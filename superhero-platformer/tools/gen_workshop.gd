extends SceneTree
## Builds levels/workshop.tscn, a bench for trying the two new toys: tiles you
## can shoot away, and hook switches driving machinery.
##
##     godot --headless --path . --script tools/gen_workshop.gd
##
## It isn't in the stage graph and has no exit -- open it in the editor and press
## F6. Two screens wide:
##
##   left   a breakable wall, a breakable floor over a pit, and a block tower
##   right  a hook switch, two platforms, two doors and a ferris wheel
##
## WARNING: this OVERWRITES levels/workshop.tscn.

const T := 8
const SCREEN := Vector2i(54, 30)
const SOLID := Vector2i(0, 0)
const SOLID_TOP := Vector2i(1, 0)
const ONEWAY := Vector2i(4, 0)
const BG := Vector2i(5, 0)
const BREAKABLE := Vector2i(6, 0)

const FLOOR_ROW := 24
const BOTTOM_ROW := 29
const WIDTH := 108           # two screens

var level_root: Node2D
var tiles: TileMapLayer
var counts: Dictionary = {}


func _initialize() -> void:
	var tileset: TileSet = load("res://assets/greybox/tileset.tres")
	level_root = Node2D.new()
	level_root.name = "Workshop"

	var bg := TileMapLayer.new()
	bg.name = "Background"
	bg.tile_set = tileset
	bg.z_index = -10
	bg.collision_enabled = false
	level_root.add_child(bg)

	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = tileset
	level_root.add_child(tiles)

	for x in WIDTH:
		for y in range(9, BOTTOM_ROW + 1):
			bg.set_cell(Vector2i(x, y), 0, BG)
	_ground(0, WIDTH - 1)
	_wall(0)
	_wall(WIDTH - 1)

	_label("DESTRUCTIBLE TILES", 40, 72)
	_label("shoot the pale blocks - a charged shot clears a hole", 40, 88, 0.14)
	_breakables()

	_label("HOOK SWITCHES", 480, 72)
	_label("hang on the switch to run the machines", 480, 88, 0.14)
	_machines()

	_rooms()
	_support()

	_assign_owner(level_root, level_root)
	var packed := PackedScene.new()
	packed.pack(level_root)
	print("workshop.tscn: ", error_string(ResourceSaver.save(packed, "res://levels/workshop.tscn")))
	quit()


# ---------------------------------------------------------------------------
# left half: things to shoot
# ---------------------------------------------------------------------------
func _breakables() -> void:
	# a wall across the way, head height: a plain shot opens one hole, a charged
	# one opens a doorway
	for y in range(FLOOR_ROW - 6, FLOOR_ROW):
		for x in range(14, 17):
			tiles.set_cell(Vector2i(x, y), 0, BREAKABLE)

	# a breakable floor over a drop, with solid ground either side
	for x in range(24, 32):
		tiles.set_cell(Vector2i(x, FLOOR_ROW), 0, BREAKABLE)
	for y in range(FLOOR_ROW + 1, BOTTOM_ROW + 1):
		for x in range(24, 32):
			tiles.erase_cell(Vector2i(x, y))

	# a tower, to see a charged shot take a bite out of it
	for y in range(FLOOR_ROW - 9, FLOOR_ROW):
		for x in range(38, 42):
			tiles.set_cell(Vector2i(x, y), 0, BREAKABLE)
	# solid rock behind it, which should survive everything
	for y in range(FLOOR_ROW - 9, FLOOR_ROW):
		tiles.set_cell(Vector2i(42, y), 0, SOLID)

	var breakables := Node2D.new()
	breakables.name = "Breakables"
	breakables.set_script(load("res://src/level/destructible_tiles.gd"))
	breakables.set(&"tile_layer", tiles)
	breakables.set(&"regrow_after", 8.0)      # so the bench resets itself
	level_root.add_child(breakables)


