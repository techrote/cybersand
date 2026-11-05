extends SceneTree

# Actual Rapier/native owner admission. Pose injection is an explicit state-
# transfer fixture; no natural travel or human gameplay acceptance is claimed.
const Session = preload("res://scripts/physical_actor_session.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Bridge = preload("res://scripts/rapier_physics_bridge.gd")
const Preferences = preload("res://scripts/flyer_preferences.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const DAM = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var checks: int = 0
var failures: Array[String] = []
var host: Node2D
var session: CyberPhysicalActorSession
var adapter: Variant
var world: Variant
var checked: Dictionary

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("WORKBENCH_ARTICULATED: "+message)

func actor(model: String, identity: int, position: Vector2) -> Dictionary:
	return {"model":model,"instance_id":identity,"position":position,"canvas_extent":Vector2i(512,512),
		"producer":"passive" if model=="reference_barrel" else "human",
		"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
			"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}}

func instantiate(definitions: Array, epoch: int) -> bool:
	if session != null: session.free()
	session = Session.new(); host.add_child(session)
	return session.configure(definitions,host.get_world_2d().space,epoch)

func candidate(sample: Dictionary, cells := PackedInt32Array()) -> int:
	return adapter.prepare_liquid_world(world,cells,checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),adapter.default_liquid_policy(),
		{"workbench_extent":Vector2i(512,512),"workbench_response":"LA-SELECTIVE","workbench_sample":sample,
		"region":PackedInt32Array([0,0,512,512]),"intent":"exploratory","definition_hash":checked.hash,
		"initial_bodies":session.bridge.pack_body_states(),"simulation_window_enabled":false})

func mixed_and_retention() -> void:
	var models: Array = ["stuntbuggy","trialsbike","acrobat","arcadelander","jetbarrel","scooper","kestrel","reference_barrel"]
	var definitions: Array = []
	for index: int in models.size():
		definitions.append(actor(models[index],100+index,Vector2(70+120*(index%4),90+150*(index/4))))
	check(Session.valid_definitions(definitions) and instantiate(definitions,5),"five players, compound flyer, second flyer and prop")
	if not session.active(): return
	# Flush actual Rapier shape/mass initialization, including custom-COM hulls,
	# before observing an applied impulse. This is a real completed physics step.
	session.bridge.step(); session.complete_step()
	var sample: Dictionary = session.pack_workbench_sample()
	check(sample.bodies.size()==31 and sample.states.size()==35*17,"31 independent owners,35 native proxies")
	var proxies: Dictionary = {}
	for index: int in sample.bodies.size():
		var member: Dictionary = sample.bodies[index]
		check(member.id==index+1 and member.part_index>=0 and member.part_index<8,"physical identity")
		for proxy: int in session.bridge.proxy_ids_for_body(index):
			check(not proxies.has(proxy) and session.bridge.physical_body_for_proxy(proxy)==index,"unique proxy/body aliases")
			proxies[proxy] = true
	var token: int = candidate(sample)
	print("ARTICULATED_PREPARE ",{"token":token,"error":adapter.get_last_error()})
	check(token>0 and adapter.commit_liquid_world(world,token),"native articulation admission beyond8bodies")
	check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true),"first live native mixed sample")
	var result: Dictionary = world.workbench_coupling_results()
	check(result.get("valid",false) and result.rows.size()==31 and result.body_limit==64 and result.actor_limit==8,"native64body/8actor limits")
	for row: Dictionary in result.get("rows",[]):
		var member: Dictionary = sample.bodies[int(row.id)-1]
		check(row.instance_id==member.instance_id and row.part_index==member.part_index,"native actor/part identity")
	# Deliberate packet perturbation isolates application identity/deduplication
	# from native response efficacy. Each independent body receives its own J.
	var application: Dictionary=result.duplicate(true)
	var before_velocity: Array[Vector2]=[]
	for body: RigidBody2D in session.bodies(): before_velocity.append(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY))
	for row: Dictionary in application.rows:
		row.impulse=Vector2(.001*int(row.id),0); row.torque=0.0; row.correction=Vector2.ZERO
	check(session.apply_workbench_results(1,application)==31,"one application per independent body")
	for index: int in session.bodies().size():
		var body: RigidBody2D=session.bodies()[index]
		var velocity: Vector2=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		check(velocity.is_equal_approx(before_velocity[index]+Vector2(.001*(index+1)/body.mass,0)),"per-body mass and impulse identity")
	check(session.apply_workbench_results(1,application)==0,"duplicate batch cannot apply a second time")
	var malformed: Dictionary = sample.duplicate(true)
	malformed.bodies[1].part_index=0
	check(candidate(malformed)<=0,"duplicate actor/part refuses")
	malformed.bodies[1].erase("part_index")
	check(candidate(malformed)<=0,"legacy missing-part default0 duplicate still refuses")
	malformed=sample.duplicate(true); malformed.bodies[0].part_index=8
	check(candidate(malformed)<=0,"ninth part refuses")
	malformed=sample.duplicate(true)
	for index: int in 9: malformed.bodies[index].instance_id=900+index
	check(candidate(malformed)<=0,"nine logical actors refuse")
	# Controlled articulation and per-part momentum must survive a reconstruction.
	for index: int in session.bodies().size():
		var body: RigidBody2D=session.bodies()[index]
		var old: Transform2D=body.global_transform
		var pose:=Transform2D(old.get_rotation()+.001*index,old.origin+Vector2(.03*index,-.02*index))
		body.global_transform=pose
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,pose)
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(index*.25,-index*.1))
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,index*.03)
	session._rigs[2]._player_controller.calculate({"grounded":false,"velocity":Vector2.ZERO,"contact_normal":Vector2.ZERO},{"primary":true},1.0/60.0)
	var captured: Array=[]
	for definition: Dictionary in definitions:
		var motion: Dictionary=session.export_workbench_motion(definition.instance_id)
		captured.append(motion.duplicate(true)); definition.retained_motion=motion; definition.position=motion.parts[0].position
	check(not captured[2].controller.air_jump,"owned controller calculation spent airborne jump")
	check(instantiate(definitions,6),"full-state reconstruction admitted")
	if not session.active(): return
	session.adopt_retained_motion()
	for index: int in definitions.size():
		var restored: Dictionary=session.export_workbench_motion(definitions[index].instance_id)
		check(restored.parts.size()==captured[index].parts.size(),"part count retained")
		for part: int in restored.parts.size():
			var a: Dictionary=restored.parts[part]; var b: Dictionary=captured[index].parts[part]
			check(a.position.is_equal_approx(b.position) and is_equal_approx(a.rotation,b.rotation),"all-part pose retained")
			check(a.linear_velocity.is_equal_approx(b.linear_velocity) and is_equal_approx(a.angular_velocity,b.angular_velocity),"all-part momentum retained")
		if captured[index].has("controller"): check(restored.controller==captured[index].controller,"controller resources retained")
	var wheel: RigidBody2D=session._rigs[0].bodies()[2]
	check(wheel.get_child(0).shape is CircleShape2D and is_equal_approx(wheel.inertia,wheel.mass*pow(wheel.get_child(0).shape.radius,2)*.5),"neutral disk inertia")

