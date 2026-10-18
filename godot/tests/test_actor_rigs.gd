extends SceneTree

# ACT-002: independent geometry/material fixtures. Timings describe this
# executing headless host and do not impose a target-machine latency gate.
const Rig = preload("res://scripts/actor_rig_motor.gd")
const Effects = preload("res://scripts/actor_rig_effects.gd")
const DT: float = 1.0 / 60.0
const RIG_IDS: Array[StringName] = [
	&"scout", &"scrabbler", &"ripper", &"groundeffect", &"digger",
	&"copter", &"pouncer", &"dropbot", &"lineshank",
	&"walljumper", &"clamberer", &"swinger", &"rocketjumper",
	&"springjack", &"gyrocrate", &"bellows", &"winchbug", &"magpie", &"skatesail",
	&"astra", &"claude", &"luna", &"qwen", &"bonsai", &"jev", &"gemini",
]
const EDITABLE: Array[int] = [
	2, 7, 9, 11, 13, 14, 18, 19, 20, 21, 23, 25, 26, 27, 29, 30, 35,
	38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 55, 56, 57, 59,
	60, 61, 65, 70, 71, 72, 73, 74, 75,
]
const MAX_QUERIES: int = 96
const MAX_RAYS: int = 64
const MAX_EFFECT_READS: int = 64
const MAX_EFFECT_WRITES: int = 64
const MAX_SPEED: float = 160.0
const MAX_AXIS_TRAVEL: float = 6.01

var assertions: int = 0
var failures: int = 0
var peak_queries: int = 0
var peak_rays: int = 0
var peak_effect_reads: int = 0
var peak_effect_writes: int = 0
var timings: Array[Dictionary] = []


class RigWorld:
	extends RefCounted

	var floor_y: float = INF
	var bounds := Rect2(0.0, 0.0, 1024.0, 1024.0)
	var obstacles: Array[Rect2] = []
	var cells: Dictionary = {}
	var masks: Dictionary = {}
	var enclosed: bool = false
	var suppress_support: bool = false
	var failed: bool = false
	var queries: int = 0
	var material_reads: int = 0
	var writes: int = 0
	var malformed_queries: int = 0
	var malformed_writes: int = 0
	var disturbance_calls: int = 0
	var read_positions: Array[Vector2i] = []
	var write_commands: Array[Dictionary] = []

	func clear_counters() -> void:
		queries = 0
		material_reads = 0
		writes = 0
		malformed_queries = 0
		malformed_writes = 0
		disturbance_calls = 0
		read_positions.clear()
		write_commands.clear()

	func has_failed() -> bool:
		return failed

	func box_collides(origin: Vector2, size: Vector2) -> bool:
		queries += 1
		return collides_untracked(origin, size)

	func character_box_collides(origin: Vector2, size: Vector2, mode: int) -> bool:
		queries += 1
		if mode == 1 and suppress_support:
			return false
		return collides_untracked(origin, size)

	func character_disturb_granular(_origin: Vector2, _size: Vector2, _impact: float) -> int:
		disturbance_calls += 1
		return 0

	func material_at(x: int, y: int) -> int:
		material_reads += 1
		read_positions.append(Vector2i(x, y))
		return material_untracked(x, y)

	func material_untracked(x: int, y: int) -> int:
		var point := Vector2(float(x) + 0.5, float(y) + 0.5)
		if not bounds.has_point(point) or point.y >= floor_y:
			return 1
		var key := Vector2i(x, y)
		if masks.has(key):
			return 1
		for obstacle: Rect2 in obstacles:
			if obstacle.has_point(point):
				return 1
		return int(cells.get(key, 0))

	func emit_disc(x: int, y: int, radius: int, material: int, _flags: int = 0) -> void:
		writes += 1
		write_commands.append({"x": x, "y": y, "radius": radius, "material": material})
		if radius != 0 or not bounds.has_point(Vector2(x, y)) or failed:
			malformed_writes += 1
			return
		cells[Vector2i(x, y)] = material

	func fill(origin: Vector2i, size: Vector2i, material: int) -> void:
		for y: int in range(origin.y, origin.y + size.y):
			for x: int in range(origin.x, origin.x + size.x):
				cells[Vector2i(x, y)] = material

	func collides_untracked(origin: Vector2, size: Vector2) -> bool:
		if not origin.is_finite() or not size.is_finite() or size.x <= 0.0 \
			or size.y <= 0.0 or size.x > 32.00001 or size.y > 32.00001:
			malformed_queries += 1
			return true
		if enclosed or failed:
			return true
		var body := Rect2(origin, size)
		if origin.y + size.y > floor_y + 0.00001 or not bounds.encloses(body):
			return true
		for obstacle: Rect2 in obstacles:
			if body.intersects(obstacle):
				return true
		for key: Vector2i in masks:
			if body.intersects(Rect2(Vector2(key), Vector2.ONE)):
				return true
		for key: Vector2i in cells:
			# These fixtures explicitly use Wall/Sand/Metal as occupancy. Other
			# material IDs below exercise tool protection, not material physics.
			if int(cells[key]) in [1, 2, 5, 28, 31] \
				and body.intersects(Rect2(Vector2(key), Vector2.ONE)):
				return true
		return false


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error("ACTOR_RIGS: " + message)


func _new_rig(rig_id: StringName, spawn: Vector2 = Vector2(180.0, 100.0)):
	var actor = Rig.new()
	_expect(actor.configure_model(rig_id), "registered rig was refused: " + str(rig_id))
	actor.reset(spawn)
	return actor


func _persistent_state(state: PackedFloat32Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	# Per-call activity flags and query/effect telemetry are not persistent
	# actuator state; resetting their readback is valid even for a rejected dt.
	for index: int in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 16, 17, 18, 19,
		20, 21, 22, 23, 24, 25, 27, 28, 35, 36, 39]:
		result.append(state[index])
	return result


