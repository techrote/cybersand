extends "res://scripts/player_playground.gd"

const LabRuntime = preload("res://scripts/paired_material_runtime.gd")
const Fixture = preload("res://scripts/paired_material_fixture.gd")
const LabOverlay = preload("res://scripts/paired_material_overlay.gd")
const PALETTE: Array[int] = [135,3,137,132,13,133,23,134,27,30,31,24,12,6,8,2,14,1,0]
const PALETTE_NAMES: Array[String] = ["Dry Binder","Water","Binder Crust","Stone Wall","Stone","Salt Wall","Salt","Coal Wall","Coal","Cement (existing)","Concrete","Brine","Acid","Fire","Lava","Sand","Dust","Hard wall","Erase"]
var family: int = 0
var paint_material: int = 135
var brush_radius: int = 6
var _lab_receipt: Label
var _family_select: OptionButton
var _lab_runtime

func _ready() -> void:
	_lab_runtime=LabRuntime.new()
	runtime=_lab_runtime
	add_child(runtime)
	_build_ui()
	var column: Control = _canvas.get_parent().get_parent().get_parent()
	var heading: Control = column.get_child(0).get_child(0)
	(heading.get_child(0) as Label).text="CYBERSAND / PAIRED MATERIAL LAB"
	(heading.get_child(1) as Label).text="Break the shell. Expose powder. Cure a finite dose."
	(_buttons[0].get_parent().get_child(0) as Label).text="PICK AN ACTOR"
	(column.get_child(column.get_child_count()-1) as Label).text="NATIVE MATERIAL AUTHORITY · PAIRED CHEMISTRY · HARD SUPPORT RELEASE · FINITE CURING"
	for index: int in range(_buttons.size()): _buttons[index].visible=index in [3,6]
	_buttons[3].text="1   Vector Rush"
	_buttons[6].text="2   Barrel Rocket"
	_overlay.free()
	_overlay=LabOverlay.new()
	_canvas.add_child(_overlay)
	_surface=Surface.new()
	add_child(_surface)
	_surface.configure("player-playground",false,Fixture.VIEW.size)
	_terrain.texture=_surface.get_texture()
	_build_lab_controls()
	select_preset(6)
	DisplayServer.window_set_title("CyberSand — paired walls and finite curing")

func _build_lab_controls() -> void:
	var column: Control = _canvas.get_parent().get_parent().get_parent()
	var tools := VBoxContainer.new()
	column.add_child(tools)
	column.move_child(tools,1)
	var row := HBoxContainer.new()
	tools.add_child(row)
	_family_select=OptionButton.new()
	_family_select.focus_mode=Control.FOCUS_NONE
	for name: String in Fixture.FAMILIES: _family_select.add_item(name+" shell / powder")
	_family_select.item_selected.connect(func(value: int) -> void:
		family=value
		select_preset(selected))
	row.add_child(_family_select)
	_button(row,"Breach intact roof",func() -> void:
		_cancel_input()
		_lab_runtime.breach_shell()
		_present(runtime.snapshot(),true))
	_button(row,"Add 16 Water cells",func() -> void:
		_cancel_input()
		_lab_runtime.add_water_dose()
		_present(runtime.snapshot(),true))
	_button(row,"Remove tray Water",func() -> void:
		_cancel_input()
		_lab_runtime.remove_water_dose()
		_present(runtime.snapshot(),true))
	var paint_row := HBoxContainer.new()
	tools.add_child(paint_row)
	var palette := OptionButton.new()
	palette.focus_mode=Control.FOCUS_NONE
	for name: String in PALETTE_NAMES: palette.add_item(name)
	palette.item_selected.connect(func(value: int) -> void: paint_material=PALETTE[value])
	paint_row.add_child(palette)
	_label(paint_row,"LMB paint · RMB erase · wheel brush size · material laws run natively",14,Color("adc0ce"))
	_lab_receipt=_label(tools,"",13,Color("f7c579"))
	_lab_receipt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func select_preset(index: int) -> bool:
	if index not in [3,6]: return false
	_cancel_input()
	if not _lab_runtime.configure_lab(Course.PRESETS[index],family):
		_status.text=runtime.last_error
		return false
	selected=index
	_target=0
	_lap_ticks=0
	_lap_started=false
	_last_draw_tick=-1
	_last_packet_epoch=-1
	_view=Fixture.VIEW
	_pause_button.text="Pause · P"
	_surface.set_render_enabled(true)
	_present(runtime.snapshot(),true)
	return true

