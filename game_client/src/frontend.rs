use bevy::input::keyboard::{KeyboardInput, Key};
use bevy::prelude::*;

use crate::core::resources::GameState;
use crate::network::auth::{request_login, request_register, AuthClient};
use crate::network::NetworkClient;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Default)]
pub enum Screen {
    #[default]
    AuthGate,
    Login,
    Register,
    Intro,
    Lobby,
    Settings,
    Game,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum AuthField {
    LoginEmail,
    LoginPassword,
    RegisterEmail,
    RegisterPassword,
    RegisterNickname,
    RoomCode,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum LobbyMode {
    #[allow(dead_code)]
    SinglePlayer,
    Multiplayer,
    Online,
}

impl LobbyMode {
    fn label(self) -> &'static str {
        match self {
            LobbyMode::SinglePlayer => "Single Player",
            LobbyMode::Multiplayer => "Multiplayer",
            LobbyMode::Online => "Online",
        }
    }
}

/// Which step of the lobby the user is currently on. The lobby is split into a
/// menu ("Choice") plus a dedicated Create Room panel and Enter Room panel, so
/// the player can first make a selection and then confirm with Create/Enter.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Default)]
pub enum LobbyPanel {
    #[default]
    Choice,
    CreateRoom,
    EnterRoom,
    WaitingRoom,
}

#[derive(Clone, Debug)]
pub struct UserAccount {
    #[allow(dead_code)]
    pub email: String,
    pub nickname: String,
    pub token: String,
}

#[derive(Resource, Default)]
pub struct AuthStore {
    pub current_user: Option<UserAccount>,
}

#[derive(Clone, Debug)]
pub struct Room {
    pub id: String,
    pub host: String,
    pub mode: LobbyMode,
    pub max_players: usize,
    pub players: Vec<String>,
    pub started: bool,
}

#[derive(Resource, Default)]
pub struct LobbyStore {
    pub rooms: Vec<Room>,
}

#[derive(Resource)]
pub struct FrontendState {
    pub screen: Screen,
    pub active_field: Option<AuthField>,
    pub login_email: String,
    pub login_password: String,
    pub register_email: String,
    pub register_password: String,
    pub register_nickname: String,
    pub room_code: String,
    pub message: String,
    pub lobby_message: String,
    pub settings_message: String,
    pub active_lobby_mode: LobbyMode,
    pub lobby_panel: LobbyPanel,
    pub current_room: Option<String>,
    pub current_room_is_host: bool,
    pub pending_auth_email: Option<String>,
}

impl Default for FrontendState {
    fn default() -> Self {
        Self {
            screen: Screen::AuthGate,
            active_field: None,
            login_email: String::new(),
            login_password: String::new(),
            register_email: String::new(),
            register_password: String::new(),
            register_nickname: String::new(),
            room_code: String::new(),
            message: String::from("Welcome. Start with Login or Register."),
            lobby_message: String::new(),
            settings_message: String::new(),
            active_lobby_mode: LobbyMode::Multiplayer,
            lobby_panel: LobbyPanel::Choice,
            current_room: None,
            current_room_is_host: false,
            pending_auth_email: None,
        }
    }
}

#[derive(Component)]
struct FrontendRoot {
    screen: Screen,
}

#[derive(Component)]
#[allow(dead_code)]
struct ScreenLabel;

#[derive(Component)]
struct MessageLabel;

#[derive(Component)]
struct LobbyMessageLabel;

/// Marks one of the three stacked lobby sub-panels (Choice / CreateRoom /
/// EnterRoom). `sync_lobby_panel_system` toggles visibility based on the
/// currently selected `LobbyPanel`.
#[derive(Component)]
struct LobbySubPanel {
    kind: LobbyPanel,
}

/// A selectable game-mode option on the Create Room panel. The active selection
/// is styled by `update_mode_options_system`.
#[derive(Component)]
struct ModeOption {
    mode: LobbyMode,
}

/// The container that hosts the dynamic list of rooms on the Enter Room panel.
#[derive(Component)]
struct RoomList;

/// A selectable row for an existing room returned by the server on the
/// Enter Room panel. Clicking it fills the room-code field.
#[derive(Component)]
struct RoomPickButton {
    code: String,
}

#[derive(Component)]
struct SettingsMessageLabel;

#[derive(Component)]
struct FieldValue {
    field: AuthField,
}

#[derive(Component)]
struct FocusButton {
    field: AuthField,
}

#[derive(Component)]
struct ActionButton {
    action: Action,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Action {
    GoLogin,
    GoRegister,
    GoAuthGate,
    LoginSubmit,
    RegisterSubmit,
    IntroSingle,
    IntroMulti,
    IntroOnline,
    IntroSettings,
    IntroQuit,
    LobbySelectCreate,
    LobbySelectEnter,
    LobbySelectChoice,
    LobbyCreate,
    LobbyJoin,
    LobbyBack,
    LobbyStart,
    LobbyLeave,
    SettingsBack,
    #[allow(dead_code)]
    GameBack,
}

const PANEL: Color = Color::srgba(0.07, 0.08, 0.10, 0.96);
const ACCENT: Color = Color::srgb(0.66, 0.78, 1.0);
const TEXT: Color = Color::srgb(0.96, 0.97, 1.0);
const MUTED: Color = Color::srgb(0.72, 0.76, 0.82);
const DANGER: Color = Color::srgb(1.0, 0.45, 0.45);

pub struct FrontendPlugin;

impl Plugin for FrontendPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<FrontendState>()
            .init_resource::<AuthStore>()
            .init_resource::<LobbyStore>()
            .add_systems(Startup, setup_frontend_ui_system)
            .add_systems(
                Update,
                (
                    sync_screen_visibility_system,
                    focus_field_system,
                    screen_button_system,
                    keyboard_input_system,
                    refresh_field_text_system,
                    refresh_status_texts_system,
                    update_mode_options_system,
                    refresh_room_list_system,
                    room_pick_system,
                    mode_option_system,
                    sync_game_pause_system,
                ),
            );
    }
}

