@tool
extends Node2D
## A set of nodes that only exists on some arriving paths. One stage, three ways
## to play it: see docs/three-paths.md §6.
##
## Put the extra people a hero run finds under a group with `on_paths = ["H"]`,
## and the extra opposition a dark run meets under one with `["D"]`. Everything
## that's in the stage no matter how you got there stays outside these groups.
##
## The culling happens in _enter_tree, before the children themselves enter the
## tree: they never run _ready, never join the "civilians" or "enemies" groups,
## and so never reach the rescue tracker's count. Freeing them later would leave
## the stage's totals wrong for a frame, which is exactly long enough for the
## tracker to read them.

## Arriving outcomes this group survives: "H", "N", "D". Empty means always.
@export var on_paths: Array[String] = []
## Keep it when there's no arriving path at all -- the first stage of a run, or
## a level opened on its own in the editor.
@export var on_first_visit := true


func _enter_tree() -> void:
	if Engine.is_editor_hint() or wanted():
		return
	for child in get_children():
		remove_child(child)
		child.free()


func wanted() -> bool:
	if on_paths.is_empty():
		return true
	var state := get_node_or_null(^"/root/GameState")
	var code: String = state.arrived_as if state else ""
	if code == "":
		return on_first_visit
	return on_paths.has(code)
