extends Node

## UI-only Strata authoring workflow. Every source inspection, preview, approval,
## write and effect change crosses the ordinary Workbench mediator. This object
## never receives a native World or submits native mutations itself.
const PLANES := ["scripted", "effects", "background"]
const PLANE_LABELS := ["Rear architecture", "Atmosphere / effects", "Background"]
const TRANSFORMS := ["identity", "mirror_x", "mirror_y", "rotate_90", "rotate_180", "rotate_270"]
const TRANSFORM_LABELS := ["Unchanged", "Mirror horizontally", "Mirror vertically", "Rotate 90°", "Rotate 180°", "Rotate 270°"]

class PreviewSurface extends Control:

	var image_texture: Texture2D
	var image_reference: Variant
	var image_extent := Vector2i.ZERO
	var caption := "No proposed image"

	func _init() -> void:
		custom_minimum_size = Vector2(180, 144)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func set_image(value: Variant) -> void:
		# Proposals are copied immutable images. Status polling must not allocate
		# a new GPU texture for the same image on every progress callback.
		if value == image_reference: return
		image_reference = value
		if value is Image and not value.is_empty():
			image_texture = ImageTexture.create_from_image(value)
			image_extent = value.get_size()
		elif value is Texture2D:
			image_texture = value
			image_extent = Vector2i(value.get_size())
		else:
			image_texture = null
			image_extent = Vector2i.ZERO
		queue_redraw()

	func _draw() -> void:
		for y: int in int(ceil(size.y / 16.0)):
			for x: int in int(ceil(size.x / 16.0)):
				var shade := Color("26313b") if (x + y) % 2 == 0 else Color("38454f")
				draw_rect(Rect2(x * 16, y * 16, 16, 16).intersection(Rect2(Vector2.ZERO, size)), shade)
		if image_texture != null and image_extent.x > 0 and image_extent.y > 0:
			var fit := minf(size.x / float(image_extent.x), size.y / float(image_extent.y))
			var drawn := Vector2(image_extent) * fit
			draw_texture_rect(image_texture, Rect2((size - drawn) * 0.5, drawn), false)
			draw_rect(Rect2(Vector2.ZERO, size), Color("8094a1"), false)


var controller: Node
var _syncing := false
var _tabs: TabContainer
var _source := LineEdit.new()
var _mask := LineEdit.new()
var _source_info := Label.new()
var _import_plane := OptionButton.new()
var _fixture := OptionButton.new()
var _fixtures: Array = []
var _crop: Array[SpinBox] = []
var _origin: Array[SpinBox] = []
var _scale: SpinBox
var _transform := OptionButton.new()
var _alpha_mode := OptionButton.new()
var _threshold: SpinBox
var _distance: SpinBox
var _unmapped := OptionButton.new()
var _palette_rows := VBoxContainer.new()
var _palette: Array[Dictionary] = []
var _materials: Array = []
var _native_source := false
var _raster_buttons: Array[Button] = []
var _source_preview := PreviewSurface.new()
var _mask_preview := PreviewSurface.new()
var _output_preview := PreviewSurface.new()
var _preview_summary := Label.new()
var _authoring_status := Label.new()
var _progress := ProgressBar.new()
var _approve := Button.new()
var _stop := Button.new()
var _token: Variant
var _last_state_key := ""
var _configuration_revision := 0
var _preview_ui_revision := -1
var _preview_request_revision := -1
var _previous_preview_identity := ""
var _last_atmosphere_key := ""
var _last_harvested_key := ""
var _compose_progress := ProgressBar.new()
var _compose_approve := Button.new()
var _compose_stop := Button.new()
var _compose_status := Label.new()
var _compose_preview := PreviewSurface.new()
var _compose_preview_scope := Label.new()
var _stage_picker := OptionButton.new()
var _stage_previews: Array = []
var _stage_preview_key := ""
var _stage_before := PreviewSurface.new()
var _stage_after := PreviewSurface.new()
var _history_warning := Label.new()
var _compose_history_warning := Label.new()
var _visual_settings_summary := Label.new()
var _apply_visual_settings := Button.new()
var _visual_review_token := ""
var _browse: FileDialog
var _module := OptionButton.new()
var _modules: Array = []
var _composition := OptionButton.new()
var _compositions: Array = []
var _module_plane := OptionButton.new()
var _module_origin: Array[SpinBox] = []
var _module_transform := OptionButton.new()
var _repeat: SpinBox
var _step: Array[SpinBox] = []
var _harvest_region: Array[SpinBox] = []
var _module_name := LineEdit.new()
var _plan_rows := Label.new()
var _effect_profile := OptionButton.new()
var _effect_description := Label.new()
var _effect_profiles: Array = []
var _effect_list := OptionButton.new()
var _effect_ids: Array[String] = []
var _effect_plane := OptionButton.new()
var _effect_region: Array[SpinBox] = []
var _effects_enabled := CheckButton.new()
var _effects_paused := CheckButton.new()
var _effect_enabled := CheckBox.new()
var _effect_count: SpinBox
var _effect_speed: SpinBox
var _effect_strength: SpinBox
var _effect_direction: Array[SpinBox] = []
var _effect_colour := ColorPickerButton.new()
var _effect_seed: SpinBox
var _effect_status := Label.new()


