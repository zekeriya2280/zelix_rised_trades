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

/// Centralized world-space render layers for all 2D gameplay visuals.
/// Mesh vertex Z must remain local (normally 0); the entity Transform Z is
/// the authoritative layer used by Bevy 2D rendering.
pub const TERRAIN_Z: f32 = -20.0;
pub const GRID_Z: f32 = -10.0;
pub const ROAD_Z: f32 = 0.0;
pub const VEHICLE_Z: f32 = 5.0;
pub const BUILDING_Z: f32 = 20.0;

/// Procedurally generated terrain material atlas. Each 2x2 block picks one
/// cell of this atlas instead of a flat vertex colour, so the map reads as a
/// mosaic of distinct materials (ocean, lake, grass, wheat, rock, snow...)
/// rather than a handful of solid colours. Generated offline as a seamless,
/// tileable texture per material (see `game_client/assets/terrain_atlas.png`).
pub const TERRAIN_ATLAS_PATH: &str = "terrain_atlas.png";
pub const ATLAS_COLS: usize = 5;
pub const ATLAS_ROWS: usize = 3;

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
    asset_server: Res<AssetServer>,
) {
    let ter = build_terrain_grid();
    let half = ter.half_world();

    // --- Terrain tiles (one quad per cell, textured from the material atlas) ---
    let mut vertices: Vec<[f32; 3]> = Vec::with_capacity(GRID_SIZE * GRID_SIZE * 4);
    let mut uvs: Vec<[f32; 2]> = Vec::with_capacity(GRID_SIZE * GRID_SIZE * 4);
    let mut indices: Vec<u32> = Vec::with_capacity(GRID_SIZE * GRID_SIZE * 6);

    for y in 0..GRID_SIZE {
        for x in 0..GRID_SIZE {
            let wx = -half + x as f32 * CELL_SIZE;
            let wy = -half + y as f32 * CELL_SIZE;
            let is_edge = x < 4 || y < 4 || x >= GRID_SIZE - 4 || y >= GRID_SIZE - 4;
            let material_index = terrain_material_index(ter.get(x, y), x, y, is_edge);
            let base = vertices.len() as u32;

            vertices.extend_from_slice(&[
                [wx, wy, 0.0],
                [wx + CELL_SIZE, wy, 0.0],
                [wx + CELL_SIZE, wy + CELL_SIZE, 0.0],
                [wx, wy + CELL_SIZE, 0.0],
            ]);
            uvs.extend_from_slice(&atlas_uv_rect(material_index));
            indices.extend_from_slice(&[base, base + 1, base + 2, base, base + 2, base + 3]);
        }
    }

    let mut tile_mesh = Mesh::new(
        PrimitiveTopology::TriangleList,
        RenderAssetUsages::default(),
    );
    tile_mesh.insert_attribute(Mesh::ATTRIBUTE_POSITION, vertices);
    tile_mesh.insert_attribute(Mesh::ATTRIBUTE_UV_0, uvs);
    tile_mesh.insert_indices(Indices::U32(indices));

    let atlas_handle: Handle<Image> = asset_server.load(TERRAIN_ATLAS_PATH);
    let terrain_material = materials.add(ColorMaterial::from(atlas_handle));

    commands.spawn((
        Mesh2d(meshes.add(tile_mesh)),
        MeshMaterial2d(terrain_material),
        Transform::from_xyz(0.0, 0.0, TERRAIN_Z),
        MapRoot,
    ));

    // Make the terrain grid queryable by the placement systems.
    commands.insert_resource(ter);
}

