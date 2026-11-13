extends SceneTree

# IN-TOOLS #361 reservoir-lab in the real shared workbench under the pressure
# Water family (default preset "Water: pressure reference"; override with
# LIQUID_EQUIPMENT_PRESET, workers with LIQUID_EQUIPMENT_WORKERS). Exercises:
#   A4  connected tanks: open, close mid-flow, reopen and approach equal levels;
#   B   cascade bins: a low valve equalizes, a high valve spills only above it;
#   A3  sealed tank: drain with the lid vent shut, then open the vent;
#   A2  submerged inlet: the pump pipes the tank's Water into the pool.
# Quantities come from the native ledger and native region census.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Equipment = preload("res://scripts/workbench_liquid_equipment.gd")
const REGIONS_A := {"a_left":[4,100,52,164],"a_right":[60,100,52,164],"c_tank":[304,150,60,90],"d_pool":[380,196,96,68]}
const REGIONS_B := {"b1":[124,110,52,154],"b2":[180,110,52,154],"b3":[236,110,52,154]}
var main: Control
var panel
var checks := 0
var failures := 0
var evidence := {}
var _observation := 0
var _workers_peak := 0
var _frame_ms := []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("RESERVOIR_LAB: " + label)
	return ok

func until(test: Callable, label: String, seconds: float = -1.0) -> bool:
	var limit := Watchdogs.milliseconds("operation_seconds") if seconds < 0 else int(seconds * 1000.0)
	var deadline := Time.get_ticks_msec() + limit
	while not test.call() and Time.get_ticks_msec() < deadline:
		var snapshot = main.latest_snapshot if main != null else null
		if snapshot != null and not snapshot.native_worker_participation.is_empty():
			_workers_peak = maxi(_workers_peak,int(snapshot.native_worker_participation.get("workers_observed",0)))
		await process_frame
	return check(test.call(), label + " / " + main.microscenario_error + " / " + str(receipt().get("last_refusal","")))

func installed() -> bool:
	return not panel.applied.is_empty() and not panel.busy() and main.pending_microscenario_apply.is_empty()

func receipt() -> Dictionary:
	return main.tower_context.get("workbench_equipment",{}) if main != null else {}

func water() -> Dictionary:
	return main.tower_context.get("water_spray",{}).get("water",{})

func current() -> bool:
	return receipt().get("configured",false) and int(receipt().get("serial",-1)) == panel.equipment.serial

func ticks() -> int:
	return int(receipt().get("ticks",0))

func run_ticks(count: int, label: String) -> bool:
	var target := ticks() + count
	return await until(func() -> bool: return ticks() >= target,label + " advanced %d ticks" % count,180.0)

func observe(regions: Dictionary) -> Dictionary:
	_observation += 1
	var serial := _observation
	main.workbench_equipment({"command":"observe","observation":serial,"regions":regions})
	await until(func() -> bool: return int(receipt().get("observation_serial",-1)) == serial,"observation %d" % serial)
	return receipt().get("observations",{})

func census() -> Dictionary:
	var result: Dictionary = await observe(REGIONS_A)
	result.merge(await observe(REGIONS_B))
	return result

func cells(snapshot: Dictionary) -> Dictionary:
	var out := {}
	for key: String in snapshot: out[key] = int(snapshot[key].water_cells)
	return out

func valve(index: int) -> Dictionary:
	return receipt().valves[index]

func set_valve(index: int, open: bool) -> bool:
	panel.equipment.selected_valve = index
	if bool(valve(index).open) != open: check(panel.equipment.toggle("valve"),"valve %d toggled" % (index + 1))
	var want := "open" if open else "closed"
	return await until(func() -> bool: return valve(index).state == want,"valve %d %s" % [index + 1,want],90.0)

