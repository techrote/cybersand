extends SceneTree

# Real Workbench/native/Rapier regression. The only injected delay is at the
# existing immutable payload-copy seam. No response or physical
# state is invented: the control waits for the combined snapshot; the repaired
# path admits exactly the one actually completed native sample before release.
const Setup = preload("res://scripts/workbench_setup.gd")
const Bridge = preload("res://scripts/workbench_physics_bridge.gd")
const WAIT_MS: int = 30000
const HOLD_WINDOW_USEC: int = 150000
const CALLBACK_PROBE_CAPACITY: int = 512
# Initial ordinary Workbench installation has the same bounded setup allowance
# as the pacing fixture. This is not a physical-progress or render-hold budget.
const STARTUP_WAIT_MS: int = 90000

class StalledRenderWorker extends "res://scripts/simulation_worker.gd":
	var probe_mutex: Mutex = Mutex.new()
	var armed: bool = false
	var minimum_tick: int = 0
	var minimum_terrain_revision: int = 0
	var held: bool = false
	var released: bool = false
	var timed_out: bool = false
	var target_serial: int = 0
	var held_started_usec: int = 0
	var released_usec: int = 0
	var target_completion: CyberSimulationSnapshot
	var target_full: CyberSimulationSnapshot

	func arm(tick: int, combined: bool, terrain_revision: int = 0) -> void:
		_mutex.lock()
		_combined_physics_publication = combined
		_mutex.unlock()
		probe_mutex.lock()
		armed = true
		minimum_tick = tick
		minimum_terrain_revision = terrain_revision
		held = false
		released = false
		timed_out = false
		target_serial = 0
		held_started_usec = 0
		released_usec = 0
		target_completion = null
		target_full = null
		probe_mutex.unlock()

	func status() -> Dictionary:
		probe_mutex.lock()
		var result: Dictionary = {"held":held,"released":released,"timed_out":timed_out,
			"serial":target_serial,"completion":target_completion,"full":target_full,
			"held_started_usec":held_started_usec,"released_usec":released_usec}
		probe_mutex.unlock()
		return result

	func release_render() -> void:
		probe_mutex.lock()
		if not released: released_usec = Time.get_ticks_usec()
		released = true
		probe_mutex.unlock()

	func _refresh_published_render_payload() -> void:
		probe_mutex.lock()
		var stall: bool = armed and int(_world.tick_index) >= minimum_tick \
			and _snapshot_hard_surface_revision >= minimum_terrain_revision \
			and _pending_render_payload_generation != _published_render_payload_generation
		if stall:
			armed = false
			held = true
			target_serial = _snapshot_serial
			held_started_usec = Time.get_ticks_usec()
			_mutex.lock()
			target_completion = _published_physics_snapshot
			_mutex.unlock()
		probe_mutex.unlock()
		if stall:
			# Bound a failed test's shutdown; no indefinitely held native owner.
			var deadline: int = Time.get_ticks_msec() + 5000
			while true:
				probe_mutex.lock()
				var done: bool = released
				if Time.get_ticks_msec() >= deadline:
					timed_out = true
					done = true
				probe_mutex.unlock()
				if done: break
				OS.delay_usec(250)
		super._refresh_published_render_payload()

	func _publish_snapshot(worker_step_time_ms: float, paused: bool,
			render_snapshot_interval_usec: int, force_render_full_refresh: bool = false,
			rigid_body_states: PackedFloat32Array = PackedFloat32Array(), rigid_body_epoch: int = 0) -> void:
		super._publish_snapshot(worker_step_time_ms,paused,render_snapshot_interval_usec,
			force_render_full_refresh,rigid_body_states,rigid_body_epoch)
		probe_mutex.lock()
		if target_serial > 0 and _published_snapshot != null and _published_snapshot.serial == target_serial:
			target_full = _published_snapshot
		probe_mutex.unlock()

