extends CanvasLayer
## Placeholder ending: a scrolling credit roll after the final stage. Swap the
## LINES array (or replace the whole scene) once the real ending exists.

const LINES := [
	"",
	"THE CITADEL GOES DARK.",
	"",
	"NINE MACHINES SILENCED.",
	"ONE CITY STILL STANDING.",
	"",
	"",
	"SUPERHERO PLATFORMER",
	"",
	"THANKS FOR PLAYING",
	"",
	"",
	"PRESS  Z  TO RETURN",
]

var _scroll: float = 0.0
var _busy: bool = false

@onready var _canvas: Control = $Draw


func _ready() -> void:
	layer = 5
	AudioManager.play_music(&"ending")
	GameState.game_beaten = true
	GameState.save_progress()


func _process(delta: float) -> void:
	_scroll += delta * 14.0
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or SceneRouter.is_busy():
		return
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"fire") or event.is_action_pressed(&"pause"):
		_busy = true
		SceneRouter.goto_title()


func draw_menu(c: Control) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, GameCamera.VIEW_SIZE), Color(0.02, 0.03, 0.08), true)
	var top := 240.0 - _scroll
	for i in LINES.size():
		var y := top + float(i) * 16.0
		if y < -16.0 or y > 250.0:
			continue
		var size := 16 if i == 7 else 10
		var col := Color(1.0, 0.85, 0.35) if i == 7 else Color(0.75, 0.85, 1.0)
		c.draw_string(font, Vector2(0, y), LINES[i], HORIZONTAL_ALIGNMENT_CENTER, 426, size, col)
	# hold at the end rather than scrolling forever
	if top < -float(LINES.size()) * 16.0 + 120.0:
		_scroll -= 14.0 * get_process_delta_time()
