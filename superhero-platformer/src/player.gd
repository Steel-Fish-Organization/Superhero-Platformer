extends CharacterBody2D
## Mega Man / Mega Man X style movement and shooting.
##
## Everything worth tuning is an @export below, so you can drag the values in
## the inspector. Speeds are pixels/second at 60 physics ticks; the original
## per-frame values from the games are noted in the comments.
##
## Controls (either layout):
##   arrows / WASD   move and climb
##   X / K / Space   jump, hold for height
##   Z / J / LMB     fire, hold to charge
##   C / L           slide (or down + jump)
##   hold down       crouch (on the ground)
##   mouse           aim, once it moves
##   Q               next weapon
##   R               respawn
##
## Gamepad: left stick / D-pad move, right stick aims. Jump A or LT, fire X or
## RT, slide B or LB -- the shoulder buttons are there so you can keep your
## right thumb on the aim stick.

## The camera listens for this so it snaps to the spawn room instead of
## scrolling to it as if you had walked there.
signal respawned
## The HUD listens for this.
signal health_changed(current: int, maximum: int)


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
## A slide pressed this soon before one can start (the tail of the previous
## slide, or its cooldown) still happens. Longer than the jump buffer so that
## chaining slides never drops a press: it covers the last ~8 frames of a slide
## plus slide_cooldown.
@export var slide_buffer := 0.22

@export_group("Ladders")
@export var climb_speed := 60.0
@export var ladder_snap := 2.0          # px/frame pull toward the ladder centre
## The little hop that pops you onto the ledge at the top of a ladder.
@export var ladder_dismount_hop := -110.0
## Jumping off a ladder uses this share of a normal jump.
@export var ladder_jump_scale := 0.85

@export_group("Hanging")
## Jump up into the underside of a one-way platform, or touch a hook from any
## angle, and the hero latches on -- Darkwing Duck style. Hanging you can shoot
## in any direction, jump off, drop off with down, or press up to climb onto a
## platform you're hanging under.
@export var hang_enabled := true
## How far below the grabbed surface the hero's feet end up.
@export var hang_drop := 26.0
## Jumping off a hang, as a share of a normal jump.
@export var hang_jump_scale := 1.0
## After letting go, nothing can be grabbed for this long...
@export var regrab_delay := 0.25
## ...and the hook or platform you just left stays off limits for this long, so
## jumping straight up off one doesn't snap you back onto it.
@export var same_grab_delay := 0.7
## How far above the head to look for a platform underside to grab.
@export var grab_reach := 6.0

@export_group("Aiming")
## Aim at the mouse (or touchpad) once it moves. The reticle replaces the cursor.
@export var mouse_aim := true
## Aim with the right stick while it's pushed.
@export var stick_aim := true
## How far out from the hero the reticle sits when aiming with the stick.
@export var stick_reticle_distance := 56.0

@export_group("Weapons")
## Drop weapon .tres files in here. Q cycles between them, and the first one is
## equipped at the start. Everything about how a weapon behaves lives in its
## resource file, so swapping the gun out is a drag-and-drop.
@export var weapons: Array[Weapon] = []

@export_group("Health")
@export var max_health := 28
## Seconds of stun after a hit.
@export var hurt_time := 0.35
## Seconds you can't be hit again for.
@export var invuln_time := 1.2
@export var knockback := 55.0

const MID_CHARGE_TINT := Color(1.35, 1.35, 1.6)
const FULL_CHARGE_TINT := Color(1.7, 1.9, 2.2)
## Shoulder height while crouched or sliding, where low shots come from.
const LOW_SHOULDER_Y := -8.0
## Mouse travel (in game pixels, at 432x240) needed to switch to mouse aiming,
## so a bumped desk doesn't take over a keyboard player's aim.
const MOUSE_WAKE_DISTANCE := 12.0

## STRAIGHT is classic Mega Man: shots go the way you face.
enum AimMode { STRAIGHT, MOUSE, STICK }

# Standing box is 3 tiles tall so it fits 3-tile corridors; the slide box is
# short enough to fit a 2-tile (16px) gap.
const STAND_SIZE := Vector2(12, 24)
## Backstop only: fall past this and you respawn. The room camera handles normal
## pits, since it knows where the rooms actually are.
@export var fall_limit := 4000.0

