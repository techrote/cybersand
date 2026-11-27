extends VBoxContainer

# The Lab owns drafts and copied receipts. The Workbench controller owns the
# asynchronous native-owner boundary; this view never holds a native World.
const Profiles = preload("res://scripts/material_audition_profile.gd")
const Scenes = preload("res://scripts/workbench_material_audition_scenes.gd")
signal configuration_changed(state: Dictionary)
var active_state: Dictionary = {}
var draft_profile: Dictionary = Profiles.defaults()
var last_receipt: Dictionary = {}
var selected_id := 3
var _materials: Array = []
var _owner: WeakRef
var _draft_binding: Dictionary = {}
var _draft_revision := 0
var _previous_profile: Dictionary = {}
var _pending: Dictionary = {}
var _loading := false
var _elapsed := 0.0
var _controls: Dictionary = {}
var _capabilities: Dictionary = {}
var _title := Label.new()
var _identity := Label.new()
var _status := Label.new()
var _fields := VBoxContainer.new()
var _name := LineEdit.new()
var _description := LineEdit.new()
var _receipt := TextEdit.new()
var _file := FileDialog.new()
var _file_action := ""
var _demo := OptionButton.new()
var _demo_help := Label.new()
var _demo_confirm := ConfirmationDialog.new()
var _buttons: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation",8)
	_build()
	_refresh_fields()
	refresh_scene()

func _label(parent: Node, text: String, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	parent.add_child(label)
	return label

func _row(parent: Node) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",8)
	row.add_theme_constant_override("v_separation",5)
	parent.add_child(row)
	return row

func _button(parent: Node, caption: String, action: Callable, key: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	_buttons[key] = button
	return button

func _build() -> void:
	_title.add_theme_font_size_override("font_size",18)
	add_child(_title)
	_label(self,"Change admitted material behaviour in this Workbench's existing World. Inspect and isolated comparison remain available in the other tabs.")
	_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_identity)
	var actions := _row(self)
	_button(actions,"Apply draft",apply_draft,"apply")
	_button(actions,"Revert configuration",revert_configuration,"revert")
	_button(actions,"Reset to accepted defaults",reset_configuration,"reset")
	_button(actions,"Cancel pending apply",cancel_pending,"cancel")
	var drafts := _row(self)
	_button(drafts,"Use active as draft",use_active_as_draft,"use_active")
	_button(drafts,"Keep draft for current scene",rebase_draft,"rebase")
	_button(drafts,"Refresh active values",refresh_scene,"refresh")
	_label(self,"Revert and Reset change material configuration only. Cells already moved, reacted, burned or disappeared stay as they are. Neither action rewinds simulation or Paint history.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	add_child(HSeparator.new())
	_fields.add_theme_constant_override("separation",10)
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_fields)
	add_child(HSeparator.new())
	_label(self,"Named profiles",false).add_theme_font_size_override("font_size",16)
	_name.placeholder_text = "Name this material profile"
	_name.max_length = 96
	add_child(_name)
	_description.placeholder_text = "Optional description: what to watch or compare"
	_description.max_length = 2048
	add_child(_description)
	var files := _row(self)
	_button(files,"Save named profile…",func() -> void: _open_file(true),"save")
	_button(files,"Load named profile…",func() -> void: _open_file(false),"load")
	_label(self,"Profiles store configuration, material IDs and this runtime's identity. Loading prepares a draft; Apply activates it. Workbench scene saves do not retain this trial: save the named profile separately and reapply after reopening. A profile from a different runtime is refused.")
	var demos := _row(self)
	_label(demos,"Demonstration scene",false)
	_demo.fit_to_longest_item = false
	_demo.custom_minimum_size.x = 260
	for entry: Dictionary in Scenes.SCENES: _demo.add_item(str(entry.label))
	_demo.item_selected.connect(func(_index: int) -> void: _refresh_demo())
	demos.add_child(_demo)
	_button(demos,"Load demo…",_confirm_demo,"demo")
	_demo_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_demo_help)
	_refresh_demo()
	var details := CheckButton.new()
	details.text = "Show last native transaction receipt"
	add_child(details)
	_receipt.editable = false
	_receipt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_receipt.custom_minimum_size.y = 180
	_receipt.add_theme_color_override("font_readonly_color",Color(0.86,0.89,0.93))
	add_child(_receipt)
	_receipt.hide()
	details.toggled.connect(func(shown: bool) -> void: _receipt.visible = shown)
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.filters = PackedStringArray(["*.json ; Material audition profile"])
	_file.file_selected.connect(_file_selected)
	add_child(_file)
	_demo_confirm.title = "Replace the current scene with a demonstration?"
	_demo_confirm.dialog_autowrap = true
	_demo_confirm.confirmed.connect(_load_demo)
	add_child(_demo_confirm)

