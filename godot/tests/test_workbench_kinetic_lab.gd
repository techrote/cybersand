extends SceneTree

# Kinetic mask tools in the real shared workbench (kinetic-lab start). Each
# authored emitter and every pointer preset flings real Water and solid cells
# through the native ballistic owners. Conservation: the native Water ledger
# stays closed, and grid solids + flying solids stay constant. Requires a
# native runtime built from this source. LIQUID_EQUIPMENT_WORKERS=1|4.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Kinetic = preload("res://scripts/workbench_kinetic_mask.gd")
var main: Control
var panel
var checks := 0
var failures := 0
var evidence := {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("KINETIC_LAB: " + label)
	return ok

func until(test: Callable, label: String, seconds: float = -1.0) -> bool:
	var limit := Watchdogs.milliseconds("operation_seconds") if seconds < 0 else int(seconds * 1000.0)
	var deadline := Time.get_ticks_msec() + limit
	while not test.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check(test.call(), label + " / " + main.microscenario_error + " / " + str(receipt().get("last_refusal","")))

func installed() -> bool:
	return not panel.applied.is_empty() and not panel.busy() and main.pending_microscenario_apply.is_empty()

func receipt() -> Dictionary:
	return main.tower_context.get("workbench_equipment",{}) if main != null else {}

func solids() -> Dictionary:
	return main.tower_context.get("ballistic_solids",{})

func water() -> Dictionary:
	return main.tower_context.get("water_spray",{}).get("water",{})

func current() -> bool:
	return receipt().get("configured",false) and int(receipt().get("serial",-1)) == panel.equipment.serial

func ticks() -> int:
	return int(receipt().get("ticks",0))

func run_ticks(count: int, label: String) -> bool:
	var target := ticks() + count
	return await until(func() -> bool: return ticks() >= target,label + " advanced %d ticks" % count,120.0)

func solid_total() -> int:
	var total := int(solids().get("live",0))
	for key: String in receipt().get("populations",{}): total += int(receipt().populations[key])
	return total

func ledger_closed() -> bool:
	var w := water()
	return not w.is_empty() and int(w.total) == int(w.expected)

func capture(label: String) -> void:
	var directory := OS.get_environment("LIQUID_EQUIPMENT_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null: image.save_png(directory.path_join("kinetic-lab-%s.png" % label))

func run() -> void:
	var workers := int(OS.get_environment("LIQUID_EQUIPMENT_WORKERS")) if not OS.get_environment("LIQUID_EQUIPMENT_WORKERS").is_empty() else 4
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	evidence.requested_workers = workers
	check(Setup.validate(Setup.kinetic_lab(PackedInt32Array([0]))).is_empty(),"kinetic-lab start validates")
	for key: String in Kinetic.ORDER: check(Kinetic.valid_request(key,8,1.0,0.0).is_empty(),"preset %s admitted" % key)
	check(not Kinetic.valid_request("nuke",8,1.0,0.0).is_empty() and not Kinetic.valid_request("blast",99,1.0,0.0).is_empty(),
		"unknown preset and oversized radius refused")
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench
	if not await until(installed,"workbench installed"): return finish()
	check(panel.load_equipment_start(Setup.KINETIC_LAB_LABEL),"kinetic-lab load requested")
	if not await until(func() -> bool: return installed() and current() and not solids().is_empty() and not receipt().get("populations",{}).is_empty(),
		"kinetic-lab installed"): return finish()
	check(bool(solids().enabled) and bool(main.tower_context.get("water_spray",{}).get("ballistic_enabled",false)),"flying Water and solids enabled")
	check(receipt().kinetics.size() == 5,"five emitters installed")
	await until(ledger_closed,"native Water ledger published")
	var total := solid_total()
	var water_total := int(water().total)
	evidence.start = {"solids":total,"water":water_total}
	panel.toggle_pause()

	# Each emitter flings the material it sits in.
	var expected := {0:"solids",1:"water",2:"water",3:"solids",4:"solids"}
	var per := {}
	for index: int in expected:
		var before: Dictionary = receipt().kinetics[index].duplicate()
		main.workbench_equipment({"command":"kinetic_pulse","serial":panel.equipment.serial,"index":index})
		await until(func() -> bool: return int(receipt().kinetics[index].pulses) > int(before.pulses),"emitter %d pulsed" % index)
		var after: Dictionary = receipt().kinetics[index]
		var flung := int(after[expected[index]]) - int(before[expected[index]])
		check(flung > 0,"%s emitter flung %s (%d)" % [after.preset,expected[index],flung])
		per[after.preset] = {"water":int(after.water) - int(before.water),"solids":int(after.solids) - int(before.solids)}
		if not await run_ticks(30,"after " + str(after.preset)): return finish()
		check(solid_total() == total,"solids conserved after %s (%d vs %d)" % [after.preset,solid_total(),total])
		check(ledger_closed() and int(water().total) == water_total,"Water conserved after %s" % after.preset)
	evidence.emitters = per
	await capture("emitters")

	# The pointer tool applies every preset anywhere.
	var applications := int(receipt().kinetic_totals.applications)
	var at := [Vector2i(60,250),Vector2i(220,240),Vector2i(360,248),Vector2i(440,258)]
	var i := 0
	for key: String in Kinetic.ORDER:
		main.workbench_equipment({"command":"kinetic_at","at":at[i % at.size()],"preset":key,"radius":10,"strength":1.0,"angle":-60.0})
		i += 1
		await process_frame
	await until(func() -> bool: return int(receipt().kinetic_totals.applications) >= applications + Kinetic.ORDER.size(),"pointer presets applied")
	var refused_before := int(receipt().refused)
	main.workbench_equipment({"command":"kinetic_at","at":Vector2i(60,250),"preset":"nuke","radius":10,"strength":1.0,"angle":0.0})
	await until(func() -> bool: return int(receipt().refused) > refused_before,"invalid pointer preset refused")
	if not await run_ticks(60,"pointer"): return finish()
	await capture("pointer")
	check(solid_total() == total and ledger_closed() and int(water().total) == water_total,"pointer presets conserve Water and solids")

	# Hold repeats each emitter at its preset period; Stop releases them.
	check(panel.equipment.hold_emitters(),"hold emitters")
	if not await run_ticks(120,"hold"): return finish()
	var held := 0
	for emitter: Dictionary in receipt().kinetics: held += int(emitter.pulses)
	check(held >= 5 * 3,"held emitters repeat (%d pulses)" % held)
	check(panel.equipment.stop_all(),"stop all")
	await until(func() -> bool:
		for emitter: Dictionary in receipt().kinetics:
			if emitter.hold: return false
		return true,"stop releases held emitters")
	await until(func() -> bool: return int(solids().get("live",1)) == 0 and int(water().get("ballistic",1)) == 0,"everything in flight landed",60.0)
	check(solid_total() == total and ledger_closed() and int(water().total) == water_total,"final Water and solids conserved")
	evidence.totals = receipt().kinetic_totals.duplicate(true)
	evidence.solids_ledger = solids().get("ledger",{}).duplicate()
	if not main.paused: panel.toggle_pause()
	finish()

func finish() -> void:
	evidence.runtime = {"os":OS.get_name(),"godot":Engine.get_version_info().string,
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"))}
	print("KINETIC_LAB_EVIDENCE " + JSON.stringify(evidence))
	print("KINETIC_LAB %d checks, %d failures" % [checks, failures])
	if main != null and not main.paused and panel != null and not panel.applied.is_empty(): panel.toggle_pause()
	quit(failures)
