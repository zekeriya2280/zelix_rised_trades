pub mod map;
pub mod vehicle_render;
pub mod ui;
pub mod camera;
pub mod build_menu;
pub mod placement;
pub mod factory_menu;
pub mod path;
pub mod logistics;

pub use map::*;
pub use vehicle_render::*;
pub use ui::*;
pub use camera::*;
pub use build_menu::*;
pub use placement::*;
pub use factory_menu::*;
pub use logistics::*;

use bevy::prelude::*;

pub struct RenderPlugin;

impl Plugin for RenderPlugin {
    fn build(&self, app: &mut App) {
        app.add_systems(
            Startup,
            (
                setup_camera_system,
                setup_map_system,
                setup_grid_lines,
                setup_ui_system,
                setup_build_menu_ui,
                setup_factory_menu_ui,
            ),
        )
        .add_systems(
            Update,
            (
                (
                    camera_pan_system,
                    camera_mouse_pan_system,
                    camera_zoom_system,
                    camera_mouse_zoom_system,
                    mouse_right_click_system,
                    open_build_menu_system,
                    open_factory_menu_system,
                    update_build_menu_buttons_system,
                    bank_button_system,
                    build_menu_button_system,
                    close_menu_on_left_click,
                    close_build_menu_system,
                )
                    .chain(),
                (
                    select_destination_system,
                    build_bank_system,
                    build_structure_system,
                    placement_preview_system,
                    draw_bank_radius_system,
                    factory_product_button_system,
                    set_factory_product_system,
                    factory_product_selected_system,
                    close_factory_menu_on_left_click,
                    close_factory_menu_system,
                    update_vehicle_visuals_system,
                    cleanup_finished_delivery_system,
                    update_logistics_hint_system,
                    update_materials_hud,
                    update_ui_system,
                )
                    .chain(),
            )
                .chain(),
        )
        .add_message::<crate::core::events::BuildBankEvent>()
        .add_message::<crate::core::events::BuildStructureEvent>()
        .add_message::<crate::core::events::OpenBuildMenuEvent>()
        .add_message::<crate::core::events::CloseBuildMenuEvent>()
        .add_message::<crate::core::events::OpenFactoryMenuEvent>()
        .add_message::<crate::core::events::CloseFactoryMenuEvent>()
        .add_message::<crate::core::events::SetFactoryProductEvent>()
        .init_resource::<crate::render::build_menu::BuildMenuState>()
        .init_resource::<crate::render::factory_menu::FactoryMenuState>()
        .init_resource::<crate::render::logistics::LogisticsSelection>()
        .init_resource::<crate::render::logistics::ActiveDelivery>()
        .init_resource::<crate::render::camera::CameraState>();

    }
}
