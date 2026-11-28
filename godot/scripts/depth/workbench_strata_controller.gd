extends Node

## The ordinary Workbench join. It borrows the existing play host and owns only
## three static decorative native Worlds plus their copied presentation data.
const Document = preload("res://scripts/depth/workbench_layer_document.gd")
const Owner = preload("res://scripts/depth/workbench_layer_owner.gd")
const Presentation = preload("res://scripts/depth/workbench_strata_presentation.gd")
const LayerPanel = preload("res://scripts/depth/workbench_strata_panel.gd")
const Scenes = preload("res://scripts/depth/workbench_strata_scenes.gd")
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Atmosphere = preload("res://scripts/depth/strata_atmosphere_profiles.gd")
const Authoring = preload("res://scripts/depth/workbench_strata_authoring.gd")
const Optics = preload("res://scripts/depth/strata_optics_configuration.gd")
const OpticalProfiles = preload("res://scripts/depth/strata_optical_profiles.gd")
const OpticalPresets = preload("res://scripts/depth/strata_optics_presets.gd")
const OpticalShowcases = preload("res://scripts/depth/strata_optical_showcase_scenes.gd")
const OpticalFixtures = preload("res://scripts/depth/strata_optics_fixtures.gd")
const MAX_EDIT_CELLS := 16384
const MAX_STROKE_POINTS := 1024
const NONPLAY := ["scripted", "effects", "background"]

var wb: Control
var layer_owner: RefCounted = Owner.new()
var presenter: Control
var _document: Dictionary = {}
var _pending: Dictionary = {}
var _sources: Dictionary = {}
var _history_state: Dictionary = {}
var _publication_errors: Dictionary = {}
var last_edit_receipt: Dictionary = {}
var _layer_ready := false
var _apply_serial := 0
var _keep_on_apply := false
var _demo_overview := false
var _window: Window
var _panel: Control
var _indicator: Label
var _overlay: Control
var _status := "Strata is off. The ordinary play World remains authoritative."
var _gesture: Dictionary = {}
var selection := Rect2i()
var cursor := Vector2i(-1,-1)
var clipboard: Dictionary = {}
var _closed := false
var _authoring: RefCounted
var _optics_inspection := Optics.inspection_defaults()
var _optics_quality := "balanced"
var _optics_preferences_loaded := false
var _optics_catalogue: Dictionary = {}
var _optics_catalogue_error := ""


func mount(workbench: Control) -> void:
	wb = workbench
	_document = Document.default_document(Setup.extent_of(wb.applied)) if not wb.applied.is_empty() else {}
	_indicator = Label.new()
	_indicator.name = "StrataEditTarget"
	_indicator.add_theme_color_override("font_color",Color(1.0,0.77,0.36))
	_indicator.hide()
	wb.paint_editor.add_child(_indicator)
	_overlay = preload("res://scripts/depth/workbench_strata_edit_overlay.gd").new()
	_overlay.name = "StrataEditOverlay"
	_overlay.set_meta("strata_independent_overlay",true)
	_overlay.controller = self
	wb.host.world_view.add_child(_overlay)
	set_process(false)


func document() -> Dictionary:
	return _document.duplicate(true)


func has_document() -> bool:
	return _layer_ready


func active_layer() -> String:
	return str(_document.get("presentation",{}).get("active","play")) if enabled() else "play"


func enabled() -> bool:
	return bool(_document.get("presentation",{}).get("enabled",false)) and is_instance_valid(presenter)


func status_text() -> String:
	return _status


func _say(text: String) -> bool:
	_status = text
	if is_instance_valid(wb): wb.message = text
	_refresh_panel()
	return true


func _refuse(text: String) -> bool:
	_say("Strata refused · " + text)
	return false


func _host_admits_strata() -> bool:
	# Persistent profiles serialize one continued Play World and an exact
	# authoring envelope. Decorative Worlds and CYSSTRAT settings have no
	# admitted continuation codec there, even while layered presentation is off.
	if is_instance_valid(wb) and is_instance_valid(wb.host) and wb.host.has_method(&"persistent_operation_allowed"):
		var reason: String = wb.host.call(&"persistent_operation_allowed", "strata", {})
		if not reason.is_empty():
			return _refuse("Strata Theatre requires the ordinary Workbench. Leave the persistent-area profile through Launcher first.")
	return true


func open_panel() -> void:
	if not _host_admits_strata(): return
	if wb.applied.is_empty():
		_refuse("Wait for the ordinary Workbench to finish installing its canvas.")
		return
	if _document.is_empty(): _document = Document.default_document(Setup.extent_of(wb.applied))
	if not is_instance_valid(_window):
		_window = Window.new()
		_window.title = "Strata Theatre · four-plane composition"
		_window.min_size = Vector2i(560,420)
		_window.hide()
		_window.transient = true
		add_child(_window)
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_window.add_child(scroll)
		_panel = LayerPanel.new()
		_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(_panel)
		_panel.mount(self)
		_window.close_requested.connect(_window.hide)
	_refresh_panel()
	_window.popup_centered_clamped(Vector2i(980,760),0.9)


func _refresh_panel() -> void:
	_history_state = layer_owner.stats().get("layers",{}) if _layer_ready else {}
	if is_instance_valid(_panel): _panel.refresh(_document,_status)
	if is_instance_valid(_indicator):
		_indicator.visible = enabled()
		var layer := active_layer()
		var row := Document.plane(_document,layer)
		_indicator.text = "EDIT: %s%s · %s" % [layer.to_upper(),
			" [LOCKED / HIDDEN]" if enabled() and (bool(row.get("locked",false)) or not presenter.effective_visible(layer)) else "",
			"play physics" if layer == "play" else "static decoration"]
	if wb != null and wb.paint_editor != null and wb.paint_editor._overlay != null:
		wb.paint_editor._overlay.visible = not enabled() or active_layer() == "play"