var facing := 1
var sliding := false
var crouching := false
var climbing := false
var hanging := false
var aim_mode := AimMode.STRAIGHT
## Unit vector shots are fired along.
var aim_dir := Vector2.RIGHT
## Set by the room camera during a screen transition -- input is ignored and the
## camera moves the player through the doorway itself.
var frozen := false

var health := 0
var weapon_index := 0

var _hurt_timer := 0.0
var _invuln := 0.0
var _spawn_point := Vector2.ZERO
var _slide_timer := 0.0
var _slide_cooldown := 0.0
var _slide_buffer := 0.0
## Which way the current slide goes. Separate from `facing`, which follows the
## aim, so you can slide away from where you're shooting.
var _slide_dir := 1
var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_cut_used := false
var _fire_cooldown := 0.0
var _charge := 0.0
var _charging := false
var _ladder: Area2D = null
## What we're hanging from: the world point the hands hold, the top of the
## platform (INF for a hook, which has no top to climb onto), and the hook node.
var _hang_anchor := Vector2.ZERO
var _hang_surface := INF
var _hang_hook: Area2D = null
var _regrab := 0.0
var _last_grab := 0.0
var _last_grab_anchor := Vector2.ZERO
var _last_grab_hook: Area2D = null
var _shots: Array[Node] = []
## The muzzle's right-facing position from the scene: its y is the standing
## shoulder height, its x how far out along the aim shots appear.
var _muzzle_offset := Vector2.ZERO
var _mouse_travel := 0.0
var _was_on_floor := false
var _floor_state_initialized := false

@onready var sprite: Sprite2D = $Sprite
@onready var stand_shape: CollisionShape2D = $StandShape
@onready var slide_shape: CollisionShape2D = $SlideShape
@onready var muzzle: Marker2D = $Muzzle
@onready var hurtbox: Area2D = $Hurtbox
@onready var hook_probe: Area2D = $HookProbe
@onready var reticle: Node2D = $Reticle


func _ready() -> void:
	add_to_group(&"player")
	_spawn_point = global_position
	_muzzle_offset = muzzle.position
	health = max_health
	$LadderProbe.area_entered.connect(func(a: Area2D) -> void: _ladder = a)
	$LadderProbe.area_exited.connect(func(a: Area2D) -> void:
		if _ladder == a:
			_ladder = null)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Picks the aiming device from whatever was touched last. Right-stick aiming is
## picked up in _update_aim, since it's a held state rather than an event.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if mouse_aim and aim_mode != AimMode.MOUSE:
			_mouse_travel += (event as InputEventMouseMotion).relative.length()
			if _mouse_travel >= MOUSE_WAKE_DISTANCE:
				_set_aim_mode(AimMode.MOUSE)
	elif aim_mode == AimMode.MOUSE:
		# Picking up the controller hands aiming back to it.
		var pad_button := event is InputEventJoypadButton and event.is_pressed()
		var pad_stick := event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5
		if pad_button or pad_stick:
			_set_aim_mode(AimMode.STRAIGHT)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if Input.is_action_just_pressed(&"restart") or global_position.y > fall_limit:
		respawn()
		return

	if frozen:
		velocity = Vector2.ZERO
		_update_sprite()
		return

	# Touching an enemy hurts. Their shots find us on their own.
	_check_contact()

	if _hurt_timer > 0.0:
		_hurt(delta)
	elif hanging:
		_hang()
	elif climbing:
		_climb(delta)
	elif sliding:
		_slide(delta)
	elif crouching:
		_crouch(delta)
	else:
		_walk(delta)

	_check_landing()
	_update_aim()
	_handle_firing(delta)
	_update_sprite()


# ---------------------------------------------------------------------------
# movement
# ---------------------------------------------------------------------------
func _walk(delta: float) -> void:
	var input_x := _input_x()
	if input_x != 0.0:
		facing = int(input_x)

	velocity.x = input_x * run_speed
	velocity.y = minf(velocity.y + gravity * delta, max_fall)

	# On the ground, holding down always means crouching, from the very first
	# frame -- unless you're standing on top of a ladder, where it climbs down.
	if is_on_floor() and Input.is_action_pressed(&"move_down"):
		if _try_grab_ladder():
			return
		_enter_crouch()
		_crouch(delta)
		return

	# The slide key works standing up, too.
	if _slide_buffer > 0.0 and is_on_floor() and _slide_cooldown <= 0.0:
		_start_slide(input_x)
		return
	if _jump_buffer > 0.0 and _coyote > 0.0:
		_jump()

	# Variable jump height: letting go mid-rise trims what's left of it. Applied
	# once per jump -- doing it every frame would compound and kill the rise
	# almost instantly, making the jump_cut number meaningless.
	if velocity.y < 0.0 and not _jump_cut_used and not Input.is_action_pressed(&"jump"):
		velocity.y *= jump_cut
		_jump_cut_used = true

	if _try_grab_ladder():
		return

	# In the air, jumping into a hook or the underside of a one-way platform
	# latches on.
	if hang_enabled and not is_on_floor() and _try_hang(delta):
		return

	move_and_slide()


