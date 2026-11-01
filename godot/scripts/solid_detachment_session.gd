extends RefCounted

# Explicit dry/inert conformance session. One ordinary asynchronous native owner
# and the existing main-thread Rapier bridge; no alternate physics integrator.
const Worker = preload("res://scripts/solid_detachment_worker.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const DOMAIN := Rect2i(32, 16, 64, 64)
const ANCHORS := Rect2i(0, 67, 128, 13)
const CUT := Rect2i(50, 65, 4, 2)
const SEED := Vector2i(51, 34)
const WALL: int = 1
const BRICK: int = 43
const SAND: int = 2
const WATER: int = 3
const COUPLING_SAMPLE_LIMIT: int = 1000000
const COUPLING_IMPULSE_CAP: float = 3.0
const COUPLING_CORRECTION_CAP: float = 0.5

var worker: CyberSimulationWorker
var bridge: CyberRapierPhysicsBridge
var viewport: SubViewport
var body: RigidBody2D
var source_payload: PackedInt32Array = PackedInt32Array()
var source_rectangles: PackedInt32Array = PackedInt32Array()
var source_center := Vector2.ZERO
var source_receipt: Dictionary = {}
var commit_receipt: Dictionary = {}
var final_receipt: Dictionary = {}
var status: String = "closed"
var last_error: String = ""
var active: bool = false
var physics_paused: bool = true
var transaction_busy: bool = false
var generation: int = 0
var request_serial: int = 0
var physics_epoch: int = 0
var surroundings_kind: String = "empty"
var _terrain_revision: int = -1
var _terrain_refreshes: int = 0
var _terrain_refresh_usec: int = 0
var _last_worker_step_ms: float = 0.0
var _last_native_tick_ms: float = 0.0
var _timed_snapshots: int = 0
var _observed_worker_ms: float = 0.0
var _observed_worker_max_ms: float = 0.0
var _observed_native_ms: float = 0.0
var _observed_native_max_ms: float = 0.0
var _main_sync_usec: int = 0
var _main_sync_max_usec: int = 0
var _main_sync_segments: int = 0
var _rapier_step_usec: int = 0
var _rapier_step_max_usec: int = 0
var _timed_rapier_steps: int = 0
var _tree: SceneTree
var _parent: Node
var _shapes: Array[CollisionShape2D] = []
var _opening: bool = false
var _release_in_progress: bool = false
var _failed: bool = false
var _coupling_local_centers: PackedVector2Array = PackedVector2Array()
var _coupling_sizes: PackedVector2Array = PackedVector2Array()
var _coupling_masses: PackedFloat32Array = PackedFloat32Array()
var _coupling_total_mass: float = 0.0
var _coupling_sample_serial: int = 0
var _coupling_snapshot_serial: int = -1
var _coupling_last_applied_sample: int = -1
var _coupling_last_native_tick: int = 0
var _coupling_state_publications: int = 0
var _coupling_result_snapshots: int = 0
var _coupling_result_records: int = 0
var _coupling_contacts: int = 0
var _coupling_displaced: int = 0
var _coupling_unresolved: int = 0
var _coupling_impulse_applications: int = 0
var _coupling_correction_applications: int = 0
var _coupling_stale_results: int = 0
var _coupling_last_impulse: Vector2 = Vector2.ZERO
var _coupling_last_correction: Vector2 = Vector2.ZERO

func open(parent: Node, workers: int = 4, surroundings: String = "empty",
		conservative_displacement: bool = true) -> bool:
	close()
	_parent = parent
	_tree = parent.get_tree()
	generation += 1
	_opening = true
	last_error = ""
	worker = _create_worker()
	surroundings_kind = surroundings
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	# Before start_worker(), this thread is the exclusive native owner.
	var native: Object = worker._world
	if not native.has_method(&"solid_detachment_command") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		return _fail("Source-matched native detachment and Rapier runtime required; no fallback")
	if not native.diagnostic_reset({"workers":workers,"telemetry":false,
		"conservative_displacement":conservative_displacement}):
		return _fail("Native diagnostic setup refused")
	native.set_simulation_window_enabled(false)
	for item: Array in [[0,72,128,4,WALL], [50,40,4,32,BRICK], [44,27,29,13,BRICK],
		[54,40,11,4,BRICK], [8,45,3,27,BRICK], [60,32,1,1,0]]:
		if not native.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4]):
			return _fail("Native fixture authoring refused")
	if not _author_surroundings(native, surroundings):
		return _fail("Unknown or refused surroundings fixture: " + surroundings)
	# Apply initial region request before frozen source observation.
	if not native.simulation_tick():
		return _fail("Initial native inclusion tick failed")
	set_paused(true)
	if worker.start_worker(Vector2(400, 400)) != OK:
		return _fail("Existing asynchronous worker failed to start")
	var configured: Dictionary = await command({"action":"configure","members":1024,"shapes":128})
	if not _owns(owner_generation, owner_worker):
		return false
	_opening = false
	if not configured.get("ok",false):
		return _fail("Native feature admission refused: " + str(configured))
	status = "anchored native terrain"
	return true

