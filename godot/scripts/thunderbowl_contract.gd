class_name CyberThunderbowlContract
extends RefCounted

# ACT-003: strict JSON value boundary. Semantic authority (issued observations,
# producer, epoch, lane, liveness and lease) is checked by the arena/session.
# Unknown fields fail closed; policies never supply a World operation or callable.
const Catalog = preload("res://scripts/actor_rig_catalog.gd")
const Actuation = preload("res://scripts/actor_rig_actuation.gd")
const MAX_JSON_BYTES: int = 65536
const MAX_SEQUENCE: int = 2147483647
const CONTROLLERS: Array[String] = ["human_wire", "human_metal", "wire_seek", "metal_pulse",
	"oracle", "lemming", "emergent", "local_swarm", "nca", "smart_link"]
const CONFIG_KEYS: Array[String] = ["version", "seed", "max_ticks", "layout", "evaluation", "actors"]
const DEFINITION_KEYS: Array[String] = ["model", "control_mode", "observation_mode", "team", "controller"]
const COMMAND_KEYS: Array[String] = ["version", "run_id", "actor_id", "epoch", "sequence",
	"observed_tick", "observation_id", "lease_ticks", "kind", "action", "tag", "message", "message_type", "cancel"]
const WIRE_KEYS: Array[String] = ["movement", "aim", "effort", "trim", "reel", "primary", "secondary", "auxiliary"]
const INPUT_KEYS: Array[String] = ["version", "device", "movement", "aim", "effort", "trim", "reel",
	"primary", "secondary", "auxiliary", "tag", "deadman"]


static func exact_keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true


static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= minimum and float(value) <= maximum


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return number(value, minimum, maximum) and float(value) == floor(float(value))


static func vector(value: Variant, size: int, minimum: float = -1.0, maximum: float = 1.0) -> bool:
	if not value is Array or value.size() != size:
		return false
	for component: Variant in value:
		if not number(component, minimum, maximum):
			return false
	return true


static func valid_config(value: Variant) -> bool:
	if not exact_keys(value, CONFIG_KEYS) or not integer(value.version, 1, 1) \
		or not integer(value.seed, 0, MAX_SEQUENCE) or not integer(value.max_ticks, 1, 36000) \
		or not value.layout is String or not value.evaluation is String \
		or value.layout != "training_pit" \
		or not ["mechanics", "matched", "asymmetric", "oracle_reference"].has(value.evaluation):
		return false
	if not value.actors is Array or value.actors.is_empty() or value.actors.size() > 8:
		return false
	for definition: Variant in value.actors:
		if not exact_keys(definition, DEFINITION_KEYS) or not definition.model is String \
			or not definition.controller is String or not definition.control_mode is String \
			or not definition.observation_mode is String \
			or not Catalog.has_rig(StringName(definition.model)) \
			or not integer(definition.team, 0, 7) or not CONTROLLERS.has(definition.controller) \
			or not ["wire", "metal"].has(definition.control_mode) \
			or not ["self", "local", "oracle"].has(definition.observation_mode):
			return false
		var controller: String = definition.controller
		var metal: bool = controller == "human_metal" or controller == "metal_pulse"
		if (definition.control_mode == "metal") != metal:
			return false
		if metal and not Actuation.supports_model(StringName(definition.model)):
			return false
		if controller == "oracle" and definition.observation_mode != "oracle":
			return false
		if controller != "oracle" and definition.observation_mode == "oracle":
			return false
		if ["lemming", "emergent"].has(controller) and definition.observation_mode != "self":
			return false
		if ["wire_seek", "local_swarm", "nca", "smart_link"].has(controller) and definition.observation_mode != "local":
			return false
		if controller == "emergent" and definition.model != "digger":
			return false
		if value.evaluation == "matched":
			var first: Dictionary = value.actors[0]
			if controller.begins_with("human_") or definition.model != first.model \
				or definition.control_mode != first.control_mode or definition.observation_mode != first.observation_mode:
				return false
	return true


static func neutral_wire() -> Dictionary:
	return {"movement": [0.0, 0.0], "aim": [0.0, 0.0], "effort": 0.0,
		"trim": 0.0, "reel": 0.0, "primary": false, "secondary": false, "auxiliary": false}


