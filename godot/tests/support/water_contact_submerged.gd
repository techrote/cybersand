extends RefCounted

# WATER-CONTACT #362 follow-up `water_contact.submerged.v1`: read-only
# characterization of why a submerged Rapier body leaves stored Water under
# its mask (`unresolved` overlaps). Fixture-only; no adapter, World, solver or
# bridge change.
#
# Classifier: for every stored Water cell under the current body mask after
# coupling (observation A), replay the adapter's documented ejection rule
# (CyberNativeCellWorld::overlap_normal, find_ejection_target and
# ejection_path_reachable, cyber_native_cell_world.cpp) against copied stored
# bytes, and record why no target exists. During reconcile the adapter masks the
# complete swept raster (rasterize_body_sweep); targets must be Empty and outside
# that sweep mask. Coupling only fills such cells, so replaying against the
# post-coupling bytes plus the replayed sweep mask, any target still admissible
# was admissible when the adapter examined the cell: an "admissible" residual is
# an oracle/adapter disagreement and fails the row. Trail cells (swept but
# outside the final pose; outward = travel direction) are classified separately.

const Apparatus = preload("res://tests/support/water_contact_impact.gd")
const SCHEMA: String = "water-contact-submerged-observer-v1"
const EMPTY: int = 0
const WATER: int = 3
const WALL: int = 1
const MAX_EJECTION: int = 8 # kMaximumEjectionDistance
const REACH_SEARCH: int = 64
const CHAIN_LIMIT: int = 64

var stride: int = 4
var samples: int = 0
var residual_cells: int = 0
var reasons: Dictionary = {}
var normals: Dictionary = {}
var required_reach: Dictionary = {}
var chain_lengths: Dictionary = {}
var by_depth: Dictionary = {}
var oracle_admissible: int = 0
var oracle_examples: Array = []
var residual_vs_unresolved: Array = []
var max_residual: int = 0
var trail_cells: int = 0
var trail_reasons: Dictionary = {}
var previous: PackedFloat32Array = PackedFloat32Array()


func _init(sample_stride: int = 4) -> void:
	stride = maxi(1, sample_stride)


static func symmetric_offset(index: int) -> int:
	if index == 0: return 0
	var magnitude: int = (index + 1) / 2
	return magnitude if (index & 1) != 0 else -magnitude


static func overlap(center: Vector2, rotation: float, half: Vector2, x: int, y: int) -> Dictionary:
	var c: float = cos(rotation)
	var s: float = sin(rotation)
	var delta := Vector2(x + 0.5 - center.x, y + 0.5 - center.y)
	var local := Vector2(c * delta.x + s * delta.y, -s * delta.x + c * delta.y)
	var xp: float = half.x - absf(local.x) + 0.5
	var yp: float = half.y - absf(local.y) + 0.5
	var ln := Vector2.ZERO
	var pen: float = 0.0
	var kind: String = ""
	if xp < yp:
		ln = Vector2(1.0 if local.x >= 0.0 else -1.0, 0.0)
		pen = maxf(0.5, xp)
		kind = "lateral_local"
	else:
		ln = Vector2(0.0, 1.0 if local.y >= 0.0 else -1.0)
		pen = maxf(0.5, yp)
		kind = "top_local" if local.y < 0.0 else "bottom_local"
	return {"normal":Vector2(c * ln.x - s * ln.y, s * ln.x + c * ln.y), "penetration":pen, "kind":kind}


# Copied region: stored bytes of the ROI plus mask ids gathered once per sample.
class Region:
	var origin: Vector2i
	var size: Vector2i
	var cells: PackedByteArray
	var mask: PackedByteArray
	var sweep: PackedByteArray
	func swept(x: int, y: int) -> bool:
		if x < origin.x or y < origin.y or x >= origin.x + size.x or y >= origin.y + size.y: return false
		return sweep[(y - origin.y) * size.x + x - origin.x] != 0
	func at(x: int, y: int) -> int:
		if x < origin.x or y < origin.y or x >= origin.x + size.x or y >= origin.y + size.y: return -1
		return cells[(y - origin.y) * size.x + x - origin.x]
	func masked(x: int, y: int) -> int:
		if x < origin.x or y < origin.y or x >= origin.x + size.x or y >= origin.y + size.y: return 0
		return mask[(y - origin.y) * size.x + x - origin.x]