func mount(mediator: Node, tabs: TabContainer) -> void:
	controller = mediator
	_tabs = tabs
	name = "StrataAuthoringControls"
	_materials = _array_call("authoring_materials")
	_build_import(_page("Import"))
	_build_compose(_page("Compose"))
	_build_atmosphere(_page("Atmosphere"))
	refresh_catalogues()
	refresh({}, "")
	set_process(false)


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	scroll.add_child(margin)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)
	return rows


func _note(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: _commit_field(); action.call())
	parent.add_child(button)
	return button


func _commit_field() -> void:
	# The floating Strata Window owns a separate viewport/focus. Apply its
	# currently typed number before any action reads SpinBox.value.
	var focus := _tabs.get_viewport().gui_get_focus_owner()
	if focus is LineEdit and focus.get_parent() is SpinBox: focus.get_parent().apply()
	if focus != null: focus.release_focus()


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	return row


func _spin(parent: Control, caption: String, low: float, high: float, value: float, step: float = 1.0) -> SpinBox:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	_note(box, caption)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(spin)
	return spin


func _numbers(parent: Control, captions: Array, low: float, high: float, defaults: Array) -> Array[SpinBox]:
	var row := _row(parent)
	var result: Array[SpinBox] = []
	for i: int in captions.size():
		result.append(_spin(row, str(captions[i]), low, high, float(defaults[i])))
	return result


func _plane_picker(parent: Control, picker: OptionButton, include_play: bool = false) -> void:
	if include_play:
		picker.add_item("Play · paused native geometry and collision")
		picker.set_item_metadata(0,"play")
	for index: int in PLANES.size():
		picker.add_item(PLANE_LABELS[index])
		picker.set_item_metadata(picker.item_count-1,PLANES[index])
	if include_play: picker.select(1)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(picker)


func _selected_plane(picker: OptionButton) -> String:
	return str(picker.get_item_metadata(picker.selected)) if picker.selected >= 0 else ""


func _select_plane(picker: OptionButton, plane: String) -> void:
	for index: int in picker.item_count:
		if picker.get_item_metadata(index) == plane: picker.select(index); return


func _transform_picker(parent: Control, picker: OptionButton) -> void:
	for title: String in TRANSFORM_LABELS: picker.add_item(title)
	parent.add_child(picker)


func _build_import(rows: VBoxContainer) -> void:
	_note(rows, "IMPORT TO NATIVE MATERIALS")
	_note(rows, "Choose a local PNG or native module. Inspection and Preview change no cells. Approve applies bounded chunks; Stop retains the acknowledged prefix.")
	var examples := _row(rows)
	_fixture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	examples.add_child(_fixture)
	_button(examples, "Load sample", _load_fixture)
	var source_row := _row(rows)
	_source.placeholder_text = "Local PNG or native module path"
	_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_row.add_child(_source)
	_button(source_row, "Browse…", func() -> void: _choose_source(false))
	_button(source_row, "Inspect", _inspect_source)
	_source_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_source_info)
	var mask_row := _row(rows)
	_mask.placeholder_text = "Mask PNG · nontransparent white/light pixels include; dark/transparent exclude"
	_mask.tooltip_text = "Same-resolution mask. A pixel is included only when alpha > 0 and mean RGB ≥ 128. Excluded pixels always mean no write, including Replace."
	_mask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_row.add_child(_mask)
	_raster_buttons.append(_button(mask_row, "Mask…", func() -> void: _choose_source(true)))
	_raster_buttons.append(_button(mask_row, "Clear", func() -> void: _mask.text = ""; _mask_preview.set_image(null); _invalidate_preview()))
	_note(rows, "Target plane · Play imports require Pause and change real collision geometry through ordinary Play history. Decorative targets have no actor authority.")
	_plane_picker(rows, _import_plane, true)
	_crop = _numbers(rows, ["Crop X", "Crop Y", "Width", "Height"], 0, 2048, [0, 0, 64, 64])
	_crop[2].min_value = 1
	_crop[3].min_value = 1
	_origin = _numbers(rows, ["Placement X", "Placement Y"], 0, 2047, [32, 32])
	var transform_row := _row(rows)
	_scale = _spin(transform_row, "Integer pixel scale", 1, 4, 1)
	var transform_box := VBoxContainer.new()
	transform_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transform_row.add_child(transform_box)
	_note(transform_box, "Exact grid transform")
	_transform_picker(transform_box, _transform)
	var alpha_row := _row(rows)
	var alpha_box := VBoxContainer.new()
	alpha_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alpha_row.add_child(alpha_box)
	_note(alpha_box, "Transparent / low-alpha pixels")
	_alpha_mode.add_item("Overlay · no write into cutouts")
	_alpha_mode.add_item("Replace · explicitly write Empty")
	alpha_box.add_child(_alpha_mode)
	_threshold = _spin(alpha_row, "Opaque threshold (1–255)", 1, 255, 128)
	_note(rows, "Overlay preserves destination cells under transparent pixels. Replace proposes actual Empty writes. Mask-excluded pixels remain untouched in either mode. Partly transparent pixels use the selected threshold.")
	var mapping_row := _row(rows)
	_distance = _spin(mapping_row, "Maximum RGB distance", 0, 442, 0)
	var unmapped_box := VBoxContainer.new()
	unmapped_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mapping_row.add_child(unmapped_box)
	_note(unmapped_box, "Unmapped pixels")
	_unmapped.add_item("Refuse the proposal")
	_unmapped.add_item("Skip and report")
	unmapped_box.add_child(_unmapped)
	_note(rows, "Colour → admitted native material palette")
	rows.add_child(_palette_rows)
	_raster_buttons.append(_button(rows, "Add palette colour", func() -> void: _add_palette_row(Color("8899aa"), 58)))
	_add_palette_row(Color("8899aa"), 58)
	_add_palette_row(Color("33ccdd"), 77)
	_button(rows, "Preview proposed native placement", _preview_import)
	var previews := _row(rows)
	_preview_box(previews, "Source · checkerboard shows alpha", _source_preview)
	_preview_box(previews, "Mask · excluded pixels are no-write", _mask_preview)
	_preview_box(previews, "Proposed material layout", _output_preview)
	_preview_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_preview_summary)
	_history_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history_warning.modulate = Color("e5c388")
	rows.add_child(_history_warning)
	_build_execution_controls(rows)
	for spin: SpinBox in _crop + _origin + [_scale, _threshold, _distance]:
		spin.value_changed.connect(func(_v: float) -> void: _invalidate_preview())
	for option: OptionButton in [_import_plane, _transform, _alpha_mode, _unmapped]:
		option.item_selected.connect(func(_index: int) -> void: _invalidate_preview())
	_source.text_changed.connect(func(_text: String) -> void: _invalidate_preview())
	_mask.text_changed.connect(func(_text: String) -> void: _invalidate_preview())