func _prepare(doc: Dictionary) -> bool:
	if not _host_admits_strata(): return false
	if authoring_busy(): return _refuse("Finish or stop the native authoring prefix before replacing its scene.")
	if not _pending.is_empty() or _apply_serial > 0: return _refuse("A scene replacement is already preparing.")
	var error := Document.validate(doc)
	if not error.is_empty(): return _refuse(error)
	var admitted: Dictionary = layer_owner.prepare(doc,layer_owner.generation())
	if not admitted.get("ok",false): return _refuse(str(admitted.get("error","Native decorative candidate refused.")))
	var token := int(admitted.token)
	var candidate: Control = Presentation.new()
	if not candidate.prepare(Document.extent_of(doc)):
		layer_owner.cancel(token)
		candidate.free()
		return _refuse("The complete decorative presentation could not be prepared.")
	# All copied packets and textures must be admitted before requesting a play
	# World replacement. Adoption below performs no native construction.
	var packets: Dictionary = layer_owner.prepared_packets(token)
	var sources := {}
	for id: String in NONPLAY:
		if not packets.has(id):
			layer_owner.cancel(token)
			candidate.free()
			return _refuse("The candidate is missing its " + id + " publication.")
		var packet: Dictionary = packets[id]
		sources[id] = {"owner_id":packet.get("owner_id",-1),"reset_generation":packet.get("reset_generation",-1),
			"revision":packet.get("revision",-1)}
	if not candidate.expect_sources(sources) or not candidate.apply_document(doc):
		layer_owner.cancel(token)
		candidate.free()
		return _refuse("Candidate presentation identity or settings were refused.")
	for id: String in NONPLAY:
		if not candidate.apply_layer_packet(id,packets[id]):
			layer_owner.cancel(token)
			candidate.free()
			return _refuse("Candidate " + id + " publication was refused before changing the play World.")
	if not candidate.prepare_host(wb.host):
		layer_owner.cancel(token)
		candidate.free()
		return _refuse("The borrowed play drawable could not be prepared; the active scene is unchanged.")
	_pending = {"token":token,"presenter":candidate,"document":doc.duplicate(true),"sources":sources}
	return true


func _adopt() -> bool:
	if _pending.is_empty(): return false
	var candidate: Control = _pending.presenter
	var previous: Control = presenter
	if is_instance_valid(previous): previous.detach()
	if not candidate.mount(wb.host):
		if is_instance_valid(previous): previous.mount(wb.host)
		cancel_candidate()
		return _refuse("The play presentation owner changed after preparation; layered adoption was not completed.")
	if not layer_owner.commit(int(_pending.token)):
		candidate.detach()
		if is_instance_valid(previous): previous.mount(wb.host)
		cancel_candidate()
		return _refuse("Prepared layer ownership changed before adoption.")
	if is_instance_valid(previous): previous.free()
	presenter = candidate
	_document = layer_owner.document()
	_sources = _pending.sources.duplicate(true)
	_publication_errors.clear()
	_layer_ready = true
	_pending = {}
	presenter.apply_document(_document)
	if _optics_preferences_loaded: presenter.set_optics_quality(_optics_quality)
	# Comparison and temporary focus never leak from a replaced scene.
	_optics_inspection = Optics.inspection_defaults()
	presenter.set_optics_inspection(_optics_inspection)
	presenter.sync_view()
	cancel_gesture()
	selection = Rect2i()
	clipboard.clear()
	set_process(enabled() or authoring_busy())
	_refresh_panel()
	return true


func cancel_candidate() -> void:
	if _pending.is_empty(): return
	layer_owner.cancel(int(_pending.token))
	var candidate: Control = _pending.presenter
	if is_instance_valid(candidate): candidate.free()
	_pending.clear()


func _ensure_current() -> bool:
	if not _host_admits_strata(): return false
	if has_document(): return true
	if wb.applied.is_empty() or wb.busy(): return _refuse("Wait for the ordinary Workbench owner.")
	if _document.is_empty(): _document = Document.default_document(Setup.extent_of(wb.applied))
	if not _prepare(_document): return false
	return _adopt()


func set_presentation(patch: Dictionary) -> bool:
	if wb.busy() or not _pending.is_empty(): return _refuse("Finish the current edit or scene replacement first.")
	if not _ensure_current(): return false
	cancel_gesture()
	wb.paint_editor.cancel_preview()
	if not layer_owner.set_presentation(patch): return _refuse("Unsupported presentation settings; the previous view is retained.")
	if patch.has("active") and str(patch.active) != str(_document.presentation.active): selection = Rect2i()
	_document = layer_owner.document()
	presenter.apply_document(_document)
	presenter.sync_view()
	set_process(enabled() or authoring_busy())
	return _say("Editing %s · %s. Presentation changes preserve the live play World and actors." % [active_layer(),
		"ordinary flat play" if not enabled() else ("active-plane inspection" if _document.presentation.mode == "flat" else "four-plane stack")])


func set_enabled(value: bool) -> bool:
	return set_presentation({"enabled":value})


func set_mode(value: String) -> bool:
	return set_presentation({"mode":value})


func select_layer(id: String) -> bool:
	return set_presentation({"active":id})


