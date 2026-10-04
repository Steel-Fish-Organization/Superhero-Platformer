extends Node
## Counts the civilians in a level and keeps the stage's letters.
##
## Drop one into a level; it finds every Civilian by itself. The HUD reads it,
## and later a save system can read the same numbers to decide what carries
## over between stages.

signal changed(saved: int, total: int, lost: int)
## A named survivor was rescued -- they hand over the stage's letter.
signal letter_found(letter: String, who: String)

var total := 0
var saved := 0
var lost := 0
var letters: Array[String] = []


func _ready() -> void:
	add_to_group(&"rescue_tracker")
	# Deferred so every civilian has run _ready and joined the group first.
	_gather.call_deferred()


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
	if civilian.letter != "" and not letters.has(civilian.letter):
		letters.append(civilian.letter)
		letter_found.emit(civilian.letter, civilian.display_name)
	changed.emit(saved, total, lost)


func _on_lost(_civilian: Civilian) -> void:
	lost += 1
	changed.emit(saved, total, lost)


## Everyone accounted for, one way or the other.
func all_resolved() -> bool:
	return saved + lost >= total
