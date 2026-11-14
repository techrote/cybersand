extends SceneTree
## Isolated #570 host: persistent mounted Workbench, existing Art authority only.
## This is a bounded file transport for a local host, never a public service.
const Setup = preload("res://scripts/workbench_setup.gd")
const Plan = preload("res://scripts/art_batch_plan.gd")
const FOCUS := Rect2i(0, 0, 96, 96)
const WORLD := Rect2i(0, 0, 512, 512)
const GUARDS := [Rect2i(40, 40, 8, 8)]
const MAX_OPERATIONS := 16
const MAX_CELLS := 1024
const MAX_EPISODE_CELLS := 4096
const MAX_ACTIONS := 64
const MAX_REQUESTS := 256
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var bench: Control
var editor: Control
var panel: Window
var art: RefCounted
var worker: RefCounted
var directory := ""
var session_id := ""
var fixture := ""
var next_request := 1
var retired := true
var cumulative_changed := 0
var action_count := 0
var active_receipts: Array = []
var capture_receipt := {}
var startup_msec := 0
var parent_pid := 0
var request_deadline := 0.0
var request_id := 0
var fatal := ""
var fixture_catalog := {}

func load_fixture_catalog() -> bool:
	var expected: Variant = JSON.parse_string(OS.get_environment("DRIV3R_FIXTURE_HASHES"))
	if not expected is Dictionary or expected.size() != 3:
		fatal = "Missing frozen fixture catalog identities"; return false
	for family: String in ["direct", "fuzzy", "vector"]:
		var relative := "experiments/driv3r/stage_b/" + family + "_cases.json"
		var path := ProjectSettings.globalize_path("res://../" + relative)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != expected.get(relative):
			fatal = "Fixture catalog identity mismatch"; return false
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 262144:
			fatal = "Fixture catalog size refused"; return false
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not data is Dictionary or data.get("schema") != "driv3r-stage-b-" + family + "-cases-v1" \
			or not data.get("cases") is Array or data.cases.is_empty() or data.cases.size() > 16:
			fatal = "Invalid fixture catalog schema"; return false
		for item: Variant in data.cases:
			if not item is Dictionary or not item.get("fixture") is Dictionary:
				fatal = "Invalid fixture entry"; return false
			var entry: Dictionary = item.fixture
			if not entry.get("id") is String or not entry.id.begins_with("b-" + family + "-") \
				or fixture_catalog.has(entry.id) or not entry.get("edits") is Array or entry.edits.size() > 32:
				fatal = "Invalid fixture identifier or edits"; return false
			var visits := 0
			var normalized: Array = []
			for edit: Variant in entry.edits:
				if not edit is Array or edit.size() != 5:
					fatal = "Invalid fixture rectangle"; return false
				for value: Variant in edit:
					if not integer(value): fatal = "Noninteger fixture"; return false
				if edit[0] < 0 or edit[1] < 0 or edit[2] < 1 or edit[3] < 1 \
					or edit[0] + edit[2] > 96 or edit[1] + edit[3] > 96 or int(edit[4]) not in [28, 58]:
					fatal = "Fixture outside fixed authority"; return false
				visits += int(edit[2] * edit[3])
				normalized.append([int(edit[0]), int(edit[1]), int(edit[2]), int(edit[3]), int(edit[4])])
			if visits > 4096: fatal = "Fixture cell bound exceeded"; return false
			fixture_catalog[entry.id] = normalized
	return true

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	run.call_deferred()

func settled() -> bool:
	var state: Dictionary = worker.art_state()
	var paint: Dictionary = worker.paint_state()
	return not editor.busy() and not art.active and not panel.log_draw and not bool(paint.busy) \
		and not bool(paint.get("receipt_ready", false)) and not bool(paint.get("legacy_busy", false)) \
		and not state.queued and not state.executing and not state.receipt_ready

func ready() -> bool:
	return not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty() and settled()

func cancelled() -> bool:
	return FileAccess.file_exists(directory + "/cancel") \
		or not parent_alive() \
		or Time.get_ticks_msec() - startup_msec > 1800000

func parent_alive() -> bool:
	# Godot's Unix is_process_running only accepts its own children. This
	# Linux-only experiment checks its host's proc entry without spawning a shell.
	return parent_pid > 0 and FileAccess.file_exists("/proc/%d/stat" % parent_pid)

