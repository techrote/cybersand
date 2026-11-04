extends SceneTree

const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Rig = preload("res://scripts/physical_actor_rig.gd")
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: call_deferred("_run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); push_error(reason); quit(1)
func options(boost: Variant = 2.0, thrust: float = 1.0) -> Dictionary:
	return {"response":"LA","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
		"thrust_multiplier":thrust,"torque_multiplier":1.0,"boost_multiplier":boost}
func delivery(rig, held: bool, action: Dictionary, velocity := Vector2.ZERO) -> Dictionary:
	rig.cancel()
	var body: RigidBody2D=rig.bodies()[0]
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0,Vector2(178,304)))
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,velocity)
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,.1)
	rig.set_review_boost_held(held)
	rig.advance(action,1.0/60.0,true)
	var observation: Dictionary=rig._player_controller.observation()
	check(rig._last_impulse.is_equal_approx(Vector2(observation.applied_force)/60.0),"actual linear impulse matches bounded controller delivery")
	check(is_equal_approx(rig._last_torque_impulse,float(observation.applied_torque)/60.0),"actual torque impulse matches controller delivery")
	return observation
func action(move: Vector2, brake: bool = false, trim: float = .6) -> Dictionary:
	return {"move":move,"aim":Vector2.UP,"effort":.5,"trim":trim,"primary":false,"secondary":brake,"auxiliary":false}
func ports(boost: bool) -> Dictionary:
	return {"q":false,"e":false,"s":false,"boost":boost}
func _run() -> void:
	var runtime=Runtime.new();root.add_child(runtime);await process_frame
	check(Rig.valid_review_options(options(1)) and Rig.valid_review_options(options(8)),"finite multiplier range endpoints admitted")
	check(runtime.configure_review_fleet(2,options()),"fresh boost authoring")
	var owner=runtime._arena
	for bad: Variant in [.99,8.01,NAN,INF,true,"2"]:
		check(not runtime.configure_review_fleet(2,options(bad)) and runtime._arena==owner,"invalid boost authoring preserves owner")
	for index: int in range(7):
		check(runtime.configure_review_fleet(index,options()),"all seven craft admit boost authoring")
		var rig=runtime._arena.session._rigs[0]
		check(rig._profile.fleet_boost_multiplier==2.0,"actual copied boost profile")
		var drive: Dictionary=action(Vector2(.2,-.2))
		var base: Dictionary=delivery(rig,false,drive)
		var boosted: Dictionary=delivery(rig,true,drive)
		check(boosted.boost_multiplier==2.0 and is_equal_approx(boosted.force_cap,base.force_cap*2),"held thrust multiplier explicitly expands current force ceiling")
		check(is_equal_approx(base.applied_torque,boosted.applied_torque),"boost never multiplies torque")
		if index==3:
			var hover: Dictionary=delivery(rig,false,action(Vector2.ZERO,false,0))
			var hover_shift: Dictionary=delivery(rig,true,action(Vector2.ZERO,false,0))
			check(Vector2(hover.applied_force).is_equal_approx(hover_shift.applied_force) and hover_shift.boost_multiplier==1.0,"Shift alone cannot multiply hoverboard antigravity")
			var expected: Vector2=Vector2(hover.applied_force)+(Vector2(base.applied_force)-Vector2(hover.applied_force))*2
			check(Vector2(boosted.applied_force).distance_to(expected)<.00001,"hoverboard scales controlled propulsion with baseline antigravity unchanged")
		else:
			check(Vector2(boosted.applied_force).distance_to(Vector2(base.applied_force)*2)<.00001,"main and applicable side propulsion scale together")
		var coast: Dictionary=delivery(rig,false,action(Vector2.ZERO,false,0),Vector2(4,2))
		var coast_shift: Dictionary=delivery(rig,true,action(Vector2.ZERO,false,0),Vector2(4,2))
		check(Vector2(coast.applied_force).is_equal_approx(coast_shift.applied_force) and coast_shift.boost_multiplier==1.0,"Shift without propulsion leaves passive drag unchanged")
		var brake: Dictionary=delivery(rig,false,action(Vector2(.2,-.2),true),Vector2(4,2))
		var brake_shift: Dictionary=delivery(rig,true,action(Vector2(.2,-.2),true),Vector2(4,2))
		check(Vector2(brake.applied_force).is_equal_approx(brake_shift.applied_force) and brake_shift.boost_multiplier==1.0 and is_equal_approx(brake.applied_torque,brake_shift.applied_torque),"Ctrl brake overrides boost without modifying its old force/torque response")
		var released: Dictionary=delivery(rig,false,drive)
		check(Vector2(released.applied_force).is_equal_approx(base.applied_force),"release returns to base thrust")
		rig.set_review_boost_held(true);rig.cancel()
		check(not rig.review_boost_held() and rig._player_controller.observation().boost_multiplier==1.0,"cancel retires held multiplier")
		check(runtime.configure_review_fleet(index,options(8,0)),"zero authored force ceiling")
		var zero: Dictionary=delivery(runtime._arena.session._rigs[0],true,drive)
		check(zero.applied_force==Vector2.ZERO and zero.force_cap==0.0,"boost cannot bypass zero authored propulsion ceiling")
	# The arena owns boost intent beside the existing action ABI and its lease.
	check(runtime.configure_review_fleet(2,options()),"fresh leased boost test")
	var arena=runtime._arena
	var view: Dictionary=arena.observation(0)
	var command: Dictionary=arena.session.make_command(view,int(view.last_sequence)+1,action(Vector2(0,-1)),2)
	check(arena.submit_review_command(command,ports(true)),"accepted leased modifier")
	check(not arena.submit_review_command(command,{"q":false,"e":false,"s":false,"boost":"yes"}),"malformed modifier refuses")
	for step: int in range(2):
		arena.step()
		check(arena.session._rigs[0]._player_controller.observation().boost_multiplier==2.0,"modifier stays within accepted lease")
	arena.step()
	check(not arena.session._rigs[0].review_boost_held() and arena.session._rigs[0]._player_controller.observation().boost_multiplier==1.0,"expired lease cannot retain boost")
	view=arena.observation(0)
	check(arena.submit_review_command(arena.session.make_command(view,int(view.last_sequence)+1,action(Vector2(0,-1))),ports(true)),"fresh boost after expiry")
	arena.step()
	check(arena.session._rigs[0].review_boost_held(),"fresh accepted lease restores held modifier")
	arena.set_paused(true)
	check(not arena.session._rigs[0].review_boost_held(),"pause retires held modifier")
	runtime.close();runtime.free()
	print("GCR_FLEET_BOOST ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
