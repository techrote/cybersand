extends SceneTree

# All eight authored helpers must return an explicit mechanism receipt. Native
# transport/reaction produces products; neither a painted product nor an aborted
# helper nor a disabled/no-op feed can satisfy this oracle.
const Data = preload("res://scripts/worldgen_qualification_data.gd")
const Runtime = preload("res://scripts/depth/semantic_plane_runtime.gd")
const TICKS: int = 220
var assertions: int = 0
var failures: int = 0
var verified_exhibits: int = 0
var records: Dictionary = {}
var controls: Dictionary = {}
var complete_sections: Array[String] = []
var elapsed_start: int = 0

func _init() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("GEN007_REACTIONS: "+message)

func _run() -> void:
	elapsed_start = Time.get_ticks_usec()
	var recipe: Dictionary = Data.recipe()
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = generator.configure(recipe)
	_expect(configured.get("ok",false),"Qualification scene configures: "+str(configured.get("error","")))
	if not configured.get("ok",false):
		_finish()
		return
	var bundle: Dictionary = generator.generate_plane_bundle()
	_expect(bundle.get("ok",false),"Complete native generation: "+str(bundle.get("error","")))
	if not bundle.get("ok",false):
		_finish()
		return
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	_expect(runtime.install_bundle(bundle),"Complete real host installation: "+runtime.last_error)
	if runtime.generation() == 0:
		_finish()
		return
	_expect(bundle.fixtures.size() == 8,"Eight separately owned play/rear apparatus feeds")
	var metadata: Dictionary = {}
	for item: Dictionary in Data.manifest().exhibits: metadata[item.rule] = item
	var features: Dictionary = Data.feature_map(bundle)
	var original: Dictionary = {}
	for plane: String in Data.PLANES: original[plane] = runtime.snapshot_layer(plane,true).cells
	for fixture: Dictionary in bundle.fixtures:
		var feature: Dictionary = features[fixture.feature_id]
		var spec: Dictionary = metadata[feature.rule_id]
		var vessel: Rect2i = Data.vessel_bounds(feature,fixture.plane)
		var scan: Dictionary = _scan(original[fixture.plane],vessel,int(spec.product),int(spec.feed),int(spec.substrate))
		records[fixture.id] = {"fixture_id":fixture.id,"feature_id":feature.id,"plane":fixture.plane,
			"title":spec.title,"bounds":vessel,"product":int(spec.product),"feed":int(spec.feed),"substrate":int(spec.substrate),
			"initial":scan,"max_product":scan.product,"max_transport":scan.transport,"min_substrate":scan.substrate,
			"completed":false,"oracle_assertions":0,"verified":false}
	_expect(runtime.configure_rates({"play":0,"scripted":20,"effects":0}),"Rear clock isolated")
	var rear_receipt: Variant = _run_ticks(runtime,"scripted",records)
	_expect(rear_receipt is Dictionary and rear_receipt.get("complete",false),"Rear helper explicitly completed every tick and observation")
	for plane: String in ["play","effects","background"]:
		_expect(runtime.snapshot_layer(plane,true).cells == original[plane],"Rear reaction preserves complete "+plane+" material state")
	var frozen_rear: PackedByteArray = runtime.snapshot_layer("scripted",true).cells
	_expect(runtime.configure_rates({"play":30,"scripted":0,"effects":0}),"Play clock isolated")
	var play_receipt: Variant = _run_ticks(runtime,"play",records)
	_expect(play_receipt is Dictionary and play_receipt.get("complete",false),"Play helper explicitly completed every tick and observation")
	_expect(runtime.snapshot_layer("scripted",true).cells == frozen_rear,"Play reactions cannot modify rear native World")
	_expect(runtime.layer_tick("background") == 0,"Far plane remains frozen")
	var ledger: Dictionary = runtime.lifecycle_stats()
	var expected_applications: int = 0
	var expected_writes: int = 0
	for fixture: Dictionary in bundle.fixtures:
		var before: int = assertions
		var errors_before: int = failures
		var record: Dictionary = records[fixture.id]
		var state: Dictionary = ledger.fixtures[fixture.id]
		_expect(record.initial.product == 0,"Product absent at generation: "+fixture.id)
		_expect(record.product != fixture.material,"Expected product is never a supplied reagent: "+fixture.id)
		_expect(record.max_product > 0,"Native product actually observed: "+fixture.id)
		_expect(record.min_substrate < record.initial.substrate,"Native substrate actually consumed: "+fixture.id)
		if record.feed != 6:
			_expect(record.max_transport > record.initial.transport,"Reagent transported below its source before contact: "+fixture.id)
		_expect(state.fired == fixture.repeat and state.retired,"Every finite feed application completed: "+fixture.id)
		expected_applications += fixture.repeat
		expected_writes += fixture.repeat*fixture.bounds.size.x*fixture.bounds.size.y
		record["applications"] = state.fired
		record["completed"] = true
		record["oracle_assertions"] = assertions-before
		record["verified"] = failures == errors_before and record.oracle_assertions >= 5
		_expect(_meaningful(record),"Explicit complete mechanism receipt: "+fixture.id)
		if _meaningful(record): verified_exhibits += 1
		print("GEN007_EXHIBIT: id=%s; plane=%s; product_peak=%d; substrate_initial=%d; substrate_minimum=%d; applications=%d; complete=%s; verified=%s"%[fixture.id,fixture.plane,record.max_product,record.initial.substrate,record.min_substrate,state.fired,record.completed,record.verified])
	_expect(ledger.applications == expected_applications and ledger.fixture_cell_writes == expected_writes,"Full fixture write/accounting totals match declaration")
	_expect(verified_exhibits == 8,"All eight apparatus oracles returned, including any helper script errors")
	complete_sections.append("native-pairs")
	# Deterministic controls retain the same complete geometry and owners.
	_run_control(recipe,"no-feed",records)
	_run_control(recipe,"missing-partner",records)
	var no_op: Dictionary = records.values()[0].duplicate(true)
	no_op.max_product = 0
	_expect(not _meaningful(no_op),"No-op helper is a failed mechanism receipt")
	var aborted: Dictionary = records.values()[0].duplicate(true)
	aborted.completed = false
	_expect(not _meaningful(aborted),"Aborted helper is a failed mechanism receipt")
	_expect(complete_sections.size() == 3 and controls.size() == 2,"All positive and negative helper sections completed")
	_finish()