## Left/right as exactly -1, 0 or 1. A half-tilted stick reports something like
## 0.4, which used to walk at 40% speed and, worse, round `facing` down to 0 --
## leaving shots with no direction and slides going nowhere. Mega Man has one
## walking speed, so any tilt past the deadzone counts as a full press.
func _input_x() -> float:
	return signf(Input.get_axis(&"move_left", &"move_right"))


func _jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer = 0.0
	_slide_buffer = 0.0
	_coyote = 0.0
	_jump_cut_used = false
	$SFX/SndJump.play()


func _enter_crouch() -> void:
	if crouching:
		return
	crouching = true
	_set_shape(true)


## Crouched: slide-height hitbox, no walking, but you can still turn and shoot.
## Jump from here always slides, never jumps. A press made a moment too early
## (the tail of the previous slide, or its cooldown) waits in _slide_buffer
## until the slide can start, rather than being lost or turning into a jump.
func _crouch(delta: float) -> void:
	var input_x := _input_x()
	var holding := Input.is_action_pressed(&"move_down") and is_on_floor()
	if not holding and _has_headroom():
		crouching = false
		_set_shape(false)
		_walk(delta)
		return

	if input_x != 0.0:
		facing = int(input_x)
	velocity.x = 0.0
	velocity.y = minf(velocity.y + gravity * delta, max_fall)

	if _slide_buffer > 0.0 and _slide_cooldown <= 0.0 and is_on_floor():
		_start_slide(input_x)
		return
	move_and_slide()


## Slides the way you're pushing, or the way you face if you aren't.
func _start_slide(dir_x: float) -> void:
	$SFX/SndSlide.play()
	sliding = true
	crouching = false
	_slide_dir = int(dir_x) if dir_x != 0.0 else facing
	facing = _slide_dir
	_slide_timer = slide_time
	_jump_buffer = 0.0
	_slide_buffer = 0.0
	_set_shape(true)


func _slide(delta: float) -> void:
	_slide_timer -= delta
	velocity.x = slide_speed * _slide_dir
	velocity.y = minf(velocity.y + gravity * delta, max_fall)
	move_and_slide()

	var cancelled := Input.is_action_just_pressed(&"jump") and not Input.is_action_pressed(&"move_down")
	var finished := _slide_timer <= 0.0 or is_on_wall() or not is_on_floor()
	if not (finished or cancelled):
		return

	# Still holding down on the ground: straight into a crouch, same low hitbox,
	# no standing-up frame in between, ready for the next slide.
	var crouch_next := not cancelled and is_on_floor() and Input.is_action_pressed(&"move_down")

	# Inside a 2-tile tunnel the slide keeps going until there's headroom again,
	# even if you're holding down -- stalling in a crouch in there is no fun.
	if not _has_headroom():
		_slide_timer = 0.05
		return

	sliding = false
	_slide_cooldown = slide_cooldown
	if crouch_next:
		crouching = true
		return
	_set_shape(false)
	if cancelled and is_on_floor():
		_jump()


