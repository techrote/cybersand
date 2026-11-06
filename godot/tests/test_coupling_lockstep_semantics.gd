extends SceneTree

# COUPLING-LOCKSTEP-001 review repair: snapshot.consumed_rigid_body_publication
# names the body publication consumed by the last successfully completed native
# tick. Paused, reset-only and failed turns must not advance it, and several
# publications before one fenced tick are consumed newest-first and counted.
# Failure is exercised at the owner bookkeeping boundary because the native
# World exposes no tick-failure injection; pause, reset and duplicate
# publications run on a live default-off-then-enabled worker thread.

const DEADLINE_MSEC: int = 10000
const SETTLE_FRAMES: int = 12

var _failures: PackedStringArray = PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)

func _world() -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.diagnostic_reset({"workers": 1}):
		return null
	CyberPhysicsCharacterisation.fill(world, 95, 0, 1, 129, 1)
	CyberPhysicsCharacterisation.fill(world, 192, 0, 1, 129, 1)
	CyberPhysicsCharacterisation.fill(world, 95, 128, 98, 1, 1)
	CyberPhysicsCharacterisation.fill(world, 96, 96, 96, 32, 2)
	world.set_simulation_window(Vector2i(92, 0), Vector2i(104, 132), 0, 0)
	return world

func _frame_state(worker: CyberSimulationWorker, paused: bool) -> void:
	worker.set_frame_state(0, false, paused, Vector2i(144, 96), Vector2i(92, 0), Vector2i(104, 132), 0, 0, true, true, true)

func _latest(worker: CyberSimulationWorker, previous: CyberSimulationSnapshot) -> CyberSimulationSnapshot:
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	return previous if snapshot == null else snapshot

func _await_consumed(worker: CyberSimulationWorker, publication: int) -> CyberSimulationSnapshot:
	var deadline: int = Time.get_ticks_msec() + DEADLINE_MSEC
	var snapshot: CyberSimulationSnapshot = null
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		snapshot = _latest(worker, snapshot)
		if snapshot != null and snapshot.consumed_rigid_body_publication == publication:
			return snapshot
	return null

func _settle(worker: CyberSimulationWorker, snapshot: CyberSimulationSnapshot) -> CyberSimulationSnapshot:
	for _frame: int in SETTLE_FRAMES:
		await physics_frame
		snapshot = _latest(worker, snapshot)
	return snapshot

func _bookkeeping() -> void:
	# Failure and duplicate publications at the exclusive-owner boundary.
	var worker := CyberSimulationWorker.new()
	_check(not worker._lockstep_record_tick(1, false), "failed tick reported as fenced")
	_check(worker._lockstep_completed_publication == -1, "failed tick advanced the completed publication")
	_check(worker.set_lockstep_coupling(true), "fence refused before start")
	_check(worker._lockstep_record_tick(1, true), "successful fenced tick not reported")
	_check(worker._lockstep_completed_publication == 1, "successful tick did not record its publication")
	_check(not worker._lockstep_record_tick(2, false), "failed fenced tick reported as fenced")
	_check(worker._lockstep_completed_publication == 1, "failed fenced tick advanced the completed publication")
	_check(worker._lockstep_record_tick(4, true), "fenced tick after duplicates not reported")
	var metrics: Dictionary = worker.lockstep_metrics()
	_check(int(metrics.ticks) == 2 and int(metrics.superseded_publications) == 2 and int(metrics.completed_publication) == 4,
		"duplicate publication accounting " + JSON.stringify(metrics))

func _live() -> void:
	var world: Object = _world()
	if world == null:
		_check(false, "native construction failed")
		return
	var worker := CyberSimulationWorker.new()
	worker._world = world
	_check(worker.set_lockstep_coupling(true), "fence refused before start")
	_frame_state(worker, false)
	worker.set_rigid_body_states(PackedFloat32Array())
	if worker.start_worker(Vector2(112, 80)) != OK:
		_check(false, "worker start failed")
		return
	var snapshot: CyberSimulationSnapshot = await _await_consumed(worker, 1)
	_check(snapshot != null, "first fenced tick never consumed publication 1")
	if snapshot == null:
		worker.stop_worker()
		return
	snapshot = await _settle(worker, snapshot)
	var tick: int = snapshot.tick_index
	_check(snapshot.consumed_rigid_body_publication == 1 and int(worker.lockstep_metrics().ticks) == tick,
		"fence advanced without a new publication (tick %d)" % tick)

	# Paused turns latch newer publications but complete no tick.
	_frame_state(worker, true)
	worker.set_rigid_body_states(PackedFloat32Array())
	worker.set_rigid_body_states(PackedFloat32Array())
	snapshot = await _settle(worker, snapshot)
	_check(snapshot.tick_index == tick, "paused worker ticked")
	_check(snapshot.consumed_rigid_body_publication == 1,
		"paused snapshot claimed publication %d" % snapshot.consumed_rigid_body_publication)

	# Unpausing completes one tick on the newest publication; 2 is superseded.
	_frame_state(worker, false)
	snapshot = await _await_consumed(worker, 3)
	_check(snapshot != null, "unpaused fenced tick never consumed publication 3")
	if snapshot != null:
		snapshot = await _settle(worker, snapshot)
		_check(snapshot.tick_index == tick + 1, "fence ran %d ticks for one publication" % (snapshot.tick_index - tick))
		_check(int(worker.lockstep_metrics().superseded_publications) == 1, "superseded publication not counted")

	# A paused reset-only turn reports no newly consumed publication.
	_frame_state(worker, true)
	worker.set_rigid_body_states(PackedFloat32Array())
	worker.queue_reset(Vector2(112, 80), false, false)
	var generation: int = snapshot.render_world_generation
	var reset_seen: bool = false
	var deadline: int = Time.get_ticks_msec() + DEADLINE_MSEC
	while Time.get_ticks_msec() < deadline and not reset_seen:
		await physics_frame
		snapshot = _latest(worker, snapshot)
		reset_seen = snapshot.render_world_generation > generation
		_check(snapshot.consumed_rigid_body_publication == 3,
			"paused reset snapshot claimed publication %d" % snapshot.consumed_rigid_body_publication)
	_check(reset_seen, "paused reset was not observed")
	_frame_state(worker, false)
	snapshot = await _await_consumed(worker, 4)
	_check(snapshot != null, "post-reset fenced tick never consumed publication 4")
	worker.stop_worker()

func _run() -> void:
	_bookkeeping()
	await _live()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error("COUPLING_LOCKSTEP_SEMANTICS " + failure)
		quit(1)
		return
	print("COUPLING_LOCKSTEP_SEMANTICS ok")
	quit(0)