# ---------------------------------------------------------------------------
# right half: things that move
# ---------------------------------------------------------------------------
func _machines() -> void:
	# The switch hangs where you can jump into it from the floor.
	_spawn("res://src/machines/hook_switch.tscn", "HookSwitch",
		Vector2(62 * T, (FLOOR_ROW - 7) * T), {&"channel": &"A"})
	# A second, momentary one: machinery runs only while you hang on it.
	_spawn("res://src/machines/hook_switch.tscn", "HookSwitch",
		Vector2(70 * T, (FLOOR_ROW - 7) * T), {&"channel": &"B", &"momentary": true})

	# Channel A: a lift and a slider, and a door that opens with them.
	_spawn("res://src/machines/moving_platform.tscn", "MovingPlatform",
		Vector2(78 * T, (FLOOR_ROW - 2) * T), {&"channel": &"A", &"travel": Vector2(0, -56), &"seconds": 2.2})
	_spawn("res://src/machines/moving_platform.tscn", "MovingPlatform",
		Vector2(84 * T, (FLOOR_ROW - 9) * T), {&"channel": &"A", &"travel": Vector2(56, 0), &"seconds": 2.6, &"phase": 0.25})
	_doorway(92)
	_spawn("res://src/machines/powered_door.tscn", "PoweredDoor",
		Vector2(92 * T + 4, (FLOOR_ROW - 1) * T - 13), {&"channel": &"A"})

	# Channel B: a gate that shuts while you hang, and the wheel.
	_doorway(97)
	_spawn("res://src/machines/powered_door.tscn", "PoweredDoor",
		Vector2(97 * T + 4, (FLOOR_ROW - 1) * T - 13), {&"channel": &"B", &"inverted": true})
	_spawn("res://src/machines/ferris_wheel.tscn", "FerrisWheel",
		Vector2(103 * T, (FLOOR_ROW - 7) * T), {&"channel": &"A", &"cars": 5, &"radius": 42.0, &"seconds": 9.0})


## A gap in the ceiling run above a doorway, so a door has something to fill.
func _doorway(x: int) -> void:
	for y in range(FLOOR_ROW - 8, FLOOR_ROW - 3):
		tiles.set_cell(Vector2i(x, y), 0, SOLID)
		tiles.set_cell(Vector2i(x + 1, y), 0, SOLID)


# ---------------------------------------------------------------------------
# tiles and furniture
# ---------------------------------------------------------------------------
func _ground(x0: int, x1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(FLOOR_ROW, BOTTOM_ROW + 1):
			tiles.set_cell(Vector2i(x, y), 0, SOLID_TOP if y == FLOOR_ROW else SOLID)


func _wall(x: int) -> void:
	for y in range(FLOOR_ROW - 14, FLOOR_ROW):
		tiles.set_cell(Vector2i(x, y), 0, SOLID)


func _label(text: String, x: int, y: int, alpha := 0.3) -> void:
	var label := Label.new()
	label.name = "Label%d" % level_root.get_child_count()
	label.text = text
	label.position = Vector2(x, y)
	label.modulate = Color(1, 1, 1, alpha)
	level_root.add_child(label)


func _rooms() -> void:
	var holder := Node2D.new()
	holder.name = "Rooms"
	level_root.add_child(holder)
	var room := Node2D.new()
	room.name = "RoomA"
	room.set_script(load("res://src/room.gd"))
	room.set(&"screens", Vector2i(2, 1))
	holder.add_child(room)


## The bits every level needs: someone to play, something to look through, and
## the rescue bookkeeping the HUD reads.
func _support() -> void:
	var tracker := Node.new()
	tracker.name = "RescueTracker"
	tracker.set_script(load("res://src/rescue/rescue_tracker.gd"))
	tracker.set(&"stage_id", &"workshop")
	level_root.add_child(tracker)

	var alert := Node.new()
	alert.name = "Alert"
	alert.set_script(load("res://src/rescue/alert.gd"))
	alert.set(&"running", false)
	level_root.add_child(alert)

	var player := _spawn("res://src/player.tscn", "Player", Vector2(4 * T, FLOOR_ROW * T))
	var cam := Camera2D.new()
	cam.name = "RoomCamera"
	cam.set_script(load("res://src/room_camera.gd"))
	cam.set(&"target", player)
	level_root.add_child(cam)

	var hud := (load("res://src/ui/hud.tscn") as PackedScene).instantiate()
	hud.name = "HUD"
	level_root.add_child(hud)


func _spawn(path: String, base_name: String, at: Vector2, props := {}) -> Node2D:
	counts[base_name] = counts.get(base_name, 0) + 1
	var node := (load(path) as PackedScene).instantiate() as Node2D
	node.name = "%s%d" % [base_name, counts[base_name]]
	node.position = at
	for key in props:
		node.set(key, props[key])
	level_root.add_child(node)
	return node


func _assign_owner(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		if child.owner != null:
			continue
		child.owner = scene_root
		if child.scene_file_path == "":
			_assign_owner(child, scene_root)
