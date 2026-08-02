extends CanvasLayer
## In-game HUD: health, weapon energy, boss health, lives and tanks.
##
## Everything is drawn with draw_rect at 1px precision rather than built from
## Control nodes, so the bars land exactly on pixel boundaries at 426x240.

const BAR_WIDTH := 6
const UNIT_HEIGHT := 2
const UNIT_GAP := 0
const BORDER := Color(0.06, 0.06, 0.12)
const EMPTY := Color(0.16, 0.16, 0.26)

const HEALTH_POS := Vector2(10, 14)
const WEAPON_POS := Vector2(22, 14)
const BOSS_POS := Vector2(410, 14)
const INFO_POS := Vector2(10, 90)

@onready var _canvas: Control = $Draw

var _boss: Boss
var _boss_health: int = 0
var _boss_max: int = 1
var _boss_visible: bool = false


func _ready() -> void:
	layer = 10
	GameState.health_changed.connect(_on_changed)
	GameState.weapon_energy_changed.connect(_on_energy_changed)
	GameState.weapon_changed.connect(_on_weapon_changed)
	GameState.lives_changed.connect(_on_changed)
	GameState.tanks_changed.connect(_on_tanks_changed)
	call_deferred(&"_hook_boss")


func _hook_boss() -> void:
	var found := get_tree().get_first_node_in_group(&"boss")
	if found is Boss:
		_boss = found as Boss
		_boss_max = maxi(_boss.max_health, 1)
		_boss.intro_started.connect(func(_b: Boss) -> void:
			_boss_visible = true
			_canvas.queue_redraw())
		_boss.health_changed.connect(func(current: int, maximum: int) -> void:
			_boss_health = current
			_boss_max = maxi(maximum, 1)
			_canvas.queue_redraw())
		_boss.defeated.connect(func(_b: Boss) -> void:
			_boss_visible = false
			_canvas.queue_redraw())


func _on_changed(_a: Variant = null, _b: Variant = null) -> void:
	_canvas.queue_redraw()


func _on_energy_changed(_id: StringName, _current: float, _maximum: float) -> void:
	_canvas.queue_redraw()


func _on_weapon_changed(_w: WeaponData) -> void:
	_canvas.queue_redraw()


func _on_tanks_changed(_e: int, _w: int) -> void:
	_canvas.queue_redraw()


# ---------------------------------------------------------------------------
# drawing (called from the Draw control's _draw via its script-less signal)
# ---------------------------------------------------------------------------
func draw_hud(c: Control) -> void:
	_draw_bar(c, HEALTH_POS, GameState.health, GameState.MAX_HEALTH, Color(0.85, 0.95, 1.0), Color(0.3, 0.75, 1.0))

	var weapon := GameState.current_weapon()
	if weapon and weapon.is_metered():
		_draw_bar(c, WEAPON_POS, int(GameState.weapon_energy_of(weapon.id)), int(weapon.max_energy),
			weapon.hud_color.lightened(0.4), weapon.hud_color)

	if _boss_visible and _boss and is_instance_valid(_boss):
		_draw_bar(c, BOSS_POS, _boss_health, _boss_max,
			_boss.bar_color.lightened(0.4), _boss.bar_color)

	_draw_info(c)


func _draw_bar(c: Control, pos: Vector2, value: int, maximum: int, light: Color, dark: Color) -> void:
	maximum = maxi(maximum, 1)
	var height := maximum * (UNIT_HEIGHT + UNIT_GAP) + 2
	# frame
	c.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(BAR_WIDTH + 2, height)), BORDER, true)
	for i in maximum:
		# units fill from the bottom up
		var y := pos.y + float((maximum - 1 - i) * (UNIT_HEIGHT + UNIT_GAP))
		var filled := i < value
		var col := EMPTY
		if filled:
			col = light if i % 2 == 0 else dark
		c.draw_rect(Rect2(Vector2(pos.x, y), Vector2(BAR_WIDTH, UNIT_HEIGHT)), col, true)


func _draw_info(c: Control) -> void:
	var font := ThemeDB.fallback_font
	var y := INFO_POS.y
	c.draw_string(font, Vector2(INFO_POS.x, y), "x%d" % maxi(GameState.lives, 0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	if GameState.e_tanks > 0:
		y += 10.0
		c.draw_string(font, Vector2(INFO_POS.x, y), "E:%d" % GameState.e_tanks,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.9, 1.0))
	if GameState.w_tanks > 0:
		y += 10.0
		c.draw_string(font, Vector2(INFO_POS.x, y), "W:%d" % GameState.w_tanks,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.85, 0.3))
