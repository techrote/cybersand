extends SceneTree

const Session = preload("res://scripts/actor_prototype_session.gd")
const ActorFixtures = preload("res://tests/test_actor_prototypes.gd")
const DT: float = 1.0 / 60.0
const MODELS: Array[StringName] = [&"runner", &"skimmer", &"crawler"]

var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error("ACTOR_SESSION: " + message)


func _world():
	var world = ActorFixtures.FixtureWorld.new()
	world.floor_y = 120.0
	return world


func _definition(model: StringName = &"runner", producer: StringName = &"policy") -> Dictionary:
	return {"model": model, "producer": producer, "position": Vector2(60.0, 106.0)}


func _submit(
	session: CyberActorPrototypeSession,
	movement: Vector2 = Vector2.ZERO,
	primary: bool = false,
	secondary: bool = false,
	actor_id: int = 0,
	producer: StringName = &"policy",
	lease: int = 12
) -> bool:
	var context: Dictionary = session.snapshot()
	return session.submit_action(actor_id, int(context.epoch),
		int(context.sequences[actor_id]) + 1, int(context.tick),
		movement, primary, secondary, lease, producer)


func _configuration_and_admission() -> void:
	var world = _world()
	var session := Session.new()
	var definitions: Array = []
	for index: int in range(8):
		var definition: Dictionary = _definition(MODELS[index % 3])
		definition.position.x += float(index) * 20.0
		definitions.append(definition)
	_expect(session.configure(definitions, world), "eight actors were refused")
	_expect(int(session.snapshot().count) == 8, "admitted capacity was not eight actors")
	var retained: Dictionary = session.snapshot()
	var over_capacity: Array = definitions.duplicate(true)
	over_capacity.append(_definition())
	_expect(not session.configure(over_capacity, world), "ninth actor bypassed capacity")
	_expect(session.snapshot() == retained, "capacity refusal replaced the current session")
	var invalid: Array = [
		[42], [{}], [{"model": "wrong", "position": Vector2.ONE}],
		[{"model": "runner", "producer": "wrong", "position": Vector2.ONE}],
		[{"model": "runner", "position": [1, 2]}],
		[{"model": "runner", "position": Vector2(NAN, 0.0)}],
		[{"model": "runner", "position": Vector2(1.0, INF)}],
		[{"model": "runner", "position": Vector2(-1.0, 0.0)}],
		[{"model": "runner", "position": Vector2(1024.0, 0.0)}],
	]
	for candidate: Array in invalid:
		_expect(not session.configure(candidate, world), "malformed actor definitions were admitted")
		_expect(session.snapshot() == retained, "malformed definitions damaged the current session")
	session.step(DT, world)
	_expect(session.query_count_last <= 8 * 32, "eight actors exceeded aggregate occupancy budget")
	_expect(session.snapshot().states.size() == 8 * 16, "capacity observation is not fixed stride")

	session.configure([_definition()], world)
	var context: Dictionary = session.snapshot()
	var epoch: int = int(context.epoch)
	_expect(session.submit_action(0, epoch, 1, 0, Vector2.RIGHT, false, false), "valid policy action was refused")
	var admitted: Dictionary = session.snapshot()
	var refusals: Array[bool] = [
		session.submit_action(-1, epoch, 2, 0, Vector2.RIGHT, false, false),
		session.submit_action(1, epoch, 2, 0, Vector2.RIGHT, false, false),
		session.submit_action(0, epoch - 1, 2, 0, Vector2.RIGHT, false, false),
		session.submit_action(0, epoch, -1, 0, Vector2.RIGHT, false, false),
		session.submit_action(0, epoch, 1, 0, Vector2.LEFT, false, false),
		session.submit_action(0, epoch, 0, 0, Vector2.LEFT, false, false),
		session.submit_action(0, epoch, 2, -1, Vector2.RIGHT, false, false),
		session.submit_action(0, epoch, 2, 1, Vector2.RIGHT, false, false),
		session.submit_action(0, epoch, 2, 0, Vector2(NAN, 0.0), false, false),
		session.submit_action(0, epoch, 2, 0, Vector2(0.0, INF), false, false),
		session.submit_action(0, epoch, 2, 0, Vector2.RIGHT, false, false, 0),
		session.submit_action(0, epoch, 2, 0, Vector2.RIGHT, false, false, 19),
		session.submit_action(0, epoch, 2, 0, Vector2.RIGHT, false, false, 12, &"human"),
	]
	for accepted: bool in refusals:
		_expect(not accepted, "invalid actor/epoch/sequence/tick/lease/producer action was accepted")
	_expect(session.snapshot() == admitted, "rejected action mutated accepted mailbox state")
	var queries_before: int = world.queries
	for invalid_delta: float in [0.0, -DT, NAN, INF]:
		session.step(invalid_delta, world)
		_expect(session.snapshot() == admitted and world.queries == queries_before,
			"invalid timestep consumed action edges, leases, or actor work")
	session.step(DT, world)
	_expect(session.player().velocity.x > 0.0, "refusal corrupted the last accepted direction")
	for tick: int in range(20):
		session.step(DT, world)
	_expect(not session.submit_action(0, epoch, 2, 0, Vector2.RIGHT, false, false, 18), "stale inference output gained a new lease on arrival")
	context = session.snapshot()
	_expect(not session.submit_action(0, epoch, 2, int(context.tick) - 2, Vector2.RIGHT, false, false, 2), "already-expired observation-relative lease was admitted")
	_expect(session.submit_action(0, epoch, 2, int(context.tick), Vector2(1.0e30, -1.0e30), false, false, 18), "bounded finite action clamping was not available")
	session.step(DT, world)
	_expect(session.player().velocity.is_finite(), "large finite policy output overflowed control")
	var old_epoch: int = int(session.snapshot().epoch)
	session.clear()
	_expect(session.snapshot().is_empty() and not session.active(), "clear retained an actor publication")
	_expect(not session.submit_action(0, old_epoch, 3, 0, Vector2.RIGHT, true, true), "cleared actor accepted late input")
	_expect(session.configure([_definition()], world), "fresh session after clear failed")
	_expect(not session.submit_action(0, old_epoch, 4, 0, Vector2.RIGHT, true, true), "old incarnation input was accepted after slot reuse")