fn setup_frontend_ui_system(mut commands: Commands) {
    spawn_auth_gate(&mut commands);
    spawn_login(&mut commands);
    spawn_register(&mut commands);
    spawn_intro(&mut commands);
    spawn_lobby(&mut commands);
    spawn_settings(&mut commands);
    spawn_game(&mut commands);
}

fn spawn_root(commands: &mut Commands, screen: Screen, title: &str) -> (Entity, Entity) {
    let mut panel_id = Entity::PLACEHOLDER;
    let root_id = commands
        .spawn((
            FrontendRoot { screen },
            Node {
                position_type: PositionType::Absolute,
                width: Val::Percent(100.0),
                height: Val::Percent(100.0),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                flex_direction: FlexDirection::Column,
                ..default()
            },
            BackgroundColor(Color::srgba(0.0, 0.0, 0.0, 0.0)),
            Visibility::Hidden,
            ZIndex(2000),
        ))
        .with_children(|parent| {
            let mut panel = parent.spawn((
                Node {
                    width: Val::Px(760.0),
                    max_width: Val::Percent(92.0),
                    padding: UiRect::all(Val::Px(24.0)),
                    flex_direction: FlexDirection::Column,
                    row_gap: Val::Px(14.0),
                    border: UiRect::all(Val::Px(1.0)),
                    ..default()
                },
                BackgroundColor(PANEL),
                BorderColor::all(ACCENT),
            ));
            panel_id = panel.id();
            panel.with_children(|panel| {
                panel.spawn((
                    Text::new(title),
                    TextFont {
                        font_size: FontSize::Px(34.0),
                        ..default()
                    },
                    TextColor(TEXT),
                ));
            });
        })
        .id();
    (root_id, panel_id)
}


fn spawn_auth_gate(commands: &mut Commands) {
    let (_root, panel) = spawn_root(commands, Screen::AuthGate, "Zelix Rised Trades");
    commands.entity(panel).with_children(|content| {
        spawn_paragraph(content, "Secure sign-in, nickname check, and online-ready lobby flow.", MUTED);
        spawn_paragraph(content, "Your account decides whether you enter Login, Register, or Intro.", MUTED);
        spawn_button(content, "Go to Login", Action::GoLogin);
        spawn_button(content, "Go to Register", Action::GoRegister);
        spawn_hint(content, "After signing in or registering you will be taken to Intro automatically.");
    });
}

fn spawn_login(commands: &mut Commands) {
    let (_root, panel) = spawn_root(commands, Screen::Login, "Login");
    commands.entity(panel).with_children(|panel| {
        spawn_paragraph(panel, "Enter email and password. Tab cycles fields.", MUTED);
        spawn_field(panel, "Email", AuthField::LoginEmail);
        spawn_field(panel, "Password", AuthField::LoginPassword);
        spawn_button(panel, "Login", Action::LoginSubmit);
        spawn_button(panel, "Don't have an account? Register", Action::GoRegister);
        spawn_button(panel, "Back", Action::GoAuthGate);
        spawn_message(panel);
    });
}

fn spawn_register(commands: &mut Commands) {
    let (_root, panel) = spawn_root(commands, Screen::Register, "Register");
    commands.entity(panel).with_children(|panel| {
        spawn_paragraph(panel, "Create account, choose a unique nickname, then enter Intro.", MUTED);
        spawn_field(panel, "Email", AuthField::RegisterEmail);
        spawn_field(panel, "Password", AuthField::RegisterPassword);
        spawn_field(panel, "Nickname", AuthField::RegisterNickname);
        spawn_button(panel, "Create account", Action::RegisterSubmit);
        spawn_button(panel, "Already have an account? Login", Action::GoLogin);
        spawn_button(panel, "Back", Action::GoAuthGate);
        spawn_message(panel);
    });
}

