extends SceneTree

const Session = preload("res://scripts/actor_prototype_session.gd")
const Legacy = preload("res://scripts/actor_prototype.gd")
const Rig = preload("res://scripts/actor_rig_motor.gd")
const Fixtures = preload("res://tests/test_actor_rigs.gd")
const DT: float = 1.0 / 60.0
const LEGACY_IDS: Array[StringName] = [&"runner", &"skimmer", &"crawler"]
const ALL_IDS: Array[StringName] = [
	&"runner", &"skimmer", &"crawler",
	&"scout", &"scrabbler", &"ripper", &"groundeffect", &"digger",
	&"copter", &"pouncer", &"dropbot", &"lineshank",
	&"walljumper", &"clamberer", &"swinger", &"rocketjumper",
	&"springjack", &"gyrocrate", &"bellows", &"winchbug", &"magpie", &"skatesail",
	&"astra", &"claude", &"luna", &"qwen", &"bonsai", &"jev", &"gemini",
]

var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error("ACTOR_RIG_SESSION: " + message)


func _world():
	var world = Fixtures.RigWorld.new()
	world.floor_y = 400.0
	return world


func _definition(model: StringName, producer: StringName = &"policy", x: float = 180.0) -> Dictionary:
	var size := Vector2(8.0, 14.0)
	if model not in LEGACY_IDS:
		var actor = Rig.new()
		actor.configure_model(model)
		size = actor.body_size
	return {"model": model, "producer": producer, "position": Vector2(x, 400.0 - size.y)}


func _command(session: CyberActorPrototypeSession, overrides: Dictionary = {}) -> bool:
	var context: Dictionary = session.snapshot()
	var actor_id: int = int(overrides.get("id", 0))
	var default_sequence: int = int(context.sequences[actor_id]) + 1 \
		if actor_id >= 0 and actor_id < int(context.count) else 0
	return session.submit_rig_action(actor_id, int(overrides.get("epoch", context.epoch)),
		int(overrides.get("sequence", default_sequence)), int(overrides.get("tick", context.tick)),
		overrides.get("move", Vector2.ZERO), overrides.get("aim", Vector2.RIGHT),
		float(overrides.get("effort", 0.7)), float(overrides.get("trim", 0.0)),
		float(overrides.get("reel", 0.0)), bool(overrides.get("primary", false)),
		bool(overrides.get("secondary", false)), bool(overrides.get("auxiliary", false)),
		int(overrides.get("lease", 12)), StringName(str(overrides.get("producer", "policy"))))


