extends SceneTree

# Exact compound occupancy and existing cellular coupling. The detached object is
# one Rapier body, while each non-overlapping native rectangle is published as a
# stable proxy to the existing rectangular sweep/displacement kernel.
const Session = preload("res://scripts/solid_detachment_session.gd")
var checks: int = 0
var failures: Array[String] = []
var session: RefCounted

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL SOL281 COUPLING ", message)

func _points_line(x: int, first_y: int, count: int) -> PackedInt32Array:
	var points := PackedInt32Array()
	for y: int in range(first_y, first_y + count):
		points.append(x)
		points.append(y)
	return points

func _points_rect(origin: Vector2i, size: Vector2i) -> PackedInt32Array:
	var points := PackedInt32Array()
	for y: int in range(origin.y, origin.y + size.y):
		for x: int in range(origin.x, origin.x + size.x):
			points.append(x)
			points.append(y)
	return points

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var policy_args: PackedStringArray = OS.get_cmdline_user_args()
	var ejection_policy: int = int(policy_args[1]) if policy_args.size() > 1 else 0
	session = Session.new()
	if not await session.open(root, 4, ejection_policy, true):
		check(false, session.last_error)
		session.close()
		quit(1)
		return
	if not await session.cut_and_release():
		check(false, session.last_error)
		session.close()
		quit(1)
		return
	# The manual Rapier space advances only through session.physics_step(). Hold
	# both clocks while checking the exact initial occupancy.
	session.set_paused(true)
	var source: Dictionary = session.source_receipt
	var metrics: Dictionary = session.coupling_metrics()
	check(metrics.proxy_count == int(source.shape_count), "one stable native proxy per exact compound rectangle")
	check(absf(float(metrics.proxy_mass) - float(source.member_count)) < 0.01,
		"proxy union area equals exact aggregate payload")
	check(int(metrics.state_publications) >= 1, "compound mask was primed before motion")

	var probes := PackedInt32Array([51, 32, 60, 32, 68, 50, 50, 50])
	var initial: Dictionary = await session.inspect_coupling(probes)
	check(initial.get("ok", false), "exclusive owner publishes coupling inspection")
	var ids: PackedInt32Array = initial.get("probe_body_ids", PackedInt32Array())
	var visible: PackedInt32Array = initial.get("probe_materials", PackedInt32Array())
	check(ids.size() == 4 and visible.size() == 4, "four exact occupancy probes returned")
	if ids.size() == 4:
		check(ids[0] > 0 and ids[3] > 0, "crown and trunk cells are occupied by compound proxies")
		check(ids[1] == 0, "the authored one-cell crown hole remains open")
		check(ids[2] == 0, "large empty area inside aggregate AABB is not falsely filled")
	if visible.size() == 4:
		check(visible[0] == 1 and visible[3] == 1, "occupied proxy cells read as transient hard obstacles")
		check(visible[1] == 0 and visible[2] == 0, "compound holes remain visible as empty native space")
	var before: Dictionary = initial.get("diagnostic_snapshot", {})
	var before_counts: Array = before.get("counts", [])
	check(before_counts.size() > session.WATER and int(before_counts[session.SAND]) == 0
		and int(before_counts[session.WATER]) == 0, "fixture starts without Sand or Water")

	# Sand falls onto the crown. Water starts in the empty right-hand region that
	# lies inside the tree's overall AABB; a filled-box approximation would mask it.
	check(session.emit_cells(_points_line(48, 21, 4), session.SAND), "Sand batch admitted")
	check(session.emit_cells(_points_line(68, 42, 4), session.WATER), "Water batch admitted in open AABB interior")
	check(await session.wait_native_ticks(120, 15000), "120 native material ticks complete without stepping Rapier")
	var settled: Dictionary = await session.inspect_coupling(probes)
	var material: Dictionary = settled.get("diagnostic_snapshot", {})
	var counts: Array = material.get("counts", [])
	var sum_y: Array = material.get("sum_y", [])
	check(counts.size() > session.WATER and sum_y.size() > session.WATER, "complete material census copied")
	var sand_count: int = int(counts[session.SAND]) if counts.size() > session.SAND else -1
	var water_count: int = int(counts[session.WATER]) if counts.size() > session.WATER else -1
	var sand_average_y: float = float(sum_y[session.SAND]) / maxf(float(sand_count), 1.0) if sand_count > 0 else -1.0
	var water_average_y: float = float(sum_y[session.WATER]) / maxf(float(water_count), 1.0) if water_count > 0 else -1.0
	check(sand_count == 4, "Sand quantity remains exact")
	check(int(material.get("water_mass", -1)) == 4 * 255, "Water mass remains exact")
	check(sand_average_y < 31.0, "Sand is supported by the real crown silhouette")
	check(water_average_y > 55.0, "Water falls through the open region inside the bounding box")
	var settled_ids: PackedInt32Array = settled.get("probe_body_ids", PackedInt32Array())
	check(settled_ids.size() == 4 and settled_ids[1] == 0 and settled_ids[2] == 0,
		"static material ticks do not fill compound holes")

	# Place a settled granular bank in the expected fall path, then run both
	# independent clocks. Sweep samples must move the exact proxy union, not its AABB.
	var bank: PackedInt32Array = _points_rect(Vector2i(76, 60), Vector2i(10, 10))
	check(session.emit_cells(bank, session.SAND), "granular sweep bank admitted")
	check(await session.wait_native_ticks(30, 10000), "granular bank settles before body motion")
	session.set_paused(false)
	var initial_transform: Transform2D = session.body_transform()
	var max_rotation: float = 0.0
	var max_translation: float = 0.0
	var main_step_us: Array[int] = []
	var frame_intervals_us: Array[int] = []
	var previous_frame_us: int = Time.get_ticks_usec()
	for _tick: int in range(360):
		await physics_frame
		var started_us: int = Time.get_ticks_usec()
		frame_intervals_us.append(started_us - previous_frame_us)
		previous_frame_us = started_us
		session.physics_step()
		main_step_us.append(Time.get_ticks_usec() - started_us)
		var transform: Transform2D = session.body_transform()
		max_rotation = maxf(max_rotation, absf(transform.get_rotation()))
		max_translation = maxf(max_translation, transform.origin.distance_to(initial_transform.origin))
	var final: Dictionary = await session.inspect_coupling(PackedInt32Array())
	var final_material: Dictionary = final.get("diagnostic_snapshot", {})
	var final_counts: Array = final_material.get("counts", [])
	metrics = session.coupling_metrics()
	check(int(metrics.state_publications) > 100, "moving compound states published repeatedly")
	check(int(metrics.result_snapshots) > 0 and int(metrics.result_records) > 0,
		"native cellular owner returned compound proxy results")
	check(int(metrics.contacts) > 0, "moving exact silhouette contacts cellular material")
	check(int(metrics.displaced) > 0, "swept compound silhouette displaces cellular material")
	var classified_unresolved: int = int(metrics.unresolved_immovable) \
		+ int(metrics.unresolved_no_target) + int(metrics.unresolved_relocation_refused)
	check(classified_unresolved == int(metrics.unresolved)
		and int(metrics.unresolved_unclassified) == 0,
		"every unresolved overlap has one explicit native cause")
	check(int(metrics.unresolved_immovable) == 0,
		"Sand/Water fixture reports no immovable-material refusal")
	check(int(metrics.unresolved_relocation_refused) == 0,
		"admitted ejection targets never fail authoritative relocation")
	check(int(metrics.unresolved_no_target) == int(metrics.unresolved)
		and (ejection_policy == 1 or int(metrics.unresolved_no_target) > 0),
		"dense-bank unresolved interactions, if any, are exhausted ejection searches")
	check(int(metrics.proxy_count) == int(source.shape_count), "proxy topology remains stable through rotation")
	check(max_rotation > 0.5 and max_translation > 5.0, "actual Rapier body still topples while coupled")
	check(final.get("aggregate_owned") == source.member_count and final.get("native_source_members") == 0,
		"material ownership remains exclusively aggregate-held")
	check(not final.get("worker_failed", true), "compound coupling does not fail the native owner")
	check(final_counts.size() > session.WATER and int(final_counts[session.SAND]) == 104,
		"Sand count conserved through swept displacement")
	check(int(final_material.get("water_mass", -1)) == 4 * 255,
		"Water mass conserved through moving compound coupling")

	# Native owner census sees all failed searches, but the latest-only
	# snapshots below observe only accepted asynchronous result records.
	var topology: Dictionary = final.get("ejection_topology", {})
	check(bool(topology.get("enabled", false)), "explicit topology census enabled")
	check(int(topology.get("radius", -1)) == 8
		and int(topology.get("per_sample_capacity", -1)) == 16,
		"bounded local square and per-owner preparation scan limit")
	var classified: int = int(topology.get("classified", -1))
	var no_target_events: int = int(topology.get("no_target_events", -1))
	check(no_target_events == classified + int(topology.get("skipped_capacity", -1)),
		"all attempted no-targets are either classified or capped")
	check(classified == int(topology.get("off_axis_direct_path", -1))
		+ int(topology.get("nearby_void_path_blocked", -1))
		+ int(topology.get("no_nearby_unmasked_void", -1))
		and classified == int(topology.get("empty_connected_forward", -1))
		+ int(topology.get("empty_connected_lateral", -1))
		+ int(topology.get("empty_connected_rear", -1))
		+ int(topology.get("empty_connected_none", -1))
		and int(topology.get("weak_direct_without_empty_route", -1))
		<= int(topology.get("empty_connected_none", -1)),
		"weak and strict empty-route partitions remain complete and bounded")
	check(classified > 0, "dense bank creates bounded inspected failures")
	var worker_timing: Dictionary = metrics.get("worker_step_timing", {})
	check(int(worker_timing.get("samples", 0)) > 0, "worker step timing observed")
	check(float(worker_timing.get("p95_ms", -1.0)) >= 0.0, "worker p95 observed")
	check(int(metrics.get("worker_overruns", -1)) >= 0, "worker overrun counter read")
	check(frame_intervals_us.size() == 360, "all physics-frame intervals recorded")
	var displacement_attempts: int = int(metrics.displaced) + int(metrics.unresolved)
	var unresolved_rate: float = float(metrics.unresolved) / maxf(float(displacement_attempts), 1.0)
	main_step_us.sort()
	var sample_count: int = main_step_us.size()
	var timing: Dictionary = {
		"samples":sample_count, "total_usec":0, "p50_usec":-1,
		"p95_usec":-1, "p99_usec":-1, "max_usec":-1
	}
	if sample_count > 0:
		var sum_us: int = 0
		for value: int in main_step_us:
			sum_us += value
		timing.total_usec = sum_us
		timing.p50_usec = main_step_us[int(floor(float(sample_count - 1) * 0.50))]
		timing.p95_usec = main_step_us[int(ceil(float(sample_count - 1) * 0.95))]
		timing.p99_usec = main_step_us[int(ceil(float(sample_count - 1) * 0.99))]
		timing.max_usec = main_step_us[sample_count - 1]
	frame_intervals_us.sort()
	var frame_pacing: Dictionary = {"samples":frame_intervals_us.size(),
		"p50_usec":-1, "p95_usec":-1, "p99_usec":-1, "max_usec":-1,
		"over_16667_usec":0}
	if not frame_intervals_us.is_empty():
		var count: int = frame_intervals_us.size()
		frame_pacing.p50_usec = frame_intervals_us[int(floor(float(count - 1) * 0.50))]
		frame_pacing.p95_usec = frame_intervals_us[int(ceil(float(count - 1) * 0.95))]
		frame_pacing.p99_usec = frame_intervals_us[int(ceil(float(count - 1) * 0.99))]
		frame_pacing.max_usec = frame_intervals_us.back()
		for interval_us: int in frame_intervals_us:
			if interval_us > 16667:
				frame_pacing.over_16667_usec += 1
	var report: Dictionary = {
		"schema":"cybersand.sol281.compound-cellular-coupling.v3",
		"ejection_policy":ejection_policy, "main_thread_step_timing":timing,
		"headless_physics_frame_pacing":frame_pacing, "ejection_topology":topology,
		"checks":checks, "failures":failures, "platform":OS.get_name(),
		"members":source.member_count, "shapes":source.shape_count,
		"initial_body_ids":ids, "sand_average_y":sand_average_y,
		"water_average_y":water_average_y, "max_rotation":max_rotation,
		"max_translation":max_translation, "coupling":metrics,
		"displacement_attempts":displacement_attempts, "unresolved_rate":unresolved_rate,
		"scope":"one dry homogeneous aggregate; exact compound proxy occupancy/sweep with Sand and Water; no reactive Wood or dynamic desoliding"
	}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("SOL281_COMPOUND_COUPLING ", JSON.stringify(report))
	session.close()
	await process_frame
	session = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
