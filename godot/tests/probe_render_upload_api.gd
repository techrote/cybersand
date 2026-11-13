extends SceneTree

# RENDER-UPLOAD-001 exact-byte API qualification, independent of native World.
# A graphical renderer is required. Optional --diagnostic emits raw CPU-call,
# render-command-queue and readback timings; these are not isolated GPU timings.
# Usage: godot --path godot --script res://tests/probe_render_upload_api.gd --
#        --output /absolute/probe.json [--diagnostic] [--diagnostic-samples 24]

var failures: Array[String] = []
var records: Array = []
var sources: Array[Texture2D] = []
var copy_material: ShaderMaterial
var diagnostics: Array = []
var output_path := "user://render-upload-api-probe.json"
var diagnostic_samples := 24
var diagnostic_enabled := false
const DIMS := Vector2i(257, 263)

func _initialize() -> void:
	print("RENDER_UPLOAD_PID ", OS.get_process_id())
	call_deferred("_run")

func _run() -> void:
	_parse_args()
	if DisplayServer.get_name() == "headless":
		push_error("RENDER-UPLOAD-001 API probe requires a graphical renderer; headless is not qualification.")
		quit(2)
		return
	await process_frame
	await process_frame
	var shader := Shader.new()
	shader.code = "shader_type texture_blit;\nrender_mode blend_disabled;\nuniform sampler2D patch : hint_blit_source0, filter_nearest, repeat_disable;\nvoid blit(){ COLOR0 = texture(patch, UV); }\n"
	copy_material = ShaderMaterial.new()
	copy_material.shader = shader
	for fmt in [Image.FORMAT_R8, Image.FORMAT_RG8]:
		await _probe_format(fmt)
	if diagnostic_enabled and failures.is_empty():
		await _diagnostic()
	var result := {
		"schema": "render-upload-001-drawable-api-probe-v2",
		"source_sha": OS.get_environment("CYBERSAND_SOURCE_SHA"),
		"probe_script_sha256": FileAccess.get_sha256(get_script().resource_path),
		"engine_binary_sha256": FileAccess.get_sha256(OS.get_executable_path()),
		"render_call_on_render_thread": RenderingServer.is_on_render_thread(),
		"thread_model": ProjectSettings.get_setting("rendering/driver/threads/thread_model", -1),
		"editor_hint": Engine.is_editor_hint(),
		"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"records": records,
		"diagnostics": diagnostics,
		"measurement_boundary": "CPU API-call wall time; force_sync only drains Godot renderer commands in pinned source; get_image timing includes completion wait and full readback/copy. No isolated GPU transfer time or PCIe bytes measured.",
		"failures": failures,
		"pass": failures.is_empty(),
	}
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var f := FileAccess.open(output_path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write API probe output: " + output_path)
		quit(2)
		return
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _probe_format(fmt: Image.Format) -> void:
	var target := DrawableTexture2D.new()
	target.setup(DIMS.x, DIMS.y, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0, 0, 0, 1), false)
	var expected := Image.create(DIMS.x, DIMS.y, false, Image.FORMAT_RGBA8)
	expected.fill(Color(0, 0, 0, 1))
	var initial := _pattern(DIMS, fmt, 0)
	_blit(target, expected, Rect2i(Vector2i.ZERO, DIMS), initial)
	await RenderingServer.frame_post_draw
	_check(target, expected, fmt, "whole_plane")
	# Exact corners and non-square dimensions, including zero and byte 255.
	var rects: Array[Rect2i] = [Rect2i(0, 0, 1, 1), Rect2i(DIMS.x - 1, DIMS.y - 1, 1, 1), Rect2i(DIMS.x - 3, 0, 3, 7), Rect2i(0, DIMS.y - 11, 5, 11)]
	for i in rects.size():
		_blit(target, expected, rects[i], _pattern(rects[i].size, fmt, i + 1))
	await RenderingServer.frame_post_draw
	_check(target, expected, fmt, "boundary_patches_same_frame")
	# Two disjoint plus overlapping patches submitted before any frame fence.
	var same_frame_rects: Array[Rect2i] = [Rect2i(13, 17, 31, 19), Rect2i(63, 61, 18, 33), Rect2i(29, 23, 27, 14)]
	for i in same_frame_rects.size():
		_blit(target, expected, same_frame_rects[i], _pattern(same_frame_rects[i].size, fmt, i + 13))
	await RenderingServer.frame_post_draw
	_check(target, expected, fmt, "disjoint_and_overlap_order_same_frame")
	# Reuse a source texture, alternating immutable images, with a blit before
	# each update. This proves command order for the current renderer only.
	var patch_dims := Vector2i(16, 13)
	var patch_a := _pattern(patch_dims, fmt, 73)
	var patch_b := _pattern(patch_dims, fmt, 91)
	var reused := ImageTexture.create_from_image(patch_a)
	sources.append(reused)
	target.blit_rect(Rect2i(101, 103, patch_dims.x, patch_dims.y), reused, Color.WHITE, 0, copy_material)
	var rgba_a: Image = patch_a.duplicate()
	rgba_a.convert(Image.FORMAT_RGBA8)
	expected.blit_rect(rgba_a, Rect2i(Vector2i.ZERO, patch_dims), Vector2i(101, 103))
	reused.update(patch_b)
	target.blit_rect(Rect2i(139, 143, patch_dims.x, patch_dims.y), reused, Color.WHITE, 0, copy_material)
	var rgba_b: Image = patch_b.duplicate()
	rgba_b.convert(Image.FORMAT_RGBA8)
	expected.blit_rect(rgba_b, Rect2i(Vector2i.ZERO, patch_dims), Vector2i(139, 143))
	await RenderingServer.frame_post_draw
	_check(target, expected, fmt, "source_texture_reuse_order_same_frame")
	# Full overwrite remains exact after sparse publications.
	_blit(target, expected, Rect2i(Vector2i.ZERO, DIMS), _pattern(DIMS, fmt, 199))
	await RenderingServer.frame_post_draw
	_check(target, expected, fmt, "full_refresh_after_partial")
	sources.clear()

