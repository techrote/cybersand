extends SceneTree

# INV-004 isolated, source-identical CyberPhysicalActorOverlay.present() probe.
# This is not a Main/frame/GPU test; queued redraws do NOT constitute rendered frames.
# The runner copies the actual production overlay script verbatim into a scratch
# project, so this apparatus never modifies a protected gameplay/renderer file.
const Overlay = preload("res://scripts/physical_actor_overlay.gd")
const COUNTS = [0, 8, 64, 512]
const ARMS = ["actual_present", "deep_copy_only", "enumerate_only"]
const REPEATS: int = 3
const BATCHES: int = 24
const CALLS_PER_BATCH: int = 20
const WARM_CALLS: int = 12
const VIEW: Vector2i = Vector2i(960, 540)
const CONTENT: Rect2 = Rect2(Vector2.ZERO, Vector2(960.0, 540.0))

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    create_timer(65.0).timeout.connect(func() -> void:
        push_error("INV154 overlay probe did not finish; refusing a silent timeout")
        quit(3))

func _parts(count: int) -> Array:
    var parts: Array = []
    for index: int in range(count):
        parts.append({
            "actor_id": index / 64, "physical_body_index": index / 8,
            "part_id": "part-%d" % index,
            "transform": Transform2D(0.0, Vector2(float(index % 80), float(index / 80))),
            "size": Vector2(8.0, 12.0),
            "color": Color(0.53, 0.75, 0.83, 1.0),
            "shape": "circle" if index % 5 == 0 else "rectangle",
            "markings": "scout" if index % 7 == 0 else "",
            "flight_live": index % 8 == 0,
            "flight_force": Vector2(12.0, -4.0),
            "flight_intent": Vector2(-1.0, 6.0),
        })
    return parts

func _call(arm: String, overlay, parts: Array) -> int:
    if arm == "actual_present":
        overlay.present(parts, Vector2.ZERO, VIEW, CONTENT)
        return overlay._parts.size()
    if arm == "deep_copy_only":
        var clone: Array = parts.duplicate(true)
        return clone.size()
    return parts.size()

func _run() -> void:
    var overlay := Overlay.new()
    root.add_child(overlay)
    var rows: Array = []
    var failures: int = 0
    for count: int in COUNTS:
        var payload: Array = _parts(count)
        for repetition: int in range(REPEATS):
            # Rotate order to reduce arm-order drift; each arm receives the
            # same, unchanged source payload for a given count.
            for arm_position: int in range(ARMS.size()):
                var arm: String = ARMS[(arm_position + repetition) % ARMS.size()]
                for warm: int in range(WARM_CALLS):
                    if _call(arm, overlay, payload) != count:
                        failures += 1
                var durations: Array[int] = []
                var checksum: int = 0
                for batch: int in range(BATCHES):
                    var before: int = Time.get_ticks_usec()
                    for call_index: int in range(CALLS_PER_BATCH):
                        checksum += _call(arm, overlay, payload)
                    var elapsed: int = Time.get_ticks_usec() - before
                    durations.append(elapsed)
                    if elapsed < 0:
                        failures += 1
                if checksum != count * BATCHES * CALLS_PER_BATCH:
                    failures += 1
                rows.append({
                    "count": count, "repeat": repetition, "arm": arm,
                    "batches_usec": durations, "calls_per_batch": CALLS_PER_BATCH,
                    "checksum": checksum
                })
    # Negative aliasing control. The real overlay owns a detached copy:
    # caller mutations after present must not alter the displayed snapshot.
    var owned_source: Array = _parts(2)
    overlay.present(owned_source, Vector2.ZERO, VIEW, CONTENT)
    var original_id: String = str(overlay._parts[0].get("part_id"))
    owned_source[0]["part_id"] = "changed-after-present"
    var detached: bool = str(overlay._parts[0].get("part_id")) == original_id
    overlay.present(owned_source, Vector2.ZERO, VIEW, CONTENT)
    var updated: bool = str(overlay._parts[0].get("part_id")) == "changed-after-present"
    if not detached or not updated:
        failures += 1
    var output: Dictionary = {
        "schema": "inv154-physical-overlay-present-v1",
        "engine": Engine.get_version_info().get("string", "unknown"),
        "os_name": OS.get_name(), "processor": OS.get_processor_name(),
        "display_server": DisplayServer.get_name(),
        "scenario": "synthetic immutable part dictionaries; actual unmodified overlay.present; headless",
        "repeats": REPEATS, "batch_count": BATCHES, "calls_per_batch": CALLS_PER_BATCH,
        "counts": COUNTS, "arms": ARMS, "rows": rows, "failures": failures,
        "copy_isolation": detached, "next_publication_visible": updated,
    }
    print("INV154_PHYSICAL_OVERLAY_PROBE " + JSON.stringify(output))
    overlay.queue_free()
    quit(0 if failures == 0 else 1)
