@tool
extends AnimatableBody2D
## A platform that runs while its channel is powered, and stops dead when it
## isn't. Wire it to a HookSwitch by giving both the same `channel`.
##
## It's an AnimatableBody2D with sync_to_physics on, so anyone standing on it is
## carried along rather than sliding off.

## Where it goes, relative to where it was placed. (0, -64) is a lift.
@export var travel := Vector2(64.0, 0.0)
## Seconds for one leg of the trip.
@export var seconds := 2.0
## Which switch drives it, and whether power stops it rather than starts it.
@export var channel: StringName = &"A"
@export var inverted := false
## Runs even with no switch on its channel -- handy for a plain moving platform.
@export var always_on := false
## Where in its run it starts, 0 to 1. Stagger these so a row of platforms
## doesn't move as one.
@export_range(0.0, 1.0) var phase := 0.0

var powered := false

var _home := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	sync_to_physics = true
	_home = position
	_t = phase
	_place()
	if Engine.is_editor_hint():
		return
	powered = Power.connect_channel(self, channel, _on_switch) != inverted or always_on
	set_physics_process(true)


func _on_switch(switch_on: bool) -> void:
	powered = (switch_on != inverted) or always_on


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not powered:
		return
	_t = fmod(_t + delta / maxf(seconds * 2.0, 0.01), 1.0)
	_place()


## A there-and-back trip: 0 at home, 1 at the far end, and back again.
func _place() -> void:
	var leg := 1.0 - absf(_t * 2.0 - 1.0)
	position = _home + travel * leg
