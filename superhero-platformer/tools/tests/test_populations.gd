extends SceneTree
## M3: one stage, three ways to play it.
##
## Loads the greybox three times over, each as though the player had arrived on a
## different path, and compares what's actually in it. Standalone rather than
## built on harness.gd, because the arriving path has to be set *before* the
## level is instantiated -- that's the whole mechanism.
##
##     godot --headless --fixed-fps 60 --path . --script tools/tests/test_populations.gd

const LEVEL := "res://levels/greybox.tscn"

var state: Node
var frame := 0
var failures := 0
var counts: Dictionary = {}
var queue := ["", "H", "N", "D"]
var level: Node


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "   [" + detail + "]"))
	if not ok:
		failures += 1


func _initialize() -> void:
	state = root.get_node_or_null(^"GameState")


## Builds the stage as it would be for someone arriving on `code`. Counting
## happens a frame later: the rescue tracker gathers deferred, so its total is
## still 0 on the frame the level is added.
func build(code: String) -> void:
	state.arrived_as = code
	level = load(LEVEL).instantiate()
	root.add_child(level)


func take_census() -> Dictionary:
	var names: Array = []
	for c in get_nodes_in_group(&"civilians"):
		names.append(c.display_name if c.display_name != "" else "crowd")
	var census := {
		"civilians": get_nodes_in_group(&"civilians").size(),
		"enemies": get_nodes_in_group(&"enemies").size(),
		"alert": level.get_node("Alert").level,
		"tracker_total": level.get_node("RescueTracker").total,
		"names": names,
	}
	root.remove_child(level)
	level.free()
	level = null
	return census


func _physics_process(_delta: float) -> bool:
	frame += 1
	if state == null:
		check("GameState autoload present", false)
		return true

	# build a stage on one frame, count it on the next
	if not queue.is_empty():
		if level == null:
			build(queue[0])
		else:
			counts[queue.pop_front()] = take_census()
		return false

	var fresh: Dictionary = counts[""]
	var hero: Dictionary = counts["H"]
	var neutral: Dictionary = counts["N"]
	var dark: Dictionary = counts["D"]
	print("  no path : %s" % fresh)
	print("  hero    : %s" % hero)
	print("  neutral : %s" % neutral)
	print("  dark    : %s" % dark)

	check("played on its own, the stage is its neutral self",
		fresh["civilians"] == 3 and fresh["enemies"] == neutral["enemies"], str(fresh))
	check("a hero arrival finds someone extra",
		hero["civilians"] > neutral["civilians"], "%d vs %d" % [hero["civilians"], neutral["civilians"]])
	check("and that someone is Wen, up in the gallery",
		hero["names"].has("Wen") and not neutral["names"].has("Wen"), str(hero["names"]))
	check("a dark arrival finds fewer people left",
		dark["civilians"] < neutral["civilians"], "%d vs %d" % [dark["civilians"], neutral["civilians"]])
	check("Juno in particular is already gone",
		neutral["names"].has("Juno") and not dark["names"].has("Juno"), str(dark["names"]))
	check("a dark arrival finds more opposition",
		dark["enemies"] > neutral["enemies"], "%d vs %d" % [dark["enemies"], neutral["enemies"]])
	check("neutral is the baseline",
		neutral["civilians"] == fresh["civilians"] and neutral["enemies"] == fresh["enemies"], str(neutral))

	check("the rescue count matches who's actually there",
		hero["tracker_total"] == hero["civilians"] and dark["tracker_total"] == dark["civilians"],
		"hero %d/%d, dark %d/%d" % [hero["tracker_total"], hero["civilians"], dark["tracker_total"], dark["civilians"]])
	check("the villain has a head start on a dark run",
		dark["alert"] == 1 and neutral["alert"] == 0, "dark=%d neutral=%d" % [dark["alert"], neutral["alert"]])

	state.arrived_as = ""
	print("\n%d failure(s)" % failures)
	return true
