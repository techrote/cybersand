extends RefCounted

# Ordinary Workbench main-thread half of the same-World protocol. The existing
# CyberSimulationWorker owns all native calls; this object owns only copied
# receipts and the material-body adapter in Main's EXISTING Rapier space.
const Bridge = preload("res://scripts/object_shard_physics_bridge.gd")
const Overlay = preload("res://scripts/object_shard_workbench_overlay.gd")
const RECEIPT_BUDGET_USEC: int = 8000
const MAX_PUMP_OPERATIONS: int = 128
const RECEIPT_DEADLINE_USEC: int = 15000000
const MOTION_PERMIT_BUDGET_USEC: int = 2000
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
var _required_native_tick: int = -1
var _last_synced_sequence: int = -1
var _physics_ready: bool = false
var _motion_lease: int = 0
var motion_permits_refused: int = 0
var motion_permit_waits_recovered: int = 0
var motion_permit_refusal_kinds: Dictionary = {}
var last_motion_permit: Dictionary = {}
var last_reabsorption_receipt: Dictionary = {}
var _reabsorption_action_serial: int = 0
var _costs: Dictionary = {}
var _control_timing: Dictionary = {}
var deferred_world_uploads: int = 0
var physical_steps: int = 0
var physical_intervals: int = 0
var native_pose_acknowledgements: int = 0
var native_pose_echo_checks: int = 0
var total_pump_usec: int = 0
var max_pump_usec: int = 0
var pump_calls: int = 0
var pump_operation_exhaustions: int = 0
var pump_budget_exhaustions: int = 0
var pump_waits: int = 0
var controls_completed: int = 0
var redundant_readiness_receipts_suppressed: int = 0
var owner_replacements: int = 0

func enable(host: Control) -> Dictionary:
	_host = host
	if enabled: return {"ok":held_reason.is_empty(),"outcome":phase}
	enabled = true
	phase = "WaitingForWorkbench"
	_mount_overlay()
	Overlay.request_material_preparation(host.get_tree() if host.is_inside_tree() else null)
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

func materials_ready() -> bool:
	return not enabled or Overlay.material_preparation_ready()

