extends "res://tests/test_la_physical_campaign.gd"

# Test-only exact geometry adapter. The inherited scalar exporters/contract
# helpers do not construct an authored-fleet model or transfer SOL authority.
const ChamberBridge = preload("res://scripts/workbench_physics_bridge.gd")
const CHAMBER_PROFILE = "res://tests/fixtures/sol_chamber/registration.json"
const CHAMBER_SOURCE = "res://tests/fixtures/sol_chamber/source.json"
class ChamberRig extends RefCounted:
	var body: RigidBody2D
	var rectangles: Array = []
	func bodies() -> Array: return [body]
	func collision_rects() -> Array: return rectangles

func bits(values: Array) -> String:
	var raw := PackedByteArray();raw.resize(values.size()*8)
	for index: int in values.size(): raw.encode_double(index*8,float(values[index]))
	return raw.hex_encode()

func body_state(body: RigidBody2D) -> Dictionary:
	var d := PhysicsServer2D.body_get_direct_state(body.get_rid())
	var mass: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_MASS)
	var inertia: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	var v: Vector2 = d.linear_velocity;var w: float = d.angular_velocity
	return {"pose":d.transform,"pose_f64le":bits(plain(d.transform)),"velocity":v,"omega":w,
		"velocity_omega_f64le":bits([v.x,v.y,w]),"mass":mass,"inertia":inertia,
		"kinetic":0.5*mass*(float(v.x)*float(v.x)+float(v.y)*float(v.y))+0.5*inertia*w*w,
		"potential":0.0,"center_of_mass_local":d.center_of_mass_local,"rid":body.get_rid().get_id(),
		"gravity_scale":body.gravity_scale,"linear_damp":body.linear_damp,"angular_damp":body.angular_damp,
		"can_sleep":body.can_sleep,"collision_layer":body.collision_layer,"collision_mask":body.collision_mask}

func runs(values: Variant) -> Array:
	var result: Array = [];var last: int = -1;var count: int = 0
	for value: int in values:
		if value!=last:
			if count>0: result.append([last,count])
			last=value;count=0
		count+=1
	if count>0:result.append([last,count])
	return result

func chamber_episode(spec: Dictionary, mode: String, workers: int, repeat: int, output: String) -> void:
	var episode_start: int = Time.get_ticks_usec();var failure_start: int = failures.size()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHAMBER_SOURCE))
	var viewport := SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
	var body := RigidBody2D.new();var rig := ChamberRig.new();rig.body=body
	var com := Vector2(32.0+3293.0/130.0,16.0+175.0/8.0)
	body.position=com+Vector2(6,35);body.mass=registration.mass;body.inertia=registration.nominal_inertia
	body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM;body.center_of_mass=Vector2.ZERO
	body.gravity_scale=0;body.linear_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.angular_damp_mode=RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp=0;body.angular_damp=0;body.can_sleep=false;body.collision_layer=1;body.collision_mask=1
	for r: Array in registration.source_rectangles:
		var center := Vector2(r[0]+r[2]*0.5,r[1]+r[3]*0.5)-com;var size := Vector2(r[2],r[3])
		rig.rectangles.append({"center":center,"size":size})
		var collider := CollisionShape2D.new();var shape := RectangleShape2D.new();shape.size=size
		collider.shape=shape;collider.position=center;body.add_child(collider)
	viewport.add_child(body)
	var bridge := ChamberBridge.new()
	check(bridge.initialize(viewport.world_2d.space,[body],PackedVector2Array([Vector2(29,38)]))==OK,"private actual Rapier space")
	var pristine: Dictionary = body_state(body);bridge.step()
	check(body_state(body).pose==pristine.pose and body_state(body).velocity==Vector2.ZERO and body_state(body).omega==0,"neutral prime preserves pristine input")
	check(bridge.configure_instances([{"instance_id":520,"workbench_options":{"response":mode,"budget":20.0}}],[rig],1)==OK,"one body six-proxy roster")
	check(bridge.configure_application_variant("baseline"),"registered baseline application")
	var sample: Dictionary = bridge.pack_sample([false])
	var initial: PackedFloat32Array = bridge.pack_body_states()
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world.diagnostic_reset({"workers":workers,"telemetry":false}),"fresh exclusive native owner")
	var preparer: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var token: int = preparer.prepare_liquid_world(world,material_rectangles(spec,source),checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),preparer.default_liquid_policy(),
		{"workbench_extent":Vector2i(256,256),"workbench_response":mode,"workbench_sample":sample,
		"region":PackedInt32Array([0,0,256,256]),"seed":0,"intent":"exploratory","definition_hash":checked.hash,
		"initial_bodies":initial,"simulation_window_enabled":false})
	var committed: bool = token>0 and preparer.commit_liquid_world(world,token)
	check(committed,"exact compound constructor: "+str(preparer.get_last_error()))
	var name: String = spec.id+"-"+mode+"-w"+str(workers)+"-r"+str(repeat)
	var report: Dictionary = {"schema":"cybersand.sol-chamber.episode.v1","registration":registration.id,"id":name,
		"apparatus":"SOL-CHAMBER-001-APPARATUS-002",
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"case":spec,"mode":mode,"requested_workers":workers,"repeat":repeat,
		"geometry":rig.rectangles,"geometry_source_sha256":FileAccess.get_sha256(CHAMBER_SOURCE),"initial_sample":sample,
		"nominal_inertia":registration.nominal_inertia,"pristine":pristine,"steps":[],"constructed":committed,
		"scope":"exact520 geometry surrogate; no native RedBrick aggregate or originalSOL authority"}
	report.physics_tick_rate=ProjectSettings.get_setting("physics/common/physics_ticks_per_second",60)
	report.fixed_delta=bridge.fixed_delta()
	check(int(report.physics_tick_rate)==60 and report.fixed_delta==1.0/60.0,"registered actual cadence")
	if committed:
		check(bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())>0,"real hard Wall collision bodies")
		report.construction_receipt=world.get_applied_liquid_construction_receipt()
		report.initial=census(world,body,"initial")
		report.initial_payload=save_payload(preparer,world,output+"/"+name+"-initial.cyps")
		report.actual_shapes=[]
		for index: int in PhysicsServer2D.body_get_shape_count(body.get_rid()):
			var shape_rid: RID = PhysicsServer2D.body_get_shape(body.get_rid(),index)
			report.actual_shapes.append({"transform":PhysicsServer2D.body_get_shape_transform(body.get_rid(),index),"data":PhysicsServer2D.shape_get_data(shape_rid)})
		check(report.actual_shapes.size()==6,"six actual shapes on one Rapier body")
		run_chamber_steps(spec,mode,body,bridge,world,preparer,report,output,name)
		check(report.steps.size()==int(registration.steps),"outer episode complete despite script interruption")
		report.final=census(world,body,"final")
		report.final_payload=null if world.has_failed() else save_payload(preparer,world,output+"/"+name+"-final.cyps")
	report.failures=failures.slice(failure_start);report.episode_us=Time.get_ticks_usec()-episode_start
	var path: String = output+"/"+name+".json";check(not FileAccess.file_exists(path),"preserve prior episode")
	if FileAccess.file_exists(path):bridge.shutdown();viewport.free();return
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(plain(report)));file.close()
	bridge.shutdown();viewport.free()
	print("SOL_CHAMBER_EPISODE ",name," steps=",report.steps.size()," failures=",report.failures.size())

