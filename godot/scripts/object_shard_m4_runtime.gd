extends RefCounted

# Ordinary Workbench main-thread half of the same-World protocol. The existing
# CyberSimulationWorker owns all native calls; this object owns only copied
# receipts and the material-body adapter in Main's EXISTING Rapier space.
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
const Overlay = preload("res://scripts/object_shard_workbench_overlay.gd")
const RECEIPT_BUDGET_USEC: int = 8000
const MAX_PUMP_OPERATIONS: int = 48
const RECEIPT_DEADLINE_USEC: int = 15000000
const PHYSICS_DELTA: float = 1.0/60.0
var enabled: bool = false
var phase: String = "Disabled"
var held_reason: String = ""
var frame: Dictionary = {}
var publication: Dictionary = {}
var capabilities: Dictionary = {}
var last_receipt: Dictionary = {}
var bridge = Bridge.new()
var overlay: Control
var _host: Control
var _pending_serial: int = 0
var _pending_kind: String = ""
var _pending_since: int = 0
var _attach_requested: bool = false
var _bound_generation: int = -1
var _terrain_owned: bool = false
var _complete_requested: bool = false
var _interval_active: bool = false
var _interval_single_step: bool = false
var _interval_completed: float = 0.0
var _interval_segments: int = 0
var _pending_delta: float = 0.0
var _pending_poses: Array = []
var _step_serial: int = 0
var _semantic_tick: int = -1
var _last_synced_sequence: int = -1
var _physics_ready: bool = false
var _motion_lease: int = 0
var motion_permits_refused: int = 0
var last_motion_permit: Dictionary = {}
var physical_steps: int = 0
var physical_intervals: int = 0
var native_pose_acknowledgements: int = 0
var total_pump_usec: int = 0
var max_pump_usec: int = 0
var controls_completed: int = 0
var owner_replacements: int = 0

func enable(host: Control) -> Dictionary:
	_host = host
	if enabled: return {"ok":held_reason.is_empty(),"outcome":phase}
	enabled = true
	phase = "WaitingForWorkbench"
	_mount_overlay()
	return {"ok":true,"outcome":phase}

func _mount_overlay() -> void:
	if overlay != null or _host == null: return
	overlay = Overlay.new()
	overlay.name = "ObjectShardMaterialOverlay"
	overlay.host = _host
	_host.world_view.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func owns_terrain() -> bool:
	return enabled and _terrain_owned

func has_live_inventory() -> bool:
	for shard: Dictionary in frame.get("shards",[]):
		if shard.get("owns_inventory",false): return true
	return bool(frame.get("promotion",{}).get("present",false))

func can_preserve_world() -> bool:
	return not enabled or (not has_live_inventory() and _pending_serial == 0 and not _interval_active)

func pending_physics() -> bool:
	return _interval_active or _pending_serial != 0 or not _physics_ready

func physics_ready() -> bool:
	return enabled and _terrain_owned and _physics_ready and held_reason.is_empty() \
		and _pending_serial == 0 and not _interval_active and not _complete_requested and _motion_lease == 0

func poll(host: Control) -> void:
	if not enabled: return
	_host = host
	_mount_overlay()
	if host.shared_workbench == null or host.latest_snapshot == null or host.simulation_worker == null: return
	# Do not attach or step while the existing owner is preparing a replacement.
	if not host.pending_microscenario_apply.is_empty() or host._pending_physical_candidate != null: return
	var current_generation: int = int(host.latest_snapshot.render_world_generation)
	if _bound_generation >= 0 and _bound_generation != current_generation:
		world_replaced()
	if not held_reason.is_empty():
		phase = "Held"
		return
	if host.simulation_worker.has_failed():
		_hold("NativeWorldFailed")
		return
	var started: int = Time.get_ticks_usec()
	for operation: int in range(MAX_PUMP_OPERATIONS):
		if Time.get_ticks_usec()-started >= RECEIPT_BUDGET_USEC: break
		var progressed: bool = _poll_once()
		if not held_reason.is_empty(): break
		if not progressed:
			if _pending_serial == 0: break
			# Bounded rendezvous only for work already admitted. This creates no
			# semantic ticks and never invokes native or Rapier on the worker.
			OS.delay_usec(100)
	var elapsed: int = Time.get_ticks_usec()-started
	total_pump_usec += elapsed
	max_pump_usec = maxi(max_pump_usec,elapsed)
	_present_if_coherent()
	if overlay != null: overlay.queue_redraw()