/// Build an in-world grid of thin quads and spawn it as a `Mesh2d`. Unlike the
/// old gizmo grid (which renders on top of every sprite), this mesh sits at
/// The grid entity is placed at `GRID_Z`, above the terrain and below roads,
/// vehicles, and buildings. Mesh vertices stay at local Z = 0 so render
/// ordering is controlled in exactly one place: the entity Transform.
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

    // Black, semi-transparent material: dark enough to read as clean black
    // grid lines against every terrain colour while still letting the
    // terrain show through. The entity Transform controls the Z layer.
    let grid_material = materials.add(ColorMaterial::from(Color::srgba(0.0, 0.0, 0.0, 0.45)));

    commands.spawn((
        Mesh2d(meshes.add(mesh)),
        MeshMaterial2d(grid_material),
        Transform::from_xyz(0.0, 0.0, GRID_Z),
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

/// Number of colour/material variants in each terrain family. Must match the
/// atlas layout in `generate_atlas.py` exactly: 3 ocean + 3 lake + 5 land +
/// 4 mountain = 15 cells, laid out row-major in a 5x3 grid.
const OCEAN_VARIANTS: usize = 3;
const LAKE_VARIANTS: usize = 3;
const LAND_VARIANTS: usize = 5;
const MOUNTAIN_VARIANTS: usize = 4;

const OCEAN_BASE: usize = 0;
const LAKE_BASE: usize = OCEAN_BASE + OCEAN_VARIANTS; // 3
const LAND_BASE: usize = LAKE_BASE + LAKE_VARIANTS; // 6
const MOUNTAIN_BASE: usize = LAND_BASE + LAND_VARIANTS; // 11

/// Atlas cell (material index, 0..15) for one terrain cell. Every 2x2 cell
/// block (matching the building footprint) rolls its own material, so
/// mountains/plains/lakes read as a varied, hand-painted mosaic instead of
/// flat single-colour bands. `is_edge` distinguishes the forced sea border
/// (ocean material) from inland sea cells, which use the lake materials
/// instead. This is a purely visual choice: it does not change
/// `TerrainType`, so buildability (which only ever checks for
/// `TerrainType::Land`) is unaffected.
fn terrain_material_index(terrain: TerrainType, x: usize, y: usize, is_edge: bool) -> usize {
    let block_x = (x / 2) as u32;
    let block_y = (y / 2) as u32;
    let v = block_hash(block_x, block_y);

    match terrain {
        TerrainType::Sea if is_edge => OCEAN_BASE + pick_index(OCEAN_VARIANTS, v),
        TerrainType::Sea => LAKE_BASE + pick_index(LAKE_VARIANTS, v),
        TerrainType::Land => LAND_BASE + pick_index(LAND_VARIANTS, v),
        TerrainType::Mountain => MOUNTAIN_BASE + pick_index(MOUNTAIN_VARIANTS, v),
    }
}

/// Deterministic, seedless pseudo-random value in `[0, 1)` for one 2x2 block.
/// Same block coordinates always produce the same value, so the material
/// choice above is stable across frames/restarts without storing anything.
fn block_hash(block_x: u32, block_y: u32) -> f32 {
    let mut h = block_x.wrapping_mul(0x27d4_eb2d) ^ block_y.wrapping_mul(0x1656_67b1);
    h ^= h >> 15;
    h = h.wrapping_mul(0x85eb_ca6b);
    h ^= h >> 13;
    (h & 0xFFFF) as f32 / 65535.0
}

/// Pick one variant index out of `count` using a `[0, 1)` value.
fn pick_index(count: usize, v: f32) -> usize {
    ((v * count as f32) as usize).min(count - 1)
}

/// UV corners (matching the vertex winding in `setup_map_system`) for the
/// atlas cell that holds `material_index`. Each terrain quad samples exactly
/// one atlas cell, so no wrapping/tiling inside the shader is needed — the
/// atlas image itself is a seamless texture per material, and identical
/// neighbouring blocks simply repeat the same cell.
fn atlas_uv_rect(material_index: usize) -> [[f32; 2]; 4] {
    let col = (material_index % ATLAS_COLS) as f32;
    let row = (material_index / ATLAS_COLS) as f32;
    let u0 = col / ATLAS_COLS as f32;
    let v0 = row / ATLAS_ROWS as f32;
    let u1 = (col + 1.0) / ATLAS_COLS as f32;
    let v1 = (row + 1.0) / ATLAS_ROWS as f32;
    [[u0, v1], [u1, v1], [u1, v0], [u0, v0]]
}