func run_chamber_steps(spec: Dictionary, mode: String, body: RigidBody2D, bridge: Variant,
		world: Variant, preparer: Variant, report: Dictionary, output: String, name: String) -> void:
	report.geometry_f64le=bits(Array(report.initial_sample.geometry))
	for step: int in int(registration.steps):
		var start: int = Time.get_ticks_usec();var boundaries: Array = []
		var before: Dictionary = body_state(body)
		var force := Vector2(60.0*float(registration.mass),0) if spec.driven and step>=30 and step<150 else Vector2.ZERO
		if force!=Vector2.ZERO:PhysicsServer2D.body_apply_central_force(body.get_rid(),force)
		var after_external: Dictionary = body_state(body)
		var drives: Array[bool] = [force!=Vector2.ZERO]
		var sample: Dictionary = bridge.pack_sample(drives)
		boundaries.append(census(world,body,"before_preparation"))
		var timer: int = Time.get_ticks_usec()
		var prepared: bool = world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true)
		var preparation_us: int = Time.get_ticks_usec()-timer
		boundaries.append(census(world,body,"after_reconciliation"))
		timer=Time.get_ticks_usec();var ticked: bool = world.simulation_tick() if prepared else false
		var native_us: int = Time.get_ticks_usec()-timer
		boundaries.append(census(world,body,"after_native_tick"))
		var response: Dictionary = coupling_result(world)
		var record: Dictionary = {"step":step,"sample":sample,"boundaries":boundaries,"prepared":prepared,"ticked":ticked,
			"response":response,"force":force,"before":before,"preparation_us":preparation_us,"native_tick_us":native_us}
		record.after_external_drive=after_external
		record.external_api_kinetic_delta=float(after_external.kinetic)-float(before.kinetic)
		if not prepared or not ticked or not response.get("valid",false):
			check(false,"native failed/refused; no physical clearance claim")
			record.terminal="native_failed_or_refused";report.steps.append(record);break
		check(response.get("response")==mode,"applied native response selector")
		var live: Dictionary = body_state(body)
		record.live_before_application=live
		record.preapplication_kinetic_delta=float(live.kinetic)-float(after_external.kinetic)
		timer=Time.get_ticks_usec();bridge.apply_packet(step+1,response)
		record.application_us=Time.get_ticks_usec()-timer
		record.application=bridge.last_application.duplicate(true)
		record.after_application=body_state(body)
		boundaries.append(census(world,body,"after_application"))
		if not record.application.get("accepted",false):
			check(false,"application refused; no physical clearance claim")
			record.terminal="application_refused";report.steps.append(record);break
		var action: Dictionary = record.application.bodies[0]
		var predicted: Vector2 = live.velocity
		if predicted.x*action.correction.x<0:predicted.x=0
		if predicted.y*action.correction.y<0:predicted.y=0
		predicted+=Vector2(action.impulse)/float(live.mass)
		record.velocity_residual=predicted.distance_to(record.after_application.velocity)
		record.omega_residual=absf(float(live.omega)+float(action.torque)/float(live.inertia)-float(record.after_application.omega))
		check(record.velocity_residual<=1e-5 and record.omega_residual<=1e-5,"existing actual RID readback tolerance")
		record.candidate_kinetic_delta=float(record.after_application.kinetic)-float(live.kinetic)
		timer=Time.get_ticks_usec();bridge.step();record.rapier_us=Time.get_ticks_usec()-timer
		record.after_step=body_state(body)
		boundaries.append(census(world,body,"after_rapier_step"))
		record.force_endpoint_work_estimate=force.dot(record.after_step.pose.origin-record.after_application.pose.origin)
		record.force_impulse=force/60.0
		record.counterfactual_second_force_increment=(force/60.0).dot(record.after_application.velocity)+0.5*(float(force.x/60.0)*float(force.x/60.0))/float(before.mass)
		record.rapier_kinetic_delta=float(record.after_step.kinetic)-float(record.after_application.kinetic)
		record.energy_scope="Pinned Rapier force API is an immediate Fdt impulse: external_api_kinetic_delta is observed drive work; endpoint Fdx and a hypothetical second force increment are diagnostics only. Hard-contact and native grain energy not independently reconstructed"
		record.statistics=copied_statistics(preparer,world)
		record.observer_us=0
		for boundary: Dictionary in boundaries:record.observer_us+=int(boundary.observer_us)
		record.export_us=0
		if step in [0,29,30,149,150,179]:
			timer=Time.get_ticks_usec();record.payload=save_payload(preparer,world,output+"/"+name+"-s"+str(step)+".cyps")
			record.export_us=Time.get_ticks_usec()-timer
		record.elapsed_us=Time.get_ticks_usec()-start
		report.steps.append(record)
	check(report.steps.size()==int(registration.steps),"full registered step coverage")

