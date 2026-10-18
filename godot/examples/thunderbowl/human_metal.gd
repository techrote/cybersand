extends "res://examples/thunderbowl/human_wire.gd"

var _direct_input: Dictionary = {}


func _reset() -> void:
	super._reset()
	_direct_input = {}


func set_input(frame: Dictionary) -> bool:
	_direct_input = {}
	return super.set_input(frame)


func set_actuator_input(frame: Dictionary) -> bool:
	if not Contract.valid_metal_input(frame):
		_direct_input = {}
		_input = Contract.neutral_input()
		return false
	_direct_input = frame.duplicate(true)
	return true


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	if not _direct_input.is_empty():
		var active: bool = _direct_input.deadman
		return _packet(view, {"actuators": _direct_input.actuators if active else [0.0, 0.0, 0.0, 0.0],
			"tag_aim": _direct_input.aim if active else [0.0, 0.0]}, active and _direct_input.tag, [], not active)
	var channels: Array = [0.0, 0.0, 0.0, 0.0]
	var aim: Array = [0.0, 0.0]
	if _input.deadman:
		aim = _input.aim.duplicate()
		match String(view.model):
			"ripper": channels = [_input.movement[0], _input.trim, _input.effort if _input.secondary else 0.0, 0.0]
			"copter": channels = [maxf(0.0, -_input.movement[1]) * _input.effort,
				_input.movement[0] * _input.effort, _input.trim, _input.effort if _input.secondary else 0.0]
			"gemini": channels = [_input.effort if _input.primary else 0.0,
				_input.effort if _input.secondary else 0.0, 0.0, 0.0]
	return _packet(view, {"actuators": channels, "tag_aim": aim},
		bool(_input.deadman) and bool(_input.tag), [], not _input.deadman)
