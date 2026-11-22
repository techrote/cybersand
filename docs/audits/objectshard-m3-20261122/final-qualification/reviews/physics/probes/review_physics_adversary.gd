extends SceneTree

const Host = preload("res://scripts/object_shard_worker_host.gd")
const View = preload("res://scripts/object_shard_lab_view.gd")
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
var host = Host.new()
var view = View.new()
var checks: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []

func _init() -> void:
	Engine.max_fps = 0
	call_deferred("_run")

func _expect(condition: bool, name: String, detail: Dictionary = {}) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(name + " " + JSON.stringify(detail))
	observations.append({"check": name, "ok": condition, "detail": detail})

func _idle() -> bool:
	var until: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < until:
		host.poll()
		host.pump_receipts(4000)
		if host.failed:
			return false
		if host.state == "Idle" and host.actions.is_empty() and host.pending.is_empty() and not host._tick_requested:
			return true
		await process_frame
	return false

func _take() -> Dictionary:
	var until: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < until:
		var rows: Array = host.worker.take_results(1)
		if not rows.is_empty():
			return rows[0]
		await process_frame
	return {}

func _tick() -> bool:
	var before: int = host.completed_ticks
	return host.request_tick().get("ok", false) and await _idle() and host.completed_ticks == before + 1

func _counts(source: Dictionary) -> Dictionary:
	var world: int = source.get("world_materials", PackedByteArray()).count(7)
	var owned: int = 0
	for shard: Dictionary in source.get("shards", []):
		if shard.get("owns_inventory", false):
			owned += shard.materials.count(7)
	return {"world": world, "owned": owned, "total": world + owned}

func _stable_wait(label: String) -> void:
	var physical: Dictionary = host.bridge.diagnostics()
	var native_tick: int = int(host.frame.tick)
	var publication: int = host.publication_sequence
	var pending: Dictionary = host.pending.duplicate(true)
	for frame_index: int in range(3):
		host.poll(false)
		host.pump_receipts(4000)
		await process_frame
	var after: Dictionary = host.bridge.diagnostics()
	_expect(after.physics_steps == physical.physics_steps and after.bodies == physical.bodies and host.frame.tick == native_tick and host.publication_sequence == publication and host.pending == pending,
		label + " actual withheld receipt freezes native publication and every body transform", {"before_steps": physical.physics_steps, "after_steps": after.physics_steps})