func expire_action() -> void:
	if not retired and (cancelled() or (request_deadline > 0 and Time.get_unix_time_from_system() >= request_deadline)):
		retired = true
		art.stop("DRIV3R host cancellation/deadline")

func until(predicate: Callable, milliseconds: int = 30000, watch_cancel: bool = false) -> bool:
	var deadline := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		if watch_cancel: expire_action()
		if predicate.call(): return true
		if worker != null and worker.has_failed(): break
		await process_frame
	fatal = "Native boundary did not settle before deadline"
	return false

func write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: fatal = "Cannot write RPC evidence"; return false
	file.store_string(JSON.stringify(value))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func material_hash(values: PackedInt32Array) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(values.to_byte_array())
	return digest.finish().hex_encode()

func record_native(receipt: Dictionary) -> void:
	active_receipts.append(receipt.duplicate(true))

func capture() -> PackedInt32Array:
	if not await until(settled): return PackedInt32Array()
	var state: Dictionary = worker.paint_state()
	var admission: Dictionary = worker.paint_queue({"kind":"capture", "region":WORLD,
		"expected_generation":state.generation, "expected_revision":state.revision, "expected_tick":state.tick})
	if admission.get("status") != "queued": fatal = "Native capture refused"; return PackedInt32Array()
	if not await until(func() -> bool: return worker.paint_state().receipt_ready): return PackedInt32Array()
	var receipt: Dictionary = worker.paint_take_result()
	if receipt.get("operation_id") != admission.get("operation_id") or receipt.get("status") != "completed" \
		or receipt.get("backend") != "CyberNativeCellWorld":
		fatal = "Native capture receipt mismatch"; return PackedInt32Array()
	var cells: PackedInt32Array = receipt.materials
	if cells.size() != WORLD.get_area(): fatal = "Incomplete native readback"; return PackedInt32Array()
	capture_receipt = receipt.duplicate(true)
	capture_receipt.erase("materials")
	capture_receipt["materials_i32le_sha256"] = material_hash(cells)
	return cells

func observation(cells: PackedInt32Array, suffix: String = "after") -> Dictionary:
	if cells.size() != WORLD.get_area(): return {}
	var stem := "readback-%06d-%s" % [request_id, suffix]
	var world_file := FileAccess.open(directory + "/" + stem + ".world.i32le", FileAccess.WRITE)
	world_file.store_buffer(cells.to_byte_array()); world_file.close()
	var crop := PackedInt32Array(); crop.resize(96 * 96)
	var picture := Image.create(96, 96, false, Image.FORMAT_RGB8)
	for y: int in 96:
		for x: int in 96:
			var value := cells[y * 512 + x]
			crop[y * 96 + x] = value
			picture.set_pixel(x, y, Color8(232, 226, 205) if value == 58 else \
				(Color8(178, 116, 54) if value == 28 else Color8(13, 21, 28)))
	var crop_file := FileAccess.open(directory + "/" + stem + ".materials.i32le", FileAccess.WRITE)
	crop_file.store_buffer(crop.to_byte_array()); crop_file.close()
	if picture.save_png(directory + "/" + stem + ".png") != OK: fatal = "PNG write failed"
	var state: Dictionary = worker.paint_state()
	return {"world_id":session_id + ":" + str(state.generation), "generation":state.generation,
		"revision":state.revision, "tick":state.tick, "focus":[0, 0, 96, 96],
		"allowed_materials":[58], "protected_rectangles":[[40, 40, 8, 8]], "fixture":fixture,
		"width":96, "height":96, "materials":Array(crop), "material_sha256":material_hash(crop),
		"world_material_sha256":material_hash(cells), "material_path":stem + ".materials.i32le",
		"world_material_path":stem + ".world.i32le", "png_path":stem + ".png",
		"png_sha256":FileAccess.get_sha256(directory + "/" + stem + ".png"),
		"retired":retired, "cumulative_changed_cells":cumulative_changed, "action_count":action_count,
		"capture_receipt":capture_receipt.duplicate(true),
		"image_kind":"native stored-material visualization, not a framebuffer screenshot"}

