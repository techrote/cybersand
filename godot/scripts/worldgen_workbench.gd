class_name CyberWorldGenerationWorkbench
extends Control

# Opt-in native procedural preview. Its private generator has one main-thread
# owner. These copied recipes/cells never access the live sandbox's World.
const Preview = preload("res://scripts/worldgen_preview.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
const MAX_CACHE_CHUNKS: int = 32
const MAX_QUEUED_CHUNKS: int = 24
const MAX_UNDO: int = 16
const MAX_PROFILE_BYTES: int = 1024 * 1024
const CELL_BUDGET: int = 2048
const CANDIDATES: Array[String] = ["strata", "flow_network", "district_grammar"]
const CANDIDATE_LABELS: Array[String] = ["01 / Strata fields", "02 / Flow network", "03 / District grammar"]
const THEME_IDS: Array[String] = ["world", "natural", "built", "dry_cavern", "wet_cavern", "basalt", "industrial", "ruins", "garden"]
const PARAMETER_SPECS: Dictionary = {
	"surface_y": ["Surface height", -8192.0, 8192.0, 1.0, 96.0],
	"relief": ["Relief", 0.0, 1024.0, 1.0, 48.0],
	"feature_scale": ["Feature scale", 8.0, 4096.0, 1.0, 96.0],
	"cave_threshold": ["Cave threshold", 0.0, 1.0, 0.01, 0.60],
	"strata_period": ["Strata spacing", 2.0, 1024.0, 1.0, 18.0],
	"warp": ["Field warp", 0.0, 512.0, 1.0, 12.0],
	"corridor_width": ["Corridor width", 2.0, 64.0, 1.0, 7.0],
	"district_size": ["District size (global)", 64.0, 2048.0, 1.0, 256.0],
	"room_size": ["Room size", 12.0, 256.0, 1.0, 48.0],
	"wall_thickness": ["Wall thickness", 1.0, 5.0, 1.0, 3.0],
	"detail": ["Detail density", 0.0, 1.0, 0.01, 0.32],
	"fluid_level": ["Fluid level", -8192.0, 8192.0, 1.0, 224.0],
}
const MODULE_DEFAULTS: Dictionary = {
	"arcology": {"bay_width": 48, "floor_height": 32, "wall": 3, "shaft_width": 10},
	"vault": {"cell_size": 32, "wall": 2, "door_width": 8},
	"aqueduct": {"span": 64, "deck_height": 24, "wall": 3, "channel_depth": 6},
}

var generator: Variant
var active_recipe: Dictionary = {}
var active_revision: int = -1
var active_fingerprint: String = ""
var last_error: String = ""
var last_packet: Dictionary = {}
var cache: Dictionary = {}
var pending_chunks: Array[Vector2i] = []
var camera_origin := Vector2.ZERO
var view_size := Vector2(384, 256)
var preview: CyberWorldGenerationPreview
var candidate_picker: OptionButton
var seed_input: SpinBox
var chunk_picker: OptionButton
var base_theme: OptionButton
var blend_theme: OptionButton
var blend_weight: SpinBox
var exclusions: Dictionary = {}
var parameter_inputs: Dictionary = {}
var tool_picker: OptionButton
var brush_theme: OptionButton
var radius_input: SpinBox
var strength_input: SpinBox
var falloff_input: SpinBox
var priority_input: SpinBox
var brush_parameter: OptionButton
var brush_value: SpinBox
var material_picker: OptionButton
var module_picker: OptionButton
var module_parameters: TextEdit
var module_help: Label
var profile_dialog: Window
var profile_editor: TextEdit
var profile_status: Label
var status_label: Label
var identity_label: Label
var pointer_label: Label
var marks_label: Label
var origin_x: SpinBox
var origin_y: SpinBox
var _cache_order: Array[Vector2i] = []
var _blocked_chunks: Dictionary = {}
var _undo: Array[Dictionary] = []
var _active_chunk := Vector2i.ZERO
var _has_active_chunk: bool = false
var _job_completed: int = 0
var _job_compute_us: int = 0
var _authoring_serial: int = 0
var _syncing_controls: bool = false
var _dirty_controls: Dictionary = {}

static func default_recipe() -> Dictionary:
	var parameters: Dictionary = {}
	for key: String in PARAMETER_SPECS:
		parameters[key] = PARAMETER_SPECS[key][4]
	return {
		"schema": 1, "seed": 74391, "chunk_size": 128, "candidate": "strata",
		"parameters": parameters,
		"themes": {"weights": {"natural": 1.0, "built": 0.18}, "exclude": []},
		"strokes": [], "paths": [], "overrides": [], "modules": [],
	}

func _ready() -> void:
	_build_ui()
	_connect_control_tracking()
	profile_editor.text = JSON.stringify(default_recipe(), "  ", true)
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		_set_error("The current native generator is unavailable. Build the GDExtension for this source, then reopen this scene.")
		return
	generator = ClassDB.instantiate(&"CyberWorldGenerator")
	for method: StringName in [&"configure", &"begin_chunk", &"advance", &"get_configuration", &"get_catalogue"]:
		if not generator.has_method(method):
			generator = null
			_set_error("The loaded native generator has an incompatible API. Rebuild the GDExtension for this source.")
			return
	_populate_catalogue(generator.get_catalogue())
	apply_recipe(default_recipe(), false)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.047, 0.067)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title: Label = _label(heading, "CYBERSAND / WORLD GENERATION", 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "Profile JSON…", _open_profile)
	_button(heading, "Apply controls", apply_controls)
	_button(heading, "Undo", undo_authoring)
	_label(layout, "Native procedural preview · globally addressed chunks · generation only", 15, Color(0.62, 0.8, 0.85))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(370, 450)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	_build_generator_tab(_tab(tabs, "Generator"))
	_build_brush_tab(_tab(tabs, "Brushes"))
	_build_module_tab(_tab(tabs, "Modules"))
	var viewer := VBoxContainer.new()
	viewer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(viewer)
	var navigation := HBoxContainer.new()
	viewer.add_child(navigation)
	_label(navigation, "Origin", 14)
	origin_x = _spin(navigation, -1000000, 1000000, 1, 0)
	origin_y = _spin(navigation, -1000000, 1000000, 1, 0)
	_button(navigation, "Go", func() -> void: set_camera_origin(Vector2(origin_x.value, origin_y.value)))
	_button(navigation, "Home", func() -> void: set_camera_origin(Vector2.ZERO))
	_button(navigation, "−", func() -> void: zoom_view(1.25))
	_button(navigation, "+", func() -> void: zoom_view(0.8))
	var grid := CheckButton.new()
	grid.text = "Chunks"
	grid.button_pressed = true
	navigation.add_child(grid)
	var guides := CheckButton.new()
	guides.text = "Guides"
	guides.button_pressed = true
	navigation.add_child(guides)
	preview = Preview.new()
	preview.custom_minimum_size = Vector2(380, 320)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer.add_child(preview)
	preview.stroke_finished.connect(add_gesture)
	preview.pan_requested.connect(func(delta: Vector2) -> void: set_camera_origin(camera_origin + delta))
	preview.zoom_requested.connect(zoom_view)
	preview.point_inspected.connect(_inspect_point)
	grid.toggled.connect(func(enabled: bool) -> void: preview.grid_visible = enabled; preview.queue_redraw())
	guides.toggled.connect(func(enabled: bool) -> void: preview.guides_visible = enabled; preview.queue_redraw())
	pointer_label = _label(viewer, "Drag to author · right/middle drag to pan · wheel to zoom · Esc cancels a stroke", 14, Color(0.65, 0.77, 0.81))
	marks_label = _label(viewer, "", 14)
	identity_label = _label(layout, "Waiting for native generator…", 14, Color(0.65, 0.85, 0.8))
	status_label = _label(layout, "", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_profile_dialog()

func _tab(parent: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box

func _build_generator_tab(box: VBoxContainer) -> void:
	_label(box, "CANDIDATE", 14, Color(0.54, 0.85, 0.81))
	candidate_picker = _options(box, CANDIDATE_LABELS)
	var note: Label = _label(box, "Strata: layered fields. Flow: linked channels. District: rooms and streets.", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seed_input = _labelled_spin(box, "Seed", 0, 9007199254740991, 1, 74391)
	var chunk_row := HBoxContainer.new()
	box.add_child(chunk_row)
	_label(chunk_row, "Chunk cells", 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chunk_picker = _options(chunk_row, ["32", "64", "128", "256"])
	chunk_picker.select(2)
	_label(box, "THEME SETS & BLENDS", 14, Color(0.54, 0.85, 0.81))
	base_theme = _options(box, THEME_IDS)
	blend_theme = _options(box, THEME_IDS)
	base_theme.select(1)
	blend_theme.select(2)
	blend_weight = _labelled_spin(box, "Blend weight", 0, 8, 0.05, 0.18)
	var theme_note: Label = _label(box, "Groups expand to their leaf themes; exclusions remove leaves from both sets. Full combinations are editable in JSON.", 13)
	theme_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var exclude_row := HFlowContainer.new()
	box.add_child(exclude_row)
	for id: String in THEME_IDS.slice(3):
		var check := CheckBox.new()
		check.text = "− " + id
		check.add_theme_font_size_override("font_size", 13)
		exclude_row.add_child(check)
		exclusions[id] = check
	_label(box, "FINE PARAMETERS", 14, Color(0.54, 0.85, 0.81))
	for key: String in PARAMETER_SPECS:
		var spec: Array = PARAMETER_SPECS[key]
		parameter_inputs[key] = _labelled_spin(box, str(spec[0]), float(spec[1]), float(spec[2]), float(spec[3]), float(spec[4]))
	_button(box, "Apply generator controls", apply_controls)
	_button(box, "Regenerate accepted profile", func() -> void: apply_recipe(active_recipe, false))

func _build_brush_tab(box: VBoxContainer) -> void:
	_label(box, "BROAD GUIDANCE / EXACT MARKS", 14, Color(0.54, 0.85, 0.81))
	tool_picker = _options(box, ["Theme stroke", "Parameter stroke", "Carved / material route", "Hard material rectangle", "Structured module", "Pan only"])
	tool_picker.item_selected.connect(func(index: int) -> void:
		if preview != null:
			preview.cancel_gesture()
			preview.tool_mode = index
			_refresh_brush_preview())
	var note: Label = _label(box, "Drag in the preview, then release to validate and regenerate. Brush edits use the accepted profile; Apply generator controls first to keep any pending numeric edits.", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box, "Theme paint", 14)
	brush_theme = _options(box, THEME_IDS)
	brush_theme.select(7)
	radius_input = _labelled_spin(box, "Radius / route half-width", 1, 512, 1, 48)
	strength_input = _labelled_spin(box, "Strength", 0, 1, 0.05, 0.85)
	falloff_input = _labelled_spin(box, "Falloff", 0.1, 8, 0.1, 1)
	priority_input = _labelled_spin(box, "Priority", -1000, 1000, 1, 10)
	radius_input.value_changed.connect(func(_value: float) -> void: _refresh_brush_preview())
	_label(box, "Parameter paint", 14)
	var brush_keys: Array[String] = []
	for key: String in PARAMETER_SPECS:
		if key != "district_size":
			brush_keys.append(key)
	brush_parameter = _options(box, brush_keys)
	brush_parameter.select(3)
	brush_value = _labelled_spin(box, "Target value", 0, 1, 0.01, 0.85)
	brush_parameter.item_selected.connect(func(_index: int) -> void: _set_brush_parameter_range())
	_label(box, "Route / hard override material", 14)
	material_picker = OptionButton.new()
	box.add_child(material_picker)
	for id: int in range(Palette.MATERIAL_COUNT):
		if id == 10:
			continue
		material_picker.add_item("%02d / %s" % [id, _material_label(id)], id)
	var precedence: Label = _label(box, "Hard material rectangles apply last. Routes connect in world coordinates across chunk edges. District size is global only.", 13)
	precedence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(box, "Undo accepted edit", undo_authoring)
	_button(box, "Clear all marks & modules", clear_authoring)

func _build_module_tab(box: VBoxContainer) -> void:
	_label(box, "STRUCTURED FEATURES", 14, Color(0.73, 0.68, 1.0))
	module_picker = _options(box, ["arcology", "vault", "aqueduct"])
	module_picker.item_selected.connect(func(_index: int) -> void: _refresh_module_editor())
	module_help = _label(box, "", 14)
	module_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	module_parameters = TextEdit.new()
	module_parameters.custom_minimum_size = Vector2(0, 190)
	module_parameters.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(module_parameters)
	_button(box, "Draw module bounds", func() -> void:
		tool_picker.select(4)
		preview.tool_mode = 4
		preview.cancel_gesture()
		_set_status("Module placement: drag a rectangle in the preview. Parameters are read on release."))
	_button(box, "Insert example zone", insert_example_module)
	var extensibility: Label = _label(box, "Module identities and versions come from the native registry. Use Profile JSON for instance dependencies, overlapping priorities, and candidate or parameter overrides.", 14)
	extensibility.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(box, "PREVIEW BOUNDS", 14, Color(0.54, 0.85, 0.81))
	var limits: Label = _label(box, "One private native generation job. Up to 2,048 cells per frame, 24 queued chunks and 32 cached chunks. Evicted previews are regenerated deterministically. Simulation residency and modified-world persistence are separate systems.", 14)
	limits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_module_editor()

func _build_profile_dialog() -> void:
	profile_dialog = Window.new()
	profile_dialog.title = "World generation / schema 1 profile"
	profile_dialog.size = Vector2i(960, 740)
	profile_dialog.min_size = Vector2i(620, 460)
	profile_dialog.visible = false
	profile_dialog.transient = true
	profile_dialog.close_requested.connect(profile_dialog.hide)
	add_child(profile_dialog)
	var margin := MarginContainer.new()
	profile_dialog.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var note: Label = _label(box, "Complete recipe: hierarchy/blends, strokes, paths, exact overrides, modules and dependencies. Apply validates before replacing the accepted generation plan.", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_editor = TextEdit.new()
	profile_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(profile_editor)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_button(actions, "Apply JSON", apply_json)
	_button(actions, "Load JSON…", _choose_load_profile)
	_button(actions, "Save accepted…", _choose_save_profile)
	_button(actions, "Restore accepted text", func() -> void: profile_editor.text = JSON.stringify(active_recipe, "  ", true))
	_button(actions, "Close", profile_dialog.hide)
	profile_status = _label(box, "", 14)
	profile_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _populate_catalogue(catalogue: Dictionary) -> void:
	var ids: Array[String] = []
	for item: Dictionary in catalogue.get("themes", []):
		ids.append(str(item.id))
	if not ids.is_empty():
		for picker: OptionButton in [base_theme, blend_theme, brush_theme]:
			var prior: String = picker.get_item_text(picker.selected)
			picker.clear()
			for id: String in ids:
				picker.add_item(id)
			_select_text(picker, prior)
	var modules: Array = catalogue.get("modules", [])
	if not modules.is_empty():
		var prior_module: String = module_picker.get_item_text(module_picker.selected)
		var prior_parameters: String = module_parameters.text
		module_picker.clear()
		for item: Dictionary in modules:
			module_picker.add_item(str(item.id))
		_select_text(module_picker, prior_module)
		if module_picker.get_item_text(module_picker.selected) == prior_module:
			module_parameters.text = prior_parameters
		else:
			_refresh_module_editor()

func apply_recipe(recipe: Dictionary, record_undo: bool = true) -> bool:
	if generator == null:
		_set_error("Native generation is unavailable; the profile cannot be applied.")
		return false
	var checked: Dictionary = generator.configure(recipe.duplicate(true))
	if not bool(checked.get("ok", false)):
		_set_error(str(checked.get("error", "Native profile validation failed.")))
		return false
	if record_undo and active_revision >= 0:
		_undo.append(active_recipe.duplicate(true))
		if _undo.size() > MAX_UNDO:
			_undo.pop_front()
	active_recipe = generator.get_configuration().duplicate(true)
	active_revision = int(checked.revision)
	active_fingerprint = str(checked.fingerprint)
	_has_active_chunk = false
	_job_completed = 0
	_job_compute_us = 0
	cache.clear()
	_cache_order.clear()
	_blocked_chunks.clear()
	pending_chunks.clear()
	last_packet.clear()
	last_error = ""
	preview.cancel_gesture()
	var chunk_size: int = int(active_recipe.get("chunk_size", 128))
	view_size.x = clampf(view_size.x, chunk_size, chunk_size * 4)
	view_size.y = view_size.x * 2.0 / 3.0
	_populate_catalogue(generator.get_catalogue())
	_sync_controls()
	_sync_preview()
	_update_requests()
	profile_editor.text = JSON.stringify(active_recipe, "  ", true)
	profile_status.text = "Accepted revision %d · %s" % [active_revision, active_fingerprint]
	_refresh_status()
	return true

func apply_controls() -> void:
	var recipe: Dictionary = active_recipe.duplicate(true) if active_revision >= 0 else default_recipe()
	if _dirty_controls.has("candidate"):
		recipe.candidate = CANDIDATES[candidate_picker.selected]
	if _dirty_controls.has("seed"):
		recipe.seed = int(seed_input.value)
	if _dirty_controls.has("chunk_size"):
		recipe.chunk_size = int(chunk_picker.get_item_text(chunk_picker.selected))
	var parameters: Dictionary = recipe.get("parameters", {}).duplicate(true)
	for key: String in parameter_inputs:
		if _dirty_controls.has(key):
			parameters[key] = parameter_inputs[key].value
	recipe.parameters = parameters
	if _dirty_controls.has("themes"):
		var old_themes: Dictionary = recipe.get("themes", {})
		var old_weights: Dictionary = old_themes.get("weights", {})
		var old_keys: Array = old_weights.keys()
		var weights: Dictionary = {}
		# Keep advanced third/further weights when changing the visible two-way
		# mixer. Rescaling all retained terms by the first weight is equivalent.
		var divisor: float = maxf(float(old_weights.get(old_keys[0], 1.0)), 0.000001) if not old_keys.is_empty() else 1.0
		for index: int in range(2, old_keys.size()):
			weights[old_keys[index]] = float(old_weights[old_keys[index]]) / divisor
		var base: String = base_theme.get_item_text(base_theme.selected)
		weights[base] = float(weights.get(base, 0.0)) + 1.0
		var blend: String = blend_theme.get_item_text(blend_theme.selected)
		if blend_weight.value > 0:
			weights[blend] = float(weights.get(blend, 0.0)) + blend_weight.value
		var excluded: Array = old_themes.get("exclude", []).duplicate()
		for id: String in exclusions:
			excluded.erase(id)
			if exclusions[id].button_pressed:
				excluded.append(id)
		recipe.themes = {"weights": weights, "exclude": excluded}
	apply_recipe(recipe)

func _sync_controls() -> void:
	_syncing_controls = true
	candidate_picker.select(maxi(CANDIDATES.find(str(active_recipe.get("candidate", "strata"))), 0))
	seed_input.value = int(active_recipe.get("seed", 1))
	var chunk_text: String = str(active_recipe.get("chunk_size", 128))
	var known_chunk: bool = false
	for index: int in range(chunk_picker.item_count):
		known_chunk = known_chunk or chunk_picker.get_item_text(index) == chunk_text
	if not known_chunk:
		chunk_picker.add_item(chunk_text)
	_select_text(chunk_picker, str(active_recipe.get("chunk_size", 128)))
	var parameters: Dictionary = active_recipe.get("parameters", {})
	for key: String in parameter_inputs:
		parameter_inputs[key].value = float(parameters.get(key, PARAMETER_SPECS[key][4]))
	var themes: Dictionary = active_recipe.get("themes", {})
	var weights: Dictionary = themes.get("weights", {"natural": 1.0})
	var keys: Array = weights.keys()
	if not keys.is_empty():
		_select_text(base_theme, str(keys[0]))
	if keys.size() > 1:
		_select_text(blend_theme, str(keys[1]))
		blend_weight.value = float(weights[keys[1]]) / maxf(float(weights[keys[0]]), 0.000001)
	else:
		blend_weight.value = 0
	for id: String in exclusions:
		exclusions[id].button_pressed = id in themes.get("exclude", [])
	_syncing_controls = false
	_dirty_controls.clear()

func _connect_control_tracking() -> void:
	candidate_picker.item_selected.connect(func(_index: int) -> void: _mark_control("candidate"))
	seed_input.value_changed.connect(func(_value: float) -> void: _mark_control("seed"))
	chunk_picker.item_selected.connect(func(_index: int) -> void: _mark_control("chunk_size"))
	for picker: OptionButton in [base_theme, blend_theme]:
		picker.item_selected.connect(func(_index: int) -> void: _mark_control("themes"))
	blend_weight.value_changed.connect(func(_value: float) -> void: _mark_control("themes"))
	for id: String in exclusions:
		exclusions[id].toggled.connect(func(_value: bool) -> void: _mark_control("themes"))
	for key: String in parameter_inputs:
		parameter_inputs[key].value_changed.connect(func(_value: float) -> void: _mark_control(key))

func _mark_control(key: String) -> void:
	if not _syncing_controls:
		_dirty_controls[key] = true

func add_gesture(points: PackedVector2Array) -> void:
	if points.is_empty() or active_revision < 0 or tool_picker.selected == 5:
		return
	var recipe: Dictionary = active_recipe.duplicate(true)
	var packed_points: Array = []
	for point: Vector2 in points:
		packed_points.append([floori(point.x), floori(point.y)])
	var id: String = _next_id(recipe)
	var priority: int = int(priority_input.value)
	match tool_picker.selected:
		0, 1:
			var stroke: Dictionary = {"id": id, "points": packed_points, "radius": radius_input.value, "strength": strength_input.value, "falloff": falloff_input.value, "priority": priority, "themes": {"weights": {}, "exclude": []}, "parameters": {}}
			if tool_picker.selected == 0:
				stroke.themes.weights[brush_theme.get_item_text(brush_theme.selected)] = 1.0
			else:
				stroke.parameters[brush_parameter.get_item_text(brush_parameter.selected)] = brush_value.value
			_append_mark(recipe, "strokes", stroke)
		2:
			_append_mark(recipe, "paths", {"id": id, "points": packed_points, "width": radius_input.value * 2.0, "material": material_picker.get_selected_id(), "priority": priority})
		3:
			_append_mark(recipe, "overrides", {"id": id, "bounds": _gesture_bounds(points), "material": material_picker.get_selected_id(), "priority": priority})
		4:
			var module: Dictionary = _module_instance(id, _gesture_bounds(points), priority)
			if module.is_empty():
				return
			_append_mark(recipe, "modules", module)
	apply_recipe(recipe)

func insert_example_module() -> void:
	if active_revision < 0:
		return
	var recipe: Dictionary = active_recipe.duplicate(true)
	var module: Dictionary = _module_instance(_next_id(recipe), [64, 128, 256, 256], int(priority_input.value))
	if module.is_empty():
		return
	_append_mark(recipe, "modules", module)
	if apply_recipe(recipe):
		set_camera_origin(Vector2(0, 96))

func _module_instance(id: String, bounds: Array, priority: int) -> Dictionary:
	var parsed := JSON.new()
	if parsed.parse(module_parameters.text) != OK or not parsed.data is Dictionary:
		_set_error("Module parameters must be a JSON object of numeric values.")
		return {}
	var module_id: String = module_picker.get_item_text(module_picker.selected)
	var parameters: Dictionary = parsed.data
	if module_id == "vault":
		var value: Variant = parameters.get("cell_size", 32)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 1 or float(value) != floorf(float(value)):
			_set_error("Vault cell_size must be a positive whole number.")
			return {}
		var cell_size: int = int(value)
		bounds[2] = maxi(cell_size, ceili(float(bounds[2]) / cell_size) * cell_size)
		bounds[3] = maxi(cell_size, ceili(float(bounds[3]) / cell_size) * cell_size)
	return {"id": id, "module": module_id, "version": 1, "bounds": bounds, "parameters": parameters, "after": [], "priority": priority}

static func _gesture_bounds(points: PackedVector2Array) -> Array:
	var first: Vector2 = points[0].floor()
	var last: Vector2 = points[-1].floor()
	var low: Vector2 = first.min(last)
	var extent: Vector2 = (first - last).abs() + Vector2.ONE
	return [int(low.x), int(low.y), int(extent.x), int(extent.y)]

static func _append_mark(recipe: Dictionary, field: String, mark: Dictionary) -> void:
	if not recipe.has(field):
		recipe[field] = []
	recipe[field].append(mark)

func _next_id(recipe: Dictionary) -> String:
	var used: Dictionary = {}
	for field: String in ["strokes", "paths", "overrides", "modules"]:
		for item: Dictionary in recipe.get(field, []):
			used[str(item.get("id", ""))] = true
	_authoring_serial += 1
	while used.has("mark-%d" % _authoring_serial):
		_authoring_serial += 1
	return "mark-%d" % _authoring_serial

func undo_authoring() -> void:
	if _undo.is_empty():
		_set_status("No earlier accepted profile in this workbench session.")
		return
	if apply_recipe(_undo[-1], false):
		_undo.pop_back()

func clear_authoring() -> void:
	if active_revision < 0:
		return
	var recipe: Dictionary = active_recipe.duplicate(true)
	for field: String in ["strokes", "paths", "overrides", "modules"]:
		recipe[field] = []
	apply_recipe(recipe)

func set_camera_origin(value: Vector2) -> void:
	# The authoring view uses Godot float coordinates; the native API supports a
	# wider integer domain. Keep interactive mapping precise in this finite range.
	camera_origin = value.clamp(Vector2(-1000000, -1000000), Vector2(1000000, 1000000))
	origin_x.value = camera_origin.x
	origin_y.value = camera_origin.y
	_sync_preview()
	_update_requests()
	_refresh_status()

func zoom_view(factor: float) -> void:
	if not is_finite(factor) or factor <= 0:
		return
	var chunk_size: int = int(active_recipe.get("chunk_size", 128))
	var center: Vector2 = camera_origin + view_size * 0.5
	view_size.x = clampf(roundf(view_size.x * factor), chunk_size, chunk_size * 4)
	view_size.y = roundf(view_size.x * 2.0 / 3.0)
	set_camera_origin(center - view_size * 0.5)

func visible_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var chunk_size: int = int(active_recipe.get("chunk_size", 128))
	var first := Vector2i(floori(camera_origin.x / chunk_size), floori(camera_origin.y / chunk_size))
	var last := Vector2i(floori((camera_origin.x + view_size.x - 0.001) / chunk_size), floori((camera_origin.y + view_size.y - 0.001) / chunk_size))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			result.append(Vector2i(x, y))
	var center: Vector2 = (camera_origin + view_size * 0.5) / chunk_size
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: float = (Vector2(a) + Vector2.ONE * 0.5).distance_squared_to(center)
		var db: float = (Vector2(b) + Vector2.ONE * 0.5).distance_squared_to(center)
		if da == db:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		return da < db)
	return result

func _update_requests() -> void:
	pending_chunks.clear()
	if active_revision < 0:
		return
	var visible: Array[Vector2i] = visible_chunks()
	# A tight work budget may reject every requested chunk. Retain refusal state
	# only for the visible request set, not an unbounded history of visited space.
	for coordinate: Vector2i in _blocked_chunks.keys():
		if not coordinate in visible:
			_blocked_chunks.erase(coordinate)
	for coordinate: Vector2i in visible:
		if cache.has(coordinate):
			_cache_order.erase(coordinate)
			_cache_order.append(coordinate)
		elif not _blocked_chunks.has(coordinate) and not (_has_active_chunk and coordinate == _active_chunk):
			if pending_chunks.size() < MAX_QUEUED_CHUNKS:
				pending_chunks.append(coordinate)
	preview.queue_redraw()

func _process(_delta: float) -> void:
	service_generation()

func service_generation() -> void:
	if generator == null or active_revision < 0:
		return
	if not _has_active_chunk:
		if pending_chunks.is_empty():
			return
		_active_chunk = pending_chunks.pop_front()
		var started: Dictionary = generator.begin_chunk(_active_chunk)
		if not bool(started.get("ok", false)):
			_blocked_chunks[_active_chunk] = true
			_set_error(str(started.get("error", "Chunk request rejected.")))
			return
		_has_active_chunk = true
		_job_completed = 0
		_job_compute_us = 0
	var start_us: int = Time.get_ticks_usec()
	var packet: Dictionary = generator.advance(CELL_BUDGET)
	_job_compute_us += Time.get_ticks_usec() - start_us
	_job_completed = int(packet.get("completed_cells", 0))
	var state: String = str(packet.get("state", "failed"))
	if not bool(packet.get("ok", false)) or state in ["failed", "cancelled"]:
		_has_active_chunk = false
		_blocked_chunks[_active_chunk] = true
		_set_error(str(packet.get("error", "Native chunk generation failed.")))
	elif state == "ready":
		_has_active_chunk = false
		packet["compute_usec"] = _job_compute_us
		if not accept_chunk(packet, _active_chunk):
			_blocked_chunks[_active_chunk] = true
		_update_requests()
	_refresh_status()

func accept_chunk(packet: Dictionary, expected_coordinate: Variant = null) -> bool:
	if not bool(packet.get("ok", false)) or str(packet.get("state", "ready")) != "ready":
		_set_error("Only completed native chunks can enter the preview.")
		return false
	if int(packet.get("revision", -1)) != active_revision or str(packet.get("fingerprint", "")) != active_fingerprint:
		_set_error("Discarded a chunk from an older generation profile.")
		return false
	for key: String in ["chunk_x", "chunk_y"]:
		if not packet.has(key) or not packet[key] is int or int(packet[key]) < -2147483648 or int(packet[key]) > 2147483647:
			_set_error("Native chunk coordinate metadata is missing or invalid.")
			return false
	var coordinate := Vector2i(int(packet.chunk_x), int(packet.chunk_y))
	if expected_coordinate is Vector2i and coordinate != expected_coordinate:
		_set_error("Native completion does not match the requested chunk coordinate.")
		return false
	var chunk_size: int = int(active_recipe.get("chunk_size", 128))
	if int(packet.get("chunk_size", 0)) != chunk_size or not packet.get("cells") is PackedByteArray:
		_set_error("Native chunk shape does not match the accepted profile.")
		return false
	var cells: PackedByteArray = packet.cells
	if cells.size() != chunk_size * chunk_size:
		_set_error("Native chunk byte count does not match its dimensions.")
		return false
	var rgba := PackedByteArray()
	rgba.resize(cells.size() * 4)
	for index: int in range(cells.size()):
		var id: int = int(cells[index])
		if id >= Palette.MATERIAL_COUNT or id == 10:
			_set_error("Native chunk contains an invalid material ID.")
			return false
		var packed: int = int(Palette.BASE_RGBA8[id])
		rgba[index * 4] = (packed >> 24) & 255
		rgba[index * 4 + 1] = (packed >> 16) & 255
		rgba[index * 4 + 2] = (packed >> 8) & 255
		rgba[index * 4 + 3] = 255
	var copied: Dictionary = packet.duplicate(true)
	copied["texture"] = ImageTexture.create_from_image(Image.create_from_data(chunk_size, chunk_size, false, Image.FORMAT_RGBA8, rgba))
	cache[coordinate] = copied
	_cache_order.erase(coordinate)
	_cache_order.append(coordinate)
	while _cache_order.size() > MAX_CACHE_CHUNKS:
		cache.erase(_cache_order.pop_front())
	last_packet = packet.duplicate(true)
	preview.chunks = cache
	preview.queue_redraw()
	return true

func _sync_preview() -> void:
	if preview == null:
		return
	preview.camera_origin = camera_origin
	preview.view_size = view_size
	preview.chunk_size = int(active_recipe.get("chunk_size", 128))
	preview.chunks = cache
	preview.recipe = active_recipe
	_refresh_brush_preview()
	preview.queue_redraw()

func _refresh_brush_preview() -> void:
	if preview != null and radius_input != null:
		preview.brush_radius = radius_input.value
		preview.tool_mode = tool_picker.selected
		preview.queue_redraw()

func _set_brush_parameter_range() -> void:
	var key: String = brush_parameter.get_item_text(brush_parameter.selected)
	var spec: Array = PARAMETER_SPECS[key]
	brush_value.min_value = float(spec[1])
	brush_value.max_value = float(spec[2])
	brush_value.step = float(spec[3])
	brush_value.value = float(spec[4])

func _refresh_module_editor() -> void:
	if module_parameters == null:
		return
	var id: String = module_picker.get_item_text(module_picker.selected)
	module_parameters.text = JSON.stringify(MODULE_DEFAULTS.get(id, {}), "  ", true)
	match id:
		"arcology": module_help.text = "Multistory rooms around a shared service shaft. Draw bounds across several chunks."
		"vault": module_help.text = "Connected maze prepared once per module. Placement width and height snap to cell_size; at most 64 × 64 maze nodes."
		"aqueduct": module_help.text = "Repeated arches, supports and a bounded fluid trough. Connect to corridors or blend into terrain."
		_: module_help.text = "Native registered module. Supply its versioned numeric parameters."

func _inspect_point(point: Vector2) -> void:
	var x: int = floori(point.x)
	var y: int = floori(point.y)
	var chunk_size: int = int(active_recipe.get("chunk_size", 128))
	var coordinate := Vector2i(floori(float(x) / chunk_size), floori(float(y) / chunk_size))
	var text: String = "Cell %d, %d · chunk %d, %d" % [x, y, coordinate.x, coordinate.y]
	if cache.has(coordinate):
		var index: int = (y - coordinate.y * chunk_size) * chunk_size + x - coordinate.x * chunk_size
		var id: int = int(cache[coordinate].cells[index])
		text += " · %d / %s" % [id, _material_label(id)]
	pointer_label.text = text

func _refresh_status() -> void:
	if active_revision < 0:
		return
	identity_label.text = "%s · seed %s · revision %d · %s" % [str(active_recipe.get("candidate", "strata")), str(active_recipe.get("seed", 1)), active_revision, active_fingerprint]
	marks_label.text = "%d theme/parameter strokes · %d routes · %d hard overrides · %d modules" % [active_recipe.get("strokes", []).size(), active_recipe.get("paths", []).size(), active_recipe.get("overrides", []).size(), active_recipe.get("modules", []).size()]
	if not last_error.is_empty():
		status_label.text = last_error
		return
	var chunk_size: int = int(active_recipe.get("chunk_size", 128))
	var text: String = "%d/%d cached chunks · %d queued" % [cache.size(), MAX_CACHE_CHUNKS, pending_chunks.size()]
	if _has_active_chunk:
		text += " · generating %d, %d: %d / %d cells" % [_active_chunk.x, _active_chunk.y, _job_completed, chunk_size * chunk_size]
	elif pending_chunks.is_empty():
		text += " · visible region ready"
	if not last_packet.is_empty():
		text += " · last chunk %s · %s operations · %.2f ms native work" % [str(last_packet.get("hash", "")), str(last_packet.get("operations", 0)), float(last_packet.get("compute_usec", 0)) / 1000.0]
	_set_status(text)

func _set_error(message: String) -> void:
	last_error = message
	if status_label != null:
		status_label.text = message
		status_label.modulate = Color(1.0, 0.67, 0.53)
	if profile_status != null:
		profile_status.text = message

func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
		status_label.modulate = Color(0.76, 0.86, 0.88)

func _open_profile() -> void:
	preview.cancel_gesture()
	profile_dialog.popup_centered()

func apply_json() -> void:
	if profile_editor.text.length() > MAX_PROFILE_BYTES or profile_editor.text.to_utf8_buffer().size() > MAX_PROFILE_BYTES:
		_set_error("Profile exceeds the 1 MiB authoring limit.")
		return
	var parsed := JSON.new()
	if parsed.parse(profile_editor.text) != OK:
		_set_error("JSON line %d: %s" % [parsed.get_error_line(), parsed.get_error_message()])
		return
	if not parsed.data is Dictionary:
		_set_error("The generation profile must be a JSON object.")
		return
	apply_recipe(parsed.data)

func _choose_load_profile() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Load generation profile"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Generation profile"])
	profile_dialog.add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void: load_profile(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)

func _choose_save_profile() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Save accepted generation profile"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.json ; Generation profile"])
	dialog.current_file = "cybersand-worldgen.json"
	profile_dialog.add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void: save_profile(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)

