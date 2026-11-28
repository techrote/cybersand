extends SceneTree

# Production Workbench session, genuine native materials and real Rapier bodies.
# This synchronous source-bound apparatus is not ordinary-window playfeel or
# Windows/NVIDIA acceptance. All compared controllers share geometry and budget.
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Usables = preload("res://scripts/physical_usable_runtime.gd")
const Perception = preload("res://scripts/ambient/ambient_perception.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const DT := 1.0 / 60.0
const EXTENT := Vector2i(512,256)
const BUDGET := 240
const MODELS := ["runner", "monowheel", "4ly_trainer"]
const STARTS := [Vector2(80,175),Vector2(220,185),Vector2(352,124)]
var checks := 0
var failures: Array[String] = []
var campaigns: Array = []
var completed: Array[String] = []


func source_identity() -> Dictionary:
	var hashes := {}
	var windows := OS.get_name()=="Windows"
	var selected := {"native":"addons/cybersand_native/bin/" + (
		"cybersand_native.windows.x86_64.dll" if windows else "libcybersand_native.linux.x86_64.so"),
		"rapier":"addons/godot-rapier2d/bin/" + (
		"libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if windows else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")}
	var runtime_supported := OS.get_name() in ["Linux","Windows"] and OS.has_feature("x86_64")
	for path: String in ["scripts/ambient/ambient_engine.gd","scripts/ambient/ambient_modules.gd",
		"scripts/ambient/ambient_perception.gd","scripts/ambient/ambient_actuator.gd",
		"scripts/ambient/ambient_profile.gd","scripts/physical_actor_session.gd",
		"scripts/physical_actor_rig.gd","scripts/physical_actor_catalog.gd",
		"scripts/physical_actor_script.gd","scripts/workbench_actor_control.gd",
		"scripts/workbench_actor_catalog.gd","scripts/workbench_physics_bridge.gd",
		"scripts/rapier_physics_bridge.gd","scripts/physical_flight_controller.gd",
		"scripts/physical_flight_profile.gd","tests/test_ambient_native_motion.gd",
		"tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json",
		"addons/cybersand_native/cybersand_native.gdextension",
		"addons/godot-rapier2d/godot-rapier2d.gdextension"]:
		hashes[path]=FileAccess.get_sha256("res://"+path)
	var runtime_artifacts := {}
	if runtime_supported:
		for owner: String in selected:
			var path: String = selected[owner]
			hashes[path]=FileAccess.get_sha256("res://"+path)
			runtime_artifacts[owner]={"path":path,"sha256":hashes[path]}
	return {"godot":Engine.get_version_info().string,"platform":OS.get_name(),
		"display_server":DisplayServer.get_name(),"captured_utc":Time.get_datetime_string_from_system(true),
		"runtime_supported":runtime_supported,"runtime_artifacts":runtime_artifacts,
		"godot_executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),"sha256":hashes}


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_NATIVE_MOTION: " + label)


func make_profile(model: String) -> Dictionary:
	var seek := Profile.make_module("seek_material", "oil")
	seek.params.pace = 0.45
	seek.params.standoff = 12.0
	var avoid := Profile.make_module("avoid_material", "water")
	var wander := Profile.make_module("wander", "roam")
	wander.weight = 0.1
	wander.params.pace = 0.2
	var boundary := Profile.make_module("avoid_boundary", "boundary")
	var profile := {"version":1, "id":"native-ambient", "name":"Native ambient fixture",
		"description":"Identical modular Oil attraction and Water aversion across actual rigs.",
		"seed":1701, "shared_seed":false, "modules":[seek,avoid,wander,boundary]}
	if model != "4ly_trainer": profile.modules.append(Profile.make_module("avoid_ledge", "ledge"))
	return profile


func definition(model: String, slot: int, mode: String) -> Dictionary:
	var control := Registry.default_control(model)
	control.source = "scripted" if mode == "scripted" else "policy"
	control.policy = "ambient" if mode == "ambient" else "external"
	control.usable_index = -1
	if mode == "ambient": control["ambient"] = make_profile(model)
	return {"model":model, "instance_id":100+slot, "position":STARTS[slot],
		"producer":Registry.producer_for(control.source), "usable_index":-1,
		"canvas_extent":EXTENT, "workbench_control":control,
		"workbench_options":{"response":"LA-SELECTIVE", "budget":20.0,
			"mass_multiplier":1.0, "inertia_multiplier":1.0,
			"thrust_multiplier":1.0, "torque_multiplier":1.0, "boost_multiplier":2.0}}


func material_snapshot(world: Object, packet: Dictionary, prior: CyberSimulationSnapshot,
		epoch: int, serial: int) -> CyberSimulationSnapshot:
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.backend_name = world.get_backend_name()
	snapshot.rigid_body_epoch = epoch
	snapshot.render_world_generation = 1
	snapshot.serial = serial
	snapshot.tick_index = int(world.tick_index)
	snapshot.simulation_world_revision = int(world.revision)
	if not PackedByteArray(packet.cells).is_empty():
		snapshot.render_snapshot_serial = serial
		snapshot.render_tick_index = int(world.tick_index)
		snapshot.world_revision = int(world.revision)
		snapshot.render_full_refresh = bool(packet.full_refresh)
		snapshot.render_channels = int(packet.channels)
		snapshot.render_patch_rectangles = packet.rectangles
		snapshot.render_patch_cells = packet.cells
	elif prior != null:
		snapshot.render_snapshot_serial = prior.render_snapshot_serial
		snapshot.render_tick_index = prior.render_tick_index
		snapshot.world_revision = prior.world_revision
		snapshot.render_full_refresh = prior.render_full_refresh
		snapshot.render_channels = prior.render_channels
		snapshot.render_patch_rectangles = prior.render_patch_rectangles
		snapshot.render_patch_cells = prior.render_patch_cells
	return snapshot


func run_campaign(mode: String) -> void:
	var started := Time.get_ticks_usec()
	var native_bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var checked := Contract.validate(Contract.parse(FileAccess.get_file_as_string(
		"res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json")).definition)
	var owner := Node2D.new()
	root.add_child(owner)
	var session := Session.new()
	owner.add_child(session)
	var roster: Array = []
	for slot: int in range(MODELS.size()): roster.append(definition(MODELS[slot],slot,mode))
	check(session.configure(roster,owner.get_world_2d().space,11),mode+": production physical session configured")
	if not session.active():
		owner.free()
		return
	var sample: Dictionary = session.pack_workbench_sample()
	var rectangles := PackedInt32Array([0,200,512,8,1,
		110,188,28,12,16,250,188,28,12,16,
		382,134,32,4,1,382,112,4,22,1,410,112,4,22,1,386,120,24,14,16])
	var token: int = native_bridge.prepare_liquid_world(world,rectangles,checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),
		native_bridge.default_liquid_policy(),{"workbench_extent":EXTENT,
			"workbench_response":"LA-SELECTIVE","workbench_sample":sample,
			"region":PackedInt32Array([0,0,EXTENT.x,EXTENT.y]),"intent":"exploratory",
			"definition_hash":checked.hash,"initial_bodies":session.bridge.pack_body_states(),
			"workbench_worker_threads":1})
	check(token>0 and native_bridge.commit_liquid_world(world,token),mode+": native prepared cells and actual body map")
	if token<=0:
		session.close()
		owner.free()
		return
	check(session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles()),mode+": native terrain copied into Rapier")
	session.bridge.process_hard_surface_collider_budget(256,0)
	var physical_usables := Usables.new()
	# This independent observer samples the exact same publications/cadence for
	# EVERY controller. Its results never enter the producer or command stream.
	var evaluator := Perception.new()
	check(evaluator.configure(EXTENT,session.epoch),mode+": separate evaluator bound to current owner")
	var snapshot: CyberSimulationSnapshot = null
	var terrain_revision: int = world.get_hard_surface_revision()
	var rows: Array = []
	var random_streams: Array = []
	for slot: int in range(MODELS.size()):
		rows.append({"model":MODELS[slot],"first":STARTS[slot],"last":STARTS[slot],
			"min_x":STARTS[slot].x,"max_x":STARTS[slot].x,"contact_samples":0,
			"material_acquisitions":0,"avoidance_decisions":0,"first_distance":-1.0,"minimum_distance":INF,
			"evaluator_oil_observations":0,"evaluator_first_oil_distance":-1.0,
			"evaluator_minimum_oil_distance":INF,"evaluator_last_oil_distance":-1.0,
			"first_observed_oil_point":null,"minimum_distance_to_first_oil_point":INF,
			"evaluator_water_observations":0,"move_active_decisions":0,"neutral_move_decisions":0,
			"intentional_idle_decisions":0,"action_x_sign_changes":0,"intent_x_sign_changes":0,
			"decision_usec_max":0,"sensor_usec_max":0,
			"stalled_active_intervals":0,"active_intervals":0,"physical_path_cells":0.0,
			"canvas_center_incidents":0,"ground_support_loss_events":0,
			"last_intent":{},"trace":[]})
		var random := RandomNumberGenerator.new()
		random.seed = 1701+100+slot
		random_streams.append(random)
	for step: int in range(BUDGET):
		if step==180:
			world.emit_disc(124,192,6,3)
			world.emit_disc(264,192,6,3)
		if step % 6==0:
			snapshot = material_snapshot(world,world.take_render_snapshot(step==0),snapshot,session.epoch,step+1)
			session.ingest_ambient_snapshot(snapshot)
			check(evaluator.ingest_snapshot(snapshot,EXTENT,session.epoch),mode+": independent native evaluator publication admitted")
			if mode=="random":
				for slot: int in range(MODELS.size()):
					var view: Dictionary = session.workbench_policy_observation(100+slot)
					var random: RandomNumberGenerator = random_streams[slot]
					var movement := Vector2(float(random.randi_range(-1,1))*0.4,
						float(random.randi_range(-1,1))*0.3 if slot==2 else 0.0)
					var action := {"move":movement}
					if slot!=2: action["effort"] = 0.7
					check(session.submit_workbench_policy(100+slot,Session.make_command(view,
						int(view.last_sequence)+1,action,12)),mode+": random legal action admitted")
		session.advance(DT)
		if step%6==0:
			for slot: int in range(MODELS.size()):
				var control: Dictionary = session.workbench_control(100+slot)
				var diagnostics: Dictionary = control.diagnostics
				var intent: Dictionary = diagnostics.get("ambient",{}).get("intent",{})
				var materials: Dictionary = diagnostics.get("environment",{}).get("materials",{})
				var observed: Dictionary = control.observation
				var evaluated: Dictionary = evaluator.observe(observed,Perception.requests(make_profile(MODELS[slot])),
					{"capabilities":Actuator.capabilities(MODELS[slot]),"bounds":Rect2(Vector2.ZERO,Vector2(EXTENT)),
					"home":STARTS[slot],"simulation_time_seconds":session._completed_time_seconds})
				var action: Dictionary = session._commands[slot].duplicate(true)
				var movement: Vector2 = action.get("move",Vector2.ZERO)
				var row: Dictionary = rows[slot]
				row.decision_usec_max=maxi(row.decision_usec_max,int(control.decision_usec))
				row.sensor_usec_max=maxi(row.sensor_usec_max,int(control.sensor_usec))
				var trace: Array = row.trace
				var delta_position := Vector2.ZERO
				if not trace.is_empty():
					var prior: Dictionary = trace.back()
					delta_position=Vector2(observed.position)-Vector2(prior.position)
					if Vector2(prior.action_move).length()>0.05:
						row.active_intervals+=1
						if delta_position.length()<0.25: row.stalled_active_intervals+=1
				if movement.length()>0.05: row.move_active_decisions+=1
				else: row.neutral_move_decisions+=1
				if not intent.is_empty() and (Vector2(intent.direction)==Vector2.ZERO or float(intent.pace)<=0.0):
					row.intentional_idle_decisions+=1
				var action_sign := signf(movement.x) if absf(movement.x)>0.05 else 0.0
				if action_sign!=0.0:
					if row.has("last_action_sign") and row.last_action_sign!=action_sign: row.action_x_sign_changes+=1
					row["last_action_sign"]=action_sign
				var intent_x: float = Vector2(intent.get("direction",Vector2.ZERO)).x
				var intent_sign := signf(intent_x) if absf(intent_x)>0.05 else 0.0
				if intent_sign!=0.0:
					if row.has("last_intent_sign") and row.last_intent_sign!=intent_sign: row.intent_x_sign_changes+=1
					row["last_intent_sign"]=intent_sign
				var evaluator_oil: Dictionary = evaluated.materials.targets.get("16",{})
				var evaluator_water: Dictionary = evaluated.materials.targets.get("3",{})
				if bool(evaluator_oil.get("available",false)) and bool(evaluator_oil.get("present",false)):
					row.evaluator_oil_observations+=1
					row.evaluator_last_oil_distance=float(evaluator_oil.distance)
					if float(row.evaluator_first_oil_distance)<0.0:
						row.evaluator_first_oil_distance=float(evaluator_oil.distance)
						row.first_observed_oil_point=Vector2(evaluator_oil.nearest)
					row.evaluator_minimum_oil_distance=minf(row.evaluator_minimum_oil_distance,evaluator_oil.distance)
				if row.first_observed_oil_point is Vector2:
					row.minimum_distance_to_first_oil_point=minf(row.minimum_distance_to_first_oil_point,
						Vector2(observed.position).distance_to(row.first_observed_oil_point))
				if bool(evaluator_water.get("available",false)) and bool(evaluator_water.get("present",false)):
					row.evaluator_water_observations+=1
				var target: Dictionary = materials.get("targets",{}).get("16",{})
				if bool(target.get("present",false)):
					rows[slot].material_acquisitions+=1
					var distance := float(target.distance)
					if rows[slot].first_distance<0.0: rows[slot].first_distance=distance
					rows[slot].minimum_distance=minf(rows[slot].minimum_distance,distance)
				if str(intent.get("active_override",""))=="water":
					rows[slot].avoidance_decisions+=1
					var water: Dictionary = materials.targets.get("3",{})
					if bool(water.get("present",false)):
						check(Vector2(intent.direction).dot(Vector2(water.nearest)-Vector2(control.observation.position))<=0.001,
							mode+": higher-priority Water intent points away from actual observation")
				rows[slot].last_intent=intent
				rows[slot].trace.append({"tick":session.tick,"position":control.observation.position,
					"actual_interval_displacement":delta_position,"action_move":movement,
					"action_effort":action.get("effort",null),"intent":intent.get("direction",Vector2.ZERO),
					"intent_pace":intent.get("pace",null),"override":intent.get("active_override",""),
					"material_sample_tick":evaluated.materials.sample_tick,"material_revision":evaluated.materials.revision,
					"oil":evaluator_oil,"water":evaluator_water})
		sample=session.pack_workbench_sample()
		if not world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true):
			check(false,mode+": native coupling refused actual moving multipart sample at tick"+str(step))
			break
		var feedback: Dictionary = physical_usables.step(DT,world,sample.equipment_frame,sample.equipment_requests)
		if not str(feedback.get("last_error","")).is_empty():
			check(false,mode+": matching equipment frame refused")
			break
		session.accept_equipment_feedback(feedback)
		if not world.simulation_tick():
			check(false,mode+": native progression refused")
			break
		session.apply_workbench_results(step+1,world.workbench_coupling_results())
		if world.get_hard_surface_revision()!=terrain_revision:
			session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles())
			session.bridge.process_hard_surface_collider_budget(256,0)
			terrain_revision=world.get_hard_surface_revision()
		session.bridge.step()
		session.complete_step()
		for slot: int in range(MODELS.size()):
			var observed: Dictionary = session._view(slot,false)
			rows[slot].physical_path_cells+=Vector2(observed.position).distance_to(rows[slot].last)
			if not Rect2(Vector2.ZERO,Vector2(EXTENT)).has_point(observed.position): rows[slot].canvas_center_incidents+=1
			if MODELS[slot]!="4ly_trainer" and rows[slot].get("was_grounded",false) and not bool(observed.grounded):
				rows[slot].ground_support_loss_events+=1
			rows[slot]["was_grounded"]=bool(observed.grounded)
			rows[slot].last=observed.position
			rows[slot].min_x=minf(rows[slot].min_x,observed.position.x)
			rows[slot].max_x=maxf(rows[slot].max_x,observed.position.x)
			if bool(observed.grounded): rows[slot].contact_samples+=1
	check(session.tick==BUDGET and int(world.tick_index)==BUDGET,mode+": both native and Rapier completed exact budget")
	if mode=="ambient":
		for slot: int in range(MODELS.size()):
			var row: Dictionary = rows[slot]
			check(row.max_x-row.min_x>2.0,mode+": genuine horizontal physical travel for "+MODELS[slot])
			check(int(row.material_acquisitions)>0,mode+": actual local Oil acquired by "+MODELS[slot])
			check(session.workbench_control(100+slot).accepted>=BUDGET/6,
				mode+": production issued-observation commands consumed for "+MODELS[slot])
		check(int(rows[0].contact_samples)>0 and int(rows[1].contact_samples)>0,
			mode+": ground and wheel families touch actual material terrain")
		check(int(rows[0].avoidance_decisions)+int(rows[1].avoidance_decisions)>0,
			mode+": native Water arrival activates higher-priority avoidance")
		var before_tick := session.tick
		var before_clock := session._completed_time_seconds
		var before_intent: Dictionary = session.workbench_control(100).diagnostics.get("ambient",{}).duplicate(true)
		session.set_suspended(true)
		for ignored: int in range(120): session.advance(DT)
		check(session.tick==before_tick and session._completed_time_seconds==before_clock,
			mode+": pause does not advance gameplay time")
		check(session.workbench_control(100).lease_remaining==0,mode+": pause revokes action lease")
		session.set_suspended(false)
		check(session.workbench_control(100).diagnostics.get("ambient",{}).get("elapsed_seconds",-1.0)==
			before_intent.get("elapsed_seconds",-2.0),mode+": pause preserves ephemeral module clock")
	for slot: int in range(rows.size()):
		if not is_finite(float(rows[slot].minimum_distance)): rows[slot].minimum_distance=-1.0
		for key: String in ["evaluator_minimum_oil_distance","minimum_distance_to_first_oil_point"]:
			if not is_finite(float(rows[slot][key])): rows[slot][key]=-1.0
		for key: String in ["last_action_sign","last_intent_sign","was_grounded"]: rows[slot].erase(key)
		check(rows[slot].evaluator_oil_observations>0,mode+": separate sensor observed actual Oil for "+MODELS[slot])
		check(rows[slot].move_active_decisions+rows[slot].neutral_move_decisions==BUDGET/6,
			mode+": activity metrics cover exact decision budget for "+MODELS[slot])
		rows[slot]["accepted_commands"]=session.workbench_control(100+slot).accepted
		rows[slot]["rejected_commands"]=session.workbench_control(100+slot).rejected
		rows[slot]["total_decision_usec"]=session.workbench_control(100+slot).total_decision_usec
	var result := {"controller":mode,"actors":rows,"native_ticks":int(world.tick_index),
		"rapier_ticks":session.tick,"source_geometry":Array(rectangles),
		"ambient_profile_seed":1701,"ambient_seed_mode":"per authored instance and module ID; engine-defined mixing",
		"random_action_seeds":[1801,1802,1803],"scripted_seed":"existing deterministic local feedback; no injected randomness",
		"decision_period_ticks":6,"budget_ticks":BUDGET,"native_threads":1,
		"physical_parts":sample.bodies.size(),"native_masks":sample.states.size()/17,
		"perception":session._ambient_perception.diagnostics(),"independent_evaluator":evaluator.diagnostics(),
		"metric_definitions":{"active_move":"command move length >0.05; zero flight move remains active hover",
			"stalled_interval":"preceding active move and actual displacement <0.25 cells across six physics ticks",
			"direction_change":"nonzero X sign changes with 0.05 deadzone; includes intentional braking",
			"material_distance":"nearest observed numeric-ID sample; material itself can flow",
			"fixed_point_distance":"distance to first observed Oil sample coordinate, even after material moves",
			"ground_support_loss":"grounded to airborne transition, without asserting a ledge cause"},
		"elapsed_usec":Time.get_ticks_usec()-started}
	campaigns.append(result)
	session.close()
	owner.free()
	completed.append(mode)


func run() -> void:
	var identities := source_identity()
	check(identities.runtime_supported,"source custody supports actual selected Linux/Windows x86_64 artifacts")
	check(ClassDB.class_exists("CyberNativeCellWorld") and ClassDB.class_exists("RapierPhysicsServer2D"),
		"actual native and Rapier extensions available")
	if failures.is_empty():
		for mode: String in ["ambient","scripted","random"]: run_campaign(mode)
	check(completed==["ambient","scripted","random"],"all exact-budget comparison campaigns completed")
	var result := {"case":"AMBIENT-001 production session actual native/Rapier locomotion",
		"checks":checks,"failures":failures,"campaigns":campaigns,
		"source_identity":identities,
		"scope":"synchronous coupled apparatus; physical Windows/NVIDIA playfeel untested"}
	var path := OS.get_environment("CYBERSAND_AMBIENT_MOTION_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(Registry._json_value(result),"\t"))
	var summary := result.duplicate(true)
	for campaign: Dictionary in summary.campaigns:
		for actor: Dictionary in campaign.actors: actor.erase("trace")
	print("AMBIENT_NATIVE_MOTION ",JSON.stringify(Registry._json_value(summary)))
	quit(0 if failures.is_empty() else 1)
