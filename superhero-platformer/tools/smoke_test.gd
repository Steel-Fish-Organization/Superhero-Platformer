extends Node
## Non-visual checks for progression, weapons and the save files.
##
##     godot --headless --path . tools/smoke_test.tscn
##
## Run as the main scene (not --script) so the autoloads exist. Exits non-zero
## if anything fails, so it drops straight into CI if you want it there.

var _failures: int = 0


func _ready() -> void:
	print("=== smoke test ===")

	_check("weapon library loaded", GameState.all_weapon_ids().size() >= 5)
	_check("default weapon equipped",
		GameState.current_weapon() != null and GameState.current_weapon().id == WeaponLibrary.DEFAULT_WEAPON_ID)
	_check("default weapon has 3 charge stages", GameState.current_weapon().stage_count() == 3)
	_check("charge tiers ordered",
		GameState.current_weapon().stage_for_charge(0.0) == 0
		and GameState.current_weapon().stage_for_charge(0.6) == 1
		and GameState.current_weapon().stage_for_charge(1.5) == 2)

	_check("final stage starts locked", not GameState.is_stage_unlocked(GameState.FINAL_STAGE_ID))
	_check("stage 1 starts unlocked", GameState.is_stage_unlocked(&"stage_01"))

	# every stage referenced by the select screen must actually exist
	for i in 9:
		var info := StageLibrary.at_grid(i)
		_check("scene exists: %s" % info["id"], ResourceLoader.exists(StageLibrary.scene_path(info["id"])))

	# clearing the eight main stages must unlock the ninth
	for id in GameState.STAGE_IDS:
		if id != GameState.FINAL_STAGE_ID:
			GameState.complete_stage(id, WeaponLibrary.reward_for(id))
	_check("cleared count is 8", GameState.cleared_count() == 8)
	_check("final stage unlocks after 8 clears", GameState.is_stage_unlocked(GameState.FINAL_STAGE_ID))
	_check("stage rewards granted", GameState.unlocked_weapons.size() == 5)

	# save -> wipe -> load round trip
	GameState.current_slot = 2
	GameState.e_tanks = 3
	GameState.lives = 7
	GameState.save_progress()
	var summary := SaveSystem.slot_summary(2)
	_check("summary reports 8 cleared", int(summary.get("stages_cleared", 0)) == 8)

	GameState.reset_run()
	_check("reset clears progress", GameState.cleared_count() == 0)

	GameState.from_dict(SaveSystem.read_slot(2))
	_check("load restores stages", GameState.cleared_count() == 8)
	_check("load restores weapons", GameState.unlocked_weapons.size() == 5)
	_check("load restores tanks", GameState.e_tanks == 3)
	_check("load restores lives", GameState.lives == 7)

	SaveSystem.erase_slot(2)
	_check("erase removes the file", not SaveSystem.slot_exists(2))

	# weapon energy accounting
	var metered := GameState.get_weapon(&"lance_beam")
	_check("reward weapon is metered", metered != null and metered.is_metered())
	GameState.unlock_weapon(&"lance_beam")
	GameState.weapon_energy[&"lance_beam"] = 5.0
	_check("can spend within energy", GameState.can_spend_energy(metered, 3.0))
	_check("cannot overspend energy", not GameState.can_spend_energy(metered, 9.0))

	print("=== %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("  ok   ", label)
	else:
		printerr("  FAIL ", label)
		_failures += 1
