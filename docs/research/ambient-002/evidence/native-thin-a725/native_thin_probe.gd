extends SceneTree

# External observation diagnostic. The frozen application source stays untouched.
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Usables = preload("res://scripts/physical_usable_runtime.gd")
const EXTENT := Vector2i(256,256)
const DT := 1.0/60.0
var failures: Array[String] = []
var checks := 0
var result: Dictionary = {}
var viewport: SubViewport
var session: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func value_digest(value: Variant) -> String:
	return digest(JSON.stringify(Registry._json_value(value)).to_utf8_buffer())

func publication(world: Object, packet: Dictionary, serial: int) -> CyberSimulationSnapshot:
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.backend_name = world.get_backend_name()
	snapshot.rigid_body_epoch = session.epoch
	snapshot.render_world_generation = 1
	snapshot.serial = serial
	snapshot.tick_index = int(world.tick_index)
	snapshot.simulation_world_revision = int(world.revision)
	snapshot.render_snapshot_serial = serial
	snapshot.render_tick_index = int(world.tick_index)
	snapshot.world_revision = int(world.revision)
	snapshot.render_full_refresh = bool(packet.full_refresh)
	snapshot.render_channels = int(packet.channels)
	snapshot.render_patch_rectangles = packet.rectangles
	snapshot.render_patch_cells = packet.cells
	return snapshot

func outside_parts(cell: Vector2i, view: Dictionary) -> Array:
	# Separating-axis test between the complete native cell square and each
	# copied rectangular part. A positive margin proves they do not overlap.
	var evidence: Array = []
	for part: Dictionary in view.parts:
		var angle := float(part.rotation)
		var ax := Vector2.RIGHT.rotated(angle)
		var ay := Vector2.DOWN.rotated(angle)
		var half := Vector2(part.size)*0.5
		var delta := Vector2(cell)+Vector2(0.5,0.5)-Vector2(part.position)
		var margin := -INF
		for axis: Vector2 in [Vector2.RIGHT,Vector2.DOWN,ax,ay]:
			var body_radius := half.x*absf(ax.dot(axis))+half.y*absf(ay.dot(axis))
			var cell_radius := 0.5*(absf(axis.x)+absf(axis.y))
			margin = maxf(margin,absf(delta.dot(axis))-body_radius-cell_radius)
		evidence.append({"part_index":part.index,"shape":part.shape,"native_mask":part.native_mask,
			"separating_axis_margin_cells":margin,"outside_entire_part":margin>0.0})
	return evidence

func scan_publication(packet: Dictionary) -> Dictionary:
	# Verification only: this complete copied-byte scan is excluded from the
	# bounded policy query read counts and repeated-query timing below.
	var positions := {"16":[],"3":[]}
	var bytes := PackedByteArray(packet.cells)
	var rects := PackedInt32Array(packet.rectangles)
	var channels := int(packet.channels)
	var visited := 0
	for offset: int in range(0,rects.size(),6):
		for y: int in range(rects[offset+3]):
			for x: int in range(rects[offset+2]):
				var material_id := int(bytes[rects[offset+4]+y*rects[offset+5]+x*channels])
				var key := str(material_id)
				if positions.has(key): positions[key].append(Vector2i(rects[offset]+x,rects[offset+1]+y))
				visited += 1
	return {"copied_cells_scanned":visited,"positions":positions,
		"excluded_from_policy_budget_and_query_timing":true}

func query(profile: Dictionary, view: Dictionary) -> Dictionary:
	var begun := Time.get_ticks_usec()
	var environment: Dictionary = session._ambient_environment(0,view,profile)
	var elapsed := Time.get_ticks_usec()-begun
	return {"materials":environment.materials,"elapsed_owner_call_usec":elapsed,
		"owner_sensor_usec":int(session.workbench_control(100).sensor_usec)}

