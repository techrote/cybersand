extends SceneTree

# INV-004: exercise the ACTUAL, unmodified CyberMicroScenarioWorkbench.refresh()
# implementation in an isolated Windows-Godot UI control tree. The runner copies
# the source scripts byte-for-byte and creates only fake identity/contract objects.
# No native World, Main process, GPU, renderer frame or real gameplay is exercised.
#
# The suite compares full control refresh vs dictionary deep-copy in separate,
# interleaved timed arms, including inactive, guarded and HUD-hidden cases.
# These data cannot by themselves justify caching or claim a real FPS gain.

const Workbench = preload("res://scripts/microscenario_workbench.gd")
const FRAME_COUNT: int = 400
const REPEATS: int = 3

class ProbeHost extends Control:
    var world_view: Control
    var water_blind_set: Dictionary = {}
    var water_active_blind_label: String = ""
    var pending_water_apply: Dictionary = {}
    var pending_microscenario_apply: Dictionary = {}
    var microscenario_hud_hidden: bool = false
    var selected_material_id: int = 1
    var brush_shape: String = "circle"
    var brush_size_px: int = 4
    var brush_rectangle_ratio: int = 2
    var brush_rectangle_vertical: bool = false
    var paused: bool = true
    var microscenario_error: String = ""
    var tower_context: Dictionary = {}
    var camera_origin: Vector2 = Vector2.ZERO
    var current_view_size: Vector2i = Vector2i(256, 256)
    func material_name(material_id: int) -> String:
        return "fixture_%d" % material_id
    func view_content_rect() -> Rect2:
        return Rect2(Vector2.ZERO, Vector2(256, 256))


func _init() -> void:
    call_deferred("_run")


func _context(observations_count: int, material_count: int, active: bool) -> Dictionary:
    var observations: Array = []
    for index: int in range(observations_count):
        observations.append({
            "id": "obs-%d" % index,
            "metric": "cell",
            "value": {"material": index % 132, "state_a": index % 256,
                "temperature_raw": index * 17},
            "trace": ["registered", "sampled", "reported"],
        })
    var inspections: Array = []
    for left: int in range(material_count):
        for right: int in range(left, material_count):
            inspections.append({
                "left": left, "right": right,
                "provenance": ["source", "candidate", "not_applied"],
                "selected": {"rule": 0, "threshold": 0},
            })
    return {"micro_active": active, "microscenario": {
        "schema_version": 2,
        "definition_hash": "INV154-control-%d-%d" % [observations_count, material_count],
        "completed_tick": 5,
        "status": {"owner_epoch": 4, "generation": 5},
        "presentation": {"instructions": "source-bounded diagnostic; not gameplay", "regions": []},
        "material_ids": range(1, material_count + 1),
        "tools": ["paint", "erase"],
        "observations": observations,
        "interaction_inspection": inspections,
    }}


func _timed_arm(arm: String, workbench: CyberMicroScenarioWorkbench, context: Dictionary) -> Dictionary:
    var sample: Dictionary = {}
    var checksum: int = 0
    var started: int = Time.get_ticks_usec()
    for frame: int in range(FRAME_COUNT):
        if arm == "real_workbench_refresh":
            workbench.refresh(context)
            sample = workbench.current
        else:
            sample = context.get("microscenario", {}).duplicate(true)
        checksum += int(sample.get("completed_tick", -1))
        checksum += sample.get("observations", []).size()
        checksum += sample.get("interaction_inspection", []).size()
    return {"arm": arm, "elapsed_usec": Time.get_ticks_usec() - started,
        "frames": FRAME_COUNT, "checksum": checksum,
        "last_observations": sample.get("observations", []).size(),
        "last_inspections": sample.get("interaction_inspection", []).size()}


func _run() -> void:
    var host := ProbeHost.new()
    root.add_child(host)
    host.world_view = Control.new()
    host.add_child(host.world_view)
    var workbench := Workbench.new()
    host.add_child(workbench)
    workbench.setup(host)
    var cases: Array = [
        {"observations": 0, "materials": 1, "state": "active"},
        {"observations": 24, "materials": 8, "state": "active"},
        {"observations": 24, "materials": 24, "state": "active"},
        {"observations": 24, "materials": 24, "state": "inactive"},
        {"observations": 24, "materials": 24, "state": "guarded"},
        {"observations": 24, "materials": 24, "state": "hud_hidden"},
    ]
    var records: Array = []
    var failures: int = 0
    for spec: Dictionary in cases:
        var state: String = str(spec.state)
        var obs: int = int(spec.observations)
        var materials: int = int(spec.materials)
        var context: Dictionary = _context(obs, materials, state != "inactive")
        host.pending_water_apply = {"pending": true} if state == "guarded" else {}
        host.microscenario_hud_hidden = state == "hud_hidden"
        workbench._shown_hash = ""
        workbench.refresh(context)
        var expected_visible: bool = state in ["active", "hud_hidden"]
        if workbench.visible != expected_visible:
            failures += 1
            push_error("INV154 actual workbench guarded/active visibility contract failed: " + state)
        if workbench.overlay.visible != (state == "active"):
            failures += 1
            push_error("INV154 actual workbench overlay contract failed: " + state)
        # Interleaved arms and repetitions avoid a simple monotonic timing bias.
        for repeat: int in range(REPEATS):
            var order: Array[String] = ["real_workbench_refresh", "deepcopy_only"]
            if repeat % 2 == 1:
                order.reverse()
            var pair: Dictionary = {}
            for arm: String in order:
                var row: Dictionary = _timed_arm(arm, workbench, context)
                row["state"] = state
                row["observations"] = obs
                row["material_ids"] = materials
                row["inspection_pairs"] = materials * (materials + 1) / 2
                row["repeat"] = repeat
                records.append(row)
                pair[arm] = row
            if int(pair["real_workbench_refresh"].checksum) != int(pair["deepcopy_only"].checksum):
                failures += 1
                push_error("INV154 workbench refresh readback does not match its direct-copy control")
            if (int(pair["real_workbench_refresh"].last_observations) != obs
                    or int(pair["real_workbench_refresh"].last_inspections) != materials * (materials + 1) / 2):
                failures += 1
                push_error("INV154 refresh lost synthetic inspection/observation entries")
        # Deep copied current must not be caller-owned (mutating source after
        # the measured arm cannot change the retained workbench snapshot).
        workbench.refresh(context)
        var preserved: int = int(workbench.current["status"]["generation"])
        context["microscenario"]["status"]["generation"] = 999
        if int(workbench.current["status"]["generation"]) != preserved:
            failures += 1
            push_error("INV154 actual workbench current aliased caller-owned state")
    print("INV154_REAL_WORKBENCH_REFRESH " + JSON.stringify({
        "schema": "inv154-source-workbench-ui-refresh-v1",
        "scope": "unmodified-workbench-source-in-standalone-headless-Windows-Godot;synthetic-context;not-Main-or-GPU",
        "os_name": OS.get_name(), "godot": Engine.get_version_info(),
        "case_count": cases.size(), "repetitions": REPEATS, "records": records,
        "expected_records": cases.size() * REPEATS * 2, "failures": failures,
    }, "", false))
    workbench.queue_free()
    host.queue_free()
    quit(1 if failures != 0 else 0)
