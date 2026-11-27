extends SceneTree

# Full ordinary Workbench, native worker and existing Rapier owner. No fake
# material samples, direct World writes, transform assignment or motor changes.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Examples = preload("res://scripts/ambient/ambient_examples.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var wb: Control
var checks := 0
var failures: Array[String] = []
var phases: Array = []
var trace: Array = []
var captures: Array = []
var _last_trace_tick := -1
var _watch_id := 1
var _started := 0


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1440, 900)
	set_meta("cybersand_feature", "shared_workbench")
	# The accepted recovery path prepares a bounded ordinary authored canvas;
	# it avoids allocating the unrelated default2048 canvas before this fixture.
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	set_meta("cybersand_playable_recovery", {"workbench":Setup.fresh(bridge.call(&"default_liquid_policy"), Vector2i(512, 512))})
	run.call_deferred()


func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("AMBIENT_WORKBENCH: " + label)
	return condition


func installed() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() \
		and host.pending_microscenario_apply.is_empty()


func control(id: int = 1) -> Dictionary:
	return host.physical_actor_session.workbench_control(id) if host != null and host.physical_actor_session != null else {}


func intent(id: int = 1) -> Dictionary:
	return control(id).get("diagnostics", {}).get("ambient", {}).get("intent", {})


func environment(id: int = 1) -> Dictionary:
	return control(id).get("diagnostics", {}).get("environment", {})


func physical_tick() -> int:
	return int(host.physical_actor_session.tick) if host != null and host.physical_actor_session != null else -1


func native_tick() -> int:
	return int(host.latest_snapshot.tick_index) if host != null and host.latest_snapshot != null else -1


func sample() -> void:
	var tick := physical_tick()
	if tick == _last_trace_tick or tick < 0: return
	_last_trace_tick = tick
	if tick % 6 != 0: return
	var c := control(_watch_id)
	var value := intent(_watch_id)
	trace.append({"run_id":str(c.get("run_id", "")), "epoch":int(c.get("epoch", -1)),
		"instance_id":_watch_id, "physical_tick":tick, "native_tick":native_tick(),
		"position":c.get("observation", {}).get("position", Vector2.ZERO),
		"grounded":bool(c.get("observation", {}).get("grounded", false)),
		"direction":value.get("direction", Vector2.ZERO), "pace":value.get("pace", 0.0),
		"override":value.get("active_override", ""), "remaining":value.get("remaining_seconds", 0.0),
		"decision_usec":c.get("decision_usec", 0), "sensor_usec":c.get("sensor_usec", 0),
		"accepted":c.get("accepted", 0), "rejected":c.get("rejected", 0)})


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	var report_at := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		sample()
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		if Time.get_ticks_msec() >= report_at:
			print("AMBIENT_WORKBENCH_WAIT ", label, " / native=", native_tick(), " physical=", physical_tick(),
				" / ", wb.message if wb != null else "opening")
			report_at = Time.get_ticks_msec() + 10000
		await process_frame
	return check(false, label + " timed out / " + str(wb.message if wb != null else "no Workbench"))


func progress(ticks: int, label: String) -> bool:
	var first_physical := physical_tick()
	var first_native := native_tick()
	var started := Time.get_ticks_usec()
	var ok := await until(func() -> bool:
		return physical_tick() >= first_physical + ticks and native_tick() >= first_native + maxi(1, ticks - 1), label)
	phases.append({"label":label, "requested_ticks":ticks, "physical_ticks":physical_tick() - first_physical,
		"native_ticks":native_tick() - first_native, "elapsed_usec":Time.get_ticks_usec() - started,
		"memory_bytes":OS.get_static_memory_usage(), "passed":ok})
	return ok


func fixture(ledge: bool = false) -> Dictionary:
	var data := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy), Vector2i(512, 512))
	data.edits = [[0, 468 if ledge else 360, 512, 12, 62]]
	var profile := Profile.blank("ledge_fixture" if ledge else "material_fixture")
	profile.name = "Actual ten-second ledge retreat" if ledge else "Actual painted material response"
	profile.seed = 24011
	if ledge:
		data.edits.append([60, 300, 240, 12, 62])
		data.edits.append([60, 312, 10, 156, 58])
		data.edits.append([290, 312, 10, 156, 58])
		var retreat := Profile.make_module("avoid_ledge", "ledge")
		retreat.params.allowed_drop = 6.0
		retreat.params.lookahead = 12.0
		retreat.params.duration = 10.0
		retreat.params.pace = 0.4
		profile.modules = [retreat]
	else:
		data.edits.append([234, 348, 3, 12, 62])
		data.edits.append([268, 348, 3, 12, 62])
		data.edits.append([237, 352, 31, 8, 16])
		var seek := Profile.make_module("seek_material", "oil")
		seek.params.radius = 50
		seek.params.standoff = 8.0
		seek.params.pace = 0.35
		var avoid := Profile.make_module("avoid_material", "water")
		avoid.params.enter_distance = 48.0
		avoid.params.exit_distance = 50.0
		avoid.params.radius = 50
		profile.modules = [seek, avoid]
	var actor := Setup.instance("runner", 1, Vector2(286, 276) if ledge else Vector2(200, 336))
	actor.control.source = "policy"
	actor.control.policy = "ambient"
	actor.control.usable_index = -1
	actor.control.ambient = profile
	data.actors = [actor]
	data.selected = 1
	data.next_id = 2
	data.material = 3
	data.brush = 10
	return data


