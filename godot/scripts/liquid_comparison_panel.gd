class_name CyberLiquidComparisonPanel
extends VBoxContainer

# Presentation and copied request selection only. The existing application
# owner and native prepared builder perform every actual reconstruction.
const Contract = preload("res://scripts/microscenario_contract.gd")
const FeelCatalogue = preload("res://scripts/liquid_feel_catalogue.gd")
const FeelControls = preload("res://scripts/liquid_feel_controls.gd")
const SETUP_BUILTIN_COUNT: int = 2 # Protected Dam Break and mixed lock exchange keep indices 0/1.
const DAM_PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const MIXED_PATH: String = "res://tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json"
const PRESETS: Array[Dictionary] = [
	{"label":"Current defaults", "assignments":[]},
	{"label":"Water: whole-cell", "assignments":[[3,"cellular_yield_v1","reference"]]},
	{"label":"Water: pressure reference", "assignments":[[3,"pressure_flow_v1","reference"]]},
	{"label":"Water: pressure cached", "assignments":[[3,"pressure_flow_v1","cached"]]},
	{"label":"Water: pressure dormant", "assignments":[[3,"pressure_flow_v1","cached_dormant"]]},
	{"label":"Water: inertial", "assignments":[[3,"inertial_cellular_v1","reference"]]},
	{"label":"Mixed: pressure Water + inertial Brine", "assignments":[[3,"pressure_flow_v1","reference"],[24,"inertial_cellular_v1","reference"]]},
	{"label":"Mixed: Current Water + inertial Brine", "assignments":[[24,"inertial_cellular_v1","reference"]]},
]
var host: Control
var bridge: Variant
var preset_picker: OptionButton
var setup_picker: OptionButton
var material_picker: OptionButton
var family_picker: OptionButton
var session_picker: OptionButton
var geometry_picker: OptionButton
var damping_numerator: SpinBox
var normalize_water: CheckBox
var apply_button: Button
var dam_button: Button
var control_button: Button
var import_button: Button
var clear_import_button: Button
var receipt_label: Label
var status: Label
var requested_policy := PackedInt32Array()
var _choices: Array = []
var _validation: Dictionary = {}
var _dirty: bool = false
var _applied_generation: int = -1
var _waiting_serial: int = 0
var _refusal: String = ""
var feel_controls: Control
# Native generation produced by this panel's own accepted comparison request;
# optional comparison sampling is tied to it, never to ordinary sessions.
var comparison_generation: int = -1
var _comparison_pending: bool = false

