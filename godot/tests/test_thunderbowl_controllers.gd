extends SceneTree

const Contract = preload("res://scripts/thunderbowl_contract.gd")
const Arena = preload("res://scripts/thunderbowl_arena.gd")
const Factory = preload("res://examples/thunderbowl/controller_factory.gd")
const Devices = preload("res://examples/thunderbowl/human_devices.gd")
var assertions: int = 0
var failures: int = 0
var _cases: Array = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("THUNDERBOWL_CONTROLLERS: " + label)


func _record(name: String, schema: String, value: Variant, valid: bool = true) -> void:
	_cases.append({"name": name, "schema": schema, "value": value.duplicate(true), "valid": valid})


func _view(model: String = "scout", mode: String = "local") -> Dictionary:
	var state: Array = []
	state.resize(40)
	state.fill(0.0)
	state[0] = 196.0
	state[1] = 193.0
	state[4] = 1.0
	state[6] = 1.0
	state[35] = 8.0
	state[36] = 14.0
	var raw: Array = []
	raw.resize(32)
	raw.fill(0.0)
	var cells: Array = []
	cells.resize(81)
	cells.fill(0)
	return {"version": 1, "run_id": "controller-test", "actor_id": 0, "epoch": 1, "tick": 0,
		"observation_id": "controller-test:1:0:0", "observation_mode": mode,
		"control_mode": "metal" if model in ["ripper", "copter", "gemini"] else "wire",
		"model": model, "team": 0, "alive": true, "self_state": state, "self_hp": 3,
		"tag_ready": true, "actuation_state": raw, "actuation_profile": "",
		"terrain": {"origin": [184, 184], "size": [9, 9], "cell_step": 4, "cells": cells},
		"neighbors": [], "messages": []}


func _advance_view(view: Dictionary, tick: int) -> Dictionary:
	var result: Dictionary = view.duplicate(true)
	result.tick = tick
	result.observation_id = "%s:%d:%d:%d" % [result.run_id, result.epoch, tick, result.actor_id]
	return result


func _neighbor(id: int, x: float, team: int = 1) -> Dictionary:
	return {"actor_id": id, "team": team, "relative_position": [x, 0.0],
		"velocity": [0.0, 0.0], "body_size": [8.0, 14.0], "rotation": 0.0}


func _presets() -> void:
	var paths: PackedStringArray = DirAccess.get_files_at("res://examples/thunderbowl/matches")
	paths.sort()
	var count: int = 0
	for filename: String in paths:
		if not filename.ends_with(".json"): continue
		count += 1
		var config: Dictionary = Contract.load_json("res://examples/thunderbowl/matches/" + filename)
		_expect(Contract.valid_config(config), "registered preset schema: " + filename)
		_record(filename, "match", config)
		var arena := Arena.new()
		_expect(arena.configure(config), "native preset configure: " + filename)
		if not arena.last_error.is_empty():
			arena.close()
			continue
		var policies: Array = []
		var central: RefCounted = Factory.create("oracle")
		for definition: Dictionary in config.actors: policies.append(Factory.create(definition.controller))
		for step: int in range(12):
			var commands: Array = []
			var oracle_views: Array = []
			if step % 6 == 0:
				for actor_id: int in range(config.actors.size()):
					var view: Dictionary = arena.observation(actor_id)
					var before: String = JSON.stringify(view)
					if step == 0: _record(filename + ":view:" + str(actor_id), "observation", view)
					if config.actors[actor_id].controller == "oracle":
						oracle_views.append(view)
						continue
					var command: Dictionary = policies[actor_id].decide(view)
					_expect(Contract.valid_command(command), "controller emitted malformed command: " + str(config.actors[actor_id].controller))
					_expect(JSON.stringify(view) == before, "policy mutated supplied copied view")
					commands.append(command)
					if step == 0: _record(filename + ":command:" + str(actor_id), "command", command)
				if not oracle_views.is_empty(): commands.append_array(central.decide_batch(oracle_views))
			var result: Dictionary = arena.step(commands)
			_expect(not result.failed, "native preset step failed: " + filename)
			_expect(int(result.admission.rejected) == 0, "valid example command refused: " + filename + " " + str(result.admission))
		arena.close()
	_expect(count == 14, "preset count drift: update schema/controller coverage intentionally")


