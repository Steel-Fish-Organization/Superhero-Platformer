extends CharacterBody2D
## The hero. Run, jump, slide, climb, shoot, take damage.
##
## Everything you'd want to tune is a constant at the top. The values are taken
## from Mega Man 5/6 and Mega Man X, converted to pixels/second at 60 ticks --
## the original per-frame numbers are in the comments so you can sanity-check
## them against the real games.
##
## Physics layers: 1 world, 2 player, 3 enemy, 4 shot, 5 ladder.

const SHOT := preload("res://src/shot.tscn")

# --- movement ---------------------------------------------------------------
const RUN_SPEED := 90.0            # 1.5 px/frame  (MM ~1.36, MMX walk 1.5)
const JUMP_VELOCITY := -292.0      # 4.87 px/frame initial rise
const GRAVITY := 900.0             # 0.25 px/frame^2
const MAX_FALL := 420.0            # 7 px/frame terminal velocity
const JUMP_CUT := 0.35             # releasing jump early kills most of the rise
const COYOTE_TIME := 0.06          # grace period to jump after walking off
const JUMP_BUFFER := 0.08          # grace period for pressing jump early

const SLIDE_SPEED := 150.0         # 2.5 px/frame
const SLIDE_TIME := 0.42           # ~26 frames, as in MM4-6
const CLIMB_SPEED := 60.0

# --- combat -----------------------------------------------------------------
const MAX_HEALTH := 28
const FIRE_COOLDOWN := 0.12
const MAX_SHOTS := 3               # Mega Man's classic 3-on-screen limit
const HURT_TIME := 0.35            # stun length, ~21 frames
const INVULN_TIME := 1.2
const KNOCKBACK := 55.0
## Fall past this Y and you die -- saves every pit needing its own kill volume.
const FALL_LIMIT := 400.0

# Standing box is 3 tiles tall so it fits 3-tile corridors; the slide box is
# short enough to fit a 2-tile (16px) gap.
const STAND_SIZE := Vector2(12, 24)

# --- sprite frames ----------------------------------------------------------
# player.png is a 8x6 grid of 24x32 frames. Add or reorder freely -- this table
# is the only thing that cares about the layout.
const FRAMES := {
	"idle":       [0, 1, 2, 3],
	"idle_shoot": [28, 29],
	"run":        [4, 5, 6, 7, 8, 9, 10, 11],
	"run_shoot":  [30, 31, 32, 33, 34, 35, 36, 37],
	"jump":       [12, 13],
	"fall":       [14, 15],
	"jump_shoot": [38],
	"slide":      [17, 18],
	"climb":      [21, 22],
	"hurt":       [19, 20],
}

var health := MAX_HEALTH
var facing := 1

var _sliding := false
var _slide_timer := 0.0
var _climbing := false
var _ladder: Area2D = null
var _coyote := 0.0
var _jump_buffer := 0.0
var _fire_cooldown := 0.0
var _shoot_pose := 0.0
var _hurt_timer := 0.0
var _invuln := 0.0
var _anim := "idle"
var _anim_time := 0.0
var _shots: Array[Node] = []

@onready var sprite: Sprite2D = $Sprite
@onready var stand_shape: CollisionShape2D = $StandShape
@onready var slide_shape: CollisionShape2D = $SlideShape


func _ready() -> void:
	add_to_group(&"player")
	$Hurtbox.body_entered.connect(_on_touched_enemy)
	$LadderProbe.area_entered.connect(func(a: Area2D) -> void: _ladder = a)
	$LadderProbe.area_exited.connect(func(a: Area2D) -> void:
		if _ladder == a:
			_ladder = null)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if global_position.y > FALL_LIMIT:
		die()
		return

	if _hurt_timer > 0.0:
		_hurt_movement(delta)
	elif _climbing:
		_climb_movement(delta)
	elif _sliding:
		_slide_movement(delta)
	else:
		_normal_movement(delta)
		_try_fire()

	_animate(delta)


# ---------------------------------------------------------------------------
# movement
# ---------------------------------------------------------------------------
func _normal_movement(delta: float) -> void:
	var input_x := Input.get_axis(&"move_left", &"move_right")
	if input_x != 0.0:
		facing = signi(int(input_x))

	velocity.x = input_x * RUN_SPEED
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	# Down + jump slides, matching MM4-6. The C key does it too.
	if _jump_buffer > 0.0 and _coyote > 0.0:
		if Input.is_action_pressed(&"move_down") and is_on_floor():
			_start_slide()
			return
		_jump()
	elif Input.is_action_just_pressed(&"slide") and is_on_floor():
		_start_slide()
		return

	# Variable jump height: let go early and you stop rising.
	if velocity.y < 0.0 and not Input.is_action_pressed(&"jump"):
		velocity.y *= JUMP_CUT

	if _grab_ladder():
		return

	move_and_slide()


func _jump() -> void:
	velocity.y = JUMP_VELOCITY
	_jump_buffer = 0.0
	_coyote = 0.0


func _start_slide() -> void:
	_sliding = true
	_slide_timer = SLIDE_TIME
	_jump_buffer = 0.0
	_set_shape(true)