func _create_worker() -> CyberSimulationWorker:
	return Worker.new()


func _author_surroundings(native: Object, kind: String) -> bool:
	# Fixture creation occurs before start_worker(), while this thread exclusively
	# owns native. Existing solid payload is never overwritten by the bank.
	if kind == "empty":
		return true
	if kind not in ["packed_sand", "embedded_sand", "mixed"]:
		return false
	for x: int in [30, 119]:
		if not native.diagnostic_fill_rect(Vector2i(x, 34), Vector2i(1, 38), WALL):
			return false
	var top: int = 48 if kind == "embedded_sand" else 58
	for y: int in range(top, 72):
		for x: int in range(31, 119):
			if int(native.material_at(x, y)) != 0:
				continue
			var material: int = WATER if kind == "mixed" and x >= 82 else SAND
			if not native.diagnostic_fill_rect(Vector2i(x, y), Vector2i.ONE, material):
				return false
	return true

func set_paused(paused: bool) -> void:
	physics_paused = paused or _failed
	if worker != null:
		worker.set_frame_state(0.0,false,physics_paused,Vector2i(64,64),Vector2i.ZERO,Vector2i(160,128),
			0,0,false,true,true)

func command(input: Dictionary) -> Dictionary:
	if worker == null or transaction_busy:
		return {"ok":false,"outcome":"SessionBusyOrClosed"}
	transaction_busy = true
	request_serial += 1
	var id: int = request_serial
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var owner_tree: SceneTree = _tree
	var request: Dictionary = input.duplicate(true)
	request["request_id"] = id
	owner_worker.queue_lab({"solid_detachment":request})
	var end: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while _owns(owner_generation, owner_worker) and Time.get_ticks_msec() < end:
		var reply: Dictionary = owner_worker.take_solid_reply(id)
		if not reply.is_empty():
			if request_serial == id:
				transaction_busy = false
			return reply
		await owner_tree.process_frame
		OS.delay_usec(500)
	# A retired coroutine must not release a replacement owner's command lock.
	if not _owns(owner_generation, owner_worker):
		return {"ok":false,"outcome":"SessionRetired"}
	if request_serial == id:
		transaction_busy = false
	_fail("Native command timed out; reset the session before retrying")
	return {"ok":false,"outcome":"SessionTimedOut"}

func _owns(owner_generation: int, owner_worker: CyberSimulationWorker) -> bool:
	return generation == owner_generation and worker != null and worker == owner_worker

func observe_intact() -> Dictionary:
	return await command({"action":"prepare","domain":DOMAIN,"anchors":ANCHORS,"seed":SEED})

