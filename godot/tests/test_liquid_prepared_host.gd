extends SceneTree

# Native construction values through the normal MicroScenario owner, with a
# deterministic worker preparation/commit barrier. No timing-based race oracle.
const Host = preload("res://scripts/microscenario_host.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var assertions: int = 0
var failures: int = 0
var worker: CyberSimulationWorker

class PreparationBarrier extends RefCounted:
	var arrived := Semaphore.new()
	var resume := Semaphore.new()
	var count: int = 0
	func enter() -> void:
		count += 1
		if count == 1:
			arrived.post()
			resume.wait()

class ObservationFailureHost extends CyberMicroScenarioHost:
	# Inject the existing observer failure branch after a real native commit.
	# Valid bounded native cell observations presently succeed; this exercises
	# the error classification without corrupting a validated definition.
	func _observe_due() -> void:
		_fault("fixture observation adapter unavailable")

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_PREPARED_HOST: " + message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func options(checked: Dictionary, rule: String = "") -> Dictionary:
	return {"definition_hash":checked.hash, "seed":checked.definition.seed,
		"region":PackedInt32Array(checked.definition.interest.region),
		"cadence_lod_enabled":checked.definition.execution.cadence_lod_enabled,
		"liquid_surface_adhesion_enabled":checked.definition.execution.liquid_surface_adhesion_enabled,
		"normalization":rule}

func prepare(bridge: Variant, world: Variant, checked: Dictionary, policy: PackedInt32Array, rule: String = "") -> int:
	return bridge.prepare_liquid_world(world, PackedInt32Array(checked.definition.rectangles),
		checked.transport.packed, PackedInt32Array(checked.definition.water_semantics),
		PackedInt32Array(checked.definition.partial_water_fills), policy, options(checked, rule))

func intact_receipt(receipt: Dictionary) -> bool:
	if receipt.is_empty(): return false
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(receipt.canonical_bytes)
	return digest.finish().hex_encode() == receipt.receipt_hash

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false, "native adapter unavailable")
		finish()
		return
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not bridge.has_method(&"prepare_liquid_world"):
		expect(false, "fresh native adapter required")
		finish()
		return
	var source: Dictionary = Runner.read_text(PATH)
	var checked: Dictionary = Contract.parse(source.text)
	expect(checked.get("ok", false), "protected Dam Break validates")
	var request: PackedInt32Array = bridge.default_liquid_policy()
	var whole: PackedInt32Array = request.duplicate()
	whole[21] = 2 # Water cellular_yield_v1/reference; other liquids retain defaults.
	var initial_hash: String = world.get_physical_state_hash()
	var generation: int = world.get_liquid_policy_session_generation()
	var token: int = prepare(bridge, world, checked, request)
	expect(token > 0, "controlled candidate prepares: " + str(bridge.get_last_error()))
	expect(world.get_physical_state_hash() == initial_hash and world.get_liquid_policy_session_generation() == generation,
		"preparation changes no live World or generation")
	expect(world.get_applied_liquid_construction_receipt().is_empty(), "pending receipt is not applied")
	expect(bridge.commit_liquid_world(world, token), "prepared default commits")
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	expect(intact_receipt(receipt) and receipt.kind == "applied_run" and receipt.qualifications == 15 \
		and not receipt.eligible_for_full_matched_evidence, "native bytes retain v1 scope/provenance qualifications")
	expect(receipt.region == PackedInt32Array(checked.definition.interest.region) \
		and not receipt.cadence_lod_enabled and receipt.liquid_surface_adhesion_enabled,
		"receipt captures final fixed interest/execution")
	expect(not bridge.commit_liquid_world(world, token), "committed token cannot replay")
	expect(world.material_at(235, 100) == 1 and world.get_tick_index() == 0, "tick-zero capture precedes dam-release event")
	var canonical: PackedByteArray = receipt.canonical_bytes.duplicate()
	receipt.canonical_bytes[0] = 0
	receipt["region"][0] = 999
	expect(world.get_applied_liquid_construction_receipt().canonical_bytes == canonical \
		and world.get_applied_liquid_construction_receipt().region[0] == 16, "copied receipt isolates consumer mutation")

	var partial: Dictionary = checked.definition.duplicate(true)
	partial.partial_water_fills = [50, 100, 1, 1, 127, 0, 51, 100, 1, 1, 128, 0]
	var partial_checked: Dictionary = Contract.validate(partial)
	initial_hash = world.get_physical_state_hash()
	generation = world.get_liquid_policy_session_generation()
	expect(prepare(bridge, world, partial_checked, whole) == 0, "whole-cell partial setup refuses without opt-in")
	expect(bridge.get_last_liquid_policy_refusal().get("code", "") == "normalization_required", "typed normalization refusal")
	expect(world.get_physical_state_hash() == initial_hash and world.get_liquid_policy_session_generation() == generation \
		and world.get_applied_liquid_construction_receipt().canonical_bytes == canonical, "refusal preserves World and applied bytes")
	var attempt: Dictionary = world.get_liquid_construction_attempt()
	expect(intact_receipt(attempt) and attempt.kind == "construction_attempt", "refusal copies a distinct native attempt encoding")
	token = prepare(bridge, world, partial_checked, whole, "water-normalize-v1")
	expect(token > 0 and bridge.commit_liquid_world(world, token), "explicit normalization installs whole-cell Water")
	receipt = world.get_applied_liquid_construction_receipt()
	expect(intact_receipt(receipt) and receipt.normalization.water_before == 255 and receipt.normalization.water_after == 255 \
		and receipt.normalization.positive_delta == 127 and receipt.normalization.negative_delta == 127 \
		and receipt.normalization.net_delta == 0 and receipt.normalization.cells_up == 1 and receipt.normalization.cells_down == 1,
		"normalization retains exact gross/net ledger and native digest")
	expect(world.material_at(50, 100) == 0 and world.material_at(51, 100) == 3, "rounding uses final native lattice values")
	expect(world.get_liquid_construction_attempt().is_empty(), "successful commit retires last refusal")
	canonical = receipt.canonical_bytes.duplicate()
	world.prepare_rigid_body_coupling(PackedFloat32Array([1,51.5,100.5,0,0.5,0.5,0,0,0,1,1]), false)
	initial_hash = world.get_physical_state_hash()
	expect(world.rigid_body_id_at(51,100) == 1, "retained masked Water fixture is active")
	expect(prepare(bridge, world, partial_checked, whole) == 0 \
		and world.get_physical_state_hash() == initial_hash and world.rigid_body_id_at(51,100) == 1 \
		and world.water_experiment_observation(Vector2i(50,100),Vector2i(2,1)).water_integer == 255 \
		and intact_receipt(world.get_liquid_construction_attempt()), "native refusal preserves stored masked Water and its capture")
	token = prepare(bridge, world, checked, request)
	var newer: int = prepare(bridge, world, checked, request)
	expect(newer > token and not bridge.commit_liquid_world(world, token), "new preparation retires older token")
	expect(bridge.commit_liquid_world(world, newer), "retired token cannot consume newer preparation")
	token = prepare(bridge, world, checked, request)
	bridge.discard_liquid_world(world, token)
	expect(not bridge.commit_liquid_world(world, token), "discarded token cannot commit")
	token = prepare(bridge, world, checked, request)
	world.set_cadence_lod_enabled(not world.get_cadence_lod_enabled())
	expect(not bridge.commit_liquid_world(world, token), "owner execution change retires prepared candidate")
	token = prepare(bridge, world, checked, request)
	expect(prepare(bridge, world, partial_checked, whole) == 0 and not bridge.commit_liquid_world(world, token),
		"new refused preparation also retires prior candidate")
	token = prepare(bridge, world, checked, request)
	world.paint_disc(70, 70, 0, 2, 0)
	initial_hash = world.get_physical_state_hash()
	generation = world.get_liquid_policy_session_generation()
	canonical = world.get_applied_liquid_construction_receipt().canonical_bytes
	expect(not bridge.commit_liquid_world(world, token) and world.get_physical_state_hash() == initial_hash \
		and world.get_liquid_policy_session_generation() == generation \
		and world.get_applied_liquid_construction_receipt().canonical_bytes == canonical, "edit between preparation and commit retains edited live World")

	var overlay: Dictionary = checked.definition.duplicate(true)
	overlay.partial_water_fills = [50, 100, 1, 1, 127, 0, 50, 100, 1, 1, 255, 0]
	var overlay_checked: Dictionary = Contract.validate(overlay)
	token = prepare(bridge, world, overlay_checked, whole)
	expect(token > 0 and bridge.commit_liquid_world(world, token), "final full overwrite admits despite earlier fraction")
	overlay.partial_water_fills = [50, 100, 1, 1, 255, 0, 50, 100, 1, 1, 127, 0]
	expect(prepare(bridge, world, Contract.validate(overlay), whole) == 0, "final fractional overwrite refuses despite earlier full Water")
	overlay.partial_water_fills = [50, 100, 1, 1, 255, 0, 50, 100, 1, 1, 0, 0]
	token = prepare(bridge, world, Contract.validate(overlay), whole)
	expect(token > 0 and bridge.commit_liquid_world(world, token) and world.material_at(50,100) == 3, "zero fill preserves prior full tuple")
	partial.water_semantics = [1, 3, 12, 0]
	token = prepare(bridge, world, Contract.validate(partial), whole, "water-normalize-v1")
	expect(token > 0 and bridge.commit_liquid_world(world, token), "three-bit normalization prepares")
	receipt = world.get_applied_liquid_construction_receipt()
	expect(receipt.normalization.water_before == 7 and receipt.normalization.water_after == 7 \
		and receipt.normalization.positive_delta == 3 and receipt.normalization.negative_delta == 3, "3/4 native threshold under seven-unit maximum")
	token = prepare(bridge, world, checked, request)
	expect(world.reset_demo_world(), "ordinary reset succeeds")
	expect(world.get_applied_liquid_construction_receipt().is_empty() and not bridge.commit_liquid_world(world, token), "ordinary constructor retires typed identity and pending token")

	var host: CyberMicroScenarioHost = Host.new()
	expect(host.install(world, checked.definition, "Benchmark", true, request, {"normalization":"water-normalize-v1"}), "normal synchronous host installs controlled native candidate")
	expect(host.summary().events_applied == 0 and world.material_at(235, 100) == 1, "host t0 observation precedes first event")
	expect(host.before_tick() and world.material_at(235, 100) == 0, "normal host applies the first release event")
	var retained_definition: String = host.summary().definition_hash
	initial_hash = world.get_physical_state_hash()
	expect(not host.install(world, partial_checked.definition, "Benchmark", true, whole, {"normalization":""}) \
		and host.summary().definition_hash == retained_definition and host.summary().events_applied == 1 \
		and world.get_physical_state_hash() == initial_hash, "host refusal retains definition, event cursor and actual World")
	var actors: Dictionary = checked.definition.duplicate(true)
	actors.player_enabled = true
	expect(not host.install(world, actors, "Inspect", true, request, {"normalization":"water-normalize-v1"}) \
		and world.get_physical_state_hash() == initial_hash, "unsupported actor setup refuses before replacement")
	var selected: Dictionary = checked.definition.duplicate(true)
	selected.interest.region = [25,31,123,127]
	selected.execution.cadence_lod_enabled = true
	selected.execution.liquid_surface_adhesion_enabled = false
	expect(host.install(world, selected, "Benchmark", true, request, {"normalization":""}), "nondefault fixed execution installs")
	receipt = world.get_applied_liquid_construction_receipt()
	expect(receipt.region == PackedInt32Array([25,31,123,127]) and world.get_cadence_lod_enabled() \
		and not world.get_liquid_surface_adhesion_enabled() \
		and str(receipt.physical_state_hash).lpad(16,"0") == world.get_physical_state_hash(), "post-install actual region/flags/hash match prepared native capture")
	var failed_host := ObservationFailureHost.new()
	generation = world.get_liquid_policy_session_generation()
	expect(failed_host.install(world, checked.definition, "Benchmark", true, request, {"normalization":""}) \
		and failed_host.summary().failed and failed_host.last_error.contains("fixture observation"), "post-commit observation failure is an installed apparatus fault, never refused construction")
	expect(world.get_liquid_policy_session_generation() == generation+1 \
		and intact_receipt(world.get_applied_liquid_construction_receipt()), "installed faulty apparatus retains its actual new World and native receipt")
	var legacy_failed_host := ObservationFailureHost.new()
	expect(not legacy_failed_host.install(world, checked.definition, "Benchmark", true, request),
		"ordinary host retains its pre-existing initial-observer failure return contract")
	await worker_barrier_test(checked.definition, request)
	await installed_observation_failure_test(checked.definition, request)
	await application_routes_test(partial_checked.definition, whole)
	finish()

