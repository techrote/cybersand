class_name CyberPixelCameraTransform
extends RefCounted

# Presentation only. Keep the requested camera in floating-point world units;
# snap its *screen translation*, never the simulation's cells or camera state.
# Including the content offset and final canvas/window transform makes one step
# one framebuffer pixel, including letterboxing, stretch and fractional zoom.
static func presentation_origin(camera_origin: Vector2, view_size: Vector2i,
		content: Rect2, screen_transform: Transform2D = Transform2D.IDENTITY) -> Vector2:
	if not _valid_view(view_size, content) or not screen_transform.is_finite() \
			or is_zero_approx(screen_transform.determinant()):
		return camera_origin
	var mapping := presentation_screen_transform(camera_origin, view_size, content, screen_transform)
	return screen_to_world(screen_transform * content.position, mapping)


static func presentation_screen_transform(camera_origin: Vector2, view_size: Vector2i,
		content: Rect2, screen_transform: Transform2D = Transform2D.IDENTITY,
		maximum_origin: Vector2 = Vector2.INF) -> Transform2D:
	if not _valid_view(view_size, content) or not screen_transform.is_finite() \
			or is_zero_approx(screen_transform.determinant()):
		return Transform2D.IDENTITY
	var pixels_per_cell := content.size / Vector2(view_size)
	var basis_x := screen_transform.x * pixels_per_cell.x
	var basis_y := screen_transform.y * pixels_per_cell.y
	var content_origin := screen_transform * content.position
	# Preserve this exact integer screen phase. Reconstructing it from the
	# inverse camera float loses precision at fractional zoom cell boundaries.
	var mapping := Transform2D(basis_x, basis_y,
		(content_origin - basis_x * camera_origin.x - basis_y * camera_origin.y).round())
	if maximum_origin.is_finite():
		var presented := screen_to_world(content_origin, mapping)
		var bounded := presented.clamp(Vector2.ZERO, maximum_origin.max(Vector2.ZERO))
		if is_axis_aligned(mapping):
			# Bounds take precedence only on the clamped axis. A fractional fitted
			# edge may require a fractional screen phase there to avoid a gap.
			if presented.x != bounded.x:
				mapping.origin.x = content_origin.x - basis_x.x * bounded.x
			if presented.y != bounded.y:
				mapping.origin.y = content_origin.y - basis_y.y * bounded.y
		else:
			mapping.origin += basis_x * (presented.x - bounded.x) + basis_y * (presented.y - bounded.y)
	return mapping


static func is_axis_aligned(mapping: Transform2D) -> bool:
	return mapping.x.y == 0.0 and mapping.y.x == 0.0 and mapping.x.x > 0.0 and mapping.y.y > 0.0


static func world_units_per_screen_pixel(mapping: Transform2D) -> Vector2:
	return Vector2.ONE / Vector2(mapping.x.x, mapping.y.y)


static func screen_to_world(point: Vector2, mapping: Transform2D) -> Vector2:
	if not is_axis_aligned(mapping): return mapping.affine_inverse() * point
	# The fragment shader receives this same reciprocal and operation order.
	# Subtract before multiplying so translated samples retain identical bits.
	return (point - mapping.origin) * world_units_per_screen_pixel(mapping)


static func screen_to_cell(point: Vector2, mapping: Transform2D) -> Vector2i:
	return Vector2i(screen_to_world(point.floor() + Vector2(0.5, 0.5), mapping).floor())


static func local_to_world(local: Vector2, origin: Vector2, view_size: Vector2i,
		content: Rect2) -> Vector2:
	if not _valid_view(view_size, content): return Vector2.INF
	return origin + (local - content.position) * Vector2(view_size) / content.size


static func world_to_local(world: Vector2, origin: Vector2, view_size: Vector2i,
		content: Rect2) -> Vector2:
	if not _valid_view(view_size, content): return Vector2.INF
	return content.position + (world - origin) * content.size / Vector2(view_size)


static func local_to_cell(local: Vector2, origin: Vector2, view_size: Vector2i,
		content: Rect2) -> Vector2i:
	if not local.is_finite() or not _valid_view(view_size, content) or not content.has_point(local):
		return Vector2i(-1, -1)
	# Flooring the two terms separately loses the fractional camera remainder.
	return Vector2i(local_to_world(local, origin, view_size, content).floor())


static func local_pixel_center(local: Vector2, screen_transform: Transform2D) -> Vector2:
	if not screen_transform.is_finite() or is_zero_approx(screen_transform.determinant()):
		return local
	# Picking addresses the same physical sample as the fragment shader. At a
	# fractional zoom, the pointer's pixel can straddle a mathematical cell edge.
	var sample_position := (screen_transform * local).floor() + Vector2(0.5, 0.5)
	return screen_transform.affine_inverse() * sample_position


static func origin_for_anchor(anchor_world: Vector2, local: Vector2, view_size: Vector2i,
		content: Rect2) -> Vector2:
	if not _valid_view(view_size, content): return anchor_world
	return anchor_world - (local - content.position) * Vector2(view_size) / content.size


static func _valid_view(view_size: Vector2i, content: Rect2) -> bool:
	return view_size.x > 0 and view_size.y > 0 and content.size.x > 0.0 and content.size.y > 0.0
