extends "res://tests/test_workbench_physics_publication.gd"

const PRODUCER_PHASES := ["sample_admitted", "worker_latch", "coupling_prepare",
	"coupling_results", "native_observations_ready"]


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 2)
	set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(ObservingHost)
	worker = StalledRenderWorker.new()
	host.simulation_worker = worker
	root.add_child(host)
	root.size = Vector2i(1280, 800)
	var enabled: bool = OS.get_environment("CYBERSAND_DIAG_PHYSICS_CAUSAL_TRACE") == "1"
	var mode: String = "combined" if worker._combined_physics_publication else "early"
	if check(await until(func() -> bool: return host.shared_workbench != null \
			and not host.shared_workbench.applied.is_empty(), STARTUP_WAIT_MS), "ordinary Workbench starts") \
			and await install():
		await _capture(enabled, mode)
	host.queue_free()
	await process_frame
	await process_frame
	check(not worker._thread.is_started() and worker.take_latest_physics_snapshot() == null,
		"shutdown joins the native owner and retires its physical publication")
	print("WORKBENCH_PHYSICS_CAUSAL_RESULT ", JSON.stringify({
		"schema":"workbench-physics-causal-v1", "checks":checks, "failures":failures,
		"enabled":enabled, "mode":mode, "observations":observations,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"godot":Engine.get_version_info().string, "display":DisplayServer.get_name()}))
	quit(int(not failures.is_empty()))


func _capture(enabled: bool, mode: String) -> void:
	var first_step: int = host.physical_actor_session.tick
	var first_manual: int = host.rapier_bridge.manual_step_count()
	check(worker.begin_render_cadence_trace(), "bounded worker capture begins")
	check(host.shared_workbench.toggle_pause(), "ordinary Workbench resume admitted")
	check(await until(func() -> bool: return host.physical_actor_session.tick >= first_step + 8),
		"real native and Rapier steps complete")
	check(host.shared_workbench.toggle_pause(), "ordinary Workbench pause admitted")
	await pause()
	var capture: Dictionary = worker.finish_render_cadence_trace()
	check(capture.dropped == 0 and worker.take_render_cadence_events().events.is_empty(),
		"bounded buffer retains and transfers every event")
	check(host.physical_actor_session.tick - first_step == host.rapier_bridge.manual_step_count() - first_manual,
		"every observed physical step completes exactly one real manual Rapier step")
	var events: Array = capture.events
	if not enabled:
		check(not events.any(func(row: Dictionary) -> bool: return row.kind in PRODUCER_PHASES),
			"ordinary trace excludes producer phases when causal observation is off")
		return
	var joined: int = 0
	for native: Dictionary in events:
		if native.kind != "native_tick" or native.body_sample < 0: continue
		var admitted: Dictionary = _phase(events, "sample_admitted", native, "accepted", 0)
		# The initial body sample may have been prepared before capture started.
		if admitted.is_empty(): continue
		var latched: Dictionary = _phase(events, "worker_latch", native, "latched", admitted.completed_usec)
		var prepared: Dictionary = _phase(events, "coupling_prepare", native, "prepared", admitted.completed_usec)
		var feedback: Dictionary = _phase(events, "coupling_results", native, "healthy", native.completed_usec)
		var observed: Dictionary = _phase(events, "native_observations_ready", native, "healthy", native.completed_usec)
		var published: Dictionary = _phase(events, "physics_publication", native, "", native.completed_usec)
		if not check(not latched.is_empty() and not prepared.is_empty() and not feedback.is_empty() \
				and not observed.is_empty() and not published.is_empty(), "sample joins all genuine producer boundaries"):
			continue
		check(admitted.start_usec <= admitted.completed_usec and admitted.world_generation == -1 \
			and admitted.tick_index == -1 and admitted.required_hard_revision == -1,
			"Main request and acceptance do not claim an unseen native identity")
		check(admitted.completed_usec <= latched.completed_usec and latched.completed_usec <= prepared.start_usec \
			and prepared.completed_usec <= native.start_usec and native.start_usec <= native.completed_usec \
			and native.completed_usec <= feedback.start_usec and feedback.completed_usec <= observed.completed_usec \
			and observed.completed_usec <= published.completed_usec, "producer boundaries are causally ordered")
		check(latched.world_generation == native.world_generation and prepared.world_generation == native.world_generation \
			and feedback.world_generation == native.world_generation and observed.world_generation == native.world_generation \
			and published.world_generation == native.world_generation and published.publication_mode == mode \
			and published.packet_valid and published.workbench_refusal.is_empty() \
			and published.tick_index == native.tick_index and published.native_completed_usec == native.completed_usec \
			and observed.completed_body_sample == native.body_sample \
			and published.required_hard_revision == observed.required_hard_revision \
			and published.packet_hard_revision == published.required_hard_revision,
			"healthy producer publication retains exact World, sample and required terrain")
		# A later retained status packet may repeat the same completion with a
		# larger serial. Its receipt cannot change the first handoff clock.
		var consumed: Array = host.admissions.filter(func(row: Dictionary) -> bool:
			return row.completed_sample == native.body_sample and row.native_tick == native.tick_index \
				and row.step > first_step and row.serial >= published.snapshot_serial)
		if consumed.is_empty(): continue # May be the final unspent sample at pause.
		check(consumed.size() == 1 and consumed[0].time_usec >= published.completed_usec \
			and consumed[0].required_revision == published.required_hard_revision \
			and consumed[0].installed_revision == published.required_hard_revision \
			and consumed[0].pending_chunks == 0 and consumed[0].response.accepted,
			"one actual Rapier completion uses validated feedback on exact installed terrain")
		observations.append({"admitted":admitted, "latched":latched, "prepared":prepared,
			"native":native, "feedback":feedback, "observed":observed, "first_publication":published,
			"rapier_completed_usec":consumed[0].time_usec, "rapier_step":consumed[0].step})
		joined += 1
	check(joined >= 4, "multiple real samples join their admissions to Rapier completions")


func _phase(events: Array, kind: String, native: Dictionary, status: String, earliest_usec: int) -> Dictionary:
	for event: Dictionary in events:
		if event.kind == kind and event.get("session", -1) == native.session \
				and event.get("rigid_body_epoch", -1) == native.rigid_body_epoch \
				and event.get("body_sample", -1) == native.body_sample \
				and (status.is_empty() or event.get("status") == status) \
				and int(event.completed_usec) >= earliest_usec:
			return event
	return {}