func _preview_box(parent: Control, caption: String, preview: Control) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	_note(box, caption)
	box.add_child(preview)


func _build_execution_controls(rows: Control) -> void:
	_progress.show_percentage = false
	rows.add_child(_progress)
	var actions := _row(rows)
	_approve.text = "Approve reviewed placement"
	_approve.disabled = true
	_approve.pressed.connect(func() -> void:
		_commit_field()
		if _token != null and _preview_ui_revision == _configuration_revision: _invoke("approve_plan", [_token])
		refresh({}, ""))
	actions.add_child(_approve)
	_stop.text = "Stop · keep applied prefix"
	_stop.disabled = true
	_stop.pressed.connect(func() -> void: _invoke("stop_authoring"); refresh({}, ""))
	actions.add_child(_stop)
	_authoring_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_authoring_status)


func _add_palette_row(colour: Color, material: int) -> void:
	var row := _row(_palette_rows)
	var colour_picker := ColorPickerButton.new()
	colour_picker.color = colour
	colour_picker.edit_alpha = false
	colour_picker.custom_minimum_size = Vector2(68, 28)
	row.add_child(colour_picker)
	var material_picker := OptionButton.new()
	material_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Dictionary in _materials:
		material_picker.add_item("%s · %d" % [str(entry.get("label", entry.get("id", ""))), int(entry.get("id", 0))], int(entry.get("id", 0)))
	var selected := material_picker.get_item_index(material)
	if selected >= 0: material_picker.select(selected)
	row.add_child(material_picker)
	var role := LineEdit.new()
	role.placeholder_text = "Role (optional)"
	role.custom_minimum_size.x = 100
	row.add_child(role)
	var record := {"row":row, "colour":colour_picker, "material":material_picker, "role":role}
	_palette.append(record)
	record.remove = _button(row, "×", func() -> void: _palette.erase(record); row.queue_free(); _invalidate_preview())
	colour_picker.color_changed.connect(func(_colour: Color) -> void: _invalidate_preview())
	material_picker.item_selected.connect(func(_index: int) -> void: _invalidate_preview())
	role.text_changed.connect(func(_text: String) -> void: _invalidate_preview())
	_invalidate_preview()


func _replace_palette(entries: Array) -> void:
	for record: Dictionary in _palette:
		(record.row as Control).queue_free()
	_palette.clear()
	for entry: Dictionary in entries:
		var rgb: Array = entry.get("rgb", [136, 153, 170])
		if rgb.size() != 3: continue
		_add_palette_row(Color8(int(rgb[0]), int(rgb[1]), int(rgb[2])), int(entry.get("material", 58)))
		(_palette.back().role as LineEdit).text = str(entry.get("role", ""))


func _choose_source(mask: bool) -> void:
	if is_instance_valid(_browse): _browse.queue_free()
	_browse = FileDialog.new()
	_browse.access = FileDialog.ACCESS_FILESYSTEM
	_browse.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_browse.filters = PackedStringArray(["*.png ; PNG image"] if mask else ["*.png ; PNG image", "*.json ; Native material module"])
	_browse.title = "Choose explicit alpha mask" if mask else "Choose local artwork or native geometry"
	_browse.file_selected.connect(func(path: String) -> void:
		if mask:
			_mask.text = path
			var result := _dict_call("authoring_inspect_source", [path])
			_mask_preview.set_image(result.get("source_image"))
			if not result.get("ok", false): _source_info.text = str(result.get("error", "Mask inspection refused."))
		else:
			_source.text = path
			_inspect_source()
		_invalidate_preview())
	add_child(_browse)
	_browse.popup_centered_clamped(Vector2i(900, 640), 0.9)