func bind_current_scene(owner: Object) -> void:
	_owner = weakref(owner) if owner != null else null
	if is_node_ready(): refresh_scene()

func set_catalogue(materials: Array) -> void:
	_materials = materials.duplicate(true)
	if is_node_ready(): _refresh_fields()

func select_material(id: int) -> bool:
	if is_node_ready() and not _commit_fields(): return false
	selected_id = id
	if is_node_ready(): _refresh_fields()
	return true

func _host() -> Object:
	return _owner.get_ref() if _owner != null else null

func _binding(state: Dictionary) -> Dictionary:
	return {"session_id":str(state.get("session_id","")),"world_id":str(state.get("world_id","")),"expected_revision":int(state.get("revision",-1))}

func _same_world(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("session_id","")) == str(b.get("session_id","")) and str(a.get("world_id","")) == str(b.get("world_id",""))

func _available() -> bool:
	return active_state.get("ok",false) and not str(active_state.get("world_id","")).is_empty() and active_state.get("profile") is Dictionary and active_state.get("capabilities") is Array

func refresh_scene() -> void:
	var owner := _host()
	if owner == null or not owner.has_method("material_audition_state"):
		active_state = {"ok":false,"error":"Open Materials Lab from an ordinary Workbench scene to audition changes. This standalone Lab keeps its isolated experiments."}
		_refresh_fields()
		_set_status(str(active_state.error))
		return
	var result: Variant = owner.call("material_audition_state")
	if not result is Dictionary:
		_set_status("The Workbench returned no material configuration readback; Apply is unavailable.")
		active_state = {"ok":false}
		_refresh_buttons()
		return
	_accept_state(result)

func _accept_state(state: Dictionary) -> void:
	var before := active_state
	var changed: bool = before.get("capabilities",[]) != state.get("capabilities",[]) or _binding(before) != _binding(state) or bool(before.get("ok",false)) != bool(state.get("ok",false))
	active_state = state.duplicate(true)
	if _available() and _draft_binding.is_empty():
		draft_profile = active_state.profile.duplicate(true)
		_draft_binding = _binding(active_state)
		_set_status("Native configuration readback is ready. Review Active and Draft, then Apply deliberately.")
	elif _available() and not _same_world(_draft_binding,active_state):
		_previous_profile.clear()
		_set_status("The Workbench World changed. Your previous draft is retained for inspection. Choose Use active as draft, or explicitly Keep draft for current scene before applying.")
	elif _available() and not before.get("ok",false) and _pending.is_empty():
		_set_status("Native configuration readback restored. Review Active and Draft; adopt or rebase the draft if its revision changed.")
	elif not _available():
		_set_status(str(state.get("error","Current-scene material audition is unavailable.")))
	if changed: _refresh_fields()
	else: _refresh_buttons()

func use_active_as_draft() -> void:
	if not _available() or not _pending.is_empty(): return
	draft_profile = active_state.profile.duplicate(true)
	_discard_pending_text()
	_draft_binding = _binding(active_state)
	_draft_revision += 1
	_refresh_fields()
	_set_status("The current native configuration is now your draft. No simulation state changed.")

