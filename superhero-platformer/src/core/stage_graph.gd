class_name StageGraph
extends Resource
## Which stage follows which, per outcome. See docs/three-paths.md.
##
## This is data, not code: the shape of the game is one .tres file, so the tree
## can be rearranged without touching a level or a script. Levels never name each
## other -- a level knows its own `stage_id` and nothing else.

const SCENE_TEMPLATE := "res://levels/%s.tscn"

@export var first_stage: StringName = &"greybox"

## stage id -> {"name": String, "H": StringName, "N": StringName, "D": StringName}
##
## A successor left empty ends the run there, which is what the last stage of an
## act does until the next act exists.
@export var stages: Dictionary = {}


func has_stage(id: StringName) -> bool:
	return stages.has(id)


func entry(id: StringName) -> Dictionary:
	return stages.get(id, {})


func display_name(id: StringName) -> String:
	return String(entry(id).get("name", String(id).to_upper()))


func scene_path(id: StringName) -> String:
	return SCENE_TEMPLATE % id


## The stage that follows `id` for an outcome code of "H", "N" or "D". Empty when
## the run ends here, or when the stage isn't in the graph at all.
func next_stage(id: StringName, code: String) -> StringName:
	return entry(id).get(code, &"")


func all_ids() -> Array:
	return stages.keys()
