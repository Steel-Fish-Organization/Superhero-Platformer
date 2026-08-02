extends Area2D
## The explosion a bomb leaves behind. Damages everything inside it once, plays
## its frames, then removes itself.

@export var damage := 4
@export var frames_per_second := 18.0
## Set by the projectile that spawned it, so an enemy bomb hurts the player.
@export var hostile := false

const WORLD := 1
const PLAYER := 2
const HOSTILE := 4
const PLAYER_SHOT := 8
const ENEMY_SHOT := 32

var _age := 0.0
var _hit: Array[Node] = []


func set_hostile(value: bool) -> void:
	hostile = value


func _ready() -> void:
	collision_layer = ENEMY_SHOT if hostile else PLAYER_SHOT
	collision_mask = PLAYER if hostile else HOSTILE
	# body_entered also fires for anything already standing inside the blast when
	# it appears, so there's no need to sweep overlaps here -- and we couldn't
	# anyway, since the physics server hasn't stepped yet on the frame we spawn.
	body_entered.connect(_damage)


func _process(delta: float) -> void:
	_age += delta
	var sprite := $Sprite as Sprite2D
	var frame := int(_age * frames_per_second)
	if frame >= sprite.hframes:
		queue_free()
		return
	sprite.frame = frame


func _damage(body: Node) -> void:
	if _hit.has(body) or not body.has_method(&"take_damage"):
		return
	_hit.append(body)
	body.take_damage(damage, self)
