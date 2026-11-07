extends SceneTree

# Windows file-sharing regression against a real native owner and its real ACK.
# The Python companion temporarily opens the published response with no sharing.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.gd")
var demo
var evidence: String

func _initialize() -> void:
    call_deferred("_run")

func _marker(name: String) -> void:
    var file := FileAccess.open(evidence.path_join(name), FileAccess.WRITE)
    file.store_string(name)
    file.close()

func _await_marker(name: String) -> bool:
    var deadline := Time.get_ticks_msec() + 8000
    while Time.get_ticks_msec() < deadline:
        if FileAccess.file_exists(evidence.path_join(name)):
            return true
        await process_frame
    return false

func _finish(ok: bool, reason: String) -> void:
    _marker("release")
    await create_timer(0.1).timeout
    demo._send_quit()
    demo.free()
    print("GEN006_WINDOWS_RESPONSE_READ_%s %s" % ["PASS" if ok else "FAIL", reason])
    quit(0 if ok else 1)

func _run() -> void:
    evidence = OS.get_environment("GEN006_READ_TEST_ROOT")
    demo = DEMO.new()
    demo.native_executable = OS.get_environment("GEN006_SLICE_EXECUTABLE")
    demo.save_root = evidence.path_join("world")
    demo.ipc_root = evidence.path_join("ipc")
    DirAccess.make_dir_recursive_absolute(demo.save_root)
    DirAccess.make_dir_recursive_absolute(demo.ipc_root)
    demo._start_controller()
    if not demo.failure.is_empty():
        await _finish(false, demo.failure)
        return
    demo.interactive_async = true
    demo.ipc_outstanding = true
    demo.ipc_request_was_edit = true
    demo.ipc_request_usec = Time.get_ticks_usec()
    demo._write_request(PackedStringArray(["focus -2 2", "dig 5 5", "inspect 5 5", "render", "status"]))
    _marker("request-sent")
    if not await _await_marker("locked"):
        await _finish(false, "lock handshake timeout")
        return
    for i in range(12):
        demo._service_live_ipc()
        await process_frame
    if not demo.failure.is_empty() or not demo.ipc_outstanding or demo.acknowledged_edits != 0:
        await _finish(false, "locked read consumed/refused native ACK: " + demo.failure)
        return
    _marker("release")
    if not await _await_marker("released"):
        await _finish(false, "unlock handshake timeout")
        return
    demo._service_live_ipc()
    var valid: bool = demo.failure.is_empty() and demo.acknowledged_edits == 1 and not demo.ipc_outstanding and demo.last_receipts.contains("GEN006_EDIT_DURABLE_ACK") and demo.last_receipts.contains("local=(5,5) material=0") and demo.last_receipts.contains("intent=1") and demo.server_pid == demo.native_pid
    print("GEN006_WINDOWS_RESPONSE_READ_RECEIPT " + demo.last_receipts)
    await _finish(valid, "locked_frames=12 ack_after_unlock=%d same_native_pid=%d" % [demo.acknowledged_edits, demo.native_pid])
