extends Enemy
## Crouch-and-leap enemy, like the frog/spring types in MM5-6. Hops toward the
## player on a timer; the squash frames telegraph the jump.

@export var hop_interval: float = 1.3
@export var hop_speed_x: float = 70.0
@export var hop_speed_y: float = -230.0
## Only hops when the player is within this range. 0 = always hop.
@export var trigger_range: float = 0.0
@export var telegraph_time: float = 0.25

var _timer: float = 0.0
var _charging: bool = false


func _on_spawn() -> void:
	_timer = hop_interval * randf_range(0.4, 1.0)


func _behaviour(delta: float) -> void:
	if not is_on_floor():
		_animate_air()
		return

	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	_timer -= delta

	if _charging:
		if _timer <= 0.0:
			_leap()
		elif sprite:
			sprite.frame = 1
		return

	if _timer <= 0.0 and _in_range():
		_charging = true
		_timer = telegraph_time
	elif sprite:
		sprite.frame = 0


func _in_range() -> bool:
	return trigger_range <= 0.0 or distance_to_player() <= trigger_range


func _leap() -> void:
	face_player()
	_charging = false
	_timer = hop_interval
	velocity = Vector2(hop_speed_x * facing, hop_speed_y)
	AudioManager.play_sfx(&"hop")


func _animate_air() -> void:
	if sprite:
		sprite.frame = 2 if velocity.y < 0.0 else 3
