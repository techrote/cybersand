extends SceneTree

# Independent actual native/Godot regression of the new signed Go input while
# the real compiled owner is SIGSTOP-ed during an unacknowledged player edit.
# No mock IPC, native World changes, or builder-owned source edits.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")
var stopped_pid: int = -1


func _initialize() -> void:
    call_deferred("_run")


func _signal(pid: int, action: String) -> bool:
    return OS.execute("/bin/kill", PackedStringArray([action, str(pid)]),
        [], true) == 0


func _resume() -> bool:
    if stopped_pid <= 0:
        return true
    var pid := stopped_pid
    stopped_pid = -1
    return _signal(pid, "-CONT")


func _fail(reason: String) -> void:
    _resume()
    push_error("GEN006_SIGNED_GO_STALLED_OWNER_FAIL " + reason)
    quit(1)


func _jump(demo: Control, x: int, y: int) -> void:
    demo.jump_x_edit.text = str(x)
    demo.jump_y_edit.text = str(y)
    demo.jump_go_button.pressed.emit()


func _wall(demo: Control, x: int, y: int) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    event.position = Vector2(28 + x * 10 + 5, 76 + y * 10 + 5)
    demo._gui_input(event)


func _capture(evidence: String, name: String) -> Image:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var screenshot: Image = root.get_texture().get_image()
    if screenshot == null or screenshot.get_width() != 1280 or screenshot.get_height() != 800:
        return null
    if screenshot.save_png(evidence.path_join(name + ".png")) != OK:
        return null
    return screenshot


func _loading_orange(image: Image) -> int:
    var orange := 0
    for y in range(682, 709):
        for x in range(710, 1230):
            var p := image.get_pixel(x, y)
            if p.r > 0.72 and p.r > 1.15 * p.g and p.g > 1.18 * p.b:
                orange += 1
    return orange


func _await_display(demo: Control, target: Vector2i, min_ack: int) -> bool:
    var deadline := Time.get_ticks_msec() + 18000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.displayed_chunk == target and demo.acknowledged_edits >= min_ack:
            return true
    return false


