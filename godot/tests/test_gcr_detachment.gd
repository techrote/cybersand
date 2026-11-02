extends SceneTree

# Mechanical prerequisite only: native lease/geometry plus isolated actual
# Rapier wrench application. No efficacy trajectory or alternate simulation loop.
const Session = preload("res://scripts/solid_detachment_session.gd")
var checks: int = 0
var failures: Array[String] = []
var viewport: SubViewport
var body: RigidBody2D
var bridge: CyberRapierPhysicsBridge
var centers := PackedVector2Array()
var sizes := PackedVector2Array()
var source: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL GCR DETACHMENT MECHANICAL ",message)

func near(value: float, expected: float, message: String, tolerance: float = 1e-5) -> void:
	check(absf(value-expected) <= tolerance*maxf(1.0,absf(expected)),message)

func world(arm: String = "R2") -> Object:
	var native: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(native != null,"actual native class")
	var options: Dictionary = {"workers":1,"telemetry":true,"conservative_displacement":true}
	if arm != "legacy":
		options["bearing_candidate"] = "GCR-A1" if arm == "A1" else "GCR"
		options["bearing_experiment"] = "GCR-ADMISSION-001-2026-11-01" if arm == "A1" else "GCR-001-2026-11-01"
	check(native.diagnostic_reset(options),"single combined initialization")
	check(native.get_gcr_admission_variant()==("disabled" if arm=="legacy" else arm),"actual immutable native variant")
	native.set_simulation_window_enabled(false)
	for item: Array in [[0,72,128,4,1],[50,40,4,32,43],[44,27,29,13,43],[54,40,11,4,43],[8,45,3,27,43],[60,32,1,1,0]]:
		check(native.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4]),"native recipe edit")
	check(native.simulation_tick(),"initial inclusion")
	check(native.solid_detachment_command({"action":"configure","members":1024,"shapes":128}).get("ok",false),"native configuration")
	return native

func transfer(native: Object) -> Dictionary:
	var prepared: Dictionary = native.solid_detachment_command({"action":"cut_prepare","domain":Session.DOMAIN,"anchors":Session.ANCHORS,"seed":Session.SEED,"cut":Session.CUT})
	check(prepared.get("ok",false),"native prepare")
	if not prepared.get("ok",false):
		return {}
	check(int(prepared.member_count)==520 and int(prepared.shape_count)==6,"native520/six")
	near(float(prepared.mass),520.0,"unit mass")
	near(float(prepared.inertia),109907693.0/1560.0,"native lamina inertia",1e-10)
	near(float(prepared.center.x),32.0+3293.0/130.0,"native COMx transport")
	near(float(prepared.center.y),16.0+175.0/8.0,"native COMy transport")
	var command: Dictionary = {"action":"acknowledge","token":prepared.token,"body_id":1,"body_generation":7,
		"shape_count":prepared.shape_count,"payload_digest":prepared.payload_digest,"shape_digest":prepared.shape_digest}
	check(native.solid_detachment_command(command).get("ok",false),"native acknowledgement")
	var committed: Dictionary = native.solid_detachment_command({"action":"commit","token":prepared.token})
	check(committed.get("ok",false),"native commit")
	check(native.solid_detachment_command({"action":"finalize","token":prepared.token,"body_id":1,"body_generation":7,
		"terrain_revision":committed.commit_revision,"physics_epoch":1}).get("ok",false),"native lease finalize")
	return prepared

func native_states(prepared: Dictionary, serial: int = 1) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	var rectangles: PackedInt32Array = prepared.rectangles
	for index: int in range(rectangles.size()/4):
		var offset: int = index*4
		result.append_array(PackedFloat64Array([index+1,rectangles[offset]+rectangles[offset+2]*.5,rectangles[offset+1]+rectangles[offset+3]*.5,
			0,rectangles[offset+2],rectangles[offset+3],0,80,0,520,serial,prepared.inertia,prepared.center.x,prepared.center.y,.78,1.0/60.0,73]))
	return result