func rebase_draft() -> void:
	if not _available() or not _pending.is_empty() or not _commit_fields(): return
	var checked := Profiles.validate_profile(draft_profile,active_state)
	if not checked.get("ok",false):
		_set_status(str(checked.error))
		return
	draft_profile = checked.profile
	_draft_binding = _binding(active_state)
	_draft_revision += 1
	_refresh_buttons()
	_set_status("Draft retained against the current World and configuration revision. Review Active versus Draft, then Apply deliberately.")

func _material_name(id: int) -> String:
	return str(_materials[id].get("name","Material %d" % id)) if id >= 0 and id < _materials.size() else "Material %d" % id

func _selected_rows() -> Array:
	var rows: Array = []
	for row: Variant in active_state.get("capabilities",[]):
		if not row is Dictionary: continue
		if row.get("kind") == "material" and int(row.get("material_id",-1)) == selected_id:
			rows.append(row)
		elif row.get("kind") == "reaction" and selected_id in [int(row.get("first",-1)),int(row.get("second",-1))]:
			rows.append(row)
	return rows

func _refresh_fields() -> void:
	if not is_node_ready(): return
	# Pending text is a draft even before the field loses focus. Read it before
	# rebuilding an active readback so an asynchronous receipt cannot erase it.
	var typed: Dictionary = {}
	for key: String in _controls:
		var field: SpinBox = _controls[key]
		if field.get_meta("audition_pending_text",false): typed[key] = field.get_line_edit().text
	for child: Node in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	_controls.clear()
	_capabilities.clear()
	_title.text = "%03d / %s · current-scene audition" % [selected_id,_material_name(selected_id)]
	if not _available():
		_identity.text = "Current scene: unavailable"
		_label(_fields,"Current native material readback is unavailable. Inspect, Edit copy and isolated tests remain available.")
		_refresh_buttons()
		return
	_identity.text = "Active profile: %s · revision %d · World %s" % [str(active_state.profile.get("profile_id","accepted-defaults")),int(active_state.get("revision",0)),str(active_state.get("world_id",""))]
	_identity.tooltip_text = "Host session: %s\nRuntime: %s\nCompatibility: %s" % [str(active_state.get("session_id","")),str(active_state.get("source_identity","unobserved")),str(active_state.get("native_compatibility","unobserved"))]
	var rows := _selected_rows()
	if rows.is_empty(): _label(_fields,"This material has no admitted current-scene properties or sparse reaction slots. Inspect lists its compiled consumers and isolated authoring options.")
	_loading = true
	for row: Dictionary in rows:
		var key := Profiles.capability_key(row)
		_capabilities[key] = row.duplicate(true)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation",3)
		_fields.add_child(box)
		var property := str(row.get("property",""))
		var reaction: bool = row.get("kind") == "reaction"
		var caption := "Reaction %d: %s + %s" % [int(row.get("slot",-1)),_material_name(int(row.get("first",-1))),_material_name(int(row.get("second",-1)))] if reaction else property.replace("_"," ").capitalize()
		var classification := str(row.get("change_class","unsupported"))
		var labels := {"live":"Live · existing World","paused":"Pause required","isolated":"Isolated comparison only","restart":"Rebuild or restart required","unsupported":"Unsupported in current scene","metadata":"Descriptive only"}
		_label(box,caption + " — " + str(labels.get(classification,classification))).add_theme_font_size_override("font_size",14)
		var values := _row(box)
		_label(values,"Declared: %s" % str(row.get("declared","—")),false)
		_label(values,"Active: %s" % str(row.get("effective","unobserved")),false)
		if classification == "live":
			_label(values,"Draft",false)
			var field := SpinBox.new()
			field.min_value = int(row.get("minimum",0))
			field.max_value = int(row.get("maximum",0))
			field.step = 1
			field.custom_minimum_size.x = 110
			field.value = Profiles.value_for(draft_profile,row)
			field.value_changed.connect(func(value: float) -> void:
				field.set_meta("audition_pending_text",false)
				_field_changed(key,int(value)))
			field.get_line_edit().text_changed.connect(func(_text: String) -> void:
				if not _loading:
					field.set_meta("audition_pending_text",true)
					_draft_revision += 1
					_set_status("Draft edited. Apply will submit one complete validated configuration."))
			values.add_child(field)
			_controls[key] = field
			if typed.has(key):
				field.get_line_edit().text = typed[key]
				field.set_meta("audition_pending_text",true)
			_label(values,"Range %d–%d" % [int(row.get("minimum",0)),int(row.get("maximum",0))],false)
		else:
			_label(values,"No live control",false)
		var explanation := str(row.get("applicability",""))
		if property == "viscosity" and classification == "live":
			explanation += " This controls generic sideways yielding. Existing activity cooling may let material rest after a missed movement gate; a changed configuration, contact or edit can wake it. Gravity and the separate liquid solver families keep their existing rules."
		if reaction:
			explanation += " Threshold T means (T + 1) / 256: 0 is 1/256, not disabled. Endpoint roles and products remain unchanged. This readback describes the admitted rule, not a witnessed contact or executed reaction."
		_label(box,explanation)
		if reaction and row.has("first_product") and row.has("second_product"):
			var matches := ["Ordered", "Unordered, roles preserved", "Symmetric"]
			var matching: int = int(row.get("match",-1))
			_label(box,"Authored roles: %s → %s; %s → %s. Match: %s. Active probability: %d/256." % [
				_material_name(int(row.first)),_material_name(int(row.first_product)),
				_material_name(int(row.second)),_material_name(int(row.second_product)),
				matches[matching] if matching >= 0 and matching < matches.size() else "unobserved",int(row.get("effective",-1))+1])
			_label(box,"Effects: " + str(row.get("effects","Canonical native product initialization; inspect an isolated contact for stored-state detail.")))
		var consumer := _label(box,"Consumer: " + str(row.get("consumer","unobserved")))
		consumer.add_theme_color_override("font_color",Color(0.62,0.72,0.82))
	_loading = false
	_refresh_buttons()