class ObservingHost extends "res://scripts/main.gd":
	var admissions: Array[Dictionary] = []
	var callbacks: int = 0
	var record_callbacks: bool = false
	var callback_probe_dropped: int = 0
	var callback_probe: Array[Dictionary] = []
	var _callback_observation: Dictionary = {}

	func _physics_process(delta: float) -> void:
		callbacks += 1
		if not record_callbacks:
			super._physics_process(delta)
			return
		_callback_observation = {"start_usec":Time.get_ticks_usec(),
			"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
			"step_before":physical_actor_session.tick if physical_actor_session != null else -1,
			"hold_reason":""}
		super._physics_process(delta)
		_callback_observation["completed_usec"] = Time.get_ticks_usec()
		_callback_observation["step_after"] = physical_actor_session.tick if physical_actor_session != null else -1
		if callback_probe.size() < CALLBACK_PROBE_CAPACITY:
			callback_probe.append(_callback_observation)
		else:
			callback_probe_dropped += 1
		_callback_observation = {}

	func _cadence_physics_hold(reason: String, snapshot: CyberSimulationSnapshot = null) -> void:
		super._cadence_physics_hold(reason, snapshot)
		if not _callback_observation.is_empty():
			_callback_observation.hold_reason = reason
			_callback_observation["snapshot_serial"] = snapshot.serial if snapshot != null else -1
			_callback_observation["waiting_sample"] = _workbench_wait_sample

	func begin_callback_probe() -> void:
		callback_probe.clear()
		callback_probe_dropped = 0
		record_callbacks = true

	func _cadence_rapier_completed(started_usec: int, completed_usec: int,
			snapshot: CyberSimulationSnapshot) -> void:
		super._cadence_rapier_completed(started_usec,completed_usec,snapshot)
		admissions.append({"serial":snapshot.serial,"step":physical_actor_session.tick,
			"time_usec":completed_usec,"native_tick":snapshot.tick_index,
			"completed_sample":snapshot.lab_context.get("workbench_completed_sample",-1),
			"pending_chunks":rapier_bridge.pending_hard_surface_chunks(),
			"required_revision":snapshot.lab_context.get("workbench_hard_surface_revision",-1),
			"installed_revision":last_hard_surface_revision,
			"response":physical_actor_session.bridge.last_application.duplicate(true)})

var host: Control
var worker: StalledRenderWorker
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var startup: Dictionary = {}

func _initialize() -> void:
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PHYSICS_PUBLICATION: " + label)
	return ok

func until(predicate: Callable, timeout_ms: int = WAIT_MS) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false

func pause() -> bool:
	host.paused = true
	host.update_worker_frame_state()
	return check(await until(func() -> bool:
		var snap: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snap != null and snap.paused),"ordinary native owner acknowledges pause")

func install() -> bool:
	if not await pause(): return false
	var ui: Control = host.shared_workbench
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	setup.actors = [Setup.instance("needle",1,Vector2(240,160)),Setup.instance(Setup.BARREL,2,Vector2(320,260))]
	setup.next_id = 3
	setup.selected = 1
	setup.edits = [[100,280,300,8,58],[240,210,12,2]]
	var prior_epoch: int = host._physical_epoch
	if not check(ui.apply(setup),"actual two-actor Workbench setup admitted"): return false
	return check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch > prior_epoch \
			and host.physical_actor_session != null and host._physical_terrain_ready \
			and worker.take_latest_physics_snapshot() != null),"new owner, required terrain and physics mailbox installed")

