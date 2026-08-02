class_name Checkpoint
extends Area2D
## Invisible respawn marker. Mega Man places one at each major section break --
## drop these after a long climb or before a mini-boss.

@export var one_shot: bool = true
## Offset from this node to where the hero actually lands.
@export var spawn_offset: Vector2 = Vector2.ZERO

var _used: bool = false


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _used and one_shot:
		return
	if not (body is Player):
		return
	_used = true
	var level := get_tree().get_first_node_in_group(&"level")
	if level and level.has_method("set_checkpoint"):
		level.call("set_checkpoint", global_position + spawn_offset)
