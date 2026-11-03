extends SceneTree

# Actual controller/Rapier delivery, isolated from material/physics stepping.
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
var checks: int = 0
var failures: int = 0

func _init() -> void: call_deferred("_run")

func check(value: bool, reason: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("Fleet side jets: "+reason)

func _setup(runtime, index: int, angle: float = 0.0, force_factor: float = 1.0):
	var options: Dictionary = {"response":"LA","budget":20.0,"mass_multiplier":1.0,
		"inertia_multiplier":1.0,"thrust_multiplier":force_factor,"torque_multiplier":1.0}
	if not runtime.configure_review_fleet(index,options):
		check(false,"fresh craft "+str(index)+": "+runtime.last_error)
		return null
	var rig = runtime._arena.session._rigs[0]
	var body: RigidBody2D = runtime._arena.session.bodies()[0]
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(angle,Vector2(178,264)))
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2.ZERO)
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,0.0)
	return rig

func _action(move: Vector2 = Vector2.ZERO, trim: float = 0.0, primary: bool = false) -> Dictionary:
	return {"move":move,"aim":Vector2.UP,"trim":trim,"primary":primary,
		"secondary":false,"auxiliary":false}

func _run() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	await process_frame
	for index: int in [1,2,4]:
		for angle: float in [0.0,PI*.5]:
			for direction: float in [-1.0,1.0]:
				var rig = _setup(runtime,index,angle)
				if rig==null: continue
				var body: RigidBody2D = runtime._arena.session.bodies()[0]
				rig.advance(_action(Vector2.ZERO,direction),1.0/60.0,true)
				var observation: Dictionary = rig._player_controller.observation()
				var force: Vector2 = observation.applied_force
				var side: Vector2 = Vector2.RIGHT.rotated(angle)
				check(force.dot(side)*direction>0.0,"Q/E pushes in selected body-local side")
				check(absf(force.cross(side))<.0001,"side thrust rotates with body")
				check(observation.side_thrust==direction and observation.thrust==0.0,"side command is independent of main throttle")
				check(observation.applied_torque==0.0 and rig._last_torque_impulse==0.0,"side keys do not double as yaw")
				check(force.length()<=float(Fleet.ROWS[index][8])+.00001,"default force ceiling retained")
				var delivered: Vector2 = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
				check(delivered.distance_to(force/body.mass/60.0)<.0001,"actual backend side delta-v closes")
				check(is_equal_approx(rig._profile.fleet_force,float(Fleet.ROWS[index][8])) and is_equal_approx(rig._profile.fleet_torque,float(Fleet.ROWS[index][9])),"side jets do not increase authored caps")
		for factor: float in [0.0,.01,1.0]:
			var rig = _setup(runtime,index,.4,factor)
			if rig==null: continue
			rig.advance(_action(Vector2.ZERO,1.0,true),1.0/60.0,true)
			var observation: Dictionary = rig._player_controller.observation()
			check(Vector2(observation.applied_force).length()<=float(Fleet.ROWS[index][8])*factor+.00001,"main and side thrust share one ceiling")
			if factor==0.0:
				check(observation.applied_force==Vector2.ZERO and rig._last_impulse==Vector2.ZERO,"zero force ceiling disables side and main thrust")
			rig.cancel()
			check(rig._player_controller.observation().side_thrust==0.0,"cancel retires side request")
	for index: int in [0,1,2,4,5,6]:
		var rig = _setup(runtime,index)
		if rig==null: continue
		rig.advance(_action(Vector2.ZERO,1.0),1.0/60.0,true)
		check(rig._last_torque_impulse==0.0,"Q/E cannot yaw dispenser or side-jet craft")
		if index in [0,5,6]:
			check(rig._last_impulse==Vector2.ZERO,"dispenser Q/E does not add hidden thrust")
		rig = _setup(runtime,index)
		rig.advance(_action(Vector2(.8,0)),1.0/60.0,true)
		check(rig._last_torque_impulse>0.0,"A/D still supplies yaw")
	var kestrel = _setup(runtime,2)
	kestrel.advance(_action(Vector2.DOWN),1.0/60.0,true)
	check(kestrel._player_controller.observation().thrust==0.0 and kestrel._last_impulse==Vector2.ZERO,"Kestrel S dispenser does not also reverse thrust")
	for index: int in [0,1,4,5,6]:
		var rig = _setup(runtime,index)
		rig.advance(_action(Vector2.DOWN),1.0/60.0,true)
		check(Vector2(rig._player_controller.observation().applied_force).y>0.0,"other flyers retain S reverse thrust")
	for direction: float in [-1.0,1.0]:
		var board = _setup(runtime,3)
		board.advance(_action(Vector2.ZERO,direction),1.0/60.0,true)
		check(board._last_torque_impulse*direction>0.0,"hoverboard Q/E tilt preserved")
	check("Side" not in Fleet.controls(0) and "Acid" in Fleet.controls(0),"Midge controls name its dispensers")
	check("Gunpowder" in Fleet.controls(2) and "Rotate" in Fleet.controls(2),"Kestrel controls name new S slot and A/D")
	runtime.close()
	runtime.queue_free()
	await process_frame
	print("GCR_FLEET_SIDE_THRUSTERS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual side-controller/force-budget delivery; no material-law acceptance"}))
	quit(0 if failures==0 else 1)
