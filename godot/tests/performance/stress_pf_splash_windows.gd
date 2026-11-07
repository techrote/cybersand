extends SceneTree

# Standalone current-main Windows graphical stress characterization. Runs the
# actual Main/Workbench/native worker/Rapier ownership path. No source patches.
# Selected case via CYBERSAND_STRESS_CASE=full-pf-off or half-pf-gas-on.
const Setup = preload("res://scripts/workbench_setup.gd")
const TARGET_SECONDS := 14.0
const WARMUP_TICKS := 30
const MAX_WAIT_MS := 90000
const MAX_PHYS_ROWS := 8192
const NUM_ACTORS := 8

class ObservedMain:
	extends "res://scripts/main.gd"
	var measuring := false
	var physics_rows: Array[Dictionary] = []
	var process_callbacks: int = 0
	var overflow := false

	func _process(delta: float) -> void:
		super(delta)
		if measuring:
			process_callbacks += 1

	func _physics_process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		var before: int = rapier_bridge.manual_step_count()
		super(delta)
		if not measuring:
			return
		if physics_rows.size() >= MAX_PHYS_ROWS:
			overflow = true
			return
		var after: int = rapier_bridge.manual_step_count()
		physics_rows.append({
			"duration_usec": Time.get_ticks_usec() - started,
			"physics_frame": Engine.get_physics_frames(),
			"step_delta": after-before,
			"bridge_step_count": after,
			"space_step_ms": rapier_bridge.last_step_time_ms() if after == before+1 else -1.0,
			"flush_ms": rapier_bridge.last_flush_time_ms() if after == before+1 else -1.0,
			"active_bodies": rapier_bridge.last_active_body_count() if after == before+1 else -1,
			"actor_tick": int(physical_actor_session.tick) if physical_actor_session != null else -1,
			"native_tick": int(latest_snapshot.tick_index) if latest_snapshot != null else -1
		})

var host: Control
var panel: Control
var mode: String = ""
var failures: Array[String] = []
var stage := "init"
var output_path: String = ""
var evidence: Dictionary = {}
var native_rows: Array[Dictionary] = []
var expected_install_epoch: int = -1
var expected_warmup_tick: int = -1

func has_installed_session() -> bool:
	return host != null and host.pending_microscenario_apply.is_empty() and host._physical_epoch > expected_install_epoch \
		and host.physical_actor_session != null and host._physical_terrain_ready \
		and panel != null and panel.applied.actors.size() == NUM_ACTORS

func has_completed_warmup() -> bool:
	return host != null and host.latest_snapshot != null \
		and int(host.latest_snapshot.tick_index) >= expected_warmup_tick + WARMUP_TICKS

func _initialize() -> void:
	run.call_deferred()

func fail(reason: String) -> void:
	failures.append(reason)
	push_error("STRESS_PF_SPLASH: " + reason)

func require(value: bool, message: String) -> bool:
	if not value:
		fail(message)
	return value

func until(predicate: Callable, label: String, timeout_ms: int = MAX_WAIT_MS) -> bool:
	var end_at: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < end_at:
		if predicate.call():
			return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed():
			break
		await process_frame
	return require(predicate.call(), label + " / " + (
		str(host.microscenario_error) if host != null else "host absent"))

func quantile(values: Array[float], q: float) -> float:
	if values.is_empty(): return -1.0
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[clampi(roundi(float(ordered.size()-1)*q), 0, ordered.size()-1)]

func cpu_free_wall_stats(rows: Array[Dictionary], key: String) -> Dictionary:
	var values: Array[float] = []
	for row: Dictionary in rows:
		if float(row.get(key,-1.0)) >= 0.0:
			values.append(float(row.get(key)))
	return {"n":values.size(), "p50":quantile(values,0.50),
		"p95":quantile(values,0.95), "p99":quantile(values,0.99),
		"max":quantile(values,1.0)}

func make_half_stress(policy: PackedInt32Array) -> Dictionary:
	# Preserve all authored material zones and all eight physical bodies; halve
	# every original rectangle and spawn position. Never invent a new tableau.
	var data: Dictionary = Setup.stress_canvas(policy)
	var edits: Array = []
	for raw: Array in data.edits:
		if raw.size() != 5:
			fail("stress-canvas contains an unsupported non-box stamp")
			return {}
		var x: int = floori(float(raw[0]) * 0.5)
		var y: int = floori(float(raw[1]) * 0.5)
		var far_x: int = ceili(float(int(raw[0])+int(raw[2])) * 0.5)
		var far_y: int = ceili(float(int(raw[1])+int(raw[3])) * 0.5)
		edits.append([x,y,maxi(1,far_x-x),maxi(1,far_y-y),int(raw[4])])
	data.edits = edits
	data.extent = [1024,512]
	var actors: Array = []
	for original: Dictionary in data.actors:
		var next_actor: Dictionary = original.duplicate(true)
		next_actor.spawn = [float(original.spawn[0])*0.5,float(original.spawn[1])*0.5]
		actors.append(next_actor)
	data.actors = actors
	return data

