extends SceneTree

# Matched real native/Rapier experiments. Every episode is one instantiated actor
# in an independently identified fresh campaign. Population episodes share a
# World by design; they are not statistically independent replicates.
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Usables = preload("res://scripts/physical_usable_runtime.gd")
const Perception = preload("res://scripts/ambient/ambient_perception.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const DT := 1.0 / 60.0
const EXTENT := Vector2i(512,256)
const CADENCE := 6
const SEEDS := [605,1701,2909]
const MAIN_ARMS := ["legacy","random","random_hold","scripted","stateful","no_memory","no_traits","coarse_only"]
const SOCIAL_TYPES := ["follow_actor","avoid_crowding","observe_actor","regroup","align_peers","disperse","avoid_peer"]
var checks := 0
var failures: Array[String] = []
var campaigns: Array = []
var matched_initial_states: Dictionary = {}
var completed: Array[String] = []
var report_path := ""
var full_mode := false


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		if failures.size() < 100: failures.append(label)
		push_error("AMBIENT2_EPISODES: " + label)
	return value


func digest(value: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(value)
	return hashing.finish().hex_encode()


func identity() -> Dictionary:
	var paths: Array[String] = [
		"scripts/ambient/ambient_engine.gd","scripts/ambient/ambient_modules.gd",
		"scripts/ambient/ambient_stateful_modules.gd","scripts/ambient/ambient_memory.gd",
		"scripts/ambient/ambient_profile.gd","scripts/ambient/ambient_perception.gd",
		"scripts/ambient/ambient_actuator.gd","scripts/physical_actor_session.gd",
		"scripts/physical_actor_rig.gd","scripts/physical_actor_catalog.gd",
		"scripts/physical_actor_script.gd","scripts/physical_usable_runtime.gd","scripts/physical_actor_effects.gd",
		"scripts/workbench_actor_control.gd","scripts/workbench_actor_catalog.gd",
		"scripts/workbench_physics_bridge.gd","scripts/rapier_physics_bridge.gd",
		"scripts/physical_flight_controller.gd","scripts/physical_flight_profile.gd","data/ambient/profiles.json",
		"tests/test_ambient2_episodes.gd","tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"]
	var hashes := {}
	for path: String in paths:
		hashes[path] = FileAccess.get_sha256("res://"+path) if FileAccess.file_exists("res://"+path) else "absent"
	var windows := OS.get_name() == "Windows"
	var runtimes := {}
	for path: String in [
		"addons/cybersand_native/bin/"+("cybersand_native.windows.x86_64.dll" if windows else "libcybersand_native.linux.x86_64.so"),
		"addons/godot-rapier2d/bin/"+("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if windows else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")]:
		runtimes[path] = FileAccess.get_sha256("res://"+path)
	return {"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"captured_utc":Time.get_datetime_string_from_system(true),"godot":Engine.get_version_info().string,
		"godot_executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"platform":OS.get_name(),"display_server":DisplayServer.get_name(),
		"runtime_supported":OS.get_name() in ["Linux","Windows"] and OS.has_feature("x86_64"),
		"sha256":hashes,"runtime_sha256":runtimes}


func make_case(group: String, layout: String, model: String, arm: String, seed: int,
		count: int = 1, seconds: int = 30) -> Dictionary:
	var matched := "%s-%s-%s-s%d-t%d-n%d" % [group,layout,model,seed,seconds,count]
	return {"id":matched+"-"+arm,"matched_group":matched,"group":group,"layout":layout,
		"model":model,"arm":arm,"seed":seed,"actor_count":count,"seconds":seconds}


func registry() -> Array:
	var cases: Array = []
	for seed: int in SEEDS:
		for model: String in ["runner","monowheel","4ly_trainer"]:
			for arm: String in MAIN_ARMS:
				cases.append(make_case("main","pockets",model,arm,seed))
	for seed: int in [605,1701]:
		for arm: String in ["legacy","stateful","no_social","random"]:
			cases.append(make_case("social","courtyard","runner",arm,seed,4))
		for layout: String in ["sealed_goal","moved_material","blocked_route"]:
			for arm: String in ["stateful","no_memory"]:
				cases.append(make_case("adverse",layout,"runner",arm,seed))
		for arm: String in ["stateful","no_social"]:
			cases.append(make_case("departure","peer_departure","runner",arm,seed,2))
		for arm: String in ["legacy","stateful"]:
			cases.append(make_case("capacity","courtyard","runner",arm,seed,8))
	for model: String in ["runner","4ly_trainer"]:
		for arm: String in ["stateful","no_memory"]:
			cases.append(make_case("sustained","pockets",model,arm,1701,1,120))
	for arm: String in ["stateful","no_memory"]:
		cases.append(make_case("sustained","pockets","monowheel",arm,1701,1,300))
	# One descriptive ordinary preset subject and one actual passive auxiliary.
	# Companion episodes are never counted as personality treatment replicates.
	for profile: Dictionary in Profile.presets():
		var model := "4ly_trainer" if str(profile.id) in ["drifting_flyer","cautious_flyer","boundary_grazer"] else "runner"
		var item := make_case("catalogue","pockets",model,str(profile.id),1701,2)
		item["profile_id"] = str(profile.id)
		cases.append(item)
	if full_mode: return cases
	var smoke: Array = []
	for item: Dictionary in cases:
		var selected: bool = int(item.seed) == 1701 and (
			(item.group == "main" and item.arm in ["legacy","stateful"]) \
			or (item.group == "social" and item.arm == "stateful") \
			or (item.group == "adverse" and item.layout == "sealed_goal" and item.arm == "stateful") \
			or (item.group == "departure" and item.arm == "stateful"))
		if not selected: continue
		var short := item.duplicate(true)
		short.seconds = 2
		short.id = "smoke-"+str(item.id)
		short.matched_group = "smoke-"+str(item.matched_group)
		smoke.append(short)
	return smoke


func start_position(item: Dictionary, slot: int) -> Vector2:
	if item.group == "catalogue": return Vector2(220 + slot * 55,130 if item.model == "4ly_trainer" else 175)
	if int(item.actor_count) == 8: return Vector2(96 + slot * 40,175)
	if int(item.actor_count) == 4: return Vector2(170 + slot * 28,175)
	if item.group == "departure": return Vector2(210 + slot * 35,175)
	return Vector2(220,130 if item.model == "4ly_trainer" else 185 if item.model == "monowheel" else 175)


func profile_for(item: Dictionary, slot: int) -> Dictionary:
	if item.group == "catalogue":
		var selected: Dictionary = Profile.preset(str(item.profile_id))
		if not selected.is_empty(): selected.seed = int(item.seed)
		return selected
	var legacy := str(item.arm) == "legacy"
	var id := "drifting_flyer" if item.model == "4ly_trainer" else "oil_moth"
	if item.group in ["social","capacity"]: id = "social_roamer"
	if not legacy:
		id = "cautious_flyer" if item.model == "4ly_trainer" else "persistent_scavenger"
		if item.group == "social": id = "social_drifter"
		if item.group == "departure": id = "timid_follower"
		if item.group == "adverse" and item.layout == "blocked_route": id = "restless_explorer"
		if item.group == "capacity":
			id = ["social_drifter","timid_follower","routine_patrol","independent_wanderer"][slot % 4]
	var profile: Dictionary = Profile.preset(id)
	if profile.is_empty(): return {}
	profile.seed = int(item.seed)
	if int(profile.version) == 2:
		if item.arm == "no_memory": profile.memory.enabled = false
		if item.arm == "no_traits":
			profile.personality.enabled = false
			profile.drives_enabled = false
		if item.arm == "coarse_only":
			profile.perception = {"spacing_cells":4,"near_radius_cells":0,"refine_boundaries":false}
		if item.arm == "no_social":
			for module: Dictionary in profile.modules:
				if str(module.type) in SOCIAL_TYPES: module.enabled = false
		if item.group in ["social","capacity","departure"]:
			profile.relations.tags = ["settlement"]
			profile.relations.prefer_tags = ["settlement"]
			profile.relations.avoid_tags = []
	return profile


func control_mode(item: Dictionary, slot: int) -> String:
	if item.group == "catalogue": return "passive_companion" if slot == 1 else "catalogue_subject"
	if item.group == "departure" and slot == 1: return "departing_peer"
	return str(item.arm)


func definition(item: Dictionary, slot: int) -> Dictionary:
	var control := Registry.default_control(str(item.model))
	var mode := control_mode(item,slot)
	control.source = "passive" if mode == "passive_companion" else "scripted" if mode == "scripted" else "policy"
	control.policy = "external" if mode in ["random","random_hold","departing_peer","scripted","passive_companion"] else "ambient"
	control.usable_index = -1
	control.decision_ticks = CADENCE
	if mode not in ["random","random_hold","departing_peer","scripted","passive_companion"]:
		control["ambient"] = profile_for(item,slot)
	return {"model":str(item.model),"instance_id":100+slot,"position":start_position(item,slot),
		"producer":Registry.producer_for(control.source),"usable_index":-1,"canvas_extent":EXTENT,
		"workbench_control":control,"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,
			"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,
			"torque_multiplier":1.0,"boost_multiplier":2.0}}


func geometry(item: Dictionary) -> PackedInt32Array:
	var result := PackedInt32Array([0,200,512,8,1,0,0,8,200,1,504,0,8,200,1])
	if item.layout in ["courtyard","peer_departure"]: return result
	if item.model == "4ly_trainer":
		result.append_array(PackedInt32Array([152,144,36,4,1,152,120,4,24,1,184,120,4,24,1,
			156,136,28,8,3,258,144,36,4,1,258,120,4,24,1,290,120,4,24,1,262,136,28,8,16]))
	else:
		result.append_array(PackedInt32Array([152,184,4,16,1,180,184,4,16,1,156,190,24,10,3,
			258,184,4,16,1,290,184,4,16,1,262,190,28,10,16]))
	if item.layout == "sealed_goal":
		result.append_array(PackedInt32Array([254,160,4,40,1,294,160,4,40,1,254,160,44,4,1]))
	return result


func publication(world: Object, packet: Dictionary, previous: CyberSimulationSnapshot,
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
	elif previous != null:
		snapshot.render_snapshot_serial = previous.render_snapshot_serial
		snapshot.render_tick_index = previous.render_tick_index
		snapshot.world_revision = previous.world_revision
		snapshot.render_full_refresh = previous.render_full_refresh
		snapshot.render_channels = previous.render_channels
		snapshot.render_patch_rectangles = previous.render_patch_rectangles
		snapshot.render_patch_cells = previous.render_patch_cells
	return snapshot


func physical_pose(view: Dictionary) -> Dictionary:
	return {"position":view.position,"velocity":view.velocity,"rotation":view.rotation,
		"angular_velocity":view.angular_velocity,"grounded":view.grounded,
		"parts":view.parts.duplicate(true),"energy":view.get("energy"),"charge":view.get("charge"),
		"cooldown":view.get("cooldown"),"fault":view.get("fault","")}


func random_unit(state: Dictionary) -> float:
	state.rng = (int(state.rng) * 1103515245 + 12345) & 0x7fffffff
	return float(state.rng) / 2147483648.0


func external_commands(session: Node, item: Dictionary, states: Array, step: int) -> void:
	for slot: int in range(int(item.actor_count)):
		var mode := control_mode(item,slot)
		if mode not in ["random","random_hold","departing_peer"]: continue
		var observed: Dictionary = session.workbench_policy_observation(100+slot)
		var movement := Vector2.ZERO
		if mode in ["random","random_hold"]:
			var state: Dictionary = states[slot]
			# Renew every six ticks; held random only resamples once per second.
			if mode == "random" or step % 60 == 0 or not state.has("held_movement"):
				movement.x = float(floori(random_unit(state)*3.0)-1)*0.45
				if item.model == "4ly_trainer": movement.y = float(floori(random_unit(state)*3.0)-1)*0.35
				state["held_movement"] = movement
			else:
				movement = state.held_movement
		elif step >= int(item.seconds)*30:
			# Actual embodied departure; no pose setter, despawn or false missing
			# observation is used. Whether it leaves sensory range is measured.
			movement.x = 0.85
		var action := {"move":movement}
		if item.model != "4ly_trainer": action["effort"] = 0.7 if movement != Vector2.ZERO else 0.0
		check(session.submit_workbench_policy(100+slot,Session.make_command(observed,
			int(observed.last_sequence)+1,action,CADENCE*2)),str(item.id)+": legal external action admitted")


func intervene(world: Object, item: Dictionary, step: int, events: Array) -> void:
	if step != int(item.seconds)*30: return
	var revision: int = world.revision
	if item.layout == "moved_material":
		# Exact ordinary paint cells remove only the original fluid pocket;
		# floor and enclosing Stone remain intact. No private cell storage.
		for y: int in range(184,200):
			for x: int in range(262,290): world.emit_disc(x,y,0,0)
		for y: int in range(190,200):
			for x: int in range(196,210): world.emit_disc(x,y,0,16)
		events.append({"kind":"relocate_oil_by_native_paint","tick":step,
			"before_revision":revision,"after_revision":int(world.revision)})
	elif item.layout == "blocked_route":
		for y: int in range(152,200):
			for x: int in range(246,252): world.emit_disc(x,y,0,1)
		events.append({"kind":"block_familiar_route_with_native_stone","tick":step,
			"before_revision":revision,"after_revision":int(world.revision)})
	elif item.layout == "peer_departure":
		events.append({"kind":"peer_begins_legal_actuator_departure","tick":step,
			"peer_instance":101,"no_teleport":true})


func sampled_target(target: Dictionary) -> Dictionary:
	var result := {"available":bool(target.get("available",false)),
		"present":bool(target.get("present",false)),"status":str(target.get("status","legacy_sampled")),
		"coverage_samples":int(target.get("coverage_sample_count",0))}
	if result.present:
		result["distance"] = float(target.distance)
		result["nearest"] = Vector2(target.nearest)
	return result


func record_decisions(session: Node, evaluator: RefCounted, item: Dictionary, rows: Array) -> void:
	var copied_views: Array = []
	for slot: int in range(int(item.actor_count)):
		copied_views.append(session.workbench_control(100+slot).observation)
	for slot: int in range(int(item.actor_count)):
		var control: Dictionary = session.workbench_control(100+slot)
		var observed: Dictionary = copied_views[slot]
		var ambient: Dictionary = control.diagnostics.get("ambient",{})
		var intent: Dictionary = ambient.get("intent",{})
		var row: Dictionary = rows[slot]
		var begun := Time.get_ticks_usec()
		var measured: Dictionary = evaluator.observe(observed,[{"material_id":16,"radius_cells":50},
			{"material_id":3,"radius_cells":50}],{"capabilities":Actuator.capabilities(str(item.model)),
			"bounds":Rect2(Vector2.ZERO,Vector2(EXTENT)),"home":start_position(item,slot),
			"simulation_time_seconds":session._completed_time_seconds,
			"perception":{"spacing_cells":4,"near_radius_cells":8,"refine_boundaries":true}})
		row.observer_usec += Time.get_ticks_usec()-begun
		var peers := 0
		var nearest_peer := INF
		var nearest_id := -1
		for other: int in range(copied_views.size()):
			if other == slot: continue
			var distance := Vector2(observed.position).distance_to(copied_views[other].position)
			if distance <= Perception.MAX_RADIUS: peers += 1
			if distance < nearest_peer:
				nearest_peer = distance
				nearest_id = 100+other
		var action: Dictionary = session._commands[slot]
		var move: Vector2 = action.get("move",Vector2.ZERO)
		var selection := str(intent.get("active_override",""))
		if selection.is_empty(): selection = str(intent.get("selected_goal",""))
		if selection.is_empty(): selection = str(intent.get("selected_module",""))
		if selection.is_empty(): selection = "blend:"+",".join(intent.get("active_modules",[])) if not intent.is_empty() else control_mode(item,slot)
		var oil: Dictionary = measured.materials.targets.get("16",{})
		var water: Dictionary = measured.materials.targets.get("3",{})
		var record := {"tick":session.tick,"seconds":session._completed_time_seconds,
			"position":observed.position,"velocity":observed.velocity,"grounded":observed.grounded,
			"home_distance":Vector2(observed.position).distance_to(start_position(item,slot)),
			"action_move":move,"intent_direction":intent.get("direction",Vector2.ZERO),
			"intent_pace":float(intent.get("pace",0.0)),"has_procedural_intent":not intent.is_empty(),
			"selection":selection,"phase":str(intent.get("goal_phase","")),
			"reason":str(intent.get("reason","")).left(128),"energy":observed.get("energy"),
			"wall_left":observed.get("wall_left"),"wall_right":observed.get("wall_right"),
			"oil":sampled_target(oil),"water":sampled_target(water),
			"nearest_peer":nearest_peer if is_finite(nearest_peer) else null,"nearest_peer_id":nearest_id,
			"observed_peer_count":peers,"drives":ambient.get("drives",{}),
			"material_sample_tick":measured.materials.get("sample_tick",-1),
			"material_revision":measured.materials.get("revision",-1)}
		if row.trace.size() > 0:
			var prior: Dictionary = row.trace.back()
			if Vector2(prior.action_move).length() > 0.05:
				row.active_intervals += 1
				var progress := Vector2(observed.position).distance_to(prior.position) if item.model == "4ly_trainer" else absf(float(observed.position.x)-float(prior.position.x))
				if progress < 0.25:
					row.stalled_active_intervals += 1
		row.trace.append(record)
		row.sensor_usec_total += int(control.sensor_usec)
		row.sensor_usec_max = maxi(row.sensor_usec_max,int(control.sensor_usec))
		row.decision_usec_max = maxi(row.decision_usec_max,int(control.decision_usec))
		if not bool(measured.materials.get("available",false)) or not oil.get("available",false) or not water.get("available",false):
			row.outcome_sensor_unavailable += 1


func checkpoint_report(report: Dictionary) -> void:
	if report_path.is_empty(): return
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file == null:
		check(false,"physical campaign report destination opened")
		return
	file.store_string(JSON.stringify(Registry._json_value(report),"\t"))


func run_case(item: Dictionary) -> void:
	var begun := Time.get_ticks_usec()
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var owner := Node2D.new()
	viewport.add_child(owner)
	var session := Session.new()
	owner.add_child(session)
	var roster: Array = []
	var initial_poses: Array = []
	var streams: Array = []
	for slot: int in range(int(item.actor_count)):
		var created := definition(item,slot)
		if created.workbench_control.has("ambient"):
			var error := Profile.validate(created.workbench_control.ambient,[],Actuator.capabilities(str(item.model)))
			if not check(error.is_empty(),str(item.id)+": valid editable profile: "+error):
				viewport.free()
				return
		roster.append(created)
		streams.append({"rng":(int(item.seed)*31+100+slot)&0x7fffffff})
	if not check(session.configure(roster,owner.get_world_2d().space,11),str(item.id)+": actual production physical session configured"):
		viewport.free()
		return
	for slot: int in range(roster.size()):
		initial_poses.append(physical_pose(session.workbench_control(100+slot).observation))
	var native_bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var fixture := Contract.validate(Contract.parse(FileAccess.get_file_as_string(
		"res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json")).definition)
	var sample: Dictionary = session.pack_workbench_sample()
	var rectangles := geometry(item)
	var token: int = native_bridge.prepare_liquid_world(world,rectangles,fixture.transport.packed,
		PackedInt32Array(fixture.definition.water_semantics),PackedInt32Array(),
		native_bridge.default_liquid_policy(),{"workbench_extent":EXTENT,
			"workbench_response":"LA-SELECTIVE","workbench_sample":sample,"region":PackedInt32Array([0,0,512,256]),
			"intent":"exploratory","definition_hash":fixture.hash,"seed":int(item.seed),
			"initial_bodies":session.bridge.pack_body_states(),"workbench_worker_threads":1})
	if not check(token>0 and native_bridge.commit_liquid_world(world,token),str(item.id)+": native material owner committed"):
		session.close()
		viewport.free()
		return
	check(session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles()),
		str(item.id)+": real native hard surfaces admitted to Rapier")
	session.bridge.process_hard_surface_collider_budget(256,0)
	var physical_usables := Usables.new()
	var evaluator := Perception.new()
	evaluator.configure(EXTENT,session.epoch)
	var terrain_revision: int = world.get_hard_surface_revision()
	var snapshot: CyberSimulationSnapshot = null
	var ticks := int(item.seconds)*60
	var rows: Array = []
	var events: Array = []
	var production_usec := 0
	var native_usec := 0
	var physics_usec := 0
	var initial_materials := {}
	for slot: int in range(roster.size()):
		rows.append({"episode_id":str(item.id)+"-a"+str(100+slot),"actor_instance":100+slot,
			"model":item.model,"profile":roster[slot].workbench_control.get("ambient",{}),
			"controller":control_mode(item,slot),"start":start_position(item,slot),
			"last":start_position(item,slot),"physical_path_cells":0.0,"neutral_command_path_cells":0.0,
			"grounded_steps":0,"canvas_center_incidents":0,"active_intervals":0,"stalled_active_intervals":0,
			"sensor_usec_total":0,"sensor_usec_max":0,"decision_usec_max":0,"observer_usec":0,
			"outcome_sensor_unavailable":0,"trace":[]})
	var finished_steps := 0
	for step: int in range(ticks):
		intervene(world,item,step,events)
		if step % CADENCE == 0:
			var packet: Dictionary = world.take_render_snapshot(step == 0)
			if step == 0:
				initial_materials = {"sha256":digest(PackedByteArray(packet.cells)),
					"bytes":PackedByteArray(packet.cells).size(),"channels":int(packet.channels),
					"rectangles":packet.rectangles,"native_tick":int(world.tick_index),"revision":int(world.revision)}
				var initial := {"materials":initial_materials,"poses":initial_poses,"geometry":rectangles}
				var key := str(item.matched_group)
				if matched_initial_states.has(key):
					check(initial == matched_initial_states[key],str(item.id)+": byte-identical native state and identical complete initial actor states")
				else:
					matched_initial_states[key] = initial.duplicate(true)
			snapshot = publication(world,packet,snapshot,session.epoch,step+1)
			session.ingest_ambient_snapshot(snapshot)
			if not check(evaluator.ingest_snapshot(snapshot,EXTENT,session.epoch),str(item.id)+": common outcome observer admits native publication"):
				break
			external_commands(session,item,streams,step)
		var segment := Time.get_ticks_usec()
		session.advance(DT)
		production_usec += Time.get_ticks_usec()-segment
		if step % CADENCE == 0: record_decisions(session,evaluator,item,rows)
		sample = session.pack_workbench_sample()
		if not check(world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true),
			str(item.id)+": real moving body/native coupling admitted"):
			break
		var feedback: Dictionary = physical_usables.step(DT,world,sample.equipment_frame,sample.equipment_requests)
		if not check(str(feedback.get("last_error","")).is_empty(),str(item.id)+": equipment feedback"):
			break
		session.accept_equipment_feedback(feedback)
		segment = Time.get_ticks_usec()
		var native_ok: bool = world.simulation_tick()
		native_usec += Time.get_ticks_usec()-segment
		if not check(native_ok,str(item.id)+": actual native progression"):
			break
		session.apply_workbench_results(step+1,world.workbench_coupling_results())
		if world.get_hard_surface_revision() != terrain_revision:
			session.bridge.queue_hard_surface_chunk_snapshot(world.get_hard_surface_chunk_rectangles())
			session.bridge.process_hard_surface_collider_budget(256,0)
			terrain_revision = world.get_hard_surface_revision()
		segment = Time.get_ticks_usec()
		session.bridge.step()
		session.complete_step()
		physics_usec += Time.get_ticks_usec()-segment
		finished_steps += 1
		for slot: int in range(rows.size()):
			var observed: Dictionary = session._view(slot,false)
			var row: Dictionary = rows[slot]
			var travel := Vector2(observed.position).distance_to(row.last)
			row.physical_path_cells += travel
			if not row.trace.is_empty() and Vector2(row.trace.back().action_move).length() <= 0.05:
				row.neutral_command_path_cells += travel
			row.last = observed.position
			if observed.grounded: row.grounded_steps += 1
			if not Rect2(Vector2.ZERO,Vector2(EXTENT)).has_point(observed.position): row.canvas_center_incidents += 1
			check(str(observed.get("fault","")).is_empty() and Vector2(observed.position).is_finite(),
				str(item.id)+": finite actual actor state")
		if step % 1800 == 1799:
			print("AMBIENT2_EPISODES_PROGRESS ",item.id," native=",world.tick_index," physical=",session.bridge.manual_step_count())
	var campaign := item.duplicate(true)
	campaign["run_id"] = session.run_id
	campaign["epoch"] = session.epoch
	campaign["native_ticks"] = int(world.tick_index)
	campaign["physical_ticks"] = session.bridge.manual_step_count()
	campaign["completed_seconds"] = session._completed_time_seconds
	campaign["initial_materials"] = initial_materials
	campaign["initial_pose_sha256"] = digest(JSON.stringify(Registry._json_value(initial_poses)).to_utf8_buffer())
	campaign["geometry"] = rectangles
	campaign["events"] = events
	campaign["production_advance_usec"] = production_usec
	campaign["native_step_usec"] = native_usec
	campaign["physics_step_usec"] = physics_usec
	campaign["elapsed_usec"] = Time.get_ticks_usec()-begun
	campaign["physical_parts"] = sample.bodies.size()
	campaign["native_masks"] = sample.states.size()/17
	campaign["perception"] = session._ambient_perception.diagnostics()
	campaign["outcome_observer"] = evaluator.diagnostics()
	check(finished_steps == ticks and campaign.native_ticks == ticks and campaign.physical_ticks == ticks,
		str(item.id)+": complete declared actual native and Rapier horizon")
	check(absf(float(campaign.completed_seconds)-float(item.seconds)) < 0.00001,
		str(item.id)+": completed simulation time matches declared horizon")
	for slot: int in range(rows.size()):
		var control: Dictionary = session.workbench_control(100+slot)
		var row: Dictionary = rows[slot]
		row["accepted_commands"] = int(control.accepted)
		row["rejected_commands"] = int(control.rejected)
		row["total_decision_usec"] = int(control.total_decision_usec)
		row["final_pose"] = physical_pose(control.observation)
		row["final_memory"] = control.diagnostics.get("ambient",{}).get("memory",{})
		row["final_drives"] = control.diagnostics.get("ambient",{}).get("drives",{})
		var expected_commands := 0 if str(row.controller) == "passive_companion" else ticks/CADENCE
		check(row.trace.size() == ticks/CADENCE and row.accepted_commands == expected_commands and row.rejected_commands == 0,
			str(row.episode_id)+": actual command/decision budget completed without rejection")
		check(row.outcome_sensor_unavailable == 0,str(row.episode_id)+": matched outcome observation coverage maintained")
	campaign["episodes"] = rows
	campaigns.append(campaign)
	if finished_steps == ticks: completed.append(str(item.id))
	session.close()
	viewport.free()
	print("AMBIENT2_EPISODES_CAMPAIGN ",item.id," actors=",rows.size()," complete_ticks=",finished_steps," elapsed_ms=",campaign.elapsed_usec/1000.0)