func _catalog_capacity_and_shape() -> void:
	_expect(Session.MODEL_IDS == LEGACY_IDS, "v1 model catalogue no longer means the original three actors")
	_expect(Session.RIG_IDS == ALL_IDS, "rig catalogue order/count differs from the registered 29 IDs")
	var session := Session.new()
	var world = _world()
	var set_names: Array[String] = []
	for model: StringName in ALL_IDS:
		_expect(session.configure([_definition(model)], world), "catalogue rig failed session configuration: " + str(model))
		var context: Dictionary = session.snapshot()
		_expect(int(context.version) == 1 and int(context.observation_stride) == 16 \
			and context.states.size() == 16, "legacy snapshot schema changed when a rig was selected")
		_expect(int(context.get("rig_version", 0)) == 2 \
			and int(context.get("rig_observation_stride", 0)) == 40 \
			and context.get("rig_states", []).size() == 40,
			"extended rig snapshot has no versioned fixed 40-feature stride")
		_expect(context.get("applied_actions", []).size() == 10 \
			and context.get("applied_sequences", []).size() == 1 \
			and context.get("applied_flags", []).size() == 1 and int(context.get("action_stride", 0)) == 10,
			"applied action publication has no fixed 10-feature stride or sequence identity")
		_expect(context.get("rig_sets", []).size() == 1 \
			and context.get("rig_capabilities", []).size() == 1,
			"rig set/capability metadata is not aligned with actor slots")
		if context.get("rig_states", []).size() != 40 or context.get("rig_sets", []).size() != 1:
			continue
		_expect(context.states == context.rig_states.slice(0, 16), "rig publication changed its common 16-feature prefix")
		set_names.append(str(context.rig_sets[0]))
		if model in LEGACY_IDS:
			_expect(session.player().get_script() == Legacy, "Set A was routed through the generalized motor")
			_expect(float(context.rig_states[35]) == 8.0 and float(context.rig_states[36]) == 14.0,
				"legacy rig padding changed the original body dimensions")
			for index: int in range(16, 40):
				if index not in [35, 36]:
					_expect(float(context.rig_states[index]) == 0.0, "Set A padding invented a new mechanic state")
		else:
			_expect(session.player().get_script() == Rig, "new rig did not use the explicit generalized owner motor")
		var retained: Dictionary = context.duplicate(true)
		var malformed: Array = [
			[42], [{}], [{"model": "unknown", "position": Vector2.ONE}],
			[{"model": model, "producer": "unknown", "position": Vector2.ONE}],
			[{"model": model, "position": [1, 2]}],
			[{"model": model, "position": Vector2(NAN, 0.0)}],
			[{"model": model, "position": Vector2(0.0, INF)}],
			[{"model": model, "position": Vector2(1023.0, 200.0)}],
			[{"model": model, "position": Vector2(200.0, 1023.0)}],
		]
		for candidate: Array in malformed:
			_expect(not session.configure(candidate, world), "malformed/out-of-bounds rig definition was admitted")
			_expect(session.snapshot() == retained, "refused rig setup partially replaced the live owner session")
	if set_names.size() == 29:
		var cursor: int = 0
		var unique_sets: Dictionary = {}
		for set_count: int in [3, 5, 4, 4, 6, 7]:
			var set_name: String = set_names[cursor]
			_expect(not set_name.is_empty() and not unique_sets.has(set_name), "rig sets lost their distinct identities")
			unique_sets[set_name] = true
			for index: int in range(cursor, cursor + set_count):
				_expect(set_names[index] == set_name, "rig belongs to the wrong catalogue set")
			cursor += set_count
		_expect(unique_sets.keys() == ["setA", "setB", "setF", "setY", "setU", "setV"],
			"catalogue set identifiers changed their externally published spelling/order")

	var definitions: Array = []
	for index: int in range(8):
		definitions.append(_definition(ALL_IDS[index * 3], &"policy", 100.0 + float(index) * 30.0))
	_expect(session.configure(definitions, world), "mixed eight-rig capacity was refused")
	var retained: Dictionary = session.snapshot()
	definitions.append(_definition(&"gemini"))
	_expect(not session.configure(definitions, world) and session.snapshot() == retained,
		"ninth mixed rig bypassed capacity or damaged the installed session")
	world.clear_counters()
	session.step(DT, world)
	var full: Dictionary = session.snapshot()
	_expect(full.states.size() == 8 * 16 and full.rig_states.size() == 8 * 40 \
		and full.applied_actions.size() == 8 * 10, "full-capacity publication has inconsistent array strides")
	_expect(world.queries <= 8 * 96 and session.query_count_last == world.queries,
		"mixed-capacity owner work exceeded its cap or escaped aggregate telemetry")


func _legacy_independent_oracle() -> void:
	for model: StringName in LEGACY_IDS:
		for use_extended: bool in [false, true]:
			var world = _world()
			var oracle_world = _world()
			var definition: Dictionary = _definition(model)
			var session := Session.new()
			_expect(session.configure([definition], world), "legacy parity session setup failed")
			var oracle := Legacy.new()
			oracle.configure_model(model)
			oracle.reset(definition.position)
			oracle.recover_invalid_spawn(oracle_world)
			for tick: int in range(120):
				var movement := Vector2(1.0 if tick % 60 < 30 else -1.0, -0.5)
				var primary: bool = tick % 40 < 4
				var secondary: bool = tick % 55 == 0
				var context: Dictionary = session.snapshot()
				var admitted: bool
				if use_extended:
					admitted = _command(session, {"move": movement, "aim": Vector2(-0.6, 0.8),
						"effort": 0.25, "trim": 0.8, "reel": -1.0, "primary": primary,
						"secondary": secondary, "auxiliary": tick % 7 < 3})
				else:
					admitted = session.submit_action(0, int(context.epoch), tick, int(context.tick),
						movement, primary, secondary, 12, &"policy")
				_expect(admitted, "valid v1/v2 legacy action was refused")
				world.clear_counters()
				oracle_world.clear_counters()
				session.step(DT, world)
				oracle.simulate_action(DT, movement, primary, secondary, oracle_world)
				_expect(session.snapshot().states == oracle.observation(),
					"Set A behavior changed against its independent original motor oracle: " + str(model))
				_expect(world.queries == oracle_world.queries and world.material_reads == 0 \
					and world.writes == 0 and world.disturbance_calls == oracle_world.disturbance_calls,
					"Set A adapter work or material effects changed through the new session")


