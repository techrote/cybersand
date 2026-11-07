extends Control
## CyberSand World Art Preview — independent desktop art-production window.
## Input packs are read-only provisional proposals; rendering is presentation-only.
const Adapter = preload("res://tools/world_design_pack_adapter.gd")
const RenderRig = preload("res://tools/world_art_render_rig.gd")
const GridOverlay = preload("res://tools/world_art_grid.gd")
const COLLECTION_ORDER = [
	"lumen-fault", "chalkbone-coast", "carved-ice-choir", "ashroot-nursery",
	"emberglass-fumaroles", "silt-clockworks", "signal-orchard", "dust-meridian",
	"cathedral-of-capacitors", "mirror-marsh", "drowned-observatory",
	"ironroot-necropolis", "tectonic-archive", "coral-telegraph", "fallow-carnival",
]
const EXPORT_TILE_CELLS: int = 512
const EXPORT_HALO_CELLS: int = 32
const MAX_EXPORT_PIXELS: int = 50000000

var art_root := ""
var export_root := ""
var design_revision := "unverified external checkout"
var pack_path := ""
var pack_hash := ""
var _pack: Dictionary = {}
var _info: Dictionary = {}
var _result: Dictionary = {}
var _native_size := Vector2i.ONE
var _rg8 := PackedByteArray()
var _collections: Array[String] = []
var _feature_ids: Array[String] = []
var _origin := Vector2.ZERO
var _zoom: float = 1.0
var _presentation_time: float = 1.37
var _glow: bool = true
var _quality: bool = true
var _background_enabled: bool = true
var _playing: bool = false
var _dragging := false
var _busy := false
var _loaded := false
var _baseline: Image
var _baseline_hash := ""
var _baseline_origin := Vector2.ZERO
var _baseline_zoom := 1.0
var _baseline_time := 1.37
var _baseline_glow := true
var _baseline_quality := true
var _baseline_dimensions := Vector2i.ZERO
var last_export_dir := ""
var last_error := ""

var collection_list: ItemList
var feature_picker: OptionButton
var variant_picker: OptionButton
var root_entry: LineEdit
var revision_label: Label
var path_label: Label
var status_label: Label
var pointer_label: Label
var size_label: Label
var compare_button: Button
var export_scale_picker: OptionButton
var time_slider: HSlider
var glow_toggle: CheckButton
var quality_toggle: CheckButton
var background_toggle: CheckButton
var grid_toggle: CheckButton
var play_toggle: CheckButton
var viewport_container: SubViewportContainer
var canvas_frame: Control
var baseline_overlay: TextureRect
var grid_overlay: Control
var rig
var directory_dialog: FileDialog

func _ready() -> void:
	get_window().title = "CyberSand World Art Preview"
	art_root = ProjectSettings.globalize_path("res://../docs/world-design")
	export_root = ProjectSettings.globalize_path("user://world-art-preview/captures")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--art-root="):
			art_root = arg.trim_prefix("--art-root=")
		elif arg.begins_with("--pack="):
			pack_path = arg.trim_prefix("--pack=")
			art_root = pack_path.get_base_dir().get_base_dir()
		elif arg.begins_with("--export-root="):
			export_root = arg.trim_prefix("--export-root=")
		elif arg.begins_with("--design-revision="):
			design_revision = arg.trim_prefix("--design-revision=")
	_build_ui()
	_setup_initial_renderer()
	root_entry.text = art_root
	discover_collections()
	if not pack_path.is_empty():
		if open_pack(pack_path):
			_select_list_for_path(pack_path)
	elif not _collections.is_empty():
		choose_collection(0)
	else:
		_status("Choose a world-design root directory containing collection/pack.json", true)

