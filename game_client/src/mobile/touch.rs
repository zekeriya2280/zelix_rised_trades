use bevy::prelude::*;

#[derive(Resource, Default)]
pub struct TouchState {
    pub world_position: Vec2,
    pub pressed: bool,
}

pub fn touch_input_system(
    touches: Res<Touches>,
    camera_query: Query<(&Camera, &GlobalTransform), With<Camera2d>>,
    mut state: ResMut<TouchState>,
) {
    state.pressed = false;

    let Ok((camera, camera_transform)) = camera_query.single() else {
        return;
    };

    if let Some(touch) = touches.iter().next() {
        if let Ok(world_pos) =
            camera.viewport_to_world_2d(camera_transform, touch.position())
        {
            state.world_position = world_pos;
            state.pressed = true;
        }
    }
}