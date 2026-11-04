extends RefCounted

# WATER-CONTACT #362 impact apparatus, experiment `water_contact.impact.v1`.
#
# Fixture-only observation of the CURRENT generic Rapier<->Water coupling under
# the four admitted Water liquid families. It changes no coupling, solver,
# Rapier bridge, mask, structural-detachment or production default. Every value
# is copied on the exclusive owner thread between public adapter calls; nothing
# runs inside a native pool job, wakes cells or consumes dirty state.
#
# Per tick the apparatus observes twice:
#   A: after prepare_rigid_body_coupling() and before simulation_tick()
#      (relocation applied, liquid transport not yet run);
#   B: after simulation_tick() (liquid transport applied).
# So every change of above-surface Water decomposes exactly into a relocation
# part (B[t-1] -> A[t]) and a solver-transport part (A[t] -> B[t]). Cells have no
# stable identity: region motion is reported as region motion, never as a
# tracked trajectory or a velocity estimate.

const Profiles = preload("res://scripts/transport_profiles.gd")
const PhysicsBridge = preload("res://scripts/rapier_physics_bridge.gd")

const RECORD_SCHEMA: String = "water-contact-impact-record-v1"
const PROBE_SCHEMA: String = "water-contact-kinematic-probe-v1"
const WORLD_SIDE: int = 1024
const EMPTY: int = 0
const WALL: int = 1
const WATER: int = 3
# native/include/cybersand/physics_diagnostics.hpp PhysicsEvent::BodyDisplacement.
# World::move_cell() records it for every relocation made outside a tick, which
# is exactly World::relocate_stored_cell() called by the body adapter.
const BODY_DISPLACEMENT_EVENT: int = 6
const DT: float = 1.0 / 60.0


static func load_manifest(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok":false, "error":"manifest is not a JSON object: " + path}
	var manifest: Dictionary = parsed
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	manifest["_manifest_sha256"] = context.finish().hex_encode()
	manifest["ok"] = true
	return manifest


static func find_by_id(rows: Array, id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("id", "")) == id:
			return row
	return {}


static func request_for(bridge: Variant, family: String, variant: String) -> PackedInt32Array:
	# Second argument is the material (Water = 3); radius is a construction input.
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(), WATER):
		if choice.family == family and choice.variant == variant and choice.accepted:
			return choice.request
	return PackedInt32Array()


static func geometry(manifest: Dictionary, case: Dictionary) -> Dictionary:
	var basin: Dictionary = manifest.world.basin
	var left: int = int(basin.left)
	var width: int = int(basin.width)
	var floor_y: int = int(basin.floor_y)
	var wall_top: int = int(basin.wall_top_y)
	var depth: int = int(case.get("depth", 0))
	var surface: int = floor_y - depth
	var roi_top: int = maxi(wall_top, surface - int(manifest.observation.roi_rows_above_surface))
	return {"left":left, "width":width, "floor_y":floor_y, "wall_top":wall_top, "depth":depth,
		"surface":surface, "roi_origin":Vector2i(left, roi_top), "roi_size":Vector2i(width, floor_y - roi_top),
		"spray_band":int(manifest.observation.spray_band_rows)}


static func rectangles(geo: Dictionary, with_water: bool) -> PackedInt32Array:
	var left: int = geo.left
	var width: int = geo.width
	var floor_y: int = geo.floor_y
	var wall_top: int = geo.wall_top
	var out := PackedInt32Array([
		left - 1, wall_top, 1, floor_y - wall_top, WALL,
		left + width, wall_top, 1, floor_y - wall_top, WALL,
		left - 1, floor_y, width + 2, 1, WALL])
	if with_water and int(geo.depth) > 0:
		out.append_array(PackedInt32Array([left, geo.surface, width, geo.depth, WATER]))
	return out


# Fresh adapter, fresh World, explicit applied-policy readback. Never falls back:
# any refusal or readback mismatch returns ok=false with the typed reason.
static func build_world(bridge: Variant, manifest: Dictionary, arm: Dictionary, workers: int,
		rects: PackedInt32Array) -> Dictionary:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if world == null or not world.diagnostic_reset({"workers":workers}):
		return {"ok":false, "error":"diagnostic reset refused workers=%d" % workers}
	world.set_simulation_window_enabled(false)
	var request: PackedInt32Array = request_for(bridge, arm.family, arm.variant)
	var profile: Dictionary = Profiles.resolve(Profiles.preset(int(manifest.world.transport_profile_preset)))
	if request.is_empty() or not profile.get("ok", false):
		return {"ok":false, "error":"no accepted native choice for %s/%s" % [arm.family, arm.variant]}
	var generation_before: int = int(world.get_liquid_policy_session_generation())
	var built: bool = bridge.build_liquid_policy_world(world, rects, profile.packed,
		PackedInt32Array(manifest.world.water_experiment_policy), PackedInt32Array(), request, int(arm.radius))
	if not built:
		return {"ok":false, "error":"construction refused", "bridge_error":str(bridge.get_last_error()),
			"refusal":bridge.get_last_liquid_policy_refusal()}
	var policy: Dictionary = world.get_liquid_solver_policy()
	var water: Dictionary = {}
	for assignment: Dictionary in policy.get("assignments", []):
		if int(assignment.material) == WATER:
			water = assignment
	var identity: Dictionary = {
		"requested_family":arm.family, "requested_variant":arm.variant, "requested_radius":int(arm.radius),
		"applied_family":str(water.get("applied_family", "")), "applied_variant":str(water.get("applied_variant", "")),
		"applied_radius":int(policy.get("maximum_rule_radius", -1)),
		"minimum_rule_radius":int(policy.get("minimum_rule_radius", -1)),
		"policy_hash":str(policy.get("policy_hash", "")), "admission":str(policy.get("admission", "")),
		"physical_state_hash_version":int(world.get_physical_state_hash_version()),
		"session_generation_before":generation_before,
		"session_generation":int(world.get_liquid_policy_session_generation()),
		"backend":str(world.get_backend_name()), "configured_workers":int(world.get_worker_threads()),
		"run_receipt_components":(world.get_liquid_run_receipt({}) as Dictionary).get("components", {}),
	}
	var matches: bool = identity.applied_family == arm.family and identity.applied_variant == arm.variant \
		and identity.applied_radius == int(arm.radius) and identity.backend == "native-phased" \
		and identity.configured_workers == workers
	return {"ok":matches, "error":"" if matches else "applied identity differs from request",
		"world":world, "identity":identity}


