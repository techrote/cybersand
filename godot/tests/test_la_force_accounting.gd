extends SceneTree
const Session = preload("res://scripts/physical_actor_session.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value: failures.append(reason); push_error("LA_FORCE: "+reason)
func state(body: RigidBody2D) -> Dictionary:
	var direct := PhysicsServer2D.body_get_direct_state(body.get_rid())
	var mass: float = PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_MASS)
	var velocity: Vector2 = direct.linear_velocity
	return {"velocity":[velocity.x,velocity.y],"position":[direct.transform.origin.x,direct.transform.origin.y],"mass":mass,"kinetic":0.5*mass*velocity.length_squared()}
func run() -> void:
	var viewport := SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
	var session := Session.new();viewport.add_child(session)
	var definition: Dictionary = {"model":"reference_barrel","instance_id":1,"position":Vector2(128,100),"canvas_extent":Vector2i(512,512),"producer":"passive",
		"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}}
	check(session.configure([definition],viewport.world_2d.space,1),"real authored barrel")
	if not session.active(): viewport.free();quit(1);return
	var body: RigidBody2D = session.bodies()[0]
	var authored: Dictionary = {"gravity_scale":body.gravity_scale,"linear_damp":body.linear_damp,"angular_damp":body.angular_damp}
	body.gravity_scale=0;body.linear_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.linear_damp=0
	body.angular_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.angular_damp=0;body.collision_layer=0;body.collision_mask=0
	session.bridge.step()
	var before: Dictionary = state(body)
	check(Vector2(before.velocity[0],before.velocity[1])==Vector2.ZERO,"neutral prime")
	PhysicsServer2D.body_apply_central_force(body.get_rid(),Vector2(6,0));session.bridge.step()
	var first: Dictionary = state(body)
	check(absf(first.velocity[0]-0.1)<1e-6 and absf(first.velocity[1])<1e-6,"one force step transfers Fdt momentum")
	session.bridge.step();var second: Dictionary = state(body)
	session.bridge.step();var third: Dictionary = state(body)
	check(absf(second.velocity[0]-first.velocity[0])<1e-6 and absf(third.velocity[0]-first.velocity[0])<1e-6,"per-step force does not persist")
	PhysicsServer2D.body_apply_central_impulse(body.get_rid(),Vector2(0.2,0))
	var applied: Dictionary = state(body)
	var predicted_work: float = 0.2*third.velocity[0]+0.5*0.2*0.2/third.mass
	check(absf(applied.mass*(applied.velocity[0]-third.velocity[0])-0.2)<1e-6,"direct actual RID momentum")
	check(absf(applied.kinetic-third.kinetic-predicted_work)<1e-6,"direct impulse work identity")
	var report: Dictionary = {"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"fixture_sha256":FileAccess.get_sha256(get_script().resource_path),
		"scope":"isolated force lifetime and direct impulse, no native coupling or global energy proof","authored":authored,
		"dt":session.bridge.fixed_delta(),"before":before,"after_force":first,"without_force_1":second,"without_force_2":third,"after_impulse":applied,
		"direct_predicted_work":predicted_work,"endpoint_force_work_estimate":6.0*(first.position[0]-before.position[0]),"checks":checks,"failures":failures}
	var output: String = OS.get_environment("LA_FORCE_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
	session.close();viewport.free()
	print("LA_FORCE_ACCOUNTING ",JSON.stringify(report));quit(int(not failures.is_empty()))
