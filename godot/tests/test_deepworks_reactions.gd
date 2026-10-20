extends SceneTree

# Exercise the actual full composition and its production tick-boundary source
# scheduler. Observations read only copied native RG8 packets. Source admission
# is not accepted as a reaction, and transport is checked away from the feeds.
const Map = preload("res://scripts/exhibition/deepworks_map.gd")
const Runtime = preload("res://scripts/exhibition/deepworks_runtime.gd")
const Cell = preload("res://scripts/cell_world.gd")
const TICKS: int = 360
const PLANES: Array[String] = ["play", "scripted"]

var assertions: int = 0
var failures: int = 0
var records: Dictionary = {}
var started_us: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("DEEPWORKS_REACTIONS: " + message)


func _run() -> void:
	started_us = Time.get_ticks_usec()
	var recipe: Dictionary = Map.build()
	var runtime: CyberDeepworksRuntime = Runtime.new()
	_expect(runtime.install(recipe["layers"], recipe["events"]), "Full map installation: " + runtime.last_error)
	if failures > 0:
		_finish({})
		return
	_expect(runtime.configure_rates({"play": 30.0, "scripted": 20.0, "effects": 20.0}), "Dynamic plane rates")
	_expect(recipe["exhibits"].size() == 32, "All thirty-two apparatus records participate")
	_observe(runtime, recipe, 0)
	for tick: int in range(1, TICKS + 1):
		var step: Dictionary = runtime.step_once()
		_expect(bool(step.get("ok", false)), "Native step %d" % tick)
		if not bool(step.get("ok", false)):
			break
		# Early samples retain fleeting ignition/quench products. Later samples
		# retain weathering, flow, growth and cure without hashing whole Worlds.
		if (tick <= 120 and tick % 12 == 0) or (tick > 120 and tick % 24 == 0):
			_observe(runtime, recipe, tick)
	var event_stats: Dictionary = runtime.event_stats()
	for plane: String in PLANES:
		_expect(runtime.layer_tick(plane) == TICKS, plane + " completed all native ticks")
	_expect(runtime.layer_tick("background") == 0, "Distant background remains frozen")
	for exhibit: Dictionary in recipe["exhibits"]:
		_verify_exhibit(exhibit, recipe["events"], event_stats)
	# A helper script error can return control to its caller without recording
	# an assertion failure. Every distinct authored apparatus must finish its
	# own oracle before a standalone run or its evidence can report success.
	_expect(records.size() == 32, "Thirty-two unique apparatus observations")
	var verified_exhibits: int = 0
	for district: int in range(16):
		for plane: String in PLANES:
			var id: String = "deepworks-%02d-%s" % [district, plane]
			var record: Dictionary = records.get(id, {})
			var verified: bool = bool(record.get("verified", false)) and bool(record.get("oracle_completed", false)) and int(record.get("oracle_assertions", 0)) > 0
			_expect(verified, id + " completed and passed its mechanism oracle")
			if verified:
				verified_exhibits += 1
	_finish({"recipe_sha256": Map.recipe_hash(recipe), "ticks_per_dynamic_plane": TICKS,
		"event_applications": event_stats.get("applications", 0),
		"verified_exhibit_count": verified_exhibits, "exhibits": records})


