extends Node
## The villain's plan advancing while you take your time.
##
## The alert level climbs the longer you spend in a stage, and enemies get
## twitchier with it. That's the price of stopping to help people: you can save
## everyone, but you'll meet the villain at full strength.
##
## Enemies ask for `fire_scale()` rather than being told, so a level without an
## Alert node simply behaves as if the level were 0.

signal level_changed(level: int)

## Seconds at each level before the next one starts.
@export var seconds_per_level := 45.0
@export var max_level := 3
## How much faster enemies act per level. 0.3 = 30% quicker at level 1.
@export var urgency_per_level := 0.3
@export var running := true

var level := 0
var elapsed := 0.0


func _ready() -> void:
	add_to_group(&"alert")


func _process(delta: float) -> void:
	if not running or level >= max_level:
		return
	elapsed += delta
	var next := mini(int(elapsed / maxf(seconds_per_level, 0.01)), max_level)
	if next != level:
		level = next
		level_changed.emit(level)


## Multiplier for enemy timers: shorter waits at higher alert.
func fire_scale() -> float:
	return 1.0 / (1.0 + urgency_per_level * float(level))


func reset() -> void:
	elapsed = 0.0
	if level != 0:
		level = 0
		level_changed.emit(level)
