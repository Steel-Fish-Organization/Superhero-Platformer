extends GameTest
## The room camera: scrolling between rooms without a jump, surviving a respawn
## mid-scroll, refusing to scroll up without a ladder, and checkpoints.

const FLOOR_Y := 432.0

var watching := false
var last_centre := Vector2.ZERO
var biggest_step := 0.0


func setup() -> void:
	place(Vector2(100.0, FLOOR_Y))


func _physics_process(delta: float) -> bool:
	if watching:
		var centre := camera.get_screen_center_position()
		biggest_step = maxf(biggest_step, centre.distance_to(last_centre))
		last_centre = centre
	return super(delta)


func step(f: int) -> bool:
	match f:
		# ---- room A -> B, the horizontal scroll --------------------------
		5:
			place(Vector2(840.0, FLOOR_Y))
		8:
			last_centre = camera.get_screen_center_position()
			biggest_step = 0.0
			watching = true
			press(&"move_right")
		40:
			release(&"move_right")
		70:
			watching = false
			check("walking right scrolls into the next room", camera.current == node("Rooms/RoomB"))
			# a sine ease over 432px in 0.5s peaks near 22.6px/frame; the old bug
			# jumped 215px in one frame when the camera limits were freed
			check("the scroll never jumps", biggest_step < 30.0, "biggest step %.1f px" % biggest_step)
			check("and hands control back", not player.frozen)

		# ---- dying mid-scroll ---------------------------------------------
		80:
			place(Vector2(1285.0, FLOOR_Y))     # B, walking right into E
		83:
			press(&"move_right")
		100:
			release(&"move_right")
			check("a scroll is under way", camera.transitioning)
			player.respawn()
		140:
			check("respawning mid-scroll leaves you at the spawn point",
				player.global_position.distance_to(player._spawn_point) < 4.0,
				"at %s" % player.global_position)
			check("and the camera isn't stuck mid-scroll", not camera.transitioning and not player.frozen)

		# ---- up needs a ladder --------------------------------------------
		150:
			place(Vector2(1100.0, 250.0))       # room B, near its ceiling
			player.velocity.y = -300.0
		156:
			check("jumping above a room doesn't scroll up to it",
				camera.current == node("Rooms/RoomB") and not camera.transitioning,
				"current=%s" % camera.current.name)

		# ---- checkpoints ---------------------------------------------------
		170:
			place(Vector2(1300.0, FLOOR_Y))
		175:
			place(Vector2(1330.0, FLOOR_Y))     # over room E's checkpoint
		180:
			var checkpoint := node("Checkpoint3")
			check("walking past a checkpoint lights it", checkpoint.reached)
			player.respawn()
		183:
			check("and you respawn there",
				player.global_position.distance_to(node("Checkpoint3").global_position) < 1.0,
				str(player.global_position))
			check("with the camera in that room", camera.current == node("Rooms/RoomE"))
			return true
	return false
