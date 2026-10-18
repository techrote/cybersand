extends "res://examples/thunderbowl/controller_base.gd"


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	# Environment-mediated candidate: independent Diggers incidentally share
	# opened native terrain. No actor contacts, messages, leader or density bonus.
	# Increased effectiveness with density is a hypothesis, not an authored score.
	var action: Dictionary = Contract.neutral_wire()
	action.movement = [sin(float(view.tick) / 150.0 + float(_actor_id) * 1.7) * 0.45, 1.0]
	action.aim = [0.0, 1.0]
	action.effort = 0.85
	action.primary = true
	return _packet(view, action, bool(view.tag_ready) and int(view.tick) % 12 == 0)