func set_layer_settings(id: String, patch: Dictionary) -> bool:
	if wb.busy() or not _pending.is_empty(): return _refuse("Finish the current edit or scene replacement first.")
	if not _ensure_current(): return false
	cancel_gesture()
	wb.paint_editor.cancel_preview()
	if not layer_owner.update_settings(id,patch): return _refuse("Unsupported layer settings; the previous scene is retained.")
	_document = layer_owner.document()
	presenter.apply_document(_document)
	presenter.sync_view()
	return _say("%s settings updated. Decorative planes have no actor or collision authority." % id.capitalize())


func set_layer_option(id: String, key: String, value: Variant) -> bool:
	return set_layer_settings(id,{key:value})


func reset_presentation() -> bool:
	if not _ensure_current(): return false
	if wb.busy(): return _refuse("Finish the current edit first.")
	var defaults := Document.default_document(Document.extent_of(_document))
	var view: Dictionary = defaults.presentation.duplicate(true)
	view.enabled = enabled()
	if not layer_owner.set_presentation(view): return false
	for row: Dictionary in defaults.planes:
		if not layer_owner.update_settings(row.id,{"visible":true,"locked":false,"opacity":row.opacity,"depth":row.depth}): return false
	_document = layer_owner.document()
	presenter.apply_document(_document)
	presenter.sync_view()
	cancel_gesture()
	return _say("Presentation settings restored. Material layouts, edit histories and the play World are unchanged.")


func play_apply_submitted(serial: int, keep: bool) -> void:
	_apply_serial = serial
	_keep_on_apply = keep
	cancel_gesture()


func play_installed() -> void:
	if not _pending.is_empty():
		_adopt()
	elif not _keep_on_apply:
		_clear_scene()
	_apply_serial = 0
	_keep_on_apply = false
	if _document.is_empty() and not wb.applied.is_empty(): _document = Document.default_document(Setup.extent_of(wb.applied))
	if _demo_overview:
		_demo_overview = false
		_show_overview.call_deferred()
	_refresh_panel()


func _show_overview() -> void:
	if not is_instance_valid(wb) or wb.applied.is_empty(): return
	wb._camera.select(2)
	wb.set_camera(2)


func play_apply_failed() -> void:
	cancel_candidate()
	_apply_serial = 0
	_keep_on_apply = false
	_demo_overview = false
	_say("Scene replacement refused; the previous valid play and decorative composition are retained.")


func load_document(record: Dictionary) -> bool:
	if not _host_admits_strata(): return false
	if wb.busy(): return _refuse("Finish the current Workbench transaction first.")
	if not record.has_all(["setup","document"]): return _refuse("Incomplete layered document.")
	var error := Document.validate(record.document)
	if not error.is_empty(): return _refuse(error)
	error = Setup.validate(record.setup)
	if not error.is_empty(): return _refuse(error)
	if Setup.extent_of(record.setup) != Document.extent_of(record.document): return _refuse("Play and layer extents differ.")
	if not _prepare(record.document): return false
	if not wb.apply(record.setup,false,0,false,false,record.get("generated",{}),record.get("baseline",{})):
		cancel_candidate()
		return false
	return _say("Preparing complete layered authored start… the current scene remains live until native admission.")


func load_demo(id: String) -> bool:
	if not _host_admits_strata(): return false
	if wb.busy(): return _refuse("Finish the current Workbench transaction first.")
	var policy := PackedInt32Array(wb.applied.liquid_policy)
	var scene: Dictionary = OpticalShowcases.make(id,policy) if id in OpticalShowcases.ids() else Scenes.make(id,policy)
	if id == OpticalFixtures.ID: scene = OpticalFixtures.make(policy)
	if scene.has("error"): return _refuse(str(scene.error))
	if not load_document(scene): return false
	_demo_overview = true
	wb._name.text = "strata-" + id
	return _say(str(scene.get("title",id)) + " · installing the complete authored scene in Overview.")


func save_named(label: String) -> bool:
	if not _host_admits_strata(): return false
	if authoring_busy(): return _refuse("Finish or stop native authoring and its readback before saving.")
	if not _gesture.is_empty() or not _pending.is_empty() or _apply_serial > 0:
		return _refuse("Finish or cancel the layer gesture/replacement before saving.")
	var error := Document.write_named(label,wb.applied,wb._generated_active,wb._material_baseline,layer_owner.document())
	if not error.is_empty(): return _refuse(error)
	return _say("Saved all four authored planes and presentation settings · " + label + ". Undo remains in this session; runtime continuation is not captured.")


func play_edit_reason() -> String:
	if authoring_busy() and not _authoring._issuing_native: return "Finish or stop the reviewed native authoring job before ordinary Play edits."
	if not enabled(): return ""
	if active_layer() != "play": return "The edit target is %s. Select Play to edit its material or use a decorative-plane tool." % active_layer()
	var row := Document.plane(_document,"play")
	if row.get("locked",false): return "The Play plane is locked."
	if not presenter.effective_visible("play"): return "The Play plane is hidden or excluded by solo/flat inspection."
	return ""


func _edit_ready(id: String) -> bool:
	if authoring_busy(): return _refuse("Finish or stop the reviewed native authoring job before another edit.")
	if not enabled() or id not in NONPLAY: return _refuse("Enable Strata and select a decorative plane first.")
	if wb.busy() or not _pending.is_empty(): return _refuse("Wait for the current owner transaction.")
	if _publication_errors.has(id): return _refuse("This plane has a committed edit awaiting a valid view. Save and reopen its authored scene before editing it again.")
	if not layer_owner.can_edit(id) or not presenter.effective_visible(id): return _refuse("The selected plane is hidden, locked or excluded from this view.")
	return true


