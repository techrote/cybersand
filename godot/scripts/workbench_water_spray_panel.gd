extends RefCounted

# WCX/BW-001 experimental Water spray controls for the development workbench.
# Construction options (ballistic parcels, IN-B1 signed law) apply on the next
# workbench build; runtime spray settings are queued to the exclusive owner and
# the status line shows the native applied values and refusals.

var host: Control
var _requested: Dictionary = {}
var _ballistic := CheckButton.new()
var _signed := CheckButton.new()
var _spray := CheckButton.new()
var _jet := CheckButton.new()
var _status := Label.new()
var _fields: Dictionary = {}
var _jet_point: Callable

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

func build(owner: Control, parent: Control, row_factory: Callable, jet_point: Callable) -> void:
	host = owner
	_jet_point = jet_point
	var row: Control = row_factory.call(parent)
	var title := Label.new()
	title.text = "Water spray (experimental)"
	row.add_child(title)
	_ballistic.text = "Ballistic Water"
	_ballistic.tooltip_text = "Construction option: native ballistic_water_v1 parcels. Applies on the next Apply settings / Restore start."
	_ballistic.toggled.connect(func(on: bool) -> void: _construction("workbench_ballistic", on))
	_signed.text = "IN signed"
	_signed.tooltip_text = "Construction option: IN-B1 signed-vertical law (requires an Inertial Water assignment). Applies on rebuild."
	_signed.toggled.connect(func(on: bool) -> void: _construction("workbench_inertial_signed", on))
	_spray.text = "Impact spray"
	_spray.toggled.connect(func(on: bool) -> void: request({"enabled": on}))
	_jet.text = "Jet"
	_jet.toggled.connect(func(on: bool) -> void:
		var point: Vector2 = _jet_point.call()
		request({"jet_enabled": on, "jet_origin": Vector2i(point)}))
	for toggle: CheckButton in [_ballistic, _signed, _spray, _jet]:
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
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_status)

func _construction(key: String, on: bool) -> void:
	host.workbench_water_options[key] = on

func request(settings: Dictionary) -> bool:
	if host == null or host.simulation_worker == null or not host.simulation_worker.has_method(&"queue_water_spray"):
		return false
	_requested.merge(settings, true)
	return host.simulation_worker.queue_water_spray(settings)

func refresh(context: Dictionary) -> void:
	var spray: Dictionary = context.get("water_spray", {})
	if spray.is_empty():
		_status.text = "Water spray · unavailable on this owner"
		return
	var applied: Dictionary = spray.get("settings", {})
	var pending := []
	for key: String in _requested:
		if applied.has(key) and str(applied[key]) != str(_requested[key]): pending.append(key)
	var receipt: Dictionary = spray.get("receipt", {})
	var refusal: String = str(receipt.get("refusal", ""))
	var ledger: Dictionary = spray.get("ledger", {})
	var tick: Dictionary = spray.get("last_coupling", {})
	_status.text = "Water spray · ballistic %s · IN-B1 %s · live %d/%d · in flight %d · launched %d (+%d lifted) · injected %d · deposited %d · surface %d · bodies hit %d · refused %d%s%s" % [
		"on" if spray.get("ballistic_enabled", false) else "off", "on" if spray.get("inertial_signed", false) else "off",
		int(spray.get("live", 0)), int(spray.get("capacity", 0)), int(spray.get("in_flight_quantity", 0)),
		int(ledger.get("launched_parcels", 0)), int(spray.get("totals", {}).get("lifted", 0)),
		int(ledger.get("injected_parcels", 0)), int(ledger.get("deposited_parcels", 0)),
		int(ledger.get("surface_entries", 0)), int(ledger.get("body_contacts", 0)),
		int(ledger.get("refused_launches", 0)) + int(spray.get("totals", {}).get("refused", 0)),
		(" · pending " + ",".join(pending)) if not pending.is_empty() else "",
		(" · refused: " + refusal) if not refusal.is_empty() else ""]
	_status.text += " · this tick %d launched, %d budget hits" % [int(tick.get("launched", 0)), int(tick.get("budget_hits", 0))]
