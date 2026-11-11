extends SceneTree

# Run again in a NEW process with CYBERSAND_PAINT_HISTORY_REOPEN=1.
# Uses the real native prepared constructor and stored-material observations;
# the focused authoring helper does not own or mutate a running worker World.
const History = preload("res://scripts/workbench_paint_editor_history.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const LABEL := "paint001-history-regression"
const EXTENT := Vector2i(512,512)
var checks := 0
var failures := 0
var bridge: Object
var checked: Dictionary


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("PAINT_EDITOR_HISTORY: "+message)
	return ok


func recipe() -> Dictionary:
	return {"schema":1,"seed":543,"chunk_size":64,"candidate":"strata",
		"parameters":{"surface_y":180,"relief":0,"cave_threshold":1,"detail":0},
		"themes":{"weights":{"basalt":1}},
		"overrides":[{"id":"paint-water-source","bounds":[196,196,20,20],"material":3}]}


func generated(source: Dictionary) -> Dictionary:
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = generator.configure(source)
	if not check(configured.get("ok",false),"actual native generator recipe admitted"): return {}
	var cells := PackedByteArray()
	cells.resize(512*512)
	var receipts := []
	for cy: int in 8:
		for cx: int in 8:
			var packet: Dictionary = generator.generate_chunk(Vector2i(cx,cy))
			if not check(packet.get("ok",false) and packet.get("state","") == "ready",
					"native generation chunk %d/%d" % [cx,cy]): return {}
			var values: PackedByteArray = packet.cells
			for y: int in 64:
				for x: int in 64:
					cells[(cy*64+y)*512+cx*64+x] = values[y*64+x]
			receipts.append(str(packet.receipt_hash))
	return {"recipe":source.duplicate(true),"origin":Vector2i.ZERO,"extent":EXTENT,
		"cells":cells,"sha256":Store.digest(cells),"recipe_sha256":Store.recipe_hash(source),
		"generator_fingerprint":str(configured.fingerprint),"plane_revision":"",
		"generator_revision":int(configured.revision),"receipt_hashes":receipts}


func mixed_cells() -> PackedInt32Array:
	var result := PackedInt32Array()
	for y: int in range(200,208):
		for x: int in range(200,208):
			result.append_array(PackedInt32Array([x,y,[0,2,3,58,77,131,7,16][x-200]]))
	return result


func reference(setup: Dictionary, packet: Dictionary = {}) -> PackedByteArray:
	var values: PackedByteArray = packet.cells.duplicate() if not packet.is_empty() else PackedByteArray()
	if values.is_empty(): values.resize(512*512)
	for stamp: Array in setup.edits:
		if stamp.size() == 5:
			for y: int in range(stamp[1],stamp[1]+stamp[3]):
				for x: int in range(stamp[0],stamp[0]+stamp[2]): values[y*512+x] = stamp[4]
		else:
			for y: int in range(maxi(0,stamp[1]-stamp[2]),mini(512,stamp[1]+stamp[2]+1)):
				for x: int in range(maxi(0,stamp[0]-stamp[2]),mini(512,stamp[0]+stamp[2]+1)):
					if (x-stamp[0])*(x-stamp[0])+(y-stamp[1])*(y-stamp[1]) <= stamp[2]*stamp[2]:
						values[y*512+x] = stamp[3]
	return values


func verify_native(setup: Dictionary, packet: Dictionary = {}) -> void:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world.diagnostic_reset({"workers":1}),"actual native World initialized")
	var options := {"workbench_extent":EXTENT,"workbench_response":str(setup.response),
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),
			"geometry":PackedFloat64Array(),"bodies":[],"emitters":[]},
		"region":PackedInt32Array([0,0,512,512]),"intent":"exploratory","definition_hash":checked.hash}
	var runs := PackedInt32Array()
	if packet.is_empty(): runs = PackedInt32Array(Setup.rectangles(setup).runs)
	else: options.workbench_generated = Store.native_packet(Store.provenance(packet),packet.cells,setup.edits)
	var token: int = bridge.prepare_liquid_world(world,runs,checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),
		PackedInt32Array(setup.liquid_policy),options)
	if not check(token > 0,"native saved-start preparation / "+str(bridge.get_last_error())): return
	if not check(bridge.commit_liquid_world(world,token),"native saved-start commit"): return
	var expected := reference(setup,packet)
	for y: int in range(196,217):
		for x: int in range(196,217):
			var actual: Dictionary = bridge.inspect_cell(world,Vector2i(x,y))
			check(actual.get("ok",false) and int(actual.get("material",-1)) == expected[y*512+x],
				"native stored material at %d/%d" % [x,y])
	if not packet.is_empty():
		var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
		check(receipt.get("generated_prepared_material_sha256","") == Store.digest(expected),
			"all 262144 native stored IDs match original generation plus exact edits")
		check(receipt.get("generated_source_sha256","") == packet.sha256,"native preserves GEN source identity")
	check(world.get_tick_index() == 0,"saved authored start has not claimed evolved simulation")


