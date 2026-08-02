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
##   Q               next weapon
##   R               respawn

## The camera listens for this so it snaps to the spawn room instead of
## scrolling to it as if you had walked there.
signal respawned


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
## The little hop that pops you onto the ledge at the top of a ladder.
@export var ladder_dismount_hop := -110.0
## Jumping off a ladder uses this share of a normal jump.
@export var ladder_jump_scale := 0.85

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

# Standing box is 3 tiles tall so it fits 3-tile corridors; the slide box is
# short enough to fit a 2-tile (16px) gap.
const STAND_SIZE := Vector2(12, 24)
## Backstop only: fall past this and you respawn. The room camera handles normal
## pits, since it knows where the rooms actually are.
@export var fall_limit := 4000.0

var facing := 1
var sliding := false
var climbing := false
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
var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_cut_used := false
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
	health = max_health
	$LadderProbe.area_entered.connect(func(a: Area2D) -> void: _ladder = a)
	$LadderProbe.area_exited.connect(func(a: Area2D) -> void:
		if _ladder == a:
			_ladder = null)
	# Touching an enemy hurts. Their shots find us on their own.
	$Hurtbox.body_entered.connect(_on_touched_hostile)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if Input.is_action_just_pressed(&"restart") or global_position.y > fall_limit:
		respawn()
		return

	if frozen:
		velocity = Vector2.ZERO
		_update_sprite()
		return

	if _hurt_timer > 0.0:
		_hurt(delta)
	elif climbing:
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

	# Variable jump height: letting go mid-rise trims what's left of it. Applied
	# once per jump -- doing it every frame would compound and kill the rise
	# almost instantly, making the jump_cut number meaningless.
	if velocity.y < 0.0 and not _jump_cut_used and not Input.is_action_pressed(&"jump"):
		velocity.y *= jump_cut
		_jump_cut_used = true

	if _try_grab_ladder():
		return

	move_and_slide()


func _jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer = 0.0
	_coyote = 0.0
	_jump_cut_used = false


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
		velocity = Vector2(
			Input.get_axis(&"move_left", &"move_right") * run_speed,
			jump_velocity * ladder_jump_scale)
		_jump_cut_used = false
		# Consume the buffered press, or _walk would fire a second, full-strength
		# jump on the very next frame and override ladder_jump_scale.
		_jump_buffer = 0.0
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
		_fire(weapon)
		if weapon.can_charge():
			_charging = true
			_charge = 0.0
	elif _charging and Input.is_action_pressed(&"fire"):
		_charge += delta
	elif _charging:
		_charging = false
		var tier := weapon.tier_for(_charge)
		if tier != weapon:
			_fire(tier)
		_charge = 0.0


func _fire(weapon: Weapon) -> void:
	if _fire_cooldown > 0.0 or weapon.projectile == null:
		return

	# Drop shots that already hit something, then apply the on-screen limit.
	var alive: Array[Node] = []
	for s in _shots:
		if is_instance_valid(s):
			alive.append(s)
	_shots = alive
	if _shots.size() >= weapon.max_active:
		return

	# launch_angle tilts the shot upward whichever way you're facing.
	var base := Vector2(facing, 0.0).rotated(deg_to_rad(-weapon.launch_angle * facing))
	var spread := deg_to_rad(weapon.spread_degrees)
	var count := maxi(weapon.shot_count, 1)

	for i in count:
		var offset := 0.0 if count == 1 else (float(i) / float(count - 1)) - 0.5
		var shot := weapon.projectile.instantiate()
		shot.damage = weapon.damage
		shot.speed = weapon.speed
		get_parent().add_child(shot)
		shot.launch(muzzle.global_position, base.rotated(offset * spread), self)
		_shots.append(shot)

	_fire_cooldown = weapon.cooldown


# ---------------------------------------------------------------------------
# housekeeping
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------
## Called by enemy shots, blasts, and the hurtbox on contact.
func take_damage(amount: int, from: Node = null) -> void:
	if _invuln > 0.0 or _hurt_timer > 0.0:
		return

	health -= amount
	if health <= 0:
		respawn()
		return

	_hurt_timer = hurt_time
	_invuln = invuln_time
	climbing = false
	if sliding:
		sliding = false
		_set_shape(false)

	var away := -facing
	if from is Node2D:
		away = signi(int(signf(global_position.x - (from as Node2D).global_position.x)))
		if away == 0:
			away = -facing
	velocity = Vector2(away * knockback, -60.0)


## Knocked back and not steering, until the stun runs out.
func _hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity.y = minf(velocity.y + gravity * delta, max_fall)
	velocity.x = move_toward(velocity.x, 0.0, 240.0 * delta)
	move_and_slide()


func _on_touched_hostile(body: Node) -> void:
	if body.has_method(&"get_contact_damage"):
		take_damage(body.get_contact_damage(), body as Node2D)


# ---------------------------------------------------------------------------
# housekeeping
# ---------------------------------------------------------------------------
func respawn() -> void:
	global_position = _spawn_point
	velocity = Vector2.ZERO
	health = max_health
	sliding = false
	climbing = false
	frozen = false
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
	# Climbing doesn't call move_and_slide, so is_on_floor() would stay stuck on
	# whatever it was before the ladder -- don't trust it while climbing.
	if is_on_floor() and not climbing:
		_coyote = coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer = jump_buffer

	if _invuln > 0.0:
		_invuln -= delta
		# flicker while you can't be hit
		sprite.visible = fmod(_invuln, 0.12) < 0.06
		if _invuln <= 0.0:
			sprite.visible = true


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
	var weapon := current_weapon()
	if _charging and weapon:
		var tier := weapon.tier_for(_charge)
		if tier != weapon:
			# alternate with white so it visibly pulses
			var flash := int(Time.get_ticks_msec() / 60.0) % 2 == 0
			var top := FULL_CHARGE_TINT if tier.charged == null else MID_CHARGE_TINT
			tint = top if flash else Color.WHITE
	sprite.modulate = tint
	queue_redraw()


## Health pip above the hero. Prototype readout -- swap it for a real HUD later.
func _draw() -> void:
	if health >= max_health:
		return
	var w := 20.0
	var frac := clampf(float(health) / float(max_health), 0.0, 1.0)
	var origin := Vector2(-w * 0.5, -38.0)
	draw_rect(Rect2(origin, Vector2(w, 3)), Color(0.1, 0.1, 0.15), true)
	draw_rect(Rect2(origin, Vector2(w * frac, 3)), Color(0.4, 0.95, 1.0), true)
