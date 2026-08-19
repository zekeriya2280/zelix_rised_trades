use bevy::prelude::*;

use crate::core::components::{Bank, Factory, Farm, Gatherer, PathFollower, Warehouse};
use crate::core::{GameState, MaterialInventory, ProductType};

#[derive(Component)]
pub struct MoneyText;

#[derive(Component)]
pub struct TimeText;

#[derive(Component)]
pub struct MaterialsText;

#[derive(Component)]
pub struct LogisticsHintText;

pub fn setup_ui_system(mut commands: Commands) {
    commands.spawn((
        Text::new("Money: ¥100000"),
        Node {
            position_type: PositionType::Absolute,
            left: Val::Px(16.0),
            top: Val::Px(16.0),
            ..default()
        },
        MoneyText,
    ));

    commands.spawn((
        Text::new("Time: 0.0"),
        Node {
            position_type: PositionType::Absolute,
            left: Val::Px(16.0),
            top: Val::Px(44.0),
            ..default()
        },
        TimeText,
    ));

    // On-screen material inventory (top-right): every produced raw material.
    commands.spawn((
        Text::new("Wood 0\nStone 0\nIron 0\nGold 0\nGrain 0"),
        TextFont {
            font_size: FontSize::Px(14.0),
            ..default()
        },
        TextColor(Color::srgb(0.9, 0.9, 0.9)),
        Node {
            position_type: PositionType::Absolute,
            top: Val::Px(16.0),
            right: Val::Px(16.0),
            ..default()
        },
        MaterialsText,
    ));

    // Logistics instructions, shown near the top-centre while a delivery is
    // being set up.
    commands.spawn((
        Text::new(""),
        TextFont {
            font_size: FontSize::Px(15.0),
            ..default()
        },
        TextColor(Color::srgb(1.0, 0.9, 0.45)),
        Node {
            position_type: PositionType::Absolute,
            top: Val::Px(80.0),
            left: Val::Percent(40.0),
            ..default()
        },
        LogisticsHintText,
    ));
}

pub fn update_ui_system(
    game: Res<GameState>,
    mut queries: ParamSet<(
        Query<&mut Text, With<MoneyText>>,
        Query<&mut Text, With<TimeText>>,
    )>,
) {
    if let Ok(mut text) = queries.p0().single_mut() {
        *text = Text::new(format!("Money: ¥{}", game.money));
    }

    if let Ok(mut text) = queries.p1().single_mut() {
        *text = Text::new(format!("Time: {:.1}", game.world_time));
    }
}

/// Refresh the on-screen material inventory from the global stockpiles.
pub fn update_materials_hud(
    inventory: Res<MaterialInventory>,
    mut text: Query<&mut Text, With<MaterialsText>>,
) {
    if let Ok(mut t) = text.single_mut() {
        *t = Text::new(format!(
            "Ahsap (Wood): {}\nTas (Stone): {}\nDemir (Iron): {}\nAltin (Gold): {}\nTahil (Grain): {}",
            inventory.get(ProductType::Wood),
            inventory.get(ProductType::Stone),
            inventory.get(ProductType::Iron),
            inventory.get(ProductType::Gold),
            inventory.get(ProductType::Grain),
        ));
    }
}
