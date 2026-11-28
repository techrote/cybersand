extends SceneTree

# Production owner/Rapier fixture. Holding Main is an adversarial dependency
# condition, not a performance measurement: only the native owner continues.
const Setup = preload("res://scripts/workbench_setup.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const WAIT_MS := 20000
var host: Control
var worker: CyberSimulationWorker
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []

func _initialize() -> void:
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	_run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("WORKBENCH_SAMPLE_IDLE: " + message)
	return ok

func until(predicate: Callable, timeout_ms: int = WAIT_MS) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false

func freeze_main(value: bool) -> void:
	host.set_process(not value)
	host.set_physics_process(not value)

func snapshot() -> CyberSimulationSnapshot:
	return worker.take_latest_snapshot(0)

func pause_owner() -> bool:
	host.paused = true
	host.update_worker_frame_state()
	var requested: int = worker.workbench_pause_request_serial()
	return check(await until(func() -> bool:
		return snapshot() != null and snapshot().lab_context.get("workbench_pause_ack_serial",-1) >= requested),
		"real worker acknowledges the requested pause serial")

func install(with_body: bool) -> bool:
	freeze_main(false)
	worker.set_engine_lab_pixel_pacing(60,true)
	worker.set_render_snapshot_hz(60)
	if not await pause_owner(): return false
	var setup: Dictionary = Setup.fresh(PackedInt32Array(host.shared_workbench.applied.liquid_policy),Vector2i(512,512))
	setup.edits = [[0,400,512,8,58],[20,310,150,85,3]]
	if with_body:
		setup.actors = [Setup.instance("needle",1,Vector2(240,160))]
		setup.next_id = 2
		setup.selected = 1
	var generation := snapshot().physics_world_generation
	if not check(host.shared_workbench.apply(setup),"ordinary World replacement admitted, body="+str(with_body)): return false
	return check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and snapshot() != null \
			and snapshot().physics_world_generation > generation \
			and (not with_body or (host.physical_actor_session != null and host._physical_terrain_ready))),
		"replacement native World and requested physical owner install")

func held_completed_sample() -> bool:
	freeze_main(false)
	host.paused = false
	host.update_worker_frame_state()
	var first_step: int = host.physical_actor_session.tick
	if not check(await until(func() -> bool: return host.physical_actor_session.tick >= first_step + 3),
			"actual Rapier completes three fresh steps"): return false
	freeze_main(true)
	return check(await until(func() -> bool:
		var value := snapshot()
		return value.lab_context.get("workbench_completed_sample",-1) >= 0 \
			and value.lab_context.workbench_completed_sample == value.offered_body_sample \
			and value.lab_context.workbench_completed_sample == host._workbench_wait_sample \
			and worker.workbench_sample_idle_status().active),
		"native completes the final actual sample and enters bounded idle wait")

