extends RefCounted

# Experimental Water controls for the real development Workbench. Wave Flow is
# a construction-time overlay on the FreeMass carrier: controls below stage a
# new World and Apply rebuilds it while retaining cells. Retained Wave face
# momentum is intentionally reset on every rebuild.

var host: Control
var _requested: Dictionary = {}
var _had_ballistic := false
var _ballistic := CheckButton.new()
var _signed := CheckButton.new()
var _spray := CheckButton.new()
var _jet := CheckButton.new()
var _pf_gas := CheckButton.new()
var _pf_c2048 := CheckButton.new()
var _face := CheckButton.new()
var _fine := CheckButton.new()
var _wave := CheckButton.new()
var _studio_solver := OptionButton.new()
var _wave_preset := OptionButton.new()
var _worker_threads := SpinBox.new()
var _wave_status := Label.new()
var _wave_dialog_status := Label.new()
var _wave_notice := Label.new()
var _wave_applied_fields: Dictionary = {}
var _wave_scroll := ScrollContainer.new()
var _spray_scroll := ScrollContainer.new()
var _wave_window := Window.new()
var _spray_window := Window.new()
var _scene_picker := OptionButton.new()
var _non_wave_options: Dictionary = {}
var _non_wave_policy := PackedInt32Array()
var _non_wave_normalize := false
var _inertial_signed_preference := false
var _wave_request_serial := 0
var _status := Label.new()
var _fields: Dictionary = {}
var _wave_fields: Dictionary = {}
var _jet_point: Callable
var _workbench: Control
var _water_pages: Dictionary = {}
var _fallback_message := ""
const ComparisonScenes = preload("res://scripts/workbench_water_comparison_scenes.gd")

const SPINS := [
	["launch_scale", "Launch ×", 0.0, 8.0, 0.1, 1.6],
	["threshold", "Threshold", 0.0, 3.0, 0.05, 0.3],
	["upward_bias", "Up bias", 0.0, 1.0, 0.05, 0.72],
	["budget", "Budget", 0, 512, 1, 64],
	["reaction_gain", "Reaction", 0.0, 4.0, 0.1, 0.0],
	["jet_angle", "Jet°", -180.0, 180.0, 1.0, -75.0],
	["jet_speed", "Jet speed", 0.0, 6.0, 0.1, 3.2],
	["jet_rate", "Jet rate", 0, 16, 1, 3],
]
const FACE_SPINS := [
	["workbench_face_budget", "Face rate", 1, 1024, 1, 320],
	["workbench_face_speed", "Face speed", 0, 512, 8, 288],
	["workbench_face_period", "Face period", 1, 64, 1, 1],
	["workbench_face_min_height", "Face min h", 2, 64, 1, 4],
]
const CONSTRUCTION_SWITCHES := [
	["workbench_ballistic", "Ballistic Water"],
	["workbench_inertial_signed", "IN signed"],
	["workbench_face_release", "Face release"],
	["workbench_fine_cores", "Fine cores"],
]
# Every kinetic Wave constant that is safe to vary without changing the fixed
# point representation or violating the two-face conservation bound.
const WAVE_SPINS := [
	["workbench_wave_substeps", "Rounds", 1, 8, 1, 1, "Solver rounds per native tick; fastest overall speed control."],
	["workbench_wave_active_rows", "Active rows", 1, 32, 1, 32, "Maximum stack depth participating in head response."],
	["workbench_wave_gain", "Gain", 0, 512, 1, 32, "Open-surface head-to-horizontal-flux acceleration."],
	["workbench_wave_gain_confined", "Confined gain", 0, 512, 1, 4, "Head acceleration for confined stacks. This is not PressureFlow's pressure field or gas model."],
	["workbench_wave_stiffness", "Stiffness", 1, 4096, 1, 256, "Sealed overfill stiffness. Native admission requires at least Active rows."],
	["workbench_wave_damp_shift", "Damp shift", 0, 16, 1, 7, "Momentum loss is roughly 1 / 2^N; larger = livelier/less damping."],
	["workbench_wave_coast", "Coast", 0, 65535, 1, 16, "Minimum inertia allowed to coast against a small head difference."],
	["workbench_wave_level_shift", "Level shift", 0, 16, 1, 3, "Depth levelling divisor 2^N; smaller = more aggressive lateral levelling."],
	["workbench_wave_sleep_after", "Sleep after", 1, 3600, 1, 30, "Quiet native ticks before a chunk sleeps."],
	["workbench_wave_wake_peak", "Wake move", 0, 65535, 1, 1, "Whole-unit movement required to hold activity. Zero effectively prevents sleep."],
	["workbench_wave_rest_head", "Rest head", 0, 65535, 1, 1, "Head difference eligible for the small-step rest rule."],
	["workbench_wave_stick", "Stick flux", 0, 65535, 1, 512, "Flux below this threshold is discarded inside Rest head."],
	["workbench_wave_calm", "Calm flux", 0, 65535, 1, 512, "Below this flux, the stronger calm damping path is used."],
	["workbench_wave_calm_damp_shift", "Calm damp", 0, 16, 1, 3, "Low-flux damping shift; larger = less damping."],
	["workbench_wave_maximum_mass", "Sealed mass cap", 255, 65535, 1, 32000, "Mass at which a sealed stack refuses further lateral inflow."],
	["workbench_wave_empty_pour_shift", "Empty pour", 1, 8, 1, 2, "Donor share into Empty is 1 / 2^N. One is the fastest conservative setting."],
	["workbench_wave_flow_share_shift", "Wet share", 1, 8, 1, 1, "Donor share between wet neighbours is 1 / 2^N. One is the conservative maximum."],
	["workbench_wave_adhesion_shift", "Adhesion shift", 0, 8, 1, 1, "Surface adhesion film is Water film / 2^N. Larger = less sticky."],
]
const WAVE_PRESETS := [
	{"label":"v2 defaults","values":{}},
	{"label":"Lively","values":{
		"workbench_wave_substeps":2,"workbench_wave_gain":48,"workbench_wave_gain_confined":8,
		"workbench_wave_stiffness":384,"workbench_wave_damp_shift":8,"workbench_wave_coast":24,
		"workbench_wave_level_shift":2,"workbench_wave_sleep_after":45,"workbench_wave_rest_head":1,
		"workbench_wave_stick":256,"workbench_wave_calm":256,"workbench_wave_calm_damp_shift":4,
		"workbench_wave_empty_pour_shift":1,"workbench_wave_adhesion_shift":2}},
	{"label":"Strong response","values":{
		"workbench_wave_substeps":3,"workbench_wave_gain":64,"workbench_wave_gain_confined":16,
		"workbench_wave_stiffness":512,"workbench_wave_damp_shift":8,"workbench_wave_coast":32,
		"workbench_wave_level_shift":1,"workbench_wave_sleep_after":60,"workbench_wave_rest_head":0,
		"workbench_wave_stick":128,"workbench_wave_calm":128,"workbench_wave_calm_damp_shift":4,
		"workbench_wave_maximum_mass":48000,"workbench_wave_empty_pour_shift":1,
		"workbench_wave_adhesion_shift":2}},
	{"label":"Heavy","values":{
		"workbench_wave_substeps":1,"workbench_wave_gain":20,"workbench_wave_gain_confined":4,
		"workbench_wave_stiffness":256,"workbench_wave_damp_shift":5,"workbench_wave_coast":8,
		"workbench_wave_level_shift":4,"workbench_wave_sleep_after":20,"workbench_wave_rest_head":1,
		"workbench_wave_stick":1024,"workbench_wave_calm":1024,"workbench_wave_calm_damp_shift":2,
		"workbench_wave_empty_pour_shift":3,"workbench_wave_adhesion_shift":0}},
]