func _step(actor, world: RigWorld, action: Dictionary = {}, delta: float = DT) -> PackedFloat32Array:
	world.clear_counters()
	var before: Vector2 = actor.centre()
	actor.simulate_rig_action(delta, action.get("move", Vector2.ZERO),
		action.get("aim", Vector2.RIGHT), float(action.get("effort", 0.7)),
		float(action.get("trim", 0.0)), float(action.get("reel", 0.0)),
		bool(action.get("primary", false)), bool(action.get("secondary", false)),
		bool(action.get("auxiliary", false)), world,
		bool(action.get("primary_pressed", false)), bool(action.get("secondary_pressed", false)),
		bool(action.get("auxiliary_pressed", false)))
	var state: PackedFloat32Array = actor.rig_observation()
	_expect(state.size() == 40, str(actor.model_id) + " changed the rig observation stride")
	if state.size() != 40:
		return state
	var finite: bool = true
	for value: float in state:
		finite = finite and is_finite(value)
	_expect(finite, str(actor.model_id) + " published a nonfinite feature")
	_expect(actor.position.is_finite() and actor.velocity.is_finite(), "nonfinite motion escaped a rig")
	_expect(actor.velocity.length() <= MAX_SPEED + 0.001, "rig exceeded velocity norm bound")
	var travel: Vector2 = (actor.centre() - before).abs()
	_expect(travel.x <= MAX_AXIS_TRAVEL and travel.y <= MAX_AXIS_TRAVEL,
		str(actor.model_id) + " exceeded actual centre travel, including rotation/ledge transitions")
	_expect(world.queries <= MAX_QUERIES and actor.query_count_last == world.queries,
		"occupancy work exceeded its cap or escaped telemetry")
	_expect(int(state[29]) <= MAX_RAYS and int(state[38]) <= MAX_EFFECT_READS,
		"ray/effect read work exceeded its per-update bound")
	_expect(int(state[29]) + int(state[38]) == world.material_reads,
		"material query telemetry omitted or double-counted real work")
	_expect(world.writes <= MAX_EFFECT_WRITES and int(state[30]) == world.writes,
		"effect write work exceeded its cap or escaped telemetry")
	_expect(world.malformed_queries == 0 and world.malformed_writes == 0,
		"invalid geometry, effect radius or effect bounds reached the World")
	_expect(state[6] >= 0.0 and state[6] <= 1.00001 and state[9] >= 0.0,
		"energy/cooldown left its declared range")
	_expect(absf(state[17]) <= 6.00001 and state[24] >= 0.0 and state[24] <= 1.00001 \
		and state[25] >= 0.0 and state[25] <= 1.00001 and state[39] >= 0.0 and state[39] <= 1.00001,
		"angular speed, tension, charge or gait left its normalized bound")
	_expect(actor.observation() == state.slice(0, 16), "common observation prefix diverged from v1 view")
	peak_queries = maxi(peak_queries, world.queries)
	peak_rays = maxi(peak_rays, int(state[29]))
	peak_effect_reads = maxi(peak_effect_reads, int(state[38]))
	peak_effect_writes = maxi(peak_effect_writes, world.writes)
	return state


func _common_contract() -> void:
	for rig_id: StringName in RIG_IDS:
		var actor = _new_rig(rig_id)
		var world := RigWorld.new()
		var capabilities: Dictionary = actor.capabilities()
		_expect(str(capabilities.get("model_id", "")) == str(rig_id) \
			and bool(capabilities.get("provisional", false)), "rig capability identity is missing")
		_expect(actor.body_size.x > 0.0 and actor.body_size.y > 0.0 \
			and actor.body_size.x <= 32.0 and actor.body_size.y <= 32.0,
			"rig hull dimensions exceed the adapter envelope")
		var before_capabilities: Dictionary = capabilities.duplicate(true)
		capabilities.clear()
		_expect(actor.capabilities() == before_capabilities, "caller mutated shared capability storage")
		for invalid: StringName in [&"runner", &"skimmer", &"crawler", &"unknown", &""]:
			_expect(not actor.configure_model(invalid) and actor.model_id == rig_id,
				"new rig motor accepted legacy/unknown identity or changed on refusal")
		var retained: PackedFloat32Array = actor.rig_observation()
		var original: PackedFloat32Array = retained.duplicate()
		for tick: int in range(36):
			_step(actor, world, {"move": Vector2(1.0 if tick < 18 else -1.0, -0.5),
				"aim": Vector2(-0.3, -1.0), "effort": 0.85, "trim": 0.5,
				"reel": -1.0, "primary": tick % 12 < 3, "secondary": tick % 17 == 0,
				"auxiliary": tick % 23 == 0})
		_expect(retained == original, "later stepping changed a retained rig observation")
		retained[0] = -999.0
		_expect(actor.rig_observation()[0] != -999.0, "rig observation aliases live motor state")
		var physical_before: PackedFloat32Array = actor.rig_observation()
		for invalid_delta: float in [0.0, -DT, NAN, INF, -INF]:
			var state: PackedFloat32Array = _step(actor, world,
				{"primary": true, "secondary": true, "auxiliary": true}, invalid_delta)
			_expect(world.queries == 0 and world.material_reads == 0 and world.writes == 0,
				"invalid timestep consumed owner World work")
			_expect(_persistent_state(state) == _persistent_state(physical_before),
				"invalid timestep consumed motion, controls, charge or cooldown")
		for field: String in ["move", "aim", "effort", "trim", "reel"]:
			var action: Dictionary = {"primary": true, "secondary": true, "auxiliary": true}
			action[field] = Vector2(NAN, INF) if field in ["move", "aim"] else NAN
			_step(actor, world, action, 1000000.0)
		_step(actor, world, {"move": Vector2(1.0e30, -1.0e30), "aim": Vector2(-1.0e30, 1.0e30),
			"effort": 1.0e30, "trim": -1.0e30, "reel": 1.0e30}, 1000000.0)
		actor.velocity = Vector2(NAN, INF)
		_step(actor, world)
		actor.reset(Vector2(180.0, 100.0))
		world.enclosed = true
		for tick: int in range(4):
			var state: PackedFloat32Array = _step(actor, world,
				{"move": Vector2.ONE, "primary": true, "secondary": true, "auxiliary": true})
			_expect(actor.position == Vector2(180.0, 100.0) and actor.velocity == Vector2.ZERO,
				"buried rig relocated or kept moving")
			_expect(state[5] == 1.0 and state[20] == 0.0 and world.writes == 0,
				"enclosed rig retained attachment or excavated its way out")
		_expect(actor.runtime_recovery_attempts == 0 and world.disturbance_calls == 0,
			"runtime rig entered setup recovery or displacement")
		world.enclosed = false
		_step(actor, world, {"move": Vector2.RIGHT})
		_expect(not actor.runtime_enclosed, "rig stayed enclosed after terrain clearance")


