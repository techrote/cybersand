extends SceneTree
const Policy=preload("res://scripts/experimental_passive_response.gd")
const Session=preload("res://scripts/physical_actor_session.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func definition(id: int) -> Dictionary:
	return {"model":"reference_barrel","instance_id":id,"position":Vector2(100+id*32,100),"canvas_extent":Vector2i(512,512),"producer":"passive",
		"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}}
func run() -> void:
	var current: Dictionary = Policy.revalidate(Vector2(0,3),0,1,20,Vector2(0,-2),0,Vector2(0,-2),0,true)
	check(current.valid and current.passive_scale==1 and current.impulse==Vector2(0,-2),"closing contact retains dissipative response")
	var reversed: Dictionary = Policy.revalidate(Vector2(0,-3),0,1,20,Vector2(0,-2),0,Vector2(0,-2),0,true)
	check(reversed.valid and reversed.passive_scale==0 and reversed.impulse==Vector2.ZERO,"separating passive acceleration removed")
	var overshoot: Dictionary = Policy.revalidate(Vector2(0,1),0,1,20,Vector2(0,-4),0,Vector2(0,-4),0,true)
	check(overshoot.valid and overshoot.passive_scale==0.5 and overshoot.impulse==Vector2(0,-2),"largest energy-admissible fraction")
	check(not Policy.revalidate(Vector2.ZERO,0,0,1,Vector2.ZERO,0,Vector2.ZERO,0,true).valid,"invalid mass refused")
	check(not Policy.revalidate(Vector2.ZERO,0,1,1,Vector2.ZERO,0,Vector2.ZERO,1e308,true).valid,"overflow energy refused")
	var host:=Node2D.new(); root.add_child(host)
	var session:=Session.new(); host.add_child(session)
	check(session.configure([definition(1),definition(2)],host.get_world_2d().space,5),"real independent body owners")
	check(session.bridge.configure_application_variant("passive-live-v1"),"opt in before sampling")
	for body: RigidBody2D in session.bodies(): body.gravity_scale=0
	session.bridge.step()
	var sample: Dictionary = session.bridge.pack_sample([false,false])
	session.bridge._serial=0 # Simulates counter wrap without a million physical samples.
	check(not session.bridge.configure_application_variant("baseline"),"nonwrapping policy lifetime fence")
	session.bridge._serial=int(sample.states[10])
	var rows: Array = []
	for owner: Dictionary in sample.bodies:
		var i: int = (owner.first_proxy-1)*17
		rows.append({"id":owner.id,"instance_id":owner.instance_id,"generation":owner.generation,"budget":owner.budget,
			"sample":int(sample.states[i+10]),"com":Vector2(sample.states[i+12],sample.states[i+13]),
			"mass":sample.states[i+9],"inertia":sample.states[i+11],"gravity":owner.gravity,"external_drive":false,
			"impulse":Vector2(0.1,0),"torque":0.0,"correction":Vector2.ZERO,"passive_impulse":Vector2.ZERO,"passive_torque":0.0})
	rows[1].passive_torque=1e308
	var packet: Dictionary = {"valid":true,"session":sample.session,"epoch":sample.epoch,"response":"LA-SELECTIVE","rows":rows}
	var before: Array = []
	for body: RigidBody2D in session.bodies(): before.append(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY))
	check(session.apply_workbench_results(1,packet)==0 and session.bridge.last_application.refusal=="passive_nonfinite","bad passive batch refused atomically")
	for index: int in session.bodies().size():
		check(PhysicsServer2D.body_get_state(session.bodies()[index].get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)==before[index],"no peer impulse before full validation")
	session.close(); host.free()
	print("LA_PASSIVE_RESPONSE checks=",checks," failures=",failures.size())
	quit(int(not failures.is_empty()))
