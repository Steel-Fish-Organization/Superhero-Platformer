extends Node
## Runtime + persistent game state. Autoloaded as `GameState`.
##
## Holds everything the HUD, stage select and save file need to know. Levels and
## UI talk to this instead of to each other, so a stage can be run straight from
## the editor (F6) without the menus having set anything up.

signal health_changed(current: int, maximum: int)
signal lives_changed(lives: int)
signal weapon_changed(weapon: WeaponData)
signal weapon_energy_changed(weapon_id: StringName, current: float, maximum: float)
signal tanks_changed(e_tanks: int, w_tanks: int)
signal stage_cleared(stage_id: StringName)

const MAX_HEALTH := 28              # Mega Man's 28-unit health bar
const STARTING_LIVES := 2
const MAX_TANKS := 4

## Stage ids in stage-select grid order. Index 8 is the hidden final stage.
const STAGE_IDS: Array[StringName] = [
	&"stage_01", &"stage_02", &"stage_03",
	&"stage_04", &"stage_05", &"stage_06",
	&"stage_07", &"stage_08", &"stage_09",
]
const FINAL_STAGE_ID: StringName = &"stage_09"

# --- run state (reset on new game / continue) ------------------------------
var health: int = MAX_HEALTH: set = _set_health
var lives: int = STARTING_LIVES: set = _set_lives
var e_tanks: int = 0
var w_tanks: int = 0

var current_stage_id: StringName = &""
var current_slot: int = 0

## Weapon id -> remaining energy. The default weapon is not metered.
var weapon_energy: Dictionary = {}
var unlocked_weapons: Array[StringName] = []
var current_weapon_index: int = 0

# --- persistent progress ---------------------------------------------------
var stages_completed: Array[StringName] = []
var game_beaten: bool = false
var playtime: float = 0.0

var _weapon_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_weapon_library()
	reset_run()


func _process(delta: float) -> void:
	if current_stage_id != &"":
		playtime += delta


# ---------------------------------------------------------------------------
# weapons
# ---------------------------------------------------------------------------
func _load_weapon_library() -> void:
	## Every .tres in src/weapons/data is registered automatically, so adding a
	## weapon is a matter of dropping a resource in that folder.
	_weapon_cache.clear()
	var dir := DirAccess.open(WeaponLibrary.DATA_DIR)
	if dir == null:
		push_warning("Weapon data folder missing: %s" % WeaponLibrary.DATA_DIR)
		return
	for file in dir.get_files():
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var res := load(WeaponLibrary.DATA_DIR.path_join(file_name))
		if res is WeaponData:
			_weapon_cache[res.id] = res


func get_weapon(id: StringName) -> WeaponData:
	return _weapon_cache.get(id)


func all_weapon_ids() -> Array:
	return _weapon_cache.keys()


func current_weapon() -> WeaponData:
	if unlocked_weapons.is_empty():
		return null
	current_weapon_index = clampi(current_weapon_index, 0, unlocked_weapons.size() - 1)
	return get_weapon(unlocked_weapons[current_weapon_index])


func cycle_weapon(step: int) -> void:
	if unlocked_weapons.size() <= 1:
		return
	current_weapon_index = wrapi(current_weapon_index + step, 0, unlocked_weapons.size())
	var w := current_weapon()
	if w:
		weapon_changed.emit(w)
		AudioManager.play_sfx(&"menu_move")


func select_weapon(index: int) -> void:
	if index < 0 or index >= unlocked_weapons.size():
		return
	current_weapon_index = index
	weapon_changed.emit(current_weapon())


func unlock_weapon(id: StringName) -> void:
	if id == &"" or unlocked_weapons.has(id):
		return
	var w := get_weapon(id)
	if w == null:
		push_warning("Tried to unlock unknown weapon: %s" % id)
		return
	unlocked_weapons.append(id)
	weapon_energy[id] = w.max_energy


func weapon_energy_of(id: StringName) -> float:
	return float(weapon_energy.get(id, 0.0))


func can_spend_energy(w: WeaponData, cost: float = -1.0) -> bool:
	if w == null:
		return false
	var required := w.energy_cost if cost < 0.0 else cost
	if required <= 0.0:
		return true
	return weapon_energy_of(w.id) >= required


func spend_energy(w: WeaponData, amount: float = -1.0) -> void:
	if w == null or w.energy_cost <= 0.0:
		return
	var cost := w.energy_cost if amount < 0.0 else amount
	weapon_energy[w.id] = maxf(0.0, weapon_energy_of(w.id) - cost)
	weapon_energy_changed.emit(w.id, weapon_energy_of(w.id), w.max_energy)


