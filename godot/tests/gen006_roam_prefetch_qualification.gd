extends SceneTree

# Real native process and Godot OpenGL: fetch a future signed tile before it
# appears and cross the following seam without a camera authority change.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("GEN006_ROAM_PREFETCH_FAIL " + reason)
    quit(1)


func _await_chunk(demo: Control, chunk: Vector2i) -> bool:
    var deadline := Time.get_ticks_msec() + 18000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.displayed_chunk == chunk and demo.native_pid == demo.server_pid:
            return true
    return false


func _await_prefetch(demo: Control, chunk: Vector2i) -> bool:
    var deadline := Time.get_ticks_msec() + 18000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.roam_frame_cache.has(chunk) and demo.roam_prefetch_completions > 0:
            return true
    return false


func _capture(directory: String, name: String) -> bool:
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    return image != null and image.get_width() == 1280 and image.get_height() == 800 \
        and image.save_png(directory.path_join(name + ".png")) == OK


func _run() -> void:
    var evidence := OS.get_environment("GEN006_PREFETCH_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("screenshot directory unavailable")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or demo.texture == null:
        _fail("native/Godot initialization: " + demo.failure)
        return
    var pid: int = demo.native_pid
    if pid <= 0 or pid != demo.server_pid:
        _fail("native PID invalid")
        return
    demo.jump_x_edit.text = "22"
    demo.jump_y_edit.text = "2"
    demo.jump_go_button.pressed.emit()
    if not await _await_chunk(demo, Vector2i(22, 2)):
        _fail("source chunk unavailable")
        return
    demo.roam_button.pressed.emit()
    if not demo.roam_enabled or not demo.roam_frame_cache.has(Vector2i(22, 2)):
        _fail("native source pixels not copied")
        return
    var start: Vector2 = demo.roam_origin
    demo._advance_roam(0.1, Vector2.RIGHT)
    if demo.roam_origin != start or demo.world_chunk != Vector2i(23, 2):
        _fail("cold seam did not wait for native owner")
        return
    if not await _await_chunk(demo, Vector2i(23, 2)):
        _fail("first adjacent native tile unavailable")
        return
    for i in range(12):
        demo._advance_roam(0.1, Vector2.RIGHT)
        if demo.world_chunk != Vector2i(23, 2) or not demo.failure.is_empty():
            _fail("lookahead changed current editable chunk")
            return
    if demo.roam_origin.x - start.x < 40.0 or \
            not demo.roam_prefetch_pending or \
            demo.roam_prefetch_chunk != Vector2i(24, 2):
        _fail("missing pre-seam directional lookahead")
        return
    var ack_before: int = demo.acknowledged_edits
    if not await _await_prefetch(demo, Vector2i(24, 2)):
        _fail("prefetch never returned actual native RGBA")
        return
    if demo.world_chunk != Vector2i(23, 2) or demo.displayed_chunk != Vector2i(23, 2):
        _fail("speculative response changed camera/edit authority")
        return
    if not await _capture(evidence, "16-prefetched-before-seam"):
        _fail("original prefetch OpenGL frame missing")
        return
    for i in range(7):
        demo._advance_roam(0.1, Vector2.RIGHT)
        if demo.input_refusal.begins_with("Roam waiting") or \
                demo.world_chunk != Vector2i(23, 2):
            _fail("second seam stalled despite native prefetch")
            return
    if demo.roam_origin.x <= start.x + 64.0 or \
            not demo.roam_frame_cache.has(Vector2i(24, 2)):
        _fail("second signed seam not crossed")
        return
    if not await _capture(evidence, "17-prefetch-crossed-seam"):
        _fail("original post-seam OpenGL frame missing")
        return
    if demo.native_pid != pid or demo.server_pid != pid or \
            demo.resident_native_shards > 2 or demo.roam_frame_cache.size() > 8 or \
            demo.roam_prefetch_requests < 1 or demo.roam_prefetch_completions < 1 or \
            demo.acknowledged_edits != ack_before or \
            not demo.queued_actions.is_empty() or demo.eviction_receipts < 1:
        _fail("residency/cache budget, native PID, or edit authority violated")
        return
    print("GEN006_ROAM_PREFETCH_PASS actual_native=1 actual_gl=1" +
        " source=(22,2) first=(23,2) prefetch=(24,2)" +
        " pre_seam=1 no_second_seam_stall=1 stable_pid=%d" % pid +
        " evictions=1 edit_acks_unchanged=1 screenshots=2")
    quit(0)