fn spawn_intro(commands: &mut Commands) {
    let (_root, panel) = spawn_root(commands, Screen::Intro, "Intro / Main Menu");
    commands.entity(panel).with_children(|panel| {
        spawn_paragraph(panel, "Choose a mode. Single Player opens the current game immediately.", MUTED);
        spawn_button(panel, "Single Player", Action::IntroSingle);
        spawn_button(panel, "Multiplayer", Action::IntroMulti);
        spawn_button(panel, "Online", Action::IntroOnline);
        spawn_button(panel, "Settings", Action::IntroSettings);
        spawn_button(panel, "Quit", Action::IntroQuit);
        spawn_message(panel);
    });
}

fn spawn_lobby(commands: &mut Commands) {
    spawn_lobby_panel(commands, LobbyPanel::Choice, "Online", |l| {
        spawn_paragraph(l, "Create a room, enter an existing room, change settings, or return to the main menu.", MUTED);
        spawn_button(l, "Create Room", Action::LobbySelectCreate);
        spawn_button(l, "Enter Room", Action::LobbySelectEnter);
        spawn_button(l, "Settings", Action::IntroSettings);
        spawn_button(l, "Main Menu", Action::LobbyBack);
        l.spawn((Text::new(""), TextFont { font_size: FontSize::Px(14.0), ..default() }, TextColor(MUTED), LobbyMessageLabel));
    });
    spawn_lobby_panel(commands, LobbyPanel::CreateRoom, "Online · Create Room", |l| {
        spawn_paragraph(l, "Create a room and then wait for players. Maximum 5 players.", MUTED);
        spawn_paragraph(l, "Game mode", ACCENT);
        spawn_mode_option(l, "Online", LobbyMode::Online);
        spawn_mode_option(l, "Multiplayer", LobbyMode::Multiplayer);
        spawn_paragraph(l, "Room ID is generated automatically after Create Room.", TEXT);
        spawn_button(l, "Create Room", Action::LobbyCreate);
        spawn_button(l, "← Back to Online", Action::LobbySelectChoice);
    });
    spawn_lobby_panel(commands, LobbyPanel::EnterRoom, "Online · Enter Room", |l| {
        spawn_paragraph(l, "Choose an open room or type its Room ID, then press Enter Game.", MUTED);
        spawn_field(l, "Room ID", AuthField::RoomCode);
        l.spawn((Node { flex_direction: FlexDirection::Column, row_gap: Val::Px(6.0), ..default() }, RoomList));
        spawn_hint(l, "Only waiting rooms can be joined.");
        spawn_button(l, "Enter Game", Action::LobbyJoin);
        spawn_button(l, "← Back to Online", Action::LobbySelectChoice);
        l.spawn((Text::new(""), TextFont { font_size: FontSize::Px(14.0), ..default() }, TextColor(DANGER), LobbyMessageLabel));
    });
    spawn_lobby_panel(commands, LobbyPanel::WaitingRoom, "Online · Waiting Room", |l| {
        spawn_paragraph(l, "Room joined successfully. Wait for the host to start the game.", MUTED);
        l.spawn((Text::new(""), TextFont { font_size: FontSize::Px(18.0), ..default() }, TextColor(ACCENT), LobbyMessageLabel));
        spawn_button(l, "Start Game (Host)", Action::LobbyStart);
        spawn_button(l, "Leave Room", Action::LobbyLeave);
    });
}

fn spawn_lobby_panel<F>(commands: &mut Commands, kind: LobbyPanel, title: &str, build: F)
where
    F: FnOnce(&mut ChildSpawnerCommands),
{
    commands
        .spawn((
            FrontendRoot { screen: Screen::Lobby },
            LobbySubPanel { kind },
            Node {
                position_type: PositionType::Absolute,
                width: Val::Percent(100.0),
                height: Val::Percent(100.0),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                flex_direction: FlexDirection::Column,
                ..default()
            },
            BackgroundColor(Color::srgba(0.0, 0.0, 0.0, 0.0)),
            Visibility::Hidden,
            ZIndex(2000),
        ))
        .with_children(|parent| {
            parent
                .spawn((
                    Node {
                        width: Val::Px(760.0),
                        max_width: Val::Percent(92.0),
                        padding: UiRect::all(Val::Px(24.0)),
                        flex_direction: FlexDirection::Column,
                        row_gap: Val::Px(14.0),
                        border: UiRect::all(Val::Px(1.0)),
                        ..default()
                    },
                    BackgroundColor(PANEL),
                    BorderColor::all(ACCENT),
                ))
                .with_children(|panel| {
                    panel.spawn((
                        Text::new(title),
                        TextFont { font_size: FontSize::Px(34.0), ..default() },
                        TextColor(TEXT),
                    ));
                    build(panel);
                });
        });
}

/// A selectable game-mode row on the Create Room panel.
#[allow(dead_code)]
fn spawn_mode_option(parent: &mut ChildSpawnerCommands, label: &str, mode: LobbyMode) {
    parent
        .spawn((
            Button,
            Interaction::default(),
            ModeOption { mode },
            Node {
                width: Val::Percent(100.0),
                min_height: Val::Px(42.0),
                padding: UiRect::horizontal(Val::Px(14.0)),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                border: UiRect::all(Val::Px(1.0)),
                ..default()
            },
            BackgroundColor(Color::srgb(0.14, 0.15, 0.18)),
            BorderColor::all(Color::srgb(0.28, 0.32, 0.40)),
        ))
        .with_children(|row| {
            row.spawn((
                Text::new(label),
                TextFont { font_size: FontSize::Px(15.0), ..default() },
                TextColor(TEXT),
            ));
        });
}

