# Superhero-Platformer

A Godot 4.5 prototype for a Mega Man / Mega Man X style action platformer.
Currently a greybox playground for trying out mechanics — three scripts, one level.

Open `superhero-platformer/project.godot` and press **F5**.

Two control layouts, both live at once:

| Action | Arrow layout | WASD layout |
| --- | --- | --- |
| move, climb ladders | Arrows | W A S D |
| jump (hold for height) | **X** | **K** |
| fire (hold to charge) | **Z** | **J** |
| slide (or ↓/S + jump) | **C** | **L** |
| respawn | **R** | **R** |

Gamepad works too: A jump, X fire, B slide.

## What's in it

```
src/player.gd    run, jump, slide, ladders, shooting, 3-tier charge   ~250 lines
src/shot.gd      projectile, tier decides speed/damage/size            ~55
src/target.gd    block to shoot at, respawns so you can keep testing   ~55
levels/greybox.tscn
assets/greybox/  flat placeholder art + the 8x8 tileset
tools/           art and level generators (you never need to open these)
```

Screen is **426×240** on an **8×8 tile grid**.

## Tuning

Every movement value is an `@export` on the Player, grouped in the inspector.
You can drag them while the game is running — open **Debug → Remote** in the
editor, pick the Player, and the changes apply instantly.

Current jump: rises **69px** (about 8.5 tiles) at full hold, **31px** if you
release straight away.

| Value | Now | Effect |
| --- | --- | --- |
| `jump_velocity` | −310 | higher number = higher jump |
| `gravity` | 720 | lower = floatier, longer hang time |
| `max_fall` | 360 | caps how fast long drops get |
| `jump_cut` | 0.45 | how much of the rise survives releasing jump |
| `run_speed` | 90 | 1.5 px/frame, matching MMX's walk |

Editing the numbers in `player.gd` works too — but if you ever tweak them in the
inspector, that saves an override into `player.tscn` which then wins over the
script.

## The greybox course

Runs left to right, one mechanic at a time:

1. flat run
2. 4-tile gap
3. jump-height ruler — pillars of 2, 4, 6, 8 and 10 tiles. It deliberately runs
   past what the jump can reach, so it stays a measuring stick while you retune.
   At the current settings you clear 8 but not 10.
4. slide tunnel, 2-tile opening — only a slide fits
5. one-way platforms — jump up through them
6. ladder up to a landing
7. shooting gallery — six targets that come back after 2 seconds

## Charge tiers

Mega Man 4+ rules: pressing fire shoots immediately **and** starts charging;
releasing after a threshold fires that tier.

| Tier | Hold | Damage | Notes |
| --- | --- | --- | --- |
| tap | — | 1 | max 3 on screen at once |
| mid | 0.5s | 3 | |
| full | 1.15s | 6 | pierces one target |

The hero flashes brighter as each tier is reached.

## Regenerating

```bash
python tools/gen_greybox.py                              # placeholder art + tileset
godot --headless --path . --script tools/gen_level.gd    # rebuilds greybox.tscn
```

The level generator **overwrites** `levels/greybox.tscn` — handy while the level
is throwaway, but stop using it once you start editing the scene in the editor.

## Not built yet

No health, HUD, menus, save system, enemies with AI, bosses, or camera rooms.
The camera is a plain `Camera2D` parented to the player with limits set in the
level. Deliberately kept small so mechanics are easy to change.

An older, much larger version of this project — save system, stage select, nine
stages, boss framework, resource-driven weapons — is on the
`reference/full-framework` branch if any of it is ever worth borrowing.
