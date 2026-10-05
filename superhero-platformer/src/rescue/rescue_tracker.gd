extends Node
## Counts the civilians in a level and keeps the stage's letters.
##
## Drop one into a level; it finds every Civilian by itself. The HUD reads it,
## and later a save system can read the same numbers to decide what carries
## over between stages.

signal changed(saved: int, total: int, lost: int)
## A named survivor was rescued -- they hand over the stage's letter.
signal letter_found(letter: String, who: String)

## How a run through this stage is counted when you reach the exit. See
## docs/three-paths.md.
enum Outcome { HERO, NEUTRAL, DARK }

## Hero needs everyone out alive. Dark needs this share of them dead; anything
## in between is neutral, including walking past everyone without a scratch.
@export_range(0.1, 1.0, 0.05) var dark_share := 0.5

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


# ---------------------------------------------------------------------------
# the outcome
# ---------------------------------------------------------------------------
## People still alive and unhelped. Neither saved nor dead: a neutral run leaves
## the stage full of them.
func untouched() -> int:
	return maxi(total - saved - lost, 0)


## Deaths needed for a dark run.
func deaths_for_dark() -> int:
	return maxi(int(ceil(float(total) * dark_share)), 1)


func outcome() -> Outcome:
	if total <= 0:
		return Outcome.NEUTRAL
	if saved >= total:
		return Outcome.HERO
	if lost >= deaths_for_dark():
		return Outcome.DARK
	return Outcome.NEUTRAL


## One letter, which is what the save file and the stage graph key off.
func outcome_code() -> String:
	match outcome():
		Outcome.HERO:
			return "H"
		Outcome.DARK:
			return "D"
		_:
			return "N"


func outcome_name() -> String:
	return ["HERO", "NEUTRAL", "DARK"][outcome()]


## False once the first person dies: hero needs everyone. The HUD greys the line
## out the moment this turns false, because that's when the player decides
## whether to go back for the last one or write the run off.
func hero_possible() -> bool:
	return total > 0 and lost == 0


func dark_possible() -> bool:
	return total > 0 and lost + untouched() >= deaths_for_dark()


## Neutral stops being reachable once one of the other two is already settled.
func neutral_possible() -> bool:
	return not (saved >= total and total > 0) and lost < deaths_for_dark()
