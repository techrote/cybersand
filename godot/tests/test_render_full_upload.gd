extends SceneTree

# Exercise Main's real patch validation, CPU image, GPU-slot publication and
# retained previous-image ownership without starting a simulation worker. The
# native publication/receipt path is covered separately by temporal-dense.
# Timing is headless CPU/upload-call evidence, not physical GPU acceptance.
const Main = preload("res://scripts/main.gd")
const MaterialShader = preload("res://shaders/material_palette.gdshader")

var assertions: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []
var report_path: String = ""


func _init() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("RENDER_FULL_UPLOAD: " + message)


func _run() -> void:
	# The previous CPU image must be enabled in this isolated process, exactly
	# as it is for the corrected Workbench presentation mode.
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE", "repaired")
	report_path = OS.get_environment("CYBERSAND_FULL_UPLOAD_OUTPUT")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--render-full-upload-evidence="):
			report_path = argument.trim_prefix("--render-full-upload-evidence=")
	for channels: int in [1, 2]:
		_verify_format(channels)
		_measure_full_uploads(channels)
	var report: Dictionary = {
		"source_sha": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"main_sha256": FileAccess.get_sha256("res://scripts/main.gd"),
		"test_sha256": FileAccess.get_sha256("res://tests/test_render_full_upload.gd"),
		"godot": Engine.get_version_info(),
		"display_server": DisplayServer.get_name(),
		"processor": OS.get_processor_name(),
		"assertions": assertions, "failures": failures,
		"measurements": measurements,
		"scope": "Real Main patch/image/texture publication; no native worker or physical GPU timing."
	}
	if not report_path.is_empty():
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var output: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		check(output != null, "evidence output can be opened")
		if output != null:
			output.store_string(JSON.stringify(report, "\t"))
			output.close()
	print("RENDER_FULL_UPLOAD: %d assertions, %d failures" % [assertions, failures])
	quit(failures)


func _make_host(side: int, channels: int) -> Control:
	var host: Control = Main.new()
	host.world_extent = Vector2i(side, side)
	host.render_channels = channels
	host.render_image_format = Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8
	host.image = Image.create(side, side, false, host.render_image_format)
	host.world_view = TextureRect.new()
	host.world_shader = ShaderMaterial.new()
	host.world_shader.shader = MaterialShader
	host.world_view.material = host.world_shader
	# Main's upload publisher only needs Workbench presence to retain the old
	# image. No presentation decision or native receipt is mocked here.
	host.shared_workbench = Control.new()
	host.create_render_textures()
	return host


func _release_host(host: Control) -> void:
	host.world_view.free()
	host.shared_workbench.free()
	host.free()


