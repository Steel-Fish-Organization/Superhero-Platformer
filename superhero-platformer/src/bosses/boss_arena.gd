class_name BossArena
extends Node2D
## Wraps a boss fight: the trigger, the shutter door, the camera lock and the
## stage-clear hand-off.
##
## Expected children:
##   Trigger  (Area2D)      -- the volume that starts the fight
##   Room     (CameraRoom)  -- optional; the camera locks to its rect
##   Door     (Node2D)      -- optional shutter that slides shut behind you

## The boss node. Leave empty to use the first Boss found under this arena.
@export var boss_path: NodePath
## Seconds the player stands still before the boss drops in.
@export var entry_pause: float = 0.6
## Music for the fight.
@export var boss_music: StringName = &"boss"
## Delay between the boss exploding and the stage-clear hand-off.
@export var clear_delay: float = 1.4

var boss: Boss
var started: bool = false
var _door_closed_y: float = 0.0

@onready var _trigger: Area2D = get_node_or_null(^"Trigger")
@onready var _room: CameraRoom = get_node_or_null(^"Room")
@onready var _door: Node2D = get_node_or_null(^"Door")


func _ready() -> void:
	boss = get_node_or_null(boss_path) as Boss
	if boss == null:
		boss = _first_boss(self)
	if boss:
		boss.defeated.connect(_on_boss_defeated)

	if _trigger:
		_trigger.collision_layer = Layers.TRIGGER
		_trigger.collision_mask = Layers.PLAYER
		_trigger.monitoring = true
		_trigger.body_entered.connect(_on_trigger_entered)

	if _door:
		_door_closed_y = _door.position.y
		_door.position.y -= 64.0   # start open, above the doorway


func _on_trigger_entered(body: Node) -> void:
	if started or not (body is Player):
		return
	started = true
	_run_sequence(body as Player)


func _run_sequence(who: Player) -> void:
	who.control_enabled = false
	who.velocity = Vector2.ZERO

	var cam := get_viewport().get_camera_2d() as GameCamera
	if cam and _room:
		cam.lock_to_rect(_room.world_rect())

	if _door:
		var tween := create_tween()
		tween.tween_property(_door, "position:y", _door_closed_y, 0.35)
		AudioManager.play_sfx(&"door")

	await get_tree().create_timer(entry_pause).timeout

	if boss == null:
		who.control_enabled = true
		return

	boss.begin_intro()
	await boss.intro_finished
	AudioManager.play_music(boss_music, true)
	who.control_enabled = true


func _on_boss_defeated(_boss: Boss) -> void:
	await get_tree().create_timer(clear_delay).timeout
	var level := get_tree().get_first_node_in_group(&"level")
	if level and level.has_method("complete_stage"):
		level.call("complete_stage")


func _first_boss(node: Node) -> Boss:
	for child in node.get_children():
		if child is Boss:
			return child as Boss
		var found := _first_boss(child)
		if found:
			return found
	return null
