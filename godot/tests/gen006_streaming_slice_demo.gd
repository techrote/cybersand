extends Control

# GEN-006 opt-in persistent native-controller demonstration.
# One native process owns the StreamingSlice and its native Worlds for the whole
# Godot scene lifetime. Godot exchanges bounded command/receipt files and copied
# RGBA frames; it never receives mutable native cells. Still NOT production
# shared-World streaming, production GDExtension ownership or cross-shard physics.
const SIDE: int = 64
# Open on a nonempty native-tick-safe cave, not unsafe surface or empty sky.
const DEMO_START: Vector2i = Vector2i(-2, 2)
const DISPLAY_SIZE: float = 640.0
const DISPLAY_TOP_LEFT: Vector2 = Vector2(28.0, 76.0)
const FRAME_BYTES: int = SIDE * SIDE * 4
const CONTROLLER_TICK_HZ: int = 30
const FRAME_REFRESH_SECONDS: float = 0.10
const IPC_TIMEOUT_MSEC: int = 5000
# The interactive host never blocks the Godot render/input thread on native IPC.
# One request is in flight; only 16 explicitly authored actions may be queued.
# Camera refreshes coalesce into a single latest-position demand.
const MAX_QUEUED_ACTIONS: int = 16

var world_chunk := DEMO_START
var selected_cell := Vector2i(18, 30)
var native_executable: String = ""
var save_root: String = ""
var ipc_root: String = ""
var texture: ImageTexture
var last_receipts: String = ""
var failure: String = ""
var total_calls: int = 0
var last_call_usec: int = 0
var native_pid: int = -1
var server_pid: int = -1
var service_ticks: int = 0
var occupied_native_cells: int = -1
var pinned_native_shards: int = 0
var pinned_chunks: PackedStringArray = PackedStringArray()
var resident_native_shards: int = 0
var resident_native_bytes: int = 0
var pin_notice: String = ""
var request_sequence: int = 0
var refresh_accumulator: float = 0.0
var controller_started: bool = false
var interactive_async: bool = false
var ipc_outstanding: bool = false
var ipc_request_chunk: Vector2i = DEMO_START
var ipc_request_usec: int = 0
var ipc_request_was_edit: bool = false
var queued_actions: Array[Dictionary] = []
var focus_dirty: bool = false
var displayed_chunk: Vector2i = DEMO_START
var input_refusal: String = ""
var acknowledged_edits: int = 0
var eviction_receipts: int = 0
var reload_receipts: int = 0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_process_unhandled_key_input(true)
    native_executable = OS.get_environment("GEN006_SLICE_EXECUTABLE")
    if native_executable.is_empty() or not FileAccess.file_exists(native_executable):
        failure = "Set GEN006_SLICE_EXECUTABLE to the compiled streaming-slice executable."
        queue_redraw()
        return
    save_root = OS.get_environment("GEN006_SLICE_ROOT")
    if save_root.is_empty():
        save_root = ProjectSettings.globalize_path("user://gen006_slice_demo")
    if DirAccess.make_dir_recursive_absolute(save_root) != OK:
        failure = "Cannot create private GEN-006 save directory: " + save_root
        queue_redraw()
        return
    ipc_root = save_root.path_join("controller-ipc-%d" % Time.get_ticks_usec())
    if DirAccess.make_dir_recursive_absolute(ipc_root) != OK:
        failure = "Cannot create persistent-controller IPC directory: " + ipc_root
        queue_redraw()
        return
    _start_controller()
    if not failure.is_empty():
        queue_redraw()
        return
    _invoke(PackedStringArray(), false, true)
    controller_started = failure.is_empty() and texture != null
    # The synchronous path is retained only for deterministic scripted native
    # and framebuffer qualification. Real gameplay uses the nonblocking pump.
    interactive_async = OS.get_environment("GEN006_SLICE_FORCE_ASYNC_TEST") == "1" or (
        OS.get_environment("GEN006_SLICE_VERIFY") != "1"
        and OS.get_environment("GEN006_GRAPHICAL_EVIDENCE").is_empty()
    )
    set_process(controller_started)

    # CI smoke uses exactly the same persistent controller and UI script.
    if OS.get_environment("GEN006_SLICE_VERIFY") == "1":
        _invoke(PackedStringArray(), true)
        _qualify_and_quit()


