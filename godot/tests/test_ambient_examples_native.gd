extends SceneTree

# Real ordinary Workbench examples, native material owner and existing Rapier
# session. Telemetry reads copied diagnostics and poses; it cannot affect input,
# RNG, leases, body motion or native material. This is not an aesthetic verdict.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Examples = preload("res://scripts/ambient/ambient_examples.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const TICKS := 240
var host: Control
var wb: Control
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var rows: Dictionary = {}
var collecting := false
var last_tick := -1
var started := 0
var source: Dictionary = {}


func _initialize() -> void:
	started = Time.get_ticks_msec()
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	set_meta("cybersand_feature", "shared_workbench")
	# The accepted recovery route prepares a bounded initial authored canvas;
	# every example still passes through ordinary native/physical admission.
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	set_meta("cybersand_playable_recovery", {"workbench":Setup.fresh(bridge.call(&"default_liquid_policy"), Vector2i(512, 512))})
	var files := ["scripts/main.gd", "scripts/shared_workbench.gd", "scripts/physical_actor_session.gd",
		"scripts/physical_actor_rig.gd", "scripts/workbench_actor_control.gd", "scripts/workbench_setup.gd",
		"scripts/ambient/ambient_profile.gd", "scripts/ambient/ambient_examples.gd",
		"scripts/ambient/ambient_engine.gd", "scripts/ambient/ambient_modules.gd",
		"scripts/ambient/ambient_perception.gd", "scripts/ambient/ambient_actuator.gd",
		"data/ambient/profiles.json", "tests/test_ambient_examples_native.gd"]
	for example: Dictionary in Examples.legacy_entries(): files.append("examples/workbench/" + str(example.id) + ".json")
	if OS.get_name() == "Windows":
		files.append("addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll")
		files.append("addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")
	else:
		files.append("addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")
		files.append("addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")
	var hashes := {}
	for name: String in files: hashes[name] = FileAccess.get_sha256("res://" + name)
	source = {"captured_utc":Time.get_datetime_string_from_system(true), "platform":OS.get_name(),
		"godot":Engine.get_version_info().string, "engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"display":DisplayServer.get_name(), "files_sha256":hashes}
	run.call_deferred()


func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("AMBIENT_EXAMPLES: " + label)
	return condition


func installed() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() \
		and host.pending_microscenario_apply.is_empty()


func physical_tick() -> int:
	return int(host.physical_actor_session.tick) if host != null and host.physical_actor_session != null else -1


func completed_physical_ticks() -> int:
	return int(host.physical_actor_session.bridge.manual_step_count()) if host != null and host.physical_actor_session != null else -1


func native_tick() -> int:
	return int(host.latest_snapshot.tick_index) if host != null and host.latest_snapshot != null else -1


func revision() -> int:
	return int(host.latest_snapshot.simulation_world_revision) if host != null and host.latest_snapshot != null else -1


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	var next_notice := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		sample()
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		if Time.get_ticks_msec() >= next_notice:
			print("AMBIENT_EXAMPLES_WAIT ", label, " native=", native_tick(), " physical=", physical_tick())
			next_notice = Time.get_ticks_msec() + 10000
		await process_frame
	return check(false, label + " / " + str(wb.message if wb != null else "opening"))


func make_rows() -> void:
	rows.clear()
	last_tick = -1
	for actor: Dictionary in wb.applied.actors:
		rows[int(actor.id)] = {"instance_id":actor.id, "model":actor.model,
			"profile":actor.control.ambient.duplicate(true), "sampled_path_cells":0.0,
			"pose_samples":0, "observed_decisions":0, "intentional_idle_decisions":0,
			"intent_x_sign_changes":0, "action_x_sign_changes":0, "active_intervals":0,
			"stalled_active_intervals":0, "overrides":{}, "material_observations":{},
			"material_unavailable_decisions":0, "faults":[], "trace":[],
			"decision_usec_max":0, "sensor_usec_max":0, "last_observed_decision":-1}


func sample() -> void:
	if not collecting or physical_tick() == last_tick: return
	last_tick = physical_tick()
	for id: int in rows:
		var row: Dictionary = rows[id]
		var view: Dictionary = host.physical_actor_session.workbench_control(id)
		var observed: Dictionary = view.get("observation", {})
		var position: Variant = observed.get("position")
		if not position is Vector2 or not position.is_finite():
			if "invalid copied pose" not in row.faults: row.faults.append("invalid copied pose")
			continue
		var fault := str(observed.get("fault", ""))
		if not fault.is_empty() and fault not in row.faults: row.faults.append(fault)
		if row.has("last_position"):
			row.sampled_path_cells += Vector2(position).distance_to(row.last_position)
		else:
			row.first_position = position
		row.last_position = position
		row.pose_samples += 1
		row.accepted_commands = int(view.get("accepted", 0))
		row.rejected_commands = int(view.get("rejected", 0))
		row.last_status = str(view.get("status", ""))
		row.last_error = str(view.get("error", ""))
		row.decision_usec_max = maxi(row.decision_usec_max, int(view.get("decision_usec", 0)))
		row.sensor_usec_max = maxi(row.sensor_usec_max, int(view.get("sensor_usec", 0)))
		var diagnostics: Dictionary = view.get("diagnostics", {})
		var ambient: Dictionary = diagnostics.get("ambient", {})
		var intent: Dictionary = ambient.get("intent", {})
		var count := int(ambient.get("decisions", 0))
		if count < 1 or count == int(row.last_observed_decision): continue
		row.last_observed_decision = count
		row.observed_decisions += 1
		var direction: Vector2 = intent.get("direction", Vector2.ZERO)
		var action: Dictionary = diagnostics.get("last_action", {})
		var move: Vector2 = action.get("move", Vector2.ZERO)
		if direction.length_squared() <= 0.000001 or float(intent.get("pace", 0.0)) <= 0.0:
			row.intentional_idle_decisions += 1
		for channel: String in ["intent", "action"]:
			var axis: float = direction.x if channel == "intent" else move.x
			var sign_value := signf(axis) if absf(axis) > 0.05 else 0.0
			var key := "last_" + channel + "_sign"
			if sign_value != 0.0:
				if row.has(key) and float(row[key]) != sign_value: row[channel + "_x_sign_changes"] += 1
				row[key] = sign_value
		var trace: Array = row.trace
		if not trace.is_empty() and Vector2(trace.back().action_move).length() > 0.05:
			row.active_intervals += 1
			if Vector2(position).distance_to(trace.back().position) < 0.25: row.stalled_active_intervals += 1
		var override_id := str(intent.get("active_override", ""))
		if not override_id.is_empty(): row.overrides[override_id] = int(row.overrides.get(override_id, 0)) + 1
		var environment: Dictionary = diagnostics.get("environment", {})
		var material: Dictionary = environment.get("materials", {})
		if not bool(material.get("available", false)): row.material_unavailable_decisions += 1
		var targets: Dictionary = material.get("targets", {})
		for material_id: Variant in targets:
			var target: Dictionary = targets[material_id]
			if not bool(target.get("available", false)) or not bool(target.get("present", false)): continue
			if not row.material_observations.has(str(material_id)):
				row.material_observations[str(material_id)] = {"count":0, "first_distance":float(target.distance),
					"minimum_distance":float(target.distance), "last_distance":float(target.distance)}
			var summary: Dictionary = row.material_observations[str(material_id)]
			summary.count += 1
			summary.minimum_distance = minf(float(summary.minimum_distance), float(target.distance))
			summary.last_distance = float(target.distance)
		trace.append({"physical_tick":last_tick, "native_tick":native_tick(), "decision":count,
			"position":position, "intent":direction, "pace":intent.get("pace", 0.0),
			"reason":intent.get("reason", ""), "override":override_id, "remaining_seconds":intent.get("remaining_seconds", 0.0),
			"action_move":move, "materials_available":material.get("available", false),
			"material_sample_tick":material.get("sample_tick", -1), "material_revision":material.get("revision", -1),
			"targets":targets.duplicate(true)})


func example_case(example: Dictionary) -> void:
	collecting = false
	if not host.paused: wb.toggle_pause()
	var begin := Time.get_ticks_usec()
	var expected: Dictionary = Examples.make(str(example.id), PackedInt32Array(wb.applied.liquid_policy))
	if not check(wb.load_ambient_example(str(example.id)), "ordinary example requested: " + str(example.id)): return
	if not await until(installed, "ordinary native and physical admission: " + str(example.id)): return
	if not check(host.physical_actor_session != null, "ordinary physical actor owner admitted: " + str(example.id)): return
	check(wb.applied.actors.size() == expected.actors.size(), "admitted complete cast: " + str(example.id))
	check(Setup.extent_of(wb.applied) == Vector2i(1024, 512), "admitted authored extent: " + str(example.id))
	check(host.paused, "example starts paused: " + str(example.id))
	make_rows()
	collecting = true
	sample()
	var first_native := native_tick()
	var first_physical := physical_tick()
	var first_completed := completed_physical_ticks()
	var first_revision := revision()
	if not check(wb.toggle_pause(), "ordinary Play accepted: " + str(example.id)): return
	var progressed := await until(func() -> bool:
		return completed_physical_ticks() >= first_completed + TICKS and native_tick() >= first_native + TICKS,
		"completed native and physical interval: " + str(example.id))
	sample()
	var case_record := {"id":example.id, "actors":rows.values().duplicate(true), "requested_ticks":TICKS,
		"native_ticks":native_tick() - first_native, "physical_ticks":physical_tick() - first_physical,
		"completed_rapier_steps":completed_physical_ticks() - first_completed,
		"initial_material_revision":first_revision, "final_material_revision":revision(),
		"wall_usec":Time.get_ticks_usec() - begin, "memory_bytes":OS.get_static_memory_usage(),
		"sensor":host.physical_actor_session._ambient_perception.diagnostics(), "progressed":progressed}
	check(progressed, "actual completed owner progression: " + str(example.id))
	check(not host.simulation_worker.has_failed(), "native owner remains healthy: " + str(example.id))
	for row: Dictionary in case_record.actors:
		var label := "%s / #%d %s" % [example.id, int(row.instance_id), str(row.model)]
		check(row.faults.is_empty(), "finite copied motion and no physical fault: " + label)
		check(int(row.get("accepted_commands", 0)) > 0 and int(row.observed_decisions) > 0,
			"ambient authority actually made and admitted decisions: " + label)
		check(int(row.get("rejected_commands", 0)) == 0 and str(row.get("last_error", "")).is_empty(),
			"no refused procedural commands: " + label)
		check(str(row.get("last_status", "")) == "policy", "live policy authority remains active: " + label)
	case_record["passed"] = failures.is_empty()
	cases.append(case_record)
	print("AMBIENT_EXAMPLE ", example.id, " actors=", rows.size(), " native=", case_record.native_ticks,
		" rapier=", case_record.completed_rapier_steps, " failures=", failures.size())
	collecting = false
	wb.toggle_pause()


func run() -> void:
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if await until(func() -> bool: return host.shared_workbench != null, "ordinary Workbench opens"):
		wb = host.shared_workbench
		if await until(installed, "initial bounded native owner"):
			for example: Dictionary in Examples.legacy_entries():
				await example_case(example)
				if not failures.is_empty(): break
	check(cases.size() == Examples.legacy_entries().size(), "all five ordinary examples reached a completed play interval")
	await finish()


func finish() -> void:
	var report := {"case":"AMBIENT-001 all ordinary examples native gameplay", "checks":checks,
		"failures":failures, "source_identity":source, "cases":cases,
		"elapsed_msec":Time.get_ticks_msec() - started,
		"metrics":{"sampled_path_cells":"Sum between copied poses at observed physical ticks; skipped ticks can underestimate travel.",
			"intentional_idle_decisions":"Observed decisions with neutral direction or zero requested pace; flight neutral can actively hover.",
			"stalled_active_intervals":"Prior requested action move >0.05 and travel <0.25 cells to the next sampled decision; not a claim of unreachable terrain.",
			"material_distance":"Nearest observed sparse native-ID sample, not exact nearest cell; material can move too.",
			"material_revision":"Native owner revision progression; not an isolated fluid-flow metric."},
		"limits":["No aesthetic or optimal pathfinding threshold", "No graphical screenshot or physical Windows/NVIDIA acceptance",
			"No guaranteed material encounter within the four-second observation window"]}
	var path := OS.get_environment("CYBERSAND_AMBIENT_EXAMPLES_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(Catalog._json_value(report), "\t")); file.close()
	print("AMBIENT_EXAMPLES checks=", checks, " failures=", failures.size(), " cases=", cases.size())
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
