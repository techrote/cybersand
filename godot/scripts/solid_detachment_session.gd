extends RefCounted

# Explicit dry/inert conformance session. One ordinary asynchronous native owner
# and the existing main-thread Rapier bridge; no alternate physics integrator.
const Worker = preload("res://scripts/solid_detachment_worker.gd")
const RenderConsumer = preload("res://scripts/solid_detachment_render_consumer.gd")
const DOMAIN := Rect2i(32, 16, 64, 64)
const ANCHORS := Rect2i(0, 67, 128, 13)
const CUT := Rect2i(50, 65, 4, 2)
const SEED := Vector2i(51, 34)
const WALL: int = 1
const BRICK: int = 43
const SAND: int = 2
const WATER: int = 3
const COUPLING_SAMPLE_LIMIT: int = 1000000
const MAX_WORKER_TIMING_SAMPLES: int = 512
const COUPLING_RESULT_AGE_LIMIT: int = 8
const COUPLING_POSITION_AGE_LIMIT: int = 2
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
var _tree: SceneTree
var _parent: Node
var _shapes: Array[CollisionShape2D] = []
var _opening: bool = false
var _release_in_progress: bool = false
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
var _coupling_unresolved_immovable: int = 0
var _coupling_unresolved_no_target: int = 0
var _coupling_unresolved_relocation_refused: int = 0
var _coupling_unresolved_unclassified: int = 0
var _coupling_impulse_applications: int = 0
var _coupling_correction_applications: int = 0
var _coupling_stale_results: int = 0
var _coupling_last_impulse: Vector2 = Vector2.ZERO
var _coupling_last_correction: Vector2 = Vector2.ZERO
var _worker_step_samples_ms: Array[float] = []
var _native_tick_samples_ms: Array[float] = []
var _snapshot_copy_samples_ms: Array[float] = []
var _snapshot_render_stage_samples_ms: Array[float] = []
var _snapshot_terrain_stage_samples_ms: Array[float] = []
var _snapshot_render_exchange_samples_ms: Array[float] = []
var _snapshot_render_accumulation_samples_ms: Array[float] = []
var _snapshot_render_full_copy_samples_ms: Array[float] = []
var _snapshot_render_residual_samples_ms: Array[float] = []
var _snapshot_render_refresh_exchange_samples_ms: Array[float] = []
var _render_native_exchange_calls: int = 0
var _render_exchanged_payload_bytes: int = 0
var _render_exchange_multi_call_samples: int = 0
# First native packet and exact pending-buffer overflow census; sampled only
# from the existing latest-only <=512 immutable worker snapshot stream.
var _render_first_status_counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _render_first_full_packets: int = 0
var _render_first_dirty_packets: int = 0
var _render_first_empty_packets: int = 0
var _render_first_payload_bytes: int = 0
var _render_retry_payload_bytes: int = 0
var _render_retry_full_packets: int = 0
var _render_overflow_bytes_only: int = 0
var _render_overflow_rectangles_only: int = 0
var _render_overflow_both: int = 0
var _render_single_call_samples: int = 0
var _render_pending_full_before_samples: int = 0
var _render_ack_cleared_samples: int = 0
var _render_pending_bytes_before_max: int = 0
var _render_pending_bytes_after_first_max: int = 0
var _snapshot_render_refresh_samples_ms: Array[float] = []
var _snapshot_terrain_refresh_samples_ms: Array[float] = []
var _snapshot_assembly_samples_ms: Array[float] = []
var _snapshot_publish_total_samples_ms: Array[float] = []
var _worker_timing_invalid_samples: int = 0
var _worker_overruns: int = 0
var _worker_sample_overflow: int = 0
var _render_consumer_enabled: bool = false
var _render_consumer: RefCounted
var _render_acknowledgements: int = 0
var _render_coalesced_packets: int = 0 # sampled snapshots, not a count
var _render_worker_refreshes: int = 0
var _render_worker_dirty_onto_full: int = 0
var _render_worker_coalesced: int = 0
var _render_worker_retries: int = 0
var _render_worker_ack_clears: int = 0
var _render_worker_baseline_drops: int = 0
var _render_worker_full_publications: int = 0
var _render_worker_published_bytes: int = 0
var _render_worker_pending_high_water: int = 0
# Totals at the first coupled (epoch-matched) snapshot. Before it no consumer
# can ACK, so whole-run totals also count an unacknowledged setup phase.
var _render_census_window_start: Dictionary = {}

