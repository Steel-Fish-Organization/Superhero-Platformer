extends Node2D
## Turns ladder tiles into working ladders.
##
## Paint any tile that has the "ladder" custom data layer ticked, anywhere in the
## TileMapLayer, and this builds the climb volume for it at runtime. Vertically
## touching ladder tiles become one ladder; a gap starts a new one.
##
## Each ladder also gets a one-way platform across its top tile, so climbing to
## the top always leaves you something to stand on -- even a ladder that ends in
## mid-air. You can drop back onto the ladder from there by holding down.

## The tiles to scan. Falls back to a sibling named "Tiles".
@export var tile_layer: TileMapLayer
## Name of the bool custom data layer that marks a tile as climbable.
@export var data_layer := "ladder"
## Width of the climb volume. Narrower than a tile so you have to line up.
@export var climb_width := 6.0
## How far the volume sticks up above the top tile. This is what lets a player
## standing on the ladder top still press down to get back on.
@export var top_margin := 6.0
## Turn off if your levels always have real floor at the top of every ladder.
@export var add_top_platform := true
## Width of that ledge. A little wider than a tile so standing on it is comfy.
@export var top_platform_width := 16.0

const LADDER_LAYER := 16      # physics layer 5, "ladder"
const WORLD_LAYER := 1        # physics layer 1, "world"


func _ready() -> void:
	if tile_layer == null:
		tile_layer = get_parent().get_node_or_null(^"Tiles") as TileMapLayer
	if tile_layer == null:
		push_warning("Ladders: no TileMapLayer set and no sibling named 'Tiles'.")
		return
	for run in _find_runs():
		_build_ladder(run[0], run[1], run[2])


## Contiguous vertical runs of ladder tiles, as [column, top_row, bottom_row].
func _find_runs() -> Array:
	var columns := {}
	for cell in tile_layer.get_used_cells():
		var data := tile_layer.get_cell_tile_data(cell)
		if data == null:
			continue
		if not data.get_custom_data(data_layer):
			continue
		if not columns.has(cell.x):
			columns[cell.x] = []
		columns[cell.x].append(cell.y)

	var runs := []
	for x in columns:
		var rows: Array = columns[x]
		rows.sort()
		var start: int = rows[0]
		var prev: int = rows[0]
		for i in range(1, rows.size()):
			var y: int = rows[i]
			if y == prev + 1:
				prev = y
				continue
			runs.append([x, start, prev])
			start = y
			prev = y
		runs.append([x, start, prev])
	return runs


func _build_ladder(column: int, top_row: int, bottom_row: int) -> void:
	var t := float(tile_layer.tile_set.tile_size.x)
	var centre_x := column * t + t * 0.5
	var top_y := top_row * t                    # where a climber ends up standing
	var bottom_y := (bottom_row + 1) * t        # the very bottom of the ladder

	var area := Area2D.new()
	area.name = "Ladder_%d_%d" % [column, top_row]
	area.collision_layer = LADDER_LAYER
	area.collision_mask = 0
	area.monitoring = false                     # the player probes for it
	area.monitorable = true
	var height := (bottom_y - top_y) + top_margin
	area.position = Vector2(centre_x, top_y - top_margin + height * 0.5)
	area.add_child(_box(Vector2(climb_width, height)))
	# The player reads these to know where to dismount and where to stop.
	area.set_meta(&"top_y", top_y)
	area.set_meta(&"bottom_y", bottom_y)
	add_child(area)

	if add_top_platform:
		_build_top_platform(centre_x, top_y)


## A one-way ledge level with the top tile: you land on it climbing up, and pass
## straight back down through it when you grab the ladder again.
func _build_top_platform(centre_x: float, top_y: float) -> void:
	var body := StaticBody2D.new()
	body.name = "LadderTop"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = Vector2(centre_x, top_y)
	var shape := _box(Vector2(top_platform_width, 2.0))
	shape.position = Vector2(0.0, 1.0)          # top edge sits exactly on top_y
	shape.one_way_collision = true
	body.add_child(shape)
	add_child(body)


func _box(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	return shape