func lease(prepared: Dictionary) -> Dictionary:
	return {"token":prepared.token,"body_id":1,"body_generation":7,"physics_epoch":1}

func original_mask(native: Object) -> PackedInt32Array:
	var result := PackedInt32Array()
	for y: int in range(25,68):
		for x: int in range(42,76):
			result.append(int(native.rigid_body_id_at(x,y)))
	return result

func native_protocol() -> void:
	for arm: String in ["R2","A1"]:
		var native: Object = world(arm)
		var prepared: Dictionary = transfer(native)
		if prepared.is_empty():
			continue
		source = prepared
		var packed: PackedFloat64Array = native_states(prepared)
		check(native.prepare_gcr_compound_coupling(packed,lease(prepared),true),"fresh compound prepare "+arm)
		var packet: PackedFloat64Array = native.gcr_compound_results()
		check(packet.size()==14,"one physical output")
		if packet.size()==14:
			check(packet[0]==1 and packet[12]==2 and packet[13]==73,"physical id/version/session")
		check(native.gcr_body_results().is_empty(),"compound cannot route to independent output")
		for point: Array in [[51,32,true],[50,50,true],[60,32,false],[68,50,false]]:
			check((int(native.rigid_body_id_at(point[0],point[1]))>0)==point[2],"exact union probe "+str(point))
		var inspection: Dictionary = native.solid_detachment_command({"action":"inspect"})
		check(inspection.members==prepared.members and int(inspection.aggregate_owned)==520 and int(inspection.native_source_members)==0,"sole exact tuple ownership")
		var diagnostics: Dictionary = native.gcr_compound_diagnostics()
		check(int(diagnostics.get("proxy_count",-1))==6,"six geometric proxies")
		check(float(diagnostics.get("normal_capacity",INF))<=20.0,"one body normal budget")
		check(int(diagnostics.get("nodes",9999))<=96 and int(diagnostics.get("updates",9999))<=768,"six rectangle work bound")
		var retained_mask: PackedInt32Array = original_mask(native)
		for fault: String in ["lease","mass","inertia","com","velocity","session","duplicate","rotation","angle-overflow","angle-maxdouble","angle-nan","angle-inf"]:
			var broken: PackedFloat64Array = native_states(prepared,2)
			var bad_lease: Dictionary = lease(prepared)
			match fault:
				"lease": bad_lease.body_generation = 8
				"mass": broken[17+9] = 1
				"inertia": broken[11] = 0
				"com": broken[17+12] += 1
				"velocity": broken[17+6] = 1
				"session": broken[17+16] = 74
				"duplicate": broken[17] = 1
				"rotation": broken[17+3] = .1
				"angle-overflow", "angle-maxdouble", "angle-nan", "angle-inf":
					var angle: float = {"angle-overflow":1e40,"angle-maxdouble":1.7976931348623157e308,"angle-nan":NAN,"angle-inf":INF}[fault]
					for offset: int in range(0,broken.size(),17):
						broken[offset+3]=angle
						broken[offset+1]=777.0; broken[offset+2]=777.0
			check(not native.prepare_gcr_compound_coupling(broken,bad_lease,true),"atomic refusal "+fault)
			check(native.gcr_compound_results().is_empty(),"invalid publication empty "+fault)
			check(original_mask(native)==retained_mask and int(native.rigid_body_id_at(777,777))==0,"invalid batch retains exact old mask "+fault)
			var after: Dictionary = native.solid_detachment_command({"action":"inspect"})
			check(after.members==prepared.members and int(after.aggregate_owned)==520,"refusal retains tuples "+fault)
		check(native.prepare_gcr_compound_coupling(native_states(prepared,3),lease(prepared),true),"fresh recovery")
		check(native.gcr_compound_results().size()==14,"fresh response recovery")
		for angle: float in [0.0,PI*.5]:
			var moved: PackedFloat64Array = native_states(prepared,4 if angle==0.0 else 5)
			var new_com: Vector2 = prepared.center+Vector2(20,0) if angle==0.0 else Vector2(160.0-prepared.center.y,prepared.center.x)
			for offset: int in range(0,moved.size(),17):
				var center := Vector2(moved[offset+1],moved[offset+2])
				center = (center-prepared.center).rotated(angle)+new_com
				moved[offset+1]=center.x; moved[offset+2]=center.y; moved[offset+3]=angle
				moved[offset+12]=new_com.x; moved[offset+13]=new_com.y
			check(native.prepare_gcr_compound_coupling(moved,lease(prepared),false),"rigid transformed native union")
			for point: Array in [[51,32,true],[50,50,true],[60,32,false],[68,50,false]]:
				var probe := Vector2i(point[0]+20,point[1]) if angle==0.0 else Vector2i(159-point[1],point[0])
				check((int(native.rigid_body_id_at(probe.x,probe.y))>0)==point[2],"transformed union/void probe")
	var baseline: Object = world("legacy")
	var baseline_source: Dictionary = transfer(baseline)
	if not baseline_source.is_empty():
		check(not baseline.prepare_gcr_compound_coupling(native_states(baseline_source),lease(baseline_source),true),"ordinary default cannot silently activate GCR")

