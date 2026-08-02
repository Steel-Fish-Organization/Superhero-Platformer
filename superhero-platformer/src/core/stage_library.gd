class_name StageLibrary
extends RefCounted
## One place that names the nine stages, their bosses and their rewards.
##
## The stage-select grid is laid out like the NES games: eight bosses around the
## edge and the ninth, hidden stage in the middle, sealed until the other eight
## are done.

const STAGES: Array[Dictionary] = [
	{"id": &"stage_01", "boss": "BULWARK",   "stage": "FOUNDRY DISTRICT", "portrait": 0},
	{"id": &"stage_02", "boss": "VOLTSPIRE", "stage": "POWER SPIRE",      "portrait": 1},
	{"id": &"stage_03", "boss": "CRYOPHANT", "stage": "COLD STORAGE",     "portrait": 2},
	{"id": &"stage_04", "boss": "NIGHTVEIL", "stage": "MIDNIGHT TRANSIT", "portrait": 3},
	{"id": &"stage_05", "boss": "MAGNAFIST", "stage": "SCRAP CANYON",     "portrait": 4},
	{"id": &"stage_06", "boss": "SOLARIS",   "stage": "SKY REFINERY",     "portrait": 5},
	{"id": &"stage_07", "boss": "TIDEBORNE", "stage": "DEEP CHANNEL",     "portrait": 6},
	{"id": &"stage_08", "boss": "GEARWRAITH","stage": "CLOCKWORK VAULT",  "portrait": 7},
	{"id": &"stage_09", "boss": "THE ARCHITECT", "stage": "CITADEL CORE", "portrait": 8},
]

## Grid positions, reading left-to-right, top-to-bottom. The centre cell is the
## hidden final stage.
const GRID_ORDER: Array[int] = [0, 1, 2, 3, 8, 4, 5, 6, 7]

## Frame index of the "?" portrait used for a locked stage.
const LOCKED_PORTRAIT := 9


static func info(stage_id: StringName) -> Dictionary:
	for s in STAGES:
		if s["id"] == stage_id:
			return s
	return {"id": stage_id, "boss": "???", "stage": "UNKNOWN", "portrait": LOCKED_PORTRAIT}


static func at_grid(cell: int) -> Dictionary:
	if cell < 0 or cell >= GRID_ORDER.size():
		return STAGES[0]
	return STAGES[GRID_ORDER[cell]]


static func scene_path(stage_id: StringName) -> String:
	return "res://levels/%s.tscn" % stage_id
