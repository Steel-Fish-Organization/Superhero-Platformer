extends CanvasLayer
## Three-slot file select. Empty slots start a new game; existing slots resume.
## Holding the slide key on a slot erases it after a confirm.

const SLOT_BOX := Vector2(300, 42)
const SLOT_TOP := 62.0
const SLOT_GAP := 14.0

var cursor: int = 0
var _confirm_erase: bool = false
var _blink: float = 0.0
var _summaries: Array[Dictionary] = []
var _busy: bool = false

@onready var _canvas: Control = $Draw


func _ready() -> void:
	layer = 5
	_refresh()
	AudioManager.play_music(&"title")


func _refresh() -> void:
	_summaries = SaveSystem.all_summaries()


func _process(delta: float) -> void:
	_blink += delta
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or SceneRouter.is_busy():
		return
	if _confirm_erase:
		if event.is_action_pressed(&"jump") or event.is_action_pressed(&"fire"):
			SaveSystem.erase_slot(cursor)
			_refresh()
			_confirm_erase = false
			AudioManager.play_sfx(&"menu_confirm")
		elif event.is_action_pressed(&"dash") or event.is_action_pressed(&"pause"):
			_confirm_erase = false
			AudioManager.play_sfx(&"denied")
		return

	if event.is_action_pressed(&"move_down"):
		_move(1)
	elif event.is_action_pressed(&"move_up"):
		_move(-1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"fire"):
		_start()
	elif event.is_action_pressed(&"dash"):
		if not _summaries[cursor].get("empty", true):
			_confirm_erase = true
			AudioManager.play_sfx(&"menu_move")
	elif event.is_action_pressed(&"pause"):
		SceneRouter.goto_title()


func _move(step: int) -> void:
	cursor = wrapi(cursor + step, 0, SaveSystem.SLOT_COUNT)
	AudioManager.play_sfx(&"menu_move")


func _start() -> void:
	_busy = true
	AudioManager.play_sfx(&"menu_confirm")
	GameState.current_slot = cursor
	var data := SaveSystem.read_slot(cursor)
	if data.is_empty():
		GameState.reset_run()
		GameState.save_progress()
	else:
		GameState.from_dict(data)
	AudioManager.stop_music(0.3)
	SceneRouter.goto_stage_select()


# ---------------------------------------------------------------------------
func draw_menu(c: Control) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, GameCamera.VIEW_SIZE), Color(0.03, 0.04, 0.09), true)
	c.draw_string(font, Vector2(0, 34), "SELECT FILE", HORIZONTAL_ALIGNMENT_CENTER, 426, 16,
		Color(1.0, 0.85, 0.35))

	var left := (GameCamera.VIEW_SIZE.x - SLOT_BOX.x) * 0.5
	for i in SaveSystem.SLOT_COUNT:
		var pos := Vector2(left, SLOT_TOP + float(i) * (SLOT_BOX.y + SLOT_GAP))
		_draw_slot(c, font, i, pos)

	var hint := "X/Z select    C erase    ENTER back"
	if _confirm_erase:
		hint = "ERASE FILE %d?  X/Z confirm   C cancel" % (cursor + 1)
	c.draw_string(font, Vector2(0, 226), hint, HORIZONTAL_ALIGNMENT_CENTER, 426, 8,
		Color(1, 0.5, 0.5) if _confirm_erase else Color(0.5, 0.55, 0.7))


func _draw_slot(c: Control, font: Font, index: int, pos: Vector2) -> void:
	var selected := index == cursor
	var rect := Rect2(pos, SLOT_BOX)
	c.draw_rect(rect, Color(0.08, 0.1, 0.18), true)
	var border := Color(0.25, 0.3, 0.45)
	if selected:
		border = Color(1, 0.9, 0.35) if fmod(_blink, 0.36) < 0.24 else Color(1, 1, 1)
	c.draw_rect(rect, border, false, 2.0 if selected else 1.0)

	var data := _summaries[index]
	c.draw_string(font, pos + Vector2(10, 16), "FILE %d" % (index + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.9, 1.0))

	if data.get("empty", true):
		c.draw_string(font, pos + Vector2(10, 32), "NEW GAME",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.65, 0.85))
		return

	var cleared := int(data.get("stages_cleared", 0))
	var beaten := bool(data.get("beaten", false))
	c.draw_string(font, pos + Vector2(10, 32),
		"STAGES %d/8    WEAPONS %d    LIVES x%d" % [cleared, int(data.get("weapons", 1)), int(data.get("lives", 2))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.78, 0.92))
	c.draw_string(font, pos + Vector2(0, 16), SaveSystem.format_playtime(float(data.get("playtime", 0.0))),
		HORIZONTAL_ALIGNMENT_RIGHT, int(SLOT_BOX.x) - 10, 8, Color(0.6, 0.68, 0.85))
	if beaten:
		c.draw_string(font, pos + Vector2(0, 32), "COMPLETE",
			HORIZONTAL_ALIGNMENT_RIGHT, int(SLOT_BOX.x) - 10, 8, Color(0.5, 1.0, 0.6))
