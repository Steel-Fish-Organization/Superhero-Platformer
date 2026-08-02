class_name GameCamera
extends Camera2D
## Mega Man style camera: rigid follow, hard-clamped to the current room, and a
## scripted scroll when the player crosses into the next room.
##
## Rooms are CameraRoom areas placed around the level. The camera never eases --
## in the reference games it is locked to the grid and only moves when it must.

signal room_transition_started
signal room_transition_finished

const VIEW_SIZE := Vector2(426, 240)
## How long a screen-to-screen scroll takes, roughly matching MM5/6.
const TRANSITION_TIME := 0.55
## How far the player is pushed through the doorway during a scroll.
const PUSH_DISTANCE := 26.0

@export var target_path: NodePath
## Keeps the hero a little above centre so there is more room to look ahead.
@export var follow_offset: Vector2 = Vector2(0, -12)
## 0 = locked to the player (classic). Higher values ease the camera in.
@export var smoothing: float = 0.0

var current_room: CameraRoom
var transitioning: bool = false

var _target: Node2D
var _shake: float = 0.0
var _shake_decay: float = 6.0
var _locked: bool = false
var _lock_rect: Rect2


func _ready() -> void:
	add_to_group(&"camera")
	ignore_rotation = true
	position_smoothing_enabled = smoothing > 0.0
	position_smoothing_speed = smoothing
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		_target = get_tree().get_first_node_in_group(&"player") as Node2D


func set_target(node: Node2D) -> void:
	_target = node


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - _shake_decay * delta)
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO

	if transitioning or _target == null or not is_instance_valid(_target):
		return
	global_position = (_target.global_position + follow_offset).round()


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Snap straight to a room without a scroll (level start, respawn).
func snap_to_room(room: CameraRoom) -> void:
	if room == null:
		return
	current_room = room
	_apply_limits(room.world_rect())
	if _target:
		global_position = (_target.global_position + follow_offset).round()
	reset_smoothing()
	force_update_scroll()


## Scroll to the next room, freezing the player the way Mega Man does.
func transition_to(room: CameraRoom, player: Player) -> void:
	if room == null or room == current_room or transitioning:
		return
	transitioning = true
	room_transition_started.emit()
	current_room = room

	var rect := room.world_rect()
	var was_controlled := false
	var push := Vector2.ZERO
	if player:
		was_controlled = player.control_enabled
		player.control_enabled = false
		player.velocity = Vector2.ZERO
		push = _push_direction(rect, player.global_position) * PUSH_DISTANCE

	# free the limits so the camera can move across the boundary
	_clear_limits()
	var end_pos := _clamp_to(rect, (player.global_position if player else global_position) + follow_offset + push)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", end_pos.round(), TRANSITION_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if player and push != Vector2.ZERO:
		tween.tween_property(player, "global_position", player.global_position + push, TRANSITION_TIME)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	_apply_limits(rect)
	if player:
		# Restore rather than force, so a scroll during a cutscene stays locked.
		player.control_enabled = was_controlled
		player.velocity = Vector2.ZERO
	transitioning = false
	room_transition_finished.emit()


## Boss arenas lock the camera to a fixed rect for the fight.
func lock_to_rect(rect: Rect2) -> void:
	_locked = true
	_lock_rect = rect
	_apply_limits(rect)
	global_position = _clamp_to(rect, rect.position + rect.size * 0.5).round()


func unlock() -> void:
	_locked = false
	if current_room:
		_apply_limits(current_room.world_rect())


func _push_direction(rect: Rect2, from: Vector2) -> Vector2:
	## Which way the player entered the new room, snapped to an axis.
	var centre := rect.position + rect.size * 0.5
	var delta := centre - from
	if absf(delta.x) > absf(delta.y):
		return Vector2(signf(delta.x), 0.0)
	return Vector2(0.0, signf(delta.y))


func _apply_limits(rect: Rect2) -> void:
	# A room smaller than the screen is centred rather than clamped.
	var size := rect.size
	if size.x < VIEW_SIZE.x:
		var pad := (VIEW_SIZE.x - size.x) * 0.5
		rect.position.x -= pad
		rect.size.x = VIEW_SIZE.x
	if size.y < VIEW_SIZE.y:
		var pad_y := (VIEW_SIZE.y - size.y) * 0.5
		rect.position.y -= pad_y
		rect.size.y = VIEW_SIZE.y
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.position.x + rect.size.x)
	limit_bottom = int(rect.position.y + rect.size.y)


func _clear_limits() -> void:
	limit_left = -100000000
	limit_top = -100000000
	limit_right = 100000000
	limit_bottom = 100000000


func _clamp_to(rect: Rect2, pos: Vector2) -> Vector2:
	var half := VIEW_SIZE * 0.5
	var min_pos := rect.position + half
	var max_pos := rect.position + rect.size - half
	return Vector2(
		clampf(pos.x, minf(min_pos.x, max_pos.x), maxf(min_pos.x, max_pos.x)),
		clampf(pos.y, minf(min_pos.y, max_pos.y), maxf(min_pos.y, max_pos.y)))
