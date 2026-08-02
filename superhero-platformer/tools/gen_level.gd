extends SceneTree
## Builder for levels/greybox.tscn. TileMap data can't be hand-written in a
## .tscn, which is why this exists.
##
##     godot --headless --path . --script tools/gen_level.gd
##
## WARNING: this OVERWRITES levels/greybox.tscn. Use it to reshape the level
## quickly while it's still throwaway; once you start editing greybox.tscn in
## the Godot editor, stop running this or you'll lose those edits.
##
## Layout, left to right, nothing blocking the section before it:
##   0..22    flat run
##   23..26   4-tile gap
##   27..46   jump heights: 2, 3 and 5 tiles (5 is the most a jump clears)
##   47..64   slide tunnel, 2-tile opening
##   65..82   one-way platforms
##   83..104  ladder up to a landing
##   105..108 gap
##   109..135 shooting gallery

const T := 8
const FLOOR := 24
const BOTTOM := 29
const WIDTH := 136

const SOLID := Vector2i(0, 0)
const SOLID_TOP := Vector2i(1, 0)
const LADDER := Vector2i(2, 0)
const LADDER_TOP := Vector2i(3, 0)
const ONEWAY := Vector2i(4, 0)
const BG := Vector2i(5, 0)

var level_root: Node2D
var tiles: TileMapLayer
var bg: TileMapLayer


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

	for x in WIDTH:
		for y in range(9, BOTTOM + 1):
			bg.set_cell(Vector2i(x, y), 0, BG)

	_ground(0, 22)
	_ground(27, 46)

	# jump-height reference: 2, 3 and 5 tiles
	_slab(32, 33, FLOOR - 2, FLOOR - 1)
	_slab(37, 38, FLOOR - 3, FLOOR - 1)
	_slab(42, 43, FLOOR - 5, FLOOR - 1)

	# slide tunnel -- the opening is 2 tiles, so only a slide gets through
	_ground(47, 64)
	_slab(52, 62, 15, FLOOR - 3)

	# one-way platforms: jump up through them, land on top
	_ground(65, 82)
	_oneway(68, 73, 20)
	_oneway(76, 81, 16)

	# ladder up to a landing with a hole to climb out of
	_ground(83, 104)
	_slab(88, 91, 11, 11)
	_slab(93, 97, 11, 11)
	for y in range(11, FLOOR):
		tiles.set_cell(Vector2i(92, y), 0, LADDER_TOP if y == 11 else LADDER)
	_ladder_area(92, 9, FLOOR - 1)

	# shooting gallery
	_ground(109, WIDTH - 1)
	_target(116, FLOOR - 1)
	_target(122, FLOOR - 1)
	_target(122, FLOOR - 3)
	_target(128, FLOOR - 1)
	_target(128, FLOOR - 3)
	_target(128, FLOOR - 5)

	_player(3)

	_assign_owner(level_root, level_root)
	var packed := PackedScene.new()
	packed.pack(level_root)
	print("greybox.tscn: ", error_string(ResourceSaver.save(packed, "res://levels/greybox.tscn")))
	quit()


func _ground(x0: int, x1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(FLOOR, BOTTOM + 1):
			tiles.set_cell(Vector2i(x, y), 0, SOLID_TOP if y == FLOOR else SOLID)


func _slab(x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			tiles.set_cell(Vector2i(x, y), 0, SOLID_TOP if y == y0 else SOLID)


func _oneway(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		tiles.set_cell(Vector2i(x, y), 0, ONEWAY)


func _ladder_area(x: int, y0: int, y1: int) -> void:
	var area := Area2D.new()
	area.name = "Ladder"
	area.collision_layer = 16       # layer 5, ladder
	area.collision_mask = 0
	area.monitoring = false
	var h := (y1 - y0 + 1) * T
	area.position = Vector2(x * T + T * 0.5, y0 * T + h * 0.5)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = Vector2(6, h)
	shape.shape = box
	area.add_child(shape)
	level_root.add_child(area)


var _target_count := 0


func _target(x: int, y: int) -> void:
	_target_count += 1
	var t := (load("res://src/target.tscn") as PackedScene).instantiate()
	# Name them explicitly, or Godot invents names like "@StaticBody2D@3".
	t.name = "Target%d" % _target_count
	t.position = Vector2(x * T + T * 0.5, y * T)
	level_root.add_child(t)


func _player(x: int) -> void:
	var p := (load("res://src/player.tscn") as PackedScene).instantiate()
	p.name = "Player"
	p.position = Vector2(x * T + T * 0.5, FLOOR * T)
	level_root.add_child(p)

	# The camera rides the player and is clamped to the level bounds -- no script
	# needed. Make the level wider and you just widen limit_right.
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(0, -12)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = WIDTH * T
	cam.limit_bottom = (BOTTOM + 1) * T
	p.add_child(cam)
	# Must be set by hand: _assign_owner deliberately doesn't descend into
	# instanced scenes, so a child added to one is dropped unless it has an owner.
	cam.owner = level_root


func _assign_owner(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		if child.owner != null:
			continue
		child.owner = scene_root
		if child.scene_file_path == "":
			_assign_owner(child, scene_root)
