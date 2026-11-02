class_name Power
extends RefCounted
## The wiring between hook switches and the machinery they drive.
##
## A machine names a `channel`; every HookSwitch on that channel drives it. No
## node paths to keep in step, so a switch and its doors can be moved, copied or
## deleted without re-linking anything -- and one switch can drive a whole
## roomful of machines by sharing a channel.

## Hooks `machine` up to every switch on its channel and reports the power state
## to start in. `on_changed` is called with the raw switch state whenever it
## flips.
static func connect_channel(machine: Node, channel: StringName, on_changed: Callable) -> bool:
	var live := false
	for node in machine.get_tree().get_nodes_in_group(&"switches"):
		if node.channel != channel:
			continue
		if not node.toggled.is_connected(on_changed):
			node.toggled.connect(on_changed)
		live = live or node.on
	return live
