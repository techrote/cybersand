extends SceneTree

# WAVE-WATERWALL-001 evidence driver (graphical; not a CI test). Loads an
# authored generated-start manifest through the ordinary Workbench GEN-007
# verify-and-install dialog, selects Wave Flow with or without Waterwall spill
# in the Water Lab, applies, then steps exact native ticks and saves submitted
# framebuffer captures plus copied native Water quantities.
#
#   godot --path godot --script res://tests/workbench_waterwall_capture.gd -- \
#     MAP_JSON|named=SETUP|tank|lip OUT_DIR MODE TICKS(comma list) [WORKERS] [VIEW x,y,w,h ...]
# MODE = orig, spill, hybrid, sloshy, max, max-nograce, combined, combined-nograce or fresh (installed defaults).
# max-nograce uses the Max over-ledge bundle with only Coyote ticks set to zero.
const Setup = preload("res://scripts/workbench_setup.gd")
const GeneratedMaps = preload("res://scripts/workbench_generated_map.gd")
var host: Control
var bench: Control
var out := ""
var mode := ""
var fixture := ""
var terrain_sha := ""
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var captures: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func fail(reason: String) -> void:
	failures.append(reason)
	push_error("WATERWALL_CAPTURE: " + reason)

func installed() -> bool:
	return bench != null and not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func native() -> Dictionary:
	return host.tower_context.get("wave_flow",{})

