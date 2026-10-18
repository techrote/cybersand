extends RefCounted

# Example policy state is private to one actor. Only copied views enter here.
const Contract = preload("res://scripts/thunderbowl_contract.gd")
var _sequence: int = 0
var _run_id: String = ""
var _epoch: int = -1
var _actor_id: int = -1


func _begin(view: Dictionary) -> void:
	if view.run_id != _run_id or int(view.epoch) != _epoch or int(view.actor_id) != _actor_id:
		_run_id = view.run_id
		_epoch = int(view.epoch)
		_actor_id = int(view.actor_id)
		_sequence = 0
		_reset()


func _reset() -> void:
	pass


func _packet(view: Dictionary, action: Dictionary, tag: bool = false,
		message: Array = [], cancel: bool = false, message_type: String = "none") -> Dictionary:
	_sequence += 1
	return Contract.command(view, _sequence, action, tag, message, cancel, message_type)


func _self_centre(view: Dictionary) -> Vector2:
	return Vector2(view.self_state[0] + view.self_state[35] * 0.5,
		view.self_state[1] + view.self_state[36] * 0.5)


func _visible_enemy(view: Dictionary) -> Dictionary:
	var nearest: Dictionary = {}
	var distance: float = INF
	for neighbor: Dictionary in view.neighbors:
		if int(neighbor.team) == int(view.team):
			continue
		var relative: Vector2 = Vector2(neighbor.relative_position[0], neighbor.relative_position[1])
		if relative.length_squared() < distance:
			nearest = neighbor
			distance = relative.length_squared()
	return nearest


func _wire_toward(view: Dictionary, relative: Vector2, effort: float = 0.7) -> Dictionary:
	var action: Dictionary = Contract.neutral_wire()
	var desired: Vector2 = relative / 24.0
	action.movement = [clampf(desired.x, -1.0, 1.0), clampf(desired.y, -1.0, 1.0)]
	action.aim = Contract.normalized([relative.x, relative.y])
	action.effort = effort
	# Authored reactive example: grounded periodic jump, not a reachability planner.
	action.primary = view.self_state[4] > 0.5 and int(view.tick) % 90 < 6
	return action


func _shot(view: Dictionary, relative: Vector2) -> bool:
	# Pulses include a release phase, preserving arena rising-edge semantics.
	return bool(view.tag_ready) and relative.length() <= 56.0 and int(view.tick) % 12 == 0
