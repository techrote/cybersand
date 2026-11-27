extends SceneTree

# Longer matched observation of genuine production ambient controllers. Each
# arm owns a fresh native World and Rapier session. This measures behaviour and
# physical progression; differences are not aesthetic or pathfinding scores.
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Usables = preload("res://scripts/physical_usable_runtime.gd")
const Perception = preload("res://scripts/ambient/ambient_perception.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const DT := 1.0 / 60.0
const EXTENT := Vector2i(512,256)
const START := Vector2(220,175)
const MODEL := "runner"
const INSTANCE := 100
const SEED := 1701
const TICKS := 1800
const CADENCE := 6
const PROFILES := ["oil_moth","shy_crawler","idle_mechanic"]
const GEOMETRY := [0,200,512,8,1,0,0,8,200,1,504,0,8,200,1,
	152,184,4,16,1,180,184,4,16,1,156,190,24,10,3,
	258,184,4,16,1,290,184,4,16,1,262,190,28,10,16]
var checks := 0
var failures: Array[String] = []
var campaigns: Array = []
var completed: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_PERSONALITIES: " + label)
	return value


func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func source_identity() -> Dictionary:
	var hashes := {}
	var windows := OS.get_name()=="Windows"
	var selected := {"native":"addons/cybersand_native/bin/" + (
		"cybersand_native.windows.x86_64.dll" if windows else "libcybersand_native.linux.x86_64.so"),
		"rapier":"addons/godot-rapier2d/bin/" + (
		"libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if windows else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")}
	for path: String in ["scripts/ambient/ambient_engine.gd","scripts/ambient/ambient_modules.gd",
		"scripts/ambient/ambient_perception.gd","scripts/ambient/ambient_actuator.gd",
		"scripts/ambient/ambient_profile.gd","scripts/physical_actor_session.gd",
		"scripts/physical_actor_rig.gd","scripts/physical_actor_catalog.gd",
		"scripts/physical_actor_script.gd","scripts/workbench_actor_control.gd",
		"scripts/workbench_actor_catalog.gd","scripts/workbench_physics_bridge.gd",
		"scripts/rapier_physics_bridge.gd","data/ambient/profiles.json",
		"tests/test_ambient_personalities_native.gd",
		"tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json",
		"addons/cybersand_native/cybersand_native.gdextension",
		"addons/godot-rapier2d/godot-rapier2d.gdextension"]:
		hashes[path]=FileAccess.get_sha256("res://"+path)
	var runtimes := {}
	for key: String in selected:
		var path: String = selected[key]
		runtimes[key]={"path":path,"sha256":FileAccess.get_sha256("res://"+path)}
	return {"godot":Engine.get_version_info().string,"platform":OS.get_name(),
		"display_server":DisplayServer.get_name(),"captured_utc":Time.get_datetime_string_from_system(true),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"runtime_supported":OS.get_name() in ["Linux","Windows"] and OS.has_feature("x86_64"),
		"runtime_artifacts":runtimes,"godot_executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"sha256":hashes}


func definition(profile: Dictionary) -> Dictionary:
	var control := Registry.default_control(MODEL)
	control.source="policy"
	control.policy="ambient"
	control.decision_ticks=CADENCE
	control.usable_index=-1
	control["ambient"]=profile.duplicate(true)
	return {"model":MODEL,"instance_id":INSTANCE,"position":START,"producer":"policy",
		"usable_index":-1,"canvas_extent":EXTENT,"workbench_control":control,
		"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,
			"mass_multiplier":1.0,"inertia_multiplier":1.0,
			"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}}


func publication(world: Object, packet: Dictionary, prior: CyberSimulationSnapshot,
		epoch: int, serial: int) -> CyberSimulationSnapshot:
	var result := CyberSimulationSnapshot.new()
	result.backend_name=world.get_backend_name()
	result.rigid_body_epoch=epoch
	result.render_world_generation=1
	result.serial=serial
	result.tick_index=int(world.tick_index)
	result.simulation_world_revision=int(world.revision)
	if not PackedByteArray(packet.cells).is_empty():
		result.render_snapshot_serial=serial
		result.render_tick_index=int(world.tick_index)
		result.world_revision=int(world.revision)
		result.render_full_refresh=bool(packet.full_refresh)
		result.render_channels=int(packet.channels)
		result.render_patch_rectangles=packet.rectangles
		result.render_patch_cells=packet.cells
	elif prior!=null:
		result.render_snapshot_serial=prior.render_snapshot_serial
		result.render_tick_index=prior.render_tick_index
		result.world_revision=prior.world_revision
		result.render_full_refresh=prior.render_full_refresh
		result.render_channels=prior.render_channels
		result.render_patch_rectangles=prior.render_patch_rectangles
		result.render_patch_cells=prior.render_patch_cells
	return result


func observed_pose(view: Dictionary) -> Dictionary:
	return {"position":view.position,"velocity":view.velocity,"grounded":view.grounded,
		"rotation":view.rotation,"angular_velocity":view.angular_velocity,
		"parts":view.parts.duplicate(true),"energy":view.get("energy",null),
		"charge":view.get("charge",null),"cooldown":view.get("cooldown",null),"fault":view.get("fault","")}


func sample_decision(session: Node, evaluator: RefCounted, row: Dictionary) -> void:
	var control: Dictionary = session.workbench_control(INSTANCE)
	var diagnostics: Dictionary = control.diagnostics
	var ambient: Dictionary = diagnostics.get("ambient",{})
	var intent: Dictionary = ambient.get("intent",{})
	var view: Dictionary = control.observation
	# Equal independently scheduled observation for every profile, including
	# profiles that do not request Oil. Never passed to the controller.
	var evaluated: Dictionary = evaluator.observe(view,[{"material_id":16,"radius_cells":50},
		{"material_id":3,"radius_cells":50}],{"capabilities":Actuator.capabilities(MODEL),
		"bounds":Rect2(Vector2.ZERO,Vector2(EXTENT)),"home":START,
		"simulation_time_seconds":session._completed_time_seconds})
	var action: Dictionary = session._commands[0].duplicate(true)
	var move: Vector2 = action.get("move",Vector2.ZERO)
	var direction: Vector2 = intent.get("direction",Vector2.ZERO)
	var pace: float = intent.get("pace",0.0)
	var override := str(intent.get("active_override",""))
	var selected_rest := override=="rest"
	var intended_active := direction.length()>0.05 and pace>0.0
	var rest_candidate_active := false
	for candidate: Dictionary in intent.get("candidates",[]):
		if str(candidate.type)=="rest": rest_candidate_active=bool(candidate.get("active",false))
	var previous_trace: Array = row.trace
	if not previous_trace.is_empty():
		var previous: Dictionary = previous_trace.back()
		if Vector2(previous.action_move).length()>0.05:
			row.active_intervals+=1
			if Vector2(view.position).distance_to(previous.position)<0.25: row.stalled_active_intervals+=1
		if previous.selected_rest and not selected_rest:
			row.rest_exits+=1
			if not rest_candidate_active:
				row.rest_completed_episodes+=1
				row["awaiting_resume"]=true
			row.rest_episodes.append({"start_seconds":row.rest_started_seconds,
				"end_seconds":session._completed_time_seconds,
				"duration_seconds":session._completed_time_seconds-float(row.rest_started_seconds),
				"selected_decisions":row.rest_episode_decisions,"following_override":override,
				"completed":not rest_candidate_active,
				"end_reason":"arbitration_interrupted" if rest_candidate_active else "timer_expired"})
	if selected_rest:
		if previous_trace.is_empty() or not bool(previous_trace.back().selected_rest):
			row.rest_entries+=1
			row["rest_started_seconds"]=session._completed_time_seconds
			row["rest_episode_decisions"]=0
		row.selected_rest_decisions+=1
		row.rest_episode_decisions+=1
		check(direction==Vector2.ZERO and pace==0.0 and move==Vector2.ZERO,
			str(row.id)+": selected scheduled rest produces genuine neutral intention and action")
	if bool(row.get("awaiting_resume",false)) and intended_active and move.length()>0.05:
		row.rest_to_active_resumptions+=1
		row["awaiting_resume"]=false
		row.resume_events.append({"seconds":session._completed_time_seconds,"position":view.position,
			"direction":direction,"pace":pace,"action_move":move})
	if move.length()>0.05: row.move_active_decisions+=1
	else: row.neutral_move_decisions+=1
	if not intended_active: row.intentional_idle_decisions+=1
	for key: String in ["action","intent"]:
		var x_value: float = move.x if key=="action" else direction.x
		var current_sign := signf(x_value) if absf(x_value)>0.05 else 0.0
		if current_sign!=0.0:
			if row.has("last_"+key+"_sign") and row["last_"+key+"_sign"]!=current_sign:
				row[key+"_x_sign_changes"]+=1
			row["last_"+key+"_sign"]=current_sign
	var candidates: Array = []
	for candidate: Dictionary in intent.get("candidates",[]):
		var active := bool(candidate.get("active",false))
		if str(candidate.type)=="rest" and active: row.rest_candidate_decisions+=1
		if str(candidate.type)=="wander" and active and bool(candidate.get("idle",false)):
			row.wander_idle_candidates+=1
		candidates.append({"id":candidate.id,"active":active,"reason":candidate.get("reason",""),
			"remaining_seconds":candidate.get("remaining_seconds",null)})
	if not override.is_empty(): row.overrides[override]=int(row.overrides.get(override,0))+1
	var resources: Dictionary = evaluated.get("resources",{})
	if bool(resources.get("available",false)):
		row.resource_observations+=1
		row.minimum_energy=minf(row.minimum_energy,float(resources.energy))
		row.maximum_energy=maxf(row.maximum_energy,float(resources.energy))
		row.last_energy=float(resources.energy)
	else: row.resource_unavailable+=1
	var material_summary := {}
	for id: String in ["16","3"]:
		var target: Dictionary = evaluated.materials.targets.get(id,{})
		var stats: Dictionary = row.materials[id]
		check(bool(evaluated.materials.get("available",false)) and bool(target.get("available",false)) \
			and int(target.get("coverage_sample_count",0))>0,
			str(row.id)+": independent native-ID material query has admitted nonempty coverage for "+id)
		if not bool(target.get("available",false)): stats.unavailable+=1
		elif not bool(target.get("present",false)): stats.absent_observed+=1
		else:
			stats.present+=1
			stats.minimum_distance=minf(stats.minimum_distance,float(target.distance))
			stats.maximum_distance=maxf(stats.maximum_distance,float(target.distance))
			stats.last_distance=float(target.distance)
		material_summary[id]={"available":target.get("available",false),"present":target.get("present",false),
			"nearest":target.get("nearest",null),"distance":target.get("distance",null),
			"coverage_sample_count":target.get("coverage_sample_count",0)}
	row.decision_usec_max=maxi(row.decision_usec_max,int(control.decision_usec))
	row.sensor_usec_max=maxi(row.sensor_usec_max,int(control.sensor_usec))
	row.trace.append({"tick":session.tick,"completed_physical_ticks":session.bridge.manual_step_count(),
		"simulation_seconds":session._completed_time_seconds,"engine_elapsed_seconds":ambient.get("elapsed_seconds",-1.0),
		"position":view.position,"velocity":view.velocity,"grounded":view.grounded,
		"intent_direction":direction,"intent_pace":pace,"action_move":move,"action_effort":action.get("effort",null),
		"override":override,"selected_rest":selected_rest,"remaining_seconds":intent.get("remaining_seconds",0.0),
		"resources":resources,"materials":material_summary,
		"material_sample_tick":evaluated.materials.sample_tick,"material_revision":evaluated.materials.revision,
		"candidates":candidates})


func run_campaign(id: String) -> void:
	var started := Time.get_ticks_usec()
	var original := Profile.preset(id)
	var profile := original.duplicate(true)
	profile.seed=SEED
	check(Profile.validate(profile,[],Actuator.capabilities(MODEL)).is_empty(),id+": admitted preset supports unchanged Runner")
	check(profile.modules==original.modules and profile.shared_seed==original.shared_seed,
		id+": only comparison seed changed from original authored preset")
	# Isolate each arm's physical space as well as its new session and native
	# owner; no contact cache or body from a prior arm shares this World2D.
	var viewport := SubViewport.new()
	viewport.world_2d=World2D.new()
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var owner := Node2D.new()
	viewport.add_child(owner)
	var session := Session.new()
	owner.add_child(session)
	if not check(session.configure([definition(profile)],owner.get_world_2d().space,11),id+": fresh production session configured"):
		viewport.free()
		return
	var native_bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var fixture := Contract.validate(Contract.parse(FileAccess.get_file_as_string(
		"res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json")).definition)
	var initial_pose := observed_pose(session.workbench_control(INSTANCE).observation)
	var sample: Dictionary = session.pack_workbench_sample()
	var token: int = native_bridge.prepare_liquid_world(world,PackedInt32Array(GEOMETRY),fixture.transport.packed,
		PackedInt32Array(fixture.definition.water_semantics),PackedInt32Array(),
		native_bridge.default_liquid_policy(),{"workbench_extent":EXTENT,
			"workbench_response":"LA-SELECTIVE","workbench_sample":sample,
			"region":PackedInt32Array([0,0,EXTENT.x,EXTENT.y]),"intent":"exploratory",
			"definition_hash":fixture.hash,"seed":0,"initial_bodies":session.bridge.pack_body_states(),
			"workbench_worker_threads":1})
	if not check(token>0 and native_bridge.commit_liquid_world(world,token),id+": fresh native material owner committed"):
		session.close()
		viewport.free()
		return
	check(session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles()),
		id+": native support and cup walls admitted to actual Rapier geometry")
	session.bridge.process_hard_surface_collider_budget(256,0)
	var physical_usables := Usables.new()
	var evaluator := Perception.new()
	check(evaluator.configure(EXTENT,session.epoch),id+": separate identical material evaluator configured")
	var terrain_revision: int = world.get_hard_surface_revision()
	var snapshot: CyberSimulationSnapshot = null
	var row := {"id":id,"model":MODEL,"instance_id":INSTANCE,"original_preset":original,
		"admitted_profile":profile,"initial_pose":initial_pose,"initial_material_payload":{},
		"run_id":session.run_id,"epoch":session.epoch,"first":START,"last":START,
		"min_x":START.x,"max_x":START.x,"physical_path_cells":0.0,"physical_path_during_selected_rest":0.0,
		"move_active_decisions":0,"neutral_move_decisions":0,"intentional_idle_decisions":0,
		"action_x_sign_changes":0,"intent_x_sign_changes":0,"active_intervals":0,"stalled_active_intervals":0,
		"rest_candidate_decisions":0,"selected_rest_decisions":0,"rest_entries":0,"rest_exits":0,
		"rest_to_active_resumptions":0,"rest_completed_episodes":0,"wander_idle_candidates":0,"rest_episodes":[],"resume_events":[],
		"overrides":{},"grounded_steps":0,"ground_support_loss_events":0,"canvas_center_incidents":0,
		"resource_observations":0,"resource_unavailable":0,"minimum_energy":INF,"maximum_energy":-INF,
		"last_energy":null,"decision_usec_max":0,"sensor_usec_max":0,"trace":[],
		"materials":{"16":{"present":0,"absent_observed":0,"unavailable":0,"minimum_distance":INF,"maximum_distance":-INF},
			"3":{"present":0,"absent_observed":0,"unavailable":0,"minimum_distance":INF,"maximum_distance":-INF}}}
	for step: int in range(TICKS):
		if step%CADENCE==0:
			var packet: Dictionary = world.take_render_snapshot(step==0)
			if step==0:
				row.initial_material_payload={"sha256":digest(PackedByteArray(packet.cells)),
					"bytes":PackedByteArray(packet.cells).size(),"rectangles":packet.rectangles,
					"channels":packet.channels,"full_refresh":packet.full_refresh,
					"native_tick":int(world.tick_index),"world_revision":int(world.revision)}
			snapshot=publication(world,packet,snapshot,session.epoch,step+1)
			session.ingest_ambient_snapshot(snapshot)
			check(evaluator.ingest_snapshot(snapshot,EXTENT,session.epoch),id+": native publication admitted to independent evaluator")
		session.advance(DT)
		if step%CADENCE==0: sample_decision(session,evaluator,row)
		sample=session.pack_workbench_sample()
		if not world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true):
			check(false,id+": moving body/native coupling refused at "+str(step))
			break
		var feedback: Dictionary = physical_usables.step(DT,world,sample.equipment_frame,sample.equipment_requests)
		if not str(feedback.get("last_error","")).is_empty():
			check(false,id+": equipment feedback refused")
			break
		session.accept_equipment_feedback(feedback)
		if not world.simulation_tick():
			check(false,id+": actual native step refused")
			break
		session.apply_workbench_results(step+1,world.workbench_coupling_results())
		if world.get_hard_surface_revision()!=terrain_revision:
			session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles())
			session.bridge.process_hard_surface_collider_budget(256,0)
			terrain_revision=world.get_hard_surface_revision()
		session.bridge.step()
		session.complete_step()
		var observed: Dictionary = session._view(0,false)
		var travel := Vector2(observed.position).distance_to(row.last)
		row.physical_path_cells+=travel
		if not row.trace.is_empty() and bool(row.trace.back().selected_rest): row.physical_path_during_selected_rest+=travel
		row.last=observed.position
		row.min_x=minf(row.min_x,observed.position.x)
		row.max_x=maxf(row.max_x,observed.position.x)
		if bool(observed.grounded): row.grounded_steps+=1
		if row.get("was_grounded",false) and not bool(observed.grounded): row.ground_support_loss_events+=1
		row["was_grounded"]=bool(observed.grounded)
		if not Rect2(Vector2.ZERO,Vector2(EXTENT)).has_point(observed.position): row.canvas_center_incidents+=1
		if not str(observed.get("fault","")).is_empty():
			check(false,id+": actual physical rig fault at "+str(step))
			break
		if step%600==599: print("AMBIENT_PERSONALITIES_PROGRESS ",id," completed=",step+1," seconds=",session._completed_time_seconds)
	var control: Dictionary = session.workbench_control(INSTANCE)
	row["native_ticks"]=int(world.tick_index)
	row["session_ticks"]=session.tick
	row["completed_rapier_ticks"]=session.bridge.manual_step_count()
	row["completed_seconds"]=session._completed_time_seconds
	row["engine_last_decision_seconds"]=control.diagnostics.get("ambient",{}).get("elapsed_seconds",-1.0)
	row["accepted_commands"]=control.accepted
	row["rejected_commands"]=control.rejected
	row["final_pose"]=observed_pose(control.observation)
	row["physical_parts"]=sample.bodies.size()
	row["native_masks"]=sample.states.size()/17
	row["perception"]=session._ambient_perception.diagnostics()
	row["independent_evaluator"]=evaluator.diagnostics()
	row["total_decision_usec"]=control.total_decision_usec
	row["elapsed_usec"]=Time.get_ticks_usec()-started
	check(row.native_ticks==TICKS and row.session_ticks==TICKS and row.completed_rapier_ticks==TICKS,
		id+": complete identical 1800 native and actual Rapier steps")
	check(absf(float(row.completed_seconds)-TICKS*DT)<0.0000001,id+": thirty seconds of completed physical progression")
	check(row.trace.size()==TICKS/CADENCE and row.accepted_commands==TICKS/CADENCE and row.rejected_commands==0,
		id+": exact matched 300-decision budget without command refusal")
	check(absf(float(row.engine_last_decision_seconds)-(TICKS-CADENCE)*DT)<0.0000001,
		id+": final pre-step decision clock distinguished from terminal physical time")
	check(control.ambient==profile,id+": production profile configuration remains unchanged through long run")
	check(row.resource_observations+row.resource_unavailable==TICKS/CADENCE,id+": explicit resource coverage for every decision")
	if id=="idle_mechanic":
		check(row.rest_candidate_decisions>0 and row.selected_rest_decisions>0,id+": actual scheduled rest both activates and wins arbitration")
		check(row.rest_completed_episodes>0 and row.rest_to_active_resumptions>0,id+": selected rest timer expires and nonzero intention/action resumes")
	if not row.trace.is_empty() and row.trace.back().selected_rest:
		row.rest_episodes.append({"start_seconds":row.rest_started_seconds,"end_seconds":row.completed_seconds,
			"duration_seconds":float(row.completed_seconds)-float(row.rest_started_seconds),
			"selected_decisions":row.rest_episode_decisions,"completed":false,"end_reason":"observation_window_ended"})
	for stats: Dictionary in row.materials.values():
		for key: String in ["minimum_distance","maximum_distance"]:
			if not is_finite(float(stats[key])): stats[key]=null
	for key: String in ["minimum_energy","maximum_energy"]:
		if not is_finite(float(row[key])): row[key]=null
	for key: String in ["last_action_sign","last_intent_sign","was_grounded","awaiting_resume",
		"rest_started_seconds","rest_episode_decisions"]: row.erase(key)
	campaigns.append(row)
	session.close()
	viewport.free()
	completed.append(id)


