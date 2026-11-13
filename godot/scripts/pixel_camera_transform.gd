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
	var pixels_per_cell := content.size / Vector2(view_size)
	var screen_zero := screen_transform * (content.position - camera_origin * pixels_per_cell)
	var local_zero := screen_transform.affine_inverse() * screen_zero.round()
	return (content.position - local_zero) / pixels_per_cell


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
