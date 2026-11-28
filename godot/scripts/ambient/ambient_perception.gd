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
const MAX_PEER_CANDIDATES := 32
const MAX_ADAPTIVE_SAMPLES := 4096

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
		if not module is Dictionary or not bool(module.get("enabled", false)) or float(module.get("weight", 1.0)) <= 0.0: continue
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
	var generation: Variant = context.get("world_generation", _generation)
	result["world_generation"] = int(generation) if _finite_number(generation) and float(generation) >= 0.0 and float(generation) == floorf(float(generation)) else -1
	var navigation: Variant = context.get("navigation", {})
	result["navigation"] = navigation.duplicate(true) if navigation is Dictionary else {"available":false}
	if result.navigation.has("directions"):
		result.navigation["sample_tick"] = int(view.tick)
	var regions: Variant = context.get("regions", [])
	result["regions"] = regions.duplicate(true) if regions is Array and regions.size() <= 32 else []
	var sampling: Variant = context.get("perception", {})
	if not sampling is Dictionary:
		result.materials = {"available":false, "status":"unavailable", "reason":"invalid sampling settings", "targets":{}}
	elif sampling.is_empty():
		result.materials = _materials(position, requested)
	else:
		result.materials = _materials_adaptive(position, requested, sampling)
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
	var result := {"available":false, "actors":[], "radius_cells":MAX_RADIUS,
		"candidate_budget":MAX_PEER_CANDIDATES, "actor_budget":MAX_NEIGHBORS,
		"coverage":"copied-owner-local-roster", "incomplete":false, "examined":0, "invalid":0}
	if not context.get("neighbors") is Array: return result
	result.available = true
	var candidates: Array = context.neighbors
	var admitted: Array[Dictionary] = []
	var identities: Dictionary = {}
	var relations: Dictionary = context.get("relations", {}) if context.get("relations", {}) is Dictionary else {}
	result.incomplete = bool(context.get("peer_roster_incomplete", false)) or candidates.size() > MAX_PEER_CANDIDATES
	for index: int in range(mini(candidates.size(), MAX_PEER_CANDIDATES)):
		var neighbor: Variant = candidates[index]
		result.examined += 1
		if not neighbor is Dictionary or not neighbor.get("position") is Vector2 \
			or not Vector2(neighbor.position).is_finite() or neighbor.get("run_id") != view.get("run_id") \
			or neighbor.get("epoch") != view.get("epoch") or neighbor.get("instance_id") == view.get("instance_id") \
			or neighbor.get("tick") != view.get("tick") or not bool(neighbor.get("available", true)) \
			or not _finite_number(neighbor.get("instance_id")) or float(neighbor.instance_id) < 0.0 \
			or float(neighbor.instance_id) != floorf(float(neighbor.instance_id)):
			result.invalid += 1
			continue
		var identity := int(neighbor.instance_id)
		if identities.has(identity):
			result.invalid += 1
			continue
		identities[identity] = true
		var distance := Vector2(neighbor.position).distance_to(view.position)
		if distance > MAX_RADIUS: continue
		var tags := _social_tags(neighbor.get("tags", []))
		var peer := {"id":identity, "position":Vector2(neighbor.position),
			"compatible":bool(neighbor.get("compatible", true)), "distance":distance,
			"sample_tick":int(neighbor.get("tick", -1)), "tags":tags,
			"affinity":_affinity(tags, relations), "velocity_available":false}
		var velocity: Variant = neighbor.get("velocity")
		if velocity is Vector2 and velocity.is_finite():
			peer["velocity"] = velocity
			peer.velocity_available = true
		admitted.append(peer)
	admitted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.distance), float(b.distance)): return float(a.distance) < float(b.distance)
		return int(a.id) < int(b.id))
	result.incomplete = bool(result.incomplete) or admitted.size() > MAX_NEIGHBORS or int(result.invalid) > 0
	for index: int in range(mini(admitted.size(), MAX_NEIGHBORS)):
		result.actors.append(admitted[index])
	return result


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _valid_material_id(value: Variant) -> bool:
	# Accepted native material.hpp is the same closed catalogue as the profile
	# validator: IDs1..131, reserved10 excluded; Empty0 is not an attraction.
	return _finite_number(value) and float(value) == floorf(float(value)) \
		and float(value) >= 1.0 and float(value) <= MAX_CATALOGUE_MATERIAL_ID and int(value) != 10


