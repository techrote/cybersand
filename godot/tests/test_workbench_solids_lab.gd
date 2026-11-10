extends SceneTree

# BS-001 solids-lab in the real shared workbench: a Sand hopper (valve), the
# collector pit, a conveyor feeding the launcher, flying solids striking a
# stack of Rapier barrels and a Water pool. Requires a native runtime built from
# this source (flying solids). Quantities: the native Sand population, the live
# flying-solid roster and the conveyor stock must always sum to the same total.
# LIQUID_EQUIPMENT_WORKERS=1|4 selects the native pool request (default 4).
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var main: Control
var panel
var checks := 0
var failures := 0
var evidence := {}
var _workers_peak := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("SOLIDS_LAB: " + label)
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

func solids() -> Dictionary:
	return main.tower_context.get("ballistic_solids",{})

func current() -> bool:
	return receipt().get("configured",false) and int(receipt().get("serial",-1)) == panel.equipment.serial

func ticks() -> int:
	return int(receipt().get("ticks",0))

func run_ticks(count: int, label: String) -> bool:
	var target := ticks() + count
	return await until(func() -> bool: return ticks() >= target,label + " advanced %d ticks" % count,180.0)

# Grid Sand + flying solids + conveyor stock. Every flying solid in this lab is Sand.
func sand_total() -> int:
	var r := receipt()
	return int(r.solid_stock.population) + int(solids().get("live",0)) + int(r.solid_stock.stock)