func open(parent: Node, workers: int = 4, ejection_policy: int = 0,
		ejection_topology: bool = false, consume_render_packets: bool = false,
		render_mode: int = 0, copy_by_run: bool = false) -> bool:
	close()
	_render_consumer_enabled = consume_render_packets
	if consume_render_packets:
		_render_consumer = RenderConsumer.new()
	_parent = parent
	_tree = parent.get_tree()
	generation += 1
	_opening = true
	last_error = ""
	worker = Worker.new()
	# SOL281 render experiment: 0 original, 1 coalescing, 2 partial ACK (P),
	# 3 P's overflow exemption without baseline drop (E);
	# copy_by_run selects candidate R. All are opt-in and set before start.
	worker._experimental_render_full_coalescing = render_mode == 1
	worker._experimental_render_partial_ack = render_mode == 2 or render_mode == 3
	worker._experimental_render_baseline_drop = render_mode != 3 # 3 = exemption only
	worker._experimental_render_copy_by_run = copy_by_run
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	# Before start_worker(), this thread is the exclusive native owner.
	var native: Object = worker._world
	if not native.has_method(&"solid_detachment_command") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		return _fail("Source-matched native detachment and Rapier runtime required; no fallback")
	if not native.diagnostic_reset({"workers":workers,"telemetry":false,
		"ejection_policy":ejection_policy, "ejection_topology":ejection_topology}):
		return _fail("Native diagnostic setup refused")
	if native.get_ejection_policy() != ejection_policy:
		return _fail("Native experimental search policy readback mismatch")
	native.set_simulation_window_enabled(false)
	for item: Array in [[0,72,128,4,WALL], [50,40,4,32,BRICK], [44,27,29,13,BRICK],
		[54,40,11,4,BRICK], [8,45,3,27,BRICK], [60,32,1,1,0]]:
		if not native.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4]):
			return _fail("Native fixture authoring refused")
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

