extends SceneTree

# Real Main/native Workbench owner regression. The observer delegates every
# production operation. Its only workload injection is one bounded delay AFTER
# an actual immutable publication; it never invents a native or Rapier result.
# The 500 ms stop bound distinguishes interruptible retirement from waiting out
# the requested 1 s timer. It is a functional guard, not performance acceptance.
const Setup = preload("res://scripts/workbench_setup.gd")
const WAIT_MS: int = 15000
const STARTUP_MS: int = 90000
const STOP_BOUND_USEC: int = 500000

class ObservedWorker extends "res://scripts/simulation_worker.gd":
	const CAPACITY: int = 1024
	var probe_mutex := Mutex.new()
	var recording: bool = false
	var polls: int = 0
	var publication_polls: int = 0
	var last_idle: Dictionary = {}
	var last_wake: Dictionary = {}
	var records: Array[Dictionary] = []
	var dropped: int = 0
	var delay_kind: String = ""
	var delay_usec: int = 0
	var delay_generation: int = -1
	var delay_after_tick: int = -1
	var delay_after_render_serial: int = -1
	var delay_target: Dictionary = {}
	var delay_completed_usec: int = 0
	var after_delay: Dictionary = {}

	func arm_delay(kind: String, duration: int, generation: int, tick: int, render_serial: int = -1) -> void:
		probe_mutex.lock()
		recording = true
		delay_kind = kind
		delay_usec = duration
		delay_generation = generation
		delay_after_tick = tick
		delay_after_render_serial = render_serial
		delay_target = {}
		delay_completed_usec = 0
		after_delay = {}
		probe_mutex.unlock()

	func observe() -> Dictionary:
		probe_mutex.lock()
		var result := {"polls":polls,"last_idle":last_idle.duplicate(),"last_wake":last_wake.duplicate(),
			"delay_target":delay_target.duplicate(),"delay_completed_usec":delay_completed_usec,
			"after_delay":after_delay.duplicate(),"dropped":dropped}
		probe_mutex.unlock()
		return result

	func observations() -> Array[Dictionary]:
		probe_mutex.lock()
		var result: Array[Dictionary] = records.duplicate(true)
		probe_mutex.unlock()
		return result

	func _workbench_owner_work_pending(pause_request: bool, settings_revision: int,
			paint_epoch: int, art_epoch: int, pixel_interval_usec: int,
			render_interval_usec: int, rebased_wait: bool) -> bool:
		var result: bool = super._workbench_owner_work_pending(pause_request,settings_revision,
			paint_epoch,art_epoch,pixel_interval_usec,render_interval_usec,rebased_wait)
		probe_mutex.lock()
		polls += 1
		var row := {"time_usec":Time.get_ticks_usec(),"serial":_snapshot_serial,
			"interval_usec":pixel_interval_usec,"rebased":rebased_wait,"pause_request":pause_request}
		if result:
			last_wake = row
		else:
			last_idle = row
		probe_mutex.unlock()
		return result

	func _publish_snapshot(worker_step_time_ms: float, paused: bool,
			render_snapshot_interval_usec: int, force_render_full_refresh: bool = false,
			rigid_body_states: PackedFloat32Array = PackedFloat32Array(), rigid_body_epoch: int = 0) -> void:
		super._publish_snapshot(worker_step_time_ms,paused,render_snapshot_interval_usec,
			force_render_full_refresh,rigid_body_states,rigid_body_epoch)
		var snapshot: CyberSimulationSnapshot = take_latest_snapshot(0)
		if snapshot == null: return
		_mutex.lock()
		var requested_pause: bool = _paused
		_mutex.unlock()
		probe_mutex.lock()
		var row := {"serial":snapshot.serial,"tick":snapshot.tick_index,
			"generation":snapshot.physics_world_generation,"time_usec":Time.get_ticks_usec(),
			"native_completed_usec":snapshot.last_native_tick_completed_usec,
			"sample":snapshot.lab_context.get("workbench_completed_sample",-1),
			"offered_sample":snapshot.offered_body_sample,"requested_pause":requested_pause,
			"render_serial":snapshot.render_snapshot_serial,"ack":snapshot.render_acknowledged_serial,
			"pending_bytes":snapshot.render_pending_patch_bytes,"polls_since_previous":polls-publication_polls,
			"failed":snapshot.simulation_failed,"refusal":snapshot.lab_context.get("workbench_refusal","")}
		publication_polls = polls
		if recording:
			if records.size() < CAPACITY: records.append(row)
			else: dropped += 1
		if not delay_target.is_empty() and after_delay.is_empty() and snapshot.serial > int(delay_target.serial):
			after_delay = row.duplicate()
		var matches: bool = snapshot.physics_world_generation == delay_generation and not snapshot.simulation_failed
		if delay_kind == "free":
			matches = matches and not requested_pause and int(row.sample) == -1 and snapshot.tick_index > delay_after_tick
		elif delay_kind == "paused":
			matches = matches and requested_pause
		elif delay_kind == "fenced":
			matches = matches and not requested_pause and int(row.sample) >= 0 \
				and snapshot.render_snapshot_serial > delay_after_render_serial \
				and row.sample == row.offered_sample and bool(snapshot.lab_context.get("workbench_gcr",{}).get("valid",false))
		else:
			matches = false
		var sleep_usec: int = delay_usec if matches else 0
		if matches:
			delay_target = row.duplicate()
			delay_kind = ""
		probe_mutex.unlock()
		if sleep_usec > 0:
			OS.delay_usec(sleep_usec)
			probe_mutex.lock()
			delay_completed_usec = Time.get_ticks_usec()
			probe_mutex.unlock()

