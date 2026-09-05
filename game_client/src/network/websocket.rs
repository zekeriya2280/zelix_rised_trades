use bevy::prelude::*;
use crossbeam_channel::{unbounded, Receiver, Sender};
use futures_util::{SinkExt, StreamExt};
use serde_json;

use super::auth::server_base;
use super::protocol::{ClientMessage, ServerMessage, WorldSnapshot};
use crate::frontend::{AuthStore, LobbyMode, LobbyPanel, LobbyStore, Room, FrontendState, Screen};
use crate::core::events::{BuildBankEvent, BuildStructureEvent, SetFactoryProductEvent};
use crate::core::{Bank, CityRadius, Factory, Farm, Gatherer, OwnerId, PathFollower, ServerId, Vehicle, Warehouse};
use crate::render::map::TerrainGrid;
use crate::render::path::route_between;
use crate::render::logistics::{collect_cells, spawn_segment};
use crate::render::vehicle_render::VehicleSprite;

#[derive(Resource, Default)]
pub struct NetworkClient {
    pub connected: bool,
    pub sender: Option<Sender<ClientMessage>>,
    pub receiver: Option<Receiver<ServerMessage>>,
    pub connecting: bool,
    pub player_id: Option<u64>,
    pub last_error: Option<String>,
    pub retry_in: f32,
}
#[derive(Resource, Default)] pub struct OnlineAuthority { pub active: bool }
#[derive(Resource, Default)] pub struct PendingSnapshot(pub Option<WorldSnapshot>);
#[derive(Component)] pub struct ServerOwned;

#[cfg(not(target_arch = "wasm32"))]
pub fn websocket_connect_system(time: Res<Time>, mut client: ResMut<NetworkClient>, auth: Res<AuthStore>) {
    client.retry_in = (client.retry_in - time.delta_secs()).max(0.0);
    if client.connected || client.connecting || client.retry_in > 0.0 { return; }
    let Some(user) = auth.current_user.as_ref() else { return; };
    if user.token.is_empty() { return; }
    client.connecting = true;
    client.last_error = None;
    let url = websocket_url();
    let token = user.token.clone();
    let (tx_out, rx_out) = unbounded::<ClientMessage>();
    let (tx_in, rx_in) = unbounded::<ServerMessage>();
    client.sender = Some(tx_out);
    client.receiver = Some(rx_in);
    std::thread::spawn(move || {
        let Ok(runtime) = tokio::runtime::Runtime::new() else { let _ = tx_in.send(ServerMessage::Disconnected { message: "Network runtime could not start".into() }); return; };
        runtime.block_on(async move {
            use tokio_tungstenite::{connect_async, tungstenite::Message};
            let Ok((socket, _)) = connect_async(&url).await else { let _ = tx_in.send(ServerMessage::Disconnected { message: "WebSocket connection failed".into() }); return; };
            let (mut write, mut read) = socket.split();
            let Ok(text) = serde_json::to_string(&ClientMessage::Join { token }) else {
                let _ = tx_in.send(ServerMessage::Disconnected { message: "Could not serialize authentication request".into() });
                return;
            };
            if write.send(Message::Text(text.into())).await.is_err() {
                let _ = tx_in.send(ServerMessage::Disconnected { message: "Authentication request could not be sent".into() });
                return;
            }
            loop {
                tokio::select! {
                    outgoing = recv_crossbeam(&rx_out) => { let Ok(message) = outgoing else { break; }; let Ok(text)=serde_json::to_string(&message) else { continue; }; if write.send(Message::Text(text.into())).await.is_err(){break;} }
                    incoming = read.next() => { match incoming { Some(Ok(Message::Text(text))) => { if let Ok(message)=serde_json::from_str::<ServerMessage>(&text){let _=tx_in.send(message);} }, Some(Ok(Message::Close(_)))|None=>break, Some(Ok(_))=>{}, Some(Err(e))=>{let _=tx_in.send(ServerMessage::Error{message:e.to_string()});break;} } }
                }
            }
            let _=tx_in.send(ServerMessage::Disconnected{message:"WebSocket connection closed".into()});
        });
    });
}

