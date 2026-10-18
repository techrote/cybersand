extends RefCounted

# Presentation/input producer only. A caller supplies aim in world direction;
# the device adapter never reads World or chooses a target for the player.
const Contract = preload("res://scripts/thunderbowl_contract.gd")
const DEADZONE: float = 0.18


static func keyboard_mouse(aim: Vector2, focused: bool, effort: float = 0.7) -> Dictionary:
	var value: Dictionary = Contract.neutral_input()
	value.device = "keyboard_mouse"
	value.deadman = focused
	if not focused: return value
	value.movement = [float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))]
	value.aim = Contract.normalized([aim.x, aim.y]) if aim.is_finite() else [0.0, 0.0]
	value.effort = clampf(effort, 0.0, 1.0)
	value.trim = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	value.reel = float(Input.is_physical_key_pressed(KEY_X)) - float(Input.is_physical_key_pressed(KEY_Z))
	value.primary = Input.is_physical_key_pressed(KEY_SPACE)
	value.secondary = Input.is_physical_key_pressed(KEY_SHIFT)
	value.auxiliary = Input.is_physical_key_pressed(KEY_C)
	value.tag = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return value


static func _axis(value: float) -> float:
	return signf(value) * (absf(value) - DEADZONE) / (1.0 - DEADZONE) if absf(value) > DEADZONE else 0.0


static func gamepad(device: int, focused: bool, effort: float = 0.7) -> Dictionary:
	var value: Dictionary = Contract.neutral_input()
	value.device = "gamepad"
	value.deadman = focused and Input.get_connected_joypads().has(device)
	if not value.deadman: return value
	value.movement = [_axis(Input.get_joy_axis(device, JOY_AXIS_LEFT_X)), _axis(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))]
	value.aim = Contract.normalized([_axis(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)),
		_axis(Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))])
	value.effort = clampf(effort, 0.0, 1.0)
	value.trim = float(Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)) \
		- float(Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER))
	value.reel = float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) \
		- float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))
	value.primary = Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	value.secondary = Input.is_joy_button_pressed(device, JOY_BUTTON_B)
	value.auxiliary = Input.is_joy_button_pressed(device, JOY_BUTTON_X)
	value.tag = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	return value


static func metal_gamepad(device: int, focused: bool, model: String) -> Dictionary:
	var value: Dictionary = gamepad(device, focused, 1.0)
	var channels: Array = [0.0, 0.0, 0.0, 0.0]
	if value.deadman:
		var left: float = clampf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT), 0.0, 1.0)
		var right: float = clampf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT), 0.0, 1.0)
		match model:
			"ripper": channels = [value.movement[0], _axis(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)), left, 0.0]
			"copter": channels = [right, value.movement[0], _axis(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)), left]
			"gemini": channels = [left, right, 0.0, 0.0]
	return {"version": 1, "device": "gamepad", "actuators": channels, "aim": value.aim,
		"tag": value.deadman and Input.is_joy_button_pressed(device, JOY_BUTTON_Y), "deadman": value.deadman}
