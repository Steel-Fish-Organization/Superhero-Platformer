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
## Which way the art is drawn. Untick for sprite sheets drawn facing left.
@export var sprite_faces_right := true
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
var _on_screen := false
## True while the hurt animation plays; state animations wait for it to end.
var _hurt_playing := false
var _wanted_anim := &""
var _wanted_speed := 1.0

@onready var sprite: Sprite2D = get_node_or_null(^"Sprite")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null(^"AnimatedSprite")


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = HOSTILE_LAYER
	collision_mask = WORLD_LAYER
	health = max_health
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_anim_finished)
	_on_spawn()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Looked up lazily, not in _ready: enemies placed before the Player in the
	# scene tree run _ready first, when the group is still empty.
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	_tick_flash(delta)

	var active := not only_active_on_screen or is_on_screen()
	if active != _on_screen:
		_on_screen = active
		if not active and _woken:
			_on_leave_screen()
	if not active:
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

	if flip_sprite:
		var flip := is_flipped()
		if sprite:
			sprite.flip_h = flip
		if animated_sprite:
			animated_sprite.flip_h = flip


## Override in each enemy. Set `velocity`; move_and_slide is called for you.
func _behaviour(_delta: float) -> void:
	pass


## Override for setup at load time.
func _on_spawn() -> void:
	pass


## Override for setup the first time the enemy comes on screen.
func _on_wake() -> void:
	pass


## Override to reset when the enemy scrolls off screen and freezes, so it isn't
## left mid-attack when the player comes back.
func _on_leave_screen() -> void:
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
		if has_anim(&"hurt"):
			if not _hurt_playing:
				_wanted_anim = animated_sprite.animation
				_wanted_speed = animated_sprite.get_playing_speed() if animated_sprite.is_playing() else 1.0
			_hurt_playing = true
			animated_sprite.play(&"hurt")
			animated_sprite.frame = 0
	return true


func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	# The die animations include their own explosion, so play that out in place
	# of the death effect. Off the hostile layer so shots and the hero pass through.
	if has_anim(&"die"):
		collision_layer = 0
		velocity = Vector2.ZERO
		_visual().modulate = Color.WHITE
		queue_redraw()
		animated_sprite.play(&"die")
		return
	if death_effect:
		var fx := death_effect.instantiate()
		if fx is Node2D:
			(fx as Node2D).global_position = global_position + _sprite_offset()
		get_parent().add_child(fx)
	queue_free()


## Read by the player's hurtbox while touching us.
func get_contact_damage() -> int:
	return 0 if _dead else contact_damage


# ---------------------------------------------------------------------------
# animation
# ---------------------------------------------------------------------------
func has_anim(anim: StringName) -> bool:
	return animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(anim)


## Seconds one pass of an animation takes at normal speed.
func anim_length(anim: StringName) -> float:
	if not has_anim(anim):
		return 0.0
	var frames := animated_sprite.sprite_frames
	var fps := frames.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for i in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	return total / fps


## Switches to a state animation. Call it every frame with whatever the enemy is
## doing; it only restarts when the animation actually changes, or when `restart`
## is set -- use that to start a one-shot (an attack) again from its first frame.
## While the hurt animation is showing, the request is held until it ends.
func play_anim(anim: StringName, speed := 1.0, restart := false) -> void:
	if _dead or not has_anim(anim):
		return
	if _hurt_playing:
		_wanted_anim = anim
		_wanted_speed = speed
		return
	if restart:
		animated_sprite.play(anim, speed)
		animated_sprite.frame = 0
		return
	if animated_sprite.animation == anim:
		# Same animation: just update the speed. A finished one-shot stays on
		# its last frame rather than restarting.
		if animated_sprite.is_playing():
			animated_sprite.play(anim, speed)
		return
	animated_sprite.play(anim, speed)


## Override to react when a one-shot state animation (attack, jump...) ends.
func _on_animation_finished(_anim: StringName) -> void:
	pass


func _on_anim_finished() -> void:
	var anim := animated_sprite.animation
	if anim == &"die":
		queue_free()
		return
	if anim == &"hurt" and _hurt_playing:
		_hurt_playing = false
		if _wanted_anim != &"" and has_anim(_wanted_anim):
			animated_sprite.play(_wanted_anim, _wanted_speed)
			animated_sprite.frame = 0
		return
	_on_animation_finished(anim)


# ---------------------------------------------------------------------------
# helpers for enemy types
# ---------------------------------------------------------------------------
## True when the art should be mirrored to face `facing`.
func is_flipped() -> bool:
	return flip_sprite and (facing < 0) == sprite_faces_right


## A child's position as an offset from us, mirrored along with the sprite. For
## muzzles and the like, placed in the editor for the unflipped art.
func flipped_offset(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO
	var offset := node.position
	if is_flipped():
		offset.x = -offset.x
	return offset


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


## Multiplier for this enemy's timers, from the level's alert level: the longer
## the hero spends rescuing people, the less patient the opposition gets. 1.0
## when the level has no Alert node.
func alert_scale() -> float:
	var alert := get_tree().get_first_node_in_group(&"alert")
	return alert.call(&"fire_scale") if alert else 1.0


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
	var visual := _visual()
	if _flash <= 0.0 or visual == null:
		return
	_flash -= delta
	visual.modulate = Color(3, 3, 3) if int(_flash * 40.0) % 2 == 0 else Color.WHITE
	if _flash <= 0.0:
		visual.modulate = Color.WHITE


## Whichever sprite node this enemy uses.
func _visual() -> Node2D:
	return sprite if sprite else animated_sprite


func _sprite_offset() -> Vector2:
	var visual := _visual()
	return visual.position if visual else Vector2.ZERO


## Small health pip above the enemy so damage is visible while prototyping.
func _draw() -> void:
	if health >= max_health or health <= 0:
		return
	var w := 16.0
	var frac := clampf(float(health) / float(max_health), 0.0, 1.0)
	var origin := Vector2(-w * 0.5, _sprite_offset().y - 16.0)
	draw_rect(Rect2(origin, Vector2(w, 3)), Color(0.1, 0.1, 0.15), true)
	draw_rect(Rect2(origin, Vector2(w * frac, 3)), Color(1.0, 0.45, 0.45), true)
