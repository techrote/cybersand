class_name CyberObjectShardLabView
extends Control

signal cell_pressed(position: Vector2i, button: int)
signal stroke_requested(cells: Array[Vector2i], button: int)

var frame: Dictionary = {}
var poses: Dictionary = {}
var overlays: bool = false
var world_texture: ImageTexture
var shard_textures: Dictionary = {}
var zoom: float = 1.0
var offset: Vector2 = Vector2.ZERO
var upload_usec: int = 0
var last_drag_cell := Vector2i(-1, -1)
var fixture_cells: Array[Vector2i] = []
var fixture_enabled: bool = false


func present(snapshot: Dictionary, body_poses: Array) -> void:
	var started: int = Time.get_ticks_usec()
	frame = snapshot
	poses.clear()
	for pose: Dictionary in body_poses:
		poses[int(pose.id)] = Transform2D(float(pose.rotation), Vector2(float(pose.x), float(pose.y)))
	var width: int = int(frame.get("width", 0))
	var height: int = int(frame.get("height", 0))
	var rgba: PackedByteArray = frame.get("world_rgba", PackedByteArray())
	if width > 0 and height > 0 and rgba.size() == width * height * 4:
		var picture: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)
		if world_texture == null or world_texture.get_width() != width or world_texture.get_height() != height:
			world_texture = ImageTexture.create_from_image(picture)
		else:
			world_texture.update(picture)
	var live: Dictionary = {}
	for shard: Dictionary in frame.get("shards", []):
		var id: int = int(shard.id)
		live[id] = true
		var previous: Dictionary = shard_textures.get(id, {})
		if previous.is_empty() or int(previous.revision) != int(shard.material_revision):
			var pixels: PackedByteArray = shard.get("rgba", PackedByteArray())
			if pixels.size() == int(shard.width) * int(shard.height) * 4:
				var picture: Image = Image.create_from_data(int(shard.width), int(shard.height), false, Image.FORMAT_RGBA8, pixels)
				var texture: ImageTexture = previous.get("texture", null)
				if texture == null or texture.get_width() != int(shard.width) or texture.get_height() != int(shard.height):
					texture = ImageTexture.create_from_image(picture)
				else:
					texture.update(picture)
				shard_textures[id] = {"texture": texture, "revision": int(shard.material_revision)}
	for id: Variant in shard_textures.keys():
		if not live.has(id):
			shard_textures.erase(id)
	upload_usec = Time.get_ticks_usec() - started
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111923"))
	if frame.is_empty() or world_texture == null:
		return
	var canvas := Vector2(float(frame.width), float(frame.height))
	zoom = maxf(1.0, floorf(minf((size.x - 32.0) / canvas.x, (size.y - 32.0) / canvas.y)))
	offset = (size - canvas * zoom) * 0.5
	draw_set_transform(offset, 0.0, Vector2.ONE * zoom)
	draw_texture(world_texture, Vector2.ZERO)
	if fixture_enabled:
		for point: Vector2i in fixture_cells:
			draw_rect(Rect2(Vector2(point), Vector2.ONE), Color("ffcf66"), false, 1.0 / zoom)
	for shard: Dictionary in frame.get("shards", []):
		var id: int = int(shard.id)
		if not shard_textures.has(id):
			continue
		var pose: Transform2D = material_pose(shard)
		draw_set_transform(offset + pose.origin * zoom, pose.get_rotation(), Vector2.ONE * zoom)
		draw_texture(shard_textures[id].texture, Vector2.ZERO)
		if overlays:
			var rectangles: PackedInt32Array = shard.get("rectangles", PackedInt32Array())
			for at: int in range(0, rectangles.size(), 4):
				draw_rect(Rect2(rectangles[at], rectangles[at + 1], rectangles[at + 2], rectangles[at + 3]),
					Color(0.3, 0.9, 1.0, 0.8), false, 1.0 / zoom)
			draw_circle(Vector2(float(shard.com_x), float(shard.com_y)), 0.7, Color("ffcf66"))
			var pocket: Rect2i = shard.get("pocket", Rect2i())
			if pocket.has_area():
				draw_rect(Rect2(pocket), Color("77e6a5"), false, 1.0 / zoom)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(offset, canvas * zoom), Color("506477"), false, 1.0)


func material_pose(shard: Dictionary) -> Transform2D:
	# A retired RID removes only the live pose sample. Retained material still
	# renders at the coordinator's final physical anchor, not its capture origin.
	var fallback := Transform2D(float(shard.get("rotation", 0.0)), Vector2(
		float(shard.get("position_x", shard.origin_x)), float(shard.get("position_y", shard.origin_y))))
	return poses.get(int(shard.id), fallback)


func _gui_input(event: InputEvent) -> void:
	if frame.is_empty():
		return
	var button: int = 0
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed:
		button = event.button_index
		point = event.position
		last_drag_cell = Vector2i(-1, -1)
	elif event is InputEventMouseButton and not event.pressed:
		last_drag_cell = Vector2i(-1, -1)
		return
	elif event is InputEventMouseMotion:
		point = event.position
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			button = MOUSE_BUTTON_LEFT
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			button = MOUSE_BUTTON_RIGHT
	if button != MOUSE_BUTTON_LEFT and button != MOUSE_BUTTON_RIGHT:
		return
	var cell := Vector2i(floori((point.x - offset.x) / zoom), floori((point.y - offset.y) / zoom))
	if cell.x >= 0 and cell.y >= 0 and cell.x < int(frame.width) and cell.y < int(frame.height):
		if last_drag_cell.x >= 0 and event is InputEventMouseMotion and button == MOUSE_BUTTON_LEFT:
			stroke_requested.emit(stroke_cells(last_drag_cell, cell), button)
		else:
			cell_pressed.emit(cell, button)
		last_drag_cell = cell
		accept_event()
	else:
		last_drag_cell = Vector2i(-1, -1)


static func stroke_cells(first: Vector2i, last: Vector2i) -> Array[Vector2i]:
	# A four-connected supercover prevents fast diagonal mouse events leaving
	# diagonal bonds behind. Each event is bounded; the session owns queue limits.
	var cells: Array[Vector2i] = []
	var point: Vector2i = first
	var delta: Vector2i = (last - first).abs()
	var direction := Vector2i(1 if last.x > first.x else -1, 1 if last.y > first.y else -1)
	var error: int = delta.x - delta.y
	while point != last and cells.size() < 256:
		var twice: int = error * 2
		if twice > -delta.y:
			error -= delta.y
			point.x += direction.x
			cells.append(point)
		if twice < delta.x and cells.size() < 256:
			error += delta.x
			point.y += direction.y
			cells.append(point)
	return cells
