extends SceneTree

# Structural and producer-level checks only. Actual Rapier traversal, contact,
# articulation and native-material evidence belong to the physical runtime test.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Pilot = preload("res://scripts/physical_actor_script.gd")
const LEGACY_IDS: Array[StringName] = [
	&"runner", &"skimmer", &"crawler", &"scout", &"scrabbler", &"ripper",
	&"groundeffect", &"digger", &"copter", &"pouncer", &"dropbot", &"lineshank",
	&"walljumper", &"clamberer", &"swinger", &"rocketjumper", &"springjack",
	&"gyrocrate", &"bellows", &"winchbug", &"magpie", &"skatesail",
	&"astra", &"claude", &"luna", &"qwen", &"bonsai", &"jev", &"gemini",
]
var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("PHYSICAL_ACTOR_CATALOG: " + message)


func _observation(rig_id: StringName) -> Dictionary:
	return {"rig_id": rig_id, "epoch": 1, "centre": Vector2(100, 80), "position": Vector2(100, 80),
		"velocity": Vector2.ZERO, "rotation": 0.0, "angular_velocity": 0.0,
		"grounded": true, "contact_normal": Vector2.UP, "ground_distance": 0.5,
		"wall_left": false, "wall_right": false, "ceiling_distance": 80.0,
		"gripped": false, "energy": 1.0, "charge": 1.0, "cooldown": 0.0,
		"rope_attached": false, "anchor": Vector2(110, 45), "rope_length": 36.0,
		"tension": 0.0, "blocked": false, "powered": true, "mode": "ground",
		"tool_ready": true, "gravity": 156.0, "parts": [], "joints": []}


func _run() -> void:
	_expect(Catalog.RIG_IDS.size() == 46, "expected all 41 retained and five player rigs")
	_expect(Catalog.rigs_in_set(&"setX").size() == 12, "extra roster must contain twelve entries")
	_expect(Catalog.rigs_in_set(&"setP") == [&"stuntbuggy", &"trialsbike", &"acrobat", &"arcadelander", &"jetbarrel"], "player roster identities")
	var seen: Dictionary = {}
	var geometry_signatures: Dictionary = {}
	var mechanisms: Dictionary = {}
	for rig_id: StringName in Catalog.RIG_IDS:
		_expect(not seen.has(rig_id), "duplicate rig identity: " + str(rig_id))
		seen[rig_id] = true
		var data: Dictionary = Catalog.entry(rig_id)
		_validate_definition(rig_id, data)
		for joint: Dictionary in data.joints:
			mechanisms[str(joint.type)] = true
		if rig_id in Catalog.EXTRA_NAMES:
			var geometry: Array = []
			for part: Dictionary in data.parts:
				geometry.append([part.offset, part.size, part.mass, part.angle])
			var signature: String = JSON.stringify(geometry)
			_expect(not geometry_signatures.has(signature), "extra rigs repeat geometry: " + str(rig_id))
			geometry_signatures[signature] = true
		_test_script(rig_id)
	for old_id: StringName in LEGACY_IDS:
		_expect(seen.has(old_id), "legacy actor omitted: " + str(old_id))
	_expect(mechanisms.has("rotary") and mechanisms.has("spring") and mechanisms.has("slide"), "catalogue lacks articulated mechanism coverage")
	var first: Dictionary = Catalog.entry(&"scrabbler")
	first.parts[0].size = Vector2(99, 99)
	first.profile.speed = -1.0
	first.mounts.clear()
	var fresh: Dictionary = Catalog.entry(&"scrabbler")
	_expect(fresh.parts[0].size != Vector2(99, 99) and fresh.profile.speed > 0.0 \
		and not fresh.mounts.is_empty(), "catalogue result aliases shared state")
	_expect(Catalog.entry(&"unknown").is_empty(), "unknown rig silently becomes an actor")
	_test_feedback()
	_test_lifetimes()
	print("PHYSICAL_ACTOR_CATALOG: %d assertions, %d failures; 46 definitions, retained feedback and player controls" % [assertions, failures])
	quit(1 if failures else 0)


