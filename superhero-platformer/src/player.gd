extends CharacterBody2D
## Mega Man / Mega Man X style movement and shooting.
##
## Everything worth tuning is a constant below. Speeds are pixels/second at 60
## physics ticks; the original per-frame values from the games are in the
## comments so you can check them against the real thing.
##
## Controls: arrows move/climb, X jump, Z fire (hold to charge), C slide, R restart.

const SHOT := preload("res://src/shot.tscn")

# --- running and jumping ----------------------------------------------------
const RUN_SPEED := 90.0          # 1.5 px/frame  (MM ~1.36, MMX walk 1.5)
const JUMP_VELOCITY := -292.0    # 4.87 px/frame initial rise
const GRAVITY := 900.0           # 0.25 px/frame^2
const MAX_FALL := 420.0          # 7 px/frame terminal velocity
const JUMP_CUT := 0.35           # release jump early and the rise is cut short
const COYOTE_TIME := 0.06        # can still jump this long after leaving a ledge
const JUMP_BUFFER := 0.08        # a jump pressed this early still counts

# --- slide ------------------------------------------------------------------
const SLIDE_SPEED := 150.0       # 2.5 px/frame
const SLIDE_TIME := 0.42         # ~26 frames, as in MM4-6
const SLIDE_COOLDOWN := 0.06

# --- ladders ----------------------------------------------------------------
const CLIMB_SPEED := 60.0
const LADDER_SNAP := 2.0         # px/frame pull toward the ladder's centre

# --- shooting ---------------------------------------------------------------
const FIRE_COOLDOWN := 0.12
const MAX_SHOTS := 3             # Mega Man's 3-on-screen limit
## Hold times for each charge tier. Index 0 is the tap shot.
const CHARGE_TIMES := [0.0, 0.5, 1.15]     # MMX pacing
const CHARGE_COLORS := [
	Color(1, 1, 1),                 # uncharged, no tint
	Color(1.35, 1.35, 1.6),         # mid charge, brightening
	Color(1.7, 1.9, 2.2),           # full charge, hot white-blue
]

# Standing box is 3 tiles tall so it fits 3-tile corridors; the slide box is
# short enough to fit a 2-tile (16px) gap.
const STAND_SIZE := Vector2(12, 24)
## Fall past this and you respawn.
const FALL_LIMIT := 400.0

var facing := 1
var sliding := false
var climbing := false

var _spawn_point := Vector2.ZERO
var _slide_timer := 0.0
var _slide_cooldown := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _fire_cooldown := 0.0
var _charge := 0.0
var _charging := false
var _ladder: Area2D = null
var _shots: Array[Node] = []

@onready var sprite: Sprite2D = $Sprite
@onready var stand_shape: CollisionShape2D = $StandShape
@onready var slide_shape: CollisionShape2D = $SlideShape
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	add_to_group(&"player")
	_spawn_point = global_position
	$LadderProbe.area_entered.connect(func(a: Area2D) -> void: _ladder = a)
	$LadderProbe.area_exited.connect(func(a: Area2D) -> void:
		if _ladder == a:
			_ladder = null)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if Input.is_action_just_pressed(&"restart") or global_position.y > FALL_LIMIT:
		respawn()
		return

	if climbing:
		_climb(delta)
	elif sliding:
		_slide(delta)
	else:
		_walk(delta)

	_handle_firing(delta)
	_update_sprite()


# ---------------------------------------------------------------------------
# movement
# ---------------------------------------------------------------------------
func _walk(delta: float) -> void:
	var input_x := Input.get_axis(&"move_left", &"move_right")
	if input_x != 0.0:
		facing = signi(int(input_x))

	velocity.x = input_x * RUN_SPEED
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	# Down + jump slides, as in MM4-6. The C key does the same thing.
	if _jump_buffer > 0.0 and _coyote > 0.0:
		if Input.is_action_pressed(&"move_down") and is_on_floor() and _slide_cooldown <= 0.0:
			_start_slide()
			return
		_jump()
	elif Input.is_action_just_pressed(&"slide") and is_on_floor() and _slide_cooldown <= 0.0:
		_start_slide()
		return

	# Variable jump height: let go of jump and you stop rising.
	if velocity.y < 0.0 and not Input.is_action_pressed(&"jump"):
		velocity.y *= JUMP_CUT

	if _try_grab_ladder():
		return

	move_and_slide()


func _jump() -> void:
	velocity.y = JUMP_VELOCITY
	_jump_buffer = 0.0
	_coyote = 0.0


func _start_slide() -> void:
	sliding = true
	_slide_timer = SLIDE_TIME
	_jump_buffer = 0.0
	_set_shape(true)