var host: Control
var worker: ObservedWorker
var checks: int = 0
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
		push_error("WORKBENCH_OWNER_DEADLINE: "+message)
	return ok

func until(predicate: Callable, timeout_ms: int = WAIT_MS) -> bool:
	var deadline: int = Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false

func freeze_main(value: bool) -> void:
	host.set_process(not value)
	host.set_physics_process(not value)

func pause_owner() -> bool:
	var before: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var serial: int = before.serial if before != null else -1
	host.paused = true
	host.update_worker_frame_state()
	return check(await until(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.serial > serial and snapshot.paused),
		"new native publication acknowledges the actual pause request")

func install(with_body: bool) -> bool:
	freeze_main(false)
	worker.set_engine_lab_pixel_pacing(60,true)
	if not await pause_owner(): return false
	var ui: Control = host.shared_workbench
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	setup.edits = [[0,400,512,8,58]]
	if with_body:
		setup.actors = [Setup.instance("needle",1,Vector2(240,160))]
		setup.next_id = 2
		setup.selected = 1
	var epoch: int = host._physical_epoch
	var generation: int = worker.take_latest_snapshot(0).physics_world_generation
	if not check(ui.apply(setup),"ordinary 512 canvas replacement admitted, body="+str(with_body)): return false
	var installed: bool = await until(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return host.pending_microscenario_apply.is_empty() \
			and host.world_extent == Vector2i(512,512) \
			and snapshot != null and snapshot.physics_world_generation > generation \
			and (not with_body or (host._physical_epoch > epoch and host.physical_actor_session != null \
				and host._physical_terrain_ready and worker.take_latest_physics_snapshot() != null)))
	if not check(installed,"actual native World and requested body configuration installed"): return false
	check(host.shared_workbench.applied.actors.size() == (1 if with_body else 0),"installed actor workload matches the requested control")
	freeze_main(true)
	return true

func await_idle(interval_usec: int, rebased: bool, after_usec: int = 0, serial: int = -1) -> bool:
	return await until(func() -> bool:
		var idle: Dictionary = worker.observe().last_idle
		return not idle.is_empty() and int(idle.interval_usec) == interval_usec and bool(idle.rebased) == rebased \
			and int(idle.time_usec) >= after_usec and (serial < 0 or int(idle.serial) == serial))