func _validate_definition(rig_id: StringName, data: Dictionary) -> void:
	_expect(data.get("id", &"") == rig_id, "wrong catalogue identity")
	var count: int = data.parts.size()
	_expect(count >= 1 and count <= 8, str(rig_id) + " exceeds total physical part budget")
	_expect(data.joints.size() >= count - 1, str(rig_id) + " contains floating decorative parts")
	_expect(not str(data.description).is_empty() and not str(data.controls).is_empty(), str(rig_id) + " lacks controls/purpose")
	_expect(float(data.spawn_floor_clearance) > 0 and float(data.spawn_radius) > 0, "invalid spawn envelope")
	var connections: Dictionary = {0: true}
	var ids: Dictionary = {}
	for part: Dictionary in data.parts:
		_expect(not ids.has(part.id), str(rig_id) + " duplicates a physical part id")
		ids[part.id] = true
		_expect(part.offset.is_finite() and part.size.is_finite() and is_finite(float(part.angle)), "nonfinite geometry")
		_expect(part.shape in ["rectangle", "circle"] and part.size.x > 0.0 and part.size.y > 0.0 \
			and part.size.x <= 32.0 and part.size.y <= 32.0, "unsupported collider dimensions")
		if part.shape == "circle":
			_expect(rig_id in [&"stuntbuggy", &"trialsbike"] and is_equal_approx(part.size.x, part.size.y) \
				and str(part.get("native_mask", "")) == "circumscribed_rectangle", "circle approximation requires explicit player wheel scope")
		_expect(is_finite(float(part.mass)) and part.mass > 0.0, "invalid part mass")
		var transform := Transform2D(part.angle, part.offset)
		var half: Vector2 = part.size * 0.5
		for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
				Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
			_expect(data.bounds.grow(0.001).has_point(transform * corner), "spawn envelope excludes a collider corner")
	for joint: Dictionary in data.joints:
		_expect(joint.a >= 0 and joint.b >= 0 and joint.a < count and joint.b < count \
			and joint.a != joint.b, "invalid joint endpoint")
		_expect(str(joint.type) in ["rotary", "slide", "spring"], "unknown joint type")
		_expect(joint.anchor.is_finite() and joint.axis.is_finite() and joint.limits.is_finite(), "nonfinite joint geometry")
		_expect(joint.limits.y >= joint.limits.x and joint.max_force > 0.0 and joint.max_force <= 5000.0, "unbounded motor/limit")
		if str(joint.type) in ["slide", "spring"]:
			_expect(joint.anchor.is_equal_approx(data.parts[joint.b].offset), "slider initial anchor would snap")
			_expect(joint.limits.x <= 0.0 and joint.limits.y >= 0.0, "slider starts outside its travel")
	for _iteration: int in range(count):
		for joint: Dictionary in data.joints:
			if connections.has(joint.a):
				connections[joint.b] = true
			if connections.has(joint.b):
				connections[joint.a] = true
	_expect(connections.size() == count, str(rig_id) + " physical graph is disconnected")
	for mount: Dictionary in data.mounts:
		_expect(mount.part >= 0 and mount.part < count and mount.offset.is_finite(), "invalid usable mount")
		_expect(str(mount.type) in ["mounted", "recoil", "articulated"], "unknown usable type")
		if mount.has("held_part"):
			_expect(mount.held_part >= 0 and mount.held_part < count, "held usable bypasses actor part budget")
	for key: String in ["speed", "accel", "gravity", "gyro", "damping", "jump", "thrust"]:
		_expect(is_finite(float(data.profile[key])) and float(data.profile[key]) > 0.0, "invalid gameplay profile " + key)


func _test_script(rig_id: StringName) -> void:
	var first = Pilot.new()
	var twin = Pilot.new()
	_expect(first.configure(rig_id, Vector2(100, 80), 0), "script refused " + str(rig_id))
	_expect(twin.configure(rig_id, Vector2(100, 80), 0), "second script refused " + str(rig_id))
	var observation: Dictionary = _observation(rig_id)
	var active: bool = false
	for tick: int in range(36):
		# The same externally supplied history yields the same commands. This
		# fixture changes observations; it does not pretend to emulate Rapier.
		observation.centre = Vector2(100 + float(tick) * 0.5, 80 - float(tick % 8))
		observation.position = observation.centre
		observation.velocity = Vector2(5.0, -2.0 if tick % 8 < 4 else 2.0)
		observation.grounded = tick % 8 == 0
		observation.contact_normal = Vector2.UP if observation.grounded else Vector2.ZERO
		var action: Dictionary = first.next_action(observation, 0.1)
		_expect(action == twin.next_action(observation, 0.1), "script nondeterminism " + str(rig_id))
		_expect(action.move.is_finite() and action.move.length() <= 1.415 \
			and action.aim.is_finite() and is_finite(float(action.trim)) \
			and absf(action.trim) <= 1.0 and action.effort >= 0.0 and action.effort <= 1.0,
			"unbounded scripted request " + str(rig_id))
		active = active or action.move.length_squared() > 0.1 or action.primary
	_expect(active, "script is inert " + str(rig_id))
	first.reset(Vector2(100, 80))
	twin.reset(Vector2(100, 80))
	_expect(first.next_action(_observation(rig_id), 0.1) == twin.next_action(_observation(rig_id), 0.1), "reset mismatch")


