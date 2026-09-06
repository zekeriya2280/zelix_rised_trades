use bevy::prelude::*;
use std::f32::consts::FRAC_PI_2;

use crate::core::PathFollower;

#[derive(Component)]
pub struct VehicleSprite;

/// Rotate the vehicle toward its immediate authoritative path segment.
/// The previous implementation pointed toward the final destination, which
/// makes a vehicle face the wrong direction on every bend of a 4-way route.
pub fn update_vehicle_visuals_system(
    mut query: Query<(&mut Transform, &PathFollower), With<VehicleSprite>>,
) {
    for (mut transform, path) in &mut query {
        if path.index >= path.waypoints.len() {
            continue;
        }

        let target = path.waypoints[path.index];
        if !target.x.is_finite() || !target.y.is_finite() {
            continue;
        }

        let current = transform.translation.truncate();
        let direction = target - current;
        if !direction.x.is_finite() || !direction.y.is_finite() {
            continue;
        }

        if direction.length_squared() > 0.0001 {
            // vehicle.png points up (+Y), so subtract 90° to align its nose
            // with the actual travel vector. This is based on the NEXT path
            // waypoint, not the final destination.
            let angle = direction.y.atan2(direction.x) - FRAC_PI_2;
            transform.rotation = Quat::from_rotation_z(angle);
        }
    }
}
