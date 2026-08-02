# Superhero-Platformer

A Godot 4.5 prototype for a Mega Man / Mega Man X style action platformer.
Currently a greybox playground for trying out mechanics — three scripts, one level.

Open `superhero-platformer/project.godot` and press **F5**.

| Key | Action |
| --- | --- |
| Arrows | move, climb ladders |
| **X** | jump (hold for a higher jump) |
| **Z** | fire — hold to charge, release to fire the charged shot |
| **C** | slide (or ↓ + jump) |
| **R** | respawn |

## What's in it

```
src/player.gd    run, jump, slide, ladders, shooting, 3-tier charge   ~250 lines
src/shot.gd      projectile, tier decides speed/damage/size            ~55
src/target.gd    block to shoot at, respawns so you can keep testing   ~55
levels/greybox.tscn
assets/greybox/  flat placeholder art + the 8x8 tileset
tools/           art and level generators (you never need to open these)
```

Screen is **426×240** on an **8×8 tile grid**. Every tuning value is a constant
at the top of `player.gd`, with the original Mega Man per-frame numbers noted in
the comments.

## The greybox course

Runs left to right, one mechanic at a time:

1. flat run
2. 4-tile gap
3. jump-height pillars — 2, 3 and 5 tiles (a jump clears 5)
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
