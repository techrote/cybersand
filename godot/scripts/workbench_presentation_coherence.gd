extends RefCounted

# PR566: presentation-only swept-mask clearance. The native World remains
# authoritative; this oracle never edits stored cells, Rapier or mask state.
# It uses CyberNativeCellWorld::rasterize_transform_in's world-cell-centre
# oriented rectangle geometry. IMPORTANT: point samples alone are NOT a
# continuous sweep. To preserve conservative safety, *each sampled rectangle*
# is enlarged by a rigorously bounded half-interval displacement: translation
# plus rotation of the furthest collider point. This covers all intermediate
# poses, with expected false refusals, without increasing the sample count.
# Every check includes current and active previous-texture occupancy.
const MAX_SHIFT_CELLS: float = 32.0
const MAX_ROTATION_SWEEP_CELLS: float = 32.0
const MAX_SWEEP_STEPS: int = 32
const MAX_SCAN_CELLS: int = 12000
const EDGE_EPSILON: float = 0.0001

static func _refuse(reason: String, scanned: int = 0) -> Dictionary:
	return {"safe":false,"reason":reason,"scanned":scanned}

static func _is_rigid(pose: Transform2D) -> bool:
	# The swept-motion proof assumes actual Rapier-style rigid transforms.
	# Refuse scale, skew or reflections rather than silently discarding them.
	return absf(pose.x.length_squared()-1.0) <= EDGE_EPSILON \
		and absf(pose.y.length_squared()-1.0) <= EDGE_EPSILON \
		and absf(pose.x.dot(pose.y)) <= EDGE_EPSILON \
		and pose.x.cross(pose.y) > 0.0


static func _touches_body(point: Vector2, pose: Transform2D, rectangles: Array,
		padding: float = 0.0) -> bool:
	var local: Vector2 = pose.affine_inverse() * point
	for rectangle: Dictionary in rectangles:
		var centre: Vector2 = rectangle.get("center",Vector2.INF)
		var size: Vector2 = rectangle.get("size",Vector2.ZERO)
		var d: Vector2 = local - centre
		if absf(d.x) <= size.x * 0.5 + padding + EDGE_EPSILON \
				and absf(d.y) <= size.y * 0.5 + padding + EDGE_EPSILON:
			return true
	return false


static func assess(bound_pose: Transform2D, live_pose: Transform2D, rectangles: Array,
		world_pixels: Image, previous_occupied: Dictionary = {},
		previous_unknown: bool = false, previous_blend_active: bool = false,
		max_scan_cells: int = MAX_SCAN_CELLS, deadline_usec: int = 0) -> Dictionary:
	if world_pixels == null or world_pixels.is_empty() or rectangles.is_empty():
		return _refuse("missing_world_or_geometry")
	if not bound_pose.is_finite() or not live_pose.is_finite():
		return _refuse("nonfinite_pose")
	if not _is_rigid(bound_pose) or not _is_rigid(live_pose):
		return _refuse("nonrigid_pose")
	if previous_blend_active and previous_unknown:
		return _refuse("previous_texture_unbounded")
	var radius: float = 0.0
	for rectangle: Variant in rectangles:
		if not rectangle is Dictionary:
			return _refuse("bad_rectangle")
		var c: Variant = rectangle.get("center")
		var size: Variant = rectangle.get("size")
		if not c is Vector2 or not size is Vector2 or not c.is_finite() or not size.is_finite() 				or size.x <= 0.0 or size.y <= 0.0:
			return _refuse("bad_rectangle")
		radius = maxf(radius, Vector2(c).length() + Vector2(size).length() * 0.5)
	var displacement: float = bound_pose.origin.distance_to(live_pose.origin)
	var angle: float = wrapf(live_pose.get_rotation() - bound_pose.get_rotation(),-PI,PI)
	var rotational_sweep: float = absf(angle) * radius
	if displacement > MAX_SHIFT_CELLS or rotational_sweep > MAX_ROTATION_SWEEP_CELLS:
		return _refuse("bounded_pose_delta")
	if displacement <= EDGE_EPSILON and rotational_sweep <= EDGE_EPSILON:
		return {"safe":true,"reason":"same_pose","scanned":0}
	var sweep: float = maxf(displacement,rotational_sweep)
	var steps: int = clampi(ceili(sweep),1,MAX_SWEEP_STEPS)
	# PROOF (shortest-angle, linearly interpolated rigid motion):
	# For any t in [0,1], a sampled time i/steps exists within 1/(2steps).
	# For any point q in any local collider rectangle, |q| <= radius.
	# Relative to that sample, the world's translation is at most
	# displacement/(2steps), and its rotated location moves by at most
	# 2*radius*sin(abs(angle)/(4steps)) <= radius*abs(angle)/(2steps).
	# Therefore a *true continuously swept* occupied cell centre must lie
	# in the sampled shape's Euclidean dilation by:
	# (displacement + radius*abs(angle))/(2steps).
	# Checking local AABBs expanded by this radius is a superset of the
	# Euclidean dilation. No material can escape between discrete samples.
	# EDGE_EPSILON absorbs float32/world-cell centre rounding.
	var padding: float = (displacement + rotational_sweep) / (2.0 * float(steps))
	var poses: Array[Transform2D] = []
	for i: int in range(steps+1):
		var weight: float = float(i) / float(steps)
		poses.append(Transform2D(bound_pose.get_rotation()+angle*weight,
			bound_pose.origin.lerp(live_pose.origin,weight)))

	# The bound is deliberately the complete turning radius; intermediate
	# rotation cannot escape it, even when endpoint AABBs are narrower.
	var first_x: int = floori(minf(bound_pose.origin.x,live_pose.origin.x)-radius-1.0)
	var last_x: int = ceili(maxf(bound_pose.origin.x,live_pose.origin.x)+radius+1.0)-1
	var first_y: int = floori(minf(bound_pose.origin.y,live_pose.origin.y)-radius-1.0)
	var last_y: int = ceili(maxf(bound_pose.origin.y,live_pose.origin.y)+radius+1.0)-1
	if first_x < 0 or first_y < 0 or last_x >= world_pixels.get_width() or last_y >= world_pixels.get_height():
		return _refuse("outside_world")
	var columns: int = last_x-first_x+1
	var rows: int = last_y-first_y+1
	if max_scan_cells < 1 or columns * rows > max_scan_cells:
		return _refuse("scan_budget")
	var scanned: int = 0
	for y: int in range(first_y,last_y+1):
		for x: int in range(first_x,last_x+1):
			scanned += 1
			# A shared Main deadline caps guard work across all actors, not
			# just each body's rectangular scan. A timeout always refuses.
			if deadline_usec > 0 and (scanned & 31) == 0 \
					and Time.get_ticks_usec() >= deadline_usec:
				return _refuse("time_budget",scanned)
			# Empty pixels need no shape testing. Previous material is tracked
			# only where last accepted patch replaced a nonempty old cell.
			var occupied: bool = world_pixels.get_pixel(x,y).r8 != 0
			if not occupied and previous_blend_active:
				occupied = previous_occupied.has(y*world_pixels.get_width()+x)
			if not occupied: continue
			var cell := Vector2(float(x)+0.5,float(y)+0.5)
			for pose: Transform2D in poses:
				if _touches_body(cell,pose,rectangles,padding):
					return _refuse("material_in_swept_mask",scanned)
	return {"safe":true,"reason":"empty_swept_mask","scanned":scanned,
		"steps":steps,"dilation_cells":padding}
