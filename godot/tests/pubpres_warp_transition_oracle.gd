extends "res://tests/pubpres_transition.gd"

# Replay the registered inputs separately. Full texture readback here must
# never change the timed fixture's render queue or frame intervals.
func _run() -> void:
	var compact := OS.get_environment("CYBERSAND_PUBPRES_PROBE_SKIP_HISTORY") == "1"
	var direct := OS.get_environment("CYBERSAND_PUBPRES_PROBE_DIRECT_DRAWABLE") == "1"
	var is_steady := OS.get_environment("CYBERSAND_PUBPRES_PROBE_STEADY_SPARSE") == "1"
	var is_fixed := OS.get_environment("CYBERSAND_PUBPRES_PROBE_FIXED_MATERIAL") == "1"
	var expect_warp_full := "--expect-warp-full" in OS.get_cmdline_user_args()
	var mode := "direct_drawable" if direct else ("compact" if compact else "clone")
	if is_steady:
		mode = "steady_sparse"
	elif is_fixed:
		mode = "fixed_material"
	elif expect_warp_full:
		mode = "warp_full"
	root.size = Vector2i(960, 720)
	RenderingServer.call_on_render_thread(Callable(DisplayServer, "window_set_vsync_mode").bind(DisplayServer.VSYNC_DISABLED))
	_build_host()
	await RenderingServer.frame_post_draw
	_check(strategy == "blit", "history oracle requires a blit request")
	if expect_warp_full:
		var adapter := RenderingServer.get_video_adapter_name()
		_check(RenderingServer.get_current_rendering_driver_name() == "opengl3_angle"
			and "Microsoft Basic Render Driver" in adapter and "Direct3D11" in adapter,
			"expected the Windows ANGLE WARP renderer")
	_check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "VSync must be disabled")
	var expected := host.image.duplicate() as Image
	var previous_rid: RID = host.previous_texture.get_rid()
	var current_rid: RID = host.texture.get_rid()
	_check(current_rid.is_valid() and previous_rid.is_valid() and current_rid != previous_rid,
		"initial history targets must be distinct")
	var current_matches := 0
	var previous_matches := 0
	var warmup_history := {}
	var entry_history: Array[Dictionary] = []
	for index: int in range(Warmup + Samples):
		var prior := expected.get_data()
		var input := _input(index)
		var region: Rect2i = input.region
		expected.blit_rect(input.patch, Rect2i(Vector2i.ZERO, region.size), region.position)
		var row := _submit(index)
		await RenderingServer.frame_post_draw
		_check(host.texture.get_rid() == previous_rid and host.previous_texture.get_rid() == current_rid,
			"generation %d changed or failed to rotate history targets" % index)
		current_rid = host.texture.get_rid()
		previous_rid = host.previous_texture.get_rid()
		if index < Warmup - 1:
			continue
		var pixels := expected.get_data()
		var current: Image = host.texture.get_image()
		var previous: Image = host.previous_texture.get_image()
		var current_ok := _matches(current, pixels)
		var previous_ok := _matches(previous, prior)
		if index == Warmup - 1:
			if _check(current_ok and previous_ok, "warm-up GPU history differs from exact tape"):
				warmup_history = {"current_matches": true, "previous_matches": true,
					"current_sha256": _hash(current.get_data()), "previous_sha256": _hash(previous.get_data())}
			continue
		current_matches += int(_check(current_ok, "generation %d current GPU bytes differ" % index))
		previous_matches += int(_check(previous_ok, "generation %d previous GPU bytes differ" % index))
		_check(host.image.get_data() == pixels, "generation %d CPU bytes differ" % index)
		var material: Dictionary = row.material
		if expect_warp_full:
			_check(material.backend == "full" and material.get("policy") == "windows_angle_warp_full"
				and material.get("submitted_bytes") == 8388608 and material.get("fallback_reason") == "",
				"generation %d did not use the WARP full-upload policy" % index)
			if row.phase == "enter_sparse" and current_ok and previous_ok:
				entry_history.append({"sequence": index, "current_sha256": _hash(current.get_data()),
					"previous_sha256": _hash(previous.get_data())})
			continue
		_check(material.backend == "blit", "generation %d left the blit publisher" % index)
		if is_steady:
			_check(row.phase == "sparse" and row.patch_bytes == 128
				and material.get("submitted_bytes") == 32768 and not material.get("history_copy", false)
				and not material.get("direct_whole", false), "generation %d left the steady sparse path" % index)
		if row.phase == "enter_sparse":
			var history_copy: bool = material.get("history_copy", false)
			var submitted: int = material.get("submitted_bytes", -1)
			_check(history_copy == (not compact and not direct) and submitted == (16777216 if direct else (8388608 if compact else 32768)),
				"generation %d missed the selected re-entry path" % index)
			if direct:
				_check(material.get("direct_drawable_update", false) and not material.get("whole_gpu_copy", false),
					"direct drawable re-entry did not update the complete same target")
			elif compact:
				_check(material.get("direct_whole", false) and material.get("whole_gpu_copy", false),
					"compact re-entry did not stage a whole frame")
			else:
				_check(material.get("history_staging", false), "clone re-entry did not use history staging")
			if current_ok and previous_ok:
				entry_history.append({"sequence": index, "current_sha256": _hash(current.get_data()),
					"previous_sha256": _hash(previous.get_data())})
	_check(entry_history.size() == (0 if is_steady else 15), "sparse entries must match the selected tape")
	var history := _check_history()
	var result := {"schema": "pubpres-warp-history-oracle-v1", "case": Case, "mode": mode,
		"tape": "steady_sparse" if is_steady else ("fixed_material" if is_fixed else "transition"),
		"history": history, "warmup_history": warmup_history,
		"complete": failures.is_empty(), "failures": failures, "frames_checked": Samples,
		"current_matches": current_matches, "previous_matches": previous_matches,
		"sparse_entries": entry_history.size(), "entry_history": entry_history,
		"initial_plane_sha256": initial_sha,
		"context": Context.identity(get_script().resource_path, host.world_shader.shader)}
	var receipt := FileAccess.open(output, FileAccess.WRITE)
	if receipt == null:
		push_error("PUBPRES WARP history oracle could not write its receipt")
		quit(2)
		return
	receipt.store_string(JSON.stringify(result) + "\n")
	receipt.close()
	host.world_view.free()
	host.free()
	quit(int(not failures.is_empty()))


func _matches(texture_image: Image, pixels: PackedByteArray) -> bool:
	return texture_image != null and texture_image.get_size() == Extent \
		and texture_image.get_format() == Image.FORMAT_RG8 and texture_image.get_data() == pixels