func run() -> void:
	var identity := source_identity()
	check(identity.runtime_supported,"source custody supports selected actual Linux/Windows x86_64 runtimes")
	check(ClassDB.class_exists("CyberNativeCellWorld") and ClassDB.class_exists("RapierPhysicsServer2D"),
		"genuine native and Rapier extensions are available")
	if failures.is_empty():
		for id: String in PROFILES: run_campaign(id)
	check(completed==PROFILES,"all three long-running personality arms completed")
	if campaigns.size()==PROFILES.size():
		for row: Dictionary in campaigns:
			check(row.initial_material_payload==campaigns[0].initial_material_payload,
				str(row.id)+": byte-identical initial native material publication and metadata")
			check(row.initial_pose==campaigns[0].initial_pose,str(row.id)+": identical initial physical pose, velocity and resource state")
	var result := {"case":"AMBIENT-001 long matched personality observation","checks":checks,"failures":failures,
		"source_identity":identity,"model":MODEL,"extent":EXTENT,"geometry":GEOMETRY,
		"profile_comparison_seed":SEED,"profile_seed_mode":"original shared_seed=false; same authored instance and seed in every arm",
		"native_setup_seed":0,"native_threads":1,"decision_period_ticks":CADENCE,"budget_ticks":TICKS,
		"independent_sensor":{"material_ids":[16,3],"radius_cells":50,"sampling":"same inclusive sparse circular query for every profile"},
		"metric_definitions":{"rest":"selected scheduled-rest override; candidate activity reported separately",
			"resume":"selected rest ended, then nonzero procedural intention and normalized command observed",
			"physical_path_during_rest":"actual body travel while selected rest remains neutral; drift is not active intention",
			"stall":"preceding command move length >0.05 and displacement <0.25 cells over six physical ticks",
			"oscillation":"nonzero X sign changes with 0.05 deadzone; includes legitimate braking or reflexes",
			"material_range":"nearest observed native numeric-ID sample within50 cells; cups may be inaccessible",
			"time":"decisions precede their step; terminal physical time30s and last decision time29.9s are distinct"},
		"campaigns":campaigns,"scope":"Synchronous native/Rapier observation. No subjective personality, global route or Windows/NVIDIA playfeel acceptance."}
	var path := OS.get_environment("CYBERSAND_AMBIENT_PERSONALITIES_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if check(file!=null,"personality report destination opened"):
			result.checks=checks
			file.store_string(JSON.stringify(Registry._json_value(result),"\t"))
	var summary := result.duplicate(true)
	for row: Dictionary in summary.campaigns:
		row.erase("trace")
		row.erase("original_preset")
		row.erase("admitted_profile")
	print("AMBIENT_PERSONALITIES ",JSON.stringify(Registry._json_value(summary)))
	quit(0 if failures.is_empty() else 1)
