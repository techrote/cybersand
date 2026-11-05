extends ConfirmationDialog

# A local editor of copied user values. Applying goes through the workbench's
# existing acknowledged owner transaction; this window owns no physics state.
const Preferences = preload("res://scripts/flyer_preferences.gd")
const ACTION_NAMES := {"move_up":"Forward / up", "move_down":"Reverse / down",
	"move_left":"Turn / strafe left", "move_right":"Turn / strafe right", "primary":"Lift / main thrust",
	"utility_left":"Left utility / deck tilt", "utility_right":"Right utility / deck tilt",
	"dispenser_s":"Rear dispenser", "boost":"Boost", "brake":"Airbrake", "assist":"Stabilize"}
const HANDLING_NAMES := {"budget":"Granular budget", "mass_multiplier":"Mass ×", "inertia_multiplier":"Inertia ×",
	"thrust_multiplier":"Thrust ceiling ×", "torque_multiplier":"Torque ceiling ×", "boost_multiplier":"Boost ×"}
const MOVEMENT_NAMES := {"acceleration":"Acceleration ×", "speed":"Speed target ×", "turn_speed":"Turn speed ×",
	"turn_acceleration":"Turn acceleration ×", "throttle_response":"Throttle response ×", "drag":"Coast drag ×",
	"stabilization":"Stabilization gain ×", "stabilization_damping":"Stabilization damping ×",
	"gravity":"Gravity ×", "friction":"Surface friction ×", "angular_drag":"Angular drag ×"}
var request_apply: Callable
var material_name: Callable
var _draft: Dictionary = {}
var _capabilities: Dictionary = {}
var _tabs: TabContainer
var _key_rows: Dictionary = {}
var _numbers: Dictionary = {}
var _flags: Dictionary = {}
var _materials: Dictionary = {}
var _error: Label
var _capture_action: String = ""
var _capture_slot: int = 0

func _ready() -> void:
	dialog_hide_on_ok = false
	exclusive = true
	min_size = Vector2i(760,540)
	add_theme_font_size_override("font_size",13)
	get_ok_button().text = "Save actor profile & apply"
	get_cancel_button().text = "Cancel"
	confirmed.connect(_submit)
	canceled.connect(cancel_capture)
	close_requested.connect(hide)

func _label(parent: Control, value: String) -> Label:
	var result := Label.new()
	result.text = value
	parent.add_child(result)
	return result

