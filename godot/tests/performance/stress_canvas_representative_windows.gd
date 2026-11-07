extends SceneTree

# Representative current-main stress characterization.
# Full arm: built-in 2048x1024 stress-canvas, Water FreeMass (PF off).
# PF arm: clipped 1024x512 stress-canvas with PF cached_dormant + gas on.
# Both retain ballistic Water, face release, impact spray and real Rapier barrels.

const Setup = preload("res://scripts/workbench_setup.gd")
const WATER := 3
const WALL := 58
const SAMPLE_SECONDS := 10.0
const WARMUP_TICKS := 30
const WATCHDOG_MSEC := 180000

var host: Control
var ui: Control
var failures: Array[String] = []
var assertions := 0
var out_dir := ""

class ObservedMain:
	extends "res://scripts/main.gd"
	var measurement_active := false
	var physics_rows: Array[Dictionary] = []
	var no_step_callbacks := 0

	func _physics_process(delta: float) -> void:
		var before_count := rapier_bridge.manual_step_count()
		var started := Time.get_ticks_usec()
		super(delta)
		if not measurement_active:
			return
		var ended := Time.get_ticks_usec()
		var after_count := rapier_bridge.manual_step_count()
		if after_count - before_count == 1:
			physics_rows.append({
				"physics_frame": Engine.get_physics_frames(),
				"callback_usec": ended - started,
				"space_step_ms": rapier_bridge.last_step_time_ms(),
				"flush_ms": rapier_bridge.last_flush_time_ms(),
				"active_bodies": rapier_bridge.last_active_body_count(),
				"bridge_step_count": after_count,
				"actor_tick": physical_actor_session.tick if physical_actor_session != null else -1,
				"native_tick": latest_snapshot.tick_index if latest_snapshot != null else -1,
			})
		else:
			no_step_callbacks += 1

func expect(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok:
		failures.append(message)
		push_error("STRESS_REP: " + message)
	return ok

func wait_for(test: Callable, label: String, timeout_msec := WATCHDOG_MSEC) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if test.call():
			return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed():
			break
		await process_frame
	return expect(false, label + " / " + (host.microscenario_error if host != null else "no host"))

func quantiles(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"n":0}
	values.sort()
	var n := values.size()
	return {
		"n":n,
		"p50":values[int(round((n - 1) * 0.50))],
		"p95":values[int(round((n - 1) * 0.95))],
		"p99":values[int(round((n - 1) * 0.99))],
		"max":values[n - 1],
	}

func write_json(name: String, value: Variant) -> void:
	if out_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(value, "\t"))
		f.close()

func water_policy(family: String, variant: String, gas_enabled: bool) -> PackedInt32Array:
	var bridge: Variant = ui._liquids.bridge
	var request: PackedInt32Array = bridge.default_liquid_policy()
	var found := false
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(request, WATER):
		if str(choice.get("family","")) == family and str(choice.get("variant","")) == variant and bool(choice.get("accepted",false)):
			request = PackedInt32Array(choice.request)
			found = true
			break
	if not expect(found, "Water policy available: " + family + "/" + variant):
		return PackedInt32Array()
	if family == "pressure_flow_v1":
		var gas: Dictionary = bridge.liquid_policy_with_pressure_gas(request, gas_enabled)
		if not expect(bool(gas.get("accepted",false)), "PressureFlow gas edit accepted"):
			return PackedInt32Array()
		request = PackedInt32Array(gas.request)
	return request

func reduced_stress(policy: PackedInt32Array) -> Dictionary:
	var src: Dictionary = Setup.stress_canvas(policy)
	var data: Dictionary = src.duplicate(true)
	data.extent = [1024,512]
	var edits: Array = []
	for raw: Variant in src.edits:
		var stamp: Array = raw
		if stamp.size() != 5:
			continue
		var x0 := maxi(0, int(stamp[0]))
		var y0 := maxi(0, int(stamp[1]))
		var x1 := mini(1024, int(stamp[0]) + int(stamp[2]))
		var y1 := mini(512, int(stamp[1]) + int(stamp[3]))
		if x0 < x1 and y0 < y1:
			edits.append([x0,y0,x1-x0,y1-y0,int(stamp[4])])
	# Preserve the first four authored stress zones, then add one explicit tall
	# Water face so PF + ballistic face release is guaranteed to stay active.
	edits.append([840,72,156,424,WATER])
	edits.append([0,500,1024,12,WALL])
	edits.append([1016,16,8,484,WALL])
	data.edits = edits
	data.actors = [
		Setup.instance(Setup.BARREL,1,Vector2(150,120)),
		Setup.instance(Setup.BARREL,2,Vector2(380,140)),
		Setup.instance(Setup.BARREL,3,Vector2(640,120)),
		Setup.instance(Setup.BARREL,4,Vector2(900,80)),
	]
	data.next_id = 5
	data.selected = 0
	data.material = WATER
	return data

