class_name Cutscene
extends Control
## A comic page that plays between stages. A stage's outro has one script per
## outcome -- hero, neutral and dark -- and tells whichever one was just earned.
##
## Each line fills the next panel on the page. When the page runs out of
## panels, it clears and carries on, so a script can be any length. Jump, fire,
## interact or Enter finishes the line being typed, then moves to the next one.
##
## Scripts are written the way dialogue is drafted:
##
##     * Citizen, "Thank you for saving me!"
##     * Later that day...
##
## `Name, "words"` is someone speaking; anything else is a narration caption.
## The bullets are optional. A speaker's face comes from `speakers`, by name.
##
## The SceneRouter tells it which outcome to play. Run on its own (F6), it plays
## `preview_outcome` instead, so each script can be checked from the editor.

## The last line has been read.
signal finished

const ADVANCE_ACTIONS: Array[StringName] = [&"jump", &"fire", &"interact", &"ui_accept"]

@export_multiline var hero_script := ""
@export_multiline var neutral_script := ""
@export_multiline var dark_script := ""
@export var speakers: Array[CutsceneSpeaker] = []
## Which script to play when there's no outcome to read, as when testing the
## scene by itself.
@export_enum("H", "N", "D") var preview_outcome := "H"
## Typewriter speed. 0 puts every line up at once.
@export var chars_per_second := 40.0

## "H", "N" or "D": the script being played.
var outcome_code := ""

var _panels: Array[ComicPanel] = []
var _lines: Array[Dictionary] = []
var _index := -1
var _leaving := false

@onready var _prompt: Label = %Prompt


func _ready() -> void:
	for node in find_children("*", "ComicPanel", true, false):
		_panels.append(node as ComicPanel)
		node.typed.connect(_on_typed)
	for panel in _panels:
		panel.clear()
	_prompt.hide()

	var router := get_node_or_null(^"/root/SceneRouter")
	outcome_code = router.cutscene_outcome if router and router.cutscene_outcome != "" else preview_outcome
	_lines = parse(script_for(outcome_code))
	if _panels.is_empty() or _lines.is_empty():
		push_warning("Cutscene: nothing to show for outcome '%s'." % outcome_code)
		_finish.call_deferred()
		return
	# The page lays its panels out during the first frame; bubbles are sized to
	# fit only once that's done.
	await get_tree().process_frame
	_next_line()


func script_for(code: String) -> String:
	match code:
		"H":
			return hero_script
		"D":
			return dark_script
		_:
			return neutral_script


## Script text to lines: {"speaker": "Hero", "text": "..."}, with an empty
## speaker for a caption.
static func parse(text: String) -> Array[Dictionary]:
	var spoken := RegEx.create_from_string('^(.+?),\\s*"(.*)"$')
	var out: Array[Dictionary] = []
	for raw in text.split("\n"):
		var line := raw.strip_edges().trim_prefix("*").strip_edges()
		if line == "":
			continue
		var found := spoken.search(line)
		if found:
			out.append({"speaker": found.get_string(1).strip_edges(), "text": found.get_string(2)})
		else:
			out.append({"speaker": "", "text": line})
	return out


func speaker_named(who: String) -> CutsceneSpeaker:
	for speaker in speakers:
		if speaker and speaker.name.to_lower() == who.to_lower():
			return speaker
	return null


## Ends the cutscene now, whatever line it's on.
func skip() -> void:
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or event.is_echo():
		return
	for action in ADVANCE_ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_advance()
			return


func _advance() -> void:
	if _index < 0:
		return
	var panel := _current_panel()
	if panel.is_typing():
		panel.finish_typing()
	elif _index >= _lines.size() - 1:
		_finish()
	else:
		_next_line()


func _next_line() -> void:
	_index += 1
	_prompt.hide()
	# A full page turns over to a fresh one.
	if _index > 0 and _index % _panels.size() == 0:
		for panel in _panels:
			panel.clear()
	var line := _lines[_index]
	var who: String = line["speaker"]
	if who == "":
		_current_panel().show_caption(line["text"], chars_per_second)
	else:
		_current_panel().show_line(who, line["text"], speaker_named(who), chars_per_second)


func _current_panel() -> ComicPanel:
	return _panels[_index % _panels.size()]


func _on_typed() -> void:
	_prompt.text = "CONTINUE >" if _index >= _lines.size() - 1 else "NEXT >"
	_prompt.show()


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	finished.emit()
	var router := get_node_or_null(^"/root/SceneRouter")
	if router:
		router.finish_cutscene()