/// A selectable row for an existing room on the Enter Room panel.
fn spawn_room_pick(
    parent: &mut ChildSpawnerCommands,
    code: &str,
    mode: &str,
    host: &str,
    len: usize,
    max: usize,
    started: bool,
) {
    let badge = if started { " | started" } else { "" };
    parent
        .spawn((
            Button,
            Interaction::default(),
            RoomPickButton { code: code.to_string() },
            Node {
                width: Val::Percent(100.0),
                min_height: Val::Px(34.0),
                padding: UiRect::horizontal(Val::Px(12.0)),
                justify_content: JustifyContent::SpaceBetween,
                align_items: AlignItems::Center,
                border: UiRect::all(Val::Px(1.0)),
                ..default()
            },
            BackgroundColor(Color::srgb(0.10, 0.11, 0.14)),
            BorderColor::all(Color::srgb(0.26, 0.30, 0.38)),
        ))
        .with_children(|row| {
            row.spawn((
                Text::new(format!("{code}  {mode}{badge}")),
                TextFont { font_size: FontSize::Px(13.0), ..default() },
                TextColor(TEXT),
            ));
            row.spawn((
                Text::new(format!("{host} ({len}/{max})")),
                TextFont { font_size: FontSize::Px(12.0), ..default() },
                TextColor(MUTED),
            ));
        });
}

fn spawn_settings(commands: &mut Commands) {
    let (_root, panel) = spawn_root(commands, Screen::Settings, "Settings");
    commands.entity(panel).with_children(|panel| {
        spawn_paragraph(panel, "Style, controls, and future sync options live here.", MUTED);
        spawn_button(panel, "Back to Intro", Action::SettingsBack);
        panel.spawn((
            Text::new("VSync: on | UI scale: adaptive | Sound: placeholder"),
            TextFont { font_size: FontSize::Px(14.0), ..default() },
            TextColor(MUTED),
            SettingsMessageLabel,
        ));
    });
}

fn spawn_game(commands: &mut Commands) {
    // The Game screen deliberately has no overlay panel: once a mode is chosen
    // (Single Player, Multiplayer, or Online), all menu panels are cleared so
    // only the world/map underneath is visible. The root is spawned directly
    // (instead of via `spawn_root`, which adds a centred panel box) with a fully
    // transparent background so the map is never covered, while still letting
    // `sync_screen_visibility_system` mark this screen visible when the game
    // starts and hidden on every other screen.
    commands.spawn((
        FrontendRoot { screen: Screen::Game },
        Node {
            position_type: PositionType::Absolute,
            width: Val::Percent(100.0),
            height: Val::Percent(100.0),
            ..default()
        },
        BackgroundColor(Color::srgba(0.0, 0.0, 0.0, 0.0)),
        Visibility::Hidden,
        ZIndex(2000),
    ));
}

fn spawn_paragraph(parent: &mut ChildSpawnerCommands, text: &str, color: Color) {
    parent.spawn((
        Text::new(text),
        TextFont { font_size: FontSize::Px(15.0), ..default() },
        TextColor(color),
        Node {
            margin: UiRect::bottom(Val::Px(2.0)),
            ..default()
        },
    ));
}

fn spawn_hint(parent: &mut ChildSpawnerCommands, text: &str) {
    parent.spawn((
        Text::new(text),
        TextFont { font_size: FontSize::Px(13.0), ..default() },
        TextColor(Color::srgb(0.58, 0.67, 0.80)),
    ));
}

fn spawn_message(parent: &mut ChildSpawnerCommands) {
    parent.spawn((
        Text::new(""),
        TextFont { font_size: FontSize::Px(14.0), ..default() },
        TextColor(DANGER),
        MessageLabel,
    ));
}

fn spawn_field(parent: &mut ChildSpawnerCommands, label: &str, field: AuthField) {
    parent
        .spawn((
            Button,
            Interaction::default(),
            FocusButton { field },
            Node {
                width: Val::Percent(100.0),
                min_height: Val::Px(42.0),
                padding: UiRect::horizontal(Val::Px(14.0)),
                justify_content: JustifyContent::SpaceBetween,
                align_items: AlignItems::Center,
                border: UiRect::all(Val::Px(1.0)),
                ..default()
            },
            BackgroundColor(Color::srgb(0.14, 0.15, 0.18)),
            BorderColor::all(Color::srgb(0.28, 0.32, 0.40)),
        ))
        .with_children(|row| {
            row.spawn((
                Text::new(label),
                TextFont { font_size: FontSize::Px(14.0), ..default() },
                TextColor(ACCENT),
            ));
            row.spawn((
                Text::new(""),
                TextFont { font_size: FontSize::Px(14.0), ..default() },
                TextColor(TEXT),
                FieldValue { field },
            ));
        });
}

