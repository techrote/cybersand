extends SceneTree

# Focused independent owner-clock regression. Uses the actual accepted Rapier
# manual bridge but no native material World or rendering. Deliberate malformed
# advance/completion ordering checks only the new ambient clock; it does not
# redefine inherited physical-session stepping or claim real playfeel.
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
var checks: int = 0
var failures: Array[String] = []
var owner: Node2D
var session


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_CLOCK: " + label)


func clock() -> float:
	return float(session.workbench_control(101).get("simulation_time_seconds",-1.0))


func core() -> Dictionary:
	return session.workbench_control(101).get("diagnostics",{}).get("ambient",{})


func complete_one(requested_delta: float) -> void:
	session.advance(requested_delta)
	session.bridge.step()
	session.complete_step()


func run() -> void:
	check(ClassDB.class_exists("RapierPhysicsServer2D"),"real pinned Rapier extension is available")
	owner = Node2D.new()
	root.add_child(owner)
	session = Session.new()
	owner.add_child(session)
	var profile := Profile.blank("clock")
	profile.modules = [Profile.make_module("rest")]
	profile.modules[0].params.active_seconds = 100.0
	var control := Registry.default_control("runner")
	control.source = "policy"
	control.policy = "ambient"
	control.enabled = true
	control.decision_ticks = 1
	control.usable_index = -1
	control.ambient = profile
	var definition := {"model":"runner","instance_id":101,"position":Vector2(120,100),
		"producer":"policy","usable_index":-1,"canvas_extent":Vector2i(512,256),"workbench_control":control,
		"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,"mass_multiplier":1.0,
			"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}}
	check(session.configure([definition],owner.get_world_2d().space,73),"ordinary accepted Workbench actor session admits clock fixture")
	if not session.active():
		print("AMBIENT_CLOCK ",JSON.stringify({"checks":checks,"failures":failures,"error":session.last_error}))
		session.close()
		owner.free()
		quit(1)
		return
	var dt: float = session.bridge.fixed_delta()
	check(absf(dt - 1.0 / 60.0) < 0.000000001,"actual bridge fixed step is one sixtieth second")
	check(clock() == 0.0,"new owner begins with zero completed physical time")
	var rid: RID = session.bodies()[0].get_rid()
	session.complete_step()
	check(clock() == 0.0,"completion notification without real bridge step cannot advance ambient time")
	complete_one(dt)
	check(absf(clock() - dt) < 0.000000001,"one genuine bridge step advances ambient time once")
	complete_one(0.2)
	check(absf(clock() - 2.0 * dt) < 0.000000001,"large requested actuator delta cannot inflate actual completed time")
	session.advance(dt)
	session.complete_step()
	check(absf(clock() - 2.0 * dt) < 0.000000001,"advance without actual bridge progression consumes no ambient time")
	complete_one(dt)
	check(absf(clock() - 3.0 * dt) < 0.000000001,"normal stepping recovers after an uncompleted request")
	for index: int in 3: session.bridge.step()
	session.complete_step()
	check(absf(clock() - 6.0 * dt) < 0.000000001,"clock records actual completed bridge count rather than one callback")
	var issued: Dictionary = session.workbench_policy_observation(101)
	var late: Dictionary = Session.make_command(issued,int(issued.last_sequence)+1,{"move":Vector2.RIGHT,"effort":0.2},6)
	var saved_time: float = clock()
	var saved_elapsed: float = float(core().get("elapsed_seconds",-1.0))
	session.set_suspended(true)
	for index: int in 4:
		session.advance(dt)
		session.complete_step()
		await process_frame
	check(clock() == saved_time,"pause and wall-clock frames consume no completed physical time")
	check(float(session._scripts[0]._ambient.diagnostics().elapsed_seconds) == saved_elapsed,"pause preserves engine temporary clock state")
	session.set_suspended(false)
	check(not session.submit_workbench_policy(101,late),"old issued command cannot regain authority after pause")
	complete_one(dt)
	check(absf(clock() - (saved_time+dt)) < 0.000000001,"fresh resumed step advances only its real duration")
	check(session.bodies()[0].get_rid() == rid,"pause and resume retain the actual physical body")
	var human := control.duplicate(true)
	human.source = "human"
	check(session.set_workbench_control(101,human),"human handoff uses existing live producer transition")
	complete_one(dt)
	check(session.set_workbench_control(101,control),"ambient handback applies authored profile through owner")
	complete_one(dt)
	check(absf(float(core().get("elapsed_seconds",-1.0))) < 0.000000001,"handback starts fresh ephemeral intent at current physical time")
	complete_one(dt)
	check(absf(float(core().get("elapsed_seconds",-1.0))-dt) < 0.000000001,"fresh handback state progresses on the following genuine step")
	var before: Dictionary = core()
	var bad := control.duplicate(true)
	bad.ambient.modules[0].params.rest_seconds = NAN
	check(not session.set_workbench_control(101,bad),"invalid live profile is refused before producer retirement")
	check(core() == before and session.bodies()[0].get_rid() == rid,"failed profile preserves the valid producer state and physical body")
	var completed: int = session.bridge.manual_step_count()
	var final_seconds: float = clock()
	session.close()
	owner.free()
	print("AMBIENT_CLOCK ",JSON.stringify({"checks":checks,"failures":failures,
		"actual_bridge_steps":completed,"completed_time_seconds":final_seconds,
		"scope":"actual Rapier bridge clock and producer lifecycle; no native material World or playfeel"}))
	quit(0 if failures.is_empty() else 1)