func _inspect_source() -> void:
	var result := _dict_call("authoring_inspect_source", [_source.text.strip_edges()])
	if not result.get("ok", false):
		_source_info.text = str(result.get("error", "Source inspection refused."))
		_source_preview.set_image(null)
		_invalidate_preview()
		return
	var extent: Array = result.get("extent", [])
	_syncing = true
	if extent.size() == 2:
		_crop[0].value = 0
		_crop[1].value = 0
		_crop[2].value = int(extent[0])
		_crop[3].value = int(extent[1])
	_source_preview.set_image(result.get("source_image"))
	_source_info.text = "%s · %s cells/pixels · SHA-256 %s\n%s" % [str(result.get("kind", "source")), str(extent), str(result.get("source_sha256", "unavailable")), str(result.get("summary", ""))]
	_native_source = str(result.get("kind", "")) == "native_module"
	if _native_source:
		_scale.value = 1
		_mask.text = ""
		_mask_preview.set_image(null)
		_source_info.text += "\nNATIVE-ID MODE · full exact grid, native IDs and native mask are preserved. Raster mapping controls are inactive. Overlay preserves no-write cells; Replace explicitly clears them."
	_refresh_native_controls()
	_syncing = false
	_invalidate_preview()


func _import_options() -> Dictionary:
	var palette: Array = []
	for record: Dictionary in _palette:
		var colour: Color = (record.colour as ColorPickerButton).color
		var picker: OptionButton = record.material
		if picker.selected < 0: continue
		palette.append({"rgb":[colour.r8, colour.g8, colour.b8], "material":picker.get_selected_id(), "role":(record.role as LineEdit).text})
	var options := {"plane":_selected_plane(_import_plane), "crop":_integers(_crop), "origin":_integers(_origin), "scale":int(_scale.value),
		"transform":TRANSFORMS[_transform.selected], "alpha_mode":"overlay" if _alpha_mode.selected == 0 else "replace", "alpha_threshold":int(_threshold.value),
		"palette":palette, "color_distance":int(_distance.value), "unmapped":"refuse" if _unmapped.selected == 0 else "skip"}
	if not _mask.text.strip_edges().is_empty(): options["mask_path"] = _mask.text.strip_edges()
	return options


func _preview_import() -> void:
	_request_preview("preview_import", [_source.text.strip_edges(), _import_options()])


func _request_preview(method: String, arguments: Array) -> void:
	var previous := _dict_call("authoring_state")
	_previous_preview_identity = str(previous.get("preview_serial", previous.get("token", "")))
	_preview_ui_revision = -1
	_preview_request_revision = _configuration_revision
	_invoke(method, arguments)
	refresh({}, "")


func _load_fixture() -> void:
	if _fixture.selected < 0 or _fixture.selected >= _fixtures.size(): return
	var item: Dictionary = _fixtures[_fixture.selected]
	_source.text = str(item.get("path", ""))
	_mask.text = ""
	_inspect_source()
	var options: Dictionary = item.get("options", {})
	_syncing = true
	if options.has("palette"): _replace_palette(options.palette)
	if options.has("crop"): _set_numbers(_crop, options.crop)
	if options.has("origin"): _set_numbers(_origin, options.origin)
	if options.has("mask_path"): _mask.text = str(options.mask_path)
	_scale.value = int(options.get("scale", 1))
	var transform_index := TRANSFORMS.find(str(options.get("transform", "identity")))
	if transform_index >= 0: _transform.select(transform_index)
	_select_plane(_import_plane,str(options.get("plane", "scripted")))
	_alpha_mode.select(0 if str(options.get("alpha_mode", "overlay")) == "overlay" else 1)
	_threshold.value = int(options.get("alpha_threshold", 128))
	_distance.value = int(options.get("color_distance", 0))
	_unmapped.select(0 if str(options.get("unmapped", "refuse")) == "refuse" else 1)
	_mask_preview.set_image(null)
	if not _mask.text.is_empty():
		var mask_result := _dict_call("authoring_inspect_source", [_mask.text])
		if mask_result.get("ok", false): _mask_preview.set_image(mask_result.get("source_image"))
	_syncing = false
	_refresh_native_controls()
	_invalidate_preview()


func _refresh_native_controls() -> void:
	for spin: SpinBox in _crop + [_scale, _threshold, _distance]: spin.editable = not _native_source
	_mask.editable = not _native_source
	_unmapped.disabled = _native_source
	for button: Button in _raster_buttons: button.disabled = _native_source
	for entry: Dictionary in _palette:
		(entry.colour as ColorPickerButton).disabled = _native_source
		(entry.material as OptionButton).disabled = _native_source
		(entry.role as LineEdit).editable = not _native_source
		(entry.remove as Button).disabled = _native_source