func diagnostics() -> Dictionary:
	return {"version":"ambient-perception/v2", "available":_freshness_reason().is_empty(),
		"reason":_freshness_reason(), "extent":_extent, "owner_epoch":_epoch,
		"world_generation":_generation, "publication_serial":_serial, "revision":_revision,
		"owner_snapshot_serial":_owner_serial,"ignored_older_publications":_ignored_older_publications,
		"sample_tick":_sample_tick, "current_tick":_latest_tick, "backend":_backend,
		"cache_bytes":_extent.x * _extent.y * _channels if _cache != null else 0,
		"ingestions":_ingestions, "patches":_patches, "source_bytes":_bytes,
		"ingest_usec_total":_ingest_usec, "ingest_usec_max":_ingest_max_usec,
		"queries":_queries, "query_samples":_query_samples,
		"query_usec_total":_query_usec, "query_usec_max":_query_max_usec,
		"maximum_samples_per_query":MAX_QUERY_SAMPLES, "maximum_adaptive_samples_per_query":MAX_ADAPTIVE_SAMPLES, "sample_spacing_cells":SAMPLE_SPACING,
		"maximum_materials":MAX_MATERIALS, "maximum_radius_cells":MAX_RADIUS}

# V1 profiles deliberately retain their qualified four-cell lattice. V2 opts in
# to an exact near field and requested coarse spacing under a single read budget.
static func settings(profile: Dictionary) -> Dictionary:
	if int(profile.get("version", 1)) < 2: return {}
	var configured: Variant = profile.get("perception", {})
	return configured.duplicate(true) if configured is Dictionary else {"invalid":true}


static func wants_navigation(profile: Dictionary) -> bool:
	for module: Variant in profile.get("modules", []):
		if module is Dictionary and bool(module.get("enabled", false)) \
			and float(module.get("weight", 1.0)) > 0.0 \
			and str(module.get("type", "")) in ["steer_obstacles", "withdraw_obstruction"]:
			return true
	return false