func capture(label: String) -> void:
	var folder := OS.get_environment("CYBERSAND_AMBIENT_CAPTURE")
	if folder.is_empty(): return
	if not check(DisplayServer.get_name() != "headless", "capture requires an actual graphical renderer"): return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label + ".png")
	if check(root.get_texture().get_image().save_png(path) == OK, "actual Workbench capture: " + label):
		captures.append({"path":path, "physical_tick":physical_tick(), "native_tick":native_tick()})


func material_painting() -> void:
	check(wb.apply(fixture()), "ordinary authored material fixture admitted")
	if not await until(installed, "material fixture preparation"): return
	wb.set_camera(2)
	check(wb.toggle_pause(), "Play starts ambient through ordinary Workbench")
	if not await until(func() -> bool:
		return environment().get("materials", {}).get("targets", {}).get("16", {}).get("present", false), "native Oil acquired"): return
	check(float(intent().get("direction", Vector2.ZERO).x) > 0.0, "actual native Oil chooses rightward preference")
	var first: Vector2 = wb.actor_observation(1).position
	if not await progress(120, "ordinary Oil approach with coupled native progression"): return
	var next: Vector2 = wb.actor_observation(1).position
	check(next.x > first.x + 2.0, "real Runner moved toward Oil without position or velocity assignment")
	check(int(control().rejected) == 0 and int(control().accepted) > 1, "ordinary policy envelope accepts local ambient commands")
	check(wb.paint(Vector2i(248, 342), 3), "running ordinary Workbench brush queues actual Water")
	if not await until(func() -> bool: return str(intent().get("active_override", "")) == "water", "painted Water changes ambient priority"): return
	check(float(intent().get("direction", Vector2.ZERO).x) < 0.0, "higher-priority painted Water avoidance overrides nearby Oil")
	check(environment().get("materials", {}).get("source", "").begins_with("native material-ID"), "live preference uses copied native identity")
	wb.open_ambient_profile(1)
	var editor: Window = wb._ambient_profile_editor
	editor.refresh_inspection()
	check(editor._inspector.text.contains("Intent") and editor._inspector.text.contains(str(intent().get("reason", ""))),
		"ordinary live inspector displays actual intent and explanation")
	editor.hide()
	wb.set_ambient_overlay(1, true)
	await capture("01-painted-water-response")
	wb.set_ambient_overlay(1, false)
	check(wb.toggle_pause(), "pause material fixture")
	var generation: int = int(control().generation)
	var profile_before: Dictionary = Catalog.control_for(wb.actor(wb.applied, 1)).ambient.duplicate(true)
	var engine_before: Dictionary = control().diagnostics.ambient.duplicate(true)
	for index: int in range(12):
		wb.select_instance(1)
		wb.actor_observation(1, false)
		control()
	check(int(control().generation) == generation and control().diagnostics.ambient == engine_before,
		"inspection neither issues authority nor changes ephemeral intentions")
	check(wb.pilot_instance(1), "human takeover retains real body")
	check(Catalog.control_for(wb.actor(wb.applied, 1)).ambient == profile_before, "human takeover preserves authored ambient profile")
	check(wb.hand_back_pilot(), "handback restores procedural adapter")
	check(int(control().diagnostics.get("ambient", {}).get("decisions", 0)) == 0, "handback explicitly restarts ephemeral decisions")


