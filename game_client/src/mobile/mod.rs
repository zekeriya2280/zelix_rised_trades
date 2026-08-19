pub mod touch;
pub mod scaling;

pub use touch::*;
pub use scaling::*;

use bevy::prelude::*;

pub struct MobilePlugin;

impl Plugin for MobilePlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<TouchState>()
            .init_resource::<UiScaleSettings>()
            .add_systems(Update, (touch_input_system, ui_scaling_system));
    }
}