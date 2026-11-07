extends "res://tests/test_sol_workbench_law.gd"

const Prior=preload("res://tests/test_sol_workbench_law.gd")
class OrderingBridge:
	extends "res://scripts/workbench_physics_bridge.gd"
	var application_order: String="correction-first"
	var stage_values: Array[Dictionary]=[]
	var applied_action: Dictionary={}
	func capture(slot: int,label: String) -> void:
		var rid: RID=_body_rids[slot];var d:=PhysicsServer2D.body_get_direct_state(rid)
		var pose: Transform2D=d.transform;var v: Vector2=d.linear_velocity;var w: float=d.angular_velocity
		var server_pose: Transform2D=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
		var server_v: Vector2=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		var server_w: float=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
		var mass: float=PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_MASS)
		var inertia: float=PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_INERTIA)
		stage_values.append({"stage":label,"bits":Prior.Probe.bits([pose.x.x,pose.x.y,pose.y.x,pose.y.y,pose.origin.x,pose.origin.y,v.x,v.y,w,mass,inertia]),
			"server_bits":Prior.Probe.bits([server_pose.x.x,server_pose.x.y,server_pose.y.x,server_pose.y.y,server_pose.origin.x,server_pose.origin.y,server_v.x,server_v.y,server_w,mass,inertia]),
			"local_com":d.center_of_mass_local,"world_com":pose*d.center_of_mass_local,"gravity":d.total_gravity,
			"linear_damp":d.total_linear_damp,"angular_damp":d.total_angular_damp,"fixed_delta":fixed_delta(),
			"body_rid":rid.get_id(),"body_instance":_bodies[slot].get_instance_id(),"manual_step":manual_step_count(),
			"valid":true,"frozen":_bodies[slot].freeze,"sleeping":d.sleeping})
	func translate_and_clip(slot: int,action: Dictionary) -> void:
		var rid: RID=_body_rids[slot];var correction: Vector2=action.correction
		if correction!=Vector2.ZERO:
			var pose: Transform2D=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
			pose.origin+=correction
			PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM,pose)
			_transforms[slot]=pose
		capture(slot,"after_translation")
		if correction!=Vector2.ZERO:
			var velocity: Vector2=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			if velocity.x*correction.x<0:velocity.x=0
			if velocity.y*correction.y<0:velocity.y=0
			PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,velocity)
		capture(slot,"after_clip")
	func impulse_and_torque(slot: int,action: Dictionary) -> void:
		var rid: RID=_body_rids[slot]
		if action.impulse!=Vector2.ZERO:PhysicsServer2D.body_apply_central_impulse(rid,action.impulse)
		capture(slot,"after_central_impulse")
		if action.torque!=0.0:PhysicsServer2D.body_apply_torque_impulse(rid,action.torque)
		capture(slot,"after_torque_impulse")
	func _apply(slot: int,action: Dictionary) -> void:
		stage_values=[];applied_action=action.duplicate(true);capture(slot,"before_action")
		if application_order=="correction-first":
			translate_and_clip(slot,action);impulse_and_torque(slot,action)
		else:
			assert(application_order=="impulse-first")
			impulse_and_torque(slot,action);translate_and_clip(slot,action)
		if action.correction!=Vector2.ZERO or action.impulse!=Vector2.ZERO or action.torque!=0.0:
			PhysicsServer2D.body_set_state(_body_rids[slot],PhysicsServer2D.BODY_STATE_SLEEPING,false)
			_last_results_applied+=1
		capture(slot,"after_wake")

class OrderProbe:
	extends Prior.Probe
	var application_order: String="correction-first"
	func _create_bridge() -> CyberRapierPhysicsBridge:
		var result:=OrderingBridge.new();result.application_order=application_order;return result
	func _observe_workbench_application(packet: Dictionary,application: Dictionary) -> void:
		super._observe_workbench_application(packet,application)
		var ordered: OrderingBridge=bridge as OrderingBridge
		frame["order_action"]=ordered.applied_action
		frame["order_stages"]=ordered.stage_values
		for stage: Dictionary in frame.order_stages:
			stage["generation"]=generation;stage["physics_epoch"]=physics_epoch;stage["terrain_revision"]=_terrain_revision
			stage["sample_serial"]=_coupling_sample_serial;stage["snapshot_serial"]=_coupling_snapshot_serial;stage["native_tick"]=_coupling_last_native_tick