func _build_ui() -> void:
	var surface := Color(0.044, 0.057, 0.076)
	var panel := StyleBoxFlat.new()
	panel.bg_color = surface
	panel.set_content_margin_all(12)
	var frame := HBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", panel.duplicate())
	left.custom_minimum_size.x = 236
	frame.add_child(left)
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 9)
	left.add_child(left_col)
	_label(left_col, "WORLD ART / COLLECTIONS", 15)
	_label(left_col, "Read-only proposals from PR #454", 11)
	root_entry = LineEdit.new()
	root_entry.placeholder_text = "World-design root directory"
	root_entry.tooltip_text = "Folder containing lumen-fault/pack.json and the other art collections."
	root_entry.text_submitted.connect(func(_v: String) -> void: art_root = root_entry.text; discover_collections())
	left_col.add_child(root_entry)
	var browse := _button(left_col, "Choose directory…", func() -> void: directory_dialog.popup_centered_ratio(0.72))
	var scan := _button(left_col, "Scan collections", func() -> void: art_root = root_entry.text; discover_collections())
	collection_list = ItemList.new()
	collection_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_list.item_selected.connect(func(index: int) -> void: choose_collection(index))
	left_col.add_child(collection_list)
	var nav := HBoxContainer.new()
	left_col.add_child(nav)
	_button(nav, "← Previous", func() -> void: choose_collection(maxi(0, collection_list.get_selected_items()[0] - 1)) if not collection_list.get_selected_items().is_empty() else choose_collection(0))
	_button(nav, "Next →", func() -> void: choose_collection(mini(_collections.size() - 1, collection_list.get_selected_items()[0] + 1)) if not collection_list.get_selected_items().is_empty() else choose_collection(0))
	_label(left_col, "SCENE / FEATURE", 13)
	feature_picker = OptionButton.new()
	feature_picker.add_item("Combined composition")
	feature_picker.item_selected.connect(func(_index: int) -> void: _refresh_variants(); _select_render(false))
	left_col.add_child(feature_picker)
	_label(left_col, "AUTHORED VARIANT", 11)
	variant_picker = OptionButton.new()
	variant_picker.add_item("Base")
	variant_picker.item_selected.connect(func(_index: int) -> void: _select_render(false))
	left_col.add_child(variant_picker)
	revision_label = _label(left_col, "Revision: " + design_revision, 11)
	revision_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_label = _label(left_col, "No pack loaded", 10)
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_label.tooltip_text = "Loaded source path and SHA-256. Packs are never modified."

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	frame.add_child(middle)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	middle.add_child(bar)
	_label(bar, "CYBERSAND · WORLD ART PREVIEW", 14)
	_button(bar, "Reload [R]", func() -> void: reload_pack())
	_button(bar, "Fit [F]", func() -> void: fit_view())
	_button(bar, "1:1 [1]", func() -> void: actual_pixels())
	_button(bar, "Reset", func() -> void: reset_view())
	_button(bar, "Pin [P]", func() -> void: pin_current())
	compare_button = _button(bar, "Show before [B]", func() -> void: toggle_comparison())
	compare_button.disabled = true
	canvas_frame = Control.new()
	canvas_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.clip_contents = true
	middle.add_child(canvas_frame)
	viewport_container = SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = false
	viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport_container.gui_input.connect(_on_canvas_input)
	canvas_frame.add_child(viewport_container)
	grid_overlay = Control.new()
	grid_overlay.set_script(GridOverlay)
	grid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_overlay.visible = false
	canvas_frame.add_child(grid_overlay)
	baseline_overlay = TextureRect.new()
	baseline_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	baseline_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	baseline_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	baseline_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	baseline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	baseline_overlay.visible = false
	canvas_frame.add_child(baseline_overlay)
	canvas_frame.resized.connect(_on_canvas_resized)
	var status_bar := HBoxContainer.new()
	middle.add_child(status_bar)
	status_label = _label(status_bar, "Awaiting source", 12)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_label = _label(status_bar, "", 12)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", panel.duplicate())
	right.custom_minimum_size.x = 256
	frame.add_child(right)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 9)
	right.add_child(controls)
	_label(controls, "PRESENTATION", 15)
	glow_toggle = _check(controls, "Emission + glow", true, func(v: bool) -> void: _glow = v; _update_presentation())
	quality_toggle = _check(controls, "Structured material detail", true, func(v: bool) -> void: _quality = v; _update_presentation())
	background_toggle = _check(controls, "Background / decor", true, func(v: bool) -> void: _background_enabled = v; _update_presentation())
	grid_toggle = _check(controls, "Native-cell grid", false, func(v: bool) -> void: grid_overlay.visible = v)
	_label(controls, "PRESENTATION TIME", 11)
	time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = 60.0
	time_slider.step = 0.01
	time_slider.value = _presentation_time
	time_slider.value_changed.connect(func(value: float) -> void: _presentation_time = value; _update_presentation())
	controls.add_child(time_slider)
	play_toggle = _check(controls, "Play shader animation [Space]", false, func(v: bool) -> void: _playing = v)
	_label(controls, "EXPORT (REAL FRAMEBUFFER)", 13)
	_label(controls, "Full-map export uses 32-cell halo tiles.", 11)
	export_scale_picker = OptionButton.new()
	export_scale_picker.add_item("1× native resolution", 1)
	export_scale_picker.add_item("2× native resolution", 2)
	export_scale_picker.select(1)
	controls.add_child(export_scale_picker)
	_button(controls, "Save visible viewport", func() -> void: export_art("viewport"))
	_button(controls, "Save full composition", func() -> void: export_art("combined"))
	_button(controls, "Save selected feature", func() -> void: export_art("feature"))
	_button(controls, "Save detail crop", func() -> void: export_art("detail"))
	_label(controls, "INSPECT NATIVE MATERIAL", 13)
	pointer_label = _label(controls, "Point at map to inspect a cell", 12)
	pointer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(controls, "NOTICE", 13)
	var notice := _label(controls, "SYNTHETIC material conditions.\nNo simulation, pressure, particles or physics state.", 11)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var help := _label(controls, "Wheel: cursor zoom\nMiddle / right drag: pan\nF: fit · 1: native pixels\nR: reload · P: pin · B: compare\nCtrl+S: save current view", 11)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	directory_dialog = FileDialog.new()
	directory_dialog.access = FileDialog.ACCESS_FILESYSTEM
	directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	directory_dialog.dir_selected.connect(func(path: String) -> void: art_root = path; root_entry.text = path; discover_collections())
	add_child(directory_dialog)

