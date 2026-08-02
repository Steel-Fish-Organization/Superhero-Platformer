extends Area2D
## The player's shot. Flies sideways until it hits an enemy or a wall.
##
## This is deliberately the dumbest possible version -- it's the piece you'll
## most likely want to replace. Swap the sprite, change SPEED, or give it
## gravity/homing/bouncing right here; nothing else in the project depends on
## how it behaves.

const SPEED := 300.0
const DAMAGE := 1
const LIFETIME := 2.0

## +1 fires right, -1 fires left. Set by the player before adding to the scene.
var direction := 1

var _age := 0.0


func _ready() -> void:
	# layer 4 (shot), collides with layer 1 (world) and layer 3 (enemy)
	collision_layer = 8
	collision_mask = 1 | 4
	body_entered.connect(_on_hit)
	$Sprite.flip_h = direction < 0


func _physics_process(delta: float) -> void:
	position.x += SPEED * direction * delta
	$Sprite.frame = int(_age * 14.0) % 2

	_age += delta
	if _age >= LIFETIME:
		queue_free()


func _on_hit(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE, self)
	queue_free()
