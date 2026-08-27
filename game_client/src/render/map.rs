use bevy::prelude::*;
use bevy::asset::RenderAssetUsages;
use bevy::render::mesh::{Indices, PrimitiveTopology};

#[derive(Component)]
pub struct MapRoot;

/// Total world size of the map (in world units), square. The whole map spans
/// from -half to +half on both axes.
pub const MAP_SIZE: f32 = 2000.0;
/// Number of cells per map side. `GRID_SIZE * CELL_SIZE == MAP_SIZE`,
/// so the map is exactly 2000 x 2000 world units with 100 x 100 cells.
pub const GRID_SIZE: usize = 100;
/// World units of one grid square. A building (2x2) occupies exactly two cells.
pub const CELL_SIZE: f32 = MAP_SIZE / GRID_SIZE as f32; // 20.0
/// Minimum world distance allowed between two building centres.
pub const MIN_BUILDING_DISTANCE: f32 = 50.0;
/// Building footprint in cells (2 x 2 squares as requested).
pub const BUILDING_FOOTPRINT: usize = 2;
/// World size of a building, matching the sprite size.
pub const BUILDING_SIZE: f32 = CELL_SIZE * BUILDING_FOOTPRINT as f32;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TerrainType {
    Sea,
    Land,
    Mountain,
}

/// Immutable grid of terrain cells. Placed as a resource so placement logic can
/// query what a tile is and snap buildings to the 2x2 grid.
#[derive(Resource)]
pub struct TerrainGrid {
    pub size: usize,
    pub cell_size: f32,
    pub cells: Vec<TerrainType>,
}

impl TerrainGrid {
    /// World coordinate of the exact centre of the whole map.
    fn half_world(&self) -> f32 {
        self.size as f32 * self.cell_size / 2.0
    }

    /// Convert a world position into integer cell coordinates.
    /// Returns None when the point lies outside the grid.
    pub fn world_to_cell(&self, pos: Vec2) -> Option<(usize, usize)> {
        let cx = ((pos.x + self.half_world()) / self.cell_size).floor() as i64;
        let cy = ((pos.y + self.half_world()) / self.cell_size).floor() as i64;
        if cx < 0 || cy < 0 || cx as usize >= self.size || cy as usize >= self.size {
            return None;
        }
        Some((cx as usize, cy as usize))
    }

    pub fn get(&self, x: usize, y: usize) -> TerrainType {
        self.cells[y * self.size + x]
    }

    /// True when a single cell is buildable flat land.
    pub fn is_land_at(&self, x: usize, y: usize) -> bool {
        x < self.size && y < self.size && self.get(x, y) == TerrainType::Land
    }

    /// True when a `footprint x footprint` area anchored at the cell of `pos`
    /// is fully buildable land (used for mountains/seas blocking).
    pub fn can_place_footprint(&self, pos: Vec2, footprint: usize) -> bool {
        let Some((cell_x, cell_y)) = self.world_to_cell(pos) else {
            return false;
        };
        let fx = cell_x - cell_x % footprint;
        let fy = cell_y - cell_y % footprint;
        for y in fy..fy + footprint {
            for x in fx..fx + footprint {
                if !self.is_land_at(x, y) {
                    return false;
                }
            }
        }
        true
    }

    /// Snap a world position to the centre of the nearest aligned footprint
    /// block so buildings line up exactly on the 2x2 grid.
    pub fn snap_centre(&self, pos: Vec2, footprint: usize) -> Vec2 {
        let half = self.half_world();
        let cx = ((pos.x + half) / self.cell_size).floor() as i64;
        let cy = ((pos.y + half) / self.cell_size).floor() as i64;
        let fx = cx - cx.rem_euclid(footprint as i64);
        let fy = cy - cy.rem_euclid(footprint as i64);
        let centre_x = (fx as f32 + footprint as f32 / 2.0) * self.cell_size - half;
        let centre_y = (fy as f32 + footprint as f32 / 2.0) * self.cell_size - half;
        Vec2::new(centre_x, centre_y)
    }
}

pub fn setup_map_system(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
) {
    let ter = build_terrain_grid();
    let half = ter.half_world();

    // --- Terrain tiles (one quad per cell, flat colours) ---
    let mut vertices: Vec<[f32; 3]> = Vec::with_capacity(GRID_SIZE * GRID_SIZE * 4);
    let mut colors: Vec<[f32; 4]> = Vec::with_capacity(GRID_SIZE * GRID_SIZE * 4);
    let mut indices: Vec<u32> = Vec::with_capacity(GRID_SIZE * GRID_SIZE * 6);

    for y in 0..GRID_SIZE {
        for x in 0..GRID_SIZE {
            let wx = -half + x as f32 * CELL_SIZE;
            let wy = -half + y as f32 * CELL_SIZE;
            let color = terrain_color(ter.get(x, y));
            let base = vertices.len() as u32;

            vertices.extend_from_slice(&[
                [wx, wy, -10.0],
                [wx + CELL_SIZE, wy, -10.0],
                [wx + CELL_SIZE, wy + CELL_SIZE, -10.0],
                [wx, wy + CELL_SIZE, -10.0],
            ]);
            colors.extend_from_slice(&[color; 4]);
            indices.extend_from_slice(&[base, base + 1, base + 2, base, base + 2, base + 3]);
        }
    }

    let mut tile_mesh = Mesh::new(
        PrimitiveTopology::TriangleList,
        RenderAssetUsages::default(),
    );
    tile_mesh.insert_attribute(Mesh::ATTRIBUTE_POSITION, vertices);
    tile_mesh.insert_attribute(Mesh::ATTRIBUTE_COLOR, colors);
    tile_mesh.insert_indices(Indices::U32(indices));

    let terrain_material = materials.add(ColorMaterial::default());

    commands.spawn((
        Mesh2d(meshes.add(tile_mesh)),
        MeshMaterial2d(terrain_material),
        Transform::default(),
        MapRoot,
    ));

    // Make the terrain grid queryable by the placement systems.
    commands.insert_resource(ter);
}

