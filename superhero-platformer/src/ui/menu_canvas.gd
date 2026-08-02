extends Control
## Drawing surface for the menu screens. The parent owns the state and
## implements `draw_menu(canvas)`.


func _draw() -> void:
	var owner_node := get_parent()
	if owner_node and owner_node.has_method("draw_menu"):
		owner_node.call("draw_menu", self)
