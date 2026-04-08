#!/usr/bin/env python3
"""
Generate player pixel-art sprites for The Merry Fields.
Output: assets/sprites/characters/player_*.png (16x24 each)
Run from repo root: python tools/generate_sprites.py
"""

import struct, zlib, os

# ── PNG writer (no dependencies) ───────────────────────────────────────────

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
    print(f"  {path}")

# ── Palette ────────────────────────────────────────────────────────────────

_ = (  0,  0,  0,  0)  # transparent
H = (101, 67, 33,255)  # hair
h = (140, 95, 50,255)  # hair highlight
S = (255,213,170,255)  # skin
E = ( 50, 30, 15,255)  # eye
M = (190, 85, 65,255)  # mouth
K = (255,170,145,255)  # blush
C = ( 90,165,255,255)  # shirt
D = ( 55,110,200,255)  # shirt shadow
P = ( 75,105,160,255)  # pants
Q = ( 45, 65,110,255)  # pants shadow
B = ( 90, 58, 35,255)  # boot
Z = ( 55, 32, 15,255)  # boot shadow

W, HT = 16, 24

# ── Character parts ────────────────────────────────────────────────────────

HEAD_DOWN = [
    [_,_,_,_,H,H,H,H,H,H,H,H,_,_,_,_],
    [_,_,_,H,H,h,H,H,H,H,h,H,H,_,_,_],
    [_,_,_,H,S,S,S,S,S,S,S,S,H,_,_,_],
    [_,_,_,H,S,S,S,S,S,S,S,S,H,_,_,_],
    [_,_,_,H,S,E,S,S,S,S,E,S,H,_,_,_],
    [_,_,_,H,S,S,S,S,S,S,S,S,H,_,_,_],
    [_,_,_,H,S,K,S,M,M,S,K,S,H,_,_,_],
    [_,_,_,H,H,S,S,S,S,S,S,H,H,_,_,_],
    [_,_,_,_,H,H,H,H,H,H,H,H,_,_,_,_],
]

HEAD_UP = [
    [_,_,_,_,H,H,H,H,H,H,H,H,_,_,_,_],
    [_,_,_,H,H,H,H,H,H,H,H,H,H,_,_,_],
    [_,_,_,H,H,H,H,H,H,H,H,H,H,_,_,_],
    [_,_,_,H,H,H,H,H,H,H,H,H,H,_,_,_],
    [_,_,_,H,H,H,H,H,H,H,H,H,H,_,_,_],
    [_,_,_,H,S,S,S,S,S,S,S,S,H,_,_,_],
    [_,_,_,H,S,S,S,S,S,S,S,S,H,_,_,_],
    [_,_,_,H,H,S,S,S,S,S,S,H,H,_,_,_],
    [_,_,_,_,H,H,H,H,H,H,H,H,_,_,_,_],
]

HEAD_RIGHT = [
    [_,_,_,_,_,H,H,H,H,H,H,_,_,_,_,_],
    [_,_,_,_,H,H,h,H,H,H,H,H,_,_,_,_],
    [_,_,_,_,H,S,S,S,S,S,S,H,_,_,_,_],
    [_,_,_,_,H,S,S,S,S,S,S,H,_,_,_,_],
    [_,_,_,_,H,S,S,E,S,S,S,H,S,_,_,_],
    [_,_,_,_,H,S,S,S,S,S,S,H,_,_,_,_],
    [_,_,_,_,H,S,K,M,M,S,S,H,_,_,_,_],
    [_,_,_,_,H,H,S,S,S,S,H,H,_,_,_,_],
    [_,_,_,_,_,H,H,H,H,H,H,_,_,_,_,_],
]

def mirror(frame):
    return [row[::-1] for row in frame]

HEAD_LEFT = mirror(HEAD_RIGHT)

BODY_DOWN = [
    [_,_,_,_,C,C,C,C,C,C,C,C,_,_,_,_],
    [_,_,_,C,C,C,C,C,C,C,C,C,C,_,_,_],
    [_,_,S,S,D,C,C,C,C,C,C,D,S,S,_,_],
    [_,_,S,S,D,C,C,C,C,C,C,D,S,S,_,_],
    [_,_,_,C,C,C,C,C,C,C,C,C,C,_,_,_],
    [_,_,_,_,C,C,C,C,C,C,C,C,_,_,_,_],
]

