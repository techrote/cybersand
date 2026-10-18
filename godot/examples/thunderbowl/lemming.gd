extends "res://examples/thunderbowl/controller_base.gd"

var _direction: float = 1.0


func _reset() -> void:
	_direction = -1.0 if _actor_id % 2 else 1.0


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	# No neighbors, messages, teammate goal or full-map query. Each actor turns
	# after its own failed progress and makes blind periodic tag attempts.
	if int(view.tick) > 0 and int(view.tick) % 60 == 0 and absf(view.self_state[2]) < 2.0:
		_direction = -_direction
	var relative: Vector2 = Vector2(_direction * 30.0, 0.0)
	return _packet(view, _wire_toward(view, relative, 0.85), _shot(view, relative))
