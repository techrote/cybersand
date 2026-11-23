extends SceneTree
# Actual Godot 4.7 GDExtension exercised against the ordinary prepared Workbench
# World. This is NOT a standalone ObjectShardLab and not a Rapier acceptance.
const Profiles = preload("res://scripts/transport_profiles.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func expect(value: bool, detail: String) -> void:
    checks += 1
    if not value:
        failures.append(detail)
        push_error("OBJECTSHARD_M4_ATTACHED: " + detail)

func _run() -> void:
    expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "real GDExtension class loaded")
    expect(ClassDB.class_exists(&"CyberDemoBridge"), "real ordinary prepared-World bridge loaded")
    if not failures.is_empty():
        _finish()
        return
    var adapter: Variant = ClassDB.instantiate(&"CyberDemoBridge")
    var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
    var identity: int = world.get_instance_id()
    var sample: Dictionary = {
        "session": 501, "epoch": 501,
        "states": PackedFloat64Array([1, 50, 50, 0, 8, 8, 0, 0, 0, 1, 1, 20, 50, 50, 0.4, 1.0/60.0, 501]),
        "geometry": PackedFloat64Array([0, 0, 8, 8]),
        "bodies": [{"id": 1, "instance_id": 42, "generation": 501, "first_proxy": 1,
            "count": 1, "budget": 20.0, "gravity": 92.0, "external_drive": false}]
    }
    var profile: Dictionary = Profiles.resolve(Profiles.preset(0))
    expect(profile.get("ok", false), "production liquid transport profile resolved")
    var options: Dictionary = {
        "workbench_extent": Vector2i(256, 256),
        "workbench_response": "LA-SELECTIVE",
        "workbench_sample": sample,
        "region": PackedInt32Array([0, 0, 256, 256]),
        "intent": "exploratory",
        "definition_hash": "objectshard-m4-sameworld-extension-test".sha256_text(),
        "initial_bodies": PackedFloat32Array([1, 50, 50, 0, 8, 8, 0, 0, 0, 1, 1]),
        "workbench_worker_threads": 1
    }
    var token: int = adapter.prepare_liquid_world(world, PackedInt32Array([0, 200, 256, 8, 1]),
        profile.packed, PackedInt32Array([1, 8, 12, 0]), PackedInt32Array(),
        adapter.default_liquid_policy(), options)
    expect(token > 0 and adapter.commit_liquid_world(world, token),
        "actual Workbench prepared native World committed")
    if token <= 0:
        _finish()
        return
    expect(world.get_instance_id() == identity, "Workbench facade instance not replaced")
    expect(world.has_method(&"object_shard_attach") and world.has_method(&"object_shard_status"),
        "owner-local same-World native methods actually registered")
    var before: int = world.get_tick_index()
    var attached: Dictionary = world.object_shard_attach(Rect2i(0, 0, 256, 256))
    expect(attached.get("ok", false), "owner-local coordinator attaches without private World")
    expect(attached.get("same_world", false) and attached.get("worker_exclusive", false),
        "attachment returns genuine same-World owner proof")
    expect(int(attached.get("native_instance_id", -1)) == identity, "receipt identifies same native facade")
    var state: Dictionary = world.object_shard_status()
    expect(state.get("attached", false) and int(state.get("native_instance_id", -1)) == identity,
        "readback retains one authoritative Workbench World")
    expect(int(state.get("shard_session", 0)) > 0 and int(state.get("world_incarnation", 0)) > 0,
        "real Coordinator native incarnation allocated and fenced")
    expect(not world.object_shard_attach(Rect2i(0, 0, 256, 256)).get("ok", false),
        "second coordinator attachment refused")
    expect(world.get_tick_index() == before, "attachment performs zero autonomous World ticks")
    var frame: Dictionary = world.object_shard_snapshot()
    expect(frame.get("ok", false) and int(frame.get("session", 0)) == int(state.shard_session),
        "copied same-World native materials and shard snapshot")
    expect(int(frame.get("tick", -1)) == before, "snapshot uses authoritative World semantic tick")
    var sample2: Dictionary = sample.duplicate(true)
    sample2.states[10] = 2
    sample2.states[1] = 50.125
    sample2.states[12] = 50.125
    expect(world.prepare_workbench_coupling(sample2.states, sample2.geometry,
        sample2.bodies, sample2.session, sample2.epoch, false),
        "original immutable GCR continues composing in same World")
    expect(world.simulation_tick(), "native owner ticks attached World once")
    expect(world.get_tick_index() == before + 1, "one and only one native World tick advanced")
    expect(not world.has_failed(), "attached World not quarantined by GCR composition")
    var next_frame: Dictionary = world.object_shard_snapshot()
    expect(int(next_frame.get("tick", -1)) == before + 1,
        "Coordinator follows actual authoritative tick; no second World")
    expect(int(next_frame.get("session", -1)) == int(frame.session),
        "owner-local shard session unchanged by ordinary World tick")
    expect(world.object_shard_retire(), "explicit retirement disposes borrowed Coordinator")
    expect(not world.object_shard_status().get("attached", false),
        "retired World has no borrowed attachment")
    expect(world.simulation_tick(), "ordinary native World keeps ticking after shard retirement")
    expect(world.get_tick_index() == before + 2,
        "retirement does not reset or replace the Workbench World")
    expect(world.get_instance_id() == identity, "actual single Workbench World facade persists")
    world = null
    adapter = null
    _finish()

func _finish() -> void:
    print(JSON.stringify({"schema":"objectshard-m4-actual-godot-sameworld-v1",
        "checks":checks,"failures":failures,
        "scope":"actual Godot 4.7 native Workbench World owner-local attachment/GCR/native tick; NOT Rapier movement"}))
    quit(0 if failures.is_empty() else 1)
