class_name MovingPlatform
extends AnimatableBody2D
## Platform that travels between waypoints. Riders are carried by feeding the
## platform's velocity into the player's `external_velocity`, which keeps the
## hero's own controls fully responsive while standing on it.

enum Mode { LOOP, PING_PONG, ONE_SHOT, ON_TOUCH }

## Waypoints relative to the platform's start position, in pixels.
@export var waypoints: Array[Vector2] = [Vector2(64, 0)]
@export var speed: float = 40.0
@export var mode: Mode = Mode.PING_PONG
## Seconds to wait at each waypoint.
@export var wait_time: float = 0.4
## Delay before an ON_TOUCH platform starts moving (falling-block feel).
@export var touch_delay: float = 0.35

var _origin: Vector2
var _points: PackedVector2Array = []
var _index: int = 0
var _direction: int = 1
var _wait: float = 0.0
var _moving: bool = true
var _last_position: Vector2
var _riders: Array[Player] = []


func _ready() -> void:
	sync_to_physics = true
	collision_layer = Layers.WORLD
	collision_mask = 0
	_origin = global_position
	_last_position = global_position
	_points.append(Vector2.ZERO)
	for w in waypoints:
		_points.append(w)
	_moving = mode != Mode.ON_TOUCH
	var rider_area := get_node_or_null(^"RiderArea") as Area2D
	if rider_area:
		rider_area.collision_layer = 0
		rider_area.collision_mask = Layers.PLAYER
		rider_area.body_entered.connect(_on_rider_entered)
		rider_area.body_exited.connect(_on_rider_exited)


func _physics_process(delta: float) -> void:
	if _moving and _points.size() > 1:
		if _wait > 0.0:
			_wait -= delta
		else:
			_advance(delta)

	# carry anything standing on top
	var moved := global_position - _last_position
	_last_position = global_position
	if moved != Vector2.ZERO:
		for r in _riders:
			if is_instance_valid(r):
				r.external_velocity += moved / delta


func _advance(delta: float) -> void:
	var target := _origin + _points[_index]
	var to_target := target - global_position
	var step := speed * delta
	if to_target.length() <= step:
		global_position = target
		_wait = wait_time
		_next_index()
		return
	global_position += to_target.normalized() * step


func _next_index() -> void:
	match mode:
		Mode.LOOP:
			_index = (_index + 1) % _points.size()
		Mode.ONE_SHOT, Mode.ON_TOUCH:
			if _index + 1 < _points.size():
				_index += 1
			else:
				_moving = false
		Mode.PING_PONG:
			if _index + _direction >= _points.size() or _index + _direction < 0:
				_direction = -_direction
			_index += _direction


func _on_rider_entered(body: Node) -> void:
	if body is Player and not _riders.has(body):
		_riders.append(body as Player)
		if mode == Mode.ON_TOUCH and not _moving and _index == 0:
			await get_tree().create_timer(touch_delay).timeout
			_moving = true


func _on_rider_exited(body: Node) -> void:
	if body is Player:
		_riders.erase(body as Player)
