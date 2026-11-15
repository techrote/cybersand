extends SceneTree

## CAMERA-STACK-RECON-001: real mounted Workbench -> native owner -> immutable
## publication -> Main recorder -> threaded BMP/IDs/JSON output. This is state
## evidence decoding, not simulation replay or a visual-smoothness acceptance.
const Setup = preload("res://scripts/workbench_setup.gd")
const Recorder = preload("res://scripts/gameplay_recorder.gd")
const VIEW := Vector2i(128,96)
const TIMEOUT_MS := 60000
var host: Control
var bench: Control
var editor: Control
var worker: RefCounted
var checks := 0
var failures: Array[String] = []
var observed: Dictionary = {}
var witnesses: Array[Dictionary] = []
var source_identity: Dictionary = {}
var runtime_identity: Dictionary = {}
var session_path := ""
var initial_roi: Rect2i
var final_status: Dictionary = {}
var completed := false


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	Engine.max_fps = 60
	process_frame.connect(_observe_snapshot)
	_run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CAMERA_STACK_RECORDING: " + label)
	return ok


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if worker != null and worker.has_failed(): break
		if host != null and host.gameplay_recorder.has_failed(): break
		await process_frame
	return check(false,label)


func ready() -> bool:
	if bench == null or editor == null or worker == null: return false
	var paint: Dictionary = worker.paint_state()
	return not bench.applied.is_empty() and not bench.busy() and not editor.busy() \
		and host.pending_microscenario_apply.is_empty() and not bool(paint.get("busy",false)) \
		and not bool(paint.get("receipt_ready",false)) and not bool(paint.get("legacy_busy",false))


