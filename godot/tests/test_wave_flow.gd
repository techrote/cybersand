extends SceneTree

const Lab = preload("res://scripts/wave_flow_session.gd")
const Evaluation = preload("res://wave_flow_evaluation.tscn")
var assertions: int = 0
var failures: int = 0
var completed := {"native_configuration":false, "mass_readback":false, "region_pause":false,
	"state_identity":false, "save_refusal":false, "solver_comparison":false,
	"fixtures":false, "rapier_contact":false, "needle_contact":false}
var observations: Array = []


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("WAVE_FLOW: " + message)
	return ok


func native_world(options: Dictionary) -> Variant:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not expect(world.diagnostic_reset(options), "native construction accepted: " + str(world.get_last_tick_error())): return null
	world.set_simulation_window_enabled(false)
	return world


func native_configuration() -> void:
	var start: int = failures
	var world: Variant = native_world({"extent":Vector2i(256, 256), "workers":4, "wave_flow":true, "wave_substeps":3})
	if world == null: return
	var applied: Dictionary = world.get_wave_flow_status()
	expect(applied.enabled and applied.substeps == 3 and applied.workers_requested == 4, "readback is the applied Wave config")
	var before: String = world.get_physical_state_hash()
	var generation: int = world.get_liquid_policy_session_generation()
	for invalid: Dictionary in [{"wave_substeps":0}, {"wave_substeps":9}, {"wave_substeps":1.5}, {"wave_flow":"yes"}, {"extent":Vector2i(8192, 8192)}]:
		var request: Dictionary = {"wave_flow":true, "extent":Vector2i(256, 256)}
		request.merge(invalid, true)
		expect(not world.diagnostic_reset(request), "invalid native options refused " + str(invalid))
		expect(world.get_physical_state_hash() == before and world.get_liquid_policy_session_generation() == generation,
			"refused construction keeps the old World")
	expect(world.diagnostic_reset({"extent":Vector2i(128, 128)}), "explicit fresh legacy reset")
	applied = world.get_wave_flow_status()
	expect(not applied.enabled and applied.storage_bytes == 0, "Wave disabled returns actual zero-storage legacy World")
	completed.native_configuration = failures == start


func mass_and_identity() -> void:
	var start: int = failures
	var world: Variant = native_world({"extent":Vector2i(256, 256), "workers":4, "wave_flow":true, "wave_substeps":3})
	if world == null: return
	for r: Array in [[0,0,160,1,1], [0,159,160,1,1], [0,0,1,160,1], [159,0,1,160,1],
		[50,1,60,155,1], [1,40,49,119,3], [50,156,60,3,3], [110,120,49,39,3]]:
		expect(world.diagnostic_fill_rect(Vector2i(r[0],r[1]),Vector2i(r[2],r[3]),r[4]), "sealed passage fixture admitted")
	var quantity: int = (49 * 119 + 60 * 3 + 49 * 39) * 255
	var before: String = world.get_physical_state_hash()
	var maximum: int = 0
	var retained_flux: bool = false
	for tick: int in range(180):
		if not expect(world.simulation_tick(), "sealed passage tick"): return
		expect(int(world.get_wave_flow_status().water_quantity) == quantity, "sealed passage exact native ledger")
		if tick % 10 == 0:
			for x: int in range(48, 112):
				var cell: Dictionary = world.inspect_wave_flow_cell(Vector2i(x, 157))
				maximum = maxi(maximum, int(cell.stored_mass))
				retained_flux = retained_flux or int(cell.face_flux) != 0
				expect(cell.ok and cell.liquid_mass == cell.stored_mass, "GDExtension mass does not truncate or wrap")
	expect(maximum > 255, "mass readback exercised real transient overfill")
	completed.mass_readback = failures == start
	start = failures
	expect(retained_flux and world.get_physical_state_hash_version() == 6, "complete physical identity includes active retained-flux law")
	expect(world.get_physical_state_hash() != before, "physical identity changes after real Wave transport")
	var first: Variant = native_world({"extent":Vector2i(128, 128), "wave_flow":true, "wave_substeps":1})
	var second: Variant = native_world({"extent":Vector2i(128, 128), "wave_flow":true, "wave_substeps":3})
	if first != null and second != null:
		expect(first.get_physical_state_hash() != second.get_physical_state_hash(), "different future substep laws have distinct complete state")
	completed.state_identity = failures == start
	start = failures
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	before = world.get_physical_state_hash()
	expect(bridge.export_physical_state(world).is_empty() and "wave" in str(bridge.get_last_error()).to_lower(), "physical save explicitly refuses retained flux omission")
	expect(world.get_physical_state_format_version() == 0 and world.get_physical_state_hash() == before, "save refusal is nondestructive and format is unsupported")
	expect(bridge.export_level(world).is_empty() and "wave" in str(bridge.get_last_error()).to_lower()
		and world.get_physical_state_hash() == before, "legacy state export refuses before narrowing overfill or altering authority")
	var legacy: Variant = native_world({"extent":Vector2i(128, 128)})
	if legacy != null:
		var saved: PackedByteArray = bridge.export_physical_state(legacy)
		expect(not saved.is_empty(), "legacy physical save remains available")
		expect(not bridge.import_physical_state(world, saved) and world.get_physical_state_hash() == before, "loading a legacy state into a Wave owner refuses instead of dropping flux")
	completed.save_refusal = failures == start
	observations.append({"case":"sealed", "maximum_mass":maximum, "retained_flux":retained_flux, "quantity":quantity})