func reset_fence() -> Dictionary:
	var reason := ""
	var status := "cancelled"
	if cancelled(): reason = "Cancelled before fixture admission or during installation"
	elif request_deadline > 0 and Time.get_unix_time_from_system() >= request_deadline:
		reason = "Fixture request deadline expired"
		status = "refused"
	if reason.is_empty(): return {}
	retired = true
	art.stop(reason)
	return {"status":status, "reason":reason, "reset_admitted":false}

func fresh(name: String) -> Dictionary:
	if not name in ["wall-v1", "fuzzy-v1"] and not fixture_catalog.has(name):
		return {"status":"refused", "reason":"Unknown fixture", "reset_admitted":false}
	if not await until(ready):
		return {"status":"failed", "reason":fatal, "reset_admitted":false}
	var fence := reset_fence()
	if not fence.is_empty(): return fence
	art.stop("DRIV3R explicit new episode")
	var generation: int = worker.paint_state().generation
	var data: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy), Vector2i(512, 512))
	data.edits = fixture_catalog[name].duplicate(true) if fixture_catalog.has(name) else [[8, 8, 1, 57, 28], [28, 24, 6, 8, 28]]
	# Recheck immediately at the actual Workbench admission. Dispatch never
	# clears the cancellation marker; a new marker belongs to this request.
	fence = reset_fence()
	if not fence.is_empty(): return fence
	if not bench.apply(data):
		fatal = "Fixture admission failed: " + str(bench.message)
		return {"status":"failed", "reason":fatal, "reset_admitted":false}
	if not await until(func() -> bool: return ready() and int(worker.paint_state().generation) > generation):
		return {"status":"failed", "reason":fatal, "reset_admitted":true}
	if not host.paused or not editor._undo_stack.is_empty():
		fatal = "New fixture must be paused with clean history"
		return {"status":"failed", "reason":fatal, "reset_admitted":true}
	fixture = name
	cumulative_changed = 0
	action_count = 0
	fence = reset_fence()
	if not fence.is_empty():
		# Installation was already admitted. Return its actual new generation
		# and readback, without claiming cancellation rolled the World back.
		fence["reset_admitted"] = true
		return fence
	retired = false
	return {"status":"completed", "reason":"", "reset_admitted":true}

func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value)

func operation_points(operations: Variant, limit: int) -> Dictionary:
	if not operations is Array or operations.is_empty() or operations.size() > MAX_OPERATIONS:
		return {"error":"Operation count must be 1..16"}
	var points := {}
	var visits := 0
	for op: Variant in operations:
		if not op is Dictionary or op.get("shape") not in ["rectangle", "pixels"]:
			return {"error":"Stage A admits rectangle and pixels only"}
		if not integer(op.get("material")) or op.material != 58:
			return {"error":"Unauthorized material"}
		var pairs: Array = []
		if op.shape == "rectangle":
			if op.size() != 6: return {"error":"Unexpected rectangle fields"}
			for key: String in ["x0", "y0", "x1", "y1"]:
				if not integer(op.get(key)): return {"error":"Coordinates must be integers"}
			if op.x1 < op.x0 or op.y1 < op.y0 or op.x0 < 0 or op.y0 < 0 or op.x1 >= 96 or op.y1 >= 96:
				return {"error":"Out of focus rectangle"}
			var count := int(op.x1 - op.x0 + 1) * int(op.y1 - op.y0 + 1)
			if visits + count > limit: return {"error":"Cell budget exceeded"}
			for y: int in range(int(op.y0), int(op.y1) + 1):
				for x: int in range(int(op.x0), int(op.x1) + 1): pairs.append([x, y])
		else:
			if op.size() != 3 or not op.get("points") is Array or op.points.is_empty() or op.points.size() + visits > limit:
				return {"error":"Invalid or over-budget pixel collection"}
			pairs = op.points
		for pair: Variant in pairs:
			if not pair is Array or pair.size() != 2 or not integer(pair[0]) or not integer(pair[1]) \
				or not FOCUS.has_point(Vector2i(pair[0], pair[1])):
				return {"error":"Out of focus or malformed pixel"}
			points[int(pair[1]) * 512 + int(pair[0])] = true
		visits += pairs.size()
	return {"points":points, "visits":visits, "error":""}