func has_live_inventory() -> bool:
	for shard: Dictionary in frame.get("shards",[]):
		if shard.get("owns_inventory",false): return true
	return bool(frame.get("promotion",{}).get("present",false)) or bool(frame.get("reabsorption",{}).get("present",false))

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
	if not materials_ready():
		if Overlay.material_preparation_observation().state == "failed":
			_hold("MaterialPreparationFailed")
		else:
			phase = "PreparingMaterials"
		return
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
	pump_calls += 1
	var operations: int = 0
	for operation: int in range(MAX_PUMP_OPERATIONS):
		if Time.get_ticks_usec()-started >= RECEIPT_BUDGET_USEC:
			pump_budget_exhaustions += 1
			break
		operations += 1
		var progressed: bool = _poll_once()
		if not held_reason.is_empty(): break
		if not progressed:
			if _pending_serial == 0 and phase != "AwaitingCompletedNativeTick": break
			# Bounded rendezvous only for work already admitted. This creates no
			# semantic ticks and never invokes native or Rapier on the worker.
			pump_waits += 1
			OS.delay_usec(100)
	if operations == MAX_PUMP_OPERATIONS: pump_operation_exhaustions += 1
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
			if not _receipt_matches_pending(row):
				_hold("ForeignOrUnexpectedOwnerReceipt")
				return false
			var kind: String = _pending_kind
			_pending_serial = 0
			_pending_kind = ""
			last_receipt = row.get("result",{})
			var compact_motion: bool = row.get("compact_motion",false) == true
			if compact_motion:
				if kind != "motion" or PHYSICS_DELTA-_interval_completed-_pending_delta <= 0.000000001 \
					or last_receipt.get("pose_echo_contract") != "bounded-owner-readback-v1" \
					or last_receipt.get("pose_echo_complete") != true:
					_hold("InvalidCompactNativeMotionReceipt")
					return false
			else:
				frame = row.get("frame",{})
			_record_control_timing(kind,row.get("timing",{}))
			controls_completed += 1
			if not last_receipt.get("ok",false):
				if kind=="complete" and _motion_lease==0 and not frame.get("quarantined",true):
					# A newly admitted edit can supersede a readiness observation.
					# No physical time was consumed by this zero-lease command.
					_complete_requested = false
					_physics_ready = false
					_last_synced_sequence = -1
					phase = "Synchronizing"
					return true
				if kind == "reabsorb_prepare":
					last_reabsorption_receipt = last_receipt.duplicate(true)
					_last_synced_sequence = -1
					phase = "Synchronizing"
					_host.shared_workbench.refuse("Settle into canvas refused: "+str(last_receipt.get("outcome","not settled or cells unavailable")))
					return true
				_hold("NativeControlRefused:"+kind,last_receipt)
				return false
			if kind == "motion":
				if not bridge._valid_motion_receipt(last_receipt,_pending_poses,_semantic_tick):
					_hold("UnprovedNativePoseApplication",last_receipt)
					return false
				var echoed: Dictionary = {"shards":last_receipt.get("applied_pose_echoes",[])} if compact_motion else frame
				if not _native_pose_echo_matches(_pending_poses,echoed):
					_hold("NativePoseEchoDiffersFromActualRapierSegment")
					return false
				native_pose_echo_checks += _pending_poses.size()
				native_pose_acknowledgements += _pending_poses.size()
				_interval_completed += _pending_delta
				_pending_poses.clear()
				_pending_delta = 0.0
				if PHYSICS_DELTA-_interval_completed <= 0.000000001:
					_interval_active = false
					_required_native_tick = _semantic_tick+1
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
				_physics_ready = int(frame.get("tick",-1)) >= _required_native_tick
				phase = "Ready" if _physics_ready else "AwaitingCompletedNativeTick"
			elif kind == "reserved": phase = "InstallDebitedTerrain"
			elif kind == "terrain": phase = "ActivateReservedBody"
			elif kind in ["activated","geometry"]: phase = "Synchronizing"
			elif kind == "reabsorb_prepare": phase = "FreezeForMaterialReturn"
			elif kind == "reabsorb_frozen": phase = "InstallReturnedMaterial"
			elif kind == "reabsorb_complete":
				last_reabsorption_receipt = last_receipt.duplicate(true)
				phase = "Synchronizing"
				_host.shared_workbench.message = "Settled material returned to the ordinary canvas with a native ownership receipt."
			return true
		if Time.get_ticks_usec()-_pending_since > RECEIPT_DEADLINE_USEC:
			_hold("NativeReceiptDeadline")
		return false
	if _interval_active:
		return _advance_segment()
	if _complete_requested:
		return _send("complete_motion",{},"complete")
	var latest: Dictionary = worker.object_shard_owner_frame(int(frame.get("publication_sequence",-1)))
	if not latest.is_empty(): frame = latest
	if frame.is_empty(): return false
	if int(frame.get("tick",-1)) < _required_native_tick: return false
	var sequence: int = int(frame.get("publication_sequence",0))
	if sequence != _last_synced_sequence or not _terrain_owned or not _physics_ready:
		return _synchronize()
	return false

func _receipt_matches_pending(row: Variant) -> bool:
	return row is Dictionary and int(row.get("serial",-1)) == _pending_serial \
		and int(row.get("world_generation",-1)) == _bound_generation \
		and int(row.get("shard_session",-1)) == int(capabilities.get("shard_session",-1))

func _native_pose_echo_matches(expected: Array, observed: Dictionary = {}) -> bool:
	var source: Dictionary = frame if observed.is_empty() else observed
	var active: int = 0
	for shard: Dictionary in source.get("shards",[]):
		if shard.get("has_body",false): active += 1
	if active!=expected.size(): return false
	for pose: Dictionary in expected:
		var actual: Dictionary = {}
		for shard: Dictionary in source.get("shards",[]):
			if int(shard.get("id",0)) == int(pose.id): actual = shard; break
		if actual.is_empty(): return false
		for key: String in ["session","id","generation","body_generation","geometry_revision","pose_serial"]:
			if actual.get(key)!=pose.get(key): return false
		for key: String in ["x","y","rotation","vx","vy","angular_velocity"]:
			var published: String = "position_"+key if key in ["x","y"] else key
			if not actual.has(published) or not is_finite(float(actual[published])) \
				or absf(float(actual[published])-float(pose[key]))>0.00000001: return false
		if bool(actual.get("sleeping",false))!=bool(pose.get("sleeping",false)): return false
	return true

