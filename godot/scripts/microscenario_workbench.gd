class_name CyberMicroScenarioWorkbench
extends VBoxContainer

# Common presentation for any schema-2 definition, including pasted generators.
# All simulation changes still travel through the controller's reset/brush APIs.
const Comparison = preload("res://scripts/microscenario_comparison.gd")
var host: Control
var comparison := Comparison.new()
var instructions: Label
var details_button: Button
var compare_button: Button
var run_button: Button
var _run_target: int = -1
var _awaiting_tick: int = -1
var _step_deadline_ms: int = 0
var _run_hash: String = ""
var material_picker: OptionButton
var shape_picker: OptionButton
var radius_input: SpinBox
var ratio_input: SpinBox
var orientation_button: Button
var details_dialog: AcceptDialog
var details_text: TextEdit
var compare_dialog: AcceptDialog
var compare_text: TextEdit
var compare_buttons: Array[Button] = []
var overlay: RegionOverlay
var runtime_identity: Dictionary = {}
var current: Dictionary = {}
var retained_capture: Dictionary = {}
var _shown_hash: String = ""

class RegionOverlay extends Control:
	var host: Control
	var regions: Array = []
	func _draw() -> void:
		if host == null or regions.is_empty(): return
		var content: Rect2 = host.view_content_rect()
		var scale: Vector2 = content.size / Vector2(host.current_view_size)
		var font: Font = ThemeDB.fallback_font
		for item: Dictionary in regions:
			var r: Array = item.region
			var top: Vector2 = content.position + (Vector2(r[0],r[1]) - host.camera_origin) * scale
			var rect := Rect2(top, Vector2(r[2],r[3]) * scale)
			if not rect.intersects(content): continue
			draw_rect(rect.intersection(content), Color(0.7,0.82,1.0,0.35), false, 1.0)
			var point: Vector2 = top + Vector2(5,18)
			if not content.has_point(point): continue
			draw_string(font,point+Vector2.ONE,str(item.label),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8,13,Color.BLACK)
			draw_string(font,point,str(item.label),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8,13,Color(0.92,0.96,1.0))