func _content_rect() -> Rect2:
	var fit: float = minf(_canvas.size.x/float(Fixture.VIEW.size.x),_canvas.size.y/float(Fixture.VIEW.size.y))
	var dimensions: Vector2 = Vector2(Fixture.VIEW.size)*maxf(0.,fit)
	return Rect2((_canvas.size-dimensions)*.5,dimensions)

func _check_targets(_state: Dictionary) -> void:
	pass

func _toggle_camera() -> void:
	# This apparatus keeps all three bays and its tray visible together.
	_follow=false

func _present(state: Dictionary, force: bool=false) -> void:
	if _surface==null or state.actor.is_empty(): return
	super._present(state,force)
	_view=Fixture.VIEW
	_surface._material.set_shader_parameter("camera_origin_px",Vector2(_view.position))
	_surface._material.set_shader_parameter("view_size_px",Vector2(_view.size))
	_overlay.targets=PackedVector2Array()
	_overlay.present(runtime.render_parts(),Vector2(_view.position),_view.size,_content_rect())
	_title.text="Paired shells / "+Course.NAMES[selected]
	_tagline.text="Current-main actor controls and mass. Chemistry and hard collision are native."
	_controls.text=Course.controls(Course.PRESETS[selected])
	_timing.text=Fixture.FAMILIES[family]+"  ·  A loose / B intact / C breached"
	_hint.text="Fly onto the roof, then breach it. Acid attacks Stone; Water dissolves Salt; Fire burns Coal. Cure one finite dose, then remove Water. Unsupported severed islands remain static."
	if _lab_receipt!=null:
		var tray: Dictionary = _lab_runtime.tray_observation()
		var counts: Variant = tray.get("counts",[])
		var active: int = int(counts[136]) if counts.size()>137 else 0
		var crust: int = int(counts[137]) if counts.size()>137 else 0
		_lab_receipt.text="EXPERIMENTAL · source %s · native profile3 / 138 IDs · Rapier / synchronous · free Water %d · bound Water %d · activated %d · crust %d\nTray sample tick %d · age %.2fs%s · refresh at most 2 Hz. Paint, breach and dose are external edits; this room is not a closed conservation run. Last edit: %s" % [OS.get_environment("CYBERSAND_SOURCE_REVISION").left(12),int(tray.get("water_mass",0)),int(tray.get("bound_water",0)),active,crust,int(tray.get("sample_tick",-1)),float(tray.get("sample_age_usec",0))/1_000_000.0," · awaiting refresh" if bool(tray.get("sample_stale",true)) else "",str(_lab_runtime.authoring_receipt.get("operation","none"))]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key in [KEY_1,KEY_2,KEY_TAB]:
			select_preset(3 if key==KEY_1 or (key==KEY_TAB and selected==6) else 6)
			get_viewport().set_input_as_handled()
			return
		if key>=KEY_3 and key<=KEY_7: return
	if event is InputEventMouseButton and event.pressed and _content_rect().has_point(_canvas.get_local_mouse_position()):
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			brush_radius=clampi(brush_radius+(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1),1,24)
			get_viewport().set_input_as_handled()
			return
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _physics_process(delta: float) -> void:
	if runtime==null or not runtime.active(): return
	var content: Rect2 = _content_rect()
	var pointer: Vector2 = _canvas.get_local_mouse_position()
	if _focused and not runtime.failed and content.has_point(pointer) and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		var cell := Vector2i(Vector2(_view.position)+(pointer-content.position)/content.size*Vector2(_view.size))
		if _lab_runtime.paint_lab(cell,0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else paint_material,brush_radius):
			_surface.set_render_enabled(true)
	super._physics_process(delta)
