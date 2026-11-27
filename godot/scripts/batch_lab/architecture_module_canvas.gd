extends "res://scripts/batch_lab/batch_lab_view.gd"
## Draw semantic guides over the exact material-ID inspection plane. These
## overlays are authored metadata, never native writes or simulated contacts.
signal local_cell_selected(cell: Vector2i)

var show_guides := true
var selected_connector := ""
var selected_cell := Vector2i(-1,-1)
var _semantics := {}
const GUIDE_COLORS := {
	"clearances":Color(0.15,0.8,1.0,0.85),
	"protected_regions":Color(1.0,0.35,0.35,0.9),
	"fixed_regions":Color(0.9,0.9,0.94,0.7),
	"variation_regions":Color(1.0,0.78,0.2,0.85)}

func set_semantics(module: Dictionary) -> void:
	_semantics.clear()
	for key: String in ["anchor","attachments","clearances","protected_regions","fixed_regions","variation_regions"]:
		_semantics[key] = module.get(key,[]).duplicate(true)
	selected_connector = ""
	selected_cell = Vector2i(-1,-1)
	queue_redraw()

func image_rect() -> Rect2:
	return Rect2(size*0.5-center*pixels_per_cell(),Vector2(extent)*pixels_per_cell())

func local_cell_at(position: Vector2) -> Vector2i:
	var point := (position-size*0.5)/pixels_per_cell()+center
	return Vector2i(floori(point.x),floori(point.y))

func _cell_center(raw: Array) -> Vector2:
	return image_rect().position+(Vector2(float(raw[0]),float(raw[1]))+Vector2(0.5,0.5))*pixels_per_cell()

func _draw() -> void:
	super()
	if not show_guides or _semantics.is_empty(): return
	var scale := pixels_per_cell()
	var origin := image_rect().position
	for key: String in GUIDE_COLORS:
		for raw: Array in _semantics.get(key,[]):
			if raw.size()!=4: continue
			var box := Rect2(origin+Vector2(float(raw[0]),float(raw[1]))*scale,Vector2(float(raw[2]),float(raw[3]))*scale)
			var color: Color = GUIDE_COLORS[key]
			draw_rect(box,Color(color,0.08),true)
			draw_rect(box,color,false,1.5)
	var anchor: Array = _semantics.get("anchor",[])
	if anchor.size()==2:
		var point := _cell_center(anchor)
		draw_line(point-Vector2(6,0),point+Vector2(6,0),Color.WHITE,2.0)
		draw_line(point-Vector2(0,6),point+Vector2(0,6),Color.WHITE,2.0)
	for connector: Dictionary in _semantics.get("attachments",[]):
		if not connector.get("point") is Array or connector.point.size()!=2: continue
		var point := _cell_center(connector.point)
		var chosen: bool = connector.get("id","")==selected_connector
		var color := Color(0.4,1.0,0.55) if connector.get("source")=="authored" else Color(0.95,0.65,0.95)
		if chosen: color=Color.WHITE
		if connector.get("kind")=="line" and connector.get("end") is Array and connector.end.size()==2:
			draw_line(point,_cell_center(connector.end),color,3.0 if chosen else 2.0)
		draw_circle(point,4.0 if chosen else 3.0,color)
		var facing: Array = connector.get("facing",[0,-1])
		var direction := Vector2(float(facing[0]),float(facing[1]))
		var tip := point+direction*12.0
		draw_line(point,tip,color,1.5)
		draw_line(tip,tip-direction*4.0+direction.orthogonal()*3.0,color,1.5)
		draw_line(tip,tip-direction*4.0-direction.orthogonal()*3.0,color,1.5)
	if Rect2i(Vector2i.ZERO,extent).has_point(selected_cell):
		draw_rect(Rect2(origin+Vector2(selected_cell)*scale,Vector2.ONE*scale),Color.WHITE,false,2.0)

func _gui_input(event: InputEvent) -> void:
	super(event)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var cell := local_cell_at(event.position)
		if Rect2i(Vector2i.ZERO,extent).has_point(cell):
			selected_cell = cell
			queue_redraw()
			local_cell_selected.emit(cell)
			accept_event()
