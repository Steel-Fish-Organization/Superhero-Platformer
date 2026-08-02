class_name Hazard
extends Area2D
## Spikes, lava, crushers and bottomless-pit volumes.
##
## Instant-kill hazards bypass invulnerability frames, matching Mega Man: spikes
## kill you even mid-blink. Set `instant_kill` off for a hazard that merely hurts.
##
## The player is handled by his own hurtbox (which masks this layer), so this
## node only watches for enemies -- otherwise a single overlap would be counted
## twice and deal double damage.

@export var instant_kill: bool = true
@export var damage: int = 4
## Also destroys enemies that touch it.
@export var hurts_enemies: bool = false


func _ready() -> void:
	collision_layer = Layers.HAZARD
	collision_mask = Layers.ENEMY if hurts_enemies else 0
	monitoring = hurts_enemies
	monitorable = true
	if instant_kill:
		add_to_group(&"instant_death")
	body_entered.connect(_on_body_entered)


## Read by the player's hurtbox when this hazard only wounds.
func get_contact_damage() -> int:
	return damage


func _on_body_entered(body: Node) -> void:
	if hurts_enemies and body is Enemy:
		(body as Enemy).die()
