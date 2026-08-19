pub mod auth;
pub mod protocol;
pub mod websocket;

pub use auth::*;
pub use websocket::*;

use bevy::prelude::*;
use crossbeam_channel::unbounded;

pub struct NetworkPlugin;

impl Plugin for NetworkPlugin {
    fn build(&self, app: &mut App) {
        let server = auth::server_base();
        let (request_tx, request_rx) = unbounded::<AuthRequest>();
        let (response_tx, response_rx) = unbounded::<AuthResponse>();
        std::thread::spawn(move || auth::auth_worker(request_rx, response_tx, server));

        app.insert_resource(AuthClient { requests: request_tx, responses: response_rx })
            .init_resource::<NetworkClient>()
            .init_resource::<OnlineAuthority>()
            .init_resource::<websocket::PendingSnapshot>()
            .add_systems(Update, (
                websocket_connect_system,
                websocket_receive_system,
                websocket_send_system,
                forward_build_events_system,
                apply_snapshot_system,
                poll_auth_responses_system,
            ));
    }
}
