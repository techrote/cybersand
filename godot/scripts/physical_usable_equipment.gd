class_name CyberPhysicalUsableEquipment
extends RefCounted

# Main-thread ownership for one physical piece of equipment. The cellular owner
# receives copied poses/identities and returns receipts; it never sees this rig.
const Catalog = preload("res://scripts/usable_catalog.gd")
const VERSION: int = 1
const METERED_VERSION: int = 2
const IN_TOOLS_VERSION: int = 3
const METERED_PROFILE: String = "metered-drain-v1"
const IN_TOOLS_NOZZLE_PROFILE: String = "in-tools-in-nozzle-v1"
const IN_TOOLS_LEAK_PROFILE: String = "in-tools-leak-v1"
const METERED_USABLE: int = 9 # Existing U10 identity; no extra catalogue entry.
const IN_TOOLS_NOZZLE_USABLE: int = 1 # Existing U02 Water Lance.
const IN_TOOLS_LEAK_USABLE: int = 9   # Existing U10 Liquid Drain.
const METERED_WATER: int = 3
const METERED_BRINE: int = 24
const METERED_FIELDS: Array[String] = ["profile", "material", "native_generation",
	"policy_hash", "world_instance_id", "quantity_budget"]
const MAX_PARTS: int = 8
const SETTLE_SPEED: float = 3.0
const SETTLE_ANGULAR_SPEED: float = 0.45
const SETTLE_TICKS: int = 8
const MAX_SETTLE_TICKS: int = 360
const ACTION_KEYS: Array[String] = ["usable_index", "instance_id", "equipment_epoch", "aim",
	"power", "trigger", "alternate", "drop", "attach", "profile", "material"]
const BUTTON_KEYS: Array[String] = ["trigger", "alternate", "drop", "attach"]

var actor_id: int = -1
var instance_id: String = ""
var equipment_epoch: int = 1
var usable_index: int = -1
var profile: String = ""
var material: int = 0
var body_id: int = 0
var state: String = "none"
var charge: float = 100.0
var cooldown: float = 0.0
var last_result: String = "none"
var accepted_uses: int = 0
var refused_uses: int = 0
var last_recoil: Vector2 = Vector2.ZERO
var last_receipt: Dictionary = {}
var processor_state: Dictionary = {"state": "inactive"}
var _rig
var _run_id: String = ""
var _epoch: int = 0
var _generation: int = 0
var _tick: int = 0
var _deadline: int = -1
var _request_sequence: int = 0
var _pending: Dictionary = {}
var _requests: Array = []
var _buttons: Dictionary = {}
var _rearm: bool = false
var _requested_aim: Vector2 = Vector2.RIGHT
var _deploy_intent: bool = false
var _settle_ticks: int = 0
var _deploy_ticks: int = 0
var _deploy_power: float = 1.0
var _last_readback_tick: int = -1
var _cell_patch: Dictionary = {}
var _projectiles: Array = []
var _absent: bool = false
var _metered_drain: Dictionary = {} # Copied native-owner context/ledger, never locally debited.
var _in_tools: Dictionary = {} # Copied #361 source/aperture owner context.