func apply(request: Dictionary, before: PackedInt32Array) -> Dictionary:
	var refusal := ""
	var current: Dictionary = worker.paint_state()
	if retired or cancelled(): refusal = "Episode retired or cancelled"
	elif not host.paused: refusal = "Native World must remain paused"
	elif request.keys().size() != 10: refusal = "Unexpected action request fields"
	elif not request.get("action_id") is String or str(request.action_id).is_empty() or str(request.action_id).length() > 96:
		refusal = "Invalid action ID"
	else:
		for key: String in ["generation", "revision", "tick"]:
			if not integer(request.get("expected_" + key)) or int(request["expected_" + key]) != int(current[key]):
				refusal = "Stale native " + key
	if refusal.is_empty() and (not integer(request.get("cell_budget")) or request.cell_budget < 1 or request.cell_budget > MAX_CELLS):
		refusal = "Cell budget must be 1..1024"
	var planned := {"points":{}, "error":""}
	if refusal.is_empty(): planned = operation_points(request.get("operations"), int(request.cell_budget))
	if refusal.is_empty(): refusal = planned.error
	if refusal.is_empty() and (action_count >= MAX_ACTIONS or cumulative_changed + planned.points.size() > MAX_EPISODE_CELLS):
		refusal = "Episode budget exhausted"
	if refusal.is_empty() and Time.get_unix_time_from_system() >= request_deadline: refusal = "Expired request"
	var expected := before.duplicate()
	var expected_changed := 0
	if refusal.is_empty():
		for index: int in planned.points:
			var point := Vector2i(index % 512, index / 512)
			if expected[index] not in [0, 58] or GUARDS[0].has_point(point): continue
			if expected[index] != 58: expected_changed += 1
			expected[index] = 58
	active_receipts.clear()
	var admission := {"status":"refused", "reason":refusal}
	var terminal := admission.duplicate(true)
	if refusal.is_empty():
		# Check cancellation again immediately at the authority handoff. The model
		# never controls the scope, palette, protection or epoch supplied here.
		expire_action()
		if retired:
			admission = {"status":"refused", "reason":"Cancelled before native admission"}
			terminal = admission.duplicate(true)
		else:
			admission = art.submit(request.operations, FOCUS, GUARDS, [0, 58])
			if admission.get("status") == "queued":
				action_count += 1
				await until(settled, 30000, true)
				terminal = art.result.duplicate(true)
			else: terminal = admission.duplicate(true)
	var after := await capture()
	var changed := 0
	if after.size() == before.size():
		for index: int in after.size():
			if after[index] != before[index]: changed += 1
	cumulative_changed += changed
	var status := str(terminal.get("status", "refused"))
	var prefix_safe := after.size() == before.size()
	if prefix_safe:
		for index: int in after.size():
			if after[index] != before[index] and after[index] != expected[index]: prefix_safe = false
	var reconstructed := before.duplicate()
	var receipt_changed := 0
	var receipts_match := true
	for native: Dictionary in active_receipts:
		if native.get("backend") != "CyberNativeCellWorld": receipts_match = false
		receipt_changed += int(native.get("changed", 0))
		for row: Array in native.get("readback", []):
			if row.size() != 4 or not WORLD.has_point(Vector2i(row[0], row[1])):
				receipts_match = false
				continue
			var index := int(row[1]) * 512 + int(row[0])
			if reconstructed[index] != int(row[2]): receipts_match = false
			reconstructed[index] = int(row[3])
	receipts_match = receipts_match and reconstructed == after and receipt_changed == changed
	var exact := (after == expected if status == "completed" else (after == before if admission.get("status") != "queued" else prefix_safe)) and receipts_match
	if not exact: fatal = "Native material readback differs from exact bounded operation oracle"
	if status == "completed" and changed != int(terminal.get("changed", -1)): fatal = "Native receipt changed-cell count mismatch"
	if not fatal.is_empty(): status = "failed"
	return {"status":status, "reason":str(terminal.get("reason", refusal)), "observation":observation(after),
		"receipt":{"admission":admission, "terminal":terminal, "native_receipts":active_receipts.duplicate(true),
			"expected_changed_cells":expected_changed, "actual_changed_cells":changed,
			"before_world_sha256":material_hash(before), "after_world_sha256":material_hash(after),
			"readback_matches":exact, "receipts_reconstruct_materials":receipts_match,
			"partial_prefix_within_authority":prefix_safe, "action_id":request.get("action_id", "")}}

