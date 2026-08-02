class_name PickupTable
extends RefCounted
## Weighted drop table used when an enemy dies. Tweak the weights here to change
## how generous the whole game is in one place.

const SMALL_HEALTH := preload("res://src/items/pickup_health_small.tscn")
const LARGE_HEALTH := preload("res://src/items/pickup_health_large.tscn")
const SMALL_ENERGY := preload("res://src/items/pickup_energy_small.tscn")
const LARGE_ENERGY := preload("res://src/items/pickup_energy_large.tscn")
const ONE_UP := preload("res://src/items/pickup_life.tscn")

const WEIGHTS: Array[Dictionary] = [
	{"scene": SMALL_HEALTH, "weight": 34.0},
	{"scene": SMALL_ENERGY, "weight": 30.0},
	{"scene": LARGE_HEALTH, "weight": 16.0},
	{"scene": LARGE_ENERGY, "weight": 16.0},
	{"scene": ONE_UP, "weight": 4.0},
]


static func roll() -> PackedScene:
	var total := 0.0
	for entry in WEIGHTS:
		total += float(entry["weight"])
	var pick := randf() * total
	for entry in WEIGHTS:
		pick -= float(entry["weight"])
		if pick <= 0.0:
			return entry["scene"]
	return SMALL_HEALTH
