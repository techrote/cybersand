class_name CyberPhysicalActorSession
extends Node2D

signal input_cancelled(actor_id: int, actor_epoch: int)

# ACT-004 main-thread owner. Only copied commands/observations/effects cross its
# boundary. The native cellular worker never receives these nodes or RIDs.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Scripted = preload("res://scripts/physical_actor_script.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const Flight = preload("res://scripts/physical_flight_profile.gd")
const MAX_ACTORS: int = 8
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
var _rigs: Array = []
var _scripts: Array = []
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
var accepted_commands: int = 0
var rejected_commands: int = 0


static func valid_definitions(definitions: Array) -> bool:
	if definitions.is_empty() or definitions.size() > MAX_ACTORS:
		return false
	var parts: int = 0
	for value: Variant in definitions:
		if not value is Dictionary:
			return false
		var model := StringName(str(value.get("model", "")))
		if not Catalog.has_rig(model) or StringName(str(value.get("producer", ""))) not in PRODUCERS:
			return false
		if not value.get("position") is Vector2 or not value.position.is_finite():
			return false
		if value.position.x < 0.0 or value.position.y < 0.0 or value.position.x >= 1024.0 or value.position.y >= 1024.0:
			return false
		var prepared: Dictionary = Equipment.definition(Catalog.entry(model), Loadouts.entry(model))
		if prepared.is_empty() or not _integer(value.get("usable_index", Loadouts.entry(model).get("usable_index", -1)), -1, 31):
			return false
		if model in Flight.IDS and int(value.get("usable_index", -1)) != -1:
			return false
		var count: int = prepared.parts.size()
		if count < 1 or count > MAX_PARTS:
			return false
		parts += count
	return parts <= CyberRigidBodyCoupling.MAX_BODIES


func configure(definitions: Array, space: RID, new_epoch: int = 1) -> bool:
	if _active or not is_inside_tree() or not valid_definitions(definitions) or new_epoch < 1:
		last_error = "Invalid physical actor configuration or live owner"
		return false
	epoch = new_epoch
	tick = 0
	_suspended = false
	_has_flight = false
	_flight_prepared = false
	_flight_step_fault = ""
	accepted_commands = 0
	rejected_commands = 0
	last_error = ""
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_definitions = definitions.duplicate(true)
	var all_bodies: Array[RigidBody2D] = []
	var sizes := PackedVector2Array()
	for index: int in range(definitions.size()):
		var definition: Dictionary = definitions[index]
		_has_flight = _has_flight or StringName(str(definition.model)) in Flight.IDS
		var loadout: Dictionary = Loadouts.entry(StringName(str(definition.model)))
		var data: Dictionary = Equipment.definition(Catalog.entry(StringName(str(definition.model))), loadout)
		_catalogue.append(data)
		var rig = Rig.new()
		add_child(rig)
		_body_offsets.append(all_bodies.size())
		_rigs.append(rig)
		if rig.configure(data, definition.position, index, epoch) != OK:
			last_error = "Physical rig refused: " + str(definition.model)
			close()
			return false
		var item = Equipment.new()
		if not item.configure(rig, run_id, epoch, index, _body_offsets[index],
			int(definition.get("usable_index", loadout.get("usable_index", -1)))):
			last_error = "Physical equipment refused: " + str(definition.model)
			close()
			return false
		_equipment.append(item)
		all_bodies.append_array(rig.bodies())
		sizes.append_array(rig.body_sizes())
		var pilot = Scripted.new()
		pilot.configure(StringName(str(definition.model)), definition.position, index)
		_scripts.append(pilot)
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
	var error: Error = bridge.initialize(space, all_bodies, sizes)
	if error != OK:
		last_error = "Rapier bridge refused physical assembly (%d)" % error
		close()
		return false
	_sequences.resize(_rigs.size())
	_sequences.fill(-1)
	_deadlines.resize(_rigs.size())
	_deadlines.fill(-1)
	_generations.resize(_rigs.size())
	_generations.fill(0)
	_flight_completed_step = bridge.manual_step_count()
	_flight_pause_step = _flight_completed_step
	_active = true
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
		or producer not in PRODUCERS:
		return false
	if not cancel_input(actor_id, expected_epoch, StringName(str(_definitions[actor_id].producer))):
		return false
	_definitions[actor_id].producer = producer
	_fallback_reasons[actor_id] = "takeover"
	return true


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
	if issue and not faulted and not _suspended:
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
	if producer != StringName(str(_definitions[actor_id].producer)):
		return _reject("producer")
	if command.get("run_id") != run_id or not _integer(command.get("epoch"), epoch, epoch):
		return _reject("run_or_epoch")
	if not str(_rigs[actor_id].fault).is_empty():
		return _reject("actor_fault")
	if not _integer(command.get("sequence"), 0, 9007199254740991) \
		or int(command.sequence) <= _sequences[actor_id]:
		return _reject("sequence")
	if not _integer(command.get("observed_tick"), maxi(0, tick - MAX_LEASE), tick) \
		or not _integer(command.get("lease_ticks"), 1, MAX_LEASE):
		return _reject("lease")
	var observed: int = int(command.observed_tick)
	if observed + int(command.lease_ticks) <= tick:
		return _reject("expired_observation")
	if _issued[actor_id][observed % (MAX_LEASE + 1)] != observed \
		or command.get("observation_id") != _observation_id(actor_id, observed):
		return _reject("observation_not_issued")
	var flight: bool = is_flight_actor(actor_id)
	var action: Dictionary = normalized_flight_action(command.get("action")) if flight else normalized_action(command.get("action"))
	if action.is_empty():
		return _reject("action")
	var equipment_action: Dictionary = action.get("equipment", {})
	if not equipment_action.is_empty():
		if not _equipment[actor_id].matches(action.equipment):
			return _reject("equipment_epoch_or_instance")
		if not _equipment[actor_id].can_select(int(action.equipment.usable_index)):
			return _reject("selection_requires_held_body")
	elif bool(action.get("tool", false)) or bool(action.get("release_usable", false)) or bool(action.get("attach_usable", false)):
		return _reject("equipment_identity_required")
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
		return _reject("button_edge_capacity")
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
	return true


