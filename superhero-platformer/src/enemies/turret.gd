extends Enemy
## Armoured emplacement: shut and invulnerable, then it opens, fires a burst and
## closes again. Deflects shots while closed, exactly like MM's shielded turrets.

enum Phase { CLOSED, OPENING, FIRING, CLOSING }

@export var projectile: PackedScene = preload("res://src/weapons/projectiles/shot_enemy.tscn")
@export var closed_time: float = 1.4
@export var open_time: float = 0.35
@export var burst_count: int = 2
@export var burst_delay: float = 0.35
@export var shot_speed: float = 150.0
@export var muzzle_offset: Vector2 = Vector2(6, -8)
## Fire straight ahead, or lead toward the player's position.
@export var aim_at_player: bool = true
## Only wakes up when the player is this close. 0 = always active.
@export var activation_range: float = 150.0

var _phase: Phase = Phase.CLOSED
var _timer: float = 0.0
var _shots_left: int = 0


func _on_spawn() -> void:
	use_gravity = false
	invulnerable = true
	_timer = closed_time


func _behaviour(delta: float) -> void:
	velocity = Vector2.ZERO
	_timer -= delta

	match _phase:
		Phase.CLOSED:
			_set_frame(0)
			if _timer <= 0.0 and _player_near():
				_enter(Phase.OPENING, open_time)
		Phase.OPENING:
			_set_frame(1)
			invulnerable = false
			face_player()
			if _timer <= 0.0:
				_shots_left = burst_count
				_enter(Phase.FIRING, 0.0)
		Phase.FIRING:
			_set_frame(2)
			if _timer <= 0.0:
				_fire()
				_shots_left -= 1
				_timer = burst_delay
				if _shots_left <= 0:
					_enter(Phase.CLOSING, open_time)
		Phase.CLOSING:
			_set_frame(1)
			if _timer <= 0.0:
				invulnerable = true
				_enter(Phase.CLOSED, closed_time)


func _enter(next: Phase, time: float) -> void:
	_phase = next
	_timer = time


func _player_near() -> bool:
	return activation_range <= 0.0 or distance_to_player() <= activation_range


func _fire() -> void:
	var dir := Vector2(facing, 0.0)
	if aim_at_player:
		dir = direction_to_player()
	var offset := Vector2(muzzle_offset.x * facing, muzzle_offset.y)
	shoot(projectile, dir, offset, shot_speed)
	AudioManager.play_sfx(&"enemy_shoot")


func _set_frame(index: int) -> void:
	if sprite:
		sprite.frame = index
