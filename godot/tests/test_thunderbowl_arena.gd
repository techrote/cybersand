extends SceneTree

const Arena = preload("res://scripts/thunderbowl_arena.gd")
const Contract = preload("res://scripts/thunderbowl_contract.gd")
const Catalog = preload("res://scripts/actor_rig_catalog.gd")
const Driver = preload("res://examples/thunderbowl/thunderbowl_driver.gd")
var assertions: int = 0
var failures: int = 0

class FailedStepArena:
	extends CyberThunderbowlArena
	func _advance_materials() -> bool:
		return false

class SceneKeyProbe:
	extends "res://examples/thunderbowl/thunderbowl_scene.gd"
	var held_keys: Dictionary = {}
	var pads: Array = []
	var axes: Dictionary = {}
	func _key_held(key: int) -> bool:
		return bool(held_keys.get(key, false))
	func _connected_pads() -> Array:
		return pads.duplicate()
	func _joy_axis(device: int, axis: int) -> float:
		return float(axes.get(Vector2i(device, axis), 0.0))
	func _joy_button(_device_id: int, _button: int) -> bool:
		return false

class MisboundPolicy:
	extends RefCounted
	var victim: Dictionary = {}
	func decide(_view: Dictionary) -> Dictionary:
		var action: Dictionary = CyberThunderbowlContract.neutral_wire()
		action.movement = [1.0, 0.0]
		return CyberThunderbowlContract.command(victim, 1000, action)
	func decide_batch(_views: Array) -> Array:
		return [decide({})]


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("THUNDERBOWL_ARENA: " + message)


func _definition(model: String = "runner", controller: String = "wire_seek", team: int = 0) -> Dictionary:
	var mode: String = "wire"
	var view: String = "local"
	if controller in ["human_metal", "metal_pulse"]:
		mode = "metal"
	if controller in ["lemming", "emergent"]:
		view = "self"
	if controller == "oracle":
		view = "oracle"
	return {"model": model, "control_mode": mode, "observation_mode": view,
		"team": team, "controller": controller}


func _config(definitions: Array = [], ticks: int = 180, seed: int = 19) -> Dictionary:
	return {"version": 1, "seed": seed, "max_ticks": ticks, "layout": "training_pit",
		"evaluation": "mechanics", "actors": definitions if not definitions.is_empty() else [_definition()]}


func _arena(definitions: Array = [], ticks: int = 180, seed: int = 19) -> CyberThunderbowlArena:
	var arena := Arena.new()
	_expect(arena.configure(_config(definitions, ticks, seed)), "real native arena could not configure: " + arena.last_error)
	return arena


func _packet(arena: CyberThunderbowlArena, actor_id: int = 0, changes: Dictionary = {}) -> Dictionary:
	var view: Dictionary = arena.observation(actor_id)
	var action: Dictionary = Contract.neutral_wire()
	if view.control_mode == "metal":
		action = {"actuators": [0.0, 0.0, 0.0, 0.0], "tag_aim": [0.0, 0.0]}
	for key: String in changes:
		if action.has(key):
			action[key] = changes[key]
	var packet: Dictionary = Contract.command(view, int(arena._last_sequences[actor_id]) + 1, action,
		bool(changes.get("tag", false)), changes.get("message", []), bool(changes.get("cancel", false)),
		str(changes.get("message_type", "none")))
	for key: String in changes:
		if packet.has(key) and key not in ["action"]:
			packet[key] = changes[key]
	return packet


func _clear_lane(arena: CyberThunderbowlArena) -> void:
	# Owner-only test fixture setup, never an action supplied to a controller.
	_expect(arena._world.diagnostic_fill_rect(Vector2i(100, 110), Vector2i(248, 118), 0),
		"native lane fixture could not clear intervening editable terrain")
	arena._invalidate_views()


func _place(arena: CyberThunderbowlArena, index: int, center: Vector2) -> void:
	var actor: CyberActorPrototype = arena._session._actors[index]
	var body: Vector2 = Vector2(arena._state(index)[35], arena._state(index)[36])
	actor.reset(center - body * 0.5)
	arena._context = arena._session.snapshot()
	arena._invalidate_views()