#[cfg(not(target_arch = "wasm32"))]
async fn recv_crossbeam<T: Send + 'static>(receiver: &Receiver<T>) -> Result<T, ()> {
    loop { match receiver.try_recv() { Ok(value)=>return Ok(value), Err(crossbeam_channel::TryRecvError::Disconnected)=>return Err(()), Err(crossbeam_channel::TryRecvError::Empty)=>tokio::time::sleep(std::time::Duration::from_millis(10)).await } }
}

#[cfg(target_arch = "wasm32")]
pub fn websocket_connect_system(time: Res<Time>, mut client: ResMut<NetworkClient>, auth: Res<AuthStore>) {
    client.retry_in=(client.retry_in-time.delta_secs()).max(0.0);
    if client.connected||client.connecting||client.retry_in>0.0{return;}
    let Some(user)=auth.current_user.as_ref() else{return;}; if user.token.is_empty(){return;}
    client.connecting=true; client.last_error=None;
    let url=websocket_url(); let token=user.token.clone();
    let (tx_out,rx_out)=unbounded::<ClientMessage>(); let (tx_in,rx_in)=unbounded::<ServerMessage>();
    client.sender=Some(tx_out); client.receiver=Some(rx_in);
    wasm_bindgen_futures::spawn_local(async move {
        let Ok(socket)=gloo_net::websocket::futures::WebSocket::open(&url) else {let _=tx_in.send(ServerMessage::Disconnected{message:"WebSocket connection failed".into()});return;};
        let (mut write,mut read)=socket.split();
        let Ok(text)=serde_json::to_string(&ClientMessage::Join{token}) else {
            let _=tx_in.send(ServerMessage::Disconnected{message:"Could not serialize authentication request".into()});
            return;
        };
        if write.send(gloo_net::websocket::Message::Text(text)).await.is_err(){
            let _=tx_in.send(ServerMessage::Disconnected{message:"Authentication request could not be sent".into()});
            return;
        }
        loop {
            while let Ok(message)=rx_out.try_recv(){let Ok(text)=serde_json::to_string(&message) else{continue;}; if write.send(gloo_net::websocket::Message::Text(text)).await.is_err(){return;}}
            match read.next().await { Some(Ok(gloo_net::websocket::Message::Text(text)))=>{if let Ok(message)=serde_json::from_str::<ServerMessage>(&text){let _=tx_in.send(message);}}, Some(Ok(_))=>{}, Some(Err(e))=>{let _=tx_in.send(ServerMessage::Error{message:e.to_string()});break;}, None=>break }
        }
        let _=tx_in.send(ServerMessage::Disconnected{message:"WebSocket connection closed".into()});
    });
}