func stalled_completion(combined: bool) -> void:
	if not await install(): return
	var label: String = "combined-control" if combined else "independent-completion"
	var full_before: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	host.begin_callback_probe()
	worker.arm(full_before.tick_index + 1,combined)
	worker.request_render_full_refresh()
	host.paused = false
	host.update_worker_frame_state()
	if not check(await until(func() -> bool: return worker.status().held),label + " stalls real material packing"):
		host.record_callbacks = false
		worker.release_render()
		return
	var hold_observed_usec: int = Time.get_ticks_usec()
	var captured: Dictionary = worker.status()
	var completed: CyberSimulationSnapshot = captured.completion
	if combined:
		check(completed == null or completed.serial < captured.serial,
			label + " keeps the new completion private during material packing")
	elif not check(completed != null and completed.serial == captured.serial,
			label + " retains actual early native completion"):
		host.record_callbacks = false
		worker.release_render()
		return
	else:
		check(completed.render_snapshot_serial == 0 and completed.render_patch_cells.is_empty() \
			and completed.cells.is_empty(),label + " physical receipt grants no material upload authority")
		check(completed.lab_context.is_read_only() and completed.lab_context.workbench_gcr.is_read_only() \
			and completed.lab_context.workbench_gcr.rows.is_read_only(),label + " nested response values are immutable")
	var held_started_usec: int = int(captured.held_started_usec)
	var hold_deadline_usec: int = held_started_usec + HOLD_WINDOW_USEC
	var baseline_usec: int = Time.get_ticks_usec()
	var callbacks_before: int = host.callbacks
	var legacy_timer: bool = OS.get_environment("CYBERSAND_TEST_LEGACY_PROCESS_TIMER") == "1"
	if legacy_timer:
		# Reproduce the historical process-clock gate on demand. SceneTree can
		# charge the precomputed delta of this frame before real time elapses.
		await create_timer(0.15).timeout
	else:
		# The observation budget starts at the worker's actual copy hold. Main's
		# first observation can follow several real callbacks in that hold.
		# Require three callbacks within the same 150 ms wall budget even if
		# the process frame that notices the deadline arrives late.
		while Time.get_ticks_usec() < hold_deadline_usec:
			await process_frame
	var window_observed_usec: int = Time.get_ticks_usec()
	host.record_callbacks = false
	var held_callbacks: Array[Dictionary] = host.callback_probe.filter(func(row: Dictionary) -> bool:
		return int(row.start_usec) >= held_started_usec and int(row.completed_usec) <= hold_deadline_usec)
	var callbacks_during_hold: int = host.callbacks - callbacks_before if legacy_timer else held_callbacks.size()
	check(host.callback_probe_dropped == 0,label + " bounded probe retains every engine callback")
	var still_held: Dictionary = worker.status()
	check(still_held.held and not still_held.released and not still_held.timed_out,
		label + " callback observation ends while native material packing remains held")
	check(callbacks_during_hold >= 3,label + " three real physics callbacks complete within the hold window")
	check(worker.take_latest_snapshot(0).serial < captured.serial,label + " graphical publication remains withheld")
	var matching: Array = host.admissions.filter(func(row: Dictionary) -> bool: return row.serial == captured.serial)
	check(matching.size() == (0 if combined else 1),label + " admits exactly the completed sample according to selected publication mode")
	if not combined and not matching.is_empty():
		var admission: Dictionary = matching[0]
		check(admission.pending_chunks == 0 and admission.required_revision == admission.installed_revision,
			"early physical admission retains complete required native terrain")
		check(admission.response.accepted and admission.response.bodies.all(func(row: Dictionary) -> bool:
			return not row.has("refusal") and row.age >= 0 and row.age <= Bridge.MAX_AGE),
			"early physical admission applies real response with unchanged one-step age limit")
		check(host._workbench_wait_sample != completed.lab_context.workbench_completed_sample,
			"subsequent callback waits for the newly published physical sample")
	observations.append({"mode":label,"serial":captured.serial,"native_tick":completed.tick_index if not combined else -1,
		"physics_handoff_usec":completed.physics_handoff_usec if not combined else 0,"callbacks_during_hold":callbacks_during_hold,
		"hold_clock":"scene_tree_process_timer" if legacy_timer else "monotonic_wall",
		"hold_started_usec":held_started_usec,"hold_observed_usec":hold_observed_usec,
		"hold_deadline_usec":hold_deadline_usec,"hold_window_observed_usec":window_observed_usec,
		"wall_window_observed":window_observed_usec >= hold_deadline_usec,
		"baseline_usec":baseline_usec,"baseline_callbacks":callbacks_before,
		"callbacks_after_baseline":host.callbacks-callbacks_before,
		"callbacks_completed_within_wall_window":held_callbacks.size(),"real_callbacks":host.callback_probe.duplicate(true),
		"physical_admissions_before_release":matching.size(),"native_completed_usec":completed.last_native_tick_completed_usec if not combined else 0})
	host.paused = true
	host.update_worker_frame_state()
	worker.release_render()
	observations.back()["hold_released_usec"] = worker.status().released_usec
	check(await until(func() -> bool: return worker.status().full != null),label + " delayed graphical publication completes")
	var full: CyberSimulationSnapshot = worker.status().full
	if full != null and not combined:
		check(full.serial == completed.serial and full.tick_index == completed.tick_index \
			and full.physics_world_generation == completed.physics_world_generation,
			label + " physical and graphical publications share one source identity")
		check(full.lab_context.workbench_gcr == completed.lab_context.workbench_gcr \
			and full.lab_context.workbench_completed_sample == completed.lab_context.workbench_completed_sample \
			and full.hard_surface_revision == completed.hard_surface_revision \
			and full.hard_surface_chunk_rectangles == completed.hard_surface_chunk_rectangles,
			label + " delayed graphics preserve exact feedback and collider values")
	check(not worker.status().timed_out,label + " render hold released without watchdog escape")
	await pause()