func _producer_equivalence_and_axes() -> void:
	var world = _world()
	for model: StringName in MODELS:
		var session := Session.new()
		_expect(session.configure([_definition(model, &"human"), _definition(model, &"policy")], world), "paired producer setup failed")
		for tick: int in range(90):
			var movement := Vector2(1.0 if tick < 45 else -1.0, -0.5)
			_expect(_submit(session, movement, tick % 40 < 4, tick % 50 == 0, 0, &"human"), "human producer lost valid action")
			_expect(_submit(session, movement, tick % 40 < 4, tick % 50 == 0, 1, &"policy"), "policy producer lost valid action")
			session.step(DT, world)
		var states: PackedFloat32Array = session.snapshot().states
		_expect(states.slice(0, 16) == states.slice(16, 32), "human and policy inputs obeyed different motor rules")

	for model: StringName in [&"runner", &"crawler"]:
		var straight := Session.new()
		var diagonal := Session.new()
		straight.configure([_definition(model)], world)
		diagonal.configure([_definition(model)], world)
		for tick: int in range(20):
			_submit(straight, Vector2.RIGHT)
			_submit(diagonal, Vector2.ONE)
			straight.step(DT, world)
			diagonal.step(DT, world)
		_expect(straight.snapshot().states == diagonal.snapshot().states, "ignored Y reduced ground-mover speed")