func region_pause() -> void:
	var start: int = failures
	var world: Variant = native_world({"extent":Vector2i(256, 256), "workers":4, "wave_flow":true})
	if world == null: return
	expect(world.diagnostic_fill_rect(Vector2i(190, 1), Vector2i(1, 240), 1), "left shaft")
	expect(world.diagnostic_fill_rect(Vector2i(192, 1), Vector2i(1, 240), 1), "right shaft")
	expect(world.diagnostic_fill_rect(Vector2i(191, 240), Vector2i(1, 1), 1), "shaft floor")
	expect(world.water_experiment_fill_rect(Vector2i(191, 10), Vector2i.ONE, 1, 0), "single-unit drop")
	world.set_simulation_window(Vector2i.ZERO, Vector2i(64, 64), 0, 0)
	world.set_simulation_window_enabled(true)
	for tick: int in range(48):
		expect(world.simulation_tick(), "paused-region tick")
	expect(world.inspect_wave_flow_cell(Vector2i(191, 10)).stored_mass == 1, "excluded drop remains frozen")
	world.set_simulation_window_enabled(false)
	for tick: int in range(260):
		if not expect(world.simulation_tick(), "reentered-region tick"): return
	expect(world.inspect_wave_flow_cell(Vector2i(191, 239)).stored_mass == 1, "reentry reactivates one-unit transport across chunks")
	expect(int(world.get_wave_flow_status().water_quantity) == 1, "region transition conserves the drop")
	completed.region_pause = failures == start


