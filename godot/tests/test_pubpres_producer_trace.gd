extends SceneTree

# Real Workbench/native/Rapier producer trace. No samples, completions, physical
# callbacks or terrain receipts are manufactured by this diagnostic fixture.
const Setup = preload("res://scripts/workbench_setup.gd")
const PHASES := ["sample_admitted","worker_latch","coupling_prepare",
	"coupling_results","native_observations_ready"]

class TraceHost extends "res://scripts/main.gd":
	var producer_main_events: Array[Dictionary] = []
	var producer_main_overflow: int = 0
	func _pubpres_transaction_observed(event: String, evidence: Dictionary) -> void:
		if producer_main_events.size() >= 10000:
			producer_main_overflow += 1
		else:
			producer_main_events.append({"kind":event,"evidence":evidence.duplicate(true)})

var checks: int = 0
var failures: Array[String] = []
var host: Variant
var worker: CyberSimulationWorker

func _initialize() -> void:
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PUBPRES_PRODUCER_TRACE: " + label)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+30000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false

func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(TraceHost)
	if OS.get_environment("CYBERSAND_PUBPRES_EXPECT_MAIN_TRACE") == "1":
		host.set("_pubpres_trace_enabled",true)
	worker = CyberSimulationWorker.new()
	host.simulation_worker = worker
	root.add_child(host)
	root.size = Vector2i(1280,800)
	if check(await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty()),
			"ordinary Workbench starts"):
		host.paused = true
		host.update_worker_frame_state()
		await until(func() -> bool: var s = worker.take_latest_snapshot(0); return s != null and s.paused)
		var setup: Dictionary = Setup.fresh(PackedInt32Array(host.shared_workbench.applied.liquid_policy),Vector2i(512,512))
		setup.actors = [Setup.instance("needle",1,Vector2(240,160)),Setup.instance(Setup.BARREL,2,Vector2(320,260))]
		setup.next_id = 3
		setup.selected = 1
		setup.edits = [[100,280,300,8,58],[240,210,12,2]]
		var epoch: int = host._physical_epoch
		if check(host.shared_workbench.apply(setup),"real two-actor native setup admitted") \
				and check(await until(func() -> bool: return host.pending_microscenario_apply.is_empty() \
					and host._physical_epoch > epoch and host._physical_terrain_ready),"native owner and exact terrain installed"):
			await _capture()
	if OS.get_environment("CYBERSAND_PUBPRES_EXPECT_MAIN_TRACE") == "1":
		check(host.producer_main_overflow == 0,"bounded Main trace has no lost events")
		for kind: String in ["mailbox_observation","terrain_install","transaction_entry"]:
			check(host.producer_main_events.any(func(e: Dictionary) -> bool: return e.kind == kind),
				"real Main emits observed " + kind)
	host.queue_free()
	await process_frame
	await process_frame
	check(not worker._thread.is_started(),"native owner joined on shutdown")
	print("PUBPRES_PRODUCER_TRACE_RESULT ",JSON.stringify({"schema":"pubpres-producer-trace-v1",
		"checks":checks,"failures":failures,"detail":worker._publication_detail_trace,
		"display":DisplayServer.get_name(),"scope":"native/Rapier correctness, not graphical performance"}))
	quit(0 if failures.is_empty() else 1)

func _capture() -> void:
	var before: int = host.physical_actor_session.tick
	var manual_before: int = host.rapier_bridge.manual_step_count()
	check(worker.begin_render_cadence_trace(),"bounded producer capture begins")
	check(host.shared_workbench.toggle_pause(),"ordinary resume admitted")
	check(await until(func() -> bool: return host.physical_actor_session.tick >= before+8),"actual sustained native/Rapier steps execute")
	check(host.shared_workbench.toggle_pause(),"ordinary pause admitted")
	check(await until(func() -> bool: var s = worker.take_latest_snapshot(0); return s != null and s.paused),"native owner acknowledges pause")
	var capture: Dictionary = worker.finish_render_cadence_trace()
	check(host.physical_actor_session.tick-before == host.rapier_bridge.manual_step_count()-manual_before,
		"every physical step has exactly one real Rapier completion")
	check(capture.dropped == 0,"bounded trace has no lost events")
	check(worker.take_render_cadence_events().events.is_empty(),"drain transfers trace ownership")
	var events: Array = capture.events
	if not worker._publication_detail_trace:
		check(events.filter(func(e: Dictionary) -> bool: return e.kind in PHASES).is_empty(),
			"common observer excludes additive producer instrumentation")
		return
	var joined: Dictionary = {}
	for event: Dictionary in events:
		if event.kind != "native_tick" or event.body_sample < 0: continue
		var id: String = "%d/%d/%d/%d" % [event.world_generation,event.session,event.rigid_body_epoch,event.body_sample]
		if joined.has(id): continue
		var admitted: Dictionary = _phase(events,"sample_admitted",event,0,event.start_usec)
		# The initial prepared sample may precede capture; do not invent its age.
		if admitted.is_empty(): continue
		var latch: Dictionary = _phase(events,"worker_latch",event,admitted.completed_usec,event.start_usec)
		var prepared: Dictionary = _phase(events,"coupling_prepare",event,admitted.completed_usec,event.start_usec)
		var results: Dictionary = _phase(events,"coupling_results",event,event.completed_usec,9223372036854775807)
		var observed: Dictionary = _phase(events,"native_observations_ready",event,event.completed_usec,9223372036854775807)
		var publication: Dictionary = _phase(events,"physics_publication",event,event.completed_usec,9223372036854775807)
		if not check(not latch.is_empty() and not prepared.is_empty() and not results.is_empty() \
				and not observed.is_empty() and not publication.is_empty(),"actual native tick joins all producer boundaries"):
			continue
		check(admitted.world_generation == -1 and admitted.tick_index == -1 and admitted.required_hard_revision == -1,
			"sample acceptance does not claim an unobserved native identity")
		check(latch.completed_usec <= prepared.start_usec and prepared.completed_usec <= event.start_usec \
			and event.completed_usec <= results.start_usec and results.completed_usec <= observed.completed_usec \
			and observed.completed_usec <= publication.completed_usec,"producer phases are causally ordered")
		check(prepared.status == "prepared" and results.status == "healthy" and observed.status == "healthy",
			"healthy publication is backed by successful native operations")
		check(publication.required_hard_revision == observed.required_hard_revision \
			and publication.tick_index == event.tick_index,"published terrain and native completion identities match")
		joined[id] = true
	check(joined.size() >= 4,"multiple real samples preserve complete producer identity")

func _phase(events: Array, kind: String, native: Dictionary, earliest: int, latest: int) -> Dictionary:
	for event: Dictionary in events:
		if event.kind == kind and event.session == native.session \
				and event.rigid_body_epoch == native.rigid_body_epoch and event.body_sample == native.body_sample \
				and int(event.completed_usec) >= earliest and int(event.completed_usec) <= latest:
			return event
	return {}