func set_paused(paused: bool) -> void:
	physics_paused = paused
	if worker != null:
		worker.set_frame_state(0.0,false,paused,Vector2i(64,64),Vector2i.ZERO,Vector2i(160,128),
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
	var end: int = Time.get_ticks_msec() + 10000
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
	if active or transaction_busy or worker == null or _opening or _release_in_progress:
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
	if not await _prime_compound_coupling():
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
	if bridge == null or not receipt.get("terrain_chunks_valid",false) or \
		str(receipt.get("terrain_snapshot_revision","")) != str(receipt.get("terrain_revision","invalid")):
		return false
	if not bridge.queue_hard_surface_chunk_snapshot(receipt.terrain_chunks):
		return false
	var turns: int = 0
	while bridge.pending_hard_surface_chunks() > 0 and turns < 300:
		bridge.process_hard_surface_collider_budget(16,0)
		turns += 1
	return bridge.pending_hard_surface_chunks() == 0

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
	var deadline: int = Time.get_ticks_msec() + 10000
	var expected: int = _coupling_local_centers.size() * CyberRigidBodyCoupling.INPUT_STRIDE
	while _owns(owner_generation, owner_worker) and Time.get_ticks_msec() < deadline:
		var snapshot: CyberSimulationSnapshot = owner_worker.take_latest_snapshot(_coupling_snapshot_serial)
		if snapshot != null:
			_coupling_snapshot_serial = snapshot.serial
			_coupling_last_native_tick = snapshot.tick_index
			if snapshot.rigid_body_epoch == physics_epoch and snapshot.current_rigid_body_states.size() == expected:
				return true
		await _tree.process_frame
		OS.delay_usec(500)
	return false

func _sample_age(sample_serial: int) -> int:
	var age: int = _coupling_sample_serial - sample_serial
	if age < 0:
		age += COUPLING_SAMPLE_LIMIT
	return age

func _consume_compound_results() -> void:
	if worker == null or bridge == null or not is_instance_valid(body):
		return
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(_coupling_snapshot_serial)
	if snapshot == null:
		return
	_coupling_snapshot_serial = snapshot.serial
	_coupling_last_native_tick = snapshot.tick_index
	# Monotonic worker totals: the latest observed snapshot carries every
	# earlier publication, including ones this latest-only reader skipped.
	_render_worker_refreshes = snapshot.snapshot_render_refresh_total
	_render_worker_dirty_onto_full = snapshot.snapshot_render_dirty_onto_full_total
	_render_worker_coalesced = snapshot.snapshot_render_coalesced_total
	_render_worker_retries = snapshot.snapshot_render_forced_full_retry_total
	_render_worker_ack_clears = snapshot.snapshot_render_ack_clear_total
	_render_worker_baseline_drops = snapshot.snapshot_render_baseline_drop_total
	_render_worker_full_publications = snapshot.snapshot_render_full_publication_total
	_render_worker_published_bytes = snapshot.snapshot_render_published_bytes_total
	_render_worker_pending_high_water = snapshot.snapshot_render_pending_bytes_high_water
	if snapshot.rigid_body_epoch != physics_epoch:
		return
	if _render_census_window_start.is_empty():
		_render_census_window_start = _render_census()
	# The optional CPU presentation consumer ACKs only after applying all
	# validated immutable bytes; the ordinary headless control never ACKs.
	if _render_consumer_enabled and _render_consumer != null:
		if snapshot.render_snapshot_serial > int(_render_consumer.last_serial):
			if _render_consumer.consume(snapshot):
				worker.acknowledge_render_snapshot(snapshot.render_snapshot_serial)
				_render_acknowledgements += 1
			else:
				worker.request_render_full_refresh()
	_coupling_result_snapshots += 1
	# Observes latest-only immutable worker snapshots. This is a sampled
	# duration distribution, not all native ticks or total frame time.
	if not snapshot.paused:
		_worker_overruns = maxi(_worker_overruns, int(snapshot.worker_overruns))
		if _worker_step_samples_ms.size() < MAX_WORKER_TIMING_SAMPLES:
			_worker_step_samples_ms.append(float(snapshot.worker_step_time_ms))
			_native_tick_samples_ms.append(float(snapshot.simulation_time_ms))
			var copy_ms: float = float(snapshot.snapshot_copy_time_ms)
			var render_ms: float = float(snapshot.snapshot_render_stage_time_ms)
			var terrain_ms: float = float(snapshot.snapshot_terrain_stage_time_ms)
			var exchange_ms: float = float(snapshot.snapshot_render_exchange_time_ms)
			var accumulation_ms: float = float(snapshot.snapshot_render_accumulation_time_ms)
			var full_copy_ms: float = float(snapshot.snapshot_render_full_copy_time_ms)
			var residual_ms: float = float(snapshot.snapshot_render_residual_time_ms)
			var exchange_calls: int = int(snapshot.snapshot_render_exchange_calls)
			var payload_bytes: int = int(snapshot.snapshot_render_exchanged_payload_bytes)
			var first_status: int = int(snapshot.snapshot_render_first_status)
			var first_bytes: int = int(snapshot.snapshot_render_first_bytes)
			var retry_bytes: int = int(snapshot.snapshot_render_retry_bytes)
			var overflow_flags: int = int(snapshot.snapshot_render_overflow_flags)
			var before_bytes: int = int(snapshot.snapshot_render_pending_bytes_before)
			var after_bytes: int = int(snapshot.snapshot_render_pending_bytes_after_first)
			var before_rects: int = int(snapshot.snapshot_render_pending_rectangles_before)
			var after_rects: int = int(snapshot.snapshot_render_pending_rectangles_after_first)
			var assembly_ms: float = float(snapshot.snapshot_assembly_time_ms)
			var publish_ms: float = float(snapshot.snapshot_publish_total_time_ms)
			_snapshot_copy_samples_ms.append(copy_ms)
			if (not is_finite(copy_ms) or not is_finite(assembly_ms)
				or not is_finite(publish_ms) or not is_finite(render_ms)
				or not is_finite(terrain_ms) or not is_finite(exchange_ms)
				or not is_finite(accumulation_ms) or not is_finite(full_copy_ms)
				or not is_finite(residual_ms) or copy_ms < 0.0
				or assembly_ms < 0.0 or render_ms < 0.0 or terrain_ms < 0.0
				or exchange_ms < 0.0 or accumulation_ms < 0.0
				or full_copy_ms < 0.0 or residual_ms < 0.0
				or exchange_calls < 0 or exchange_calls > 2 or payload_bytes < 0
				or first_bytes < 0 or retry_bytes < 0 or before_bytes < 0 or after_bytes < 0
				or before_rects < 0 or after_rects < 0
				or payload_bytes != first_bytes + retry_bytes
				or (exchange_calls == 0 and (first_status != -1 or first_bytes != 0
					or retry_bytes != 0 or overflow_flags != 0))
				or (exchange_calls > 0 and (first_status < 0 or first_status > 3))
				or (exchange_calls == 1 and (overflow_flags != 0 or retry_bytes != 0
					or snapshot.snapshot_render_retry_full))
				or (exchange_calls == 2 and (overflow_flags == 0 or overflow_flags > 3
					or not snapshot.snapshot_render_retry_full))
				or (snapshot.snapshot_render_coalesced and (exchange_calls != 1
					or first_status != 1 or snapshot.snapshot_render_first_full
					or overflow_flags != 0 or not snapshot.snapshot_render_pending_full_before
					or after_bytes != before_bytes or after_rects != before_rects))
				or (exchange_calls > 0 and overflow_flags != (
					(1 if after_bytes - int(snapshot.snapshot_render_overflow_exempt_bytes)
						> CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2 else 0)
					+ (2 if after_rects - int(snapshot.snapshot_render_overflow_exempt_rectangles)
						> CyberSimulationWorker.MAX_PENDING_RENDER_PATCHES
						* CyberSimulationWorker.RENDER_PATCH_METADATA_STRIDE else 0)))
				or (snapshot.snapshot_render_ack_cleared and
					(before_bytes != 0 or before_rects != 0))
				or (not snapshot.snapshot_render_stage_active
					and (exchange_calls != 0 or payload_bytes != 0))
				or publish_ms < copy_ms or publish_ms < assembly_ms
				or absf(copy_ms - render_ms - terrain_ms) > 0.002
				or absf(render_ms - exchange_ms - accumulation_ms
					- full_copy_ms - residual_ms) > 0.002):
				_worker_timing_invalid_samples += 1
			else:
				_snapshot_render_stage_samples_ms.append(render_ms)
				_snapshot_terrain_stage_samples_ms.append(terrain_ms)
				_snapshot_render_exchange_samples_ms.append(exchange_ms)
				_snapshot_render_accumulation_samples_ms.append(accumulation_ms)
				_snapshot_render_full_copy_samples_ms.append(full_copy_ms)
				_snapshot_render_residual_samples_ms.append(residual_ms)
				_render_native_exchange_calls += exchange_calls
				_render_exchanged_payload_bytes += payload_bytes
				if snapshot.snapshot_render_coalesced:
					_render_coalesced_packets += 1
				if exchange_calls == 2:
					_render_exchange_multi_call_samples += 1
					_render_retry_payload_bytes += retry_bytes
					if snapshot.snapshot_render_retry_full:
						_render_retry_full_packets += 1
					match overflow_flags:
						1:
							_render_overflow_bytes_only += 1
						2:
							_render_overflow_rectangles_only += 1
						3:
							_render_overflow_both += 1
				elif exchange_calls == 1:
					_render_single_call_samples += 1
				if exchange_calls > 0:
					_render_first_status_counts[first_status] += 1
					_render_first_payload_bytes += first_bytes
					if snapshot.snapshot_render_first_full:
						_render_first_full_packets += 1
					elif first_bytes == 0:
						_render_first_empty_packets += 1
					else:
						_render_first_dirty_packets += 1
					if snapshot.snapshot_render_pending_full_before:
						_render_pending_full_before_samples += 1
					if snapshot.snapshot_render_ack_cleared:
						_render_ack_cleared_samples += 1
					_render_pending_bytes_before_max = maxi(_render_pending_bytes_before_max, before_bytes)
					_render_pending_bytes_after_first_max = maxi(_render_pending_bytes_after_first_max, after_bytes)
				if snapshot.snapshot_render_stage_active:
					_snapshot_render_refresh_samples_ms.append(render_ms)
					_snapshot_render_refresh_exchange_samples_ms.append(exchange_ms)
				if snapshot.snapshot_terrain_stage_active:
					_snapshot_terrain_refresh_samples_ms.append(terrain_ms)
				_snapshot_assembly_samples_ms.append(assembly_ms)
				_snapshot_publish_total_samples_ms.append(publish_ms)
		else:
			_worker_sample_overflow += 1
	var results: PackedFloat32Array = snapshot.rigid_body_results
	var record_count: int = CyberRigidBodyCoupling.result_body_count(results)
	if record_count == 0:
		return
	var impulses: Array[Vector2] = []
	impulses.resize(_coupling_local_centers.size())
	impulses.fill(Vector2.ZERO)
	var correction := Vector2.ZERO
	var correction_weight: float = 0.0
	var accepted_sample: int = -1
	var accepted_records: int = 0
	var accepted_contacts: int = 0
	var accepted_displaced: int = 0
	var accepted_unresolved: int = 0
	var accepted_unresolved_immovable: int = 0
	var accepted_unresolved_no_target: int = 0
	var accepted_unresolved_relocation_refused: int = 0
	for record: int in range(record_count):
		var offset: int = record * CyberRigidBodyCoupling.RESULT_STRIDE
		var proxy_id: int = roundi(results[offset + CyberRigidBodyCoupling.RESULT_BODY_ID])
		if proxy_id < 1 or proxy_id > _coupling_local_centers.size():
			continue
		var sample: int = roundi(results[offset + CyberRigidBodyCoupling.RESULT_SAMPLE_SERIAL])
		var age: int = _sample_age(sample)
		if age > COUPLING_RESULT_AGE_LIMIT:
			_coupling_stale_results += 1
			continue
		accepted_sample = sample
		var proxy: int = proxy_id - 1
		var impulse := Vector2(results[offset + CyberRigidBodyCoupling.RESULT_IMPULSE_X],
			results[offset + CyberRigidBodyCoupling.RESULT_IMPULSE_Y]) / (1.0 + float(age) * 0.25)
		impulses[proxy] = impulse
		if age <= COUPLING_POSITION_AGE_LIMIT:
			var weight: float = _coupling_masses[proxy] / maxf(_coupling_total_mass, 1.0)
			correction += Vector2(results[offset + CyberRigidBodyCoupling.RESULT_CORRECTION_X],
				results[offset + CyberRigidBodyCoupling.RESULT_CORRECTION_Y]) * weight
			correction_weight += weight
		accepted_contacts += roundi(results[offset + CyberRigidBodyCoupling.RESULT_CONTACT_COUNT])
		accepted_displaced += roundi(results[offset + CyberRigidBodyCoupling.RESULT_DISPLACED_COUNT])
		accepted_unresolved += roundi(results[offset + CyberRigidBodyCoupling.RESULT_UNRESOLVED_COUNT])
		accepted_unresolved_immovable += roundi(
			results[offset + CyberRigidBodyCoupling.RESULT_UNRESOLVED_IMMOVABLE_COUNT]
		)
		accepted_unresolved_no_target += roundi(
			results[offset + CyberRigidBodyCoupling.RESULT_UNRESOLVED_NO_TARGET_COUNT]
		)
		accepted_unresolved_relocation_refused += roundi(
			results[offset + CyberRigidBodyCoupling.RESULT_UNRESOLVED_RELOCATION_REFUSED_COUNT]
		)
		accepted_records += 1
	if accepted_sample < 0 or accepted_sample == _coupling_last_applied_sample:
		return
	_coupling_last_applied_sample = accepted_sample
	_coupling_contacts += accepted_contacts
	_coupling_displaced += accepted_displaced
	_coupling_unresolved += accepted_unresolved
	_coupling_unresolved_immovable += accepted_unresolved_immovable
	_coupling_unresolved_no_target += accepted_unresolved_no_target
	_coupling_unresolved_relocation_refused += accepted_unresolved_relocation_refused
	_coupling_unresolved_unclassified += maxi(0, accepted_unresolved
		- accepted_unresolved_immovable
		- accepted_unresolved_no_target
		- accepted_unresolved_relocation_refused)
	_coupling_result_records += accepted_records
	if correction_weight > 0.0:
		correction = (correction / correction_weight).limit_length(COUPLING_CORRECTION_CAP)
	else:
		correction = Vector2.ZERO
	if correction.length_squared() > 0.00000001:
		var transform: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
		transform.origin += correction
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, transform)
		bridge.refresh_all_states()
		_coupling_correction_applications += 1
	var total_impulse := Vector2.ZERO
	var impulse_budget: float = 0.0
	for impulse: Vector2 in impulses:
		total_impulse += impulse
		impulse_budget += impulse.length()
	var impulse_scale: float = 1.0
	if impulse_budget > COUPLING_IMPULSE_CAP:
		impulse_scale = COUPLING_IMPULSE_CAP / impulse_budget
	var body_transform_now: Transform2D = bridge.body_transform(0)
	for proxy: int in range(impulses.size()):
		var applied: Vector2 = impulses[proxy] * impulse_scale
		if applied.length_squared() <= 0.00000001:
			continue
		var world_center: Vector2 = body_transform_now * _coupling_local_centers[proxy]
		PhysicsServer2D.body_apply_impulse(body.get_rid(), applied, world_center - body_transform_now.origin)
		_coupling_impulse_applications += 1
	_coupling_last_impulse = total_impulse * impulse_scale
	_coupling_last_correction = correction
	if _coupling_last_impulse.length_squared() > 0.00000001 or correction.length_squared() > 0.00000001:
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_SLEEPING, false)

