extends "res://examples/thunderbowl/controller_base.gd"


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	var enemy: Dictionary = _visible_enemy(view)
	var relative: Vector2 = Vector2(18.0, 0.0)
	var message: Array = []
	if not enemy.is_empty():
		relative = Vector2(enemy.relative_position[0], enemy.relative_position[1])
		# A bounded absolute arena-cell target suggestion, team/lifetime checked
		# by delivery. The recipient cannot treat it as fresh personal vision.
		var target: Vector2 = _self_centre(view) + relative
		message = [clampf(target.x / 1024.0, 0.0, 1.0), clampf(target.y / 1024.0, 0.0, 1.0), 1.0, 0.0]
	else:
		for received: Dictionary in view.messages:
			if received.kind == "goal_hint" and received.payload[2] > 0.5:
				relative = Vector2(received.payload[0], received.payload[1]) * 1024.0 - _self_centre(view)
				break
	# Explicit group-interest spacing is coordination even without a packet.
	var separation: Vector2 = Vector2.ZERO
	for neighbor: Dictionary in view.neighbors:
		if int(neighbor.team) != int(view.team):
			continue
		var offset: Vector2 = Vector2(neighbor.relative_position[0], neighbor.relative_position[1])
		if offset.length_squared() < 400.0 and offset.length_squared() > 0.01:
			separation -= offset.normalized() * 16.0
	var action: Dictionary = _wire_toward(view, relative + separation)
	# Message-directed travel never authorizes shooting at an unseen entity.
	if not enemy.is_empty(): action.aim = Contract.normalized([relative.x, relative.y])
	return _packet(view, action, not enemy.is_empty() and _shot(view, relative), message,
		false, "goal_hint" if not message.is_empty() else "none")
