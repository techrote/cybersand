extends "res://scripts/physical_actor_arena.gd"

# Experiment-owned copy of the retained synchronous pipeline. C keeps numerical
# order; T moves only sampling across actuation; S/X act only after unchanged
# bridge delivery. Native material and all ordinary owners remain unchanged.
const CausalBase = preload("res://qualification/gcr_creep_capture.gd")
var causal_arm: String = "C"
var causal_phase: Dictionary = {}
var causal_native_results := PackedFloat64Array()
var causal_rest_receipt: Dictionary = {}

func set_causal_arm(value: String) -> bool:
	if value not in ["C","T","S","X"] or not causal_phase.is_empty() or (session!=null and session.tick!=0):
		return false
	causal_arm=value
	return true

func _causal_prepare(resolve: bool) -> bool:
	var states: PackedFloat64Array = session.bridge.pack_gcr_body_states()
	if states.size()!=17 or states.size()!=session.bodies().size()*CyberRigidBodyCoupling.GCR_INPUT_STRIDE or not _world.prepare_gcr_coupling(states,resolve):
		_fail("gcr_input_refused")
		return false
	gcr_stats.prepared+=1
	causal_phase["sample"]={"count":1,"session":states[16],"serial":states[10],"position":Vector2(states[1],states[2]),
		"rotation":states[3],"velocity":Vector2(states[6],states[7]),"omega":states[8],
		"phase":"after-actuation" if causal_arm=="T" else "before-actuation"}
	return true

func _causal_actuate() -> void:
	var body: RigidBody2D = session.bodies()[0]
	var before: Dictionary = CausalBase.state(body)
	var mass: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_MASS)
	var inertia: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	var rig_tick_before: int = int(session._rigs[0]._tick)
	session.advance(1.0/PHYSICS_HZ)
	var rig_tick_after: int = int(session._rigs[0]._tick)
	var after: Dictionary = CausalBase.state(body)
	causal_phase["actuation"]={"count":rig_tick_after-rig_tick_before,"advance_call_count":1,"rig_tick_before":rig_tick_before,"rig_tick_after":rig_tick_after,
		"before":before,"after":after,"actual_mass":mass,"actual_inertia":inertia,
		"actual_impulse":(Vector2(after.velocity)-Vector2(before.velocity))*mass,
		"actual_torque_impulse":(float(after.omega)-float(before.omega))*inertia,
		"pose_unchanged":before.position==after.position and before.rotation==after.rotation}
	if not causal_phase.actuation.pose_unchanged:
		_fail("causal_actuation_changed_pose")

static func correction_intervention(bridge: CyberRapierPhysicsBridge, body: RigidBody2D, application: Dictionary, arm: String, gravity: float) -> Dictionary:
	var result: Dictionary = {"accepted":false,"arm":arm,"setter_count":0,"applied_translation":Vector2.ZERO,"inverse_translation":Vector2.ZERO,
		"offset_potential_delta":0.0,"scope":"post-delivery position setter; original zeroing and corrected-COM wrench remain unchanged"}
	var rows: Array = application.get("bodies",[])
	if arm not in ["C","T","S","X"] or not application.get("accepted",false) or rows.size()!=1:
		result["error"]="correction intervention requires one accepted physical application"
		return result
	var row: Dictionary = rows[0]
	if int(row.get("age",-1))!=0 or int(row.get("index",-1))!=0 or int(row.get("session",-1))!=bridge._gcr_session_id:
		result["error"]="correction intervention requires current age0 identity"
		return result
	var before: Dictionary = CausalBase.state(body)
	var pre_origin: Vector2 = row.current_origin
	var observed: Vector2 = Vector2(before.position)-pre_origin
	var proposed: Vector2 = row.correction
	var impulse: Vector2 = row.impulse
	result.merge({"proposed_correction":proposed,"observed_translation":observed,"pre_response_origin":pre_origin,
		"after_response_origin":before.position,"velocity_before_setter":before.velocity,"omega_before_setter":before.omega,
		"retained_angular_impulse":row.angular_impulse,"proposed_c_cross_J":proposed.cross(impulse),"observed_c_cross_J":observed.cross(impulse),
		"counterfactual_no_correction_bridge_angular_impulse":float(row.angular_impulse)+proposed.cross(impulse),
		"original_nominal_potential_delta":row.get("correction_potential_delta",0.0),
		"observed_bridge_potential_delta":-float(row.actual_mass)*gravity*observed.y})
	if observed!=Vector2.ZERO and arm in ["S","X"]:
		var target: Vector2 = Vector2(before.position) if arm=="S" else pre_origin
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
		pose.origin=target
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,pose)
		bridge.refresh_all_states()
		result.setter_count=1
	var after: Dictionary = CausalBase.state(body)
	result["final_origin"]=after.position
	result["applied_translation"]=Vector2(after.position)-Vector2(before.position)
	result["inverse_translation"]=result.applied_translation if arm=="X" else Vector2.ZERO
	result["offset_potential_delta"]=-float(row.actual_mass)*gravity*Vector2(result.applied_translation).y
	result["velocity_after_setter"]=after.velocity
	result["omega_after_setter"]=after.omega
	result["rotation_before_setter"]=before.rotation
	result["rotation_after_setter"]=after.rotation
	result["rotation_roundtrip_delta"]=float(after.rotation)-float(before.rotation)
	result["rotation_roundtrip_tolerance"]=1e-5
	result["sample"]=row.sample
	result["session"]=row.session
	result["accepted"]=after.velocity==before.velocity and after.omega==before.omega and absf(float(result.rotation_roundtrip_delta))<=1e-5 and (after.position==pre_origin if arm=="X" and observed!=Vector2.ZERO else after.position==before.position)
	if not result.accepted:
		result["error"]="position setter changed velocity, rotation or target origin"
	return result