func _effect_envelope_and_occlusion() -> void:
	var world := RigWorld.new()
	var effect := Effects.new()
	world.fill(Vector2i(94, 94), Vector2i(13, 13), 2)
	effect.apply(world, Effects.BLAST, Vector2(100.25, 100.75), 999, 99.0)
	_expect(world.material_reads == 49 and world.writes == 49 \
		and effect.reads_last == 49 and effect.writes_last == 49,
		"radius-four effect did not account for its 49-cell footprint exactly")
	_expect(effect.radius == 4.0 and effect.strength == 1.0 \
		and effect.origin == Vector2(100.5, 100.5), "effect metadata did not expose bounded actual parameters")
	for y: int in range(94, 107):
		for x: int in range(94, 107):
			var offset := Vector2i(x - 100, y - 100)
			var expected: int = 2
			if offset.length_squared() <= 16:
				expected = 6 if offset == Vector2i.ZERO else 0
			_expect(world.material_untracked(x, y) == expected,
				"effect changed material outside its circular footprint or duplicated its fire centre")
	for command: Dictionary in world.write_commands:
		_expect(int(command.radius) == 0 and int(command.material) in [0, 6],
			"effect bypassed the point-write/material envelope")
	effect.apply(world, Effects.DIG, Vector2(200.0, 200.0), 4)
	_expect(world.material_reads == 49 and world.writes == 49,
		"second effect bypassed the per-update single-slot limit")

	for material: int in range(81):
		world = RigWorld.new()
		world.cells[Vector2i(100, 100)] = material
		effect.clear()
		effect.apply(world, Effects.DIG, Vector2(100.5, 100.5), 1)
		var editable: bool = material in EDITABLE
		_expect(world.material_untracked(100, 100) == (0 if editable else material),
			"fixed excavation allowlist disagrees at material " + str(material))
		_expect(world.writes == (1 if editable else 0) and effect.writes_last == world.writes,
			"unchanged/protected material was counted or written as excavation")

	for use_mask: bool in [false, true]:
		world = RigWorld.new()
		world.fill(Vector2i(96, 96), Vector2i(9, 9), 2)
		for y: int in range(96, 105):
			if use_mask:
				world.masks[Vector2i(101, y)] = true
			else:
				world.cells[Vector2i(101, y)] = 1
		effect.clear()
		effect.apply(world, Effects.BLAST, Vector2(100.0, 100.0), 4)
		_expect(world.material_untracked(99, 100) == 0, "unoccluded effect control did not excavate")
		for y: int in range(96, 105):
			_expect(world.material_untracked(101, y) == 1, "effect removed a protected wall/body mask")
			for x: int in range(102, 105):
				_expect(world.material_untracked(x, y) == 2,
					"effect reached hidden cells behind a one-cell protected wall/body mask")
		_expect(world.material_reads == effect.reads_last and world.writes == effect.writes_last,
			"occluded effect work was omitted from telemetry")

	world = RigWorld.new()
	world.fill(Vector2i(96, 96), Vector2i(9, 9), 2)
	world.cells[Vector2i(101, 100)] = 1
	effect.clear()
	effect.apply(world, Effects.DIG, Vector2(100.0, 100.0), 4)
	_expect(world.material_untracked(101, 101) == 2,
		"diagonal tool ray leaked around the touching corner of a protected cell")
	_expect(world.material_untracked(99, 101) == 0,
		"corner-occlusion negative control blocked the open side too")

	world = RigWorld.new()
	world.fill(Vector2i(96, 96), Vector2i(9, 9), 2)
	world.cells[Vector2i(100, 100)] = 1
	effect.clear()
	effect.apply(world, Effects.BLAST, Vector2(100.0, 100.0), 4)
	_expect(world.writes == 0, "a protected effect centre excavated neighbouring or hidden cells")


func _effect_refusals() -> void:
	var world := RigWorld.new()
	var effect := Effects.new()
	for target: Vector2 in [Vector2(NAN, 0.0), Vector2(0.0, INF), Vector2(-1.0, 100.0),
		Vector2(1024.0, 100.0), Vector2(100.0, 1024.0), Vector2(1.0e30, 1.0e30)]:
		effect.clear()
		world.clear_counters()
		effect.apply(world, Effects.BLAST, target, 4)
		_expect(world.material_reads == 0 and world.writes == 0 and effect.kind == Effects.NONE,
			"invalid effect target reached the World or advertised an effect: " + str(target))
	for kind: int in [-1, 0, 3, 2147483647]:
		effect.clear()
		world.clear_counters()
		effect.apply(world, kind, Vector2(100.0, 100.0), 4)
		_expect(world.material_reads == 0 and world.writes == 0, "unknown effect kind was admitted")
	for power: float in [NAN, INF, -INF]:
		effect.clear()
		world.clear_counters()
		effect.apply(world, Effects.BLAST, Vector2(100.0, 100.0), 4, power)
		_expect(world.material_reads == 0 and world.writes == 0, "nonfinite effect strength was admitted")
	effect.apply(null, Effects.BLAST, Vector2(100.0, 100.0), 4)
	effect.apply(RefCounted.new(), Effects.BLAST, Vector2(100.0, 100.0), 4)
	_expect(effect.kind == Effects.NONE, "missing World API was treated as a completed effect")
	world.failed = true
	world.clear_counters()
	effect.apply(world, Effects.BLAST, Vector2(100.0, 100.0), 4)
	_expect(world.material_reads == 0 and world.writes == 0 and effect.kind == Effects.NONE,
		"owner effect crossed failed-world quarantine")
	world.failed = false
	world.fill(Vector2i.ZERO, Vector2i(5, 5), 2)
	effect.apply(world, Effects.BLAST, Vector2.ZERO, 4)
	_expect(world.malformed_writes == 0 and world.material_reads <= 49 and world.writes <= 49,
		"boundary-clipped effect wrote outside the World or exceeded its footprint")
	for point: Vector2i in world.read_positions:
		_expect(point.x >= 0 and point.y >= 0 and point.x < 1024 and point.y < 1024,
			"effect queried an OOB cell as if it were a valid target")


