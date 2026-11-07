extends SceneTree

# Independent GEN-006 actual Godot framebuffer acceptance of the newest native
# simulation-pin containment in the opt-in #486 demo. No production code edits.
# This is NOT a general sparse-World or shared-chunk correctness certificate.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")
const ENV_EVIDENCE := "GEN006_PIN_GRAPHICAL_EVIDENCE"

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("GEN006_PIN_GRAPHICAL_FAIL " + reason)
    quit(1)

func _key(demo: Control, keycode: int) -> void:
    var event := InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    demo._unhandled_key_input(event)

func _dig(demo: Control, x: int, y: int) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_RIGHT
    event.position = Vector2(28.0 + float(x) * 10.0 + 5.0,
        76.0 + float(y) * 10.0 + 5.0)
    event.pressed = true
    demo._gui_input(event)

func _wall(demo: Control, x: int, y: int) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = Vector2(28.0 + float(x) * 10.0 + 5.0,
        76.0 + float(y) * 10.0 + 5.0)
    event.pressed = true
    demo._gui_input(event)

func _await_durable_edit(demo: Control, expected_acks: int) -> bool:
    var deadline := Time.get_ticks_msec() + 20000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.acknowledged_edits >= expected_acks:
            return true
    return false


func _await_live_frame(demo: Control, chunk: Vector2i) -> bool:
    var deadline := Time.get_ticks_msec() + 20000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.displayed_chunk == chunk and demo.native_pid == demo.server_pid:
            return true
    return false


func _await_empty_intent(demo: Control) -> bool:
    # Inspect is a sequenced *native owner request*, not an overlapping
    # synchronous _invoke while the interactive queue owns IPC.
    var prior_calls: int = demo.total_calls
    demo._queue_live_action("inspect 5 5", false)
    var deadline := Time.get_ticks_msec() + 20000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.total_calls > prior_calls and demo.last_receipts.contains(
                "CELL chunk=(-2,2) local=(5,5)") and demo.last_receipts.contains(
                "intent=1"):
            return true
    return false


func _await_surface_pin(demo: Control) -> bool:
    var deadline := Time.get_ticks_msec() + 15000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.pinned_native_shards >= 1 and not demo.pin_notice.is_empty() and \
                demo.last_receipts.contains("chunk=(-2,1)") and \
                demo.last_receipts.contains("pinned=1"):
            return true
    return false


func _frame(label: String, dir: String) -> Image:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.get_width() < 1280 or image.get_height() < 800:
        return null
    if image.save_png(dir.path_join(label + ".png")) != OK:
        return null
    return image

func _visible_orange_pin_pixels(image: Image) -> int:
    # Only the user-facing simulation-pin HUD strip, not the log, terrain or
    # permanent experiment disclaimer. An orange warning must be actually
    # submitted to the GL framebuffer rather than stored only in GDScript.
    var warm: int = 0
    for y in range(269, 310):
        for x in range(710, 1240):
            var pixel: Color = image.get_pixel(x, y)
            if pixel.r > 0.70 and pixel.r > 1.18 * pixel.g \
                    and pixel.g > 1.25 * pixel.b:
                warm += 1
    return warm