func _build_compose(rows: VBoxContainer) -> void:
	_note(rows, "REUSABLE NATIVE PARTS AND LAYERED COMPOSITIONS")
	_note(rows, "Native parts preserve material IDs and exact grid transforms. Composition stages declare their own plane, bounds, dependencies and revision fences. A reviewed preview is required before placement.")
	_plane_picker(rows, _module_plane, true)
	_module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_module)
	_module_origin = _numbers(rows, ["Origin X", "Origin Y"], 0, 2047, [64, 64])
	for spin: SpinBox in _module_origin:
		spin.tooltip_text = "Native parts place the transformed grid's top-left here; a part's own anchor is retained as metadata. Layered compositions use these coordinates as their common design anchor."
	_transform_picker(rows, _module_transform)
	var repeat_row := _row(rows)
	_repeat = _spin(repeat_row, "Repeat count", 1, 16, 1)
	_step = _numbers(repeat_row, ["Step X", "Step Y"], -2048, 2048, [96, 0])
	_button(rows, "Preview selected native part", func() -> void:
		if _module.selected < 0 or _module.selected >= _modules.size(): return
		_request_preview("preview_module", [str(_modules[_module.selected].get("id", "")), {"plane":_selected_plane(_module_plane), "origin":_integers(_module_origin), "transform":TRANSFORMS[_module_transform.selected], "count":int(_repeat.value), "step":_integers(_step)}])
		_show_plan())
	rows.add_child(HSeparator.new())
	_note(rows, "Layered preset · shared anchor, explicit per-plane stages")
	_composition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_composition)
	_button(rows, "Preview layered composition", func() -> void:
		if _composition.selected < 0 or _composition.selected >= _compositions.size(): return
		_request_preview("preview_composition", [str(_compositions[_composition.selected].get("id", "")), {"origin":_integers(_module_origin)}])
		_show_plan())
	_plan_rows.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_plan_rows)
	_compose_history_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_compose_history_warning.modulate = Color("e5c388")
	rows.add_child(_compose_history_warning)
	_note(rows,"Inspect a proposed stage · copied native materials before / proposed after")
	_stage_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_stage_picker)
	_stage_picker.item_selected.connect(func(_index: int) -> void: _show_stage_preview())
	var stage_images := _row(rows)
	_preview_box(stage_images,"Before · native ID observation",_stage_before)
	_preview_box(stage_images,"After · native ID proposal",_stage_after)
	_preview_box(rows, "Native ID proposal · fixed plane order, current opacity; actual Workbench rendering differs.", _compose_preview)
	_compose_preview_scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_compose_preview_scope)
	_visual_settings_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_visual_settings_summary)
	_compose_progress.show_percentage = false
	rows.add_child(_compose_progress)
	var approval := _row(rows)
	_compose_approve.text = "Approve reviewed construction"
	_compose_approve.disabled = true
	_compose_approve.pressed.connect(func() -> void:
		_commit_field()
		if _token != null and _preview_ui_revision == _configuration_revision: _invoke("approve_plan", [_token])
		refresh({}, ""))
	approval.add_child(_compose_approve)
	_compose_stop.text = "Stop · keep applied prefix"
	_compose_stop.disabled = true
	_compose_stop.pressed.connect(func() -> void: _invoke("stop_authoring"); refresh({}, ""))
	approval.add_child(_compose_stop)
	_compose_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_compose_status)
	_apply_visual_settings.text = "Apply reviewed depth and atmosphere"
	_apply_visual_settings.disabled = true
	_apply_visual_settings.tooltip_text = "Separate approval after all native stages complete. Preset atmosphere replaces the existing effect configuration. Current scene, revisions and visual settings are revalidated."
	_apply_visual_settings.pressed.connect(func() -> void:
		_commit_field()
		var state := _dict_call("authoring_state")
		if bool(state.get("can_apply_visual_settings",false)) and not _visual_review_token.is_empty() \
				and _visual_review_token == str(state.get("visual_settings_token","")) and _preview_ui_revision == _configuration_revision:
			_invoke("apply_composition_settings",[_visual_review_token])
		refresh({},""))
	rows.add_child(_apply_visual_settings)
	rows.add_child(HSeparator.new())
	_note(rows, "Harvest from the selected native plane · Play requires Pause; Empty defaults to transparent no-write")
	_module_name.placeholder_text = "Name the harvested native part"
	rows.add_child(_module_name)
	_harvest_region = _numbers(rows, ["Region X", "Region Y", "Width", "Height"], 0, 2048, [32, 32, 64, 64])
	_harvest_region[2].min_value = 1
	_harvest_region[3].min_value = 1
	_button(rows, "Harvest native part", func() -> void:
		_invoke("harvest_module", [_selected_plane(_module_plane), _integers(_harvest_region), _module_name.text.strip_edges()])
		refresh_catalogues()
		_show_plan())
	_button(rows, "Export selected part…", _export_module)
	for spin: SpinBox in _module_origin + _step + [_repeat]:
		spin.value_changed.connect(func(_v: float) -> void: _invalidate_preview())
	for option: OptionButton in [_module, _module_plane, _module_transform, _composition]:
		option.item_selected.connect(func(_index: int) -> void: _invalidate_preview())


func _show_plan() -> void:
	var state := _dict_call("authoring_state")
	var text := ""
	for stage: Dictionary in state.get("stages", []):
		text += "%s · %s · %s · %s\n" % [str(stage.get("id", "stage")), str(stage.get("plane", "")), str(stage.get("region", [])), str(stage.get("status", "proposed"))]
	_plan_rows.text = text if not text.is_empty() else str(state.get("error", state.get("message", "No proposed stages.")))
	refresh({}, "")


func _export_module() -> void:
	if _module.selected < 0 or _module.selected >= _modules.size(): return
	var selected_id: String = str(_modules[_module.selected].get("id", ""))
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.json ; Native material module"])
	dialog.current_file = selected_id.validate_filename() + ".json"
	dialog.file_selected.connect(func(path: String) -> void: _invoke("export_module", [selected_id, path]))
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(900, 640), 0.9)
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())


