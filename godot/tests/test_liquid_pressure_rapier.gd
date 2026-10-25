extends SceneTree

# Functional parity with actual independently stepped Rapier spaces. This is
# not a timing benchmark or a claim about distinct pool participants.
const Profiles = preload("res://scripts/transport_profiles.gd")
const PhysicsBridge = preload("res://scripts/rapier_physics_bridge.gd")
const VARIANTS: Array[String] = ["reference", "cached", "cached_dormant"]
const TICKS: int = 96
var assertions: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []
var one_worker_trace: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_PRESSURE_RAPIER: " + message)
	return value

func request_for(bridge: Variant, variant: String) -> PackedInt32Array:
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(), 3):
		if choice.family == "pressure_flow_v1" and choice.variant == variant and choice.accepted:
			return choice.request
	return PackedInt32Array()

func build(bridge: Variant, workers: int, variant: String) -> Dictionary:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not expect(world.diagnostic_reset({"workers":workers}), "configured worker count admitted"):
		return {}
	world.set_simulation_window_enabled(false)
	var request: PackedInt32Array = request_for(bridge, variant)
	var profile: Dictionary = Profiles.resolve(Profiles.preset(0))
	if not expect(not request.is_empty() and profile.get("ok", false), "runtime choice admits " + variant):
		return {}
	# Closed basin, initially partially immersed rotating body; no source/sink.
	var rectangles := PackedInt32Array([8, 8, 1, 83, 1, 87, 8, 1, 83, 1,
		8, 90, 80, 1, 1, 9, 55, 78, 35, 3])
	if not expect(bridge.build_liquid_policy_world(world, rectangles, profile.packed,
		PackedInt32Array([1, 8, 12, 0]), PackedInt32Array(), request), "actual typed pressure construction"):
		return {}
	var applied: Dictionary = world.get_liquid_solver_policy()
	var water: Dictionary = {}
	for assignment: Dictionary in applied.assignments:
		if int(assignment.material) == 3: water = assignment
	if not expect(water.get("applied_family", "") == "pressure_flow_v1"
		and water.get("applied_variant", "") == variant, "actual variant readback"):
		return {}
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(128, 128)
	root.add_child(viewport)
	var body := RigidBody2D.new()
	body.mass = 1.0
	body.gravity_scale = 0.094
	body.linear_damp = 0.15
	body.angular_damp = 0.35
	body.position = Vector2(48, 52)
	body.rotation = 0.23
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 14)
	shape.shape = rectangle
	body.add_child(shape)
	viewport.add_child(body)
	# initialize takes exclusive manual ownership before the first physics frame.
	var physics = PhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	if not expect(physics.initialize(viewport.world_2d.space, bodies,
		PackedVector2Array([Vector2(8, 14)])) == OK, "actual independent Rapier space initializes"):
		viewport.free()
		return {}
	physics.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
	physics.reset_body(0, Vector2(48, 52), 0.23)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(3, 12))
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.35)
	physics.refresh_all_states()
	return {"world":world, "physics":physics, "viewport":viewport,
		"initial":physics.pack_body_states(), "contacts":0, "impulse":0.0,
		"translated":false, "rotated":false, "variant":variant}

func snapshot(world: Variant) -> Dictionary:
	var ledger: Dictionary = world.get_pressure_flow_ledger()
	ledger.erase("last_tick") # Derived preparation work legitimately differs.
	return {"projection":world.get_liquid_comparison_hash(1),
		"quiescent":world.get_liquid_comparison_hash(2), "gas":world.inspect_gas_compartments(),
		"ledger":ledger, "water":world.water_experiment_observation(Vector2i.ZERO, Vector2i(128, 128)).water_integer}

func cohort(bridge: Variant, workers: int) -> bool:
	var arms: Array[Dictionary] = []
	for variant: String in VARIANTS:
		var arm: Dictionary = build(bridge, workers, variant)
		if arm.is_empty():
			for old: Dictionary in arms:
				old.physics.shutdown()
				old.viewport.free()
			return false
		arms.append(arm)
	var initial_water: int = int(snapshot(arms[0].world).water)
	var ok: bool = true
	for tick: int in range(TICKS):
		var reference_states := PackedFloat32Array()
		var reference_results := PackedFloat32Array()
		var reference: Dictionary = {}
		for index: int in range(arms.size()):
			var arm: Dictionary = arms[index]
			arm.physics.step()
			var states: PackedFloat32Array = arm.physics.pack_body_states()
			arm.world.prepare_rigid_body_coupling(states)
			if not expect(arm.world.simulation_tick(), "native tick succeeds at " + str(tick)):
				ok = false
				break
			var results: PackedFloat32Array = arm.world.rigid_body_results()
			ok = expect(results.size() == 9, "one complete actual-body result") and ok
			if results.size() == 9:
				arm.contacts += int(results[5])
				arm.impulse += absf(results[1]) + absf(results[2])
			ok = expect(arm.physics.apply_cellular_results(tick + 1, results) == 1
				and arm.physics.last_results_applied() == 1
				and arm.physics.last_stale_results_rejected() == 0
				and arm.physics.manual_step_count() == tick + 1,
				"exactly one fresh cellular response is applied after exactly one manual Rapier step") and ok
			var current: Dictionary = snapshot(arm.world)
			ok = expect(int(current.water) == initial_water, "closed basin quantity stays exact") and ok
			arm.translated = arm.translated or states[1] != arm.initial[1] or states[2] != arm.initial[2]
			arm.rotated = arm.rotated or states[3] != arm.initial[3]
			if index == 0:
				reference_states = states
				reference_results = results
				reference = current
				var trace: Dictionary = {"states":states, "results":results, "authority":current}
				if workers == 1:
					one_worker_trace.append(trace)
				else:
					ok = expect(one_worker_trace.size() == TICKS and trace == one_worker_trace[tick],
						"one/four worker native authority and actual Rapier trajectory match") and ok
			else:
				ok = expect(states == reference_states, "actual Rapier sampled poses/velocities match reference") and ok
				ok = expect(results == reference_results, "signed impulses, corrections and contacts match reference") and ok
				ok = expect(current == reference, "native authority, ledger and gas match reference") and ok
		if not ok: break
	for arm: Dictionary in arms:
		ok = expect(arm.translated and arm.rotated and arm.contacts > 0 and arm.impulse > 0.0,
			"positive real translation, rotation, Water contact and cellular impulse") and ok
		observations.append({"workers":workers, "variant":arm.variant, "contacts":arm.contacts,
			"absolute_impulse":arm.impulse, "translated":arm.translated, "rotated":arm.rotated})
		arm.physics.shutdown()
		arm.viewport.free()
	return ok

func run() -> void:
	if not expect(ClassDB.class_exists(&"CyberDemoBridge"), "fresh native adapter available"):
		finish()
		return
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	for workers: int in [1, 4]:
		if not cohort(bridge, workers): break
	finish()

func finish() -> void:
	print("LIQUID_PRESSURE_RAPIER_OBSERVATIONS: " + JSON.stringify(observations))
	print("LIQUID_PRESSURE_RAPIER: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
