use bevy::prelude::*;
use crossbeam_channel::{Receiver, Sender};
use serde::{Deserialize, Serialize};

use crate::core::GameState;
use crate::frontend::{AuthStore, FrontendState, Screen, UserAccount};

#[derive(Clone, Debug)]
pub enum AuthRequest {
    Register { email: String, password: String, nickname: String },
    Login { email: String, password: String },
}

#[derive(Clone, Debug)]
pub struct AuthResponse {
    pub ok: bool,
    pub message: String,
    pub nickname: String,
    pub token: String,
}

#[derive(Resource)]
pub struct AuthClient {
    pub requests: Sender<AuthRequest>,
    pub responses: Receiver<AuthResponse>,
}

#[derive(Serialize)]
struct AuthForm<'a> {
    email: &'a str,
    password: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    nickname: Option<&'a str>,
}

#[derive(Deserialize)]
struct AuthPayload {
    ok: bool,
    message: String,
    #[serde(default)]
    nickname: String,
    #[serde(default)]
    token: String,
}

pub fn request_login(client: &AuthClient, email: &str, password: &str) {
    let _ = client.requests.send(AuthRequest::Login {
        email: email.trim().to_string(),
        password: password.to_string(),
    });
}

pub fn request_register(client: &AuthClient, email: &str, password: &str, nickname: &str) {
    let _ = client.requests.send(AuthRequest::Register {
        email: email.trim().to_string(),
        password: password.to_string(),
        nickname: nickname.trim().to_string(),
    });
}

pub fn auth_worker(
    requests: Receiver<AuthRequest>,
    responses: Sender<AuthResponse>,
    server: String,
) {
    while let Ok(request) = requests.recv() {
        let response = match request {
            AuthRequest::Login { email, password } => post_form(&server, "login", &email, &password, None),
            AuthRequest::Register { email, password, nickname } => {
                post_form(&server, "register", &email, &password, Some(&nickname))
            }
        };
        let _ = responses.send(response);
    }
}

pub fn poll_auth_responses_system(
    client: Res<AuthClient>,
    mut state: ResMut<FrontendState>,
    mut auth: ResMut<AuthStore>,
    mut game: ResMut<GameState>,
) {
    while let Ok(response) = client.responses.try_recv() {
        if response.ok {
            let email = match state.screen {
                Screen::Login => state.login_email.trim().to_string(),
                Screen::Register => state.register_email.trim().to_string(),
                _ => String::new(),
            };
            auth.current_user = Some(UserAccount {
                email,
                nickname: response.nickname,
                token: response.token,
            });
            state.login_password.clear();
            state.register_password.clear();
            state.screen = Screen::Intro;
            state.active_field = None;
            state.message = response.message;
            game.paused = true;
        } else {
            state.message = response.message;
        }
    }
}

fn post_form(
    server: &str,
    path: &str,
    email: &str,
    password: &str,
    nickname: Option<&str>,
) -> AuthResponse {
    let url = format!("{server}/auth/{path}");
    let body = match serde_json::to_string(&AuthForm { email, password, nickname }) {
        Ok(body) => body,
        Err(error) => return failed(format!("Request serialisation failed: {error}")),
    };

        let result = ureq::post(&url)
        .set("Content-Type", "application/json")
        .send_string(&body)
        .map_err(|error| error.to_string())
        .and_then(|response| response.into_json::<AuthPayload>().map_err(|error| error.to_string()));

    match result {
        Ok(payload) => AuthResponse {
            ok: payload.ok,
            message: payload.message,
            nickname: payload.nickname,
            token: payload.token,
        },
        Err(error) => failed(format!("Auth service error: {error}")),
    }
}

fn failed(message: String) -> AuthResponse {
    AuthResponse { ok: false, message, nickname: String::new(), token: String::new() }
}

pub fn server_base() -> String {
    std::env::var("GAME_SERVER_URL").unwrap_or_else(|_| "http://127.0.0.1:8765".to_string())
}
