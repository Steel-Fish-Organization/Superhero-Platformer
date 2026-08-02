extends CharacterBody2D
## Basic flying enemy. Hovers on the spot (or drifts), bobs up and down, and
## shoots at the player when he's close enough. Something to test health and
## damage against, in both directions.

signal died

@export_group("Health")
@export var max_health := 4
## Damage dealt to the player on contact.
@export var contact_damage := 3

@export_group("Movement")
@export var bob_height := 8.0
@export var bob_speed := 2.0
## Left/right drift. 0 hovers in place; it turns around at walls.
@export var drift_speed := 0.0

@export_group("Shooting")
@export var projectile: PackedScene
@export var fire_interval := 1.6
@export var shot_speed := 140.0
## Won't shoot unless the player is at least this close.
@export var sight_range := 220.0
## Aim at the player rather than straight ahead.
@export var aim_at_player := true

const HOSTILE_LAYER := 4      # physics layer 3
const WORLD_LAYER := 1

var health := 0
var facing := -1

var _origin := Vector2.ZERO
var _phase := 0.0
var _fire_timer := 0.0
var _flash := 0.0
var _player: Node2D


func _ready() -> void:
	add_to_group(&"enemies")
	health = max_health
	collision_layer = HOSTILE_LAYER
	collision_mask = WORLD_LAYER
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_origin = global_position
	_phase = randf() * TAU
	_fire_timer = fire_interval * randf_range(0.3, 1.0)


func _physics_process(delta: float) -> void:
	# Looked up lazily, not in _ready: enemies placed before the Player in the
	# scene tree run _ready first, and the group isn't populated yet at that point.
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player")

	_phase += delta * bob_speed
	_fire_timer -= delta

	velocity.x = drift_speed * facing
	# Bob around the height it started at.
	var want_y := _origin.y + sin(_phase) * bob_height
	velocity.y = (want_y - global_position.y) * 6.0
	move_and_slide()
	if drift_speed != 0.0 and is_on_wall():
		facing = -facing

	if _player and is_instance_valid(_player):
		if aim_at_player:
			facing = 1 if _player.global_position.x > global_position.x else -1
		if _fire_timer <= 0.0 and _in_range():
			_shoot()
			_fire_timer = fire_interval

	_animate(delta)


func _in_range() -> bool:
	return sight_range <= 0.0 or global_position.distance_to(_player.global_position) <= sight_range


func _shoot() -> void:
	if projectile == null:
		return
	var shot := projectile.instantiate()
	var dir := Vector2(facing, 0.0)
	if aim_at_player and _player and is_instance_valid(_player):
		# aim at his middle rather than his feet
		dir = (_player.global_position + Vector2(0, -12) - global_position).normalized()
	shot.speed = shot_speed
	get_parent().add_child(shot)
	shot.launch(global_position, dir, self)


func take_damage(amount: int, _from: Node = null) -> void:
	health -= amount
	_flash = 0.15
	if health <= 0:
		died.emit()
		queue_free()


## Read by the player when he bumps into us.
func get_contact_damage() -> int:
	return contact_damage


func _animate(delta: float) -> void:
	var sprite := $Sprite as Sprite2D
	sprite.frame = int(_phase * 2.0) % 2
	sprite.flip_h = facing < 0
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3) if int(_flash * 40.0) % 2 == 0 else Color.WHITE
		if _flash <= 0.0:
			sprite.modulate = Color.WHITE
	queue_redraw()


## Small health pip above the enemy so damage is visible while prototyping.
func _draw() -> void:
	if health >= max_health:
		return
	var w := 16.0
	var frac := clampf(float(health) / float(max_health), 0.0, 1.0)
	var origin := Vector2(-w * 0.5, -16.0)
	draw_rect(Rect2(origin, Vector2(w, 3)), Color(0.1, 0.1, 0.15), true)
	draw_rect(Rect2(origin, Vector2(w * frac, 3)), Color(1.0, 0.45, 0.45), true)
