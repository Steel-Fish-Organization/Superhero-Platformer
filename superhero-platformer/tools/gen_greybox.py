#!/usr/bin/env python3
"""Greybox placeholder art. Run with:  python tools/gen_greybox.py

Deliberately ugly flat shapes -- they exist so the prototype is readable, not
pretty. Replace any PNG with real art of the same size and nothing else changes.
Also writes the TileSet resource, so tile ids and collision stay in sync.
"""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILE = 8

C = {
    "clear":   (0, 0, 0, 0),
    "line":    (18, 20, 28, 255),
    "rock":    (104, 110, 124, 255),
    "rock_lt": (146, 152, 168, 255),
    "rock_dk": (68, 72, 86, 255),
    "bg":      (44, 48, 62, 255),
    "bg_lt":   (56, 61, 78, 255),
    "ladder":  (214, 176, 72, 255),
    "plat":    (176, 116, 60, 255),
    "plat_lt": (214, 152, 84, 255),
    "hero":    (72, 132, 224, 255),
    "hero_lt": (128, 184, 255, 255),
    "hero_dk": (40, 76, 152, 255),
    "visor":   (236, 244, 255, 255),
    "shot":    (120, 236, 246, 255),
    "shot_lt": (255, 255, 255, 255),
    "target":  (214, 84, 84, 255),
    "target_d":(140, 44, 48, 255),
    "enemy":   (196, 84, 176, 255),
    "enemy_lt":(232, 148, 214, 255),
    "enemy_dk":(124, 44, 112, 255),
    "bomb":    (236, 148, 64, 255),
    "bomb_lt": (255, 214, 150, 255),
    "rico":    (120, 226, 140, 255),
    "orange":  (250, 168, 62, 255),
}


class Img:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[C["clear"]] * w for _ in range(h)]

    def rect(self, x, y, w, h, col):
        for j in range(y, y + h):
            if 0 <= j < self.h:
                for i in range(x, x + w):
                    if 0 <= i < self.w:
                        self.px[j][i] = C[col] if isinstance(col, str) else col

    def outline(self, x, y, w, h, col):
        self.rect(x, y, w, 1, col)
        self.rect(x, y + h - 1, w, 1, col)
        self.rect(x, y, 1, h, col)
        self.rect(x + w - 1, y, 1, h, col)

    def disc(self, cx, cy, r, col):
        for j in range(self.h):
            for i in range(self.w):
                if (i - cx) ** 2 + (j - cy) ** 2 <= r * r:
                    self.rect(i, j, 1, 1, col)

    def save(self, rel):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        raw = bytearray()
        for row in self.px:
            raw.append(0)
            for r, g, b, a in row:
                raw += bytes((r, g, b, a))

        def chunk(tag, data):
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

        png = (b"\x89PNG\r\n\x1a\n"
               + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
               + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
               + chunk(b"IEND", b""))
        with open(path, "wb") as fh:
            fh.write(png)
        print("  ", rel)


# ---------------------------------------------------------------------------
# tileset: 6 tiles in a row -- solid, solid top, ladder, ladder top, platform, bg
# ---------------------------------------------------------------------------
SOLID_TILES = [0, 1]          # full 8x8 collision box
ONEWAY_TILES = [4]            # top-only collision
NO_COLLISION = [2, 3, 5]      # ladder + background are visual only
## Tiles flagged with the "ladder" custom data layer. src/ladders.gd reads that
## flag and builds the climbable volumes, so painting these tiles is all it
## takes to place a ladder.
LADDER_TILES = [2, 3]


