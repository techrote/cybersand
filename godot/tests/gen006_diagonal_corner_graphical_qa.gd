extends SceneTree

# Independent actual-native/Godot 4.7 OpenGL qualification for four-tile
# signed diagonal roaming. The builder's first seam test covers only two-tile
# horizontal movement. This validates the 2-native-resident / 4-copied-tile
# corner case before prefetch or cache-refresh changes.
const DEMO := preload("res://tests/gen006_streaming_slice_demo.tscn")
const CORNER := Vector2i(-24, 2)


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("GEN006_DIAGONAL_CORNER_FAIL " + message)
    quit(1)


func _await_frame(demo: Control, target: Vector2i) -> bool:
    var deadline := Time.get_ticks_msec() + 20000
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if not demo.failure.is_empty():
            return false
        if demo.displayed_chunk == target and demo.native_pid == demo.server_pid:
            if demo.roam_enabled and not demo.roam_frame_cache.has(target):
                continue
            return true
    return false


func _capture(folder: String, stem: String) -> String:
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null or image.get_width() != 1280 or image.get_height() != 800:
        return ""
    if image.save_png(folder.path_join(stem + ".png")) != OK:
        return ""
    var hasher := HashingContext.new()
    hasher.start(HashingContext.HASH_SHA256)
    hasher.update(image.get_data())
    return hasher.finish().hex_encode()


func _run() -> void:
    var evidence := OS.get_environment("GEN006_CORNER_EVIDENCE")
    if evidence.is_empty() or DirAccess.make_dir_recursive_absolute(evidence) != OK:
        _fail("original framebuffer evidence directory unavailable")
        return
    root.size = Vector2i(1280, 800)
    var demo: Control = DEMO.instantiate()
    root.add_child(demo)
    demo.size = Vector2(1280, 800)
    if not demo.failure.is_empty() or not demo.interactive_async or demo.texture == null:
        _fail("actual native/Godot startup: " + demo.failure)
        return
    var pid: int = demo.native_pid
    if pid <= 0 or pid != demo.server_pid:
        _fail("native PID not stable at startup")
        return

    # Demand an actual negative signed native source, not a cached fake image.
    demo.jump_x_edit.text = str(CORNER.x)
    demo.jump_y_edit.text = str(CORNER.y)
    demo.jump_go_button.pressed.emit()
    if not await _await_frame(demo, CORNER):
        _fail("signed native start (-24,2) never became displayed")
        return
    var before := await _capture(evidence, "00-native-negative-origin")
    if before.is_empty():
        _fail("missing initial original OpenGL capture")
        return
    var baseline_ticks: int = demo.service_ticks
    var baseline_acks: int = demo.acknowledged_edits
    demo.roam_button.pressed.emit()
    if not demo.roam_enabled or not demo.roam_frame_cache.has(CORNER):
        _fail("Roam ON did not retain native first tile")
        return
    var original_origin: Vector2 = demo.roam_origin
    var wanted: Array[Vector2i] = [
        Vector2i(-23, 2), Vector2i(-24, 3), Vector2i(-23, 3)
    ]

    # The first attempted diagonal step requires four tiles. It must not move
    # until three *real* separately focused native source RGBA frames arrive.
    for next_tile in wanted:
        var previous_origin: Vector2 = demo.roam_origin
        demo._advance_roam(0.1, Vector2(1, 1))
        if demo.roam_origin != previous_origin:
            _fail("camera moved before corner tile " + str(next_tile) + " loaded")
            return
        if demo.world_chunk != next_tile or not demo.input_refusal.begins_with("Roam waiting"):
            _fail("native corner demand missing or wrong: expected " + str(next_tile)
                + " actual " + str(demo.world_chunk) + " refusal " + demo.input_refusal)
            return
        if not await _await_frame(demo, next_tile):
            _fail("native corner tile missing or refused: " + str(next_tile)
                + " native_error=" + demo.failure)
            return
        if demo.native_pid != pid or demo.server_pid != pid or demo.resident_native_shards > 2:
            _fail("native owner restarted or residency exceeded 2 during corner demand")
            return
        if demo.roam_frame_cache.size() > 8:
            _fail("copied tile cache exceeded its 8-tile bound")
            return

    # All four sources must be actual 64x64 native textures; two may already
    # have been evicted from native residency, proving presentation != authority.
    for tile in [CORNER, wanted[0], wanted[1], wanted[2]]:
        if not demo.roam_frame_cache.has(tile):
            _fail("native source tile missing from four-tile cache: " + str(tile))
            return
        var tex: Texture2D = demo.roam_frame_cache[tile]
        if tex == null or tex.get_width() != 64 or tex.get_height() != 64:
            _fail("invalid real 64x64 native tile: " + str(tile))
            return
    if demo.roam_frame_cache.size() != 4:
        _fail("unexpected cache size for four-tile corner")
        return
    if demo.eviction_receipts < 2:
        _fail("four distinct native demands did not exercise finite residency")
        return

    # Advance ~30 world cells into the signed corner so the actual framebuffer
    # composites large visible areas of all four distinct copied native tiles.
    for index in range(12):
        demo._advance_roam(0.1, Vector2(1, 1))
        if not demo.failure.is_empty():
            _fail("native failure during four-tile composition: " + demo.failure)
            return
        if demo.input_refusal.begins_with("Roam waiting"):
            _fail("unexpected additional native focus with all four corner tiles cached")
            return
    if demo.roam_origin.x <= original_origin.x + 25.0 or demo.roam_origin.y <= original_origin.y + 25.0:
        _fail("four-tile diagonal camera did not actually advance")
        return
    if demo._visible_roam_tiles(demo.roam_origin).size() != 4:
        _fail("diagonal viewport did not overlap all four signed chunks")
        return

    var after := await _capture(evidence, "01-native-four-tile-corner")
    if after.is_empty() or after == before:
        _fail("original OpenGL capture absent or unchanged after native corner motion")
        return

    # Copied native pixels are NOT authoritative for editing, including at a
    # corner where two of the visible source shards have been truly evicted.
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = Vector2(350, 380)
    demo._gui_input(click)
    if not demo.input_refusal.contains("read-only") or demo.acknowledged_edits != baseline_acks:
        _fail("copied corner image allowed a false native durable edit ACK")
        return
    if not demo.queued_actions.is_empty() or demo.native_pid != pid or demo.server_pid != pid:
        _fail("corner edit entered native queue or native owner PID changed")
        return
    if demo.resident_native_shards > 2 or demo.roam_frame_cache.size() > 8:
        _fail("native residency or presentation cache exceeded declared capacity")
        return
    if demo.service_ticks <= baseline_ticks:
        _fail("actual native tick service failed to advance")
        return
    print("GEN006_DIAGONAL_CORNER_PASS actual_native=1 actual_gl=1"
        + " four_signed_native_tiles=1 native_corner_demands=3"
        + " resident_max_2=1 native_evictions=%d" % demo.eviction_receipts
        + " tile_cache=4 stable_pid=%d" % pid
        + " editing_read_only=1 ticks_advanced=1 original_png=2")
    quit(0)
