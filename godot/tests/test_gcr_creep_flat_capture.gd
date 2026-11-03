extends SceneTree

const Flat = preload("res://qualification/gcr_creep_flat_capture.gd")
var checks: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, reason: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("GCR flat apparatus: "+reason)

static func sample_application() -> Dictionary:
	return {"accepted":true,"bodies":[{"age":0,"sample":7,"session":2,
		"actual_mass":.1,"actual_inertia":.975,"velocity_before_correction":Vector2(4,-1),"omega_before_correction":.75}]}

static func sample_receipt() -> Dictionary:
	return {"bodies":[{"sample":7,"session":2,"sample_velocity":Vector2(3,-2),"sample_omega":.5}]}

func actual_setup_and_delivery() -> void:
	var arena = Flat.Arena.new()
	root.add_child(arena)
	await process_frame
	check(arena.configure_review_fleet(Flat.configuration(),"GCR-REST","GCR-REST-001-2026-11-02",2,Flat.options(false)),"actual default LA Kestrel constructs")
	if arena.session==null:
		arena.free()
		return
	var setup: Dictionary = Flat.author_room(arena)
	check(setup.accepted,"flat native authoring preserves constructor pose and primed sample")
	check(setup.session_before==setup.session_after and setup.sample_before==setup.sample_after,"no bridge session or serial reset during setup")
	check(setup.native_tick_before==0 and setup.native_tick_after==0,"material authoring executes zero native ticks")
	check(setup.census.counts[2]==97410 and setup.census.counts[1]==1788,"flat bed and border census match registered exact geometry")
	check(setup.census.counts[0]==97410,"no tall bank remains in the authored room")
	var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":.7,"trim":.15,"primary":false,"secondary":false,"auxiliary":false}
	var view: Dictionary = arena.observation(0)
	check(arena.submit(arena.session.make_command(view,int(view.last_sequence)+1,action),&"human"),"existing Q/E side-jet action admitted")
	var snapshot: Dictionary = arena.step()
	check(not snapshot.get("failed",true),"first actual flat frame succeeds")
	var measured: Dictionary = Flat.measure_controller_delivery(arena.session.bridge.gcr_application_diagnostics(),arena._world.gcr_rest_receipt())
	var rig = arena.session._rigs[0]
	var controller: Dictionary = rig._player_controller.observation()
	check(measured.measured,"first side-jet impulse measured from actual backend phase velocities")
	check(Vector2(measured.impulse).x>0.0 and absf(Vector2(measured.impulse).y)<1e-7,"upright initial side jet produces measured rightward impulse")
	check(Vector2(measured.impulse).distance_to(Vector2(controller.applied_force)/60.0)<1e-7,"measured side-jet delivery agrees with bounded request at this nonzero scale")
	check(measured.torque_impulse==0.0,"side thrust action does not introduce steering torque")
	# Isolated apparatus witness: the retained rig reports even tiny requested
	# impulses that its part-level backend writer refuses below magnitude1e-4.
	# This is a test precondition, not a primary trajectory or controller change.
	var body: RigidBody2D = arena.session.bodies()[0]
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(.001,.001))
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,0.0)
	arena.session.bridge.refresh_all_states()
	action.trim=0.0
	view=arena.observation(0)
	check(arena.submit(arena.session.make_command(view,int(view.last_sequence)+1,action),&"human"),"neutral tiny-motion witness admitted")
	snapshot=arena.step()
	check(not snapshot.get("failed",true),"neutral tiny-motion witness completes")
	measured=Flat.measure_controller_delivery(arena.session.bridge.gcr_application_diagnostics(),arena._world.gcr_rest_receipt())
	check(measured.measured and Vector2(measured.impulse)==Vector2.ZERO,"backend phase measurement detects zero delivered impulse")
	check(Vector2(rig._last_impulse).length()>0.0 and Vector2(rig._last_impulse).length()<.0001,"rig report remains explicitly distinct from actual tiny-impulse delivery")
	arena.close()
	arena.free()
	await process_frame

func _run() -> void:
	var application: Dictionary = sample_application()
	var receipt: Dictionary = sample_receipt()
	var measured: Dictionary = Flat.measure_controller_delivery(application,receipt)
	check(measured.measured and Vector2(measured.impulse).distance_to(Vector2(.1,.1))<1e-12,"phase difference uses actual mass")
	check(absf(float(measured.torque_impulse)-.24375)<1e-12,"angular phase difference uses actual inertia")
	application.bodies[0].age=1
	check(not Flat.measure_controller_delivery(application,receipt).measured,"aged application cannot identify this-step actuation")
	application=sample_application()
	application.bodies[0].sample=8
	check(not Flat.measure_controller_delivery(application,receipt).measured,"mismatched sample refuses measured attribution")
	application=sample_application()
	application.bodies[0].session=3
	check(not Flat.measure_controller_delivery(application,receipt).measured,"mismatched session refuses measured attribution")
	application=sample_application()
	application.accepted=false
	check(not Flat.measure_controller_delivery(application,receipt).measured,"unaccepted application cannot supply delivery")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--protocol="):
			var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--protocol=")))
			check(protocol is Dictionary and Flat.protocol_error(protocol).is_empty(),"actual committed flat protocol binds exact fixture")
			if protocol is Dictionary:
				protocol.fixture_flyer.bank=[300,192,339,128]
				check(not Flat.protocol_error(protocol).is_empty(),"accidental reintroduction of tall bank refuses")
	await actual_setup_and_delivery()
	print("GCR_CREEP_FLAT_APPARATUS ",JSON.stringify({"checks":checks,"failures":failures,
		"scope":"flat setup, same-phase measured actuation and retained tiny-impulse refusal; no physical efficacy"}))
	quit(0 if failures==0 else 1)
