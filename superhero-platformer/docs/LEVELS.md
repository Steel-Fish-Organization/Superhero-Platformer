# Building a stage

## The greybox test level

`levels/sandbox.tscn` — open it and press **F6**. It is a labelled scratch level
for trying ideas without touching a real stage. Every weapon is unlocked, tanks
and lives are topped up, and beating the boss there **does not** record a stage
clear or write to your save file.

Seven sections, left to right:

| # | Section | What you can check |
| --- | --- | --- |
| 1 | Movement | jump height against 1-6 tile pillars (a jump clears 5) |
| 2 | Gap width | gaps of 2-7 tiles, spikes below (a running jump clears ~7) |
| 3 | Terrain | 2-tile slide tunnel, 3-tile corridor, ladder, one-way platforms, moving platforms, spikes |
| 4 | Enemies + items | one of each enemy and every pickup |
| 5 | Low gravity | `gravity_scale = 0.4` |
| 6 | Heavy + slow | `gravity_scale 1.7`, `speed_scale 0.6`, `jump_scale 0.9` |
| 7 | Boss | the full arena sequence, re-fightable |

Extra keys, sandbox only:

| Key | Effect |
| --- | --- |
| **R** | respawn at the last checkpoint, free (no life lost, no death animation) |
| **T** | refill health, weapon energy and tanks |
| **Y** | take 4 damage — for checking i-frames and knockback |
| **U** | toggle 0.35× slow motion |

Rebuild it after editing the layout:

```
godot --headless --path . --script tools/gen_sandbox.gd
```

That script only writes `levels/sandbox.tscn`, so it is safe to re-run at any time.

## What a stage scene needs

Only four things:

```
Level              (Node2D, src/level/level.gd)   stage_id, display_name, music
├── Background     (TileMapLayer)  collision_enabled = false
├── Tiles          (TileMapLayer)  the world tileset
├── Rooms/         CameraRoom areas, one flagged is_start_room
├── Entities/      spawners, checkpoints, hazards, ladders, items
├── GameCamera     (Camera2D, src/level/game_camera.gd)
├── PlayerSpawn    (Marker2D)
└── BossArena      (optional, src/bosses/boss_arena.gd)
```

`Level` finds `PlayerSpawn` and `GameCamera` by name, spawns the hero, adds the
HUD and pause menu, and handles death and respawn. You can hit **F6** on any
stage and play it immediately — set `quick_spawn = true` to skip the beam-in
while you are iterating.

## The tile grid

Everything is on an 8×8 grid; the screen is 426×240, so a screen is 53×30 tiles.
The atlas is `assets/tilesets/tiles.png`, wired up in
`assets/tilesets/world_tileset.tres`.

| Atlas cell | Tile | Collision |
| --- | --- | --- |
| `(0..8, 0)` | ground block, 3×3 edge set | solid |
| `(9, 0)` | standalone block | solid |
| `(10..13, 0)` | spikes up / down / left / right | **none** — pair with a `Hazard` |
| `(14..15, 0)` | ladder, ladder top | **none** — pair with a `Ladder` |
| `(0..2, 2)` | one-way platform, left / mid / right | top-only |
| `(3, 2)` | ice | solid |
| `(4..5, 2)` | conveyor left / right | solid |
| `(6, 2)` | breakable block | solid |
| `(7, 2)` | water | none |
| `(0..9, 3)` | background bricks and pipes | none |

Spikes and ladders are visual tiles on purpose: the kill volume and the climb
volume are scenes (`Hazard`, `Ladder`), which keeps them reliable and lets you
size them independently of the art.

## Rooms and the camera

Cover the playable space with `CameraRoom` areas that do not overlap. One must
have `is_start_room = true`. Crossing a boundary triggers the screen scroll.

Per-room overrides: `music`, `gravity_scale`, `speed_scale`, `jump_scale` — that
is how you get an underwater or low-gravity section without new code.

Falling more than `Level.pit_margin` below the current room kills the player, so
a bottomless pit needs no extra node.

## Placing enemies

Use a `Spawner` rather than the enemy directly. It spawns when the spot comes
near the screen and frees it when it leaves — the NES behaviour, and it keeps big
stages cheap. `respawns = false` pins a one-time enemy.

## Boss rooms

Add a `BossArena` with children named `Trigger` (Area2D), `Room` (CameraRoom) and
optionally `Door` (a Node2D that slides down into place). Put the boss under it;
it is found automatically, or point `boss_path` at it. When the boss dies the
arena calls `Level.complete_stage()`, which awards the weapon from
`WeaponLibrary.STAGE_REWARDS` and returns to the stage select.

## Tiles with no behaviour yet

The atlas includes **ice** `(3,2)`, **conveyor** `(4-5,2)` and **breakable**
`(6,2)` tiles. They are drawn and they are solid, but nothing special happens
when you touch them — there is no low-friction, carry or shatter code yet. They
are there so the art exists when you want to wire the behaviour up. The hooks are
already present: `Player.speed_scale` and `Player.external_velocity` are what ice
and conveyors would drive.

## The generators

Both generators share the helpers in `tools/stage_builder.gd` — `ground`,
`slab`, `platform`, `spikes`, `ladder`, `room`, `spawner`, `checkpoint`, `item`,
`moving_platform`, `label` and `boss_arena`. Add a helper there and both scripts
get it.

`tools/gen_stages.gd` built the current nine stages:

```
godot --headless --path . --script tools/gen_stages.gd
```

Stage 1 is hand-designed in that script (`_build_stage_01`); stages 2-9 are
generated blockouts so the stage select, bosses and save system are exercised
end to end. They are playable but they are **not designed levels** — they are
scaffolding for you to replace.

> **This script overwrites `levels/*.tscn`.** Once you start editing a stage in
> the Godot editor, stop regenerating it, or remove it from the loop in
> `_initialize()`.

The helper functions (`_ground`, `_slab`, `_platform`, `_spikes`,
`_ladder_tiles`, `_room`, `_spawner`, `_checkpoint`, `_boss_arena`) are a
reasonable way to block out a stage in code before hand-finishing it in the
editor, if you like working that way.

## Testing a stage without playing it

```
godot --path . tools/screenshot_runner.tscn -- <scene> <out.png> [frames] [inputs] [warp]
```

- `inputs` — `action@start-end` pairs in frames, e.g. `move_right@10-90,fire@20-80`
- `warp` — `x,y` to drop the hero into a later section

Example: jump straight into stage 1's boss arena and watch the intro.

```
godot --path . tools/screenshot_runner.tscn -- \
  res://levels/stage_01.tscn res://.screenshots/boss.png 130 "" "944,192"
```