func finish() -> void:
	if is_instance_valid(session): session.close()
	if is_instance_valid(viewport): viewport.free()
	await process_frame
	result["checks"] = checks
	result["failures"] = failures
	result["complete"] = failures.is_empty()
	var report := FileAccess.open(OS.get_environment("CYBERSAND_THIN_REPORT"),FileAccess.WRITE)
	if report == null:
		push_error("Native thin probe report could not be opened")
		quit(1)
		return
	report.store_string(JSON.stringify(Registry._json_value(result),"\t"))
	report.close()
	print("AMBIENT2_NATIVE_THIN ",JSON.stringify({"complete":result.complete,"checks":checks,
		"failures":failures,"source_revision":result.source_revision,
		"diagnostic_sha256":result.diagnostic_sha256,"behavioral_episodes_added":0}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	result = {"case":"AMBIENT-002 native thin-patch observation diagnostic",
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"diagnostic_sha256":FileAccess.get_sha256(get_script().resource_path),
		"godot_executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"behavioral_episodes_added":0,"actual_worlds":1,"actual_actors":1,
		"ownership":"one synchronous production PhysicalActorSession/native owner",
		"timing_scope":"100 alternating warm repeated owner calls per arm; no policy/native/physics advancement during queries; not production cadence cost"}
	var profile: Dictionary = Profile.preset("cautious_flyer")
	for module: Dictionary in profile.modules:
		module.enabled = str(module.type) in ["investigate_material","avoid_material"]
		if module.enabled: module.params.radius = 50
	profile.perception = {"spacing_cells":4,"near_radius_cells":8,"refine_boundaries":true}
	if not check(Profile.validate(profile,[],Actuator.capabilities("4ly_trainer")).is_empty(),"valid two-material diagnostic profile"):
		await finish(); return
	var control: Dictionary = Registry.default_control("4ly_trainer")
	control.source = "policy"
	control.policy = "ambient"
	control.usable_index = -1
	control.decision_ticks = 6
	control["ambient"] = profile
	var definition := {"model":"4ly_trainer","instance_id":100,"position":Vector2(128.5,100.5),
		"producer":Registry.producer_for(control.source),"usable_index":-1,"canvas_extent":EXTENT,
		"workbench_control":control,"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,
		"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,
		"torque_multiplier":1.0,"boost_multiplier":2.0}}
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var owner := Node2D.new()
	viewport.add_child(owner)
	session = Session.new()
	owner.add_child(session)
	if not check(session.configure([definition],owner.get_world_2d().space,11),"real Trainer admitted to production owner"):
		await finish(); return
	var native_bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var fixture := Contract.validate(Contract.parse(FileAccess.get_file_as_string(
		"res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json")).definition)
	var sample: Dictionary = session.pack_workbench_sample()
	var rectangles := PackedInt32Array([0,200,256,8,1,0,0,8,200,1,248,0,8,200,1])
	var token: int = native_bridge.prepare_liquid_world(world,rectangles,fixture.transport.packed,
		PackedInt32Array(fixture.definition.water_semantics),PackedInt32Array(),native_bridge.default_liquid_policy(),
		{"workbench_extent":EXTENT,"workbench_response":"LA-SELECTIVE","workbench_sample":sample,
		"region":PackedInt32Array([0,0,256,256]),"intent":"exploratory","definition_hash":fixture.hash,
		"seed":1701,"initial_bodies":session.bridge.pack_body_states(),"workbench_worker_threads":1})
	if not check(token>0 and native_bridge.commit_liquid_world(world,token),"real native World committed"):
		await finish(); return
	check(session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles()),"native hard surfaces copied to Rapier")
	session.bridge.process_hard_surface_collider_budget(256,0)
	var initial_packet: Dictionary = world.take_render_snapshot(true)
	session.ingest_ambient_snapshot(publication(world,initial_packet,1))
	session.advance(DT)
	sample = session.pack_workbench_sample()
	if not check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true),"real coupling admitted"):
		await finish(); return
	var physical_usables := Usables.new()
	var feedback: Dictionary = physical_usables.step(DT,world,sample.equipment_frame,sample.equipment_requests)
	check(str(feedback.get("last_error","")).is_empty(),"equipment owner feedback valid")
	session.accept_equipment_feedback(feedback)
	if not check(world.simulation_tick(),"one native tick completed"):
		await finish(); return
	session.apply_workbench_results(1,world.workbench_coupling_results())
	session.bridge.step()
	session.complete_step()
	var view: Dictionary = session.workbench_control(100).observation
	var position := Vector2(view.position)
	check(position.is_finite() and str(view.get("fault","")).is_empty(),"finite fault-free public admitted pose")
	check(int(world.tick_index)==1 and session.bridge.manual_step_count()==1,"one native and one physical step")
	check(view.parts.size()==1 and view.parts[0].shape=="rectangle" and view.parts[0].native_mask=="matching_rectangle","Trainer copied part matches exact rectangular native mask")
	var near_cell := Vector2i(floori(position.x)+1,floori(position.y)-6)
	if near_cell.x%4==0: near_cell.x += 1
	var far_cell := Vector2i(floori(position.x)+41,floori(position.y)-6)
	if far_cell.x%4==0: far_cell.x += 1
	var near_distance := position.distance_to(Vector2(near_cell)+Vector2(0.5,0.5))
	var far_distance := position.distance_to(Vector2(far_cell)+Vector2(0.5,0.5))
	var near_outside := outside_parts(near_cell,view)
	var far_outside := outside_parts(far_cell,view)
	check(near_distance<=8.0 and far_distance>8.0 and far_distance<50.0,"both material cells inside scope, only Oil inside near field")
	check(near_cell.x%4!=0 and far_cell.x%4!=0,"both cells lie off global four-cell lattice")
	for part: Dictionary in near_outside+far_outside:
		if not check(bool(part.outside_entire_part),"complete painted cell square outside actual copied part"):
			await finish(); return
	world.emit_disc(near_cell.x,near_cell.y,0,16)
	world.emit_disc(far_cell.x,far_cell.y,0,3)
	var packet: Dictionary = world.take_render_snapshot(true)
	check(bool(packet.full_refresh),"full native copied publication available")
	var decoded := scan_publication(packet)
	check(decoded.positions["16"]==[near_cell] and decoded.positions["3"]==[far_cell],"actual published material IDs contain exactly the two authored one-cell patches")
	var payload := FileAccess.open(OS.get_environment("CYBERSAND_THIN_CELLS"),FileAccess.WRITE)
	payload.store_buffer(PackedByteArray(packet.cells))
	payload.close()
	var snapshot := publication(world,packet,2)
	session.ingest_ambient_snapshot(snapshot)
	var coarse: Dictionary = profile.duplicate(true)
	coarse.perception = {"spacing_cells":4,"near_radius_cells":0,"refine_boundaries":false}
	var pose_hash := value_digest(view)
	var packet_hash := digest(PackedByteArray(packet.cells))
	var revision := int(world.revision)
	var warm_coarse := query(coarse,view)
	var warm_adaptive := query(profile,view)
	var timings := {"coarse":[],"adaptive":[]}
	var owner_timings := {"coarse":[],"adaptive":[]}
	var samples := {"coarse":[],"adaptive":[]}
	for repeat: int in range(100):
		var order: Array = ["coarse","adaptive"] if repeat%2==0 else ["adaptive","coarse"]
		for arm: String in order:
			var measured := query(coarse if arm=="coarse" else profile,view)
			timings[arm].append(measured.elapsed_owner_call_usec)
			owner_timings[arm].append(measured.owner_sensor_usec)
			samples[arm].append(int(measured.materials.sample_count))
			check(measured.materials==warm_coarse.materials if arm=="coarse" else measured.materials==warm_adaptive.materials,"repeated query retains identical observed values")
	var c: Dictionary = warm_coarse.materials
	var a: Dictionary = warm_adaptive.materials
	check(bool(c.available) and bool(a.available),"both queries admit same native publication")
	check(not bool(c.targets["16"].present) and bool(a.targets["16"].present),"adaptive sees near one-cell Oil that coarse sampling misses")
	check(Vector2(a.targets["16"].nearest)==Vector2(near_cell)+Vector2(0.5,0.5),"adaptive target identifies exact published cell center")
	for materials: Dictionary in [c,a]:
		check(not bool(materials.targets["3"].present) and materials.targets["3"].status=="unobserved_in_incomplete_coverage","far one-cell Water remains explicitly unobserved under incomplete coverage")
		check(not bool(materials.coverage_complete) and not bool(materials.budget_exhausted) and int(materials.sample_count)<=4096,"query budget and incomplete coverage explicit")
		check(int(materials.sample_tick)==1 and int(materials.publication_serial)==2 and int(materials.revision)==revision,"same actual publication/tick/revision bound to query")
	var after: Dictionary = world.take_render_snapshot(true)
	check(packet_hash==digest(PackedByteArray(after.cells)) and revision==int(world.revision),"native publication unchanged throughout query arms")
	check(pose_hash==value_digest(session.workbench_control(100).observation),"actual public actor pose/state unchanged throughout query arms")
	check(int(world.tick_index)==1 and session.bridge.manual_step_count()==1,"queries advance no native or physical step")
	result.merge({"profile":profile,"coarse_profile":coarse,"actor_observation":view,"actor_observation_sha256":pose_hash,
		"native_tick":int(world.tick_index),"physical_ticks":session.bridge.manual_step_count(),"owner_epoch":session.epoch,
		"native_revision":revision,"publication_serial":2,"world_generation":1,
		"near":{"material_id":16,"cell":near_cell,"distance_cells":near_distance,"outside_parts":near_outside},
		"far":{"material_id":3,"cell":far_cell,"distance_cells":far_distance,"outside_parts":far_outside},
		"publication":{"sha256":packet_hash,"bytes":PackedByteArray(packet.cells).size(),"channels":int(packet.channels),
		"rectangles":packet.rectangles,"verification_scan":decoded},"coarse":warm_coarse,"adaptive":warm_adaptive,
		"warm_repeated_query_elapsed_usec":timings,"warm_repeated_owner_sensor_usec":owner_timings,
		"warm_repeated_read_counts":samples,"queries_per_arm":101,
		"limitations":["Observation comparison only; zero added behavioral episodes.",
		"Repeated warm query elapsed times exclude native advancement, Rapier, publication copy and complete diagnostic verification scan.",
		"One admitted Trainer pose and two thin native patches do not establish population performance or universal thin-feature coverage."]})
	await finish()
