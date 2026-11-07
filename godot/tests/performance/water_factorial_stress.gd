extends SceneTree

# One-process bounded factorial shard: identical 1024x512 stress-canvas,
# eight live Rapier barrels, 59 materials, fixed native-tick windows.
# Configurations are generated independently by tools/ci/stress_water_factorial.py.
# No production physics/renderer/worker source is changed.

const Setup = preload("res://scripts/workbench_setup.gd")
const WARMUP_TICKS := 30
const MEASURE_TICKS := 100
const MAX_CASE_MS := 50000
const MAX_INSTALL_MS := 30000
const MAX_STARTUP_MS := 90000
const ACTOR_COUNT := 8

class ObservedMain:
	extends "res://scripts/main.gd"
	var measuring := false
	var space_step_rows: Array[Dictionary] = []
	var physics_callback_count := 0

	func _physics_process(delta: float) -> void:
		var start: int = Time.get_ticks_usec()
		var before: int = rapier_bridge.manual_step_count()
		super(delta)
		if not measuring: return
		physics_callback_count += 1
		var after: int = rapier_bridge.manual_step_count()
		if after == before + 1:
			space_step_rows.append({
				"wall_ms":rapier_bridge.last_step_time_ms(),
				"callback_ms":float(Time.get_ticks_usec()-start)/1000.0,
				"active_bodies":rapier_bridge.last_active_body_count(),
				"frame":Engine.get_physics_frames()
			})

var host: Control
var panel: Control
var manifest: Dictionary
var output_path := ""
var trial_rows: Array[Dictionary] = []
var current_epoch := -1
var current_warmup_end := -1
var batch_failure := ""
var current_case_id := ""

func _initialize() -> void:
	run.call_deferred()

func ready_initial() -> bool:
	return host != null and is_instance_valid(host) and host.shared_workbench != null \
		and not host.shared_workbench.applied.is_empty() and host.simulation_worker != null

func ready_installed() -> bool:
	return host != null and not host.pending_microscenario_apply.is_empty() == false \
		and host._physical_epoch > current_epoch \
		and host.physical_actor_session != null and host._physical_terrain_ready \
		and panel != null and not panel.busy() and panel.applied.actors.size() == ACTOR_COUNT

func ready_warmup() -> bool:
	return host != null and host.latest_snapshot != null \
		and int(host.latest_snapshot.tick_index) >= current_warmup_end