func _publish(id: String) -> bool:
	# The native edit is already committed. Even a failed display admission must
	# leave Save and the edit target reporting the actual authored revision.
	_document = layer_owner.document()
	var packet: Dictionary = layer_owner.snapshot_layer(id,true)
	if packet.is_empty() or packet.get("failed",false):
		_publication_errors[id] = "No current native publication"
		_say("Edit committed on %s; its decorative display is stale. The previous pixels remain. Save and reopen this authored scene to recover its view." % id)
		return false
	# A publication is bound to the current owner identity and authored revision,
	# not merely to a larger serial supplied by an arbitrary caller.
	_sources[id] = {"owner_id":packet.get("owner_id",-1),"reset_generation":packet.get("reset_generation",-1),"revision":packet.get("revision",-1)}
	if not presenter.expect_sources(_sources) or not presenter.apply_layer_packet(id,packet):
		_publication_errors[id] = "Current publication refused"
		_say("Edit committed on %s; its new display publication was refused. The previous pixels remain. Save and reopen this authored scene to recover its view." % id)
		return false
	_publication_errors.erase(id)
	presenter.apply_document(_document)
	_refresh_panel()
	return true


func edit_cells(id: String, cells: PackedInt32Array) -> bool:
	if not _edit_ready(id): return false
	var receipt: Dictionary = layer_owner.paint_cells(id,cells,layer_owner.generation())
	last_edit_receipt = receipt.duplicate(true)
	if not receipt.get("ok",false): return _refuse(str(receipt.get("error",receipt.get("reason","Native paint refused."))))
	last_edit_receipt["published"] = _publish(id)
	if not last_edit_receipt.published: return true # Native commit succeeded; stale pixels are a separate receipt field.
	return _say("Edited %s · %d cells · independent static-plane Undo." % [id,int(receipt.get("changed",cells.size()/3))])


func undo_layer() -> bool:
	if active_layer() == "play": return wb.paint_editor.undo()
	return _history("undo")


func redo_layer() -> bool:
	if active_layer() == "play": return wb.paint_editor.redo()
	return _history("redo")


func _history(action: String) -> bool:
	var id := active_layer()
	if not _edit_ready(id): return false
	cancel_gesture()
	var receipt: Dictionary = layer_owner.undo(id) if action == "undo" else layer_owner.redo(id)
	last_edit_receipt = receipt.duplicate(true)
	if not receipt.get("ok",false): return _refuse(str(receipt.get("error",receipt.get("reason","No retained history."))))
	last_edit_receipt["published"] = _publish(id)
	if not last_edit_receipt.published: return true # History was committed even when its later display failed.
	return _say("%s %s authored edit. Play history and simulation are unchanged." % [action.capitalize(),id])


func route_editor_action(action: String) -> Dictionary:
	if not enabled() or active_layer() == "play": return {"handled":false}
	var ok := false
	match action:
		"copy": ok = copy_selection()
		"undo", "redo": ok = _history(action)
		"cancel":
			cancel_gesture()
			ok = _say("Layer gesture cancelled; no native edit was committed.")
		_: return {"handled":false}
	return {"handled":true,"ok":ok}


func update_editor_controls(editor: Control) -> void:
	if not enabled() or active_layer() == "play": return
	var id := active_layer()
	var allowed: bool = layer_owner.can_edit(id) and presenter.effective_visible(id) and not wb.busy() and not _publication_errors.has(id)
	var history: Dictionary = _history_state.get(id,{})
	editor._copy.disabled = not selection.has_area() or not presenter.effective_visible(id) or wb.busy()
	editor._paste.disabled = not allowed or clipboard.is_empty()
	editor._undo_button.disabled = not allowed or int(history.get("undo",0)) == 0
	editor._redo_button.disabled = not allowed or int(history.get("redo",0)) == 0
	editor._undo_button.tooltip_text = "Undo the selected static plane; play history is independent."
	editor._cancel_button.disabled = _gesture.is_empty()


func copy_selection() -> bool:
	var id := active_layer()
	if not enabled() or id not in NONPLAY or not presenter.effective_visible(id): return _refuse("Select a visible decorative plane to copy.")
	if wb.busy() or not _gesture.is_empty(): return _refuse("Finish the current gesture first.")
	if not selection.has_area() or selection.size.x*selection.size.y > MAX_EDIT_CELLS:
		return _refuse("Select at most 16,384 native cells inside one plane.")
	var captured: Dictionary = layer_owner.capture_region(id,selection)
	if not captured.get("ok",false): return _refuse(str(captured.get("error","Native layer capture refused.")))
	clipboard = captured.duplicate(true)
	clipboard["layer"] = id
	clipboard["generation"] = layer_owner.generation()
	clipboard["region"] = selection
	return _say("Copied %d × %d native %s cells, including Empty." % [selection.size.x,selection.size.y,id])


func paste_at(point: Vector2i) -> bool:
	var id := active_layer()
	if not _edit_ready(id): return false
	if clipboard.is_empty() or int(clipboard.get("generation",-1)) != layer_owner.generation():
		return _refuse("Copy a selection from the current composition first.")
	var region: Rect2i = clipboard.region
	var plan := Shapes.rectangle(region.position,region.end-Vector2i.ONE,true,Document.extent_of(_document),MAX_EDIT_CELLS)
	if not plan.accepted: return _refuse(str(plan.error))
	var paste := Shapes.stamp_materials(plan.cells,clipboard.materials,region.position,point,Document.extent_of(_document),MAX_EDIT_CELLS)
	if not paste.accepted: return _refuse(str(paste.error))
	return edit_cells(id,_triples(paste.cells,0,paste.materials))


func _triples(points: PackedInt32Array, material: int, materials: PackedInt32Array = PackedInt32Array()) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(points.size()/2*3)
	for index: int in points.size()/2:
		result[index*3] = points[index*2]
		result[index*3+1] = points[index*2+1]
		result[index*3+2] = material if materials.is_empty() else materials[index]
	return result


