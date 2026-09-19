extends Node2D
## The aiming reticle. It's a child of the Player but top_level, so it sits in
## world space rather than following the hero around.
##
## With the mouse it moves itself to the pointer every rendered frame -- doing
## that from the player's physics tick would make it trail the cursor. With the
## right stick the player places it.

@export var radius := 5.0
@export var colour := Color(1.0, 1.0, 1.0, 0.95)
@export var outline := Color(0.05, 0.06, 0.1, 0.85)

## Set by the player while the mouse is the aiming device.
var follow_mouse := false


func _ready() -> void:
	top_level = true
	z_index = 100
	visible = false


func _process(_delta: float) -> void:
	if follow_mouse and visible:
		global_position = get_global_mouse_position().round()


func _draw() -> void:
	# Dark outline first, then the bright reticle on top, so it reads against
	# both the dark background and light tiles.
	_draw_shape(outline, 3.0)
	_draw_shape(colour, 1.0)


func _draw_shape(col: Color, width: float) -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, col, width)
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(dir * (radius - 2.0), dir * (radius + 3.0), col, width)
	draw_rect(Rect2(-0.5, -0.5, 1.0, 1.0), col, true)
