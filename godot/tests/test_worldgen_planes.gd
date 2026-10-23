extends SceneTree

# A separate adapter oracle compares independently requested tile payloads and
# owner registrations; it never uses the native whole-result hash as the oracle.
const Cell = preload("res://scripts/cell_world.gd")
const PROFILES: Array[String] = ["semantic-refinery", "semantic-flooded-cavern"]
const PLANES: Array[String] = ["play", "scripted", "effects", "background"]
var assertions: int = 0
var failures: int = 0
var completed: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _recipe(name: String) -> Dictionary:
	var path := ProjectSettings.globalize_path("res://../examples/worldgen/" + name + ".json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_check(false, "valid recipe " + name)
		return {}
	return parsed

func _run() -> void:
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		_check(false, "required native generator")
		_finish()
		return
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	if not generator.has_method(&"generate_plane_bundle"):
		_check(false, "source-matched GEN-005 native extension")
		_finish()
		return
	for name: String in PROFILES:
		_exercise_profile(generator, name)
	_rejections(generator)
	_incremental_and_retry(generator)
	_ordinary_chunk_revisions(generator)
	_check(completed.size() == 5, "all independent test sections completed")
	_finish()

func _finish() -> void:
	print("GEN-005 plane adapter: %d assertions; %d failures" % [assertions, failures])
	print("GEN-005 adapter sections: ", completed)
	quit(0 if failures == 0 else 1)

func _exercise_profile(generator: Object, name: String) -> void:
	var recipe: Dictionary = _recipe(name)
	var configured: Dictionary = generator.configure(recipe)
	_check(bool(configured.get("ok", false)), name + " configure: " + str(configured))
	if not configured.get("ok", false):
		return
	var whole: Dictionary = generator.generate_plane_bundle()
	_check(bool(whole.get("ok", false)), name + " whole generation: " + str(whole.get("error", "")))
	if not whole.get("ok", false):
		return
	_check(whole.get("complete", false), "whole proposal is installable")
	var bounds: Rect2i = whole.bounds
	_check(bounds.position.x < 0 and bounds.position.y < 0, "negative canonical coordinates")
	var fixture_owners: Dictionary = {}
	var link_owners: Dictionary = {}
	var actor_owners: Dictionary = {}
	var reconstructed: Dictionary = {}
	for plane: String in PLANES:
		var output := PackedByteArray()
		output.resize(bounds.size.x * bounds.size.y)
		reconstructed[plane] = output
	# Reverse request order deliberately starts away from the canonical owner.
	var requests: Array[Rect2i] = []
	for y: int in range(bounds.position.y, bounds.end.y, 64):
		for x: int in range(bounds.position.x, bounds.end.x, 64):
			requests.append(Rect2i(x, y, mini(64, bounds.end.x - x), mini(64, bounds.end.y - y)))
	requests.reverse()
	for request: Rect2i in requests:
		var tile: Dictionary = generator.generate_plane_region(request)
		_check(tile.get("ok", false), "tile generation")
		if not tile.get("ok", false):
			continue
		_check(not tile.get("complete", true) and not tile.has("layers"), "tile cannot masquerade as host replacement")
		for plane: String in PLANES:
			var source: PackedByteArray = tile.materials[plane]
			var destination: PackedByteArray = reconstructed[plane]
			for y: int in range(request.size.y):
				for x: int in range(request.size.x):
					var index: int = (request.position.y - bounds.position.y + y) * bounds.size.x + request.position.x - bounds.position.x + x
					destination[index] = source[y * request.size.x + x]
			reconstructed[plane] = destination
		for id: String in tile.fixture_ids:
			_check(not fixture_owners.has(id), "exactly one canonical fixture owner")
			fixture_owners[id] = true
		for id: String in tile.link_ids:
			_check(not link_owners.has(id), "exactly one canonical link owner")
			link_owners[id] = true
		for id: String in tile.actor_ids:
			_check(not actor_owners.has(id), "exactly one canonical actor owner")
			actor_owners[id] = true
	for plane: String in PLANES:
		_check(reconstructed[plane] == whole.materials[plane], "independent tiled material equivalence: " + plane)
		var rows: PackedInt32Array = whole.layers[plane]
		_check(rows.size() % 5 == 0 and rows.size() <= 4096 * 5, "bounded native run rectangles")
		var projected := PackedByteArray()
		projected.resize(bounds.size.x * bounds.size.y)
		for offset: int in range(0, rows.size(), 5):
			for y: int in range(rows[offset + 1], rows[offset + 1] + rows[offset + 3]):
				for x: int in range(rows[offset], rows[offset] + rows[offset + 2]):
					projected[y * bounds.size.x + x] = rows[offset + 4]
		_check(projected == whole.materials[plane], "host material rectangles exactly reconstruct native proposal: " + plane)
	_check(fixture_owners.size() == whole.fixtures.size(), "complete fixture ownership union")
	_check(link_owners.size() == whole.links.size(), "complete link ownership union")
	_check(actor_owners.size() == whole.actors.size() and actor_owners.size() == 4, "complete play-actor ownership union")
	var masked_planes: Dictionary = {}
	for projection: Dictionary in whole.projections:
		if not str(projection.get("application", "")).is_empty():
			_check(projection.application == "spatial:weathering" and str(projection.fields_fingerprint).length() == 16, "copied shared-field provenance")
			masked_planes[projection.plane] = true
	_check(masked_planes.has("scripted") and masked_planes.has("background"), "rear and far projections share typed world-space mask")
	var families: Dictionary = {}
	for link: Dictionary in whole.links:
		families[link.family] = true
		_check(link.classification in ["static", "presentation", "runtime"], "typed semantic-link class")
		_check(not str(link.id).is_empty() and str(link.revision).length() == 16, "stable link identity/revision")
		if link.classification == "runtime":
			_check((link.source_plane == "play" and link.target_plane == "scripted" and link.effect == "blast") or (link.source_plane == "scripted" and link.target_plane == "effects" and link.effect == "burst"), "only existing runtime routes")
	for family: String in ["explosion", "vent", "window", "pipe", "waterfall", "machinery"]:
		_check(families.has(family), "working declared link family " + family)
	for fixture: Dictionary in whole.fixtures:
		_check(fixture.repeat > 0 and fixture.period > 0 and fixture.plane != "background", "finite separately-owned fixture")
		_check(fixture.material != Cell.BRINE, "Brine diagnostic is a native product, not a feed")
	var plans: Dictionary = generator.get_plane_plan()
	_check(plans.fingerprint == whole.fingerprint, "copied semantic plan matches proposal")
	var inspected: Dictionary = generator.inspect_plane_cell("scripted", bounds.position + Vector2i(24, 24))
	_check(inspected.get("ok", false) and inspected.has("features") and inspected.has("projections") and inspected.has("links"), "GEN-007 provenance export")
	# Consumer-owned data cannot mutate the retained compiler or future proposals.
	whole.fixtures.clear()
	whole.materials.play[0] = 255
	var next: Dictionary = generator.generate_plane_bundle()
	_check(next.get("ok", false) and next.fixtures.size() == fixture_owners.size(), "copied fixture isolation")
	_check(next.materials.play == reconstructed.play, "copied material isolation")
	completed.append(name)

func _rejections(generator: Object) -> void:
	var original: Dictionary = _recipe(PROFILES[0])
	_check(generator.configure(original).get("ok", false), "rejection control configured")
	var fingerprint: String = generator.get_plane_plan().fingerprint
	var variants: Array[Dictionary] = []
	var bad := original.duplicate(true)
	bad.semantic_planes.links[0].target_rule = "missing-endpoint"
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes.links[0].target_plane = "play"
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes.links[0].family = "implicit-overlap"
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes.fixtures[0].material = 10
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes.fixtures[0].bounds = [100000, 100000, 4, 4]
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes.fixtures[0].repeat = 0
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes.fixtures[0].plane = "background"
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes.projections[0].density = NAN
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes.projections[0]["application"] = "spatial:missing-mask"
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes["camera_zoom"] = 2
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes["limits"] = {"max_links": 1}
	variants.append(bad)
	bad = original.duplicate(true)
	bad.semantic_planes["limits"] = {"max_prepared_bytes": 1}
	variants.append(bad)
	for candidate: Dictionary in variants:
		var rejected: Dictionary = generator.configure(candidate)
		_check(not rejected.get("ok", true) and not str(rejected.get("error", "")).is_empty(), "invalid semantic bundle rejected")
		_check(generator.get_plane_plan().fingerprint == fingerprint, "rejection preserves last valid complete plan")
	completed.append("rejections")

func _incremental_and_retry(generator: Object) -> void:
	var recipe: Dictionary = _recipe(PROFILES[1])
	_check(generator.configure(recipe).get("ok", false), "incremental control")
	var plan: Dictionary = generator.get_plane_plan()
	var request := Rect2i(plan.bounds.position + Vector2i(32, 32), Vector2i(16, 16))
	var complete: Dictionary = generator.generate_plane_region(request)
	var pending: Dictionary = generator.begin_plane_region(request)
	_check(pending.get("ok", false) and pending.state == "running" and not pending.has("materials"), "pending proposal publishes no partial cells")
	var count: int = 0
	while pending.get("ok", false) and pending.get("state", "") == "running" and count < 100:
		pending = generator.advance_plane_region(17)
		count += 1
	_check(pending.get("ok", false) and pending.get("state", "") == "ready", "bounded sliced completion")
	_check(pending.get("materials", {}) == complete.materials, "budget slices preserve all plane materials")
	_check(generator.begin_plane_region(request).get("ok", false), "begin stale control")
	_check(generator.advance_plane_region(1).get("state", "") == "running", "partial job retained privately")
	var retried: Dictionary = generator.configure(recipe)
	_check(retried.get("ok", false) and generator.get_plane_plan().fingerprint == plan.fingerprint, "identical retry keeps semantic bundle identity")
	_check(not generator.advance_plane_region(256).get("ok", true), "configuration replacement retires old job")
	_check(generator.begin_plane_region(request).get("ok", false), "begin cancellation")
	_check(generator.cancel_plane_region().get("state", "") == "cancelled", "explicit cancellation")
	_check(not generator.advance_plane_region(256).get("ok", true), "cancelled job cannot publish")
	completed.append("incremental-retry")

func _ordinary_chunk_revisions(generator: Object) -> void:
	var recipe: Dictionary = _recipe(PROFILES[0])
	var configured: Dictionary = generator.configure(recipe)
	_check(configured.get("ok", false) and configured.revision > int(recipe.semantic_planes.get("revision", 1)), "adapter serial differs from authored semantic revision")
	var coordinate := Vector2i(-1, -1)
	var direct: Dictionary = generator.generate_chunk(coordinate)
	_check(direct.get("ok", false) and direct.revision == configured.revision and direct.fingerprint == configured.fingerprint, "ordinary workbench chunk retains current adapter identity")
	var pending: Dictionary = generator.begin_chunk(coordinate)
	_check(pending.get("ok", false) and pending.revision == configured.revision, "ordinary pending chunk has current adapter serial")
	var slices: int = 0
	while pending.get("ok", false) and pending.get("state", "") == "running" and slices < 20:
		pending = generator.advance(512)
		slices += 1
	_check(pending.get("ok", false) and pending.state == "ready" and pending.revision == configured.revision, "ordinary completed chunk retains pending/configure serial")
	_check(pending.get("cells", PackedByteArray()) == direct.get("cells", PackedByteArray()), "ordinary chunk contents stay stable through sliced completion")
	completed.append("ordinary-chunk-revisions")