func _build_atmosphere(rows: VBoxContainer) -> void:
	_note(rows, "PRESENTATION-ONLY ATMOSPHERE")
	_note(rows, "These motifs are visual animation, not Steam mass, native rain, physical lighting or hazards. They do not edit materials or Undo history. Hidden/excluded planes freeze their motifs; Play remains authoritative.")
	var flags := _row(rows)
	_effects_enabled.text = "Enable atmosphere"
	_effects_paused.text = "Pause animation"
	flags.add_child(_effects_enabled)
	flags.add_child(_effects_paused)
	_effects_enabled.toggled.connect(func(value: bool) -> void: if not _syncing: _invoke("set_atmosphere_settings", [{"enabled":value}]))
	_effects_paused.toggled.connect(func(value: bool) -> void: if not _syncing: _invoke("set_atmosphere_settings", [{"paused":value}]))
	_button(flags, "Reset motion", func() -> void: _invoke("reset_atmosphere_phase"))
	_effect_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_effect_profile)
	_effect_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_effect_description)
	_effect_profile.item_selected.connect(func(_index: int) -> void: _refresh_profile_description())
	_plane_picker(rows, _effect_plane)
	_effect_region = _numbers(rows, ["Region X", "Region Y", "Width", "Height"], 0, 2048, [64, 64, 256, 128])
	_effect_region[2].min_value = 1
	_effect_region[3].min_value = 1
	_effect_seed = _spin(rows, "Deterministic seed", 0, 2147483647, 1701)
	_button(rows, "Add selected atmosphere profile", func() -> void:
		if _effect_profile.selected < 0 or _effect_profile.selected >= _effect_profiles.size(): return
		_invoke("add_atmosphere_profile", [str(_effect_profiles[_effect_profile.selected].get("id", "")), _selected_plane(_effect_plane), _integers(_effect_region), int(_effect_seed.value)])
		_refresh_atmosphere())
	rows.add_child(HSeparator.new())
	_note(rows, "Existing regional effect")
	_effect_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_effect_list)
	_effect_list.item_selected.connect(func(_index: int) -> void: _refresh_atmosphere(false))
	_effect_enabled.text = "This effect enabled"
	rows.add_child(_effect_enabled)
	var values := _row(rows)
	_effect_count = _spin(values, "Motif count (shared limit 384)", 0, 96, 24)
	_effect_speed = _spin(values, "Speed", 0.0, 64.0, 8.0, 0.5)
	_effect_strength = _spin(values, "Strength", 0.0, 1.0, 0.25, 0.05)
	_effect_count.tooltip_text = "Actual seeded visual motifs in this region. Every region shares the 384-motif budget."
	_effect_speed.tooltip_text = "Haze, steam, rain, dust and machinery: native cells per second along the direction. Beacon: pulse multiplier, 0.2 cycles per second × speed."
	_effect_strength.tooltip_text = "Multiplies the motif colour's alpha. This changes appearance without changing native materials."
	_effect_enabled.tooltip_text = "Hides this effect. If another effect continues on its plane, re-enabling rejoins that plane's current phase. Pause animation freezes all plane clocks."
	_effect_direction = _numbers(rows, ["Direction X", "Direction Y"], -1.0, 1.0, [1.0, 0.0])
	for spin: SpinBox in _effect_direction: spin.step = 0.1
	_effect_colour.custom_minimum_size = Vector2(100, 28)
	_effect_colour.color = Color("9eabb8")
	_effect_colour.edit_alpha = true
	rows.add_child(_effect_colour)
	var edit_actions := _row(rows)
	_button(edit_actions, "Apply effect settings", _apply_effect)
	_button(edit_actions, "Remove selected effect", func() -> void:
		var id := _selected_effect()
		if not id.is_empty(): _invoke("remove_atmosphere_effect", [id])
		_refresh_atmosphere())
	_effect_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_effect_status)
	_note(rows, "Profile additions and edits are validated authored settings. Animation phase is transient; Save/Reopen restores settings and seed. No catch-up burst is requested after pause or hidden time.")


func _apply_effect() -> void:
	var id := _selected_effect()
	if id.is_empty(): return
	var colour: Color = _effect_colour.color
	_invoke("update_atmosphere_effect", [id, {"enabled":_effect_enabled.button_pressed,
		"region":_integers(_effect_region), "seed":int(_effect_seed.value), "count":int(_effect_count.value),
		"speed":float(_effect_speed.value), "strength":float(_effect_strength.value),
		"direction":[float(_effect_direction[0].value), float(_effect_direction[1].value)],
		"colour":[colour.r, colour.g, colour.b, colour.a]}])
	_refresh_atmosphere()


func _selected_effect() -> String:
	return _effect_ids[_effect_list.selected] if _effect_list.selected >= 0 and _effect_list.selected < _effect_ids.size() else ""