func _materials_adaptive(position: Vector2, requested: Array, settings_value: Dictionary) -> Dictionary:
	var reason := _freshness_reason()
	var state := "fresh" if reason.is_empty() else "stale" if "stale" in reason else "unavailable"
	var result := {"available":reason.is_empty(), "reason":reason, "status":state,
		"source":"native material-ID publication (stored cells plus ballistic projection)",
		"world_generation":_generation, "owner_epoch":_epoch, "sample_tick":_sample_tick,
		"current_tick":_latest_tick, "revision":_revision, "current_revision":_current_revision,
		"publication_serial":_serial, "age_ticks":maxi(0, _latest_tick - _sample_tick),
		"coverage":"sampled-circle-clipped-to-canvas", "coverage_complete":false,
		"distance":"inclusive Euclidean distance to cell centers from current actor center",
		"nearest_semantics":"nearest observed sample; unsampled cells are unknown",
		"targets":{}, "sample_count":0, "near_sample_count":0, "refinement_sample_count":0,
		"maximum_samples":MAX_ADAPTIVE_SAMPLES, "budget_exhausted":false}
	if settings_value.size() != 3 or not settings_value.has_all(["spacing_cells", "near_radius_cells", "refine_boundaries"]) \
		or not _finite_number(settings_value.get("spacing_cells")) \
		or not _finite_number(settings_value.get("near_radius_cells")) \
		or float(settings_value.spacing_cells) != floorf(float(settings_value.spacing_cells)) \
		or float(settings_value.near_radius_cells) != floorf(float(settings_value.near_radius_cells)) \
		or float(settings_value.spacing_cells) < 1.0 or float(settings_value.spacing_cells) > 4.0 \
		or float(settings_value.near_radius_cells) < 0.0 or float(settings_value.near_radius_cells) > 16.0 \
		or not settings_value.get("refine_boundaries") is bool:
		result.available = false
		result.status = "unavailable"
		result.reason = "invalid bounded adaptive sampling settings"
		return result
	if requested.size() > MAX_MATERIALS:
		result.available = false
		result.status = "unavailable"
		result.reason = "material query capacity exceeded"
		return result
	var maximum := 0.0
	var coverage: Dictionary = {}
	for request: Variant in requested:
		if not request is Dictionary or not _valid_material_id(request.get("material_id")) \
			or not _finite_number(request.get("radius_cells")):
			result.available = false
			result.status = "unavailable"
			result.reason = "invalid material query"
			return result
		var material_id := int(request.material_id)
		var radius := float(request.radius_cells)
		if radius < 1.0 or radius > MAX_RADIUS or radius != floorf(radius) \
			or result.targets.has(str(material_id)):
			result.available = false
			result.status = "unavailable"
			result.reason = "invalid material radius or duplicate query"
			return result
		maximum = maxf(maximum, radius)
		coverage[radius] = 0
		result.targets[str(material_id)] = {"available":reason.is_empty(), "status":state,
			"present":false, "count":0, "radius_cells":radius, "sample_tick":_sample_tick,
			"revision":_revision, "coverage":"sampled-circle", "coverage_sample_count":0,
			"coverage_complete":false, "absence_scope":"admitted_samples_only",
			"boundary":{"available":false, "reason":"no observed boundary"}}
	var requested_spacing := int(settings_value.spacing_cells)
	var spacing := requested_spacing
	var near_radius := minf(float(settings_value.near_radius_cells), maximum)
	var refine := bool(settings_value.refine_boundaries)
	var near_bound := int(pow(ceili(near_radius * 2.0) + 2, 2)) if near_radius > 0.0 else 0
	var refinement_bound := MAX_MATERIALS * 29 if refine else 0
	# Coarsen explicitly instead of truncating a scan toward one corner. Even
	# radius96, near16 and eight refinements fit at spacing4 (<=3,813 sites).
	while spacing < SAMPLE_SPACING \
		and int(pow(ceili(maximum * 2.0 / spacing) + 1, 2)) + near_bound + refinement_bound > MAX_ADAPTIVE_SAMPLES:
		spacing += 1
	result["requested_spacing_cells"] = requested_spacing
	result["sample_spacing_cells"] = spacing
	result["near_radius_cells"] = near_radius
	result["resolution_limited"] = spacing != requested_spacing
	result["coverage_state"] = "incomplete_requested_resolution" if spacing != requested_spacing else "sampled"
	result.coverage_complete = spacing == 1 or near_radius >= maximum
	if not result.available or requested.is_empty(): return result
	var started := Time.get_ticks_usec()
	var visited: Dictionary = {}
	if near_radius > 0.0:
		var near_squared := near_radius * near_radius
		for y: int in range(maxi(0, ceili(position.y - near_radius - 0.5)), mini(_extent.y - 1, floori(position.y + near_radius - 0.5)) + 1):
			for x: int in range(maxi(0, ceili(position.x - near_radius - 0.5)), mini(_extent.x - 1, floori(position.x + near_radius - 0.5)) + 1):
				if position.distance_squared_to(Vector2(x + 0.5, y + 0.5)) <= near_squared:
					_adaptive_sample(Vector2i(x,y), position, maximum, result, coverage, visited)
		result.near_sample_count = result.sample_count
	var first_x := maxi(0, ceili((position.x - maximum - 0.5) / spacing) * spacing)
	var first_y := maxi(0, ceili((position.y - maximum - 0.5) / spacing) * spacing)
	var last_x := mini(_extent.x - 1, floori((position.x + maximum - 0.5) / spacing) * spacing)
	var last_y := mini(_extent.y - 1, floori((position.y + maximum - 0.5) / spacing) * spacing)
	for y: int in range(first_y, last_y + 1, spacing):
		for x: int in range(first_x, last_x + 1, spacing):
			_adaptive_sample(Vector2i(x,y), position, maximum, result, coverage, visited)
	var before_refinement := int(result.sample_count)
	if refine:
		for key: String in result.targets:
			var target: Dictionary = result.targets[key]
			if not target.present: continue
			var point := Vector2i(Vector2(target.nearest).floor())
			# A finite exact patch improves an already observed coarse location;
			# it cannot discover every remote thin feature between lattice sites.
			for dy: int in range(-2,3):
				for dx: int in range(-2,3):
					var candidate := point + Vector2i(dx,dy)
					if position.distance_squared_to(Vector2(candidate) + Vector2(0.5,0.5)) <= float(target.radius_cells) * float(target.radius_cells):
						_adaptive_sample(candidate, position, maximum, result, coverage, visited)
			_observe_boundary(int(key), target, position, maximum, result, coverage, visited)
	result.refinement_sample_count = int(result.sample_count) - before_refinement
	for key: String in result.targets:
		var target: Dictionary = result.targets[key]
		target.coverage_sample_count = int(coverage[float(target.radius_cells)])
		target["sample_spacing_cells"] = spacing
		target["near_radius_cells"] = near_radius
		target["resolution_limited"] = spacing != requested_spacing
		target.coverage_complete = (spacing == 1 or near_radius >= float(target.radius_cells)) and not result.budget_exhausted
		if target.coverage_complete: target.absence_scope = "all_cell_centers_in_circle_clipped_to_canvas"
		if int(target.coverage_sample_count) == 0:
			target.available = false
			target.status = "unavailable"
			target["reason"] = "no admitted sample lies inside this clipped circle"
		else:
			target.status = "observed" if target.present else "absent" if target.coverage_complete else "unobserved_in_incomplete_coverage"
	if int(result.sample_count) == 0:
		result.available = false
		result.status = "unavailable"
		result.reason = "no admitted sample lies inside this clipped circle"
	if result.budget_exhausted:
		result.coverage_complete = false
		result.coverage_state = "incomplete_budget"
	_queries += 1
	_query_samples += int(result.sample_count)
	var elapsed := Time.get_ticks_usec() - started
	_query_usec += elapsed
	_query_max_usec = maxi(_query_max_usec, elapsed)
	return result


