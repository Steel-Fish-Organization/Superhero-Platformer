extends GameTest
## Twin-stick and mouse aiming: where shots go, which way the hero faces, and
## how the game decides which device is doing the aiming.
##
## Note: the headless display server doesn't implement cursor hiding, so the
## OS-cursor half of mouse aiming can't be checked here.

const FLOOR_Y := 432.0
const START := Vector2(100.0, FLOOR_Y)

var shot: Node
var mouse_target := Vector2.ZERO


func setup() -> void:
	place(START)


func step(f: int) -> bool:
	match f:
		# ---- straight ahead, as Mega Man ---------------------------------
		5:
			check("aim starts straight", player.aim_mode == player.AimMode.STRAIGHT)
			check("straight aim follows facing", player.aim_dir == Vector2(player.facing, 0.0))
			check("reticle hidden when aiming straight", not player.reticle.visible)

		# ---- right stick --------------------------------------------------
		10:
			press(&"aim_up")
		13:
			check("right stick takes over aiming", player.aim_mode == player.AimMode.STICK)
			check("aim points up", player.aim_dir.distance_to(Vector2.UP) < 0.01, str(player.aim_dir))
			check("reticle sits above the hero",
				player.reticle.visible and player.reticle.global_position.y < player.global_position.y - 40.0,
				"reticle=%s" % player.reticle.global_position)
			player._fire_cooldown = 0.0
			press(&"fire")
		14:
			release(&"fire")
		16:
			shot = newest_shot()
			check("shots fly where you aim", shot != null and shot.velocity.y < -250.0 and absf(shot.velocity.x) < 1.0,
				"vel=%s" % (shot.velocity if shot else "none"))
			release(&"aim_up")
			press(&"aim_left", 0.7)
			press(&"aim_down", 0.7)
		20:
			check("diagonal aim", player.aim_dir.x < -0.6 and player.aim_dir.y > 0.6, str(player.aim_dir))
			check("the hero turns to face the aim", player.facing == -1)
			release(&"aim_left")
			release(&"aim_down")
		23:
			check("letting the stick go returns to straight aim",
				player.aim_mode == player.AimMode.STRAIGHT and not player.reticle.visible)

		# ---- aiming while moving the other way ---------------------------
		30:
			place(START)
			press(&"aim_right")
			press(&"move_left")
		40:
			check("you can back away while aiming forward",
				player.facing == 1 and player.velocity.x < 0.0,
				"facing=%d vel.x=%.1f" % [player.facing, player.velocity.x])
			release(&"aim_right")
			release(&"move_left")

		# ---- the bomb still lobs relative to the aim ---------------------
		45:
			place(START)
			player.weapon_index = 1      # bomb
			player._fire_cooldown = 0.0
			press(&"aim_right")
		48:
			press(&"fire")
		49:
			release(&"fire")
		51:
			shot = newest_shot()
			check("the bomb still arcs upward when aimed level",
				shot != null and shot.velocity.x > 0.0 and shot.velocity.y < 0.0,
				"vel=%s" % (shot.velocity if shot else "none"))
			release(&"aim_right")
			player.weapon_index = 0

		# ---- mouse --------------------------------------------------------
		60:
			place(START)
			mouse_target = START + Vector2(-60.0, -60.0)
		62:
			mouse_to(mouse_target, Vector2(4.0, 0.0))     # a nudge, not a move
		64:
			check("a nudge doesn't hijack aiming", player.aim_mode == player.AimMode.STRAIGHT)
			mouse_to(mouse_target, Vector2(30.0, 0.0))
		66:
			check("moving the mouse takes over aiming", player.aim_mode == player.AimMode.MOUSE)
			check_near("the mouse maps to the world", player.get_global_mouse_position().distance_to(mouse_target), 0.0, 2.0)
			check("aim points at the cursor", player.aim_dir.x < -0.5 and player.aim_dir.y < -0.5, str(player.aim_dir))
			check("the hero faces the cursor", player.facing == -1)
			player._fire_cooldown = 0.0
			press(&"fire")
		67:
			release(&"fire")
		69:
			shot = newest_shot()
			var want := (mouse_target - (player.global_position + Vector2(0.0, -16.0))).normalized()
			check("shots fly at the cursor",
				shot != null and shot.velocity.normalized().distance_to(want) < 0.05,
				"vel=%s want=%s" % [shot.velocity.normalized() if shot else "none", want])
		# picking the controller back up
		75:
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_A
			event.pressed = true
			Input.parse_input_event(event)
		78:
			check("touching the controller hands aiming back", player.aim_mode == player.AimMode.STRAIGHT)
			return true
	return false
