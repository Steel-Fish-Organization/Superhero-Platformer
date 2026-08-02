extends CanvasLayer
## Title screen. Any confirm key goes to the file select.

const CITY := preload("res://assets/sprites/bg_city.png")

var _time: float = 0.0
var _leaving: bool = false

@onready var _canvas: Control = $Draw


func _ready() -> void:
	layer = 5
	AudioManager.play_music(&"title")


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or SceneRouter.is_busy():
		return
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"fire") or event.is_action_pressed(&"pause"):
		_leaving = true
		AudioManager.play_sfx(&"menu_confirm")
		SceneRouter.goto_file_select()


func draw_menu(c: Control) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, GameCamera.VIEW_SIZE), Color(0.03, 0.04, 0.09), true)

	# scrolling skyline strip
	var scroll := fmod(_time * 8.0, 64.0)
	for i in range(-1, 8):
		c.draw_texture_rect_region(CITY,
			Rect2(Vector2(float(i) * 64.0 - scroll, 150.0), Vector2(64, 64)),
			Rect2(Vector2.ZERO, Vector2(64, 64)),
			Color(0.5, 0.55, 0.8))

	c.draw_string(font, Vector2(0, 74), "SUPERHERO", HORIZONTAL_ALIGNMENT_CENTER, 426, 28,
		Color(0.4, 0.75, 1.0))
	c.draw_string(font, Vector2(0, 104), "PLATFORMER", HORIZONTAL_ALIGNMENT_CENTER, 426, 22,
		Color(1.0, 0.82, 0.3))

	if fmod(_time, 1.0) < 0.65:
		c.draw_string(font, Vector2(0, 140), "PRESS  Z  TO START", HORIZONTAL_ALIGNMENT_CENTER, 426, 10,
			Color(0.9, 0.95, 1.0))

	c.draw_string(font, Vector2(0, 232), "ARROWS move   X jump   Z fire   C slide   A/S weapon   ENTER pause",
		HORIZONTAL_ALIGNMENT_CENTER, 426, 8, Color(0.45, 0.5, 0.65))
