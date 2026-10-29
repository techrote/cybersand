extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-LIFE-005 / #269: actual Main/worker/reference-Rapier failure quarantine
# and ordinary reset. A construction-time capacity forces a real native fault;
# the test never substitutes a World, calls it while owned, or fabricates failure.
const Contract = preload("res://scripts/microscenario_contract.gd")
const FIXTURE_ID: String = "play-life005/capacity-recovery"
const CAPACITY_SETTING: String = "cybersand/native_active_core_capacity"
const FAILURE_CALLBACKS: int = 8


class FailureHarness:
	extends "res://scripts/main.gd"
	var completed_main_callbacks: int = 0
	var completed_physics_callbacks: int = 0

	func _process(delta: float) -> void:
		super._process(delta)
		completed_main_callbacks += 1

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		completed_physics_callbacks += 1


var desktop: Control
var result: Dictionary = {}


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_LIFE005: " + message)


func fixture() -> Dictionary:
	var definition: Dictionary = Contract.base(FIXTURE_ID)
	# Native construction requires a rectangle. An explicit Empty-on-Empty
	# carve preserves the empty control, without activating selected material.
	definition.rectangles = [20,20,1,1,0]
	definition.body_enabled = true
	definition.player_enabled = false
	definition.tools = ["paint"]
	definition.interest = {"policy":"fixed","region":[0,0,64,64]}
	return definition


func installed() -> bool:
	return (is_instance_valid(desktop) and desktop.latest_snapshot != null
		and desktop.pending_microscenario_apply.is_empty()
		and desktop.microscenario_definition.get("id", "") == FIXTURE_ID
		and desktop.tower_context.get("micro_active", false)
		and desktop.rapier_bridge.is_initialized() and desktop.rigid_bodies.size() == 3)


func clocks_progress(native_tick: int, physical_step: int) -> bool:
	return (installed() and not desktop.simulation_worker.has_failed()
		and desktop.latest_snapshot.tick_index >= native_tick + 3
		and desktop.rapier_bridge.manual_step_count() >= physical_step + 3)


func paused_publication(after_serial: int) -> bool:
	return (desktop.latest_snapshot.serial > after_serial and desktop.latest_snapshot.paused
		and not desktop.latest_snapshot.simulation_failed)


func emissions_published(after_revision: int) -> bool:
	return (desktop.latest_snapshot.paused and not desktop.latest_snapshot.simulation_failed
		and desktop.latest_snapshot.simulation_world_revision > after_revision
		and desktop.latest_snapshot.world_revision == desktop.latest_snapshot.simulation_world_revision
		and desktop.image.get_pixel(20,20).r8 == 2 and desktop.image.get_pixel(48,20).r8 == 2)


func render_acknowledged(after_serial: int, identity: Dictionary) -> bool:
	return (desktop.latest_snapshot.serial > after_serial and desktop.latest_snapshot.paused
		and not desktop.latest_snapshot.simulation_failed
		and desktop.latest_snapshot.tick_index == int(identity.tick)
		and desktop.latest_snapshot.render_world_generation == int(identity.generation)
		and desktop.latest_snapshot.simulation_world_revision == int(identity.revision)
		and desktop.latest_snapshot.world_revision == int(identity.revision)
		and desktop.latest_snapshot.render_snapshot_serial == int(identity.render_serial)
		and desktop.latest_snapshot.render_patch_rectangles.is_empty()
		and desktop.latest_snapshot.render_patch_cells.is_empty())


func fault_observed() -> bool:
	return desktop.latest_snapshot.simulation_failed and desktop.simulation_worker.has_failed()


func callbacks_progress(main_before: int, physics_before: int) -> bool:
	return (desktop.completed_main_callbacks >= main_before + FAILURE_CALLBACKS
		and desktop.completed_physics_callbacks >= physics_before + FAILURE_CALLBACKS)


func recovered(generation: int) -> bool:
	return (installed() and not desktop.simulation_worker.has_failed()
		and not desktop.latest_snapshot.simulation_failed
		and desktop.latest_snapshot.render_world_generation > generation
		and desktop.latest_snapshot.tick_index == 0 and desktop.latest_snapshot.paused)