func _reject(reason: String) -> bool:
	last_error = reason
	rejected_commands += 1
	return false


func submit_local(actor_id: int, action: Dictionary, producer: StringName, lease: int = 6) -> bool:
	var view: Dictionary = observation(actor_id)
	if view.is_empty():
		return false
	return submit(make_command(view, _sequences[actor_id] + 1, action, lease), producer)


func cancel_input(actor_id: int, expected_epoch: int, producer: StringName) -> bool:
	if not _active or actor_id < 0 or actor_id >= _rigs.size() or expected_epoch != epoch \
		or producer != StringName(str(_definitions[actor_id].producer)):
		return false
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
	_rigs[actor_id].cancel()
	_scripts[actor_id].cancel()
	# A desktop cellular owner may already hold a copied effect packet. Revoking
	# only this session's queue would leave that packet live after focus loss,
	# pause or lease expiry. The main-thread host fences its worker queue too.
	input_cancelled.emit(actor_id, epoch)
	return true


func set_suspended(value: bool) -> void:
	if value == _suspended:
		return
	if not value and _has_flight:
		if not _flight_step_fault.is_empty():
			return
		if bridge.manual_step_count() != _flight_pause_step:
			_fault_flight_step("flight_physics_advanced_while_suspended")
			return
		# Paused views cannot become authority merely because the tick stayed
		# unchanged. A fresh post-resume observation gets a new generation.
		for index: int in range(_rigs.size()):
			if is_flight_actor(index):
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
				_fallback_reasons[index] = "resumed"
	_suspended = value
	if value:
		_flight_pause_step = bridge.manual_step_count()
		_effects.clear()
		for index: int in range(_rigs.size()):
			cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
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
	# Collect every scripted view before admitting outputs or advancing any body.
	var script_actions: Array = []
	if tick % DECISION_TICKS == 0:
		for index: int in range(_rigs.size()):
			if str(_rigs[index].fault).is_empty() and (_definitions[index].producer == &"demo" or _definitions[index].producer == "demo"):
				script_actions.append({"id": index,
					"action": _scripts[index].next_action(observation(index), delta * DECISION_TICKS)})
	for output: Dictionary in script_actions:
		submit_local(int(output.id), output.action, &"demo", 12)
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
			if _effects.size() >= MAX_ACTORS:
				break
			var effect: Dictionary = request.duplicate(true)
			effect["source_body_id"] = _body_offsets[index] + int(effect.get("source_part", 0)) + 1
			_effects.append(effect)


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
		for index: int in range(_rigs.size()):
			_capture_flight_step(index)
			_rigs[index].complete_step()
			_rigs[index].refresh_observation()
			# Fault quarantine retires both unconsumed input and copied tool work.
			# Healthy actors keep their separate leases and continue the session.
			if not str(_rigs[index].fault).is_empty() and not _commands[index].is_empty():
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
				_fallback_reasons[index] = "fault"
			elif is_flight_actor(index) and not _commands[index].is_empty() and tick >= _deadlines[index]:
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


func render_parts() -> Array:
	var result: Array = []
	for index: int in range(_rigs.size()):
		var parts: Array = _catalogue[index].parts
		var actor_bodies: Array[RigidBody2D] = _rigs[index].bodies()
		var flight: Dictionary = _view(index, false).get("flight", {}) if is_flight_actor(index) else {}
		for part_index: int in range(actor_bodies.size()):
			var body: RigidBody2D = actor_bodies[part_index]
			var shape: Shape2D = body.get_child(0).shape
			var dimensions: Vector2 = Vector2(shape.radius * 2.0, shape.radius * 2.0) if shape is CircleShape2D else shape.size
			var presented: Dictionary = {"actor_id": index, "part_id": str(parts[part_index].id),
				"transform": bridge.body_transform(_body_offsets[index] + part_index),
				"size": dimensions, "color": parts[part_index].color,
				"shape": "circle" if shape is CircleShape2D else "rectangle"}
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
	_active = false
	bridge.shutdown()
	for rig in _rigs:
		if is_instance_valid(rig):
			rig.close()
			rig.free()
	_rigs.clear()
	_scripts.clear()
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


func _exit_tree() -> void:
	close()
