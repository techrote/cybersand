extends SceneTree

const Map = preload("res://scripts/exhibition/deepworks_map.gd")
const Runtime = preload("res://scripts/exhibition/deepworks_runtime.gd")
const Cell = preload("res://scripts/cell_world.gd")
var assertions: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var recipe: Dictionary = Map.build()
	_expect(Map.SIZE == Vector2i(1024, 1024), "Total authored dimensions must be exactly 1024 square")
	_expect(Map.recipe_hash(recipe) == Map.recipe_hash(Map.build()), "Recipe and source order must be deterministic")
	_expect(recipe["exhibits"].size() == 32, "Thirty-two primary exhibits must exist")
	_expect(Map.passages().size() == 24, "Every orthogonal district seam must have an opening")
	var runtime: CyberDeepworksRuntime = Runtime.new()
	_expect(runtime.install(recipe["layers"], recipe["events"]), "Full-map native installation: " + runtime.last_error)
	if failures > 0:
		_finish()
		return
	var material_ids: Dictionary = {}
	for id: String in Map.LAYERS:
		var rectangles: PackedInt32Array = recipe["layers"][id]
		var writes: int = 0
		for offset: int in range(0, rectangles.size(), 5):
			writes += rectangles[offset + 2] * rectangles[offset + 3]
		_expect(rectangles.size() / 5 <= 4096, id + " rectangle budget")
		_expect(writes <= 4194304, id + " cumulative authoring-write budget")
		var packet: Dictionary = runtime.snapshot_layer(id, true)
		var data: PackedByteArray = packet.get("cells", PackedByteArray())
		_expect(not bool(packet.get("failed", false)) and data.size() == 2097152, id + " complete native snapshot")
		if data.size() != 2097152:
			continue
		var occupancy: Array[int] = []
		occupancy.resize(16)
		occupancy.fill(0)
		for y: int in range(1, 1023):
			for x: int in range(1, 1023):
				var material: int = data[(y * 1024 + x) * 2]
				if material != Cell.EMPTY:
					occupancy[(y / 256) * 4 + x / 256] += 1
					if id == "play": material_ids[material] = true
		for index: int in range(16):
			var minimum: int = 6 if id == "effects" else 1500
			_expect(occupancy[index] >= minimum, "%s must contain real %s material coverage" % [Map.district_code(index), id])
		print("Deepworks ", id, ": records=", rectangles.size() / 5, " writes=", writes, " occupancy=", occupancy)
	for material: int in range(81, 132):
		_expect(material_ids.has(material), "Building material %d survives full map composition" % material)
	_check_passages(runtime)
	# Each district must own a native source and exhibit on BOTH chemical planes.
	for district: int in range(16):
		for id: String in ["play", "scripted", "effects"]:
			var count: int = 0
			for event: Dictionary in recipe["events"]:
				if event["district"] == district and event["layer"] == id and event["material"] != Cell.EMPTY:
					count += 1
			_expect(count > 0, "Missing local source in %s / %s" % [Map.district_code(district), id])
		for id: String in ["play", "scripted"]:
			var count: int = 0
			for exhibit: Dictionary in recipe["exhibits"]:
				if exhibit["district"] == district and exhibit["layer"] == id: count += 1
			_expect(count == 1, "Exactly one primary %s exhibit in %s" % [id, Map.district_code(district)])
	var generation_before: int = runtime.generation()
	var old_probe: int = runtime.material_at("play", Vector2i(20, 20))
	for mutation: Dictionary in [
		{"material": 10}, {"material": 132}, {"material": 3.0}, {"layer": "background"},
		{"layer": "foreign"}, {"district": -1}, {"period": 0}, {"period": -1},
		{"first_tick": -1}, {"first_tick": 36001}, {"repeat": -1}, {"repeat": 10001},
		{"rect": Rect2i(0, 10, 2, 2)}, {"rect": Rect2i(50, 50, 0, 1)},
		{"rect": Rect2i(50, 50, 64, 64)}, {"rect": Rect2i(280, 50, 1, 1)},
		{"rect": Rect2i(2147483640, 12, 16, 1)}, {"rect": Rect2i(12, 2147483640, 1, 16)},
		{"rect": [50, 50, 1, 1]}, {"unknown": true}, {"id": ""},
		{"layer": "effects", "material": Cell.ACID},
	]:
		var event: Dictionary = _sample_event()
		event.merge(mutation, true)
		_expect(not runtime.install(recipe["layers"], [event]), "Invalid programme rejected: " + str(mutation))
		_expect(runtime.generation() == generation_before and runtime.material_at("play", Vector2i(20, 20)) == old_probe, "Rejected programme preserves installed world")
	_expect(not runtime.install(recipe["layers"], [_sample_event(), _sample_event()]), "Duplicate source identities refused")
	var capacity: Array = []
	for index: int in range(193):
		var event: Dictionary = _sample_event()
		event["id"] = "event-%d" % index
		capacity.append(event)
	_expect(not runtime.install(recipe["layers"], capacity), "Event count cap refused")
	var excessive_writes: Array = []
	for index: int in range(17):
		var event: Dictionary = _sample_event()
		event["id"] = "wide-%d" % index
		event["rect"] = Rect2i(80, 80, 32, 16)
		excessive_writes.append(event)
	_expect(not runtime.install(recipe["layers"], excessive_writes), "Simultaneous layer write cap refused")
	_expect(runtime.generation() == generation_before, "All invalid programmes leave native generation intact")
	# Check scheduler semantics on small sparse worlds, with immutable wall probes.
	var blank: Dictionary = {}
	for id: String in Map.LAYERS: blank[id] = PackedInt32Array()
	var programme: Array = [_sample_event()]
	var rear: Dictionary = _sample_event()
	rear.merge({"id": "rear", "layer": "scripted", "rect": Rect2i(101, 80, 1, 1)}, true)
	programme.append(rear)
	_expect(runtime.install(blank, programme), "Sparse programme installation")
	programme[0]["material"] = Cell.LAVA
	for _frame: int in range(3): runtime.advance(1.0, true)
	_expect(runtime.event_stats()["applications"] == 0 and runtime.layer_tick("play") == 0, "Pause freezes emitters as well as native clocks")
	runtime.set_layer_paused("play", true)
	for _tick: int in range(6): _expect(runtime.step_once()["ok"], "Rear-only native step")
	_expect(runtime.material_at("play", Vector2i(100, 80)) == Cell.EMPTY, "Rear programme cannot mutate paused foreground")
	_expect(runtime.event_stats()["fired"]["rear"] == 2, "Finite rear source fires exactly twice")
	_expect(runtime.material_at("scripted", Vector2i(101, 80)) == Cell.WALL, "Native rear source is visible")
	runtime.set_layer_paused("play", false)
	for _tick: int in range(8): runtime.step_once()
	_expect(runtime.event_stats()["fired"]["sample"] == 2, "Finite source terminates after its requested pulse count")
	_expect(runtime.material_at("play", Vector2i(100, 80)) == Cell.WALL, "Caller cannot mutate installed programme")
	_expect(runtime.layer_tick("background") == 0, "Distant architecture never advances")
	var pending: Dictionary = runtime.paint_disc("play", Vector2i(90, 90), 1, Cell.FIRE)
	_expect(pending["accepted"], "Queued pre-reset edit admitted")
	var previous_generation: int = runtime.generation()
	_expect(runtime.install(blank, [_sample_event()]), "Reset restarts the programme")
	runtime.advance(0.0, true)
	_expect(runtime.material_at("play", Vector2i(90, 90)) == Cell.EMPTY, "Reset discards prior-generation queued edits")
	_expect(runtime.event_stats()["applications"] == 0 and runtime.layer_tick("play") == 0, "Reset restores tick and source phase")
	var stale: Dictionary = runtime.route_event("play", "scripted", "blast", Vector2i(100, 100), 6, Cell.FIRE, previous_generation)
	_expect(not stale["accepted"], "Pre-reset cross-layer receipt refused")
	runtime.scripts_enabled = false
	for _tick: int in range(8): runtime.step_once()
	_expect(runtime.event_stats()["applications"] == 0 and runtime.layer_tick("play") == 8, "Disabling sources leaves native physics running")
	_finish()

func _check_passages(runtime: CyberDeepworksRuntime) -> void:
	for seam: Dictionary in Map.passages():
		var rect: Rect2i = seam["rect"]
		var clear: bool = true
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				if runtime.material_at("play", Vector2i(x, y)) != Cell.EMPTY: clear = false
		_expect(clear, "Complete native passage %d ↔ %d is clear" % [seam["a"], seam["b"]])

func _sample_event() -> Dictionary:
	return {"id": "sample", "district": 0, "layer": "play", "rect": Rect2i(100, 80, 1, 1),
		"material": Cell.WALL, "first_tick": 2, "period": 3, "repeat": 2}

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("Deepworks map and programme: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
