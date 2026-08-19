use bevy::prelude::*;

use crate::core::components::{Factory, OwnerId};
use crate::network::OnlineAuthority;
use crate::core::events::{
    CloseBuildMenuEvent, CloseFactoryMenuEvent, OpenFactoryMenuEvent, ProductType,
    SetFactoryProductEvent,
};

#[derive(Component)]
pub struct FactoryMenu;

#[derive(Component)]
pub struct FactoryMenuProductButton {
    pub product: ProductType,
}

#[derive(Resource, Default)]
pub struct FactoryMenuState {
    pub is_open: bool,
    pub selected: Option<Entity>,
}

const PANEL_WIDTH: f32 = 240.0;

pub fn setup_factory_menu_ui(mut commands: Commands) {
    commands
        .spawn((
            FactoryMenu,
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
            parent.spawn((
                Text::new("Hangi hammadde üretilsin?"),
                TextFont {
                    font_size: FontSize::Px(14.0),
                    ..default()
                },
                TextColor(Color::WHITE),
                Node {
                    margin: UiRect::bottom(Val::Px(4.0)),
                    ..default()
                },
            ));

            for product in ProductType::ALL {
                spawn_product_button(parent, product);
            }
        });
}

fn spawn_product_button(parent: &mut ChildSpawnerCommands, product: ProductType) {
    parent
        .spawn((
            FactoryMenuProductButton { product },
            Button,
            Interaction::default(),
            Node {
                width: Val::Percent(100.0),
                min_height: Val::Px(30.0),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                ..default()
            },
            BackgroundColor(Color::srgb(0.18, 0.18, 0.22)),
        ))
        .with_children(|parent| {
            parent.spawn((
                Text::new(format!("{}  ({} ¥)", product.label(), product.value())),
                TextFont {
                    font_size: FontSize::Px(13.0),
                    ..default()
                },
                TextColor(Color::WHITE),
            ));
        });
}

/// Show the panel near the cursor for the factory that was right-clicked, and
/// close the build menu so the two panels never overlap.
pub fn open_factory_menu_system(
    mut state: ResMut<FactoryMenuState>,
    mut query: Query<(&mut Node, &mut Visibility), With<FactoryMenu>>,
    mut event: MessageReader<OpenFactoryMenuEvent>,
    mut close_build: MessageWriter<CloseBuildMenuEvent>,
) {
    for ev in event.read() {
        state.is_open = true;
        state.selected = Some(ev.entity);

        if let Ok((mut node, mut visibility)) = query.single_mut() {
            *visibility = Visibility::Visible;
            node.left = Val::Px(ev.screen_position.x + 16.0);
            node.top = Val::Px(ev.screen_position.y + 16.0);
        }

        // Never have the build menu and factory panel open at the same time.
        close_build.write(CloseBuildMenuEvent);
    }
}

/// Read the chosen material buttons; when one is pressed, apply it to the
/// currently selected factory and close the panel.
pub fn factory_product_button_system(
    state: Res<FactoryMenuState>,
    buttons: Query<(&Interaction, &FactoryMenuProductButton), Changed<Interaction>>,
    mut set_events: MessageWriter<SetFactoryProductEvent>,
    mut close_events: MessageWriter<CloseFactoryMenuEvent>,
) {
    if !state.is_open {
        return;
    }

    for (interaction, button) in &buttons {
        if *interaction == Interaction::Pressed {
            if let Some(entity) = state.selected {
                set_events.write(SetFactoryProductEvent {
                    entity,
                    product: button.product,
                });
            }
            close_events.write(CloseFactoryMenuEvent);
            return;
        }
    }
}

/// Apply a chosen material to the factory.
pub fn set_factory_product_system(
    authority: Res<OnlineAuthority>,
    mut factories: Query<&mut Factory>,
    mut event: MessageReader<SetFactoryProductEvent>,
) {
    for ev in event.read() {
        // In online mode the server is the sole authority. The local component
        // is changed only by the authoritative snapshot.
        if authority.active {
            continue;
        }
        if let Ok(mut factory) = factories.get_mut(ev.entity) {
            factory.product = ev.product;
        }
    }
}

/// Close the factory panel when the Close event fires (material chosen, panel
/// toggled off, or build menu opened).
pub fn close_factory_menu_system(
    mut state: ResMut<FactoryMenuState>,
    mut query: Query<&mut Visibility, With<FactoryMenu>>,
    mut event: MessageReader<CloseFactoryMenuEvent>,
) {
    if event.read().next().is_some() {
        state.is_open = false;
        state.selected = None;

        if let Ok(mut visibility) = query.single_mut() {
            *visibility = Visibility::Hidden;
        }
    }
}

/// Close the factory panel with a left click outside any of its buttons.
pub fn close_factory_menu_on_left_click(
    mouse: Res<ButtonInput<MouseButton>>,
    state: Res<FactoryMenuState>,
    buttons: Query<&Interaction, (With<FactoryMenuProductButton>, With<Button>)>,
    mut close_events: MessageWriter<CloseFactoryMenuEvent>,
) {
    if !state.is_open || !mouse.just_pressed(MouseButton::Left) {
        return;
    }

    for interaction in &buttons {
        if *interaction == Interaction::Pressed {
            return;
        }
    }

    close_events.write(CloseFactoryMenuEvent);
}
