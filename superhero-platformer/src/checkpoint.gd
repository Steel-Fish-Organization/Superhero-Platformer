@tool
extends Area2D
## Walk past it and death, pits and R bring you back here instead of the start
## of the level. Mega Man puts one at each major section break -- after a long
## climb, before a mini-boss.
##
## Checkpoints only ever move you forward: walking back past an earlier one
## doesn't pull your respawn back to it. Place it with its origin on the floor;
## that's where the hero reappears.

const TRIGGER_LAYER := 64     # physics layer 7, "trigger"
const PLAYER_LAYER := 2

## Where the hero reappears, relative to this node.
@export var spawn_offset := Vector2.ZERO
## Draw a little flag post that lights up once reached. Turn off for an
## invisible, Mega Man-style checkpoint (it still shows in the editor).
@export var show_flag := true:
	set(value):
		show_flag = value
		queue_redraw()

var reached := false


func _ready() -> void:
	collision_layer = TRIGGER_LAYER
	collision_mask = PLAYER_LAYER
	monitorable = false
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if reached or not body.has_method(&"set_checkpoint"):
		return
	reached = true
	body.call(&"set_checkpoint", global_position + spawn_offset)
	queue_redraw()


func _draw() -> void:
	if not show_flag and not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-1, -24, 2, 24), Color(0.55, 0.58, 0.68), true)
	var flag := PackedVector2Array([Vector2(1, -24), Vector2(11, -20), Vector2(1, -16)])
	draw_colored_polygon(flag, Color(0.35, 0.95, 1.0) if reached else Color(0.3, 0.32, 0.42))
