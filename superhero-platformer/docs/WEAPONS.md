# Weapons

The weapon system is fully data-driven. Nothing in the player, enemies or HUD
knows what the hero actually shoots — swapping the projectile is a resource
change, not a code change.

## The three pieces

| Piece | File | What it is |
| --- | --- | --- |
| `WeaponData` | `src/weapons/weapon_data.gd` | One selectable weapon: name, colours, energy, cadence, and a list of charge stages. |
| `WeaponChargeStage` | `src/weapons/weapon_charge_stage.gd` | One charge tier. Index 0 is the tap shot; later stages fire after holding fire for `charge_time` seconds. |
| `Projectile` | `src/weapons/projectile.gd` | The thing that flies. Every behaviour is an exported knob. |

Weapons live in `src/weapons/data/*.tres` and are **registered automatically at
startup** — drop a new `.tres` in that folder and it exists. `WeaponLibrary`
(`src/weapons/weapon_library.gd`) decides which one you start with and which
stage awards which weapon.

## Swapping the hero's projectile

This is the change you asked to keep easy. Pick whichever level fits:

**1. Same weapon, different-looking shot.**
Open `src/weapons/projectiles/shot_pulse.tscn`, replace the `Sprite` texture and
the `Shape`. Done — damage, charge and the 3-shot limit are untouched.

**2. Same weapon, different behaviour.**
Duplicate a projectile scene, change the exported values, and point the charge
stage at it in `src/weapons/data/pulse_bolt.tres`. The knobs:

| Export | Effect |
| --- | --- |
| `speed`, `gravity_accel`, `max_fall_speed` | straight shot vs. lobbed arc |
| `wave_amplitude`, `wave_frequency` | sine weave across the travel direction |
| `homing_turn_rate`, `homing_range` | degrees/second it steers toward enemies |
| `return_after` | seconds before it boomerangs back to the shooter |
| `spin_degrees_per_second`, `align_sprite_to_velocity` | how the sprite is oriented |
| `pierce` | enemies it passes through before dying |
| `wall_behavior` | `DESTROY`, `BOUNCE`, `PASS_THROUGH`, `STICK` |
| `hostile` | flips the collision layers so enemies can fire it |

**3. A completely different weapon entirely.**
Change `WeaponLibrary.DEFAULT_WEAPON_ID` to any weapon id in `src/weapons/data/`.
That one becomes the starting weapon; everything else follows.

The five shipped weapons are deliberately different from one another so each
mechanic has a worked example:

| Weapon | Awarded by | Demonstrates |
| --- | --- | --- |
| `pulse_bolt` | start | 3-tier charge, unmetered energy, 3-shot cap |
| `scatter_flare` | stage 1 | multi-shot spread, gravity, bouncing |
| `arc_ripper` | stage 2 | boomerang return, piercing, no charging |
| `lance_beam` | stage 3 | fast piercing beam, high energy cost, long cooldown |
| `tracer_swarm` | stage 4 | homing + weave, charged multi-shot |

## Charge tuning

Charging follows Mega Man 4-6 rules and is handled by
`src/weapons/weapon_system.gd`:

- Pressing fire *always* releases the tap shot immediately **and** starts charging.
- Releasing after passing a stage's `charge_time` fires that stage.
- Getting hit cancels the charge (`weapons.enabled` goes false during the stun).
- `max_active` caps concurrent shots per weapon — the buster's classic limit of 3.

Defaults: mid charge at 0.5s, full charge at 1.15s. Both live in
`tools/gen_weapons.gd` and in the `.tres` files.

## Regenerating the starter set

`tools/gen_weapons.gd` builds all five weapons from code:

```
godot --headless --path . --script tools/gen_weapons.gd
```

It **overwrites** `src/weapons/data/*.tres`. Once you start tuning weapons in the
inspector, edit them there and stop running this script (or update the script to
match).

## Boss weaknesses

Every `Enemy` (and therefore every `Boss`) has a `damage_multipliers` dictionary
keyed by weapon id, plus an `immune_to` list. That is the Mega Man
rock-paper-scissors system:

```gdscript
damage_multipliers = {
    &"arc_ripper": 4.0,      # weak point
    &"scatter_flare": 0.5,   # resistant
}
immune_to = [&"tracer_swarm"] # deflects entirely
```

A hit that is fully absorbed returns `false`, which makes the projectile
*deflect* rather than explode — the same visual language the NES games use.
