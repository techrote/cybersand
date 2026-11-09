extends SceneTree

# IN-TOOLS #361: the integrated liquid-lab apparatus in the real shared
# workbench (native World worker + Rapier body). Exercises the actual device
# path the human uses: load the built-in start, open/close the valve, drain,
# fire the pumped nozzle, refusals, Stop, Restore start and New blank. Water
# quantities come from the native ledger (`water_spray.water`) and native
# region census, never from GDScript estimates.
#
# LIQUID_EQUIPMENT_WORKERS=1|4 selects the native pool request (default 4).
# LIQUID_EQUIPMENT_BALLISTIC=0 runs the nozzle in resting-cell mode.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Equipment = preload("res://scripts/workbench_liquid_equipment.gd")
const TANK := [16,130,120,90]
const BASIN := [4,226,256,38]
const GATE := [56,220,8,4]
const DRY := [334,120,142,144]
const AIM: float = Setup.LIQUID_LAB_NOZZLE[2]
var main: Control
var panel
var checks := 0
var failures := 0
var evidence := {}
var _observation := 0
var _workers_peak := 0
var _tick_ms := []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("LIQUID_EQUIPMENT: " + label)
	return ok

func until(test: Callable, label: String, seconds: float = -1.0) -> bool:
	var limit := Watchdogs.milliseconds("operation_seconds") if seconds < 0 else int(seconds * 1000.0)
	var deadline := Time.get_ticks_msec() + limit
	while not test.call() and Time.get_ticks_msec() < deadline:
		_sample()
		await process_frame
	return check(test.call(), label + " / " + main.microscenario_error + " / " + str(receipt().get("last_refusal","")))

func _sample() -> void:
	var snapshot = main.latest_snapshot
	if snapshot == null: return
	var sample: Dictionary = snapshot.native_worker_participation
	if not sample.is_empty():
		_workers_peak = maxi(_workers_peak,int(sample.get("workers_observed",0)))
		if sample.has("native_tick_ms") and _tick_ms.size() < 4096: _tick_ms.append(float(sample.native_tick_ms))

func installed() -> bool:
	return not panel.applied.is_empty() and not panel.busy() and main.pending_microscenario_apply.is_empty()

func receipt() -> Dictionary:
	return main.tower_context.get("workbench_equipment",{})

func water() -> Dictionary:
	return main.tower_context.get("water_spray",{}).get("water",{})

func spray() -> Dictionary:
	return main.tower_context.get("water_spray",{})

func current() -> bool:
	return receipt().get("configured",false) and int(receipt().get("serial",-1)) == panel.equipment.serial

func ticks() -> int:
	return int(receipt().get("ticks",0))

func run_ticks(count: int, label: String) -> bool:
	var target := ticks() + count
	return await until(func() -> bool: return ticks() >= target,label + " advanced %d ticks" % count,120.0)

func observe() -> Dictionary:
	_observation += 1
	var serial := _observation
	main.workbench_equipment({"command":"observe","observation":serial,
		"regions":{"tank":TANK,"basin":BASIN,"gate":GATE,"dry":DRY}})
	await until(func() -> bool: return int(receipt().get("observation_serial",-1)) == serial,"observation %d" % serial)
	return receipt().get("observations",{})

