extends Enemy
## Airborne enemy with three selectable patterns, covering most of the flying
## foes in MM5/MM6 and the bat/wasp types in MMX.

enum Pattern {
	SINE,      ## drifts one direction, weaving up and down
	TRACK_Y,   ## holds its x-drift but matches the player's height
	SWOOP,     ## hovers, then dives at the player and returns
}

@export var pattern: Pattern = Pattern.SINE
@export var speed: float = 45.0
@export var amplitude: float = 14.0
@export var frequency: float = 1.6
@export var swoop_range: float = 110.0
@export var swoop_speed: float = 150.0
@export var track_strength: float = 40.0

var _origin: Vector2
var _phase: float = 0.0
var _swooping: bool = false


func _on_spawn() -> void:
	use_gravity = false
	_origin = global_position
	_phase = randf() * TAU
	if player:
		facing = 1 if player.global_position.x > global_position.x else -1


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
			_swoop(delta)

	if sprite:
		sprite.frame = int(_phase * 1.2) % 4


func _swoop(_delta: float) -> void:
	if not _swooping:
		velocity = Vector2(0.0, sin(_phase) * amplitude)
		if distance_to_player() < swoop_range:
			_swooping = true
			face_player()
		return
	velocity = direction_to_player() * swoop_speed
	if global_position.distance_to(_origin) > swoop_range * 1.6:
		_swooping = false
		global_position = global_position.lerp(_origin, 0.02)
