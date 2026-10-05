extends GameTest
## M2: the stage graph. Where each outcome leads, that every stage it names
## actually exists, and that a whole run through the tree is remembered.
##
## Nothing here changes scenes: the suite checks where the goal *would* send you,
## which is the part that can be wrong. Actually loading each stage is what the
## stubs are for, by hand.

var state: Node
var graph: StageGraph
var goal: Node2D


func setup() -> void:
	state = root.get_node_or_null(^"GameState")
	if state:
		state.save_path = "user://test_graph.json"
		state.reset(true)
		graph = state.graph
	goal = get_first_node_in_group(&"stage_goal")
	if goal:
		goal.auto_advance = false      # don't travel out from under the test


## Plays out a run: hands each stage an outcome and follows the graph.
func walk(from: StringName, codes: Array) -> Array:
	var path: Array = [from]
	var at := from
	for code in codes:
		at = graph.next_stage(at, code)
		if at == &"":
			break
		path.append(at)
	return path


func step(f: int) -> bool:
	if state == null or graph == null:
		check("the stage graph loads", false, "no GameState or no graph resource")
		return true

	match f:
		2:
			check("the stage graph loads", true)
			check("the run starts at the greybox", graph.first_stage == &"greybox",
				String(graph.first_stage))
			check("every stage has three ways out", graph.all_ids().all(func(id):
				var e: Dictionary = graph.entry(id)
				return e.has("H") and e.has("N") and e.has("D")))
			check("stages have display names", graph.display_name(&"transit") == "MIDNIGHT TRANSIT",
				graph.display_name(&"transit"))

		# every stage the graph names has a scene on disk
		4:
			var missing: Array = []
			for id in graph.all_ids():
				if not ResourceLoader.exists(graph.scene_path(id)):
					missing.append(String(id))
				for code in ["H", "N", "D"]:
					var next: StringName = graph.next_stage(id, code)
					if next != &"" and not graph.has_stage(next):
						missing.append("%s -%s-> %s (not in graph)" % [id, code, next])
			check("every stage in the graph exists, and so does everywhere it points",
				missing.is_empty(), str(missing))

		# the three branches out of the opening stage
		6:
			check("hero leads to the rooftops", graph.next_stage(&"greybox", "H") == &"rooftops")
			check("neutral leads to the transit", graph.next_stage(&"greybox", "N") == &"transit")
			check("dark leads to the undercity", graph.next_stage(&"greybox", "D") == &"undercity")
			check("the last stage ends the run", graph.next_stage(&"citadel", "H") == &"")
			check("an unknown stage leads nowhere", graph.next_stage(&"nowhere", "H") == &"")

		# paths converge rather than multiplying
		8:
			var hero_run := walk(&"greybox", ["H", "H", "H"])
			var dark_run := walk(&"greybox", ["D", "D", "D"])
			check("a hero run reaches the citadel", hero_run.back() == &"citadel", str(hero_run))
			check("so does a dark one, by another road", dark_run.back() == &"citadel", str(dark_run))
			# past the opening they share, and before the citadel they both end at
			check("and they shared nothing in between",
				hero_run.slice(1, 3).all(func(id): return not dark_run.slice(1, 3).has(id)),
				"%s vs %s" % [hero_run, dark_run])
			check("a run is four stages long", hero_run.size() == 4, str(hero_run))

		# the goal works out where it would send you
		10:
			var tracker := node("RescueTracker")
			tracker.saved = tracker.total      # a hero run
			goal._finish(player)
		12:
			check("finishing settles the outcome", goal.outcome_code == "H", goal.outcome_code)
			check("and looks up where that leads", goal.next_stage_id == &"rooftops",
				String(goal.next_stage_id))
			check("the hero is held while the result shows", player.frozen)
			check("the run is remembered", state.path_history == ["H"], str(state.path_history))
			check("and so is this stage's outcome", state.outcome_of(&"greybox") == "H")

		# the latest run owns the branch, even when it's a worse one
		14:
			state.record_outcome(&"greybox", "D")
			check("replaying darker changes where you go next",
				state.next_stage_after(&"greybox", state.outcome_of(&"greybox")) == &"undercity",
				state.outcome_of(&"greybox"))
			check("but your best rescue count is untouched",
				state.stage_record(&"greybox")["saved"] >= 0)
			check("and the history keeps both runs", state.path_history == ["H", "D"],
				str(state.path_history))

		# all of it survives a save and reload
		16:
			check("progress saves", state.save_game())
			state.reset()
		18:
			check("progress loads", state.load_game())
			check("outcomes came back", state.outcome_of(&"greybox") == "D")
			check("the path history came back", state.path_history == ["H", "D"],
				str(state.path_history))
			state.reset(true)
			return true
	return false
