extends SceneTree

# Provisional actor behavior, owner-neutral input and bounded work. Timing is
# reported for the executing host; it is not a target-PC performance threshold.
const Actor = preload("res://scripts/actor_prototype.gd")
const DT: float = 1.0 / 60.0
const MODELS: Array[StringName] = [&"runner", &"skimmer", &"crawler"]
const MAX_QUERIES: int = 32
const MAX_SPEED: float = 120.0
const MAX_AXIS_TRAVEL: float = 4.01

var assertions: int = 0
var failures: int = 0
var peak_queries: int = 0
var timing: Array[Dictionary] = []


class FixtureWorld:
	extends RefCounted

	var floor_y: float = INF
	var bounds: Rect2 = Rect2(-1000000.0, -1000000.0, 2000000.0, 2000000.0)
	var obstacles: Array[Rect2] = []
	var enclosed: bool = false
	var suppress_support: bool = false
	var queries: int = 0
	var malformed_queries: int = 0
	var disturbance_calls: int = 0

	func box_collides(origin: Vector2, size: Vector2) -> bool:
		queries += 1
		return _collides(origin, size)

	func character_box_collides(origin: Vector2, size: Vector2, mode: int) -> bool:
		queries += 1
		if mode == 1 and suppress_support:
			return false
		return _collides(origin, size)

	func character_disturb_granular(
		_origin: Vector2,
		_size: Vector2,
		_impact: float
	) -> int:
		disturbance_calls += 1
		return 0

	func _collides(origin: Vector2, size: Vector2) -> bool:
		if (
			not origin.is_finite()
			or not size.is_finite()
			or size.x <= 0.0
			or size.y <= 0.0
			or size.x > 32.0
			or size.y > 32.0
		):
			malformed_queries += 1
			return true
		if enclosed:
			return true
		if origin.y + size.y > floor_y + 0.00001:
			return true
		if (
			origin.x < bounds.position.x
			or origin.y < bounds.position.y
			or origin.x + size.x > bounds.end.x
			or origin.y + size.y > bounds.end.y
		):
			return true
		var body := Rect2(origin, size)
		for obstacle: Rect2 in obstacles:
			if body.intersects(obstacle):
				return true
		return false


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error("ACTOR_PROTOTYPES: " + message)


func _new_actor(model: StringName, spawn: Vector2 = Vector2.ZERO) -> CyberActorPrototype:
	var actor := Actor.new()
	actor.configure_model(model)
	actor.reset(spawn)
	return actor


func _step(
	actor: CyberActorPrototype,
	world: FixtureWorld,
	movement: Vector2 = Vector2.ZERO,
	primary: bool = false,
	secondary: bool = false,
	delta: float = DT,
	primary_pressed: bool = false,
	secondary_pressed: bool = false
) -> void:
	world.queries = 0
	var before: Vector2 = actor.position
	actor.simulate_action(
		delta, movement, primary, secondary, world,
		primary_pressed, secondary_pressed
	)
	peak_queries = maxi(peak_queries, world.queries)
	_expect(world.queries <= MAX_QUERIES, str(actor.model_id) + " exceeded occupancy-query budget")
	_expect(actor.query_count_last == world.queries, "query telemetry omitted an occupancy query")
	_expect(world.malformed_queries == 0, "malformed geometry reached the world query boundary")
	_expect(actor.position.is_finite() and actor.velocity.is_finite(), "actor produced nonfinite motion")
	_expect(actor.velocity.length() <= MAX_SPEED + 0.001, "actor exceeded common speed bound")
	if before.is_finite():
		var travel: Vector2 = (actor.position - before).abs()
		_expect(
			travel.x <= MAX_AXIS_TRAVEL and travel.y <= MAX_AXIS_TRAVEL,
			"actor exceeded the per-call bounded sweep/traversal distance"
		)