func _field_changed(key: String, value: int) -> void:
	if _loading or not _capabilities.has(key): return
	# A typed value can reach the draft during Apply before SpinBox emits its
	# focus-loss notification. That notification is not a newer user edit.
	if Profiles.value_for(draft_profile,_capabilities[key]) == value: return
	draft_profile = Profiles.set_value(draft_profile,_capabilities[key],value)
	draft_profile.profile_id = "trial-%d" % Time.get_ticks_usec()
	_draft_revision += 1
	_set_status("Draft edited. Apply will submit one complete validated configuration.")

func _discard_pending_text() -> void:
	for field: SpinBox in _controls.values(): field.set_meta("audition_pending_text",false)

func _commit_fields() -> bool:
	for key: String in _controls:
		var field: SpinBox = _controls[key]
		var text: String = field.get_line_edit().text.strip_edges() if field.get_meta("audition_pending_text",false) else str(int(field.value))
		if not text.is_valid_int():
			_set_status("Draft value must be a whole number: " + text)
			return false
		var value := text.to_int()
		var row: Dictionary = _capabilities[key]
		if value < int(row.minimum) or value > int(row.maximum):
			_set_status("%s must be between %d and %d; no configuration was submitted." % [str(row.property),int(row.minimum),int(row.maximum)])
			return false
		if Profiles.value_for(draft_profile,row) != value: _field_changed(key,value)
		field.set_value_no_signal(value)
		field.set_meta("audition_pending_text",false)
	return true

