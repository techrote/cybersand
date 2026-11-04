extends RefCounted

# Opt-in SOL281 response planner. This script owns no live object, RID, material
# or clock. Its caller authenticates token/generation/tick/sample and applies a
# completely validated plan through the one main-thread Rapier owner.
#
# A parallel face group uses its approaching contact-length-weighted resultant.
# This is an explicit uniform support-pressure approximation, not a friction or
# elastic granular law. It removes the left-to-right torque bias of independently
# arresting symmetric points. The approaching subset is recomputed from current
# point velocities on EACH sweep, so an approaching rotating edge cannot vanish
# behind the separating opposite edge or a stationary group COM. Four fixed
# sweeps handle nonparallel groups; every
# emitted impulse is unilateral, zero-restitution and dissipative at the planned
# current velocity. There is no position correction or additional gravity term.
const SCHEMA: String = "cybersand.sol281.sand-contact.v1"
const MAX_CONTACTS: int = 256
const MAX_PROXIES: int = 64
const SOLVER_SWEEPS: int = 4
const MAX_VERTEX_DRIFT: float = 0.25
const CONTACT_EPSILON: float = 0.00002
# Native observations use float64 geometry over float32 body records. Rebuilding
# a compound from the copied float32 COM adds small roundoff at remote proxies.
# This tolerance authenticates the supplied witness; it does not inflate bodies.
const WITNESS_EPSILON: float = 0.001
const NORMAL_EPSILON: float = 0.0001
const ENERGY_RELATIVE_TOLERANCE: float = 0.00000001
const ENERGY_ABSOLUTE_TOLERANCE: float = 0.00000001
const APPROACH_EPSILON: float = 0.000001
const PARALLEL_DOT: float = 0.999999


static func _refuse(outcome: String) -> Dictionary:
	return {"accepted":false, "outcome":outcome, "impulses":[]}


static func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _rigid_transform(value: Transform2D) -> bool:
	return value.is_finite() and absf(value.x.length_squared() - 1.0) <= NORMAL_EPSILON \
		and absf(value.y.length_squared() - 1.0) <= NORMAL_EPSILON \
		and absf(value.x.dot(value.y)) <= NORMAL_EPSILON \
		and absf(value.determinant() - 1.0) <= NORMAL_EPSILON


static func _face_normal(face: int) -> Vector2:
	match face:
		0: return Vector2.UP
		1: return Vector2.RIGHT
		2: return Vector2.DOWN
		3: return Vector2.LEFT
	return Vector2.ZERO


static func _corners(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half: Vector2 = size * 0.5
	return PackedVector2Array([center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y), center + half,
		center + Vector2(-half.x, half.y)])


static func _in_cell(point: Vector2, cell: Vector2i, epsilon: float) -> bool:
	var local: Vector2 = point - Vector2(cell)
	return local.x >= -epsilon and local.y >= -epsilon \
		and local.x <= 1.0 + epsilon and local.y <= 1.0 + epsilon


static func _clip_axis(polygon: PackedVector2Array, axis: int, bound: float,
		keep_greater: bool) -> PackedVector2Array:
	var output := PackedVector2Array()
	if polygon.is_empty():
		return output
	var previous: Vector2 = polygon[polygon.size() - 1]
	var previous_inside: bool = previous[axis] >= bound if keep_greater else previous[axis] <= bound
	for current: Vector2 in polygon:
		var current_inside: bool = current[axis] >= bound if keep_greater else current[axis] <= bound
		if current_inside != previous_inside:
			var denominator: float = current[axis] - previous[axis]
			if denominator != 0.0:
				var fraction: float = clampf((bound - previous[axis]) / denominator, 0.0, 1.0)
				output.append(previous + (current - previous) * fraction)
		if current_inside:
			output.append(current)
		previous = current
		previous_inside = current_inside
	return output


