extends VBoxContainer

const Setup = preload("res://scripts/workbench_setup.gd")
const WaterComparisonScenes = preload("res://scripts/workbench_water_comparison_scenes.gd")
const GeneratedMaps = preload("res://scripts/workbench_generated_map.gd")
const MaterialBaseline = preload("res://scripts/workbench_material_baseline.gd")
const PaintEditor = preload("res://scripts/workbench_paint_editor_controller.gd")
const ObjectShardM4Port = preload("res://scripts/object_shard_m4_workbench_port.gd")
const ObjectShardScenes = preload("res://scripts/object_shard_workbench_scenes.gd")
const ObjectShardFootprint = preload("res://scripts/object_shard_live_edit_footprint.gd")
const ObjectShardEditDiagnostics = preload("res://scripts/object_shard_live_edit_diagnostics.gd")
const ArtBatchPanel = preload("res://scripts/art_batch_panel.gd")
const Fleet = Setup.Fleet
const ActorCatalog = Setup.ActorCatalog
const ActorInteraction = preload("res://scripts/workbench_actor_interaction.gd")
const AmbientAuthoring = preload("res://scripts/ambient/ambient_authoring.gd")
const RESPONSE_LABELS := ["LA-SA · selective arrivals","LA · all events","LA · events off","RFT · fixed 20"]
const ZOOMS := [Vector2i(240,135),Vector2i(480,270),Vector2i(960,540)]
const TOOL_NAMES := ["Paint","Place body","Select body","Move selected","Place source","Grab physical part","Place / rotate (paused)"]
enum { CUT_MOVING_TOOL = 7, IGNITE_MOVING_TOOL, SETTLE_MOVING_TOOL,
	STRUCTURAL_ERASER_TOOL, SLICE_TOOL, WEATHERING_TOOL, DRILL_TOOL }
const MOVING_EDIT_TOOLS := [CUT_MOVING_TOOL, IGNITE_MOVING_TOOL, STRUCTURAL_ERASER_TOOL, SLICE_TOOL, WEATHERING_TOOL, DRILL_TOOL]
const MOVING_TOOLS := [CUT_MOVING_TOOL, IGNITE_MOVING_TOOL, SETTLE_MOVING_TOOL, STRUCTURAL_ERASER_TOOL, SLICE_TOOL, WEATHERING_TOOL, DRILL_TOOL]
const STRUCTURAL_TOOL_NAMES := ["Precision cut", "Area ignition", "Settle into canvas", "Structural eraser", "Slice", "Weathering", "Drill"]
var actor_interaction: RefCounted
var _pending_sandbox_demo := ""
var _generated_dialog := preload("res://scripts/workbench_generator_dialog.gd").new()
var _materials_lab_window: Window
var _materials_lab_panel: Control
var material_audition: RefCounted
var batch_lab: Window
var architecture_lab: Window
# These copied bytes are only a reconstructible authored starting baseline.
# The sole live World remains owned by the existing native simulation worker.
var _generated_active: Dictionary = {}
var _pending_generated: Dictionary = {}
var _pending_retain_generated := false
var _pending_water_comparison := ""
var _pending_material_demo := ""
var _pending_staged_liquid_selection: Dictionary = {}
var _material_baseline: Dictionary = {}
var _pending_material_baseline: Dictionary = {}
var _flatten_request: Dictionary = {}
var _flatten_status: Dictionary = {"status":"idle"}
var _flatten_button: Button
var _flatten_confirmation := ConfirmationDialog.new()
var art_batches: Window
# A small session association is read once without constructing Art or opening
# any traffic archive. It binds native completions through profile outages.
var _art_history_session: Dictionary = {}
var art_history_persistence: Dictionary = {}
var host: Control
# Experimental same-World interface only. Default-off and never creates a World.
var object_shard_m4_port = ObjectShardM4Port.new()
var _object_shard_window: Window
var _object_shard_export_label: Label
var _object_shard_export_folder: Button
var _object_shard_recording: CheckButton
var _object_shard_scene: String = ""
var _pending_object_shard_scene: String = ""
var _object_shard_seen_result: Vector2i = Vector2i.ZERO
var _object_shard_pointer_tool: int = -1
var _object_shard_pointer_local: Vector2 = Vector2(-1,-1)
var _object_shard_pointer_attempt: Array = []
var _object_shard_tool_mode: int = -1
var _object_shard_activity_until_ms: int = 0
var _object_shard_edit_probe = ObjectShardEditDiagnostics.new()
var _object_shard_diagnostic_identity: Dictionary = {}
var _object_shard_pointer_source_tool: int = -1
var _object_shard_pointer_capture_usec: int = 0
var _object_shard_consumed_capture_usec: int = 0
var _object_shard_stroke_id: int = 0
var _object_shard_sample_id: int = 0
var _object_shard_pointer_start: Vector2i = Vector2i(-1,-1)
var _object_shard_pointer_previous: Vector2i = Vector2i(-1,-1)
var _object_shard_pointer_camera: Array = []
var _object_shard_segment: Dictionary = {}
var _object_shard_slice_committing: bool = false
var _object_shard_slice_commit_usec: int = 0
var _object_shard_wait_since: int = 0
var _object_shard_wait_reason: String = ""
var _object_shard_last_admission_usec: int = 0
var _object_shard_last_presented_action: int = 0
var _object_shard_last_transport_hold: String = ""
var _erosion_density := SpinBox.new()
var _erosion_seed := SpinBox.new()
var _erosion_material_only := CheckButton.new()
var _erosion_pass: int = 0
var applied: Dictionary = {}
var pilot_slot := -1
var _pilot_instance_id := 0
var _pending_pilot_id := -1
var _pilot_returns: Dictionary = {}
var _roster_models: Array[String] = []
var _model_ids: Array[String] = []
var _actor_panel: Window
var _actor_configuration_button: Button
var _ambient_profile_editor: Window
var _ambient_overlay: Control
var _ambient_overlay_id := 0
var _pending_ambient_example := ""
var _pending_actor_workshop := false
var fire_enabled := false
var step_requested := false
var step_serial := 0
var step_pending := false
var message := ""
var _tool := OptionButton.new()
var _model := OptionButton.new()
var _roster := OptionButton.new()
var _actor_action: String = ""
var _liquid_action := false
var _pending_request_serial := 0
var _instances := OptionButton.new()
var _material := OptionButton.new()
var _response := OptionButton.new()
var _camera := OptionButton.new()
var _brush := SpinBox.new()
var _fire := CheckButton.new()
var _stream := CheckButton.new()
var _fields := {}
var _position := []
var _extent := []
var _details := VBoxContainer.new()
# Details scrolls inside a capped height so the toolbar rows above it never
# leave the top of the window (the toolbar grew with the equipment rows).
var _details_scroll := ScrollContainer.new()
const DETAILS_MAX_HEIGHT := 300
var _liquids: CyberLiquidComparisonPanel
var _detail_label := Label.new()
var _name := LineEdit.new()
var _status := Label.new()
var _last_cell := Vector2i(-1,-1)
var _drag_button := 0
var _pan := false
var _stream_was_active := false
var _saved_view := {}
var _reload_rollback := {}
var _requested_response: String = "LA-SELECTIVE"
var _zoom := 1
var _last_status_ms := -1000
var _runtime_label := ""
var _processor_label := ""
# WCX/BW-001 experimental Water spray controls (separate owner script).
var water_lab := preload("res://scripts/workbench_water_lab.gd").new()
var water_spray := preload("res://scripts/workbench_water_spray_panel.gd").new()
var paint_editor: Control
var reciprocal_panel: Control
# IN-TOOLS #361 valve / drain / nozzle controls (separate owner script).
var equipment := preload("res://scripts/workbench_liquid_equipment_panel.gd").new()

func open_reciprocal() -> void:
	_cancel()
	if reciprocal_panel == null:
		reciprocal_panel = load("res://scripts/workbench_reciprocal_panel.gd").new()
		add_child(reciprocal_panel)
		move_child(reciprocal_panel,mini(4,get_child_count()-1))
		reciprocal_panel.mount(self)
	reciprocal_panel.open_panel()

func open_materials_lab() -> void:
	_cancel()
	if not is_instance_valid(_materials_lab_window):
		_materials_lab_window = Window.new()
		_materials_lab_window.hide()
		_materials_lab_window.title = "CyberSand / Materials Lab"
		_materials_lab_window.min_size = Vector2i(1000,650)
		_materials_lab_window.transient = true
		# A desktop Lab owns physical pixels instead of inheriting the game's
		# stretched canvas. Keep embedded fallback for headless/Web displays.
		_materials_lab_window.force_native = not OS.has_feature("web") and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)
		_materials_lab_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		_materials_lab_window.handle_input_locally = true
		add_child(_materials_lab_window)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side: String in ["left","right","top","bottom"]:
			margin.add_theme_constant_override("margin_" + side,10)
		_materials_lab_window.add_child(margin)
		var panel := preload("res://scripts/material_lab_panel.gd").new()
		if material_audition == null:
			material_audition = preload("res://scripts/material_audition_controller.gd").new()
			material_audition.bind(self)
		panel.bind_current_scene(material_audition)
		_materials_lab_panel = panel
		panel.name = "MaterialsLabPanel"
		margin.add_child(panel)
		panel.close_requested.connect(_materials_lab_window.hide)
		_materials_lab_window.close_requested.connect(_materials_lab_window.hide)
	_materials_lab_panel.set_policy_readback(host.tower_context.get("liquid_solver_policy",{}),"Workbench owner snapshot at opening; reopen to refresh")
	if _materials_lab_window.force_native: _materials_lab_window.current_screen = get_window().current_screen
	_materials_lab_window.popup_centered_clamped(Vector2i(1520,900),0.95)
	if _materials_lab_window.force_native:
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(get_window().current_screen)
		if not _fit_materials_lab_native(usable,Vector2i(1520,900)):
			_materials_lab_window.hide()
			refuse("Materials Lab needs its 1000×650 client plus window borders inside the desktop work area (%d×%d)." % [usable.size.x,usable.size.y])

func _fit_materials_lab_native(usable: Rect2i, requested: Vector2i) -> bool:
	# Godot's centered-clamped popup uses the full monitor. Native decorations
	# can only be measured after showing; fit their outer rectangle to work area.
	var popup: Window = _materials_lab_window
	var before := {"client_position":popup.position,"client_size":popup.size,
		"outer_position":popup.get_position_with_decorations(),"outer_size":popup.get_size_with_decorations()}
	var chrome: Vector2i = popup.get_size_with_decorations() - popup.size
	var available: Vector2i = usable.size - chrome
	var receipt := {"requested_client_size":requested,"usable_position":usable.position,"usable_size":usable.size,
		"minimum_client_size":popup.min_size,"chrome":chrome,"before":before,"admitted":false}
	popup.set_meta("materials_lab_placement",receipt)
	if available.x < popup.min_size.x or available.y < popup.min_size.y: return false
	popup.size = requested.min(available).max(popup.min_size)
	var offset: Vector2i = popup.position - popup.get_position_with_decorations()
	popup.position = usable.position + (usable.size - popup.get_size_with_decorations()) / 2 + offset
	receipt["after"] = {"client_position":popup.position,"client_size":popup.size,
		"outer_position":popup.get_position_with_decorations(),"outer_size":popup.get_size_with_decorations()}
	receipt.admitted = usable.encloses(Rect2i(popup.position,popup.size)) and usable.encloses(
		Rect2i(popup.get_position_with_decorations(),popup.get_size_with_decorations()))
	popup.set_meta("materials_lab_placement",receipt)
	return receipt.admitted

func _row(parent: Control) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",4)
	row.add_theme_constant_override("v_separation",2)
	parent.add_child(row)
	return row