static func definition(base: Dictionary, _loadout: Dictionary = {}) -> Dictionary:
	var data: Dictionary = base.duplicate(true)
	if str(data.get("equipment_preparation", "mounted")) == "none":
		# Explicit absence differs from an empty usable on a permanent chassis.
		# Callers which prepare catalogue geometry without a loadout still retain
		# this declared topology. A supplied contradictory loadout is refused.
		if data.get("parts", []).size() != 1 or not data.get("mounts", []).is_empty() \
			or not data.get("joints", []).is_empty() \
			or (not _loadout.is_empty() and (_loadout.get("preparation") != "none" or _loadout.get("usable_index") != -1)):
			return {}
		data["equipment_managed"] = true
		return data
	if data.get("mounts", []).is_empty() or data.get("parts", []).is_empty():
		return {}
	var mount: Dictionary = data.mounts[0]
	var held: int = int(mount.get("held_part", -1))
	if held < 0:
		if data.parts.size() >= MAX_PARTS:
			return {}
		held = data.parts.size()
		var host: int = int(mount.part)
		var host_part: Dictionary = data.parts[host]
		var half: Vector2 = Vector2(host_part.size) * 0.5
		mount.offset = Vector2(half.x, clampf(Vector2(mount.offset).y, -half.y, half.y))
		var axis: Vector2 = Vector2.RIGHT
		var tool_size: Vector2 = Vector2(5.0, 2.5)
		var host_angle: float = float(host_part.get("angle", 0.0))
		var pivot: Vector2 = Vector2(host_part.offset) + Vector2(mount.offset).rotated(float(host_part.get("angle", 0.0)))
		# The permanent mounting chassis is shared by live loadout changes; a
		# dropped chassis must return before it can be retooled. No spare is made.
		data.parts.append({"id": "equipment", "shape": "rectangle", "offset": pivot + (axis * 2.5).rotated(host_angle),
			"size": tool_size, "mass": 0.12, "angle": host_angle,
			"role": "usable", "color": Color(0.84, 0.66, 0.28), "friction": 0.8, "bounce": 0.02})
		data.joints.append({"id": "equipment_grip", "type": "rotary", "a": host, "b": held,
			"anchor": pivot, "limits": mount.get("limits", Vector2(-2.5, 2.5)),
			"role": "equipment", "aim_axis": axis, "motor_speed": 9.0,
			"max_force": 100.0, "softness": 0.025})
		mount.held_part = held
	# Use the joint which actually owns the held body, including the suspended
	# payload and hammer's distal limb. Its grip is not a fictitious root mount.
	for joint: Dictionary in data.joints:
		if int(joint.b) != held and int(joint.a) != held:
			continue
		var host: int = int(joint.a) if int(joint.b) == held else int(joint.b)
		mount.part = host
		mount.offset = (Vector2(joint.anchor) - Vector2(data.parts[host].offset)).rotated(-float(data.parts[host].get("angle", 0.0)))
		mount["physical_joint_id"] = str(joint.get("id", ""))
		mount["physical_limits"] = joint.get("limits", Vector2(-2.5, 2.5))
		mount["aim_axis"] = joint.get("aim_axis", Vector2.RIGHT)
		# Preserve the payload sling, hammer and blade's authored joint roles;
		# the equipment owner only steers joints that already advertise aim.
		if str(joint.get("role", "")) in ["aim", "tool", "equipment"]:
			joint["equipment_aim"] = true
		break
	mount["equipment_managed"] = true
	data["equipment_managed"] = true
	var bounds := Rect2()
	var first: bool = true
	for part: Dictionary in data.parts:
		var pose := Transform2D(float(part.get("angle", 0.0)), part.offset)
		var half: Vector2 = Vector2(part.size) * 0.5
		for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
			var point: Vector2 = pose * corner
			bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
			first = false
	data["bounds"] = bounds
	data["body_size"] = bounds.size
	data["spawn_floor_clearance"] = bounds.end.y + 2.0
	data["spawn_radius"] = maxf(bounds.position.length(), bounds.end.length()) + 2.0
	data["part_count"] = data.parts.size()
	return data


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func normalized_action(value: Variant) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return {}
	for key: Variant in value:
		if (not key is String and not key is StringName) or str(key) not in ACTION_KEYS:
			return {}
	if not _integer(value.get("usable_index"), -1, Catalog.count() - 1) \
		or not value.get("instance_id") is String or str(value.instance_id).is_empty() \
		or not _integer(value.get("equipment_epoch"), 1, 9007199254740991):
		return {}
	var result: Dictionary = {"usable_index": int(value.usable_index), "instance_id": str(value.instance_id),
		"equipment_epoch": int(value.equipment_epoch), "aim": Vector2.ZERO, "power": 1.0,
		"trigger": false, "alternate": false, "drop": false, "attach": false}
	if value.has("profile") or value.has("material"):
		if not value.get("profile") is String:
			return {}
		var selected_profile: String = str(value.profile)
		var selected_material: Variant = value.get("material", 0)
		if not selected_material is int:
			return {}
		if selected_profile.is_empty():
			if selected_material != 0:
				return {}
		elif selected_profile == METERED_PROFILE:
			if int(value.usable_index) != METERED_USABLE \
				or selected_material not in [METERED_WATER, METERED_BRINE]:
				return {}
		elif selected_profile == IN_TOOLS_NOZZLE_PROFILE:
			if int(value.usable_index) != IN_TOOLS_NOZZLE_USABLE or selected_material != METERED_WATER:
				return {}
		elif selected_profile == IN_TOOLS_LEAK_PROFILE:
			if int(value.usable_index) != IN_TOOLS_LEAK_USABLE or selected_material != 0:
				return {}
		else:
			return {}
		result["profile"] = selected_profile
		result["material"] = selected_material
	for button: String in BUTTON_KEYS:
		if value.has(button) and not value[button] is bool:
			return {}
		result[button] = bool(value.get(button, false))
	if value.has("power"):
		if not (value.power is int or value.power is float) or not is_finite(float(value.power)):
			return {}
		result.power = clampf(float(value.power), 0.0, 1.0)
	if value.has("aim"):
		var aim: Variant = value.aim
		if aim is Array and aim.size() == 2:
			if not (aim[0] is int or aim[0] is float) or not (aim[1] is int or aim[1] is float):
				return {}
			aim = Vector2(float(aim[0]), float(aim[1]))
		if not aim is Vector2 or not aim.is_finite():
			return {}
		result.aim = aim.limit_length(1.0)
	return result


