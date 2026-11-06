extends SceneTree

# Exercise the private settings through actual configured Rapier bodies. The
# paired legacy path is the control; neither arm supplies a cellular response.
const Session = preload("res://scripts/physical_actor_session.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Preferences = preload("res://scripts/flyer_preferences.gd")
const BASE_OPTIONS := {"response":"LA-SELECTIVE","budget":20.0,"mass_multiplier":1.0,
	"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}
const EMPTY_PORTS := {"q":false,"e":false,"s":false,"boost":false}
const DELTA: float = 1.0/60.0
var checks: int = 0
var failures: int = 0
var host: Node2D
var session: CyberPhysicalActorSession
var next_epoch: int = 1
var metrics: Array = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FLYER_TUNING: "+message)


func actor(model: String, id: int, position: Vector2, tuning: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var values := BASE_OPTIONS.duplicate(true)
	values.merge(options,true)
	if not tuning.is_empty(): values.customization = tuning.duplicate(true)
	return {"model":model,"instance_id":id,"position":position,"canvas_extent":Vector2i(2048,2048),
		"producer":"passive" if model=="reference_barrel" else "human","workbench_options":values}


func pair(model: String, tuning: Dictionary, options: Dictionary = {}) -> bool:
	if session != null: session.free()
	session = Session.new()
	host.add_child(session)
	var configured := session.configure([actor(model,1,Vector2(250,220)),
		actor(model,2,Vector2(500,220),tuning,options)],host.get_world_2d().space,next_epoch)
	next_epoch += 1
	check(configured,"configure paired "+model)
	return configured


func neutral(model: String) -> Dictionary:
	return Preferences.tuning_defaults(Fleet.capabilities(Fleet.index_for_id(model)))


func states() -> Array:
	var rows := []
	for rig in session._rigs:
		var body: RigidBody2D = rig.bodies()[0]
		rows.append({"velocity":PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
			"omega":float(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)),
			"force":rig._player_controller.observation().applied_force,
			"torque":rig._player_controller.observation().applied_torque,
			"impulse":rig._last_impulse,"angular_impulse":rig._last_torque_impulse,
			"mass":body.mass,"inertia":body.inertia})
	return rows


func advance(action: Dictionary, ports: Dictionary = EMPTY_PORTS) -> Array:
	# Match the workbench keyboard sampler's explicit full-effort neutral action.
	# An empty dictionary is cancellation in the session contract.
	var command := {"effort":1.0}
	command.merge(action,true)
	for id: int in [1,2]:
		check(session.submit_workbench_action(id,command,ports,false),"leased action accepted")
	session.advance(DELTA)
	session.bridge.step()
	session.complete_step()
	return states()


func motion(velocity: Vector2, angle: float = 0.0, omega: float = 0.0) -> void:
	for rig in session._rigs:
		var body: RigidBody2D = rig.bodies()[0]
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
		pose = Transform2D(angle,pose.origin)
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,pose)
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,velocity)
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,omega)
		body.transform = pose
		body.linear_velocity = velocity
		body.angular_velocity = omega
		rig._refresh_states()
	session.bridge.refresh_all_states()


func default_equivalence() -> void:
	for index: int in Fleet.count():
		var model: String = Fleet.stable_id(index)
		if not pair(model,neutral(model)): continue
		var authored := Fleet.authoring_record(index)
		var before := Fleet.definition_hash(index)
		var original_body: RigidBody2D = session._rigs[0].bodies()[0]
		var configured_body: RigidBody2D = session._rigs[1].bodies()[0]
		check(original_body.mass==configured_body.mass and original_body.inertia==configured_body.inertia
			and original_body.gravity_scale==configured_body.gravity_scale
			and original_body.angular_damp==configured_body.angular_damp and original_body.linear_damp==configured_body.linear_damp
			and original_body.physics_material_override.friction==configured_body.physics_material_override.friction,
			"neutral settings preserve physical properties "+model)
		for tick: int in range(8):
			var action := {"move":Vector2(0.4,-0.8),"trim":0.4,"primary":tick<3,
				"secondary":tick==5,"auxiliary":tick==6}
			var result := advance(action)
			check(result[0].force==result[1].force and result[0].torque==result[1].torque,
				"neutral controller preserves exact requested wrench "+model)
			check(result[0].impulse==result[1].impulse and result[0].angular_impulse==result[1].angular_impulse,
				"neutral controller preserves exact bounded delivered wrench "+model)
			check(Vector2(result[0].velocity).is_equal_approx(result[1].velocity) and is_equal_approx(result[0].omega,result[1].omega),
				"neutral actual Rapier motion matches "+model)
		check(Fleet.definition_hash(index)==before and Fleet.authoring_record(index)==authored,
			"settings never mutate authored identity "+model)


