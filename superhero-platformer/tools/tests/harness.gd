class_name GameTest
extends SceneTree
## Shared rig for the headless test suites in this folder.
##
## Each suite extends this and fills in `step(frame)`, returning true when it's
## done. The rig loads the greybox level, drives real input through the real
## physics loop, and prints PASS/FAIL per check with a count at the end.
##
##     godot --headless --fixed-fps 60 --path . --script tools/tests/<suite>.gd
##
## --fixed-fps 60 matters: it makes every frame exactly one physics tick, so the
## frame numbers in a suite mean the same thing on every machine.
##
## Input pressed from here reaches the player on the NEXT frame, since the rig
## runs before the scene tree's nodes. Leave a frame between pressing a button
## and checking what it did.

const LEVEL := "res://levels/greybox.tscn"

var level: Node
var player: CharacterBody2D
var camera: Camera2D
var frame := 0
var failures := 0

var _held: Array[StringName] = []


func _initialize() -> void:
	level = load(LEVEL).instantiate()
	root.add_child(level)
	player = level.get_node("Player")
	camera = level.get_node("RoomCamera")


## Override for suite setup. Runs on the first physics frame, not in
## _initialize: nodes added to the tree there haven't had _ready called yet, so
## their @onready members are still null.
func setup() -> void:
	pass


## Override: one physics frame. Return true to finish the suite.
func step(_frame: int) -> bool:
	return true


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		setup()
		return false
	if step(frame):
		_release_all()
		print("\n%d failure(s)" % failures)
		return true
	return false


# ---------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------
func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "   [" + detail + "]"))
	if not ok:
		failures += 1


func check_near(name: String, value: float, want: float, tolerance := 1.0) -> void:
	check(name, absf(value - want) <= tolerance, "%.2f, wanted %.2f +/- %.2f" % [value, want, tolerance])


# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func press(action: StringName, strength := 1.0) -> void:
	Input.action_press(action, strength)
	if not _held.has(action):
		_held.append(action)


func release(action: StringName) -> void:
	Input.action_release(action)
	_held.erase(action)


func _release_all() -> void:
	for action in _held.duplicate():
		Input.action_release(action)
	_held.clear()


## Moves the mouse to a world point. `travel` is in game pixels, and has to be
## over the player's MOUSE_WAKE_DISTANCE to switch aiming to the mouse.
func mouse_to(world: Vector2, travel := Vector2(30.0, 0.0)) -> void:
	var window := root.get_final_transform() * (root.get_canvas_transform() * world)
	var event := InputEventMouseMotion.new()
	event.position = window
	event.global_position = window
	event.relative = root.get_final_transform().basis_xform(travel)
	Input.parse_input_event(event)


# ---------------------------------------------------------------------------
# world
# ---------------------------------------------------------------------------
## Puts the hero somewhere and snaps the camera there. Shots off camera are
## culled, so suites must bring the camera to whatever they're testing.
func place(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.sliding = false
	player.crouching = false
	player.hanging = false
	player.climbing = false
	player.dashing = false
	player._regrab = 0.0
	player._last_grab = 0.0
	# Queued presses shouldn't survive a teleport, or an earlier case's buffered
	# slide fires the moment the next one puts the hero back on the ground.
	player._jump_buffer = 0.0
	player._slide_buffer = 0.0
	# A teleport is a fresh start in the air too: without this, a suite that
	# never lets the hero land keeps an earlier case's spent dash or double jump.
	player._air_jumps_used = 0
	player._air_dash_used = false
	# A velocity a suite sets by hand isn't a held jump, so the variable-height
	# jump cut would halve it on the first frame. Mark the cut as already spent.
	player._jump_cut_used = true
	player._set_shape(false)
	player.respawned.emit()


func live_shots() -> Array:
	return player._shots.filter(func(shot): return is_instance_valid(shot))


func newest_shot() -> Node:
	var alive := live_shots()
	return alive[-1] if alive.size() > 0 else null


func node(path: String) -> Node:
	return level.get_node_or_null(path)