BODY_UP = [
    [_,_,_,_,C,C,C,C,C,C,C,C,_,_,_,_],
    [_,_,_,C,C,C,C,C,C,C,C,C,C,_,_,_],
    [_,_,S,S,D,C,C,C,C,C,C,D,S,S,_,_],
    [_,_,S,S,D,C,C,C,C,C,C,D,S,S,_,_],
    [_,_,_,C,C,C,C,C,C,C,C,C,C,_,_,_],
    [_,_,_,_,C,C,C,C,C,C,C,C,_,_,_,_],
]

BODY_RIGHT = [
    [_,_,_,_,_,C,C,C,C,C,C,C,_,_,_,_],
    [_,_,_,_,C,C,C,C,C,C,C,C,_,_,_,_],
    [_,_,_,S,D,C,C,C,C,C,C,C,_,_,_,_],
    [_,_,_,S,D,C,C,C,C,C,C,C,_,_,_,_],
    [_,_,_,_,C,C,C,C,C,C,C,C,_,_,_,_],
    [_,_,_,_,_,C,C,C,C,C,C,C,_,_,_,_],
]

BODY_LEFT = mirror(BODY_RIGHT)

# ── Legs (6 rows, 4 walk frames) ───────────────────────────────────────────

def legs_down(f):
    """f = 0..3 walk frame"""
    if f == 0:  # neutral
        return [
            [_,_,_,_,P,P,P,P,P,P,P,P,_,_,_,_],
            [_,_,_,_,P,P,_,_,_,_,P,P,_,_,_,_],
            [_,_,_,_,P,P,_,_,_,_,P,P,_,_,_,_],
            [_,_,_,_,B,B,_,_,_,_,B,B,_,_,_,_],
            [_,_,_,_,B,B,_,_,_,_,B,B,_,_,_,_],
            [_,_,_,B,B,B,_,_,_,_,B,B,B,_,_,_],
        ]
    elif f == 1:  # left leg forward
        return [
            [_,_,_,_,P,P,P,P,P,P,P,P,_,_,_,_],
            [_,_,_,P,P,P,_,_,_,_,_,P,_,_,_,_],
            [_,_,P,P,_,_,_,_,_,_,_,P,_,_,_,_],
            [_,_,B,B,_,_,_,_,_,_,_,B,_,_,_,_],
            [_,B,B,_,_,_,_,_,_,_,_,_,B,_,_,_],
            [_,B,B,B,_,_,_,_,_,_,_,_,B,B,_,_],
        ]
    elif f == 2:  # mid-stride (slight bob)
        return [
            [_,_,_,_,P,P,P,P,P,P,P,P,_,_,_,_],
            [_,_,_,P,P,_,_,_,_,_,P,P,P,_,_,_],
            [_,_,_,P,P,_,_,_,_,_,_,P,P,_,_,_],
            [_,_,_,B,B,_,_,_,_,_,_,B,B,_,_,_],
            [_,_,_,B,B,_,_,_,_,_,_,B,B,_,_,_],
            [_,_,B,B,B,_,_,_,_,_,B,B,B,_,_,_],
        ]
    else:  # f == 3: right leg forward
        return [
            [_,_,_,_,P,P,P,P,P,P,P,P,_,_,_,_],
            [_,_,_,_,P,_,_,_,_,_,P,P,P,_,_,_],
            [_,_,_,_,P,_,_,_,_,_,_,_,P,P,_,_],
            [_,_,_,_,B,_,_,_,_,_,_,_,B,B,_,_],
            [_,_,_,_,_,B,_,_,_,_,_,_,B,B,_,_],
            [_,_,_,B,B,_,_,_,_,_,_,B,B,B,_,_],
        ]