func run() -> void:
	var structure: String=OS.get_environment("SOL_STRUCTURE");var surroundings: String=OS.get_environment("SOL_SURROUNDINGS")
	var arm: String=OS.get_environment("SOL_ORDER_ARM");var workers: int=int(OS.get_environment("SOL_WORKERS"));var repeat: int=int(OS.get_environment("SOL_REPEAT"))
	var output: String=OS.get_environment("SOL_OUTPUT")
	if output.is_empty() or FileAccess.file_exists(output):printerr("SOL_ORDER refuses output overwrite");quit(1);return
	check(structure in ["tree","building"] and surroundings in ["packed_sand","mixed"] and workers in [1,4] and repeat>=0 and repeat<5,"registered coordinate")
	check(arm in ["correction-first","impulse-first"],"registered fixed-action order")
	var s:=OrderProbe.new();s.structure=structure;s.workbench_law=true;s.application_order=arm
	var opened: bool=await s.open(root,workers,surroundings,true,false,true)
	check(opened,"fresh authoritative session opens: "+s.last_error)
	if not opened:s.close();quit(1);return
	check((await s.observe_intact()).get("outcome")=="Anchored","actual intact structure anchored")
	var before: Dictionary=await s.full_census();check(not before.is_empty(),"full-domain before-cut census")
	check(await s.cut_and_release(),"real native cut/commit/finalize: "+s.last_error)
	if not s.active:s.close();quit(1);return
	var n: int=520 if structure=="tree" else 356;var target: int=12 if OS.get_environment("SOL_SMOKE")=="1" else 720
	check(s.source_receipt.member_count==n and s.commit_receipt.aggregate_owned==n,"full source tuple ownership")
	check(s.bridge.manual_step_count()==0 and s.bridge._body_rids.size()==1,"one body, zero-step handoff")
	for proof: Dictionary in s.bind_checks:check(proof.refused and proof.body.manual_step==0,"binding refusal "+str(proof.kind))
	var initial: Dictionary=s.handoff_native;check(initial.aggregate_owned==n and initial.native_source_members==0,"sole aggregate ownership")
	var shapes: Array=[]
	for i: int in PhysicsServer2D.body_get_shape_count(s.body.get_rid()):
		var shape: RID=PhysicsServer2D.body_get_shape(s.body.get_rid(),i)
		shapes.append({"type":PhysicsServer2D.shape_get_type(shape),"data":PhysicsServer2D.shape_get_data(shape),"transform":PhysicsServer2D.body_get_shape_transform(s.body.get_rid(),i),"owner_disabled":s.body.is_shape_owner_disabled(s.body.shape_find_owner(i))})
	var report: Dictionary={"registration":"SOL-WORKBENCH-ORDER-001","source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"platform":OS.get_name(),
		"structure":structure,"surroundings":surroundings,"arm":arm,"workers":workers,"repeat":repeat,"apparatus_only":target!=720,"binding_checks":s.bind_checks,
		"before_cut":census(before),"prepared":s.source_receipt,"commit":s.commit_receipt,"activation":s.final_receipt,"initial_native":census(initial),
		"initial_body":s.read(),"server_shapes":shapes,"proxy_centres":s._coupling_local_centers,"proxy_sizes":s._coupling_sizes,"proxy_masses":s._coupling_masses,
		"body_rid":s.body.get_rid().get_id(),"body_instance":s.body.get_instance_id(),"provisional_sample":s.workbench_provisional,"live_initial_sample":s._coupling_sample_serial,
		"authored":{"gravity_scale":s.body.gravity_scale,"linear_damp":s.body.linear_damp,"angular_damp":s.body.angular_damp,"ordinary_cap":3.,"correction_cap":.5,"workbench_budget":20.},
		"steps":[],"no_step_attempts":0,"no_step_usec":0,"no_step_reasons":{},"attempts":0,"attempt_usec":0,"participation":[]}
	var distinct: int=-1;var completed: int=0;var started: int=Time.get_ticks_usec();var deadline: int=Time.get_ticks_msec()+295000
	while completed<target and int(report.attempts)<14400 and Time.get_ticks_msec()<deadline:
		await physics_frame
		var prior: int=s.bridge.manual_step_count();s.physics_step();var row: Dictionary=s.frame
		report.attempts+=1;report.attempt_usec+=int(row.elapsed_usec)
		var advance: int=s.bridge.manual_step_count()-prior
		if advance==0:
			report.no_step_attempts+=1;report.no_step_usec+=int(row.elapsed_usec)
			var why: String=str(row.audit.outcome);report.no_step_reasons[why]=int(report.no_step_reasons.get(why,0))+1
			check(s._failed or row.before.bits==row.after_step.bits,"held attempt leaves body unchanged")
		else:
			check(advance==1,"one physical advance");row["step"]=completed;completed+=1
			check(row.workbench_packet.get("response")=="LA-SELECTIVE" and row.workbench_packet.get("valid",false),"actual native LA-SELECTIVE")
			check(row.workbench_packet.rows.size()==1 and row.workbench_packet.rows[0].proxy_count==(6 if structure=="tree" else 5),"exact single aggregate")
			check(row.workbench_packet.rows[0].budget==20. and row.response_attempts_delta==0,"unchanged budget, no SOL281 double response")
			row["source_sample"]=int(row.workbench_packet.rows[0].sample);row["incoming_age"]=posmod(int(row.before.sample_serial)-int(row.source_sample),1000000)
			check(row.incoming_age==0 and row.order_stages.size()==6,"completed sample and all actual primitive stages")
			report.steps.append(plain(row))
		if not s.participation.is_empty() and int(s.participation.get("sequence",-1))!=distinct:
			distinct=int(s.participation.sequence);report.participation.append(plain(s.participation))
		if s._failed:check(false,s.last_error);break
	report["physical_episode_usec"]=Time.get_ticks_usec()-started;s.set_paused(true)
	var final: Dictionary=await s.full_census();check(not final.is_empty(),"paused atomic final census")
	check(completed==target,"complete physical observation")
	check(final.get("aggregate_owned")==n and final.get("native_source_members")==0 and final.get("members")==s.source_receipt.members,"final ownership/tuples")
	report["final_native"]=census(final);report["metrics"]=s.coupling_metrics();report["workbench_attempts"]=s.workbench_attempts;report["workbench_waits"]=s.workbench_waits
	report["checks"]=checks;report["failures"]=failures;s.close();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:printerr("SOL_ORDER output failed");quit(1);return
	file.store_string(JSON.stringify(plain(report),"",true,true));file.flush();var error: Error=file.get_error();file.close()
	print("SOL_ORDER checks=",checks," failures=",failures.size()," steps=",completed);quit(int(not failures.is_empty() or error!=OK))
