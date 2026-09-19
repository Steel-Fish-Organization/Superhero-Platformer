# Superhero-Platformer

A Godot 4.5 prototype for a Mega Man / Mega Man X style action platformer.
A greybox playground for trying out mechanics — small scripts, one level.

Open `superhero-platformer/project.godot` and press **F5**.

Two control layouts, both live at once:

| Action | Arrow layout | WASD layout |
| --- | --- | --- |
| move, climb ladders | Arrows | W A S D |
| jump (hold for height) | **X** or Space | **K** or Space |
| fire (hold to charge) | **Z** or left click | **J** or left click |
| crouch | hold **↓** | hold **S** |
| slide (or crouch + jump) | **C** | **L** |
| aim | mouse | mouse |
| next weapon | **Q** | **Q** |
| respawn | **R** | **R** |

Gamepad, twin-stick style:

| Action | Button |
| --- | --- |
| move / crouch | left stick or D-pad |
| aim | right stick |
| jump | A or **LT** |
| fire | X or **RT** |
| slide | B or **LB** |
| next weapon | RB |

The triggers and LB are there so your right thumb can stay on the aim stick.
Any left-stick tilt past the deadzone counts as a full press — Mega Man has one
walking speed.

### Aiming

Shots go straight ahead, Mega Man style, until you pick up an aiming device:

- **Mouse / touchpad** — move it and a reticle replaces the cursor; shots fly
  at it. Touching the controller hands aiming back to the pad.
- **Right stick** — push it and the reticle appears that way; let go and you're
  back to shooting straight ahead.

While aiming, the hero turns to face the reticle, so you can back away while
shooting forward. Slides still go the way you're *moving*. Turn either device
off with `mouse_aim` / `stick_aim` on the Player.

### Crouch and slide

On the ground, holding down always crouches, straight away: low hitbox, no
walking, but you can turn and shoot. Jump from a crouch **always** slides,
never jumps, and a slide ending with down still held drops straight back into
a crouch, so slides chain cleanly. A slide pressed up to `slide_buffer` (0.22s)
early — near the end of the previous one — still happens.

## What's in it

```
src/player.gd         run, jump, slide, ladders, health, firing     ~510 lines
src/enemies/enemy.gd  base for every enemy: health, contact, death  ~200
src/projectile.gd     every projectile: gravity, bounce, pierce      ~190
src/room_camera.gd    follows the player, clamped per room, scrolls  ~175
src/ladders.gd        builds climbable ladders out of tiles          ~115
src/room.gd           one room on the screen grid, editor gizmo       ~80
src/enemies/*.gd      drone, walker, hopper, turret, flyer        40-80 each
src/target.gd         block to shoot at, respawns while you test      ~55
src/ui/hud.gd         the health bar                                   ~50
src/weapon.gd         the drag-and-drop weapon resource                ~50
src/checkpoint.gd     moves your respawn point forward                 ~50
src/blast.gd          the explosion a bomb leaves behind               ~50

src/weapons/          pulse.tres, bomb.tres, ricochet.tres  <- drag these around
src/projectiles/      the scenes those weapons fire
src/fx/               enemy death explosion
levels/greybox.tscn
assets/greybox/       flat placeholder art + the 8x8 tileset
assets/sprites/       enemy and explosion art (from the reference branch)
tools/                art and level generators (you never need to open these)
```

Screen is **432×240**, which is exactly **54×30 tiles** on the 8×8 grid — so
rooms, walls and room boundaries all land on whole tiles.

## Ladders

Ladders are made of tiles. In the TileSet editor, tick the **`ladder`** custom
data flag on any tile; paint that tile anywhere and `src/ladders.gd` turns it
into a working ladder at load time. Tiles that touch vertically become one
ladder; a gap starts a new one.

Every ladder gets a **one-way ledge across its top tile**, generated for you. So:

- climbing to the top pops you up and you stand on it — even on a ladder that
  ends in mid-air with no floor around it
- holding **down** on that ledge puts you back on the ladder and you drop
  through it
- **jump** while climbing is a real jump off the ladder, at `ladder_jump_scale`
  (0.85) of a normal one, and you keep your left/right steering

Turn the ledge off per-level with `add_top_platform` on the Ladders node if your
levels always have real floor up there.

## Rooms

Levels are split into rooms on a screen grid. Add a `Room` node, set **`screens`**
(e.g. `(3,1)` for three screens wide), and drag it — it snaps to the grid and
draws its bounds in the editor.

The rule is just "which room is the player in?", so **any two rooms that touch
are connected**. Walk into a neighbour and the screen scrolls across; if there's
no room that way, nothing happens and the camera stays put. There's no adjacency
list to maintain.

A room should only be larger than one screen on one axis — that's what makes it
scroll horizontally *or* vertically but never both. The editor warns you if you
set both. Falling below a room with nothing under it counts as a pit and
respawns you.

