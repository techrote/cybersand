extends SceneTree
## Actual native M1/M2 application controls. No inference performance is claimed.
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
const Experiments = preload("res://scripts/batch_lab/batch_lab_experiments.gd")
var controller: Node
var checks := 0
var failures: Array[String] = []
var evidence := ""
var started := 0
var maximum_active := 0
var frames := 0
var results: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("BATCH_NATIVE_CHECK ",checks," ",label," ",ok)
	if not ok: failures.append(label); push_error(label)
	return ok

func settle(label: String, timeout_ms := 90000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while controller.is_running() and Time.get_ticks_msec()<deadline:
		maximum_active = maxi(maximum_active,controller._active.size())
		frames += 1
		await process_frame
	return check(not controller.is_running(),label)

func configure(values: Array) -> void:
	for i: int in values.size(): check(controller.configure_tile(i,values[i]).ok,"configure tile %d" % i)

func capture(label: String) -> void:
	for i: int in controller.tiles.size():
		var tile: Dictionary = controller.tiles[i]
		var row := {"label":label,"tile":i,"attempt_id":tile.attempt_id,"state":tile.state,
			"material_sha256":tile.get("material_sha256",""),"metrics":tile.metrics,"timings":tile.timings}
		results.append(row)
		if not evidence.is_empty():
			check(controller.export_result(i,evidence.path_join("%s-tile-%02d.json" % [label,i])).ok,"export original %s %d" % [label,i])
			if tile.image!=null: check(tile.image.save_png(evidence.path_join("%s-tile-%02d-material-id.png" % [label,i]))==OK,"material ID image %s %d" % [label,i])

func plane_oracle(config: Dictionary) -> PackedByteArray:
	# Independent scalar rectangle oracle; does not call the product rasterizer.
	var width := int(config.extent[0])
	var height := int(config.extent[1])
	var cells := PackedByteArray()
	cells.resize(width*height*2)
	for rect: Array in config.source_rectangles:
		for y: int in range(rect[1],rect[1]+rect[3]):
			for x: int in range(rect[0],rect[0]+rect[2]): cells.encode_u16((y*width+x)*2,int(rect[4]))
	for op: Dictionary in config.operations:
		for y: int in range(int(op.y0),int(op.y1)+1):
			for x: int in range(int(op.x0),int(op.x1)+1):
				var blocked := false
				for guard: Array in config.protection:
					if x>=guard[0] and x<guard[0]+guard[2] and y>=guard[1] and y<guard[1]+guard[3]: blocked = true
				if not blocked and cells.decode_u16((y*width+x)*2) in [0,58]: cells.encode_u16((y*width+x)*2,int(op.material))
	return cells

func run() -> void:
	started = Time.get_ticks_msec()
	evidence = OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	controller = Controller.new()
	root.add_child(controller)
	await process_frame
	check(ClassDB.class_exists("CyberNativeCellWorld"),"real native runtime available")
	check(controller.tiles.size()==4,"2x2 feasibility grid exists")
	var values: Array = []
	for i: int in 4:
		var config := Controller.defaults()
		config.extent = [64,64]
		config.source_region = [0,0,64,64]
		config.seed = 19301+i
		config.source_rectangles = [[20,20,3,3,28],[30,30,3,3,2]]
		config.protection = [[40,40,3,3]]
		config.operations = [{"shape":"rectangle","x0":8+i,"y0":8,"x1":55,"y1":55,"material":58}]
		values.append(config)
	configure(values)
	var preview: Dictionary = controller.compile_preview(0)
	check(preview.ok and preview.zero_writes and not controller.is_running() and controller.attempts.is_empty(),"compilation preview performs zero native writes")
	check(controller.start().ok,"2x2 queued")
	check(controller.tiles[0].state=="queued" and controller.tiles[0].material_cells.is_empty(),"queue admission is not applied cells")
	if not await settle("2x2 native completion"): finish(); return
	for i: int in 4:
		var tile: Dictionary = controller.tiles[i]
		check(tile.state=="completed","2x2 tile %d completed / %s" % [i,tile.reason])
		check(tile.material_cells==plane_oracle(values[i]),"2x2 tile %d exact complete material oracle" % i)
		check(tile.metrics.get("outside_unchanged",false),"2x2 tile %d native padding unchanged" % i)
		check(not tile.receipts.is_empty() and tile.receipts[0].backend=="CyberNativeCellWorld","2x2 tile %d real native receipt" % i)
	check(maximum_active==2,"two independent native owners execute with bounded concurrency")
	check(controller.tiles[0].execution_origin=="supplied-program","procedural control origin is supplied native program")
	capture("feasibility-2x2")
	if not failures.is_empty(): finish(); return
	var first: PackedByteArray = controller.tiles[0].material_cells.duplicate()
	var neighbor: PackedByteArray = controller.tiles[1].material_cells.duplicate()
	check(controller.replay(0).ok,"deterministic replay queued")
	await settle("deterministic replay completed")
	check(controller.tiles[0].material_cells==first,"fresh native replay exactly matches stored material plane")
	check(controller.tiles[0].execution_origin=="history-replay","replay origin distinguishes retained program from a new inference")
	check(controller.tiles[1].material_cells==neighbor,"replaying one tile cannot mutate another")
	var original: PackedByteArray = controller.tiles[0].source_materials.duplicate()
	check(controller.undo(0).ok,"isolated native material Undo queued")
	await settle("isolated material Undo complete")
	check(controller.tiles[0].material_cells==original,"Undo reconstitutes exact native source plane")
	check(controller.tiles[0].execution_origin=="captured-baseline","material history origin identifies actual native baseline reconstruction")
	check(controller.redo(0).ok,"isolated native material Redo queued")
	await settle("isolated material Redo complete")
	check(controller.tiles[0].material_cells==first,"Redo reconstitutes exact confirmed result plane")
	check(controller.tiles[1].material_cells==neighbor,"history does not modify neighboring tile")
	var captured := PackedByteArray()
	captured.resize(128*128*2)
	captured.encode_u16((74*128+74)*2,28)
	captured.encode_u16((84*128+84)*2,3)
	var cropped: Dictionary = values[0].duplicate(true)
	cropped.source_cells = captured
	cropped.source_extent = [128,128]
	cropped.source_region = [64,64,64,64]
	cropped.source_rectangles = []
	check(controller.configure_tile(0,cropped).ok,"external source capture configured")
	captured.encode_u16((74*128+74)*2,2)
	check(controller.start([0]).ok,"captured source starts independently")
	await settle("captured source completes")
	check(controller.tiles[0].source_materials.decode_u16((10*64+10)*2)==28 \
		and controller.tiles[0].material_cells.decode_u16((10*64+10)*2)==28,"caller mutation cannot alter frozen source and protected Metal survives")
	check(controller.tiles[1].material_cells==neighbor,"captured source attempt cannot affect its neighbor")
	check(controller.tiles[0].source_materials.decode_u16((20*64+20)*2)==3 and controller.tiles[0].material_cells.decode_u16((20*64+20)*2)==3 \
		and controller.tiles[0].receipts[0].tick==0,"Water identity remains isolated and protected in paused native ownership; no simulated tick claim")
	check(controller.tiles[0].metrics.structure.outside_scope_changed_cells==0 and controller.tiles[0].metrics.structure.changed_cells>2000,
		"source-world crop offset does not misclassify valid tile-local construction")
	# A strict host work budget produces a retained real partial prefix.
	var partial: Dictionary = Controller.defaults()
	partial.operations = [{"shape":"rectangle","x0":0,"y0":0,"x1":127,"y1":127,"material":58}]
	partial.budget_cells = 128
	check(controller.configure_tile(0,partial).ok and controller.start([0]).ok,"bounded partial attempt queued")
	await settle("budget partial retires")
	check(controller.tiles[0].state=="partial" and controller.tiles[0].metrics.checked==128 and controller.tiles[0].metrics.changed==128,"budget retains only 128 acknowledged native cells")
	check(controller.tiles[0].material_cells.decode_u16(0)==58 and controller.tiles[0].material_cells.decode_u16(128*2)==0,"partial prefix has no unconfirmed second row")
	var checker := Controller.defaults()
	var points: Array = []
	for y: int in 128:
		for x: int in 128:
			if (x+y)%2==0: points.append([x,y])
	checker.operations = [{"shape":"pixels","points":points,"material":58}]
	checker.budget_cells = 6000
	check(controller.configure_tile(0,checker).ok and controller.start([0]).ok,"large fragmented confirmed prefix queued")
	await settle("fragmented native prefix completes")
	var fragmented: PackedByteArray = controller.tiles[0].material_cells.duplicate()
	check(controller.tiles[0].state=="partial" and controller.tiles[0].accepted_edits.size()>4096,"one supported command yields more than 4096 native accepted fragments")
	check(controller.replay(0).ok,"fragmented replay keeps compact original native program")
	await settle("fragmented native replay completes")
	check(controller.tiles[0].material_cells==fragmented,"6000-cell confirmed replay excludes unconsumed suffix without operation expansion")
	# Stop after one or more native receipts, retaining the real timing-dependent prefix.
	partial.budget_cells = 65536
	partial.extent = [512,512]
	partial.source_region = [0,0,512,512]
	partial.operations = [{"shape":"rectangle","x0":0,"y0":0,"x1":511,"y1":511,"material":58}]
	check(controller.configure_tile(0,partial).ok and controller.start([0]).ok,"running Stop attempt queued")
	var deadline := Time.get_ticks_msec()+90000
	while int(controller.tiles[0].metrics.get("changed",0))==0 and controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	controller.stop([0])
	await settle("running Stop retires at native boundary")
	var stopped: Dictionary = controller.tiles[0]
	var actual := 0
	for i: int in stopped.material_cells.size()/2:
		if stopped.material_cells.decode_u16(i*2)==58: actual += 1
	check(stopped.state=="partial" and actual>0 and actual<512*512 and actual==int(stopped.metrics.changed),"Stop result exactly matches confirmed prefix, not queued suffix")
	check(controller.start([1]).ok,"unstarted Stop queued")
	controller.stop([1])
	check(controller.tiles[1].state=="stopped" and controller.tiles[1].material_cells.is_empty() \
		and controller.tiles[1].material_sha256.is_empty() and controller.tiles[1].accepted_edits.is_empty(),"Stop before dispatch performs no native construction or stale result inheritance")
	# Invalid/native-disallowed requests remain in the denominator.
	var invalid := Controller.defaults()
	invalid.operations = [{"shape":"rectangle","x0":0,"y0":0,"x1":128,"y1":3,"material":58}]
	check(controller.configure_tile(2,invalid).ok and controller.start([2]).ok,"out-of-bounds attempt retained")
	await settle("out-of-bounds refusal completes")
	check(controller.tiles[2].state=="refused" and controller.tiles[2].material_cells.is_empty(),"invalid geometry is refused before native writes")
	invalid = Controller.defaults()
	invalid.provider = "OpenAI"; invalid.model = "unverified-model"
	check(controller.configure_tile(3,invalid).ok and controller.start([3]).ok,"unapproved model request retained")
	await settle("cloud spending gate completes")
	check(controller.tiles[3].state=="refused" and controller.tiles[3].reason.contains("not authorised"),"no silent paid cloud dispatch")
	capture("negative-and-partial")
	check(not Controller.local_endpoint("http://127.0.0.1.evil.test/v1") and not Controller.local_endpoint("https://api.openai.com/v1") \
		and Controller.local_endpoint("http://localhost:1234/v1"),"local-provider routing cannot silently become public paid inference")
	check(not controller.configure_tile(2,{"api_key":"never-export-me"}).ok,"credentials refused in saved configuration")
	# Genuine 16-attempt native grids for all three construction families.
	for family: String in Experiments.FAMILIES:
		check(controller.configure_grid(4,4).ok,"4x4 %s grid" % family)
		var configs := Experiments.make_grid(family,4,19301)
		configure(configs)
		check(controller.start().ok,"4x4 %s queued" % family)
		if not await settle("4x4 %s native completion" % family,180000): finish(); return
		for i: int in 16:
			var tile: Dictionary = controller.tiles[i]
			check(tile.state=="completed" and tile.material_cells==plane_oracle(configs[i]),"%s tile %d exact native outcome" % [family,i])
			check(tile.metrics.get("outside_unchanged",false),"%s tile %d outside footprint unchanged" % [family,i])
		# Prompt metadata alone cannot change an actual deterministic control.
		for i: int in [0,4,8,12]:
			check(controller.tiles[i].material_cells==controller.tiles[i+1].material_cells \
				and controller.tiles[i].material_cells==controller.tiles[i+2].material_cells \
				and controller.tiles[i].material_cells==controller.tiles[i+3].material_cells,"%s P0-P3 controls matched at same seed %d" % [family,i/4])
		check(controller.tiles[0].material_cells!=controller.tiles[4].material_cells,"%s actual seeded variation" % family)
		capture("grid-"+family)
	# Small matched seeded-random controls, including structurally poor results.
	# These are real native executions, not model/prompt performance estimates.
	for family: String in Experiments.FAMILIES:
		check(controller.configure_grid(2,2).ok,"matched random %s 2x2 grid" % family)
		var configs := Experiments.make_grid(family,2,19301,"seeded_random")
		configure(configs)
		check(controller.start().ok,"matched random %s queued" % family)
		if not await settle("matched random %s native completion" % family): finish(); return
		for i: int in 4:
			var tile: Dictionary = controller.tiles[i]
			check(tile.state=="completed" and tile.material_cells==plane_oracle(configs[i]),"random %s tile %d exact native outcome; no quality filter" % [family,i])
		capture("random-"+family)
	if not evidence.is_empty():
		check(controller.save_session(evidence.path_join("native-session.json")).ok,"all successful and unsuccessful attempts saved")
		var saved_count: int = controller.attempts.size()
		var saved_hash: String = controller.tiles[0].material_sha256
		var readback: Dictionary = controller.load_session(evidence.path_join("native-session.json"))
		check(readback.ok and controller.attempts.size()==saved_count and controller.tiles[0].material_sha256==saved_hash,"save/reopen retains all attempted outcomes and exact native plane")
	finish()

func finish() -> void:
	var summary := {"schema":1,"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,
		"attempts":controller.attempts.size(),"maximum_active":maximum_active,"responsive_process_frames":frames,
		"backend":"actual CyberNativeCellWorld via CyberSimulationWorker and ArtBatchExecutor",
		"model_inference":"not performed; deterministic procedural controls and explicit refusals","results":results}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("native-summary.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(summary,"  ")); file.close()
	print("BATCH_NATIVE_RESULT ",JSON.stringify(summary))
	controller.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