func policy_readback() -> Dictionary:
	for row: Dictionary in host.tower_context.get("liquid_solver_policy",{}).get("assignments",[]):
		if int(row.get("material",-1)) == WATER:
			return row.duplicate(true)
	return {}

func actor_states() -> Array:
	var result: Array = []
	if host.physical_actor_session == null:
		return result
	var count: int = host.physical_actor_session.bodies().size()
	for id: int in range(1,count + 1):
		var state: Dictionary = host.physical_actor_session.workbench_actor_state(id)
		if not state.is_empty():
			result.append({
				"id":id,
				"position":[float(state.position.x),float(state.position.y)],
				"linear_velocity":[float(state.linear_velocity.x),float(state.linear_velocity.y)],
				"rotation":float(state.get("rotation",0.0)),
			})
	return result

func actor_displacements(start: Array, finish: Array) -> Array:
	var by_id := {}
	for row: Dictionary in start:
		by_id[int(row.id)] = Vector2(float(row.position[0]),float(row.position[1]))
	var out: Array = []
	for row: Dictionary in finish:
		var id := int(row.id)
		var p := Vector2(float(row.position[0]),float(row.position[1]))
		var q: Vector2 = by_id.get(id,p)
		out.append({"id":id,"dx":p.x-q.x,"dy":p.y-q.y,"distance":p.distance_to(q)})
	return out

func install_workload(kind: String) -> bool:
	var policy: PackedInt32Array
	var recipe: Dictionary
	if kind == "full-pf-off":
		policy = water_policy("freemass_v1","reference",false)
		recipe = Setup.stress_canvas(policy)
	else:
		policy = water_policy("pressure_flow_v1","cached_dormant",true)
		recipe = reduced_stress(policy)
	if policy.is_empty():
		return false
	expect(Setup.validate(recipe).is_empty(), "representative recipe validates")
	host.workbench_water_options = {
		"workbench_ballistic":true,
		"workbench_face_release":true,
		"workbench_face_budget":320,
		"workbench_face_speed":288,
		"workbench_face_period":1,
		"workbench_face_min_height":4,
	}
	var epoch: int = host._physical_epoch
	if not expect(ui.apply(recipe), "representative workbench apply requested"):
		return false
	var adopted := await wait_for(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch > epoch \
			and host.physical_actor_session != null and host._physical_terrain_ready,
		"representative workbench adopted")
	if not adopted:
		return false
	var rb := policy_readback()
	expect(not rb.is_empty(), "Water policy readback exists")
	if kind == "full-pf-off":
		expect(str(rb.get("applied_family","")) == "freemass_v1", "full stress has PressureFlow off")
	else:
		expect(str(rb.get("applied_family","")) == "pressure_flow_v1" and str(rb.get("applied_variant","")) == "cached_dormant",
			"reduced stress has PF cached_dormant")
	# Runtime impact spray is separate from ballistic/face-release construction.
	expect(ui.water_spray.request({
		"enabled":true,
		"launch_scale":1.6,
		"threshold":0.3,
		"upward_bias":0.72,
		"budget":64,
		"reaction_gain":0.0,
		"jet_enabled":false,
	}), "impact spray request queued")
	if host.paused:
		expect(ui.toggle_pause(), "workbench unpaused")
	await wait_for(func() -> bool:
		return bool(host.tower_context.get("water_spray",{}).get("settings",{}).get("enabled",false)),
		"impact spray applied")
	return failures.is_empty()

