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
        "states": PackedFloat64Array(), "geometry": PackedFloat64Array(), "bodies": []
    }
    var physical := PackedFloat32Array()
    for index: int in range(64):
        var id: int = index + 1
        var x: int = 50 + (index % 8) * 16
        var y: int = 50 + floori(index / 8.0) * 16
        sample.states.append_array(PackedFloat64Array([id, x, y, 0, 8, 8, 0, 0, 0, 1, 1, 20, x, y, 0.4, 1.0/60.0, 501]))
        sample.geometry.append_array(PackedFloat64Array([0, 0, 8, 8]))
        sample.bodies.append({"id": id, "instance_id": 41 + id, "generation": 501, "first_proxy": id,
            "count": 1, "budget": 20.0, "gravity": 92.0, "external_drive": false})
        physical.append_array(PackedFloat32Array([id, x, y, 0, 8, 8, 0, 0, 0, 1, 1]))
    var profile: Dictionary = Profiles.resolve(Profiles.preset(0))
    expect(profile.get("ok", false), "production liquid transport profile resolved")
    var options: Dictionary = {
        "workbench_extent": Vector2i(256, 256),
        "workbench_response": "LA-SELECTIVE",
        "workbench_sample": sample,
        "region": PackedInt32Array([0, 0, 256, 256]),
        "intent": "exploratory",
        "definition_hash": "objectshard-m4-sameworld-extension-test".sha256_text(),
        "initial_bodies": physical,
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
    expect(world.simulation_tick(),"ordinary World preattachment baseline tick")
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
    _terrain_batches(world, state)
    var sample2: Dictionary = sample.duplicate(true)
    for index: int in range(64): sample2.states[index * 17 + 10] = 2
    sample2.states[1] = 50.125
    sample2.states[12] = 50.125
    expect(world.prepare_workbench_coupling(sample2.states, sample2.geometry,
        sample2.bodies, sample2.session, sample2.epoch, false),
        "original immutable GCR continues composing in same World")
    expect(int(state.get("first_mutable_body_id", 0)) > 64 and world.rigid_body_id_at(162, 162) == 64,
        "64th immutable actor proxy retains its native identity beside reserved moving material")
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

func _terrain_request(world: Variant, state: Dictionary, cells: Array, operation: String = "erase") -> Dictionary:
    return {"native_instance_id":world.get_instance_id(), "session":501, "owner_epoch":501,
        "world_generation":1, "transport_generation":1, "shard_session":state.shard_session,
        "world_incarnation":state.world_incarnation, "action_id":1, "port_generation":1,
        "operation":operation, "domain":"terrain", "position":cells[0], "target":{},
        "terrain_cells":cells, "observation":{"world_revision":world.get_revision(), "publication_sequence":1},
        "probability_ppm":1000000, "seed":31, "material_filter":-1}

func _terrain_batches(world: Variant, state: Dictionary) -> void:
    const A := Vector2i(10,190)
    const B := Vector2i(11,190)
    for cell: Vector2i in [A,B]:
        expect(world.object_shard_edit_cell(cell,7,37,0,402).get("ok",false), "native terrain batch fixture written")
    var base: Dictionary = _terrain_request(world,state,[A,B,B])
    var malformed: Array[Dictionary] = []
    var bad: Dictionary = base.duplicate(true)
    bad.terrain_cells = 42
    malformed.append(bad)
    bad = base.duplicate(true)
    bad.terrain_cells = []
    bad.terrain_cells.resize(4097)
    bad.terrain_cells.fill(A)
    malformed.append(bad)
    bad = base.duplicate(true)
    bad.target = {"unexpected":{"nested":[1,2,3]}}
    malformed.append(bad)
    bad = base.duplicate(true)
    bad.position = B
    malformed.append(bad)
    bad = base.duplicate(true)
    bad.domain = "moving"
    malformed.append(bad)
    bad = base.duplicate(true)
    bad.seed = -1
    malformed.append(bad)
    bad = base.duplicate(true)
    bad.native_instance_id += 1
    malformed.append(bad)
    bad = base.duplicate(true)
    bad.observation.world_revision -= 1
    malformed.append(bad)
    for rejected: Dictionary in malformed:
        var receipt: Dictionary = world.object_shard_workbench_action(rejected)
        expect(not receipt.get("ok",false), "malformed, oversized, foreign or stale native batch refused")
        expect(world.stored_material_at(A.x,A.y)==7 and world.stored_material_at(B.x,B.y)==7 \
            and world.get_revision()==base.observation.world_revision, "native parser refusal preserves all material and revision")
    for domain: Variant in ["unknown",17,{"nested":[]}]:
        bad = base.duplicate(true)
        bad.erase("terrain_cells")
        bad.targets = [{}]
        bad.domain = domain
        expect(world.object_shard_workbench_action(bad).get("outcome","")=="InvalidBatchDomain",
            "unknown or non-string structural domain refuses before target parsing")
    var protected: Dictionary = _terrain_request(world,state,[A,Vector2i(50,50)])
    expect(not world.object_shard_workbench_action(protected).get("ok",false), "immutable actor overlap refuses complete native batch")
    expect(world.stored_material_at(A.x,A.y)==7, "protected later cell cannot permit an earlier debit")
    var ignite: Dictionary = _terrain_request(world,state,[A,B,B],"ignite")
    var result: Dictionary = world.object_shard_workbench_action(ignite)
    expect(result.get("accepted",false) and result.get("same_world",false) and result.get("changed_cells",0)==2 \
        and result.get("requested_cells",0)==3 and result.get("unique_cells",0)==2 \
        and result.get("geometry_rebuilds",-1)==0 and result.get("removed_cells",-1)==0,
        "native area ignition deduplicates actual cells without geometry reconstruction")
    expect(result.get("source_terrain_cells",[])==ignite.terrain_cells and result.get("terrain_changed_cells",[]).size()==2,
        "native terrain receipt echoes source and exact deduplicated changed cells")
    expect(world.object_shard_edit_cell(A,7,37,117,402).get("ok",false), "fixture simulates a progressed burning countdown")
    ignite = _terrain_request(world,state,[A,B,B],"ignite")
    result = world.object_shard_workbench_action(ignite)
    expect(result.get("accepted",false) and result.get("changed_cells",-1)==0 \
        and world.object_shard_inspect_cell(A).get("state_b",0)==117 \
        and world.get_revision()==ignite.observation.world_revision, "repeated ignition cannot reset countdown or fabricate a material revision")
    var filtered: Dictionary = _terrain_request(world,state,[A,B])
    filtered.material_filter = 43
    result = world.object_shard_workbench_action(filtered)
    expect(result.get("accepted",false) and result.get("changed_cells",-1)==0 \
        and world.get_revision()==filtered.observation.world_revision, "no eligible filtered material is an observable native no-op")
    base = _terrain_request(world,state,[A,B,B])
    result = world.object_shard_workbench_action(base)
    expect(result.get("accepted",false) and result.get("removed_cells",0)==2 \
        and result.get("terrain_changed_cells",[]).size()==2 \
        and world.stored_material_at(A.x,A.y)==0 and world.stored_material_at(B.x,B.y)==0,
        "one native terrain transaction erases exactly the two unique cells")
    expect(world.get_revision()==base.observation.world_revision+1, "native terrain batch publishes one facade revision")
    expect(not world.object_shard_workbench_action(base).get("ok",false), "previous terrain observation cannot be replayed after material publication")

func _finish() -> void:
    print(JSON.stringify({"schema":"objectshard-m4-actual-godot-sameworld-v1",
        "checks":checks,"failures":failures,
        "scope":"actual Godot 4.7 native Workbench World owner-local attachment/GCR/native tick; NOT Rapier movement"}))
    quit(0 if failures.is_empty() else 1)
