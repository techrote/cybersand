extends SceneTree

# Actual native World + Godot 4.7 OpenGL qualification of signed subchunk roaming.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("GEN006_ROAM_SEAM_FAIL " + reason)
    quit(1)


func _jump(demo: Control, x: int, y: int) -> void:
    demo.jump_x_edit.text = str(x)
    demo.jump_y_edit.text = str(y)
    demo.jump_go_button.pressed.emit()


func _await_frame(demo: Control, chunk: Vector2i) -> bool:
    var deadline := Time.get_ticks_msec() + 18000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.displayed_chunk == chunk and demo.native_pid == demo.server_pid:
            return true
    return false


func _capture(directory: String, name: String) -> bool:
    await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image = root.get_texture().get_image()
    return frame != null and frame.get_width() == 1280 and frame.get_height() == 800 \
        and frame.save_png(directory.path_join(name + ".png")) == OK


func _run() -> void:
    var evidence := OS.get_environment("GEN006_ROAM_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("screenshot directory unavailable")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or demo.texture == null:
        _fail("actual native/Godot startup: " + demo.failure)
        return
    var initial_pid: int = demo.native_pid
    if initial_pid <= 0 or initial_pid != demo.server_pid:
        _fail("native PID mismatch")
        return

    # Two actually captured positive signed native frames.
    _jump(demo, 22, 2)
    if not await _await_frame(demo, Vector2i(22, 2)):
        _fail("positive source not admitted")
        return
    demo.roam_button.pressed.emit()
    if not demo.roam_enabled or not demo.roam_frame_cache.has(Vector2i(22, 2)):
        _fail("Roam failed to cache the actual native source frame")
        return
    var origin: Vector2 = demo.roam_origin
    demo._advance_roam(0.1, Vector2.RIGHT)
    if demo.roam_origin != origin or demo.world_chunk != Vector2i(23, 2) or \
            not demo.input_refusal.begins_with("Roam waiting"):
        _fail("uncached seam moved before native request completed")
        return
    if not await _await_frame(demo, Vector2i(23, 2)):
        _fail("positive adjacent frame not loaded")
        return
    demo._advance_roam(0.1, Vector2.RIGHT)
    if demo.roam_origin.x <= origin.x or \
            demo._visible_roam_tiles(demo.roam_origin).size() != 2 or \
            not demo.roam_frame_cache.has(Vector2i(22, 2)) or \
            not demo.roam_frame_cache.has(Vector2i(23, 2)):
        _fail("positive seam failed to compose both real native frames")
        return
    if not await _capture(evidence, "14-positive-seam"):
        _fail("positive original OpenGL capture missing")
        return
    var ack_count: int = demo.acknowledged_edits
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = Vector2(150, 200)
    demo._gui_input(click)
    if not demo.input_refusal.contains("read-only") or \
            demo.acknowledged_edits != ack_count or not demo.queued_actions.is_empty():
        _fail("read-only cached viewport incorrectly permitted edit")
        return
    demo.roam_button.pressed.emit()
    if demo.roam_enabled:
        _fail("Roam OFF failed")
        return

    # Negative-coordinate floor: -24 + 1 -> -23; no truncation to zero.
    _jump(demo, -24, 2)
    if not await _await_frame(demo, Vector2i(-24, 2)):
        _fail("negative source not admitted")
        return
    demo.roam_button.pressed.emit()
    var neg_origin: Vector2 = demo.roam_origin
    demo._advance_roam(0.1, Vector2.RIGHT)
    if demo.roam_origin != neg_origin or demo.world_chunk != Vector2i(-23, 2):
        _fail("negative signed prefetch incorrect")
        return
    if not await _await_frame(demo, Vector2i(-23, 2)):
        _fail("negative adjacent native frame not loaded")
        return
    demo._advance_roam(0.1, Vector2.RIGHT)
    if demo.roam_origin.x <= neg_origin.x or \
            demo._visible_roam_tiles(demo.roam_origin).size() != 2 or \
            not demo.roam_frame_cache.has(Vector2i(-24, 2)) or \
            not demo.roam_frame_cache.has(Vector2i(-23, 2)):
        _fail("negative seam failed to compose real native frames")
        return
    if not await _capture(evidence, "15-negative-seam"):
        _fail("negative original OpenGL capture missing")
        return
    if demo.native_pid != initial_pid or demo.server_pid != initial_pid or \
            demo.resident_native_shards > 2 or demo.roam_frame_cache.size() > 8 or \
            demo.eviction_receipts < 1 or demo.acknowledged_edits != ack_count:
        _fail("native PID, residency budget, edit refusal or eviction failed")
        return
    print("GEN006_ROAM_SEAM_PASS actual_native=1 actual_gl=1"
        + " positive=(22,2)-(23,2) negative=(-24,2)-(-23,2)"
        + " stable_native_pid=%d" % initial_pid
        + " freeze_before_unloaded_seam=1 edit_refused=1"
        + " residency_max_2=1 screenshots=2")
    quit(0)
