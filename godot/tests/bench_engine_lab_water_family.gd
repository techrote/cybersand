extends SceneTree

# ENG-LAB-001 Phase B: real Workbench, real native Water and an actual human-owned
# Needle flyer. Every subprocess starts a fresh identical authored World.
# No input tape, simulated keypress, proxy solver, alternative Rapier step or
# replacement render transport is introduced by this measurement fixture.
const Setup = preload("res://scripts/workbench_setup.gd")
const EXPECTED_GODOT: String = "4.7.stable.official.5b4e0cb0f"
const WORLD_EXTENT := Vector2i(1024,1024)
const RENDER_WINDOW := Vector2i(1600,900)
const CAMERA_VIEW := Vector2i(960,540)
const CAMERA_ORIGIN := Vector2(16,155)
const WATER_MATERIAL: int = 3
const MEASURE_USEC: int = 10000000
const WARMUP_USEC: int = 1000000
const INSTALL_TIMEOUT_MS: int = 120000
const MEASURE_TIMEOUT_MS: int = 90000
const FAMILY_CONTRACT: Dictionary = {
	"pressure":{"family":"pressure_flow_v1","variant":"cached_dormant"},
	"freemass":{"family":"freemass_v1","variant":"reference"},
	"cellular":{"family":"cellular_yield_v1","variant":"reference"},
	"inertial":{"family":"inertial_cellular_v1","variant":"reference"},
}

var family: String = ""
var workers: int = -1
var repetition: int = 0
var output_path: String = ""
var errors: Array[String] = []
var assertions: int = 0
var fixture_hash: String = ""
var configured_policy_hash: String = ""
var required_rule_radius: int = 2
var observed_policy: Dictionary = {}
var actor_initial: Dictionary = {}
var actor_final: Dictionary = {}
var last_report: Dictionary = {}
var native_workbench_receipt: Dictionary = {}
var _host: Control
var _panel: Window


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--family="): family = arg.trim_prefix("--family=")
		if arg.begins_with("--workers="): workers = int(arg.trim_prefix("--workers="))
		if arg.begins_with("--repeat="): repetition = int(arg.trim_prefix("--repeat="))
		if arg.begins_with("--receipt="): output_path = arg.trim_prefix("--receipt=")
	if family not in FAMILY_CONTRACT or workers not in [1,4] or repetition not in [1,2] or output_path.is_empty():
		push_error("ENGINE_LAB_WATER: invalid case options")
		quit(2)
		return
	var version: Dictionary = Engine.get_version_info()
	print("ENGINE_LAB_WATER_ENGINE ",JSON.stringify({"display":DisplayServer.get_name(),
		"version":version,"adapter":RenderingServer.get_video_adapter_name()}))
	# The external runner authenticates the *exact* official Godot binary via
	# --version and its SHA-256. Engine.version_info.string omits the build SHA.
	if DisplayServer.get_name() == "headless" or int(version.get("major",-1)) != 4 or int(version.get("minor",-1)) != 7:
		push_error("ENGINE_LAB_WATER: real graphical Godot 4.7 required")
		quit(2)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	Engine.max_fps = 60
	root.size = RENDER_WINDOW
	set_meta("cybersand_feature","shared_workbench")
	_run.call_deferred()


func check(ok: bool, what: String) -> bool:
	assertions += 1
	if not ok:
		errors.append(what)
		push_error("ENGINE_LAB_WATER: " + what)
	return ok


func _initial_ready() -> bool:
	return (is_instance_valid(_host) and _host.shared_workbench != null
		and not _host.shared_workbench.applied.is_empty()
		and _host.latest_snapshot != null
		and not _host.simulation_worker.has_failed())


func _applied_water() -> Dictionary:
	var policy: Dictionary = _host.tower_context.get("liquid_solver_policy",{})
	for assignment: Dictionary in policy.get("assignments",[]):
		if int(assignment.get("material",-1)) == WATER_MATERIAL:
			return assignment
	return {}


