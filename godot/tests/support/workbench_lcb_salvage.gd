extends RefCounted

# Salvage of #370's five controlled leak/drain capsules. The unchanged source
# fixtures remain valid MicroScenarios; this adapter also produces real
# workbench starting setups from the *same* geometry and full-cell Water.
# Legacy Wall (ID 1) is mapped to the workbench's hard-wall stamp (ID 58).
# Scheduled openings are a separate test plan, not permanent starting paint.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const BASE := "res://tests/fixtures/workbench/lcb_salvage/"
const CASES: Array[String] = [
    "lcb.feel.leak-side.vented.v1",
    "lcb.feel.leak-side.sealed.v1",
    "lcb.feel.drain-bottom.vented.v1",
    "lcb.feel.drain-bottom.sealed.v1",
    "lcb.feel.tank-closed.control.v1",
]
const FAST_HORIZON := 16
const FAST_OPEN_TICK := 4
const INITIAL_WATER := 124 * 110 * 255

static func load_case(case_id: String) -> Dictionary:
    if not case_id in CASES:
        return {"ok":false, "error":"Unregistered capsule: " + case_id}
    var path := BASE + case_id + ".json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok":false, "error":"Capsule unavailable: " + path}
    return Contract.parse(file.get_as_text())

static func workbench_start(definition: Dictionary, policy: PackedInt32Array) -> Dictionary:
    var start: Dictionary = Setup.fresh(policy, Vector2i(1024, 1024))
    var old_rectangles: Array = definition.rectangles
    if old_rectangles.size() % 5 != 0:
        return {"ok":false, "error":"Malformed source rectangle vector"}
    for index: int in range(0, old_rectangles.size(), 5):
        var material: int = int(old_rectangles[index + 4])
        if material == 0:
            continue
        # Workbench starting paint uses its native authoring palette, not the
        # legacy MicroScenario Wall ID. Both are non-flowing solid boundaries.
        if material == 1:
            material = Setup.WALL
        start.edits.append([
            int(old_rectangles[index]), int(old_rectangles[index + 1]),
            int(old_rectangles[index + 2]), int(old_rectangles[index + 3]),
            material,
        ])
    var fills: Array = definition.partial_water_fills
    if fills.size() % 6 != 0:
        return {"ok":false, "error":"Malformed Water fill vector"}
    var water_quantity := 0
    for index: int in range(0, fills.size(), 6):
        var quantity: int = int(fills[index + 4])
        if quantity != 255 or int(fills[index + 5]) != 0:
            return {"ok":false, "error":"Workbench start requires unchanged full-cell Water"}
        var width: int = int(fills[index + 2])
        var height: int = int(fills[index + 3])
        water_quantity += width * height * quantity
        start.edits.append([
            int(fills[index]), int(fills[index + 1]), width, height, Setup.WATER,
        ])
    var reason: String = Setup.validate(start)
    if not reason.is_empty():
        return {"ok":false, "error":"Workbench rejected source geometry: " + reason}
    var packed: Dictionary = Setup.rectangles(start)
    if packed.has("error"):
        return {"ok":false, "error":str(packed.error)}
    return {"ok":true, "setup":start, "native_rectangles":packed.runs,
        "initial_water":water_quantity}

static func accelerated_case(definition: Dictionary) -> Dictionary:
    # Original capsules and their registered 120/1200-tick evidence are never
    # rewritten. CI moves only the breach at t120 to t4 and observes t0..16.
    # This is a NEW test identity, not a rerun of the historical experiment.
    var fast: Dictionary = definition.duplicate(true)
    for event: Dictionary in fast.events:
        if int(event.tick) == 120:
            event.tick = FAST_OPEN_TICK
    fast.observations = []
    fast.conditions = []
    fast.presentation.duration_ticks = FAST_HORIZON
    fast.presentation.instructions = str(fast.presentation.instructions) + " CI-only breach at tick 4; outcome measured through tick 16."
    return Contract.validate(fast)
