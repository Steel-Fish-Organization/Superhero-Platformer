@tool
extends AnimatableBody2D
## A door that slides out of the way while its channel is powered. Set
## `inverted` for one that shuts instead -- a gate that a switch drops.
##
## `opening` is where the door goes when it opens, relative to where it was
## placed: (0, -24) sinks it into the ceiling, (0, 24) into the floor.

@export var opening := Vector2(0.0, -26.0)
@export var seconds := 0.6
@export var channel: StringName = &"A"
@export var inverted := false
@export var starts_open := false

var open := false

var _home := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	sync_to_physics = true
	_home = position
	open = starts_open
	_t = 1.0 if open else 0.0
	_place()
	if Engine.is_editor_hint():
		return
	open = Power.connect_channel(self, channel, _on_switch) != inverted
	_t = 1.0 if open else 0.0
	_place()


func _on_switch(switch_on: bool) -> void:
	open = switch_on != inverted


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var want := 1.0 if open else 0.0
	if is_equal_approx(_t, want):
		return
	_t = move_toward(_t, want, delta / maxf(seconds, 0.01))
	_place()


func _place() -> void:
	position = _home + opening * _t