# Current-pose mask read from the adapter (rigid_body_id_at), plus the replayed
# sweep raster used as the target-exclusion mask during reconcile.
static func region_for(world: Variant, cells: PackedByteArray, geo: Dictionary, poses: Array) -> Region:
	var r := Region.new()
	r.origin = geo.roi_origin
	r.size = geo.roi_size
	r.cells = cells
	r.mask = PackedByteArray()
	r.mask.resize(r.size.x * r.size.y)
	r.sweep = PackedByteArray()
	r.sweep.resize(r.size.x * r.size.y)
	var current: Array = poses[-1]
	var ext: Vector2 = Apparatus.body_extent(current[1], current[2] * 2.0)
	var lo := Vector2i(maxi(r.origin.x, floori(current[0].x - ext.x / 2.0) - 2), maxi(r.origin.y, floori(current[0].y - ext.y / 2.0) - 2))
	var hi := Vector2i(mini(r.origin.x + r.size.x, ceili(current[0].x + ext.x / 2.0) + 2), mini(r.origin.y + r.size.y, ceili(current[0].y + ext.y / 2.0) + 2))
	for y: int in range(lo.y, hi.y):
		for x: int in range(lo.x, hi.x):
			r.mask[(y - r.origin.y) * r.size.x + x - r.origin.x] = int(world.rigid_body_id_at(x, y))
	for pose: Array in poses:
		raster(r, pose[0], pose[1], pose[2])
	return r


# CyberNativeCellWorld::rasterize_transform_in, into the copied sweep mask.
static func raster(r: Region, center: Vector2, rotation: float, half: Vector2) -> void:
	var c: float = cos(rotation)
	var s: float = sin(rotation)
	var ex := Vector2(absf(c) * half.x + absf(s) * half.y, absf(s) * half.x + absf(c) * half.y)
	var fx: int = int(clampf(floorf(center.x - ex.x), 0.0, 1023.0))
	var lx: int = int(clampf(ceilf(center.x + ex.x) - 1.0, 0.0, 1023.0))
	var fy: int = int(clampf(floorf(center.y - ex.y), 0.0, 1023.0))
	var ly: int = int(clampf(ceilf(center.y + ex.y) - 1.0, 0.0, 1023.0))
	for y: int in range(fy, ly + 1):
		for x: int in range(fx, lx + 1):
			var d := Vector2(x + 0.5 - center.x, y + 0.5 - center.y)
			var l := Vector2(c * d.x + s * d.y, -s * d.x + c * d.y)
			if absf(l.x) > half.x or absf(l.y) > half.y: continue
			if x >= r.origin.x and y >= r.origin.y and x < r.origin.x + r.size.x and y < r.origin.y + r.size.y:
				r.sweep[(y - r.origin.y) * r.size.x + x - r.origin.x] = 1