pub fn websocket_receive_system(
    mut client: ResMut<NetworkClient>,
    mut authority: ResMut<OnlineAuthority>,
    mut pending: ResMut<PendingSnapshot>,
    mut game: ResMut<crate::core::GameState>,
    mut inventory: ResMut<crate::core::MaterialInventory>,
    mut lobby: ResMut<LobbyStore>,
    mut frontend: ResMut<FrontendState>,
) {
    let Some(receiver) = client.receiver.take() else { return; };
    while let Ok(message) = receiver.try_recv() {
        match message {
            ServerMessage::Welcome { player_id } => {
                client.player_id = Some(player_id);
                client.connected = true;
                client.connecting = false;
                client.retry_in = 0.0;
                authority.active = false;
            }
            ServerMessage::LobbyState { room_id, is_host, started, mode, host_name, players, max_players, rooms } => {
                lobby.rooms = rooms.into_iter().map(|room| Room {
                    id: room.id, host: room.host,
                    mode: if room.mode.eq_ignore_ascii_case("online") { LobbyMode::Online } else { LobbyMode::Multiplayer },
                    max_players: room.max_players as usize, players: room.players, started: room.started,
                }).collect();
                if let Some(id) = room_id.clone() {
                    if !lobby.rooms.iter().any(|room| room.id == id) {
                        lobby.rooms.push(Room { id: id.clone(), host: host_name.clone(), mode: if mode.eq_ignore_ascii_case("online") { LobbyMode::Online } else { LobbyMode::Multiplayer }, max_players: max_players as usize, players: players.clone(), started });
                    }
                    frontend.current_room = Some(id.clone());
                    frontend.current_room_is_host = is_host;
                    frontend.room_code = id;
                    frontend.lobby_panel = if started { LobbyPanel::Choice } else { LobbyPanel::WaitingRoom };
                    if started {
                        frontend.screen = Screen::Game;
                        frontend.message = format!("Room started with {} players.", players.len());
                        game.paused = false;
                    } else if frontend.screen == Screen::Game {
                        frontend.screen = Screen::Lobby;
                        game.paused = true;
                    }
                    frontend.lobby_message = format!("Room: {} | {}/{} players", frontend.room_code, players.len(), max_players);
                } else {
                    frontend.current_room = None;
                    frontend.current_room_is_host = false;
                    // Only wipe the room-code input when the user is NOT actively
                    // typing it on the Enter Room panel – otherwise every LobbyState
                    // broadcast (triggered by the room list changing) clears their
                    // in-progress input.
                    if frontend.lobby_panel != LobbyPanel::EnterRoom {
                        frontend.room_code.clear();
                    }
                    if frontend.screen == Screen::Game {
                        frontend.screen = Screen::Lobby;
                        frontend.lobby_panel = LobbyPanel::Choice;
                        game.paused = true;
                    }
                }
            }
            ServerMessage::WorldSnapshot { data } => {
                client.connected = true;
                client.connecting = false;
                client.retry_in = 0.0;
                authority.active = data.in_game;
                game.money = data.money;
                game.world_time = data.tick as f64 / 20.0;
                game.server_tick = data.tick;
                game.storage_used = data.storage_used;
                game.storage_capacity = data.storage_capacity;
                inventory.counts.insert(crate::core::events::ProductType::Wood, data.inventory.wood);
                inventory.counts.insert(crate::core::events::ProductType::Stone, data.inventory.stone);
                inventory.counts.insert(crate::core::events::ProductType::Iron, data.inventory.iron);
                inventory.counts.insert(crate::core::events::ProductType::Gold, data.inventory.gold);
                inventory.counts.insert(crate::core::events::ProductType::Grain, data.inventory.grain);
                if !data.in_game && frontend.screen == Screen::Game {
                    frontend.screen = Screen::Lobby;
                    game.paused = true;
                }
                if data.in_game {
                    pending.0 = Some(data);
                } else {
                    pending.0 = None;
                }
            }
            ServerMessage::Pong => {}
            ServerMessage::CommandRejected { message } => {
                client.last_error = Some(message);
            }
            ServerMessage::Error { message } => {
                // ServerError is a connection/protocol-level failure. Never leave the
                // client stuck in `connecting = true`, otherwise the reconnect guard
                // prevents any subsequent WebSocket attempt.
                client.connected = false;
                client.connecting = false;
                client.retry_in = 2.0;
                client.player_id = None;
                client.sender = None;
                authority.active = false;
                pending.0 = None;
                frontend.current_room = None;
                frontend.current_room_is_host = false;
                frontend.room_code.clear();
                if frontend.screen == Screen::Game {
                    frontend.screen = Screen::Intro;
                    game.paused = true;
                }
                client.last_error = Some(message);
            }
            ServerMessage::Disconnected { message } => {
                client.connected = false;
                client.connecting = false;
                client.retry_in = 2.0;
                client.player_id = None;
                authority.active = false;
                pending.0 = None;
                frontend.current_room = None;
                frontend.current_room_is_host = false;
                frontend.room_code.clear();
                if frontend.screen == Screen::Game {
                    frontend.screen = Screen::Intro;
                    game.paused = true;
                }
                client.last_error = Some(message);
            }
        }
    }
    client.receiver = Some(receiver);
}

