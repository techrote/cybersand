extends SceneTree

# Pure schema/actuator contract. Real Rapier motion and owner admission are
# covered separately by the physical-flight physics/session fixtures.
const Profile = preload("res://scripts/physical_flight_profile.gd")
const Controller = preload("res://scripts/physical_flight_controller.gd")
const DT: float = 1.0 / 60.0
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, reason: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("FLIGHT_PROFILE: " + reason)


func test_schema() -> void:
	var seen_hashes: Dictionary = {}
	for id: StringName in Profile.IDS:
		var profile: Dictionary = Profile.entry(id)
		expect(Profile.validate(profile).is_empty(), "all reserved profiles validate " + str(id))
		expect(profile.calibration == "candidate_4ly002",
			"distinct authored values are candidates until the prospectively registered measurement gate " + str(id))
		var hash: String = Profile.profile_hash(profile)
		expect(hash.length() == 64 and not seen_hashes.has(hash), "each profile has unique complete hash " + str(id))
		seen_hashes[hash] = true
		expect(float(profile.max_force) > float(profile.mass) * float(profile.gravity) * 1.15,
			"unsupported hover and ascent have finite vertical thrust headroom " + str(id))
		var original_size: Array = profile.collider_size.duplicate()
		var view: Dictionary = Profile.descriptor(profile)
		view.collider_size[0] = 50.0
		view.capabilities.collider_size[0] = 50.0
		view.units.force = "changed"
		expect(profile.collider_size == original_size, "descriptor and policy-visible capabilities are deep copies " + str(id))
		expect(Profile.descriptor(profile).units.force == "authored_mass*cell/second^2", "nested descriptor copy " + str(id))
	var trainer: Dictionary = Profile.entry(&"4ly_trainer")
	var hauler: Dictionary = Profile.entry(&"4ly_hauler")
	var drifter: Dictionary = Profile.entry(&"4ly_drifter")
	var dart: Dictionary = Profile.entry(&"4ly_dart")
	expect(float(hauler.mass) > float(trainer.mass) and float(hauler.acceleration) < float(trainer.acceleration)
		and float(hauler.velocity_response_seconds) > float(trainer.velocity_response_seconds),
		"Hauler has distinct heavy, low-response actuator parameters")
	expect(float(drifter.braking) < float(trainer.braking) and float(drifter.linear_drag) < float(trainer.linear_drag)
		and float(drifter.attitude_kp) > 0.0, "Drifter has softer translation but finite upright assistance")
	expect(float(dart.acceleration) > float(trainer.acceleration) and float(dart.braking) > float(trainer.braking)
		and float(dart.mass) < float(trainer.mass), "Dart has faster, smaller physical handling parameters")
	var base: Dictionary = trainer
	for key: String in Profile.KEYS:
		var missing: Dictionary = base.duplicate(true)
		missing.erase(key)
		expect(not Profile.validate(missing).is_empty(), "missing key refused " + key)
	for key: String in Profile.NUMERIC_LIMITS:
		for invalid: Variant in [NAN, INF, -INF, true, "12", {}, []]:
			var malformed: Dictionary = base.duplicate(true)
			malformed[key] = invalid
			expect(not Profile.validate(malformed).is_empty(), "bad numeric refused " + key)
	var changed: Dictionary = base.duplicate(true)
	changed["goal"] = [1, 2]
	expect(not Profile.validate(changed).is_empty(), "unknown profile field refused")
	for key: String in ["collider_size", "desired_speed"]:
		for invalid: Variant in [Vector2.ONE, [1], [1, 2, 3], [NAN, 2], [true, 2], ["1", 2], [[1], 2], [-1, 2]]:
			changed = base.duplicate(true)
			changed[key] = invalid
			expect(not Profile.validate(changed).is_empty(), "malformed pair refused " + key)
	changed = base.duplicate(true)
	changed.inertia = 14.0
	expect(not Profile.validate(changed).is_empty(), "mass and collider determine declared inertia")
	changed = base.duplicate(true)
	changed.max_force = 1500.0
	expect(not Profile.validate(changed).is_empty(), "force envelope checked against mass")
	changed = base.duplicate(true)
	changed.max_torque = 1500.0
	expect(not Profile.validate(changed).is_empty(), "torque envelope checked against inertia")
	changed = base.duplicate(true)
	changed.max_force = 150.0
	expect(Profile.validate(changed).is_empty(), "underpowered plant is valid and need not hover")
	for value: Variant in [0, -1, 1.0 / 30.0, NAN, true, "0.016666"]:
		changed = base.duplicate(true)
		changed.fixed_delta = value
		expect(not Profile.validate(changed).is_empty(), "unsupported fixed cadence refused")
	for value: Variant in [2, true, "1", NAN]:
		changed = base.duplicate(true)
		changed.version = value
		expect(not Profile.validate(changed).is_empty(), "unsupported schema version refused")
	for key: String in ["family", "topology", "action_profile", "resource_mode", "calibration", "id"]:
		changed = base.duplicate(true)
		changed[key] = "invented"
		expect(not Profile.validate(changed).is_empty(), "unknown identity refused " + key)
	# Canonicalization handles JSON numeric spelling and insertion order while
	# retaining tiny accepted tuning differences, rather than display rounding.
	var reversed: Dictionary = {}
	var keys: Array = base.keys()
	keys.reverse()
	for key: String in keys:
		reversed[key] = base[key]
	reversed.version = 1.0
	reversed.desired_speed = [48, 36]
	expect(Profile.profile_hash(reversed) == Profile.profile_hash(base), "canonical key/numeric identity")
	changed = base.duplicate(true)
	changed.linear_drag += 0.00000001
	expect(Profile.profile_hash(changed) != Profile.profile_hash(base), "full precision tuning changes identity")
	changed = base.duplicate(true)
	changed.friction = 0.81
	expect(Profile.profile_hash(changed) != Profile.profile_hash(base), "contact material joins profile identity")


