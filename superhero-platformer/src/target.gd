extends StaticBody2D
## A block to shoot at, so you can feel whether the shooting is working.
##
## Comes back after a moment so you can keep testing without restarting. Delete
## this script and its scene once real enemies exist.

@export var max_health := 3
@export var respawn_after := 2.0

var health := 0
var _flash := 0.0
var _dead_for := -1.0


func _ready() -> void:
	health = max_health
	collision_layer = 4     # layer 3, target
	collision_mask = 0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		$Sprite.modulate = Color(3, 3, 3) if int(_flash * 40.0) % 2 == 0 else Color.WHITE
		if _flash <= 0.0:
			$Sprite.modulate = Color.WHITE

	if _dead_for >= 0.0:
		_dead_for += delta
		if _dead_for >= respawn_after:
			_revive()


func take_damage(amount: int, _from: Node = null) -> void:
	if _dead_for >= 0.0:
		return
	health -= amount
	_flash = 0.14
	if health <= 0:
		_die()


func _die() -> void:
	health = 0
	_dead_for = 0.0
	visible = false
	$Shape.set_deferred(&"disabled", true)


func _revive() -> void:
	health = max_health
	_dead_for = -1.0
	visible = true
	$Sprite.modulate = Color.WHITE
	$Shape.set_deferred(&"disabled", false)