func _poll_once() -> bool:
	var worker: CyberSimulationWorker = _host.simulation_worker
	if not _attach_requested:
		var requested: Dictionary = worker.object_shard_request_same_world()
		if requested.get("ok",false):
			_attach_requested = true
			phase = "AwaitingFirstNativeTick"
		else:
			capabilities = worker.object_shard_same_world_capabilities()
			_attach_requested = bool(capabilities.get("native_attached",false))
		return false
	capabilities = worker.object_shard_same_world_capabilities()
	if not str(capabilities.get("held_reason","")).is_empty():
		_hold(str(capabilities.held_reason))
		return false
	if not capabilities.get("native_attached",false): return false
	if _bound_generation < 0:
		if not _host.rapier_bridge.is_initialized() and _host.physical_actor_session == null:
			var empty_space_error: Error = _host.rapier_bridge.initialize_empty_workbench(_host.get_viewport().world_2d.space)
			if empty_space_error != OK:
				_hold("EmptyWorkbenchPhysicsUnavailable",{"error":empty_space_error})
				return false
		if not _host.rapier_bridge.is_initialized():
			phase = "WaitingForMainPhysics"
			return false
		frame = worker.object_shard_owner_frame()
		if frame.is_empty(): return false
		var initialized: Dictionary = bridge.initialize(int(frame.session),_host.rapier_bridge.shared_space(),16,256)
		if not initialized.get("ok",false):
			_hold("SharedRapierInitializationFailed",initialized)
			return false
		_bound_generation = int(capabilities.world_generation)
		phase = "BindingMainPhysics"
		_physics_ready = false
		return true
	if _pending_serial != 0:
		var replies: Array = worker.object_shard_take_owner_results(8)
		for row: Variant in replies:
			if not row is Dictionary or int(row.get("serial",-1)) != _pending_serial \
				or int(row.get("world_generation",-1)) != _bound_generation \
				or int(row.get("shard_session",-1)) != int(capabilities.shard_session):
				_hold("ForeignOrUnexpectedOwnerReceipt")
				return false
			var kind: String = _pending_kind
			_pending_serial = 0
			_pending_kind = ""
			last_receipt = row.get("result",{}).duplicate(true)
			frame = row.get("frame",{}).duplicate(true)
			controls_completed += 1
			if not last_receipt.get("ok",false):
				_hold("NativeControlRefused:"+kind,last_receipt)
				return false
			if kind == "motion":
				if not bridge._valid_motion_receipt(last_receipt,_pending_poses,_semantic_tick):
					_hold("UnprovedNativePoseApplication",last_receipt)
					return false
				native_pose_acknowledgements += _pending_poses.size()
				_interval_completed += _pending_delta
				_pending_poses.clear()
				_pending_delta = 0.0
				if PHYSICS_DELTA-_interval_completed <= 0.000000001:
					_interval_active = false
					physical_intervals += 1
					# Completing actors and publishing their ordinary GCR sample
					# happens once per admitted 1/60 interval, after all native ACKs.
					_host._object_shard_m4_complete_interval(_interval_single_step)
					_complete_requested = true
				else:
					phase = "ReadyForNextSegment"
			elif kind == "complete":
				_motion_lease = 0
				_complete_requested = false
				_physics_ready = true
				phase = "Ready"
			elif kind == "reserved": phase = "InstallDebitedTerrain"
			elif kind == "terrain": phase = "ActivateReservedBody"
			elif kind in ["activated","geometry"]: phase = "Synchronizing"
			return true
		if Time.get_ticks_usec()-_pending_since > RECEIPT_DEADLINE_USEC:
			_hold("NativeReceiptDeadline")
		return false
	if _interval_active:
		return _advance_segment()
	if _complete_requested:
		return _send("complete_motion",{},"complete")
	var latest: Dictionary = worker.object_shard_owner_frame()
	if not latest.is_empty(): frame = latest
	if frame.is_empty(): return false
	var sequence: int = int(frame.get("publication_sequence",0))
	if sequence != _last_synced_sequence or not _terrain_owned or not _physics_ready:
		return _synchronize()
	return false