fn spawn_button(parent: &mut ChildSpawnerCommands, label: &str, action: Action) {
    parent
        .spawn((
            Button,
            Interaction::default(),
            ActionButton { action },
            Node {
                width: Val::Percent(100.0),
                min_height: Val::Px(42.0),
                padding: UiRect::horizontal(Val::Px(14.0)),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                border: UiRect::all(Val::Px(1.0)),
                ..default()
            },
            BackgroundColor(Color::srgb(0.14, 0.15, 0.18)),
            BorderColor::all(Color::srgb(0.28, 0.32, 0.40)),
        ))
        .with_children(|row| {
            row.spawn((
                Text::new(label),
                TextFont { font_size: FontSize::Px(15.0), ..default() },
                TextColor(TEXT),
            ));
        });
}


fn focus_field_system(
    mut state: ResMut<FrontendState>,
    buttons: Query<(&Interaction, &FocusButton), (Changed<Interaction>, With<Button>)>,
) {
    for (interaction, button) in &buttons {
        if *interaction == Interaction::Pressed {
            state.active_field = Some(button.field);
        }
    }
}

fn sync_screen_visibility_system(
    state: Res<FrontendState>,
    mut query: Query<(&FrontendRoot, Option<&LobbySubPanel>, &mut Visibility)>,
) {
    for (root, sub, mut visibility) in &mut query {
        let visible = root.screen == state.screen
            && sub.map(|panel| panel.kind == state.lobby_panel).unwrap_or(true);
        *visibility = if visible { Visibility::Visible } else { Visibility::Hidden };
    }
}
/// Highlights the game-mode currently selected on the Create Room panel.
fn update_mode_options_system(
    state: Res<FrontendState>,
    mut options: Query<(&ModeOption, &mut BackgroundColor, &mut BorderColor, &Children)>,
    mut texts: Query<&mut TextColor>,
) {
    for (option, mut bg, mut border, children) in &mut options {
        let selected = option.mode == state.active_lobby_mode;
        *bg = BackgroundColor(if selected {
            Color::srgb(0.20, 0.30, 0.45)
        } else {
            Color::srgb(0.14, 0.15, 0.18)
        });
        *border = BorderColor::all(if selected {
            ACCENT
        } else {
            Color::srgb(0.28, 0.32, 0.40)
        });
        for child in children {
            if let Ok(mut color) = texts.get_mut(*child) {
                *color = TextColor(if selected { ACCENT } else { TEXT });
            }
        }
    }
}

/// Rebuilds the Enter Room panel's room list whenever the server's room set
/// changes, so new rooms appear without restarting.
fn mode_option_system(
    mut state: ResMut<FrontendState>,
    buttons: Query<(&Interaction, &ModeOption), (Changed<Interaction>, With<Button>)>,
) {
    for (interaction, option) in &buttons {
        if *interaction == Interaction::Pressed {
            state.active_lobby_mode = option.mode;
            state.lobby_message = format!("Selected {} mode.", option.mode.label());
        }
    }
}

fn refresh_room_list_system(
    lobby: Res<LobbyStore>,
    container: Query<(Entity, &Children), With<RoomList>>,
    mut commands: Commands,
) {
    if !lobby.is_changed() {
        return;
    }
    let Ok((container_entity, children)) = container.single() else {
        return;
    };
    for child in children {
        commands.entity(*child).despawn();
    }
    for room in &lobby.rooms {
        let code = room.id.clone();
        let mode = room.mode.label().to_string();
        let host = room.host.clone();
        let len = room.players.len();
        let max = room.max_players;
        let started = room.started;
        commands.entity(container_entity).with_children(move |list| {
            spawn_room_pick(list, &code, &mode, &host, len, max, started);
        });
    }
}

/// Clicking a listed room fills the room-code field and highlights that row.
fn room_pick_system(
    mut state: ResMut<FrontendState>,
    buttons: Query<(&Interaction, &RoomPickButton), (Changed<Interaction>, With<Button>)>,
    mut styles: Query<(&RoomPickButton, &mut BackgroundColor, &mut BorderColor, &Children)>,
    mut texts: Query<&mut TextColor>,
) {
    for (interaction, button) in &buttons {
        if *interaction == Interaction::Pressed {
            state.room_code = button.code.clone();
        }
    }
    for (button, mut bg, mut border, children) in &mut styles {
        let selected = state.room_code == button.code;
        *bg = BackgroundColor(if selected {
            Color::srgb(0.20, 0.30, 0.45)
        } else {
            Color::srgb(0.10, 0.11, 0.14)
        });
        *border = BorderColor::all(if selected {
            ACCENT
        } else {
            Color::srgb(0.26, 0.30, 0.38)
        });
        for child in children {
            if let Ok(mut color) = texts.get_mut(*child) {
                *color = TextColor(if selected { ACCENT } else { TEXT });
            }
        }
    }
}

