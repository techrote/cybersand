extends SceneTree

# Isolated measurement of the real Workbench event loop. No source changes or
# target-hardware performance claims; records frame/service latency. Supply
# --output=<absolute-report-path> after Godot's -- separator, or set
# CYBERSAND_WORKBENCH_EVIDENCE_OUTPUT. Run with --path pointing at godot/.
const Workbench = preload("res://worldgen_workbench.tscn")
const EDITOR_COMMIT: String = "5dda4faf6daa5fd77693c9cd93e5108f35454f97"
var app: Variant
var failures: Array[String] = []
var report: Dictionary = {}
var output: String = ""

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func summary(samples: Array[int]) -> Dictionary:
	if samples.is_empty(): return {"samples":0}
	var sorted: Array[int] = samples.duplicate()
	sorted.sort()
	return {"samples":sorted.size(), "min_usec":sorted[0], "p50_usec":sorted[mini(sorted.size()-1, int(sorted.size()*0.5))], "p95_usec":sorted[mini(sorted.size()-1, int(sorted.size()*0.95))], "max_usec":sorted.back()}

func edit_pending() -> bool:
	return app._edit_thread != null or not app._pending_edit.is_empty()

func wait_for_edit(retained_revision: int, retained_cache: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var gaps: Array[int] = []
	var services: Array[int] = []
	var cache_retained: bool = true
	while edit_pending() and Time.get_ticks_usec()-started < 120000000:
		await process_frame
		var frame: int = Time.get_ticks_usec()
		gaps.append(frame-previous)
		previous = frame
		if app.active_revision == retained_revision:
			cache_retained = cache_retained and app.cache.size() == retained_cache.size()
			for coordinate: Vector2i in retained_cache:
				cache_retained = cache_retained and app.cache.has(coordinate) and app.cache.get(coordinate, {}).get("hash", "") == retained_cache[coordinate]
		var work: int = Time.get_ticks_usec()
		app.service_editor_transaction()
		services.append(Time.get_ticks_usec()-work)
	check(not edit_pending(), "Edit did not complete within the isolated 120-second bound")
	# Include the frame following the last service call, so a completed main-thread
	# commit/rebuild cannot disappear from the measured heartbeat gaps.
	await process_frame
	gaps.append(Time.get_ticks_usec()-previous)
	return {"wall_usec":Time.get_ticks_usec()-started, "heartbeat_frames":gaps.size(), "frame_gaps":summary(gaps), "main_service_calls":summary(services), "accepted_cache_retained_until_commit":cache_retained, "native_prepare_usec":app.last_prepare_usec, "native_adopt_usec":app.last_adopt_usec, "accepted_revision":app.active_revision, "accepted_fingerprint":app.active_fingerprint, "accepted_seed":app.active_recipe.get("seed", 1), "last_error":app.last_error}

func cache_identity() -> Dictionary:
	var copied: Dictionary = {}
	for coordinate: Vector2i in app.cache: copied[coordinate] = app.cache[coordinate].get("hash", "")
	return copied

func preview_until_ready() -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var gaps: Array[int] = []
	var services: Array[int] = []
	while (app._has_active_chunk or not app.pending_chunks.is_empty()) and Time.get_ticks_usec()-started < 120000000:
		await process_frame
		var frame: int = Time.get_ticks_usec()
		gaps.append(frame-previous)
		previous = frame
		var work: int = Time.get_ticks_usec()
		app.service_generation()
		services.append(Time.get_ticks_usec()-work)
	check(not app._has_active_chunk and app.pending_chunks.is_empty() and app._blocked_chunks.is_empty(), "Native preview did not finish every requested chunk")
	await process_frame
	gaps.append(Time.get_ticks_usec()-previous)
	var native_usec: int = 0
	var material_bytes: int = 0
	var logical_operations: int = 0
	for packet: Dictionary in app.cache.values():
		native_usec += int(packet.get("compute_usec", 0))
		logical_operations += int(packet.get("operations", 0))
		for plane: PackedByteArray in packet.get("materials", {"play":packet.cells}).values(): material_bytes += plane.size()
	return {"wall_usec":Time.get_ticks_usec()-started, "heartbeat_frames":gaps.size(), "frame_gaps":summary(gaps), "main_service_calls":summary(services), "cached_chunks":app.cache.size(), "material_bytes":material_bytes, "native_generation_calls_usec":native_usec, "conservative_logical_operations":logical_operations, "camera_origin":app.camera_origin, "view_size":app.view_size, "chunk_size":app.active_recipe.get("chunk_size", 128)}

func run() -> void:
	output = OS.get_environment("CYBERSAND_WORKBENCH_EVIDENCE_OUTPUT")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty() or not output.is_absolute_path():
		push_error("Provide --output=<absolute-report-path> or CYBERSAND_WORKBENCH_EVIDENCE_OUTPUT.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK:
		push_error("Could not create the requested evidence output directory.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("This measurement requires the actual display-backed workbench.")
		quit(1)
		return
	Engine.max_fps = 60
	root.size = Vector2i(1600,1000)
	var runtime_digest: String = FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")
	var environment: Dictionary = {}
	for key: String in ["LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "GALLIVM_PERF", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]: environment[key] = OS.get_environment(key)
	var source_inputs: Dictionary = {}
	for source: String in ["res://scripts/worldgen_workbench.gd", "res://scripts/worldgen_workbench_tools.gd", "res://scripts/worldgen_preview.gd"]: source_inputs[source] = FileAccess.get_sha256(source)
	app = Workbench.instantiate()
	root.add_child(app)
	app.set_process(false)
	await process_frame
	check(app.generator != null and app.generator.has_method(&"adopt_configuration"), "Source-matched native adoption API missing")
	var recipe_path: String = ProjectSettings.globalize_path("res://../examples/worldgen/gen007-deepworks.json")
	var recipe_digest: String = FileAccess.get_sha256(recipe_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
	check(parsed is Dictionary, "Qualification recipe failed to parse")
	if not failures.is_empty():
		quit(1)
		return
	var recipe: Dictionary = parsed
	app.view_size = Vector2(128,128)
	app.set_camera_origin(Vector2.ZERO)
	# Warm the already accepted starter view outside any measured section.
	while app._has_active_chunk or not app.pending_chunks.is_empty(): app.service_generation()
	for ignored: int in range(20): await process_frame
	var old_revision: int = app.active_revision
	var old_cache: Dictionary = cache_identity()
	var submitted: int = Time.get_ticks_usec()
	check(app.request_recipe(recipe), "Full qualification recipe did not submit")
	var submit_usec: int = Time.get_ticks_usec()-submitted
	var full: Dictionary = await wait_for_edit(old_revision, old_cache)
	full.submit_main_call_usec = submit_usec
	check(int(app.active_recipe.get("seed", 0)) == 19301 and app.active_recipe.get("semantic_planes", {}).get("id", "") == recipe.semantic_planes.id, "Full qualification recipe was not adopted")
	check(bool(full.accepted_cache_retained_until_commit), "Full preparation mutated the accepted preview before admission")
	app.tools2.select_plane(4)
	app.view_size = Vector2(256,192)
	app.set_camera_origin(Vector2.ZERO)
	var preview: Dictionary = await preview_until_ready()
	var accepted_revision: int = app.active_revision
	var accepted_cache: Dictionary = cache_identity()
	var cancelled_recipe: Dictionary = recipe.duplicate(true)
	cancelled_recipe.seed = 19317
	submitted = Time.get_ticks_usec()
	check(app.request_recipe(cancelled_recipe), "Cancellation candidate did not submit")
	var cancel_submit_usec: int = Time.get_ticks_usec()-submitted
	await process_frame
	var alive_at_cancel: bool = app._edit_thread != null and app._edit_thread.is_alive()
	check(alive_at_cancel, "Cancellation probe did not overlap a running full-recipe validator")
	var cancelled: int = Time.get_ticks_usec()
	app.cancel_pending_edit()
	var cancellation_usec: int = Time.get_ticks_usec()-cancelled
	var cancellation: Dictionary = await wait_for_edit(accepted_revision, accepted_cache)
	cancellation.submit_main_call_usec = cancel_submit_usec
	cancellation.cancel_main_call_usec = cancellation_usec
	cancellation.worker_was_alive_at_cancel = alive_at_cancel
	cancellation.worker_quiescence_usec = cancellation.wall_usec
	cancellation.erase("native_prepare_usec")
	cancellation.erase("native_adopt_usec")
	cancellation.native_timing_scope = "Cancelled private candidate is never adopted; only observed quiescence and retained accepted identity are measured."
	cancellation.accepted_identity_preserved = app.active_revision == accepted_revision and int(app.active_recipe.seed) == 19301
	check(bool(cancellation.accepted_identity_preserved) and bool(cancellation.accepted_cache_retained_until_commit), "Cancelled qualification edit affected accepted identity or preview")
	# Queue a second candidate while the first remains exclusively owned by its
	# worker. The newest request must win; neither submission blocks on the old.
	var latest_recipe: Dictionary = recipe.duplicate(true)
	latest_recipe.seed = 19337
	submitted = Time.get_ticks_usec()
	check(app.request_recipe(cancelled_recipe), "First rapid qualification edit did not submit")
	check(app.request_recipe(latest_recipe), "Latest rapid qualification edit did not submit")
	var rapid_submit_usec: int = Time.get_ticks_usec()-submitted
	check(app._edit_thread != null and app._pending_edit.size() > 0, "Rapid qualification changes did not exercise one active plus one pending request")
	var rapid: Dictionary = await wait_for_edit(accepted_revision, accepted_cache)
	rapid.submit_two_main_calls_usec = rapid_submit_usec
	rapid.native_timing_scope = "Preparation/adoption fields describe only the accepted latest candidate; retired work is included only in overall wall time."
	check(int(app.active_recipe.seed) == 19337 and bool(rapid.accepted_cache_retained_until_commit), "Latest qualification edit lost to a retired worker or altered the accepted preview early")
	var final_preview: Dictionary = await preview_until_ready()
	check(runtime_digest == FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so") and recipe_digest == FileAccess.get_sha256(recipe_path), "Runtime or recipe changed during the isolated measurement")
	for source: String in source_inputs: check(source_inputs[source] == FileAccess.get_sha256(source), "Editor input changed during measurement: " + source)
	report = {"schema":1, "editor_source_commit":EDITOR_COMMIT, "source_commit":OS.get_environment("CYBERSAND_SOURCE_SHA"), "recipe_sha256":recipe_digest, "runtime_sha256":runtime_digest, "platform":OS.get_name(), "processor":OS.get_processor_name(), "display":DisplayServer.get_name(), "renderer":RenderingServer.get_video_adapter_name(), "environment":environment, "godot":Engine.get_version_info(), "frame_cap":60, "scope":"Isolated local display-backed Workbench; full 1024x1024 recipe preparation, bounded viewport rendering. No target-hardware or full-map rendering timing claim.", "full_recipe":full, "four_plane_preview":preview, "cancelled_candidate":cancellation, "rapid_latest_candidate":rapid, "latest_preview":final_preview, "failures":failures, "source_file_sha256":source_inputs}
	report.source_binding = "Checkout commit identifies the starting revision; exact recipe, runtime, and editor input hashes bind the measured working tree."
	report.probe_sha256 = FileAccess.get_sha256(get_script().resource_path)
	report.heartbeat_measurement = "Each phase includes the first process_frame heartbeat after its final service call, including completed commit/UI rebuild cost."
	report.input_worktree_changes = OS.get_environment("CYBERSAND_INPUT_WORKTREE_CHANGES")
	report.cache_state = {"xdg_directories":"Fresh isolated paths for this run; no user renderer cache reused.", "unmeasured_warmup":"Native extension and starter recipe loaded; one accepted 128x128 starter preview plus 20 rendered frames before the first full qualification submission.", "full_recipe":"First qualification preparation in this process; operating-system file/page caches are uncontrolled.", "later_candidates":"Same warmed process; each edit uses a new private native adapter and immutable compiled plan.", "timing_scope":"Interaction latency in an open editor, not application startup or cold-renderer performance."}
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var image_path: String = output.get_base_dir().path_join("workbench-qualification-viewport.png")
	check(image.save_png(image_path) == OK, "Qualification Workbench viewport image could not be retained")
	report.viewport_file_sha256 = FileAccess.get_sha256(image_path)
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	check(file != null, "Latency evidence could not be retained")
	if file != null:
		file.store_string(JSON.stringify(report, "  ", true, true)+"\n")
		file.close()
	print("GEN007_WORKBENCH_LATENCY: %d failures; full_prepare_ms=%.3f; adopt_ms=%.3f; cancel_ms=%.3f; heartbeat_frames=%d" % [failures.size(), float(full.native_prepare_usec)/1000.0, float(full.native_adopt_usec)/1000.0, float(cancellation.cancel_main_call_usec)/1000.0, int(full.heartbeat_frames)])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