func configure(rig, session_run: String, actor_epoch: int, slot: int, first_body: int, initial_usable: int) -> bool:
	var mount: Dictionary = rig.equipment_mount_state()
	_absent = str(rig.capabilities().get("equipment_preparation", "mounted")) == "none"
	if (_absent and (not mount.is_empty() or initial_usable != -1)) \
		or (not _absent and mount.is_empty()) or initial_usable < -1 or initial_usable >= Catalog.count():
		return false
	_rig = rig
	_run_id = session_run
	_epoch = actor_epoch
	actor_id = slot
	body_id = 0 if _absent else first_body + int(mount.held_part) + 1
	instance_id = "%s:%d:%d:equipment" % [session_run, actor_epoch, slot]
	usable_index = initial_usable
	state = "held" if usable_index >= 0 else "none"
	last_result = "equipped" if usable_index >= 0 else "unequipped"
	return true


func matches(action: Dictionary) -> bool:
	return action.get("instance_id") == instance_id \
		and int(action.get("equipment_epoch", -1)) == equipment_epoch


func can_select(index: int) -> bool:
	return not _absent and (index == usable_index or state in ["held", "none"])


func pre_advance(action: Dictionary, fallback_aim: Vector2, allowed: bool) -> void:
	if not allowed or action.is_empty() or not matches(action):
		_rig.set_equipment_aim(Vector2.ZERO, false)
		return
	var aim: Vector2 = action.get("aim", Vector2.ZERO)
	if aim.length_squared() < 0.00001:
		aim = fallback_aim
	if aim.length_squared() > 0.00001:
		_requested_aim = aim.normalized()
	_rig.set_equipment_aim(_requested_aim, state in ["held", "none"])


func advance(action: Dictionary, delta: float, current_tick: int, generation: int, deadline: int, allowed: bool) -> void:
	if _absent:
		return
	_tick = current_tick
	_generation = generation
	_deadline = deadline
	cooldown = maxf(0.0, cooldown - minf(delta, 1.0 / 30.0))
	charge = minf(100.0, charge + minf(delta, 1.0 / 30.0) * 6.0)
	if not allowed:
		cancel(generation)
		return
	if not action.is_empty() and matches(action):
		var requested: int = int(action.usable_index)
		var requested_profile: String = str(action.get("profile", profile if requested == usable_index else ""))
		var requested_material: int = int(action.get("material", material if requested == usable_index else 0))
		if requested != usable_index or requested_profile != profile or requested_material != material:
			if can_select(requested) and state in ["held", "none"]:
				usable_index = requested
				profile = requested_profile
				material = requested_material
				equipment_epoch += 1
				_retire_pending()
				_rearm = bool(action.trigger) or bool(action.alternate)
				_buttons = {"trigger": bool(action.trigger), "alternate": bool(action.alternate), "drop": false, "attach": false}
				state = "held" if usable_index >= 0 else "none"
				last_result = "equipped_release_to_arm" if _rearm else ("equipped" if usable_index >= 0 else "unequipped")
				return
			_refuse("selection_requires_held_body")
			return
		release_metered_activation(action)
		var pressed: Dictionary = {}
		for button: String in BUTTON_KEYS:
			pressed[button] = bool(action[button]) and not bool(_buttons.get(button, false))
			_buttons[button] = bool(action[button])
		if bool(pressed.drop) and bool(pressed.attach):
			_refuse("ambiguous_attachment_action")
			return
		if bool(pressed.drop):
			_drop(false)
			return
		if bool(pressed.attach):
			_attach()
			return
		if _rearm:
			if not bool(action.trigger) and not bool(action.alternate):
				_rearm = false
			return
		if usable_index >= 0:
			var category: StringName = Catalog.category_for(usable_index)
			if category == Catalog.CATEGORY_OBJECT and bool(pressed.trigger):
				if float(action.power) <= 0.0:
					_refuse("zero_power")
					return
				_deploy_power = float(action.power)
				if state == "held":
					_drop(true)
				elif state == "released":
					_deploy_intent = true
					_deploy_ticks = 0
					last_result = "settling"
				elif state == "fixed" and _pending.is_empty():
					_request("deploy", float(action.power))
			elif bool(pressed.alternate):
				if category == Catalog.CATEGORY_OBJECT:
					_refuse("processor_pickup_requires_attach")
				elif state == "held":
					_request("alternate", float(action.power))
			elif (bool(action.trigger) if category == Catalog.CATEGORY_TOOL else bool(pressed.trigger)):
				if state == "held":
					_request("use", float(action.power))
				else:
					_refuse("equipment_not_held")
	elif action.is_empty():
		_buttons.clear()
		if not profile.is_empty():
			_retire_pending()
	if _deploy_intent and state == "released":
		_settle_deployment()