func _start_controller() -> void:
    native_pid = OS.create_process(
        native_executable,
        PackedStringArray([
            "--serve", save_root, ipc_root, "1", str(CONTROLLER_TICK_HZ)
        ]),
        false
    )
    if native_pid <= 0:
        failure = "Cannot launch persistent native GEN-006 controller."
        return
    var ready_path := ipc_root.path_join("ready.txt")
    if not _wait_for_file(ready_path, IPC_TIMEOUT_MSEC):
        failure = "Persistent native controller did not become ready."
        return
    var ready := FileAccess.get_file_as_string(ready_path)
    if not ready.contains("GEN006_STREAM_SERVER_READY"):
        failure = "Invalid persistent-controller ready receipt: " + ready.right(240)
        return
    for field in ready.split(" ", false):
        if field.begins_with("pid="):
            server_pid = int(field.trim_suffix("\n").split("=")[1])
    if server_pid <= 0 or server_pid != native_pid:
        failure = "Persistent-controller PID receipt mismatch."
        return


func _wait_for_file(path: String, timeout_msec: int) -> bool:
    var deadline := Time.get_ticks_msec() + timeout_msec
    while Time.get_ticks_msec() < deadline:
        if FileAccess.file_exists(path):
            return true
        if native_pid > 0 and not OS.is_process_running(native_pid):
            return false
        OS.delay_msec(2)
    return false


func _write_request(commands: PackedStringArray) -> bool:
    request_sequence += 1
    var request_path := ipc_root.path_join("request.txt")
    var staging_path := ipc_root.path_join("request.staging")
    var response_path := ipc_root.path_join("response.txt")
    if FileAccess.file_exists(response_path):
        DirAccess.remove_absolute(response_path)
    if FileAccess.file_exists(request_path):
        failure = "Previous persistent-controller request is still outstanding."
        return false
    var file := FileAccess.open(staging_path, FileAccess.WRITE)
    if file == null:
        failure = "Persistent request open failed: " + str(FileAccess.get_open_error())
        return false
    file.store_string("SEQ %d\n%s\n" % [request_sequence, "\n".join(commands)])
    file.flush()
    file.close()
    if DirAccess.rename_absolute(staging_path, request_path) != OK:
        failure = "Persistent request publication failed."
        return false
    return true


func _read_response(started_usec: int) -> bool:
    var response_path := ipc_root.path_join("response.txt")
    if not _wait_for_file(response_path, IPC_TIMEOUT_MSEC):
        failure = "Persistent native controller response timed out."
        return false
    last_call_usec = Time.get_ticks_usec() - started_usec
    total_calls += 1
    last_receipts = FileAccess.get_file_as_string(response_path)
    DirAccess.remove_absolute(response_path)
    if not last_receipts.begins_with("SEQ %d\n" % request_sequence):
        failure = "Persistent-controller sequence mismatch: " + last_receipts.left(120)
        return false
    if last_receipts.contains("REFUSED "):
        failure = "Native command refused: " + last_receipts.right(350)
        return false
    for line in last_receipts.split("\n", false):
        if line.begins_with("EVICT "):
            eviction_receipts += 1
        elif line.begins_with("RELOAD "):
            reload_receipts += 1
        if line.begins_with("STATUS resident="):
            # Replace the complete roster per native STATUS, not just the
            # last pinned shard. A full budget is only two in this prototype.
            pinned_chunks.clear()
            pin_notice = ""
            for field in line.split(" ", false):
                if field.begins_with("resident="):
                    resident_native_shards = int(field.split("=")[1].split("/")[0])
                elif field.begins_with("pinned="):
                    pinned_native_shards = int(field.split("=")[1])
                elif field.begins_with("native_cell_bytes="):
                    resident_native_bytes = int(field.split("=")[1])
        elif line.begins_with("  chunk=") and line.contains("pinned=1"):
            var pinned_row: String = line.strip_edges()
            pinned_chunks.append(pinned_row)
            pin_notice = pinned_row
        if line.begins_with("GEN006_STREAM_SERVER_STATE "):
            for field in line.split(" ", false):
                if field.begins_with("pid="):
                    server_pid = int(field.split("=")[1])
                elif field.begins_with("continuous_ticks="):
                    service_ticks = int(field.split("=")[1])
        elif line.begins_with("CHUNK_SURVEY "):
            for field in line.split(" ", false):
                if field.begins_with("occupied="):
                    occupied_native_cells = int(field.split("=")[1])
    if server_pid != native_pid:
        failure = "Persistent native process identity changed."
        return false
    return true


