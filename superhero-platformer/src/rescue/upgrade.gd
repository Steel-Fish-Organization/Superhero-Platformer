class_name Upgrade
extends Resource
## A permanent reward for saving people, saved as a .tres in
## src/rescue/upgrades/ and handed out by a Civilian or by clearing a stage.
##
## Nothing in the code knows what any particular upgrade does: an upgrade is
## just a set of values written onto the Player, the same drag-and-drop idea as
## the Weapon resources. Make a new one, point a civilian at it, done.

## Must be unique -- it's what the save file stores.
@export var id: StringName = &""
@export var display_name := "Upgrade"
## One line, for the HUD banner when it's earned.
@export var blurb := ""
## Player properties to set, e.g. {"max_health": 32, "charge_rate": 1.6}.
## Applied over the hero's starting values, so removing an upgrade is clean.
@export var player_properties: Dictionary = {}