func installed_observation_failure_test(definition: Dictionary, request: PackedInt32Array) -> void:
	worker = Worker.new()
	worker._scenario_host = ObservationFailureHost.new()
	worker.set_frame_state(0, false, true, Vector2i(512,512), Vector2i(16,16), Vector2i(992,272), 0, 0, true, false, true)
	expect(worker.start_worker(Vector2(512,512)) == OK, "fault-injection owner starts")
	worker.queue_lab({"scenario_reset":definition,"scenario_request_serial":201,"scenario_mode":"Benchmark",
		"sampled_character_enabled":false,"liquid_policy":request,"controlled_liquid_setup":{"normalization":""}})
	expect(await wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.lab_context.get("scenario_request_serial",0) == 201), "faulty installed apparatus is acknowledged")
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	expect(snapshot.lab_context.scenario_request_applied and snapshot.lab_context.microscenario.failed \
		and str(snapshot.lab_context.status).contains("installed; apparatus failed") \
		and intact_receipt(snapshot.lab_context.liquid_construction_receipt), "worker separates installed observer fault from transactional refusal")
	worker.stop_worker()

func application_routes_test(definition: Dictionary, request: PackedInt32Array) -> void:
	# Run the real normal-app controllers and their existing acknowledgement,
	# reset and presentation routes. This is native headless execution of both
	# scene owners; browser/Wasm qualification remains a separate gate.
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	expect(desktop.microscenario_apply_controlled_liquid(definition, request, true, "Benchmark"), "desktop app admits controlled request")
	expect(await wait_for(func() -> bool:
		return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("micro_active",false)), "desktop app acknowledges actual installation")
	var receipt: Dictionary = desktop.tower_context.get("liquid_construction_receipt", {})
	expect(intact_receipt(receipt) and receipt.normalization.water_after == 255 \
		and not desktop.tower_context.sampled_character_enabled, "desktop app reports actual typed whole-cell receipt without an actor")
	var generation: int = receipt.session_generation
	var payload: String = receipt.prepared_payload_hash
	desktop.microscenario_reset()
	expect(await wait_for(func() -> bool:
		return desktop.pending_microscenario_apply.is_empty() \
			and int(desktop.tower_context.get("liquid_construction_receipt",{}).get("session_generation",0)) > generation), "desktop Reset keeps explicit policy and normalization opt-in")
	receipt = desktop.tower_context.liquid_construction_receipt
	expect(receipt.prepared_payload_hash == payload and receipt.normalization.water_after == 255, "desktop Reset reproduces normalized final setup")
	generation = receipt.session_generation
	var retained: PackedByteArray = receipt.canonical_bytes.duplicate()
	expect(desktop.microscenario_apply_controlled_liquid(definition, request, false, "Inspect"), "desktop queues explicit no-opt-in request for native refusal")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()), "desktop receives refusal acknowledgement")
	expect(desktop.tower_context.liquid_construction_receipt.canonical_bytes == retained \
		and desktop.tower_context.liquid_construction_receipt.session_generation == generation \
		and desktop.microscenario_mode == "Benchmark" \
		and desktop.microscenario_error.contains("normalization_required"), "desktop refusal retains prior mode/applied receipt and reports the reason")
	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame
	var web: Control = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	await process_frame
	expect(web.ready_to_play and web.microscenario_apply_controlled_liquid(definition, request, true, "Benchmark"), "synchronous app owner installs controlled candidate")
	receipt = web.tower_context.get("liquid_construction_receipt", {})
	expect(intact_receipt(receipt) and receipt.prepared_payload_hash == payload \
		and receipt.normalization.water_before == 255 and receipt.normalization.water_after == 255, "both actual controllers receive the same normalized setup")
	generation = receipt.session_generation
	web.microscenario_reset()
	receipt = web.tower_context.get("liquid_construction_receipt", {})
	expect(receipt.session_generation == generation+1 and receipt.prepared_payload_hash == payload, "synchronous Reset keeps selected family and explicit normalization")
	retained = receipt.canonical_bytes.duplicate()
	expect(not web.microscenario_apply_controlled_liquid(definition, request, false, "Benchmark") \
		and web.tower_context.liquid_construction_receipt.canonical_bytes == retained, "synchronous refusal preserves applied state")
	web.rapier_bridge.shutdown()
	web.queue_free()
	await process_frame