func _update_texture() -> bool:
    var bytes := FileAccess.get_file_as_bytes(save_root.path_join("gen006-current.rgba"))
    if bytes.size() != FRAME_BYTES:
        failure = "Expected %d authoritative native RGBA bytes, got %d" % [
            FRAME_BYTES, bytes.size()
        ]
        return false
    var image := Image.create_from_data(SIDE, SIDE, false, Image.FORMAT_RGBA8, bytes)
    if texture == null:
        texture = ImageTexture.create_from_image(image)
    else:
        texture.update(image)
    queue_redraw()
    return true


func _invoke(actions: PackedStringArray, force_eviction: bool = false,
             include_survey: bool = false) -> void:
    if native_pid <= 0 or not OS.is_process_running(native_pid):
        failure = "Persistent native controller is not running."
        queue_redraw()
        return
    if not failure.is_empty():
        queue_redraw()
        return
    var commands := PackedStringArray()
    commands.append("focus %d %d" % [world_chunk.x, world_chunk.y])
    if force_eviction:
        commands.append("focus %d %d" % [world_chunk.x + 1, world_chunk.y])
        commands.append("focus %d %d" % [world_chunk.x + 2, world_chunk.y])
        commands.append("focus %d %d" % [world_chunk.x, world_chunk.y])
    for action in actions:
        commands.append(action)
    if include_survey:
        commands.append("survey")
    commands.append("render")
    commands.append("status")
    var started := Time.get_ticks_usec()
    if not _write_request(commands) or not _read_response(started):
        queue_redraw()
        return
    if _update_texture():
        displayed_chunk = world_chunk


func _queue_live_focus() -> void:
    # Only the latest camera position is relevant. Never create unbounded
    # intermediate native Worlds for rapid arrow-key navigation.
    focus_dirty = true
    queue_redraw()


func _queue_live_action(action: String, is_edit: bool = true) -> void:
    if queued_actions.size() >= MAX_QUEUED_ACTIONS:
        input_refusal = "Input backpressure: 16 pending actions; edit NOT submitted."
        queue_redraw()
        return
    # Bind the edit to the camera chunk at the instant of player input.
    # Later navigation cannot silently paint the destination chunk instead.
    queued_actions.append({
        "chunk": world_chunk, "command": action, "edit": is_edit
    })
    input_refusal = ""
    queue_redraw()


func _start_live_request() -> void:
    if ipc_outstanding or not failure.is_empty():
        return
    var target: Vector2i = world_chunk
    var commands := PackedStringArray()
    var action: Dictionary = {}
    var has_action := not queued_actions.is_empty()
    if has_action:
        action = queued_actions.pop_front()
        target = action["chunk"]
    elif not focus_dirty:
        return
    else:
        focus_dirty = false
    commands.append("focus %d %d" % [target.x, target.y])
    if has_action:
        commands.append(str(action["command"]))
    commands.append("render")
    commands.append("status")
    var started := Time.get_ticks_usec()
    if not _write_request(commands):
        # File publication failed: the action has NOT been handed to native.
        if has_action:
            queued_actions.push_front(action)
        else:
            focus_dirty = true
        queue_redraw()
        return
    ipc_request_chunk = target
    ipc_request_usec = started
    ipc_request_was_edit = has_action and bool(action["edit"])
    ipc_outstanding = true
    queue_redraw()


