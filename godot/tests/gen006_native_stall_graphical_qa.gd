extends SceneTree

# Independent GEN-006 actual-Godot acceptance of a deliberately STALLED real
# native owner. SIGSTOP/SIGCONT targets the compiled controller OS process;
# no synthetic IPC responder, checkpoint fixture or substitute World is used.
# QA-only: builder #486 and protected production source remain unchanged.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")
var suspended_pid: int = -1


func _initialize() -> void:
    call_deferred("_run")


func _signal_native(pid: int, signal_name: String) -> bool:
    return OS.execute("/bin/kill",
        PackedStringArray([signal_name, str(pid)]), [], true) == 0


func _resume_native() -> bool:
    if suspended_pid <= 0:
        return true
    var pid := suspended_pid
    suspended_pid = -1
    return _signal_native(pid, "-CONT")


func _fail(reason: String) -> void:
    # A failed assertion must never strand a SIGSTOP-ed native child.
    _resume_native()
    push_error("GEN006_NATIVE_STALL_GRAPHICAL_FAIL " + reason)
    quit(1)


func _key(demo: Control, keycode: int, shift: bool = false) -> void:
    var event := InputEventKey.new()
    event.keycode = keycode
    event.shift_pressed = shift
    event.pressed = true
    demo._unhandled_key_input(event)


func _click_wall(demo: Control, x: int, y: int) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    event.position = Vector2(28.0 + x * 10.0 + 5.0,
        76.0 + y * 10.0 + 5.0)
    demo._gui_input(event)


func _capture(name: String, directory: String) -> Image:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var screenshot: Image = root.get_texture().get_image()
    if screenshot == null or screenshot.get_width() < 1280 or             screenshot.get_height() < 800:
        return null
    if screenshot.save_png(directory.path_join(name + ".png")) != OK:
        return null
    return screenshot


func _orange_loading_pixels(image: Image) -> int:
    # Restrict to the LOADING/LIVE camera-state line in the real framebuffer;
    # the permanent orange experimental footer cannot satisfy the predicate.
    var count := 0
    for y in range(682, 709):
        for x in range(710, 1230):
            var pixel := image.get_pixel(x, y)
            if pixel.r > 0.72 and pixel.r > 1.15 * pixel.g and                     pixel.g > 1.18 * pixel.b:
                count += 1
    return count


func _await_display(demo: Control, target: Vector2i, ack_count: int) -> bool:
    var deadline := Time.get_ticks_msec() + 18000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.displayed_chunk == target and                 demo.acknowledged_edits >= ack_count:
            return true
    return false


