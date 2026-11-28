extends SceneTree
## Scalar geometry oracles + actual Batch Lab native harvest/replay and durable library.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")
var failures: Array[String] = []
var checks := 0
var controller: Node
var evidence := ""

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks+=1
	print("NATIVE_MODULE_CHECK ",checks," ",label," ",condition)
	if not condition: failures.append(label); push_error(label)
	return condition

func bounds() -> Dictionary:
	return {"region":Rect2i(0,0,64,64),"protected":[],"allowed_materials":[0,7,28,58],"max_cells":4096}

func plane(values: Array, width: int, height: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(width*height*2)
	for index: int in values.size(): bytes.encode_u16(index*2,int(values[index]))
	return bytes

func operations_plane(operations: Array, width: int, height: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(width*height*2)
	for op: Dictionary in operations:
		for y: int in range(op.y0,op.y1+1):
			for x: int in range(op.x0,op.x1+1): result.encode_u16((y*width+x)*2,op.material)
	return result

func run() -> void:
	evidence = OS.get_environment("NATIVE_MODULE_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	var library := Library.new()
	if OS.get_environment("NATIVE_MODULE_MODE")=="reopen":
		var path := OS.get_environment("NATIVE_MODULE_LIBRARY_PATH")
		check(library.load_library(path).ok,"fresh process opens exact library")
		check(library.count()==1,"fresh process retains module count")
		var original := library.get_module("industrial-gate")
		if original.is_empty(): finish(); return
		check(not library.summaries()[0].native_readback_verified,"fresh process does not inherit unverified native authority")
		await native_replay(original,"identity",PackedByteArray())
		finish(); return
	var asymmetric := plane([58,0,7,28,58,0],3,2)
	var metadata := {"id":"asymmetric","name":"Asymmetric part","tags":["industrial","test"],
		"part_type":"irregular_transition","allowed_transforms":Module.TRANSFORMS,
		"anchor":[0,1],"provenance":{"kind":"explicit-scalar-test-fixture"},
		"roles":[{"name":"frame","material_ids":[58],"compatible_materials":[28,58],"source":"authored"}],
		"attachments":[{"id":"support","kind":"socket","point":[0,1],"facing":[0,1],
			"compatibility":["support"],"required":true,"source":"authored"}],
		"clearances":[[1,0,1,1]],"variation_regions":[[0,0,3,2]]}
	var harvested := Module.harvest(asymmetric,Vector2i(3,2),Rect2i(0,0,3,2),metadata)
	if not check(harvested.ok,"exact asymmetric fixture harvested"): finish(); return
	var module: Dictionary = harvested.module
	check(harvested.cells==asymmetric,"full material bytes include Empty cells")
	asymmetric.encode_u16(0,65535)
	check(Module.validate(module).cells.decode_u16(0)==58,"caller cannot mutate retained module geometry")
	check(Module.summary(module).native_readback_verified==false,"scalar fixture cannot claim native qualification")
	var wide_identity := Module.harvest(plane([58],1,1),Vector2i.ONE,Rect2i(0,0,1,1),
		{"id":"wide-id","name":"Wide native identities","provenance":{"native_boundary_usec":36500000000,"worker_instance":-9223371963538340290}})
	check(wide_identity.ok and Module.validate(JSON.parse_string(Module.json_bytes(wide_identity.module).get_string_from_utf8())).ok,
		"large native timestamps and signed64 provenance survive JSON exactly")
	# Expected rows written independently, not generated with the product transform.
	var expected := {
		"identity":[[58,0,7,28,58,0],3,2,[0,1],[0,1]],
		"mirror_x":[[7,0,58,0,58,28],3,2,[2,1],[0,1]],
		"mirror_y":[[28,58,0,58,0,7],3,2,[0,0],[0,-1]],
		"rotate_90":[[28,58,58,0,0,7],2,3,[0,0],[-1,0]],
		"rotate_180":[[0,58,28,7,0,58],3,2,[2,0],[0,-1]],
		"rotate_270":[[7,0,0,58,58,28],2,3,[1,2],[1,0]]}
	for transform: String in expected:
		var compiled := Module.compile(module,{"origin":[0,0],"transform":transform},bounds())
		var want: Array = expected[transform]
		check(compiled.ok and compiled.zero_writes,"compile "+transform+" is zero-write")
		if not compiled.ok: continue
		check(operations_plane(compiled.operations,want[1],want[2])==plane(want[0],want[1],want[2]),"independent exact material oracle "+transform)
		check(compiled.anchor==want[3] and compiled.connections[0].point==want[3] and compiled.connections[0].facing==want[4],"anchor and socket transform "+transform)
		check(compiled.budget.unique_cells==4 and compiled.cells.size()==12,"host computed exact occupied budget "+transform)
	var restricted := bounds()
	restricted.protected = [Rect2i(0,0,1,1)]
	check(not Module.compile(module,{"origin":[0,0]},restricted).ok,"protected occupied cell refuses full proposal")
	restricted.protected = [Rect2i(1,0,1,1)]
	check(Module.compile(module,{"origin":[0,0]},restricted).ok,"transparent Empty never erases protected existing content")
	restricted.max_cells = 3
	check(not Module.compile(module,{"origin":[0,0]},restricted).ok,"exact host budget beats proposed counts")
	check(not Module.compile(module,{"origin":[63,63]},bounds()).ok,"whole bounds outside region refused")
	check(not Module.compile(module,{"origin":[0,0],"transform":"rotate_45"},bounds()).ok,"non-grid transform refused")
	check(not Module.compile(module,{"origin":[0.1,0]},bounds()).ok,"fractional origin refused")
	check(not Module.compile(module,{"origin":[0,0],"palette":{"frame":7}},bounds()).ok,"incompatible authored palette refused")
	check(not Module.compile(module,{"origin":[0,0],"palette":{"invented":28}},bounds()).ok,"invented role refused")
	var palette := Module.compile(module,{"origin":[0,0],"palette":{"frame":28}},bounds())
	check(palette.ok and operations_plane(palette.operations,3,2)==plane([28,0,7,28,28,0],3,2),"compatible palette only replaces declared source roles")
	var variation := Module.compile(module,{"origin":[0,0],"variation":{"seed":17,"keep_fraction":0}},bounds())
	check(variation.ok and variation.budget.unique_cells==1 and variation.cells==PackedInt32Array([0,1,28]),"variation preserves required attachment and removes only declared variable cells")
	var once := Module.compile(module,{"origin":[0,0],"variation":{"seed":17,"keep_fraction":0.5}},bounds())
	var twice := Module.compile(module,{"origin":[0,0],"variation":{"seed":17,"keep_fraction":0.5}},bounds())
	check(once.cells==twice.cells and once.placement_sha256==twice.placement_sha256,"seeded variation exactly repeatable")
	for mutation: String in ["bytes","extent","checksum","unknown-field","bad-clearance","inferred-required","secret","bad-role","bad-anchor"]:
		var bad := module.duplicate(true)
		match mutation:
			"bytes": bad.geometry.cells_base64 = "AA=="
			"extent": bad.extent = [513,2]
			"checksum": bad.geometry.sha256 = "0".repeat(64)
			"unknown-field": bad["future_capability"] = true
			"bad-clearance": bad.clearances = [[0,0,1,1]]
			"inferred-required": bad.attachments[0].source = "inferred"
			"secret": bad.provenance["api_key"] = "do-not-store"
			"bad-role": bad.roles[0].material_ids = [58,58]
			"bad-anchor": bad.anchor = [-1,0]
		bad.content_sha256 = Module.content_digest(bad)
		check(not Module.validate(bad).ok,"adversarial import refused: "+mutation)
	var tampered := module.duplicate(true)
	tampered.name = "Unbound mutation"
	check(not Module.validate(tampered).ok,"manifest modification without checksum refused")
	var unknown := Module.harvest(plane([65535],1,1),Vector2i.ONE,Rect2i(0,0,1,1),{"id":"unknown","name":"Unknown source identity"})
	check(unknown.ok and unknown.cells.decode_u16(0)==65535,"unknown uint16 identity retained without substitution")
	check(not Module.compile(unknown.module,{"origin":[0,0]},bounds()).ok,"unsupported stored material cannot become native paint")
	check(library.add(module).ok and library.search("industrial",{"part_type":"irregular_transition"}).size()==1,"module library search and structural filter")
	check(not library.summaries()[0].native_readback_verified,"adding a document cannot self-qualify it")
	var other := module.duplicate(true)
	other.name = "Different module"
	other.content_sha256 = Module.content_digest(other)
	check(not library.add(other).ok,"same identity with different content requires explicit replacement")
	check(library.annotate("asymmetric","Named transition",["service","industrial"]).ok,"rename and tag preserve geometry")
	check(library.get_module("asymmetric").geometry.sha256==module.geometry.sha256,"annotation does not alter exact geometry")
	# Actual native construction is required before the library gets native admission.
	controller = Controller.new()
	root.add_child(controller)
	await process_frame
	check(ClassDB.class_exists("CyberNativeCellWorld"),"actual native runtime available")
	controller.configure_grid(1,1)
	var config := Controller.defaults()
	config.extent = [64,64]; config.source_region = [0,0,64,64]; config.materials = [0,7,28,58]
	config.operations = [
		{"shape":"rectangle","x0":4,"y0":56,"x1":59,"y1":59,"material":58},
		{"shape":"rectangle","x0":8,"y0":12,"x1":11,"y1":55,"material":28},
		{"shape":"rectangle","x0":52,"y0":12,"x1":55,"y1":55,"material":28},
		{"shape":"rectangle","x0":8,"y0":8,"x1":55,"y1":11,"material":7}]
	check(controller.configure_tile(0,config).ok and controller.start([0]).ok,"native industrial gate queued")
	if not await settle("native industrial gate completed"): finish(); return
	var tile: Dictionary = controller.tiles[0]
	check(tile.state=="completed" and tile.material_cells==operations_plane(config.operations,64,64),"native original exactly matches independent scalar construction")
	var native_library := Library.new()
	var native := native_library.harvest_tile(tile,{"id":"industrial-gate","name":"Industrial gate","tags":["industrial","gateway"],
		"part_type":"beam_truss","allowed_transforms":Module.TRANSFORMS,"clearances":[[12,12,40,44]],
		"roles":[{"name":"beam","material_ids":[7],"compatible_materials":[7,28,58],"source":"authored"}]})
	if not check(native.ok,"completed tile harvested from actual native receipts"): finish(); return
	check(native_library.summaries()[0].native_readback_verified,"live native harvest gets current-session observation qualification")
	var refused_tile := tile.duplicate(true)
	refused_tile.state = "partial"
	check(not native_library.harvest_tile(refused_tile,{}).ok,"partial tile cannot masquerade as successful native module")
	refused_tile = tile.duplicate(true); refused_tile.receipts = []
	check(not Module.harvest_tile(refused_tile,{}).ok,"missing native receipts refuse harvest")
	for mutation: String in ["queued-receipt","missing-counter","inconsistent-counter","receipt-hash","source-hash","unacknowledged-change"]:
		refused_tile = tile.duplicate(true)
		match mutation:
			"queued-receipt": refused_tile.receipts[0].status = "queued"
			"missing-counter": refused_tile.receipts[0].erase("checked")
			"inconsistent-counter": refused_tile.receipts[0].confirmed = 0
			"receipt-hash": refused_tile.receipts[0].readback_sha256 = "bad"
			"source-hash": refused_tile.provenance.source_material_sha256 = "0".repeat(64)
			"unacknowledged-change":
				for receipt: Dictionary in refused_tile.receipts:
					receipt.unchanged = receipt.changed; receipt.changed = 0
		check(not Module.harvest_tile(refused_tile,{}).ok,"native custody mutation refused: "+mutation)
	var retained := Library.new()
	refused_tile = tile.duplicate(true); refused_tile.provenance.reopened_record = true
	var old_capture := retained.harvest_tile(refused_tile,{"id":"retained","name":"Retained qualified evidence"})
	check(old_capture.ok and not retained.summaries()[0].native_readback_verified,
		"reopened retained tile can be harvested without asserting fresh native observation: "+str(old_capture.get("reason","")))
	var original: PackedByteArray = tile.material_cells.duplicate()
	await native_replay(native.module,"identity",original)
	await native_replay(native.module,"mirror_x",PackedByteArray())
	var path := OS.get_environment("NATIVE_MODULE_LIBRARY_PATH")
	if path.is_empty(): path = "user://native-module-test/library.json"
	check(native_library.save(path).ok,"library atomically saved with native replacement primitive")
	var reopened := Library.new()
	var loaded := reopened.load_library(path)
	check(loaded.ok and reopened.get_module("industrial-gate")==native.module,"library roundtrip exact manifest: "+str(loaded.get("reason","")))
	if not loaded.ok: finish(); return
	check(not reopened.summaries()[0].native_readback_verified,"reopened claims require fresh native replay qualification")
	var export_path := path.get_base_dir().path_join("industrial-gate.json")
	check(native_library.export_module("industrial-gate",export_path).ok,"native module exported")
	var imported := Library.new()
	check(imported.import_module(export_path).ok and imported.get_module("industrial-gate")==native.module,"native module import preserves exact recipe and geometry")
	var malformed := FileAccess.open(path.get_base_dir().path_join("malformed.json"),FileAccess.WRITE)
	malformed.store_string('{"format":"cybersand-native-module-library-v1","modules":[],"content_sha256":"bad"}')
	malformed.close()
	check(not reopened.load_library(path.get_base_dir().path_join("malformed.json")).ok and reopened.count()==1,"failed load retains previous library")
	if not evidence.is_empty():
		native_library.export_module("industrial-gate",evidence.path_join("industrial-gate.module.json"))
	finish()

func settle(label: String) -> bool:
	var deadline := Time.get_ticks_msec()+90000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	return check(not controller.is_running(),label)

func native_replay(module: Dictionary, transform: String, exact: PackedByteArray) -> void:
	if controller==null:
		controller = Controller.new(); root.add_child(controller); await process_frame; controller.configure_grid(1,1)
	var compiled := Module.compile(module,{"origin":[0,0],"transform":transform},bounds())
	if not check(compiled.ok,"native replay compiled "+transform): return
	var config := Controller.defaults()
	config.extent = [64,64]; config.source_region = [0,0,64,64]; config.materials = [0,7,28,58]
	config.operations = compiled.operations
	check(controller.configure_tile(0,config).ok and controller.start([0]).ok,"native replay queued "+transform)
	if not await settle("native replay completed "+transform): return
	var tile: Dictionary = controller.tiles[0]
	check(tile.state=="completed" and tile.material_cells==operations_plane(compiled.operations,64,64),"native replay exact complete plane "+transform)
	if not exact.is_empty(): check(tile.material_cells==exact,"harvest and fresh native replay retain every original material ID")
	check(tile.metrics.get("outside_unchanged",false),"native replay leaves arena outside module unchanged "+transform)
	check(controller.undo(0).ok,"native replay undo queued "+transform)
	await settle("native replay undo settled "+transform)
	check(controller.tiles[0].material_cells.count(0)==controller.tiles[0].material_cells.size(),"native replay undo returns exact empty source "+transform)
	check(controller.redo(0).ok,"native replay redo queued "+transform)
	await settle("native replay redo settled "+transform)
	check(controller.tiles[0].material_cells==operations_plane(compiled.operations,64,64),"native replay redo restores exact module "+transform)

func finish() -> void:
	if controller!=null: controller.queue_free()
	var report := {"schema":1,"checks":checks,"failures":failures,"passed":failures.is_empty(),
		"engine":Engine.get_version_info().string,"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/"+("cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "libcybersand_native.linux.x86_64.so")),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"Native material geometry, receipts and durable replay. No physical owner or model-quality acceptance."}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("native-module-"+OS.get_environment("NATIVE_MODULE_MODE")+"report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NATIVE_MODULE_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
