@tool
extends Area2D
## A hook you hang from to throw a switch. Jump into it, your weight drags the
## handle down, and whatever is wired to its `channel` turns on or off.
##
## It's a hook like any other -- the same physics layer, the same grab -- so the
## hero latches onto it from any angle and rides it down. Letting go springs it
## back up.
##
## `momentary` decides what kind of switch it is: a latch that stays where you
## left it (default), or a deadman's handle that only holds while you hang on.

## The switch changed state. Machines on the same channel listen for this.
signal toggled(on: bool)

const HOOK_LAYER := 128       # physics layer 8, "hook"

## Which machines this drives. Everything on the same channel moves together.
@export var channel: StringName = &"A"
## True = only on while someone's hanging on it. False = a latch: each pull flips it.
@export var momentary := false
@export var starts_on := false
## How far the handle travels, and how long the trip takes.
@export var travel := 14.0
@export var pull_time := 0.35
## Springs back this much faster than it was pulled down.
@export var return_scale := 1.6

@export_group("Look")
@export var on_colour := Color(0.45, 0.95, 0.55)
@export var off_colour := Color(0.85, 0.72, 0.35)

var on := false
## 0 at the top of its travel, 1 at the bottom.
var pull := 0.0

var _home := Vector2.ZERO
var _was_down := false


func _ready() -> void:
	add_to_group(&"switches")
	add_to_group(&"hooks")
	collision_layer = HOOK_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	on = starts_on
	_home = position
	if not Engine.is_editor_hint():
		toggled.emit.call_deferred(on)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	var held := _is_held()
	var speed := delta / maxf(pull_time, 0.01)
	pull = clampf(pull + (speed if held else -speed * return_scale), 0.0, 1.0)
	position = _home + Vector2(0.0, travel * pull)

	var down := pull >= 1.0
	if down and not _was_down:
		_throw(true)
	elif not down and _was_down and momentary:
		_throw(false)
	_was_down = down
	queue_redraw()


## Someone's weight is on it: the hero is hanging, and it's this they're hanging
## from.
func _is_held() -> bool:
	var player := get_tree().get_first_node_in_group(&"player")
	return player != null and player.has_method(&"hanging_from") and player.hanging_from() == self


func _throw(down: bool) -> void:
	on = down if momentary else not on
	toggled.emit(on)


## For tests and for machinery that wants to force a state.
func set_on(value: bool) -> void:
	if on == value:
		return
	on = value
	toggled.emit(on)


func _draw() -> void:
	# The rail it slides on, drawn from the handle back up to where it rests.
	var top := -travel * pull
	draw_line(Vector2(0.0, top - 10.0), Vector2(0.0, 0.0), Color(0.5, 0.52, 0.6), 2.0)
	var colour := on_colour if on else off_colour
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, colour, 2.0)
	draw_rect(Rect2(-7.0, -2.0, 14.0, 4.0), colour, true)
