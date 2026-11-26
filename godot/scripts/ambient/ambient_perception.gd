extends RefCounted

# Copied native publication consumer, never a World/physics owner. Image is used
# ONLY as byte-preserving CPU L8/RG8 storage so patch copies run in the engine.
# It is never a viewport, framebuffer, palette colour or GPU readback. R holds
# the native material ID; G, when present, is an ignored visual-state byte.
# Native render IDs include stored cells and native-owned ballistic projections.
const VERSION := "ambient-observation/v1"
const MAX_EXTENT := 2048
const MAX_RADIUS := 96
const SAMPLE_SPACING := 4
const MAX_MATERIALS := 8
const MAX_CATALOGUE_MATERIAL_ID := 131
const MAX_PATCHES := 256
const MAX_PUBLICATION_BYTES := 16 * 1024 * 1024
const MAX_NATIVE_AGE_TICKS := 12
const MAX_QUERY_SAMPLES := 2401
const MAX_NEIGHBORS := 7

var _extent := Vector2i.ZERO
var _epoch := -1
var _generation := -1
var _serial := -1
var _owner_serial := -1
var _sample_tick := -1
var _latest_tick := -1
var _revision := -1
var _current_revision := -1
var _channels := 0
var _cache: Image
var _primed := false
var _failed := false
var _backend := ""
var _reason := "not configured"
var _blocked_reason := "not configured"
var _ingestions := 0
var _patches := 0
var _bytes := 0
var _ingest_usec := 0
var _ingest_max_usec := 0
var _queries := 0
var _query_samples := 0
var _query_usec := 0
var _query_max_usec := 0
var _ignored_older_publications := 0


func reset() -> void:
	_extent = Vector2i.ZERO
	_epoch = -1
	_clear_publication()
	_reason = "not configured"


func _clear_publication() -> void:
	_cache = null
	_primed = false
	_generation = -1
	_serial = -1
	_owner_serial = -1
	_sample_tick = -1
	_latest_tick = -1
	_revision = -1
	_current_revision = -1
	_channels = 0
	_failed = false
	_backend = ""
	_blocked_reason = "full material baseline required"


func configure(extent: Vector2i, expected_epoch: int) -> bool:
	if extent.x < 1 or extent.y < 1 or extent.x > MAX_EXTENT or extent.y > MAX_EXTENT or expected_epoch < 0:
		return false
	if extent != _extent or expected_epoch != _epoch:
		_clear_publication()
		_extent = extent
		_epoch = expected_epoch
		_reason = "awaiting full native material publication"
	return true


func wants_full_refresh() -> bool:
	return _extent != Vector2i.ZERO and not _primed