func _common_contract() -> void:
	for model: StringName in MODELS:
		var actor: CyberActorPrototype = _new_actor(model, Vector2(30.0, 40.0))
		var world := FixtureWorld.new()
		var capabilities: Dictionary = actor.capabilities()
		_expect(not capabilities.is_empty(), str(model) + " has no capability description")
		_expect(
			str(capabilities.get("model_id", "")) == str(model)
			and bool(capabilities.get("provisional", false))
			and int(capabilities.get("observation_size", 0)) == 16,
			"capability identity cannot describe this provisional policy target"
		)
		_expect(
			int(capabilities.get("maximum_collision_queries", 0)) == MAX_QUERIES
			and float(capabilities.get("maximum_speed", 0.0)) <= MAX_SPEED,
			"advertised cost/speed bounds disagree with the tested contract"
		)
		capabilities.clear()
		_expect(not actor.capabilities().is_empty(), "caller mutated shared capability storage")
		actor.configure_model(&"unregistered-model")
		_expect(actor.model_id == model, "unknown model silently changed the installed ruleset")

		var observation: PackedFloat32Array = actor.observation()
		_expect(observation.size() == 16, "observation shape differs between actor models")
		if observation.size() == 16:
			_expect(int(observation[13]) == MODELS.find(model), "observation model index is wrong")
			observation[0] = -1000.0
			_expect(actor.position.x == 30.0, "policy observation exposed mutable actor storage")
		for value: float in actor.observation():
			_expect(is_finite(value), "observation contains a nonfinite feature")

		_step(actor, world, Vector2.RIGHT)
		_expect(actor.position.x > 30.0, str(model) + " did not react during its first action tick")
		var positive_velocity: float = actor.velocity.x
		_step(actor, world, Vector2.LEFT)
		_expect(actor.velocity.x < positive_velocity, str(model) + " did not react to direction reversal")

		for bad_delta: float in [0.0, -1.0, NAN, INF, -INF]:
			var before: Vector2 = actor.position
			_step(actor, world, Vector2.RIGHT, true, true, bad_delta)
			_expect(actor.position == before and world.queries == 0, "nonpositive/nonfinite dt consumed a tick")
		for movement: Vector2 in [Vector2(NAN, 1.0), Vector2(INF, -INF), Vector2(1.0e30, -1.0e30)]:
			_step(actor, world, movement, true, true, 1000000.0)
		actor.reset(Vector2(NAN, INF))
		_expect(actor.position.is_finite(), "nonfinite spawn corrupted actor position")
		_step(actor, world)

		actor.reset(Vector2(30.0, 40.0))
		world.enclosed = true
		for frame: int in range(5):
			_step(actor, world, Vector2.UP, true, true)
		_expect(actor.position == Vector2(30.0, 40.0), "runtime burial silently relocated actor")
		_expect(actor.runtime_enclosed and actor.recovery_blocked, "burial did not expose immobilization")
		_expect(actor.runtime_recovery_attempts == 0, "prototype entered legacy relocation search")
		_expect(world.disturbance_calls == 0, "enclosed actor tried to delete/displace material")
		world.enclosed = false
		_step(actor, world, Vector2.RIGHT)
		_expect(not actor.recovery_blocked and actor.position.x > 30.0, "actor did not resume when enclosure cleared")


func _independent_instances() -> void:
	for model: StringName in MODELS:
		var player: CyberActorPrototype = _new_actor(model)
		var policy: CyberActorPrototype = _new_actor(model)
		var unrelated: CyberActorPrototype = _new_actor(model, Vector2(80.0, -40.0))
		var world := FixtureWorld.new()
		for tick: int in range(90):
			var movement := Vector2(-1.0 if tick < 45 else 1.0, -0.25)
			var primary: bool = tick % 30 < 5
			var secondary: bool = tick % 40 < 4
			_step(player, world, movement, primary, secondary)
			_step(unrelated, world, Vector2.UP, not primary, not secondary)
			_step(policy, world, movement, primary, secondary)
		_expect(player.observation() == policy.observation(), "interleaved actor instances share control state")
		_expect(player.position != unrelated.position, "independent actions did not produce independent motion")


