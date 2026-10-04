extends GameTest
## The abilities rescues unlock: double jump, air dash and the hook boost.
##
## Each one is checked twice -- locked, where it must do nothing at all, and
## unlocked, where it must do its thing. An ability that works before you earn
## it is the same bug as one that doesn't work after.

const FLOOR_Y := 432.0
const START := Vector2(100.0, FLOOR_Y)

var state: Node
var peak := 0.0
var mark := 0.0
var launch := Vector2.ZERO


func setup() -> void:
	state = root.get_node_or_null(^"GameState")
	if state:
		state.save_path = "user://test_abilities.json"
		state.reset(true)
	place(START)


func grant(id: StringName) -> void:
	state.unlock(state.library[id])


## Jumps, holding the button, and reports how high the hero got.
func jump_and_track(f: int, start_frame: int) -> void:
	if f == start_frame:
		place(START)
		peak = FLOOR_Y
	elif f == start_frame + 2:
		press(&"jump")
	elif f > start_frame + 2:
		peak = minf(peak, player.global_position.y)


func step(f: int) -> bool:
	if state == null:
		check("GameState autoload present", false)
		return true

	# ---- double jump --------------------------------------------------------
	jump_and_track(f, 5)
	match f:
		16:
			release(&"jump")   # let go, so the next press is a fresh one
		18:
			press(&"jump")      # a second press, mid-air
		19:
			release(&"jump")
		40:
			check("locked: a second jump does nothing", player.global_position.y > FLOOR_Y - 75.0,
				"reached %.1f px up" % (FLOOR_Y - peak))
			release(&"jump")
			mark = FLOOR_Y - peak
			grant(&"double_jump")
			check("the upgrade reaches the hero", player.has_ability(&"double_jump"))
	jump_and_track(f, 45)
	match f:
		56:
			release(&"jump")
		58:
			press(&"jump")      # held: letting go early would cut it short
		70:
			release(&"jump")
		85:
			check("unlocked: the second jump lifts you higher", FLOOR_Y - peak > mark + 20.0,
				"%.1f px vs %.1f px locked" % [FLOOR_Y - peak, mark])
			release(&"jump")
		88:
			check("but only one extra jump", player._air_jumps_used >= player._air_jumps_allowed())
		# landing gives it back
		92:
			place(START)
		95:
			check("landing recharges it", player._air_jumps_used == 0)

		# ---- air dash -------------------------------------------------------
		100:
			place(START)
			player.velocity = Vector2(0.0, -200.0)
			mark = player.global_position.x
		102:
			press(&"slide")
		103:
			release(&"slide")
		106:
			check("locked: the slide button in mid-air does nothing",
				not player.dashing and absf(player.global_position.x - mark) < 8.0,
				"moved %.1f" % (player.global_position.x - mark))
			grant(&"air_dash")
		110:
			place(START)
			player.velocity = Vector2(0.0, -200.0)
			player.facing = 1
			mark = player.global_position.x
		112:
			press(&"slide")
		113:
			release(&"slide")
		115:
			check("unlocked: it dashes", player.dashing)
			check("the dash is flat -- no falling through it", absf(player.velocity.y) < 0.01)
			check_near("at dash speed", player.velocity.x, player.air_dash_speed, 1.0)
		125:
			check("the dash ends by itself", not player.dashing)
			check("and carries you forward", player.global_position.x - mark > 25.0,
				"moved %.1f" % (player.global_position.x - mark))
		127:
			check("one dash per trip through the air", player._air_dash_used)
			press(&"slide")
		128:
			release(&"slide")
		131:
			check("so a second dash is refused", not player.dashing)
		# dashing into a hook still grabs it
		140:
			# just inside dash range of the hook (a dash covers ~40px), and
			# airborne, since nothing is grabbed from the ground
			var hook: Node2D = node("Hook1")
			place(hook.global_position + Vector2(-45.0, player.hang_drop))
			player.facing = 1
			player.velocity = Vector2(0.0, -60.0)
		142:
			press(&"slide")
		143:
			release(&"slide")
		155:
			check("dashing into a hook still latches on", player.hanging,
				"dashing=%s pos=%s" % [player.dashing, player.global_position.round()])

		# ---- hook boost ------------------------------------------------------
		160:
			var hook: Node2D = node("Hook1")
			place(hook.global_position + Vector2(0.0, player.hang_drop))
			player._grab(hook.global_position, INF, hook)
			press(&"move_right")
		163:
			press(&"jump")
		164:
			release(&"jump")
		166:
			launch = player.velocity
		167:
			check("locked: letting go jumps normally",
				absf(launch.x) <= player.run_speed + 0.1 and launch.y < 0.0, "launch=%s" % launch)
			release(&"move_right")
			grant(&"hook_boost")
		170:
			var hook: Node2D = node("Hook1")
			place(hook.global_position + Vector2(0.0, player.hang_drop))
			player._grab(hook.global_position, INF, hook)
			press(&"move_right")
		173:
			press(&"jump")
		174:
			release(&"jump")
		175:
			check("unlocked: you launch off faster", player.velocity.x > launch.x + 20.0,
				"%.1f vs %.1f" % [player.velocity.x, launch.x])
			check("and higher", player.velocity.y < launch.y - 20.0,
				"%.1f vs %.1f" % [player.velocity.y, launch.y])
			release(&"move_right")

		# ---- everything together, and wiping it ------------------------------
		180:
			state.grant_all()
			check("F1's grant-all gives every upgrade on disk",
				state.unlocked.size() == state.library.size(), str(state.unlocked))
			check("including the abilities",
				player.has_ability(&"double_jump") and player.has_ability(&"air_dash")
				and player.has_ability(&"hook_boost"))
		182:
			state.reset(true)
		184:
			check("F2's wipe takes the abilities back", not player.has_ability(&"air_dash"),
				str(player._abilities))
			check("and the stats with them", is_equal_approx(player.charge_rate, 1.0),
				"charge_rate=%.2f" % player.charge_rate)
			return true
	return false