func run() -> void:
	out_dir = OS.get_environment("CYBERSAND_STRESS_OUTPUT")
	var kind := OS.get_environment("CYBERSAND_STRESS_KIND")
	var requested_fps := int(OS.get_environment("CYBERSAND_STRESS_MAX_FPS"))
	var requested_hz := int(OS.get_environment("CYBERSAND_STRESS_PHYSICS_HZ"))
	if kind.is_empty(): kind = "full-pf-off"
	if requested_hz <= 0: requested_hz = 60
	var old_fps := Engine.max_fps
	var old_hz := Engine.physics_ticks_per_second
	var old_project_hz: Variant = ProjectSettings.get_setting("physics/common/physics_ticks_per_second",old_hz)
	Engine.max_fps = requested_fps
	Engine.physics_ticks_per_second = requested_hz
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second",requested_hz)

	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(ObservedMain)
	root.add_child(host)
	var opened := await wait_for(func() -> bool:
		return host.shared_workbench != null and not host.shared_workbench.applied.is_empty(),
		"shared workbench opened")
	if opened:
		ui = host.shared_workbench
		opened = await install_workload(kind)
	if opened:
		var warm_start := int(host.latest_snapshot.tick_index)
		await wait_for(func() -> bool: return int(host.latest_snapshot.tick_index) >= warm_start + WARMUP_TICKS,
			"representative warmup")
	if opened and failures.is_empty():
		var start_tick := int(host.latest_snapshot.tick_index)
		var start_rapier: int = host.rapier_bridge.manual_step_count()
		var start_actor_tick: int = host.physical_actor_session.tick
		var start_actors := actor_states()
		var start_spray: Dictionary = host.tower_context.get("water_spray",{}).duplicate(true)
		var start_usec := Time.get_ticks_usec()
		host.physics_rows.clear()
		host.no_step_callbacks = 0
		host.measurement_active = true
		write_json("measurement-start.json",{
			"ticks_usec":start_usec,"unix_usec":roundi(Time.get_unix_time_from_system()*1000000.0),
			"native_tick":start_tick,"rapier_step":start_rapier,"actor_tick":start_actor_tick,
		})
		var native_samples: Array[float] = []
		var worker_samples: Array[float] = []
		var last_seen_tick := start_tick
		var deadline := start_usec + int(SAMPLE_SECONDS * 1000000.0)
		while Time.get_ticks_usec() < deadline and not host.simulation_worker.has_failed():
			await process_frame
			var snap: CyberSimulationSnapshot = host.latest_snapshot
			if snap != null and int(snap.tick_index) != last_seen_tick:
				last_seen_tick = int(snap.tick_index)
				native_samples.append(float(snap.simulation_time_ms))
				worker_samples.append(float(snap.worker_step_time_ms))
		host.measurement_active = false
		var end_usec := Time.get_ticks_usec()
		var end_tick := int(host.latest_snapshot.tick_index)
		var end_rapier: int = host.rapier_bridge.manual_step_count()
		var end_actor_tick: int = host.physical_actor_session.tick
		var end_actors := actor_states()
		var spray: Dictionary = host.tower_context.get("water_spray",{}).duplicate(true)
		write_json("measurement-end.json",{
			"ticks_usec":end_usec,"unix_usec":roundi(Time.get_unix_time_from_system()*1000000.0),
			"native_tick":end_tick,"rapier_step":end_rapier,"actor_tick":end_actor_tick,
		})
		var elapsed := float(end_usec-start_usec)/1000000.0
		var steps: Array[float] = []
		var callbacks: Array[float] = []
		for row: Dictionary in host.physics_rows:
			steps.append(float(row.space_step_ms))
			callbacks.append(float(row.callback_usec)/1000.0)
		var ledger: Dictionary = spray.get("ledger",{})
		var result := {
			"schema":"stress-representative-v1",
			"kind":kind,
			"requested_max_fps":requested_fps,
			"requested_physics_hz":requested_hz,
			"elapsed_seconds":elapsed,
			"native_tick_delta":end_tick-start_tick,
			"native_ticks_per_second":float(end_tick-start_tick)/elapsed,
			"rapier_step_delta":end_rapier-start_rapier,
			"rapier_steps_per_second":float(end_rapier-start_rapier)/elapsed,
			"actor_tick_delta":end_actor_tick-start_actor_tick,
			"actor_ticks_per_second":float(end_actor_tick-start_actor_tick)/elapsed,
			"physics_step_rows":host.physics_rows.size(),
			"no_step_callbacks":host.no_step_callbacks,
			"space_step_ms":quantiles(steps),
			"physics_callback_ms":quantiles(callbacks),
			"space_step_over_40ms":steps.filter(func(v: float) -> bool: return v > 40.0).size(),
			"native_tick_ms":quantiles(native_samples),
			"worker_step_ms":quantiles(worker_samples),
			"policy":policy_readback(),
			"body_count":host.physical_actor_session.bodies().size(),
			"actor_start":start_actors,
			"actor_end":end_actors,
			"actor_displacements":actor_displacements(start_actors,end_actors),
			"water_spray":{
				"ballistic_enabled":spray.get("ballistic_enabled",false),
				"settings":spray.get("settings",{}),
				"live":spray.get("live",0),
				"in_flight_quantity":spray.get("in_flight_quantity",0),
				"launched_parcels":ledger.get("launched_parcels",0),
				"injected_parcels":ledger.get("injected_parcels",0),
				"deposited_parcels":ledger.get("deposited_parcels",0),
				"surface_entries":ledger.get("surface_entries",0),
				"body_contacts":ledger.get("body_contacts",0),
				"refused_launches":ledger.get("refused_launches",0),
				"start_ledger":start_spray.get("ledger",{}),
			},
			"worker_failed":host.simulation_worker.has_failed(),
			"worker_error":str(host.simulation_worker.failure_message()) if host.simulation_worker.has_method("failure_message") else "",
			"assertions":assertions,
			"failures":failures,
		}
		write_json("fixture-result.json",result)
		print("STRESS_REP_RESULT ",JSON.stringify(result))

	Engine.max_fps = old_fps
	Engine.physics_ticks_per_second = old_hz
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second",old_project_hz)
	if host != null:
		host.queue_free()
		await process_frame
	quit(0 if failures.is_empty() else 1)
