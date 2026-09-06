use bevy::{math::Isometry2d, prelude::*};

use crate::core::components::{
    Bank, CityRadius, Factory, Farm, Gatherer, PlacementPreview, Warehouse,
};
use crate::core::events::{BuildBankEvent, BuildStructureEvent, BuildingType, ProductType};
use crate::render::map::{TerrainGrid, BUILDING_FOOTPRINT, BUILDING_SIZE, BUILDING_Z, MIN_BUILDING_DISTANCE};
use crate::network::OnlineAuthority;

pub const CITY_RADIUS: f32 = 300.0;
const BANK_COST: i64 = 10_000;
const GATHERER_COST: i64 = 5_000;
const FACTORY_COST: i64 = 20_000;
const WAREHOUSE_COST: i64 = 8_000;
const FARM_COST: i64 = 12_000;

pub fn placement_preview_system(
    mut commands: Commands,
    preview_query: Query<Entity, With<PlacementPreview>>,
) {
    for entity in &preview_query {
        commands.entity(entity).despawn();
    }
}

pub fn build_bank_system(
    mut commands: Commands,
    mut game_state: ResMut<crate::core::resources::GameState>,
    asset_server: Res<AssetServer>,
    mut event: MessageReader<BuildBankEvent>,
    banks: Query<(), With<Bank>>,
    terrain: Res<TerrainGrid>,
    authority: Res<OnlineAuthority>,
) {
    if authority.active || banks.iter().next().is_some() {
        return;
    }

    for ev in event.read() {
        if game_state.money < BANK_COST {
            continue;
        }

        // Snap to the 2x2 grid and refuse to sit on a mountain or sea.
        let snapped = terrain.snap_centre(ev.position.truncate(), BUILDING_FOOTPRINT);
        if !terrain.can_place_footprint(snapped, BUILDING_FOOTPRINT) {
            continue;
        }

        game_state.money -= BANK_COST;

        commands.spawn((
            Bank,
            CityRadius { radius: CITY_RADIUS },
            Sprite {
                image: asset_server.load("bank.png"),
                custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                ..default()
            },
            Transform::from_xyz(snapped.x, snapped.y, BUILDING_Z),
        ));
    }
}

pub fn draw_bank_radius_system(
    mut gizmos: Gizmos,
    banks: Query<(&GlobalTransform, &CityRadius), With<Bank>>,
) {
    // Only the bank-centered first city is highlighted with a red circle.
    for (transform, radius) in &banks {
        let center = transform.translation().truncate();
        gizmos
            .circle_2d(
                Isometry2d::from_translation(center),
                radius.radius,
                Color::srgba(1.0, 0.0, 0.0, 0.5),
            )
            .resolution(128);
    }
}

