extends SceneTree

# Opt-in scientific fixture. All physical calls are serialized on the main
# thread; native World retains its own pool. No public fleet or solver changes.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Bridge = preload("res://scripts/workbench_physics_bridge.gd")
const PROFILE = "res://tests/fixtures/la_selective/registration.json"
const DAM = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
class FixtureRig extends RefCounted:
	var rectangles: Array = []
	var body: RigidBody2D
	func collision_rects() -> Array: return rectangles
	func bodies() -> Array: return [body]

var failures: Array[String] = []
var checks: int = 0
var profile: Dictionary
var checked: Dictionary
var reports: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error(reason)

func plain(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Transform2D: return [plain(value.x),plain(value.y),plain(value.origin)]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = plain(value[key])
		return result
	if value is Array or value is PackedFloat64Array or value is PackedInt32Array:
		var result: Array = []
		for item: Variant in value: result.append(plain(item))
		return result
	return value

func state(body: RigidBody2D) -> Dictionary:
	var d := PhysicsServer2D.body_get_direct_state(body.get_rid())
	var m: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_MASS)
	var inertia: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	return {"pose":d.transform,"velocity":d.linear_velocity,"omega":d.angular_velocity,
		"mass":m,"inertia":inertia,"kinetic":0.5*m*d.linear_velocity.length_squared()+0.5*inertia*d.angular_velocity*d.angular_velocity,
		"potential":0.0}

# Independent Sutherland-Hodgman clipping, never candidate contact admission.
func clip(poly: Array, axis: int, bound: float, sign_value: float) -> Array:
	var out: Array = []
	if poly.is_empty(): return out
	var previous: Vector2 = poly.back()
	var prior: float = sign_value*(previous[axis]-bound)
	for point: Vector2 in poly:
		var next: float = sign_value*(point[axis]-bound)
		if (next>=0) != (prior>=0): out.append(previous+(point-previous)*(prior/(prior-next)))
		if next>=0: out.append(point)
		previous=point
		prior=next
	return out

func area(poly: Array) -> float:
	var result: float = 0.0
	for i: int in poly.size(): result += Vector2(poly[i]).cross(poly[(i+1)%poly.size()])
	return absf(result)*0.5

func geometry(snapshot: Dictionary, rectangles: Array, pose: Transform2D, material: int) -> Dictionary:
	var total: float = 0.0
	var depth: float = 0.0
	var hard: float = 0.0
	var foreign: float = 0.0
	var union: Array = []
	var touched: Dictionary = {}
	for rect: Dictionary in rectangles:
		var poly: Array = []
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			poly.append(pose*(rect.center+corner*rect.size*0.5))
		union.append(plain(poly))
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for point: Vector2 in poly:
			low=low.min(point)
			high=high.max(point)
		for y: int in range(maxi(0,floori(low.y)),mini(256,ceili(high.y))):
			for x: int in range(maxi(0,floori(low.x)),mini(256,ceili(high.x))):
				var m: int = snapshot.cells[y*256+x]
				if m==0: continue
				var clipped: Array = clip(clip(clip(clip(poly,0,x,1),0,x+1,-1),1,y,1),1,y+1,-1)
				var overlap: float = area(clipped)
				if overlap<=1e-9: continue
				touched[str(m)]=int(touched.get(str(m),0))+1
				if m==1: hard+=overlap
				elif m!=material: foreign+=overlap
				if m!=material: continue
				total+=overlap
				var minimum: float = INF
				var cell: Array = [Vector2(x,y),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]
				for axis: Vector2 in [Vector2.RIGHT,Vector2.DOWN,pose.x,pose.y]:
					var a0: float = INF
					var a1: float = -INF
					var b0: float = INF
					var b1: float = -INF
					for p: Vector2 in poly:
						a0=minf(a0,p.dot(axis)); a1=maxf(a1,p.dot(axis))
					for p: Vector2 in cell:
						b0=minf(b0,p.dot(axis)); b1=maxf(b1,p.dot(axis))
					minimum=minf(minimum,minf(a1-b0,b1-a0))
				depth=maxf(depth,minimum)
	return {"material_area":total,"max_proxy_cell_sat_depth":depth,"hard_Wall_area":hard,
		"foreign_area":foreign,"contacted_material_counts":touched,"proxy_union":union}

func snapshot(world: Variant) -> Dictionary:
	return world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(256,256),false)

