extends SceneTree

# Original native packets are the oracle; Main's real validation, GPU publication
# and accepted ACK seam run on an actual graphical backend. Readbacks deliberately
# serialize this correctness fixture: its frame costs are NOT performance results.
const Main = preload("res://scripts/main.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const SIDE := 1024
const EDITS := 320

class NativeOwner extends CyberSimulationWorker:
	var ack_mode := "normal"
	var held_serial := 0
	var ack_queue: Array[Dictionary] = []
	var event_index := 0
	var full_captures := 0
	var source_captures := 0
	var source := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RG8)
	func acknowledge_render_snapshot(serial: int) -> void:
		held_serial = maxi(held_serial, serial)
		if ack_mode == "normal":
			super.acknowledge_render_snapshot(serial)
		elif ack_mode == "delayed":
			ack_queue.append({"serial": serial, "due": event_index + 8})
	func pump() -> void:
		while not ack_queue.is_empty() and int(ack_queue[0].due) <= event_index:
			super.acknowledge_render_snapshot(int(ack_queue.pop_front().serial))
	func recover() -> void:
		ack_mode = "normal"
		ack_queue.clear()
		super.acknowledge_render_snapshot(held_serial)
	func _take_native_render_snapshot(force_full: bool) -> Dictionary:
		var packet: Dictionary = super._take_native_render_snapshot(force_full)
		var bytes: PackedByteArray = packet.get("cells", PackedByteArray())
		if bytes.is_empty(): return packet
		source_captures += 1
		if bool(packet.get("full_refresh", false)): full_captures += 1
		var rectangles: PackedInt32Array = packet.rectangles
		for offset: int in range(0, rectangles.size(), 6):
			var rect := Rect2i(rectangles[offset], rectangles[offset + 1], rectangles[offset + 2], rectangles[offset + 3])
			var compact := PackedByteArray()
			for row: int in rect.size.y:
				var start: int = rectangles[offset + 4] + row * rectangles[offset + 5]
				compact.append_array(bytes.slice(start, start + rect.size.x * 2))
			var patch := Image.create_from_data(rect.size.x, rect.size.y, false, Image.FORMAT_RG8, compact)
			source.blit_rect(patch, Rect2i(Vector2i.ZERO, rect.size), rect.position)
		return packet

var failures: Array[String] = []
var checks := 0
var cases: Array[Dictionary] = []


func _init() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("RENDER_UPLOAD_577_ACK: " + message)