func _refresh_atmosphere(rebuild: bool = true) -> void:
	var configuration := _dict_call("atmosphere_state")
	if configuration.is_empty(): return
	var configuration_key := JSON.stringify(configuration)
	if rebuild and configuration_key == _last_atmosphere_key: return
	_last_atmosphere_key = configuration_key
	_syncing = true
	_effects_enabled.set_pressed_no_signal(bool(configuration.get("enabled", false)))
	_effects_paused.set_pressed_no_signal(bool(configuration.get("paused", true)))
	var selected := _selected_effect()
	if rebuild:
		_effect_list.clear()
		_effect_ids.clear()
		for effect: Dictionary in configuration.get("effects", []):
			_effect_ids.append(str(effect.get("id", "")))
			_effect_list.add_item("%s · %s" % [str(effect.get("id", "effect")), str(effect.get("plane", ""))])
		var old_index := _effect_ids.find(selected)
		if old_index >= 0: _effect_list.select(old_index)
	selected = _selected_effect()
	for effect: Dictionary in configuration.get("effects", []):
		if str(effect.get("id", "")) != selected: continue
		_effect_enabled.set_pressed_no_signal(bool(effect.get("enabled", true)))
		_effect_count.value = int(effect.get("count", 24))
		_effect_speed.value = float(effect.get("speed", 8.0))
		_effect_strength.value = float(effect.get("strength", 0.25))
		_effect_seed.value = int(effect.get("seed", 1701))
		_set_numbers(_effect_region, effect.get("region", []))
		_set_numbers(_effect_direction, effect.get("direction", []))
		_select_plane(_effect_plane,str(effect.get("plane", "effects")))
		var colour: Array = effect.get("colour", [0.6, 0.7, 0.8, 1.0])
		if colour.size() == 4: _effect_colour.color = Color(float(colour[0]), float(colour[1]), float(colour[2]), float(colour[3]))
		var beacon := str(effect.get("kind","")) == "beacon"
		for spin: SpinBox in _effect_direction:
			spin.editable = not beacon
			spin.tooltip_text = "Direction is not used by beacon pulses." if beacon else "Direction of visual motion in native cell coordinates."
		_effect_speed.tooltip_text = "Beacon pulse multiplier: 0.2 cycles per second × speed. Direction is not used." if beacon else "Native cells per second along the direction; presentation-only visual motion."
	_effect_status.text = "%d regional effects · %s · %s" % [_effect_ids.size(), "enabled" if _effects_enabled.button_pressed else "disabled", "paused" if _effects_paused.button_pressed else "running when visible"]
	_syncing = false


func refresh_catalogues() -> void:
	_fixtures = _array_call("import_fixture_catalogue")
	_fill_catalogue(_fixture, _fixtures, "No bundled import examples")
	_modules = _array_call("module_catalogue")
	_fill_catalogue(_module, _modules, "No native parts in this library")
	_compositions = _array_call("composition_catalogue")
	_fill_catalogue(_composition, _compositions, "No layered composition presets")
	_effect_profiles = _array_call("atmosphere_profiles")
	_fill_catalogue(_effect_profile, _effect_profiles, "No atmosphere profiles")
	_refresh_profile_description()


func _refresh_profile_description() -> void:
	_effect_description.text = str(_effect_profiles[_effect_profile.selected].get("description","")) \
		if _effect_profile.selected >= 0 and _effect_profile.selected < _effect_profiles.size() else ""


func _show_stage_preview() -> void:
	if _stage_picker.selected < 0 or _stage_picker.selected >= _stage_previews.size():
		_stage_before.set_image(null)
		_stage_after.set_image(null)
		return
	var stage: Dictionary = _stage_previews[_stage_picker.selected]
	_stage_before.set_image(stage.get("before_image"))
	_stage_after.set_image(stage.get("output_image"))


func _refresh_stage_previews(state: Dictionary) -> void:
	var proposed: Array = state.get("preview_regions",[])
	var identities: Array = []
	for stage: Dictionary in proposed:
		var before: Variant = stage.get("before_image")
		var after: Variant = stage.get("output_image")
		identities.append([stage.get("id"),stage.get("plane"),stage.get("region"),
			str(before.get_instance_id()) if before is Image else "",str(after.get_instance_id()) if after is Image else ""])
	var key := str(state.get("preview_serial",""))+":"+JSON.stringify(identities)
	if key != _stage_preview_key:
		_stage_preview_key = key
		var selected := _stage_picker.selected
		_stage_previews = proposed
		_stage_picker.clear()
		for stage: Dictionary in _stage_previews:
			_stage_picker.add_item("%s · %s · %s" % [str(stage.get("id","stage")),str(stage.get("plane","")),str(stage.get("region",[]))])
		_stage_picker.disabled = _stage_previews.is_empty()
		if not _stage_previews.is_empty(): _stage_picker.select(clampi(selected,0,_stage_previews.size()-1))
		_show_stage_preview()
	_compose_preview.set_image(state.get("composite_image",state.get("output_image")))
	_compose_preview_scope.text = str(state.get("composite_scope",""))
	if state.has("composite_region"):
		_compose_preview_scope.text += "\nNative proposal region: " + str(state.composite_region)


func _fill_catalogue(picker: OptionButton, entries: Array, empty_text: String) -> void:
	var old := picker.selected
	picker.clear()
	for entry: Dictionary in entries: picker.add_item(str(entry.get("label", entry.get("name", entry.get("id", "Untitled")))))
	if entries.is_empty(): picker.add_item(empty_text)
	picker.disabled = entries.is_empty()
	if not entries.is_empty(): picker.select(clampi(old, 0, entries.size() - 1))


