extends CharacterBody2D
## Mega Man / Mega Man X style movement and shooting.
##
## Everything worth tuning is an @export below, so you can drag the values in
## the inspector. Speeds are pixels/second at 60 physics ticks; the original
## per-frame values from the games are noted in the comments.
##
## Controls (either layout):
##   arrows / WASD   move and climb
##   X / K           jump, hold for height
##   Z / J           fire, hold to charge
##   C / L           slide (or down + jump)
##   R               respawn

const SHOT := preload("res://src/shot.tscn")

# These are @export rather than const so you can drag them in the inspector
# while the game is running (Debug > "Remote" tree) and feel the change live.
# Editing the numbers here works too, as long as you haven't overridden them on
# the Player node -- an inspector tweak saves into player.tscn and wins.

@export_group("Running")
@export var run_speed := 90.0           # 1.5 px/frame  (MM ~1.36, MMX walk 1.5)

@export_group("Jumping")
## Initial upward speed. Bigger number = higher jump.
@export var jump_velocity := -310.0     # 5.17 px/frame
## Pulls you down. Smaller number = floatier, longer hang time.
@export var gravity := 720.0            # 0.2 px/frame^2
## Fastest you can ever fall.
@export var max_fall := 360.0           # 6 px/frame
## Releasing jump mid-rise multiplies the remaining rise by this.
@export var jump_cut := 0.45
## You can still jump this long after walking off a ledge.
@export var coyote_time := 0.06
## A jump pressed this soon before landing still counts.
@export var jump_buffer := 0.08

@export_group("Slide")
@export var slide_speed := 150.0        # 2.5 px/frame
@export var slide_time := 0.42          # ~26 frames, as in MM4-6
@export var slide_cooldown := 0.06

@export_group("Ladders")
@export var climb_speed := 60.0
@export var ladder_snap := 2.0          # px/frame pull toward the ladder centre

@export_group("Shooting")
@export var fire_cooldown := 0.12
@export var max_shots := 3              # Mega Man's 3-on-screen limit
## Seconds of holding fire needed for each tier. Index 0 is the tap shot.
@export var charge_times: Array[float] = [0.0, 0.5, 1.15]   # MMX pacing

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

	velocity.x = input_x * run_speed
	velocity.y = minf(velocity.y + gravity * delta, max_fall)

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
		velocity.y *= jump_cut

	if _try_grab_ladder():
		return

	move_and_slide()


func _jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer = 0.0
	_coyote = 0.0


func _start_slide() -> void:
	sliding = true
	_slide_timer = slide_time
	_jump_buffer = 0.0
	_set_shape(true)


func _slide(delta: float) -> void:
	_slide_timer -= delta
	velocity.x = slide_speed * facing
	velocity.y = minf(velocity.y + gravity * delta, max_fall)
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
	_slide_cooldown = slide_cooldown
	_set_shape(false)
	if cancelled and is_on_floor():
		_jump()


func _climb(_delta: float) -> void:
	if _ladder == null or not is_instance_valid(_ladder):
		climbing = false
		return

	velocity = Vector2(0.0, Input.get_axis(&"move_up", &"move_down") * climb_speed)
	global_position.x = move_toward(global_position.x, _ladder.global_position.x, ladder_snap)
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
	for i in charge_times.size():
		if _charge >= charge_times[i]:
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
	if tier == 0 and _shots.size() >= max_shots:
		return

	var shot := SHOT.instantiate()
	shot.global_position = muzzle.global_position
	shot.direction = facing
	shot.tier = tier
	get_parent().add_child(shot)
	_shots.append(shot)
	_fire_cooldown = fire_cooldown


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
	_coyote = coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer = jump_buffer


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