func cancel_gesture() -> void:
	_gesture.clear()
	cursor = Vector2i(-1,-1)
	if is_instance_valid(_overlay): _overlay.queue_redraw()


func gesture() -> Dictionary:
	return _gesture.duplicate(false)


func _point(local: Vector2) -> Vector2i:
	var point: Vector2 = presenter.screen_to_layer(local,active_layer())
	if point.x < 0 or point.y < 0: return Vector2i(-1,-1)
	var cell := Vector2i(point.floor())
	return cell if Rect2i(Vector2i.ZERO,Document.extent_of(_document)).has_point(cell) else Vector2i(-1,-1)


func world_input(event: InputEvent) -> bool:
	if not enabled() or not event is InputEventMouse: return false
	if event is InputEventMouseButton and event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		cancel_gesture()
		return false
	if event is InputEventMouseMotion and wb._pan: return false
	var id := active_layer()
	if id == "play":
		if play_edit_reason().is_empty(): return false
		if event is InputEventMouseButton and event.pressed: _refuse(play_edit_reason())
		return true
	if wb._tool.selected != 0:
		if event is InputEventMouseButton and event.pressed: _refuse("Actor placement and physical tools address Play. Select Play for those tools.")
		return true
	cursor = _point(event.position)
	if event is InputEventMouseMotion:
		if not _gesture.is_empty() and cursor.x >= 0:
			_gesture.cursor = cursor
			if _gesture.tool in ["Brush","Eraser"] and (_gesture.points.is_empty() or _gesture.points.back() != cursor):
				if _gesture.points.size() >= MAX_STROKE_POINTS:
					cancel_gesture()
					_refuse("Draw a shorter gesture (at most 1,024 sampled points).")
				else: _gesture.points.append(cursor)
		return true
	if not event is InputEventMouseButton: return true
	if event.pressed:
		if cursor.x < 0 or not _edit_ready(id): return true
		var tool: String = wb.paint_editor.tool_name()
		if event.button_index == MOUSE_BUTTON_RIGHT: tool = "Eraser"
		if tool == "Fill":
			_refuse("Decorative planes support Brush, Eraser, Line, Rectangle, Outline and bounded Select/Copy/Paste. Fill remains a Play tool.")
			return true
		_gesture = {"layer":id,"generation":layer_owner.generation(),"revision":int(Document.plane(_document,id).revision),
			"tool":tool,"anchor":cursor,"cursor":cursor,
			"points":[cursor],"radius":wb.paint_editor.radius(),"material":0 if tool == "Eraser" else wb.paint_editor.material_id}
		return true
	if _gesture.is_empty(): return true
	var saved := _gesture
	_gesture = {}
	if cursor.x < 0 or saved.layer != id or int(saved.generation) != layer_owner.generation() \
			or int(saved.revision) != int(Document.plane(_document,id).revision):
		_refuse("Gesture cancelled outside its original plane or after another edit changed that plane.")
		return true
	if saved.tool == "Select":
		var anchor: Vector2i = saved.anchor
		var region := Rect2i(anchor.min(cursor),anchor.max(cursor)-anchor.min(cursor)+Vector2i.ONE)
		if region.size.x*region.size.y > MAX_EDIT_CELLS:
			_refuse("Select at most 16,384 cells.")
		else:
			selection = region
			_say("Selected %d × %d on %s. Copy reads authoritative native materials." % [region.size.x,region.size.y,id])
		return true
	if saved.tool == "Paste":
		paste_at(cursor)
		return true
	var extent := Document.extent_of(_document)
	var plan := {}
	if saved.tool in ["Rectangle","Outline"]:
		plan = Shapes.rectangle(saved.anchor,cursor,saved.tool == "Rectangle",extent,MAX_EDIT_CELLS)
	elif saved.tool == "Line":
		plan = Shapes.line(saved.anchor,cursor,int(saved.radius),extent,MAX_EDIT_CELLS)
	else:
		var selected := {}
		var points: Array = saved.points
		if points.back() != cursor: points.append(cursor)
		for index: int in points.size():
			var segment := Shapes.line(points[maxi(0,index-1)],points[index],int(saved.radius),extent,MAX_EDIT_CELLS)
			if not segment.accepted:
				_refuse(str(segment.error))
				return true
			if segment.get("clipped",false):
				_refuse("Brush crosses the canvas boundary; use a smaller radius or move inside.")
				return true
			for cell_index: int in segment.cells.size()/2:
				selected[int(segment.cells[cell_index*2+1])*extent.x+int(segment.cells[cell_index*2])] = true
				if selected.size() > MAX_EDIT_CELLS:
					_refuse("Gesture exceeds 16,384 cells; use smaller strokes.")
					return true
		var cells := PackedInt32Array()
		var ordered: Array = selected.keys()
		ordered.sort()
		for index: int in ordered:
			cells.append(index%extent.x)
			cells.append(index/extent.x)
		plan = {"accepted":true,"cells":cells}
	if not plan.get("accepted",false):
		_refuse(str(plan.get("error","Shape refused.")))
		return true
	if plan.get("clipped",false):
		_refuse("Shape crosses the canvas boundary; no partial decorative edit was applied.")
		return true
	edit_cells(id,_triples(plan.cells,int(saved.material)))
	return true


