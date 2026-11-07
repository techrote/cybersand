extends SceneTree

# Independent actual-native/Godot multi-material drag, signed LRU and
# authoritative state restoration QA. Never uses a mock controller.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")
const SKY := Vector2i(-1, -3)


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("GEN006_DRAG_MATERIAL_QA_FAIL " + message)
    quit(1)


func _pos(x: int, y: int) -> Vector2:
    return Vector2(33.0 + x * 10.0, 81.0 + y * 10.0)


func _mouse(demo: Control, button: int, x: int, y: int, pressed: bool = true) -> void:
    var e := InputEventMouseButton.new()
    e.button_index = button
    e.position = _pos(x, y)
    e.pressed = pressed
    demo._gui_input(e)


func _stroke(demo: Control, button: int, x0: int, x1: int, y: int) -> void:
    _mouse(demo, button, x0, y)
    var e := InputEventMouseMotion.new()
    e.position = _pos(x1, y)
    match button:
        MOUSE_BUTTON_LEFT: e.button_mask = MOUSE_BUTTON_MASK_LEFT
        MOUSE_BUTTON_RIGHT: e.button_mask = MOUSE_BUTTON_MASK_RIGHT
        MOUSE_BUTTON_MIDDLE: e.button_mask = MOUSE_BUTTON_MASK_MIDDLE
    demo._gui_input(e)
    _mouse(demo, button, x1, y, false)


func _key(demo: Control, key: int, shifted: bool = false) -> void:
    var e := InputEventKey.new()
    e.keycode = key
    e.pressed = true
    e.shift_pressed = shifted
    demo._unhandled_key_input(e)


func _await_frame(demo: Control, chunk: Vector2i) -> bool:
    var until := Time.get_ticks_msec() + 35000
    while Time.get_ticks_msec() < until:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.displayed_chunk == chunk and demo.world_chunk == chunk:
            return true
    return false


func _await_ack(demo: Control, count: int) -> bool:
    var until := Time.get_ticks_msec() + 60000
    while Time.get_ticks_msec() < until:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.acknowledged_edits >= count and demo.queued_actions.is_empty():
            return true
    return false


func _native_cell(demo: Control, x: int, y: int) -> Dictionary:
    demo._invoke(PackedStringArray(["inspect %d %d" % [x, y]]), false, true)
    if not demo.failure.is_empty():
        return {}
    for line in demo.last_receipts.split("\n", false):
        if not line.begins_with("CELL chunk=(-1,-3) local=(%d,%d)" % [x, y]):
            continue
        var values: Dictionary = {}
        for field in line.split(" ", false):
            for name in ["material", "intent"]:
                if field.begins_with(name + "="):
                    values[name] = int(field.trim_prefix(name + "="))
            if field.begins_with("liquid="):
                values["liquid"] = float(field.trim_prefix("liquid="))
        return values
    return {}


func _snapshot(demo: Control) -> Dictionary:
    # All inspections go to the same real native PID. Pause only the Godot
    # request pump to avoid competing display refreshes, not native ticks.
    demo.set_process(false)
    demo.focus_dirty = false
    var until := Time.get_ticks_msec() + 12000
    while demo.ipc_outstanding and Time.get_ticks_msec() < until:
        demo._service_live_ipc()
        await process_frame
    if demo.ipc_outstanding or not demo.queued_actions.is_empty():
        return {}
    demo.interactive_async = false
    var s: Dictionary = {}
    for x in range(12, 16):
        s["empty_%d" % x] = _native_cell(demo, x, 12)
    s["total_water"] = 0.0
    for x in range(18, 20):
        var cell: Dictionary = _native_cell(demo, x, 30)
        s["water_%d" % x] = cell
        s["total_water"] += float(cell.get("liquid", -10000.0))
    demo.interactive_async = true
    demo.set_process(true)
    return s


func _verify_empty_and_mass(snapshot: Dictionary, mass: float) -> bool:
    for x in range(12, 16):
        var c: Dictionary = snapshot.get("empty_%d" % x, {})
        if c.get("material", -1) != 0 or c.get("intent", -1) != 1:
            return false
    return absf(float(snapshot.get("total_water", -1.0)) - mass) <= 0.05


func _frame(demo: Control, evidence: String, name: String) -> bool:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.get_width() != 1280 or image.get_height() != 800:
        return false
    if image.save_png(evidence.path_join(name + ".png")) != OK:
        return false
    # The actual native RGBA pixel must agree with Godot's actual GL frame.
    var rgba := FileAccess.get_file_as_bytes(
        demo.save_root.path_join("gen006-current.rgba"))
    if rgba.size() != 16384:
        return false
    var i := (30 * 64 + 18) * 4
    var native := Color8(rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3])
    var p := _pos(18, 30)
    var a := image.get_pixel(int(p.x), int(p.y))
    var b := image.get_pixel(int(p.x), 799 - int(p.y))
    var d1 := maxf(absf(a.r-native.r), maxf(absf(a.g-native.g), absf(a.b-native.b)))
    var d2 := maxf(absf(b.r-native.r), maxf(absf(b.g-native.g), absf(b.b-native.b)))
    print("GEN006_DRAG_GL_RECEIPT %s delta=%.5f" % [name, minf(d1, d2)])
    return minf(d1, d2) < 0.20


