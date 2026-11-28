class_name CyberPhysicalActorSession
extends Node2D

signal input_cancelled(actor_id: int, actor_epoch: int)

# ACT-004 main-thread owner. Only copied commands/observations/effects cross its
# boundary. The native cellular worker never receives these nodes or RIDs.
const WorkbenchCatalog = preload("res://scripts/workbench_actor_catalog.gd")
const WorkbenchControl = preload("res://scripts/workbench_actor_control.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const WorkbenchBridge = preload("res://scripts/workbench_physics_bridge.gd")
const WorkbenchEmitter = preload("res://scripts/workbench_emitter.gd")
const Manipulator = preload("res://scripts/workbench_actor_manipulator.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Scripted = preload("res://scripts/physical_actor_script.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")
const Capacity = preload("res://scripts/workbench_sandbox_capacity.gd")
const MAX_ACTORS: int = Capacity.MAX_ACTORS
const AmbientPerception = preload("res://scripts/ambient/ambient_perception.gd")
const AmbientActuator = preload("res://scripts/ambient/ambient_actuator.gd")
const MAX_PARTS: int = 8
const MAX_LEASE: int = 18
const DECISION_TICKS: int = 6
const VERSION: int = 2
const MAX_BUTTON_EDGES: int = 24
const BUTTON_KEYS: Array[String] = ["primary", "secondary", "auxiliary", "tool", "release_usable", "attach_usable"]
const PRODUCERS: Array[StringName] = [&"human", &"demo", &"policy"]
const ACTION_KEYS: Array[String] = ["move", "aim", "effort", "trim", "reel", "primary", "secondary", "auxiliary", "tool", "release_usable", "attach_usable", "equipment"]
const COMMAND_KEYS: Array[String] = ["version", "kind", "run_id", "actor_id", "epoch", "sequence", "observed_tick", "observation_id", "lease_ticks", "action"]

var bridge: CyberRapierPhysicsBridge = CyberRapierPhysicsBridge.new()
var last_error: String = ""
var epoch: int = 0
var tick: int = 0
var run_id: String = ""
var _definitions: Array = []
var _catalogue: Array = []
var _workbench_ports: Dictionary = {}
var _workbench_emitted_at: Dictionary = {}
var _rigs: Array = []
var _scripts: Array = []
var _workbench_decision_ticks := PackedInt64Array()
var _decision_cost_usec := PackedInt64Array()
var _decision_total_usec := PackedInt64Array()
var _actor_accepted := PackedInt64Array()
var _actor_rejected := PackedInt64Array()
var _actor_errors: Array[String] = []
var _equipment: Array = []
var _body_offsets: PackedInt32Array = PackedInt32Array()
var _sequences: PackedInt64Array = PackedInt64Array()
var _deadlines: PackedInt64Array = PackedInt64Array()
var _generations: PackedInt64Array = PackedInt64Array()
var _commands: Array = []
var _flight_commands: Array = []
var _flight_applied: Array = []
var _flight_last_step: Array = []
var _has_flight: bool = false
var _flight_completed_step: int = 0
var _flight_prepared: bool = false
var _flight_step_fault: String = ""
var _flight_pause_step: int = 0
var _fallback_reasons: Array[String] = []
var _button_edges: Array = []
var _accepted_buttons: Array = []
var _applied_buttons: Array = []
var _issued: Array = []
var _effects: Array = []
var _active: bool = false
var _suspended: bool = false
var _manipulator: RefCounted
var _manipulated_actor: int = -1
var accepted_commands: int = 0
var rejected_commands: int = 0
var _ambient_perception = AmbientPerception.new()
var _ambient_sensor_active := false
var _ambient_refresh_requested := false
var _completed_time_seconds := 0.0
var _ambient_completed_physics_step := 0
var _ambient_sensor_cost_usec := PackedInt64Array()
var _ambient_world_generation := -1
var _ambient_world_serial := -1
var _ambient_peer_tick := -1
var _ambient_slots: Dictionary = {}
var _ambient_peer_observations: Array[Dictionary] = []
var _workbench_group_applying := false


static func _valid_retained_motion(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or not value.has_all(["rotation","angular_velocity","linear_velocity"]): return false
	return _finite_scalar(value.rotation) and _finite_scalar(value.angular_velocity) and value.linear_velocity is Vector2 and value.linear_velocity.is_finite()


static func _finite_scalar(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _hulls_inside(extent: Vector2i, origin: Vector2, angle: float, index: int) -> bool:
	var pose := Transform2D(angle,origin)
	var shapes: Array = Fleet.collision_rects(index) if index >= 0 else [{"center":Vector2.ZERO,"size":Vector2(8,14)}]
	for shape: Dictionary in shapes:
		for sign_x: float in [-1.0,1.0]:
			for sign_y: float in [-1.0,1.0]:
				var point: Vector2 = pose * (shape.center + shape.size * Vector2(sign_x,sign_y)*0.5)
				if point.x<0 or point.y<0 or point.x>extent.x or point.y>extent.y: return false
	return true


static func _valid_retained_parts(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for part: Variant in value:
		if not part is Dictionary or part.size() != 4 or not part.has_all(["position", "rotation", "linear_velocity", "angular_velocity"]): return false
		if not part.position is Vector2 or not part.position.is_finite() or not _finite_scalar(part.rotation) \
			or not part.linear_velocity is Vector2 or not part.linear_velocity.is_finite() or not _finite_scalar(part.angular_velocity): return false
	return true


static func _prepared_inside(value: Dictionary, prepared: Dictionary) -> bool:
	var extent: Vector2i = value.canvas_extent
	for index: int in range(prepared.parts.size()):
		var part: Dictionary = prepared.parts[index]
		var spawn_rotation: float = float(value.get("spawn_rotation", 0.0))
		var angle: float = float(part.get("angle", 0.0)) + spawn_rotation
		var origin: Vector2 = value.position + Vector2(part.offset).rotated(spawn_rotation)
		if value.has("retained_motion"):
			angle = float(value.retained_motion.rotation)
		elif value.has("retained_parts"):
			angle = float(value.retained_parts[index].rotation)
			origin = value.retained_parts[index].position
		var pose := Transform2D(angle, origin)
		var rectangles: Array = part.get("collision_rects", [{"center":Vector2.ZERO, "size":part.size}])
		for rectangle: Dictionary in rectangles:
			for x: float in [-1.0, 1.0]:
				for y: float in [-1.0, 1.0]:
					var point: Vector2 = pose * (Vector2(rectangle.center) + Vector2(rectangle.size) * Vector2(x, y) * 0.5)
					if point.x < 0 or point.y < 0 or point.x > extent.x or point.y > extent.y: return false
	return true


static func valid_definitions(definitions: Array) -> bool:
	if definitions.is_empty() or definitions.size() > MAX_ACTORS: return false
	var ambient_slots := 0
	var parts: int = 0
	var proxies: int = 0
	var limits_value: Variant = definitions[0].get("workbench_capacity", Capacity.defaults()) if definitions[0] is Dictionary else {}
	if not Capacity.error(limits_value).is_empty(): return false
	var limits: Dictionary = limits_value
	if definitions.size() > int(limits.logical_limit): return false
	var identities: Dictionary = {}
	var workbench: bool = definitions[0] is Dictionary and definitions[0].has("workbench_options")
	var response: String = ""
	var extent: Vector2i = Vector2i.ZERO
	for value: Variant in definitions:
		if not value is Dictionary: return false
		var model := StringName(str(value.get("model", "")))
		var producer := StringName(str(value.get("producer", "")))
		if workbench != value.has("workbench_options"): return false
		if workbench and value.get("workbench_capacity", Capacity.defaults()) != limits: return false
		if not workbench and value.has("workbench_capacity"): return false
		if not value.get("position") is Vector2 or not value.position.is_finite(): return false
		var prepared: Dictionary
		if workbench:
			if not WorkbenchCatalog.supports_producer(str(model), str(producer)): return false
			prepared = WorkbenchCatalog.definition(str(model))
			if not _integer(value.get("instance_id"), 1, 9007199254740991) or identities.has(int(value.instance_id)): return false
			identities[int(value.instance_id)] = true
			if not value.workbench_options is Dictionary or value.workbench_options.is_empty() or not Rig.valid_review_options(value.workbench_options): return false
			if not response.is_empty() and response != value.workbench_options.response: return false
			response = value.workbench_options.response
			if not value.get("canvas_extent") is Vector2i: return false
			if extent != Vector2i.ZERO and extent != value.canvas_extent: return false
			extent = value.canvas_extent
			if extent.x < 1 or extent.y < 1 or extent.x > 2048 or extent.y > 2048: return false
			if value.has("workbench_control"):
				if not WorkbenchCatalog.control_error(str(model), value.workbench_control).is_empty(): return false
				if value.workbench_control.policy == "ambient": ambient_slots += 1
				if ambient_slots > WorkbenchCatalog.MAX_AMBIENT_CONTROLLERS: return false
				if WorkbenchCatalog.producer_for(str(value.workbench_control.source)) != str(producer): return false
				if int(value.get("usable_index", -1)) != int(value.workbench_control.usable_index): return false
			if value.has("retained_motion") and (prepared.get("parts", []).size() != 1 or value.has("retained_parts") or not _valid_retained_motion(value.retained_motion)): return false
			if value.has("retained_parts") and not _valid_retained_parts(value.retained_parts, prepared.get("parts", []).size()): return false
			if value.has("spawn_rotation") and (not _finite_scalar(value.spawn_rotation) or absf(float(value.spawn_rotation)) > TAU): return false
			if model in Flight.IDS and (float(value.workbench_options.mass_multiplier) != 1.0 or float(value.workbench_options.inertia_multiplier) != 1.0): return false
			if prepared.is_empty() or not _prepared_inside(value, prepared): return false
			proxies += WorkbenchCatalog.proxy_count(str(model))
		else:
			if not Catalog.has_rig(model): return false
			if model == Catalog.PASSIVE_BARREL:
				if producer != &"passive": return false
			elif producer not in PRODUCERS: return false
			if value.has("retained_motion") or value.has("retained_parts") or value.has("workbench_control") or value.has("spawn_rotation"): return false
			if value.position.x < 0.0 or value.position.y < 0.0 or value.position.x >= 1024.0 or value.position.y >= 1024.0: return false
			prepared = Equipment.definition(Catalog.entry(model), Loadouts.entry(model))
		var selected: Variant = value.get("usable_index", Loadouts.entry(model).get("usable_index", -1))
		if prepared.is_empty() or not _integer(selected, -1, 31): return false
		if str(prepared.get("equipment_preparation", "mounted")) == "none" and int(selected) != -1: return false
		var count: int = prepared.parts.size()
		if count < 1 or count > MAX_PARTS: return false
		parts += count
	return parts <= int(limits.body_limit) and proxies <= int(limits.proxy_limit)


func configure(definitions: Array, space: RID, new_epoch: int = 1, diagnostic_observer: Callable = Callable()) -> bool:
	var configuration_started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
	if _active or not is_inside_tree() or not valid_definitions(definitions) or new_epoch < 1:
		last_error = "Invalid physical actor configuration or live owner"
		return false
	if diagnostic_observer.is_valid():
		diagnostic_observer.call("session_validation",configuration_started,{"expected_epoch":new_epoch})
	epoch = new_epoch
	tick = 0
	_completed_time_seconds = 0.0
	_ambient_completed_physics_step = 0
	_ambient_world_generation = -1
	_ambient_world_serial = -1
	_ambient_peer_tick = -1
	_ambient_peer_observations.clear()
	_workbench_group_applying = false
	_ambient_perception.reset()
	_ambient_sensor_active = false
	_ambient_refresh_requested = false
	_suspended = false
	_has_flight = false
	_flight_prepared = false
	_flight_step_fault = ""
	accepted_commands = 0
	rejected_commands = 0
	last_error = ""
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_definitions = definitions.duplicate(true)
	if _definitions[0].has("workbench_options"):
		bridge = WorkbenchBridge.new()
	var all_bodies: Array[RigidBody2D] = []
	var sizes := PackedVector2Array()
	for index: int in range(definitions.size()):
		var actor_started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
		var definition: Dictionary = definitions[index]
		_has_flight = _has_flight or StringName(str(definition.model)) in Flight.IDS
		var loadout: Dictionary = Loadouts.entry(StringName(str(definition.model)))
		var data: Dictionary = WorkbenchCatalog.definition(str(definition.model)) if definition.has("workbench_options") else Equipment.definition(Catalog.entry(StringName(str(definition.model))), loadout)
		var fleet_index: int = Fleet.index_for_id(str(definition.model)) if definition.has("workbench_options") else -1
		if fleet_index >= 0:
			data = Equipment.definition(Fleet.definition(fleet_index))
		_catalogue.append(data)
		if diagnostic_observer.is_valid():
			diagnostic_observer.call("actor_definition",actor_started,{"slot":index,"model":str(definition.model)})
		var rig_started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
		var rig = Rig.new()
		add_child(rig)
		_body_offsets.append(all_bodies.size())
		_rigs.append(rig)
		var options: Dictionary = definition.get("workbench_options", {})
		if rig.configure(data, definition.position, index, epoch, fleet_index, options, definition.has("workbench_options") and fleet_index < 0,
			float(definition.get("spawn_rotation", 0.0))) != OK:
			last_error = "Physical rig refused: " + str(definition.model)
			close()
			return false
		if diagnostic_observer.is_valid():
			diagnostic_observer.call("actor_bodies_shapes",rig_started,{"slot":index,"bodies":rig.bodies().size()})
		var adapters_started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
		if definition.has("retained_motion"):
			var body: RigidBody2D = rig.bodies()[0]
			body.global_rotation = float(definition.retained_motion.rotation)
			PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
		if definition.has("retained_parts"):
			var rig_bodies: Array = rig.bodies()
			for part: int in range(rig_bodies.size()):
				var motion: Dictionary = definition.retained_parts[part]
				var body: RigidBody2D = rig_bodies[part]
				body.global_transform = Transform2D(float(motion.rotation), motion.position)
				PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
		if definition.has("retained_motion") or definition.has("retained_parts"):
			rig.refresh_observation()
		var item = Equipment.new()
		if not item.configure(rig, run_id, epoch, index, _body_offsets[index],
			int(definition.get("usable_index", loadout.get("usable_index", -1)))):
			last_error = "Physical equipment refused: " + str(definition.model)
			close()
			return false
		_equipment.append(item)
		all_bodies.append_array(rig.bodies())
		sizes.append_array(rig.body_sizes())
		var pilot = WorkbenchControl.new() if definition.has("workbench_options") else Scripted.new()
		pilot.configure(str(definition.model), definition.position, index)
		if definition.has("workbench_options") and definition.get("workbench_control", {}).has("ambient"):
			if not pilot.configure_ambient(definition.workbench_control.ambient, int(definition.instance_id)):
				last_error = "Procedural actor profile refused: " + str(definition.model)
				close()
				return false
		if definition.get("workbench_control", {}).get("policy") == "ambient": _ambient_slots[index] = true
		_scripts.append(pilot)
		_workbench_decision_ticks.append(-1)
		_decision_cost_usec.append(0)
		_decision_total_usec.append(0)
		_actor_accepted.append(0)
		_actor_rejected.append(0)
		_actor_errors.append("")
		_ambient_sensor_cost_usec.append(0)
		_commands.append({})
		_flight_commands.append({})
		_flight_applied.append({})
		_flight_last_step.append({})
		_fallback_reasons.append("not_commanded")
		_button_edges.append([])
		_accepted_buttons.append({})
		_applied_buttons.append({})
		var history := PackedInt64Array()
		history.resize(MAX_LEASE + 1)
		history.fill(-1)
		_issued.append(history)
		if diagnostic_observer.is_valid():
			diagnostic_observer.call("actor_adapters_and_retained_motion",adapters_started,{"slot":index})
	var bridge_started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
	var error: Error = bridge.initialize(space, all_bodies, sizes)
	if error == OK and bridge is WorkbenchBridge:
		error = bridge.configure_instances(_definitions, _rigs, epoch)
	if error != OK:
		last_error = "Rapier bridge refused physical assembly (%d)" % error
		close()
		return false
	if bridge is WorkbenchBridge:
		for index: int in range(_equipment.size()):
			if _equipment[index].body_id > 0:
				_equipment[index].body_id = bridge.proxy_for_body(_equipment[index].body_id - 1)
	if diagnostic_observer.is_valid():
		diagnostic_observer.call("physical_bridge",bridge_started,{"bodies":all_bodies.size(),"actors":_rigs.size()})
	_sequences.resize(_rigs.size())
	_sequences.fill(-1)
	_deadlines.resize(_rigs.size())
	_deadlines.fill(-1)
	_generations.resize(_rigs.size())
	_generations.fill(0)
	_flight_completed_step = bridge.manual_step_count()
	_ambient_completed_physics_step = bridge.manual_step_count()
	_flight_pause_step = _flight_completed_step
	_active = true
	if diagnostic_observer.is_valid():
		diagnostic_observer.call("session_configuration",configuration_started,{"expected_epoch":new_epoch,"bodies":all_bodies.size()})
	return true


func active() -> bool:
	return _active


func is_flight_actor(actor_id: int) -> bool:
	return actor_id >= 0 and actor_id < _definitions.size() \
		and StringName(str(_definitions[actor_id].model)) in Flight.IDS


func set_propulsion_enabled(actor_id: int, enabled: bool) -> bool:
	# Main-thread host/fixture switch, never an extra learned-policy output.
	if not _active or not is_flight_actor(actor_id):
		return false
	cancel_input(actor_id, epoch, StringName(str(_definitions[actor_id].producer)))
	_fallback_reasons[actor_id] = "power_changed"
	return _rigs[actor_id].set_propulsion_enabled(enabled)


func takeover(actor_id: int, expected_epoch: int, producer: StringName) -> bool:
	# Ownership changes revoke issued observations before the replacement source
	# can request a fresh lease. Physical state is not reconstructed here.
	if not _active or actor_id < 0 or actor_id >= _rigs.size() or expected_epoch != epoch \
		or (not WorkbenchCatalog.supports_producer(str(_definitions[actor_id].model), str(producer)) if bridge is WorkbenchBridge else producer not in PRODUCERS or _definitions[actor_id].model == Catalog.PASSIVE_BARREL):
		return false
	if not cancel_input(actor_id, expected_epoch, StringName(str(_definitions[actor_id].producer))):
		return false
	_definitions[actor_id].producer = producer
	if bridge is WorkbenchBridge:
		var control: Dictionary = _workbench_configuration(actor_id)
		control.source = "scripted" if producer == &"demo" else str(producer)
		_definitions[actor_id]["workbench_control"] = control
	_fallback_reasons[actor_id] = "takeover"
	return true


func slot_for_instance(instance_id: int) -> int:
	if not _active or not bridge is WorkbenchBridge: return -1
	for slot: int in range(_definitions.size()):
		if int(_definitions[slot].instance_id) == instance_id: return slot
	return -1


func _workbench_configuration(slot: int) -> Dictionary:
	var result: Dictionary = _definitions[slot].get("workbench_control", WorkbenchCatalog.default_control(str(_definitions[slot].model))).duplicate(true)
	result.source = "scripted" if str(_definitions[slot].producer) == "demo" else str(_definitions[slot].producer)
	result.usable_index = int(_definitions[slot].get("usable_index", result.usable_index))
	return result


func workbench_control(instance_id: int) -> Dictionary:
	var slot := slot_for_instance(instance_id)
	if slot < 0: return {}
	var result := _workbench_configuration(slot)
	var view := _view(slot, false)
	var status := str(result.source)
	if not str(view.fault).is_empty(): status = "faulted"
	elif _suspended: status = "paused"
	elif slot == _manipulated_actor: status = "physically grabbed"
	elif not bool(result.enabled): status = "stopped"
	elif result.source == "policy" and int(view.lease_remaining) == 0: status = "expired" if _fallback_reasons[slot] == "expired" else "waiting"
	result.merge({"instance_id":instance_id, "actor_id":slot, "run_id":run_id, "epoch":epoch,
		"tick":tick, "generation":_generations[slot], "producer":str(_definitions[slot].producer),
		"status":status, "last_sequence":_sequences[slot], "lease_remaining":view.lease_remaining,
		"accepted":_actor_accepted[slot], "rejected":_actor_rejected[slot], "error":_actor_errors[slot],
		"decision_usec":_decision_cost_usec[slot], "total_decision_usec":_decision_total_usec[slot],
		"sensor_usec":_ambient_sensor_cost_usec[slot], "simulation_time_seconds":_completed_time_seconds,
		"diagnostics":_scripts[slot].diagnostics(), "observation":view}, true)
	return result.duplicate(true)


func set_workbench_control(instance_id: int, configuration: Dictionary) -> bool:
	if _workbench_group_applying: return _reject("A group control transaction is completing.")
	var slot := slot_for_instance(instance_id)
	if slot < 0: return _reject("unknown_workbench_instance")
	var error: String = WorkbenchCatalog.control_error(str(_definitions[slot].model), configuration)
	if not error.is_empty(): return _reject(error, slot)
	# A source handoff preserves the actual existing equipment. Changing the
	# starting loadout is an authored prepare operation, never a covert retool.
	if int(configuration.usable_index) != int(_workbench_configuration(slot).usable_index):
		return _reject("Starting equipment changes require authored Apply; takeover preserves the live item.", slot)
	if configuration.policy == "ambient" and not _ambient_slots.has(slot) and _ambient_slots.size() >= WorkbenchCatalog.MAX_AMBIENT_CONTROLLERS:
		return _reject(WorkbenchCatalog.AMBIENT_CAPACITY_ERROR, slot)
	# Prepare the pure adapter before revoking the currently usable producer.
	var replacement: Variant = null
	if configuration.has("ambient"):
		replacement = WorkbenchControl.new()
		replacement.configure(str(_definitions[slot].model), _definitions[slot].position, slot)
		if not replacement.configure_ambient(configuration.ambient, instance_id):
			return _reject("Procedural behaviour configuration refused before handoff.", slot)
	var producer := StringName(WorkbenchCatalog.producer_for(str(configuration.source)))
	if not takeover(slot, epoch, producer): return _reject("takeover_refused", slot)
	if replacement != null: _scripts[slot] = replacement
	_definitions[slot]["workbench_control"] = configuration.duplicate(true)
	if configuration.policy == "ambient": _ambient_slots[slot] = true
	else: _ambient_slots.erase(slot)
	_ambient_peer_tick = -1
	_actor_errors[slot] = ""
	return true



# Two-phase, main-thread-only control admission. No producer is revoked until
# every member and replacement adapter is prepared against one owner identity.
func set_workbench_controls(configurations: Array, expected_run: String, expected_epoch: int) -> bool:
	if _workbench_group_applying or not _active or not bridge is WorkbenchBridge \
		or expected_run != run_id or expected_epoch != epoch \
		or configurations.is_empty() or configurations.size() > WorkbenchCatalog.MAX_AMBIENT_CONTROLLERS:
		return _reject("Invalid or stale Workbench group transaction.")
	var prepared: Array[Dictionary] = []
	var next_ambient_slots := _ambient_slots.duplicate()
	var seen: Dictionary = {}
	for item: Variant in configurations:
		if not item is Dictionary or not item.has_all(["instance_id", "configuration", "expected_configuration"]) \
			or item.size() != 3 or not item.instance_id is int \
			or not item.configuration is Dictionary or not item.expected_configuration is Dictionary:
			return _reject("Malformed Workbench group member.")
		var instance_id: int = item.instance_id
		var slot: int = slot_for_instance(instance_id)
		if slot < 0 or seen.has(instance_id): return _reject("Unknown or repeated Workbench group member.")
		seen[instance_id] = true
		var previous: Dictionary = _workbench_configuration(slot)
		if previous != item.expected_configuration:
			return _reject("A group member changed controller; refresh the staged selection.")
		var configuration: Dictionary = item.configuration.duplicate(true)
		var model: String = str(_definitions[slot].model)
		var error: String = WorkbenchCatalog.control_error(model, configuration)
		if not error.is_empty(): return _reject(error)
		if configuration.policy == "ambient": next_ambient_slots[slot] = true
		else: next_ambient_slots.erase(slot)
		if int(configuration.usable_index) != int(previous.usable_index):
			return _reject("Group assignment cannot change live equipment.")
		var producer: StringName = StringName(WorkbenchCatalog.producer_for(str(configuration.source)))
		if not WorkbenchCatalog.supports_producer(model, str(producer)):
			return _reject("Unsupported group producer.")
		var replacement: Variant = null
		if configuration.has("ambient"):
			replacement = WorkbenchControl.new()
			if not replacement.configure(model, _definitions[slot].position, slot) \
				or not replacement.configure_ambient(configuration.ambient, instance_id):
				return _reject("Group profile refused before any producer changed.")
		prepared.append({"slot":slot, "control":configuration, "producer":producer,
			"previous_producer":StringName(str(_definitions[slot].producer)), "replacement":replacement})
	if next_ambient_slots.size() > WorkbenchCatalog.MAX_AMBIENT_CONTROLLERS:
		return _reject(WorkbenchCatalog.AMBIENT_CAPACITY_ERROR)
	# No await, external callback, or new fallible preparation occurs below.
	# Cancellation notices are delivered only after all configurations are visible.
	_workbench_group_applying = true
	for item: Dictionary in prepared:
		var slot: int = item.slot
		cancel_input(slot, epoch, item.previous_producer, false, false)
		_definitions[slot].producer = item.producer
		if item.replacement != null: _scripts[slot] = item.replacement
		_definitions[slot]["workbench_control"] = item.control
		_actor_errors[slot] = ""
		_fallback_reasons[slot] = "takeover"
	_ambient_peer_tick = -1
	_ambient_slots = next_ambient_slots
	for item: Dictionary in prepared: input_cancelled.emit(int(item.slot), epoch)
	_workbench_group_applying = false
	last_error = ""
	return true


# Bounded owner snapshot, shared across ambient decisions at one physical tick.
# Only public poses, velocities, capabilities and authored affinity tags cross
# the boundary. Private policies, drives, goals and memories are never shared.
func _ambient_peer_values() -> Array:
	if _ambient_peer_tick == tick: return _ambient_peer_observations
	_ambient_peer_observations.clear()
	_ambient_peer_tick = tick
	var limit: int = mini(_rigs.size(), AmbientPerception.MAX_PEER_CANDIDATES)
	var start: int = tick % _rigs.size() if _rigs.size() > limit else 0
	for offset: int in range(limit):
		var slot: int = (start + offset) % _rigs.size()
		if not str(_rigs[slot].fault).is_empty(): continue
		var copied: Dictionary = _rigs[slot].observation()
		if not copied.get("position") is Vector2 or not copied.position.is_finite() \
			or not copied.get("velocity") is Vector2 or not copied.velocity.is_finite(): continue
		var model: String = str(_definitions[slot].model)
		var capabilities: Dictionary = AmbientActuator.capabilities(model)
		var control: Dictionary = _definitions[slot].get("workbench_control", {})
		var tags: Array = control.get("ambient", {}).get("relations", {}).get("tags", []).duplicate()
		_ambient_peer_observations.append({"instance_id":int(_definitions[slot].instance_id),
			"model":model, "run_id":run_id, "epoch":epoch, "tick":tick, "available":true,
			"position":copied.position, "velocity":copied.velocity, "tags":tags,
			"supported":bool(capabilities.get("supported", false)),
			"vertical":bool(capabilities.get("vertical", false))})
	return _ambient_peer_observations


# The host supplies immutable native publications; the decision core never sees
# this owner or the publication object. No buffer is allocated for ordinary
# human/scripted/external/passive scenes.
func ingest_ambient_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	if not _active or not bridge is WorkbenchBridge: return
	# World identity is required even when a profile requests no material IDs.
	# Read only the accepted owner's immutable envelope; do not invent a World
	# generation from a render frame counter, missing cache or wall-clock time.
	if snapshot != null and snapshot.rigid_body_epoch == epoch \
		and snapshot.serial >= 0 and snapshot.tick_index >= 0 \
		and snapshot.render_world_generation >= 0 and snapshot.serial >= _ambient_world_serial \
		and snapshot.render_world_generation >= _ambient_world_generation:
		_ambient_world_generation = int(snapshot.render_world_generation)
		_ambient_world_serial = int(snapshot.serial)
	var needed := false
	for slot: int in _ambient_slots:
		var definition: Dictionary = _definitions[slot]
		var control: Dictionary = definition.workbench_control
		if str(definition.producer) == "policy" and str(control.get("policy", "")) == "ambient" \
			and bool(control.get("enabled", false)) and not AmbientPerception.requests(control.get("ambient", {})).is_empty():
			needed = true
			break
	if not needed:
		if _ambient_sensor_active: _ambient_perception.reset()
		_ambient_sensor_active = false
		_ambient_refresh_requested = false
		return
	var extent: Vector2i = _definitions[0].canvas_extent
	if not _ambient_sensor_active:
		_ambient_sensor_active = _ambient_perception.configure(extent, epoch)
	if _ambient_sensor_active and snapshot != null:
		_ambient_perception.ingest_snapshot(snapshot, extent, epoch)
		if not _ambient_perception.wants_full_refresh(): _ambient_refresh_requested = false


func take_ambient_refresh_request() -> bool:
	if not _ambient_sensor_active or _ambient_refresh_requested or not _ambient_perception.wants_full_refresh(): return false
	_ambient_refresh_requested = true
	return true


func _ambient_environment(slot: int, view: Dictionary, profile: Dictionary) -> Dictionary:
	var begun := Time.get_ticks_usec()
	_ambient_perception.configure(_definitions[slot].canvas_extent, epoch)
	var spatial: Dictionary = {"available":false, "modules":{}}
	var probes: Dictionary = {}
	for module: Dictionary in profile.get("modules", []):
		if bool(module.enabled) and float(module.weight) > 0.0 and str(module.type) == "avoid_ledge":
			var lookahead := float(module.params.lookahead)
			var max_drop := minf(64.0, float(module.params.allowed_drop) + 8.0)
			var key := "%0.9f:%0.9f" % [lookahead, max_drop]
			if not probes.has(key): probes[key] = _rigs[slot].ambient_ledge_observation(lookahead, max_drop, _definitions[slot].canvas_extent)
			var sample: Dictionary = probes[key]
			spatial.modules[str(module.id)] = sample.duplicate(true)
			if not spatial.has("left"):
				spatial["left"] = sample.left.duplicate(true)
				spatial["right"] = sample.right.duplicate(true)
			spatial.available = bool(spatial.available) or bool(sample.available)
	var neighbors: Array = []
	var capabilities: Dictionary = AmbientActuator.capabilities(str(_definitions[slot].model))
	for copied: Dictionary in _ambient_peer_values():
		if int(copied.instance_id) == int(_definitions[slot].instance_id): continue
		var peer: Dictionary = copied.duplicate(true)
		peer["compatible"] = bool(peer.supported) and bool(peer.vertical) == bool(capabilities.get("vertical", false))
		peer.erase("supported")
		peer.erase("vertical")
		neighbors.append(peer)
	var navigation: Dictionary = {"available":false, "reason":"No enabled module requests terrain steering.", "directions":[]}
	for module: Dictionary in profile.get("modules", []):
		if bool(module.enabled) and float(module.weight) > 0.0 and str(module.type) in ["steer_obstacles", "withdraw_obstruction"]:
			navigation = _rigs[slot].ambient_navigation_observation(32.0, _definitions[slot].canvas_extent, bool(capabilities.get("vertical", false)))
			break
	var environment: Dictionary = _ambient_perception.observe(view, _ambient_perception.requests(profile),
		{"capabilities":capabilities,
		"bounds":Rect2(Vector2.ZERO, Vector2(_definitions[slot].canvas_extent)),
		"home":_definitions[slot].position, "spatial":spatial, "neighbors":neighbors,
		"peer_roster_incomplete":_rigs.size() > _ambient_peer_observations.size(),
		"perception":AmbientPerception.settings(profile), "relations":profile.get("relations", {}),
		"regions":profile.get("regions", []),
		"navigation":navigation, "world_generation":_ambient_world_generation,
		"simulation_time_seconds":_completed_time_seconds})
	_ambient_sensor_cost_usec[slot] = Time.get_ticks_usec() - begun
	return environment


func workbench_policy_observation(instance_id: int) -> Dictionary:
	var slot := slot_for_instance(instance_id)
	if slot < 0 or _definitions[slot].producer != &"policy" or not bool(_workbench_configuration(slot).enabled) or _suspended: return {}
	return observation(slot)


func submit_workbench_policy(instance_id: int, command: Dictionary) -> bool:
	var slot := slot_for_instance(instance_id)
	if slot < 0: return _reject("unknown_workbench_instance")
	if command.get("actor_id") != slot: return _reject("wrong_workbench_instance", slot)
	return submit(command, &"policy")


func submit_workbench_action(instance_id: int, action: Dictionary, ports: Dictionary, fire: bool) -> bool:
	var slot := slot_for_instance(instance_id)
	if slot < 0 or _definitions[slot].producer != "human" or not WorkbenchEmitter.valid_ports(ports): return false
	var admitted: Dictionary = {"move":action.get("move", Vector2.ZERO)} if is_flight_actor(slot) else action
	if not submit_local(slot, admitted, &"human", 6): return false
	if Fleet.index_for_id(str(_definitions[slot].model)) >= 0:
		_workbench_ports[slot] = {"ports":ports.duplicate(true), "generation":_generations[slot],
			"sequence":_sequences[slot], "fire":fire}
		_rigs[slot].set_review_boost_held(ports.boost)
	return true


func workbench_actor_state(instance_id: int) -> Dictionary:
	var slot := slot_for_instance(instance_id)
	if slot < 0: return {}
	var rig = _rigs[slot]
	var body: RigidBody2D = rig.bodies()[0]
	var rid := body.get_rid()
	var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var linear: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var angular: float = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	return {"instance_id":instance_id, "model":str(_definitions[slot].model), "position":pose.origin,
		"rotation":pose.get_rotation(), "linear_velocity":linear, "angular_velocity":angular, "mass":body.mass, "inertia":body.inertia,
		"gravity":body.gravity_scale * float(ProjectSettings.get_setting("physics/2d/default_gravity")),
		"force_limit":float(rig._profile.get("fleet_force",0.0)), "torque_limit":float(rig._profile.get("fleet_torque",0.0)),
		"budget":float(_definitions[slot].workbench_options.budget),
		"definition_hash":str(rig._profile.get("fleet_definition_hash","")),
		"control_generation":_generations[slot], "controller":rig._player_controller.observation() if rig._player_controller != null else {},
		"retained_parts":_retained_parts(slot)}


func manipulator() -> RefCounted:
	if _manipulator == null:
		_manipulator = Manipulator.new()
		_manipulator.bind(self)
	return _manipulator


func pick_workbench_part(point: Vector2, presentation: Variant = null, padding: float = 0.0) -> Dictionary:
	if not _active or not bridge is WorkbenchBridge or not point.is_finite(): return {}
	# Match the draw order: the last actor/part is visually above earlier ones.
	for slot: int in range(_rigs.size() - 1, -1, -1):
		var accepted: Variant = null
		if presentation is Dictionary:
			accepted = {}
			var first: int = bridge.actor_body_index(slot)
			for part: int in range(bridge.actor_body_count(slot)):
				var body_slot := first + part
				if body_slot < 0 or body_slot >= bridge._members.size(): continue
				var member: Dictionary = bridge._members[body_slot]
				if member.actor_slot != slot or member.actor_instance_id != _definitions[slot].instance_id or member.part_index != part: continue
				var receipt: Dictionary = presentation.mask_frame.instances.get(int(member.instance_id), {})
				var pose: Variant = presentation.poses.get(body_slot)
				if receipt.get("generation",-1) == member.generation and receipt.get("pose") is Transform2D \
						and receipt.pose.is_finite() and pose is Transform2D and pose.is_finite():
					# Padded mouse aid must not select a fully covered member via
					# adjacent Empty sky. Check that exact accepted material pixel
					# and the same unpadded physical part before enabling the hit.
					if presentation.get("contact_clips",{}).has(body_slot):
						if not preload("res://scripts/workbench_presentation_coherence.gd").contact_point_visible(
								point,presentation.contact_clips[body_slot]): continue
						if padding>0.0 and _rigs[slot].pick_part(point,{part:pose},0.0).is_empty(): continue
					accepted[part] = pose
		var hit: Dictionary = _rigs[slot].pick_part(point, accepted, padding)
		if hit.is_empty(): continue
		var member_index: int = bridge.actor_body_index(slot) + int(hit.part_index)
		if member_index < 0 or member_index >= bridge._members.size(): continue
		var picked_member: Dictionary = bridge._members[member_index]
		hit.merge({"member_id":picked_member.instance_id, "member_generation":picked_member.generation,
			"instance_id":int(_definitions[slot].instance_id), "actor_slot":slot,
			"run_id":run_id, "epoch":epoch, "extent":_definitions[slot].canvas_extent})
		return hit
	return {}


func workbench_grab_body(hit: Dictionary) -> RigidBody2D:
	# RIDs never cross the native worker boundary. Every access revalidates the
	# current session, actor identity and exact live body before returning it.
	if not _active or hit.get("run_id") != run_id or hit.get("epoch") != epoch: return null
	var slot := slot_for_instance(int(hit.get("instance_id", -1)))
	if slot < 0 or slot != int(hit.get("actor_slot", -1)) or not str(_rigs[slot].fault).is_empty(): return null
	var parts: Array = _rigs[slot].bodies()
	var index := int(hit.get("part_index", -1))
	if index < 0 or index >= parts.size() or not bridge is WorkbenchBridge: return null
	var member_index: int = bridge.actor_body_index(slot) + index
	if member_index < 0 or member_index >= bridge._members.size(): return null
	var member: Dictionary = bridge._members[member_index]
	if member.instance_id != hit.get("member_id",-1) or member.generation != hit.get("member_generation",-1) \
			or member.actor_slot != slot or member.part_index != index: return null
	var body: RigidBody2D = parts[index]
	if not is_instance_valid(body) or body.get_instance_id() != int(hit.get("body_identity", -1)) \
		or not body.get_rid().is_valid() or body.freeze: return null
	return body


func claim_workbench_grab(hit: Dictionary) -> bool:
	if _suspended or workbench_grab_body(hit) == null: return false
	if _manipulated_actor >= 0 and _manipulator != null: _manipulator.end_grab("replaced_grab")
	var slot := int(hit.actor_slot)
	if not cancel_input(slot, epoch, StringName(str(_definitions[slot].producer)), true): return false
	_manipulated_actor = slot
	_fallback_reasons[slot] = "physical_grab"
	return true


func release_workbench_grab(hit: Dictionary, reason: String) -> void:
	if not _active or hit.get("run_id") != run_id or hit.get("epoch") != epoch: return
	var slot := slot_for_instance(int(hit.get("instance_id", -1)))
	if slot < 0 or slot != _manipulated_actor: return
	_manipulated_actor = -1
	# Fresh post-release observations are required; a stale policy result or
	# held equipment edge from before the grab must not restart a motor/tool.
	cancel_input(slot, epoch, StringName(str(_definitions[slot].producer)), true)
	_fallback_reasons[slot] = reason


func capture_workbench_assembly(instance_id: int) -> Dictionary:
	var slot := slot_for_instance(instance_id)
	if slot < 0: return {}
	var parts: Array = _retained_parts(slot)
	if parts.is_empty(): return {}
	var definition: Dictionary = _catalogue[slot]
	var rotation: float = float(parts[0].rotation) - float(definition.parts[0].get("angle", 0.0))
	var origin: Vector2 = Vector2(parts[0].position) - Vector2(definition.parts[0].offset).rotated(rotation)
	return {"instance_id":instance_id, "run_id":run_id, "epoch":epoch,
		"model":str(_definitions[slot].model), "position":origin, "rotation":rotation,
		"parts":parts, "geometry":_rigs[slot].manipulation_geometry(),
		"extent":_definitions[slot].canvas_extent, "joint_count":_rigs[slot].physical_joint_count(),
		"pose_error":_rigs[slot].placement_pose_error()}


func _retained_parts(slot: int) -> Array:
	var result: Array = []
	for body: RigidBody2D in _rigs[slot].bodies():
		var rid := body.get_rid()
		var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		result.append({"position":pose.origin, "rotation":pose.get_rotation(),
			"linear_velocity":PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
			"angular_velocity":PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)})
	return result


func adopt_retained_motion() -> void:
	if not bridge is WorkbenchBridge: return
	bridge.retire_provisional_samples()
	for slot: int in range(_definitions.size()):
		var motions: Array = _definitions[slot].get("retained_parts", [])
		if _definitions[slot].has("retained_motion"): motions = [_definitions[slot].retained_motion]
		var actor_bodies: Array = _rigs[slot].bodies()
		for part: int in range(motions.size()):
			var motion: Dictionary = motions[part]
			var body: RigidBody2D = actor_bodies[part]
			body.linear_velocity = motion.linear_velocity
			body.angular_velocity = motion.angular_velocity
			PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, motion.linear_velocity)
			PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, motion.angular_velocity)
	bridge.refresh_all_states()
	for rig in _rigs: rig.refresh_observation()


func pack_workbench_sample() -> Dictionary:
	if not _active or not bridge is WorkbenchBridge: return {}
	var drives: Array[bool] = []
	for slot: int in range(_rigs.size()):
		var rig = _rigs[slot]
		var driven: bool = not rig._action.is_empty() and (rig._last_impulse != Vector2.ZERO or rig._last_torque_impulse != 0.0)
		for part: int in range(rig.bodies().size()):
			var grabbed: bool = slot == _manipulated_actor and _manipulator != null and _manipulator.grabs_part(slot, part)
			drives.append(grabbed or (driven and not rig._detached.has(part)))
	var packet: Dictionary = bridge.pack_sample(drives)
	if packet.is_empty(): return packet
	packet["emitters"] = []
	packet["equipment_frame"] = equipment_frame()
	packet["equipment_requests"] = drain_equipment_requests()
	packet["physical_effects"] = drain_effects()
	if _suspended or tick % WorkbenchEmitter.CADENCE_TICKS != 0: return packet
	for slot: int in _workbench_ports:
		var binding: Dictionary = _workbench_ports[slot]
		if int(_workbench_emitted_at.get(slot,-1)) == tick or _commands[slot].is_empty() or tick >= _deadlines[slot]: continue
		if binding.generation != _generations[slot] or binding.sequence != _sequences[slot]: continue
		_workbench_emitted_at[slot] = tick
		var range_value: Dictionary = bridge.actor_proxy_range(slot)
		var identity: Dictionary = {"actor_slot":slot, "instance_id":_definitions[slot].instance_id,
			"session":packet.session, "epoch":epoch, "generation":binding.generation, "sequence":binding.sequence,
			"tick":tick, "first_proxy":range_value.first_proxy, "count":range_value.count}
		packet.emitters.append_array(WorkbenchEmitter.intents(_rigs[slot], bridge.body_transform(_body_offsets[slot]), binding, identity))
	return packet


func apply_workbench_results(snapshot_serial: int, packet: Dictionary) -> int:
	if not _active or not bridge is WorkbenchBridge: return 0
	return bridge.apply_packet(snapshot_serial, packet)


func bodies() -> Array[RigidBody2D]:
	var result: Array[RigidBody2D] = []
	for rig in _rigs:
		result.append_array(rig.bodies())
	return result


func observation(actor_id: int) -> Dictionary:
	return _view(actor_id, true)


func _view(actor_id: int, issue: bool) -> Dictionary:
	if not _active or actor_id < 0 or actor_id >= _rigs.size():
		return {}
	var result: Dictionary = _rigs[actor_id].observation()
	var faulted: bool = not str(result.get("fault", "")).is_empty()
	result.merge({"version": VERSION, "representation": "articulated-rapier",
		"run_id": run_id, "actor_id": actor_id, "epoch": epoch, "tick": tick,
		"observation_id": _observation_id(actor_id, tick),
		"model": str(_definitions[actor_id].model), "producer": str(_definitions[actor_id].producer),
		"profile_version": Catalog.VERSION, "control_mode": "wire",
		"lease_remaining": 0 if faulted else maxi(0, _deadlines[actor_id] - tick),
		"last_sequence": _sequences[actor_id], "suspended": _suspended or faulted}, true)
	result["control_generation"] = _generations[actor_id]
	result["pending_input_edges"] = _button_edges[actor_id].size()
	if bridge is WorkbenchBridge:
		result["instance_id"] = int(_definitions[actor_id].instance_id)
		result["controller_enabled"] = bool(_workbench_configuration(actor_id).enabled)
		result["policy_adapter"] = str(_definitions[actor_id].get("workbench_control", {}).get("policy", "fixture"))
		result["simulation_time_seconds"] = _completed_time_seconds
		if not result.controller_enabled: result.suspended = true
	result["equipment"] = _equipment[actor_id].observation()
	result["cell_patch"] = result.equipment.get("cell_patch", {}).duplicate(true)
	if is_flight_actor(actor_id):
		result["action_profile"] = Flight.ACTION_PROFILE
		result["profile_version"] = Flight.VERSION
		result["control_mode"] = Flight.ACTION_PROFILE
		result.flight["command"] = _flight_commands[actor_id].duplicate(true)
		result.flight["applied"] = _flight_applied[actor_id].duplicate(true)
		result.flight["last_step"] = _flight_last_step[actor_id].duplicate(true)
		result.flight["command_live"] = not _suspended and not faulted and not _commands[actor_id].is_empty() and tick < _deadlines[actor_id]
		result.flight["fallback_reason"] = _fallback_reasons[actor_id]
		result.flight["step_fault"] = _flight_step_fault
		if _suspended or faulted:
			result.flight["mode"] = "suspended"
	if issue and not faulted and not bool(result.suspended):
		_issued[actor_id][tick % (MAX_LEASE + 1)] = tick
	return result.duplicate(true)


func _observation_id(actor_id: int, observed: int) -> String:
	return "%s:%d:%d:%d:%d" % [run_id, epoch, actor_id, _generations[actor_id], observed]


static func make_command(view: Dictionary, sequence: int, action: Dictionary, lease_ticks: int = 12) -> Dictionary:
	var copied: Dictionary = action.duplicate(true)
	var item: Dictionary = view.get("equipment", {})
	if not item.is_empty():
		# The existing M/N/U controls are local shorthand for exactly the same
		# observed equipment identity; raw external packets still carry it.
		if not copied.has("equipment") and (copied.has("tool") \
			or copied.has("release_usable") or copied.has("attach_usable")):
			copied["equipment"] = {"trigger": bool(copied.get("tool", false)),
				"drop": bool(copied.get("release_usable", false)), "attach": bool(copied.get("attach_usable", false)),
				"aim": copied.get("aim", Vector2.ZERO), "power": copied.get("effort", 0.7)}
		if copied.get("equipment") is Dictionary:
			for key: String in ["usable_index", "instance_id", "equipment_epoch"]:
				if not copied.equipment.has(key):
					copied.equipment[key] = item.get(key)
	return {"version": VERSION, "kind": "physical_wire_action", "run_id": view.get("run_id", ""),
		"actor_id": view.get("actor_id", -1), "epoch": view.get("epoch", -1),
		"sequence": sequence, "observed_tick": view.get("tick", -1),
		"observation_id": view.get("observation_id", ""), "lease_ticks": lease_ticks,
		"action": copied}


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func normalized_action(value: Variant) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return {}
	var result: Dictionary = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "effort": 0.7,
		"trim": 0.0, "reel": 0.0, "primary": false, "secondary": false,
		"auxiliary": false, "tool": false, "release_usable": false, "attach_usable": false, "equipment": {}}
	for key: Variant in value:
		if not key is String and not key is StringName:
			return {}
		var name: String = str(key)
		if name not in ACTION_KEYS:
			return {}
		var item: Variant = value[key]
		if name == "equipment":
			var equipment_action: Dictionary = Equipment.normalized_action(item)
			if equipment_action.is_empty():
				return {}
			result[name] = equipment_action
		elif name in ["move", "aim"]:
			if item is Array and item.size() == 2:
				if not (item[0] is int or item[0] is float) or not (item[1] is int or item[1] is float):
					return {}
				item = Vector2(float(item[0]), float(item[1]))
			if not item is Vector2 or not item.is_finite():
				return {}
			result[name] = item.limit_length(1.0)
		elif name in ["effort", "trim", "reel"]:
			if not (item is int or item is float) or not is_finite(float(item)):
				return {}
			result[name] = clampf(float(item), 0.0 if name == "effort" else -1.0, 1.0)
		else:
			if not item is bool:
				return {}
			result[name] = item
	return result


static func normalized_flight_action(value: Variant) -> Dictionary:
	# This new profile is deliberately closed to legacy effort, trim and ability
	# outputs. Its version-2 envelope retains the original ownership fences.
	if not value is Dictionary or value.size() != 1 or not value.has("move"):
		return {}
	var move: Variant = value.move
	if move is Array and move.size() == 2:
		if not (move[0] is int or move[0] is float) or not (move[1] is int or move[1] is float):
			return {}
		for component: Variant in move:
			if not is_finite(float(component)) or absf(float(component)) > 1.0:
				return {}
		move = Vector2(float(move[0]), float(move[1]))
	if not move is Vector2 or not move.is_finite() or absf(move.x) > 1.0 or absf(move.y) > 1.0:
		return {}
	return {"move": move.limit_length(1.0)}


func submit(command: Variant, producer: StringName = &"policy") -> bool:
	if not _active or _suspended or not command is Dictionary or command.size() != COMMAND_KEYS.size():
		return _reject("command_schema_or_suspended")
	for key: Variant in command:
		if str(key) not in COMMAND_KEYS:
			return _reject("unknown_command_field")
	if not _integer(command.get("version"), VERSION, VERSION) or command.get("kind") != "physical_wire_action":
		return _reject("command_version")
	if not _integer(command.get("actor_id"), 0, _rigs.size() - 1):
		return _reject("actor_id")
	var actor_id: int = int(command.actor_id)
	if actor_id == _manipulated_actor: return _reject("actor_physically_grabbed", actor_id)
	if _definitions[actor_id].model == Catalog.PASSIVE_BARREL or _definitions[actor_id].producer == &"passive":
		return _reject("passive_prop", actor_id)
	if bridge is WorkbenchBridge and not bool(_workbench_configuration(actor_id).enabled): return _reject("controller_stopped", actor_id)
	if producer != StringName(str(_definitions[actor_id].producer)):
		return _reject("producer", actor_id)
	if command.get("run_id") != run_id or not _integer(command.get("epoch"), epoch, epoch):
		return _reject("run_or_epoch", actor_id)
	if not str(_rigs[actor_id].fault).is_empty():
		return _reject("actor_fault", actor_id)
	if not _integer(command.get("sequence"), 0, 9007199254740991) \
		or int(command.sequence) <= _sequences[actor_id]:
		return _reject("sequence", actor_id)
	if not _integer(command.get("observed_tick"), maxi(0, tick - MAX_LEASE), tick) \
		or not _integer(command.get("lease_ticks"), 1, MAX_LEASE):
		return _reject("lease", actor_id)
	var observed: int = int(command.observed_tick)
	if observed + int(command.lease_ticks) <= tick:
		return _reject("expired_observation", actor_id)
	if _issued[actor_id][observed % (MAX_LEASE + 1)] != observed \
		or command.get("observation_id") != _observation_id(actor_id, observed):
		return _reject("observation_not_issued", actor_id)
	var flight: bool = is_flight_actor(actor_id)
	var action: Dictionary = normalized_flight_action(command.get("action")) if flight else normalized_action(command.get("action"))
	if action.is_empty():
		return _reject("action", actor_id)
	var equipment_action: Dictionary = action.get("equipment", {})
	if not equipment_action.is_empty():
		if not _equipment[actor_id].matches(action.equipment):
			return _reject("equipment_epoch_or_instance", actor_id)
		if not _equipment[actor_id].can_select(int(action.equipment.usable_index)):
			return _reject("selection_requires_held_body", actor_id)
	elif bool(action.get("tool", false)) or bool(action.get("release_usable", false)) or bool(action.get("attach_usable", false)):
		return _reject("equipment_identity_required", actor_id)
	var edges: Array = []
	for button: String in BUTTON_KEYS:
		if button in ["tool", "release_usable", "attach_usable"]:
			continue
		if bool(action.get(button, false)) != bool(_accepted_buttons[actor_id].get(button, false)):
			edges.append({"button": button, "pressed": bool(action.get(button, false))})
	for button: String in Equipment.BUTTON_KEYS:
		var key: String = "equipment_" + button
		if bool(equipment_action.get(button, false)) != bool(_accepted_buttons[actor_id].get(key, false)):
			edges.append({"button": key, "pressed": bool(equipment_action.get(button, false))})
	if _button_edges[actor_id].size() + edges.size() > MAX_BUTTON_EDGES:
		return _reject("button_edge_capacity", actor_id)
	_button_edges[actor_id].append_array(edges)
	for button: String in BUTTON_KEYS:
		_accepted_buttons[actor_id][button] = action.get(button, false)
	for button: String in Equipment.BUTTON_KEYS:
		_accepted_buttons[actor_id]["equipment_" + button] = bool(equipment_action.get(button, false))
	_sequences[actor_id] = int(command.sequence)
	_deadlines[actor_id] = observed + int(command.lease_ticks)
	_commands[actor_id] = action
	if flight:
		_flight_commands[actor_id] = {"requested_action": command.action.duplicate(true),
			"admitted_action": action.duplicate(true), "sequence": int(command.sequence),
			"observed_tick": observed, "admitted_tick": tick}
		_fallback_reasons[actor_id] = "none"
	accepted_commands += 1
	_actor_accepted[actor_id] += 1
	_actor_errors[actor_id] = ""
	return true


func _reject(reason: String, actor_id: int = -1) -> bool:
	last_error = reason
	rejected_commands += 1
	if actor_id >= 0 and actor_id < _actor_rejected.size():
		_actor_rejected[actor_id] += 1
		_actor_errors[actor_id] = reason
	return false


func submit_local(actor_id: int, action: Dictionary, producer: StringName, lease: int = 6) -> bool:
	var view: Dictionary = observation(actor_id)
	if view.is_empty():
		return false
	return submit(make_command(view, _sequences[actor_id] + 1, action, lease), producer)


func cancel_input(actor_id: int, expected_epoch: int, producer: StringName, preserve_ambient: bool = false, notify_owner: bool = true) -> bool:
	if not _active or actor_id < 0 or actor_id >= _rigs.size() or expected_epoch != epoch \
		or producer != StringName(str(_definitions[actor_id].producer)):
		return false
	if actor_id == _manipulated_actor:
		_manipulated_actor = -1
		if _manipulator != null: _manipulator.invalidate("input_cancelled")
	_capture_flight_step(actor_id)
	_commands[actor_id] = {}
	_flight_commands[actor_id] = {}
	_flight_applied[actor_id] = {}
	_fallback_reasons[actor_id] = "cancelled"
	_button_edges[actor_id].clear()
	_accepted_buttons[actor_id].clear()
	_applied_buttons[actor_id].clear()
	_deadlines[actor_id] = -1
	_generations[actor_id] += 1
	_equipment[actor_id].cancel(_generations[actor_id])
	_issued[actor_id].fill(-1)
	_effects = _effects.filter(func(effect: Dictionary) -> bool: return int(effect.actor_slot) != actor_id)
	_workbench_ports.erase(actor_id)
	_rigs[actor_id].cancel()
	if bridge is WorkbenchBridge: _scripts[actor_id].cancel(preserve_ambient)
	else: _scripts[actor_id].cancel()
	_workbench_decision_ticks[actor_id] = -1
	# A desktop cellular owner may already hold a copied effect packet. Revoking
	# only this session's queue would leave that packet live after focus loss,
	# pause or lease expiry. The main-thread host fences its worker queue too.
	if notify_owner: input_cancelled.emit(actor_id, epoch)
	return true


func set_suspended(value: bool) -> void:
	if value and _manipulator != null: _manipulator.end_grab("paused")
	if value == _suspended:
		return
	if not value and _has_flight:
		if not _flight_step_fault.is_empty():
			return
		if bridge.manual_step_count() != _flight_pause_step:
			_fault_flight_step("flight_physics_advanced_while_suspended")
			return
	if not value and (_has_flight or bridge is WorkbenchBridge):
		# Paused views cannot become authority merely because the tick stayed
		# unchanged. Apply the existing flight lifecycle fence to every composed
		# Workbench producer before issuing a fresh post-resume observation.
		for index: int in range(_rigs.size()):
			if is_flight_actor(index) or bridge is WorkbenchBridge:
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)), true)
				_fallback_reasons[index] = "resumed"
	_suspended = value
	_ambient_completed_physics_step = bridge.manual_step_count()
	if value:
		_flight_pause_step = bridge.manual_step_count()
		_effects.clear()
		for index: int in range(_rigs.size()):
			cancel_input(index, epoch, StringName(str(_definitions[index].producer)), true)
			_fallback_reasons[index] = "suspended"
		if _flight_pause_step == _flight_completed_step:
			_flight_prepared = false


