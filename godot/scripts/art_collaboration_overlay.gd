extends Control
## A copied-material difference overlay, never a World or execution authority.
var host: Control
var region := Rect2i()
var texture: ImageTexture
var enabled := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 75
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

func clear() -> void:
	texture = null
	enabled = false
	queue_redraw()

func show_difference(bounds: Rect2i, before: PackedInt32Array, after: PackedInt32Array) -> void:
	clear()
	if not bounds.has_area() or before.size() != after.size() or after.size() != bounds.size.x*bounds.size.y or after.size() > 262144: return
	var pixels := PackedByteArray()
	pixels.resize(after.size()*4)
	pixels.fill(0)
	for i: int in after.size():
		if before[i] == after[i]: continue
		var p := i*4
		# Cyan additions, amber replacements, red carving; material identity is
		# in the proposal inspector. This is a diagnostic overlay, not shading.
		var color := Color(0.2,0.9,1.0,0.65) if before[i] == 0 else Color(1.0,0.75,0.2,0.7)
		if after[i] == 0: color = Color(1.0,0.25,0.3,0.7)
		pixels[p] = color.r8; pixels[p+1] = color.g8; pixels[p+2] = color.b8; pixels[p+3] = color.a8
	texture = ImageTexture.create_from_image(Image.create_from_data(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8,pixels))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region = bounds
	enabled = true
	queue_redraw()

func _process(_delta: float) -> void:
	if enabled and visible: queue_redraw()

func _draw() -> void:
	if not enabled or texture == null or not is_instance_valid(host): return
	var area: Rect2 = host.view_content_rect()
	var dimensions: Vector2 = Vector2(host.current_view_size)
	if not area.has_area() or dimensions.x <= 0 or dimensions.y <= 0: return
	var scale := area.size/dimensions
	var target := Rect2(area.position+(Vector2(region.position)-Vector2(host.camera_origin).floor())*scale,Vector2(region.size)*scale)
	draw_texture_rect(texture,target,false)
	draw_rect(target,Color(0.5,0.95,1.0,0.95),false,1.0)
