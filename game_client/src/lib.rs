use bevy::prelude::*;
use bevy::window::WindowResolution;

mod app;
mod core;
mod network;
mod simulation;
mod render;
mod mobile;
mod frontend;

pub fn run() {
    App::new()
        .insert_resource(ClearColor(Color::srgb(0.08, 0.09, 0.11)))
        .add_plugins(
            DefaultPlugins.set(WindowPlugin {
                primary_window: Some(Window {
                    title: "Zelix Rised Trades".into(),
                    resolution: WindowResolution::new(2560, 1600),
                    resizable: true,
                    present_mode: bevy::window::PresentMode::AutoVsync,
                    ..default()
                }),
                ..default()
            }),
        )
        .add_plugins(app::GameAppPlugin)
        .run();
}
