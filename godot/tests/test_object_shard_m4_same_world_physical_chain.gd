extends SceneTree

# Executes the actual ordinary CyberNativeCellWorld + existing Main-owned
# Rapier space, not a private M3 Coordinator or image-only reenactment.
# The selected native extension must be compiled from this exact checkout.
const Profiles = preload("res://scripts/transport_profiles.gd")
const ShardBridge = preload("res://scripts/object_shard_physics_bridge.gd")
const RAPIER: StringName = &"RapierPhysicsServer2D"
var checks: int = 0
var failures: Array[String] = []
var world: Object
var adapter: Object
var bridge: CyberObjectShardPhysicsBridge
var main_space: RID
var physical_steps: int = 0

func _initialize() -> void:
    call_deferred("_run")

func expect(ok: bool, why: String) -> bool:
    checks += 1
    if not ok:
        failures.append(why)
        push_error("M4_SAMEWORLD_PHYSICAL_CHAIN: " + why)
    return ok

func _ack(shard: Dictionary, kind: String) -> Dictionary:
    var value: Dictionary = {"kind":kind}
    for key: String in ["session","id","generation","transaction","body_generation",
        "payload_digest","geometry_revision","mask_digest","shape_digest"]:
        value[key] = shard[key]
    return value

func _current_shard(id: int) -> Dictionary:
    for row: Dictionary in world.object_shard_snapshot().get("shards",[]):
        if int(row.id) == id:
            return row
    return {}

func _promote() -> Dictionary:
    var preparation: Dictionary = {}
    for i: int in range(128):
        preparation = world.object_shard_prepare_next()
        if preparation.get("ok",false):
            return world.object_shard_snapshot()
        if str(preparation.get("outcome","")) not in ["Busy","Anchored"]:
            break
    expect(false,"native detached connected component prepared: "+str(preparation))
    return {}

func _wood_count() -> int:
    var frame: Dictionary = world.object_shard_snapshot()
    var count: int = 0
    for material: int in frame.get("world_materials",PackedByteArray()):
        if material == 7: count += 1
    for shard: Dictionary in frame.get("shards",[]):
        if not shard.get("owns_inventory",false): continue
        for material: int in shard.materials:
            if material == 7: count += 1
    return count