func _button(row: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button

func setup(controller: Control, selection_only: bool = false) -> void:
	host = controller
	name = "LiquidComparisonControls"
	var heading := Label.new()
	heading.text = "Liquid solvers" if selection_only else "Liquid comparison • experimental"
	heading.add_theme_font_size_override("font_size", 20)
	add_child(heading)
	var explanation := Label.new()
	explanation.text = "Choose a solver policy, then rebuild the active scenario. Exploratory mode stages sampled or articulated actors in supported maps. Use the existing pause and step controls to run."
	if selection_only:
		explanation.text = "Choose Current defaults or an experimental family for each material. Selections take effect when you build the session. Unavailable combinations show the native refusal reason."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explanation)
	var presets := HFlowContainer.new()
	add_child(presets)
	setup_picker = OptionButton.new()
	setup_picker.add_item("Protected Dam Break")
	setup_picker.add_item("Water / Oil / Brine lock exchange")
	for index: int in FeelCatalogue.SCENARIOS.size():
		var entry: Dictionary = FeelCatalogue.SCENARIOS[index]
		setup_picker.add_item("#360 " + str(entry.title))
		var item: int = SETUP_BUILTIN_COUNT + index
		setup_picker.set_item_tooltip(item, str(entry.get("unavailable", entry.measure)))
		setup_picker.set_item_disabled(item, entry.has("unavailable"))
	presets.add_child(setup_picker)
	session_picker = OptionButton.new()
	session_picker.add_item("Controlled • fixed actor-free")
	session_picker.add_item("Exploratory • staged owner")
	session_picker.tooltip_text = "Exploratory setup stages sampled actors or desktop articulated actors in supported maps. Other body routes remain unavailable; full matched evidence remains pending."
	session_picker.item_selected.connect(func(_index: int) -> void: _dirty = true; _refusal = "")
	presets.add_child(session_picker)
	geometry_picker = OptionButton.new()
	geometry_picker.add_item("Original Current geometry (radius 2)",2)
	geometry_picker.add_item("Matched IN geometry (radius 3)",3)
	geometry_picker.add_item("Preferred per family (IN 3, others 2)",0)
	geometry_picker.tooltip_text = "Any inertial solver requires explicit radius three. Matched geometry runs every family at radius three; preferred geometry uses each family's native radius. Never pool their timings. Original Current control always restores radius two."
	geometry_picker.item_selected.connect(func(_index: int) -> void: _dirty = true;_refusal = "")
	presets.add_child(geometry_picker)
	preset_picker = OptionButton.new()
	preset_picker.tooltip_text = "Presets replace the solver policy. The active definition's independent Water precision, coherence and transport settings stay unchanged."
	preset_picker.item_selected.connect(select_preset)
	presets.add_child(preset_picker)
	var rows := HFlowContainer.new()
	add_child(rows)
	material_picker = OptionButton.new()
	material_picker.tooltip_text = "The policy covers every liquid material, including species absent from this setup. Its solver applies whenever cells of that material appear."
	material_picker.item_selected.connect(func(_index: int) -> void: _refresh_choices())
	rows.add_child(material_picker)
	family_picker = OptionButton.new()
	family_picker.item_selected.connect(select_family)
	rows.add_child(family_picker)
	var damping_row := HBoxContainer.new()
	var damping_label := Label.new();damping_label.text = "IN damping numerator / 16"
	damping_row.add_child(damping_label)
	damping_numerator = SpinBox.new()
	damping_numerator.min_value = 0;damping_numerator.max_value = 16;damping_numerator.step = 1
	damping_numerator.value = 1
	damping_numerator.tooltip_text = "Native family block v2. Zero retains motion; sixteen removes velocity before travel. Applies only on rebuild, with actual native readback."
	damping_numerator.value_changed.connect(select_inertial_damping)
	damping_row.add_child(damping_numerator);add_child(damping_row)
	normalize_water = CheckBox.new()
	normalize_water.text = "Normalize Water to whole cells on rebuild"
	normalize_water.tooltip_text = "Explicit water-normalize-v1: final Water cells round at one-half of the native maximum. The receipt records exact Water added and removed, including zero net change. Check this for both comparator arms when matching whole-cell setups."
	normalize_water.toggled.connect(func(_enabled: bool) -> void: _dirty = true; _refusal = "")
	add_child(normalize_water)
	var actions := HFlowContainer.new()
	add_child(actions)
	apply_button = _button(actions, "Apply & rebuild active", apply_active)
	dam_button = _button(actions, "Load selected comparison", load_selected)
	control_button = _button(actions, "Original Current control", load_current_control)
	control_button.tooltip_text = "Uses the unchanged protected definition and original default constructor; pending family and normalization choices are not applied."
	if host.has_method(&"liquid_comparison_arm_import"):
		import_button = _button(actions,"Use selection for next level import",arm_import)
		import_button.tooltip_text = "Explicit Exploratory only. The next ordinary body-free CYSD import uses this copied policy/normalization/geometry. Current imports remain the default until armed."
		clear_import_button = _button(actions,"Use Current defaults for next import",clear_import)
	receipt_label = Label.new()
	receipt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(receipt_label)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	if not selection_only and host.has_method(&"liquid_feel_relaunch"):
		feel_controls = FeelControls.new()
		add_child(feel_controls)
		feel_controls.setup(self, host)
	if selection_only:
		# Reuse the native-backed editor, without exposing its separate
		# comparison/import transactions inside the playable-session surface.
		setup_picker.hide()
		session_picker.hide()
		session_picker.select(1)
		actions.hide()
		receipt_label.hide()
		status.hide()
	if ClassDB.class_exists(&"CyberDemoBridge"):
		bridge = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge == null or not bridge.has_method(&"liquid_policy_assignment_choices"):
		refresh({})
		return
	requested_policy = bridge.default_liquid_policy()
	_validation = bridge.validate_liquid_policy(requested_policy)
	for assignment: Dictionary in _validation.receipt.assignments:
		material_picker.add_item(str(assignment.name).capitalize(), int(assignment.material))
	for index: int in PRESETS.size():
		var result: Dictionary = _preset(index)
		preset_picker.add_item(str(PRESETS[index].label))
		preset_picker.set_item_disabled(index, not result.ok)
		preset_picker.set_item_tooltip(index, str(result.get("error", "Pending policy; applies only on rebuild")))
	_refresh_choices()
	refresh({})

