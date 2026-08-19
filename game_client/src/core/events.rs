use bevy::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Message)]
pub struct BuildBankEvent {
    pub position: Vec3,
}

#[derive(Message)]
pub struct OpenBuildMenuEvent {
    pub position: Vec3,
    /// Exact cursor position in window (logical) pixels, used to place the
    /// build-menu panel precisely where the player right-clicked.
    pub screen_position: Vec2,
}

#[derive(Message)]
pub struct CloseBuildMenuEvent;


#[derive(Message)]
pub struct BuildStructureEvent {
    pub building_type: BuildingType,
    pub position: Vec3,
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum BuildingType {
    Gatherer,
    Factory,
    Warehouse,
    Farm,
}

/// The raw material a factory has been told to produce (chosen via the
/// right-click factory panel).
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Hash, Default)]
#[serde(rename_all = "snake_case")]
pub enum ProductType {
    #[default]
    Wood,
    Stone,
    Iron,
    Gold,
    Grain,
}

impl ProductType {
    pub const ALL: [ProductType; 5] = [
        ProductType::Wood,
        ProductType::Stone,
        ProductType::Iron,
        ProductType::Gold,
        ProductType::Grain,
    ];

    pub fn label(self) -> &'static str {
        match self {
            ProductType::Wood => "Wood",
            ProductType::Stone => "Stone",
            ProductType::Iron => "Iron",
            ProductType::Gold => "Gold",
            ProductType::Grain => "Grain",
        }
    }

    /// Sell value of one produced unit, so choosing a material matters.
    pub fn value(self) -> i64 {
        match self {
            ProductType::Wood => 80,
            ProductType::Stone => 90,
            ProductType::Iron => 140,
            ProductType::Gold => 220,
            ProductType::Grain => 70,
        }
    }
}

/// Right-clicking a factory opens its "which raw material?" panel.
#[derive(Message)]
pub struct OpenFactoryMenuEvent {
    pub entity: Entity,
    pub screen_position: Vec2,
}

#[derive(Message)]
pub struct CloseFactoryMenuEvent;

/// The player picked a raw material from the factory panel.
#[derive(Message)]
pub struct SetFactoryProductEvent {
    pub entity: Entity,
    pub product: ProductType,
}
