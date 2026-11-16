extends SceneTree

# Independent actual-Main lifecycle qualification. The observer calls each real
# production method unchanged, retaining byte/binding identities around shader
# preparation. GPU readbacks deliberately serialize this correctness fixture;
# elapsed times here are not performance acceptance.
const Context = preload("res://tests/palette_qualification_context.gd")
const Setup = preload("res://scripts/workbench_setup.gd")

class ObservedMain extends "res://scripts/main.gd":
	var preparation_observations: Array[Dictionary] = []
	var process_callbacks := 0
	var physics_callbacks := 0

	func _process(delta: float) -> void:
		process_callbacks += 1
		super._process(delta)

	func _physics_process(delta: float) -> void:
		physics_callbacks += 1
		super._physics_process(delta)

	func _prepare_render_upload_shaders() -> bool:
		var before := accepted_state()
		var runs_before: int = _render_shader_preparation_runs
		var prepared: bool = super._prepare_render_upload_shaders()
		var after := accepted_state()
		preparation_observations.append({"accepted_before": before, "accepted_after": after,
			"unchanged": before == after, "result": prepared,
			"differences": state_differences(before, after),
			"runs_before": runs_before, "runs_after": _render_shader_preparation_runs,
			"receipt": render_shader_preparation.duplicate(true)})
		return prepared

	func state_differences(before: Variant, after: Variant, path: String = "") -> Array:
		var differences: Array = []
		if before is Dictionary and after is Dictionary:
			for key: Variant in before:
				differences.append_array(state_differences(before[key], after.get(key), path + "/" + str(key)))
		elif before is Array and after is Array and before.size() == after.size():
			for index: int in before.size():
				differences.append_array(state_differences(before[index], after[index], path + "/" + str(index)))
		elif typeof(before) != typeof(after) or before != after:
			differences.append({"path": path, "before_type": type_string(typeof(before)),
				"after_type": type_string(typeof(after)), "before": var_to_str(before), "after": var_to_str(after)})
		return differences

	func accepted_state() -> Dictionary:
		var effects: Array[Dictionary] = []
		for material: ShaderMaterial in vapour_trail_shaders:
			effects.append(material_state(material))
		var viewports: Array[int] = []
		for viewport: SubViewport in vapour_trail_viewports:
			viewports.append(viewport.get_viewport_rid().get_id())
		return {"current_rid": texture.get_rid().get_id(),
			"previous_rid": previous_texture.get_rid().get_id(),
			"view_rid": world_view.texture.get_rid().get_id(),
			"current_bytes": texture_digest(texture), "previous_bytes": texture_digest(previous_texture),
			"cpu_bytes": digest(image.get_data()), "extent": world_extent,
			"serial": last_uploaded_render_snapshot_serial, "generation": last_uploaded_world_generation,
			"revision": last_uploaded_revision, "accepted_count": accepted_render_publications,
			"accepted_usec": last_accepted_render_usec, "blend_start": snapshot_blend_start_usec,
			"ack": simulation_worker._acknowledged_render_snapshot_serial,
			"native_revision": int(simulation_worker.paint_state().revision),
			"native_tick": latest_snapshot.tick_index if latest_snapshot != null else -1,
			"rapier_step": physical_actor_session.tick if physical_actor_session != null else -1,
			"process_callbacks": process_callbacks, "physics_callbacks": physics_callbacks,
			"engine_process_frames": Engine.get_process_frames(), "engine_physics_frames": Engine.get_physics_frames(),
			"palette": material_state(world_shader), "glow": material_state(glow_source_shader),
			"vapour": effects, "vapour_viewports": viewports,
			"vapour_latest": vapour_trail_latest, "vapour_frame": vapour_trail_frame,
			"vapour_usec": vapour_trail_usec, "children": get_child_count()}

	func material_state(material: ShaderMaterial) -> Dictionary:
		if material == null: return {}
		var uniforms := {}
		for description: Dictionary in material.shader.get_shader_uniform_list():
			var key: String = str(description.name)
			var value: Variant = material.get_shader_parameter(key)
			# ShaderMaterial.duplicate() can materialize an unset scalar's default
			# in the source getter cache. Compare its actual shader value, not the
			# getter's lazy null representation; bound textures remain exact IDs.
			if value == null:
				var default_value: Variant = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), key)
				if typeof(default_value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR]:
					value = default_value
			# Main supplies integer 0 to the float water_presentation_mode uniform;
			# duplication may expose 0.0. Compare the declared GPU scalar type.
			if int(description.type) == TYPE_FLOAT and (value is int or value is float):
				value = float(value)
			if value is Resource:
				uniforms[key] = {"object": value.get_instance_id(), "rid": value.get_rid().get_id()}
			else:
				uniforms[key] = value
		return {"material": material.get_instance_id(), "shader": material.shader.get_instance_id(),
			"shader_rid": material.shader.get_rid().get_id(), "uniforms": uniforms}

	func texture_digest(value: Texture2D) -> String:
		var content := value.get_image()
		if content == null or content.is_empty(): return "unavailable"
		content.convert(render_image_format)
		return digest(content.get_data())

	func digest(bytes: PackedByteArray) -> String:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		return hashing.finish().hex_encode()

