class_name WeaponLibrary
extends RefCounted
## Where weapons live and which one the player starts with.
##
## To change the starting projectile entirely: point DEFAULT_WEAPON_ID at a
## different .tres in src/weapons/data/. Nothing else needs to know.

const DATA_DIR := "res://src/weapons/data"
const DEFAULT_WEAPON_ID: StringName = &"pulse_bolt"

## Which weapon each stage awards. Kept here so the stage-select screen can show
## the reward before you own it, and so GameState can grant it on clear.
const STAGE_REWARDS := {
	&"stage_01": &"scatter_flare",
	&"stage_02": &"arc_ripper",
	&"stage_03": &"lance_beam",
	&"stage_04": &"tracer_swarm",
	&"stage_05": &"",
	&"stage_06": &"",
	&"stage_07": &"",
	&"stage_08": &"",
	&"stage_09": &"",
}


static func reward_for(stage_id: StringName) -> StringName:
	return STAGE_REWARDS.get(stage_id, &"")