func cut_and_release() -> bool:
	if active or transaction_busy or worker == null or _opening or _release_in_progress or _failed:
		return false
	_release_in_progress = true
	set_paused(true)
	var this_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var prepared: Dictionary = await command({"action":"cut_prepare","domain":DOMAIN,"anchors":ANCHORS,
		"seed":SEED,"cut":CUT})
	if not _owns(this_generation, owner_worker):
		return false
	if not prepared.get("ok",false):
		return _fail("Cut/extraction refused: " + str(prepared.get("outcome")))
	source_receipt = prepared.duplicate(true)
	source_payload = prepared.members.duplicate()
	source_rectangles = prepared.rectangles.duplicate()
	source_center = prepared.center
	if not _configure_compound_coupling():
		await command({"action":"cancel","token":prepared.token})
		if not _owns(this_generation, owner_worker):
			return false
		return _fail("Exact compound occupancy exceeds the bounded proxy contract")
	# Only copied native values cross this boundary. The source is still native
	# and fenced while the main thread prepares its inactive actual Rapier RIDs.
	var body_ready: bool = await _prepare_body(prepared)
	if not _owns(this_generation, owner_worker):
		return false
	if not body_ready:
		await command({"action":"cancel","token":prepared.token})
		if not _owns(this_generation, owner_worker):
			return false
		_destroy_physics()
		return _fail("Inactive Rapier geometry preparation failed")
	var acknowledged: Dictionary = await command({"action":"acknowledge","token":prepared.token,
		"body_id":1,"body_generation":this_generation,"shape_count":_shapes.size(),
		"payload_digest":prepared.payload_digest,"shape_digest":prepared.shape_digest})
	if not _owns(this_generation, owner_worker):
		return false
	if not acknowledged.get("ok",false):
		await command({"action":"cancel","token":prepared.token})
		if not _owns(this_generation, owner_worker):
			return false
		_destroy_physics()
		return _fail("Native reservation acknowledgement refused")
	# Store a reply only after proving the receiving session still owns it.
	var committed: Dictionary = await command({"action":"commit","token":prepared.token})
	if not _owns(this_generation, owner_worker):
		return false
	commit_receipt = committed
	if not committed.get("ok",false):
		await command({"action":"cancel","token":prepared.token})
		if not _owns(this_generation, owner_worker):
			return false
		_destroy_physics()
		return _fail("Native commit refused")
	if not _install_terrain(committed):
		return await _rollback_inactive("Post-commit static terrain repair refused")
	# Both clocks remain held. No physics step is permitted between retiring the
	# old static shapes and activation/finalization of the new compound body.
	for shape: CollisionShape2D in _shapes:
		shape.disabled = false
	body.collision_layer = 1
	body.collision_mask = 1
	# Keep the actual body frozen until the native compound proxy mask has been
	# published and acknowledged. No cell tick may see active Rapier contact
	# without the matching hole-preserving native occupancy representation.
	body.freeze = true
	body.sleeping = true
	physics_epoch += 1
	var finalized: Dictionary = await command({"action":"finalize","token":prepared.token,"body_id":1,
		"body_generation":this_generation,"terrain_revision":committed.commit_revision,"physics_epoch":physics_epoch})
	if not _owns(this_generation, owner_worker):
		return false
	final_receipt = finalized
	if not finalized.get("ok",false):
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		return await _rollback_inactive("Final contact receipt refused")
	bridge.refresh_all_states()
	active = true
	var primed: bool = await _prime_compound_coupling()
	if not _owns(this_generation, owner_worker):
		return false
	if not primed:
		body.freeze = true
		body.sleeping = true
		active = false
		return _fail("Compound native occupancy failed to publish; reset required")
	body.freeze = false
	body.sleeping = false
	bridge.refresh_all_states()
	_release_in_progress = false
	status = "native aggregate — live Rapier + exact compound cellular coupling"
	set_paused(false)
	return true

func _prepare_body(prepared: Dictionary) -> bool:
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var owner_tree: SceneTree = _tree
	if owner_worker == null or not is_instance_valid(_parent):
		return false
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(160,128)
	_parent.add_child(viewport)
	body = RigidBody2D.new()
	body.name = "NativeDetachedTree"
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass = float(prepared.mass)
	body.inertia = float(prepared.inertia)
	body.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector2.ZERO
	body.gravity_scale = 0.094
	body.linear_damp = 0.04
	body.angular_damp = 0.04
	body.position = source_center # Initial placement only; never animated.
	var spans: PackedInt32Array = source_rectangles
	_shapes.clear()
	for i: int in range(0,spans.size(),4):
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(spans[i+2],spans[i+3])
		collision.shape = rectangle
		collision.position = Vector2(spans[i],spans[i+1]) + rectangle.size * 0.5 - source_center
		collision.disabled = true
		body.add_child(collision)
		_shapes.append(collision)
	viewport.add_child(body)
	var prepared_body: RigidBody2D = body
	var prepared_viewport: SubViewport = viewport
	await owner_tree.process_frame
	if not _owns(owner_generation, owner_worker):
		return false
	if body != prepared_body or viewport != prepared_viewport:
		return false
	if not is_instance_valid(body) or not body.get_rid().is_valid():
		return false
	bridge = CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	if bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(29,38)])) != OK:
		return false
	if PhysicsServer2D.body_get_shape_count(body.get_rid()) != int(prepared.shape_count):
		return false
	# Install original terrain while dynamic shapes are disabled: useful also
	# for verifying that source retirement really replaces existing colliders.
	return _install_terrain(prepared)