func _run() -> void:
	_expect(host.open({"scenario": 0, "seed": 12, "width": 192, "height": 128}, 77001).get("ok", false), "one real native worker opens")
	_expect(await _idle(), "startup reaches real installed terrain")
	if host.failed:
		await _finish()
		return
	var edits: Array[Dictionary] = []
	for y: int in range(8):
		for x: int in range(4):
			edits.append({"position": Vector2i(60 + x, 30 + y), "material": 7})
	_expect(host.author_batch(edits).get("ok", false) and await _idle(), "32 real Wood cells authored")
	view.present(host.publication, [])
	var old_publication: Dictionary = host.publication
	var old_sequence: int = host.publication_sequence
	host.defer_prepared_promotion = true
	for attempt: int in range(8):
		host.request_tick()
		var until: int = Time.get_ticks_msec() + 10000
		while Time.get_ticks_msec() < until and host.state != "PreparedForReview" and not host.failed:
			host.poll()
			if host.state == "Idle" and not host._tick_requested:
				break
			await process_frame
		if host.state == "PreparedForReview" or host.failed:
			break
	_expect(host.state == "PreparedForReview" and _counts(host.frame) == {"world": 32, "owned": 0, "total": 32}, "prepared native component remains World-owned", {"state": host.state, "counts": _counts(host.frame)})
	if host.state != "PreparedForReview":
		await _finish()
		return
	host.set_receipt_hold(true)
	_expect(host.resume_prepared().get("ok", false), "real physics reservation is submitted")
	var id: int = int(host.frame.promotion.id)
	var rid: RID = host.bridge.bodies[id].rid
	_expect(not host.bridge.bodies[id].active and PhysicsServer2D.body_get_mode(rid) == PhysicsServer2D.BODY_MODE_STATIC and PhysicsServer2D.body_get_collision_layer(rid) == 0,
		"reserved RID is real, disabled and static before native custody changes")
	await _stable_wait("reservation")
	var receipt: Dictionary = await _take()
	_expect(receipt.get("result", {}).get("phase") == "CommittedInactive" and _counts(receipt.frame) == {"world": 0, "owned": 32, "total": 32},
		"actual reservation acknowledgement transfers exactly once into inactive native custody", {"phase": receipt.get("result", {}).get("phase"), "counts": _counts(receipt.frame)})
	_expect(host.accept_receipt(receipt).get("ok", false) and host.pending.get("purpose") == "terrain", "native commit installs terrain before submitting terrain acknowledgement")
	_expect(not host.bridge.bodies[id].active and PhysicsServer2D.body_get_collision_layer(rid) == 0 and host.publication_sequence == old_sequence,
		"postcommit terrain cannot activate or expose a partially switched body")
	await _stable_wait("terrain")
	receipt = await _take()
	_expect(receipt.get("result", {}).get("phase") == "ReadyToActivate", "native occupancy mask barrier really completes")
	_expect(host.accept_receipt(receipt).get("ok", false) and host.pending.get("purpose") == "activated", "main activates only after native mask acceptance")
	_expect(host.bridge.bodies[id].active and PhysicsServer2D.body_get_mode(rid) == PhysicsServer2D.BODY_MODE_RIGID and PhysicsServer2D.body_get_collision_layer(rid) == 1,
		"the accepted activation changes the actual Rapier body")
	await _stable_wait("activation")
	receipt = await _take()
	_expect(receipt.get("result", {}).get("phase") == "Active", "native body activation acknowledgement is real")
	_expect(host.accept_receipt(receipt).get("ok", false) and host.pending.get("purpose") == "motion", "first physical segment begins only after full native custody barrier")
	var first_steps: int = host.bridge.steps
	var segments: int = 0
	while host.pending.get("purpose") == "motion" and not host.failed:
		await _stable_wait("motion segment " + str(segments))
		_expect(host.publication == old_publication and view.frame == old_publication, "displayed material remains the previous coherent publication during unaccepted movement")
		receipt = await _take()
		var actual: Dictionary = receipt.duplicate(true)
		_expect(actual.get("result", {}).get("applied", false) and actual.result.semantic_tick == host.frame.tick,
			"worker genuinely applied the sampled segment without another chemistry tick")
		_expect(host.accept_receipt(receipt).get("ok", false), "real applied segment receipt accepted")
		var steps: int = host.bridge.steps
		var duplicate: Dictionary = host.accept_receipt(actual)
		_expect(not duplicate.get("ok", false) and duplicate.outcome == "ExpiredOrDuplicate" and host.bridge.steps == steps,
			"duplicate actual receipt cannot grant a second physical step")
		segments += 1
	_expect(host.state == "Idle" and not host.failed and segments == 4 and host.bridge.steps == first_steps + 3,
		"promotion completes one four-segment physical interval", {"segments": segments, "steps": host.bridge.steps, "state": host.state})
	_expect(_counts(host.publication) == {"world": 0, "owned": 32, "total": 32} and host.publication.tick == host.frame.tick,
		"only the complete accepted material/pose pair is published")
	view.present(host.publication, [])
	var visible_shard: Dictionary = host.publication.shards[0]
	var shown: Transform2D = view.material_pose(visible_shard)
	var backend: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	_expect(shown.is_equal_approx(backend) and visible_shard.applied_physics_revision == visible_shard.geometry_revision,
		"native, view and real Rapier transform agree at publication")
	host.set_receipt_hold(false)
	host.defer_prepared_promotion = false
	await _moving_target_and_com(id, rid)
	await _finish()

func _hit(source: Dictionary) -> Dictionary:
	for y: int in range(20, 70):
		for x: int in range(40, 90):
			var target: Dictionary = host.capture_target(Vector2i(x, y), source)
			if int(target.get("owner", 0)) > 0:
				return target
	return {}