func _runner_actions() -> void:
	var world := FixtureWorld.new()
	world.floor_y = 0.0
	var runner: CyberActorPrototype = _new_actor(&"runner", Vector2(0.0, -14.0))
	_step(runner, world)
	_step(runner, world, Vector2.ZERO, true)
	_expect(runner.position.y < -14.0 and runner.velocity.y < -32.0, "runner jump was not immediate")
	_step(runner, world, Vector2.ZERO, false)
	_expect(runner.velocity.y >= -32.001, "jump release did not shorten the rising arc")
	for tick: int in range(120):
		_step(runner, world, Vector2.ZERO, true)
	_expect(runner.grounded and absf(runner.position.y + 14.0) < 0.6, "holding jump retriggered after landing")
	_step(runner, world, Vector2.ZERO, false)
	_step(runner, world, Vector2.ZERO, false, false, DT, true)
	_expect(runner.velocity.y < 0.0, "compressed press/release jump tap was discarded")

	runner.reset(Vector2(0.0, -14.0))
	_step(runner, world)
	world.floor_y = INF
	_step(runner, world)
	_step(runner, world, Vector2.ZERO, true)
	_expect(runner.velocity.y < 0.0, "runner lost jump grace immediately after leaving a ledge")
	runner.reset(Vector2(0.0, -14.0))
	world.floor_y = 0.0
	_step(runner, world)
	world.floor_y = INF
	for tick: int in range(10):
		_step(runner, world)
	_step(runner, world, Vector2.ZERO, true)
	_expect(runner.velocity.y >= 0.0, "expired jump grace admitted an air jump")

	world.floor_y = 0.0
	runner.reset(Vector2(0.0, -15.5))
	runner.velocity.y = 60.0
	var buffered_jump: bool = false
	for tick: int in range(6):
		_step(runner, world, Vector2.ZERO, true)
		buffered_jump = buffered_jump or runner.velocity.y < 0.0
	_expect(buffered_jump, "pre-landing jump edge was lost before supported contact")

	# The landing-buffer transition runs after collision resolution. Combining it
	# with a dash must not publish a new jump velocity beyond the common bound.
	runner.reset(Vector2(0.0, -15.5))
	runner.velocity.y = 60.0
	var buffered_dash_jump: bool = false
	for tick: int in range(4):
		_step(runner, world, Vector2.RIGHT, true, true)
		buffered_dash_jump = buffered_dash_jump or runner.velocity.y < 0.0
	_expect(buffered_dash_jump, "combined dash fixture did not execute its buffered landing jump")

	runner.reset(Vector2(0.0, -14.0))
	_step(runner, world, Vector2.RIGHT, false, true)
	_expect(runner.secondary_active and runner.cooldown_remaining > 0.0, "runner dash did not activate")
	var cooldown: float = runner.cooldown_remaining
	runner.clear_actions()
	_expect(runner.cooldown_remaining == cooldown, "cancel/pause erased dash cooldown")
	_expect(not runner.secondary_active, "cancel/pause retained an active dash")
	for tick: int in range(10):
		_step(runner, world, Vector2.RIGHT)
	_step(runner, world, Vector2.RIGHT, false, true)
	_expect(not runner.secondary_active, "dash retriggered before cooldown elapsed")
	for tick: int in range(90):
		_step(runner, world, Vector2.RIGHT, false, true)
	_expect(not runner.secondary_active and is_zero_approx(runner.cooldown_remaining), "held dash repeated at cooldown expiry")
	_step(runner, world, Vector2.RIGHT, false, false, DT, false, true)
	_expect(runner.secondary_active, "compressed dash edge was not accepted after cooldown")