func _preset(index: int) -> Dictionary:
	var request: PackedInt32Array = bridge.default_liquid_policy()
	for assignment: Array in PRESETS[index].assignments:
		var found: bool = false
		for choice: Dictionary in bridge.liquid_policy_assignment_choices(request, int(assignment[0])):
			if choice.family != assignment[1] or choice.variant != assignment[2]: continue
			if not choice.accepted:
				return {"ok":false, "error":str(choice.refusal.code) + ": " + str(choice.refusal.detail)}
			request = choice.request
			found = true
			break
		if not found: return {"ok":false, "error":"This runtime has no declared choice for that preset"}
	return {"ok":true, "request":request}

func select_preset(index: int) -> void:
	if bridge == null or not bridge.has_method(&"liquid_policy_assignment_choices") or index < 0 or index >= PRESETS.size(): return
	var result: Dictionary = _preset(index)
	if not result.ok:
		_refusal = str(result.error)
		return
	requested_policy = result.request
	_dirty = true
	_refusal = ""
	_refresh_choices()

func _refresh_choices() -> void:
	if bridge == null or not bridge.has_method(&"liquid_policy_assignment_choices") or requested_policy.is_empty(): return
	_validation = bridge.validate_liquid_policy(requested_policy)
	_choices = bridge.liquid_policy_assignment_choices(requested_policy, material_picker.get_selected_id())
	family_picker.clear()
	var selected: int = -1
	for assignment: Dictionary in _validation.get("receipt", {}).get("assignments", []):
		if int(assignment.material) != material_picker.get_selected_id(): continue
		for index: int in _choices.size():
			if _choices[index].family == assignment.applied_family and _choices[index].variant == assignment.applied_variant:
				selected = index
	for index: int in _choices.size():
		var choice: Dictionary = _choices[index]
		var label: String = str(choice.family).trim_suffix("_v1").replace("_", " ").capitalize() + " / " + str(choice.variant)
		label += " • Current" if choice.current_default else " • experimental"
		if not choice.accepted: label += " • unavailable"
		family_picker.add_item(label)
		family_picker.set_item_disabled(index, not choice.accepted)
		if not choice.accepted:
			family_picker.set_item_tooltip(index, str(choice.refusal.code) + ": " + str(choice.refusal.detail))
	if selected >= 0: family_picker.select(selected)
	var inertial: Dictionary = _validation.get("receipt",{}).get("family_parameters",{}).get("inertial_cellular_v1",{})
	damping_numerator.set_value_no_signal(float(inertial.get("damping_numerator",1)))
	damping_numerator.get_parent().visible = not inertial.is_empty()
	damping_numerator.editable = not inertial.is_empty() and bridge.has_method(&"liquid_policy_with_inertial_damping")

func select_inertial_damping(value: float) -> void:
	if bridge == null or not bridge.has_method(&"liquid_policy_with_inertial_damping"): return
	var result: Dictionary = bridge.liquid_policy_with_inertial_damping(requested_policy,int(value))
	if not result.get("accepted",false):
		_refusal = str(result.get("refusal",{}).get("detail","IN damping refused"))
		return
	requested_policy = result.request
	_dirty = true;_refusal = ""
	_refresh_choices()

func select_family(index: int) -> void:
	if index < 0 or index >= _choices.size(): return
	var choice: Dictionary = _choices[index]
	if not choice.accepted:
		_refusal = str(choice.refusal.code) + ": " + str(choice.refusal.detail)
		return
	requested_policy = choice.request.duplicate()
	_dirty = true
	_refusal = ""
	_refresh_choices()

