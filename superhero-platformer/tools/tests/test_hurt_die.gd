extends GameTest
## Getting hit plays the hurt animation; running out of health plays the death
## animation, then respawns.

const FLOOR_Y := 432.0


func setup() -> void:
	place(Vector2(100.0, FLOOR_Y))


func step(f: int) -> bool:
	match f:
		5:
			player.take_damage(1)
		7:
			check("a hit plays the hurt animation", player.anim_spr.animation == &"hurt",
				player.anim_spr.animation)
		60:
			check("and it gives way once the stun ends", player.anim_spr.animation != &"hurt",
				player.anim_spr.animation)
		120:
			player.health = 1
			player.take_damage(1)
		122:
			check("a fatal hit plays the death animation", player.anim_spr.animation == &"die",
				player.anim_spr.animation)
			check("and doesn't respawn straight away", player.dying and player.health == 0)
			check("further hits are ignored while dying", not player.take_damage(1))
		240:
			check("the hero respawns once it finishes", not player.dying,
				"dying=%s" % player.dying)
			check("with full health", player.health == player.max_health, str(player.health))
			return true
	return false