func _synchronize() -> bool:
	_physics_ready = false
	# A fragmentation commit changes the parent's collision shape while its
	# child remains disabled. Install that parent revision before activating
	# the child; overlapping old parent/child colliders must never be stepped.
	for changed_shard: Dictionary in frame.get("shards",[]):
		if bridge.bodies.has(int(changed_shard.id)) and changed_shard.get("geometry_pending",false):
			var changed: Dictionary = bridge.install_geometry(changed_shard)
			if not changed.get("ok",false):
				_hold("MutableGeometryInstallationFailed",changed)
				return false
			return _send("acknowledge",{"receipt":_ack(changed_shard,
				"BodyRetired" if changed.get("retired_body",false) else "GeometryInstalled")},"geometry")
	var promotion: Dictionary = frame.get("promotion",{})
	if promotion.get("present",false):
		var shard: Dictionary = _find_shard(int(promotion.id))
		if shard.is_empty():
			_hold("NativePromotionInventoryMissing")
			return false
		var lifecycle: String = str(shard.get("lifecycle",promotion.get("phase","")))
		if lifecycle == "Prepared":
			var reserved: Dictionary = bridge.reserve_body(shard)
			if not reserved.get("ok",false):
				_hold("RapierReservationRefused",reserved)
				return false
			return _send("acknowledge",{"receipt":_ack(shard,"PhysicsReserved")},"reserved")
		if lifecycle == "CommittedInactive":
			var installed: Dictionary = _install_terrain()
			if not installed.get("ok",false): return false
			var receipt: Dictionary = _ack(shard,"TerrainInstalled")
			var chunks: Array = []
			for required: Dictionary in promotion.chunks:
				for actual: Dictionary in installed.chunks:
					if int(actual.id) == int(required.id): chunks.append(actual)
			receipt.chunks = chunks
			return _send("acknowledge",{"receipt":receipt},"terrain")
		if lifecycle in ["MaskApplied","ReadyToActivate"] or phase == "ActivateReservedBody":
			var active: Dictionary = bridge.activate(shard)
			if not active.get("ok",false):
				_hold("RapierActivationRefused",active)
				return false
			return _send("acknowledge",{"receipt":_ack(shard,"BodyActivated")},"activated")
		_hold("UnknownNativePromotionPhase",{"phase":lifecycle})
		return false
	var terrain_result: Dictionary = _install_terrain()
	if not terrain_result.get("ok",false): return false
	var retained: Dictionary = {}
	for shard: Dictionary in frame.get("shards",[]):
		var id: int = int(shard.id)
		if shard.get("owns_inventory",false): retained[id] = true
	for id: Variant in bridge.bodies.keys():
		if not retained.has(id):
			var removed: Dictionary = bridge.remove_body(int(id))
			if not removed.get("ok",false):
				_hold("RetiredBodyCleanupFailed",removed)
				return false
	_last_synced_sequence = int(frame.get("publication_sequence",0))
	# A successful native release authenticates the worker/main binding only
	# after every actual shape/mass/terrain installation has succeeded.
	_complete_requested = true
	return _send("complete_motion",{},"complete")

func _install_terrain() -> Dictionary:
	var result: Dictionary = bridge.install_terrain(frame.get("terrain_chunks",[]))
	if not result.get("ok",false):
		_hold("SharedTerrainInstallationFailed",result)
		return result
	if not _terrain_owned:
		# Both calls occur on main between solver steps. The replacement is
		# read back before the previous static shapes are removed.
		_host.rapier_bridge.release_hard_surface_shapes_to_material_owner()
		_terrain_owned = true
	return result

func acquire_interval() -> bool:
	if not physics_ready(): return false
	# Must precede native-wrench consumption and actor controls. A rejected
	# permit consumes no forces, inputs, actor ticks or physical time.
	var expected: Dictionary = {}
	for key: String in ["world_generation","session","world_incarnation","publication_sequence","tick","next_transaction"]:
		expected[key] = frame.get(key)
	last_motion_permit = _host.simulation_worker.object_shard_acquire_motion(expected)
	if not last_motion_permit.get("ok",false):
		motion_permits_refused += 1
		if str(last_motion_permit.get("outcome","")) in ["InstalledFrameChanged","NativeBarrierPending","NativeGeometryPending"]:
			_physics_ready = false
		return false
	_motion_lease = int(last_motion_permit.lease)
	return true