## While climbing the player is moved directly rather than through
## move_and_slide, so he passes cleanly through the one-way ledge at the top of
## the ladder. The ladder itself defines how far up and down he can go.
func _climb(delta: float) -> void:
	if _ladder == null or not is_instance_valid(_ladder):
		climbing = false
		return

	# Jumping off a ladder is a real jump, and you keep your steering.
	if Input.is_action_just_pressed(&"jump"):
		climbing = false
		velocity = Vector2(_input_x() * run_speed, jump_velocity * ladder_jump_scale)
		_jump_cut_used = false
		# Consume the buffered press, or _walk would fire a second, full-strength
		# jump on the very next frame and override ladder_jump_scale.
		_jump_buffer = 0.0
		_slide_buffer = 0.0
		_coyote = 0.0
		return

	var top_y: float = _ladder.get_meta(&"top_y", global_position.y)
	var bottom_y: float = _ladder.get_meta(&"bottom_y", global_position.y)

	velocity = Vector2.ZERO
	global_position.y += Input.get_axis(&"move_up", &"move_down") * climb_speed * delta
	global_position.x = move_toward(global_position.x, _ladder.global_position.x, ladder_snap)

	if global_position.y <= top_y:
		# Reached the top: hop up and land on the ledge that sits there.
		global_position.y = top_y - 1.0
		climbing = false
		velocity.y = ladder_dismount_hop
	elif global_position.y >= bottom_y:
		# Reached the bottom: step off onto whatever is underneath.
		global_position.y = bottom_y
		climbing = false


func _try_grab_ladder() -> bool:
	if _ladder == null:
		return false
	var up := Input.is_action_pressed(&"move_up")
	var down := Input.is_action_pressed(&"move_down")
	if not (up or down):
		return false

	var top_y: float = _ladder.get_meta(&"top_y", global_position.y)
	var bottom_y: float = _ladder.get_meta(&"bottom_y", global_position.y)
	# Already standing on top of it -- up does nothing, down climbs back on.
	if up and global_position.y <= top_y + 2.0:
		return false
	# Standing at the foot of it -- down does nothing.
	if down and global_position.y >= bottom_y - 2.0:
		return false

	climbing = true
	velocity = Vector2.ZERO
	return true


# ---------------------------------------------------------------------------
# hanging (Darkwing Duck style)
# ---------------------------------------------------------------------------
## Looks for something to latch onto, and does it. Hooks catch you from any
## angle; a platform underside only catches you on the way up, so you don't
## snag on every ledge you drop past.
func _try_hang(delta: float) -> bool:
	if _regrab > 0.0:
		return false

	for area in hook_probe.get_overlapping_areas():
		if not _grab_blocked(area, area.global_position):
			_grab(area.global_position, INF, area)
			return true

	if velocity.y > 0.0:
		return false
	var found := _platform_above(delta)
	if found.is_empty() or _grab_blocked(null, found["anchor"]):
		return false
	_grab(found["anchor"], found["surface"], null)
	return true


## The underside of a one-way platform within reach above the head, as
## {anchor, surface}, or {} for nothing grabbable. The ray is stretched by this
## frame's rise so a fast jump can't skip straight past a platform.
func _platform_above(delta: float) -> Dictionary:
	var head := global_position + Vector2(0.0, -STAND_SIZE.y)
	var reach := grab_reach + absf(velocity.y) * delta
	var query := PhysicsRayQueryParameters2D.create(head, head + Vector2(0.0, -reach))
	query.collision_mask = 1        # world
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}

	var anchor := Vector2(global_position.x, hit["position"].y)
	var collider = hit["collider"]
	if collider is TileMapLayer:
		# Only tiles whose collision is one-way: solid ceilings aren't grabbable.
		var tiles := collider as TileMapLayer
		var cell := tiles.local_to_map(tiles.to_local(hit["position"] + Vector2(0.0, -1.0)))
		var data := tiles.get_cell_tile_data(cell)
		if data == null or not data.is_collision_polygon_one_way(0, 0):
			return {}
		var centre := tiles.to_global(tiles.map_to_local(cell))
		return {"anchor": anchor, "surface": centre.y - float(tiles.tile_set.tile_size.y) * 0.5}

	# The ledges ladders.gd builds on top of each ladder.
	if collider is Node and (collider as Node).is_in_group(&"grabbable"):
		return {"anchor": anchor, "surface": (collider as Node).get_meta(&"surface_y", anchor.y)}
	return {}


## Refuses the hook or platform you just let go of, for same_grab_delay.
func _grab_blocked(hook: Area2D, anchor: Vector2) -> bool:
	if _last_grab <= 0.0:
		return false
	if hook != null:
		return hook == _last_grab_hook
	return _last_grab_hook == null \
		and absf(anchor.y - _last_grab_anchor.y) < 4.0 \
		and absf(anchor.x - _last_grab_anchor.x) < 12.0


func _grab(anchor: Vector2, surface: float, hook: Area2D) -> void:
	$SFX/SndGrab.play()
	hanging = true
	sliding = false
	crouching = false
	climbing = false
	_hang_anchor = anchor
	_hang_surface = surface
	_hang_hook = hook
	velocity = Vector2.ZERO
	_set_shape(false)
	_snap_to_hang()