func _comparable(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	result.erase("run_id")
	return result


func _configuration_and_real_rigs() -> void:
	var arena := Arena.new()
	for model: StringName in Catalog.RIG_IDS:
		_expect(arena.configure(_config([_definition(str(model))], 3)), "current rig rejected by real arena: " + str(model))
		var before: Dictionary = arena.snapshot()
		_expect(before.actor_prototypes.count == 1 and before.actor_prototypes.models[0] == model,
			"arena catalog entry did not become an actual current actor session")
		_expect(arena.observation(0).self_state.size() == 40, "rig view lost its fixed 40-state prefix")
		var after: Dictionary = arena.step([_packet(arena, 0, {"movement": [1.0, 0.0]})])
		_expect(after.tick == 1 and after.actor_prototypes.tick == 1 and arena._world.get_tick_index() == 1,
			"native/session ownership did not advance exactly one common tick")
		_expect(after.admission.accepted == 1 and after.work.motor_collision_queries > 0,
			"real rig was admitted without executing its bounded motor")
	var definitions: Array = []
	for model: String in ["runner", "ripper", "digger", "copter", "lineshank", "clamberer", "qwen", "gemini"]:
		definitions.append(_definition(model))
	_expect(arena.configure(_config(definitions)), "eight current rigs exceeded the intended arena capacity")
	var installed: Dictionary = arena.snapshot()
	definitions.append(_definition())
	_expect(not arena.configure(_config(definitions)), "ninth arena rig was admitted")
	_expect(arena.snapshot().actor_prototypes == installed.actor_prototypes \
		and arena.snapshot().run_id == installed.run_id, "refused setup partly replaced the live authority")
	var invalid: Dictionary = _config()
	invalid["world"] = RefCounted.new()
	_expect(not arena.configure(invalid), "arbitrary object/unknown config field was accepted")
	var output: Dictionary = arena.snapshot()
	output.hp[0] = 0
	output.actor_prototypes.rig_states[0] = -999.0
	_expect(arena.snapshot().hp[0] == 3 and arena.snapshot().actor_prototypes.rig_states[0] != -999.0,
		"evaluator publication retained mutable authoritative arrays")
	arena.close()
	_expect(arena.observation(0).is_empty() and arena.step([]).reason == "closed", "closed arena accepted further authority access")


func _identity_and_command_admission() -> void:
	var arena := _arena([_definition("runner"), _definition("runner", "wire_seek", 1)])
	_clear_lane(arena)
	var command: Dictionary = _packet(arena)
	var invalids: Array = []
	for key: String in ["run_id", "epoch", "sequence", "observed_tick", "observation_id", "lease_ticks"]:
		var candidate: Dictionary = command.duplicate(true)
		match key:
			"run_id": candidate[key] = "a different process or episode"
			"epoch": candidate[key] = 99
			"sequence": candidate[key] = -1
			"observed_tick": candidate[key] = 10
			"observation_id": candidate[key] = "fabricated"
			"lease_ticks": candidate[key] = 19
		invalids.append(candidate)
	var extra: Dictionary = command.duplicate(true)
	extra["producer"] = "human"
	invalids.append(extra)
	var nonfinite: Dictionary = command.duplicate(true)
	nonfinite.action.movement = [NAN, 0.0]
	invalids.append(nonfinite)
	var unseen: Dictionary = command.duplicate(true)
	unseen.actor_id = 1
	unseen.observation_id = "%s:%d:0:1" % [command.run_id, command.epoch]
	invalids.append(unseen)
	for candidate: Dictionary in invalids:
		var result: Dictionary = arena.step([candidate])
		_expect(result.admission.accepted == 0 and result.admission.rejected == 1,
			"malformed, forged, stale or unissued command mutated actor authority")
	var valid: Dictionary = _packet(arena, 0, {"movement": [1.0, 0.0]})
	var result: Dictionary = arena.step([valid, valid.duplicate(true)])
	_expect(result.admission.accepted == 1 and result.admission.rejected == 1,
		"duplicate actor packet escaped the per-step command bound")
	result = arena.step([valid])
	_expect(result.admission.accepted == 0 and result.actor_prototypes.sequences[0] == valid.sequence,
		"replayed packet regained sequence authority")
	var overflow: Array = []
	for _index: int in range(9): overflow.append(_packet(arena))
	result = arena.step(overflow)
	_expect(result.admission.accepted == 0 and result.admission.rejected == 9, "oversized batch partially executed")
	var stale: Dictionary = _packet(arena)
	for _index: int in range(19): arena.step([])
	result = arena.step([stale])
	_expect(result.admission.accepted == 0 and result.actor_prototypes.applied_sequences[0] == -1,
		"late response extended its observation-derived lease")
	var old: Dictionary = _packet(arena)
	var old_run: String = old.run_id
	_expect(arena.configure(_config()), "new episode could not configure")
	_expect(arena.snapshot().run_id != old_run and arena.snapshot().run_id.length() == 32,
		"new native episode reused its opaque run identity")
	result = arena.step([old])
	_expect(result.admission.accepted == 0, "previous episode response matched a new epoch-one arena")
	arena.close()


func _locality_and_owned_views() -> void:
	var arena := _arena([_definition("runner"), _definition("runner", "wire_seek", 1),
		_definition("runner", "oracle", 0)])
	_clear_lane(arena)
	_place(arena, 1, Vector2(260.0, 221.0))
	_place(arena, 2, Vector2(330.0, 221.0))
	var local_before: Dictionary = arena.observation(0)
	var oracle_before: Dictionary = arena.observation(2)
	_expect(local_before.neighbors.is_empty() and not local_before.has("oracle") \
		and not local_before.has("actors") and not local_before.has("world"), "local view leaked an evaluator/global field")
	arena._hp[1] = 1
	arena._session._actors[1].energy = 0.125
	arena._session._actors[1].velocity = Vector2(37.0, -4.0)
	arena._session._actors[1].position.x += 12.0
	arena._context = arena._session.snapshot()
	arena._invalidate_views()
	_expect(arena.observation(0) == local_before, "fully hidden actor hp, energy, position or velocity changed a local packet")
	_expect(arena.observation(2).oracle != oracle_before.oracle, "oracle reference could not observe the hidden-state negative control")
	var retained: Dictionary = arena.observation(0)
	retained.self_state[0] = -100.0
	retained.terrain.cells[0] = 80
	_expect(arena.observation(0) == local_before, "consumer mutation changed cached/authoritative local observations")
	_place(arena, 1, Vector2(145.0, 221.0))
	var visible: Dictionary = arena.observation(0)
	_expect(visible.neighbors.size() == 1 and visible.neighbors[0].actor_id == 1,
		"nearby unobscured opponent was not visible")
	_expect(not visible.neighbors[0].has("hp") and not visible.neighbors[0].has("energy") \
		and not visible.neighbors[0].has("state") and not visible.neighbors[0].has("target"),
		"neighbor record exposed hidden controller/resources")
	arena._world.diagnostic_fill_rect(Vector2i(130, 200), Vector2i(1, 28), 1)
	arena._invalidate_views()
	_expect(arena.observation(0).neighbors.is_empty(), "one-cell wall failed to hide nearby actor")
	_expect(visible.terrain.cells.size() == 81 and visible.terrain.cell_step == 4,
		"local stencil lost its fixed work/spacing declaration")
	var cached_work: int = int(arena.snapshot().work.sensor_reads)
	for _index: int in range(10): arena.observation(0)
	_expect(arena.snapshot().work.sensor_reads == cached_work, "re-reading a common tick resampled native sensors")
	_expect(cached_work <= Arena.MAX_SENSOR_READS, "common-frame local/oracle sensing exceeded its cap")
	arena.close()
	var self_arena := _arena([_definition("runner", "lemming"), _definition("runner", "wire_seek", 1)])
	_clear_lane(self_arena)
	_expect(self_arena.observation(0).neighbors.is_empty() and self_arena.observation(0).messages.is_empty(),
		"self-only controller received neighbor or communication information")
	self_arena.close()


func _tags_and_terminal_accounting() -> void:
	var arena := _arena([_definition("runner"), _definition("runner", "wire_seek", 1)], 300)
	_clear_lane(arena)
	var before: Dictionary = arena.snapshot()
	var first: Dictionary = arena.step([_packet(arena, 0, {"aim": [1.0, 0.0], "tag": true})])
	_expect(first.hp == PackedInt32Array([3, 2]) and first.rewards == PackedFloat64Array([1.0, -1.0]),
		"valid LOS tag did not apply exactly one virtual hp/reward event")
	_expect(before.hp == PackedInt32Array([3, 3]), "retained evaluator hp changed after tag resolution")
	for _index: int in range(35):
		arena.step([_packet(arena, 0, {"aim": [1.0, 0.0], "tag": true})])
	_expect(arena.snapshot().hp[1] == 2 and arena.snapshot().tags_dealt[0] == 1,
		"held tag input retriggered merely because cooldown expired")
	arena.step([_packet(arena)])
	arena._world.diagnostic_fill_rect(Vector2i(130, 200), Vector2i(1, 28), 1)
	arena._invalidate_views()
	var blocked: Dictionary = arena.step([_packet(arena, 0, {"aim": [1.0, 0.0], "tag": true})])
	_expect(blocked.hp[1] == 2, "virtual tag crossed a native one-cell wall")
	_expect(int(arena._world.material_at(130, 221)) == 1, "virtual tag action edited native terrain")
	_expect(blocked.work.tag_reads <= Arena.MAX_TAG_READS, "bounded tag ray work escaped accounting")
	arena.close()
	var duel := _arena([_definition("runner"), _definition("runner", "wire_seek", 1)])
	_clear_lane(duel)
	duel._hp[0] = 1
	duel._hp[1] = 1
	var end: Dictionary = duel.step([_packet(duel, 1, {"aim": [-1.0, 0.0], "tag": true}),
		_packet(duel, 0, {"aim": [1.0, 0.0], "tag": true})])
	_expect(end.hp == PackedInt32Array([0, 0]) and end.reason == "all_eliminated",
		"simultaneous virtual shots acquired actor-iteration first-mover advantage")
	_expect(end.tags_dealt == PackedInt32Array([1, 1]) and end.event_count == 4,
		"simultaneous tags/eliminations were lost or duplicated")
	var frozen: Dictionary = end.duplicate(true)
	for _index: int in range(3): duel.step([])
	_expect(duel.snapshot() == frozen, "terminal match kept advancing or farming rewards")
	duel.close()
	var ring := _arena()
	_place(ring, 0, Vector2(180.0, 80.0))
	var fallen: Dictionary = ring.step([])
	_expect(fallen.hp[0] == 0 and fallen.rewards[0] == -2.0 and fallen.events[0].type == "ring_out",
		"arena boundary event was not explicitly scored once")
	ring.close()


func _messages_and_cancellation() -> void:
	var arena := _arena([_definition("runner", "local_swarm"), _definition("runner", "nca")], 80)
	_clear_lane(arena)
	var before: Dictionary = arena.observation(1)
	var sent: Dictionary = _packet(arena, 0, {"message": [0.5, -0.25, 0.0, 1.0], "message_type": "goal_hint"})
	_expect(before.messages.is_empty(), "unsent communication appeared in an observation")
	arena.step([sent])
	var received: Dictionary = arena.observation(1)
	_expect(received.messages.size() == 1 and received.messages[0].kind == "goal_hint" \
		and received.messages[0].sent_tick == 0 and received.tick == 1,
		"bounded typed message was not delivered exactly on the following tick")
	_expect(before.messages.is_empty(), "new message mutated a retained pre-step observation")
	var wrong_kind: Dictionary = _packet(arena, 0, {"message": [1.0, 0.0, 0.0, 0.0], "message_type": "latent_state"})
	var result: Dictionary = arena.step([wrong_kind])
	_expect(result.admission.accepted == 0, "local_swarm impersonated an NCA hidden-state message")
	for _index: int in range(11): arena.step([])
	_expect(arena.observation(1).messages.is_empty(), "expired observation-derived message lease was extended")
	arena.step([_packet(arena, 0, {"message": [0.0, 1.0, 0.0, 0.0], "message_type": "goal_hint"})])
	arena._world.diagnostic_fill_rect(Vector2i(130, 200), Vector2i(1, 28), 1)
	arena.step([])
	_expect(arena.observation(1).messages.is_empty(), "communication retained an unseen sender through a new wall")
	arena.close()
	var pouncer := _arena([_definition("pouncer", "human_wire")])
	_clear_lane(pouncer)
	for _index: int in range(12):
		pouncer.step([_packet(pouncer, 0, {"aim": [1.0, -1.0], "effort": 1.0, "primary": true})])
	_expect(pouncer.observation(0).self_state[25] > 0.0, "pouncer fixture did not arm a real release charge")
	var cancelled: Dictionary = pouncer.step([_packet(pouncer, 0, {"cancel": true})])
	_expect(cancelled.actor_prototypes.rig_states[25] == 0.0 \
		and cancelled.actor_prototypes.rig_states[3] >= -0.01,
		"focus/deadman cancellation was interpreted as an intentional charged leap")
	pouncer.close()


func _metal_and_failed_owner() -> void:
	var arena := _arena([_definition("copter", "metal_pulse")], 70)
	_clear_lane(arena)
	_place(arena, 0, Vector2(190.0, 170.0))
	var view: Dictionary = arena.observation(0)
	_expect(view.actuation_state.size() == 32 and view.actuation_profile == "copter-metal-v1",
		"native arena did not expose the configured raw actuator profile")
	var y_before: float = view.self_state[1]
	var hover: Dictionary = _packet(arena, 0, {"actuators": [0.5, 0.0, 0.0, 0.0], "lease_ticks": 1})
	var lifted: Dictionary = arena.step([hover])
	_expect(lifted.admission.accepted == 1 and absf(lifted.actor_prototypes.rig_states[1] - y_before) < 0.001,
		"real Copter raw half-collective did not produce its declared upright hover")
	var expired: Dictionary = arena.step([])
	_expect(expired.actor_prototypes.applied_sequences[0] == -1 and expired.actor_prototypes.rig_states[3] > 0.0,
		"expired raw command became a wire auto-hover instead of passive zero-metal gravity")
	var wrong: Dictionary = Contract.command(arena.observation(0), 100, Contract.neutral_wire())
	wrong.kind = "rig_action"
	_expect(arena.step([wrong]).admission.accepted == 0, "wire packet bypassed fixed metal lane")
	arena.close()
	var failed := FailedStepArena.new()
	_expect(failed.configure(_config()), "failure-injection owner fixture could not use real native setup")
	var retained: Dictionary = failed.snapshot()
	var result: Dictionary = failed.step([_packet(failed, 0, {"movement": [1.0, 0.0], "tag": true, "aim": [1.0, 0.0]})])
	_expect(result.failed and result.finished and result.tick == 0 and result.attempted_tick == 1,
		"owner failure was not quarantined at the last completed generation")
	_expect(result.actor_prototypes == retained.actor_prototypes and result.hp == retained.hp \
		and result.rewards == retained.rewards, "failed material step published speculative actors or rewards")
	_expect(failed.observation(0).is_empty() and failed.step([]) == result,
		"failed owner retried a tick or issued new policy authority")
	failed.close()


func _determinism_and_work_report() -> void:
	var definitions: Array = []
	for model: String in ["runner", "ripper", "digger", "copter", "lineshank", "clamberer", "qwen", "gemini"]:
		definitions.append(_definition(model))
	var first := _arena(definitions, 120, 29)
	var second := _arena(definitions, 120, 29)
	_expect(first.snapshot().run_id != second.snapshot().run_id, "independent runs accidentally shared packet identity")
	_expect(_comparable(first.snapshot()) == _comparable(second.snapshot()), "same-seed authored setup was not repeatable")
	var start: int = Time.get_ticks_usec()
	var peak_sensors: int = 0
	var edited: int = 0
	for tick: int in range(120):
		var commands_a: Array = []
		var commands_b: Array = []
		if tick % 6 == 0:
			for index: int in range(8):
				var changes: Dictionary = {"movement": [1.0 if index % 2 == 0 else -1.0, 0.0],
					"aim": [1.0 if index % 2 == 0 else -1.0, 0.1], "effort": 0.7,
					"primary": index == 2 or tick % 30 == 0}
				commands_a.append(_packet(first, index, changes))
				commands_b.append(_packet(second, index, changes))
			peak_sensors = maxi(peak_sensors, int(first.snapshot().work.sensor_reads))
		var a: Dictionary = first.step(commands_a)
		var b: Dictionary = second.step(commands_b)
		_expect(_comparable(a) == _comparable(b), "same-seed native arena/action trace diverged at tick " + str(tick))
		_expect(a.work.motor_collision_queries <= 8 * 96 and a.work.motor_ray_queries <= 8 * 64 \
			and a.work.motor_effect_reads <= 8 * 64 and a.work.motor_edited_cells <= 8 * 64,
			"actual native eight-rig owner work exceeded existing motor quotas")
		edited += int(a.work.motor_edited_cells)
	var elapsed: int = Time.get_ticks_usec() - start
	_expect(first.snapshot().finished and not first.snapshot().final_material_hash.is_empty(),
		"bounded native match did not publish a final completed material identity")
	_expect(first.snapshot().final_material_hash == str(first._world.diagnostic_snapshot(Arena.ARENA_ORIGIN,
		Arena.ARENA_SIZE, false).hash), "final published material identity differs from the actual completed native world")
	_expect(edited > 0, "real Digger shared-terrain example executed no bounded native excavation")
	_expect(peak_sensors <= Arena.MAX_SENSOR_READS, "eight-rig policy sensing exceeded its explicit budget")
	print("THUNDERBOWL_NATIVE_TIMING {\"actors\":8,\"ticks_per_arena\":120,\"arena_count\":2,\"elapsed_usec\":", elapsed,
		",\"peak_sensor_reads\":", peak_sensors, ",\"edited_cells\":", edited,
		",\"scope\":\"two real native workers=1 arenas; 10Hz views/actions, 60Hz motors/materials, evaluator copies and equality checks; informational\"}")
	var prior_digest: String = first.snapshot().layout_digest
	first.configure(_config(definitions, 1, 30))
	_expect(first.snapshot().layout_digest != prior_digest, "different seed did not change authored arena terrain")
	first.close()
	second.close()


func _driver_and_file_adapter() -> void:
	var driver := Driver.new()
	_expect(driver.configure(_config([_definition("runner"), _definition("runner", "wire_seek", 1)])),
		"ordinary policy routing negative setup failed")
	var attacker := MisboundPolicy.new()
	attacker.victim = driver.arena.observation(1)
	driver._controllers[0] = attacker
	var refused: Dictionary = driver.step()
	_expect(driver.controller_rejections == 1 and refused.actor_prototypes.sequences[0] == -1 \
		and refused.actor_prototypes.sequences[1] < 1000 and refused.admission.rejected == 0,
		"ordinary controller forged another issued actor observation and stole its owner slot")
	_expect(driver.configure(_config([_definition("runner", "oracle"), _definition("runner", "wire_seek", 1)])),
		"oracle policy routing negative setup failed")
	attacker = MisboundPolicy.new()
	attacker.victim = driver.arena.observation(1)
	driver._oracle = attacker
	refused = driver.step()
	_expect(driver.controller_rejections == 1 and refused.actor_prototypes.sequences[0] == -1 \
		and refused.actor_prototypes.sequences[1] < 1000,
		"shared oracle escaped its assigned actor set")
	driver.close()
	_expect(driver.configure(_config([_definition("runner", "human_wire")])), "first-frame human driver setup failed")
	var human_frame: Dictionary = Contract.neutral_input()
	human_frame.deadman = true
	human_frame.primary = true
	human_frame.effort = 0.7
	var first_frame: Dictionary = driver.step({0: human_frame})
	_expect(first_frame.admission.accepted == 1 and first_frame.actor_prototypes.rig_states[3] < -1.0,
		"fresh human first-frame primary press was discarded by controller identity binding")
	_expect(driver.configure(_config([_definition("gemini", "human_metal")])), "first-frame raw human driver setup failed")
	var raw_frame: Dictionary = {"version": 1, "device": "virtual", "actuators": [0.25, 0.75, 0.0, 0.0],
		"aim": [1.0, 0.0], "tag": false, "deadman": true}
	first_frame = driver.step({0: raw_frame})
	_expect(first_frame.admission.accepted == 1 and absf(first_frame.actor_prototypes.rig_states[17]) > 0.001,
		"fresh independent metal first-frame channels were discarded by controller identity binding")
	driver.close()
	var config: Dictionary = Contract.load_json("res://examples/thunderbowl/matches/mixed.json")
	config.max_ticks = 120
	_expect(driver.configure(config), "shared example driver could not install all control/observation lanes")
	var initial: Dictionary = driver.snapshot()
	for _tick: int in range(120):
		var value: Dictionary = driver.step()
		_expect(not value.failed and int(value.admission.rejected) == 0,
			"runnable example driver emitted invalid or stale envelopes")
	var completed: Dictionary = driver.snapshot()
	_expect(completed.finished and completed.admission_totals.accepted > 0 \
		and completed.admission_totals.rejected == 0, "driver did not retain cumulative admission outcomes")
	_expect(completed.event_count > 0 and completed.work.sensor_reads_total > 0 \
		and completed.work.presentation_reads_total == 0, "headless runner lost combat/sensor accounting or secretly rendered")
	_expect(initial.tick == 0 and initial.actor_prototypes.tick == 0, "driver changed a retained reset-generation snapshot")
	driver.close()
	var exchange: String = "user://thunderbowl-test-link"
	DirAccess.make_dir_recursive_absolute(exchange)
	for filename: String in ["actor-0-request.json", "actor-0-response.json"]:
		var path: String = exchange.path_join(filename)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	driver.smart_directory = exchange
	config = Contract.load_json("res://examples/thunderbowl/matches/smart_link.json")
	config.max_ticks = 30
	_expect(driver.configure(config), "smart-link runner fixture failed native setup")
	driver.step()
	var request: Dictionary = Contract.load_json(exchange.path_join("actor-0-request.json"))
	_expect(not request.is_empty() and request.observation.observation_mode == "local" \
		and not request.observation.has("oracle"), "file request omitted issued local view or leaked oracle authority")
	if not request.is_empty():
		var response: Dictionary = {}
		for key: String in ["version", "request_id", "run_id", "actor_id", "epoch", "observation_id", "observed_tick"]:
			response[key] = request[key]
		response["valid_for_ticks"] = 120
		response["intent"] = {"mode": "move_to", "goal": [200.0, 220.0], "speed": 0.5, "engage": false}
		_expect(Driver.write_json(exchange.path_join("actor-0-response.json"), response), "file response could not be committed atomically")
		for _tick: int in range(6): driver.step()
		_expect(driver.smart_statistics()[0].accepted == 1, "bounded file adapter did not admit matching asynchronous decision")
		for _tick: int in range(6): driver.step()
		_expect(driver.smart_statistics()[0].accepted == 1 and driver.smart_statistics()[0].rejected == 0,
			"unchanged response file was replayed on each policy decision")
	driver.close()


func _presentation_path() -> void:
	var scene := SceneKeyProbe.new()
	scene.set_physics_process(false)
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	_expect(scene._driver.snapshot().actor_prototypes.count == 8,
		"optional full evaluator scene did not spawn its actual mixed arena")
	_expect(scene._texture != null and scene._texture.get_width() == 256 and scene._texture.get_height() == 144,
		"visible scene did not build its bounded native material image")
	scene._canvas.size = Vector2(800.0, 600.0)
	var content: Rect2 = scene._content_rect()
	_expect(content.size.is_equal_approx(Vector2(800.0, 450.0)) \
		and content.position.is_equal_approx(Vector2(0.0, 75.0)), "scene overlay/material projection differs under letterboxing")
	var view: Dictionary = scene._driver.arena.observation(0)
	var center := Vector2(view.self_state[0] + view.self_state[35] * 0.5,
		view.self_state[1] + view.self_state[36] * 0.5)
	var pointer: Vector2 = content.position + (center + Vector2(20.0, 0.0) - Vector2(96, 96)) \
		* content.size / Vector2(256, 144)
	_expect(scene._pointer_aim_at(view, pointer).is_equal_approx(Vector2.RIGHT),
		"actual production pointer projection did not align with actor center and content rectangle")
	_expect(scene._pointer_aim_at(view, Vector2(-1.0, -1.0)) == Vector2.ZERO \
		and scene._pointer_aim_at(view, Vector2(NAN, 0.0)) == Vector2.ZERO,
		"outside/nonfinite pointer projection supplied hidden aim")
	scene.held_keys = {KEY_A: true, KEY_D: true}
	_expect(scene._any_control_held(), "opposing raw keyboard controls bypassed scene focus rearm")
	for key: int in [KEY_A, KEY_D]:
		scene.held_keys.erase(key)
		if key == KEY_A: _expect(scene._any_control_held(), "one remaining held key was treated as all controls released")
	_expect(not scene._any_control_held(), "released raw keyboard controls could not rearm")
	var tick_before: int = int(scene._driver.snapshot().tick)
	scene._physics_process(Arena.DT)
	_expect(scene._driver.snapshot().tick == tick_before + 1, "optional scene did not step the same native owner harness")
	var human_match: int = scene._match_paths.find("res://examples/thunderbowl/matches/human_metal.json")
	scene._match.select(human_match)
	scene._restart()
	scene._device.select(1)
	scene.pads = [3, 4]
	scene.axes = {Vector2i(3, JOY_AXIS_TRIGGER_RIGHT): 0.8}
	scene._rearm = false
	scene._physics_process(Arena.DT)
	_expect(scene._rearm and scene._pad_id == 3, "new held gamepad activated without a release handshake")
	scene.pads = []
	scene._physics_process(Arena.DT)
	_expect(scene._rearm and scene._pad_id == -1, "gamepad removal did not invalidate input rearm")
	scene.pads = [3]
	scene._physics_process(Arena.DT)
	_expect(scene._rearm, "held reconnected pad escaped its release handshake")
	scene.axes = {Vector2i(4, JOY_AXIS_TRIGGER_RIGHT): 0.9}
	scene.pads = [3, 4]
	scene._physics_process(Arena.DT)
	_expect(scene._rearm, "conservative prototype rearm ignored a held attached gamepad")
	scene.axes.clear()
	scene._physics_process(Arena.DT)
	_expect(not scene._rearm, "fully released attached pads could not rearm")
	scene.queue_free()
	await process_frame


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		_expect(false, "source-matched native extension is required; no mock arena acceptance")
	else:
		_configuration_and_real_rigs()
		_identity_and_command_admission()
		_locality_and_owned_views()
		_tags_and_terminal_accounting()
		_messages_and_cancellation()
		_metal_and_failed_owner()
		_determinism_and_work_report()
		_driver_and_file_adapter()
		await _presentation_path()
	print("Thunderbowl arena: ", assertions, " assertions / ", failures, " failures")
	quit(0 if failures == 0 else 1)