func begin_interval(single_step: bool) -> bool:
	if _motion_lease <= 0 or _interval_active or _pending_serial != 0: return false
	_interval_active = true
	_interval_single_step = single_step
	_interval_completed = 0.0
	_interval_segments = 0
	_semantic_tick = int(frame.get("tick",-1))
	_physics_ready = false
	phase = "RealRapierInterval"
	return _advance_segment()

func _advance_segment() -> bool:
	if not _interval_active or _pending_serial != 0: return false
	var remaining: float = PHYSICS_DELTA-_interval_completed
	var delta: float = minf(remaining,PHYSICS_DELTA/float(Bridge.BASE_MOTION_SUBSTEPS))
	for body: Dictionary in bridge.bodies.values():
		if not body.get("active",false): continue
		var velocity: Vector2 = PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var angular: float = absf(float(PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)))
		var speed: float = velocity.length()
		if not velocity.is_finite() or not is_finite(angular):
			_hold("InvalidPhysicalVelocity")
			return false
		if speed > 0.0: delta = minf(delta,Bridge.MAX_SEGMENT_TRANSLATION*0.9/speed)
		if angular > 0.0: delta = minf(delta,Bridge.MAX_SEGMENT_ROTATION*0.9/angular)
		var corner_speed: float = speed+float(body.bounds_diagonal)*angular
		if corner_speed > 0.0: delta = minf(delta,Bridge.MAX_SEGMENT_CORNER_MOTION*0.9/corner_speed)
	var available: int = Bridge.MAX_MOTION_SUBSTEPS-_interval_segments
	if delta <= 0.0 or remaining/delta > float(available)+0.0000001:
		_hold("MotionSubstepCapacity")
		return false
	_host.rapier_bridge.step_interval(delta)
	_step_serial += 1
	physical_steps += 1
	_interval_segments += 1
	var sampled: Dictionary = bridge.capture_completed_main_step(_step_serial)
	if not sampled.get("ok",false):
		_hold("CompletedMainPoseCaptureFailed",sampled)
		return false
	_pending_poses = sampled.get("poses",[]).duplicate(true)
	_pending_delta = delta
	var workbench_sample: Dictionary = {}
	if _host.physical_actor_session != null:
		workbench_sample = _host.rapier_bridge.pack_material_motion_sample()
		if workbench_sample.is_empty():
			_hold("CompletedMainActorPoseCaptureFailed")
			return false
	return _send("accept_motion",{"poses":_pending_poses,"workbench_sample":workbench_sample},"motion")

func _send(command: String, values: Dictionary, kind: String) -> bool:
	if _pending_serial != 0: return false
	var request: Dictionary = values.duplicate(true)
	for key: String in ["world_generation","shard_session","world_incarnation"]:
		request[key] = capabilities.get(key,-1)
	request["main_space_id"] = bridge.space.get_id()
	request["motion_lease"] = _motion_lease
	var result: Dictionary = _host.simulation_worker.object_shard_submit_owner_control(command,request)
	if not result.get("ok",false):
		_hold("WorkerControlAdmissionRefused",result)
		return false
	_pending_serial = int(result.serial)
	_pending_kind = kind
	_pending_since = Time.get_ticks_usec()
	return true

func _find_shard(id: int) -> Dictionary:
	for row: Dictionary in frame.get("shards",[]):
		if int(row.id) == id: return row
	return {}

static func _ack(shard: Dictionary, kind: String) -> Dictionary:
	var value: Dictionary = {"kind":kind}
	for key: String in ["session","id","generation","transaction","body_generation",
		"payload_digest","geometry_revision","mask_digest","shape_digest"]:
		value[key] = shard[key]
	return value

func _present_if_coherent() -> void:
	if _host == null or frame.is_empty() or not held_reason.is_empty(): return
	if int(frame.get("world_generation",-1)) != int(_host.last_uploaded_world_generation) \
		or int(frame.get("world_revision",-1)) != int(_host.last_uploaded_revision): return
	# Keep an admitted transaction hidden until actual physics installation.
	if frame.get("promotion",{}).get("present",false): return
	for shard: Dictionary in frame.get("shards",[]):
		if shard.get("geometry_pending",false): return
	var next: Dictionary = frame.duplicate(true)
	for key: String in ["session","owner_epoch","shard_session","world_incarnation","transport_generation"]:
		next[key] = capabilities.get(key,-1)
	next["render_serial"] = int(_host.last_uploaded_render_snapshot_serial)
	publication = next
	if overlay != null: overlay.present(publication)