func body_wait_and_wakes() -> void:
	if not await install(true) or not await held_completed_sample(): return
	var before := snapshot()
	var physical_tick: int = host.physical_actor_session.tick
	var native_tick: int = before.tick_index
	var bytes: PackedByteArray = before.render_patch_cells.duplicate()
	var waits: int = worker.workbench_sample_idle_status().waits
	await create_timer(0.60).timeout
	var after := snapshot()
	check(after.tick_index == native_tick and host.physical_actor_session.tick == physical_tick,
		"held completed sample grants neither native nor Rapier progress")
	check(after.serial - before.serial <= 4,
		"bounded heartbeat avoids recurring16.7ms status-only publications")
	check(worker.workbench_sample_idle_status().waits > waits,
		"treatment executes genuine bounded waits")
	check(before.render_patch_cells == bytes,"retained immutable material bytes survive waiting")
	observations.append({"case":"held-completion","native_tick":native_tick,"physical_tick":physical_tick,
		"status_publications":after.serial-before.serial,"idle":worker.workbench_sample_idle_status()})

	# A real Main upload/ACK must retire its journal without a new native tick.
	if not check(await until(func() -> bool: return worker.workbench_sample_idle_status().active),"ACK challenge starts inside wait"): return
	before = snapshot()
	host.consume_render_snapshot(before)
	check(host.last_uploaded_render_snapshot_serial == before.render_snapshot_serial,"ordinary Main accepts retained upload")
	check(await until(func() -> bool: return snapshot().render_acknowledged_serial >= before.render_snapshot_serial),
		"actual upload ACK interrupts waiting")
	check(snapshot().tick_index == native_tick and before.render_patch_cells == bytes,
		"ACK neither invents native progress nor mutates retained payload")

	if not check(await until(func() -> bool: return worker.workbench_sample_idle_status().active),"resync challenge starts inside wait"): return
	before = snapshot()
	worker.request_render_full_refresh()
	check(await until(func() -> bool: return snapshot().render_snapshot_serial > before.render_snapshot_serial),
		"explicit full refresh interrupts waiting")
	check(snapshot().render_full_refresh and snapshot().tick_index == native_tick,
		"full refresh preserves native identity")
	check(worker.workbench_sample_idle_status().last_wake == "owner_work","resync wakes through pending owner work")

	# An admitted material edit wakes immediately, then its real render deadline
	# remains serviced even if Main supplies no further sample.
	worker.set_render_snapshot_hz(20)
	if not check(await until(func() -> bool: return worker.workbench_sample_idle_status().active),"edit challenge starts inside wait"): return
	before = snapshot()
	check(worker.queue_emit_cells(PackedInt32Array([80,80]),58),"ordinary material edit admits while sample is fenced")
	check(await until(func() -> bool: return snapshot().render_snapshot_serial > before.render_snapshot_serial \
		and snapshot().simulation_world_revision > before.simulation_world_revision),
		"edit obtains a real render publication at its due deadline")
	check(snapshot().tick_index == native_tick,"edit does not manufacture a material turn")
	before = snapshot()
	worker.set_render_snapshot_hz(60)
	if not check(await until(func() -> bool: return snapshot().serial > before.serial \
		and worker.workbench_sample_idle_status().active),"render-cadence change is consumed before view challenge"): return

	# View origins do not increment construction-setting revisions.
	if not check(await until(func() -> bool: return worker.workbench_sample_idle_status().active),"view challenge starts inside wait"): return
	waits = worker.workbench_sample_idle_status().waits
	worker.set_frame_state(0.0,false,false,host.world_extent/2,Vector2i(1,0),
		host.world_extent,0,0,true,false,host.liquid_surface_adhesion_enabled)
	check(await until(func() -> bool: return worker.workbench_sample_idle_status().waits > waits \
		and worker.workbench_sample_idle_status().last_wake == "identity_view_or_trace"),
		"camera origin change interrupts without a settings revision")

	if not check(await until(func() -> bool: return worker.workbench_sample_idle_status().active),"trace challenge starts inside wait"): return
	waits = worker.workbench_sample_idle_status().waits
	check(worker.begin_render_cadence_trace(),"ordinary tracing begins")
	check(await until(func() -> bool: return worker.workbench_sample_idle_status().waits > waits \
		and worker.workbench_sample_idle_status().last_wake == "identity_view_or_trace"),
		"observer transition interrupts waiting")
	worker.finish_render_cadence_trace()

	if not check(await until(func() -> bool: return worker.workbench_sample_idle_status().active),"pause challenge starts inside wait"): return
	if not await pause_owner(): return
	check(worker.workbench_sample_idle_status().last_wake == "owner_work","pause interrupts through ordinary request")
	check(not worker.workbench_sample_idle_status().active,"paused authoring bypasses treatment")
	before = snapshot()
	var paint := worker.paint_state()
	var request: Dictionary = worker.paint_queue({"kind":"edit","cells":PackedInt32Array([64,64,58]),
		"expected_generation":paint.generation,"expected_revision":paint.revision,"expected_tick":paint.tick,
		"expected_authoring_generation":paint.authoring_generation})
	if check(request.get("status","") == "queued","paused paint uses ordinary owner queue"):
		if check(await until(func() -> bool: return worker.paint_state().receipt_ready),"paused paint receipt completes"):
			check(worker.paint_take_result().get("after",PackedInt32Array()) == PackedInt32Array([58]),"paused paint writes exact material")
	check(snapshot().tick_index == before.tick_index,"paused editing retains native tick")
	if not await held_completed_sample(): return
	check(host.physical_actor_session.tick > physical_tick,"resume supplies fresh actual samples and progresses")

func no_body_and_retirement() -> void:
	if not await install(false): return
	freeze_main(true)
	var waits: int = worker.workbench_sample_idle_status().waits
	var before := snapshot()
	host.paused = false
	host.update_worker_frame_state()
	check(await until(func() -> bool: return snapshot().tick_index >= before.tick_index + 5),
		"no-body World retains actual timer-paced material evolution")
	check(worker.workbench_sample_idle_status().waits == waits,"no-body World never enters sample idle treatment")
	if not await install(true) or not await held_completed_sample(): return
	var generation: int = snapshot().physics_world_generation
	if not await install(true): return
	check(snapshot().physics_world_generation > generation and snapshot().lab_context.workbench_completed_sample == -1,
		"World replacement retires prior completed-sample authority")
	if not await held_completed_sample(): return
	var started: int = Time.get_ticks_usec()
	worker.stop_worker()
	check(not worker._thread.is_started() and worker.take_latest_physics_snapshot() == null,
		"stop joins actual owner and clears physical mailbox")
	observations.append({"case":"stop","elapsed_usec":Time.get_ticks_usec()-started,
		"idle":worker.workbench_sample_idle_status()})

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	worker = Worker.new()
	host.simulation_worker = worker
	root.add_child(host)
	root.size = Vector2i(1280,800)
	if check(await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),90000),
			"ordinary Workbench starts with source-matched native runtime"):
		check(worker.workbench_sample_idle_status().enabled,"explicit treatment selector is active")
		if failures.is_empty(): await body_wait_and_wakes()
		if failures.is_empty(): await no_body_and_retirement()
	check(not worker.has_failed(),"native health remains valid")
	worker.stop_worker()
	host.queue_free()
	await process_frame
	await process_frame
	var report := {"schema":"workbench-sample-idle-v1","checks":checks,"failures":failures,
		"observations":observations,"godot":Engine.get_version_info(),"platform":OS.get_name(),
		"display":DisplayServer.get_name(),"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"worker_sha256":FileAccess.get_sha256("res://scripts/simulation_worker.gd"),
		"fixture_sha256":FileAccess.get_sha256(get_script().resource_path),
		"scope":"Actual production worker/native/Rapier lifecycle under deliberately held Main. No physical display or comparative performance acceptance."}
	var output := OS.get_environment("CYBERSAND_SAMPLE_IDLE_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")+"\n")
	print("WORKBENCH_SAMPLE_IDLE: %d checks, %d failures"%[checks,failures.size()])
	quit(int(not failures.is_empty()))