func _moving_target_and_com(id: int, rid: RID) -> void:
	PhysicsServer2D.body_set_param(rid, PhysicsServer2D.BODY_PARAM_GRAVITY_SCALE, 0.0)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(7.0, -1.0))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.7)
	var displayed: Dictionary = view.frame
	var old_target: Dictionary = _hit(displayed)
	_expect(not old_target.is_empty() and await _tick(), "real motion advances after the displayed target was captured")
	var captured_from_old_view: Dictionary = host.capture_target(old_target.position, view.frame)
	_expect(captured_from_old_view.pose_serial == old_target.pose_serial and host.publication.shards[0].pose_serial != old_target.pose_serial,
		"pointer witness retains displayed serial even when host has a newer unseen publication")
	_expect(host.queue_action("edit", {"position": old_target.position, "material": 0, "target": captured_from_old_view}).get("ok", false) and await _idle(),
		"stale displayed target reaches a terminal decision")
	_expect(host.last_action.get("outcome") == "TargetChanged" and _counts(host.frame).owned == 32,
		"old displayed pointer cannot retarget moving material")
	view.present(host.publication, [])
	var exact: Dictionary = _hit(view.frame)
	var old_pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var old_velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var old_angular: float = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	var old_com: Vector2 = PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
	var old_point_relative: Vector2 = old_pose.basis_xform(-old_com)
	var old_point_velocity: Vector2 = old_velocity + Vector2(-old_point_relative.y, old_point_relative.x) * old_angular
	_expect(host.queue_action("edit", {"position": exact.position, "material": 0, "target": exact}).get("ok", false) and await _idle(),
		"fresh exact moving corner erasure runs through real native geometry change")
	var new_pose: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	var new_velocity: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var new_angular: float = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	var new_com: Vector2 = PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
	var new_point_relative: Vector2 = new_pose.basis_xform(-new_com)
	var new_point_velocity: Vector2 = new_velocity + Vector2(-new_point_relative.y, new_point_relative.x) * new_angular
	var native: Dictionary = host.publication.shards[0]
	_expect(host.last_action.get("ok", false) and old_com != new_com and _counts(host.frame).owned == 31,
		"the experiment really changed native mass distribution", {"old_com": old_com, "new_com": new_com})
	_expect(new_pose.origin == old_pose.origin and new_pose.x.distance_to(old_pose.x) < 0.000001 and new_angular == old_angular and new_point_velocity.distance_to(old_point_velocity) < 0.0001,
		"COM update preserves lattice origin and point velocity under real rotation", {"velocity_error": new_point_velocity.distance_to(old_point_velocity), "old_pose": old_pose, "new_pose": new_pose, "old_angular": old_angular, "new_angular": new_angular, "origin_delta": new_pose.origin.distance_to(old_pose.origin), "basis_delta": new_pose.x.distance_to(old_pose.x)})
	_expect(is_equal_approx(float(PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_MASS)), native.mass) and is_equal_approx(float(PhysicsServer2D.body_get_param(rid, PhysicsServer2D.BODY_PARAM_INERTIA)), native.inertia) and new_com.is_equal_approx(Vector2(native.com_x, native.com_y)),
		"actual backend mass COM and inertia match the revised native publication")
	_expect(native.applied_physics_revision == native.geometry_revision and not native.geometry_pending and not PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING),
		"destructive geometry is acknowledged and uses the intended wake contract")
	view.present(host.publication, [])
	_expect(view.material_pose(native).is_equal_approx(new_pose), "changed material remains anchored to its accepted pose")
	var native_tick: int = int(host.frame.tick)
	var physics_steps: int = host.bridge.steps
	for count: int in range(12):
		host.pump_receipts(4000)
		host.poll()
		await process_frame
	_expect(host.frame.tick == native_tick and host.bridge.steps == physics_steps,
		"unrequested polling and receipt pumping create no native or physical time")

func _finish() -> void:
	var diagnostics: Dictionary = host.diagnostics()
	host.close()
	var until: int = Time.get_ticks_msec() + 10000
	while host.state != "Closed" and Time.get_ticks_msec() < until:
		host.poll()
		await process_frame
	_expect(host.state == "Closed" and host.bridge.bodies.is_empty(), "actual worker disposal precedes RID release")
	view.free()
	var result: Dictionary = {"schema": "review-physics-adversary-v1", "checks": checks, "failures": failures,
		"engine": Engine.get_version_info(), "scope": "isolated reused native514 runtime iteration evidence only", "observations": observations, "diagnostics": diagnostics}
	var file := FileAccess.open("res://../review-physics-adversary-result.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  ") + "\n")
		file.close()
	print(JSON.stringify({"schema": result.schema, "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