func advance(delta: float) -> void:
	if not _active or _suspended:
		return
	if _has_flight:
		if bridge.manual_step_count() != _flight_completed_step:
			_fault_flight_step("flight_requires_completion_before_advance")
			return
		if _flight_prepared:
			last_error = "flight_step_already_prepared"
			return
	if not is_finite(delta) or delta <= 0.0:
		for index: int in range(_rigs.size()):
			if is_flight_actor(index):
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
				_fallback_reasons[index] = "invalid_cadence"
				last_error = "flight_requires_fixed_60_hz"
		return
	if _has_flight:
		_flight_prepared = true
	# Collect all copied views before accepting any producer output. The same
	# main-thread owner schedules bounded local decisions; no inference blocks
	# the native cellular owner and no UI visibility controls these producers.
	var script_actions: Array = []
	for index: int in range(_rigs.size()):
		if not str(_rigs[index].fault).is_empty(): continue
		if index == _manipulated_actor: continue
		var producer: String = str(_definitions[index].producer)
		var period: int = DECISION_TICKS
		var ambient_profile: Dictionary = {}
		if bridge is WorkbenchBridge:
			var control: Dictionary = _workbench_configuration(index)
			if not bool(control.enabled): continue
			if producer != "demo" and not (producer == "policy" and control.policy in ["fixture", "ambient"]): continue
			if producer == "policy" and control.policy == "ambient": ambient_profile = control.ambient
			period = int(control.decision_ticks)
			if _workbench_decision_ticks[index] >= 0 and tick - _workbench_decision_ticks[index] < period: continue
		else:
			if producer != "demo" or tick % period != 0: continue
		var view: Dictionary = workbench_policy_observation(int(_definitions[index].instance_id)) if bridge is WorkbenchBridge and producer == "policy" else observation(index)
		if not ambient_profile.is_empty(): view["ambient_environment"] = _ambient_environment(index, view, ambient_profile)
		var begin_usec := Time.get_ticks_usec()
		var action: Dictionary = _scripts[index].next_action(view, delta * period)
		_decision_cost_usec[index] = Time.get_ticks_usec() - begin_usec
		_decision_total_usec[index] += _decision_cost_usec[index]
		_workbench_decision_ticks[index] = tick
		if not action.is_empty():
			script_actions.append({"id":index, "producer":producer,
				"command":make_command(view, _sequences[index] + 1, action, mini(MAX_LEASE, period + 6))})
	for output: Dictionary in script_actions:
		if bridge is WorkbenchBridge and output.producer == "policy":
			submit_workbench_policy(int(_definitions[int(output.id)].instance_id), output.command)
		else:
			submit(output.command, StringName(str(output.producer)))
	_effects.clear()
	for index: int in range(_rigs.size()):
		if is_flight_actor(index) and absf(delta - Flight.FIXED_DELTA) > 0.000000001:
			cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
			_fallback_reasons[index] = "invalid_cadence"
			last_error = "flight_requires_fixed_60_hz"
			continue
		if not str(_rigs[index].fault).is_empty() or _deadlines[index] < tick + 1:
			if not _commands[index].is_empty():
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
				_fallback_reasons[index] = "fault" if not str(_rigs[index].fault).is_empty() else "expired"
		var command: Dictionary = _commands[index].duplicate(true)
		if not command.is_empty() and not is_flight_actor(index):
			# Preserve a quick press and release across physical samples. Each
			# button changes at most once per tick; cancellation never drains it.
			var changed: Dictionary = {}
			while not _button_edges[index].is_empty():
				var edge: Dictionary = _button_edges[index][0]
				if changed.has(edge.button):
					break
				_button_edges[index].pop_front()
				_applied_buttons[index][edge.button] = edge.pressed
				changed[edge.button] = true
			for button: String in BUTTON_KEYS:
				command[button] = bool(_applied_buttons[index].get(button, false))
			if not command.equipment.is_empty():
				for button: String in Equipment.BUTTON_KEYS:
					command.equipment[button] = bool(_applied_buttons[index].get("equipment_" + button, false))
		_equipment[index].pre_advance(command.get("equipment", {}), command.get("aim", Vector2.ZERO), not command.is_empty())
		_rigs[index].advance(command, delta, not command.is_empty())
		if is_flight_actor(index):
			var view: Dictionary = _rigs[index].observation()
			_flight_applied[index] = {"run_id": run_id, "epoch": epoch, "actor_id": index,
				"producer": str(_definitions[index].producer), "control_generation": _generations[index],
				"sequence": _sequences[index], "observed_tick": _flight_commands[index].get("observed_tick", -1),
				"step_tick": tick, "physics_step": _flight_completed_step + 1,
				"controller": view.flight.controller.duplicate(true), "action": view.action.duplicate(true)} \
				if not command.is_empty() and str(view.fault).is_empty() and bool(view.flight.controller.valid) else {}
		_equipment[index].advance(command.get("equipment", {}), delta, tick, _generations[index],
			_deadlines[index], not command.is_empty() and str(_rigs[index].fault).is_empty())
		for request: Dictionary in _rigs[index].drain_effects():
			if _effects.size() >= _rigs.size():
				break
			var effect: Dictionary = request.duplicate(true)
			effect["source_body_id"] = bridge.proxy_for_body(_body_offsets[index] + int(effect.get("source_part", 0))) if bridge is WorkbenchBridge else _body_offsets[index] + int(effect.get("source_part", 0)) + 1
			_effects.append(effect)
	# This is the existing authoritative prepare-before-Rapier-step boundary.
	# The spring is never advanced by UI frames or by the native cell worker.
	if _manipulator != null: _manipulator.advance(delta)


