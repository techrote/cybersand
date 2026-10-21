extends Control

# A finite authored scene consumes the same native recipe that the workbench
# edits. Native owners retain all four materials and finite reaction programmes.
const Data = preload("res://scripts/worldgen_qualification_data.gd")
const Runtime = preload("res://scripts/depth/semantic_plane_runtime.gd")
const DepthView = preload("res://scripts/depth/depth_compositor.gd")
const PLANE_NAMES: Array[String] = ["Play", "Rear", "Atmosphere", "Far"]
var generator: Object
var runtime: CyberSemanticPlaneRuntime
var compositor: CyberDepthCompositor
var bundle: Dictionary = {}
var grammar: Dictionary = {}
var last_error: String = ""
var faulted: bool = false
var paused: bool = true
var seed_index: int = 0
var hud_visible: bool = true
var show_routes: bool = false
var show_sockets: bool = false
var generation_ms: float = 0.0
var _panel: PanelContainer
var _title: Label
var _status: Label
var _seed: OptionButton
var _places: OptionButton
var _overlay: Control
var _time: float = 0.0
var _drag: bool = false
var _visibility := Vector4.ONE
var _plane_checks: Array[CheckBox] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.017,0.025,0.033)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_build_ui()
	resized.connect(_layout)
	if not load_seed(0):
		faulted = true
		_status.text = last_error
	_layout()

func load_seed(index: int) -> bool:
	if index < 0 or index >= Data.SEEDS.size():
		last_error = "Unknown declared seed"
		return false
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		last_error = "Source-matched native generator required"
		return false
	var began: int = Time.get_ticks_usec()
	var candidate: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = candidate.configure(Data.recipe(Data.SEEDS[index]))
	if not configured.get("ok",false):
		last_error = str(configured.get("error","Recipe validation failed"))
		return false
	var generated: Dictionary = candidate.generate_plane_bundle()
	if not generated.get("ok",false):
		last_error = str(generated.get("error","Generation failed"))
		return false
	var owner: CyberSemanticPlaneRuntime = Runtime.new()
	if not owner.install_bundle(generated):
		last_error = owner.last_error
		return false
	var view: CyberDepthCompositor = DepthView.new()
	view.layer_scale = Vector4.ONE
	view.layer_parallax = Vector4(1.0,0.98,0.97,0.95)
	if not view.configure(Vector2i(1024,1024)):
		last_error = view.last_error
		view.free()
		return false
	view.set_view(Vector2.ZERO,Vector2(1024,1024))
	view.set_options({"mode":"hybrid","parallax_strength":0.6,"relief_depth":1.5,
		"relief_slices":3,"fog_strength":0.16,"reflection_strength":0.08,
		"freeze_material_animation":true,"layer_visibility":Vector4.ONE})
	for plane: String in Data.PLANES:
		if not view.apply_layer_packet(plane,owner.snapshot_layer(plane,true)):
			last_error = "Failed complete plane presentation " + plane
			view.free()
			return false
	# Candidate preparation above never mutates the accepted scene or its view.
	if compositor != null:
		remove_child(compositor)
		compositor.queue_free()
	generator = candidate
	runtime = owner
	bundle = generated
	grammar = candidate.get_semantic_plan()
	compositor = view
	add_child(compositor)
	move_child(compositor,1)
	compositor.gui_input.connect(_map_input)
	seed_index = index
	paused = true
	_time = 0.0
	_visibility = Vector4.ONE
	faulted = false
	last_error = ""
	generation_ms = float(Time.get_ticks_usec()-began)/1000.0
	_seed.select(index)
	_title.text = "THE FOURFOLD WORKS"
	for check: CheckBox in _plane_checks: check.set_pressed_no_signal(true)
	_places.clear()
	_places.add_item("Whole map / four districts")
	for place: Dictionary in Data.manifest().subregions: _places.add_item(place.name)
	_layout()
	_status.text = "Seed %d · %d features · %.0f ms\nP run/pause · N single step · O overview\nWheel zoom · middle drag · F8 hide controls" % [Data.SEEDS[index],bundle.features.size(),generation_ms]
	_overlay.queue_redraw()
	return true

