extends RefCounted
## Shared level-construction helpers for the generator scripts.
##
##     const Builder := preload("res://tools/stage_builder.gd")
##     var b := Builder.new("stage_01", "FOUNDRY DISTRICT")
##     b.ground(0, 20, 24, 29)
##     b.room("RoomA", 0, 0, 53, 29, true)
##     b.player_spawn(3, 24)
##     b.save()
##
## Loaded by path rather than class_name: a `--script` run does not reliably have
## the global class cache available. All coordinates are in TILES unless the
## parameter says otherwise.

const T := 8                  # tile size in pixels
const ROOM_H := 30            # one screen tall (240 / 8)
const SCREEN_W := 53          # one screen wide (426 / 8, rounded down)

const TILESET := "res://assets/tilesets/world_tileset.tres"
const LEVEL_SCRIPT := "res://src/level/level.gd"

# --- atlas coordinates in world_tileset.tres --------------------------------
const GROUND_TOP := Vector2i(1, 0)
const GROUND_FILL := Vector2i(4, 0)
const GROUND_L := Vector2i(0, 0)
const GROUND_R := Vector2i(2, 0)
const BLOCK := Vector2i(9, 0)
const SPIKE_UP := Vector2i(10, 0)
const SPIKE_DOWN := Vector2i(11, 0)
const LADDER := Vector2i(14, 0)
const LADDER_TOP := Vector2i(15, 0)
const PLATFORM_L := Vector2i(0, 2)
const PLATFORM_M := Vector2i(1, 2)
const PLATFORM_R := Vector2i(2, 2)
const ICE := Vector2i(3, 2)
const CONVEYOR_L := Vector2i(4, 2)
const CONVEYOR_R := Vector2i(5, 2)
const BREAKABLE := Vector2i(6, 2)
const BG_BRICK := Vector2i(0, 3)
const BG_PIPE := Vector2i(6, 3)

# --- scene paths ------------------------------------------------------------
const WALKER := "res://src/enemies/walker.tscn"
const HOPPER := "res://src/enemies/hopper.tscn"
const FLYER := "res://src/enemies/flyer.tscn"
const TURRET := "res://src/enemies/turret.tscn"
const BOSS := "res://src/bosses/bulwark.tscn"
const HEALTH_S := "res://src/items/pickup_health_small.tscn"
const HEALTH_L := "res://src/items/pickup_health_large.tscn"
const ENERGY_S := "res://src/items/pickup_energy_small.tscn"
const ENERGY_L := "res://src/items/pickup_energy_large.tscn"
const ONE_UP := "res://src/items/pickup_life.tscn"
const E_TANK := "res://src/items/pickup_e_tank.tscn"
const W_TANK := "res://src/items/pickup_w_tank.tscn"

var stage_id: String
var root: Node2D
var tiles: TileMapLayer
var bg_tiles: TileMapLayer
var rooms: Node2D
var entities: Node2D
var labels: Node2D


func _init(id: String, display: String, music: StringName = &"stage",
		level_script: String = LEVEL_SCRIPT) -> void:
	stage_id = id
	var tileset: TileSet = load(TILESET)

	root = Node2D.new()
	root.name = "Level"
	root.set_script(load(level_script))
	root.set(&"stage_id", StringName(id))
	root.set(&"display_name", display)
	root.set(&"music", music)

	bg_tiles = TileMapLayer.new()
	bg_tiles.name = "Background"
	bg_tiles.tile_set = tileset
	bg_tiles.z_index = -10
	bg_tiles.collision_enabled = false   # visual only (`enabled` would hide it too)
	root.add_child(bg_tiles)

	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = tileset
	root.add_child(tiles)

	rooms = Node2D.new()
	rooms.name = "Rooms"
	root.add_child(rooms)

	entities = Node2D.new()
	entities.name = "Entities"
	root.add_child(entities)

	labels = Node2D.new()
	labels.name = "Labels"
	labels.z_index = 20
	root.add_child(labels)


# ---------------------------------------------------------------------------
# tiles
# ---------------------------------------------------------------------------
func tile(x: int, y: int, atlas: Vector2i) -> void:
	tiles.set_cell(Vector2i(x, y), 0, atlas)


func bg(x: int, y: int, atlas: Vector2i) -> void:
	bg_tiles.set_cell(Vector2i(x, y), 0, atlas)


