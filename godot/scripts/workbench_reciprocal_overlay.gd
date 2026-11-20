extends Control

var panel: Control

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE;z_index=90
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents=true

func _draw() -> void:
	if panel==null or not panel.visible or panel.bench.applied.is_empty(): return
	var host:Control=panel.bench.host
	var content:Rect2=host.view_content_rect()
	if not content.has_area(): return
	var scale:=content.size/Vector2(host.current_view_size)
	var camera:=Vector2(host.camera_origin).floor()
	var region:Rect2i=panel.territory
	if region.has_area():
		var rect:=Rect2(content.position+(Vector2(region.position)-camera)*scale,Vector2(region.size)*scale)
		draw_rect(rect,Color(0.15,0.6,0.9,0.08),true)
		draw_rect(rect,Color(0.4,0.8,1,0.9),false,2)
		var masks:Dictionary=panel.ownership_preview()
		if not panel.controls.shared_ownership.button_pressed:
			for run:Rect2i in masks.interface_runs:
				var band:=Rect2(content.position+(Vector2(region.position+run.position)-camera)*scale,Vector2(run.size)*scale)
				draw_rect(band,Color(0.85,0.62,0.3,0.15),true)
		for run:Rect2i in masks.shared_runs:
			var shared:=Rect2(content.position+(Vector2(region.position+run.position)-camera)*scale,Vector2(run.size)*scale)
			draw_rect(shared,Color(0.4,1,0.5,0.12),true)
	for point:Vector2i in panel.activation:
		draw_circle(content.position+(Vector2(point)+Vector2(0.5,0.5)-camera)*scale,4,Color(0.4,0.8,1))
	for point:Vector2i in panel.protected_points:
		if region.has_point(point): draw_rect(Rect2(content.position+(Vector2(point)-camera)*scale,scale),Color(0.4,0.95,1,0.45))