func _adaptive_sample(cell: Vector2i, position: Vector2, maximum: float, result: Dictionary,
		coverage: Dictionary, visited: Dictionary) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= _extent.x or cell.y >= _extent.y: return -1
	var point := Vector2(cell) + Vector2(0.5,0.5)
	var distance_squared := position.distance_squared_to(point)
	if distance_squared > maximum * maximum: return -1
	var offset := cell.y * _extent.x + cell.x
	if visited.has(offset): return int(visited[offset])
	if int(result.sample_count) >= MAX_ADAPTIVE_SAMPLES:
		result.budget_exhausted = true
		return -1
	# Byte-valued CPU L8/RG8 storage; this is not a displayed colour.
	var material_id := roundi(_cache.get_pixel(cell.x,cell.y).r * 255.0)
	visited[offset] = material_id
	result.sample_count += 1
	for radius: float in coverage:
		if distance_squared <= radius * radius: coverage[radius] += 1
	var key := str(material_id)
	if result.targets.has(key):
		var target: Dictionary = result.targets[key]
		if distance_squared <= float(target.radius_cells) * float(target.radius_cells):
			target.count += 1
			if not bool(target.present) or distance_squared < float(target.distance) * float(target.distance):
				target.present = true
				target["nearest"] = point
				target["distance"] = sqrt(distance_squared)
				target["direction"] = (point - position).normalized()
	return material_id


func _observe_boundary(material_id: int, target: Dictionary, position: Vector2, maximum: float,
		result: Dictionary, coverage: Dictionary, visited: Dictionary) -> void:
	var center := Vector2i(Vector2(target.nearest).floor())
	var outside := Vector2.ZERO
	var best_outside := Vector2.ZERO
	var best_score := -INF
	var checked := 0
	var toward_actor := (position - Vector2(target.nearest)).normalized()
	for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var candidate := center + offset
		if position.distance_squared_to(Vector2(candidate) + Vector2(0.5,0.5)) > float(target.radius_cells) * float(target.radius_cells): continue
		var found := _adaptive_sample(candidate, position, maximum, result, coverage, visited)
		if found < 0: continue
		checked += 1
		if found == material_id: continue
		outside += Vector2(offset)
		var score := Vector2(offset).dot(toward_actor)
		if score > best_score:
			best_score = score
			best_outside = Vector2(offset)
	if best_outside == Vector2.ZERO:
		target.boundary = {"available":false, "reason":"no different adjacent material observed", "checked_neighbors":checked}
		return
	var normal := outside.normalized() if outside.length_squared() > 0.000001 else best_outside
	var tangent := Vector2(-normal.y, normal.x)
	var boundary_position := Vector2(center) + Vector2(0.5,0.5) + best_outside * 0.5
	target.boundary = {"available":true, "position":boundary_position, "normal":normal, "tangent":tangent,
		"checked_neighbors":checked, "complete_cross":checked == 4,
		"source":"exact adjacent native-ID transitions; local estimated outward normal"}
	target["boundary_normal"] = normal
	target["boundary_tangent"] = tangent


static func _social_tags(value: Variant) -> Array:
	var result: Array = []
	if not value is Array or value.size() > 8: return result
	for tag: Variant in value:
		if not tag is String or tag.is_empty() or tag.length() > 64: continue
		if tag not in result: result.append(tag)
	result.sort()
	return result


static func _affinity(tags: Array, relations: Dictionary) -> int:
	for tag: Variant in _social_tags(relations.get("avoid_tags", [])):
		if tag in tags: return -1
	for tag: Variant in _social_tags(relations.get("prefer_tags", [])):
		if tag in tags: return 1
	return 0
