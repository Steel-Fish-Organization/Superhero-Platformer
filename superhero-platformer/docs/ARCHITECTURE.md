# Architecture

## Layout

```
assets/          generated placeholder art, audio and the tileset
levels/          stage_01 .. stage_09
src/
  autoload/      GameState, SaveSystem, AudioManager, SceneRouter
  bosses/        Boss base class, BossArena, BULWARK (the worked example)
  core/          Layers, StageLibrary
  enemies/       Enemy base class + walker / hopper / flyer / turret
  fx/            explosions, impacts, the Mega Man death burst
  items/         pickups and the enemy drop table
  level/         Level root, room camera, checkpoints, hazards, ladders, spawners
  player/        the hero
  shaders/       palette swap for weapon-tinted armour
  ui/            title, file select, stage select, HUD, pause, game over, ending
  weapons/       WeaponData / WeaponChargeStage / Projectile / WeaponSystem
tools/           art, audio, weapon and stage generators + test harnesses
```

## Autoloads

| Singleton | Responsibility |
| --- | --- |
| `GameState` | Health, lives, tanks, weapons, stage progress. Everything the HUD and menus read. Emits signals rather than being polled. |
| `SaveSystem` | Three JSON files in `user://`. `slot_summary()` powers the file-select screen without loading a full run. |
| `AudioManager` | Name-keyed SFX and music. A missing sound is a silent no-op, so the game never breaks on absent audio. |
| `SceneRouter` | Every scene change, with a fade. Also `flash()` for boss deaths. |

A stage never talks to another stage, and the UI never talks to gameplay nodes —
both go through `GameState`. That is what lets any stage be run directly with
**F6** in the editor without the menus having set anything up.

## Physics layers

Defined once in `src/core/layers.gd`; use those constants, not raw integers.

| Bit | Layer | Used by |
| --- | --- | --- |
| 1 | `WORLD` | tilemaps, moving platforms |
| 2 | `PLAYER` | the hero's body |
| 3 | `PLAYER_HURTBOX` | the area that receives damage for the hero |
| 4 | `PLAYER_ATTACK` | player projectiles |
| 5 | `ENEMY` | enemy and boss bodies (they double as hurtboxes) |
| 6 | `ENEMY_ATTACK` | enemy projectiles |
| 7 | `PICKUP` | items |
| 8 | `HAZARD` | spikes, pits, crushers |
| 9 | `LADDER` | climbable volumes |
| 10 | `TRIGGER` | camera rooms, boss doors, checkpoints |

**Damage flows in exactly two directions**, which avoids double-counting:

- *Player hurts enemy*: the projectile masks `ENEMY` and calls `take_damage()` on
  the body it hits. Returning `false` means "no effect" and the shot deflects.
- *Enemy hurts player*: the hero's own `Hurtbox` masks `ENEMY | HAZARD` and detects
  contact itself; enemy projectiles mask `PLAYER_HURTBOX` and call `apply_damage()`.

Hazards deliberately do **not** damage the player from their own side — the
hurtbox already sees them, and handling it twice would deal double damage.

## Player

`src/player/player.gd`, tuned against Mega Man 5/6 and Mega Man X. Speeds are in
pixels/second at 60 ticks; the per-frame values from the reference games are in
comments next to each constant.

| Constant | Value | Reference |
| --- | --- | --- |
| `RUN_SPEED` | 90 | 1.5 px/frame (MM ≈ 1.36, MMX walk = 1.5) |
| `JUMP_VELOCITY` | −292 | 4.87 px/frame initial rise |
| `GRAVITY` | 900 | 0.25 px/frame² |
| `MAX_FALL` | 420 | 7 px/frame terminal velocity |
| `SLIDE_SPEED` / `SLIDE_TIME` | 150 / 0.42s | ≈ 26 frames, as in MM4-6 |
| `HURT_TIME` / `INVULN_TIME` | 0.35s / 1.2s | ≈ 21 frame stun |

Standing collision is 12×24 (three tiles tall, so it fits three-tile corridors);
sliding is 12×14, which fits a two-tile 16px gap. Standing up is blocked while
there is no headroom, exactly like the NES games.

Collision shapes are toggled with `set_deferred`, never directly: the physics
server rejects a shape change while it is flushing queries, which is exactly
where you are when a hurtbox signal cancels a slide. `_try_stand_up()` also
refuses to restore the tall shape without headroom, and the check at the top of
`_physics_process` retries until the hero is clear — so taking a hit mid-slide
under a low ceiling can never wedge him in geometry or leave the short hitbox on.

Rooms can retune the feel without touching constants: `gravity_scale`,
`speed_scale` and `jump_scale` are set per `CameraRoom` (water, low gravity),
and `external_velocity` is what conveyors and moving platforms push in.

Animation is driven by a frame table in the script rather than an
`AnimationPlayer`, so retiming is a one-line change.

## Camera and rooms

`GameCamera` is rigid — no smoothing — and hard-clamped to the current
`CameraRoom`. Crossing into a new room triggers the Mega Man screen scroll:
the player freezes, the camera slides across in 0.55s, and the hero is nudged
through the doorway. `lock_to_rect()` pins it for a boss fight.

Rooms are plain `Area2D`s with a rectangular shape. They should tile the level
without overlapping, and sizes should be multiples of 8.

## Enemies and bosses

`Enemy` handles health, the weakness table, hit flashing, contact damage, death
FX and drops; subclasses implement `_behaviour(delta)` only.

`Boss` extends it with the Mega Man fight opening: the boss drops in, everything
freezes while the health bar fills one unit at a time, then the fight starts.
Subclasses implement `_fight(delta)`. `BULWARK` (`src/bosses/bulwark.gd`) is the
worked example — three telegraphed attacks and an enrage threshold — and is meant
to be copied for the other eight.

`BossArena` wires it together: a trigger volume, the shutter door, the camera
lock, and the hand-off to `Level.complete_stage()` when the boss dies.

## Off-screen spawning

`Spawner` reproduces the NES behaviour: an enemy exists only while its spot is
near the visible screen, and scrolling away and back gives you a fresh one. Set
`respawns = false` for anything that should stay dead.