func _drop(deploy: bool) -> void:
	if state not in ["held", "none"] or not _rig.release_usable():
		_refuse("release_requires_owned_grip")
		return
	_retire_pending()
	equipment_epoch += 1
	state = "released"
	_deploy_intent = deploy
	_deploy_ticks = 0
	_settle_ticks = 0
	last_result = "settling" if deploy else "released"
	_rig.refresh_observation()


func _attach() -> void:
	if state in ["held", "none"]:
		_refuse("already_attached")
		return
	if not _rig.attach_usable():
		_refuse("reattach_requires_proximity_and_clearance")
		return
	_retire_pending()
	equipment_epoch += 1
	state = "held" if usable_index >= 0 else "none"
	_deploy_intent = false
	_rearm = true
	processor_state = {"state": "inactive"}
	last_result = "reattached_release_to_arm"
	_rig.refresh_observation()


func _settle_deployment() -> void:
	_deploy_ticks += 1
	var mount: Dictionary = _rig.equipment_mount_state()
	if mount.is_empty():
		_deploy_intent = false
		_refuse("missing_equipment_body")
		return
	var settled: bool = Vector2(mount.velocity).length() <= SETTLE_SPEED \
		and absf(float(mount.angular_velocity)) <= SETTLE_ANGULAR_SPEED and bool(mount.supported)
	_settle_ticks = _settle_ticks + 1 if settled else 0
	if _settle_ticks >= SETTLE_TICKS:
		if not _rig.fix_usable():
			_deploy_intent = false
			_refuse("cannot_fix_equipment")
			return
		state = "fixed"
		_deploy_intent = false
		equipment_epoch += 1
		_request("deploy", _deploy_power)
	elif _deploy_ticks >= MAX_SETTLE_TICKS:
		_deploy_intent = false
		_refuse("deployment_did_not_settle")


func _request(operation: String, power: float) -> void:
	if not _pending.is_empty():
		return
	if not profile.is_empty():
		var experimental_error: String = _experimental_context_error()
		if not experimental_error.is_empty():
			_refuse(experimental_error)
			return
	var payload_alternate: bool = operation == "alternate" and Catalog.category_for(usable_index) == Catalog.CATEGORY_PROJECTILE
	if operation != "deploy" and not payload_alternate and cooldown > 0.0:
		_refuse("cooldown")
		return
	if power <= 0.0 and not payload_alternate:
		_refuse("zero_power")
		return
	var definition_value: Dictionary = Catalog.entry(usable_index)
	# U01-U32 costs are authored per accepted activation; power controls the
	# effect, not its accounting charge. The worker owns the final decision.
	var required: float = float(definition_value.get("cost", 0.0))
	if charge < required and not payload_alternate:
		_refuse("resource")
		return
	var pose: Dictionary = _rig.equipment_mount_state()
	if pose.is_empty() or (operation != "deploy" and not payload_alternate and not bool(pose.clearance)):
		_refuse("muzzle_blocked")
		return
	_request_sequence += 1
	_pending = {"version": VERSION, "run_id": _run_id, "epoch": _epoch, "actor_id": actor_id,
		"generation": _generation, "equipment_epoch": equipment_epoch, "instance_id": instance_id,
		"usable_index": usable_index, "body_id": body_id, "sequence": _request_sequence,
		"request_id": "%s:%d:%d" % [instance_id, equipment_epoch, _request_sequence],
		"operation": operation, "power": power}
	if not profile.is_empty():
		_pending.version = METERED_VERSION if profile == METERED_PROFILE else IN_TOOLS_VERSION
		_pending.merge(_experimental_request_context(), true)
	_requests.append(_pending.duplicate(true))
	last_result = "awaiting_cellular_admission"


func _refuse(reason: String) -> void:
	last_result = reason
	refused_uses += 1


func _retire_pending() -> void:
	_pending.clear()
	_requests.clear()


func release_metered_activation(action: Dictionary) -> void:
	# A released intake cannot commit later from an already copied request.
	# The ordinary equipment frame publishes the empty request ID and the
	# worker revalidates it under its existing cancellation/transaction mutex.
	# Committed ordinary projectile and processor semantics are unchanged.
	if profile.is_empty() or _pending.is_empty():
		return
	var held: bool = bool(action.get("alternate", false)) if str(_pending.operation) == "alternate" \
		else bool(action.get("trigger", false))
	if int(action.get("usable_index", -1)) != usable_index \
		or str(action.get("profile", profile)) != profile \
		or int(action.get("material", material)) != material:
		held = false
	if not held:
		_retire_pending()
		last_result = "released"