func select_policy(bridge: Object, selected_mode: String) -> PackedInt32Array:
	var request: PackedInt32Array = bridge.default_liquid_policy()
	if selected_mode == "full-pf-off":
		return request
	var matched := false
	for option: Dictionary in bridge.liquid_policy_assignment_choices(request, Setup.WATER):
		if str(option.get("family","")) == "pressure_flow_v1" and str(option.get("variant","")) == "cached_dormant" and bool(option.get("accepted",false)):
			request = PackedInt32Array(option.request)
			matched = true
			break
	if not require(matched,"native Water PF cached_dormant option unavailable"):
		return PackedInt32Array()
	var gas: Dictionary = bridge.liquid_policy_with_pressure_gas(request,true)
	if not require(bool(gas.get("accepted",false)),"native PF gas request refused: " + str(gas)):
		return PackedInt32Array()
	return PackedInt32Array(gas.request)

func sample_snapshot() -> Dictionary:
	var snap: CyberSimulationSnapshot = host.latest_snapshot
	if snap == null: return {}
	var context: Dictionary = host.tower_context
	var spray: Dictionary = context.get("water_spray",{})
	var ledger: Dictionary = spray.get("ledger",{})
	var amounts: Dictionary = spray.get("totals",{})
	var actors: Array = []
	var session: CyberPhysicalActorSession = host.physical_actor_session
	if session != null:
		for index: int in range(1,NUM_ACTORS+1):
			var state: Dictionary = session.workbench_actor_state(index)
			if state.is_empty(): continue
			var position: Vector2 = state.get("position",Vector2.ZERO)
			var velocity: Vector2 = state.get("linear_velocity",Vector2.ZERO)
			actors.append({
				"id":index, "position":[position.x,position.y],
				"linear_velocity":[velocity.x,velocity.y],
				"rotation":float(state.get("rotation",0.0)),
				"angular_velocity":float(state.get("angular_velocity",0.0))
			})
	return {
		"t_usec":Time.get_ticks_usec(),
		"native_tick":int(snap.tick_index),
		"simulation_time_ms":float(snap.simulation_time_ms),
		"worker_step_time_ms":float(snap.worker_step_time_ms),
		"rapier_tick":int(session.tick) if session != null else -1,
		"render_serial":int(snap.render_snapshot_serial),
		"water_spray":{"ballistic_enabled":spray.get("ballistic_enabled",false),
			"settings":spray.get("settings",{}).duplicate(true),
			"receipt":spray.get("receipt",{}).duplicate(true),
			"live":spray.get("live",0),"in_flight_quantity":spray.get("in_flight_quantity",0),
			"last_coupling":spray.get("last_coupling",{}).duplicate(true),
			"ledger":ledger.duplicate(true),"totals":amounts.duplicate(true)},
		"actors":actors
	}

func record() -> void:
	var row: Dictionary = sample_snapshot()
	if row.is_empty(): return
	if native_rows.is_empty() or row.native_tick != native_rows.back().native_tick:
		native_rows.append(row)