func build(owner: Control, parent: Control, row_factory: Callable, jet_point: Callable, water_pages: Dictionary = {}) -> void:
	host = owner
	_workbench = parent
	_water_pages = water_pages
	_jet_point = jet_point
	_inertial_signed_preference = _option_on("workbench_inertial_signed")
	var embedded := not water_pages.is_empty()
	# Embedded in the Water Lab, the legacy Wave/spray windows, their scroll
	# bodies and the standalone Wave toggle are never added to the tree. Free
	# them with the Workbench so no Window viewport or node outlives it.
	if embedded: parent.tree_exiting.connect(_free_unparented_controls,CONNECT_ONE_SHOT)
	var solver_surface: Control = water_pages.get("solvers",parent)
	var status_surface: Control = water_pages.get("status",parent)

	var row: Control = row_factory.call(solver_surface)
	var title := Label.new()
	title.text = "Water solver"
	row.add_child(title)
	_wave.text = "Wave Flow"
	_wave.tooltip_text = "Stage experimental Wave Flow on the FreeMass carrier. Apply retains cells and actors but resets Wave momentum. Ballistic/face-release requests are held aside until another solver is chosen."
	_wave.button_pressed = _option_on("workbench_wave_flow")
	_wave.toggled.connect(_set_wave)
	_wave.focus_mode = Control.FOCUS_NONE
	if embedded:
		# One discoverable law selector replaces the historical button cluster.
		for name: String in ["FreeMass · original","Wave Flow · experimental",
			"PressureFlow · reference","PressureFlow · cached",
			"PressureFlow · dormant","Inertial cellular","Other · advanced policy"]:
			_studio_solver.add_item(name)
		_studio_solver.set_item_disabled(6,true)
		_studio_solver.custom_minimum_size.x = 260
		_studio_solver.tooltip_text = "Stage the Water law; the native Applied status below is authoritative. Wave Flow retains the FreeMass carrier."
		_studio_solver.item_selected.connect(_choose_studio_solver)
		row.add_child(_studio_solver)
	else:
		row.add_child(_wave)
		_button(row,"PF cached",func() -> void: _stage_solver("pressure_flow_v1","cached"))
		_button(row,"PF dormant",func() -> void: _stage_solver("pressure_flow_v1","cached_dormant"))
		_button(row,"Inertial",func() -> void: _stage_solver("inertial_cellular_v1","reference"))
		_button(row,"FreeMass",_stage_plain_freemass)
	if not embedded:
		_button(row,"Apply solver / tuning",_apply_wave)
		_button(row,"Wave tuning…",func() -> void: _show_controls(_wave_window))
		_button(row,"Spray / other controls…",func() -> void: _show_controls(_spray_window))

	row = row_factory.call(solver_surface)
	var scene_label := Label.new()
	scene_label.text = "Water comparison"
	row.add_child(scene_label)
	for scene: Dictionary in ComparisonScenes.SCENES:
		_scene_picker.add_item(str(scene.label))
	_scene_picker.tooltip_text = "Ordinary editable starts. Load / reset replaces the canvas and applies the requested solver/tuning. Save your authored start first if needed."
	row.add_child(_scene_picker)
	_button(row,"Load / reset scene",_load_comparison)
	var workers_label := Label.new()
	workers_label.text = "Pool workers"
	row.add_child(workers_label)
	_worker_threads.min_value = 1
	_worker_threads.max_value = 32
	_worker_threads.step = 1
	_worker_threads.custom_minimum_size.x = 66
	_worker_threads.value = int(host.workbench_water_options.get("workbench_worker_threads",1))
	_worker_threads.tooltip_text = "Requested native pool size for Apply solver / tuning or an explicit Load (1–32). Native status reports useful participants separately. This setting applies to every solver."
	_worker_threads.value_changed.connect(func(value: float) -> void:
		host.workbench_water_options["workbench_worker_threads"] = int(value))
	row.add_child(_worker_threads)
	_wave_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_status.max_lines_visible = 3
	status_surface.add_child(_wave_status)

	var tuning: Control = water_pages["wave"] if embedded else _controls_body(parent,_wave_window,_wave_scroll,"Wave Flow tuning")
	row = row_factory.call(tuning)
	_wave_preset.tooltip_text = "v2 defaults is the original parameter point. Other presets are exploratory starting points. Selection stages values; Apply changes the native World."
	for preset: Dictionary in WAVE_PRESETS: _wave_preset.add_item(str(preset.label))
	_wave_preset.item_selected.connect(_select_wave_preset)
	row.add_child(_wave_preset)
	_button(row,"Reset Wave defaults",_reset_wave_defaults)
	_button(row,"Revert to native",_revert_wave)
	if not embedded:
		_button(row,"Apply solver / tuning",_apply_wave)
		_button(row,"Close",_wave_window.hide)
	var hint := Label.new()
	hint.text = "Inputs = requested · native values appear beside each input · Apply restarts Wave momentum"
	row.add_child(hint)
	_wave_dialog_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tuning.add_child(_wave_dialog_status)
	var limitations := Label.new()
	limitations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limitations.text = "Experimental: no PressureFlow pressure/gas field, buoyancy, falling lateral momentum or physical-state save."
	tuning.add_child(limitations)
	_wave_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_notice.text = "Reset stages v2 defaults. Apply solver / tuning or Load / reset scene installs requested values."
	tuning.add_child(_wave_notice)
	for group: Array in [["Motion / response",0,8],["Sleep / rest",8,14],["Transfer / capacity",14,18]]:
		var heading := Label.new()
		heading.text = group[0]
		tuning.add_child(heading)
		row = row_factory.call(tuning)
		for index: int in range(int(group[1]),int(group[2])):
			_add_wave_field(row,WAVE_SPINS[index])
	_update_wave_controls()

	var spray_controls: Control = water_pages["transport"] if embedded else _controls_body(parent,_spray_window,_spray_scroll,"Water spray / other controls")
	row = row_factory.call(spray_controls)
	title = Label.new()
	title.text = "Water spray / transport"
	row.add_child(title)
	_ballistic.text = "Ballistic Water"
	_ballistic.tooltip_text = "Native ballistic_water_v1 parcels. Incompatible with Wave Flow. Staged until Apply solver / tuning or an explicit Load; Restore start keeps the accepted configuration."
	_ballistic.button_pressed = _option_on("workbench_ballistic")
	_ballistic.toggled.connect(func(on: bool) -> void:
		if on and _wave.button_pressed:
			_wave.set_pressed_no_signal(false)
			host.workbench_water_options["workbench_wave_flow"] = false
			_update_wave_controls()
		_construction("workbench_ballistic", on))
	_signed.text = "IN signed"
	_signed.button_pressed = _option_on("workbench_inertial_signed")
	_signed.tooltip_text = "IN-B1 signed-vertical law (requires Inertial Water). Its preference is retained when choosing another Water solver. Staged until Apply solver / tuning or an explicit Load."
	_signed.toggled.connect(func(on: bool) -> void: _construction("workbench_inertial_signed", on))
	_spray.text = "Impact spray"
	_spray.toggled.connect(func(on: bool) -> void: request({"enabled": on}))
	_jet.text = "Jet"
	_jet.toggled.connect(func(on: bool) -> void:
		var point: Vector2 = _jet_point.call()
		request({"jet_enabled": on, "jet_origin": Vector2i(point)}))
	_face.text = "Face release"
	_face.tooltip_text = "Requires Ballistic Water: tall vertical Water faces shed cells as parcels. Staged until Apply solver / tuning or an explicit Load."
	_face.toggled.connect(func(on: bool) -> void: _construction("workbench_face_release", on))
	_pf_gas.text = "PF gas"
	_pf_gas.button_pressed = true
	_pf_gas.tooltip_text = "PressureFlow gas topology. Off = gas-free PressureFlow: same surging in open/vented scenes at lower cost. Staged in the liquid selection."
	_pf_gas.toggled.connect(_set_pressure_gas)
	_pf_c2048.text = "PF 2048"
	_pf_c2048.tooltip_text = "Explicit opt-in: 2048 gas compartments rather than 1024. Only available with gas-enabled PressureFlow Water."
	_pf_c2048.button_pressed = int(host.workbench_water_options.get("pressure_gas_compartment_capacity",1024)) == 2048
	_pf_c2048.toggled.connect(func(on: bool) -> void:
		host.workbench_water_options["pressure_gas_compartment_capacity"] = 2048 if on else 1024)
	_fine.text = "Fine cores"
	_fine.tooltip_text = "32-cell scheduling cores (default 64). Changes deterministic update geometry. Staged until Apply solver / tuning or an explicit Load."
	_fine.toggled.connect(func(on: bool) -> void: _construction("workbench_fine_cores", on))
	for toggle: CheckButton in [_ballistic, _signed, _face, _spray, _jet, _pf_gas, _pf_c2048, _fine]:
		toggle.focus_mode = Control.FOCUS_NONE
		row.add_child(toggle)
	for spec: Array in SPINS:
		var label := Label.new()
		label.text = spec[1]
		row.add_child(label)
		var field := SpinBox.new()
		field.min_value = spec[2]
		field.max_value = spec[3]
		field.step = spec[4]
		field.value = spec[5]
		field.custom_minimum_size.x = 70
		var key: String = spec[0]
		var integer: bool = spec[4] is int
		field.value_changed.connect(func(value: float) -> void:
			request({key: int(value) if integer else value}))
		row.add_child(field)
		_fields[key] = field
	row = row_factory.call(spray_controls)
	for spec: Array in FACE_SPINS:
		var label := Label.new()
		label.text = spec[1]
		row.add_child(label)
		var field := SpinBox.new()
		field.min_value = spec[2]
		field.max_value = spec[3]
		field.step = spec[4]
		var key: String = spec[0]
		if not host.workbench_water_options.has(key):
			host.workbench_water_options[key] = int(spec[5])
		field.value = int(host.workbench_water_options[key])
		field.custom_minimum_size.x = 70
		field.tooltip_text = "Face release tuning; staged until Apply solver / tuning or an explicit Load."
		field.value_changed.connect(func(value: float) -> void: host.workbench_water_options[key] = int(value))
		row.add_child(field)
		_fields[key] = field
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spray_controls.add_child(_status)
	if not embedded:
		_button(row_factory.call(spray_controls),"Apply solver / tuning",_apply_wave)
		_button(row_factory.call(spray_controls),"Close",_spray_window.hide)
	_update_wave_controls()

