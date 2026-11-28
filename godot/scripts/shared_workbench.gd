extends VBoxContainer

const Setup = preload("res://scripts/workbench_setup.gd")
const WaterComparisonScenes = preload("res://scripts/workbench_water_comparison_scenes.gd")
const GeneratedMaps = preload("res://scripts/workbench_generated_map.gd")
const MaterialBaseline = preload("res://scripts/workbench_material_baseline.gd")
const PaintEditor = preload("res://scripts/workbench_paint_editor_controller.gd")
const ArtBatchPanel = preload("res://scripts/art_batch_panel.gd")
const StrataDocument = preload("res://scripts/depth/workbench_layer_document.gd")
const StrataController = preload("res://scripts/depth/workbench_strata_controller.gd")
const Fleet = Setup.Fleet
const ActorCatalog = Setup.ActorCatalog
const ActorInteraction = preload("res://scripts/workbench_actor_interaction.gd")
const AmbientAuthoring = preload("res://scripts/ambient/ambient_authoring.gd")
const RESPONSE_LABELS := ["LA-SA · selective arrivals","LA · all events","LA · events off","RFT · fixed 20"]
const ZOOMS := [Vector2i(240,135),Vector2i(480,270),Vector2i(960,540)]
const TOOL_NAMES := ["Paint","Place body","Select body","Move selected","Place source","Grab physical part","Place / rotate (paused)"]
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
# Created only by the explicit Strata action or a layered document load. The
# ordinary startup keeps its existing World, presentation and publication path.
var strata: Node
# A launcher receipt is emitted only after the existing worker acknowledges the
# first ordinary canvas. Argument recognition alone is not successful startup.
var _launch_admission_emitted := false
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
	_button(row,"Strata Theatre…",open_strata)
	_button(row,"Water Lab…",water_lab.open)
	_picker(row,_camera,["Free camera","Follow selected","Overview"],func(i: int) -> void: set_camera(i))
	_button(row,"−",func() -> void: zoom_by(1))
	_button(row,"+",func() -> void: zoom_by(-1))
	_actor_configuration_button = _button(row,"Configuration…",open_actor_composition)
	_button(row,"Art batches",open_art_batches)
	_button(row,"Batch Lab…",open_batch_lab)
	_button(row,"Architecture…",open_architecture_lab)
	_button(row,"Details",func() -> void: _details.visible = not _details.visible)
	_button(row,"Menu [F2]",func() -> void:
		if host.has_method(&"request_persistent_exit"): host.call(&"request_persistent_exit","launcher")
		else: get_tree().change_scene_to_file("res://feature_launcher.tscn"))
	row = _row(self)
	_picker(row,_tool,TOOL_NAMES)
	_tool.item_selected.connect(func(_index: int) -> void: _cancel())
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
		if not applied.is_empty(): applied.brush = maxi(2,int(value)))
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


func ensure_strata() -> Node:
	if not is_instance_valid(strata):
		strata = StrataController.new()
		add_child(strata)
		strata.mount(self)
	return strata


func open_strata() -> void:
	if host.has_method(&"persistent_operation_allowed"):
		var reason: String = host.call(&"persistent_operation_allowed", "strata", {})
		if not reason.is_empty():
			refuse("Strata Theatre requires the ordinary Workbench. Leave the persistent-area profile through Launcher first.")
			return
	_cancel()
	ensure_strata().open_panel()


func strata_play_edit_reason() -> String:
	return strata.play_edit_reason() if is_instance_valid(strata) else ""


func strata_edit_action(action: String) -> Dictionary:
	return strata.route_editor_action(action) if is_instance_valid(strata) else {"handled":false}


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
	var layer_guard := strata_play_edit_reason()
	if not layer_guard.is_empty():
		refuse("Flatten changes Play material history. " + layer_guard)
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
	if actor_interaction != null: actor_interaction.cancel("flatten")
	var layer_guard := strata_play_edit_reason()
	if not layer_guard.is_empty(): return _refuse_flatten("Flatten changes Play material history. " + layer_guard)
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
	if actor_interaction != null: actor_interaction.cancel("closed")
	cancel_flatten("Flatten cancelled during shutdown; no baseline was adopted.")
	if reciprocal_panel != null: reciprocal_panel.cancel("Workbench exited; experimental generation cancelled.")
	if is_instance_valid(strata): strata.shutdown()

