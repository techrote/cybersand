extends Control

var interaction: RefCounted
var world_to_local := Transform2D.IDENTITY

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 90
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

func _draw() -> void:
	if interaction == null or interaction.bench == null: return
	var proposed: Dictionary = interaction.placement
	if not proposed.is_empty():
		var color := Color("7debc0") if proposed.get("valid",false) else Color("ff6c7a")
		for part: Dictionary in proposed.get("polygons",[]):
			var polygon := PackedVector2Array()
			for point: Vector2 in part.polygon: polygon.append(world_to_local * point)
			if polygon.size() < 3: continue
			draw_colored_polygon(polygon,Color(color,0.22))
			polygon.append(polygon[0])
			draw_polyline(polygon,color,2.0,true)
		var centre: Vector2 = world_to_local * Vector2(proposed.position)
		draw_circle(centre,4.0,color)
		draw_line(centre,centre+Vector2(26,0).rotated(float(proposed.rotation)),color,2.0,true)
		var caption := "%.2f, %.2f  /  %.1f°" % [proposed.position.x,proposed.position.y,float(proposed.rotation_degrees)]
		draw_string(ThemeDB.fallback_font,centre+Vector2(12,-12),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	var grabbed: Dictionary = interaction.grab_state()
	if grabbed.get("active",false):
		var anchor: Vector2 = world_to_local * Vector2(grabbed.anchor)
		var target: Vector2 = world_to_local * Vector2(grabbed.target)
		draw_line(anchor,target,Color("ffd37b"),2.0,true)
		draw_circle(anchor,4.0,Color("ffd37b"))
		draw_arc(target,7.0,0,TAU,24,Color("fff0ba"),1.5,true)
