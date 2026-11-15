extends Control

const Lab = preload("res://scripts/wave_flow_session.gd")
const Overlay = preload("res://scripts/physical_actor_overlay.gd")
var lab: Node2D
var scene_picker: OptionButton
var solver_picker: OptionButton
var workers: SpinBox
var substeps: SpinBox
var tick_rate: SpinBox
var physics_rate: SpinBox
var size_picker: OptionButton
var pause_button: Button
var status_label: Label
var view: TextureRect
var overlay: CyberPhysicalActorOverlay
var image: Image
var texture: ImageTexture
var paused: bool = true
var _native_due: float = 0.0
var _display_due: float = 0.0
var _status_due: float = 0.0
var _last_ticks: int = 0
var _previous_physics_rate: int = 60
var _previous_project_physics_rate: int = 60


func _ready() -> void:
	_previous_physics_rate = Engine.physics_ticks_per_second
	_previous_project_physics_rate = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	var background := ColorRect.new()
	background.color = Color("111821")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	_label(column, "WAVE FLOW / EXPERIMENTAL WATER", 26)
	_label(column, "Choose a scene and solver, then Reset and Run. Space pauses; D disturbs the pool. Needle: W thrust, A/D turn, S reverse. F2 returns to the launcher.", 16)
	var rows := HFlowContainer.new()
	column.add_child(rows)
	scene_picker = OptionButton.new()
	for label: String in Lab.LABELS: scene_picker.add_item(label)
	rows.add_child(scene_picker)
	solver_picker = OptionButton.new()
	for label: String in ["Wave Flow (experimental)", "FreeMass", "Inertial", "PressureFlow reference"]: solver_picker.add_item(label)
	rows.add_child(solver_picker)
	workers = _number(rows, "Workers", 1, 32, mini(4, OS.get_processor_count()))
	substeps = _number(rows, "Wave substeps", 1, 8, 3)
	size_picker = OptionButton.new()
	for side: int in [256, 512, 1024, 2048]: size_picker.add_item("%d × %d" % [side, side], side)
	size_picker.select(1)
	rows.add_child(size_picker)
	_button(rows, "Reset scene", reset_scene)
	pause_button = _button(rows, "Run", toggle_pause)
	_button(rows, "Single tick", single_tick)
	_button(rows, "Disturb pool", disturb)
	var rates := HFlowContainer.new()
	column.add_child(rates)
	tick_rate = _number(rates, "Native ticks/s", 1, 120, 60)
	physics_rate = _number(rates, "Rapier ticks/s", 30, 120, 60)
	physics_rate.value_changed.connect(_set_physics_rate)
	_set_physics_rate(physics_rate.value)
	var reset_hint: Label = _label(rates, "Apply scene, solver, size, workers and substeps with Reset.", 15)
	reset_hint.custom_minimum_size.x = 380
	status_label = _label(column, "Loading native runtime…", 16)
	view = TextureRect.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(128, 128)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Deliberately flat material colours: decorative shader waves would hide the
	# solver's actual free surface. Input is the native copied display projection.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment(){int m=int(round(texture(TEXTURE,UV).r*255.0)); vec3 c=vec3(0.025,0.04,0.065); if(m==3)c=vec3(0.18,0.57,0.91); else if(m!=0)c=vec3(0.5,0.56,0.62); COLOR=vec4(c,1.0);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	view.material = material
	column.add_child(view)
	overlay = Overlay.new()
	view.add_child(overlay)
	_label(column, "Experimental limits: no physical-state saves, buoyancy or retained sideways waterfall momentum. Water-initiated chemistry, coherence and sinking through lighter liquids are unavailable. Other materials keep their own interactions.", 15)
	lab = Lab.new()
	lab.visible = false
	add_child(lab)
	if reset_scene(): print("WAVE_FLOW_EVALUATION_READY")


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _number(parent: Node, text: String, minimum: int, maximum: int, value: int) -> SpinBox:
	var box := HBoxContainer.new()
	parent.add_child(box)
	var label: Label = _label(box, text, 15)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.value = value
	box.add_child(spin)
	return spin


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _set_physics_rate(value: float) -> void:
	# The established Rapier bridge reads its step length from ProjectSettings.
	# Update both clocks so 120 steps/s means 1/120-second steps, not double speed.
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", int(value))
	Engine.physics_ticks_per_second = int(value)