# On edits, build other actors at their actual positions while leaving the
# saved spawn recipe intact. A deliberate restore/load uses saved spawns.
func apply(candidate: Dictionary, preserve: bool = false, reset_id: int = 0,
		convert_liquid_inventory: bool = false, resume_play: bool = false,
		generated_packet: Dictionary = {}, material_baseline: Dictionary = {},
		apply_staged_water: bool = true, pose_overrides: Dictionary = {}, authoring_patch: Dictionary = {},
		retain_layers: bool = false) -> bool:
	if is_instance_valid(strata) and strata.authoring_busy(): return refuse("Finish or stop Strata native authoring before replacing its source.")
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
	_pending_staged_liquid_selection = retained_selection
	_pending_generated = generated_packet.duplicate(true)
	_pending_material_baseline = material_baseline.duplicate(false)
	_pending_retain_generated = preserve
	_pending_request_serial = int(host.pending_microscenario_apply.serial)
	if is_instance_valid(strata): strata.play_apply_submitted(_pending_request_serial,preserve or retain_layers)
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
	if is_instance_valid(strata): strata.play_installed()
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
	_report_launch_admission()

func _report_launch_admission() -> void:
	if _launch_admission_emitted or not "--workbench" in OS.get_cmdline_user_args(): return
	if host == null or host.latest_snapshot == null or host.simulation_worker == null: return
	var generation := int(host.latest_snapshot.render_world_generation)
	if generation <= 0 or applied.is_empty(): return
	_launch_admission_emitted = true
	var extent := Setup.extent_of(applied)
	print("STRATA_WORKBENCH_LAUNCH_ADMITTED " + JSON.stringify({
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"workbench_script":get_script().resource_path,
		"world_generation":generation,
		# Godot's RefCounted identity can have its signed 64-bit high bit set.
		# Text preserves every bit across JSON readers; zero remains invalid.
		"worker_id":str(host.simulation_worker.get_instance_id()),
		"extent":[extent.x,extent.y],
		"strata_enabled":is_instance_valid(strata) and strata.enabled(),
	}))


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
	return apply(applied,false,0,false,false,_generated_active,_material_baseline,false,{},{},true)

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
	var layered: bool = is_instance_valid(strata) and strata.has_document()
	if layered:
		if not strata.save_named(_name.text): return false
	else:
		var error := MaterialBaseline.write_named(_name.text,applied,_material_baseline) if not _material_baseline.is_empty() else (
			GeneratedMaps.write_named(_name.text,applied,_generated_active)
			if not _generated_active.is_empty() else Setup.write_named(_name.text,applied))
		if not error.is_empty(): return refuse(error)
	if reciprocal_panel != null:
		var evidence_error: String = reciprocal_panel.save_evidence(_name.text)
		if not evidence_error.is_empty(): message=evidence_error;return true
	if not layered:
		message = ("Saved flattened material start · " if not _material_baseline.is_empty() else "Saved generated starting map · " if not _generated_active.is_empty()
			else "Saved starting setup · ") + _name.text
	if host.simulation_worker.has_failed():
		message += ". Native owner remains failed; restart the application and Load this start. Failed runtime state was not captured."
	if material_audition != null:
		var material_state: Dictionary = material_audition.material_audition_state()
		if material_state.get("changes_behavior",false):
			message += ". Material audition profile is separate: save it in Materials Lab and reapply after loading."
	return true