func _refresh_buttons() -> void:
	if _buttons.is_empty(): return
	var available := _available()
	var pending := not _pending.is_empty()
	var bound := _same_world(_draft_binding,active_state) and int(_draft_binding.get("expected_revision",-1)) == int(active_state.get("revision",-2))
	_buttons.apply.disabled = not available or pending or not bound
	_buttons.revert.disabled = not available or pending or _previous_profile.is_empty()
	_buttons.reset.disabled = not available or pending
	_buttons.cancel.disabled = not pending
	_buttons.use_active.disabled = not available or pending
	_buttons.rebase.disabled = not available or pending or bound
	_buttons.refresh.disabled = _host() == null
	_buttons.save.disabled = not available
	_buttons.load.disabled = not available or pending
	var owner := _host()
	_buttons.demo.disabled = owner == null or not owner.has_method("request_material_audition_demo") or pending

func _set_status(message: String) -> void:
	_status.text = message
	_refresh_buttons()

func apply_draft() -> Dictionary:
	if not _commit_fields(): return {"ok":false,"error":_status.text}
	if not _same_world(_draft_binding,active_state) or int(_draft_binding.get("expected_revision",-1)) != int(active_state.get("revision",-2)):
		_set_status("Draft is bound to an older World or configuration revision. Refresh and explicitly keep the draft for the current scene, or use the current active configuration.")
		return {"ok":false,"error":_status.text}
	return _submit(draft_profile,"apply")

func revert_configuration() -> Dictionary:
	if _previous_profile.is_empty(): return {"ok":false,"error":"No previous configuration in this World is available."}
	return _submit(_previous_profile,"revert")

func reset_configuration() -> Dictionary:
	return _submit(Profiles.defaults(),"reset")

func _submit(profile: Dictionary, action: String) -> Dictionary:
	if not _available() or not _pending.is_empty(): return {"ok":false,"error":"The current native owner is unavailable or already applying a configuration."}
	var checked := Profiles.validate_profile(profile,active_state)
	if not checked.get("ok",false):
		_set_status(str(checked.error))
		return checked
	var owner := _host()
	if owner == null or not owner.has_method("request_material_audition"):
		_set_status("Current-scene application is unavailable in this runtime.")
		return {"ok":false,"error":_status.text}
	var request := _binding(active_state)
	request.profile = checked.profile.duplicate(true)
	_pending = {"request":request.duplicate(true),"previous":active_state.profile.duplicate(true),"draft_revision":_draft_revision,"action":action,"request_id":""}
	var result: Variant = owner.call("request_material_audition",request)
	if not result is Dictionary:
		_pending.clear()
		_set_status("The owner returned no admission receipt; no activation is claimed.")
		return {"ok":false,"error":_status.text}
	_pending.request_id = str(result.get("request_id",""))
	if result.get("status") == "pending" or result.get("pending",false):
		if str(_pending.request_id).is_empty():
			_pending.clear()
			_set_status("Pending application has no request identity; refresh native state before retrying.")
			return {"ok":false,"error":_status.text}
		_set_status("Applying at the native owner boundary… Your World continues; intermediate slider values are not submitted.")
	else:
		_complete(result)
	return result