func maximum_capacity() -> void:
	var definitions: Array=[]
	for index: int in 8: definitions.append(actor("stuntbuggy",index+1,Vector2(65+120*(index%4),90+180*(index/4))))
	check(instantiate(definitions,7),"eight8part actors")
	if not session.active(): return
	var sample: Dictionary=session.pack_workbench_sample()
	check(sample.bodies.size()==64 and sample.states.size()==64*17,"existing64proxy bound")
	var token: int=candidate(sample)
	print("ARTICULATED_MAX_PREPARE ",{"token":token,"error":adapter.get_last_error()})
	check(token>0,"actual native64owner admission")
	if token>0: adapter.discard_liquid_world(world,token)

func granular_support() -> void:
	check(instantiate([actor("reference_barrel",31,Vector2(100,100))],8),"support fixture")
	if not session.active(): return
	var sample: Dictionary=session.pack_workbench_sample()
	var token: int=candidate(sample,PackedInt32Array([80,107,40,40,2]))
	print("ARTICULATED_SUPPORT_PREPARE ",{"token":token,"error":adapter.get_last_error()})
	check(token>0 and adapter.commit_liquid_world(world,token),"powder underneath body")
	check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true),"first live native support sample")
	var packet: Dictionary=world.workbench_coupling_results()
	check(packet.get("valid",false) and packet.rows[0].support.get("samples",0)>0,"native upward supported-face witness")
	session.apply_workbench_results(1,packet); session._rigs[0]._sense()
	check(session._rigs[0]._support.get("granular",false) and not session._rigs[0]._support.has("rid"),"support owns no synthetic RID")
	for step: int in 2:
		session.bridge.step(); session.complete_step()
	session._rigs[0]._sense()
	check(session._rigs[0]._support.is_empty(),"support expires without fresh publication")
	world.emit_disc(100,120,45,0)
	sample=session.pack_workbench_sample()
	check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true),"real excavation next sample")
	packet=world.workbench_coupling_results()
	check(packet.rows[0].support.is_empty(),"excavation retires native support witness")
	session.apply_workbench_results(2,packet); session._rigs[0]._sense()
	check(session._rigs[0]._support.is_empty(),"no support after excavation")
	for spec: Array in [[3,107,40],[1,107,40],[2,52,41]]:
		check(instantiate([actor("reference_barrel",31,Vector2(100,100))],9+int(spec[0])),"support negative control")
		sample=session.pack_workbench_sample()
		token=candidate(sample,PackedInt32Array([80,spec[1],40,spec[2],spec[0]]))
		check(token>0 and adapter.commit_liquid_world(world,token),"control preparation")
		check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true),"control physical sample")
		packet=world.workbench_coupling_results()
		check(packet.rows[0].support.is_empty(),"Water,hard terrain and overhead powder never grant granular grounding")