func key_input(event: InputEvent) -> bool:
	if not enabled() or active_layer() == "play" or not event is InputEventKey or not event.pressed or event.echo: return false
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	if event.keycode == KEY_ESCAPE:
		cancel_gesture()
		_say("Layer gesture cancelled; no native edit was committed.")
		return true
	if event.ctrl_pressed or event.meta_pressed:
		match event.keycode:
			KEY_S: wb.save_setup()
			KEY_C: copy_selection()
			KEY_V: wb.paint_editor.select_tool("Paste")
			KEY_Z:
				if event.shift_pressed: _history("redo")
				else: _history("undo")
			KEY_Y: _history("redo")
			_: return false
		return true
	var keys := {KEY_B:"Brush",KEY_E:"Eraser",KEY_L:"Line",KEY_R:"Rectangle",KEY_O:"Outline",KEY_S:"Select",KEY_V:"Paste"}
	if keys.has(event.keycode):
		cancel_gesture()
		wb.paint_editor.select_tool(keys[event.keycode])
		return true
	return false


func _process(delta: float) -> void:
	if _authoring != null and _authoring.busy(): _authoring.step()
	if enabled():
		presenter.advance_optics(delta)
		presenter.sync_view()
		if is_instance_valid(_overlay): _overlay.queue_redraw()
	if not enabled() and not authoring_busy(): set_process(false)


func diagnostics() -> Dictionary:
	var state: Dictionary = wb.host.simulation_worker.paint_state() if wb != null else {}
	var actors := []
	if wb != null:
		for actor: Dictionary in wb.applied.get("actors",[]): actors.append(int(actor.id))
	return {"enabled":enabled(),"active_layer":active_layer(),"play_generation":state.get("generation",-1),
		"play_revision":state.get("revision",-1),"play_tick":state.get("tick",-1),
		"simulation_worker_id":wb.host.simulation_worker.get_instance_id(),
		"physical_session_id":wb.host.physical_actor_session.get_instance_id() if wb.host.physical_actor_session != null else 0,
		"actor_ids":actors,"layers":layer_owner.stats(),"presentation":presenter.diagnostics() if is_instance_valid(presenter) else {},
		"pending":not _pending.is_empty(),"play_apply_serial":_apply_serial}


func _clear_scene() -> void:
	if _authoring != null: _authoring.retire_scene()
	if is_instance_valid(presenter):
		presenter.detach()
		presenter.free()
	presenter = null
	layer_owner.retire()
	_layer_ready = false
	_sources.clear()
	_history_state.clear()
	_publication_errors.clear()
	_document = {}
	_optics_inspection = Optics.inspection_defaults()
	selection = Rect2i()
	clipboard.clear()
	cancel_gesture()
	set_process(false)
	if is_instance_valid(_indicator): _indicator.hide()
	if wb != null and wb.paint_editor != null and wb.paint_editor._overlay != null: wb.paint_editor._overlay.show()


func shutdown() -> void:
	if _closed: return
	_closed = true
	cancel_candidate()
	_clear_scene()
	if _authoring != null:
		_authoring.shutdown()
		_authoring = null
	if is_instance_valid(_overlay): _overlay.queue_free()


func _exit_tree() -> void:
	shutdown()


func _authoring_service() -> RefCounted:
	if _authoring == null:
		_authoring = Authoring.new()
		_authoring.mount(self)
	return _authoring


func authoring_materials() -> Array[Dictionary]:
	return _authoring_service().authoring_materials()


func authoring_busy() -> bool:
	return _authoring != null and _authoring.busy()


func authoring_state() -> Dictionary:
	return _authoring.authoring_state() if _authoring != null else {"status":"idle", "busy":false, "can_approve":false}


func authoring_inspect_source(path: String) -> Dictionary:
	return _authoring_service().authoring_inspect_source(path)


func preview_import(path: String, options: Dictionary) -> Dictionary:
	return _authoring_service().preview_import(path, options)


func preview_module(id: String, options: Dictionary) -> Dictionary:
	return _authoring_service().preview_module(id, options)


func preview_composition(id: String, options: Dictionary) -> Dictionary:
	return _authoring_service().preview_composition(id, options)


func approve_plan(token: String) -> Dictionary:
	return _authoring_service().approve_plan(token)


func stop_authoring() -> Dictionary:
	return _authoring_service().stop_authoring()


func module_catalogue() -> Array:
	return _authoring_service().module_catalogue()


func composition_catalogue() -> Array:
	return _authoring_service().composition_catalogue()


func apply_composition_settings(token: String) -> Dictionary:
	return _authoring_service().apply_composition_settings(token)


func import_fixture_catalogue() -> Array:
	return _authoring_service().import_fixture_catalogue()


func harvest_module(plane: String, region: Array, title: String) -> Dictionary:
	return _authoring_service().harvest_module(plane, region, title)


func export_module(id: String, path: String) -> Dictionary:
	return _authoring_service().export_module(id, path)


func authoring_plane_state(id: String) -> Dictionary:
	return _authoring_service().authoring_plane_state(id)


func fit_scene() -> bool:
	if not has_document(): return _refuse("Load or enable a scene before fitting the view.")
	_show_overview()
	if is_instance_valid(presenter): presenter.sync_view()
	return _say("Fit to the existing Workbench Overview camera.")


func scene_catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var challenge := OpticalFixtures.metadata()
	challenge.label = "Optics readability challenge · adversarial native scene"
	result.append(challenge)
	for id: String in OpticalShowcases.ids():
		var entry := OpticalShowcases.metadata(id)
		if entry.has("error"): continue
		entry.label = "%s · optics study · %d × %d" % [entry.title,entry.extent[0],entry.extent[1]]
		result.append(entry)
	for id: String in Scenes.Showcase.ids():
		var entry: Dictionary = Scenes.Showcase.metadata(id)
		if entry.has("error"): continue
		entry.label = "%s · %d × %d" % [entry.title, entry.extent[0], entry.extent[1]]
		result.append(entry)
	var labels := ["Industrial assembly hall", "Science-fiction arcology", "Organic / industrial cavern"]
	for index: int in Scenes.IDS.size():
		result.append({"id":Scenes.IDS[index], "label":labels[index] + " · original 1024 × 768",
			"description":"Original #769 native four-plane reference scene; static decoration."})
	return result