func bounded(condition: Callable, timeout_ms: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed():
			return false
		await process_frame
	return condition.call()

func config_error(kind: String, cfg: Dictionary, detail: String) -> Dictionary:
	return {
		"id":str(cfg.get("id","missing")),
		"replicate":int(cfg.get("replicate",-1)),
		"shard":int(cfg.get("shard",-1)),
		"status":kind,
		"reason":detail,
		"config":cfg.duplicate(true)
	}

func percent(values: Array[float], q: float) -> float:
	if values.is_empty(): return -1.0
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[clampi(roundi(float(ordered.size()-1)*q),0,ordered.size()-1)]

func same_canvas(policy: PackedInt32Array) -> Dictionary:
	var data: Dictionary = Setup.stress_canvas(policy)
	var boxes: Array = []
	for stamp: Array in data.edits:
		if stamp.size() != 5: return {}
		var x: int = floori(float(stamp[0])*0.5)
		var y: int = floori(float(stamp[1])*0.5)
		var x2: int = ceili(float(int(stamp[0])+int(stamp[2]))*0.5)
		var y2: int = ceili(float(int(stamp[1])+int(stamp[3]))*0.5)
		boxes.append([x,y,maxi(1,x2-x),maxi(1,y2-y),int(stamp[4])])
	data.edits = boxes
	data.extent = [1024,512]
	var actors: Array = []
	for old: Dictionary in data.actors:
		var actor: Dictionary = old.duplicate(true)
		actor.spawn = [float(old.spawn[0])*0.5,float(old.spawn[1])*0.5]
		actors.append(actor)
	data.actors = actors
	return data

func water_policy(bridge: Object, cfg: Dictionary) -> PackedInt32Array:
	var default_policy: PackedInt32Array = bridge.default_liquid_policy()
	var family: String = str(cfg.get("family",""))
	var variant: String = str(cfg.get("variant",""))
	var selected: PackedInt32Array = PackedInt32Array()
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(default_policy,Setup.WATER):
		if str(choice.get("family","")) == family and str(choice.get("variant","")) == variant:
			if bool(choice.get("accepted",false)):
				selected = PackedInt32Array(choice.request)
			else:
				batch_failure = str(choice.get("refusal",{}))
			break
	if family == "freemass_v1" and selected.is_empty():
		selected = default_policy
	if selected.is_empty():
		if batch_failure.is_empty(): batch_failure = "No native Water policy choice for "+family+"/"+variant
		return selected
	if family == "pressure_flow_v1":
		var gas: Dictionary = bridge.liquid_policy_with_pressure_gas(
			selected, bool(cfg.get("gas",false)))
		if not bool(gas.get("accepted",false)):
			batch_failure = "Native gas option refused: "+str(gas.get("refusal",{}))
			return PackedInt32Array()
		return PackedInt32Array(gas.request)
	return selected

func capture_actors() -> Array:
	var out: Array = []
	if host == null or host.physical_actor_session == null: return out
	for id: int in range(1,ACTOR_COUNT+1):
		var a: Dictionary = host.physical_actor_session.workbench_actor_state(id)
		if a.is_empty(): continue
		var p: Vector2 = a.get("position",Vector2.ZERO)
		var v: Vector2 = a.get("linear_velocity",Vector2.ZERO)
		out.append({"id":id,"position":[p.x,p.y],"velocity":[v.x,v.y],
			"rotation":float(a.get("rotation",0)),"omega":float(a.get("angular_velocity",0))})
	return out

func write_progress() -> void:
	if output_path.is_empty(): return
	var file: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"schema":"water-factorial-result-v1",
			"pilot":bool(manifest.get("pilot",false)),
			"seed":manifest.get("seed",""),
			"replicate":manifest.get("replicate",-1),
			"shard":manifest.get("shard",-1),
			"cases":trial_rows,
			"batch_failure":batch_failure
		}, "\t"))
		file.close()

func recover_host() -> bool:
	if host != null and is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	host = null
	panel = null
	var new_host: Control = load("res://main.tscn").instantiate()
	new_host.set_script(ObservedMain)
	host = new_host
	root.add_child(host)
	if not await bounded(Callable(self,"ready_initial"),MAX_STARTUP_MS):
		batch_failure = "initial workbench startup did not finish"
		return false
	panel = host.shared_workbench
	return true

func ensure_paused() -> bool:
	if host == null or panel == null: return false
	if not host.paused:
		return panel.toggle_pause()
	return true

func policy_readback(cfg: Dictionary) -> String:
	var policy: Dictionary = host.tower_context.get("liquid_solver_policy",{})
	var seen := false
	for row: Dictionary in policy.get("assignments",[]):
		if int(row.get("material",-1)) == Setup.WATER:
			if str(row.get("applied_family","")) != str(cfg.family) \
				or str(row.get("applied_variant","")) != str(cfg.variant):
				return "Native Water family/variant mismatch: "+str(row)
			seen = true
			break
	if not seen: return "Native policy missing Water entry"
	if str(cfg.family) == "pressure_flow_v1":
		var pf: Dictionary = policy.get("family_parameters",{}).get("pressure_flow_v1",{})
		if not pf.has("gas_enabled") or bool(pf.gas_enabled) != bool(cfg.gas):
			return "Native PF gas readback mismatch: "+str(pf)
	return ""

