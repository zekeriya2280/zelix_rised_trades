use bevy::prelude::*;
use std::f32::consts::FRAC_PI_2;

use crate::core::PathFollower;

#[derive(Component)]
pub struct VehicleSprite;

pub fn update_vehicle_visuals_system(
    mut query: Query<(&mut Transform, &PathFollower), With<VehicleSprite>>,
) {
    for (mut transform, path) in &mut query {
        if path.index >= path.waypoints.len() {
            continue;
        }
        let target = path.waypoints[path.index];
        let direction = target - transform.translation.truncate();

        if direction.length_squared() > 0.0001 {
            // vehicle.png is drawn pointing up (+Y); subtract 90° so it points
            // along the actual travel direction.
            let angle = direction.y.atan2(direction.x) - FRAC_PI_2;
            transform.rotation = Quat::from_rotation_z(angle);
        }
    }
}