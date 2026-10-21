extends SceneTree

# Independent full-map acceptance: final material route clearance, owned feature
# counts, regional four-plane treatment and exact whole/tile/worker parity.
const Data = preload("res://scripts/worldgen_qualification_data.gd")
const PLANES: Array[String] = ["play","scripted","effects","background"]
var assertions: int = 0
var failures: int = 0
var records: Array[Dictionary] = []
var completed: Array[String] = []
var baseline: Dictionary = {}
var baseline_generator: Object
var began: int = 0

func _init() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("GEN007_QUALIFICATION: " + message)

func _run() -> void:
	began = Time.get_ticks_usec()
	_expect(ClassDB.class_exists(&"CyberWorldGenerator"),"Native generator is required")
	if failures:
		_finish()
		return
	var first_ids: Array = []
	var distinct: Dictionary = {}
	var distinct_layouts: Dictionary = {}
	for seed: int in Data.SEEDS:
		var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
		var start: int = Time.get_ticks_usec()
		var configured: Dictionary = generator.configure(Data.recipe(seed))
		_expect(configured.get("ok",false),"Seed %d configures: %s" % [seed,configured.get("error","")])
		if not configured.get("ok",false): continue
		var whole: Dictionary = generator.generate_plane_bundle()
		var ms: float = float(Time.get_ticks_usec()-start)/1000.0
		_expect(whole.get("ok",false) and whole.get("complete",false),"Seed %d native complete proposal: %s" % [seed,whole.get("error","")])
		if not whole.get("ok",false): continue
		var structural: Dictionary = Data.structural_receipt(whole,generator.get_semantic_plan())
		_expect(structural.get("complete",false) and structural.get("ok",false),"Seed %d independent structural oracle: %s" % [seed,structural.get("errors",[])])
		_expect(whole.operations <= 4000000000,"Declared full-map work bound respected")
		_expect(whole.storage_bytes <= whole.budgets.max_prepared_bytes,"Native prepared storage respects its declared cap")
		for plane: String in PLANES:
			_expect(whole.materials[plane].size() == 1048576,"Exactly 1024x1024 on " + plane)
			_expect(whole.layers[plane].size() / 5 <= 4096,"Bounded host rectangles for " + plane)
		if first_ids.is_empty(): first_ids = structural.stable_ids
		else: _expect(structural.stable_ids == first_ids,"Stable feature IDs survive seed variation")
		distinct[whole.hashes.play] = true
		var cabinet_layout: Array = []
		for cabinet: Dictionary in Data.tagged(whole,"service-cabinet"): cabinet_layout.append({"id":cabinet.id,"bounds":cabinet.bounds})
		distinct_layouts[Data.digest(var_to_bytes(cabinet_layout))] = true
		var tiled_receipt: Variant = _tiled(generator,whole,128,true)
		_expect(tiled_receipt is Dictionary and tiled_receipt.get("complete",false),"Every reverse tile oracle completed for this seed")
		if seed == Data.SEEDS[0]:
			baseline = whole
			baseline_generator = generator
			var alternate_receipt: Variant = _tiled(generator,whole,256,false)
			_expect(alternate_receipt is Dictionary and alternate_receipt.get("complete",false),"Alternate partition oracle explicitly completed")
			records.append({"seed":seed,"revision":whole.revision,"hashes":whole.hashes,"generation_ms":ms,"structure":structural,"cabinet_layout":cabinet_layout,"native_storage_bytes":whole.storage_bytes,"native_limits":whole.budgets,"native_spatial_index":whole.spatial_index,"complete":true})
		else:
			records.append({"seed":seed,"revision":whole.revision,"hashes":whole.hashes,"generation_ms":ms,"structure":structural,"cabinet_layout":cabinet_layout,"native_storage_bytes":whole.storage_bytes,"native_limits":whole.budgets,"native_spatial_index":whole.spatial_index,"complete":true})
		completed.append("seed-%d"%seed)
		print("GEN007_SEED: seed=%d; structural_ok=%s; route_centres=%d; connected_loops=%d; generation_ms=%.3f; complete=true"%[seed,structural.ok,structural.routes.checked_centres,structural.routes.connected_optional_loops,ms])
	_expect(records.size() == 4,"Reference plus three declared seed helpers completed")
	_expect(distinct.size() == 4,"All four seeds produce distinct actual material content")
	_expect(distinct_layouts.size() >= 2,"Native route preference changes actual cabinet placement across declared seeds")
	if not baseline.is_empty():
		_parallel_workers()
		_budget_slices()
		_negative_controls()
	_expect(completed.size() == 7,"All seven independent qualification sections completed")
	_finish()