static func runtime_identity(bridge: Variant) -> Dictionary:
	var loaded: Dictionary = bridge.loaded_native_runtime_values()
	var provenance_path: String = "res://addons/cybersand_native/runtime-provenance.json"
	if OS.get_name() == "Linux":
		provenance_path = "res://addons/cybersand_native/runtime-provenance.linux.json"
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string(provenance_path))
	var expected: String = str((provenance as Dictionary).get("sha256", "")) if provenance is Dictionary else ""
	var version: Dictionary = Engine.get_version_info()
	return {"os":OS.get_name(), "godot":"%s.%s.%s.%s" % [version.major, version.minor, version.patch, version.status],
		"godot_hash":str(version.get("hash", "")),
		"physics_engine_setting":str(ProjectSettings.get_setting("physics/2d/physics_engine", "")),
		"rapier_server_class_present":ClassDB.class_exists(&"RapierPhysicsServer2D"),
		"native_runtime_current_file_sha256":str(loaded.get("current_file_sha256", "")),
		"native_runtime_path":str(loaded.get("api_reported_library_path", "")),
		"native_runtime_mapped_module_binding":str(loaded.get("mapped_module_binding", "")),
		"provenance_sha256":expected,
		"provenance_source_commit":str((provenance as Dictionary).get("source_commit", "")) if provenance is Dictionary else "",
		"runtime_matches_provenance":expected != "" and expected == str(loaded.get("current_file_sha256", "")),
		"processor_count":OS.get_processor_count()}


# Copied stored state that World::move_cell() must carry unchanged.
static func carried_state(bridge: Variant, world: Variant, point: Vector2i, inertial: bool) -> String:
	var cell: Dictionary = bridge.inspect_cell(world, point)
	var text: String = "%d,%d,%d" % [int(cell.get("material", -1)), int(cell.get("state_a", -1)), int(cell.get("state_b", -1))]
	if cell.has("family_state"):
		var family: Dictionary = cell.family_state
		text += ",pf:%d,%d" % [int(family.get("overfill", -1)), int(family.get("flow", -1))]
	if inertial:
		var motion: Dictionary = world.inspect_inertial_cell(point)
		text += ",in:%d,%d,%d,%d" % [int(motion.get("vx", 0)), int(motion.get("vy", 0)),
			int(motion.get("ax", 0)), int(motion.get("ay", 0))]
	return text


static func body_displacement_counts(histogram: Array) -> Dictionary:
	var out: Dictionary = {"up":0, "lateral":0, "down":0, "left":0, "right":0, "other_material":0, "total":0}
	for entry: Variant in histogram:
		var key: int = int(entry[0])
		if (key >> 24) & 255 != BODY_DISPLACEMENT_EVENT:
			continue
		var count: int = int(entry[1])
		if (key >> 16) & 255 != WATER:
			out.other_material += count
			continue
		var direction: int = key & 255
		var dy: int = direction / 3 - 1
		var dx: int = direction % 3 - 1
		out.total += count
		if dy < 0: out.up += count
		elif dy > 0: out.down += count
		else: out.lateral += count
		if dx < 0: out.left += count
		elif dx > 0: out.right += count
	return out