func _definition_supported(definition: Dictionary) -> bool:
	if definition.is_empty() or int(definition.get("schema_version",0)) != 2: return false
	if session_picker.selected == 1:
		if definition.get("body_enabled",true):
			return host.has_method(&"microscenario_supports_prepared_physical_liquid") \
				and host.microscenario_supports_prepared_physical_liquid(definition)
		return host.has_method(&"microscenario_apply_exploratory_liquid")
	if definition.get("body_enabled",true): return false
	return (not definition.get("player_enabled",true)
		and definition.get("execution",{}).get("policy","") == "fixed"
		and definition.get("interest",{}).get("policy","") == "fixed")

func _request(definition: Dictionary, original_control: bool = false, mode: String = "Inspect", active_route: bool = false) -> bool:
	_refusal = ""
	if bridge == null or not bridge.has_method(&"liquid_policy_assignment_choices"):
		_refusal = "This runtime has no native liquid comparison editor"
		return false
	if not _definition_supported(definition) and not (active_route and _active_owner_supported()):
		_refusal = "This route is not yet wired for experimental policies. Choose a fixed actor-free MicroScenario or load Dam Break."
		return false
	if not original_control and selected_radius() == 3 \
		and not bridge.has_method(&"liquid_policy_with_inertial_damping"):
		_refusal = "This runtime has no explicit matched-IN geometry support"
		return false
	var admitted: bool
	if original_control: admitted = host.microscenario_apply_definition(definition, mode)
	elif active_route:
		admitted = host.liquid_comparison_apply_active(requested_policy,normalize_water.button_pressed,
			session_picker.selected == 1,mode,selected_radius())
	elif session_picker.selected == 1:
		admitted = host.microscenario_apply_exploratory_liquid(definition, requested_policy, normalize_water.button_pressed, mode,{},selected_radius())
	else: admitted = host.microscenario_apply_controlled_liquid(definition, requested_policy, normalize_water.button_pressed, mode,selected_radius())
	if not admitted:
		_refusal = str(host.microscenario_error)
		return false
	_comparison_pending = not original_control
	if not host.pending_microscenario_apply.is_empty():
		_waiting_serial = int(host.pending_microscenario_apply.serial)
	else:
		_dirty = false
		_sync_applied(host.tower_context)
		_accept_comparison(host.tower_context)
	return true

func _accept_comparison(context: Dictionary) -> void:
	comparison_generation = int(context.get("liquid_solver_policy",{}).get("session_generation",-1)) if _comparison_pending else -1
	_comparison_pending = false

# Explicit request geometry. Preferred resolves to each family's native radius:
# three when any selected assignment requires it, otherwise two.
func selected_radius() -> int:
	var selected: int = geometry_picker.get_selected_id()
	if selected != 0: return selected
	return maxi(2, int(_validation.get("receipt",{}).get("minimum_rule_radius",2)))

# Replace only the pending Water assignment, through the native choice list.
func select_water_family(family: String, variant: String = "reference") -> bool:
	if bridge == null or not bridge.has_method(&"liquid_policy_assignment_choices"): return false
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(requested_policy, 3):
		if choice.family != family or choice.variant != variant: continue
		if not choice.accepted:
			_refusal = str(choice.refusal.code) + ": " + str(choice.refusal.detail)
			return false
		requested_policy = choice.request.duplicate()
		_dirty = true
		_refusal = ""
		_refresh_choices()
		return true
	_refusal = "This runtime offers no Water %s/%s choice" % [family, variant]
	return false

func requested_water_assignment() -> Dictionary:
	for assignment: Dictionary in _validation.get("receipt",{}).get("assignments",[]):
		if int(assignment.material) == 3:
			return {"family":str(assignment.applied_family), "variant":str(assignment.applied_variant)}
	return {}

# Copied accepted comparison selection for Main's fresh-owner reload.
func relaunch_envelope() -> Dictionary:
	var context: Dictionary = host.tower_context
	var applied: Dictionary = context.get("liquid_solver_policy",{})
	if comparison_generation < 0 or int(applied.get("session_generation",-2)) != comparison_generation: return {}
	if host.microscenario_definition.is_empty() or not applied.has("envelope"): return {}
	return {"definition":host.microscenario_definition.duplicate(true), "policy":PackedInt32Array(applied.envelope),
		"normalization":str(host.microscenario_liquid_setup.get("normalization","")),
		"radius":int(applied.get("maximum_rule_radius",2)), "mode":str(host.microscenario_mode),
		"setup_index":setup_picker.selected, "geometry_index":geometry_picker.selected}

