class_name Enemy
extends CharacterBody2D
## Base class for every enemy and boss.
##
## Handles health, the per-weapon damage table (Mega Man's weakness system),
## hit flashing, contact damage, death FX and item drops. Subclasses only need
## to implement `_behaviour(delta)`.

signal died(enemy: Enemy)
signal health_changed(current: int, maximum: int)

const GRAVITY := 900.0
const MAX_FALL := 420.0

@export_group("Stats")
@export var max_health: int = 4
@export var contact_damage: int = 3
## Damage multiplier per weapon id. Anything not listed uses 1.0.
## e.g. {&"arc_ripper": 4.0} makes this enemy weak to the Arc Ripper.
@export var damage_multipliers: Dictionary = {}
## Weapons listed here do nothing at all (deflect, like Mega Man's shielded foes).
@export var immune_to: Array[StringName] = []
## Ignores every hit while true -- used for armoured/closed states.
@export var invulnerable: bool = false

@export_group("Physics")
@export var use_gravity: bool = true
@export var face_player_on_spawn: bool = true
## Flip the sprite when facing left. Off for symmetrical enemies.
@export var flip_sprite: bool = true

@export_group("Death")
@export var death_effect: PackedScene = preload("res://src/fx/explosion.tscn")
@export var death_sfx: StringName = &"explode"
## Chance (0-1) that this enemy drops an item at all.
@export_range(0.0, 1.0) var drop_chance: float = 0.35
## Score/flavour only -- not shown by default but handy for a results screen.
@export var points: int = 100

var health: int
var facing: int = 1
var player: Player
var _flash: float = 0.0
var _dead: bool = false

@onready var sprite: Sprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD
	health = max_health
	player = get_tree().get_first_node_in_group(&"player") as Player
	if face_player_on_spawn and player:
		facing = 1 if player.global_position.x > global_position.x else -1
	_on_spawn()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _flash > 0.0:
		_flash -= delta
		if sprite:
			sprite.modulate = Color(3.0, 3.0, 3.0) if int(_flash * 40.0) % 2 == 0 else Color.WHITE
			if _flash <= 0.0:
				sprite.modulate = Color.WHITE

	if use_gravity:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	_behaviour(delta)
	move_and_slide()

	if sprite and flip_sprite:
		sprite.flip_h = facing < 0


## Override in subclasses. Set `velocity`; move_and_slide is called for you.
func _behaviour(_delta: float) -> void:
	pass


## Override for one-time setup that needs `player` to already be resolved.
func _on_spawn() -> void:
	pass


# ---------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------
## Returns false when the hit had no effect, which tells the projectile to
## deflect instead of exploding.
func take_damage(amount: int, source: Node = null) -> bool:
	if _dead or invulnerable:
		return false

	var weapon_id: StringName = &""
	if source and source.has_meta(&"weapon_id"):
		weapon_id = source.get_meta(&"weapon_id")
	if immune_to.has(weapon_id):
		return false

	var multiplier := float(damage_multipliers.get(weapon_id, 1.0))
	var final := int(round(float(amount) * multiplier))
	if final <= 0:
		return false

	health -= final
	health_changed.emit(health, max_health)
	_flash = 0.14
	_on_damaged(final, source)
	if health <= 0:
		die()
	return true


func _on_damaged(_amount: int, _source: Node) -> void:
	pass


## True while the hit flash is playing -- subclasses use it to pick a hurt frame.
func is_flashing() -> bool:
	return _flash > 0.0


func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	_spawn_death_effect()
	_try_drop()
	queue_free()


func _spawn_death_effect() -> void:
	if death_effect == null:
		return
	var fx := death_effect.instantiate()
	if fx is Node2D:
		(fx as Node2D).global_position = global_position
	get_parent().add_child(fx)
	if death_sfx != &"":
		AudioManager.play_sfx(death_sfx)


func _try_drop() -> void:
	if randf() > drop_chance:
		return
	var scene := PickupTable.roll()
	if scene == null:
		return
	var item := scene.instantiate()
	if item is Node2D:
		(item as Node2D).global_position = global_position
	if item is Pickup:
		# Drops fade out; items placed by hand in a level stay forever.
		(item as Pickup).lifetime = 8.0
	get_parent().call_deferred(&"add_child", item)


## Read by the player's hurtbox on contact.
func get_contact_damage() -> int:
	return contact_damage


# ---------------------------------------------------------------------------
# helpers for subclasses
# ---------------------------------------------------------------------------
func distance_to_player() -> float:
	if player == null or not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)


func direction_to_player() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.RIGHT
	return (player.global_position - global_position).normalized()


func face_player() -> void:
	if player and is_instance_valid(player):
		facing = 1 if player.global_position.x > global_position.x else -1


## True when there is no floor just ahead -- used to turn around at ledges.
func at_ledge(probe_ahead: float = 8.0, probe_down: float = 12.0) -> bool:
	var from := global_position + Vector2(probe_ahead * facing, -2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, probe_down))
	query.collision_mask = Layers.WORLD
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func shoot(scene: PackedScene, dir: Vector2, offset: Vector2 = Vector2.ZERO, speed_override: float = -1.0) -> Projectile:
	if scene == null:
		return null
	var shot := scene.instantiate()
	get_parent().add_child(shot)
	if shot is Projectile:
		var p := shot as Projectile
		if speed_override > 0.0:
			p.speed = speed_override
		p.launch(global_position + offset, dir, null, self)
		return p
	return null