/// Build an in-world grid of thin quads and spawn it as a `Mesh2d`. Unlike the
/// old gizmo grid (which renders on top of every sprite), this mesh sits at
/// `z = -5`, i.e. above the terrain (`z = -10`) but below all buildings
/// (`z = 20`), so the grid lines never cover a building.
///
/// The grid uses a dedicated semi-transparent `ColorMaterial` (alpha < 1) so
/// Bevy places it in the Transparent 2D phase — properly alpha-blended and
/// depth-sorted behind the buildings, with no unstable opaque-phase overwrite
/// against the terrain.
pub fn setup_grid_lines(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
) {
    let half = MAP_SIZE / 2.0;
    let thickness = 1.0;

    let line_count = GRID_SIZE + 1;
    let mut vertices: Vec<[f32; 3]> = Vec::with_capacity(line_count * 2 * 4);
    let mut indices: Vec<u32> = Vec::with_capacity(line_count * 2 * 6);

    for i in 0..line_count {
        let p = -half + i as f32 * CELL_SIZE;
        // vertical line
        push_line_quad(&mut vertices, &mut indices, p, -half, p, half, thickness, 0.0);
        // horizontal line
        push_line_quad(&mut vertices, &mut indices, -half, p, half, p, thickness, 0.0);
    }

    let mut mesh = Mesh::new(
        PrimitiveTopology::TriangleList,
        RenderAssetUsages::default(),
    );
    mesh.insert_attribute(Mesh::ATTRIBUTE_POSITION, vertices);
    mesh.insert_indices(Indices::U32(indices));

    // Transparent material: routes this mesh into the blended Transparent 2D
    // phase so the lines are stable and never flicker against the terrain.
    let grid_material = materials.add(ColorMaterial::from(Color::srgba(1.0, 1.0, 1.0, 0.14)));

    commands.spawn((
        Mesh2d(meshes.add(mesh)),
        MeshMaterial2d(grid_material),
        Transform::from_xyz(0.0, 0.0, -5.0),
    ));
}

/// Append a thin quad (a straight line of the given thickness) to the grid mesh
/// buffers. Only positions/indices are written; the colour comes from the
/// grid's single transparent material.
fn push_line_quad(
    vertices: &mut Vec<[f32; 3]>,
    indices: &mut Vec<u32>,
    sx: f32,
    sy: f32,
    ex: f32,
    ey: f32,
    thickness: f32,
    z: f32,
) {
    let dx = ex - sx;
    let dy = ey - sy;
    let len = (dx * dx + dy * dy).sqrt();
    if len <= f32::EPSILON {
        return;
    }
    // Perpendicular unit vector scaled by half the line thickness.
    let hx = -dy / len * thickness / 2.0;
    let hy = dx / len * thickness / 2.0;

    let base = vertices.len() as u32;
    vertices.extend_from_slice(&[
        [sx + hx, sy + hy, z],
        [sx - hx, sy - hy, z],
        [ex - hx, ey - hy, z],
        [ex + hx, ey + hy, z],
    ]);
    indices.extend_from_slice(&[base, base + 1, base + 2, base, base + 2, base + 3]);
}


fn build_terrain_grid() -> TerrainGrid {
    // Keep the terrain formula identical to the server's authoritative mask.
    // This avoids shipping a large terrain grid over the network and removes
    // the old Perlin dependency from the client.
    let mut cells = Vec::with_capacity(GRID_SIZE * GRID_SIZE);
    for y in 0..GRID_SIZE {
        for x in 0..GRID_SIZE {
            let edge = x < 4 || y < 4 || x >= GRID_SIZE - 4 || y >= GRID_SIZE - 4;
            if edge {
                cells.push(TerrainType::Sea);
                continue;
            }

            let wx = -MAP_SIZE / 2.0 + (x as f32 + 0.5) * CELL_SIZE;
            let wy = -MAP_SIZE / 2.0 + (y as f32 + 0.5) * CELL_SIZE;
            let height = (wx / 180.0).sin() * 0.45
                + (wy / 230.0).cos() * 0.35
                + ((wx + wy) / 310.0).sin() * 0.20;
            let normalized = ((height + 1.0) / 2.0).clamp(0.0, 1.0);

            let terrain = if normalized < 0.08 {
                TerrainType::Sea
            } else if normalized < 0.84 {
                TerrainType::Land
            } else {
                TerrainType::Mountain
            };
            cells.push(terrain);
        }
    }

    TerrainGrid {
        size: GRID_SIZE,
        cell_size: CELL_SIZE,
        cells,
    }
}

fn terrain_color(terrain: TerrainType) -> [f32; 4] {
    match terrain {
        TerrainType::Sea => [0.06, 0.16, 0.55, 1.0],
        TerrainType::Land => [0.40, 0.65, 0.30, 1.0],
        TerrainType::Mountain => [0.52, 0.48, 0.45, 1.0],
    }
}

