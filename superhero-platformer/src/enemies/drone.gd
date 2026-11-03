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
## Frame of the attack animation the shot leaves on.
@export var fire_frame := 3

var _origin := Vector2.ZERO
var _phase := 0.0
var _fire_timer := 0.0
var _attacking := false
var _shot_pending := false

## Where shots leave from -- the stinger. Mirrors with the sprite.
@onready var _proj_source: Node2D = get_node_or_null(^"ProjSource")


func _on_spawn() -> void:
	use_gravity = false
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_origin = global_position
	_phase = randf() * TAU
	_fire_timer = fire_interval * randf_range(0.3, 1.0)


func _on_leave_screen() -> void:
	_attacking = false
	_shot_pending = false
	_fire_timer = fire_interval * randf_range(0.3, 1.0)
	play_anim(&"idle")


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

	var in_range := _in_range()
	if _fire_timer <= 0.0 and in_range and not _attacking:
		_fire_timer = fire_interval * alert_scale()
		if has_anim(&"attack"):
			# Wind up; the shot leaves on fire_frame. Restarted explicitly: when
			# the alert level makes attacks back-to-back, the last one is still
			# sitting finished on its final frame.
			_attacking = true
			_shot_pending = true
			play_anim(&"attack", 1.0, true)
		else:
			_fire()

	if _attacking:
		play_anim(&"attack")
		if _shot_pending and animated_sprite.animation == &"attack" and animated_sprite.frame >= fire_frame:
			_shot_pending = false
			_fire()
	else:
		play_anim(&"aggro" if in_range else &"idle")


func _fire() -> void:
	var offset := flipped_offset(_proj_source)
	var dir := direction_to_player(global_position + offset) if aim_at_player else Vector2(facing, 0.0)
	shoot(projectile, dir, offset, shot_speed)


func _in_range() -> bool:
	return sight_range <= 0.0 or distance_to_player() <= sight_range

## SIGNALS
func _on_animation_finished(anim: StringName) -> void:
	if anim == &"attack":
		_attacking = false
		# Never got to the shot frame (fire_frame past the end) -- fire anyway.
		if _shot_pending:
			_shot_pending = false
			_fire()


func _on_animated_sprite_frame_changed() -> void:
	pass # Replace with function body.


func _on_animated_sprite_sprite_frames_changed() -> void:
	pass # Replace with function body.