func refresh(_document: Dictionary, status: String) -> void:
	var state := _dict_call("authoring_state")
	if not state.is_empty():
		var harvested_key := JSON.stringify(state.get("harvested_modules", []))
		if harvested_key != _last_harvested_key:
			_last_harvested_key = harvested_key
			refresh_catalogues()
		_token = state.get("token")
		var preview_identity := str(state.get("preview_serial", state.get("token", "")))
		if bool(state.get("can_approve", false)) and _token != null \
				and _preview_request_revision == _configuration_revision \
				and not preview_identity.is_empty() and preview_identity != _previous_preview_identity:
			_preview_ui_revision = _configuration_revision
			_visual_review_token = str(state.get("visual_settings_token",""))
		_approve.disabled = not bool(state.get("can_approve", false)) or _preview_ui_revision != _configuration_revision
		_compose_approve.disabled = _approve.disabled
		_stop.disabled = not bool(state.get("cancellable", false))
		_compose_stop.disabled = _stop.disabled
		_progress.max_value = maxi(1, int(state.get("total", 1)))
		_progress.value = int(state.get("processed", 0))
		_compose_progress.max_value = _progress.max_value
		_compose_progress.value = _progress.value
		var message := str(state.get("message","")).strip_edges()
		if message.is_empty(): message = str(state.get("status",""))
		var error := str(state.get("error",""))
		if not error.is_empty() and error != message and error != str(state.get("status","")): message += "\n"+error
		_authoring_status.text = message
		_compose_status.text = _authoring_status.text
		var warnings := ""
		for warning: Variant in state.get("history_warnings",[]): warnings += str(warning)+"\n"
		_history_warning.text = warnings.strip_edges()
		_compose_history_warning.text = _history_warning.text
		_visual_settings_summary.text = str(state.get("visual_settings_summary",""))
		if state.has("visual_settings_proposal"):
			_visual_settings_summary.text += "\nDepth and atmosphere need separate approval after native construction. The preset replaces the existing atmosphere configuration."
		_apply_visual_settings.disabled = not bool(state.get("can_apply_visual_settings",false)) or _visual_review_token.is_empty() \
			or _visual_review_token != str(state.get("visual_settings_token","")) or _preview_ui_revision != _configuration_revision
		_apply_visual_settings.visible = state.has("visual_settings_proposal")
		var key := str(state.get("preview_serial", state.get("token", ""))) + ":" + str(state.get("status", ""))
		if key != _last_state_key:
			_last_state_key = key
			if state.has("source_image"): _source_preview.set_image(state.source_image)
			if state.has("mask_image"): _mask_preview.set_image(state.mask_image)
			if state.has("output_image"):
				_output_preview.set_image(state.output_image)
		_refresh_stage_previews(state)
		var stage_text := ""
		for stage: Dictionary in state.get("stages", []):
			stage_text += "%s · %s · %s · %s · applied %s / changed %s\n" % [str(stage.get("id", "stage")), str(stage.get("plane", "")), str(stage.get("region", [])), str(stage.get("status", "proposed")), str(stage.get("applied", 0)), str(stage.get("changed", stage.get("changed_cells", 0)))]
		if not stage_text.is_empty(): _plan_rows.text = stage_text
		# Ready import locations come from the actual reviewed native stage.
		# The conversion summary does not carry a top-level region after admission.
		var preview_plane: String = str(state.get("plane", "—"))
		var preview_region: String = str(state.get("region", "—"))
		var preview_stages: Array = state.get("stages", [])
		if preview_stages.size() == 1:
			var single_preview_stage: Dictionary = preview_stages[0]
			preview_plane = str(single_preview_stage.get("plane", preview_plane))
			preview_region = str(single_preview_stage.get("region", preview_region))
		elif preview_stages.size() > 1:
			preview_plane = "per stage"
			preview_region = "%d explicit stages · inspect Compose" % preview_stages.size()
		_preview_summary.text = "Target: %s · region %s\nChanged cells: %s · mapped: %s · no-write: %s · explicit Empty: %s · unmapped: %s\nSource: %s\nProposed geometry: %s" % [
			preview_plane, preview_region, str(state.get("changed_cells", "not yet read back")),
			str(state.get("mapped", "—")), str(state.get("no_write", "—")), str(state.get("explicit_empty", "—")), str(state.get("unmapped", "—")),
			str(state.get("source_sha256", "—")), str(state.get("geometry_sha256", "—"))]
		set_process(bool(state.get("busy", false)))
	elif not status.is_empty(): _authoring_status.text = status
	_refresh_atmosphere()


func _process(_delta: float) -> void:
	if is_instance_valid(_tabs) and _tabs.is_visible_in_tree(): refresh({}, "")


func _invalidate_preview() -> void:
	if _syncing: return
	_configuration_revision += 1
	_approve.disabled = true
	_compose_approve.disabled = true
	_apply_visual_settings.disabled = true
	_visual_review_token = ""
	_token = null
	_preview_summary.text = "Settings changed. Preview again before approval."


func _integers(values: Array[SpinBox]) -> Array:
	var result: Array = []
	for spin: SpinBox in values: result.append(int(spin.value))
	return result


func _set_numbers(spins: Array[SpinBox], values: Array) -> void:
	if spins.size() != values.size(): return
	for i: int in spins.size(): spins[i].value = float(values[i])


func _invoke(method: String, args: Array = []) -> Variant:
	if controller == null or not controller.has_method(method):
		if is_instance_valid(_authoring_status): _authoring_status.text = "This authoring action is unavailable: " + method
		return null
	return controller.callv(method, args)


func _dict_call(method: String, args: Array = []) -> Dictionary:
	if controller == null or not controller.has_method(method): return {}
	var result: Variant = controller.callv(method, args)
	return result if result is Dictionary else {}


func _array_call(method: String, args: Array = []) -> Array:
	if controller == null or not controller.has_method(method): return []
	var result: Variant = controller.callv(method, args)
	return result if result is Array else []