func _complete(result: Dictionary) -> void:
	if _pending.is_empty(): return
	_commit_fields()
	var submitted := _pending.duplicate(true)
	if not str(submitted.request_id).is_empty() and str(result.get("request_id","")) != str(submitted.request_id):
		_set_status("An unrelated transaction receipt was ignored; the submitted request remains pending.")
		return
	last_receipt = result.duplicate(true)
	_receipt.text = JSON.stringify(last_receipt,"\t")
	_pending.clear()
	# Native commit and receipt encoding are separate operations. A bridge may
	# acknowledge activation even if it could not allocate the effective readback.
	# Never describe that outcome as a refused or cancelled configuration.
	var readback_failed: bool = not result.get("ok",false) and (bool(result.get("accepted",false)) or result.get("status") == "active_readback_failed")
	if not result.get("ok",false) and not readback_failed:
		var detail := str(result.get("error",result.get("message",result.get("status","No native activation acknowledged."))))
		if result.get("status") in ["retired","unavailable"] or result.get("code") in ["unknown_request","host_retired"]:
			_previous_profile.clear()
			refresh_scene()
			_set_status("Transaction outcome unavailable: " + detail + " Active values must be checked before another change; no configuration reversal is claimed.")
		else:
			_set_status("Configuration refused: " + detail)
			refresh_scene()
		return
	var state: Dictionary = result.get("state",result).duplicate(true)
	var activated_revision: int = int(submitted.request.expected_revision)+1
	var receipt_matches: bool = (not result.has("world_id") or str(result.world_id) == str(submitted.request.world_id)) and (not result.has("session_id") or str(result.session_id) == str(submitted.request.session_id)) and (not result.has("revision") or int(result.revision) == activated_revision)
	if readback_failed:
		refresh_scene()
		state = active_state.duplicate(true)
	if not receipt_matches or not state.get("ok",false) or not state.get("capabilities") is Array or not _same_world(submitted.request,state) or int(state.get("revision",-1)) != activated_revision or not state.get("profile") is Dictionary or state.profile != submitted.request.profile:
		_previous_profile.clear()
		if readback_failed:
			var message := "Configuration activated, but native readback failed. Refresh active values before another change. Simulation consequences remain in the current World."
			if _available() and (not _same_world(submitted.request,state) or int(state.revision) > activated_revision):
				message = "Earlier activation acknowledged. Native readback failed for that transaction; a newer World or revision is now authoritative. Your draft was retained and old Revert history retired. Review Active versus Draft before another Apply."
			# A stale pre-commit cache is not current effective-value evidence.
			if _same_world(submitted.request,state) and int(state.get("revision",-1)) <= int(submitted.request.expected_revision):
				active_state = {"ok":false,"error":message}
				_refresh_fields()
			_set_status(message)
		else:
			_set_status("Native activation receipt does not match the submitted World, revision and profile. Refresh active values; no successful application is claimed.")
			refresh_scene()
		return
	# A native receipt records an activation, not necessarily the current owner.
	# The cached owner read is cheap and also covers retirement/replacement before
	# the panel had an opportunity to refresh. Never resurrect a retired World,
	# publish an older revision, or infer current values from a historical receipt.
	if not readback_failed: refresh_scene()
	var current_matches: bool = _available() and _same_world(active_state,state) and int(active_state.revision) == int(state.revision) and active_state.profile == state.profile
	if not current_matches:
		_previous_profile.clear()
		var newer_available: bool = _available() and (not _same_world(active_state,state) or int(active_state.revision) > int(state.revision))
		if _available() and not newer_available:
			active_state = {"ok":false,"error":"Native activation was acknowledged, but current effective values could not be confirmed."}
			_refresh_fields()
		var authority := "A newer World or revision is now authoritative." if newer_available else "The current native owner readback is unavailable."
		_set_status("Earlier activation acknowledged. %s The draft was retained and old Revert history retired. Review Active versus Draft before another Apply." % authority)
		return
	_previous_profile = submitted.previous.duplicate(true)
	# Preserve edits made while native admission was pending. They become a
	# new draft against the acknowledged revision, never the active receipt.
	if _draft_revision == int(submitted.draft_revision): draft_profile = state.profile.duplicate(true)
	_draft_binding = _binding(state)
	_accept_state(state)
	# refresh_scene() may already have published this binding before the restored
	# profile became the draft. Keep the numeric controls consistent with adoption.
	_refresh_fields()
	configuration_changed.emit(active_state.duplicate(true))
	var recovery := "The initial readback failed; refreshed native values confirm activation. " if readback_failed else ""
	_set_status("Configuration activated at revision %d. %s%s Simulation consequences remain in the current World." % [int(state.revision),recovery,"Your newer draft is still unapplied." if _draft_revision != int(submitted.draft_revision) else "You may continue editing or revert the configuration."])