func _install_terrain(receipt: Dictionary) -> bool:
	var started: int = Time.get_ticks_usec()
	if bridge == null or not receipt.get("terrain_chunks_valid",false) or \
		str(receipt.get("terrain_snapshot_revision","")) != str(receipt.get("terrain_revision","invalid")):
		return false
	if not bridge.queue_hard_surface_chunk_snapshot(receipt.terrain_chunks):
		return false
	var turns: int = 0
	while bridge.pending_hard_surface_chunks() > 0 and turns < 300:
		bridge.process_hard_surface_collider_budget(16,0)
		turns += 1
	if bridge.pending_hard_surface_chunks() != 0:
		return false
	_terrain_revision = int(receipt.get("terrain_revision", -1))
	_terrain_refreshes += 1
	_terrain_refresh_usec += Time.get_ticks_usec() - started
	return true

func _rollback_inactive(reason: String) -> bool:
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	if owner_worker == null or not source_receipt.has("token"):
		return false
	var token: String = str(source_receipt.token)
	var restored: Dictionary = await command({"action":"rollback","token":token})
	if not _owns(owner_generation, owner_worker):
		return false
	if restored.get("ok",false) and _install_terrain(restored):
		physics_epoch += 1
		var finished: Dictionary = await command({"action":"finish_rollback","token":token,
			"body_id":1,"body_generation":owner_generation,"terrain_revision":restored.commit_revision,"physics_epoch":physics_epoch})
		if not _owns(owner_generation, owner_worker):
			return false
		if not finished.get("ok",false):
			reason += "; native rollback completion refused"
	else:
		reason += "; rollback quarantined — reset whole session"
	_destroy_physics()
	return _fail(reason)

func _configure_compound_coupling() -> bool:
	_coupling_local_centers = PackedVector2Array()
	_coupling_sizes = PackedVector2Array()
	_coupling_masses = PackedFloat32Array()
	_coupling_total_mass = 0.0
	if source_rectangles.is_empty() or (source_rectangles.size() & 3) != 0:
		return false
	var count: int = source_rectangles.size() / 4
	if count < 1 or count > CyberRigidBodyCoupling.MAX_BODIES:
		return false
	for i: int in range(count):
		var offset: int = i * 4
		var size := Vector2(float(source_rectangles[offset + 2]), float(source_rectangles[offset + 3]))
		if size.x <= 0.0 or size.y <= 0.0:
			return false
		var center := Vector2(float(source_rectangles[offset]), float(source_rectangles[offset + 1])) + size * 0.5
		var area: float = size.x * size.y
		_coupling_local_centers.append(center - source_center)
		_coupling_sizes.append(size)
		_coupling_masses.append(area)
		_coupling_total_mass += area
	# The exact non-overlapping rectangle union must account for every payload
	# member. A mismatch is a geometry/ownership defect, not an approximation.
	return absf(_coupling_total_mass - float(source_receipt.get("member_count", 0))) < 0.01

func _pack_compound_states() -> PackedFloat32Array:
	var states := PackedFloat32Array()
	if worker == null or bridge == null or not is_instance_valid(body) or _coupling_local_centers.is_empty():
		return states
	_coupling_sample_serial = (_coupling_sample_serial + 1) % COUPLING_SAMPLE_LIMIT
	var transform: Transform2D = bridge.body_transform(0)
	var rotation: float = transform.get_rotation()
	var linear: Vector2 = bridge.body_linear_velocity(0)
	var omega: float = angular_velocity()
	for index: int in range(_coupling_local_centers.size()):
		var world_center: Vector2 = transform * _coupling_local_centers[index]
		var world_offset: Vector2 = world_center - transform.origin
		var point_velocity := linear + Vector2(-omega * world_offset.y, omega * world_offset.x)
		CyberRigidBodyCoupling.append_input(states, index + 1, world_center, rotation,
			_coupling_sizes[index], point_velocity, omega, _coupling_masses[index],
			_coupling_sample_serial)
	return states

