extends Window

# A staged authoring window. Inspection and widget refresh never issue an actor
# observation, consume RNG, renew a lease or reset an admitted controller.
signal profile_applied(instance_id: int, profile: Dictionary)
signal overlay_requested(instance_id: int, enabled: bool)

const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Actuator = preload("res://scripts/ambient/ambient_actuator.gd")
const MaterialCatalogue = preload("res://scripts/material_lab_catalogue.gd")
const Authoring = preload("res://scripts/ambient/ambient_authoring.gd")
var wb: Control
var _instance_id := 0
var _model := ""
var _definition_hash := ""
var _bound_run := ""
var _bound_epoch := -1
var _baseline_profile: Dictionary = {}
var _draft: Dictionary = {}
var _loading := false
var _selected_module := -1
var _poll_elapsed := 0.0
var _materials: Array = []
var _material_ids: Array = []
var _presets: Array = []
var _presets_picker := OptionButton.new()
var _profile_id := LineEdit.new()
var _profile_name := LineEdit.new()
var _description := TextEdit.new()
var _seed := SpinBox.new()
var _shared_seed := CheckButton.new()
var _module_list := ItemList.new()
var _module_type := OptionButton.new()
var _parameter_body := VBoxContainer.new()
var _profile_status := Label.new()
var _target := Label.new()
var _inspector := TextEdit.new()
var _overlay := CheckButton.new()
var _apply_button := Button.new()
var _content_scroll := ScrollContainer.new()
var _mounted := false
var _catalogue_search := LineEdit.new()
var _living_body := VBoxContainer.new()
var _places_body := VBoxContainer.new()
var _library_body := VBoxContainer.new()
var _region_list: ItemList
var _region_fields: VBoxContainer
var _region_selected := -1
var _library_list: ItemList
var _group_list: ItemList
var _library_baseline: Dictionary = {}
var _group_expected: Dictionary = {}



func mount(workbench: Control) -> void:
	if _mounted: return
	_mounted = true
	wb = workbench
	title = "CyberSand / Behaviour profile"
	size = Vector2i(1020, 760)
	min_size = Vector2i(740, 480)
	transient = true
	exclusive = false
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.follow_focus = true
	margin.add_child(_content_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(column)
	var row := _row(column)
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_target)
	_button(row, "Close", hide)
	row = _row(column)
	_label(row, "Preset")
	_presets_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_presets_picker.fit_to_longest_item = false
	row.add_child(_presets_picker)
	_presets_picker.item_selected.connect(_choose_preset)
	_button(row, "Duplicate to customize", duplicate_draft)
	row = _row(column)
	_label(row, "Name")
	_profile_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_name.max_length = 80
	row.add_child(_profile_name)
	_profile_name.text_changed.connect(func(value: String) -> void:
		if not _loading: _draft.name = value; _validate_draft())
	_label(row, "ID")
	_profile_id.custom_minimum_size.x = 180
	_profile_id.max_length = 64
	row.add_child(_profile_id)
	_profile_id.text_changed.connect(func(value: String) -> void:
		if not _loading: _draft.id = value; _validate_draft())
	_description.custom_minimum_size.y = 54
	_description.placeholder_text = "Describe the personality. Configuration is saved; live intentions are not."
	column.add_child(_description)
	_description.text_changed.connect(func() -> void:
		if not _loading: _draft.description = _description.text; _validate_draft())
	row = _row(column)
	_label(row, "Seed")
	_seed.min_value = 0
	_seed.max_value = Profile.MAX_SEED
	_seed.step = 1
	_seed.custom_minimum_size.x = 180
	row.add_child(_seed)
	_seed.value_changed.connect(func(value: float) -> void:
		if not _loading: _draft.seed = int(value); _validate_draft())
	_shared_seed.text = "Share identical seed across actors"
	_shared_seed.tooltip_text = "Off: mix this seed with each authored actor ID. On: actors receive the same RNG seed; different observations can still produce different actions."
	row.add_child(_shared_seed)
	_shared_seed.toggled.connect(func(value: bool) -> void:
		if not _loading: _draft.shared_seed = value; _validate_draft())
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.y = 260
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	var split := HSplitContainer.new()
	split.name = "Modules"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 290
	tabs.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 245
	split.add_child(left)
	_label(left, "Modules · equal priorities use list order")
	_module_list.custom_minimum_size.y = 150
	_module_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_module_list)
	_module_list.item_selected.connect(func(index: int) -> void: _selected_module = index; _show_module())
	row = _row(left)
	_button(row, "Up", func() -> void: move_module(-1))
	_button(row, "Down", func() -> void: move_module(1))
	_button(row, "Remove", remove_module)
	_catalogue_search.placeholder_text = "Search module catalogue…"
	_catalogue_search.tooltip_text = "Search labels, descriptions, requirements and stable module IDs."
	left.add_child(_catalogue_search)
	_catalogue_search.text_changed.connect(_filter_catalogue)
	row = _row(left)
	_module_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_module_type.fit_to_longest_item = false
	row.add_child(_module_type)
	_filter_catalogue("")
	_button(row, "Add", func() -> void:
		if _module_type.selected >= 0: add_module(str(_module_type.get_item_metadata(_module_type.selected))))
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)
	_parameter_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_parameter_body)
	_add_tab(tabs, _living_body, "Personality")
	_add_tab(tabs, _places_body, "Places and peers")
	_add_tab(tabs, _library_body, "Library and group")
	_profile_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_profile_status)
	row = _row(column)
	_apply_button.text = "Apply profile to this actor"
	_apply_button.pressed.connect(apply_draft)
	row.add_child(_apply_button)
	_button(row, "Revert staged edits", revert_draft)
	_overlay.text = "Intent, perception and memory"
	_overlay.tooltip_text = "Draw copied observations only. Off by default; does not change decisions."
	_overlay.toggled.connect(func(value: bool) -> void:
		overlay_requested.emit(_instance_id, value)
		if wb != null and wb.has_method("set_ambient_overlay"): wb.call("set_ambient_overlay", _instance_id, value))
	row.add_child(_overlay)
	var save_note := _label(column, "Apply acknowledges a live controller change and resets its private intent. Save the Workbench scene to keep this authored profile. Reopen starts fresh timers and RNG.")
	save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.editable = false
	_inspector.custom_minimum_size.y = 115
	_inspector.placeholder_text = "Live intent and sensor diagnostics appear here."
	column.add_child(_inspector)
	_load_materials()
	_presets = Profile.presets()
	_presets_picker.add_item("Choose a preset…")
	for profile: Dictionary in _presets:
		_presets_picker.add_item(str(profile.name))
		_presets_picker.set_item_metadata(_presets_picker.item_count - 1, str(profile.id))
	set_process(true)