func _button(row: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = caption
	button.pressed.connect(func() -> void:
		_commit_field(button.get_viewport())
		action.call())
	row.add_child(button)
	return button

func _label(row: Control, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	row.add_child(label)

func _picker(row: Control, picker: OptionButton, names: Array, action: Callable = Callable()) -> void:
	picker.focus_mode = Control.FOCUS_NONE
	if picker in [_model,_roster,_instances]:
		picker.fit_to_longest_item = false
		picker.clip_text = true
		picker.custom_minimum_size.x = 190
		picker.get_popup().max_size = Vector2i(800,500)
	for caption: String in names:
		picker.add_item(caption)
	if action.is_valid(): picker.item_selected.connect(action)
	row.add_child(picker)

func _spin(row: Control, caption: String, field: SpinBox, low: float, high: float, step: float, value: float) -> SpinBox:
	_label(row,caption)
	field.min_value = low
	field.max_value = high
	field.step = step
	field.value = value
	field.custom_minimum_size.x = 78
	field.get_line_edit().focus_entered.connect(_cancel)
	row.add_child(field)
	return field

func setup(controller: Control, recovery: Dictionary = {}) -> void:
	host = controller
	_erosion_density.min_value = 1
	_erosion_density.max_value = 100
	_erosion_density.value = 25
	_erosion_seed.max_value = 1000000000
	_erosion_seed.value = 4242
	object_shard_m4_port.enabled = not host.has_method(&"persistent_operation_allowed") and "--objectshard-m4-workbench" in OS.get_cmdline_user_args()
	# No previous Art conversation or profile session is read at game startup.
	_art_history_session = {"state":"no_session","source":"","error":""}
	host.tower_panel.refresh(false,0,{})
	var layout: Control = host.get_node("Layout")
	for child: Control in layout.get_children():
		if child != host.world_view: child.hide()
	layout.add_child(self)
	layout.move_child(self,0)
	host.world_view.custom_minimum_size = Vector2(0,180)
	host.world_view.mouse_filter = Control.MOUSE_FILTER_STOP
	host.world_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.world_view.gui_input.connect(_world_input)
	host.world_view.mouse_exited.connect(_cancel_object_shard_pointer)
	host.world_view.resized.connect(_cancel_object_shard_pointer)
	var compact := Theme.new()
	compact.default_font_size = 13
	theme = compact
	var row := _row(self)
	_label(row,"Pilot")
	_picker(row,_roster,["Choose flyer…"],_roster_changed)
	_fill_roster()
	_button(row,"Play / Pause [P]",toggle_pause)
	_button(row,"Step [.]",step_once)
	_button(row,"Reset selected [R]",reset_selected)
	_button(row,"Restore start",restore_start)
	_button(row,"New blank",new_canvas)
	_button(row,"New from generator…",func() -> void: _generated_dialog.open_new())
	_button(row,"Reciprocal assembly…",open_reciprocal)
	_button(row,"Materials Lab…",open_materials_lab)
	_button(row,"Water Lab…",water_lab.open)
	_picker(row,_camera,["Free camera","Follow selected","Overview"],func(i: int) -> void: set_camera(i))
	_button(row,"−",func() -> void: zoom_by(1))
	_button(row,"+",func() -> void: zoom_by(-1))
	_actor_configuration_button = _button(row,"Configuration…",open_actor_composition)
	_button(row,"Art batches",open_art_batches)
	if not host.has_method(&"persistent_operation_allowed"): _button(row,"Structures…",open_object_shard_controls)
	_button(row,"Batch Lab…",open_batch_lab)
	_button(row,"Architecture…",open_architecture_lab)
	_button(row,"Details",func() -> void: _details.visible = not _details.visible)
	_button(row,"Menu [F2]",func() -> void:
		if host.has_method(&"request_persistent_exit"): host.call(&"request_persistent_exit","launcher")
		else: get_tree().change_scene_to_file("res://feature_launcher.tscn"))
	row = _row(self)
	_picker(row,_tool,TOOL_NAMES,func(_index: int) -> void:
		_cancel()
		_update_object_shard_tool_controls())
	if object_shard_m4_port.enabled:
		for label: String in STRUCTURAL_TOOL_NAMES: _tool.add_item(label)
	var names: Array = []
	_model_ids = _compact_model_ids()
	for id: String in _model_ids: names.append(ActorCatalog.entry(id).get("name",id))
	_label(row,"Place model")
	_picker(row,_model,names)
	_model.tooltip_text = "Model for Place at X/Y, cursor placement, and Replace selected. Use Pilot to switch immediately."
	_button(row,"Place at X/Y",func() -> void: place(model_choice(),entered_position()))
	_label(row,"Instance")
	_picker(row,_instances,[],func(i: int) -> void: select_instance(_instances.get_item_id(i)))
	_button(row,"Focus",focus_selected)
	_button(row,"Replace with model",replace_selected)
	_button(row,"Remove",remove_selected)
	_picker(row,_material,Setup.MATERIAL_NAMES,func(i: int) -> void:
		if paint_editor != null:
			var id: int = _material.get_item_id(i)
			paint_editor.select_material(id)
			if not applied.is_empty() and id in Setup.MATERIALS: applied.material = id
		elif not applied.is_empty(): applied.material = Setup.MATERIALS[i])
	_spin(row,"Radius",_brush,2,24,1,8)
	_brush.value_changed.connect(func(value: float) -> void:
		if not applied.is_empty(): applied.brush = maxi(2,int(value))
		_cancel_object_shard_pointer())
	_button(row,"Source at X/Y",func() -> void: place_source(Vector2i(entered_position())))
	_button(row,"Burst [B]",burst)
	_stream.text = "Stream ≤600 ticks"
	_stream.focus_mode = Control.FOCUS_NONE
	_stream.toggled.connect(stream)
	row.add_child(_stream)
	row = _row(self)
	for axis: String in ["X","Y"]:
		_position.append(_spin(row,axis,SpinBox.new(),0,2047,0.01,200))
	_button(row,"Save reset spawn",save_spawn)
	_button(row,"Use body position",capture_spawn)
	_button(row,"Move to X/Y",move_selected)
	_picker(row,_response,RESPONSE_LABELS,func(i: int) -> void: _requested_response = Setup.RESPONSES[i])
	_button(row,"Apply settings",apply_settings)
	_button(row,"Defaults",defaults)
	_fire.text = "Thruster fire"
	_fire.focus_mode = Control.FOCUS_NONE
	_fire.toggled.connect(func(enabled: bool) -> void:
		fire_enabled = enabled
		if not applied.is_empty(): applied.fire = enabled)
	row.add_child(_fire)
	# All Water configuration and equipment live in one bounded, scrollable window.
	# Only a single entry point remains in the Workbench toolbar.
	water_lab.build(self)
	water_spray.build(host,self,_row,entered_position,water_lab.pages)
	equipment.build(host,self,_row,entered_position,water_lab.pages["equipment"])
	_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details_scroll.custom_minimum_size.y = DETAILS_MAX_HEIGHT
	_details_scroll.hide()
	add_child(_details_scroll)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_scroll.add_child(_details)
	_details.visibility_changed.connect(_details_visibility_changed)
	_details.hide()
	row = _row(_details)
	for key: String in Setup.DEFAULT_OPTIONS:
		var low := 5.0 if key == "budget" else (1.0 if key == "boost_multiplier" else (0.01 if key in ["mass_multiplier","inertia_multiplier"] else 0.0))
		var high := 80.0 if key == "budget" else (8.0 if key == "boost_multiplier" else 64.0)
		_fields[key] = _spin(row,key.replace("_multiplier"," ×").capitalize(),SpinBox.new(),low,high,1 if key == "budget" else 0.01,Setup.DEFAULT_OPTIONS[key])
	_button(row,"Reload JSON + reset",reload_definitions)
	row = _row(_details)
	for axis: String in ["New width","height"]:
		_extent.append(_spin(row,axis,SpinBox.new(),512,2048,64,2048))
	_name.text = "my-canvas"
	_name.custom_minimum_size.x = 150
	_name.focus_entered.connect(_cancel)
	row.add_child(_name)
	var save_start_button := _button(row,"Save start [Ctrl+S]",save_setup)
	var load_start_button := _button(row,"Load start",load_setup)
	add_child(_generated_dialog)
	_generated_dialog.mount(self)
	paint_editor = PaintEditor.new()
	add_child(paint_editor)
	move_child(paint_editor,2)
	paint_editor.mount(self)
	actor_interaction = ActorInteraction.new()
	actor_interaction.mount(self)
	paint_editor.deferred_brush_finished.connect(func(token: int, result: Dictionary) -> void:
		if art_batches != null: art_batches.executor.manual_finished(token,result))
	paint_editor.history_action_finished.connect(func(receipt: Dictionary) -> void:
		if art_batches != null: art_batches.history_edited(receipt))
	# Native history remains available independently of Art and its session log.
	_name.reparent(paint_editor)
	_name.tooltip_text = "Name of the authored starting map; Save does not capture evolved simulation."
	save_start_button.reparent(paint_editor)
	load_start_button.reparent(paint_editor)
	_flatten_button = _button(paint_editor,"Flatten / Bake History…",_flatten_pressed)
	_flatten_button.tooltip_text = "Make the current stored materials the new baseline and discard earlier construction/Undo history. The live World keeps running. Save remains separate."
	_flatten_confirmation.title = "Flatten / Bake History"
	_flatten_confirmation.dialog_text = "Make the current material layout the new authored baseline?\nEarlier construction and Undo/Redo history will be discarded.\nThe live simulation and actors continue unchanged. This does not Save."
	_flatten_confirmation.ok_button_text = "Flatten history"
	_flatten_confirmation.confirmed.connect(func() -> void: request_flatten())
	add_child(_flatten_confirmation)
	_material.clear()
	for material_id: int in host.simulation_worker.paint_materials():
		_material.add_item("%s · %d" % [host.material_name(material_id).capitalize(),material_id],material_id)
	_brush.min_value = 0
	_brush.tooltip_text = "Radius in cells. Zero paints one cell; [ and ] adjust width."
	_liquids = host.playable_session_panel.policy_editor
	_liquids.reparent(water_lab.pages["advanced"])
	_liquids.use_one_shot_normalization()
	_liquids.water_family_selected.connect(water_spray.stage_advanced_water_family)
	_button(_row(water_lab.pages["advanced"]),"Apply liquid selection",apply_liquids)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(_detail_label)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A long receipt must not grow the toolbar off the top of the window; the
	# full status stays readable in the tooltip.
	_status.max_lines_visible = 2
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_status)
	if object_shard_m4_port.enabled: _reserve_object_shard_status_height()
	DisplayServer.window_set_title("CyberSand · Development workbench")
	_processor_label = "%s · %d logical CPUs" % [OS.get_processor_name(),OS.get_processor_count()]
	var binary := "cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so"
	var binary_hash := FileAccess.get_sha256("res://addons/cybersand_native/bin/"+binary)
	_runtime_label = "%s · Godot %s · native %s · definitions %s" % [OS.get_name(),Engine.get_version_info().string,binary_hash.left(12),Fleet.registry_hash().left(12)]
	if host.has_method(&"persistent_bootstrap_pending") and host.call(&"persistent_bootstrap_pending"): return
	if recovery.is_empty(): new_canvas.call_deferred()
	else: apply.call_deferred(recovery)


func _ensure_art_batches() -> Window:
	# No panel/provider/conversation state exists until the owner opens Art.
	if not is_instance_valid(art_batches):
		art_batches = preload("res://scripts/art_batch_panel.gd").new()
		art_batches.wb = self
		# Executor calls are also permitted before the Window receives its first
		# _process callback (e.g. an explicit hidden-panel agent transaction).
		# Bind immediately, while preserving lazy panel/provider construction.
		art_batches.executor.wb = self
		art_batches.hide()
		add_child(art_batches)
	return art_batches


func open_art_batches() -> void:
	_cancel()
	_ensure_art_batches().popup_centered()


func open_batch_lab() -> void:
	_cancel()
	# Optional and lazy: ordinary Workbench startup creates no tile workers,
	# provider sessions, experiment files or render targets.
	if not is_instance_valid(batch_lab):
		batch_lab = preload("res://scripts/batch_lab/batch_lab_panel.gd").new()
		batch_lab.wb = self
		batch_lab.hide()
		add_child(batch_lab)
	batch_lab.popup_centered_clamped(Vector2i(1180,780),0.92)


func capture_batch_source(region: Rect2i) -> Dictionary:
	return await preload("res://scripts/batch_lab/batch_lab_source.gd").capture(self,region)


func open_architecture_lab() -> void:
	_cancel()
	if not is_instance_valid(architecture_lab):
		architecture_lab = preload("res://scripts/batch_lab/architecture_stage_panel.gd").new()
		architecture_lab.wb = self
		architecture_lab.hide()
		add_child(architecture_lab)
	architecture_lab.popup_centered_clamped(Vector2i(1160,780),0.92)


func open_actor_composition() -> void:
	if is_instance_valid(_actor_configuration_button) and _actor_configuration_button.disabled:
		refuse(_actor_configuration_button.tooltip_text)
		return
	_cancel()
	if not is_instance_valid(_actor_panel):
		_actor_panel = preload("res://scripts/workbench_actor_panel.gd").new()
		_actor_panel.hide()
		add_child(_actor_panel)
		_actor_panel.mount(self)
		_actor_panel.interaction_mode_requested.connect(actor_interaction.set_mode)
		_actor_panel.manipulation_settings_requested.connect(actor_interaction.configure)
		_actor_panel.capacity_requested.connect(set_sandbox_capacity)
		_actor_panel.demo_requested.connect(load_actor_sandbox)
		_actor_panel.placement_requested.connect(actor_interaction.place_exact)
		_actor_panel.tuning_requested.connect(set_actor_tuning)
	_actor_panel.refresh(true)
	_actor_panel.popup_centered_clamped(Vector2i(900,700),0.9)


func actor_sandbox_state() -> Dictionary:
	return actor_interaction.state() if actor_interaction != null else {}


func actor_placement_pose(id: int) -> Dictionary:
	if actor_interaction == null: return {}
	var current = actor_interaction.manipulator()
	return current.capture_actor(id) if current != null else {}


func set_sandbox_capacity(value: Dictionary) -> bool:
	if not _editable_authored_world(): return false
	var error := Setup.SandboxCapacity.error(value)
	if not error.is_empty(): return refuse(error)
	var next := applied.duplicate(true)
	next["sandbox_capacity"] = value.duplicate(true)
	error = Setup.validate(next,false)
	if not error.is_empty(): return refuse(error)
	# Updating the admitted budget uses the existing prepared-owner protocol.
	# No actors are deleted and no body count is silently clipped.
	if not apply(next,true,0,false,not host.paused,{},{},false): return false
	message = "Preparing capacity · %d actors / %d bodies / %d proxies. Existing poses and terrain retained; controllers restart." % [value.logical_limit,value.body_limit,value.proxy_limit]
	return true


func set_actor_tuning(id: int, options: Dictionary) -> bool:
	if not _editable_authored_world(): return false
	var next := applied.duplicate(true)
	var selected := actor(next,id)
	if selected.is_empty(): return refuse("Select an existing actor before applying physical tuning.")
	selected.options = options.duplicate(true)
	var error := Setup.validate(next,false)
	if not error.is_empty(): return refuse(error)
	if not apply(next,true,0,false,not host.paused,{},{},false): return false
	message = "Preparing physical tuning for #%d · existing poses and terrain retained; controllers restart." % id
	return true


func load_actor_sandbox(kind: String, count: int = 64) -> bool:
	if not _editable_authored_world(): return false
	var candidate: Dictionary = preload("res://scripts/workbench_actor_sandbox.gd").build(kind,PackedInt32Array(applied.liquid_policy),count)
	if candidate.is_empty(): return refuse("Sandbox example could not be built within the physical resource limits.")
	if not apply(candidate,false,0,false,false,{},{},false): return false
	_pending_sandbox_demo = kind
	message = "Preparing %s playground with %d real actors…" % [kind,candidate.actors.size()]
	return true


func commit_actor_placement(source: Dictionary, proposed: Dictionary) -> bool:
	if not _editable_authored_world(): return false
	if not host.paused: return refuse("Pause an installed session before committing placement.")
	var session = host.physical_actor_session
	if session == null or session.run_id != str(source.get("run_id","")) or session.epoch != int(source.get("epoch",-1)):
		return refuse("The physical owner changed during placement; no authored data was modified.")
	var id := int(source.get("instance_id",0))
	var next := applied.duplicate(true)
	var selected := actor(next,id)
	if selected.is_empty(): return refuse("The selected actor no longer exists.")
	# Prepared adoption retains every other assembly too. Released, fixed or
	# reattached equipment has a different live joint graph that an authored
	# reconstruction cannot faithfully preserve. Refuse before staging anything.
	for retained: Dictionary in applied.actors:
		var pose: Dictionary = session.capture_workbench_assembly(int(retained.id))
		if pose.is_empty(): return refuse("An assembly is unavailable; placement left the world unchanged.")
		if not str(pose.get("pose_error","")).is_empty():
			return refuse("Cannot preserve #%d: %s Reset that actor before authored placement." % [int(retained.id),str(pose.pose_error)])
	var latest: Dictionary = session.capture_workbench_assembly(id)
	if latest.is_empty() or latest.parts != source.get("parts",[]):
		return refuse("The actor pose changed during placement; start a new preview.")
	var confirmed: Dictionary = ActorInteraction.Manipulator.placement_preview(latest,proposed.position,float(proposed.rotation))
	if confirmed.is_empty() or not confirmed.valid: return refuse("Place every physical part inside the canvas.")
	selected.spawn = [confirmed.position.x,confirmed.position.y]
	selected["spawn_rotation_degrees"] = rad_to_deg(float(confirmed.rotation))
	next.selected = id
	var overrides := {id:{"position":confirmed.position,"retained_parts":confirmed.parts}}
	if not apply(next,true,0,false,false,{},{},false,overrides): return false
	_actor_action = "Placed / rotated"
	message = "Preparing #%d placement once · current articulation retained; momentum is cleared for this actor; controllers restart." % id
	return true


func _compact_model_ids() -> Array[String]:
	# Keep the ordinary paint toolbar compact. The expandable composition panel
	# contains all families; placed non-flyers remain directly available here.
	var result: Array[String] = []
	for index: int in Fleet.count(): result.append(Fleet.stable_id(index))
	result.append(Setup.BARREL)
	for a: Dictionary in applied.get("actors",[]):
		if str(a.model) not in result: result.append(str(a.model))
	return result


func open_ambient_profile(id: int) -> void:
	var a := actor(applied, id)
	if a.is_empty() or not ActorCatalog.AmbientActuator.supports(str(a.model)):
		refuse("Inspect an actor with a supported procedural locomotion adapter.")
		return
	_cancel()
	if not is_instance_valid(_ambient_profile_editor):
		_ambient_profile_editor = preload("res://scripts/ambient/ambient_profile_editor.gd").new()
		_ambient_profile_editor.hide()
		add_child(_ambient_profile_editor)
		_ambient_profile_editor.mount(self)
	_ambient_profile_editor.open_for(id)



# Scene-local reusable profiles are authored data. Assignments are explicit
# copies, so saving a library entry cannot silently change an existing actor.
func ambient_library() -> Dictionary:
	var current: Dictionary = applied.get("ambient_authoring", AmbientAuthoring.blank())
	return AmbientAuthoring.canonicalize(current)


func set_ambient_library(library: Dictionary, expected_library: Dictionary, expected_run: String, expected_epoch: int) -> bool:
	if not _editable() or host.physical_actor_session == null: return false
	var session: Variant = host.physical_actor_session
	if str(session.run_id) != expected_run or int(session.epoch) != expected_epoch:
		return refuse("World changed; refresh the staged profile library.")
	if ambient_library() != expected_library:
		return refuse("Profile library changed elsewhere; refresh before applying.")
	var error: String = AmbientAuthoring.validate(library)
	if not error.is_empty(): return refuse(error)
	var next: Dictionary = applied.duplicate()
	next["ambient_authoring"] = AmbientAuthoring.canonicalize(library)
	if JSON.stringify(next).to_utf8_buffer().size() > Setup.BYTE_LIMIT:
		return refuse("The authored scene and profile library exceed the save-file budget.")
	applied["ambient_authoring"] = next.ambient_authoring
	message = "Profile library saved in this authored scene. Existing actor copies are unchanged; use Save start to persist."
	return true


func apply_ambient_group(ids: Array, profile: Dictionary, expected: Dictionary) -> bool:
	if not _editable() or host.physical_actor_session == null: return false
	var session: Variant = host.physical_actor_session
	if ids.is_empty() or ids.size() > ActorCatalog.MAX_AMBIENT_CONTROLLERS \
		or not expected.has_all(["run_id", "epoch", "actors"]) or not expected.actors is Dictionary \
		or str(expected.run_id) != str(session.run_id) or int(expected.epoch) != int(session.epoch):
		return refuse("Invalid or stale group selection; refresh it before applying.")
	var seen: Dictionary = {}
	var transactions: Array[Dictionary] = []
	var next: Dictionary = applied.duplicate(true)
	for value: Variant in ids:
		if not value is int or value <= 0 or seen.has(value):
			return refuse("Group selection contains an invalid or repeated actor.")
		var id: int = value
		seen[id] = true
		var current: Dictionary = actor(applied, id)
		var staged: Variant = expected.actors.get(str(id))
		if current.is_empty() or not staged is Dictionary \
			or not staged.has_all(["model", "hash", "control"]) \
			or str(staged.model) != str(current.model) or str(staged.hash) != str(current.hash) \
			or not staged.control is Dictionary or staged.control != ActorCatalog.control_for(current):
			return refuse("A selected actor disappeared or changed; refresh the group. No actor was changed.")
		var control: Dictionary = ActorCatalog.control_for(current)
		control.source = "policy"
		control.policy = "ambient"
		control.enabled = true
		control["ambient"] = profile.duplicate(true)
		var error: String = ActorCatalog.control_error(str(current.model), control)
		if not error.is_empty(): return refuse("#%d: %s. No group member was changed." % [id, error])
		control.ambient = ActorCatalog.AmbientProfile.canonicalize(control.ambient)
		transactions.append({"instance_id":id, "configuration":control,
			"expected_configuration":ActorCatalog.control_for(current)})
		actor(next, id)["control"] = control.duplicate(true)
	var error: String = Setup.validate(next, false)
	if not error.is_empty(): return refuse(error)
	if JSON.stringify(next).to_utf8_buffer().size() > Setup.BYTE_LIMIT:
		return refuse("Group profiles exceed the authored save-file budget.")
	if not session.set_workbench_controls(transactions, str(expected.run_id), int(expected.epoch)):
		return refuse(str(session.last_error))
	# The owner acknowledged every replacement before authored assignments change.
	for item: Dictionary in transactions:
		var id: int = item.instance_id
		actor(applied, id)["control"] = item.configuration.duplicate(true)
		_pilot_returns.erase(id)
		if id == pilot_id():
			_cancel()
			_pilot_instance_id = 0
			pilot_slot = -1
	_sync_roster()
	message = "Applied %s to %d inhabitants together; physical poses and resources retained." % [str(profile.get("name", "profile")), transactions.size()]
	return true


func set_ambient_overlay(id: int, enabled: bool) -> void:
	_ambient_overlay_id = id if enabled and not actor(applied, id).is_empty() else 0
	if _ambient_overlay_id > 0 and not is_instance_valid(_ambient_overlay):
		_ambient_overlay = preload("res://scripts/ambient/ambient_debug_overlay.gd").new()
		host.get_node("Layout/World").add_child(_ambient_overlay)
	if is_instance_valid(_ambient_overlay) and _ambient_overlay_id == 0: _ambient_overlay.hide()


func load_ambient_example(example_id: String) -> bool:
	if not _editable(): return false
	var candidate: Dictionary = preload("res://scripts/ambient/ambient_examples.gd").make(example_id, PackedInt32Array(applied.liquid_policy))
	if candidate.is_empty(): return refuse("Unknown ambient example.")
	if not apply(candidate, false, 0, false, false, {}, {}, false): return false
	_pending_ambient_example = example_id
	message = "Preparing native ambient scene; existing materials and actor owners remain active until acknowledgement."
	return true


func _fill_roster() -> void:
	_roster.clear()
	_roster_models.clear()
	_roster.add_item("Observer / no human pilot",0)
	var available := []
	for index: int in Fleet.count(): available.append(Fleet.stable_id(index))
	for a: Dictionary in applied.get("actors",[]):
		if a.model not in available: available.append(a.model)
	for model_id: String in available:
		if not ActorCatalog.supports(model_id,"human"): continue
		_roster_models.append(model_id)
		_roster.add_item(str(ActorCatalog.entry(model_id).name),_roster_models.size())
	_roster.tooltip_text = "Choose the human pilot explicitly. Inspecting an actor does not change its controller."


func _sync_roster() -> void:
	var piloted := actor(applied,pilot_id())
	_roster.select(_roster_models.find(str(piloted.get("model","")))+1)


func _roster_changed(index: int) -> void:
	_sync_roster()
	if index == 0: release_pilot()
	elif index <= _roster_models.size(): pilot_model(_roster_models[index-1])


func pilot_id() -> int:
	return _pilot_instance_id


func pilot_description() -> String:
	var a := actor(applied,pilot_id())
	return "Observer" if a.is_empty() else "#%d %s" % [pilot_id(),a.model]


func release_pilot() -> void:
	_cancel()
	_pilot_instance_id = 0
	pilot_slot = -1
	_sync_roster()
	message = "Human input released; autonomous controllers continue."


func pilot_instance(id: int) -> bool:
	if not _editable(): return false
	var a := actor(applied,id)
	if a.is_empty() or not ActorCatalog.supports(str(a.model),"human"):
		return refuse("This actor cannot be piloted.")
	_cancel()
	var control := ActorCatalog.control_for(a)
	if control.source != "human": _pilot_returns[id] = control.duplicate(true)
	control.source = "human"
	control.enabled = true
	if not set_actor_control(id,control): return false
	_pilot_instance_id = id
	pilot_slot = host.physical_actor_session.slot_for_instance(id)
	select_instance(id)
	_sync_roster()
	message = "Piloting %s. Other actors keep their own controllers." % pilot_description()
	if host.paused: message += " Press Play / Pause [P] to enable movement."
	return true


func hand_back_pilot() -> bool:
	var id := pilot_id()
	var a := actor(applied,id)
	if a.is_empty(): return refuse("No human pilot to hand back.")
	var control: Dictionary = _pilot_returns.get(id,ActorCatalog.default_control(str(a.model))).duplicate(true)
	if control.source == "human": control.source = "scripted"
	control.enabled = true
	# A fallback hand-back changes producer, never the authored starting item.
	control.usable_index = ActorCatalog.control_for(a).usable_index
	if not set_actor_control(id,control): return false
	_pilot_returns.erase(id)
	message = "Handed #%d back to %s control without rebuilding its body." % [id,control.source]
	return true


func set_actor_control(id: int, control: Dictionary) -> bool:
	if not _editable() or host.physical_actor_session == null: return false
	var a := actor(applied,id)
	if a.is_empty(): return refuse("Unknown actor instance.")
	var error := ActorCatalog.control_error(str(a.model),control)
	if not error.is_empty(): return refuse(error)
	if id == pilot_id(): _cancel()
	if not host.physical_actor_session.set_workbench_control(id,control):
		return refuse(host.physical_actor_session.last_error)
	a.control = control.duplicate(true)
	if id == pilot_id() and (control.source != "human" or not control.enabled):
		_pilot_instance_id = 0
		pilot_slot = -1
	_sync_roster()
	message = "#%d · %s · %s; live pose and resources retained." % [id,control.source,"enabled" if control.enabled else "decisions stopped"]
	return true


func apply_actor_equipment(id: int, usable_index: int) -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	var a := actor(next,id)
	if a.is_empty(): return refuse("Unknown actor instance.")
	var config := ActorCatalog.control_for(a)
	config.usable_index = usable_index
	var error := ActorCatalog.control_error(str(a.model),config)
	if not error.is_empty(): return refuse(error)
	a.control = config
	if not apply(next,true,0,false,not host.paused,{},{},false): return false
	_actor_action = "Re-equipped"
	message = "Preparing starting equipment; live terrain and body poses are retained, controller/resource state restarts."
	return true


func actor_observation(id: int, issue: bool = false) -> Dictionary:
	if host.physical_actor_session == null: return {}
	if issue: return host.physical_actor_session.workbench_policy_observation(id)
	var slot: int = host.physical_actor_session.slot_for_instance(id)
	return host.physical_actor_session._view(slot,false) if slot >= 0 else {}


func submit_actor_policy(id: int, command: Dictionary) -> bool:
	if busy() or host.paused or host.physical_actor_session == null:
		return refuse("Play an installed actor session before submitting a policy action.")
	if not host.physical_actor_session.submit_workbench_policy(id,command):
		return refuse(host.physical_actor_session.last_error)
	message = "Policy command accepted for #%d; consumption remains leased to physical ticks." % id
	return true


func load_mixed_actor_workshop() -> bool:
	if not _editable(): return false
	var candidate := Setup.builtin(Setup.MIXED_ACTOR_LABEL,PackedInt32Array(applied.liquid_policy))
	if candidate.is_empty(): return refuse("Mixed Actor Workshop is unavailable.")
	if not apply(candidate,false,0,false,false,{},{},false): return false
	_pending_actor_workshop = true
	return true


func _commit_field(input_viewport: Viewport = null) -> void:
	# Windows retain independent focused fields. Commit the clicked child
	# first, then main X/Y or other pending parent input consumed by its action.
	# Main-window and default callers still visit their viewport exactly once.
	var viewports: Array[Viewport] = [get_viewport()]
	if input_viewport != null and input_viewport != viewports[0]: viewports.push_front(input_viewport)
	for viewport: Viewport in viewports:
		var focus := viewport.gui_get_focus_owner()
		if focus is LineEdit and focus.get_parent() is SpinBox: focus.get_parent().apply()
		if focus != null: focus.release_focus()

func selected_id() -> int:
	return int(applied.get("selected",0))

func model_choice() -> String:
	return _model_ids[_model.selected] if _model.selected >= 0 and _model.selected < _model_ids.size() else Setup.BARREL

func entered_position() -> Vector2:
	return Vector2(_position[0].value,_position[1].value)

func actor(setup_data: Dictionary, id: int) -> Dictionary:
	for a: Dictionary in setup_data.get("actors",[]):
		if int(a.id) == id: return a
	return {}

func body_state(id: int) -> Dictionary:
	if id <= 0 or host.physical_actor_session == null: return {}
	return host.physical_actor_session.workbench_actor_state(id)

func refuse(reason: String) -> bool:
	message = "Refused · " + reason.trim_prefix("MicroScenario rejected; ")
	return false

func busy() -> bool:
	return (host.has_method(&"persistent_operation_allowed") and not str(host.call(&"persistent_operation_allowed","authoring",{})).is_empty()) \
		or not host.pending_microscenario_apply.is_empty() or step_pending or host.simulation_worker.has_failed() \
		or is_flatten_pending() or (paint_editor != null and paint_editor.busy()) \
		or (object_shard_m4_port.enabled and host.has_method("object_shard_m4_latency_report") \
			and not host.object_shard_m4_runtime.materials_ready()) \
		or (reciprocal_panel != null and reciprocal_panel.busy())

func persistent_stage_authoring(authoring: Dictionary) -> void:
	_pending_generated = authoring.get("generated_packet",{}).duplicate(true)
	_pending_material_baseline = authoring.get("material_baseline",{}).duplicate(true)
	_pending_retain_generated = false
	_pending_request_serial = int(host.pending_microscenario_apply.get("serial",0))

func persistent_restore_camera(camera: Dictionary) -> void:
	if camera.is_empty(): return
	var origin: Variant = camera.get("origin")
	var size: Variant = camera.get("size")
	if not origin is Array or origin.size() != 2 or not size is Array or size.size() != 2: return
	if not is_finite(float(origin[0])) or not is_finite(float(origin[1])): return
	_zoom = clampi(int(camera.get("zoom",1)),0,ZOOMS.size()-1)
	_camera.select(clampi(int(camera.get("mode",0)),0,2))
	host.current_view_size = Vector2i(clampi(int(size[0]),1,2048),clampi(int(size[1]),1,2048))
	host.camera_origin = Vector2(origin[0],origin[1])

func _editable() -> bool:
	if busy() or applied.is_empty():
		return refuse("Wait for the current owner transaction.")
	return true

func _flatten_pressed() -> void:
	if is_flatten_pending():
		cancel_flatten()
		return
	_cancel()
	_flatten_confirmation.popup_centered(Vector2i(550,190))

func is_flatten_pending() -> bool:
	return not _flatten_request.is_empty()

func get_flatten_status() -> Dictionary:
	return _flatten_status.duplicate(true)

func _refuse_flatten(reason: String) -> Dictionary:
	refuse(reason)
	_flatten_status = {"status":"failed","reason":reason}
	return {"ok":false,"reason":reason}

func request_flatten(capacity_bytes: int = 2048*2048*2) -> Dictionary:
	if host != null and host.has_method("object_shard_m4_latency_report") and host.object_shard_m4_runtime.has_live_inventory():
		return _refuse_flatten("Moving structures own material outside the terrain. Save start preserves the authored recipe; Flatten requires all shards to be returned first.")
	if actor_interaction != null: actor_interaction.cancel("flatten")
	if host == null or applied.is_empty(): return _refuse_flatten("No native Workbench is installed.")
	if is_flatten_pending(): return {"ok":false,"reason":"Flatten is already preparing."}
	if host.simulation_worker.has_failed():
		return _refuse_flatten("Native owner failed. Save the settled authored start, then restart the application and Load it.")
	if busy(): return _refuse_flatten("Wait for the current owner/paint transaction before Flatten.")
	if paint_editor != null and (paint_editor.dragging or paint_editor.recovery_required()):
		return _refuse_flatten("Finish the paint gesture, or Undo the partial edit, before Flatten.")
	if art_batches != null:
		var executor: RefCounted = art_batches.executor
		if executor.active or executor.waiting or not executor.manual.is_empty() or not executor.manual_inflight.is_empty():
			return _refuse_flatten("Agent drawing is queued or executing. Stop/wait for its native acknowledgement, then retry Flatten.")
	var state: Dictionary = host.simulation_worker.paint_state()
	if bool(state.get("busy",false)) or bool(state.get("art_busy",false)) or bool(state.get("legacy_busy",false)) \
			or bool(state.get("transition_busy",false)):
		return _refuse_flatten("Wait for all native edits and their completion receipts before Flatten.")
	var requested_usec := Time.get_ticks_usec()
	var admitted: Dictionary = host.simulation_worker.material_capture_request(int(state.get("generation",-1)),capacity_bytes)
	if not admitted.get("ok",false): return _refuse_flatten(str(admitted.get("reason","Native material capture refused.")))
	_flatten_request = {"token":int(admitted.token),"generation":int(state.generation),
		"extent":Setup.extent_of(applied),"edits":applied.edits.duplicate(true),"started_usec":requested_usec}
	_flatten_status = {"status":"pending","token":int(admitted.token),"reason":"Capturing native stored materials…"}
	if _flatten_button != null: _flatten_button.text = "Cancel Flatten"
	message = "Flatten · capturing native stored materials; previous history retained until validation completes…"
	return admitted

func cancel_flatten(reason: String = "Flatten cancelled; previous authoring history retained.") -> void:
	if not is_flatten_pending(): return
	if host != null and is_instance_valid(host) and host.simulation_worker != null:
		host.simulation_worker.material_capture_cancel(int(_flatten_request.token))
	_flatten_request = {}
	_flatten_status = {"status":"failed","reason":reason}
	if _flatten_button != null: _flatten_button.text = "Flatten / Bake History…"
	message = reason

func _poll_flatten() -> void:
	if not is_flatten_pending(): return
	var poll_usec := Time.get_ticks_usec()
	var captured: Dictionary = host.simulation_worker.material_capture_poll(int(_flatten_request.token))
	var transfer_usec := Time.get_ticks_usec()-poll_usec
	if captured.is_empty(): return
	if not captured.get("ok",false):
		cancel_flatten("Flatten failed · "+str(captured.get("error","Incomplete native material capture.")))
		return
	if int(captured.get("request_token",-1)) != int(_flatten_request.token) \
			or int(captured.get("generation",-1)) != int(_flatten_request.generation) \
			or Setup.extent_of(applied) != _flatten_request.extent or applied.edits != _flatten_request.edits:
		cancel_flatten("Flatten refused · stale native capture or changed authored history.")
		return
	var stage_usec := Time.get_ticks_usec()
	var staged := MaterialBaseline.stage(captured,_flatten_request.extent)
	if staged.has("error"):
		cancel_flatten("Flatten refused · "+str(staged.error))
		return
	var candidate := applied.duplicate(true)
	candidate.edits = []
	var error := Setup.validate(candidate)
	if not error.is_empty():
		cancel_flatten("Flatten refused · "+error)
		return
	stage_usec = Time.get_ticks_usec()-stage_usec
	var adoption_usec := Time.get_ticks_usec()
	var finished: Dictionary = host.simulation_worker.material_capture_finish(int(_flatten_request.token),true)
	if not finished.get("ok",false):
		cancel_flatten("Flatten refused · "+str(finished.get("reason","Native owner changed.")))
		return
	# The complete validated plane already exists. Only authoring references and
	# history change here; no prepared World, actor API, pause or simulation call.
	_material_baseline = staged.baseline
	_generated_active = {}
	applied = candidate
	if paint_editor != null: paint_editor.flattened()
	if art_batches != null:
		art_batches.stop_all("History flattened; pending model responses retired")
		art_batches.executor.canvas_changed()
	_flatten_status = {"status":"complete","reason":"","sha256":_material_baseline.sha256,
		"byte_count":_material_baseline.cells.size(),"extent":_material_baseline.extent,
		"generation":int(captured.generation),"native_generation":captured.get("native_generation",-1),
		"revision":captured.get("revision",-1),"tick":captured.get("tick",-1),
		"authoring_generation":finished.authoring_generation,"capture_usec":captured.get("capture_usec",0),
		"copy_usec":captured.get("copy_usec",0),"native_boundary_usec":captured.get("native_boundary_usec",0),
		# transfer_usec is only the worker-result handoff; native_boundary_usec
		# includes the complete GDScript/native call and owned buffer creation.
		"transfer_usec":transfer_usec,"stage_usec":stage_usec,"adoption_usec":Time.get_ticks_usec()-adoption_usec,
		"total_usec":Time.get_ticks_usec()-int(_flatten_request.started_usec)}
	_flatten_request = {}
	if _flatten_button != null: _flatten_button.text = "Flatten / Bake History…"
	message = "Flattened %s · %d bytes (2/cell). Earlier history discarded; live World unchanged. Save start when ready." % [
		str(_material_baseline.extent),_material_baseline.cells.size()]

func _exit_tree() -> void:
	for control: Control in [_erosion_density,_erosion_seed,_erosion_material_only]:
		if is_instance_valid(control) and control.get_parent()==null: control.free()
	object_shard_m4_port.retire("WorkbenchExit")
	if actor_interaction != null: actor_interaction.cancel("closed")
	cancel_flatten("Flatten cancelled during shutdown; no baseline was adopted.")
	if reciprocal_panel != null: reciprocal_panel.cancel("Workbench exited; experimental generation cancelled.")

# On edits, build other actors at their actual positions while leaving the
# saved spawn recipe intact. A deliberate restore/load uses saved spawns.
func apply(candidate: Dictionary, preserve: bool = false, reset_id: int = 0,
		convert_liquid_inventory: bool = false, resume_play: bool = false,
		generated_packet: Dictionary = {}, material_baseline: Dictionary = {},
		apply_staged_water: bool = true, pose_overrides: Dictionary = {}, authoring_patch: Dictionary = {}) -> bool:
	if busy(): return refuse("Wait for the current owner transaction.")
	if not authoring_patch.is_empty() and (not preserve or reciprocal_panel == null \
			or not reciprocal_panel.attests(candidate,authoring_patch)):
		return refuse("Construction history must match the current validated experimental proposal.")
	if preserve and paint_editor != null and paint_editor.recovery_required():
		return refuse("Undo the partial paint edit or Restore start before retaining the live World.")
	if preserve:
		if applied.is_empty(): return refuse("No installed session to retain.")
		# A retained request can change ownership/settings, never substitute a
		# different starting paint history for the native cells being copied.
		if authoring_patch.is_empty():
			candidate = candidate.duplicate()
			candidate.edits = applied.edits
	var error := Setup.validate(candidate,not preserve)
	if not error.is_empty(): return refuse(error)
	if preserve and object_shard_m4_port.enabled and uses_fixed_step_flight(candidate):
		return refuse("4LY flight requires its single-step Rapier space. Load a complete flight start to leave Structures.")
	if candidate.has("ambient_authoring"):
		candidate = candidate.duplicate()
		candidate["ambient_authoring"] = AmbientAuthoring.canonicalize(candidate.ambient_authoring)
	if not preserve and not generated_packet.is_empty() \
			and candidate.edits.size() > Setup.native_rectangle_budget():
		return refuse("This installed native runtime cannot reopen that detailed generated start; rebuild its GDExtension.")
	if preserve and art_batches != null and art_batches.executor.active:
		art_batches.executor.stop("Settings changed; finishing current chunk")
		return refuse("Finishing the current drawing chunk; retry after its acknowledgment.")
	if preserve and not generated_packet.is_empty():
		return refuse("Cannot import generated cells while preserving a live session.")
	if not material_baseline.is_empty() and (preserve or not generated_packet.is_empty()):
		return refuse("A standalone material baseline requires a fresh authored-start construction.")
	var generation := {}
	var material_packet := {}
	if not material_baseline.is_empty():
		error = MaterialBaseline.validate_document(candidate,material_baseline)
		if not error.is_empty(): return refuse(error)
		material_packet = MaterialBaseline.native_packet(material_baseline,candidate.edits)
	if not generated_packet.is_empty():
		var meta := GeneratedMaps.provenance(generated_packet)
		error = GeneratedMaps.valid_provenance(meta,Setup.extent_of(candidate))
		if not error.is_empty(): return refuse(error)
		if not generated_packet.get("cells") is PackedByteArray or \
				GeneratedMaps.digest(generated_packet.cells) != meta.sha256:
			return refuse("Generated material bytes changed after preview.")
		generation = GeneratedMaps.native_packet(meta,generated_packet.cells,candidate.edits)
	var runs := []
	if not preserve and generation.is_empty() and material_packet.is_empty():
		var recipe := Setup.rectangles(candidate)
		if recipe.has("error"): return refuse(recipe.error)
		runs = recipe.runs
		if runs.size() / 5 > Setup.native_rectangle_budget():
			return refuse("This installed native runtime cannot reopen that detailed authored start; rebuild its GDExtension.")
	# Retained authoring transfers the current native cells. Stamp replay and
	# its rectangle limit apply only when constructing an authored start.
	var definitions := Setup.physical_definitions(candidate)
	if preserve:
		for a: Dictionary in definitions:
			if int(a.instance_id) == reset_id: continue
			if host.physical_actor_session != null:
				var existing_pose: Dictionary = host.physical_actor_session.capture_workbench_assembly(int(a.instance_id))
				if not str(existing_pose.get("pose_error","")).is_empty():
					return refuse("Cannot retain #%d: %s Reset that actor before changing the composition." % [int(a.instance_id),str(existing_pose.pose_error)])
			if pose_overrides.has(int(a.instance_id)):
				var pose: Dictionary = pose_overrides[int(a.instance_id)]
				a.position = pose.position
				a.retained_parts = pose.retained_parts.duplicate(true)
				continue
			var state := body_state(int(a.instance_id))
			if not state.is_empty():
				a.position = state.position
				if state.get("retained_parts",[]).size() > 1:
					a.retained_parts = state.retained_parts.duplicate(true)
				else:
					a.retained_motion = {"rotation":state.rotation,"linear_velocity":state.linear_velocity,
						"angular_velocity":state.angular_velocity}
		_saved_view = {"origin":host.camera_origin,"size":host.current_view_size}
	else:
		_saved_view.clear()
	if art_batches != null: art_batches.executor.canvas_changed(false)
	_cancel()
	# Publish the current owner view before preparation captures its settings
	# revision; the first rendered frame must not invalidate startup construction.
	host.update_worker_frame_state()
	var retained_selection := {}
	if not apply_staged_water and _liquids != null:
		retained_selection = {"policy":_liquids.requested_policy.duplicate(),
			"normalize":_liquids.normalize_water.button_pressed,"geometry":_liquids.geometry_picker.selected,
			"dirty":_liquids._dirty}
	var ok: bool = host.workbench_apply(candidate,definitions,runs,Setup.extent_of(candidate),
		PackedInt32Array(candidate.liquid_policy),candidate.normalize,int(candidate.rule_radius),
		str(candidate.response),preserve,convert_liquid_inventory,resume_play,generation,material_packet,apply_staged_water,authoring_patch)
	if not ok: return refuse(host.microscenario_error)
	object_shard_m4_port.retire("WorldReplacement")
	_cancel_object_shard_pointer("WorldReplacement")
	_object_shard_diagnostic_identity.clear()
	_erosion_pass = 0
	_object_shard_last_transport_hold = ""
	_object_shard_edit_probe.reset({"port_generation":object_shard_m4_port.generation})
	if host.has_method("object_shard_m4_latency_report") and host.object_shard_m4_probe.enabled:
		host.object_shard_m4_probe.retire("WorkbenchReplacement")
	_pending_staged_liquid_selection = retained_selection
	_pending_generated = generated_packet.duplicate(true)
	_pending_material_baseline = material_baseline.duplicate(false)
	_pending_retain_generated = preserve
	_pending_request_serial = int(host.pending_microscenario_apply.serial)
	return true

func install_generated_start(candidate: Dictionary, packet: Dictionary) -> bool:
	if busy(): return refuse("Wait for the current native-owner transaction.")
	if packet.is_empty() or not _generated_dialog.attests(packet):
		return refuse("Generated map is not the current verified native preview; regenerate first.")
	# Explicit dialog confirmation is the only replacement path. No partial
	# native writes occur before the owner's acknowledged prepared commit.
	if not apply(candidate,false,0,false,false,packet): return false
	message = "Installing verified GEN-007 terrain…"
	return true

func new_canvas() -> bool:
	if _liquids == null or _liquids.bridge == null: return refuse("Native policy interface unavailable.")
	if not applied.is_empty() and not host.simulation_worker.has_failed() and not _editable(): return false
	var size := Vector2i(int(_extent[0].value),int(_extent[1].value))
	var policy: PackedInt32Array = _liquids.bridge.default_liquid_policy() if applied.is_empty() else PackedInt32Array(applied.liquid_policy)
	var candidate := Setup.fresh(policy,size)
	if not applied.is_empty(): candidate.rule_radius = int(applied.rule_radius)
	if host.simulation_worker.has_failed(): return host.workbench_restart(candidate)
	return apply(candidate,false,0,false,false,{},{},applied.is_empty())

func load_water_comparison(scene_id: String) -> bool:
	if not _editable(): return false
	if _liquids == null or _liquids.bridge == null: return refuse("Native policy interface unavailable.")
	var policy: PackedInt32Array = _liquids.requested_policy
	if policy.is_empty(): policy = PackedInt32Array(applied.liquid_policy)
	var checked: Dictionary = _liquids.bridge.validate_liquid_policy(policy)
	if not checked.get("accepted",false): return refuse(str(checked.get("refusal",{})))
	var candidate := WaterComparisonScenes.create(scene_id,policy)
	if candidate.is_empty(): return refuse("Unknown Water comparison scene.")
	candidate.rule_radius = maxi(int(candidate.rule_radius),int(checked.receipt.get("minimum_rule_radius",2)))
	# Explicit Load resets the authored scene with the requested law/tuning.
	# It never silently chooses a solver or modifies another law's options.
	if not apply(candidate): return false
	_pending_water_comparison = scene_id
	message = "Preparing Water comparison scene with requested solver / tuning…"
	return true

func _editable_authored_world() -> bool:
	if not _editable(): return false
	var reason := authored_world_change_block_reason()
	return true if reason.is_empty() else refuse(reason)

func authored_world_change_block_reason() -> String:
	if is_instance_valid(architecture_lab) and architecture_lab.authoring_busy():
		return "Wait for the current Architecture action before changing the authored World."
	return art_batches.history_block_reason() if is_instance_valid(art_batches) else ""

func load_material_audition_demo(scene_id: String) -> Dictionary:
	if not _editable(): return {"ok":false,"error":message}
	var reason := authored_world_change_block_reason()
	if not reason.is_empty(): return {"ok":false,"error":reason}
	if _liquids == null or _liquids.bridge == null:
		return {"ok":false,"error":"Native policy interface unavailable."}
	var policy: PackedInt32Array = PackedInt32Array(applied.get("liquid_policy",[]))
	if policy.is_empty(): policy = _liquids.bridge.default_liquid_policy()
	var candidate: Dictionary = preload("res://scripts/workbench_material_audition_scenes.gd").create(scene_id,policy)
	if candidate.is_empty(): return {"ok":false,"error":"Unknown material audition scene."}
	if not apply(candidate,false,0,false,false,{},{},false): return {"ok":false,"error":message}
	_pending_material_demo = scene_id
	message = "Installing material audition scene. Previous scene and its session profile are replaced."
	return {"ok":true,"status":"pending","scene_id":scene_id}

func installed(candidate: Dictionary) -> void:
	if art_batches != null: art_batches.executor.canvas_changed()
	_pending_request_serial = 0
	set_ambient_overlay(0, false)
	if not _pending_retain_generated:
		_pilot_returns.clear()
	else:
		for id: int in _pilot_returns.keys():
			var before := actor(applied,id)
			var after := actor(candidate,id)
			if before.is_empty() or after.is_empty() or before.model != after.model \
					or ActorCatalog.control_for(after).source != "human":
				_pilot_returns.erase(id)
	if not _pending_retain_generated:
		_generated_active = _pending_generated.duplicate(true)
		_material_baseline = _pending_material_baseline.duplicate(false)
	_pending_generated.clear()
	_pending_material_baseline.clear()
	_pending_retain_generated = false
	applied = candidate.duplicate(true)
	if object_shard_m4_port.enabled and uses_fixed_step_flight(applied):
		# Main already retired the old structural journal on this accepted
		# replacement. Keep the new flight owner on its ordinary clock.
		object_shard_m4_port.enabled = false
		_status.custom_minimum_size.y = 0
		host.object_shard_m4_runtime.shutdown()
		if _tool.selected in MOVING_TOOLS: _tool.select(0)
		while _tool.item_count > TOOL_NAMES.size(): _tool.remove_item(_tool.item_count-1)
		_update_object_shard_tool_controls()
	var desired_pilot := _pending_pilot_id if _pending_pilot_id >= 0 else _pilot_instance_id
	_pending_pilot_id = -1
	_pilot_instance_id = 0
	pilot_slot = -1
	if host.physical_actor_session != null:
		var desired := actor(applied,desired_pilot)
		if not desired.is_empty() and ActorCatalog.control_for(desired).source == "human" and ActorCatalog.control_for(desired).enabled:
			_pilot_instance_id = desired_pilot
		else:
			for a: Dictionary in applied.actors:
				if ActorCatalog.control_for(a).source == "human" and ActorCatalog.control_for(a).enabled:
					_pilot_instance_id = int(a.id)
					break
		pilot_slot = host.physical_actor_session.slot_for_instance(_pilot_instance_id)
	var roster_choice := _model.selected
	_model.clear()
	_model_ids = _compact_model_ids()
	for model_id: String in _model_ids: _model.add_item(ActorCatalog.entry(model_id).get("name",model_id))
	_model.select(clampi(roster_choice,0,_model.item_count-1))
	_fill_roster()
	_reload_rollback.clear()
	var policy: Dictionary = host.tower_context.get("liquid_solver_policy",{})
	if policy.has("envelope"): applied.liquid_policy = Array(policy.envelope)
	if _pending_staged_liquid_selection.is_empty():
		_liquids.requested_policy = PackedInt32Array(applied.liquid_policy)
		_liquids._dirty = false
		_liquids.geometry_picker.select(1 if int(applied.rule_radius) == 3 else 0)
		_liquids.normalize_water.set_pressed_no_signal(false)
	else:
		_liquids.requested_policy = _pending_staged_liquid_selection.policy
		_liquids._dirty = bool(_pending_staged_liquid_selection.dirty) or _liquids.requested_policy != PackedInt32Array(applied.liquid_policy)
		_liquids.geometry_picker.select(int(_pending_staged_liquid_selection.geometry))
		_liquids.normalize_water.set_pressed_no_signal(bool(_pending_staged_liquid_selection.normalize))
	_pending_staged_liquid_selection.clear()
	if host.pending_microscenario_apply.get("workbench_adopt_authored_law",false):
		host.workbench_water_options.workbench_wave_flow = false
		water_spray._wave.set_pressed_no_signal(false)
		water_spray._update_wave_controls()
		water_spray._sync_studio_solver()
	_liquids._refresh_choices()
	if not _saved_view.is_empty():
		host.camera_origin = _saved_view.origin
		host.current_view_size = _saved_view.size
		_saved_view.clear()
	else:
		_camera.select(0)
		_zoom = 1
		host.current_view_size = ZOOMS[_zoom]
		host.camera_origin = Vector2.ZERO
	var size := Setup.extent_of(applied)
	_extent[0].value = size.x
	_extent[1].value = size.y
	for axis: int in 2: _position[axis].max_value = size[axis]-1
	if paint_editor == null: _material.select(Setup.MATERIALS.find(int(applied.material)))
	_brush.set_value_no_signal(applied.brush)
	_requested_response = applied.response
	_response.select(Setup.RESPONSES.find(_requested_response))
	fire_enabled = applied.fire
	_fire.set_pressed_no_signal(fire_enabled)
	_stream.set_pressed_no_signal(false)
	_instances.clear()
	_instances.add_item("Observer",0)
	for a: Dictionary in applied.actors:
		_instances.add_item("%d · %s" % [int(a.id),str(a.model).capitalize()],int(a.id))
	select_instance(selected_id(),true)
	if not applied.source.is_empty():
		host.workbench_source(Vector2i(applied.source[0],applied.source[1]),int(applied.source[2]),"configure")
	if not _pending_water_comparison.is_empty():
		var scene := WaterComparisonScenes.description(_pending_water_comparison)
		_name.text = "water-" + _pending_water_comparison
		_camera.select(2)
		set_camera(2)
		message = "%s · %s" % [str(scene.get("label","Water comparison")),str(scene.get("help",""))]
		_pending_water_comparison = ""
	equipment.installed(applied)
	for i: int in 3:
		host.world_shader.set_shader_parameter("rigid_body_data_%d" % i,Vector4(-1000,-1000,0,0))
	host.update_worker_frame_state()
	if paint_editor != null:
		paint_editor.installed()
		paint_editor.select_material(int(applied.material))
		_material.select(_material.get_item_index(int(applied.material)))
	# Refreshing PAINT publishes its own tool status. The acknowledged native
	# installation, actor action and inventory receipt must remain the common
	# Workbench status after that refresh.
	var rounded_on_apply: bool = _liquid_action and bool(candidate.normalize)
	if not _actor_action.is_empty():
		_reveal_selected()
		var state := body_state(selected_id())
		message = "%s %s #%d at %s (session %d)." % [_actor_action,str(state.get("model","")).capitalize(),
			selected_id(),str(state.get("position","?")),host._physical_epoch]
		_actor_action = ""
	elif _liquid_action:
		_liquid_action = false
		message = "Liquid settings applied."
	else:
		message = ("Generated native terrain installed. Place a flyer to explore; save the authored start when ready."
			if not _generated_active.is_empty() else
			"Choose a flyer to pilot, or use Place model to add an independent body.")
	if not _pending_object_shard_scene.is_empty():
		_object_shard_scene = _pending_object_shard_scene
		_pending_object_shard_scene = ""
		enable_object_shard()
		_name.text = "structures-"+_object_shard_scene
		_set_view(Vector2(16,208),Vector2i(480,304))
		message = str(ObjectShardScenes.manifest(_object_shard_scene).instructions)
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt",{}).get("workbench_conversion",{})
	message += _inventory_report(receipt,rounded_on_apply)
	if _pending_actor_workshop:
		_pending_actor_workshop = false
		_name.text = Setup.MIXED_ACTOR_LABEL
		_camera.select(2)
		set_camera(2)
		message = "Mixed Actor Workshop ready. Play, inspect an NPC, Pilot inspected, then Hand back. Paint remains available."
	if not _pending_sandbox_demo.is_empty():
		_name.text = "actor-sandbox-" + _pending_sandbox_demo
		_camera.select(2)
		set_camera(2)
		message = "%s ready · %d physical actors. Play to grab a part or paint; Pause to place / rotate an assembly." % [_pending_sandbox_demo.capitalize(),applied.actors.size()]
		_pending_sandbox_demo = ""
	if not _pending_material_demo.is_empty():
		var scene := preload("res://scripts/workbench_material_audition_scenes.gd").description(_pending_material_demo)
		_name.text = "materials-" + _pending_material_demo
		_camera.select(2)
		set_camera(2)
		message = "%s · %s" % [str(scene.get("label","Material audition")),str(scene.get("help",""))]
		_pending_material_demo = ""
	if not _pending_ambient_example.is_empty():
		_name.text = _pending_ambient_example
		_pending_ambient_example = ""
		_camera.select(2)
		set_camera(2)
		message = "Ambient scene ready. Play, paint Oil or Water nearby, inspect decisions, and edit Behaviour profile. Save stores the authored profile; runtime timers restart on reopen."
	if is_instance_valid(_actor_panel): _actor_panel.refresh(true)
	if reciprocal_panel != null: reciprocal_panel.native_installed(candidate)
	if not OS.get_environment("MAT_AUDITION_LAUNCHER_RECEIPT").is_empty():
		preload("res://tests/support/material_audition_launcher_witness.gd").attach(self)


func _material_counts(counts: Dictionary) -> String:
	var names := PackedStringArray()
	var ids := counts.keys()
	ids.sort()
	for id: Variant in ids:
		var cells := int(counts[id])
		if cells > 0: names.append("%d %s" % [cells,host.material_name(int(id))])
	return ", ".join(names)


func _inventory_report(receipt: Dictionary, rounded_on_apply: bool) -> String:
	if receipt.is_empty(): return ""
	var halo := int(receipt.get("preserved_halo_cells",0))
	var clipped := int(receipt.get("clipped_material_cells",0))
	var losses := PackedStringArray()
	if clipped > 0:
		losses.append("%d cells beyond reserved storage (%s, %d visible Water units)" % [
			clipped,_material_counts(receipt.clipped_materials),int(receipt.clipped_visible_water)])
	# State can also be clipped from an Empty cell or gas compartment. These
	# counts are separate from the material ledger. Each clipped subset is
	# annotated on its total rather than counted twice.
	for field: Array in [["water_overfill","%d pressure overfill units"],["gas_amount","%d gas units"],
			["inertial_cells","inertial state in %d cells"],["pressure_flow_cells","pressure flow in %d cells"]]:
		var total := int(receipt.get("discarded_"+field[0],0))
		var beyond := int(receipt.get("clipped_"+field[0],0))
		if total > 0:
			var loss: String = field[1] % total
			if beyond > 0: loss += " (%d beyond storage)" % beyond
			losses.append(loss)
		elif beyond > 0:
			losses.append(field[1] % beyond + " beyond storage")
	if receipt.get("clipped_thermal_cells",0):
		losses.append("thermal state in %d cells beyond storage" % int(receipt.clipped_thermal_cells))
	if receipt.get("clipped_gas_labels",0):
		losses.append("%d gas labels beyond storage" % int(receipt.clipped_gas_labels))
	var added := int(receipt.get("normalization_produced",0))
	var removed := int(receipt.get("normalization_consumed",0))
	if not receipt.get("requested",false) and not rounded_on_apply and not added and not removed and halo == 0 and losses.is_empty(): return ""
	var report := " Water quantity %d → %d." % [int(receipt.water_before),int(receipt.water_after)]
	if rounded_on_apply or added or removed: report += " Rounding added %d and removed %d Water units." % [added,removed]
	if halo > 0:
		report += " Kept %d cells outside the canvas (%s), including %d visible Water units." % [
			halo,_material_counts(receipt.preserved_halo_materials),int(receipt.preserved_halo_visible_water)]
	if not losses.is_empty(): report += " Discarded " + ", ".join(losses) + "."
	return report


func _water_identity(context: Dictionary) -> String:
	if bool(context.get("wave_flow",{}).get("enabled",false)):
		return "Wave Flow (FreeMass carrier)"
	for assignment: Dictionary in context.get("liquid_solver_policy",{}).get("assignments",[]):
		if int(assignment.material)==CyberCellWorld.WATER:
			return "%s/%s" % [str(assignment.applied_family).trim_suffix("_v1"),assignment.applied_variant]
	return "pending"


func _details_visibility_changed() -> void:
	_details_scroll.visible = _details.visible
	if is_instance_valid(host):
		if _details.is_visible_in_tree(): _cancel()
		host.simulation_worker.set_worker_participation_sampling(_details.is_visible_in_tree())


func _participation_report(snapshot: CyberSimulationSnapshot) -> String:
	if snapshot == null: return "Waiting for the native worker."
	var requested := "Auto" if snapshot.native_worker_request <= 0 else str(snapshot.native_worker_request)
	var result := "%s · native pool %s" % [_processor_label,requested]
	var sample := snapshot.native_worker_participation
	if sample.is_empty() or sample.world_generation != snapshot.render_world_generation:
		return result + " · waiting for a completed tick sample."
	result += ", capacity %d" % int(sample.worker_capacity)
	result += "\nTick %d · %d task claimants (peak in one cell-update phase) · cell-update phase jobs %s" % [
		sample.completed_tick,sample.workers_observed,str(sample.phase_jobs)]
	if sample.has("native_tick_ms"):
		var elapsed: float = sample.native_tick_ms
		var budget_ms := 1000.0/60.0
		result += " · %.2f ms (%.0f%% of the %.2f ms tick budget)" % [elapsed,100.0*elapsed/budget_ms,budget_ms]
	return result + ". An inline owner counts as one claimant. CPU utilization is a separate measure."


func select_instance(id: int, installing: bool = false) -> bool:
	if not installing and busy(): return refuse("Wait for owner acknowledgement.")
	var a := actor(applied,id)
	if a.is_empty() and id != 0: return refuse("Unknown instance.")
	_cancel()
	applied.selected = id
	_instances.select(_instances.get_item_index(id))
	var options: Dictionary = a.get("options",Setup.DEFAULT_OPTIONS)
	for key: String in _fields:
		_fields[key].value = options[key]
		var fleet_tuning: bool = Fleet.index_for_id(str(a.get("model",""))) >= 0
		var flight_plant: bool = str(a.get("model","")) in ActorCatalog.Flight.IDS
		_fields[key].editable = not a.is_empty() and (fleet_tuning or key == "budget" or (not flight_plant and key in ["mass_multiplier","inertia_multiplier"]))
	if not a.is_empty():
		_position[0].value = a.spawn[0]
		_position[1].value = a.spawn[1]
	_sync_roster()
	if not installing:
		_reveal_selected()
		message = "Observer selected." if a.is_empty() else "Selected %s #%d." % [str(a.model).capitalize(),id]
	return true


func _reveal_selected() -> void:
	var state := body_state(selected_id())
	var visible_cells := Rect2(Vector2(host.camera_origin),Vector2(host.current_view_size))
	if not state.is_empty() and not visible_cells.grow(-8).has_point(state.position): focus_selected()


func _change_actor(candidate: Dictionary, id: int, label: String) -> bool:
	if not apply(candidate,true,id,false,not host.paused,{},{},false): return false
	_actor_action = label
	message = "Preparing %s #%d…" % [str(actor(candidate,id).model).capitalize(),id]
	return true


func pilot_model(model: String) -> bool:
	if busy() or applied.is_empty(): return refuse("Wait for the current owner transaction.")
	if not ActorCatalog.supports(model,"human"): return refuse("Unknown or unpiloted model.")
	for other: Dictionary in applied.actors:
		if other.model == model: return pilot_instance(int(other.id))
	_pending_pilot_id = int(applied.next_id)
	var current := actor(applied,selected_id())
	var ok: bool = _replace_actor(model) if not current.is_empty() and current.model != Setup.BARREL else place(model,entered_position())
	if not ok: _pending_pilot_id = -1
	return ok


func place(model: String, pos: Vector2) -> bool:
	if busy() or applied.is_empty(): return refuse("Wait for the current owner transaction.")
	var next := applied.duplicate(true)
	next.actors.append(Setup.instance(model,int(next.next_id),pos))
	next.selected = next.next_id
	next.next_id = int(next.next_id)+1
	return _change_actor(next,int(next.selected),"Placed")

func replace_selected() -> bool:
	if busy() or selected_id() == 0: return refuse("Select a body before replacing it.")
	return _replace_actor(model_choice())


func _replace_actor(model: String) -> bool:
	var next := applied.duplicate(true)
	var old := actor(next,selected_id())
	var replacement := Setup.instance(model,int(next.next_id),Setup.point(old.spawn))
	# A model change keeps the selected instance's applied comparison tuning.
	# Independent placement and the explicit Defaults action still use defaults.
	for key: String in old.options:
		if key == "budget" or (key in ["mass_multiplier","inertia_multiplier"] and model not in ActorCatalog.Flight.IDS) \
				or Fleet.index_for_id(model) >= 0:
			replacement.options[key] = old.options[key]
	next.actors[next.actors.find(old)] = replacement
	next.selected = next.next_id
	next.next_id = int(next.next_id)+1
	return _change_actor(next,int(next.selected),"Switched to")

func remove_selected() -> bool:
	if not _editable(): return false
	if selected_id() == 0: return refuse("Select an instance first.")
	var next := applied.duplicate(true)
	next.actors.erase(actor(next,selected_id()))
	next.selected = 0
	return apply(next,true,0,false,not host.paused,{},{},false)

func save_spawn() -> bool:
	if not _editable(): return false
	if selected_id() == 0: return refuse("Select an instance first.")
	var next := applied.duplicate(true)
	var value := entered_position()
	actor(next,selected_id()).spawn = [value.x,value.y]
	var error := Setup.validate(next)
	if not error.is_empty(): return refuse(error)
	applied = next
	message = "Saved reset spawn at %s" % value
	return true

func capture_spawn() -> bool:
	var state := body_state(selected_id())
	if state.is_empty(): return refuse("No authoritative body position.")
	_position[0].value = state.position.x
	_position[1].value = state.position.y
	return save_spawn()

func move_selected() -> bool:
	if not _editable(): return false
	if selected_id() == 0: return refuse("Select an instance first.")
	var next := applied.duplicate(true)
	var pos := entered_position()
	actor(next,selected_id()).spawn = [pos.x,pos.y]
	return _change_actor(next,selected_id(),"Moved")

func reset_selected() -> bool:
	if host.simulation_worker.has_failed():
		if not _generated_active.is_empty() or not _material_baseline.is_empty():
			return refuse("Native owner failed. Save the settled authored start, then restart the application and Load it.")
		return host.workbench_restart(applied)
	if selected_id() == 0: return refuse("Choose a flyer under Pilot or select an instance to reset.")
	return _change_actor(applied,selected_id(),"Reset")

func restore_start() -> bool:
	if applied.is_empty(): return refuse("No starting setup is installed.")
	if host.simulation_worker.has_failed():
		if not _generated_active.is_empty() or not _material_baseline.is_empty():
			return refuse("Native owner failed. Save the settled authored start, then restart the application and Load it.")
		return host.workbench_restart(applied)
	return apply(applied,false,0,false,false,_generated_active,_material_baseline,false)

func apply_settings() -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	next.response = _requested_response
	var a := actor(next,selected_id())
	if not a.is_empty():
		for key: String in _fields: a.options[key] = _fields[key].value
	return apply(next,true,0,false,not host.paused,{},{},false)

func defaults() -> bool:
	if not _editable(): return false
	var next := applied.duplicate(true)
	next.response = Setup.RESPONSES[0]
	var a := actor(next,selected_id())
	if not a.is_empty(): a.options = Setup.DEFAULT_OPTIONS.duplicate()
	return apply(next,true,0,false,not host.paused,{},{},false)

func reload_definitions(manifest: String = Fleet.DEFAULT_MANIFEST) -> bool:
	if not _editable(): return false
	var previous := Fleet.registry_snapshot()
	if not Fleet.reload_definitions(manifest): return refuse(Fleet.last_error())
	var next := applied.duplicate(true)
	for a: Dictionary in next.actors:
		a.hash = ActorCatalog.definition_hash(str(a.model))
	if not apply(next,true,selected_id(),false,not host.paused,{},{},false):
		Fleet.restore_registry(previous)
		return false
	_reload_rollback = previous
	return true

func apply_liquids() -> bool:
	if busy() or applied.is_empty(): return refuse("Wait for the current owner transaction.")
	var next := applied.duplicate(true)
	var validation: Dictionary = _liquids.bridge.validate_liquid_policy(_liquids.requested_policy)
	if not validation.get("accepted",false): return refuse(str(validation.get("refusal",{})))
	var wave_requested: Variant = host.workbench_water_options.get("workbench_wave_flow",false)
	if not wave_requested is bool: return refuse("Wave Flow selection requires a boolean value.")
	if wave_requested:
		var water_family := ""
		for assignment: Dictionary in validation.get("receipt",{}).get("assignments",[]):
			if int(assignment.get("material",-1)) == CyberCellWorld.WATER:
				water_family = str(assignment.get("applied_family",""))
		if water_family != "freemass_v1":
			return refuse("Wave Flow is an overlay on the FreeMass Water carrier. Choose FreeMass or turn Wave Flow off.")
		var ballistic_requested: Variant = host.workbench_water_options.get("workbench_ballistic",false)
		if not ballistic_requested is bool: return refuse("Ballistic Water selection requires a boolean value.")
	next.liquid_policy = Array(_liquids.requested_policy)
	next.normalize = _liquids.normalize_water.button_pressed
	next.rule_radius = maxi(_liquids.geometry_picker.get_selected_id(),int(validation.receipt.get("minimum_rule_radius",2)))
	if not apply(next,true,0,true,not host.paused): return false
	_liquid_action = true
	message = ("Preparing Wave Flow tuning… retained cells stay; face momentum resets."
		if wave_requested
		else "Preparing liquid settings…")
	return true

func _save_block_reason() -> String:
	if host == null or host.simulation_worker == null or applied.is_empty():
		return "No acknowledged authored start is available to save."
	if not host.pending_microscenario_apply.is_empty() or step_pending or is_flatten_pending():
		return "Wait for the current owner transaction before saving."
	if object_shard_m4_port.enabled and (object_shard_m4_port.pending_count()>0 or not object_shard_m4_port.held_reason().is_empty()):
		return "Wait for acknowledged structural edit completion before saving the authored start."
	# Admission is not completion. Ordinary brush commands and both editors
	# retain the shared owner boundary until native work/receipts are settled.
	var edits: Dictionary = host.simulation_worker.paint_state()
	if bool(edits.get("busy",false)) or bool(edits.get("art_busy",false)) \
			or bool(edits.get("legacy_busy",false)) or bool(edits.get("transition_busy",false)) \
			or bool(edits.get("flatten_busy",false)):
		return "Wait for all native edits and their completion receipts before saving."
	if host.simulation_worker.has_failed():
		for stamp: Array in applied.edits:
			if stamp.size()==4:
				return "Legacy brush execution cannot be confirmed after native failure. Save refused; existing authoring history is retained."
	return ""

func save_setup() -> bool:
	if actor_interaction != null: actor_interaction.cancel("save_authored_start")
	var blocked := _save_block_reason()
	if not blocked.is_empty(): return refuse(blocked)
	if paint_editor != null and not paint_editor.save_allowed(): return false
	if art_batches != null:
		art_batches.executor.poll()
		var executor: RefCounted = art_batches.executor
		if executor.active or executor.waiting or not executor.manual.is_empty() or not executor.manual_inflight.is_empty():
			return refuse("Drawing still queued or executing; Stop/wait before saving.")
	# Polling can settle a receipt or admit deferred work. Recheck every edit
	# fence, but do not reject a settled authored document merely because its
	# live native owner is quarantined. This Save never reads that World.
	blocked = _save_block_reason()
	if not blocked.is_empty(): return refuse(blocked)
	if paint_editor != null and not paint_editor.save_allowed(): return false
	var error := MaterialBaseline.write_named(_name.text,applied,_material_baseline) if not _material_baseline.is_empty() else (
		GeneratedMaps.write_named(_name.text,applied,_generated_active)
		if not _generated_active.is_empty() else Setup.write_named(_name.text,applied))
	if not error.is_empty(): return refuse(error)
	if reciprocal_panel != null:
		var evidence_error: String = reciprocal_panel.save_evidence(_name.text)
		if not evidence_error.is_empty(): message=evidence_error;return true
	message = ("Saved flattened material start · " if not _material_baseline.is_empty() else "Saved generated starting map · " if not _generated_active.is_empty()
		else "Saved starting setup · ") + _name.text
	if object_shard_m4_port.enabled:
		message += ". Load start reconstructs the authored scene. Moving poses, burning progress and shard inventory are not a runtime save."
	if host.simulation_worker.has_failed():
		message += ". Native owner remains failed; restart the application and Load this start. Failed runtime state was not captured."
	if material_audition != null:
		var material_state: Dictionary = material_audition.material_audition_state()
		if material_state.get("changes_behavior",false):
			message += ". Material audition profile is separate: save it in Materials Lab and reapply after loading."
	return true

func load_setup() -> bool:
	if not host.simulation_worker.has_failed() and not _editable(): return false
	var flattened := MaterialBaseline.read_named(_name.text)
	if flattened.has("error"): return refuse(flattened.error)
	if flattened.get("flattened",false):
		if host.simulation_worker.has_failed(): return refuse("Restart the application before loading into a fresh native owner.")
		return apply(flattened.setup,false,0,false,false,{},flattened.baseline)
	var generated := GeneratedMaps.read_named(_name.text)
	if generated.has("error"): return refuse(generated.error)
	if generated.get("generated",false):
		_generated_dialog.open_saved(generated.setup,generated.generation)
		return true
	var result := Setup.read_named(_name.text)
	# Until the owner saves their own file of the name, "my-canvas" opens the
	# built-in water evaluation start, "bench-canvas" the whole-engine
	# benchmark and "stress-canvas" the heavy-activity stress start. A saved
	# file of the name always wins.
	if _name.text in Setup.EQUIPMENT_LABELS and not FileAccess.file_exists(Setup._path(_name.text)):
		return load_equipment_start(_name.text)
	if (_name.text in Setup.BUILTIN_LABELS or _name.text in Setup.ACTOR_LABELS) and not FileAccess.file_exists(Setup._path(_name.text)):
		if _liquids == null or _liquids.bridge == null: return refuse("Native policy interface unavailable.")
		result = {"setup":Setup.builtin(_name.text,_liquids.bridge.default_liquid_policy())}
	if result.has("error"): return refuse(result.error)
	if host.simulation_worker.has_failed(): return host.workbench_restart(result.setup)
	return apply(result.setup)

func art_authoring_state() -> Dictionary:
	if is_flatten_pending(): return {"busy":true,"reason":"Wait for Flatten material capture and baseline adoption."}
	if paint_editor == null: return {"busy":false,"reason":""}
	if paint_editor.recovery_required():
		return {"busy":false,"reason":"Undo the partial human edit or Restore start before agent drawing."}
	var state: Dictionary = host.simulation_worker.paint_state()
	return {"busy":paint_editor.busy() or bool(state.get("busy",false)) or bool(state.get("legacy_busy",false)),"reason":""}

func begin_deferred_art_stroke(stroke: Array, token: int) -> bool:
	return paint_editor != null and paint_editor.begin_deferred_brush(stroke[0],stroke[1],stroke[2],token)

func art_changed_source() -> void:
	if paint_editor != null: paint_editor.invalidate_history("Agent drawing changed the source")

func art_record_receipt(executor: RefCounted, receipt: Dictionary, submission: int) -> void:
	if paint_editor != null: paint_editor.before_agent_receipt(receipt,submission)
	executor.remember(receipt.get("readback",[]))
	if paint_editor != null: paint_editor.after_agent_receipt(receipt)

func finish_art_history() -> void:
	if paint_editor != null: paint_editor.finish_agent_history()

func art_history_guard() -> String:
	if reciprocal_panel != null and reciprocal_panel.busy():
		return "Wait for reciprocal generation before changing World history."
	return art_batches.history_block_reason() if art_batches != null else ""

# Built-in #361 equipment starts. Each asks the native validator for one of
# the existing opt-in liquid presets (inertial Water by default) and sets
# ballistic Water for that World so the nozzle fires real parcels. Either can
# be refused; the start then keeps the policy it was given and the nozzle
# injects resting cells instead. Global defaults never change.
const EQUIPMENT_PRESETS := {Setup.LIQUID_LAB_LABEL:"Water: inertial",Setup.RESERVOIR_LAB_LABEL:"Water: pressure reference"}

func load_liquid_lab(ballistic: bool = true, preset_label: String = "") -> bool:
	return load_equipment_start(Setup.LIQUID_LAB_LABEL,ballistic,preset_label)

func load_equipment_start(label: String, ballistic: bool = true, preset_label: String = "") -> bool:
	if _liquids == null or _liquids.bridge == null: return refuse("Native policy interface unavailable.")
	if label not in Setup.EQUIPMENT_LABELS: return refuse("Unknown equipment start.")
	if not host.simulation_worker.has_failed() and not _editable(): return false
	if preset_label.is_empty(): preset_label = EQUIPMENT_PRESETS[label]
	var policy: PackedInt32Array = _liquids.bridge.default_liquid_policy()
	var note := ""
	var preset := -1
	for index: int in CyberLiquidComparisonPanel.PRESETS.size():
		if CyberLiquidComparisonPanel.PRESETS[index].label == preset_label: preset = index
	var chosen: Dictionary = _liquids._preset(preset) if preset >= 0 else {"ok":false,"error":"preset missing"}
	if chosen.get("ok",false): policy = chosen.request
	else: note = " %s unavailable (%s); using the current policy." % [preset_label,str(chosen.get("error",""))]
	var candidate := Setup.builtin(label,policy)
	var checked: Dictionary = _liquids.bridge.validate_liquid_policy(policy)
	if checked.get("accepted",false):
		candidate.rule_radius = maxi(int(candidate.rule_radius),int(checked.receipt.get("minimum_rule_radius",2)))
	host.workbench_water_options["workbench_ballistic"] = ballistic
	water_spray._ballistic.set_pressed_no_signal(ballistic)
	if host.simulation_worker.has_failed(): return host.workbench_restart(candidate)
	if not apply(candidate): return false
	message = "Loading %s (%s): V valve, [ ] choose valve, G drain, H nozzle, J/K aim." % [label,preset_label] + note
	return true

func _cancel() -> void:
	if host != null: host.cancel_playable_course_input()

func cancel_stroke() -> void:
	if actor_interaction != null: actor_interaction.cancel("input_cancelled")
	if paint_editor != null: paint_editor.cancel_preview()
	_cancel_object_shard_pointer()
	_drag_button = 0
	_pan = false
	_last_cell = Vector2i(-1,-1)
	_stream.set_pressed_no_signal(false)

func toggle_pause() -> bool:
	if applied.is_empty() or busy(): return refuse("Wait for the session.")
	if not host._workbench_frame_error.is_empty(): return refuse(host._workbench_frame_error)
	_cancel()
	host.paused = not host.paused
	# Worker cancellation is immediate. Mirror both edges in the session now,
	# even when Pause and Play occur between two physics callbacks.
	if host.physical_actor_session != null:
		host.physical_actor_session.set_suspended(host.paused)
	host.update_worker_frame_state()
	if not host.paused: host._publish_physical_body_state()
	return true

func step_once() -> bool:
	if not _editable(): return false
	if not host._workbench_frame_error.is_empty(): return refuse(host._workbench_frame_error)
	if not host.paused: return refuse("Pause before requesting one step.")
	var stopped: String = host.tower_context.get("workbench_refusal","")
	if not stopped.is_empty(): return refuse(stopped)
	step_serial += 1
	step_requested = true
	step_pending = true
	return true

func paint(pos: Vector2i, material: int) -> bool:
	# Existing Save/paint-editor tests also use a minimal Control host without
	# Main's instrumentation property. It must remain a valid Workbench client.
	var m4_probe_enabled: bool = host != null and host.has_method("object_shard_m4_latency_report") \
		and host.object_shard_m4_probe.enabled
	if m4_probe_enabled:
		host.object_shard_m4_probe.mark_input(pos, "ordinary_brush")
	if paint_editor != null and paint_editor.recovery_required():
		return refuse("Undo the partial paint edit or Restore start before painting.")
	if art_batches != null:
		var deferred: int = art_batches.executor.defer_manual(pos,material)
		if deferred != 0: return deferred > 0
	if busy() or applied.is_empty(): return false
	if material not in Setup.MATERIALS or not Rect2i(Vector2i.ZERO,Setup.extent_of(applied)).has_point(pos): return false
	var stamp := [pos.x,pos.y,int(applied.brush),material]
	var new_stamp: bool = applied.edits.is_empty() or applied.edits.back() != stamp
	var has_baseline := not _generated_active.is_empty() or not _material_baseline.is_empty()
	if new_stamp and has_baseline and applied.edits.size() >= Setup.MAX_STAMPS:
		return refuse("Starting edit budget exhausted; Flatten again to consolidate the current materials.")
	if new_stamp and not has_baseline and applied.edits.size() >= Setup.MAX_STAMPS:
		# Compact the recorded history into the same cells' merged rectangles.
		var compacted := Setup.compact_edits(applied)
		if compacted.has("error"): return refuse(compacted.error)
		if compacted.edits.size() >= Setup.MAX_STAMPS:
			return refuse("Starting terrain is too detailed to record more paint (%d rectangles)." % Setup.MAX_RUNS)
		applied.edits = compacted.edits
	# The usual stroke path costs one record. Check coalesced capacity only when
	# the maximum possible row count would exceed the reconstruction budget.
	var runs := 2*int(applied.brush)+1
	for old: Array in applied.edits: runs += Setup.stamp_rows(old)
	if not has_baseline and new_stamp and runs > Setup.MAX_RUNS:
		applied.edits.append(stamp)
		var recipe := Setup.rectangles(applied)
		applied.edits.pop_back()
		if recipe.has("error"): return refuse(recipe.error)
	var m4_queue_started_usec: int = Time.get_ticks_usec() if m4_probe_enabled else -1
	var admitted_brush: bool = host.queue_brush_mutation(pos.x,pos.y,int(applied.brush),material)
	if m4_queue_started_usec >= 0:
		host.object_shard_m4_probe.record_duration("queue_admission", m4_queue_started_usec,
			Time.get_ticks_usec(), {"accepted": admitted_brush, "operation": "ordinary_brush",
				"scope": "ordinary_worker_queue_no_native_causal_receipt"})
	if not admitted_brush: return refuse("Worker refused brush.")
	if new_stamp: applied.edits.append(stamp)
	return true

func place_source(pos: Vector2i) -> bool:
	if applied.is_empty() or busy(): return refuse("Wait for the session.")
	var selected_material: int = paint_editor.material_id if paint_editor != null else int(applied.material)
	var next := applied.duplicate(true)
	next.source = [pos.x,pos.y,selected_material]
	var error := Setup.validate(next)
	if not error.is_empty(): return refuse(error)
	if not host.workbench_source(pos,selected_material,"configure"): return refuse("Worker refused source.")
	applied.source = next.source
	_stream.set_pressed_no_signal(false)
	return true

func burst() -> bool:
	if busy() or applied.get("source",[]).is_empty(): return refuse("Place a powder source first.")
	return host.workbench_source(Vector2i(applied.source[0],applied.source[1]),int(applied.source[2]),"burst")

func stream(enabled: bool) -> bool:
	if busy() or applied.get("source",[]).is_empty():
		_stream.set_pressed_no_signal(false)
		return refuse("Place a powder source first.")
	return host.workbench_source(Vector2i(applied.source[0],applied.source[1]),int(applied.source[2]),"stream" if enabled else "stop")

func _set_view(origin: Vector2, size: Vector2i) -> void:
	if applied.is_empty(): return
	if origin!=host.camera_origin or size!=host.current_view_size: _cancel_object_shard_pointer("CameraChanged")
	var extent := Setup.extent_of(applied)
	host.current_view_size = size.min(extent)
	host.camera_origin = origin.clamp(Vector2.ZERO,Vector2(extent-host.current_view_size))
	host.update_worker_frame_state()

func focus_selected() -> void:
	var state := body_state(selected_id())
	if not state.is_empty(): _set_view(Vector2(state.position)-Vector2(host.current_view_size)*0.5,host.current_view_size)

func set_camera(index: int) -> void:
	if applied.is_empty(): return
	if index == 2:
		_set_view(Vector2.ZERO,Setup.extent_of(applied))
	elif index == 1:
		_set_view(host.camera_origin,ZOOMS[_zoom])
		focus_selected()
	else:
		_set_view(host.camera_origin,ZOOMS[_zoom])

func zoom_by(direction: int) -> void:
	if applied.is_empty(): return
	var centre := Vector2(host.camera_origin) + Vector2(host.current_view_size)*0.5
	_zoom = clampi(_zoom+direction,0,ZOOMS.size()-1)
	_camera.select(0)
	_set_view(centre-Vector2(ZOOMS[_zoom])*0.5,ZOOMS[_zoom])

func _input(event: InputEvent) -> void:
	# Release outside the World view must stop a material hold immediately,
	# even when its prior native receipt is still pending.
	if event is InputEventMouseButton and not event.pressed \
		and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		# A Slice has an explicit release-to-commit route inside the canvas.
		# Other releases retire every unadmitted capsule, including off-canvas.
		if _object_shard_pointer_tool != SLICE_TOOL or host == null \
				or not host.world_view.get_global_rect().has_point(event.position):
			_cancel_object_shard_pointer("PointerReleased")
			_drag_button = 0
	if event is InputEventKey and event.pressed and not event.echo and object_shard_m4_port.enabled:
		if event.keycode==KEY_ESCAPE:
			_cancel_object_shard_pointer("Cancelled")
			_drag_button = 0
		elif event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT] and _tool.selected in MOVING_TOOLS:
			_brush.value = clampi(int(_brush.value)+(-1 if event.keycode==KEY_BRACKETLEFT else 1),0,24)
			get_viewport().set_input_as_handled()
			return
	if actor_interaction != null and actor_interaction.global_input(event):
		get_viewport().set_input_as_handled()
		return
	if paint_editor != null and paint_editor.key_input(event):
		get_viewport().set_input_as_handled()
		return
	if host == null or applied.is_empty() or busy(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event is InputEventJoypadButton:
		var pads := Input.get_connected_joypads()
		if event.pressed and event.button_index == JOY_BUTTON_START and not pads.is_empty() and event.device == pads[0]:
			toggle_pause()
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F:
		var mode := (_camera.selected+1) % _camera.item_count
		_camera.select(mode)
		set_camera(mode)
	elif event.keycode == KEY_TAB and not applied.actors.is_empty():
		var current := _instances.selected-1
		var direction := -1 if event.shift_pressed else 1
		var next := posmod(current+direction,applied.actors.size())+1
		select_instance(_instances.get_item_id(next))
	elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
		var index: int = event.keycode-KEY_1
		if not Fleet.valid_index(index): return
		pilot_model(Fleet.stable_id(index))
	else: return
	get_viewport().set_input_as_handled()

func uses_fixed_step_flight(setup_document: Dictionary) -> bool:
	for definition: Dictionary in setup_document.get("actors",[]):
		if StringName(str(definition.model)) in ActorCatalog.Flight.IDS: return true
	return false

func _reserve_object_shard_status_height() -> void:
	# One-line and wrapped receipts must agree on the viewport transform while
	# a visible-cell gesture is held. Genuine viewport resizes still cancel it.
	var style_height := _status.get_theme_stylebox(&"normal").get_minimum_size().y
	_status.custom_minimum_size.y = 2 * _status.get_line_height() + _status.get_theme_constant(&"line_spacing") + style_height

func enable_object_shard() -> bool:
	if host == null or not host.has_method("object_shard_m4_latency_report"): return false
	if host.has_method(&"persistent_operation_allowed"): return refuse("Persistent Areas cannot retain a structural body owner.")
	if uses_fixed_step_flight(applied):
		return refuse("Structures cannot subdivide a 4LY flight actor's Rapier interval. Load a structures scene or remove the flight actor first.")
	if not busy() and not applied.is_empty():
		var extent: Vector2i = Setup.extent_of(applied)
		if extent.x > 1024 or extent.y > 1024:
			return refuse("Choose a 512 or 1024 canvas, or load a structures scene, before enabling destructible structures.")
	object_shard_m4_port.enabled = true
	_reserve_object_shard_status_height()
	if _tool.item_count == TOOL_NAMES.size():
		for label: String in STRUCTURAL_TOOL_NAMES: _tool.add_item(label)
	host.object_shard_m4_runtime.enable(host)
	message = "Structures enabled for this session. Press Play to attach to the existing native World. Supported canvases are 512 or 1024 cells per side."
	return true

func load_object_shard_scene(scene_id: String) -> bool:
	if host.has_method(&"persistent_operation_allowed"): return refuse("Open Structures in the ordinary Workbench. Persistent Areas stores actor-free terrain.")
	if not _editable_authored_world(): return false
	if _liquids == null or _liquids.bridge == null: return refuse("Native policy interface unavailable.")
	var policy: PackedInt32Array = _liquids.requested_policy
	if policy.is_empty(): policy = PackedInt32Array(applied.liquid_policy)
	var candidate: Dictionary = ObjectShardScenes.create(scene_id,policy)
	if candidate.is_empty(): return refuse("Unknown structures scene.")
	if not apply(candidate): return false
	_pending_object_shard_scene = scene_id
	message = "Preparing ordinary Workbench structures scene…"
	return true

func open_object_shard_controls() -> void:
	cancel_stroke()
	if _object_shard_window == null:
		_object_shard_window = Window.new()
		_object_shard_window.title = "Destructible structures · experimental"
		_object_shard_window.size = Vector2i(740,650)
		_object_shard_window.transient = true
		_object_shard_window.close_requested.connect(func() -> void: _object_shard_window.hide())
		add_child(_object_shard_window)
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.offset_left = 12
		scroll.offset_right = -12
		scroll.offset_top = 12
		scroll.offset_bottom = -12
		_object_shard_window.add_child(scroll)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(column)
		var description := Label.new()
		description.text = "Enable on the current canvas or load a playable construction.\nErase lower support stems for a full drop; a narrow cut leaves stumps to land on.\nEraser follows material through collapse. Radius and [ ] set brush width.\nSlice: drag and release; Drill: click. Weathering density/seed are below.\nPause, then Settle into canvas returns a still, nearly aligned body to material cells.\nUp to 16 bodies; each must fit 16,384 cells of bounds. Restore start replaces the scene.\nSave start stores the authored construction, not a live physics checkpoint."
		column.add_child(description)
		_button(column,"Enable on current canvas",enable_object_shard)
		for i: int in range(ObjectShardScenes.IDS.size()):
			var id: String = ObjectShardScenes.IDS[i]
			_button(column,ObjectShardScenes.LABELS[i],func() -> void:
				if load_object_shard_scene(id): _object_shard_window.hide())
		var weather_row := _row(column)
		_spin(weather_row,"Weathering %",_erosion_density,1,100,1,_erosion_density.value)
		_erosion_density.value_changed.connect(func(_value: float) -> void: _cancel_object_shard_pointer("WeatheringDensityChanged"))
		_spin(weather_row,"Seed",_erosion_seed,0,1000000000,1,_erosion_seed.value)
		_erosion_seed.value_changed.connect(func(_value: float) -> void:
			_erosion_pass = 0
			_cancel_object_shard_pointer("WeatheringSeedChanged"))
		_erosion_material_only.text = "Only selected material"
		_erosion_material_only.tooltip_text = "Weathering affects only the material selected in the ordinary material list."
		_erosion_material_only.toggled.connect(func(_enabled: bool) -> void: _cancel_object_shard_pointer("WeatheringMaterialFilterChanged"))
		weather_row.add_child(_erosion_material_only)
		_object_shard_recording = CheckButton.new()
		_object_shard_recording.text = "Record performance timings (optional)"
		_object_shard_recording.tooltip_text = "Start a fresh bounded recording. Stop to keep the last recording, then Save diagnostics. No files are written automatically."
		_object_shard_recording.toggled.connect(set_object_shard_diagnostics_enabled)
		column.add_child(_object_shard_recording)
		var exports := HBoxContainer.new()
		column.add_child(exports)
		_button(exports,"Save diagnostics",save_object_shard_diagnostics)
		_object_shard_export_folder = _button(exports,"Open diagnostics folder",func() -> void:
			var error: Error = OS.shell_open(ProjectSettings.globalize_path("user://objectshard-diagnostics"))
			if error != OK: refuse("Could not open the diagnostics folder: " + error_string(error)))
		_object_shard_export_folder.disabled = not DirAccess.dir_exists_absolute("user://objectshard-diagnostics")
		_object_shard_export_label = Label.new()
		_object_shard_export_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_object_shard_export_label.text = "Timings are off for ordinary play. Enable recording for a comparison, then Save diagnostics."
		column.add_child(_object_shard_export_label)
	_object_shard_recording.set_pressed_no_signal(host.object_shard_m4_probe.enabled)
	_object_shard_window.popup_centered()

func set_object_shard_diagnostics_enabled(recording: bool) -> bool:
	if host == null or not host.has_method("set_object_shard_diagnostics_enabled"): return false
	host.set_object_shard_diagnostics_enabled(recording)
	if _object_shard_recording != null:
		_object_shard_recording.set_pressed_no_signal(recording)
	message = "Performance recording started. Play normally, then Save diagnostics." if recording else "Performance recording stopped. Save diagnostics retains the recorded timings."
	if _object_shard_export_label != null: _object_shard_export_label.text = message
	return true

func save_object_shard_diagnostics() -> Dictionary:
	if host == null or not host.has_method("object_shard_m4_latency_report"):
		return {"ok":false,"outcome":"OrdinaryWorkbenchRequired"}
	var folder: String = "user://objectshard-diagnostics"
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if folder_error != OK:
		refuse("Could not create the diagnostics folder: " + error_string(folder_error))
		return {"ok":false,"outcome":"DirectoryCreateFailed","error":int(folder_error)}
	var source: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	if source.is_empty(): source = OS.get_environment("GITHUB_SHA")
	if source.is_empty(): source = "unavailable"
	var utc: String = Time.get_datetime_string_from_system(true)
	var name: String = "objectshard-"+utc.replace(":","-").replace("T","-")+"-"+str(Time.get_ticks_usec())+".json"
	var path: String = folder.path_join(name)
	var manifest: String = OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")
	var report: Dictionary = {
		"schema":"objectshard-m4-workbench-diagnostics-v1","captured_utc":utc+"Z",
		"source_commit":source,"source_scope":"launcher/environment identity; unavailable is not a source claim",
		"package_manifest_sha256":FileAccess.get_sha256(manifest) if not manifest.is_empty() and FileAccess.file_exists(manifest) else "unavailable",
		"platform":{"os":OS.get_name(),"os_version":OS.get_version(),
			"processor":OS.get_processor_name(),"logical_processors":OS.get_processor_count(),
			"godot":Engine.get_version_info(),"display_backend":DisplayServer.get_name(),
			"rendering_method":RenderingServer.get_current_rendering_method(),
			"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
			"adapter":RenderingServer.get_video_adapter_name(),"adapter_vendor":RenderingServer.get_video_adapter_vendor(),
			"window_size":[get_window().size.x,get_window().size.y],"window_mode":get_window().mode,
			"vsync_mode":DisplayServer.window_get_vsync_mode(get_window().get_window_id())},
		"workload":{"scene_id":_object_shard_scene,"paused":host.paused,
			"camera_origin":[host.camera_origin.x,host.camera_origin.y],
			"view_size":[host.current_view_size.x,host.current_view_size.y],
			"camera_mode":_camera.get_item_text(_camera.selected)},
		"capabilities":host.object_shard_m4_runtime.capabilities.duplicate(true),
		"visible_observation":host.object_shard_m4_runtime.visible_observation(),
		"runtime":host.object_shard_m4_runtime.diagnostics(),
		"probe":host.object_shard_m4_probe.summary(),
		"editing":object_shard_edit_diagnostics(),
		"scope":"explicit local diagnostic snapshot; native progression and renderer callbacks are distinct; physical monitor presentation is not verified"}
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		var error: Error = FileAccess.get_open_error()
		refuse("Could not save diagnostics: " + error_string(error))
		return {"ok":false,"outcome":"FileOpenFailed","error":int(error)}
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		refuse("Diagnostics write failed: " + error_string(write_error))
		return {"ok":false,"outcome":"FileWriteFailed","error":int(write_error)}
	var absolute: String = ProjectSettings.globalize_path(path)
	message = "Diagnostics saved: " + absolute
	if _object_shard_export_label != null: _object_shard_export_label.text = message
	if _object_shard_export_folder != null: _object_shard_export_folder.disabled = false
	return {"ok":true,"outcome":"DiagnosticsSaved","path":absolute,"user_path":path,
		"source_commit":source,"schema":report.schema}

func object_shard_m4_status() -> Dictionary:
	if host == null or not host.has_method("object_shard_m4_latency_report"):
		return {"ok": false, "ready": false, "outcome": "OrdinaryWorkerRequired"}
	return object_shard_m4_port.interface_status(host.simulation_worker, host.latest_snapshot)

func object_shard_user_status(now_ms: int = -1) -> String:
	if host == null or not object_shard_m4_port.enabled: return "Off"
	var runtime: RefCounted = host.object_shard_m4_runtime
	var failure: String = str(runtime.held_reason)
	if failure.is_empty(): failure = object_shard_m4_port.held_reason()
	if failure == "MaterialPreparationFailed":
		return "Held: Material preparation failed · Structures → Save diagnostics; restart application to retry"
	if not failure.is_empty():
		return "Held: %s · Structures → Save diagnostics; Restore start to recover" % failure
	if not runtime.materials_ready(): return "Preparing structure materials…"
	if not runtime.owns_terrain():
		return "Paused · Play to start structures" if host.paused and runtime.phase == "AwaitingFirstNativeTick" else "Starting"
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	var rebuilding: bool = bool(runtime.frame.get("promotion",{}).get("present",false)) \
		or bool(runtime.frame.get("reabsorption",{}).get("present",false))
	for shard: Dictionary in runtime.frame.get("shards",[]):
		rebuilding = rebuilding or bool(shard.get("geometry_pending",false))
	if rebuilding or object_shard_m4_port.pending_count() > 0:
		_object_shard_activity_until_ms = now + 450
	if now < _object_shard_activity_until_ms: return "Editing / rebuilding"
	# Short ACK/readiness phases are ordinary progression, not user states.
	# A wait becomes visible only when its real outstanding receipt is slow.
	if runtime._pending_serial != 0 and runtime._pending_since > 0 \
		and Time.get_ticks_usec()-runtime._pending_since >= 500000:
		return "Waiting for native transaction"
	if host.paused: return "Paused" if runtime.physics_ready() else "Pausing"
	return "Running"


func object_shard_m4_action(pos: Vector2i, action: String,
		observed: Dictionary = {}, witness: Dictionary = {}) -> Dictionary:
	if host == null or not host.has_method("object_shard_m4_latency_report") \
			or applied.is_empty() or busy():
		refuse("ObjectShard M4: no installed or available ordinary Workbench.")
		return {"ok": false, "outcome": "WorkbenchUnavailable"}
	if observed.is_empty() and host.object_shard_m4_runtime.enabled:
		observed = host.object_shard_m4_runtime.visible_observation()
		witness = host.object_shard_m4_runtime.visible_target(pos)
	var uploaded: Dictionary = {"world_generation": host.last_uploaded_world_generation,
		"world_revision": host.last_uploaded_revision,
		"render_serial": host.last_uploaded_render_snapshot_serial}
	var result: Dictionary = object_shard_m4_port.queue_intent(host.simulation_worker,
		host.latest_snapshot, uploaded, observed, action, pos, witness,
		Time.get_ticks_usec())
	if not result.get("ok", false):
		refuse("Structures: " + str(result.get("outcome", "UnknownRefusal")))
	else:
		message = "Moving material operation queued on the native owner."
	return result


func _pick(pos: Vector2i) -> void:
	for a: Dictionary in applied.actors:
		var state := body_state(int(a.id))
		if state.is_empty(): continue
		var local := (Vector2(pos)-Vector2(state.position)).rotated(-float(state.rotation))
		if Setup.bounds(str(a.model)).grow(2).has_point(local):
			select_instance(int(a.id))
			return
	select_instance(0)

func object_shard_edit_diagnostics() -> Dictionary:
	var value: Dictionary = _object_shard_edit_probe.snapshot()
	if host != null and host.object_shard_m4_runtime != null:
		var metrics: Dictionary = host.object_shard_m4_runtime.publication.get("metrics",{})
		var native: Dictionary = {"scope":"cumulative current native coordinator session; islands are geometry observations, not committed fragment counts"}
		for key: String in ["fragments","fragment_refusals","batch_edits","batch_requested_cells","batch_changed_cells","batch_geometry_rebuilds","batch_target_ns","batch_mutation_ns","batch_geometry_ns"]:
			if metrics.has(key): native[key] = metrics[key]
		value["native_session_metrics"] = native
	return value

func _cancel_object_shard_pointer(reason: String = "InputCancelled") -> void:
	if _object_shard_pointer_tool >= 0:
		_object_shard_edit_probe.record("cancel",{"outcome":reason,"tool":_object_shard_pointer_tool,
			"pending":object_shard_m4_port.pending_count(),"unadmitted_domains":_object_shard_segment.get("remaining",[]).size()})
	_object_shard_pointer_tool = -1
	_object_shard_pointer_source_tool = -1
	_object_shard_pointer_capture_usec = 0
	_object_shard_pointer_local = Vector2(-1,-1)
	_object_shard_pointer_attempt.clear()
	_object_shard_pointer_camera.clear()
	_object_shard_segment.clear()
	_object_shard_wait_since = 0
	_object_shard_wait_reason = ""
	_object_shard_slice_committing = false
	_object_shard_slice_commit_usec = 0

func _object_shard_input_mode(event: InputEvent = null) -> int:
	if not object_shard_m4_port.enabled: return -1
	if _tool.selected in MOVING_TOOLS: return _tool.selected
	if _tool.selected != 0: return -1
	if _object_shard_pointer_tool==STRUCTURAL_ERASER_TOOL and _object_shard_pointer_source_tool==0:
		return STRUCTURAL_ERASER_TOOL
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT: return STRUCTURAL_ERASER_TOOL
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT: return STRUCTURAL_ERASER_TOOL
	if paint_editor != null and (paint_editor.tool_name()=="Eraser" \
			or (paint_editor.tool_name()=="Brush" and paint_editor.material_id==0)):
		return STRUCTURAL_ERASER_TOOL
	return -1

func _update_object_shard_tool_controls() -> void:
	var mode: int = _tool.selected if object_shard_m4_port.enabled else -1
	if mode == _object_shard_tool_mode: return
	_object_shard_tool_mode = mode
	_cancel_object_shard_pointer("ToolChanged")
	if paint_editor != null: paint_editor.cancel_preview()
	_brush.editable = mode not in [CUT_MOVING_TOOL,SETTLE_MOVING_TOOL]
	_brush.tooltip_text = "Precision cut removes exactly one visible owned cell." if mode==CUT_MOVING_TOOL \
		else "Radius in cells. Zero targets one cell; [ and ] adjust width."
	_tool.tooltip_text = "Drag a line, then release inside the canvas to commit one bounded owner transaction at the next safe opportunity (within 2 seconds). Escape cancels before admission." if mode==SLICE_TOOL \
		else "Click to drill one circular hole. Radius sets the opening." if mode==DRILL_TOOL \
		else "Hold to erode material. Structures… sets density, seed and material filter." if mode==WEATHERING_TOOL \
		else "Pause, then click one visible body to return its settled material." if mode==SETTLE_MOVING_TOOL \
		else "Hold and drag to edit visible material. Terrain and moving structures share this interaction; release cancels unadmitted work."

func _object_shard_cell_from_local(point: Vector2) -> Vector2i:
	var pixel: Vector2i = host.view_pixel_from_local_point(point)
	return Vector2i(-1,-1) if pixel.x<0 else Vector2i(host.camera_origin.floor())+pixel

func _update_object_shard_cursor() -> void:
	if host.brush_preview == null: return
	var mode: int = _object_shard_input_mode()
	if mode<0:
		if paint_editor != null: host.brush_preview.hide()
		return
	var pos: Vector2i = _object_shard_cell_from_local(host.world_view.get_local_mouse_position())
	if pos.x<0:
		host.brush_preview.hide()
		return
	var area: Rect2 = host.view_content_rect()
	var scale: Vector2 = area.size/Vector2(host.current_view_size)
	var radius: int = 0 if mode in [CUT_MOVING_TOOL,SETTLE_MOVING_TOOL] else clampi(int(_brush.value),0,24)
	var first: Vector2 = Vector2(_object_shard_pointer_start if mode==SLICE_TOOL and _object_shard_pointer_tool==SLICE_TOOL else pos)+Vector2(0.5,0.5)
	var last: Vector2 = Vector2(pos)+Vector2(0.5,0.5)
	var points: PackedVector2Array = ObjectShardFootprint.outline(first,last,float(radius))
	for i: int in points.size(): points[i] = area.position+(points[i]-host.camera_origin.floor())*scale
	host.brush_preview.points = points
	host.brush_preview.show()

func _object_shard_wait(reason: String) -> bool:
	if _object_shard_wait_reason!=reason:
		_object_shard_wait_reason = reason
		_object_shard_edit_probe.record("wait",{"outcome":reason,"tool":_object_shard_pointer_tool,
			"pending":object_shard_m4_port.pending_count()})
	message = "Structural edit waiting: "+reason+(". Escape cancels this committed slice before admission." if _object_shard_slice_committing else ". Release cancels unadmitted work.")
	return true

func object_shard_edit_opportunity() -> bool:
	# Invoked immediately before Main seeks another Rapier motion permit.
	# A fresh visible publication gets one bounded user-edit admission first.
	return _pump_object_shard_pointer()

func _pump_object_shard_pointer(pressed: bool = false) -> bool:
	if _object_shard_pointer_tool not in MOVING_EDIT_TOOLS: return false
	if (_drag_button == 0 and not _object_shard_slice_committing) or _tool.selected != _object_shard_pointer_source_tool or busy() or applied.is_empty():
		_cancel_object_shard_pointer("InputNoLongerActive")
		return false
	if _object_shard_pointer_tool==SLICE_TOOL:
		if not _object_shard_slice_committing: return false
		if Time.get_ticks_usec()-_object_shard_slice_commit_usec>2000000:
			_object_shard_edit_probe.record("refused",{"outcome":"SliceAdmissionDeadline","tool":SLICE_TOOL})
			_cancel_object_shard_pointer("SliceAdmissionDeadline")
			message = "Committed slice could not acquire a safe visible frame within two seconds; no native submission remains."
			return false
	if _object_shard_pointer_camera != [host.camera_origin.floor(),host.current_view_size,host.world_view.size]:
		_cancel_object_shard_pointer("CameraChanged")
		return false
	var pos: Vector2i = _object_shard_cell_from_local(_object_shard_pointer_local)
	if pos.x<0:
		_cancel_object_shard_pointer("OutsideCanvas")
		return false
	var runtime: RefCounted = host.object_shard_m4_runtime
	var mode: int = _object_shard_pointer_tool
	var action: String = "ignite" if mode==IGNITE_MOVING_TOOL else "erase"
	if not runtime.capabilities.get("attached",false):
		if pressed: message = "Structures are not attached yet; press again when ready."
		_object_shard_edit_probe.record("refused",{"outcome":"OwnerNotAttached","tool":mode})
		_cancel_object_shard_pointer("OwnerNotAttached")
		return false
	if not runtime.held_reason.is_empty() or not object_shard_m4_port.held_reason().is_empty():
		_cancel_object_shard_pointer("OwnerHeld")
		return false
	if object_shard_m4_port.pending_count()>0 or not runtime.physics_ready():
		return _object_shard_wait("WaitingForPhysicalReceipt")
	if int(runtime.publication.get("publication_sequence",-1))!=int(runtime.frame.get("publication_sequence",-2)) \
			or not object_shard_m4_port.latest_edit_presented(runtime.publication,runtime.capabilities):
		# Leave one process opportunity for the completed coherent frame to upload.
		# A failed upload cannot indefinitely starve physical progression.
		if _object_shard_wait_since==0: _object_shard_wait_since = Time.get_ticks_usec()
		if Time.get_ticks_usec()-_object_shard_wait_since>250000:
			_object_shard_edit_probe.record("refused",{"outcome":"DisplayedPublicationDeadline","tool":mode})
			_cancel_object_shard_pointer("DisplayedPublicationDeadline")
			return false
		return _object_shard_wait("WaitingForDisplayedPublication")
	_object_shard_wait_since = 0
	_object_shard_wait_reason = ""
	# At most 30 transactions/s, even when paused. The native transaction itself
	# is bounded separately; this interval does not create a stored input queue.
	if not pressed and Time.get_ticks_usec()-_object_shard_last_admission_usec<33333: return false
	var current_groups: Dictionary = {}
	if _object_shard_segment.is_empty():
		var attempt: Array = [runtime.publication.get("publication_sequence",-1),pos,mode,_object_shard_pointer_previous,_erosion_pass if mode==WEATHERING_TOOL else 0]
		if attempt==_object_shard_pointer_attempt: return false
		_object_shard_pointer_attempt = attempt
		var radius: int = 0 if mode==CUT_MOVING_TOOL else clampi(int(_brush.value),0,24)
		var first: Vector2i = _object_shard_pointer_start if mode==SLICE_TOOL else _object_shard_pointer_previous
		if mode in [CUT_MOVING_TOOL,DRILL_TOOL]: first = pos
		var footprint: Dictionary = ObjectShardFootprint.build(first,pos,radius,Setup.extent_of(applied),mode!=SLICE_TOOL)
		if not footprint.ok:
			_object_shard_edit_probe.record("refused",{"outcome":footprint.outcome,"tool":mode})
			message = "Structural footprint is too large; use a narrower or shorter slice."
			_cancel_object_shard_pointer("FootprintCapacity")
			return false
		current_groups = runtime.visible_edit_groups(footprint.cells,mode!=CUT_MOVING_TOOL)
		var owners: Array = current_groups.keys()
		owners.sort()
		# Centre owner has precedence for deliberately placed drill/slice actions.
		if mode in [DRILL_TOOL,SLICE_TOOL]:
			var centre: Dictionary = runtime.visible_target(pos)
			var preferred: int = int(centre.get("owner",0))
			if owners.has(preferred): owners.erase(preferred); owners.push_front(preferred)
		if owners.is_empty():
			_object_shard_pointer_previous = footprint.end
			_object_shard_edit_probe.record("no_eligible",{"outcome":"NoEligibleVisibleMaterial","tool":mode,"requested_cells":footprint.cells.size()})
			if pressed or mode==SLICE_TOOL: message = "No eligible visible material in this footprint."
			if mode==SLICE_TOOL: _cancel_object_shard_pointer("NoEligibleVisibleMaterial")
			return false
		var source_captured: int = _object_shard_pointer_capture_usec
		var input_kind: String = "pointer_event"
		if source_captured<=_object_shard_consumed_capture_usec:
			source_captured = Time.get_ticks_usec()
			input_kind = "held_resample"
		_object_shard_consumed_capture_usec = source_captured
		_object_shard_segment = {"cells":footprint.cells,"end":footprint.end,"remaining":owners,
			"requested_owners":owners.size(),"captured_usec":source_captured,"input_kind":input_kind,"sample_id":_object_shard_sample_id}
	if current_groups.is_empty(): current_groups = runtime.visible_edit_groups(_object_shard_segment.cells,mode!=CUT_MOVING_TOOL)
	while not _object_shard_segment.remaining.is_empty() and not current_groups.has(_object_shard_segment.remaining[0]):
		_object_shard_segment.remaining.pop_front()
	if _object_shard_segment.remaining.is_empty():
		_object_shard_pointer_previous = _object_shard_segment.end
		_object_shard_segment.clear()
		return false
	var owner: int = int(_object_shard_segment.remaining.pop_front())
	var values: Array = current_groups[owner]
	var targets: Array = values if owner>0 else []
	var terrain: Array = values if owner==0 else []
	if owner==0 and action=="erase" and not _object_shard_terrain_history_capacity(terrain.size()):
		_object_shard_edit_probe.record("refused",{"outcome":"AuthoredStartCapacity","tool":mode,"requested_cells":terrain.size()})
		message = "Starting construction edit capacity reached. Save and simplify its authored recipe before more terrain erasure."
		_cancel_object_shard_pointer("AuthoredStartCapacity")
		return false
	var selection: Dictionary = {"probability_ppm":roundi(_erosion_density.value*10000.0) if mode==WEATHERING_TOOL else 1000000,
		"seed":int(_erosion_seed.value)+_erosion_pass if mode==WEATHERING_TOOL else 0,
		"material_filter":paint_editor.material_id if mode==WEATHERING_TOOL and _erosion_material_only.button_pressed and paint_editor != null else -1}
	var origin: Vector2i = terrain[0] if owner==0 else targets[0].position
	var uploaded: Dictionary = {"world_generation":host.last_uploaded_world_generation,
		"world_revision":host.last_uploaded_revision,"render_serial":host.last_uploaded_render_snapshot_serial}
	var admitted_now: int = Time.get_ticks_usec()
	var captured: int = int(_object_shard_segment.captured_usec)
	var result: Dictionary = object_shard_m4_port.queue_intent(host.simulation_worker,host.latest_snapshot,
		uploaded,runtime.visible_observation(),action,origin,{} if owner==0 else targets[0],captured,targets,terrain,selection)
	var detail: Dictionary = {"outcome":result.outcome,"tool":mode,"domain":"terrain" if owner==0 else "structural",
		"owner":owner,"requested_cells":values.size(),"action_id":result.get("action_id",0),
		"radius":0 if mode==CUT_MOVING_TOOL else int(_brush.value),"seed":selection.seed,"probability_ppm":selection.probability_ppm,
		"material_filter":selection.material_filter,
		"captured_usec":captured,"stroke_id":_object_shard_stroke_id,"sample_id":_object_shard_segment.sample_id,
		"input_kind":_object_shard_segment.input_kind}
	_object_shard_edit_probe.record("admitted" if result.get("ok",false) else "uncertain" if result.get("may_have_executed",false) else "refused",detail)
	if result.get("ok",false):
		_object_shard_last_admission_usec = admitted_now
		message = "Structural edit admitted · %d cells · waiting for native completion." % values.size()
		if mode==WEATHERING_TOOL: _erosion_pass += 1
	else:
		message = "Structural edit "+str(result.outcome)+"; no success has been reported."
	if mode in [DRILL_TOOL,SLICE_TOOL]:
		if not _object_shard_segment.remaining.is_empty():
			_object_shard_edit_probe.record("partial",{"outcome":"SingleOwnerPlacement","remaining_owners":_object_shard_segment.remaining.size(),"tool":mode})
			message += " This placement targets one owner; repeat for other overlapping material."
		_cancel_object_shard_pointer("PlacementCommitted")
		_drag_button = 0
	elif _object_shard_segment.remaining.is_empty():
		_object_shard_pointer_previous = _object_shard_segment.end
		_object_shard_segment.clear()
	return result.get("ok",false)

func _object_shard_terrain_history_capacity(maximum_changed: int) -> bool:
	# Reserve a worst-case one-cell record for every possible acknowledged
	# erasure. Never commit live material and discover an unrecordable start.
	var rows: int = maximum_changed
	for stamp: Array in applied.edits: rows += Setup.stamp_rows(stamp)
	if applied.edits.size()+maximum_changed<=Setup.MAX_STAMPS and rows<=Setup.MAX_RUNS: return true
	if not _generated_active.is_empty() or not _material_baseline.is_empty(): return false
	var compacted: Dictionary = Setup.compact_edits(applied)
	if compacted.has("error"): return false
	rows = maximum_changed
	for stamp: Array in compacted.edits: rows += Setup.stamp_rows(stamp)
	if compacted.edits.size()+maximum_changed>Setup.MAX_STAMPS or rows>Setup.MAX_RUNS: return false
	applied.edits = compacted.edits
	return true

func _record_object_shard_terrain_erase(cells: Array) -> void:
	# Record only positively acknowledged ordinary-terrain erasure. Detached
	# changes remain live material and are deliberately absent from start saves.
	if cells.is_empty() or applied.is_empty(): return
	var ordered: Array = cells.duplicate()
	ordered.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.y<b.y or (a.y==b.y and a.x<b.x))
	var row: Array = []
	for cell: Vector2i in ordered:
		if not row.is_empty() and int(row[1])==cell.y and int(row[0])+int(row[2])==cell.x:
			row[2] = int(row[2])+1
		else:
			if not row.is_empty(): applied.edits.append(row)
			row = [cell.x,cell.y,1,1,0]
	if not row.is_empty(): applied.edits.append(row)
	if paint_editor != null: paint_editor.invalidate_history("Structural live edit changed native material")
	if applied.edits.size()>Setup.MAX_STAMPS:
		var compacted: Dictionary = Setup.compact_edits(applied)
		if not compacted.has("error"): applied.edits = compacted.edits