func _run() -> void:
    if not expect(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge")
        and ClassDB.class_exists(RAPIER),"native World, real Workbench bridge and selected Rapier classes"):
        _finish()
        return
    world = ClassDB.instantiate(&"CyberNativeCellWorld")
    adapter = ClassDB.instantiate(&"CyberDemoBridge")
    var original_instance: int = world.get_instance_id()
    var sample: Dictionary = {"session":401,"epoch":401,
        "states":PackedFloat64Array([1,50,50,0,8,8,0,0,0,1,1,20,50,50,0.4,1.0/60.0,401]),
        "geometry":PackedFloat64Array([0,0,8,8]),"bodies":[{
            "id":1,"instance_id":42,"generation":401,"first_proxy":1,"count":1,
            "budget":20.0,"gravity":92.0,"external_drive":false}]}
    var profile: Dictionary = Profiles.resolve(Profiles.preset(0))
    var options: Dictionary = {"workbench_extent":Vector2i(256,256),
        "workbench_response":"LA-SELECTIVE","workbench_sample":sample,
        "region":PackedInt32Array([0,0,256,256]),"intent":"exploratory",
        "definition_hash":"objectshard-m4-physical-existing-world-v1".sha256_text(),
        "initial_bodies":PackedFloat32Array([1,50,50,0,8,8,0,0,0,1,1]),
        "workbench_worker_threads":1}
    var token: int = adapter.prepare_liquid_world(world,
        PackedInt32Array([0,200,256,8,1]),profile.packed,
        PackedInt32Array([1,8,12,0]),PackedInt32Array(),
        adapter.default_liquid_policy(),options)
    if not expect(token>0 and adapter.commit_liquid_world(world,token),
        "actual ordinary prepared Workbench World installed"):
        _finish()
        return
    # The regular owner advances the initial World once before attaching; the
    # attachment itself must never create a second tick.
    expect(world.simulation_tick(),"initial ordinary World owner tick")
    var before: int = world.get_tick_index()
    var attached: Dictionary = world.object_shard_attach(Rect2i(0,0,256,256))
    if not expect(attached.get("ok",false) and attached.get("same_world",false)
        and int(attached.get("native_instance_id",-1))==original_instance,
        "native shard policy attached to exactly the original World identity"):
        _finish()
        return
    expect(world.get_tick_index()==before,"attachment performed zero autonomous ticks")
    # Author and detach without painting into any different World.
    for y: int in range(30,33):
        for x: int in range(30,33):
            expect(world.object_shard_edit_cell(Vector2i(x,y),7,170,0,400).get("ok",false),
                "author Wood through same World owner")
    for x: int in range(30,33):
        expect(world.object_shard_edit_cell(Vector2i(x,33),1,0,0,200).get("ok",false),
            "author structural support inside the live Workbench")
    expect(world.object_shard_edit_cell(Vector2i(95,170),3,128,0,200).get("ok",false),
        "author live Water on same actual World")
    expect(_wood_count()==9,"initial Wood quantity exactly nine native cells")
    for x: int in range(30,33):
        expect(world.object_shard_edit_cell(Vector2i(x,33),0,0,0,200).get("ok",false),
            "cut support by exact authoritative cell removal")
    var prepared: Dictionary = _promote()
    if prepared.is_empty():
        _finish()
        return
    var promotion: Dictionary = prepared.promotion
    var shard: Dictionary = prepared.shards[0]
    var id: int = int(shard.id)
    expect(promotion.get("present",false) and prepared.get("paused",false),
        "native promotion pauses exact material debit awaiting installed geometry")
    main_space = PhysicsServer2D.space_create()
    PhysicsServer2D.space_set_active(main_space,false)
    bridge = ShardBridge.new()
    if not expect(bridge.initialize(int(prepared.session),main_space).get("ok",false)
        and bridge.space==main_space,"real Main-owned shared Rapier space adopted"):
        _finish()
        return
    var reserved: Dictionary = bridge.reserve_body(shard)
    expect(reserved.get("ok",false) and bridge.bodies.has(id),
        "real Rapier rigid RID and mass/COM/inertia installed before debit")
    var reserved_ack: Dictionary = world.object_shard_acknowledge(_ack(shard,"PhysicsReserved"))
    if not expect(reserved_ack.get("ok",false),"actual physics reservation allows native atomic World debit"):
        _finish()
        return
    var after_debit: Dictionary = world.object_shard_snapshot()
    shard = _current_shard(id)
    expect(after_debit.get("paused",false) and shard.get("owns_inventory",false)
        and _wood_count()==9,"post-debit native Wood is in shard only, never duplicated")
    var installed: Dictionary = bridge.install_terrain(after_debit.terrain_chunks)
    if not expect(installed.get("ok",false),"actual postdebit hard-surface terrain installed in same Rapier space"):
        _finish()
        return
    var ack: Dictionary = _ack(shard,"TerrainInstalled")
    var chunks: Array = []
    for required: Dictionary in after_debit.promotion.chunks:
        for actual: Dictionary in installed.get("chunks",[]):
            if int(actual.id)==int(required.id):
                chunks.append(actual)
    ack["chunks"] = chunks
    if not expect(world.object_shard_acknowledge(ack).get("ok",false),
        "native exact revisioned terrain acknowledgement"):
        _finish()
        return
    shard = _current_shard(id)
    if not expect(bridge.activate(shard).get("ok",false),
        "real Rapier body activated only after authoritative debit and terrain install"):
        _finish()
        return
    if not expect(world.object_shard_acknowledge(_ack(shard,"BodyActivated")).get("ok",false),
        "native owner acknowledges actual enabled rigid body"):
        _finish()
        return
    expect(not world.object_shard_snapshot().get("paused",true),
        "post-activation material chemistry and ordinary World may progress")
    var first_y: float = float(_current_shard(id).position_y)
    var full_motion: bool = true
    for n: int in range(120):
        ClassDB.class_call_static(RAPIER,&"space_step",main_space,1.0/60.0)
        ClassDB.class_call_static(RAPIER,&"space_flush_queries",main_space)
        var motion: Dictionary = bridge.capture_completed_main_step(n+1)
        var applied: Dictionary = world.object_shard_accept_motion(motion.get("poses",[]))
        if not motion.get("ok",false) or not applied.get("ok",false):
            expect(false,"actual Rapier movement needs exact native applied pose receipt: "+str(applied))
            full_motion = false
            break
        if not world.simulation_tick():
            expect(false,"same authoritative World continues real material laws after physical pose: "+str(world.object_shard_status()))
            full_motion = false
            break
        physical_steps += 1
    expect(full_motion and physical_steps==120,"120 real Rapier movement and 120 real native owner ticks, no second ticks")
    var settled: Dictionary = _current_shard(id)
    expect(not settled.is_empty() and float(settled.get("position_y",0))>first_y+10.0,
        "real physical fall reflected in applied native shard pose")
    expect(_wood_count()==9,"material balance survives all real physical and Water ticks")
    expect(world.get_instance_id()==original_instance,
        "all chemistry, material transfer and physical motion share one native World identity")
    # Edit the MOVING inventory after actual applied pose, not ordinary terrain.
    if not settled.is_empty() and full_motion:
        # Native component discovery reserves a one-cell Empty ring around
        # the captured 3x3 Wood. The old test's hard-coded index 4 addressed
        # the ring (role Empty), NOT an owned structural Wood cell.
        # Choose an actual current, fully witnessed Wood structural cell.
        var structural_wood: Array[int] = []
        for cell_index: int in range(settled.roles.size()):
            if int(settled.roles[cell_index]) == 1 and int(settled.materials[cell_index]) == 7:
                structural_wood.append(cell_index)
        if not expect(structural_wood.size() == 9,
            "all nine moving Wood cells retain exact native Structural role"):
            _finish()
            return
        # Middle cell of the retained raster order gives the centre of the
        # authored 3x3; erasing it changes real geometry without disconnection.
        var target: int = structural_wood[int(structural_wood.size() / 2)]
        expect(int(settled.roles[target]) == 1 and int(settled.materials[target]) == 7,
            "moving-cell erase target is Wood owned by the current native shard")
        var request: Dictionary = {"session":int(settled.session),"id":int(settled.id),
            "generation":int(settled.generation),
            "sequence":int(world.object_shard_snapshot().next_transaction),
            "body_generation":int(settled.body_generation),
            "geometry_revision":int(settled.applied_physics_revision),
            "pose_serial":int(settled.pose_serial),
            "material_revision":int(settled.material_revision),
            "cell":target,"incarnation":int(settled.incarnations[target]),
            "capability_version":1,
            "expected":{"material":int(settled.materials[target]),
                "state_a":int(settled.states_a[target]),"state_b":int(settled.states_b[target]),
                "temperature":int(settled.temperature[target])}}
        var erased: Dictionary = world.object_shard_erase_shard(request)
        if not erased.get("ok", false):
            # Retain exact native refusal evidence. Never retry a possibly
            # executed edit or substitute a terrain brush.
            print("M4_ERASE_FAILURE_EVIDENCE " + JSON.stringify({
                "result": erased, "request": request,
                "phase": settled.get("lifecycle", ""),
                "native_applied_physics_revision": settled.get("applied_physics_revision", -1),
                "native_geometry_revision": settled.get("geometry_revision", -1),
                "geometry_pending": settled.get("geometry_pending", false),
                "native_pose_serial": settled.get("pose_serial", -1),
                "world_tick": world.get_tick_index()}))
        if expect(erased.get("ok",false),"real applied-pose moving Wood cell erased through native shard receipt"):
            expect(_wood_count()==8,"precisely one Wood cell removed, no other World inventory lost")
            var changed: Dictionary = _current_shard(id)
            var installed_geometry: Dictionary = bridge.install_geometry(changed)
            expect(installed_geometry.get("ok",false),"real changed-shape/mass/COM/inertia reinstalled on same RID")
            var kind: String = "BodyRetired" if installed_geometry.get("retired_body",false) else "GeometryInstalled"
            expect(world.object_shard_acknowledge(_ack(changed,kind)).get("ok",false),
                "real native revisioned changed-geometry acknowledgment")
    var retained_wood: int = _wood_count()
    var retained_owner: Dictionary = world.object_shard_status()
    expect(not world.object_shard_retire(),"explicit owner retirement refuses live material inventory")
    expect(world.object_shard_status().get("attached",false) and _wood_count()==retained_wood
        and world.object_shard_status().get("shard_session")==retained_owner.get("shard_session"),
        "refused retirement retains the exact native owner and every owned Wood cell")
    # A deliberate whole-World replacement is the existing scoped disposal
    # authority. Ordinary same-World retirement must never destroy inventory.
    var replacement: int = adapter.prepare_liquid_world(world,
        PackedInt32Array([0,200,256,8,1]),profile.packed,
        PackedInt32Array([1,8,12,0]),PackedInt32Array(),
        adapter.default_liquid_policy(),options)
    if not expect(replacement>0 and adapter.commit_liquid_world(world,replacement),
        "explicit fresh authored World safely replaces live owned material"):
        _finish()
        return
    if bridge!=null: bridge.shutdown()
    expect(not world.object_shard_status().get("attached",true),
        "whole-World replacement retires its previous coordinator")
    expect(world.simulation_tick() and world.object_shard_attach(Rect2i(0,0,256,256)).get("ok",false),
        "fresh empty material owner can attach to the replacement World")
    expect(world.object_shard_retire(),"empty attached Coordinator explicitly retires without material loss")
    expect(world.simulation_tick() and world.get_instance_id()==original_instance,
        "ordinary World remains alive and progressing after shard retirement")
    _finish()

func _finish() -> void:
    if bridge!=null:
        bridge.shutdown()
        bridge = null
    if main_space.is_valid():
        PhysicsServer2D.free_rid(main_space)
    world = null
    adapter = null
    print(JSON.stringify({"schema":"objectshard-m4-sameworld-rapier-physical-chain-v1",
        "checks":checks,"failures":failures,"native_and_rapier_steps":physical_steps,
        "scope":"actual native World + Godot Rapier shared space: author/cut/atomic debit/install/fall/chemistry/edit/retire",
        "no_synthetic_engine":true}))
    quit(0 if failures.is_empty() else 1)