func _service_live_ipc() -> void:
    if native_pid <= 0 or not OS.is_process_running(native_pid):
        failure = "Persistent native controller stopped; queued edits unconfirmed."
        queue_redraw()
        return
    if ipc_outstanding:
        var response_path := ipc_root.path_join("response.txt")
        if FileAccess.file_exists(response_path):
            # _read_response returns immediately once the response exists.
            var accepted := _read_response(ipc_request_usec)
            ipc_outstanding = false
            if not accepted:
                # An ambiguous or refused edit must never be silently retried.
                input_refusal = "Native response failed; last edit outcome UNKNOWN."
                queue_redraw()
                return
            if ipc_request_was_edit:
                if not last_receipts.contains("GEN006_EDIT_DURABLE_ACK "):
                    failure = "Native edit has no durable ACK; outcome not confirmed."
                    queue_redraw()
                    return
                acknowledged_edits += 1
            if ipc_request_chunk == world_chunk:
                if _update_texture():
                    displayed_chunk = ipc_request_chunk
                    if input_refusal.begins_with("Waiting for native chunk"):
                        input_refusal = ""
            else:
                # A response from an old camera demand must not be displayed
                # as the current destination. Request the latest view next.
                focus_dirty = true
            queue_redraw()
        elif Time.get_ticks_usec() - ipc_request_usec > IPC_TIMEOUT_MSEC * 1000:
            failure = "Native IPC deadline exceeded; outstanding edit state UNKNOWN."
            queue_redraw()
            return
    if not ipc_outstanding and failure.is_empty():
        _start_live_request()


func _send_quit() -> void:
    if native_pid <= 0 or not OS.is_process_running(native_pid):
        return
    if interactive_async:
        # Stop issuing camera refreshes on shutdown. Flush all *submitted and
        # locally queued* player commands through the same durable ACK path
        # before asking the exclusive native owner to quit. Input/render must
        # remain nonblocking during gameplay, but the bounded exit path may wait.
        focus_dirty = false
        var drain_deadline := Time.get_ticks_msec() + 7000
        while (ipc_outstanding or not queued_actions.is_empty()) and \
                Time.get_ticks_msec() < drain_deadline and \
                OS.is_process_running(native_pid) and failure.is_empty():
            _service_live_ipc()
            OS.delay_msec(2)
        if ipc_outstanding or not queued_actions.is_empty() or not failure.is_empty():
            # No success claim: a timeout/exit creates an UNKNOWN edit outcome.
            # Never replay an ambiguously published mutation automatically.
            push_error("GEN006_SHUTDOWN_UNCONFIRMED_EDIT outstanding=%s queued=%d error=%s" % [
                str(ipc_outstanding), queued_actions.size(), failure
            ])
            # Explicitly fail-stop an unresponsive owner. Otherwise a Godot
            # exit would orphan a continuously ticking native child process.
            # Submitted edit outcome remains UNKNOWN, never falsely ACKed.
            OS.kill(native_pid)
            return
    var commands := PackedStringArray(["quit"])
    var started := Time.get_ticks_usec()
    if _write_request(commands):
        _read_response(started)
    var deadline := Time.get_ticks_msec() + 1200
    while OS.is_process_running(native_pid) and Time.get_ticks_msec() < deadline:
        OS.delay_msec(5)
    if OS.is_process_running(native_pid):
        OS.kill(native_pid)


func _exit_tree() -> void:
    set_process(false)
    _send_quit()


func _process(delta: float) -> void:
    if not controller_started or not failure.is_empty():
        return
    if not interactive_async:
        return
    refresh_accumulator += delta
    if refresh_accumulator >= FRAME_REFRESH_SECONDS:
        refresh_accumulator = 0.0
        _queue_live_focus()
    _service_live_ipc()


func _qualify_and_quit() -> void:
    var qualified: bool = (
        texture != null and failure.is_empty()
        and last_receipts.contains("RENDER_RGBA ")
        and last_receipts.contains("EVICT ")
        and last_receipts.contains("RELOAD ")
        and last_receipts.contains("GEN006_STREAM_SERVER_STATE ")
        and native_pid > 0 and server_pid == native_pid
    )
    if qualified:
        print("GEN006_GODOT_NATIVE_FRAME_PASS width=64 height=64"
            + " actual_native_rgba=1 real_eviction=1"
            + " persistent_native_process=1 continuous_service=1")
    else:
        push_error("GEN006_GODOT_NATIVE_FRAME_FAIL " + failure
            + " receipts=" + last_receipts.right(500))
    get_tree().quit(0 if qualified else 1)


