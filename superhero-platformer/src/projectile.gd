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
## Removed once it is this far outside the screen, as in Mega Man. Besides
## looking right, it frees the shot's place in the on-screen limit straight away
## rather than holding it for the rest of `lifetime`.
@export var offscreen_margin := 16.0

@export_group("Motion")
## Downward acceleration. 0 for a straight shot, high for a lobbed bomb.
@export var gravity_accel := 0.0
@export var max_fall := 400.0
## Point the sprite the way it's travelling. Good for bombs and arrows.
@export var face_travel := false
## With face_travel, rounds the angle to steps of this many degrees -- 90 points
## the sprite straight up, down, left or right. 0 = no snapping.
@export_range(0.0, 180.0) var face_snap_degrees := 0.0
## Which way the art points, with face_travel. 0 = drawn facing right, -90 = up.
@export_range(-180.0, 180.0) var sprite_facing_degrees := 0.0
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

@export_group("Breaking tiles")
## Whether this shot can clear tiles flagged `breakable`. Enemy fire leaves the
## level alone by default.
@export var breaks_tiles := true
## 0 takes out the single tile that was hit. A charged shot or an explosion sets
## this to clear everything breakable within the radius, in pixels.
@export var break_radius := 0.0

@export_group("Side")
## Flips the collision layers so enemies can fire this same projectile.
@export var hostile := false

# layers: 1 world, 2 player, 3 hostile, 4 player_shot, 6 enemy_shot, 9 civilian
const WORLD := 1
const PLAYER := 2
const HOSTILE := 4
const PLAYER_SHOT := 8
const ENEMY_SHOT := 32
## Only enemy fire carries this in its mask. The hero's shots pass straight
## through bystanders -- you cannot shoot a civilian in this game, by design.
const CIVILIAN := 256

var direction := Vector2.RIGHT
var velocity := Vector2.ZERO
var shooter: Node2D

var _age := 0.0
var _hits_left := 0
var _bounces_left := 0
var _dead := false
## Glanced off something armoured -- it can't hurt anything any more.
var _deflected := false


func _ready() -> void:
	collision_layer = ENEMY_SHOT if hostile else PLAYER_SHOT
	collision_mask = (WORLD | PLAYER | CIVILIAN) if hostile else (WORLD | HOSTILE)
	_hits_left = pierce
	_bounces_left = bounces
	body_entered.connect(_on_hit)
	# Civilians are areas, not bodies: only enemy fire has them in its mask.
	area_entered.connect(_on_hit)


## Called by whoever fires it, before it is added to the scene.
func launch(from: Vector2, dir: Vector2, by: Node2D = null) -> void:
	global_position = from
	direction = dir.normalized()
	velocity = direction * speed
	shooter = by
	if face_travel:
		rotation = _travel_angle()
	elif direction.x < 0.0:
		scale.x = -absf(scale.x)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	_age += delta
	if _age >= lifetime:
		_die(impact_on_expire)
		return
	if _is_offscreen():
		_die(false)
		return

	if gravity_accel != 0.0:
		velocity.y = minf(velocity.y + gravity_accel * delta, max_fall)

	_move(velocity * delta)

	if spin_degrees_per_second != 0.0:
		rotation += deg_to_rad(spin_degrees_per_second) * delta
	elif face_travel:
		rotation = _travel_angle()

	var sprite := get_node_or_null(^"Sprite") as Sprite2D
	if sprite and sprite.hframes > 1:
		sprite.frame = int(_age * 14.0) % sprite.hframes


## Rotation that points the art along the velocity, snapped if asked.
func _travel_angle() -> float:
	var angle := velocity.angle()
	if face_snap_degrees > 0.0:
		angle = snappedf(angle, deg_to_rad(face_snap_degrees))
	return angle - deg_to_rad(sprite_facing_degrees)


## Swept move, so walls are hit exactly rather than overlapped into.
func _move(step: Vector2) -> void:
	if step == Vector2.ZERO:
		return
	var space := get_world_2d().direct_space_state
	var heading := step.normalized()
	var destination := global_position + step + heading
	var query := PhysicsRayQueryParameters2D.create(global_position, destination)
	query.collision_mask = WORLD
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)

	# Shots ignore one-way platforms, both ways round: you can stand on one and
	# shoot down through it, or shoot up at something standing on it. The ray
	# restarts just past each one rather than excluding its collider -- a whole
	# TileMapLayer can share one collider with the solid walls around it.
	var skips := 0
	while not hit.is_empty() and skips < 8 and _is_one_way(hit, heading):
		skips += 1
		query.from = hit["position"] + heading
		if query.from.distance_squared_to(global_position) >= destination.distance_squared_to(global_position):
			hit = {}
			break
		hit = space.intersect_ray(query)

	if hit.is_empty():
		global_position += step
		return

	global_position = hit.position - step.normalized()

	# A wall you can shoot away. The hit point sits on the tile's face, so look a
	# whisker further in to find the tile itself rather than the empty cell in
	# front of it.
	if breaks_tiles and _break_tiles_at(hit["position"] + heading):
		_die(true)
		return

	if _bounces_left <= 0:
		_die(true)
		return
	_bounces_left -= 1
	velocity = velocity.bounce(hit.get("normal", Vector2.UP)) * bounciness
	direction = velocity.normalized()


## Asks the level to break what it can at this point. True when something went,
## which is what tells the shot it hit a wall worth dying on rather than bouncing
## off. Levels without a DestructibleTiles node always answer no.
func _break_tiles_at(point: Vector2) -> bool:
	var tiles := get_tree().get_first_node_in_group(&"breakables")
	return tiles != null and tiles.shatter(point, break_radius) > 0


## True for the platforms shots are allowed through: one-way tiles, and one-way
## collision shapes on any body, such as the ledges ladders.gd builds.
func _is_one_way(hit: Dictionary, heading: Vector2) -> bool:
	var collider = hit.get("collider")
	if collider is TileMapLayer:
		var tiles := collider as TileMapLayer
		# A hair past the surface, so we read the tile we just hit, not its neighbour.
		var inside: Vector2 = hit["position"] + heading
		var data := tiles.get_cell_tile_data(tiles.local_to_map(tiles.to_local(inside)))
		return data != null and data.is_collision_polygon_one_way(0, 0)
	if collider is CollisionObject2D:
		var body := collider as CollisionObject2D
		var owner_id := body.shape_find_owner(hit.get("shape", 0))
		var shape := body.shape_owner_get_owner(owner_id)
		return shape is CollisionShape2D and (shape as CollisionShape2D).one_way_collision
	return false


func _is_offscreen() -> bool:
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	return not view.grow(offscreen_margin).has_point(global_position)


func _on_hit(body: Node) -> void:
	if _dead or _deflected or body == shooter:
		return
	if not body.has_method(&"take_damage"):
		return
	if not body.take_damage(damage, self):
		# The hit didn't land. An enemy shot flies on through a flickering hero;
		# a player shot glances off armour, like a closed turret.
		if not hostile:
			_deflect()
		return
	if _hits_left > 0:
		_hits_left -= 1
		return
	_die(true)


## Bounces back and up at an angle, harmlessly, as in Mega Man.
func _deflect() -> void:
	_deflected = true
	var back := -signf(velocity.x) if velocity.x != 0.0 else -1.0
	velocity = Vector2(back, -1.0).normalized() * maxf(speed, 200.0)
	direction = velocity.normalized()
	modulate = Color(1, 1, 1, 0.6)


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