func visible_observation() -> Dictionary:
	var value: Dictionary = {}
	for key: String in ["world_generation","world_revision","render_serial","session","owner_epoch","shard_session","world_incarnation","transport_generation","publication_sequence"]:
		if publication.has(key): value[key] = publication[key]
	return value

func visible_target(position: Vector2i) -> Dictionary:
	if publication.is_empty(): return {}
	for shard: Dictionary in publication.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		var pose := Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
		var local: Vector2i = Vector2i((pose.affine_inverse()*(Vector2(position)+Vector2(0.5,0.5))).floor())
		if local.x < 0 or local.y < 0 or local.x >= int(shard.width) or local.y >= int(shard.height): continue
		var cell: int = local.y*int(shard.width)+local.x
		if int(shard.roles[cell]) != 1: continue
		var target: Dictionary = {"position":position,"owner":int(shard.id),"cell":cell,
			"generation":int(shard.generation),"body_generation":int(shard.body_generation),
			"geometry_revision":int(shard.geometry_revision),"applied_physics_revision":int(shard.applied_physics_revision),
			"pose_serial":int(shard.pose_serial),"material_revision":int(shard.material_revision),
			"incarnation":int(shard.incarnations[cell]),
			"expected":{"material":int(shard.materials[cell]),"state_a":int(shard.states_a[cell]),
				"state_b":int(shard.states_b[cell]),"temperature":int(shard.temperature[cell])}}
		for key: String in ["session","owner_epoch","shard_session","world_incarnation","transport_generation","publication_sequence"]:
			target[key] = publication[key]
		return target
	return {}

func _hold(reason: String, detail: Dictionary = {}) -> void:
	if held_reason.is_empty(): held_reason = reason
	phase = "Held"
	_physics_ready = false
	last_receipt = {"ok":false,"outcome":reason,"detail":detail.duplicate(true)}
	if _host != null and _host.shared_workbench != null:
		_host.shared_workbench.refuse("Structures held: "+reason+". Restore start for a fresh World.")

func world_replaced() -> void:
	# Called only after the ordinary owner accepted a whole-World replacement.
	# Never advertises a successful same-World discard of live material.
	bridge.shutdown()
	frame = {}
	publication = {}
	capabilities = {}
	_pending_serial = 0
	_pending_kind = ""
	_attach_requested = false
	_bound_generation = -1
	_terrain_owned = false
	_complete_requested = false
	_interval_active = false
	_motion_lease = 0
	_physics_ready = false
	_last_synced_sequence = -1
	held_reason = ""
	owner_replacements += 1
	phase = "WaitingForWorkbench" if enabled else "Disabled"
	if overlay != null: overlay.clear()

func shutdown() -> void:
	# Native disposal/worker join is owned by Main's existing shutdown route.
	bridge.shutdown()
	if overlay != null and is_instance_valid(overlay): overlay.queue_free()
	overlay = null
	enabled = false
	phase = "Closed"

func diagnostics() -> Dictionary:
	return {"enabled":enabled,"phase":phase,"held_reason":held_reason,"attached":_bound_generation>0,
		"world_generation":_bound_generation,"native_instance_id":capabilities.get("native_instance_id",0),
		"shared_main_space_id":bridge.space.get_id() if bridge.space.is_valid() else 0,
		"physics_ready":physics_ready(),"pending_serial":_pending_serial,"pending_kind":_pending_kind,
		"native_tick":frame.get("tick",0),"publication_sequence":frame.get("publication_sequence",0),
		"body_count":bridge.bodies.size(),"has_live_inventory":has_live_inventory(),
		"physical_steps":physical_steps,"physical_intervals":physical_intervals,
		"motion_lease":_motion_lease,"motion_permits_refused":motion_permits_refused,"last_motion_permit":last_motion_permit.duplicate(true),
		"native_pose_acknowledgements":native_pose_acknowledgements,"controls_completed":controls_completed,
		"pump_usec_total":total_pump_usec,"pump_usec_max":max_pump_usec,"owner_replacements":owner_replacements,
		"receipt":last_receipt.duplicate(true),"physics":bridge.diagnostics(),
		"save_scope":"authored-start-only; moving inventory is never serialized as World cells"}
