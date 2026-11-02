@tool
extends Node2D
## Tiles you can shoot away. Paint any tile with the **`breakable`** custom data
## flag ticked and this erases it when it's hit; everything else shrugs the shot
## off, as before.
##
## A plain shot takes out the one tile it hits. A charged shot carries a
## `break_radius`, so it clears everything breakable within it -- same for a
## bomb's blast. Nothing else in the game knows about this: projectile.gd asks
## whatever is in the "breakables" group, and gets a no if there isn't one.
##
## Drop one of these into a level next to its TileMapLayer, the way Ladders works.

## A tile was destroyed, at its centre in world space.
signal tile_broken(where: Vector2)

## The tiles to scan. Falls back to a sibling named "Tiles".
@export var tile_layer: TileMapLayer
## Name of the bool custom data layer that marks a tile as shootable.
@export var data_layer := "breakable"
## Shots needed to clear one tile. 1 is a Mega Man block; raise it for walls that
## should take a few hits.
@export var hits_to_break := 1
## Seconds before a broken tile grows back. 0 leaves the hole for good.
@export var regrow_after := 0.0
## The puff left behind. Any scene; it's placed at the tile's centre.
@export var debris: PackedScene = preload("res://src/fx/explosion.tscn")
@export var debris_tint := Color(0.75, 0.72, 0.68)
@export var debris_scale := 0.55

## cell -> hits taken so far, for walls that need more than one shot.
var _hits: Dictionary = {}
## cell -> the tile that was there, for regrowing it.
var _broken: Dictionary = {}


func _ready() -> void:
	add_to_group(&"breakables")
	if tile_layer == null:
		tile_layer = get_parent().get_node_or_null(^"Tiles") as TileMapLayer
	if tile_layer == null and not Engine.is_editor_hint():
		push_warning("DestructibleTiles: no TileMapLayer set and no sibling named 'Tiles'.")


## The entry point for anything that wants to break tiles. `radius` of 0 means
## just the tile at `where`; anything larger clears every breakable tile whose
## centre falls inside. Returns how many tiles went.
func shatter(where: Vector2, radius := 0.0) -> int:
	if tile_layer == null:
		return 0
	var broken := 0
	if radius <= 0.0:
		return 1 if _hit_cell(_cell_at(where)) else 0

	var centre := _cell_at(where)
	var reach := int(ceil(radius / float(tile_layer.tile_set.tile_size.x)))
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var cell := centre + Vector2i(dx, dy)
			if _cell_centre(cell).distance_to(where) <= radius and _hit_cell(cell):
				broken += 1
	return broken


## True when there's a breakable tile here -- used by shots to decide whether
## they've hit something they can get through.
func is_breakable(where: Vector2) -> bool:
	return _is_breakable_cell(_cell_at(where))


func _cell_at(where: Vector2) -> Vector2i:
	return tile_layer.local_to_map(tile_layer.to_local(where))


func _cell_centre(cell: Vector2i) -> Vector2:
	return tile_layer.to_global(tile_layer.map_to_local(cell))


func _is_breakable_cell(cell: Vector2i) -> bool:
	var data := tile_layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data(data_layer)


## One hit on one cell. Returns true if the tile was destroyed by it.
func _hit_cell(cell: Vector2i) -> bool:
	if not _is_breakable_cell(cell):
		return false
	var hits: int = _hits.get(cell, 0) + 1
	if hits < hits_to_break:
		_hits[cell] = hits
		return false

	_hits.erase(cell)
	_broken[cell] = {
		"source": tile_layer.get_cell_source_id(cell),
		"atlas": tile_layer.get_cell_atlas_coords(cell),
		"alt": tile_layer.get_cell_alternative_tile(cell),
	}
	tile_layer.erase_cell(cell)
	var centre := _cell_centre(cell)
	_spawn_debris(centre)
	tile_broken.emit(centre)
	if regrow_after > 0.0:
		_regrow_later(cell)
	return true


func _regrow_later(cell: Vector2i) -> void:
	await get_tree().create_timer(regrow_after).timeout
	if not is_instance_valid(self) or not _broken.has(cell):
		return
	var was: Dictionary = _broken[cell]
	_broken.erase(cell)
	tile_layer.set_cell(cell, was["source"], was["atlas"], was["alt"])


func _spawn_debris(centre: Vector2) -> void:
	if debris == null:
		return
	var puff := debris.instantiate()
	if puff is Node2D:
		var fx := puff as Node2D
		fx.global_position = centre
		fx.scale = Vector2.ONE * debris_scale
		fx.modulate = debris_tint
	add_child(puff)