func _admission_and_applied_identity() -> void:
	var world = _world()
	var control_world = _world()
	var session := Session.new()
	var control := Session.new()
	session.configure([_definition(&"astra")], world)
	control.configure([_definition(&"astra")], control_world)
	var action: Dictionary = {"sequence": 1, "move": Vector2(0.4, -0.2),
		"aim": Vector2(-0.6, 0.8), "effort": 0.75, "trim": 0.25, "reel": -0.5,
		"primary": true, "auxiliary": true}
	var initial: Dictionary = session.snapshot()
	_expect(_command(session, action) and _command(control, action), "valid extended command was refused")
	var admitted: Dictionary = session.snapshot()
	_expect(int(admitted.sequences[0]) == 1 and admitted.applied_sequences == initial.applied_sequences \
		and admitted.applied_actions == initial.applied_actions and admitted.rig_states == initial.rig_states,
		"admission published a command as already applied before an owner tick")
	var refusal_cases: Array[Dictionary] = [
		{"id": -1}, {"id": 1}, {"epoch": int(admitted.epoch) - 1},
		{"sequence": -1}, {"sequence": 0}, {"sequence": 1},
		{"tick": -1}, {"tick": 1}, {"lease": 0}, {"lease": 19},
		{"producer": "human"}, {"producer": "demo"}, {"producer": "unknown"},
		{"move": Vector2(NAN, 1.0)}, {"move": Vector2(1.0, INF)},
		{"aim": Vector2(NAN, 1.0)}, {"aim": Vector2(1.0, -INF)},
		{"effort": NAN}, {"effort": INF}, {"trim": NAN}, {"trim": -INF},
		{"reel": NAN}, {"reel": INF},
	]
	for refusal: Dictionary in refusal_cases:
		var command: Dictionary = action.duplicate(true)
		command.sequence = 2
		command.merge(refusal, true)
		_expect(not _command(session, command), "invalid extended command bypassed atomic admission")
		_expect(session.snapshot() == admitted, "rejected extended command changed published mailbox or actor state")
	var before_queries: int = world.queries
	for invalid_delta: float in [0.0, -DT, NAN, INF]:
		session.step(invalid_delta, world)
		_expect(session.snapshot() == admitted and world.queries == before_queries,
			"invalid owner timestep consumed extra control edges/leases")
	session.step(DT, world)
	control.step(DT, control_world)
	var applied: Dictionary = session.snapshot()
	_expect(applied.rig_states == control.snapshot().rig_states \
		and applied.applied_actions == control.snapshot().applied_actions,
		"rejected extra-axis command corrupted the previously admitted action or edge latches")
	_expect(int(applied.applied_sequences[0]) == 1, "owner did not publish the sequence it actually applied")
	var expected := PackedFloat32Array([0.4, -0.2, -0.6, 0.8, 0.75, 0.25, -0.5, 1.0, 0.0, 1.0])
	_expect(applied.applied_actions == expected, "applied extended action lost, reordered or conflated an independent axis")
	_expect(_command(session, {"sequence": 2, "move": Vector2.LEFT}), "refused command consumed its otherwise available sequence")
	var newer: Dictionary = session.snapshot()
	_expect(int(newer.sequences[0]) == 2 and int(newer.applied_sequences[0]) == 1 \
		and newer.applied_actions == applied.applied_actions,
		"newer mailbox admission relabelled the previously applied action")
	session.step(DT, world)
	_expect(int(session.snapshot().applied_sequences[0]) == 2, "newer action never acquired its applied identity")
	for tick: int in range(20):
		session.step(DT, world)
	_expect(not _command(session, {"sequence": 3, "tick": 0, "lease": 18}),
		"stale extended inference gained freshness at arrival")
	var current_tick: int = int(session.snapshot().tick)
	_expect(not _command(session, {"sequence": 3, "tick": current_tick - 2, "lease": 2}),
		"already-expired observation-relative extended lease was accepted")
	_expect(_command(session, {"sequence": 3, "move": Vector2(1.0e30, -1.0e30),
		"aim": Vector2(-1.0e30, 1.0e30), "effort": 1.0e30, "trim": -1.0e30, "reel": 1.0e30}),
		"large finite policy values could not be safely bounded")
	session.step(DT, world)
	var bounded: PackedFloat32Array = session.snapshot().applied_actions
	for value: float in bounded:
		_expect(is_finite(value) and absf(value) <= 1.00001, "extended action normalization overflowed its finite range")
	_expect(_command(session, {"aim": Vector2(1.0e-25, -1.0e-25)}), "tiny finite aim was refused")
	session.step(DT, world)
	var tiny: PackedFloat32Array = session.snapshot().applied_actions
	_expect(Vector2(tiny[2], tiny[3]).distance_to(Vector2(1.0, -1.0).normalized()) < 0.00001,
		"tiny independent aim lost its direction through squared-length underflow")
	_expect(_command(session, {"aim": Vector2.ZERO}), "explicit zero aim was refused")
	session.step(DT, world)
	var zero: PackedFloat32Array = session.snapshot().applied_actions
	_expect(zero[2] == 0.0 and zero[3] == 0.0, "zero submitted aim was replaced by invented producer intent")
	var old_epoch: int = int(session.snapshot().epoch)
	session.clear()
	_expect(session.snapshot().is_empty() and not session.active(), "clear retained extended actor publication")
	_expect(not session.submit_rig_action(0, old_epoch, 99, current_tick,
		Vector2.RIGHT, Vector2.UP, 1.0, 1.0, 1.0, true, true, true),
		"cleared rig accepted late extended input")
	session.configure([_definition(&"astra")], world)
	_expect(not _command(session, {"epoch": old_epoch, "sequence": 99}),
		"reused actor slot admitted an action for its old incarnation")


