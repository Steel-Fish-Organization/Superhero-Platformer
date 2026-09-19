extends CanvasLayer
## Mega Man style health bar, top-left, fed by the Player's health_changed
## signal. Drawn with draw_rect rather than Control nodes so every unit lands on
## a whole pixel at 432x240.

const BAR_POS := Vector2(10, 14)
const BAR_WIDTH := 6
const UNIT_HEIGHT := 2
const BORDER := Color(0.06, 0.06, 0.12)
const EMPTY := Color(0.16, 0.16, 0.26)
const LIGHT := Color(0.85, 0.95, 1.0)
const DARK := Color(0.3, 0.75, 1.0)

var _health := 0
var _max_health := 1

@onready var _canvas: Control = $Draw


func _ready() -> void:
	_canvas.draw.connect(_draw_hud)
	# Deferred so the player has joined its group whatever the scene order.
	_hook_player.call_deferred()


func _hook_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not player.has_signal(&"health_changed"):
		push_warning("HUD: no player with a health_changed signal found.")
		return
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	_health = current
	_max_health = maxi(maximum, 1)
	_canvas.queue_redraw()


func _draw_hud() -> void:
	# frame
	var height := _max_health * UNIT_HEIGHT + 2
	_canvas.draw_rect(Rect2(BAR_POS - Vector2(1, 1), Vector2(BAR_WIDTH + 2, height)), BORDER, true)
	# units fill from the bottom up, alternating light and dark
	for i in _max_health:
		var y := BAR_POS.y + float((_max_health - 1 - i) * UNIT_HEIGHT)
		var col := EMPTY
		if i < _health:
			col = LIGHT if i % 2 == 0 else DARK
		_canvas.draw_rect(Rect2(Vector2(BAR_POS.x, y), Vector2(BAR_WIDTH, UNIT_HEIGHT)), col, true)
