extends SceneTree

# WAVE-WATERWALL-001 evidence driver, not an ordinary CI test. Real keyboard
# input drives a real Midge through Water in the threaded Shared Workbench.
# Only the headless focused-window predicate is replaced. No pose, velocity,
# native cell, or physics control law is edited during the flight.
#   godot --headless --path godot --script res://tests/workbench_waterwall_crest_probe.gd -- \
#     MODE(orig|spill|hybrid) WORKERS CRESTS FIXTURE(pool|wall) BOOST(0|1) [OUT_JSON]
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true

var host: Control
var bench: Control
var failures: Array[String] = []
var output := ""
var mode := "hybrid"
var fixture := "wall"
var workers := 4
var requested_crests := 8
var boost := false
var observed_crests := 0
var observed_submersions := 0
var physical_ticks := 0
var min_y := INF
var max_y := -INF
var peak_parcels := 0
var launched := 0
var initial_quantity := ""
var rows: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func fail(reason: String) -> void:
	failures.append(reason)
	push_error("WATERWALL_CREST: "+reason)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release() -> void:
	for code: Key in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_Q,KEY_E,KEY_SHIFT,KEY_CTRL,KEY_SPACE,KEY_C]:
		key(code,false)

func installed() -> bool:
	return bench != null and not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty()

func native() -> Dictionary:
	return host.tower_context.get("wave_flow",{})

