class_name Spawner
extends Node2D
## Off-screen enemy spawner, reproducing the NES behaviour: an enemy exists only
## while its spot is near the visible screen, and scrolling away and back gives
## you a fresh one.
##
## Put this where the enemy should stand and point `scene` at the enemy. Turn
## `respawns` off for anything that should stay dead once killed.

@export var scene: PackedScene
## Spawns once the spot is within this many pixels of the screen edge.
@export var spawn_margin: float = 24.0
## Despawns once it is this far outside -- larger than spawn_margin so an enemy
## sitting on the boundary does not flicker in and out.
@export var despawn_margin: float = 96.0
@export var respawns: bool = true
## Delay before a killed enemy may come back, in seconds.
@export var respawn_cooldown: float = 0.5
## Draw a marker in the editor so empty spawners are visible.
@export var editor_gizmo: bool = true

var _instance: Node2D
var _killed: bool = false
var _cooldown: float = 0.0
var _check: float = 0.0


func _ready() -> void:
	add_to_group(&"spawners")
	if Engine.is_editor_hint():
		return
	set_process(true)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	# 10 Hz is plenty for spawn checks and keeps big stages cheap.
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.1

	var rect := _screen_rect()
	if rect.size == Vector2.ZERO:
		return

	if is_instance_valid(_instance):
		if not rect.grow(despawn_margin).has_point(global_position):
			_instance.queue_free()
			_instance = null
			# Leaving the screen resets a "killed" enemy, exactly like the NES games.
			_killed = false
		return

	if _killed and not respawns:
		return
	if _cooldown > 0.0:
		return
	if rect.grow(spawn_margin).has_point(global_position):
		_spawn()


func _spawn() -> void:
	if scene == null:
		return
	var node := scene.instantiate()
	if not (node is Node2D):
		push_warning("Spawner '%s' expects a Node2D scene." % name)
		return
	_instance = node as Node2D
	_instance.global_position = global_position
	get_parent().add_child(_instance)
	if _instance is Enemy:
		(_instance as Enemy).died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: Enemy) -> void:
	_killed = true
	_instance = null
	_cooldown = respawn_cooldown


func _screen_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2()
	var size := GameCamera.VIEW_SIZE
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)


func _draw() -> void:
	if not editor_gizmo or not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-6, -6, 12, 12), Color(1, 0.4, 0.4, 0.6), false, 1.0)