func poses() -> Array[Transform2D]:
	var values: Array[Transform2D] = []
	for index: int in range(desktop.rigid_bodies.size()):
		values.append(desktop.rapier_bridge.body_transform(index))
	return values


func payload(snapshot: CyberSimulationSnapshot) -> Dictionary:
	return {"tick":snapshot.tick_index,"generation":snapshot.render_world_generation,
		"world_revision":snapshot.world_revision,"simulation_revision":snapshot.simulation_world_revision,
		"cells":snapshot.cells.duplicate(),"render_serial":snapshot.render_snapshot_serial,
		"render_tick":snapshot.render_tick_index,"rectangles":snapshot.render_patch_rectangles.duplicate(),
		"patch_cells":snapshot.render_patch_cells.duplicate(),
		"terrain_revision":snapshot.hard_surface_revision,
		"terrain":snapshot.hard_surface_rectangles.duplicate(),
		"terrain_chunks":snapshot.hard_surface_chunk_rectangles.duplicate(),
		"character_position":snapshot.character_position,"character_velocity":snapshot.character_velocity,
		"context":snapshot.lab_context.duplicate(true)}


func exercise(worker: CyberSimulationWorker) -> bool:
	var definition: Dictionary = fixture()
	expect(desktop.microscenario_apply_definition(definition, "Play"),
		"public Main admits the empty fixed-interest reference-body fixture")
	var ready: bool = await wait_for(Callable(self, "installed"))
	expect(ready, "actual native owner acknowledges the fixture and three reference Rapier bodies")
	if not ready:
		return false
	var original_bodies: Array = desktop.rigid_bodies.duplicate()
	var original_ids: Array[int] = []
	for body: RigidBody2D in original_bodies:
		original_ids.append(body.get_instance_id())
	expect(desktop.physical_actor_session == null and desktop._physical_epoch == 0,
		"fixture uses the actual reference-body route, not a SetP actor incarnation")
	var physical_start: int = desktop.rapier_bridge.manual_step_count()
	var native_start: int = desktop.latest_snapshot.tick_index
	desktop.paused = false
	ready = await wait_for(Callable(self, "clocks_progress").bind(native_start, physical_start))
	expect(ready, "capacity-one native World and actual main-thread Rapier advance healthily first")
	if not ready:
		return false
	result.healthy_tick = desktop.latest_snapshot.tick_index
	result.healthy_physics_step = desktop.rapier_bridge.manual_step_count()

	# Public pause makes the exact last-valid material payload observable. The
	# existing owner admits emissions while paused; only the following native
	# simulation tick fails. No test barrier holds native jobs or rewinds physics.
	var before_pause: int = desktop.latest_snapshot.serial
	desktop.paused = true
	desktop.update_worker_frame_state()
	ready = await wait_for(Callable(self, "paused_publication").bind(before_pause))
	expect(ready, "exclusive owner publishes a healthy paused boundary before fault injection")
	if not ready:
		return false
	var before_emission_revision: int = desktop.latest_snapshot.simulation_world_revision
	expect(worker.queue_emit_cells(PackedInt32Array([20,20,48,20]), 2),
		"one bounded public emission batch is admitted by the exclusive owner")
	ready = await wait_for(Callable(self, "emissions_published").bind(before_emission_revision))
	expect(ready, "owner publishes both admitted Sand points into Main's actual presentation before another tick")
	if not ready:
		return false
	# Main acknowledges applied render transport. Wait for its copied empty
	# pending-patch publication before retaining the exact failure comparison;
	# a valid acknowledgement must not look like a payload mutation failure.
	var emission_identity: Dictionary = {"tick":desktop.latest_snapshot.tick_index,
		"generation":desktop.latest_snapshot.render_world_generation,
		"revision":desktop.latest_snapshot.simulation_world_revision,
		"render_serial":desktop.latest_snapshot.render_snapshot_serial}
	ready = await wait_for(Callable(self, "render_acknowledged").bind(
		desktop.latest_snapshot.serial, emission_identity))
	expect(ready, "healthy paused publication retires acknowledged render transport before comparison")
	if not ready:
		return false
	var retained: CyberSimulationSnapshot = desktop.latest_snapshot
	var retained_payload: Dictionary = payload(retained)
	var retained_image: PackedByteArray = desktop.image.get_data().duplicate()
	var native_tick: int = retained.tick_index
	result.healthy_generation = retained.render_world_generation
	result.healthy_status_serial = retained.serial
	var policy: Dictionary = retained.lab_context.get("liquid_solver_policy", {}).duplicate(true)
	desktop.paused = false
	desktop.update_worker_frame_state()
	ready = await wait_for(Callable(self, "fault_observed"))
	expect(ready, "Main consumes the actual native scheduling-capacity failure")
	if not ready:
		return false
	var failed: CyberSimulationSnapshot = desktop.latest_snapshot
	expect(failed.last_tick_error.contains("active scheduling-core capacity exhausted")
		and failed.tick_failure_count == 1 and failed.failed_tick_index == native_tick + 1,
		"native failure reports its exact capacity reason and one attempted/completed tick boundary")
	expect(payload(failed) == retained_payload and payload(retained) == retained_payload,
		"failure wrapper preserves the last valid cellular/render/terrain/context payload and immutable lease")
	expect(desktop.image.get_data() == retained_image,
		"failure leaves Main's last successfully presented material image unchanged")
	expect(failed.serial > retained.serial and failed.paused and desktop.paused
		and failed.rigid_body_results.is_empty(),
		"fresh failure status pauses Main and cannot publish partially completed body feedback")
	var stopped_step: int = desktop.rapier_bridge.manual_step_count()
	var stopped_poses: Array[Transform2D] = poses()
	var callbacks_before: int = desktop.completed_main_callbacks
	var physics_before: int = desktop.completed_physics_callbacks
	expect(not worker.queue_emit_disc(24,24,0,2)
		and not worker.queue_emit_cells(PackedInt32Array([24,24]),2),
		"public emissions explicitly refuse the quarantined session")
	# Exercise existing public owner updates, including a resume request. A fault
	# stays latched; ordinary pause/view changes cannot resume cellular or Rapier work.
	desktop.paused = false
	desktop.camera_origin = Vector2(32,0)
	desktop.update_worker_frame_state()
	ready = await wait_for(Callable(self, "callbacks_progress").bind(callbacks_before, physics_before))
	expect(ready, "actual Main and physics callbacks remain live while the failed session is stopped")
	expect(desktop.rapier_bridge.manual_step_count() == stopped_step and poses() == stopped_poses,
		"Rapier completes no further step or pose change after the observed failure fence")
	expect(worker._thread.is_started() and worker.has_failed()
		and desktop.latest_snapshot.failed_tick_index == failed.failed_tick_index
		and desktop.latest_snapshot.tick_failure_count == 1
		and desktop.latest_snapshot.tick_index == native_tick,
		"exclusive owner stays available without retrying or advancing the quarantined World")
	result.failed_tick = native_tick
	result.failed_attempt = failed.failed_tick_index
	result.failure_reason = failed.last_tick_error
	result.failed_generation = failed.render_world_generation
	result.failure_status_serial = failed.serial
	result.quarantine_failure_count = failed.tick_failure_count
	result.main_callbacks_during_failure = desktop.completed_main_callbacks - callbacks_before
	result.physics_callbacks_during_failure = desktop.completed_physics_callbacks - physics_before
	result.failure_stopped_physics_step = stopped_step

	var old_generation: int = failed.render_world_generation
	desktop.microscenario_reset()
	expect(not desktop.pending_microscenario_apply.is_empty(),
		"public R/reset queues ordinary reconstruction of the same definition")
	ready = await wait_for(Callable(self, "recovered").bind(old_generation))
	expect(ready, "ordinary reconstruction advances World generation and clears failure at paused tick zero")
	if not ready:
		return false
	expect(desktop.latest_snapshot.tick_failure_count == 0
		and desktop.latest_snapshot.last_tick_error.is_empty()
		and desktop.microscenario_definition == definition
		and desktop.latest_snapshot.lab_context.get("liquid_solver_policy", {}).get("envelope", PackedInt32Array())
			== policy.get("envelope", PackedInt32Array()),
		"reset clears failure diagnostics while preserving the authored recipe and default liquid policy")
	var reset_ids: Array[int] = []
	for body: RigidBody2D in desktop.rigid_bodies:
		reset_ids.append(body.get_instance_id())
	expect(reset_ids == original_ids and desktop._physical_epoch == 0,
		"ordinary reset retains/reset the same three reference nodes without inventing an actor epoch")
	result.reference_body_nodes_retained = reset_ids == original_ids
	result.reference_epoch = desktop._physical_epoch
	var recovered_step: int = desktop.rapier_bridge.manual_step_count()
	desktop.paused = false
	ready = await wait_for(Callable(self, "clocks_progress").bind(0, recovered_step))
	expect(ready, "reconstructed native World and actual reference Rapier resume healthy completed steps")
	expect(payload(retained) == retained_payload and failed.tick_failure_count == 1,
		"later recovery cannot mutate the retained healthy or failed publication")
	result.recovered_generation = desktop.latest_snapshot.render_world_generation
	result.recovered_tick = desktop.latest_snapshot.tick_index
	result.recovered_physics_step = desktop.rapier_bridge.manual_step_count()
	result.recovered_failure_count = desktop.latest_snapshot.tick_failure_count
	return ready