func _snap_to_hang() -> void:
	if _hang_hook and is_instance_valid(_hang_hook):
		# Hooks hold you centred under them; platforms let you hang where you hit.
		_hang_anchor = _hang_hook.global_position
		global_position.x = _hang_anchor.x
	global_position.y = _hang_anchor.y + hang_drop


func _hang() -> void:
	if _hang_hook and not is_instance_valid(_hang_hook):
		_release(false)
		return

	velocity = Vector2.ZERO
	var input_x := _input_x()
	if input_x != 0.0 and aim_mode == AimMode.STRAIGHT:
		facing = int(input_x)

	# Jump lets go and jumps; down just drops. Both start the regrab delay, so
	# you get clear of what you were holding.
	if Input.is_action_just_pressed(&"jump"):
		_release(true)
		return
	if Input.is_action_just_pressed(&"move_down"):
		_release(false)
		return
	# Up pulls you onto a platform you're hanging under -- the easy way up.
	if Input.is_action_pressed(&"move_up") and _hang_surface < INF:
		_climb_onto()
		return

	_snap_to_hang()


func _release(with_jump: bool) -> void:
	hanging = false
	_regrab = regrab_delay
	_last_grab = same_grab_delay
	_last_grab_anchor = _hang_anchor
	_last_grab_hook = _hang_hook
	_hang_hook = null
	_hang_surface = INF
	_jump_buffer = 0.0
	_jump_cut_used = false
	velocity.x = _input_x() * run_speed
	velocity.y = jump_velocity * hang_jump_scale if with_jump else 0.0


## Pulls up onto the platform being hung from, and stands on it.
func _climb_onto() -> void:
	var surface := _hang_surface
	hanging = false
	_regrab = regrab_delay
	_last_grab = same_grab_delay
	_last_grab_anchor = _hang_anchor
	_last_grab_hook = null
	_hang_hook = null
	_hang_surface = INF
	# Feet land on the top edge; the platform is one-way, so it holds from here.
	global_position.y = surface
	velocity = Vector2.ZERO


# ---------------------------------------------------------------------------
# shooting
# ---------------------------------------------------------------------------
## The weapon currently equipped, or null if the array is empty.
func current_weapon() -> Weapon:
	if weapons.is_empty():
		return null
	return weapons[clampi(weapon_index, 0, weapons.size() - 1)]


func next_weapon() -> void:
	if weapons.size() <= 1:
		return
	weapon_index = wrapi(weapon_index + 1, 0, weapons.size())
	_charging = false
	_charge = 0.0


func _handle_firing(delta: float) -> void:
	if Input.is_action_just_pressed(&"weapon_next"):
		next_weapon()

	var weapon := current_weapon()
	if weapon == null:
		return

	# Mega Man 4+ rule: pressing fire shoots immediately AND starts charging.
	# Releasing after passing a threshold fires that tier instead.
	if Input.is_action_just_pressed(&"fire"):
		$SFX/SndCharge.stop()
		_fire(weapon)
		if weapon.can_charge():
			_charging = true
			_charge = 0.0
	elif _charging and Input.is_action_pressed(&"fire"):
		_charge += delta
		if $SFX/SndCharge.playing == false and _charge > 0.5:
			$SFX/SndCharge.play()
	elif _charging:
		$SFX/SndCharge.stop()
		_charging = false
		var tier := weapon.tier_for(_charge)
		if tier != weapon:
			_fire(tier)
		_charge = 0.0


func _fire(weapon: Weapon) -> void:
	if _fire_cooldown > 0.0 or weapon.projectile == null:
		return

	# Drop shots that already hit something, then apply the on-screen limit.
	# Each charge tier has its own limit, so the buster shot that pressing fire
	# always lets off doesn't use up the charged shot's single slot.
	var alive: Array[Node] = []
	var same_tier := 0
	for s in _shots:
		if is_instance_valid(s):
			alive.append(s)
			if s.get_meta(&"weapon", null) == weapon:
				same_tier += 1
	_shots = alive
	if same_tier >= weapon.max_active:
		return

	# Fired along the aim. launch_angle tilts it upward on whichever side you're
	# aiming, so the bomb still lobs.
	var side := signf(aim_dir.x) if absf(aim_dir.x) > 0.05 else float(facing)
	var base := aim_dir.rotated(deg_to_rad(-weapon.launch_angle * side))
	var spread := deg_to_rad(weapon.spread_degrees)
	var count := maxi(weapon.shot_count, 1)

	for i in count:
		var offset := 0.0 if count == 1 else (float(i) / float(count - 1)) - 0.5
		var shot := weapon.projectile.instantiate()
		shot.damage = weapon.damage
		shot.speed = weapon.speed
		shot.set_meta(&"weapon", weapon)
		get_parent().add_child(shot)
		shot.launch(muzzle.global_position, base.rotated(offset * spread), self)
		_shots.append(shot)

	_fire_cooldown = weapon.cooldown


