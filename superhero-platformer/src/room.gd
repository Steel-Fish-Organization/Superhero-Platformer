@tool
extends Node2D
## One Mega Man style room. Place these on the screen grid; wherever two of them
## touch, the camera transitions between them. Nothing else to wire up.
##
## A room is a whole number of screens across and down, and it should only be
## bigger than one screen on ONE axis -- that is what makes a room scroll either
## horizontally or vertically but never both. The editor warns you otherwise.
##
## Rooms snap to the screen grid while you drag them in the editor, so "touching"
## is easy to get exactly right.

const SCREEN := Vector2(432, 240)

## Size in screens. (3,1) scrolls horizontally, (1,3) scrolls vertically,
## (1,1) doesn't scroll at all.
@export var screens := Vector2i(1, 1):
	set(value):
		screens = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		update_configuration_warnings()
		queue_redraw()

## Turn off if you want to nudge a room off the grid on purpose.
@export var snap_to_grid := true


func _ready() -> void:
	add_to_group(&"rooms")


func size() -> Vector2:
	return Vector2(screens) * SCREEN


## World-space bounds of the room.
func rect() -> Rect2:
	return Rect2(global_position, size())


func contains(point: Vector2) -> bool:
	return rect().has_point(point)


func centre() -> Vector2:
	return global_position + size() * 0.5


# ---------------------------------------------------------------------------
# editor only
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	if snap_to_grid:
		position = position.snapped(SCREEN)
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var box := Rect2(Vector2.ZERO, size())
	draw_rect(box, Color(0.35, 0.8, 1.0, 0.06), true)
	draw_rect(box, Color(0.35, 0.8, 1.0, 0.9), false, 2.0)
	# dashed-ish screen divisions so multi-screen rooms are readable
	for i in range(1, screens.x):
		var x := i * SCREEN.x
		draw_line(Vector2(x, 0), Vector2(x, size().y), Color(0.35, 0.8, 1.0, 0.35), 1.0)
	for j in range(1, screens.y):
		var y := j * SCREEN.y
		draw_line(Vector2(0, y), Vector2(size().x, y), Color(0.35, 0.8, 1.0, 0.35), 1.0)


func _get_configuration_warnings() -> PackedStringArray:
	if screens.x > 1 and screens.y > 1:
		return ["A room should scroll on one axis only. Set screens.x or screens.y to 1."]
	return []
