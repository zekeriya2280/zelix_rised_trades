//! Grid-based shortest-path (A*) over the terrain grid.
//!
//! Roads are computed over the discrete `TerrainGrid` cells instead of a
//! straight bird's-eye line, and they never cross cells that are blocked
//! (buildings, mountains or sea).

use std::cmp::Reverse;
use std::collections::{BinaryHeap, HashMap};

use bevy::prelude::*;

use crate::render::map::{BUILDING_FOOTPRINT, TerrainGrid, TerrainType};

/// Build the shortest road between two buildings over the terrain grid.
pub fn route_between<F: Fn(usize, usize) -> bool>(
    terrain: &TerrainGrid,
    is_blocked: &F,
    from: Vec2,
    to: Vec2,
) -> Option<Vec<Vec2>> {
    // Hop off the source/destination building on the side that faces the
    // target, so the road leaves and arrives at the boundary cell that points
    // toward the other building (not at an unrelated nearby cell).
    let start_cell = boundary_cell_towards(terrain, is_blocked, from, BUILDING_FOOTPRINT, to)
        .or_else(|| nearest_walkable(terrain, is_blocked, from))?;
    let end_cell = boundary_cell_towards(terrain, is_blocked, to, BUILDING_FOOTPRINT, from)
        .or_else(|| nearest_walkable(terrain, is_blocked, to))?;

    astar(terrain, is_blocked, start_cell, end_cell)
}

/// A* over the grid from a fixed start cell to a fixed end cell.
fn astar<F: Fn(usize, usize) -> bool>(
    terrain: &TerrainGrid,
    is_blocked: &F,
    start_cell: (i64, i64),
    end_cell: (i64, i64),
) -> Option<Vec<Vec2>> {
    let size = terrain.size as i64;
    let cell = terrain.cell_size;
    let half = size as f32 * cell / 2.0;

    if start_cell == end_cell {
        return Some(vec![cell_center(half, cell, start_cell)]);
    }

    let walkable = |x: i64, y: i64| {
        in_bounds(x, y, size)
            && !is_blocked(x as usize, y as usize)
            && terrain.get(x as usize, y as usize) == TerrainType::Land
    };

    // Manhattan heuristic (4-way movement) in whole cells — integer A* costs.
    let h = |x: i64, y: i64| (x - end_cell.0).abs() + (y - end_cell.1).abs();

    let mut open: BinaryHeap<Reverse<(i64, i64, i64)>> = BinaryHeap::new();
    let mut g_score: HashMap<(i64, i64), i64> = HashMap::new();
    let mut came: HashMap<(i64, i64), (i64, i64)> = HashMap::new();

    g_score.insert(start_cell, 0);
    open.push(Reverse((h(start_cell.0, start_cell.1), start_cell.0, start_cell.1)));

    const NEIGHBORS: [(i64, i64); 4] = [(1, 0), (-1, 0), (0, 1), (0, -1)];

    while let Some(Reverse((_, cx, cy))) = open.pop() {
        let cur = (cx, cy);
        if cur == end_cell {
            break;
        }
        let Some(&cur_g) = g_score.get(&cur) else {
            continue;
        };

        for (dx, dy) in NEIGHBORS {
            let nx = cx + dx;
            let ny = cy + dy;
            if !walkable(nx, ny) {
                continue;
            }
            let key = (nx, ny);
            let ng = cur_g + 1;
            if ng < *g_score.get(&key).unwrap_or(&i64::MAX) {
                g_score.insert(key, ng);
                came.insert(key, cur);
                open.push(Reverse((ng + h(nx, ny), nx, ny)));
            }
        }
    }

    if !came.contains_key(&end_cell) {
        return None;
    }

    let mut cells = Vec::new();
    let mut cur = end_cell;
    loop {
        cells.push(cur);
        if cur == start_cell {
            break;
        }
        match came.get(&cur) {
            Some(&prev) => cur = prev,
            None => break,
        }
    }
    cells.reverse();

    Some(
        cells
            .iter()
            .map(|&(x, y)| cell_center(half, cell, (x, y)))
            .collect(),
    )
}

/// Pick a walkable grid cell directly beside a building footprint, on the side
/// that faces `target` (e.g. destination right of the factory, so we start at
/// the factory's right-hand boundary cell).
fn boundary_cell_towards<F: Fn(usize, usize) -> bool>(
    terrain: &TerrainGrid,
    is_blocked: &F,
    center: Vec2,
    footprint: usize,
    target: Vec2,
) -> Option<(i64, i64)> {
    let size = terrain.size as i64;
    let cell = terrain.cell_size;
    let half = size as f32 * cell / 2.0;

    let (cx, cy) = terrain.world_to_cell(center)?;
    let fx = (cx - cx % footprint) as i64;
    let fy = (cy - cy % footprint) as i64;
    let f = footprint as i64;

    let dir = (target - center).normalize_or_zero();

    let mut best = None;
    let mut best_score = -1.0f32;

    for y in (fy - 1)..=(fy + f) {
        for x in (fx - 1)..=(fx + f) {
            let inside = x >= fx && x < fx + f && y >= fy && y < fy + f;
            if inside || !in_bounds(x, y, size) {
                continue;
            }
            let (xu, yu) = (x as usize, y as usize);
            if is_blocked(xu, yu) {
                continue;
            }
            if terrain.get(xu, yu) != TerrainType::Land {
                continue;
            }
            let c = cell_center(half, cell, (x, y));
            let away = (c - center).normalize_or_zero();
            let score = away.dot(dir);
            if score > best_score {
                best_score = score;
                best = Some((x, y));
            }
        }
    }

    best
}

fn in_bounds(x: i64, y: i64, size: i64) -> bool {
    x >= 0 && y >= 0 && x < size && y < size
}

fn cell_center(half: f32, cell: f32, c: (i64, i64)) -> Vec2 {
    Vec2::new(
        -half + (c.0 as f32 + 0.5) * cell,
        -half + (c.1 as f32 + 0.5) * cell,
    )
}

/// Find the closest walkable (land, not blocked) cell near a world position.
/// Start/end points usually sit on a building, so we hop to a free cell beside
/// them before routing.
fn nearest_walkable<F: Fn(usize, usize) -> bool>(
    terrain: &TerrainGrid,
    is_blocked: &F,
    world: Vec2,
) -> Option<(i64, i64)> {
    let size = terrain.size as i64;
    let cell = terrain.cell_size;
    let half = size as f32 * cell / 2.0;

    let (cx, cy) = terrain.world_to_cell(world)?;
    let (cx, cy) = (cx as i64, cy as i64);

    const RADIUS: i64 = 2;
    let mut best = None;
    let mut best_d = f32::MAX;

    for dy in -RADIUS..=RADIUS {
        for dx in -RADIUS..=RADIUS {
            let x = cx + dx;
            let y = cy + dy;
            if !in_bounds(x, y, size) {
                continue;
            }
            let (xu, yu) = (x as usize, y as usize);
            if is_blocked(xu, yu) {
                continue;
            }
            if terrain.get(xu, yu) != TerrainType::Land {
                continue;
            }
            let center = cell_center(half, cell, (x, y));
            let d = center.distance(world);
            if d < best_d {
                best_d = d;
                best = Some((x, y));
            }
        }
    }

    best
}