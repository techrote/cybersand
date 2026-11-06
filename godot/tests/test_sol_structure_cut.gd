extends SceneTree

class Probe:
	extends "res://scripts/solid_detachment_session.gd"
	var structure: String = "tree"
	var stage_trace: bool = false
	var measured: Dictionary = {}
	func _author_surroundings(native: Object, kind: String) -> bool:
		if structure=="building":
			# Setup only, while this thread exclusively owns native; cut stays real.
			for r: Array in [[50,40,4,32],[44,27,29,13],[54,40,11,4]]:
				if not native.diagnostic_fill_rect(Vector2i(r[0],r[1]),Vector2i(r[2],r[3]),0):return false
			for r: Array in [[50,27,23,4],[50,31,4,13],[69,31,4,13],[50,44,23,4],[50,48,4,24]]:
				if not native.diagnostic_fill_rect(Vector2i(r[0],r[1]),Vector2i(r[2],r[3]),BRICK):return false
		return super._author_surroundings(native,kind)
	func _prepare_body(prepared: Dictionary) -> bool:
		var ok: bool = await super._prepare_body(prepared)
		if ok:
			body.max_contacts_reported=16
			body.contact_monitor=true
		return ok
	func read() -> Dictionary:
		if not is_instance_valid(body) or bridge==null:return {"valid":false}
		var rid: RID = body.get_rid();var d := PhysicsServer2D.body_get_direct_state(rid)
		var p: Transform2D = d.transform;var v: Vector2 = d.linear_velocity;var w: float = d.angular_velocity
		var m: float = PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_MASS)
		var inertia: float = PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_INERTIA)
		var contacts: Array = []
		for index: int in d.get_contact_count():
			contacts.append({"position":d.get_contact_local_position(index),"normal":d.get_contact_local_normal(index),
				"impulse":d.get_contact_impulse(index),"local_shape":d.get_contact_local_shape(index),
				"collider_rid":d.get_contact_collider(index).get_id(),"collider_shape":d.get_contact_collider_shape(index),
				"collider_position":d.get_contact_collider_position(index)})
		var maximum_vertex_speed: float = 0.0
		for shape: CollisionShape2D in _shapes:
			var rectangle: RectangleShape2D = shape.shape as RectangleShape2D
			for sx: float in [-1.,1.]:
				for sy: float in [-1.,1.]:
					var offset: Vector2 = p.basis_xform(shape.position+rectangle.size*Vector2(sx,sy)*0.5-d.center_of_mass_local)
					maximum_vertex_speed=maxf(maximum_vertex_speed,(v+Vector2(-w*offset.y,w*offset.x)).length())
		return {"valid":true,"pose":p,"velocity":v,"omega":w,"mass":m,"inertia":inertia,"local_com":d.center_of_mass_local,
			"body_rid":rid.get_id(),"body_instance":body.get_instance_id(),"fixed_delta":bridge.fixed_delta(),
			"gravity":d.total_gravity,"linear_damp":d.total_linear_damp,"angular_damp":d.total_angular_damp,"reported_dt":d.step,
			"sleeping":d.sleeping,"frozen":body.freeze,"contacts":contacts,"contact_report_limit":16,"contact_report_may_be_truncated":contacts.size()==16,"contact_impulse_freshness":"cached_report; sleeping freshness unqualified","maximum_vertex_speed":maximum_vertex_speed,
			"kinetic":0.5*m*(float(v.x)*v.x+float(v.y)*v.y)+0.5*inertia*w*w,"manual_step":bridge.manual_step_count(),
			"bits":bits([p.x.x,p.x.y,p.y.x,p.y.y,p.origin.x,p.origin.y,v.x,v.y,w,m,inertia]),
			"sample_serial":_coupling_sample_serial,"snapshot_serial":_coupling_snapshot_serial,"native_tick":_coupling_last_native_tick,
			"physics_epoch":physics_epoch,"generation":generation,"terrain_revision":_terrain_revision}
	func _consume_compound_results() -> void:
		measured={"before":read(),"metrics_before":coupling_metrics(),"ordinary_stage_calls":0,
			"ordinary_stage":{"observed":false,"reason":"No ordinary bridge invocation in this consume"}}
		super._consume_compound_results()
		measured["after_application"]=read();measured["metrics_after"]=coupling_metrics()
		measured["new_snapshot"]=measured.before.snapshot_serial!=measured.after_application.snapshot_serial
		measured["ordinary_records_delta"]=_coupling_result_records-int(measured.metrics_before.result_records)
		measured["ordinary_impulse_applications_delta"]=_coupling_impulse_applications-int(measured.metrics_before.impulse_applications)
		measured["ordinary_correction_applications_delta"]=_coupling_correction_applications-int(measured.metrics_before.correction_applications)
		measured["response_attempts_delta"]=int(_contact_metrics.response_attempts)-int(measured.metrics_before.physical_contact.response_attempts)
		measured["response_is_new"]=measured.response_attempts_delta>0
		measured["response"]=last_contact_response.duplicate(true)
		measured["contact_observation"]=last_contact_observation.duplicate(true)
	func _observe_compound_application(applied: Dictionary, results: PackedFloat32Array,
			states: PackedFloat32Array, snapshot_serial: int, native_tick: int,
			world_revision: int, owner_epoch: int) -> void:
		if not stage_trace:return
		measured["ordinary_stage_calls"]=int(measured.ordinary_stage_calls)+1
		measured["ordinary_stage"]={"observed":true,"state":read(),"receipt":applied.duplicate(true),
			"native_results_bits":results.duplicate().to_byte_array().hex_encode(),
			"native_states_bits":states.duplicate().to_byte_array().hex_encode(),
			"snapshot_serial":snapshot_serial,"native_tick":native_tick,"world_revision":str(world_revision),
			"owner_epoch":owner_epoch,"capture_usec":Time.get_ticks_usec()}
	static func bits(values: Array) -> String:
		var bytes := PackedByteArray();bytes.resize(values.size()*8)
		for index: int in values.size():bytes.encode_double(index*8,float(values[index]))
		return bytes.hex_encode()