static func _intersection(pose: Transform2D, center: Vector2, size: Vector2,
		cell: Vector2i) -> Dictionary:
	# Full closed unit square versus the actual oriented proxy. The AABB is not
	# used as contact geometry. Work cell-relative for a well-conditioned area.
	var world_center: Vector2 = pose * center
	var delta: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) - world_center
	var half: Vector2 = size * 0.5
	var gap_x: float = absf(delta.x) - (0.5 + absf(pose.x.x) * half.x + absf(pose.y.x) * half.y)
	var gap_y: float = absf(delta.y) - (0.5 + absf(pose.x.y) * half.x + absf(pose.y.y) * half.y)
	var gap_u: float = absf(delta.dot(pose.x)) - (half.x + 0.5 * (absf(pose.x.x) + absf(pose.x.y)))
	var gap_v: float = absf(delta.dot(pose.y)) - (half.y + 0.5 * (absf(pose.y.x) + absf(pose.y.y)))
	var gap: float = maxf(maxf(gap_x, gap_y), maxf(gap_u, gap_v))
	var polygon := PackedVector2Array()
	for corner: Vector2 in _corners(center, size):
		polygon.append(pose * corner - Vector2(cell))
	polygon = _clip_axis(polygon, 0, 0.0, true)
	polygon = _clip_axis(polygon, 0, 1.0, false)
	polygon = _clip_axis(polygon, 1, 0.0, true)
	polygon = _clip_axis(polygon, 1, 1.0, false)
	var twice_area: float = 0.0
	if polygon.size() >= 3:
		for i: int in range(polygon.size()):
			twice_area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return {"gap":gap, "depth":maxf(0.0, -gap), "area":absf(twice_area) * 0.5}


static func _face_segment(pose: Transform2D, center: Vector2, size: Vector2,
		face: int, cell: Vector2i) -> Dictionary:
	var corners: PackedVector2Array = _corners(center, size)
	var a: Vector2 = pose * corners[face]
	var b: Vector2 = pose * corners[(face + 1) % 4]
	var delta: Vector2 = b - a
	var low: float = 0.0
	var high: float = 1.0
	for axis: int in range(2):
		if absf(delta[axis]) <= 0.000000000001:
			if a[axis] < float(cell[axis]) - CONTACT_EPSILON \
				or a[axis] > float(cell[axis] + 1) + CONTACT_EPSILON:
				return {}
			continue
		var first: float = (float(cell[axis]) - a[axis]) / delta[axis]
		var last: float = (float(cell[axis] + 1) - a[axis]) / delta[axis]
		low = maxf(low, minf(first, last))
		high = minf(high, maxf(first, last))
		if high <= low:
			return {}
	var length: float = delta.length() * (high - low)
	if not is_finite(length) or length <= 0.0:
		return {}
	return {"point":a + delta * ((low + high) * 0.5), "weight":length}


static func _contact_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.proxy) != int(b.proxy): return int(a.proxy) < int(b.proxy)
	if int(a.face) != int(b.face): return int(a.face) < int(b.face)
	var ac: Vector2i = a.cell
	var bc: Vector2i = b.cell
	if ac.y != bc.y: return ac.y < bc.y
	if ac.x != bc.x: return ac.x < bc.x
	return float(a.begin) < float(b.begin)


static func _exterior_segment(a: Vector2, b: Vector2, proxy: int, face: int,
		centers: PackedVector2Array, sizes: PackedVector2Array) -> bool:
	# Work in the common aggregate-local frame. Authenticate the WHOLE segment,
	# not only its midpoint: a partially covered compound seam is not support.
	var normal: Vector2 = _face_normal(face)
	var axis: int = 0 if face == 1 or face == 3 else 1
	var tangent: int = 1 - axis
	var plane: float = centers[proxy][axis] + normal[axis] * sizes[proxy][axis] * 0.5
	var low: float = centers[proxy][tangent] - sizes[proxy][tangent] * 0.5
	var high: float = centers[proxy][tangent] + sizes[proxy][tangent] * 0.5
	if absf(a[axis] - plane) > WITNESS_EPSILON or absf(b[axis] - plane) > WITNESS_EPSILON \
		or minf(a[tangent], b[tangent]) < low - WITNESS_EPSILON \
		or maxf(a[tangent], b[tangent]) > high + WITNESS_EPSILON:
		return false
	var segment_low: float = minf(a[tangent], b[tangent])
	var segment_high: float = maxf(a[tangent], b[tangent])
	for other: int in range(centers.size()):
		if other == proxy:
			continue
		var other_low: float = centers[other][axis] - sizes[other][axis] * 0.5
		var other_high: float = centers[other][axis] + sizes[other][axis] * 0.5
		var covers_outward: bool = other_low <= plane + CONTACT_EPSILON \
			and other_high > plane + CONTACT_EPSILON if normal[axis] > 0.0 else \
			other_high >= plane - CONTACT_EPSILON and other_low < plane - CONTACT_EPSILON
		if not covers_outward:
			continue
		var covered_low: float = maxf(segment_low, centers[other][tangent] - sizes[other][tangent] * 0.5)
		var covered_high: float = minf(segment_high, centers[other][tangent] + sizes[other][tangent] * 0.5)
		if covered_high - covered_low > CONTACT_EPSILON:
			return false
	return true


