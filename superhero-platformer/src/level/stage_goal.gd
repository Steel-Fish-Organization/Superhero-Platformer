@tool
extends Area2D
## The way out. Touching it ends the stage and settles how the run counted:
## hero, neutral or dark, read off the RescueTracker's numbers.
##
## In M1 that's where it stops -- the outcome is recorded and shown, and the hero
## is held in place. Once the stage graph exists (M2), this is also what asks it
## where to go next. See docs/three-paths.md.

## The outcome is settled; the HUD shows it, and the router acts on it.
signal stage_finished(code: String, outcome_name: String)

const TRIGGER_LAYER := 64     # physics layer 7
const PLAYER_LAYER := 2

## Freeze the hero on arrival, so they can't wander back in and keep playing a
## stage that has already been counted.
@export var hold_player := true
## Travel to the next stage by itself. Off for a stage you're testing on its own,
## and off in the test suites, which check where it *would* go.
@export var auto_advance := true
## How long the result stays on screen before the next stage loads.
@export var result_time := 2.0
## A Cutscene played after the result and before the next stage. It picks its
## hero / neutral / dark script from how the stage was finished. Leave empty to
## go straight on.
@export_file("*.tscn") var outro := ""

var finished := false
var outcome_code := ""
## Where this outcome leads, from the stage graph. Empty ends the run.
var next_stage_id: StringName = &""

var _pulse := 0.0


func _ready() -> void:
	add_to_group(&"stage_goal")
	collision_layer = TRIGGER_LAYER
	collision_mask = PLAYER_LAYER
	monitorable = false
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if finished or not body.is_in_group(&"player"):
		return
	_finish(body)


func _finish(player: Node) -> void:
	finished = true
	var tracker := get_tree().get_first_node_in_group(&"rescue_tracker")
	var name_of := "NEUTRAL"
	if tracker:
		outcome_code = tracker.outcome_code()
		name_of = tracker.outcome_name()
	else:
		outcome_code = "N"
		push_warning("StageGoal: no RescueTracker in this level; counting the run as neutral.")

	var state := get_node_or_null(^"/root/GameState")
	if state and tracker:
		state.record_outcome(tracker.stage_id, outcome_code)
		next_stage_id = state.next_stage_after(tracker.stage_id, outcome_code)

	if hold_player and player:
		player.set(&"frozen", true)
	stage_finished.emit(outcome_code, name_of)

	if auto_advance and (next_stage_id != &"" or outro != ""):
		_travel.call_deferred()


## Holds the result on screen for a moment, then hands over to the router: the
## outro first if there is one, which goes on to the next stage when it's done.
## The hero is already frozen, so the pause reads as the stage ending rather
## than as the game hanging.
func _travel() -> void:
	var router := get_node_or_null(^"/root/SceneRouter")
	if router == null:
		push_warning("StageGoal: no SceneRouter, so '%s' can't be loaded." % next_stage_id)
		return
	await get_tree().create_timer(result_time).timeout
	if not is_instance_valid(self):
		return
	if outro != "":
		router.play_cutscene(outro, outcome_code, next_stage_id)
	else:
		router.goto_stage(next_stage_id)


func _draw() -> void:
	# A lit doorway: two posts and a lintel, with the light inside breathing.
	var glow := 0.55 + 0.2 * sin(_pulse * 2.4)
	draw_rect(Rect2(-10.0, -34.0, 20.0, 34.0), Color(0.35, 0.95, 1.0, glow * 0.35), true)
	draw_rect(Rect2(-11.0, -36.0, 22.0, 3.0), Color(0.8, 0.9, 1.0), true)
	draw_rect(Rect2(-11.0, -34.0, 3.0, 34.0), Color(0.8, 0.9, 1.0), true)
	draw_rect(Rect2(8.0, -34.0, 3.0, 34.0), Color(0.8, 0.9, 1.0), true)