func _schema_adversaries() -> void:
	var valid: Dictionary = Contract.command(_view(), 1, Contract.neutral_wire())
	_expect(Contract.valid_command(valid), "neutral wire command rejected")
	for key: String in Contract.COMMAND_KEYS:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(key)
		_expect(not Contract.valid_command(missing), "required command field accepted missing: " + key)
		_record("missing:" + key, "command", missing, false)
	for change: Dictionary in [{"sequence": -1}, {"sequence": 1.5}, {"actor_id": 8}, {"lease_ticks": 19},
		{"observed_tick": -1}, {"tag": 1}, {"cancel": 0}, {"unexpected": "field"},
		{"message": [0, 0, 0, 0]}, {"message_type": "latent_state"}, {"kind": false}]:
		var bad: Dictionary = valid.duplicate(true)
		bad.merge(change, true)
		_expect(not Contract.valid_command(bad), "malformed command accepted: " + str(change))
		_record("bad-envelope:" + str(change), "command", bad, false)
	for channel: String in ["effort", "trim", "reel"]:
		for value: Variant in [NAN, INF, -INF, "1", true, -2.0, 2.0]:
			var bad: Dictionary = valid.duplicate(true)
			bad.action[channel] = value
			_expect(not Contract.valid_command(bad), "invalid scalar admitted: " + channel)
	var cancellation: Dictionary = valid.duplicate(true)
	cancellation.cancel = true
	_expect(Contract.valid_command(cancellation), "neutral cancellation refused")
	cancellation.action.primary = true
	_expect(not Contract.valid_command(cancellation), "charged cancellation allowed primary")
	_record("non-neutral-cancel", "command", cancellation, false)
	var config: Dictionary = Contract.load_json("res://examples/thunderbowl/matches/wire_duel.json")
	for bad_type: Variant in [false, 0, [], {}, null]:
		var malformed: Dictionary = config.duplicate(true)
		malformed.layout = bad_type
		_expect(not Contract.valid_config(malformed), "malformed layout type did not fail cleanly")
		_record("bad-layout-type:" + str(bad_type), "match", malformed, false)
	config.actors[0].controller = "human_wire"
	_expect(not Contract.valid_config(config), "matched classification admitted human cadence")
	config.evaluation = "asymmetric"
	_expect(Contract.valid_config(config), "asymmetric human configuration rejected")
	config.actors[0].control_mode = "metal"
	_expect(not Contract.valid_config(config), "unsupported/controller-mismatched metal rig admitted")


func _human_inputs() -> void:
	for filename: String in ["input_keyboard.json", "input_touch.json"]:
		var frame: Dictionary = Contract.load_json("res://examples/thunderbowl/" + filename)
		_expect(Contract.valid_input(frame), "human input fixture invalid: " + filename)
		_record(filename, "input", frame)
	var human: RefCounted = Factory.create("human_wire")
	var view: Dictionary = _view()
	human.decide(view) # Binding resets stale input; then sample this episode.
	var frame: Dictionary = Contract.neutral_input()
	frame.deadman = true
	frame.primary = true
	frame.effort = 0.6
	_expect(human.set_input(frame), "human copied frame refused")
	frame.primary = false
	_expect(human.decide(view).action.primary, "human frame aliased caller storage")
	human.set_input(Contract.neutral_input())
	var released: Dictionary = human.decide(view)
	_expect(released.cancel and not released.action.primary, "deadman loss became charged release")
	var malformed: Dictionary = Contract.neutral_input()
	malformed.effort = INF
	_expect(not human.set_input(malformed) and human.decide(view).cancel, "malformed human frame retained authority")
	var metal: RefCounted = Factory.create("human_metal")
	view = _view("gemini")
	metal.decide(view)
	var raw: Dictionary = Contract.load_json("res://examples/thunderbowl/input_gamepad_metal.json")
	raw.actuators = [0.25, 0.75, 0.0, 0.0]
	_expect(metal.set_actuator_input(raw), "direct analog input refused")
	_expect(metal.decide(view).action.actuators == raw.actuators, "independent analog thrusters gained hidden conversion")
	_record("independent-analog", "actuator-input", raw)
	_expect(Contract.valid_input(Devices.keyboard_mouse(Vector2.RIGHT, false)), "unfocused keyboard adapter invalid")
	_expect(not Devices.gamepad(-1, true).deadman, "disconnected pad retained deadman")