func _experimental_context_error() -> String:
	if profile == METERED_PROFILE:
		if usable_index != METERED_USABLE or material not in [METERED_WATER, METERED_BRINE]:
			return "metered_profile"
		if _metered_drain.is_empty():
			return "awaiting_native_owner_context"
		if bool(_metered_drain.get("terminal", true)):
			return "metered_owner_terminal"
		if not bool(_metered_drain.get("available", false)):
			var reason: String = str(_metered_drain.get("reason", ""))
			return "metered_owner_unavailable" if reason.is_empty() else reason
		if int(_metered_drain.get("world_instance_id", 0)) == 0 \
			or int(_metered_drain.get("native_generation", -1)) < 0 \
			or str(_metered_drain.get("policy_hash", "")).length() != 64:
			return "invalid_metered_readback"
		if material not in _metered_drain.get("allowed_materials", []):
			return "unsupported_material_policy"
		var remaining: int = int(_metered_drain.water_units_remaining) if material == METERED_WATER \
			else int(_metered_drain.brine_cells_remaining)
		return "experimental_budget_exhausted" if remaining <= 0 else ""
	if profile not in [IN_TOOLS_NOZZLE_PROFILE, IN_TOOLS_LEAK_PROFILE]:
		return "experimental_profile"
	if profile == IN_TOOLS_NOZZLE_PROFILE and (usable_index != IN_TOOLS_NOZZLE_USABLE or material != METERED_WATER):
		return "in_tools_nozzle_profile"
	if profile == IN_TOOLS_LEAK_PROFILE and (usable_index != IN_TOOLS_LEAK_USABLE or material != 0):
		return "in_tools_leak_profile"
	if _in_tools.is_empty():
		return "awaiting_in_tools_owner_context"
	if bool(_in_tools.get("terminal", true)):
		return "in_tools_owner_terminal"
	if not bool(_in_tools.get("available", false)):
		var reason: String = str(_in_tools.get("reason", ""))
		return "in_tools_owner_unavailable" if reason.is_empty() else reason
	if int(_in_tools.get("world_instance_id", 0)) == 0 \
		or int(_in_tools.get("native_generation", -1)) < 0 \
		or str(_in_tools.get("policy_hash", "")).length() != 64:
		return "invalid_in_tools_readback"
	if profile == IN_TOOLS_NOZZLE_PROFILE and int(_in_tools.get("water_units_remaining", 0)) <= 0:
		return "experimental_budget_exhausted"
	return ""


func _experimental_request_context() -> Dictionary:
	var context: Dictionary = _metered_drain if profile == METERED_PROFILE else _in_tools
	var maximum: int = int(context.get("maximum", 0))
	var budget: int = 0
	if profile == METERED_PROFILE:
		budget = 16 * maximum if material == METERED_WATER else (16 if maximum > 0 else 0)
	elif profile == IN_TOOLS_NOZZLE_PROFILE:
		budget = int(context.get("water_units_remaining", 0))
	return {"profile": profile, "material": material,
		"native_generation": int(context.get("native_generation", -1)),
		"policy_hash": str(context.get("policy_hash", "")),
		"world_instance_id": int(context.get("world_instance_id", 0)),
		"quantity_budget": budget}


func cancel(generation: int) -> void:
	_generation = generation
	_deadline = -1
	_retire_pending()
	_buttons.clear()
	_rearm = false
	_deploy_intent = false
	_settle_ticks = 0
	_rig.set_equipment_aim(Vector2.ZERO, false)
	# Released/deployed bodies and already committed worker entities persist.
	# A producer cancellation is neither pickup nor a velocity-changing action.
	last_result = "cancelled"


func drain_requests() -> Array:
	var result: Array = _requests.duplicate(true)
	_requests.clear()
	return result


func reject_requests(requests: Array, reason: String) -> void:
	for request: Variant in requests:
		if request is Dictionary and not _pending.is_empty() and request.get("request_id") == _pending.get("request_id"):
			_retire_pending()
			_refuse(reason)


