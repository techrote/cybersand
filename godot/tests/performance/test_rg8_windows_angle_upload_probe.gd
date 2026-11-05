extends SceneTree

# INV-004: bounded Windows graphical ANGLE RG8 ImageTexture.update() diagnostic.
# No CyberSand native World, Rapier, palette shader or production source is loaded.
# In all data-change arms the ENTIRE image is submitted (same as current Main).
# This measures CPU API-call time, not GPU completion or photon latency.
const SIZES: Array[int] = [256, 1024]
const ARMS: Array[String] = ["static_no_upload", "single_pixel_full_upload", "bulk_fill_full_upload"]
const REPEATS: int = 3
const MEASURED_FRAMES: int = 40
const WARM_FRAMES: int = 12

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    create_timer(180.0).timeout.connect(func() -> void:
        push_error("RG8 upload probe exceeded internal watchdog")
        quit(3))

func _run() -> void:
    if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
        push_error("Requires actual Windows graphical DisplayServer; headless is NOT a pass")
        quit(2)
        return
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    root.size = Vector2i(720, 540)
    var present: TextureRect = TextureRect.new()
    present.size = Vector2(640, 480)
    present.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    present.stretch_mode = TextureRect.STRETCH_SCALE
    root.add_child(present)

    var rows: Array[Dictionary] = []
    var failures: int = 0
    for size: int in SIZES:
        var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RG8)
        image.fill(Color(0.0, 0.0, 0.0, 1.0))
        var texture: ImageTexture = ImageTexture.create_from_image(image)
        if texture == null or image.get_format() != Image.FORMAT_RG8:
            push_error("RG8 allocation failed")
            quit(4)
            return
        present.texture = texture
        for repeat_index: int in range(REPEATS):
            # Counterbalance warm renderer/cache drift across arm order.
            for arm_index: int in range(ARMS.size()):
                var arm: String = ARMS[(arm_index + repeat_index) % ARMS.size()]
                for warm_index: int in range(WARM_FRAMES):
                    await RenderingServer.frame_post_draw
                var row: Dictionary = {
                    "size": size, "arm": arm, "repeat": repeat_index,
                    "submitted_bytes_per_upload": size * size * 2 if arm != "static_no_upload" else 0,
                    "samples": [], "pixel_write_checks": 0
                }
                var previous_frame_usec: int = Time.get_ticks_usec()
                for frame_index: int in range(MEASURED_FRAMES):
                    var prepare_start: int = Time.get_ticks_usec()
                    if arm == "single_pixel_full_upload":
                        var changed: float = float((frame_index + repeat_index) % 2 + 1) / 255.0
                        image.set_pixel(frame_index % size, frame_index / size, Color(changed, 0.0, 0.0, 1.0))
                        if image.get_pixel(frame_index % size, frame_index / size).r > 0.0:
                            row.pixel_write_checks += 1
                    elif arm == "bulk_fill_full_upload":
                        image.fill(Color(float((frame_index + repeat_index) % 2 + 1) / 255.0, 0.0, 0.0, 1.0))
                    var prepared_usec: int = Time.get_ticks_usec()
                    var upload_start: int = prepared_usec
                    if arm != "static_no_upload":
                        texture.update(image)
                    var upload_end: int = Time.get_ticks_usec()
                    await RenderingServer.frame_post_draw
                    var drawn_usec: int = Time.get_ticks_usec()
                    row.samples.append({
                        "prepare_usec": prepared_usec - prepare_start,
                        "upload_api_usec": upload_end - upload_start,
                        "frame_wait_usec": drawn_usec - upload_end,
                        "frame_interval_usec": drawn_usec - previous_frame_usec,
                        "start_usec": prepare_start, "post_draw_usec": drawn_usec
                    })
                    previous_frame_usec = drawn_usec
                if row.samples.size() != MEASURED_FRAMES:
                    failures += 1
                if arm == "single_pixel_full_upload" and row.pixel_write_checks != MEASURED_FRAMES:
                    failures += 1
                rows.append(row)
    var report: Dictionary = {
        "schema": "inv154-rg8-angle-upload-v1",
        "godot_version": str(Engine.get_version_info().get("string", "")),
        "os_name": OS.get_name(), "display_server": DisplayServer.get_name(),
        "rendering_method": RenderingServer.get_current_rendering_method(),
        "sizes": SIZES, "arms": ARMS, "repeats": REPEATS,
        "measured_frames_per_arm_repeat": MEASURED_FRAMES,
        "warm_frames_per_arm_repeat": WARM_FRAMES,
        "rows": rows, "failures": failures,
        "native_world_loaded": false, "rapier_loaded": false,
        "presentation": "graphical TextureRect using RG8 ImageTexture; no material shader",
        "timing_semantics": "monotonic CPU wall durations; frame_post_draw is not GPU completion"
    }
    print("INV154_RG8_UPLOAD " + JSON.stringify(report))
    quit(0 if failures == 0 else 5)