func _controls_body(parent: Control, window: Window, scroll: ScrollContainer, title: String) -> VBoxContainer:
	# A non-modal Workbench child avoids growing the main toolbar above the
	# desktop on 720p displays. It owns UI only; the same native World runs.
	window.title = title
	window.size = Vector2i(1000,410)
	window.min_size = Vector2i(640,280)
	window.transient = true
	window.exclusive = false
	window.force_native = false
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.theme = parent.theme
	window.hide()
	parent.add_child(window)
	window.close_requested.connect(window.hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,10)
	window.add_child(margin)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body

func _show_controls(window: Window) -> void:
	# The consolidated Workbench keeps Wave and spray on tabs of one window.
	# The legacy standalone layout remains available to older callers.
	if not _water_pages.is_empty():
		var tabs: TabContainer = _water_pages["tabs"]
		tabs.current_tab = 1 if window == _wave_window else 2
		return
	window.popup_centered_clamped(Vector2i(1000,410),0.95)

func _free_unparented_controls() -> void:
	for node: Node in [_wave,_wave_window,_spray_window,_wave_scroll,_spray_scroll]:
		if is_instance_valid(node) and node.get_parent() == null: node.free()

func _add_wave_field(row: Control, spec: Array) -> void:
	# Keep each label/input/readback together when the Workbench is narrow.
	var pair := HBoxContainer.new()
	row.add_child(pair)
	var label := Label.new()
	label.text = spec[1]
	label.tooltip_text = spec[6]
	pair.add_child(label)
	var field := SpinBox.new()
	field.min_value = spec[2]
	field.max_value = spec[3]
	field.step = spec[4]
	var key: String = spec[0]
	if not host.workbench_water_options.has(key): host.workbench_water_options[key] = int(spec[5])
	field.value = int(host.workbench_water_options[key])
	field.custom_minimum_size.x = 76
	field.tooltip_text = "%s\nAllowed %d–%d; default %d. Staged until Apply solver / tuning or an explicit Load." % [spec[6],spec[2],spec[3],spec[5]]
	field.value_changed.connect(func(value: float) -> void:
		host.workbench_water_options[key] = int(value))
	pair.add_child(field)
	_wave_fields[key] = field
	var actual := Label.new()
	actual.text = "native —"
	actual.tooltip_text = "Actual configuration copied from the authoritative native World."
	pair.add_child(actual)
	_wave_applied_fields[key] = actual

