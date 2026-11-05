extends SceneTree

# Real authored rigs, one native owner and a permanently private Rapier space.
# 001--003 are immutable historical experiments; this is a distinct campaign.
const Session = preload("res://scripts/physical_actor_session.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const REGISTRATION = "res://tests/fixtures/la_physical/registration-v2.json"
const DAM = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var failures: Array[String] = []
var checks: int = 0
var registration: Dictionary
var checked: Dictionary

func _initialize() -> void: run.call_deferred()

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:
		failures.append(reason)
		push_error("LA_PHYSICAL: "+reason)

func plain(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Transform2D: return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value: out[str(key)]=plain(value[key])
		return out
	if value is Array or value is PackedFloat64Array or value is PackedFloat32Array or value is PackedInt32Array:
		var out: Array = []
		for item: Variant in value: out.append(plain(item))
		return out
	return value

func body_state(body: RigidBody2D) -> Dictionary:
	var direct := PhysicsServer2D.body_get_direct_state(body.get_rid())
	var mass: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_MASS)
	var inertia: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	return {"pose":direct.transform,"velocity":direct.linear_velocity,"omega":direct.angular_velocity,
		"mass":mass,"inertia":inertia,"kinetic":0.5*mass*direct.linear_velocity.length_squared()+0.5*inertia*direct.angular_velocity*direct.angular_velocity,
		"potential":-mass*body.gravity_scale*float(ProjectSettings.get_setting("physics/2d/default_gravity"))*direct.transform.origin.y}

func rectangle_bounds(rects: Array, angle: float) -> Rect2:
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for rect: Dictionary in rects:
		for sign_value: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var point: Vector2 = (rect.center+rect.size*sign_value*0.5).rotated(angle)
			low=low.min(point); high=high.max(point)
	return Rect2(low,high-low)

func actor(model: String, index: int, mode: String, extent: int) -> Dictionary:
	return {"model":model,"instance_id":index+1,"position":Vector2(128+index*56,100),
		"canvas_extent":Vector2i(extent,extent),"producer":"passive" if model=="reference_barrel" else "human",
		"workbench_options":{"response":mode,"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
			"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}}

func save_payload(preparer: Variant, world: Variant, path: String) -> Dictionary:
	var bytes: PackedByteArray = preparer.export_physical_state(world)
	check(not bytes.is_empty(),"authoritative CYPS capture: "+str(preparer.get_last_error()))
	var file := FileAccess.open(path,FileAccess.WRITE)
	check(file!=null,"CYPS evidence writable")
	if file!=null: file.store_buffer(bytes)
	return {"path":path,"bytes":bytes.size(),"sha256":FileAccess.get_sha256(path)}

func emit_count(world: Variant, x: int, y: int, radius: int, material: int) -> int:
	var empty: Array[Vector2i] = []
	for dy: int in range(-radius,radius+1):
		for dx: int in range(-radius,radius+1):
			if dx*dx+dy*dy<=radius*radius and world.material_at(x+dx,y+dy)==0: empty.append(Vector2i(x+dx,y+dy))
	world.emit_disc(x,y,radius,material)
	var inserted: int = 0
	for point: Vector2i in empty:
		if world.material_at(point.x,point.y)==material: inserted+=1
	return inserted

func observation(world: Variant, body: RigidBody2D, rects: Array, extent: int) -> Dictionary:
	var pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	var bounds: Rect2 = rectangle_bounds(rects,pose.get_rotation())
	var origin := Vector2i(maxi(0,floori(pose.origin.x+bounds.position.x)-2),maxi(0,floori(pose.origin.y+bounds.position.y)-2))
	var size := Vector2i(mini(extent-origin.x,ceili(bounds.size.x)+6),mini(extent-origin.y,ceili(bounds.size.y)+6))
	if size.x<=0 or size.y<=0: return {"outside":true,"pose":plain(pose)}
	var snap: Dictionary = world.diagnostic_snapshot(origin,size,false)
	var runs: Array = []
	var previous: int = -1
	var count: int = 0
	for material: int in snap.cells:
		if material!=previous:
			if count>0: runs.append([previous,count])
			previous=material; count=0
		count+=1
	if count>0: runs.append([previous,count])
	return {"origin":plain(origin),"size":plain(size),"material_runs":runs,"native_hash":snap.hash,"pose":plain(pose)}

func episode(spec: Dictionary, arm: String, workers: int, repeat: int, output: String) -> void:
	var baseline: String = "LA-SELECTIVE" if arm.begins_with("LA-SELECTIVE-LIVE-PASSIVE") else arm
	var initial_failures: int = failures.size()
	var extent: int = int(spec.get("extent",512))
	var viewport := SubViewport.new()
	viewport.world_2d=World2D.new(); viewport.size=Vector2i(2,2)
	viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var session := Session.new()
	viewport.add_child(session)
	var definitions: Array = []
	for index: int in spec.models.size(): definitions.append(actor(spec.models[index],index,baseline,extent))
	check(session.configure(definitions,viewport.world_2d.space,1),"actual authored session: "+str(session.last_error))
	if not session.active(): viewport.free(); return
	var application_variant: String = "passive-live-on-change-v2" if arm=="LA-SELECTIVE-LIVE-PASSIVE-GATED" else ("passive-live-v1" if arm=="LA-SELECTIVE-LIVE-PASSIVE" else "baseline")
	check(session.bridge.configure_application_variant(application_variant),"trajectory application variant")
	var bodies: Array[RigidBody2D] = session.bodies()
	var geometries: Array = []
	var authored: Array = []
	var gravity_scales: Array = []
	for index: int in bodies.size():
		var body: RigidBody2D = bodies[index]
		var rects: Array = session._rigs[index].collision_rects()
		geometries.append(rects)
		var angle: float = float(spec.get("angle",0.0))
		var bounds: Rect2 = rectangle_bounds(rects,angle)
		var pose := Transform2D(angle,Vector2(128+index*56,128-bounds.end.y))
		body.global_transform=pose
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,pose)
		gravity_scales.append(body.gravity_scale); body.gravity_scale=0
		if spec.get("isolation",false): body.collision_layer=0; body.collision_mask=0
	# Prime the real bodies before native construction, with no force or gravity.
	session.bridge.step()
	for index: int in bodies.size():
		bodies[index].gravity_scale=gravity_scales[index]
		check(body_state(bodies[index]).velocity==Vector2.ZERO,"neutral dynamic initialization")
		if spec.has("initial_vy"):
			PhysicsServer2D.body_set_state(bodies[index].get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(0,spec.initial_vy))
		authored.append({"definition":definitions[index],"state":body_state(bodies[index]),"geometry":geometries[index],
			"layer":bodies[index].collision_layer,"mask":bodies[index].collision_mask,
			"authoring":session.workbench_actor_state(index+1)})
	session.bridge.refresh_all_states()
	var drives: Array[bool] = []
	for body: RigidBody2D in bodies: drives.append(false)
	var sample: Dictionary = session.bridge.pack_sample(drives)
	var initial_bodies: PackedFloat32Array = session.bridge.pack_body_states()
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world.diagnostic_reset({"workers":workers,"telemetry":false}),"fresh native owner")
	var preparer: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var rectangles := PackedInt32Array()
	var material: int = int(spec.get("material",2))
	var layout: String = spec.layout
	for index: int in bodies.size():
		var x: int = 128+index*56
		if layout!="arrival": rectangles.append_array(PackedInt32Array([x-24,128,48,24,2]))
		rectangles.append_array(PackedInt32Array([x-32,152,64,2,1]))
		if layout in ["banks","cage"]:
			var hull_bounds: Rect2 = rectangle_bounds(geometries[index],float(spec.get("angle",0.0)))
			var left: int = floori(x+hull_bounds.position.x)
			var right: int = ceili(x+hull_bounds.end.x)
			rectangles.append_array(PackedInt32Array([left-12,114,12,14,2,right,114,12,14,2]))
		if layout=="cage": rectangles.append_array(PackedInt32Array([x-8,104,16,3,2,x-12,108,8,20,1,x+4,108,8,20,1]))
		if layout=="wall-bed": rectangles.append_array(PackedInt32Array([x-8,110,4,18,1]))
		if layout=="arrival": rectangles.append_array(PackedInt32Array([x-3,92,6,2,material]))
		if layout=="invalid-sand": rectangles.append_array(PackedInt32Array([x-2,118,4,4,2]))
		if layout=="invalid-wall": rectangles.append_array(PackedInt32Array([x-2,118,4,4,1]))
	var sources: Array = []
	if spec.has("distributed"):
		for y: int in 8:
			for x: int in 8:
				var sx: int = 96+224*x
				var sy: int = 256+224*y
				var m: int = 2 if (x+y)%2==0 else 14
				var side: int = 12 if spec.distributed=="dense" else 6
				rectangles.append_array(PackedInt32Array([sx,sy,side,side,m,sx-4,sy+64,side+8,1,1]))
				sources.append([sx,sy,m])
	var token: int = preparer.prepare_liquid_world(world,rectangles,checked.transport.packed,PackedInt32Array(checked.definition.water_semantics),
		PackedInt32Array(),preparer.default_liquid_policy(),{"workbench_extent":Vector2i(extent,extent),"workbench_response":baseline,
		"workbench_sample":sample,"region":PackedInt32Array([0,0,extent,extent]),"seed":0,
		"intent":"exploratory","definition_hash":checked.hash,"initial_bodies":initial_bodies,"simulation_window_enabled":false})
	check(token>0 and preparer.commit_liquid_world(world,token),"native construction: "+str(preparer.get_last_error()))
	if token<=0: session.close(); viewport.free(); return
	check(session.bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())>0,"real hard terrain")
	var name: String = spec.id+"-"+arm+"-w"+str(workers)+"-r"+str(repeat)
	var report: Dictionary = {"id":name,"registration":registration.id,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"case":spec,"arm":arm,"native_mode":baseline,"requested_workers":workers,"repeat":repeat,"extent":extent,
		"authored":plain(authored),"initial_sample":plain(sample),"initial_geometry":[],"steps":[],"lifecycle":[]}
	for index: int in bodies.size(): report.initial_geometry.append(observation(world,bodies[index],geometries[index],extent))
	report.initial_payload=save_payload(preparer,world,output+"/"+name+"-initial.cyps")
	var total_controls: int = 0
	var total_control_us: int = 0
	var steps: int = registration.static_steps if spec.kind=="static" else registration.ordinary_steps
	for step: int in steps:
		var start: int = Time.get_ticks_usec()
		var before: Array = []
		var external: Array = []
		for index: int in bodies.size():
			before.append(body_state(bodies[index])); drives[index]=false
			var rid: RID = bodies[index].get_rid()
			var impulse := Vector2.ZERO
			var torque: float = 0.0
			if step==30:
				impulse=Vector2(float(spec.get("impulse",0)),0)
				torque=float(spec.get("torque_impulse",0))
			if impulse!=Vector2.ZERO: PhysicsServer2D.body_apply_central_impulse(rid,impulse); drives[index]=true
			if torque!=0: PhysicsServer2D.body_apply_torque_impulse(rid,torque); drives[index]=true
			var force: float = float(spec.get("force",0)) if step>=30 and step<150 else 0.0
			if force!=0: PhysicsServer2D.body_apply_central_force(rid,Vector2(force,0)); drives[index]=true
			external.append({"impulse":impulse,"torque_impulse":torque,"force":Vector2(force,0),
				"impulse_work":body_state(bodies[index]).kinetic-before[index].kinetic})
		if spec.get("powered",false) and step>=30 and step<150:
			check(session.submit_workbench_action(1,{"move":Vector2(0.6,-0.4),"effort":1.0,"primary":true},
				{"q":false,"e":false,"s":false,"boost":false},false),"authored pilot lease")
		session.advance(1.0/60.0)
		if spec.get("powered",false):
			sample=session.pack_workbench_sample()
		else: sample=session.bridge.pack_sample(drives)
		var sampled: Array = []
		for body: RigidBody2D in bodies: sampled.append(body_state(body))
		var emissions: int = 0
		var inserted_materials: Dictionary = {}
		if spec.get("stream",false) and step%4==0:
			inserted_materials[str(material)]=emit_count(world,128,92,1,material); emissions+=1
		if spec.get("distributed","")=="stream" and step%4==0:
			for source: Array in sources:
				var key: String = str(source[2])
				inserted_materials[key]=int(inserted_materials.get(key,0))+emit_count(world,source[0],source[1],0,source[2]); emissions+=1
		if step==int(spec.get("remove_support_step",-1)):
			report.removal_before=save_payload(preparer,world,output+"/"+name+"-removal-before.cyps")
			world.water_experiment_erase_rect(Vector2i(96,128),Vector2i(64,26))
			report.removal_after=save_payload(preparer,world,output+"/"+name+"-removal-after.cyps")
			session.bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
		var native_start: int = Time.get_ticks_usec()
		var prepared: bool = world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true)
		var preparation_us: int = Time.get_ticks_usec()-native_start
		native_start=Time.get_ticks_usec()
		var ticked: bool = world.simulation_tick() if prepared else false
		var tick_us: int = Time.get_ticks_usec()-native_start
		var response: Dictionary = world.workbench_coupling_results()
		check(prepared and ticked and response.get("valid",false) and response.get("response")==baseline,"native source/mode/healthy tick")
		if not response.get("valid",false): break
		# An explicit reversible actuator impulse changes live velocity without
		# changing sampled geometry. This is a separate registered causal case.
		if step==int(spec.get("reverse_step",-1)):
			for index: int in bodies.size():
				var current: Dictionary = body_state(bodies[index])
				var reverse: Vector2 = -2.0*current.mass*current.velocity
				PhysicsServer2D.body_apply_central_impulse(bodies[index].get_rid(),reverse)
				external[index].reversal_impulse=reverse
				external[index].reversal_work=body_state(bodies[index]).kinetic-current.kinetic
		if int(spec.get("publication_age",0))==1: session.bridge.pack_sample(drives)
		if spec.get("physical_step_before_application",false): session.bridge.step()
		var live: Array = []
		for body: RigidBody2D in bodies: live.append(body_state(body))
		if step==0:
			var c0: int = Time.get_ticks_usec()
			var invalid: Dictionary = response.duplicate(true); invalid.epoch+=1
			check(session.apply_workbench_results(999999,invalid)==0,"foreign epoch refusal")
			invalid=response.duplicate(true); invalid.rows[0].instance_id+=999
			check(session.apply_workbench_results(999999,invalid)==0,"foreign body refusal")
			total_control_us+=Time.get_ticks_usec()-c0; total_controls+=2
		var apply_start: int = Time.get_ticks_usec()
		session.apply_workbench_results(step+1,response)
		var application_us: int = Time.get_ticks_usec()-apply_start
		var application: Dictionary = session.bridge.last_application.duplicate(true)
		var after_apply: Array = []
		for body: RigidBody2D in bodies: after_apply.append(body_state(body))
		for index: int in bodies.size():
			var action: Dictionary = application.bodies[index]
			if action.has("refusal"): continue
			var predicted: Vector2 = live[index].velocity
			if predicted.x*action.correction.x<0: predicted.x=0
			if predicted.y*action.correction.y<0: predicted.y=0
			predicted+=Vector2(action.impulse)/live[index].mass
			var residual: float = predicted.distance_to(after_apply[index].velocity)
			var omega_residual: float = absf(live[index].omega+action.torque/live[index].inertia-after_apply[index].omega)
			action.velocity_residual=residual; action.omega_residual=omega_residual
			check(residual<=registration.readback_absolute_tolerance and omega_residual<=registration.readback_absolute_tolerance,"real RID applied impulse reconstruction")
			if action.get("passive_revalidation_active",false): check(float(action.get("passive_energy_accepted",0))<=1e-10,"no positive analytic passive work")
		var rapier_start: int = Time.get_ticks_usec()
		if not spec.get("physical_step_before_application",false): session.bridge.step()
		session.complete_step()
		var rapier_us: int = Time.get_ticks_usec()-rapier_start
		var after_step: Array = []
		var controllers: Array = []
		for index: int in bodies.size():
			after_step.append(body_state(bodies[index])); controllers.append(session.workbench_actor_state(index+1).controller)
		var simulation_us: int = Time.get_ticks_usec()-start
		var observer_start: int = Time.get_ticks_usec()
		var geometry: Array = []
		if extent<=512 or step%12==0 or step==steps-1:
			for index: int in bodies.size(): geometry.append(observation(world,bodies[index],geometries[index],extent))
		var statistics: Dictionary = preparer.inspect_statistics(world)
		report.steps.append(plain({"step":step,"sampled":sampled,"live_before_application":live,"before":before,
			"after_application":after_apply,"after_step":after_step,"external":external,"controllers":controllers,
			"native_response":response,"application":application,"geometry":geometry,"statistics":statistics,
			"emission_requests":emissions,"inserted_materials":inserted_materials,"preparation_us":preparation_us,"native_tick_us":tick_us,
			"application_us":application_us,"rapier_us":rapier_us,"simulation_us":simulation_us,
			"observation_us":Time.get_ticks_usec()-observer_start}))
		var c0: int = Time.get_ticks_usec()
		check(session.apply_workbench_results(step+1,response)==0 and session.bridge.last_application.refusal=="duplicate_snapshot","duplicate consumption refusal")
		total_control_us+=Time.get_ticks_usec()-c0; total_controls+=1
	report.final_payload=save_payload(preparer,world,output+"/"+name+"-final.cyps")
	report.control_application_attempts=total_controls; report.control_application_us=total_control_us
	check(report.steps.size()==steps,"complete registered observation window")
	var held: Dictionary = world.workbench_coupling_results()
	session.bridge.pack_sample(drives); session.bridge.pack_sample(drives)
	session.apply_workbench_results(999998,held)
	report.lifecycle.append(plain(session.bridge.last_application))
	check(not session.bridge.last_application.accepted,"stale observation cannot apply")
	var invalid_roster: Array = sample.bodies.duplicate(true)
	invalid_roster.append(sample.bodies[0])
	var before_refusal: String = world.get_physical_state_hash()
	check(not world.prepare_workbench_coupling(sample.states,sample.geometry,invalid_roster,sample.session,sample.epoch,true),"duplicate owner roster refusal")
	check(world.get_physical_state_hash()==before_refusal,"refused roster preserves native authority")
	check(not session.bridge.configure_application_variant("baseline"),"first-sample policy selection remains locked")
	check(world.diagnostic_reset({"workers":workers,"telemetry":false}) and world.workbench_coupling_results().is_empty(),"World reset retires coupling and arrival history")
	report.lifecycle.append({"duplicate_owner_refused":true,"native_unchanged":true,"reset_coupling_retired":true})
	var old_session: int = int(sample.session)
	session.close()
	check(session.apply_workbench_results(999999,held)==0,"retired owner cannot apply")
	report.lifecycle.append({"retired_session":old_session,"accepted":false})
	report.failures=failures.slice(initial_failures)
	var file := FileAccess.open(output+"/"+name+".json",FileAccess.WRITE)
	check(file!=null,"scientific report writable")
	if file!=null: file.store_string(JSON.stringify(plain(report)))
	viewport.free()
	print("LA_PHYSICAL_EPISODE ",name," steps=",report.steps.size()," failures=",report.failures.size())

func run() -> void:
	registration=JSON.parse_string(FileAccess.get_file_as_string(REGISTRATION))
	if registration.has("extends"):
		var inherited: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(registration.extends))
		inherited.merge(registration,true); registration=inherited
		registration.cases.append_array(registration.get("extra_cases",[]))
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var output: String = OS.get_environment("LA_PHYSICAL_OUTPUT")
	if output.is_empty(): output="user://la-physical"
	DirAccess.make_dir_recursive_absolute(output)
	var selection: PackedStringArray = OS.get_environment("LA_PHYSICAL_CASES").split(",",false)
	var workers: int = int(OS.get_environment("LA_PHYSICAL_WORKERS"))
	if workers==0: workers=1
	var repeat: int = int(OS.get_environment("LA_PHYSICAL_REPEAT"))
	for spec: Dictionary in registration.cases:
		if not selection.is_empty() and spec.id not in selection: continue
		for arm: String in registration.arms: episode(spec,arm,workers,repeat,output)
	print("LA_PHYSICAL checks=",checks," failures=",failures.size())
	quit(int(not failures.is_empty()))
