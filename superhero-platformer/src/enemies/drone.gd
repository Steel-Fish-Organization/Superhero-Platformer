extends Enemy
## Flying gunner. Hovers on the spot (or drifts), bobs up and down, and shoots
## at the player when they're close enough.

@export_group("Movement")
@export var bob_height := 8.0
@export var bob_speed := 2.0
## Left/right drift. 0 hovers in place; it turns around at walls.
@export var drift_speed := 0.0

@export_group("Shooting")
@export var projectile: PackedScene
@export var fire_interval := 1.6
@export var shot_speed := 140.0
## Won't shoot unless the player is at least this close.
@export var sight_range := 220.0
## Aim at the player rather than straight ahead.
@export var aim_at_player := true

var _origin := Vector2.ZERO
var _phase := 0.0
var _fire_timer := 0.0


func _on_spawn() -> void:
	use_gravity = false
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_origin = global_position
	_phase = randf() * TAU
	_fire_timer = fire_interval * randf_range(0.3, 1.0)


func _behaviour(delta: float) -> void:
	_phase += delta * bob_speed
	_fire_timer -= delta

	if drift_speed != 0.0 and is_on_wall():
		facing = -facing
	if aim_at_player:
		face_player()

	velocity.x = drift_speed * facing
	# Bob around the height it started at.
	var want_y := _origin.y + sin(_phase) * bob_height
	velocity.y = (want_y - global_position.y) * 6.0

	if _fire_timer <= 0.0 and _in_range():
		_fire_timer = fire_interval
		var dir := direction_to_player() if aim_at_player else Vector2(facing, 0.0)
		shoot(projectile, dir, Vector2.ZERO, shot_speed)

	if sprite:
		sprite.frame = int(_phase * 2.0) % 2


func _in_range() -> bool:
	return sight_range <= 0.0 or distance_to_player() <= sight_range