func capture(label: String) -> void:
	var directory := OS.get_environment("LIQUID_EQUIPMENT_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null: image.save_png(directory.path_join("reservoir-lab-%s.png" % label))

func ledger_closed(label: String) -> void:
	var w := water()
	check(not w.is_empty() and int(w.total) == int(w.expected),label + " native Water ledger closed " + str(w))

func run() -> void:
	var workers := int(OS.get_environment("LIQUID_EQUIPMENT_WORKERS")) if not OS.get_environment("LIQUID_EQUIPMENT_WORKERS").is_empty() else 4
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	var preset := OS.get_environment("LIQUID_EQUIPMENT_PRESET")
	evidence.requested_workers = workers
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench
	main.simulation_worker.set_worker_participation_sampling(true)
	if not await until(installed,"workbench installed"): return finish()
	check(panel.load_equipment_start(Setup.RESERVOIR_LAB_LABEL,true,preset),"reservoir-lab load requested")
	if not await until(func() -> bool: return installed() and current(),"reservoir-lab installed and configured"): return finish()
	var family := ""
	for assignment: Dictionary in main.tower_context.get("liquid_solver_policy",{}).get("assignments",[]):
		if int(assignment.material) == 3: family = str(assignment.applied_family) + "/" + str(assignment.applied_variant)
	evidence.water_family = family
	if preset.is_empty(): check(family.begins_with("pressure_flow_v1"),"reservoir-lab requests pressure Water (got %s)" % family)
	var r := receipt()
	check(r.valves.size() == 6,"six valves installed")
	for i: int in 6: check(valve(i).state == "closed","valve %d starts closed" % (i + 1))
	var unit := int(r.water_unit)
	await until(func() -> bool: return not water().is_empty(),"native Water ledger published")
	ledger_closed("installed")
	var world_start := int(water().total)
	var start := await census()
	evidence.start = cells(start)
	check(int(start.a_right.water_cells) == 0 and int(start.b3.water_cells) == 0,"right tank and bin 3 start empty")
	panel.toggle_pause()

	# A4: connected tanks. Close mid-flow, then reopen until the levels approach.
	if not await set_valve(0,true): return finish()
	if not await run_ticks(150,"A4 first flow"): return finish()
	if not await set_valve(0,false): return finish()
	var trimmed := int(valve(0).trimmed_water)
	var shut := await observe(REGIONS_A)
	if not await run_ticks(90,"A4 shut"): return finish()
	var held := await observe(REGIONS_A)
	check(int(shut.a_right.water_cells) > 0,"Water crossed the open valve (%d cells)" % int(shut.a_right.water_cells))
	check(int(held.a_right.water) == int(shut.a_right.water) and int(held.a_left.water) == int(shut.a_left.water),
		"a closed valve passes no Water (right %d -> %d)" % [int(shut.a_right.water),int(held.a_right.water)])
	check(int(water().total) == world_start - trimmed,"closing mid-flow changes Water by exactly the booked trim (%d)" % trimmed)
	if not await set_valve(0,true): return finish()
	if not await run_ticks(600,"A4 equalize"): return finish()
	var level := await observe(REGIONS_A)
	var left := int(level.a_left.water_cells)
	var right := int(level.a_right.water_cells)
	check(absi(left - right) * 10 < left + right,"connected tanks approach equal levels (%d vs %d cells)" % [left,right])
	await capture("a4")
	evidence.a4 = {"right_after_150":int(shut.a_right.water_cells),"trimmed_on_close":trimmed,"displaced_on_close":int(valve(0).displaced_cells),
		"left_after_reopen":left,"right_after_reopen":right}
	ledger_closed("A4")

	# B: low valve 2 equalizes bins 1-2; high valve 5 spills into bin 3 only above it.
	if not await set_valve(1,true): return finish()
	if not await run_ticks(400,"B low valve"): return finish()
	var low := await observe(REGIONS_B)
	check(int(low.b2.water_cells) > int(start.b2.water_cells) + 500,"low valve fed bin 2 (%d cells)" % int(low.b2.water_cells))
	check(int(low.b3.water_cells) == 0,"bin 3 stays dry with its valves shut")
	if not await set_valve(4,true): return finish()
	if not await run_ticks(300,"B high valve"): return finish()
	var high := await observe(REGIONS_B)
	check(int(high.b3.water_cells) > 0,"high valve spills into bin 3 once Water stands above it (%d cells)" % int(high.b3.water_cells))
	await capture("cascade")
	evidence.cascade = {"b1":int(high.b1.water_cells),"b2":int(high.b2.water_cells),"b3":int(high.b3.water_cells),
		"b2_after_low":int(low.b2.water_cells)}
	ledger_closed("B")

	# A3: sealed tank. Drain with the vent shut, then with the vent open.
	var loop_total := int(water().total) + int(receipt().pipe.stock)
	check(panel.equipment.toggle("drain"),"tank drain opened")
	if not await run_ticks(240,"A3 vent shut"): return finish()
	var drained_shut := int(receipt().drain.drained_water)
	var sealed := await observe(REGIONS_A)
	if not await set_valve(5,true): return finish()
	if not await run_ticks(240,"A3 vent open"): return finish()
	var drained_open := int(receipt().drain.drained_water) - drained_shut
	var vented := await observe(REGIONS_A)
	check(drained_shut + drained_open > 0,"the tank drain removed Water")
	check(int(water().total) + int(receipt().pipe.stock) == loop_total,"drain and pipe conserve the loop")
	await capture("sealed")
	evidence.sealed_tank = {"drained_cells_vent_shut":float(drained_shut)/unit,"drained_cells_vent_open":float(drained_open)/unit,
		"tank_cells_after_shut":int(sealed.c_tank.water_cells),"tank_cells_after_open":int(vented.c_tank.water_cells),
		"tank_overfill_after_shut":int(sealed.c_tank.overfill)}
	ledger_closed("A3")

	# A2: submerged inlet. The pump pipes the tank's Water into the pool.
	var idle0 := await observe(REGIONS_A)
	if not await run_ticks(60,"A2 idle control"): return finish()
	var idle1 := await observe(REGIONS_A)
	evidence.pool_idle_drift = int(idle1.d_pool.water) - int(idle0.d_pool.water)
	evidence.pool_idle_overfill = [int(idle0.d_pool.overfill),int(idle1.d_pool.overfill)]
	var pool_before := int(idle1.d_pool.water)
	var quad0 := await observe({"q00":[0,0,256,256],"q10":[256,0,256,256],"q01":[0,256,256,256],"q11":[256,256,256,256]})
	var injected_before := int(receipt().nozzle.injected_water)
	check(panel.equipment.toggle("nozzle"),"submerged nozzle on")
	if not await run_ticks(120,"A2 inlet"): return finish()
	await capture("inlet-mid")
	if not await run_ticks(120,"A2 inlet"): return finish()
	check(panel.equipment.toggle("drain"),"drain shut")
	check(panel.equipment.toggle("nozzle"),"nozzle off")
	await until(func() -> bool: return not receipt().nozzle.on and not receipt().drain.open,"devices off")
	r = receipt()
	await capture("inlet")
	var injected := int(r.nozzle.injected_water) - injected_before
	var pool := await observe(REGIONS_A)
	var around := await observe({"gap":[300,244,80,20],"above":[380,40,96,156],"c_tank":[304,150,60,90],"right_of_a":[116,100,4,164]})
	evidence.around_pool = cells(around)
	var quad1 := await observe({"q00":[0,0,256,256],"q10":[256,0,256,256],"q01":[0,256,256,256],"q11":[256,256,256,256]})
	var quad_delta := {}
	for key: String in quad1: quad_delta[key] = int(quad1[key].water) - int(quad0[key].water)
	evidence.quadrant_delta = quad_delta
	evidence.inlet_receipt = receipt().nozzle.duplicate()
	evidence.spray_in_flight = int(water().get("ballistic",0))
	check(injected > 0 and int(r.nozzle.column_injections) + int(r.nozzle.topped_up) > 0,"the submerged nozzle injected under Water")
	check(int(pool.d_pool.water) - pool_before == injected,"the pool gained exactly the injected Water (%d vs %d)" % [int(pool.d_pool.water) - pool_before,injected])
	check(int(water().total) + int(r.pipe.stock) == loop_total,"loop conserved through the submerged inlet")
	evidence.inlet = {"injected_cells":float(injected)/unit,"column_injections":int(r.nozzle.column_injections),
		"topped_up":int(r.nozzle.topped_up),"pool_cells":int(pool.d_pool.water_cells)}
	ledger_closed("A2")
	check(Equipment.underwater_spread(1.0) == 6 and Equipment.underwater_spread(2.0) == 3 and Equipment.underwater_spread(3.0) == 0,
		"underwater spread follows nozzle speed (slow spreads, fast stacks a fountain)")
	# Fast inlet: a fountain column rises above the pool surface.
	panel.equipment._speed.set_value_no_signal(4.0)
	check(panel.equipment.tune(),"inlet speed raised to 4")
	await until(func() -> bool: return is_equal_approx(float(receipt().nozzle.speed),4.0),"fast inlet applied")
	var above0 := int((await observe({"above":[380,40,96,156]})).above.water_cells)
	check(panel.equipment.toggle("drain"),"drain reopened")
	check(panel.equipment.toggle("nozzle"),"fast inlet on")
	if not await run_ticks(90,"fountain"): return finish()
	await capture("fountain")
	var above1 := int((await observe({"above":[380,40,96,156]})).above.water_cells)
	check(above1 > above0 + 5,"a fast inlet raises a fountain column above the pool (%d -> %d cells)" % [above0,above1])
	evidence.fountain = {"cells_above_surface_box":above1 - above0}
	panel.equipment.stop_all()
	if not main.paused: panel.toggle_pause()
	finish()

func finish() -> void:
	evidence.workers_observed_peak = _workers_peak
	evidence.runtime = {"os":OS.get_name(),"godot":Engine.get_version_info().string,
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"))}
	print("RESERVOIR_LAB_EVIDENCE " + JSON.stringify(evidence))
	print("RESERVOIR_LAB %d checks, %d failures" % [checks, failures])
	if main != null and not main.paused and panel != null and not panel.applied.is_empty(): panel.toggle_pause()
	quit(failures)
