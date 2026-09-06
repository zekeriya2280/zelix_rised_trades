pub mod auth;
pub mod protocol;
pub mod websocket;

pub use auth::*;
pub use websocket::*;

use bevy::prelude::*;

pub struct NetworkPlugin;

impl Plugin for NetworkPlugin {
fn build(&self, app: &mut App) {
app.insert_resource(auth::make_auth_client())
.init_resource::<NetworkClient>()
.init_resource::<OnlineAuthority>()
.init_resource::<websocket::PendingSnapshot>()
.add_systems(
Update,
(
websocket_connect_system,
websocket_receive_system,
websocket_send_system,
forward_build_events_system,
apply_snapshot_system,
poll_auth_responses_system,
),
);
}
}
