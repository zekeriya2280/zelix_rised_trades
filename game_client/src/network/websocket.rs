use bevy::prelude::*;
use crossbeam_channel::{unbounded, Receiver, Sender};
use futures_util::{SinkExt, StreamExt};
use serde_json;

use super::auth::server_base;
use super::protocol::{ClientMessage, ServerMessage, WorldSnapshot};

use crate::frontend::{
    AuthStore,
    FrontendState,
    LobbyMode,
    LobbyPanel,
    LobbyStore,
    Room,
    Screen,
};

use crate::core::events::{
    BuildBankEvent,
    BuildStructureEvent,
    SetFactoryProductEvent,
};

use crate::core::{
    Bank,
    CityRadius,
    Factory,
    Farm,
    Gatherer,
    OwnerId,
    PathFollower,
    ServerId,
    Vehicle,
    Warehouse,
};

use crate::render::logistics::{spawn_segment, OnlineDeliveryRoad};
use crate::render::vehicle_render::VehicleSprite;

use crate::render::map::{BUILDING_SIZE, BUILDING_Z, VEHICLE_Z};

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

#[derive(Resource, Default)]
pub struct OnlineAuthority {
    pub active: bool,
}

#[derive(Resource, Default)]
pub struct PendingSnapshot(pub Option<WorldSnapshot>);

#[derive(Component)]
pub struct ServerOwned;

#[cfg(not(target_arch = "wasm32"))]
pub fn websocket_connect_system(
    time: Res<Time>,
    mut client: ResMut<NetworkClient>,
    auth: Res<AuthStore>,
) {
    client.retry_in = (client.retry_in - time.delta_secs()).max(0.0);

    if client.connected || client.connecting || client.retry_in > 0.0 {
        return;
    }

    let Some(user) = auth.current_user.as_ref() else {
        return;
    };

    if user.token.is_empty() {
        return;
    }

    client.connecting = true;
    client.last_error = None;

    let url = websocket_url();
    let token = user.token.clone();

    let (tx_out, rx_out) = unbounded::<ClientMessage>();
    let (tx_in, rx_in) = unbounded::<ServerMessage>();

    client.sender = Some(tx_out);
    client.receiver = Some(rx_in);

    std::thread::spawn(move || {
        let Ok(runtime) = tokio::runtime::Runtime::new() else {
            let _ = tx_in.send(ServerMessage::Disconnected {
                message: "Network runtime could not start".into(),
            });
            return;
        };

        runtime.block_on(async move {
            use tokio_tungstenite::{
                connect_async,
                tungstenite::Message,
            };

            let Ok((socket, _)) = connect_async(&url).await else {
                let _ = tx_in.send(ServerMessage::Disconnected {
                    message: "WebSocket connection failed".into(),
                });
                return;
            };

            let (mut write, mut read) = socket.split();

            let Ok(text) =
                serde_json::to_string(&ClientMessage::Join { token })
            else {
                let _ = tx_in.send(ServerMessage::Disconnected {
                    message: "Could not serialize authentication request".into(),
                });
                return;
            };

            if write
                .send(Message::Text(text.into()))
                .await
                .is_err()
            {
                let _ = tx_in.send(ServerMessage::Disconnected {
                    message: "Authentication request could not be sent".into(),
                });
                return;
            }

            loop {
                tokio::select! {
                    outgoing = recv_crossbeam(&rx_out) => {
                        let Ok(message) = outgoing else {
                            break;
                        };

                        let Ok(text) = serde_json::to_string(&message) else {
                            continue;
                        };

                        if write
                            .send(Message::Text(text.into()))
                            .await
                            .is_err()
                        {
                            break;
                        }
                    }

                    incoming = read.next() => {
                        match incoming {
                            Some(Ok(Message::Text(text))) => {
                                if let Ok(message) =
                                    serde_json::from_str::<ServerMessage>(&text)
                                {
                                    let _ = tx_in.send(message);
                                }
                            }

                            Some(Ok(Message::Close(_))) | None => {
                                break;
                            }

                            Some(Ok(_)) => {}

                            Some(Err(error)) => {
                                let _ = tx_in.send(ServerMessage::Error {
                                    message: error.to_string(),
                                });
                                break;
                            }
                        }
                    }
                }
            }

            let _ = tx_in.send(ServerMessage::Disconnected {
                message: "WebSocket connection closed".into(),
            });
        });
    });
}