func run() -> void:
	var requested_mode := OS.get_environment("CYBERSAND_AMBIENT2_EPISODES_MODE")
	full_mode = requested_mode in ["full","registry"]
	report_path = OS.get_environment("CYBERSAND_AMBIENT2_EPISODES_REPORT")
	var source := identity()
	var cases := registry()
	var complete_registry := cases.duplicate(true)
	if requested_mode == "registry":
		checkpoint_report({"case":"AMBIENT-002 physical campaign registry","source_identity":source,
			"registration":complete_registry,"actual_episodes_executed":0})
		print("AMBIENT2_REGISTRY ",JSON.stringify({"campaigns":cases.size(),"actual_episodes_executed":0,
			"source_revision":source.source_revision}))
		quit(0)
		return
	var selected_case := OS.get_environment("CYBERSAND_AMBIENT2_EPISODES_CASE")
	if not selected_case.is_empty():
		var selected: Array = []
		for item: Dictionary in cases:
			if str(item.id) == selected_case: selected.append(item)
		cases = selected
		check(cases.size() == 1,"exact registered physical shard selected")
	var expected_episodes := 0
	for item: Dictionary in cases: expected_episodes += int(item.actor_count)
	check(source.runtime_supported,"actual source custody supports current runtime")
	check(ClassDB.class_exists("CyberNativeCellWorld") and ClassDB.class_exists("RapierPhysicsServer2D"),
		"genuine native/Rapier extensions exist")
	if selected_case.is_empty():
		check((expected_episodes == 194 if full_mode else expected_episodes == 13),"registered physical episode count")
	var report := {"case":"AMBIENT-002 matched physical actor episodes","mode":"shard" if not selected_case.is_empty() else "full" if full_mode else "smoke",
		"source_identity":source,"expected_campaigns":cases.size(),"expected_actor_episodes":expected_episodes,
		"extent":EXTENT,"native_threads":1,"decision_period_ticks":CADENCE,"actor_limit":8,
		"registration":cases,"complete_registration":complete_registry,"seed_semantics":"matched authored seeds; procedural module mixing and independent baseline LCG streams differ",
		"observation_scope":"common independent Oil/Water radius50 near8 observer for every controller; causal ablations retain their base profile and request scope; legacy/new system comparisons include the declared profile/sensor differences",
		"metric_scope":"actual center path includes gait; stable16-cell coverage/intentions/social outcomes are reduced independently; neutral action does not guarantee stillness",
		"scope":"ordinary production session and native/Rapier runtime in a synchronous apparatus; no global routing or physical NVIDIA playfeel acceptance",
		"complete":false,"checks":checks,"failures":failures,"campaigns":campaigns}
	if failures.is_empty():
		for item: Dictionary in cases:
			run_case(item)
			# Owners are closed before deferred reclamation; no active episode
			# accrues extra simulation time in this idle frame.
			await process_frame
			report.checks = checks
			report.failures = failures
			report["completed_campaigns"] = completed.size()
			checkpoint_report(report)
			if not failures.is_empty(): break
	check(completed.size() == cases.size(),"every registered physical campaign completed")
	var episodes := 0
	for campaign: Dictionary in campaigns: episodes += campaign.episodes.size()
	check(episodes == expected_episodes,"every independently identified physical actor episode completed")
	report.complete = failures.is_empty()
	report.checks = checks
	report.failures = failures
	report["completed_campaigns"] = completed.size()
	report["completed_actor_episodes"] = episodes
	checkpoint_report(report)
	print("AMBIENT2_EPISODES ",JSON.stringify({"mode":report.mode,"checks":checks,"failures":failures,
		"complete":report.complete,"campaigns":completed.size(),"episodes":episodes,
		"expected_episodes":expected_episodes,"report":report_path,"source_revision":source.source_revision,"case_id":selected_case}))
	quit(0 if failures.is_empty() else 1)

