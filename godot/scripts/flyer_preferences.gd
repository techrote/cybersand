extends RefCounted

# User preferences contain bounded copied values. No authored definition, live
# actor, native World, input lease or mutable static state is retained here.
const PlaygroundInput = preload("res://scripts/player_playground_input.gd")
const VERSION: int = 1
const MAX_MODELS: int = 16
const BYTE_LIMIT: int = 256 * 1024
const DEFAULT_OPTIONS := {"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
	"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}
const TUNING_DEFAULTS := {"acceleration":1.0,"speed":1.0,"turn_speed":1.0,
	"turn_acceleration":1.0,"throttle_response":1.0,"drag":1.0,"stabilization":1.0,
	"stabilization_damping":1.0,"gravity":1.0,"friction":1.0,"angular_drag":1.0,
	"swap_side_thrusters":false,"thruster_visuals":true,
	"fire_amount":1.0,"q_amount":1.0,"e_amount":1.0,"s_amount":1.0,
	"q_material":0,"e_material":0,"s_material":0}
const ACTIONS: Array[String] = ["move_up","move_down","move_left","move_right","primary",
	"utility_left","utility_right","dispenser_s","boost","brake","assist"]
const RESERVED: Array[int] = [KEY_P,KEY_R,KEY_B,KEY_F,KEY_TAB,KEY_PERIOD,KEY_F2,
	KEY_ESCAPE,KEY_BRACKETLEFT,KEY_BRACKETRIGHT,
	KEY_0,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,
	KEY_KP_0,KEY_KP_1,KEY_KP_2,KEY_KP_3,KEY_KP_4,KEY_KP_5,KEY_KP_6,KEY_KP_7,KEY_KP_8,KEY_KP_9]

var file_path: String = "user://workbench/flyer-profiles.json"
var _models: Dictionary = {}
var _profiles: Dictionary = {}


static func _keys(value: Variant, expected: Array) -> bool:
	return value is Dictionary and value.size() == expected.size() and value.has_all(expected)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value,low,high) and floor(float(value)) == value


static func _model_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 48: return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true


static func tuning_defaults(capabilities: Dictionary = {}) -> Dictionary:
	var result: Dictionary = TUNING_DEFAULTS.duplicate(true)
	for port: String in ["q","e","s"]:
		result[port+"_material"] = int(capabilities.get("dispenser_"+port,0))
	return result


static func valid_material(value: Variant) -> bool:
	return _integer(value,0,CyberCellWorld.LAST_MATERIAL) and int(value) != 10


static func validate_tuning(value: Variant) -> String:
	if not _keys(value,TUNING_DEFAULTS.keys()): return "Missing or unknown flyer tuning fields."
	for key: String in TUNING_DEFAULTS:
		if TUNING_DEFAULTS[key] is bool:
			if not value[key] is bool: return "Flyer switch must be true or false: "+key
		elif key.ends_with("_material"):
			if not valid_material(value[key]): return "Unavailable emitted material: "+key
		else:
			var high: float = 8.0 if key.ends_with("_amount") else 64.0
			if not _number(value[key],0.0,high): return "Flyer tuning outside admission: "+key
	return ""


static func default_bindings() -> Dictionary:
	return {"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],
		"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"primary":[KEY_SPACE],
		"utility_left":[KEY_Q],"utility_right":[KEY_E],"dispenser_s":[KEY_S,KEY_DOWN],
		"boost":[KEY_SHIFT],"brake":[KEY_CTRL],"assist":[KEY_C]}


static func _canonical_key(code: int) -> int:
	return code-32 if code >= 97 and code <= 122 else code


static func reserved_key(code: int) -> bool:
	return _canonical_key(code) in RESERVED


static func key_label(code: int) -> String:
	return OS.get_keycode_string(_canonical_key(code)) if code > 0 else "Unbound"


static func binding_label(binding: Array) -> String:
	var labels := PackedStringArray()
	for code: Variant in binding: labels.append(key_label(int(code)))
	return " / ".join(labels) if not labels.is_empty() else "Unbound"