pub fn build_structure_system(
    mut commands: Commands,
    mut game: ResMut<crate::core::resources::GameState>,
    asset_server: Res<AssetServer>,
    mut events: MessageReader<BuildStructureEvent>,
    banks: Query<&GlobalTransform, With<Bank>>,
    warehouses: Query<&GlobalTransform, With<Warehouse>>,
    factories: Query<&GlobalTransform, With<Factory>>,
    gatherers: Query<&GlobalTransform, With<Gatherer>>,
    farms: Query<&GlobalTransform, With<Farm>>,
    terrain: Res<TerrainGrid>,
    mut message: Query<&mut Text, With<crate::render::build_menu::BuildMenuMessage>>,
    authority: Res<OnlineAuthority>,
) {
    if authority.active { return; }

    for event in events.read() {
        // Snap to the 2x2 grid so buildings line up cleanly.
        let position = terrain.snap_centre(event.position.truncate(), BUILDING_FOOTPRINT);

        let bank_center = banks.iter().next().map(|t| t.translation().truncate());
        let inside_city = bank_center
            .map(|center| center.distance(position) <= CITY_RADIUS)
            .unwrap_or(false);

        let cost = match event.building_type {
            BuildingType::Gatherer => GATHERER_COST,
            BuildingType::Factory => FACTORY_COST,
            BuildingType::Warehouse => WAREHOUSE_COST,
            BuildingType::Farm => FARM_COST,
        };

        if game.money < cost {
            set_message(
                &mut message,
                "Hata: Yeterli paran yok.",
            );
            continue;
        }

        // No building may ever be placed on a mountain or the sea.
        if !terrain.can_place_footprint(position, BUILDING_FOOTPRINT) {
            set_message(
                &mut message,
                "Hata: Dağ veya deniz üzerine bina yapılamaz.",
            );
            continue;
        }

        // Buildings must keep a minimum distance from every existing building
        // (bank, warehouse, factory, gatherer and farm), so they don't overlap
        // and streets/spaces remain between them.
        let too_close = banks
            .iter()
            .chain(warehouses.iter())
            .chain(factories.iter())
            .chain(gatherers.iter())
            .chain(farms.iter())
            .any(|transform| {
                transform
                    .translation()
                    .truncate()
                    .distance(position) < MIN_BUILDING_DISTANCE
            });

        if too_close {
            set_message(
                &mut message,
                "Hata: Binalar arası en az 50 birim mesafe olmalı.",
            );
            continue;
        }

        // Inside the bank's 300 radius, all four building types are allowed.
        // Outside it, only Warehouse is legal.
        if !inside_city && event.building_type != BuildingType::Warehouse {
            set_message(
                &mut message,
                "Hata: Şehir dışında sadece Warehouse kurulabilir.",
            );
            continue;
        }

        // The first outside-city warehouse must be within 300 of an existing
        // warehouse. Once the chain exists, every next warehouse can extend
        // the chain by another 300 world units.
        if !inside_city && event.building_type == BuildingType::Warehouse {
            let reachable = bank_center
                .map(|center| center.distance(position) <= CITY_RADIUS)
                .unwrap_or(false)
                || warehouses
                    .iter()
                    .any(|transform| transform.translation().truncate().distance(position) <= CITY_RADIUS);

            if !reachable {
                set_message(
                    &mut message,
                    "Hata: Warehouse, Bank'a veya mevcut bir Warehouse'a en fazla 300 birim uzakta olmalı.",
                );
                continue;
            }
        }

        game.money -= cost;

        match event.building_type {
            BuildingType::Warehouse => {
                commands.spawn((
                    Warehouse,
                    Sprite {
                        image: asset_server.load("warehouse.png"),
                        custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                        ..default()
                    },
                    Transform::from_xyz(position.x, position.y, BUILDING_Z),
                ));
            }
            BuildingType::Factory => {
                let id = next_id();
                commands.spawn((
                    Factory { id, level: 1, product: ProductType::Wood },
                    Sprite {
                        image: asset_server.load("factory.png"),
                        custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                        ..default()
                    },
                    Transform::from_xyz(position.x, position.y, BUILDING_Z),
                ));
            }
            BuildingType::Gatherer => {
                commands.spawn((
                    Gatherer,
                    Sprite {
                        image: asset_server.load("gatherer.png"),
                        custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                        ..default()
                    },
                    Transform::from_xyz(position.x, position.y, BUILDING_Z),
                ));
            }
            BuildingType::Farm => {
                commands.spawn((
                    Farm,
                    Sprite {
                        image: asset_server.load("farm.png"),
                        custom_size: Some(Vec2::splat(BUILDING_SIZE)),
                        ..default()
                    },
                    Transform::from_xyz(position.x, position.y, BUILDING_Z),
                ));
            }
        }

        set_message(&mut message, "");
    }
}

fn set_message(message: &mut Query<&mut Text, With<crate::render::build_menu::BuildMenuMessage>>, value: &str) {
    if let Ok(mut text) = message.single_mut() {
        *text = Text::new(value);
    }
}

fn next_id() -> u64 {
    use std::sync::atomic::{AtomicU64, Ordering};
    static NEXT_ID: AtomicU64 = AtomicU64::new(10);
    NEXT_ID.fetch_add(1, Ordering::Relaxed)
}