As in Mega Man, you only scroll **up** into a room by climbing a ladder through
the ceiling — a jump that pokes above the room doesn't scroll. Turn off
`upward_needs_ladder` on the RoomCamera if a level needs jump-up transitions.

## Tuning

Every movement value is an `@export` on the Player, grouped in the inspector.
You can drag them while the game is running — open **Debug → Remote** in the
editor, pick the Player, and the changes apply instantly.

Current jump: rises **69px** (about 8.5 tiles) at full hold, **37px** if you
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

Five rooms, laid out to exercise both transition directions:

```
              col 2         col 3
  row 0    [ C  ladder ][ D  gallery ]
  row 1    [ A  start — 2 screens  ][ B ][ E  enemies ]

  A → B  walk right      (horizontal)
  B → C  climb the ladder (vertical)
  C → D  walk right      (horizontal)
  B → E  walk right      (horizontal)
```

**Room A** — flat run, 4-tile gap, jump-height ruler (pillars of 2/4/6/8/10
tiles; it deliberately runs past what the jump reaches so it stays a measuring
stick while you retune — right now you clear 8 but not 10), a 2-tile slide
tunnel, one-way platforms, and a ladder that ends in mid-air.

**Room B** — the foot of a long ladder that climbs into room C.

**Room C** — the top of that ladder, coming up through a hole in the floor.

**Room D** — shooting gallery, six targets that come back after 2 seconds.

**Room E** — one of each enemy type: two walkers (one pacing a raised block),
a hopper, a turret on a pedestal, and two flyers (weaving and swooping).

Checkpoints (small flag posts) sit at the entrances to rooms B, C and E.

## Weapons

Weapons are `.tres` files in `src/weapons/`. The Player has a **`weapons` array**
in the inspector — drag files in, reorder them, delete them. **Q** cycles between
them in game. Nothing in the code knows what a weapon does; it's all in the file.

Three to start with:

| Weapon | Behaviour |
| --- | --- |
| **Pulse Gun** | straight shot, three charge tiers |
| **Bomb** | lobbed on an arc, explodes into a damaging blast |
| **Ricochet** | bounces off walls and floors up to 6 times |

### Making a new one

Right-click in `src/weapons/` → New Resource → **Weapon**, then fill in:

- `projectile` — a scene from `src/projectiles/` (or a new one)
- `damage`, `speed`, `cooldown`, `max_active`
- `shot_count` / `spread_degrees` for a shotgun
- `launch_angle` to lob it upward
- `charged` — another Weapon file, if it should charge into something

**Charge tiers are a chain, not a list.** Each file is one tier and points at the
next through `charged`, so the pulse gun is
`pulse.tres → pulse_mid.tres → pulse_full.tres`. A weapon that doesn't charge
just leaves that slot empty. Holding fire walks as far up the chain as you held.

The projectile scenes are all the same `projectile.gd` script with different
exported values — `gravity_accel` makes it lob, `bounces` makes it ricochet,
`pierce` lets it pass through enemies, `impact` spawns something when it dies.

## Health and damage

The player has **28 HP** (Mega Man's bar), shown on the **HUD** in the top-left
corner, with i-frames, a flicker, and knockback. Touching an enemy hurts for as
long as you overlap it, once the i-frames run out. Enemy shots fly straight
through you while you're flickering.

Running out of health (or falling in a pit, or pressing R) respawns you with full
health at the last **checkpoint** you passed — or the start of the level if you
haven't reached one. Checkpoints only move you forward. Drop `src/checkpoint.tscn`
into a level with its origin on the floor; turn off `show_flag` for an invisible
one.

### Enemies

Every enemy extends `src/enemies/enemy.gd`, which handles health, the white hit
flash, contact damage, the little health pip and the death explosion. Enemies
only act while they're on screen, as in Mega Man.

| Enemy | Behaviour |
| --- | --- |
| **Drone** | hovers and bobs (or drifts), shoots at you within `sight_range` |
| **Walker** | patrols, turns at walls and ledges; can `chase` |
| **Hopper** | crouches (the tell), then leaps at you on a timer |
| **Turret** | shut and armoured — shots glance off — then opens, fires a burst, closes |
| **Flyer** | `pattern`: weave (sine), match your height, or swoop at you and return |

To add a new type, extend `Enemy` and fill in `_behaviour(delta)` — set
`velocity`, and `move_and_slide` is called for you.

## Charge tiers

Mega Man 4+ rules: pressing fire shoots immediately **and** starts charging;
releasing after a threshold fires that tier too.

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

No menus, pause, save system, lives, item drops, or bosses. Killed enemies stay
dead until you restart the game. Deliberately kept small so mechanics are easy
to change.

An older, much larger version of this project — save system, stage select, nine
stages, boss framework, resource-driven weapons — is on the
`reference/full-framework` branch if any of it is ever worth borrowing.
