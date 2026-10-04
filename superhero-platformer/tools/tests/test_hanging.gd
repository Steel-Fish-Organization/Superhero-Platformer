extends GameTest
## Darkwing Duck style hanging: grabbing one-way platforms from below and hooks
## from any angle, shooting while hung, and getting off again.

const FLOOR_Y := 432.0
# Room A's one-way platforms: tiles 74-79 top edge y=400 (x 592-640), and
# tiles 82-87 top edge y=368 (x 656-696).
const LOW_PLAT_TOP := 400.0
const LOW_PLAT_X := 600.0
const HIGH_PLAT_X := 676.0
const HIGH_PLAT_TOP := 368.0

var hook: Node2D
var shot: Node
var mark := Vector2.ZERO


func setup() -> void:
	hook = node("Hook1")        # room A, over the pit
	place(Vector2(LOW_PLAT_X, FLOOR_Y))


func step(f: int) -> bool:
	match f:
		# ---- grabbing a one-way platform from underneath -----------------
		5:
			press(&"jump")
		6:
			release(&"jump")
		18:
			check("jumping into a one-way platform grabs it", player.hanging)
			check_near("you hang just under it", player.global_position.y, LOW_PLAT_TOP + 4.0 + player.hang_drop, 3.0)
			check("and you stop falling", absf(player.velocity.y) < 0.01)
			mark = player.global_position
		# shooting while hung
		20:
			press(&"aim_left", 0.7)
			press(&"aim_down", 0.7)
			player._fire_cooldown = 0.0
		22:
			press(&"fire")
		23:
			release(&"fire")
		25:
			shot = newest_shot()
			check("you can shoot down-left while hanging",
				shot != null and shot.velocity.x < 0.0 and shot.velocity.y > 0.0,
				"vel=%s" % (shot.velocity if shot else "none"))
			check("shooting doesn't shake you off", player.hanging and player.global_position.is_equal_approx(mark))
			release(&"aim_left")
			release(&"aim_down")
		# up climbs on top
		30:
			press(&"move_up")
		33:
			release(&"move_up")
		40:
			check_near("up pulls you onto the platform", player.global_position.y, LOW_PLAT_TOP, 1.5)
			check("and you're standing on it", player.is_on_floor() and not player.hanging)

		# ---- jumping off, without snapping straight back on --------------
		50:
			place(Vector2(LOW_PLAT_X, FLOOR_Y))
		53:
			press(&"jump")
		54:
			release(&"jump")
		66:
			check("hanging again", player.hanging)
			press(&"jump")
		67:
			release(&"jump")
		69:
			check("jump lets go and launches you", not player.hanging and player.velocity.y < -100.0,
				"vel=%s" % player.velocity)
		74:
			check("and you don't re-grab the same platform", not player.hanging,
				"regrab=%.2f same=%.2f" % [player._regrab, player._last_grab])

		# ---- down drops off ----------------------------------------------
		90:
			place(Vector2(HIGH_PLAT_X, FLOOR_Y))
		93:
			press(&"jump")       # held, for a full-height jump
		101:
			release(&"jump")
		106:
			check("hanging under the higher platform", player.hanging and player.global_position.y < 410.0,
				"y=%.1f" % player.global_position.y)
			press(&"move_down")
		107:
			release(&"move_down")
		113:
			check("down drops you without a jump", not player.hanging and player.velocity.y > 0.0,
				"vel=%s" % player.velocity)
		# a free mid-air jump after dropping would mean stale ground state
		115:
			press(&"jump")
		116:
			release(&"jump")
		118:
			check("dropping off gives you no free mid-air jump", player.velocity.y > 0.0,
				"vel.y=%.1f" % player.velocity.y)

		# ---- solid ceilings are not grabbable ----------------------------
		130:
			place(Vector2(500.0, FLOOR_Y))      # under the slide tunnel's solid roof
		133:
			press(&"jump")
		141:
			release(&"jump")
		150:
			check("a solid ceiling can't be grabbed", not player.hanging)

		# ---- hooks, from any angle ---------------------------------------
		160:
			# launched hard enough to clear the hook: a jump that peaks just short
			# of it is a level-design problem, not a grab bug
			place(hook.global_position + Vector2(0.0, 50.0))
			player.velocity = Vector2(0.0, -240.0)
		178:
			check("rising into a hook grabs it", player.hanging)
			check("you hang centred under it",
				absf(player.global_position.x - hook.global_position.x) < 0.01
				and absf(player.global_position.y - (hook.global_position.y + player.hang_drop)) < 0.01,
				"pos=%s hook=%s" % [player.global_position, hook.global_position])
		185:
			place(hook.global_position + Vector2(0.0, -40.0))
			player.velocity = Vector2(0.0, 120.0)
		200:
			check("falling onto a hook grabs it too", player.hanging)
		205:
			place(hook.global_position + Vector2(-40.0, 20.0))
			player.velocity = Vector2(160.0, 0.0)
		215:
			check("drifting sideways into a hook grabs it", player.hanging)
			press(&"move_up")
		220:
			check("up on a hook does nothing -- there's no top to climb", player.hanging)
			release(&"move_up")

		# ---- hook to hook -------------------------------------------------
		240:
			var middle: Node2D = node("Hook3")
			place(middle.global_position + Vector2(0.0, player.hang_drop))
			player._grab(middle.global_position, INF, middle)
		245:
			check("hanging on room C's middle hook", player.hanging)
			press(&"jump")
			press(&"move_right")
		246:
			release(&"jump")
		290:
			check("you can jump from one hook to the next",
				player.hanging and player._hang_hook == node("Hook4"),
				"hanging=%s at %s" % [player.hanging, player.global_position])
			release(&"move_right")
			return true
	return false