func _page(caption: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = caption
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",6)
	scroll.add_child(box)
	return box

func _spin(parent: Control, label: String, key: String, value: float, low: float, high: float, step: float) -> void:
	_label(parent,label)
	var field := SpinBox.new()
	field.min_value = low
	field.max_value = high
	field.step = step
	field.value = value
	field.custom_minimum_size.x = 100
	field.get_line_edit().focus_entered.connect(cancel_capture)
	parent.add_child(field)
	_numbers[key] = field

func _flag(parent: Control, label: String, key: String, value: bool) -> void:
	var field := CheckButton.new()
	field.text = label
	field.button_pressed = value
	field.focus_mode = Control.FOCUS_NONE
	parent.add_child(field)
	_flags[key] = field

func open_profile(model_name: String, profile: Dictionary, capabilities: Dictionary) -> void:
	cancel_capture()
	_draft = profile.duplicate(true)
	_capabilities = capabilities.duplicate(true)
	title = model_name + " · saved controls & options"
	_key_rows.clear(); _numbers.clear(); _flags.clear(); _materials.clear()
	for child in get_children():
		if child is VBoxContainer and child.name == "ProfileContent": child.free()
	var content := VBoxContainer.new()
	content.name = "ProfileContent"
	content.add_theme_constant_override("separation",6)
	add_child(content)
	var intro := _label(content,"Saved for this actor model; applied to the selected instance. Other placed actors keep their settings.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(730,420)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(_tab: int) -> void: cancel_capture())
	content.add_child(_tabs)
	var keys := _page("Keys")
	_label(keys,"Click a binding, then press a key. Escape cancels capture; Delete clears it. Number keys are reserved.")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",12)
	keys.add_child(grid)
	_label(grid,"Action"); _label(grid,"Primary"); _label(grid,"Alternate")
	for action: String in ACTION_NAMES:
		if capabilities.get("legacy_secondary",false) and action in ["dispenser_s","brake"]: continue
		if capabilities.get("kind","") == "material" and action in ["utility_left","utility_right"]: continue
		var caption: String = ACTION_NAMES[action]
		if capabilities.get("legacy_secondary",false):
			if action == "boost": caption = "Secondary / Shift action"
			elif action == "assist": caption = "Auxiliary / C action"
			elif action == "primary": caption = "Primary / jump / surge"
			elif action in ["utility_left","utility_right"]: caption = "Lean / trim "+("left" if action == "utility_left" else "right")
		_label(grid,caption)
		var buttons: Array = []
		for slot: int in 2:
			var button := Button.new()
			button.custom_minimum_size.x = 150
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(begin_capture.bind(action,slot))
			grid.add_child(button)
			buttons.append(button)
		_key_rows[action] = buttons
	_refresh_bindings()
	var handling := _page("Handling")
	var actor_kind: String = str(capabilities.get("kind","flyer"))
	_label(handling,"Native material fields retain their authored response. Only keyboard bindings are configurable here." if actor_kind == "material" else "Multipliers are relative to the actor's authored values. Existing actuator and physics safety limits still apply.")
	var values := GridContainer.new()
	values.columns = 4
	values.add_theme_constant_override("h_separation",12)
	handling.add_child(values)
	for key: String in HANDLING_NAMES:
		if actor_kind == "material" or (actor_kind == "mechanical" and key == "boost_multiplier"): continue
		var low := 5.0 if key == "budget" else (1.0 if key == "boost_multiplier" else (0.01 if key in ["mass_multiplier","inertia_multiplier"] else 0.0))
		var high := 80.0 if key == "budget" else (8.0 if key == "boost_multiplier" else 64.0)
		var label: String = HANDLING_NAMES[key]
		if actor_kind == "mechanical" and key == "thrust_multiplier": label = "Movement impulse ×"
		if actor_kind == "mechanical" and key == "torque_multiplier": label = "Body torque ×"
		_spin(values,label,"options/"+key,float(_draft.options[key]),low,high,1.0 if key == "budget" else 0.01)
	for key: String in MOVEMENT_NAMES:
		if actor_kind == "material" or (actor_kind == "mechanical" and key == "throttle_response"): continue
		_spin(values,MOVEMENT_NAMES[key],"tuning/"+key,float(_draft.tuning[key]),0.0,64.0,0.05)
	var note := _label(handling,"Speed target adds overspeed damping rather than a hard speed clamp. Gravity, friction and angular drag retain their existing physical limits.")
	if actor_kind == "mechanical": note.text = "Speed is the authored controller's target. Movement/body-torque multipliers retain physical safety limits and do not retune wheel or joint motors."
	note.visible = actor_kind != "material"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var effects := _page("Thrusters & sources")
	if actor_kind != "flyer":
		_label(effects,"This actor has no authored flyer dispensers. Mechanical actors use the workbench's separate physical usable selector.")
	else:
		_flag(effects,"Show pixel thruster exhaust","tuning/thruster_visuals",_draft.tuning.thruster_visuals)
		_flag(effects,"Emit real Fire from thrusters","fire_enabled",_draft.fire_enabled)
	if bool(capabilities.get("side_thrusters",false)):
		_flag(effects,"Invert side-thruster directions","tuning/swap_side_thrusters",_draft.tuning.swap_side_thrusters)
	var sources := GridContainer.new()
	sources.columns = 2
	sources.add_theme_constant_override("h_separation",12)
	effects.add_child(sources)
	if actor_kind == "flyer": _spin(sources,"Thruster Fire amount ×","tuning/fire_amount",_draft.tuning.fire_amount,0,8,0.25)
	for port: String in ["q","e","s"]:
		if int(capabilities.get("dispenser_"+port,0)) == 0: continue
		_label(sources,port.to_upper()+" dispenser material")
		var picker := OptionButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		picker.add_item("Disabled",0)
		for id: int in range(1,CyberCellWorld.LAST_MATERIAL+1):
			if id == 10: continue
			picker.add_item(str(material_name.call(id)).capitalize() if material_name.is_valid() else "Material %d" % id,id)
		picker.select(picker.get_item_index(int(_draft.tuning[port+"_material"])))
		sources.add_child(picker)
		_materials[port+"_material"] = picker
		_spin(sources,port.to_upper()+" dispenser amount ×","tuning/"+port+"_amount",_draft.tuning[port+"_amount"],0,8,0.25)
	var source_note := _label(effects,"The exhaust graphic creates no material. Real sources add cells only into clear space; blocked outlets can emit less. 1× is one cell per nozzle every six physics ticks; fractions reduce the rate, up to 8×.")
	source_note.visible = actor_kind == "flyer"
	source_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var defaults := Button.new()
	defaults.text = "Restore authored defaults in this editor"
	defaults.focus_mode = Control.FOCUS_NONE
	defaults.pressed.connect(func() -> void: open_profile.call_deferred(model_name,Preferences.default_profile(_capabilities),_capabilities))
	content.add_child(defaults)
	_error = _label(content,"")
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_centered(Vector2i(820,650))

func cancel_capture() -> void:
	_capture_action = ""
	if not _key_rows.is_empty(): _refresh_bindings()

func begin_capture(action: String, slot: int) -> void:
	_capture_action = action
	_capture_slot = slot
	_error.text = "Press a key for %s. Escape cancels; Delete clears." % ACTION_NAMES[action]
	_key_rows[action][slot].text = "Press a key…"

func capture_key(code: int) -> bool:
	if _capture_action.is_empty(): return false
	if code == KEY_ESCAPE:
		cancel_capture(); _error.text = "Capture cancelled."; return true
	if code not in [KEY_DELETE,KEY_BACKSPACE] and Preferences.reserved_key(code,_capabilities):
		_error.text = "That key is reserved for workbench navigation or material/usables selection."
		return true
	var keys: Array = _draft.bindings[_capture_action].duplicate()
	while keys.size() < 2: keys.append(0)
	keys[_capture_slot] = 0 if code in [KEY_DELETE,KEY_BACKSPACE] else code
	keys = keys.filter(func(value: int) -> bool: return value != 0)
	if keys.size() == 2 and keys[0] == keys[1]: keys.pop_back()
	var candidate: Dictionary = _draft.bindings.duplicate(true)
	candidate[_capture_action] = keys
	var error: String = Preferences.validate_bindings(candidate,_capabilities)
	if not error.is_empty(): _error.text = error; return true
	_draft.bindings = candidate
	cancel_capture()
	_error.text = "Binding staged. Save & apply to use it. Shared keys may intentionally activate more than one action."
	return true

func _refresh_bindings() -> void:
	for action: String in _key_rows:
		var keys: Array = _draft.bindings[action]
		for slot: int in 2:
			_key_rows[action][slot].text = Preferences.key_label(int(keys[slot])) if keys.size() > slot else "Unbound"

func staged_profile() -> Dictionary:
	var candidate := _draft.duplicate(true)
	for path: String in _numbers:
		var field: SpinBox = _numbers[path]
		if field.get_line_edit().has_focus(): field.apply()
		var pieces := path.split("/")
		candidate[pieces[0]][pieces[1]] = field.value
	for path: String in _flags:
		if path == "fire_enabled": candidate.fire_enabled = _flags[path].button_pressed
		else: candidate.tuning[path.trim_prefix("tuning/")] = _flags[path].button_pressed
	for key: String in _materials: candidate.tuning[key] = _materials[key].get_selected_id()
	return candidate

func _submit() -> void:
	cancel_capture()
	var candidate := staged_profile()
	var error: String = Preferences.validate_profile(candidate,_capabilities)
	if not error.is_empty(): _error.text = error; return
	if not request_apply.is_valid() or not bool(request_apply.call(candidate)):
		_error.text = "The settings were not applied. Check the workbench status and current response budget."
		return
	hide()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if not _capture_action.is_empty():
		capture_key(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()
