extends SceneTree

# Actual coordinator + Rapier costs. Native component timers are nested and
# reported separately; their sum is not presented as a frame time. Rendered
# mode measures the ordinary Lab presentation, including real texture uploads.
const Session = preload("res://scripts/object_shard_lab_session.gd")
const CASES: Array[String] = ["empty_lab", "inert_moving", "reacting_one", "reacting_three",
	"perforated", "saturated_output", "dormant_three", "wake_burst_three"]
const COMPONENTS: Array[String] = ["world_ns", "chemistry_ns", "contact_ns", "occupancy_ns",
	"geometry_ns", "terrain_ns", "exchange_ns", "relocation_ns", "discovery_ns", "snapshot_ns"]
var destination: String = ""
var selected: String = ""
var sample_count: int = 1200
var rendered: bool = false
var failures: int = 0
var checks: int = 0
var reports: Array[Dictionary] = []
var lab: Node


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--objectshard-profile="):
			destination = argument.trim_prefix("--objectshard-profile=")
		elif argument.begins_with("--objectshard-profile-case="):
			selected = argument.trim_prefix("--objectshard-profile-case=")
		elif argument.begins_with("--objectshard-profile-ticks="):
			sample_count = int(argument.trim_prefix("--objectshard-profile-ticks="))
		elif argument == "--objectshard-profile-rendered":
			rendered = true
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	_expect(not destination.is_empty() and sample_count >= 60 and sample_count <= 3600,
		"A result path and bounded 60–3600 sample count are required")
	_expect(selected.is_empty() or selected in CASES, "Requested workload exists")
	_expect(not rendered or DisplayServer.get_name() != "headless", "Rendered costs require an actual display")
	_expect(ClassDB.class_exists(&"CyberObjectShardLab"), "Actual ObjectShard extension is available")
	if failures > 0:
		_finish()
		return
	if rendered:
		var scene: PackedScene = load("res://object_shard_lab.tscn")
		lab = scene.instantiate()
		root.add_child(lab)
		current_scene = lab
		await process_frame
	for name: String in CASES:
		if selected.is_empty() or selected == name:
			await _measure(name)
	_finish()


