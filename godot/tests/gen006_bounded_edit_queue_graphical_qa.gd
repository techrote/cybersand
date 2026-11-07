extends SceneTree

# Independent GEN-006 acceptance of bounded player-edit admission under a
# stalled ACTUAL native World/controller. This is NOT a synthetic IPC oracle.
# Runs against the pinned builder #486 source; no builder or physics edits.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")
const FIRST_X := 7
const ACCEPTED_EDITS := 17 # one in flight + exactly sixteen queued
const REFUSED_X := FIRST_X + ACCEPTED_EDITS
var stopped_pid: int = -1


func _initialize() -> void:
    call_deferred("_run")


func _signal(pid: int, signal_name: String) -> bool:
    return OS.execute("/bin/kill",
        PackedStringArray([signal_name, str(pid)]), [], true) == 0


func _resume() -> bool:
    if stopped_pid <= 0:
        return true
    var pid := stopped_pid
    stopped_pid = -1
    return _signal(pid, "-CONT")


func _fail(reason: String) -> void:
    _resume() # Never strand a stopped genuine native process.
    push_error("GEN006_BOUNDED_QUEUE_GRAPHICAL_FAIL " + reason)
    quit(1)


func _wall(demo: Control, x: int) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    event.position = Vector2(28.0 + float(x) * 10.0 + 5.0,
        76.0 + 8.0 * 10.0 + 5.0)
    demo._gui_input(event)


func _frame(path: String) -> Image:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var img: Image = root.get_texture().get_image()
    if img == null or img.get_width() < 1280 or img.get_height() < 800:
        return null
    if img.save_png(path) != OK:
        return null
    return img


func _hud_pixel_differences(a: Image, b: Image) -> int:
    # This is the real framebuffer's IPC/queue/ACK status row, not a
    # screenshot of an invented widget or a test-only success string.
    var changed := 0
    for y in range(220, 249):
        for x in range(710, 1240):
            var p: Color = a.get_pixel(x, y)
            var q: Color = b.get_pixel(x, y)
            if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.25:
                changed += 1
    return changed


