extends SceneTree

# Real Rapier lifecycle regression. Delayed/repeated bridge commands must not
# target another native incarnation or wake a body which already settled.
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge = Bridge.new()
	_expect(bridge.initialize(8127).get("ok", false), "actual pinned Rapier initialized")
	_expect(bridge.install_terrain([{"id": 0, "session": 8127, "revision": 1,
		"digest": "identity-floor", "rectangles": PackedInt32Array([0, 90, 192, 4])}]).get("ok", false),
		"actual support collider installed")
	var shard: Dictionary = _shard(1)
	_expect(bridge.reserve_body(shard).get("ok", false), "current native identity reserved")
	var rid: RID = bridge.bodies[1].rid
	for key: String in ["session", "generation", "body_generation", "transaction", "geometry_revision"]:
		var stale: Dictionary = shard.duplicate(true)
		stale[key] = int(stale[key]) + 1
		_expect(not bridge.reserve_body(stale).get("ok", false), "reservation rejects changed " + key)
		_expect(not bridge.activate(stale).get("ok", false), "activation rejects changed " + key)
		if key != "geometry_revision":
			stale.geometry_revision = 2
			stale.geometry_digest = "newer-shape"
			_expect(not bridge.install_geometry(stale).get("ok", false), "geometry rejects changed " + key)
	_expect(not bridge.bodies[1].active and PhysicsServer2D.body_get_collision_layer(rid) == 0,
		"refused commands never activate the reserved material owner")
	for phase: String in ["Prepared", "PhysicsReserved", "CommittedInactive", "TerrainInstalled", "MaskApplied", "Retired"]:
		var premature: Dictionary = shard.duplicate(true)
		premature.lifecycle = phase
		premature.owns_inventory = true
		_expect(not bridge.activate(premature).get("ok", false) and not bridge.bodies[1].active,
			"native " + phase + " publication cannot skip the activation barrier")
	var unowned: Dictionary = shard.duplicate(true)
	unowned.lifecycle = "ReadyToActivate"
	unowned.owns_inventory = false
	_expect(not bridge.activate(unowned).get("ok", false), "unowned publication cannot activate material")
	shard.lifecycle = "ReadyToActivate"
	shard.owns_inventory = true
	_expect(bridge.activate(shard).get("ok", false), "original authoritative command remains executable")
	shard.lifecycle = "Active"
	for tick: int in range(600):
		if not bridge.step().get("ok", false):
			_expect(false, "real settling interval stays in the admitted envelope")
			break
		if tick % 120 == 0:
			await process_frame
	var sleeping: bool = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING)
	_expect(sleeping, "real gravity and contact settle naturally before duplicate delivery")
	var before: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var angular: float = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	var events_before: int = bridge.diagnostic_events.size()
	for duplicate: int in range(8):
		var receipt: Dictionary = bridge.activate(shard)
		_expect(receipt.get("ok", false) and receipt.get("activated", false) and receipt.get("duplicate", false),
			"exact repeated activation returns an installed receipt")
		_expect(bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING)),
			"duplicate delivery preserves real sleep")
	_expect(bridge.diagnostic_events.size() == events_before, "duplicates do not invent physical activation events")
	_expect(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM) == before
		and PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY) == velocity
		and PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY) == angular,
		"idempotent activation preserves exact backend pose and velocity")
	for key: String in ["mass", "inertia", "com_x", "geometry_revision", "geometry_digest", "rectangles"]:
		var changed: Dictionary = shard.duplicate(true)
		if key == "rectangles":
			changed.rectangles = PackedInt32Array([0, 0, 3, 2])
		elif key == "geometry_digest":
			changed.geometry_digest = "conflict"
		elif key == "geometry_revision":
			changed.geometry_revision = 2
		else:
			changed[key] = float(changed[key]) + 1.0
		_expect(not bridge.reserve_body(changed).get("ok", false), "duplicate reservation checks installed " + key)
		_expect(not bridge.activate(changed).get("ok", false), "duplicate activation checks installed " + key)
		if key != "geometry_revision":
			_expect(not bridge.install_geometry(changed).get("ok", false), "equal-revision update checks installed " + key)
	_expect(bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING)),
		"conflicting deliveries leave a settled body asleep")
	var eroded: Dictionary = shard.duplicate(true)
	eroded.geometry_revision = 2
	eroded.geometry_digest = "identity-eroded"
	eroded.rectangles = PackedInt32Array([0, 0, 2, 1])
	eroded.mass = 2.0
	eroded.com_y = 0.5
	eroded.inertia = 5.0 / 6.0
	_expect(bridge.install_geometry(eroded).get("ok", false), "legitimate revision still updates geometry")
	_expect(not bool(PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING)),
		"changed contact graph retains the qualified 001R wake behavior")
	_expect(not bridge.activate(shard).get("ok", false), "old activation cannot undo accepted geometry")
	var retired: Dictionary = eroded.duplicate(true)
	retired.geometry_revision = 3
	retired.geometry_digest = "identity-retired"
	retired.rectangles = PackedInt32Array()
	retired.mass = 0.0
	_expect(bridge.install_geometry(retired).get("retired_body", false) and bridge.bodies.is_empty(),
		"empty native skeleton retires actual body")
	_expect(not bridge.reserve_body(shard).get("ok", false) and not bridge.activate(shard).get("ok", false),
		"late pre-retirement command cannot recreate a disposed owner")
	var replacement: Dictionary = _shard(2)
	_expect(bridge.reserve_body(replacement).get("ok", false) and bridge.activate(replacement).get("ok", false),
		"fresh monotonic native identity uses the freed slot")
	_expect(not bridge.reserve_body(shard).get("ok", false) and bridge.bodies.size() == 1,
		"retired identity cannot steal capacity from its successor")
	bridge.shutdown()
	print(JSON.stringify({"schema": "objectshard-physics-identity-test-v1", "checks": checks,
		"failures": failures, "engine": Engine.get_version_info(), "platform": OS.get_name()}))
	quit(failures)


func _shard(id: int) -> Dictionary:
	return {"session": 8127, "id": id, "generation": 1, "body_generation": 1,
		"transaction": id, "geometry_revision": 1, "geometry_digest": "identity-box-" + str(id),
		"rectangles": PackedInt32Array([0, 0, 2, 2]), "width": 2, "height": 2,
		"origin_x": 70, "origin_y": 20, "position_x": 70.0, "position_y": 20.0, "rotation": 0.0,
		"mass": 4.0, "com_x": 1.0, "com_y": 1.0, "inertia": 8.0 / 3.0}


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
