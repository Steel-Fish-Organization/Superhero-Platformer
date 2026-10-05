extends Node
## What survives leaving a stage: who you rescued, the letters they carried, and
## the upgrades those earned you. Autoloaded as `GameState`.
##
## Saved as plain JSON in `user://` so it's easy to read while developing. On
## Windows that's %APPDATA%/Godot/app_userdata/Superhero Platformer/progress.json.
##
## Replaying a stage can only ever improve your record -- a worse run doesn't
## take anything away, so going back for someone you missed is never a risk.

signal rescues_changed(stage_id: StringName)
## A stage was finished and counted as hero, neutral or dark.
signal stage_finished(stage_id: StringName, code: String)
signal upgrade_unlocked(upgrade: Upgrade)
signal word_completed(word: String)
## Progress was wiped -- anything holding earned state should rebuild from here.
signal progress_reset

const DEFAULT_SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 1
## Where progress is written. A var rather than a const so tests (and, later, a
## file-select screen) can point it somewhere else.
var save_path := DEFAULT_SAVE_PATH
## The letters hidden across the stages, one each, spell this.
const WORD := "GUARDIAN"
## The upgrade handed over when the word is complete, if it exists.
const WORD_REWARD_ID := &"word_reward"

const UPGRADE_DIR := "res://src/rescue/upgrades"
## The shape of the game: which stage follows which, per outcome.
const GRAPH_PATH := "res://src/core/stage_graph.tres"

## stage_id -> {"saved": int, "total": int, "lost": int}
var stages: Dictionary = {}
## Letters collected so far, in the order they were found.
var letters: Array[String] = []
## stage_id -> "H" / "N" / "D", the way that stage was LAST finished. The latest
## run owns the branch, unlike `stages` below, which keeps your best rescue
## count: a player who first cleared a stage as a hero has to be able to go back
## and take the dark route afterwards.
var outcomes: Dictionary = {}
## Every stage finish this run, in order: ["H", "N", "N", "D"]. The ending reads
## this once endings exist (M4).
var path_history: Array[String] = []
## How the stage you're in now was reached: the outcome of the stage before it.
## Levels read this to decide which population to spawn. Empty on the first
## stage of a run, or when a level is played on its own.
var arrived_as := ""
## Upgrade ids earned. The resources themselves live in `library`.
var unlocked: Array[StringName] = []
## id -> Upgrade, every upgrade resource on disk.
var library: Dictionary = {}
## The stage graph, loaded once at startup.
var graph: StageGraph
## The stage being played, for reloads and for the next lookup.
var current_stage_id: StringName = &""


func _ready() -> void:
	_load_library()
	graph = load(GRAPH_PATH) as StageGraph
	if graph == null:
		push_warning("GameState: no stage graph at %s; stages won't link up." % GRAPH_PATH)
	load_game()


## Dev keys, debug builds only, so they can't reach a player:
##   F1  grant every upgrade        F2  wipe progress
##   F3  save now                   F4  list what you have in the console
##   F6 / F7 / F8  replay this stage as if you'd arrived on the hero / neutral /
##                 dark path, which is how you see M3's populations without
##                 playing a whole run to get here
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_F1:
			grant_all()
			print("[GameState] granted every upgrade: ", unlocked)
		KEY_F2:
			reset(true)
			print("[GameState] progress wiped")
		KEY_F3:
			print("[GameState] saved: ", save_game(), " -> ", save_path)
		KEY_F4:
			print("[GameState] upgrades=", unlocked, " letters=", word_progress(),
				" stages=", stages, " arrived_as='", arrived_as, "'")
		KEY_F6:
			_replay_as("H")
		KEY_F7:
			_replay_as("N")
		KEY_F8:
			_replay_as("D")


## Reloads the stage you're in as though you'd walked in off that path.
func _replay_as(code: String) -> void:
	arrived_as = code
	var router := get_node_or_null(^"/root/SceneRouter")
	var stage := current_stage_id if current_stage_id != &"" else (graph.first_stage if graph else &"")
	print("[GameState] replaying %s as a %s arrival" % [stage, code])
	if router and stage != &"":
		router.goto_stage(stage)


## Every upgrade on disk at once, for testing.
func grant_all() -> void:
	for id in library:
		unlock(library[id])


func _load_library() -> void:
	var dir := DirAccess.open(UPGRADE_DIR)
	if dir == null:
		push_warning("GameState: no upgrade folder at %s" % UPGRADE_DIR)
		return
	for file in dir.get_files():
		# Exported projects serve .tres as .remap, so strip that first.
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var upgrade := load("%s/%s" % [UPGRADE_DIR, name]) as Upgrade
		if upgrade and upgrade.id != &"":
			library[upgrade.id] = upgrade


