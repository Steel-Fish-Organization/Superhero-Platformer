extends GameTest
## Which animation plays for which state, and -- the part that actually broke --
## whether it plays at all.
##
## Setting `anim_spr.animation` picks an animation without starting playback, so
## for a while the sprite only animated while you were walking: ducking from a
## standstill froze on frame 0, idle never moved, and a jump from standing never
## reached its falling animation.

const FLOOR_Y := 432.0

var spr: AnimatedSprite2D


func setup() -> void:
	spr = player.anim_spr
	place(Vector2(100.0, FLOOR_Y))


func last_frame() -> int:
	return spr.sprite_frames.get_frame_count(spr.animation) - 1


func state() -> String:
	return "%s frame=%d/%d playing=%s" % [spr.animation, spr.frame, last_frame(), spr.is_playing()]


func step(f: int) -> bool:
	match f:
		# ---- standing still ------------------------------------------------
		5:
			check("standing plays the idle animation", spr.animation == &"idle", state())
			check("and it actually animates", spr.is_playing(), state())

		# ---- ducking from a standstill -------------------------------------
		10:
			press(&"move_down")
		14:
			check("holding down plays the duck animation", spr.animation == &"duck", state())
		30:
			check("which runs all the way to its last frame",
				spr.animation == &"duck" and spr.frame == last_frame(), state())
			check("and holds there instead of looping", not spr.is_playing(), state())
			release(&"move_down")
		34:
			check("standing up goes back to idle", spr.animation == &"idle" and spr.is_playing(), state())

		# ---- ducking out of a walk, which always worked --------------------
		40:
			press(&"move_right")
		48:
			check("walking plays the walk cycle", spr.animation == &"walk" and spr.is_playing(), state())
			press(&"move_down")
		70:
			check("ducking out of a walk still completes",
				spr.animation == &"duck" and spr.frame == last_frame(), state())
			release(&"move_down")
			release(&"move_right")

		# ---- a jump from standing still ------------------------------------
		80:
			place(Vector2(100.0, FLOOR_Y))
		83:
			press(&"jump")
		88:
			check("jumping plays the jump animation", spr.animation == &"jump", state())
			release(&"jump")
		110:
			check("falling hands over to the fall animation",
				spr.animation == &"fall" and spr.is_playing(), state())

		# ---- sliding --------------------------------------------------------
		130:
			place(Vector2(100.0, FLOOR_Y))
		133:
			press(&"slide")
		134:
			release(&"slide")
		140:
			check("sliding plays the slide animation", spr.animation == &"slide" and spr.is_playing(), state())
		180:
			check("and standing up afterwards returns to idle",
				spr.animation == &"idle" and spr.is_playing(), state())
			return true
	return false
