class_name EffectSprite
extends Sprite2D
## One-shot frame animation that frees itself. Used for explosions and impacts.

@export var fps: float = 18.0
@export var loops: int = 1
@export var randomize_rotation: bool = false
@export var sfx: StringName = &""

var _time: float = 0.0
var _total: int = 1


func _ready() -> void:
	_total = maxi(hframes * vframes, 1)
	if randomize_rotation:
		rotation = randf() * TAU
	if sfx != &"":
		AudioManager.play_sfx(sfx)


func _process(delta: float) -> void:
	_time += delta
	var index := int(_time * fps)
	if index >= _total * loops:
		queue_free()
		return
	frame = index % _total
