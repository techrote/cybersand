extends SceneTree

# Real Godot/OpenGL + compiled native owner acceptance for the opt-in
# NONBLOCKING gameplay IPC lane. Existing deterministic synchronous graphical
# qualification remains separate and unchanged.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("GEN006_GODOT_ASYNC_INPUT_FAIL " + reason)
    quit(1)


func _key(demo: Control, keycode: int, shifted: bool = false) -> void:
    var event := InputEventKey.new()
    event.keycode = keycode
    event.shift_pressed = shifted
    event.pressed = true
    demo._unhandled_key_input(event)


func _click(demo: Control, x: int, y: int, button: int) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = button
    event.pressed = true
    event.position = Vector2(28.0 + x * 10.0 + 5.0, 76.0 + y * 10.0 + 5.0)
    demo._gui_input(event)


func _await_render(demo: Control, target: Vector2i, minimum_acks: int) -> bool:
    var deadline := Time.get_ticks_msec() + 12000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            print("GEN006_ASYNC_NATIVE_REFUSAL " + demo.failure)
            return false
        if demo.displayed_chunk == target and demo.acknowledged_edits >= minimum_acks:
            return true
    return false


func _run() -> void:
    var evidence := OS.get_environment("GEN006_ASYNC_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("missing or invalid GEN006_ASYNC_EVIDENCE")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or demo.texture == null:
        _fail("live async Godot scene did not initialize: " + demo.failure)
        return
    var native_pid: int = demo.native_pid
    var native_ticks: int = demo.service_ticks
    var initial_calls: int = demo.total_calls
    if native_pid <= 0 or demo.server_pid != native_pid:
        _fail("compiled native service PID receipt absent")
        return

    # All of these inputs occur before any subsequent _process frame.
    # A synchronous native request per input would violate the live contract.
    # The Wall edit must remain bound to (-2,2) despite subsequent camera moves.
    var started := Time.get_ticks_usec()
    _click(demo, 8, 8, MOUSE_BUTTON_LEFT)
    for i in range(12):
        _key(demo, KEY_RIGHT)
        _key(demo, KEY_LEFT)
    _key(demo, KEY_RIGHT, true)
    _key(demo, KEY_HOME)
    var input_usec := Time.get_ticks_usec() - started
    if input_usec > 500000 or demo.total_calls != initial_calls or \
            demo.queued_actions.size() != 1 or not demo.focus_dirty or \
            demo.world_chunk != Vector2i(-2, 2):
        _fail("live input blocked on native, lost edit, or queued camera history"
            + " elapsed_usec=" + str(input_usec)
            + " calls=" + str(demo.total_calls)
            + " pending=" + str(demo.queued_actions.size()))
        return
    if not await _await_render(demo, Vector2i(-2, 2), 1):
        _fail("native edit ACK/initial asynchronous frame missing")
        return
    if demo.queued_actions.size() != 0 or not demo.input_refusal.is_empty():
        _fail("queued edit not drained or falsely refused")
        return

    # Real native camera demand across 1536 px and beyond the 2-World budget.
    _key(demo, KEY_RIGHT, true)
    if not await _await_render(demo, Vector2i(22, 2), 1):
        _fail("far requested native frame not displayed")
        return
    _key(demo, KEY_RIGHT)
    if not await _await_render(demo, Vector2i(23, 2), 1):
        _fail("third signed native demand not displayed")
        return
    _key(demo, KEY_HOME)
    if not await _await_render(demo, Vector2i(-2, 2), 1):
        _fail("return to edited native chunk not displayed")
        return
    if demo.eviction_receipts < 1 or demo.reload_receipts < 1 or \
            demo.native_pid != native_pid or demo.server_pid != native_pid:
        _fail("real native residency/identity not preserved; evict="
            + str(demo.eviction_receipts) + " reload="
            + str(demo.reload_receipts))
        return

    # Finish the asynchronous pipeline before using the retained synchronous
    # diagnostic path solely to inspect the real authoritative native cell.
    var deadline := Time.get_ticks_msec() + 6000
    while demo.ipc_outstanding and Time.get_ticks_msec() < deadline:
        await process_frame
    if demo.ipc_outstanding:
        _fail("pending live native response did not drain")
        return
    demo.interactive_async = false
    demo._invoke(PackedStringArray(["inspect 8 8"]), false, true)
    if not demo.failure.is_empty() or not demo.last_receipts.contains("intent=1"):
        _fail("player Wall intent lost or applied to wrong chunk: "
            + demo.failure + " / " + demo.last_receipts.right(400))
        return
    if demo.native_pid != native_pid or demo.server_pid != native_pid:
        _fail("persistent native service changed process during async input")
        return

    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.get_width() < 1280 or image.get_height() < 800:
        _fail("no actual OpenGL framebuffer")
        return
    var image_path := evidence.path_join("08-async-home.png")
    if image.save_png(image_path) != OK:
        _fail("cannot preserve actual async Godot framebuffer")
        return

    print("GEN006_GODOT_ASYNC_INPUT_PASS"
        + " real_gl_framebuffer=1"
        + " compiled_native_owner=1"
        + " stable_native_pid=%d" % native_pid
        + " enqueue_usec=%d" % input_usec
        + " queued_player_edit_ack=1"
        + " captured_chunk_identity=1"
        + " coalesced_camera_requests=1"
        + " native_evictions=%d" % demo.eviction_receipts
        + " native_reloads=%d" % demo.reload_receipts
        + " continuous_tick_receipt=%d" % demo.service_ticks
        + " initial_tick_receipt=%d" % native_ticks
        + " screenshots=1")
    quit(0)
