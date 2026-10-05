@tool
class_name Civilian
extends Area2D
## Someone to rescue. Stand next to them and press interact (E / gamepad Y) and
## they're freed; they run off the side of the screen to safety.
##
## Set `danger_time` above 0 and a countdown starts the moment they come on
## screen: reach them before it runs out or they're lost for this attempt. That
## timer is the whole point of the rescue system -- it's what makes stopping to
## help cost you something, rather than being a free collectible.
##
## A civilian with a `display_name` is a named survivor: the one person in a
## stage worth remembering, and the one who carries the stage's `letter`.

signal rescued(civilian: Civilian)
signal lost(civilian: Civilian)

enum State { TRAPPED, FLEEING, SAFE, LOST }
## What killed them, for the stage summary and for tuning a level that turns out
## to be a meat grinder.
enum Cause { NONE, CLOCK, CAUGHT_IN_FIRE }

const TRIGGER_LAYER := 64     # physics layer 7, "trigger"
const PLAYER_LAYER := 2

@export_group("Who")
## Named survivors are the ones who hand over an upgrade. Blank = one of the crowd.
@export var display_name := "":
	set(value):
		display_name = value
		queue_redraw()
## The stage letter this person carries, if any. One per stage spells the word.
@export var letter := ""
## What they give you for saving them. Usually only named survivors have one.
@export var upgrade: Upgrade

@export_group("Danger")
## Hits from enemy fire, enemy explosions or hazards before they're killed. The
## hero cannot hurt them at all: their hitbox isn't in any player attack's mask.
@export var max_health := 6
## Seconds from first being seen until they're lost. 0 = in no immediate danger.
@export var danger_time := 0.0:
	set(value):
		danger_time = maxf(value, 0.0)
		queue_redraw()
## Flashes red for the last of the countdown, so the panic is readable.
@export var panic_time := 3.0

@export_group("Escape")
@export var flee_speed := 80.0
@export var flee_seconds := 1.4

var state := State.TRAPPED
var cause := Cause.NONE
var time_left := 0.0
var health := 0

var _flash := 0.0
var _player_near := false
var _seen := false
var _flee_timer := 0.0
var _flee_dir := 1
var _bob := 0.0

@onready var _snd_rescue: AudioStreamPlayer2D = get_node_or_null(^"SndRescue")
@onready var _snd_danger: AudioStreamPlayer2D = get_node_or_null(^"SndDanger")


func _ready() -> void:
	add_to_group(&"civilians")
	collision_layer = TRIGGER_LAYER
	collision_mask = PLAYER_LAYER
	monitorable = false
	time_left = danger_time
	health = max_health
	if Engine.is_editor_hint():
		return
	body_entered.connect(func(body: Node) -> void:
		if body.is_in_group(&"player"):
			_player_near = true)
	body_exited.connect(func(body: Node) -> void:
		if body.is_in_group(&"player"):
			_player_near = false)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	_bob += delta
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	match state:
		State.TRAPPED:
			_tick_danger(delta)
			if _player_near and Input.is_action_just_pressed(&"interact"):
				_rescue()
			queue_redraw()
		State.FLEEING:
			position.x += flee_speed * _flee_dir * delta
			_flee_timer -= delta
			modulate.a = clampf(_flee_timer / 0.5, 0.0, 1.0)
			if _flee_timer <= 0.0:
				state = State.SAFE
				hide()
			queue_redraw()
		State.LOST:
			queue_redraw()


## The countdown only starts once they're on screen: being punished for a room
## you have never seen isn't a choice, it's a trap.
func _tick_danger(delta: float) -> void:
	if danger_time <= 0.0:
		return
	if not _seen:
		if not _on_screen():
			return
		_seen = true
		if _snd_danger:
			_snd_danger.play()
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_die(Cause.CLOCK)


## Called by enemy shots and explosions through the Hitbox child. Returns false
## when the hit did nothing, so a shot passes through someone already gone.
func take_damage(amount: int, _from: Node = null) -> bool:
	if state != State.TRAPPED or amount <= 0:
		return false
	health -= amount
	_flash = 0.2
	if _snd_danger and not _snd_danger.playing:
		_snd_danger.play()
	if health <= 0:
		_die(Cause.CAUGHT_IN_FIRE)
	queue_redraw()
	return true


func _die(by: Cause) -> void:
	if state != State.TRAPPED:
		return
	state = State.LOST
	cause = by
	health = 0
	if _snd_danger:
		_snd_danger.stop()
	lost.emit(self)
	queue_redraw()


func _on_screen() -> bool:
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	return view.has_point(global_position)


func _rescue() -> void:
	state = State.FLEEING
	_flee_timer = flee_seconds
	# Run away from the hero, so they don't jog through them on the way out.
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	_flee_dir = 1 if player == null or player.global_position.x < global_position.x else -1
	if _snd_danger:
		_snd_danger.stop()
	if _snd_rescue:
		_snd_rescue.play()
	rescued.emit(self)


## True once they're safe or gone -- the tracker counts these as saved.
func is_saved() -> bool:
	return state == State.FLEEING or state == State.SAFE


# ---------------------------------------------------------------------------
# drawing -- placeholder art, like the rest of the greybox
# ---------------------------------------------------------------------------
func _draw() -> void:
	var body_colour := Color(0.95, 0.75, 0.3)      # trapped: amber
	match state:
		State.FLEEING, State.SAFE:
			body_colour = Color(0.45, 0.95, 0.55)  # saved: green
		State.LOST:
			body_colour = Color(0.35, 0.35, 0.42)  # lost: grey
	# panic flash as the countdown runs out
	if state == State.TRAPPED and _seen and time_left <= panic_time and danger_time > 0.0:
		if int(_bob * 8.0) % 2 == 0:
			body_colour = Color(1.0, 0.35, 0.35)
	# white flash when caught by enemy fire
	if _flash > 0.0 and int(_flash * 30.0) % 2 == 0:
		body_colour = Color(3.0, 3.0, 3.0)

	var lean := 0.0 if state != State.LOST else 3.0   # the lost slump over
	draw_rect(Rect2(-3.0 + lean, -10.0, 6.0, 7.0), body_colour, true)        # body
	draw_circle(Vector2(lean, -13.0), 3.0, body_colour)                      # head
	if display_name != "":
		# named survivors get a collar so they stand out across a room
		draw_rect(Rect2(-4.0 + lean, -11.0, 8.0, 1.5), Color(0.4, 0.85, 1.0), true)

	if state == State.TRAPPED or Engine.is_editor_hint():
		_draw_danger_bar()
		if _player_near:
			_draw_prompt()


func _draw_danger_bar() -> void:
	if danger_time <= 0.0:
		return
	var frac := clampf(time_left / danger_time, 0.0, 1.0)
	var origin := Vector2(-8.0, -22.0)
	draw_rect(Rect2(origin, Vector2(16.0, 2.0)), Color(0.1, 0.1, 0.15), true)
	draw_rect(Rect2(origin, Vector2(16.0 * frac, 2.0)), Color(1.0, 0.5, 0.3), true)


## A chevron bobbing overhead: "you can do something here".
func _draw_prompt() -> void:
	var y := -26.0 + sin(_bob * 6.0) * 1.5
	var tip := Vector2(0.0, y + 3.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-3.0, -4.0), tip + Vector2(3.0, -4.0)]),
		Color(1.0, 1.0, 1.0, 0.9))