func multipliers() -> void:
	var tuning := neutral("kestrel")
	tuning.acceleration = 2.0
	if pair("kestrel",tuning):
		var result := advance({"primary":true})
		check(Vector2(result[1].force).is_equal_approx(Vector2(result[0].force)*2.0),"acceleration multiplier changes actual requested force")
		var expected: Vector2 = (Vector2(result[1].impulse)-Vector2(result[0].impulse))/float(result[0].mass)
		check((Vector2(result[1].velocity)-Vector2(result[0].velocity)).distance_to(expected)<0.00001,
			"acceleration impulse reaches actual Rapier velocity")
		metrics.append({"case":"acceleration2","rows":result})
	tuning = neutral("kestrel")
	tuning.throttle_response = 2.0
	if pair("kestrel",tuning):
		var result := advance({"primary":true})
		check(Vector2(result[1].force).is_equal_approx(Vector2(result[0].force)*2.0),"throttle response changes first physical thrust ramp")
	tuning = neutral("kestrel")
	tuning.speed = 2.0
	if pair("kestrel",tuning):
		var speed: float = session._rigs[0]._profile.speed
		motion(Vector2(0,speed*1.5))
		var result := advance({})
		check(result[1].velocity.y>result[0].velocity.y and result[0].velocity.y>speed,
			"speed setting changes soft overspeed resistance without clamping velocity")
	tuning = neutral("kestrel")
	tuning.drag = 2.0
	if pair("kestrel",tuning):
		motion(Vector2(10,0))
		var result := advance({})
		check(is_equal_approx(result[1].force.x,result[0].force.x*2.0) and result[1].velocity.x<result[0].velocity.x,
			"drag multiplier damps actual motion")
	tuning = neutral("afterglow")
	tuning.stabilization = 2.0
	if pair("afterglow",tuning):
		motion(Vector2.ZERO,0.12,0.15)
		var result := advance({})
		check(result[1].torque<result[0].torque and result[1].omega<result[0].omega,
			"stronger stabilization changes actual angular response")
	tuning = neutral("kestrel")
	tuning.turn_speed = 2.0
	tuning.turn_acceleration = 0.5
	if pair("kestrel",tuning):
		var result := advance({"move":Vector2.RIGHT})
		var rig = session._rigs[1]
		check(is_equal_approx(rig._profile.fleet_turn_speed,session._rigs[0]._profile.fleet_turn_speed*2.0)
			and is_equal_approx(result[1].torque/rig._inertias[0],10.0),"turn speed and angular acceleration both reach controller")
	tuning = neutral("kestrel")
	tuning.acceleration = 0.0
	if pair("kestrel",tuning):
		var result := advance({"primary":true})
		check(result[1].force==Vector2.ZERO and result[0].force.length_squared()>0.0,"zero acceleration disables propulsion")


func side_swap() -> void:
	var tuning := neutral("kestrel")
	tuning.swap_side_thrusters = true
	if pair("kestrel",tuning):
		var result := advance({"trim":1.0})
		check(result[0].force.x>0 and is_equal_approx(result[0].force.x,-float(result[1].force.x)),"swapped Kestrel side force reverses")
		check(is_equal_approx(result[0].velocity.x,-float(result[1].velocity.x)) and result[0].omega==result[1].omega,
			"swapped side impulse reverses actual translation without adding rotation")
		check(session._rigs[0]._player_controller.observation().side_thrust==1.0
			and session._rigs[1]._player_controller.observation().side_thrust==-1.0,"telemetry identifies actual swapped jet side")
	if pair("kestrel",tuning):
		var result := advance({"move":Vector2.RIGHT})
		check(result[0].torque==result[1].torque and result[0].omega==result[1].omega,"side swap preserves A/D turning")
	if pair("kestrel",tuning):
		var ports := EMPTY_PORTS.duplicate()
		ports.s = true
		var result := advance({"move":Vector2.DOWN},ports)
		check(result[0].force==Vector2.ZERO and result[1].force==Vector2.ZERO,"Kestrel dispenser S still does not reverse thrust")


