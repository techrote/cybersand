extends SceneTree

# Real Main/native/Rapier. The test delays delivery of one already genuine,
# immutable native packet until the process callback. It never creates native
# completion, moves a body, calls _physics_process manually or injects time.
const Setup = preload("res://scripts/workbench_setup.gd")
const WAIT_MS: int = 90000

class DelayedDeliveryWorker extends "res://scripts/simulation_worker.gd":
	var observing_physics: bool = false
	var delay_enabled: bool = false
	var expected_sample: int = -1
	var previous: CyberSimulationSnapshot
	var withheld: CyberSimulationSnapshot
	var held_frame: int = -1
	var try_reads: int = 0
	var read_observations: Array[Dictionary] = []

	func take_latest_physics_snapshot() -> CyberSimulationSnapshot:
		var actual: CyberSimulationSnapshot = super.take_latest_physics_snapshot()
		if not observing_physics or not delay_enabled: return actual
		if read_observations.size() < 16:
			read_observations.append({"frame":Engine.get_process_frames(),"expected":expected_sample,
				"actual":actual.lab_context.get("workbench_completed_sample",-1) if actual != null else -2,
				"previous":previous.lab_context.get("workbench_completed_sample",-1) if previous != null else -2,
				"world":actual.physics_world_generation if actual != null else -2,
				"previous_world":previous.physics_world_generation if previous != null else -2,
				"terrain":actual.hard_surface_revision if actual != null else -2,
				"previous_terrain":previous.hard_surface_revision if previous != null else -2})
		if withheld != null and held_frame == Engine.get_process_frames(): return previous
		if actual != null and previous != null and expected_sample >= 0 \
			and actual.physics_world_generation == previous.physics_world_generation \
			and actual.rigid_body_epoch == previous.rigid_body_epoch \
			and actual.hard_surface_revision == previous.hard_surface_revision \
			and actual.lab_context.get("workbench_completed_sample",-1) == expected_sample \
			and previous.lab_context.get("workbench_completed_sample",-1) != expected_sample:
			withheld = actual
			held_frame = Engine.get_process_frames()
			return previous
		previous = actual
		return actual

	func try_read_physics_mailbox() -> Dictionary:
		try_reads += 1
		return super.try_read_physics_mailbox()

class Host extends "res://scripts/main.gd":
	var phase: String = ""
	var finished: bool = false
	var checks: Callable
	var rows: Array[Dictionary] = []
	var callbacks: int = 0
	var real_callback_ids: Dictionary = {}
	var last_attempt: Dictionary = {}
	var arm_observations: Array[Dictionary] = []

	func _physics_process(delta: float) -> void:
		callbacks += 1
		var owner = simulation_worker as DelayedDeliveryWorker
		owner.observing_physics = true
		owner.expected_sample = _workbench_wait_sample
		super._physics_process(delta)
		owner.observing_physics = false
		if _workbench_same_frame.callback_serial > 0:
			real_callback_ids[_workbench_same_frame.callback_serial] = {
				"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
				"tick":physical_actor_session.tick if physical_actor_session != null else -1}

	func _arm_same_frame_continuation(delta: float, snapshot: CyberSimulationSnapshot) -> void:
		super._arm_same_frame_continuation(delta,snapshot)
		if arm_observations.size() < 16:
			arm_observations.append({"identity":_same_frame_identity(),"pending":_workbench_same_frame.pending.duplicate(true),
				"frame":Engine.get_process_frames(),"paused":paused,"suspended":physical_actor_session._suspended,
				"step_pending":shared_workbench.step_pending,"step_requested":shared_workbench.step_requested,
				"sample":_workbench_wait_sample,"bridge_sample":physical_actor_session.bridge._serial,
				"terrain":last_hard_surface_revision,"error":_workbench_frame_error})

	func _same_frame_continuation_observed(kind: String, evidence: Dictionary) -> void:
		if kind == "end": last_attempt = evidence.duplicate(true)

	func _process(delta: float) -> void:
		var owner = simulation_worker as DelayedDeliveryWorker
		if phase.is_empty() or finished or owner.withheld == null \
			or owner.held_frame != Engine.get_process_frames() or _workbench_same_frame.pending.is_empty():
			super._process(delta)
			return
		var ticket: Dictionary = _workbench_same_frame.pending.duplicate(true)
		var before: int = physical_actor_session.tick
		var manual_before: int = rapier_bridge.manual_step_count()
		var commands_before: int = physical_actor_session.accepted_commands
		var reads_before: int = owner.try_reads
		var callbacks_before: int = callbacks
		checks.call(owner.withheld.lab_context.is_read_only() \
			and owner.withheld.lab_context.workbench_gcr.is_read_only(), phase + " retains an actual immutable native completion")
		checks.call(real_callback_ids.has(ticket.callback_serial) \
			and real_callback_ids[ticket.callback_serial].tick == before, phase + " permit names a genuine callback with no completed step")
		match phase:
			"cancel":
				physical_actor_session.cancel_input(0,physical_actor_session.epoch,&"human")
			"pause":
				checks.call(shared_workbench.toggle_pause(),"ordinary Workbench pause is admitted")
			"expired":
				# Unit test of the host's fail-closed boundary, not an invented
				# engine callback or alternate source packet.
				_workbench_same_frame.pending.process_frame -= 1
		super._process(delta)
		var advanced: int = physical_actor_session.tick-before
		checks.call(advanced == (1 if phase == "positive" else 0),phase + " advances only authorized actual physical work")
		checks.call(rapier_bridge.manual_step_count()-manual_before == advanced,phase + " Rapier and actor counters agree exactly")
		checks.call(callbacks == callbacks_before,phase + " continuation creates no physics callback")
		checks.call(physical_actor_session.accepted_commands == commands_before,phase + " continuation publishes no new input")
		checks.call(not last_attempt.is_empty() and last_attempt.callback_serial == ticket.callback_serial,
			phase + " retained attempt binds the original callback")
		if phase == "positive":
			checks.call(owner.try_reads-reads_before == 1 and last_attempt.status == "ready",
				"positive continuation reads the mailbox once without a wait")
			checks.call(physical_actor_session.bridge.last_application.accepted \
				and physical_actor_session.bridge.last_application.bodies.all(func(row: Dictionary) -> bool:
					return not row.has("refusal") and row.sample == ticket.identity.sample),
				"real native response passes unchanged body history and wrench validation")
			checks.call(_workbench_wait_sample != ticket.identity.sample \
				and last_hard_surface_revision == ticket.required_revision \
				and rapier_bridge.pending_hard_surface_chunks() == 0,
				"completed step publishes a new body sample on complete unchanged native terrain")
		else:
			checks.call(owner.try_reads == reads_before,phase + " invalid permit refuses before reading native mailbox")
		var final_tick: int = physical_actor_session.tick
		var final_reads: int = owner.try_reads
		_try_same_frame_continuation()
		checks.call(physical_actor_session.tick == final_tick and owner.try_reads == final_reads,
			phase + " repeated process attempt cannot spend a permit twice")
		rows.append({"phase":phase,"before_tick":before,"after_tick":physical_actor_session.tick,
			"manual_before":manual_before,"manual_after":rapier_bridge.manual_step_count(),
			"attempt":last_attempt.duplicate(true),"callback_count":callbacks_before})
		owner.delay_enabled = false
		paused = true
		physical_actor_session.set_suspended(true)
		update_worker_frame_state()
		finished = true

