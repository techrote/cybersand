extends SceneTree

# EXPLORE-001 native + ordinary shared workbench, deliberately not a second
# generated-scene runtime. Run as a separate process again with
# CYBERSAND_EXPLORE_REOPEN=1 to prove persistent map reconstruction.
const Setup = preload("res://scripts/workbench_setup.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var panel: Control
var dialog: ConfirmationDialog
var checks := 0
var failed := 0
var _small_complete := false
var _new_complete := false
var _reopen_complete := false
var start_ms := 0
var name := "explore001-generated-acceptance"

func _initialize() -> void:
	start_ms = Time.get_ticks_msec()
	run.call_deferred()

func require(condition: bool, detail: String) -> bool:
	checks += 1
	if not condition:
		failed += 1
		push_error("EXPLORE001: " + detail + " / " + host.microscenario_error)
	return condition

func until(predicate: Callable, detail: String, seconds: int = 180) -> bool:
	var deadline: int = Time.get_ticks_msec() + maxi(seconds * 1000, Watchdogs.milliseconds("operation_seconds"))
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		await process_frame
	return require(false,detail + " / " + (dialog._status.text if dialog != null else "generator dialog not mounted"))

func installed() -> bool:
	return not panel.applied.is_empty() and not panel.busy() and host.pending_microscenario_apply.is_empty()

# A previous blank map can already have an uploaded image. Only a fresh,
# source-matched presentation generation from the new native owner can satisfy
# installation/readback assertions.
func uploaded_after(previous: int) -> bool:
	if host.latest_snapshot == null: return false
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	return host.last_uploaded_world_generation > previous and \
		host.last_uploaded_world_generation == snapshot.render_world_generation and \
		host.last_uploaded_revision == snapshot.world_revision and \
		snapshot.world_revision == snapshot.simulation_world_revision

func screenshot(label: String) -> void:
	var directory := OS.get_environment("CYBERSAND_EXPLORE_CAPTURE")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().save_png(directory.path_join(label+".png")) == OK,
		"original framebuffer "+label)

func compare_materials(expected: PackedByteArray, width: int, height: int, label: String) -> void:
	if not require(host.image.get_width()==width and host.image.get_height()==height,
			label + " world render dimensions"): return
	var actual: PackedByteArray = host.image.get_data()
	var stride := 2 if host.image.get_format()==Image.FORMAT_RG8 else 1
	if not require(actual.size() >= expected.size()*stride,label+" rendered buffer size"): return
	var different := 0
	var display_water_coverage := 0
	for i: int in expected.size():
		var id: int = int(actual[i*stride])
		if expected[i]==3 and id in [0,3]:
			if id==0: display_water_coverage += 1
			continue
		if id!=expected[i]: different += 1
	require(different==0,label+" native render-copy parity outside documented Water/Empty dither; mismatch="+str(different))
	print("EXPLORE001_RENDER ",label," water_dithered_cells=",display_water_coverage)

# The authoritative material-ID oracle is the native prepared-World receipt,
# not the visible Water coverage projection (the latter deliberately dithers).
func authoritative_cells(expected: PackedByteArray, baseline_sha: String, label: String) -> void:
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt",{})
	require(not receipt.is_empty(),label+" native prepared-owner receipt exists")
	require(str(receipt.get("generated_prepared_material_sha256",""))==Store.digest(expected),
		label+" exact native stored-material digest before first tick")
	require(str(receipt.get("generated_source_sha256",""))==baseline_sha,
		label+" generator material fingerprint independently preserved")

func free_spawn(cells: PackedByteArray, side: int) -> Vector2:
	for y: int in range(40,side-40,16):
		for x: int in range(40,side-40,16):
			var clear := true
			for dy: int in range(-14,15,2):
				for dx: int in range(-14,15,2):
					if cells[(y+dy)*side+x+dx]!=0:
						clear=false
						break
				if not clear: break
			if clear: return Vector2(x,y)
	return Vector2(-1,-1)

