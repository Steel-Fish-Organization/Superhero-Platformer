class_name CameraRoom
extends Area2D
## A screen (or a corridor of several screens) the camera is allowed to show.
##
## Place these over the level so they tile the playable space without
## overlapping. Give each one a RectangleShape2D child; sizes should be
## multiples of 8 so the camera never lands on a half pixel. The camera scrolls
## between rooms the moment the player crosses a boundary.

## Rooms flagged as the start point are what the camera snaps to on spawn.
@export var is_start_room: bool = false
## Optional music override while inside this room.
@export var music: StringName = &""
## Rooms can change the feel of the space -- water levels, low gravity, etc.
@export var gravity_scale: float = 1.0
@export var speed_scale: float = 1.0
@export var jump_scale: float = 1.0

@onready var _shape: CollisionShape2D = get_node_or_null(^"Shape")


func _ready() -> void:
	add_to_group(&"camera_rooms")
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)


func world_rect() -> Rect2:
	if _shape == null:
		_shape = get_node_or_null(^"Shape") as CollisionShape2D
	if _shape == null or not (_shape.shape is RectangleShape2D):
		push_warning("CameraRoom '%s' needs a CollisionShape2D named Shape with a RectangleShape2D." % name)
		return Rect2(global_position, GameCamera.VIEW_SIZE)
	var size: Vector2 = (_shape.shape as RectangleShape2D).size
	var centre := _shape.global_position
	return Rect2(centre - size * 0.5, size)


func contains(point: Vector2) -> bool:
	return world_rect().has_point(point)


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	var level := _find_level()
	if level and level.has_method("enter_room"):
		level.call("enter_room", self, body)


func _find_level() -> Node:
	var n: Node = self
	while n:
		if n.has_method("enter_room"):
			return n
		n = n.get_parent()
	return null