func apply_case(cfg: Dictionary) -> Dictionary:
	current_case_id = str(cfg.id)
	batch_failure = ""
	var started_ms: int = Time.get_ticks_msec()
	if host == null or not is_instance_valid(host) or host.simulation_worker.has_failed():
		if not await recover_host():
			return config_error("HOST_FAIL",cfg,batch_failure)
	if not ensure_paused():
		return config_error("HOST_FAIL",cfg,"could not pause existing World")
	var bridge: Object = panel._liquids.bridge
	if bridge == null:
		return config_error("HOST_FAIL",cfg,"native liquid policy bridge unavailable")
	var policy: PackedInt32Array = water_policy(bridge,cfg)
	if policy.is_empty():
		return config_error("POLICY_REFUSED",cfg,batch_failure)
	var recipe: Dictionary = same_canvas(policy)
	if recipe.is_empty():
		return config_error("HARNESS_FAIL",cfg,"stress recipe conversion failed")
	recipe.normalize = bool(cfg.normalize)
	recipe.rule_radius = int(cfg.rule_radius)
	var error: String = Setup.validate(recipe)
	if not error.is_empty():
		return config_error("RECIPE_REFUSED",cfg,error)
	var rectangles: Dictionary = Setup.rectangles(recipe)
	if rectangles.has("error") or rectangles.get("runs",[]).size()/5 > Setup.MAX_RUNS:
		return config_error("RECIPE_REFUSED",cfg,"rectangle validation: "+str(rectangles.get("error","capacity")))
	if recipe.actors.size()!=ACTOR_COUNT or recipe.edits.size()!=119:
		return config_error("HARNESS_FAIL",cfg,"altered original stress material/actor inventory")

	# Reset all finite construction switches before every independent World.
	host.workbench_water_options.clear()
	host.workbench_water_options.merge({
		"workbench_ballistic":bool(cfg.ballistic),
		"workbench_face_release":bool(cfg.face),
		"workbench_inertial_signed":bool(cfg.signed),
		"workbench_fine_cores":bool(cfg.fine),
		"workbench_face_budget":320, "workbench_face_speed":288,
		"workbench_face_period":1,"workbench_face_min_height":4
	},true)
	current_epoch = host._physical_epoch
	if not panel.apply(recipe):
		return config_error("INSTALL_REFUSED",cfg,str(panel.message)+" / "+str(host.microscenario_error))
	if not await bounded(Callable(self,"ready_installed"),MAX_INSTALL_MS):
		var why: String = str(host.microscenario_error)
		if host.simulation_worker.has_failed(): why += " / worker FAILED"
		return config_error("INSTALL_FAIL",cfg,why)
	error = policy_readback(cfg)
	if not error.is_empty():
		return config_error("POLICY_MISMATCH",cfg,error)
	var config_spray: Dictionary = {
		"enabled":bool(cfg.spray),"jet_enabled":bool(cfg.jet),
		"jet_origin":Vector2i(816,360),"jet_angle":-62.0,
		"jet_speed":3.4,"jet_rate":3,"jet_quantity":96,
		"launch_scale":1.6,"threshold":0.3,"upward_bias":0.72,
		"budget":64,"reaction_gain":0.0
	}
	var request_ok: bool = panel.water_spray.request(config_spray)
	if not request_ok and (bool(cfg.spray) or bool(cfg.jet)):
		return config_error("SPRAY_REFUSED",cfg,"active impact/jet request rejected at queue")
	if not panel.toggle_pause():
		return config_error("UNPAUSE_FAIL",cfg,str(panel.message))
	current_warmup_end = int(host.latest_snapshot.tick_index)+WARMUP_TICKS
	if not await bounded(Callable(self,"ready_warmup"),MAX_CASE_MS):
		return config_error("WARMUP_FAIL",cfg,"insufficient warmup ticks / "+str(host.microscenario_error))
	var initial_spray: Dictionary = host.tower_context.get("water_spray",{})
	var settings: Dictionary = initial_spray.get("settings",{})
	if bool(initial_spray.get("ballistic_enabled",false)) != bool(cfg.ballistic):
		return config_error("OPTIONS_MISMATCH",cfg,"ballistic readback disagrees: "+str(initial_spray))
	if bool(settings.get("enabled",false)) != bool(cfg.spray):
		return config_error("OPTIONS_MISMATCH",cfg,"impact spray disagrees: "+str(settings))
	if bool(settings.get("jet_enabled",false)) != bool(cfg.jet):
		return config_error("OPTIONS_MISMATCH",cfg,"jet disagrees: "+str(settings))
	if bool(initial_spray.get("inertial_signed",false)) != bool(cfg.signed):
		return config_error("OPTIONS_MISMATCH",cfg,"IN signed disagrees: "+str(initial_spray.get("inertial_signed")))
	# Fixed native-tick budget, not a wall-time-only benchmark. All case
	# workloads have exactly the same authored world and initial actor positions.
	var start_tick: int = int(host.latest_snapshot.tick_index)
	var start_rapier: int = int(host.physical_actor_session.tick)
	var start_usec: int = Time.get_ticks_usec()
	var limit: int = Time.get_ticks_msec()+MAX_CASE_MS
	var last_tick: int = -1
	var samples: Array[Dictionary] = []
	var actors_first: Array = capture_actors()
	var actor_intermediate: Array = []
	host.measuring = true
	host.physics_callback_count = 0
	host.space_step_rows.clear()
	var world_failure := ""
	while Time.get_ticks_msec() < limit:
		if host.simulation_worker.has_failed():
			world_failure = "worker failed: "+str(host.microscenario_error)
			break
		var context_error: String = str(host.tower_context.get("workbench_refusal",""))
		if not context_error.is_empty():
			world_failure = context_error
			break
		if host.latest_snapshot != null:
			var snap: CyberSimulationSnapshot = host.latest_snapshot
			var tick: int = int(snap.tick_index)
			if tick > start_tick and tick != last_tick:
				last_tick = tick
				var water: Dictionary = host.tower_context.get("water_spray",{})
				var spray_led: Dictionary = water.get("ledger",{})
				samples.append({
					"tick":tick,"simulation_ms":float(snap.simulation_time_ms),
					"worker_ms":float(snap.worker_step_time_ms),
					"parcels":int(water.get("live",0)),
					"launched":int(spray_led.get("launched_parcels",0)),
					"body_contacts":int(spray_led.get("body_contacts",0))
				})
				if (tick-start_tick)%20 == 0: actor_intermediate.append({
					"native_tick":tick, "actors":capture_actors()
				})
			if tick >= start_tick + MEASURE_TICKS:
				break
		await process_frame
	host.measuring = false
	var end_usec: int = Time.get_ticks_usec()
	var end_tick: int = int(host.latest_snapshot.tick_index) if host.latest_snapshot != null else -1
	var stop_spray: Dictionary = host.tower_context.get("water_spray",{})
	var times: Array[float] = []
	var worker_times: Array[float] = []
	var steps: Array[float] = []
	for row: Dictionary in samples:
		times.append(float(row.simulation_ms))
		worker_times.append(float(row.worker_ms))
	for row: Dictionary in host.space_step_rows:
		steps.append(float(row.wall_ms))
	var seconds: float = maxf(float(end_usec-start_usec)/1000000.0,0.000001)
	var observed_ticks: int = maxi(0,end_tick-start_tick)
	var result: Dictionary = {
		"id":current_case_id,
		"replicate":int(cfg.replicate),"shard":int(cfg.shard),
		"status":"PASS","reason":"",
		"config":cfg.duplicate(true),
		"summary":{
			"native_ticks":observed_ticks,
			"native_hz":float(observed_ticks)/seconds,
			"rapier_ticks":int(host.physical_actor_session.tick)-start_rapier,
			"duration_s":seconds,
			"native_tick_p50_ms":percent(times,0.5),
			"native_tick_p95_ms":percent(times,0.95),
			"native_tick_p99_ms":percent(times,0.99),
			"native_tick_max_ms":percent(times,1.0),
			"worker_p50_ms":percent(worker_times,0.5),
			"rapier_step_p50_ms":percent(steps,0.5),
			"rapier_step_p95_ms":percent(steps,0.95),
			"rapier_step_max_ms":percent(steps,1.0),
			"rapier_steps_over_40ms":steps.filter(func(value:float)->bool:return value>40.0).size(),
			"rapier_steps_sampled":steps.size(),
			"snapshot_samples":samples.size(),
			"physics_callback_count":host.physics_callback_count,
			"elapsed_case_s":float(Time.get_ticks_msec()-started_ms)/1000.0,
			"spray_ledger":stop_spray.get("ledger",{}).duplicate(true),
			"spray_totals":stop_spray.get("totals",{}).duplicate(true),
			"spray_receipt":stop_spray.get("receipt",{}).duplicate(true),
			"final_actor_states":capture_actors(),
			"initial_actor_states":actors_first,
			"actor_trace":actor_intermediate,
			"native_wall_samples_ms":times,
			"worker_wall_samples_ms":worker_times,
			"rapier_wall_samples_ms":steps
		}
	}
	if not world_failure.is_empty():
		result.status = "WORLD_FAIL"
		result.reason = world_failure
	elif observed_ticks < MEASURE_TICKS or steps.size() < 10:
		result.status = "INCOMPLETE"
		result.reason = "Expected fixed native tick budget "+str(MEASURE_TICKS)+", got "+str(observed_ticks)
	if not host.paused:
		panel.toggle_pause()
	return result

