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
    if demo.world_chunk != Vector2i(-2, 2) or \
            demo.occupied_native_cells < 512 or demo.occupied_native_cells >= 4096:
        _fail("default first scene lacks substantial safe native Strata terrain: "
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
    demo._invoke(PackedStringArray(), false, true)
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

    # Real camera misses, not artificial prefetched neighbors, must drive LRU.
    # Start and painted sky occupy two actual native Worlds. Shift+Right demands
    # one far chunk at 1472px, forcing the first real eviction only.
    _key(demo, KEY_RIGHT, true)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(23, -3):
        _fail("Shift+Right 1536-pixel navigation failed: " + demo.failure)
        return
    if not demo.last_receipts.contains("EVICT x=-2 y=2") or not \
            demo.last_receipts.contains("GENERATE x=23 y=-3") or \
            demo.last_receipts.contains("RELOAD x=23 y=-3"):
        _fail("camera-driven native miss did not evict oldest real resident")
        return
    var distant: Dictionary = await _capture("03-distant-chunk", evidence, chunk_root, 8, 8)
    if distant.has("error"):
        _fail(str(distant["error"]))
        return

    # A second independent camera position now exceeds the two-World budget,
    # evicting the EDITED sky chunk. No synthetic focus/prefetch is permitted.
    _key(demo, KEY_RIGHT)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(24, -3) or \
            not demo.last_receipts.contains("EVICT x=-1 y=-3"):
        _fail("third distinct camera demand failed to evict edited sky: "
            + demo.failure + " / " + demo.last_receipts.right(400))
        return
    _key(demo, KEY_LEFT)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(23, -3):
        _fail("camera return through live far resident failed")
        return

    # Return 1536px via actual input and require native RELOAD of the
    # previously evicted edited sky, not mere presentation of cached pixels.
    _key(demo, KEY_LEFT, true)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(-1, -3) or \
            not demo.last_receipts.contains("RELOAD x=-1 y=-3"):
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

    # With autonomous native 30Hz simulation, even a three-sided basin
    # permits upward/diagonal transport between input and framebuffer sampling
    # (original failure preserved in run #42343367577). Enclose all eight
    # neighboring cells using actual player Wall edits before Water17 paint.
    # This is a stronger, static native containment fixture, not a weaker
    # colour-only renderer assertion.
    for wall_cell in [
            Vector2i(17, 29), Vector2i(18, 29), Vector2i(19, 29),
            Vector2i(17, 30), Vector2i(19, 30),
            Vector2i(17, 31), Vector2i(18, 31), Vector2i(19, 31)]:
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
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(-2, 2) or \
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

    # Integrate the previously independent visible-pin recovery scenario
    # into the primary playable demo acceptance. The native owner must remain
    # alive and the HUD must expose its actual complete pin roster.
    _key(demo, KEY_UP)
    if not demo.failure.is_empty() or demo.world_chunk != Vector2i(-2, 1):
        _fail("surface camera navigation failed: " + demo.failure)
        return
    await create_timer(0.70).timeout
    demo._invoke(PackedStringArray(), false, true)
    if not demo.failure.is_empty() or demo.pinned_native_shards < 1 or \
            demo.pinned_chunks.size() != demo.pinned_native_shards:
        _fail("native pin roster missing/inconsistent: " + demo.failure
            + " count=" + str(demo.pinned_native_shards)
            + " rows=" + str(demo.pinned_chunks.size()))
        return
    var target_pin := false
    for row in demo.pinned_chunks:
        if row.contains("chunk=(-2,1)") and row.contains("pinned=1"):
            target_pin = true
    if not target_pin:
        _fail("active camera's pinned native chunk missing from complete HUD roster")
        return
    var pin_frame: Dictionary = await _capture(
        "07-visible-simulation-pin", evidence, chunk_root, 8, 50)
    if pin_frame.has("error"):
        _fail("could not capture actual pinned surface framebuffer")
        return
    var pin_image: Image = Image.load_from_file(str(pin_frame["png"]))
    if pin_image == null or pin_image.get_width() < 1280:
        _fail("pinned HUD image cannot be read")
        return
    var orange_pin_pixels := 0
    for y in range(270, 341):
        for x in range(710, 1240):
            var p: Color = pin_image.get_pixel(x, y)
            if p.r > 0.70 and p.r > 1.18 * p.g and p.g > 1.25 * p.b:
                orange_pin_pixels += 1
    if orange_pin_pixels < 40:
        _fail("native pin exists but no visible orange HUD warning")
        return
    _key(demo, KEY_HOME)
    if not demo.failure.is_empty() or demo.native_pid != persistent_pid or \
            demo.server_pid != persistent_pid or demo.occupied_native_cells < 512:
        _fail("native owner or terrain did not recover after visible pin")
        return

    print("GEN006_GODOT_GRAPHICAL_FRAME_PASS"
        + " persistent_native_process=1"
        + " real_gl_framebuffer=1"
        + " native_world_rgba=1"
        + " paint_dig=1"
        + " camera_pixel_x=1472"
        + " real_camera_lru=1"
        + " real_eviction_reload=1"
        + " restored_pixels=1"
        + " water17_visual=1"
        + " native_surface_first_frame=1"
        + " native_surface_home_restore=1"
        + " native_pin_roster_visible=1"
        + " pin_orange_pixels=%d" % orange_pin_pixels
        + " screenshots=8")
    quit(0)
