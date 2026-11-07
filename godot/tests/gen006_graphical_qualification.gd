extends SceneTree

# Independent actual-viewport graphical qualification of the existing #486
# opt-in native-World demonstration. No production source or demo source edits.
# Must run with a real rendering driver/window (Xvfb on CI), NOT --headless.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")
const OUT_ENV := "GEN006_GRAPHICAL_EVIDENCE"

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("GEN006_GRAPHICAL_QUALIFICATION_FAIL " + message)
    quit(1)


func _delta(a: Color, b: Color) -> float:
    return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _native_pixel(chunk_root: String, x: int, y: int) -> Color:
    var data := FileAccess.get_file_as_bytes(chunk_root.path_join("gen006-current.rgba"))
    if data.size() != 64 * 64 * 4:
        return Color(-1, -1, -1, -1)
    var index := (y * 64 + x) * 4
    return Color8(data[index], data[index + 1], data[index + 2], data[index + 3])


func _capture(label: String, evidence: String, chunk_root: String, x: int, y: int) -> Dictionary:
    # Allow the dirty CanvasItem to be submitted to the real software GL
    # framebuffer before requesting Window/Viewport readback.
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var screenshot: Image = root.get_texture().get_image()
    if screenshot == null or screenshot.get_width() < 1280 or screenshot.get_height() < 800:
        return {"error": "empty/incomplete actual Godot viewport image for " + label}
    var png := evidence.path_join(label + ".png")
    if screenshot.save_png(png) != OK:
        return {"error": "cannot preserve Godot framebuffer PNG " + png}
    var native := _native_pixel(chunk_root, x, y)
    if native.r < 0:
        return {"error": "native RGBA payload missing for " + label}
    var screen_x: int = 28 + x * 10 + 5
    var screen_y: int = 76 + y * 10 + 5
    var direct: Color = screenshot.get_pixel(screen_x, screen_y)
    var flipped: Color = screenshot.get_pixel(screen_x, screenshot.get_height() - 1 - screen_y)
    var difference := minf(_delta(direct, native), _delta(flipped, native))
    print("GEN006_FRAME_RECEIPT label=%s native=%s screen=%s flipped=%s delta=%.4f png=%s" %
        [label, native.to_html(true), direct.to_html(true), flipped.to_html(true), difference, png])
    return {"native": native, "screen": direct if _delta(direct, native) <= _delta(flipped, native) else flipped,
        "delta": difference, "png": png}


func _click(demo: Control, x: int, y: int, mouse_button: int) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = mouse_button
    event.position = Vector2(28.0 + float(x) * 10.0 + 5.0, 76.0 + float(y) * 10.0 + 5.0)
    event.pressed = true
    # Call the real scene's existing UI action handler, without replacing
    # its native subprocess/texture transport or model code.
    demo._gui_input(event)


func _key(demo: Control, keycode: int, shifted: bool = false) -> void:
    var event := InputEventKey.new()
    event.keycode = keycode
    event.shift_pressed = shifted
    event.pressed = true
    demo._unhandled_key_input(event)


