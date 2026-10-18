extends "res://examples/thunderbowl/controller_base.gd"


func decide(view: Dictionary) -> Dictionary:
	_begin(view)
	# Open-loop actuator test: no feedback/PID or desired velocity in this policy.
	var phase: int = int(view.tick) % 240
	var drive: float = 0.35 if phase < 90 else (-0.35 if phase < 180 else 0.0)
	var channels: Array = [0.0, 0.0, 0.0, 0.0]
	match String(view.model):
		"ripper": channels = [drive, 0.05 if phase < 90 else 0.0, 0.5 if phase >= 180 else 0.0, 0.0]
		"copter": channels = [0.55 if phase < 180 else 0.0, drive, 0.015 if phase < 90 else -0.015, 0.0]
		"gemini": channels = [0.52 if phase < 180 else 0.0, 0.5 if phase < 180 else 0.0, 0.0, 0.0]
	return _packet(view, {"actuators": channels, "tag_aim": [1.0, 0.0]})
