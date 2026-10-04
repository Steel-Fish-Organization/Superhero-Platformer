extends SceneTree
## Rescue system checks. Run with:
##
##     godot --headless --fixed-fps 60 --path . --script tools/tests/test_rescue.gd

var level: Node
var player: CharacterBody2D
var tracker: Node
var alert: Node
var f := 0
var fails := 0
var banner := ""


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "   [" + detail + "]"))
	if not ok:
		fails += 1


func _initialize() -> void:
	level = load("res://levels/greybox.tscn").instantiate()
	root.add_child(level)
	player = level.get_node("Player")
	tracker = level.get_node("RescueTracker")
	alert = level.get_node("Alert")
	tracker.letter_found.connect(func(letter: String, who: String) -> void:
		banner = "%s/%s" % [who, letter])


## Stand next to someone (and bring the camera, which their danger timer needs).
func stand_by(civilian: Node2D, offset := Vector2(-10.0, 0.0)) -> void:
	player.global_position = civilian.global_position + offset
	player.velocity = Vector2.ZERO
	player.respawned.emit()


func _physics_process(_d: float) -> bool:
	f += 1
	var tunnel: Node2D = level.get_node_or_null("Civilian1")
	var ada: Node2D = level.get_node_or_null("Civilian2")
	var doomed: Node2D = level.get_node_or_null("Civilian3")

	match f:
		2:
			check("three civilians placed", tracker.total == 3, "total=%d" % tracker.total)
			check("nobody saved yet", tracker.saved == 0 and tracker.lost == 0)
			check("the named survivor carries the stage letter", ada.display_name == "Ada" and ada.letter == "G")
			check("only one of them is on a danger timer",
				tunnel.danger_time == 0.0 and ada.danger_time == 0.0 and doomed.danger_time > 0.0)
		# interact out of range does nothing
		5:
			player.global_position = tunnel.global_position + Vector2(90.0, 0.0)
			player.respawned.emit()
		7:
			Input.action_press(&"interact")
		8:
			Input.action_release(&"interact")
		10:
			check("interacting from across the room does nothing", tracker.saved == 0)
		# walk up and rescue
		12:
			stand_by(tunnel)
		15:
			Input.action_press(&"interact")
		16:
			Input.action_release(&"interact")
		18:
			check("interacting beside someone rescues them", tracker.saved == 1, "saved=%d" % tracker.saved)
			check("they run clear of the hero", tunnel.state == tunnel.State.FLEEING)
		100:
			check("once clear they're counted safe", tunnel.state == tunnel.State.SAFE and not tunnel.visible)
			check("no letter from an unnamed civilian", tracker.letters.is_empty())
		# the named survivor hands over the stage letter
		105:
			stand_by(ada)
		108:
			Input.action_press(&"interact")
		109:
			Input.action_release(&"interact")
		112:
			check("rescuing the named survivor yields the letter", tracker.letters == ["G"], str(tracker.letters))
			check("the HUD is told who it was", banner == "Ada/G", banner)
			check("two saved now", tracker.saved == 2)
		# the danger timer: only starts once they're on screen
		120:
			check("danger clock hasn't started off screen", doomed.time_left == doomed.danger_time,
				"left=%.1f of %.1f" % [doomed.time_left, doomed.danger_time])
			stand_by(doomed, Vector2(-70.0, 0.0))
		150:
			check("danger clock runs once seen", doomed.time_left < doomed.danger_time,
				"left=%.1f" % doomed.time_left)
			# run the clock down without going to them
			doomed.time_left = 0.2
		170:
			check("running out of time loses them", doomed.state == doomed.State.LOST and tracker.lost == 1,
				"state=%d lost=%d" % [doomed.state, tracker.lost])
			check("a lost civilian can't be rescued afterwards", tracker.saved == 2)
		175:
			Input.action_press(&"interact")
		176:
			Input.action_release(&"interact")
		178:
			check("interacting with the lost does nothing", tracker.saved == 2 and doomed.state == doomed.State.LOST)
			check("everyone is accounted for", tracker.all_resolved())

		# the alert level: the villain's head start
		180:
			check("alert starts at zero", alert.level == 0)
			check("no alert means normal enemy timing", is_equal_approx(alert.fire_scale(), 1.0))
			alert.seconds_per_level = 0.05   # speed it up for the test
		190:
			check("alert climbs with time spent", alert.level > 0, "level=%d" % alert.level)
			check("enemies get quicker with it", alert.fire_scale() < 1.0, "scale=%.2f" % alert.fire_scale())
			var drone: Node = level.get_node("Drone1")
			check("enemies read the level's alert", drone.alert_scale() < 1.0, "scale=%.2f" % drone.alert_scale())
		200:
			check("alert stops at its maximum", alert.level == alert.max_level, "level=%d" % alert.level)
			alert.reset()
		202:
			check("alert can be reset", alert.level == 0 and is_equal_approx(alert.fire_scale(), 1.0))
			print("\n%d failure(s)" % fails)
			return true
	return false
