class_name WeaponData
extends Resource
## A selectable weapon. Drop a .tres of this type into src/weapons/data/ and it
## is registered automatically at startup (see GameState._load_weapon_library).
##
## The default weapon is defined by WeaponLibrary.DEFAULT_WEAPON_ID; every other
## weapon is awarded by clearing the stage listed in its `awarded_by_stage`.

@export_group("Identity")
@export var id: StringName = &"weapon"
@export var display_name: String = "WEAPON"
## Three-letter tag used by the pause menu, Mega Man style.
@export var short_name: String = "WPN"
## Stage that grants this weapon. Empty = available from the start.
@export var awarded_by_stage: StringName = &""

@export_group("Charge stages")
## Index 0 is the tap shot. Add stages for mid/full charge; each needs a longer
## `charge_time` than the one before it.
@export var stages: Array[WeaponChargeStage] = []
@export var can_charge: bool = true
## Charging stops (and auto-fires) if the button is held past the last stage.
@export var auto_fire_at_full: bool = false

@export_group("Energy")
## 0 means the weapon is unmetered (the starting weapon).
@export var max_energy: float = 28.0
## Default per-shot cost; individual stages can override it.
@export var energy_cost: float = 1.0

@export_group("Cadence")
@export var fire_cooldown: float = 0.14
## Seconds the shoot pose is held after firing.
@export var pose_time: float = 0.25

@export_group("Presentation")
## Tints the player's suit while equipped, like a Mega Man weapon swap.
@export var suit_primary: Color = Color(0.19, 0.38, 0.85)
@export var suit_secondary: Color = Color(0.43, 0.63, 1.0)
## Colour for the HUD energy bar and the charge aura.
@export var hud_color: Color = Color(0.38, 0.91, 0.94)
@export var charge_sfx: StringName = &"charge_loop"
@export var charge_ready_sfx: StringName = &"charge_ready"


func stage_count() -> int:
	return stages.size()


func stage_at(index: int) -> WeaponChargeStage:
	if stages.is_empty():
		return null
	return stages[clampi(index, 0, stages.size() - 1)]


## Highest stage reachable after holding fire for `held` seconds.
func stage_for_charge(held: float) -> int:
	if not can_charge:
		return 0
	var best := 0
	for i in stages.size():
		if held >= stages[i].charge_time:
			best = i
	return best


## Seconds needed to reach the final stage (used by the charge aura).
func full_charge_time() -> float:
	if stages.is_empty():
		return 0.0
	return stages[stages.size() - 1].charge_time


func cost_of(stage_index: int) -> float:
	var s := stage_at(stage_index)
	if s == null:
		return 0.0
	return energy_cost if s.energy_cost < 0.0 else s.energy_cost


func is_metered() -> bool:
	return max_energy > 0.0 and energy_cost > 0.0