func _tiled(generator: Object, whole: Dictionary, side: int, reverse: bool) -> Dictionary:
	var requests: Array[Rect2i] = []
	for y: int in range(0,1024,side):
		for x: int in range(0,1024,side): requests.append(Rect2i(x,y,side,side))
	if reverse: requests.reverse()
	var reconstructed: Dictionary = {}
	var fixture_ids: Dictionary = {}
	var link_ids: Dictionary = {}
	var expected_fixtures: Dictionary = _records_by_id(whole.fixtures)
	var expected_links: Dictionary = _records_by_id(whole.links)
	for plane: String in PLANES:
		var bytes := PackedByteArray()
		bytes.resize(1048576)
		reconstructed[plane] = bytes
	var tiles: int = 0
	for bounds: Rect2i in requests:
		var tile: Dictionary = generator.generate_plane_region(bounds)
		_expect(tile.get("ok",false),"Independent native tile: " + str(tile.get("error","")))
		if not tile.get("ok",false): continue
		_expect(tile.fingerprint == whole.fingerprint,"Tile proposal identifies same accepted plan")
		var plan: Dictionary = generator.get_plane_plan()
		_expect(plan.features == whole.features and plan.projections == whole.projections,"Every tile retains exact semantic and projection records")
		var fixtures: Dictionary = _records_by_id(plan.fixtures)
		var links: Dictionary = _records_by_id(plan.links)
		_copy_tile(tile,reconstructed)
		for id: String in tile.fixture_ids:
			_expect(not fixture_ids.has(id),"Exactly one tile owns fixture " + id)
			_expect(fixtures.get(id,{}) == expected_fixtures.get(id,{}) and fixtures.has(id),"Tile-owned native fixture record matches whole-map record")
			fixture_ids[id] = fixtures.get(id,{})
		for id: String in tile.link_ids:
			_expect(not link_ids.has(id),"Exactly one tile owns link " + id)
			_expect(links.get(id,{}) == expected_links.get(id,{}) and links.has(id),"Tile-owned native link record matches whole-map record")
			link_ids[id] = links.get(id,{})
		tiles += 1
	for plane: String in PLANES: _expect(reconstructed[plane] == whole.materials[plane],"Whole/tiled exact material parity: " + plane)
	_expect(tiles == requests.size(),"Every requested tile completed")
	_expect(fixture_ids.size() == whole.fixtures.size() and link_ids.size() == whole.links.size(),"Complete registration union under request reordering")
	_expect(fixture_ids == expected_fixtures and link_ids == expected_links,"Whole/tiled exact normalized fixture and link record parity")
	return {"complete":tiles == requests.size(),"tiles":tiles}