func capture(label: String) -> void:
	var directory := OS.get_environment("LIQUID_EQUIPMENT_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null: image.save_png(directory.path_join("solids-lab-%s.png" % label))

func run() -> void:
	var workers := int(OS.get_environment("LIQUID_EQUIPMENT_WORKERS")) if not OS.get_environment("LIQUID_EQUIPMENT_WORKERS").is_empty() else 4
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	evidence.requested_workers = workers
	var lab := Setup.solids_lab(PackedInt32Array([0]))
	check(Setup.validate(lab).is_empty(),"solids-lab start validates: " + Setup.validate(lab))
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench
	main.simulation_worker.set_worker_participation_sampling(true)
	if not await until(installed,"workbench installed"): return finish()
	# Raised in-flight capacities (owner request: above 4096).
	main.workbench_water_options["workbench_ballistic_capacity"] = 16384
	main.workbench_water_options["workbench_solids_capacity"] = 8192
	check(panel.load_equipment_start(Setup.SOLIDS_LAB_LABEL),"solids-lab load requested")
	if not await until(func() -> bool: return installed() and current() and not solids().is_empty(),"solids-lab installed"): return finish()
	var spray: Dictionary = main.tower_context.get("water_spray",{})
	check(bool(solids().enabled) and int(solids().capacity) == 8192,"flying solids enabled with the raised capacity (%s)" % str(solids().get("capacity")))
	check(bool(spray.get("ballistic_enabled",false)) and int(spray.get("capacity",0)) == 16384,"ballistic Water capacity raised (%s)" % str(spray.get("capacity")))
	var r := receipt()
	check(r.solids_mode == "flying solids" and r.launcher.installed and r.collector.installed,"launcher and collector installed")
	check(int(r.solid_stock.stock) == 200 and int(r.solid_stock.population) > 0,"conveyor starts with 200 Sand")
	var total := sand_total()
	evidence.start = {"sand_total":total,"population":int(r.solid_stock.population)}
	# Refusals change nothing.
	var refused := int(r.refused)
	main.workbench_equipment({"command":"tune_launcher","serial":panel.equipment.serial,"angle":999.0,"speed":4.0,"rate":2})
	main.workbench_equipment({"command":"launcher","serial":panel.equipment.serial-1,"on":true})
	await until(func() -> bool: return int(receipt().refused) >= refused + 2,"invalid launcher commands refused")
	check(not receipt().launcher.on,"refused commands changed nothing")
	panel.toggle_pause()

	# Hopper: the floor valve releases Sand into the collector pit.
	panel.equipment.selected_valve = 0
	check(panel.equipment.toggle("valve"),"hopper valve opened")
	check(panel.equipment.toggle("collector"),"collector opened")
	if not await run_ticks(240,"hopper"): return finish()
	r = receipt()
	var collected := int(r.collector.collected.get("2",0))
	check(collected > 0 and int(r.solid_stock.stock) == 200 + collected,"collected Sand feeds the conveyor exactly (%d)" % collected)
	check(sand_total() == total,"hopper and collector conserve Sand (%d vs %d)" % [sand_total(),total])
	await capture("hopper")
	evidence.hopper = {"collected":collected}

	# Launcher: flying Sand strikes the barrel stack.
	var barrel_before: Dictionary = panel.body_state(3)
	var before: Dictionary = solids().get("ledger",{}).duplicate()
	check(panel.equipment.toggle("launcher"),"launcher on")
	var peak := 0
	var conserved := true
	var deadline := ticks() + 240
	while ticks() < deadline:
		peak = maxi(peak,int(solids().get("live",0)))
		if sand_total() != total: conserved = false
		await process_frame
	await capture("launcher")
	r = receipt()
	var after: Dictionary = solids().ledger
	check(int(r.launcher.launched) > 0 and int(after.injected) - int(before.get("injected",0)) == int(r.launcher.launched),
		"every launcher shot is a native flying solid (%d)" % int(r.launcher.launched))
	check(conserved and sand_total() == total,"grid + flying + conveyor Sand stays constant while firing")
	check(bool(solids().get("closed",false)),"native flying-solid ledger closed")
	check(int(after.body_contacts) - int(before.get("body_contacts",0)) > 0,"flying solids strike the barrels")
	var barrel_after: Dictionary = panel.body_state(3)
	evidence.launcher = {"fired":int(r.launcher.launched),"peak_live":peak,
		"body_contacts":int(after.body_contacts) - int(before.get("body_contacts",0)),
		"terrain_contacts":int(after.terrain_contacts) - int(before.get("terrain_contacts",0)),
		"liquid_contacts":int(after.liquid_contacts) - int(before.get("liquid_contacts",0)),
		"surface_landings":int(after.surface_landings) - int(before.get("surface_landings",0)),
		"landed":int(after.landed) - int(before.get("landed",0)),
		"top_barrel_moved":Vector2(barrel_after.get("position",Vector2.ZERO)).distance_to(Vector2(barrel_before.get("position",Vector2.ZERO)))}
	check(panel.equipment.tune_launcher(10.0),"launcher aim nudged")
	await until(func() -> bool: return is_equal_approx(float(receipt().launcher.angle),-140.0),"launcher aim applied live")

	# Stop: every device closes; in-flight solids land and nothing is lost.
	check(panel.equipment.stop_all(),"stop all")
	await until(func() -> bool: return not receipt().launcher.on and not receipt().collector.open and int(solids().get("live",1)) == 0,
		"devices stopped and every solid landed",90.0)
	evidence.stop = {"live":int(solids().get("live",-1)),"deferred":int(solids().ledger.deferred_landings),
		"forced":int(solids().ledger.forced_landings)}
	check(sand_total() == total,"Sand conserved after landing")
	if not main.paused: panel.toggle_pause()

	# Restore start rebuilds the World; equipment is reconstructed closed.
	var old_serial: int = panel.equipment.serial
	check(panel.restore_start(),"restore start")
	if not await until(func() -> bool: return installed() and current() and panel.equipment.serial > old_serial,"restored"): return finish()
	r = receipt()
	check(int(r.launcher.launched) == 0 and int(r.solid_stock.stock) == 200 and int(solids().get("live",-1)) == 0,"restore resets the solids devices")
	check(is_equal_approx(float(r.config.launcher[2]),-140.0),"restore keeps the authored launcher aim")
	panel._name.text = "test-solids-lab-bs001"
	check(panel.save_setup(),"save named start")
	var loaded := Setup.read_named("test-solids-lab-bs001")
	check(loaded.has("setup") and loaded.setup.get("equipment",{}) == panel.applied.equipment,"saved solids equipment reads back identically")
	DirAccess.remove_absolute(Setup._path("test-solids-lab-bs001"))
	finish()

func finish() -> void:
	evidence.workers_observed_peak = _workers_peak
	evidence.runtime = {"os":OS.get_name(),"godot":Engine.get_version_info().string,
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"))}
	print("SOLIDS_LAB_EVIDENCE " + JSON.stringify(evidence))
	print("SOLIDS_LAB %d checks, %d failures" % [checks, failures])
	if main != null and not main.paused and panel != null and not panel.applied.is_empty(): panel.toggle_pause()
	quit(failures)