func _pattern(size: Vector2i, fmt: Image.Format, salt: int) -> Image:
	var bpp := 1 if fmt == Image.FORMAT_R8 else 2
	var data := PackedByteArray()
	data.resize(size.x * size.y * bpp)
	for i in size.x * size.y:
		data[i * bpp] = (i * 37 + salt * 53) % 256
		if bpp == 2:
			data[i * bpp + 1] = (i * 19 + salt * 17) % 256
	data[0] = 0 if salt % 2 == 0 else 255
	if bpp == 2:
		data[1] = 255 if salt % 2 == 0 else 0
	return Image.create_from_data(size.x, size.y, false, fmt, data)

func _blit(target: DrawableTexture2D, expected: Image, rect: Rect2i, patch: Image) -> void:
	var tex := ImageTexture.create_from_image(patch)
	sources.append(tex)
	target.blit_rect(rect, tex, Color.WHITE, 0, copy_material)
	var rgba: Image = patch.duplicate()
	rgba.convert(Image.FORMAT_RGBA8)
	expected.blit_rect(rgba, Rect2i(Vector2i.ZERO, rect.size), rect.position)

func _check(target: DrawableTexture2D, expected: Image, fmt: int, label: String) -> void:
	var actual := target.get_image()
	var ok := actual != null and actual.get_format() == Image.FORMAT_RGBA8 and actual.get_size() == DIMS
	var mismatch := -1
	if ok:
		var lhs := actual.get_data()
		var rhs := expected.get_data()
		ok = lhs == rhs
		if not ok:
			for i in mini(lhs.size(), rhs.size()):
				if lhs[i] != rhs[i]:
					mismatch = i
					break
	if not ok:
		failures.append("format=%d stage=%s first_mismatch_byte=%d" % [fmt, label, mismatch])
	records.append({"format": "R8" if fmt == Image.FORMAT_R8 else "RG8", "stage": label, "pass": ok, "first_mismatch_byte": mismatch})

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--output" and i + 1 < args.size():
			i += 1
			output_path = args[i]
		elif args[i].begins_with("--output="):
			output_path = args[i].trim_prefix("--output=")
		elif args[i] == "--diagnostic":
			diagnostic_enabled = true
		elif args[i] == "--diagnostic-samples" and i + 1 < args.size():
			i += 1
			diagnostic_samples = clampi(int(args[i]), 8, 128)
		i += 1

func _diagnostic() -> void:
	# This deliberately serializes every update with full readback. It is an API
	# attribution experiment, separate from realistic frame-cadence benchmarks.
	# Same immutable Image versus one-cell-different alternating immutable Images
	# can reveal whether the renderer is eliding identical submitted contents.
	for side in [512, 1024, 2048]:
		for fmt in [Image.FORMAT_R8, Image.FORMAT_RG8]:
			var a := Image.create(side, side, false, fmt)
			a.fill(Color(17.0 / 255.0, 127.0 / 255.0, 0, 1))
			var b: Image = a.duplicate()
			b.set_pixel(side / 2, side / 2, Color(255.0 / 255.0, 1.0, 0, 1))
			for change in [false, true]:
				var tex := ImageTexture.create_from_image(a)
				var samples: Array = []
				for sample_index in range(-2, diagnostic_samples):
					var chosen := b if change and sample_index % 2 == 0 else a
					var t0 := Time.get_ticks_usec()
					tex.update(chosen)
					var t1 := Time.get_ticks_usec()
					RenderingServer.force_sync()
					var t2 := Time.get_ticks_usec()
					var actual := tex.get_image()
					var t3 := Time.get_ticks_usec()
					if actual == null or actual.get_data() != chosen.get_data():
						failures.append("diagnostic readback mismatch side=%d fmt=%d change=%s sample=%d" % [side, fmt, change, sample_index])
					if sample_index >= 0:
						samples.append({
							"sample": sample_index,
							"image_texture_update_us": t1 - t0,
							"render_command_queue_sync_us": t2 - t1,
							"readback_including_completion_us": t3 - t2,
						})
				diagnostics.append({
					"world_dimensions": [side, side],
					"format": "R8" if fmt == Image.FORMAT_R8 else "RG8",
					"contents": "one_cell_alternates" if change else "identical_image_repeated",
					"logical_upload_bytes_per_call": side * side * (1 if fmt == Image.FORMAT_R8 else 2),
					"samples": samples,
				})
				await process_frame
