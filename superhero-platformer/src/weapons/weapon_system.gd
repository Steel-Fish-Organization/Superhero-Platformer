class_name WeaponSystem
extends Node2D
## Firing/charging component. Lives under the player and owns everything about
## shooting: charge timing, the per-weapon concurrent-shot cap, energy spend and
## the charge aura.
##
## Mega Man 4+ charge rules: tapping fire always releases a tap shot immediately
## and starts charging; releasing after passing a threshold fires that stage.

signal fired(stage_index: int, stage: WeaponChargeStage)
signal charge_stage_changed(stage_index: int)
signal out_of_energy(weapon: WeaponData)

## Where shots spawn. Mirrored automatically by the player's facing.
@export var muzzle: Marker2D
@export var aura: Sprite2D
## Turn off while sliding, hurt, in a cutscene, etc.
@export var enabled: bool = true

var facing: int = 1
var charge_time: float = 0.0
var charge_stage: int = 0
var is_charging: bool = false

var _cooldown: float = 0.0
var _active: Array[Projectile] = []
var _charge_sfx_playing: bool = false


func _ready() -> void:
	_resolve_nodes()
	GameState.weapon_changed.connect(_on_weapon_changed)
	if aura:
		aura.visible = false


## Node-typed @exports only resolve when the scene was saved by the editor, so
## fall back to the conventional child names.
func _resolve_nodes() -> void:
	if muzzle == null:
		muzzle = get_node_or_null(^"Muzzle") as Marker2D
	if aura == null:
		aura = get_node_or_null(^"Aura") as Sprite2D
	if muzzle == null:
		push_warning("WeaponSystem has no Muzzle marker; shots will spawn at its own origin.")


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_prune()

	if not enabled:
		_cancel_charge()
		return

	var weapon := GameState.current_weapon()
	if weapon == null:
		return

	if Input.is_action_just_pressed(&"fire"):
		_fire_stage(weapon, 0)
		if weapon.can_charge and weapon.stage_count() > 1:
			is_charging = true
			charge_time = 0.0
			_set_charge_stage(0)

	if is_charging and Input.is_action_pressed(&"fire"):
		charge_time += delta
		var reached := weapon.stage_for_charge(charge_time)
		if reached != charge_stage:
			_set_charge_stage(reached)
			if reached > 0:
				AudioManager.play_sfx(weapon.charge_ready_sfx if reached >= weapon.stage_count() - 1 else weapon.charge_sfx)
		if weapon.auto_fire_at_full and reached >= weapon.stage_count() - 1:
			_release(weapon)
	elif is_charging:
		_release(weapon)

	_update_aura(weapon, delta)


func _release(weapon: WeaponData) -> void:
	var stage_index := charge_stage
	_cancel_charge()
	if stage_index > 0:
		_fire_stage(weapon, stage_index)


func _fire_stage(weapon: WeaponData, stage_index: int) -> bool:
	if _cooldown > 0.0:
		return false
	var stage := weapon.stage_at(stage_index)
	if stage == null or stage.projectile_scene == null:
		return false
	if _count_for(weapon) >= stage.max_active:
		return false

	var cost := weapon.cost_of(stage_index)
	if not GameState.can_spend_energy(weapon, cost):
		out_of_energy.emit(weapon)
		AudioManager.play_sfx(&"denied")
		return false
	GameState.spend_energy(weapon, cost)

	var origin := muzzle.global_position if muzzle else global_position
	var base_dir := Vector2(facing, 0.0)
	var count := maxi(stage.shot_count, 1)
	var spread := deg_to_rad(stage.spread_degrees)
	for i in count:
		var t := 0.0 if count == 1 else (float(i) / float(count - 1)) - 0.5
		var dir := base_dir.rotated(t * spread)
		var offset := base_dir.orthogonal() * (t * stage.lateral_offset)
		_spawn(stage, origin + offset, dir, weapon)

	_cooldown = weapon.fire_cooldown + stage.extra_cooldown
	if stage.screen_shake > 0.0:
		_shake(stage.screen_shake)
	AudioManager.play_sfx(stage.shoot_sfx)
	fired.emit(stage_index, stage)
	return true


func _spawn(stage: WeaponChargeStage, origin: Vector2, dir: Vector2, weapon: WeaponData) -> void:
	var shot := stage.projectile_scene.instantiate()
	# Shots live on the level, not the player, so they keep flying if he dies.
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(shot)
	if shot is Projectile:
		var p := shot as Projectile
		p.set_meta(&"weapon_id", weapon.id)
		p.launch(origin, dir, stage, get_parent() as Node2D)
		_active.append(p)
	elif shot is Node2D:
		(shot as Node2D).global_position = origin


func _count_for(weapon: WeaponData) -> int:
	var n := 0
	for p in _active:
		if is_instance_valid(p) and p.get_meta(&"weapon_id", &"") == weapon.id:
			n += 1
	return n


func _prune() -> void:
	var kept: Array[Projectile] = []
	for p in _active:
		if is_instance_valid(p):
			kept.append(p)
	_active = kept


func _set_charge_stage(value: int) -> void:
	if charge_stage == value:
		return
	charge_stage = value
	charge_stage_changed.emit(charge_stage)


func _cancel_charge() -> void:
	if is_charging:
		is_charging = false
	charge_time = 0.0
	_set_charge_stage(0)
	if aura:
		aura.visible = false


func _update_aura(weapon: WeaponData, delta: float) -> void:
	if aura == null:
		return
	if charge_stage <= 0:
		aura.visible = false
		return
	aura.visible = true
	aura.modulate = weapon.hud_color
	# Two 2-frame tiers in charge_aura.png: frames 0-1 = tier 1, 2-3 = tier 2.
	var tier := 0 if charge_stage == 1 else 1
	var blink := int(Time.get_ticks_msec() / 60.0) % 2
	aura.frame = tier * 2 + blink
	aura.rotation += delta * 4.0


func _shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_shake"):
		cam.call("add_shake", amount)


func _on_weapon_changed(_weapon: WeaponData) -> void:
	_cancel_charge()
	_cooldown = maxf(_cooldown, 0.08)


## Called by the player when it flips, so shots leave the correct side.
func set_facing(dir: int) -> void:
	facing = signi(dir) if dir != 0 else facing
	if muzzle:
		muzzle.position.x = absf(muzzle.position.x) * facing