# rasterize_body_sweep pose list: kMaximumBodySweepDistance 32, spacing 1, at most 24 steps.
static func sweep_poses(previous: PackedFloat32Array, states: PackedFloat32Array) -> Array:
	var center := Vector2(states[1], states[2])
	var half := Vector2(maxf(0.5, states[4] * 0.5), maxf(0.5, states[5] * 0.5))
	var current: Array = [center, float(states[3]), half]
	if previous.size() < 11:
		return [current]
	var pc := Vector2(previous[1], previous[2])
	var ph := Vector2(maxf(0.5, previous[4] * 0.5), maxf(0.5, previous[5] * 0.5))
	var travel: float = center.distance_to(pc)
	if travel > 32.0:
		return [current]
	var delta: float = fposmod(float(states[3]) - float(previous[3]) + PI, TAU) - PI
	var rot_travel: float = absf(delta) * maxf(half.length(), ph.length())
	var extent: float = maxf(travel, rot_travel)
	if extent <= 1.0:
		return [current]
	var steps: int = int(clampf(ceilf(extent / 1.0), 1.0, 24.0))
	var poses: Array = []
	for i: int in range(steps + 1):
		var w: float = float(i) / steps
		poses.append([pc.lerp(center, w), float(previous[3]) + delta * w, ph.lerp(half, w)])
	poses.append(current)
	return poses


# Outside the interior ROI: basin walls/floor are hard; open air above is Empty.
static func material(r: Region, geo: Dictionary, x: int, y: int) -> int:
	var m: int = r.at(x, y)
	if m != -1: return m
	if x < int(geo.left) or x >= int(geo.left) + int(geo.width) or y >= int(geo.floor_y): return WALL
	return EMPTY


static func path_reachable(r: Region, geo: Dictionary, sx: int, sy: int, tx: int, ty: int, body: int) -> bool:
	var dx: int = tx - sx
	var dy: int = ty - sy
	var count: int = maxi(absi(dx), absi(dy)) * 2
	for i: int in range(1, count):
		var x: int = sx + floori(float(dx * i) / count + 0.5)
		var y: int = sy + floori(float(dy * i) / count + 0.5)
		var obstacle: int = r.masked(x, y)
		if (obstacle != 0 and obstacle != body) or material(r, geo, x, y) == WALL:
			return false
	return true


# Replays find_ejection_target for one masked cell. Returns the reason no target
# exists ("admissible" means the oracle found one) and the minimum straight
# reach at which any probe would find an unmasked Empty cell.
static func classify(r: Region, geo: Dictionary, x: int, y: int, normal: Vector2, pen: float, body: int) -> Dictionary:
	var tangent := Vector2(-normal.y, normal.x)
	var source := Vector2(x + 0.5, y + 0.5)
	var first: int = maxi(1, ceili(pen))
	var empty_masked: int = 0
	var empty_blocked: int = 0
	var occupied_water: int = 0
	var occupied_hard: int = 0
	for distance: int in range(first, first + MAX_EJECTION + 1):
		for probe: int in range(9):
			var c: Vector2 = source + normal * distance + tangent * symmetric_offset(probe)
			var cx: int = floori(c.x)
			var cy: int = floori(c.y)
			if cx < 0 or cy < 0 or cx >= 1024 or cy >= 1024:
				occupied_hard += 1
				continue
			if r.masked(cx, cy) != 0 or r.swept(cx, cy):
				if material(r, geo, cx, cy) == EMPTY: empty_masked += 1
				continue
			var m: int = material(r, geo, cx, cy)
			if m != EMPTY:
				if m == WATER: occupied_water += 1
				else: occupied_hard += 1
				continue
			if not path_reachable(r, geo, x, y, cx, cy, body):
				empty_blocked += 1
				continue
			return {"reason":"admissible", "target":[cx, cy], "distance":distance}
	var reason: String = "no_empty_within_reach"
	if empty_blocked > 0: reason = "empty_path_blocked"
	elif empty_masked > 0: reason = "empty_only_under_mask"
	elif occupied_water == 0: reason = "hard_or_bounds_only"
	# Straight reach the same probe fan would need to meet an unmasked Empty cell.
	var needed: int = -1
	for distance: int in range(first + MAX_EJECTION + 1, REACH_SEARCH + 1):
		for probe: int in range(9):
			var c: Vector2 = source + normal * distance + tangent * symmetric_offset(probe)
			var cx: int = floori(c.x)
			var cy: int = floori(c.y)
			if r.masked(cx, cy) == 0 and material(r, geo, cx, cy) == EMPTY:
				needed = distance
				break
		if needed >= 0: break
	return {"reason":reason, "required_reach":needed, "adapter_reach":first + MAX_EJECTION}