fn refresh_field_text_system(
    state: Res<FrontendState>,
    mut fields: Query<(&FieldValue, &mut Text)>,
) {
    if !state.is_changed() {
        // Still refresh each frame because the text buffers are tiny and the
        // screen needs to stay visually in sync while typing.
    }

    for (field, mut text) in &mut fields {
        let value = match field.field {
            AuthField::LoginEmail => mask_or_show(&state.login_email, false),
            AuthField::LoginPassword => mask_or_show(&state.login_password, true),
            AuthField::RegisterEmail => mask_or_show(&state.register_email, false),
            AuthField::RegisterPassword => mask_or_show(&state.register_password, true),
            AuthField::RegisterNickname => mask_or_show(&state.register_nickname, false),
            AuthField::RoomCode => mask_or_show(&state.room_code, false),
        };
        *text = Text::new(value);
    }
}

fn refresh_status_texts_system(
    state: Res<FrontendState>,
    auth: Res<AuthStore>,
    lobby: Res<LobbyStore>,
    mut message: Query<
        &mut Text,
        (
            With<MessageLabel>,
            Without<LobbyMessageLabel>,
            Without<SettingsMessageLabel>,
        ),
    >,
    mut lobby_message: Query<
        &mut Text,
        (
            With<LobbyMessageLabel>,
            Without<MessageLabel>,
            Without<SettingsMessageLabel>,
        ),
    >,
    mut settings_message: Query<
        &mut Text,
        (
            With<SettingsMessageLabel>,
            Without<MessageLabel>,
            Without<LobbyMessageLabel>,
        ),
    >,
) {
    for mut text in &mut message {
        let mut body = state.message.clone();
        if let Some(user) = &auth.current_user {
            body.push_str(&format!("\nSigned in as {}", user.nickname));
        }
        if let Some(room) = state.current_room.as_ref() {
            body.push_str(&format!("\nRoom: {}", room));
        }
        *text = Text::new(body.clone());
    }

    let lobby_body = if lobby.rooms.is_empty() {
        String::from("No rooms yet. Create one to start.")
    } else {
        let mut rows = Vec::new();
        for room in &lobby.rooms {
            rows.push(format!(
                "{} | {} | {}/{} | host: {}{}",
                room.id,
                room.mode.label(),
                room.players.len(),
                room.max_players,
                room.host,
                if room.started { " | started" } else { "" },
            ));
        }
        rows.join("\n")
    };
    let mut lobby_full = lobby_body;
    if !state.lobby_message.is_empty() {
        if !lobby_full.is_empty() {
            lobby_full.push_str("\n\n");
        }
        lobby_full.push_str(&state.lobby_message);
    }
    for mut text in &mut lobby_message {
        *text = Text::new(lobby_full.clone());
    }

    let settings_body = if state.settings_message.is_empty() {
        "VSync: on | UI scale: adaptive | Sound: placeholder".to_string()
    } else {
        state.settings_message.clone()
    };
    for mut text in &mut settings_message {
        *text = Text::new(settings_body.clone());
    }
}

fn keyboard_input_system(
    mut events: MessageReader<KeyboardInput>,
    mut state: ResMut<FrontendState>,
    client: Res<AuthClient>,
    keys: Res<ButtonInput<KeyCode>>,
) {
    for ev in events.read() {
        let Some(focused) = state.active_field else {
            continue;
        };

        // Special keys first.
        if ev.state != bevy::input::ButtonState::Pressed {
            continue;
        }

        if keys.just_pressed(KeyCode::Tab) {
            let reverse = keys.pressed(KeyCode::ShiftLeft) || keys.pressed(KeyCode::ShiftRight);
            state.active_field = Some(next_field(focused, state.screen, reverse));
            continue;
        }
        if keys.just_pressed(KeyCode::Enter) {
            // Enter submits the current screen's primary action.
            match state.screen {
                Screen::Login => {
                    let email = state.login_email.trim().to_string();
                    let password = state.login_password.clone();
                    if email.is_empty() || password.is_empty() {
                        state.message = String::from("Fill in email and password.");
                    } else {
                        state.pending_auth_email = Some(email.clone());
                        request_login(&client, &email, &password);
                        state.message = String::from("Signing in...");
                    }
                }
                Screen::Register => {
                    let email = state.register_email.trim().to_string();
                    let password = state.register_password.clone();
                    let nickname = state.register_nickname.trim().to_string();
                    if email.is_empty() || password.is_empty() || nickname.is_empty() {
                        state.message = String::from("Email, password, and nickname are required.");
                    } else {
                        state.pending_auth_email = Some(email.clone());
                        request_register(&client, &email, &password, &nickname);
                        state.message = String::from("Creating account...");
                    }
                }
                Screen::Lobby => {
                    // Enter key joins the room from Enter Room panel.
                    if state.lobby_panel == LobbyPanel::EnterRoom {
                        let code = state.room_code.trim().to_string();
                        if code.is_empty() {
                            state.lobby_message = String::from("Enter a Room ID first.");
                        } else {
                            state.active_field = None;
                            state.lobby_message = format!("Joining {}...", code);
                            // Network send is handled in screen_button_system;
                            // here we just mirror the validation path.
                        }
                    }
                }
                _ => {}
            }
            continue;
        }
        if keys.just_pressed(KeyCode::Backspace) {
            current_buffer_mut(&mut state, focused).pop();
            continue;
        }

        if let Some(text) = key_text(ev) {
            let buffer = current_buffer_mut(&mut state, focused);
            for ch in text.chars() {
                if !ch.is_control() && buffer.len() < 64 {
                    buffer.push(ch);
                }
            }
        }
    }
}

