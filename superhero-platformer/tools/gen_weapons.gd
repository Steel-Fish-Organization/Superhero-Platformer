extends SceneTree
## Builds the starter weapon set in src/weapons/data/.
##
##     godot --headless --path . --script tools/gen_weapons.gd
##
## Run it again after changing the defaults below; it overwrites the .tres files.
## Once a weapon exists you can also just edit it in the inspector -- this script
## is only here so the initial set is reproducible.

const OUT_DIR := "res://src/weapons/data"

const PULSE := "res://src/weapons/projectiles/shot_pulse.tscn"
const PULSE_MID := "res://src/weapons/projectiles/shot_pulse_mid.tscn"
const PULSE_FULL := "res://src/weapons/projectiles/shot_pulse_full.tscn"
const SCATTER := "res://src/weapons/projectiles/shot_scatter.tscn"
const ARC := "res://src/weapons/projectiles/shot_arc.tscn"
const LANCE := "res://src/weapons/projectiles/shot_lance.tscn"
const TRACER := "res://src/weapons/projectiles/shot_tracer.tscn"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_save(_pulse_bolt())
	_save(_scatter_flare())
	_save(_arc_ripper())
	_save(_lance_beam())
	_save(_tracer_swarm())

	print("Weapons written to ", OUT_DIR)
	quit()


func _save(w: WeaponData) -> void:
	var path := "%s/%s.tres" % [OUT_DIR, w.id]
	var err := ResourceSaver.save(w, path)
	if err != OK:
		printerr("Failed to save %s: %s" % [path, error_string(err)])
	else:
		print("  ", path)


func _stage(scene_path: String, damage: int, speed: float, charge_time: float,
		max_active: int = 3, cost: float = -1.0) -> WeaponChargeStage:
	var s := WeaponChargeStage.new()
	s.projectile_scene = load(scene_path)
	s.damage = damage
	s.speed = speed
	s.charge_time = charge_time
	s.max_active = max_active
	s.energy_cost = cost
	return s


# ---------------------------------------------------------------------------
# the starting weapon -- unmetered, three charge tiers, Mega Man X pacing
# ---------------------------------------------------------------------------
func _pulse_bolt() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"pulse_bolt"
	w.display_name = "PULSE BOLT"
	w.short_name = "PLS"
	w.max_energy = 0.0
	w.energy_cost = 0.0
	w.can_charge = true
	w.fire_cooldown = 0.12
	w.hud_color = Color(0.38, 0.91, 0.94)
	w.suit_primary = Color(0.188, 0.376, 0.847)
	w.suit_secondary = Color(0.431, 0.627, 1.0)

	var tap := _stage(PULSE, 1, 300.0, 0.0, 3)
	tap.shoot_sfx = &"shoot"

	var mid := _stage(PULSE_MID, 3, 330.0, 0.5, 1)
	mid.shoot_sfx = &"shoot_mid"
	mid.extra_cooldown = 0.06
	mid.recoil_time = 0.1

	var full := _stage(PULSE_FULL, 6, 400.0, 1.15, 1)
	full.shoot_sfx = &"shoot_full"
	full.extra_cooldown = 0.12
	full.recoil_time = 0.18
	full.screen_shake = 1.5
	full.muzzle_scale = 1.0

	w.stages = [tap, mid, full]
	return w


# ---------------------------------------------------------------------------
# stage rewards
# ---------------------------------------------------------------------------
func _scatter_flare() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"scatter_flare"
	w.display_name = "SCATTER FLARE"
	w.short_name = "SCF"
	w.awarded_by_stage = &"stage_01"
	w.max_energy = 28.0
	w.energy_cost = 1.0
	w.can_charge = true
	w.fire_cooldown = 0.24
	w.hud_color = Color(1.0, 0.6, 0.25)
	w.suit_primary = Color(0.85, 0.35, 0.12)
	w.suit_secondary = Color(1.0, 0.72, 0.35)

	var tap := _stage(SCATTER, 2, 250.0, 0.0, 9, 1.0)
	tap.shot_count = 3
	tap.spread_degrees = 34.0
	tap.shoot_sfx = &"shoot"

	var big := _stage(SCATTER, 2, 280.0, 0.65, 15, 3.0)
	big.shot_count = 5
	big.spread_degrees = 56.0
	big.shoot_sfx = &"shoot_mid"
	big.screen_shake = 1.0

	w.stages = [tap, big]
	return w


func _arc_ripper() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"arc_ripper"
	w.display_name = "ARC RIPPER"
	w.short_name = "ARC"
	w.awarded_by_stage = &"stage_02"
	w.max_energy = 28.0
	w.energy_cost = 2.0
	w.can_charge = false
	w.fire_cooldown = 0.3
	w.hud_color = Color(0.6, 1.0, 0.5)
	w.suit_primary = Color(0.16, 0.6, 0.3)
	w.suit_secondary = Color(0.5, 0.95, 0.55)

	var tap := _stage(ARC, 3, 210.0, 0.0, 2, 2.0)
	tap.shoot_sfx = &"shoot_mid"
	w.stages = [tap]
	return w


func _lance_beam() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"lance_beam"
	w.display_name = "LANCE BEAM"
	w.short_name = "LNC"
	w.awarded_by_stage = &"stage_03"
	w.max_energy = 28.0
	w.energy_cost = 3.0
	w.can_charge = false
	w.fire_cooldown = 0.45
	w.hud_color = Color(1.0, 0.85, 0.35)
	w.suit_primary = Color(0.72, 0.55, 0.1)
	w.suit_secondary = Color(1.0, 0.9, 0.45)

	var tap := _stage(LANCE, 2, 520.0, 0.0, 1, 3.0)
	tap.shoot_sfx = &"shoot_full"
	tap.screen_shake = 1.0
	tap.extra_cooldown = 0.1
	w.stages = [tap]
	return w


func _tracer_swarm() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"tracer_swarm"
	w.display_name = "TRACER SWARM"
	w.short_name = "TRC"
	w.awarded_by_stage = &"stage_04"
	w.max_energy = 28.0
	w.energy_cost = 1.0
	w.can_charge = true
	w.fire_cooldown = 0.2
	w.hud_color = Color(0.85, 0.55, 1.0)
	w.suit_primary = Color(0.45, 0.2, 0.7)
	w.suit_secondary = Color(0.8, 0.55, 1.0)

	var tap := _stage(TRACER, 2, 190.0, 0.0, 4, 1.0)
	tap.shoot_sfx = &"shoot"

	var swarm := _stage(TRACER, 2, 190.0, 0.7, 8, 3.0)
	swarm.shot_count = 3
	swarm.spread_degrees = 50.0
	swarm.lateral_offset = 6.0
	swarm.shoot_sfx = &"shoot_mid"

	w.stages = [tap, swarm]
	return w