func _button(row: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		var focus := button.get_viewport().gui_get_focus_owner()
		if focus is LineEdit and focus.get_parent() is SpinBox: focus.get_parent().apply()
		if focus != null: focus.release_focus()
		if _workbench != null: _workbench._commit_field()
		action.call())
	row.add_child(button)
	return button

func _option_on(key: String) -> bool:
	var value: Variant = host.workbench_water_options.get(key,false)
	return value is bool and value

func _native_wave_value(wave: Dictionary, key: String) -> Variant:
	var native_key := key.trim_prefix("workbench_wave_")
	var value: Variant = wave.get("substeps") if native_key == "substeps" else wave.get("parameters",{}).get(native_key)
	return value if value is int else null

func _qualified_wave_values() -> Dictionary:
	var values := {}
	for spec: Array in WAVE_SPINS: values[spec[0]] = int(spec[5])
	return values

func _select_wave_preset(index: int) -> void:
	if index < 0 or index >= WAVE_PRESETS.size(): return
	var values := _qualified_wave_values()
	values.merge(WAVE_PRESETS[index].values,true)
	for key: String in values:
		host.workbench_water_options[key] = int(values[key])
		if _wave_fields.has(key): _wave_fields[key].set_value_no_signal(int(values[key]))
	_fallback_message = "Wave preset '%s' staged; Apply solver / tuning to use it. Native World unchanged." % WAVE_PRESETS[index].label
	_wave_notice.text = _fallback_message

func _reset_wave_defaults() -> void:
	_wave_preset.select(0)
	_select_wave_preset(0)