func _slide(delta: float) -> void:
	_slide_timer -= delta
	velocity.x = SLIDE_SPEED * facing
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()

	var cancelled := Input.is_action_just_pressed(&"jump") and not Input.is_action_pressed(&"move_down")
	var finished := _slide_timer <= 0.0 or is_on_wall() or not is_on_floor()
	if not (finished or cancelled):
		return

	# You can't stand up inside a 2-tile tunnel, so the slide keeps going until
	# there is headroom again.
	if not _has_headroom():
		_slide_timer = 0.05
		return

	sliding = false
	_slide_cooldown = SLIDE_COOLDOWN
	_set_shape(false)
	if cancelled and is_on_floor():
		_jump()


func _climb(_delta: float) -> void:
	if _ladder == null or not is_instance_valid(_ladder):
		climbing = false
		return

	velocity = Vector2(0.0, Input.get_axis(&"move_up", &"move_down") * CLIMB_SPEED)
	global_position.x = move_toward(global_position.x, _ladder.global_position.x, LADDER_SNAP)
	move_and_slide()

	# Jump off, or step off the top or bottom.
	if Input.is_action_just_pressed(&"jump"):
		climbing = false
		velocity.y = 0.0
	elif _ladder == null:
		climbing = false
	elif is_on_floor() and Input.is_action_pressed(&"move_down"):
		climbing = false


func _try_grab_ladder() -> bool:
	if _ladder == null:
		return false
	if not (Input.is_action_pressed(&"move_up") or Input.is_action_pressed(&"move_down")):
		return false
	# Pressing down while standing on solid ground shouldn't grab a ladder we're
	# already on top of.
	if Input.is_action_pressed(&"move_down") and is_on_floor() \
			and _ladder.global_position.y < global_position.y:
		return false
	climbing = true
	velocity = Vector2.ZERO
	return true


# ---------------------------------------------------------------------------
# shooting
# ---------------------------------------------------------------------------
func _handle_firing(delta: float) -> void:
	# Mega Man 4+ rule: pressing fire shoots immediately AND starts charging.
	# Releasing after passing a threshold fires that charge tier.
	if Input.is_action_just_pressed(&"fire"):
		_fire(0)
		_charging = true
		_charge = 0.0
	elif _charging and Input.is_action_pressed(&"fire"):
		_charge += delta
	elif _charging:
		_charging = false
		var tier := charge_tier()
		if tier > 0:
			_fire(tier)
		_charge = 0.0


## Highest charge tier reached so far: 0 tap, 1 mid, 2 full.
func charge_tier() -> int:
	var tier := 0
	for i in CHARGE_TIMES.size():
		if _charge >= CHARGE_TIMES[i]:
			tier = i
	return tier


func _fire(tier: int) -> void:
	if _fire_cooldown > 0.0:
		return

	# Drop shots that already hit something, then apply the on-screen limit.
	var alive: Array[Node] = []
	for s in _shots:
		if is_instance_valid(s):
			alive.append(s)
	_shots = alive
	# Charged shots ignore the limit -- you only ever have one out at a time.
	if tier == 0 and _shots.size() >= MAX_SHOTS:
		return

	var shot := SHOT.instantiate()
	shot.global_position = muzzle.global_position
	shot.direction = facing
	shot.tier = tier
	get_parent().add_child(shot)
	_shots.append(shot)
	_fire_cooldown = FIRE_COOLDOWN


# ---------------------------------------------------------------------------
# housekeeping
# ---------------------------------------------------------------------------
func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	sliding = false
	climbing = false
	_charging = false
	_charge = 0.0
	_set_shape(false)


func _tick_timers(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_slide_cooldown = maxf(0.0, _slide_cooldown - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_coyote = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer = JUMP_BUFFER


## True when there's room to stand up where we are.
func _has_headroom() -> bool:
	var box := RectangleShape2D.new()
	box.size = STAND_SIZE - Vector2(1.0, 0.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, -STAND_SIZE.y * 0.5))
	query.collision_mask = 1        # world
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Deferred because the physics server refuses shape changes while it is
## resolving collisions, which is where some of these calls come from.
func _set_shape(is_sliding: bool) -> void:
	stand_shape.set_deferred(&"disabled", is_sliding)
	slide_shape.set_deferred(&"disabled", not is_sliding)


func _update_sprite() -> void:
	sprite.frame = 1 if sliding else 0
	sprite.flip_h = facing < 0
	muzzle.position.x = absf(muzzle.position.x) * facing
	muzzle.position.y = -8.0 if sliding else -16.0

	# Charging flashes the hero brighter as each tier is reached.
	var tint := Color.WHITE
	if _charging:
		var tier := charge_tier()
		if tier > 0:
			# alternate between white and the tier colour so it visibly pulses
			var flash := int(Time.get_ticks_msec() / 60.0) % 2 == 0
			tint = CHARGE_COLORS[tier] if flash else Color.WHITE
	sprite.modulate = tint