func _publish_compound_states() -> bool:
	if worker == null or physics_epoch <= 0:
		return false
	var states: PackedFloat32Array = _pack_compound_states()
	if states.size() != _coupling_local_centers.size() * CyberRigidBodyCoupling.INPUT_STRIDE:
		return false
	var admission: Dictionary = worker.set_rigid_body_states(states, physics_epoch)
	if str(admission.get("status", "")) != "no_effects":
		return false
	_coupling_state_publications += 1
	return true

func _prime_compound_coupling() -> bool:
	if not _publish_compound_states():
		return false
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	var expected: int = _coupling_local_centers.size() * CyberRigidBodyCoupling.INPUT_STRIDE
	while _owns(owner_generation, owner_worker) and Time.get_ticks_msec() < deadline:
		var snapshot: CyberSimulationSnapshot = owner_worker.take_latest_snapshot(_coupling_snapshot_serial)
		if snapshot != null:
			_coupling_snapshot_serial = snapshot.serial
			_coupling_last_native_tick = snapshot.tick_index
			if snapshot.simulation_failed:
				return _fail("Native owner failed before compound mask activation; reset the complete session")
			if snapshot.rigid_body_epoch == physics_epoch and snapshot.current_rigid_body_states.size() == expected:
				return true
		await _tree.process_frame
		OS.delay_usec(500)
	return false

func _consume_compound_results() -> void:
	if worker == null or bridge == null or not is_instance_valid(body):
		return
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(_coupling_snapshot_serial)
	if snapshot == null:
		return
	_coupling_snapshot_serial = snapshot.serial
	_coupling_last_native_tick = snapshot.tick_index
	if snapshot.simulation_failed:
		_fail("Native owner failed; Rapier held at its last admitted pose; reset the complete session")
		return
	if snapshot.rigid_body_epoch != physics_epoch:
		return
	_last_worker_step_ms = snapshot.worker_step_time_ms
	_last_native_tick_ms = snapshot.simulation_time_ms
	_timed_snapshots += 1
	_observed_worker_ms += _last_worker_step_ms
	_observed_worker_max_ms = maxf(_observed_worker_max_ms, _last_worker_step_ms)
	_observed_native_ms += _last_native_tick_ms
	_observed_native_max_ms = maxf(_observed_native_max_ms, _last_native_tick_ms)
	if snapshot.hard_surface_chunk_rectangles_valid and snapshot.hard_surface_revision != _terrain_revision:
		if not bridge.queue_hard_surface_chunk_snapshot(snapshot.hard_surface_chunk_rectangles):
			_fail("Changed terrain collider publication refused; reset required")
			return
		_terrain_revision = snapshot.hard_surface_revision
		_terrain_refreshes += 1
	_coupling_result_snapshots += 1
	# The shared main-thread Rapier owner alone applies contact response. Native
	# already owns force/friction calculation; detachment only supplies the exact
	# geometry that maps its proxy impulse positions into the one aggregate.
	var applied: Dictionary = bridge.apply_compound_cellular_results(
		snapshot.serial, snapshot.rigid_body_results, 0, _coupling_sample_serial,
		_coupling_local_centers, _coupling_masses, COUPLING_IMPULSE_CAP, COUPLING_CORRECTION_CAP)
	_coupling_stale_results += int(applied.get("stale_records", 0))
	if not applied.get("accepted", false):
		return
	_coupling_last_applied_sample = int(applied.sample_serial)
	_coupling_contacts += int(applied.contacts)
	_coupling_displaced += int(applied.displaced)
	_coupling_unresolved += int(applied.unresolved)
	_coupling_result_records += int(applied.records)
	_coupling_impulse_applications += int(applied.impulse_applications)
	_coupling_correction_applications += int(applied.correction_applications)
	_coupling_last_impulse = applied.impulse
	_coupling_last_correction = applied.correction