var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var output := "user://render-upload-577-preparation-lifecycle.json"
var source_before: Dictionary = {}
var host: Control


func _init() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("RENDER_UPLOAD_577_PREPARATION_LIFECYCLE: " + label)


func _sources() -> Dictionary:
	var result := {}
	for path: String in ["res://scripts/main.gd", "res://scripts/material_upload_hybrid.gd",
			"res://scripts/material_upload_shader_prepare.gd", "res://scripts/simulation_worker.gd",
			get_script().resource_path]:
		result[path] = FileAccess.get_sha256(path)
	return result


func _until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		await process_frame
	check(false, label)
	return false


func _workbench_ready() -> bool:
	return host.shared_workbench != null and not host.shared_workbench.applied.is_empty() \
		and not host.shared_workbench.busy() and host.pending_microscenario_apply.is_empty() \
		and not host.shared_workbench.paint_editor.busy() \
		and not host.simulation_worker.paint_state().busy \
		and host.last_uploaded_revision == int(host.simulation_worker.paint_state().revision)


func _case(channels: int, initial: String) -> void:
	var label := ("R8" if channels == 1 else "RG8") + "/" + initial
	if channels == 2: set_meta("cybersand_feature", "shared_workbench")
	elif has_meta("cybersand_feature"): remove_meta("cybersand_feature")
	host = load("res://main.tscn").instantiate()
	host.set_script(ObservedMain)
	host.paused = true
	host.render_upload_strategy_override = initial
	if channels == 1:
		# Select the supported compatibility owner before it acquires the World.
		host.simulation_worker._world = CyberCellWorld.new()
	root.add_child(host)
	check(host.render_channels == channels, label + " actual owner channel format")
	check(host.render_upload_status.active == initial, label + " startup policy admitted")
	check(host._render_shader_preparation_runs == (1 if initial == "hybrid" else 0), label + " startup preparation count")
	if channels == 2:
		if not await _until(_workbench_ready, label + " actual Workbench initialized"):
			await _release()
			return
	else:
		if not await _until(func() -> bool: return host.latest_snapshot != null and host.latest_snapshot.paused,
				label + " compatibility owner paused"):
			await _release()
			return
	check(host.latest_snapshot.backend_name == ("native-phased" if channels == 2 else "gdscript-serial-fallback"),
		label + " real selected owner")
	# Observe a genuine publication before switching. The native and compatibility
	# owners both receive the same public queued edit, with no direct cell writes.
	var prior_serial: int = host.last_uploaded_render_snapshot_serial
	check(host.simulation_worker.queue_emit_disc(500, 300, 0, CyberCellWorld.STEAM), label + " queued material edit admitted")
	if not await _until(func() -> bool: return host.last_uploaded_render_snapshot_serial > prior_serial,
			label + " actual material publication completed"):
		await _release()
		return
	var before: Dictionary = host.accepted_state()
	check(host.set_render_upload_strategy("hybrid"), label + " explicit hybrid activation")
	var after: Dictionary = host.accepted_state()
	check(before == after, label + " activation preserves all accepted and effect identities")
	check(host._render_shader_preparation_runs == 1, label + " one successful preparation")
	check(host.render_shader_preparation.prepared and host.render_shader_preparation.readback_count == 12,
		label + " all actual palette/emission/vapour combinations prepared")
	check(host.render_shader_preparation.channels == channels and host.render_shader_preparation.hdr_2d,
		label + " preparation matches actual format and HDR")
	# Switching to compact allocates equivalent resources by design; compare
	# complete bytes and source identity, then require exact adoption on reentry.
	var current_bytes: String = host.texture_digest(host.texture)
	var previous_bytes: String = host.texture_digest(host.previous_texture)
	var accepted_serial: int = host.last_uploaded_render_snapshot_serial
	var acknowledged: int = host.simulation_worker._acknowledged_render_snapshot_serial
	var fade: int = host.snapshot_blend_start_usec
	check(host.set_render_upload_strategy("full"), label + " live full selection")
	check(host.texture_digest(host.texture) == current_bytes and host.texture_digest(host.previous_texture) == previous_bytes,
		label + " compact selection preserves complete temporal images")
	check(host.last_uploaded_render_snapshot_serial == accepted_serial and host.simulation_worker._acknowledged_render_snapshot_serial == acknowledged
		and host.snapshot_blend_start_usec == fade, label + " compact selection preserves source ACK and fade")
	before = host.accepted_state()
	check(host.set_render_upload_strategy("hybrid"), label + " cached hybrid reentry")
	check(host.accepted_state() == before, label + " cached activation preserves exact bindings")
	check(host._render_shader_preparation_runs == 1, label + " cached reentry does not prepare again")
	# Draw callbacks and ordinary paused Main callbacks must not start preparation
	# or acknowledge any material that was not newly published.
	var observations: int = host.preparation_observations.size()
	for frame: int in range(6): await RenderingServer.frame_post_draw
	check(host._render_shader_preparation_runs == 1 and host.preparation_observations.size() == observations,
		label + " draw callbacks never restart preparation")
	check(host.last_uploaded_render_snapshot_serial == accepted_serial and host.simulation_worker._acknowledged_render_snapshot_serial == acknowledged,
		label + " draw callbacks never invent material acceptance or ACK")
	var generation: int = host.last_uploaded_world_generation
	if channels == 2:
		var candidate: Dictionary = Setup.fresh(PackedInt32Array(host.shared_workbench.applied.liquid_policy), Vector2i(512, 512))
		check(host.shared_workbench.apply(candidate), label + " actual World reconstruction admitted")
		await _until(func() -> bool: return _workbench_ready() and host.world_extent == Vector2i(512, 512) \
			and host.last_uploaded_world_generation > generation, label + " reconstructed World accepted")
	else:
		host.reset_world()
		await _until(func() -> bool: return host.last_uploaded_world_generation > generation,
			label + " compatibility World reset accepted")
	check(host._render_shader_preparation_runs == 1 and host.preparation_observations.size() == observations,
		label + " World reconstruction reuses preparation without force_draw")
	check(host.texture_digest(host.texture) == host.digest(host.image.get_data()), label + " reconstructed current CPU/GPU exact")
	check(host.simulation_worker._acknowledged_render_snapshot_serial == host.last_uploaded_render_snapshot_serial,
		label + " reconstructed material ACK is accepted serial")
	for observation: Dictionary in host.preparation_observations:
		check(observation.unchanged, label + " every real preparation/cache call preserves accepted state")
		check(observation.result, label + " every preparation/cache call succeeds")
	check(not host._render_shader_preparation_running, label + " preparation guard released")
	for child: Node in host.get_children():
		check(not str(child.name).begins_with("MaterialUploadPrepare_"), label + " no temporary viewport remains")
	cases.append({"label": label, "channels": channels, "initial_strategy": initial,
		"backend": host.latest_snapshot.backend_name, "preparation_runs": host._render_shader_preparation_runs,
		"final_generation": host.last_uploaded_world_generation, "final_serial": host.last_uploaded_render_snapshot_serial,
		"ack": host.simulation_worker._acknowledged_render_snapshot_serial,
		"preparation": host.render_shader_preparation.duplicate(true),
		"observations": host.preparation_observations.duplicate(true)})
	await _release()


func _release() -> void:
	host.queue_free()
	await process_frame
	await process_frame
	host = null


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	source_before = _sources()
	check(DisplayServer.get_name() != "headless", "actual graphical backend required")
	check(ClassDB.class_exists(&"CyberNativeCellWorld"), "source-matched native module required")
	if failures.is_empty():
		await _case(2, "hybrid")
		await _case(2, "full")
		await _case(1, "hybrid")
	check(_sources() == source_before, "source bytes unchanged during qualification")
	var report := {"schema": "render-upload-577-independent-preparation-lifecycle-v1", "ok": failures.is_empty(),
		"checks": checks, "failures": failures, "cases": cases, "context": Context.identity(get_script().resource_path),
		"source_files_sha256": source_before,
		"scope": "Actual Main and native/R8 compatibility owners; initialization/live activation/cache/reconstruction/effect identities; readback-serialized correctness, not performance"}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	else: check(false, "receipt path writable")
	print("RENDER_UPLOAD_577_PREPARATION_LIFECYCLE ", JSON.stringify({"ok": failures.is_empty(), "checks": checks,
		"failures": failures, "cases": cases.size()}))
	quit(0 if failures.is_empty() else 1)
