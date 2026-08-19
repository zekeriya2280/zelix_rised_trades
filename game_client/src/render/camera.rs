use bevy::input::mouse::MouseWheel;
use bevy::prelude::*;

use crate::render::build_menu::BuildMenuState;

#[derive(Component)]
pub struct MainCamera;

#[derive(Resource)]
pub struct CameraState {
    pub zoom: f32,
    pub min_zoom: f32,
    pub max_zoom: f32,
    pub last_mouse_pos: Option<Vec2>,
}

impl Default for CameraState {
    fn default() -> Self {
        Self {
            zoom: 1.0,
            min_zoom: 0.25,
            max_zoom: 3.0,
            last_mouse_pos: None,
        }
    }
}

pub fn setup_camera_system(mut commands: Commands) {
    commands.spawn((
        Camera2d,
        MainCamera,
        Transform::from_xyz(0.0, 0.0, 100.0),
        Projection::Orthographic(OrthographicProjection::default_2d()),
    ));
}

pub fn camera_pan_system(
    keyboard: Res<ButtonInput<KeyCode>>,
    time: Res<Time>,
    mut query: Query<&mut Transform, With<MainCamera>>,
) {
    let Ok(mut transform) = query.single_mut() else {
        return;
    };

    let speed = 500.0 * time.delta_secs();

    if keyboard.pressed(KeyCode::KeyW) || keyboard.pressed(KeyCode::ArrowUp) {
        transform.translation.y += speed;
    }
    if keyboard.pressed(KeyCode::KeyS) || keyboard.pressed(KeyCode::ArrowDown) {
        transform.translation.y -= speed;
    }
    if keyboard.pressed(KeyCode::KeyA) || keyboard.pressed(KeyCode::ArrowLeft) {
        transform.translation.x -= speed;
    }
    if keyboard.pressed(KeyCode::KeyD) || keyboard.pressed(KeyCode::ArrowRight) {
        transform.translation.x += speed;
    }
}

pub fn camera_mouse_pan_system(
    mouse: Res<ButtonInput<MouseButton>>,
    windows: Query<&Window>,
    menu_state: Res<BuildMenuState>,
    mut camera_state: ResMut<CameraState>,
    mut query: Query<&mut Transform, With<MainCamera>>,
) {
    let Ok(mut transform) = query.single_mut() else {
        return;
    };

    let Ok(window) = windows.single() else {
        return;
    };

    let Some(current_pos) = window.cursor_position() else {
        camera_state.last_mouse_pos = None;
        return;
    };

    let dragging = mouse.pressed(MouseButton::Middle)
        || (mouse.pressed(MouseButton::Left) && !menu_state.is_open);

    if dragging {
        if let Some(last_pos) = camera_state.last_mouse_pos {
            let delta = current_pos - last_pos;
            transform.translation.x -= delta.x;
            transform.translation.y += delta.y;
        }
        camera_state.last_mouse_pos = Some(current_pos);
    } else {
        camera_state.last_mouse_pos = None;
    }
}

pub fn camera_zoom_system(
    keyboard: Res<ButtonInput<KeyCode>>,
    mut camera_state: ResMut<CameraState>,
    mut query: Query<&mut Projection, With<MainCamera>>,
) {
    let Ok(mut projection) = query.single_mut() else {
        return;
    };

    if keyboard.just_pressed(KeyCode::Equal) || keyboard.just_pressed(KeyCode::NumpadAdd) {
        camera_state.zoom *= 0.9;
    }
    if keyboard.just_pressed(KeyCode::Minus) || keyboard.just_pressed(KeyCode::NumpadSubtract) {
        camera_state.zoom *= 1.1;
    }

    camera_state.zoom = camera_state
        .zoom
        .clamp(camera_state.min_zoom, camera_state.max_zoom);

    if let Projection::Orthographic(ortho) = &mut *projection {
        ortho.scale = camera_state.zoom;
    }
}

/// Zoom the camera with the mouse wheel. Wheeling up zooms in, wheeling down
/// zooms out.
pub fn camera_mouse_zoom_system(
    mut scroll: MessageReader<MouseWheel>,
    mut camera_state: ResMut<CameraState>,
    mut projection: Query<&mut Projection, With<MainCamera>>,
) {
    let mut changed = false;
    for ev in scroll.read() {
        if ev.y > 0.0 {
            camera_state.zoom *= 0.9;
        } else if ev.y < 0.0 {
            camera_state.zoom *= 1.1;
        }
        changed = true;
    }
    if !changed {
        return;
    }

    camera_state.zoom = camera_state
        .zoom
        .clamp(camera_state.min_zoom, camera_state.max_zoom);

    let Ok(mut projection) = projection.single_mut() else {
        return;
    };
    if let Projection::Orthographic(ortho) = &mut *projection {
        ortho.scale = camera_state.zoom;
    }
}