static func counts_delta(now: Dictionary, before: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in now:
		out[key] = int(now[key]) - int(before.get(key, 0))
	return out


static func body_extent(rotation: float, size: Vector2) -> Vector2:
	return Vector2(absf(cos(rotation)) * size.x + absf(sin(rotation)) * size.y,
		absf(sin(rotation)) * size.x + absf(cos(rotation)) * size.y)


# Expected current-pose mask using the adapter's documented rasterization rule
# (cell centre inside the rotated rectangle). Compared with rigid_body_id_at().
# Stored material from a copied ROI snapshot. material_at() is occupancy-masked
# (a body-covered cell reads as the obstacle), so it must not be used to find
# stored Water under a body. Outside the interior ROI the basin is hard terrain
# or open air; -1 means "not observed by this snapshot".
static func stored(cells: PackedByteArray, geo: Dictionary, x: int, y: int) -> int:
	var origin: Vector2i = geo.roi_origin
	var size: Vector2i = geo.roi_size
	if x < origin.x or y < origin.y or x >= origin.x + size.x or y >= origin.y + size.y:
		return -1
	return cells[(y - origin.y) * size.x + x - origin.x]


static func mask_check(world: Variant, cells: PackedByteArray, geo: Dictionary, center: Vector2, rotation: float,
		size: Vector2) -> Dictionary:
	var extent: Vector2 = body_extent(rotation, size)
	var first: Vector2i = Vector2i(floori(center.x - extent.x / 2.0) - 2, floori(center.y - extent.y / 2.0) - 2)
	var last: Vector2i = Vector2i(ceili(center.x + extent.x / 2.0) + 2, ceili(center.y + extent.y / 2.0) + 2)
	var expected: int = 0
	var observed: int = 0
	var mismatched: int = 0
	var masked_water: int = 0
	var unobserved: int = 0
	# Mirror rasterize_transform_in exactly: double cos/sin, single-precision
	# Vector2 delta/local/half storage. (Vector2.rotated() rounds differently and
	# misclassified one exact-edge cell in water_contact.submerged.v1 stage 2.)
	var c: float = cos(rotation)
	var s: float = sin(rotation)
	var half := Vector2(maxf(0.5, size.x * 0.5), maxf(0.5, size.y * 0.5))
	for y: int in range(maxi(0, first.y), mini(WORLD_SIDE, last.y)):
		for x: int in range(maxi(0, first.x), mini(WORLD_SIDE, last.x)):
			var delta := Vector2(x + 0.5 - center.x, y + 0.5 - center.y)
			var local := Vector2(c * delta.x + s * delta.y, -s * delta.x + c * delta.y)
			var inside: bool = absf(local.x) <= half.x and absf(local.y) <= half.y
			var id: int = int(world.rigid_body_id_at(x, y))
			var material: int = stored(cells, geo, x, y)
			# Wall columns/floor lie outside the interior ROI; the adapter never
			# masks hard terrain (Rapier owns that contact).
			var hard: bool = material == -1 and (x < int(geo.left) or x >= int(geo.left) + int(geo.width) or y >= int(geo.floor_y))
			if material == -1 and not hard: unobserved += 1
			if inside and not hard: expected += 1
			if id != 0: observed += 1
			if not hard and (id == 1) != inside: mismatched += 1
			if id != 0 and material == WATER: masked_water += 1
	return {"expected":expected, "observed":observed, "mismatched":mismatched, "masked_water_cells":masked_water,
		"unobserved_cells":unobserved}


static func spray_metrics(world: Variant, cells: PackedByteArray, geo: Dictionary) -> Dictionary:
	var origin: Vector2i = geo.roi_origin
	var size: Vector2i = geo.roi_size
	var surface: int = geo.surface
	var band_limit: int = surface - int(geo.spray_band)
	var highest: int = 2147483647
	var above_cells: int = 0
	var band_cells: int = 0
	var band_min_x: int = 2147483647
	var band_max_x: int = -1
	var isolated: int = 0
	var unsupported: int = 0
	var rows_above: int = mini(size.y, surface - origin.y)
	for local_y: int in range(rows_above):
		var row: int = local_y * size.x
		for local_x: int in range(size.x):
			if cells[row + local_x] != WATER:
				continue
			var y: int = origin.y + local_y
			var x: int = origin.x + local_x
			above_cells += 1
			highest = mini(highest, y)
			if y >= band_limit:
				continue
			band_cells += 1
			band_min_x = mini(band_min_x, x)
			band_max_x = maxi(band_max_x, x)
			var neighbours: int = 0
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					if dx == 0 and dy == 0: continue
					var nx: int = local_x + dx
					var ny: int = local_y + dy
					if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y: continue
					if cells[ny * size.x + nx] == WATER: neighbours += 1
			if neighbours == 0: isolated += 1
			var below: int = cells[row + size.x + local_x] if local_y + 1 < size.y else WALL
			if below == EMPTY and int(world.rigid_body_id_at(x, y + 1)) == 0:
				unsupported += 1
	if highest == 2147483647:
		# No Water above the initial surface: report the first Water row in the ROI.
		for index: int in range(cells.size()):
			if cells[index] == WATER:
				highest = origin.y + index / size.x
				break
	return {"above_cells":above_cells, "band_cells":band_cells,
		"peak_height":(surface - highest) if highest != 2147483647 else null,
		"band_span":[band_min_x, band_max_x] if band_cells > 0 else null,
		"band_isolated":isolated, "band_unsupported":unsupported}


static func inertial_census(world: Variant, cells: PackedByteArray, geo: Dictionary) -> Dictionary:
	var origin: Vector2i = geo.roi_origin
	var size: Vector2i = geo.roi_size
	var rows_above: int = mini(size.y, int(geo.surface) - origin.y)
	var out: Dictionary = {"cells":0, "moving":0, "negative_vy":0, "max_vy":0, "min_vy":0, "max_abs_vx":0,
		"sum_vy":0, "sum_abs_vx":0}
	for local_y: int in range(rows_above):
		for local_x: int in range(size.x):
			if cells[local_y * size.x + local_x] != WATER:
				continue
			var motion: Dictionary = world.inspect_inertial_cell(Vector2i(origin.x + local_x, origin.y + local_y))
			if not motion.get("inertial_family", false):
				continue
			var vx: int = int(motion.vx)
			var vy: int = int(motion.vy)
			out.cells += 1
			if vx != 0 or vy != 0: out.moving += 1
			if vy < 0: out.negative_vy += 1
			out.max_vy = maxi(int(out.max_vy), vy)
			out.min_vy = mini(int(out.min_vy), vy)
			out.max_abs_vx = maxi(int(out.max_abs_vx), absi(vx))
			out.sum_vy += vy
			out.sum_abs_vx += absi(vx)
	return out


static func quantiles(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n":0}
	var ordered: Array = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: Variant in ordered: total += float(value)
	return {"n":ordered.size(), "p50":ordered[ordered.size() / 2], "p95":ordered[mini(ordered.size() - 1, ordered.size() * 95 / 100)],
		"max":ordered[-1], "sum":total}


static func water_region(world: Variant, origin: Vector2i, size: Vector2i) -> Dictionary:
	if size.x < 1 or size.y < 1:
		return {"quantity":0, "visible":0, "overfill":0, "cells":0}
	var observed: Dictionary = world.water_experiment_observation(origin, size)
	return {"quantity":int(observed.get("water_integer", -1)), "visible":int(observed.get("water_visible", -1)),
		"overfill":int(observed.get("water_overfill", -1)), "cells":int(observed.get("water_cells", -1))}


# One registered dynamic run: actual Rapier body in an independently and
# manually stepped space, one Rapier step per native tick, native results
# applied back with the tick serial (bridge stale/duplicate rules unchanged).
# `observer` (optional, default null) is a read-only sampler with
# sample(world, tick, states, cells_a, geo, body_size, results) and summary().
# It sees observation A (post-coupling stored bytes; the body mask is unchanged
# by the tick) and changes nothing. With null, v1 behaviour is unchanged.
static func run_case(host: Node, bridge: Variant, manifest: Dictionary, case: Dictionary, arm: Dictionary,
		workers: int, observer: Variant = null) -> Dictionary:
	var geo: Dictionary = geometry(manifest, case)
	var with_water: bool = bool(case.get("water", true)) and int(case.get("depth", 0)) > 0
	var with_body: bool = bool(case.get("body", true))
	var horizon: int = int(case.get("ticks", manifest.horizon_ticks))
	var record: Dictionary = {"schema":RECORD_SCHEMA, "experiment":manifest.experiment_id,
		"manifest_sha256":manifest._manifest_sha256, "case":case.id, "arm":arm.id, "family":arm.family,
		"variant":arm.variant, "radius":int(arm.radius), "workers_configured":workers, "horizon":horizon,
		"geometry":{"left":geo.left, "width":geo.width, "floor_y":geo.floor_y, "wall_top":geo.wall_top,
			"depth":geo.depth, "surface":geo.surface, "roi":[geo.roi_origin.x, geo.roi_origin.y, geo.roi_size.x, geo.roi_size.y],
			"spray_band_rows":geo.spray_band},
		"runtime":runtime_identity(bridge), "ok":false, "violations":[]}
	var built: Dictionary = build_world(bridge, manifest, arm, workers, rectangles(geo, with_water))
	if not built.get("ok", false):
		record["error"] = built.get("error", "construction")
		record["construction"] = built.duplicate()
		record.construction.erase("world")
		return record
	var world: Variant = built.world
	record["identity"] = built.identity
	# Quantity regions are the interior observation ROI (basin interior from
	# roi_top to the floor). ROI quantity equal to the construction quantity at
	# every tick proves both conservation and that no Water left the ROI (over a
	# wall, through the floor, or above roi_top); the complete World is also
	# observed every `global_stride` ticks and at the end. Native region
	# observers cost about 0.27 us per scanned cell, so this keeps the run bounded.
	var interior_origin: Vector2i = geo.roi_origin
	var interior_size: Vector2i = geo.roi_size
	var above_size := Vector2i(geo.width, int(geo.surface) - int(geo.roi_origin.y))
	var band_size := Vector2i(geo.width, maxi(0, int(geo.surface) - int(geo.spray_band) - int(geo.roi_origin.y)))
	var global_stride: int = int(manifest.observation.get("global_stride", 10))
	var initial_global: Dictionary = water_region(world, Vector2i.ZERO, Vector2i(WORLD_SIDE, WORLD_SIDE))
	var initial_interior: Dictionary = water_region(world, interior_origin, interior_size)
	record["initial_water"] = {"global":initial_global, "interior":initial_interior,
		"expected_whole_cell_quantity":int(geo.width) * int(geo.depth) * 255 if with_water else 0,
		"normalization":"none: rectangle-constructed whole-cell Water (255 per cell) in every arm"}
	var inertial: bool = arm.family == "inertial_cellular_v1"
	var pressure: bool = arm.family == "pressure_flow_v1"

	var viewport: SubViewport = null
	var body: RigidBody2D = null
	var physics: Variant = null
	var body_size := Vector2(case.get("body_size", manifest.body.size)[0], case.get("body_size", manifest.body.size)[1])
	var rotation0: float = float(case.get("rotation", 0.0))
	var extent0: Vector2 = body_extent(rotation0, body_size)
	var start := Vector2(float(geo.left) + float(geo.width) / 2.0 + float(case.get("offset_x", 0.0)),
		float(geo.surface) - float(manifest.body.initial_gap_cells) - extent0.y / 2.0)
	if bool(case.get("start_on_floor_gap", false)):
		start.y = float(geo.floor_y) - float(manifest.body.initial_gap_cells) - extent0.y / 2.0 - float(case.get("start_above_floor", 0.0))
	var velocity0 := Vector2(float(case.get("velocity_x", 0.0)), float(case.get("velocity_y", 0.0)))
	if with_body:
		viewport = SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.size = Vector2i(128, 128)
		host.add_child(viewport)
		body = RigidBody2D.new()
		body.mass = float(manifest.body.mass)
		body.gravity_scale = float(manifest.body.gravity_scale)
		body.linear_damp = float(manifest.body.linear_damp)
		body.angular_damp = float(manifest.body.angular_damp)
		body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		body.position = start
		body.rotation = rotation0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = body_size
		shape.shape = rectangle
		body.add_child(shape)
		viewport.add_child(body)
		physics = PhysicsBridge.new()
		var bodies: Array[RigidBody2D] = [body]
		if physics.initialize(viewport.world_2d.space, bodies, PackedVector2Array([body_size])) != OK:
			viewport.free()
			record["error"] = "actual Rapier space initialization refused"
			return record
		physics.enable_diagnostics()
		PhysicsServer2D.body_set_param(body.get_rid(), PhysicsServer2D.BODY_PARAM_FRICTION, float(manifest.body.friction))
		physics.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
		physics.reset_body(0, start, rotation0)
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity0)
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,
			float(case.get("angular_velocity", 0.0)))
		physics.refresh_all_states()
		record["body"] = {"size":[body_size.x, body_size.y], "mass":body.mass,
			"inertia_reported":float(PhysicsServer2D.body_get_param(body.get_rid(), PhysicsServer2D.BODY_PARAM_INERTIA)),
			"gravity_scale":body.gravity_scale, "linear_damp":body.linear_damp, "angular_damp":body.angular_damp,
			"friction":float(manifest.body.friction), "ccd":"cast_shape", "initial_center":[start.x, start.y],
			"initial_rotation":rotation0, "initial_velocity":[velocity0.x, velocity0.y],
			"initial_angular_velocity":float(case.get("angular_velocity", 0.0)),
			"hard_surface_shapes":int(physics.hard_surface_shape_count())}

	var trace_context := HashingContext.new()
	trace_context.start(HashingContext.HASH_SHA256)
	var violations: Array = []
	var add_violation := func(kind: String, tick: int, detail: Variant) -> void:
		if violations.size() < 64:
			violations.append({"kind":kind, "tick":tick, "detail":detail})
	var prev_cells: PackedByteArray = world.diagnostic_snapshot(geo.roi_origin, geo.roi_size, false).get("cells", PackedByteArray())
	var prev_hist: Dictionary = body_displacement_counts(world.diagnostic_snapshot(geo.roi_origin, Vector2i(1, 1), true).get("histogram", []))
	var initial_hist: Dictionary = prev_hist.duplicate()
	var prev_above: Dictionary = water_region(world, interior_origin, above_size)
	var prev_band: Dictionary = water_region(world, interior_origin, band_size)
	var initial_above_quantity: int = int(prev_above.quantity)
	var sums: Dictionary = {"relocation_above_gain":0, "relocation_above_loss":0, "solver_above_gain":0,
		"solver_above_loss":0, "relocation_band_gain":0, "solver_band_gain":0, "solver_band_loss":0,
		"solver_peak_rises":0, "relocation_peak_rises":0, "solver_rise_rows":0, "relocation_rise_rows":0}
	var totals: Dictionary = {"contacts":0, "displaced":0, "unresolved":0, "results_applied":0, "stale_rejected":0,
		"destinations_in_roi":0, "destinations_above_surface":0, "destinations_in_band":0,
		"max_destination_height":null, "carried_state_checks":0, "carried_state_mismatches":0,
		"carried_state_incomplete":0, "masked_water_cell_ticks":0, "max_masked_water_cells":0,
		"masked_water_samples":[]}
	var peak: Dictionary = {"band_quantity":0, "band_tick":-1, "above_quantity":initial_above_quantity, "above_tick":0,
		"height":null, "height_tick":-1, "relocations_per_tick":0, "relocations_tick":-1, "band_span":null,
		"band_isolated":0, "band_unsupported":0}
	var series: Array = []
	var tick_us: Array = []
	var coupling_us: Array = []
	var rapier_ms: Array = []
	var participants: Dictionary = {}
	var phase_max: Array = []
	var in_summary: Dictionary = {"censuses":0, "negative_vy":0, "max_vy":0, "max_abs_vx":0, "max_moving":0,
		"destinations_negative_vy":0, "destinations_checked":0, "destination_max_vy":0}
	var pf_summary: Dictionary = {"max_overfill":0, "gas_observations":0, "max_compartments":0, "ledger_closes_all":true}
	var body_trace: Array = []
	var max_floor_penetration: float = 0.0
	var max_wall_penetration: float = 0.0
	var floor_contact_tick: int = -1
	var mask_summary: Dictionary = {"checks":0, "mismatched_cells":0, "max_expected":0, "max_observed":0}
	var last_band_nonzero: int = -1
	var carried_budget: int = int(manifest.observation.carried_state_check_ticks)
	var census_stride: int = int(manifest.observation.census_stride)
	var series_stride: int = int(manifest.observation.series_stride)
	var empty_states := PackedFloat32Array()
	var last_results := PackedFloat32Array()
	var stale_probe: Dictionary = {}
	var prev_spray: Dictionary = spray_metrics(world, prev_cells, geo)
	var last_peak_b: Variant = prev_spray.peak_height
	var global_checks: int = 0
	for tick: int in range(horizon):
		var states: PackedFloat32Array = empty_states
		var center := Vector2.ZERO
		var rotation: float = 0.0
		var candidates: Dictionary = {}
		if with_body:
			physics.step()
			rapier_ms.append(float(physics.last_step_time_ms()))
			states = physics.pack_body_states()
			center = Vector2(states[1], states[2])
			rotation = states[3]
			# Bounded carried-state candidates: every stored Water cell inside the
			# union of the previous and current body boxes, read BEFORE coupling.
			if carried_budget > 0 and with_water:
				var extent: Vector2 = body_extent(rotation, body_size)
				var previous_center: Vector2 = center
				if not body_trace.is_empty():
					previous_center = Vector2(body_trace[-1][1], body_trace[-1][2])
				var lo := Vector2i(floori(minf(center.x, previous_center.x) - extent.x) - 2,
					floori(minf(center.y, previous_center.y) - extent.y) - 2)
				var hi := Vector2i(ceili(maxf(center.x, previous_center.x) + extent.x) + 2,
					ceili(maxf(center.y, previous_center.y) + extent.y) + 2)
				for y: int in range(maxi(lo.y, geo.wall_top), mini(hi.y, geo.floor_y)):
					for x: int in range(maxi(lo.x, geo.left), mini(hi.x, int(geo.left) + int(geo.width))):
						if stored(prev_cells, geo, x, y) == WATER:
							candidates[Vector2i(x, y)] = carried_state(bridge, world, Vector2i(x, y), inertial)
		var started: int = Time.get_ticks_usec()
		world.prepare_rigid_body_coupling(states)
		coupling_us.append(Time.get_ticks_usec() - started)
		# Observation A: relocation applied, transport not yet run.
		# Coupling changes stored material only by relocation, so on a tick with
		# no BodyDisplacement event A equals the previous B and is not re-read.
		var hist_now: Dictionary = body_displacement_counts(world.diagnostic_snapshot(geo.roi_origin, Vector2i(1, 1), true).get("histogram", []))
		var relocated: Dictionary = counts_delta(hist_now, prev_hist)
		prev_hist = hist_now
		var cells_a: PackedByteArray = prev_cells
		var above_a: Dictionary = prev_above
		var band_a: Dictionary = prev_band
		var spray_a: Dictionary = prev_spray
		if int(relocated.total) != 0 or int(relocated.other_material) != 0:
			cells_a = world.diagnostic_snapshot(geo.roi_origin, geo.roi_size, false).get("cells", PackedByteArray())
			above_a = water_region(world, interior_origin, above_size)
			band_a = water_region(world, interior_origin, band_size)
			spray_a = spray_metrics(world, cells_a, geo)
		var destinations: Array = []
		var sources: Array = []
		for index: int in range(cells_a.size()):
			var before: int = prev_cells[index]
			var after: int = cells_a[index]
			if before == EMPTY and after == WATER:
				destinations.append(Vector2i(int(geo.roi_origin.x) + index % int(geo.roi_size.x), int(geo.roi_origin.y) + index / int(geo.roi_size.x)))
			elif before == WATER and after == EMPTY:
				sources.append(Vector2i(int(geo.roi_origin.x) + index % int(geo.roi_size.x), int(geo.roi_origin.y) + index / int(geo.roi_size.x)))
		totals.destinations_in_roi += destinations.size()
		for point: Vector2i in destinations:
			var height: int = int(geo.surface) - point.y
			if point.y < int(geo.surface): totals.destinations_above_surface += 1
			if point.y < int(geo.surface) - int(geo.spray_band): totals.destinations_in_band += 1
			totals.max_destination_height = height if totals.max_destination_height == null else maxi(int(totals.max_destination_height), height)
			if inertial and in_summary.destinations_checked < 4096:
				var motion: Dictionary = world.inspect_inertial_cell(point)
				in_summary.destinations_checked += 1
				in_summary.destination_max_vy = maxi(int(in_summary.destination_max_vy), int(motion.get("vy", 0)))
				if int(motion.get("vy", 0)) < 0: in_summary.destinations_negative_vy += 1
		if relocated.total != destinations.size() or sources.size() != destinations.size():
			add_violation.call("relocation_census_mismatch", tick + 1, {"histogram":relocated.total,
				"destinations":destinations.size(), "sources":sources.size()})
		if not candidates.is_empty() and relocated.total > 0:
			carried_budget -= 1
			var before_states: Array = []
			var complete: bool = true
			for point: Vector2i in sources:
				if candidates.has(point): before_states.append(candidates[point])
				else: complete = false
			var after_states: Array = []
			for point: Vector2i in destinations:
				after_states.append(carried_state(bridge, world, point, inertial))
			before_states.sort()
			after_states.sort()
			if not complete:
				totals.carried_state_incomplete += 1
			else:
				totals.carried_state_checks += 1
				if before_states != after_states:
					totals.carried_state_mismatches += 1
					add_violation.call("carried_state_changed", tick + 1, {"before":before_states.slice(0, 8), "after":after_states.slice(0, 8)})
		if int(relocated.total) > int(peak.relocations_per_tick):
			peak.relocations_per_tick = int(relocated.total)
			peak.relocations_tick = tick + 1
		if int(relocated.total) != 0:
			var interior_a: Dictionary = water_region(world, interior_origin, interior_size)
			if int(interior_a.quantity) != int(initial_interior.quantity):
				add_violation.call("roi_quantity_after_coupling", tick + 1, {"observed":interior_a.quantity, "initial":initial_interior.quantity})

		started = Time.get_ticks_usec()
		var succeeded: bool = world.simulation_tick()
		tick_us.append(Time.get_ticks_usec() - started)
		if not succeeded or world.has_failed():
			add_violation.call("tick_failure", tick + 1, str(world.get_last_tick_error()))
			break
		var stats: Dictionary = bridge.inspect_statistics(world)
		var observed_workers: int = int(stats.get("values", {}).get("worker_threads_observed", -1))
		participants[str(observed_workers)] = int(participants.get(str(observed_workers), 0)) + 1
		var phases: Array = stats.get("phase_jobs_last_tick", [])
		for phase_index: int in range(phases.size()):
			if phase_max.size() <= phase_index: phase_max.append(0)
			phase_max[phase_index] = maxi(int(phase_max[phase_index]), int(phases[phase_index]))
		var results: PackedFloat32Array = world.rigid_body_results()
		if observer != null and with_body:
			observer.sample(world, tick, states, cells_a, geo, body_size, results)
		if with_body:
			if results.size() != CyberRigidBodyCoupling.RESULT_STRIDE:
				add_violation.call("result_count", tick + 1, results.size())
			if results.size() >= 9:
				totals.contacts += int(results[5])
				totals.displaced += int(results[6])
				totals.unresolved += int(results[7])
				if int(results[6]) != int(relocated.total):
					add_violation.call("displaced_vs_histogram", tick + 1, {"result":int(results[6]), "histogram":relocated.total})
			totals.results_applied += int(physics.apply_cellular_results(tick + 1, results))
			totals.stale_rejected += int(physics.last_stale_results_rejected())
			if int(physics.manual_step_count()) != tick + 1:
				add_violation.call("rapier_step_count", tick + 1, int(physics.manual_step_count()))
			if bool(case.get("stale_duplicate_probe", false)):
				stale_probe = stale_duplicate_probe(physics, tick, results, last_results, stale_probe)
			last_results = results
			trace_context.update(states.to_byte_array())
			trace_context.update(results.to_byte_array())
		elif results.size() != 0:
			add_violation.call("body_free_result", tick + 1, results.size())

		# Observation B: liquid transport applied.
		var cells_b: PackedByteArray = world.diagnostic_snapshot(geo.roi_origin, geo.roi_size, false).get("cells", PackedByteArray())
		var above_b: Dictionary = water_region(world, interior_origin, above_size)
		var band_b: Dictionary = water_region(world, interior_origin, band_size)
		var interior_b: Dictionary = water_region(world, interior_origin, interior_size)
		var spray_b: Dictionary = spray_metrics(world, cells_b, geo)
		if int(interior_b.quantity) != int(initial_interior.quantity):
			add_violation.call("roi_quantity", tick + 1, {"observed":interior_b.quantity, "initial":initial_interior.quantity})
		if tick % global_stride == global_stride - 1 or tick == horizon - 1:
			var global_b: Dictionary = water_region(world, Vector2i.ZERO, Vector2i(WORLD_SIDE, WORLD_SIDE))
			global_checks += 1
			if int(global_b.quantity) != int(initial_global.quantity):
				add_violation.call("global_quantity", tick + 1, {"observed":global_b.quantity, "initial":initial_global.quantity})
			if int(global_b.quantity) != int(interior_b.quantity):
				add_violation.call("outside_basin_water", tick + 1, int(global_b.quantity) - int(interior_b.quantity))
		pf_summary.max_overfill = maxi(int(pf_summary.max_overfill), int(interior_b.overfill))
		if not pressure and int(interior_b.overfill) != 0:
			add_violation.call("overfill_outside_pressure_flow", tick + 1, interior_b.overfill)
		# Exact decomposition of above-surface change.
		var reloc_above: int = int(above_a.quantity) - int(prev_above.quantity)
		var solver_above: int = int(above_b.quantity) - int(above_a.quantity)
		var reloc_band: int = int(band_a.quantity) - int(prev_band.quantity)
		var solver_band: int = int(band_b.quantity) - int(band_a.quantity)
		if reloc_above > 0: sums.relocation_above_gain += reloc_above
		else: sums.relocation_above_loss -= reloc_above
		if solver_above > 0: sums.solver_above_gain += solver_above
		else: sums.solver_above_loss -= solver_above
		if reloc_band > 0: sums.relocation_band_gain += reloc_band
		if solver_band > 0: sums.solver_band_gain += solver_band
		else: sums.solver_band_loss -= solver_band
		var peak_a: Variant = spray_a.peak_height
		var peak_b: Variant = spray_b.peak_height
		if peak_a != null and last_peak_b != null and int(peak_a) > int(last_peak_b):
			sums.relocation_peak_rises += 1
			sums.relocation_rise_rows += int(peak_a) - int(last_peak_b)
		if peak_a != null and peak_b != null and int(peak_b) > int(peak_a):
			sums.solver_peak_rises += 1
			sums.solver_rise_rows += int(peak_b) - int(peak_a)
		last_peak_b = peak_b
		if int(band_b.quantity) > int(peak.band_quantity):
			peak.band_quantity = int(band_b.quantity)
			peak.band_tick = tick + 1
			peak.band_span = spray_b.band_span
		if int(band_b.quantity) > 0: last_band_nonzero = tick + 1
		if int(above_b.quantity) > int(peak.above_quantity):
			peak.above_quantity = int(above_b.quantity)
			peak.above_tick = tick + 1
		if peak_b != null and (peak.height == null or int(peak_b) > int(peak.height)):
			peak.height = int(peak_b)
			peak.height_tick = tick + 1
		peak.band_isolated = maxi(int(peak.band_isolated), int(spray_b.band_isolated))
		peak.band_unsupported = maxi(int(peak.band_unsupported), int(spray_b.band_unsupported))
		if inertial and (tick % census_stride == 0 or int(spray_b.above_cells) > 0 and tick % census_stride == 0):
			var census: Dictionary = inertial_census(world, cells_b, geo)
			in_summary.censuses += 1
			in_summary.negative_vy += int(census.negative_vy)
			in_summary.max_vy = maxi(int(in_summary.max_vy), int(census.max_vy))
			in_summary.max_abs_vx = maxi(int(in_summary.max_abs_vx), int(census.max_abs_vx))
			in_summary.max_moving = maxi(int(in_summary.max_moving), int(census.moving))
			if int(census.negative_vy) != 0:
				add_violation.call("negative_inertial_vy", tick + 1, census)
		if pressure and tick % (census_stride * 5) == 0:
			var gas: Dictionary = world.inspect_gas_compartments()
			pf_summary.gas_observations += 1
			pf_summary.max_compartments = maxi(int(pf_summary.max_compartments), (gas.get("compartments", []) as Array).size())
			var book: Dictionary = gas.get("ledger", {})
			if book.has("closes") and not bool(book.closes):
				pf_summary.ledger_closes_all = false
				add_violation.call("pressure_gas_ledger_open", tick + 1, book)
		if with_body:
			var transform: Transform2D = physics.body_transform(0)
			var b_center: Vector2 = transform.origin
			var b_rotation: float = transform.get_rotation()
			var b_velocity: Vector2 = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			var b_angular: float = float(PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))
			var b_extent: Vector2 = body_extent(b_rotation, body_size)
			var bottom: float = b_center.y + b_extent.y / 2.0
			var floor_penetration: float = maxf(0.0, bottom - float(geo.floor_y))
			var wall_penetration: float = maxf(maxf(0.0, float(geo.left) - (b_center.x - b_extent.x / 2.0)),
				maxf(0.0, (b_center.x + b_extent.x / 2.0) - float(int(geo.left) + int(geo.width))))
			max_floor_penetration = maxf(max_floor_penetration, floor_penetration)
			max_wall_penetration = maxf(max_wall_penetration, wall_penetration)
			if floor_contact_tick < 0 and bottom >= float(geo.floor_y) - 1.0:
				floor_contact_tick = tick + 1
			body_trace.append([tick + 1, b_center.x, b_center.y, b_velocity.x, b_velocity.y, b_rotation, b_angular,
				int(results[5]) if results.size() >= 9 else 0, int(results[6]) if results.size() >= 9 else 0,
				int(results[7]) if results.size() >= 9 else 0,
				float(results[1]) if results.size() >= 9 else 0.0, float(results[2]) if results.size() >= 9 else 0.0])
			if tick % census_stride == 0:
				var masks: Dictionary = mask_check(world, cells_b, geo, center, rotation, body_size)
				totals.masked_water_samples.append(int(masks.masked_water_cells))
				mask_summary.checks += 1
				mask_summary.mismatched_cells += int(masks.mismatched)
				mask_summary.max_expected = maxi(int(mask_summary.max_expected), int(masks.expected))
				mask_summary.max_observed = maxi(int(mask_summary.max_observed), int(masks.observed))
				if int(masks.masked_water_cells) > 0: totals.masked_water_cell_ticks += 1
				totals.max_masked_water_cells = maxi(int(totals.max_masked_water_cells), int(masks.masked_water_cells))
				if int(masks.mismatched) != 0:
					add_violation.call("mask_mismatch", tick + 1, masks)
		if tick % series_stride == 0 or tick == horizon - 1:
			series.append({"tick":tick + 1, "above":int(above_b.quantity), "band":int(band_b.quantity),
				"peak_height":peak_b, "band_cells":int(spray_b.band_cells), "isolated":int(spray_b.band_isolated),
				"unsupported":int(spray_b.band_unsupported), "relocated_up":int(relocated.up),
				"relocated_lateral":int(relocated.lateral), "relocated_down":int(relocated.down),
				"reloc_above":reloc_above, "solver_above":solver_above, "overfill":int(interior_b.overfill),
				"masked_water":totals.masked_water_samples[-1] if with_body and not totals.masked_water_samples.is_empty() else 0,
				"body_y":body_trace[-1][2] if with_body and not body_trace.is_empty() else null,
				"body_vy":body_trace[-1][4] if with_body and not body_trace.is_empty() else null})
		if tick % 10 == 0:
			trace_context.update(str(world.get_physical_state_hash()).to_utf8_buffer())
		prev_cells = cells_b
		prev_above = above_b
		prev_band = band_b
		prev_spray = spray_b
		if tick % 120 == 119:
			await host.get_tree().process_frame

	var final_hist: Dictionary = counts_delta(prev_hist, initial_hist)
	var return_tick: Variant = null
	if int(peak.band_quantity) > 0 and last_band_nonzero >= 0 and last_band_nonzero < horizon - int(manifest.observation.return_quiet_ticks):
		return_tick = last_band_nonzero + 1
	var masked_samples: Array = totals.masked_water_samples
	totals.erase("masked_water_samples")
	totals["masked_water_cells"] = quantiles(masked_samples)
	totals["global_checks"] = global_checks
	record["relocation"] = {"histogram_total":final_hist, "results":totals}
	record["decomposition"] = sums
	record["peaks"] = peak
	record["return"] = {"band_return_tick":return_tick, "last_band_nonzero_tick":last_band_nonzero,
		"censored":return_tick == null and int(peak.band_quantity) > 0,
		"rule":"first tick after the last nonzero spray-band quantity, if it is followed by at least return_quiet_ticks zero ticks"}
	record["inertial"] = in_summary if inertial else {"available":false}
	record["pressure"] = pf_summary if pressure else {"available":false}
	if pressure:
		record.pressure["final_ledger"] = world.get_pressure_flow_ledger()
	record["boundary"] = {"max_body_floor_penetration":max_floor_penetration, "max_body_wall_penetration":max_wall_penetration,
		"floor_contact_tick":floor_contact_tick}
	record["mask"] = mask_summary
	record["cost"] = {"native_tick_us":quantiles(tick_us), "coupling_us":quantiles(coupling_us),
		"rapier_step_ms":quantiles(rapier_ms), "scope":"headless host timings around single calls; not displayed FPS"}
	record["workers"] = {"configured":workers, "observed_participant_histogram":participants, "phase_jobs_max":phase_max,
		"scope":"worker_threads_observed = maximum distinct task-claiming participants in one dispatch of a completed tick"}
	record["final"] = {"physical_state_hash":str(world.get_physical_state_hash()), "global_water":water_region(world, Vector2i.ZERO, Vector2i(WORLD_SIDE, WORLD_SIDE)),
		"completed_ticks":int(world.get_tick_index()), "tick_failures":int(world.get_tick_failure_count()), "failed":bool(world.has_failed())}
	if with_body:
		record["rapier"] = {"manual_steps":int(physics.manual_step_count()), "results_applied":totals.results_applied,
			"stale_rejected":totals.stale_rejected}
		if not stale_probe.is_empty(): record["stale_duplicate_probe"] = stale_probe
		var sampled: Array = []
		for index: int in range(body_trace.size()):
			if index % series_stride == 0 or index == body_trace.size() - 1: sampled.append(body_trace[index])
		record["body_trace"] = sampled
		record["body_trace_columns"] = ["tick", "x", "y", "vx", "vy", "rotation", "angular_velocity", "contacts", "displaced", "unresolved", "impulse_x", "impulse_y"]
	record["series"] = series
	if observer != null:
		record["observer"] = observer.summary()
	record["trace_sha256"] = trace_context.finish().hex_encode()
	record["violations"] = violations
	if with_body:
		physics.shutdown()
		viewport.free()
	record["ok"] = violations.is_empty() and int(record.final.completed_ticks) == horizon
	return record