func atmosphere_profiles() -> Array[Dictionary]:
	return Atmosphere.presets()


func atmosphere_presets() -> Array[Dictionary]:
	return atmosphere_profiles()


func atmosphere_state() -> Dictionary:
	return _document.get("atmosphere", Atmosphere.default_configuration()).duplicate(true)


func set_atmosphere(configuration: Dictionary) -> bool:
	if not _ensure_current(): return false
	if not _pending.is_empty() or _apply_serial > 0: return _refuse("Wait for scene admission before changing atmosphere.")
	var reason: String = Atmosphere.validate(configuration, Document.extent_of(_document))
	if not reason.is_empty(): return _refuse(reason)
	var previous := atmosphere_state()
	var before := {}
	var after := {}
	for effect: Dictionary in previous.effects: before[effect.id] = effect
	for effect: Dictionary in configuration.effects: after[effect.id] = effect
	for id: String in before:
		if not after.has(id) or before[id] != after[id]:
			if not layer_owner.can_edit(str(before[id].plane)): return _refuse("An excluded or locked plane cannot change its authored effects.")
	for id: String in after:
		if not before.has(id) or before[id] != after[id]:
			if not layer_owner.can_edit(str(after[id].plane)): return _refuse("An excluded or locked plane cannot receive authored effects.")
	if not layer_owner.update_extensions({"atmosphere":configuration}): return _refuse(layer_owner.last_error)
	_document = layer_owner.document()
	if not presenter.apply_document(_document):
		return _say("Atmosphere settings committed; their display update failed. Save and reopen the authored scene. " + presenter.last_error)
	return _say("Atmosphere settings saved in the authored scene · presentation-only motion, no native material or physics changes.")


func set_atmosphere_settings(patch: Dictionary) -> bool:
	var configuration := atmosphere_state()
	for key: Variant in patch:
		if key not in ["enabled", "paused", "seed"]: return _refuse("Use the regional effect controls for this atmosphere setting.")
		configuration[key] = patch[key]
	return set_atmosphere(configuration)


func add_atmosphere(preset: String, plane: String, region: Rect2i, seed: int) -> bool:
	if not _ensure_current(): return false
	if plane not in NONPLAY or not layer_owner.can_edit(plane): return _refuse("Select a visible, unlocked decorative plane for an authored visual effect.")
	var configuration := atmosphere_state()
	var id := "effect-" + Crypto.new().generate_random_bytes(6).hex_encode()
	var effect: Dictionary = Atmosphere.make_effect(preset, plane, region, seed, id)
	if effect.is_empty(): return _refuse("Unknown atmosphere profile.")
	configuration.effects.append(effect)
	configuration.enabled = true
	return set_atmosphere(configuration)


func add_atmosphere_profile(preset: String, plane: String, region: Array, seed: int) -> bool:
	if region.size() != 4: return _refuse("An effect region needs x, y, width and height.")
	for component: Variant in region:
		if not Setup._integer(component, 0, 2048): return _refuse("Effect coordinates must be bounded integer cells.")
	return add_atmosphere(preset, plane, Rect2i(int(region[0]), int(region[1]), int(region[2]), int(region[3])), seed)


func update_atmosphere_effect(id: String, patch: Dictionary) -> bool:
	var configuration := atmosphere_state()
	for effect: Dictionary in configuration.effects:
		if effect.id != id: continue
		if not layer_owner.can_edit(str(effect.plane)): return _refuse("The effect's native plane is hidden or locked.")
		for key: Variant in patch:
			if key not in ["region", "seed", "count", "speed", "strength", "direction", "colour", "enabled"]:
				return _refuse("Effect identity and plane cannot be changed by a settings patch.")
			effect[key] = patch[key]
		return set_atmosphere(configuration)
	return _refuse("Unknown atmosphere effect identity.")


func remove_atmosphere_effect(id: String) -> bool:
	var configuration := atmosphere_state()
	for index: int in configuration.effects.size():
		var effect: Dictionary = configuration.effects[index]
		if effect.id == id:
			if not layer_owner.can_edit(str(effect.plane)): return _refuse("The effect's native plane is hidden or locked.")
			configuration.effects.remove_at(index)
			return set_atmosphere(configuration)
	return _refuse("Unknown atmosphere effect identity.")


func reset_atmosphere_phase() -> bool:
	if not is_instance_valid(presenter): return _refuse("Enable Strata before restarting visual motion.")
	presenter.reset_atmosphere_phase()
	return _say("Visual atmosphere restarted from its deterministic seed; authored geometry and history are unchanged.")


func _load_optics_preferences() -> void:
	if _optics_preferences_loaded: return
	_optics_preferences_loaded = true
	_optics_quality = OpticalPresets.read_quality()
	var read: Dictionary = OpticalPresets.read_catalogue()
	_optics_catalogue_error = str(read.get("error",""))
	_optics_catalogue = read.get("catalogue",OpticalPresets.empty_catalogue())
	if is_instance_valid(presenter): presenter.set_optics_quality(_optics_quality)


func _say_optics(text: String) -> bool:
	# Live sliders must not duplicate a pending native import/construction preview
	# through the unrelated authoring tabs on every value change.
	_status = text
	if is_instance_valid(wb): wb.message = text
	if is_instance_valid(_panel): _panel.refresh_optics(_document,text)
	return true


