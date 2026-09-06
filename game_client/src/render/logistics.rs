//! Logistics: choosing a material and a destination building for a factory,
//! then routing a vehicle over the grid and drawing the road between the two
//! buildings.

use std::collections::HashSet;

use bevy::prelude::*;

use crate::core::events::{ProductType, SetFactoryProductEvent};
use crate::core::{Bank, Factory, Farm, Gatherer, OwnerId, PathFollower, Vehicle, Warehouse};
use crate::render::camera::MainCamera;
use crate::render::map::{self, BUILDING_SIZE, TerrainGrid, ROAD_Z, VEHICLE_Z};
use crate::render::path::route_between;
use crate::render::vehicle_render::VehicleSprite;
use crate::network::{NetworkClient, OnlineAuthority};
use crate::network::protocol::ClientMessage;

#[derive(Component)]
pub struct DeliveryRoadSegment;

/// Which stage of the "send material" flow we are in.
#[derive(Default)]
pub enum SelectionPhase {
    #[default]
    Idle,
    /// A factory was given a material; now the player must click the target
    /// building (a factory or a warehouse) it should be delivered to.
    AwaitingDestination { source: Entity, product: ProductType },
}

#[derive(Resource, Default)]
pub struct LogisticsSelection {
    pub phase: SelectionPhase,
}

/// The currently active (single) delivery: its vehicle and drawn road.
#[derive(Resource)]
pub struct ActiveDelivery {
    pub active: bool,
    pub vehicle: Entity,
    pub road_entities: Vec<Entity>,
}

impl Default for ActiveDelivery {
    fn default() -> Self {
        Self {
            active: false,
            vehicle: Entity::PLACEHOLDER,
            road_entities: Vec::new(),
        }
    }
}
/// After a material is picked for a factory, enter the "pick destination"
/// stage by arming the logistics selection.
pub fn factory_product_selected_system(
    mut selection: ResMut<LogisticsSelection>,
    mut events: MessageReader<SetFactoryProductEvent>,
) {
    for ev in events.read() {
        selection.phase = SelectionPhase::AwaitingDestination {
            source: ev.entity,
            product: ev.product,
        };
    }
}

/// Show a hint describing the current logistics stage.
pub fn update_logistics_hint_system(
    selection: Res<LogisticsSelection>,
    mut hint: Query<&mut Text, With<crate::render::ui::LogisticsHintText>>,
    _authority: Res<OnlineAuthority>,
    _network: Res<NetworkClient>,
) {
    let msg = match selection.phase {
        SelectionPhase::Idle => String::new(),
        SelectionPhase::AwaitingDestination { .. } => {
            "Hedef sec: malzemenin goturulecegi fabrika veya depoya SOL TIKLA".to_string()
        }
    };

    if let Ok(mut text) = hint.single_mut() {
        *text = Text::new(msg);
    }
}
/// While waiting for a destination, a left click on a factory or warehouse
/// computes the shortest grid path, draws the road, and dispatches a vehicle.
/// Runs early in the frame chain so the click that chose the material on the
/// previous frame is never interpreted as a destination click.
pub fn select_destination_system(
    mouse: Res<ButtonInput<MouseButton>>,
    windows: Query<&Window>,
    camera: Query<(&Camera, &GlobalTransform), With<MainCamera>>,
    mut selection: ResMut<LogisticsSelection>,
    terrain: Res<TerrainGrid>,
    banks: Query<&GlobalTransform, With<Bank>>,
    warehouses: Query<(Entity, &GlobalTransform, Option<&OwnerId>), With<Warehouse>>,
    factories: Query<(Entity, &GlobalTransform, Option<&OwnerId>), With<Factory>>,
    gatherers: Query<&GlobalTransform, With<Gatherer>>,
    farms: Query<&GlobalTransform, With<Farm>>,
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    mut active: ResMut<ActiveDelivery>,
    mut hint: Query<&mut Text, With<crate::render::ui::LogisticsHintText>>,
    authority: Res<OnlineAuthority>,
    network: Res<NetworkClient>,
) {
    let (source, _product) = match &selection.phase {
        SelectionPhase::AwaitingDestination { source, product } => (*source, *product),
        _ => return,
    };

    if !mouse.just_pressed(MouseButton::Left) {
        return;
    }

    let Ok(window) = windows.single() else {
        return;
    };
    let Some(cursor) = window.cursor_position() else {
        return;
    };
    let Ok((cam, cam_t)) = camera.single() else {
        return;
    };
    let Ok(world) = cam.viewport_to_world_2d(cam_t, cursor) else {
        return;
    };

    let half = BUILDING_SIZE / 2.0;

    // The clicked building must be a warehouse or a different factory.
    let mut dest: Option<(Entity, Vec2)> = None;
    for (e, t, owner) in &warehouses {
        if authority.active && owner.map(|id| id.0) != network.player_id {
            continue;
        }
        let p = t.translation().truncate();
        if within_box(world, p, half) {
            dest = Some((e, p));
            break;
        }
    }
    if dest.is_none() {
        for (e, t, owner) in &factories {
            if authority.active && owner.map(|id| id.0) != network.player_id {
                continue;
            }
            let p = t.translation().truncate();
            if e == source {
                continue;
            }
            if within_box(world, p, half) {
                dest = Some((e, p));
                break;
            }
        }
    }

    let Some((_, dest_pos)) = dest else {
        return;
    };
    let src_pos = match factories.get(source) {
        Ok((_, t, _)) => t.translation().truncate(),
        Err(_) => {
            selection.phase = SelectionPhase::Idle;
            return;
        }
    };

    if authority.active {
        if let Some(sender) = &network.sender {
            let _ = sender.send(ClientMessage::SpawnVehicle {
                x: src_pos.x,
                y: src_pos.y,
                target_x: dest_pos.x,
                target_y: dest_pos.y,
                speed: 80.0,
            });
        }
        selection.phase = SelectionPhase::Idle;
        if let Ok(mut text) = hint.single_mut() {
            *text = Text::new("Teslimat sunucuya gönderildi.");
        }
        return;
    }
// Roads never cross a building footprint.
    let mut blocked: HashSet<(usize, usize)> = HashSet::new();
    for t in &banks {
        collect_cells(&terrain, t.translation().truncate(), &mut blocked);
    }
    for (_, t, _) in &warehouses {
        collect_cells(&terrain, t.translation().truncate(), &mut blocked);
    }
    for (_, t, _) in &factories {
        collect_cells(&terrain, t.translation().truncate(), &mut blocked);
    }
    for t in &gatherers {
        collect_cells(&terrain, t.translation().truncate(), &mut blocked);
    }
    for t in &farms {
        collect_cells(&terrain, t.translation().truncate(), &mut blocked);
    }

    let is_blocked = |x: usize, y: usize| blocked.contains(&(x, y));

    match route_between(&terrain, &is_blocked, src_pos, dest_pos) {
        Some(waypoints) => {
            despawn_delivery(&mut commands, &mut active);

            // Draw the road as consecutive segments along the grid path.
            let mut road = Vec::new();
            for pair in waypoints.windows(2) {
                road.push(spawn_segment(&mut commands, pair[0], pair[1]));
            }

            // Dispatch a vehicle that follows the path over time.
            let vehicle = commands
                .spawn((
                    Vehicle {
                        speed: 80.0,
                    },
                    Sprite {
                        image: asset_server.load("vehicle.png"),
                        custom_size: Some(Vec2::splat(24.0)),
                        ..default()
                    },
                    PathFollower {
                        waypoints: waypoints.clone(),
                        index: 0,
                    },
                    Transform::from_xyz(src_pos.x, src_pos.y, VEHICLE_Z),
                    VehicleSprite,
                ))
                .id();

            active.active = true;
            active.vehicle = vehicle;
            active.road_entities = road;

            selection.phase = SelectionPhase::Idle;
        }
        None => {
            if let Ok(mut text) = hint.single_mut() {
                *text = Text::new("Yol bulunamadi: hedefe grid uzerinden ulasilamiyor.");
            }
        }
    }
}

