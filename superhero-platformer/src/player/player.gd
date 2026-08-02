class_name Player
extends CharacterBody2D
## The hero. Movement is tuned against Mega Man 5/6 and Mega Man X:
## instant ground acceleration, a fixed jump arc with a variable cut, and a
## fixed-duration slide that fits through 2-tile (16px) gaps.
##
## All speeds are in pixels/second at 60 physics ticks -- the per-frame values
## from the reference games are noted next to each constant.

signal died
signal health_changed(current: int, maximum: int)
signal state_changed(state: int)
signal landed

enum State { SPAWNING, IDLE, RUN, JUMP, FALL, SLIDE, CLIMB, HURT, DEAD, VICTORY }

# --- movement constants ----------------------------------------------------
const RUN_SPEED := 90.0            # 1.5 px/frame  (MM: 1.36, MMX walk: 1.5)
const AIR_SPEED := 90.0            # no air-drag in the reference games
const JUMP_VELOCITY := -292.0      # 4.87 px/frame initial rise
const GRAVITY := 900.0             # 0.25 px/frame^2
const MAX_FALL := 420.0            # 7 px/frame terminal velocity
const JUMP_CUT_MULTIPLIER := 0.35  # releasing jump kills most of the rise
const COYOTE_TIME := 0.06
const JUMP_BUFFER := 0.08

const SLIDE_SPEED := 150.0         # 2.5 px/frame
const SLIDE_TIME := 0.42           # ~26 frames, as in MM4-6
const SLIDE_COOLDOWN := 0.06

const CLIMB_SPEED := 60.0
const CLIMB_SNAP := 2.0            # px/frame horizontal snap onto a ladder

const HURT_TIME := 0.35            # ~21 frames of stun
const HURT_KNOCKBACK := 55.0
const INVULN_TIME := 1.2
const BLINK_RATE := 0.06

const STAND_SIZE := Vector2(12, 24)   # 3 tiles tall -- fits 3-tile corridors
const SLIDE_SIZE := Vector2(12, 14)   # fits 2-tile (16px) gaps

# --- frame tables (indices into player.png, 8 columns) ---------------------
const FRAMES := {
	"idle":        [0, 1, 2, 3],
	"idle_shoot":  [28, 29],
	"run":         [4, 5, 6, 7, 8, 9, 10, 11],
	"run_shoot":   [30, 31, 32, 33, 34, 35, 36, 37],
	"jump":        [12, 13],
	"jump_shoot":  [38],
	"fall":        [14, 15],
	"fall_shoot":  [39],
	"land":        [16],
	"slide":       [17, 18],
	"hurt":        [19, 20],
	"climb":       [21, 22],
	"climb_shoot": [40, 41],
	"climb_top":   [23],
	"beam":        [24],
	"beam_land":   [25, 26],
	"victory":     [27],
}
const IDLE_FPS := 3.0
const RUN_FPS := 14.0
const CLIMB_FPS := 6.0

# --- tunable per-level modifiers -------------------------------------------
## Water / low-gravity rooms multiply these instead of touching the constants.
var gravity_scale: float = 1.0
var speed_scale: float = 1.0
var jump_scale: float = 1.0
## Injected by conveyors and moving platforms each frame.
var external_velocity: Vector2 = Vector2.ZERO

# --- state -----------------------------------------------------------------
var state: State = State.SPAWNING
var facing: int = 1
var invulnerable: bool = false
var control_enabled: bool = true

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _slide_timer: float = 0.0
var _slide_cooldown: float = 0.0
var _hurt_timer: float = 0.0
var _invuln_timer: float = 0.0
var _blink_timer: float = 0.0
var _anim_time: float = 0.0
var _anim_name: String = "idle"
var _shoot_pose: float = 0.0
var _land_timer: float = 0.0
var _ladders: Array[Area2D] = []
var _current_ladder: Area2D = null
var _spawn_target_y: float = 0.0
var _shape_sliding: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var stand_shape: CollisionShape2D = $StandShape
@onready var slide_shape: CollisionShape2D = $SlideShape
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapons: WeaponSystem = $WeaponSystem
@onready var ladder_probe: Area2D = $LadderProbe


