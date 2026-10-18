extends SceneTree

const Session = preload("res://scripts/actor_prototype_session.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const Actuation = preload("res://scripts/actor_rig_actuation.gd")
const Fixtures = preload("res://tests/test_actor_rig_actuation.gd")
const DT: float = 1.0 / 60.0
var assertions: int = 0
var failures: int = 0


class CandidateWorld:
	extends RefCounted
	var entered: Semaphore = Semaphore.new()
	var submitted: Semaphore = Semaphore.new()
	var intercept: bool = true

	func box_collides(_origin: Vector2, _size: Vector2) -> bool:
		if intercept:
			intercept = false
			entered.post()
			submitted.wait()
		return false

	func character_box_collides(_origin: Vector2, _size: Vector2, _mode: int) -> bool:
		return false

	func has_failed() -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_and_fixed_lanes()
	_test_admission_and_latest_values()
	_test_observation_lease_and_cancel()
	_test_partial_force_receipts_and_snapshot_copy()
	_test_suspend_reset_and_slot_reuse()
	_test_candidate_concurrency()
	_test_forwarding()
	print("Actor actuator session: %d assertions, %d failures." % [assertions, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL actuator session: " + label)


func _near(actual: float, expected: float, label: String, tolerance: float = 0.0001) -> void:
	_check(is_finite(actual) and absf(actual - expected) <= tolerance,
		"%s (actual %.9f; expected %.9f)" % [label, actual, expected])


func _definition(model: StringName = &"copter", mode: StringName = &"metal",
		producer: StringName = &"policy", x: float = 300.0) -> Dictionary:
	return {"model": model, "control_mode": mode, "producer": producer, "position": Vector2(x, 300.0)}


func _command(session, command: Vector4, overrides: Dictionary = {}) -> bool:
	var context: Dictionary = session.snapshot()
	var actor_id: int = int(overrides.get("id", 0))
	var sequence: int = int(context.sequences[actor_id]) + 1 \
		if actor_id >= 0 and actor_id < context.count else 0
	return session.submit_actuator_action(actor_id, int(overrides.get("epoch", context.epoch)),
		int(overrides.get("sequence", sequence)), int(overrides.get("tick", context.tick)), command,
		int(overrides.get("lease", 12)), StringName(str(overrides.get("producer", "policy"))))


func _all_zero(values: PackedFloat32Array) -> bool:
	for value: float in values:
		if value != 0.0:
			return false
	return true


func _test_configuration_and_fixed_lanes() -> void:
	var world = Fixtures.TestWorld.new()
	var session := Session.new()
	_check(session.configure([_definition()], world), "valid direct profile installs")
	var retained: Dictionary = session.snapshot()
	for candidate: Dictionary in [
		_definition(&"runner"), _definition(&"scout"), _definition(&"copter", &"metal", &"demo"),
		_definition(&"copter", &"unknown"), _definition(&"copter", &"Metal"),
		{"model": "copter", "position": Vector2(300.0, 300.0), "control_mode": 1},
		{"model": "copter", "position": Vector2(300.0, 300.0), "control_mode": false},
	]:
		_check(not Session.valid_definitions([candidate]), "invalid fixed-lane definition rejected")
		_check(not session.configure([candidate], world), "invalid setup never replaces live session")
		_check(session.snapshot() == retained, "rejected configure preserves epoch, state and capabilities")
	var context: Dictionary = session.snapshot()
	_check(not session.submit_action(0, context.epoch, 0, context.tick, Vector2.RIGHT, true, true), "metal rejects legacy v1 intent")
	_check(not session.submit_rig_action(0, context.epoch, 0, context.tick,
		Vector2.RIGHT, Vector2.UP, 1.0, 1.0, 1.0, true, true, true), "metal rejects v2 intent")
	_check(_command(session, Vector4.ZERO, {"sequence": 0}), "wrong-lane refusals do not consume sequence")
	_check(session.configure([_definition(&"copter", &"wire")], world), "explicit wire profile installs")
	_check(not _command(session, Vector4(1.0, 0.0, 0.0, 0.0)), "wire rejects direct actuator packet")
	context = session.snapshot()
	_check(session.submit_rig_action(0, context.epoch, 0, context.tick,
		Vector2.RIGHT, Vector2.UP, 0.7, 0.0, 0.0, false, false, false), "wire retains rig input")
	_check(session.configure([{"model": &"runner", "producer": &"policy", "position": Vector2(300.0, 300.0)}], world), "missing mode defaults to wire for SetA")
	context = session.snapshot()
	_check(context.control_modes == [&"wire"] and context.actuation_profiles == [""], "wire profile metadata is explicit")
	_check(_all_zero(context.actuation_states), "wire state reserves zero-filled actuation padding")
	var definitions: Array = []
	for index: int in range(8):
		definitions.append(_definition([&"ripper", &"copter", &"gemini"][index % 3], &"metal",
			&"human" if index == 0 else &"policy", 100.0 + float(index) * 32.0))
	_check(session.configure(definitions, world), "eight direct rigs fit existing owner capacity")
	context = session.snapshot()
	_check(context.count == 8 and context.actuation_states.size() == 8 * 32 \
		and context.control_modes.size() == 8 and context.actuation_profiles.size() == 8,
		"all profile/state arrays align with eight slots")
	definitions.append(_definition())
	_check(not session.configure(definitions, world) and session.snapshot() == context, "ninth direct rig fails atomically")
	world.clear_counters()
	session.step(DT, world)
	_check(world.queries <= 8 * 96 and session.query_count_last == world.queries,
		"direct actor owner work remains explicitly bounded and counted")
	_check(_all_zero(session.snapshot().applied_actions), "v2 input rows remain zero for metal actors")


func _test_admission_and_latest_values() -> void:
	var world = Fixtures.TestWorld.new()
	var session := Session.new()
	_check(session.configure([_definition()], world), "admission fixture configured")
	var retained: Dictionary = session.snapshot()
	for overrides: Dictionary in [
		{"id": -1}, {"id": 8}, {"epoch": int(retained.epoch) - 1}, {"epoch": int(retained.epoch) + 1},
		{"sequence": -1}, {"tick": -1}, {"tick": 1}, {"lease": 0}, {"lease": 19},
		{"producer": "human"}, {"producer": "demo"}, {"producer": "other"},
	]:
		_check(not _command(session, Vector4.ZERO, overrides), "invalid identity/freshness/capacity envelope refused")
		_check(session.snapshot() == retained, "refusal preserves all mailbox receipts")
	for channel: int in range(4):
		var malformed: Vector4 = Vector4.ZERO
		malformed[channel] = INF
		_check(not _command(session, malformed), "nonfinite actuator channel refused before admission")
	_check(_command(session, Vector4(1.0, 1.0, 1.0, 1.0), {"sequence": 4}), "first finite packet admitted")
	_check(not _command(session, Vector4.ZERO, {"sequence": 4}), "duplicate sequence refused")
	_check(not _command(session, Vector4.ZERO, {"sequence": 3}), "reordered sequence refused")
	_check(_command(session, Vector4.ZERO, {"sequence": 5}), "newer neutral command replaces held actuators")
	session.step(DT, world)
	var context: Dictionary = session.snapshot()
	_check(context.sequences[0] == 5 and context.applied_sequences[0] == 5, "latest raw packet has admitted/applied receipt")
	_check(_all_zero(context.actuation_states.slice(0, 4)) and _all_zero(context.actuation_states.slice(11, 14)),
		"raw press/release compressed before a tick does not acquire a wire-style edge")
	_near(context.states[6], 1.0, "unconsumed raw power request spends no reserve")
	_check((int(context.applied_flags[0]) & (1 | 2 | 4 | 8 | 32 | 64)) == 0, "metal never invents intent button flags")
	_check(_command(session, Vector4(-5.0, 5.0, -5.0, -5.0)), "finite out-of-range unipolar input is accepted for clamping")
	session.step(DT, world)
	context = session.snapshot()
	_check(context.actuation_states.slice(0, 4) == PackedFloat32Array([0.0, 1.0, -1.0, 0.0]),
		"negative collective/brake clamp to zero; signed channels clamp independently")
	_check(_all_zero(context.applied_actions), "raw command never masquerades as a v2 movement packet")
	_check(session.configure([_definition(&"gemini")], world), "Gemini admission fixture")
	retained = session.snapshot()
	_check(not _command(session, Vector4(1.0, 1.0, 0.1, 0.0)), "Gemini reserved channel nonzero refused")
	_check(session.snapshot() == retained, "reserved-channel refusal preserves receipts")
	_check(_command(session, Vector4(-3.0, 0.5, 0.0, 0.0)), "negative Gemini unipolar value clamps rather than reverses thrust")
	session.step(DT, world)
	_check(session.snapshot().actuation_states.slice(0, 4) == PackedFloat32Array([0.0, 0.5, 0.0, 0.0]), "Gemini channel clamp readback")


func _test_observation_lease_and_cancel() -> void:
	var world = Fixtures.TestWorld.new()
	var session := Session.new()
	_check(session.configure([_definition()], world), "lease fixture configured")
	_check(_command(session, Vector4(1.0, 0.25, 0.0, 0.0), {"lease": 1}), "one-tick direct lease admitted")
	session.step(DT, world)
	var live: Dictionary = session.snapshot()
	_check(live.tick == 1 and live.applied_sequences[0] == 0 and live.lease_remaining[0] == 0,
		"lease deadline includes its last owner tick")
	var before_velocity := Vector2(live.states[2], live.states[3])
	var before_energy: float = live.states[6]
	session.step(DT, world)
	var expired: Dictionary = session.snapshot()
	_check(expired.applied_sequences[0] == -1 and (int(expired.applied_flags[0]) & Session.CANCEL) != 0,
		"expiry consumes neutral with a cancellation receipt")
	_check(expired.sequences[0] == 0 and _all_zero(expired.actuation_states.slice(0, 4)),
		"admitted sequence remains historical while actual raw input becomes zero")
	_near(expired.states[2], before_velocity.x * (1.0 - 0.08 * DT), "expired input coasts rather than invoking a wire brake")
	_near(expired.states[3], before_velocity.y * (1.0 - 0.08 * DT) + 156.0 * DT, "expired input retains passive gravity")
	_near(expired.states[6], minf(1.0, before_energy + 0.14 * DT), "expiry stops drain and permits neutral recharge")
	_check(not _command(session, Vector4.ZERO, {"tick": 0, "lease": 2}), "old observation cannot reset an expired lease on arrival")
	_check(_command(session, Vector4(0.5, 0.0, 0.0, 0.0), {"tick": 0, "lease": 3}), "old observation may use only its one remaining tick")
	session.step(DT, world)
	_check(session.snapshot().applied_sequences[0] == 1, "remaining observed lease applies at deadline")
	session.step(DT, world)
	_check(session.snapshot().applied_sequences[0] == -1, "arrival never renews the old observation's full lease")
	_check(_command(session, Vector4(0.8, 0.1, 0.0, 0.0)), "fresh direct command after expiry")
	session.step(DT, world)
	var context: Dictionary = session.snapshot()
	var epoch: int = context.epoch
	var sequence: int = context.sequences[0]
	var physical: PackedFloat32Array = context.states.slice(0, 7)
	_check(not session.cancel_input(0, epoch, &"human"), "wrong producer cannot cancel direct actor")
	_check(session.cancel_input(0, epoch, &"policy"), "assigned producer can cancel")
	_check(session.snapshot().states.slice(0, 7) == physical, "producer cancellation never touches owner physics immediately")
	session.step(DT, world)
	context = session.snapshot()
	_check(context.applied_sequences[0] == -1 and _all_zero(context.actuation_states.slice(0, 4)), "owner consumes cancellation as zero raw input")
	_check(not _command(session, Vector4.ZERO, {"sequence": sequence}), "cancel does not weaken increasing sequence rule")
	_check(_command(session, Vector4(0.5, 0.0, 0.0, 0.0), {"sequence": sequence + 1}), "fresh sequence re-arms direct input")
	_check(session.cancel_input(0, epoch, &"policy"), "cancel before replacement command")
	_check(_command(session, Vector4(0.5, 0.0, 0.0, 0.0), {"sequence": sequence + 2}), "new command after cancel may apply in same owner tick")
	session.step(DT, world)
	context = session.snapshot()
	_check(context.applied_sequences[0] == sequence + 2 and context.actuation_states[0] == 0.5 \
		and (int(context.applied_flags[0]) & Session.CANCEL) != 0, "cancel and new held input preserve both outcomes")
	for _tick: int in range(20):
		session.step(DT, world)
	_check(not _command(session, Vector4.ZERO, {"tick": 0, "lease": 18}), "maximum observation age remains enforced")


func _test_partial_force_receipts_and_snapshot_copy() -> void:
	var world = Fixtures.TestWorld.new()
	var session := Session.new()
	var definitions: Array = [_definition()]
	_check(session.configure(definitions, world), "receipt fixture configured")
	definitions[0]["control_mode"] = &"wire"
	definitions[0]["model"] = &"gemini"
	_check(session.snapshot().control_modes[0] == &"metal" and session.snapshot().models[0] == &"copter",
		"caller definition mutation cannot reconfigure installed actor")
	session.player().energy = 0.24 * DT * 0.5
	_check(_command(session, Vector4(1.0, 0.0, 0.0, 0.0), {"sequence": 7}), "limited-resource request admitted")
	session.step(DT, world)
	var context: Dictionary = session.snapshot()
	_check(context.actuation_version == 1 and context.actuation_stride == 32, "additive actuation schema version")
	_check(context.observation_stride == 16 and context.rig_observation_stride == 40 and context.action_stride == 10,
		"existing observation/action strides are unchanged")
	_check(context.applied_sequences[0] == 7 and context.actuation_profiles[0] == "copter-metal-v1", "force receipt aligns with applied sequence/profile")
	_near(context.actuation_states[0], 1.0, "clamped raw request remains visible")
	_near(context.actuation_states[4], 0.5, "actually powered actuator level differs under energy limit")
	_near(context.actuation_states[9], -312.0, "requested world force receipt")
	_near(context.actuation_states[12], -156.0, "applied world force receipt")
	_near(context.actuation_states[22], 0.5, "resource scale receipt")
	_near(context.actuation_states[31], context.states[6], "actuation and rig energy readbacks refer to same owner tick")
	var retained_states: PackedFloat32Array = context.actuation_states.duplicate()
	var mutated: PackedFloat32Array = context.actuation_states
	mutated[0] = 999.0
	context.actuation_states = mutated
	context.control_modes[0] = &"wire"
	context.actuation_profiles[0] = "wrong"
	context.actuation_capabilities[0]["channels"][0] = "tampered"
	context.capabilities[0]["actuation_profile"]["mass"] = 999.0
	var fresh: Dictionary = session.snapshot()
	_check(fresh.actuation_states == retained_states and fresh.control_modes[0] == &"metal" \
		and fresh.actuation_profiles[0] == "copter-metal-v1", "snapshot mutation cannot alter motor or profile identity")
	_check(fresh.actuation_capabilities[0]["channels"][0] == "collective" \
		and fresh.capabilities[0]["actuation_profile"]["mass"] == 1.0, "nested profile capabilities are copied")
	_check(_command(session, Vector4.ZERO), "new copied snapshot command admitted")
	session.step(DT, world)
	_check(fresh.actuation_states == retained_states, "later ticks cannot mutate retained published raw state")
	_check(session.snapshot().actuation_states != retained_states, "next publication carries new actual actuation")


func _test_suspend_reset_and_slot_reuse() -> void:
	var world = Fixtures.TestWorld.new()
	var session := Session.new()
	_check(session.configure([_definition(&"gemini", &"metal", &"human")], world), "human direct slot configured")
	_check(not _command(session, Vector4.ZERO), "policy cannot drive assigned human slot")
	_check(_command(session, Vector4(0.8, 0.6, 0.0, 0.0), {"producer": "human"}), "human uses the same raw value seam")
	session.step(DT, world)
	var live: Dictionary = session.snapshot()
	session.set_suspended(true)
	var paused: Dictionary = session.snapshot()
	_check(paused.epoch == live.epoch + 1 and paused.suspended, "suspension advances epoch")
	_check(paused.states.slice(0, 7) == live.states.slice(0, 7), "suspension preserves pose, velocity and reserve")
	_check(_all_zero(paused.actuation_states.slice(0, 20)) and paused.applied_sequences[0] == -1, "suspension clears last actuator output and receipt")
	_check(not _command(session, Vector4.ZERO, {"producer": "human"}), "suspended owner refuses new commands")
	session.step(DT, world)
	_check(session.snapshot() == paused, "suspended owner advances no actor tick")
	session.set_suspended(false)
	var resumed: Dictionary = session.snapshot()
	_check(resumed.epoch == paused.epoch + 1 and not resumed.suspended, "resume has a fresh neutral epoch")
	_check(not _command(session, Vector4(1.0, 1.0, 0.0, 0.0), {"epoch": live.epoch, "producer": "human"}), "late pre-pause output cannot re-arm")
	session.set_suspended(false)
	_check(session.snapshot().epoch == resumed.epoch, "idempotent resume does not manufacture another epoch")
	session.step(DT, world)
	_check(_all_zero(session.snapshot().actuation_states.slice(0, 4)), "resume advances neutral direct dynamics")
	_check(_command(session, Vector4(0.5, 0.5, 0.0, 0.0), {"producer": "human", "sequence": 0}), "new epoch allows sequence restart")
	var old_epoch: int = session.snapshot().epoch
	_check(session.configure([_definition(&"ripper")], world), "fresh configure reuses slot with another direct profile")
	var replaced: Dictionary = session.snapshot()
	_check(replaced.epoch == old_epoch + 1 and replaced.tick == 0 and replaced.sequences[0] == -1,
		"successful configure advances epoch exactly once and resets receipt/tick")
	_check(not session.submit_actuator_action(0, old_epoch, 999, 0, Vector4(1.0, 1.0, 0.0, 0.0), 12, &"human"),
		"reused slot rejects previous epoch/producer")
	_check(_command(session, Vector4(1.0, 0.0, 0.0, 0.0), {"sequence": 0}), "new profile accepts only fresh-lifetime values")
	session.clear()
	_check(session.snapshot().is_empty(), "clear retires all public actor state")
	_check(not session.submit_actuator_action(0, replaced.epoch, 1, 0, Vector4.ZERO), "cleared slot cannot accept stale output")
	_check(session.configure([_definition()], world), "configure after clear remains usable")
	_check(session.snapshot().epoch == replaced.epoch + 2, "clear and replacement each invalidate prior epoch once")


func _candidate_producer(session, epoch: int, observed_tick: int, entered: Semaphore, submitted: Semaphore) -> bool:
	entered.wait()
	# w=1 is valid for the old Copter, but reserved/invalid for the new Ripper.
	var admitted: bool = session.submit_actuator_action(0, epoch, 100, observed_tick,
		Vector4(0.0, 0.0, 0.0, 1.0), 12, &"policy")
	submitted.post()
	return admitted


func _test_candidate_concurrency() -> void:
	var world = Fixtures.TestWorld.new()
	var session := Session.new()
	_check(session.configure([_definition()], world), "concurrent candidate old session configured")
	var previous: Dictionary = session.snapshot()
	var candidate := CandidateWorld.new()
	var producer := Thread.new()
	var error: Error = producer.start(_candidate_producer.bind(session, previous.epoch,
		previous.tick, candidate.entered, candidate.submitted))
	_check(error == OK, "bounded producer thread starts")
	if error != OK:
		return
	_check(session.configure([_definition(&"ripper")], candidate), "candidate World is prepared under owner while producer submits")
	var old_admitted: bool = bool(producer.wait_to_finish())
	_check(old_admitted, "old profile remains valid until atomic configure commit")
	var committed: Dictionary = session.snapshot()
	_check(committed.epoch == previous.epoch + 1 and committed.sequences[0] == -1,
		"configure invalidates and discards old-epoch candidate-time input")
	_check(committed.models[0] == &"ripper" and committed.actuation_profiles[0] == "ripper-metal-v1",
		"new slot model and profile publish coherently")
	_check(not session.submit_actuator_action(0, previous.epoch, 101, 0, Vector4.ZERO), "old producer output cannot enter replacement slot")
	_check(not _command(session, Vector4(0.0, 0.0, 0.0, 1.0)), "new profile reserved channel is enforced after commit")
	session.step(DT, candidate)
	_check(session.snapshot().applied_sequences[0] == -1 and _all_zero(session.snapshot().actuation_states.slice(0, 4)),
		"candidate-time input never drives replacement actor")


func _test_forwarding() -> void:
	var worker := Worker.new()
	var world = Fixtures.TestWorld.new()
	_check(worker._actor_session.configure([_definition(&"copter", &"metal", &"human")], world), "owner-local worker forwarding fixture")
	var context: Dictionary = worker._actor_session.snapshot()
	_check(not worker.submit_actor_actuator_action(0, context.epoch, 0, context.tick,
		Vector4(0.5, 0.2, 0.0, 0.0)), "forwarder retains producer identity instead of overriding it")
	_check(worker.submit_actor_actuator_action(0, context.epoch, 0, context.tick,
		Vector4(0.5, 0.2, 0.0, 0.0), 1, &"human"), "forwarder preserves raw command and all envelope fields")
	worker._actor_session.step(DT, world)
	context = worker._actor_session.snapshot()
	_check(context.applied_sequences[0] == 0 and context.actuation_states[0] == 0.5,
		"forwarded direct packet reaches the actual owner motor")
	_near(context.actuation_states[1], 0.2, "forwarded second raw channel")
	worker._actor_session.step(DT, world)
	_check(worker._actor_session.snapshot().applied_sequences[0] == -1, "forwarder preserves one-tick lease")