func _installed() -> bool:
	if not _initial_ready() or _host.pending_microscenario_apply.size() > 0:
		return false
	if _host.physical_actor_session == null or not _host._physical_terrain_ready:
		return false
	if _host.rapier_bridge != _host.physical_actor_session.bridge or not _host.rapier_bridge.is_initialized():
		return false
	if Setup.extent_of(_host.shared_workbench.applied) != WORLD_EXTENT:
		return false
	var chosen: Dictionary = FAMILY_CONTRACT[family]
	var applied: Dictionary = _applied_water()
	return (not applied.is_empty()
		and str(applied.get("applied_family","")) == str(chosen.family)
		and str(applied.get("applied_variant","")) == str(chosen.variant))


func _running() -> bool:
	return (_installed() and not _host.paused
		and _host.latest_snapshot.tick_index > 0
		and _host.rapier_bridge.manual_step_count() > 0
		and _host.physical_actor_session.tick > 0)


func _benchmark_done() -> bool:
	return _panel != null and _panel.recorder.finished


func _wait_for(predicate: Callable, limit_ms: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if _host != null and is_instance_valid(_host) and _host.simulation_worker.has_failed():
			return false
		await process_frame
	return false


func _requested_policy() -> PackedInt32Array:
	var bridge: Variant = _host.shared_workbench._liquids.bridge
	var baseline: PackedInt32Array = bridge.default_liquid_policy()
	var wanted: Dictionary = FAMILY_CONTRACT[family]
	var choices: Array = bridge.liquid_policy_assignment_choices(baseline,WATER_MATERIAL)
	var selected := PackedInt32Array()
	for choice: Dictionary in choices:
		if str(choice.get("family","")) != str(wanted.family) or str(choice.get("variant","")) != str(wanted.variant):
			continue
		if not bool(choice.get("accepted",false)):
			check(false,"native policy choice refused: " + str(choice.get("refusal",{})))
			return selected
		selected = choice.request
		break
	if selected.is_empty():
		check(false,"no explicit native choice for Water " + str(wanted.family) + "/" + str(wanted.variant))
		return selected
	var validation: Dictionary = bridge.validate_liquid_policy(selected)
	if not check(bool(validation.get("accepted",false)),
		"native policy validator must admit family " + family):
		return PackedInt32Array()
	required_rule_radius = int(validation.get("receipt",{}).get("minimum_rule_radius",2))
	if not check(required_rule_radius in [2,3], "admitted native geometry radius must be 2 or 3"):
		return PackedInt32Array()
	return selected


func _common_fixture(policy: PackedInt32Array) -> Dictionary:
	var d: Dictionary = Setup.fresh(policy,WORLD_EXTENT)
	d.actors = [Setup.instance("needle",1,Vector2(459,215))]
	d.next_id = 2
	d.selected = 1
	d.material = WATER_MATERIAL
	d.rule_radius = required_rule_radius
	# Every variant receives these identical source rectangle stamps. The
	# complete World is finite and built by the normal native prepared path.
	# Two reservoirs, an obstructing weir and overhead Sand stimulate movement
	# without issuing any input while the benchmark samples.
	d.edits = [
		[62,743,896,14,Setup.WALL],       # continuous hard floor
		[62,268,14,475,Setup.WALL],       # left retaining wall
		[944,268,14,475,Setup.WALL],      # right retaining wall
		[498,410,14,333,Setup.WALL],      # central height differential / weir
		[85,458,384,265,WATER_MATERIAL], # high reservoir
		[530,520,384,203,WATER_MATERIAL],# lower reservoir
		[170,330,220,75,WATER_MATERIAL], # falling water ledge
		[605,350,172,58,Setup.SAND],     # moving sand shelf
		[805,290,90,35,Setup.SAND],      # farther disturbance
		[382,425,90,11,Setup.WALL],      # collision lip beside Needle descent
	]
	# All policies and solver variants share precisely the same recipe,
	# actor spawn, material, physical options, edit order and rate knobs.
	var without_policy: Dictionary = d.duplicate(true)
	without_policy.liquid_policy = []
	# IN is admitted only at radius3, normal other Water families at radius2.
	# Preserve identical authored cells/actors and disclose this necessary geometry confound.
	without_policy.rule_radius = 0
	fixture_hash = JSON.stringify(without_policy).sha256_text()
	check(Setup.validate(d).is_empty(),"fixture schema valid")
	return d


func _stop(reason: String) -> void:
	if _panel != null and is_instance_valid(_panel) and _panel.recorder.running:
		_panel.recorder.abort(reason, Time.get_ticks_usec())
		if _host != null and is_instance_valid(_host): _host.engine_lab_benchmark_active = false
	if _panel != null and is_instance_valid(_panel) and _panel.recorder.finished:
		last_report = _panel.recorder.outcome


func _finish() -> void:
	var chosen: Dictionary = FAMILY_CONTRACT.get(family,{})
	var s: CyberSimulationSnapshot = _host.latest_snapshot if _host != null and is_instance_valid(_host) else null
	var state: Dictionary = {
		"schema":"eng-lab-001-water-family-real-workbench-v1",
		"ok":errors.is_empty() and last_report.get("status","") == "passed",
		"family":family,"native_family":chosen.get("family",""),
		"native_variant":chosen.get("variant",""),
		"worker_request":workers,"repetition":repetition,
		"fixture_sha256":fixture_hash,
		"policy_sha256":configured_policy_hash,
		"minimum_native_rule_radius":required_rule_radius,
		"applied_native_policy":observed_policy,
		"native_construction_receipt":native_workbench_receipt,
		"world_size":[WORLD_EXTENT.x,WORLD_EXTENT.y],
		"camera_origin":[CAMERA_ORIGIN.x,CAMERA_ORIGIN.y],
		"camera_size":[CAMERA_VIEW.x,CAMERA_VIEW.y],
		"requested_window":[RENDER_WINDOW.x,RENDER_WINDOW.y],
		"window_size":[root.size.x,root.size.y],
		"native_workers_configured":s.scheduler_thread_capacity_hint if s != null else -1,
		"native_worker_request_readback":s.native_worker_request if s != null else -1,
		"actor_model":"needle","actor_initial":actor_initial,"actor_final":actor_final,
		"active_actor_tick":_host.physical_actor_session.tick if _host != null and is_instance_valid(_host) and _host.physical_actor_session != null else -1,
		"run_tick":s.tick_index if s != null else -1,
		"assertions":assertions,"failures":errors,
		"benchmark":last_report,
	}
	if state.ok:
		check(bool(last_report.get("native_ticks",0) > 0)
			and bool(last_report.get("rapier_steps",0) > 0)
			and not actor_initial.is_empty() and not actor_final.is_empty(),
			"real native/Rapier/flyer all progress during measured interval")
		check(int(state.native_worker_request_readback) == workers,
			"actual worker source request matches selected campaign worker count")
		check(state.window_size == state.requested_window,
			"actual graphical window size is exact and matched")
		state.ok = errors.is_empty()
		state.assertions = assertions
		state.failures = errors.duplicate()
	if not output_path.is_empty():
		var file: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
		if file == null:
			push_error("ENGINE_LAB_WATER: output receipt not writable: " + output_path)
			state.ok = false
		else:
			file.store_string(JSON.stringify(state,"\t") + "\n")
			file.close()
	print("ENGINE_LAB_WATER: ",JSON.stringify({"family":family,"workers":workers,
		"repetition":repetition,"ok":state.ok,"assertions":assertions,
		"failures":errors,"native_ticks":last_report.get("native_ticks",-1),
		"rapier_steps":last_report.get("rapier_steps",-1),
		"frame_p95_ms":last_report.get("frame_interval_ms",{}).get("p95",-1),
		"source":last_report.get("identity",{}).get("source_revision","")}))
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	await process_frame
	quit(0 if state.ok else 1)


func _run() -> void:
	_host = load("res://main.tscn").instantiate()
	root.add_child(_host)
	if not check(await _wait_for(Callable(self,"_initial_ready"),INSTALL_TIMEOUT_MS),
		"Shared Workbench first native World installed"):
		await _finish()
		return
	var policy: PackedInt32Array = _requested_policy()
	if policy.is_empty():
		await _finish()
		return
	var setup: Dictionary = _common_fixture(policy)
	if not errors.is_empty():
		await _finish()
		return
	configured_policy_hash = JSON.stringify(Array(policy)).sha256_text()
	if not check(_host.shared_workbench.apply(setup),
		"real native prepared Workbench replacement accepted: "+str(_host.microscenario_error)):
		await _finish()
		return
	if not check(await _wait_for(Callable(self,"_installed"),INSTALL_TIMEOUT_MS),
		"correct native Water family applied + real Needle/Rapier + terrain installed: " + str(_host.microscenario_error)):
		await _finish()
		return
	var native_policy: Dictionary = _host.tower_context.get("liquid_solver_policy",{})
	observed_policy = native_policy.duplicate(true)
	native_workbench_receipt = _host.tower_context.get("liquid_construction_receipt",{}).duplicate(true)
	check(str(native_policy.get("policy_hash","")).length() >= 16,
		"applied Water policy has positive native hash")
	check(not native_workbench_receipt.is_empty(),
		"workbench native construction has positive receipt")
	check(int(_host.shared_workbench.applied.selected) == 1
		and _host.shared_workbench.applied.actors.size() == 1
		and str(_host.shared_workbench.applied.actors[0].model) == "needle",
		"exactly one selected human Needle flyer adopted")
	check(_host.latest_snapshot.native_worker_request == workers,
		"native worker policy request source-matched")
	if not errors.is_empty():
		await _finish()
		return
	_host.shared_workbench._set_view(CAMERA_ORIGIN,CAMERA_VIEW)
	check(_host.current_view_size == CAMERA_VIEW
		and _host.camera_origin == CAMERA_ORIGIN,
		"identical viewport and interest window to each other campaign arm")
	if not check(_host.shared_workbench.toggle_pause(),"actual Workbench unpauses"):
		await _finish()
		return
	if not check(await _wait_for(Callable(self,"_running"),60000),
		"actual native tick and manually stepped Rapier + Needle session run"):
		await _finish()
		return
	var warm_started: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - warm_started < WARMUP_USEC and not _host.simulation_worker.has_failed():
		await process_frame
	if not check(not _host.simulation_worker.has_failed() and not _host.paused
		and _host.physical_actor_session != null,"active World survives equal wall-clock warmup"):
		await _finish()
		return
	actor_initial = _host.physical_actor_session.workbench_actor_state(1).duplicate(true)
	if not check(not actor_initial.is_empty() and actor_initial.has("position"),
		"real Needle actor has owned initial pose"):
		await _finish()
		return
	_panel = _host.shared_workbench.engine_lab
	_panel.open_for(_host)
	_panel.begin_benchmark()
	if not check(_panel.recorder.running and _host.engine_lab_benchmark_active,
		"passive real 10-second Engine Lab capture started"):
		await _finish()
		return
	if not check(await _wait_for(Callable(self,"_benchmark_done"),MEASURE_TIMEOUT_MS),
		"bounded current-World benchmark reaches its terminal wall-clock"):
		_stop("campaign_benchmark_deadline")
		await _finish()
		return
	last_report = _panel.recorder.outcome
	actor_final = _host.physical_actor_session.workbench_actor_state(1).duplicate(true)
	check(last_report.get("status","") == "passed","passive recorder completed without reset, pause or refusal")
	check(not actor_final.is_empty() and actor_final.has("position"),
		"real Needle actor retained an owned terminal pose")
	if not errors.is_empty():
		_stop("campaign_invalid_data")
	await _finish()