func add_energy(id: StringName, amount: float) -> void:
	var w := get_weapon(id)
	if w == null:
		return
	weapon_energy[id] = minf(w.max_energy, weapon_energy_of(id) + amount)
	weapon_energy_changed.emit(id, weapon_energy_of(id), w.max_energy)


func refill_all_weapons() -> void:
	for id in unlocked_weapons:
		var w := get_weapon(id)
		if w:
			weapon_energy[id] = w.max_energy
			weapon_energy_changed.emit(id, w.max_energy, w.max_energy)


# ---------------------------------------------------------------------------
# health / lives / tanks
# ---------------------------------------------------------------------------
func _set_health(value: int) -> void:
	health = clampi(value, 0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func _set_lives(value: int) -> void:
	lives = maxi(value, -1)
	lives_changed.emit(lives)


func heal(amount: int) -> void:
	self.health = health + amount


func add_life(count: int = 1) -> void:
	self.lives = lives + count
	AudioManager.play_sfx(&"one_up")


func add_tank(kind: StringName) -> bool:
	if kind == &"e_tank" and e_tanks < MAX_TANKS:
		e_tanks += 1
	elif kind == &"w_tank" and w_tanks < MAX_TANKS:
		w_tanks += 1
	else:
		return false
	tanks_changed.emit(e_tanks, w_tanks)
	return true


func use_e_tank() -> bool:
	if e_tanks <= 0 or health >= MAX_HEALTH:
		return false
	e_tanks -= 1
	self.health = MAX_HEALTH
	tanks_changed.emit(e_tanks, w_tanks)
	return true


func use_w_tank() -> bool:
	if w_tanks <= 0:
		return false
	w_tanks -= 1
	refill_all_weapons()
	tanks_changed.emit(e_tanks, w_tanks)
	return true


# ---------------------------------------------------------------------------
# progress
# ---------------------------------------------------------------------------
func is_stage_cleared(id: StringName) -> bool:
	return stages_completed.has(id)


func is_stage_unlocked(id: StringName) -> bool:
	if id == FINAL_STAGE_ID:
		return all_main_stages_cleared()
	return true


func all_main_stages_cleared() -> bool:
	for id in STAGE_IDS:
		if id == FINAL_STAGE_ID:
			continue
		if not stages_completed.has(id):
			return false
	return true


func complete_stage(id: StringName, reward_weapon: StringName = &"") -> void:
	if not stages_completed.has(id):
		stages_completed.append(id)
	unlock_weapon(reward_weapon)
	if id == FINAL_STAGE_ID:
		game_beaten = true
	stage_cleared.emit(id)
	save_progress()


func cleared_count() -> int:
	var n := 0
	for id in STAGE_IDS:
		if id != FINAL_STAGE_ID and stages_completed.has(id):
			n += 1
	return n


# ---------------------------------------------------------------------------
# run lifecycle
# ---------------------------------------------------------------------------
func reset_run() -> void:
	## Fresh state for a brand-new file.
	stages_completed.clear()
	unlocked_weapons.clear()
	weapon_energy.clear()
	game_beaten = false
	playtime = 0.0
	e_tanks = 0
	w_tanks = 0
	current_weapon_index = 0
	current_stage_id = &""
	unlock_weapon(WeaponLibrary.DEFAULT_WEAPON_ID)
	self.lives = STARTING_LIVES
	self.health = MAX_HEALTH


func prepare_stage(id: StringName) -> void:
	## Called right before a stage scene loads.
	current_stage_id = id
	current_weapon_index = 0
	self.health = MAX_HEALTH


func on_player_died() -> void:
	self.lives = lives - 1


func has_lives() -> bool:
	return lives >= 0


# ---------------------------------------------------------------------------
# save bridge
# ---------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"stages_completed": stages_completed.map(func(s): return String(s)),
		"unlocked_weapons": unlocked_weapons.map(func(s): return String(s)),
		"game_beaten": game_beaten,
		"playtime": playtime,
		"lives": lives,
		"e_tanks": e_tanks,
		"w_tanks": w_tanks,
	}


func from_dict(data: Dictionary) -> void:
	reset_run()
	stages_completed.clear()
	for s in data.get("stages_completed", []):
		stages_completed.append(StringName(s))
	for s in data.get("unlocked_weapons", []):
		unlock_weapon(StringName(s))
	game_beaten = bool(data.get("game_beaten", false))
	playtime = float(data.get("playtime", 0.0))
	self.lives = int(data.get("lives", STARTING_LIVES))
	e_tanks = int(data.get("e_tanks", 0))
	w_tanks = int(data.get("w_tanks", 0))
	refill_all_weapons()
	tanks_changed.emit(e_tanks, w_tanks)


func save_progress() -> void:
	SaveSystem.write_slot(current_slot, to_dict())