func ingest_snapshot(snapshot: CyberSimulationSnapshot, extent: Vector2i, expected_epoch: int) -> bool:
	if snapshot == null or not configure(extent, expected_epoch): return false
	if snapshot.rigid_body_epoch != _epoch:
		_reason = "physical owner epoch mismatch"
		_blocked_reason = _reason
		return false
	if snapshot.render_world_generation < _generation:
		_reason = "older World generation refused"
		_blocked_reason = _reason
		return false
	if snapshot.render_world_generation < 0 or snapshot.serial < 0 or snapshot.tick_index < 0 \
		or snapshot.simulation_world_revision < 0:
		_reason = "invalid native publication identity"
		_blocked_reason = _reason
		return false
	if snapshot.render_world_generation == _generation:
		# The render callback may retain an older envelope than the physical
		# completion callback. Ignore it without rolling freshness backward.
		if snapshot.serial < _owner_serial:
			_ignored_older_publications += 1
			return false
		if snapshot.tick_index < _latest_tick or snapshot.simulation_world_revision < _current_revision \
			or (snapshot.serial == _owner_serial and (snapshot.tick_index != _latest_tick \
				or snapshot.simulation_world_revision != _current_revision)):
			_reason = "native publication progression regressed or immutable identity changed"
			_blocked_reason = _reason
			return false
	_latest_tick = int(snapshot.tick_index)
	_current_revision = int(snapshot.simulation_world_revision)
	_failed = bool(snapshot.simulation_failed)
	_backend = str(snapshot.backend_name)
	if _failed:
		_reason = "native simulation failed"
		return false
	if not _backend.begins_with("native"):
		_reason = "native material identity unavailable for this backend"
		_blocked_reason = _reason
		return false
	if snapshot.render_world_generation != _generation:
		_cache = null
		_primed = false
		_serial = -1
		_generation = int(snapshot.render_world_generation)
	_owner_serial = int(snapshot.serial)
	if snapshot.render_snapshot_serial <= _serial:
		_blocked_reason = ""
		_reason = _freshness_reason()
		return _reason.is_empty()
	var channels := int(snapshot.render_channels)
	var metadata: PackedInt32Array = snapshot.render_patch_rectangles
	var payload: PackedByteArray = snapshot.render_patch_cells
	if channels not in [1, 2] or metadata.is_empty() or metadata.size() % 6 != 0 \
		or metadata.size() > MAX_PATCHES * 6 or payload.is_empty() or payload.size() > MAX_PUBLICATION_BYTES:
		return _refuse("invalid bounded material publication")
	# Validate every patch before changing the retained cache. A truncated later
	# patch cannot partially advance a previously valid material view.
	var full_covers_canvas := false
	var patches: Array[Dictionary] = []
	for index: int in range(0, metadata.size(), 6):
		var rect := Rect2i(metadata[index], metadata[index + 1], metadata[index + 2], metadata[index + 3])
		var offset := int(metadata[index + 4])
		var stride := int(metadata[index + 5])
		if rect.position.x < 0 or rect.position.y < 0 or rect.size.x < 1 or rect.size.y < 1 \
			or rect.end.x > _extent.x or rect.end.y > _extent.y or offset < 0 \
			or stride < rect.size.x * channels or stride > MAX_EXTENT * channels \
			or offset + (rect.size.y - 1) * stride + rect.size.x * channels > payload.size():
			return _refuse("invalid material patch geometry or payload")
		if rect == Rect2i(Vector2i.ZERO, _extent): full_covers_canvas = true
		patches.append({"rect":rect, "offset":offset, "stride":stride})
	if (not _primed or channels != _channels) and (not snapshot.render_full_refresh or not full_covers_canvas):
		return _refuse("full material baseline required")
	var started := Time.get_ticks_usec()
	var format := Image.FORMAT_L8 if channels == 1 else Image.FORMAT_RG8
	if _cache == null or channels != _channels:
		_cache = Image.create_empty(_extent.x, _extent.y, false, format)
	for patch: Dictionary in patches:
		var rect: Rect2i = patch.rect
		var offset: int = patch.offset
		var stride: int = patch.stride
		var tight := PackedByteArray()
		if stride == rect.size.x * channels:
			tight = payload.slice(offset, offset + rect.size.y * stride)
		else:
			# Clipped native boundary patches retain the original wider row stride.
			# Copy complete bounded rows; never reinterpret padding as cell IDs.
			for row: int in range(rect.size.y):
				tight.append_array(payload.slice(offset + row * stride, offset + row * stride + rect.size.x * channels))
		var source := Image.create_from_data(rect.size.x, rect.size.y, false, format, tight)
		_cache.blit_rect(source, Rect2i(Vector2i.ZERO, rect.size), rect.position)
	_channels = channels
	_primed = true
	_serial = int(snapshot.render_snapshot_serial)
	_sample_tick = int(snapshot.render_tick_index)
	_revision = int(snapshot.world_revision)
	_blocked_reason = ""
	_ingestions += 1
	_patches += patches.size()
	_bytes += payload.size()
	var elapsed := Time.get_ticks_usec() - started
	_ingest_usec += elapsed
	_ingest_max_usec = maxi(_ingest_max_usec, elapsed)
	_reason = _freshness_reason()
	return _reason.is_empty()


