extends Sprite2D
## One-shot frame animation that frees itself. Used for enemy explosions.

@export var fps := 18.0
@export var loops := 1
@export var randomize_rotation := false

var _time := 0.0
var _total := 1


func _ready() -> void:
	_total = maxi(hframes * vframes, 1)
	if randomize_rotation:
		rotation = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	var index := int(_time * fps)
	if index >= _total * loops:
		queue_free()
		return
	frame = index % _total