func _run() -> void:
    var evidence := OS.get_environment("GEN006_QUEUE_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("missing actual framebuffer evidence directory")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or \
            demo.native_pid <= 0 or demo.server_pid != demo.native_pid or \
            demo.world_chunk != Vector2i(-2, 2) or demo.texture == null:
        _fail("actual native/Godot controller did not start: " + demo.failure)
        return
    var pid: int = demo.native_pid

    # Drain any normal 10Hz camera refresh before stopping the real owner.
    # This ensures there is no unrelated in-flight request or stale reply.
    demo.set_process(false)
    demo.focus_dirty = false
    var drain_deadline := Time.get_ticks_msec() + 7500
    while demo.ipc_outstanding and Time.get_ticks_msec() < drain_deadline:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding or not demo.failure.is_empty():
        _fail("pre-stall request did not drain: " + demo.failure)
        return
    var before: Image = await _frame(evidence.path_join("00-empty-queue.png"))
    if before == null:
        _fail("actual before-frame missing")
        return

    if not _signal(pid, "-STOP"):
        _fail("cannot suspend actual compiled native process")
        return
    stopped_pid = pid
    var state_lines: Array = []
    var state_rc := OS.execute("/bin/ps",
        PackedStringArray(["-o", "stat=", "-p", str(pid)]), state_lines, true)
    var state: String = str(state_lines[0]).strip_edges() \
        if not state_lines.is_empty() else ""
    if state_rc != 0 or not state.begins_with("T"):
        _fail("actual stopped-process state not verified: " + state)
        return

    # One real mouse click is submitted to the stopped native owner; 16
    # additional clicks are queued. The 18th click MUST be refused, not lost
    # silently, falsely ACKed, or sent as an unbounded edit command.
    var first_usec := Time.get_ticks_usec()
    _wall(demo, FIRST_X)
    demo._service_live_ipc()
    if not demo.ipc_outstanding or not demo.queued_actions.is_empty():
        _fail("first edit did not become the one in-flight owner command")
        return
    for x in range(FIRST_X + 1, REFUSED_X):
        _wall(demo, x)
    _wall(demo, REFUSED_X)
    var input_usec := Time.get_ticks_usec() - first_usec
    if input_usec > 500000 or demo.queued_actions.size() != 16 or \
            demo.acknowledged_edits != 0 or not demo.ipc_outstanding or \
            not demo.input_refusal.contains("16 pending actions") or \
            not demo.input_refusal.contains("NOT submitted"):
        _fail("bounded queue overflow was not visibly refused or input blocked:"
            + " input_us=" + str(input_usec)
            + " queued=" + str(demo.queued_actions.size())
            + " ack=" + str(demo.acknowledged_edits)
            + " refusal=" + demo.input_refusal)
        return

    # The genuine Godot frame loop must keep rendering, with changed HUD
    # pixels, while its native process remains stopped at the OS level.
    demo.set_process(true)
    var frames_before := Engine.get_frames_drawn()
    await create_timer(0.35).timeout
    var queued: Image = await _frame(evidence.path_join("01-queue-saturated.png"))
    var frames_during_stop := Engine.get_frames_drawn() - frames_before
    demo.set_process(false)
    var hud_delta := _hud_pixel_differences(before, queued) if queued != null else 0
    if queued == null or frames_during_stop < 5 or hud_delta < 30 or \
            not demo.failure.is_empty() or \
            demo.acknowledged_edits != 0 or demo.queued_actions.size() != 16 or \
            demo.native_pid != pid:
        _fail("Godot stopped rendering, falsely ACKed or obscured queue saturation"
            + " frames=" + str(frames_during_stop)
            + " hud_delta=" + str(hud_delta)
            + " failure=" + demo.failure)
        return

    if not _resume():
        _fail("could not resume actual native controller")
        return
    # Manual nonblocking pump, without 10Hz refresh noise: every submitted
    # player action gets exactly one sequence and one durable ACK.
    var deadline := Time.get_ticks_msec() + 110000
    while Time.get_ticks_msec() < deadline:
        demo._service_live_ipc()
        if not demo.failure.is_empty():
            break
        if not demo.ipc_outstanding and demo.queued_actions.is_empty():
            break
        await process_frame
    if not demo.failure.is_empty() or demo.ipc_outstanding or \
            not demo.queued_actions.is_empty() or \
            demo.acknowledged_edits != ACCEPTED_EDITS or \
            demo.native_pid != pid or demo.server_pid != pid or \
            not OS.is_process_running(pid):
        _fail("queued native edits did not drain with exact durable ACKs:"
            + " ack=" + str(demo.acknowledged_edits)
            + " queued=" + str(demo.queued_actions.size())
            + " outstanding=" + str(demo.ipc_outstanding)
            + " failure=" + demo.failure)
        return

    # Inspect ALL seventeen authoritative native cells, not just samples.
    # The refused eighteenth edit must have no player edit-intent tombstone.
    demo.interactive_async = false
    for x in range(FIRST_X, REFUSED_X + 1):
        demo._invoke(PackedStringArray(["inspect %d 8" % x]), false, true)
        var expected_intent := "intent=0" if x == REFUSED_X else "intent=1"
        if not demo.failure.is_empty() or \
                not demo.last_receipts.contains("CELL chunk=(-2,2) local=(%d,8)" % x) or \
                not demo.last_receipts.contains(expected_intent):
            _fail("native cell authority does not match ACK/refusal x="
                + str(x) + " expected=" + expected_intent
                + " receipt=" + demo.last_receipts.right(300))
            return
    var recovered: Image = await _frame(evidence.path_join("02-queue-drained.png"))
    if recovered == null:
        _fail("actual recovered framebuffer missing")
        return
    print("GEN006_BOUNDED_QUEUE_GRAPHICAL_PASS"
        + " real_native_sigstop_sigcont=1"
        + " accepted_edits=%d" % ACCEPTED_EDITS
        + " refusal_without_edit=1"
        + " durable_acks=%d" % demo.acknowledged_edits
        + " frames_during_stop=%d" % frames_during_stop
        + " ipc_hud_changed_pixels=%d" % hud_delta
        + " queue_capacity=16"
        + " stable_native_pid=%d" % pid
        + " input_enqueue_usec=%d" % input_usec
        + " authoritative_intent_checked=1 screenshots=3")
    quit(0)
