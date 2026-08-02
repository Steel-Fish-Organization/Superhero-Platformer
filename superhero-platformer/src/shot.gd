extends Area2D
## The player's shot. Three charge tiers, set by the player when it spawns.
##
## This is the piece most likely to change as you prototype -- give it gravity,
## homing, bouncing, whatever. Nothing else depends on how it behaves.

## Per tier: 0 tap, 1 mid charge, 2 full charge.
const SPEED := [300.0, 330.0, 400.0]
const DAMAGE := [1, 3, 6]
const RADIUS := [3.0, 5.0, 7.0]
## A full-charge shot punches through this many targets before dying.
const PIERCE := [0, 0, 1]
const LIFETIME := 2.0

## Set by the player before the shot is added to the scene.
var direction := 1
var tier := 0

var _hits_left := 0
var _age := 0.0


func _ready() -> void:
	tier = clampi(tier, 0, 2)
	_hits_left = PIERCE[tier]

	# layer 4 (shot); collides with layer 1 (world) and layer 3 (target)
	collision_layer = 8
	collision_mask = 1 | 4
	body_entered.connect(_on_hit)

	$Sprite.frame = tier
	($Shape.shape as CircleShape2D).radius = RADIUS[tier]


func _physics_process(delta: float) -> void:
	position.x += SPEED[tier] * direction * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()


func _on_hit(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE[tier], self)
		if _hits_left > 0:
			_hits_left -= 1
			return
	queue_free()
