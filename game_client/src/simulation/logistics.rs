use bevy::prelude::*;

use crate::core::{PathFollower, Vehicle};

pub fn logistics_tick_system(
    time: Res<Time>,
    mut query: Query<(&mut Transform, &Vehicle, &mut PathFollower)>,
) {
    let dt = time.delta_secs();

    for (mut transform, vehicle, mut path) in &mut query {
        if path.index >= path.waypoints.len() {
            continue;
        }

        let target = path.waypoints[path.index];
        let current = transform.translation;
        let direction = target - current.truncate();
        let distance = direction.length();

        if distance <= 1.0 {
            transform.translation = Vec3::new(target.x, target.y, current.z);
            path.index += 1;
            continue;
        }

        let step = vehicle.speed * dt;
        let movement = direction.normalize() * step.min(distance);
        transform.translation.x += movement.x;
        transform.translation.y += movement.y;
    }
}