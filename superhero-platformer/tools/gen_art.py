#!/usr/bin/env python3
"""Placeholder pixel-art generator for Superhero Platformer.

Everything the game draws is produced here so the art stays on the 8x8 grid and
can be regenerated after a palette or metric change:

    python tools/gen_art.py

Replace the generated PNGs with real art whenever you like -- keep the frame
sizes and sheet layouts listed in docs/ART.md and nothing else has to change.
Writes PNGs with zlib only, no third-party imaging library required.
"""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# --------------------------------------------------------------------------
# palette
# --------------------------------------------------------------------------
P = {
    "clear":  (0, 0, 0, 0),
    "line":   (16, 16, 32, 255),      # outline
    "suit_d": (26, 46, 122, 255),     # hero suit shadow
    "suit":   (48, 96, 216, 255),     # hero suit
    "suit_l": (110, 160, 255, 255),   # hero suit highlight
    "gold_d": (176, 120, 8, 255),
    "gold":   (248, 192, 32, 255),
    "skin":   (240, 184, 144, 255),
    "skin_d": (200, 136, 96, 255),
    "white":  (248, 248, 248, 255),
    "grey_d": (56, 56, 72, 255),
    "grey":   (104, 104, 128, 255),
    "grey_l": (168, 168, 192, 255),
    "red_d":  (152, 32, 40, 255),
    "red":    (232, 64, 64, 255),
    "green":  (80, 216, 120, 255),
    "green_d":(32, 128, 72, 255),
    "cyan":   (96, 232, 240, 255),
    "cyan_d": (32, 136, 168, 255),
    "purple": (168, 96, 232, 255),
    "orange": (248, 136, 40, 255),
    "brown":  (128, 88, 56, 255),
    "brown_d":(80, 52, 32, 255),
    "bg_d":   (32, 32, 56, 255),
    "bg":     (56, 56, 88, 255),
}