func overdue_ordinary_paths() -> void:
	if not await install(false): return
	var before: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	worker.arm_delay("free",80000,before.physics_world_generation,before.tick_index)
	host.paused = false
	host.update_worker_frame_state()
	if check(await until(func() -> bool: return not worker.observe().after_delay.is_empty()),
			"delayed free-running publication is followed by an actual completed native tick"):
		var probe: Dictionary = worker.observe()
		check(probe.after_delay.tick > probe.delay_target.tick and probe.after_delay.native_completed_usec > probe.delay_target.native_completed_usec,
			"no-body control progresses actual native state after the injected publication cost")
		check(probe.after_delay.polls_since_previous == 0,
			"overdue no-body timer does not gain a new polling interval")
		observations.append({"case":"overdue-no-body","probe":probe})
	if not await pause_owner(): return
	before = worker.take_latest_snapshot(0)
	worker.arm_delay("paused",80000,before.physics_world_generation,before.tick_index)
	worker.request_render_full_refresh()
	if check(await until(func() -> bool: return not worker.observe().after_delay.is_empty()),
			"paused owner continues after a delayed real publication"):
		var probe: Dictionary = worker.observe()
		check(probe.after_delay.tick == probe.delay_target.tick and probe.after_delay.polls_since_previous == 0,
			"overdue paused authoring keeps its timer and does not advance native state")
		observations.append({"case":"overdue-paused","probe":probe})

func ordinary_ack_cadence() -> void:
	# Ensure there is a genuine submitted packet that Main has not ACKed yet.
	var before: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	worker.request_render_full_refresh()
	if not check(await until(func() -> bool:
		return worker.take_latest_snapshot(0).render_snapshot_serial > before.render_snapshot_serial),
			"ordinary owner creates a real full packet before the cadence control"): return
	host.paused = false
	host.update_worker_frame_state()
	var changed_usec: int = Time.get_ticks_usec()
	worker.set_engine_lab_pixel_pacing(1,true)
	if not check(await await_idle(1000000,false,changed_usec),"no-body owner enters its original 1 Hz timer wait"): return
	for cycle: int in range(2):
		before = worker.take_latest_snapshot(0)
		var native_tick: int = before.tick_index
		var packet_serial: int = before.render_snapshot_serial
		var started_usec: int = Time.get_ticks_usec()
		host.consume_render_snapshot(before)
		check(host.last_uploaded_render_snapshot_serial == packet_serial and host._engine_lab_last_ack_serial >= packet_serial,
			"real Main uploads the retained packet before acknowledging it")
		worker.request_render_full_refresh()
		worker.set_engine_lab_ack_gated_publication(true)
		await create_timer(0.10).timeout
		var after: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		check(after.tick_index == native_tick and after.render_snapshot_serial == packet_serial,
			"ACK and resync do not authorize an early no-body native tick")
		if not check(await until(func() -> bool:
			var value: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
			return value.tick_index > native_tick and value.render_snapshot_serial > packet_serial),
				"ordinary timer later completes a real native tick and requested full resync"): return
		after = worker.take_latest_snapshot(0)
		check(after.render_full_refresh and after.render_acknowledged_serial >= packet_serial,
			"timer-paced turn retains the admitted ACK and full refresh")
		observations.append({"case":"ordinary-ack-cadence","cycle":cycle,"before_tick":native_tick,
			"after_tick":after.tick_index,"command_to_publication_usec":after.published_usec-started_usec,
			"actual_native_interval_usec":after.last_native_tick_started_usec-before.last_native_tick_started_usec})
		if not check(await await_idle(1000000,false,started_usec,after.serial),"next ordinary 1 Hz timer wait is observed"): return

func begin_rebased_wait() -> CyberSimulationSnapshot:
	var before: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	worker.arm_delay("fenced",1100000,before.physics_world_generation,before.tick_index,before.render_snapshot_serial)
	worker.request_render_full_refresh()
	if not check(await until(func() -> bool:
		return worker.observe().delay_completed_usec > 0),"bounded delay completes after a genuine fenced-body publication"):
		return null
	var probe: Dictionary = worker.observe()
	if not check(await await_idle(1000000,true,int(probe.delay_completed_usec),int(probe.delay_target.serial)),
			"overdue completed-body turn enters the new rebased wait"): return null
	var value: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	check(value.tick_index == probe.delay_target.tick and value.lab_context.workbench_completed_sample >= 0
		and value.lab_context.workbench_completed_sample == value.offered_body_sample,
		"rebased waiting retains one actually completed body sample")
	return value