func _measure(name: String) -> void:
	var scenario: int = 0 if name == "empty_lab" else 1
	if name in ["reacting_one", "saturated_output"]:
		scenario = 2
	elif name in ["reacting_three", "dormant_three", "wake_burst_three"]:
		scenario = 4
	var started: int = Time.get_ticks_usec()
	var session = Session.new() if not rendered else lab.session
	var opened: Dictionary = session.open(scenario, 12)
	_expect(opened.get("ok", false), name + ": real Lab opens")
	if not opened.get("ok", false):
		return
	var construction_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	if name in ["dormant_three", "wake_burst_three"]:
		_clear_starting_burn(session)
	if name == "perforated":
		_perforate(session)
	if scenario != 0:
		_erase_support(session)
		for tick: int in range(30):
			session.advance(true)
			if session.failed or session.bridge.bodies.size() == (3 if scenario == 4 else 1):
				break
		_expect(not session.failed and session.bridge.bodies.size() == (3 if scenario == 4 else 1), name + ": actual promotion succeeds")
	var setup_usec: int = Time.get_ticks_usec() - started
	# Settle fixtures without adding a body velocity or skipping a native tick.
	for tick: int in range(90):
		session.advance(true)
		if session.failed:
			break
	if name == "saturated_output" and not session.failed:
		started = Time.get_ticks_usec()
		_block_destinations(session)
		setup_usec += Time.get_ticks_usec() - started
	if name == "wake_burst_three" and not session.failed:
		for shard: Dictionary in session.frame.shards:
			var cell: int = _surface_wood(shard)
			_expect(cell >= 0 and session.native.ignite_shard(int(shard.id), int(shard.generation), cell).get("ok", false),
				name + ": real shard Wood ignition accepted")
		session._refresh()
	_expect(not session.failed, name + ": construction and warm-up remain operational")
	var before: Dictionary = session.frame.metrics.duplicate(true)
	var series: Dictionary = {}
	var rows: Array[Dictionary] = []
	var max_shapes: int = 0
	var max_products: int = 0
	var first_present: int = 0
	var max_accounted_bytes: int = 0
	for tick: int in range(sample_count):
		if session.failed:
			break
		var previous: Dictionary = session.frame.metrics.duplicate(true)
		var wall_start: int = Time.get_ticks_usec()
		session.advance(true)
		if session.failed:
			break
		var row: Dictionary = session.samples[-1].duplicate(true)
		for component: String in COMPONENTS:
			row["native_" + component.trim_suffix("_ns") + "_usec"] = float(int(session.frame.metrics.get(component, 0)) - int(previous.get(component, 0))) / 1000.0
		row["pose_copy_usec"] = int(session.bridge.timings.pose_copy_usec)
		if rendered:
			lab._present()
			row["presentation_submit_usec"] = int(lab.last_presentation_usec)
			row["render_upload_submit_usec"] = int(lab.canvas.upload_usec)
			await process_frame
			await RenderingServer.frame_post_draw
			var presented: int = Time.get_ticks_usec()
			row["frame_through_draw_usec"] = presented - wall_start
			if first_present != 0:
				row["present_interval_usec"] = presented - first_present
			first_present = presented
		elif tick % 60 == 0:
			await process_frame
		var product_count: int = 0
		for shard: Dictionary in session.frame.shards:
			max_shapes = maxi(max_shapes, shard.rectangles.size() / 4)
			product_count += int(shard.products)
		max_products = maxi(max_products, product_count)
		max_accounted_bytes = maxi(max_accounted_bytes, int(session.frame.metrics.get("live_bytes", 0)))
		for key: String in row:
			if key.ends_with("_usec"):
				if not series.has(key):
					series[key] = []
				series[key].append(float(row[key]))
		rows.append(row)
	_expect(not session.failed and rows.size() == sample_count, name + ": all measured semantic/physics frames complete")
	if name == "perforated":
		_expect(max_shapes > 8, "Perforated profile really exercises more than eight exact shapes")
	if name == "saturated_output":
		_expect(int(session.frame.metrics.get("output_blocked", 0)) > int(before.get("output_blocked", 0)), "Blocked destinations retain real product attempts")
	if name in ["reacting_one", "reacting_three", "wake_burst_three"]:
		_expect(int(session.frame.metrics.get("products_created", 0)) > 0, name + ": actual native products exist")
	var statistics: Dictionary = {}
	for key: String in series:
		statistics[key] = _percentiles(series[key])
	var report: Dictionary = session.export_result()
	report["name"] = name
	report["construction_usec"] = construction_usec
	report["setup_edits_and_promotion_usec"] = setup_usec
	report["timings"] = statistics
	report["maximum_shapes_per_body"] = max_shapes
	report["maximum_retained_products"] = max_products
	report["maximum_accounted_native_bytes"] = max_accounted_bytes
	report["profile_samples"] = rows
	report.erase("samples")
	reports.append(report)
	print(JSON.stringify({"profile_case": name, "samples": rows.size(), "failed": session.failed,
		"frame_usec": statistics.get("frame_usec", {}), "construction_usec": construction_usec}))
	if not rendered:
		session.close()
	await process_frame


func _percentiles(values: Array) -> Dictionary:
	if values.is_empty():
		return {"samples": 0}
	var sorted: Array = values.duplicate()
	sorted.sort()
	var result: Dictionary = {"samples": sorted.size(), "max": sorted[-1]}
	for pair: Array in [["p50", 0.50], ["p95", 0.95], ["p99", 0.99]]:
		result[pair[0]] = sorted[clampi(ceili(float(sorted.size()) * float(pair[1])) - 1, 0, sorted.size() - 1)]
	return result


func _erase_support(session: CyberObjectShardLabSession) -> void:
	var cells: PackedByteArray = session.frame.world_materials
	var width: int = int(session.frame.width)
	var bottom: int = -1
	for y: int in range(int(session.frame.height) - 1, -1, -1):
		for x: int in range(width):
			if int(cells[y * width + x]) == 7:
				bottom = y
				break
		if bottom >= 0:
			break
	for y: int in range(maxi(0, bottom - 11), bottom + 1):
		for x: int in range(width):
			if int(cells[y * width + x]) == 7:
				_expect(session.edit(Vector2i(x, y), 0).get("ok", false), "Ordinary support edit succeeds")