func paused_terrain_and_reset() -> void:
	if not await install(): return
	var old: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var old_tick: int = host.physical_actor_session.tick
	worker.arm(0,false,old.hard_surface_revision+1)
	# This actual queued edit is consumed before either publication. The early
	# completion must contain its new hard terrain even though native is paused.
	var before: Dictionary = worker.paint_state()
	var queued: Dictionary = worker.paint_queue({"kind":"edit","cells":PackedInt32Array([64,64,58]),
		"expected_generation":before.generation,"expected_revision":before.revision,"expected_tick":before.tick,
		"expected_authoring_generation":before.authoring_generation})
	if not check(queued.get("status","") == "queued","paused hard-material PAINT admitted"):
		worker.release_render()
		return
	if not check(await until(func() -> bool: return worker.status().held),"paused edit stalls material packing"):
		worker.release_render()
		return
	var fresh: CyberSimulationSnapshot = worker.status().completion
	if check(fresh != null,"paused edit publishes a complete physical terrain receipt"):
		check(fresh.hard_surface_revision > old.hard_surface_revision,"early geometry includes post-tick PAINT changes")
		check(await until(func() -> bool:
			return host.last_hard_surface_revision == fresh.hard_surface_revision \
				and host.rapier_bridge.pending_hard_surface_chunks() == 0),"paused callbacks install complete early native geometry")
		var shapes: int = host.rapier_bridge.hard_surface_shape_count()
		host.sync_hard_surface_colliders(old)
		check(host.last_hard_surface_revision == fresh.hard_surface_revision \
			and host.rapier_bridge.pending_hard_surface_chunks() == 0 \
			and host.rapier_bridge.hard_surface_shape_count() == shapes,
			"late graphical collider packet cannot roll back early physical terrain")
		check(host.physical_actor_session.tick == old_tick,"early terrain delivery does not advance paused physics")
	worker.release_render()
	check(await until(func() -> bool: return worker.status().full != null),"paused material publication resumes")
	check(await until(func() -> bool: return worker.paint_state().receipt_ready),"PAINT retains ordinary authoring receipt")
	var receipt: Dictionary = worker.paint_take_result()
	check(receipt.get("status","") == "completed" and receipt.get("after",PackedInt32Array()) == PackedInt32Array([58]),
		"PAINT acknowledgement preserves exact authoritative material")
	await pause()
	var generation: int = worker.take_latest_physics_snapshot().physics_world_generation
	var epoch: int = host._physical_epoch
	if await install():
		var new: CyberSimulationSnapshot = worker.take_latest_physics_snapshot()
		check(new.rigid_body_epoch > epoch and new.physics_world_generation > generation \
			and new.lab_context.workbench_completed_sample == -1,"reset retires old World/sample authority")
		var start: int = host.physical_actor_session.tick
		check(host.shared_workbench.step_once(),"ordinary paused single-step admitted")
		check(await until(func() -> bool: return not host.shared_workbench.step_pending \
			and worker.take_latest_snapshot(0).tick_index == 1),"single-step completes one native tick")
		check(host.physical_actor_session.tick == start + 1 and host.paused,
			"single-step completes exactly one actual Rapier step and stays paused")