func _producer_equivalence() -> void:
	for model: StringName in ALL_IDS:
		var human_world = _world()
		var policy_world = _world()
		var human := Session.new()
		var policy := Session.new()
		human.configure([_definition(model, &"human")], human_world)
		policy.configure([_definition(model, &"policy")], policy_world)
		for tick: int in range(45):
			var action: Dictionary = {"move": Vector2(0.8 if tick < 24 else -0.6, -0.4),
				"aim": Vector2(-0.6, -0.8), "effort": 0.8, "trim": 0.4,
				"reel": -0.75, "primary": tick % 15 < 3, "secondary": tick % 19 == 0,
				"auxiliary": tick % 23 < 2, "producer": "human"}
			_expect(_command(human, action), "human extended action was refused")
			action.producer = "policy"
			_expect(_command(policy, action), "policy extended action was refused")
			human.step(DT, human_world)
			policy.step(DT, policy_world)
			var a: Dictionary = human.snapshot()
			var b: Dictionary = policy.snapshot()
			_expect(a.states == b.states and a.rig_states == b.rig_states \
				and a.applied_actions == b.applied_actions,
				"human/policy producers obeyed different rules for " + str(model))
			_expect(human_world.cells == policy_world.cells,
				"producer identity changed bounded material effects")


func _legacy_edges_through_v2() -> void:
	var world = _world()
	var session := Session.new()
	session.configure([_definition(&"runner")], world)
	_expect(_command(session, {"primary": true}) and _command(session, {"primary": false}),
		"extended quick primary tap was refused")
	session.step(DT, world)
	_expect(session.player().velocity.y < 0.0, "v2 mailbox lost a complete primary tap between ticks")
	session.configure([_definition(&"runner")], world)
	for tick: int in range(55):
		_command(session, {"move": Vector2.RIGHT, "secondary": true})
		session.step(DT, world)
	_expect(not session.player().secondary_active, "v2 held dash repeated after cooldown")
	_command(session, {"move": Vector2.RIGHT, "secondary": false})
	_command(session, {"move": Vector2.RIGHT, "secondary": true})
	session.step(DT, world)
	_expect(session.player().secondary_active, "v2 release-repress lost its new secondary edge")
	var before: Dictionary = session.snapshot()
	var cooldown: float = session.player().cooldown_remaining
	session.set_suspended(true)
	var paused: Dictionary = session.snapshot()
	_expect(int(paused.epoch) != int(before.epoch), "pause retained extended action epoch")
	_expect(not _command(session, {"primary": true, "secondary": true, "auxiliary": true}),
		"suspended session admitted extended action")
	for tick: int in range(20):
		session.step(DT, world)
	_expect(session.snapshot() == paused and session.player().cooldown_remaining == cooldown,
		"paused rig consumed ticks, changed publication or refunded cooldown")
	session.set_suspended(false)
	_expect(not _command(session, {"epoch": before.epoch, "sequence": 999}),
		"pre-pause extended action survived new input epoch")
	_command(session, {"move": Vector2.LEFT})
	session.step(DT, world)
	_expect(session.player().cooldown_remaining > 0.0 and not session.player().secondary_active,
		"pause/resume repeated or refunded an extended dash")