func ledge_clock() -> void:
	check(wb.apply(fixture(true)), "ordinary physical ledge fixture admitted")
	if not await until(installed, "ledge fixture preparation"): return
	wb.set_camera(2)
	check(wb.toggle_pause(), "Play ledge fixture")
	if not await until(func() -> bool: return str(intent().get("active_override", "")) == "ledge", "physical lookahead detects walkway drop"): return
	var first_tick := physical_tick()
	var first_clock := float(control().simulation_time_seconds)
	check(float(intent().direction.x) < 0.0, "ledge retreat latches away from actual right-hand drop")
	check(float(intent().remaining_seconds) > 9.7, "new ledge retreat starts at ten simulation seconds")
	var start_count: int = int(control().diagnostics.ambient.module_state.ledge.get("triggers", 0))
	check(start_count == 1, "first actual ledge latch records exactly one trigger")
	if not await progress(120, "two physical seconds of latched retreat"): return
	check(wb.toggle_pause(), "pause during latched retreat")
	var paused_tick := physical_tick()
	var paused_time := float(control().simulation_time_seconds)
	var paused_memory: Dictionary = control().diagnostics.ambient.duplicate(true)
	var pause_until := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < pause_until: await process_frame
	check(physical_tick() == paused_tick and float(control().simulation_time_seconds) == paused_time,
		"paused wall time advances neither physical tick nor simulation clock")
	check(control().diagnostics.ambient == paused_memory, "pause preserves remaining retreat duration and RNG")
	check(int(control().lease_remaining) == 0, "pause retires current command lease")
	check(wb.toggle_pause(), "resume from a fresh issued observation")
	if not await until(func() -> bool: return physical_tick() >= first_tick + 570, "retreat still active before ten seconds"): return
	check(str(intent().get("active_override", "")) == "ledge" and float(intent().direction.x) < 0.0,
		"retreat remains latched for at least9.5 simulated seconds")
	if not await until(func() -> bool: return physical_tick() >= first_tick + 618, "retreat finite release"): return
	check(str(intent().get("active_override", "")) != "ledge", "ten-second retreat releases without refreshing its timer")
	var module_state: Dictionary = control().diagnostics.ambient.module_state.ledge
	check(int(module_state.get("triggers", 0)) == start_count, "continued edge sensing does not renew the same retreat trigger")
	phases.append({"label":"ten-second retreat", "trigger_tick":first_tick, "finish_tick":physical_tick(),
		"completed_seconds":float(control().simulation_time_seconds) - first_clock,
		"paused_wall_ms":400, "trigger_count":start_count, "module_state":module_state.duplicate(true)})
	wb.set_ambient_overlay(1, true)
	await capture("02-physical-ledge-retreat")
	wb.set_ambient_overlay(1, false)
	check(wb.toggle_pause(), "pause after completed retreat")


func population() -> void:
	check(wb.load_ambient_example("ambient-settlement"), "ordinary UI loads authored eight-inhabitant settlement")
	if not await until(installed, "settlement native preparation"): return
	check(wb.applied.actors.size() == Catalog.MAX_AMBIENT_CONTROLLERS, "population uses actual accepted eight-actor capacity")
	check(wb.toggle_pause(), "Play all eight independent procedural actors")
	if not await progress(90, "eight-actor actual ambient settlement"): return
	var rows: Array = []
	for actor: Dictionary in wb.applied.actors:
		var c := control(int(actor.id))
		check(int(c.get("accepted", 0)) > 2 and int(c.get("rejected", 0)) == 0, "independent admitted decisions for settlement actor#%d" % actor.id)
		rows.append({"id":actor.id, "model":actor.model, "accepted":c.get("accepted"), "rejected":c.get("rejected"),
			"decision_usec":c.get("decision_usec"), "sensor_usec":c.get("sensor_usec"), "position":c.observation.position})
	phases.append({"label":"accepted capacity population", "actors":rows,
		"perception":host.physical_actor_session._ambient_perception.diagnostics()})
	await capture("03-eight-inhabitant-settlement")
	check(wb.toggle_pause(), "pause settlement")
	var before_run := str(control().run_id)
	check(wb.remove_selected(), "ordinary actor deletion admitted")
	if await until(installed, "actor deletion acknowledged"):
		check(wb.applied.actors.size() == 7 and str(control(2).run_id) != before_run,
			"deletion retires old session and authored instance without stale authority")


func run() -> void:
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if await until(func() -> bool: return host.shared_workbench != null, "ordinary Workbench opens"):
		wb = host.shared_workbench
		if await until(installed, "initial prepared owner"):
			await material_painting()
			if failures.is_empty(): await ledge_clock()
			if failures.is_empty(): await population()
	await finish()


func finish() -> void:
	var report := {"case":"AMBIENT-001 ordinary Workbench native gameplay", "checks":checks,
		"failures":failures, "headless":DisplayServer.get_name() == "headless", "godot":Engine.get_version_info(),
		"elapsed_msec":Time.get_ticks_msec() - _started, "phases":phases, "trace":trace, "captures":captures,
		"limits":["No physical Windows/NVIDIA acceptance", "No cross-platform Rapier trajectory determinism claim"]}
	var path := OS.get_environment("CYBERSAND_AMBIENT_WORKBENCH_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(Catalog._json_value(report), "\t")); file.close()
	print("AMBIENT_WORKBENCH checks=", checks, " failures=", failures.size(), " phases=", phases.size())
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
