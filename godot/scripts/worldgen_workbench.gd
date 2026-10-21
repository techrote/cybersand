class_name CyberWorldGenerationWorkbench
extends Control

# Opt-in native procedural preview. Its private generator has one main-thread
# owner. These copied recipes/cells never access the live sandbox's World.
const Preview = preload("res://scripts/worldgen_preview.gd")
const Palette = preload("res://scripts/material_appearance_lut.gd")
const WorkbenchTools = preload("res://scripts/worldgen_workbench_tools.gd")
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
const SPATIAL_EXAMPLES: Array[String] = [
	"typed-industrial-structure", "typed-vector-utilities", "typed-categorical-districts",
	"typed-reusable-decay", "typed-multiscale-seeds",
]
# Presentation names for the existing native material IDs, matching main.gd.
# The reserved invalid slot 10 is never offered by an authoring picker.
const MATERIAL_LABELS: Array[String] = [
	"empty", "wall", "sand", "water", "smoke", "cloner", "fire", "wood",
	"lava", "ice", "invalid", "plant", "acid", "stone", "dust", "mite",
	"oil", "rocket", "fungus", "seed", "paste", "slush", "steam", "salt",
	"brine", "sodium", "gunpowder", "coal", "metal", "rust", "cement", "concrete",
	"toxic sludge", "mercury", "spark", "glass", "molten glass", "foam", "limestone block", "sandstone block",
	"granite block", "cobblestone", "mossy cobblestone", "red brick", "lime plaster", "wattle and daub", "oak timber", "thatch",
	"terracotta tile", "slate", "wrought iron", "lead sheet", "bronze", "copper", "verdigris copper", "stained glass",
	"packed earth", "industrial brick", "reinforced concrete", "asphalt", "wet asphalt", "wet cobblestone", "steel plate", "painted steel",
	"corrugated steel", "rusted steel", "steel grating", "chainlink", "steel pipe", "copper pipe", "ceramic tile", "chemical glass",
	"dark glass", "rubber", "cable bundle", "insulation", "hazard stripe", "neon cyan", "neon magenta", "neon amber", "LED white",
	"pine planks", "birch log", "rough oak log", "walnut panel", "mahogany panel", "bamboo", "plywood", "driftwood", "cedar shingles", "charred timber", "cork", "wicker", "cardboard", "paper screen", "tar block", "acrylic sheet", "moss wall", "marble", "chalk block", "basalt columns", "obsidian", "adobe brick", "raw clay", "firebrick", "packed snow", "rock salt block", "gypsum board", "quicklime block", "rammed earth", "sandbag", "terrazzo", "gabion", "galvanised zinc sheet", "aluminium panel", "magnesium plate", "thermite brick", "bare iron plate", "gold leaf", "brass panel", "glass block", "frosted glass", "quartz crystal", "uranium glass", "sugar glass", "wax block", "sulfur block", "phosphor panel", "polymer panel", "solar panel", "carbon fibre", "heat-shield tile",
]

var tools2: RefCounted
var _redo: Array[Dictionary] = []
var _interactive_edit: bool = false
var _edit_serial: int = 0
var _edit_thread: Thread
var _pending_edit: Dictionary = {}
var _active_edit: Dictionary = {}
var last_prepare_usec: int = 0
var last_adopt_usec: int = 0
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
var inspect_toggle: CheckButton
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
var page_picker: OptionButton
var diagnostic_picker: OptionButton
var diagnostic_legend: Label
var diagnostic_channel: String = ""
var _view_token: int = 0
var _active_view_token: int = 0
var _inspected_material: int = -1
var field_specs: Dictionary = {}
var field_choice: OptionButton
var field_id: LineEdit
var field_kind: OptionButton
var field_inputs: LineEdit
var field_warp_x: OptionButton
var field_warp_y: OptionButton
var field_context: OptionButton
var field_parameter_box: VBoxContainer
var field_parameter_inputs: Dictionary = {}
var field_help: Label
var spatial_specs: Dictionary = {}
var spatial_nodes: Dictionary = {}
var spatial_editor: TextEdit
var spatial_kind: OptionButton
var spatial_scale: OptionButton
var spatial_id: LineEdit
var spatial_choice: OptionButton
var spatial_help: Label
var spatial_example: OptionButton
var semantic_feature_count: int = 0
var semantic_route_report: Dictionary = {}
var aggregate_choice: OptionButton
var aggregate_id: LineEdit
var aggregate_grain: SpinBox
var aggregate_variation: OptionButton
var aggregate_rows: VBoxContainer
var aggregate_components: Array[Dictionary] = []
var modifier_choice: OptionButton
var modifier_id: LineEdit
var modifier_priority: SpinBox
var modifier_strength: SpinBox
var modifier_application: OptionButton
var modifier_exclusion: OptionButton
var modifier_context: OptionButton
var modifier_context_material: OptionButton
var modifier_bounds: LineEdit
var modifier_action: OptionButton
var modifier_material: OptionButton
var modifier_aggregate: OptionButton
var modifier_parameter: OptionButton
var modifier_low: SpinBox
var modifier_high: SpinBox
var modifier_mapping_field: OptionButton
var modifier_theme: OptionButton
var modifier_json: TextEdit
var modifier_translate_x: SpinBox
var modifier_translate_y: SpinBox
var modifier_scale: SpinBox
var brush_application: OptionButton
var brush_exclusion: OptionButton
var brush_context: OptionButton
var brush_context_material: OptionButton
var brush_aggregate: OptionButton
var module_application: OptionButton
var module_exclusion: OptionButton
var module_strength: SpinBox
var module_choice: OptionButton

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
	profile_editor.text = JSON.stringify(default_recipe(), "  ", true, true)
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		_set_error("The current native generator is unavailable. Build the GDExtension for this source, then reopen this scene.")
		return
	generator = ClassDB.instantiate(&"CyberWorldGenerator")
	for method: StringName in [&"configure", &"begin_chunk", &"advance", &"get_configuration", &"get_catalogue"]:
		if not generator.has_method(method):
			generator = null
			_set_error("The loaded native generator has an incompatible API. Rebuild the GDExtension for this source.")
			return
	var catalogue: Dictionary = generator.get_catalogue()
	if not catalogue.has("field_kinds"):
		generator = null
		_set_error("The loaded native generator predates field authoring. Rebuild the GDExtension for this source.")
		return
	_populate_catalogue(catalogue)
	apply_recipe(default_recipe(), false)