# ---------------------------------------------------------------------------
# aiming
# ---------------------------------------------------------------------------
## Works out `aim_dir`, turns the hero to face it, and places the muzzle and
## reticle. Straight mode is classic Mega Man; mouse and stick aim freely.
func _update_aim() -> void:
	var shoulder := global_position + _shoulder()

	var stick := Vector2.ZERO
	if stick_aim:
		stick = Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick != Vector2.ZERO:
		if aim_mode != AimMode.STICK:
			_set_aim_mode(AimMode.STICK)
		aim_dir = stick.normalized()
		reticle.global_position = (shoulder + aim_dir * stick_reticle_distance).round()
	elif aim_mode == AimMode.STICK:
		# Let go of the stick: back to shooting straight ahead.
		_set_aim_mode(AimMode.STRAIGHT)

	if aim_mode == AimMode.MOUSE:
		var to_mouse := get_global_mouse_position() - shoulder
		if to_mouse.length() > 4.0:
			aim_dir = to_mouse.normalized()
	elif aim_mode == AimMode.STRAIGHT:
		aim_dir = Vector2(facing, 0.0)

	# Free aim turns the hero to face it -- you can back away while shooting
	# forward. Aiming straight up or down leaves you facing as you were.
	if aim_mode != AimMode.STRAIGHT and absf(aim_dir.x) > 0.05:
		facing = 1 if aim_dir.x > 0.0 else -1

	muzzle.position = _shoulder() + aim_dir * _muzzle_offset.x


func _set_aim_mode(mode: AimMode) -> void:
	aim_mode = mode
	_mouse_travel = 0.0
	# The reticle stands in for the OS cursor while the mouse is aiming.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if mode == AimMode.MOUSE else Input.MOUSE_MODE_VISIBLE
	reticle.set(&"follow_mouse", mode == AimMode.MOUSE)
	reticle.visible = mode != AimMode.STRAIGHT


## Where shots come from, before being pushed out along the aim.
func _shoulder() -> Vector2:
	return Vector2(0.0, LOW_SHOULDER_Y if (sliding or crouching) else _muzzle_offset.y)


# ---------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------
## Called by enemy shots, blasts, and _check_contact. Returns false when the hit
## was ignored (i-frames, mid-transition), so enemy shots fly on through you
## instead of vanishing, as in Mega Man.
func take_damage(amount: int, from: Node = null) -> bool:
	if _invuln > 0.0 or _hurt_timer > 0.0 or frozen:
		return false

	$SFX/SndDamage.play()

	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health <= 0:
		respawn()
		return true

	_hurt_timer = hurt_time
	_invuln = invuln_time
	climbing = false
	# Getting hit shakes you off a hook or platform.
	if hanging:
		_release(false)
	# Standing up inside a 2-tile tunnel would wedge the hero into the ceiling,
	# so a hit while low only stands you up where there's room. Otherwise the
	# slide or crouch simply carries on once the stun wears off.
	if (sliding or crouching) and _has_headroom():
		sliding = false
		crouching = false
		_set_shape(false)

	var away := -facing
	if from is Node2D:
		away = int(signf(global_position.x - (from as Node2D).global_position.x))
		if away == 0:
			away = -facing
	velocity = Vector2(away * knockback, -60.0)
	return true


## Knocked back and not steering, until the stun runs out.
func _hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity.y = minf(velocity.y + gravity * delta, max_fall)
	velocity.x = move_toward(velocity.x, 0.0, 240.0 * delta)
	move_and_slide()


