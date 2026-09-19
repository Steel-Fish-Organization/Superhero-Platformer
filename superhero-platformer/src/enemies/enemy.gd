class_name Enemy
extends CharacterBody2D
## Base for every enemy. Handles health, hit flashing, contact damage, death and
## the little health pip. Each enemy type only fills in `_behaviour(delta)`: set
## `velocity` there, and move_and_slide is called for you.
##
## Enemies only act while they're on screen, as in Mega Man. That stops a walker
## two rooms away wandering off before you ever meet it, and stops enemies in
## the next room shooting at you through the wall.

signal died(enemy: Enemy)

const HOSTILE_LAYER := 4      # physics layer 3
const WORLD_LAYER := 1
const GRAVITY := 900.0
const MAX_FALL := 420.0
## Aim at the hero's middle rather than their feet.
const PLAYER_CENTRE := Vector2(0, -12)

@export_group("Health")
@export var max_health := 4
## Damage dealt to the player on contact.
@export var contact_damage := 3
## Ignores every hit while true. The turret uses this while it's shut.
@export var invulnerable := false

@export_group("Behaviour")
@export var use_gravity := true
## Turn to face the player the first time it comes on screen.
@export var face_player_on_spawn := true
## Flip the sprite when facing left. Off for symmetrical enemies.
@export var flip_sprite := true
## Freeze while off screen. Turn off for something that should keep going.
@export var only_active_on_screen := true

@export_group("Death")
@export var death_effect: PackedScene = preload("res://src/fx/explosion.tscn")

var health := 0
var facing := -1
var player: Node2D

var _flash := 0.0
var _dead := false
var _woken := false

@onready var sprite: Sprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = HOSTILE_LAYER
	collision_mask = WORLD_LAYER
	health = max_health
	_on_spawn()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Looked up lazily, not in _ready: enemies placed before the Player in the
	# scene tree run _ready first, when the group is still empty.
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	_tick_flash(delta)

	if only_active_on_screen and not is_on_screen():
		return
	if not _woken:
		_woken = true
		if face_player_on_spawn:
			face_player()
		_on_wake()

	if use_gravity:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	_behaviour(delta)
	move_and_slide()

	if sprite and flip_sprite:
		sprite.flip_h = facing < 0


## Override in each enemy. Set `velocity`; move_and_slide is called for you.
func _behaviour(_delta: float) -> void:
	pass


## Override for setup at load time.
func _on_spawn() -> void:
	pass


## Override for setup the first time the enemy comes on screen.
func _on_wake() -> void:
	pass


# ---------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------
## Returns false when the hit had no effect, which makes the shot glance off.
func take_damage(amount: int, _from: Node = null) -> bool:
	if _dead or invulnerable or amount <= 0:
		return false
	health -= amount
	_flash = 0.15
	if health <= 0:
		die()
	else:
		queue_redraw()
	return true


func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	if death_effect:
		var fx := death_effect.instantiate()
		if fx is Node2D:
			(fx as Node2D).global_position = global_position + _sprite_offset()
		get_parent().add_child(fx)
	queue_free()


## Read by the player's hurtbox while touching us.
func get_contact_damage() -> int:
	return contact_damage


# ---------------------------------------------------------------------------
# helpers for enemy types
# ---------------------------------------------------------------------------
func is_on_screen(margin := 8.0) -> bool:
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	return view.grow(margin).has_point(global_position)


func distance_to_player() -> float:
	if player == null or not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)


func direction_to_player(from := global_position) -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2(facing, 0.0)
	return (player.global_position + PLAYER_CENTRE - from).normalized()


func face_player() -> void:
	if player and is_instance_valid(player):
		facing = 1 if player.global_position.x > global_position.x else -1


## True when there is no floor just ahead -- used to turn around at ledges.
func at_ledge(probe_ahead := 8.0, probe_down := 12.0) -> bool:
	var from := global_position + Vector2(probe_ahead * facing, -2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, probe_down))
	query.collision_mask = WORLD_LAYER
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Fires a projectile scene (any scene with the Projectile script) from here.
func shoot(scene: PackedScene, dir: Vector2, offset := Vector2.ZERO, speed := -1.0) -> Node:
	if scene == null:
		return null
	var shot := scene.instantiate()
	if speed > 0.0:
		shot.speed = speed
	get_parent().add_child(shot)
	shot.launch(global_position + offset, dir, self)
	return shot


# ---------------------------------------------------------------------------
# visuals
# ---------------------------------------------------------------------------
func _tick_flash(delta: float) -> void:
	if _flash <= 0.0 or sprite == null:
		return
	_flash -= delta
	sprite.modulate = Color(3, 3, 3) if int(_flash * 40.0) % 2 == 0 else Color.WHITE
	if _flash <= 0.0:
		sprite.modulate = Color.WHITE


func _sprite_offset() -> Vector2:
	return sprite.position if sprite else Vector2.ZERO


## Small health pip above the enemy so damage is visible while prototyping.
func _draw() -> void:
	if health >= max_health or health <= 0:
		return
	var w := 16.0
	var frac := clampf(float(health) / float(max_health), 0.0, 1.0)
	var origin := Vector2(-w * 0.5, _sprite_offset().y - 16.0)
	draw_rect(Rect2(origin, Vector2(w, 3)), Color(0.1, 0.1, 0.15), true)
	draw_rect(Rect2(origin, Vector2(w * frac, 3)), Color(1.0, 0.45, 0.45), true)
