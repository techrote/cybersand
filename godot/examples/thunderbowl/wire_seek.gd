extends "res://examples/thunderbowl/controller_base.gd"


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	var enemy: Dictionary = _visible_enemy(view)
	var relative: Vector2 = Vector2(24.0 * cos(float(view.tick) / 90.0), -4.0)
	if not enemy.is_empty():
		relative = Vector2(enemy.relative_position[0], enemy.relative_position[1])
	return _packet(view, _wire_toward(view, relative), not enemy.is_empty() and _shot(view, relative))


func decide_toward(view: Dictionary, relative: Vector2, attack: bool = true) -> Dictionary:
	_begin(view)
	return _packet(view, _wire_toward(view, relative), attack and _shot(view, relative))