func run() -> void:
	var manifest_file: String = OS.get_environment("CYBERSAND_FACTORIAL_MANIFEST")
	output_path = OS.get_environment("CYBERSAND_FACTORIAL_OUTPUT")
	if manifest_file.is_empty() or output_path.is_empty():
		push_error("WATER_FACTORIAL: manifest and output path required")
		quit(2)
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_file))
	if not raw is Dictionary:
		push_error("WATER_FACTORIAL: invalid manifest")
		quit(2)
		return
	manifest = raw
	if str(manifest.get("schema","")) != "water-factorial-manifest-v1":
		push_error("WATER_FACTORIAL: wrong manifest schema")
		quit(2)
		return
	if OS.get_name() != "Windows":
		push_error("WATER_FACTORIAL: Windows native runtime required")
		quit(2)
		return
	set_meta("cybersand_feature","shared_workbench")
	root.size = Vector2i(960,540)
	Engine.max_fps = 0
	Engine.physics_ticks_per_second = 60
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second",60)
	if not await recover_host():
		push_error("WATER_FACTORIAL: initial application host failed")
		quit(2)
		return
	var cases: Array = manifest.get("cases",[])
	for i: int in range(cases.size()):
		var cfg: Dictionary = cases[i]
		var result: Dictionary = await apply_case(cfg)
		trial_rows.append(result)
		write_progress()
		print("WATER_FACTORIAL_CASE "+JSON.stringify({
			"id":result.id,"replicate":result.replicate,"status":result.status,
			"reason":result.reason,
			"p50":result.get("summary",{}).get("native_tick_p50_ms",-1),
			"hz":result.get("summary",{}).get("native_hz",-1)
		}))
		if result.status not in ["PASS"]:
			push_warning("WATER_FACTORIAL case "+result.id+" "+result.status+": "+str(result.reason))
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed():
			if not await recover_host():
				batch_failure = "could not recover from prior World's failure"
				break
	if host != null and is_instance_valid(host):
		host.queue_free()
		await process_frame
	write_progress()
	print("WATER_FACTORIAL_DONE "+JSON.stringify({
		"total":trial_rows.size(),"expected":cases.size(),
		"passed":trial_rows.filter(func(row:Dictionary)->bool:return row.status=="PASS").size(),
		"batch_failure":batch_failure
	}))
	quit(0 if trial_rows.size() == cases.size() else 1)
