extends SceneTree

# COUPLING-LOCKSTEP-001 (native/tests/fixtures/coupling_lockstep_001.json).
# Usage: --script res://tests/test_coupling_lockstep.gd -- <output-dir|-> <async|lockstep> <workers> <ticks>
# Geometry is test_physics_async.gd seed 0 with three 8x14 bodies. Every Rapier
# step records lossless body bits plus the exact consumed native publication.
# Without arguments it runs a short lockstep self-check and exits 0 on success.

const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Recorder = preload("res://tests/coupling_lockstep_worker.gd")
const MAIN_HOLD_LIMIT_MSEC: int = 5000

func _init() -> void:
	call_deferred("_run")

static func bits(values: Array) -> String:
	var bytes := PackedByteArray()
	bytes.resize(values.size() * 8)
	for index: int in values.size():
		bytes.encode_double(index * 8, float(values[index]))
	return bytes.hex_encode()

static func body_bits(rids: Array[RID]) -> String:
	var values: Array = []
	for rid: RID in rids:
		var t: Transform2D = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		var v: Vector2 = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var w: float = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
		values.append_array([t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y, v.x, v.y, w])
	return bits(values)

func _fail(message: String) -> void:
	push_error("COUPLING_LOCKSTEP " + message)
	quit(1)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var self_check: bool = args.is_empty()
	var output: String = "-" if self_check else args[0]
	var mode: String = "lockstep" if args.size() < 2 else args[1]
	var workers: int = 1 if args.size() < 3 else int(args[2])
	var ticks: int = 90 if args.size() < 4 else int(args[3])
	if mode not in ["async", "lockstep"] or workers < 1 or workers > 8 or ticks < 2 or ticks > CyberPhysicsCharacterisation.MAX_TICKS:
		_fail("usage: <output|-> <async|lockstep> <workers 1..8> <ticks 2..7200>")
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.diagnostic_reset({"workers": workers}):
		_fail("native construction failed")
		return
	var left: int = 96
	var surface: int = 192
	var floor_y: int = surface + 384
	CyberPhysicsCharacterisation.fill(world, left - 1, 0, 1, floor_y + 1, 1)
	CyberPhysicsCharacterisation.fill(world, left + 96, 0, 1, floor_y + 1, 1)
	CyberPhysicsCharacterisation.fill(world, left - 1, floor_y, 98, 1, 1)
	CyberPhysicsCharacterisation.fill(world, left, surface, 96, 384, 2)
	world.set_simulation_window(Vector2i(left - 4, 0), Vector2i(104, floor_y + 4), 0, 0)
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(128, 128)
	root.add_child(viewport)
	var starts: Array[Vector2] = [Vector2(left + 42, surface - 9), Vector2(left + 52, surface - 9), Vector2(left + 47, surface - 40)]
	var bodies: Array[RigidBody2D] = []
	var sizes := PackedVector2Array()
	for start: Vector2 in starts:
		var body: RigidBody2D = RigidBody2D.new()
		body.mass = 1.0
		body.gravity_scale = 0.094
		body.linear_damp = 0.15
		body.angular_damp = 0.35
		body.position = start
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(8, 14)
		collision.shape = shape
		body.add_child(collision)
		viewport.add_child(body)
		bodies.append(body)
		sizes.append(Vector2(8, 14))
	await process_frame
	var bridge: CyberRapierPhysicsBridge = CyberRapierPhysicsBridge.new()
	if bridge.initialize(viewport.world_2d.space, bodies, sizes) != OK:
		_fail("Rapier construction failed")
		return
	for index: int in starts.size():
		bridge.reset_body(index, starts[index], 0.0)
	bridge.enable_diagnostics()
	bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
	var rids: Array[RID] = []
	for body: RigidBody2D in bodies:
		rids.append(body.get_rid())
	var worker = Recorder.new()
	worker._world = world
	if not worker.prepare_trace(ticks):
		_fail("trace capacity rejected")
		return
	if mode == "lockstep" and not worker.set_lockstep_coupling(true):
		_fail("lockstep coupling refused before start")
		return
	worker.set_frame_state(0, false, false, Vector2i(left + 48, surface), Vector2i(left - 4, 0), Vector2i(104, floor_y + 4), 0, 0, true, true, true)
	worker.set_rigid_body_states(bridge.pack_body_states())
	var published: int = worker.rigid_body_publication()
	var initial_bits: String = body_bits(rids)
	var start_usec: int = Time.get_ticks_usec()
	if worker.start_worker(Vector2(left + 16, surface - 14)) != OK:
		_fail("worker start failed")
		return
	if self_check and worker.set_lockstep_coupling(false):
		worker.stop_worker()
		_fail("lockstep reconfiguration was accepted after start")
		return
	var steps: Array = []
	var ages: Array = []
	ages.resize(10)
	ages.fill(0)
	var physics_frames: int = 0
	var held_frames: int = 0
	var hold_started_msec: int = -1
	var last_applied_serial: int = -1
	var deadline: int = Time.get_ticks_msec() + maxi(Watchdogs.milliseconds("operation_seconds"), ticks * 60)
	var snapshot: CyberSimulationSnapshot
	while true:
		await physics_frame
		physics_frames += 1
		snapshot = worker.take_latest_snapshot(-1)
		if snapshot == null or snapshot.simulation_failed or Time.get_ticks_msec() > deadline:
			worker.stop_worker()
			bridge.shutdown()
			_fail("native failure or fixture deadline in " + mode)
			return
		if mode == "lockstep" and (snapshot.consumed_rigid_body_publication != published or snapshot.serial == last_applied_serial):
			# Bounded non-blocking main hold: skip this physics frame.
			held_frames += 1
			if hold_started_msec < 0:
				hold_started_msec = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - hold_started_msec > MAIN_HOLD_LIMIT_MSEC:
				worker.stop_worker()
				bridge.shutdown()
				_fail("main hold exceeded %d ms" % MAIN_HOLD_LIMIT_MSEC)
				return
			continue
		hold_started_msec = -1
		var pre_bits: String = body_bits(rids)
		bridge.apply_cellular_results(snapshot.serial, snapshot.rigid_body_results)
		var d: PackedFloat64Array = bridge.diagnostic_applications
		if d[5] > 0:
			ages[clampi(int(d[0]), 0, 9)] += 1
		last_applied_serial = snapshot.serial
		if snapshot.tick_index >= ticks:
			break
		bridge.step()
		steps.append({"tick": snapshot.tick_index, "serial": snapshot.serial,
			"publication": snapshot.consumed_rigid_body_publication,
			"states": snapshot.current_rigid_body_states.to_byte_array().hex_encode(),
			"results": snapshot.rigid_body_results.to_byte_array().hex_encode(),
			"pre": pre_bits, "post": body_bits(rids),
			"character": bits([snapshot.character_position.x, snapshot.character_position.y,
				snapshot.character_velocity.x, snapshot.character_velocity.y])})
		worker.set_rigid_body_states(bridge.pack_body_states())
		published = worker.rigid_body_publication()
		worker.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
	var wall_usec: int = Time.get_ticks_usec() - start_usec
	worker.stop_worker()
	var final: Dictionary = world.diagnostic_snapshot(Vector2i(left - 1, surface - 128), Vector2i(98, 513), true)
	final.erase("cells")
	var report: Dictionary = {"registration": "COUPLING-LOCKSTEP-001", "ok": true, "mode": mode,
		"workers": workers, "ticks": ticks, "completed_ticks": final.get("completed_ticks", -1),
		"rapier_steps": bridge.manual_step_count(), "physics_frames": physics_frames,
		"held_frames": held_frames, "wall_usec": wall_usec, "age_histogram": ages,
		"worker_overruns": snapshot.worker_overruns, "lockstep": worker.lockstep_metrics(),
		"native_worker_threads": int(world.get_worker_threads()) if world.has_method(&"get_worker_threads") else -1,
		"initial_bits": initial_bits, "final_bits": body_bits(rids),
		"state_hash": str(final.get("state_hash", "")), "content_hash": str(final.get("content_hash", "")),
		"tick_hashes": Array(worker.tick_hashes), "steps": steps, "platform": OS.get_name(),
		"engine": Engine.get_version_info().get("string", "")}
	bridge.shutdown()
	viewport.queue_free()
	if self_check:
		var metrics: Dictionary = report.lockstep
		var ok: bool = (int(metrics.ticks) == ticks and int(metrics.timeouts) == 0
			and steps.size() == ticks - 1 and int(ages[0]) == steps.size() + 1)
		for index: int in steps.size():
			ok = ok and int(steps[index].publication) == index + 1 and int(steps[index].tick) == index + 1
		if not ok:
			_fail("lockstep self-check failed: " + JSON.stringify(metrics) + " ages " + str(ages))
			return
		print("COUPLING_LOCKSTEP self-check ok steps=%d" % steps.size())
		quit(0)
		return
	if output != "-":
		var file: FileAccess = FileAccess.open(output.path_join("%s-w%d.json" % [mode, workers]), FileAccess.WRITE)
		if file == null:
			_fail("output file unavailable")
			return
		file.store_string(JSON.stringify(report))
		file.close()
	report.erase("steps")
	report.erase("tick_hashes")
	print("COUPLING_LOCKSTEP ", JSON.stringify(report))
	await process_frame
	quit(0)