func _revert_wave() -> void:
	if not host.pending_microscenario_apply.is_empty():
		_wave_notice.text = "Wait for the current solver application before reverting requested settings."
		return
	var context: Dictionary = host.tower_context
	var wave: Dictionary = context.get("wave_flow",{})
	if wave.is_empty():
		_wave_notice.text = "No native configuration has been published yet."
		return
	var values := {}
	for spec: Array in WAVE_SPINS:
		var value: Variant = _native_wave_value(wave,str(spec[0]))
		if value == null:
			_wave_notice.text = "Native readback is incomplete; requested values were not changed. Rebuild the source-matched runtime."
			return
		values[spec[0]] = value
	if not wave.get("enabled") is bool or not wave.get("workers_requested") is int:
		_wave_notice.text = "Native solver/worker readback is incomplete; requested values were not changed."
		return
	var on := bool(wave.get("enabled",false))
	if not on: _restore_non_wave_options()
	else:
		host.workbench_water_options["workbench_ballistic"] = false
		host.workbench_water_options["workbench_face_release"] = false
		host.workbench_water_options["workbench_inertial_signed"] = false
		_ballistic.set_pressed_no_signal(false)
		_face.set_pressed_no_signal(false)
		_signed.set_pressed_no_signal(false)
		_workbench._liquids.normalize_water.set_pressed_no_signal(false)
	host.workbench_water_options["workbench_wave_flow"] = on
	_wave.set_pressed_no_signal(on)
	for spec: Array in WAVE_SPINS:
		var key: String = spec[0]
		var value := int(values[key])
		host.workbench_water_options[key] = value
		_wave_fields[key].set_value_no_signal(value)
	if context.get("liquid_solver_policy",{}).has("envelope"):
		_workbench._liquids.requested_policy = PackedInt32Array(context.liquid_solver_policy.envelope)
		_workbench._liquids._dirty = false
		var family := _requested_water_family()
		if family == "inertial_cellular_v1" and context.get("water_spray",{}).get("inertial_signed") is bool:
			_inertial_signed_preference = context.water_spray.inertial_signed
		_stage_inertial_signed(family if not on else "")
	var workers := int(wave.get("workers_requested",1))
	_worker_threads.set_value_no_signal(workers)
	host.workbench_water_options["workbench_worker_threads"] = workers
	_update_wave_controls()
	_fallback_message = "Requested solver, workers and Wave values restored from native readback. Native World unchanged."
	_wave_notice.text = _fallback_message

func _load_comparison() -> bool:
	var index := _scene_picker.selected
	if index < 0 or index >= ComparisonScenes.SCENES.size(): return false
	var scene: Dictionary = ComparisonScenes.SCENES[index]
	if not _workbench.load_water_comparison(str(scene.id)):
		_fallback_message = str(_workbench.message)
		_wave_notice.text = _fallback_message
		return false
	_wave_request_serial = int(host.pending_microscenario_apply.get("serial",0))
	_fallback_message = "Preparing %s with requested solver / tuning. %s" % [scene.label,scene.help]
	_wave_notice.text = _fallback_message
	return true

func _set_wave(on: bool) -> void:
	if not host.pending_microscenario_apply.is_empty():
		_wave.set_pressed_no_signal(_option_on("workbench_wave_flow"))
		_wave_notice.text = "Wait for the current solver application before changing the requested solver."
		return
	if on and not _option_on("workbench_wave_flow"):
		_remember_inertial_signed()
		_non_wave_options = {
			"workbench_ballistic":_option_on("workbench_ballistic"),
			"workbench_face_release":_option_on("workbench_face_release")}
		if _workbench._liquids != null:
			_non_wave_policy = _workbench._liquids.requested_policy.duplicate()
			_non_wave_normalize = _workbench._liquids.normalize_water.button_pressed
	host.workbench_water_options["workbench_wave_flow"] = on
	if on:
		if not _stage_solver("freemass_v1","reference",false):
			_wave.set_pressed_no_signal(false)
			host.workbench_water_options["workbench_wave_flow"] = false
			_update_wave_controls()
			return
		_ballistic.set_pressed_no_signal(false)
		_face.set_pressed_no_signal(false)
		_signed.set_pressed_no_signal(false)
		host.workbench_water_options["workbench_ballistic"] = false
		host.workbench_water_options["workbench_face_release"] = false
		host.workbench_water_options["workbench_inertial_signed"] = false
		_workbench._liquids.normalize_water.set_pressed_no_signal(false)
		_fallback_message = "Wave Flow staged on the FreeMass carrier; Apply solver / tuning to rebuild."
		_show_controls(_wave_window)
	else:
		_restore_non_wave_options()
		if not _non_wave_policy.is_empty() and _workbench._liquids != null:
			_workbench._liquids.requested_policy = _non_wave_policy.duplicate()
			_workbench._liquids._dirty = true
		_stage_inertial_signed(_requested_water_family())
		_fallback_message = "Wave Flow staged off; previous non-Wave selection restored. Apply solver / tuning to rebuild."
	_wave_notice.text = _fallback_message
	_update_wave_controls()

func _restore_non_wave_options() -> void:
	if _non_wave_options.is_empty(): return
	host.workbench_water_options.merge(_non_wave_options,true)
	_ballistic.set_pressed_no_signal(bool(_non_wave_options.workbench_ballistic))
	_face.set_pressed_no_signal(bool(_non_wave_options.workbench_face_release))
	if _workbench._liquids != null:
		_workbench._liquids.normalize_water.set_pressed_no_signal(_non_wave_normalize)
	_non_wave_options.clear()

func _requested_water_family() -> String:
	if _workbench == null or _workbench._liquids == null or _workbench._liquids.bridge == null: return ""
	var validation: Dictionary = _workbench._liquids.bridge.validate_liquid_policy(_workbench._liquids.requested_policy)
	for assignment: Dictionary in validation.get("receipt",{}).get("assignments",[]):
		if int(assignment.get("material",-1)) == CyberCellWorld.WATER:
			return str(assignment.get("applied_family",""))
	return ""