func test_actuator() -> void:
	var profile: Dictionary = Profile.entry(&"4ly_trainer")
	var controller = Controller.new()
	expect(controller.configure(profile), "controller configuration")
	profile.max_force = 1.0
	var first: Dictionary = controller.advance(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, DT)
	expect(first.valid and first.powered, "authorized neutral remains powered")
	expect(Vector2(first.gravity_compensation).is_equal_approx(Vector2(0, -187.2)), "gravity uses mass-scaled same-budget force")
	expect(Vector2(first.applied_force).length() <= 40.0001, "startup obeys force slew")
	expect(Vector2(first.applied_force).y < 0.0, "neutral starts gravity compensation")
	for _tick: int in range(120):
		controller.advance(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, DT)
	var hover: Dictionary = controller.observation()
	expect(absf(Vector2(hover.applied_force).y + 187.2) < 0.001, "bounded neutral reaches full gravity compensation")
	expect(not hover.thrust_saturated, "caller profile mutation cannot reduce controller budget")
	controller.reset()
	var accelerated: Dictionary = controller.advance(Vector2.RIGHT, Vector2.ZERO, 0.0, 0.0, DT)
	expect(absf(Vector2(accelerated.bounded_acceleration).x - 90.0) < 0.001, "drive acceleration budget")
	controller.reset()
	var braked: Dictionary = controller.advance(Vector2.ZERO, Vector2(100, 0), 0.0, 0.0, DT)
	expect(absf(Vector2(braked.bounded_acceleration).x + 135.0) < 0.001, "separate braking budget")
	controller.reset()
	var diagonal: Dictionary = controller.advance(Vector2.ONE, Vector2.ZERO, 0.0, 0.0, DT)
	expect(Vector2(diagonal.admitted_move).is_equal_approx(Vector2.ONE.normalized()), "diagonal mapped into unit disk")
	expect(absf(Vector2(diagonal.desired_velocity).x / 48.0 - 1.0 / sqrt(2.0)) < 0.00001,
		"horizontal desired speed mapping")
	expect(absf(Vector2(diagonal.desired_velocity).y / 36.0 - 1.0 / sqrt(2.0)) < 0.00001,
		"vertical desired speed mapping")
	var last_force: Vector2 = diagonal.applied_force
	var last_torque: float = float(diagonal.applied_torque)
	for tick: int in range(120):
		var sign_value: float = 1.0 if tick % 2 == 0 else -1.0
		var row: Dictionary = controller.advance(Vector2(sign_value, -sign_value),
			Vector2(10000, -10000), sign_value * 3.0, sign_value * 100.0, DT)
		expect(row.valid and Vector2(row.applied_force).is_finite(), "finite adversarial assistance")
		expect(Vector2(row.applied_force).length() <= 360.001, "total force bounded")
		expect(Vector2(row.applied_force).distance_to(last_force) <= 40.001, "force slew bounded")
		expect(absf(float(row.applied_torque)) <= 300.001, "angular torque bounded")
		expect(absf(float(row.applied_torque) - last_torque) <= 60.001, "angular torque slew bounded")
		last_force = row.applied_force
		last_torque = float(row.applied_torque)
	var copied: Dictionary = controller.observation()
	copied.applied_force = Vector2(1e8, 1e8)
	copied.requested_acceleration[0] = 1e8
	expect(Vector2(controller.observation().applied_force).length() <= 360.001, "response observation copied")
	expect(controller.observation().requested_acceleration[0] != 1e8, "nested response copied")
	controller.cancel()
	expect(controller.observation().applied_force == Vector2.ZERO and controller.observation().desired_velocity == Vector2.ZERO,
		"cancel clears response and command history")
	var restarted: Dictionary = controller.advance(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, DT)
	expect(restarted == first, "cancelled controller restarts without latent target or force")
	var unpowered: Dictionary = controller.advance(Vector2.UP, Vector2(30, -20), 1.0, 2.0, DT, false)
	expect(unpowered.valid and not unpowered.powered and unpowered.applied_force == Vector2.ZERO
		and unpowered.applied_torque == 0.0, "explicit propulsion disable removes all assistance")
	var weak: Dictionary = Profile.entry(&"4ly_trainer")
	weak.max_force = 150.0
	expect(controller.configure(weak), "underpowered controller configuration")
	for _tick: int in range(120):
		controller.advance(Vector2.ZERO, Vector2(0, 40), 0.0, 0.0, DT)
	var saturated: Dictionary = controller.observation()
	expect(saturated.thrust_saturated and Vector2(saturated.target_force).length() <= 150.001,
		"gravity compensation cannot exceed shared thrust budget")
	expect(Vector2(saturated.applied_force).length() <= 150.001, "saturated actuator state stays bounded")
	controller.reset()
	var huge: Dictionary = controller.advance(Vector2.ZERO, Vector2(1e30, -1e30), 0.0, 0.0, DT)
	expect(huge.valid and Vector2(huge.applied_force).is_finite(), "large finite motion cannot overflow bounded force")