func _swarm_boundaries() -> void:
	for controller: String in ["lemming", "emergent"]:
		var first: RefCounted = Factory.create(controller)
		var second: RefCounted = Factory.create(controller)
		var view: Dictionary = _view("digger" if controller == "emergent" else "scout", "self")
		var polluted: Dictionary = view.duplicate(true)
		polluted.neighbors = [_neighbor(1, -12.0)]
		polluted.messages = [{"kind": "goal_hint", "payload": [1, 1, 1, 0]}]
		polluted["oracle"] = {"hidden": "forbidden source"}
		_expect(first.decide(view).action == second.decide(polluted).action,
			"independent example used neighbors/messages/oracle: " + controller)
	var local: RefCounted = Factory.create("local_swarm")
	var view: Dictionary = _view()
	view.messages = [{"sender": 1, "kind": "goal_hint", "payload": [0.15, 0.20, 1, 0], "sent_tick": 0, "expires_tick": 12}]
	var command: Dictionary = local.decide(view)
	_expect(command.action.movement[0] < 0.0 and not command.tag, "local hint failed movement or shot at unseen target")
	view.neighbors = [_neighbor(2, 30.0)]
	command = local.decide(view)
	_expect(command.message_type == "goal_hint" and command.message.size() == 4, "local target hint not explicitly typed")
	var a: RefCounted = Factory.create("nca")
	var b: RefCounted = Factory.create("nca")
	view.messages = [{"sender": 1, "kind": "latent_state", "payload": [0.2, 0.4, -0.8, 0.3]},
		{"sender": 2, "kind": "latent_state", "payload": [-0.6, 0.1, 0.7, -0.2]}]
	var reordered: Dictionary = view.duplicate(true)
	reordered.messages.reverse()
	var ca: Dictionary = a.decide(view)
	var cb: Dictionary = b.decide(reordered)
	_expect(ca.message == cb.message, "NCA neighbor order changed simultaneous aggregation")
	_expect(ca.message_type == "latent_state" and a.weight_sha256.length() == 64, "NCA lost typed state or weight identity")
	var untouched: RefCounted = Factory.create("nca")
	var empty_view: Dictionary = view.duplicate(true)
	empty_view.messages = []
	_expect(ca.message != untouched.decide(empty_view).message, "NCA example did not use previous neighbor state")
	var weights: Dictionary = Contract.load_json("res://examples/thunderbowl/nca_seed_weights.json")
	_record("nca-untrained-weights", "nca-weights", weights)
	var invalid_type: Dictionary = weights.duplicate(true)
	invalid_type.architecture = false
	_expect(not a.set_weights(invalid_type), "NCA malformed architecture did not fail cleanly")
	_record("nca-architecture-type", "nca-weights", invalid_type, false)
	weights.weights_in[0] = INF
	_expect(not a.set_weights(weights), "NCA nonfinite weights accepted")