func _button(row: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	row.add_child(b)
	return b

func _dialog(title: String) -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = title
	add_child(dialog)
	return dialog

func _text(parent: Node) -> TextEdit:
	var text := TextEdit.new()
	text.editable = false
	text.custom_minimum_size = Vector2(800,400)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(text)
	return text

func setup(controller: Control) -> void:
	host = controller
	name = "DefinitionWorkbench"
	runtime_identity = CyberMicroScenarioIdentity.current()
	var row := HFlowContainer.new()
	add_child(row)
	details_button = _button(row,"Identities / all results",open_details)
	compare_button = _button(row,"Fresh-reset A/B",open_comparison)
	run_button = _button(row,"Run declared window",run_declared_window)
	material_picker = OptionButton.new()
	material_picker.focus_mode = Control.FOCUS_NONE
	for id: int in range(1,CyberMicroScenarioContract.MATERIAL_COUNT):
		if id != 10: material_picker.add_item("%d / %s" % [id,host.material_name(id)],id)
	material_picker.item_selected.connect(func(index: int) -> void:
		host.selected_material_id = material_picker.get_item_id(index))
	row.add_child(material_picker)
	shape_picker = OptionButton.new()
	shape_picker.focus_mode = Control.FOCUS_NONE
	for shape: String in ["circle", "square", "rectangle"]:
		shape_picker.add_item(shape.capitalize())
	shape_picker.item_selected.connect(func(index: int) -> void:
		host.set_brush_shape(["circle", "square", "rectangle"][index])
		_refresh_brush_controls())
	row.add_child(shape_picker)
	radius_input = SpinBox.new()
	radius_input.min_value = 1
	radius_input.max_value = 32
	radius_input.step = 1
	radius_input.value = host.brush_size_px
	radius_input.suffix = " px"
	radius_input.custom_minimum_size.x = 170
	radius_input.value_changed.connect(func(value: float) -> void:
		host.set_brush_size(int(value))
		_refresh_brush_controls())
	radius_input.get_line_edit().text_submitted.connect(func(_text: String) -> void: radius_input.get_line_edit().release_focus())
	row.add_child(radius_input)
	ratio_input = SpinBox.new()
	ratio_input.min_value = 1
	ratio_input.max_value = 4
	ratio_input.step = 1
	ratio_input.value = host.brush_rectangle_ratio
	ratio_input.prefix = "Long/short ×"
	ratio_input.custom_minimum_size.x = 145
	ratio_input.value_changed.connect(func(value: float) -> void:
		host.set_brush_rectangle_ratio(int(value))
		_refresh_brush_controls())
	ratio_input.get_line_edit().text_submitted.connect(func(_text: String) -> void: ratio_input.get_line_edit().release_focus())
	row.add_child(ratio_input)
	orientation_button = _button(row, "Rect H", func() -> void:
		host.set_brush_rectangle_vertical(not host.brush_rectangle_vertical)
		_refresh_brush_controls())
	_refresh_brush_controls()
	instructions = Label.new()
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_font_size_override("font_size",13)
	instructions.max_lines_visible = 3
	add_child(instructions)
	details_dialog = _dialog("Definition identities, declared observations and latest results")
	details_text = _text(details_dialog)
	compare_dialog = _dialog("A/B definitions — every load is a fresh validated reset")
	var form := VBoxContainer.new()
	compare_dialog.add_child(form)
	var actions := HFlowContainer.new()
	form.add_child(actions)
	for slot: String in ["A","B"]:
		compare_buttons.append(_button(actions,"Store active as " + slot,store_active.bind(slot)))
		compare_buttons.append(_button(actions,"Fresh reset " + slot,load_slot.bind(slot)))
	compare_buttons.append(_button(actions,"Capture active result",func() -> void: host.microscenario_capture()))
	compare_text = _text(form)
	overlay = RegionOverlay.new()
	overlay.host = host
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.clip_contents = true
	host.world_view.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _refresh_brush_controls() -> void:
	if host == null or shape_picker == null:
		return
	var shapes: Array[String] = ["circle", "square", "rectangle"]
	var shape_index: int = shapes.find(host.brush_shape)
	if shape_index >= 0 and shape_picker.selected != shape_index:
		shape_picker.select(shape_index)
	if int(radius_input.value) != host.brush_size_px:
		radius_input.value = host.brush_size_px
	radius_input.prefix = (
		"Diameter "
		if host.brush_shape == "circle"
		else "Edge "
		if host.brush_shape == "square"
		else "Short edge "
	)
	if int(ratio_input.value) != host.brush_rectangle_ratio:
		ratio_input.value = host.brush_rectangle_ratio
	var rectangle: bool = host.brush_shape == "rectangle"
	ratio_input.visible = rectangle
	orientation_button.visible = rectangle
	orientation_button.text = "Rect V" if host.brush_rectangle_vertical else "Rect H"


func blocked() -> bool:
	return (not host.water_blind_set.is_empty() or not host.water_active_blind_label.is_empty()
		or not host.pending_water_apply.is_empty() or not host.pending_microscenario_apply.is_empty())

func modal_open() -> bool:
	return details_dialog.visible or compare_dialog.visible

func refresh(context: Dictionary) -> void:
	current = context.get("microscenario", {}).duplicate(true)
	var enabled: bool = context.get("micro_active",false) and int(current.get("schema_version",1)) == 2
	var guarded: bool = blocked()
	if host.microscenario_hud_hidden:
		details_dialog.hide()
		compare_dialog.hide()
	visible = enabled and not guarded
	details_button.disabled = guarded or not enabled
	compare_button.disabled = guarded or not enabled
	overlay.visible = enabled and not guarded and not host.microscenario_hud_hidden
	if not enabled or guarded:
		_cancel_run()
		details_dialog.hide()
		compare_dialog.hide()
		return
	var hash: String = str(current.get("definition_hash",""))
	var presentation: Dictionary = current.get("presentation",{})
	if hash != _shown_hash:
		_shown_hash = hash
		retained_capture.clear()
		instructions.text = str(presentation.get("instructions",""))
		instructions.tooltip_text = instructions.text
		overlay.regions = presentation.get("regions",[]).duplicate(true)
	overlay.queue_redraw()
	var tools: Array = current.get("tools",[])
	var brush_enabled: bool = "paint" in tools or "erase" in tools
	material_picker.disabled = not "paint" in tools
	shape_picker.disabled = not brush_enabled
	radius_input.editable = brush_enabled
	ratio_input.editable = brush_enabled
	orientation_button.disabled = not brush_enabled
	_refresh_brush_controls()
	material_picker.select(material_picker.get_item_index(int(host.selected_material_id)))
	for button: Button in compare_buttons: button.disabled = guarded
	_pump_declared_window()

func details() -> Dictionary:
	var materials: Array = []
	for id: int in current.get("material_ids",[]): materials.append({"id":id,"ui_name":host.material_name(id)})
	return {"scenario":current.duplicate(true), "material_identities":materials,
		"interaction_profile":current.get("interaction_profile",{}).duplicate(true),
		"interaction_inspection":current.get("interaction_inspection",[]).duplicate(true),
		"viewer_runtime_identity":runtime_identity.duplicate(true),
		"capture":retained_capture.duplicate(true),
		"notes":"Interaction inspection is read-only native provenance for materials present in this complete definition. A probability roll of zero exposes the candidate rule; it is not an executed-tick claim. Specialized entries identify their current world.cpp authority and are not evaluated by the inspector. Declared probes remain authoritative observations; missing results are pending, not zero. Cell state and temperature are raw engine fields. Capture requests an immutable owner-boundary report; this panel never reads the worker World."}

func open_details() -> void:
	if blocked() or not visible: return
	_cancel_run()
	host.paused = true
	details_text.text = JSON.stringify(details(),"  ")
	details_dialog.popup_centered(Vector2i(860,540))

func open_comparison() -> void:
	if blocked() or not visible: return
	_cancel_run()
	host.paused = true
	_refresh_comparison()
	compare_dialog.popup_centered(Vector2i(860,560))

func store_active(slot: String) -> bool:
	if blocked() or not host.tower_context.get("micro_active",false): return false
	var ok: bool = comparison.store(slot,host.microscenario_definition)
	_refresh_comparison()
	return ok

func load_slot(slot: String) -> bool:
	if blocked(): return false
	var definition: Dictionary = comparison.definition(slot)
	if definition.is_empty(): return false
	var mode: String = str(host.tower_context.get("microscenario",{}).get("mode","Inspect"))
	var ok: bool = host.microscenario_apply_definition(definition,mode)
	if ok: compare_dialog.hide()
	_refresh_comparison()
	return ok

func accept_capture(report: Dictionary) -> void:
	if blocked(): return
	retained_capture = report.duplicate(true)
	comparison.retain(report)
	if details_dialog.visible: details_text.text = JSON.stringify(details(),"  ")
	_refresh_comparison()

func _refresh_comparison() -> void:
	if compare_text == null: return
	compare_text.text = "Store a baseline as A and a candidate as B. Fresh reset A/B uses the complete stored definition, never live worker mutation. Resume each to the same completed tick, pause and capture. Matching runtime/tick/seed alone does not prove that manual brush inputs matched.\n\n" + JSON.stringify(comparison.summary(),"  ")

func cancel_declared_window() -> void:
	_cancel_run()

func _cancel_run() -> void:
	_run_target = -1
	_awaiting_tick = -1
	if run_button != null: run_button.text = "Run declared window"

func run_declared_window() -> bool:
	if _run_target >= 0:
		_cancel_run()
		return true
	if blocked() or not visible or current.get("failed",false): return false
	var target: int = int(current.get("presentation",{}).get("duration_ticks",0))
	if target <= int(current.get("completed_tick",0)) or target > CyberMicroScenarioContract.MAX_TICK: return false
	host.paused = true
	_run_hash = str(current.definition_hash)
	_run_target = target
	_awaiting_tick = -1
	run_button.text = "Cancel bounded run"
	_pump_declared_window()
	return true

func _pump_declared_window() -> void:
	# One acknowledged existing single-step command at a time, at most 3600.
	# This does not add native events, change solver semantics, or access World.
	if _run_target < 0: return
	if blocked() or not host.paused or current.get("failed",false) or str(current.get("definition_hash","")) != _run_hash:
		_cancel_run()
		return
	var tick: int = int(current.get("completed_tick",0))
	if tick >= _run_target:
		_cancel_run()
		return
	if _awaiting_tick >= 0 and tick < _awaiting_tick:
		if Time.get_ticks_msec() > _step_deadline_ms:
			host.microscenario_error = "Bounded run stopped: owner step acknowledgement timed out; no retry"
			_cancel_run()
		return
	_awaiting_tick = tick + 1
	_step_deadline_ms = Time.get_ticks_msec() + 10000
	if not host.tower_command({"step":true}): _cancel_run()
