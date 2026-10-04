extends GameTest
## Shooting, damage and enemies: charge tiers, shots versus one-way platforms,
## contact damage, and armour that shots glance off.

const FLOOR_Y := 432.0
# Room A's lower one-way platform: tiles 74-79, top edge y=400.
const PLAT_TOP := 400.0
const PLAT_X := 600.0
# Room A's mid-air ladder at tile 99: its generated top ledge is at y=352.
const LEDGE := Vector2(796.0, 352.0)

var shot: Node
var before := 0
var turret: Node


func setup() -> void:
	place(Vector2(100.0, FLOOR_Y))


## Fires a projectile scene directly, for the cases where driving the hero's
## own gun would be fiddly.
func fire_at(from: Vector2, dir: Vector2, scene := "res://src/projectiles/pulse.tscn") -> void:
	shot = load(scene).instantiate()
	level.add_child(shot)
	shot.launch(from, dir)


func shot_alive() -> bool:
	return is_instance_valid(shot) and not shot._dead


func step(f: int) -> bool:
	match f:
		# ---- the buster and its charge tiers ------------------------------
		5:
			press(&"fire")
		6:
			release(&"fire")
		8:
			check("tapping fire shoots", newest_shot() != null)
			check_near("the shot leaves at weapon speed", newest_shot().velocity.x, 300.0, 1.0)
		10:
			press(&"fire")       # a second buster shot, then hold to charge
		11:
			release(&"fire")
		12:
			press(&"fire")
		90:                      # ~1.3s held: full charge
			release(&"fire")
		92:
			var tiers := live_shots().map(func(s): return s.get_meta(&"weapon").display_name)
			check("a charged shot still fires with buster shots on screen",
				tiers.has("Pulse (full charge)"), str(tiers))
		200:
			check("shots are cleared once off screen", live_shots().is_empty(),
				"%d still alive" % live_shots().size())

		# ---- one-way platforms don't stop bullets ------------------------
		205:
			place(Vector2(PLAT_X, FLOOR_Y))
		207:
			fire_at(Vector2(PLAT_X, PLAT_TOP + 20.0), Vector2.UP)
		214:
			check("shots pass up through a one-way platform",
				shot_alive() and shot.global_position.y < PLAT_TOP - 8.0,
				"y=%.1f" % (shot.global_position.y if is_instance_valid(shot) else NAN))
		216:
			fire_at(Vector2(PLAT_X, PLAT_TOP - 8.0), Vector2.DOWN)
		223:
			check("and down through it as well",
				shot_alive() and shot.global_position.y > PLAT_TOP + 12.0,
				"y=%.1f" % (shot.global_position.y if is_instance_valid(shot) else NAN))
		225:
			place(LEDGE + Vector2(0.0, 40.0))
		227:
			fire_at(LEDGE + Vector2(0.0, 16.0), Vector2.UP)
		234:
			check("and through a generated ladder-top ledge",
				shot_alive() and shot.global_position.y < LEDGE.y - 8.0,
				"y=%.1f" % (shot.global_position.y if is_instance_valid(shot) else NAN))
		# but solid tiles still stop them
		240:
			place(Vector2(300.0, FLOOR_Y))
		242:
			fire_at(Vector2(300.0, FLOOR_Y - 12.0), Vector2.DOWN)
		252:
			check("solid ground still stops a shot", not shot_alive())
		254:
			fire_at(Vector2(460.0, 400.0), Vector2.RIGHT)   # into the tunnel block
		264:
			check("a solid wall still stops a shot", not shot_alive())
		# a ricochet bounces off solid ground, not off one-way platforms
		266:
			fire_at(Vector2(300.0, 400.0), Vector2(0.7, 0.7), "res://src/projectiles/ricochet.tscn")
		280:
			check("a ricochet still bounces off solid ground",
				shot_alive() and shot.velocity.y < 0.0,
				"vel=%s" % (shot.velocity if is_instance_valid(shot) else "gone"))

		# ---- contact damage -----------------------------------------------
		300:
			place(Vector2(1000.0, FLOOR_Y))     # room B
		302:
			var drone: Node2D = node("Drone1")
			drone.set_physics_process(false)
			drone.global_position = player.global_position + Vector2(4.0, -12.0)
			before = player.health
		305:
			check("touching an enemy hurts", player.health < before, "%d -> %d" % [before, player.health])
			before = player.health
		# i-frames are 1.2s; still overlapping afterwards must hurt again
		400:
			check("still standing in them hurts again once the i-frames end",
				player.health < before, "%d -> %d" % [before, player.health])
			node("Drone1").queue_free()
			player.health = player.max_health

		# ---- armour: shots glance off a closed turret --------------------
		410:
			turret = node("Turret1")
			place(Vector2(turret.global_position.x - 100.0, FLOOR_Y))
			turret._phase = 0            # CLOSED
			turret._timer = 5.0
			turret.invulnerable = true
			before = turret.health
		412:
			fire_at(turret.global_position + Vector2(-40.0, -5.0), Vector2.RIGHT)
		440:
			check("a closed turret takes no damage", turret.health == before,
				"%d -> %d" % [before, turret.health])
			check("the shot glances off instead of vanishing",
				not is_instance_valid(shot) or shot._deflected,
				"deflected=%s" % (shot._deflected if is_instance_valid(shot) else "shot gone"))
		442:
			turret.invulnerable = false
			fire_at(turret.global_position + Vector2(-40.0, -5.0), Vector2.RIGHT)
		450:
			check("an open one does take damage", turret.health < before, "hp=%d" % turret.health)

		# ---- enemies die and leave an explosion --------------------------
		460:
			var walker := node("Walker1")
			place(walker.global_position + Vector2(-40.0, 0.0))
			walker.take_damage(99)
		462:
			check("a dead enemy is gone", node("Walker1") == null)
			check("and leaves an explosion",
				level.get_children().any(func(n): return n.name.begins_with("Explosion")))
			return true
	return false
