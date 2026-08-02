extends Enemy
## Ground patroller. Walks until it meets a wall or a ledge, then turns around.
## The Mega Man staple -- cheap, predictable, good for teaching a jump.

@export var speed: float = 34.0
## Turn around at the edge of a platform instead of walking off.
@export var stop_at_ledges: bool = true
## Pause in seconds when turning. 0 = turn instantly.
@export var turn_pause: float = 0.0
## Walk toward the player instead of patrolling blindly.
@export var chase: bool = false
@export var chase_range: float = 120.0

var _pause: float = 0.0


func _behaviour(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		velocity.x = 0.0
		return

	if chase and distance_to_player() < chase_range:
		face_player()

	if is_on_floor():
		var blocked := is_on_wall()
		var ledge := stop_at_ledges and at_ledge()
		if blocked or ledge:
			facing = -facing
			_pause = turn_pause

	velocity.x = speed * facing