func _run() -> void:
    var executable := OS.get_environment("GEN006_SLICE_EXECUTABLE")
    var chunk_root := OS.get_environment("GEN006_SLICE_ROOT")
    var evidence := OS.get_environment(OUT_ENV)
    if executable.is_empty() or chunk_root.is_empty() or evidence.is_empty():
        _fail("missing GEN006_SLICE_EXECUTABLE, GEN006_SLICE_ROOT or " + OUT_ENV)
        return
    if DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("cannot create PNG evidence root " + evidence)
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or demo.texture == null:
        _fail("cannot start actual native image scene: " + demo.failure)
        return
    var persistent_pid: int = demo.native_pid
    if persistent_pid <= 0 or demo.server_pid != persistent_pid:
        _fail("persistent native controller PID receipt missing")
        return

    # Product-facing first frame must contain REAL generated cells, not merely
    # an empty sky texture that becomes visible only after manual painting.
    if demo.world_chunk != Vector2i(-2, 1) or \
            demo.occupied_native_cells < 512 or demo.occupied_native_cells >= 4096:
        _fail("default first scene lacks substantial native Strata terrain: "
            + str(demo.occupied_native_cells))
        return
    var terrain_first: Dictionary = await _capture(
        "00-generated-terrain", evidence, chunk_root, 8, 50)
    if terrain_first.has("error") or float(terrain_first.get("delta", 1.0)) > 0.20:
        _fail("first terrain framebuffer does not match actual native RGBA")
        return
    print("GEN006_TERRAIN_FIRST_FRAME_PASS occupied=%d total=4096"
        % demo.occupied_native_cells)

    # The original fixed-sky Water17 diagnostic remains a valuable native
    # control, but it should no longer dictate the player's starting view.
    demo.world_chunk = Vector2i(-1, -3)
    demo._invoke(PackedStringArray(), true, true)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(-1, -3):
        _fail("cannot enter signed sky qualification shard: " + demo.failure)
        return

    # First deliberately dig, then paint a Wall at exactly the same pixel.
    # These must produce changed native RGBA bytes AND changed *rendered*
    # framebuffer pixels at the magnified cell centre.
    _click(demo, 8, 8, MOUSE_BUTTON_RIGHT)
    if not demo.failure.is_empty():
        _fail("dig refused: " + demo.failure)
        return
    var empty: Dictionary = await _capture("01-dug", evidence, chunk_root, 8, 8)
    if empty.has("error"):
        _fail(str(empty["error"]))
        return

    _click(demo, 8, 8, MOUSE_BUTTON_LEFT)
    if not demo.failure.is_empty():
        _fail("wall paint refused: " + demo.failure)
        return
    var wall: Dictionary = await _capture("02-painted-wall", evidence, chunk_root, 8, 8)
    if wall.has("error"):
        _fail(str(wall["error"]))
        return
    if _delta(empty["native"], wall["native"]) < 0.12:
        _fail("native dig/wall did not change authoritative RGBA pixel")
        return
    if _delta(empty["screen"], wall["screen"]) < 0.08:
        _fail("actual Godot framebuffer failed to update after native Wall edit")
        return
    if float(wall["delta"]) > 0.20:
        _fail("painted native Wall colour not present in Godot framebuffer")
        return

    # Navigate beyond the old 1024px finite scene. The scene's own action
    # crosses a two-native-World LRU budget and must log real eviction/reload.
    _key(demo, KEY_RIGHT, true)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(23, -3):
        _fail("Shift+Right 1536-pixel navigation/eviction failed: " + demo.failure)
        return
    if not demo.last_receipts.contains("EVICT ") or not demo.last_receipts.contains("RELOAD "):
        _fail("actual native LRU receipts missing from movement action")
        return
    var distant: Dictionary = await _capture("03-distant-chunk", evidence, chunk_root, 8, 8)
    if distant.has("error"):
        _fail(str(distant["error"]))
        return

    # Return to the first signed chunk and prove saved native Wall really
    # reappears as the same on-screen pixel, not just the same CLI receipt.
    _key(demo, KEY_LEFT, true)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(-1, -3):
        _fail("reverse 1536-pixel native restore failed: " + demo.failure)
        return
    var restored: Dictionary = await _capture("04-reloaded-wall", evidence, chunk_root, 8, 8)
    if restored.has("error"):
        _fail(str(restored["error"]))
        return
    if _delta(restored["native"], wall["native"]) > 0.001:
        _fail("native Wall pixel changed after save/real shard destruction/reload")
        return
    if _delta(restored["screen"], wall["screen"]) > 0.08 or float(restored["delta"]) > 0.20:
        _fail("Godot framebuffer did not restore the same native Wall pixel")
        return

    # With autonomous native 30Hz simulation, uncontained Water may move
    # before a rendered-frame readback. Construct a three-sided real native
    # basin so the visual assertion genuinely samples Water, rather than
    # vacuously passing when both native and viewport pixels are empty.
    for wall_cell in [Vector2i(18, 31), Vector2i(17, 30), Vector2i(19, 30)]:
        _click(demo, wall_cell.x, wall_cell.y, MOUSE_BUTTON_LEFT)
        if not demo.failure.is_empty():
            _fail("Water17 containment Wall refused: " + demo.failure)
            return
    var water_before: Color = _native_pixel(chunk_root, 18, 30)

    # Capture an actual native Water paint after World reload, using the
    # scene's real middle-button input path and real RGBA copy.
    _click(demo, 18, 30, MOUSE_BUTTON_MIDDLE)
    if not demo.failure.is_empty():
        _fail("native Water17 paint refused: " + demo.failure)
        return
    var water: Dictionary = await _capture("05-water17", evidence, chunk_root, 18, 30)
    if water.has("error") or float(water.get("delta", 1.0)) > 0.20:
        _fail("native Water17 pixel missing from Godot viewport: " + str(water))
        return
    if _delta(water_before, water["native"]) < 0.12:
        _fail("Water17 visual check would be false-positive: native cell is empty")
        return

    # The user-facing Home control returns to the terrain-bearing start.
    # This also forces the independently saved first chunk to reload after
    # native World eviction; terrain must remain visibly present.
    _key(demo, KEY_HOME)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(-2, 1) or \
            demo.occupied_native_cells < 512:
        _fail("Home failed to restore native terrain-bearing start: "
            + str(demo.occupied_native_cells) + " " + demo.failure)
        return
    var terrain_back: Dictionary = await _capture(
        "06-reloaded-terrain", evidence, chunk_root, 8, 50)
    if terrain_back.has("error") or float(terrain_back.get("delta", 1.0)) > 0.20:
        _fail("restored terrain framebuffer does not match native RGBA")
        return
    if demo.native_pid != persistent_pid or demo.server_pid != persistent_pid:
        _fail("native controller process changed during graphical interaction")
        return

    print("GEN006_GODOT_GRAPHICAL_FRAME_PASS"
        + " persistent_native_process=1"
        + " real_gl_framebuffer=1"
        + " native_world_rgba=1"
        + " paint_dig=1"
        + " camera_pixel_x=1472"
        + " real_eviction_reload=1"
        + " restored_pixels=1"
        + " water17_visual=1"
        + " native_surface_first_frame=1"
        + " native_surface_home_restore=1"
        + " screenshots=7")
    quit(0)