func exercise_saved() -> void:
	var data: Dictionary = Store.read_named(name)
	if not require(data.get("generated",false),"fresh-process versioned generated map readable"): return
	dialog.open_saved(data.setup,data.generation)
	if not await until(func() -> bool: return dialog._phase=="ready" or dialog._status.text.begins_with("Refused"),
			"saved native recipe regeneration",240): return
	if not require(dialog._phase=="ready","no generator revision/material mismatch on restart"): return
	var cells: PackedByteArray = dialog._ready_packet.cells.duplicate()
	require(Store.digest(cells)==data.generation.sha256,"regenerated bytes match saved source")
	var setup: Dictionary = data.setup
	var edited := cells.duplicate()
	for stamp: Array in setup.edits:
		if stamp.size()!=4: continue
		var x: int=stamp[0]
		var y: int=stamp[1]
		var radius: int=stamp[2]
		for dy: int in range(-radius,radius+1):
			for dx: int in range(-radius,radius+1):
				if dx*dx+dy*dy<=radius*radius and x+dx>=0 and x+dx<setup.extent[0] and y+dy>=0 and y+dy<setup.extent[1]:
					edited[(y+dy)*setup.extent[0]+x+dx]=stamp[3]
	var previous_generation: int = host.last_uploaded_world_generation
	if not require(panel.install_generated_start(setup,dialog._ready_packet),"fresh process generated start requested"): return
	dialog.hide()
	if not await until(installed,"fresh-process prepared World and Rapier acknowledged"): return
	if not await until(uploaded_after.bind(previous_generation),"matching published fresh-process native World"): return
	authoritative_cells(edited,data.generation.sha256,"fresh-process edited starting map")
	compare_materials(edited,setup.extent[0],setup.extent[1],"fresh-process edited starting map")
	require(panel.applied.actors==setup.actors and panel.applied.selected==setup.selected,
		"fresh-process authored spawns and selected flyer")
	require(panel.applied.liquid_policy==setup.liquid_policy,"fresh-process liquid selection")
	require(panel._generated_active.recipe_sha256==data.generation.recipe_sha256,
		"fresh-process procedural provenance remains bound")
	await screenshot("explore001-reopened-start")
	var prior_tick: int=host.latest_snapshot.tick_index
	require(panel.toggle_pause(),"reopened generated map Play")
	await until(func() -> bool: return int(host.latest_snapshot.tick_index)>=prior_tick+8,"reopened native ticks")
	panel.toggle_pause()
	_reopen_complete = true

# A second native source genuinely generates and installs 512² Water plus hard
# terrain, without using the rich semantic fixture's non-play scripted water.
func exercise_small() -> void:
	var fixture: Dictionary = {"schema":1,"seed":917,"chunk_size":64,
		"candidate":"strata",
		"parameters":{"surface_y":0,"relief":0,"fluid_level":64},
		"themes":{"weights":{"basalt":1},"exclude":[]},
		"overrides":[
			{"id":"explore001-water","bounds":[320,420,150,56],"material":3},
			{"id":"explore001-floor","bounds":[304,620,464,18],"material":58}]}
	dialog.open_new()
	dialog._saved_recipe = fixture
	dialog._extent.select(0)
	dialog._x.set_value_no_signal(256)
	dialog._y.set_value_no_signal(256)
	dialog._start()
	if not await until(func() -> bool: return dialog._phase=="ready" or dialog._status.text.begins_with("Refused"),
			"512² Water/native material fixture",180): return
	if not require(dialog._phase=="ready","512 native generation preview"): return
	var source: Dictionary=dialog._ready_packet.duplicate(true)
	require(source.cells.size()==512*512 and source.cells.find(3)>=0 and source.cells.find(58)>=0,
		"genuinely generated Water and hard rock exist")
	var global_chunk: Dictionary=dialog._generator.generate_chunk(Vector2i(4,4))
	require(global_chunk.get("ok",false) and global_chunk.cells[0]==source.cells[0],
		"global (256,256) native sampler maps exactly to destination local (0,0)")
	var candidate: Dictionary=Setup.fresh(panel._liquids.bridge.default_liquid_policy(),Vector2i(512,512))
	var previous_generation: int = host.last_uploaded_world_generation
	if not require(panel.install_generated_start(candidate,source),"512 native World constructor"): return
	dialog.hide()
	if not await until(installed,"512 native World and Rapier installed"): return
	if not await until(uploaded_after.bind(previous_generation),"source-matched 512 pixel publication"): return
	authoritative_cells(source.cells,source.sha256,"512 native generated Water and hard surface")
	compare_materials(source.cells,512,512,"512 native generated Water and hard surface")
	var tick: int=host.latest_snapshot.tick_index
	require(panel.toggle_pause(),"512 Water Play")
	await until(func() -> bool: return host.latest_snapshot.tick_index>=tick+18,"512 Water native ticks")
	panel.toggle_pause()
	previous_generation = host.last_uploaded_world_generation
	if not require(panel.restore_start(),"512 generated initial-state reset"): return
	if not await until(installed,"512 generated reset acknowledged"): return
	if not await until(uploaded_after.bind(previous_generation),"512 generated native reset render identity"): return
	authoritative_cells(source.cells,source.sha256,"512 exact generated reset after evolved Water")
	compare_materials(source.cells,512,512,"512 exact generated reset after evolved Water")
	var old: Dictionary=panel.applied.duplicate(true)
	dialog.open_new()
	dialog._saved_recipe=fixture
	dialog._extent.select(0)
	dialog._start()
	dialog.hide()
	require(panel.applied==old and installed(),"cancelled native generation left existing map unchanged")
	_small_complete = true