func _observe(runtime: CyberDeepworksRuntime, recipe: Dictionary, tick: int) -> void:
	for plane: String in PLANES:
		var packet: Dictionary = runtime.snapshot_layer(plane, true)
		var cells: PackedByteArray = packet.get("cells", PackedByteArray())
		_expect(not bool(packet.get("failed", false)) and cells.size() == 2097152,
			"Complete copied %s RG8 packet at tick %d" % [plane, tick])
		if cells.size() != 2097152:
			continue
		for exhibit: Dictionary in recipe["exhibits"]:
			if exhibit["layer"] != plane:
				continue
			var scan: Dictionary = _scan(exhibit, cells)
			if tick == 0:
				records[exhibit["id"]] = {
					"title": exhibit["title"], "layer": plane,
					"mechanism": exhibit["mechanism"],
					"initial": scan["counts"].duplicate(),
					"minimum": scan["counts"].duplicate(),
					"maximum": scan["counts"].duplicate(),
					"lower_maximum": scan["lower"].duplicate(),
					"first_new": {}, "final_mean_y": scan["mean_y"],
					"verified": false, "oracle_completed": false, "oracle_assertions": 0,
				}
				continue
			var record: Dictionary = records[exhibit["id"]]
			for material: int in range(132):
				record["maximum"][material] = maxi(record["maximum"][material], scan["counts"][material])
				record["minimum"][material] = mini(record["minimum"][material], scan["counts"][material])
				record["lower_maximum"][material] = maxi(record["lower_maximum"][material], scan["lower"][material])
				if record["initial"][material] == 0 and scan["counts"][material] > 0 and not record["first_new"].has(material):
					record["first_new"][material] = tick
			record["final_mean_y"] = scan["mean_y"]


func _scan(exhibit: Dictionary, cells: PackedByteArray) -> Dictionary:
	var counts := PackedInt32Array()
	var lower := PackedInt32Array()
	var sum_y := PackedInt32Array()
	var mean_y := PackedFloat32Array()
	counts.resize(132)
	lower.resize(132)
	sum_y.resize(132)
	mean_y.resize(132)
	var rect: Rect2i = exhibit["observation"]
	var district_y: int = (int(exhibit["district"]) >> 2) * 256
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var material: int = cells[(y * 1024 + x) * 2]
			if material >= 132 or material == 10:
				_expect(false, "Invalid native material in copied exhibit packet")
				continue
			counts[material] += 1
			sum_y[material] += y - district_y
			if y - district_y >= 143:
				lower[material] += 1
	for material: int in range(132):
		mean_y[material] = float(sum_y[material]) / float(counts[material]) if counts[material] > 0 else -1.0
	return {"counts": counts, "lower": lower, "mean_y": mean_y}


func _verify_exhibit(exhibit: Dictionary, events: Array, event_stats: Dictionary) -> void:
	var id: String = exhibit["id"]
	_expect(records.has(id), id + " has native observations")
	if not records.has(id):
		return
	var before_failures: int = failures
	var record: Dictionary = records[id]
	var source_materials: Dictionary = {}
	var direct_writes: Dictionary = {}
	var source_count: int = 0
	for event: Dictionary in events:
		if event["district"] != exhibit["district"] or event["layer"] != exhibit["layer"]:
			continue
		var material: int = event["material"]
		if material == Cell.EMPTY:
			continue
		source_materials[material] = true
		var fired: int = int(event_stats["fired"].get(event["id"], 0))
		var rect: Rect2i = event["rect"]
		direct_writes[material] = int(direct_writes.get(material, 0)) + fired * rect.size.x * rect.size.y
		source_count += fired
	_expect(source_count > 0, id + " has fired its production reactant source")
	var mechanism: String = exhibit["mechanism"]
	var before_oracle_assertions: int = assertions
	var oracle_completed: bool = false
	match mechanism:
		"flow":
			oracle_completed = _check_flow(exhibit, record)
		"purification":
			_expect(record["initial"][Cell.TOXIC_SLUDGE] > 100, id + " starts with a real sludge bed")
			_expect(record["minimum"][Cell.TOXIC_SLUDGE] < record["initial"][Cell.TOXIC_SLUDGE] / 4,
				id + " removes most sludge rather than merely painting Water beside it")
			_expect(record["maximum"][Cell.WATER] > 100, id + " publishes the resulting Water reservoir")
			oracle_completed = true
		"growth":
			if exhibit["layer"] == "scripted":
				var initial_wood: int = record["initial"][Cell.WOOD] + record["initial"][Cell.OAK_TIMBER]
				var remaining_wood: int = record["minimum"][Cell.WOOD] + record["minimum"][Cell.OAK_TIMBER]
				_expect(remaining_wood < initial_wood, id + " consumes the actual old timber substrate")
				_expect(record["maximum"][Cell.FUNGUS] > record["initial"][Cell.FUNGUS] + int(direct_writes.get(Cell.FUNGUS, 0)),
					id + " grows more Fungus than all directly injected cells")
				oracle_completed = true
			else:
				oracle_completed = _check_products(id, exhibit, record, source_materials)
		"combustion":
			oracle_completed = _check_products(id, exhibit, record, source_materials)
			var initial_fuel: int = 0
			var minimum_fuel: int = 0
			for material: int in [Cell.PINE_PLANKS, Cell.CARDBOARD, Cell.BAMBOO, Cell.PLYWOOD]:
				initial_fuel += record["initial"][material]
				minimum_fuel += record["minimum"][material]
			_expect(minimum_fuel < initial_fuel, id + " consumes combustible specimens")
		"reaction", "charge", "curing":
			oracle_completed = _check_products(id, exhibit, record, source_materials)
		_:
			_expect(false, id + " needs an explicit mechanism-specific oracle")
	record["oracle_completed"] = oracle_completed
	record["oracle_assertions"] = assertions - before_oracle_assertions
	_expect(oracle_completed, id + " mechanism helper returned its completion receipt")
	_expect(record["oracle_assertions"] > 0, id + " executed mechanism assertions")
	record["verified"] = oracle_completed and record["oracle_assertions"] > 0 and before_failures == failures
	var products: Array[String] = []
	for product: int in exhibit["expected_products"]:
		products.append("%d:%d" % [product, record["maximum"][product]])
	print("DEEPWORKS_EXHIBIT %s %s products={%s} verified=%s" % [id, mechanism, ",".join(products), record["verified"]])


