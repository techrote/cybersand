class_name CyberPhysicalActorSession
extends Node2D

signal input_cancelled(actor_id: int, actor_epoch: int)

# ACT-004 main-thread owner. Only copied commands/observations/effects cross its
# boundary. The native cellular worker never receives these nodes or RIDs.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Scripted = preload("res://scripts/physical_actor_script.gd")
const MAX_ACTORS: int = 8
const MAX_PARTS: int = 8
const MAX_LEASE: int = 18
const DECISION_TICKS: int = 6
const VERSION: int = 2
const MAX_BUTTON_EDGES: int = 24
const BUTTON_KEYS: Array[String] = ["primary", "secondary", "auxiliary", "tool", "release_usable", "attach_usable"]
const PRODUCERS: Array[StringName] = [&"human", &"demo", &"policy"]
const ACTION_KEYS: Array[String] = ["move", "aim", "effort", "trim", "reel", "primary", "secondary", "auxiliary", "tool", "release_usable", "attach_usable"]
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
var _body_offsets: PackedInt32Array = PackedInt32Array()
var _sequences: PackedInt64Array = PackedInt64Array()
var _deadlines: PackedInt64Array = PackedInt64Array()
var _generations: PackedInt64Array = PackedInt64Array()
var _commands: Array = []
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
		var count: int = Catalog.entry(model).parts.size()
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
	accepted_commands = 0
	rejected_commands = 0
	last_error = ""
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_definitions = definitions.duplicate(true)
	var all_bodies: Array[RigidBody2D] = []
	var sizes := PackedVector2Array()
	for index: int in range(definitions.size()):
		var definition: Dictionary = definitions[index]
		var data: Dictionary = Catalog.entry(StringName(str(definition.model)))
		_catalogue.append(data)
		var rig = Rig.new()
		add_child(rig)
		_body_offsets.append(all_bodies.size())
		_rigs.append(rig)
		if rig.configure(data, definition.position, index, epoch) != OK:
			last_error = "Physical rig refused: " + str(definition.model)
			close()
			return false
		all_bodies.append_array(rig.bodies())
		sizes.append_array(rig.body_sizes())
		var pilot = Scripted.new()
		pilot.configure(StringName(str(definition.model)), definition.position, index)
		_scripts.append(pilot)
		_commands.append({})
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
	_active = true
	return true


func active() -> bool:
	return _active


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
	if issue and not faulted:
		_issued[actor_id][tick % (MAX_LEASE + 1)] = tick
	return result.duplicate(true)


func _observation_id(actor_id: int, observed: int) -> String:
	return "%s:%d:%d:%d:%d" % [run_id, epoch, actor_id, _generations[actor_id], observed]


static func make_command(view: Dictionary, sequence: int, action: Dictionary, lease_ticks: int = 12) -> Dictionary:
	return {"version": VERSION, "kind": "physical_wire_action", "run_id": view.get("run_id", ""),
		"actor_id": view.get("actor_id", -1), "epoch": view.get("epoch", -1),
		"sequence": sequence, "observed_tick": view.get("tick", -1),
		"observation_id": view.get("observation_id", ""), "lease_ticks": lease_ticks,
		"action": action.duplicate(true)}


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func normalized_action(value: Variant) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return {}
	var result: Dictionary = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "effort": 0.7,
		"trim": 0.0, "reel": 0.0, "primary": false, "secondary": false,
		"auxiliary": false, "tool": false, "release_usable": false, "attach_usable": false}
	for key: Variant in value:
		if not key is String and not key is StringName:
			return {}
		var name: String = str(key)
		if name not in ACTION_KEYS:
			return {}
		var item: Variant = value[key]
		if name in ["move", "aim"]:
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
	var action: Dictionary = normalized_action(command.get("action"))
	if action.is_empty():
		return _reject("action")
	var edges: Array = []
	for button: String in BUTTON_KEYS:
		if bool(action[button]) != bool(_accepted_buttons[actor_id].get(button, false)):
			edges.append({"button": button, "pressed": bool(action[button])})
	if _button_edges[actor_id].size() + edges.size() > MAX_BUTTON_EDGES:
		return _reject("button_edge_capacity")
	_button_edges[actor_id].append_array(edges)
	for button: String in BUTTON_KEYS:
		_accepted_buttons[actor_id][button] = action[button]
	_sequences[actor_id] = int(command.sequence)
	_deadlines[actor_id] = observed + int(command.lease_ticks)
	_commands[actor_id] = action
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
	_commands[actor_id] = {}
	_button_edges[actor_id].clear()
	_accepted_buttons[actor_id].clear()
	_applied_buttons[actor_id].clear()
	_deadlines[actor_id] = -1
	_generations[actor_id] += 1
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
	_suspended = value
	if value:
		_effects.clear()
		for index: int in range(_rigs.size()):
			cancel_input(index, epoch, StringName(str(_definitions[index].producer)))


func advance(delta: float) -> void:
	if not _active or _suspended or not is_finite(delta) or delta <= 0.0:
		return
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
		if not str(_rigs[index].fault).is_empty() or _deadlines[index] < tick + 1:
			if not _commands[index].is_empty():
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)))
		var command: Dictionary = _commands[index].duplicate(true)
		if not command.is_empty():
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
		_rigs[index].advance(command, delta, not command.is_empty())
		for request: Dictionary in _rigs[index].drain_effects():
			if _effects.size() >= MAX_ACTORS:
				break
			var effect: Dictionary = request.duplicate(true)
			effect["source_body_id"] = _body_offsets[index] + int(effect.get("source_part", 0)) + 1
			_effects.append(effect)


func complete_step() -> void:
	if _active and not _suspended:
		tick += 1
		for index: int in range(_rigs.size()):
			_rigs[index].refresh_observation()
			# Fault quarantine retires both unconsumed input and copied tool work.
			# Healthy actors keep their separate leases and continue the session.
			if not str(_rigs[index].fault).is_empty() and not _commands[index].is_empty():
				cancel_input(index, epoch, StringName(str(_definitions[index].producer)))


func drain_effects() -> Array:
	var result: Array = _effects.duplicate(true)
	_effects.clear()
	return result


func render_parts() -> Array:
	var result: Array = []
	for index: int in range(_rigs.size()):
		var parts: Array = _catalogue[index].parts
		var actor_bodies: Array[RigidBody2D] = _rigs[index].bodies()
		for part_index: int in range(actor_bodies.size()):
			var body: RigidBody2D = actor_bodies[part_index]
			var shape: RectangleShape2D = body.get_child(0).shape
			result.append({"actor_id": index, "part_id": str(parts[part_index].id),
				"transform": bridge.body_transform(_body_offsets[index] + part_index),
				"size": shape.size, "color": parts[part_index].color})
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
	_definitions.clear()
	_catalogue.clear()
	_body_offsets.clear()
	_sequences.clear()
	_deadlines.clear()
	_generations.clear()
	_commands.clear()
	_button_edges.clear()
	_accepted_buttons.clear()
	_applied_buttons.clear()
	_issued.clear()
	_effects.clear()


func _exit_tree() -> void:
	close()
