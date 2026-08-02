extends CanvasLayer
## Shown when the last life is gone. Continue restarts the stage with a fresh
## set of lives; the progress already saved to the file is untouched.

const OPTIONS := ["CONTINUE", "STAGE SELECT", "QUIT TO TITLE"]

var cursor: int = 0
var _blink: float = 0.0
var _busy: bool = false

@onready var _canvas: Control = $Draw


func _ready() -> void:
	layer = 5
	AudioManager.stop_music()
	AudioManager.play_sfx(&"game_over")
	# Coming back from a game over always restores the standard life count.
	GameState.lives = GameState.STARTING_LIVES
	GameState.health = GameState.MAX_HEALTH
	GameState.refill_all_weapons()


func _process(delta: float) -> void:
	_blink += delta
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or SceneRouter.is_busy():
		return
	if event.is_action_pressed(&"move_down"):
		_move(1)
	elif event.is_action_pressed(&"move_up"):
		_move(-1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"fire") or event.is_action_pressed(&"pause"):
		_activate()


func _move(step: int) -> void:
	cursor = wrapi(cursor + step, 0, OPTIONS.size())
	AudioManager.play_sfx(&"menu_move")


func _activate() -> void:
	_busy = true
	AudioManager.play_sfx(&"menu_confirm")
	match cursor:
		0:
			if GameState.current_stage_id != &"":
				SceneRouter.goto_stage(GameState.current_stage_id)
			else:
				SceneRouter.goto_stage_select()
		1:
			SceneRouter.goto_stage_select()
		_:
			SceneRouter.goto_title()


func draw_menu(c: Control) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, GameCamera.VIEW_SIZE), Color(0.02, 0.02, 0.05), true)
	c.draw_string(font, Vector2(0, 78), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, 426, 24,
		Color(0.9, 0.25, 0.3))

	for i in OPTIONS.size():
		var y := 132.0 + float(i) * 18.0
		var selected := i == cursor
		var col := Color(0.6, 0.65, 0.8)
		if selected:
			col = Color(1, 0.9, 0.4) if fmod(_blink, 0.4) < 0.28 else Color.WHITE
			c.draw_string(font, Vector2(146, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
		c.draw_string(font, Vector2(0, y), OPTIONS[i], HORIZONTAL_ALIGNMENT_CENTER, 426, 10, col)