func reset_body() -> void:
	bridge.reset_body(0,source.center,0.0)
	bridge.reset_result_tracking()
	bridge.refresh_all_states()

func material_controls() -> void:
	for material: int in [0,1,3]:
		var native: Object = world("R2")
		var prepared: Dictionary = transfer(native)
		if prepared.is_empty():
			continue
		# Separate mechanical contact fixture, never a physical-population arm.
		check(native.diagnostic_fill_rect(Vector2i(44,65),Vector2i(29,7),material),"non-granular control edit")
		var before: Dictionary = native.diagnostic_snapshot(Vector2i.ZERO,Vector2i(160,128),false,false)
		check(native.prepare_gcr_compound_coupling(native_states(prepared),lease(prepared),true),"non-granular compound prepare")
		check(native.simulation_tick(),"one actual control tick")
		check(native.gcr_compound_results().size()==14,"non-granular output remains versioned")
		var diagnostic: Dictionary = native.gcr_compound_diagnostics()
		check(diagnostic.get("passive_impulse",Vector2(INF,INF))==Vector2.ZERO,"no new granular passive response material"+str(material))
		check(diagnostic.get("event_accepted",Vector2(INF,INF))==Vector2.ZERO,"no new granular event response material"+str(material))
		var after: Dictionary = native.diagnostic_snapshot(Vector2i.ZERO,Vector2i(160,128),false,false)
		check(before.water_mass==after.water_mass,"exact Water mass in non-granular control")

func response(states: PackedFloat64Array, j: Vector2 = Vector2(3,4), angular: float = 7.0) -> PackedFloat64Array:
	return PackedFloat64Array([1,j.x,j.y,0,0,0,0,0,states[10],angular,states[12],states[13],2,states[16]])

func velocities() -> Array:
	return [PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
		float(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))]

