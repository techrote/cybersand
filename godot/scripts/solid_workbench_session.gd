extends "res://scripts/solid_detachment_session.gd"

# Opt-in scientific adapter. The World, body, cut transaction and main's
# WorkbenchBridge/law remain the actual production implementations.
const WorkbenchBridge=preload("res://scripts/workbench_physics_bridge.gd")
var workbench_law: bool=false
var workbench_packet: Dictionary={}
var workbench_application: Dictionary={}
var workbench_wait_sample: int=-1
var workbench_provisional: int=-1
var workbench_attempts: int=0
var workbench_waits: Dictionary={}
class Rig:
	extends RefCounted
	var body: RigidBody2D
	var rects: Array=[]
	func bodies() -> Array:return [body]
	func collision_rects() -> Array:return rects

func _create_bridge() -> CyberRapierPhysicsBridge:
	return WorkbenchBridge.new() if workbench_law else super._create_bridge()

func _author_surroundings(native: Object,kind: String) -> bool:
	if not super._author_surroundings(native,kind):return false
	return not workbench_law or bool(native.diagnostic_enable_solid_workbench())

func _prepare_body(prepared: Dictionary) -> bool:
	if not await super._prepare_body(prepared):return false
	if not workbench_law:return true
	if sand_resistance_enabled:return _fail("Workbench and SOL281 Sand cannot both be enabled")
	var rig:=Rig.new();rig.body=body
	for i: int in _coupling_local_centers.size():rig.rects.append({"center":_coupling_local_centers[i],"size":_coupling_sizes[i]})
	return (bridge as WorkbenchBridge).configure_instances([{"instance_id":body.get_instance_id(),
		"workbench_options":{"response":"LA-SELECTIVE","budget":20.0}}],[rig],physics_epoch+1)==OK

func _publish_compound_states() -> bool:
	if not workbench_law:return super._publish_compound_states()
	if worker==null or physics_epoch<=0:return false
	var sample: Dictionary=(bridge as WorkbenchBridge).pack_sample([false])
	if sample.is_empty():return false
	if workbench_wait_sample<0:
		if not worker.install_solid_workbench_sample(sample):return false
	else:worker.set_workbench_sample(sample)
	workbench_wait_sample=int(sample.states[10]);_coupling_sample_serial=workbench_wait_sample
	_coupling_state_publications+=1
	return true

func _prime_compound_coupling() -> bool:
	if not workbench_law:return await super._prime_compound_coupling()
	var this_generation: int=generation;var owner: CyberSimulationWorker=worker
	var sample: Dictionary=(bridge as WorkbenchBridge).pack_sample([false])
	if sample.is_empty():return false
	var bound: Dictionary=await _bind_initial_workbench(sample)
	if not _owns(this_generation,owner) or not bound.get("ok",false):return false
	if not owner.install_solid_workbench_sample(sample):return false
	workbench_wait_sample=int(sample.states[10]);_coupling_sample_serial=workbench_wait_sample
	_coupling_state_publications+=1
	var deadline: int=Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while _owns(this_generation,owner) and Time.get_ticks_msec()<deadline:
		var s: CyberSimulationSnapshot=owner.take_latest_snapshot(0)
		if s!=null:
			if s.simulation_failed:return _fail("Native World failed during workbench priming")
			var p: Dictionary=s.lab_context.get("workbench_gcr",{})
			if s.rigid_body_epoch==physics_epoch and p.get("valid",false) and p.get("rows",[]).size()==1 \
				and p.rows[0].sample==workbench_wait_sample:
				workbench_provisional=workbench_wait_sample
				return true
		await _tree.process_frame
		OS.delay_usec(500)
	return false

func _bind_initial_workbench(sample: Dictionary) -> Dictionary:
	return await command({"action":"workbench_bind","token":str(source_receipt.token),
		"body_generation":generation,"sample":sample})

func _after_unfreeze() -> bool:
	if not workbench_law:return super._after_unfreeze()
	# Frozen priming is not a completed physical sample. Retire it and publish
	# a new live serial without advancing Rapier; never bypass the main fence.
	(bridge as WorkbenchBridge).retire_provisional_samples()
	return _publish_compound_states()