func _capture_flight_step(actor_id: int) -> void:
	# Cancellation after the native step must retain the consumed command's
	# identity, even if a new producer or generation takes over before completion.
	if is_flight_actor(actor_id) and not _flight_applied[actor_id].is_empty() \
		and bridge.manual_step_count() == int(_flight_applied[actor_id].physics_step):
		_flight_last_step[actor_id] = _flight_applied[actor_id].duplicate(true)


func _fault_flight_step(reason: String) -> void:
	_flight_step_fault = reason
	last_error = reason
	set_suspended(true)
	for index: int in range(_rigs.size()):
		if is_flight_actor(index):
			cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
			_fallback_reasons[index] = "step_fault"


func complete_step() -> void:
	if not _active:
		return
	if _has_flight:
		if not _flight_step_fault.is_empty():
			return
		var actual_step: int = bridge.manual_step_count()
		if _suspended and actual_step != _flight_pause_step:
			_fault_flight_step("flight_physics_advanced_while_suspended")
			return
		if actual_step == _flight_completed_step:
			last_error = "flight_step_not_completed"
			return
		if actual_step != _flight_completed_step + 1 or not _flight_prepared:
			_fault_flight_step("flight_unexpected_physics_step")
			return
	elif _suspended:
		return
	if _active:
		tick += 1
		var completed_physics_step: int = bridge.manual_step_count()
		# Actual completed fixed Rapier steps, never requested delta or wall time.
		_completed_time_seconds += maxi(0, completed_physics_step - _ambient_completed_physics_step) * bridge.fixed_delta()
		_ambient_completed_physics_step = completed_physics_step
		for index: int in range(_rigs.size()):
			_capture_flight_step(index)
			_rigs[index].complete_step()
			_rigs[index].refresh_observation()
			# Fault quarantine retires both unconsumed input and copied tool work.
			# Healthy actors keep their separate leases and continue the session.
			if not str(_rigs[index].fault).is_empty() and not _commands[index].is_empty():
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
				_fallback_reasons[index] = "fault"
			elif (is_flight_actor(index) or bridge is WorkbenchBridge) and not _commands[index].is_empty() and tick >= _deadlines[index]:
				# Retire at the completed lease boundary, before a queued reply can
				# extend a pre-expiry observation into a new period of authority.
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
				_fallback_reasons[index] = "expired"
		if _has_flight:
			_flight_completed_step = bridge.manual_step_count()
			_flight_prepared = false