func _refuse(reason: String) -> bool:
	_reason = reason
	_blocked_reason = reason
	# Publication omission means later incremental patches cannot prove a full
	# view. Retain no authority until the owner supplies another full baseline.
	_primed = false
	return false


func _freshness_reason() -> String:
	if _failed: return "native simulation failed"
	if not _blocked_reason.is_empty(): return _blocked_reason
	if not _primed or _cache == null: return "full material baseline required"
	if _sample_tick < 0 or _latest_tick < _sample_tick: return "invalid native sampling tick"
	# Unchanged material revision proves retained bytes remain current even if
	# many simulation ticks elapsed. Changed material has a bounded age budget.
	if _current_revision != _revision and _latest_tick - _sample_tick > MAX_NATIVE_AGE_TICKS:
		return "native material publication stale"
	return ""


static func requests(profile: Dictionary) -> Array:
	var requested: Dictionary = {}
	for module: Variant in profile.get("modules", []):
		if not module is Dictionary or not bool(module.get("enabled", false)): continue
		if str(module.get("type", "")) not in ["seek_material", "avoid_material", "investigate_material"]: continue
		var parameters: Dictionary = module.get("params", {})
		if not parameters.has("material_id") or not parameters.has("radius"): continue
		if not _valid_material_id(parameters.material_id) or not _finite_number(parameters.radius): continue
		var material_id := int(parameters.material_id)
		var radius := float(parameters.radius)
		if radius < 1.0 or radius > MAX_RADIUS or radius != floorf(radius): continue
		requested[material_id] = maxf(float(requested.get(material_id, 0.0)), radius)
	var result: Array = []
	var ids: Array = requested.keys()
	ids.sort()
	for material_id: int in ids:
		if result.size() >= MAX_MATERIALS: break
		result.append({"material_id":material_id, "radius_cells":float(requested[material_id])})
	return result


func observe(view: Dictionary, requested: Array, context: Dictionary) -> Dictionary:
	var result := {"version":VERSION, "available":false, "reason":"invalid actor observation",
		"materials":{"available":false, "reason":"actor observation unavailable", "targets":{}},
		"grounded":{"available":false}, "obstacles":{"available":false},
		"ledges":{"available":false}, "neighbors":{"available":false}, "bounds":{"available":false}}
	for key: String in ["run_id", "epoch", "actor_id", "instance_id", "control_generation", "tick"]:
		result[key] = view.get(key)
	var position: Variant = view.get("position")
	var velocity: Variant = view.get("velocity")
	if view.get("representation") != "articulated-rapier" or not position is Vector2 or not position.is_finite() \
		or not velocity is Vector2 or not velocity.is_finite() or int(view.get("epoch", -1)) != _epoch \
		or bool(view.get("suspended", true)) or not str(view.get("fault", "")).is_empty(): return result
	result.available = true
	result.reason = ""
	result["position"] = position
	result["velocity"] = velocity
	result["capabilities"] = context.get("capabilities", {}).duplicate(true)
	result["simulation_time_seconds"] = context.get("simulation_time_seconds", float(view.get("tick", 0)) / 60.0)
	result["home"] = context.get("home", position)
	result["grounded"] = {"available":view.get("grounded") is bool, "value":bool(view.get("grounded", false))}
	if _finite_number(view.get("energy")):
		result["resources"] = {"available":true, "energy":float(view.energy)}
	else:
		result["resources"] = {"available":false}
	var bounds: Variant = context.get("bounds")
	if bounds is Rect2 and bounds.position.is_finite() and bounds.size.is_finite() and bounds.has_area():
		result.bounds = {"available":true, "rect":bounds, "kind":"authored_region_or_canvas"}
	if _finite_number(view.get("wall_left")) and _finite_number(view.get("wall_right")) \
		and float(view.wall_left) >= 0.0 and float(view.wall_right) >= 0.0:
		result.obstacles = {"available":true, "left_distance":float(view.wall_left),
			"right_distance":float(view.wall_right), "maximum_distance_cells":30.0,
			"source":"existing physical terrain rays", "sample_tick":int(view.tick)}
	var spatial: Dictionary = context.get("spatial", {})
	if spatial.has("left") and spatial.has("right"):
		result.ledges = {"available":bool(spatial.get("available", true)),
			"left":spatial.left.duplicate(true), "right":spatial.right.duplicate(true),
			"sample_tick":int(view.tick), "source":"owner-issued terrain rays; not world-boundary inference"}
		if spatial.get("modules") is Dictionary:
			result.ledges["modules"] = spatial.modules.duplicate(true)
	result.neighbors = _neighbors(view, context)
	result.materials = _materials(position, requested)
	return result