func finish() -> void:
	if host != null and is_instance_valid(host):
		if host.measuring: host.measuring = false
		if panel != null and is_instance_valid(panel) and not host.paused:
			panel.toggle_pause()
	evidence["stage"] = stage
	evidence["case"] = mode
	evidence["failures"] = failures
	evidence["native_rows"] = native_rows
	evidence["physics_rows"] = host.physics_rows if host != null and is_instance_valid(host) else []
	var report: String = JSON.stringify(evidence,"\t")
	if not output_path.is_empty():
		var file: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
		if file != null:
			file.store_string(report)
			file.close()
		else:
			fail("could not write result JSON: " + output_path)
	print("STRESS_PF_SPLASH_RESULT ", JSON.stringify(evidence.get("summary",{})),
		" case=",mode," failures=",failures.size()," stage=",stage)
	if host != null and is_instance_valid(host):
		host.queue_free()
		await process_frame
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	mode = OS.get_environment("CYBERSAND_STRESS_CASE")
	output_path = OS.get_environment("CYBERSAND_STRESS_OUTPUT")
	if not require(mode in ["full-pf-off","half-pf-gas-on"], "unsupported case: "+mode):
		await finish()
		return
	if not require(OS.get_name() == "Windows" and (
		DisplayServer.get_name() != "headless" or OS.get_environment("CYBERSAND_STRESS_ALLOW_HEADLESS") == "1"
	), "actual Windows application host required"):
		await finish()
		return
	stage = "create_workbench"
	set_meta("cybersand_feature","shared_workbench")
	root.size = Vector2i(960,540) if mode == "half-pf-gas-on" else Vector2i(1920,1080)
	# Keep native and Rapier standard 60Hz; avoid changing solver timesteps.
	Engine.max_fps = 0
	Engine.physics_ticks_per_second = 60
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second",60)
	host = load("res://main.tscn").instantiate()
	host.set_script(ObservedMain)
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),
		"initial workbench initialized", 90000):
		await finish()
		return
	panel = host.shared_workbench
	var bridge: Object = panel._liquids.bridge
	if not require(bridge != null, "native policy bridge absent"):
		await finish()
		return
	var policy: PackedInt32Array = select_policy(bridge,mode)
	if policy.is_empty():
		await finish()
		return
	var recipe: Dictionary = (Setup.stress_canvas(policy) if mode == "full-pf-off"
		else make_half_stress(policy))
	if recipe.is_empty():
		await finish()
		return
	var edit_materials := {}
	for edit: Array in recipe.edits:
		edit_materials[int(edit[4])] = true
	if not require(recipe.actors.size() == 8 and edit_materials.size() >= 50,
		"stress material/actor inventory lost during scaling"):
		await finish()
		return
	var err: String = Setup.validate(recipe)
	if not require(err.is_empty(), "native workbench recipe refused: "+err):
		await finish()
		return
	var packed: Dictionary = Setup.rectangles(recipe)
	if not require(not packed.has("error") and int(packed.get("runs",[]).size()/5) <= Setup.MAX_RUNS,
		"converted starting rectangles not admitted: "+str(packed.get("error","capacity"))):
		await finish()
		return
	evidence["host"] = {"windows":OS.get_name(),"display_server":DisplayServer.get_name(),
		"physics_hz":Engine.physics_ticks_per_second,"max_fps":Engine.max_fps}
	evidence["recipe"] = {"original":"stress-canvas","scale":1.0 if mode=="full-pf-off" else 0.5,
		"extent":recipe.extent, "stamps":recipe.edits.size(), "rectangles":int(packed.runs.size()/5),
		"materials":edit_materials.size(), "actors":recipe.actors.size(),
		"policy_sha256":str(policy), "face_tuning":[320,288,1,4]}
	# The same ballistic construction/tuning in both arms.
	host.workbench_water_options.merge({
		"workbench_ballistic":true,
		"workbench_face_release":true,
		"workbench_face_budget":320,
		"workbench_face_speed":288,
		"workbench_face_period":1,
		"workbench_face_min_height":4
	},true)
	expected_install_epoch = host._physical_epoch
	stage = "install"
	if not require(panel.apply(recipe), "workbench refused install: "+panel.message+" / "+host.microscenario_error):
		await finish()
		return
	if not await until(Callable(self,"has_installed_session"),
		"fresh stress World and Rapier actors installed",60000):
		await finish()
		return
	evidence["policy_readback"] = host.tower_context.get("liquid_solver_policy",{}).duplicate(true)
	if mode == "half-pf-gas-on":
		var found := false
		for assignment: Dictionary in evidence.policy_readback.get("assignments",[]):
			if int(assignment.get("material",-1)) == Setup.WATER:
				found = str(assignment.get("applied_family","")) == "pressure_flow_v1" and str(assignment.get("applied_variant","")) == "cached_dormant"
		if not require(found,"installed PF cached_dormant policy not read back"):
			await finish()
			return
	# Impact spray; no synthetic jet or external force is introduced.
	stage = "enable_spray"
	var spray_request := {"enabled":true,"launch_scale":1.6,"threshold":0.3,
		"upward_bias":0.72,"budget":64,"jet_enabled":false}
	if not require(panel.water_spray.request(spray_request),"impact spray queue refused"):
		await finish()
		return
	if not require(panel.toggle_pause(),"unpause refused: "+panel.message):
		await finish()
		return
	stage = "warmup"
	expected_warmup_tick = int(host.latest_snapshot.tick_index)
	if not await until(Callable(self,"has_completed_warmup"),
		"warmup 30 real native ticks",60000):
		evidence["worker_failure"] = host.tower_context.get("workbench_refusal",host.microscenario_error)
		await finish()
		return
	var initial_spray: Dictionary = host.tower_context.get("water_spray",{})
	if not require(bool(initial_spray.get("ballistic_enabled",false)), "ballistic Water not active"):
		await finish()
		return
	if not require(bool(initial_spray.get("settings",{}).get("enabled",false)),
		"impact spray not enabled in actual native readback"):
		await finish()
		return
	stage = "measure"
	host.physics_rows.clear()
	host.process_callbacks = 0
	host.measuring = true
	var begin_usec: int = Time.get_ticks_usec()
	var begin_tick: int = int(host.latest_snapshot.tick_index)
	var begin_actor_tick: int = int(host.physical_actor_session.tick)
	var begin_physics_frame: int = Engine.get_physics_frames()
	var begin_process_frame: int = Engine.get_process_frames()
	var begin_bridge_step: int = host.rapier_bridge.manual_step_count()
	var end_usec: int = begin_usec + int(TARGET_SECONDS * 1000000.0)
	while Time.get_ticks_usec() < end_usec:
		if host.simulation_worker.has_failed() or not str(host.tower_context.get("workbench_refusal","")).is_empty():
			break
		await process_frame
		record()
	var stopped_usec: int = Time.get_ticks_usec()
	host.measuring = false
	record()
	var elapsed: float = float(stopped_usec-begin_usec)/1000000.0
	var final_tick: int = int(host.latest_snapshot.tick_index)
	var step_samples: Array[float] = []
	var physics_samples: Array[float] = []
	var counted: int = 0
	for row: Dictionary in host.physics_rows:
		physics_samples.append(float(row.duration_usec)/1000.0)
		if int(row.step_delta)==1 and float(row.space_step_ms) >= 0:
			step_samples.append(float(row.space_step_ms))
			counted += 1
	var tick_samples: Array[float] = []
	var first_actor_pos: Array = []
	var last_actor_pos: Array = []
	var max_spray_live: int = 0
	for row: Dictionary in native_rows:
		tick_samples.append(float(row.simulation_time_ms))
		max_spray_live = maxi(max_spray_live,int(row.water_spray.get("live",0)))
	if not native_rows.is_empty():
		for actor: Dictionary in native_rows.front().actors:
			first_actor_pos.append(actor.get("position",[]))
		for actor: Dictionary in native_rows.back().actors:
			last_actor_pos.append(actor.get("position",[]))
	var final_spray: Dictionary = host.tower_context.get("water_spray",{})
	var summary: Dictionary = {
		"duration_s":elapsed, "native_ticks":final_tick-begin_tick,
		"native_ticks_per_s":float(final_tick-begin_tick)/elapsed if elapsed>0 else 0.0,
		"rapier_ticks":int(host.physical_actor_session.tick)-begin_actor_tick,
		"rapier_ticks_per_s":float(int(host.physical_actor_session.tick)-begin_actor_tick)/elapsed if elapsed>0 else 0.0,
		"bridge_steps":host.rapier_bridge.manual_step_count()-begin_bridge_step,
		"physics_callbacks":Engine.get_physics_frames()-begin_physics_frame,
		"process_callbacks":Engine.get_process_frames()-begin_process_frame,
		"observed_process_callbacks":host.process_callbacks,
		"native_tick_ms":cpu_free_wall_stats(native_rows,"simulation_time_ms"),
		"physics_callback_ms":{"n":physics_samples.size(),"p50":quantile(physics_samples,0.5),
			"p95":quantile(physics_samples,0.95),"p99":quantile(physics_samples,0.99),
			"max":quantile(physics_samples,1.0)},
		"space_step_wall_ms":{"n":step_samples.size(),"p50":quantile(step_samples,0.5),
			"p95":quantile(step_samples,0.95),"p99":quantile(step_samples,0.99),
			"max":quantile(step_samples,1.0),"over_40ms":step_samples.filter(func(v:float)->bool: return v>40.0).size()},
		"splash_enabled":bool(final_spray.get("settings",{}).get("enabled",false)),
		"ballistic_enabled":bool(final_spray.get("ballistic_enabled",false)),
		"max_live_parcels":max_spray_live,
		"spray_ledger":final_spray.get("ledger",{}).duplicate(true),
		"spray_totals":final_spray.get("totals",{}).duplicate(true),
		"spray_receipt":final_spray.get("receipt",{}).duplicate(true),
		"first_actor_positions":first_actor_pos,"last_actor_positions":last_actor_pos,
		"native_failure":host.simulation_worker.has_failed(),
		"workbench_refusal":str(host.tower_context.get("workbench_refusal","")),
		"overflow":host.overflow
	}
	evidence["summary"] = summary
	if not require(elapsed > 8.0 and final_tick-begin_tick >= 15 and counted >= 15 and not host.overflow,
		"insufficient real native/Rapier progress or sample overflow"):
		await finish()
		return
	if not require(not summary.native_failure and str(summary.workbench_refusal).is_empty(),
		"World failed during measurement: "+str(summary.workbench_refusal)):
		await finish()
		return
	if not require(bool(summary.splash_enabled) and bool(summary.ballistic_enabled),
		"ballistic/impact spray switched off unexpectedly"):
		await finish()
		return
	stage = "complete"
	await finish()
