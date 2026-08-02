extends SceneTree
## Builder for levels/greybox.tscn. TileMap data can't be hand-written in a
## .tscn, which is why this exists.
##
##     godot --headless --path . --script tools/gen_level.gd
##
## WARNING: this OVERWRITES levels/greybox.tscn. Handy while the level is still
## throwaway; once you start editing greybox.tscn in the Godot editor, stop
## running this or you'll lose those edits.
##
## Four rooms on the screen grid (one screen = 54 x 30 tiles):
##
##            col 2        col 3
##   row 0    [ C ladder ][ D gallery ]
##   row 1    [ A start .. 2 screens ][ B ]
##
##   A -> B   horizontal transition
##   B -> C   vertical transition, climbed on the long ladder
##   C -> D   horizontal transition

const T := 8
const SCREEN := Vector2i(54, 30)          # tiles per screen at 432x240

const SOLID := Vector2i(0, 0)
const SOLID_TOP := Vector2i(1, 0)
const LADDER := Vector2i(2, 0)
const LADDER_TOP := Vector2i(3, 0)
const ONEWAY := Vector2i(4, 0)
const BG := Vector2i(5, 0)

# row 1 rooms (A, B): floor near the bottom of the lower screen
const LOW_FLOOR := 54
const LOW_BOTTOM := 59
# row 0 rooms (C, D): floor near the bottom of the upper screen
const HIGH_FLOOR := 24
const HIGH_BOTTOM := 29

var level_root: Node2D
var tiles: TileMapLayer
var bg: TileMapLayer
var target_count := 0


func _initialize() -> void:
	var tileset: TileSet = load("res://assets/greybox/tileset.tres")

	level_root = Node2D.new()
	level_root.name = "Greybox"

	bg = TileMapLayer.new()
	bg.name = "Background"
	bg.tile_set = tileset
	bg.z_index = -10
	bg.collision_enabled = false
	level_root.add_child(bg)

	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = tileset
	level_root.add_child(tiles)

	_room_a()
	_room_b()
	_room_c()
	_room_d()

	_ladders_node()
	_rooms_node()
	var player := _player(3, LOW_FLOOR)
	_camera(player)

	_assign_owner(level_root, level_root)
	var packed := PackedScene.new()
	packed.pack(level_root)
	print("greybox.tscn: ", error_string(ResourceSaver.save(packed, "res://levels/greybox.tscn")))
	quit()


# ---------------------------------------------------------------------------
# room A -- start, 2 screens wide: run, gap, jump ruler, slide tunnel,
#           one-way platforms, and a ladder that ends in mid-air
# ---------------------------------------------------------------------------
func _room_a() -> void:
	_bg_fill(0, 107, 39, LOW_BOTTOM)
	_ground(0, 22, LOW_FLOOR, LOW_BOTTOM)
	_ground(27, 107, LOW_FLOOR, LOW_BOTTOM)     # 4-tile gap at 23..26

	# jump-height ruler: 2, 4, 6, 8, 10 tiles. Deliberately runs past what the
	# jump can reach so it stays a measuring stick while you retune.
	for i in 5:
		var height := 2 + i * 2
		var px := 31 + i * 5
		_slab(px, px + 1, LOW_FLOOR - height, LOW_FLOOR - 1)

	# slide tunnel: a 2-tile opening, so only a slide gets through
	_slab(60, 68, LOW_FLOOR - 9, LOW_FLOOR - 3)

	# one-way platforms
	_oneway(74, 79, LOW_FLOOR - 4)
	_oneway(82, 87, LOW_FLOOR - 8)

	# a ladder ending in mid-air -- the ledge at its top is generated, not tiled
	_ladder_column(99, LOW_FLOOR - 10, LOW_FLOOR - 1)


# ---------------------------------------------------------------------------
# room B -- foot of the long ladder up to room C
# ---------------------------------------------------------------------------
func _room_b() -> void:
	_bg_fill(108, 161, 39, LOW_BOTTOM)
	_ground(108, 161, LOW_FLOOR, LOW_BOTTOM)
	# runs from just above this floor all the way to room C's floor level
	_ladder_column(130, HIGH_FLOOR, LOW_FLOOR - 1)
	_target(120, LOW_FLOOR - 1)
	_enemy(145, LOW_FLOOR - 8)