func controls(base: Dictionary, packet: Dictionary) -> void:
	var cells := mixed_cells()
	var stamps: Dictionary = History.stamps(cells,EXTENT)
	check(stamps.accepted and stamps.stamps.size() == 8 and stamps.stamps[0] == [200,200,1,8,0],
		"mixed material strips coalesce vertically and preserve Empty")
	for invalid: PackedInt32Array in [PackedInt32Array(),PackedInt32Array([1,2]),
			PackedInt32Array([200,200,58,200,200,0]),PackedInt32Array([201,200,58,200,200,0]),
			PackedInt32Array([-1,2,58]),PackedInt32Array([512,2,58]),
			PackedInt32Array([1,2,10]),PackedInt32Array([1,2,132]),PackedInt32Array([1,2,256])]:
		var before: Dictionary = base.duplicate(true)
		check(not History.prepare(base,invalid).accepted and base == before,"invalid plan refuses without authoring mutation")
	var oversized := PackedInt32Array()
	oversized.resize((History.MAX_CELLS+1)*3)
	check(not History.prepare(base,oversized).accepted,"operation cell overflow refuses before raster work")
	var detail := PackedInt32Array()
	for index: int in 4097:
		detail.append_array(PackedInt32Array([index%512,index/512,2 if (index+index/512)%2 else 58]))
	check(not History.prepare(base,detail).accepted,"unpersistable detailed operation refuses before native queue")
	var split_base := base.duplicate(true)
	var split_cells := PackedInt32Array()
	for index: int in 1500:
		var x := (index%128)*4
		var y := (index/128)*2
		split_base.edits.append([x,y,3,1,58])
		split_cells.append_array(PackedInt32Array([x+1,y,2]))
	check(not History.prepare(split_base,split_cells).accepted,
		"overlapping stamps that split into 4500 native rectangles refuse before queue")
	var full := base.duplicate(true)
	full.edits = []
	for index: int in Setup.MAX_STAMPS: full.edits.append([200,200,1,1,58])
	check(not History.prepare(full,cells,packet).accepted,"generated edit capacity refuses without dropping erasure")
	var squeezed: Dictionary = History.prepare(full,cells)
	check(squeezed.accepted and squeezed.setup.edits.size() == 7,
		"ordinary blank-baseline compaction safely frees old history")
	var changed_source := packet.duplicate(true)
	changed_source.cells[0] = 0 if changed_source.cells[0] else 58
	check(not History.prepare(base,cells,changed_source).accepted,"changed generated source refuses")
	var original := base.duplicate(true)
	var result: Dictionary = History.prepare(base,cells,packet)
	check(result.accepted and base == original,"candidate preparation never changes original authored setup")
	if result.accepted:
		check(result.setup.actors == base.actors and result.setup.liquid_policy == base.liquid_policy \
			and result.setup.response == base.response and result.setup.source == base.source,
			"actors, solver policy, source and response survive preparation")
	var prefix: Dictionary = History.prepare(base,cells.slice(0,15),packet)
	check(prefix.accepted and prefix.cell_count == 5 and prefix.stamps.size() == 5,
		"partial ACK prefix represents exactly its five confirmed cells")
	var large := PackedInt32Array()
	large.resize(512*512*3)
	for index: int in 512*512:
		large[index*3] = index%512
		large[index*3+1] = index/512
		large[index*3+2] = 58
	var started := Time.get_ticks_usec()
	var maximum: Dictionary = History.prepare(Setup.fresh(bridge.default_liquid_policy(),EXTENT),large)
	var elapsed := Time.get_ticks_usec()-started
	check(maximum.accepted and maximum.stamps == [[0,0,512,512,58]],"262144-cell rectangle persists as one exact box")
	print("PAINT_EDITOR_HISTORY_PERF cells=262144 prepare_usec=",elapsed)


func run() -> void:
	if not check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge") \
			and ClassDB.class_exists(&"CyberWorldGenerator"),"actual native interfaces loaded"):
		quit(1)
		return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	checked = Contract.validate(Contract.parse(FileAccess.get_file_as_string(
		"res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json")).definition)
	var reopened := OS.get_environment("CYBERSAND_PAINT_HISTORY_REOPEN") == "1"
	if reopened:
		var ordinary: Dictionary = Setup.read_named(LABEL)
		var saved: Dictionary = Store.read_named(LABEL+"-generated")
		if check(ordinary.has("setup") and saved.get("generated",false),"fresh process reads both saved formats"):
			var packet := generated(saved.generation.recipe)
			check(Store.provenance(packet) == saved.generation,"fresh native regeneration matches all persisted identities")
			verify_native(ordinary.setup)
			verify_native(saved.setup,packet)
			check(saved.setup.actors.size() == 1 and saved.setup.selected == 1 \
				and saved.setup.actors[0].spawn == [440.0,40.0],"fresh process retains actor identity and authored spawn")
	else:
		var packet := generated(recipe())
		var base := Setup.fresh(bridge.default_liquid_policy(),EXTENT)
		base.actors = [Setup.instance(Setup.BARREL,1,Vector2(440,40))]
		base.next_id = 2
		base.selected = 1
		base.source = [20,20,2]
		controls(base,packet)
		var ordinary: Dictionary = History.prepare(base,mixed_cells())
		var generated_start: Dictionary = History.prepare(base,mixed_cells(),packet)
		if check(ordinary.accepted and generated_start.accepted,"both saved-start candidates admitted"):
			check(Setup.write_named(LABEL,ordinary.setup).is_empty(),"atomic ordinary Setup-v2 save")
			check(Store.write_named(LABEL+"-generated",generated_start.setup,packet).is_empty(),"atomic generated-start v1 save")
			verify_native(ordinary.setup)
			verify_native(generated_start.setup,packet)
	print("PAINT_EDITOR_HISTORY checks=",checks," failures=",failures," reopened=",reopened)
	quit(1 if failures else 0)
