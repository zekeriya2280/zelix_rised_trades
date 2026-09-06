import numpy as np
from PIL import Image

TILE = 128
COLS = 5
ROWS = 3

def periodic_noise(size, seed, harmonics=4, base_freq=2):
    rng = np.random.RandomState(seed)
    X, Y = np.meshgrid(np.arange(size), np.arange(size))
    val = np.zeros((size, size), dtype=float)
    total_amp = 0.0
    for h in range(1, harmonics + 1):
        freq = base_freq * h
        amp = 1.0 / h
        phase_x = rng.uniform(0, 2 * np.pi)
        phase_y = rng.uniform(0, 2 * np.pi)
        term = np.sin(2 * np.pi * freq * X / size + phase_x) * np.cos(2 * np.pi * freq * Y / size + phase_y)
        val += amp * term
        total_amp += amp
    val /= total_amp
    val = (val - val.min()) / (val.max() - val.min() + 1e-9)
    return val

def water_material(base, seed, size=TILE):
    n = periodic_noise(size, seed, harmonics=3, base_freq=3)
    ripple = periodic_noise(size, seed + 1, harmonics=2, base_freq=6)
    color = np.array(base)
    img = np.zeros((size, size, 3))
    for c in range(3):
        v = color[c] * (0.80 + 0.30 * n)
        v += 0.10 * ripple * (1.0 if c == 2 else 0.55)
        img[..., c] = v
    return np.clip(img, 0, 1)

def grass_material(base, seed, size=TILE):
    n = periodic_noise(size, seed, harmonics=4, base_freq=4)
    fine = periodic_noise(size, seed + 2, harmonics=1, base_freq=26)
    color = np.array(base)
    img = np.zeros((size, size, 3))
    for c in range(3):
        v = color[c] * (0.82 + 0.30 * n)
        v += 0.07 * (fine - 0.5) * (1.2 if c == 1 else 0.6)
        img[..., c] = v
    return np.clip(img, 0, 1)

def rock_material(base, seed, size=TILE, snow=False):
    n = periodic_noise(size, seed, harmonics=4, base_freq=5)
    veins = periodic_noise(size, seed + 3, harmonics=2, base_freq=9)
    color = np.array(base)
    img = np.zeros((size, size, 3))
    vein_mask = (veins < 0.28).astype(float)
    for c in range(3):
        v = color[c] * (0.75 + 0.35 * n)
        v = v * (1 - 0.35 * vein_mask)
        img[..., c] = v
    if snow:
        speck = periodic_noise(size, seed + 7, harmonics=1, base_freq=30)
        snow_mask = (speck > 0.80).astype(float)
        for c in range(3):
            img[..., c] = img[..., c] * (1 - snow_mask) + 1.0 * snow_mask
    return np.clip(img, 0, 1)

# Order MUST match the client's palette arrays exactly:
# Sea(edge)=ocean x3, Sea(interior)=lake x3, Land x5, Mountain x4
materials = [
    ("ocean_deep",        "water", (0.04, 0.12, 0.45), 101, {}),
    ("ocean_swell",       "water", (0.05, 0.17, 0.53), 102, {}),
    ("ocean_trench",      "water", (0.03, 0.09, 0.38), 103, {}),
    ("lake_turquoise",    "water", (0.10, 0.46, 0.62), 104, {}),
    ("lake_shallow",      "water", (0.14, 0.56, 0.68), 105, {}),
    ("lake_deep",         "water", (0.08, 0.38, 0.58), 106, {}),
    ("meadow_green",      "grass", (0.40, 0.65, 0.30), 201, {}),
    ("deep_grass",        "grass", (0.34, 0.56, 0.28), 202, {}),
    ("dry_golden_plain",  "grass", (0.55, 0.68, 0.35), 203, {}),
    ("wheat_field",       "grass", (0.62, 0.60, 0.33), 204, {}),
    ("sage_plain",        "grass", (0.45, 0.64, 0.42), 205, {}),
    ("grey_rock",         "rock",  (0.52, 0.48, 0.45), 301, {}),
    ("dark_rock",         "rock",  (0.42, 0.36, 0.34), 302, {}),
    ("pale_stone",        "rock",  (0.60, 0.56, 0.50), 303, {}),
    ("snow_edge",         "rock",  (0.70, 0.68, 0.66), 304, {"snow": True}),
]

assert len(materials) == COLS * ROWS

atlas = np.zeros((ROWS * TILE, COLS * TILE, 3), dtype=np.uint8)

for idx, (name, kind, base, seed, kwargs) in enumerate(materials):
    if kind == "water":
        tile = water_material(base, seed)
    elif kind == "grass":
        tile = grass_material(base, seed)
    else:
        tile = rock_material(base, seed, **kwargs)
    tile_u8 = (tile * 255).astype(np.uint8)
    row, col = divmod(idx, COLS)
    atlas[row*TILE:(row+1)*TILE, col*TILE:(col+1)*TILE, :] = tile_u8
    print(f"{idx:2d} {name:18s} kind={kind:5s} row={row} col={col}")

img = Image.fromarray(atlas, mode="RGB")
out_path = "/home/claude/texgen/terrain_atlas.png"
img.save(out_path)
print("saved", out_path, img.size)
