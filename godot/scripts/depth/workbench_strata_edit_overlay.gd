extends Control

## A bounded screen-space guide using the same inverse pair as the presenter.
## It holds no native World and never infers material authority from pixels.
var controller: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 90
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true


func _region(rect: Rect2i, colour: Color, filled: bool = false) -> void:
	var id: String = controller.active_layer()
	var start: Vector2 = controller.presenter.layer_to_screen(Vector2(rect.position),id)
	var end: Vector2 = controller.presenter.layer_to_screen(Vector2(rect.end),id)
	var area := Rect2(start,end-start).intersection(controller.wb.host.view_content_rect())
	if area.has_area(): draw_rect(area,colour,filled,1.5)


func _draw() -> void:
	if controller == null or not controller.enabled() or controller.active_layer() == "play": return
	if not controller.presenter.effective_visible(controller.active_layer()): return
	if controller.selection.has_area(): _region(controller.selection,Color(1.0,0.78,0.28,0.9))
	var gesture: Dictionary = controller.gesture()
	var cursor: Vector2i = controller.cursor
	if cursor.x < 0: return
	if not gesture.is_empty() and gesture.tool in ["Rectangle","Outline","Select"]:
		var anchor: Vector2i = gesture.anchor
		_region(Rect2i(anchor.min(cursor),anchor.max(cursor)-anchor.min(cursor)+Vector2i.ONE),Color(0.45,0.9,1.0,0.9))
	else:
		var radius: int = controller.wb.paint_editor.radius()
		_region(Rect2i(cursor-Vector2i(radius,radius),Vector2i.ONE*(radius*2+1)),Color(0.45,0.9,1.0,0.85))
