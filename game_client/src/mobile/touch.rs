use bevy::prelude::*;

use crate::render::camera::MainCamera;

#[derive(Resource, Default)]
pub struct TouchState {
    pub world_position: Vec2,
    pub pressed: bool,
    pub last_screen_position: Option<Vec2>,
}

pub fn touch_input_system(
    touches: Res<Touches>,
    camera_query: Query<(&Camera, &GlobalTransform), With<Camera2d>>,
    mut camera_transform: Query<&mut Transform, With<MainCamera>>,
    mut state: ResMut<TouchState>,
) {
    state.pressed = false;

    let Ok((camera, camera_transform_2d)) = camera_query.single() else {
        state.last_screen_position = None;
        return;
    };

    let Some(touch) = touches.iter().next() else {
        state.last_screen_position = None;
        return;
    };

    let screen_pos = touch.position();
    if let Ok(world_pos) = camera.viewport_to_world_2d(camera_transform_2d, screen_pos) {
        state.world_position = world_pos;
        state.pressed = true;
    }

    if let Some(last) = state.last_screen_position {
        let delta = screen_pos - last;
        if let Ok(mut transform) = camera_transform.single_mut() {
            transform.translation.x -= delta.x;
            transform.translation.y += delta.y;
        }
    }
    state.last_screen_position = Some(screen_pos);
}