func physics_step() -> void:
	if active and not physics_paused and not transaction_busy and bridge != null:
		_consume_compound_results()
		bridge.step()
		if not _publish_compound_states():
			_fail("Compound native occupancy publication failed; reset required")

func emit_cells(points: PackedInt32Array, material_id: int) -> bool:
	return worker != null and worker.queue_emit_cells(points, material_id)

func wait_native_ticks(ticks: int, timeout_ms: int = 10000) -> bool:
	if worker == null or ticks < 1 or active == false:
		return false
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var latest: CyberSimulationSnapshot = owner_worker.take_latest_snapshot(-1)
	var start_tick: int = latest.tick_index if latest != null else _coupling_last_native_tick
	var observed_serial: int = latest.serial if latest != null else _coupling_snapshot_serial
	var target: int = start_tick + ticks
	set_paused(false)
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while _owns(owner_generation, owner_worker) and Time.get_ticks_msec() < deadline:
		var snapshot: CyberSimulationSnapshot = owner_worker.take_latest_snapshot(observed_serial)
		if snapshot != null:
			observed_serial = snapshot.serial
			_coupling_last_native_tick = snapshot.tick_index
			if snapshot.tick_index >= target:
				_coupling_snapshot_serial = maxi(_coupling_snapshot_serial, observed_serial)
				_coupling_last_applied_sample = _coupling_sample_serial
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
		"include_body_metrics":true, "include_ejection_topology":true}
	var result: Dictionary = await command(request)
	if not _owns(owner_generation, owner_worker):
		return {"ok":false,"outcome":"SessionRetired"}
	if result.get("ok", false):
		set_paused(was_paused)
	return result