func reset_scene() -> bool:
	paused = true
	pause_button.text = "Run"
	_native_due = 0.0
	if not lab.configure(Lab.SCENES[scene_picker.selected], Lab.SOLVERS[solver_picker.selected],
		int(workers.value), int(substeps.value), size_picker.get_selected_id()):
		status_label.text = "Refused: " + str(lab.error)
		return false
	image = null
	texture = null
	_last_ticks = 0
	_status_due = 0.0
	_present()
	_status(0.0)
	return true


func toggle_pause() -> void:
	if lab == null or lab.world == null or not lab.error.is_empty(): return
	paused = not paused
	_native_due = 0.0
	pause_button.text = "Run" if paused else "Pause"


func single_tick() -> void:
	if not paused or lab.world == null: return
	if not lab.step(): status_label.text = "Stopped: " + str(lab.error)
	_present()
	_status(0.0)


func disturb() -> void:
	if lab == null or lab.world == null: return
	lab.disturb(-1)
	_present()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_SPACE:
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_D and lab.scene_id != "needle":
		disturb()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if paused or lab == null or lab.world == null: return
	var turn: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var lift: float = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	lab.tick_physics({"move":Vector2(turn, lift), "trim":turn, "primary":Input.is_physical_key_pressed(KEY_W)})


func _process(delta: float) -> void:
	if lab == null or lab.world == null: return
	if not paused:
		_native_due += delta
		var started: int = Time.get_ticks_usec()
		var dispatched: int = 0
		while _native_due >= 1.0 / tick_rate.value and dispatched < 4:
			# Bounded catch-up supports 120 native Hz at a 60 Hz display. Give
			# input/presentation another turn after at most four ticks or 8 ms.
			_native_due -= 1.0 / tick_rate.value
			dispatched += 1
			if not lab.tick_native():
				paused = true
				pause_button.text = "Run"
				break
			if lab.scene_id == "deep_pool" and lab.ticks % 180 == 0: lab.disturb(-1)
			if Time.get_ticks_usec() - started >= 8000: break
		_native_due = minf(_native_due, 1.0 / tick_rate.value)
	_display_due += delta
	if _display_due >= 1.0 / 30.0:
		_display_due = 0.0
		_present()
	_status_due += delta
	if _status_due >= 0.5:
		_status(float(lab.ticks - _last_ticks) / _status_due)
		_last_ticks = lab.ticks
		_status_due = 0.0


func _present() -> void:
	if lab.world == null: return
	var bytes: PackedByteArray = lab.world.get_cells()
	if bytes.size() != lab.extent.x * lab.extent.y: return
	image = Image.create_from_data(lab.extent.x, lab.extent.y, false, Image.FORMAT_R8, bytes)
	if texture == null:
		texture = ImageTexture.create_from_image(image)
		view.texture = texture
	else: texture.update(image)
	var scale_factor: float = minf(view.size.x / lab.extent.x, view.size.y / lab.extent.y)
	var fitted := Vector2(lab.extent) * scale_factor
	var parts: Array = [] if lab.actors == null else lab.actors.render_parts()
	overlay.present(parts, Vector2.ZERO, lab.extent, Rect2((view.size - fitted) * 0.5, fitted))


func _status(achieved_rate: float) -> void:
	var status: Dictionary = lab.status()
	if not str(status.get("error", "")).is_empty():
		status_label.text = "Stopped: " + str(status.error)
		return
	status_label.text = "%s · tick %d · %.2f ms native · %.1f ticks/s achieved · %d display FPS\nWorkers %d observed / %d requested · strips %d · solved chunks %d · Water %s (change %+d) · side state %.1f MiB · resident %.1f MiB · contacts %d" % [
		status.solver, status.completed_tick, status.native_tick_ms, achieved_rate, Engine.get_frames_per_second(),
		status.workers_observed, status.workers_requested, status.last_tasks, status.last_solved_chunks,
		status.water_quantity, status.quantity_delta, float(status.storage_bytes) / 1048576.0,
		float(status.resident_cell_bytes) / 1048576.0, status.contacts]


func _exit_tree() -> void:
	Engine.physics_ticks_per_second = _previous_physics_rate
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", _previous_project_physics_rate)
	if lab != null: lab.close()