func _choose_studio_solver(index: int) -> void:
	var admitted := false
	match index:
		0: admitted = _stage_solver("freemass_v1","reference")
		1:
			_wave.button_pressed = true
			admitted = _option_on("workbench_wave_flow")
		2: admitted = _stage_solver("pressure_flow_v1","reference")
		3: admitted = _stage_solver("pressure_flow_v1","cached")
		4: admitted = _stage_solver("pressure_flow_v1","cached_dormant")
		5: admitted = _stage_solver("inertial_cellular_v1","reference")
	if not admitted:
		_fallback_message = "Requested Water law was not staged. Check the refusal/status before applying."
		_wave_notice.text = _fallback_message
	_sync_studio_solver()

func _sync_studio_solver() -> void:
	if _studio_solver.item_count == 0: return
	var option := 6 # other/whole-cell policy is available in Advanced.
	if _option_on("workbench_wave_flow"):
		option = 1
	else:
		var family := _requested_water_family()
		var variant := "reference"
		if _workbench != null and _workbench._liquids != null and _workbench._liquids.bridge != null:
			var checked: Dictionary = _workbench._liquids.bridge.validate_liquid_policy(_workbench._liquids.requested_policy)
			for assignment: Dictionary in checked.get("receipt",{}).get("assignments",[]):
				if int(assignment.get("material",-1)) == CyberCellWorld.WATER:
					variant = str(assignment.get("applied_variant","reference"))
					break
		match family:
			"freemass_v1": option = 0
			"inertial_cellular_v1": option = 5
			"pressure_flow_v1":
				option = 2 if variant == "reference" else (3 if variant == "cached" else 4)
	_studio_solver.select(option)

func _remember_inertial_signed() -> void:
	if not _option_on("workbench_wave_flow") and _requested_water_family() == "inertial_cellular_v1":
		_inertial_signed_preference = _option_on("workbench_inertial_signed")

func _stage_inertial_signed(family: String) -> void:
	# Keep the Inertial preference separate from the construction request: a
	# different selected law must never inherit this Inertial-only option.
	var on := family == "inertial_cellular_v1" and _inertial_signed_preference
	host.workbench_water_options["workbench_inertial_signed"] = on
	_signed.set_pressed_no_signal(on)

func _update_wave_controls() -> void:
	var enabled := _option_on("workbench_wave_flow")
	for value: Variant in _wave_fields.values():
		var field: SpinBox = value
		field.editable = enabled
	_wave_preset.disabled = not enabled
	# These settings belong to the non-Wave laws and stay staged for returning
	# to them. Wave tuning never rewrites their stored numeric values.
	for toggle: CheckButton in [_ballistic,_signed,_face,_pf_gas,_pf_c2048]:
		toggle.disabled = enabled
	if _workbench != null and _workbench._liquids != null:
		_workbench._liquids.normalize_water.disabled = enabled

func _stage_plain_freemass() -> void:
	_stage_solver("freemass_v1","reference")

func _stage_solver(family: String, variant: String, announce: bool = true) -> bool:
	if not host.pending_microscenario_apply.is_empty():
		if announce: _wave_notice.text = "Wait for the current solver application before choosing another solver."
		return false
	var ui: Control = host.shared_workbench
	if ui == null or ui.applied.is_empty() or ui._liquids == null:
		if announce: _wave_notice.text = "No installed Workbench liquid policy to stage."
		return false
	var bridge: Variant = ui._liquids.bridge
	if bridge == null: return false
	var staged: PackedInt32Array = ui._liquids.requested_policy
	if announce and _option_on("workbench_wave_flow") and not _non_wave_policy.is_empty():
		staged = _non_wave_policy.duplicate()
	if staged.is_empty(): staged = PackedInt32Array(ui.applied.liquid_policy)
	for option: Dictionary in bridge.liquid_policy_assignment_choices(staged,CyberCellWorld.WATER):
		if option.get("family","") == family and option.get("variant","") == variant and option.get("accepted",false):
			if announce: _remember_inertial_signed()
			ui._liquids.requested_policy = PackedInt32Array(option.request)
			ui._liquids._dirty = true
			if announce:
				_wave.set_pressed_no_signal(false)
				host.workbench_water_options["workbench_wave_flow"] = false
				_restore_non_wave_options()
				_stage_inertial_signed(family)
				_update_wave_controls()
			if announce:
				_fallback_message = "%s/%s staged; Apply solver / tuning to rebuild." % [family.trim_suffix("_v1"),variant]
				_wave_notice.text = _fallback_message
			return true
	if announce: _wave_notice.text = "%s/%s is not admitted for Water in this policy." % [family,variant]
	return false

func _apply_wave() -> bool:
	if _workbench == null or not _workbench.has_method(&"apply_liquids"):
		_wave_notice.text = "Workbench liquid rebuild is unavailable."
		return false
	if _workbench.apply_liquids():
		_wave_request_serial = int(host.pending_microscenario_apply.get("serial",0))
		_fallback_message = "Preparing Workbench liquid solver/tuning… retained cells stay; Wave momentum resets."
		_wave_notice.text = _fallback_message
		return true
	_fallback_message = str(_workbench.message)
	_wave_notice.text = _fallback_message
	return false

func _construction(key: String, on: bool) -> void:
	if key == "workbench_inertial_signed": _inertial_signed_preference = on
	host.workbench_water_options[key] = on

func _set_pressure_gas(on: bool) -> void:
	var ui: Control = host.shared_workbench
	if ui == null or ui.applied.is_empty() or ui._liquids == null: return
	var bridge: Variant = ui._liquids.bridge
	if bridge == null or not bridge.has_method(&"liquid_policy_with_pressure_gas"): return
	var staged: PackedInt32Array = ui._liquids.requested_policy
	if staged.is_empty(): staged = PackedInt32Array(ui.applied.liquid_policy)
	var result: Dictionary = bridge.liquid_policy_with_pressure_gas(staged, on)
	if result.get("accepted", false):
		ui._liquids.requested_policy = PackedInt32Array(result.request)
		ui._liquids._dirty = true
		_status.text = "PressureFlow gas %s staged; Apply solver / tuning to rebuild." % ("on" if on else "off")
	else:
		_status.text = "PressureFlow gas refused: %s" % str(result.get("refusal", {}).get("detail", "no active PressureFlow"))