func physics_step() -> void:
	if active and not physics_paused and not transaction_busy and bridge != null:
		var sync_start: int = Time.get_ticks_usec()
		_consume_compound_results()
		_record_main_sync(Time.get_ticks_usec() - sync_start)
		if physics_paused:
			return
		if bridge.pending_hard_surface_chunks() > 0:
			var started: int = Time.get_ticks_usec()
			bridge.process_hard_surface_collider_budget(16, 0)
			_terrain_refresh_usec += Time.get_ticks_usec() - started
			if bridge.pending_hard_surface_chunks() > 0:
				return
		var step_start: int = Time.get_ticks_usec()
		bridge.step()
		var step_usec: int = Time.get_ticks_usec() - step_start
		_rapier_step_usec += step_usec
		_rapier_step_max_usec = maxi(_rapier_step_max_usec, step_usec)
		_timed_rapier_steps += 1
		sync_start = Time.get_ticks_usec()
		var published: bool = _publish_compound_states()
		_record_main_sync(Time.get_ticks_usec() - sync_start)
		if not published:
			_fail("Compound native occupancy publication failed; reset required")

func _record_main_sync(usec: int) -> void:
	_main_sync_usec += usec
	_main_sync_max_usec = maxi(_main_sync_max_usec, usec)
	_main_sync_segments += 1

func emit_cells(points: PackedInt32Array, material_id: int) -> bool:
	if worker == null or transaction_busy or _opening or _release_in_progress or _failed:
		return false
	return worker.queue_emit_cells(points, material_id)

func excavate_support() -> bool:
	# An ordinary authoritative edit. The next copied hard-surface revision
	# refreshes the main-thread collider before another admitted Rapier step.
	if not active:
		return false
	var points := PackedInt32Array()
	for y: int in range(69, 76):
		for x: int in range(40, 102):
			points.append(x)
			points.append(y)
	return emit_cells(points, 0)

func wait_native_ticks(ticks: int, timeout_ms: int = 0) -> bool:
	if worker == null or ticks < 1 or active == false or _failed:
		return false
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var latest: CyberSimulationSnapshot = owner_worker.take_latest_snapshot(-1)
	var start_tick: int = latest.tick_index if latest != null else _coupling_last_native_tick
	var observed_serial: int = latest.serial if latest != null else _coupling_snapshot_serial
	var target: int = start_tick + ticks
	set_paused(false)
	var deadline: int = Time.get_ticks_msec() + maxi(timeout_ms, Watchdogs.milliseconds("operation_seconds"))
	while _owns(owner_generation, owner_worker) and Time.get_ticks_msec() < deadline:
		var snapshot: CyberSimulationSnapshot = owner_worker.take_latest_snapshot(observed_serial)
		if snapshot != null:
			observed_serial = snapshot.serial
			_coupling_last_native_tick = snapshot.tick_index
			if snapshot.simulation_failed:
				return _fail("Native owner failed during held material ticks; reset the complete session")
			if snapshot.tick_index >= target:
				_coupling_snapshot_serial = maxi(_coupling_snapshot_serial, observed_serial)
				_coupling_last_applied_sample = _coupling_sample_serial
				bridge.retire_held_cellular_sample(0, _coupling_sample_serial)
				set_paused(true)
				return true
		await _tree.process_frame
		OS.delay_usec(500)
	if _owns(owner_generation, owner_worker):
		set_paused(true)
	return false

func inspect_coupling(points: PackedInt32Array = PackedInt32Array(),
		region: Rect2i = Rect2i(0, 0, 128, 80)) -> Dictionary:
	if worker == null or _opening or _release_in_progress or transaction_busy:
		return {"ok":false,"outcome":"SessionBusyOrClosed"}
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var was_paused: bool = physics_paused
	set_paused(true)
	var request: Dictionary = {"action":"inspect", "probe_points":points,
		"snapshot_origin":region.position, "snapshot_size":region.size,
		"include_body_metrics":true}
	var result: Dictionary = await command(request)
	if not _owns(owner_generation, owner_worker):
		return {"ok":false,"outcome":"SessionRetired"}
	if result.get("ok", false):
		set_paused(was_paused)
	return result