func coupling_result(world: Variant) -> Dictionary:
	return world.workbench_coupling_results()

func copied_statistics(preparer: Variant, world: Variant) -> Dictionary:
	return preparer.inspect_statistics(world)

func run() -> void:
	registration=JSON.parse_string(FileAccess.get_file_as_string(CHAMBER_PROFILE))
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var output: String = OS.get_environment("SOL_CHAMBER_OUTPUT")
	check(not output.is_empty(),"explicit retained output directory")
	if output.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var selection: String = OS.get_environment("SOL_CHAMBER_CASE")
	var arm: String = OS.get_environment("SOL_CHAMBER_ARM")
	var workers: int = int(OS.get_environment("SOL_CHAMBER_WORKERS"))
	var repeat: int = int(OS.get_environment("SOL_CHAMBER_REPEAT"))
	check(selection in registration.cases.map(func(c: Dictionary) -> String:return c.id) and arm in registration.arms and workers in [1,4],"registered execution coordinates")
	if not failures.is_empty():quit(1);return
	for spec: Dictionary in registration.cases:
		if spec.id==selection:chamber_episode(spec,arm,workers,repeat,output)
	print("SOL_CHAMBER checks=",checks," failures=",failures.size())
	quit(int(not failures.is_empty()))

func census(world: Variant, body: RigidBody2D, boundary: String) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	var roi: Array = registration.observation_roi
	var origin := Vector2i(roi[0],roi[1]);var size := Vector2i(roi[2],roi[3])
	var snap: Dictionary = world.diagnostic_snapshot(origin,size,false)
	var mask := PackedInt32Array();mask.resize(size.x*size.y)
	for y: int in size.y:
		for x: int in size.x:mask[y*size.x+x]=int(world.rigid_body_id_at(origin.x+x,origin.y+y))
	return {"boundary":boundary,"state":body_state(body),"origin":origin,"size":size,
		"material_runs":runs(snap.cells),"mask_runs":runs(mask),"native_hash":snap.hash,
		"native_tick":snap.completed_ticks,"attempted_tick":snap.attempted_ticks,"failed":snap.failed,
		"revision":world.get_revision(),"world_instance":world.get_instance_id(),
		"counts_in_roi":snap.counts,"sum_y_in_roi":snap.sum_y,"chunks":snap.chunks,"cores":snap.cores,
		"observer_us":Time.get_ticks_usec()-start}

func material_rectangles(spec: Dictionary, source: Dictionary) -> PackedInt32Array:
	var occupied: Dictionary = {}
	for m: Array in source.member_tuples:occupied[Vector2i(m[0]+6,m[1]+35)]=true
	var result := PackedInt32Array([48,60,49,1,1,48,101,49,1,1,48,61,1,40,1,96,61,1,40,1])
	var count: int = 0
	for y: int in range(61,101):
		for x: int in range(49,96):
			if occupied.has(Vector2i(x,y)) or (spec.open and x>=82):continue
			result.append_array(PackedInt32Array([x,y,1,1,2]));count+=1
	check(count==int(registration.stored_sand_counts["open" if spec.open else "closed"]),"registered pristine Sand count")
	return result
