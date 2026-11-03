extends SceneTree

# Repeated actual asynchronous sessions. These are observational distributions,
# not matched trajectories, per-tick geometry or a GPU/feel qualification.
const Session = preload("res://scripts/solid_detachment_session.gd")
const Consumer = preload("res://scripts/solid_detachment_render_consumer.gd")
const STEPS: int = 360
const REPEATS: int = 3
var checks: int = 0
var failures: Array[String] = []
var workers: int = 1
var records: Array[Dictionary] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL SOL281 CONTACT RECOVERY ", message)

func _init() -> void:
	call_deferred("_run")

func _case(kind: String, candidate: bool, repeat: int) -> void:
	var label: String = "%s/%s/r%d" % [kind, "candidate" if candidate else "baseline", repeat]
	var session = Session.new()
	var opened: bool = await session.open(root, workers, kind, true, candidate, true)
	check(opened, label + ": source-matched owner opens")
	if not opened:
		session.close()
		return
	var intact: Dictionary = await session.observe_intact()
	check(intact.get("outcome") == "Anchored", label + ": intact structure stays native")
	var before: Dictionary = await session.inspect_coupling(PackedInt32Array(), Rect2i(0, 0, 160, 128))
	var before_material: Dictionary = before.get("diagnostic_snapshot", {})
	var before_counts: Array = before_material.get("counts", [])
	var sand_before: int = int(before_counts[2]) if before_counts.size() > 2 else -1
	var water_before: int = int(before_material.get("water_mass", -1))
	var released: bool = await session.cut_and_release()
	check(released, label + ": actual trunk cut releases once")
	if not released:
		session.close()
		return
	var initial: Transform2D = session.body_transform()
	var max_translation: float = 0.0
	var max_rotation: float = 0.0
	var max_omega: float = 0.0
	var finite_motion: bool = true
	var consumer = Consumer.new()
	var render_serial: int = -1
	var observation_serial: int = -1
	var trace: Array[Dictionary] = []
	for step: int in range(STEPS):
		await physics_frame
		session.physics_step()
		var pose: Transform2D = session.body_transform()
		finite_motion = finite_motion and pose.is_finite() and is_finite(session.angular_velocity())
		max_translation = maxf(max_translation, pose.origin.distance_to(initial.origin))
		max_rotation = maxf(max_rotation, absf(pose.get_rotation()))
		max_omega = maxf(max_omega, absf(session.angular_velocity()))
		var snapshot: CyberSimulationSnapshot = session.worker.take_latest_snapshot(render_serial)
		if snapshot != null:
			render_serial = snapshot.serial
			if snapshot.render_snapshot_serial > consumer.last_serial and consumer.consume(snapshot):
				session.worker.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
		var observation: Dictionary = session.last_contact_observation
		if observation.get("ok", false) and int(observation.get("snapshot_serial", -1)) != observation_serial:
			observation_serial = int(observation.snapshot_serial)
			var source_pose: Transform2D = observation.source_transform
			trace.append({"rapier_step":step + 1, "snapshot":observation_serial,
				"native_tick":observation.tick, "sample_serial":observation.sample_serial,
				"revision":observation.revision, "physics_epoch":observation.physics_epoch,
				"token":observation.token, "body_generation":observation.body_generation,
				"source_published_usec":observation.published_usec, "observed_usec":Time.get_ticks_usec(),
				"proxies":observation.proxies,
				"overlap_cells":observation.overlap_cells, "overlap_area":observation.overlap_area,
				"sand_overlap_area":observation.sand_overlap_area,
				"max_penetration":observation.max_penetration,
				"max_sand_penetration":observation.max_sand_penetration,
				"contact_count":observation.contacts.size(), "observation_ms":observation.observation_ms,
				"source_x":source_pose.origin.x, "source_y":source_pose.origin.y,
				"source_angle":source_pose.get_rotation(),
				"current_x":pose.origin.x, "current_y":pose.origin.y, "current_angle":pose.get_rotation(),
				"omega":session.angular_velocity()})
	var after: Dictionary = await session.inspect_coupling(PackedInt32Array(), Rect2i(0, 0, 160, 128))
	var material: Dictionary = after.get("diagnostic_snapshot", {})
	var counts: Array = material.get("counts", [])
	var sand_after: int = int(counts[2]) if counts.size() > 2 else -2
	var water_after: int = int(material.get("water_mass", -2))
	var metrics: Dictionary = session.coupling_metrics()
	var physical: Dictionary = metrics.get("physical_contact", {})
	check(after.get("ok", false) and not after.get("worker_failed", true) and session.last_error.is_empty(),
		label + ": complete healthy owner")
	check(after.get("members") == session.source_receipt.get("members"), label + ": exact aggregate tuple payload")
	check(int(after.get("aggregate_owned", -1)) == 520 and int(after.get("native_source_members", -1)) == 0,
		label + ": single owner of all 520 members")
	check(sand_before > 0 and sand_before == sand_after, label + ": exact Sand quantity")
	check(water_before >= 0 and water_before == water_after, label + ": exact Water quantity")
	check(finite_motion, label + ": finite Rapier translation and rotation")
	check(int(metrics.get("proxy_count", 0)) == 6, label + ": six original proxies retain holes")
	check(int(metrics.get("timed_rapier_steps", 0)) == STEPS, label + ": all registered physics steps execute")
	check(int(physical.get("observations", 0)) > 0 and not trace.is_empty(), label + ": exact geometry observations captured")
	check(int(physical.get("energy_violations", -1)) == 0 and physical.get("response_failures", {}) == {},
		label + ": finite, dissipative actual response readback")
	check(bool(metrics.get("sand_resistance_enabled", not candidate)) == candidate, label + ": explicit response arm")
	check((int(physical.get("response_accepts", 0)) > 0 and float(physical.get("impulse_magnitude_sum", 0.0)) > 0.0)
		if candidate else (int(physical.get("response_accepts", 0)) == 0),
		label + ": candidate applies resistance and baseline does not")
	var refused_responses: int = 0
	for count: int in physical.get("response_refusals", {}).values():
		refused_responses += count
	var failed_responses: int = 0
	for count: int in physical.get("response_failures", {}).values():
		failed_responses += count
	check(int(physical.get("worker_observation_attempts", 0)) >= int(physical.get("observations", 0)) + int(physical.get("refused_observations", 0))
		and float(physical.get("worker_contact_ms_total", 0.0)) >= float(physical.get("geometry_ms_total", 0.0))
		and int(physical.get("response_attempts", -1)) == int(physical.get("response_accepts", 0)) + refused_responses + failed_responses
		and float(physical.get("response_ms_all_attempts", 0.0)) >= float(physical.get("response_ms_total", 0.0)),
		label + ": cost includes every owner attempt and response refusal")
	records.append({"id":label, "surroundings":kind, "candidate":candidate, "repeat":repeat,
		"sand_before":sand_before, "sand_after":sand_after, "water_before":water_before,
		"water_after":water_after, "steps":STEPS, "max_translation":max_translation,
		"max_rotation":max_rotation, "max_angular_velocity":max_omega,
		"metrics":metrics, "displacement":after.get("conservative_displacement", {}), "trace":trace})
	session.close()
	await process_frame

func _run() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="):
			workers = int(argument.trim_prefix("--workers="))
		elif not argument.begins_with("--"):
			output = argument
	check(workers in [1, 4], "registered worker cohort")
	for kind: String in ["packed_sand", "embedded_sand", "mixed"]:
		for repeat: int in range(REPEATS):
			# Alternate order; neither arm's trajectory is treated as matched input.
			for candidate: bool in ([false, true] if repeat % 2 == 0 else [true, false]):
				await _case(kind, candidate, repeat)
	check(records.size() == 18, "all three environments, two policies and three repetitions complete")
	var report := {"schema":"cybersand.sol281.contact-recovery.v1", "platform":OS.get_name(),
		"workers":workers, "checks":checks, "failures":failures, "cases":records,
		"denominator":"geometry observations are unique consumed native publications, not every native tick",
		"scope":"repeated asynchronous conservation/geometry/response; unmatched trajectories and no GPU or human acceptance"}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			check(false, "report output opens")
		else:
			file.store_string(JSON.stringify(report, "\t"))
	print("SOL281_CONTACT_RECOVERY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
