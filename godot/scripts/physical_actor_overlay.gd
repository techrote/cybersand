class_name CyberPhysicalActorOverlay
extends Control

# Filled polygons use the actual rectangle or circle shape and the bridge's
# authoritative physics transform. This node owns no gameplay or collision.
var outlines: bool = true
var _parts: Array = []
var source_origin: Vector2 = Vector2.INF
var _origin: Vector2 = Vector2.ZERO
var _view_size: Vector2 = Vector2.ONE
const MAX_EXHAUST_PIXELS: int = 160


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func present(parts: Array, origin: Vector2, view_size: Vector2i, content: Rect2) -> void:
	_parts = parts.duplicate(true)
	_origin = origin.floor()
	_view_size = Vector2(view_size)
	position = content.position
	size = content.size
	visible = not _parts.is_empty() or source_origin.is_finite()
	queue_redraw()


func polygon(part: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var half: Vector2 = part.size * 0.5
	var transform: Transform2D = part.transform
	var corners := PackedVector2Array()
	if str(part.get("shape", "rectangle")) == "circle":
		for index: int in range(24):
			corners.append(Vector2.from_angle(float(index) * TAU / 24.0) * half.x)
	else:
		corners = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	for corner: Vector2 in corners:
		result.append((transform * corner - _origin) * size / _view_size)
	return result


func show_workbench_source(receipt: Dictionary) -> void:
	var origin: Vector2 = Vector2(receipt.origin) if receipt.get("armed",false) else Vector2.INF
	if origin != source_origin:
		source_origin = origin
		visible = not _parts.is_empty() or source_origin.is_finite()
		queue_redraw()


func _point(world: Vector2) -> Vector2:
	return (world - _origin) * size / _view_size


func exhaust_pixels(exhaust: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if exhaust.is_empty() or not exhaust.get("pose") is Transform2D or not exhaust.get("bounds") is Rect2: return result
	var pose: Transform2D = exhaust.pose
	var bounds: Rect2 = exhaust.bounds
	if not pose.is_finite() or not bounds.has_area(): return result
	var main: float = clampf(float(exhaust.get("main", 0.0)), -1.0, 1.0)
	var side: float = clampf(float(exhaust.get("side", 0.0)), -1.0, 1.0)
	var turn: float = clampf(float(exhaust.get("turn", 0.0)), -1.0, 1.0)
	var board: bool = bool(exhaust.get("board", false))
	var centre := bounds.get_center()
	var jets: Array[Dictionary] = []
	if absf(main) > 0.001:
		var direction := Vector2(0, signf(main))
		if board: direction = direction.rotated(-pose.get_rotation())
		var nozzle_y: float = bounds.end.y + 0.5 if main > 0.0 else bounds.position.y - 0.5
		if board:
			for offset: float in [-0.28, 0.28]:
				jets.append({"origin":Vector2(centre.x + bounds.size.x * offset, nozzle_y), "direction":direction, "strength":absf(main)})
		else: jets.append({"origin":Vector2(centre.x, nozzle_y), "direction":direction, "strength":absf(main)})
	if absf(side) > 0.001:
		var direction := Vector2(-signf(side), 0)
		if board: direction = direction.rotated(-pose.get_rotation())
		jets.append({"origin":Vector2(bounds.position.x - 0.5 if side > 0.0 else bounds.end.x + 0.5, centre.y),
			"direction":direction, "strength":absf(side)})
	if absf(turn) > 0.001:
		jets.append({"origin":Vector2(bounds.position.x, bounds.end.y + 0.5 if turn > 0.0 else bounds.position.y - 0.5),
			"direction":Vector2(0, signf(turn)), "strength":absf(turn) * 0.6})
		jets.append({"origin":Vector2(bounds.end.x - 1.0, bounds.position.y - 0.5 if turn > 0.0 else bounds.end.y + 0.5),
			"direction":Vector2(0, -signf(turn)), "strength":absf(turn) * 0.6})
	var outer := Color("327dc7") if not bool(exhaust.get("boost", false)) else Color("e88539")
	var core := Color("eaffff")
	var middle := Color("78e7f5") if not bool(exhaust.get("boost", false)) else Color("ffe09a")
	var phase: int = posmod(int(exhaust.get("phase", 0)), 3)
	var emitted: Dictionary = {}
	for jet: Dictionary in jets:
		var length: int = clampi(3 + ceili(float(jet.strength) * 4.0) + int(phase == 1), 3, 8)
		var direction: Vector2 = jet.direction
		var across := direction.orthogonal()
		for step: int in range(length):
			var width: int = 1 if step < length - 2 else 0
			for cross_offset: int in range(-width, width + 1):
				if result.size() >= MAX_EXHAUST_PIXELS: return result
				var world: Vector2 = pose * (Vector2(jet.origin) + direction * step + across * cross_offset)
				var cell := Vector2i(floori(world.x), floori(world.y))
				if emitted.has(cell): continue
				emitted[cell] = true
				var color: Color = outer if cross_offset != 0 else (core if step < 2 else middle)
				result.append({"cell":cell,"color":color})
	return result


func _draw_exhaust(exhaust: Dictionary) -> void:
	var pixel_size: Vector2 = size / _view_size
	for pixel: Dictionary in exhaust_pixels(exhaust):
		# One native-world pixel per rect, snapped before presentation scaling.
		# No antialiasing, separate particle simulation or material writes.
		draw_rect(Rect2(_point(Vector2(pixel.cell)), pixel_size), pixel.color)


func _draw_markings(part: Dictionary) -> void:
	var pose: Transform2D = part.transform
	var half: Vector2 = Vector2(part.size)*0.5
	match part.markings:
		"scoop":
			if str(part.part_id) == "chassis":
				draw_line(_point(pose*Vector2(-half.x*.8,0)),_point(pose*Vector2(half.x*.8,0)),Color("6ffff0"),1.0)
		"board":
			for side: float in [-.65,.65]:
				draw_line(_point(pose*Vector2(half.x*side,-half.y)),_point(pose*Vector2(half.x*side,half.y)),Color("6ffff0"),3.0)
			draw_line(_point(pose*Vector2(-half.x*.9,0)),_point(pose*Vector2(half.x*.9,0)),Color("f7f1c7"),1.0)
		"science":
			var radius: float = minf(half.x,half.y)*.65
			draw_arc(_point(pose.origin),radius*size.x/_view_size.x,0.0,TAU,20,Color("223848"),2.0)
			draw_line(_point(pose*Vector2(-radius,0)),_point(pose*Vector2(radius,0)),Color("8af6ec"),1.0)
			for side: float in [-.75,.75]:
				draw_line(_point(pose*Vector2(half.x*side,-half.y*.7)),_point(pose*Vector2(half.x*side,half.y*.7)),Color("526471"),2.0)
		"scout":
			draw_line(_point(pose*Vector2(0,-half.y*.75)),_point(pose*Vector2(0,half.y*.55)),Color("213448"),2.0)


func _draw() -> void:
	if _view_size.x <= 0.0 or _view_size.y <= 0.0:
		return
	if source_origin.is_finite():
		var outline := PackedVector2Array()
		for delta: Vector2 in [Vector2.ZERO,Vector2(4,0),Vector2(4,24),Vector2(0,24),Vector2.ZERO]:
			outline.append(_point(source_origin + delta))
		draw_polyline(outline,Color("80e9d1"),1.0)
	for part: Dictionary in _parts:
		if part.has("gcr_exhaust"): _draw_exhaust(part.gcr_exhaust)
	for part: Dictionary in _parts:
		var vertices: PackedVector2Array = polygon(part)
		var color: Color = part.color
		draw_colored_polygon(vertices, color.darkened(0.18))
		if outlines:
			vertices.append(vertices[0])
			draw_polyline(vertices, color.lightened(0.35), 1.0, false)
		if part.has("markings"): _draw_markings(part)
		# Cues derive exclusively from the admitted/applied actuator receipt
		# and the real Rapier transform. They never integrate a separate pose.
		if bool(part.get("flight_live", false)):
			var centre: Vector2 = (part.transform.origin - _origin) * size / _view_size
			var force: Vector2 = part.get("flight_force", Vector2.ZERO)
			if force.length_squared() > 1.0:
				draw_line(centre, centre - force.normalized() * clampf(force.length() * 0.025, 2.0, 10.0),
					color.lightened(0.5), 2.0, true)
			var intent: Vector2 = part.get("flight_intent", Vector2.ZERO)
			if intent.length_squared() > 1.0:
				draw_line(centre, centre + intent.normalized() * clampf(intent.length() * 0.075, 2.0, 6.0),
					color.darkened(0.55), 1.0, true)
