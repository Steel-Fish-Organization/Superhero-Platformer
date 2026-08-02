extends Node
## Three-slot file save/load. Autoloaded as `SaveSystem`.
##
## Files live in `user://` as plain JSON so they are easy to inspect while
## developing. On Windows that is %APPDATA%/Godot/app_userdata/Superhero Platformer.

const SLOT_COUNT := 3
const SAVE_VERSION := 1
const PATH_TEMPLATE := "user://file_%d.json"

signal slot_written(slot: int)
signal slot_erased(slot: int)


func slot_path(slot: int) -> String:
	return PATH_TEMPLATE % slot


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func write_slot(slot: int, payload: Dictionary) -> bool:
	var data := payload.duplicate(true)
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save slot %d: %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	slot_written.emit(slot)
	return true


func read_slot(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		push_error("Could not read save slot %d" % slot)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save slot %d is corrupt; ignoring." % slot)
		return {}
	return _migrate(parsed)


func erase_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))
	slot_erased.emit(slot)


## Compact info for the file-select screen without loading a whole run.
func slot_summary(slot: int) -> Dictionary:
	var data := read_slot(slot)
	if data.is_empty():
		return {"empty": true, "slot": slot}
	var completed: Array = data.get("stages_completed", [])
	var main_cleared := 0
	for id in completed:
		if String(id) != String(GameState.FINAL_STAGE_ID):
			main_cleared += 1
	return {
		"empty": false,
		"slot": slot,
		"stages_cleared": main_cleared,
		"weapons": (data.get("unlocked_weapons", []) as Array).size(),
		"lives": int(data.get("lives", 2)),
		"playtime": float(data.get("playtime", 0.0)),
		"beaten": bool(data.get("game_beaten", false)),
	}


func all_summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in SLOT_COUNT:
		out.append(slot_summary(i))
	return out


func format_playtime(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _migrate(data: Dictionary) -> Dictionary:
	## Bump SAVE_VERSION and patch old files here when the format changes.
	var version := int(data.get("version", 0))
	if version < SAVE_VERSION:
		data["version"] = SAVE_VERSION
	return data