func inventory(s: Dictionary) -> Dictionary:
	return {"counts":s.counts,"sum_y":s.sum_y,"water_mass":s.water_mass,"native_state_hash":s.hash,
		"stored_material_hex_sha256":s.cells.hex_encode().sha256_text(),"tick":s.completed_ticks,
		"attempted_tick":s.attempted_ticks,"failed":s.failed,"chunks":s.chunks,"cores":s.cores}

func episode(spec: Dictionary, mode: String, workers: int) -> void:
	var host := Node2D.new()
	root.add_child(host)
	var rig := FixtureRig.new()
	var body := RigidBody2D.new()
	rig.body=body
	var mass: float = 5.0
	var inertia: float = mass*(8.0*8.0+14.0*14.0)/12.0
	if spec.shape=="SOL-union-surrogate":
		mass=profile.source_mass
		inertia=profile.source_inertia
		var source_com := Vector2(profile.source_com[0],profile.source_com[1])
		for r: Array in profile.source_rectangles:
			rig.rectangles.append({"center":Vector2(r[0]+r[2]*0.5,r[1]+r[3]*0.5)-source_com,"size":Vector2(r[2],r[3])})
	else: rig.rectangles=[{"center":Vector2.ZERO,"size":Vector2(8,14)}]
	body.mass=mass
	body.inertia=inertia
	body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass=Vector2.ZERO
	body.gravity_scale=0
	body.linear_damp_mode=RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp_mode=RigidBody2D.DAMP_MODE_REPLACE
	body.linear_damp=0
	body.angular_damp=0
	body.can_sleep=false
	body.collision_layer=0
	body.collision_mask=0
	body.position=Vector2(spec.origin[0],spec.origin[1])
	body.rotation=spec.angle
	for rect: Dictionary in rig.rectangles:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size=rect.size
		collider.shape=shape
		collider.position=rect.center
		body.add_child(collider)
	host.add_child(body)
	var physics := Bridge.new()
	check(physics.initialize(host.get_world_2d().space,[body],PackedVector2Array([Vector2(40,50)]))==OK,"actual Rapier initialize")
	check(physics.configure_instances([{"instance_id":42,"workbench_options":{"response":mode,"budget":20.0}}],[rig],1)==OK,"one body / compound ownership")
	var packet: Dictionary = physics.pack_sample([false])
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world.diagnostic_reset({"workers":workers,"telemetry":false}),"fresh diagnostic owner")
	var preparer: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var cells := PackedInt32Array()
	for rect: Array in spec.rectangles: cells.append_array(PackedInt32Array(rect))
	var initial := PackedFloat32Array([1,body.position.x,body.position.y,body.rotation,40,50,0,0,0,mass,1])
	var token: int = preparer.prepare_liquid_world(world,cells,checked.transport.packed,PackedInt32Array(checked.definition.water_semantics),
		PackedInt32Array(),preparer.default_liquid_policy(),{"workbench_extent":Vector2i(256,256),"workbench_response":mode,
		"workbench_sample":packet,"region":PackedInt32Array([0,0,256,256]),"seed":0,
		"intent":"exploratory","definition_hash":checked.hash,"initial_bodies":initial,"simulation_window_enabled":false})
	check(token>0 and preparer.commit_liquid_world(world,token),"native construction: "+str(preparer.get_last_error()))
	if token<=0:
		physics.shutdown(); host.free(); return
	var report: Dictionary = {"case":spec.id,"mode":mode,"workers":workers,"session":packet.session,"epoch":1,
		"geometry":plain(rig.rectangles),"initial_input":plain(packet),"initial_inventory":inventory(snapshot(world)),
		"initial_body":plain(state(body)),"steps":[],"qualification":"#394 common-transform surrogate; no native SOL handoff"}
	var elapsed_owner: int = 0
	var elapsed_application: int = 0
	for step: int in profile.steps:
		var before: Dictionary = state(body)
		var challenge_before: float = before.kinetic
		if spec.get("challenge",false) and step==profile.challenge.step:
			PhysicsServer2D.body_apply_central_impulse(body.get_rid(),Vector2(3,1))
			PhysicsServer2D.body_apply_torque_impulse(body.get_rid(),0.5)
		packet=physics.pack_sample([false])
		var sampled: Dictionary = state(body)
		var start: int = Time.get_ticks_usec()
		var prepared: bool = world.prepare_workbench_coupling(packet.states,packet.geometry,packet.bodies,packet.session,packet.epoch,false)
		var ticked: bool = world.simulation_tick() if prepared else false
		var response: Dictionary = world.workbench_coupling_results()
		var owner_us: int = Time.get_ticks_usec()-start
		elapsed_owner+=owner_us
		check(prepared and ticked and response.get("valid",false) and response.get("response")==mode,"applied native mode / healthy tick")
		if not response.get("valid",false): break
		var row: Dictionary = response.rows[0]
		# Rejected foreign-owner packets cannot consume the real sample.
		if step==0:
			var wrong: Dictionary = response.duplicate(true)
			wrong.epoch+=1
			check(physics.apply_packet(100000,wrong)==0 and physics.last_application.refusal=="owner_or_response","epoch refusal")
			wrong=response.duplicate(true)
			wrong.rows[0].instance_id+=1
			check(physics.apply_packet(100000,wrong)==0 and physics.last_application.refusal=="identity","owner refusal")
		var stored: Dictionary = snapshot(world)
		var geometry_before: Dictionary = geometry(stored,rig.rectangles,sampled.pose,spec.material)
		start=Time.get_ticks_usec()
		var applied: int = physics.apply_packet(step+1,response)
		var application_us: int = Time.get_ticks_usec()-start
		elapsed_application+=application_us
		var delivery: Dictionary = physics.last_application.duplicate(true)
		var after_application: Dictionary = state(body)
		physics.step()
		var after: Dictionary = state(body)
		var legacy: Vector2 = row.impulse-row.event_accepted-row.passive_impulse
		report.steps.append(plain({"step":step,"native_tick":world.get_tick_index(),"sample":packet.states[10],
			"packet":{"session":response.session,"epoch":response.epoch,"sample_tick":response.sample_tick,"valid":response.valid,
				"arrival_storage_bytes":response.arrival_storage_bytes,"native_mask_reserved":response.native_mask_reserved},
			"sampled_body":sampled,"before":before,"after_application":after_application,"after_step":after,
			"candidate_row":row,"legacy_residual":legacy,"legacy_torque_residual":row.torque-row.event_torque-row.passive_torque,
			"application":delivery,"nonzero_applied_bodies":applied,"owner_us":owner_us,"application_us":application_us,
			"external_challenge_work":sampled.kinetic-challenge_before,"response_energy_delta":after_application.kinetic-sampled.kinetic,
			"Rapier_step_energy_delta":after.kinetic-after_application.kinetic,
			"geometry_before_step":geometry_before,"geometry_after_step":geometry(stored,rig.rectangles,after.pose,spec.material),
			"stored_inventory":inventory(stored)}))
		if mode=="LA-EVENT-OFF": check(row.event_accepted==Vector2.ZERO and row.event_torque==0,"event-off retains zero event wrench")
		if spec.material==3: check(row.arrival_count==0,"Water excluded from arrivals")
		check(physics.apply_packet(step+1,response)==0 and physics.last_application.refusal=="duplicate_snapshot","one-use snapshot")
	report.owner_total_us=elapsed_owner
	report.application_total_us=elapsed_application
	report.final_inventory=inventory(snapshot(world))
	check(report.steps.size()==profile.steps,"complete registered observation window")
	# Prospective publication controls, after the measurement window, equal in all arms.
	packet=physics.pack_sample([false])
	check(world.prepare_workbench_coupling(packet.states,packet.geometry,packet.bodies,packet.session,packet.epoch,false),"publication control prepare")
	var held: Dictionary = world.workbench_coupling_results()
	physics.pack_sample([false])
	physics.apply_packet(1001,held)
	report.age_one=plain(physics.last_application.duplicate(true))
	physics.pack_sample([false])
	physics.apply_packet(1002,held)
	report.stale=plain(physics.last_application.duplicate(true))
	check(physics.last_application.bodies[0].get("refusal")=="age","stale publication refused")
	reports.append(report)
	physics.shutdown()
	host.free()

func run() -> void:
	profile=JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var selected_workers: int = int(OS.get_environment("LA_EXPERIMENT_WORKERS"))
	if selected_workers==0: selected_workers=1
	for spec: Dictionary in profile.cases:
		for mode: String in profile.arms: episode(spec,mode,selected_workers)
	var output: String = OS.get_environment("LA_EXPERIMENT_OUTPUT")
	if output.is_empty(): output="user://la-selective-experiment.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"evidence output writable")
	if file!=null:
		file.store_string(JSON.stringify({"profile":profile,"platform":OS.get_name(),"engine":Engine.get_version_info(),
			"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"checks":checks,"failures":failures,"episodes":reports}))
	print("LA_SELECTIVE_EXPERIMENT checks=",checks," failures=",failures.size()," episodes=",reports.size())
	quit(int(not failures.is_empty()))