func _run() -> void:
    var evidence := OS.get_environment("GEN006_SIGNED_STALL_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("evidence path not writable")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    var original := Vector2i(-2, 2)
    if not demo.failure.is_empty() or not demo.interactive_async or demo.texture == null \
            or demo.native_pid <= 0 or demo.native_pid != demo.server_pid \
            or demo.displayed_chunk != original:
        _fail("actual Godot/native controller did not initialize: " + demo.failure)
        return
    var pid: int = demo.native_pid
    var before: Image = await _capture(evidence, "00-signed-go-live")
    if before == null:
        _fail("initial actual OpenGL frame missing")
        return
    var initial_orange := _loading_orange(before)

    # Drain incidental startup refresh before freezing the native OS process.
    demo.interactive_async = false
    demo.focus_dirty = false
    var deadline := Time.get_ticks_msec() + 6500
    while demo.ipc_outstanding and Time.get_ticks_msec() < deadline:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding or not demo.failure.is_empty():
        _fail("startup refresh failed to drain before native suspension")
        return
    demo.refresh_accumulator = 0.0
    demo.interactive_async = true
    var baseline_calls: int = demo.total_calls
    var baseline_evictions: int = demo.eviction_receipts

    if not _signal(pid, "-STOP"):
        _fail("actual native owner SIGSTOP failed")
        return
    stopped_pid = pid
    var ps_output: Array = []
    var state_rc := OS.execute("/bin/ps",
        PackedStringArray(["-o", "stat=", "-p", str(pid)]), ps_output, true)
    var process_state: String = str(ps_output[0]).strip_edges() \
        if not ps_output.is_empty() else ""
    if state_rc != 0 or not process_state.begins_with("T"):
        _fail("native OS process not genuinely stopped: " + process_state)
        return

    # Native cannot acknowledge this wall edit while stopped.
    _wall(demo, 8, 8)
    demo._service_live_ipc()
    if not demo.ipc_outstanding or demo.acknowledged_edits != 0 \
            or not demo.queued_actions.is_empty():
        _fail("player edit was not exactly one unacknowledged native request")
        return

    # Exercise the NEW UI button, not arrow-key navigation. Rapid far demands
    # must coalesce to one final target while the original edit remains bound.
    var started_usec := Time.get_ticks_usec()
    _jump(demo, 22, 2)
    _jump(demo, 23, 2)
    _jump(demo, -24, 2)
    _jump(demo, 24, 2)
    var enqueue_usec := Time.get_ticks_usec() - started_usec
    _wall(demo, 9, 9)
    if enqueue_usec > 500000 or demo.world_chunk != Vector2i(24, 2) \
            or not demo.focus_dirty or demo.displayed_chunk != original \
            or not demo.input_refusal.contains("NOT submitted") \
            or demo.acknowledged_edits != 0 or demo.total_calls != baseline_calls \
            or not demo.queued_actions.is_empty() or not demo.ipc_outstanding:
        _fail("signed Go camera coalescing, stale-frame edit refusal or nonblocking input failed")
        return

    var frames_before := Engine.get_frames_drawn()
    await create_timer(0.28).timeout
    var stopped: Image = await _capture(evidence, "01-signed-go-native-stopped")
    var frame_count := Engine.get_frames_drawn() - frames_before
    if stopped == null or frame_count < 5 or not demo.failure.is_empty() \
            or demo.acknowledged_edits != 0 or not demo.ipc_outstanding:
        _fail("Godot rendering or ACK boundary failed during real native stall")
        return
    var loading_delta := _loading_orange(stopped) - initial_orange
    if loading_delta < 20:
        _fail("actual OpenGL LOADING state did not appear after signed Go jump")
        return

    if not _resume():
        _fail("native SIGCONT failed")
        return
    if not await _await_display(demo, Vector2i(24, 2), 1):
        _fail("single latest Go demand / originally pending durable ACK failed: "
            + demo.failure)
        return
    # No 22/23/-24 transient demands should have admitted extra shards.
    if demo.eviction_receipts != baseline_evictions or demo.resident_native_shards > 2:
        _fail("intermediate Go destinations consumed native residency")
        return
    _jump(demo, -24, 2)
    if not await _await_display(demo, Vector2i(-24, 2), 1):
        _fail("second distant signed demand failed: " + demo.failure)
        return
    _jump(demo, -2, 2)
    if not await _await_display(demo, original, 1):
        _fail("edited original native shard failed to reload: " + demo.failure)
        return
    if demo.native_pid != pid or demo.server_pid != pid \
            or demo.eviction_receipts < baseline_evictions + 2 \
            or demo.reload_receipts < 1 or demo.resident_native_shards > 2:
        _fail("genuine eviction/reload, memory budget or stable native PID failed")
        return
    var restored: Image = await _capture(evidence, "02-signed-go-native-restored")
    if restored == null:
        _fail("final actual OpenGL frame missing")
        return

    # Inspect the real native World, not a presentation cache. Do not race an
    # already-issued async request with the diagnostic synchronous inspector.
    demo.set_process(false)
    demo.interactive_async = false
    demo.focus_dirty = false
    deadline = Time.get_ticks_msec() + 7000
    while demo.ipc_outstanding and Time.get_ticks_msec() < deadline:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding:
        _fail("async pipeline failed to drain before authoritative inspection")
        return
    demo._invoke(PackedStringArray(["inspect 8 8", "inspect 9 9"]), false, true)
    if not demo.failure.is_empty() \
            or not demo.last_receipts.contains("CELL chunk=(-2,2) local=(8,8)") \
            or not demo.last_receipts.contains("intent=1") \
            or not demo.last_receipts.contains("CELL chunk=(-2,2) local=(9,9)"):
        _fail("authoritative signed-go return lost original native edit: "
            + demo.last_receipts.right(320))
        return
    print("GEN006_SIGNED_GO_STALLED_OWNER_PASS actual_native=1 actual_gl=1"
        + " sigstop_sigcont=1 native_pid=%d" % pid
        + " coalesced_intermediate_go=3"
        + " durable_original_edit=1 refused_stale_frame=1"
        + " evictions=%d" % demo.eviction_receipts
        + " reloads=%d" % demo.reload_receipts
        + " frame_while_stopped=%d" % frame_count
        + " loading_orange_delta=%d" % loading_delta
        + " enqueue_usec=%d" % enqueue_usec
        + " screenshots=3")
    quit(0)
