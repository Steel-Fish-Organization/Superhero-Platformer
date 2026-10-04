extends GameTest
## What carries over: the save file, the letters, and the upgrades rescues earn.
##
## Writes to a scratch save file, never the real one.

const TEST_SAVE := "user://test_progress.json"

var state: Node
var banner := ""
var base_charge := 0.0
var base_health := 0


func setup() -> void:
	state = root.get_node_or_null(^"GameState")
	if state:
		state.save_path = TEST_SAVE
	base_charge = player.charge_rate
	base_health = player.max_health


func step(f: int) -> bool:
	if state == null:
		check("GameState autoload is present", false, "no /root/GameState -- is the autoload registered?")
		return true

	match f:
		2:
			state.reset(true)
			state.upgrade_unlocked.connect(func(upgrade: Upgrade) -> void: banner = String(upgrade.id))
			check("GameState autoload is present", true)
			check("the upgrade library loaded from disk", state.library.has(&"charge_coil"),
				str(state.library.keys()))
			check("nothing earned yet", state.unlocked.is_empty() and state.letters.is_empty())

		# ---- rescuing a named survivor pays out --------------------------
		5:
			var ada: Node2D = node("Civilian2")
			player.global_position = ada.global_position + Vector2(-10.0, 0.0)
			player.respawned.emit()
		8:
			press(&"interact")
		9:
			release(&"interact")
		12:
			check("rescuing Ada unlocks her upgrade", state.has_upgrade(&"charge_coil"), str(state.unlocked))
			check("the upgrade is announced", banner == "charge_coil", banner)
			check("her letter is kept", state.letters.has("G"), str(state.letters))
			check("the stage record is written",
				state.stage_record(&"greybox")["saved"] == 1, str(state.stage_record(&"greybox")))
		14:
			check("the hero actually charges faster now",
				player.charge_rate > base_charge, "%.2f -> %.2f" % [base_charge, player.charge_rate])

		# ---- the word, and its reward -------------------------------------
		20:
			check("the word shows what's missing", state.word_progress() == "G_______", state.word_progress())
			check("and isn't finished", not state.is_word_complete())
			for letter in "UARDIAN":
				state.collect_letter(letter)
		22:
			check("collecting every letter completes the word", state.is_word_complete())
			check("which pays out the word reward", state.has_upgrade(&"word_reward"), str(state.unlocked))
			check("and that upgrade reaches the hero too",
				is_equal_approx(player.invuln_time, 1.8), "invuln=%.2f" % player.invuln_time)

		# ---- upgrades don't stack on themselves --------------------------
		24:
			player.apply_upgrades()
			player.apply_upgrades()
			check("applying upgrades twice changes nothing",
				is_equal_approx(player.charge_rate, 1.6), "charge_rate=%.2f" % player.charge_rate)

		# ---- saving and loading -------------------------------------------
		26:
			check("saving writes the file", state.save_game() and FileAccess.file_exists(TEST_SAVE))
			state.reset()
			check("reset clears memory", state.unlocked.is_empty() and state.letters.is_empty())
		28:
			check("loading brings it all back", state.load_game())
			check("upgrades survived", state.has_upgrade(&"charge_coil") and state.has_upgrade(&"word_reward"),
				str(state.unlocked))
			# GUARDIAN repeats its A, so the set of distinct letters is 7
			check("letters survived", state.letters.size() == 7, str(state.letters))
			check("stage records survived", state.stage_record(&"greybox")["saved"] >= 1,
				str(state.stage_record(&"greybox")))

		# ---- replaying a stage can only improve the record ----------------
		30:
			state.record_stage(&"greybox", 3, 3, 0)
			state.record_stage(&"greybox", 1, 3, 2)     # a worse run afterwards
			check("a worse replay doesn't take anything away",
				state.stage_record(&"greybox")["saved"] == 3, str(state.stage_record(&"greybox")))
			check("totals add up across stages", state.total_saved() == 3, "%d" % state.total_saved())

		# ---- clean sweep ---------------------------------------------------
		32:
			state.reset(true)
			var tracker := node("RescueTracker")
			tracker.saved = tracker.total - 1
			tracker.lost = 0
			tracker._on_rescued(node("Civilian1"))
			check("saving everyone earns the clean sweep",
				state.has_upgrade(&"field_medic"), str(state.unlocked))
		34:
			check("which widens the health bar",
				player.max_health > base_health, "%d -> %d" % [base_health, player.max_health])
			state.reset(true)
			return true
	return false
