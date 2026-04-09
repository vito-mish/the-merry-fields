#!/usr/bin/env python3
"""
Generate combined seasonal farm tileset for The Merry Fields.
Output: assets/tilesets/farm_tiles.png
  128 x 64 pixels — 8 tiles wide (16px each) × 4 seasons tall (16px each)
  Row 0 (y=0):  Spring
  Row 1 (y=16): Summer
  Row 2 (y=32): Autumn
  Row 3 (y=48): Winter

Tile index (per row):
  0=Grass 1=Dirt 2=Tilled 3=Watered 4=Path 5=Water 6=Fence 7=Border
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

# ── Shared tiles (unchanged across seasons) ───────────────────────────────────

def make_dirt():
    base = (174, 128, 82, 255); light = (196, 152, 104, 255); dark = (140, 98, 56, 255)
    t = [[base]*16 for _ in range(16)]
    for x, y in [(3,3),(9,2),(13,5),(5,9),(11,11),(2,13),(14,8)]: t[y][x] = dark
    for x, y in [(6,5),(1,7),(12,3),(7,13),(4,11)]:               t[y][x] = light
    return t

def make_tilled():
    base = (120, 82, 44, 255); furrow = (88, 56, 26, 255); ridge = (148, 108, 66, 255)
    t = [[base]*16 for _ in range(16)]
    for y in range(0, 16, 3):
        for x in range(16): t[y][x] = furrow
    for y in range(1, 16, 3):
        for x in range(16): t[y][x] = ridge
    return t

def make_watered():
    base = (90, 58, 30, 255); wet = (68, 42, 18, 255); sheen = (108, 80, 50, 255)
    t = [[base]*16 for _ in range(16)]
    for y in range(0, 16, 3):
        for x in range(16): t[y][x] = wet
    for y in range(1, 16, 3):
        for x in range(0, 16, 4): t[y][x] = sheen
    return t

def make_path():
    base = (162, 148, 128, 255); stone = (140, 128, 108, 255)
    gap = (120, 108, 90, 255);   light = (180, 168, 150, 255)
    t = [[base]*16 for _ in range(16)]
    for y in range(1, 7):
        for x in range(1, 7):  t[y][x] = stone
        for x in range(9, 15): t[y][x] = stone
    for y in range(9, 15):
        for x in range(1, 7):  t[y][x] = stone
        for x in range(9, 15): t[y][x] = stone
    for x in [1, 9]:
        for y in [1, 9]: t[y][x] = light
    for i in range(16):
        t[7][i] = gap; t[8][i] = gap; t[i][7] = gap; t[i][8] = gap
    return t

def make_fence():
    wood = (140, 98, 56, 255); dark = (100, 66, 30, 255); light = (172, 130, 82, 255)
    t = [[(0,0,0,0)]*16 for _ in range(16)]
    for y in range(16):
        for x in [0,1,14,15]: t[y][x] = wood
    for x in [1,14]: t[0][x] = light
    for x in range(16):
        for y in [5,6,10,11]: t[y][x] = wood
    for x in range(16):
        t[5][x] = light; t[10][x] = light; t[6][x] = dark; t[11][x] = dark
    for x in [0, 14]:
        for y in range(16): t[y][x] = dark
    return t

# ── Seasonal GRASS ────────────────────────────────────────────────────────────

def make_grass_spring():
    base=(82,150,58,255); light=(106,178,78,255); dark=(58,116,40,255)
    blade=(128,198,90,255); petal=(252,240,220,255); center=(230,140,170,255)
    t = [[base]*16 for _ in range(16)]
    for x,y in [(2,12),(2,13),(3,12),(7,11),(7,12),(8,11),(12,13),(12,14),(13,12)]: t[y][x]=blade
    for x,y in [(5,8),(10,5),(1,3),(14,10),(8,14)]:  t[y][x]=dark
    for x,y in [(4,2),(9,7),(13,3),(2,10),(11,12)]:  t[y][x]=light
    for x,y in [(5,4),(11,9),(2,7)]:
        t[y][x]=center
        if x+1<16: t[y][x+1]=petal
    return t

def make_grass_summer():
    base=(52,118,32,255); light=(72,148,48,255); dark=(36,88,20,255); dry=(158,168,52,255)
    t = [[base]*16 for _ in range(16)]
    for x,y in [(5,8),(10,5),(1,3),(14,10),(8,14),(3,1),(12,6)]: t[y][x]=dark
    for x,y in [(4,2),(9,7),(13,3),(2,10),(11,12),(7,4),(0,13)]: t[y][x]=light
    for x,y in [(7,6),(12,11),(3,9),(15,3)]: t[y][x]=dry
    return t

def make_grass_autumn():
    base=(108,98,52,255); dark=(78,68,34,255); light=(132,118,70,255)
    lo=(204,96,28,255); lr=(180,52,24,255); ly=(212,172,36,255)
    t = [[base]*16 for _ in range(16)]
    for x,y in [(5,8),(10,5),(1,3),(14,10)]:  t[y][x]=dark
    for x,y in [(4,2),(9,7),(13,3),(2,10)]:   t[y][x]=light
    for x,y in [(3,4),(11,3),(8,12),(0,10)]:
        t[y][x]=lo
        if x+1<16: t[y][x+1]=lo
    for x,y in [(1,11),(13,7),(6,2)]:  t[y][x]=lr
    for x,y in [(8,5),(4,13),(14,2),(10,9)]: t[y][x]=ly
    return t

def make_grass_winter():
    snow=(220,230,245,255); shadow=(185,198,220,255)
    ice=(245,250,255,255); peek=(68,108,52,255)
    t = [[snow]*16 for _ in range(16)]
    for x,y in [(3,3),(9,2),(13,6),(1,9),(6,12),(14,5),(10,14)]:
        t[y][x]=shadow
        if x+1<16: t[y][x+1]=shadow
    for x,y in [(5,1),(11,4),(7,8),(2,12),(15,10)]: t[y][x]=ice
    for x,y in [(4,15),(9,15),(13,14),(1,14)]:      t[y][x]=peek
    return t

# ── Seasonal BORDER ───────────────────────────────────────────────────────────

def make_border_spring():
    base=(50,90,38,255); dark=(36,66,26,255); bush=(72,136,52,255); bloom=(210,170,200,255)
    t = [[base]*16 for _ in range(16)]
    for y in range(0,8):
        for x in range(16): t[y][x]=bush
    for x,y in [(3,3),(9,1),(13,5),(1,6),(7,4)]: t[y][x]=dark
    for x,y in [(2,2),(6,5),(11,3),(14,1)]:      t[y][x]=bloom
    for y in range(8,16):
        for x in range(16): t[y][x]=dark
    return t

def make_border_summer():
    base=(42,80,30,255); dark=(28,56,18,255); bush=(56,110,38,255); hi=(72,138,52,255)
    t = [[base]*16 for _ in range(16)]
    for y in range(0,8):
        for x in range(16): t[y][x]=bush
    for x,y in [(3,3),(9,1),(13,5),(1,6),(7,4)]: t[y][x]=dark
    for x,y in [(5,2),(11,4),(2,6)]:             t[y][x]=hi
    for y in range(8,16):
        for x in range(16): t[y][x]=dark
    return t

def make_border_autumn():
    base=(90,68,30,255); dark=(60,42,16,255)
    orange=(190,90,24,255); red=(160,50,20,255); yellow=(200,158,30,255)
    t = [[base]*16 for _ in range(16)]
    for y in range(0,8):
        for x in range(16): t[y][x]=orange
    for x,y in [(3,3),(9,1),(13,5)]: t[y][x]=red
    for x,y in [(1,6),(7,4),(11,2)]: t[y][x]=yellow
    for y in range(8,16):
        for x in range(16): t[y][x]=dark
    return t

def make_border_winter():
    snow=(215,225,242,255); hi=(240,246,255,255); shadow=(178,192,215,255)
    branch=(58,44,26,255); bark=(82,64,36,255)
    t = [[snow]*16 for _ in range(16)]
    for x,y in [(3,1),(9,0),(13,3),(1,5),(7,2),(14,4)]: t[y][x]=shadow
    for x,y in [(5,1),(11,3),(2,4)]:                     t[y][x]=hi
    for y in range(8,16):
        for x in range(16): t[y][x]=branch
    for x,y in [(2,9),(6,11),(10,9),(14,12),(4,14)]: t[y][x]=bark
    return t

# ── Seasonal WATER ────────────────────────────────────────────────────────────

def make_water_normal():
    deep=(48,100,180,255); mid=(68,130,210,255); light=(100,165,235,255); foam=(160,210,245,255)
    t = [[mid]*16 for _ in range(16)]
    for y in range(16):
        for x in range(16):
            if (x+y*2)%7<2: t[y][x]=light
            if (x*2+y)%9<1: t[y][x]=deep
    for x,y in [(3,4),(10,2),(5,10),(13,8),(7,14)]:
        t[y][x]=foam
        if x+1<16: t[y][x+1]=foam
    return t

def make_water_winter():
    ice=(148,176,215,255); hi=(195,218,240,255); dark=(108,138,178,255); crack=(220,232,248,255)
    t = [[ice]*16 for _ in range(16)]
    for y in range(16):
        for x in range(16):
            if (x+y*3)%8<2: t[y][x]=hi
            if (x*3+y)%11<1: t[y][x]=dark
    for x,y in [(2,3),(3,3),(4,4),(9,8),(10,8),(10,9),(5,13),(6,13)]: t[y][x]=crack
    return t

# ── Compose seasonal rows into combined sheet ─────────────────────────────────

SEASON_ROWS = [
    # Spring
    [make_grass_spring(), make_dirt(), make_tilled(), make_watered(),
     make_path(), make_water_normal(), make_fence(), make_border_spring()],
    # Summer
    [make_grass_summer(), make_dirt(), make_tilled(), make_watered(),
     make_path(), make_water_normal(), make_fence(), make_border_summer()],
    # Autumn
    [make_grass_autumn(), make_dirt(), make_tilled(), make_watered(),
     make_path(), make_water_normal(), make_fence(), make_border_autumn()],
    # Winter
    [make_grass_winter(), make_dirt(), make_tilled(), make_watered(),
     make_path(), make_water_winter(), make_fence(), make_border_winter()],
]

SHEET_W = 128  # 8 tiles × 16px
SHEET_H = 64   # 4 seasons × 16px

sheet = [[(0,0,0,0)] * SHEET_W for _ in range(SHEET_H)]
for row_idx, tiles in enumerate(SEASON_ROWS):
    oy = row_idx * 16
    for ti, tile in enumerate(tiles):
        ox = ti * 16
        for y in range(16):
            for x in range(16):
                sheet[oy + y][ox + x] = tile[y][x]

OUT = "assets/tilesets/farm_tiles.png"
save_png(OUT, sheet, SHEET_W, SHEET_H)
print(f"Saved {OUT} ({SHEET_W}x{SHEET_H}, 4 seasons × 8 tiles)")
print("Row 0=Spring, Row 1=Summer, Row 2=Autumn, Row 3=Winter")