func neutral_player_parity() -> void:
	if session != null: session.free(); session=null
	for model: String in ["stuntbuggy","trialsbike","acrobat","arcadelander","jetbarrel"]:
		var data: Dictionary=Session.Equipment.definition(Session.Catalog.entry(StringName(model)),Session.Loadouts.entry(StringName(model)))
		var left_view:=SubViewport.new(); var right_view:=SubViewport.new()
		left_view.world_2d=World2D.new(); right_view.world_2d=World2D.new()
		left_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		right_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		host.add_child(left_view); host.add_child(right_view)
		var left=Rig.new(); var right=Rig.new(); left_view.add_child(left); right_view.add_child(right)
		var options: Dictionary=actor(model,1,Vector2(100,120)).workbench_options
		options.customization=Preferences.tuning_defaults()
		check(left.configure(data,Vector2(100,120))==OK and right.configure(data,Vector2(100,120),0,1,-1,options)==OK,"legacy/workbench source pair "+model)
		var bridge=Bridge.new(); var other_bridge=Bridge.new()
		check(bridge.initialize(left_view.world_2d.space,left.bodies(),left.body_sizes())==OK \
			and other_bridge.initialize(right_view.world_2d.space,right.bodies(),right.body_sizes())==OK,"paired actual Rapier owners,matched origins")
		for part: int in left.bodies().size():
			var a: RigidBody2D=left.bodies()[part]; var b: RigidBody2D=right.bodies()[part]
			check(a.mass==b.mass and a.inertia==b.inertia and a.gravity_scale==b.gravity_scale,"neutral per-part physical properties "+model)
		var command: Dictionary={"move":Vector2(.6,-1).normalized(),"aim":Vector2(1,-.5),"trim":.2,"primary":true,"secondary":false,"auxiliary":false,"effort":1.0}
		left.advance(command,1.0/60.0,true); right.advance(command,1.0/60.0,true)
		check(left._last_impulse==right._last_impulse and left._last_torque_impulse==right._last_torque_impulse,"neutral requested J/L exact "+model)
		bridge.step(); other_bridge.step(); left.refresh_observation(); right.refresh_observation()
		for part: int in left.bodies().size():
			var a: Vector2=PhysicsServer2D.body_get_state(left.bodies()[part].get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var b: Vector2=PhysicsServer2D.body_get_state(right.bodies()[part].get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			check(a.distance_to(b)<.001,"neutral real step velocity within float tolerance "+model)
		bridge.shutdown(); other_bridge.shutdown(); left_view.free(); right_view.free()

func movement_options() -> void:
	for spec: Array in [["acrobat","acceleration",2.0],["arcadelander","thrust_multiplier",2.0],["jetbarrel","thrust_multiplier",0.0],["jetbarrel","torque_multiplier",0.0]]:
		var definitions: Array=[actor(spec[0],1,Vector2(100,120)),actor(spec[0],2,Vector2(350,120))]
		for definition: Dictionary in definitions: definition.workbench_options.customization=Preferences.tuning_defaults()
		if spec[1] in ["thrust_multiplier","torque_multiplier"]: definitions[1].workbench_options[spec[1]]=spec[2]
		else: definitions[1].workbench_options.customization[spec[1]]=spec[2]
		check(instantiate(definitions,25),"movement multiplier pair "+str(spec))
		if not session.active(): continue
		var action: Dictionary={"move":Vector2.RIGHT if spec[0]=="acrobat" or spec[1]=="torque_multiplier" else Vector2.UP,"effort":1.0}
		for id: int in [1,2]: check(session.submit_workbench_action(id,action,{"q":false,"e":false,"s":false,"boost":false},false),"leased player customization")
		session.advance(1.0/60.0)
		var a=session._rigs[0]; var b=session._rigs[1]
		if spec[1]=="torque_multiplier": check(absf(a._last_torque_impulse)>0.0 and b._last_torque_impulse==0.0,"zero custom torque cancels commanded turn")
		elif float(spec[2])==0.0: check(a._last_impulse.length()>0.0 and b._last_impulse==Vector2.ZERO,"zero movement impulse multiplier")
		else: check(b._last_impulse.is_equal_approx(a._last_impulse*2.0),"effective movement multiplier doubles requested J")

func fixed_chassis() -> void:
	var definition: Dictionary=actor("jetbarrel",17,Vector2(100,100))
	definition.usable_index=22
	check(instantiate([definition],26),"fixed equipment chassis fixture")
	if not session.active(): return
	var rig=session._rigs[0]
	check(rig.release_usable() and rig.fix_usable(),"real mount release and static fixing")
	for body: RigidBody2D in session.bodies(): body.freeze=false
	session.adopt_retained_motion()
	check(rig.bodies()[1].freeze,"adoption reinstates deployed freeze after provisional blanket hold")
	var sample: Dictionary=session.pack_workbench_sample()
	var token: int=candidate(sample)
	check(token>0 and adapter.commit_liquid_world(world,token),"fixed chassis native occupancy")
	check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true),"fixed chassis sample")
	var packet: Dictionary=world.workbench_coupling_results()
	packet.rows[1].correction=Vector2(0,-.2)
	packet.rows[1].impulse=Vector2(.2,0)
	packet.rows[1].torque=.1
	var chassis: RigidBody2D=rig.bodies()[1]
	var before: Transform2D=PhysicsServer2D.body_get_state(chassis.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	session.apply_workbench_results(1,packet)
	check(session.bridge.last_application.bodies[1].get("refusal")=="fixed_body","fixed-body response recorded separately")
	check(chassis.freeze and PhysicsServer2D.body_get_state(chassis.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)==before,"correction cannot move fixed processor chassis")
	# Controlled ownership-mode transition isolates the sample fence. A real
	# pickup uses this same freeze flag after its own proximity/clearance checks.
	chassis.freeze=false
	session.apply_workbench_results(2,packet)
	check(session.bridge.last_application.bodies[1].get("refusal")=="body_mode_changed","fixed sample cannot gain authority after dynamic pickup")

func run() -> void:
	host=Node2D.new(); root.add_child(host)
	adapter=ClassDB.instantiate(&"CyberDemoBridge"); world=ClassDB.instantiate(&"CyberNativeCellWorld")
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	mixed_and_retention(); maximum_capacity(); granular_support(); neutral_player_parity(); movement_options(); fixed_chassis()
	if session!=null: session.free()
	host.free(); adapter=null; world=null
	print("WORKBENCH_ARTICULATED ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
