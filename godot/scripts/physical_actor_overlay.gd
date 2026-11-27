class_name CyberPhysicalActorOverlay
extends Control

# Filled polygons use the actual rectangle or circle shape and the bridge's
# authoritative physics transform. This node owns no gameplay or collision.
var outlines: bool = true
var _parts: Array = []
var source_origin: Vector2 = Vector2.INF
var equipment_markers: Dictionary = {}
var actor_labels: Dictionary = {}
var _origin: Vector2 = Vector2.ZERO
var _view_size: Vector2 = Vector2.ONE
var _water_layer: CyberPhysicalActorOverlay = null
var _water_state: Dictionary = {}
var _is_water_layer: bool = false
const WATER_COMPOSITION_SHADER = preload("res://shaders/workbench_water_actor_composition.gdshader")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func present(parts: Array, origin: Vector2, view_size: Vector2i, content: Rect2, water_state: Variant = null) -> void:
	_parts = parts.duplicate(true)
	_origin = origin
	_view_size = Vector2(view_size)
	position = content.position
	size = content.size
	visible = not _parts.is_empty() or source_origin.is_finite() or not equipment_markers.is_empty()
	var water_parts: Array = []
	if not _is_water_layer and (not _water_state.is_empty() or (water_state is Dictionary and not water_state.is_empty())):
		for part: Dictionary in _parts:
			if part.get("water_composed", false) and _may_draw_part(part): water_parts.append(part)
	if water_state is Dictionary:
		# Bind only for this submission's drawable Water parts. A camera change
		# re-evaluates them against its own mapping before any polygon is drawn.
		set_water_composition(water_state if not water_parts.is_empty() else {})
	if not _is_water_layer and _water_layer != null and not _water_state.is_empty():
		_water_layer.outlines = outlines
		var shader: ShaderMaterial = _water_layer.material
		shader.set_shader_parameter("world_origin", _origin)
		shader.set_shader_parameter("view_size", _view_size)
		shader.set_shader_parameter("overlay_size", size.max(Vector2.ONE))
		_water_layer.present(water_parts, origin, view_size, Rect2(Vector2.ZERO, size))
	queue_redraw()


func set_water_composition(state: Dictionary) -> void:
	if _is_water_layer: return
	var enabled: bool = state.get("enabled", false) and state.get("current_texture") is Texture2D \
		and state.get("previous_texture") is Texture2D and state.get("world_size") is Vector2i
	if not enabled:
		# Proof availability can alternate on consecutive admitted frames. Keep
		# one bounded layer/material rather than allocate and retire GPU resources
		# on every transition. Drop texture references while it is inactive.
		if not _water_state.is_empty() and _water_layer != null:
			_water_layer._parts.clear()
			_water_layer.hide()
			var shader: ShaderMaterial = _water_layer.material
			shader.set_shader_parameter("current_material", null)
			shader.set_shader_parameter("previous_material", null)
			_water_layer.queue_redraw()
		_water_state.clear()
		return
	if _water_layer == null:
		_water_layer = CyberPhysicalActorOverlay.new()
		_water_layer.name = "ProvenWaterActors"
		_water_layer._is_water_layer = true
		_water_layer.show_behind_parent = true
		var shader := ShaderMaterial.new()
		shader.shader = WATER_COMPOSITION_SHADER
		_water_layer.material = shader
		add_child(_water_layer)
	if state == _water_state: return
	_water_state = state.duplicate()
	var shader: ShaderMaterial = _water_layer.material
	shader.set_shader_parameter("current_material", state.current_texture)
	shader.set_shader_parameter("previous_material", state.previous_texture)
	shader.set_shader_parameter("world_size", Vector2(state.world_size))
	shader.set_shader_parameter("previous_active", bool(state.get("previous_active", false)))
	shader.set_shader_parameter("snapshot_blend", float(state.get("snapshot_blend", 1.0)))


func show_actor_labels(labels: Dictionary) -> void:
	if labels != actor_labels:
		actor_labels = labels.duplicate(true)
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
		visible = not _parts.is_empty() or source_origin.is_finite() or not equipment_markers.is_empty()
		queue_redraw()


# IN-TOOLS #361 device markers from the worker's copied equipment receipt.
func show_liquid_equipment(receipt: Dictionary, selected_valve: int = -1) -> void:
	var markers := {}
	if receipt.get("configured",false):
		var config: Dictionary = receipt.get("config",{})
		var rects := []
		for i: int in receipt.get("valves",[]).size():
			var valve: Dictionary = receipt.valves[i]
			rects.append([valve.rect,valve.open,"valve",i == selected_valve])
		if not config.get("drain",[]).is_empty(): rects.append([config.drain,receipt.drain.open,"drain",false])
		markers.rects = rects
		if not config.get("nozzle",[]).is_empty(): markers.nozzle = [config.nozzle,receipt.nozzle.on,receipt.nozzle.angle]
	if markers != equipment_markers:
		equipment_markers = markers
		visible = not _parts.is_empty() or source_origin.is_finite() or not equipment_markers.is_empty()
		queue_redraw()


