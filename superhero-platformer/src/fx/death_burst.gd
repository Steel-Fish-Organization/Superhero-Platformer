extends Node2D
## The Mega Man death explosion: pellets flying out in a ring, then silence.

const PELLET := preload("res://assets/sprites/shot_lv1.png")

@export var pellet_count: int = 8
@export var speed: float = 90.0
@export var duration: float = 1.1
@export var color: Color = Color(0.38, 0.91, 0.94)
## Adds a second, slower ring like the boss/player death in MM5.
@export var double_ring: bool = true

var _pellets: Array[Sprite2D] = []
var _velocities: Array[Vector2] = []
var _time: float = 0.0


func _ready() -> void:
	_make_ring(pellet_count, speed, 0.0)
	if double_ring:
		_make_ring(pellet_count, speed * 0.55, PI / pellet_count)


func _make_ring(count: int, spd: float, offset: float) -> void:
	for i in count:
		var angle := offset + TAU * float(i) / float(count)
		var s := Sprite2D.new()
		s.texture = PELLET
		s.hframes = 2
		s.modulate = color
		add_child(s)
		_pellets.append(s)
		_velocities.append(Vector2.RIGHT.rotated(angle) * spd)


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	var blink := int(_time * 20.0) % 2
	for i in _pellets.size():
		_pellets[i].position += _velocities[i] * delta
		_pellets[i].frame = blink