func _world_input(event: InputEvent) -> void:
	var event_capture_usec: int = Time.get_ticks_usec()
	# Capture the user's attempt before eligibility/readiness guards, so a
	# never-admitted press remains diagnosable with timings recording disabled.
	var capture_mode: int = _object_shard_input_mode(event)
	if capture_mode>=0 and ((event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]) \
			or (event is InputEventMouseMotion and _object_shard_pointer_tool>=0 and not _object_shard_slice_committing)):
		var captured_cell: Vector2i = _object_shard_cell_from_local(event.position)
		_object_shard_edit_probe.record("attempt",{"tool":capture_mode,"radius":0 if capture_mode in [CUT_MOVING_TOOL,SETTLE_MOVING_TOOL] else int(_brush.value),
			"position":captured_cell,"input_phase":"press" if event is InputEventMouseButton else "motion",
			"seed":int(_erosion_seed.value)+_erosion_pass if capture_mode==WEATHERING_TOOL else 0,"probability_ppm":roundi(_erosion_density.value*10000.0) if capture_mode==WEATHERING_TOOL else 1000000,
			"material_filter":paint_editor.material_id if capture_mode==WEATHERING_TOOL and _erosion_material_only.button_pressed and paint_editor!=null else -1})
	if object_shard_m4_port.enabled and not host.object_shard_m4_runtime.materials_ready():
		# Preparation admits no paint/cut through an earlier actor or PAINT
		# interceptor, but the retained canvas remains navigable.
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				_pan = event.pressed
				if _pan: _camera.select(0)
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				zoom_by(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
				refuse(object_shard_user_status())
		elif event is InputEventMouseMotion and _pan:
			var area: Rect2 = host.view_content_rect()
			if area.has_area(): _set_view(Vector2(host.camera_origin)-event.relative*Vector2(host.current_view_size)/area.size,host.current_view_size)
		return
	# An external reciprocal job owns this source until it settles, including
	# when its dock is hidden or territory painting is switched off. PAINT's
	# own gesture routing remains unchanged when that separate job is idle.
	if reciprocal_panel != null and reciprocal_panel.busy(): return
	if reciprocal_panel != null and reciprocal_panel.world_input(event): return
	# An M4 moving-body operation can never route through the ordinary terrain
	# painter, including right drag or an active paint-editor interception.
	_update_object_shard_tool_controls()
	var m4_mode: int = _object_shard_input_mode(event)
	var m4_moving_tool: bool = m4_mode>=0
	if not m4_moving_tool and actor_interaction != null and actor_interaction.world_input(event): return
	if not m4_moving_tool and not applied.is_empty() and paint_editor != null \
			and paint_editor.world_input(event): return
	if applied.is_empty() or busy():
		if m4_moving_tool:
			# A blocked or aborted pointer stroke cannot resume after Apply/F2.
			_drag_button = 0
			_cancel_object_shard_pointer()
			_last_cell = Vector2i(-1, -1)
			if event is InputEventMouseButton and event.pressed \
					and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				refuse("ObjectShard M4: WorkbenchUnavailable")
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_cancel_object_shard_pointer()
			_pan = event.pressed
			if _pan: _camera.select(0)
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_cancel_object_shard_pointer()
			zoom_by(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			return
		if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return
		_commit_field()
		if not event.pressed and _object_shard_pointer_tool==SLICE_TOOL:
			# Release is the explicit commit for this one bounded line, not a
			# continuing held pointer. No mouse motion can extend this operation.
			_object_shard_pointer_local = event.position
			_object_shard_slice_committing = true
			_object_shard_slice_commit_usec = event_capture_usec
			_object_shard_pointer_capture_usec = _object_shard_slice_commit_usec
			_object_shard_sample_id += 1
			_drag_button = 0
			_object_shard_edit_probe.record("wait",{"outcome":"SliceCommittedAwaitingSafeOpportunity","tool":SLICE_TOOL})
			message = "Slice committed; waiting for a safe visible edit opportunity. Escape cancels before native admission."
			_pump_object_shard_pointer(true)
			return
		_drag_button = event.button_index if event.pressed else 0
		if not event.pressed: _cancel_object_shard_pointer("PointerReleased")
		_last_cell = Vector2i(-1,-1)
	elif event is InputEventMouseMotion:
		if _pan:
			var area: Rect2 = host.view_content_rect()
			if area.has_area(): _set_view(Vector2(host.camera_origin)-event.relative*Vector2(host.current_view_size)/area.size,host.current_view_size)
			return
	else: return
	var pixel: Vector2i = host.view_pixel_from_local_point(event.position)
	if pixel.x < 0:
		if m4_moving_tool: _cancel_object_shard_pointer()
		return
	var pos := Vector2i(host.camera_origin.floor()) + pixel
	if m4_moving_tool:
		if _object_shard_slice_committing:
			if not (event is InputEventMouseButton and event.pressed): return
			_cancel_object_shard_pointer("NewGesture")
		if _drag_button == 0: return
		if m4_mode == SETTLE_MOVING_TOOL:
			_drag_button = 0
			var result: Dictionary = host.object_shard_m4_runtime.request_reabsorption(pos)
			if not result.get("ok",false): refuse("Settle into canvas: "+str(result.get("outcome","unavailable")))
			else: message = "Native owner is checking a settled material return; inventory stays owned until the physics freeze receipt."
		else:
			var pressed: bool = event is InputEventMouseButton and event.pressed
			if pressed:
				_object_shard_stroke_id += 1
				_object_shard_pointer_tool = m4_mode
				_object_shard_pointer_source_tool = _tool.selected
				_object_shard_pointer_start = pos
				_object_shard_pointer_previous = pos
				_object_shard_pointer_camera = [host.camera_origin.floor(),host.current_view_size,host.world_view.size]
				_object_shard_pointer_attempt.clear()
				_object_shard_segment.clear()
			_object_shard_pointer_local = event.position
			_object_shard_pointer_capture_usec = event_capture_usec
			_object_shard_sample_id += 1
			_pump_object_shard_pointer(pressed)
		return
	if _drag_button == 0 or pos == _last_cell: return
	_last_cell = pos
	if _drag_button == MOUSE_BUTTON_RIGHT or _tool.selected == 0:
		paint(pos,0 if _drag_button == MOUSE_BUTTON_RIGHT else int(applied.material))
		return
	_drag_button = 0
	match _tool.selected:
		1: place(model_choice(),Vector2(pos))
		2: _pick(pos)
		3:
			_position[0].value = pos.x
			_position[1].value = pos.y
			move_selected()
		4: place_source(pos)

func _process(_delta: float) -> void:
	if host == null: return
	_update_object_shard_tool_controls()
	if object_shard_m4_port.enabled:
		var capabilities: Dictionary = host.object_shard_m4_runtime.capabilities
		var identity: Dictionary = {"port_generation":object_shard_m4_port.generation,
			"world_generation":capabilities.get("world_generation",0),"session":capabilities.get("session",0),
			"world_incarnation":capabilities.get("world_incarnation",0),"owner_epoch":capabilities.get("owner_epoch",0),
			"shard_session":capabilities.get("shard_session",0),"transport_generation":capabilities.get("transport_generation",0)}
		if identity!=_object_shard_diagnostic_identity:
			_object_shard_edit_probe.reset(identity)
			_object_shard_diagnostic_identity = identity
			_object_shard_last_transport_hold = ""
	if object_shard_m4_port.enabled and object_shard_m4_port.pending_count() > 0:
		var polled: Dictionary = object_shard_m4_port.poll_results(host.simulation_worker)
		if polled.get("may_have_executed",false) and str(polled.get("outcome",""))!=_object_shard_last_transport_hold:
			_object_shard_last_transport_hold = str(polled.get("outcome",""))
			_object_shard_edit_probe.record("uncertain",{"outcome":_object_shard_last_transport_hold,
				"pending":object_shard_m4_port.pending_count(),"action_id":polled.get("action_id",0)})
	if object_shard_m4_port.enabled and not object_shard_m4_port.results.is_empty():
		var newest: Dictionary = object_shard_m4_port.results.back()
		var newest_id := Vector2i(int(newest.get("port_generation",0)),int(newest.get("action_id",0)))
		if newest_id.x==object_shard_m4_port.generation and (newest_id.x!=_object_shard_seen_result.x or newest_id.y>_object_shard_seen_result.y):
			for terminal: Dictionary in object_shard_m4_port.results:
				var identity := Vector2i(int(terminal.get("port_generation",0)),int(terminal.get("action_id",0)))
				if identity.x!=object_shard_m4_port.generation or (identity.x==_object_shard_seen_result.x and identity.y<=_object_shard_seen_result.y): continue
				_object_shard_seen_result = identity
				var native: Dictionary = terminal.get("native_receipt",{})
				var details: Dictionary = {"outcome":terminal.get("outcome","Unknown"),"action_id":terminal.get("action_id",0)}
				for key: String in ["requested_cells","unique_cells","eligible_cells","changed_cells","removed_cells","changed_owners","geometry_rebuilds","native_edit_ns","target_ns","mutation_ns","geometry_ns","islands_before","islands_after","transaction_id","seed","probability_ppm","material_filter"]:
					details[key] = native.get(key,-1 if key=="material_filter" else 0)
				details["domain"] = native.get("domain","structural")
				for key: String in terminal.get("refusal",{}): details[key] = terminal.refusal[key]
				for key: String in terminal.get("timing",{}): details[key] = terminal.timing[key]
				_object_shard_edit_probe.record("uncertain" if terminal.get("may_have_executed",false) else "receipt",details)
				if terminal.get("may_have_executed",false):
					message = "Structural edit completion is uncertain; further edits are held. Restore start for a fresh owner."
				elif terminal.get("ok",false):
					if native.get("domain","")=="terrain" and native.get("operation","")=="erase":
						_record_object_shard_terrain_erase(native.get("terrain_changed_cells",[]))
					message = "Structural %s applied · %d changed cells · native transaction %d · presentation pending." % [
						str(native.get("operation","edit")),int(native.get("changed_cells",1)),int(native.get("transaction_id",0))]
					if int(native.get("changed_cells",1))==0:
						message = "No eligible material changed · native no-op receipt %d." % int(native.get("transaction_id",0))
						_object_shard_edit_probe.record("no_eligible",{"outcome":"NativeNoOp","action_id":terminal.get("action_id",0),
							"requested_cells":native.get("requested_cells",0),"eligible_cells":native.get("eligible_cells",0)})
					if int(native.get("probability_ppm",1000000))<1000000:
						message += " Weathering seed %d." % int(native.get("seed",0))
				elif terminal.get("outcome","")=="TargetChanged":
					message = "Target changed before execution. Held brushes will acquire a fresh visible target."
				else:
					var refusal: Dictionary = terminal.get("refusal",{})
					message = "Structural edit: "+str(refusal.get("native_outcome",terminal.get("outcome","refused")))+"."
					if not str(refusal.get("detail","")).is_empty(): message += " "+str(refusal.detail)
					elif refusal.get("native_outcome","")=="DestinationUnavailable": message += " Protected contact or foreground owned material blocks this edit."
					else: message += " No material change was confirmed."
		var runtime: RefCounted = host.object_shard_m4_runtime
		if runtime.physics_ready() and object_shard_m4_port.latest_edit_presented(runtime.publication,runtime.capabilities):
			for action_id: int in _object_shard_edit_probe.applied_pending_ids():
				_object_shard_last_presented_action = action_id
				_object_shard_edit_probe.record("presented",{"action_id":action_id,"outcome":"Presented",
					"publication_sequence":runtime.publication.get("publication_sequence",0)})
				if action_id==_object_shard_seen_result.y and message.begins_with("Structural ") and message.contains("presentation pending"):
					message = message.replace("presentation pending","presented")
	_pump_object_shard_pointer()
	if actor_interaction != null: actor_interaction.poll()
	if _ambient_overlay_id > 0 and is_instance_valid(_ambient_overlay):
		var control: Dictionary = host.physical_actor_session.workbench_control(_ambient_overlay_id) if host.physical_actor_session != null else {}
		_ambient_overlay.present(control.get("diagnostics", {}), host.camera_origin.floor(), host.current_view_size, host.view_content_rect())
	_poll_flatten()
	_update_object_shard_cursor()
	if step_pending:
		if host.simulation_worker.has_failed() or not host._workbench_frame_error.is_empty() or not str(host.tower_context.get("workbench_refusal","")).is_empty():
			step_requested = false
			step_pending = false
			refuse(host._workbench_frame_error if not host._workbench_frame_error.is_empty() else str(host.tower_context.get("workbench_refusal","World failed")))
		elif int(host.tower_context.get("workbench_step_serial",-1)) == step_serial:
			step_pending = false
	if _pending_request_serial > 0 and host.pending_microscenario_apply.is_empty():
		_pending_request_serial = 0
		_pending_generated.clear()
		_pending_material_baseline.clear()
		_pending_retain_generated = false
		_pending_water_comparison = ""
		_pending_staged_liquid_selection.clear()
		_pending_object_shard_scene = ""
		_pending_material_demo = ""
		_pending_pilot_id = -1
		_pending_actor_workshop = false
		_pending_sandbox_demo = ""
		_pending_ambient_example = ""
		_actor_action = ""
		_liquid_action = false
		_saved_view.clear()
		_sync_roster()
		refuse(host.microscenario_error if not host.microscenario_error.is_empty() else "The requested change was not installed.")
	if not _reload_rollback.is_empty() and host.pending_microscenario_apply.is_empty():
		Fleet.restore_registry(_reload_rollback)
		_reload_rollback.clear()
	if not applied.is_empty() and _camera.selected == 1: focus_selected()
	var preparing_materials: bool = object_shard_m4_port.enabled and not host.object_shard_m4_runtime.materials_ready()
	if not preparing_materials and Time.get_ticks_msec()-_last_status_ms < 150: return
	_last_status_ms = Time.get_ticks_msec()
	var cursor: Vector2i = host.view_pixel_from_local_point(host.world_view.get_local_mouse_position())
	if cursor.x >= 0: cursor += Vector2i(host.camera_origin.floor())
	var context: Dictionary = host.tower_context
	var source: Dictionary = context.get("workbench_source",{})
	if _stream_was_active and not source.get("stream_enabled",false):
		_stream.set_pressed_no_signal(false)
	_stream_was_active = source.get("stream_enabled",false)
	if host.physical_actor_overlay != null:
		host.physical_actor_overlay.show_workbench_source(source)
		var labels := {}
		if host.physical_actor_session != null:
			for a: Dictionary in applied.get("actors",[]):
				var slot: int = host.physical_actor_session.slot_for_instance(int(a.id))
				var control := ActorCatalog.control_for(a)
				labels[slot] = {"text":"#%d %s · %s" % [a.id,a.model,"PILOT" if int(a.id) == pilot_id() else control.source],
					"color":Color("ffd37b") if int(a.id) == pilot_id() else (Color("c4b4ff") if control.source == "policy" else Color("82e3bb")),
					"selected":int(a.id) == selected_id()}
		host.physical_actor_overlay.show_actor_labels(labels)
	var gcr: Dictionary = context.get("workbench_gcr",{})
	var state := "Preparing" if not host.pending_microscenario_apply.is_empty() else ("Paused" if host.paused else "Playing")
	var reason: String = message
	# Show a current fault separately. Completed request errors are consumed
	# once above; an old rejection must not follow later successful actions.
	var owner_error: String = context.get("workbench_refusal","")
	if host.latest_snapshot != null and host.latest_snapshot.simulation_failed:
		owner_error = host.latest_snapshot.last_tick_error
	if not owner_error.is_empty() and not reason.contains(owner_error):
		reason += " · " + owner_error
	_status.text = "%s · cell %s · %s · %s   |   source %d inserted / %d blocked" % [
		state,cursor,str(applied.get("extent","")),reason,int(source.get("inserted",0)),int(source.get("blocked",0))]
	_status.text += " · pilot " + pilot_description()
	_status.text += " · granular %s · active Water %s" % [gcr.get("response","pending"),_water_identity(context)]
	if object_shard_m4_port.enabled:
		# Status text does not need native/physics readbacks or deep receipt
		# copies. Full source diagnostics remain an explicit evaluator action.
		var runtime: RefCounted = host.object_shard_m4_runtime
		_status.text += " · structures %s · %d/%d bodies" % [object_shard_user_status(),runtime.bridge.bodies.size(),int(runtime.capabilities.get("max_bodies",16))]
		var admission: String = str(runtime.frame.get("admission",{}).get("reason",""))
		if admission == "Discovering":
			_status.text += " · finding structures: %d frontier cells" % int(runtime.frame.admission.get("frontier_cells",0))
		elif admission in ["ComponentCells","BoundingBox","ShapeLimit"]:
			_status.text += " · structure exceeds geometry budget; cut it into smaller connected sections"
		elif admission in ["BodySlots","TotalArea","StorageCapacity"]:
			_status.text += " · material-body budget full; settle bodies into the canvas or restore the scene"
		for shard: Dictionary in runtime.frame.get("shards",[]):
			if shard.get("fragment_deferred",false):
				_status.text += " · split waiting for body budget; surviving material remains in its physical parent"
				break
		if not str(runtime.held_reason).is_empty() or not object_shard_m4_port.held_reason().is_empty():
			# The status label is capped at two lines. Put a protective refusal
			# before routine cell/source counters so it cannot be clipped away.
			_status.text = "Structures " + object_shard_user_status() + "\n" + _status.text
		elif preparing_materials:
			_status.text = "Preparing structure materials…\n" + _status.text
	_status.tooltip_text = _status.text
	if object_shard_m4_port.enabled:
		var bounds: Dictionary = host.object_shard_m4_runtime.capabilities
		_status.tooltip_text += "\nInternal structural phase: " + str(host.object_shard_m4_runtime.phase)
		_status.tooltip_text += "\nMaterial-body bounds: %d cells per body, %d cells combined." % [int(bounds.get("max_body_area",16384)),int(bounds.get("max_total_area",65536))]
	water_spray.refresh(context)
	equipment.refresh(context)
	if _details.visible:
		var selected := body_state(selected_id())
		var policy: Dictionary = context.get("liquid_solver_policy",{})
		var assignments := []
		for a: Dictionary in policy.get("assignments",[]):
			assignments.append("%s %s/%s" % [a.get("name",a.material),a.applied_family,a.applied_variant])
		var selected_row: Dictionary = {}
		var selected_body := -1
		if host.physical_actor_session != null:
			selected_body = host.physical_actor_session.bridge.actor_body_index(host.physical_actor_session.slot_for_instance(selected_id()))
		for receipt: Dictionary in gcr.get("rows",[]):
			if int(receipt.get("id",0))-1 == selected_body: selected_row = receipt
		var delivery: Dictionary = {}
		if host.physical_actor_session != null:
			var ledger: Dictionary = host.rapier_bridge.last_application
			for entry: Dictionary in ledger.get("bodies",[]):
				if int(entry.id)-1 == selected_body:
					delivery = entry
					break
			if delivery.is_empty(): delivery = {"refusal":ledger.get("refusal","pending")}
		var actual := "Observer" if selected.is_empty() else "%s #%d · mass %.3f · inertia %.3f · force ceiling %.2f · torque ceiling %.2f" % [
			selected.model,selected_id(),selected.mass,selected.inertia,selected.force_limit,selected.torque_limit]
		_detail_label.text = "%s\n%s\nWorld requested %s / native %s · body budget %s · native J %s / torque %s · arrivals %s · proxies %s\nRapier application %s\nLiquid r%d · %s\n%s" % [
			_runtime_label,actual,_requested_response,gcr.get("response","pending"),selected_row.get("budget","—"),selected_row.get("impulse","—"),
			selected_row.get("torque","—"),selected_row.get("arrival_count","—"),selected_row.get("proxy_count","—"),str(delivery),
			int(policy.get("maximum_rule_radius",0)),", ".join(assignments),str(ActorCatalog.entry(str(actor(applied,selected_id()).get("model",""))).get("controls",""))]
		_detail_label.text += "\nWorld limits · %s bodies, %s proxies, %s raster cells · arrivals %s bytes" % [
			gcr.get("body_limit","—"),gcr.get("proxy_limit","—"),gcr.get("world_mask_cell_limit","—"),gcr.get("arrival_storage_bytes","—")]
		_detail_label.text += "\n" + _participation_report(host.latest_snapshot)