func _synchronize() -> bool:
	_physics_ready = false
	var reabsorption: Dictionary = frame.get("reabsorption",{})
	if reabsorption.get("present",false):
		return _synchronize_reabsorption(reabsorption)
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
		if shard.get("has_body",false) and bridge.bodies.has(id):
			# Semantic ingress/chemistry may change occupied carriers without
			# rebuilding a rigid shape. Refresh the exact published motion
			# domain before granting another physical interval; no RID or time
			# changes occur here. Intermediate leased contact cannot transfer
			# owned carriers, so the domain remains fixed throughout a lease.
			var domain: Dictionary = bridge.refresh_motion_domain(shard)
			if not domain.get("ok",false):
				_hold("MotionDomainRefreshFailed",domain)
				return false
	for id: Variant in bridge.bodies.keys():
		if not retained.has(id):
			var removed: Dictionary = bridge.remove_body(int(id))
			if not removed.get("ok",false):
				_hold("RetiredBodyCleanupFailed",removed)
				return false
	_last_synced_sequence = int(frame.get("publication_sequence",0))
	if capabilities.get("attached",false):
		# Initial binding was already authenticated by the exclusive owner.
		# A repeated zero-lease complete command changes no native barrier and
		# admits no physical time. The next interval still needs the exact
		# mutex-owned publication lease, after these actual installations.
		_physics_ready = int(frame.get("tick",-1))>=_required_native_tick
		phase = "Ready" if _physics_ready else "AwaitingCompletedNativeTick"
		redundant_readiness_receipts_suppressed += 1
		return true
	# Authenticate first attachment only after every actual shape/mass/terrain
	# installation succeeds. Leased interval completion always remains native.
	_complete_requested = true
	return _send("complete_motion",{},"complete")

func _synchronize_reabsorption(value: Dictionary) -> bool:
	var id: int = int(value.get("id",0))
	var shard: Dictionary = _find_shard(id)
	var receipt: Dictionary = {}
	for key: String in ["session","id","generation","transaction","body_generation","payload_digest","geometry_revision","mask_digest","shape_digest"]:
		receipt[key] = value.get(key,shard.get(key))
	if str(value.get("phase","")) == "Prepared":
		var frozen: Dictionary = bridge.freeze_for_reabsorption(shard,int(value.transaction))
		if not frozen.get("ok",false):
			_hold("ReabsorptionPhysicsFreezeFailed",frozen)
			return false
		receipt["kind"] = "ReabsorptionFrozen"
		return _send("acknowledge",{"receipt":receipt},"reabsorb_frozen")
	if str(value.get("phase","")) == "WorldCommitted":
		if bridge.bodies.has(id):
			var removed: Dictionary = bridge.remove_body(id)
			if not removed.get("ok",false):
				_hold("ReturnedBodyCleanupFailed",removed)
				return false
		var installed: Dictionary = _install_terrain()
		if not installed.get("ok",false): return false
		var chunks: Array = []
		for required: Dictionary in value.get("chunks",[]):
			for actual: Dictionary in installed.chunks:
				if int(actual.id)==int(required.id): chunks.append(actual)
		receipt["chunks"] = chunks
		receipt["kind"] = "ReabsorptionComplete"
		return _send("acknowledge",{"receipt":receipt},"reabsorb_complete")
	_hold("UnknownReabsorptionPhase",value)
	return false

