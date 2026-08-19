use bevy::prelude::*;

use crate::core::components::{Bank, OwnerId};
use crate::network::{NetworkClient, OnlineAuthority};
use crate::core::events::{
    BuildBankEvent, BuildStructureEvent, BuildingType, CloseBuildMenuEvent,
    CloseFactoryMenuEvent, OpenBuildMenuEvent, OpenFactoryMenuEvent,
};
use crate::render::camera::MainCamera;
use crate::render::factory_menu::FactoryMenuState;
use crate::render::map::BUILDING_SIZE;

#[derive(Component)]
pub struct BuildMenu;

#[derive(Component)]
pub struct BuildMenuButton {
    pub building_type: BuildingType,
}

#[derive(Component)]
pub struct BuildMenuMessage;

#[derive(Component)]
pub struct BankMenuButton;

#[derive(Resource, Default)]
pub struct BuildMenuState {
    pub is_open: bool,
    pub position: Vec3,
}

const PANEL_WIDTH: f32 = 220.0;
const BANK_COST: i64 = 10_000;

pub fn setup_build_menu_ui(mut commands: Commands) {
    commands
        .spawn((
            BuildMenu,
            Node {
                position_type: PositionType::Absolute,
                width: Val::Px(PANEL_WIDTH),
                padding: UiRect::all(Val::Px(8.0)),
                flex_direction: FlexDirection::Column,
                row_gap: Val::Px(4.0),
                border: UiRect::all(Val::Px(1.0)),
                ..default()
            },
            Visibility::Hidden,
            BackgroundColor(Color::srgba(0.10, 0.10, 0.12, 0.97)),
            BorderColor::all(Color::srgb(0.55, 0.55, 0.60)),
        ))
        .with_children(|parent| {
            spawn_bank_button(parent);

            spawn_button(
                parent,
                BuildingType::Gatherer,
                "Gatherer (¥5,000)",
            );

            spawn_button(
                parent,
                BuildingType::Factory,
                "Factory (¥20,000)",
            );

            spawn_button(
                parent,
                BuildingType::Warehouse,
                "Warehouse (¥8,000)",
            );

            spawn_button(
                parent,
                BuildingType::Farm,
                "Farm (¥12,000)",
            );

            parent.spawn((
                BuildMenuMessage,
                Text::new(""),
                TextFont {
                    font_size: FontSize::Px(13.0),
                    ..default()
                },
                TextColor(Color::srgb(1.0, 0.35, 0.35)),
                Node {
                    margin: UiRect::top(Val::Px(6.0)),
                    ..default()
                },
            ));
        });
}

fn spawn_bank_button(parent: &mut ChildSpawnerCommands) {
    parent
        .spawn((
            BankMenuButton,
            Button,
            Interaction::default(),
            Node {
                width: Val::Percent(100.0),
                min_height: Val::Px(34.0),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                ..default()
            },
            BackgroundColor(Color::srgb(0.18, 0.18, 0.22)),
        ))
        .with_children(|parent| {
            parent.spawn((
                Text::new(format!("Bank (¥{BANK_COST})")),
                TextFont {
                    font_size: FontSize::Px(14.0),
                    ..default()
                },
                TextColor(Color::WHITE),
            ));
        });
}

fn spawn_button(
    parent: &mut ChildSpawnerCommands,
    building_type: BuildingType,
    label: &str,
) {
    parent
        .spawn((
            Button,
            Interaction::default(),
            Node {
                width: Val::Percent(100.0),
                min_height: Val::Px(32.0),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                // Collapsed until the update system decides which buttons are
                // relevant; Display::None removes them from layout so the panel
                // is always sized to exactly the visible elements.
                display: Display::None,
                ..default()
            },
            BackgroundColor(Color::srgb(0.18, 0.18, 0.22)),
            BuildMenuButton { building_type },
        ))
        .with_children(|parent| {
            parent.spawn((
                Text::new(label),
                TextFont {
                    font_size: FontSize::Px(14.0),
                    ..default()
                },
                TextColor(Color::WHITE),
            ));
        });
}

pub fn open_build_menu_system(
    mut menu_state: ResMut<BuildMenuState>,
    mut query: Query<(&mut Node, &mut Visibility), With<BuildMenu>>,
    mut event: MessageReader<OpenBuildMenuEvent>,
) {
    for ev in event.read() {
        menu_state.is_open = true;
        menu_state.position = ev.position;

        let Ok((mut node, mut visibility)) = query.single_mut() else {
            continue;
        };

        *visibility = Visibility::Visible;

        // Place the panel exactly where the player right-clicked (using the raw
        // cursor pixel position, so it never lands at a random/offset spot).
        node.left = Val::Px(ev.screen_position.x + 16.0);
        node.top = Val::Px(ev.screen_position.y + 16.0);
    }
}

pub fn update_build_menu_buttons_system(
    menu_state: Res<BuildMenuState>,
    network: Res<NetworkClient>,
    authority: Res<OnlineAuthority>,
    banks: Query<(&GlobalTransform, Option<&OwnerId>), With<Bank>>,
    mut button_queries: ParamSet<(
        Query<&mut Node, With<BankMenuButton>>,
        Query<(&BuildMenuButton, &mut Node)>,
    )>,
) {
    let own_player = network.player_id;
    let bank_for_player = |owner: Option<&OwnerId>| {
        if authority.active {
            owner.map(|id| id.0 == own_player.unwrap_or(0)).unwrap_or(false)
        } else {
            true
        }
    };

    let own_bank = banks.iter().find(|(_, owner)| bank_for_player(*owner));
    let bank_exists = own_bank.is_some();

    for mut node in button_queries.p0().iter_mut() {
        node.display = if bank_exists || !menu_state.is_open {
            Display::None
        } else {
            Display::Flex
        };
    }

    let inside_city = own_bank
        .map(|(transform, _)| {
            transform.translation().truncate().distance(menu_state.position.truncate())
                <= crate::render::placement::CITY_RADIUS
        })
        .unwrap_or(false);

    for (button, mut node) in button_queries.p1().iter_mut() {
        let show = if !menu_state.is_open {
            false
        } else {
            match button.building_type {
                BuildingType::Warehouse => bank_exists,
                BuildingType::Gatherer | BuildingType::Factory | BuildingType::Farm => {
                    bank_exists && inside_city
                }
            }
        };
        node.display = if show { Display::Flex } else { Display::None };
    }
}