func coupling_metrics() -> Dictionary:
	return {"proxy_count":_coupling_local_centers.size(), "proxy_mass":_coupling_total_mass,
		"state_publications":_coupling_state_publications, "result_snapshots":_coupling_result_snapshots,
		"result_records":_coupling_result_records, "contacts":_coupling_contacts,
		"displaced":_coupling_displaced, "unresolved":_coupling_unresolved,
		"impulse_applications":_coupling_impulse_applications,
		"correction_applications":_coupling_correction_applications,
		"stale_results":_coupling_stale_results, "last_impulse":_coupling_last_impulse,
		"last_correction":_coupling_last_correction, "native_tick":_coupling_last_native_tick,
		"sample_serial":_coupling_sample_serial,
		"terrain_revision":_terrain_revision, "terrain_refreshes":_terrain_refreshes,
		"terrain_refresh_ms":float(_terrain_refresh_usec) / 1000.0,
		"worker_step_ms":_last_worker_step_ms, "native_tick_ms":_last_native_tick_ms,
		"timed_snapshots":_timed_snapshots,
		"observed_worker_step_ms_total":_observed_worker_ms, "observed_worker_step_ms_max":_observed_worker_max_ms,
		"observed_native_tick_ms_total":_observed_native_ms, "observed_native_tick_ms_max":_observed_native_max_ms,
		"main_sync_segments":_main_sync_segments, "main_sync_ms_total":float(_main_sync_usec) / 1000.0,
		"main_sync_ms_max":float(_main_sync_max_usec) / 1000.0, "timed_rapier_steps":_timed_rapier_steps,
		"rapier_step_ms_total":float(_rapier_step_usec) / 1000.0, "rapier_step_ms_max":float(_rapier_step_max_usec) / 1000.0}

func body_transform() -> Transform2D:
	return bridge.body_transform(0) if bridge != null else Transform2D(0.0,source_center)

func angular_velocity() -> float:
	return float(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)) \
		if is_instance_valid(body) else 0.0

func inspect_active() -> Dictionary:
	if worker == null or _opening or _release_in_progress or transaction_busy:
		return {"ok":false,"outcome":"SessionBusyOrClosed"}
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var was_paused: bool = physics_paused
	set_paused(true)
	var result: Dictionary = await command({"action":"inspect"})
	if not _owns(owner_generation, owner_worker):
		return {"ok":false,"outcome":"SessionRetired"}
	if result.get("ok", false):
		set_paused(was_paused)
	return result

func close() -> void:
	generation += 1
	active = false
	physics_paused = true
	if worker != null:
		worker.stop_worker()
	_destroy_physics()
	worker = null
	transaction_busy = false
	_opening = false
	_release_in_progress = false
	_failed = false
	_terrain_revision = -1
	_terrain_refreshes = 0
	_terrain_refresh_usec = 0
	_last_worker_step_ms = 0.0
	_last_native_tick_ms = 0.0
	_timed_snapshots = 0
	_observed_worker_ms = 0.0
	_observed_worker_max_ms = 0.0
	_observed_native_ms = 0.0
	_observed_native_max_ms = 0.0
	_main_sync_usec = 0
	_main_sync_max_usec = 0
	_main_sync_segments = 0
	_rapier_step_usec = 0
	_rapier_step_max_usec = 0
	_timed_rapier_steps = 0
	source_payload = PackedInt32Array()
	source_rectangles = PackedInt32Array()
	source_center = Vector2.ZERO
	source_receipt = {}
	commit_receipt = {}
	final_receipt = {}
	_coupling_local_centers = PackedVector2Array()
	_coupling_sizes = PackedVector2Array()
	_coupling_masses = PackedFloat32Array()
	_coupling_total_mass = 0.0
	_coupling_sample_serial = 0
	_coupling_snapshot_serial = -1
	_coupling_last_applied_sample = -1
	_coupling_last_native_tick = 0
	_coupling_state_publications = 0
	_coupling_result_snapshots = 0
	_coupling_result_records = 0
	_coupling_contacts = 0
	_coupling_displaced = 0
	_coupling_unresolved = 0
	_coupling_impulse_applications = 0
	_coupling_correction_applications = 0
	_coupling_stale_results = 0
	_coupling_last_impulse = Vector2.ZERO
	_coupling_last_correction = Vector2.ZERO
	status = "closed"

func _destroy_physics() -> void:
	active = false
	if is_instance_valid(body):
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	if bridge != null:
		bridge.shutdown()
		bridge = null
	if is_instance_valid(viewport):
		PhysicsServer2D.space_set_active(viewport.world_2d.space,false)
		viewport.queue_free()
	viewport = null
	body = null
	_shapes.clear()

func _fail(reason: String) -> bool:
	_failed = true
	last_error = reason
	status = "REFUSED: " + reason
	_opening = false
	_release_in_progress = false
	set_paused(true)
	return false
