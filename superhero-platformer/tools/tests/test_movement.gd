extends GameTest
## Walking, the analog stick, crouching and sliding.
##
## Covers the bugs that were found by hand and must not come back: a half-tilted
## stick leaving `facing` at 0, chained slides turning into jumps, and the
## headroom check mistaking the floor for a ceiling.

# Room A: flat floor at y=432. The 2-tile slide tunnel spans x 480-552.
const FLOOR_Y := 432.0
const TUNNEL_IN := 462.0
const TUNNEL_OUT := 552.0

var mark := 0.0
var slide_frames := 0
var jumped := false
var chain_trial := 0
var chain_start := 0
var chain_offset := 0
var chain_slides := 0
var was_sliding := false
var chain_jumped: Array = []
var chain_missed: Array = []


func setup() -> void:
	place(Vector2(100.0, FLOOR_Y))


func step(f: int) -> bool:
	if player.sliding:
		slide_frames += 1
	match f:
		# ---- the analog stick is digital ---------------------------------
		5:
			press(&"move_left", 0.4)
		10:
			check("40% stick faces left", player.facing == -1, "facing=%d" % player.facing)
			check("40% stick walks at full speed", absf(player.velocity.x) == player.run_speed,
				"vel.x=%.1f" % player.velocity.x)
			release(&"move_left")
			press(&"move_right", 0.3)
		13:
			check("30% stick faces right", player.facing == 1)
			check("muzzle keeps its offset", player.muzzle.position.x == 10.0,
				"muzzle.x=%.1f" % player.muzzle.position.x)
			release(&"move_right")

		# ---- crouch ------------------------------------------------------
		20:
			place(Vector2(100.0, FLOOR_Y))
			press(&"move_down")
			press(&"move_right")
		23:
			check("holding down crouches at once", player.crouching)
			check("crouch uses the low hitbox", not player.slide_shape.disabled and player.stand_shape.disabled)
			mark = player.global_position.x
		35:
			check_near("crouching can't walk", player.global_position.x - mark, 0.0, 0.5)
			check("crouching still turns you", player.facing == 1)
			release(&"move_down")
		38:
			check("releasing down stands up", not player.crouching,
				"headroom=%s" % player._has_headroom())
			release(&"move_right")

		# ---- one slide on open ground lasts slide_time --------------------
		45:
			place(Vector2(100.0, FLOOR_Y))
			slide_frames = 0
		47:
			press(&"slide")
		48:
			release(&"slide")
		90:
			check_near("flat-ground slide lasts slide_time", float(slide_frames), player.slide_time * 60.0, 2.0)
			check("and stands up after", not player.sliding and not player.crouching)

		# ---- slide direction follows the push, not the aim ---------------
		95:
			place(Vector2(100.0, FLOOR_Y))
			press(&"aim_left")
			press(&"move_right")
		97:
			press(&"slide")
		98:
			release(&"slide")
			mark = player.global_position.x
		115:
			check("slide goes where you push", player.global_position.x - mark > 20.0,
				"moved %.1f" % (player.global_position.x - mark))
			check("while aiming the other way", player.facing == -1)
			release(&"aim_left")
			release(&"move_right")

		# ---- the slide tunnel --------------------------------------------
		130:
			place(Vector2(TUNNEL_IN, FLOOR_Y))
			press(&"move_right")
		133:
			press(&"slide")
		134:
			release(&"slide")
		290:
			check("a slide carries you through the 2-tile tunnel",
				player.global_position.x > TUNNEL_OUT + 6.0, "x=%.1f" % player.global_position.x)
			release(&"move_right")

	# ---- chained slides: never a jump, never a dropped press -------------
	if f >= 300:
		return _chain_step(f)
	return false


## Holds down and presses jump at every frame offset around the end of a slide.
## Each trial: any airborne frame is a bug, and so is a second slide that never
## starts.
func _chain_step(f: int) -> bool:
	var t := f - chain_start
	if chain_start == 0 or t >= 70:
		if chain_start != 0:
			if jumped:
				chain_jumped.append(chain_offset)
			if chain_slides < 2:
				chain_missed.append(chain_offset)
			chain_trial += 1
		if chain_trial > 16:
			check("chained slides never jump", chain_jumped.is_empty(), str(chain_jumped))
			check("chained slides never drop a press", chain_missed.is_empty(), str(chain_missed))
			return true
		chain_start = f
		chain_offset = chain_trial - 8
		chain_slides = 0
		was_sliding = false
		jumped = false
		place(Vector2(60.0, FLOOR_Y))
		player.facing = 1
		press(&"move_down")
		press(&"jump")
		return false

	if t == 1:
		release(&"jump")
	# second press, landing `chain_offset` frames either side of the slide's end
	if t == 26 + chain_offset:
		press(&"jump")
	if t == 27 + chain_offset:
		release(&"jump")
	if player.sliding and not was_sliding:
		chain_slides += 1
	was_sliding = player.sliding
	if t > 3 and player.velocity.y < -1.0:
		jumped = true
	if t == 69:
		release(&"move_down")
	return false