func _label(parent: Node, message: String, font_size: int) -> Label:
	var widget := Label.new()
	widget.text = message
	widget.add_theme_font_size_override("font_size", font_size)
	parent.add_child(widget)
	return widget

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var widget := Button.new()
	widget.text = caption
	widget.pressed.connect(action)
	parent.add_child(widget)
	return widget

func _check(parent: Node, caption: String, initial: bool, action: Callable) -> CheckButton:
	var widget := CheckButton.new()
	widget.text = caption
	widget.button_pressed = initial
	widget.toggled.connect(action)
	parent.add_child(widget)
	return widget

func _setup_initial_renderer() -> void:
	rig = RenderRig.new()
	viewport_container.add_child(rig)
	var blank: Image = Image.create_empty(1, 1, false, Image.FORMAT_RG8)
	blank.fill(Color(0, 0, 0, 1))
	rig.setup(blank, Vector2i(512, 512))
	_on_canvas_resized()
	_update_presentation()

func _status(message: String, failed: bool = false) -> void:
	last_error = message if failed else ""
	status_label.text = ("ERROR: " if failed else "") + message
	status_label.add_theme_color_override("font_color", Color(1.0, 0.44, 0.44) if failed else Color(0.65, 0.88, 0.83))
	if failed:
		push_warning(message)

func discover_collections() -> void:
	art_root = art_root.simplify_path()
	root_entry.text = art_root
	_collections.clear()
	collection_list.clear()
	var source := DirAccess.open(art_root)
	if source == null:
		_status("Directory not available: " + art_root + " — choose the exported #454 docs/world-design folder", true)
		return
	var directories: PackedStringArray = source.get_directories()
	directories.sort()
	for dir_name: String in COLLECTION_ORDER:
		if directories.has(dir_name) and FileAccess.file_exists(art_root.path_join(dir_name).path_join("pack.json")):
			_collections.append(art_root.path_join(dir_name).path_join("pack.json"))
			collection_list.add_item("%02d  %s" % [_collections.size(), dir_name.replace("-", " ").capitalize()])
	for dir_name: String in directories:
		if dir_name in COLLECTION_ORDER:
			continue
		if FileAccess.file_exists(art_root.path_join(dir_name).path_join("pack.json")):
			_collections.append(art_root.path_join(dir_name).path_join("pack.json"))
			collection_list.add_item("%02d  %s" % [_collections.size(), dir_name.replace("-", " ").capitalize()])
	if _collections.is_empty():
		_status("No collection/pack.json found under " + art_root, true)
	else:
		_status("Found %d world-art collections; select one" % _collections.size())

func _select_list_for_path(path: String) -> void:
	for i: int in range(_collections.size()):
		if _collections[i] == path:
			collection_list.select(i)
			return

