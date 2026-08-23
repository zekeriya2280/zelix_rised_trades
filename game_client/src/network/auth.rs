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
    pub responses: Receiver<AuthResponse>,
    #[cfg(not(target_arch = "wasm32"))]
    requests: Sender<AuthRequest>,
    #[cfg(target_arch = "wasm32")]
    response_tx: Sender<AuthResponse>,
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

pub fn make_auth_client() -> AuthClient {
    let (response_tx, response_rx) = crossbeam_channel::unbounded::<AuthResponse>();
    #[cfg(not(target_arch = "wasm32"))]
    {
        let (request_tx, request_rx) = crossbeam_channel::unbounded::<AuthRequest>();
        let server = server_base();
        std::thread::spawn(move || auth_worker(request_rx, response_tx, server));
        return AuthClient { responses: response_rx, requests: request_tx };
    }
    #[cfg(target_arch = "wasm32")]
    {
        return AuthClient { responses: response_rx, response_tx };
    }
}

pub fn request_login(client: &AuthClient, email: &str, password: &str) {
    #[cfg(not(target_arch = "wasm32"))]
    {
        let _ = client.requests.send(AuthRequest::Login { email: email.trim().to_string(), password: password.to_string() });
    }
    #[cfg(target_arch = "wasm32")]
    {
        let sender = client.response_tx.clone();
        let server = server_base();
        let email = email.trim().to_string();
        let password = password.to_string();
        wasm_bindgen_futures::spawn_local(async move {
            let response = web_post_form(&server, "login", &email, &password, None).await;
            let _ = sender.send(response);
        });
    }
}

pub fn request_register(client: &AuthClient, email: &str, password: &str, nickname: &str) {
    #[cfg(not(target_arch = "wasm32"))]
    {
        let _ = client.requests.send(AuthRequest::Register {
            email: email.trim().to_string(), password: password.to_string(), nickname: nickname.trim().to_string(),
        });
    }
    #[cfg(target_arch = "wasm32")]
    {
        let sender = client.response_tx.clone();
        let server = server_base();
        let email = email.trim().to_string();
        let password = password.to_string();
        let nickname = nickname.trim().to_string();
        wasm_bindgen_futures::spawn_local(async move {
            let response = web_post_form(&server, "register", &email, &password, Some(&nickname)).await;
            let _ = sender.send(response);
        });
    }
}

#[cfg(not(target_arch = "wasm32"))]
pub fn auth_worker(requests: Receiver<AuthRequest>, responses: Sender<AuthResponse>, server: String) {
    while let Ok(request) = requests.recv() {
        let response = match request {
            AuthRequest::Login { email, password } => post_form(&server, "login", &email, &password, None),
            AuthRequest::Register { email, password, nickname } => post_form(&server, "register", &email, &password, Some(&nickname)),
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
            auth.current_user = Some(UserAccount { email, nickname: response.nickname, token: response.token });
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

#[cfg(not(target_arch = "wasm32"))]
fn post_form(server: &str, path: &str, email: &str, password: &str, nickname: Option<&str>) -> AuthResponse {
    let url = format!("{server}/auth/{path}");
    let body = match serde_json::to_string(&AuthForm { email, password, nickname }) {
        Ok(body) => body,
        Err(error) => return failed(format!("Request serialisation failed: {error}")),
    };
    match ureq::post(&url).set("Content-Type", "application/json").send_string(&body) {
        Ok(response) => match response.into_json::<AuthPayload>() {
            Ok(payload) => AuthResponse { ok: payload.ok, message: payload.message, nickname: payload.nickname, token: payload.token },
            Err(error) => failed(format!("Auth service returned invalid JSON: {error}")),
        },
        Err(ureq::Error::Status(code, response)) => match response.into_json::<AuthPayload>() {
            Ok(payload) if !payload.message.is_empty() => failed(format!("{code}: {}", payload.message)),
            _ => failed(format!("Auth service returned HTTP {code}.")),
        },
        Err(error) => failed(format!("Auth service error: {error}")),
    }
}

#[cfg(target_arch = "wasm32")]
async fn web_post_form(server: &str, path: &str, email: &str, password: &str, nickname: Option<&str>) -> AuthResponse {
    let url = format!("{server}/auth/{path}");
    let body = match serde_json::to_string(&AuthForm { email, password, nickname }) {
        Ok(body) => body,
        Err(error) => return failed(format!("Request serialisation failed: {error}")),
    };
    let request = match gloo_net::http::Request::post(&url).header("Content-Type", "application/json").body(body) {
        Ok(request) => request,
        Err(error) => return failed(format!("Auth request could not be created: {error}")),
    };
    let response = match request.send().await {
        Ok(response) => response,
        Err(error) => return failed(format!("Auth service error: {error}")),
    };
    let status = response.status();
    let text = match response.text().await {
        Ok(text) => text,
        Err(error) => return failed(format!("Auth service returned unreadable data: {error}")),
    };
    match serde_json::from_str::<AuthPayload>(&text) {
        Ok(payload) if status < 400 => AuthResponse { ok: payload.ok, message: payload.message, nickname: payload.nickname, token: payload.token },
        Ok(payload) => failed(format!("{status}: {}", payload.message)),
        Err(error) => failed(format!("Auth service returned invalid JSON ({status}): {error}")),
    }
}

fn failed(message: String) -> AuthResponse { AuthResponse { ok: false, message, nickname: String::new(), token: String::new() } }

#[derive(Deserialize)] struct GameClientConfig { #[serde(default)] server_url: String }

pub fn server_base() -> String {
    #[cfg(not(target_arch = "wasm32"))]
    {
        if let Some(value) = option_env!("GAME_SERVER_URL") {
            if !value.trim().is_empty() {
                return value.trim().trim_end_matches('/').to_string();
            }
        }
        if let Ok(value) = std::env::var("GAME_SERVER_URL") { if !value.trim().is_empty() { return value.trim().trim_end_matches('/').to_string(); } }
        for path in ["game_config.json", "assets/game_config.json"] {
            if let Ok(text) = std::fs::read_to_string(path) {
                if let Ok(config) = serde_json::from_str::<GameClientConfig>(&text) {
                    if !config.server_url.trim().is_empty() {
                        return config.server_url.trim().trim_end_matches('/').to_string();
                    }
                }
            }
        }
        return "http://127.0.0.1:8765".into();
    }
    #[cfg(target_arch = "wasm32")]
    {
        if let Some(value) = option_env!("GAME_SERVER_URL") { if !value.trim().is_empty() { return value.trim().trim_end_matches('/').to_string(); } }
        if let Some(window) = web_sys::window() {
            let location = window.location();
            if let (Ok(protocol), Ok(host)) = (location.protocol(), location.host()) {
                let scheme = if protocol == "https:" { "https" } else { "http" };
                return format!("{scheme}://{host}");
            }
        }
        "http://127.0.0.1:8765".into()
    }
}