func load_profile(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_error("Cannot open profile: %s" % error_string(FileAccess.get_open_error()))
		return false
	if file.get_length() > MAX_PROFILE_BYTES:
		file.close()
		_set_error("Profile exceeds the 1 MiB authoring limit.")
		return false
	profile_editor.text = file.get_as_text()
	file.close()
	profile_status.text = "Loaded %s. Apply JSON to validate and generate." % path.get_file()
	return true

func save_profile(path: String) -> bool:
	if active_revision < 0:
		_set_error("There is no accepted generation profile to save.")
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_error("Cannot save profile: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(active_recipe, "  ", true) + "\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		_set_error("Profile write failed: %s" % error_string(error))
		return false
	profile_status.text = "Saved accepted revision %d to %s." % [active_revision, path.get_file()]
	return true

static func _material_label(id: int) -> String:
	var common: Dictionary = {0: "empty / carve", 1: "wall", 2: "sand", 3: "water", 7: "wood", 8: "lava", 11: "plant", 13: "stone", 28: "metal", 31: "concrete", 35: "glass", 38: "limestone", 39: "sandstone", 40: "granite", 41: "cobblestone", 42: "mossy stone", 43: "brick", 53: "copper", 56: "packed earth", 57: "industrial brick", 58: "reinforced concrete", 62: "steel plate", 63: "painted steel", 73: "rubber", 74: "cable bundle"}
	return str(common.get(id, "material " + str(id)))

func _label(parent: Node, text: String, font_size: int = 14, tint: Color = Color(0.81, 0.87, 0.9)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = tint
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _options(parent: Node, values: Array[String]) -> OptionButton:
	var picker := OptionButton.new()
	for value: String in values:
		picker.add_item(value)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(picker)
	return picker

func _spin(parent: Node, low: float, high: float, step: float, initial: float) -> SpinBox:
	var input := SpinBox.new()
	input.min_value = low
	input.max_value = high
	input.step = step
	input.value = initial
	input.custom_minimum_size.x = 104
	parent.add_child(input)
	return input

func _labelled_spin(parent: Node, text: String, low: float, high: float, step: float, initial: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, text, 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _spin(row, low, high, step, initial)

static func _select_text(picker: OptionButton, value: String) -> void:
	for index: int in range(picker.item_count):
		if picker.get_item_text(index) == value:
			picker.select(index)
			return