class Canvas:
    def __init__(self, w, h, fill="clear"):
        self.w = w
        self.h = h
        self.px = [[P[fill] for _ in range(w)] for _ in range(h)]

    def set(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = P[col] if isinstance(col, str) else col

    def rect(self, x, y, w, h, col):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.set(i, j, col)

    def frame(self, x, y, w, h, col):
        """Hollow rectangle."""
        for i in range(x, x + w):
            self.set(i, y, col)
            self.set(i, y + h - 1, col)
        for j in range(y, y + h):
            self.set(x, j, col)
            self.set(x + w - 1, j, col)

    def disc(self, cx, cy, r, col):
        for j in range(int(cy - r) - 1, int(cy + r) + 2):
            for i in range(int(cx - r) - 1, int(cx + r) + 2):
                if (i - cx) ** 2 + (j - cy) ** 2 <= r * r:
                    self.set(i, j, col)

    def ring(self, cx, cy, r, col, thickness=1.0):
        inner = (r - thickness) ** 2
        for j in range(int(cy - r) - 1, int(cy + r) + 2):
            for i in range(int(cx - r) - 1, int(cx + r) + 2):
                d = (i - cx) ** 2 + (j - cy) ** 2
                if inner <= d <= r * r:
                    self.set(i, j, col)

    def tri(self, x, y, w, h, col, point="up"):
        """Filled triangle inside the given box."""
        for j in range(h):
            t = (j + 0.5) / h
            if point == "up":
                span = int(round(w * t))
                x0 = x + (w - span) // 2
                self.rect(x0, y + j, max(span, 1), 1, col)
            elif point == "down":
                span = int(round(w * (1.0 - t)))
                x0 = x + (w - span) // 2
                self.rect(x0, y + j, max(span, 1), 1, col)

    def blit(self, other, ox, oy):
        for j in range(other.h):
            for i in range(other.w):
                c = other.px[j][i]
                if c[3]:
                    self.set(ox + i, oy + j, c)

    def save(self, relpath):
        path = os.path.join(ROOT, relpath)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        raw = bytearray()
        for row in self.px:
            raw.append(0)
            for r, g, b, a in row:
                raw += bytes((r, g, b, a))

        def chunk(tag, data):
            out = struct.pack(">I", len(data)) + tag + data
            return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as fh:
            fh.write(png)
        print("  wrote", relpath, f"({self.w}x{self.h})")


# --------------------------------------------------------------------------
# hero -- 24x32 frames, 8 columns x 6 rows
# --------------------------------------------------------------------------
FRAME_W, FRAME_H = 24, 32


def hero(c, ox, oy, *, body_dy=0, legs="stand", arm="idle", head_dy=0, facing=1,
         slide=False, hurt=False, climb=None):
    """Draw one hero pose into `c` at the frame origin (ox, oy)."""
    def R(x, y, w, h, col):
        c.rect(ox + x, oy + y, w, h, col)

    if slide:
        # low, stretched-forward pose
        R(3, 22, 18, 2, "line")
        R(4, 24, 17, 6, "suit")
        R(4, 24, 17, 2, "suit_l")
        R(4, 29, 17, 2, "suit_d")
        R(14, 20, 8, 7, "suit_d")            # helmet, thrust forward
        R(15, 21, 7, 5, "suit")
        R(16, 22, 5, 2, "cyan")              # visor
        R(2, 26, 4, 4, "gold")               # boot
        R(0, 25, 3, 6, "grey_l")             # dust streak
        c.frame(ox + 3, oy + 21, 19, 11, "line")
        return

    ty = 13 + body_dy   # torso top
    hy = 3 + body_dy + head_dy

    # --- head -------------------------------------------------------------
    R(7, hy, 10, 9, "line")
    R(8, hy + 1, 8, 7, "suit")
    R(8, hy + 1, 8, 2, "suit_l")
    R(9, hy + 6, 6, 2, "skin")               # jaw
    R(9, hy + 3, 6, 3, "cyan" if not hurt else "red")   # visor
    R(9, hy + 3, 6, 1, "white")              # visor glint
    R(11, hy - 1, 3, 2, "gold")              # crest
    R(6, hy + 3, 1, 3, "gold_d")             # ear pods
    R(17, hy + 3, 1, 3, "gold_d")

    # --- torso ------------------------------------------------------------
    R(7, ty, 10, 9, "line")
    R(8, ty + 1, 8, 7, "suit")
    R(8, ty + 1, 3, 7, "suit_l")
    R(13, ty + 1, 3, 7, "suit_d")
    R(10, ty + 1, 4, 3, "gold")              # chest emblem
    R(11, ty + 2, 2, 1, "white")
    R(8, ty + 7, 8, 2, "gold_d")             # belt

    # --- arms -------------------------------------------------------------
    if arm == "shoot":
        R(16, ty + 1, 3, 4, "suit_d")        # shoulder
        R(18, ty + 2, 6, 4, "line")          # weapon barrel
        R(18, ty + 3, 5, 2, "grey_l")
        R(22, ty + 3, 2, 2, "cyan")          # muzzle
        R(5, ty + 1, 3, 5, "suit_d")         # trailing arm
    elif arm == "up":
        R(16, ty - 3, 3, 8, "suit_d")
        R(5, ty + 1, 3, 6, "suit_d")
    elif arm == "tuck":
        R(16, ty + 2, 3, 4, "suit_d")
        R(5, ty + 2, 3, 4, "suit_d")
    elif arm == "climb":
        R(16, ty - 4, 3, 7, "suit_d")
        R(5, ty - 1, 3, 7, "suit_d")
    else:
        R(16, ty + 1, 3, 6, "suit_d")
        R(5, ty + 1, 3, 6, "suit_d")

    # --- legs -------------------------------------------------------------
    ly = ty + 9
    poses = {
        "stand":  ((8, 0, 4, 22 - ly + 8), (13, 0, 4, 22 - ly + 8)),
        "run_a":  ((6, 0, 5, 6), (14, 1, 5, 5)),
        "run_b":  ((8, 0, 5, 7), (13, 0, 5, 7)),
        "run_c":  ((10, 1, 5, 5), (12, 0, 5, 7)),
        "run_d":  ((7, 0, 5, 7), (14, 0, 5, 6)),
        "jump":   ((6, 0, 5, 5), (14, 2, 5, 4)),
        "fall":   ((7, 0, 5, 7), (13, 0, 5, 5)),
        "land":   ((6, 2, 6, 4), (13, 2, 6, 4)),
        "climb":  ((8, 0, 5, 6), (13, 1, 5, 5)),
    }
    (ax, ady, aw, ah), (bx, bdy, bw, bh) = poses.get(legs, poses["stand"])
    for (lx, ldy, lw, lh) in ((ax, ady, aw, ah), (bx, bdy, bw, bh)):
        R(lx, ly + ldy, lw, lh, "line")
        R(lx, ly + ldy, lw - 1, lh - 1, "suit")
        R(lx, ly + ldy + lh - 3, lw, 3, "gold")   # boot


def build_player_sheet():
    c = Canvas(FRAME_W * 8, FRAME_H * 6)

    def at(idx):
        return (idx % 8) * FRAME_W, (idx // 8) * FRAME_H

    def put(idx, **kw):
        ox, oy = at(idx)
        hero(c, ox, oy, **kw)

    # row 0: idle 0-3, run 0-3
    put(0)
    put(1, body_dy=1)
    put(2)
    put(3, head_dy=1)
    put(4, legs="run_a", body_dy=-1)
    put(5, legs="run_b")
    put(6, legs="run_c", body_dy=-1)
    put(7, legs="run_d")
    # row 1: run 4-7, jump, apex, fall, fall2
    put(8, legs="run_a", body_dy=-1)
    put(9, legs="run_b")
    put(10, legs="run_c", body_dy=-1)
    put(11, legs="run_d")
    put(12, legs="jump", arm="tuck", body_dy=-1)
    put(13, legs="jump", arm="tuck")
    put(14, legs="fall", arm="up")
    put(15, legs="fall", arm="up", body_dy=1)
    # row 2: land, slide x2, hurt x2, climb x2, climb top
    put(16, legs="land", arm="tuck", body_dy=2)
    put(17, slide=True)
    put(18, slide=True)
    put(19, hurt=True, legs="jump", arm="up", body_dy=-1)
    put(20, hurt=True, legs="fall", arm="up", body_dy=1)
    put(21, legs="climb", arm="climb")
    put(22, legs="climb", arm="climb", body_dy=1)
    put(23, legs="stand", arm="up")
    # row 3: teleport beam/land, victory, idle-shoot x2, run-shoot 0-1
    ox, oy = at(24)
    c.rect(ox + 9, oy, 6, 32, "cyan")
    c.rect(ox + 11, oy, 2, 32, "white")
    ox, oy = at(25)
    c.rect(ox + 9, oy, 6, 20, "cyan")
    c.rect(ox + 11, oy, 2, 20, "white")
    hero(c, ox, oy + 12, legs="jump", arm="tuck")
    put(26, legs="land", arm="tuck", body_dy=2)
    put(27, arm="up")
    put(28, arm="shoot")
    put(29, arm="shoot", body_dy=1)
    put(30, legs="run_a", arm="shoot", body_dy=-1)
    put(31, legs="run_b", arm="shoot")
    # row 4: run-shoot 2-7, jump-shoot, fall-shoot
    put(32, legs="run_c", arm="shoot", body_dy=-1)
    put(33, legs="run_d", arm="shoot")
    put(34, legs="run_a", arm="shoot", body_dy=-1)
    put(35, legs="run_b", arm="shoot")
    put(36, legs="run_c", arm="shoot", body_dy=-1)
    put(37, legs="run_d", arm="shoot")
    put(38, legs="jump", arm="shoot", body_dy=-1)
    put(39, legs="fall", arm="shoot")
    # row 5: climb-shoot, spares
    put(40, legs="climb", arm="shoot")
    put(41, legs="climb", arm="shoot", body_dy=1)
    c.save("assets/sprites/player.png")


# --------------------------------------------------------------------------
# projectiles
# --------------------------------------------------------------------------
def build_shots():
    # level 1 -- 8x8, 2 frames
    c = Canvas(16, 8)
    for f in range(2):
        o = f * 8
        c.disc(o + 3.5, 3.5, 3.2, "cyan_d")
        c.disc(o + 3.5, 3.5, 2.2, "cyan")
        c.disc(o + 3.0 + f * 0.5, 3.0, 1.1, "white")
    c.save("assets/sprites/shot_lv1.png")

    # level 2 -- 16x16, 2 frames
    c = Canvas(32, 16)
    for f in range(2):
        o = f * 16
        c.disc(o + 7.5, 7.5, 6.2, "cyan_d")
        c.disc(o + 7.5, 7.5, 4.6, "cyan")
        c.disc(o + 6.5, 6.5, 2.4, "white")
        for k in range(3):
            c.set(o + 1 + f, 4 + k * 3, "cyan")
    c.save("assets/sprites/shot_lv2.png")

    # level 3 (full charge) -- 32x24, 2 frames
    c = Canvas(64, 24)
    for f in range(2):
        o = f * 32
        for x in range(32):
            t = x / 31.0
            h = int(2 + 9 * (1.0 - abs(t - 0.62) * 1.9))
            if h > 0:
                c.rect(o + x, 12 - h, 1, h * 2, "cyan_d")
        c.disc(o + 20, 12, 8.0, "cyan")
        c.disc(o + 20, 12, 5.0, "white")
        c.ring(o + 20, 12, 10.0 + f, "cyan", 1.2)
    c.save("assets/sprites/shot_lv3.png")

    # enemy shot -- 8x8, 2 frames
    c = Canvas(16, 8)
    for f in range(2):
        o = f * 8
        c.disc(o + 3.5, 3.5, 3.2, "red_d")
        c.disc(o + 3.5, 3.5, 2.0, "red")
        c.set(o + 3 - f, 3, "white")
    c.save("assets/sprites/shot_enemy.png")


def build_charge_aura():
    """32x32, 4 frames: two charge tiers, two flicker phases each."""
    c = Canvas(128, 32)
    for f in range(4):
        o = f * 32
        tier = f // 2
        phase = f % 2
        col = "cyan" if tier == 0 else "white"
        r = 9 + tier * 3 + phase
        c.ring(o + 16, 16, r, col, 1.2)
        for k in range(6):
            ang = k * 1.0472 + phase * 0.5
            import math
            x = 16 + math.cos(ang) * (r + 2)
            y = 16 + math.sin(ang) * (r + 2)
            c.rect(o + int(x), int(y), 2, 2, col)
    c.save("assets/sprites/charge_aura.png")


def build_explosion():
    c = Canvas(96, 16)
    seq = [(2, "white"), (4, "cyan"), (6, "cyan_d"), (7, "white"), (6, "cyan"), (4, "cyan_d")]
    for f, (r, col) in enumerate(seq):
        o = f * 16
        if f < 3:
            c.disc(o + 8, 8, r, col)
            if f > 0:
                c.disc(o + 8, 8, r - 2, "white")
        else:
            c.ring(o + 8, 8, r, col, 2.0)
            for k in range(8):
                import math
                ang = k * 0.7854
                x = 8 + math.cos(ang) * (r + 1)
                y = 8 + math.sin(ang) * (r + 1)
                c.rect(o + int(x), int(y), 2, 2, col)
    c.save("assets/sprites/explosion.png")


# --------------------------------------------------------------------------
# enemies
# --------------------------------------------------------------------------
def build_enemies():
    # walker -- 16x16, 4 frames
    c = Canvas(64, 16)
    for f in range(4):
        o = f * 16
        bob = (0, 1, 0, 1)[f]
        c.rect(o + 2, 4 + bob, 12, 9, "line")
        c.rect(o + 3, 5 + bob, 10, 7, "red")
        c.rect(o + 3, 5 + bob, 10, 2, "red_d")
        c.rect(o + 9, 7 + bob, 4, 3, "white")          # eye
        c.rect(o + 10, 8 + bob, 2, 2, "line")
        step = (0, 2, 0, -2)[f]
        c.rect(o + 3 + step, 13, 3, 3, "grey_d")
        c.rect(o + 10 - step, 13, 3, 3, "grey_d")
    c.save("assets/sprites/enemy_walker.png")

    # flyer -- 16x16, 4 frames
    c = Canvas(64, 16)
    for f in range(4):
        o = f * 16
        wing = (0, 2, 4, 2)[f]
        c.disc(o + 8, 9, 4.4, "line")
        c.disc(o + 8, 9, 3.4, "purple")
        c.rect(o + 6, 7, 4, 2, "white")
        c.rect(o + 1, 5 + wing, 5, 2, "grey_l")        # wings
        c.rect(o + 10, 5 + wing, 5, 2, "grey_l")
    c.save("assets/sprites/enemy_flyer.png")

    # turret -- 16x16, 3 frames (closed / opening / firing)
    c = Canvas(48, 16)
    for f in range(3):
        o = f * 16
        c.rect(o + 1, 6, 14, 10, "line")
        c.rect(o + 2, 7, 12, 8, "grey")
        c.rect(o + 2, 7, 12, 2, "grey_l")
        if f >= 1:
            c.rect(o + 5, 3, 6, 5, "line")
            c.rect(o + 6, 4, 4, 3, "orange" if f == 2 else "grey_d")
        if f == 2:
            c.rect(o + 6, 0, 4, 4, "red")
    c.save("assets/sprites/enemy_turret.png")

    # hopper -- 16x16, 4 frames
    c = Canvas(64, 16)
    for f in range(4):
        o = f * 16
        squash = (0, -2, 0, 2)[f]
        h = 10 - squash
        c.rect(o + 3, 16 - h, 10, h, "line")
        c.rect(o + 4, 17 - h, 8, h - 2, "green")
        c.rect(o + 4, 17 - h, 8, 2, "green_d")
        c.rect(o + 5, 19 - h, 2, 2, "white")
        c.rect(o + 9, 19 - h, 2, 2, "white")
    c.save("assets/sprites/enemy_hopper.png")


def build_boss():
    """48x48, 6 frames: idle, idle2, telegraph, attack, jump, hurt."""
    c = Canvas(48 * 6, 48)
    for f in range(6):
        o = f * 48
        hurt = f == 5
        body = "grey_l" if hurt else "purple"
        bob = (0, 1, 0, 0, -3, 0)[f]
        # legs
        c.rect(o + 10, 36 + bob, 8, 12, "line")
        c.rect(o + 30, 36 + bob, 8, 12, "line")
        c.rect(o + 11, 37 + bob, 6, 10, "grey_d")
        c.rect(o + 31, 37 + bob, 6, 10, "grey_d")
        # torso
        c.rect(o + 8, 16 + bob, 32, 22, "line")
        c.rect(o + 9, 17 + bob, 30, 20, body)
        c.rect(o + 9, 17 + bob, 30, 4, "white" if hurt else "grey_l")
        c.rect(o + 18, 24 + bob, 12, 8, "line")
        c.rect(o + 19, 25 + bob, 10, 6, "orange" if f in (2, 3) else "red_d")   # core
        # head
        c.rect(o + 16, 4 + bob, 16, 13, "line")
        c.rect(o + 17, 5 + bob, 14, 11, body)
        c.rect(o + 19, 9 + bob, 10, 4, "red" if f in (2, 3) else "cyan")
        c.rect(o + 20, 0 + bob, 3, 5, "gold")     # horns
        c.rect(o + 25, 0 + bob, 3, 5, "gold")
        # arms
        if f == 3:
            c.rect(o + 40, 14 + bob, 8, 10, "line")
            c.rect(o + 41, 15 + bob, 7, 8, "orange")
            c.rect(o + 0, 20 + bob, 8, 10, "line")
            c.rect(o + 1, 21 + bob, 7, 8, "grey_d")
        else:
            c.rect(o + 2, 20 + bob, 7, 14, "line")
            c.rect(o + 3, 21 + bob, 5, 12, "grey_d")
            c.rect(o + 39, 20 + bob, 7, 14, "line")
            c.rect(o + 40, 21 + bob, 5, 12, "grey_d")
    c.save("assets/sprites/boss.png")


# --------------------------------------------------------------------------
# pickups / hud / ui
# --------------------------------------------------------------------------
def build_pickups():
    """8x8 frames: health_s, health_l, energy_s, energy_l, life, etank, wtank."""
    c = Canvas(8 * 7, 8)

    def capsule(o, col, dark, small):
        if small:
            c.rect(o + 2, 2, 4, 4, dark)
            c.rect(o + 3, 3, 2, 2, col)
        else:
            c.rect(o + 1, 1, 6, 6, dark)
            c.rect(o + 2, 2, 4, 4, col)
            c.rect(o + 3, 3, 1, 1, "white")

    capsule(0, "red", "red_d", True)
    capsule(8, "red", "red_d", False)
    capsule(16, "cyan", "cyan_d", True)
    capsule(24, "cyan", "cyan_d", False)
    # 1-up: tiny helmet
    o = 32
    c.rect(o + 1, 2, 6, 5, "suit_d")
    c.rect(o + 2, 3, 4, 3, "suit")
    c.rect(o + 2, 4, 4, 1, "cyan")
    c.rect(o + 3, 1, 2, 1, "gold")
    # E-tank
    o = 40
    c.rect(o + 1, 1, 6, 6, "line")
    c.rect(o + 2, 2, 4, 4, "cyan")
    c.rect(o + 3, 3, 2, 2, "white")
    # W-tank
    o = 48
    c.rect(o + 1, 1, 6, 6, "line")
    c.rect(o + 2, 2, 4, 4, "gold")
    c.rect(o + 3, 3, 2, 2, "white")
    c.save("assets/sprites/pickups.png")


def build_hud():
    """8x8 cells: empty bar, full bar, weapon bar, frame corner."""
    c = Canvas(8 * 4, 8)
    c.rect(0, 0, 8, 8, "line")
    c.rect(1, 1, 6, 6, "bg_d")
    c.rect(8, 0, 8, 8, "line")
    c.rect(9, 1, 6, 6, "white")
    c.rect(9, 1, 6, 2, "cyan")
    c.rect(16, 0, 8, 8, "line")
    c.rect(17, 1, 6, 6, "gold")
    c.rect(17, 1, 6, 2, "white")
    c.rect(24, 0, 8, 8, "line")
    c.rect(25, 1, 6, 6, "grey_l")
    c.save("assets/sprites/hud_cell.png")


STAGE_COLORS = [
    ("cyan", "cyan_d"), ("orange", "red_d"), ("green", "green_d"),
    ("purple", "suit_d"), ("red", "red_d"), ("gold", "gold_d"),
    ("grey_l", "grey_d"), ("suit_l", "suit_d"), ("white", "line"),
]


def build_portraits():
    """32x32 boss portraits for the stage select, 9 frames + locked frame."""
    c = Canvas(32 * 10, 32)
    for i, (col, dark) in enumerate(STAGE_COLORS):
        o = i * 32
        c.rect(o, 0, 32, 32, dark)
        c.rect(o + 8, 4, 16, 14, "line")
        c.rect(o + 9, 5, 14, 12, col)
        c.rect(o + 11, 9, 10, 4, "line")
        c.rect(o + 12, 10, 3, 2, "red")
        c.rect(o + 17, 10, 3, 2, "red")
        c.rect(o + 10, 18, 12, 10, "line")
        c.rect(o + 11, 19, 10, 8, col)
        c.rect(o + 14, 21, 4, 4, "gold")
        c.rect(o + 11, 1, 3, 4, "gold")
        c.rect(o + 18, 1, 3, 4, "gold")
    # locked / unknown
    o = 9 * 32
    c.rect(o, 0, 32, 32, "bg_d")
    c.rect(o + 12, 8, 8, 4, "grey_l")
    c.rect(o + 13, 12, 2, 4, "grey_l")
    c.rect(o + 17, 12, 2, 4, "grey_l")
    c.rect(o + 10, 16, 12, 10, "grey")
    c.rect(o + 15, 19, 2, 4, "bg_d")
    c.save("assets/ui/portraits.png")


# --------------------------------------------------------------------------
# tileset -- 8x8 tiles, atlas is 16 columns x 8 rows
# --------------------------------------------------------------------------
TILE = 8
ATLAS_COLS, ATLAS_ROWS = 16, 8

# tiles that get a full 8x8 collision box
SOLID = set()
# tiles that get a one-way (top only) collision box
ONE_WAY = set()


def build_tiles():
    c = Canvas(ATLAS_COLS * TILE, ATLAS_ROWS * TILE)

    def cell(cx, cy):
        return cx * TILE, cy * TILE

    def block(cx, cy, base, light, dark, top=False, left=False, right=False, bottom=False):
        ox, oy = cell(cx, cy)
        c.rect(ox, oy, 8, 8, base)
        # subtle noise so the grid reads at 426x240
        for (px, py) in ((1, 5), (5, 2), (6, 6), (2, 1)):
            c.set(ox + px, oy + py, dark)
        if top:
            c.rect(ox, oy, 8, 2, light)
        if bottom:
            c.rect(ox, oy + 6, 8, 2, dark)
        if left:
            c.rect(ox, oy, 2, 8, light if top else dark)
        if right:
            c.rect(ox + 6, oy, 2, 8, dark)
        SOLID.add((cx, cy))

    # --- row 0-1: metal ground (3x3 autotile-ish block + single) ----------
    combos = [
        (True, True, False, False), (True, False, False, False), (True, False, True, False),
        (False, True, False, False), (False, False, False, False), (False, False, True, False),
        (False, True, False, True), (False, False, False, True), (False, False, True, True),
        (True, True, True, True),
    ]
    for i, (t, l, r, b) in enumerate(combos):
        block(i, 0, "grey", "grey_l", "grey_d", top=t, left=l, right=r, bottom=b)

    # --- row 0 tail: hazards & specials ------------------------------------
    # spikes (visual only -- pair with a Hazard scene for the kill volume)
    for i, d in enumerate(("up", "down", "left", "right")):
        ox, oy = cell(10 + i, 0)
        c.rect(ox, oy, 8, 8, "bg_d")
        if d == "up":
            c.tri(ox, oy, 4, 8, "grey_l", "up")
            c.tri(ox + 4, oy, 4, 8, "grey_l", "up")
        elif d == "down":
            c.tri(ox, oy, 4, 8, "grey_l", "down")
            c.tri(ox + 4, oy, 4, 8, "grey_l", "down")
        else:
            for k in range(4):
                w = k + 1 if d == "right" else 4 - k
                x0 = ox + (0 if d == "right" else 8 - w)
                c.rect(x0, oy + k * 2, w, 2, "grey_l")
    # ladder + ladder top
    for i, top in enumerate((False, True)):
        ox, oy = cell(14 + i, 0)
        c.rect(ox + 1, oy, 2, 8, "gold_d")
        c.rect(ox + 5, oy, 2, 8, "gold_d")
        c.rect(ox, oy + 2, 8, 2, "gold")
        if top:
            c.rect(ox, oy, 8, 2, "gold")

    # --- row 2: one-way platforms ------------------------------------------
    for i in range(3):
        ox, oy = cell(i, 2)
        c.rect(ox, oy, 8, 4, "brown")
        c.rect(ox, oy, 8, 2, "gold_d")
        c.rect(ox, oy + 3, 8, 1, "brown_d")
        if i == 0:
            c.rect(ox, oy, 1, 4, "gold")
        if i == 2:
            c.rect(ox + 7, oy, 1, 4, "brown_d")
        ONE_WAY.add((i, 2))

    # ice, conveyor L/R, breakable, water
    block(3, 2, "cyan_d", "cyan", "suit_d", top=True)
    for i, d in enumerate((-1, 1)):
        ox, oy = cell(4 + i, 2)
        c.rect(ox, oy, 8, 8, "grey_d")
        c.rect(ox, oy, 8, 3, "grey")
        for k in range(0, 8, 4):
            c.rect(ox + k, oy, 2, 3, "gold")
        SOLID.add((4 + i, 2))
    block(6, 2, "brown", "gold_d", "brown_d", top=True, left=True, right=True, bottom=True)
    ox, oy = cell(7, 2)
    c.rect(ox, oy, 8, 8, (48, 96, 200, 140))
    c.rect(ox, oy, 8, 2, (110, 170, 255, 190))

    # --- row 3: background bricks (no collision) ---------------------------
    for i in range(6):
        ox, oy = cell(i, 3)
        c.rect(ox, oy, 8, 8, "bg_d")
        c.rect(ox, oy, 8, 4, "bg")
        c.rect(ox, oy + 3, 8, 1, "bg_d")
        if i % 2 == 0:
            c.rect(ox + 3, oy, 1, 4, "bg_d")
            c.rect(ox, oy + 4, 8, 4, "bg")
            c.rect(ox + 7, oy + 4, 1, 4, "bg_d")
        else:
            c.rect(ox, oy + 4, 8, 3, "bg")
    # pipes / girders backdrop
    for i in range(6, 10):
        ox, oy = cell(i, 3)
        c.rect(ox, oy, 8, 8, "bg_d")
        c.rect(ox + 2, oy, 4, 8, "bg")
        c.rect(ox + 2, oy, 1, 8, "grey_d")

    c.save("assets/tilesets/tiles.png")
    return c


def _used_cells(canvas):
    """Every atlas cell that actually has art -- all of them must be registered
    as tiles, or set_cell() on a visual-only tile silently does nothing."""
    used = set()
    for cy in range(ATLAS_ROWS):
        for cx in range(ATLAS_COLS):
            for j in range(cy * TILE, (cy + 1) * TILE):
                for i in range(cx * TILE, (cx + 1) * TILE):
                    if canvas.px[j][i][3]:
                        used.add((cx, cy))
                        break
                if (cx, cy) in used:
                    break
    return used


def build_tileset_resource(canvas):
    """Emit the TileSet .tres so tile ids and collision stay in sync with the art."""
    used = _used_cells(canvas)
    lines = [
        '[gd_resource type="TileSet" load_steps=3 format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/tilesets/tiles.png" id="1_tiles"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_main"]',
        'texture = ExtResource("1_tiles")',
        "texture_region_size = Vector2i(8, 8)",
    ]
    box = "PackedVector2Array(-4, -4, 4, -4, 4, 4, -4, 4)"
    plate = "PackedVector2Array(-4, -4, 4, -4, 4, 0, -4, 0)"
    for cy in range(ATLAS_ROWS):
        for cx in range(ATLAS_COLS):
            key = (cx, cy)
            if key not in used:
                continue
            solid = key in SOLID
            oneway = key in ONE_WAY
            lines.append(f"{cx}:{cy}/0 = 0")
            if solid or oneway:
                lines.append(
                    f"{cx}:{cy}/0/physics_layer_0/polygon_0/points = {box if solid else plate}")
            if oneway:
                lines.append(f"{cx}:{cy}/0/physics_layer_0/polygon_0/one_way = true")
    lines += [
        "",
        "[resource]",
        "tile_size = Vector2i(8, 8)",
        "physics_layer_0/collision_layer = 1",
        'sources/0 = SubResource("TileSetAtlasSource_main")',
        "",
    ]
    path = os.path.join(ROOT, "assets/tilesets/world_tileset.tres")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))
    print("  wrote assets/tilesets/world_tileset.tres",
          f"({len(used)} tiles: {len(SOLID)} solid, {len(ONE_WAY)} one-way)")


def build_misc():
    # 8x8 white pixel for tinting bars, particles, fades
    c = Canvas(8, 8, "white")
    c.save("assets/sprites/px.png")

    # 64x64 parallax star/city backdrop tile
    c = Canvas(64, 64, "bg_d")
    for (x, y, w, h) in ((2, 30, 12, 34), (18, 22, 10, 42), (32, 36, 14, 28), (50, 26, 11, 38)):
        c.rect(x, y, w, h, "bg")
        for wy in range(y + 3, y + h - 2, 6):
            for wx in range(x + 2, x + w - 2, 4):
                c.set(wx, wy, "gold" if (wx + wy) % 3 else "grey_d")
    for (x, y) in ((6, 6), (22, 12), (40, 4), (56, 14), (14, 18), (48, 16)):
        c.set(x, y, "white")
    c.save("assets/sprites/bg_city.png")


def main():
    print("Generating placeholder art ...")
    build_player_sheet()
    build_shots()
    build_charge_aura()
    build_explosion()
    build_enemies()
    build_boss()
    build_pickups()
    build_hud()
    build_portraits()
    tiles_canvas = build_tiles()
    build_tileset_resource(tiles_canvas)
    build_misc()
    print("Done.")


if __name__ == "__main__":
    main()
