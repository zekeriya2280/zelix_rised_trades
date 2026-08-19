pub mod production;
pub mod logistics;

pub use production::*;
pub use logistics::*;

use bevy::prelude::*;

pub struct SimulationPlugin;

impl Plugin for SimulationPlugin {
    fn build(&self, app: &mut App) {
        app.add_systems(
            Update,
            (
                production_tick_system,
                logistics_tick_system,
            ),
        );
    }
}