func exercise_new() -> void:
	dialog.open_new()
	for i: int in dialog._profile.item_count:
		if dialog._profile.get_item_text(i) == "gen007-deepworks":
			dialog._profile.select(i)
			break
	dialog._seed.set_value_no_signal(19337)
	dialog._extent.select(1)
	dialog._x.set_value_no_signal(0)
	dialog._y.set_value_no_signal(0)
	dialog._start()
	if not await until(func() -> bool: return dialog._phase=="ready" or dialog._status.text.begins_with("Refused"),
			"deepworks 1024x1024 native generation",300): return
	if not require(dialog._phase=="ready","full native play-plane preview / "+dialog._status.text): return
	var source: Dictionary = dialog._ready_packet.duplicate(true)
	require(source.cells.size()==1048576 and source.receipt_hashes.size()>0,
		"native 1024x1024 copied material and receipts")
	var model := Setup.fresh(panel._liquids.bridge.default_liquid_policy(),Vector2i(1024,1024))
	var previous_generation: int = host.last_uploaded_world_generation
	if not require(panel.install_generated_start(model,source),"actual shared prepared-World request"): return
	dialog.hide()
	if not await until(installed,"generated 1024 native/Rapier install",180): return
	if not await until(uploaded_after.bind(previous_generation),
			"source-matched 1024 native material publication"): return
	authoritative_cells(source.cells,source.sha256,"generated-before-simulation")
	compare_materials(source.cells,1024,1024,"generated-before-simulation")
	require(panel._generated_active.sha256==source.sha256,"preserved generator metadata")
	require(panel.applied.edits.is_empty(),"no procedural cells translated to paint history")
	await screenshot("explore001-generated")
	var original: PackedByteArray = source.cells
	var invalid: Dictionary = source.duplicate(true)
	invalid.cells[128] = 10
	invalid.sha256 = Store.digest(invalid.cells)
	require(not panel.install_generated_start(model,invalid) and installed(),
		"invalid material rejected by source-attested dialog; old World preserved")
	# Exercise the native constructor as well: a direct internal apply bypasses
	# dialog attestation, so its validated copy must still reject forbidden ids.
	var previous_epoch: int = host._physical_epoch
	if panel.apply(model,false,0,false,false,invalid):
		await until(func() -> bool: return host.pending_microscenario_apply.is_empty(),
			"native malformed material refusal completed")
	require(installed() and host._physical_epoch==previous_epoch and \
			panel._generated_active.sha256==source.sha256,
		"invalid material rejected by prepared native builder without World swap")
	invalid = source.duplicate(true)
	invalid.cells.resize(100)
	require(not panel.install_generated_start(model,invalid) and installed(),
		"truncated generated array refused; old World preserved")
	previous_epoch=host._physical_epoch
	if panel.apply(model,false,0,false,false,invalid):
		await until(func() -> bool: return host.pending_microscenario_apply.is_empty(),
			"native truncated array refusal completed")
	require(installed() and host._physical_epoch==previous_epoch and \
			panel._generated_active.sha256==source.sha256,
		"truncated material refused without committing the prepared World")
	invalid = source.duplicate(true)
	invalid.sha256 = "0".repeat(64)
	require(not panel.install_generated_start(model,invalid) and installed(),
		"mismatched SHA refused; old World preserved")
	previous_epoch=host._physical_epoch
	if panel.apply(model,false,0,false,false,invalid):
		await until(func() -> bool: return host.pending_microscenario_apply.is_empty(),
			"native mismatched SHA refusal completed")
	require(installed() and host._physical_epoch==previous_epoch and \
			panel._generated_active.sha256==source.sha256,
		"source hash mismatch rejected without changing the installed World")
	var spawn: Vector2 = free_spawn(original,1024)
	if not require(spawn.x>0,"actual generated flyer clearance found"): return
	if not require(panel.place("midge",spawn),"existing controllable flyer placed"): return
	if not await until(installed,"flyer accepted on generated map"): return
	require(panel.select_instance(1),"flyer selected to pilot")
	var body: Dictionary = panel.body_state(1)
	require(not body.is_empty() and body.get("model")=="midge","real Rapier flyer body registered")
	# An Erase changes the authored starting map, not only the evolving World.
	var at := Vector2i(160,160)
	panel._brush.value=3
	if not require(panel.paint(at,0),"generated-terrain erase via ordinary brush"): return
	var over := Vector2i(188,166)
	if not require(panel.paint(over,58),"generated-terrain overpaint via ordinary brush"): return
	if not await until(func() -> bool:
		return host.image.get_pixelv(over).r8==58 and host.image.get_pixelv(at).r8==0,
		"actual native paint/erase and collider update"): return
	require(panel.applied.edits.size()==2 and panel.applied.edits[0][3]==0,
		"ordered Erase and Hard wall edits retained without rectangles")
	await screenshot("explore001-painted")
	var earlier: Vector2 = Vector2(panel.body_state(1).position)
	var tick: int=host.latest_snapshot.tick_index
	require(panel.toggle_pause(),"play generated map")
	var input := InputEventKey.new()
	input.keycode=KEY_W
	input.pressed=true
	Input.parse_input_event(input)
	if not await until(func() -> bool: return int(host.latest_snapshot.tick_index)>=tick+60,
			"native ticks and Rapier updating together",60): return
	input.pressed=false
	Input.parse_input_event(input)
	panel.toggle_pause()
	var later: Dictionary=panel.body_state(1)
	require(not host.simulation_worker.has_failed(),"native worker healthy after flyer motion")
	require(not later.is_empty() and Vector2(later.position).distance_to(Vector2(earlier))>0.05,
		"controllable flyer changed physical position under W input")
	await screenshot("explore001-played")
	panel._name.text = name
	require(panel.save_setup(),"atomic generated map save")
	var saved: Dictionary=Store.read_named(name)
	require(saved.get("generated",false),"manifest readback and provenance")
	if saved.get("generated",false):
		require(saved.generation.sha256==source.sha256 and saved.setup.edits.size()==2,
			"saved original base and two ordered manual edits")
		require(saved.setup.actors.size()==1 and saved.setup.selected==1,
			"saved physical setup and selected flyer")
	_new_complete = true
	print("EXPLORE001_SOURCE ",JSON.stringify({"source_sha256":source.sha256,"profile":source.recipe_sha256,
		"native_receipts":source.receipt_hashes,"install_receipt":host.tower_context.get("liquid_construction_receipt",{}),
		"elapsed_ms":Time.get_ticks_msec()-start_ms}))