func fenced_controls() -> void:
	if not await install(true): return
	freeze_main(false)
	host.paused = false
	host.update_worker_frame_state()
	if not check(await until(func() -> bool: return host.physical_actor_session.tick >= 3),
			"real needle completes Rapier steps before the consumer is held"): return
	freeze_main(true)
	if not check(await until(func() -> bool:
		var value: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return value.lab_context.get("workbench_completed_sample",-1) >= 0 \
			and value.lab_context.workbench_completed_sample == value.offered_body_sample),
			"native owner completes the final admitted body sample"): return
	var configured_usec: int = Time.get_ticks_usec()
	worker.set_engine_lab_pixel_pacing(1,true)
	if not check(await await_idle(1000000,false,configured_usec),"body owner observes the1Hz configuration before the delayed full publication"): return
	var retained: CyberSimulationSnapshot = await begin_rebased_wait()
	if retained == null: return
	var retained_bytes: PackedByteArray = retained.render_patch_cells.duplicate()
	var retained_rectangles: PackedInt32Array = retained.render_patch_rectangles.duplicate()
	var started_usec: int = Time.get_ticks_usec()
	host.consume_render_snapshot(retained)
	if check(await until(func() -> bool:
		return worker.take_latest_snapshot(0).render_acknowledged_serial >= retained.render_snapshot_serial),
			"accepted Main upload interrupts the rebased wait with its real ACK"):
		var after: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		var wake: Dictionary = worker.observe().last_wake
		check(after.tick_index == retained.tick_index and after.render_pending_patch_bytes == 0,
			"rebased ACK retires the pending journal without another native tick")
		check(not wake.is_empty() and wake.rebased and wake.time_usec >= started_usec,
			"ACK was observed by the actual rebased owner predicate")
		check(retained.render_patch_cells == retained_bytes and retained.render_patch_rectangles == retained_rectangles,
			"ACK leaves the retained immutable packet intact")
		observations.append({"case":"rebased-ack","native_tick":after.tick_index,
			"elapsed_usec":after.published_usec-started_usec,"wake":wake})
	retained = await begin_rebased_wait()
	if retained == null: return
	started_usec = Time.get_ticks_usec()
	worker.request_render_full_refresh()
	if check(await until(func() -> bool:
		return worker.take_latest_snapshot(0).render_snapshot_serial > retained.render_snapshot_serial),
			"explicit resync interrupts a rebased wait despite an unacknowledged packet"):
		var after: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		var wake: Dictionary = worker.observe().last_wake
		check(after.render_full_refresh and after.tick_index == retained.tick_index,
			"rebased resync publishes exact current material without a fabricated native tick")
		check(not wake.is_empty() and wake.rebased and wake.time_usec >= started_usec,
			"full refresh was observed by the actual rebased owner predicate")
		host.consume_render_snapshot(after)
		check(host.last_uploaded_render_snapshot_serial == after.render_snapshot_serial,
			"actual Main accepts the resynchronized material packet")
		observations.append({"case":"rebased-full-resync","native_tick":after.tick_index,
			"elapsed_usec":after.published_usec-started_usec,"wake":wake})

