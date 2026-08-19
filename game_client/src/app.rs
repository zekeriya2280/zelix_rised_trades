use bevy::prelude::*;

use crate::core::{GameState, MaterialInventory};
use crate::frontend::FrontendPlugin;
use crate::mobile::MobilePlugin;
use crate::network::NetworkPlugin;
use crate::render::RenderPlugin;
use crate::simulation::SimulationPlugin;

pub struct GameAppPlugin;

impl Plugin for GameAppPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<GameState>()
            .init_resource::<MaterialInventory>()
            .add_plugins((
                RenderPlugin,
                SimulationPlugin,
                NetworkPlugin,
                MobilePlugin,
                FrontendPlugin,
            ));
    }
}