func _build_ui() -> void:
	tools2 = WorkbenchTools.new(self)
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
	var title: Label = _label(heading, "CYBERSAND / GENERATION WORKBENCH 2", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "Examples…", func() -> void: _open_profile(); _choose_load_profile(true))
	_button(heading, "Profile JSON…", _open_profile)
	_button(heading, "Apply controls", apply_controls)
	_button(heading, "Undo", undo_authoring)
	_button(heading, "Redo", redo_authoring)
	_button(heading, "Cancel edit", cancel_pending_edit)
	_label(layout, "Native procedural preview · globally addressed chunks · generation only", 15, Color(0.62, 0.8, 0.85))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(390, 450)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sidebar)
	page_picker = _options(sidebar, ["Generator", "Brushes / contextual sculpt", "Modules", "Fields & masks", "Aggregates", "Modifiers", "Typed spatial graphs", "Graph canvas", "Hierarchy / planes", "Why is this here?", "Quality / comparisons"])
	var tabs := TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(tabs)
	page_picker.item_selected.connect(func(index: int) -> void: tabs.current_tab = index)
	_build_generator_tab(_tab(tabs, "Generator"))
	_build_brush_tab(_tab(tabs, "Brushes"))
	_build_module_tab(_tab(tabs, "Modules"))
	_build_field_tab(_tab(tabs, "Fields"))
	_build_aggregate_tab(_tab(tabs, "Aggregates"))
	_build_modifier_tab(_tab(tabs, "Modifiers"))
	_build_spatial_tab(_tab(tabs, "Spatial"))
	tools2.build_graph_tab(_tab(tabs, "Graph"))
	tools2.build_hierarchy_tab(_tab(tabs, "Hierarchy"))
	tools2.build_inspector_tab(_tab(tabs, "Inspector"))
	tools2.build_quality_tab(_tab(tabs, "Quality"))
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
	inspect_toggle = CheckButton.new()
	inspect_toggle.text = "Inspect"
	inspect_toggle.button_pressed = true
	inspect_toggle.toggled.connect(func(enabled: bool) -> void:
		preview.inspection_only = enabled
		preview.cancel_gesture())
	navigation.add_child(inspect_toggle)
	var guides := CheckButton.new()
	guides.text = "Guides"
	guides.button_pressed = true
	navigation.add_child(guides)
	tools2.build_view_controls(viewer)
	preview = Preview.new()
	preview.inspection_only = true
	preview.custom_minimum_size = Vector2(380, 320)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer.add_child(preview)
	preview.stroke_finished.connect(func(points: PackedVector2Array) -> void:
		_interactive_edit = true
		add_gesture(points)
		_interactive_edit = false)
	preview.pan_requested.connect(func(delta: Vector2) -> void: set_camera_origin(camera_origin + delta))
	preview.zoom_requested.connect(zoom_view)
	preview.point_inspected.connect(_inspect_point)
	var inspection := HBoxContainer.new()
	viewer.add_child(inspection)
	_label(inspection, "Inspect", 14)
	diagnostic_picker = _options(inspection, ["Materials"])
	diagnostic_picker.set_item_metadata(0, "")
	diagnostic_picker.item_selected.connect(func(index: int) -> void: select_diagnostic(str(diagnostic_picker.get_item_metadata(index))))
	var opacity: SpinBox = _labelled_spin(inspection, "Overlay", 0, 1, 0.1, 1)
	opacity.value_changed.connect(func(value: float) -> void: preview.diagnostic_opacity = value; preview.queue_redraw())
	diagnostic_legend = _label(inspection, "Material colours", 13)
	grid.toggled.connect(func(enabled: bool) -> void: preview.grid_visible = enabled; preview.queue_redraw())
	guides.toggled.connect(func(enabled: bool) -> void: preview.guides_visible = enabled; preview.queue_redraw())
	pointer_label = _label(viewer, "Inspect click / Ctrl-click · turn Inspect off to paint · right/middle drag to pan · wheel to zoom", 14, Color(0.65, 0.77, 0.81))
	pointer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	marks_label = _label(viewer, "", 14)
	marks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	tool_picker = _options(box, ["Theme stroke", "Parameter stroke", "Carved / material route", "Hard material rectangle", "Structured module", "Pan only", "Contextual carve", "Contextual material", "Contextual aggregate", "Contextual parameter", "Contextual theme"])
	tool_picker.item_selected.connect(func(index: int) -> void:
		if preview != null:
			preview.cancel_gesture()
			preview.tool_mode = index
			if inspect_toggle != null: inspect_toggle.button_pressed = false
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
	_label(box, "CONTEXTUAL SCULPT", 14, Color(0.73, 0.68, 1.0))
	_note(box, "Contextual tools append a masked modifier. Context samples the fixed base terrain before fields, modules and modifiers; it never queries live simulation.")
	brush_application = _field_reference(box, "Application field")
	brush_exclusion = _field_reference(box, "Exclusion field")
	brush_context = _options(box, ["any", "empty", "occupied", "solid", "fluid", "material"])
	brush_context_material = _material_options(box)
	_button(box, "Use last inspected material", _pick_context_material)
	_note(box, "The picked ID is from the displayed result. The context filter still tests the original base terrain, so a painted result may differ from that context.")
	brush_aggregate = _field_reference(box, "Aggregate for contextual paint")

func _build_module_tab(box: VBoxContainer) -> void:
	_label(box, "STRUCTURED FEATURES", 14, Color(0.73, 0.68, 1.0))
	module_choice = _field_reference(box, "Accepted instance / new placement")
	module_choice.item_selected.connect(func(_index: int) -> void: _load_module_instance())
	module_picker = _options(box, ["arcology", "vault", "aqueduct"])
	module_picker.item_selected.connect(func(_index: int) -> void: _refresh_module_editor())
	module_help = _label(box, "", 14)
	module_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	module_parameters = TextEdit.new()
	module_parameters.custom_minimum_size = Vector2(0, 190)
	module_parameters.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(module_parameters)
	module_application = _field_reference(box, "Application field")
	module_exclusion = _field_reference(box, "Exclusion field")
	module_strength = _labelled_spin(box, "Masked output strength", 0, 1, 0.05, 1)
	_button(box, "Apply parameters & masks to selected instance", apply_module_instance)
	_button(box, "Inspect selected module mask", func() -> void: select_diagnostic("module:" + _reference(module_choice)))
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

func _build_field_tab(box: VBoxContainer) -> void:
	_note(box, "Named native fields drive masks, sidechains, parameter mappings and material variation. Inputs reference other field IDs; cycles are rejected.")
	field_choice = _field_reference(box, "Accepted field / new draft")
	field_choice.item_selected.connect(func(_index: int) -> void: _load_field())
	field_id = _text_input(box, "Field ID", "field-1")
	field_kind = _options(box, ["constant"])
	field_kind.item_selected.connect(func(_index: int) -> void: _refresh_field_parameters({}))
	field_inputs = _text_input(box, "Input IDs, comma separated", "")
	field_warp_x = _field_reference(box, "Warp X driver")
	field_warp_y = _field_reference(box, "Warp Y driver")
	field_context = _options(box, ["occupied", "solid", "fluid", "depth", "slope", "route"])
	field_help = _note(box, "Field controls require the current native extension.")
	field_parameter_box = VBoxContainer.new()
	box.add_child(field_parameter_box)
	_button(box, "Apply field", apply_field)
	_button(box, "Duplicate as new field", func() -> void: field_choice.select(0); field_id.text = _entry_id("fields", "field"))
	_button(box, "Delete selected field", func() -> void: delete_entry("fields", _reference(field_choice)))
	_button(box, "Inspect accepted field", func() -> void: select_diagnostic("field:" + _reference(field_choice)))
	_note(box, "SFC ranks describe finite tiles. Hilbert adjacency holds within a tile; tile borders and Morton ranks do not guarantee connected routes. Use the existing route tools for navigation guidance.")

func _build_spatial_tab(box: VBoxContainer) -> void:
	_note(box, "Schema 2 adds typed, immutable spatial functions. Edit nodes, named subgraphs, instances, geometry and finite adjacency assignments here. Only explicit normalized outputs can drive material masks.")
	spatial_example = _options(box, SPATIAL_EXAMPLES)
	_button(box, "Load complete spatial example", func() -> void: load_spatial_example(spatial_example.get_item_text(spatial_example.selected)))
	_button(box, "Load four foundries hierarchy", load_hierarchy_example)
	_note(box, "The hierarchy profile creates four districts with nested rooms, apparatus, shared passages and utilities. Edit its grammar in the full profile JSON; inspect a cell for ancestry and material decisions.")
	spatial_choice = _field_reference(box, "Accepted typed output")
	spatial_choice.item_selected.connect(func(_index: int) -> void: _refresh_spatial_help())
	_button(box, "Inspect typed output", func() -> void: select_diagnostic("spatial:" + _reference(spatial_choice)))
	spatial_help = _note(box, "Choose an accepted output to inspect its type, units, sampling scale and native work declaration.")
	spatial_id = _text_input(box, "New node ID", "spatial-node")
	spatial_kind = _options(box, ["coordinate_x"])
	spatial_scale = _options(box, ["1", "4", "16", "64"])
	_button(box, "Insert operator draft into JSON", _insert_spatial_node)
	spatial_editor = TextEdit.new()
	spatial_editor.custom_minimum_size = Vector2(0, 300)
	spatial_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	spatial_editor.text = JSON.stringify({"nodes":[]}, "  ", true, true)
	box.add_child(spatial_editor)
	_button(box, "Apply spatial JSON", apply_spatial_json)
	_button(box, "Restore accepted graph text", func() -> void: spatial_editor.text = JSON.stringify(active_recipe.get("spatial", {"nodes":[]}), "  ", true, true))
	_note(box, "Draft input_1 / input_2 references must be replaced with real node IDs. Full profile JSON also edits material modifiers. Category addresses stay exact; colours and signed-value ramps are display mappings only.")

func load_spatial_example(name: String) -> bool:
	if not name in SPATIAL_EXAMPLES:
		_set_error("Unknown typed spatial example.")
		return false
	var path: String = ProjectSettings.globalize_path("res://../examples/worldgen/" + name + ".json")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		_set_error("Cannot read typed spatial example: " + name)
		return false
	return apply_recipe(parser.data)

func load_hierarchy_example() -> bool:
	var path: String = ProjectSettings.globalize_path("res://../examples/worldgen/hierarchy-multi-district.json")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		_set_error("Cannot read the four foundries hierarchy example.")
		return false
	if not apply_recipe(parser.data):
		return false
	camera_origin = Vector2(-128, -128)
	view_size = Vector2(256, 256)
	_sync_preview()
	return true

func apply_spatial_json() -> bool:
	if spatial_editor.text.to_utf8_buffer().size() > MAX_PROFILE_BYTES:
		_set_error("Spatial JSON exceeds the 1 MiB profile limit.")
		return false
	var parser := JSON.new()
	if parser.parse(spatial_editor.text) != OK or not parser.data is Dictionary:
		_set_error("Spatial JSON must be a valid object: " + parser.get_error_message())
		return false
	var recipe: Dictionary = active_recipe.duplicate(true)
	recipe.schema = maxi(2, int(recipe.get("schema", 1)))
	recipe.spatial = parser.data
	return apply_recipe(recipe)

func _insert_spatial_node() -> void:
	var parser := JSON.new()
	if parser.parse(spatial_editor.text) != OK or not parser.data is Dictionary:
		_set_error("Fix spatial JSON before inserting a node.")
		return
	var definition: Dictionary = parser.data
	if definition.has("nodes") and not definition.nodes is Array:
		_set_error("Spatial nodes must be an array.")
		return
	var kind: String = spatial_kind.get_item_text(spatial_kind.selected)
	var spec: Dictionary = spatial_specs.get(kind, {})
	var node: Dictionary = {"id":spatial_id.text.strip_edges(), "kind":kind, "sampling_scale":int(spatial_scale.get_item_text(spatial_scale.selected))}
	var inputs: Array[String] = []
	for index: int in range(int(spec.get("input_count", 0))): inputs.append("input_%d" % (index + 1))
	if not inputs.is_empty(): node.inputs = inputs
	var parameters: Dictionary = {}
	for parameter: Dictionary in spec.get("parameters", []): parameters[str(parameter.name)] = parameter.default_value
	if not parameters.is_empty(): node.parameters = parameters
	if kind == "constant": node.value = {"type":"scalar", "x":0}
	if kind == "category_is": node.value = {"type":"category", "category":{"x":"0","y":"0","domain":"0000000000000000"}}
	if kind in ["parameter", "geometry_distance", "assigned_region"]: node.reference = "replace-reference"
	var nodes: Array = definition.get("nodes", [])
	nodes.append(node)
	definition.nodes = nodes
	spatial_editor.text = JSON.stringify(definition, "  ", true, true)

func _refresh_spatial_help() -> void:
	if spatial_help == null: return
	var id: String = _reference(spatial_choice)
	if not spatial_nodes.has(id):
		spatial_help.text = "Choose an accepted output to inspect its type, units, sampling scale and native work declaration."
		return
	var info: Dictionary = spatial_nodes[id]
	spatial_help.text = "%s · %s · cells^%d · sample every %d cells\nBounds [%s, %s] · %d declared operations\nIdentity %s" % [id, str(info.type), int(info.unit_power), int(info.sampling_scale), str(info.minimum), str(info.maximum), int(info.operations), str(info.fingerprint)]
	if str(info.type) == "signed_distance":
		spatial_help.text += "\nDistance factors [%s, %s]" % [str(info.distance_min_factor), str(info.distance_max_factor)]

func _build_aggregate_tab(box: VBoxContainer) -> void:
	_note(box, "An aggregate distributes existing materials in spatial grains. Weights describe preferences; physics and material rules remain unchanged.")
	aggregate_choice = _field_reference(box, "Accepted aggregate / new draft")
	aggregate_choice.item_selected.connect(func(_index: int) -> void: _load_aggregate())
	aggregate_id = _text_input(box, "Aggregate ID", "aggregate-1")
	aggregate_grain = _labelled_spin(box, "Grain size", 1, 4096, 1, 12)
	aggregate_variation = _field_reference(box, "Variation field (optional)")
	_note(box, "A variation field selects the component from its value. Grain size controls the spatial fallback only when no variation field is selected.")
	_label(box, "MATERIAL / RELATIVE WEIGHT", 14, Color(0.54, 0.85, 0.81))
	aggregate_rows = VBoxContainer.new()
	box.add_child(aggregate_rows)
	aggregate_components = [{"material":38,"weight":3.0}, {"material":39,"weight":1.0}]
	_render_aggregate_rows()
	_button(box, "Add component", func() -> void:
		if aggregate_components.size() < 16:
			aggregate_components.append({"material":38,"weight":1.0})
			_render_aggregate_rows())
	_button(box, "Apply aggregate", apply_aggregate)
	_button(box, "Duplicate as new aggregate", func() -> void: aggregate_choice.select(0); aggregate_id.text = _entry_id("aggregates", "aggregate"))
	_button(box, "Delete selected aggregate", func() -> void: delete_entry("aggregates", _reference(aggregate_choice)))
	_note(box, "Select this aggregate in a modifier or Contextual aggregate brush to place it. Deleting an in-use recipe is refused until its references are changed.")

func _build_modifier_tab(box: VBoxContainer) -> void:
	_note(box, "A modifier combines a field mask, exclusion sidechain, spatial shape and fixed base-terrain context. Lower priority runs first; final hard material overrides remain authoritative.")
	modifier_choice = _field_reference(box, "Accepted modifier / new draft")
	modifier_choice.item_selected.connect(func(_index: int) -> void: _load_modifier())
	modifier_id = _text_input(box, "Modifier ID", "modifier-1")
	modifier_priority = _labelled_spin(box, "Priority", -1000, 1000, 1, 10)
	modifier_strength = _labelled_spin(box, "Strength", 0, 1, 0.05, 1)
	modifier_application = _field_reference(box, "Application field")
	modifier_exclusion = _field_reference(box, "Exclusion sidechain field")
	modifier_context = _options(box, ["any", "empty", "occupied", "solid", "fluid", "material"])
	modifier_context_material = _material_options(box)
	modifier_bounds = _text_input(box, "Bounds [x,y,width,height]; blank keeps stroke/world", "")
	modifier_action = _options(box, ["Keep JSON actions", "Paint material", "Paint aggregate", "Set parameter", "Map field to parameter", "Blend theme"])
	modifier_material = _material_options(box)
	modifier_aggregate = _field_reference(box, "Aggregate")
	var keys: Array[String] = []
	for key: String in PARAMETER_SPECS:
		if key != "district_size": keys.append(key)
	modifier_parameter = _options(box, keys)
	modifier_parameter.select(keys.find("cave_threshold"))
	modifier_low = _labelled_spin(box, "Target / mapping low", 0, 1, 0.01, 0.6)
	modifier_high = _labelled_spin(box, "Mapping high", 0, 1, 0.01, 0.9)
	modifier_parameter.item_selected.connect(func(_index: int) -> void: _modifier_parameter_range())
	modifier_mapping_field = _field_reference(box, "Mapping field")
	modifier_theme = _options(box, THEME_IDS)
	_label(box, "FULL MODIFIER DRAFT", 14)
	modifier_json = TextEdit.new()
	modifier_json.custom_minimum_size.y = 200
	modifier_json.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	modifier_json.text = "{\"material\": 0}"
	box.add_child(modifier_json)
	_note(box, "Guided identity, masks, context and bounds are applied to this draft. Keep JSON actions preserves combined themes, parameters and mappings; selecting another action replaces those actions.")
	_button(box, "Apply modifier", apply_modifier)
	_button(box, "Duplicate as new modifier", func() -> void: modifier_choice.select(0); modifier_id.text = _entry_id("modifiers", "modifier"))
	_button(box, "Delete selected modifier", func() -> void: delete_entry("modifiers", _reference(modifier_choice)))
	_button(box, "Inspect effective mask", func() -> void: select_diagnostic("modifier:" + _reference(modifier_choice)))
	_label(box, "MOVE / SCALE ACCEPTED MODIFIER", 14, Color(0.73, 0.68, 1.0))
	modifier_translate_x = _labelled_spin(box, "Translate X", -1000000, 1000000, 1, 0)
	modifier_translate_y = _labelled_spin(box, "Translate Y", -1000000, 1000000, 1, 0)
	modifier_scale = _labelled_spin(box, "Uniform scale", 0.05, 20, 0.05, 1)
	_button(box, "Transform selected modifier", func() -> void:
		transform_modifier(_reference(modifier_choice), Vector2(modifier_translate_x.value, modifier_translate_y.value), modifier_scale.value))
	_note(box, "Scale uses the bounds center or the stroke-point centroid and scales its radius. Transforms apply to the accepted modifier and can be undone; world-wide modifiers have no shape to transform.")

func _field_parameter_values() -> Dictionary:
	var result: Dictionary = {}
	for key: String in field_parameter_inputs:
		var input: Control = field_parameter_inputs[key]
		result[key] = input.get_selected_id() if input is OptionButton else (input as SpinBox).value
	return result

func _refresh_field_parameters(values: Dictionary) -> void:
	if field_parameter_box == null: return
	for child: Node in field_parameter_box.get_children():
		field_parameter_box.remove_child(child)
		child.queue_free()
	field_parameter_inputs.clear()
	var kind: String = field_kind.get_item_text(field_kind.selected)
	var spec: Dictionary = field_specs.get(kind, {})
	for parameter: Dictionary in spec.get("parameters", []):
		var key: String = str(parameter.name)
		if kind == "material" and key == "material":
			_label(field_parameter_box, "Material in fixed base terrain", 13)
			var picker: OptionButton = _material_options(field_parameter_box)
			picker.select(picker.get_item_index(int(values.get(key, parameter.default_value))))
			field_parameter_inputs[key] = picker
			continue
		var input: SpinBox = _labelled_spin(field_parameter_box, key, float(parameter.minimum), float(parameter.maximum), 1.0 if parameter.integer else 0.01, float(values.get(key, parameter.default_value)))
		field_parameter_inputs[key] = input
	field_warp_x.disabled = not bool(spec.get("supports_warp", false))
	field_warp_y.disabled = field_warp_x.disabled
	field_context.disabled = not bool(spec.get("requires_context", false))
	field_help.text = "%d input field(s) required. Output is normalized to 0..1; parameter defaults and limits come from the native catalogue." % int(spec.get("input_count", 0))
	match kind:
		"mix": field_help.text += " Input order: A, B, blend factor. Zero chooses A; one chooses B."
		"remap", "smoothstep": field_help.text += " Input values at low/high become zero/one, with clipping outside that interval."
		"band": field_help.text += " Select input values inside low..high; feather softens the inside edges."
		"circle": field_help.text += " x/y is the center; feather softens the inside edge and must not exceed radius."
		"box": field_help.text += " x/y is the minimum corner; feather must not exceed half the smaller dimension."
		"context": field_help.text += " Remap fixed base-terrain context from low..high. Depth is signed cells; slope is absolute surface gradient; route is shared-network membership."
		"cellular_gap": field_help.text += " Normalized second-minus-first feature distance; this is a gap proxy, not exact Voronoi edge distance."

func _load_field() -> void:
	var item: Dictionary = _entry("fields", _reference(field_choice))
	field_id.text = str(item.get("id", _entry_id("fields", "field")))
	_select_text(field_kind, str(item.get("kind", "constant")))
	var parts := PackedStringArray()
	for id: String in item.get("inputs", []): parts.append(id)
	field_inputs.text = ", ".join(parts)
	_select_reference(field_warp_x, str(item.get("warp_x", "")))
	_select_reference(field_warp_y, str(item.get("warp_y", "")))
	_select_text(field_context, str(item.get("context", "occupied")))
	_refresh_field_parameters(item.get("parameters", {}))

func apply_field() -> bool:
	if field_specs.is_empty():
		_set_error("Field authoring requires the current native extension.")
		return false
	var kind: String = field_kind.get_item_text(field_kind.selected)
	var inputs: Array = []
	for part: String in field_inputs.text.split(",", false): inputs.append(part.strip_edges())
	var item: Dictionary = {"id":field_id.text.strip_edges(), "kind":kind, "inputs":inputs, "parameters":_field_parameter_values()}
	if not field_warp_x.disabled:
		if not _reference(field_warp_x).is_empty(): item.warp_x = _reference(field_warp_x)
		if not _reference(field_warp_y).is_empty(): item.warp_y = _reference(field_warp_y)
	if not field_context.disabled: item.context = field_context.get_item_text(field_context.selected)
	if not upsert_entry("fields", item, _reference(field_choice)): return false
	_select_reference(field_choice, str(item.id))
	_load_field()
	return true

func _render_aggregate_rows() -> void:
	for child: Node in aggregate_rows.get_children():
		aggregate_rows.remove_child(child)
		child.queue_free()
	for index: int in range(aggregate_components.size()):
		var row := HBoxContainer.new()
		aggregate_rows.add_child(row)
		var component: Dictionary = aggregate_components[index]
		var material: OptionButton = _material_options(row)
		material.select(material.get_item_index(int(component.material)))
		material.item_selected.connect(func(_selected: int) -> void: component.material = material.get_selected_id())
		var weight: SpinBox = _spin(row, 0, 1000000, 0.1, float(component.get("weight", 1)))
		weight.value_changed.connect(func(value: float) -> void: component.weight = value)
		_button(row, "×", func() -> void: aggregate_components.remove_at(index); _render_aggregate_rows())

func _load_aggregate() -> void:
	var item: Dictionary = _entry("aggregates", _reference(aggregate_choice))
	aggregate_id.text = str(item.get("id", _entry_id("aggregates", "aggregate")))
	aggregate_grain.value = float(item.get("grain_size", 12 if item.is_empty() else 4))
	_select_reference(aggregate_variation, str(item.get("variation", "")))
	aggregate_components.clear()
	for component: Dictionary in item.get("components", [{"material":38,"weight":3.0},{"material":39,"weight":1.0}]):
		aggregate_components.append(component.duplicate(true))
	_render_aggregate_rows()

func apply_aggregate() -> bool:
	var item: Dictionary = {"id":aggregate_id.text.strip_edges(), "components":aggregate_components.duplicate(true), "grain_size":int(aggregate_grain.value)}
	if not _reference(aggregate_variation).is_empty(): item.variation = _reference(aggregate_variation)
	if not upsert_entry("aggregates", item, _reference(aggregate_choice)): return false
	_select_reference(aggregate_choice, str(item.id))
	_load_aggregate()
	return true

func _load_modifier() -> void:
	var item: Dictionary = _entry("modifiers", _reference(modifier_choice))
	modifier_id.text = str(item.get("id", _entry_id("modifiers", "modifier")))
	modifier_priority.value = float(item.get("priority", 10 if item.is_empty() else 0))
	modifier_strength.value = float(item.get("strength", 1))
	_select_reference(modifier_application, str(item.get("application", "")))
	_select_reference(modifier_exclusion, str(item.get("exclusion", "")))
	_select_text(modifier_context, str(item.get("context", "any")))
	modifier_context_material.select(modifier_context_material.get_item_index(int(item.get("context_material", 0))))
	modifier_bounds.text = JSON.stringify(item.bounds) if item.has("bounds") else ""
	modifier_action.select(0)
	modifier_json.text = JSON.stringify(item if not item.is_empty() else {"material":0}, "  ", true, true)

func _modifier_parameter_range() -> void:
	var spec: Array = PARAMETER_SPECS[modifier_parameter.get_item_text(modifier_parameter.selected)]
	for input: SpinBox in [modifier_low, modifier_high]:
		input.min_value = float(spec[1])
		input.max_value = float(spec[2])
		input.step = float(spec[3])
		input.value = float(spec[4])

func apply_modifier() -> bool:
	var parsed := JSON.new()
	if parsed.parse(modifier_json.text) != OK or not parsed.data is Dictionary:
		_set_error("Modifier draft must be a JSON object.")
		return false
	var item: Dictionary = parsed.data
	item.id = modifier_id.text.strip_edges()
	item.priority = int(modifier_priority.value)
	item.strength = modifier_strength.value
	_set_optional_reference(item, "application", modifier_application)
	_set_optional_reference(item, "exclusion", modifier_exclusion)
	item.context = modifier_context.get_item_text(modifier_context.selected)
	if item.context == "material": item.context_material = modifier_context_material.get_selected_id()
	else: item.erase("context_material")
	if modifier_bounds.text.strip_edges().is_empty(): item.erase("bounds")
	else:
		var bounds_json := JSON.new()
		if bounds_json.parse(modifier_bounds.text) != OK or not bounds_json.data is Array:
			_set_error("Modifier bounds must be [x,y,width,height].")
			return false
		item.bounds = bounds_json.data
		for key: String in ["points", "radius", "falloff"]: item.erase(key)
	if modifier_action.selected != 0:
		for key: String in ["material", "aggregate", "themes", "parameters", "mappings"]: item.erase(key)
		var parameter: String = modifier_parameter.get_item_text(modifier_parameter.selected)
		match modifier_action.selected:
			1: item.material = modifier_material.get_selected_id()
			2: item.aggregate = _reference(modifier_aggregate)
			3: item.parameters = {parameter:modifier_low.value}
			4: item.mappings = [{"parameter":parameter,"field":_reference(modifier_mapping_field),"low":modifier_low.value,"high":modifier_high.value}]
			5: item.themes = {"weights":{modifier_theme.get_item_text(modifier_theme.selected):1.0}}
	if not upsert_entry("modifiers", item, _reference(modifier_choice)): return false
	_select_reference(modifier_choice, str(item.id))
	_load_modifier()
	return true

func upsert_entry(section: String, item: Dictionary, previous_id: String = "") -> bool:
	if active_revision < 0: return false
	var recipe: Dictionary = active_recipe.duplicate(true)
	var entries: Array = recipe.get(section, []).duplicate(true)
	var replaced: bool = false
	for index: int in range(entries.size()):
		if str(entries[index].get("id", "")) == (previous_id if not previous_id.is_empty() else str(item.get("id", ""))):
			entries[index] = item.duplicate(true)
			replaced = true
			break
	if not replaced: entries.append(item.duplicate(true))
	recipe[section] = entries
	return apply_recipe(recipe)

func transform_modifier(id: String, translation: Vector2, scale_factor: float) -> bool:
	var item: Dictionary = _entry("modifiers", id)
	if item.is_empty() or not translation.is_finite() or not is_finite(scale_factor) or scale_factor <= 0:
		_set_error("Select an accepted modifier and a finite positive transform.")
		return false
	if item.has("bounds"):
		var bounds: Array = item.bounds
		var center_x: float = float(bounds[0]) + float(bounds[2]) * 0.5 + float(translation.x)
		var center_y: float = float(bounds[1]) + float(bounds[3]) * 0.5 + float(translation.y)
		var width: int = maxi(1, roundi(float(bounds[2]) * scale_factor))
		var height: int = maxi(1, roundi(float(bounds[3]) * scale_factor))
		item.bounds = [roundi(center_x - width * 0.5), roundi(center_y - height * 0.5), width, height]
	elif not item.get("points", []).is_empty():
		var center_x: float = 0
		var center_y: float = 0
		for point: Array in item.points:
			center_x += float(point[0])
			center_y += float(point[1])
		center_x /= item.points.size()
		center_y /= item.points.size()
		var moved: Array = []
		for point: Array in item.points:
			var x: float = float(point[0])
			var y: float = float(point[1])
			# Identity scale must also preserve small coordinates in a stroke
			# spanning very large distances; avoid cancellation through a centroid.
			if scale_factor != 1:
				x = center_x + (x - center_x) * scale_factor
				y = center_y + (y - center_y) * scale_factor
			moved.append([x + float(translation.x), y + float(translation.y)])
		item.points = moved
		item.radius = float(item.get("radius", 96)) * scale_factor
	else:
		_set_error("A world-wide modifier has no bounds or stroke to transform.")
		return false
	if not upsert_entry("modifiers", item, id): return false
	_select_reference(modifier_choice, id)
	_load_modifier()
	modifier_translate_x.value = 0
	modifier_translate_y.value = 0
	modifier_scale.value = 1
	return true

func delete_entry(section: String, id: String) -> bool:
	if id.is_empty() or active_revision < 0: return false
	var recipe: Dictionary = active_recipe.duplicate(true)
	var kept: Array = []
	for item: Dictionary in recipe.get(section, []):
		if str(item.get("id", "")) != id: kept.append(item.duplicate(true))
	recipe[section] = kept
	return apply_recipe(recipe)

func _entry(section: String, id: String) -> Dictionary:
	for item: Dictionary in active_recipe.get(section, []):
		if str(item.get("id", "")) == id: return item.duplicate(true)
	return {}

func _entry_id(section: String, prefix: String) -> String:
	var index: int = 1
	while not _entry(section, "%s-%d" % [prefix,index]).is_empty(): index += 1
	return "%s-%d" % [prefix,index]

func _refresh_extension_lists() -> void:
	var ids: Dictionary = {"fields":[], "aggregates":[], "modifiers":[]}
	for section: String in ids:
		for item: Dictionary in active_recipe.get(section, []): ids[section].append(str(item.id))
	for picker: OptionButton in [field_choice, field_warp_x, field_warp_y]:
		_set_references(picker, ids.fields)
	var mask_ids: Array = ids.fields.duplicate()
	for id: String in spatial_nodes:
		if str(spatial_nodes[id].type) == "normalized": mask_ids.append("spatial:" + id)
	for picker: OptionButton in [aggregate_variation, modifier_application, modifier_exclusion, modifier_mapping_field, brush_application, brush_exclusion, module_application, module_exclusion]:
		_set_references(picker, mask_ids)
	_set_references(spatial_choice, spatial_nodes.keys())
	for picker: OptionButton in [aggregate_choice, modifier_aggregate, brush_aggregate]: _set_references(picker, ids.aggregates)
	_set_references(modifier_choice, ids.modifiers)
	var module_ids: Array = []
	for item: Dictionary in active_recipe.get("modules", []): module_ids.append(str(item.id))
	_set_references(module_choice, module_ids)
	var channels: Array = []
	for section: String in ["fields", "modifiers", "modules"]:
		var prefix: String = {"fields":"field", "modifiers":"modifier", "modules":"module"}[section]
		for item: Dictionary in active_recipe.get(section, []): channels.append(prefix+":"+str(item.id))
	for id: String in spatial_nodes: channels.append("spatial:" + id)
	diagnostic_picker.clear()
	diagnostic_picker.add_item("Materials")
	diagnostic_picker.set_item_metadata(0, "")
	for channel: String in channels:
		diagnostic_picker.add_item(channel)
		diagnostic_picker.set_item_metadata(diagnostic_picker.item_count-1, channel)
	if not diagnostic_channel in channels: diagnostic_channel = ""
	_select_reference(diagnostic_picker, diagnostic_channel)
	_refresh_spatial_help()

func _pick_context_material() -> void:
	if _inspected_material < 0:
		_set_error("Inspect a ready cell first, then use its material as the context filter.")
		return
	_select_text(brush_context, "material")
	brush_context_material.select(brush_context_material.get_item_index(_inspected_material))

func _build_profile_dialog() -> void:
	profile_dialog = Window.new()
	profile_dialog.title = "World generation / schema 1, 2 and 3 profiles"
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
	var note: Label = _label(box, "Complete recipe: themes, scalar or typed spatial fields, reusable subgraphs, immutable geometry, aggregates, modifiers, routes and modules. Apply validates before replacing the accepted generation plan.", 14)
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
	_button(actions, "Restore accepted text", func() -> void: profile_editor.text = JSON.stringify(active_recipe, "  ", true, true))
	_button(actions, "Close", profile_dialog.hide)
	profile_status = _label(box, "", 14)
	profile_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _populate_catalogue(catalogue: Dictionary) -> void:
	var ids: Array[String] = []
	for item: Dictionary in catalogue.get("themes", []):
		ids.append(str(item.id))
	if not ids.is_empty():
		for picker: OptionButton in [base_theme, blend_theme, brush_theme, modifier_theme]:
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
	if catalogue.has("field_kinds"):
		var prior_kind: String = field_kind.get_item_text(field_kind.selected)
		var values: Dictionary = _field_parameter_values()
		field_specs.clear()
		field_kind.clear()
		for spec: Dictionary in catalogue.field_kinds:
			field_specs[str(spec.id)] = spec.duplicate(true)
			field_kind.add_item(str(spec.id))
		_select_text(field_kind, prior_kind)
		_refresh_field_parameters(values)
	spatial_specs.clear()
	var prior_spatial_kind: String = spatial_kind.get_item_text(spatial_kind.selected)
	spatial_kind.clear()
	for spec: Dictionary in catalogue.get("spatial_kinds", []):
		spatial_specs[str(spec.id)] = spec.duplicate(true)
		spatial_kind.add_item(str(spec.id))
	if spatial_kind.item_count > 0: _select_text(spatial_kind, prior_spatial_kind)
	spatial_nodes.clear()
	for info: Dictionary in catalogue.get("spatial_nodes", []): spatial_nodes[str(info.id)] = info.duplicate(true)
	_refresh_extension_lists()

func apply_recipe(recipe: Dictionary, record_undo: bool = true) -> bool:
	if generator == null:
		_set_error("Native generation is unavailable; the profile cannot be applied.")
		return false
	if _interactive_edit:
		return request_recipe(recipe, record_undo)
	cancel_pending_edit()
	var candidate: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var size: int = int(recipe.get("chunk_size", 128))
	if size <= 0: size = 128 # Native parsing owns the diagnostic for invalid size.
	var coordinate := Vector2i(floori(camera_origin.x / size), floori(camera_origin.y / size))
	var prepared: Dictionary = _prepare_candidate(candidate, recipe.duplicate(true), coordinate)
	if not prepared.get("ok", false):
		_set_error(str(prepared.get("error", "Candidate preparation failed.")))
		return false
	return _commit_prepared(candidate, prepared, record_undo)

static func _prepare_candidate(candidate: Variant, recipe: Dictionary, coordinate: Vector2i) -> Dictionary:
	# This function runs either on the caller or one exclusive GDScript worker.
	# It never accesses a scene node, live World, shared app state or native pool.
	var started: int = Time.get_ticks_usec()
	if JSON.stringify(recipe, "", true, true).to_utf8_buffer().size() > MAX_PROFILE_BYTES:
		return {"ok":false, "error":"Profile exceeds the 1 MiB authoring limit."}
	var checked: Dictionary = candidate.configure(recipe)
	if not bool(checked.get("ok", false)): return checked
	var sampled: Dictionary = candidate.generate_chunk(coordinate)
	if not bool(sampled.get("ok", false)):
		return {"ok":false, "error":"Candidate work budget failed before commit: " + str(sampled.get("error", "unavailable"))}
	if recipe.has("semantic_planes"):
		var candidate_planes: Dictionary = candidate.get_plane_plan()
		var bounds: Rect2i = candidate_planes.get("bounds", Rect2i())
		var patch := Rect2i(bounds.position, Vector2i(mini(bounds.size.x, 16), mini(bounds.size.y, 16)))
		var sampled_planes: Dictionary = candidate.generate_plane_region(patch)
		if not bool(sampled_planes.get("ok", false)):
			return {"ok":false, "error":"Candidate plane budget failed before commit: " + str(sampled_planes.get("error", "unavailable"))}
	checked["prepare_usec"] = Time.get_ticks_usec() - started
	return checked

func _commit_prepared(candidate: Variant, prepared: Dictionary, record_undo: bool = true) -> bool:
	var started: int = Time.get_ticks_usec()
	var checked: Dictionary
	if generator.has_method(&"adopt_configuration"):
		checked = generator.adopt_configuration(candidate, maxi(active_revision, 0))
		if prepared.has("route_validation"): checked["route_validation"] = prepared.route_validation.duplicate(true)
	else:
		# Old runtimes may still open the retained GEN-001 surface while new
		# diagnostics clearly refuse. Source-matched GEN-007 uses adoption.
		checked = generator.configure(candidate.get_configuration())
	last_prepare_usec = int(prepared.get("prepare_usec", 0))
	last_adopt_usec = Time.get_ticks_usec() - started
	if not bool(checked.get("ok", false)):
		_set_error(str(checked.get("error", "Native profile validation failed.")))
		return false
	if record_undo and active_revision >= 0:
		_redo.clear()
		_undo.append(active_recipe.duplicate(true))
		if _undo.size() > MAX_UNDO:
			_undo.pop_front()
	active_recipe = generator.get_configuration().duplicate(true)
	active_revision = int(checked.revision)
	active_fingerprint = str(checked.fingerprint)
	semantic_feature_count = 0
	semantic_route_report = checked.get("route_validation", {}).duplicate(true)
	if active_recipe.has("grammar"):
		var plan: Dictionary = generator.get_semantic_plan()
		semantic_feature_count = plan.get("features", []).size()
	_view_token += 1
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
	tools2.on_recipe_accepted()
	_sync_controls()
	_sync_preview()
	_update_requests()
	profile_editor.text = JSON.stringify(active_recipe, "  ", true, true)
	spatial_editor.text = JSON.stringify(active_recipe.get("spatial", {"nodes":[]}), "  ", true, true)
	profile_status.text = "Accepted revision %d · %s" % [active_revision, active_fingerprint]
	_refresh_status()
	return true

func request_recipe(recipe: Dictionary, record_undo: bool = true, history_action: String = "") -> bool:
	if JSON.stringify(recipe, "", true, true).to_utf8_buffer().size() > MAX_PROFILE_BYTES:
		_set_error("Profile exceeds the 1 MiB authoring limit.")
		return false
	_edit_serial += 1
	_pending_edit = {"serial":_edit_serial, "recipe":recipe.duplicate(true), "record_undo":record_undo, "history":history_action, "base_revision":active_revision, "before":active_recipe.duplicate(true)}
	_set_status("Validating a candidate on its private generation owner; the accepted preview remains available…")
	service_editor_transaction()
	return true

func cancel_pending_edit() -> void:
	var had_pending: bool = _edit_thread != null or not _pending_edit.is_empty()
	_edit_serial += 1
	_pending_edit.clear()
	# Cancellation retires identity immediately. At most one bounded native
	# preparation may finish in the background; its result cannot be admitted.
	if had_pending:
		last_error = ""
		_set_status("Edit cancelled; accepted recipe and preview retained.")

func service_editor_transaction() -> void:
	if _edit_thread != null:
		if _edit_thread.is_alive(): return
		var prepared: Dictionary = _edit_thread.wait_to_finish()
		_edit_thread = null
		var job: Dictionary = _active_edit
		_active_edit = {}
		if int(job.get("serial", -1)) == _edit_serial and int(job.get("base_revision", -1)) == active_revision:
			if not prepared.get("ok", false):
				_set_error(str(prepared.get("error", "Candidate validation failed.")))
			elif _commit_prepared(job.owner, prepared, bool(job.record_undo)):
				if str(job.history) == "undo":
					_undo.pop_back()
					_redo.append(job.before)
				elif str(job.history) == "redo":
					_redo.pop_back()
					_undo.append(job.before)
				while _undo.size() > MAX_UNDO: _undo.pop_front()
				while _redo.size() > MAX_UNDO: _redo.pop_front()
		_refresh_status()
	if _pending_edit.is_empty(): return
	_active_edit = _pending_edit
	_pending_edit = {}
	if int(_active_edit.base_revision) != active_revision:
		_active_edit.clear()
		return
	var candidate: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	_active_edit.owner = candidate
	var recipe: Dictionary = _active_edit.recipe
	var size: int = maxi(int(recipe.get("chunk_size", 128)), 1)
	var coordinate := Vector2i(floori(camera_origin.x / size), floori(camera_origin.y / size))
	_edit_thread = Thread.new()
	var error: Error = _edit_thread.start(_prepare_candidate.bind(candidate, recipe, coordinate))
	if error != OK:
		_edit_thread = null
		_active_edit.clear()
		_set_error("Could not start the private recipe validator: " + error_string(error))

func _exit_tree() -> void:
	cancel_pending_edit()
	if _edit_thread != null:
		_edit_thread.wait_to_finish()
		_edit_thread = null
	_active_edit.clear()
	if tools2 != null: tools2.shutdown()

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
	var chunk_text: String = str(int(active_recipe.get("chunk_size", 128)))
	var known_chunk: bool = false
	for index: int in range(chunk_picker.item_count):
		known_chunk = known_chunk or chunk_picker.get_item_text(index) == chunk_text
	if not known_chunk:
		chunk_picker.add_item(chunk_text)
	_select_text(chunk_picker, chunk_text)
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
		6, 7, 8, 9, 10:
			var modifier: Dictionary = {"id":id, "priority":priority, "points":packed_points, "radius":radius_input.value, "falloff":falloff_input.value, "strength":strength_input.value, "context":brush_context.get_item_text(brush_context.selected)}
			_set_optional_reference(modifier, "application", brush_application)
			_set_optional_reference(modifier, "exclusion", brush_exclusion)
			if modifier.context == "material": modifier.context_material = brush_context_material.get_selected_id()
			match tool_picker.selected:
				6: modifier.material = 0
				7: modifier.material = material_picker.get_selected_id()
				8:
					if _reference(brush_aggregate).is_empty():
						_set_error("Select an accepted aggregate before painting it.")
						return
					modifier.aggregate = _reference(brush_aggregate)
				9: modifier.parameters = {brush_parameter.get_item_text(brush_parameter.selected):brush_value.value}
				10: modifier.themes = {"weights":{brush_theme.get_item_text(brush_theme.selected):1.0}}
			_append_mark(recipe, "modifiers", modifier)
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

func _load_module_instance() -> void:
	var item: Dictionary = _entry("modules", _reference(module_choice))
	if item.is_empty(): return
	_select_text(module_picker, str(item.module))
	_refresh_module_editor()
	module_parameters.text = JSON.stringify(item.get("parameters", {}), "  ", true, true)
	_select_reference(module_application, str(item.get("application", "")))
	_select_reference(module_exclusion, str(item.get("exclusion", "")))
	module_strength.value = float(item.get("strength", 1))

func apply_module_instance() -> bool:
	var id: String = _reference(module_choice)
	var item: Dictionary = _entry("modules", id)
	if item.is_empty():
		_set_error("Select an accepted module instance to edit its parameters and masks.")
		return false
	var parsed := JSON.new()
	if parsed.parse(module_parameters.text) != OK or not parsed.data is Dictionary:
		_set_error("Module parameters must be a JSON object of numeric values.")
		return false
	item.module = module_picker.get_item_text(module_picker.selected)
	item.parameters = parsed.data
	_set_optional_reference(item, "application", module_application)
	_set_optional_reference(item, "exclusion", module_exclusion)
	item.strength = module_strength.value
	if not upsert_entry("modules", item, id): return false
	_select_reference(module_choice, id)
	_load_module_instance()
	return true

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
	var instance: Dictionary = {"id": id, "module": module_id, "version": 1, "bounds": bounds, "parameters": parameters, "after": [], "priority": priority}
	_set_optional_reference(instance, "application", module_application)
	_set_optional_reference(instance, "exclusion", module_exclusion)
	if module_strength.value != 1: instance.strength = module_strength.value
	return instance

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
	for field: String in ["strokes", "paths", "overrides", "modules", "modifiers"]:
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
	if _interactive_edit:
		request_recipe(_undo[-1], false, "undo")
		return
	var previous: Dictionary = active_recipe.duplicate(true)
	if apply_recipe(_undo[-1], false):
		_undo.pop_back()
		_redo.append(previous)
		if _redo.size() > MAX_UNDO: _redo.pop_front()

func redo_authoring() -> void:
	if _redo.is_empty():
		_set_status("No later accepted profile in this workbench session.")
		return
	if _interactive_edit:
		request_recipe(_redo[-1], false, "redo")
		return
	var previous: Dictionary = active_recipe.duplicate(true)
	if apply_recipe(_redo[-1], false):
		_redo.pop_back()
		_undo.append(previous)
		if _undo.size() > MAX_UNDO: _undo.pop_front()

func clear_authoring() -> void:
	if active_revision < 0:
		return
	var recipe: Dictionary = active_recipe.duplicate(true)
	for field: String in ["strokes", "paths", "overrides", "modules", "modifiers"]:
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
	service_editor_transaction()
	service_generation()
	tools2.service_auxiliary()

func select_diagnostic(channel: String) -> bool:
	var found: bool = false
	for index: int in range(diagnostic_picker.item_count):
		found = found or str(diagnostic_picker.get_item_metadata(index)) == channel
	if not found:
		_set_error("Select an accepted diagnostic output before inspecting it.")
		return false
	if channel == diagnostic_channel: return true
	diagnostic_channel = channel
	reset_view_jobs()
	return true

func reset_view_jobs() -> void:
	_view_token += 1
	tools2.retire_trace("The plane, stage or diagnostic changed. Click a ready cell to inspect this view.")
	pointer_label.text = "Click a ready cell to inspect this view."
	pointer_label.tooltip_text = ""
	_has_active_chunk = false
	_job_completed = 0
	_job_compute_us = 0
	cache.clear()
	_cache_order.clear()
	_blocked_chunks.clear()
	pending_chunks.clear()
	last_packet.clear()
	last_error = ""
	_inspected_material = -1
	_select_reference(diagnostic_picker, diagnostic_channel)
	_sync_preview()
	_update_requests()
	_refresh_status()

func service_generation() -> void:
	if generator == null or active_revision < 0:
		return
	if not _has_active_chunk:
		if pending_chunks.is_empty():
			return
		_active_chunk = pending_chunks.pop_front()
		_active_view_token = _view_token
		var started: Dictionary = tools2.begin_preview(_active_chunk)
		if not bool(started.get("ok", false)):
			_blocked_chunks[_active_chunk] = true
			_set_error(str(started.get("error", "Chunk request rejected.")))
			return
		_has_active_chunk = true
		_job_completed = 0
		_job_compute_us = 0
	var start_us: int = Time.get_ticks_usec()
	var packet: Dictionary = tools2.advance_preview(CELL_BUDGET)
	_job_compute_us += Time.get_ticks_usec() - start_us
	_job_completed = int(packet.get("completed_cells", 0))
	var state: String = str(packet.get("state", "failed"))
	if not bool(packet.get("ok", false)) or state in ["failed", "cancelled"]:
		_has_active_chunk = false
		_blocked_chunks[_active_chunk] = true
		_set_error(str(packet.get("error", "Native chunk generation failed.")))
	elif state == "ready":
		_has_active_chunk = false
		packet = tools2.normalize_plane_packet(packet, _active_chunk)
		packet["compute_usec"] = _job_compute_us
		if not accept_chunk(packet, _active_chunk, _active_view_token):
			_blocked_chunks[_active_chunk] = true
		_update_requests()
	_refresh_status()

static func _canonical_signed_integer(text: String) -> bool:
	return text.is_valid_int() and str(text.to_int()) == text

static func _canonical_hex_identity(text: String) -> bool:
	if text.length() != 16: return false
	for index: int in range(16):
		if not text.substr(index, 1) in "0123456789abcdef": return false
	return true

func _typed_diagnostic_error(packet: Dictionary, count: int) -> String:
	var id: String = diagnostic_channel.substr(8)
	if not spatial_nodes.has(id): return "Typed output is not part of the accepted graph."
	if not packet.get("diagnostic_info") is Dictionary: return "Typed diagnostic metadata is missing."
	var info: Dictionary = packet.diagnostic_info
	var expected: Dictionary = spatial_nodes[id]
	for key: String in expected:
		if key != "id" and info.get(key) != expected[key]: return "Typed diagnostic metadata differs from the accepted output: " + key
	if not packet.get("diagnostics") is PackedFloat32Array or not packet.diagnostics.is_empty(): return "Typed diagnostics cannot contain a legacy normalized payload."
	if not packet.get("diagnostic_values") is PackedFloat64Array or not packet.get("diagnostic_categories") is PackedStringArray:
		return "Typed diagnostics require copied double and exact-category arrays."
	var values: PackedFloat64Array = packet.diagnostic_values
	var categories: PackedStringArray = packet.diagnostic_categories
	var type: String = str(info.type)
	if type == "category":
		if not values.is_empty() or categories.size() != count * 3: return "Exact category diagnostic shape is invalid."
		for index: int in range(count):
			if not _canonical_signed_integer(categories[index * 3]) or not _canonical_signed_integer(categories[index * 3 + 1]) or not _canonical_hex_identity(categories[index * 3 + 2]):
				return "Category diagnostic address is not exact canonical integer text."
		return ""
	var components: int = 2 if type == "vector2" else 1
	if values.size() != count * components or not categories.is_empty(): return "Typed numeric diagnostic shape is invalid."
	for value: float in values:
		if not is_finite(value): return "Typed diagnostic contains a nonfinite value."
		if value < float(info.minimum) or value > float(info.maximum): return "Typed diagnostic exceeds its declared component bounds."
		if type == "normalized" and (value < 0 or value > 1): return "Normalized typed diagnostic is outside 0..1."
		if type == "boolean" and value != 0 and value != 1: return "Boolean typed diagnostic is not exactly zero or one."
		if type == "distance" and value < 0: return "Unsigned distance diagnostic is negative."
	return ""

# These are display-only mappings. Raw doubles and categorical addresses remain
# unchanged in the copied packet and are shown by point inspection.
static func spatial_diagnostic_color(packet: Dictionary, index: int) -> Color:
	var type: String = str(packet.diagnostic_info.type)
	if type == "category":
		var address: String = "%s:%s:%s" % [packet.diagnostic_categories[index * 3 + 2], packet.diagnostic_categories[index * 3], packet.diagnostic_categories[index * 3 + 1]]
		# Mix every address bit before choosing a display hue, so neighbouring
		# integer identities do not collapse to nearly indistinguishable colours.
		var colour_key: int = address.hash() & 0xffffffff
		for _round: int in range(2): colour_key = (((colour_key >> 16) ^ colour_key) * 0x45d9f3b) & 0xffffffff
		colour_key = (colour_key >> 16) ^ colour_key
		return Color.from_hsv(float(colour_key & 0xffffff) / 16777216.0, 0.65, 0.92)
	var values: PackedFloat64Array = packet.diagnostic_values
	if type == "vector2":
		# Keep double components out of Godot's single-precision Vector2 carrier.
		var x: float = values[index * 2]
		var y: float = values[index * 2 + 1]
		var hue: float = fposmod(atan2(y, x) / TAU, 1.0)
		var magnitude: float = sqrt(x * x + y * y)
		var brightness: float = 0.2 + 0.8 * (1.0 - exp(-magnitude / 16.0))
		return Color.from_hsv(hue, 0.75, brightness)
	var value: float = values[index]
	if type in ["normalized", "boolean"]: return Color(value, value, value, 1)
	if type == "distance":
		var level: float = 1.0 - exp(-value / 24.0)
		return Color(level, level, level, 1)
	var intensity: float = 2.0 * atan(absf(value) / 16.0) / PI
	return Color(0.15, 0.18, 0.22).lerp(Color(0.15, 0.65, 1.0) if value < 0 else Color(1.0, 0.55, 0.16), intensity)

static func spatial_diagnostic_text(packet: Dictionary, index: int) -> String:
	var info: Dictionary = packet.diagnostic_info
	var type: String = str(info.type)
	if type == "category": return "category (%s, %s; %s)" % [packet.diagnostic_categories[index * 3], packet.diagnostic_categories[index * 3 + 1], packet.diagnostic_categories[index * 3 + 2]]
	if type == "boolean": return "true" if packet.diagnostic_values[index] == 1 else "false"
	if type == "vector2": return "(%s, %s) cells^%d" % [str(packet.diagnostic_values[index * 2]), str(packet.diagnostic_values[index * 2 + 1]), int(info.unit_power)]
	return "%s cells^%d (%s)" % [str(packet.diagnostic_values[index]), int(info.unit_power), type]

func accept_chunk(packet: Dictionary, expected_coordinate: Variant = null, expected_view_token: int = -1) -> bool:
	if not bool(packet.get("ok", false)) or str(packet.get("state", "ready")) != "ready":
		_set_error("Only completed native chunks can enter the preview.")
		return false
	if int(packet.get("revision", -1)) != active_revision or str(packet.get("fingerprint", "")) != active_fingerprint:
		_set_error("Discarded a chunk from an older generation profile.")
		return false
	if expected_view_token >= 0 and expected_view_token != _view_token:
		_set_error("Discarded a chunk from an older inspection request.")
		return false
	var expected_channel: String = diagnostic_channel
	if expected_channel.is_empty() and tools2.selected_stage != "final" and not tools2.uses_plane_preview(): expected_channel = "stage:" + tools2.selected_stage
	if str(packet.get("diagnostic", "")) != expected_channel:
		_set_error("Native diagnostic channel does not match the current inspection.")
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
	if packet.has("stage_cells") and tools2.selected_stage == "final":
		_set_error("Unrequested stage cells cannot replace the final preview.")
		return false
	if packet.has("stage") and str(packet.stage) != tools2.selected_stage:
		_set_error("Native stage does not match the selected intermediate view.")
		return false
	var shown: PackedByteArray = packet.get("stage_cells", cells)
	if not shown is PackedByteArray or shown.size() != cells.size():
		_set_error("Native generation stage has an invalid material extent.")
		return false
	for material: int in shown:
		if material == 10 or material >= Palette.MATERIAL_COUNT:
			_set_error("Native stage contains an invalid material ID.")
			return false
	var diagnostics := PackedFloat32Array()
	var typed: bool = diagnostic_channel.begins_with("spatial:")
	if typed:
		var error: String = _typed_diagnostic_error(packet, cells.size())
		if not error.is_empty():
			_set_error(error)
			return false
	elif packet.has("diagnostic_info") or packet.has("diagnostic_values") or packet.has("diagnostic_categories"):
		_set_error("Unrequested typed payload cannot enter the material or scalar preview.")
		return false
	elif not diagnostic_channel.is_empty():
		if not packet.get("diagnostics") is PackedFloat32Array:
			_set_error("Native diagnostic values are missing.")
			return false
		diagnostics = packet.diagnostics
		if diagnostics.size() != cells.size():
			_set_error("Native diagnostic shape does not match its material chunk.")
			return false
		for value: float in diagnostics:
			if not is_finite(value) or value < 0 or value > 1:
				_set_error("Native diagnostic contains a non-normalized value.")
				return false
	elif packet.has("diagnostics") and (not packet.diagnostics is PackedFloat32Array or not packet.diagnostics.is_empty()):
		_set_error("Unrequested native diagnostic values cannot enter the material preview.")
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
	copied["texture"] = tools2.display_texture(packet)
	if copied.texture == null:
		_set_error("Native plane/stage display payload is malformed.")
		return false
	if typed or not diagnostics.is_empty():
		var pixels := PackedByteArray()
		pixels.resize(cells.size() * 4)
		for index: int in range(cells.size()):
			if typed:
				var color: Color = spatial_diagnostic_color(packet, index)
				pixels[index * 4] = color.r8
				pixels[index * 4 + 1] = color.g8
				pixels[index * 4 + 2] = color.b8
			else:
				var level: int = roundi(diagnostics[index] * 255.0)
				for component: int in range(3): pixels[index * 4 + component] = level
			pixels[index * 4 + 3] = 255
		copied["diagnostic_texture"] = ImageTexture.create_from_image(Image.create_from_data(chunk_size, chunk_size, false, Image.FORMAT_RGBA8, pixels))
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
	if diagnostic_legend != null:
		diagnostic_legend.text = "Material colours" if diagnostic_channel.is_empty() else "0 dark · 1 bright"
		if diagnostic_channel.begins_with("spatial:"):
			match str(spatial_nodes.get(diagnostic_channel.substr(8), {}).get("type", "")):
				"vector2": diagnostic_legend.text = "Hue: direction · light: length"
				"category": diagnostic_legend.text = "Colour: exact category"
				"scalar", "signed_distance": diagnostic_legend.text = "Blue: negative · orange: positive"
				"distance": diagnostic_legend.text = "Dark: near · light: far"
	preview.camera_origin = camera_origin
	preview.view_size = view_size
	preview.chunk_size = int(active_recipe.get("chunk_size", 128))
	preview.chunks = cache
	preview.recipe = active_recipe
	preview.diagnostic_channel = diagnostic_channel
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
	module_parameters.text = JSON.stringify(MODULE_DEFAULTS.get(id, {}), "  ", true, true)
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
	_inspected_material = -1
	if cache.has(coordinate):
		var index: int = (y - coordinate.y * chunk_size) * chunk_size + x - coordinate.x * chunk_size
		var id: int = int(cache[coordinate].cells[index])
		text += " · %d / %s" % [id, _material_label(id)]
		_inspected_material = id
		if diagnostic_channel.begins_with("spatial:") and cache[coordinate].has("diagnostic_info"):
			text += " · %s = %s" % [diagnostic_channel, spatial_diagnostic_text(cache[coordinate], index)]
		elif not diagnostic_channel.is_empty() and cache[coordinate].has("diagnostics"):
			text += " · %s = %.5f" % [diagnostic_channel, float(cache[coordinate].diagnostics[index])]
	var provenance: Dictionary = tools2.inspect_point(Vector2i(x, y))
	if provenance.get("ok", false):
		text += " · native replay · accepted revision %d" % active_revision
		pointer_label.tooltip_text = "Full bounded provenance is in Why is this here?"
	pointer_label.text = text

func _refresh_status() -> void:
	if active_revision < 0:
		return
	identity_label.text = "%s · seed %s · revision %d · %s" % [str(active_recipe.get("candidate", "strata")), str(int(active_recipe.get("seed", 1))), active_revision, active_fingerprint]
	marks_label.text = "%d theme/parameter strokes · %d routes · %d hard overrides · %d modules" % [active_recipe.get("strokes", []).size(), active_recipe.get("paths", []).size(), active_recipe.get("overrides", []).size(), active_recipe.get("modules", []).size()]
	marks_label.text += " · %d fields · %d aggregates · %d modifiers" % [active_recipe.get("fields", []).size(), active_recipe.get("aggregates", []).size(), active_recipe.get("modifiers", []).size()]
	if not spatial_nodes.is_empty(): marks_label.text += " · %d typed nodes" % spatial_nodes.size()
	if semantic_feature_count > 0: marks_label.text += " · %d semantic features" % semantic_feature_count
	if not last_error.is_empty():
		status_label.text = last_error
		return
	var chunk_size: int = int(active_recipe.get("chunk_size", 128))
	var text: String = "%d/%d cached chunks · %d queued" % [cache.size(), MAX_CACHE_CHUNKS, pending_chunks.size()]
	if _has_active_chunk:
		text += " · generating %d, %d: %d / %d cells" % [_active_chunk.x, _active_chunk.y, _job_completed, chunk_size * chunk_size]
	elif pending_chunks.is_empty():
		text += " · visible region ready"
	if not _pending_edit.is_empty() or (_edit_thread != null and int(_active_edit.get("serial", -1)) == _edit_serial):
		text += " · validating candidate (accepted preview retained)"
	elif _edit_thread != null:
		text += " · cancelled edit retiring privately (accepted preview retained)"
	if not last_packet.is_empty():
		text += " · last chunk %s · %s operations · %.2f ms native work" % [str(last_packet.get("hash", "")), str(last_packet.get("operations", 0)), float(last_packet.get("compute_usec", 0)) / 1000.0]
	if not semantic_route_report.is_empty() and not semantic_route_report.get("passed", false):
		text += " · base-generator route clearance conflict (before semantic-plane projection): inspect validate_routes()"
	if not semantic_route_report.get("supports_passed", true):
		text += " · base-generator support contact conflict: inspect material contributions"
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

func _choose_load_profile(examples: bool = false) -> void:
	var dialog := FileDialog.new()
	dialog.title = "Load generation profile"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Generation profile"])
	if examples:
		var directory: String = ProjectSettings.globalize_path("res://../examples/worldgen")
		if DirAccess.dir_exists_absolute(directory): dialog.current_dir = directory
		profile_status.text = "Choose hilbert-seams.json, weathered-aggregate.json or sidechained-arcology.json from examples/worldgen, then Apply JSON."
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
	file.store_string(JSON.stringify(active_recipe, "  ", true, true) + "\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		_set_error("Profile write failed: %s" % error_string(error))
		return false
	profile_status.text = "Saved accepted revision %d to %s." % [active_revision, path.get_file()]
	return true

static func _material_label(id: int) -> String:
	return MATERIAL_LABELS[id] if id >= 0 and id < MATERIAL_LABELS.size() else "invalid material " + str(id)

func _note(parent: Node, text: String) -> Label:
	var result: Label = _label(parent, text, 13)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func _text_input(parent: Node, label: String, initial: String) -> LineEdit:
	_label(parent, label, 13)
	var input := LineEdit.new()
	input.text = initial
	parent.add_child(input)
	return input

func _material_options(parent: Node) -> OptionButton:
	var picker: OptionButton = _options(parent, [])
	for id: int in range(Palette.MATERIAL_COUNT):
		if id != 10: picker.add_item("%02d / %s" % [id, _material_label(id)], id)
	return picker

func _field_reference(parent: Node, label: String) -> OptionButton:
	_label(parent, label, 13)
	var picker: OptionButton = _options(parent, ["— none / new —"])
	picker.set_item_metadata(0, "")
	return picker

static func _reference(picker: OptionButton) -> String:
	if picker == null or picker.selected < 0: return ""
	return str(picker.get_item_metadata(picker.selected))

static func _select_reference(picker: OptionButton, value: String) -> void:
	for index: int in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == value:
			picker.select(index)
			return
	picker.select(0)

static func _set_optional_reference(item: Dictionary, key: String, picker: OptionButton) -> void:
	var value: String = _reference(picker)
	if value.is_empty(): item.erase(key)
	else: item[key] = value

static func _set_references(picker: OptionButton, ids: Array) -> void:
	var prior: String = _reference(picker)
	picker.clear()
	picker.add_item("— none / new —")
	picker.set_item_metadata(0, "")
	for id: String in ids:
		picker.add_item(id)
		picker.set_item_metadata(picker.item_count-1, id)
	_select_reference(picker, prior)

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
	button.pressed.connect(func() -> void:
		_interactive_edit = true
		action.call()
		_interactive_edit = false)
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
