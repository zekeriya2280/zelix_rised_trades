use bevy::prelude::*;

use crate::core::events::ProductType;

/// Authoritative identity supplied by the game server. Client code must never
/// invent or mutate these ids in online mode.
#[derive(Component, Clone, Copy, Debug, PartialEq, Eq)]
pub struct ServerId(pub u64);

/// Ownership supplied by the server. Used only for presentation/interaction
/// filtering; gameplay authorization remains server-side.
#[derive(Component, Clone, Copy, Debug, PartialEq, Eq)]
pub struct OwnerId(pub u64);

#[derive(Component)]
pub struct Vehicle {
    pub speed: f32,
}

#[derive(Component)]
pub struct Factory {
    pub id: u64,
    pub level: u8,
    /// The raw material this factory currently produces.
    pub product: ProductType,
}

#[derive(Component)]
pub struct Warehouse;

/// A vehicle that follows an ordered list of grid cell-centre waypoints.
#[derive(Component)]
pub struct PathFollower {
    pub waypoints: Vec<Vec2>,
    pub index: usize,
}

#[derive(Component)]
pub struct Bank;

#[derive(Component)]
pub struct Farm;

#[derive(Component)]
pub struct Gatherer;

#[derive(Component)]
pub struct CityRadius {
    pub radius: f32,
}

#[derive(Component)]
pub struct PlacementPreview;