func owner_retirement_during_render() -> void:
	if not await pause(): return
	worker.arm(0,false)
	worker.request_render_full_refresh()
	if not check(await until(func() -> bool: return worker.status().held),"owner retirement overlaps a real material publication"):
		worker.release_render()
		return
	check(worker.take_latest_physics_snapshot() != null,"an actual physical completion exists before retirement")
	# The public owner-retirement boundary executes while its old native owner
	# is still inside material packing. A late full frame must not revive it.
	worker.set_physical_actor_epoch(host._physical_epoch + 1)
	check(worker.take_latest_physics_snapshot() == null,"owner retirement clears physical authority immediately")
	worker._mutex.lock()
	worker._combined_physics_publication = true
	worker._mutex.unlock()
	check(worker.take_latest_physics_snapshot() == null,"combined control cannot use old graphics after retirement")
	worker._mutex.lock()
	worker._combined_physics_publication = false
	worker._mutex.unlock()
	worker.release_render()
	check(await until(func() -> bool: return worker.status().full != null),"retired owner's already-started graphical copy finishes")
	await create_timer(0.05).timeout
	check(worker.take_latest_physics_snapshot() == null,"late full publication and subsequent owner turns cannot revive old physics")

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	var scene_started_usec: int = Time.get_ticks_usec()
	host = load("res://main.tscn").instantiate()
	host.set_script(ObservingHost)
	worker = StalledRenderWorker.new()
	host.simulation_worker = worker
	root.add_child(host)
	root.size = Vector2i(1280,800)
	var readiness_started_usec: int = Time.get_ticks_usec()
	var ready: bool = await until(func() -> bool: return host.shared_workbench != null \
		and not host.shared_workbench.applied.is_empty(),STARTUP_WAIT_MS)
	var readiness_finished_usec: int = Time.get_ticks_usec()
	var full: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var physical: CyberSimulationSnapshot = worker.take_latest_physics_snapshot()
	var paint: Dictionary = worker.paint_state()
	startup = {"ready_before_watchdog":ready,"readiness_watchdog_msec":STARTUP_WAIT_MS,
		"scene_setup_elapsed_msec":float(readiness_started_usec-scene_started_usec)/1000.0,
		"readiness_wait_elapsed_msec":float(readiness_finished_usec-readiness_started_usec)/1000.0,
		"total_elapsed_msec":float(readiness_finished_usec-scene_started_usec)/1000.0,
		"observed_state_usec":Time.get_ticks_usec(),"process_frames":Engine.get_process_frames(),
		"physics_callbacks":host.callbacks,"worker_start_error":int(host.worker_start_error),
		"worker_failed":worker.has_failed(),"workbench_available":host.shared_workbench!=null,
		"workbench_applied":host.shared_workbench!=null and not host.shared_workbench.applied.is_empty(),
		"workbench_message":str(host.shared_workbench.message) if host.shared_workbench!=null else "",
		"owner_error":host.microscenario_error,"physical_epoch":host._physical_epoch,
		"physical_owner_available":host.physical_actor_session!=null,
		"terrain_ready":host._physical_terrain_ready,"transition_busy":paint.get("transition_busy",false),
		"pending_request_serial":host.pending_microscenario_apply.get("serial",-1),
		"pending_request_fields":host.pending_microscenario_apply.keys(),
		"graphical_snapshot_serial":full.serial if full!=null else -1,
		"graphical_native_tick":full.tick_index if full!=null else -1,
		"physics_snapshot_serial":physical.serial if physical!=null else -1,
		"physics_native_tick":physical.tick_index if physical!=null else -1,
		"meaning":"Setup wall time and observed owner state; no CPU, shader, driver or gameplay-performance attribution."}
	print("PHYSICS_PUBLICATION_STARTUP ",JSON.stringify(startup))
	full = null
	physical = null
	if check(ready,"ordinary Workbench starts"):
		check(host.engine_lab_wait_native_sample and worker.engine_lab_pixel_pacing().sample_wake,
			"ordinary native wait/wake remains enabled")
		await stalled_completion(true)
		await stalled_completion(false)
		await paused_terrain_and_reset()
		await owner_retirement_during_render()
	worker.release_render()
	host.queue_free()
	await process_frame
	await process_frame
	check(not worker._thread.is_started() and worker.take_latest_physics_snapshot() == null,
		"shutdown joins worker and retires physical publication without graphical fallback")
	var report: Dictionary = {"schema":"workbench-physics-publication-v1","checks":checks,
		"failures":failures,"observations":observations,"startup":startup,"godot":Engine.get_version_info().string,
		"platform":OS.get_name(),"display":DisplayServer.get_name(),
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION")}
	var output: String = OS.get_environment("CYBERSAND_PHYSICS_PUBLICATION_OUTPUT")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"  ") + "\n")
	print("PHYSICS_PUBLICATION_RESULT ",JSON.stringify(report))
	quit(int(not failures.is_empty()))
