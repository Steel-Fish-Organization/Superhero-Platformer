extends SceneTree
## Builds levels/sandbox.tscn -- the greybox test level.
##
##     godot --headless --path . --script tools/gen_sandbox.gd
##
## Everything is laid out left to right in labelled sections so you can walk
## through and check one mechanic at a time. Re-run after editing this file; it
## overwrites levels/sandbox.tscn only.

const Builder := preload("res://tools/stage_builder.gd")

const FLOOR := 24
const BOTTOM := Builder.ROOM_H - 1

const HEAD := Color(1, 0.9, 0.35)     # section headings
const NOTE := Color(0.65, 0.85, 1.0)  # feature captions
const WARN := Color(1, 0.5, 0.5)      # hazards / caveats

var b


func _initialize() -> void:
	b = Builder.new("sandbox", "SANDBOX", &"stage", "res://src/level/sandbox.gd")
	b.camera()

	_section_movement(0, 77)
	_section_gaps(78, 160)
	_section_terrain(161, 248)
	_section_enemies(249, 326)
	_section_low_gravity(327, 404)
	_section_heavy(405, 482)
	_section_boss(483, 535)

	b.player_spawn(3, FLOOR)
	b.save()
	print("Sandbox written. Open levels/sandbox.tscn and press F6.")
	quit()


func _base(x0: int, x1: int, name_str: String, start: bool = false, props: Dictionary = {}) -> void:
	b.bg_fill(x0, x1, 8, BOTTOM)
	b.ground(x0, x1, FLOOR, BOTTOM)
	b.room(name_str, x0, 0, x1, BOTTOM, start, null, props)
	if not start:
		b.checkpoint(x0 + 4, FLOOR)


# ---------------------------------------------------------------------------
# 1. movement + jump height
# ---------------------------------------------------------------------------
func _section_movement(x0: int, x1: int) -> void:
	_base(x0, x1, "RoomMovement", true)
	b.label("1. MOVEMENT", x0 + 6, 9, HEAD, 12)
	b.label("run  X jump  Z fire (hold to charge)  C slide", x0 + 6, 11, NOTE)
	b.label("R respawn   T refill   Y take 4 dmg   U slow-mo", x0 + 6, 13, NOTE)

	# Pillars 1..6 tiles tall. A standing jump rises 47px, so 5 is the ceiling.
	b.label("JUMP HEIGHT - TILES (max clear = 5)", x0 + 12, 15, NOTE)
	for i in 6:
		var h := i + 1
		var px := x0 + 14 + i * 5
		b.slab(px, px + 1, FLOOR - h, FLOOR - 1)
		b.label(str(h), px, FLOOR - h - 2, HEAD)

	b.label("FLAT RUN", x0 + 50, 22, NOTE)


# ---------------------------------------------------------------------------
# 2. gap widths
# ---------------------------------------------------------------------------
func _section_gaps(x0: int, x1: int) -> void:
	b.bg_fill(x0, x1, 8, BOTTOM)
	b.room("RoomGaps", x0, 0, x1, BOTTOM)
	b.checkpoint(x0 + 4, FLOOR)
	b.label("2. GAP WIDTH - TILES (a running jump clears ~7)", x0 + 6, 9, HEAD, 12)
	b.label("spikes below = instant death, ignores i-frames", x0 + 6, 11, WARN)

	var x := x0
	b.ground(x, x + 7, FLOOR, BOTTOM)
	x += 8
	for gap in range(2, 8):
		b.spikes(x, x + gap - 1, BOTTOM)
		b.label(str(gap), x + gap / 2, FLOOR - 3, HEAD)
		x += gap
		b.ground(x, mini(x + 7, x1), FLOOR, BOTTOM)
		x += 8
	b.ground(mini(x, x1), x1, FLOOR, BOTTOM)


