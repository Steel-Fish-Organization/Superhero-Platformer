extends CanvasLayer
## Mega Man style health bar, top-left, fed by the Player's health_changed
## signal, plus the rescue readout on the right. Drawn with draw_rect rather
## than Control nodes so every unit lands on a whole pixel at 432x240.

const BAR_POS := Vector2(10, 14)
const BAR_WIDTH := 6
const UNIT_HEIGHT := 2
const BORDER := Color(0.06, 0.06, 0.12)
const EMPTY := Color(0.16, 0.16, 0.26)
const LIGHT := Color(0.85, 0.95, 1.0)
const DARK := Color(0.3, 0.75, 1.0)

const RESCUE_POS := Vector2(340, 20)
const SAVED_COLOUR := Color(0.45, 0.95, 0.55)
const LOST_COLOUR := Color(0.9, 0.4, 0.4)
const ALERT_COLOUR := Color(1.0, 0.55, 0.3)
## How long a "letter found" banner stays up.
const LETTER_BANNER_TIME := 3.0

var _health := 0
var _max_health := 1
var _saved := 0
var _total := 0
var _lost := 0
var _alert := 0
var _max_alert := 3
var _letters: Array[String] = []
var _upgrades: Array[String] = []
var _banner := ""
var _banner_timer := 0.0

@onready var _canvas: Control = $Draw


func _ready() -> void:
	_canvas.draw.connect(_draw_hud)
	# Deferred so the player, tracker and alert have all run _ready, whatever
	# the scene order.
	_hook_player.call_deferred()
	_hook_rescue.call_deferred()
	_hook_state.call_deferred()


func _process(delta: float) -> void:
	if _banner_timer <= 0.0:
		return
	_banner_timer -= delta
	if _banner_timer <= 0.0:
		_banner = ""
	_canvas.queue_redraw()


func _hook_state() -> void:
	var state := get_node_or_null(^"/root/GameState")
	if state == null:
		return
	state.upgrade_unlocked.connect(_on_upgrade_unlocked)
	state.progress_reset.connect(_on_progress_reset)
	_refresh_upgrades(state)


func _on_upgrade_unlocked(upgrade: Upgrade) -> void:
	_banner = "%s EARNED" % upgrade.display_name.to_upper()
	_banner_timer = LETTER_BANNER_TIME
	_refresh_upgrades(get_node_or_null(^"/root/GameState"))


func _on_progress_reset() -> void:
	_banner = ""
	_refresh_upgrades(get_node_or_null(^"/root/GameState"))


func _refresh_upgrades(state: Node) -> void:
	_upgrades.clear()
	if state:
		for upgrade in state.unlocked_upgrades():
			_upgrades.append(upgrade.display_name)
		_letters = state.letters
	_canvas.queue_redraw()


func _hook_rescue() -> void:
	var tracker := get_tree().get_first_node_in_group(&"rescue_tracker")
	if tracker:
		tracker.changed.connect(_on_rescue_changed)
		tracker.letter_found.connect(_on_letter_found)
		_letters = tracker.letters
		_on_rescue_changed(tracker.saved, tracker.total, tracker.lost)
	var alert := get_tree().get_first_node_in_group(&"alert")
	if alert:
		alert.level_changed.connect(_on_alert_changed)
		_max_alert = alert.max_level
		_on_alert_changed(alert.level)


func _on_rescue_changed(saved: int, total: int, lost: int) -> void:
	_saved = saved
	_total = total
	_lost = lost
	_canvas.queue_redraw()


func _on_letter_found(letter: String, who: String) -> void:
	_banner = "%s SAFE  -  %s" % [who.to_upper(), letter] if who != "" else letter
	_banner_timer = LETTER_BANNER_TIME
	_canvas.queue_redraw()


func _on_alert_changed(level: int) -> void:
	_alert = level
	_canvas.queue_redraw()


func _hook_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not player.has_signal(&"health_changed"):
		push_warning("HUD: no player with a health_changed signal found.")
		return
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	_health = current
	_max_health = maxi(maximum, 1)
	_canvas.queue_redraw()


func _draw_hud() -> void:
	# frame
	var height := _max_health * UNIT_HEIGHT + 2
	_canvas.draw_rect(Rect2(BAR_POS - Vector2(1, 1), Vector2(BAR_WIDTH + 2, height)), BORDER, true)
	# units fill from the bottom up, alternating light and dark
	for i in _max_health:
		var y := BAR_POS.y + float((_max_health - 1 - i) * UNIT_HEIGHT)
		var col := EMPTY
		if i < _health:
			col = LIGHT if i % 2 == 0 else DARK
		_canvas.draw_rect(Rect2(Vector2(BAR_POS.x, y), Vector2(BAR_WIDTH, UNIT_HEIGHT)), col, true)

	_draw_rescue()
	_draw_upgrades()


## Rescue count, the letters found so far, and how far the villain's plan has
## got. Deliberately plain text for now -- a prototype readout, not final UI.
func _draw_rescue() -> void:
	if _total <= 0:
		return
	var font := ThemeDB.fallback_font
	var pos := RESCUE_POS
	_canvas.draw_string(font, pos, "SAVED %d/%d" % [_saved, _total],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SAVED_COLOUR)
	if _lost > 0:
		pos.y += 10.0
		_canvas.draw_string(font, pos, "LOST %d" % _lost, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LOST_COLOUR)
	if not _letters.is_empty():
		pos.y += 10.0
		_canvas.draw_string(font, pos, " ".join(_letters), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LIGHT)

	# alert pips: the villain's head start
	pos.y += 10.0
	for i in _max_alert:
		var filled := i < _alert
		_canvas.draw_rect(Rect2(pos + Vector2(float(i) * 7.0, -4.0), Vector2(5.0, 4.0)),
			ALERT_COLOUR if filled else EMPTY, true)

	if _banner != "":
		_canvas.draw_string(font, Vector2(RESCUE_POS.x - 220.0, 20.0), _banner,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SAVED_COLOUR)


## What you've earned so far, bottom-left. A prototype readout -- a real one
## would use icons.
func _draw_upgrades() -> void:
	var font := ThemeDB.fallback_font
	for i in _upgrades.size():
		_canvas.draw_string(font, Vector2(10.0, 196.0 + float(i) * 9.0), _upgrades[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, LIGHT)
