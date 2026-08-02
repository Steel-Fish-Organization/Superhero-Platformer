class_name Level
extends Node2D
## Root node of every stage. Spawns the player, drives checkpoints and respawns,
## owns the camera/room logic and reports the stage as cleared.
##
## A stage scene only needs: this script on the root, a `PlayerSpawn` Marker2D,
## a `GameCamera`, and at least one `CameraRoom`.

signal stage_completed(stage_id: StringName)
signal checkpoint_reached(position: Vector2)

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const HUD_SCENE := preload("res://src/ui/hud.tscn")
const PAUSE_SCENE := preload("res://src/ui/pause_menu.tscn")

@export var stage_id: StringName = &"stage_01"
@export var display_name: String = "STAGE"
@export var music: StringName = &"stage"
## Seconds between the death explosion and the respawn.
@export var respawn_delay: float = 1.6
## Falling this far below the current room kills the player, as a safety net for
## rooms without an explicit pit hazard.
@export var pit_margin: float = 48.0
## Skip the beam-in animation (handy while testing a stage with F6).
@export var quick_spawn: bool = false

var player: Player
var camera: GameCamera
var checkpoint: Vector2
var current_room: CameraRoom
var _hud: CanvasLayer
var _pause_menu: CanvasLayer
var _respawning: bool = false
var _completed: bool = false


func _ready() -> void:
	add_to_group(&"level")
	randomize()

	camera = _find_camera()
	var spawn := get_node_or_null(^"PlayerSpawn") as Marker2D
	checkpoint = spawn.global_position if spawn else Vector2.ZERO

	_spawn_player(not quick_spawn)
	_setup_ui()

	# Make sure GameState knows which stage this is even when run directly.
	if GameState.current_stage_id != stage_id:
		GameState.prepare_stage(stage_id)

	var start := _start_room()
	if start:
		current_room = start
		camera.snap_to_room(start)
		_apply_room_modifiers(start)
	AudioManager.play_music(music)


func _process(_delta: float) -> void:
	_check_pit()


# ---------------------------------------------------------------------------
# player lifecycle
# ---------------------------------------------------------------------------
func _spawn_player(beam: bool) -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.spawn_at(checkpoint, beam)
	player.died.connect(_on_player_died)
	if camera:
		camera.set_target(player)


func _setup_ui() -> void:
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_pause_menu = PAUSE_SCENE.instantiate()
	add_child(_pause_menu)


func set_checkpoint(pos: Vector2) -> void:
	if pos.is_equal_approx(checkpoint):
		return
	checkpoint = pos
	checkpoint_reached.emit(pos)


func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	_set_pause_blocked(true)
	GameState.on_player_died()
	AudioManager.stop_music(0.4)
	await get_tree().create_timer(respawn_delay).timeout

	if not GameState.has_lives():
		SceneRouter.goto_game_over()
		return

	# Mega Man restarts the room you died in, with full health.
	GameState.health = GameState.MAX_HEALTH
	if is_instance_valid(player):
		player.queue_free()
	await get_tree().process_frame
	_spawn_player(true)
	var room := _room_at(checkpoint)
	if room:
		current_room = room
		camera.snap_to_room(room)
		_apply_room_modifiers(room)
	AudioManager.play_music(music, true)
	_respawning = false
	_set_pause_blocked(false)


func _check_pit() -> void:
	if _respawning or _completed or player == null or not is_instance_valid(player):
		return
	if current_room == null:
		return
	var rect := current_room.world_rect()
	if player.global_position.y > rect.position.y + rect.size.y + pit_margin:
		player.kill_instantly()


# ---------------------------------------------------------------------------
# rooms
# ---------------------------------------------------------------------------
func enter_room(room: CameraRoom, who: Player) -> void:
	if room == current_room or camera == null or _respawning:
		return
	var previous := current_room
	current_room = room
	_apply_room_modifiers(room)
	if room.music != &"":
		AudioManager.play_music(room.music)
	if previous == null:
		camera.snap_to_room(room)
	else:
		camera.transition_to(room, who)


func _apply_room_modifiers(room: CameraRoom) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.gravity_scale = room.gravity_scale
	player.speed_scale = room.speed_scale
	player.jump_scale = room.jump_scale


func _start_room() -> CameraRoom:
	for r in get_tree().get_nodes_in_group(&"camera_rooms"):
		if r is CameraRoom and (r as CameraRoom).is_start_room:
			return r
	return _room_at(checkpoint)


func _room_at(point: Vector2) -> CameraRoom:
	for r in get_tree().get_nodes_in_group(&"camera_rooms"):
		if r is CameraRoom and (r as CameraRoom).contains(point):
			return r
	return null


func _find_camera() -> GameCamera:
	var c := get_node_or_null(^"GameCamera") as GameCamera
	if c:
		return c
	for n in get_tree().get_nodes_in_group(&"camera"):
		if n is GameCamera:
			return n
	# Fall back to a camera created on the fly so a half-built stage still runs.
	var made := GameCamera.new()
	made.name = "GameCamera"
	add_child(made)
	return made


# ---------------------------------------------------------------------------
# completion
# ---------------------------------------------------------------------------
## Called by the boss arena once the boss is gone.
func complete_stage() -> void:
	if _completed:
		return
	_completed = true
	_set_pause_blocked(true)
	if is_instance_valid(player):
		player.victory_pose()
	AudioManager.stop_music(0.3)
	AudioManager.play_sfx(&"stage_clear")

	var reward := WeaponLibrary.reward_for(stage_id)
	GameState.complete_stage(stage_id, reward)
	stage_completed.emit(stage_id)

	await get_tree().create_timer(2.2).timeout
	if stage_id == GameState.FINAL_STAGE_ID:
		SceneRouter.goto_ending()
	else:
		SceneRouter.goto_stage_select()


## Pausing is owned by the pause menu; the level only says when it is off limits.
func _set_pause_blocked(value: bool) -> void:
	if _pause_menu:
		_pause_menu.set(&"blocked", value)
