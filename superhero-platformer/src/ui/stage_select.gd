extends CanvasLayer
## Stage select. Eight bosses around a 3x3 grid with the hidden ninth stage in
## the middle, exactly like the NES games -- the centre stays a "?" until every
## other stage is cleared.

const PORTRAITS := preload("res://assets/ui/portraits.png")
const CELL := 64          # portrait drawn at 2x
const GAP := 2
const GRID_TOP := 32.0

var cursor: int = 0
var _blink: float = 0.0
var _entering: bool = false

@onready var _canvas: Control = $Draw


func _ready() -> void:
	layer = 5
	AudioManager.play_music(&"stage_select")
	cursor = _first_unlocked_cell()


func _process(delta: float) -> void:
	_blink += delta
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _entering or SceneRouter.is_busy():
		return
	if event.is_action_pressed(&"move_left"):
		_move(-1, 0)
	elif event.is_action_pressed(&"move_right"):
		_move(1, 0)
	elif event.is_action_pressed(&"move_up"):
		_move(0, -1)
	elif event.is_action_pressed(&"move_down"):
		_move(0, 1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"fire") or event.is_action_pressed(&"pause"):
		_confirm()


func _move(dx: int, dy: int) -> void:
	var col := wrapi(cursor % 3 + dx, 0, 3)
	var row := wrapi(cursor / 3 + dy, 0, 3)
	cursor = row * 3 + col
	AudioManager.play_sfx(&"menu_move")


func _confirm() -> void:
	var info := StageLibrary.at_grid(cursor)
	var id: StringName = info["id"]
	if not GameState.is_stage_unlocked(id):
		AudioManager.play_sfx(&"denied")
		return
	if not ResourceLoader.exists(StageLibrary.scene_path(id)):
		push_warning("Stage scene not built yet: %s" % id)
		AudioManager.play_sfx(&"denied")
		return
	_entering = true
	AudioManager.play_sfx(&"menu_confirm")
	AudioManager.stop_music(0.3)
	SceneRouter.goto_stage(id)


func _first_unlocked_cell() -> int:
	for i in 9:
		var info := StageLibrary.at_grid(i)
		if GameState.is_stage_unlocked(info["id"]) and not GameState.is_stage_cleared(info["id"]):
			return i
	return 0


# ---------------------------------------------------------------------------
func draw_menu(c: Control) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, GameCamera.VIEW_SIZE), Color(0.04, 0.05, 0.1), true)

	var info := StageLibrary.at_grid(cursor)
	var id: StringName = info["id"]
	var unlocked := GameState.is_stage_unlocked(id)

	# header: boss name on the left, reward weapon on the right
	var title: String = info["boss"] if unlocked else "? ? ?"
	c.draw_string(font, Vector2(12, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(1, 0.92, 0.5))
	var subtitle: String = info["stage"] if unlocked else "SEALED"
	c.draw_string(font, Vector2(12, 26), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(0.6, 0.7, 0.9))

	var reward := WeaponLibrary.reward_for(id)
	if unlocked and reward != &"":
		var w := GameState.get_weapon(reward)
		if w:
			var owned := GameState.unlocked_weapons.has(reward)
			c.draw_string(font, Vector2(0, 16),
				("GOT: " if owned else "GET: ") + w.display_name,
				HORIZONTAL_ALIGNMENT_RIGHT, 414, 8,
				w.hud_color if owned else Color(0.55, 0.6, 0.75))

	_draw_grid(c, font)
	_draw_footer(c, font)


func _draw_grid(c: Control, font: Font) -> void:
	var total := 3 * CELL + 2 * GAP
	var left := (GameCamera.VIEW_SIZE.x - float(total)) * 0.5
	for i in 9:
		var info := StageLibrary.at_grid(i)
		var id: StringName = info["id"]
		var unlocked := GameState.is_stage_unlocked(id)
		var cleared := GameState.is_stage_cleared(id)
		var col := i % 3
		var row := i / 3
		var pos := Vector2(left + float(col * (CELL + GAP)), GRID_TOP + float(row * (CELL + GAP)))

		var frame := int(info["portrait"]) if unlocked else StageLibrary.LOCKED_PORTRAIT
		var src := Rect2(Vector2(float(frame * 32), 0), Vector2(32, 32))
		var dst := Rect2(pos, Vector2(CELL, CELL))
		var tint := Color.WHITE
		if cleared:
			tint = Color(0.5, 0.55, 0.65)
		elif not unlocked:
			tint = Color(0.7, 0.7, 0.8)
		c.draw_texture_rect_region(PORTRAITS, dst, src, tint)

		if cleared:
			c.draw_string(font, pos + Vector2(6, CELL - 6), "CLEAR",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 1.0, 0.6))

		# cursor
		if i == cursor:
			var flash := fmod(_blink, 0.36) < 0.24
			var border := Color(1, 0.9, 0.35) if flash else Color(1, 1, 1)
			c.draw_rect(dst.grow(1.0), border, false, 2.0)
		else:
			c.draw_rect(dst, Color(0.2, 0.24, 0.36), false, 1.0)


func _draw_footer(c: Control, font: Font) -> void:
	var cleared := GameState.cleared_count()
	c.draw_string(font, Vector2(12, 237), "CLEARED %d/8" % cleared,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.7, 0.9))
	c.draw_string(font, Vector2(0, 237), "LIVES x%d   E-TANK %d" % [maxi(GameState.lives, 0), GameState.e_tanks],
		HORIZONTAL_ALIGNMENT_RIGHT, 414, 8, Color(0.6, 0.7, 0.9))
	if not GameState.all_main_stages_cleared():
		c.draw_string(font, Vector2(0, 237), "CENTRE SEALED",
			HORIZONTAL_ALIGNMENT_CENTER, 426, 8, Color(0.8, 0.45, 0.5))