func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    var move := Vector2i.ZERO
    match key.keycode:
        KEY_LEFT: move = Vector2i(-1, 0)
        KEY_RIGHT: move = Vector2i(1, 0)
        KEY_UP: move = Vector2i(0, -1)
        KEY_DOWN: move = Vector2i(0, 1)
        KEY_HOME: world_chunk = DEMO_START
        KEY_SPACE:
            if interactive_async:
                _queue_live_action("tick 1", false)
            else:
                _invoke(PackedStringArray(["tick 1"]))
        KEY_R:
            if interactive_async:
                _queue_live_focus()
            else:
                _invoke(PackedStringArray())
    if move != Vector2i.ZERO:
        world_chunk += move * (24 if key.shift_pressed else 1)
        if not interactive_async:
            failure = ""
        # A real camera miss demands one chunk. Do not manufacture an LRU
        # eviction by visiting two unrequested synthetic neighbor chunks.
        if interactive_async:
            _queue_live_focus()
        else:
            _invoke(PackedStringArray(), false, true)
    elif key.keycode == KEY_HOME:
        if not interactive_async:
            failure = ""
        if interactive_async:
            _queue_live_focus()
        else:
            _invoke(PackedStringArray(), false, true)
    elif key.keycode in [KEY_SPACE, KEY_R]:
        get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton):
        return
    var button := event as InputEventMouseButton
    if not button.pressed:
        return
    var local_point: Vector2 = (button.position - DISPLAY_TOP_LEFT) * (
        float(SIDE) / DISPLAY_SIZE
    )
    if local_point.x < 0 or local_point.y < 0 or \
            local_point.x >= SIDE or local_point.y >= SIDE:
        return
    selected_cell = Vector2i(int(local_point.x), int(local_point.y))
    var edit: String = ""
    match button.button_index:
        MOUSE_BUTTON_LEFT:
            edit = "wall %d %d" % [selected_cell.x, selected_cell.y]
        MOUSE_BUTTON_RIGHT:
            edit = "dig %d %d" % [selected_cell.x, selected_cell.y]
        MOUSE_BUTTON_MIDDLE:
            edit = "water %d %d 17" % [selected_cell.x, selected_cell.y]
    if not edit.is_empty():
        if interactive_async:
            if displayed_chunk != world_chunk:
                # No edit may target unrendered terrain under a stale camera
                # frame. The click was NOT sent and cannot be mistaken for ACK.
                input_refusal = "Waiting for native chunk frame: edit NOT submitted."
                queue_redraw()
                accept_event()
                return
            _queue_live_action(edit)
        else:
            _invoke(PackedStringArray([edit]), false, true)
        accept_event()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#0d1220"), true)
    var font: Font = ThemeDB.fallback_font
    draw_string(font, Vector2(28, 30), "GEN-006 / Native World Stream [experimental]", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#dee9fb"))
    draw_string(font, Vector2(28, 54), "Arrows: chunk  |  Shift+arrows: 1536px  |  Home: terrain  |  Left-click: Wall  |  Right-click: dig  |  Middle: Water17  |  Space: tick", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a3b5ce"))
    draw_rect(Rect2(DISPLAY_TOP_LEFT - Vector2(2, 2),
                   Vector2(DISPLAY_SIZE + 4, DISPLAY_SIZE + 4)),
                   Color("#3f5972"), false, 2.0)
    if texture != null:
        draw_texture_rect(texture, Rect2(DISPLAY_TOP_LEFT,
                          Vector2(DISPLAY_SIZE, DISPLAY_SIZE)), false)
    else:
        draw_rect(Rect2(DISPLAY_TOP_LEFT, Vector2(DISPLAY_SIZE, DISPLAY_SIZE)),
                  Color("#080a12"), true)
    var cursor := DISPLAY_TOP_LEFT + Vector2(selected_cell) * (
        DISPLAY_SIZE / float(SIDE)
    )
    draw_rect(Rect2(cursor, Vector2(10, 10)), Color("#f1d876"), false, 1.0)
    var px_x := world_chunk.x * SIDE
    var px_y := world_chunk.y * SIDE
    draw_string(font, Vector2(710, 106),
        "Chunk (%d, %d)" % [world_chunk.x, world_chunk.y],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#e5f0ff"))
    draw_string(font, Vector2(710, 132),
        "World origin (%d, %d) pixels" % [px_x, px_y],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b9c7e3"))
    draw_string(font, Vector2(710, 696),
        "Frame chunk (%d,%d)  |  requested (%d,%d)  |  %s" % [
            displayed_chunk.x, displayed_chunk.y, world_chunk.x, world_chunk.y,
            "LOADING" if displayed_chunk != world_chunk else "LIVE"
        ], HORIZONTAL_ALIGNMENT_LEFT, 530.0, 13,
        Color("#f4a261") if displayed_chunk != world_chunk else Color("#a5be9d"))
    draw_string(font, Vector2(710, 157),
        "Native residency: %d / 2 Worlds  |  cell bytes: %d" % [
            resident_native_shards, resident_native_bytes
        ],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b9c7e3"))
    draw_string(font, Vector2(710, 184),
        "Persistent native PID: %d  |  Requests: %d" % [native_pid, total_calls],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b9c7e3"))
    draw_string(font, Vector2(710, 211),
        "Continuous ticks: %d @ %d Hz  |  Last IPC: %.1f ms" % [
            service_ticks, CONTROLLER_TICK_HZ, float(last_call_usec) / 1000.0
        ], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9caec9"))
    draw_string(font, Vector2(710, 233),
        "IPC %s | queued: %d/%d | durable edit ACKs: %d | evict/reload: %d/%d" % [
            "BUSY" if ipc_outstanding else "READY", queued_actions.size(),
            MAX_QUEUED_ACTIONS, acknowledged_edits, eviction_receipts,
            reload_receipts
        ], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9caec9"))
    draw_string(font, Vector2(710, 370),
        "Copied native RGBA 64x64 (not Godot production shader)",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9caec9"))
    draw_string(font, Vector2(710, 255),
        "Native occupied cells: %d / 4096" % occupied_native_cells,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b6dcaa"))
    var pin_color := Color("#f4a261") if pinned_native_shards > 0 else Color("#9caec9")
    draw_string(font, Vector2(710, 277),
        "Native simulation pins: %d (unsupported shard tick)" % pinned_native_shards,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, pin_color)
    # Show every native simulation pin instead of only the last warning.
    # Pin receipts are taken from the owner-produced resident roster, and the
    # two-shard capacity bounds the number of on-screen lines.
    for i in range(pinned_chunks.size()):
        draw_string(font, Vector2(710, 302 + i * 20),
            "PIN %d/%d: %s" % [i + 1, pinned_chunks.size(), pinned_chunks[i].left(82)],
            HORIZONTAL_ALIGNMENT_LEFT, 540.0, 12, Color("#f4a261"))
    if not input_refusal.is_empty():
        draw_string(font, Vector2(710, 346), input_refusal,
                    HORIZONTAL_ALIGNMENT_LEFT, 550.0, 14, Color("#ff967b"))
    if not failure.is_empty():
        draw_string(font, Vector2(710, 394), failure,
                    HORIZONTAL_ALIGNMENT_LEFT, 550.0, 15, Color("#ff967b"))
    else:
        var lines := last_receipts.split("\n", false)
        var tail := lines.slice(maxi(0, lines.size() - 14))
        for i in range(tail.size()):
            draw_string(font, Vector2(710, 404 + i * 19),
                        tail[i].left(92), HORIZONTAL_ALIGNMENT_LEFT,
                        520.0, 13, Color("#a5be9d"))
    draw_string(font, Vector2(28, 751),
        "EXPERIMENT ONLY: one native World per shard; cross-shard effects, Rapier bodies and production streaming are unsupported.",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f4a261"))