func _records_by_id(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Dictionary in values: result[value.id] = value
	return result

func _copy_tile(tile: Dictionary, target: Dictionary) -> void:
	var bounds: Rect2i = tile.bounds
	for plane: String in PLANES:
		var source: PackedByteArray = tile.materials[plane]
		var destination: PackedByteArray = target[plane]
		for y: int in range(bounds.size.y):
			for x: int in range(bounds.size.x): destination[(bounds.position.y+y)*1024+bounds.position.x+x] = source[y*bounds.size.x+x]
		target[plane] = destination

func _worker(seed: int, bounds: Rect2i) -> Dictionary:
	# Each worker exclusively owns its adapter; no live World, renderer or scene
	# object crosses threads. The copied recipe is independently compiled.
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = generator.configure(Data.recipe(seed))
	if not configured.get("ok",false): return configured
	var result: Dictionary = generator.generate_plane_region(bounds)
	result["features"] = generator.get_plane_plan().get("features",[])
	result["fixtures"] = generator.get_plane_plan().get("fixtures",[])
	result["links"] = generator.get_plane_plan().get("links",[])
	result["projections"] = generator.get_plane_plan().get("projections",[])
	return result

func _parallel_workers() -> void:
	var threads: Array[Thread] = []
	for index: int in range(4):
		var thread := Thread.new()
		var rect := Rect2i((index%2)*512,(index/2)*512,512,512)
		_expect(thread.start(_worker.bind(Data.SEEDS[0],rect)) == OK,"Independent generation worker starts")
		threads.append(thread)
	var target: Dictionary = {}
	for plane: String in PLANES:
		var bytes := PackedByteArray()
		bytes.resize(1048576)
		target[plane] = bytes
	var finished: int = 0
	for thread: Thread in threads:
		if not thread.is_started(): continue
		var result: Dictionary = thread.wait_to_finish()
		_expect(result.get("ok",false),"Native worker generation completes")
		if not result.get("ok",false): continue
		_expect(result.features == baseline.features and result.fixtures == baseline.fixtures and result.links == baseline.links and result.projections == baseline.projections,"Workers reproduce exact semantic, projection, fixture and link records")
		_copy_tile(result,target)
		finished += 1
	for plane: String in PLANES: _expect(target[plane] == baseline.materials[plane],"One/four independent worker material parity on " + plane)
	_expect(finished == 4,"All four worker helpers returned")
	if finished == 4: completed.append("workers")

func _budget_slices() -> void:
	var bounds := Rect2i(450,100,128,128)
	var direct: Dictionary = baseline_generator.generate_plane_region(bounds)
	for budget: int in [31,4096]:
		var pending: Dictionary = baseline_generator.begin_plane_region(bounds)
		var slices: int = 0
		while pending.get("ok",false) and pending.get("state","") == "running" and slices < 600:
			pending = baseline_generator.advance_plane_region(budget)
			slices += 1
		_expect(pending.get("ok",false) and pending.get("state","") == "ready","Bounded budget %d completes"%budget)
		_expect(pending.get("materials",{}) == direct.get("materials",{}),"Budget slicing preserves every plane byte")
		_expect(pending.get("fixture_ids",[]) == direct.get("fixture_ids",[]),"Budget slicing preserves registration records")
		_expect(pending.get("link_ids",[]) == direct.get("link_ids",[]),"Budget slicing preserves owned link records")
	completed.append("budgets")

func _negative_controls() -> void:
	var fingerprint: String = baseline_generator.get_plane_plan().fingerprint
	var exhausted: Dictionary = Data.recipe()
	exhausted.semantic_planes.limits.max_operations = 1
	var rejected: Dictionary = baseline_generator.configure(exhausted)
	_expect(not rejected.get("ok",true),"Exhausted generation budget rejects")
	_expect(baseline_generator.get_plane_plan().fingerprint == fingerprint,"Failed budget edit preserves previous accepted plan")
	var blocked: Dictionary = Data.recipe()
	blocked["overrides"] = [{"id":"negative-route-block","bounds":[508,508,9,9],"material":1,"priority":100}]
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = generator.configure(blocked)
	_expect(configured.get("ok",false),"Authored blocking hard override is retained and inspectable")
	if configured.get("ok",false):
		var generated: Dictionary = generator.generate_plane_bundle()
		_expect(generated.get("ok",false),"Blocking override still produces an honest material proposal")
		if generated.get("ok",false):
			var receipt: Dictionary = Data.route_receipt(generated,generator.get_semantic_plan())
			_expect(not receipt.ok and receipt.blocked_centres > 0,"Independent post-override clearance control fails")
			_expect(generated.materials.play[512*1024+512] == 1,"Final override remains authoritative")
	completed.append("negative-controls")

func _finish() -> void:
	var path: String = OS.get_environment("CYBERSAND_GEN007_QUALIFICATION_REPORT")
	var report: Dictionary = {"schema":1,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"recipe_sha256":FileAccess.get_sha256(Data.RECIPE),"assertions":assertions,"failures":failures,
		"completed":completed,"records":records,"elapsed_ms":float(Time.get_ticks_usec()-began)/1000.0,
		"engine":Engine.get_version_info(),"os":OS.get_name(),
		"godot_static_peak_bytes":OS.get_static_memory_peak_usage(),
		"memory_scope":"Godot static allocation peak only; native/process peak RSS is recorded by the process wrapper"}
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		_expect(file != null,"Requested qualification report writable")
		if file != null:
			report.assertions = assertions
			report.failures = failures
			file.store_string(JSON.stringify(report,"\t",true,true)+"\n")
	print("GEN007_QUALIFICATION: %d assertions; %d failures; completed=%s"%[assertions,failures,completed])
	quit(1 if failures else 0)