const SNAPSHOT_INTERVAL_SECONDS: f32 = 0.1;
const KEEPALIVE_INTERVAL_SECONDS: f32 = 15.0;
/// While waiting in a room lobby the client polls for LobbyState every second,
/// so when the host starts the match every member's panel drops and everyone
/// enters the game at (nearly) the same moment instead of up to one keep-alive
/// interval later.
const LOBBY_POLL_INTERVAL_SECONDS: f32 = 1.0;

pub fn websocket_send_system(
    time: Res<Time>,
    client: Res<NetworkClient>,
    frontend: Res<FrontendState>,
    mut snapshot_elapsed: Local<f32>,
    mut keepalive_elapsed: Local<f32>,
    mut lobby_elapsed: Local<f32>,
) {
    if !client.connected {
        *snapshot_elapsed = 0.0;
        *keepalive_elapsed = 0.0;
        *lobby_elapsed = 0.0;
        return;
    }

    *snapshot_elapsed += time.delta_secs();
    *keepalive_elapsed += time.delta_secs();
    *lobby_elapsed += time.delta_secs();

    let Some(sender) = &client.sender else { return; };

    if frontend.screen == Screen::Game && *snapshot_elapsed >= SNAPSHOT_INTERVAL_SECONDS {
        *snapshot_elapsed %= SNAPSHOT_INTERVAL_SECONDS;
        let _ = sender.send(ClientMessage::RequestSnapshot);
    } else if frontend.screen != Screen::Game {
        *snapshot_elapsed = 0.0;
    }

    if *keepalive_elapsed >= KEEPALIVE_INTERVAL_SECONDS {
        *keepalive_elapsed %= KEEPALIVE_INTERVAL_SECONDS;
        let _ = sender.send(ClientMessage::Ping);
    }

    // A Ping also answers with a fresh LobbyState on the server, so polling it
    // here keeps waiting-room members in sync with the host's Start Game.
    if frontend.screen == Screen::Lobby && *lobby_elapsed >= LOBBY_POLL_INTERVAL_SECONDS {
        *lobby_elapsed %= LOBBY_POLL_INTERVAL_SECONDS;
        let _ = sender.send(ClientMessage::Ping);
    } else if frontend.screen != Screen::Lobby {
        *lobby_elapsed = 0.0;
    }
}

pub fn forward_build_events_system(
    client: Res<NetworkClient>,
    mut bank_events: MessageReader<BuildBankEvent>,
    mut build_events: MessageReader<BuildStructureEvent>,
    mut product_events: MessageReader<SetFactoryProductEvent>,
    factories: Query<&crate::core::Factory>,
) {
    let Some(sender) = &client.sender else { return; };
    if !client.connected { return; }

    for event in bank_events.read() {
        let _ = sender.send(ClientMessage::BuildBank { x: event.position.x, y: event.position.y });
    }
    for event in build_events.read() {
        let _ = sender.send(ClientMessage::BuildStructure {
            building_type: event.building_type,
            x: event.position.x,
            y: event.position.y,
        });
    }
    for event in product_events.read() {
        if let Ok(factory) = factories.get(event.entity) {
            let _ = sender.send(ClientMessage::SetFactoryProduct { id: factory.id, product: event.product });
        }
    }
}

