extends "res://tests/support/sol_active_normal_authored.gd"

# Observation only. No CyberNativeCellWorld is instantiated or controller advanced.
func measured(body: RigidBody2D, bridge: Variant) -> Dictionary:
	var state: Dictionary = body_state(body)
	var direct := PhysicsServer2D.body_get_direct_state(body.get_rid())
	state["center_of_mass_local"]=direct.center_of_mass_local
	state["gravity"]=direct.total_gravity
	state["gravity_f64le"]=observed_f64_bits([direct.total_gravity.x,direct.total_gravity.y])
	state["linear_damp"]=direct.total_linear_damp
	state["angular_damp"]=direct.total_angular_damp
	state["reported_step"]=direct.step
	state["contacts"]=direct.get_contact_count()
	state["manual_step"]=bridge.manual_step_count()
	state["sleeping"]=direct.sleeping
	return state

func properties(body: RigidBody2D) -> Dictionary:
	return {"gravity_scale":body.gravity_scale,"linear_damp":body.linear_damp,"angular_damp":body.angular_damp,
		"linear_damp_mode":body.linear_damp_mode,"angular_damp_mode":body.angular_damp_mode,
		"collision_layer":body.collision_layer,"collision_mask":body.collision_mask,
		"project_gravity":ProjectSettings.get_setting("physics/2d/default_gravity"),
		"project_gravity_vector":ProjectSettings.get_setting("physics/2d/default_gravity_vector"),
		"project_linear_damp":ProjectSettings.get_setting("physics/2d/default_linear_damp"),
		"project_angular_damp":ProjectSettings.get_setting("physics/2d/default_angular_damp")}

func oracle(model: String, motion: Dictionary) -> Dictionary:
	var viewport := SubViewport.new();viewport.world_2d=World2D.new();viewport.size=Vector2i(2,2)
	viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
	var session := Session.new();viewport.add_child(session)
	var definition: Dictionary = actor(model,0,"LA-SELECTIVE",512)
	var configured: bool = session.configure([definition],viewport.world_2d.space,1)
	check(configured,"fresh actual Rapier authored session "+model)
	if not configured:session.close();viewport.free();return {}
	# The bridge creates an empty static terrain RID; remove it in this private
	# fixture so the registered space contains only the one authored body.
	session.bridge._destroy_hard_surface_collider()
	var body: RigidBody2D = session.bodies()[0]
	var authored_properties: Dictionary = properties(body)
	var geometry: Array = session._rigs[0].collision_rects()
	var prime_before: Dictionary = measured(body,session.bridge)
	body.gravity_scale=0;body.can_sleep=false
	session.bridge.step()
	var prime_after: Dictionary = measured(body,session.bridge)
	check(prime_after.pose==prime_before.pose and prime_after.velocity==Vector2.ZERO and prime_after.omega==0,"neutral prime unchanged")
	body.gravity_scale=authored_properties.gravity_scale
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(motion.velocity[0],motion.velocity[1]))
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,float(motion.omega))
	var records: Array = []
	for step: int in 32:
		var before: Dictionary = measured(body,session.bridge)
		var started: int = Time.get_ticks_usec();session.bridge.step();var elapsed: int = Time.get_ticks_usec()-started
		var after: Dictionary = measured(body,session.bridge)
		check(after.manual_step==before.manual_step+1,"exactly one manual step")
		check(before.contacts==0 and after.contacts==0 and not after.sleeping,"awake empty-space no-contact step")
		check(properties(body)==authored_properties,"authored gravity/damping/collision properties retained")
		records.append({"step":step,"before":before,"after":after,"step_us":elapsed})
	var out: Dictionary = {"model":model,"initial_motion":motion,"definition":definition,"properties":authored_properties,
		"geometry":geometry,"instance_id":body.get_instance_id(),"session_instance":session.get_instance_id(),
		"space_id":viewport.world_2d.space.get_id(),"body_rid":body.get_rid().get_id(),"epoch":session.epoch,
		"prime_before":prime_before,"prime_after":prime_after,"steps":records,"native_World":"ABSENT","native_workers":"NOT_APPLICABLE"}
	session.close();check(not session.active() and session.bodies().is_empty(),"oracle teardown")
	out["teardown"]=true;viewport.free();return out

func run() -> void:
	# The isolated project receives the exact preregistered bytes as a test fixture.
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/sol_gravity_operator_001.json"))
	check(profile.registration=="SOL-GRAVITY-OPERATOR-001" and profile.steps==32 and profile.cadence==60,"registered operator profile")
	var episodes: Array = []
	for model: String in profile.models:
		for motion: Dictionary in profile.initial_states:episodes.append(oracle(model,motion))
	var output: String = OS.get_environment("SOL_GRAVITY_OUTPUT")
	check(not output.is_empty() and not FileAccess.file_exists(output),"new evidence destination")
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"oracle output writable")
	if file!=null:
		file.store_string(JSON.stringify(plain({"registration":profile.registration,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
			"checks":checks,"failures":failures,"episodes":episodes})));file.close()
	print("SOL_GRAVITY_OPERATOR checks=",checks," failures=",failures.size());quit(int(not failures.is_empty()))
