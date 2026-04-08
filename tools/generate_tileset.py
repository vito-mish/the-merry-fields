#!/usr/bin/env python3
"""
Generate farm tileset for The Merry Fields.
Output: assets/tilesets/farm_tiles.png
Tile size: 16x16, layout: 8 tiles wide x 1 tall (128x16)

Tile index:
  0 = Grass
  1 = Dirt (farmable)
  2 = Tilled soil
  3 = Watered soil
  4 = Stone path
  5 = Water
  6 = Fence
  7 = Border (solid, impassable)
"""

import struct, zlib, os

def save_png(path, pixels, w, h):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b""
    for row in pixels:
        raw += b"\x00"
        for r, g, b, a in row:
            raw += bytes([r, g, b, a])
    ihdr = struct.pack(">II", w, h) + bytes([8, 6, 0, 0, 0])
    data = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)

# ── Tile definitions (16×16 pixels each) ──────────────────────────────────

def make_grass():
    base = (82, 148, 60, 255)
    light = (102, 172, 76, 255)
    dark = (60, 118, 44, 255)
    blade = (120, 190, 88, 255)
    t = [[base]*16 for _ in range(16)]
    # Blade patterns
    for x, y in [(2,12),(2,13),(3,12),(7,11),(7,12),(8,11),(12,13),(12,14),(13,12)]:
        t[y][x] = blade
    # Dark spots
    for x, y in [(5,8),(10,5),(1,3),(14,10),(8,14)]:
        t[y][x] = dark
    # Light patches
    for x, y in [(4,2),(9,7),(13,3),(2,10),(11,12)]:
        t[y][x] = light
    return t

def make_dirt():
    base = (174, 128, 82, 255)
    light = (196, 152, 104, 255)
    dark = (140, 98, 56, 255)
    t = [[base]*16 for _ in range(16)]
    for x, y in [(3,3),(9,2),(13,5),(5,9),(11,11),(2,13),(14,8)]:
        t[y][x] = dark
    for x, y in [(6,5),(1,7),(12,3),(7,13),(4,11)]:
        t[y][x] = light
    return t

def make_tilled():
    base = (120, 82, 44, 255)
    furrow = (88, 56, 26, 255)
    ridge = (148, 108, 66, 255)
    t = [[base]*16 for _ in range(16)]
    for y in range(0, 16, 3):
        for x in range(16):
            t[y][x] = furrow
    for y in range(1, 16, 3):
        for x in range(16):
            t[y][x] = ridge
    return t

def make_watered():
    base = (90, 58, 30, 255)
    wet = (68, 42, 18, 255)
    sheen = (108, 80, 50, 255)
    t = [[base]*16 for _ in range(16)]
    for y in range(0, 16, 3):
        for x in range(16):
            t[y][x] = wet
    for y in range(1, 16, 3):
        for x in range(0, 16, 4):
            t[y][x] = sheen
    return t

def make_path():
    base = (162, 148, 128, 255)
    stone = (140, 128, 108, 255)
    gap = (120, 108, 90, 255)
    light = (180, 168, 150, 255)
    t = [[base]*16 for _ in range(16)]
    # Stone blocks
    for y in range(1, 7):
        for x in range(1, 7):
            t[y][x] = stone
    for y in range(1, 7):
        for x in range(9, 15):
            t[y][x] = stone
    for y in range(9, 15):
        for x in range(1, 7):
            t[y][x] = stone
    for y in range(9, 15):
        for x in range(9, 15):
            t[y][x] = stone
    # Highlights
    for x in [1,9]:
        for y in [1,9]:
            t[y][x] = light
    # Gaps
    for i in range(16):
        t[7][i] = gap
        t[8][i] = gap
        t[i][7] = gap
        t[i][8] = gap
    return t

def make_water():
    deep = (48, 100, 180, 255)
    mid = (68, 130, 210, 255)
    light = (100, 165, 235, 255)
    foam = (160, 210, 245, 255)
    t = [[mid]*16 for _ in range(16)]
    for y in range(16):
        for x in range(16):
            if (x + y * 2) % 7 < 2:
                t[y][x] = light
            if (x * 2 + y) % 9 < 1:
                t[y][x] = deep
    for x, y in [(3,4),(10,2),(5,10),(13,8),(7,14)]:
        t[y][x] = foam
        if x+1 < 16: t[y][x+1] = foam
    return t

def make_fence():
    wood = (140, 98, 56, 255)
    dark = (100, 66, 30, 255)
    light = (172, 130, 82, 255)
    t = [[(0,0,0,0)]*16 for _ in range(16)]
    # Posts
    for y in range(16):
        for x in [0,1,14,15]:
            t[y][x] = wood
    for x in [1,14]:
        t[0][x] = light
    # Rails
    for x in range(16):
        for y in [5,6,10,11]:
            t[y][x] = wood
    for x in range(16):
        t[5][x] = light
        t[10][x] = light
    # Dark shading
    for x in [0,14]:
        for y in range(16):
            t[y][x] = dark
    for x in range(16):
        t[6][x] = dark
        t[11][x] = dark
    return t

def make_border():
    base = (50, 90, 38, 255)
    dark = (36, 66, 26, 255)
    bush = (68, 120, 50, 255)
    t = [[base]*16 for _ in range(16)]
    for y in range(0, 8):
        for x in range(16):
            t[y][x] = bush
    for x, y in [(3,3),(9,1),(13,5),(1,6),(7,4)]:
        t[y][x] = dark
    for y in range(8, 16):
        for x in range(16):
            t[y][x] = dark
    return t

# ── Compose sprite sheet ────────────────────────────────────────────────────

TILES = [
    make_grass(),
    make_dirt(),
    make_tilled(),
    make_watered(),
    make_path(),
    make_water(),
    make_fence(),
    make_border(),
]

SHEET_W = 16 * len(TILES)
SHEET_H = 16

sheet = [[(0,0,0,0)] * SHEET_W for _ in range(SHEET_H)]

for ti, tile in enumerate(TILES):
    ox = ti * 16
    for y in range(16):
        for x in range(16):
            sheet[y][ox + x] = tile[y][x]

OUT = "assets/tilesets/farm_tiles.png"
save_png(OUT, sheet, SHEET_W, SHEET_H)
print(f"Saved {OUT} ({SHEET_W}x{SHEET_H}, {len(TILES)} tiles)")
