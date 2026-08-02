class_name Pickup
extends Area2D
## Health / weapon-energy / life / tank item. Frames come from pickups.png in
## this order: health_s, health_l, energy_s, energy_l, life, e_tank, w_tank.

enum Kind { HEALTH, WEAPON_ENERGY, LIFE, E_TANK, W_TANK }

@export var kind: Kind = Kind.HEALTH
@export var amount: int = 2
## 0 = never expires. Enemy drops usually expire; placed items do not.
@export var lifetime: float = 0.0
@export var bob: bool = true
@export var pickup_sfx: StringName = &"pickup"

var _age: float = 0.0
var _base_y: float = 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)
	_base_y = position.y


func _process(delta: float) -> void:
	_age += delta
	if bob:
		position.y = _base_y + sin(_age * 4.0) * 1.0
	if lifetime > 0.0:
		if _age > lifetime:
			queue_free()
		elif _age > lifetime - 2.0:
			sprite.visible = int(_age * 12.0) % 2 == 0


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	if not _apply(body as Player):
		return
	AudioManager.play_sfx(pickup_sfx)
	queue_free()


## Returns false when the item cannot be used yet (full health, tanks maxed),
## so it stays on the ground for later -- same as Mega Man.
func _apply(p: Player) -> bool:
	match kind:
		Kind.HEALTH:
			if GameState.health >= GameState.MAX_HEALTH:
				return false
			p.heal(amount)
		Kind.WEAPON_ENERGY:
			var w := GameState.current_weapon()
			if w == null or not w.is_metered():
				return false
			if GameState.weapon_energy_of(w.id) >= w.max_energy:
				return false
			GameState.add_energy(w.id, float(amount))
		Kind.LIFE:
			GameState.add_life()
		Kind.E_TANK:
			return GameState.add_tank(&"e_tank")
		Kind.W_TANK:
			return GameState.add_tank(&"w_tank")
	return true
