extends SceneTree
const Base=preload("res://scripts/solid_workbench_session.gd")
class Probe:
	extends Base
	var structure: String="tree"
	var frame: Dictionary={}
	var participation: Dictionary={}
	var handoff_native: Dictionary={}
	var bind_checks: Array=[]
	func full_census() -> Dictionary:
		var out: Dictionary=await command({"action":"inspect","snapshot_tiles":true,"include_body_metrics":true})
		var tiles: Array=out.get("diagnostic_tiles",[])
		if not out.get("ok",false) or tiles.size()!=4:return {}
		for tile: Dictionary in tiles:
			if tile.get("cells",PackedByteArray()).size()!=512*512:return {}
			if tile.hash!=tiles[0].hash or tile.completed_ticks!=tiles[0].completed_ticks:return {}
		return out
	func _bind_initial_workbench(sample: Dictionary) -> Dictionary:
		if OS.get_environment("SOL_SMOKE")=="1":
			for kind: String in ["token","generation","placement","mass","budget"]:
				var bad: Dictionary={"action":"workbench_bind","token":str(source_receipt.token),"body_generation":generation,"sample":sample.duplicate(true)}
				if kind=="token":bad.token="foreign:owner"
				elif kind=="generation":bad.body_generation=generation+1
				elif kind=="budget":bad.sample.bodies[0].budget=21.
				else:
					var values: PackedFloat64Array=bad.sample.states
					for offset: int in range(0,values.size(),17):
						if kind=="mass":values[offset+9]+=1.
						else:values[offset+1]+=1.;values[offset+12]+=1.
					bad.sample.states=values
				var reply: Dictionary=await command(bad)
				bind_checks.append({"kind":kind,"refused":not reply.get("ok",true),"body":read()})
		var bound: Dictionary=await super._bind_initial_workbench(sample)
		if OS.get_environment("SOL_SMOKE")=="1" and bound.get("ok",false):
			var duplicate: Dictionary=await super._bind_initial_workbench(sample)
			bind_checks.append({"kind":"duplicate","refused":not duplicate.get("ok",true),"body":read()})
		return bound
	func _prime_compound_coupling() -> bool:
		if not await super._prime_compound_coupling():return false
		# Capture once while the handoff is already frozen. Pausing an uncompleted
		# live WB sample for an initial census would change its pacing admission.
		handoff_native=await full_census()
		return handoff_native.get("ok",false)
	func _create_worker() -> CyberSimulationWorker:
		var result: CyberSimulationWorker=super._create_worker();result.set_worker_participation_sampling(true);return result
	func _author_surroundings(native: Object,kind: String) -> bool:
		if structure=="building":
			for r: Array in [[50,40,4,32],[44,27,29,13],[54,40,11,4]]:
				if not native.diagnostic_fill_rect(Vector2i(r[0],r[1]),Vector2i(r[2],r[3]),0):return false
			for r: Array in [[50,27,23,4],[50,31,4,13],[69,31,4,13],[50,44,23,4],[50,48,4,24]]:
				if not native.diagnostic_fill_rect(Vector2i(r[0],r[1]),Vector2i(r[2],r[3]),BRICK):return false
		return super._author_surroundings(native,kind)
	func _observe_worker_participation(values: Dictionary) -> void:participation=values
	func read() -> Dictionary:
		if not is_instance_valid(body) or bridge==null:return {"valid":false}
		var rid: RID=body.get_rid();var d:=PhysicsServer2D.body_get_direct_state(rid)
		if d==null:return {"valid":false}
		var p: Transform2D=d.transform;var v: Vector2=d.linear_velocity;var w: float=d.angular_velocity
		var m: float=PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_MASS)
		var inertia: float=PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_INERTIA)
		var maximum: float=0.
		for shape: CollisionShape2D in _shapes:
			var rectangle: RectangleShape2D=shape.shape as RectangleShape2D
			for sx: float in [-1.,1.]:
				for sy: float in [-1.,1.]:
					var offset: Vector2=p.basis_xform(shape.position+rectangle.size*Vector2(sx,sy)*.5-d.center_of_mass_local)
					maximum=maxf(maximum,(v+Vector2(-w*offset.y,w*offset.x)).length())
		return {"valid":true,"bits":bits([p.x.x,p.x.y,p.y.x,p.y.y,p.origin.x,p.origin.y,v.x,v.y,w,m,inertia]),
			"local_com":d.center_of_mass_local,"gravity":d.total_gravity,"linear_damp":d.total_linear_damp,"angular_damp":d.total_angular_damp,
			"fixed_delta":bridge.fixed_delta(),"body_rid":rid.get_id(),"body_instance":body.get_instance_id(),
			"manual_step":bridge.manual_step_count(),"sample_serial":_coupling_sample_serial,"snapshot_serial":_coupling_snapshot_serial,
			"native_tick":_coupling_last_native_tick,"generation":generation,"physics_epoch":physics_epoch,"terrain_revision":_terrain_revision,
			"frozen":body.freeze,"sleeping":d.sleeping,"maximum_vertex_speed":maximum}
	func _consume_compound_results() -> Dictionary:
		var e: Dictionary=super._consume_compound_results()
		frame["after_application"]=read();frame["legacy_response"]=last_contact_response
		return e
	func _observe_compound_application(receipt: Dictionary,results: PackedFloat32Array,states: PackedFloat32Array,
			snapshot: int,tick: int,revision: int,epoch: int) -> void:
		frame["ordinary"]={"receipt":receipt,"results_bits":results.to_byte_array().hex_encode(),"states_bits":states.to_byte_array().hex_encode(),
			"snapshot":snapshot,"tick":tick,"revision":str(revision),"epoch":epoch,"state":read(),"current_sample":_coupling_sample_serial}
	func _observe_contact_boundary(stage: String,e: Dictionary,advanced: int) -> void:
		frame[stage]={"state":read(),"source_sample":e.sample,"current":e.current,"advanced":advanced}
	func _observe_workbench_application(packet: Dictionary,application: Dictionary) -> void:
		frame["after_application"]=read();frame["workbench_packet"]=packet;frame["workbench_application"]=application
	func physics_step() -> Dictionary:
		frame={"before":read(),"response_attempts_before":int(_contact_metrics.get("response_attempts",0))}
		var started: int=Time.get_ticks_usec();var audit: Dictionary=super.physics_step()
		frame["elapsed_usec"]=Time.get_ticks_usec()-started;frame["after_step"]=read();frame["audit"]=audit
		frame["response_attempts_delta"]=int(_contact_metrics.get("response_attempts",0))-int(frame.response_attempts_before)
		frame.erase("response_attempts_before")
		if not frame.has("after_application"):frame["after_application"]=frame.before
		return audit
	static func bits(a: Array) -> String:
		var b:=PackedByteArray();b.resize(a.size()*8)
		for i: int in a.size():b.encode_double(i*8,float(a[i]))
		return b.hex_encode()