func accept_receipt(receipt: Dictionary, generation: int, current_tick: int, deadline: int) -> bool:
	if _pending.is_empty() or generation != _generation or current_tick >= deadline:
		return false
	for key: String in ["version", "run_id", "epoch", "actor_id", "generation", "equipment_epoch", "instance_id",
		"usable_index", "body_id", "sequence", "request_id", "operation"]:
		if receipt.get(key) != _pending.get(key):
			return false
	if int(_pending.version) in [METERED_VERSION, IN_TOOLS_VERSION]:
		for key: String in METERED_FIELDS:
			if receipt.get(key) != _pending.get(key):
				return false
	if not receipt.get("accepted") is bool or not receipt.get("consumed") is bool:
		return false
	for key: String in ["charge", "cooldown"]:
		var value: Variant = receipt.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	if float(receipt.charge) < 0.0 or float(receipt.charge) > 100.0 or float(receipt.cooldown) < 0.0 or float(receipt.cooldown) > 60.0:
		return false
	var accepted: bool = bool(receipt.accepted) and bool(receipt.consumed)
	if int(_pending.version) == METERED_VERSION \
		and not _valid_metered_outcome(receipt.get("metered_drain"), material, accepted,
			int(_pending.quantity_budget), int(_metered_drain.get(
				"water_units_initial" if material == METERED_WATER else "brine_cells_initial",0))):
		return false
	if int(_pending.version) == IN_TOOLS_VERSION \
		and not _valid_in_tools_outcome(receipt.get("in_tools"), profile, accepted,
			int(_pending.quantity_budget), int(_in_tools.get("water_units_initial", 0))):
		return false
	var operation: String = str(_pending.operation)
	var power: float = float(_pending.power)
	charge = float(receipt.charge)
	cooldown = float(receipt.cooldown)
	last_receipt = receipt.duplicate(true)
	last_result = str(receipt.get("reason", "accepted" if accepted else "refused"))
	_retire_pending()
	if not accepted:
		refused_uses += 1
		return true
	accepted_uses += 1
	if operation == "deploy":
		if state == "fixed":
			state = "deployed"
			processor_state = {"state": "ready"}
	elif state == "held" and operation in ["use", "alternate"]:
		# Applying at most once is guaranteed by consuming the matching pending
		# token before touching Rapier. No forged receipt supplies an impulse.
		var category: StringName = Catalog.category_for(usable_index)
		var magnitude: float = (8.0 if category == Catalog.CATEGORY_PROJECTILE else 1.1) * power
		if operation == "alternate" and category == Catalog.CATEGORY_PROJECTILE:
			magnitude = 0.0
		elif operation == "alternate":
			magnitude *= 0.35
		last_recoil = _rig.apply_equipment_recoil(magnitude)
	return true


func accept_readback(row: Dictionary, feedback: Dictionary, generation: int) -> bool:
	if row.get("run_id") != _run_id or row.get("epoch") != _epoch \
		or row.get("actor_id") != actor_id or row.get("generation") != generation \
		or row.get("instance_id") != instance_id or row.get("equipment_epoch") != equipment_epoch \
		or row.get("usable_index") != usable_index or row.get("body_id") != body_id \
		or not _integer(feedback.get("tick"), 0, 9007199254740991) \
		or int(feedback.tick) <= _last_readback_tick:
		return false
	for key: String in ["charge", "cooldown"]:
		if not (row.get(key) is int or row.get(key) is float) or not is_finite(float(row[key])):
			return false
	if float(row.charge) < 0.0 or float(row.charge) > 100.0 or float(row.cooldown) < 0.0 or float(row.cooldown) > 60.0:
		return false
	if row.has("metered_drain"):
		var context: Variant = row.metered_drain
		if not _valid_metered_readback(context):
			_metered_drain.clear()
			if profile == METERED_PROFILE:
				_retire_pending()
				last_result = "invalid_metered_readback"
				return false
		else:
			if not _metered_drain.is_empty() and (
				context.world_instance_id != _metered_drain.world_instance_id \
				or context.native_generation != _metered_drain.native_generation \
				or context.policy_hash != _metered_drain.policy_hash):
				if profile == METERED_PROFILE:
					_retire_pending()
					_rearm = true
					last_result = "native_owner_changed_release_to_arm"
			_metered_drain = context.duplicate(true)
			if profile == METERED_PROFILE and bool(context.terminal):
				_retire_pending()
				last_result = "metered_owner_terminal"
	if row.has("in_tools"):
		var in_tools_context: Variant = row.in_tools
		if not _valid_in_tools_readback(in_tools_context):
			_in_tools.clear()
			if profile in [IN_TOOLS_NOZZLE_PROFILE, IN_TOOLS_LEAK_PROFILE]:
				_retire_pending()
				last_result = "invalid_in_tools_readback"
				return false
		else:
			if not _in_tools.is_empty() and (
				in_tools_context.world_instance_id != _in_tools.world_instance_id \
				or in_tools_context.native_generation != _in_tools.native_generation \
				or in_tools_context.policy_hash != _in_tools.policy_hash):
				if profile in [IN_TOOLS_NOZZLE_PROFILE, IN_TOOLS_LEAK_PROFILE]:
					_retire_pending()
					_rearm = true
					last_result = "native_owner_changed_release_to_arm"
			_in_tools = in_tools_context.duplicate(true)
			if profile in [IN_TOOLS_NOZZLE_PROFILE, IN_TOOLS_LEAK_PROFILE] and bool(in_tools_context.terminal):
				_retire_pending()
				last_result = "in_tools_owner_terminal"
	_last_readback_tick = int(feedback.tick)
	charge = float(row.charge)
	cooldown = float(row.cooldown)
	if row.get("cell_patch") is Dictionary:
		_cell_patch = row.cell_patch.duplicate(true)
	_projectiles.clear()
	for projectile: Variant in feedback.get("projectiles", []):
		if _projectiles.size() >= 64:
			break
		if projectile is Dictionary and int(projectile.get("owner", -1)) == actor_id:
			_projectiles.append(projectile.duplicate(true))
	for device: Variant in feedback.get("objects", []):
		if device is Dictionary and device.get("instance_id") == instance_id \
			and device.get("equipment_epoch") == equipment_epoch and device.get("body_id") == body_id:
			processor_state = device.duplicate(true)
			processor_state["state"] = str(device.get("status", "waiting"))
			break
	return true


