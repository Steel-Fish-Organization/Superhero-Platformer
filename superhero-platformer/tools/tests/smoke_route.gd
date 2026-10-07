extends SceneTree
## Walks a whole run through the graph for real: loads the opening stage with the
## router, finishes each stage with a chosen outcome, and lets it travel. The
## test suites deliberately never change scenes, so this is the one that proves
## the router, the stubs and the graph work together.
##
##     godot --headless --fixed-fps 60 --path . --script tools/tests/smoke_route.gd

const OUTCOMES := ["H", "N", "D"]      # hero out of the greybox, then neutral, then dark

var state: Node
var router: Node
var frame := 0
var visited: Array[String] = []
var outros_seen: Array[String] = []
var acted_in := ""
var failures := 0


func _initialize() -> void:
	state = root.get_node_or_null(^"GameState")
	router = root.get_node_or_null(^"SceneRouter")
	if state:
		state.save_path = "user://smoke_route.json"
		state.reset(true)


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		# Autoloads have not run _ready during _initialize, so the graph is only
		# there from the first frame onwards.
		router.goto_stage(state.graph.first_stage)
		return false
	if frame < 40 or router == null or router.is_busy():
		return frame > 1200

	var level := current_scene
	if level == null:
		return frame > 600
	# An outro between stages: note it and click straight through.
	if level is Cutscene:
		print("  outro after %s (%s)" % [state.current_stage_id, level.outcome_code])
		outros_seen.append(String(state.current_stage_id))
		level.skip()
		return false
	var stage := String(state.current_stage_id)
	if not visited.has(stage):
		visited.append(stage)
		print("  arrived in %s (%s)" % [stage, state.graph.display_name(state.current_stage_id)])
		acted_in = ""

	# finish this stage with the next outcome in the list
	if acted_in != stage:
		acted_in = stage
		var tracker := level.get_node_or_null(^"RescueTracker")
		var goal := level.get_node_or_null(^"StageGoal") as Node2D
		if goal == null:
			for child in level.get_children():
				if child.is_in_group(&"stage_goal"):
					goal = child
					break
		if tracker == null or goal == null:
			print("  FAIL  %s is missing a tracker or a goal" % stage)
			failures += 1
			return true
		var code: String = OUTCOMES[mini(visited.size() - 1, OUTCOMES.size() - 1)]
		match code:
			"H":
				tracker.saved = tracker.total
			"D":
				tracker.lost = tracker.deaths_for_dark()
		goal.result_time = 0.1
		goal._finish(level.get_node_or_null(^"Player"))

	if state.graph.next_stage(state.current_stage_id, state.outcome_of(state.current_stage_id)) == &"":
		print("\nroute walked: %s" % " -> ".join(visited))
		print("path history: %s" % str(state.path_history))
		var want := ["greybox", "rooftops", "sky_spire", "citadel"]
		var ok: bool = visited == want
		print(("PASS  " if ok else "FAIL  ") + "a real run travels the graph   [wanted %s]" % str(want))
		if not ok:
			failures += 1
		var want_outros := ["greybox"]      # the only stage with an outro so far
		ok = outros_seen == want_outros
		print(("PASS  " if ok else "FAIL  ") + "outros play between stages   [saw %s, wanted %s]" % [str(outros_seen), str(want_outros)])
		if not ok:
			failures += 1
		state.reset(true)
		print("\n%d failure(s)" % failures)
		return true
	return false