func _ready() -> void:
	add_to_group(&"player")
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 4.0
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD

	hurtbox.collision_layer = Layers.PLAYER_HURTBOX
	hurtbox.collision_mask = Layers.ENEMY | Layers.HAZARD
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	ladder_probe.collision_layer = 0
	ladder_probe.collision_mask = Layers.LADDER
	ladder_probe.area_entered.connect(func(a: Area2D) -> void: _ladders.append(a))
	ladder_probe.area_exited.connect(func(a: Area2D) -> void: _ladders.erase(a))

	weapons.fired.connect(_on_weapon_fired)
	GameState.weapon_changed.connect(_apply_weapon_palette)
	GameState.health_changed.connect(func(c: int, m: int) -> void: health_changed.emit(c, m))
	_apply_weapon_palette(GameState.current_weapon())
	_use_stand_shape()


## Beam-in entrance. Pass the ground position the hero should land on.
func spawn_at(pos: Vector2, beam: bool = true) -> void:
	global_position = pos
	_spawn_target_y = pos.y
	velocity = Vector2.ZERO
	control_enabled = false
	invulnerable = true
	if beam:
		global_position.y = pos.y - 200.0
		_set_state(State.SPAWNING)
	else:
		_finish_spawn()


func _finish_spawn() -> void:
	control_enabled = true
	invulnerable = false
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if _shape_sliding and state != State.SLIDE:
		_try_stand_up()

	match state:
		State.SPAWNING: _process_spawn(delta)
		State.HURT:     _process_hurt(delta)
		State.SLIDE:    _process_slide(delta)
		State.CLIMB:    _process_climb(delta)
		State.DEAD, State.VICTORY: _process_locked(delta)
		_:              _process_normal(delta)

	_animate(delta)
	external_velocity = Vector2.ZERO