func _edges_expiry_and_pause() -> void:
	var world = _world()
	var session := Session.new()
	session.configure([_definition()], world)
	_expect(_submit(session, Vector2.ZERO, true), "quick primary press was refused")
	_expect(_submit(session, Vector2.ZERO, false), "quick primary release was refused")
	session.step(DT, world)
	_expect(session.player().velocity.y < 0.0, "press-release between ticks lost its latched edge")

	session.configure([_definition()], world)
	for tick: int in range(120):
		_submit(session, Vector2.ZERO, true)
		session.step(DT, world)
	_expect(session.player().grounded, "held primary automatically repeated jumps")
	_submit(session, Vector2.ZERO, false)
	_submit(session, Vector2.ZERO, true)
	session.step(DT, world)
	_expect(session.player().velocity.y < 0.0, "release-repress between ticks lost its new edge")

	session.configure([_definition()], world)
	for tick: int in range(55):
		_submit(session, Vector2.RIGHT, false, true)
		session.step(DT, world)
	_expect(not session.player().secondary_active, "held dash repeated after its cooldown")
	_submit(session, Vector2.RIGHT, false, false)
	_submit(session, Vector2.RIGHT, false, true)
	session.step(DT, world)
	_expect(session.player().secondary_active, "release-repress dash edge was not OR-latched")
	var cooldown: float = session.player().cooldown_remaining
	var before_pause: Dictionary = session.snapshot()
	session.set_suspended(true)
	var paused: Dictionary = session.snapshot()
	_expect(int(paused.epoch) != int(before_pause.epoch), "pause did not invalidate the input epoch")
	_expect(not _submit(session, Vector2.RIGHT, true, true), "suspended actor admitted input")
	for tick: int in range(20):
		session.step(DT, world)
	_expect(session.player().cooldown_remaining == cooldown, "pause consumed/refunded cooldown time")
	_expect(int(session.snapshot().tick) == int(paused.tick), "pause advanced actor ticks")
	_expect(session.snapshot().states == paused.states, "pause changed frozen actor state")
	session.set_suspended(false)
	var resumed: Dictionary = session.snapshot()
	_expect(int(resumed.epoch) != int(paused.epoch), "resume did not require fresh action identity")
	_expect(not session.submit_action(0, int(before_pause.epoch), 999, int(before_pause.tick), Vector2.RIGHT, true, true), "pre-pause policy result survived the epoch change")
	_expect(_submit(session, Vector2.LEFT), "fresh post-resume action was refused")
	session.step(DT, world)
	_expect(session.player().cooldown_remaining > 0.0 and not session.player().secondary_active, "pause allowed an immediate free dash")

	var above_floor: Dictionary = _definition()
	above_floor.position.y = 103.0
	session.configure([above_floor], world)
	session.player().velocity.y = 60.0
	_submit(session, Vector2.ZERO, true, false, 0, &"policy", 1)
	session.step(DT, world)
	for tick: int in range(8):
		session.step(DT, world)
	_expect(session.player().grounded and session.player().velocity.y >= 0.0, "expired command replayed its buffered jump on landing")
	_expect(int(session.snapshot().lease_remaining[0]) == 0, "expired lease remained live")

	session.configure([_definition()], world)
	_submit(session, Vector2.RIGHT, false, true)
	session.step(DT, world)
	var cancel_epoch: int = int(session.snapshot().epoch)
	_expect(not session.cancel_input(0, cancel_epoch, &"human"), "wrong producer cancelled policy input")
	_expect(session.cancel_input(0, cancel_epoch, &"policy"), "assigned producer could not cancel input")
	session.step(DT, world)
	_expect(not session.player().secondary_active, "cancel left an active dash running")
	_expect(session.player().cooldown_remaining > 0.0, "cancel refunded dash cooldown")


func _publication_lifetime() -> void:
	var world = _world()
	var session := Session.new()
	session.configure([_definition(&"skimmer")], world)
	var retained: Dictionary = session.snapshot()
	var original: Dictionary = retained.duplicate(true)
	for tick: int in range(20):
		_submit(session, Vector2.UP, true)
		session.step(DT, world)
	_expect(retained == original, "later simulation changed an earlier actor publication")
	retained.states[0] = -999.0
	retained.models[0] = &"wrong"
	retained.capabilities[0].model_id = "wrong"
	var fresh: Dictionary = session.snapshot()
	_expect(float(fresh.states[0]) != -999.0 and fresh.models[0] == &"skimmer", "publication exposed mutable actor/model storage")
	_expect(str(fresh.capabilities[0].model_id) == "skimmer", "publication exposed mutable capability storage")
	var timing_start: int = Time.get_ticks_usec()
	for tick: int in range(1200):
		session.step(DT, world)
	print("ACTOR_SESSION_TIMING ", JSON.stringify({"actors": 1, "steps": 1200,
		"mean_microseconds": float(Time.get_ticks_usec() - timing_start) / 1200.0,
		"scope": "headless host / session with mock occupancy / informational"}))
	var definitions: Array = []
	for index: int in range(8):
		var definition: Dictionary = _definition(MODELS[index % 3], &"demo")
		definition.position.x += float(index) * 20.0
		definitions.append(definition)
	session.configure(definitions, world)
	var peak_queries: int = 0
	var publication_checksum: float = 0.0
	timing_start = Time.get_ticks_usec()
	for tick: int in range(1200):
		session.step(DT, world)
		var publication: Dictionary = session.snapshot()
		publication_checksum += float(publication.states[0])
		peak_queries = maxi(peak_queries, int(publication.query_count_last))
	print("ACTOR_SESSION_PUBLICATION_TIMING ", JSON.stringify({"actors": 8, "steps": 1200,
		"mean_microseconds": float(Time.get_ticks_usec() - timing_start) / 1200.0,
		"peak_occupancy_queries": peak_queries, "publication_checksum": publication_checksum,
		"scope": "headless host / mixed scripted demos + session step + snapshot / mock occupancy / informational"}))
	_expect(peak_queries <= 8 * 32, "full-capacity updates exceeded aggregate query budget")


func _run() -> void:
	_configuration_and_admission()
	_producer_equivalence_and_axes()
	_edges_expiry_and_pause()
	_publication_lifetime()
	print("ACTOR_SESSION: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