# ---------------------------------------------------------------------------
# rescues
# ---------------------------------------------------------------------------
## Records how a stage went. Only improvements are kept.
func record_stage(stage_id: StringName, saved: int, total: int, lost: int) -> void:
	var best: Dictionary = stages.get(stage_id, {"saved": 0, "total": 0, "lost": 0})
	stages[stage_id] = {
		"saved": maxi(int(best["saved"]), saved),
		"total": maxi(int(best["total"]), total),
		"lost": lost if saved >= int(best["saved"]) else int(best["lost"]),
	}
	rescues_changed.emit(stage_id)


func stage_record(stage_id: StringName) -> Dictionary:
	return stages.get(stage_id, {"saved": 0, "total": 0, "lost": 0})


## Settles how a stage was finished. Always overwrites: the most recent run is
## the one the stage graph follows.
func record_outcome(stage_id: StringName, code: String) -> void:
	outcomes[stage_id] = code
	path_history.append(code)
	# Whatever you did here is how you'll arrive wherever you go next.
	arrived_as = code
	stage_finished.emit(stage_id, code)


## "H", "N", "D", or "" for a stage that has never been finished.
func outcome_of(stage_id: StringName) -> String:
	return outcomes.get(stage_id, "")


## Where an outcome leads. Empty when the run ends here.
func next_stage_after(stage_id: StringName, code: String) -> StringName:
	return graph.next_stage(stage_id, code) if graph else &""


## Everyone saved, across every stage played so far.
func total_saved() -> int:
	var sum := 0
	for record in stages.values():
		sum += int(record["saved"])
	return sum


func collect_letter(letter: String) -> void:
	if letter == "" or letters.has(letter):
		return
	letters.append(letter)
	if is_word_complete():
		word_completed.emit(WORD)
		if library.has(WORD_REWARD_ID):
			unlock(library[WORD_REWARD_ID])


## The word so far, with blanks for what's still missing: "G_A___A_".
func word_progress() -> String:
	var out := ""
	for i in WORD.length():
		var letter := WORD[i]
		out += letter if letters.has(letter) else "_"
	return out


func is_word_complete() -> bool:
	for i in WORD.length():
		if not letters.has(WORD[i]):
			return false
	return true


# ---------------------------------------------------------------------------
# upgrades
# ---------------------------------------------------------------------------
## Returns false if it was already earned, so callers can skip the fanfare.
func unlock(upgrade: Upgrade) -> bool:
	if upgrade == null or upgrade.id == &"" or unlocked.has(upgrade.id):
		return false
	unlocked.append(upgrade.id)
	library[upgrade.id] = upgrade
	upgrade_unlocked.emit(upgrade)
	return true


func has_upgrade(id: StringName) -> bool:
	return unlocked.has(id)


## The earned upgrades, in the order they were earned.
func unlocked_upgrades() -> Array[Upgrade]:
	var out: Array[Upgrade] = []
	for id in unlocked:
		if library.has(id):
			out.append(library[id])
	return out


# ---------------------------------------------------------------------------
# saving
# ---------------------------------------------------------------------------
func save_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("GameState: can't write %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"stages": stages,
		"outcomes": outcomes,
		"path_history": path_history,
		"arrived_as": arrived_as,
		"current_stage": String(current_stage_id),
		"letters": letters,
		"unlocked": unlocked.map(func(id: StringName) -> String: return String(id)),
	}, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: %s is corrupt; starting fresh." % save_path)
		return false

	var data: Dictionary = parsed
	stages = {}
	for key in data.get("stages", {}):
		var record: Dictionary = data["stages"][key]
		stages[StringName(key)] = {
			"saved": int(record.get("saved", 0)),
			"total": int(record.get("total", 0)),
			"lost": int(record.get("lost", 0)),
		}
	outcomes = {}
	for key in data.get("outcomes", {}):
		outcomes[StringName(key)] = String(data["outcomes"][key])
	path_history.assign(data.get("path_history", []))
	arrived_as = String(data.get("arrived_as", ""))
	current_stage_id = StringName(data.get("current_stage", ""))
	letters.assign(data.get("letters", []))
	unlocked.clear()
	for id in data.get("unlocked", []):
		unlocked.append(StringName(id))
	return true


## Wipes progress, in memory and on disk. Handy while testing.
func reset(erase_file := false) -> void:
	stages.clear()
	outcomes.clear()
	path_history.clear()
	arrived_as = ""
	letters.clear()
	unlocked.clear()
	if erase_file and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	progress_reset.emit()
