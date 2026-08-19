use bevy::prelude::*;
use std::collections::HashMap;

use crate::core::{Factory, GameState, MaterialInventory};
use crate::network::OnlineAuthority;

#[derive(Resource)]
pub struct ProductionState {
    pub progress: HashMap<u64, f32>,
    pub interval: f32,
}

impl Default for ProductionState {
    fn default() -> Self {
        Self {
            progress: HashMap::new(),
            interval: 5.0,
        }
    }
}

pub fn production_tick_system(
    time: Res<Time>,
    mut state: Local<ProductionState>,
    mut game: ResMut<GameState>,
    mut inventory: ResMut<MaterialInventory>,
    factories: Query<&Factory>,
    authority: Res<OnlineAuthority>,
) {
    if game.paused || authority.active {
        return;
    }

    let dt = time.delta_secs();

    // interval değerini progress üzerindeki mutable borrow'dan önce alıyoruz.
    let interval = state.interval;

    for factory in &factories {
        let progress = state.progress.entry(factory.id).or_insert(0.0);

        *progress += dt;

        if *progress >= interval {
            *progress = 0.0;

            // Reward depends on which raw material the factory produces, and
            // the produced unit is added to the on-screen material inventory.
            game.money += factory.product.value() * factory.level as i64;
            inventory.add(factory.product, factory.level as u32);
        }
    }

    game.world_time += dt as f64;
}