pub fn build_menu_button_system(
    menu_state: Res<BuildMenuState>,
    mut query: Query<(&BuildMenuButton, &Interaction), (With<Button>, Changed<Interaction>)>,
    mut build_events: MessageWriter<BuildStructureEvent>,
    mut close_menu_events: MessageWriter<CloseBuildMenuEvent>,
) {
    // The client only emits the user's intent. Money, terrain, distance and
    // ownership are validated by the server in online mode.
    for (button, interaction) in &mut query {
        if *interaction != Interaction::Pressed {
            continue;
        }
        build_events.write(BuildStructureEvent {
            building_type: button.building_type,
            position: menu_state.position,
        });
        close_menu_events.write(CloseBuildMenuEvent);
    }
}

pub fn bank_button_system(
    menu_state: Res<BuildMenuState>,
    mut query: Query<&Interaction, (With<BankMenuButton>, Changed<Interaction>)>,
    mut build_bank_events: MessageWriter<BuildBankEvent>,
    mut close_menu_events: MessageWriter<CloseBuildMenuEvent>,
) {
    for interaction in &query {
        if *interaction == Interaction::Pressed {
            build_bank_events.write(BuildBankEvent { position: menu_state.position });
            close_menu_events.write(CloseBuildMenuEvent);
        }
    }
}

pub fn mouse_right_click_system(
    mouse: Res<ButtonInput<MouseButton>>,
    windows: Query<&Window>,
    camera: Query<(&Camera, &GlobalTransform), With<MainCamera>>,
    menu_state: Res<BuildMenuState>,
    factory_menu: Res<FactoryMenuState>,
    factories: Query<(Entity, &GlobalTransform, Option<&crate::core::components::OwnerId>), With<crate::core::components::Factory>>,
    authority: Res<OnlineAuthority>,
    network: Res<NetworkClient>,
    mut open_menu_events: MessageWriter<OpenBuildMenuEvent>,
    mut open_factory_events: MessageWriter<OpenFactoryMenuEvent>,
    mut close_menu_events: MessageWriter<CloseBuildMenuEvent>,
    mut close_factory_events: MessageWriter<CloseFactoryMenuEvent>,
) {
    if !mouse.just_pressed(MouseButton::Right) {
        return;
    }

    // Right-click toggles whatever panel is currently open.
    if menu_state.is_open {
        close_menu_events.write(CloseBuildMenuEvent);
        return;
    }

    if factory_menu.is_open {
        close_factory_events.write(CloseFactoryMenuEvent);
        return;
    }

    let Ok(window) = windows.single() else {
        return;
    };

    let Some(cursor_position) = window.cursor_position() else {
        return;
    };

    let Ok((camera, camera_transform)) = camera.single() else {
        return;
    };

    let Ok(world_position) =
        camera.viewport_to_world_2d(camera_transform, cursor_position)
    else {
        return;
    };

    // Right-clicking directly on a factory opens its raw-material panel
    // instead of the build menu (a building is a square sprite).
    let half = BUILDING_SIZE / 2.0;
    for (entity, transform, owner) in &factories {
        if authority.active && owner.map(|id| id.0) != network.player_id {
            continue;
        }
        let center = transform.translation().truncate();
        if (world_position.x - center.x).abs() <= half
            && (world_position.y - center.y).abs() <= half
        {
            open_factory_events.write(OpenFactoryMenuEvent {
                entity,
                screen_position: cursor_position,
            });
            return;
        }
    }

    open_menu_events.write(OpenBuildMenuEvent {
        position: Vec3::new(
            world_position.x,
            world_position.y,
            0.0,
        ),
        screen_position: cursor_position,
    });
}

pub fn close_menu_on_left_click(
    mouse: Res<ButtonInput<MouseButton>>,
    menu_state: Res<BuildMenuState>,
    build_button_query: Query<
        &Interaction,
        (With<BuildMenuButton>, With<Button>),
    >,
    bank_button_query: Query<
        &Interaction,
        (With<BankMenuButton>, With<Button>),
    >,
    mut close_menu_events: MessageWriter<CloseBuildMenuEvent>,
) {
    if !menu_state.is_open || !mouse.just_pressed(MouseButton::Left) {
        return;
    }

    for interaction in &build_button_query {
        if *interaction == Interaction::Pressed {
            return;
        }
    }

    for interaction in &bank_button_query {
        if *interaction == Interaction::Pressed {
            return;
        }
    }

    close_menu_events.write(CloseBuildMenuEvent);
}

pub fn close_build_menu_system(
    mut menu_state: ResMut<BuildMenuState>,
    mut query: Query<&mut Visibility, With<BuildMenu>>,
    mut event: MessageReader<CloseBuildMenuEvent>,
) {
    if event.read().next().is_some() {
        menu_state.is_open = false;

        if let Ok(mut visibility) = query.single_mut() {
            *visibility = Visibility::Hidden;
        }
    }
}