func _body_bounds(actor) -> Rect2:
	var sine: float = absf(sin(actor.rotation))
	var cosine: float = absf(cos(actor.rotation))
	var extent := Vector2(actor.body_size.x * cosine + actor.body_size.y * sine,
		actor.body_size.x * sine + actor.body_size.y * cosine)
	return Rect2(actor.centre() - extent * 0.5, extent)


func _rotation_and_tuck_geometry() -> void:
	# Endpoints fit, but the angular interval contains the wider 45-degree
	# footprint. A point/endpoint-only rotation test would miss this obstacle.
	var blocked_world := RigWorld.new()
	var free_world := RigWorld.new()
	var blocked = _new_rig(&"ripper", Vector2(100.0, 100.0))
	var free = _new_rig(&"ripper", Vector2(100.0, 100.0))
	blocked.rotation = PI * 0.25 - 0.08
	free.rotation = blocked.rotation
	blocked.angular_velocity = 4.8
	free.angular_velocity = 4.8
	var initial_angle: float = blocked.rotation
	blocked_world.obstacles.append(Rect2(112.060, 95.0, 0.01, 30.0))
	_expect(not blocked_world.collides_untracked(_body_bounds(blocked).position, _body_bounds(blocked).size),
		"angular obstacle fixture starts with an embedded hull")
	_step(free, free_world, {}, 1.0 / 30.0)
	_step(blocked, blocked_world, {}, 1.0 / 30.0)
	_expect(free.rotation > initial_angle + 0.1, "free angular sweep negative control did not rotate")
	_expect(is_equal_approx(blocked.rotation, initial_angle) and blocked.angular_velocity == 0.0,
		"rotated hull crossed a thin obstacle at an intermediate angle")
	_expect(not blocked_world.collides_untracked(_body_bounds(blocked).position, _body_bounds(blocked).size),
		"rejected rotation left the rig embedded")

	blocked_world = RigWorld.new()
	free_world = RigWorld.new()
	blocked_world.floor_y = 200.0
	free_world.floor_y = 200.0
	blocked_world.obstacles.append(Rect2(190.0, 188.5, 40.0, 0.5))
	blocked = _new_rig(&"ripper", Vector2(200.0, 190.0))
	free = _new_rig(&"ripper", Vector2(200.0, 190.0))
	blocked.angular_velocity = 6.0
	free.angular_velocity = 6.0
	_step(blocked, blocked_world, {}, 1.0 / 30.0)
	_step(free, free_world, {}, 1.0 / 30.0)
	_expect(absf(free.rotation) > 0.1, "supported track torque could not tip in clear volume")
	_expect(blocked.rotation == 0.0, "supported tipping pushed its expanding hull through a low ceiling")
	_expect(_body_bounds(free).end.y <= 200.0001, "ground pivot rotated through its support")

	for rig_id: StringName in [&"clamberer", &"bonsai"]:
		var world := RigWorld.new()
		var actor = _new_rig(rig_id, Vector2(200.0, 180.0))
		var full_size: Vector2 = actor.body_size
		_step(actor, world, {"auxiliary": true})
		_expect(actor.body_size.y == 6.0 and actor.body_size.x == full_size.x,
			"gap tuck did not expose the declared compact collision hull")
		var top: float = actor.centre().y - full_size.y * 0.5
		world.obstacles.append(Rect2(195.0, top - 0.5, 30.0, 1.0))
		_step(actor, world, {"auxiliary": false})
		_expect(actor.body_size.y == 6.0, "releasing tuck enlarged the hull through a low roof")
		_expect(not world.collides_untracked(_body_bounds(actor).position, _body_bounds(actor).size),
			"blocked hull restoration left an overlapping actor")
		world.obstacles.clear()
		_step(actor, world)
		_expect(actor.body_size == full_size, "clear volume did not permit restoring the full hull")
		world.floor_y = 200.0
		actor.reset(Vector2(200.0, 200.0 - full_size.y))
		_step(actor, world, {"auxiliary": true, "secondary": true})
		_expect(actor.attachment_mode == 0 and not actor.grounded and actor.velocity.y > 0.0,
			"center-preserving tuck retained an obsolete floor contact across the new gap")


func _contact_and_adhesion() -> void:
	for rig_id: StringName in [&"scrabbler", &"dropbot", &"walljumper", &"clamberer", &"claude", &"bonsai", &"magpie"]:
		var world := RigWorld.new()
		var actor = _new_rig(rig_id, Vector2(200.0, 160.0))
		world.obstacles.append(Rect2(200.0 + actor.body_size.x, 140.0, 1.0, 100.0))
		_step(actor, world, {"move": Vector2.UP, "secondary": true})
		_expect(actor.attachment_mode == 1 and actor.contact_normal == Vector2.LEFT \
			and actor.position.y < 160.0, str(rig_id) + " did not climb its actual side contact")
		var climbing_velocity: float = actor.velocity.y
		world.obstacles.clear()
		_step(actor, world, {"move": Vector2.UP, "secondary": true})
		_expect(actor.attachment_mode == 0 and actor.contact_normal == Vector2.ZERO,
			str(rig_id) + " retained adhesion after its support disappeared")
		_expect(actor.velocity.y > climbing_velocity, "contact-free climb did not restore downward acceleration")
		actor.reset(Vector2(200.0, 141.0))
		world.obstacles.append(Rect2(180.0, 140.0, 70.0, 1.0))
		_step(actor, world, {"move": Vector2.RIGHT, "secondary": true})
		_expect(actor.attachment_mode == 1 and actor.contact_normal == Vector2.DOWN \
			and actor.position.x > 200.0, str(rig_id) + " did not use a real ceiling contact")
		actor.clear_actions()
		_expect(actor.attachment_mode == 0 and actor.rope_length == 0.0 and actor.tension == 0.0,
			"cancellation retained a contact constraint")

	var world := RigWorld.new()
	var brief = _new_rig(&"walljumper", Vector2(200.0, 160.0))
	world.obstacles.append(Rect2(208.0, 140.0, 1.0, 100.0))
	brief.energy = 0.03
	_step(brief, world, {"move": Vector2.UP, "secondary": true})
	_expect(brief.attachment_mode == 1, "low-stamina fixture never attached")
	_step(brief, world, {"move": Vector2.UP, "secondary": true})
	_expect(brief.attachment_mode == 0 and brief.energy >= 0.0,
		"brief grab ignored stamina exhaustion")
	for tick: int in range(5):
		_step(brief, world, {"move": Vector2.UP, "secondary": true})
		_expect(brief.attachment_mode == 0, "exhausted grab flickered back before its reserve recovered")
	var patient = _new_rig(&"clamberer", Vector2(200.0, 160.0))
	for tick: int in range(1800):
		_step(patient, world, {"secondary": true})
		_expect(patient.attachment_mode == 1, "Clamberer could not sustain its declared 30-second stationary adhesion")
	_expect(patient.energy > 0.15 and patient.energy < 0.35, "Clamberer long-adhesion resource use disagrees with its declared envelope")


