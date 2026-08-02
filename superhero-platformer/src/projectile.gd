class_name Projectile
extends Area2D
## One projectile script for every weapon. A straight shot, a lobbed bomb and a
## ricochet are the same script with different values set in the scene.
##
## Walls are found with a swept raycast rather than an overlap, so a fast shot
## can never tunnel through the 8px tiles.

## Straight-line speed. The weapon overrides this when it fires.
@export var speed := 300.0
@export var damage := 1
@export var lifetime := 2.0

@export_group("Motion")
## Downward acceleration. 0 for a straight shot, high for a lobbed bomb.
@export var gravity_accel := 0.0
@export var max_fall := 400.0
## Point the sprite the way it's travelling. Good for bombs and arrows.
@export var face_travel := false
@export var spin_degrees_per_second := 0.0

@export_group("On contact")
## Enemies it can pass through before dying. 0 = dies on the first hit.
@export_range(0, 8) var pierce := 0
## Wall bounces before it gives up. 0 = dies on the first wall.
@export_range(0, 12) var bounces := 0
## How much speed survives each bounce.
@export_range(0.0, 1.0) var bounciness := 0.9
## Spawned where it dies -- an explosion, a spark, nothing.
@export var impact: PackedScene
## Fires the impact scene even when it just times out, not only on a hit.
@export var impact_on_expire := false

@export_group("Side")
## Flips the collision layers so enemies can fire this same projectile.
@export var hostile := false

# layers: 1 world, 2 player, 3 hostile, 4 player_shot, 6 enemy_shot
const WORLD := 1
const PLAYER := 2
const HOSTILE := 4
const PLAYER_SHOT := 8
const ENEMY_SHOT := 32

var direction := Vector2.RIGHT
var velocity := Vector2.ZERO
var shooter: Node2D

var _age := 0.0
var _hits_left := 0
var _bounces_left := 0
var _dead := false


func _ready() -> void:
	collision_layer = ENEMY_SHOT if hostile else PLAYER_SHOT
	collision_mask = (WORLD | PLAYER) if hostile else (WORLD | HOSTILE)
	_hits_left = pierce
	_bounces_left = bounces
	body_entered.connect(_on_body_entered)


## Called by whoever fires it, before it is added to the scene.
func launch(from: Vector2, dir: Vector2, by: Node2D = null) -> void:
	global_position = from
	direction = dir.normalized()
	velocity = direction * speed
	shooter = by
	if face_travel:
		rotation = velocity.angle()
	elif direction.x < 0.0:
		scale.x = -absf(scale.x)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	_age += delta
	if _age >= lifetime:
		_die(impact_on_expire)
		return

	if gravity_accel != 0.0:
		velocity.y = minf(velocity.y + gravity_accel * delta, max_fall)

	_move(velocity * delta)

	if spin_degrees_per_second != 0.0:
		rotation += deg_to_rad(spin_degrees_per_second) * delta
	elif face_travel:
		rotation = velocity.angle()

	var sprite := get_node_or_null(^"Sprite") as Sprite2D
	if sprite and sprite.hframes > 1:
		sprite.frame = int(_age * 14.0) % sprite.hframes


## Swept move, so walls are hit exactly rather than overlapped into.
func _move(step: Vector2) -> void:
	if step == Vector2.ZERO:
		return
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + step + step.normalized())
	query.collision_mask = WORLD
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		global_position += step
		return

	global_position = hit.position - step.normalized()
	if _bounces_left <= 0:
		_die(true)
		return
	_bounces_left -= 1
	velocity = velocity.bounce(hit.get("normal", Vector2.UP)) * bounciness
	direction = velocity.normalized()


func _on_body_entered(body: Node) -> void:
	if _dead or body == shooter:
		return
	if not body.has_method(&"take_damage"):
		return
	body.take_damage(damage, self)
	if _hits_left > 0:
		_hits_left -= 1
		return
	_die(true)


func _die(spawn_impact: bool) -> void:
	if _dead:
		return
	_dead = true
	# Stop counting further overlaps while we wait to be freed.
	set_deferred(&"monitoring", false)

	if spawn_impact and impact:
		var fx := impact.instantiate()
		if fx.has_method(&"set_hostile"):
			fx.call(&"set_hostile", hostile)

		# Place it before it enters the tree. Position is relative to the parent
		# because global_position isn't meaningful until it's parented.
		var parent := get_parent()
		if fx is Node2D:
			if parent is Node2D:
				(fx as Node2D).position = (parent as Node2D).to_local(global_position)
			else:
				(fx as Node2D).global_position = global_position

		# Deferred on purpose: this can be reached from body_entered, and adding
		# an Area2D with a collision shape while the physics server is flushing
		# queries is rejected. The deferred call keeps `fx` alive until then.
		parent.add_child.call_deferred(fx)

	queue_free()