pub fn apply_snapshot_system(
    mut commands: Commands,
    mut pending: ResMut<PendingSnapshot>,
    asset_server: Res<AssetServer>,
    network: Res<NetworkClient>,
    server_entities: Query<(Entity, &ServerId, &OwnerId), With<ServerOwned>>,
    terrain: Res<TerrainGrid>,
    server_buildings: Query<
        &GlobalTransform,
        (
            With<ServerOwned>,
            Or<(With<Bank>, With<Factory>, With<Warehouse>, With<Gatherer>, With<Farm>)>,
        ),
    >,
) {
    let Some(snapshot) = pending.0.take() else { return; };

    // Only replicate this client's OWN entities. Other players' buildings,
    // vehicles and their delivery roads must never appear on screen — they
    // were showing up as unwanted objects/movements besides the player's own
    // truck during factory/warehouse/transportation gameplay.
    let my_id = network.player_id;
    let is_mine = |owner_id: u64| my_id == Some(owner_id);

    // Reconcile by authoritative server id instead of destroying/recreating the
    // whole world every snapshot. This removes a large amount of Bevy ECS and
    // asset churn on multiplayer clients.
    use std::collections::{HashMap, HashSet};
    let existing: HashMap<u64, Entity> = server_entities
        .iter()
        .map(|(entity, id, _owner)| (id.0, entity))
        .collect();

    let mut seen = HashSet::new();

    for bank in snapshot.banks {
        if !is_mine(bank.owner_id) { continue; }
        seen.insert(bank.id);
        let entity = existing.get(&bank.id).copied().unwrap_or_else(|| {
            commands.spawn((
                ServerOwned,
                ServerId(bank.id),
                OwnerId(bank.owner_id),
                Bank,
                CityRadius { radius: 300.0 },
                Sprite { image: asset_server.load("bank.png"), custom_size: Some(Vec2::splat(48.0)), ..default() },
                Transform::from_xyz(bank.x, bank.y, 20.0),
            )).id()
        });
        if existing.contains_key(&bank.id) {
            commands.entity(entity).insert((
                OwnerId(bank.owner_id),
                Transform::from_xyz(bank.x, bank.y, 20.0),
            ));
        }
    }

    for factory in snapshot.factories {
        if !is_mine(factory.owner_id) { continue; }
        seen.insert(factory.id);
        let entity = existing.get(&factory.id).copied().unwrap_or_else(|| {
            commands.spawn((
                ServerOwned,
                ServerId(factory.id),
                OwnerId(factory.owner_id),
                Factory { id: factory.id, level: factory.level, product: factory.product },
                Sprite { image: asset_server.load("factory.png"), custom_size: Some(Vec2::splat(48.0)), ..default() },
                Transform::from_xyz(factory.x, factory.y, 20.0),
            )).id()
        });
        if existing.contains_key(&factory.id) {
            commands.entity(entity).insert((
                OwnerId(factory.owner_id),
                Factory { id: factory.id, level: factory.level, product: factory.product },
                Transform::from_xyz(factory.x, factory.y, 20.0),
            ));
        }
    }

    for warehouse in snapshot.warehouses {
        if !is_mine(warehouse.owner_id) { continue; }
        seen.insert(warehouse.id);
        let entity = existing.get(&warehouse.id).copied().unwrap_or_else(|| {
            commands.spawn((
                ServerOwned,
                ServerId(warehouse.id),
                OwnerId(warehouse.owner_id),
                Warehouse,
                Sprite { image: asset_server.load("warehouse.png"), custom_size: Some(Vec2::splat(48.0)), ..default() },
                Transform::from_xyz(warehouse.x, warehouse.y, 20.0),
            )).id()
        });
        if existing.contains_key(&warehouse.id) {
            commands.entity(entity).insert((
                OwnerId(warehouse.owner_id),
                Transform::from_xyz(warehouse.x, warehouse.y, 20.0),
            ));
        }
    }

    for building in snapshot.gatherers {
        if !is_mine(building.owner_id) { continue; }
        seen.insert(building.id);
        let entity = existing.get(&building.id).copied().unwrap_or_else(|| {
            commands.spawn((
                ServerOwned,
                ServerId(building.id),
                OwnerId(building.owner_id),
                Gatherer,
                Sprite { image: asset_server.load("gatherer.png"), custom_size: Some(Vec2::splat(48.0)), ..default() },
                Transform::from_xyz(building.x, building.y, 20.0),
            )).id()
        });
        if existing.contains_key(&building.id) {
            commands.entity(entity).insert((
                OwnerId(building.owner_id),
                Transform::from_xyz(building.x, building.y, 20.0),
            ));
        }
    }

    for building in snapshot.farms {
        if !is_mine(building.owner_id) { continue; }
        seen.insert(building.id);
        let entity = existing.get(&building.id).copied().unwrap_or_else(|| {
            commands.spawn((
                ServerOwned,
                ServerId(building.id),
                OwnerId(building.owner_id),
                Farm,
                Sprite { image: asset_server.load("farm.png"), custom_size: Some(Vec2::splat(48.0)), ..default() },
                Transform::from_xyz(building.x, building.y, 20.0),
            )).id()
        });
        if existing.contains_key(&building.id) {
            commands.entity(entity).insert((
                OwnerId(building.owner_id),
                Transform::from_xyz(building.x, building.y, 20.0),
            ));
        }
    }

    for vehicle in snapshot.vehicles {
        // Skip other players' vehicles entirely: spawning them also draws
        // their delivery roads, which appeared as unwanted movement.
        if !is_mine(vehicle.owner_id) { continue; }
        seen.insert(vehicle.id);
        let is_new = !existing.contains_key(&vehicle.id);
        let entity = existing.get(&vehicle.id).copied().unwrap_or_else(|| {
            commands.spawn((
                ServerOwned,
                ServerId(vehicle.id),
                OwnerId(vehicle.owner_id),
                Vehicle { speed: vehicle.speed },
                // Marker so update_vehicle_visuals_system rotates the sprite
                // along the travel direction (otherwise it always faces up).
                VehicleSprite,
                Sprite { image: asset_server.load("vehicle.png"), custom_size: Some(Vec2::splat(24.0)), ..default() },
                Transform::from_xyz(vehicle.x, vehicle.y, 20.0),
                PathFollower { waypoints: vec![Vec2::new(vehicle.target_x, vehicle.target_y)], index: 0 },
            )).id()
        });
        if existing.contains_key(&vehicle.id) {
            commands.entity(entity).insert((
                OwnerId(vehicle.owner_id),
                Vehicle { speed: vehicle.speed },
                VehicleSprite,
                Transform::from_xyz(vehicle.x, vehicle.y, 20.0),
                PathFollower { waypoints: vec![Vec2::new(vehicle.target_x, vehicle.target_y)], index: 0 },
            ));
        }

        // Draw the factory -> warehouse delivery road for newly replicated
        // vehicles so online players see the route just like in single-player.
        // The segments become children of the vehicle and despawn with it.
        if is_new {
            let mut blocked = std::collections::HashSet::new();
            for transform in &server_buildings {
                collect_cells(&terrain, transform.translation().truncate(), &mut blocked);
            }
            let is_blocked = |x: usize, y: usize| blocked.contains(&(x, y));
            if let Some(waypoints) = route_between(
                &terrain,
                &is_blocked,
                Vec2::new(vehicle.x, vehicle.y),
                Vec2::new(vehicle.target_x, vehicle.target_y),
            ) {
                let segments: Vec<Entity> = waypoints
                    .windows(2)
                    .map(|pair| spawn_segment(&mut commands, pair[0], pair[1]))
                    .collect();
                if !segments.is_empty() {
                    commands.entity(entity).add_children(&segments);
                }
            }
        }
    }

    for (entity, id, owner) in server_entities.iter() {
        if !seen.contains(&id.0) || !is_mine(owner.0) {
            commands.entity(entity).despawn();
        }
    }
}

fn websocket_url() -> String {
    let base = server_base().trim_end_matches('/').to_string();
    if base.ends_with("/ws") {
        return base;
    }
    if let Some(rest) = base.strip_prefix("https://") {
        format!("wss://{rest}/ws")
    } else if let Some(rest) = base.strip_prefix("http://") {
        format!("ws://{rest}/ws")
    } else if base.starts_with("ws://") || base.starts_with("wss://") {
        format!("{base}/ws")
    } else {
        format!("ws://{base}/ws")
    }
}

#[cfg(test)]
mod tests {
    #[derive(Debug)]
    struct ConnectionFlags {
        connected: bool,
        connecting: bool,
        retry_in: f32,
    }

    fn apply_connection_error(state: &mut ConnectionFlags) {
        state.connected = false;
        state.connecting = false;
        state.retry_in = 2.0;
    }

    #[test]
    fn server_error_clears_connecting_state() {
        let mut state = ConnectionFlags { connected: false, connecting: true, retry_in: 0.0 };
        apply_connection_error(&mut state);
        assert!(!state.connected);
        assert!(!state.connecting);
        assert_eq!(state.retry_in, 2.0);
    }
}