func test_refusals_and_identity() -> void:
	var controller = Controller.new()
	expect(controller.configure(Profile.entry(&"4ly_trainer")), "negative fixture configured")
	for move: Vector2 in [Vector2(NAN, 0), Vector2(0, INF), Vector2(1.1, 0), Vector2(0, -1.1)]:
		var row: Dictionary = controller.advance(move, Vector2.ZERO, 0.0, 0.0, DT)
		expect(not row.valid and row.applied_force == Vector2.ZERO, "malformed action refused with cleared response")
	for dt: float in [0.0, -DT, DT * 2.0, NAN, INF]:
		var row: Dictionary = controller.advance(Vector2.RIGHT, Vector2.ZERO, 0.0, 0.0, dt)
		expect(not row.valid and row.reason == "fixed_step_required" and row.applied_force == Vector2.ZERO,
			"invalid cadence cannot retain assistance")
	for state: Array in [[Vector2(NAN, 0), 0.0, 0.0], [Vector2.ZERO, INF, 0.0], [Vector2.ZERO, 0.0, NAN]]:
		var row: Dictionary = controller.advance(Vector2.ZERO, state[0], float(state[1]), float(state[2]), DT)
		expect(not row.valid and row.reason == "invalid_motion", "nonfinite own motion refused")
	var source: String = FileAccess.get_file_as_string("res://scripts/physical_flight_controller.gd")
	var declaration: String = 'const SOURCE_SHA256: String = "' + Controller.SOURCE_SHA256 + '"'
	var normalized: String = source.replace(declaration, 'const SOURCE_SHA256: String = "<CONTROLLER_HASH>"')
	expect(not source.is_empty() and Controller.controller_hash().length() == 64,
		"embedded controller source identity present")
	expect(normalized.sha256_text() == Controller.controller_hash(), "exportable controller identity matches actual normalized source")
	# This callable surface cannot receive a goal/route/world or copied evaluator
	# dictionary. Those belong to producers, not to local assistance.
	for method: Dictionary in controller.get_method_list():
		if str(method.name) == "advance":
			var names: Array = []
			for argument: Dictionary in method.args:
				names.append(str(argument.name))
			expect(names == ["move", "velocity", "angle", "angular_velocity", "dt", "powered"],
				"goal-blind typed actuator API")
	var invalid: Dictionary = Profile.entry(&"4ly_trainer")
	invalid.mass = NAN
	expect(not controller.configure(invalid), "invalid replacement profile refused")
	expect(not controller.advance(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, DT).valid,
		"failed reconfiguration cannot reuse old controller")


func run() -> void:
	test_schema()
	test_actuator()
	test_refusals_and_identity()
	print("Physical flight profile: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
