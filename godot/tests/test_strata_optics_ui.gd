extends SceneTree

## Actual controls with a synthetic mediator: proves UI routing and edit/focus
## separation. Native, shader, persistence and framebuffer evidence is separate.
const OpticsPanel = preload("res://scripts/depth/workbench_strata_optics_panel.gd")
const Configuration = preload("res://scripts/depth/strata_optics_configuration.gd")
var checks: Array[Dictionary] = []

class Mediator extends Node:
	var configuration: Dictionary = Configuration.defaults()
	var inspection := {"bypass":false,"clarity":false,"wipe":1.0,"focus_override":""}
	var quality := "balanced"
	var presets: Array = []
	var calls: Array[Dictionary] = []
	var selected_edit_plane := "background"
	func optics_state() -> Dictionary:
		return {"configuration":configuration.duplicate(true),"inspection":inspection.duplicate(true),"quality":quality,"custom_presets":presets.duplicate(true)}
	func optics_profiles() -> Array:
		var result: Array = [{"id":"classic","label":"Classic","description":"Exact bypass"},
			{"id":"clarity","label":"Gameplay Clarity","description":"Readable Play without relying only on colour"}]
		result.append_array(presets)
		return result
	func set_optics(patch: Dictionary) -> bool:
		calls.append({"method":"set_optics","patch":patch.duplicate(true)})
		configuration.merge(patch,true)
		return true
	func set_plane_optics(id: String, patch: Dictionary) -> bool:
		calls.append({"method":"set_plane_optics","plane":id,"patch":patch.duplicate(true)})
		configuration.planes[id].merge(patch,true)
		return true
	func select_optics_profile(id: String) -> bool:
		calls.append({"method":"select_optics_profile","id":id})
		configuration.profile = id
		return true
	func reset_optics() -> bool:
		calls.append({"method":"reset_optics"})
		configuration = Configuration.defaults()
		return true
	func set_optics_inspection(patch: Dictionary) -> bool:
		calls.append({"method":"set_optics_inspection","patch":patch.duplicate(true)})
		inspection.merge(patch,true)
		return true
	func set_optics_quality(value: String) -> bool:
		calls.append({"method":"set_optics_quality","value":value})
		quality = value
		return true
	func save_optics_preset(value: String) -> bool:
		calls.append({"method":"save_optics_preset","name":value,"configuration":configuration.duplicate(true)})
		return true
	func delete_optics_preset(id: String) -> bool:
		calls.append({"method":"delete_optics_preset","id":id})
		return true


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, passed: bool) -> void:
	checks.append({"label":label,"passed":passed})
	if not passed: push_error("STRATA3_UI " + label)


