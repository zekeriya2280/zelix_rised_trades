use bevy::prelude::*;
use std::collections::HashMap;

use crate::core::events::ProductType;

#[derive(Resource)]
pub struct GameState {
    pub money: i64,
    pub world_time: f64,
    pub paused: bool,
    /// Last authoritative server tick received in online mode.
    pub server_tick: u64,
}

impl Default for GameState {
    fn default() -> Self {
        Self {
            money: 100_000,
            world_time: 0.0,
            paused: true,
            server_tick: 0,
        }
    }
}

/// Running totals of each produced raw material, shown live in the HUD.
#[derive(Resource, Default)]
pub struct MaterialInventory {
    pub counts: HashMap<ProductType, u32>,
}

impl MaterialInventory {
    pub fn add(&mut self, product: ProductType, amount: u32) {
        *self.counts.entry(product).or_insert(0) += amount;
    }

    pub fn get(&self, product: ProductType) -> u32 {
        self.counts.get(&product).copied().unwrap_or(0)
    }
}