func _meaningful(record: Dictionary) -> bool:
	return bool(record.get("completed",false)) and bool(record.get("verified",false)) and int(record.get("oracle_assertions",0)) >= 5 and int(record.get("max_product",0)) > 0

func _run_ticks(runtime: CyberSemanticPlaneRuntime, plane: String, observed: Dictionary) -> Dictionary:
	for tick: int in range(1,TICKS+1):
		var result: Dictionary = runtime.step_once()
		_expect(result.get("ok",false),"Native "+plane+" step "+str(tick))
		if not result.get("ok",false): return {}
		if tick % 2 == 0:
			var packet: Dictionary = runtime.snapshot_layer(plane,true)
			_expect(not packet.get("failed",false) and packet.get("cells",PackedByteArray()).size() == 2097152,"Complete independent native observation")
			if packet.get("failed",false): return {}
			for record: Dictionary in observed.values():
				if record.plane != plane: continue
				var scan: Dictionary = _scan(packet.cells,record.bounds,record.product,record.feed,record.substrate)
				record.max_product = maxi(record.max_product,scan.product)
				record.max_transport = maxi(record.max_transport,scan.transport)
				record.min_substrate = mini(record.min_substrate,scan.substrate)
	_expect(runtime.layer_tick(plane) == TICKS,"Entire native clock run completed: "+plane)
	print("GEN007_REACTION_STAGE: plane=%s; ticks=%d; complete=%s"%[plane,runtime.layer_tick(plane),runtime.layer_tick(plane) == TICKS])
	return {"complete":runtime.layer_tick(plane) == TICKS,"ticks":runtime.layer_tick(plane)}