func _slide_movement(delta: float) -> void:
	_slide_timer -= delta
	velocity.x = SLIDE_SPEED * facing
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()

	var cancelled := Input.is_action_just_pressed(&"jump") and not Input.is_action_pressed(&"move_down")
	if _slide_timer > 0.0 and not is_on_wall() and not cancelled and is_on_floor():
		return

	# Keep sliding while there is a ceiling overhead -- you can't stand up in a
	# 2-tile tunnel, so the slide extends until you're clear.
	if not _has_headroom():
		_slide_timer = 0.05
		return

	_sliding = false
	_set_shape(false)
	if cancelled and is_on_floor():
		_jump()


func _climb_movement(_delta: float) -> void:
	if _ladder == null or not is_instance_valid(_ladder):
		_climbing = false
		return

	var dir := Input.get_axis(&"move_up", &"move_down")
	velocity = Vector2(0.0, dir * CLIMB_SPEED)
	global_position.x = move_toward(global_position.x, _ladder.global_position.x, 2.0)
	move_and_slide()

	# Jumping or reaching the end of the ladder lets go.
	if Input.is_action_just_pressed(&"jump") or _ladder == null:
		_climbing = false
		velocity.y = 0.0
	elif is_on_floor() and dir > 0.0:
		_climbing = false


func _grab_ladder() -> bool:
	if _ladder == null:
		return false
	if not (Input.is_action_pressed(&"move_up") or Input.is_action_pressed(&"move_down")):
		return false
	_climbing = true
	velocity = Vector2.ZERO
	return true


func _hurt_movement(delta: float) -> void:
	_hurt_timer -= delta
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	velocity.x = move_toward(velocity.x, 0.0, 240.0 * delta)
	move_and_slide()


# ---------------------------------------------------------------------------
# shooting
# ---------------------------------------------------------------------------
func _try_fire() -> void:
	if not Input.is_action_just_pressed(&"fire") or _fire_cooldown > 0.0:
		return

	# Drop shots that already hit something, then enforce the on-screen limit.
	var alive: Array[Node] = []
	for s in _shots:
		if is_instance_valid(s):
			alive.append(s)
	_shots = alive
	if _shots.size() >= MAX_SHOTS:
		return

	var shot := SHOT.instantiate()
	shot.global_position = $Muzzle.global_position
	shot.direction = facing
	get_parent().add_child(shot)
	_shots.append(shot)

	_fire_cooldown = FIRE_COOLDOWN
	_shoot_pose = 0.25


# ---------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------
func take_damage(amount: int, from: Node2D = null) -> void:
	if _invuln > 0.0:
		return

	health -= amount
	if health <= 0:
		die()
		return

	_hurt_timer = HURT_TIME
	_invuln = INVULN_TIME

	var away := -facing
	if from:
		away = signi(int(signf(global_position.x - from.global_position.x)))
		if away == 0:
			away = -facing
	velocity = Vector2(away * KNOCKBACK, -60.0)

	if _sliding:
		_sliding = false
		_set_shape(false)


func die() -> void:
	# Simplest possible respawn: start the level over.
	get_tree().reload_current_scene()


func _on_touched_enemy(body: Node) -> void:
	if body.has_method("get_contact_damage"):
		take_damage(body.get_contact_damage(), body as Node2D)


# ---------------------------------------------------------------------------
# housekeeping
# ---------------------------------------------------------------------------
func _tick_timers(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_shoot_pose = maxf(0.0, _shoot_pose - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_coyote = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote - delta)

	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer = JUMP_BUFFER

	if _invuln > 0.0:
		_invuln -= delta
		# blink twice per 0.12s while invulnerable
		sprite.visible = fmod(_invuln, 0.12) < 0.06
		if _invuln <= 0.0:
			sprite.visible = true


## True when there is room to stand up where we are.
func _has_headroom() -> bool:
	var box := RectangleShape2D.new()
	box.size = STAND_SIZE - Vector2(1.0, 0.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, -STAND_SIZE.y * 0.5))
	query.collision_mask = 1        # world
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Deferred because the physics server refuses shape changes while it is busy
## resolving collisions -- which is exactly when a hit cancels a slide.
func _set_shape(sliding: bool) -> void:
	stand_shape.set_deferred(&"disabled", sliding)
	slide_shape.set_deferred(&"disabled", not sliding)


func _animate(delta: float) -> void:
	var shooting := _shoot_pose > 0.0
	var next := "idle"
	var fps := 3.0

	if _hurt_timer > 0.0:
		next = "hurt"
	elif _sliding:
		next = "slide"
		fps = 12.0
	elif _climbing:
		next = "climb"
		fps = 6.0 if absf(velocity.y) > 1.0 else 0.0
	elif not is_on_floor():
		next = "jump_shoot" if shooting else ("jump" if velocity.y < 0.0 else "fall")
		fps = 6.0
	elif absf(velocity.x) > 1.0:
		next = "run_shoot" if shooting else "run"
		fps = 14.0
	elif shooting:
		next = "idle_shoot"
		fps = 6.0

	if next != _anim:
		_anim = next
		_anim_time = 0.0
	_anim_time += delta

	var list: Array = FRAMES[_anim]
	var index := 0
	if fps > 0.0 and list.size() > 1:
		index = int(_anim_time * fps) % list.size()
	sprite.frame = list[index]
	sprite.flip_h = facing < 0
	$Muzzle.position.x = absf($Muzzle.position.x) * facing