func optics_state() -> Dictionary:
	_load_optics_preferences()
	var customs: Array = []
	for row: Dictionary in _optics_catalogue.presets:
		customs.append({"id":row.id,"label":row.name,"description":"Custom optical preset · editable scene values","custom":true})
	return {"configuration":_document.get("optics",Optics.defaults()).duplicate(true),
		"inspection":_optics_inspection.duplicate(true),"quality":_optics_quality,
		"custom_presets":customs,"preset_error":_optics_catalogue_error,
		"statistics":presenter.optics_statistics() if is_instance_valid(presenter) else {}}


func optics_profiles() -> Array:
	var result: Array = OpticalProfiles.list_profiles()
	result.append_array(optics_state().custom_presets)
	return result


func _commit_optics(configuration: Dictionary) -> bool:
	var error := Optics.validate(configuration)
	if not error.is_empty(): return _refuse(error)
	if wb.busy() or not _pending.is_empty() or _apply_serial > 0:
		return _refuse("Finish scene admission before changing optical settings.")
	if not _ensure_current(): return false
	# Optical parallax can change a decorative projection, so end any unfinished
	# gesture before applying the new projection. The edit target never changes.
	cancel_gesture()
	if wb.paint_editor != null: wb.paint_editor.cancel_preview()
	if not layer_owner.set_optics(configuration): return _refuse(layer_owner.last_error)
	if int(_document.version) == Document.LEGACY_VERSION: _document = Document.upgraded(_document)
	_document.version = Document.OPTICAL_VERSION
	_document.optics = Optics.canonical(configuration)
	if not presenter.apply_optics(_document.optics):
		return _say("Optical settings saved; display update failed. Save and reopen the scene. " + presenter.last_error)
	set_process(enabled() or authoring_busy())
	return _say_optics("Optical presentation updated · edit target %s · Play materials and physics preserved." % active_layer().to_upper())


func set_optics(patch: Dictionary) -> bool:
	var current: Dictionary = _document.get("optics",Optics.defaults())
	var result := Optics.patched(current,patch)
	if result.has("error"): return _refuse(str(result.error))
	return _commit_optics(result.configuration)


func set_plane_optics(id: String, patch: Dictionary) -> bool:
	# Play exposes only its artistic focus anchor; every shading/mapping control
	# remains the existing physical renderer's responsibility.
	if id == "play":
		for key: Variant in patch:
			if key != "depth": return _refuse("Play optics exposes focal depth only; its material renderer stays crisp.")
	var current: Dictionary = _document.get("optics",Optics.defaults())
	var result := Optics.patched(current,patch,id)
	if result.has("error"): return _refuse(str(result.error))
	return _commit_optics(result.configuration)


func select_optics_profile(id: String) -> bool:
	_load_optics_preferences()
	var configuration := OpticalProfiles.configuration(id)
	if configuration.is_empty():
		for row: Dictionary in _optics_catalogue.presets:
			if row.id == id: configuration = row.configuration.duplicate(true)
	if configuration.is_empty(): return _refuse("Unknown optical profile; current settings are retained.")
	if not _commit_optics(configuration): return false
	# Explicit profile selection leaves temporary comparisons in a predictable state.
	_optics_inspection = Optics.inspection_defaults()
	presenter.set_optics_inspection(_optics_inspection)
	if is_instance_valid(_panel): _panel.refresh_optics(_document,_status)
	return true


func reset_optics() -> bool:
	return select_optics_profile("classic")


func set_optics_inspection(patch: Dictionary) -> bool:
	var candidate := _optics_inspection.duplicate(true)
	for key: Variant in patch:
		if key not in candidate: return _refuse("Unsupported temporary optical comparison.")
		candidate[key] = patch[key]
	var error := Optics.validate_inspection(candidate)
	if not error.is_empty(): return _refuse(error)
	if not _ensure_current(): return false
	cancel_gesture()
	if wb.paint_editor != null: wb.paint_editor.cancel_preview()
	if not presenter.set_optics_inspection(candidate): return _refuse(presenter.last_error)
	_optics_inspection = candidate
	return _say_optics("Temporary optical comparison · authored optics and native edit target retained.")


func set_optics_quality(quality: String) -> bool:
	if quality not in Optics.QUALITIES: return _refuse("Choose Low, Balanced or High optical quality.")
	_load_optics_preferences()
	var error := OpticalPresets.write_quality(quality)
	if not error.is_empty(): return _refuse(error)
	_optics_quality = quality
	if is_instance_valid(presenter): presenter.set_optics_quality(quality)
	return _say_optics("Optical quality: %s · application preference; authored scene settings unchanged." % quality.capitalize())


func save_optics_preset(label: String) -> bool:
	if wb.busy() or not _pending.is_empty() or _apply_serial > 0:
		return _refuse("Finish scene admission before saving an optical preset.")
	if not _ensure_current(): return false
	var config: Dictionary = _document.get("optics",Optics.defaults())
	var saved := OpticalPresets.save(label,config)
	if saved.has("error"): return _refuse(str(saved.error))
	_optics_catalogue = saved.catalogue
	_optics_catalogue_error = ""
	# Named copies retain their own identity while the embedded scene settings
	# remain independent of future catalogue editing/removal.
	config = config.duplicate(true)
	config.profile = saved.id
	if not _commit_optics(config): return false
	return _say_optics("Saved editable optical preset · " + label.strip_edges())


func delete_optics_preset(id: String) -> bool:
	var removed := OpticalPresets.remove(id)
	if removed.has("error"): return _refuse(str(removed.error))
	_optics_catalogue = removed.catalogue
	_optics_catalogue_error = ""
	return _say_optics("Removed the named optical preset. The current scene retains its complete optical settings.")
