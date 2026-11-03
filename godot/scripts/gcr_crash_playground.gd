extends "res://scripts/player_playground.gd"

# Explicit owner-review scene only. Reuses the synchronous arena and controllers.
# Painting is an intentional native authoring edit between owner steps.
const CRASH_VIEW := Rect2i(16,16,992,480)
const MATERIALS: Array[int] = [2,14,29,13,19,23,25,26,27,3,58,0]
const MATERIAL_NAMES: Array[String] = ["Sand","Dust","Rust","Stone","Seed","Salt","Sodium","Gunpowder","Coal","Water","Hard wall","Erase"]
var paint_material: int = 2
var brush_radius: int = 8
var _brush_label: Label

func _ready() -> void:
	_granular_experiment = "GCR"
	_granular_token = "GCR-001-2026-11-01"
	super._ready()
	_surface.free()
	_surface = Surface.new()
	add_child(_surface)
	_surface.configure("player-playground",false,Vector2i(992,480))
	_terrain.texture = _surface.get_texture()
	var tools := HBoxContainer.new()
	var canvas_column: Control = _canvas.get_parent()
	canvas_column.add_child(tools)
	canvas_column.move_child(tools,0)
	var palette := OptionButton.new()
	palette.focus_mode = Control.FOCUS_NONE
	for material_name: String in MATERIAL_NAMES: palette.add_item(material_name)
	palette.item_selected.connect(func(index: int) -> void: paint_material = MATERIALS[index])
	tools.add_child(palette)
	_brush_label = _label(tools,"",16,Color.WHITE)
	_follow = true
	select_preset(6)
	DisplayServer.window_set_title("CyberSand — GCR crash playground + material painting")

func select_preset(index: int) -> bool:
	if Course.is_swarm(Course.PRESETS[index]): return false
	if not super.select_preset(index): return false
	return seed_crash_room()

func seed_crash_room() -> bool:
	var world: Object = runtime._arena._world
	if not world.diagnostic_fill_rect(Vector2i(0,0),Vector2i(1024,512),0): return false
	for rect: Rect2i in [Rect2i(16,475,992,21),Rect2i(16,16,6,480),Rect2i(1002,16,6,480),Rect2i(16,16,992,6)]:
		if not world.diagnostic_fill_rect(rect.position,rect.size,58): return false
	# Separated, deep category banks; varied height and stepped slopes.
	for i: int in range(9):
		var x: int = 70 + i * 100
		var height: int = 50 + (i % 3) * 22
		if not world.diagnostic_fill_rect(Vector2i(x,475-height),Vector2i(70,height),MATERIALS[i]): return false
		for step: int in range(5):
			if not world.diagnostic_fill_rect(Vector2i(x-20+step*4,465-step*8),Vector2i(4,10+step*8),MATERIALS[i]): return false
	# A second airborne tier provides glancing entries and thin support.
	for i: int in range(4):
		var x: int = 285+i*170
		if not world.diagnostic_fill_rect(Vector2i(x,255-i%2*55),Vector2i(86,5),58): return false
		if not world.diagnostic_fill_rect(Vector2i(x,225-i%2*55),Vector2i(64,30),MATERIALS[i]): return false
	_present(runtime.snapshot(),true)
	return true

func _content_rect() -> Rect2:
	var fit: float = minf(_canvas.size.x / float(_view.size.x),_canvas.size.y / float(_view.size.y))
	var dimensions: Vector2 = Vector2(_view.size)*maxf(0.0,fit)
	return Rect2((_canvas.size-dimensions)*0.5,dimensions)

func _present(state: Dictionary, force: bool = false) -> void:
	super._present(state,force)
	if _surface == null or state.actor.is_empty(): return
	var position: Vector2 = state.actor.get("position",Vector2(178,264))
	_view = CRASH_VIEW
	if _follow: _view = Rect2i(clampi(floori(position.x)-256,16,496),clampi(floori(position.y)-128,16,240),512,256)
	_surface._material.set_shader_parameter("camera_origin_px",Vector2(_view.position))
	_surface._material.set_shader_parameter("view_size_px",Vector2(_view.size))
	_overlay.targets = PackedVector2Array()
	_overlay.present(runtime.render_parts(),Vector2(_view.position),_view.size,_content_rect())
	_timing.text = "FREE PLAY — %s — F: overview / follow" % _granular_experiment
	_hint.text = "LMB paint selected material · RMB erase · mouse wheel brush size · R resets terrain and actor · P pauses. All nine granular materials; reactions remain active."
	if _brush_label != null: _brush_label.text = "  Radius %d · wheel to resize" % brush_radius

func paint_at(cell: Vector2i, material: int) -> bool:
	if runtime == null or runtime._arena == null or not CRASH_VIEW.grow(-brush_radius-6).has_point(cell): return false
	if material not in MATERIALS: return false
	runtime._arena._world.paint_disc(cell.x,cell.y,brush_radius,material,0)
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _content_rect().has_point(_canvas.get_local_mouse_position()):
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			brush_radius = clampi(brush_radius+(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1),2,24)
			get_viewport().set_input_as_handled()
			return
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _physics_process(delta: float) -> void:
	# No worker or Rapier API is called by painting. One bounded edit per tick.
	if _focused and runtime != null and runtime._arena != null and not runtime.failed:
		var content := _content_rect()
		var pointer := _canvas.get_local_mouse_position()
		if content.has_point(pointer) and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			var cell := Vector2i(Vector2(_view.position)+(pointer-content.position)/content.size*Vector2(_view.size))
			if paint_at(cell,0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else paint_material):
				_surface.set_render_enabled(true)
				_present(runtime.snapshot(),true)
	super._physics_process(delta)
