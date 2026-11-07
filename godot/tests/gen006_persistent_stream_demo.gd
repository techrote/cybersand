extends Control

# GEN-006 opt-in long-lived World session. One single-owner native subprocess
# retains its native Worlds and simulates on a 100ms tick; no OS.execute() on
# input or frame. The mailbox is atomic and bounded; only copied RGBA crosses.
# This is NOT the admitted shared-World/GDExtension production interface.
const SIDE: int = 64
const FRAME_BYTES: int = SIDE * SIDE * 4
const DISPLAY_SIZE: float = 640.0
const DISPLAY_ORIGIN: Vector2 = Vector2(28.0, 76.0)
const MAX_QUEUE: int = 16

var native_pid: int = -1
var save_root: String = ""
var control_root: String = ""
var texture: ImageTexture
var latest_image: Image
var latest_frame: int = 0
var native_ticks: int = 0
var observed_workers: int = 0
var resident_count: int = 0
var active_chunk: Vector2i = Vector2i(-1, -3)
var intended_chunk: Vector2i = Vector2i(-1, -3)
var selected_cell: Vector2i = Vector2i(18, 30)
var last_error: String = ""
var last_receipt: String = ""
var commands: Array[String] = []
var pending_id: int = 0
var next_id: int = 1
var pending_command: String = ""
var round_trips: int = 0
var heartbeat_usec: int = 0
var started_usec: int = 0
var verify_enabled: bool = false
var verify_step: int = 0
var verify_frame: int = 0
var verified_empty: Color
var verified_wall: Color
var verify_failure: bool = false


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_process_unhandled_key_input(true)
    verify_enabled = OS.get_environment("GEN006_PERSISTENT_VERIFY") == "1"
    var executable: String = OS.get_environment("GEN006_PERSISTENT_EXECUTABLE")
    if executable.is_empty() or not FileAccess.file_exists(executable):
        _error("GEN006_PERSISTENT_EXECUTABLE must name the compiled native session.")
        return
    save_root = OS.get_environment("GEN006_PERSISTENT_ROOT")
    if save_root.is_empty():
        save_root = ProjectSettings.globalize_path("user://gen006_persistent_world")
    control_root = OS.get_environment("GEN006_PERSISTENT_CONTROL")
    if control_root.is_empty():
        control_root = ProjectSettings.globalize_path(
            "user://gen006_mailbox_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
    if DirAccess.make_dir_recursive_absolute(save_root) != OK or \
            DirAccess.make_dir_recursive_absolute(control_root) != OK:
        _error("Cannot create native session save/mailbox directories.")
        return
    _heartbeat()
    native_pid = OS.create_process(executable, PackedStringArray([
        "--serve", save_root, control_root, "1"
    ]), false)
    if native_pid <= 0:
        _error("Failed to spawn native persistent-session executable.")
        return
    started_usec = Time.get_ticks_usec()
    set_process(true)


func _heartbeat() -> void:
    if control_root.is_empty():
        return
    var path: String = control_root.path_join("heartbeat.txt")
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_line(str(Time.get_ticks_usec()))
        file.close()
    heartbeat_usec = Time.get_ticks_usec()


func _error(reason: String) -> void:
    last_error = reason
    push_error("GEN006_PERSISTENT_GODOT_FAIL " + reason)
    queue_redraw()
    if verify_enabled and not verify_failure:
        verify_failure = true
        get_tree().quit(1)


func _queue_action(command: String) -> void:
    if commands.size() >= MAX_QUEUE:
        last_error = "Native command queue full: %d pending actions" % MAX_QUEUE
        queue_redraw()
        return
    commands.append(command)


func _dispatch_next() -> void:
    if pending_id != 0 or commands.is_empty():
        return
    var target: String = control_root.path_join("command.txt")
    if FileAccess.file_exists(target):
        return
    var candidate: String = commands[0]
    var temporary: String = control_root.path_join("command.prepared")
    var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        _error("Cannot write native session request.")
        return
    file.store_line("%d %s" % [next_id, candidate])
    file.close()
    if DirAccess.rename_absolute(temporary, target) != OK:
        _error("Cannot atomically publish native session request.")
        return
    commands.pop_front()
    pending_id = next_id
    pending_command = candidate
    next_id += 1


func _poll_ack() -> void:
    if pending_id == 0:
        return
    var target: String = control_root.path_join("ack.txt")
    if not FileAccess.file_exists(target):
        return
    var parts: PackedStringArray = FileAccess.get_file_as_string(target).strip_edges().split(
        " ", false, 3
    )
    if parts.size() != 4 or parts[0] != "ACK":
        return
    if int(parts[1]) != pending_id:
        return
    DirAccess.remove_absolute(target)
    last_receipt = "%s: %s %s" % [pending_command, parts[2], parts[3]]
    if parts[2] == "ERR":
        last_error = last_receipt
        if verify_enabled:
            _error("Native session rejected verification action: " + last_receipt)
    elif parts[2] != "OK":
        _error("Unrecognized native session receipt: " + last_receipt)
    else:
        last_error = ""
        round_trips += 1
    pending_id = 0
    pending_command = ""
    queue_redraw()


func _poll_frame() -> void:
    var state_path: String = control_root.path_join("state.txt")
    if not FileAccess.file_exists(state_path):
        return
    var parts: PackedStringArray = FileAccess.get_file_as_string(state_path).strip_edges().split(
        " ", false
    )
    if parts.size() != 9 or parts[0] != "FRAME":
        return
    var frame: int = int(parts[1])
    if frame <= latest_frame:
        return
    var filename: String = parts[8]
    if filename.get_file() != filename or not filename.begins_with("frame-") or \
            not filename.ends_with(".rgba"):
        _error("Invalid native frame filename.")
        return
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(
        control_root.path_join(filename)
    )
    if bytes.size() != FRAME_BYTES:
        # Frames are bounded and old ones may expire after a desktop stall.
        # Retry at the next source-published frame rather than showing garbage.
        return
    var image: Image = Image.create_from_data(SIDE, SIDE, false, Image.FORMAT_RGBA8, bytes)
    if texture == null:
        texture = ImageTexture.create_from_image(image)
    else:
        texture.update(image)
    latest_image = image
    active_chunk = Vector2i(int(parts[2]), int(parts[3]))
    native_ticks = int(parts[4])
    resident_count = int(parts[5])
    observed_workers = int(parts[6])
    latest_frame = frame
    queue_redraw()


func _pixel(x: int, y: int) -> Color:
    if latest_image == null:
        return Color(-1.0, -1.0, -1.0)
    return latest_image.get_pixel(x, y)


func _verify() -> void:
    if verify_failure:
        return
    if Time.get_ticks_usec() - started_usec > 30000000:
        _error("Native persistent Godot integration timed out.")
        return
    if latest_frame == 0 or texture == null:
        return
    if pending_id != 0 or not commands.is_empty():
        return
    match verify_step:
        0:
            if native_ticks < 2:
                return
            verify_frame = latest_frame
            _queue_action("DIG 8 8")
            verify_step = 1
        1:
            if latest_frame <= verify_frame:
                return
            verified_empty = _pixel(8, 8)
            verify_frame = latest_frame
            _queue_action("WALL 8 8")
            verify_step = 2
        2:
            if latest_frame <= verify_frame:
                return
            verified_wall = _pixel(8, 8)
            if verified_wall == verified_empty:
                _error("Native Wall edit did not change actual RGBA framebuffer.")
                return
            _queue_action("FOCUS 0 -3")
            verify_step = 3
        3:
            if active_chunk != Vector2i(0, -3):
                return
            _queue_action("FOCUS 24 -3")
            verify_step = 4
        4:
            if active_chunk != Vector2i(24, -3) or resident_count != 2:
                return
            _queue_action("FOCUS -1 -3")
            verify_step = 5
        5:
            if active_chunk != Vector2i(-1, -3):
                return
            if _pixel(8, 8) != verified_wall:
                _error("Native Wall changed after real eviction and reload.")
                return
            if not OS.is_process_running(native_pid) or observed_workers < 1:
                _error("Persistent native process died or performed no real work.")
                return
            _queue_action("SAVE")
            verify_step = 6
        6:
            _queue_action("QUIT")
            verify_step = 7
        7:
            print("GEN006_PERSISTENT_GODOT_PASS"
                + " persistent_pid=1 autonomous_native_ticks=1"
                + " paint=1 real_eviction_reload=1 native_rgba=1"
                + " frames=%d configured_workers=1 observed_workers=%d" %
                    [latest_frame, observed_workers])
            get_tree().quit(0)


func _process(_delta: float) -> void:
    if native_pid <= 0:
        return
    if Time.get_ticks_usec() - heartbeat_usec > 1000000:
        _heartbeat()
    _poll_frame()
    _poll_ack()
    if not OS.is_process_running(native_pid) and verify_step < 7:
        _error("Persistent native World process exited unexpectedly.")
        return
    _dispatch_next()
    if verify_enabled:
        _verify()


func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    var movement: Vector2i = Vector2i.ZERO
    match key.keycode:
        KEY_LEFT: movement = Vector2i(-1, 0)
        KEY_RIGHT: movement = Vector2i(1, 0)
        KEY_UP: movement = Vector2i(0, -1)
        KEY_DOWN: movement = Vector2i(0, 1)
        KEY_HOME:
            intended_chunk = Vector2i(-1, -3)
            _queue_action("FOCUS -1 -3")
        KEY_SPACE:
            _queue_action("PAUSE" if not paused else "RESUME")
            paused = not paused
        KEY_R: _queue_action("STATUS")
        KEY_S: _queue_action("SAVE")
    if movement != Vector2i.ZERO:
        intended_chunk += movement * (24 if key.shift_pressed else 1)
        _queue_action("FOCUS %d %d" % [intended_chunk.x, intended_chunk.y])
    get_viewport().set_input_as_handled()


var paused: bool = false


func _gui_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton):
        return
    var button: InputEventMouseButton = event as InputEventMouseButton
    if not button.pressed:
        return
    var local: Vector2 = (button.position - DISPLAY_ORIGIN) * (
        float(SIDE) / DISPLAY_SIZE
    )
    if local.x < 0 or local.y < 0 or local.x >= SIDE or local.y >= SIDE:
        return
    selected_cell = Vector2i(int(local.x), int(local.y))
    match button.button_index:
        MOUSE_BUTTON_LEFT:
            _queue_action("WALL %d %d" % [selected_cell.x, selected_cell.y])
        MOUSE_BUTTON_RIGHT:
            _queue_action("DIG %d %d" % [selected_cell.x, selected_cell.y])
        MOUSE_BUTTON_MIDDLE:
            _queue_action("WATER %d %d 17 417" % [selected_cell.x, selected_cell.y])
    accept_event()
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1220"), true)
    var font: Font = ThemeDB.fallback_font
    draw_string(font, Vector2(28, 31), "GEN-006 / Persistent Native World [experimental]",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#e2edfe"))
    draw_string(font, Vector2(28, 55),
        "Arrows: camera  Shift+arrows: 1536px  Left: Wall  Right: Dig  Middle: Water17  Space: pause  S: save",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a8bad6"))
    draw_rect(Rect2(DISPLAY_ORIGIN, Vector2(DISPLAY_SIZE, DISPLAY_SIZE)),
        Color("#060912"), true)
    if texture != null:
        draw_texture_rect(texture, Rect2(DISPLAY_ORIGIN,
            Vector2(DISPLAY_SIZE, DISPLAY_SIZE)), false)
    var cursor: Vector2 = DISPLAY_ORIGIN + Vector2(selected_cell) * 10.0
    draw_rect(Rect2(cursor, Vector2(10.0, 10.0)),
        Color("#f6db8e"), false, 1.0)
    draw_string(font, Vector2(710, 105),
        "Native PID: %d  |  Alive: %s" % [
            native_pid, str(native_pid > 0 and OS.is_process_running(native_pid))],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d8eaff"))
    draw_string(font, Vector2(710, 136),
        "Camera chunk: (%d, %d)" % [active_chunk.x, active_chunk.y],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d8eaff"))
    draw_string(font, Vector2(710, 166),
        "World pixels: (%d, %d)" % [active_chunk.x * SIDE, active_chunk.y * SIDE],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b8cce4"))
    draw_string(font, Vector2(710, 196),
        "Native ticks: %d  |  Live Worlds: %d/2" % [native_ticks, resident_count],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b8cce4"))
    draw_string(font, Vector2(710, 226),
        "Native observed workers: %d" % observed_workers,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b8cce4"))
    draw_string(font, Vector2(710, 256),
        "Frames: %d  |  commands: %d  |  queued: %d" % [
            latest_frame, round_trips, commands.size() + int(pending_id != 0)],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b8cce4"))
    draw_string(font, Vector2(710, 290), last_receipt.left(74),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b0c4da"))
    if not last_error.is_empty():
        draw_string(font, Vector2(710, 324), last_error.left(70),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ff9977"))
    draw_string(font, Vector2(28, 751),
        "OPT-IN SINGLE-OWNER SHARDS: no cross-shard Water, live Rapier, shared-World eviction or production ABI.",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f1ab71"))


func _exit_tree() -> void:
    # Independent terminal mailbox signal. Native session saves authoritative
    # state and releases its single-writer lock even if a normal command is
    # outstanding when the Godot window closes.
    if native_pid > 0 and not control_root.is_empty():
        var file: FileAccess = FileAccess.open(
            control_root.path_join("shutdown.txt"), FileAccess.WRITE)
        if file != null:
            file.store_line("stop")
            file.close()