static func valid_wire(value: Variant) -> bool:
	return exact_keys(value, WIRE_KEYS) and vector(value.movement, 2) and vector(value.aim, 2) \
		and number(value.effort, 0.0, 1.0) and number(value.trim, -1.0, 1.0) \
		and number(value.reel, -1.0, 1.0) and value.primary is bool \
		and value.secondary is bool and value.auxiliary is bool


static func valid_command(value: Variant) -> bool:
	if not exact_keys(value, COMMAND_KEYS) or not integer(value.version, 1, 1) \
		or not value.run_id is String or value.run_id.length() < 1 or value.run_id.length() > 64 \
		or not integer(value.actor_id, 0, 7) or not integer(value.epoch, 1, MAX_SEQUENCE) \
		or not integer(value.sequence, 0, MAX_SEQUENCE) or not integer(value.observed_tick, 0, 36000) \
		or not value.observation_id is String or value.observation_id.length() > 128 \
		or value.observation_id.is_empty() or not integer(value.lease_ticks, 1, 18) \
		or not value.kind is String or not value.message_type is String \
		or not value.tag is bool or not value.cancel is bool or not value.message is Array:
		return false
	if not value.message.is_empty() and not vector(value.message, 4):
		return false
	if not ["none", "goal_hint", "latent_state"].has(value.message_type) \
		or (value.message_type == "none") != value.message.is_empty():
		return false
	if value.kind == "rig_action":
		if not valid_wire(value.action):
			return false
		if value.cancel and value.action != neutral_wire():
			return false
	elif value.kind == "actuator_action":
		if not exact_keys(value.action, ["actuators", "tag_aim"]) \
			or not vector(value.action.actuators, 4) or not vector(value.action.tag_aim, 2):
			return false
		if value.cancel and (value.action.actuators != [0.0, 0.0, 0.0, 0.0] or value.action.tag_aim != [0.0, 0.0]):
			return false
	else:
		return false
	return not value.cancel or (not value.tag and value.message.is_empty())


static func command(view: Dictionary, sequence: int, action: Dictionary,
		tag: bool = false, message: Array = [], cancel: bool = false, message_type: String = "none") -> Dictionary:
	return {"version": 1, "run_id": view.run_id, "actor_id": view.actor_id,
		"epoch": view.epoch, "sequence": sequence, "observed_tick": view.tick,
		"observation_id": view.observation_id, "lease_ticks": 12,
		"kind": "actuator_action" if view.control_mode == "metal" else "rig_action",
		"action": action.duplicate(true), "tag": tag, "message": message.duplicate(),
		"message_type": message_type, "cancel": cancel}


static func neutral_input() -> Dictionary:
	var value: Dictionary = neutral_wire()
	value.merge({"version": 1, "device": "virtual", "tag": false, "deadman": false})
	return value


static func valid_input(value: Variant) -> bool:
	if not exact_keys(value, INPUT_KEYS) or not integer(value.version, 1, 1) \
		or not value.device is String \
		or not ["keyboard_mouse", "gamepad", "touch", "virtual"].has(value.device) \
		or not value.tag is bool or not value.deadman is bool:
		return false
	var action: Dictionary = {}
	for key: String in WIRE_KEYS:
		action[key] = value[key]
	return valid_wire(action)


static func normalized(value: Array) -> Array:
	var direction: Vector2 = Vector2(value[0], value[1])
	if direction != Vector2.ZERO:
		direction = (direction / maxf(absf(direction.x), absf(direction.y))).normalized()
	return [direction.x, direction.y]


static func valid_metal_input(value: Variant) -> bool:
	return exact_keys(value, ["version", "device", "actuators", "aim", "tag", "deadman"]) \
		and integer(value.version, 1, 1) and value.device is String \
		and ["keyboard_mouse", "gamepad", "touch", "virtual"].has(value.device) \
		and vector(value.actuators, 4) and vector(value.aim, 2) and value.tag is bool and value.deadman is bool


static func load_json(path: String) -> Dictionary:
	# File I/O is for setup/external adapters, never a motor or World tick.
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_JSON_BYTES:
		file.close()
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}