func _run() -> void:
    var evidence := OS.get_environment("GEN006_DRAG_MATERIAL_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("no framebuffer evidence directory")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or \
            demo.native_pid <= 0 or demo.server_pid != demo.native_pid:
        _fail("actual native controller not ready: " + demo.failure)
        return
    var pid: int = demo.native_pid
    demo.world_chunk = SKY
    demo._queue_live_focus()
    if not await _await_frame(demo, SKY):
        _fail("signed sky demand unavailable: " + demo.failure)
        return

    _stroke(demo, MOUSE_BUTTON_LEFT, 12, 15, 12)
    if demo.queued_actions.size() != 4 or not await _await_ack(demo, 4):
        _fail("left drag failed to commit four native Walls")
        return
    _stroke(demo, MOUSE_BUTTON_RIGHT, 12, 15, 12)
    if demo.queued_actions.size() != 4 or not await _await_ack(demo, 8):
        _fail("right drag failed to commit four explicit Empty edits")
        return

    # Native Water17 has actual 30Hz dynamics. Ten surrounding real Wall
    # edits enclose two neighboring cells so zero cross-shard loss is implied.
    for y in [29, 31]:
        for x in range(17, 21):
            _mouse(demo, MOUSE_BUTTON_LEFT, x, y)
            _mouse(demo, MOUSE_BUTTON_LEFT, x, y, false)
    for x in [17, 20]:
        _mouse(demo, MOUSE_BUTTON_LEFT, x, 30)
        _mouse(demo, MOUSE_BUTTON_LEFT, x, 30, false)
    if demo.queued_actions.size() != 10 or not await _await_ack(demo, 18):
        _fail("native Water enclosure Walls failed")
        return
    _stroke(demo, MOUSE_BUTTON_MIDDLE, 18, 19, 30)
    if demo.queued_actions.size() != 2 or not await _await_ack(demo, 20):
        _fail("middle drag failed to commit two Water17 edits")
        return
    await create_timer(0.35).timeout
    var before: Dictionary = await _snapshot(demo)
    if not _verify_empty_and_mass(before, 34.0):
        _fail("native Empty intent/Water mass incorrect before eviction: " + str(before))
        return
    if not await _frame(demo, evidence, "00-materials-before-eviction"):
        _fail("actual Water OpenGL framebuffer failed before eviction")
        return

    # Two genuine distant camera demands exceed capacity and remove the
    # edited sky World. Returning must be native RELOAD, not hidden pixels.
    _key(demo, KEY_RIGHT, true)
    if not await _await_frame(demo, Vector2i(23, -3)):
        _fail("distant camera demand 23 failed: " + demo.failure)
        return
    _key(demo, KEY_RIGHT)
    if not await _await_frame(demo, Vector2i(24, -3)):
        _fail("distant camera demand 24 failed: " + demo.failure)
        return
    var evicted: int = demo.eviction_receipts
    _key(demo, KEY_LEFT)
    if not await _await_frame(demo, Vector2i(23, -3)):
        _fail("first native camera return failed: " + demo.failure)
        return
    _key(demo, KEY_LEFT, true)
    if not await _await_frame(demo, SKY):
        _fail("modified signed chunk did not return: " + demo.failure)
        return
    if evicted < 2 or demo.reload_receipts < 1 or \
            demo.resident_native_shards > 2 or demo.native_pid != pid:
        _fail("native shard release/reload missing: evictions=%d reloads=%d" % [
            evicted, demo.reload_receipts])
        return
    var after: Dictionary = await _snapshot(demo)
    if not _verify_empty_and_mass(after, float(before["total_water"])):
        _fail("native Empty/Water changed after real release and reload: " + str(after))
        return
    if not await _frame(demo, evidence, "01-materials-after-reload"):
        _fail("actual Water OpenGL framebuffer failed after native reload")
        return
    if demo.acknowledged_edits != 20 or demo.native_pid != pid:
        _fail("native ACK or continuous PID changed")
        return
    demo.set_process(false)
    demo.interactive_async = false
    demo._send_quit()
    if OS.is_process_running(pid):
        _fail("native process not cleanly shut down")
        return
    print("GEN006_DRAG_MATERIAL_ROUNDTRIP_PASS"
        + " native_empty_intent=4 native_water_mass=%.3f" % [
            float(after["total_water"])]
        + " durable_acks=20 native_evictions=%d native_reloads=%d" % [
            evicted, demo.reload_receipts]
        + " signed_1536_camera=1 same_pid=1 actual_gl_pngs=2")
    quit(0)