func _tick_timers(delta: float) -> void:
	_slide_cooldown = maxf(0.0, _slide_cooldown - delta)
	_shoot_pose = maxf(0.0, _shoot_pose - delta)
	_land_timer = maxf(0.0, _land_timer - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		_blink_timer += delta
		sprite.visible = fmod(_blink_timer, BLINK_RATE * 2.0) < BLINK_RATE
		if _invuln_timer <= 0.0:
			invulnerable = false
			sprite.visible = true

	if control_enabled and Input.is_action_just_pressed(&"jump"):
		_jump_buffer = JUMP_BUFFER


# ---------------------------------------------------------------------------
# states
# ---------------------------------------------------------------------------
func _process_spawn(delta: float) -> void:
	velocity = Vector2(0.0, 520.0)
	move_and_slide()
	if global_position.y >= _spawn_target_y - 0.5 or is_on_floor():
		global_position.y = _spawn_target_y
		velocity = Vector2.ZERO
		AudioManager.play_sfx(&"land")
		_land_timer = 0.18
		_finish_spawn()


func _process_locked(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = minf(velocity.y + _gravity() * delta, MAX_FALL)
	move_and_slide()


func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity.y = minf(velocity.y + _gravity() * delta, MAX_FALL)
	velocity.x = move_toward(velocity.x, 0.0, 240.0 * delta)
	move_and_slide()
	if _hurt_timer <= 0.0:
		weapons.enabled = true
		_set_state(State.IDLE if is_on_floor() else State.FALL)


func _process_normal(delta: float) -> void:
	var input_x := _input_axis()
	if input_x != 0:
		facing = input_x
		weapons.set_facing(facing)

	velocity.x = input_x * RUN_SPEED * speed_scale
	velocity.y = minf(velocity.y + _gravity() * delta, MAX_FALL)

	# jump / slide -- holding down turns a jump press into a slide, MM4-6 style.
	# Starting a slide has to return immediately: the state assignment at the end
	# of this function would otherwise stomp State.SLIDE back to IDLE.
	if _jump_buffer > 0.0 and _coyote > 0.0:
		if Input.is_action_pressed(&"move_down") and is_on_floor() and _slide_cooldown <= 0.0:
			_start_slide()
			return
		_do_jump()
	elif Input.is_action_just_pressed(&"dash") and is_on_floor() and _slide_cooldown <= 0.0:
		_start_slide()
		return

	# variable jump height
	if velocity.y < 0.0 and not Input.is_action_pressed(&"jump"):
		velocity.y *= JUMP_CUT_MULTIPLIER

	if _try_grab_ladder():
		return

	var was_airborne := not is_on_floor()
	velocity += external_velocity
	move_and_slide()

	if was_airborne and is_on_floor():
		_land_timer = 0.12
		AudioManager.play_sfx(&"land")
		landed.emit()

	if not is_on_floor():
		_set_state(State.JUMP if velocity.y < 0.0 else State.FALL)
	elif absf(velocity.x) > 1.0:
		_set_state(State.RUN)
	else:
		_set_state(State.IDLE)


func _process_slide(delta: float) -> void:
	_slide_timer -= delta
	velocity.x = SLIDE_SPEED * facing * speed_scale
	velocity.y = minf(velocity.y + _gravity() * delta, MAX_FALL)
	velocity += external_velocity
	move_and_slide()

	var blocked := is_on_wall()
	var cancel := Input.is_action_just_pressed(&"jump") and not Input.is_action_pressed(&"move_down")
	if _slide_timer <= 0.0 or blocked or cancel or not is_on_floor():
		if not _end_slide():
			return
		if cancel and is_on_floor():
			_do_jump()


func _process_climb(delta: float) -> void:
	if _current_ladder == null or not is_instance_valid(_current_ladder):
		_release_ladder()
		return

	var vy := 0.0
	if Input.is_action_pressed(&"move_up"):
		vy = -CLIMB_SPEED
	elif Input.is_action_pressed(&"move_down"):
		vy = CLIMB_SPEED
	velocity = Vector2(0.0, vy)

	# snap to the ladder's centre line
	var target_x: float = _current_ladder.global_position.x
	global_position.x = move_toward(global_position.x, target_x, CLIMB_SNAP)

	move_and_slide()

	if Input.is_action_just_pressed(&"jump"):
		_release_ladder()
		velocity.y = 0.0
		return
	# stepped off the top or bottom
	if not _ladders.has(_current_ladder):
		_release_ladder()
		return
	if is_on_floor() and Input.is_action_pressed(&"move_down"):
		_release_ladder()


# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------
func _gravity() -> float:
	return GRAVITY * gravity_scale


func _input_axis() -> int:
	if not control_enabled:
		return 0
	return int(Input.get_axis(&"move_left", &"move_right"))


func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY * jump_scale
	_jump_buffer = 0.0
	_coyote = 0.0
	AudioManager.play_sfx(&"jump")
	_set_state(State.JUMP)


func _start_slide() -> void:
	_slide_timer = SLIDE_TIME
	_jump_buffer = 0.0
	_use_slide_shape()
	weapons.enabled = true
	AudioManager.play_sfx(&"slide")
	_set_state(State.SLIDE)


## Returns false (and stays sliding) when there is no headroom to stand up.
func _end_slide() -> bool:
	if not _can_stand():
		_slide_timer = maxf(_slide_timer, 0.05)
		return false
	_use_stand_shape()
	_slide_cooldown = SLIDE_COOLDOWN
	_set_state(State.IDLE if is_on_floor() else State.FALL)
	return true


func _can_stand() -> bool:
	var shape := RectangleShape2D.new()
	shape.size = STAND_SIZE - Vector2(1.0, 0.0)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position + Vector2(0.0, -STAND_SIZE.y * 0.5))
	params.collision_mask = Layers.WORLD
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


func _use_stand_shape() -> void:
	_set_shapes(false)


func _use_slide_shape() -> void:
	_set_shapes(true)


## The physics server rejects shape toggles while it is flushing queries, which
## is exactly where we are when a hurtbox signal cancels a slide. Deferring is
## always safe: both callers hand control back immediately afterwards, so no
## movement happens with the stale shape.
func _set_shapes(sliding: bool) -> void:
	_shape_sliding = sliding
	stand_shape.set_deferred(&"disabled", sliding)
	slide_shape.set_deferred(&"disabled", not sliding)


## Stand back up only when there is headroom. Taking a hit mid-slide under a
## low ceiling leaves the short shape in place; the check at the top of
## _physics_process restores it as soon as the hero is clear.
func _try_stand_up() -> bool:
	if not _shape_sliding:
		return true
	if not _can_stand():
		return false
	_use_stand_shape()
	return true


func _try_grab_ladder() -> bool:
	if _ladders.is_empty():
		return false
	var up := Input.is_action_pressed(&"move_up")
	var down := Input.is_action_pressed(&"move_down")
	if not (up or down) or not control_enabled:
		return false
	if down and is_on_floor() and not _ladder_below():
		return false
	_current_ladder = _ladders[0]
	velocity = Vector2.ZERO
	_set_state(State.CLIMB)
	return true


func _ladder_below() -> bool:
	for l in _ladders:
		if l.global_position.y > global_position.y - 4.0:
			return true
	return false


func _release_ladder() -> void:
	_current_ladder = null
	_set_state(State.FALL)


# ---------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------
func take_damage(amount: int, source: Node = null) -> bool:
	if invulnerable or state == State.DEAD or state == State.SPAWNING:
		return false
	GameState.health = GameState.health - amount
	if GameState.health <= 0:
		_die()
		return true

	_hurt_timer = HURT_TIME
	_invuln_timer = INVULN_TIME
	invulnerable = true
	_blink_timer = 0.0
	weapons.enabled = false

	var away := 1.0
	if source is Node2D:
		away = signf(global_position.x - (source as Node2D).global_position.x)
		if is_zero_approx(away):
			away = -facing
	else:
		away = -facing
	velocity = Vector2(away * HURT_KNOCKBACK, -60.0)
	if state == State.SLIDE:
		_use_stand_shape()
	_current_ladder = null
	AudioManager.play_sfx(&"hurt")
	_set_state(State.HURT)
	return true


## Spikes, pits and crushers ignore invulnerability, exactly like Mega Man.
func kill_instantly() -> void:
	if state == State.DEAD:
		return
	GameState.health = 0
	_die()


func _die() -> void:
	_set_state(State.DEAD)
	control_enabled = false
	weapons.enabled = false
	invulnerable = true
	sprite.visible = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	AudioManager.play_sfx(&"player_death")
	_spawn_death_burst()
	died.emit()


func _spawn_death_burst() -> void:
	var fx := preload("res://src/fx/death_burst.tscn").instantiate()
	fx.global_position = global_position + Vector2(0, -STAND_SIZE.y * 0.5)
	get_parent().add_child(fx)


func heal(amount: int) -> void:
	GameState.heal(amount)
	AudioManager.play_sfx(&"heal")


func victory_pose() -> void:
	control_enabled = false
	weapons.enabled = false
	velocity = Vector2.ZERO
	_set_state(State.VICTORY)


func _on_hurtbox_body_entered(body: Node) -> void:
	# enemy bodies deal contact damage
	if body.has_method("get_contact_damage"):
		take_damage(int(body.call("get_contact_damage")), body as Node2D)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"instant_death"):
		kill_instantly()
	elif area.has_method("get_contact_damage"):
		take_damage(int(area.call("get_contact_damage")), area)


