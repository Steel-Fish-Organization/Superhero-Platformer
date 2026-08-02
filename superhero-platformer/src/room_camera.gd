extends Camera2D
## Mega Man style room camera.
##
## Follows the player, clamped to whatever Room he is standing in. Walk into a
## touching room and the screen scrolls across to it; if there is no room that
## way, nothing happens and the camera stays put.
##
## There is no adjacency list to maintain -- "which room is he in now?" is the
## whole rule, so rooms that touch are automatically connected.

signal transition_started(from_room: Node2D, to_room: Node2D)
signal transition_finished(room: Node2D)

## Defaults to the first node in the "player" group.
@export var target: Node2D
## How long a screen-to-screen scroll takes.
@export var transition_time := 0.5
## How far the player is carried through the doorway during the scroll, so he
## doesn't immediately walk back and re-trigger it.
@export var push_distance := 26.0
## Falling this far below the current room counts as a pit.
@export var pit_margin := 48.0

var current: Node2D
var transitioning := false


func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group(&"player")
	make_current()
	if target:
		_enter(_room_at(target.global_position), true)
		# A respawn teleports him; snap there rather than scrolling as if he
		# had walked across the boundary.
		if target.has_signal(&"respawned"):
			target.connect(&"respawned", _on_target_respawned)


func _on_target_respawned() -> void:
	transitioning = false
	_enter(_room_at(target.global_position), true)


func _physics_process(_delta: float) -> void:
	if transitioning or target == null or not is_instance_valid(target):
		return

	if current and current.contains(target.global_position):
		_follow()
		return

	var next := _room_at(target.global_position)
	if next and next != current:
		_transition(next)
		return

	# Not in any room. Below the current one means a pit; otherwise just hold
	# the camera still and let him walk back in.
	if current and target.global_position.y > current.rect().end.y + pit_margin:
		if target.has_method(&"respawn"):
			target.call(&"respawn")
			_enter(_room_at(target.global_position), true)
	_follow()


func _follow() -> void:
	# The limits do the clamping, so this can just track the player.
	global_position = target.global_position.round()


func _room_at(point: Vector2) -> Node2D:
	for room in get_tree().get_nodes_in_group(&"rooms"):
		if room is Node2D and room.call(&"contains", point):
			return room
	return null


func _enter(room: Node2D, snap: bool) -> void:
	if room == null:
		return
	current = room
	_apply_limits(room.call(&"rect"))
	if snap and target:
		global_position = target.global_position.round()
		reset_smoothing()
		force_update_scroll()
	transition_finished.emit(room)


func _transition(next: Node2D) -> void:
	transitioning = true
	var previous := current
	current = next
	transition_started.emit(previous, next)

	var push := _push_direction(previous, next) * push_distance
	if target.has_method(&"set") :
		target.set(&"frozen", true)
		target.set(&"velocity", Vector2.ZERO)

	# Free the limits so the camera can travel across the boundary, then put the
	# new room's limits on once it has arrived.
	_clear_limits()
	var rect: Rect2 = next.call(&"rect")
	var end_pos := _clamp_centre(rect, target.global_position + push)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", end_pos.round(), transition_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "global_position", target.global_position + push, transition_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	_apply_limits(rect)
	target.set(&"frozen", false)
	transitioning = false
	transition_finished.emit(next)


## Which way we crossed, snapped to one axis.
func _push_direction(from_room: Node2D, to_room: Node2D) -> Vector2:
	if from_room == null:
		return Vector2.ZERO
	var delta: Vector2 = to_room.call(&"centre") - from_room.call(&"centre")
	if absf(delta.x) > absf(delta.y):
		return Vector2(signf(delta.x), 0.0)
	return Vector2(0.0, signf(delta.y))


func _apply_limits(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func _clear_limits() -> void:
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000


## Where the camera centre ends up for a given target position inside a room.
func _clamp_centre(rect: Rect2, pos: Vector2) -> Vector2:
	var half := get_viewport_rect().size * 0.5
	var lo := rect.position + half
	var hi := rect.end - half
	return Vector2(
		clampf(pos.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)),
		clampf(pos.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))