func drain_effects() -> Array:
	var result: Array = _effects.duplicate(true)
	_effects.clear()
	return result


func equipment_frame() -> Dictionary:
	var actors: Array = []
	var devices: Array = []
	if _active:
		for index: int in range(_rigs.size()):
			var parts: Array = []
			for part: Dictionary in _rigs[index].observation().get("parts", []):
				parts.append({"body_id": _body_offsets[index] + int(part.index) + 1,
					"position": part.position, "rotation": part.rotation, "half_extents": Vector2(part.size) * 0.5})
			if bridge is WorkbenchBridge: parts = bridge.equipment_parts(index)
			var frame: Dictionary = _equipment[index].frame(_generations[index], tick, _deadlines[index],
				not _suspended and str(_rigs[index].fault).is_empty(), parts)
			if not frame.is_empty():
				actors.append(frame)
			var device: Dictionary = _equipment[index].device_frame()
			if not device.is_empty():
				devices.append(device)
	return {"version": Equipment.VERSION, "run_id": run_id, "epoch": epoch, "tick": tick,
		"suspended": _suspended or not _active, "actors": actors, "devices": devices}


func drain_equipment_requests() -> Array:
	var result: Array = []
	for item in _equipment:
		result.append_array(item.drain_requests())
	return result.duplicate(true)


