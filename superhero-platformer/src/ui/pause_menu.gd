extends CanvasLayer
## Mega Man's pause screen: pick a weapon, burn a tank, or bail out to the
## stage select. Pauses the tree while open.

const ROW_HEIGHT := 16
const LIST_POS := Vector2(70, 56)
const BAR_X := 220.0
const BAR_WIDTH := 100.0

enum RowKind { WEAPON, E_TANK, W_TANK, QUIT }

var open: bool = false
## Set by the level while dying or finishing, so the pause key does nothing then.
var blocked: bool = false
var _rows: Array[Dictionary] = []
var _index: int = 0

@onready var _canvas: Control = $Draw


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func toggle() -> void:
	if open:
		close()
	else:
		show_menu()


func show_menu() -> void:
	_build_rows()
	_index = _index_of_current_weapon()
	open = true
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx(&"pause")
	_canvas.queue_redraw()


func close() -> void:
	open = false
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx(&"pause")


func _build_rows() -> void:
	_rows.clear()
	for i in GameState.unlocked_weapons.size():
		var w := GameState.get_weapon(GameState.unlocked_weapons[i])
		if w:
			_rows.append({"kind": RowKind.WEAPON, "weapon": w, "index": i})
	if GameState.e_tanks > 0:
		_rows.append({"kind": RowKind.E_TANK})
	if GameState.w_tanks > 0:
		_rows.append({"kind": RowKind.W_TANK})
	_rows.append({"kind": RowKind.QUIT})


func _index_of_current_weapon() -> int:
	for i in _rows.size():
		var row := _rows[i]
		if row["kind"] == RowKind.WEAPON and row["index"] == GameState.current_weapon_index:
			return i
	return 0


func _unhandled_input(event: InputEvent) -> void:
	# Opening is handled here too, rather than by the level polling Input: a
	# polled check would re-fire on the same frame the menu closes and reopen it.
	if not open:
		if not blocked and event.is_action_pressed(&"pause"):
			show_menu()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause"):
		_confirm_weapon()
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_down"):
		_move(1)
	elif event.is_action_pressed(&"move_up"):
		_move(-1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"fire"):
		_activate()
		get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	if _rows.is_empty():
		return
	_index = wrapi(_index + step, 0, _rows.size())
	AudioManager.play_sfx(&"menu_move")
	_canvas.queue_redraw()


func _activate() -> void:
	if _rows.is_empty():
		return
	var row := _rows[_index]
	match row["kind"]:
		RowKind.WEAPON:
			_confirm_weapon()
			close()
		RowKind.E_TANK:
			if GameState.use_e_tank():
				AudioManager.play_sfx(&"heal")
				_build_rows()
				_index = mini(_index, _rows.size() - 1)
			else:
				AudioManager.play_sfx(&"denied")
			_canvas.queue_redraw()
		RowKind.W_TANK:
			if GameState.use_w_tank():
				AudioManager.play_sfx(&"heal")
				_build_rows()
				_index = mini(_index, _rows.size() - 1)
			else:
				AudioManager.play_sfx(&"denied")
			_canvas.queue_redraw()
		RowKind.QUIT:
			close()
			SceneRouter.goto_stage_select()


func _confirm_weapon() -> void:
	if _rows.is_empty():
		return
	var row := _rows[_index]
	if row["kind"] == RowKind.WEAPON:
		GameState.select_weapon(int(row["index"]))


# ---------------------------------------------------------------------------
func draw_menu(c: Control) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, GameCamera.VIEW_SIZE), Color(0.02, 0.02, 0.06, 0.88), true)
	c.draw_rect(Rect2(Vector2(48, 28), Vector2(330, 184)), Color(0.1, 0.12, 0.22, 1.0), true)
	c.draw_rect(Rect2(Vector2(48, 28), Vector2(330, 184)), Color(0.45, 0.6, 0.9, 1.0), false, 1.0)
	c.draw_string(font, Vector2(LIST_POS.x, 46), "WEAPONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.7, 0.9, 1.0))

	for i in _rows.size():
		var row := _rows[i]
		var y := LIST_POS.y + float(i * ROW_HEIGHT)
		var selected := i == _index
		if selected:
			c.draw_string(font, Vector2(LIST_POS.x - 12.0, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				Color(1, 0.9, 0.4))
		_draw_row(c, font, row, Vector2(LIST_POS.x, y), selected)

	c.draw_string(font, Vector2(LIST_POS.x - 12.0, 200.0),
		"UP/DOWN select    Z or X confirm    ENTER resume",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.6, 0.75))


func _draw_row(c: Control, font: Font, row: Dictionary, pos: Vector2, selected: bool) -> void:
	var text := ""
	var col := Color.WHITE if selected else Color(0.72, 0.76, 0.86)
	match row["kind"]:
		RowKind.WEAPON:
			var w: WeaponData = row["weapon"]
			text = w.display_name
			col = w.hud_color if selected else w.hud_color.darkened(0.25)
			if w.is_metered():
				_draw_energy(c, pos, GameState.weapon_energy_of(w.id), w.max_energy, w.hud_color)
			else:
				c.draw_string(font, Vector2(BAR_X, pos.y), "UNLIMITED",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.55, 0.7))
		RowKind.E_TANK:
			text = "E-TANK  x%d" % GameState.e_tanks
			col = Color(0.4, 0.9, 1.0)
		RowKind.W_TANK:
			text = "W-TANK  x%d" % GameState.w_tanks
			col = Color(1.0, 0.85, 0.3)
		RowKind.QUIT:
			text = "EXIT STAGE"
			col = Color(1.0, 0.5, 0.5) if selected else Color(0.7, 0.4, 0.4)
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _draw_energy(c: Control, pos: Vector2, value: float, maximum: float, col: Color) -> void:
	var frac := 0.0 if maximum <= 0.0 else clampf(value / maximum, 0.0, 1.0)
	var rect := Rect2(Vector2(BAR_X, pos.y - 6.0), Vector2(BAR_WIDTH, 6.0))
	c.draw_rect(rect, Color(0.15, 0.16, 0.24), true)
	c.draw_rect(Rect2(rect.position, Vector2(BAR_WIDTH * frac, 6.0)), col, true)
	c.draw_rect(rect, Color(0.35, 0.4, 0.55), false, 1.0)
