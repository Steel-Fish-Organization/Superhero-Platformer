extends Control
## Thin drawing surface for the HUD. Keeping _draw here (rather than on the
## CanvasLayer, which cannot draw) lets the HUD script own all the state.


func _draw() -> void:
	var hud := get_parent()
	if hud and hud.has_method("draw_hud"):
		hud.call("draw_hud", self)
