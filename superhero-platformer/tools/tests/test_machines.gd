extends SceneTree
## Hook switches and the machinery they drive: hanging on one throws it, the
## machines on its channel follow, and a momentary switch only holds while
## someone's weight is on it.
##
## Runs in the workshop, where the machines are.
##
##     godot --headless --fixed-fps 60 --path . --script tools/tests/test_machines.gd

const LEVEL := "res://levels/workshop.tscn"

var level: Node
var player: CharacterBody2D
var latch: Node2D          # channel A, stays where you leave it
var deadman: Node2D        # channel B, only on while held
var lift: Node2D
var door_a: Node2D
var gate_b: Node2D
var wheel: Node2D

var frame := 0
var failures := 0
var mark := Vector2.ZERO
var mark_angle := 0.0


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "   [" + detail + "]"))
	if not ok:
		failures += 1


func _initialize() -> void:
	level = load(LEVEL).instantiate()
	root.add_child(level)
	player = level.get_node("Player1")
	latch = level.get_node("HookSwitch1")
	deadman = level.get_node("HookSwitch2")
	lift = level.get_node("MovingPlatform1")
	door_a = level.get_node("PoweredDoor1")
	gate_b = level.get_node("PoweredDoor2")
	wheel = level.get_node("FerrisWheel1")


## Puts the hero on a switch the way a jump into it would.
func grab(switch: Node2D) -> void:
	player.global_position = switch.global_position + Vector2(0.0, player.hang_drop)
	player._grab(switch.global_position, INF, switch)


func let_go() -> void:
	player._release(false)
	player.global_position += Vector2(0.0, 40.0)


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		2:
			check("the workshop has a switch on each channel",
				latch.channel == &"A" and deadman.channel == &"B")
			check("the latch starts off", not latch.on)
			check("so does its lift", not lift.powered)
			check("its door starts shut", not door_a.open)
			check("while the inverted gate starts open", gate_b.open,
				"gate open=%s" % gate_b.open)
			mark = lift.position
			mark_angle = wheel.angle

		# ---- nothing moves until something throws the switch -------------
		20:
			check("the lift stays put while the power is off",
				lift.position.is_equal_approx(mark), str(lift.position))
			check("and the wheel doesn't turn", is_equal_approx(wheel.angle, mark_angle))

		# ---- hang on the latch -------------------------------------------
		25:
			grab(latch)
		27:
			check("hanging on it starts pulling it down", latch.pull > 0.0, "pull=%.2f" % latch.pull)
		55:
			check("the handle reaches the bottom", latch.pull >= 1.0, "pull=%.2f" % latch.pull)
			check("which throws the switch", latch.on)
			check("the hero rides it down", player.global_position.y > latch._home.y,
				"player y=%.1f" % player.global_position.y)
			check("the lift starts running", lift.powered)
			check("the door opens", door_a.open)
			check("and the wheel turns", wheel.powered)
			mark = lift.position
			mark_angle = wheel.angle
		80:
			check("the lift has actually moved", not lift.position.is_equal_approx(mark),
				"%s -> %s" % [mark, lift.position])
			check("the wheel has actually turned", wheel.angle > mark_angle,
				"%.2f -> %.2f" % [mark_angle, wheel.angle])
			check("its cars stay level for riding",
				wheel.get_node("Car1").rotation == 0.0)

		# ---- a latch stays thrown after you let go -----------------------
		85:
			let_go()
		120:
			check("the handle springs back up", latch.pull <= 0.0, "pull=%.2f" % latch.pull)
			check("but the latch stays on", latch.on)
			check("so the machines keep running", lift.powered and door_a.open)

		# ---- hanging on it again turns it back off ------------------------
		125:
			grab(latch)
		160:
			check("a second pull turns it off", not latch.on)
			check("the lift stops", not lift.powered)
			check("and the door shuts", not door_a.open)
			mark = lift.position
		180:
			check("a stopped lift stays where it stopped",
				lift.position.is_equal_approx(mark), str(lift.position))
			let_go()

		# ---- the momentary switch ------------------------------------------
		200:
			check("the gate is open again", gate_b.open)
			grab(deadman)
		235:
			check("holding the deadman's handle turns it on", deadman.on, "pull=%.2f" % deadman.pull)
			check("which shuts the inverted gate", not gate_b.open)
			let_go()
		275:
			check("letting go turns it straight back off", not deadman.on)
			check("and the gate opens again", gate_b.open)
			print("\n%d failure(s)" % failures)
			return true
	return false