func _jump_flight_and_ground_sensing() -> void:
	var world := RigWorld.new()
	world.floor_y = 400.0
	var scout = _new_rig(&"scout", Vector2(200.0, 388.0))
	_step(scout, world, {"primary": true, "effort": 1.0})
	_expect(scout.velocity.y < -70.0 and scout.air_jumps_remaining == 1, "Scout's first jump did not spend one air jump")
	for tick: int in range(8):
		_step(scout, world, {"primary": true})
	_expect(scout.air_jumps_remaining == 1, "held Scout jump consumed or repeated the air jump")
	_step(scout, world)
	_step(scout, world, {"primary": true, "effort": 1.0})
	_expect(scout.velocity.y < -70.0 and scout.air_jumps_remaining == 0, "Scout's second press did not double jump")
	for tick: int in range(8):
		_step(scout, world)
	var before: float = scout.velocity.y
	_step(scout, world, {"primary": true})
	_expect(scout.air_jumps_remaining == 0 and scout.velocity.y > before,
		"Scout gained an unauthorized third air jump")
	for tick: int in range(150):
		_step(scout, world)
	_expect(scout.grounded and scout.air_jumps_remaining == 2, "landing did not restore Scout's jump budget")

	for rig_id: StringName in [&"scout", &"pouncer"]:
		var air_world := RigWorld.new()
		var gliding = _new_rig(rig_id)
		var falling = _new_rig(rig_id)
		gliding.velocity = Vector2(20.0, 80.0)
		falling.velocity = gliding.velocity
		_step(gliding, air_world, {"secondary": true})
		_step(falling, air_world)
		_expect(gliding.velocity.y > 0.0 and gliding.velocity.y < falling.velocity.y,
			str(rig_id) + " glide did not slow actual descent")

	var near_world := RigWorld.new()
	var far_world := RigWorld.new()
	near_world.floor_y = 112.0
	far_world.floor_y = 300.0
	var near = _new_rig(&"groundeffect", Vector2(200.0, 100.0))
	var far = _new_rig(&"groundeffect", Vector2(200.0, 100.0))
	var settling = _new_rig(&"groundeffect", Vector2(200.0, 100.0))
	_step(near, near_world)
	_step(far, far_world)
	_step(settling, near_world, {"secondary": true})
	_expect(near.velocity.y < 0.0 and far.velocity.y > 0.0,
		"GroundEffect cushion ignored the bounded distance to real ground")
	_expect(settling.velocity.y > near.velocity.y, "GroundEffect settling brake did not relinquish lift")

	var air_world := RigWorld.new()
	var rotor = _new_rig(&"copter")
	var cut_rotor = _new_rig(&"copter")
	_step(rotor, air_world, {"effort": 1.0})
	_step(cut_rotor, air_world, {"effort": 1.0, "auxiliary": true})
	_expect(rotor.velocity.y < 0.0 and cut_rotor.velocity.y > 0.0 and cut_rotor.auxiliary_active,
		"Copter cut-power toggle did not distinguish powered lift from ballistic fall")
	var stabilized = _new_rig(&"copter")
	var tumbling = _new_rig(&"copter")
	stabilized.rotation = 0.3
	tumbling.rotation = 0.3
	stabilized.angular_velocity = 3.0
	tumbling.angular_velocity = 3.0
	_step(stabilized, air_world, {"secondary": true})
	_step(tumbling, air_world)
	_expect(absf(stabilized.angular_velocity) < absf(tumbling.angular_velocity),
		"Copter stabilizer did not oppose actual body spin")

	var stationary = _new_rig(&"skatesail")
	var fast = _new_rig(&"skatesail")
	fast.velocity.x = 80.0
	_step(stationary, air_world, {"secondary": true, "trim": 1.0})
	_step(fast, air_world, {"secondary": true, "trim": 1.0})
	_expect(stationary.velocity.y > 0.0 and fast.velocity.y >= 0.0 \
		and fast.velocity.y < stationary.velocity.y, "Skatesail granted stationary hover or ignored the airspeed lift requirement")


