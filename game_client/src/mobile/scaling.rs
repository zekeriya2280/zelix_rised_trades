use bevy::prelude::*;

#[derive(Resource)]
pub struct UiScaleSettings {
    pub scale: f32,
}

impl Default for UiScaleSettings {
    fn default() -> Self {
        Self { scale: 1.0 }
    }
}

pub fn ui_scaling_system(
    windows: Query<&Window>,
    mut settings: ResMut<UiScaleSettings>,
) {
    let Ok(window) = windows.single() else {
        return;
    };

    // A single resource keeps layout decisions deterministic across Android/Web/Desktop.
    // Individual UI panels can consume this value without duplicating breakpoint logic.
    settings.scale = if window.width() < 900.0 { 1.25 } else { 1.0 };
}