fn despawn_delivery(commands: &mut Commands, active: &mut ActiveDelivery) {
    if active.active {
        commands.entity(active.vehicle).despawn();
    }
    for entity in active.road_entities.drain(..) {
        commands.entity(entity).despawn();
    }
    active.active = false;
}

pub fn cleanup_finished_delivery_system(
    mut commands: Commands,
    mut active: ResMut<ActiveDelivery>,
    path_followers: Query<&PathFollower>,
) {
    if !active.active {
        return;
    }

    let Ok(path) = path_followers.get(active.vehicle) else {
        return;
    };

    if path.index < path.waypoints.len() {
        return;
    }

    despawn_delivery(&mut commands, &mut active);
}

/// Mark every cell under a building's 2x2 footprint as blocked.
pub fn collect_cells(
    terrain: &TerrainGrid,
    world: Vec2,
    out: &mut HashSet<(usize, usize)>,
) {
    let snapped = terrain.snap_centre(world, map::BUILDING_FOOTPRINT);
    let Some((cx, cy)) = terrain.world_to_cell(snapped) else {
        return;
    };
    let fx = cx - cx % map::BUILDING_FOOTPRINT;
    let fy = cy - cy % map::BUILDING_FOOTPRINT;
    for y in fy..fy + map::BUILDING_FOOTPRINT {
        for x in fx..fx + map::BUILDING_FOOTPRINT {
            out.insert((x, y));
        }
    }
}

fn within_box(point: Vec2, center: Vec2, half: f32) -> bool {
    (point.x - center.x).abs() <= half && (point.y - center.y).abs() <= half
}

pub fn spawn_segment(commands: &mut Commands, a: Vec2, b: Vec2) -> Entity {
    let delta = b - a;
    let length = delta.length();
    if length < 0.001 {
        return commands.spawn_empty().id();
    }
    let angle = delta.y.atan2(delta.x);
    let mid = a + delta * 0.5;
    commands
        .spawn((
            DeliveryRoadSegment,
            Sprite::from_color(Color::srgb(0.45, 0.35, 0.05), Vec2::new(length, 6.0)),
            Transform {
                translation: Vec3::new(mid.x, mid.y, ROAD_Z),
                rotation: Quat::from_rotation_z(angle),
                ..default()
            },
        ))
        .id()
}