fn key_text(ev: &KeyboardInput) -> Option<&str> {
    match &ev.logical_key {
        Key::Character(text) => Some(text.as_ref()),
        _ => None,
    }
}

fn current_buffer_mut<'a>(state: &'a mut FrontendState, field: AuthField) -> &'a mut String {
    match field {
        AuthField::LoginEmail => &mut state.login_email,
        AuthField::LoginPassword => &mut state.login_password,
        AuthField::RegisterEmail => &mut state.register_email,
        AuthField::RegisterPassword => &mut state.register_password,
        AuthField::RegisterNickname => &mut state.register_nickname,
        AuthField::RoomCode => &mut state.room_code,
    }
}

fn next_field(current: AuthField, screen: Screen, reverse: bool) -> AuthField {
    match screen {
        Screen::Login => {
            let order = [AuthField::LoginEmail, AuthField::LoginPassword];
            cycle_field(current, &order, reverse)
        }
        Screen::Register => {
            let order = [
                AuthField::RegisterEmail,
                AuthField::RegisterPassword,
                AuthField::RegisterNickname,
            ];
            cycle_field(current, &order, reverse)
        }
        Screen::Lobby => AuthField::RoomCode,
        _ => current,
    }
}

/// Cycles to the next field in `order`, wrapping around. When `reverse` is true
/// (Shift+Tab), it cycles in the opposite direction.
fn cycle_field(current: AuthField, order: &[AuthField], reverse: bool) -> AuthField {
    if let Some(pos) = order.iter().position(|field| *field == current) {
        let step = if reverse { order.len() - 1 } else { 1 };
        order[(pos + step) % order.len()]
    } else {
        order[0]
    }
}

