extends "res://tests/pubpres_transition.gd"

# Untimed production-Main oracle for the explicit three-slot Full experiment.
# The frozen two-slot oracle remains unchanged. This uses its complete retained
# transition tape and first-read byte comparisons, with a three-resource
# ownership rule that additionally forbids updating either preceding history.
func _run() -> void:
	root.size = Vector2i(960, 720)
	RenderingServer.call_on_render_thread(Callable(DisplayServer, "window_set_vsync_mode").bind(DisplayServer.VSYNC_DISABLED))
	_check(not steady_sparse and not fixed_material, "source comparison requires the retained transition tape")
	_check(strategy == "full" and OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS") == "3",
		"three-slot Full experiment must be explicitly requested")
	_build_host()
	_check(host._material_full_ring != null, "production Main did not create the three-slot owner")
	if host._material_full_ring == null:
		quit(1)
		return
	var resource_ids: PackedInt64Array = host._material_full_ring.resource_identity()
	_check(resource_ids.size() == 3, "exactly three full-image owners required")
	await RenderingServer.frame_post_draw
	_check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "VSync must be disabled")
	var expected: Image = _initial_plane()
	var previous_rid: RID = host.previous_texture.get_rid()
	var current_rid: RID = host.texture.get_rid()
	_check(current_rid.is_valid() and previous_rid.is_valid() and current_rid != previous_rid,
		"initial history targets must be distinct")
	var current_matches := 0
	var previous_matches := 0
	var warmup_history := {}
	var admissions: Array[Dictionary] = []
	var entry_history: Array[Dictionary] = []
	for index: int in range(Warmup + Samples):
		var prior := expected.get_data()
		var input := _input(index)
		var region: Rect2i = input.region
		expected.blit_rect(input.patch, Rect2i(Vector2i.ZERO, region.size), region.position)
		var row := _submit(index)
		await RenderingServer.frame_post_draw
		_check(host.texture.get_rid() != previous_rid and host.texture.get_rid() != current_rid
			and host.previous_texture.get_rid() == current_rid,
			"generation %d failed spare-only update or exact preceding history" % index)
		_check(host._material_full_ring.resource_identity() == resource_ids
			and host.material_publication_status().full_image_slots == 3
			and host._material_full_ring.allocated_logical_gpu_bytes() == 3*Extent.x*Extent.y*Channels,
			"generation %d changed resource ownership, slot count or logical allocation" % index)
		current_rid = host.texture.get_rid()
		previous_rid = host.previous_texture.get_rid()
		if index < Warmup - 1:
			continue
		var current: Image = host.texture.get_image()
		var previous: Image = host.previous_texture.get_image()
		var pixels := expected.get_data()
		var current_ok := _matches(current, pixels)
		var previous_ok := _matches(previous, prior)
		if index == Warmup - 1:
			if _check(current_ok and previous_ok, "warm-up histories differ from the retained tape"):
				warmup_history = {"current_matches": true, "previous_matches": true,
					"current_sha256": _hash(current.get_data()), "previous_sha256": _hash(previous.get_data())}
			continue
		current_matches += int(_check(current_ok, "generation %d current GPU bytes differ" % index))
		previous_matches += int(_check(previous_ok, "generation %d previous GPU bytes differ" % index))
		_check(host.image.get_data() == pixels, "generation %d CPU bytes differ" % index)
		admissions.append({"sequence": index, "revision": host.last_uploaded_revision,
			"material": row.material, "current_matches": current_ok, "previous_matches": previous_ok})
		if row.phase == "enter_sparse" and current_ok and previous_ok:
			entry_history.append({"sequence": index, "current_sha256": _hash(current.get_data()),
				"previous_sha256": _hash(previous.get_data())})
	_check(entry_history.size() == 15, "missing dense-to-sparse re-entry history")
	var history := _check_history()
	var result := {"schema": "pubpres-full-image-ring-transition-history-v1", "resource_count":resource_ids.size(), "full_image_slots":3, "case": Case, "tape": "transition",
		"complete": failures.is_empty(), "failures": failures, "frames_checked": Samples,
		"current_matches": current_matches, "previous_matches": previous_matches,
		"sparse_entries": entry_history.size(), "entry_history": entry_history, "admissions": admissions,
		"history": history, "warmup_history": warmup_history, "initial_plane_sha256": initial_sha,
		"application_main_sha256": FileAccess.get_sha256("res://scripts/main.gd"),
		"publisher_sha256":FileAccess.get_sha256("res://scripts/full_image_ring_publisher.gd"),
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"context": Context.identity(get_script().resource_path, host.world_shader.shader)}
	var receipt := FileAccess.open(output, FileAccess.WRITE)
	if receipt == null:
		push_error("PUBPRES source transition oracle could not write its receipt")
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
