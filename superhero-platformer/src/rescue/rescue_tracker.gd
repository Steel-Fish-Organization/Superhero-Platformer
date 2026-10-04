extends Node
## Counts the civilians in a level and keeps the stage's letters.
##
## Drop one into a level; it finds every Civilian by itself. The HUD reads it,
## and later a save system can read the same numbers to decide what carries
## over between stages.

signal changed(saved: int, total: int, lost: int)
## A named survivor was rescued -- they hand over the stage's letter.
signal letter_found(letter: String, who: String)

## Which stage this is, for the save file.
@export var stage_id: StringName = &"greybox"
## Earned by getting everyone out alive. The reward for the harder path.
@export var clean_sweep_rewards: Array[Upgrade] = []

var total := 0
var saved := 0
var lost := 0
var letters: Array[String] = []


func _ready() -> void:
	add_to_group(&"rescue_tracker")
	# Deferred so every civilian has run _ready and joined the group first.
	_gather.call_deferred()


## The autoload, or null when a level is run on its own without it.
func _state() -> Node:
	return get_node_or_null(^"/root/GameState")


func _gather() -> void:
	for node in get_tree().get_nodes_in_group(&"civilians"):
		var civilian := node as Civilian
		if civilian == null:
			continue
		total += 1
		civilian.rescued.connect(_on_rescued)
		civilian.lost.connect(_on_lost)
	changed.emit(saved, total, lost)


func _on_rescued(civilian: Civilian) -> void:
	saved += 1
	var state := _state()
	if civilian.letter != "" and not letters.has(civilian.letter):
		letters.append(civilian.letter)
		letter_found.emit(civilian.letter, civilian.display_name)
		if state:
			state.collect_letter(civilian.letter)
	if state and civilian.upgrade:
		state.unlock(civilian.upgrade)
	# Everyone out alive earns the clean sweep.
	if saved >= total and lost == 0 and state:
		for reward in clean_sweep_rewards:
			state.unlock(reward)
	_publish()


func _on_lost(_civilian: Civilian) -> void:
	lost += 1
	_publish()


func _publish() -> void:
	changed.emit(saved, total, lost)
	var state := _state()
	if state:
		state.record_stage(stage_id, saved, total, lost)


## Everyone accounted for, one way or the other.
func all_resolved() -> bool:
	return saved + lost >= total