func _run() -> void:
    var evidence := OS.get_environment("GEN006_STALL_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("screenshot evidence directory unavailable")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or             demo.texture == null or demo.native_pid <= 0 or             demo.server_pid != demo.native_pid:
        _fail("actual native/Godot asynchronous controller initialization failed: "
            + demo.failure)
        return
    var native_pid: int = demo.native_pid
    var before: Image = await _capture("00-live-before-stop", evidence)
    if before == null:
        _fail("could not capture initial actual GL framebuffer")
        return
    var before_orange := _orange_loading_pixels(before)
    # Freeze the periodic refresh producer and DRAIN any already-submitted
    # background focus before SIGSTOP. Otherwise a preexisting response can be
    # consumed after suspension and falsify the no-new-ACK assertion.
    demo.interactive_async = false
    demo.focus_dirty = false
    var drain_deadline := Time.get_ticks_msec() + 6500
    while demo.ipc_outstanding and Time.get_ticks_msec() < drain_deadline:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding or not demo.failure.is_empty():
        _fail("pre-stall native refresh did not drain cleanly: " + demo.failure)
        return
    demo.refresh_accumulator = 0.0
    demo.interactive_async = true
    var initial_requests: int = demo.total_calls

    if not _signal_native(native_pid, "-STOP"):
        _fail("could not suspend the actual compiled native owner")
        return
    suspended_pid = native_pid
    # Godot FileAccess may refuse Linux procfs paths even when the PID is
    # stopped. Use the actual host's ps(1) process-state receipt instead.
    var process_state_output: Array = []
    var process_state_rc := OS.execute("/bin/ps",
        PackedStringArray(["-o", "stat=", "-p", str(native_pid)]),
        process_state_output, true)
    var process_state: String = str(process_state_output[0]).strip_edges() \
        if not process_state_output.is_empty() else ""
    if process_state_rc != 0 or not process_state.begins_with("T"):
        _fail("native process not actually stopped: " + process_state)
        return

    # Send one real player edit to the stopped native owner. It cannot ACK
    # until SIGCONT. Godot input must remain responsive in the meantime.
    _click_wall(demo, 8, 8)
    demo._service_live_ipc()
    if not demo.ipc_outstanding or demo.queued_actions.size() != 0 or             demo.acknowledged_edits != 0:
        _fail("stopped native edit did not become one unacknowledged in-flight request")
        return
    var started_usec := Time.get_ticks_usec()
    for i in range(24):
        _key(demo, KEY_RIGHT)
        _key(demo, KEY_LEFT)
    _key(demo, KEY_RIGHT, true)
    var enqueue_usec := Time.get_ticks_usec() - started_usec
    _click_wall(demo, 9, 9) # stale native frame must refuse the wrong chunk
    if enqueue_usec > 500000 or demo.world_chunk != Vector2i(22, 2) or             not demo.focus_dirty or not demo.input_refusal.contains("NOT submitted") or             demo.acknowledged_edits != 0 or demo.total_calls != initial_requests or             not demo.ipc_outstanding:
        _fail("camera/edit input blocked, misrouted or falsely acknowledged"
            + " enqueue_usec=" + str(enqueue_usec)
            + " calls=" + str(demo.total_calls)
            + " refusal=" + demo.input_refusal)
        return

    var drawn_before := Engine.get_frames_drawn()
    await create_timer(0.28).timeout
    var stalled: Image = await _capture("01-native-stopped-ui-live", evidence)
    var frames_while_stopped := Engine.get_frames_drawn() - drawn_before
    if stalled == null or frames_while_stopped < 5 or             not demo.failure.is_empty() or not demo.ipc_outstanding or             demo.acknowledged_edits != 0 or             Time.get_ticks_usec() - started_usec > 4500000:
        _fail("actual Godot frames stopped advancing while native owner was suspended"
            + " frames=" + str(frames_while_stopped) + " error=" + demo.failure)
        return
    var stalled_orange := _orange_loading_pixels(stalled)
    if stalled_orange < before_orange + 20:
        _fail("requested versus displayed chunk not visible in actual GL frame"
            + " before=" + str(before_orange)
            + " stalled=" + str(stalled_orange))
        return

    if not _resume_native():
        _fail("could not resume the native owner")
        return
    if not await _await_display(demo, Vector2i(22, 2), 1):
        _fail("native did not execute previously in-flight edit and latest camera demand: "
            + demo.failure)
        return
    _key(demo, KEY_HOME)
    if not await _await_display(demo, Vector2i(-2, 2), 1):
        _fail("native did not return to signed original chunk: " + demo.failure)
        return
    # Drain any scheduled refresh before using the unchanged synchronous
    # diagnostic inspector to verify actual native cell authority.
    var deadline := Time.get_ticks_msec() + 6000
    demo.interactive_async = false
    while demo.ipc_outstanding and Time.get_ticks_msec() < deadline:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding:
        _fail("native IPC would not drain after resumed service")
        return
    demo._invoke(PackedStringArray(["inspect 8 8"]), false, true)
    if not demo.failure.is_empty() or demo.native_pid != native_pid or             demo.server_pid != native_pid or             not demo.last_receipts.contains("CELL chunk=(-2,2) local=(8,8)") or             not demo.last_receipts.contains("intent=1"):
        _fail("original player edit was lost, owner PID changed or durable ACK incorrect: "
            + demo.failure + " " + demo.last_receipts.right(300))
        return
    var resumed: Image = await _capture("02-native-resumed-edit-confirmed", evidence)
    if resumed == null:
        _fail("actual GL recovery framebuffer missing")
        return
    print("GEN006_NATIVE_STALL_GRAPHICAL_PASS"
        + " compiled_native_owner=1 actual_sigstop_sigcont=1"
        + " rendered_while_owner_stopped=%d" % frames_while_stopped
        + " live_to_loading_orange=%d" % (stalled_orange - before_orange)
        + " enqueue_usec=%d" % enqueue_usec
        + " refused_stale_frame_edit=1"
        + " single_native_pid=%d" % native_pid
        + " durable_original_chunk_edit=1"
        + " latest_camera_coalesced=1"
        + " screenshots=3")
    quit(0)