func body_settings() -> void:
	var tuning := neutral("scooper")
	tuning.gravity = 64.0
	tuning.friction = 64.0
	tuning.angular_drag = 64.0
	if pair("scooper",tuning,{"mass_multiplier":3.0,"inertia_multiplier":2.0}):
		var a: RigidBody2D = session._rigs[0].bodies()[0]
		var b: RigidBody2D = session._rigs[1].bodies()[0]
		check(is_equal_approx(b.mass,a.mass*3.0) and is_equal_approx(b.inertia,a.inertia*6.0),"compound retains one correctly scaled mass and inertia")
		check(is_equal_approx(session._rigs[1]._gravity,500.0) and b.physics_material_override.friction==1.0 and b.angular_damp==8.0,
			"existing gravity/friction/angular-drag bounds remain explicit")
		var sample: Dictionary = session.pack_workbench_sample()
		check(sample.bodies[1].count==5 and is_equal_approx(sample.bodies[1].gravity,500.0),"compound sample reports actual bounded gravity")
		for offset: int in range(5*17,10*17,17):
			check(is_equal_approx(sample.states[offset+9],b.mass) and is_equal_approx(sample.states[offset+11],b.inertia),
				"every compound proxy shares the body's one mass and inertia")
	tuning = neutral("afterglow")
	tuning.gravity = 0.5
	if pair("afterglow",tuning):
		var result := advance({})
		check(Vector2(result[1].force).is_equal_approx(Vector2(result[0].force)*0.5),"hover compensation follows resolved body gravity")
		check(Vector2(result[0].velocity).length()<0.00001 and Vector2(result[1].velocity).length()<0.00001,
			"both actual hoverboard gravity settings balance without position or velocity assignment")
	tuning = neutral("kestrel")
	tuning.acceleration = 64.0
	tuning.turn_speed = 64.0
	tuning.turn_acceleration = 64.0
	if pair("kestrel",tuning,{"thrust_multiplier":64.0,"torque_multiplier":64.0,"boost_multiplier":8.0}):
		var ports := EMPTY_PORTS.duplicate()
		ports.boost = true
		var result := advance({"move":Vector2(1,-1),"primary":true},ports)
		check(is_equal_approx(Vector2(result[1].impulse).length(),float(result[1].mass)*Rig.MAX_IMPULSE_PER_MASS),
			"maximum customization still hits the existing linear impulse bound")
		check(is_equal_approx(absf(result[1].angular_impulse),float(result[1].inertia)*4.0),
			"maximum customization still hits the existing angular impulse bound")
		check(Vector2(result[1].force).length()*DELTA>Vector2(result[1].impulse).length()
			and absf(result[1].torque)*DELTA>absf(result[1].angular_impulse),
			"requested wrench remains distinct from the bounded delivered impulse")


func refusals() -> void:
	var options := BASE_OPTIONS.duplicate(true)
	options.customization = neutral("kestrel")
	check(Rig.valid_review_options(options),"new full customization admitted")
	for edit: Dictionary in [{"acceleration":NAN},{"acceleration":65.0},{"gravity":-1.0},{"swap_side_thrusters":1},{"q_material":10}]:
		var invalid := options.duplicate(true)
		invalid.customization.merge(edit,true)
		check(not Rig.valid_review_options(invalid),"invalid customization refuses "+str(edit))
	var missing := options.duplicate(true)
	missing.customization.erase("drag")
	check(not Rig.valid_review_options(missing),"partial tuning is not silently completed at the physical owner")
	var wrong := options.duplicate(true)
	wrong.customization = []
	check(not Rig.valid_review_options(wrong),"non-dictionary customization refuses")
	var ordinary := Session.new()
	host.add_child(ordinary)
	check(not ordinary.configure([actor("reference_barrel",1,Vector2(300,200),neutral("kestrel"))],host.get_world_2d().space,next_epoch),
		"flyer customization cannot enter the passive-barrel route")
	ordinary.free()


func run() -> void:
	host = Node2D.new()
	root.add_child(host)
	default_equivalence()
	multipliers()
	side_swap()
	body_settings()
	refusals()
	if session != null: session.free()
	host.free()
	await process_frame
	print("FLYER_TUNING "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(int(failures>0))
