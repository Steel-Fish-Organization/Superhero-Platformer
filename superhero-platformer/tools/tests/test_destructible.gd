extends SceneTree
## Tiles you can shoot away: one per plain shot, a hole per charged shot, and
## solid rock that survives both.
##
## Runs in the workshop rather than the greybox, since that's where the
## breakable tiles are. Standalone for the same reason -- harness.gd loads the
## greybox.
##
##     godot --headless --fixed-fps 60 --path . --script tools/tests/test_destructible.gd

const LEVEL := "res://levels/workshop.tscn"
const T := 8

var level: Node
var tiles: TileMapLayer
var breakables: Node
var frame := 0
var failures := 0
var shot: Node
var before := 0


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "   [" + detail + "]"))
	if not ok:
		failures += 1


func _initialize() -> void:
	level = load(LEVEL).instantiate()
	root.add_child(level)
	tiles = level.get_node("Tiles")
	breakables = level.get_node("Breakables")
	breakables.regrow_after = 0.0        # keep holes open; regrowth is checked on its own


## How many cells of the wall at x 14..16 are still standing.
func wall_count() -> int:
	var standing := 0
	for x in range(14, 17):
		for y in range(18, 24):
			if tiles.get_cell_source_id(Vector2i(x, y)) != -1:
				standing += 1
	return standing


func cell_of(where: Vector2) -> Vector2i:
	return tiles.local_to_map(tiles.to_local(where))


func centre_of(cell: Vector2i) -> Vector2:
	return tiles.to_global(tiles.map_to_local(cell))


## Fires a projectile scene from `from` towards `dir`, and keeps hold of it.
func fire(scene: String, from: Vector2, dir: Vector2) -> void:
	shot = load(scene).instantiate()
	shot.offscreen_margin = 100000.0     # the camera isn't following this test
	level.add_child(shot)
	shot.launch(from, dir)


func _physics_process(_delta: float) -> bool:
	frame += 1
	var wall_cell := Vector2i(14, 21)
	var rock_cell := Vector2i(42, 20)

	match frame:
		2:
			check("the workshop has a breakable wall", wall_count() == 18, "%d cells" % wall_count())
			check("and the tile knows it's breakable",
				breakables.is_breakable(centre_of(wall_cell)))
			check("while plain rock doesn't", not breakables.is_breakable(centre_of(rock_cell)))

		# ---- a plain shot takes one tile ----------------------------------
		4:
			before = wall_count()
			fire("res://src/projectiles/pulse.tscn", centre_of(wall_cell) - Vector2(40, 0), Vector2.RIGHT)
		14:
			check("a plain shot clears exactly one tile", wall_count() == before - 1,
				"%d -> %d" % [before, wall_count()])
			check("the tile it hit is the one that went",
				tiles.get_cell_source_id(wall_cell) == -1)
			check("and the shot stops there", not is_instance_valid(shot) or shot._dead)

		# ---- a charged shot opens a hole ----------------------------------
		20:
			before = wall_count()
			fire("res://src/projectiles/pulse_full.tscn", centre_of(Vector2i(14, 19)) - Vector2(40, 0), Vector2.RIGHT)
		32:
			var gone := before - wall_count()
			check("a charged shot takes several tiles with it", gone >= 3, "%d tiles" % gone)

		# ---- solid rock is still solid ------------------------------------
		40:
			before = wall_count()
			fire("res://src/projectiles/pulse_full.tscn", centre_of(rock_cell) - Vector2(40, 0), Vector2.RIGHT)
		55:
			check("solid rock shrugs off a charged shot",
				tiles.get_cell_source_id(rock_cell) != -1)

		# ---- enemy fire leaves the level alone ----------------------------
		60:
			before = wall_count()
			fire("res://src/projectiles/enemy_shot.tscn", centre_of(Vector2i(16, 22)) - Vector2(40, 0), Vector2.RIGHT)
		75:
			check("enemy fire doesn't redecorate", wall_count() == before,
				"%d -> %d" % [before, wall_count()])

		# ---- walls that need more than one hit ----------------------------
		80:
			breakables.hits_to_break = 3
			before = wall_count()
			breakables.shatter(centre_of(Vector2i(15, 23)))
		82:
			check("a tougher wall survives the first hit", wall_count() == before)
			breakables.shatter(centre_of(Vector2i(15, 23)))
			breakables.shatter(centre_of(Vector2i(15, 23)))
		84:
			check("and goes on the third", wall_count() == before - 1,
				"%d -> %d" % [before, wall_count()])
			breakables.hits_to_break = 1

		# ---- regrowing ------------------------------------------------------
		90:
			breakables.regrow_after = 0.3
			before = wall_count()
			breakables.shatter(centre_of(Vector2i(16, 18)))
		92:
			check("a tile with regrowth still breaks", wall_count() == before - 1)
		115:
			check("and comes back afterwards", wall_count() == before,
				"%d, wanted %d" % [wall_count(), before])
			print("\n%d failure(s)" % failures)
			return true
	return false