func worker_barrier_test(definition: Dictionary, request: PackedInt32Array) -> void:
	worker = Worker.new()
	worker.set_frame_state(0, false, true, Vector2i(512,512), Vector2i(16,16), Vector2i(992,272), 0, 0, true, false, true)
	expect(worker.start_worker(Vector2(512,512)) == OK, "threaded normal owner starts")
	var barrier := PreparationBarrier.new()
	worker._controlled_liquid_prepare_barrier = barrier.enter
	var generation: int = worker.take_latest_snapshot(0).lab_context.liquid_solver_policy.session_generation
	var command: Dictionary = {"scenario_reset":definition, "scenario_request_serial":101, "scenario_mode":"Benchmark",
		"sampled_character_enabled":false, "liquid_policy":request, "controlled_liquid_setup":{"normalization":"water-normalize-v1"}}
	worker.queue_lab(command)
	var arrived: bool = await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived, "prepared candidate reached deterministic barrier")
	if not arrived:
		barrier.resume.post()
		worker.stop_worker()
		return
	# Identical definition, newer request identity. A definition-hash-only fence
	# would wrongly accept both candidates and advance generation twice.
	command.scenario_request_serial = 102
	worker.queue_lab(command)
	barrier.resume.post()
	expect(await wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.lab_context.get("scenario_request_serial",0) == 102), "newer same-definition request is acknowledged")
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var receipt: Dictionary = snapshot.lab_context.get("liquid_construction_receipt", {})
	expect(snapshot.lab_context.get("scenario_request_applied",false) and intact_receipt(receipt) \
		and int(receipt.session_generation) == generation+1, "stale prepared candidate never commits; newer request commits exactly once")
	expect(receipt.normalization.net_delta == 0 and receipt.normalization.cells_unchanged > 0, "explicit no-change normalization keeps its receipt")
	var bytes: PackedByteArray = receipt.canonical_bytes.duplicate()
	receipt.canonical_bytes[0] = 0
	var serial: int = snapshot.serial
	expect(await wait_for(func() -> bool:
		var next: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return next != null and next.serial > serial), "later normal publication arrives")
	expect(worker.take_latest_snapshot(0).lab_context.liquid_construction_receipt.canonical_bytes == bytes,
		"consumer mutation cannot alter later worker receipt publication")
	generation = int(receipt.session_generation)
	barrier = PreparationBarrier.new()
	worker._controlled_liquid_prepare_barrier = barrier.enter
	command.scenario_request_serial = 103
	worker.queue_lab(command)
	arrived = await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived, "reset test reaches prepared boundary")
	worker.queue_reset(Vector2(512,512), false)
	barrier.resume.post()
	expect(await wait_for(func() -> bool:
		var next: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return next != null and not next.lab_context.get("micro_active",true)), "ordinary reset supersedes prepared scenario")
	snapshot = worker.take_latest_snapshot(0)
	expect(snapshot.lab_context.liquid_construction_receipt.is_empty() \
		and snapshot.lab_context.liquid_solver_policy.session_generation == generation+1, "reset fence commits only ordinary reset and retires old construction identity")
	generation = int(snapshot.lab_context.liquid_solver_policy.session_generation)
	barrier = PreparationBarrier.new()
	worker._controlled_liquid_prepare_barrier = barrier.enter
	command.scenario_request_serial = 104
	worker.queue_lab(command)
	arrived = await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived, "stop test reaches prepared boundary")
	var stopper := Thread.new()
	expect(stopper.start(worker.stop_worker) == OK, "independent stop caller starts")
	expect(await wait_for(func() -> bool:
		worker._mutex.lock()
		var stopped: bool = not worker._running
		worker._mutex.unlock()
		return stopped), "stop retires in-flight request before waiting for owner")
	barrier.resume.post()
	stopper.wait_to_finish()
	# The thread is joined; direct native read is now again exclusively owned.
	expect(worker._world.get_liquid_policy_session_generation() == generation \
		and worker._world.get_applied_liquid_construction_receipt().is_empty(), "stop fence prevents prepared candidate commit")

func finish() -> void:
	if worker != null: worker.stop_worker()
	print("LIQUID_PREPARED_HOST: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