func load_setup() -> bool:
	if not host.simulation_worker.has_failed() and not _editable(): return false
	var layered := StrataDocument.read_named(_name.text)
	if layered.has("error"): return refuse(layered.error)
	if layered.get("layered",false):
		if host.simulation_worker.has_failed(): return refuse("Restart the application before loading into a fresh native owner.")
		return ensure_strata().load_document(layered)
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
	var layer_guard := strata_play_edit_reason()
	# A target restriction is a refusal, not an in-flight transaction. Existing
	# Art polling must be able to drain/refuse queued work and honour Stop.
	if not layer_guard.is_empty(): return {"busy":false,"reason":"Art authoring targets Play. " + layer_guard}
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
	if is_instance_valid(strata): strata.cancel_gesture()
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
	var layer_guard := strata_play_edit_reason()
	if not layer_guard.is_empty(): return refuse(layer_guard)
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
	if not host.queue_brush_mutation(pos.x,pos.y,int(applied.brush),material): return refuse("Worker refused brush.")
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
	if actor_interaction != null and actor_interaction.global_input(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(strata) and strata.key_input(event):
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

func _pick(pos: Vector2i) -> void:
	for a: Dictionary in applied.actors:
		var state := body_state(int(a.id))
		if state.is_empty(): continue
		var local := (Vector2(pos)-Vector2(state.position)).rotated(-float(state.rotation))
		if Setup.bounds(str(a.model)).grow(2).has_point(local):
			select_instance(int(a.id))
			return
	select_instance(0)

func _world_input(event: InputEvent) -> void:
	# An external reciprocal job owns this source until it settles, including
	# when its dock is hidden or territory painting is switched off. PAINT's
	# own gesture routing remains unchanged when that separate job is idle.
	if reciprocal_panel != null and reciprocal_panel.busy(): return
	if reciprocal_panel != null and reciprocal_panel.world_input(event): return
	if is_instance_valid(strata) and strata.world_input(event): return
	if actor_interaction != null and actor_interaction.world_input(event): return
	if not applied.is_empty() and paint_editor != null and paint_editor.world_input(event): return
	if applied.is_empty() or busy(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan = event.pressed
			if _pan: _camera.select(0)
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			return
		if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return
		_commit_field()
		_drag_button = event.button_index if event.pressed else 0
		_last_cell = Vector2i(-1,-1)
	elif event is InputEventMouseMotion:
		if _pan:
			var area: Rect2 = host.view_content_rect()
			if area.has_area(): _set_view(Vector2(host.camera_origin)-event.relative*Vector2(host.current_view_size)/area.size,host.current_view_size)
			return
	else: return
	var pixel: Vector2i = host.view_pixel_from_local_point(event.position)
	if pixel.x < 0: return
	var pos := Vector2i(host.camera_origin.floor()) + pixel
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
	if actor_interaction != null: actor_interaction.poll()
	if _ambient_overlay_id > 0 and is_instance_valid(_ambient_overlay):
		var control: Dictionary = host.physical_actor_session.workbench_control(_ambient_overlay_id) if host.physical_actor_session != null else {}
		_ambient_overlay.present(control.get("diagnostics", {}), host.camera_origin.floor(), host.current_view_size, host.view_content_rect())
	_poll_flatten()
	if paint_editor != null and host.brush_preview != null: host.brush_preview.hide()
	if step_pending:
		if host.simulation_worker.has_failed() or not host._workbench_frame_error.is_empty() or not str(host.tower_context.get("workbench_refusal","")).is_empty():
			step_requested = false
			step_pending = false
			refuse(host._workbench_frame_error if not host._workbench_frame_error.is_empty() else str(host.tower_context.get("workbench_refusal","World failed")))
		elif int(host.tower_context.get("workbench_step_serial",-1)) == step_serial:
			step_pending = false
	if _pending_request_serial > 0 and host.pending_microscenario_apply.is_empty():
		if is_instance_valid(strata): strata.play_apply_failed()
		_pending_request_serial = 0
		_pending_generated.clear()
		_pending_material_baseline.clear()
		_pending_retain_generated = false
		_pending_water_comparison = ""
		_pending_staged_liquid_selection.clear()
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
	if Time.get_ticks_msec()-_last_status_ms < 150: return
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
	_status.tooltip_text = _status.text
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