func _materials(position: Vector2, requested: Array) -> Dictionary:
	var reason := _freshness_reason()
	var result := {"available":reason.is_empty(), "reason":reason,
		"source":"native material-ID publication (stored cells plus ballistic projection)",
		"world_generation":_generation, "owner_epoch":_epoch, "sample_tick":_sample_tick,
		"current_tick":_latest_tick, "revision":_revision, "current_revision":_current_revision,
		"publication_serial":_serial, "age_ticks":maxi(0, _latest_tick - _sample_tick),
		"sample_spacing_cells":SAMPLE_SPACING, "coverage":"sampled-circle-clipped-to-canvas",
		"distance":"inclusive Euclidean distance to cell centers from current actor center",
		"nearest_semantics":"nearest observed sample; unsampled cells are unknown", "targets":{}, "sample_count":0}
	if requested.size() > MAX_MATERIALS:
		result.available = false
		result.reason = "material query capacity exceeded"
		return result
	var maximum := 0.0
	var coverage: Dictionary = {}
	for request: Variant in requested:
		if not request is Dictionary or not _finite_number(request.get("material_id")) \
			or not _finite_number(request.get("radius_cells")):
			result.available = false
			result.reason = "invalid material query"
			return result
		var material_id := int(request.material_id)
		var radius := float(request.radius_cells)
		if not _valid_material_id(request.material_id) \
			or radius < 1.0 or radius > MAX_RADIUS or radius != floorf(radius) \
			or result.targets.has(str(material_id)):
			result.available = false
			result.reason = "invalid material ID, radius or duplicate query"
			return result
		maximum = maxf(maximum, radius)
		coverage[radius] = 0
		result.targets[str(material_id)] = {"available":reason.is_empty(), "present":false,
			"count":0, "radius_cells":radius, "sample_tick":_sample_tick, "revision":_revision,
			"coverage":"sampled-circle", "coverage_sample_count":0, "sample_spacing_cells":SAMPLE_SPACING}
	if not bool(result.available) or requested.is_empty(): return result
	var started := Time.get_ticks_usec()
	var first_x := maxi(0, ceili((position.x - maximum - 0.5) / SAMPLE_SPACING) * SAMPLE_SPACING)
	var first_y := maxi(0, ceili((position.y - maximum - 0.5) / SAMPLE_SPACING) * SAMPLE_SPACING)
	var last_x := mini(_extent.x - 1, floori((position.x + maximum - 0.5) / SAMPLE_SPACING) * SAMPLE_SPACING)
	var last_y := mini(_extent.y - 1, floori((position.y + maximum - 0.5) / SAMPLE_SPACING) * SAMPLE_SPACING)
	for y: int in range(first_y, last_y + 1, SAMPLE_SPACING):
		for x: int in range(first_x, last_x + 1, SAMPLE_SPACING):
			var point := Vector2(x + 0.5, y + 0.5)
			var distance_squared := position.distance_squared_to(point)
			if distance_squared > maximum * maximum: continue
			result.sample_count += 1
			for radius: float in coverage:
				if distance_squared <= radius * radius: coverage[radius] += 1
			# Exact 8-bit ID decoding from an unfiltered CPU byte image. No palette,
			# display framebuffer, shader colour, texture filtering or renderer API.
			var material_id := roundi(_cache.get_pixel(x, y).r * 255.0)
			var key := str(material_id)
			if not result.targets.has(key): continue
			var target: Dictionary = result.targets[key]
			if distance_squared > float(target.radius_cells) * float(target.radius_cells): continue
			target.count += 1
			if not bool(target.present) or distance_squared < float(target.distance) * float(target.distance):
				target.present = true
				target["nearest"] = point
				target["distance"] = sqrt(distance_squared)
				target["direction"] = (point - position).normalized()
	for key: String in result.targets:
		var target: Dictionary = result.targets[key]
		target.coverage_sample_count = int(coverage[float(target.radius_cells)])
		if int(target.coverage_sample_count) == 0:
			target.available = false
			target["reason"] = "no admitted sparse sample lies inside this clipped circle"
	if int(result.sample_count) == 0:
		result.available = false
		result.reason = "no admitted sparse sample lies inside this clipped circle"
	_queries += 1
	_query_samples += int(result.sample_count)
	var elapsed := Time.get_ticks_usec() - started
	_query_usec += elapsed
	_query_max_usec = maxi(_query_max_usec, elapsed)
	return result