# Four-connected distance from each cell to the nearest unmasked Empty cell,
# travelling through unmasked Water only: the shortest one-cell push chain a
# vacancy-propagation scheme (e.g. #347's <=4-move transaction) would need.
static func chain_field(r: Region, geo: Dictionary) -> PackedInt32Array:
	var n: int = r.size.x * r.size.y
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for i: int in range(n):
		if r.cells[i] == EMPTY and r.mask[i] == 0:
			dist[i] = 0
			queue.append(i)
	# Open air above the ROI counts as Empty for the top row.
	for x: int in range(r.size.x):
		if r.cells[x] == WATER and r.mask[x] == 0 and dist[x] < 0 and r.origin.y > int(geo.wall_top):
			dist[x] = 1
			queue.append(x)
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var ix: int = i % r.size.x
		var iy: int = i / r.size.x
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = ix + d.x
			var ny: int = iy + d.y
			if nx < 0 or ny < 0 or nx >= r.size.x or ny >= r.size.y: continue
			var j: int = ny * r.size.x + nx
			if dist[j] >= 0 or r.cells[j] != WATER or r.mask[j] != 0: continue
			if dist[i] >= CHAIN_LIMIT: continue
			dist[j] = dist[i] + 1
			queue.append(j)
	return dist


static func chain_for(r: Region, field: PackedInt32Array, x: int, y: int) -> int:
	# A masked source moves into an unmasked neighbour first.
	var best: int = -1
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x - r.origin.x
		var ny: int = y + d.y - r.origin.y
		if nx < 0 or ny < 0 or nx >= r.size.x or ny >= r.size.y: continue
		var j: int = ny * r.size.x + nx
		if r.mask[j] != 0 or field[j] < 0: continue
		var v: int = field[j] + 1
		best = v if best < 0 else mini(best, v)
	return best


static func bucket(value: int) -> String:
	if value < 0: return "unreachable"
	if value <= 4: return "1-4"
	if value <= 8: return "5-8"
	if value <= 16: return "9-16"
	if value <= 32: return "17-32"
	return "33+"


func add(table: Dictionary, key: String, count: int = 1) -> void:
	table[key] = int(table.get(key, 0)) + count