func _charged_and_impulse_tools() -> void:
	var world := RigWorld.new()
	world.floor_y = 400.0
	var pouncer = _new_rig(&"pouncer", Vector2(200.0, 390.0))
	for tick: int in range(24):
		_step(pouncer, world, {"primary": true, "aim": Vector2.UP, "effort": 1.0})
	_expect(pouncer.charge > 0.4 and pouncer.grounded, "Pouncer did not coil on support while held")
	_step(pouncer, world, {"aim": Vector2.UP})
	_expect(pouncer.velocity.y < -90.0 and pouncer.charge == 0.0,
		"deliberate Pouncer release did not spend preload on a stronger leap")
	var spring = _new_rig(&"springjack", Vector2(200.0, 388.0))
	var launches: int = 0
	for tick: int in range(240):
		var was_falling: bool = spring.velocity.y >= 0.0
		_step(spring, world, {"primary": true})
		if was_falling and spring.velocity.y < 0.0:
			launches += 1
	_expect(launches >= 2, "Springjack held action did not produce a supported pogo rhythm")
	spring.clear_actions()
	for tick: int in range(160):
		_step(spring, world)
	_expect(spring.grounded and spring.velocity.y >= 0.0, "cancelled Springjack continued its automatic bounce cadence")
	var empty_gyro = _new_rig(&"gyrocrate", Vector2(200.0, 390.0))
	var spinning_gyro = _new_rig(&"gyrocrate", Vector2(200.0, 390.0))
	spinning_gyro.angular_velocity = 3.0
	_step(empty_gyro, world, {"secondary": true})
	_step(spinning_gyro, world, {"secondary": true})
	_expect(empty_gyro.velocity.y >= 0.0 and spinning_gyro.velocity.y < 0.0 \
		and absf(spinning_gyro.angular_velocity) < 3.0,
		"Gyrocrate hop did not require and spend actual flywheel spin")

	var air_world := RigWorld.new()
	for rig_id: StringName in [&"astra", &"luna", &"bellows", &"jev", &"rocketjumper"]:
		var actor = _new_rig(rig_id)
		var aim: Vector2 = Vector2.RIGHT if rig_id == &"rocketjumper" else Vector2.LEFT
		var action_world := RigWorld.new()
		if rig_id == &"rocketjumper":
			action_world.obstacles.append(Rect2(191.0, 85.0, 1.0, 80.0))
		_step(actor, action_world, {"move": Vector2.RIGHT, "aim": aim, "primary": true})
		_expect(actor.velocity.x < -10.0 and actor.primary_active and actor.cooldown_remaining > 0.0,
			str(rig_id) + " lost independent aim or its authored impulse/cooldown")
		var energy: float = actor.energy
		_expect(energy < 1.0, "impulse action had no resource cost")
		for tick: int in range(40):
			_step(actor, action_world, {"primary": true, "aim": aim})
			_expect(not actor.primary_active and actor.effect_kind == 0,
				"held impulse repeated without a new edge after cooldown")
		actor.reset(Vector2(180.0, 100.0))
		actor.energy = 0.0
		_step(actor, action_world, {"primary": true, "aim": aim})
		_expect(not actor.primary_active and actor.effect_kind == 0 \
			and not actor.primary_ready, "exhausted impulse fired or advertised resource readiness")
	var unsupported_rocket = _new_rig(&"rocketjumper")
	_step(unsupported_rocket, air_world, {"primary": true, "aim": Vector2.RIGHT})
	_expect(not unsupported_rocket.primary_active and unsupported_rocket.effect_kind == 0 \
		and unsupported_rocket.energy == 1.0 and unsupported_rocket.velocity.x == 0.0,
		"Rocketjumper manufactured an explosion impulse or spent energy without a nearby surface")

	var bellows = _new_rig(&"bellows")
	var uncharged = _new_rig(&"bellows")
	for tick: int in range(30):
		_step(bellows, air_world, {"secondary": true})
	var stored: float = bellows.charge
	bellows.velocity = Vector2.ZERO
	_step(bellows, air_world, {"primary": true, "aim": Vector2.UP})
	_step(uncharged, air_world, {"primary": true, "aim": Vector2.UP})
	_expect(stored > 0.3 and bellows.charge < stored and bellows.velocity.y < uncharged.velocity.y,
		"Bellows inhale did not increase and spend the next pulse's bonus reserve")
	_step(bellows, air_world, {"auxiliary": true})
	_expect(bellows.charge == 0.0, "Bellows vent retained stored bonus pressure")

	var left = _new_rig(&"gemini")
	var right = _new_rig(&"gemini")
	var paired = _new_rig(&"gemini")
	_step(left, air_world, {"primary": true, "effort": 1.0})
	_step(right, air_world, {"secondary": true, "effort": 1.0})
	_step(paired, air_world, {"primary": true, "secondary": true, "effort": 1.0})
	_expect(left.angular_velocity > 0.0 and right.angular_velocity < 0.0 \
		and absf(paired.angular_velocity) < 0.0001, "Gemini paired controls did not produce opposing, balanced body torque")
	_expect(paired.velocity.y < left.velocity.y and paired.velocity.y < right.velocity.y,
		"paired thrusters supplied no additional lift")

	var wall_world := RigWorld.new()
	wall_world.obstacles.append(Rect2(207.0, 80.0, 1.0, 100.0))
	var ricochet = _new_rig(&"jev", Vector2(195.0, 100.0))
	var stopped = _new_rig(&"jev", Vector2(195.0, 100.0))
	ricochet.velocity = Vector2(100.0, 0.0)
	stopped.velocity = ricochet.velocity
	_step(ricochet, wall_world, {"secondary": true}, 1.0 / 30.0)
	_step(stopped, wall_world, {}, 1.0 / 30.0)
	_expect(ricochet.velocity.x < 0.0 and absf(ricochet.velocity.x) < 100.0 \
		and stopped.velocity.x == 0.0, "Jev contact response did not produce a lossy optional rebound")
	_expect(_body_bounds(ricochet).end.x <= 207.0001 and _body_bounds(stopped).end.x <= 207.0001,
		"ricochet response crossed its one-cell contact wall")