func bridge_protocol() -> void:
	viewport = SubViewport.new(); viewport.world_2d = World2D.new(); root.add_child(viewport)
	body = RigidBody2D.new(); body.mass=520; body.inertia=source.inertia
	body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM; body.center_of_mass=Vector2.ZERO
	body.position=source.center; body.gravity_scale=0; body.linear_damp=0; body.angular_damp=0
	body.collision_layer=0; body.collision_mask=0
	var rectangles: PackedInt32Array = source.rectangles
	for offset: int in range(0,rectangles.size(),4):
		var size := Vector2(rectangles[offset+2],rectangles[offset+3])
		var center: Vector2 = Vector2(rectangles[offset],rectangles[offset+1])+size*.5-source.center
		centers.append(center); sizes.append(size)
		var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new()
		shape.size=size; collision.shape=shape; collision.position=center; body.add_child(collision)
	viewport.add_child(body)
	await process_frame
	bridge = CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	check(bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(29,38)]))==OK,"actual compound Rapier owner")
	reset_body()
	# Change the backend directly without refreshing the bridge cache. Every
	# geometric record and sample history must derive from this one direct pose.
	var fresh_pose := Transform2D(.125,source.center+Vector2(2,-1))
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,fresh_pose)
	var fresh_states: PackedFloat64Array = bridge.pack_gcr_compound_states(centers,sizes)
	for index: int in range(centers.size()):
		var expected: Vector2 = fresh_pose*centers[index]
		near(fresh_states[index*17+1],expected.x,"direct-pose proxyx")
		near(fresh_states[index*17+2],expected.y,"direct-pose proxyy")
		near(fresh_states[index*17+3],.125,"common direct rotation")
		near(fresh_states[index*17+12],fresh_pose.origin.x,"common direct COMx")
		near(fresh_states[index*17+13],fresh_pose.origin.y,"common direct COMy")
	reset_body()
	var states: PackedFloat64Array = bridge.pack_gcr_compound_states(centers,sizes)
	check(states.size()==102,"six17 geometry records")
	if states.size()!=102:
		return
	for offset: int in range(0,states.size(),17):
		near(states[offset+9],520,"repeated true total mass")
		near(states[offset+11],float(PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)),"actual backend inertia")
		check(states[offset+6]==states[6] and states[offset+7]==states[7],"common COM velocity")
	check(bridge.apply_gcr_compound_results(1,response(states))>0,"actual version2 wrench")
	var applied: Array = velocities()
	near(applied[0].x,3.0/520.0,"one Jx/m, no legacy3 clip")
	near(applied[0].y,4.0/520.0,"one Jy/m")
	near(applied[1],7.0/float(PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)),"one COM L/I")
	check(bridge.apply_gcr_compound_results(2,response(states))==0 and velocities()==applied,"duplicate cannot reapply")
	var newer: PackedFloat64Array = bridge.pack_gcr_compound_states(centers,sizes)
	check(bridge.apply_gcr_compound_results(3,response(newer))>0,"next serial accepts once")
	var newer_applied: Array = velocities()
	check(bridge.apply_gcr_compound_results(4,response(states))==0,"older serial refuses")
	check(bridge.apply_gcr_compound_results(5,response(newer))==0 and velocities()==newer_applied,"N,N-1,N cannot mint wrench")
	for fault: String in ["version","session","nan","age","corner"]:
		reset_body(); states=bridge.pack_gcr_compound_states(centers,sizes)
		var packet: PackedFloat64Array = response(states)
		match fault:
			"version": packet[12]=1
			"session": packet[13]+=1
			"nan": packet[9]=NAN
			"age":
				bridge.pack_gcr_compound_states(centers,sizes); bridge.pack_gcr_compound_states(centers,sizes)
			"corner":
				PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(.1,source.center))
		check(bridge.apply_gcr_compound_results(1,packet)==0,"bridge refuses "+fault)
		check(velocities()==[Vector2.ZERO,0.0],"no partial mutation "+fault)
	reset_body(); states=bridge.pack_gcr_compound_states(centers,sizes)
	check(bridge.apply_gcr_results(1,response(states))==0,"independent consumer refuses compoundversion")
	bridge.shutdown(); viewport.queue_free()

func _run() -> void:
	native_protocol()
	material_controls()
	if not source.is_empty():
		await bridge_protocol()
	print("GCR_DETACHMENT_MECHANICAL ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"platform":OS.get_name(),"scope":"lease/geometry/actual application only; no efficacy trajectory"}))
	quit(0 if failures.is_empty() else 1)
