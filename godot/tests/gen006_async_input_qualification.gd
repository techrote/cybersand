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

    # A frame still showing (-2,2) must never permit a click to paint the
    # unrendered destination (22,2). This is an explicit refusal, not a queue.
    _key(demo, KEY_RIGHT, true)
    _click(demo, 9, 9, MOUSE_BUTTON_LEFT)
    if demo.queued_actions.size() != 0 or not demo.input_refusal.contains("NOT submitted") or \
            demo.acknowledged_edits != 1:
        _fail("stale-frame edit was misrouted or silently accepted")
        return
    # Real native camera demand across 1536 px and beyond the 2-World budget.
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

    # Slow native checkpoint/ACK simulation: pause the ACTUAL compiled native
    # owner process, submit a real Wall edit and let Godot render for >5 seconds.
    # This used to turn a recoverable slow reply into a sticky failed scene.
    # The native child is always resumed before checking any failure condition.
    demo.set_process(false)
    demo.focus_dirty = false
    var pre_stall_deadline := Time.get_ticks_msec() + 6000
    while demo.ipc_outstanding and Time.get_ticks_msec() < pre_stall_deadline:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding or not demo.failure.is_empty():
        _fail("could not drain native camera refresh before slow checkpoint test")
        return
    var stop_result := OS.execute("/usr/bin/kill", PackedStringArray([
        "-STOP", str(native_pid)
    ]))
    if stop_result != 0:
        _fail("could not stop isolated native test child")
        return
    var ack_before_stall: int = demo.acknowledged_edits
    _click(demo, 10, 10, MOUSE_BUTTON_LEFT)
    demo._service_live_ipc()
    var submitted: bool = demo.ipc_outstanding and demo.queued_actions.is_empty()
    demo.set_process(true)
    await create_timer(6.2).timeout
    await RenderingServer.frame_post_draw
    var slow_image: Image = root.get_texture().get_image()
    var slow_frame_valid: bool = (
        slow_image != null and slow_image.get_width() >= 1280
        and slow_image.get_height() >= 800
    )
    var slow_saved: bool = false
    if slow_frame_valid:
        slow_saved = slow_image.save_png(
            evidence.path_join("09-slow-native-ack.png")
        ) == OK
    var survived: bool = (
        submitted and demo.failure.is_empty() and demo.ipc_outstanding
        and demo.ipc_slow_warning and demo.ipc_slow_count >= 1
        and demo.ipc_pending_msec >= 5000
        and demo.acknowledged_edits == ack_before_stall
        and demo.native_pid == native_pid and demo.server_pid == native_pid
        and OS.is_process_running(native_pid)
        and slow_frame_valid and slow_saved
    )
    var resume_result := OS.execute("/usr/bin/kill", PackedStringArray([
        "-CONT", str(native_pid)
    ]))
    if resume_result != 0 or not survived:
        _fail("slow native checkpoint falsely failed, ACKed or froze the Godot"
            + " framebuffer: " + demo.failure
            + " age_ms=" + str(demo.ipc_pending_msec)
            + " ack=" + str(demo.acknowledged_edits)
            + " slow=" + str(demo.ipc_slow_warning))
        return
    demo.set_process(false)
    demo.focus_dirty = false
    var resume_deadline := Time.get_ticks_msec() + 12000
    while demo.ipc_outstanding and Time.get_ticks_msec() < resume_deadline:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding or not demo.failure.is_empty() or \
            demo.acknowledged_edits != ack_before_stall + 1 or \
            demo.ipc_slow_warning or demo.last_call_usec < 5000000 or \
            demo.native_pid != native_pid:
        _fail("resumed native owner did not deliver the original durable ACK"
            + " / " + demo.failure + " / " + demo.last_receipts.right(280))
        return
    demo.interactive_async = false
    demo._invoke(PackedStringArray(["inspect 10 10"]), false, true)
    if not demo.failure.is_empty() or not demo.last_receipts.contains("intent=1"):
        _fail("slow-ACK Wall edit missing from authoritative native cells")
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

    # Close immediately after another real player edit: _exit_tree's
    # bounded drain must publish its durable ACK before native quit. Reopen
    # using a SECOND real native process and inspect the saved Wall intent.
    demo.interactive_async = true
    _click(demo, 9, 9, MOUSE_BUTTON_LEFT)
    if demo.queued_actions.size() != 1:
        _fail("shutdown durability edit was not queued")
        return
    demo._send_quit()
    if demo.acknowledged_edits != 3 or demo.ipc_outstanding or \
            not demo.queued_actions.is_empty() or OS.is_process_running(native_pid):
        _fail("bounded graceful shutdown lost queued native ACK or live PID")
        return
    if not FileAccess.file_exists(demo.ipc_root.path_join("stopped.txt")):
        _fail("native stopped receipt absent after edit drain")
        return
    demo.interactive_async = false
    demo.ipc_root = demo.save_root.path_join(
        "async-reopen-%d" % Time.get_ticks_usec()
    )
    if DirAccess.make_dir_recursive_absolute(demo.ipc_root) != OK:
        _fail("cannot create fresh native restart IPC root")
        return
    demo._start_controller()
    if demo.native_pid <= 0 or demo.native_pid == native_pid or \
            demo.server_pid != demo.native_pid or not demo.failure.is_empty():
        _fail("independent native restart failed")
        return
    demo.world_chunk = Vector2i(-2, 2)
    demo._invoke(PackedStringArray(["inspect 9 9"]), false, true)
    if not demo.failure.is_empty() or \
            not demo.last_receipts.contains("chunk=(-2,2) local=(9,9)") or \
            not demo.last_receipts.contains("intent=1"):
        _fail("restarted native World did not preserve shutdown-drained edit"
            + " " + demo.last_receipts.right(300))
        return

    print("GEN006_GODOT_ASYNC_INPUT_PASS"
        + " real_gl_framebuffer=1"
        + " compiled_native_owner=1"
        + " stable_native_pid=%d" % native_pid
        + " enqueue_usec=%d" % input_usec
        + " queued_player_edit_ack=1"
        + " six_second_native_stall_recovered=1"
        + " slow_edit_durable_ack=1"
        + " slow_host_ipc_ms=%d" % int(demo.ipc_peak_latency_usec / 1000)
        + " shutdown_drained_second_edit=1"
        + " native_restart_edit_preserved=1"
        + " captured_chunk_identity=1"
        + " coalesced_camera_requests=1"
        + " native_evictions=%d" % demo.eviction_receipts
        + " native_reloads=%d" % demo.reload_receipts
        + " continuous_tick_receipt=%d" % demo.service_ticks
        + " initial_tick_receipt=%d" % native_ticks
        + " screenshots=1")
    quit(0)