## Solid ground from x0..x1 inclusive, surface at top_y, filled down to bottom_y.
func ground(x0: int, x1: int, top_y: int, bottom_y: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(top_y, bottom_y + 1):
			var atlas := GROUND_FILL
			if y == top_y:
				atlas = GROUND_TOP
				if x == x0:
					atlas = GROUND_L
				elif x == x1:
					atlas = GROUND_R
			tile(x, y, atlas)


## A rectangle of solid blocks -- floating slabs, ceilings, walls.
func slab(x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			tile(x, y, BLOCK if y > y0 else GROUND_TOP)


## Thin platform you can jump up through.
func platform(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		var atlas := PLATFORM_M
		if x == x0:
			atlas = PLATFORM_L
		elif x == x1:
			atlas = PLATFORM_R
		tile(x, y, atlas)


## Spike tiles plus the kill volume that goes with them.
func spikes(x0: int, x1: int, y: int, ceiling: bool = false) -> void:
	for x in range(x0, x1 + 1):
		tile(x, y, SPIKE_DOWN if ceiling else SPIKE_UP)
	var top := float(y * T) if ceiling else float(y * T) + 3.0
	hazard(Rect2(Vector2(x0 * T, top), Vector2((x1 - x0 + 1) * T, T - 3.0)))


## Ladder tiles plus the climbable area.
func ladder(x: int, y0: int, y1: int) -> Node:
	for y in range(y0, y1 + 1):
		tile(x, y, LADDER_TOP if y == y0 else LADDER)
	return ladder_area(x, y0, y1)


func bg_fill(x0: int, x1: int, y0: int, y1: int, atlas: Vector2i = BG_BRICK) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			bg(x, y, atlas)


# ---------------------------------------------------------------------------
# entities
# ---------------------------------------------------------------------------
func player_spawn(tile_x: int, tile_y: int) -> Marker2D:
	var m := Marker2D.new()
	m.name = "PlayerSpawn"
	m.position = Vector2(tile_x * T + T * 0.5, tile_y * T)
	root.add_child(m)
	return m


func camera() -> Camera2D:
	var cam := Camera2D.new()
	cam.name = "GameCamera"
	cam.set_script(load("res://src/level/game_camera.gd"))
	root.add_child(cam)
	return cam


func room(name_str: String, x0: int, y0: int, x1: int, y1: int, start: bool = false,
		parent: Node = null, props: Dictionary = {}) -> Node:
	var area := Area2D.new()
	area.name = name_str
	area.set_script(load("res://src/level/camera_room.gd"))
	area.set(&"is_start_room", start)
	for key in props:
		area.set(StringName(key), props[key])
	var w := (x1 - x0 + 1) * T
	var h := (y1 - y0 + 1) * T
	area.position = Vector2(x0 * T + w * 0.5, y0 * T + h * 0.5)
	area.add_child(_box_shape(Vector2(w, h)))
	(parent if parent else rooms).add_child(area)
	return area


## Rect is in PIXELS.
func hazard(rect: Rect2, parent: Node = null, props: Dictionary = {}) -> Node:
	var area := Area2D.new()
	area.name = "Hazard"
	area.set_script(load("res://src/level/hazard.gd"))
	area.position = rect.position + rect.size * 0.5
	for key in props:
		area.set(StringName(key), props[key])
	area.add_child(_box_shape(rect.size))
	(parent if parent else entities).add_child(area)
	return area


func ladder_area(tile_x: int, y0: int, y1: int) -> Node:
	var area := Area2D.new()
	area.name = "Ladder"
	area.set_script(load("res://src/level/ladder.gd"))
	var h := (y1 - y0 + 1) * T
	area.position = Vector2(tile_x * T + T * 0.5, y0 * T + h * 0.5)
	area.add_child(_box_shape(Vector2(6, h)))
	entities.add_child(area)
	return area


func checkpoint(tile_x: int, tile_y: int) -> Node:
	var area := Area2D.new()
	area.name = "Checkpoint"
	area.set_script(load("res://src/level/checkpoint.gd"))
	area.position = Vector2(tile_x * T + T * 0.5, tile_y * T - T)
	area.add_child(_box_shape(Vector2(16, 48)))
	entities.add_child(area)
	return area


func spawner(scene_path: String, tile_x: int, tile_y: int, props: Dictionary = {}) -> Node:
	var s := Node2D.new()
	s.name = "Spawner"
	s.set_script(load("res://src/level/spawner.gd"))
	s.set(&"scene", load(scene_path))
	s.position = Vector2(tile_x * T + T * 0.5, tile_y * T)
	for key in props:
		s.set(StringName(key), props[key])
	entities.add_child(s)
	return s


func item(scene_path: String, tile_x: int, tile_y: int) -> Node:
	var node := (load(scene_path) as PackedScene).instantiate()
	node.position = Vector2(tile_x * T + T * 0.5, tile_y * T - T * 0.5)
	entities.add_child(node)
	return node


func moving_platform(tile_x: int, tile_y: int, width_tiles: int, waypoints: Array,
		props: Dictionary = {}) -> Node:
	var body := AnimatableBody2D.new()
	body.name = "MovingPlatform"
	body.set_script(load("res://src/level/moving_platform.gd"))
	body.position = Vector2(tile_x * T, tile_y * T)
	var typed: Array[Vector2] = []
	for w in waypoints:
		typed.append(w)
	body.set(&"waypoints", typed)
	for key in props:
		body.set(StringName(key), props[key])

	var size := Vector2(width_tiles * T, T)
	body.add_child(_box_shape(size))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load("res://assets/sprites/px.png")
	sprite.scale = size / 8.0
	sprite.modulate = Color(0.85, 0.6, 0.25)
	body.add_child(sprite)

	# The area that detects riders, one pixel proud of the top surface.
	var rider := Area2D.new()
	rider.name = "RiderArea"
	rider.position = Vector2(0, -T * 0.5 - 2)
	rider.add_child(_box_shape(Vector2(size.x, 6)))
	body.add_child(rider)

	entities.add_child(body)
	return body


## World-space caption. Handy for a greybox scene; harmless anywhere else.
func label(text: String, tile_x: int, tile_y: int, color: Color = Color(1, 0.9, 0.4),
		size: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(tile_x * T, tile_y * T)
	l.set(&"theme_override_font_sizes/font_size", size)
	l.set(&"theme_override_colors/font_color", color)
	l.set(&"theme_override_colors/font_shadow_color", Color(0, 0, 0, 0.8))
	l.set(&"theme_override_constants/shadow_offset_x", 1)
	l.set(&"theme_override_constants/shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(l)
	return l


func boss_arena(trigger_x: int, room_x0: int, room_x1: int, boss_x: int, floor_y: int,
		boss_scene: String = BOSS) -> Node:
	var arena := Node2D.new()
	arena.name = "BossArena"
	arena.set_script(load("res://src/bosses/boss_arena.gd"))
	root.add_child(arena)

	var trigger := Area2D.new()
	trigger.name = "Trigger"
	trigger.position = Vector2(trigger_x * T, (floor_y - 12) * T)
	trigger.add_child(_box_shape(Vector2(16, 24 * T)))
	arena.add_child(trigger)

	room("Room", room_x0, 0, room_x1, ROOM_H - 1, false, arena)

	var boss := (load(boss_scene) as PackedScene).instantiate()
	boss.name = "Boss"
	boss.position = Vector2(boss_x * T, floor_y * T)
	arena.add_child(boss)
	arena.set(&"boss_path", NodePath("Boss"))
	return arena


# ---------------------------------------------------------------------------
# output
# ---------------------------------------------------------------------------
func save(path: String = "") -> bool:
	var out := path if path != "" else "res://levels/%s.tscn" % stage_id
	_assign_owner(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		printerr("pack failed for %s: %s" % [stage_id, error_string(err)])
		root.free()
		return false
	err = ResourceSaver.save(packed, out)
	if err != OK:
		printerr("save failed for %s: %s" % [out, error_string(err)])
	else:
		print("  ", out)
	root.free()
	return err == OK


func _box_shape(size: Vector2, shape_name: String = "Shape") -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = shape_name
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	return shape


func _assign_owner(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		if child.owner != null:
			continue
		child.owner = scene_root
		# Do not descend into instanced scenes -- they pack as instances.
		if child.scene_file_path == "":
			_assign_owner(child, scene_root)
