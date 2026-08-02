extends Node
## Development helper: boots a scene, waits, grabs a screenshot, quits.
##
##     godot --path . tools/screenshot_runner.tscn -- <scene_path> <out.png> [frames] [inputs]
##
## `inputs` is a smoke-test script: comma separated `action@start-end` entries
## in frame numbers, e.g. `move_right@10-90,fire@20-80,jump@60-64`. Handy for
## checking that movement, charging and firing actually work without a human.
##
## Run as the main scene (not with --script) so the autoloads are present. The
## target scene is added alongside this node rather than replacing it, so the
## runner survives to take the shot.

const DEFAULT_SCENE := "res://levels/stage_01.tscn"
const DEFAULT_OUT := "res://.screenshots/frame.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	var out_path: String = args[1] if args.size() > 1 else DEFAULT_OUT
	var frames: int = int(args[2]) if args.size() > 2 else 90

	# Lock to 60fps so a frame in the input script equals one physics tick.
	Engine.max_fps = 60

	var tree := get_tree()
	await tree.process_frame

	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("Could not load ", scene_path)
		tree.quit(1)
		return
	var instance := packed.instantiate()
	tree.root.add_child(instance)
	tree.current_scene = instance

	# Optional 5th arg "x,y": drop the player straight into a later section.
	if args.size() > 4:
		await tree.process_frame
		var xy := args[4].split(",")
		var p := tree.get_first_node_in_group(&"player") as Node2D
		if p and xy.size() == 2:
			p.call(&"spawn_at", Vector2(float(xy[0]), float(xy[1])), false)

	var script_entries := _parse_inputs(args[3] if args.size() > 3 else "")
	for i in frames:
		# Inject right after a physics step so the *next* step sees the press as
		# "just pressed" -- the same ordering the OS input flush produces.
		await tree.physics_frame
		_apply_inputs(script_entries, i)
	_release_all(script_entries)

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var err := img.save_png(out_path)
	print("screenshot %s -> %s (%s)" % [scene_path, out_path, error_string(err)])
	_report(tree)
	tree.quit()


func _parse_inputs(spec: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in spec.split(",", false):
		var parts := entry.split("@")
		if parts.size() != 2:
			continue
		var span := parts[1].split("-")
		out.append({
			"action": StringName(parts[0].strip_edges()),
			"start": int(span[0]),
			"end": int(span[1]) if span.size() > 1 else int(span[0]),
			"down": false,
		})
	return out


func _apply_inputs(entries: Array[Dictionary], frame: int) -> void:
	for e in entries:
		var want := frame >= int(e["start"]) and frame <= int(e["end"])
		if want == bool(e["down"]):
			continue
		e["down"] = want
		_send(e["action"], want)


func _release_all(entries: Array[Dictionary]) -> void:
	for e in entries:
		if bool(e["down"]):
			_send(e["action"], false)


## action_press/release drives Input.is_action_* (what gameplay reads); the
## InputEventAction additionally reaches _unhandled_input, which the menus use.
func _send(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _report(tree: SceneTree) -> void:
	var p := tree.get_first_node_in_group(&"player")
	if p is Node2D:
		print("  player at ", (p as Node2D).global_position.round())
	print("  live projectiles: ", tree.get_nodes_in_group(&"projectiles").size())
	print("  live enemies: ", tree.get_nodes_in_group(&"enemies").size())
	print("  health: %d/%d" % [GameState.health, GameState.MAX_HEALTH])
	var w := GameState.current_weapon()
	print("  weapons unlocked: ", GameState.unlocked_weapons,
		"  equipped: ", w.display_name if w else "<none>",
		"  stages: ", w.stage_count() if w else -1)
	if p:
		var ws := p.get_node_or_null(^"WeaponSystem")
		if ws:
			print("  muzzle: ", ws.get(&"muzzle"), "  enabled: ", ws.get(&"enabled"),
				"  charge_stage: ", ws.get(&"charge_stage"))
