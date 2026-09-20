@tool
extends Area2D
## A hook the hero latches onto, Darkwing Duck style. Touch it from any angle --
## rising, falling, or drifting sideways -- and you hang from it until you jump
## or drop off. Hanging you can shoot in any direction, or jump to the next hook.
##
## Drop these into a level wherever you want a perch or a way across a gap. The
## hero hangs `hang_drop` below the ring; the player script owns that distance.

const HOOK_LAYER := 128       # physics layer 8, "hook"

@export var radius := 4.0
@export var colour := Color(0.85, 0.72, 0.35)
## Length of the stem drawn above the ring, up to whatever it hangs from.
@export var stem := 6.0:
	set(value):
		stem = value
		queue_redraw()


func _ready() -> void:
	add_to_group(&"hooks")
	collision_layer = HOOK_LAYER
	collision_mask = 0
	# The player probes for us, the same way ladders work.
	monitoring = false
	monitorable = true


func _draw() -> void:
	draw_line(Vector2(0.0, -stem - radius), Vector2(0.0, -radius), colour.darkened(0.2), 2.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, colour, 2.0)