func request_reabsorption(position: Vector2i) -> Dictionary:
	if not physics_ready() or _host == null: return {"ok":false,"outcome":"WaitForPhysicalReceipt"}
	if not _host.paused: return {"ok":false,"outcome":"PauseBeforeSettlingIntoCanvas"}
	var target: Dictionary = visible_target(position)
	if target.is_empty(): return {"ok":false,"outcome":"DisplayedMovingMaterialRequired"}
	_reabsorption_action_serial += 1
	var request: Dictionary = {"operation":"reabsorb","position":position,"target":target,
		"observation":visible_observation(),"action_id":_reabsorption_action_serial,"port_generation":1}
	for key: String in ["native_instance_id","world_generation","session","owner_epoch","shard_session","world_incarnation","transport_generation"]:
		request[key] = capabilities.get(key)
	_physics_ready = false
	if not _send("prepare_reabsorb",{"request":request},"reabsorb_prepare"):
		return {"ok":false,"outcome":"OwnerPreparationRefused"}
	return {"ok":true,"outcome":"ReabsorptionRequested","applied":false}

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
	# Offer fresh, displayed input a service opportunity between physical intervals.
	# This runs only Main-side admission; all native mutation remains worker-owned.
	if _host.shared_workbench != null and _host.shared_workbench.object_shard_edit_opportunity():
		return false
	# Must precede native-wrench consumption and actor controls. A rejected
	# permit consumes no forces, inputs, actor ticks or physical time.
	var expected: Dictionary = {}
	for key: String in ["world_generation","session","world_incarnation","publication_sequence","tick","next_transaction"]:
		expected[key] = frame.get(key)
	var started: int = Time.get_ticks_usec()
	var waited: bool = false
	for attempt: int in range(24):
		last_motion_permit = _host.simulation_worker.object_shard_acquire_motion(expected)
		if last_motion_permit.get("ok",false): break
		var reason: String = str(last_motion_permit.get("outcome",""))
		motion_permit_refusal_kinds[reason] = int(motion_permit_refusal_kinds.get(reason,0))+1
		if reason != "OwnerBusy" or Time.get_ticks_usec()-started >= MOTION_PERMIT_BUDGET_USEC: break
		# A completed native publication can precede the worker's final ordinary
		# snapshot copy. Retry only this transport-busy refusal; every attempt
		# revalidates the exact frame and no forces/actor time have been consumed.
		waited = true
		OS.delay_usec(100)
	if not last_motion_permit.get("ok",false):
		motion_permits_refused += 1
		if str(last_motion_permit.get("outcome","")) in ["InstalledFrameChanged","NativeBarrierPending","NativeGeometryPending"]:
			_physics_ready = false
		return false
	if waited: motion_permit_waits_recovered += 1
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
		var signed_angular: float = float(PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
		var angular: float = absf(signed_angular)
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
		var offset: Vector2 = pose.basis_xform(body.com)
		# Rapier reports velocity at COM; native limits constrain the stable
		# material lattice origin. Predict that point's velocity explicitly.
		var origin_velocity: Vector2 = velocity-Vector2(-offset.y,offset.x)*signed_angular
		var speed: float = origin_velocity.length()
		if not velocity.is_finite() or not is_finite(angular):
			_hold("InvalidPhysicalVelocity")
			return false
		if speed > 0.0: delta = minf(delta,Bridge.MAX_SEGMENT_TRANSLATION*0.5/speed)
		if angular > 0.0: delta = minf(delta,Bridge.segment_rotation_limit(float(body.rotation_radius))*0.5/angular)
		var corner_speed: float = speed+float(body.motion_radius)*angular
		if corner_speed > 0.0: delta = minf(delta,Bridge.MAX_SEGMENT_CORNER_MOTION*0.5/corner_speed)
	var available: int = Bridge.MAX_MOTION_SUBSTEPS-_interval_segments
	if delta <= 0.0 or remaining/delta > float(available)+0.0000001:
		_hold("MotionSubstepCapacity")
		return false
	var step_started: int = Time.get_ticks_usec()
	_host.rapier_bridge.step_interval(delta)
	_record_cost("rapier_segment","physics_work",step_started,{"delta":delta,"scope":"actual shared Main Rapier step and flush only"})
	_step_serial += 1
	physical_steps += 1
	_interval_segments += 1
	var capture_started: int = Time.get_ticks_usec()
	var sampled: Dictionary = bridge.capture_completed_main_step(_step_serial,delta)
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
	_record_cost("pose_packet_capture","publication_prepare",capture_started,{"scope":"completed shard and GCR RID reads plus copied packet construction"})
	return _send("accept_motion",{"poses":_pending_poses,"workbench_sample":workbench_sample,
		"final_segment":PHYSICS_DELTA-_interval_completed-delta<=0.000000001},"motion")

func _record_cost(name: String, stage: String, started: int, detail: Dictionary) -> void:
	var ended: int = Time.get_ticks_usec()
	var elapsed: int = ended-started
	if not _costs.has(name): _costs[name] = {"calls":0,"usec":0,"max_usec":0}
	_costs[name].calls += 1
	_costs[name].usec += elapsed
	_costs[name].max_usec = maxi(int(_costs[name].max_usec),elapsed)
	if _host != null and _host.object_shard_m4_probe.enabled:
		_host.object_shard_m4_probe.record_duration(stage,started,ended,detail)

func _record_control_timing(kind: String, timing: Dictionary) -> void:
	# These clocks belong to this exact serial's transport envelope. They do
	# not grant time, authenticate a pose, or replace native acknowledgements.
	# Queue/service/publication/delivery partition this one control's round
	# trip; other commands and Main/worker activity may overlap that span.
	var keys: Array[String] = ["admitted_usec","execution_started_usec",
		"execution_finished_usec","receipt_ready_usec"]
	var stamps: Array[int] = []
	for key: String in keys:
		if not timing.get(key) is int: return
		stamps.append(int(timing[key]))
	stamps.append(Time.get_ticks_usec())
	for index: int in range(stamps.size()-1):
		if stamps[index] < 0 or stamps[index+1] < stamps[index]: return
	if not _control_timing.has(kind): _control_timing[kind] = {}
	var stages: Array[String] = ["queue","owner_service","publication_copy","delivery"]
	for index: int in range(stages.size()):
		var stage: String = stages[index]
		if not _control_timing[kind].has(stage):
			_control_timing[kind][stage] = {"calls":0,"usec":0,"max_usec":0}
		var elapsed: int = stamps[index+1]-stamps[index]
		var counter: Dictionary = _control_timing[kind][stage]
		counter.calls += 1
		counter.usec += elapsed
		counter.max_usec = maxi(int(counter.max_usec),elapsed)

func _send(command: String, values: Dictionary, kind: String) -> bool:
	if _pending_serial != 0: return false
	var admission_started: int = Time.get_ticks_usec()
	var request: Dictionary = values.duplicate(true)
	for key: String in ["world_generation","shard_session","world_incarnation"]:
		request[key] = capabilities.get(key,-1)
	request["main_space_id"] = bridge.space.get_id()
	request["motion_lease"] = _motion_lease
	if command == "complete_motion" and _motion_lease > 0:
		request["workbench_sample_serial"] = int(_host._workbench_wait_sample) if _host.physical_actor_session != null else -1
		if _interval_single_step:
			request["workbench_step_serial"] = int(_host.shared_workbench.step_serial)
	var result: Dictionary = _host.simulation_worker.object_shard_submit_owner_control(command,request)
	_record_cost("owner_control_admission","queue_admission",admission_started,{"command":command,"scope":"bounded main-to-worker command copy and admission including mutex wait"})
	if not result.get("ok",false):
		result["actor_frame_error"] = _host._workbench_frame_error
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
	# Present the completed material/physics/native interval. Input captured
	# from that display can run before the next Main motion permit; a partial
	# substep publication would already be obsolete when the pointer arrives.
	if _interval_active or not _physics_ready or _pending_serial != 0 \
		or int(frame.get("tick",-1)) < _required_native_tick: return
	if int(frame.get("world_generation",-1)) != int(_host.last_uploaded_world_generation) \
		or int(frame.get("world_revision",-1)) != int(_host.last_uploaded_revision): return
	# Keep an admitted transaction hidden until actual physics installation.
	if frame.get("promotion",{}).get("present",false) or frame.get("reabsorption",{}).get("present",false): return
	for shard: Dictionary in frame.get("shards",[]):
		if shard.get("geometry_pending",false): return
	if int(publication.get("publication_sequence",-1)) == int(frame.get("publication_sequence",0)) \
		and int(publication.get("world_generation",-1)) == int(frame.get("world_generation",0)) \
		and int(publication.get("render_serial",-1)) == int(_host.last_uploaded_render_snapshot_serial): return
	var next: Dictionary = frame.duplicate(true)
	for key: String in ["session","owner_epoch","shard_session","world_incarnation","transport_generation"]:
		next[key] = capabilities.get(key,-1)
	next["render_serial"] = int(_host.last_uploaded_render_snapshot_serial)
	publication = next
	if overlay != null: overlay.present(publication)

func can_upload_world(snapshot: CyberSimulationSnapshot) -> bool:
	if not enabled or not _terrain_owned: return true
	var accepted: bool = snapshot != null and _physics_ready and _pending_serial == 0 \
		and not _interval_active and int(frame.get("tick",-1))>=_required_native_tick \
		and int(frame.get("world_generation",-1))==int(snapshot.render_world_generation) \
		and int(frame.get("world_revision",-1))==int(snapshot.world_revision) \
		and not frame.get("promotion",{}).get("present",false) \
		and not frame.get("reabsorption",{}).get("present",false)
	for shard: Dictionary in frame.get("shards",[]):
		if shard.get("geometry_pending",false): accepted = false
	if not accepted: deferred_world_uploads += 1
	return accepted

func present_uploaded_world() -> void:
	# Main calls this immediately after accepting the matching ordinary World
	# upload, before any draw. Both material owners change visual publication
	# together; the ordinary worker retains unacknowledged patches meanwhile.
	_present_if_coherent()

func visible_observation() -> Dictionary:
	var value: Dictionary = {}
	for key: String in ["world_generation","world_revision","render_serial","session","owner_epoch","shard_session","world_incarnation","transport_generation","publication_sequence"]:
		if publication.has(key): value[key] = publication[key]
	return value

func request_inventory_inspection() -> Dictionary:
	if _host==null or _host.simulation_worker==null or not physics_ready():
		return {"ok":false,"outcome":"WaitForPhysicalReceipt"}
	if not _host.paused: return {"ok":false,"outcome":"PauseBeforeInventoryInspection"}
	if int(publication.get("publication_sequence",-1))!=int(frame.get("publication_sequence",-2)):
		return {"ok":false,"outcome":"WaitForDisplayedInventoryPublication"}
	var source: Dictionary = {}
	for key: String in ["world_generation","session","world_incarnation","publication_sequence","tick","world_revision","next_transaction"]:
		source[key] = frame.get(key)
	for key: String in ["native_instance_id","transport_generation","owner_epoch","shard_session"]:
		source[key] = capabilities.get(key)
	return _host.simulation_worker.object_shard_request_inventory_inspection(source)

func take_inventory_inspection(token: int) -> Dictionary:
	if _host==null or _host.simulation_worker==null:
		return {"ok":false,"outcome":"InventoryInspectionRetired","token":token}
	return _host.simulation_worker.object_shard_take_inventory_inspection(token)

func _visible_shards_front_to_back() -> Array:
	var shards: Array = publication.get("shards",[]).duplicate(false)
	# Overlay z-order uses stable owner IDs; choosing the same maximum prevents
	# editing a hidden body or ordinary terrain under a visible structural cell.
	shards.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.id)>int(b.id))
	return shards

