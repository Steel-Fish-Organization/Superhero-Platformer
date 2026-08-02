extends CharacterBody2D
## A walking enemy with health. Patrols back and forth, turns at walls and
## ledges, hurts the player on contact, dies when shot enough times.
##
## Enough to test that shooting feels right. Copy the file for a new enemy type
## and change _move() -- there's no base class or registry to hook into.

@export var max_health := 3
@export var contact_damage := 3
@export var speed := 34.0
## Turn around at the edge of a platform instead of walking off it.
@export var stop_at_ledges := true

const GRAVITY := 900.0
const MAX_FALL := 420.0

var health := 0
var facing := -1

var _flash := 0.0


func _ready() -> void:
	add_to_group(&"enemies")
	health = max_health
	# layer 3 (enemy), only collides with layer 1 (world)
	collision_layer = 4
	collision_mask = 1


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	_move()
	move_and_slide()

	$Sprite.flip_h = facing < 0
	$Sprite.frame = int(Time.get_ticks_msec() / 120.0) % 4

	if _flash > 0.0:
		_flash -= delta
		# blink white while taking a hit
		$Sprite.modulate = Color(3, 3, 3) if int(_flash * 40.0) % 2 == 0 else Color.WHITE
		if _flash <= 0.0:
			$Sprite.modulate = Color.WHITE


func _move() -> void:
	if is_on_floor() and (is_on_wall() or (stop_at_ledges and _at_ledge())):
		facing = -facing
	velocity.x = speed * facing


## Casts a short ray just ahead and down; nothing there means a drop.
func _at_ledge() -> bool:
	var from := global_position + Vector2(8.0 * facing, -2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 12.0))
	query.collision_mask = 1        # world
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func take_damage(amount: int, _from: Node = null) -> void:
	health -= amount
	_flash = 0.14
	if health <= 0:
		queue_free()


## Read by the player's hurtbox on contact.
func get_contact_damage() -> int:
	return contact_damage