var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("SOL_WORKBENCH ",why)
func plain(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:return [value.x,value.y]
	if value is Transform2D:return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]
	if value is Rect2i:return [value.position.x,value.position.y,value.size.x,value.size.y]
	if value is Dictionary:
		var out: Dictionary={}
		for k: Variant in value:out[str(k)]=plain(value[k])
		return out
	if value is Array or value is PackedInt32Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedByteArray or value is PackedVector2Array:
		var out: Array=[]
		for x: Variant in value:out.append(plain(x))
		return out
	return value
func census(value: Dictionary) -> Dictionary:
	var out: Dictionary=value.duplicate(true)
	for d: Dictionary in out.get("diagnostic_tiles",[]):
		var runs: Array=[];var previous: int=-1;var count: int=0
		for m: int in d.get("cells",PackedByteArray()):
			if m!=previous:
				if count:runs.append([previous,count])
				previous=m;count=0
			count+=1
		if count:runs.append([previous,count])
		d.erase("cells");d["material_runs"]=runs
	return out
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var structure: String=OS.get_environment("SOL_STRUCTURE");var surroundings: String=OS.get_environment("SOL_SURROUNDINGS")
	var arm: String=OS.get_environment("SOL_ARM");var workers: int=int(OS.get_environment("SOL_WORKERS"));var repeat: int=int(OS.get_environment("SOL_REPEAT"))
	var output: String=OS.get_environment("SOL_OUTPUT")
	if output.is_empty() or FileAccess.file_exists(output):printerr("SOL_WORKBENCH refuses output overwrite");quit(1);return
	check(structure in ["tree","building"] and surroundings in ["packed_sand","mixed"] and workers in [1,4] and repeat>=0 and repeat<5,"registered coordinate")
	check(arm in ["legacy-off","legacy-pre","workbench-LA-SELECTIVE"],"registered arm")
	var s:=Probe.new();s.structure=structure;s.workbench_law=arm=="workbench-LA-SELECTIVE"
	var opened: bool=await s.open(root,workers,surroundings,true,arm=="legacy-pre",true)
	check(opened,"fresh authoritative session opens: "+s.last_error)
	if not opened:s.close();quit(1);return
	check((await s.observe_intact()).get("outcome")=="Anchored","intact structure anchored")
	var before: Dictionary=await s.full_census()
	check(not before.is_empty(),"complete stable full-domain initial census")
	check(await s.cut_and_release(),"real cut/commit/finalize: "+s.last_error)
	if not s.active:s.close();quit(1);return
	var n: int=520 if structure=="tree" else 356
	var target: int=12 if OS.get_environment("SOL_SMOKE")=="1" else 720
	check(s.source_receipt.member_count==n and s.commit_receipt.aggregate_owned==n,"full actual source ownership")
	check(s.bridge.manual_step_count()==0 and s.bridge._body_rids.size()==1,"one body and zero-step handoff")
	for proof: Dictionary in s.bind_checks:check(proof.refused and proof.body.manual_step==0,"binding refusal "+str(proof.kind))
	var initial: Dictionary=s.handoff_native
	check(initial.aggregate_owned==n and initial.native_source_members==0,"sole aggregate ownership")
	var shapes: Array=[]
	for i: int in PhysicsServer2D.body_get_shape_count(s.body.get_rid()):
		var shape: RID=PhysicsServer2D.body_get_shape(s.body.get_rid(),i)
		shapes.append({"type":PhysicsServer2D.shape_get_type(shape),"data":PhysicsServer2D.shape_get_data(shape),"transform":PhysicsServer2D.body_get_shape_transform(s.body.get_rid(),i),"owner_disabled":s.body.is_shape_owner_disabled(s.body.shape_find_owner(i))})
	var report: Dictionary={"registration":"SOL-WORKBENCH-LAW-001","source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"platform":OS.get_name(),
		"structure":structure,"surroundings":surroundings,"arm":arm,"workers":workers,"repeat":repeat,
		"apparatus_only":target!=720,"binding_checks":s.bind_checks,
		"before_cut":census(before),"prepared":s.source_receipt,"commit":s.commit_receipt,"activation":s.final_receipt,"initial_native":census(initial),
		"initial_body":s.read(),"server_shapes":shapes,"proxy_centres":s._coupling_local_centers,"proxy_sizes":s._coupling_sizes,"proxy_masses":s._coupling_masses,
		"body_rid":s.body.get_rid().get_id(),"body_instance":s.body.get_instance_id(),"provisional_sample":s.workbench_provisional,
		"live_initial_sample":s._coupling_sample_serial,"authored":{"gravity_scale":s.body.gravity_scale,"linear_damp":s.body.linear_damp,"angular_damp":s.body.angular_damp,"ordinary_cap":3.,"correction_cap":.5,"workbench_budget":20.},
		"steps":[],"no_step_attempts":0,"no_step_usec":0,"no_step_reasons":{},"attempts":0,"attempt_usec":0,"participation":[]}
	var distinct: int=-1;var completed: int=0;var deadline: int=Time.get_ticks_msec()+295000
	while completed<target and int(report.attempts)<14400 and Time.get_ticks_msec()<deadline:
		await physics_frame
		var prior: int=s.bridge.manual_step_count();s.physics_step();var row: Dictionary=s.frame
		report.attempts+=1;report.attempt_usec+=int(row.elapsed_usec)
		var advance: int=s.bridge.manual_step_count()-prior
		if advance==0:
			report.no_step_attempts+=1;report.no_step_usec+=int(row.elapsed_usec)
			var why: String=str(row.audit.outcome);report.no_step_reasons[why]=int(report.no_step_reasons.get(why,0))+1
			check(s._failed or row.before.bits==row.after_step.bits,"held attempt does not move body")
		else:
			check(advance==1,"one actual Rapier step")
			row["step"]=completed;completed+=1
			if s.workbench_law:
				check(row.workbench_packet.get("response")=="LA-SELECTIVE" and row.workbench_packet.get("valid",false),"actual native mode")
				check(row.workbench_packet.rows.size()==1 and row.workbench_packet.rows[0].proxy_count==(6 if structure=="tree" else 5),"single exact compound owner")
				check(row.workbench_packet.rows[0].budget==20. and row.response_attempts_delta==0,"unchanged budget and no SOL281 double response")
				row["source_sample"]=int(row.workbench_packet.rows[0].sample)
				row["incoming_age"]=posmod(int(row.before.sample_serial)-int(row.source_sample),1000000)
				check(row.incoming_age==0,"current completed workbench sample")
			elif row.has("ordinary"):
				var raw: PackedByteArray=str(row.ordinary.results_bits).hex_decode()
				row["source_sample"]=int(raw.decode_float(8*4)) if raw.size()>=36 else -1
				row["incoming_age"]=posmod(int(row.ordinary.current_sample)-int(row.source_sample),1000000) if int(row.source_sample)>=0 else -1
			report.steps.append(plain(row))
		if not s.participation.is_empty() and int(s.participation.get("sequence",-1))!=distinct:
			distinct=int(s.participation.sequence);report.participation.append(plain(s.participation))
		if s._failed:check(false,s.last_error);break
	s.set_paused(true)
	var final: Dictionary=await s.full_census()
	check(not final.is_empty(),"complete stable full-domain final census")
	check(completed==target,"complete registered physical-step observation")
	check(final.get("aggregate_owned")==n and final.get("native_source_members")==0 and final.get("members")==s.source_receipt.members,"final ownership and tuples")
	check(not s.workbench_law or int(s._contact_metrics.response_attempts)==0,"no SOL281 Sand on workbench arm")
	report["final_native"]=census(final);report["metrics"]=s.coupling_metrics();report["workbench_attempts"]=s.workbench_attempts;report["workbench_waits"]=s.workbench_waits
	report["checks"]=checks;report["failures"]=failures;s.close();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:printerr("SOL_WORKBENCH output failed");quit(1);return
	file.store_string(JSON.stringify(plain(report),"",true,true));file.flush();var error: Error=file.get_error();file.close()
	print("SOL_WORKBENCH checks=",checks," failures=",failures.size()," steps=",completed);quit(int(not failures.is_empty() or error!=OK))