func _response(request: Dictionary, speed: float = 0.65) -> Dictionary:
	var response: Dictionary = {}
	for key: String in ["version", "request_id", "run_id", "actor_id", "epoch", "observation_id", "observed_tick"]:
		response[key] = request[key]
	response.valid_for_ticks = 120
	response.intent = {"mode": "move_to", "goal": [300.0, 200.0], "speed": speed, "engage": true}
	return response


func _smart_link() -> void:
	var smart: RefCounted = Factory.create("smart_link")
	var view: Dictionary = _view("runner")
	var request: Dictionary = smart.request(view)
	_record("model-request", "smart-request", request)
	_expect(not request.is_empty() and smart.request(view).is_empty(), "smart link allows multiple in-flight requests")
	var response: Dictionary = _response(request)
	_record("model-response", "smart-decision", response)
	for key: String in ["request_id", "run_id", "actor_id", "epoch", "observation_id", "observed_tick"]:
		for bad_type: Variant in [false, [], {}, null]:
			var malformed: Dictionary = response.duplicate(true)
			malformed[key] = bad_type
			_expect(not smart.submit_decision(malformed), "smart reply identity type did not fail cleanly: " + key)
			_record("smart-type:" + key + ":" + str(bad_type), "smart-decision", malformed, false)
	var forged: Dictionary = response.duplicate(true)
	forged.observed_tick = 6
	_expect(not smart.submit_decision(forged), "model forged a newer observation tick")
	_expect(smart.submit_decision(response), "fresh model intention refused")
	_expect(not smart.submit_decision(response), "model reply replay accepted")
	var action: Dictionary = smart.decide(view)
	_expect(action.action.movement[0] > 0.0 and action.action.movement[0] <= 0.65 and not action.tag,
		"model drive-demand scaling failed or shot at unseen target")
	var expired: Dictionary = smart.decide(_advance_view(view, 120))
	_expect(expired.cancel and expired.action == Contract.neutral_wire(), "expired model plan acquired a fresh actuator lease")
	request = smart.request(_advance_view(view, 120))
	response = _response(request, 0.0)
	_expect(smart.submit_decision(response), "zero drive-demand intention refused")
	_expect(smart.decide(_advance_view(view, 120)).cancel, "zero drive demand moved SetA, which ignores effort")
	view.run_id = "new-run"
	view.observation_id = "new-run:1:0:0"
	smart.decide(view)
	_expect(not smart.submit_decision(response), "model result crossed an arena reset")


func _oracle_assignment() -> void:
	var central: RefCounted = Factory.create("oracle")
	var view: Dictionary = _view("scout", "oracle")
	var enemies: Array = []
	for index: int in range(2):
		var state: Array = view.self_state.duplicate()
		state[0] = 226.0 if index == 0 else 156.0
		enemies.append({"actor_id": index + 2, "model": "scout", "team": 1, "alive": true, "hp": 3, "state": state})
	view.oracle = {"actors": enemies}
	var peer: Dictionary = view.duplicate(true)
	peer.actor_id = 1
	peer.observation_id = "controller-test:1:0:1"
	var actions: Array = central.decide_batch([view, peer])
	_expect(actions.size() == 2 and actions[0].action.aim[0] > 0.0 and actions[1].action.aim[0] < 0.0,
		"central batch failed to coordinate target assignment")


func _run() -> void:
	_schema_adversaries()
	_human_inputs()
	_swarm_boundaries()
	_smart_link()
	_oracle_assignment()
	_presets()
	var file: FileAccess = FileAccess.open("user://thunderbowl-contract-cases.json", FileAccess.WRITE)
	_expect(file != null, "could not retain external-schema validation capture")
	if file != null:
		file.store_string(JSON.stringify({"cases": _cases}, "\t") + "\n")
		file.close()
	print("Thunderbowl controller assertions: %d; failures: %d; schema capture cases: %d" % [assertions, failures, _cases.size()])
	quit(1 if failures else 0)
