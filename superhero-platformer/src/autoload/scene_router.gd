extends CanvasLayer
## Fade-to-black scene transitions. Autoloaded as `SceneRouter`.
##
## Always change scenes through here rather than `get_tree().change_scene_to_file`,
## so the fade, the pause reset and the "loading" guard stay consistent.

signal transition_started(target: String)
signal transition_finished(target: String)

const STAGE_PATH_TEMPLATE := "res://levels/%s.tscn"
const TITLE_SCENE := "res://src/ui/title_screen.tscn"
const FILE_SELECT_SCENE := "res://src/ui/file_select.tscn"
const STAGE_SELECT_SCENE := "res://src/ui/stage_select.tscn"
const GAME_OVER_SCENE := "res://src/ui/game_over.tscn"
const ENDING_SCENE := "res://src/ui/ending.tscn"

@onready var _fade: ColorRect = $Fade

var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.color.a = 0.0
	_fade.visible = false


func is_busy() -> bool:
	return _busy


func change_scene(path: String, fade_out: float = 0.3, fade_in: float = 0.3) -> void:
	if _busy:
		return
	_busy = true
	transition_started.emit(path)
	get_tree().paused = false

	if fade_out > 0.0:
		await _fade_to(1.0, fade_out)

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to load scene '%s' (%s)" % [path, error_string(err)])
		_busy = false
		await _fade_to(0.0, 0.2)
		return

	# let the new scene finish _ready before revealing it
	await get_tree().process_frame
	await get_tree().process_frame

	if fade_in > 0.0:
		await _fade_to(0.0, fade_in)
	_busy = false
	transition_finished.emit(path)


func goto_stage(stage_id: StringName) -> void:
	var path := STAGE_PATH_TEMPLATE % stage_id
	if not ResourceLoader.exists(path):
		push_error("Stage scene missing: %s" % path)
		return
	GameState.prepare_stage(stage_id)
	change_scene(path)


func goto_title() -> void:
	change_scene(TITLE_SCENE)


func goto_file_select() -> void:
	change_scene(FILE_SELECT_SCENE)


func goto_stage_select() -> void:
	GameState.current_stage_id = &""
	change_scene(STAGE_SELECT_SCENE)


func goto_game_over() -> void:
	change_scene(GAME_OVER_SCENE)


func goto_ending() -> void:
	change_scene(ENDING_SCENE)


func reload_stage() -> void:
	if GameState.current_stage_id == &"":
		goto_stage_select()
	else:
		goto_stage(GameState.current_stage_id)


## Flash the screen white -- used for boss deaths and big hits.
func flash(color: Color = Color.WHITE, duration: float = 0.12) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.0, duration)
	tween.tween_callback(rect.queue_free)


func _fade_to(alpha: float, duration: float) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished
	_fade.visible = alpha > 0.0