func _auxiliary_edges_and_expiry() -> void:
	var world = _world()
	var session := Session.new()
	session.configure([_definition(&"qwen")], world)
	var initial_mode: float = float(session.snapshot().rig_states[27])
	_expect(_command(session, {"auxiliary": true}) and _command(session, {"auxiliary": false}),
		"complete auxiliary tap was refused")
	session.step(DT, world)
	var first: Dictionary = session.snapshot()
	_expect((int(first.applied_flags[0]) & Session.AUXILIARY_PRESSED) != 0 \
		and (int(first.applied_flags[0]) & Session.AUXILIARY_HELD) == 0 \
		and float(first.applied_actions[9]) == 0.0,
		"consumed readback lost a pressed-but-released auxiliary edge")
	_expect(float(first.rig_states[27]) != initial_mode, "auxiliary quick tap did not change Qwen's actual locomotion mode")
	_command(session, {"auxiliary": true})
	session.step(DT, world)
	var held_mode: float = float(session.snapshot().rig_states[27])
	for tick: int in range(8):
		_command(session, {"auxiliary": true})
		session.step(DT, world)
		var held: Dictionary = session.snapshot()
		_expect((int(held.applied_flags[0]) & Session.AUXILIARY_HELD) != 0 \
			and (int(held.applied_flags[0]) & Session.AUXILIARY_PRESSED) == 0,
			"held auxiliary generated extra rising edges")
		_expect(float(held.rig_states[27]) == held_mode, "held Qwen toggle switched modes repeatedly")
	_command(session, {"auxiliary": false})
	_command(session, {"auxiliary": true})
	session.step(DT, world)
	_expect((int(session.snapshot().applied_flags[0]) & Session.AUXILIARY_PRESSED) != 0,
		"auxiliary release-repress was not OR-latched")

	# Several rises coalesce to exactly one edge per button, with the latest
	# held values. This remains bounded even if a producer runs much faster.
	session.configure([_definition(&"qwen")], world)
	for packet: int in range(20):
		_command(session, {"primary": packet % 2 == 0, "secondary": packet % 2 == 0,
			"auxiliary": packet % 2 == 0})
	session.step(DT, world)
	var coalesced: Dictionary = session.snapshot()
	_expect((int(coalesced.applied_flags[0]) & 111) == 76,
		"fast action producer did not coalesce three independent edges and latest held values")
	_expect(coalesced.applied_actions.slice(7, 10) == PackedFloat32Array([0.0, 0.0, 0.0]),
		"fast producer left stale held buttons in consumed action")

	session.configure([_definition(&"pouncer")], world)
	for tick: int in range(12):
		_command(session, {"primary": true, "aim": Vector2.UP, "lease": 1})
		session.step(DT, world)
	_expect(float(session.snapshot().rig_states[25]) > 0.0, "charged-leap expiry fixture never accumulated preload")
	world.clear_counters()
	session.step(DT, world)
	var expired: Dictionary = session.snapshot()
	_expect(float(expired.rig_states[25]) == 0.0 and session.player().velocity.y >= 0.0,
		"expired primary lease fired a charged leap as if the user deliberately released")
	_expect(int(expired.applied_sequences[0]) == -1 and expired.applied_actions == PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]) \
		and (int(expired.applied_flags[0]) & Session.CANCEL) != 0,
		"expired rig command retained non-neutral extra controls or a live applied sequence")
	_expect(world.writes == 0, "expired charged action emitted an owner effect")

	for cancel_kind: String in ["cancel", "pause"]:
		session.configure([_definition(&"pouncer")], world)
		for tick: int in range(12):
			_command(session, {"primary": true, "aim": Vector2.UP})
			session.step(DT, world)
		var before: Dictionary = session.snapshot()
		_expect(float(before.rig_states[25]) > 0.0, "charge cancellation fixture has no preload")
		if cancel_kind == "cancel":
			_expect(not session.cancel_input(0, int(before.epoch), &"human"), "wrong producer cancelled a charged policy action")
			_expect(session.cancel_input(0, int(before.epoch), &"policy"), "assigned producer could not cancel a charged action")
			_expect(session.snapshot().applied_actions == before.applied_actions,
				"producer cancellation rewrote consumed history before owner stepping")
		else:
			session.set_suspended(true)
			session.set_suspended(false)
		session.step(DT, world)
		_expect(float(session.snapshot().rig_states[25]) == 0.0 and session.player().velocity.y >= 0.0,
			cancel_kind + " replayed stored preload as a leap")
		_expect(int(session.snapshot().applied_sequences[0]) == -1,
			cancel_kind + " retained a consumed command in the new neutral lifetime")


