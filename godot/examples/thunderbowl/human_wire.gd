extends "res://examples/thunderbowl/controller_base.gd"

var _input: Dictionary = Contract.neutral_input()


func _reset() -> void:
	_input = Contract.neutral_input()


func set_input(frame: Dictionary) -> bool:
	if not Contract.valid_input(frame):
		_input = Contract.neutral_input()
		return false
	_input = frame.duplicate(true)
	return true


func decide_input(view: Dictionary, frame: Dictionary) -> Dictionary:
	# Bind/reset the episode before sampling this frame, preserving a first-tick
	# tap while still clearing input retained from a previous actor/epoch.
	_begin(view)
	if frame.has("actuators") and has_method(&"set_actuator_input"):
		call(&"set_actuator_input", frame)
	else:
		set_input(frame)
	return decide(view)


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	if not _input.deadman:
		return _packet(view, Contract.neutral_wire(), false, [], true)
	var action: Dictionary = {}
	for key: String in Contract.WIRE_KEYS:
		action[key] = _input[key]
	return _packet(view, action, _input.tag)
