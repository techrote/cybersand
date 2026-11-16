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
var _wave_preset := OptionButton.new()
var _status := Label.new()
var _fields: Dictionary = {}
var _wave_fields: Dictionary = {}
var _jet_point: Callable
var _workbench: Control
var _fallback_message := ""

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
# Every kinetic Wave constant that is safe to vary without changing the fixed
# point representation or violating the two-face conservation bound.
const WAVE_SPINS := [
	["workbench_wave_substeps", "Rounds", 1, 8, 1, 1, "Solver rounds per native tick; fastest overall speed control."],
	["workbench_wave_active_rows", "Active rows", 1, 32, 1, 32, "Maximum stack depth participating in head response."],
	["workbench_wave_gain", "Accel", 0, 512, 1, 32, "Open-surface head-to-horizontal-flux acceleration."],
	["workbench_wave_gain_confined", "Sealed accel", 0, 512, 1, 4, "Head acceleration for confined/pressurised stacks."],
	["workbench_wave_stiffness", "Pressure stiff", 1, 4096, 8, 256, "Sealed overfill stiffness. Native admission requires at least Active rows."],
	["workbench_wave_damp_shift", "Damp shift", 0, 16, 1, 7, "Momentum loss is roughly 1 / 2^N; larger = livelier/less damping."],
	["workbench_wave_coast", "Coast", 0, 65535, 1, 16, "Minimum inertia allowed to coast against a small head difference."],
	["workbench_wave_level_shift", "Level shift", 0, 16, 1, 3, "Depth levelling divisor 2^N; smaller = more aggressive lateral levelling."],
	["workbench_wave_sleep_after", "Sleep ticks", 1, 3600, 1, 30, "Quiet rounds before a chunk sleeps."],
	["workbench_wave_wake_peak", "Wake move", 0, 65535, 1, 1, "Whole-unit movement required to hold activity. Zero effectively prevents sleep."],
	["workbench_wave_rest_head", "Rest head", 0, 65535, 1, 1, "Head difference eligible for the small-step rest rule."],
	["workbench_wave_stick", "Stick flux", 0, 65535, 16, 512, "Flux below this threshold is discarded inside Rest head."],
	["workbench_wave_calm", "Calm flux", 0, 65535, 16, 512, "Below this flux, the stronger calm damping path is used."],
	["workbench_wave_calm_damp_shift", "Calm damp", 0, 16, 1, 3, "Low-flux damping shift; larger = less damping."],
	["workbench_wave_maximum_mass", "Seal max", 255, 65535, 255, 32000, "Mass at which a sealed stack refuses further lateral inflow."],
	["workbench_wave_empty_pour_shift", "Empty pour", 1, 8, 1, 2, "Donor share into Empty is 1 / 2^N. One is the fastest conservative setting."],
	["workbench_wave_flow_share_shift", "Wet share", 1, 8, 1, 1, "Donor share between wet neighbours is 1 / 2^N. One is the conservative maximum."],
	["workbench_wave_adhesion_shift", "Film shift", 0, 8, 1, 1, "Surface adhesion film is Water film / 2^N. Larger = less sticky."],
]
const WAVE_PRESETS := [
	{"label":"Qualified v2","values":{}},
	{"label":"Lively","values":{
		"workbench_wave_substeps":2,"workbench_wave_gain":48,"workbench_wave_gain_confined":8,
		"workbench_wave_stiffness":384,"workbench_wave_damp_shift":8,"workbench_wave_coast":24,
		"workbench_wave_level_shift":2,"workbench_wave_sleep_after":45,"workbench_wave_rest_head":1,
		"workbench_wave_stick":256,"workbench_wave_calm":256,"workbench_wave_calm_damp_shift":4,
		"workbench_wave_empty_pour_shift":1,"workbench_wave_adhesion_shift":2}},
	{"label":"Pressure-ish","values":{
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

func build(owner: Control, parent: Control, row_factory: Callable, jet_point: Callable) -> void:
	host = owner
	_workbench = parent
	_jet_point = jet_point

	var row: Control = row_factory.call(parent)
	var title := Label.new()
	title.text = "Water solver lab"
	row.add_child(title)
	_wave.text = "Wave Flow"
	_wave.tooltip_text = "Run Wave Flow in the actual Workbench. Enabling stages the required FreeMass carrier and disables incompatible ballistic Water. Apply rebuilds the live World and resets retained Wave face momentum."
	_wave.button_pressed = bool(host.workbench_water_options.get("workbench_wave_flow",false))
	_wave.toggled.connect(_set_wave)
	_wave.focus_mode = Control.FOCUS_NONE
	row.add_child(_wave)
	_wave_preset.tooltip_text = "Authoring starting points only. Qualified v2 reproduces the previously qualified constants; other presets are deliberately exploratory."
	for preset: Dictionary in WAVE_PRESETS: _wave_preset.add_item(str(preset.label))
	_wave_preset.item_selected.connect(_select_wave_preset)
	row.add_child(_wave_preset)
	_button(row,"PF cached",func() -> void: _stage_solver("pressure_flow_v1","cached"))
	_button(row,"PF dormant",func() -> void: _stage_solver("pressure_flow_v1","cached_dormant"))
	_button(row,"FreeMass",_stage_plain_freemass)
	_button(row,"Apply solver / tuning",_apply_wave)

	row = row_factory.call(parent)
	for spec: Array in WAVE_SPINS:
		var label := Label.new()
		label.text = spec[1]
		label.tooltip_text = spec[6]
		row.add_child(label)
		var field := SpinBox.new()
		field.min_value = spec[2]
		field.max_value = spec[3]
		field.step = spec[4]
		var key: String = spec[0]
		if not host.workbench_water_options.has(key):
			host.workbench_water_options[key] = int(spec[5])
		field.value = int(host.workbench_water_options[key])
		field.custom_minimum_size.x = 72
		field.tooltip_text = spec[6] + " Applies on solver rebuild."
		field.value_changed.connect(func(value: float) -> void:
			host.workbench_water_options[key] = int(value))
		row.add_child(field)
		_wave_fields[key] = field
	_update_wave_controls()

	row = row_factory.call(parent)
	title = Label.new()
	title.text = "Water spray / transport"
	row.add_child(title)
	_ballistic.text = "Ballistic Water"
	_ballistic.tooltip_text = "Construction option: native ballistic_water_v1 parcels. Incompatible with Wave Flow. Applies on the next Apply settings / Restore start."
	_ballistic.button_pressed = bool(host.workbench_water_options.get("workbench_ballistic",false))
	_ballistic.toggled.connect(func(on: bool) -> void:
		if on and _wave.button_pressed:
			_wave.set_pressed_no_signal(false)
			host.workbench_water_options["workbench_wave_flow"] = false
			_update_wave_controls()
		_construction("workbench_ballistic", on))
	_signed.text = "IN signed"
	_signed.tooltip_text = "Construction option: IN-B1 signed-vertical law (requires an Inertial Water assignment). Applies on rebuild."
	_signed.toggled.connect(func(on: bool) -> void: _construction("workbench_inertial_signed", on))
	_spray.text = "Impact spray"
	_spray.toggled.connect(func(on: bool) -> void: request({"enabled": on}))
	_jet.text = "Jet"
	_jet.toggled.connect(func(on: bool) -> void:
		var point: Vector2 = _jet_point.call()
		request({"jet_enabled": on, "jet_origin": Vector2i(point)}))
	_face.text = "Face release"
	_face.tooltip_text = "Construction option (requires Ballistic Water): tall vertical Water faces shed cells as parcels at dam-break speed. Applies on rebuild."
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
	_fine.tooltip_text = "Construction option: 32-cell scheduling cores (default 64). Different deterministic update geometry; applies on rebuild."
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
	row = row_factory.call(parent)
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
		field.tooltip_text = "Face release tuning; applies on rebuild."
		field.value_changed.connect(func(value: float) -> void: host.workbench_water_options[key] = int(value))
		row.add_child(field)
		_fields[key] = field
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_status)

func _button(row: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button

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
	_status.text = "Wave preset '%s' staged; Apply solver / tuning rebuilds the Workbench and resets Wave momentum." % WAVE_PRESETS[index].label

func _set_wave(on: bool) -> void:
	host.workbench_water_options["workbench_wave_flow"] = on
	if on:
		if not _stage_solver("freemass_v1","reference",false):
			_wave.set_pressed_no_signal(false)
			host.workbench_water_options["workbench_wave_flow"] = false
			_update_wave_controls()
			return
		_ballistic.set_pressed_no_signal(false)
		_face.set_pressed_no_signal(false)
		host.workbench_water_options["workbench_ballistic"] = false
		host.workbench_water_options["workbench_face_release"] = false
		_status.text = "Wave Flow staged on the FreeMass carrier; Apply solver / tuning to rebuild."
	else:
		_status.text = "Wave Flow staged off; choose a liquid family and Apply solver / tuning."
	_update_wave_controls()

func _update_wave_controls() -> void:
	var enabled := bool(host.workbench_water_options.get("workbench_wave_flow",false))
	for value: Variant in _wave_fields.values():
		var field: SpinBox = value
		field.editable = enabled
	_wave_preset.disabled = not enabled

func _stage_plain_freemass() -> void:
	_wave.set_pressed_no_signal(false)
	host.workbench_water_options["workbench_wave_flow"] = false
	_update_wave_controls()
	_stage_solver("freemass_v1","reference")

func _stage_solver(family: String, variant: String, announce: bool = true) -> bool:
	var ui: Control = host.shared_workbench
	if ui == null or ui.applied.is_empty() or ui._liquids == null:
		if announce: _status.text = "No installed Workbench liquid policy to stage."
		return false
	var bridge: Variant = ui._liquids.bridge
	if bridge == null: return false
	var staged: PackedInt32Array = ui._liquids.requested_policy
	if staged.is_empty(): staged = PackedInt32Array(ui.applied.liquid_policy)
	for option: Dictionary in bridge.liquid_policy_assignment_choices(staged,CyberCellWorld.WATER):
		if option.get("family","") == family and option.get("variant","") == variant and option.get("accepted",false):
			ui._liquids.requested_policy = PackedInt32Array(option.request)
			if family != "freemass_v1":
				_wave.set_pressed_no_signal(false)
				host.workbench_water_options["workbench_wave_flow"] = false
				_update_wave_controls()
			if announce:
				_status.text = "%s/%s staged; Apply solver / tuning to rebuild." % [family.trim_suffix("_v1"),variant]
			return true
	if announce: _status.text = "%s/%s is not admitted for Water in this policy." % [family,variant]
	return false

func _apply_wave() -> void:
	if _workbench == null or not _workbench.has_method(&"apply_liquids"):
		_status.text = "Workbench liquid rebuild is unavailable."
		return
	if _workbench.apply_liquids():
		_fallback_message = "Preparing Workbench liquid solver/tuning… retained cells stay; Wave momentum resets."
		_status.text = _fallback_message

func _construction(key: String, on: bool) -> void:
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
		_status.text = "PressureFlow gas %s staged; Apply solver / tuning to rebuild." % ("on" if on else "off")
	else:
		_status.text = "PressureFlow gas refused: %s" % str(result.get("refusal", {}).get("detail", "no active PressureFlow"))

func request(settings: Dictionary) -> bool:
	if host == null or host.simulation_worker == null or not host.simulation_worker.has_method(&"queue_water_spray"):
		return false
	_requested.merge(settings, true)
	return host.simulation_worker.queue_water_spray(settings)

func refresh(context: Dictionary) -> void:
	var wave: Dictionary = context.get("wave_flow",{})
	var wave_line := "Wave · unavailable"
	if not wave.is_empty():
		if wave.get("enabled",false):
			var p: Dictionary = wave.get("parameters",{})
			wave_line = "Wave ON · %d rounds · accel %d/%d · stiff %d · damp %d/%d · coast %d · level %d · sleep %d · %.2f ms · %d chunks/%d tasks" % [
				int(wave.get("substeps",1)),int(p.get("gain",0)),int(p.get("gain_confined",0)),int(p.get("stiffness",0)),
				int(p.get("damp_shift",0)),int(p.get("calm_damp_shift",0)),int(p.get("coast",0)),int(p.get("level_shift",0)),
				int(p.get("sleep_after",0)),float(wave.get("native_tick_ms",0.0)),int(wave.get("last_solved_chunks",0)),int(wave.get("last_tasks",0))]
		else:
			wave_line = "Wave OFF"
	var spray: Dictionary = context.get("water_spray", {})
	if spray.is_empty():
		_status.text = wave_line if not wave.is_empty() else (_fallback_message if not _fallback_message.is_empty() else "Wave · awaiting native status")
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
	_status.text = wave_line + "\n" + spray_line
