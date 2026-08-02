extends SceneTree
## Builds the nine stage scenes in levels/.
##
##     godot --headless --path . --script tools/gen_stages.gd
##
## Stage 1 is a designed level; stages 2-9 are blockouts with the same structure
## so the stage select, bosses and save system are all exercised end to end.
##
## IMPORTANT: this overwrites levels/stage_*.tscn. Once you start editing a stage
## in the Godot editor, stop regenerating it (or drop it from the loop below).
## The greybox test level is built by tools/gen_sandbox.gd and is untouched here.

const Builder := preload("res://tools/stage_builder.gd")
## Loaded by path rather than class_name: a `--script` run does not reliably
## have the global class cache available.
const STAGE_LIB := preload("res://src/core/stage_library.gd")

const FLOOR := 24
const BOTTOM := Builder.ROOM_H - 1

var b


func _initialize() -> void:
	_build_stage_01()
	for i in range(2, 10):
		_build_blockout(i)
	print("Stages written to res://levels/")
	quit()


# ---------------------------------------------------------------------------
# STAGE 1 -- FOUNDRY DISTRICT (designed)
# ---------------------------------------------------------------------------
func _build_stage_01() -> void:
	b = Builder.new("stage_01", "FOUNDRY DISTRICT")
	b.camera()

	# ---- room A: x 0..53 -- teach run, jump, shoot -------------------------
	b.bg_fill(0, 53, 12, BOTTOM)
	b.ground(0, 17, FLOOR, BOTTOM)
	b.ground(22, 33, FLOOR, BOTTOM)          # gap to jump (4 tiles)
	b.ground(38, 53, FLOOR, BOTTOM)          # second gap (4 tiles)
	b.spikes(18, 21, BOTTOM)                 # spikes in the first pit
	b.slab(26, 29, FLOOR - 5, FLOOR - 5)     # shootable perch
	b.platform(34, 37, FLOOR - 3)            # stepping stone over the 2nd gap

	b.spawner(Builder.WALKER, 12, FLOOR)
	b.spawner(Builder.WALKER, 30, FLOOR)
	b.spawner(Builder.FLYER, 24, FLOOR - 10)
	b.spawner(Builder.HOPPER, 45, FLOOR)
	b.item(Builder.HEALTH_L, 27, FLOOR - 5)

	b.room("RoomA", 0, 0, 53, BOTTOM, true)

	# ---- room B: x 54..107 -- vertical climb + turrets ---------------------
	b.bg_fill(54, 107, 4, BOTTOM)
	b.ground(54, 63, FLOOR, BOTTOM)
	b.ground(64, 69, FLOOR - 4, BOTTOM)
	b.ground(70, 77, FLOOR - 8, BOTTOM)
	b.slab(78, 83, FLOOR - 8, BOTTOM)
	b.ground(84, 95, FLOOR - 12, BOTTOM)
	b.ground(96, 107, FLOOR, BOTTOM)
	b.spikes(96, 101, BOTTOM)

	b.ladder(80, FLOOR - 14, FLOOR - 9)
	b.platform(86, 90, FLOOR - 17)
	b.platform(92, 95, FLOOR - 20)

	b.spawner(Builder.TURRET, 66, FLOOR - 4)
	b.spawner(Builder.TURRET, 88, FLOOR - 17)
	b.spawner(Builder.WALKER, 74, FLOOR - 8)
	b.spawner(Builder.FLYER, 100, FLOOR - 14)
	b.spawner(Builder.HOPPER, 92, FLOOR - 12)
	b.checkpoint(60, FLOOR)
	b.item(Builder.E_TANK, 94, FLOOR - 20)

	b.room("RoomB", 54, 0, 107, BOTTOM)

	# ---- room C: boss corridor -------------------------------------------
	var c0 := 108
	var c1 := c0 + Builder.SCREEN_W - 1
	b.bg_fill(c0, c1, 6, BOTTOM)
	b.ground(c0, c1, FLOOR, BOTTOM)
	# arena wall so the fight stays contained
	for y in range(FLOOR - 18, FLOOR):
		b.tile(c1, y, Builder.BLOCK)
	b.checkpoint(c0 + 3, FLOOR)

	b.room("RoomC", c0, 0, c1, BOTTOM)
	b.boss_arena(c0 + 10, c0, c1, c1 - 10, FLOOR)

	b.player_spawn(3, FLOOR)
	b.save()


# ---------------------------------------------------------------------------
# STAGES 2-9 -- blockouts
# ---------------------------------------------------------------------------
func _build_blockout(index: int) -> void:
	var stage_id := "stage_%02d" % index
	var info: Dictionary = STAGE_LIB.info(StringName(stage_id))
	b = Builder.new(stage_id, String(info["stage"]))
	b.camera()

	var rng := RandomNumberGenerator.new()
	rng.seed = index * 977

	# ---- run-up room ------------------------------------------------------
	b.bg_fill(0, 53, 10, BOTTOM)
	var x := 0
	while x <= 53:
		var span: int = rng.randi_range(6, 12)
		var top: int = FLOOR - rng.randi_range(0, 4)
		b.ground(x, mini(x + span, 53), top, BOTTOM)
		if rng.randf() < 0.5 and x > 8:
			b.spawner(Builder.WALKER if rng.randf() < 0.6 else Builder.HOPPER, x + 2, top)
		if rng.randf() < 0.35:
			b.platform(x + 2, x + 5, top - 4)
		x += span + rng.randi_range(2, 4)     # the gap
	b.room("RoomA", 0, 0, 53, BOTTOM, true)

	# ---- second room ------------------------------------------------------
	b.bg_fill(54, 107, 10, BOTTOM)
	b.ground(54, 107, FLOOR, BOTTOM)
	for i in 4:
		var px: int = 58 + i * 12
		b.platform(px, px + 5, FLOOR - 4 - i * 3)
		b.spawner(Builder.FLYER if i % 2 == 0 else Builder.TURRET, px + 2, FLOOR - 5 - i * 3)
	b.checkpoint(58, FLOOR)
	b.room("RoomB", 54, 0, 107, BOTTOM)

	# ---- boss corridor ----------------------------------------------------
	var c0 := 108
	var c1 := c0 + Builder.SCREEN_W - 1
	b.bg_fill(c0, c1, 6, BOTTOM)
	b.ground(c0, c1, FLOOR, BOTTOM)
	for y in range(FLOOR - 18, FLOOR):
		b.tile(c1, y, Builder.BLOCK)
	b.checkpoint(c0 + 3, FLOOR)
	b.room("RoomC", c0, 0, c1, BOTTOM)
	b.boss_arena(c0 + 10, c0, c1, c1 - 10, FLOOR)

	b.player_spawn(3, FLOOR - 4)
	b.save()
