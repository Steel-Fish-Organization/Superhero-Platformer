class_name Weapon
extends Resource
## One weapon, saved as a .tres you drag into the Player's `weapons` array.
##
## A charge weapon is just a chain: each file describes one tier and points at
## the next one through `charged`. So the pulse gun is
##
##     pulse.tres  ->  pulse_mid.tres  ->  pulse_full.tres
##
## and a bomb that doesn't charge is one file with `charged` left empty. To try
## a new weapon, make a new .tres, point it at a projectile scene, and drop it
## in the array -- no code changes anywhere.

@export var display_name := "Weapon"

@export_group("Shot")
## What gets fired. Any scene whose root has the Projectile script.
@export var projectile: PackedScene
@export var damage := 1
@export var speed := 300.0
## Shots of this weapon allowed on screen at once. Mega Man's buster is 3.
@export var max_active := 3
## Seconds before you can fire again.
@export var cooldown := 0.12
## Fired all at once, spread over `spread_degrees`.
@export_range(1, 8) var shot_count := 1
@export_range(0.0, 180.0, 1.0) var spread_degrees := 0.0
## Aims the shot upward, useful for lobbed weapons like the bomb.
@export_range(-89.0, 89.0, 1.0) var launch_angle := 0.0

@export_group("Charging")
## How long fire must be held to reach THIS tier. The first tier is 0.
@export var charge_time := 0.0
## The tier this one upgrades into. Leave empty for a weapon with no charge.
@export var charged: Weapon


## Walks the charge chain and returns the best tier for how long fire was held.
func tier_for(held: float) -> Weapon:
	var best: Weapon = self
	var next: Weapon = charged
	while next != null and held >= next.charge_time:
		best = next
		next = next.charged
	return best


## True if holding fire on this weapon can produce anything stronger.
func can_charge() -> bool:
	return charged != null