static func validate_bindings(value: Variant) -> String:
	if not _keys(value,ACTIONS): return "Missing or unknown flyer actions."
	for action: String in ACTIONS:
		if not value[action] is Array or value[action].size() > 2:
			return "Use at most two keys for "+action+"."
		var used: Dictionary = {}
		for candidate: Variant in value[action]:
			# JSON represents integer values as floats; canonicalization follows
			# validation. Modifier masks/chords are not silently treated as keys.
			if not _integer(candidate,1,KEY_UNKNOWN-1): return "Invalid key for "+action+"."
			var code: int = _canonical_key(int(candidate))
			if reserved_key(code): return key_label(code)+" is reserved for workbench tools/navigation."
			if key_label(code).is_empty(): return "Unknown key for "+action+"."
			if used.has(code): return "Duplicate key within "+action+"."
			used[code] = true
	return ""


static func default_profile(capabilities: Dictionary = {}) -> Dictionary:
	return {"options":DEFAULT_OPTIONS.duplicate(true),"tuning":tuning_defaults(capabilities),
		"bindings":default_bindings(),"fire_enabled":false}


static func validate_profile(value: Variant, capabilities: Dictionary = {}) -> String:
	if not _keys(value,["options","tuning","bindings","fire_enabled"]): return "Invalid flyer profile fields."
	if not value.fire_enabled is bool: return "Thruster Fire must be true or false."
	if not _keys(value.options,DEFAULT_OPTIONS.keys()): return "Missing or unknown body settings."
	for key: String in DEFAULT_OPTIONS:
		var low: float = 5.0 if key == "budget" else (1.0 if key == "boost_multiplier" else (0.01 if key in ["mass_multiplier","inertia_multiplier"] else 0.0))
		var high: float = 80.0 if key == "budget" else (8.0 if key == "boost_multiplier" else 64.0)
		if not _number(value.options[key],low,high): return "Body setting outside admission: "+key
	var error: String = validate_tuning(value.tuning)
	if not error.is_empty(): return error
	for port: String in ["q","e","s"]:
		if capabilities.has("dispenser_"+port) and int(capabilities["dispenser_"+port]) == 0 and int(value.tuning[port+"_material"]) != 0:
			return "This flyer has no "+port.to_upper()+" dispenser."
	return validate_bindings(value.bindings)


static func keys_pressed(binding: Array, state: Dictionary) -> bool:
	for value: Variant in binding:
		if bool(state.get(int(value),false)): return true
	return false


static func from_state(bindings: Dictionary, keys: Dictionary, stick: Vector2 = Vector2.ZERO,
		buttons: Vector3i = Vector3i.ZERO, lean: float = 0.0, gamepad_ports: Dictionary = {},
		reverse_thrust: bool = true) -> Dictionary:
	var held: Dictionary = {}
	for name: String in ACTIONS: held[name] = keys_pressed(bindings.get(name,[]),keys)
	var canonical := {KEY_W:held.move_up,KEY_S:held.move_down and reverse_thrust,
		KEY_A:held.move_left,KEY_D:held.move_right,KEY_SPACE:held.primary,
		KEY_Q:held.utility_left,KEY_E:held.utility_right,KEY_SHIFT:held.brake,KEY_C:held.assist}
	var action: Dictionary = PlaygroundInput.from_state(canonical,stick,buttons,lean)
	if not reverse_thrust:
		# Kestrel's S dispenses without cancelling simultaneous forward thrust.
		action.move.y = -1.0 if held.move_up else minf(0.0,action.move.y)
		action.move = Vector2(action.move).limit_length(1.0)
		action.aim = Vector2(action.move).normalized()
	var ports := {"q":held.utility_left or bool(gamepad_ports.get("q",lean < -0.01)),
		"e":held.utility_right or bool(gamepad_ports.get("e",lean > 0.01)),
		"s":held.dispenser_s or bool(gamepad_ports.get("s",stick.y > 0.2)),"boost":held.boost}
	return {"action":action,"ports":ports}


