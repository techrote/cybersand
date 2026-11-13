extends SceneTree

# Actual compiled native World and Godot OpenGL signed-coordinate UI acceptance.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("GEN006_SIGNED_JUMP_FAIL " + message)
    quit(1)


func _jump(demo: Control, x: String, y: String) -> void:
    demo.jump_x_edit.text = x
    demo.jump_y_edit.text = y
    demo.jump_go_button.pressed.emit()


func _click_wall(demo: Control, x: int, y: int) -> void:
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.pressed = true
    e.position = Vector2(28 + x * 10 + 5, 76 + y * 10 + 5)
    demo._gui_input(e)


func _await_chunk(demo: Control, target: Vector2i, min_acks: int) -> bool:
    var deadline := Time.get_ticks_msec() + 18000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            print("GEN006_JUMP_NATIVE_REFUSED " + demo.failure)
            return false
        if demo.displayed_chunk == target and demo.acknowledged_edits >= min_acks:
            return true
    return false


func _capture(directory: String, name: String) -> bool:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    return image != null and image.get_width() == 1280 and image.get_height() == 800 \
        and image.save_png(directory.path_join(name + ".png")) == OK


func _run() -> void:
    var evidence := OS.get_environment("GEN006_JUMP_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("evidence directory missing")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or demo.texture == null:
        _fail("actual native/Godot scene failed startup: " + demo.failure)
        return
    var native_pid: int = demo.native_pid
    var original := Vector2i(-2, 2)
    var initial_calls: int = demo.total_calls
    if native_pid <= 0 or demo.server_pid != native_pid or demo.world_chunk != original:
        _fail("native identity or original chunk incorrect")
        return
    # Invalid signed coordinates cannot start native work or change the camera.
    _jump(demo, "not-a-number", "2")
    if demo.world_chunk != original or demo.total_calls != initial_calls or \
            demo.focus_dirty or not demo.input_refusal.contains("refused"):
        _fail("malformed coordinate was submitted")
        return
    _jump(demo, "4097", "2")
    if demo.world_chunk != original or demo.focus_dirty or demo.total_calls != initial_calls:
        _fail("positive out-of-domain coordinate was submitted")
        return
    _jump(demo, "-4097", "2")
    if demo.world_chunk != original or demo.focus_dirty or demo.total_calls != initial_calls:
        _fail("negative out-of-domain coordinate was submitted")
        return

    # Authoritative edit survives far camera movement and real shard eviction.
    _click_wall(demo, 8, 8)
    if not await _await_chunk(demo, original, 1):
        _fail("original native edit durable ACK not received")
        return
    var before_jump: int = demo.total_calls
    _jump(demo, "22", "2")
    if demo.world_chunk != Vector2i(22, 2) or demo.total_calls != before_jump or \
            not demo.focus_dirty or not demo.queued_actions.is_empty():
        _fail("jump blocked on native IPC or queued intermediate demands")
        return
    _click_wall(demo, 9, 9)
    if not demo.input_refusal.contains("NOT submitted") or \
            demo.acknowledged_edits != 1 or not demo.queued_actions.is_empty():
        _fail("stale destination frame allowed an edit")
        return
    if not await _await_chunk(demo, Vector2i(22, 2), 1):
        _fail("positive distant signed native demand failed")
        return
    if not await _capture(evidence, "11-positive-jump"):
        _fail("positive OpenGL framebuffer missing")
        return
    _jump(demo, "23", "2")
    if not await _await_chunk(demo, Vector2i(23, 2), 1):
        _fail("third native chunk absent")
        return
    _jump(demo, "-24", "2")
    if not await _await_chunk(demo, Vector2i(-24, 2), 1):
        _fail("negative distant signed native demand failed")
        return
    if not await _capture(evidence, "12-negative-jump"):
        _fail("negative OpenGL framebuffer missing")
        return
    _jump(demo, "-2", "2")
    if not await _await_chunk(demo, original, 1):
        _fail("edited original chunk not restored")
        return
    if not await _capture(evidence, "13-restored-edit"):
        _fail("restored OpenGL framebuffer missing")
        return
    if demo.native_pid != native_pid or demo.server_pid != native_pid or \
            demo.eviction_receipts < 2 or demo.reload_receipts < 1 or \
            demo.resident_native_shards > 2:
        _fail("native owner PID, resident budget or eviction/reload violated")
        return

    demo.set_process(false)
    demo.focus_dirty = false
    var deadline := Time.get_ticks_msec() + 8000
    while demo.ipc_outstanding and Time.get_ticks_msec() < deadline:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding:
        _fail("native response pending before authoritative inspection")
        return
    demo.interactive_async = false
    demo._invoke(PackedStringArray(["inspect 8 8"]), false, true)
    if not demo.failure.is_empty() or not demo.last_receipts.contains(
            "CELL chunk=(-2,2) local=(8,8)") or \
            not demo.last_receipts.contains("intent=1"):
        _fail("authoritative reloaded Wall intent missing: " + demo.last_receipts.right(260))
        return
    print("GEN006_SIGNED_JUMP_PASS actual_native=1 actual_gl=1"
        + " positive_chunk=(22,2) negative_chunk=(-24,2)"
        + " invalid_jump_refusals=3 stale_edit_refusal=1"
        + " native_pid=%d" % native_pid
        + " evictions=%d" % demo.eviction_receipts
        + " reloads=%d" % demo.reload_receipts
        + " persistent_wall=1 screenshots=3")
    quit(0)