func sample(world: Variant, tick: int, states: PackedFloat32Array, cells: PackedByteArray, geo: Dictionary,
		body_size: Vector2, results: PackedFloat32Array) -> void:
	# The adapter sweeps from its previous accepted sample, i.e. the previous
	# call. Track it on every call, sampled or not.
	var before: PackedFloat32Array = previous
	previous = states
	if states.size() < 11 or tick % stride != 0:
		return
	var center := Vector2(states[1], states[2])
	var rotation: float = states[3]
	var half := Vector2(maxf(0.5, states[4] * 0.5), maxf(0.5, states[5] * 0.5))
	var extent: Vector2 = Apparatus.body_extent(rotation, half * 2.0)
	var r: Region = region_for(world, cells, geo, sweep_poses(before, states))
	var field: PackedInt32Array = chain_field(r, geo)
	var travel := Vector2.ZERO
	if before.size() >= 11:
		travel = center - Vector2(before[1], before[2])
	var outward_travel: Vector2 = travel.normalized() if travel.length() > 0.000001 else Vector2.ZERO
	var residual: int = 0
	# Rows of the body top below the initial surface (negative: above it).
	var depth_key: String = str(roundi(center.y - extent.y / 2.0 - float(int(geo.surface))))
	for i: int in range(r.mask.size()):
		if r.cells[i] != WATER: continue
		var x: int = r.origin.x + i % r.size.x
		var y: int = r.origin.y + i / r.size.x
		if r.mask[i] == 0:
			# Swept trail outside the final pose: classify with the travel normal.
			if r.sweep[i] != 0 and outward_travel != Vector2.ZERO:
				trail_cells += 1
				var t: Dictionary = classify(r, geo, x, y, outward_travel, 0.5, 1)
				add(trail_reasons, t.reason)
			continue
		residual += 1
		var o: Dictionary = overlap(center, rotation, half, x, y)
		var c: Dictionary = classify(r, geo, x, y, o.normal, o.penetration, r.mask[i])
		add(reasons, c.reason)
		add(normals, o.kind + ":" + c.reason)
		if c.reason == "admissible":
			oracle_admissible += 1
			if oracle_examples.size() < 8:
				oracle_examples.append({"tick":tick + 1, "cell":[x, y], "target":c.target, "kind":o.kind})
			continue
		add(required_reach, bucket(int(c.required_reach)) if int(c.required_reach) >= 0 else "beyond_64")
		add(chain_lengths, bucket(chain_for(r, field, x, y)))
	samples += 1
	residual_cells += residual
	max_residual = maxi(max_residual, residual)
	var row: Dictionary = by_depth.get(depth_key, {"samples":0, "residual":0, "displaced":0, "unresolved":0})
	row.samples += 1
	row.residual += residual
	row.displaced += int(results[6]) if results.size() >= 9 else 0
	row.unresolved += int(results[7]) if results.size() >= 9 else 0
	by_depth[depth_key] = row
	if residual_vs_unresolved.size() < 400:
		residual_vs_unresolved.append([tick + 1, residual, int(results[7]) if results.size() >= 9 else 0,
			int(results[6]) if results.size() >= 9 else 0])


func summary() -> Dictionary:
	return {"schema":SCHEMA, "stride":stride, "samples":samples, "residual_cell_samples":residual_cells,
		"max_residual":max_residual, "reasons":reasons, "normal_kind_reasons":normals,
		"required_straight_reach":required_reach, "push_chain_length":chain_lengths,
		"oracle_admissible":oracle_admissible, "oracle_examples":oracle_examples,
		"trail_cell_samples":trail_cells, "trail_reasons":trail_reasons,
		"by_body_top_depth":by_depth, "residual_vs_unresolved":residual_vs_unresolved,
		"units":"cell-samples at every `stride` ticks; depth = body-top rows below the initial surface"}


# Kinematic forcing (prescribed body records, no Rapier): the reference body
# descends vertically at `rate` cells per step from two rows above the surface
# to the floor, optionally ticking the liquid between steps. Isolates the
# adapter relocation law as a function of body-top depth.
static func kinematic_descent(bridge: Variant, manifest: Dictionary, arm: Dictionary, depth: int, rate: float,
		tick_liquid: bool, body_size: Vector2) -> Dictionary:
	var geo: Dictionary = Apparatus.geometry(manifest, {"depth":depth})
	var built: Dictionary = Apparatus.build_world(bridge, manifest, arm, 1, Apparatus.rectangles(geo, true))
	var out: Dictionary = {"schema":"water-contact-kinematic-descent-v1", "arm":arm.id, "depth":depth, "rate":rate,
		"tick_liquid":tick_liquid, "body_size":[body_size.x, body_size.y], "ok":false,
		"label":"kinematic forcing experiment: prescribed body records, no Rapier dynamics"}
	if not built.get("ok", false):
		out["error"] = built.get("error", "construction")
		return out
	var world: Variant = built.world
	var q0: int = int(world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024, 1024)).water_integer)
	var observer: Variant = load("res://tests/support/water_contact_submerged.gd").new(1)
	var center := Vector2(float(geo.left) + float(geo.width) / 2.0, float(geo.surface) - 2.0 - body_size.y / 2.0)
	var steps: Array = []
	var serial: int = 0
	var tick: int = 0
	while center.y + body_size.y / 2.0 < float(geo.floor_y) - 1.0 and steps.size() < 600:
		serial += 1
		var states := PackedFloat32Array()
		CyberRigidBodyCoupling.append_input(states, 1, center, 0.0, body_size, Vector2(0, rate * 60.0), 0.0, 1.0, serial)
		world.prepare_rigid_body_coupling(states)
		var results: PackedFloat32Array = world.rigid_body_results()
		var cells: PackedByteArray = world.diagnostic_snapshot(geo.roi_origin, geo.roi_size, false).get("cells", PackedByteArray())
		var before: int = observer.residual_cells
		observer.sample(world, tick, states, cells, geo, body_size, results)
		steps.append([snappedf(center.y - body_size.y / 2.0 - float(geo.surface), 0.01), int(results[6]), int(results[7]),
			observer.residual_cells - before])
		if tick_liquid and not world.simulation_tick():
			out["error"] = "tick failure"
			return out
		tick += 1
		center.y += rate
	var q1: int = int(world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024, 1024)).water_integer)
	out["steps_columns"] = ["body_top_rows_below_surface", "displaced", "unresolved", "residual_masked_water"]
	out["steps"] = steps
	out["observer"] = observer.summary()
	out["quantity"] = {"before":q0, "after":q1}
	var last_relocating: Variant = null
	for step: Array in steps:
		if int(step[1]) > 0: last_relocating = step[0]
	out["deepest_relocating_body_top"] = last_relocating
	out["ok"] = q0 == q1 and int(observer.oracle_admissible) == 0 and not world.has_failed()
	return out