func _check_products(id: String, exhibit: Dictionary, record: Dictionary, injected: Dictionary) -> bool:
	_expect(not exhibit["expected_products"].is_empty(), id + " declares a real observable product")
	for product: int in exhibit["expected_products"]:
		_expect(not injected.has(product), "%s product %d must not be painted by its sources" % [id, product])
		_expect(record["initial"][product] == 0, "%s product %d must be absent initially" % [id, product])
		_expect(record["maximum"][product] > 0, "%s native product %d must actually appear" % [id, product])
	return true


func _check_flow(exhibit: Dictionary, record: Dictionary) -> bool:
	var id: String = exhibit["id"]
	var district: int = exhibit["district"]
	if district == 0:
		var materials: Array[int] = [Cell.SAND, Cell.DUST]
		if exhibit["layer"] == "scripted":
			materials.assign([Cell.STONE, Cell.SAND])
		for material: int in materials:
			_expect(record["initial"][material] == 0, id + " starts without injected grains")
			_expect(record["lower_maximum"][material] > 0,
				"%s material %d must reach below y143, well beyond its source nozzle" % [id, material])
	elif district == 15:
		_expect(record["initial"][Cell.MERCURY] == 0, id + " starts without Mercury")
		_expect(record["lower_maximum"][Cell.MERCURY] > 0, id + " Mercury must descend through the liquid well")
		var mean: PackedFloat32Array = record["final_mean_y"]
		_expect(mean[Cell.WATER] > mean[Cell.OIL], id + " Water remains below the lighter Oil on average")
		_expect(mean[Cell.MERCURY] > 143.0, id + " dense Mercury is observed below its y105 injection height")
	else:
		_expect(false, id + " needs an explicit physical transport oracle")
		return false
	return true


func _finish(report: Dictionary) -> void:
	report["assertions"] = assertions
	report["failures"] = failures
	report["elapsed_seconds"] = float(Time.get_ticks_usec() - started_us) / 1000000.0
	var destination: String = OS.get_environment("CYBERSAND_DEEPWORKS_REACTION_REPORT")
	if not destination.is_empty():
		var output: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
		_expect(output != null, "Could not write requested reaction evidence")
		if output != null:
			report["assertions"] = assertions
			report["failures"] = failures
			output.store_string(JSON.stringify(report, "\t"))
	print("DEEPWORKS_REACTIONS: %d assertions; %d failures; %.3f seconds" % [assertions, failures, report["elapsed_seconds"]])
	quit(1 if failures else 0)