# ---------------------------------------------------------------------------
# room C -- top of the ladder. Its floor has a hole for the shaft.
# ---------------------------------------------------------------------------
func _room_c() -> void:
	_bg_fill(108, 161, 9, HIGH_BOTTOM)
	for x in range(108, 162):
		if x >= 129 and x <= 131:
			continue                            # 3-tile shaft around the ladder
		_column(x, HIGH_FLOOR, HIGH_BOTTOM)
	_oneway(140, 145, HIGH_FLOOR - 5)
	_oneway(150, 155, HIGH_FLOOR - 9)
	_enemy(145, HIGH_FLOOR - 12, 24.0)


# ---------------------------------------------------------------------------
# room D -- shooting gallery
# ---------------------------------------------------------------------------
func _room_d() -> void:
	_bg_fill(162, 215, 9, HIGH_BOTTOM)
	_ground(162, 215, HIGH_FLOOR, HIGH_BOTTOM)
	_target(175, HIGH_FLOOR - 1)
	_target(185, HIGH_FLOOR - 1)
	_target(185, HIGH_FLOOR - 3)
	_target(195, HIGH_FLOOR - 1)
	_target(195, HIGH_FLOOR - 3)
	_target(195, HIGH_FLOOR - 5)
	_enemy(170, HIGH_FLOOR - 10)
	_enemy(205, HIGH_FLOOR - 14, 20.0)


# ---------------------------------------------------------------------------
# tile helpers
# ---------------------------------------------------------------------------
func _column(x: int, top: int, bottom: int) -> void:
	for y in range(top, bottom + 1):
		tiles.set_cell(Vector2i(x, y), 0, SOLID_TOP if y == top else SOLID)


func _ground(x0: int, x1: int, top: int, bottom: int) -> void:
	for x in range(x0, x1 + 1):
		_column(x, top, bottom)


func _slab(x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		_column(x, y0, y1)


func _oneway(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		tiles.set_cell(Vector2i(x, y), 0, ONEWAY)


## Just paints tiles -- src/ladders.gd finds them and builds the climb volume.
func _ladder_column(x: int, top: int, bottom: int) -> void:
	for y in range(top, bottom + 1):
		tiles.set_cell(Vector2i(x, y), 0, LADDER_TOP if y == top else LADDER)


func _bg_fill(x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			bg.set_cell(Vector2i(x, y), 0, BG)


# ---------------------------------------------------------------------------
# nodes
# ---------------------------------------------------------------------------
func _ladders_node() -> void:
	var node := Node2D.new()
	node.name = "Ladders"
	node.set_script(load("res://src/ladders.gd"))
	node.set(&"tile_layer", tiles)
	level_root.add_child(node)


func _rooms_node() -> void:
	var holder := Node2D.new()
	holder.name = "Rooms"
	level_root.add_child(holder)
	# name, screen-grid cell, size in screens
	_room(holder, "RoomA", Vector2i(0, 1), Vector2i(2, 1))
	_room(holder, "RoomB", Vector2i(2, 1), Vector2i(1, 1))
	_room(holder, "RoomC", Vector2i(2, 0), Vector2i(1, 1))
	_room(holder, "RoomD", Vector2i(3, 0), Vector2i(1, 1))


func _room(holder: Node2D, name_str: String, cell: Vector2i, screens: Vector2i) -> void:
	var room := Node2D.new()
	room.name = name_str
	room.set_script(load("res://src/room.gd"))
	room.position = Vector2(cell * SCREEN * T)
	room.set(&"screens", screens)
	holder.add_child(room)


func _target(x: int, y: int) -> void:
	target_count += 1
	var node := (load("res://src/target.tscn") as PackedScene).instantiate()
	node.name = "Target%d" % target_count
	node.position = Vector2(x * T + T * 0.5, y * T)
	level_root.add_child(node)


var enemy_count := 0


func _enemy(x: int, y: int, drift := 0.0) -> void:
	enemy_count += 1
	var node := (load("res://src/enemy.tscn") as PackedScene).instantiate()
	node.name = "Enemy%d" % enemy_count
	node.position = Vector2(x * T + T * 0.5, y * T)
	node.set(&"drift_speed", drift)
	level_root.add_child(node)


func _player(x: int, y: int) -> Node2D:
	var p := (load("res://src/player.tscn") as PackedScene).instantiate()
	p.name = "Player"
	p.position = Vector2(x * T + T * 0.5, y * T)
	level_root.add_child(p)
	return p


func _camera(player: Node2D) -> void:
	var cam := Camera2D.new()
	cam.name = "RoomCamera"
	cam.set_script(load("res://src/room_camera.gd"))
	cam.set(&"target", player)
	level_root.add_child(cam)


func _assign_owner(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		if child.owner != null:
			continue
		child.owner = scene_root
		if child.scene_file_path == "":
			_assign_owner(child, scene_root)
