extends SceneTree

# Real exclusive-owner reset/publication checks. R8 fallback sends full images
# on ordinary paints, while native transport can request a full resync of the
# same World. Neither operation is a World replacement.
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
var failures: int = 0
var assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	assertions += 1
	if value:
		return
	failures += 1
	push_error(message)


func _wait_for(worker: CyberSimulationWorker, after: int, predicate: Callable) -> CyberSimulationSnapshot:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(after)
		if snapshot != null and predicate.call(snapshot):
			return snapshot
		await process_frame
	return null


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native owner unavailable")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		await _check_owner(false)
	await _check_owner(true)
	print("RENDER_WORLD_GENERATION: %d assertions, %d failures" % [assertions, failures])
	quit(failures)


func _check_owner(fallback: bool) -> void:
	var worker := CyberSimulationWorker.new()
	if fallback:
		# Select the real compatibility implementation before ownership starts.
		worker._world = CyberCellWorld.new()
	worker.set_frame_state(0.0, false, true, Vector2i(160, 90),
		Vector2i.ZERO, Vector2i(320, 180), 0, 0, false, false, true)
	var backend: String = "R8 fallback" if fallback else "native RG8"
	_expect(worker.start_worker(Vector2(150, 145)) == OK, backend + " worker did not start")
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(-1)
	_expect(initial != null and initial.render_world_generation > 0,
		backend + " first render has no World generation")
	if initial == null:
		worker.stop_worker()
		return
	worker.acknowledge_render_snapshot(initial.render_snapshot_serial)
	worker.queue_emit_disc(500, 300, 0, CyberCellWorld.STEAM)
	var painted: CyberSimulationSnapshot = await _wait_for(worker, initial.serial,
		func(s: CyberSimulationSnapshot) -> bool:
			return s.render_snapshot_serial > initial.render_snapshot_serial and s.world_revision != initial.world_revision)
	_expect(painted != null, backend + " paint was not published")
	if painted == null:
		worker.stop_worker()
		return
	_expect(painted.render_world_generation == initial.render_world_generation,
		backend + " ordinary paint changed the World generation")
	if fallback:
		_expect(painted.render_channels == 1 and painted.render_full_refresh,
			"fallback control did not exercise an ordinary full R8 publication")
	worker.acknowledge_render_snapshot(painted.render_snapshot_serial)
	worker.request_render_full_refresh()
	var refreshed: CyberSimulationSnapshot = await _wait_for(worker, painted.serial,
		func(s: CyberSimulationSnapshot) -> bool:
			return s.render_snapshot_serial > painted.render_snapshot_serial and s.render_full_refresh)
	_expect(refreshed != null, backend + " transport full refresh was not published")
	if refreshed == null:
		worker.stop_worker()
		return
	_expect(refreshed.render_world_generation == painted.render_world_generation,
		backend + " transport resync masqueraded as a World reset")
	worker.acknowledge_render_snapshot(refreshed.render_snapshot_serial)
	worker.queue_reset(Vector2(150, 145))
	var reset: CyberSimulationSnapshot = await _wait_for(worker, refreshed.serial,
		func(s: CyberSimulationSnapshot) -> bool:
			return s.render_world_generation > refreshed.render_world_generation)
	_expect(reset != null, backend + " accepted reset did not publish a new World generation")
	if reset == null:
		worker.stop_worker()
		return
	_expect(reset.render_world_generation == refreshed.render_world_generation + 1 and
		reset.render_snapshot_serial > refreshed.render_snapshot_serial and reset.render_full_refresh,
		backend + " reset identity is not bound to its replacement render payload")
	_expect(initial.render_world_generation == painted.render_world_generation and
		initial.render_world_generation == refreshed.render_world_generation,
		backend + " retained snapshots were mutated by reset")
	worker.acknowledge_render_snapshot(reset.render_snapshot_serial)
	if not fallback:
		worker.queue_lab({"scenario_reset": {}, "scenario_request_serial": 1, "scenario_mode": "Inspect"})
		var rejected: CyberSimulationSnapshot = await _wait_for(worker, reset.serial,
			func(s: CyberSimulationSnapshot) -> bool:
				return int(s.lab_context.get("scenario_request_serial", 0)) == 1)
		_expect(rejected != null and not rejected.lab_context.get("scenario_request_applied", true) and
			rejected.render_world_generation == reset.render_world_generation,
			"rejected scenario replacement invalidated valid presentation history")
		var generation: int = reset.render_world_generation
		var definition: Dictionary = Catalogue.sand_release()
		for request: int in [2, 3]:
			# Apply the identical map twice, paused at tick zero. Tick indices,
			# material revisions and definition hashes cannot identify a reset.
			worker.queue_lab({"scenario_reset": definition, "scenario_request_serial": request,
				"scenario_mode": "Inspect"})
			var installed: CyberSimulationSnapshot = await _wait_for(worker, reset.serial,
				func(s: CyberSimulationSnapshot) -> bool:
					return (int(s.lab_context.get("scenario_request_serial", 0)) == request and
						bool(s.lab_context.get("scenario_request_applied", false)) and s.render_world_generation > generation))
			_expect(installed != null and installed.render_world_generation == generation + 1 and
				installed.render_full_refresh, "identical paused scenario reset did not advance its render-bound identity")
			if installed == null:
				break
			generation = installed.render_world_generation
			worker.acknowledge_render_snapshot(installed.render_snapshot_serial)
	worker.stop_worker()
