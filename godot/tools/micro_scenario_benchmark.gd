extends SceneTree

# Same frozen definition and owner-side host as interactive consumers. This is
# cellular + stationary sampled-character apparatus, not a Rapier/H-study runner.
const Contract = preload("res://scripts/micro_scenario_contract.gd")
const Catalogue = preload("res://scripts/micro_scenario_catalogue.gd")
const Host = preload("res://scripts/micro_scenario_host.gd")

func _init() -> void:
	call_deferred("_run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var args: Dictionary = {"scenario": "communicating-reservoirs", "seed": "0", "ticks": "180",
		"workers": "1", "mode": "benchmark", "observers": "on",
		"definition": "", "output": "user://micro-benchmark.json"}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if not arg.begins_with("--") or pair.size() != 2 or not args.has(pair[0]):
			fail("Unknown argument: " + arg); return
		args[pair[0]] = pair[1]
	for key: String in ["seed", "ticks", "workers"]:
		if not str(args[key]).is_valid_int(): fail("Invalid numeric " + key); return
	var seed: int = int(args.seed)
	var ticks: int = int(args.ticks)
	var workers: int = int(args.workers)
	if not Contract.integer(seed, 0, Contract.MAX_SEED) or not Contract.integer(ticks, 0, Contract.MAX_TICK+1) \
		or not workers in [1,2,4,6,8,16] or not args.mode in Contract.MODES \
		or not args.observers in ["on", "off"]:
		fail("Out-of-range benchmark arguments"); return
	var raw: Variant
	if str(args.definition).is_empty():
		raw = Catalogue.definition(str(args.scenario), seed)
	else:
		var file: FileAccess = FileAccess.open(str(args.definition), FileAccess.READ)
		if file == null or file.get_length() > Contract.MAX_BYTES:
			fail("Definition missing or over byte budget"); return
		raw = JSON.parse_string(file.get_as_text())
	var checked: Dictionary = Contract.validate(raw)
	if not checked.get("ok", false): fail(str(checked.error)); return
	if bool(checked.definition.body_enabled):
		fail("This definition requires the existing scene/Rapier owner; cellular benchmark refuses to omit bodies"); return
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		fail("Native backend unavailable"); return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var host: CyberMicroScenarioHost = Host.new()
	if not host.reset(world, checked.definition, str(args.mode), args.observers == "on"):
		fail(host.last_error); return
	world.simulation_window_enabled = false
	world.cadence_lod_enabled = false
	world.set_liquid_surface_adhesion_enabled(true)
	var character: CyberSampledCharacter = CyberSampledCharacter.new()
	var spawn: Variant = checked.definition.player_start
	if spawn != null: character.reset(Vector2(spawn[0], spawn[1]))
	var times: Array[int] = []
	var started: int = Time.get_ticks_usec()
	var ok: bool = true
	for i: int in range(ticks):
		var before: int = Time.get_ticks_usec()
		if not host.apply_due(world): ok = false; break
		world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
		if spawn != null: character.simulate(1.0 / 60.0, 0.0, false, world)
		if not world.simulation_tick(): ok = false; break
		times.append(Time.get_ticks_usec() - before)
	var elapsed: int = Time.get_ticks_usec() - started
	var report: Dictionary = host.capture(world, {
		"owner": "headless-cellular-stationary-character-before-cells", "domain": "whole-world",
		"requested_workers": workers, "actual_workers": world.get_worker_threads(), "rapier_active": false})
	report["benchmark"] = {"requested_ticks": ticks, "completed_ticks": world.get_tick_index(),
		"ok": ok, "owner": "headless-cellular-stationary-character-before-cells",
		"interest_domain": "whole-world; compare only matching owner configurations",
		"elapsed_usec": elapsed, "tick_usec": times,
		"timing_scope": "host events + character + native tick; excludes final capture",
		"timing_claim": "measurement of this runtime only, not production performance acceptance"}
	var output: FileAccess = FileAccess.open(str(args.output), FileAccess.WRITE)
	if output == null: fail("Cannot write benchmark output"); return
	output.store_string(JSON.stringify(report, "  ") + "\n")
	print("MS000_BENCHMARK ", JSON.stringify({"ok": ok, "scenario": checked.definition.id,
		"definition_hash": checked.hash, "ticks": world.get_tick_index(), "output": args.output}))
	quit(0 if ok else 1)