func _visible_shard_cell(position: Vector2i, shard: Dictionary, inverse: Transform2D) -> int:
	var local: Vector2i = Vector2i((inverse*(Vector2(position)+Vector2(0.5,0.5))).floor())
	if local.x < 0 or local.y < 0 or local.x >= int(shard.width) or local.y >= int(shard.height): return -1
	var cell: int = local.y*int(shard.width)+local.x
	return cell if int(shard.materials[cell])!=0 else -1

func _visible_shard_target(position: Vector2i, shard: Dictionary, inverse: Transform2D) -> Dictionary:
	var cell: int = _visible_shard_cell(position,shard,inverse)
	if cell<0 or int(shard.roles[cell])!=1: return {}
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

func visible_target(position: Vector2i) -> Dictionary:
	if publication.is_empty(): return {}
	for shard: Dictionary in _visible_shards_front_to_back():
		if not shard.get("owns_inventory",false): continue
		var inverse: Transform2D = Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y))).affine_inverse()
		if _visible_shard_cell(position,shard,inverse)>=0:
			# Cargo/products are visible foreground too. They cannot authorize
			# cutting a different body or terrain through their drawn material.
			return _visible_shard_target(position,shard,inverse)
	return {}

func visible_edit_groups(positions: Array, include_terrain: bool = true) -> Dictionary:
	var groups: Dictionary = {}
	if positions.size()>4096 or publication.is_empty(): return groups
	var shards: Array = _visible_shards_front_to_back()
	var inverses: Dictionary = {}
	for shard: Dictionary in shards:
		if shard.get("owns_inventory",false):
			inverses[int(shard.id)] = Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y))).affine_inverse()
	for position: Vector2i in positions:
		var found: bool = false
		for shard: Dictionary in shards:
			if not inverses.has(int(shard.id)): continue
			if _visible_shard_cell(position,shard,inverses[int(shard.id)])<0: continue
			found = true
			var target: Dictionary = _visible_shard_target(position,shard,inverses[int(shard.id)])
			if target.is_empty(): break
			var owner: int = int(target.owner)
			if not groups.has(owner): groups[owner] = []
			groups[owner].append(target)
			found = true
			break
		if not found and include_terrain and _host.image != null \
				and position.x>=0 and position.y>=0 and position.x<_host.image.get_width() and position.y<_host.image.get_height():
			var material: int = roundi(_host.image.get_pixelv(position).r*255.0)
			if material>0:
				if not groups.has(0): groups[0] = []
				groups[0].append(position)
	return groups

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
	_required_native_tick = -1
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
		"material_preparation":Overlay.material_preparation_observation(),
		"world_generation":_bound_generation,"native_instance_id":capabilities.get("native_instance_id",0),
		"shared_main_space_id":bridge.space.get_id() if bridge.space.is_valid() else 0,
		"physics_ready":physics_ready(),"pending_serial":_pending_serial,"pending_kind":_pending_kind,
		"native_tick":frame.get("tick",0),"publication_sequence":frame.get("publication_sequence",0),
		"body_count":bridge.bodies.size(),"has_live_inventory":has_live_inventory(),
		"physical_steps":physical_steps,"physical_intervals":physical_intervals,
		"motion_lease":_motion_lease,"motion_permits_refused":motion_permits_refused,"last_motion_permit":last_motion_permit.duplicate(true),
		"motion_permit_waits_recovered":motion_permit_waits_recovered,
		"motion_permit_refusal_kinds":motion_permit_refusal_kinds.duplicate(),
		"native_pose_acknowledgements":native_pose_acknowledgements,"controls_completed":controls_completed,
		"redundant_readiness_receipts_suppressed":redundant_readiness_receipts_suppressed,
		"native_pose_echo_checks":native_pose_echo_checks,
		"pump_usec_total":total_pump_usec,"pump_usec_max":max_pump_usec,"owner_replacements":owner_replacements,
		"pump_calls":pump_calls,"pump_operation_exhaustions":pump_operation_exhaustions,
		"pump_budget_exhaustions":pump_budget_exhaustions,"pump_waits":pump_waits,
		"receipt":last_receipt.duplicate(true),"physics":bridge.diagnostics(),
		"reabsorption_receipt":last_reabsorption_receipt.duplicate(true),
		"worker_profile":_host.simulation_worker.object_shard_owner_profile() if _host != null and _host.simulation_worker != null else {},
		"main_costs":_costs.duplicate(true),"main_cost_scope":"cumulative lifetime stage counters; phases do not overlap; pump includes waits and these stages",
		"control_timing":_control_timing.duplicate(true),
		"control_timing_scope":"exact serial queue, owner native-call service, snapshot/receipt copy and Main delivery spans; distinct from ordinary snapshot receipt_delivery and not additive to Main/worker stage totals",
		"deferred_world_uploads":deferred_world_uploads,
		"save_scope":"authored-start-only; moving inventory is never serialized as World cells"}
