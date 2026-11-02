extends "res://scripts/gcr_crash_playground.gd"

const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const FleetOverlay = preload("res://scripts/gcr_review_fleet_overlay.gd")
var applied_controls: Dictionary = {"response":"LA","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0}
var control_fields: Dictionary = {}
var response_select: OptionButton
var control_status: Label
var control_error: String = ""

func _ready() -> void:
	super._ready()
	_overlay.free()
	_overlay = FleetOverlay.new()
	_canvas.add_child(_overlay)
	for index: int in range(7): _buttons[index].text = "%d   %s" % [index+1,Fleet.NAMES[index]]
	_build_comparison_controls()
	select_preset(0)
	DisplayServer.window_set_title("CyberSand — flyer budget playground + painting")

func _build_comparison_controls() -> void:
	var column: Control = _canvas.get_parent().get_parent().get_parent()
	var panel := VBoxContainer.new()
	column.add_child(panel)
	column.move_child(panel,1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	panel.add_child(row)
	var responses := VBoxContainer.new()
	row.add_child(responses)
	_label(responses,"EXPERIMENTAL RESPONSE",12,Color("f7c579"))
	response_select=OptionButton.new()
	response_select.focus_mode=Control.FOCUS_NONE
	response_select.add_item("LA / A1 · budget comparison")
	response_select.add_item("RFT / R2 reference · fixed 20")
	response_select.select(0 if applied_controls.response=="LA" else 1)
	responses.add_child(response_select)
	for key: String in ["budget","mass_multiplier","inertia_multiplier"]:
		var field := VBoxContainer.new()
		row.add_child(field)
		_label(field,{"budget":"Impulse budget","mass_multiplier":"Mass × authored","inertia_multiplier":"Inertia × mass-scaled shape"}[key],12,Color("adc0ce"))
		var input := SpinBox.new()
		input.min_value=5.0 if key=="budget" else 0.01
		input.max_value=80.0 if key=="budget" else 64.0
		input.step=1.0 if key=="budget" else 0.01
		input.value=applied_controls[key]
		input.custom_minimum_size.x=130
		field.add_child(input)
		control_fields[key]=input
	_button(row,"Apply + reset room",apply_controls)
	_button(row,"Restore flyer defaults",restore_controls)
	var actuator_row := HBoxContainer.new()
	actuator_row.add_theme_constant_override("separation",12)
	panel.add_child(actuator_row)
	for key: String in ["thrust_multiplier","torque_multiplier"]:
		var field := VBoxContainer.new()
		actuator_row.add_child(field)
		_label(field,"Thrust limit × authored" if key=="thrust_multiplier" else "Torque limit × authored",12,Color("adc0ce"))
		var input := SpinBox.new()
		input.min_value=0.0
		input.max_value=64.0
		input.step=0.01
		input.value=float(applied_controls.get(key,1.0))
		input.custom_minimum_size.x=190
		field.add_child(input)
		control_fields[key]=input
	var explanation := _label(actuator_row,"0 disables that actuator. Limits change; acceleration/speed targets stay authored.",13,Color("adc0ce"))
	explanation.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	control_status=_label(panel,"",14,Color("f7c579"))
	control_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _release_edit_focus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null: focused.release_focus()

func apply_controls() -> bool:
	_release_edit_focus()
	control_error=""
	var staged: Dictionary = {"response":"LA" if response_select.selected==0 else "RFT"}
	for key: String in control_fields: staged[key]=control_fields[key].value
	if staged.response=="RFT" and staged.budget!=20.0:
		control_error="RFT reference uses budget 20. Select LA to compare budgets 20 / 40 / 80."
		control_status.text=control_error
		return false
	var previous: Dictionary = applied_controls
	applied_controls=staged
	if not select_preset(selected):
		applied_controls=previous
		control_error=runtime.last_error
		return false
	return true

func restore_controls() -> void:
	response_select.select(0)
	control_fields.budget.value=20.0
	control_fields.mass_multiplier.value=1.0
	control_fields.inertia_multiplier.value=1.0
	control_fields.thrust_multiplier.value=1.0
	control_fields.torque_multiplier.value=1.0
	apply_controls()

func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_ESCAPE]:
			_release_edit_focus()
			get_viewport().set_input_as_handled()
		return
	super._input(event)

func select_preset(index: int) -> bool:
	if not Fleet.valid_index(index): return false
	_cancel_input()
	_release_edit_focus()
	if not runtime.configure_review_fleet(index,applied_controls):
		_status.text = "Fleet refused: "+runtime.last_error
		return false
	selected = index
	_target = 0
	_lap_ticks = 0
	_lap_started = false
	_last_draw_tick = -1
	_last_packet_epoch = -1
	_pause_button.text = "Pause  ·  P"
	if _surface != null: _surface.set_render_enabled(true)
	return seed_crash_room()

func _check_targets(_state: Dictionary) -> void:
	pass # Free play has no course gate or score.

func _present(state: Dictionary, force: bool = false) -> void:
	super._present(state,force)
	if _surface == null: return
	_title.text = Fleet.NAMES[selected]
	_title.add_theme_color_override("font_color",Fleet.COLORS[selected])
	_tagline.text = Fleet.DESCRIPTIONS[selected]
	_controls.text = Fleet.controls(selected)
	_overlay.preset = &"arcadelander"
	if _overlay is FleetOverlay: _overlay.fleet_index = selected
	for index: int in range(_buttons.size()):
		_buttons[index].modulate = Fleet.COLORS[selected] if index==selected else Color.WHITE
	_timing.text = "FLIGHT FLEET  ·  %s  ·  F overview / follow" % Fleet.NAMES[selected]
	if control_status != null and runtime._arena != null:
		var body: RigidBody2D = runtime._arena.session.bodies()[0]
		var profile: Dictionary = runtime._arena.session._rigs[0]._profile
		control_status.text="Applied: %s · budget %.0f · mass %.5f (×%.2f) · inertia %.5f (×%.2f) · thrust cap %.3f · torque cap %.3f\nApply/reset rebuilds terrain and craft. Settings persist across craft; material laws and sleep unchanged." % [applied_controls.response,applied_controls.budget,body.mass,applied_controls.mass_multiplier,body.inertia,applied_controls.inertia_multiplier,profile.fleet_force,profile.fleet_torque]
		if not control_error.is_empty(): control_status.text+="\n"+control_error
