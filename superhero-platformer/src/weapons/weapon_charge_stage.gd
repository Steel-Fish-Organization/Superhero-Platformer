class_name WeaponChargeStage
extends Resource
## One charge tier of a weapon. Stage 0 is the uncharged tap shot; each extra
## stage fires after `charge_time` seconds of holding the fire button.
##
## Swapping what a weapon *shoots* means pointing `projectile_scene` at a
## different scene -- no code change anywhere else.

@export_group("Projectile")
## Scene instanced when this stage fires. Must extend Projectile (or expose
## the same `launch()` signature).
@export var projectile_scene: PackedScene
## How many copies to fire at once (spread guns, shotguns).
@export_range(1, 12) var shot_count: int = 1
## Total arc in degrees across all shots when shot_count > 1.
@export_range(0.0, 180.0, 1.0) var spread_degrees: float = 0.0
## Extra per-shot offset perpendicular to the aim direction, in pixels.
@export var lateral_offset: float = 0.0

@export_group("Damage & Motion")
@export_range(1, 32) var damage: int = 1
@export var speed: float = 240.0
## Optional per-stage overrides; leave at -1 to use the projectile scene's own value.
@export var lifetime_override: float = -1.0
@export var knockback: float = 0.0
@export var hit_stop: float = 0.0

@export_group("Cost & Cadence")
## Seconds of holding fire before this stage becomes available. Stage 0 = 0.
@export var charge_time: float = 0.0
## Weapon energy spent per shot. -1 falls back to WeaponData.energy_cost.
@export var energy_cost: float = -1.0
## Concurrent projectiles allowed from this weapon. Mega Man's buster is 3.
@export_range(1, 32) var max_active: int = 3
## Extra cooldown added after firing this stage.
@export var extra_cooldown: float = 0.0
## Seconds the player is locked into the shoot pose (0 = just the pose blend).
@export var recoil_time: float = 0.0

@export_group("Presentation")
@export var muzzle_scale: float = 1.0
@export var shoot_sfx: StringName = &"shoot"
@export var screen_shake: float = 0.0