func step(commands: Variant = []) -> Dictionary:
	if session==null or _finished or _paused:
		return snapshot()
	if session.bodies().size()!=1 or config.get("granular_experiment","")!="GCR-REST":
		_fail("causal_fixture_requires_one_registered_flyer")
		return snapshot()
	if not commands is Array or commands.size()>Session.MAX_ACTORS:
		last_error="command_batch"
		return snapshot()
	_command_receipts.clear()
	var seen: Dictionary = {}
	for command: Variant in commands:
		if command is Dictionary and Session._integer(command.get("actor_id"),0,7):
			var actor: int = int(command.actor_id)
			if seen.has(actor):
				last_error="duplicate_actor_in_batch"
				return snapshot()
			seen[actor]=true
	causal_phase={"arm":causal_arm,"schedule":"actuation-sample-native-response-rapier" if causal_arm=="T" else "sample-actuation-native-response-rapier",
		"counts":{"actuation":0,"sample":0,"native_tick":0,"rapier_step":0,"response_calls":0}}
	causal_phase["counter_before"]={"native_tick":int(_world.get_tick_index()),"rapier_steps":session.bridge.manual_step_count(),
		"session_tick":session.tick,"packed_sample":session.bridge._sample_serial,"last_applied_sample":session.bridge._applied_sample_serials[0],
		"last_snapshot":session.bridge._last_result_snapshot_serial,"rig_tick":int(session._rigs[0]._tick)}
	causal_native_results=PackedFloat64Array()
	causal_rest_receipt={}
	if causal_arm!="T":
		if not _causal_prepare(true):
			return snapshot()
	for command: Variant in commands:
		var accepted: bool = submit(command,&"policy")
		_command_receipts.append({"accepted":accepted,"reason":"" if accepted else last_error})
	_causal_actuate()
	causal_phase.counts.actuation=int(causal_phase.actuation.count)
	if _failed:
		return snapshot()
	if causal_arm=="T":
		if not _causal_prepare(true):
			return snapshot()
	causal_phase.counts.sample=(session.bridge._sample_serial-int(causal_phase.counter_before.packed_sample)+session.bridge.SAMPLE_SERIAL_LIMIT)%session.bridge.SAMPLE_SERIAL_LIMIT
	if config.has("review_fleet_index"):
		var rig = session._rigs[0]
		_review_emitter.step(_world,int(config.review_fleet_index),rig._transforms[0],rig._sizes[0],rig._action,rig._player_controller.observation(),float(rig._profile.fleet_force),session._view(0,false))
	var requests: Array = session.drain_effects()
	_effect_receipts=_effects.apply(_world,requests,session.epoch)
	_effect_requests_total+=requests.size()
	for receipt: Dictionary in _effect_receipts:
		_effect_changes_total+=int(receipt.changed_cells)
		_effect_refusals_total+=int(receipt.status=="refused")
	var usable_requests: Array = session.drain_equipment_requests()
	var equipment_state: Dictionary = _usables.step(1.0/PHYSICS_HZ,_world,session.equipment_frame(),usable_requests)
	_usable_requests_total+=usable_requests.size()
	_usable_changes_total+=int(equipment_state.get("write_count_last",0))
	for request: Dictionary in usable_requests:
		for receipt: Dictionary in equipment_state.get("receipts",[]):
			if str(receipt.get("request_id",""))!=str(request.get("request_id","")):
				continue
			_usable_accepted_total+=int(bool(receipt.get("accepted",false)))
			_usable_refused_total+=int(not bool(receipt.get("accepted",false)))
	session.accept_equipment_feedback(equipment_state)
	causal_phase["native_contact_counter_before"]=int(_world.get_rigid_body_contacts_last_tick())
	if not bool(_world.simulation_tick()):
		_fail("native_tick")
		return snapshot()
	causal_phase.counts.native_tick=int(_world.get_tick_index())-int(causal_phase.counter_before.native_tick)
	causal_phase["native_contact_counter_after"]=int(_world.get_rigid_body_contacts_last_tick())
	_coupling_results=PackedFloat32Array()
	var results: PackedFloat64Array = _world.gcr_body_results()
	if results.size()!=session.bodies().size()*CyberRigidBodyCoupling.GCR_RESULT_STRIDE:
		_fail("gcr_response_refused")
		return snapshot()
	gcr_stats.responses+=results.size()/CyberRigidBodyCoupling.GCR_RESULT_STRIDE
	var receipt: Dictionary = _world.gcr_rest_receipt()
	causal_native_results=results.duplicate()
	causal_rest_receipt=receipt.duplicate(true)
	gcr_stats.applications+=session.bridge.apply_gcr_results(session.tick+1,results,receipt)
	causal_phase.counts.response_calls+=1
	var application: Dictionary = session.bridge.gcr_application_diagnostics()
	if not bool(application.get("accepted",false)):
		_fail("gcr_application_refused")
		return snapshot()
	causal_phase["correction_setter"]=correction_intervention(session.bridge,session.bodies()[0],application,causal_arm,38.0)
	if not causal_phase.correction_setter.accepted:
		_fail("causal_position_setter_refused")
		return snapshot()
	for body: Dictionary in _world.gcr_diagnostics().get("bodies",[]):
		var event_value: Variant = body.get("event_accepted",Vector2.ZERO)
		var event_magnitude: float = event_value.length() if event_value is Vector2 else float(event_value)
		if float(body.get("normal_accepted",0))+event_magnitude>0:
			gcr_stats.granular_frames+=1
	_sync_terrain()
	if _failed:
		return snapshot()
	session.bridge.step()
	causal_phase.counts.rapier_step=session.bridge.manual_step_count()-int(causal_phase.counter_before.rapier_steps)
	session.complete_step()
	causal_phase["counter_after"]={"native_tick":int(_world.get_tick_index()),"rapier_steps":session.bridge.manual_step_count(),
		"session_tick":session.tick,"packed_sample":session.bridge._sample_serial,"last_applied_sample":session.bridge._applied_sample_serials[0],
		"last_snapshot":session.bridge._last_result_snapshot_serial,"rig_tick":int(session._rigs[0]._tick)}
	causal_phase["observed_session_tick_delta"]=int(causal_phase.counter_after.session_tick)-int(causal_phase.counter_before.session_tick)
	var applied_rows: Array = application.get("bodies",[])
	causal_phase["fresh_sample_applied"]=applied_rows.size()==1 and int(applied_rows[0].get("sample",-1))==int(causal_phase.sample.serial) and int(causal_phase.counter_after.last_applied_sample)==int(causal_phase.sample.serial) and int(causal_phase.counter_after.last_snapshot)==int(causal_phase.counter_before.session_tick)+1 and int(applied_rows[0].get("age",-1))==0 and int(causal_phase.counter_after.last_applied_sample)!=int(causal_phase.counter_before.last_applied_sample)
	if causal_phase.counts!={"actuation":1,"sample":1,"native_tick":1,"rapier_step":1,"response_calls":1} or int(causal_phase.observed_session_tick_delta)!=1 or not causal_phase.fresh_sample_applied:
		_fail("causal_observed_boundary_counter_mismatch")
	for actor: Dictionary in session.snapshot().actors:
		if not str(actor.get("fault","")).is_empty():
			_fail("actor_fault: "+str(actor.fault))
			break
	if not _failed and session.tick>=int(config.max_ticks):
		_finished=true
		_reason="tick_limit"
		session.set_suspended(true)
	return snapshot()
