extends SceneTree
## Builds the placeholder levels the stage graph points at, so routing can be
## proven before any of them has content.
##
##     godot --headless --path . --script tools/gen_stubs.gd
##
## Each stub is one screen: a floor, a name painted on the wall, two civilians
## (one on a clock), a goal, and the bookkeeping every level needs. That's enough
## to walk in, pick a path and walk out, which is all M2 needs them to do.
##
## WARNING: this OVERWRITES levels/<id>.tscn for every stage listed below. Once
## a stub becomes a real level, take it out of this list.

const T := 8
const SCREEN := Vector2i(54, 30)
const SOLID := Vector2i(0, 0)
const SOLID_TOP := Vector2i(1, 0)
const BG := Vector2i(5, 0)
const FLOOR_ROW := 24
const BOTTOM_ROW := 29

## Every stage the graph names except the greybox, which is a real level.
const STUBS: Array[Dictionary] = [
	{"id": &"rooftops", "name": "ROOFTOPS"},
	{"id": &"transit", "name": "MIDNIGHT TRANSIT"},
	{"id": &"undercity", "name": "UNDERCITY"},
	{"id": &"sky_spire", "name": "SKY REFINERY"},
	{"id": &"deep_channel", "name": "DEEP CHANNEL"},
	{"id": &"scrap_canyon", "name": "SCRAP CANYON"},
	{"id": &"citadel", "name": "CITADEL CORE"},
]

var root_node: Node2D
var tiles: TileMapLayer


func _initialize() -> void:
	for stub in STUBS:
		_build(stub["id"], stub["name"])
	quit()


func _build(id: StringName, display_name: String) -> void:
	var tileset: TileSet = load("res://assets/greybox/tileset.tres")
	root_node = Node2D.new()
	root_node.name = String(id).to_pascal_case()

	var bg := TileMapLayer.new()
	bg.name = "Background"
	bg.tile_set = tileset
	bg.z_index = -10
	bg.collision_enabled = false
	root_node.add_child(bg)

	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = tileset
	root_node.add_child(tiles)

	for x in range(0, SCREEN.x):
		for y in range(9, BOTTOM_ROW + 1):
			bg.set_cell(Vector2i(x, y), 0, BG)
		for y in range(FLOOR_ROW, BOTTOM_ROW + 1):
			tiles.set_cell(Vector2i(x, y), 0, SOLID_TOP if y == FLOOR_ROW else SOLID)
	# end walls, so you can't walk out of the world
	for y in range(FLOOR_ROW - 6, FLOOR_ROW):
		tiles.set_cell(Vector2i(0, y), 0, SOLID)
		tiles.set_cell(Vector2i(SCREEN.x - 1, y), 0, SOLID)

	_label(display_name)
	_rooms()
	_civilian(18, {&"display_name": "Bystander"})
	_civilian(30, {&"danger_time": 12.0})
	_populations()
	_add("res://src/level/stage_goal.tscn", "StageGoal", 48)
	_add("res://src/checkpoint.tscn", "Checkpoint", 6)
	_rescue_nodes(id)

	var player := _add("res://src/player.tscn", "Player", 4)
	_camera(player)
	_hud()

	_assign_owner(root_node, root_node)
	var packed := PackedScene.new()
	packed.pack(root_node)
	var path := "res://levels/%s.tscn" % id
	print("%s: %s" % [path, error_string(ResourceSaver.save(packed, path))])


## The stage's name painted across the back wall, so you can tell at a glance
## which stub the router dropped you into.
func _label(text: String) -> void:
	var label := Label.new()
	label.name = "StageName"
	label.text = text
	label.position = Vector2(60, 80)
	label.modulate = Color(1, 1, 1, 0.25)
	root_node.add_child(label)

	var note := Label.new()
	note.name = "StubNote"
	note.text = "placeholder stage - walk right to the exit"
	note.position = Vector2(60, 104)
	note.modulate = Color(1, 1, 1, 0.15)
	root_node.add_child(note)


func _rooms() -> void:
	var holder := Node2D.new()
	holder.name = "Rooms"
	root_node.add_child(holder)
	var room := Node2D.new()
	room.name = "RoomA"
	room.set_script(load("res://src/room.gd"))
	room.set(&"screens", Vector2i(1, 1))
	holder.add_child(room)


func _civilian(x: int, props := {}) -> void:
	_add("res://src/rescue/civilian.tscn", "Civilian", x, props)


## Even a placeholder stage shows which path you walked in on: a hero arrival
## finds one more person, a dark arrival finds two walkers in the way.
func _populations() -> void:
	var hero := _population("Pop_Hero", ["H"])
	_add("res://src/rescue/civilian.tscn", "Civilian", 42, {&"display_name": "Witness"}, hero)

	var dark := _population("Pop_Dark", ["D"])
	_add("res://src/enemies/walker.tscn", "Walker", 24, {}, dark)
	_add("res://src/enemies/walker.tscn", "Walker", 38, {}, dark)


func _population(name_str: String, paths: Array[String]) -> Node2D:
	var group := Node2D.new()
	group.name = name_str
	group.set_script(load("res://src/level/population.gd"))
	group.set(&"on_paths", paths)
	group.set(&"on_first_visit", false)
	root_node.add_child(group)
	return group


func _add(path: String, base_name: String, x: int, props := {}, parent: Node2D = null) -> Node2D:
	var node := (load(path) as PackedScene).instantiate() as Node2D
	node.name = "%s%d" % [base_name, root_node.get_child_count()]
	node.position = Vector2(x * T + T * 0.5, FLOOR_ROW * T)
	for key in props:
		node.set(key, props[key])
	var holder: Node2D = parent if parent != null else root_node
	holder.add_child(node)
	return node


func _rescue_nodes(id: StringName) -> void:
	var tracker := Node.new()
	tracker.name = "RescueTracker"
	tracker.set_script(load("res://src/rescue/rescue_tracker.gd"))
	tracker.set(&"stage_id", id)
	root_node.add_child(tracker)

	var alert := Node.new()
	alert.name = "Alert"
	alert.set_script(load("res://src/rescue/alert.gd"))
	root_node.add_child(alert)


func _camera(player: Node2D) -> void:
	var cam := Camera2D.new()
	cam.name = "RoomCamera"
	cam.set_script(load("res://src/room_camera.gd"))
	cam.set(&"target", player)
	root_node.add_child(cam)


func _hud() -> void:
	var hud := (load("res://src/ui/hud.tscn") as PackedScene).instantiate()
	hud.name = "HUD"
	root_node.add_child(hud)


func _assign_owner(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		if child.owner != null:
			continue
		child.owner = scene_root
		if child.scene_file_path == "":
			_assign_owner(child, scene_root)