var host: Host
var worker: DelayedDeliveryWorker
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	OS.set_environment("CYBERSAND_DIAG_SAME_FRAME_CONTINUATION","1")
	OS.set_environment("CYBERSAND_DIAG_NATIVE_RENDEZVOUS","")
	OS.set_environment("CYBERSAND_DIAG_PHYSICS_PUBLICATION","early")
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("SAME_FRAME_INTEGRATION: " + label)
	return value

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+WAIT_MS
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	var loaded: Control = load("res://main.tscn").instantiate()
	loaded.set_script(Host)
	host = loaded
	worker = DelayedDeliveryWorker.new()
	host.simulation_worker = worker
	host.checks = check
	root.add_child(host)
	root.size = Vector2i(1280,800)
	if check(await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty()),"ordinary Workbench starts"):
		host.paused = true
		host.update_worker_frame_state()
		await until(func() -> bool: var snap: CyberSimulationSnapshot = worker.take_latest_snapshot(0); return snap != null and snap.paused)
		var setup: Dictionary = Setup.fresh(PackedInt32Array(host.shared_workbench.applied.liquid_policy),Vector2i(512,512))
		setup.actors = [Setup.instance("needle",1,Vector2(240,160)),Setup.instance(Setup.BARREL,2,Vector2(320,260))]
		setup.next_id = 3
		setup.selected = 1
		setup.edits = [[100,280,300,8,58],[240,210,12,2]]
		var epoch: int = host._physical_epoch
		if check(host.shared_workbench.apply(setup),"real two-actor native Workbench is admitted") \
			and check(await until(func() -> bool: return host.pending_microscenario_apply.is_empty() \
				and host._physical_epoch > epoch and host._physical_terrain_ready),"native World, real Rapier actors and exact terrain install"):
			check(host.same_frame_continuation_status().enabled and not host.native_rendezvous_status().enabled,"only explicitly selected nonblocking continuation is enabled")
			for mode: String in ["positive","cancel","pause","expired"]:
				worker.previous = worker.take_latest_physics_snapshot()
				worker.withheld = null
				worker.held_frame = -1
				worker.delay_enabled = true
				host.phase = mode
				host.finished = false
				host.last_attempt = {}
				check(host.shared_workbench.toggle_pause(),mode + " ordinary resume admitted")
				check(await until(func() -> bool: return host.finished),mode + " executes a real held callback and process attempt")
				if not host.finished: break
				await until(func() -> bool: var snap: CyberSimulationSnapshot = worker.take_latest_snapshot(0); return snap != null and snap.paused)
	var rows: Array = host.rows.duplicate(true)
	var diagnostics: Dictionary = {"arms":host.arm_observations,"reads":worker.read_observations,"callbacks":host.callbacks,"withheld":worker.withheld != null,"last_attempt":host.last_attempt}
	host.queue_free()
	await process_frame
	await process_frame
	check(not worker._thread.is_started() and worker.take_latest_physics_snapshot() == null,"shutdown joins actual native owner and retires authority")
	var report := {"schema":"workbench-same-frame-integration-v1","checks":checks,"failures":failures,
		"observations":rows,"diagnostics":diagnostics,"godot":Engine.get_version_info().string,"display":DisplayServer.get_name(),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
		"scope":"Real native/Rapier guard integration with delayed immutable delivery; not a performance measurement"}
	print("SAME_FRAME_INTEGRATION_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