# Bounded rejection control inside one registered run: an exact duplicate of
# the just-applied result and an aged (>8 samples) earlier result must both be
# refused by the unchanged Rapier bridge and apply no impulse.
static func stale_duplicate_probe(physics: Variant, tick: int, results: PackedFloat32Array,
		last_results: PackedFloat32Array, probe: Dictionary) -> Dictionary:
	var out: Dictionary = probe.duplicate()
	if tick == 40:
		var duplicate_applied: int = int(physics.apply_cellular_results(tick + 1, results))
		out["duplicate_snapshot_applied"] = duplicate_applied
		out["duplicate_flag"] = float(physics.diagnostic_applications[3]) if physics.diagnostic_applications.size() > 3 else -1.0
		out["held_results"] = results
	if tick == 52 and out.has("held_results"):
		var stale_applied: int = int(physics.apply_cellular_results(1000000 + tick, out.held_results))
		out["stale_applied"] = stale_applied
		out["stale_rejected"] = int(physics.last_stale_results_rejected())
		out.erase("held_results")
	return out


# Kinematic forcing experiment (prescribed body record, no Rapier). One stored
# Water cell is given real retained state, then a body record is placed so the
# adapter's ordinary overlap path relocates exactly that cell. The complete
# carried state is compared before and immediately after coupling, before the
# next tick, then the next tick's motion is observed.
static func kinematic_probe(bridge: Variant, manifest: Dictionary, arm: Dictionary, body_velocity: Vector2,
		mode: String) -> Dictionary:
	var geo: Dictionary = geometry(manifest, {"depth":0})
	var rects: PackedInt32Array = rectangles(geo, false)
	var column: int = int(geo.left) + int(geo.width) / 2
	var start_y: int = int(geo.floor_y) - 200
	rects.append_array(PackedInt32Array([column, start_y, 1, 1, WATER]))
	var built: Dictionary = build_world(bridge, manifest, arm, 1, rects)
	var out: Dictionary = {"schema":PROBE_SCHEMA, "arm":arm.id, "family":arm.family, "mode":mode,
		"body_velocity":[body_velocity.x, body_velocity.y], "ok":false,
		"label":"kinematic forcing experiment: prescribed body record, no Rapier dynamics"}
	if not built.get("ok", false):
		out["error"] = built.get("error", "construction")
		return out
	var world: Variant = built.world
	var inertial: bool = arm.family == "inertial_cellular_v1"
	var free_ticks: int = int(manifest.kinematic_probe.free_fall_ticks)
	for tick: int in range(free_ticks):
		world.prepare_rigid_body_coupling(PackedFloat32Array())
		if not world.simulation_tick():
			out["error"] = "tick failure during free fall"
			return out
	var source: Vector2i = Vector2i(-1, -1)
	for y: int in range(int(geo.wall_top), int(geo.floor_y)):
		if int(world.material_at(column, y)) == WATER:
			source = Vector2i(column, y)
			break
	if source.x < 0:
		out["error"] = "probe cell not found"
		return out
	var quantity_before: int = int(world.water_experiment_observation(Vector2i.ZERO, Vector2i(WORLD_SIDE, WORLD_SIDE)).water_integer)
	var state_before: String = carried_state(bridge, world, source, inertial)
	var size := Vector2(manifest.body.size[0], manifest.body.size[1])
	# Body below the cell: the cell lies inside the current pose near its top face.
	var center := Vector2(float(source.x) + 0.5, float(source.y) + 0.5 + float(manifest.kinematic_probe.cell_depth_inside_top))
	var states := PackedFloat32Array()
	if mode == "swept":
		# Previous pose entirely below; current pose has swept up past the cell.
		# Previous pose wholly below the cell; the current pose has moved up so
		# the cell is inside the swept raster but outside the current body.
		var previous := PackedFloat32Array()
		var below: Vector2 = Vector2(center.x, float(source.y) + 1.0 + size.y / 2.0 + 1.0)
		CyberRigidBodyCoupling.append_input(previous, 1, below, 0.0, size, body_velocity, 0.0, 1.0, 1)
		world.prepare_rigid_body_coupling(previous)
		center = below + Vector2(0, -float(manifest.kinematic_probe.sweep_cells))
		CyberRigidBodyCoupling.append_input(states, 1, center, 0.0, size, body_velocity, 0.0, 1.0, 2)
	else:
		CyberRigidBodyCoupling.append_input(states, 1, center, 0.0, size, body_velocity, 0.0, 1.0, 1)
	world.prepare_rigid_body_coupling(states)
	var results: PackedFloat32Array = world.rigid_body_results()
	var destination: Vector2i = Vector2i(-1, -1)
	var water_cells: int = 0
	for y: int in range(int(geo.wall_top), int(geo.floor_y)):
		for x: int in range(int(geo.left), int(geo.left) + int(geo.width)):
			if int(world.material_at(x, y)) == WATER:
				water_cells += 1
				destination = Vector2i(x, y)
	var state_after: String = carried_state(bridge, world, destination, inertial) if destination.x >= 0 else ""
	if destination == source:
		# Unresolved: the stored cell stays put (outside the final pose).
		state_after = carried_state(bridge, world, destination, inertial)
	var quantity_after: int = int(world.water_experiment_observation(Vector2i.ZERO, Vector2i(WORLD_SIDE, WORLD_SIDE)).water_integer)
	var motion_before: Dictionary = {}
	if inertial: motion_before = world.inspect_inertial_cell(destination)
	if not world.simulation_tick():
		out["error"] = "tick failure after relocation"
		return out
	var next: Vector2i = Vector2i(-1, -1)
	for y: int in range(int(geo.wall_top), int(geo.floor_y)):
		for x: int in range(int(geo.left), int(geo.left) + int(geo.width)):
			if int(world.material_at(x, y)) == WATER:
				next = Vector2i(x, y)
	var motion_after: Dictionary = world.inspect_inertial_cell(next) if inertial and next.x >= 0 else {}
	out["source"] = [source.x, source.y]
	out["destination"] = [destination.x, destination.y]
	out["next_tick_position"] = [next.x, next.y]
	out["relocation_rows_up"] = source.y - destination.y
	out["next_tick_rows_up"] = destination.y - next.y
	out["water_cells_after"] = water_cells
	out["results"] = {"contacts":int(results[5]) if results.size() >= 9 else -1, "displaced":int(results[6]) if results.size() >= 9 else -1,
		"unresolved":int(results[7]) if results.size() >= 9 else -1,
		"impulse":[float(results[1]) if results.size() >= 9 else 0.0, float(results[2]) if results.size() >= 9 else 0.0]}
	out["state_before"] = state_before
	out["state_after"] = state_after
	out["state_carried_unchanged"] = state_before == state_after and destination != source
	out["quantity"] = {"before":quantity_before, "after":quantity_after}
	if inertial:
		out["inertial"] = {"before_tick":{"vx":motion_before.get("vx"), "vy":motion_before.get("vy")},
			"after_tick":{"vx":motion_after.get("vx"), "vy":motion_after.get("vy")}}
	# Overlap mode must relocate exactly the probe cell upward with its complete
	# state. Swept mode records the outcome (relocated or unresolved) and only
	# requires conservation: no creation, deletion or state change.
	var conserved: bool = water_cells == 1 and quantity_before == quantity_after and state_before == state_after
	out["conserved"] = conserved
	if mode == "swept":
		out["ok"] = conserved
	else:
		out["ok"] = conserved and int(out.results.displaced) == 1 and bool(out.state_carried_unchanged) \
			and int(out.relocation_rows_up) > 0
	return out