func request(settings: Dictionary) -> bool:
	if host == null or host.simulation_worker == null or not host.simulation_worker.has_method(&"queue_water_spray"):
		return false
	_requested.merge(settings, true)
	return host.simulation_worker.queue_water_spray(settings)

func refresh(context: Dictionary) -> void:
	_sync_studio_solver()
	_refresh_wave(context)
	var spray: Dictionary = context.get("water_spray", {})
	if spray.is_empty():
		_status.text = "Water spray · awaiting native status"
		return
	var applied: Dictionary = spray.get("settings", {})
	var pending := []
	for key: String in _requested:
		if applied.has(key) and str(applied[key]) != str(_requested[key]): pending.append(key)
	var has_ballistic: bool = spray.get("ballistic_enabled", false)
	var worker: Variant = host.simulation_worker if host != null else null
	if has_ballistic and not _had_ballistic and not pending.is_empty() and worker != null and worker.has_method(&"queue_water_spray"):
		worker.queue_water_spray(_requested.duplicate(true))
	_had_ballistic = has_ballistic
	var receipt: Dictionary = spray.get("receipt", {})
	var refusal: String = str(receipt.get("refusal", ""))
	var ledger: Dictionary = spray.get("ledger", {})
	var tick: Dictionary = spray.get("last_coupling", {})
	var spray_line := "Water spray · ballistic %s · IN-B1 %s · live %d/%d · in flight %d · launched %d (+%d lifted) · injected %d · deposited %d · surface %d · bodies hit %d · refused %d%s%s" % [
		"on" if spray.get("ballistic_enabled", false) else "off", "on" if spray.get("inertial_signed", false) else "off",
		int(spray.get("live", 0)), int(spray.get("capacity", 0)), int(spray.get("in_flight_quantity", 0)),
		int(ledger.get("launched_parcels", 0)), int(spray.get("totals", {}).get("lifted", 0)),
		int(ledger.get("injected_parcels", 0)), int(ledger.get("deposited_parcels", 0)),
		int(ledger.get("surface_entries", 0)), int(ledger.get("body_contacts", 0)),
		int(ledger.get("refused_launches", 0)) + int(spray.get("totals", {}).get("refused", 0)),
		(" · pending " + ",".join(pending)) if not pending.is_empty() else "",
		(" · refused: " + refusal) if not refusal.is_empty() else ""]
	spray_line += " · this tick %d launched, %d budget hits" % [int(tick.get("launched", 0)), int(tick.get("budget_hits", 0))]
	_status.text = spray_line
	_status.tooltip_text = spray_line