func reject_equipment_requests(requests: Array, reason: String = "worker_admission") -> void:
	for item in _equipment:
		item.reject_requests(requests, reason)


func accept_equipment_feedback(snapshot_value: Dictionary) -> int:
	if not _active or snapshot_value.get("run_id") != run_id or snapshot_value.get("epoch") != epoch:
		return 0
	var accepted: int = 0
	for receipt: Variant in snapshot_value.get("receipts", []):
		if not receipt is Dictionary or not _integer(receipt.get("actor_id"), 0, _equipment.size() - 1):
			continue
		var index: int = int(receipt.actor_id)
		if _suspended or not str(_rigs[index].fault).is_empty():
			continue
		if _equipment[index].accept_receipt(receipt, _generations[index], tick, _deadlines[index]):
			accepted += 1
	for row: Variant in snapshot_value.get("actors", []):
		if row is Dictionary and _integer(row.get("actor_id"), 0, _equipment.size() - 1):
			var index: int = int(row.actor_id)
			_equipment[index].accept_readback(row, snapshot_value, _generations[index])
	return accepted


func render_parts(display_frame: Dictionary = {}, presentation_poses: Dictionary = {},
		require_mask_receipt: bool = false) -> Array:
	var result: Array = []
	# Direct callers historically use render_parts() for geometry inspection
	# without a display receipt. Preserve that API. Main's Workbench overlay
	# explicitly opts into strict validation; ONLY that path can be rendered
	# ahead of a material texture and must never use live fallback on refusal.
	var strict_workbench: bool = require_mask_receipt and bridge is WorkbenchBridge
	var workbench_frame_ok: bool = true
	if strict_workbench:
		workbench_frame_ok = display_frame.get("session",-1) == bridge._session \
			and display_frame.get("epoch",-1) == bridge._epoch \
			and display_frame.get("instances") is Dictionary
	for index: int in range(_rigs.size()):
		var parts: Array = _catalogue[index].parts
		var actor_bodies: Array[RigidBody2D] = _rigs[index].bodies()
		var flight: Dictionary = _view(index, false).get("flight", {}) if is_flight_actor(index) else {}
		for part_index: int in range(actor_bodies.size()):
			var body: RigidBody2D = actor_bodies[part_index]
			var body_index: int = _body_offsets[index]+part_index
			# Missing/stale body receipts suppress this overlay part. Only Main
			# may admit an optional visual-only live transform after clearance.
			var physical_pose: Transform2D
			if strict_workbench:
				if not workbench_frame_ok or body_index >= bridge._members.size():
					continue
				var member: Dictionary = bridge._members[body_index]
				var instance: Dictionary = display_frame.instances.get(int(member.instance_id),{})
				if instance.get("generation",-1) != member.generation \
						or not instance.get("pose") is Transform2D:
					continue
				physical_pose = instance.pose
				if not physical_pose.is_finite():
					continue
				if presentation_poses.has(body_index):
					var candidate: Variant = presentation_poses[body_index]
					if candidate is Transform2D and candidate.is_finite():
						physical_pose = candidate
			else:
				physical_pose = (
					presentation_poses[body_index] if presentation_poses.has(body_index)
					else (bridge.display_pose(body_index,display_frame)
						if bridge is WorkbenchBridge else bridge.body_transform(body_index)))
			if str(parts[part_index].get("shape","rectangle"))=="rectangle_union":
				var shape_index: int=0
				for child in body.get_children():
					if not child is CollisionShape2D or not child.shape is RectangleShape2D: continue
					result.append({"actor_id":index,"part_id":str(parts[part_index].id) if shape_index==0 else "%s_shape_%d" % [parts[part_index].id,shape_index],
						"physical_part_id":str(parts[part_index].id),"physical_body_index":_body_offsets[index]+part_index,
						"markings":_rigs[index]._profile.get("fleet_markings",""),
						"transform":physical_pose*child.transform,"size":child.shape.size,"color":parts[part_index].color,"shape":"rectangle"})
					shape_index+=1
				continue
			var shape: Shape2D = body.get_child(0).shape
			var dimensions: Vector2 = Vector2(shape.radius * 2.0, shape.radius * 2.0) if shape is CircleShape2D else shape.size
			var presented: Dictionary = {"actor_id": index, "part_id": str(parts[part_index].id),
				# Preserve the direct-geometry branch's historical metadata. The
				# explicit association below serves only Water layer composition.
				"water_body_index": body_index,
				"transform": physical_pose,
				"size": dimensions, "color": parts[part_index].color,
				"shape": "circle" if shape is CircleShape2D else "rectangle"}
			if _rigs[index]._profile.has("fleet_markings"): presented["markings"] = _rigs[index]._profile.fleet_markings
			if not flight.is_empty() and part_index == 0:
				var controller: Dictionary = flight.get("controller", {})
				presented["flight_force"] = controller.get("applied_force", Vector2.ZERO)
				presented["flight_intent"] = controller.get("desired_velocity", Vector2.ZERO)
				presented["flight_live"] = bool(flight.get("command_live", false))
			result.append(presented)
	return result