func _held(reason: String) -> Dictionary:
	workbench_waits[reason]=int(workbench_waits.get(reason,0))+1
	return {"outcome":reason,"deferred":false}

func _observe_workbench_application(_packet: Dictionary,_application: Dictionary) -> void:
	pass

func physics_step() -> Dictionary:
	if not workbench_law:return super.physics_step()
	workbench_attempts+=1
	if not active or physics_paused or transaction_busy or bridge==null:return _held("Inactive")
	var this_generation: int=generation;var owner: CyberSimulationWorker=worker
	var owner_bridge: CyberRapierPhysicsBridge=bridge;var owner_body: RigidBody2D=body
	var owner_epoch: int=physics_epoch;var owner_token: String=str(source_receipt.token)
	var owner_waits: Dictionary=workbench_waits
	var s: CyberSimulationSnapshot=owner.take_latest_snapshot(0)
	if s==null:return _held("AwaitingSnapshot")
	if s.simulation_failed:
		_fail("Native World failed; hold SOL at last admitted pose")
		return _held("NativeFailed")
	if s.rigid_body_epoch!=physics_epoch:return _held("EpochMismatch")
	if not str(s.lab_context.get("workbench_refusal","")).is_empty():
		_fail(str(s.lab_context.workbench_refusal));return _held("NativeRefusal")
	# Same completed-sample and same-publication terrain gate as main.gd.
	var required: int=int(s.lab_context.get("workbench_hard_surface_revision",-1))
	if required<0 or not s.hard_surface_chunk_rectangles_valid:return _held("TerrainUnknown")
	if bridge.pending_hard_surface_chunks()==0 and s.hard_surface_revision==required and _terrain_revision!=required:
		if not bridge.queue_hard_surface_chunk_snapshot(s.hard_surface_chunk_rectangles):
			_fail("Workbench terrain refused");return _held("TerrainRefused")
		_terrain_revision=required
	if bridge.pending_hard_surface_chunks()>0:bridge.process_hard_surface_collider_budget(32,750)
	if _terrain_revision!=required or bridge.pending_hard_surface_chunks()>0:return _held("TerrainPending")
	if s.lab_context.get("workbench_completed_sample",-1)!=workbench_wait_sample:return _held("AwaitingCompletion")
	workbench_packet=s.lab_context.get("workbench_gcr",{})
	_coupling_snapshot_serial=s.serial;_coupling_last_native_tick=s.tick_index
	_observe_native_snapshot(s)
	_observe_worker_participation(s.native_worker_participation)
	_record_contact_observation(s.solid_contact_observation,s.solid_contact_work)
	(bridge as WorkbenchBridge).apply_packet(s.serial,workbench_packet)
	workbench_application=(bridge as WorkbenchBridge).last_application
	_observe_workbench_application(workbench_packet,workbench_application)
	if not workbench_application.get("accepted",false):
		_fail("Workbench application refused; reset required");return _held("ApplicationRefused")
	var direct:=PhysicsServer2D.body_get_direct_state(body.get_rid())
	if direct==null or not direct.transform.is_finite() or not direct.linear_velocity.is_finite() or not is_finite(direct.angular_velocity):
		_fail("Workbench post-application state invalid; lease retained");return _held("ApplicationFailed")
	var prior: int=bridge.manual_step_count();bridge.step()
	if not _owns(this_generation,owner) or bridge!=owner_bridge or body!=owner_body or not active \
		or physics_paused or _failed or transaction_busy or physics_epoch!=owner_epoch or str(source_receipt.get("token",""))!=owner_token:
		owner_waits["OwnerRetired"]=int(owner_waits.get("OwnerRetired",0))+1
		return {"outcome":"OwnerRetired","deferred":false}
	if bridge.manual_step_count()!=prior+1:
		_fail("Workbench Rapier step failed");return _held("StepNotAdvanced")
	if not _publish_compound_states():
		_fail("Workbench publication failed");return _held("PublicationFailed")
	return {"outcome":"Published","deferred":false}

func close() -> void:
	super.close()
	workbench_packet={};workbench_application={};workbench_wait_sample=-1;workbench_provisional=-1
	workbench_attempts=0;workbench_waits={}
