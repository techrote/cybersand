extends SceneTree

# Main-thread construction/publication controls, not owner gameplay acceptance.
const Runtime=preload("res://scripts/player_playground_runtime.gd")
const Fleet=preload("res://scripts/gcr_review_fleet.gd")
const Rig=preload("res://scripts/physical_actor_rig.gd")
var checks: int=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("_run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); push_error(reason)
func options(response: String, mass: float=1.0, inertia: float=1.0) -> Dictionary:
	return {"response":response,"budget":20.0,"mass_multiplier":mass,"inertia_multiplier":inertia}
func pose(body: RigidBody2D) -> Transform2D:
	return PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
func overlaps(rectangles: Array, point: Vector2) -> bool:
	for rect: Dictionary in rectangles:
		if Rect2(Vector2(rect.center)-Vector2(rect.size)*0.5,rect.size).has_point(point): return true
	return false
func _run() -> void:
	var scooper: int=Fleet.NAMES.find("Scooper")
	check(scooper>=0 and Fleet.uses_compound(scooper),"Scooper is an explicit compound definition")
	if scooper<0: quit(1); return
	var definition: Dictionary=Fleet.definition(scooper)
	check(Rig.validate_definition(definition).is_empty(),"compound definition validates")
	var rectangles: Array=Fleet.collision_rects(scooper)
	check(rectangles.size()==6,"registered six-piece physical hull")
	var bad: Dictionary=definition.duplicate(true)
	bad.parts[0].collision_rects.append(bad.parts[0].collision_rects[0].duplicate(true))
	check(not Rig.validate_definition(bad).is_empty(),"positive-area duplicate shape refuses")
	var unbound=Rig.new();root.add_child(unbound)
	check(unbound.configure(definition,Vector2(700,100))==ERR_UNAVAILABLE,"ordinary actor owner cannot silently publish compound as AABB")
	unbound.free()
	var runtime=Runtime.new();root.add_child(runtime)
	await process_frame
	for response: String in ["LA","LA-EVENT-OFF","LA-SELECTIVE","RFT"]:
		check(runtime.configure_review_fleet(scooper,options(response),Vector2(700,100)),"compound admitted in "+response)
		if runtime._arena==null: continue
		var arena=runtime._arena
		var rig=arena.session._rigs[0]
		var bodies: Array[RigidBody2D]=arena.session.bodies()
		check(bodies.size()==1 and arena.session._rigs.size()==1,"all hull pieces share one actual body")
		var body: RigidBody2D=bodies[0]
		check(body.get_child_count()==6,"six hard colliders on the same physical RID")
		check(body.center_of_mass_mode==RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM and body.center_of_mass==Vector2.ZERO,"COM is the authored physical origin")
		check(is_equal_approx(body.mass,0.18) and is_equal_approx(body.inertia,float(definition.parts[0].inertia)),"actual mass and parallel-axis inertia installed once")
		check(is_equal_approx(rig._total_mass,body.mass) and is_equal_approx(rig._inertias[0],body.inertia),"actuation caches use the same actual mass and inertia")
		check(arena._authored_compound_centers.size()==6 and arena._authored_compound_geometry.size()==24,"native geometry is the same bounded union")
		check(arena.gcr_stats.prepared==1,"construction publishes exactly one union sample, no AABB prime")
		check(runtime.snapshot().authored_compound and runtime.snapshot().review_definition_hash==Fleet.definition_hash(scooper),"receipt labels actual frozen definition and compound owner")
		var rendered: Array=runtime.render_parts()
		check(rendered.size()==6,"graphics contain the actual six shapes")
		for index: int in range(6):
			var collider: CollisionShape2D=body.get_child(index)
			check(collider.shape is RectangleShape2D and collider.shape.size.is_equal_approx(rectangles[index].size),"hard collider size matches authored/native rectangle")
			check(collider.position.is_equal_approx(rectangles[index].center),"hard collider is placed at its actual COM-relative offset")
			check(Transform2D(rendered[index].transform).is_equal_approx(pose(body)*collider.transform) and Vector2(rendered[index].size).is_equal_approx(collider.shape.size),"copied rendering uses actual collider geometry")
			check(rendered[index].physical_body_index==0,"render shape does not create another physical owner")
		var chassis_count: int=0
		for part: Dictionary in rendered:
			if part.part_id=="chassis": chassis_count+=1
		check(chassis_count==1,"one propulsion presentation per body")
		var copied: Array=rig.collision_rects()
		copied[0].center=Vector2(999,999)
		check(rig.collision_rects()[0].center.is_equal_approx(rectangles[0].center),"copied geometry cannot mutate the live owner")
		var local_cavity:=Vector2.ZERO
		var found_cavity: bool=false
		var bounds: Rect2=Fleet.bounds(scooper)
		for y: int in range(ceili(bounds.position.y)+1,floori(bounds.end.y)):
			for x: int in range(ceili(bounds.position.x)+1,floori(bounds.end.x)):
				var point:=Vector2(x+0.25,y+0.25)
				if not overlaps(rectangles,point): local_cavity=point;found_cavity=true;break
			if found_cavity: break
		check(found_cavity,"the registered body has a genuine open AABB cavity")
		for angle: float in [0.0,0.65,PI*0.5]:
			PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(angle,Vector2(700,100)))
			arena.session.bridge.refresh_all_states()
			rig.refresh_observation()
			var state: Dictionary=arena.step()
			check(not state.failed,"rotated compound prepares/steps/applies in "+response)
			var diagnostics: Dictionary=arena.session.bridge.gcr_application_diagnostics()
			check(diagnostics.get("accepted",false) and diagnostics.bodies.size()==1,"one accumulated wrench is accepted for every rotated union")
			var result: PackedFloat64Array=arena._world.gcr_compound_results()
			check(result.size()==14 and result[0]==1.0 and result[12]==2.0,"one version2 result for the complete physical body")
			var velocity_before: Vector2=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			check(arena.session.bridge.apply_gcr_compound_results(arena.session.tick,result,arena._world.gcr_rest_receipt() if response!="RFT" else {})==0,"duplicate result cannot apply twice")
			check(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)==velocity_before,"duplicate refusal leaves momentum unchanged")
		var old_identity: Dictionary=arena._authored_compound_identity.duplicate(true)
		var old_result: PackedFloat64Array=arena._world.gcr_compound_results()
		check(arena.reset(),"fresh reset keeps compound definition and selected response")
		check(arena._authored_compound_identity.session_id!=old_identity.session_id and arena._authored_compound_identity.body_generation>old_identity.body_generation,"reset replaces native and Rapier sample identity")
		check(arena.session.bridge.apply_gcr_compound_results(1,old_result,arena._world.gcr_rest_receipt() if response!="RFT" else {})==0,"old-owner wrench cannot apply to new body")
		check(arena.session.bodies().size()==1 and arena._review_definition_hash==Fleet.definition_hash(scooper),"reset retains one physical owner and exact authored definition hash")
	check(runtime.configure_review_fleet(scooper,options("LA-SELECTIVE",2.0,3.0),Vector2(700,100)),"compound accepts existing mass/inertia developer controls")
	var scaled: RigidBody2D=runtime._arena.session.bodies()[0]
	check(is_equal_approx(scaled.mass,0.36) and is_equal_approx(scaled.inertia,float(definition.parts[0].inertia)*6.0),"compound mass and geometric inertia each scale exactly once")
	for index: int in range(7):
		check(runtime.configure_review_fleet(index,options("LA"),Vector2(700,100)),"original flyer construction remains available")
		check(runtime._arena._authored_compound_identity.is_empty() and runtime._arena.session.bodies()[0].get_child_count()==1 and runtime.render_parts().size()==1,"original flyer retains independent one-rectangle path")
	runtime.close();runtime.free()
	print("GCR_SCOOPER_BODY ",JSON.stringify({"checks":checks,"failures":failures,"responses":["LA","LA-EVENT-OFF","LA-SELECTIVE","RFT"],"scope":"One-body compound construction, colliders, copied drawing and response lifetime"}))
	quit(0 if failures.is_empty() else 1)
