extends SceneTree

# Non-stepping ownership transfer: deferred CanvasItem transform notifications
# must finish before the exact worker-bound frozen body identities are captured.
const Candidate = preload("res://scripts/prepared_physical_session.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message); push_error("WORKBENCH_PREPARED_POSE: "+message)
func run() -> void:
	var host := Node2D.new(); root.add_child(host); await process_frame
	var angles := [0.0,-0.00029288575751707,0.141343981027603,0.2,PI/4.0,PI/2.0]
	var catalogue := Session.Equipment.definition(Session.Catalog.entry(&"acrobat"),Session.Loadouts.entry(&"acrobat"))
	var parts: Array = []
	for index: int in catalogue.parts.size():
		parts.append({"position":Vector2(140,100)+Vector2(catalogue.parts[index].offset),
			"rotation":angles[index%angles.size()],"linear_velocity":Vector2(1.25,-0.75),"angular_velocity":0.15})
	var definition := {"model":"acrobat","instance_id":1,"position":Vector2(140,100),"canvas_extent":Vector2i(512,512),"producer":"human",
		"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,"mass_multiplier":1.1,"inertia_multiplier":1.0,
			"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0},
		"retained_motion":{"rotation":parts[0].rotation,"linear_velocity":parts[0].linear_velocity,"angular_velocity":0.15,"parts":parts}}
	var candidate = Candidate.new()
	check(candidate.prepare(host,[definition],1),"nonroot independently rotated actual articulated bodies stage")
	if candidate.session != null:
		var original := candidate.initial_body_states()
		var step: int = candidate.physics_bridge().manual_step_count()
		for frame: int in 4:
			await physics_frame; await process_frame
			check(candidate.pose_unchanged(),"exact frozen server pose survives deferred transform notifications frame%d"%frame)
			check(candidate.initial_body_states() == original and candidate.physics_bridge().manual_step_count() == step,"no packet recapture or hidden physics step")
		# The exact comparison remains strict for a genuine post-capture edit.
		var body: RigidBody2D = candidate.bodies()[1]
		var pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
		pose.origin.x += 0.01
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,pose)
		check(not candidate.pose_unchanged(),"real changed body pose still refuses")
		check(candidate.initial_body_states() == original,"failed pose validation never rewrites captured authority")
	candidate.close(); host.free(); await process_frame
	print("WORKBENCH_PREPARED_POSE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