func _skimmer_actions() -> void:
	var world := FixtureWorld.new()
	var cruise: CyberActorPrototype = _new_actor(&"skimmer")
	var boost: CyberActorPrototype = _new_actor(&"skimmer")
	for tick: int in range(20):
		_step(cruise, world, Vector2.UP)
		_step(boost, world, Vector2.UP, true)
	_expect(boost.position.y < cruise.position.y - 0.5, "boost did not exceed regular flight")
	_expect(boost.energy < cruise.energy, "boost did not consume its separate energy budget")
	cruise.velocity = Vector2(60.0, 0.0)
	boost.velocity = cruise.velocity
	_step(cruise, world, Vector2.RIGHT)
	_step(boost, world, Vector2.RIGHT, false, true)
	_expect(boost.velocity.x < cruise.velocity.x, "skimmer brake did not override travel input")
	var saved_energy: float = boost.energy
	boost.clear_actions()
	_expect(boost.energy == saved_energy, "cancel/pause refilled skimmer energy")

	boost.reset(Vector2.ZERO)
	var exhausted: bool = false
	var exhausted_velocity: float = 0.0
	for tick: int in range(240):
		_step(boost, world, Vector2.UP, true)
		_expect(boost.energy >= 0.0 and boost.energy <= 1.0, "energy escaped normalized range")
		if boost.energy <= 0.00001:
			exhausted = true
			exhausted_velocity = boost.velocity.y
			break
	_expect(exhausted, "continuous boosted flight never exhausted its finite energy")
	if exhausted:
		for tick: int in range(6):
			_step(boost, world, Vector2.UP, true)
		_expect(boost.velocity.y > exhausted_velocity, "exhausted skimmer kept applying upward thrust")
		_expect(not boost.primary_active, "exhausted skimmer still advertised active boost")
	for tick: int in range(150):
		_step(boost, world, Vector2.ZERO, false, true)
	_expect(boost.energy >= 0.15, "coasting/braking did not recharge the exhausted skimmer")
	for tick: int in range(20):
		_step(boost, world, Vector2.UP)
	_expect(boost.velocity.y < 0.0, "recharged skimmer did not regain upward control")


func _crawler_actions() -> void:
	for height: int in [4, 5]:
		var world := FixtureWorld.new()
		world.floor_y = 0.0
		world.obstacles.append(Rect2(8.0, -float(height), 40.0, float(height)))
		var crawler: CyberActorPrototype = _new_actor(&"crawler", Vector2(0.0, -14.0))
		for tick: int in range(8):
			_step(crawler, world, Vector2.RIGHT)
		if height == 4:
			_expect(crawler.position.x > 0.0 and crawler.position.y < -17.5, "crawler did not traverse its supported four-cell ledge")
		else:
			_expect(crawler.position.x <= 0.0001, "crawler exceeded its four-cell ledge capability")

	var roof_world := FixtureWorld.new()
	roof_world.floor_y = 0.0
	roof_world.obstacles.append(Rect2(8.0, -4.0, 40.0, 4.0))
	roof_world.obstacles.append(Rect2(-10.0, -17.0, 30.0, 1.0))
	var low_roof: CyberActorPrototype = _new_actor(&"crawler", Vector2(0.0, -14.0))
	for tick: int in range(12):
		_step(low_roof, roof_world, Vector2.RIGHT)
	_expect(low_roof.position.x <= 0.0001, "crawler teleported through intermediate overhead clearance")
	_expect(not roof_world.box_collides(low_roof.position, low_roof.BODY_SIZE), "failed clamber embedded the crawler in terrain")

	var unsupported := FixtureWorld.new()
	unsupported.floor_y = 0.0
	unsupported.obstacles.append(Rect2(8.0, -4.0, 40.0, 4.0))
	unsupported.suppress_support = true
	var airborne: CyberActorPrototype = _new_actor(&"crawler", Vector2(0.0, -14.0))
	for tick: int in range(8):
		_step(airborne, unsupported, Vector2.RIGHT)
	_expect(airborne.position.x <= 0.0001, "crawler used clamber without supported contact")

	var floor_world := FixtureWorld.new()
	floor_world.floor_y = 0.0
	var crawler: CyberActorPrototype = _new_actor(&"crawler", Vector2(0.0, -14.0))
	for tick: int in range(12):
		_step(crawler, floor_world, Vector2.RIGHT)
	for tick: int in range(6):
		_step(crawler, floor_world, Vector2.RIGHT, true, true)
	_expect(absf(crawler.velocity.x) < 0.001 and crawler.grounded, "crawler brace did not suppress locomotion and jump")
	_step(crawler, floor_world, Vector2.ZERO, true, false)
	_expect(crawler.velocity.y >= 0.0, "unbracing replayed a suppressed jump edge")
	_step(crawler, floor_world, Vector2.ZERO, false)
	_step(crawler, floor_world, Vector2.ZERO, true)
	_expect(crawler.velocity.y < 0.0, "crawler did not hop after a fresh valid press")