# Windowed runs only: LIQUID_EQUIPMENT_CAPTURE_DIR saves the real workbench
# frame (native World + Rapier presentation) at each phase.
func capture(label: String) -> void:
	var directory := OS.get_environment("LIQUID_EQUIPMENT_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null: image.save_png(directory.path_join("liquid-lab-%s.png" % label))

func ledger_closed(label: String) -> bool:
	var w := water()
	return check(not w.is_empty() and int(w.total) == int(w.expected),label + " native Water ledger closed " + str(w))

func run() -> void:
	var workers := int(OS.get_environment("LIQUID_EQUIPMENT_WORKERS")) if not OS.get_environment("LIQUID_EQUIPMENT_WORKERS").is_empty() else 4
	var ballistic := OS.get_environment("LIQUID_EQUIPMENT_BALLISTIC") != "0"
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	evidence.requested_workers = workers
	evidence.ballistic_requested = ballistic
	_static_checks()
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench
	main.simulation_worker.set_worker_participation_sampling(true)
	if not await until(installed,"workbench installed"): return finish()

	# Install the built-in apparatus through the ordinary workbench action.
	check(panel.load_liquid_lab(ballistic),"liquid-lab load requested")
	if not await until(func() -> bool: return installed() and current(),"liquid-lab installed and configured"): return finish()
	var r := receipt()
	var policy: Dictionary = main.tower_context.get("liquid_solver_policy",{})
	var family := ""
	for assignment: Dictionary in policy.get("assignments",[]):
		if int(assignment.material) == 3: family = str(assignment.applied_family)
	evidence.water_family = family
	evidence.rule_radius = int(policy.get("maximum_rule_radius",0))
	check(family == "inertial_cellular_v1","liquid-lab applies opt-in inertial Water (got %s)" % family)
	check(bool(r.whole_cell_water),"device owner sees whole-cell Water")
	check(bool(spray().get("ballistic_enabled",false)) == ballistic,"ballistic Water construction matches the request")
	check(r.valve.state == "closed" and not r.drain.open and not r.nozzle.on,"every device starts closed")
	var unit := int(r.water_unit)
	evidence.water_unit = unit
	check(unit > 0 and int(r.pipe.stock) == 150 * unit,"pipe starts with the authored 150-cell supply")
	await until(func() -> bool: return not water().is_empty(),"native Water ledger published")
	ledger_closed("installed")
	var start_total := int(water().total)
	var loop_total := start_total + int(r.pipe.stock)
	var first := await observe()
	check(int(first.gate.water_cells) == 0 and int(first.tank.water_cells) == 120 * 90,"sealed reservoir holds 10800 Water cells")
	await capture("start")
	evidence.start = {"world_water":start_total,"tank_cells":int(first.tank.water_cells)}

	# Refusals: a command for an older configuration and an out-of-range tune.
	var refused_before := int(receipt().refused)
	main.workbench_equipment({"command":"valve","serial":panel.equipment.serial-1,"open":true})
	main.workbench_equipment({"command":"tune","serial":panel.equipment.serial,"angle":720.0,"speed":4.0,"rate":2})
	main.workbench_equipment({"command":"configure","serial":1,"config":{"version":1}})
	await until(func() -> bool: return int(receipt().refused) >= refused_before + 3,"stale/invalid commands refused")
	check(not receipt().valve.open and is_equal_approx(float(receipt().nozzle.angle),AIM),"refused commands changed nothing")
	check(not main.simulation_worker.queue_workbench_equipment({"command":"explode"}),"unknown command refused at the queue")

	panel.toggle_pause()
	# A. Leak: open the side valve and let the inertial solver run out.
	check(panel.equipment.toggle("valve"),"valve opened by the workbench control")
	if not await run_ticks(240,"leak"): return finish()
	var leaking := await observe()
	r = receipt()
	check(int(r.valve.opened_cells) == 32,"all 32 gate cells opened (%d)" % int(r.valve.opened_cells))
	check(int(leaking.tank.water_cells) < 120 * 90 - 400,"reservoir lost Water through the opening (%d)" % int(leaking.tank.water_cells))
	check(int(leaking.basin.water_cells) > 400,"Water ran out laterally into the basin (%d)" % int(leaking.basin.water_cells))
	check(int(water().total) == start_total,"leak is a pure transfer: native Water unchanged")
	ledger_closed("leak")
	await capture("leak")
	evidence.leak = {"tank_cells":int(leaking.tank.water_cells),"basin_cells":int(leaking.basin.water_cells),
		"gate_cells":int(leaking.gate.water_cells)}

	# Close: the gate refills, pushing caught whole cells aside exactly.
	check(panel.equipment.toggle("valve"),"valve closing")
	await until(func() -> bool: return receipt().valve.state == "closed","valve fully closed",60.0)
	r = receipt()
	check(int(r.valve.closed_cells) == 32,"all 32 gate cells refilled before closed is reported (%d)" % int(r.valve.closed_cells))
	check(int(r.valve.trimmed_water) == 0,"whole-cell Water is moved, never trimmed")
	check(int(water().total) == start_total,"closing preserves native Water exactly")
	var closed := await observe()
	check(int(closed.gate.water_cells) == 0,"no Water left inside the closed gate")
	if not await run_ticks(90,"after closure"): return finish()
	var settled := await observe()
	check(int(settled.tank.water_cells) == int(closed.tank.water_cells),"no flow through a closed valve")
	await capture("closed")
	evidence.close = {"displaced_cells":int(r.valve.displaced_cells),"closed_cells":int(r.valve.closed_cells),
		"basin_cells_at_close":int(closed.basin.water_cells),"basin_cells_later":int(settled.basin.water_cells)}

	# B. Drain: the bottom drain pipes basin Water to the nozzle.
	check(panel.equipment.toggle("drain"),"drain opened")
	if not await run_ticks(200,"drain"): return finish()
	r = receipt()
	var drained := int(r.drain.drained_water)
	check(drained > 0 and drained % unit == 0,"drain removed whole Water cells (%d units)" % drained)
	check(int(r.pipe.stock) == 150 * unit + drained,"pump pipe holds exactly the drained Water")
	check(int(water().total) == start_total - drained,"native Water fell by exactly the drained quantity")
	check(int(water().total) + int(r.pipe.stock) == loop_total,"loop quantity conserved during drainage")
	ledger_closed("drain")
	await capture("drain")
	evidence.drain = {"drained_cells":drained / unit,"masked_skips":int(r.drain.masked_skips)}

	# C. Nozzle: pumped Water fired back over the ledge and barrel.
	var barrel_before: Dictionary = panel.body_state(1)
	var spray_before: Dictionary = spray().get("ledger",{})
	check(panel.equipment.toggle("nozzle"),"nozzle on")
	if not await run_ticks(240,"nozzle"): return finish()
	r = receipt()
	var injected := int(r.nozzle.injected_water)
	check(injected > 0 and int(r.nozzle.emitted) > 0,"nozzle injected Water (%d emissions)" % int(r.nozzle.emitted))
	var w := water()
	check(int(w.total) + int(r.pipe.stock) == loop_total,"loop quantity conserved with Water in flight (%s, pipe %d)" % [str(w),int(r.pipe.stock)])
	ledger_closed("nozzle")
	if ballistic:
		var spray_after: Dictionary = spray().get("ledger",{})
		check(int(spray_after.injected_parcels) - int(spray_before.get("injected_parcels",0)) == int(r.nozzle.emitted),
			"every nozzle emission is a native ballistic parcel")
		evidence.ballistic = {"in_flight":int(w.get("ballistic",0)),"body_contacts":int(spray_after.body_contacts)-int(spray_before.get("body_contacts",0)),
			"terrain_contacts":int(spray_after.terrain_contacts)-int(spray_before.get("terrain_contacts",0)),
			"deposited":int(spray_after.deposited_parcels)-int(spray_before.get("deposited_parcels",0))}
		check(int(evidence.ballistic.body_contacts) > 0,"the default aim strikes the barrel (Rapier body contacts)")
	var barrel_after: Dictionary = panel.body_state(1)
	if not barrel_before.is_empty() and not barrel_after.is_empty():
		evidence.barrel = {"before":str(barrel_before.position),"after":str(barrel_after.position),
			"moved":Vector2(barrel_after.position).distance_to(Vector2(barrel_before.position))}
	var spraying := await observe()
	await capture("nozzle")
	evidence.nozzle = {"emitted":int(r.nozzle.emitted),"injected_cells":injected / unit,"dry_zone_cells":int(spraying.dry.water_cells),
		"mode":str(r.nozzle_mode),"pipe_cells":int(r.pipe.stock) / unit}

	# Live aim tuning keeps the devices running and is kept as authored data.
	check(panel.equipment.nudge_aim(10.0),"aim nudged")
	await until(func() -> bool: return is_equal_approx(float(receipt().nozzle.angle),AIM+10.0),"aim applied live")
	check(receipt().nozzle.on and is_equal_approx(float(panel.applied.equipment.nozzle[2]),AIM+10.0),"tuning keeps the nozzle on and is authored")

	# Stop closes everything; residual Water keeps moving under the solver.
	check(panel.equipment.stop_all(),"stop all")
	await until(func() -> bool: return not receipt().drain.open and not receipt().nozzle.on and receipt().valve.state == "closed","all devices stopped")
	var stock_after_stop := int(receipt().pipe.stock)
	if not await run_ticks(30,"after stop"): return finish()
	check(int(receipt().pipe.stock) == stock_after_stop,"stopped devices move no Water")
	if not main.paused: panel.toggle_pause()

	# Restore start rebuilds the World; equipment is reconstructed closed.
	var old_serial: int = panel.equipment.serial
	check(panel.restore_start(),"restore start")
	if not await until(func() -> bool: return installed() and current() and panel.equipment.serial > old_serial,"restored and reconfigured"): return finish()
	r = receipt()
	check(r.valve.state == "closed" and int(r.drain.drained_water) == 0 and int(r.pipe.stock) == 150 * unit,"restore resets transient device state")
	await until(func() -> bool: return not water().is_empty() and int(water().total) == start_total,"restored World has the authored Water")
	var restored := await observe()
	check(int(restored.tank.water_cells) == 120 * 90,"restored reservoir is full and sealed")
	check(is_equal_approx(float(r.config.nozzle[2]),AIM+10.0),"restore keeps the authored aim")

	# Save/Load round trip of the authored equipment block.
	panel._name.text = "test-liquid-lab-361"
	check(panel.save_setup(),"save named start")
	var loaded := Setup.read_named("test-liquid-lab-361")
	check(loaded.has("setup") and loaded.setup.get("equipment",{}) == panel.applied.equipment,"saved equipment reads back identically")
	DirAccess.remove_absolute(Setup._path("test-liquid-lab-361"))

	# New blank removes the equipment entirely.
	check(panel.new_canvas(),"new blank")
	if not await until(func() -> bool: return installed() and not panel.applied.has("equipment"),"blank canvas installed"): return finish()
	await until(func() -> bool: return not receipt().get("configured",true),"worker owner deconfigured on World replacement")
	check(not panel.equipment.toggle("valve"),"device controls refuse without equipment")
	finish()

func _static_checks() -> void:
	var lab := Setup.liquid_lab(PackedInt32Array([0]))
	check(Setup.validate(lab).is_empty(),"liquid-lab start validates: " + Setup.validate(lab))
	check(not Setup.fresh(PackedInt32Array([0])).has("equipment"),"ordinary starts keep Setup-v2 keys")
	var extent := Vector2i(512,512)
	var cases := {
		"unknown key": {"version":1,"valve":[],"drain":[],"nozzle":[],"supply":0,"pump":false,"x":1},
		"oversized valve": {"version":1,"valve":[10,10,10,10],"drain":[],"nozzle":[],"supply":0,"pump":false},
		"zero drain rate": {"version":1,"valve":[],"drain":[10,10,4,4,0],"nozzle":[],"supply":0,"pump":false},
		"nozzle at edge": {"version":1,"valve":[],"drain":[],"nozzle":[0,5,0.0,2.0,1],"supply":0,"pump":false},
		"pump without nozzle": {"version":1,"valve":[],"drain":[10,10,4,4,4],"nozzle":[],"supply":0,"pump":true},
		"fractional geometry": {"version":1,"valve":[10.5,10,4,4],"drain":[],"nozzle":[],"supply":0,"pump":false},
		"future version": {"version":2,"valve":[],"drain":[],"nozzle":[],"supply":0,"pump":false},
	}
	for label: String in cases:
		check(not Equipment.validate(cases[label],extent).is_empty(),"refuses " + label)
		var bad := lab.duplicate(true)
		bad.equipment = cases[label]
		check(not Setup.validate(bad).is_empty(),"Setup refuses " + label)

func finish() -> void:
	if not _tick_ms.is_empty():
		var total := 0.0
		for value: float in _tick_ms: total += value
		var sorted := _tick_ms.duplicate()
		sorted.sort()
		evidence.native_tick_ms = {"samples":_tick_ms.size(),"mean":total/_tick_ms.size(),"p95":sorted[int(sorted.size()*0.95)]}
	evidence.workers_observed_peak = _workers_peak
	evidence.runtime = {"os":OS.get_name(),"godot":Engine.get_version_info().string,
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"))}
	print("LIQUID_EQUIPMENT_EVIDENCE " + JSON.stringify(evidence))
	print("LIQUID_EQUIPMENT %d checks, %d failures" % [checks, failures])
	if main != null and not main.paused and panel != null and not panel.applied.is_empty(): panel.toggle_pause()
	quit(failures)
