extends SceneTree
# Actual compiled native World and real Godot OpenGL brush acceptance.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("GEN006_BRUSH_FAIL " + reason)
    quit(1)
func _point(x: int) -> Vector2:
    return Vector2(28.0 + x * 10.0 + 5.0, 76.0 + 12.0 * 10.0 + 5.0)
func _run() -> void:
    var evidence := OS.get_environment("GEN006_DRAG_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("evidence path unavailable")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or demo.native_pid <= 0:
        _fail("real native owner unavailable " + demo.failure)
        return
    var original_pid: int = demo.native_pid
    var down := InputEventMouseButton.new()
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    down.position = _point(12)
    demo._gui_input(down)
    var move := InputEventMouseMotion.new()
    move.position = _point(16)
    move.button_mask = MOUSE_BUTTON_MASK_LEFT
    demo._gui_input(move)
    var up := InputEventMouseButton.new()
    up.button_index = MOUSE_BUTTON_LEFT
    up.position = _point(16)
    up.pressed = false
    demo._gui_input(up)
    if demo.queued_actions.size() != 5 or demo.acknowledged_edits != 0:
        _fail("missing interpolated edits or false durable ACK")
        return
    for i in range(5):
        if demo.queued_actions[i]["chunk"] != Vector2i(-2, 2) or \
                demo.queued_actions[i]["command"] != ("wall %d 12" % (12 + i)):
            _fail("signed chunk binding / stroke ordering")
            return
    var deadline := Time.get_ticks_msec() + 45000
    while (demo.acknowledged_edits < 5 or demo.ipc_outstanding or
            not demo.queued_actions.is_empty()) and Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            _fail("actual native command rejected " + demo.failure)
            return
    if demo.acknowledged_edits != 5 or demo.native_pid != original_pid:
        _fail("actual native ACKs/PID not preserved")
        return
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.get_width() != 1280 or image.get_height() != 800 or \
            image.save_png(evidence.path_join("10-native-drag.png")) != OK:
        _fail("actual Godot OpenGL screenshot absent")
        return
    demo.set_process(false)
    demo.focus_dirty = false
    var drained := Time.get_ticks_msec() + 8000
    while demo.ipc_outstanding and Time.get_ticks_msec() < drained:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding:
        _fail("refresh in-flight not drained")
        return
    demo.interactive_async = false
    for x in range(12, 17):
        demo._invoke(PackedStringArray(["inspect %d 12" % x]), false, true)
        if not demo.failure.is_empty() or \
                not demo.last_receipts.contains("CELL chunk=(-2,2) local=(%d,12)" % x) or \
                not demo.last_receipts.contains("intent=1"):
            _fail("missing real native Wall intent " + str(x))
            return
    demo._send_quit()
    if OS.is_process_running(original_pid):
        _fail("initial native process still running")
        return
    demo.ipc_root = demo.save_root.path_join("brush-restart-%d" % Time.get_ticks_usec())
    if DirAccess.make_dir_recursive_absolute(demo.ipc_root) != OK:
        _fail("second native IPC directory unavailable")
        return
    demo._start_controller()
    if demo.native_pid == original_pid or demo.native_pid <= 0 or not demo.failure.is_empty():
        _fail("independent native restart failed")
        return
    for x in range(12, 17):
        demo._invoke(PackedStringArray(["inspect %d 12" % x]), false, true)
        if not demo.failure.is_empty() or \
                not demo.last_receipts.contains("CELL chunk=(-2,2) local=(%d,12)" % x) or \
                not demo.last_receipts.contains("intent=1"):
            _fail("restarted native World lost stroke " + str(x))
            return
    print("GEN006_GODOT_BRUSH_PASS actual_native=1 interpolated_cells=5"
        + " durable_acks=5 restart_cells=5 actual_gl=1")
    quit(0)
