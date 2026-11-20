extends "res://tests/pubpres_transition.gd"

# Replay the registered inputs separately. Full texture readback here must
# never change the timed fixture's render queue or frame intervals.
func _run() -> void:
	var compact := OS.get_environment("CYBERSAND_PUBPRES_PROBE_SKIP_HISTORY") == "1"
	var mode := "compact" if compact else "clone"
	root.size = Vector2i(960, 720)
	RenderingServer.call_on_render_thread(Callable(DisplayServer, "window_set_vsync_mode").bind(DisplayServer.VSYNC_DISABLED))
	_build_host()
	await RenderingServer.frame_post_draw
	_check(strategy == "blit", "history oracle requires the blit publisher")
	_check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "VSync must be disabled")
	var expected := host.image.duplicate() as Image
	var previous_rid: RID = host.previous_texture.get_rid()
	var current_rid: RID = host.texture.get_rid()
	_check(current_rid.is_valid() and previous_rid.is_valid() and current_rid != previous_rid,
		"initial history targets must be distinct")
	var current_matches := 0
	var previous_matches := 0
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
		if index < Warmup:
			continue
		var pixels := expected.get_data()
		var current: Image = host.texture.get_image()
		var previous: Image = host.previous_texture.get_image()
		var current_ok := _matches(current, pixels)
		var previous_ok := _matches(previous, prior)
		current_matches += int(_check(current_ok, "generation %d current GPU bytes differ" % index))
		previous_matches += int(_check(previous_ok, "generation %d previous GPU bytes differ" % index))
		_check(host.image.get_data() == pixels, "generation %d CPU bytes differ" % index)
		var material: Dictionary = row.material
		_check(material.backend == "blit", "generation %d left the blit publisher" % index)
		if row.phase == "enter_sparse":
			var history_copy: bool = material.get("history_copy", false)
			var submitted: int = material.get("submitted_bytes", -1)
			_check(history_copy == (not compact) and submitted == (8388608 if compact else 32768),
				"generation %d missed the selected re-entry path" % index)
			if compact:
				_check(material.get("direct_whole", false) and material.get("whole_gpu_copy", false),
					"compact re-entry did not stage a whole frame")
			else:
				_check(material.get("history_staging", false), "clone re-entry did not use history staging")
			if current_ok and previous_ok:
				entry_history.append({"sequence": index, "current_sha256": _hash(current.get_data()),
					"previous_sha256": _hash(previous.get_data())})
	_check(entry_history.size() == 15, "all 15 sparse entries must match")
	var result := {"schema": "pubpres-warp-history-oracle-v1", "case": Case, "mode": mode,
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