func _tether_lifetimes_and_obstructions() -> void:
	for rig_id: StringName in [&"lineshank", &"swinger", &"winchbug"]:
		var world := RigWorld.new()
		var actor = _new_rig(rig_id, Vector2(200.0, 160.0))
		world.obstacles.append(Rect2(240.0, 130.0, 1.0, 100.0))
		world.obstacles.append(Rect2(224.0, 130.0, 1.0, 100.0))
		_step(actor, world, {"primary": true, "aim": Vector2.RIGHT})
		_expect(actor.attachment_mode == (3 if rig_id == &"lineshank" else 2) \
			and floori(actor.anchor.x) == 224, "tether skipped the first visible one-cell surface")
		var original_length: float = actor.rope_length
		_step(actor, world, {"aim": Vector2.RIGHT, "reel": -1.0})
		_expect(actor.rope_length < original_length and actor.rope_length >= 6.0,
			"independent reel input did not shorten the bounded line")
		world.obstacles.append(Rect2(218.0, 130.0, 1.0, 100.0))
		_step(actor, world, {"primary": true, "aim": Vector2.RIGHT, "reel": -1.0})
		_expect(actor.attachment_mode == 0 and actor.tension == 0.0,
			"existing line pulled through a newly occluding one-cell wall")
		_expect(_body_bounds(actor).end.x <= 218.0001, "line pull tunneled through its new obstruction")
		world.obstacles.clear()
		actor.reset(Vector2(200.0, 160.0))
		world.obstacles.append(Rect2(230.0, 130.0, 1.0, 100.0))
		_step(actor, world, {"primary": true, "aim": Vector2.RIGHT})
		_expect(actor.attachment_mode != 0, "anchor-removal fixture did not attach")
		world.obstacles.clear()
		_step(actor, world, {"primary": true, "aim": Vector2.RIGHT})
		_expect(actor.attachment_mode == 0 and actor.anchor == Vector2.ZERO,
			"tether survived removal of its authoritative anchor")
		actor.reset(Vector2(200.0, 160.0))
		world.obstacles.append(Rect2(270.0, 130.0, 1.0, 100.0))
		_step(actor, world, {"primary": true, "aim": Vector2.RIGHT})
		_expect(actor.attachment_mode == 0, "tether attached beyond its declared maximum cast range")
		world.obstacles.clear()
		actor.reset(Vector2(1010.0, 160.0))
		_step(actor, world, {"primary": true, "aim": Vector2.RIGHT})
		_expect(actor.attachment_mode == 0, "native OOB Wall sentinel became a valid grappling anchor")
		for point: Vector2i in world.read_positions:
			_expect(point.x >= 0 and point.y >= 0 and point.x < 1024 and point.y < 1024,
				"tether read outside the finite World before refusing a target")

	var world := RigWorld.new()
	var bungee = _new_rig(&"lineshank", Vector2(200.0, 160.0))
	world.obstacles.append(Rect2(240.0, 130.0, 1.0, 100.0))
	_step(bungee, world, {"primary": true, "aim": Vector2.RIGHT})
	_expect(bungee.attachment_mode == 3 and bungee.tension > 0.0,
		"Lineshank did not store elastic tension on its shorter bungee")
	_step(bungee, world, {"auxiliary": true, "aim": Vector2.RIGHT})
	_expect(bungee.attachment_mode == 0 and bungee.velocity.x > 0.0,
		"slingshot release retained the constraint or discarded all launch momentum")
	_step(bungee, world, {"secondary": true, "aim": Vector2.UP})
	_expect(bungee.velocity.y < 0.0 and bungee.effect_kind == Effects.DIG,
		"Lineshank's independent blade action produced no lift/tool request")
	var air_world := RigWorld.new()
	var lifting = _new_rig(&"lineshank")
	var diving = _new_rig(&"lineshank")
	var stationary = _new_rig(&"lineshank")
	for blade in [lifting, diving, stationary]:
		_step(blade, air_world, {"secondary": true})
		blade.velocity = Vector2.ZERO
		blade.rotation = PI * 0.25
		blade.angular_velocity = 0.0
	lifting.velocity.x = 80.0
	diving.velocity.x = 80.0
	diving.rotation = -PI * 0.25
	_step(lifting, air_world, {"secondary": true, "aim": Vector2.UP.rotated(PI * 0.25)})
	_step(diving, air_world, {"secondary": true, "aim": Vector2.UP.rotated(-PI * 0.25)})
	_step(stationary, air_world, {"secondary": true, "aim": Vector2.UP.rotated(PI * 0.25)})
	_expect(lifting.velocity.y < stationary.velocity.y and diving.velocity.y > stationary.velocity.y \
		and stationary.velocity.y > 0.0, "held blade ignored incidence/airspeed or manufactured lift at rest")
	_expect(lifting.effect_kind == 0 and diving.effect_kind == 0 and stationary.effect_kind == 0,
		"held blade aerodynamics replayed the edge-triggered tool pulse")
	stationary.rotation = 0.0
	stationary.angular_velocity = 0.0
	_step(stationary, air_world, {"secondary": true, "aim": Vector2.RIGHT})
	_expect(stationary.angular_velocity > 0.0 and stationary.rotation > 0.0,
		"independent blade aim did not change actual knife attitude")

	# A transient composed body mask is revalidated every tick. Removing or
	# moving that mask must not leave a phantom persistent rope anchor.
	var masked = _new_rig(&"swinger", Vector2(200.0, 160.0))
	world = RigWorld.new()
	world.masks[Vector2i(226, 166)] = true
	_step(masked, world, {"primary": true, "aim": Vector2.RIGHT})
	_expect(masked.attachment_mode == 2, "composed-mask anchor fixture did not attach")
	world.masks.clear()
	world.masks[Vector2i(227, 166)] = true
	_step(masked, world, {"primary": true, "aim": Vector2.RIGHT})
	_expect(masked.attachment_mode == 0, "moved body mask retained a phantom static anchor")


func _motor_effect_origins_and_dive() -> void:
	for rig_id: StringName in [&"ripper", &"rocketjumper"]:
		var world := RigWorld.new()
		world.floor_y = 220.0
		var actor = _new_rig(rig_id, Vector2(200.0, 190.0))
		var wall_x: int = 200 + int(actor.body_size.x)
		world.obstacles.append(Rect2(float(wall_x), 170.0, 1.0, 50.0))
		world.fill(Vector2i(wall_x + 1, 180), Vector2i(9, 30), 2)
		var protected_cells: Dictionary = world.cells.duplicate(true)
		_step(actor, world, {"primary": true, "aim": Vector2.RIGHT})
		_expect(world.cells == protected_cells,
			str(rig_id) + " placed its tool origin beyond an adjacent protected wall and edited hidden cells")
		_expect(world.writes == 0, "occluded actor-to-tool origin still reached the native write boundary")

	var world := RigWorld.new()
	world.fill(Vector2i(196, 200), Vector2i(18, 12), 2)
	var digger = _new_rig(&"digger", Vector2(200.0, 194.0))
	_step(digger, world, {"primary": true, "aim": Vector2.UP, "move": Vector2.RIGHT, "effort": 1.0})
	_expect(digger.effect_kind == Effects.DIG and digger.edited_cells_last > 0,
		"Digger did not apply bounded excavation to editable material at its nose")
	_expect(digger.velocity.y > absf(digger.velocity.x) and digger.position.y > 194.0,
		"Digger ignored its downward drilling cone or failed to enter cleared material")
	for command: Dictionary in world.write_commands:
		_expect(int(command.y) >= 200 and int(command.radius) == 0,
			"downward drill wrote outside the local editable face")

	world = RigWorld.new()
	world.floor_y = 220.0
	var dropbot = _new_rig(&"dropbot", Vector2(200.0, 170.0))
	var impact_seen: bool = false
	for tick: int in range(30):
		_step(dropbot, world, {"auxiliary": true, "aim": Vector2.DOWN})
		if dropbot.effect_kind == Effects.BLAST:
			impact_seen = true
			_expect(dropbot.velocity.y < 0.0 and dropbot.effect_radius <= 3.0,
				"Dropbot impact did not rebound through its bounded authored effect")
		_expect(_body_bounds(dropbot).end.y <= 220.0001, "Dropbot dive crossed a one-cell solid landing plane")
	_expect(impact_seen, "Dropbot's committed dive never generated its contact-triggered effect")

	world = RigWorld.new()
	world.floor_y = 200.0
	world.obstacles.append(Rect2(235.0, 170.0, 1.0, 60.0))
	var magpie = _new_rig(&"magpie", Vector2(200.0, 190.0))
	for tick: int in range(24):
		_step(magpie, world, {"secondary": true})
	_expect(magpie.charge >= 0.15, "Magpie clamp did not charge its capacitor on actual support")
	_step(magpie, world, {"primary": true, "aim": Vector2.RIGHT})
	_expect(magpie.velocity.x > 30.0 and magpie.charge == 0.0,
		"Magpie did not spend charge on a visible, swept lunge")
	magpie.reset(Vector2(200.0, 190.0))
	world.obstacles.clear()
	for tick: int in range(24):
		_step(magpie, world, {"secondary": true})
	_step(magpie, world, {"primary": true, "aim": Vector2.UP})
	_expect(not magpie.primary_active and magpie.charge >= 0.15,
		"Magpie spent its targeted lunge on empty air without a bounded visible surface")