func _clear_starting_burn(session: CyberObjectShardLabSession) -> void:
	var cells: PackedByteArray = session.frame.world_materials
	var width: int = int(session.frame.width)
	for index: int in range(cells.size()):
		if int(cells[index]) == 7:
			var point := Vector2i(index % width, index / width)
			var value: Dictionary = session.native.inspect(point)
			if int(value.state_b) > 0:
				_expect(session.edit(point, 7, int(value.state_a), 0, 200).get("ok", false), "Dormant fixture uses ordinary exact-payload editing")


func _perforate(session: CyberObjectShardLabSession) -> void:
	var cells: PackedByteArray = session.frame.world_materials
	var width: int = int(session.frame.width)
	for y: int in range(2, int(session.frame.height) - 2, 3):
		for x: int in range(2, width - 2, 3):
			var index: int = y * width + x
			if cells[index] == 7 and cells[index - 1] == 7 and cells[index + 1] == 7 and cells[index - width] == 7 and cells[index + width] == 7:
				_expect(session.edit(Vector2i(x, y), 0).get("ok", false), "Ordinary perforation edit succeeds")


func _surface_wood(shard: Dictionary) -> int:
	var width: int = int(shard.width)
	for index: int in range(shard.materials.size()):
		if int(shard.materials[index]) != 7:
			continue
		if index < width or index >= shard.materials.size() - width or index % width == 0 or index % width == width - 1:
			return index
		for neighbor: int in [index - 1, index + 1, index - width, index + width]:
			if int(shard.materials[neighbor]) == 0:
				return index
	return -1


func _block_destinations(session: CyberObjectShardLabSession) -> void:
	# A real World wall enclosure blocks destinations. Failed writes against the
	# actual moving occupancy are expected refusals and never edit shard payload.
	for shard: Dictionary in session.frame.shards:
		if not session.bridge.bodies.has(int(shard.id)):
			continue
		var rid: RID = session.bridge.bodies[int(shard.id)].rid
		PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, true)
		var pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var bounds := Rect2(pose.origin, Vector2.ZERO)
		for corner: Vector2 in [Vector2.ZERO, Vector2(shard.width, 0), Vector2(0, shard.height), Vector2(shard.width, shard.height)]:
			bounds = bounds.expand(pose * corner)
		bounds = bounds.grow(3.0)
		for y: int in range(maxi(0, floori(bounds.position.y)), mini(int(session.frame.height), ceili(bounds.end.y))):
			for x: int in range(maxi(0, floori(bounds.position.x)), mini(int(session.frame.width), ceili(bounds.end.x))):
				if int(session.native.inspect(Vector2i(x, y)).material) == 0:
					session.edit(Vector2i(x, y), 1)


func _finish() -> void:
	var report: Dictionary = {"schema": "objectshard-lab-profile-v1", "checks": checks, "failures": failures,
		"engine": Engine.get_version_info(), "platform": OS.get_name(), "display": DisplayServer.get_name(),
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"), "requested_samples": sample_count,
		"rendered": rendered, "cases": reports,
		"timing_scope": "Frame owner-thread elapsed time excludes presentation unless separately reported and includes host preemption. Occupancy includes contact/relocation. Upload and presentation measure submission elapsed time; frame_through_draw includes frame scheduling and actual draw completion, not GPU-only time.",
		"memory_scope": "Native counters are an accounted lower bound; separate native allocator experiment measures C++ construction/steady allocations. Godot/Rapier/GPU allocation churn is not measured here.",
		"physical_owner_acceptance": "Not established by automated profiling"}
	if not destination.is_empty():
		var output: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
		if output == null:
			failures += 1
		else:
			output.store_string(JSON.stringify(report, "  ") + "\n")
			output.close()
	print(JSON.stringify({"schema": report.schema, "checks": checks, "failures": failures,
		"cases": reports.size(), "rendered": rendered, "destination": destination}))
	if lab != null:
		lab.session.close()
	quit(failures)