func _run() -> void:
    var exe := OS.get_environment("GEN006_SLICE_EXECUTABLE")
    var world := OS.get_environment("GEN006_SLICE_ROOT")
    var evidence := OS.get_environment(ENV_EVIDENCE)
    if exe.is_empty() or world.is_empty() or evidence.is_empty():
        _fail("environment missing executable, save root or screenshot path")
        return
    if DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("cannot make evidence folder")
        return

    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or demo.texture == null or not demo.interactive_async:
        _fail("native/Godot demonstration did not initialize: " + demo.failure)
        return
    var owner_pid: int = demo.native_pid
    if owner_pid <= 0 or demo.server_pid != owner_pid \
            or demo.world_chunk != Vector2i(-2, 2) \
            or demo.pinned_native_shards != 0:
        _fail("unexpected first-frame native identity/terrain/pin state")
        return
    var before: Image = await _frame("00-before-pin", evidence)
    if before == null:
        _fail("baseline actual framebuffer was not captured")
        return
    var baseline_warm: int = _visible_orange_pin_pixels(before)

    # A real queued player right-click must complete its native durable ACK
    # before inspection. Never overlap direct _invoke with outstanding async IPC.
    var first_acks: int = demo.acknowledged_edits
    _dig(demo, 5, 5)
    if not await _await_durable_edit(demo, first_acks + 1) or \
            not await _await_empty_intent(demo):
        _fail("native Empty edit/intent not durably acknowledged before pin: " + demo.failure)
        return

    # The actual player camera Up key enters the already reproduced
    # unsupported surface shard (-2,1). Native background ticks should
    # rollback/pin it without killing the owner or silently dropping edits.
    _key(demo, KEY_UP)
    if demo.world_chunk != Vector2i(-2, 1) or not demo.failure.is_empty():
        _fail("camera failed to navigate to unsupported surface: " + demo.failure)
        return
    if not await _await_live_frame(demo, Vector2i(-2, 1)):
        _fail("native owner did not display requested surface chunk: " + demo.failure)
        return
    await create_timer(0.70).timeout
    if not await _await_surface_pin(demo):
        _fail("native owner did not return a simulation-pin receipt: " + demo.failure)
        return
    if owner_pid != demo.native_pid or owner_pid != demo.server_pid \
            or not OS.is_process_running(owner_pid):
        _fail("native PID changed or owner died during simulated pin")
        return
    # Status has the complete resident/pin roster. The current HUD's
    # single pin_notice displays the LAST pinned resident only; when two
    # different surface shards pin, require the target in the full native
    # receipt and a nonempty visible notice, not target==last notice.
    if demo.pinned_native_shards < 1 or demo.pin_notice.is_empty() \
            or not demo.last_receipts.contains("chunk=(-2,1)") \
            or not demo.last_receipts.contains("pinned=1"):
        _fail("unsupported surface pin not visible in Godot receipts/HUD: "
            + str(demo.pinned_native_shards) + " / " + demo.pin_notice
            + " / " + demo.last_receipts.right(450))
        return
    var pin_frame: Image = await _frame("01-native-pin-visible", evidence)
    if pin_frame == null:
        _fail("pin actual framebuffer was not captured")
        return
    var pin_warm: int = _visible_orange_pin_pixels(pin_frame)
    if pin_warm < baseline_warm + 15:
        _fail("pin is in native status but not perceptibly drawn on actual GL frame: "
            + str(baseline_warm) + " -> " + str(pin_warm))
        return

    # The user can recover with the existing Home key. The same native PID
    # must accept new actions and restore the earlier edit across true LRU.
    _key(demo, KEY_HOME)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(-2, 2):
        _fail("Home could not restore the safe terrain view: " + demo.failure)
        return
    if not await _await_live_frame(demo, Vector2i(-2, 2)) or \
            not await _await_empty_intent(demo):
        _fail("player Empty-intent lost on actual native Home reload: "
            + demo.failure + " / " + demo.last_receipts.right(350))
        return
    var before_wall_ack: int = demo.acknowledged_edits
    _wall(demo, 8, 8)
    if not await _await_durable_edit(demo, before_wall_ack + 1) or \
            owner_pid != demo.native_pid or owner_pid != demo.server_pid or \
            not OS.is_process_running(owner_pid):
        _fail("native owner did not durably acknowledge post-pin player Wall edit")
        return
    var recovered: Image = await _frame("02-home-and-edit-after-pin", evidence)
    if recovered == null:
        _fail("recovered real Godot viewport could not be captured")
        return

    print("GEN006_PIN_GRAPHICAL_PASS"
        + " real_gl_framebuffer=1"
        + " camera_surface=(-2,1)"
        + " pin_receipt=1"
        + " pin_visible=1"
        + " native_pid_stable=1"
        + " empty_intent_restored=1"
        + " home_and_paint=1"
        + " before_pin_orange=%d" % baseline_warm
        + " after_pin_orange=%d" % pin_warm
        + " screenshots=3")
    quit(0)
