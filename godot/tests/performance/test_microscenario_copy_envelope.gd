extends SceneTree

# INV-004 follow-up: bounded synthetic envelope grounded in the CURRENT
# MicroScenario contract (MAX_OBSERVATIONS=24), not a real graphical Main trial.
# The first #417 benchmark's 64/256 "observations" are impossible for a
# validated MicroScenario; a separate interaction_inspection array can be much
# larger. Both arrays are modelled explicitly here.
#
# A negative control deliberately mutates a nested Dictionary between simulated
# owner publications. It MUST break copy-on-publication parity, demonstrating
# why the original speed ratio is not by itself safe caching authorization.

const MAX_OBSERVATIONS: int = 24
const FRAMES: int = 800
const REPETITIONS: int = 3
const OBSERVATIONS: Array[int] = [0, 24]
const MATERIAL_COUNTS: Array[int] = [1, 8, 24]
const STRIDES: Array[int] = [1, 4]


func _init() -> void:
    call_deferred("_run")


func _make_context(observation_count: int, material_count: int) -> Dictionary:
    var observations: Array = []
    for index: int in range(observation_count):
        observations.append({
            "id": "obs-%d" % index,
            "tick": 0,
            "metric": "cell_state",
            "region": [index, 0, 1, 1],
            "value": {
                "material": index % 132,
                "state_a": (index * 3) % 256,
                "state_b": (index * 7) % 256,
                "temperature_raw": (index * 23) % 65536,
            },
        })
    var inspections: Array = []
    for left: int in range(material_count):
        for right: int in range(left, material_count):
            inspections.append({
                "left": left,
                "right": right,
                "rule": {"status": "not_selected", "threshold": 0},
                "provenance": ["current", "sparse-pair", "synthetic"],
            })
    var materials: Array = []
    for material_id: int in range(material_count):
        materials.append(material_id + 1)
    return {
        "micro_active": true,
        "microscenario": {
            "schema_version": 2,
            "definition_hash": "INV154-synthetic-envelope",
            "completed_tick": 0,
            "status": {"revision": 0},
            "observations": observations,
            "observation_limit": MAX_OBSERVATIONS,
            "material_ids": materials,
            "interaction_inspection": inspections,
            "presentation": {"instructions": "synthetic", "regions": []},
        },
    }


func _measure(arm: String, observations: int, materials: int, stride: int,
        mutate_between_publications: bool) -> Dictionary:
    var context: Dictionary = _make_context(observations, materials)
    var retained: Dictionary = {}
    var cloned: int = 0
    var digest: int = 0
    var started: int = Time.get_ticks_usec()
    for frame: int in range(FRAMES):
        # Source-backed desktop model: the owner publishes a complete new
        # context at each declared snapshot boundary. No mutation is allowed
        # between boundaries in the ordinary control arm.
        if frame % stride == 0:
            context["microscenario"]["completed_tick"] = int(frame / stride)
            context["microscenario"]["status"]["revision"] = frame
        elif mutate_between_publications:
            # Deliberate counterexample only; not an assertion that actual
            # CyberSand desktop mutates this specific field in place.
            context["microscenario"]["status"]["revision"] = frame
        if arm == "every_frame" or frame % stride == 0:
            retained = context.get("microscenario", {}).duplicate(true)
            cloned += 1
        digest += int(retained.get("completed_tick", -1)) * ((frame % 7) + 1)
        digest += int(retained.get("status", {}).get("revision", -1))
        digest += retained.get("observations", []).size()
        digest += retained.get("interaction_inspection", []).size()
    return {
        "arm": arm,
        "observations": observations,
        "materials": materials,
        "synthetic_inspection_pairs": materials * (materials + 1) / 2,
        "frames": FRAMES,
        "stride": stride,
        "mutate_between_publications": mutate_between_publications,
        "clones": cloned,
        "digest": digest,
        "elapsed_usec": Time.get_ticks_usec() - started,
    }


func _pair(observations: int, materials: int, stride: int, repeat: int,
        negative_control: bool, results: Array) -> int:
    var arms: Array[String] = ["every_frame", "on_publication"]
    if repeat % 2 == 1:
        arms.reverse()
    var recorded: Dictionary = {}
    for arm: String in arms:
        var result: Dictionary = _measure(arm, observations, materials, stride,
            negative_control)
        result["repeat"] = repeat
        result["kind"] = "inplace_negative_control" if negative_control else "immutable_publications"
        results.append(result)
        recorded[arm] = result
    var current: Dictionary = recorded["every_frame"]
    var candidate: Dictionary = recorded["on_publication"]
    var expected_equal: bool = not negative_control
    var actually_equal: bool = int(current.digest) == int(candidate.digest)
    var expected_clones: int = int(ceili(float(FRAMES) / float(stride)))
    if actually_equal != expected_equal or int(current.clones) != FRAMES or int(candidate.clones) != expected_clones:
        push_error("INV154 envelope discriminator parity/clone contract failed: observations=%d materials=%d stride=%d repeat=%d negative=%s" % [
            observations, materials, stride, repeat, str(negative_control)])
        return 1
    return 0


func _run() -> void:
    var results: Array = []
    var failures: int = 0
    var pair_checks: int = 0
    for observations: int in OBSERVATIONS:
        if observations > MAX_OBSERVATIONS:
            push_error("Disallowed synthetic MicroScenario observation population")
            failures += 1
            continue
        for materials: int in MATERIAL_COUNTS:
            for stride: int in STRIDES:
                for repeat: int in range(REPETITIONS):
                    failures += _pair(observations, materials, stride, repeat, false, results)
                    pair_checks += 1
    # The counterexample is only meaningful if there are frames between
    # publications. It is an intentional semantic counterexample, not a bug.
    for repeat: int in range(REPETITIONS):
        failures += _pair(24, 8, 4, repeat, true, results)
        pair_checks += 1
    print("INV154_MICROSCENARIO_ENVELOPE_PROBE " + JSON.stringify({
        "schema": "inv154-observation-and-inspection-envelope-v1",
        "scope": "synthetic-dictionary-copy-only;observation-limit-24;not-real-Main-FPS",
        "os_name": OS.get_name(),
        "godot_version": Engine.get_version_info(),
        "frames": FRAMES,
        "repetitions": REPETITIONS,
        "pair_checks": pair_checks,
        "cases": results,
        "failures": failures,
    }, "", false))
    quit(1 if failures != 0 else 0)
