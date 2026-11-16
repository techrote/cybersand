extends SceneTree

# Independent review of Main's real checked publication/ACK transaction. These
# intentionally refused source identities must produce the existing production
# diagnostics. No upload, rejection or ACK method is overridden by this fixture.
# Complete readbacks make this correctness evidence, not performance evidence.
const Main = preload("res://scripts/main.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const SIDE := 512
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var expected_diagnostics: Array[String] = []
var source_before: Dictionary = {}
var output := "user://render-upload-577-refusal.json"


func _init() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("RENDER_UPLOAD_577_REFUSAL: " + label)


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in ["res://scripts/main.gd", "res://scripts/material_upload_hybrid.gd",
			"res://scripts/simulation_worker.gd", "res://shaders/material_upload_copy.gdshader",
			get_script().resource_path]:
		result[path] = FileAccess.get_sha256(path)
	return result


func _packet(serial: int, generation: int, channels: int, material: int,
		full: bool = false, whole: bool = false) -> CyberSimulationSnapshot:
	var packet := CyberSimulationSnapshot.new()
	packet.serial = serial
	packet.render_snapshot_serial = serial
	packet.render_world_generation = generation
	packet.render_channels = channels
	packet.render_full_refresh = full
	packet.world_revision = serial * 10
	packet.render_generated_usec = Time.get_ticks_usec()
	packet.render_context = {"workbench_display": {"serial": serial, "revision": packet.world_revision}}
	var side := SIDE if whole else 2
	var origin := 0 if whole else 100
	packet.render_patch_rectangles = PackedInt32Array([origin, origin, side, side, 0, side * channels])
	packet.render_patch_cells.resize(side * side * channels)
	for cell: int in range(side * side):
		packet.render_patch_cells[cell * channels] = material
		if channels == 2:
			packet.render_patch_cells[cell * channels + 1] = (serial + cell) % 256
	return packet


func _gpu_bytes(texture: Texture2D, format: Image.Format) -> PackedByteArray:
	var readback := texture.get_image()
	if readback == null or readback.is_empty():
		return PackedByteArray()
	readback.convert(format)
	return readback.get_data()


func _accepted_state(host: Control) -> Dictionary:
	return {"current_rid": host.texture.get_rid().get_id(),
		"previous_rid": host.previous_texture.get_rid().get_id(),
		"view_rid": host.world_view.texture.get_rid().get_id(),
		"shader_current_rid": host.world_shader.get_shader_parameter("current_world_texture").get_rid().get_id(),
		"shader_previous_rid": host.world_shader.get_shader_parameter("previous_world_texture").get_rid().get_id(),
		"serial": host.last_uploaded_render_snapshot_serial,
		"generation": host.last_uploaded_world_generation, "revision": host.last_uploaded_revision,
		"ack": host.simulation_worker._acknowledged_render_snapshot_serial,
		"accepted_count": host.accepted_render_publications,
		"accepted_usec": host.last_accepted_render_usec, "blend_start": host.snapshot_blend_start_usec,
		"workbench_frame": host._uploaded_workbench_frame.duplicate(true)}


func _refuse(host: Control, packet: CyberSimulationSnapshot, expected: Dictionary,
		current: PackedByteArray, previous: PackedByteArray, reason: String) -> void:
	var before: int = host.rejected_render_snapshot_count
	var diagnostic := "Rejected render snapshot %d (%d metadata integers, %d payload bytes): %s; requesting full refresh" % [
		packet.render_snapshot_serial, packet.render_patch_rectangles.size(), packet.render_patch_cells.size(), reason]
	expected_diagnostics.append(diagnostic)
	host.consume_render_snapshot(packet)
	check(host.rejected_render_snapshot_count == before + 1, "real Main rejection counted: " + reason)
	check(host.last_render_patch_validation_error == reason, "precise refusal reason: " + reason)
	check(_accepted_state(host) == expected, "refusal preserves accepted bindings/ACK/identity/fade: " + reason)
	check(_gpu_bytes(host.texture, host.render_image_format) == current, "refusal retains complete current: " + reason)
	check(_gpu_bytes(host.previous_texture, host.render_image_format) == previous, "refusal retains complete previous: " + reason)
	check(host.simulation_worker._render_full_refresh_requested, "refusal requests full refresh: " + reason)
	check(host._render_upload_fallback_pending, "refusal waits for full recovery: " + reason)


func _case(channels: int) -> void:
	var host: Control = Main.new()
	host.world_extent = Vector2i(SIDE, SIDE)
	host.render_channels = channels
	host.render_image_format = Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8
	host.image = Image.create(SIDE, SIDE, false, host.render_image_format)
	host.world_view = TextureRect.new()
	host.world_view.size = Vector2(320, 240)
	host.world_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.world_shader = ShaderMaterial.new()
	host.world_shader.shader = CyberPaletteShader.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	host.world_view.material = host.world_shader
	host.shared_workbench = Control.new()
	host.render_upload_strategy_override = "hybrid"
	host._render_upload_context = {"serial": 0, "generation": 4, "full": true}
	host.create_render_textures()
	host.last_uploaded_world_generation = 4
	root.add_child(host.world_view)
	check(host.render_upload_status.active == "hybrid", "graphical hybrid admitted for " + str(channels) + " channels")
	if host.render_upload_status.active != "hybrid":
		host.world_view.queue_free()
		host.shared_workbench.free()
		host.free()
		return
	for serial: int in range(1, 10):
		var before: PackedByteArray = host.image.get_data()
		host.consume_render_snapshot(_packet(serial, 4, channels, 2 if serial % 2 else 6))
		check(host.last_uploaded_render_snapshot_serial == serial, "ordinary source serial accepted " + str(serial))
		check(host.simulation_worker._acknowledged_render_snapshot_serial == serial, "real worker ACK accepted " + str(serial))
		check(_gpu_bytes(host.texture, host.render_image_format) == host.image.get_data(), "ordinary current complete " + str(serial))
		check(_gpu_bytes(host.previous_texture, host.render_image_format) == before, "ordinary previous complete " + str(serial))
		await process_frame
	check(host.texture is DrawableTexture2D, "refusal begins with active sparse drawable history")
	var accepted := _accepted_state(host)
	var accepted_cpu: PackedByteArray = host.image.get_data()
	var accepted_current := _gpu_bytes(host.texture, host.render_image_format)
	var accepted_previous := _gpu_bytes(host.previous_texture, host.render_image_format)
	# Main ignores repeated/older render serials before touching CPU/GPU state.
	# Do not manufacture a serial rejection that the real consumer never calls.
	for serial: int in [9, 8]:
		host.consume_render_snapshot(_packet(serial, 3, channels, 0))
		check(_accepted_state(host) == accepted and host.image.get_data() == accepted_cpu,
			"stale/replayed serial is ignored before patch work " + str(serial))
		check(host.rejected_render_snapshot_count == 0, "ignored serial does not invent a refusal")
	_refuse(host, _packet(10, 3, channels, 0), accepted, accepted_current, accepted_previous,
		"material upload World generation is stale")
	check(host.image.get_data() != accepted_cpu, "stale-generation fixture reached post-patch publication refusal")
	check(not host.set_render_upload_strategy("full"), "live switch cannot bypass outstanding recovery")
	_refuse(host, _packet(11, 4, channels, 3), accepted, accepted_current, accepted_previous,
		"hybrid fallback is waiting for a complete native refresh")
	_refuse(host, _packet(12, 3, channels, 4, true, true), accepted, accepted_current, accepted_previous,
		"hybrid fallback refuses stale publication identity")
	_refuse(host, _packet(13, 4, channels, 5, true, false), accepted, accepted_current, accepted_previous,
		"hybrid fallback is waiting for a complete native refresh")
	var recovered := _packet(14, 4, channels, 7, true, true)
	host.consume_render_snapshot(recovered)
	check(host.last_uploaded_render_snapshot_serial == 14 and host.simulation_worker._acknowledged_render_snapshot_serial == 14,
		"only complete accepted recovery advances source serial and ACK")
	check(host.accepted_render_publications == int(accepted.accepted_count) + 1, "recovery is one accepted publication")
	check(host.texture is ImageTexture and host.previous_texture is ImageTexture and host._render_upload_hybrid == null,
		"recovery returns an independent compact pair")
	check(host.render_upload_status.active == "full" and not host._render_upload_fallback_pending,
		"recovery returns safe full mode")
	check(_gpu_bytes(host.texture, host.render_image_format) == recovered.render_patch_cells,
		"recovery current equals the complete original recovery payload")
	check(_gpu_bytes(host.previous_texture, host.render_image_format) == accepted_current,
		"recovery previous equals last accepted GPU current, not speculative CPU bytes")
	var before: PackedByteArray = recovered.render_patch_cells.duplicate()
	host.consume_render_snapshot(_packet(15, 4, channels, 6))
	check(host.last_uploaded_render_snapshot_serial == 15 and host.simulation_worker._acknowledged_render_snapshot_serial == 15,
		"ordinary compact publication and ACK continue after fallback")
	check(_gpu_bytes(host.texture, host.render_image_format) == host.image.get_data(), "post-recovery current exact")
	check(_gpu_bytes(host.previous_texture, host.render_image_format) == before, "post-recovery previous exact")
	check(host.render_upload_metrics.mode == "full_update", "post-recovery submission uses baseline compact operation")
	records.append({"channels": channels, "accepted": host.accepted_render_publications,
		"refused": host.rejected_render_snapshot_count, "final_serial": host.last_uploaded_render_snapshot_serial,
		"ack": host.simulation_worker._acknowledged_render_snapshot_serial,
		"final_mode": host.render_upload_metrics.mode})
	host.world_view.queue_free()
	host.shared_workbench.free()
	host.free()
	await process_frame


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	source_before = _source_hashes()
	check(DisplayServer.get_name() != "headless", "actual graphical backend required")
	if failures.is_empty():
		for channels: int in [1, 2]:
			await _case(channels)
	check(_source_hashes() == source_before, "source bytes unchanged during test")
	var report := {"schema": "render-upload-577-independent-main-refusal-v1", "ok": failures.is_empty(),
		"checks": checks, "failures": failures, "cases": records,
		"expected_error_messages": expected_diagnostics, "context": Context.identity(get_script().resource_path),
		"source_files_sha256": source_before,
		"scope": "Real Main publication/refusal/ACK methods with deliberately adversarial source packets; exact GPU readbacks; no native simulation or performance claim"}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	else:
		check(false, "receipt path writable")
	print("RENDER_UPLOAD_577_REFUSAL ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