def legs_up(f):
    """Back view legs"""
    if f == 0:
        return [
            [_,_,_,_,Q,P,P,P,P,P,P,Q,_,_,_,_],
            [_,_,_,_,P,P,_,_,_,_,P,P,_,_,_,_],
            [_,_,_,_,P,P,_,_,_,_,P,P,_,_,_,_],
            [_,_,_,_,B,B,_,_,_,_,B,B,_,_,_,_],
            [_,_,_,_,B,B,_,_,_,_,B,B,_,_,_,_],
            [_,_,_,B,B,B,_,_,_,_,B,B,B,_,_,_],
        ]
    elif f == 1:
        return [
            [_,_,_,_,Q,P,P,P,P,P,P,Q,_,_,_,_],
            [_,_,_,P,P,P,_,_,_,_,_,P,_,_,_,_],
            [_,_,P,P,_,_,_,_,_,_,_,P,_,_,_,_],
            [_,_,Z,B,_,_,_,_,_,_,_,B,_,_,_,_],
            [_,Z,B,_,_,_,_,_,_,_,_,_,B,_,_,_],
            [_,Z,B,B,_,_,_,_,_,_,_,_,B,B,_,_],
        ]
    elif f == 2:
        return legs_up(0)
    else:
        return [
            [_,_,_,_,Q,P,P,P,P,P,P,Q,_,_,_,_],
            [_,_,_,_,P,_,_,_,_,_,P,P,P,_,_,_],
            [_,_,_,_,P,_,_,_,_,_,_,_,P,P,_,_],
            [_,_,_,_,B,_,_,_,_,_,_,_,B,Z,_,_],
            [_,_,_,_,_,B,_,_,_,_,_,_,B,Z,_,_],
            [_,_,_,B,B,_,_,_,_,_,_,B,B,Z,_,_],
        ]

def legs_right(f):
    """Side view legs"""
    if f == 0:
        return [
            [_,_,_,_,_,P,P,P,P,P,_,_,_,_,_,_],
            [_,_,_,_,_,P,P,_,P,P,_,_,_,_,_,_],
            [_,_,_,_,_,P,P,_,P,P,_,_,_,_,_,_],
            [_,_,_,_,_,B,B,_,B,B,_,_,_,_,_,_],
            [_,_,_,_,_,B,B,_,B,B,_,_,_,_,_,_],
            [_,_,_,_,B,B,B,_,B,B,B,_,_,_,_,_],
        ]
    elif f == 1:  # back leg up
        return [
            [_,_,_,_,_,P,P,P,P,_,_,_,_,_,_,_],
            [_,_,_,_,_,P,P,_,P,P,_,_,_,_,_,_],
            [_,_,_,_,P,P,_,_,_,P,_,_,_,_,_,_],
            [_,_,_,_,B,B,_,_,_,B,_,_,_,_,_,_],
            [_,_,_,_,B,B,_,_,B,B,_,_,_,_,_,_],
            [_,_,_,B,B,B,_,B,B,B,_,_,_,_,_,_],
        ]
    elif f == 2:
        return legs_right(0)
    else:  # front leg up
        return [
            [_,_,_,_,_,P,P,P,P,_,_,_,_,_,_,_],
            [_,_,_,_,_,P,P,P,_,P,_,_,_,_,_,_],
            [_,_,_,_,_,P,_,_,_,P,P,_,_,_,_,_],
            [_,_,_,_,_,B,_,_,_,B,B,_,_,_,_,_],
            [_,_,_,_,B,B,_,_,B,B,_,_,_,_,_,_],
            [_,_,_,B,B,B,_,B,B,B,_,_,_,_,_,_],
        ]

def legs_left(f):
    return mirror(legs_right(f))

# ── Compose full frame ─────────────────────────────────────────────────────

def make_frame(head, body, legs):
    frame = head + body + legs
    while len(frame) < HT:
        frame.append([_] * W)
    return frame[:HT]

# ── Generate all frames ────────────────────────────────────────────────────

OUT = "assets/sprites/characters"

def save(name, head, body, legs_fn):
    # idle (frame 0)
    save_png(f"{OUT}/idle_{name}_0.png", make_frame(head, body, legs_fn(0)), W, HT)
    # walk (frames 0-3)
    for i in range(4):
        save_png(f"{OUT}/walk_{name}_{i}.png", make_frame(head, body, legs_fn(i)), W, HT)

print("Generating sprites...")
save("down",  HEAD_DOWN,  BODY_DOWN,  legs_down)
save("up",    HEAD_UP,    BODY_UP,    legs_up)
save("right", HEAD_RIGHT, BODY_RIGHT, legs_right)
save("left",  HEAD_LEFT,  BODY_LEFT,  legs_left)
print("Done!")