## Called by enemy projectiles.
func apply_damage(amount: int, source: Node = null) -> bool:
	return take_damage(amount, source)


# ---------------------------------------------------------------------------
# presentation
# ---------------------------------------------------------------------------
func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	_anim_time = 0.0
	state_changed.emit(state)


func _on_weapon_fired(_stage_index: int, _stage: WeaponChargeStage) -> void:
	var w := GameState.current_weapon()
	_shoot_pose = w.pose_time if w else 0.25


func _animate(delta: float) -> void:
	_anim_time += delta
	var shooting := _shoot_pose > 0.0
	var anim := "idle"
	var fps := IDLE_FPS

	match state:
		State.SPAWNING:
			anim = "beam"
		State.DEAD:
			anim = "hurt"
		State.VICTORY:
			anim = "victory"
		State.HURT:
			anim = "hurt"
			fps = 8.0
		State.SLIDE:
			anim = "slide"
			fps = 12.0
		State.CLIMB:
			anim = "climb_shoot" if shooting else "climb"
			fps = CLIMB_FPS if absf(velocity.y) > 1.0 else 0.0
		State.RUN:
			anim = "run_shoot" if shooting else "run"
			fps = RUN_FPS
		State.JUMP:
			anim = "jump_shoot" if shooting else "jump"
			fps = 6.0
		State.FALL:
			anim = "fall_shoot" if shooting else "fall"
			fps = 6.0
		_:
			if _land_timer > 0.0:
				anim = "land"
			else:
				anim = "idle_shoot" if shooting else "idle"
				fps = 6.0 if shooting else IDLE_FPS

	if anim != _anim_name:
		_anim_name = anim
		_anim_time = 0.0

	var frames: Array = FRAMES[anim]
	var index := 0
	if fps > 0.0 and frames.size() > 1:
		index = int(_anim_time * fps) % frames.size()
	sprite.frame = frames[index]
	sprite.flip_h = facing < 0


func _apply_weapon_palette(weapon: WeaponData) -> void:
	if weapon == null:
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter(&"replace_mid", weapon.suit_primary)
	mat.set_shader_parameter(&"replace_light", weapon.suit_secondary)
	mat.set_shader_parameter(&"replace_dark", weapon.suit_primary.darkened(0.45))