func fixture_matrix() -> void:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(256, 256)
	root.add_child(viewport)
	var lab := Lab.new()
	viewport.add_child(lab)
	var start: int = failures
	for law: String in Lab.SOLVERS:
		if not expect(lab.configure("dam", law, 2, 3, 128), "compare " + law + ": " + lab.error): continue
		var status: Dictionary = lab.status()
		expect(status.enabled == (law == "wave_flow_v1"), "actual Wave selection matches requested solver")
		var policy: Dictionary = lab.world.get_liquid_solver_policy()
		if law == "wave_flow_v1": expect(policy.get("effective_water_solver", "") == law, "carrier is clearly overridden by Wave")
		else:
			var family: String = ""
			for assignment: Dictionary in policy.assignments:
				if assignment.material == 3: family = str(assignment.applied_family)
			expect(family == law, "actual native comparison family")
		for tick: int in range(24):
			if not expect(lab.step(), "comparison tick " + law): break
			expect(lab.quantity() == lab.initial_quantity, "comparison conserves seeded quantity")
	completed.solver_comparison = failures == start
	start = failures
	for scene: String in Lab.SCENES:
		if scene in ["body", "needle"]: continue
		if not expect(lab.configure(scene, "wave_flow_v1", 4, 3, 256), "fixture " + scene + ": " + lab.error): continue
		for tick: int in range(150):
			if tick == 80 and scene in ["deep_pool", "sparse"]:
				if scene == "sparse": expect(lab.status().last_solved_chunks == 0, "undisturbed sparse pools really slept")
				expect(lab.disturb(-1) > 0, "disturbance actually relocated stored Water " + scene)
			if not expect(lab.step(), "fixture tick " + scene): break
			if tick == 80 and scene == "sparse": expect(lab.status().last_solved_chunks > 0, "edit actually woke dormant sparse Water")
			expect(lab.quantity() == lab.initial_quantity, "fixture conserves closed quantity " + scene)
		expect(lab.world.get_cells().size() == 256 * 256, "complete copied render projection " + scene)
		observations.append(lab.status())
	completed.fixtures = failures == start
	for scene: String in ["body", "needle"]:
		start = failures
		if not expect(lab.configure(scene, "wave_flow_v1", 4, 3, 256), "real physical fixture " + scene + ": " + lab.error): continue
		var initial: Dictionary = lab.actors.workbench_actor_state(1)
		for tick: int in range(120):
			var action: Dictionary = {"move":Vector2(0.1, 0), "trim":0.1}
			if not expect(lab.step(action), "actual Rapier + Wave step " + scene): break
			expect(lab.quantity() == lab.initial_quantity, "moving real mask conserves stored Water " + scene)
		var final_state: Dictionary = lab.actors.workbench_actor_state(1)
		expect(final_state.position.distance_to(initial.position) > 0.1, "real body translated " + scene)
		expect(absf(final_state.rotation - initial.rotation) > 0.00001, "real body rotated " + scene)
		expect(lab.contacts > 0 and lab.received_impulses > 0, "positive actual Water contact and applied response " + scene)
		expect(lab.actors.bridge.manual_step_count() == 120, "actual Rapier integration count " + scene)
		if scene == "needle":
			var record: Dictionary = Lab.Fleet.authoring_record(Lab.Fleet.index_for_id("needle"))
			expect(final_state.model == "needle" and is_equal_approx(final_state.mass, float(record.physics.mass))
				and final_state.definition_hash == Lab.Fleet.definition_hash(Lab.Fleet.index_for_id("needle")), "authored Needle identity, mass and controller")
		completed["needle_contact" if scene == "needle" else "rapier_contact"] = failures == start
		observations.append(lab.status())
	lab.close()
	viewport.free()


func run() -> void:
	if expect(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"RapierPhysicsServer2D"), "source-matched native and Rapier extensions loaded"):
		native_configuration()
		mass_and_identity()
		region_pause()
		fixture_matrix()
	# Exercise the same visible controls as Test It.cmd, even in headless CI.
	if failures == 0:
		var screen: Variant = Evaluation.instantiate()
		root.add_child(screen)
		await process_frame
		expect(screen.lab != null and screen.lab.world != null and screen.lab.status().enabled, "evaluation UI constructs the actual Wave World")
		screen.solver_picker.select(1)
		expect(screen.reset_scene() and not screen.lab.status().enabled, "UI Reset applies actual legacy comparison")
		screen.free()
	await process_frame
	await process_frame
	print("WAVE_FLOW_OBSERVATIONS: ", JSON.stringify(observations))
	print("WAVE_FLOW: %d assertions; %d failures; completed=%s" % [assertions, failures, JSON.stringify(completed)])
	quit(int(failures > 0 or false in completed.values()))