func snapshot() -> Dictionary:
	var actors: Array = []
	for index: int in range(_rigs.size()):
		actors.append(_view(index, false))
	return {"version": VERSION, "run_id": run_id, "epoch": epoch, "tick": tick,
		"representation": "articulated-rapier", "active": _active, "suspended": _suspended,
		"actor_count": _rigs.size(), "body_count": bodies().size(), "actors": actors,
		"accepted_commands": accepted_commands, "rejected_commands": rejected_commands,
		"last_error": last_error}


func close() -> void:
	if _manipulator != null: _manipulator.end_grab("session_closed")
	_manipulated_actor = -1
	_active = false
	_ambient_perception.reset()
	_ambient_sensor_active = false
	_ambient_refresh_requested = false
	_ambient_sensor_cost_usec.clear()
	_ambient_slots.clear()
	_completed_time_seconds = 0.0
	_ambient_completed_physics_step = 0
	_ambient_world_generation = -1
	_ambient_world_serial = -1
	_ambient_peer_tick = -1
	_ambient_peer_observations.clear()
	_workbench_group_applying = false
	bridge.shutdown()
	for rig in _rigs:
		if is_instance_valid(rig):
			rig.close()
			rig.free()
	_rigs.clear()
	_scripts.clear()
	_workbench_decision_ticks.clear()
	_decision_cost_usec.clear()
	_decision_total_usec.clear()
	_actor_accepted.clear()
	_actor_rejected.clear()
	_actor_errors.clear()
	_equipment.clear()
	_definitions.clear()
	_catalogue.clear()
	_body_offsets.clear()
	_sequences.clear()
	_deadlines.clear()
	_generations.clear()
	_commands.clear()
	_flight_commands.clear()
	_flight_applied.clear()
	_flight_last_step.clear()
	_has_flight = false
	_flight_prepared = false
	_flight_step_fault = ""
	_fallback_reasons.clear()
	_button_edges.clear()
	_accepted_buttons.clear()
	_applied_buttons.clear()
	_issued.clear()
	_effects.clear()
	_workbench_ports.clear()
	_workbench_emitted_at.clear()


func _exit_tree() -> void:
	close()