func run() -> void:
	var started: int = Time.get_ticks_msec()
	var had_capacity: bool = ProjectSettings.has_setting(CAPACITY_SETTING)
	var prior_capacity: Variant = ProjectSettings.get_setting(CAPACITY_SETTING, null)
	ProjectSettings.set_setting(CAPACITY_SETTING,1)
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(FailureHarness)
	ProjectSettings.set_setting(CAPACITY_SETTING, prior_capacity if had_capacity else null)
	desktop.paused = true
	expect(ProjectSettings.has_setting(CAPACITY_SETTING) == had_capacity
		and ProjectSettings.get_setting(CAPACITY_SETTING,null) == prior_capacity,
		"test restores the construction-only capacity setting before Main enters the tree")
	root.add_child(desktop)
	await process_frame
	var worker: CyberSimulationWorker = desktop.simulation_worker
	expect(desktop.worker_start_error == OK and worker._thread.is_started()
		and desktop.rapier_start_error == OK, "actual Main worker and Rapier initialize")
	var completed: bool = false
	if desktop.worker_start_error == OK and worker._thread.is_started():
		completed = await exercise(worker)
	var final_bodies: Array = desktop.rigid_bodies.duplicate()
	var bridge = desktop.rapier_bridge
	desktop.queue_free()
	for _frame: int in range(3):
		await process_frame
	var joined: bool = not worker._thread.is_started()
	expect(joined and not is_instance_valid(desktop), "actual scene exit frees Main and joins its exclusive owner")
	var retired: bool = true
	for body: Variant in final_bodies:
		retired = retired and not is_instance_valid(body)
	expect(retired and not bridge.is_initialized(), "scene exit retires all reference bodies and Rapier resources")
	if joined and completed:
		# Only AFTER the exclusive owner joins may main inspect its native World.
		# Read the full stored-material image, including cells outside interest
		# and beneath body masks. A selected-region material_at scan could miss
		# Sand that moved away or was hidden by a reference-body mask.
		var recovered_cells: PackedByteArray = worker._world.get_cells()
		expect(recovered_cells.size() == 1024 * 1024,
			"joined adapter supplies the complete bounded stored-material image")
		var sand_cells: int = recovered_cells.count(2)
		expect(sand_cells == 0 and not worker._world.has_failed(),
			"joined reconstructed World contains no replayed quarantined Sand emission")
		result.post_join_material_cells = recovered_cells.size()
		result.post_join_sand_cells = sand_cells
	expect(completed, "healthy/faulted/recovered actual-host sequence completes")
	result.merge({"assertions":assertions,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,
		"real_host":true,"host":"main.tscn+CyberSimulationWorker+main-thread-reference-Rapier",
		"construction_active_core_capacity":1,"reference_bodies":3,"worker_joined":joined,
		"reference_bodies_retired":retired,"retries":0,"slow_native_injection":false,
		"native_phase_jobs_held":false,"native_thread_join_trace":false,"rendered_fps_measured":false,
		"physical_gamepad_qualified":false,"setp_course_qualified":false},true)
	print("PLAY_LIFE005_RESULT ",JSON.stringify(result))
	quit(0 if failures == 0 else 1)
