extends Enemy
## Crouch-and-leap enemy, like the frog/spring types in MM5-6. Hops toward the
## player on a timer; the crouch frame telegraphs the jump.

@export var hop_interval := 1.3
@export var hop_speed_x := 70.0
@export var hop_speed_y := -230.0
## Only hops when the player is within this range. 0 = always hop.
@export var trigger_range := 0.0
@export var telegraph_time := 0.25

var _timer := 0.0
var _charging := false

# CUSTOM FUNCTIONS
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
		return

	if _timer <= 0.0 and _in_range():
		_charging = true
		_timer = telegraph_time
		# Squeeze the crouch animation into the telegraph so it lands on the leap.
		var length := anim_length(&"pre-jump")
		play_anim(&"pre-jump", length / telegraph_time if telegraph_time > 0.0 else 1.0)
	else:
		play_anim(&"idle")


func _in_range() -> bool:
	return trigger_range <= 0.0 or distance_to_player() <= trigger_range


func _leap() -> void:
	face_player()
	_charging = false
	_timer = hop_interval
	velocity = Vector2(hop_speed_x * facing, hop_speed_y)


func _animate_air() -> void:
	play_anim(&"jump" if velocity.y < 0.0 else &"fall")