fn screen_button_system(
    mut state: ResMut<FrontendState>,
    auth: ResMut<AuthStore>,
    mut game: ResMut<GameState>,
    client: Res<AuthClient>,
    network: Res<NetworkClient>,
    lobby: Res<LobbyStore>,
    mut exit_writer: MessageWriter<AppExit>,
    buttons: Query<(&Interaction, &ActionButton), (Changed<Interaction>, With<Button>)>,
) {
    for (interaction, button) in &buttons {
        if *interaction != Interaction::Pressed {
            continue;
        }

        match button.action {
            Action::GoLogin => {
                state.screen = Screen::Login;
                state.active_field = Some(AuthField::LoginEmail);
                state.message = String::from("Login with your account.");
                game.paused = true;
            }
            Action::GoRegister => {
                state.screen = Screen::Register;
                state.active_field = Some(AuthField::RegisterEmail);
                state.message = String::from("Register a new account.");
                game.paused = true;
            }
            Action::GoAuthGate => {
                state.screen = Screen::AuthGate;
                state.active_field = None;
                state.message = String::from("Welcome. Start with Login or Register.");
                game.paused = true;
            }
            Action::LoginSubmit => {
                let email = state.login_email.trim().to_string();
                let password = state.login_password.clone();
                if email.is_empty() || password.is_empty() {
                    state.message = String::from("Fill in email and password.");
                } else {
                    state.pending_auth_email = Some(email.clone());
                    request_login(&client, &email, &password);
                    state.message = String::from("Signing in...");
                }
                game.paused = true;
            }
            Action::RegisterSubmit => {
                let email = state.register_email.trim().to_string();
                let password = state.register_password.clone();
                let nickname = state.register_nickname.trim().to_string();
                if email.is_empty() || password.is_empty() || nickname.is_empty() {
                    state.message = String::from("Email, password, and nickname are required.");
                } else {
                    state.pending_auth_email = Some(email.clone());
                    request_register(&client, &email, &password, &nickname);
                    state.message = String::from("Creating account...");
                }
                game.paused = true;
            }
            Action::IntroSingle => {
                state.screen = Screen::Game;
                state.current_room = None;
                state.message = String::from("Single player loaded.");
                game.paused = false;
            }
            Action::IntroMulti => {
                state.screen = Screen::Lobby;
                state.lobby_panel = LobbyPanel::Choice;
                state.active_lobby_mode = LobbyMode::Multiplayer;
                state.active_field = Some(AuthField::RoomCode);
                state.lobby_message = String::from("Multiplayer lobby ready.");
                game.paused = true;
            }
            Action::IntroOnline => {
                state.screen = Screen::Lobby;
                state.lobby_panel = LobbyPanel::Choice;
                state.active_lobby_mode = LobbyMode::Online;
                state.current_room = None;
                state.current_room_is_host = false;
                state.active_field = None;
                state.lobby_message = String::from("Online room lobby ready.");
                game.paused = true;
            }
            Action::IntroSettings => {
                state.screen = Screen::Settings;
                state.active_field = None;
                state.settings_message = String::from("Graphics: optimal | Input: keyboard/mouse | Network: ready for backend.");
                game.paused = true;
            }
            Action::IntroQuit => {
                exit_writer.write(AppExit::Success);
            }
            Action::LobbySelectCreate => {
                state.lobby_panel = LobbyPanel::CreateRoom;
                state.active_lobby_mode = LobbyMode::Online;
                state.current_room = None;
                state.current_room_is_host = false;
                state.active_field = Some(AuthField::RoomCode);
                state.lobby_message = String::from("Select a game mode, then Create Room.");
                game.paused = true;
            }
            Action::LobbySelectEnter => {
                state.lobby_panel = LobbyPanel::EnterRoom;
                state.current_room = None;
                state.current_room_is_host = false;
                // Do NOT clear room_code here so the user can type without it
                // being wiped each time the panel is visited.
                state.active_field = Some(AuthField::RoomCode);
                state.lobby_message = String::from("Select a room or type its code, then Enter.");
                game.paused = true;
            }
            Action::LobbySelectChoice => {
                state.lobby_panel = LobbyPanel::Choice;
                state.active_field = Some(AuthField::RoomCode);
                state.lobby_message = String::from("Choose Create Room or Enter Room.");
                game.paused = true;
            }
            Action::LobbyCreate => {
                let mode = match state.active_lobby_mode { LobbyMode::Online => "online", _ => "multiplayer" }.to_string();
                state.active_field = None;
                state.lobby_message = String::from("Creating room...");
                send_lobby_command(&mut state, &auth, &network, crate::network::protocol::ClientMessage::LobbyCreate { mode });
            }
            Action::LobbyJoin => {
                let code = state.room_code.trim().to_string();
                if code.is_empty() {
                    state.lobby_message = String::from("Enter a Room ID first.");
                } else {
                    state.active_field = None;
                    state.lobby_message = format!("Joining {}...", code);
                    send_lobby_command(&mut state, &auth, &network, crate::network::protocol::ClientMessage::LobbyJoin { code });
                }
            }
            Action::LobbyBack => {
                state.screen = Screen::Intro;
                state.active_field = None;
                state.lobby_message.clear();
                game.paused = true;
            }
            Action::LobbyStart => {
                // A room cannot start with the host alone: require at least one
                // other player (2..=5 total). The server enforces this too.
                let player_count = state
                    .current_room
                    .as_ref()
                    .and_then(|code| lobby.rooms.iter().find(|room| &room.id == code))
                    .map(|room| room.players.len())
                    .unwrap_or(0);
                if player_count < 2 {
                    state.lobby_message = String::from(
                        "At least 2 players are required to start (you + 1 more, max 5).",
                    );
                } else {
                    send_lobby_command(&mut state, &auth, &network, crate::network::protocol::ClientMessage::LobbyStart);
                }
            }
            Action::LobbyLeave => {
                send_lobby_command(&mut state, &auth, &network, crate::network::protocol::ClientMessage::LobbyLeave);
                state.screen = Screen::Intro;
                state.active_field = None;
                game.paused = true;
            }
            Action::SettingsBack => {
                state.screen = Screen::Intro;
                state.active_field = None;
                game.paused = true;
            }
            Action::GameBack => {
                state.screen = Screen::Intro;
                state.active_field = None;
                state.message = String::from("Returned to main menu.");
                game.paused = true;
            }
        }
    }
}

fn send_lobby_command(
    state: &mut FrontendState,
    auth: &AuthStore,
    network: &NetworkClient,
    message: crate::network::protocol::ClientMessage,
) {
    if auth.current_user.is_none() {
        state.lobby_message = String::from("Login first.");
        return;
    }
    let Some(sender) = network.sender.as_ref() else {
        // No connection attempt in progress yet. The websocket auto-connects as
        // soon as the signed-in user's token is available, so surface a clear
        // message and let the retry keep trying rather than dropping the click.
        state.lobby_message = String::from("Connecting to game server... The command will be sent once the connection is available.");
        return;
    };
    // The `sender` channel buffers outgoing messages until the socket is up, so
    // do NOT gate on `network.connected` here: dropping the request on the very
    // first click (while the websocket is still establishing) is exactly why the
    // Create/Enter buttons appeared to "do nothing".
    if sender.send(message).is_err() {
        state.lobby_message = String::from("Failed to send lobby command.");
    } else if !network.connected {
        state.lobby_message = String::from("Connecting to game server... command queued.");
    } else {
        state.lobby_message = String::from("Waiting for server...");
    }
}

fn mask_or_show(value: &str, secret: bool) -> String {
    if secret {
        if value.is_empty() {
            String::from("<empty>")
        } else {
            "•".repeat(value.chars().count())
        }
    } else if value.is_empty() {
        String::from("<empty>")
    } else {
        value.to_string()
    }
}

fn sync_game_pause_system(state: Res<FrontendState>, mut game: ResMut<GameState>) {
    let should_pause = !matches!(state.screen, Screen::Game);
    if game.paused != should_pause {
        game.paused = should_pause;
    }
}