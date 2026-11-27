extends RefCounted

# PR566: presentation-only swept-mask clearance. The native World remains
# authoritative; this oracle never edits stored cells, Rapier or mask state.
# It uses CyberNativeCellWorld::rasterize_transform_in's world-cell-centre
# oriented rectangle geometry. IMPORTANT: point samples alone are NOT a
# continuous sweep. To preserve conservative safety, *each sampled rectangle*
# is enlarged by a rigorously bounded half-interval displacement: translation
# plus rotation of the furthest collider point. This covers all intermediate
# poses, with expected false refusals. Coherent callers may refine a material
# refusal once, using the same proof and at most MAX_SWEEP_STEPS intervals.
# Every pass includes current and active previous-texture occupancy.
const MAX_SHIFT_CELLS: float = 32.0
const MAX_ROTATION_SWEEP_CELLS: float = 32.0
const MAX_SWEEP_STEPS: int = 32
const MAX_SCAN_CELLS: int = 12000 # Fine-geometry cells per pass; Main also caps both passes together.
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


# A material-only certificate for an exact subregion of the two actual images.
# The second RG8 channel is material state, so examine only material IDs.
static func region_is_empty(image: Image, region: Rect2i) -> bool:
	if image == null or region.size.x <= 0 or region.size.y <= 0 \
			or not Rect2i(Vector2i.ZERO,image.get_size()).encloses(region) \
			or image.get_format() not in [Image.FORMAT_R8,Image.FORMAT_RG8]: return false
	var ids := image.get_region(region)
	ids.convert(Image.FORMAT_R8)
	return ids.get_data().count(0) == region.get_area()


# Every rotated point in any collider remains within radius of the linearly
# translated origin. The enclosing box therefore covers the continuous rigid
# sweep, including intermediate rotations. Preserve the ordinary motion caps.
static func empty_region_covers_sweep(region: Rect2i, start: Transform2D, target: Transform2D,
		rectangles: Array) -> bool:
	if not start.is_finite() or not target.is_finite() or not _is_rigid(start) or not _is_rigid(target) \
			or rectangles.is_empty() or rectangles.size() > 8 \
			or start.origin.distance_to(target.origin) > MAX_SHIFT_CELLS: return false
	var radius := 0.0
	for rect: Variant in rectangles:
		if not rect is Dictionary: return false
		var center: Variant = rect.get("center")
		var size: Variant = rect.get("size")
		if not center is Vector2 or not size is Vector2 or not center.is_finite() or not size.is_finite() \
				or size.x <= 0.0 or size.y <= 0.0: return false
		radius = maxf(radius,Vector2(center).length()+Vector2(size).length()*0.5)
	if absf(wrapf(target.get_rotation()-start.get_rotation(),-PI,PI))*radius > MAX_ROTATION_SWEEP_CELLS:
		return false
	var edge := Vector2.ONE*(radius+EDGE_EPSILON)
	var minimum := start.origin.min(target.origin)-edge
	var maximum := start.origin.max(target.origin)+edge
	return Rect2(region).encloses(Rect2(minimum,maximum-minimum))


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
		max_scan_cells: int = MAX_SCAN_CELLS, deadline_usec: int = 0,
		previous_world_pixels: Image = null, require_footprint_clear: bool = false,
		current_material_bytes: PackedByteArray = PackedByteArray(),
		previous_material_bytes: PackedByteArray = PackedByteArray(),
		max_empty_scan_cells: int = 0, refine_material_contacts: bool = false,
		compose_water: bool = false) -> Dictionary:
	var coarse: Dictionary = _assess_motion(bound_pose,live_pose,rectangles,
		world_pixels,previous_occupied,previous_unknown,previous_blend_active,
		max_scan_cells,deadline_usec,previous_world_pixels,require_footprint_clear,
		current_material_bytes,previous_material_bytes,max_empty_scan_cells,0,compose_water)
	if not refine_material_contacts or bool(coarse.safe) \
			or coarse.reason != "material_in_swept_mask" \
			or float(coarse.get("dilation_cells",0.0)) == 0.0 \
			or int(coarse.get("steps",MAX_SWEEP_STEPS)) >= MAX_SWEEP_STEPS:
		return coarse
	# The coarse proof deliberately overestimates motion between samples. Near
	# real contacts its roughly half-cell dilation can touch terrain although
	# the entire actual interpolated motion is clear. Refine that uncertainty
	# with the SAME continuous-coverage proof, up to the existing 32 intervals.
	# A coarse hit is never permission to ignore material, and no time, scan,
	# provenance or previous-texture refusal is retried as a clearance success.
	var capacity: int = max_empty_scan_cells if max_empty_scan_cells > 0 else max_scan_cells
	var remaining: int = capacity-int(coarse.scanned)
	var refined: Dictionary
	if remaining <= 0:
		refined = _refuse("scan_budget")
	elif deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec:
		refined = _refuse("time_budget")
	else:
		refined = _assess_motion(bound_pose,live_pose,rectangles,
			world_pixels,previous_occupied,previous_unknown,previous_blend_active,
			mini(max_scan_cells,remaining),deadline_usec,previous_world_pixels,require_footprint_clear,
			current_material_bytes,previous_material_bytes,
			remaining if max_empty_scan_cells > 0 else 0,MAX_SWEEP_STEPS,compose_water)
	# Both passes spend the same shared allowance and cooperative deadline.
	refined.scanned = int(refined.scanned)+int(coarse.scanned)
	refined.refined = true
	refined.coarse_steps = int(coarse.steps)
	refined.coarse_dilation_cells = float(coarse.dilation_cells)
	if bool(refined.safe): refined.reason = "refined_swept_mask"
	return refined


