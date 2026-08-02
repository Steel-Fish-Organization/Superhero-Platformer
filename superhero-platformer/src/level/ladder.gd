class_name Ladder
extends Area2D
## Climbable volume. Make it one tile (8px) wide and as tall as the ladder art;
## the player snaps to this node's x position while climbing.
##
## Add a second, short Ladder area one tile above the top so the hero can climb
## out onto the ledge, the same trick the NES games use.

@export var top_platform: bool = false


func _ready() -> void:
	collision_layer = Layers.LADDER
	collision_mask = 0
	monitoring = false
	monitorable = true