func _pattern(side: int, channels: int, seed_value: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(side * side * channels)
	for cell: int in range(side * side):
		result[cell * channels] = (cell + seed_value) % 7
		if channels == 2:
			result[cell * channels + 1] = (cell * 23 + seed_value) % 256
	return result


func _full_rect(side: int, channels: int) -> PackedInt32Array:
	return PackedInt32Array([0, 0, side, side, 0, side * channels])


func _verify_upload(host: Control, rectangles: PackedInt32Array,
		payload: PackedByteArray, expected: PackedByteArray, label: String) -> void:
	var upload_payload: PackedByteArray = payload.duplicate()
	var expected_bytes: PackedByteArray = expected.duplicate()
	var old_bytes: PackedByteArray = host.image.get_data()
	var old_current: RID = host.texture.get_rid()
	var old_previous: RID = host.previous_texture.get_rid()
	var old_content_id: int = host._presentation_current_content_id
	var immutable_payload: PackedByteArray = payload.duplicate()
	check(host.upload_texture_patches(rectangles, upload_payload,
		host.last_uploaded_revision + 1, host.render_channels), label + " accepted")
	check(host.image.get_data() == expected_bytes, label + " exact image bytes")
	check(host._presentation_current_bytes == expected_bytes, label + " exact current occupancy bytes")
	check(host._presentation_previous_bytes == old_bytes, label + " exact previous occupancy bytes")
	check(host._presentation_previous_image != null and
		host._presentation_previous_image.get_data() == old_bytes, label + " retained previous CPU image")
	check(not host._presentation_previous_unknown, label + " previous image is known")
	check(host.texture.get_rid() == old_previous and host.previous_texture.get_rid() == old_current,
		label + " actual GPU slots swap")
	check(host._presentation_previous_content_id == old_content_id,
		label + " content identity follows the old current GPU slot")
	check(host.world_view.texture == host.texture and
		host.world_shader.get_shader_parameter("current_world_texture") == host.texture and
		host.world_shader.get_shader_parameter("previous_world_texture") == host.previous_texture,
		label + " shader and view publish the same texture pair")
	check(upload_payload == immutable_payload, label + " immutable input payload")
	if not upload_payload.is_empty():
		upload_payload[0] = (int(upload_payload[0]) + 1) % 256
		check(host.image.get_data() == expected_bytes and host._presentation_current_bytes == expected_bytes,
			label + " later payload mutation does not alias the published image")


func _verify_format(channels: int) -> void:
	const SIDE: int = 8
	var host: Control = _make_host(SIDE, channels)
	var prefix: String = "R8 " if channels == 1 else "RG8 "
	var full: PackedByteArray = _pattern(SIDE, channels, 3)
	_verify_upload(host, _full_rect(SIDE, channels), full, full, prefix + "tight whole image")
	var first_previous: Image = host._presentation_previous_image
	var first_previous_bytes: PackedByteArray = first_previous.get_data()
	var same_id: int = host._presentation_current_content_id
	_verify_upload(host, _full_rect(SIDE, channels), full, full, prefix + "equal whole image")
	check(host._presentation_current_content_id == same_id, prefix + "equal content keeps its identity")
	var modified: PackedByteArray = full.duplicate()
	var changed_index: int = 1 if channels == 2 else 0
	modified[changed_index] = (int(modified[changed_index]) + 13) % 256
	_verify_upload(host, _full_rect(SIDE, channels), modified, modified,
		prefix + ("condition-only change" if channels == 2 else "material change"))
	check(host._presentation_current_content_id != same_id,
		prefix + "any changed render byte receives different content identity")
	check(first_previous.get_data() == first_previous_bytes,
		prefix + "retained earlier history survives subsequent full uploads")

	var partial := PackedByteArray()
	partial.resize(2 * 2 * channels)
	partial.fill(4)
	var expected: PackedByteArray = modified.duplicate()
	for y: int in range(2):
		for x: int in range(2):
			for channel: int in range(channels):
				expected[((y + 3) * SIDE + x + 2) * channels + channel] = 4
	_verify_upload(host, PackedInt32Array([2, 3, 2, 2, 0, 2 * channels]),
		partial, expected, prefix + "partial fallback")

	var padded_expected: PackedByteArray = _pattern(SIDE, channels, 5)
	var stride: int = SIDE * channels + 3
	var padded := PackedByteArray()
	padded.resize(7 + stride * SIDE + 4)
	padded.fill(229)
	for y: int in range(SIDE):
		for x: int in range(SIDE * channels):
			padded[7 + y * stride + x] = padded_expected[y * SIDE * channels + x]
	_verify_upload(host, PackedInt32Array([0, 0, SIDE, SIDE, 7, stride]),
		padded, padded_expected, prefix + "offset and padded full fallback")
	var trailing: PackedByteArray = full.duplicate()
	trailing.append_array(PackedByteArray([121, 122, 123]))
	_verify_upload(host, _full_rect(SIDE, channels), trailing, full,
		prefix + "tight full with trailing payload fallback")

	var multiple := PackedByteArray()
	multiple.resize(SIDE * SIDE * channels)
	multiple.fill(2)
	for index: int in range(SIDE * SIDE / 2 * channels, multiple.size()):
		multiple[index] = 6
	var multiple_rects := PackedInt32Array([
		0, 0, SIDE, SIDE / 2, 0, SIDE * channels,
		0, SIDE / 2, SIDE, SIDE / 2, SIDE * SIDE / 2 * channels, SIDE * channels])
	_verify_upload(host, multiple_rects, multiple, multiple,
		prefix + "multiple patches fallback")

	var malformed: Array[Dictionary] = [
		{"rects":PackedInt32Array(), "bytes":full, "channels":channels},
		{"rects":PackedInt32Array([0, 0, SIDE]), "bytes":full, "channels":channels},
		{"rects":_full_rect(SIDE, channels), "bytes":PackedByteArray(), "channels":channels},
		{"rects":_full_rect(SIDE, channels), "bytes":full.slice(0, full.size() - 1), "channels":channels},
		{"rects":_full_rect(SIDE, channels), "bytes":full, "channels":3 - channels},
		{"rects":PackedInt32Array([1, 0, SIDE, SIDE, 0, SIDE * channels]), "bytes":full, "channels":channels},
		{"rects":PackedInt32Array([0, 0, SIDE, SIDE, 0, SIDE * channels - 1]), "bytes":full, "channels":channels},
	]
	for index: int in range(malformed.size()):
		var before: PackedByteArray = host.image.get_data()
		var previous_image: Image = host._presentation_previous_image
		var current_rid: RID = host.texture.get_rid()
		var previous_rid: RID = host.previous_texture.get_rid()
		var current_content: int = host._presentation_current_content_id
		var previous_content: int = host._presentation_previous_content_id
		var item: Dictionary = malformed[index]
		check(not host.upload_texture_patches(item.rects, item.bytes, 999, item.channels),
			prefix + "malformed %d is refused" % index)
		check(not host.last_render_patch_validation_error.is_empty(), prefix + "refusal is explained")
		check(host.image.get_data() == before and host._presentation_previous_image == previous_image,
			prefix + "refusal preserves both CPU images")
		check(host.texture.get_rid() == current_rid and host.previous_texture.get_rid() == previous_rid and
			host._presentation_current_content_id == current_content and
			host._presentation_previous_content_id == previous_content,
			prefix + "refusal preserves GPU slots and content certificates")
	_release_host(host)


func _measure_full_uploads(channels: int) -> void:
	const SIDE: int = 2048
	var host: Control = _make_host(SIDE, channels)
	var a := PackedByteArray()
	a.resize(SIDE * SIDE * channels)
	a.fill(0)
	a[(SIDE * 512 + 512) * channels] = CyberCellWorld.MARBLE
	var b: PackedByteArray = a.duplicate()
	b[(SIDE * 1024 + 1024) * channels] = CyberCellWorld.FIRE
	if channels == 2:
		b[(SIDE * 1024 + 1024) * channels + 1] = 255
	var rows: Array[Dictionary] = []
	var sequence: Array[int] = [0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1]
	var metadata: PackedInt32Array = _full_rect(SIDE, channels)
	for index: int in range(sequence.size()):
		var payload: PackedByteArray = a if sequence[index] == 0 else b
		var started: int = Time.get_ticks_usec()
		var accepted: bool = host.upload_texture_patches(metadata, payload, index + 1, channels)
		var elapsed: int = Time.get_ticks_usec() - started
		check(accepted, "2048² upload accepted")
		check(host.image.get_data() == payload, "2048² upload exact bytes")
		rows.append({"index":index, "payload":sequence[index], "elapsed_usec":elapsed,
			"reported_upload_ms":host.upload_time_ms,
			"content_cache_usec":host._presentation_upload_cache_usec,
			"content_id":host._presentation_current_content_id,
			"previous_content_id":host._presentation_previous_content_id,
			"material_publication":host.material_publication_status()})
	measurements.append({"channels":channels, "side":SIDE,
		"payload_bytes":a.size(), "samples":rows})
	_release_host(host)
