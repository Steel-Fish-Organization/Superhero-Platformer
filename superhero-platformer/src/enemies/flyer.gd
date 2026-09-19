extends Enemy
## Airborne enemy with three selectable patterns, covering most of the flying
## foes in MM5/MM6 and the bat/wasp types in MMX. Doesn't shoot -- it's the body
## that hurts.

enum Pattern {
	SINE,      ## drifts one direction, weaving up and down
	TRACK_Y,   ## holds its x-drift but matches the player's height
	SWOOP,     ## hovers, then dives at the player and returns
}

@export var pattern := Pattern.SINE
@export var speed := 45.0
@export var amplitude := 14.0
@export var frequency := 1.6
@export var swoop_range := 110.0
@export var swoop_speed := 150.0
@export var track_strength := 40.0

var _origin := Vector2.ZERO
var _phase := 0.0
var _swooping := false
var _returning := false


func _on_spawn() -> void:
	use_gravity = false
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_origin = global_position
	_phase = randf() * TAU


func _behaviour(delta: float) -> void:
	_phase += delta * frequency * TAU
	match pattern:
		Pattern.SINE:
			velocity = Vector2(speed * facing, cos(_phase) * amplitude * frequency * TAU * 0.16)
		Pattern.TRACK_Y:
			var dy := 0.0
			if player and is_instance_valid(player):
				dy = signf(player.global_position.y - 8.0 - global_position.y) * track_strength
			velocity = Vector2(speed * facing, dy)
		Pattern.SWOOP:
			_swoop()

	if sprite:
		sprite.frame = int(_phase * 1.2) % sprite.hframes


func _swoop() -> void:
	if _swooping:
		velocity = direction_to_player() * swoop_speed
		facing = 1 if velocity.x >= 0.0 else -1
		# Overshot far enough -- head home and hover again.
		if global_position.distance_to(_origin) > swoop_range * 1.6:
			_swooping = false
			_returning = true
		return

	if _returning:
		var home := _origin - global_position
		if home.length() <= 2.0:
			_returning = false
		else:
			velocity = home.normalized() * minf(swoop_speed * 0.6, home.length() * 8.0)
			facing = 1 if velocity.x >= 0.0 else -1
			return

	velocity = Vector2(0.0, sin(_phase) * amplitude)
	if distance_to_player() < swoop_range:
		_swooping = true
		face_player()