static func _energy(velocity: Vector2, omega: float, mass: float, inertia: float) -> float:
	return 0.5 * mass * velocity.length_squared() + 0.5 * inertia * omega * omega


static func plan(observation: Dictionary, transform: Transform2D, velocity: Vector2,
		omega: float, mass: float, inertia: float, local_centers: PackedVector2Array,
		sizes: PackedVector2Array) -> Dictionary:
	if observation.get("schema") != SCHEMA or typeof(observation.get("ok")) != TYPE_BOOL \
		or not observation.ok or typeof(observation.get("complete")) != TYPE_BOOL \
		or not observation.complete or typeof(observation.get("source_transform")) != TYPE_TRANSFORM2D \
		or typeof(observation.get("contacts")) != TYPE_ARRAY:
		return _refuse("InvalidObservation")
	for key: String in ["token", "body_generation", "revision"]:
		if typeof(observation.get(key)) != TYPE_STRING or str(observation[key]).is_empty():
			return _refuse("InvalidIdentity")
	if typeof(observation.get("sample_serial")) != TYPE_INT \
		or int(observation.sample_serial) < 0 or int(observation.sample_serial) >= 1000000 \
		or typeof(observation.get("tick")) != TYPE_INT or int(observation.tick) < 0:
		return _refuse("InvalidIdentity")
	var source: Transform2D = observation.source_transform
	var records: Array = observation.contacts
	if records.size() > MAX_CONTACTS or local_centers.is_empty() \
		or local_centers.size() > MAX_PROXIES or sizes.size() != local_centers.size() \
		or not _rigid_transform(source) or not _rigid_transform(transform) \
		or not velocity.is_finite() or not is_finite(omega) or not is_finite(mass) \
		or not is_finite(inertia) or mass <= 0.0 or inertia <= 0.0:
		return _refuse("InvalidBody")
	var maximum_drift: float = 0.0
	for proxy: int in range(local_centers.size()):
		if not local_centers[proxy].is_finite() or not sizes[proxy].is_finite() \
			or sizes[proxy].x <= 0.0 or sizes[proxy].y <= 0.0:
			return _refuse("InvalidGeometry")
		for corner: Vector2 in _corners(local_centers[proxy], sizes[proxy]):
			maximum_drift = maxf(maximum_drift, (transform * corner).distance_to(source * corner))
	if not is_finite(maximum_drift) or maximum_drift > MAX_VERTEX_DRIFT:
		return _refuse("PoseDrift")
	var source_inverse: Transform2D = source.affine_inverse()
	var contacts: Array[Dictionary] = []
	# Validate EVERY record before planning even the first impulse. A malformed
	# last record therefore cannot produce a usable partial response.
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY:
			return _refuse("InvalidContact")
		var record: Dictionary = raw
		if typeof(record.get("proxy")) != TYPE_INT or typeof(record.get("face")) != TYPE_INT \
			or typeof(record.get("cell")) != TYPE_VECTOR2I or typeof(record.get("point")) != TYPE_VECTOR2 \
			or typeof(record.get("a")) != TYPE_VECTOR2 or typeof(record.get("b")) != TYPE_VECTOR2 \
			or typeof(record.get("normal")) != TYPE_VECTOR2 or not _number(record.get("depth")) \
			or not _number(record.get("area")) or not _number(record.get("weight")):
			return _refuse("InvalidContact")
		var proxy: int = int(record.proxy) - 1
		var face: int = int(record.face)
		var cell: Vector2i = record.cell
		var point: Vector2 = record.point
		var endpoint_a: Vector2 = record.a
		var endpoint_b: Vector2 = record.b
		var outward: Vector2 = record.normal
		var weight: float = float(record.weight)
		if proxy < 0 or proxy >= local_centers.size() or face < 0 or face >= 4 \
			or not point.is_finite() or not outward.is_finite() \
			or not endpoint_a.is_finite() or not endpoint_b.is_finite() \
			or absf(outward.length_squared() - 1.0) > NORMAL_EPSILON \
			or float(record.depth) <= 0.0 or float(record.area) <= 0.0 \
			or float(record.area) > 1.0 + WITNESS_EPSILON \
			or weight <= 0.0 or weight > sqrt(2.0) + WITNESS_EPSILON \
			or not _in_cell(point, cell, CONTACT_EPSILON) \
			or not _in_cell(endpoint_a, cell, CONTACT_EPSILON) \
			or not _in_cell(endpoint_b, cell, CONTACT_EPSILON):
			return _refuse("InvalidContact")
		var expected_normal: Vector2 = source.basis_xform(_face_normal(face))
		if outward.distance_to(expected_normal) > NORMAL_EPSILON:
			return _refuse("InvalidFaceNormal")
		var source_intersection: Dictionary = _intersection(source, local_centers[proxy], sizes[proxy], cell)
		var local_a: Vector2 = source_inverse * endpoint_a
		var local_b: Vector2 = source_inverse * endpoint_b
		if float(source_intersection.area) <= 0.0 or float(source_intersection.depth) <= 0.0 \
			or absf(float(record.depth) - float(source_intersection.depth)) > WITNESS_EPSILON \
			or absf(float(record.area) - float(source_intersection.area)) > WITNESS_EPSILON \
			or point.distance_to((endpoint_a + endpoint_b) * 0.5) > WITNESS_EPSILON \
			or absf(weight - endpoint_a.distance_to(endpoint_b)) > WITNESS_EPSILON \
			or not _exterior_segment(local_a, local_b, proxy, face, local_centers, sizes):
			return _refuse("InvalidGeometryWitness")
		var current_point: Vector2 = transform * (source_inverse * point)
		var current_intersection: Dictionary = _intersection(transform, local_centers[proxy], sizes[proxy], cell)
		if not current_point.is_finite() or not _in_cell(current_point, cell, CONTACT_EPSILON) \
			or float(current_intersection.gap) > CONTACT_EPSILON \
			or _face_segment(transform, local_centers[proxy], sizes[proxy], face, cell).is_empty():
			return _refuse("ClearedContact")
		contacts.append({"proxy":proxy + 1, "face":face, "cell":cell,
			"offset":current_point - transform.origin,
			"normal":transform.basis_xform(_face_normal(face)).normalized(), "weight":weight,
			"begin":minf(local_a[0 if face == 0 or face == 2 else 1], local_b[0 if face == 0 or face == 2 else 1]),
			"end":maxf(local_a[0 if face == 0 or face == 2 else 1], local_b[0 if face == 0 or face == 2 else 1])})
	contacts.sort_custom(_contact_before)
	for i: int in range(1, contacts.size()):
		if contacts[i].proxy == contacts[i - 1].proxy and contacts[i].face == contacts[i - 1].face \
			and contacts[i].cell == contacts[i - 1].cell \
			and ((contacts[i].begin == contacts[i - 1].begin and contacts[i].end == contacts[i - 1].end) \
				or float(contacts[i].begin) < float(contacts[i - 1].end) - CONTACT_EPSILON):
			return _refuse("DuplicateContact")
	var groups: Array[Dictionary] = []
	for contact: Dictionary in contacts:
		var found: int = -1
		for i: int in range(groups.size()):
			if (groups[i].normal as Vector2).dot(contact.normal) >= PARALLEL_DOT:
				found = i
				break
		if found < 0:
			groups.append({"normal":contact.normal, "segments":[]})
			found = groups.size() - 1
		groups[found].segments.append({"offset":contact.offset, "weight":contact.weight})
	if groups.size() > 4:
		return _refuse("IncoherentNormals")
	var result_velocity: Vector2 = velocity
	var result_omega: float = omega
	var before: float = _energy(velocity, omega, mass, inertia)
	if not is_finite(before):
		return _refuse("InvalidEnergy")
	var tolerance: float = maxf(ENERGY_ABSOLUTE_TOLERANCE, before * ENERGY_RELATIVE_TOLERANCE)
	var impulses: Array[Dictionary] = []
	var total_impulse := Vector2.ZERO
	var torque_impulse: float = 0.0
	var approaching_count: int = 0
	for sweep: int in range(SOLVER_SWEEPS):
		for step: int in range(groups.size()):
			var index: int = step if (sweep & 1) == 0 else groups.size() - 1 - step
			var group: Dictionary = groups[index]
			var normal: Vector2 = -(group.normal as Vector2)
			var weighted_offset := Vector2.ZERO
			var approaching_weight: float = 0.0
			for segment: Dictionary in group.segments:
				var segment_offset: Vector2 = segment.offset
				var segment_velocity: Vector2 = result_velocity \
					+ Vector2(-segment_offset.y, segment_offset.x) * result_omega
				if segment_velocity.dot(normal) >= -APPROACH_EPSILON:
					continue
				weighted_offset += segment_offset * float(segment.weight)
				approaching_weight += float(segment.weight)
			if approaching_weight <= 0.0:
				continue
			var offset: Vector2 = weighted_offset / approaching_weight
			if not offset.is_finite():
				return _refuse("InvalidGroup")
			var at_contact: Vector2 = result_velocity + Vector2(-offset.y, offset.x) * result_omega
			var approach: float = at_contact.dot(normal)
			if approach >= -APPROACH_EPSILON:
				continue
			var lever: float = offset.cross(normal)
			var inverse_effective_mass: float = 1.0 / mass + lever * lever / inertia
			var magnitude: float = -approach / inverse_effective_mass
			var impulse: Vector2 = normal * magnitude
			var torque: float = offset.cross(impulse)
			var next_velocity: Vector2 = result_velocity + impulse / mass
			var next_omega: float = result_omega + torque / inertia
			var step_before: float = _energy(result_velocity, result_omega, mass, inertia)
			var step_after: float = _energy(next_velocity, next_omega, mass, inertia)
			var step_tolerance: float = maxf(ENERGY_ABSOLUTE_TOLERANCE,
				step_before * ENERGY_RELATIVE_TOLERANCE)
			if not is_finite(magnitude) or not impulse.is_finite() or not next_velocity.is_finite() \
				or not is_finite(next_omega) or not is_finite(step_after) \
				or step_after > step_before + step_tolerance:
				return _refuse("NonDissipativeResponse")
			impulses.append({"impulse":impulse, "offset":offset})
			total_impulse += impulse
			torque_impulse += torque
			result_velocity = next_velocity
			result_omega = next_omega
			approaching_count += 1
	var after: float = _energy(result_velocity, result_omega, mass, inertia)
	if not total_impulse.is_finite() or not is_finite(torque_impulse) or after > before + tolerance:
		return _refuse("NonDissipativeResponse")
	var maximum_remaining_approach: float = 0.0
	var remaining_approaching_contacts: int = 0
	for contact: Dictionary in contacts:
		var offset: Vector2 = contact.offset
		var point_velocity: Vector2 = result_velocity + Vector2(-offset.y, offset.x) * result_omega
		var residual: float = point_velocity.dot(contact.normal)
		maximum_remaining_approach = maxf(maximum_remaining_approach, residual)
		if residual > APPROACH_EPSILON:
			remaining_approaching_contacts += 1
	return {"accepted":true, "outcome":"Accepted", "impulses":impulses,
		"velocity":result_velocity, "omega":result_omega,
		"energy_before":before, "energy_after":after, "energy_tolerance":tolerance,
		"total_impulse":total_impulse, "torque_impulse":torque_impulse,
		"approaching_count":approaching_count, "contact_count":contacts.size(),
		"group_count":groups.size(), "solver_sweeps":SOLVER_SWEEPS,
		"maximum_remaining_approach_speed":maximum_remaining_approach,
		"remaining_approaching_contacts":remaining_approaching_contacts,
		"maximum_vertex_drift":maximum_drift,
		"pressure_distribution":"approaching-parallel-face-contact-length-weighted-resultant"}