func restore_relaunch(envelope: Dictionary) -> bool:
	requested_policy = PackedInt32Array(envelope.policy)
	normalize_water.set_pressed_no_signal(str(envelope.normalization) == "water-normalize-v1")
	setup_picker.select(int(envelope.setup_index))
	geometry_picker.select(int(envelope.geometry_index))
	session_picker.select(0)
	_dirty = true
	_refresh_choices()
	_comparison_pending = true
	var admitted: bool = host.microscenario_apply_controlled_liquid(envelope.definition, requested_policy,
		str(envelope.normalization) == "water-normalize-v1", str(envelope.mode), int(envelope.radius))
	if not admitted:
		_comparison_pending = false
		_refusal = str(host.microscenario_error)
		return false
	if not host.pending_microscenario_apply.is_empty(): _waiting_serial = int(host.pending_microscenario_apply.serial)
	return true

func apply_active() -> bool:
	return _request(host.liquid_comparison_active_definition(),false,host.microscenario_mode,true)

func _active_owner_supported() -> bool:
	return host.has_method(&"liquid_comparison_can_apply_active") \
		and host.liquid_comparison_can_apply_active(session_picker.selected == 1)

func arm_import() -> bool:
	if import_button == null: return false
	var accepted: bool = host.liquid_comparison_arm_import(requested_policy,normalize_water.button_pressed,
		session_picker.selected==1,selected_radius())
	_refusal = "" if accepted else str(host.microscenario_error)
	_dirty = true
	return accepted

func clear_import() -> void:
	if import_button != null: host.liquid_comparison_clear_import()
	_refusal = ""

func _selected_definition() -> Dictionary:
	var path: String = DAM_PATH if setup_picker.selected == 0 else MIXED_PATH
	if setup_picker.selected >= SETUP_BUILTIN_COUNT:
		var entry: Dictionary = FeelCatalogue.entry(setup_picker.selected - SETUP_BUILTIN_COUNT)
		if entry.is_empty() or entry.has("unavailable"):
			_refusal = str(entry.get("unavailable","Unknown comparison scenario"))
			return {}
		path = str(entry.fixture)
	var checked: Dictionary = Contract.parse(FileAccess.get_file_as_string(path))
	if not checked.get("ok",false):
		_refusal = str(checked.get("error","Protected Dam Break unavailable"))
		return {}
	return checked.definition

func load_dam() -> bool:
	setup_picker.select(0)
	return load_selected()

func load_selected() -> bool:
	return _request(_selected_definition())

func load_current_control() -> bool:
	return _request(_selected_definition(), true)

func _sync_applied(context: Dictionary) -> void:
	var applied: Dictionary = context.get("liquid_solver_policy",{})
	if applied.is_empty() or not applied.has("envelope"): return
	_applied_generation = int(applied.session_generation)
	if not _dirty:
		requested_policy = applied.envelope.duplicate()
		geometry_picker.select(1 if int(applied.get("maximum_rule_radius",2)) == 3 else 0)
		session_picker.select(1 if host.microscenario_liquid_setup.get("intent", "controlled") == "exploratory" else 0)
		normalize_water.set_pressed_no_signal(not host.microscenario_liquid_setup.is_empty() \
			and host.microscenario_liquid_setup.get("normalization","") == "water-normalize-v1")
		_refresh_choices()