## Checked every frame rather than on body_entered: that signal only fires on
## the first touch, so an enemy you were still standing inside when the i-frames
## ran out could never hurt you again.
func _check_contact() -> void:
	if _invuln > 0.0 or _hurt_timer > 0.0:
		return
	for body in hurtbox.get_overlapping_bodies():
		if not body.has_method(&"get_contact_damage"):
			continue
		var amount: int = body.get_contact_damage()
		if amount > 0 and take_damage(amount, body as Node2D):
			return


# ---------------------------------------------------------------------------
# housekeeping
# ---------------------------------------------------------------------------
func _check_landing() -> void:
	var on_floor := is_on_floor()
	if not _floor_state_initialized:
		_floor_state_initialized = true
	else:
		if on_floor and not _was_on_floor:
			$SFX/SndLand.play()
	_was_on_floor = on_floor


## Checkpoints call this. Death, pits and R all bring you back here from now on.
func set_checkpoint(point: Vector2) -> void:
	_spawn_point = point


func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	health = max_health
	health_changed.emit(health, max_health)
	sliding = false
	crouching = false
	climbing = false
	hanging = false
	frozen = false
	_hang_hook = null
	_hang_surface = INF
	_jump_buffer = 0.0
	_slide_buffer = 0.0
	_regrab = 0.0
	_last_grab = 0.0
	_charging = false
	_charge = 0.0
	_hurt_timer = 0.0
	_invuln = 0.0
	sprite.visible = true
	_set_shape(false)
	respawned.emit()


func _tick_timers(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_slide_cooldown = maxf(0.0, _slide_cooldown - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_slide_buffer = maxf(0.0, _slide_buffer - delta)
	_regrab = maxf(0.0, _regrab - delta)
	_last_grab = maxf(0.0, _last_grab - delta)
	# Climbing and hanging don't call move_and_slide, so is_on_floor() stays stuck
	# on whatever it was beforehand -- don't trust it in either state. Left as is,
	# a hang begun from the ground would keep refreshing coyote time and hand you
	# a free mid-air jump the moment you dropped off.
	var grounded := is_on_floor() and not climbing and not hanging
	if grounded:
		_coyote = coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if Input.is_action_just_pressed(&"jump"):
		var down := Input.is_action_pressed(&"move_down")
		if down and (grounded or sliding or crouching):
			# Down + jump on the ground is a slide and only a slide -- it never
			# queues a jump, which is what used to make chained slides hop.
			_slide_buffer = slide_buffer
		else:
			_jump_buffer = jump_buffer
			# Down + jump in the air: a coyote jump if one's still allowed,
			# otherwise a slide the moment you land.
			if down:
				_slide_buffer = slide_buffer
	if Input.is_action_just_pressed(&"slide"):
		_slide_buffer = slide_buffer

	if _invuln > 0.0:
		_invuln -= delta
		# flicker while you can't be hit
		sprite.visible = fmod(_invuln, 0.12) < 0.06
		if _invuln <= 0.0:
			sprite.visible = true


## True when there's room to stand up where we are.
func _has_headroom() -> bool:
	# The box stops 1px above the feet. Reaching all the way down, it touched the
	# floor you were standing on whenever you sat exactly on it, and read that as
	# a ceiling -- leaving you stuck crouched or sliding with nothing overhead.
	var box := RectangleShape2D.new()
	box.size = STAND_SIZE - Vector2(1.0, 1.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, -(STAND_SIZE.y + 1.0) * 0.5))
	query.collision_mask = 1        # world
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Deferred because the physics server refuses shape changes while it is
## resolving collisions, which is where some of these calls come from.
func _set_shape(is_sliding: bool) -> void:
	stand_shape.set_deferred(&"disabled", is_sliding)
	slide_shape.set_deferred(&"disabled", not is_sliding)


func _update_sprite() -> void:
	# Crouching shares the slide's low frame for now -- there's no crouch art yet.
	sprite.frame = 1 if (sliding or crouching) else 0
	sprite.flip_h = (_slide_dir if sliding else facing) < 0

	# Charging flashes the hero brighter as each tier is reached.
	var tint := Color.WHITE
	var weapon := current_weapon()
	if _charging and weapon:
		var tier := weapon.tier_for(_charge)
		if tier != weapon:
			# alternate with white so it visibly pulses
			var flash := int(Time.get_ticks_msec() / 60.0) % 2 == 0
			var top := FULL_CHARGE_TINT if tier.charged == null else MID_CHARGE_TINT
			tint = top if flash else Color.WHITE
	sprite.modulate = tint