func _thin_surface_boundaries() -> void:
	for model: StringName in MODELS:
		var world := FixtureWorld.new()
		world.floor_y = 120.0
		world.obstacles.append(Rect2(100.0, -100.0, 1.0, 220.0))
		world.obstacles.append(Rect2(-100.0, 10.0, 200.0, 1.0))
		var actor: CyberActorPrototype = _new_actor(model, Vector2(88.0, 30.0))
		for tick: int in range(80):
			_step(actor, world, Vector2(1.0, -1.0), true, tick % 2 == 0, 1000.0)
			_expect(actor.position.x + actor.BODY_SIZE.x <= 100.0001, "actor tunneled through a one-cell wall")
			_expect(actor.position.y >= 10.9999, "actor tunneled through a one-cell ceiling")
			_expect(actor.position.y + actor.BODY_SIZE.y <= 120.0001, "actor tunneled through floor")


func _native_smoke() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "source-matched native runtime is unavailable")
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_expect(world.diagnostic_reset({"workers": 1}), "native empty-world reset failed")
	_expect(world.diagnostic_fill_rect(Vector2i(60, 120), Vector2i(80, 1), CyberCellWorld.WALL), "native floor setup failed")
	_expect(world.diagnostic_fill_rect(Vector2i(110, 0), Vector2i(1, 120), CyberCellWorld.WALL), "native wall setup failed")
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(60, 0), Vector2i(80, 128), true)
	_expect(before.has("hash") and before.has("counts"), "native fixture did not produce a valid conservation observation")
	for model: StringName in MODELS:
		var actor: CyberActorPrototype = _new_actor(model, Vector2(88.0, 92.0))
		for tick: int in range(120):
			actor.simulate_action(DT, Vector2.RIGHT, tick % 60 < 4, tick % 40 == 0, world)
			_expect(actor.position.is_finite() and actor.velocity.is_finite(), "native actor motion became nonfinite")
			_expect(actor.position.x + actor.BODY_SIZE.x <= 110.0001, "native actor crossed the hard wall")
			_expect(actor.query_count_last <= MAX_QUERIES, "native actor exceeded query budget")
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(60, 0), Vector2i(80, 128), true)
	_expect(before.get("hash") == after.get("hash"), "hard-surface actor smoke mutated authoritative World state")
	_expect(before.get("counts") == after.get("counts"), "hard-surface actor smoke changed material counts")
	_expect(int(world.tick_index) == 0, "actor movement secretly advanced cellular simulation")


func _timing_report() -> void:
	const STEPS: int = 6000
	for model: StringName in MODELS:
		var actor: CyberActorPrototype = _new_actor(model)
		var world := FixtureWorld.new()
		var maximum_queries: int = 0
		var start: int = Time.get_ticks_usec()
		for tick: int in range(STEPS):
			world.queries = 0
			actor.simulate_action(DT, Vector2.RIGHT, tick % 80 < 4, tick % 120 == 0, world)
			maximum_queries = maxi(maximum_queries, world.queries)
		var elapsed: int = Time.get_ticks_usec() - start
		_expect(maximum_queries <= MAX_QUERIES, "long-run query cost exceeded the fixed budget")
		timing.append({
			"model": str(model),
			"steps": STEPS,
			"mean_microseconds": float(elapsed) / float(STEPS),
			"maximum_occupancy_queries": maximum_queries,
			"scope": "headless host / mock occupancy / informational timing",
		})


func _run() -> void:
	_common_contract()
	_independent_instances()
	_runner_actions()
	_skimmer_actions()
	_crawler_actions()
	_thin_surface_boundaries()
	_native_smoke()
	_timing_report()
	print("ACTOR_PROTOTYPES ", JSON.stringify({
		"assertions": assertions,
		"failures": failures,
		"peak_occupancy_queries": peak_queries,
		"timing": timing,
	}))
	quit(1 if failures else 0)