func refresh(context: Dictionary) -> void:
	var available: bool = bridge != null and bridge.has_method(&"liquid_policy_assignment_choices")
	var pending: bool = not host.pending_microscenario_apply.is_empty() or not host.pending_water_apply.is_empty()
	var blind: bool = not host.water_blind_set.is_empty() or not host.water_active_blind_label.is_empty()
	var import_state: Dictionary = host.liquid_comparison_import_state() if import_button != null else {}
	if _waiting_serial != 0 and not pending and int(context.get("scenario_request_serial",0)) == _waiting_serial:
		if context.get("scenario_request_applied",false):
			_dirty = false
			_accept_comparison(context)
		else:
			_comparison_pending = false
			_refusal = str(host.microscenario_error)
		_waiting_serial = 0
	var generation: int = int(context.get("liquid_solver_policy",{}).get("session_generation",-1))
	if available and generation != _applied_generation:
		if import_state.get("applied",false) and requested_policy == context.get("liquid_solver_policy",{}).get("envelope",null): _dirty = false
		_sync_applied(context)
	session_picker.disabled = not available or pending or blind
	geometry_picker.disabled = not available or pending or blind or not bridge.has_method(&"liquid_policy_with_inertial_damping")
	damping_numerator.editable = not pending and not blind and available \
		and bridge.has_method(&"liquid_policy_with_inertial_damping") \
		and not _validation.get("receipt",{}).get("family_parameters",{}).get("inertial_cellular_v1",{}).is_empty()
	preset_picker.disabled = not available or pending or blind
	setup_picker.disabled = not available or pending or blind
	material_picker.disabled = not available or pending or blind
	family_picker.disabled = not available or pending or blind
	normalize_water.disabled = not available or pending or blind
	dam_button.disabled = not available or pending or blind
	control_button.disabled = not available or pending or blind
	apply_button.disabled = not available or pending or blind or not (_definition_supported(host.liquid_comparison_active_definition()) or _active_owner_supported())
	if import_button != null:
		import_button.disabled = not available or pending or blind or session_picker.selected!=1
		clear_import_button.disabled = pending or blind or not import_state.get("armed",false)
	var applied: Dictionary = context.get("liquid_solver_policy",{})
	var typed: Dictionary = context.get("liquid_construction_receipt",{})
	receipt_label.text = "Applied native policy: " + str(applied.get("policy_hash","unavailable")).left(16)
	for assignment: Dictionary in applied.get("assignments",[]):
		if int(assignment.material) == 3:
			receipt_label.text += " • Water " + str(assignment.applied_family) + "/" + str(assignment.applied_variant)
	if not typed.is_empty():
		receipt_label.text += "\nNative receipt " + str(typed.receipt_hash).left(16) + " • " + str(typed.get("run_intent","controlled")) + " • host/source proof pending"
		var observed: Dictionary = context.get("liquid_host_observation",{})
		if not observed.is_empty(): receipt_label.text += "\nHost record " + str(observed.digest).left(16) + " • qualified"
		var normalized: Dictionary = typed.get("normalization",{})
		if not normalized.is_empty():
			receipt_label.text += " • Water added %s / removed %s / net %s" % [normalized.positive_delta, normalized.negative_delta, normalized.net_delta]
		var inertial: Dictionary = applied.get("family_parameters",{}).get("inertial_cellular_v1",{})
		if not inertial.is_empty():
			receipt_label.text += "\nApplied IN damping %s/%s • hash/CYPS v%s • radius %s" % [inertial.damping_numerator,inertial.damping_denominator,applied.physical_state_hash_version,applied.maximum_rule_radius]
	else:
		receipt_label.text += " • original constructor; no typed setup receipt"
	if not available: status.text = "This runtime has no liquid comparison editor; a source-matched native rebuild is required."
	elif blind: status.text = "Finish the Water blind session before changing solver policy."
	elif pending: status.text = "Rebuilding at the existing owner boundary…"
	elif context.get("microscenario",{}).get("failed",false): status.text = "Installed session apparatus failed: " + str(context.microscenario.get("error","unavailable"))
	elif not _refusal.is_empty(): status.text = "Refused; applied session retained. " + _refusal
	elif import_state.get("armed",false): status.text = "Next ordinary body-free level import uses the captured selection " + str(import_state.pending_policy_hash).left(16) + ". The running World is unchanged."
	elif import_state.get("applied",false) and not _dirty: status.text = "Imported setup is applied. P runs; R / Restart rebuilds its accepted payload and selected liquids. Level saves still reconstruct Current defaults unless a policy is explicitly armed."
	elif not (_definition_supported(host.liquid_comparison_active_definition()) or _active_owner_supported()): status.text = "Controlled needs a fixed actor-free setup. Exploratory retains sampled owners in Tower or supported MicroScenarios and desktop articulated owners; other routes remain pending."
	elif _dirty:
		status.text = "Pending solver/normalization selection. The running World keeps its applied policy until rebuild."
		if int(_validation.get("receipt",{}).get("minimum_rule_radius",2)) > selected_radius():
			status.text += " IN Brine requires the explicit matched geometry selection."
	else: status.text = "Applied setup is ready. Reset keeps its accepted policy and normalization selection."
	if feel_controls != null: feel_controls.observe(context)