# ---------------------------------------------------------------------------
# 3. tunnels, ladders, platforms, hazards
# ---------------------------------------------------------------------------
func _section_terrain(x0: int, x1: int) -> void:
	_base(x0, x1, "RoomTerrain")
	b.label("3. TERRAIN", x0 + 6, 9, HEAD, 12)

	# 2-tile opening: only reachable by sliding
	b.slab(x0 + 5, x0 + 14, 16, FLOOR - 3)
	b.label("SLIDE - 2 TILES", x0 + 4, 15, NOTE)

	# 3-tile opening: walk through standing
	b.slab(x0 + 21, x0 + 30, 15, FLOOR - 4)
	b.label("WALK - 3 TILES", x0 + 20, 14, NOTE)

	# ladder up to a landing with a hole in it
	var lx := x0 + 39
	b.slab(lx - 4, lx - 1, 11, 11)
	b.slab(lx + 1, lx + 4, 11, 11)
	for y in range(11, FLOOR):
		b.tile(lx, y, Builder.LADDER_TOP if y == 11 else Builder.LADDER)
	b.ladder_area(lx, 9, FLOOR - 1)
	b.label("LADDER", lx - 3, 10, NOTE)

	# one-way platforms -- jump up through them, stand on top
	b.platform(x0 + 49, x0 + 54, 20)
	b.platform(x0 + 57, x0 + 62, 16)
	b.label("ONE-WAY", x0 + 49, 19, NOTE)

	# moving platforms: vertical lift and horizontal shuttle
	b.moving_platform(x0 + 67, 21, 4, [Vector2(0, -72)],
		{"speed": 34.0, "mode": 1, "wait_time": 0.5})
	b.moving_platform(x0 + 74, 21, 4, [Vector2(56, 0)],
		{"speed": 40.0, "mode": 1, "wait_time": 0.3})
	b.label("MOVING PLATFORMS", x0 + 66, 18, NOTE)

	# floor spikes
	b.spikes(x0 + 82, x0 + 85, FLOOR - 1)
	b.label("SPIKES", x0 + 82, FLOOR - 3, WARN)


# ---------------------------------------------------------------------------
# 4. enemies and pickups
# ---------------------------------------------------------------------------
func _section_enemies(x0: int, x1: int) -> void:
	_base(x0, x1, "RoomEnemies")
	b.label("4. ENEMIES + ITEMS", x0 + 6, 9, HEAD, 12)
	b.label("walk off-screen and back to respawn them", x0 + 6, 11, NOTE)

	b.spawner(Builder.WALKER, x0 + 8, FLOOR)
	b.label("WALKER", x0 + 7, FLOOR - 4, NOTE)

	b.spawner(Builder.HOPPER, x0 + 18, FLOOR)
	b.label("HOPPER", x0 + 17, FLOOR - 4, NOTE)

	b.spawner(Builder.FLYER, x0 + 28, FLOOR - 9)
	b.label("FLYER", x0 + 27, FLOOR - 13, NOTE)

	b.spawner(Builder.TURRET, x0 + 38, FLOOR)
	b.label("TURRET", x0 + 37, FLOOR - 5, NOTE)
	b.label("(armoured while shut - shots deflect)", x0 + 33, FLOOR - 7, WARN)

	b.spawner(Builder.WALKER, x0 + 50, FLOOR, {"chase": true, "speed": 48.0})
	b.label("CHASER", x0 + 49, FLOOR - 4, NOTE)

	var items := [
		[Builder.HEALTH_S, "HP+2"], [Builder.HEALTH_L, "HP+10"],
		[Builder.ENERGY_S, "WE+2"], [Builder.ENERGY_L, "WE+10"],
		[Builder.ONE_UP, "1UP"], [Builder.E_TANK, "E"], [Builder.W_TANK, "W"],
	]
	for i in items.size():
		var px := x0 + 58 + i * 3
		b.item(items[i][0], px, FLOOR)
		b.label(items[i][1], px - 1, FLOOR - 3, NOTE)


# ---------------------------------------------------------------------------
# 5 + 6. room modifiers
# ---------------------------------------------------------------------------
func _section_low_gravity(x0: int, x1: int) -> void:
	_base(x0, x1, "RoomLowGravity", false, {"gravity_scale": 0.4})
	b.label("5. LOW GRAVITY (gravity_scale 0.4)", x0 + 6, 9, HEAD, 12)
	b.label("set per CameraRoom - no code needed", x0 + 6, 11, NOTE)
	for i in 5:
		var px := x0 + 14 + i * 10
		b.platform(px, px + 4, FLOOR - 5 - i * 3)


func _section_heavy(x0: int, x1: int) -> void:
	_base(x0, x1, "RoomHeavy", false,
		{"gravity_scale": 1.7, "speed_scale": 0.6, "jump_scale": 0.9})
	b.label("6. HEAVY + SLOW (gravity 1.7, speed 0.6, jump 0.9)", x0 + 6, 9, HEAD, 12)
	b.label("the shape an underwater or mud room would take", x0 + 6, 11, NOTE)
	for i in 4:
		var px := x0 + 16 + i * 12
		b.slab(px, px + 3, FLOOR - 4, FLOOR - 1)


# ---------------------------------------------------------------------------
# 7. boss
# ---------------------------------------------------------------------------
func _section_boss(x0: int, x1: int) -> void:
	_base(x0, x1, "RoomBoss")
	b.label("7. BOSS", x0 + 6, 9, HEAD, 12)
	b.label("clearing here does NOT touch your save", x0 + 6, 11, NOTE)
	for y in range(FLOOR - 18, FLOOR):
		b.tile(x1, y, Builder.BLOCK)
	b.boss_arena(x0 + 12, x0, x1, x1 - 10, FLOOR)