func run() -> void:
	root.size=Vector2i(1920,1080)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	if "--workbench" not in OS.get_cmdline_user_args():
		current_scene.launch("shared_workbench")
	await scene_changed
	host=current_scene
	panel=host.shared_workbench
	if not require(panel!=null,"ordinary mounted workbench exists"):
		quit(1)
		return
	dialog=panel._generated_dialog
	if not require(dialog != null,"Godot 4.7 generator dialog compiled and mounted"):
		quit(1)
		return
	if await until(installed,"initial native owner and blank canvas"):
		if OS.get_environment("CYBERSAND_EXPLORE_REOPEN")=="1":
			await exercise_saved()
			require(_reopen_complete,"MANDATORY complete fresh-process generated start and native ticks")
		else:
			await exercise_small()
			require(_small_complete,"MANDATORY complete 512 native Water/generation/reset")
			await exercise_new()
			require(_new_complete,"MANDATORY complete 1024 Deepworks/flyer/paint/save")
	else:
		require(false,"MANDATORY initial World acknowledgment before scenarios")
	require(checks >= 8,"MANDATORY multiple native/gameplay assertions actually ran")
	print("EXPLORE001_RESULTS checks=",checks," failures=",failed,
		" small=",_small_complete," new=",_new_complete," reopened=",_reopen_complete,
		" elapsed_ms=",Time.get_ticks_msec()-start_ms)
	host.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
