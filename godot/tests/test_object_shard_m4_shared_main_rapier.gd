extends SceneTree

# Actual RapierPhysicsServer2D native backend. The Main owner creates and
# steps exactly one existing space; M4 installs RIDs into that space and never
# calls space_step, frees that space, or invents a motion acknowledgement.
const ShardBridge = preload("res://scripts/object_shard_physics_bridge.gd")
const RAPIER: StringName = &"RapierPhysicsServer2D"
const DELTA: float = 1.0/60.0
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _expect(ok: bool, detail: String) -> void:
    checks += 1
    if not ok:
        failures.append(detail)
        push_error("OBJECTSHARD_M4_SHARED_RAPIER " + detail)

func _run() -> void:
    _expect(ClassDB.class_exists(RAPIER) and str(ProjectSettings.get_setting(
        "physics/2d/physics_engine", "")) == "Rapier2D",
        "actual supported Rapier2D backend selected")
    if not failures.is_empty():
        _finish()
        return
    var main_space: RID = PhysicsServer2D.space_create()
    PhysicsServer2D.space_set_active(main_space,false)
    _expect(main_space.is_valid(), "ordinary Main owns one actual Rapier space")
    var shards := ShardBridge.new()
    var start: Dictionary = shards.initialize(902,main_space)
    _expect(start.get("ok",false) and shards.space == main_space,
        "ObjectShard shares existing Main-owned space")
    _expect(not shards.begin_motion_tick(1).get("ok", false) and
        str(shards.begin_motion_tick(1).get("outcome","")) == "MainOwnsRapierStep",
        "M4 substep API cannot advance the Main-owned Rapier space")
    var terrain: Dictionary = shards.install_terrain([{
        "id":0,"session":902,"revision":1,"digest":"902-terrain",
        "rectangles":PackedInt32Array([0,90,192,3])
    }])
    _expect(terrain.get("ok",false) and terrain.get("installed",false),
        "real hard-surface collider installed in same existing space")
    var body: Dictionary = {"id":1,"session":902,"generation":1,"body_generation":1,
        "transaction":55,"geometry_revision":1,"geometry_digest":"902-body",
        "rectangles":PackedInt32Array([0,0,3,3]),"origin_x":32,"origin_y":20,
        "position_x":32.0,"position_y":20.0,"rotation":0.0,
        "mass":9.0,"com_x":1.5,"com_y":1.5,"inertia":13.5}
    var reserved: Dictionary = shards.reserve_body(body)
    _expect(reserved.get("ok",false) and int(reserved.get("shape_count",-1))==1,
        "mutable body's actual Rapier shape reserved with mass COM inertia")
    var activated: Dictionary = shards.activate(body)
    _expect(activated.get("ok",false) and activated.get("activated",false),
        "live mutable body activated with backend readback")
    PhysicsServer2D.body_set_state(shards.bodies[1].rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,0.6)
    var initial: Transform2D = PhysicsServer2D.body_get_state(shards.bodies[1].rid,
        PhysicsServer2D.BODY_STATE_TRANSFORM)
    var post: Dictionary = {"ok":false}
    var all_receipts: bool = true
    for n: int in range(100):
        # Exactly one physical step, by Main's existing backend, not M4.
        ClassDB.class_call_static(RAPIER,&"space_step",main_space,DELTA)
        ClassDB.class_call_static(RAPIER,&"space_flush_queries",main_space)
        post = shards.capture_completed_main_step(n+1)
        if not post.get("ok",false) or int(post.get("body_count",-1))!=1:
            all_receipts = false
            break
    _expect(all_receipts,"100 actual Main-owned Rapier step readbacks accepted")
    var last: Transform2D = PhysicsServer2D.body_get_state(shards.bodies[1].rid,
        PhysicsServer2D.BODY_STATE_TRANSFORM)
    _expect(last.origin.y > initial.origin.y+1.0,
        "body really falls under gravity in the shared Main space")
    _expect(last.origin.y < 92.0,
        "actual floor contact prevents catastrophic penetration")
    var duplicate: Dictionary = shards.capture_completed_main_step(100)
    _expect(not duplicate.get("ok",false) and duplicate.get("outcome")=="StaleMainPhysicsStep",
        "duplicate Main physics serial cannot manufacture a second motion receipt")
    _expect(post.get("poses",[]).size()==1 and
        int(post.poses[0].get("geometry_revision",-1))==1,
        "actual published pose retains native geometry revision identity")
    _expect(post.get("poses",[]).size()==1 and absf(float(post.poses[0].rotation))>0.05 and
        absf(wrapf(float(post.poses[0].rotation)-last.get_rotation(),-PI,PI))<0.00001,
        "shared Main native pose includes the actual continuously observed Rapier rotation")
    var serial: int = 100
    for direction: int in [1,-1]:
        var crossing: Dictionary = body.duplicate(true)
        crossing.id = 2 if direction==1 else 3
        crossing.transaction = 56 if direction==1 else 57
        crossing.position_x = 80.0 if direction==1 else 110.0
        crossing.rotation = float(direction)*(PI-0.01)
        crossing.angular_velocity = float(direction)*0.6
        _expect(shards.reserve_body(crossing).get("ok",false) and shards.activate(crossing).get("ok",false),
            "actual angular wrap fixture reserved and activated")
        for step: int in range(4):
            ClassDB.class_call_static(RAPIER,&"space_step",main_space,DELTA)
            ClassDB.class_call_static(RAPIER,&"space_flush_queries",main_space)
            serial += 1
            post = shards.capture_completed_main_step(serial)
        var continuous: float = 0.0
        for observed: Dictionary in post.get("poses",[]):
            if int(observed.id)==int(crossing.id): continuous = float(observed.rotation)
        var wrapped: Transform2D = PhysicsServer2D.body_get_state(shards.bodies[crossing.id].rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
        _expect(post.get("ok",false) and continuous*float(direction)>PI and
            absf(wrapf(continuous-wrapped.get_rotation(),-PI,PI))<0.00001,
            "actual shared Main angle remains continuous across "+str(direction)+" pi crossing")
    shards.shutdown()
    # A borrowed space remains owned by Main; stepping after shard disposal
    # must not fail or lose its native physical backend.
    ClassDB.class_call_static(RAPIER,&"space_step",main_space,DELTA)
    ClassDB.class_call_static(RAPIER,&"space_flush_queries",main_space)
    _expect(main_space.is_valid(),"retiring shard bridge does not free shared Main space")
    PhysicsServer2D.free_rid(main_space)
    _finish()

func _finish() -> void:
    print(JSON.stringify({"schema":"objectshard-m4-existing-main-rapier-v1",
        "checks":checks,"failures":failures,"platform":OS.get_name(),
        "scope":"real single Main-owned Rapier space: fall/contact/readback/retirement; no claim of native material integration"}))
    quit(0 if failures.is_empty() else 1)
