extends GameTest
## M1: a run through the stage ends hero, neutral or dark.
##
## Three runs, one per outcome, each ending at the stage goal. Also checks the
## two rules that make the choice readable: the hero line dies with the first
## casualty, and the hero cannot hurt a civilian however hard they try.

const FLOOR_Y := 432.0

var state: Node
var tracker: Node
var goal: Node2D
var finished: Array = []
var before := 0


func setup() -> void:
	state = root.get_node_or_null(^"GameState")
	if state:
		state.save_path = "user://test_outcomes.json"
		state.reset(true)
	tracker = node("RescueTracker")
	goal = get_first_node_in_group(&"stage_goal")
	goal.stage_finished.connect(func(code: String, name_of: String) -> void:
		finished = [code, name_of])


## Walks up to someone and presses interact over two frames.
func rescue(civilian: Node2D) -> void:
	player.global_position = civilian.global_position + Vector2(-10.0, 0.0)
	player.velocity = Vector2.ZERO
	player.respawned.emit()


## Starts the stage over without reloading it: everyone back, counters cleared.
func restage() -> void:
	for c in get_nodes_in_group(&"civilians"):
		c.state = c.State.TRAPPED
		c.cause = c.Cause.NONE
		c.health = c.max_health
		c.time_left = c.danger_time
		c._seen = false
		c.show()
		c.modulate.a = 1.0
	tracker.saved = 0
	tracker.lost = 0
	goal.finished = false
	player.frozen = false
	finished = []


func step(f: int) -> bool:
	var dex: Node2D = node("Civilian1")
	var ada: Node2D = node("Civilian2")
	var juno: Node2D = node("Civilian3")

	match f:
		2:
			check("the stage has a goal to reach", goal != null)
			check("three people in it", tracker.total == 3, "total=%d" % tracker.total)
			check("dark needs half of them", tracker.deaths_for_dark() == 2,
				"needs %d" % tracker.deaths_for_dark())
			check("every route is still open",
				tracker.hero_possible() and tracker.neutral_possible() and tracker.dark_possible())
			check("and nothing is settled yet", tracker.outcome_code() == "N")

		# ---- neutral: walk past everyone and leave --------------------------
		5:
			# clear of the turret's pedestal, which sits four tiles back
			place(goal.global_position + Vector2(-20.0, 0.0))
			press(&"move_right")
		45:
			release(&"move_right")
			check("walking out having helped nobody is neutral", finished == ["N", "NEUTRAL"], str(finished))
			check("nobody died on the way", tracker.lost == 0)
			check("the hero is held at the exit", player.frozen)
			check("the outcome is written down", state.outcome_of(&"greybox") == "N",
				state.outcome_of(&"greybox"))

		# ---- hero: everyone out, then leave ---------------------------------
		50:
			restage()
			rescue(dex)
		53:
			press(&"interact")
		54:
			release(&"interact")
		56:
			rescue(ada)
		59:
			press(&"interact")
		60:
			release(&"interact")
		62:
			rescue(juno)
		65:
			press(&"interact")
		66:
			release(&"interact")
		68:
			check("all three saved", tracker.saved == 3, "saved=%d" % tracker.saved)
			check("that reads as hero before you even leave", tracker.outcome_code() == "H")
			check("neutral is out of reach now", not tracker.neutral_possible())
			place(goal.global_position + Vector2(-20.0, 0.0))
			press(&"move_right")
		95:
			release(&"move_right")
			check("leaving with everyone alive is a hero run", finished == ["H", "HERO"], str(finished))
			check("and that's what gets saved", state.outcome_of(&"greybox") == "H")
			check("the path history grows", state.path_history == ["N", "H"], str(state.path_history))

		# ---- dark: let them die ---------------------------------------------
		100:
			restage()
			check("restaged clean", tracker.saved == 0 and tracker.lost == 0)
			# two clocks run out: nobody came
			dex._die(dex.Cause.CLOCK)
			juno._die(juno.Cause.CLOCK)
		102:
			check("two dead is dark", tracker.outcome_code() == "D", tracker.outcome_name())
			check("the hero route is gone", not tracker.hero_possible())
			check("so is neutral", not tracker.neutral_possible())
			place(goal.global_position + Vector2(-20.0, 0.0))
			press(&"move_right")
		130:
			release(&"move_right")
			check("leaving with half the stage dead is a dark run", finished == ["D", "DARK"], str(finished))
			check("recorded over the hero run", state.outcome_of(&"greybox") == "D")

		# ---- one death ends the hero route, but not the run ----------------
		135:
			restage()
			dex._die(dex.Cause.CLOCK)
		137:
			check("one death rules out hero", not tracker.hero_possible())
			check("but neutral is still live", tracker.neutral_possible())
			check("and the run counts as neutral so far", tracker.outcome_code() == "N")

		# ---- the hero cannot hurt a bystander ------------------------------
		145:
			restage()
			place(ada.global_position + Vector2(-40.0, 0.0))
			player.facing = 1
			before = ada.health
		147:
			player._fire_cooldown = 0.0
			press(&"fire")
		148:
			release(&"fire")
		165:
			check("your own shots can't hurt a civilian", ada.health == before,
				"%d -> %d" % [before, ada.health])
			check("so they're still there to rescue", ada.state == ada.State.TRAPPED)
		# but enemy fire can
		170:
			var shot: Node = load("res://src/projectiles/enemy_shot.tscn").instantiate()
			level.add_child(shot)
			shot.launch(ada.global_position + Vector2(-30.0, -8.0), Vector2.RIGHT)
		185:
			check("enemy fire does hurt them", ada.health < before, "%d -> %d" % [before, ada.health])
		187:
			ada.take_damage(99)
		189:
			check("and can kill them", ada.state == ada.State.LOST)
			check("counted as caught in the fighting, not the clock",
				ada.cause == ada.Cause.CAUGHT_IN_FIRE, "cause=%d" % ada.cause)
			check("the tracker counts them among the dead", tracker.lost >= 1)
			state.reset(true)
			return true
	return false