func choose_collection(index: int) -> void:
	if index < 0 or index >= _collections.size() or _busy:
		return
	if open_pack(_collections[index]):
		collection_list.select(index)

func _read_pack(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Missing pack: " + path}
	var contents: String = FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(contents) != OK:
		return {"ok": false, "error": "JSON line %d: %s" % [
			parser.get_error_line(), parser.get_error_message()]}
	var inspection: Dictionary = Adapter.inspect(parser.data)
	if not inspection.ok:
		return inspection
	return {"ok": true, "pack": parser.data, "info": inspection,
		"sha256": FileAccess.get_sha256(path)}

func _chosen_feature() -> String:
	if feature_picker.selected <= 0 or feature_picker.selected - 1 >= _feature_ids.size():
		return ""
	return _feature_ids[feature_picker.selected - 1]

func _chosen_variant() -> String:
	if variant_picker.selected <= 0:
		return ""
	return variant_picker.get_item_text(variant_picker.selected)

func open_pack(path: String, preserve_view: bool = false) -> bool:
	_status("Loading " + path.get_file() + " …")
	var loaded: Dictionary = _read_pack(path)
	if not loaded.ok:
		_status("Load failed; last good render retained: " + loaded.error, true)
		return false
	var old_feature: String = _chosen_feature() if preserve_view else ""
	var old_variant: String = _chosen_variant() if preserve_view else ""
	var input: Dictionary = Adapter.build_combined(loaded.pack)
	if not old_feature.is_empty() and loaded.info.features.has(old_feature):
		var candidate: Dictionary = Adapter.build_feature(loaded.pack, old_feature, old_variant)
		if candidate.ok:
			input = candidate
	if not input.ok:
		_status("Rendering input failed; last good render retained: " + input.error, true)
		return false
	var image: Image = _image_from_input(input)
	if image == null or image.is_empty():
		_status("Cannot construct RG8 source; last good render retained", true)
		return false
	_pack = loaded.pack
	_info = loaded.info
	_result = input
	_rg8 = input.data
	_native_size = input["size"]
	pack_path = path
	pack_hash = loaded.sha256
	rig.replace_input(image)
	_loaded = true
	_feature_ids.clear()
	feature_picker.clear()
	feature_picker.add_item("Combined composition")
	var index := 0
	for feature_id: String in _info.features:
		_feature_ids.append(feature_id)
		feature_picker.add_item(feature_id.replace("-", " ").capitalize())
		if feature_id == old_feature and input.geometry.family == "feature":
			index = _feature_ids.size()
	feature_picker.select(index)
	_refresh_variants(old_variant if index > 0 else "")
	path_label.text = "SOURCE: %s\nSHA256: %s" % [pack_path, pack_hash.substr(0, 20)]
	revision_label.text = "Art revision: " + design_revision
	if not preserve_view or _zoom <= 0.0:
		fit_view()
	else:
		_update_camera()
	_status("Loaded %s | %s | %s" % [path.get_base_dir().get_file(), str(_native_size), pack_hash.substr(0, 12)])
	return true

func _refresh_variants(preferred: String = "") -> void:
	variant_picker.clear()
	variant_picker.add_item("Base")
	var feature: String = _chosen_feature()
	var selected_index: int = 0
	if not feature.is_empty() and _info.features.has(feature):
		for variant: Dictionary in _info.features[feature].get("variants", []):
			variant_picker.add_item(variant.id)
			if variant.id == preferred:
				selected_index = variant_picker.item_count - 1
	variant_picker.select(selected_index)

func _select_render(preserve_view: bool) -> void:
	if not _loaded or _busy:
		return
	var feature: String = _chosen_feature()
	var input: Dictionary = (Adapter.build_combined(_pack) if feature.is_empty()
		else Adapter.build_feature(_pack, feature, _chosen_variant()))
	if not input.ok:
		_status(input.error, true)
		return
	var image: Image = _image_from_input(input)
	if image == null or image.is_empty():
		_status("RG8 image construction failed", true)
		return
	_result = input
	_rg8 = input.data
	_native_size = input["size"]
	rig.replace_input(image)
	if preserve_view:
		_update_camera()
	else:
		fit_view()
	_status("Viewing %s / %s" % [pack_path.get_base_dir().get_file(),
		"combined" if feature.is_empty() else feature + " " + _chosen_variant()])

func _image_from_input(input: Dictionary) -> Image:
	var native_size: Vector2i = input["size"]
	var image: Image = Image.create_from_data(native_size.x, native_size.y,
		false, Image.FORMAT_RG8, input.data)
	if image == null or image.is_empty() or image.get_data() != input.data:
		return null
	return image

func reload_pack() -> bool:
	if not _loaded:
		_status("No source loaded; select a collection first", true)
		return false
	return open_pack(pack_path, true)

func _on_canvas_resized() -> void:
	if rig == null:
		return
	var old_size: Vector2i = rig.size
	var centre: Vector2 = _origin + Vector2(old_size) / maxf(_zoom, 0.00001) * 0.5
	var pixels := Vector2i(maxi(1, roundi(canvas_frame.size.x)), maxi(1, roundi(canvas_frame.size.y)))
	rig.set_resolution(pixels)
	_origin = centre - Vector2(pixels) / maxf(_zoom, 0.00001) * 0.5
	_update_camera()

func fit_view() -> void:
	if not _loaded:
		return
	var pixels: Vector2 = Vector2(rig.size)
	_zoom = clampf(minf(pixels.x / float(_native_size.x),
		pixels.y / float(_native_size.y)) * 0.96, 0.03, 32.0)
	_origin = Vector2(_native_size) * 0.5 - pixels / _zoom * 0.5
	_update_camera()

func actual_pixels() -> void:
	if not _loaded:
		return
	_zoom = 1.0
	_origin = Vector2(_native_size) * 0.5 - Vector2(rig.size) * 0.5
	_update_camera()

func reset_view() -> void:
	_presentation_time = 1.37
	time_slider.set_value_no_signal(_presentation_time)
	_playing = false
	play_toggle.set_pressed_no_signal(false)
	_glow = true
	glow_toggle.set_pressed_no_signal(true)
	_quality = true
	quality_toggle.set_pressed_no_signal(true)
	_background_enabled = true
	background_toggle.set_pressed_no_signal(true)
	_update_presentation()
	fit_view()

func _update_camera() -> void:
	if rig == null:
		return
	var view_size := Vector2(rig.size) / maxf(_zoom, 0.00001)
	rig.set_view(_origin, view_size)
	grid_overlay.set("world_origin", _origin)
	grid_overlay.set("world_zoom", _zoom)
	grid_overlay.set("native_size", _native_size)
	grid_overlay.queue_redraw()
	size_label.text = "%d × %d cells · %.2f px/cell" % [_native_size.x, _native_size.y, _zoom]

func _update_presentation() -> void:
	if rig == null:
		return
	rig.set_presentation(_presentation_time, _glow, _quality)
	rig.set_background_enabled(_background_enabled)

func _process(delta: float) -> void:
	if _playing:
		_presentation_time = fposmod(_presentation_time + delta, 60.0)
		time_slider.set_value_no_signal(_presentation_time)
		_update_presentation()

func _on_canvas_input(event: InputEvent) -> void:
	if not _loaded or _busy:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var world_under: Vector2 = _origin + mouse.position / _zoom
			var factor: float = 1.2 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2
			_zoom = clampf(_zoom * factor, 0.03, 32.0)
			_origin = world_under - mouse.position / _zoom
			_update_camera()
			viewport_container.accept_event()
		elif mouse.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = mouse.pressed
			viewport_container.accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _dragging:
			_origin -= motion.relative / _zoom
			_update_camera()
		_inspect(motion.position)
		viewport_container.accept_event()

func _inspect(pixel: Vector2) -> void:
	var world := _origin + pixel / _zoom
	var point := Vector2i(floori(world.x), floori(world.y))
	if point.x < 0 or point.y < 0 or point.x >= _native_size.x or point.y >= _native_size.y:
		pointer_label.text = "Outside map · (%d, %d)" % [point.x, point.y]
		return
	var index := (point.y * _native_size.x + point.x) * 2
	if index + 1 >= _rg8.size():
		return
	pointer_label.text = "Cell (%d, %d)\nMaterial ID %d · condition %d\n%s" % [
		point.x, point.y, _rg8[index], _rg8[index + 1],
		"Combined composition" if _chosen_feature().is_empty() else _chosen_feature()]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: InputEventKey = event
	if key.ctrl_pressed and key.keycode == KEY_S:
		export_art("viewport")
	elif key.keycode == KEY_F:
		fit_view()
	elif key.keycode == KEY_1:
		actual_pixels()
	elif key.keycode == KEY_R:
		reload_pack()
	elif key.keycode == KEY_P:
		pin_current()
	elif key.keycode == KEY_B:
		toggle_comparison()
	elif key.keycode == KEY_SPACE:
		play_toggle.button_pressed = not play_toggle.button_pressed
	else:
		return
	get_viewport().set_input_as_handled()

func pin_current() -> void:
	if not _loaded or _busy:
		return
	_pin_after_frames()

func _pin_after_frames() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_baseline = rig.get_texture().get_image()
	if _baseline == null or _baseline.is_empty():
		_status("Pin failed: no graphical framebuffer", true)
		return
	_baseline.convert(Image.FORMAT_RGB8)
	_baseline_origin = _origin
	_baseline_zoom = _zoom
	_baseline_time = _presentation_time
	_baseline_glow = _glow
	_baseline_quality = _quality
	_baseline_dimensions = rig.size
	_baseline_hash = pack_hash
	baseline_overlay.texture = ImageTexture.create_from_image(_baseline)
	baseline_overlay.visible = false
	compare_button.disabled = false
	compare_button.text = "Show before [B]"
	_status("Pinned genuine rendered frame at source " + _baseline_hash.substr(0, 12))

func toggle_comparison() -> void:
	if _baseline == null or _baseline.is_empty() or not _loaded:
		return
	if baseline_overlay.visible:
		baseline_overlay.visible = false
		compare_button.text = "Show before [B]"
		_status("Current source " + pack_hash.substr(0, 12))
		return
	_origin = _baseline_origin
	_zoom = _baseline_zoom
	_presentation_time = _baseline_time
	time_slider.set_value_no_signal(_presentation_time)
	_glow = _baseline_glow
	glow_toggle.set_pressed_no_signal(_glow)
	_quality = _baseline_quality
	quality_toggle.set_pressed_no_signal(_quality)
	_playing = false
	play_toggle.set_pressed_no_signal(false)
	_update_camera()
	_update_presentation()
	baseline_overlay.visible = true
	compare_button.text = "Show after [B]"
	_status("BEFORE (captured image %s) ⇄ current %s" % [
		_baseline_hash.substr(0, 12), pack_hash.substr(0, 12)])

func _new_export_directory(kind: String) -> String:
	var parent: String = export_root.simplify_path()
	if parent == pack_path.get_base_dir() or parent.begins_with(pack_path.get_base_dir() + "/"):
		return ""
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		return ""
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var unique: String = "%s-%s-%s" % [stamp, kind, Crypto.new().generate_random_bytes(8).hex_encode()]
	var destination: String = parent.path_join(unique)
	if DirAccess.dir_exists_absolute(destination):
		return ""
	if DirAccess.make_dir_absolute(destination) != OK:
		return ""
	return destination

func _json_file(path: String, value: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(value, "  ") + "\n")
	var success: bool = f.get_error() == OK
	f.close()
	return success

func export_art(kind: String) -> void:
	if not _loaded or _busy:
		return
	if kind == "feature" and _chosen_feature().is_empty():
		_status("Select a feature in the left panel before exporting it", true)
		return
	_busy = true
	var directory: String = _new_export_directory(kind)
	if directory.is_empty():
		_busy = false
		_status("Cannot create a new safe export directory outside the source pack", true)
		return
	last_export_dir = directory
	_json_file(directory.path_join("status.json"), {"status": "incomplete", "kind": kind})
	_status("Exporting " + kind + " …")
	var exported: Image
	var source_size: Vector2i = _native_size
	var source_rg8_hash: String = _result.get("rg8_sha256", "")
	if kind in ["viewport", "detail"]:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		exported = rig.get_texture().get_image()
		if kind == "detail" and exported != null and not exported.is_empty():
			var half: Vector2i = Vector2i(maxi(1, exported.get_width() / 2),
				maxi(1, exported.get_height() / 2))
			var first: Vector2i = (exported.get_size() - half) / 2
			exported = exported.get_region(Rect2i(first, half))
	else:
		var input: Dictionary = (Adapter.build_combined(_pack) if kind == "combined"
			else Adapter.build_feature(_pack, _chosen_feature(), _chosen_variant()))
		if input.ok:
			source_size = input["size"]
			source_rg8_hash = input.get("rg8_sha256", "")
			exported = await _render_full(input, export_scale_picker.get_selected_id())
	if exported == null or exported.is_empty():
		_busy = false
		_status("Framebuffer export failed; incomplete status retained: " + directory, true)
		return
	exported.convert(Image.FORMAT_RGB8)
	var image_path: String = directory.path_join(kind + ".png")
	if exported.save_png(image_path) != OK:
		_busy = false
		_status("PNG write failed; incomplete status retained: " + directory, true)
		return
	var metadata := {
		"kind": kind, "pack_path": pack_path, "pack_sha256": pack_hash,
		"design_revision": design_revision, "selected_feature": _chosen_feature(),
		"selected_variant": _chosen_variant(), "native_dimensions": [source_size.x, source_size.y],
		"pixels": [exported.get_width(), exported.get_height()],
		"framebuffer": "Godot SubViewportTexture.get_image",
		"input_format": "Image.FORMAT_RG8; native material IDs and synthetic conditions",
		"source_rg8_sha256": source_rg8_hash,
		"presentation": {"time": _presentation_time, "glow": _glow,
			"structured_detail": _quality, "background": _background_enabled,
			"zoom": _zoom, "camera_origin": [_origin.x, _origin.y]},
		"renderer": rig.renderer_identity(),
		"image_file": kind + ".png", "png_sha256": FileAccess.get_sha256(image_path),
		"baseline_source_sha256": _baseline_hash if _baseline != null else "",
	}
	if not _json_file(directory.path_join("metadata.json"), metadata) or not _json_file(
			directory.path_join("status.json"), {"status": "complete", "kind": kind,
				"png_sha256": metadata.png_sha256}):
		_busy = false
		_status("Export metadata failed; check partial output: " + directory, true)
		return
	_busy = false
	_status("Saved genuine %s PNG: %s" % [kind, image_path])
	print("WORLD_ART_EXPORT " + JSON.stringify({"status": "complete", "path": image_path,
		"sha256": metadata.png_sha256}))

func _render_full(input: Dictionary, output_scale: int) -> Image:
	var dims: Vector2i = input["size"]
	var scale: int = clampi(output_scale, 1, 2)
	if dims.x * dims.y * scale * scale > MAX_EXPORT_PIXELS:
		_status("Requested full export exceeds %d pixels" % MAX_EXPORT_PIXELS, true)
		return null
	var input_image: Image = _image_from_input(input)
	if input_image == null:
		return null
	var output: Image = Image.create_empty(dims.x * scale, dims.y * scale, false, Image.FORMAT_RGB8)
	var export_rig = RenderRig.new()
	get_tree().root.add_child(export_rig)
	export_rig.setup(input_image, Vector2i(2, 2))
	export_rig.set_presentation(_presentation_time, _glow, _quality)
	export_rig.set_background_enabled(_background_enabled)
	for y: int in range(0, dims.y, EXPORT_TILE_CELLS):
		for x: int in range(0, dims.x, EXPORT_TILE_CELLS):
			var inner := Rect2i(x, y, mini(EXPORT_TILE_CELLS, dims.x - x),
				mini(EXPORT_TILE_CELLS, dims.y - y))
			var start: Vector2i = inner.position - Vector2i(EXPORT_HALO_CELLS, EXPORT_HALO_CELLS)
			var world_view: Vector2i = inner.size + Vector2i(EXPORT_HALO_CELLS * 2, EXPORT_HALO_CELLS * 2)
			if world_view.x % 2 != 0:
				world_view.x += 1
			if world_view.y % 2 != 0:
				world_view.y += 1
			export_rig.set_resolution(world_view * scale)
			export_rig.set_view(Vector2(start), Vector2(world_view))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var tile: Image = export_rig.get_texture().get_image()
			if tile == null or tile.is_empty() or tile.get_size() != world_view * scale:
				export_rig.queue_free()
				return null
			tile.convert(Image.FORMAT_RGB8)
			output.blit_rect(tile, Rect2i(Vector2i(EXPORT_HALO_CELLS * scale,
				EXPORT_HALO_CELLS * scale), inner.size * scale), inner.position * scale)
	export_rig.queue_free()
	return output