func _publication_and_timing() -> void:
	var world = _world()
	var session := Session.new()
	session.configure([_definition(&"gemini")], world)
	var retained: Dictionary = session.snapshot()
	var original: Dictionary = retained.duplicate(true)
	for tick: int in range(12):
		_command(session, {"move": Vector2.UP, "aim": Vector2.LEFT, "primary": true, "trim": 0.5})
		session.step(DT, world)
	_expect(retained == original, "later rig/session stepping mutated an old publication")
	retained.rig_states[16] = -999.0
	retained.applied_actions[2] = -999.0
	retained.applied_sequences[0] = 999
	retained.rig_sets[0] = "wrong"
	retained.rig_capabilities[0].id = "wrong"
	var fresh: Dictionary = session.snapshot()
	_expect(float(fresh.rig_states[16]) != -999.0 and float(fresh.applied_actions[2]) != -999.0 \
		and int(fresh.applied_sequences[0]) != 999 and str(fresh.rig_sets[0]) != "wrong" \
		and str(fresh.rig_capabilities[0].id) == "gemini",
		"extended publication exposed mutable owner storage")
	var decoded: Variant = JSON.parse_string(JSON.stringify(fresh))
	_expect(decoded is Dictionary, "extended publication failed JSON round trip")
	if decoded is Dictionary:
		for field: String in ["states", "rig_states", "applied_actions", "sequences", "applied_sequences", "applied_flags", "lease_remaining"]:
			_expect(decoded[field] is Array and decoded[field].size() == fresh[field].size(),
				"packed publication field did not serialize as a usable numeric array: " + field)
			for value: Variant in decoded[field]:
				_expect((value is int or value is float) and is_finite(float(value)),
					"JSON rig publication contains nonnumeric/nonfinite values")
	var definitions: Array = []
	for index: int in range(8):
		definitions.append(_definition(ALL_IDS[3 + index * 3], &"demo", 100.0 + float(index) * 30.0))
	session.configure(definitions, world)
	const STEPS: int = 600
	var maximum_queries: int = 0
	var maximum_reads: int = 0
	var checksum: float = 0.0
	var start: int = Time.get_ticks_usec()
	for tick: int in range(STEPS):
		world.clear_counters()
		session.step(DT, world)
		var published: Dictionary = session.snapshot()
		checksum += float(published.rig_states[0]) + float(published.applied_actions[4])
		maximum_queries = maxi(maximum_queries, world.queries)
		maximum_reads = maxi(maximum_reads, world.material_reads)
	var elapsed: int = Time.get_ticks_usec() - start
	_expect(maximum_queries <= 8 * 96 and maximum_reads <= 8 * 128,
		"eight-rig owner plus publication exceeded its aggregate query envelope")
	print("ACTOR_RIG_SESSION_TIMING ", JSON.stringify({"actors": 8, "steps": STEPS,
		"mean_microseconds": float(elapsed) / float(STEPS), "maximum_occupancy_queries": maximum_queries,
		"maximum_material_reads": maximum_reads, "publication_checksum": checksum,
		"scope": "headless host / mixed scripted demos + owner step + copied v1/v2/action snapshots / mock World / informational"}))


func _run() -> void:
	_catalog_capacity_and_shape()
	_legacy_independent_oracle()
	_admission_and_applied_identity()
	_producer_equivalence()
	_legacy_edges_through_v2()
	_auxiliary_edges_and_expiry()
	_publication_and_timing()
	print("ACTOR_RIG_SESSION: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