func _row(parent: Node) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", 8)
	parent.add_child(result)
	return result


func _label(parent: Node, text: String) -> Label:
	var result := Label.new()
	result.text = text
	parent.add_child(result)
	return result


func _button(parent: Node, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.pressed.connect(action)
	parent.add_child(result)
	return result


func _load_materials() -> void:
	_materials.clear()
	_material_ids.clear()
	var catalogue := MaterialCatalogue.new()
	if not catalogue.reload(): return
	for item: Dictionary in catalogue.materials:
		if int(item.id) > 0 and bool(item.get("valid", false)):
			_materials.append({"id": int(item.id), "name": str(item.name)})
			_material_ids.append(int(item.id))


func open_for(instance_id: int) -> void:
	if wb == null: return
	_instance_id = instance_id
	_overlay.set_pressed_no_signal(false)
	if wb.has_method("set_ambient_overlay"): wb.call("set_ambient_overlay", instance_id, false)
	revert_draft()
	popup_centered()
	refresh_inspection()


func _actor() -> Dictionary:
	if wb == null: return {}
	return wb.actor(wb.applied, _instance_id)


func staged_profile() -> Dictionary:
	return _draft.duplicate(true)


func replace_draft(profile: Dictionary) -> bool:
	var error := Profile.validate(profile)
	if not error.is_empty():
		_profile_status.text = "Staged profile refused: " + error
		return false
	_draft = Profile.canonicalize(profile)
	_selected_module = 0 if not _draft.modules.is_empty() else -1
	_show_profile()
	return true


func revert_draft() -> void:
	var actor := _actor()
	if actor.is_empty():
		_model = ""
		_definition_hash = ""
		_bound_run = ""
		_bound_epoch = -1
		_baseline_profile = {}
		_draft = Profile.blank()
		_target.text = "No available actor. Inspect an actor, then open Behaviour profile."
	else:
		_model = str(actor.model)
		_definition_hash = str(actor.hash)
		var session_view := _session_view()
		_bound_run = str(session_view.get("run_id", ""))
		_bound_epoch = int(session_view.get("epoch", -1))
		var control := Catalog.control_for(actor)
		_baseline_profile = control.get("ambient", {}).duplicate(true)
		_draft = _baseline_profile.duplicate(true)
		if _draft.is_empty():
			_draft = Profile.preset("drifting_flyer" if bool(Actuator.capabilities(_model).get("vertical", false)) else "oil_moth")
		if _draft.is_empty(): _draft = Profile.blank()
		_target.text = "Profile for #%d · %s · staged edits do not drive the actor" % [_instance_id, _model]
	_selected_module = 0 if not _draft.modules.is_empty() else -1
	_library_baseline = wb.ambient_library() if wb.has_method("ambient_library") else Authoring.blank()
	_group_expected = _capture_group()
	_show_profile()
	refresh_inspection()


func _choose_preset(index: int) -> void:
	if _loading or index <= 0 or index > _presets.size(): return
	replace_draft(_presets[index - 1])
	_profile_status.text = "Preset staged. Apply to acknowledge the controller change."


func duplicate_draft() -> void:
	if _draft.is_empty(): return
	_draft = _draft.duplicate(true)
	_draft.id = str(_draft.id).left(59) + "_copy"
	_draft.name = str(_draft.name).left(74) + " copy"
	_draft.seed = (int(_draft.seed) + 1) % (Profile.MAX_SEED + 1)
	_draft.shared_seed = false
	_show_profile()
	_profile_status.text = "Independent copy staged; existing actors keep their admitted profiles."


func _show_profile() -> void:
	_loading = true
	_profile_id.text = str(_draft.get("id", ""))
	_profile_name.text = str(_draft.get("name", ""))
	_description.text = str(_draft.get("description", ""))
	_seed.set_value_no_signal(float(_draft.get("seed", 1)))
	_shared_seed.set_pressed_no_signal(bool(_draft.get("shared_seed", false)))
	_presets_picker.select(0)
	_loading = false
	_refresh_module_list()
	_show_module()
	_show_living_settings()
	_show_places()
	_show_library()
	_validate_draft()


func _refresh_module_list() -> void:
	_module_list.clear()
	for module: Dictionary in _draft.get("modules", []):
		_module_list.add_item("%s %s · P%d" % ["●" if module.enabled else "○",
			str(Profile.module_spec(str(module.type)).get("label", module.type)), int(module.priority)])
		_module_list.set_item_tooltip(_module_list.item_count - 1, str(module.id))
	if _selected_module >= 0 and _selected_module < _module_list.item_count:
		_module_list.select(_selected_module)


func add_module(type: String) -> bool:
	if _draft.get("modules", []).size() >= Profile.MAX_MODULES:
		_profile_status.text = "Sixteen-module limit reached. Remove a module before adding another."
		return false
	var index := 1
	var instance_id := type
	var used := {}
	for module: Dictionary in _draft.get("modules", []): used[str(module.id)] = true
	while used.has(instance_id):
		index += 1
		instance_id = type + "_" + str(index)
	var module := Profile.make_module(type, instance_id)
	if module.is_empty(): return false
	_draft.modules.append(module)
	_selected_module = _draft.modules.size() - 1
	_refresh_module_list()
	_show_module()
	_validate_draft()
	return true


func remove_module() -> void:
	if _selected_module < 0 or _selected_module >= _draft.get("modules", []).size(): return
	_draft.modules.remove_at(_selected_module)
	_selected_module = mini(_selected_module, _draft.modules.size() - 1)
	_refresh_module_list()
	_show_module()
	_validate_draft()


func move_module(direction: int) -> void:
	var next := _selected_module + direction
	if _selected_module < 0 or next < 0 or next >= _draft.get("modules", []).size(): return
	var module: Dictionary = _draft.modules[_selected_module]
	_draft.modules.remove_at(_selected_module)
	_draft.modules.insert(next, module)
	_selected_module = next
	_refresh_module_list()
	_show_module()
	_validate_draft()


func _show_module() -> void:
	for child: Node in _parameter_body.get_children():
		_parameter_body.remove_child(child)
		child.queue_free()
	if _selected_module < 0 or _selected_module >= _draft.get("modules", []).size():
		var empty := _label(_parameter_body, "Add a module to author a behaviour. An empty profile produces neutral intent.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var module: Dictionary = _draft.modules[_selected_module]
	var spec := Profile.module_spec(str(module.type))
	var heading := _label(_parameter_body, str(spec.get("label", module.type)))
	heading.add_theme_font_size_override("font_size", 19)
	var description := _label(_parameter_body, str(spec.get("description", "")))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var requirements := _label(_parameter_body, "Needs: %s · capabilities: %s" % [", ".join(spec.get("requires", [])), ", ".join(spec.get("capabilities", []))])
	requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := _row(_parameter_body)
	var enabled := CheckButton.new()
	enabled.text = "Enabled"
	enabled.set_pressed_no_signal(bool(module.enabled))
	row.add_child(enabled)
	enabled.toggled.connect(func(value: bool) -> void: module.enabled = value; _refresh_module_list(); _validate_draft())
	_label(row, "Instance ID")
	var instance_id := LineEdit.new()
	instance_id.text = str(module.id)
	instance_id.max_length = 64
	instance_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(instance_id)
	instance_id.text_changed.connect(func(value: String) -> void: module.id = value; _validate_draft())
	_numeric(_parameter_body, module, "priority", {"type":"integer", "min":0, "max":1000, "unit":"priority", "description":"Higher-priority override wins; list order breaks equal-priority ties."}, false)
	_numeric(_parameter_body, module, "weight", {"type":"number", "min":0.0, "max":10.0, "unit":"weight", "description":"Relative continuous steering strength; zero removes this module's contribution, including overrides."}, false)
	for key: String in spec.params:
		var parameter: Dictionary = spec.params[key]
		if key == "material_id": _material_parameter(module, key, parameter)
		elif str(parameter.get("type", "")) in ["bool", "boolean"]:
			var button := CheckButton.new()
			button.text = key.capitalize()
			button.tooltip_text = str(parameter.get("description", ""))
			button.set_pressed_no_signal(bool(module.params[key]))
			_parameter_body.add_child(button)
			button.toggled.connect(func(value: bool) -> void: module.params[key] = value; _validate_draft())
		elif str(parameter.get("type", "")) == "region": _region_parameter(module, key, parameter)
		elif str(parameter.get("type", "")) == "points": _points_parameter(module, key, parameter)
		elif str(parameter.get("type", "")) in ["string", "identifier"]:
			_text_parameter(module.params, key, parameter, _parameter_body)
		else: _numeric(_parameter_body, module, key, parameter, true)


func _numeric(parent: Node, module: Dictionary, key: String, spec: Dictionary, parameter: bool) -> void:
	var row := _row(parent)
	var label := _label(row, key.capitalize() + (" (" + str(spec.unit) + ")" if not str(spec.get("unit", "")).is_empty() else ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = str(spec.get("description", ""))
	var field := SpinBox.new()
	field.set_meta("ambient_parameter", key)
	field.min_value = float(spec.get("min", 0.0))
	field.max_value = float(spec.get("max", 1.0))
	var integer := str(spec.get("type", "")) in ["int", "integer", "material"]
	field.step = 1.0 if integer else 0.05
	field.custom_minimum_size.x = 140
	field.tooltip_text = label.tooltip_text
	field.set_value_no_signal(float(module.params[key] if parameter else module[key]))
	row.add_child(field)
	if parameter and key == "effort" and not bool(Actuator.capabilities(_model).get("effort_channel", true)):
		field.editable = false
		row.modulate = Color(1.0, 1.0, 1.0, 0.65)
		var note := _label(parent, "This rig uses Pace only. Effort is retained for compatible ground and wheel profiles.")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		field.tooltip_text = note.text
	field.value_changed.connect(func(value: float) -> void:
		var stored: Variant = int(value) if integer else value
		if parameter: module.params[key] = stored
		else: module[key] = stored
		if key == "priority": _refresh_module_list()
		_validate_draft())


func _material_parameter(module: Dictionary, key: String, spec: Dictionary) -> void:
	var row := _row(_parameter_body)
	_label(row, "Material (native stable ID)")
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.tooltip_text = str(spec.get("description", "")) + " Actual compiled material catalogue."
	row.add_child(picker)
	for material: Dictionary in _materials:
		picker.add_item("%03d · %s" % [int(material.id), str(material.name)], int(material.id))
	var selected := picker.get_item_index(int(module.params[key]))
	if selected < 0:
		picker.add_item("%03d · catalogue unavailable" % int(module.params[key]), int(module.params[key]))
		selected = picker.item_count - 1
	picker.select(selected)
	picker.disabled = _materials.is_empty()
	picker.item_selected.connect(func(index: int) -> void: module.params[key] = picker.get_item_id(index); _validate_draft())
	if _materials.is_empty():
		var note := _label(_parameter_body, "Native material catalogue unavailable. The authored ID is retained; reload a source-matched runtime to change material selection.")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _validate_draft() -> void:
	var error := Profile.validate(_draft, _material_ids, Actuator.capabilities(_model))
	_apply_button.disabled = _actor().is_empty()
	_profile_status.text = "Staged: " + error if not error.is_empty() else "Staged profile is valid. Apply changes only this actor; save the Workbench scene to retain it."


func apply_draft() -> bool:
	var actor := _actor()
	if actor.is_empty():
		_profile_status.text = "Apply refused: this actor no longer exists."
		return false
	if str(actor.model) != _model or str(actor.hash) != _definition_hash:
		_profile_status.text = "Apply refused: the inspected actor was replaced. Revert to inspect its current profile."
		return false
	var current_session := _session_view()
	if _bound_run.is_empty() or str(current_session.get("run_id", "")) != _bound_run \
		or int(current_session.get("epoch", -1)) != _bound_epoch:
		_profile_status.text = "Apply refused: the authored World or actor session was replaced. Revert to bind this editor to the current actor."
		return false
	var error := Profile.validate(_draft, _material_ids, Actuator.capabilities(_model))
	if not error.is_empty():
		_profile_status.text = "Apply refused: " + error + " Previous valid profile remains active."
		return false
	var control := Catalog.control_for(actor)
	if control.get("ambient", {}) != _baseline_profile:
		_profile_status.text = "Apply refused: the profile changed outside this editor. Revert to load its admitted version."
		return false
	control.source = "policy"
	control.policy = "ambient"
	control.enabled = true
	control.ambient = Profile.canonicalize(_draft)
	if not wb.set_actor_control(_instance_id, control):
		_profile_status.text = "Apply refused: " + str(wb.message) + " Previous valid profile remains active."
		return false
	_baseline_profile = control.ambient.duplicate(true)
	_draft = control.ambient.duplicate(true)
	_profile_status.text = "Applied to #%d. Procedural NPC is active when Play advances; private intentions restarted. Save the scene to retain this profile." % _instance_id
	profile_applied.emit(_instance_id, _draft.duplicate(true))
	refresh_inspection()
	return true


func _process(delta: float) -> void:
	if not visible: return
	_poll_elapsed += delta
	if _poll_elapsed < 0.2: return
	_poll_elapsed = 0.0
	refresh_inspection()


func refresh_inspection() -> void:
	if wb == null or _actor().is_empty():
		_inspector.text = "Actor unavailable. No controller state was changed by inspection."
		return
	if wb.host == null or wb.host.physical_actor_session == null:
		_inspector.text = "Waiting for the current authored actor session."
		return
	var view := _session_view()
	var diagnostics: Dictionary = view.get("diagnostics", {})
	var ambient: Dictionary = diagnostics.get("ambient", {})
	var environment: Dictionary = diagnostics.get("environment", {})
	_inspector.text = "#%d · %s · decisions every %d physical ticks · lease %d ticks\n" % [_instance_id,
		str(view.get("status", "waiting")), int(view.get("decision_ticks", 6)), int(view.get("lease_remaining", 0))]
	if not ambient.is_empty():
		var intent: Dictionary = ambient.get("intent", {})
		_inspector.text += "Intent: %s · override: %s · remaining %.2f s · elapsed %.2f s\n" % [
			str(intent.get("reason", "waiting for first decision")), str(intent.get("active_override", "")),
			float(intent.get("remaining_seconds", 0.0)), float(ambient.get("elapsed_seconds", 0.0))]
		_inspector.text += "Direction %s · pace %.2f · effort %.2f · decisions %d · sensor %d µs / decision %d µs\n" % [
			str(intent.get("direction", Vector2.ZERO)), float(intent.get("pace", 0.0)), float(intent.get("effort", 0.0)),
			int(ambient.get("decisions", 0)), int(view.get("sensor_usec", 0)), int(view.get("decision_usec", 0))]
		var materials: Dictionary = environment.get("materials", {})
		_inspector.text += "Material coverage: %s\n" % ("available · nearest observed only" if bool(materials.get("available", false)) else "unavailable: " + str(materials.get("reason", "waiting")))
		for id: Variant in materials.get("targets", {}):
			var target: Dictionary = materials.targets[id]
			_inspector.text += "  Material %s: %s\n" % [str(id), "observed at %.2f cells" % float(target.get("distance", 0.0)) if bool(target.get("present", false)) else str(target.get("reason", "no match observed"))]
		for candidate: Dictionary in intent.get("candidates", []):
			_inspector.text += "  %s · %s · score %.2f · %s\n" % [str(candidate.get("id", "")),
				"active" if bool(candidate.get("active", false)) else "inactive", float(candidate.get("score", 0.0)), str(candidate.get("reason", ""))]
		var memory: Dictionary = ambient.get("memory", {})
		if not memory.is_empty():
			_inspector.text += "Memory: %d visited · %d interests · %d failed approaches · %s\n" % [
				memory.get("visited", []).size(), memory.get("interests", []).size(),
				memory.get("obstructions", []).size(),
				"active" if bool(memory.get("enabled", false)) else "disabled"]
			_inspector.text += "Goal: %s · phase %s · commitment %.2f s · drives %s\n" % [
				str(intent.get("selected_goal", "")), str(intent.get("goal_phase", "")),
				float(intent.get("commitment_remaining_seconds", 0.0)), str(ambient.get("drives", {}))]
			var recent: Array = ambient.get("recent_decisions", [])
			for index: int in range(maxi(0, recent.size() - 6), recent.size()):
				var transition: Dictionary = recent[index]
				_inspector.text += "  %.1f s · %s · %s · %s\n" % [float(transition.get("time", 0.0)),
					str(transition.get("selected", "")), str(transition.get("phase", "")), str(transition.get("reason", ""))]
	else:
		_inspector.text += "No ambient decision yet. Select Procedural NPC / Ambient and Play. Inspection is read-only."


func _session_view() -> Dictionary:
	if wb == null or wb.host == null or wb.host.physical_actor_session == null: return {}
	return wb.host.physical_actor_session.workbench_control(_instance_id)


func _json(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[str(key)] = _json(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json(item))
		return result
	if value is Vector2 or value is Vector2i: return [value.x, value.y]
	if value is StringName: return str(value)
	return value


func _add_tab(tabs: TabContainer, body: VBoxContainer, label: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = label
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)


func _clear_body(body: Node) -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()


func _note(parent: Node, text: String) -> Label:
	var label := _label(parent, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _filter_catalogue(query: String) -> void:
	var selected := str(_module_type.get_item_metadata(_module_type.selected)) if _module_type.selected >= 0 else ""
	_module_type.clear()
	var needle := query.strip_edges().to_lower()
	for type: String in Profile.module_types():
		var spec := Profile.module_spec(type)
		var haystack := "%s %s %s %s" % [type, spec.get("label", ""), spec.get("description", ""), " ".join(spec.get("requires", []))]
		if not needle.is_empty() and not haystack.to_lower().contains(needle): continue
		_module_type.add_item(str(spec.get("label", type)))
		_module_type.set_item_metadata(_module_type.item_count - 1, type)
		if type == selected: _module_type.select(_module_type.item_count - 1)
	_module_type.tooltip_text = "%d matching modules. Adding a module changes only the staged profile." % _module_type.item_count


func enable_living_settings() -> void:
	var upgraded: Dictionary = Profile.upgrade(_draft)
	if upgraded.is_empty():
		_profile_status.text = "Cannot enable living settings on an invalid draft."
		return
	_draft = upgraded
	_show_profile()
	_profile_status.text = "Living settings staged. Apply acknowledges a controller change; previous configuration remains active."


func _living_enabled() -> bool:
	return int(_draft.get("version", 1)) >= 2


func _show_living_settings() -> void:
	_clear_body(_living_body)
	if not _living_enabled():
		_note(_living_body, "This is an original AMBIENT-001 profile. Its authored behaviour stays unchanged until you explicitly enable living settings.")
		_button(_living_body, "Enable living settings in this draft", enable_living_settings)
		return
	_note(_living_body, "Traits change documented decision mechanisms. They are authored settings; private drives and remembered places restart after Apply, Reset or Reopen.")
	_bool_field(_living_body, _draft, "drives_enabled", "Allow finite exploration and social drives to accumulate with physical simulation time. Disable for a matched drive ablation.")
	for key: String in Profile.personality_specs():
		var spec: Dictionary = Profile.personality_specs()[key]
		if str(spec.get("type", "")) in ["bool", "boolean"]:
			_bool_field(_living_body, _draft.personality, key, str(spec.get("description", "")))
		else:
			_value_field(_living_body, _draft.personality, key, spec, "trait_" + key)
	_label(_living_body, "Bounded spatial memory")
	var memory: Dictionary = _draft.memory
	_bool_field(_living_body, memory, "enabled", "Remember visited cells, interests and failed approaches. Disable for a matched memory ablation.")
	for key: String in Profile.memory_specs():
		if key == "enabled": continue
		_value_field(_living_body, memory, key, Profile.memory_specs()[key], "memory_" + key)
	_label(_living_body, "Perception budget")
	for key: String in Profile.perception_specs():
		var spec: Dictionary = Profile.perception_specs()[key]
		if str(spec.get("type", "")) in ["bool", "boolean"]:
			_bool_field(_living_body, _draft.perception, key, str(spec.get("description", "")))
		else:
			_value_field(_living_body, _draft.perception, key, spec, "perception_" + key)
	_note(_living_body, "Sampling spacing is requested resolution. The owner may coarsen it to stay within its explicit sample budget; the inspector reports actual coverage.")


func _bool_field(parent: Node, values: Dictionary, key: String, description: String) -> void:
	var button := CheckButton.new()
	button.text = key.capitalize()
	button.tooltip_text = description
	button.set_pressed_no_signal(bool(values.get(key, false)))
	parent.add_child(button)
	_note(parent, description)
	button.toggled.connect(func(value: bool) -> void: values[key] = value; _validate_draft())


func _value_field(parent: Node, values: Dictionary, key: String, spec: Dictionary, metadata: String = "") -> void:
	var row := _row(parent)
	var label := _label(row, key.capitalize() + (" (" + str(spec.get("unit", "")) + ")" if not str(spec.get("unit", "")).is_empty() else ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = str(spec.get("description", ""))
	var field := SpinBox.new()
	field.set_meta("ambient_setting", metadata if not metadata.is_empty() else key)
	field.min_value = float(spec.get("min", 0.0))
	field.max_value = float(spec.get("max", 1.0))
	var integer := str(spec.get("type", "")) in ["integer", "int"]
	field.step = 1.0 if integer else 0.05
	field.custom_minimum_size.x = 140
	field.tooltip_text = label.tooltip_text
	field.set_value_no_signal(float(values.get(key, spec.get("default", 0.0))))
	row.add_child(field)
	if not label.tooltip_text.is_empty(): _note(parent, label.tooltip_text)
	field.value_changed.connect(func(value: float) -> void:
		values[key] = int(value) if integer else value
		_validate_draft())


func _text_parameter(values: Dictionary, key: String, spec: Dictionary, parent: Node) -> void:
	var row := _row(parent)
	_label(row, key.capitalize())
	var field := LineEdit.new()
	field.text = str(values.get(key, ""))
	field.max_length = int(spec.get("max_length", 64))
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.tooltip_text = str(spec.get("description", ""))
	row.add_child(field)
	field.text_changed.connect(func(value: String) -> void: values[key] = value; _validate_draft())


func _show_places() -> void:
	_clear_body(_places_body)
	if not _living_enabled():
		_note(_places_body, "Enable living settings in the Personality tab to author home, interest, avoidance regions and relationships.")
		return
	_note(_places_body, "Regions use native World cell coordinates. They are authored places, not sensed materials or invisible physical walls. Assigning a profile copies these places into each actor's editable configuration.")
	var split := HSplitContainer.new()
	split.custom_minimum_size.y = 170
	_places_body.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 230
	split.add_child(left)
	_region_list = ItemList.new()
	_region_list.custom_minimum_size.y = 130
	left.add_child(_region_list)
	for region: Dictionary in _draft.regions:
		_region_list.add_item("%s · %s" % [str(region.kind).capitalize(), region.name])
	if _region_selected >= _draft.regions.size(): _region_selected = -1
	if _region_selected >= 0: _region_list.select(_region_selected)
	_region_list.item_selected.connect(func(index: int) -> void: _region_selected = index; _show_region_fields())
	var row := _row(left)
	for kind: String in ["home", "interest", "avoid"]:
		_button(row, "+" + kind.capitalize(), func() -> void: add_region(kind))
	_button(left, "Remove selected region", remove_region)
	_region_fields = VBoxContainer.new()
	_region_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_region_fields)
	_show_region_fields()
	_label(_places_body, "Copied peer relationships")
	_note(_places_body, "Tags describe this inhabitant. Preferred and avoided tags filter only actually observed peers. Empty preference tags allow any compatible observed peer.")
	for key: String in ["tags", "prefer_tags", "avoid_tags"]:
		var tag_row := _row(_places_body)
		_label(tag_row, key.capitalize())
		var tags := LineEdit.new()
		tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tags.text = ", ".join(_draft.relations.get(key, []))
		tags.placeholder_text = "Up to eight ASCII identifiers, separated by commas"
		tags.tooltip_text = "Use letters, digits, underscores and hyphens. This field changes only the staged profile."
		tag_row.add_child(tags)
		tags.text_changed.connect(func(value: String) -> void:
			var items: Array = []
			for item: String in value.split(",", false):
				if not item.strip_edges().is_empty(): items.append(item.strip_edges())
			_draft.relations[key] = items
			_validate_draft())
	_value_field(_places_body, _draft.relations, "peer_id", {"type":"integer", "min":-1, "max":2147483646, "unit":"actor ID", "description":"-1 allows any suitable observed peer; a positive ID focuses peer-following modules. Missing peers are not fabricated."})


func add_region(kind: String) -> bool:
	if not _living_enabled() or kind not in ["home", "interest", "avoid"]: return false
	if _draft.regions.size() >= 12:
		_profile_status.text = "Twelve authored regions already staged."
		return false
	for region: Dictionary in _draft.regions:
		if kind == "home" and str(region.kind) == "home":
			_profile_status.text = "A profile has one home region. Edit the existing home."
			return false
	var used := {}
	for region: Dictionary in _draft.regions: used[str(region.id)] = true
	var number := 1
	while used.has(kind + "_" + str(number)): number += 1
	var actor := _actor()
	var spawn: Array = actor.get("spawn", [128.0, 128.0])
	var extent: Array = wb.applied.get("extent", [2048, 2048]) if wb != null else [2048, 2048]
	var region := {"id":kind + "_" + str(number), "name":kind.capitalize() + " " + str(number),
		"kind":kind, "x":clampf(float(spawn[0]) - 48.0, 0.0, maxf(0.0, float(extent[0]) - 96.0)),
		"y":clampf(float(spawn[1]) - 48.0, 0.0, maxf(0.0, float(extent[1]) - 96.0)), "width":96.0, "height":96.0}
	_draft.regions.append(region)
	_region_selected = _draft.regions.size() - 1
	_show_places()
	_show_module()
	_validate_draft()
	return true


func remove_region() -> void:
	if not _living_enabled() or _region_selected < 0 or _region_selected >= _draft.regions.size(): return
	_draft.regions.remove_at(_region_selected)
	_region_selected = mini(_region_selected, _draft.regions.size() - 1)
	_show_places()
	_show_module()
	_validate_draft()


func _show_region_fields() -> void:
	if _region_fields == null: return
	_clear_body(_region_fields)
	if _region_selected < 0 or _region_selected >= _draft.get("regions", []).size():
		_note(_region_fields, "Select a place to edit its rectangle. The optional overlay shows authored places together with copied memory and intent.")
		return
	var region: Dictionary = _draft.regions[_region_selected]
	_text_parameter(region, "id", {"max_length":64, "description":"Stable place identifier used by region modules."}, _region_fields)
	_text_parameter(region, "name", {"max_length":80, "description":"Readable place label."}, _region_fields)
	for key: String in ["x", "y", "width", "height"]:
		_value_field(_region_fields, region, key, {"type":"number", "min":1 if key in ["width", "height"] else 0, "max":2048, "unit":"cells"}, "region_" + key)


func _region_parameter(module: Dictionary, key: String, spec: Dictionary) -> void:
	var row := _row(_parameter_body)
	_label(row, key.capitalize())
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("First applicable authored region")
	picker.set_item_metadata(0, "")
	var selected := 0
	var wanted := str(module.params.get(key, ""))
	for region: Dictionary in _draft.get("regions", []):
		picker.add_item("%s · %s" % [region.kind, region.name])
		picker.set_item_metadata(picker.item_count - 1, str(region.id))
		if str(region.id) == wanted: selected = picker.item_count - 1
	if not wanted.is_empty() and selected == 0:
		picker.add_item("Missing region: " + wanted)
		picker.set_item_metadata(picker.item_count - 1, wanted)
		selected = picker.item_count - 1
	picker.select(selected)
	picker.tooltip_text = str(spec.get("description", ""))
	row.add_child(picker)
	picker.item_selected.connect(func(index: int) -> void: module.params[key] = str(picker.get_item_metadata(index)); _validate_draft())
	_note(_parameter_body, str(spec.get("description", "Choose an authored region in Places and peers.")))


func _points_parameter(module: Dictionary, key: String, spec: Dictionary) -> void:
	_note(_parameter_body, str(spec.get("description", "Home-relative patrol waypoints, in native cells. Routes steer real actuators; they do not guarantee traversability.")))
	var points: Array = module.params.get(key, [])
	for index: int in points.size():
		var row := _row(_parameter_body)
		_label(row, "Waypoint %d" % (index + 1))
		for axis: int in 2:
			_label(row, "X" if axis == 0 else "Y")
			var field := SpinBox.new()
			field.min_value = -2048
			field.max_value = 2048
			field.step = 1
			field.custom_minimum_size.x = 110
			field.set_value_no_signal(float(points[index][axis]))
			row.add_child(field)
			field.value_changed.connect(func(value: float) -> void: points[index][axis] = value; _validate_draft())
		_button(row, "Remove", func() -> void: points.remove_at(index); _show_module(); _validate_draft())
	var add := _button(_parameter_body, "Add waypoint", func() -> void:
		if points.size() < 16:
			points.append([0.0, 0.0])
			module.params[key] = points
			_show_module()
			_validate_draft())
	add.disabled = points.size() >= 16


func _capture_group() -> Dictionary:
	var view := _session_view()
	var result := {"run_id":str(view.get("run_id", "")), "epoch":int(view.get("epoch", -1)), "actors":{}}
	if wb == null: return result
	for actor: Dictionary in wb.applied.get("actors", []):
		if not Actuator.supports(str(actor.model)): continue
		result.actors[str(int(actor.id))] = {"model":str(actor.model), "hash":str(actor.hash), "control":Catalog.control_for(actor).duplicate(true)}
	return result


func refresh_group() -> void:
	_group_expected = _capture_group()
	_library_baseline = wb.ambient_library() if wb != null and wb.has_method("ambient_library") else Authoring.blank()
	_show_library()


func _show_library() -> void:
	_clear_body(_library_body)
	_note(_library_body, "A shared scene library stores reusable authored profiles. Choosing an entry stages a copy. Assignment creates individual overrides; later library edits do not silently change any inhabitant. Save the Workbench scene to retain the library.")
	var row := _row(_library_body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_library_list = ItemList.new()
	_library_list.custom_minimum_size = Vector2(260, 100)
	left.add_child(_library_list)
	for profile: Dictionary in _library_baseline.get("profiles", []):
		_library_list.add_item(str(profile.name))
		_library_list.set_item_metadata(_library_list.item_count - 1, str(profile.id))
	_library_list.item_activated.connect(load_library_profile)
	var library_buttons := _row(left)
	_button(library_buttons, "Stage selected", func() -> void:
		var selected := _library_list.get_selected_items()
		if not selected.is_empty(): load_library_profile(selected[0]))
	_button(library_buttons, "Store this draft", store_library_profile)
	_button(left, "Remove selected library entry", remove_library_profile)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_label(right, "Group assignment · Ctrl/Shift for several")
	_group_list = ItemList.new()
	_group_list.select_mode = ItemList.SELECT_MULTI
	_group_list.custom_minimum_size = Vector2(260, 100)
	right.add_child(_group_list)
	for key: String in _group_expected.get("actors", {}):
		var snapshot: Dictionary = _group_expected.actors[key]
		_group_list.add_item("#%s · %s" % [key, snapshot.model])
		_group_list.set_item_metadata(_group_list.item_count - 1, int(key))
	_button(right, "Apply draft to selected group", apply_group_draft)
	_button(right, "Refresh group and library", refresh_group)
	_note(_library_body, "Group Apply validates every selected actor and its current control identity before changing any. Replaced actors, stale worlds or incompatible locomotion refuse the entire assignment. Per-actor Apply remains available below.")


func load_library_profile(index: int) -> bool:
	var profiles: Array = _library_baseline.get("profiles", [])
	if index < 0 or index >= profiles.size(): return false
	return replace_draft(profiles[index])


func store_library_profile() -> bool:
	if wb == null or not wb.has_method("set_ambient_library"): return false
	var error := Profile.validate(_draft)
	if not error.is_empty():
		_profile_status.text = "Library store refused: " + error
		return false
	var next: Dictionary = _library_baseline.duplicate(true)
	var replaced := false
	for index: int in next.profiles.size():
		if str(next.profiles[index].id) == str(_draft.id):
			next.profiles[index] = Profile.canonicalize(_draft)
			replaced = true
			break
	if not replaced:
		if next.profiles.size() >= Authoring.MAX_PROFILES:
			_profile_status.text = "Scene library capacity reached. Remove an unused profile or replace the same ID."
			return false
		next.profiles.append(Profile.canonicalize(_draft))
	if not wb.set_ambient_library(next, _library_baseline, _bound_run, _bound_epoch):
		_profile_status.text = "Library store refused: " + str(wb.message)
		return false
	_library_baseline = next.duplicate(true)
	_show_library()
	_profile_status.text = "Profile stored in the scene library. Existing actors retain their individual profiles. Save the scene to persist."
	return true


func remove_library_profile() -> bool:
	if _library_list == null or wb == null or not wb.has_method("set_ambient_library"): return false
	var selected := _library_list.get_selected_items()
	if selected.is_empty(): return false
	var next := _library_baseline.duplicate(true)
	next.profiles.remove_at(selected[0])
	if not wb.set_ambient_library(next, _library_baseline, _bound_run, _bound_epoch):
		_profile_status.text = "Library removal refused: " + str(wb.message)
		return false
	_library_baseline = next.duplicate(true)
	_show_library()
	_profile_status.text = "Library entry removed. Existing assigned profiles are retained."
	return true


func apply_group_draft() -> bool:
	if _group_list == null or wb == null or not wb.has_method("apply_ambient_group"): return false
	var ids: Array = []
	for index: int in _group_list.get_selected_items(): ids.append(int(_group_list.get_item_metadata(index)))
	if ids.is_empty():
		_profile_status.text = "Select one or more inhabitants in the group list first."
		return false
	if not wb.apply_ambient_group(ids, _draft.duplicate(true), _group_expected.duplicate(true)):
		_profile_status.text = "Group Apply refused: " + str(wb.message)
		return false
	_group_expected = _capture_group()
	if _instance_id in ids:
		_baseline_profile = Profile.canonicalize(_draft)
	_show_library()
	_profile_status.text = "Profile copied to %d acknowledged inhabitants. Each now has an independent editable override; save the scene to retain assignments." % ids.size()
	return true