func _timing_summary_ms(samples: Array[float]) -> Dictionary:
	var result: Dictionary = {"samples":samples.size(), "p50_ms":-1.0,
		"p95_ms":-1.0, "p99_ms":-1.0, "max_ms":-1.0}
	if samples.is_empty():
		return result
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	result.p50_ms = ordered[int(floor(float(ordered.size() - 1) * 0.50))]
	result.p95_ms = ordered[int(ceil(float(ordered.size() - 1) * 0.95))]
	result.p99_ms = ordered[int(ceil(float(ordered.size() - 1) * 0.99))]
	result.max_ms = ordered.back()
	return result

func _render_census() -> Dictionary:
	return {"refreshes":_render_worker_refreshes,
		"dirty_onto_full":_render_worker_dirty_onto_full,
		"coalesced":_render_worker_coalesced,
		"forced_full_retries":_render_worker_retries,
		"ack_clears":_render_worker_ack_clears,
		"baseline_drops":_render_worker_baseline_drops,
		"full_publications":_render_worker_full_publications,
		"published_bytes":_render_worker_published_bytes}

# Monotonic totals since the first coupled snapshot (latest minus start).
func _render_census_window() -> Dictionary:
	var latest: Dictionary = _render_census()
	var window: Dictionary = {}
	for key: String in latest:
		window[key] = int(latest[key]) - int(_render_census_window_start.get(key, latest[key]))
	return window