def build_tiles():
    img = Img(TILE * 6, TILE)

    def cell(i):
        return i * TILE

    # 0: solid rock
    img.rect(cell(0), 0, 8, 8, "rock")
    img.rect(cell(0), 6, 8, 2, "rock_dk")
    img.rect(cell(0) + 1, 1, 2, 2, "rock_lt")

    # 1: solid rock with a lit top edge
    img.rect(cell(1), 0, 8, 8, "rock")
    img.rect(cell(1), 0, 8, 2, "rock_lt")
    img.rect(cell(1), 6, 8, 2, "rock_dk")

    # 2: ladder
    img.rect(cell(2) + 1, 0, 2, 8, "ladder")
    img.rect(cell(2) + 5, 0, 2, 8, "ladder")
    img.rect(cell(2), 3, 8, 2, "ladder")

    # 3: ladder top
    img.rect(cell(3) + 1, 0, 2, 8, "ladder")
    img.rect(cell(3) + 5, 0, 2, 8, "ladder")
    img.rect(cell(3), 0, 8, 2, "ladder")
    img.rect(cell(3), 5, 8, 2, "ladder")

    # 4: one-way platform (top half only)
    img.rect(cell(4), 0, 8, 3, "plat_lt")
    img.rect(cell(4), 3, 8, 1, "plat")

    # 5: background fill
    img.rect(cell(5), 0, 8, 8, "bg")
    img.rect(cell(5), 0, 8, 1, "bg_lt")
    img.rect(cell(5), 0, 1, 8, "bg_lt")

    img.save("assets/greybox/tiles.png")


def build_tileset_resource():
    box = "PackedVector2Array(-4, -4, 4, -4, 4, 4, -4, 4)"
    plate = "PackedVector2Array(-4, -4, 4, -4, 4, 0, -4, 0)"
    lines = [
        '[gd_resource type="TileSet" load_steps=3 format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/greybox/tiles.png" id="1_tiles"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_grey"]',
        'texture = ExtResource("1_tiles")',
        "texture_region_size = Vector2i(8, 8)",
    ]
    for i in range(6):
        lines.append("%d:0/0 = 0" % i)
        if i in SOLID_TILES:
            lines.append("%d:0/0/physics_layer_0/polygon_0/points = %s" % (i, box))
        elif i in ONEWAY_TILES:
            lines.append("%d:0/0/physics_layer_0/polygon_0/points = %s" % (i, plate))
            lines.append("%d:0/0/physics_layer_0/polygon_0/one_way = true" % i)
        if i in LADDER_TILES:
            lines.append("%d:0/0/custom_data_0 = true" % i)
    lines += [
        "",
        "[resource]",
        "tile_size = Vector2i(8, 8)",
        "physics_layer_0/collision_layer = 1",
        # Tick this box on any tile in the TileSet editor to make it climbable.
        'custom_data_layer_0/name = "ladder"',
        "custom_data_layer_0/type = 1",          # 1 = bool
        'sources/0 = SubResource("TileSetAtlasSource_grey")',
        "",
    ]
    path = os.path.join(ROOT, "assets/greybox/tileset.tres")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))
    print("   assets/greybox/tileset.tres")


# ---------------------------------------------------------------------------
# player: 24x32 cells. 0 = stand, 1 = slide. The visor shows which way he faces.
# ---------------------------------------------------------------------------
def build_player():
    img = Img(24 * 2, 32)

    # frame 0 -- standing, 14 wide x 26 tall, feet at the bottom of the cell
    x, y, w, h = 5, 6, 14, 26
    img.rect(x, y, w, h, "hero")
    img.rect(x, y, w, 3, "hero_lt")
    img.rect(x, y + h - 4, w, 4, "hero_dk")
    img.outline(x, y, w, h, "line")
    img.rect(x + 8, y + 4, 5, 4, "visor")          # faces right
    img.rect(x + 3, y + 12, w - 6, 2, "hero_dk")

    # frame 1 -- sliding, 22 wide x 14 tall, hugging the floor
    ox = 24
    x, y, w, h = ox + 1, 18, 22, 14
    img.rect(x, y, w, h, "hero")
    img.rect(x, y, w, 3, "hero_lt")
    img.rect(x, y + h - 3, w, 3, "hero_dk")
    img.outline(x, y, w, h, "line")
    img.rect(x + w - 7, y + 4, 5, 4, "visor")

    img.save("assets/greybox/player.png")