var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:failures.append(reason);printerr("SOL_STRUCTURE ",reason)
func plain(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:return [value.x,value.y]
	if value is Transform2D:return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]
	if value is Rect2i:return [value.position.x,value.position.y,value.size.x,value.size.y]
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:out[str(key)]=plain(value[key])
		return out
	if value is Array or value is PackedInt32Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedByteArray or value is PackedVector2Array:
		var out: Array = []
		for item: Variant in value:out.append(plain(item))
		return out
	return value
func census(value: Dictionary) -> Dictionary:
	var out: Dictionary = value.duplicate(true)
	if out.has("diagnostic_snapshot"):
		var snapshot: Dictionary = out.diagnostic_snapshot
		var runs: Array = [];var previous: int = -1;var count: int = 0
		for material: int in snapshot.get("cells",PackedByteArray()):
			if material!=previous:
				if count:runs.append([previous,count])
				previous=material;count=0
			count+=1
		if count:runs.append([previous,count])
		snapshot.erase("cells");snapshot["material_runs"]=runs;snapshot["origin"]=Vector2i.ZERO;snapshot["size"]=Vector2i(160,128)
	return out
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var structure: String = OS.get_environment("SOL_STRUCTURE")
	var surroundings: String = OS.get_environment("SOL_SURROUNDINGS")
	var enabled: bool = OS.get_environment("SOL_SAND_RESPONSE")=="1"
	var compact_evidence: bool = OS.get_environment("SOL_COMPACT_EVIDENCE")=="1"
	var workers: int = int(OS.get_environment("SOL_WORKERS"))
	var steps: int = 720 if surroundings=="empty" else 360
	var output: String = OS.get_environment("SOL_OUTPUT")
	if output.is_empty() or FileAccess.file_exists(output):
		printerr("SOL_STRUCTURE refuses missing/existing output path");quit(1);return
	check(structure in ["tree","building"] and surroundings in ["empty","packed_sand"] and workers in [1,4],"registered input")
	var session := Probe.new();session.structure=structure;session.stage_trace=OS.get_environment("SOL_STAGE_TRACE")=="1"
	var opened: bool = await session.open(root,workers,surroundings,true,enabled,true)
	check(opened,"actual SOL source opens: "+session.last_error)
	if not opened:session.close();quit(1);return
	var intact: Dictionary = await session.observe_intact()
	check(intact.get("outcome")=="Anchored","uncut structure remains native and anchored")
	var before: Dictionary = await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128))
	check(await session.cut_and_release(),"actual native cut/discovery/commit: "+session.last_error)
	if not session.active:session.close();quit(1);return
	var expected: int = 520 if structure=="tree" else 356
	check(session.source_receipt.member_count==expected and session.source_receipt.native_source_members==expected,"prepared full source ownership")
	check(session.commit_receipt.get("aggregate_owned",-1)==expected,"committed aggregate ownership receipt")
	check(session.bridge.manual_step_count()==0,"zero physics steps inside handoff")
	check(session.bridge._body_rids.size()==1 and session.bridge._body_rids[0]==session.body.get_rid(),"one actual aggregate body")
	var initial: Dictionary = await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128))
	check(initial.get("aggregate_owned",-1)==expected and initial.get("native_source_members",-1)==0,"authoritative post-commit sole ownership census")
	var shapes: Array = []
	for shape: CollisionShape2D in session._shapes:
		var rectangle: RectangleShape2D = shape.shape as RectangleShape2D
		shapes.append({"position":shape.position,"size":rectangle.size,"disabled":shape.disabled})
	var server_shapes: Array = []
	for index: int in PhysicsServer2D.body_get_shape_count(session.body.get_rid()):
		var shape: RID = PhysicsServer2D.body_get_shape(session.body.get_rid(),index)
		server_shapes.append({"type":PhysicsServer2D.shape_get_type(shape),"data":PhysicsServer2D.shape_get_data(shape),
			"transform":PhysicsServer2D.body_get_shape_transform(session.body.get_rid(),index),
			"owner_disabled":session.body.is_shape_owner_disabled(session.body.shape_find_owner(index))})
	var report: Dictionary = {"registration":"SOL-STRUCTURE-CUT-001","source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"platform":OS.get_name(),"structure":structure,"surroundings":surroundings,"sand_response":enabled,"workers":workers,
		"stage_trace":session.stage_trace,"stage_registration":"SOL-STRUCTURE-STAGES-001" if session.stage_trace else "",
		"compact_delta_counters":compact_evidence,"mass_readiness_evidence":"Cached scalar/COM readback alone is insufficient; isolated known-wrench oracle and actual permitted response supply behavioral evidence",
		"intact":intact,"before_cut":census(before),"prepared":session.source_receipt.duplicate(true),"commit":session.commit_receipt.duplicate(true),
		"activation":session.final_receipt.duplicate(true),"initial_native":census(initial),"initial_body":session.read(),"scene_shapes":shapes,"server_shapes":server_shapes,"physical_gate_status":"PENDING_INDEPENDENT_REDUCTION",
		"proxy_centres":session._coupling_local_centers,"proxy_masses":session._coupling_masses,"proxy_sizes":session._coupling_sizes,
		"body_rid":session.body.get_rid().get_id(),"body_instance":session.body.get_instance_id(),"steps":[],
		"authored":{"gravity_scale":session.body.gravity_scale,"linear_damp":session.body.linear_damp,"angular_damp":session.body.angular_damp,
			"linear_damp_mode":session.body.linear_damp_mode,"angular_damp_mode":session.body.angular_damp_mode,"project_gravity":ProjectSettings.get_setting("physics/2d/default_gravity"),"ordinary_impulse_cap":3.0}}
	for index: int in steps:
		await physics_frame
		var started: int = Time.get_ticks_usec();var prior: int = session.bridge.manual_step_count()
		session.physics_step()
		check(session.bridge.manual_step_count()==prior+1,"one actual Rapier step")
		if session.bridge.manual_step_count()!=prior+1:break
		var row: Dictionary = session.measured.duplicate(true);row["step"]=index;row["after_step"]=session.read();row["elapsed_us"]=Time.get_ticks_usec()-started
		if session.stage_trace:
			check(int(row.ordinary_stage_calls)<=1,"bounded ordinary observation")
			if row.ordinary_stage.observed:
				var mid: Dictionary = row.ordinary_stage.state
				check(int(row.ordinary_stage_calls)==1 and mid.manual_step==prior and row.before.manual_step==prior and row.after_application.manual_step==prior,"no physics step between application stages")
				check(mid.body_rid==report.body_rid and mid.physics_epoch==row.before.physics_epoch and mid.generation==row.before.generation,"midpoint same authoritative body/session")
				if not row.ordinary_stage.receipt.get("accepted",false):check(mid.bits==row.before.bits,"refused ordinary stage is mutation-free")
				if not row.response_is_new or not row.response.get("accepted",false):
					if not row.response.get("failed",false):check(mid.bits==row.after_application.bits,"disabled or refused Sand is mutation-free")
			else:check(int(row.ordinary_stage_calls)==0 and row.before.bits==row.after_application.bits,"unobserved ordinary stage does not reuse held work")
		if compact_evidence:
			# Deltas above and final complete metrics retain every attempt/refusal;
			# omit two redundant cumulative dictionaries from each serialized frame.
			row.erase("metrics_before");row.erase("metrics_after")
		report.steps.append(plain(row))
	var final: Dictionary = await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128))
	check(final.get("aggregate_owned")==expected and final.get("native_source_members")==0,"final exclusive payload ownership")
	check(final.get("members")==session.source_receipt.members,"all final member tuples preserved")
	check(report.steps.size()==steps,"complete registered observation coverage")
	report["final_native"]=census(final);report["metrics"]=session.coupling_metrics();report["checks"]=checks;report["failures"]=failures
	session.close();await process_frame
	if FileAccess.file_exists(output):printerr("SOL_STRUCTURE refuses evidence overwrite");quit(1);return
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"evidence output writable")
	report["checks"]=checks;report["failures"]=failures
	if file==null:quit(1);return
	# Explicit full-precision decimal serialization for native scalar witnesses;
	# body-state bit envelopes remain the lossless independent measurement.
	file.store_string(JSON.stringify(plain(report),"",true,true));file.flush()
	var write_error: Error = file.get_error();file.close()
	if write_error!=OK:printerr("SOL_STRUCTURE evidence write failed ",write_error);quit(1);return
	print("SOL_STRUCTURE checks=",checks," failures=",failures.size()," steps=",report.steps.size());quit(int(not failures.is_empty()))
