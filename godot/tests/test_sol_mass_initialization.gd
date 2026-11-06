extends SceneTree

var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("SOL_MASS_INIT ",why)
func bits(values: Array) -> String:
	var b := PackedByteArray();b.resize(values.size()*8)
	for i: int in values.size():b.encode_double(i*8,float(values[i]))
	return b.hex_encode()
func read(body: RigidBody2D, bridge: CyberRapierPhysicsBridge) -> Dictionary:
	var rid: RID = body.get_rid();var d := PhysicsServer2D.body_get_direct_state(rid)
	var p: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var v: Vector2 = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	var w: float = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	return {"pose_bits":bits([p.x.x,p.x.y,p.y.x,p.y.y,p.origin.x,p.origin.y]),"velocity_bits":bits([v.x,v.y,w]),
		"direct_velocity_bits":bits([d.linear_velocity.x,d.linear_velocity.y,d.angular_velocity]),
		"mass":PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_MASS),"inertia":PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_INERTIA),
		"cached_inverse_mass":d.inverse_mass,"cached_inverse_inertia":d.inverse_inertia,"local_com":[d.center_of_mass_local.x,d.center_of_mass_local.y],
		"steps":bridge.manual_step_count(),"sleeping":d.sleeping,"rid":rid.get_id()}
func close(value: float,expected: float) -> bool:return absf(value-expected)<=16.0*pow(2.0,-23.0)*maxf(absf(expected),1e-12)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output: String = OS.get_environment("SOL_OUTPUT")
	if output.is_empty() or FileAccess.file_exists(output):printerr("SOL_MASS_INIT refuses output");quit(1);return
	var profile_path: String=OS.get_environment("SOL_MASS_PROFILE")
	if profile_path.is_empty():profile_path="res://tests/fixtures/sol_mass_initialization_001.json"
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	var cases: Array = []
	var inertia_scales: Array=profile.get("inertia_scales",[1])
	for structure: String in ["tree","building"]:
		var fixture: Dictionary = profile.fixtures[structure]
		for arm: String in profile.arms:
			for impulse_kind: String in profile.impulses:
				for inertia_scale: float in inertia_scales:
					var viewport := SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
					var body := RigidBody2D.new();body.freeze=true;body.collision_layer=0;body.collision_mask=0
					if arm=="auto_com_before_custom_inertia_fresh":
						body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_AUTO
						body.mass=float(fixture.mass);body.inertia=float(fixture.inertia)*inertia_scale
					else:
						body.mass=float(fixture.mass);body.inertia=float(fixture.inertia)*inertia_scale
						body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM;body.center_of_mass=Vector2.ZERO
					if arm=="auto_com_custom_inertia_fresh":body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_AUTO
					body.gravity_scale=0.;body.linear_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.angular_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.linear_damp=0.;body.angular_damp=0.
					body.position=Vector2(fixture.center[0],fixture.center[1]);var shapes: Array[CollisionShape2D] = []
					for i: int in range(0,fixture.rectangles.size(),4):
						var shape := CollisionShape2D.new();var rectangle := RectangleShape2D.new();var r: Array=fixture.rectangles
						rectangle.size=Vector2(r[i+2],r[i+3]);shape.shape=rectangle;shape.position=Vector2(r[i],r[i+1])+rectangle.size*.5-body.position;shape.disabled=true;body.add_child(shape);shapes.append(shape)
					viewport.add_child(body);await process_frame
					var bridge := CyberRapierPhysicsBridge.new();var bodies: Array[RigidBody2D]=[body]
					check(bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(29,38)]))==OK,"private actual Rapier initializes")
					for shape: CollisionShape2D in shapes:shape.disabled=false
					body.freeze=false;body.sleeping=false;bridge.refresh_all_states()
					var initial: Dictionary=read(body,bridge)
					if arm=="custom_after_zero_g_step":bridge.step()
					var before: Dictionary=read(body,bridge)
					var impulse:=Vector2(3.,0.) if impulse_kind=="central" else Vector2(0.,3.)
					var offset:=Vector2.ZERO if impulse_kind=="central" else Vector2(1.,0.)
					var called: bool=bridge._apply_cellular_impulse(0,impulse,offset)
					var immediate: Dictionary=read(body,bridge);bridge.step();var post: Dictionary=read(body,bridge)
					var bv: PackedByteArray=str(before.velocity_bits).hex_decode();var iv: PackedByteArray=str(immediate.velocity_bits).hex_decode();var pv: PackedByteArray=str(post.velocity_bits).hex_decode()
					var expected: Array=[impulse.x/float(fixture.mass),impulse.y/float(fixture.mass),offset.cross(impulse)/(float(fixture.inertia)*inertia_scale)]
					var observed: Array=[];var post_observed: Array=[];var matches: bool=true
					for axis: int in 3:
						observed.append(iv.decode_double(axis*8)-bv.decode_double(axis*8));post_observed.append(pv.decode_double(axis*8)-bv.decode_double(axis*8));matches=matches and close(float(observed[axis]),float(expected[axis]))
					check(called and initial.steps==0 and before.steps==int(arm=="custom_after_zero_g_step") and post.steps==before.steps+1,"known impulse and exact stage counts")
					check(before.mass==fixture.mass and is_finite(float(before.inertia)),"declared mass/inertia readable")
					if arm in ["custom_after_zero_g_step","auto_com_before_custom_inertia_fresh"]:check(matches,"ready backend obeys known impulse and explicit inertia reference")
					cases.append({"structure":structure,"arm":arm,"inertia_scale":inertia_scale,"impulse_kind":impulse_kind,"expected":expected,"observed":observed,"post_observed":post_observed,"matches_reference":matches,"initial":initial,"before":before,"immediate":immediate,"post":post})
					bridge.shutdown();viewport.queue_free();await process_frame
	check(cases.size()==2*profile.arms.size()*profile.impulses.size()*inertia_scales.size(),"complete registered geometry/arm/inertia/wrench oracle")
	var report: Dictionary={"registration":profile.registration,"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"host":OS.get_name(),"scope":"Isolated backend initialization; no nativeWorld or SOLphysicalclearance", "checks":checks,"failures":failures,"cases":cases}
	var file := FileAccess.open(output,FileAccess.WRITE);check(file!=null,"output writable")
	if file==null:quit(1);return
	report.checks=checks;report.failures=failures;file.store_string(JSON.stringify(report,"",true,true));file.flush();var error: Error=file.get_error();file.close()
	print("SOL_MASS_INIT checks=",checks," failures=",failures.size());quit(int(not failures.is_empty() or error!=OK))
