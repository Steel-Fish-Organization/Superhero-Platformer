class_name CutsceneSpeaker
extends Resource
## Who's talking in a cutscene: the name the script uses, and the face to draw
## in their panels. A Cutscene matches script lines to these by name.

## As written in the script, e.g. "Silver Spoon". Case doesn't matter.
@export var name := ""
## One frame is plenty -- use an AtlasTexture to cut it out of a sprite sheet.
@export var portrait: Texture2D
## Recolours the portrait, so one sheet can stand in for several characters.
@export var tint := Color.WHITE
## Faces the other way, so two people talking can look at each other.
@export var flip := false