func _run() -> void:
	check(DisplayServer.get_name() != "headless", "actual graphical backend required")
	check(ClassDB.class_exists(&"CyberNativeCellWorld"), "source-matched native backend required")
	if failures.is_empty():
		for strategy: String in ["full", "hybrid"]:
			for mode: String in ["normal", "delayed", "missing"]:
				await _case(strategy, mode)
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"cases": cases, "context": Context.identity(get_script().resource_path),
		"scope": "actual native/Main/GPU correctness; synchronous controlled native owner; readbacks serialize every publication; not a frame-performance comparison"}
	var output := "user://render-upload-577-ack.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report) + "\n")
		file.close()
	print("RENDER_UPLOAD_577_ACK ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "cases": cases}))
	quit(0 if failures.is_empty() else 1)


func _case(strategy: String, mode: String) -> void:
	var owner := NativeOwner.new()
	owner._workbench_extent = Vector2i(SIDE, SIDE)
	owner.set_render_pending_compaction_enabled(strategy == "hybrid")
	var host: Control = Main.new()
	host.simulation_worker = owner
	host.render_upload_strategy_override = strategy
	host.world_extent = Vector2i(SIDE, SIDE)
	host.render_channels = 2
	host.render_image_format = Image.FORMAT_RG8
	host.image = Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RG8)
	host.world_view = TextureRect.new()
	host.world_view.size = Vector2(320, 240)
	host.world_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.world_shader = ShaderMaterial.new()
	host.world_shader.shader = CyberPaletteShader.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	host.world_view.material = host.world_shader
	host.create_render_textures()
	root.add_child(host.world_view)
	owner._publish_snapshot(0.0, true, 0, true)
	var initial: CyberSimulationSnapshot = owner.take_latest_snapshot(-1)
	host.consume_render_snapshot(initial)
	check(host.render_upload_status.active == strategy, strategy + " admitted on actual backend")
	owner.ack_mode = mode
	var previous: Image = owner.source.duplicate()
	var first_publications: int = host.accepted_render_publications
	var first_capture: int = owner.source_captures
	var latencies: Array[int] = []
	var serials: Array[int] = []
	for index: int in EDITS:
		owner.event_index = index
		owner.pump()
		owner._world.emit_disc(30 + (index % 20) * 22, 30 + (index / 20) * 22,
			0, CyberCellWorld.WALL if index % 2 == 0 else CyberCellWorld.STONE)
		owner._publish_snapshot(0.0, true, 0)
		var packet: CyberSimulationSnapshot = owner.take_latest_snapshot(-1)
		var before: int = host.last_uploaded_render_snapshot_serial
		host.consume_render_snapshot(packet)
		check(host.last_uploaded_render_snapshot_serial > before, strategy + "/" + mode + " every changed source is published immediately " + str(index))
		serials.append(host.last_uploaded_render_snapshot_serial)
		latencies.append(Time.get_ticks_usec() - packet.render_generated_usec)
		await RenderingServer.frame_post_draw
		_check_texture(host.texture, owner.source, strategy + "/" + mode + " current " + str(index))
		_check_texture(host.previous_texture, previous, strategy + "/" + mode + " previous " + str(index))
		check(host.image.get_data() == owner.source.get_data(), strategy + "/" + mode + " CPU/native " + str(index))
		check(packet.hard_surface_revision == int(owner._world.hard_surface_revision), "collider invalidation remains current")
		previous = owner.source.duplicate()
	check(host.accepted_render_publications - first_publications == EDITS, "ACK policy did not suppress visual updates")
	check(owner.source_captures - first_capture >= EDITS, "ACK policy did not gate native capture")
	var full_before_recovery: int = owner.full_captures
	owner.recover()
	owner._publish_snapshot(0.0, true, 0)
	owner._world.emit_disc(490, 490, 0, CyberCellWorld.METAL)
	owner._publish_snapshot(0.0, true, 0)
	var recovered: CyberSimulationSnapshot = owner.take_latest_snapshot(-1)
	host.consume_render_snapshot(recovered)
	await RenderingServer.frame_post_draw
	_check_texture(host.texture, owner.source, "recovered current")
	_check_texture(host.previous_texture, previous, "recovered previous")
	check(not recovered.render_full_refresh, "ACK recovery returns to sparse native transport")
	check(host.rejected_render_snapshot_count == 0, "valid source sequence never refused")
	# Live selection must preserve both temporal images and source/fade identity.
	var accepted: int = host.last_uploaded_render_snapshot_serial
	var blend: int = host.snapshot_blend_start_usec
	check(host.set_render_upload_strategy("hybrid" if strategy == "full" else "full"), "live strategy switch admitted")
	_check_texture(host.texture, owner.source, "live-switch current")
	_check_texture(host.previous_texture, previous, "live-switch previous")
	check(host.last_uploaded_render_snapshot_serial == accepted and host.snapshot_blend_start_usec == blend,
		"live switch does not invent publication or restart fade")
	# Explicit baseline selection after a startup/refusal fallback resets policy.
	check(host.set_render_upload_strategy("full"), "restore baseline before fallback control")
	host.render_upload_status = {"requested": "hybrid", "active": "full", "fallback_reason": "test fallback"}
	owner.set_render_pending_compaction_enabled(true)
	check(host.set_render_upload_strategy("full"), "same-active baseline selection")
	check(not owner._render_pending_compaction_requested and host.render_upload_status.requested == "full",
		"same-active baseline clears hybrid transport request")
	cases.append({"strategy": strategy, "ack": mode, "edits": EDITS,
		"accepted_visual_updates": EDITS, "native_captures": owner.source_captures,
		"native_full_captures_before_recovery": full_before_recovery,
		"serials": serials, "receive_to_submission_usec_with_readbacks_between_events": latencies,
		"final_native_sha256": _digest(owner.source.get_data()), "history_mismatches": 0 if failures.is_empty() else null})
	if host._render_upload_hybrid != null: host._render_upload_hybrid.close()
	host.world_view.queue_free()
	host.free()
	await process_frame


func _check_texture(texture: Texture2D, expected: Image, label: String) -> void:
	var readback := texture.get_image()
	check(readback != null and not readback.is_empty(), label + " readback")
	if readback == null or readback.is_empty(): return
	readback.convert(Image.FORMAT_RG8)
	check(readback.get_data() == expected.get_data(), label + " exact original source bytes")


func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
