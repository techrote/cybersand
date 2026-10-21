class_name CyberPlayerPlaygroundInput
extends RefCounted

# One local sampler for keyboard and standard gamepads. Physics owners consume
# copied actions; they never query global Input or take ownership of UI focus.
const KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN,
	KEY_RIGHT, KEY_Q, KEY_E, KEY_SPACE, KEY_SHIFT, KEY_C]
const DEADZONE: float = 0.18


static func deadzone(value: Vector2) -> Vector2:
	if not value.is_finite() or value.length() <= DEADZONE:
		return Vector2.ZERO
	return value.normalized() * clampf((value.length() - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)


static func sample() -> Dictionary:
	var keys: Dictionary = {}
	for key: Key in KEYS:
		keys[key] = Input.is_physical_key_pressed(key)
	var stick := Vector2.ZERO
	var buttons := Vector3i.ZERO
	var lean: float = 0.0
	var pads: Array[int] = Input.get_connected_joypads()
	if not pads.is_empty():
		var pad: int = pads[0]
		stick = deadzone(Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)))
		buttons = Vector3i(int(Input.is_joy_button_pressed(pad, JOY_BUTTON_A)),
			int(Input.is_joy_button_pressed(pad, JOY_BUTTON_B)), int(Input.is_joy_button_pressed(pad, JOY_BUTTON_X)))
		lean = float(int(Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER))
			- int(Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER)))
	return from_state(keys, stick, buttons, lean)


static func from_state(keys: Dictionary, stick: Vector2 = Vector2.ZERO,
		buttons: Vector3i = Vector3i.ZERO, lean: float = 0.0) -> Dictionary:
	var movement := Vector2(
		int(bool(keys.get(KEY_D, false)) or bool(keys.get(KEY_RIGHT, false))) - int(bool(keys.get(KEY_A, false)) or bool(keys.get(KEY_LEFT, false))),
		int(bool(keys.get(KEY_S, false)) or bool(keys.get(KEY_DOWN, false))) - int(bool(keys.get(KEY_W, false)) or bool(keys.get(KEY_UP, false))))
	if stick.is_finite():
		movement += stick
	var trim: float = float(int(bool(keys.get(KEY_E, false))) - int(bool(keys.get(KEY_Q, false))))
	if is_finite(lean):
		trim += lean
	return {"move": movement.limit_length(1.0), "aim": movement.normalized(), "effort": 1.0,
		"trim": clampf(trim, -1.0, 1.0), "primary": bool(keys.get(KEY_SPACE, false)) or buttons.x != 0,
		"secondary": bool(keys.get(KEY_SHIFT, false)) or buttons.y != 0,
		"auxiliary": bool(keys.get(KEY_C, false)) or buttons.z != 0}


static func active(action: Dictionary) -> bool:
	return Vector2(action.get("move", Vector2.ZERO)).length_squared() > 0.0001 \
		or absf(float(action.get("trim", 0.0))) > 0.01 or bool(action.get("primary", false)) \
		or bool(action.get("secondary", false)) or bool(action.get("auxiliary", false))