func until(predicate: Callable, label: String, seconds := 90.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed():
			fail(label+": "+str(host.latest_snapshot.last_tick_error))
			return false
		await process_frame
	fail(label+": timed out / "+str(host.microscenario_error))
	return false

# Sample the immutable terrain image already consumed by Main, outside the
# tiny Midge hull. Only Water connected to the fixed reservoir floor counts;
# isolated falling blobs must not manufacture an apparent surface crossing.
func surface(x: int) -> int:
	if host.image == null: return -1
	var samples: Array[int] = []
	for offset: int in [-16,-10,10,16]:
		var column := clampi(x+offset,8,244)
		var top := 396
		for y: int in range(395,139,-1):
			if host.image.get_pixel(column,y).r8 != Setup.WATER: break
			top = y
		if 396-top>=16: samples.append(top)
	if samples.size()<2: return -1
	samples.sort()
	return samples[samples.size()/2]

func install() -> bool:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	current_scene = host
	bench = host.shared_workbench
	if not await until(installed,"ordinary Workbench installation"): return false
	host.workbench_water_options.workbench_worker_threads = workers
	# This historical Midge comparison starts each law at its original tuning.
	var spray = bench.water_spray
	spray._set_wave(true)
	spray._reset_wave_defaults()
	spray._ballistic.button_pressed = false
	for spec: Array in spray.SPILL_SPINS:
		host.workbench_water_options[spec[0]] = int(spec[5])
		spray._spill_fields[spec[0]].set_value_no_signal(int(spec[5]))
	spray._set_spill("workbench_wave_spill_full_face",false)
	spray._set_spill("workbench_wave_spill",mode != "orig")
	spray._set_spill("workbench_wave_spill_parcels",mode == "hybrid")
	host.workbench_water_options.workbench_wave_body_push = 0
	host.workbench_water_options.workbench_wave_body_push_by_mass = 0
	var recipe: Dictionary = Setup.fresh(bench._liquids.bridge.default_liquid_policy(),Vector2i(512,512))
	recipe.actors = [Setup.instance("midge",1,Vector2(128,258))]
	recipe.next_id = 2
	recipe.selected = 1
	recipe.edits = [[0,0,4,472,Setup.WALL],[508,0,4,472,Setup.WALL],
		[0,468,512,4,Setup.WALL],[0,396,256,4,Setup.WALL],
		[252,252 if fixture == "wall" else 0,4,148 if fixture == "wall" else 400,Setup.WALL],
		[4,220,248,176,Setup.WATER],[256,432,252,36,Setup.WATER]]
	var generation: int = int(host.latest_snapshot.render_world_generation)
	if not bench.apply(recipe):
		fail("Midge fixture refused: "+str(bench.message))
		return false
	if not await until(func() -> bool: return installed() and host.latest_snapshot.render_world_generation>generation,
		"Midge fixture installation"): return false
	var wave := native()
	if not bool(wave.get("enabled",false)) or bool(wave.get("spill",{}).get("enabled",false)) != (mode != "orig") \
		or bool(wave.get("spill",{}).get("parcels",false)) != (mode == "hybrid") \
		or int(wave.get("parameters",{}).get("body_push",-1)) != 0 \
		or int(wave.get("parameters",{}).get("body_push_by_mass",-1)) != 0 \
		or int(wave.get("workers_requested",-1)) != workers:
		fail("actual native options differ from requested fixture")
		return false
	initial_quantity = str(wave.get("water_quantity","missing"))
	if not initial_quantity.is_valid_int() or int(initial_quantity)<=0:
		fail("positive native stored-plus-ballistic Water quantity is missing")
		return false
	rows.append({"phase":"installed","native":wave.duplicate(true),
		"actor":host.physical_actor_session.workbench_actor_state(1)})
	release()
	if not bench.toggle_pause():
		fail("unpause refused")
		return false
	var neutral_target: int = host.physical_actor_session.tick+4
	return await until(func() -> bool: return host.physical_actor_session.tick>=neutral_target and not host._actor_input_rearm,
		"neutral keyboard input rearmed")

func fly() -> void:
	var start: int = host.physical_actor_session.tick
	var last_tick := start
	var ascending := true
	var submerged := false
	var deadline := Time.get_ticks_msec()+240000
	key(KEY_C,true)
	key(KEY_SHIFT,boost)
	key(KEY_W,true)
	while observed_crests<requested_crests and Time.get_ticks_msec()<deadline and physical_ticks<requested_crests*600+600:
		await process_frame
		if host.simulation_worker.has_failed():
			fail("native owner quarantined: "+str(host.latest_snapshot.last_tick_error))
			break
		var tick: int = host.physical_actor_session.tick
		if tick == last_tick: continue
		last_tick = tick
		physical_ticks = tick-start
		var actor: Dictionary = host.physical_actor_session.workbench_actor_state(1)
		if actor.is_empty() or actor.get("model","") != "midge":
			fail("real Midge no longer present")
			break
		var position: Vector2 = actor.position
		min_y = minf(min_y,position.y)
		max_y = maxf(max_y,position.y)
		var waterline := surface(roundi(position.x))
		if waterline<0:
			fail("cannot observe a pool-connected Water surface")
			break
		if position.y>waterline+7 and not submerged:
			submerged = true
			observed_submersions += 1
		if submerged and position.y<waterline-7:
			submerged = false
			observed_crests += 1
			rows.append({"phase":"crest","crest":observed_crests,"physics_tick":tick,
				"native_tick":host.latest_snapshot.tick_index,"position":position,"surface_y":waterline,
				"actor":actor,"spill":native().get("spill",{}).duplicate(true)})
		if ascending and position.y<waterline-25:
			ascending = false
			key(KEY_W,false)
			key(KEY_S,true)
		elif not ascending and position.y>waterline+25:
			ascending = true
			key(KEY_S,false)
			key(KEY_W,true)
		var wave := native()
		peak_parcels = maxi(peak_parcels,int(wave.get("spill",{}).get("parcels_peak",0)))
		launched = maxi(launched,int(wave.get("spill",{}).get("launched_parcels",0)))
		if str(wave.get("water_quantity","missing")) != initial_quantity:
			fail("stored plus ballistic Water changed")
			break
		if host.paused:
			fail("Workbench paused unexpectedly: "+str(host.microscenario_error))
			break
	if observed_crests<requested_crests and failures.is_empty():
		fail("did not complete requested surface crossings")
	if mode == "hybrid" and fixture == "wall" and launched == 0:
		fail("hybrid wall fixture never actually launched ballistic Water")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()<5:
		fail("usage: MODE WORKERS CRESTS FIXTURE BOOST [OUT_JSON]")
		await finish()
		return
	mode = args[0]
	workers = int(args[1])
	requested_crests = int(args[2])
	fixture = args[3]
	boost = int(args[4]) == 1
	output = args[5] if args.size()>5 else ""
	if mode not in ["orig","spill","hybrid"] or workers not in [1,2,4,6] \
		or requested_crests<1 or requested_crests>100 or fixture not in ["pool","wall"]:
		fail("invalid bounded flight request")
		await finish()
		return
	root.size = Vector2i(1600,900)
	if await install(): await fly()
	await finish()

func finish() -> void:
	release()
	var binary := "cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"
	var summary := {"schema":"wave-waterwall-crest-probe-v1","mode":mode,"workers":workers,"fixture":fixture,"boost":boost,
		"requested_crests":requested_crests,"crests":observed_crests,"submersions":observed_submersions,
		"physics_ticks":physical_ticks,"min_y":min_y if is_finite(min_y) else null,"max_y":max_y if is_finite(max_y) else null,
		"peak_parcels":peak_parcels,"launched_parcels":launched,"initial_water_quantity":initial_quantity,
		"godot":Engine.get_version_info().string,"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/"+binary),
		"failures":failures,"final_native":native().duplicate(true) if is_instance_valid(host) else {}}
	if not output.is_empty():
		var receipt := summary.duplicate(true)
		receipt["rows"] = rows
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null: fail("cannot save flight receipt")
		else:
			file.store_string(JSON.stringify(receipt,"\t")+"\n")
			file.close()
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	print("WATERWALL_CREST ",JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