# ---------------------------------------------------------------------------
# shot: 3 frames of 16x16 -- tap, mid charge, full charge
# ---------------------------------------------------------------------------
def build_shot():
    img = Img(16 * 3, 16)
    for i, r in enumerate((2.5, 4.5, 6.5)):
        cx = i * 16 + 8
        img.disc(cx, 8, r + 1, "line")
        img.disc(cx, 8, r, "shot")
        img.disc(cx - r * 0.3, 8 - r * 0.3, max(r * 0.45, 1.0), "shot_lt")
    img.save("assets/greybox/shot.png")


# ---------------------------------------------------------------------------
# target: a 16x16 block to shoot at
# ---------------------------------------------------------------------------
def build_target():
    img = Img(16, 16)
    img.rect(0, 0, 16, 16, "target")
    img.rect(0, 12, 16, 4, "target_d")
    img.outline(0, 0, 16, 16, "line")
    img.rect(6, 6, 4, 4, "line")
    img.save("assets/greybox/target.png")


# ---------------------------------------------------------------------------
# flying enemy: 16x16, 2 frames (wings up / wings down)
# ---------------------------------------------------------------------------
def build_enemy():
    img = Img(16 * 2, 16)
    for f in range(2):
        o = f * 16
        wing = 2 if f else 0
        img.rect(o + 0, 6 + wing, 4, 2, "enemy_lt")     # wings
        img.rect(o + 12, 6 + wing, 4, 2, "enemy_lt")
        img.rect(o + 4, 4, 8, 9, "enemy")               # body
        img.rect(o + 4, 4, 8, 2, "enemy_lt")
        img.rect(o + 4, 11, 8, 2, "enemy_dk")
        img.outline(o + 4, 4, 8, 9, "line")
        img.rect(o + 6, 7, 4, 3, "shot_lt")             # eye
        img.rect(o + 7, 8, 2, 1, "line")
    img.save("assets/greybox/enemy.png")


# ---------------------------------------------------------------------------
# extra projectiles
# ---------------------------------------------------------------------------
def build_bomb():
    """8x8, 2 frames -- the fuse blinks."""
    img = Img(8 * 2, 8)
    for f in range(2):
        o = f * 8
        img.disc(o + 3.5, 4.5, 3.4, "line")
        img.disc(o + 3.5, 4.5, 2.6, "bomb")
        img.rect(o + 2, 3, 2, 1, "bomb_lt")
        img.rect(o + 4, 0, 1, 2, "line")                # fuse
        img.rect(o + 5, 0, 1, 1, "orange" if f == 0 else "shot_lt")
    img.save("assets/greybox/bomb.png")


def build_ricochet():
    """8x8, 2 frames -- a spinning diamond."""
    img = Img(8 * 2, 8)
    for f in range(2):
        o = f * 8
        if f == 0:
            for i in range(4):
                img.rect(o + 3 - i, 3 - i + 1, 2 + i * 2, 1, "rico")
                img.rect(o + 3 - i, 4 + i, 2 + i * 2, 1, "rico")
        else:
            img.rect(o + 1, 3, 6, 2, "rico")
            img.rect(o + 3, 1, 2, 6, "rico")
        img.rect(o + 3, 3, 2, 2, "shot_lt")
    img.save("assets/greybox/ricochet.png")


def build_blast():
    """24x24, 4 frames -- an expanding ring."""
    img = Img(24 * 4, 24)
    for f, r in enumerate((5, 9, 12, 11)):
        o = f * 24
        col = "orange" if f < 2 else "bomb_lt"
        img.disc(o + 12, 12, r, col)
        if f >= 1:
            img.disc(o + 12, 12, r - 3, "shot_lt")
        if f == 3:
            img.disc(o + 12, 12, r - 5, "clear")
    img.save("assets/greybox/blast.png")


def main():
    print("Generating greybox art ...")
    build_tiles()
    build_tileset_resource()
    build_player()
    build_shot()
    build_target()
    build_enemy()
    build_bomb()
    build_ricochet()
    build_blast()
    print("Done.")


if __name__ == "__main__":
    main()