static func _valid_metered_readback(value: Variant) -> bool:
	if not value is Dictionary or value.get("profile") != METERED_PROFILE \
		or not value.get("available") is bool or not value.get("terminal") is bool \
		or not value.get("reason") is String or not value.get("policy_hash") is String \
		or not value.get("allowed_materials") is Array:
		return false
	for key: String in ["world_instance_id", "native_generation", "mass_bits", "maximum",
		"water_units_initial", "water_units_remaining", "water_units_removed",
		"brine_cells_initial", "brine_cells_remaining", "brine_cells_removed"]:
		if not value.get(key) is int:
			return false
	if int(value.native_generation) < -1:
		return false
	if bool(value.available) and (int(value.world_instance_id) == 0 or int(value.native_generation) < 0 \
		or str(value.policy_hash).is_empty() or int(value.mass_bits) < 3 or int(value.mass_bits) > 8 \
		or int(value.maximum) != (1 << int(value.mass_bits)) - 1):
		return false
	var seen: Dictionary = {}
	for item: Variant in value.allowed_materials:
		if not item is int or item not in [METERED_WATER, METERED_BRINE] or seen.has(item):
			return false
		seen[item] = true
	for prefix: String in ["water_units_", "brine_cells_"]:
		var cap: int = 8160 if prefix == "water_units_" else 32
		var initial: int = int(value[prefix + "initial"])
		var remaining: int = int(value[prefix + "remaining"])
		var removed: int = int(value[prefix + "removed"])
		if initial < 0 or initial > cap or remaining < 0 or removed < 0 \
			or remaining + removed != initial:
			return false
	return true


static func _valid_metered_outcome(value: Variant, selected_material: int, accepted: bool,
	quantity_budget: int, initial_budget: int) -> bool:
	if not value is Dictionary or value.get("status") not in ["applied", "refused", "fault"] \
		or not value.get("reason") is String:
		return false
	for key: String in ["water_units_removed", "brine_cells_removed", "sink_debit", "remaining_budget"]:
		if not value.get(key) is int or int(value[key]) < 0:
			return false
	var debit: int = int(value.water_units_removed) if selected_material == METERED_WATER \
		else int(value.brine_cells_removed)
	var other: int = int(value.brine_cells_removed) if selected_material == METERED_WATER \
		else int(value.water_units_removed)
	if other != 0 or int(value.sink_debit) != debit or quantity_budget <= 0 or initial_budget <= 0 \
		or debit > quantity_budget or int(value.remaining_budget) > initial_budget \
		or debit + int(value.remaining_budget) > initial_budget:
		return false
	if value.has("budget_before"):
		if not value.budget_before is int or int(value.budget_before) < 0 \
			or int(value.budget_before) > initial_budget \
			or int(value.budget_before) - debit != int(value.remaining_budget):
			return false
	if value.status == "applied":
		return accepted and debit > 0
	if accepted:
		return false
	return debit == 0 if value.status == "refused" else true


static func _valid_in_tools_readback(value: Variant) -> bool:
	if not value is Dictionary or value.get("controller") != "in-tools-liquid-v1" \
		or not value.get("available") is bool or not value.get("terminal") is bool \
		or not value.get("reason") is String or not value.get("policy_hash") is String \
		or not value.get("allowed_profiles") is Array or not value.get("aperture_open") is bool \
		or not value.get("aperture_point") is Vector2i:
		return false
	for key: String in ["world_instance_id", "native_generation", "mass_bits", "maximum",
		"water_units_initial", "water_units_remaining", "water_units_admitted"]:
		if not value.get(key) is int:
			return false
	if int(value.native_generation) < -1:
		return false
	if bool(value.available) and (int(value.world_instance_id) == 0 or int(value.native_generation) < 0 \
		or str(value.policy_hash).length() != 64 or int(value.mass_bits) < 3 or int(value.mass_bits) > 8 \
		or int(value.maximum) != (1 << int(value.mass_bits)) - 1):
		return false
	var initial: int = int(value.water_units_initial)
	var remaining: int = int(value.water_units_remaining)
	var admitted: int = int(value.water_units_admitted)
	return initial >= 0 and remaining >= 0 and admitted >= 0 and remaining + admitted == initial