func _test_feedback() -> void:
	var runner = Pilot.new()
	runner.configure(&"runner", Vector2(100, 80))
	var obs: Dictionary = _observation(&"runner")
	var initial: Dictionary = runner.next_action(obs, 0.1)
	_expect(initial.move.x > 0.0, "runner does not start toward route")
	for _tick: int in range(3):
		runner.next_action(obs, 0.1)
	_expect(float(runner.diagnostics().direction) > 0.0, "zero startup speed causes immediate alternating direction")
	obs.wall_right = true
	obs.blocked = true
	for _tick: int in range(12):
		runner.next_action(obs, 0.1)
	_expect(int(runner.diagnostics().recovery_count) == 1 \
		and float(runner.diagnostics().direction) < 0.0, "wall stall does not produce one bounded reversal")
	var recovered: Dictionary = runner.next_action(obs, 0.1)
	_expect(recovered.move.x < 0.0, "recovery continues driving into observed wall")
	var flier = Pilot.new()
	flier.configure(&"skimmer", Vector2(100, 80))
	var flight: Dictionary = _observation(&"skimmer")
	flight.grounded = false
	flight.contact_normal = Vector2.ZERO
	flight.ceiling_distance = 2.0
	_expect(flier.next_action(flight, 0.1).move.y > 0.0, "flier ignores nearby ceiling")
	flight.ceiling_distance = 80.0
	flight.rotation = 1.6
	flight.angular_velocity = 3.0
	var tilted: Dictionary = flier.next_action(flight, 0.1)
	_expect(tilted.trim < 0.0 and absf(tilted.move.x) < 0.5, "flier fails to countersteer a large tilt")
	var route = Pilot.new()
	route.configure(&"skimmer", Vector2(100, 80))
	var endpoint: Dictionary = _observation(&"skimmer")
	endpoint.centre = Vector2(132.5, 60)
	endpoint.position = endpoint.centre
	endpoint.grounded = false
	endpoint.contact_normal = Vector2.ZERO
	_expect(route.next_action(endpoint, 0.1).move.x < 0.0, "flier asymptotically parks at route endpoint instead of turning")
	var hover = Pilot.new()
	hover.configure(&"groundeffect", Vector2(100, 80))
	var cushion: Dictionary = _observation(&"groundeffect")
	cushion.ground_distance = 3.0
	_expect(hover.next_action(cushion, 0.1).move.y < 0.0, "ground cushion does not request clearance")
	var rope = Pilot.new()
	rope.configure(&"swinger", Vector2(100, 80))
	var swinging: Dictionary = _observation(&"swinger")
	swinging.rope_attached = true
	swinging.grounded = false
	swinging.velocity = Vector2(24, -10)
	var release: bool = false
	for _tick: int in range(8):
		release = release or rope.next_action(swinging, 0.1).secondary
	_expect(release, "rope controller misses observed rising release window")
	var duet = Pilot.new()
	duet.configure(&"gemini", Vector2(100, 80))
	var paired: Dictionary = _observation(&"gemini")
	paired.centre = Vector2(100, 55)
	paired.position = paired.centre
	paired.rotation = 0.6
	paired.angular_velocity = 0.2
	var differential: bool = false
	var collective_off: bool = false
	for _tick: int in range(48):
		var balance: Dictionary = duet.next_action(paired, 0.1)
		differential = differential or balance.primary != balance.secondary
		collective_off = collective_off or (not balance.primary and not balance.secondary)
	_expect(differential, "Duet always drives both independent pods identically")
	_expect(collective_off, "Duet ignores collective off-periods near its altitude target")
	paired.rotation = PI - 0.1
	var inverted: Dictionary = duet.next_action(paired, 0.1)
	_expect(not inverted.primary and not inverted.secondary and not inverted.auxiliary,
		"Duet pins its inverted hull with thrust instead of righting before relaunch")


func _test_lifetimes() -> void:
	var pouncer = Pilot.new()
	pouncer.configure(&"pouncer", Vector2(100, 80))
	var obs: Dictionary = _observation(&"pouncer")
	var held: bool = false
	var released: bool = false
	for _tick: int in range(10):
		var action: Dictionary = pouncer.next_action(obs, 0.1)
		if action.primary:
			held = true
		elif held:
			released = true
	_expect(held and released, "charged skill lacks a deliberate hold/release sequence")
	pouncer.reset(Vector2(100, 80))
	for _tick: int in range(3):
		pouncer.next_action(obs, 0.1)
	_expect(bool(pouncer.diagnostics().charge_holding), "charge fixture failed to arm")
	pouncer.cancel()
	obs.suspended = true
	var cancelled: Dictionary = pouncer.next_action(obs, 0.1)
	_expect(cancelled == Pilot.neutral_action() and not bool(pouncer.diagnostics().charge_holding), "cancel retained a charged request")
	obs.suspended = false
	_expect(not pouncer.next_action(obs, 0.1).primary, "resume immediately rearms old action")
	obs.epoch = 2
	_expect(pouncer.next_action(obs, 0.1) == Pilot.neutral_action(), "new actor epoch receives stale commands")
	obs.velocity = Vector2(NAN, 0)
	_expect(pouncer.next_action(obs, 0.1) == Pilot.neutral_action(), "nonfinite observations produce motion")
	_expect(pouncer.next_action(_observation(&"pouncer"), 0.0) == Pilot.neutral_action(), "zero time advances producer")