func publish_layers(force: bool = false) -> bool:
	for plane: String in Data.PLANES:
		var packet: Dictionary = runtime.snapshot_layer(plane,force)
		if packet.get("failed",false):
			last_error = str(packet.get("error","Native publication failed"))
			faulted = true
			return false
		if packet.get("unchanged",false): continue
		if not compositor.apply_layer_packet(plane,packet):
			last_error = "Rejected plane publication " + plane
			faulted = true
			return false
	return true

func _process(delta: float) -> void:
	if faulted or runtime == null: return
	if not paused: _time += delta
	compositor.set_time(_time)
	var step: Dictionary = runtime.advance(delta,paused)
	if not step.get("ok",false):
		faulted = true
		last_error = str(step.get("error",runtime.last_error))
		_status.text = last_error
		return
	publish_layers()

func step_once() -> bool:
	if runtime == null or faulted: return false
	paused = true
	var result: Dictionary = runtime.step_once()
	if not result.get("ok",false):
		last_error = runtime.last_error
		return false
	return publish_layers(true)

func reset_scene() -> bool:
	if runtime == null: return false
	var reset: Dictionary = runtime.reset_bundle(runtime.generation(),str(bundle.revision))
	if not reset.get("accepted",reset.get("ok",false)):
		last_error = str(reset.get("error",runtime.last_error))
		return false
	paused = true
	_time = 0.0
	return publish_layers(true)

func set_hud_visible(value: bool) -> void:
	hud_visible = value
	_panel.visible = value
	_layout()

func show_overview() -> void:
	if compositor != null: compositor.set_view(Vector2.ZERO,Vector2(1024,1024))
	_overlay.queue_redraw()

func show_region(index: int) -> void:
	if compositor == null or index < 0 or index > 3: return
	compositor.set_view(Vector2((index%2)*512,(index/2)*512),Vector2(512,512))
	_overlay.queue_redraw()

func show_subregion(index: int) -> void:
	var places: Array = Data.manifest().subregions
	if compositor == null or index < 0 or index >= places.size(): return
	var entry: Dictionary = places[index]
	var all: Dictionary = Data.feature_map(bundle)
	for feature: Dictionary in bundle.features:
		if feature.rule_id == entry.rule and all.get(feature.parent,{}).get("rule_id","") == entry.district:
			var bounds: Rect2i = feature.bounds
			compositor.set_view(Vector2(bounds.position)-Vector2(8,8),Vector2(bounds.size)+Vector2(16,16))
			_title.text = str(entry.name).to_upper()
			break
	_overlay.queue_redraw()

func set_layer_visible(index: int, value: bool) -> void:
	if index < 0 or index >= 4 or compositor == null: return
	_visibility[index] = 1.0 if value else 0.0
	compositor.set_options({"layer_visibility":_visibility})

func set_diagnostics(routes: bool, sockets: bool) -> void:
	show_routes = routes
	show_sockets = sockets
	_overlay.queue_redraw()

func _draw_overlay() -> void:
	if compositor == null: return
	if show_routes:
		for path: Dictionary in Data.route_paths(bundle,grammar):
			var color := Color(0.18,1.0,0.84,0.8) if path.kind == "primary" else Color(1.0,0.72,0.20,0.85)
			var points: Array = path.points
			for i: int in range(1,points.size()):
				_overlay.draw_line(compositor.position+compositor.get_layer_screen_position(Vector2(points[i-1]),0),compositor.position+compositor.get_layer_screen_position(Vector2(points[i]),0),color,2.0)
	if show_sockets:
		for socket: Dictionary in grammar.get("sockets",[]):
			var p := Vector2(float(socket.x),float(socket.y))
			_overlay.draw_circle(compositor.position+compositor.get_layer_screen_position(p,0),4.0,Color(1.0,0.28,0.62))