func _draw_equipment() -> void:
	for marker: Array in equipment_markers.get("rects",[]):
		var rect: Array = marker[0]
		var live: bool = marker[1]
		var corners := PackedVector2Array()
		for delta: Vector2 in [Vector2.ZERO,Vector2(rect[2],0),Vector2(rect[2],rect[3]),Vector2(0,rect[3]),Vector2.ZERO]:
			corners.append(_point(Vector2(rect[0],rect[1]) + delta))
		var color := (Color("7dff9a") if live else Color("ffb347")) if marker[2] == "valve" else (Color("5fc8ff") if live else Color("3a6f8f"))
		draw_polyline(corners,color,3.0 if marker[3] else (2.0 if live else 1.0))
	if equipment_markers.has("nozzle"):
		var nozzle: Array = equipment_markers.nozzle[0]
		var centre := Vector2(nozzle[0],nozzle[1]) + Vector2(0.5,0.5)
		var tip := centre + Vector2.RIGHT.rotated(deg_to_rad(float(equipment_markers.nozzle[2]))) * 8.0
		var color := Color("9ef0ff") if equipment_markers.nozzle[1] else Color("6a8a99")
		draw_circle(_point(centre),3.0,color)
		draw_line(_point(centre),_point(tip),color,2.0,true)


func _point(world: Vector2) -> Vector2:
	return (world - _origin) * size / _view_size


# Conservative overlay-local raster bounds. Labels, source and equipment
# markers have their own draw paths and keep using the full accepted part list.
func _may_draw_part(part: Dictionary) -> bool:
	if not clip_contents: return true
	if _view_size.x <= 0 or _view_size.y <= 0 or size.x <= 0 or size.y <= 0: return false
	var pose: Transform2D = part.transform
	var half: Vector2 = Vector2(part.size).abs() * 0.5
	if str(part.get("shape","rectangle")) == "circle": half = Vector2.ONE * half.x
	var scale_px := size / _view_size
	var centre := _point(pose.origin)
	var radius := (pose.x.abs() * half.x + pose.y.abs() * half.y) * scale_px
	if part.get("markings","") == "science":
		# This particular arc uses horizontal pixel scale on both axes.
		radius = radius.max(Vector2.ONE * (minf(half.x,half.y) * 0.65 * scale_px.x))
	# The longest live flight cue extends 10 pixels from the centre. Wide
	# markings and antialiasing may reach beyond the geometric footprint.
	if bool(part.get("flight_live",false)): radius = radius.max(Vector2(10,10))
	radius += Vector2(3,3)
	return Rect2(centre - radius, 2.0 * radius).intersects(Rect2(Vector2.ZERO, size), true)


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
	if not equipment_markers.is_empty(): _draw_equipment()
	for part: Dictionary in _parts:
		if not _is_water_layer and (part.get("water_composed", false) or not _may_draw_part(part)): continue
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

	# Labels use the same presented root-part transform as the actor polygons.
	# They identify controller ownership, never add a separate pose authority.
	var labelled := {}
	var font := ThemeDB.fallback_font
	for part: Dictionary in _parts:
		var actor_id: int = int(part.actor_id)
		if labelled.has(actor_id) or not actor_labels.has(actor_id): continue
		labelled[actor_id] = true
		var label: Dictionary = actor_labels[actor_id]
		var caption := str(label.text)
		# Dense sandbox casts keep IDs readable; inspection and the pilot retain
		# the full model/source label. This changes presentation only.
		if actor_labels.size() > 16 and not label.selected and not caption.ends_with(" · PILOT"):
			caption = caption.get_slice(" ",0)
		var anchor: Vector2 = _point(part.transform.origin) + Vector2(0,-14)
		if anchor.x < 0 or anchor.x > size.x or anchor.y < 0 or anchor.y > size.y: continue
		var text_size := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
		anchor.x = clampf(anchor.x-text_size.x*0.5,3,maxf(3,size.x-text_size.x-3))
		draw_rect(Rect2(anchor-Vector2(3,13),text_size+Vector2(6,3)),Color(0.03,0.05,0.08,0.86))
		draw_string(font,anchor,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,label.color)
		if label.selected: draw_circle(_point(part.transform.origin),5,label.color,false,1.0,true)