func until(predicate: Callable, reason: String, seconds := 600.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds*1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		if is_instance_valid(host) and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		await process_frame
	if not predicate.call():
		fail(reason + " / " + str(host.microscenario_error) + " / " + str(bench.message if bench != null else ""))
		return false
	return true

# The same admitted parsing as GeneratedMaps.read_named, reading an explicit
# path instead of a user:// label so the owner's own map store is untouched.
func read_manifest(path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {"error":"invalid JSON"}
	var entry: Dictionary = parser.data
	if entry.get("format","") != GeneratedMaps.FORMAT: return {"error":"not a generated-start manifest"}
	var setup: Dictionary = entry.starting_setup
	var error: String = Setup.validate(setup)
	if error.is_empty(): error = GeneratedMaps.edit_work_error(setup)
	if error.is_empty(): error = GeneratedMaps.valid_provenance(entry.generation,Setup.extent_of(setup))
	if not error.is_empty(): return {"error":error}
	var generation: Dictionary = entry.generation
	for key: String in ["origin","extent"]: generation[key] = Array(PackedInt32Array(generation[key]))
	for key: String in ["schema","generator_revision"]: generation[key] = int(generation[key])
	for key: String in ["version","next_id","selected","rule_radius","material","brush"]: setup[key] = int(setup[key])
	for key: String in ["extent","source","liquid_policy"]: setup[key] = Array(PackedInt32Array(setup[key]))
	for index: int in setup.edits.size(): setup.edits[index] = Array(PackedInt32Array(setup.edits[index]))
	for actor: Dictionary in setup.actors: actor.id = int(actor.id)
	return {"setup":setup,"generation":generation}

func capture(tag: String, views: Array) -> void:
	for frame: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	for index: int in views.size():
		var view: Rect2i = views[index]
		bench._set_view(Vector2(view.position),view.size)
		for frame: int in 4: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var content: Rect2 = host.view_content_rect()
		content.position += host.world_view.get_global_rect().position
		var cropped := image.get_region(Rect2i(content))
		var name := "%s-v%d-%s.png" % [mode,index,tag]
		var path := out.path_join(name)
		if cropped.save_png(path) != OK:
			fail("save "+name)
			return
		captures.append({"file":name,"sha256":FileAccess.get_sha256(path),
			"view":[int(host.camera_origin.x),int(host.camera_origin.y),host.current_view_size.x,host.current_view_size.y]})

func step_to(target: int) -> bool:
	while int(native().get("completed_tick",0)) < target:
		var tick: int = int(native().get("completed_tick",0))
		if not bench.step_once():
			fail("step refused: "+str(bench.message))
			return false
		if not await until(func() -> bool: return installed() and int(native().get("completed_tick",0)) >= tick+1,"native tick "+str(tick+1),60.0):
			return false
	return true

func record(tag: String, started_usec: int) -> void:
	var wave := native()
	rows.append({"tag":tag,"completed_tick":int(wave.get("completed_tick",0)),"wave_ticks":int(wave.get("ticks",0)),
		"water_quantity":str(wave.get("water_quantity","")),"water_cells":int(wave.get("water_cells",0)),
		"native_tick_ms":float(wave.get("native_tick_ms",0.0)),"last_solved_chunks":int(wave.get("last_solved_chunks",0)),
		"parameters":wave.get("parameters",{}).duplicate(true),"spill":wave.get("spill",{}).duplicate(true),"elapsed_s":(Time.get_ticks_usec()-started_usec)/1e6,
		"status":bench.water_spray._wave_status.text,"spill_status":bench.water_spray._spill_status.text})

func install_fixture(path: String) -> bool:
	if path.begins_with("named="):
		var before := int(native().get("session_generation",-1))
		bench._name.text = path.trim_prefix("named=")
		if not bench.load_setup():
			fail("named setup refused: "+str(bench.message))
			return false
		return await until(func() -> bool: return installed() and int(native().get("session_generation",-1)) > before,"load named setup")
	if path in ["tank","lip"]:
		# Same step and wall heights as the native slosh apparatus. Workbench
		# admits a 512-cell minimum canvas, so enclose this 128-cell fixture.
		var open_lip := path == "lip"
		var setup := Setup.fresh(bench._liquids.bridge.default_liquid_policy(),Vector2i(512,512))
		setup.edits = [[128,0,1,129,Setup.WALL],[0,128,128,1,Setup.WALL],
			[16,16,1,41,Setup.WALL],[16,56,66,1,Setup.WALL],
			[81,44 if open_lip else 16,1,13 if open_lip else 41,Setup.WALL],
			[16,80,98,1,Setup.WALL],[113,56,1,25,Setup.WALL],
			[17,45,64,11,Setup.WATER],[17,39,32,6,Setup.WATER]]
		var before := int(native().get("session_generation",-1))
		if not bench.apply(setup):
			fail("tank construction refused: "+str(bench.message))
			return false
		return await until(func() -> bool: return installed() and int(native().get("session_generation",-1)) > before,"install tank")
	var manifest := read_manifest(path)
	if manifest.has("error"):
		fail(str(manifest.error))
		return false
	# Ordinary GEN-007 route: regenerate, verify the saved identity, install.
	var dialog = bench._generated_dialog
	dialog.open_saved(manifest.setup,manifest.generation)
	if not await until(func() -> bool: return dialog._phase == "ready" or dialog._status.text.begins_with("Refused"),"terrain regeneration"):
		return false
	if dialog._phase != "ready" or dialog._ready_packet.sha256 != manifest.generation.sha256:
		fail("regenerated terrain does not match the manifest: "+dialog._status.text)
		return false
	terrain_sha = manifest.generation.sha256
	var before_generation := int(native().get("session_generation",-1))
	dialog._install()
	if not await until(func() -> bool: return installed() and int(native().get("session_generation",-1)) > before_generation,"install map"):
		return false
	dialog.hide()
	return true

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4 or DisplayServer.get_name() == "headless":
		fail("usage: MAP OUT MODE TICKS [WORKERS] [VIEW...] with a real display")
		await finish()
		return
	out = args[1]
	mode = args[2]
	fixture = args[0].get_file()
	if mode not in ["orig","spill","hybrid","sloshy","max","max-nograce","combined","combined-nograce","fresh"]:
		fail("unknown mode "+mode)
		await finish()
		return
	var ticks: Array[int] = []
	for text: String in args[3].split(","):
		if not text.is_valid_int() or int(text) < 0 or (not ticks.is_empty() and int(text) <= ticks[-1]):
			fail("capture ticks must be increasing nonnegative integers")
			await finish()
			return
		ticks.append(int(text))
	var workers := int(args[4]) if args.size() > 4 else 4
	var views: Array = []
	for index: int in range(5,args.size()):
		var p := args[index].split(",")
		views.append(Rect2i(int(p[0]),int(p[1]),int(p[2]),int(p[3])))
	if views.is_empty(): views = [Rect2i(8,10,112,76)] if fixture in ["tank","lip"] else [Rect2i(0,0,1024,1024)]
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_size = Vector2i.ZERO
	root.gui_embed_subwindows = true
	root.size = Vector2i(1600,1000)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	host = current_scene
	bench = host.shared_workbench
	if not await until(installed,"ordinary Workbench starts"):
		await finish()
		return
	if not await install_fixture(args[0]):
		await finish()
		return
	host.paused = true
	# Water Lab: Wave Flow, optional Waterwall spill, workers, Apply.
	var spray = bench.water_spray
	host.workbench_water_options["workbench_worker_threads"] = workers
	if mode == "fresh":
		var initial := native()
		if not initial.get("enabled",false) or not initial.get("spill",{}).get("enabled",false) or not initial.get("spill",{}).get("parcels",false):
			fail("freshly loaded start did not use Wave with spill and ballistic release")
			await finish()
			return
	else:
		spray._set_wave(true)
	var is_sheet := mode in ["max","max-nograce","combined","combined-nograce"]
	var has_parcels := mode in ["hybrid","fresh"] or is_sheet
	var has_spill := mode == "spill" or has_parcels
	if mode != "fresh":
		spray._set_spill("workbench_wave_spill",has_spill)
		spray._set_spill("workbench_wave_spill_parcels",has_parcels)
	if mode in ["sloshy","combined","combined-nograce"]:
		for index: int in spray._wave_preset.item_count:
			if spray._wave_preset.get_item_text(index) == "Sloshy":
				spray._select_wave_preset(index)
	if is_sheet:
		spray._stage_max_over_ledge()
		if mode.ends_with("-nograce"): spray._spill_fields.workbench_wave_spill_coyote_ticks.value = 0
	var before_generation := int(native().get("session_generation",-1))
	if not spray._apply_wave():
		fail("apply refused: "+str(bench.message))
		await finish()
		return
	if not await until(func() -> bool: return installed() and int(native().get("session_generation",-1)) > before_generation \
			and bool(native().get("enabled",false)),"Wave applied"):
		await finish()
		return
	host.paused = true
	var spill_on := bool(native().get("spill",{}).get("enabled",false))
	var parcels_on := bool(native().get("spill",{}).get("parcels",false))
	if spill_on != has_spill or parcels_on != has_parcels:
		fail("native spill readback %s/%s does not match mode %s" % [spill_on,parcels_on,mode])
	var accepted := native()
	if int(accepted.workers_requested) != workers: fail("native workers do not match request")
	for key: String in ["deep_gain","flux_smoothing"]:
		if accepted.parameters.get(key) != host.workbench_water_options["workbench_wave_"+key]: fail("unconfirmed "+key)
	for key: String in ["sheet_rate","coyote_ticks","draw_head"]:
		if accepted.spill.get(key) != host.workbench_water_options["workbench_wave_spill_"+key]: fail("unconfirmed "+key)
	var initial_quantity := str(accepted.water_quantity)
	if bench.water_lab != null and bench.water_lab.window != null: bench.water_lab.window.hide()
	# Keep the paint cursor out of the submitted evidence. At high zoom its
	# cyan hover disc can cover the entire crest while the World is paused.
	bench.paint_editor._overlay.hide()
	var started := Time.get_ticks_usec()
	var base := int(native().get("completed_tick",0))
	for target: int in ticks:
		if not await step_to(base+target): break
		if int(native().completed_tick) != base+target or str(native().water_quantity) != initial_quantity:
			fail("captured tick or conserved quantity differs at "+str(target))
			break
		spray.refresh(host.tower_context)
		record("t%04d" % target,started)
		await capture("t%04d" % target,views)
	await finish()

func finish() -> void:
	var binary := "cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"
	var receipt := {"schema":"wave-waterwall-workbench-capture-v1","mode":mode,"fixture":fixture,"terrain_sha256":terrain_sha,
		"kind":"ordinary Shared Workbench, authored tank, named setup or GEN-007 verified terrain, Water Lab Apply, exact single-step native ticks, submitted framebuffer crops",
		"godot":Engine.get_version_info().string,"display":DisplayServer.get_name(),"rendering":RenderingServer.get_video_adapter_name(),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/"+binary),
		"failures":failures,"rows":rows,"captures":captures}
	if not out.is_empty():
		var file := FileAccess.open(out.path_join("capture-%s.json" % mode),FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(receipt,"\t")+"\n")
			file.close()
	print("WATERWALL_CAPTURE ",JSON.stringify({"mode":mode,"rows":rows.size(),"failures":failures}))
	if is_instance_valid(host): host.queue_free()
	await process_frame
	quit(int(not failures.is_empty()))