func paused_paint_reset_and_stop() -> void:
	if not await pause_owner(): return
	var before: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var physical_tick: int = host.physical_actor_session.tick
	var paint: Dictionary = worker.paint_state()
	var queued: Dictionary = worker.paint_queue({"kind":"edit","cells":PackedInt32Array([64,64,58]),
		"expected_generation":paint.generation,"expected_revision":paint.revision,"expected_tick":paint.tick,
		"expected_authoring_generation":paint.authoring_generation})
	if check(queued.get("status","") == "queued","paused paint is admitted through the real owner queue"):
		if check(await until(func() -> bool: return worker.paint_state().receipt_ready),"paused paint produces its authoritative receipt"):
			var receipt: Dictionary = worker.paint_take_result()
			check(receipt.get("status","") == "completed" and receipt.get("after",PackedInt32Array()) == PackedInt32Array([58]),
				"paint preserves exact authoritative material58")
			check(worker.take_latest_snapshot(0).tick_index == before.tick_index and host.physical_actor_session.tick == physical_tick,
				"paused paint advances neither native nor Rapier simulation time")
			observations.append({"case":"paused-paint","receipt":receipt})
	var generation: int = before.physics_world_generation
	var epoch: int = host._physical_epoch
	if not await install(true): return
	var replacement: CyberSimulationSnapshot = worker.take_latest_physics_snapshot()
	check(replacement.physics_world_generation > generation and replacement.rigid_body_epoch > epoch
		and replacement.lab_context.workbench_completed_sample == -1,
		"actual prepared World replacement retires the prior epoch and completed sample")
	var changed_usec: int = Time.get_ticks_usec()
	worker.set_engine_lab_pixel_pacing(1,true)
	if not check(await await_idle(1000000,false,changed_usec),"paused replacement enters a real 1 Hz owner poll"): return
	var started_usec: int = Time.get_ticks_usec()
	worker.stop_worker()
	var elapsed_usec: int = Time.get_ticks_usec()-started_usec
	check(elapsed_usec < STOP_BOUND_USEC and not worker._thread.is_started()
		and worker.take_latest_physics_snapshot() == null and worker.try_read_physics_mailbox().status == "retired",
		"stop interrupts the 1 Hz poll, joins the owner and retires physical authority")
	observations.append({"case":"stop-during-one-hz-poll","elapsed_usec":elapsed_usec,
		"functional_bound_usec":STOP_BOUND_USEC,"scope":"Functional retirement bound, not a throughput result."})

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	worker = ObservedWorker.new()
	host.simulation_worker = worker
	root.add_child(host)
	root.size = Vector2i(1280,800)
	if check(await until(func() -> bool:
		return host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),STARTUP_MS),
			"ordinary Workbench starts with the real native runtime"):
		check(host.engine_lab_wait_native_sample and worker.engine_lab_pixel_pacing().sample_wake,
			"default native completion and sample-wake fences remain enabled")
		await overdue_ordinary_paths()
		if failures.is_empty(): await ordinary_ack_cadence()
		if failures.is_empty(): await fenced_controls()
		if failures.is_empty(): await paused_paint_reset_and_stop()
	check(not worker.has_failed(),"native material-health failure fence remains healthy")
	var rows: Array[Dictionary] = worker.observations()
	check(worker.observe().dropped == 0 and not rows.is_empty(),"bounded observer retains actual owner publications")
	check(rows.all(func(row: Dictionary) -> bool: return not row.failed and str(row.refusal).is_empty()),
		"all observed publications retain native health and valid Workbench authority")
	worker.stop_worker()
	host.queue_free()
	await process_frame
	await process_frame
	var report := {"schema":"workbench-owner-deadline-v1","checks":checks,"failures":failures,
		"observations":observations,"publications":rows,"final_probe":worker.observe(),"godot":Engine.get_version_info(),
		"platform":OS.get_name(),"display":DisplayServer.get_name(),
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"worker_sha256":FileAccess.get_sha256("res://scripts/simulation_worker.gd"),
		"fixture_sha256":FileAccess.get_sha256(get_script().resource_path),
		"scope":"Real native/Workbench scheduling, immutable ACK/resync, pause/paint/reset and retirement. Injected publication delays are functional controls, not gameplay performance evidence."}
	var output: String = OS.get_environment("CYBERSAND_OWNER_DEADLINE_OUTPUT")
	var artifact_dir: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if output.is_empty() and not artifact_dir.is_empty(): output = artifact_dir.path_join("workbench-owner-deadline.json")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t")+"\n")
	print("WORKBENCH_OWNER_DEADLINE: %d checks, %d failures"%[checks,failures.size()])
	quit(int(not failures.is_empty()))