static func _assess_motion(bound_pose: Transform2D, live_pose: Transform2D, rectangles: Array,
		world_pixels: Image, previous_occupied: Dictionary,
		previous_unknown: bool, previous_blend_active: bool,
		max_scan_cells: int, deadline_usec: int,
		previous_world_pixels: Image, require_footprint_clear: bool,
		current_material_bytes: PackedByteArray,
		previous_material_bytes: PackedByteArray,
		max_empty_scan_cells: int, minimum_steps: int, compose_water: bool = false) -> Dictionary:
	if world_pixels == null or world_pixels.is_empty() or rectangles.is_empty():
		return _refuse("missing_world_or_geometry")
	if not bound_pose.is_finite() or not live_pose.is_finite():
		return _refuse("nonfinite_pose")
	if not _is_rigid(bound_pose) or not _is_rigid(live_pose):
		return _refuse("nonrigid_pose")
	if previous_blend_active and previous_unknown:
		return _refuse("previous_texture_unbounded")
	if previous_blend_active and previous_world_pixels != null \
			and (previous_world_pixels.is_empty() or previous_world_pixels.get_size()!=world_pixels.get_size()):
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
	# A native-bound pose is historically trusted by the caller. A retained
	# presentation pose has no such authority after a material upload: its
	# stationary footprint must be checked against both visible textures.
	if not require_footprint_clear and displacement <= EDGE_EPSILON and rotational_sweep <= EDGE_EPSILON:
		return {"safe":true,"reason":"same_pose","scanned":0}
	var sweep: float = maxf(displacement,rotational_sweep)
	var steps: int = clampi(maxi(ceili(sweep),minimum_steps),1,MAX_SWEEP_STEPS)
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
	var inverse_poses: Array[Transform2D] = []
	var boxes: Array[Vector4] = []
	for rectangle: Dictionary in rectangles:
		var centre: Vector2 = rectangle.center
		var half: Vector2 = Vector2(rectangle.size)*0.5 + Vector2.ONE*(padding+EDGE_EPSILON)
		boxes.append(Vector4(centre.x,centre.y,half.x,half.y))
	var low := Vector2.INF
	var high := -Vector2.INF
	for i: int in range(steps+1):
		if deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec:
			return _refuse("time_budget")
		var weight: float = float(i) / float(steps)
		var pose := Transform2D(bound_pose.get_rotation()+angle*weight,
			bound_pose.origin.lerp(live_pose.origin,weight))
		inverse_poses.append(pose.affine_inverse())
		for box: Vector4 in boxes:
			var centre: Vector2 = pose*Vector2(box.x,box.y)
			var extent: Vector2 = pose.x.abs()*box.z+pose.y.abs()*box.w
			low = low.min(centre-extent)
			high = high.max(centre+extent)
	# Every continuous pose is inside the already proven sampled dilations.
	# Their union AABB is therefore sufficient; the old full turning circle
	# scanned thousands of unrelated platform cells around wide thin actors.
	var width: int = world_pixels.get_width()
	var height: int = world_pixels.get_height()
	if low.x < -EDGE_EPSILON*2.0 or low.y < -EDGE_EPSILON*2.0 \
			or high.x > float(width)+EDGE_EPSILON*2.0 or high.y > float(height)+EDGE_EPSILON*2.0:
		return _refuse("outside_world")
	var first_x: int = maxi(0,floori(low.x))
	var last_x: int = mini(width-1,ceili(high.x)-1)
	var first_y: int = maxi(0,floori(low.y))
	var last_y: int = mini(height-1,ceili(high.y)-1)
	var columns: int = last_x-first_x+1
	var rows: int = last_y-first_y+1
	var cells: int = columns*rows
	if max_scan_cells < 1:
		return _refuse("scan_budget")
	var pre_scanned: int = 0
	# A complete clear rectangle is a stronger, cheaper clearance proof than
	# testing each occupied centre against every rotated shape. These bounded
	# copies/counts execute in native Image/PackedByteArray code. The ordinary
	# path still requires every channel to be zero. Explicit Water composition
	# can prove the entire bounds contain only Empty/Water material IDs; its
	# caller separately needs actual completed-pose authority and shader clipping.
	# RG8's second channel is state, never another material ID. Convert a bounded
	# copy to R8 before counting IDs, leaving both immutable source images intact.
	# Charge the whole rectangle to the shared frame cell budget even if this
	# fast proof fails. The 12K fine-geometry cap applies to each pass; the
	# optional refinement also spends the query's remaining shared allowance.
	if cells <= max_empty_scan_cells and (cells > max_scan_cells or cells*2 <= max_empty_scan_cells):
		if deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec:
			return _refuse("time_budget")
		var region := Rect2i(first_x,first_y,columns,rows)
		var region_image: Image = world_pixels.get_region(region)
		if compose_water and region_image.get_format() in [Image.FORMAT_R8,Image.FORMAT_RG8]:
			region_image.convert(Image.FORMAT_R8)
		var bytes: PackedByteArray = region_image.get_data()
		var water_ids: int = bytes.count(3) if compose_water and region_image.get_format()==Image.FORMAT_R8 else 0
		var clear: bool = not bytes.is_empty() and bytes.count(0)+water_ids==bytes.size()
		var water_in_bounds: bool = water_ids > 0
		if clear and previous_blend_active:
			if previous_world_pixels != null:
				region_image = previous_world_pixels.get_region(region)
				if compose_water and region_image.get_format() in [Image.FORMAT_R8,Image.FORMAT_RG8]:
					region_image.convert(Image.FORMAT_R8)
				bytes = region_image.get_data()
				water_ids = bytes.count(3) if compose_water and region_image.get_format()==Image.FORMAT_R8 else 0
				clear = not bytes.is_empty() and bytes.count(0)+water_ids==bytes.size()
				water_in_bounds = water_in_bounds or water_ids > 0
			else:
				clear = previous_occupied.is_empty()
		pre_scanned = cells
		if deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec:
			return _refuse("time_budget",pre_scanned)
		if clear:
			return {"safe":true,"reason":"water_composed_swept_mask" if water_in_bounds else "empty_swept_mask",
				"scanned":pre_scanned,"steps":steps,"dilation_cells":padding,
				"proof":"water_composable_bounds" if water_in_bounds else "empty_bounds",
				"water_in_bounds":water_in_bounds}
		max_scan_cells = mini(max_scan_cells,max_empty_scan_cells-pre_scanned)
	if cells > max_scan_cells:
		return _refuse("scan_budget",pre_scanned)
	# Main supplies the immutable bytes retained once per actual upload. The
	# independent/legacy API retains local Image reads; it must not copy an
	# entire World once per actor merely to inspect this bounded footprint.
	var stride: int = 1 if world_pixels.get_format()==Image.FORMAT_R8 else (2 if world_pixels.get_format()==Image.FORMAT_RG8 else 0)
	var old_stride: int = 0
	if current_material_bytes.is_empty(): stride = 0
	if previous_blend_active and previous_world_pixels != null:
		old_stride = 1 if previous_world_pixels.get_format()==Image.FORMAT_R8 else (2 if previous_world_pixels.get_format()==Image.FORMAT_RG8 else 0)
		if previous_material_bytes.is_empty(): old_stride = 0
	if (stride > 0 and current_material_bytes.size() != width*height*stride) \
			or (old_stride > 0 and previous_material_bytes.size() != width*height*old_stride):
		return _refuse("material_bytes_unbounded",pre_scanned)
	var scanned: int = 0
	var water_in_scan_bounds: bool = false
	for y: int in range(first_y,last_y+1):
		for x: int in range(first_x,last_x+1):
			scanned += 1
			# A shared Main deadline caps guard work across all actors, not
			# just each body's rectangular scan. A timeout always refuses.
			if deadline_usec > 0 and (scanned & 31) == 0 \
					and Time.get_ticks_usec() >= deadline_usec:
				return _refuse("time_budget",pre_scanned+scanned)
			# Empty pixels need no shape testing. The exact previous image
			# covers active crossfade material; the small-patch map is retained
			# for legacy callers without an image.
			var cell_index: int = y*width+x
			var current_id: int = int(current_material_bytes[cell_index*stride]) \
				if stride > 0 else int(world_pixels.get_pixel(x,y).r8)
			var previous_id: int = 0
			if previous_blend_active:
				previous_id = int(previous_material_bytes[cell_index*old_stride]) if old_stride > 0 \
					else (int(previous_world_pixels.get_pixel(x,y).r8) if previous_world_pixels != null \
					else (1 if previous_occupied.has(cell_index) else 0))
			if current_id == 0 and previous_id == 0: continue
			# This flag is a presentation composition proof, never empty-space
			# permission. The caller must separately prove the current completed
			# pose/native dependency and use the Water-only clipped draw layer.
			if compose_water and (current_id == 0 or current_id == 3) and (previous_id == 0 or previous_id == 3):
				# Water anywhere in these conservative bounds selects the clipped
				# layer. Only incompatible material needs the swept polygon test.
				water_in_scan_bounds = true
				continue
			var cell := Vector2(float(x)+0.5,float(y)+0.5)
			for inverse_pose: Transform2D in inverse_poses:
				var local: Vector2 = inverse_pose*cell
				for box: Vector4 in boxes:
					if absf(local.x-box.x)<=box.z and absf(local.y-box.y)<=box.w:
						var refused: Dictionary = _refuse("material_in_swept_mask",pre_scanned+scanned)
						refused.steps = steps
						refused.dilation_cells = padding
						return refused
	return {"safe":true,"reason":"water_composed_swept_mask" if water_in_scan_bounds else "empty_swept_mask",
		"scanned":pre_scanned+scanned,"water_in_bounds":water_in_scan_bounds,
		"steps":steps,"dilation_cells":padding}
