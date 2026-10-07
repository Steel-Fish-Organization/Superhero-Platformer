extends CanvasLayer
## Fade-to-black scene changes. Autoloaded as `SceneRouter`.
##
## Lifted from the reference/full-framework branch and trimmed to what this
## branch has: no title, file select or ending scenes yet. Always change scenes
## through here rather than calling change_scene_to_file directly, so the fade,
## the unpause and the "already loading" guard stay in one place.

signal transition_started(target: String)
signal transition_finished(target: String)

@onready var _fade: ColorRect = $Fade

## Handed to a cutscene by play_cutscene(): the outcome it should tell, and the
## stage to load once it's over.
var cutscene_outcome := ""
var cutscene_next: StringName = &""

var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.color.a = 0.0
	_fade.visible = false


func is_busy() -> bool:
	return _busy


func change_scene(path: String, fade_out := 0.35, fade_in := 0.35) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: no scene at '%s'" % path)
		return
	_busy = true
	transition_started.emit(path)
	get_tree().paused = false

	if fade_out > 0.0:
		await _fade_to(1.0, fade_out)

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: failed to load '%s' (%s)" % [path, error_string(err)])
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


## Loads a stage by id, through the graph so the scene path stays in one place.
func goto_stage(stage_id: StringName) -> void:
	var state := get_node_or_null(^"/root/GameState")
	var path := "res://levels/%s.tscn" % stage_id
	if state and state.graph:
		path = state.graph.scene_path(stage_id)
		state.current_stage_id = stage_id
	change_scene(path)


## Plays a cutscene for an outcome ("H", "N" or "D"), then goes on to
## `next_stage` when the cutscene calls finish_cutscene().
func play_cutscene(path: String, outcome_code: String, next_stage: StringName) -> void:
	cutscene_outcome = outcome_code
	cutscene_next = next_stage
	change_scene(path)


## Called by a cutscene on its last line. With no stage to go to, the run is
## over, and there's no ending screen yet, so it starts again from the top.
func finish_cutscene() -> void:
	var next := cutscene_next
	cutscene_outcome = ""
	cutscene_next = &""
	# A cutscene with nothing to show ends before its own fade-in has finished.
	while _busy:
		await transition_finished
	if next == &"":
		var state := get_node_or_null(^"/root/GameState")
		if state == null or state.graph == null:
			return
		next = state.graph.first_stage
	goto_stage(next)


func reload_stage() -> void:
	var state := get_node_or_null(^"/root/GameState")
	if state and state.current_stage_id != &"":
		goto_stage(state.current_stage_id)


func _fade_to(alpha: float, duration: float) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished
	_fade.visible = alpha > 0.0
