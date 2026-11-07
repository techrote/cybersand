extends Control

# GEN-006 opt-in, process-backed Godot demonstration.
# The native executable owns all cells and native simulation. This view only
# consumes copied RGBA bytes and issues synchronous, bounded commands.
# NOT a production Godot streaming adapter, gameplay host, or shared-World API.
const SIDE: int = 64
const DISPLAY_SIZE: float = 640.0
const DISPLAY_TOP_LEFT: Vector2 = Vector2(28.0, 76.0)
const FRAME_BYTES: int = SIDE * SIDE * 4

var world_chunk := Vector2i(-1, -3)
var selected_cell := Vector2i(18, 30)
var native_executable: String = ""
var save_root: String = ""
var texture: ImageTexture
var last_receipts: String = ""
var failure: String = ""
var total_calls: int = 0
var last_call_usec: int = 0


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
    _invoke(PackedStringArray())
    # Headless acceptance deliberately uses the same Godot UI script and the
    # real native executable, then closes without requiring manual input.
    if OS.get_environment("GEN006_SLICE_VERIFY") == "1":
        _invoke(PackedStringArray(), true)
        _qualify_and_quit()


func _qualify_and_quit() -> void:
    var qualified: bool = (
        texture != null and failure.is_empty()
        and last_receipts.contains("RENDER_RGBA ")
        and last_receipts.contains("EVICT ")
        and last_receipts.contains("RELOAD ")
    )
    if qualified:
        print("GEN006_GODOT_NATIVE_FRAME_PASS width=64 height=64"
            + " actual_native_rgba=1 real_eviction=1")
    else:
        push_error("GEN006_GODOT_NATIVE_FRAME_FAIL " + failure
            + " receipts=" + last_receipts.right(500))
    get_tree().quit(0 if qualified else 1)


func _invoke(actions: PackedStringArray, force_eviction: bool = false) -> void:
    if native_executable.is_empty() or not failure.is_empty():
        queue_redraw()
        return
    var commands := PackedStringArray()
    commands.append("focus %d %d" % [world_chunk.x, world_chunk.y])
    # Only on camera movement: cross three native shards to demonstrate real
    # capacity-bounded eviction/reload while remaining in the isolated domain.
    if force_eviction:
        commands.append("focus %d %d" % [world_chunk.x + 1, world_chunk.y])
        commands.append("focus %d %d" % [world_chunk.x + 2, world_chunk.y])
        commands.append("focus %d %d" % [world_chunk.x, world_chunk.y])
    for action in actions:
        commands.append(action)
    commands.append("render")
    commands.append("status")
    commands.append("quit")
    var command_path: String = save_root.path_join("gen006-commands.txt")
    var file := FileAccess.open(command_path, FileAccess.WRITE)
    if file == null:
        failure = "Command file open failed: " + str(FileAccess.get_open_error())
        queue_redraw()
        return
    file.store_string("\n".join(commands) + "\n")
    file.close()

    var stdout: Array = []
    var started := Time.get_ticks_usec()
    # Synchronous by design: the experimental CLI has no stream-safe,
    # long-lived Godot/GDExtension transport yet. Do not run in gameplay.
    var exit_code := OS.execute(
        native_executable,
        PackedStringArray(["--batch", save_root, command_path, "1"]),
        stdout, true
    )
    last_call_usec = Time.get_ticks_usec() - started
    total_calls += 1
    last_receipts = str(stdout[0]) if not stdout.is_empty() else ""
    if exit_code != 0 or last_receipts.contains("REFUSED "):
        failure = "Native command refused (exit %d): %s" % [
            exit_code, last_receipts.right(350)
        ]
        queue_redraw()
        return

    var bytes := FileAccess.get_file_as_bytes(save_root.path_join("gen006-current.rgba"))
    if bytes.size() != FRAME_BYTES:
        failure = "Expected %d authoritative native RGBA bytes, got %d" % [
            FRAME_BYTES, bytes.size()
        ]
        queue_redraw()
        return
    var image := Image.create_from_data(SIDE, SIDE, false, Image.FORMAT_RGBA8, bytes)
    texture = ImageTexture.create_from_image(image)
    queue_redraw()


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
        KEY_HOME: world_chunk = Vector2i(-1, -3)
        KEY_SPACE: _invoke(PackedStringArray(["tick 1"]))
        KEY_R: _invoke(PackedStringArray())
    if move != Vector2i.ZERO:
        # Shift+arrow moves 24 chunks (1536 native world pixels).
        world_chunk += move * (24 if key.shift_pressed else 1)
        failure = ""
        _invoke(PackedStringArray(), true)
    elif key.keycode == KEY_HOME:
        failure = ""
        _invoke(PackedStringArray(), true)
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
        _invoke(PackedStringArray([edit]))
        accept_event()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#0d1220"), true)
    var font: Font = ThemeDB.fallback_font
    draw_string(font, Vector2(28, 30), "GEN-006 / Native World Stream [experimental]", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#dee9fb"))
    draw_string(font, Vector2(28, 54), "Arrows: chunk  |  Shift+arrows: 1536px jump  |  Left: wall  Right: dig  Middle: Water17  Space: tick  R: reload", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a3b5ce"))
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
    draw_string(font, Vector2(710, 157),
        "Resident budget: 2 native Worlds",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b9c7e3"))
    draw_string(font, Vector2(710, 184),
        "CLI calls: %d  |  Last round trip: %.1f ms" % [
            total_calls, float(last_call_usec) / 1000.0
        ], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b9c7e3"))
    draw_string(font, Vector2(710, 211),
        "Copied native RGBA 64x64 (not Godot production shader)",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9caec9"))
    if not failure.is_empty():
        draw_string(font, Vector2(710, 245), failure,
                    HORIZONTAL_ALIGNMENT_LEFT, 550.0, 15, Color("#ff967b"))
    else:
        var lines := last_receipts.split("\n", false)
        var tail := lines.slice(maxi(0, lines.size() - 14))
        for i in range(tail.size()):
            draw_string(font, Vector2(710, 255 + i * 22),
                        tail[i].left(92), HORIZONTAL_ALIGNMENT_LEFT,
                        520.0, 13, Color("#a5be9d"))
    draw_string(font, Vector2(28, 751),
        "EXPERIMENT ONLY: one native World per shard; cross-shard effects, Rapier bodies and production streaming are unsupported.",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f4a261"))