func dispatch(request: Dictionary) -> Dictionary:
	if request.get("protocol_version") != 1 or request.get("request_id") != request_id \
		or not request.get("kind") is String:
		return {"status":"refused", "reason":"Protocol or request identity mismatch"}
	if not request.get("expires_unix") is float and not request.get("expires_unix") is int:
		return {"status":"refused", "reason":"Missing deadline"}
	request_deadline = float(request.expires_unix)
	if not is_finite(request_deadline) or request_deadline <= Time.get_unix_time_from_system() \
		or request_deadline > Time.get_unix_time_from_system() + 120:
		return {"status":"refused", "reason":"Expired or excessive request deadline"}
	if request.kind == "reset":
		if request.size() != 5 or not request.get("fixture") is String:
			return {"status":"refused", "reason":"Invalid fixture request"}
		var reset := await fresh(str(request.fixture))
		reset["observation"] = observation(await capture())
		return reset
	var before := await capture()
	if before.is_empty(): return {"status":"failed", "reason":fatal}
	observation(before, "before")
	if request.kind == "apply": return await apply(request, before)
	if request.kind in ["stop", "shutdown"]:
		retired = true
		art.stop("DRIV3R explicit host Stop")
		await until(settled)
	elif request.kind != "observe": return {"status":"refused", "reason":"Unknown operation", "observation":observation(before)}
	var after := await capture()
	return {"status":"stopped" if retired else "completed", "reason":"", "observation":observation(after),
		"receipt":{"before_world_sha256":material_hash(before), "after_world_sha256":material_hash(after),
			"actual_changed_cells":0, "readback_matches":before == after}}

func run() -> void:
	directory = OS.get_environment("DRIV3R_NATIVE_DIRECTORY")
	session_id = OS.get_environment("DRIV3R_NATIVE_SESSION")
	parent_pid = int(OS.get_environment("DRIV3R_PARENT_PID"))
	startup_msec = Time.get_ticks_msec()
	if directory.is_empty() or session_id.is_empty(): quit(2); return
	if not load_fixture_catalog(): push_error(fatal); quit(2); return
	set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	bench = host.shared_workbench
	worker = host.simulation_worker
	editor = bench.paint_editor
	panel = bench.art_batches
	art = panel.executor
	art.native_receipt.connect(record_native)
	if not await until(ready, 180000): quit(3); return
	write_json(directory + "/ready.json", {"protocol_version":1, "pid":OS.get_process_id(),
		"session_id":session_id, "godot":Engine.get_version_info().string,
		"harness_sha256":FileAccess.get_sha256(get_script().resource_path),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
		"rapier_sha256":FileAccess.get_sha256("res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"),
		"source_sha":OS.get_environment("DRIV3R_SOURCE_SHA"), "backend":"CyberNativeCellWorld"})
	while fatal.is_empty() and next_request <= MAX_REQUESTS and Time.get_ticks_msec() - startup_msec < 1800000:
		if not parent_alive(): break
		if FileAccess.file_exists(directory + "/cancel"):
			retired = true
			art.stop("DRIV3R out-of-band cancel")
		var path := directory + "/request-%06d.json" % next_request
		if not FileAccess.file_exists(path):
			await process_frame
			continue
		request_id = next_request
		next_request += 1
		var request: Variant = null
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_length() <= 65536: request = JSON.parse_string(file.get_as_text())
		if file != null: file.close()
		var response := {"status":"refused", "reason":"Malformed or oversized request"}
		if request is Dictionary: response = await dispatch(request)
		response["protocol_version"] = 1
		response["request_id"] = request_id
		response["fatal"] = fatal
		write_json(directory + "/response-%06d.json" % request_id, response)
		request_deadline = 0.0
		if request is Dictionary and request.get("kind") == "shutdown": break
	retired = true
	art.stop("DRIV3R session shutdown")
	await until(settled, 5000)
	host.queue_free()
	await process_frame
	await process_frame
	write_json(directory + "/closed.json", {"fatal":fatal, "retired":true, "requests":next_request - 1})
	quit(0 if fatal.is_empty() else 1)
