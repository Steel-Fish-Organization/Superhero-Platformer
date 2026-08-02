class_name Boss
extends Enemy
## Base class for the nine stage bosses.
##
## Reproduces the Mega Man fight opening: the boss drops in, everything freezes
## while its health bar fills one unit at a time, then the fight starts. Death is
## the long chain of explosions before the stage clears.
##
## Subclasses override `_fight(delta)` and usually `_choose_attack()`.

signal intro_started(boss: Boss)
signal intro_finished(boss: Boss)
signal defeated(boss: Boss)

enum Phase { DORMANT, ENTERING, FILLING, FIGHT, DYING }

@export_group("Identity")
@export var boss_name: String = "BOSS"
## Health bar colour in the HUD.
@export var bar_color: Color = Color(0.85, 0.4, 1.0)

@export_group("Intro")
## Drops in from this many pixels above its placed position.
@export var entry_drop: float = 140.0
@export var entry_speed: float = 320.0
## Seconds per health unit while the bar fills. MM uses roughly 1/20s.
@export var fill_step: float = 0.05
@export var intro_sfx: StringName = &"boss_appear"

@export_group("Fight")
## Health fraction below which the boss speeds up / changes pattern.
@export_range(0.0, 1.0) var enrage_threshold: float = 0.35
## Seconds of stagger after being hit. 0 = never flinches.
@export var flinch_time: float = 0.0

@export_group("Death")
@export var death_burst: PackedScene = preload("res://src/fx/death_burst.tscn")
@export var death_duration: float = 2.0

var phase: Phase = Phase.DORMANT
var displayed_health: int = 0
var enraged: bool = false

var _entry_y: float = 0.0
var _fill_timer: float = 0.0
var _flinch: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(&"boss")
	max_health = maxi(max_health, 1)
	health = max_health
	displayed_health = 0
	invulnerable = true
	visible = false
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	match phase:
		Phase.DORMANT:
			return
		Phase.ENTERING:
			_process_entering(delta)
			return
		Phase.FILLING:
			_process_filling(delta)
			return
		Phase.DYING:
			return
		_:
			pass

	if _flinch > 0.0:
		_flinch -= delta
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		if use_gravity:
			velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		return

	super._physics_process(delta)


func _behaviour(delta: float) -> void:
	_fight(delta)


## Override this: the actual fight.
func _fight(_delta: float) -> void:
	pass


# ---------------------------------------------------------------------------
# intro
# ---------------------------------------------------------------------------
## Called by the BossArena when the player walks in.
func begin_intro() -> void:
	if phase != Phase.DORMANT:
		return
	_entry_y = global_position.y
	global_position.y -= entry_drop
	visible = true
	phase = Phase.ENTERING
	AudioManager.play_sfx(intro_sfx)
	intro_started.emit(self)


func _process_entering(_delta: float) -> void:
	velocity = Vector2(0.0, entry_speed)
	move_and_slide()
	if global_position.y >= _entry_y or is_on_floor():
		global_position.y = _entry_y
		velocity = Vector2.ZERO
		phase = Phase.FILLING
		_fill_timer = 0.0
		_on_landed()


func _process_filling(delta: float) -> void:
	velocity = Vector2.ZERO
	_fill_timer -= delta
	if _fill_timer > 0.0:
		return
	_fill_timer = fill_step
	displayed_health += 1
	health_changed.emit(displayed_health, max_health)
	AudioManager.play_sfx(&"bar_fill")
	if displayed_health >= max_health:
		_start_fight()


func _on_landed() -> void:
	pass


func _start_fight() -> void:
	phase = Phase.FIGHT
	invulnerable = false
	displayed_health = health
	intro_finished.emit(self)
	_on_fight_started()


func _on_fight_started() -> void:
	pass


# ---------------------------------------------------------------------------
# damage & death
# ---------------------------------------------------------------------------
func _on_damaged(_amount: int, _source: Node) -> void:
	displayed_health = health
	if flinch_time > 0.0:
		_flinch = flinch_time
	if not enraged and float(health) / float(max_health) <= enrage_threshold:
		enraged = true
		_on_enraged()


func _on_enraged() -> void:
	pass


func die() -> void:
	if phase == Phase.DYING:
		return
	phase = Phase.DYING
	invulnerable = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	displayed_health = 0
	health_changed.emit(0, max_health)
	_death_sequence()


func _death_sequence() -> void:
	AudioManager.stop_music(0.3)
	# A scatter of explosions across the body, then the big ring burst.
	var elapsed := 0.0
	while elapsed < death_duration:
		var fx := (death_effect if death_effect else null)
		if fx:
			var e := fx.instantiate()
			if e is Node2D:
				(e as Node2D).global_position = global_position + Vector2(
					randf_range(-20.0, 20.0), randf_range(-24.0, 16.0))
			get_parent().add_child(e)
		await get_tree().create_timer(0.14).timeout
		elapsed += 0.14

	if death_burst:
		var burst := death_burst.instantiate()
		if burst is Node2D:
			(burst as Node2D).global_position = global_position
		get_parent().add_child(burst)
	SceneRouter.flash(Color(1, 1, 1, 0.8), 0.25)

	visible = false
	died.emit(self)
	defeated.emit(self)
	await get_tree().create_timer(0.6).timeout
	queue_free()


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
## Convenience for pattern code: true roughly `chance` of the time.
func roll(chance: float) -> bool:
	return randf() < chance


func jump_toward_player(vx: float, vy: float) -> void:
	face_player()
	velocity = Vector2(absf(vx) * facing, -absf(vy))
