class_name Projectile
extends Area2D
## Base projectile. Every behaviour a Mega Man weapon needs is an exported knob
## here, so most new weapons are a new .tscn with different values plus a sprite.
##
## Walls are detected with a swept raycast rather than area overlap, so fast
## shots can never tunnel through the 8px tiles.

signal expired
signal hit_body(body: Node)

enum WallBehavior { DESTROY, BOUNCE, PASS_THROUGH, STICK }

@export_group("Motion")
@export var speed: float = 240.0
## Downward acceleration in px/s^2 (named to avoid Area2D's own `gravity`).
@export var gravity_accel: float = 0.0
@export var max_fall_speed: float = 400.0
## Sine weave perpendicular to the travel direction (pixels).
@export var wave_amplitude: float = 0.0
@export var wave_frequency: float = 0.0
## Degrees per second the shot turns toward the nearest enemy. 0 = no homing.
@export var homing_turn_rate: float = 0.0
@export var homing_range: float = 160.0
@export var spin_degrees_per_second: float = 0.0
@export var align_sprite_to_velocity: bool = false
## Seconds of straight travel before returning to the shooter (boomerang).
@export var return_after: float = 0.0

@export_group("Collision")
@export var damage: int = 1
## Enemies it can pass through before dying. 0 = dies on first hit.
@export var pierce: int = 0
@export var wall_behavior: WallBehavior = WallBehavior.DESTROY
@export var max_bounces: int = 3
@export var lifetime: float = 3.0
## Extra margin so shots die a hair inside walls instead of visibly clipping.
@export var wall_skin: float = 1.0
## Set on an enemy weapon so it targets the player instead.
@export var hostile: bool = false

@export_group("Presentation")
@export var impact_effect: PackedScene
@export var hit_sfx: StringName = &"hit"
@export var wall_sfx: StringName = &"deflect"
## Multiplied into the sprite scale by the firing stage's muzzle_scale.
@export var base_scale: float = 1.0
## Frames/second for a child node named "Sprite" with hframes > 1.
@export var sprite_fps: float = 14.0

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var stage: WeaponChargeStage
var shooter: Node2D

var _age: float = 0.0
var _hits_left: int = 0
var _bounces: int = 0
var _wave_phase: float = 0.0
var _returning: bool = false
var _dead: bool = false


func _ready() -> void:
	collision_layer = Layers.ENEMY_ATTACK if hostile else Layers.PLAYER_ATTACK
	collision_mask = Layers.PLAYER_HURTBOX if hostile else Layers.ENEMY
	monitoring = true
	monitorable = false
	_hits_left = pierce
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	add_to_group(&"projectiles")


## Fire this projectile. `stage_data` is optional -- without it the scene's own
## exported values are used, which makes projectiles testable on their own.
func launch(from: Vector2, dir: Vector2, stage_data: WeaponChargeStage = null, by: Node2D = null) -> void:
	global_position = from
	direction = dir.normalized()
	shooter = by
	stage = stage_data
	if stage_data:
		speed = stage_data.speed
		damage = stage_data.damage
		if stage_data.lifetime_override >= 0.0:
			lifetime = stage_data.lifetime_override
		scale = Vector2.ONE * base_scale * stage_data.muzzle_scale
	else:
		scale = Vector2.ONE * base_scale
	velocity = direction * speed
	rotation = 0.0
	if align_sprite_to_velocity:
		rotation = velocity.angle()
	elif direction.x < 0.0:
		scale.x *= -1.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		_expire()
		return

	_update_velocity(delta)

	var motion := velocity * delta
	if wave_amplitude > 0.0 and wave_frequency > 0.0:
		var prev := sin(_wave_phase) * wave_amplitude
		_wave_phase += wave_frequency * TAU * delta
		var curr := sin(_wave_phase) * wave_amplitude
		motion += velocity.normalized().orthogonal() * (curr - prev)

	_move(motion)

	if spin_degrees_per_second != 0.0:
		rotation += deg_to_rad(spin_degrees_per_second) * delta
	elif align_sprite_to_velocity:
		rotation = velocity.angle()

	var spr := get_node_or_null(^"Sprite") as Sprite2D
	if spr and spr.hframes > 1 and sprite_fps > 0.0:
		spr.frame = int(_age * sprite_fps) % spr.hframes


func _update_velocity(delta: float) -> void:
	if gravity_accel != 0.0:
		velocity.y = minf(velocity.y + gravity_accel * delta, max_fall_speed)

	if return_after > 0.0 and not _returning and _age >= return_after:
		_returning = true
	if _returning and is_instance_valid(shooter):
		var to_owner := (shooter.global_position - global_position).normalized()
		velocity = to_owner * speed
		if global_position.distance_to(shooter.global_position) < 8.0:
			_vanish()
		return

	if homing_turn_rate > 0.0:
		var target := _find_target()
		if target:
			var want := (target.global_position - global_position).angle()
			var have := velocity.angle()
			var turn := deg_to_rad(homing_turn_rate) * delta
			velocity = Vector2.RIGHT.rotated(rotate_toward(have, want, turn)) * velocity.length()


func _move(motion: Vector2) -> void:
	if wall_behavior == WallBehavior.PASS_THROUGH or motion == Vector2.ZERO:
		global_position += motion
		return

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + motion + motion.normalized() * wall_skin)
	query.collision_mask = Layers.WORLD
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		global_position += motion
		return

	global_position = hit.position - motion.normalized() * wall_skin
	_on_wall_hit(hit.get("normal", Vector2.UP))


func _on_wall_hit(normal: Vector2) -> void:
	match wall_behavior:
		WallBehavior.BOUNCE:
			_bounces += 1
			if _bounces > max_bounces:
				_expire()
				return
			velocity = velocity.bounce(normal)
			direction = velocity.normalized()
			AudioManager.play_sfx(wall_sfx)
		WallBehavior.STICK:
			velocity = Vector2.ZERO
			set_physics_process(false)
		_:
			AudioManager.play_sfx(wall_sfx)
			_expire()


func _on_body_entered(body: Node) -> void:
	if _dead or hostile or body == shooter:
		return
	_deal_damage(body)


func _on_area_entered(area: Area2D) -> void:
	if _dead or not hostile:
		return
	if area.has_method("apply_damage"):
		area.call("apply_damage", damage, self)
		_after_hit(area)


func _deal_damage(target: Node) -> void:
	if not target.has_method("take_damage"):
		return
	var absorbed: Variant = target.call("take_damage", damage, self)
	# A target may return false to say "no effect" (shielded / invulnerable).
	if absorbed is bool and not absorbed:
		AudioManager.play_sfx(wall_sfx)
		if wall_behavior == WallBehavior.DESTROY:
			_expire()
		return
	_after_hit(target)


func _after_hit(target: Node) -> void:
	hit_body.emit(target)
	AudioManager.play_sfx(hit_sfx)
	if _hits_left > 0:
		_hits_left -= 1
		return
	_expire()


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_d := homing_range * homing_range
	var group := &"player" if hostile else &"enemies"
	for n in get_tree().get_nodes_in_group(group):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _expire() -> void:
	if _dead:
		return
	_dead = true
	if impact_effect:
		var fx := impact_effect.instantiate()
		if fx is Node2D:
			(fx as Node2D).global_position = global_position
		get_parent().add_child(fx)
	expired.emit()
	queue_free()


func _vanish() -> void:
	if _dead:
		return
	_dead = true
	expired.emit()
	queue_free()