func _refresh_wave(context: Dictionary) -> void:
	var wave: Dictionary = context.get("wave_flow",{})
	if wave.is_empty() or not wave.get("enabled") is bool:
		_wave_status.text = "Applied Water: awaiting native readback. Requested controls are not evidence of activation."
		_wave_dialog_status.text = _wave_status.text
		for label: Label in _wave_applied_fields.values(): label.text = "native unavailable"
		return
	var active := bool(wave.get("enabled",false))
	var requested := _option_on("workbench_wave_flow")
	var changes: Array[String] = []
	if not host.workbench_water_options.get("workbench_wave_flow",false) is bool: changes.append("invalid Wave selection")
	if active != requested: changes.append("Wave selection")
	var actual_values: Array[String] = []
	for spec: Array in WAVE_SPINS:
		var key: String = spec[0]
		var native_value: Variant = _native_wave_value(wave,key)
		var value := int(native_value) if native_value != null else 0
		var requested_value: Variant = host.workbench_water_options.get(key,spec[5])
		var staged := int(requested_value) if requested_value is int else 0
		var label: Label = _wave_applied_fields[key]
		label.text = "native %d%s" % [value,"" if active else " (off)"] if native_value != null else "native unavailable"
		var different := requested and (not active or native_value == null or not requested_value is int or value != staged)
		label.modulate = Color(1.0,0.76,0.38) if different else Color(0.72,0.90,0.80)
		if different: changes.append(str(spec[1]))
		actual_values.append("%s: requested %s; %s" % [spec[1],str(requested_value),label.text])
	var native_workers := int(wave.get("workers_requested",1))
	if not host.workbench_water_options.has("workbench_worker_threads"):
		_worker_threads.set_value_no_signal(clampi(native_workers,1,32))
	var worker_request: Variant = host.workbench_water_options.get("workbench_worker_threads",native_workers)
	var requested_workers := int(worker_request) if worker_request is int else 0
	if not worker_request is int or requested_workers != native_workers: changes.append("Pool workers")
	var applied_name := str(_workbench._water_identity(context))
	var requested_rounds: Variant = host.workbench_water_options.get("workbench_wave_substeps",1)
	var requested_name := "Wave OFF"
	if requested:
		requested_name = "Wave ON ×%d" % requested_rounds if requested_rounds is int else "Wave ON · invalid rounds"
	if _workbench._liquids != null and _workbench._liquids.bridge != null:
		var policy: PackedInt32Array = _workbench._liquids.requested_policy
		var native_settings: Dictionary = context.get("liquid_solver_policy",{})
		var native_policy := PackedInt32Array(native_settings.get("envelope",[]))
		if not policy.is_empty() and policy != native_policy: changes.append("Water policy")
		var validation: Dictionary = _workbench._liquids.bridge.validate_liquid_policy(policy)
		if not validation.get("accepted",false): changes.append("invalid Water policy")
		# Apply consumes the effective radius after the policy's minimum. Show
		# both the picker and effective request, then compare to the real World.
		var requested_radius: int = _workbench._liquids.geometry_picker.get_selected_id()
		var minimum_radius: int = int(validation.get("receipt",{}).get("minimum_rule_radius",2))
		var effective_radius: int = maxi(requested_radius,minimum_radius)
		var native_radius: Variant = native_settings.get("maximum_rule_radius")
		if not native_radius is int or native_radius != effective_radius: changes.append("Rule radius")
		actual_values.append("Rule radius: requested %d; effective %d (policy minimum %d); native %s" % [
			requested_radius,effective_radius,minimum_radius,str(native_radius) if native_radius is int else "unavailable"])
		# Rounding is a one-shot construction action, not a persistent law flag.
		# Even zero net mass change must wait for its successful native receipt.
		if _workbench._liquids.normalize_water.button_pressed:
			changes.append("Round Water on next Apply")
			actual_values.append("Water rounding: requested for next Apply; not yet consumed")
		if not requested:
			for assignment: Dictionary in validation.get("receipt",{}).get("assignments",[]):
				if int(assignment.get("material",-1)) == CyberCellWorld.WATER:
					requested_name = "%s/%s" % [str(assignment.get("applied_family","")).trim_suffix("_v1"),assignment.get("applied_variant","")]
	_construction_status(wave,changes,actual_values)
	var pending: bool = not host.pending_microscenario_apply.is_empty()
	if _wave_request_serial > 0 and not pending:
		_wave_request_serial = 0
		if not str(host.microscenario_error).is_empty():
			_fallback_message = "Refused · " + str(host.microscenario_error)
			if active and not requested:
				_fallback_message += " Running Wave World unchanged. Load / reset scene starts the requested solver from authored cells (replaces current simulation)."
		else:
			_fallback_message = "Native rebuild completed. " + ("Requested selection/values match native readback." if changes.is_empty() else "Some requested values differ; inspect highlighted native values.")
		_wave_notice.text = _fallback_message
	var outcome := "PREPARING" if pending else ("APPLIED · active settings match" if changes.is_empty() else "STAGED · %d differences" % changes.size())
	var refusal := str(host.microscenario_error)
	if not pending and not refusal.is_empty(): outcome = "REFUSED · " + refusal
	var worker_failed: bool = host.simulation_worker != null and host.simulation_worker.has_failed()
	if worker_failed or not bool(wave.get("healthy",true)):
		outcome = "NATIVE WORLD FAILED · displayed values are last completed native readback"
	_wave_status.text = "Applied: %s%s · requested: %s · %s\nNative tick %d · Wave ticks/rounds %d/%d · pool %d (request %d), observed %d, peak %d · %.3f ms · %d chunks / %d tasks" % [
		applied_name," · %d rounds/tick" % int(wave.get("substeps",1)) if active else " · Wave OFF",requested_name,outcome,
		int(wave.get("completed_tick",0)),int(wave.get("ticks",0)),int(wave.get("rounds",0)),native_workers,requested_workers,
		int(wave.get("workers_observed",0)),int(wave.get("maximum_participants",0)),float(wave.get("native_tick_ms",0.0)),
		int(wave.get("last_solved_chunks",0)),int(wave.get("last_tasks",0))]
	_wave_status.tooltip_text = _wave_status.text + "\n" + _fallback_message \
		+ ("\nStaged differences: " + ", ".join(changes) if not changes.is_empty() else "") + "\n" + "\n".join(actual_values) \
		+ "\nWave storage %d bytes · capacity refusals %d · quantity %s · generation %d\nObserved participants are native task claimants, not CPU utilization. Timings are complete native ticks." % [
			int(wave.get("storage_bytes",0)),int(wave.get("capacity_refusals",0)),str(wave.get("water_quantity","?")),int(wave.get("session_generation",0))]
	_wave_dialog_status.text = _wave_status.text
	_wave_dialog_status.tooltip_text = _wave_status.tooltip_text

func _construction_status(wave: Dictionary, changes: Array[String], actual_values: Array[String]) -> void:
	var actual: Dictionary = wave.get("construction_options",{})
	for spec: Array in CONSTRUCTION_SWITCHES:
		var key: String = spec[0]
		var requested: Variant = host.workbench_water_options.get(key,false)
		var native_value: Variant = actual.get(key)
		if not native_value is bool or not requested is bool or native_value != requested:
			changes.append(str(spec[1]))
		actual_values.append("%s: requested %s; native %s" % [spec[1],str(requested),str(native_value) if native_value is bool else "unavailable"])
	# Dormant tuning belongs to its own law and is not an active construction
	# request. Compare it only when the same admission path will consume it.
	if _option_on("workbench_ballistic") and _option_on("workbench_face_release"):
		for spec: Array in FACE_SPINS:
			_construction_number(actual,str(spec[0]),str(spec[1]),int(spec[5]),changes,actual_values)
	if not _option_on("workbench_wave_flow") and _requested_water_family() == "pressure_flow_v1":
		_construction_number(actual,"pressure_gas_compartment_capacity","PF compartment capacity",1024,changes,actual_values)

func _construction_number(actual: Dictionary, key: String, label: String, fallback: int,
		changes: Array[String], actual_values: Array[String]) -> void:
	var requested: Variant = host.workbench_water_options.get(key,fallback)
	var native_value: Variant = actual.get(key)
	if not requested is int or not native_value is int or requested != native_value: changes.append(label)
	actual_values.append("%s: requested %s; native %s" % [label,str(requested),str(native_value) if native_value is int else "unavailable"])
