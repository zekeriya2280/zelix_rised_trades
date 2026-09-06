import math
import numpy as np
from PIL import Image, ImageDraw

TILE = 128
COLS = 5
ROWS = 3

def octagon_points(cx, cy, r, rotate_deg):
    pts = []
    for i in range(8):
        ang = math.radians(rotate_deg + i * 45)
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    return pts

def gem_icon(base_rgb, seed, size=TILE):
    base = np.array(base_rgb)

    # Opaque base layer: backdrop + faceted "emerald cut" steps. All alpha=255
    # here, so plain RGB drawing is correct (no blending needed).
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)

    backdrop = tuple(int(c) for c in np.clip(base * 0.40 * 255, 0, 255))
    draw.rectangle([0, 0, size, size], fill=backdrop)

    cx, cy = size / 2, size / 2
    max_r = size * 0.47
    steps = 5
    for i in range(steps, 0, -1):
        r = max_r * i / steps
        shade = 0.55 + 0.55 * (1 - i / steps)
        color = tuple(int(c) for c in np.clip(base * shade * 255, 0, 255))
        poly = octagon_points(cx, cy, r, 22.5)
        draw.polygon(poly, fill=color)

    # Translucent overlay: facet lines, outline, highlight, glint. These have
    # real alpha < 255, so they are composited onto the opaque base rather
    # than drawn as flat opaque shapes.
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay, "RGBA")

    outer = octagon_points(cx, cy, max_r, 22.5)
    for (px, py) in outer:
        odraw.line([cx, cy, px, py], fill=(255, 255, 255, 45), width=1)

    odraw.polygon(outer, outline=(10, 10, 10, 170), width=3)

    hl_x, hl_y = cx - max_r * 0.30, cy - max_r * 0.32
    hw, hh = size * 0.085, size * 0.05
    odraw.ellipse([hl_x - hw, hl_y - hh, hl_x + hw, hl_y + hh], fill=(255, 255, 255, 100))

    gx, gy = cx + max_r * 0.20, cy + max_r * 0.24
    gr = size * 0.03
    odraw.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=(255, 255, 255, 80))

    final = Image.alpha_composite(img.convert("RGBA"), overlay)
    return final.convert("RGB")

materials = [
    ("ocean_deep",        (0.04, 0.12, 0.45), 101),
    ("ocean_swell",       (0.05, 0.17, 0.53), 102),
    ("ocean_trench",      (0.03, 0.09, 0.38), 103),
    ("lake_turquoise",    (0.10, 0.46, 0.62), 104),
    ("lake_shallow",      (0.14, 0.56, 0.68), 105),
    ("lake_deep",         (0.08, 0.38, 0.58), 106),
    ("meadow_green",      (0.40, 0.65, 0.30), 201),
    ("deep_grass",        (0.34, 0.56, 0.28), 202),
    ("dry_golden_plain",  (0.55, 0.68, 0.35), 203),
    ("wheat_field",       (0.62, 0.60, 0.33), 204),
    ("sage_plain",        (0.45, 0.64, 0.42), 205),
    ("grey_rock",         (0.52, 0.48, 0.45), 301),
    ("dark_rock",         (0.42, 0.36, 0.34), 302),
    ("pale_stone",        (0.60, 0.56, 0.50), 303),
    ("snow_edge",         (0.70, 0.68, 0.66), 304),
]

assert len(materials) == COLS * ROWS
atlas = Image.new("RGB", (COLS * TILE, ROWS * TILE))
for idx, (name, base, seed) in enumerate(materials):
    tile_img = gem_icon(base, seed)
    row, col = divmod(idx, COLS)
    atlas.paste(tile_img, (col * TILE, row * TILE))

out_path = "/home/claude/texgen/terrain_atlas.png"
atlas.save(out_path)
print("saved", out_path, atlas.size)