func cancel_pending() -> Dictionary:
	var owner := _host()
	if _pending.is_empty() or owner == null or not owner.has_method("cancel_material_audition"):
		return {"ok":false,"error":"No cancellable material transaction is pending."}
	var result: Variant = owner.call("cancel_material_audition",str(_pending.request_id))
	if not result is Dictionary: return {"ok":false,"error":"Cancellation has no owner receipt."}
	if result.get("status") in ["pending","cancel_requested"]:
		_set_status("Cancellation requested; waiting for the native owner's terminal receipt.")
	else: _complete(result)
	return result

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < (0.08 if not _pending.is_empty() else 0.5): return
	_elapsed = 0.0
	var owner := _host()
	if not _pending.is_empty() and owner == null:
		_complete({"ok":false,"status":"retired","request_id":str(_pending.request_id),"error":"The material audition host retired; no activation is claimed."})
	elif not _pending.is_empty() and owner != null and owner.has_method("poll_material_audition"):
		var result: Variant = owner.call("poll_material_audition",str(_pending.request_id))
		if result is Dictionary and not result.is_empty() and result.get("status") != "pending" and not result.get("pending",false): _complete(result)
	elif is_visible_in_tree() and owner != null:
		refresh_scene()

func save_profile(path: String) -> Dictionary:
	if not _commit_fields(): return {"ok":false,"error":_status.text}
	var result := Profiles.save(path,draft_profile,active_state,_name.text,_description.text)
	_set_status("Named draft profile saved. Saving does not activate it or save simulation state." if result.get("ok",false) else str(result.error))
	return result

func load_profile(path: String) -> Dictionary:
	if not _pending.is_empty(): return {"ok":false,"error":"Finish or cancel the pending transaction before loading a profile."}
	var result := Profiles.load_file(path,active_state)
	if not result.get("ok",false):
		_set_status(str(result.error))
		return result
	draft_profile = result.profile.duplicate(true)
	_discard_pending_text()
	_name.text = str(result.name)
	_description.text = str(result.description)
	_draft_binding = _binding(active_state)
	_draft_revision += 1
	_refresh_fields()
	_set_status("Named profile loaded as a draft. Review the values, then Apply to change this World.")
	return result

func _open_file(saving: bool) -> void:
	_file_action = "save" if saving else "load"
	_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	_file.title = "Save named material profile" if saving else "Load material profile as draft"
	DirAccess.make_dir_recursive_absolute("user://materials_lab/profiles")
	_file.current_dir = ProjectSettings.globalize_path("user://materials_lab/profiles")
	_file.current_file = "material-audition-profile.json" if saving else ""
	_file.popup_centered_ratio(0.7)

func _file_selected(path: String) -> void:
	if _file_action == "save": save_profile(path)
	else: load_profile(path)

func _refresh_demo() -> void:
	if _demo.selected < 0: return
	_demo_help.text = str(Scenes.SCENES[_demo.selected].help)

func _confirm_demo() -> void:
	if _demo.selected < 0: return
	_demo_confirm.dialog_text = "Load %s?\n\nThis is an explicit scene replacement. Save your authored scene and named material profile first if you want to keep them. The new scene starts with accepted material defaults; it does not rewind your current simulation." % str(Scenes.SCENES[_demo.selected].label)
	_demo_confirm.popup_centered(Vector2i(560,240))

func _load_demo() -> void:
	var owner := _host()
	if owner == null or not owner.has_method("request_material_audition_demo") or _demo.selected < 0: return
	var result: Variant = owner.call("request_material_audition_demo",str(Scenes.SCENES[_demo.selected].id))
	if result is Dictionary:
		_set_status("Demonstration scene replacement requested. Wait for the Workbench acknowledgement, then use its active configuration as your draft." if result.get("ok",false) else str(result.get("error","Demonstration scene was refused.")))