func _native_smoke() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "source-matched native runtime is unavailable")
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	_expect(world.diagnostic_reset({"workers": 1}), "native rig fixture reset failed")
	_expect(world.diagnostic_fill_rect(Vector2i(40, 120), Vector2i(100, 1), CyberCellWorld.WALL),
		"native rig floor setup failed")
	_expect(world.diagnostic_fill_rect(Vector2i(110, 20), Vector2i(1, 100), CyberCellWorld.WALL),
		"native rig one-cell wall setup failed")
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(40, 20), Vector2i(100, 101), true)
	for rig_id: StringName in RIG_IDS:
		var actor = _new_rig(rig_id, Vector2(76.0, 65.0))
		for tick: int in range(48):
			actor.simulate_rig_action(DT, Vector2.RIGHT, Vector2.RIGHT, 0.7,
				0.0, 0.0, false, false, false, world)
			var state: PackedFloat32Array = actor.rig_observation()
			_expect(actor.position.is_finite() and actor.velocity.is_finite() \
				and actor.query_count_last <= MAX_QUERIES, "native rig motion/query contract failed")
			_expect(actor.centre().x < 110.0 and actor.centre().y < 120.0,
				"native rig crossed the hard wall/floor")
			_expect(state.size() == 40 and int(state[29]) <= MAX_RAYS \
				and int(state[30]) == 0, "idle native rig emitted a tool effect or exceeded ray work")
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(40, 20), Vector2i(100, 101), true)
	_expect(before.get("hash") == after.get("hash") and before.get("counts") == after.get("counts"),
		"ordinary hard-surface rig motion changed native material authority")
	_expect(int(world.tick_index) == 0, "rig movement secretly stepped the native World")
	_expect(world.diagnostic_fill_rect(Vector2i(156, 76), Vector2i(9, 9), CyberCellWorld.SAND),
		"native tool material fixture setup failed")
	_expect(world.diagnostic_fill_rect(Vector2i(161, 76), Vector2i(1, 9), CyberCellWorld.WALL),
		"native tool occluder setup failed")
	var effect := Effects.new()
	effect.apply(world, Effects.BLAST, Vector2(160.0, 80.0), 4)
	_expect(int(world.material_at(160, 80)) == CyberCellWorld.FIRE \
		and int(world.material_at(159, 80)) == CyberCellWorld.EMPTY,
		"existing native point-write API did not apply the bounded gameplay blast")
	_expect(int(world.material_at(161, 80)) == CyberCellWorld.WALL \
		and int(world.material_at(162, 80)) == CyberCellWorld.SAND,
		"native gameplay blast removed its wall or edited hidden material")
	_expect(effect.reads_last == 49 and effect.writes_last <= 49,
		"native gameplay effect exceeded its declared footprint")


func _timing_report() -> void:
	const STEPS: int = 600
	for rig_id: StringName in RIG_IDS:
		var actor = _new_rig(rig_id, Vector2(180.0, 100.0))
		var world := RigWorld.new()
		world.floor_y = 600.0
		var maximum_queries: int = 0
		var maximum_reads: int = 0
		var start: int = Time.get_ticks_usec()
		for tick: int in range(STEPS):
			world.clear_counters()
			actor.simulate_rig_action(DT, Vector2(1.0 if tick % 240 < 120 else -1.0, -0.25),
				Vector2.UP, 0.7, 0.1, 0.0, tick % 90 < 4, tick % 120 == 0,
				tick % 150 == 0, world)
			maximum_queries = maxi(maximum_queries, world.queries)
			maximum_reads = maxi(maximum_reads, world.material_reads)
		var elapsed: int = Time.get_ticks_usec() - start
		_expect(maximum_queries <= MAX_QUERIES and maximum_reads <= MAX_RAYS + MAX_EFFECT_READS,
			"long-run rig cost exceeded its fixed budget")
		timings.append({"rig": str(rig_id), "steps": STEPS,
			"mean_microseconds": float(elapsed) / float(STEPS),
			"maximum_occupancy_queries": maximum_queries, "maximum_material_reads": maximum_reads,
			"scope": "headless host / mock World / informational motor timing"})


func _run() -> void:
	_common_contract()
	_effect_envelope_and_occlusion()
	_effect_refusals()
	_rotation_and_tuck_geometry()
	_contact_and_adhesion()
	_jump_flight_and_ground_sensing()
	_charged_and_impulse_tools()
	_tether_lifetimes_and_obstructions()
	_motor_effect_origins_and_dive()
	_native_smoke()
	_timing_report()
	print("ACTOR_RIGS ", JSON.stringify({"assertions": assertions, "failures": failures,
		"peak_occupancy_queries": peak_queries, "peak_ray_queries": peak_rays,
		"peak_effect_reads": peak_effect_reads, "peak_effect_writes": peak_effect_writes,
		"timings": timings}))
	quit(1 if failures else 0)