func _run_control(original: Dictionary, label: String, positive: Dictionary) -> void:
	var recipe: Dictionary = original.duplicate(true)
	if label == "no-feed": recipe.semantic_planes.fixtures = []
	else:
		for projection: Dictionary in recipe.semantic_planes.projections:
			if str(projection.id).ends_with("-specimen"): projection.material = 0
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = generator.configure(recipe)
	_expect(configured.get("ok",false),label+" control configures")
	if not configured.get("ok",false): return
	var bundle: Dictionary = generator.generate_plane_bundle()
	_expect(bundle.get("ok",false),label+" complete generation")
	if not bundle.get("ok",false): return
	var runtime: CyberSemanticPlaneRuntime = Runtime.new()
	_expect(runtime.install_bundle(bundle),label+" complete installation")
	if runtime.generation() == 0: return
	_expect(runtime.configure_rates({"play":30,"scripted":20,"effects":0}),label+" independent native clocks")
	var maximum: Dictionary = {}
	for id: String in positive: maximum[id] = 0
	for tick: int in range(1,TICKS+1):
		var result: Dictionary = runtime.step_once()
		_expect(result.get("ok",false),label+" native tick "+str(tick))
		if not result.get("ok",false): return
		if tick % 4 == 0:
			for plane: String in ["play","scripted"]:
				var packet: Dictionary = runtime.snapshot_layer(plane,true)
				_expect(not packet.get("failed",false),label+" native packet")
				for id: String in positive:
					var record: Dictionary = positive[id]
					if record.plane != plane: continue
					maximum[id] = maxi(maximum[id],_scan(packet.cells,record.bounds,record.product,record.feed,record.substrate).product)
	var count: int = 0
	for id: String in maximum:
		_expect(maximum[id] == 0,label+" produces no claimed product in "+id)
		count += 1
	_expect(count == 8,label+" checks every authored apparatus independently")
	controls[label] = {"complete":true,"observed_exhibits":count,"maximum_products":maximum,"ticks":TICKS}
	complete_sections.append(label)

func _scan(bytes: PackedByteArray, bounds: Rect2i, product: int, feed: int, substrate: int) -> Dictionary:
	var result: Dictionary = {"product":0,"feed":0,"substrate":0,"transport":0}
	if bytes.size() != 2097152: return result
	for y: int in range(bounds.position.y,bounds.end.y):
		for x: int in range(bounds.position.x,bounds.end.x):
			var material: int = bytes[(y*1024+x)*2]
			if material == product: result.product += 1
			if material == feed:
				result.feed += 1
				if y >= bounds.position.y+16: result.transport += 1
			if material == substrate: result.substrate += 1
	return result

func _finish() -> void:
	var report: Dictionary = {"schema":1,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"recipe_sha256":FileAccess.get_sha256(Data.RECIPE),"assertions":assertions,"failures":failures,
		"verified_exhibits":verified_exhibits,"records":records,"controls":controls,"completed":complete_sections,
		"ticks_per_active_plane":TICKS,"elapsed_ms":float(Time.get_ticks_usec()-elapsed_start)/1000.0}
	var destination: String = OS.get_environment("CYBERSAND_GEN007_REACTIONS_REPORT")
	if not destination.is_empty():
		var output := FileAccess.open(destination,FileAccess.WRITE)
		_expect(output != null,"Requested reaction report writable")
		if output != null:
			report.assertions = assertions
			report.failures = failures
			output.store_string(JSON.stringify(report,"\t",true,true)+"\n")
	print("GEN007_REACTIONS: %d assertions; %d failures; verified_exhibits=%d; completed=%s"%[assertions,failures,verified_exhibits,complete_sections])
	quit(1 if failures else 0)