# Positive control: the classifier must predict exactly the target the adapter
# then uses for a cell it does relocate (one probe cell, five rows inside the
# top face, as in water_contact.impact.v1's kinematic probe), so a zero
# disagreement count above cannot come from a classifier that rejects everything.
static func positive_control(bridge: Variant, manifest: Dictionary, arm: Dictionary) -> Dictionary:
	var geo: Dictionary = Apparatus.geometry(manifest, {"depth":0})
	var rects: PackedInt32Array = Apparatus.rectangles(geo, false)
	var column: int = int(geo.left) + int(geo.width) / 2
	var row: int = int(geo.floor_y) - 200
	rects.append_array(PackedInt32Array([column, row, 1, 1, WATER]))
	var built: Dictionary = Apparatus.build_world(bridge, manifest, arm, 1, rects)
	if not built.get("ok", false):
		return {"ok":false, "error":built.get("error", "construction")}
	var world: Variant = built.world
	var size := Vector2(manifest.body.size[0], manifest.body.size[1])
	var center := Vector2(column + 0.5, row + 0.5 + 5.0)
	var states := PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(states, 1, center, 0.0, size, Vector2.ZERO, 0.0, 1.0, 1)
	var g: Dictionary = geo.duplicate()
	g.roi_origin = Vector2i(int(geo.left), row - 40)
	g.roi_size = Vector2i(int(geo.width), 80)
	var cells: PackedByteArray = world.diagnostic_snapshot(g.roi_origin, g.roi_size, false).get("cells", PackedByteArray())
	var r: Region = region_for(world, cells, g, sweep_poses(PackedFloat32Array(), states))
	# Before coupling there is no adapter mask: use the replayed raster for both.
	r.mask = r.sweep.duplicate()
	var o: Dictionary = overlap(center, 0.0, size / 2.0, column, row)
	var predicted: Dictionary = classify(r, g, column, row, o.normal, o.penetration, 1)
	world.prepare_rigid_body_coupling(states)
	var actual := Vector2i(-1, -1)
	for y: int in range(row - 20, row + 1):
		if int(bridge.inspect_cell(world, Vector2i(column, y)).get("material", -1)) == WATER:
			actual = Vector2i(column, y)
	var target: Array = predicted.get("target", [])
	return {"arm":arm.id, "predicted":predicted, "actual":[actual.x, actual.y],
		"ok":predicted.reason == "admissible" and target.size() == 2 and Vector2i(target[0], target[1]) == actual}