func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE: _drag = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var factor: float = 0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
			var extent: Vector2 = (compositor.view_size*factor).clamp(Vector2(128,128),Vector2(1024,1024))
			var origin: Vector2 = compositor.camera_origin+(compositor.view_size-extent)*0.5
			compositor.set_view(origin,extent)
			_overlay.queue_redraw()
	if event is InputEventMouseMotion and _drag:
		compositor.set_camera(compositor.camera_origin-event.relative/compositor.content_rect().size*compositor.view_size)
		_overlay.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: _drag = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_P,KEY_SPACE: paused = not paused
		KEY_N: step_once()
		KEY_R: reset_scene()
		KEY_O: show_overview()
		KEY_F8: set_hud_visible(not hud_visible)
		KEY_ESCAPE: get_tree().change_scene_to_file("res://main.tscn")

func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_panel = PanelContainer.new()
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",12)
	margin.add_child(rows)
	_title = Label.new()
	_title.text = "THE FOURFOLD WORKS"
	_title.add_theme_font_size_override("font_size",21)
	rows.add_child(_title)
	var subtitle := Label.new()
	subtitle.text = "GEN-007 · one place, four material worlds\n1024 × 1024 total cells"
	rows.add_child(subtitle)
	_seed = OptionButton.new()
	for seed: int in Data.SEEDS: _seed.add_item("Seed %d"%seed)
	_seed.item_selected.connect(func(index: int) -> void:
		if not load_seed(index):
			_seed.select(seed_index)
			_status.text = last_error)
	rows.add_child(_seed)
	_places = OptionButton.new()
	_places.item_selected.connect(func(index: int) -> void:
		if index == 0: show_overview()
		else: show_subregion(index-1))
	rows.add_child(_places)
	var controls := HBoxContainer.new()
	for label: String in ["Run / pause","Step","Reset"]:
		var button := Button.new()
		button.text = label
		if label == "Run / pause": button.pressed.connect(func() -> void: paused = not paused)
		elif label == "Step": button.pressed.connect(step_once)
		else: button.pressed.connect(reset_scene)
		controls.add_child(button)
	rows.add_child(controls)
	for index: int in range(4):
		var check := CheckBox.new()
		check.text = PLANE_NAMES[index]
		check.button_pressed = true
		check.toggled.connect(func(value: bool) -> void: set_layer_visible(index,value))
		rows.add_child(check)
		_plane_checks.append(check)
	var routes := CheckBox.new()
	routes.text = "Show final route skeleton"
	routes.toggled.connect(func(value: bool) -> void: set_diagnostics(value,show_sockets))
	rows.add_child(routes)
	var sockets := CheckBox.new()
	sockets.text = "Show semantic sockets"
	sockets.toggled.connect(func(value: bool) -> void: set_diagnostics(show_routes,value))
	rows.add_child(sockets)
	var note := Label.new()
	note.text = "Copper Choir / Frost Observatory\nEmber Terraces / Basalt Archive\n\nEight galleries share reusable cabinets,\nservice geometry and optional loop courts.\n\nThe eight feeds supply ordinary reagents.\nNative kernels produce the observed products."
	note.add_theme_color_override("font_color",Color(0.65,0.78,0.81))
	rows.add_child(note)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_status)
	add_child(_panel)

func _layout() -> void:
	if _panel == null: return
	_panel.position = Vector2(12,12)
	_panel.size = Vector2(330,maxf(620,size.y-24))
	if compositor != null:
		compositor.position = Vector2(354,0) if hud_visible else Vector2.ZERO
		compositor.size = Vector2(maxf(1,size.x-compositor.position.x),size.y)
	_overlay.queue_redraw()
