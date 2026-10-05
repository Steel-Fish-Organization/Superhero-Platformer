extends Area2D
## The part of a civilian that enemy fire can hit.
##
## It sits on the "civilian" physics layer, which only enemy shots and enemy
## explosions carry in their masks -- that's what makes bystanders untouchable by
## the hero no matter how carelessly you aim. It's a separate, small box because
## the civilian's own area is the much larger "you can interact here" range.

func take_damage(amount: int, from: Node = null) -> bool:
	var civilian := get_parent() as Civilian
	return civilian.take_damage(amount, from) if civilian else false
