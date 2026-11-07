extends SceneTree

# Five source-identical LCB-FEEL capsules, admitted as workbench starts and
# exercised through the *current* native MicroScenario prepared-session host.
# Same Water family, same initial cells, same deterministic ticks at workers 1/4.
# No performance thresholds, new interface, solver changes or material defaults.
const Salvage = preload("res://tests/support/workbench_lcb_salvage.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const FAMILIES: Array[String] = [
    "freemass_v1", "cellular_yield_v1", "pressure_flow_v1", "inertial_cellular_v1",
]
var assertions := 0
var failures := 0
var completed_arms := 0

func _initialize() -> void:
    run.call_deferred()

func check(ok: bool, detail: String) -> bool:
    assertions += 1
    if not ok:
        failures += 1
        push_error("WORKBENCH_LCB_SALVAGE: " + detail)
    return ok

func choice_for(bridge: Variant, defaults: PackedInt32Array, family: String) -> Dictionary:
    for entry: Dictionary in bridge.liquid_policy_assignment_choices(defaults, 3):
        if bool(entry.get("accepted", false)) and str(entry.get("family", "")) == family \
                and str(entry.get("variant", "")) == "reference":
            return entry
    return {}

func run_arm(definition: Dictionary, policy: PackedInt32Array,
        family: String, workers: int, label: String) -> Dictionary:
    var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
    if not check(world != null and world.diagnostic_reset({"workers":workers}),
            label + " " + family + " w%d native reset" % workers):
        return {"ok":false}
    world.set_simulation_window_enabled(false)
    var host: CyberMicroScenarioHost = Host.new()
    var setup: Dictionary = {"intent":"controlled", "maximum_rule_radius":3,
        "normalization":"water-normalize-v1"}
    if not check(host.install(world, definition, "Benchmark", true, policy, setup),
            label + " " + family + " w%d admission: %s" % [workers,host.last_error]):
        return {"ok":false}
    var applied: Dictionary = world.get_liquid_solver_policy()
    var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
    var correct_family := false
    for assignment: Dictionary in applied.get("assignments", []):
        if int(assignment.get("material", -1)) == 3:
            correct_family = str(assignment.get("applied_family", "")) == family \
                and str(assignment.get("applied_variant", "")) == "reference"
    check(correct_family and int(applied.get("maximum_rule_radius", -1)) == 3 \
        and int(world.get_worker_threads()) == workers,
        label + " " + family + " w%d genuine applied policy/radius/capacity" % workers)
    check(str(receipt.get("run_intent", "")) == "controlled" \
        and int(receipt.get("worker_threads", -1)) == workers \
        and int(receipt.get("maximum_rule_radius", -1)) == 3,
        label + " " + family + " w%d construction receipt" % workers)
    var hashes: Array[String] = []
    var values: Array[int] = []
    var first: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024,1024))
    check(int(first.get("water_integer", -1)) == Salvage.INITIAL_WATER,
        label + " " + family + " w%d exact initial Water" % workers)
    hashes.append(str(world.get_physical_state_hash()))
    values.append(int(first.get("water_integer", -1)))
    for tick: int in range(1, Salvage.FAST_HORIZON + 1):
        if not check(host.advance(), label + " " + family + " w%d tick %d: %s" % [workers,tick,host.last_error]):
            return {"ok":false}
        var observed: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024,1024))
        var stored: int = int(observed.get("water_integer", -1))
        if not check(stored == Salvage.INITIAL_WATER,
                label + " " + family + " w%d tick %d Water conservation: %d" % [workers,tick,stored]):
            return {"ok":false}
        hashes.append(str(world.get_physical_state_hash()))
        values.append(stored)
    var capture: Dictionary = host.capture()
    if not check(int(capture.get("events_applied", -1)) == definition.events.size(),
            label + " " + family + " w%d scheduled events applied" % workers):
        return {"ok":false}
    check(not world.has_failed() and int(world.get_tick_index()) == Salvage.FAST_HORIZON,
        label + " " + family + " w%d finished healthy" % workers)
    host.clear()
    host = null
    world = null
    completed_arms += 1
    return {"ok":true, "hashes":hashes, "water":values}

func run() -> void:
    if not check(ClassDB.class_exists(&"CyberNativeCellWorld") \
            and ClassDB.class_exists(&"CyberDemoBridge"), "current native extension available"):
        finish()
        return
    var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
    var defaults: PackedInt32Array = bridge.default_liquid_policy()
    for case_id: String in Salvage.CASES:
        var source: Dictionary = Salvage.load_case(case_id)
        if not check(bool(source.get("ok", false)), case_id + " original source admission: " + str(source.get("error", ""))):
            continue
        var workbench: Dictionary = Salvage.workbench_start(source.definition, defaults)
        if not check(bool(workbench.get("ok", false)), case_id + " workbench setup: " + str(workbench.get("error", ""))):
            continue
        check(int(workbench.initial_water) == Salvage.INITIAL_WATER,
            case_id + " matching Water quantity in workbench start")
        var fast: Dictionary = Salvage.accelerated_case(source.definition)
        if not check(bool(fast.get("ok", false)), case_id + " bounded CI definition: " + str(fast.get("error", ""))):
            continue
        for family: String in FAMILIES:
            var selection: Dictionary = choice_for(bridge, defaults, family)
            if not check(not selection.is_empty(), case_id + " " + family + " admitted native menu choice"):
                continue
            var runs: Array[Dictionary] = []
            for workers: int in [1, 4]:
                var arm: Dictionary = run_arm(fast.definition, selection.request, family, workers, case_id)
                if arm.get("ok", false):
                    runs.append(arm)
            if runs.size() == 2:
                check(runs[0].hashes == runs[1].hashes and runs[0].water == runs[1].water,
                    case_id + " " + family + " 1/4-worker all-tick parity")
    check(completed_arms == Salvage.CASES.size() * FAMILIES.size() * 2,
        "all 40 genuine native arms executed; completed %d" % completed_arms)
    finish()

func finish() -> void:
    print("WORKBENCH_LCB_SALVAGE: %d assertions; %d failures; arms=%d" %
        [assertions,failures,completed_arms])
    quit(1 if failures > 0 else 0)