func _run() -> void:
	root.size = Vector2i(800,600)
	var mediator := Mediator.new()
	root.add_child(mediator)
	var tabs := TabContainer.new()
	tabs.size = Vector2(560,480)
	root.add_child(tabs)
	var panel := OpticsPanel.new()
	root.add_child(panel)
	panel.mount(mediator,tabs)
	var document := {"presentation":{"enabled":true,"active":"background"}}
	panel.refresh(document,"Synthetic status")
	await process_frame
	_check("Optics is one integrated scrollable tab", tabs.get_tab_count() == 1 and tabs.get_tab_title(0) == "Optics" and panel._page.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	_check("refresh and mount issue no mutation", mediator.calls.is_empty())
	_check("panel has no recurring processing", not panel.is_processing())
	_check("preset name capacity matches validated store", panel._preset_name.max_length == 48)
	_check("native target explicitly differs from optics selector", panel._plane_id == "scripted" and "BACKGROUND" in panel._edit_target.text)
	_check("Play focus default disables unused manual distance and focal plane", not panel._global_controls.focus_distance.spin.editable and panel._focal_plane.disabled)
	_check("Classic has immediate bypass and explicit reset controls", not panel._enabled.button_pressed and panel._profile.get_item_metadata(panel._profile.selected) == "classic")
	_check("advanced effects hidden initially", not panel._advanced.visible and not panel._plane_advanced.visible)
	panel._advanced_toggle.button_pressed = true
	panel._plane_advanced_toggle.button_pressed = true
	_check("advanced controls can be revealed independently", panel._advanced.visible and panel._plane_advanced.visible)
	panel._plane_picker.select(0)
	panel._plane_picker.item_selected.emit(0)
	_check("inspecting Play does not change edit target or dispatch mutation", mediator.calls.is_empty() and mediator.selected_edit_plane == "background")
	_check("Play shading controls and participation are disabled", panel._plane_participates.disabled and not panel._plane_controls.contrast.spin.editable and panel._tint.disabled)
	_check("Play optical depth is editable with explicit safety explanation", panel._plane_controls.depth.spin.editable and "physic" in panel._plane_note.text)
	panel._plane_patch({"brightness":0.5})
	_check("UI cannot bypass Play crisp guard", mediator.calls.is_empty())
	panel._plane_controls.depth.slider.value = 0.2
	_check("Play depth reaches optical-only API", mediator.calls.back().method == "set_plane_optics" and mediator.calls.back().plane == "play" and is_equal_approx(mediator.calls.back().patch.depth,0.2))
	panel._plane_picker.select(3)
	panel._plane_picker.item_selected.emit(3)
	panel._plane_controls.contrast.slider.value = 0.63
	_check("decorative optical edit addresses explicit plane", mediator.calls.back().method == "set_plane_optics" and mediator.calls.back().plane == "background" and is_equal_approx(mediator.calls.back().patch.contrast,0.63))
	panel._focus_mode.select(1)
	panel._focus_mode.item_selected.emit(1)
	panel.refresh(document)
	_check("manual mode exposes distance without authoring mutation", panel._global_controls.focus_distance.spin.editable and mediator.selected_edit_plane == "background")
	panel._focus_mode.select(2)
	panel._focus_mode.item_selected.emit(2)
	panel.refresh(document)
	panel._focal_plane.select(1)
	panel._focal_plane.item_selected.emit(1)
	_check("manual focal plane controls optics only", not panel._focal_plane.disabled and mediator.configuration.focal_plane == "scripted" and mediator.selected_edit_plane == "background")
	var authored := JSON.stringify(mediator.configuration)
	panel._bypass.button_pressed = true
	panel._clarity.button_pressed = true
	panel._wipe.slider.value = 0.45
	panel._inspection_focus.select(4)
	panel._inspection_focus.item_selected.emit(4)
	_check("comparison and inspection do not mutate authored optics", JSON.stringify(mediator.configuration) == authored and mediator.inspection.bypass and mediator.inspection.clarity and is_equal_approx(mediator.inspection.wipe,0.45) and mediator.inspection.focus_override == "background")
	panel._quality.select(0)
	panel._quality.item_selected.emit(0)
	_check("quality preference is separate from authored optics", mediator.quality == "low" and JSON.stringify(mediator.configuration) == authored)
	panel._effects.shadows.button_pressed = not panel._effects.shadows.button_pressed
	_check("one effect toggle retains all effect fields", mediator.calls.back().method == "set_optics" and mediator.calls.back().patch.effects.size() == OpticsPanel.EFFECTS.size())
	panel.refresh(document)
	panel._preset_name.text = ""
	var count: int = mediator.calls.size()
	panel._save_named()
	_check("empty custom name refuses before mediator", mediator.calls.size() == count and "Enter a name" in panel._status.text)
	panel._preset_name.text = "  Copper halls  "
	panel._save_named()
	_check("named copy trims and sends actual configuration", mediator.calls.back().method == "save_optics_preset" and mediator.calls.back().name == "Copper halls")
	count = mediator.calls.size()
	panel._delete_selected()
	_check("built-in profile deletion refused in UI", mediator.calls.size() == count and panel._delete_preset.disabled)
	mediator.presets.append({"id":"custom-copper","label":"Copper halls","description":"Custom authored optics"})
	mediator.configuration.profile = "custom-copper"
	panel.refresh(document)
	_check("custom catalogue updates without stale selection", panel._profile.item_count == 3 and panel._profile.get_item_metadata(panel._profile.selected) == "custom-copper" and not panel._delete_preset.disabled)
	panel._delete_selected()
	_check("only exact selected custom ID is removed", mediator.calls.back() == {"method":"delete_optics_preset","id":"custom-copper"})
	# A status refresh must not replace uncommitted numeric input mid-keystroke.
	var field: LineEdit = panel._global_controls.tonal.spin.get_line_edit()
	panel._page.ensure_control_visible(field)
	await process_frame
	field.grab_focus()
	field.text = "0.37"
	panel.refresh(document,"Asynchronous status")
	_check("asynchronous refresh retains focused numeric text", field.text == "0.37")
	panel._preset_name.text = "Typed values"
	panel._save_named()
	_check("Save commits focused typed value before copying preset", mediator.calls.back().method == "save_optics_preset" and is_equal_approx(mediator.calls.back().configuration.tonal,0.37))
	field.release_focus()
	mediator.configuration.enabled = true
	mediator.configuration.planes.background.opacity = 0.0
	mediator.inspection.bypass = false
	panel.refresh(document)
	_check("invisible optical target warning preserves native authority", "OPTICALLY HIDDEN" in panel._edit_target.text and mediator.selected_edit_plane == "background")
	panel.refresh({"presentation":{"enabled":false,"active":"background"}})
	_check("layered-off indicator names effective Play edit target", "PLAY" in panel._edit_target.text)
	var failures := 0
	for item: Dictionary in checks:
		if not item.passed: failures += 1
	print("STRATA3_UI_RESULT " + JSON.stringify({"schema":"cybersand.strata3-ui.v1","scope":"actual controls with synthetic mediator; no native, framebuffer, persistence or physical GPU claim","checks":checks,"failures":failures,"passed":failures == 0}))
	panel.queue_free()
	tabs.queue_free()
	mediator.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