static func _neighbors(view: Dictionary, context: Dictionary) -> Dictionary:
	var result := {"available":false, "actors":[], "radius_cells":MAX_RADIUS}
	if not context.get("neighbors") is Array: return result
	result.available = true
	for neighbor: Variant in context.neighbors:
		if result.actors.size() >= MAX_NEIGHBORS: break
		if not neighbor is Dictionary or not neighbor.get("position") is Vector2 \
			or not Vector2(neighbor.position).is_finite() or neighbor.get("run_id") != view.get("run_id") \
			or neighbor.get("epoch") != view.get("epoch") or neighbor.get("instance_id") == view.get("instance_id") \
			or neighbor.get("tick") != view.get("tick"):
			continue
		if Vector2(neighbor.position).distance_to(view.position) > MAX_RADIUS: continue
		result.actors.append({"id":int(neighbor.get("instance_id", -1)),
			"position":Vector2(neighbor.position), "compatible":bool(neighbor.get("compatible", true)),
			"sample_tick":int(neighbor.get("tick", -1))})
	return result


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _valid_material_id(value: Variant) -> bool:
	# Accepted native material.hpp is the same closed catalogue as the profile
	# validator: IDs1..131, reserved10 excluded; Empty0 is not an attraction.
	return _finite_number(value) and float(value) == floorf(float(value)) \
		and float(value) >= 1.0 and float(value) <= MAX_CATALOGUE_MATERIAL_ID and int(value) != 10


func diagnostics() -> Dictionary:
	return {"version":"ambient-perception/v1", "available":_freshness_reason().is_empty(),
		"reason":_freshness_reason(), "extent":_extent, "owner_epoch":_epoch,
		"world_generation":_generation, "publication_serial":_serial, "revision":_revision,
		"owner_snapshot_serial":_owner_serial,"ignored_older_publications":_ignored_older_publications,
		"sample_tick":_sample_tick, "current_tick":_latest_tick, "backend":_backend,
		"cache_bytes":_extent.x * _extent.y * _channels if _cache != null else 0,
		"ingestions":_ingestions, "patches":_patches, "source_bytes":_bytes,
		"ingest_usec_total":_ingest_usec, "ingest_usec_max":_ingest_max_usec,
		"queries":_queries, "query_samples":_query_samples,
		"query_usec_total":_query_usec, "query_usec_max":_query_max_usec,
		"maximum_samples_per_query":MAX_QUERY_SAMPLES, "sample_spacing_cells":SAMPLE_SPACING,
		"maximum_materials":MAX_MATERIALS, "maximum_radius_cells":MAX_RADIUS}