static func _valid_in_tools_outcome(value: Variant, selected_profile: String, accepted: bool,
	quantity_budget: int, initial_budget: int) -> bool:
	if not value is Dictionary or value.get("status") not in ["applied", "refused", "fault"] \
		or not value.get("reason") is String or value.get("profile") != selected_profile:
		return false
	for key: String in ["source_credit", "sink_debit"]:
		if not value.get(key) is int or int(value[key]) < 0:
			return false
	if selected_profile == IN_TOOLS_NOZZLE_PROFILE:
		for key: String in ["water_units_added", "budget_before", "remaining_budget"]:
			if not value.get(key) is int or int(value[key]) < 0:
				return false
		var added: int = int(value.water_units_added)
		if int(value.source_credit) != added or int(value.sink_debit) != 0 \
			or quantity_budget <= 0 or initial_budget <= 0 or int(value.budget_before) != quantity_budget \
			or added > quantity_budget:
			return false
		if value.status == "applied":
			return accepted and added > 0 and int(value.remaining_budget) == quantity_budget - added
		return not accepted and (added == 0 or value.status == "fault")
	if selected_profile == IN_TOOLS_LEAK_PROFILE:
		if int(value.source_credit) != 0 or int(value.sink_debit) != 0 \
			or int(value.get("quantity_delta", 0)) != 0:
			return false
		return accepted == (value.status == "applied")
	return false


func observation() -> Dictionary:
	if _absent:
		return {"preparation": "none", "state": "none", "usable_index": -1,
			"body_id": 0, "available": false, "ready": false, "cell_patch": {}}
	var result: Dictionary = _rig.equipment_mount_state().duplicate(true)
	var definition_value: Dictionary = Catalog.entry(usable_index)
	result.merge({"instance_id": instance_id, "equipment_epoch": equipment_epoch, "body_id": body_id,
		"usable_index": usable_index, "usable_id": str(definition_value.get("id", "")),
		"profile": profile, "material": material, "metered_drain": _metered_drain.duplicate(true),
		"in_tools": _in_tools.duplicate(true),
		"name": str(definition_value.get("name", "None")), "category": str(definition_value.get("category", "")),
		"state": state, "released": state in ["released", "fixed", "deployed"],
		"requested_aim": _requested_aim, "charge": charge, "cooldown": cooldown,
		"ready": usable_index >= 0 and state == "held" and cooldown <= 0.0 and _pending.is_empty() and not _rearm \
			and charge >= float(definition_value.get("cost", 0.0)) \
			and (profile.is_empty() or _experimental_context_error().is_empty()),
		"pending": not _pending.is_empty(), "request_id": str(_pending.get("request_id", "")),
		"last_result": last_result, "last_receipt": last_receipt.duplicate(true),
		"accepted_uses": accepted_uses, "refused_uses": refused_uses, "last_recoil": last_recoil,
		"deploy_intent": _deploy_intent, "processor_state": processor_state.duplicate(true),
		"cell_patch": _cell_patch.duplicate(true), "projectiles": _projectiles.duplicate(true)}, true)
	return result.duplicate(true)


func frame(generation: int, current_tick: int, deadline: int, enabled: bool, parts: Array) -> Dictionary:
	var pose: Dictionary = _rig.equipment_mount_state()
	if pose.is_empty():
		return {}
	var result: Dictionary = {"actor_id": actor_id, "generation": generation, "equipment_epoch": equipment_epoch,
		"instance_id": instance_id, "usable_index": usable_index, "state": state, "body_id": body_id,
		"position": pose.position, "rotation": pose.rotation, "half_extents": pose.half_extents,
		"muzzle": pose.muzzle, "direction": pose.aim_direction, "owner_origin": pose.owner_origin,
		"active": enabled and current_tick < deadline, "lease_deadline": deadline, "parts": parts.duplicate(true)}
	if not profile.is_empty():
		result.merge(_experimental_request_context(), true)
		result["metered_request_id"] = str(_pending.get("request_id", ""))
		# Preserve exactly the context/budget against which this pending command
		# was issued. A later owner change clears it in accept_readback.
		if not _pending.is_empty():
			for key: String in METERED_FIELDS:
				result[key] = _pending[key]
	return result


func device_frame() -> Dictionary:
	if state not in ["fixed", "deployed"]:
		return {}
	var pose: Dictionary = _rig.equipment_mount_state()
	return {"instance_id": instance_id, "actor_id": actor_id, "equipment_epoch": equipment_epoch,
		"usable_index": usable_index, "body_id": body_id, "position": pose.position,
		"rotation": pose.rotation, "half_extents": pose.half_extents, "state": state}