#[cfg(not(target_arch = "wasm32"))]
async fn recv_crossbeam<T: Send + 'static>(
    receiver: &Receiver<T>,
) -> Result<T, ()> {
    loop {
        match receiver.try_recv() {
            Ok(value) => return Ok(value),

            Err(crossbeam_channel::TryRecvError::Disconnected) => {
                return Err(());
            }

            Err(crossbeam_channel::TryRecvError::Empty) => {
                tokio::time::sleep(
                    std::time::Duration::from_millis(10),
                )
                .await;
            }
        }
    }
}

#[cfg(target_arch = "wasm32")]
pub fn websocket_connect_system(
    time: Res<Time>,
    mut client: ResMut<NetworkClient>,
    auth: Res<AuthStore>,
) {
    client.retry_in = (client.retry_in - time.delta_secs()).max(0.0);

    if client.connected || client.connecting || client.retry_in > 0.0 {
        return;
    }

    let Some(user) = auth.current_user.as_ref() else {
        return;
    };

    if user.token.is_empty() {
        return;
    }

    client.connecting = true;
    client.last_error = None;

    let url = websocket_url();
    let token = user.token.clone();

    let (tx_out, rx_out) = unbounded::<ClientMessage>();
    let (tx_in, rx_in) = unbounded::<ServerMessage>();

    client.sender = Some(tx_out);
    client.receiver = Some(rx_in);

    wasm_bindgen_futures::spawn_local(async move {
        let Ok(socket) =
            gloo_net::websocket::futures::WebSocket::open(&url)
        else {
            let _ = tx_in.send(ServerMessage::Disconnected {
                message: "WebSocket connection failed".into(),
            });
            return;
        };

        let (mut write, mut read) = socket.split();

        let Ok(text) =
            serde_json::to_string(&ClientMessage::Join { token })
        else {
            let _ = tx_in.send(ServerMessage::Disconnected {
                message: "Could not serialize authentication request".into(),
            });
            return;
        };

        if write
            .send(gloo_net::websocket::Message::Text(text))
            .await
            .is_err()
        {
            let _ = tx_in.send(ServerMessage::Disconnected {
                message: "Authentication request could not be sent".into(),
            });
            return;
        }

        loop {
            while let Ok(message) = rx_out.try_recv() {
                let Ok(text) = serde_json::to_string(&message) else {
                    continue;
                };

                if write
                    .send(gloo_net::websocket::Message::Text(text))
                    .await
                    .is_err()
                {
                    return;
                }
            }

            // Do not block outgoing messages behind read.next().await. A
            // short async wake-up gives WebAssembly a responsive bidirectional
            // WebSocket loop without a busy-spin.
            use futures_util::future::{select, Either};
            use futures_util::FutureExt;
            let incoming = Box::pin(read.next().fuse());
            let wake = Box::pin(gloo_timers::future::TimeoutFuture::new(10).fuse());

            match select(incoming, wake).await {
                Either::Left((message, _)) => match message {
                    Some(Ok(gloo_net::websocket::Message::Text(text))) => {
                        if let Ok(message) =
                            serde_json::from_str::<ServerMessage>(&text)
                        {
                            let _ = tx_in.send(message);
                        }
                    }
                    Some(Ok(_)) => {}
                    Some(Err(error)) => {
                        let _ = tx_in.send(ServerMessage::Error {
                            message: error.to_string(),
                        });
                        break;
                    }
                    None => break,
                },
                Either::Right((_, _)) => {}
            }
        }

        let _ = tx_in.send(ServerMessage::Disconnected {
            message: "WebSocket connection closed".into(),
        });
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
    let Some(receiver) = client.receiver.take() else {
        return;
    };

    while let Ok(message) = receiver.try_recv() {
        match message {
            ServerMessage::Welcome { player_id } => {
                client.player_id = Some(player_id);
                client.connected = true;
                client.connecting = false;
                client.retry_in = 0.0;
                authority.active = false;
            }

            ServerMessage::LobbyState {
                room_id,
                is_host,
                started,
                mode,
                host_name,
                players,
                max_players,
                rooms,
            } => {
                lobby.rooms = rooms
                    .into_iter()
                    .map(|room| Room {
                        id: room.id,
                        host: room.host,
                        mode: if room
                            .mode
                            .eq_ignore_ascii_case("online")
                        {
                            LobbyMode::Online
                        } else {
                            LobbyMode::Multiplayer
                        },
                        max_players: room.max_players as usize,
                        players: room.players,
                        started: room.started,
                    })
                    .collect();

                if let Some(id) = room_id.clone() {
                    if !lobby.rooms.iter().any(|room| room.id == id) {
                        lobby.rooms.push(Room {
                            id: id.clone(),
                            host: host_name.clone(),
                            mode: if mode.eq_ignore_ascii_case("online") {
                                LobbyMode::Online
                            } else {
                                LobbyMode::Multiplayer
                            },
                            max_players: max_players as usize,
                            players: players.clone(),
                            started,
                        });
                    }

                    frontend.current_room = Some(id.clone());
                    frontend.current_room_is_host = is_host;
                    frontend.room_code = id;

                    frontend.lobby_panel = if started {
                        LobbyPanel::Choice
                    } else {
                        LobbyPanel::WaitingRoom
                    };

                    if started {
                        frontend.screen = Screen::Game;
                        frontend.message = format!(
                            "Room started with {} players.",
                            players.len()
                        );
                        game.paused = false;
                    } else if frontend.screen == Screen::Game {
                        frontend.screen = Screen::Lobby;
                        game.paused = true;
                    }

                    frontend.lobby_message = format!(
                        "Room: {} | {}/{} players",
                        frontend.room_code,
                        players.len(),
                        max_players
                    );
                } else {
                    frontend.current_room = None;
                    frontend.current_room_is_host = false;

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

                inventory.counts.insert(
                    crate::core::events::ProductType::Wood,
                    data.inventory.wood,
                );

                inventory.counts.insert(
                    crate::core::events::ProductType::Stone,
                    data.inventory.stone,
                );

                inventory.counts.insert(
                    crate::core::events::ProductType::Iron,
                    data.inventory.iron,
                );

                inventory.counts.insert(
                    crate::core::events::ProductType::Gold,
                    data.inventory.gold,
                );

                inventory.counts.insert(
                    crate::core::events::ProductType::Grain,
                    data.inventory.grain,
                );

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

    let Some(sender) = &client.sender else {
        return;
    };

    if frontend.screen == Screen::Game
        && *snapshot_elapsed >= SNAPSHOT_INTERVAL_SECONDS
    {
        *snapshot_elapsed %= SNAPSHOT_INTERVAL_SECONDS;
        let _ = sender.send(ClientMessage::RequestSnapshot);
    } else if frontend.screen != Screen::Game {
        *snapshot_elapsed = 0.0;
    }

    if *keepalive_elapsed >= KEEPALIVE_INTERVAL_SECONDS {
        *keepalive_elapsed %= KEEPALIVE_INTERVAL_SECONDS;
        let _ = sender.send(ClientMessage::Ping);
    }

    if frontend.screen == Screen::Lobby
        && *lobby_elapsed >= LOBBY_POLL_INTERVAL_SECONDS
    {
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
    let Some(sender) = &client.sender else {
        return;
    };

    if !client.connected {
        return;
    }

    for event in bank_events.read() {
        let _ = sender.send(ClientMessage::BuildBank {
            x: event.position.x,
            y: event.position.y,
        });
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
            let _ = sender.send(ClientMessage::SetFactoryProduct {
                id: factory.id,
                product: event.product,
            });
        }
    }
}

pub fn apply_snapshot_system(
    mut commands: Commands,
    mut pending: ResMut<PendingSnapshot>,
    asset_server: Res<AssetServer>,
    _network: Res<NetworkClient>,
    server_entities: Query<
        (Entity, &ServerId, &OwnerId),
        With<ServerOwned>,
    >,
    online_roads: Query<(Entity, &OnlineDeliveryRoad)>,
) {
    let Some(snapshot) = pending.0.take() else {
        return;
    };

    /*
        The server is authoritative for the shared online world.

        Every client in the same room renders the complete authoritative
        snapshot. Ownership remains attached to entities for interaction and
        permissions, but ownership must not be used as a visibility filter.
    */

    use std::collections::{HashMap, HashSet};

    let existing: HashMap<u64, Entity> = server_entities
        .iter()
        .map(|(entity, id, _owner)| (id.0, entity))
        .collect();

    let mut seen = HashSet::new();

    for bank in snapshot.banks {
        seen.insert(bank.id);

        let entity = existing
            .get(&bank.id)
            .copied()
            .unwrap_or_else(|| {
                commands
                    .spawn((
                        ServerOwned,
                        ServerId(bank.id),
                        OwnerId(bank.owner_id),
                        Bank,
                        CityRadius { radius: 300.0 },
                        Sprite {
                            image: asset_server.load("bank.png"),
                            custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                            ..default()
                        },
                        Transform::from_xyz(
                            bank.x,
                            bank.y,
                            BUILDING_Z,
                        ),
                    ))
                    .id()
            });

        if existing.contains_key(&bank.id) {
            commands.entity(entity).insert((
                OwnerId(bank.owner_id),
                Transform::from_xyz(
                    bank.x,
                    bank.y,
                    BUILDING_Z,
                ),
            ));
        }
    }

    for factory in snapshot.factories {
        seen.insert(factory.id);

        let entity = existing
            .get(&factory.id)
            .copied()
            .unwrap_or_else(|| {
                commands
                    .spawn((
                        ServerOwned,
                        ServerId(factory.id),
                        OwnerId(factory.owner_id),
                        Factory {
                            id: factory.id,
                            level: factory.level,
                            product: factory.product,
                        },
                        Sprite {
                            image: asset_server.load("factory.png"),
                            custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                            ..default()
                        },
                        Transform::from_xyz(
                            factory.x,
                            factory.y,
                            BUILDING_Z,
                        ),
                    ))
                    .id()
            });

        if existing.contains_key(&factory.id) {
            commands.entity(entity).insert((
                OwnerId(factory.owner_id),
                Factory {
                    id: factory.id,
                    level: factory.level,
                    product: factory.product,
                },
                Transform::from_xyz(
                    factory.x,
                    factory.y,
                    BUILDING_Z,
                ),
            ));
        }
    }

    for warehouse in snapshot.warehouses {
        seen.insert(warehouse.id);

        let entity = existing
            .get(&warehouse.id)
            .copied()
            .unwrap_or_else(|| {
                commands
                    .spawn((
                        ServerOwned,
                        ServerId(warehouse.id),
                        OwnerId(warehouse.owner_id),
                        Warehouse,
                        Sprite {
                            image: asset_server.load("warehouse.png"),
                            custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                            ..default()
                        },
                        Transform::from_xyz(
                            warehouse.x,
                            warehouse.y,
                            BUILDING_Z,
                        ),
                    ))
                    .id()
            });

        if existing.contains_key(&warehouse.id) {
            commands.entity(entity).insert((
                OwnerId(warehouse.owner_id),
                Transform::from_xyz(
                    warehouse.x,
                    warehouse.y,
                    BUILDING_Z,
                ),
            ));
        }
    }

    for building in snapshot.gatherers {
        seen.insert(building.id);

        let entity = existing
            .get(&building.id)
            .copied()
            .unwrap_or_else(|| {
                commands
                    .spawn((
                        ServerOwned,
                        ServerId(building.id),
                        OwnerId(building.owner_id),
                        Gatherer,
                        Sprite {
                            image: asset_server.load("gatherer.png"),
                            custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                            ..default()
                        },
                        Transform::from_xyz(
                            building.x,
                            building.y,
                            BUILDING_Z,
                        ),
                    ))
                    .id()
            });

        if existing.contains_key(&building.id) {
            commands.entity(entity).insert((
                OwnerId(building.owner_id),
                Transform::from_xyz(
                    building.x,
                    building.y,
                    BUILDING_Z,
                ),
            ));
        }
    }

    for building in snapshot.farms {
        seen.insert(building.id);

        let entity = existing
            .get(&building.id)
            .copied()
            .unwrap_or_else(|| {
                commands
                    .spawn((
                        ServerOwned,
                        ServerId(building.id),
                        OwnerId(building.owner_id),
                        Farm,
                        Sprite {
                            image: asset_server.load("farm.png"),
                            custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                            ..default()
                        },
                        Transform::from_xyz(
                            building.x,
                            building.y,
                            BUILDING_Z,
                        ),
                    ))
                    .id()
            });

        if existing.contains_key(&building.id) {
            commands.entity(entity).insert((
                OwnerId(building.owner_id),
                Transform::from_xyz(
                    building.x,
                    building.y,
                    BUILDING_Z,
                ),
            ));
        }
    }

    let existing_roads: std::collections::HashSet<u64> = online_roads
        .iter()
        .map(|(_, road)| road.vehicle_id)
        .collect();

    for vehicle in snapshot.vehicles {
        if !vehicle.is_finite() {
            if let Some(entity) = existing.get(&vehicle.id) {
                commands.entity(*entity).despawn();
            }
            continue;
        }

        seen.insert(vehicle.id);
        let is_new = !existing.contains_key(&vehicle.id);

        let waypoints: Vec<Vec2> = vehicle
            .path
            .iter()
            .map(|point| Vec2::new(point.x, point.y))
            .collect();
        let path_index = vehicle.path_index as usize;

        let entity = existing
            .get(&vehicle.id)
            .copied()
            .unwrap_or_else(|| {
                commands
                    .spawn((
                        ServerOwned,
                        ServerId(vehicle.id),
                        OwnerId(vehicle.owner_id),
                        Vehicle { speed: vehicle.speed },
                        VehicleSprite,
                        Sprite {
                            image: asset_server.load("vehicle.png"),
                            custom_size: Some(Vec2::splat(24.0)),
                            ..default()
                        },
                        Transform::from_xyz(
                            vehicle.x,
                            vehicle.y,
                            VEHICLE_Z,
                        ),
                        PathFollower {
                            waypoints: waypoints.clone(),
                            index: path_index,
                        },
                    ))
                    .id()
            });

        if !is_new {
            commands.entity(entity).insert((
                OwnerId(vehicle.owner_id),
                Vehicle { speed: vehicle.speed },
                VehicleSprite,
                Transform::from_xyz(
                    vehicle.x,
                    vehicle.y,
                    VEHICLE_Z,
                ),
                PathFollower {
                    waypoints: waypoints.clone(),
                    index: path_index,
                },
            ));
        }

        // The server is authoritative for the exact road. Never recalculate
        // the route locally: the client and server can otherwise choose
        // different equal-cost grid paths. Roads are independent world
        // entities and must never become vehicle children.
        if !waypoints.is_empty()
            && (is_new || !existing_roads.contains(&vehicle.id))
        {
            for pair in waypoints.windows(2) {
                if pair[0].distance_squared(pair[1]) <= 0.0001 {
                    continue;
                }
                let segment = spawn_segment(
                    &mut commands,
                    pair[0],
                    pair[1],
                );
                commands
                    .entity(segment)
                    .insert(OnlineDeliveryRoad {
                        vehicle_id: vehicle.id,
                    });
            }
        }
    }

    /*
        Snapshot is authoritative:
        anything not present on the latest server snapshot is stale
        and must disappear locally.
    */
    for (entity, id, _owner) in server_entities.iter() {
        if !seen.contains(&id.0) {
            commands.entity(entity).despawn();
        }
    }

    // Roads have no ServerId of their own. Remove all road segments whose
    // vehicle disappeared from the authoritative snapshot.
    for (road_entity, road) in online_roads.iter() {
        if !seen.contains(&road.vehicle_id) {
            commands.entity(road_entity).despawn();
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
    } else if base.starts_with("ws://")
        || base.starts_with("wss://")
    {
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
        let mut state = ConnectionFlags {
            connected: false,
            connecting: true,
            retry_in: 0.0,
        };

        apply_connection_error(&mut state);

        assert!(!state.connected);
        assert!(!state.connecting);
        assert_eq!(state.retry_in, 2.0);
    }
}