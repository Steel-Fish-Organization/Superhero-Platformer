extends Boss
## Stage 1 boss: BULWARK.
##
## A readable three-attack pattern in the MM5/MM6 mould -- leap, spread shot,
## ground slam -- with a tell before each one and a short recovery you can punish.
## Copy this file as the starting point for the other eight bosses.

enum Action { WAIT, LEAP, SPREAD, SLAM, RECOVER }

@export_group("Pattern")
@export var wait_time: float = 0.7
@export var enraged_wait: float = 0.35
@export var tell_time: float = 0.3

@export_group("Leap")
@export var leap_speed_x: float = 105.0
@export var leap_speed_y: float = 300.0

@export_group("Spread shot")
@export var projectile: PackedScene = preload("res://src/weapons/projectiles/shot_enemy.tscn")
@export var spread_shots: int = 3
@export var spread_arc: float = 44.0
@export var shot_speed: float = 160.0
@export var muzzle_offset: Vector2 = Vector2(16, -22)

@export_group("Slam")
@export var slam_rise: float = 200.0
@export var slam_shockwave_speed: float = 190.0

var _action: Action = Action.WAIT
var _last_attack: Action = Action.WAIT
var _timer: float = 0.0
var _tell: float = 0.0
var _slam_falling: bool = false


func _on_fight_started() -> void:
	_enter(Action.WAIT, wait_time)


func _on_enraged() -> void:
	# Speeds up and starts firing five-way spreads.
	spread_shots = 5
	spread_arc = 70.0
	AudioManager.play_sfx(&"boss_enrage")


func _fight(delta: float) -> void:
	_timer -= delta
	if _tell > 0.0:
		_tell -= delta
		velocity.x = 0.0
		_set_frame(2)
		if _tell <= 0.0:
			_execute()
		return

	match _action:
		Action.WAIT:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			face_player()
			_set_frame(int(Time.get_ticks_msec() / 400.0) % 2)
			if _timer <= 0.0 and is_on_floor():
				_choose_attack()
		Action.LEAP:
			_set_frame(4)
			if is_on_floor() and velocity.y >= 0.0:
				_land_from_leap()
		Action.SLAM:
			_process_slam()
		Action.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			_set_frame(0)
			if _timer <= 0.0:
				_enter(Action.WAIT, _wait_duration())
		_:
			pass


func _wait_duration() -> float:
	return enraged_wait if enraged else wait_time


func _choose_attack() -> void:
	## Reroll once if we drew the same attack again -- keeps the fight readable
	## without making the pattern fully predictable.
	var next := _roll_attack()
	if next == _last_attack:
		next = _roll_attack()
	_last_attack = next
	_action = next
	_tell = tell_time
	face_player()


func _roll_attack() -> Action:
	var pick := randf()
	if pick < 0.4:
		return Action.LEAP
	elif pick < 0.75:
		return Action.SPREAD
	return Action.SLAM


func _execute() -> void:
	match _action:
		Action.LEAP:
			jump_toward_player(leap_speed_x, leap_speed_y)
			AudioManager.play_sfx(&"boss_jump")
		Action.SPREAD:
			_fire_spread()
			_enter(Action.RECOVER, 0.45)
		Action.SLAM:
			velocity = Vector2(0.0, -slam_rise)
			_slam_falling = false
		_:
			_enter(Action.WAIT, _wait_duration())


func _land_from_leap() -> void:
	velocity.x = 0.0
	_shake(2.0)
	_enter(Action.RECOVER, 0.35)


func _fire_spread() -> void:
	_set_frame(3)
	var base := Vector2(facing, 0.0)
	var arc := deg_to_rad(spread_arc)
	for i in spread_shots:
		var t := 0.0 if spread_shots == 1 else (float(i) / float(spread_shots - 1)) - 0.5
		var dir := base.rotated(t * arc)
		var offset := Vector2(muzzle_offset.x * facing, muzzle_offset.y)
		shoot(projectile, dir, offset, shot_speed)
	AudioManager.play_sfx(&"enemy_shoot")


func _process_slam() -> void:
	_set_frame(4)
	if not _slam_falling and velocity.y >= 0.0:
		_slam_falling = true
		# Drop straight onto the player's current x.
		if player and is_instance_valid(player):
			global_position.x = move_toward(global_position.x, player.global_position.x, 6.0)
	if _slam_falling and is_on_floor():
		_shake(3.5)
		AudioManager.play_sfx(&"boss_slam")
		_spawn_shockwaves()
		_enter(Action.RECOVER, 0.6)


func _spawn_shockwaves() -> void:
	for dir in [Vector2.LEFT, Vector2.RIGHT]:
		shoot(projectile, dir, Vector2(dir.x * 14.0, -4.0), slam_shockwave_speed)


func _enter(action: Action, time: float) -> void:
	_action = action
	_timer = time
	_tell = 0.0
	_slam_falling = false


func _set_frame(index: int) -> void:
	if sprite:
		sprite.frame = 5 if is_flashing() else index


func _shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_shake"):
		cam.call("add_shake", amount)