static func sample(bindings: Dictionary, include_gamepad: bool = true, reverse_thrust: bool = true) -> Dictionary:
	var keys: Dictionary = {}
	for name: String in ACTIONS:
		for value: Variant in bindings.get(name,[]):
			var code: int = int(value)
			keys[code] = Input.is_physical_key_pressed(code) or Input.is_key_pressed(code)
	var stick := Vector2.ZERO
	var buttons := Vector3i.ZERO
	var lean: float = 0.0
	var ports: Dictionary = {}
	var pads: Array[int] = Input.get_connected_joypads()
	if include_gamepad and not pads.is_empty():
		var pad: int = pads[0]
		var raw := Vector2(Input.get_joy_axis(pad,JOY_AXIS_LEFT_X),Input.get_joy_axis(pad,JOY_AXIS_LEFT_Y))
		stick = PlaygroundInput.deadzone(raw)
		buttons = Vector3i(int(Input.is_joy_button_pressed(pad,JOY_BUTTON_A)),
			int(Input.is_joy_button_pressed(pad,JOY_BUTTON_B)),int(Input.is_joy_button_pressed(pad,JOY_BUTTON_X)))
		ports = {"q":Input.is_joy_button_pressed(pad,JOY_BUTTON_LEFT_SHOULDER),
			"e":Input.is_joy_button_pressed(pad,JOY_BUTTON_RIGHT_SHOULDER),"s":raw.y > 0.2}
		lean = float(int(ports.e)-int(ports.q))
	return from_state(bindings,keys,stick,buttons,lean,ports,reverse_thrust)


func configure_models(models: Dictionary) -> void:
	_models = models.duplicate(true)


func profile(model: String) -> Dictionary:
	return _profiles[model].duplicate(true) if _profiles.has(model) else default_profile(_models.get(model,{}))


func has_saved(model: String) -> bool:
	return _profiles.has(model)


func _canonical_profile(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for action: String in ACTIONS:
		var keys: Array = []
		for code: Variant in result.bindings[action]: keys.append(_canonical_key(int(code)))
		result.bindings[action] = keys
	for port: String in ["q","e","s"]: result.tuning[port+"_material"] = int(result.tuning[port+"_material"])
	return result


func load_profiles() -> String:
	if not FileAccess.file_exists(file_path): return ""
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file == null: return "Saved flyer profiles could not be opened."
	if file.get_length() > BYTE_LIMIT: return "Saved flyer profiles exceed the 256 KiB limit."
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return "Saved flyer profiles contain invalid JSON; existing preferences were retained."
	var value: Variant = parser.data
	if not _keys(value,["version","profiles"]) or not _integer(value.version,VERSION,VERSION) or not value.profiles is Dictionary or value.profiles.size() > MAX_MODELS:
		return "Unsupported saved flyer profile format."
	var candidate: Dictionary = {}
	for model: Variant in value.profiles:
		if not _model_id(model) or not _models.has(model): return "Saved flyer profile references an unavailable flyer."
		var error: String = validate_profile(value.profiles[model],_models[model])
		if not error.is_empty(): return "Saved "+str(model)+" profile refused: "+error
		candidate[model] = _canonical_profile(value.profiles[model])
	_profiles = candidate
	return ""


func commit_profile(model: String, value: Dictionary) -> String:
	if not _model_id(model) or not _models.has(model): return "Unavailable flyer profile."
	var error: String = validate_profile(value,_models[model])
	if not error.is_empty(): return error
	var candidate: Dictionary = _profiles.duplicate(true)
	candidate[model] = _canonical_profile(value)
	if candidate.size() > MAX_MODELS: return "Flyer profile capacity exhausted."
	var content: String = JSON.stringify({"version":VERSION,"profiles":candidate},"",true,true)
	if content.to_utf8_buffer().size() > BYTE_LIMIT: return "Flyer profiles exceed the 256 KiB limit."
	var directory: String = file_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return "Cannot create the flyer profile directory."
	var temporary: String = file_path+"."+Crypto.new().generate_random_bytes(8).hex_encode()+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "Cannot create the temporary flyer profile file."
	file.store_string(content)
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result == OK: result = DirAccess.rename_absolute(temporary,file_path)
	if result != OK:
		DirAccess.remove_absolute(temporary)
		return "Flyer preferences were not saved (%s)." % error_string(result)
	_profiles = candidate
	return ""