func identity() -> Dictionary:
	var result := {"os":OS.get_name(),"godot":Engine.get_version_info().string,
		"display":DisplayServer.get_name(),"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION")}
	for path: String in ["scripts/main.gd","scripts/shared_workbench.gd","scripts/simulation_worker.gd",
		"scripts/gameplay_recorder.gd","scripts/pixel_camera_transform.gd","tests/test_camera_stack_recording.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	var native_name := "cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so"
	result.native_sha256 = FileAccess.get_sha256("res://addons/cybersand_native/bin/" + native_name)
	return result


func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _observe_snapshot() -> void:
	if host == null or not is_instance_valid(host) or host.latest_snapshot == null: return
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	if not host.gameplay_recorder.is_active(): return
	observed[snapshot.serial] = {"render_serial":snapshot.render_snapshot_serial,
		"tick":snapshot.tick_index,"render_tick":snapshot.render_tick_index,
		"world_revision":snapshot.world_revision,"simulation_world_revision":snapshot.simulation_world_revision,
		"render_usec":snapshot.render_generated_usec,"published_usec":snapshot.published_usec,
		"backend":snapshot.backend_name,"full_refresh":snapshot.render_full_refresh,
		"patch_metadata_values":snapshot.render_patch_rectangles.size(),"patch_bytes":snapshot.render_patch_cells.size()}


func readback(region: Rect2i, label: String) -> PackedByteArray:
	if not await until(ready,"authoring settled before " + label): return PackedByteArray()
	var state: Dictionary = worker.paint_state()
	var admitted: Dictionary = worker.paint_queue({"kind":"capture","region":region,
		"expected_generation":int(state.generation),"expected_revision":int(state.revision),
		"expected_tick":int(state.tick),"expected_authoring_generation":int(state.get("authoring_generation",1))})
	if not check(admitted.get("status")=="queued","native ROI readback admitted: " + label): return PackedByteArray()
	if not await until(func() -> bool: return bool(worker.paint_state().receipt_ready),"native readback receipt: " + label): return PackedByteArray()
	var receipt: Dictionary = worker.paint_take_result()
	if not check(receipt.get("status")=="completed" and receipt.get("operation_id")==admitted.operation_id \
		and receipt.get("backend")=="CyberNativeCellWorld","independent native readback completed: " + label): return PackedByteArray()
	var materials: PackedInt32Array = receipt.get("materials",PackedInt32Array())
	if not check(materials.size()==region.get_area(),"native readback covers every ROI cell: " + label): return PackedByteArray()
	var ids := PackedByteArray()
	ids.resize(materials.size())
	for index: int in range(materials.size()): ids[index] = materials[index]
	witnesses.append({"label":label,"sha256":digest(ids),"bytes":ids.size(),
		"generation":receipt.generation,"revision":receipt.revision,"tick":receipt.tick,
		"backend":receipt.backend,"operation_id":receipt.operation_id})
	return ids


func edit(cells: PackedInt32Array, label: String) -> bool:
	if not check(editor.commit_cells(cells,label),"real PAINT operation admitted: " + label): return false
	return await until(ready,"native PAINT operation settled: " + label) \
		and check(editor.last_receipt.get("status")=="completed","real PAINT operation completed: " + label)


func latest_frame_matches(expected: PackedByteArray) -> bool:
	var index := int(host.gameplay_recorder.status().written_frames)
	if index < 1: return false
	return FileAccess.get_file_as_bytes(session_path.path_join("frame-%06d.ids" % index)) == expected


func bitmap_matches(path: String, expected: PackedByteArray) -> bool:
	# Godot's independent image decoder checks BMP palette and bottom-up rows.
	var decoded := Image.load_from_file(path)
	if decoded == null or decoded.get_size()!=initial_roi.size or expected.size()!=initial_roi.get_area(): return false
	for y: int in range(initial_roi.size.y):
		for x: int in range(initial_roi.size.x):
			var material := int(expected[y*initial_roi.size.x+x])
			var color: Color = Color.hex(CyberMaterialAppearanceLut.BASE_RGBA8[material])
			var actual: Color = decoded.get_pixel(x,y)
			if actual.r8!=color.r8 or actual.g8!=color.g8 or actual.b8!=color.b8: return false
	return true


func read_json(path: String) -> Dictionary:
	if not check(FileAccess.file_exists(path),"written JSON exists: " + path.get_file()): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(parsed is Dictionary,"written JSON decodes: " + path.get_file()): return {}
	return parsed


func json_integers_equal(values: Variant, expected: Array) -> bool:
	# JSON numbers decode as floats. Compare their exact numeric values without
	# truncating a malformed fractional extent or coordinate to an integer.
	if not values is Array or values.size()!=expected.size(): return false
	for index: int in range(expected.size()):
		if not (values[index] is float or values[index] is int) or float(values[index])!=float(expected[index]): return false
	return true


func qualify() -> void:
	if not await until(ready,"mounted native Workbench is ready"): return
	var fresh: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	if not check(bench.apply(fresh),"bounded empty native fixture admitted"): return
	if not await until(ready,"native 512-square fixture installed"): return
	check(bool(worker.paint_state().paused) and fresh.actors.is_empty(),"paused terrain fixture has no authored actor overlay")
	bench._camera.select(0)
	host.camera_follow_enabled = false
	bench._set_view(Vector2(63.25,31.75),VIEW)
	await process_frame
	await process_frame
	var presented: Vector2 = host.presentation_camera_origin()
	check(absf(presented.x-roundf(presented.x))>0.001 and absf(presented.y-roundf(presented.y))>0.001,
		"mounted camera presents fractional origins on both axes")
	var config: Dictionary = host.recording_configuration()
	initial_roi = config.roi
	check(initial_roi==Rect2i(Vector2i(presented.floor()),VIEW+Vector2i.ONE),
		"Main admits every partially visible right and bottom edge cell")
	var first := initial_roi.position
	var last := initial_roi.end-Vector2i.ONE
	if not await edit(PackedInt32Array([first.x,first.y,58,last.x,first.y,28,
		first.x,last.y,35,last.x,last.y,131]),"recording edge witnesses"): return
	var before: PackedByteArray = await readback(initial_roi,"before")
	if before.is_empty(): return
	check(before[0]==58 and before[initial_roi.size.x-1]==28 and before[before.size()-initial_roi.size.x]==35 \
		and before[before.size()-1]==131,"native readback contains the four distinct partially visible edge witnesses")
	runtime_identity = host.recording_runtime_identity()
	config.output_root = OS.get_environment("CAMERA_STACK_RECORDING_OUTPUT")
	if str(config.output_root).is_empty(): config.output_root = "user://camera-stack-recording-regression"
	config.session_name = "camera-stack-native-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	# Use the existing admission API solely to direct retained artifacts. Main
	# remains the only snapshot feeder, exactly as for the interactive recorder.
	if not check(host.gameplay_recorder.start_recording(config,runtime_identity)==OK,"real threaded recorder starts"): return
	session_path = host.gameplay_recorder.session_path()
	worker.request_render_full_refresh()
	if not await until(func() -> bool: return latest_frame_matches(before),"actual native publication reaches the first disk frame"): return
	check(bool(host.gameplay_recorder.status().primed),"full native publication primes recording")
	var first_path := session_path.path_join("frame-000001.ids")
	check(FileAccess.get_file_as_bytes(first_path)==before,"initial raw frame equals independent native readback for the entire ROI")
	check(bitmap_matches(session_path.path_join("frame-000001.bmp"),before),"initial BMP decodes to native palette colors, dimensions and row orientation")
	bench._set_view(host.camera_origin+Vector2(25.5,15.5),VIEW)
	await process_frame
	check(host.recording_configuration().roi!=initial_roi,"camera pan changes a newly requested recording ROI")
	check(host.gameplay_recorder._roi==initial_roi,"active recording retains its initial world ROI across camera pan")
	if not await edit(PackedInt32Array([last.x,last.y,58]),"recording corner delta after camera pan"): return
	var after: PackedByteArray = await readback(initial_roi,"after")
	if after.is_empty(): return
	var expected := before.duplicate()
	expected[expected.size()-1] = 58
	check(after==expected,"native authority changes only the requested original-ROI corner")
	if not await until(func() -> bool: return latest_frame_matches(after),"native corner delta reaches a later disk frame"): return
	await process_frame
	_observe_snapshot()
	host.toggle_gameplay_recording()
	if not await until(func() -> bool: return not host.gameplay_recorder.is_active(),"interactive stop finalizes the threaded writer"): return
	final_status = host.gameplay_recorder.poll_finalization()
	check(not final_status.failed and not final_status.accepting and int(final_status.queued_frames)==0,
		"finalization releases the queue without failure")
	check(int(final_status.written_frames)>=2 and int(final_status.dropped_frames)==0,"bounded two-state recording preserves frames without drops")
	check(FileAccess.get_file_as_bytes(first_path)==before,"later native edit leaves the first recorded frame immutable")
	var count := int(final_status.written_frames)
	var final_base := session_path.path_join("frame-%06d" % count)
	check(FileAccess.get_file_as_bytes(final_base+".ids")==after,"final raw frame equals the complete updated native ROI")
	check(bitmap_matches(final_base+".bmp",after),"final BMP independently decodes the updated native material plane")
	check(not bitmap_matches(session_path.path_join("frame-000001.bmp"),after),"negative control detects the stale pre-edit bitmap")
	var manifest := read_json(session_path.path_join("recording.json"))
	if manifest.is_empty(): return
	check(manifest.get("disposition")=="complete" and not bool(manifest.get("failure",true)),"manifest finalizes as complete")
	check(manifest.get("evidence_kind")==Recorder.EVIDENCE_KIND and str(manifest.get("state_scope",{}).get("replay","")).contains("not an exact replay"),
		"recording truthfully labels state evidence rather than exact replay")
	var roi_array := [initial_roi.position.x,initial_roi.position.y,initial_roi.size.x,initial_roi.size.y]
	check(json_integers_equal(manifest.get("configuration",{}).get("roi"),roi_array) \
		and json_integers_equal(manifest.get("configuration",{}).get("world_extent"),[512,512]),
		"final manifest retains admitted ROI and native extent")
	check(int(manifest.get("counters",{}).get("written_frames",-1))==count,"manifest and finalized writer count agree")
	check(manifest.get("identity",{}).get("source",{}).get("native_sha256")==source_identity.native_sha256,
		"manifest records the actual native library hash")
	var previous_serial := -1
	for index: int in range(1,count+1):
		var base := "frame-%06d" % index
		var frame := read_json(session_path.path_join(base+".json"))
		if frame.is_empty(): return
		check(int(frame.get("frame_index",-1))==index and frame.get("material_ids_file")==base+".ids" \
			and frame.get("review_bitmap_file")==base+".bmp","frame metadata owns its matching raw and bitmap files")
		check(json_integers_equal(frame.get("recording_roi"),roi_array) \
			and json_integers_equal(frame.get("recording_configuration",{}).get("roi"),roi_array),
			"every frame retains the initial camera-derived ROI")
		var serial := int(frame.get("snapshot_serial",-1))
		check(serial>=previous_serial and observed.has(serial),"recorded frame identifies an actual consumed native snapshot")
		if not observed.has(serial): return
		var actual: Dictionary = observed[serial]
		check(int(frame.get("render_snapshot_serial",-1))==int(actual.render_serial) \
			and int(frame.get("completed_simulation_tick",-1))==int(actual.tick) \
			and int(frame.get("material_generation",{}).get("completed_simulation_tick",-1))==int(actual.render_tick) \
			and int(frame.get("consumer_snapshot_published_monotonic_usec",-1))==int(actual.published_usec) \
			and int(frame.get("world_revision",-1))==int(actual.world_revision) \
			and frame.get("backend")==actual.backend,"frame generations, timing and backend match the real native receipt")
		check(frame.get("session_identity",{}).get("source_revision")==runtime_identity.source.source_revision \
			and frame.get("session_identity",{}).get("native_sha256")==source_identity.native_sha256,
			"each decoded frame retains the supplied source and actual runtime identity")
		previous_serial = serial
	check(witnesses.size()==2 and witnesses[0].generation==witnesses[1].generation \
		and witnesses[0].tick==witnesses[1].tick,"before/after native readbacks use the same paused World generation and tick")
	completed = true


func _run() -> void:
	source_identity = identity()
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	root.size = Vector2i(1440,1000)
	bench = host.shared_workbench
	editor = bench.paint_editor
	worker = host.simulation_worker
	await qualify()
	check(completed,"all native recording and artifact decoding phases complete")
	check(source_identity==identity(),"tested source files and native library stayed unchanged")
	if host.gameplay_recorder.is_active(): final_status = host.gameplay_recorder.stop_recording("test did not reach normal finalization")
	else: final_status = host.gameplay_recorder.poll_finalization()
	host.queue_free()
	await process_frame
	await process_frame
	print("CAMERA_STACK_RECORDING_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"completed":completed,
		"execution":"headless-native" if DisplayServer.get_name()=="headless" else "graphical-native",
		"scope":"native state recording and BMP/IDs/JSON decoding; no exact-replay or smoothness claim",
		"session_path":ProjectSettings.globalize_path(session_path),"source_identity":source_identity,
		"recording_identity":{"source_revision":runtime_identity.get("source",{}).get("source_revision","unavailable"),
			"script_set_sha256":runtime_identity.get("source",{}).get("script_set_sha256","unavailable"),
			"backend":runtime_identity.get("worker",{}).get("backend","unavailable"),
			"worker_count":runtime_identity.get("worker",{}).get("worker_count",0)},
		"native_readbacks":witnesses,"final_status":final_status}))
	quit(0 if failures.is_empty() else 1)