func coupling_metrics() -> Dictionary:
	return {"proxy_count":_coupling_local_centers.size(), "proxy_mass":_coupling_total_mass,
		"state_publications":_coupling_state_publications, "result_snapshots":_coupling_result_snapshots,
		"result_records":_coupling_result_records, "contacts":_coupling_contacts,
		"displaced":_coupling_displaced, "unresolved":_coupling_unresolved,
		"unresolved_immovable":_coupling_unresolved_immovable,
		"unresolved_no_target":_coupling_unresolved_no_target,
		"unresolved_relocation_refused":_coupling_unresolved_relocation_refused,
		"unresolved_unclassified":_coupling_unresolved_unclassified,
		"impulse_applications":_coupling_impulse_applications,
		"correction_applications":_coupling_correction_applications,
		"stale_results":_coupling_stale_results, "last_impulse":_coupling_last_impulse,
		"last_correction":_coupling_last_correction, "native_tick":_coupling_last_native_tick,
		"sample_serial":_coupling_sample_serial,
		"worker_step_timing":_timing_summary_ms(_worker_step_samples_ms),
		"native_tick_timing":_timing_summary_ms(_native_tick_samples_ms),
		"snapshot_copy_timing":_timing_summary_ms(_snapshot_copy_samples_ms),
		"snapshot_render_stage_timing":_timing_summary_ms(_snapshot_render_stage_samples_ms),
		"snapshot_terrain_stage_timing":_timing_summary_ms(_snapshot_terrain_stage_samples_ms),
		"snapshot_render_exchange_timing":_timing_summary_ms(_snapshot_render_exchange_samples_ms),
		"snapshot_render_accumulation_timing":_timing_summary_ms(_snapshot_render_accumulation_samples_ms),
		"snapshot_render_full_copy_timing":_timing_summary_ms(_snapshot_render_full_copy_samples_ms),
		"snapshot_render_residual_timing":_timing_summary_ms(_snapshot_render_residual_samples_ms),
		"snapshot_render_refresh_exchange_timing":_timing_summary_ms(_snapshot_render_refresh_exchange_samples_ms),
		"render_native_exchange_calls":_render_native_exchange_calls,
		"render_coalesced_packets":_render_coalesced_packets,
		"render_worker_census":{"refreshes":_render_worker_refreshes,
			"dirty_onto_full":_render_worker_dirty_onto_full,
			"coalesced":_render_worker_coalesced,
			"forced_full_retries":_render_worker_retries,
			"ack_clears":_render_worker_ack_clears,
			"baseline_drops":_render_worker_baseline_drops,
			"full_publications":_render_worker_full_publications,
			"published_bytes":_render_worker_published_bytes,
			"pending_bytes_high_water":_render_worker_pending_high_water},
		"render_worker_census_window":_render_census_window(),
		"render_exchanged_payload_bytes":_render_exchanged_payload_bytes,
		"render_exchange_multi_call_samples":_render_exchange_multi_call_samples,
		"render_single_call_samples":_render_single_call_samples,
		"render_first_status_counts":_render_first_status_counts.duplicate(),
		"render_first_full_packets":_render_first_full_packets,
		"render_first_dirty_packets":_render_first_dirty_packets,
		"render_first_empty_packets":_render_first_empty_packets,
		"render_first_payload_bytes":_render_first_payload_bytes,
		"render_retry_payload_bytes":_render_retry_payload_bytes,
		"render_retry_full_packets":_render_retry_full_packets,
		"render_overflow_bytes_only":_render_overflow_bytes_only,
		"render_overflow_rectangles_only":_render_overflow_rectangles_only,
		"render_overflow_both":_render_overflow_both,
		"render_pending_full_before_samples":_render_pending_full_before_samples,
		"render_ack_cleared_samples":_render_ack_cleared_samples,
		"render_pending_bytes_before_max":_render_pending_bytes_before_max,
		"render_pending_bytes_after_first_max":_render_pending_bytes_after_first_max,
		"snapshot_render_refresh_timing":_timing_summary_ms(_snapshot_render_refresh_samples_ms),
		"snapshot_terrain_refresh_timing":_timing_summary_ms(_snapshot_terrain_refresh_samples_ms),
		"snapshot_assembly_timing":_timing_summary_ms(_snapshot_assembly_samples_ms),
		"snapshot_publish_total_timing":_timing_summary_ms(_snapshot_publish_total_samples_ms),
		"render_acknowledgements":_render_acknowledgements,
		"render_consumer":_render_consumer.metrics() if _render_consumer_enabled and _render_consumer != null else {"enabled":false,"consumed":0,"refused":0,"last_serial":0},
		"worker_timing_invalid_samples":_worker_timing_invalid_samples,
		"worker_overruns":_worker_overruns, "worker_sample_overflow":_worker_sample_overflow}

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
	_coupling_unresolved_immovable = 0
	_coupling_unresolved_no_target = 0
	_coupling_unresolved_relocation_refused = 0
	_coupling_unresolved_unclassified = 0
	_coupling_impulse_applications = 0
	_coupling_correction_applications = 0
	_coupling_stale_results = 0
	_coupling_last_impulse = Vector2.ZERO
	_coupling_last_correction = Vector2.ZERO
	_worker_step_samples_ms.clear()
	_native_tick_samples_ms.clear()
	_snapshot_copy_samples_ms.clear()
	_snapshot_render_stage_samples_ms.clear()
	_snapshot_terrain_stage_samples_ms.clear()
	_snapshot_render_exchange_samples_ms.clear()
	_snapshot_render_accumulation_samples_ms.clear()
	_snapshot_render_full_copy_samples_ms.clear()
	_snapshot_render_residual_samples_ms.clear()
	_snapshot_render_refresh_exchange_samples_ms.clear()
	_render_native_exchange_calls = 0
	_render_exchanged_payload_bytes = 0
	_render_exchange_multi_call_samples = 0
	_render_first_status_counts = PackedInt32Array([0, 0, 0, 0])
	_render_first_full_packets = 0
	_render_first_dirty_packets = 0
	_render_first_empty_packets = 0
	_render_first_payload_bytes = 0
	_render_retry_payload_bytes = 0
	_render_retry_full_packets = 0
	_render_overflow_bytes_only = 0
	_render_overflow_rectangles_only = 0
	_render_overflow_both = 0
	_render_single_call_samples = 0
	_render_pending_full_before_samples = 0
	_render_ack_cleared_samples = 0
	_render_pending_bytes_before_max = 0
	_render_pending_bytes_after_first_max = 0
	_snapshot_render_refresh_samples_ms.clear()
	_snapshot_terrain_refresh_samples_ms.clear()
	_snapshot_assembly_samples_ms.clear()
	_snapshot_publish_total_samples_ms.clear()
	_worker_timing_invalid_samples = 0
	_worker_overruns = 0
	_worker_sample_overflow = 0
	_render_consumer_enabled = false
	_render_consumer = null
	_render_acknowledgements = 0
	_render_coalesced_packets = 0
	_render_worker_refreshes = 0
	_render_worker_dirty_onto_full = 0
	_render_worker_coalesced = 0
	_render_worker_retries = 0
	_render_worker_ack_clears = 0
	_render_worker_baseline_drops = 0
	_render_worker_full_publications = 0
	_render_worker_published_bytes = 0
	_render_worker_pending_high_water = 0
	_render_census_window_start = {}
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
	last_error = reason
	status = "REFUSED: " + reason
	_opening = false
	_release_in_progress = false
	set_paused(true)
	return false
