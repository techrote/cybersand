extends SceneTree

# Exercises the actual configuration Window and its signal/state boundary. The
# host below is deliberately UI-only; physical/native behavior has separate real
# Workbench integration tests and is not inferred from these control assertions.
const Configuration = preload("res://scripts/workbench_actor_panel.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")

class Host extends Control:
	var paused := false
	var physical_actor_session: RefCounted

class Workbench extends Control:
	var host := Host.new()
	var applied := {"actors":[],"selected":0}
	var message := "Ready."
	var pilot_transfers := 0
	var pause_calls := 0
	var applied_controls: Array = []
	var placement_pose := {"position":Vector2(223,240),"rotation":PI/4.0}
	func _row(parent: Control) -> HFlowContainer:
		var row := HFlowContainer.new()
		parent.add_child(row)
		return row
	func _label(parent: Control, caption: String) -> void:
		var label := Label.new()
		label.text = caption
		parent.add_child(label)
	func _button(parent: Control, caption: String, action: Callable) -> Button:
		var button := Button.new()
		button.text = caption
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			var focus := button.get_viewport().gui_get_focus_owner()
			if focus is LineEdit and focus.get_parent() is SpinBox: focus.get_parent().apply()
			if focus != null: focus.release_focus()
			action.call())
		parent.add_child(button)
		return button
	func _spin(parent: Control, caption: String, field: SpinBox, low: float, high: float, step: float, value: float) -> void:
		_label(parent,caption)
		field.min_value = low
		field.max_value = high
		field.step = step
		field.value = value
		field.custom_minimum_size.x = 80
		parent.add_child(field)
	func selected_id() -> int: return int(applied.selected)
	func select_instance(id: int) -> void: applied.selected = id
	func actor(data: Dictionary, id: int) -> Dictionary:
		for a: Dictionary in data.actors:
			if a.id == id: return a
		return {}
	func pilot_description() -> String: return "#1 test pilot"
	func toggle_pause() -> void:
		pause_calls += 1
		host.paused = not host.paused
	func focus_selected() -> void: pass
	func reset_selected() -> void: pass
	func remove_selected() -> void: pass
	func pilot_instance(_id: int) -> void: pilot_transfers += 1
	func hand_back_pilot() -> void: pilot_transfers += 1
	func release_pilot() -> void: pilot_transfers += 1
	func entered_position() -> Vector2: return Vector2(200,200)
	func place(_model: String, _point: Vector2) -> void: pass
	func _replace_actor(_model: String) -> void: pass
	func apply_actor_equipment(_id: int,_item: int) -> void: pass
	func set_actor_control(id: int,config: Dictionary) -> void:
		actor(applied,id).control = config.duplicate(true)
		applied_controls.append(config.duplicate(true))
	func actor_observation(_id: int,_issue: bool = false) -> Dictionary: return {}
	func refuse(reason: String) -> bool:
		message = reason
		return false
	func actor_placement_pose(_id: int) -> Dictionary: return placement_pose

var checks := 0
var failures: Array[String] = []
var signals_seen: Dictionary = {}
var panel: Window
var wb: Control


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WB_ACTOR_CONFIGURATION: "+label)


func find_button(root_node: Node, caption: String) -> Button:
	if root_node is Button and root_node.text == caption: return root_node
	for child: Node in root_node.get_children():
		var found := find_button(child,caption)
		if found != null: return found
	return null


func run() -> void:
	wb = Workbench.new()
	root.add_child(wb)
	wb.add_child(wb.host)
	wb.applied = {"selected":1,"actors":[{"id":1,"model":"runner","spawn":[120,140],
		"spawn_rotation_degrees":30.0,"control":Catalog.default_control("runner")}]}
	panel = Configuration.new()
	wb.add_child(panel)
	panel.mount(wb)
	panel.interaction_mode_requested.connect(func(mode: String) -> void: signals_seen.mode = mode)
	panel.manipulation_settings_requested.connect(func(settings: Dictionary) -> void: signals_seen.settings = settings)
	panel.capacity_requested.connect(func(config: Dictionary) -> void: signals_seen.capacity = config)
	panel.demo_requested.connect(func(kind: String,count: int) -> void: signals_seen.demo = [kind,count])
	panel.tuning_requested.connect(func(id: int,options: Dictionary) -> void: signals_seen.tuning = [id,options])
	panel.placement_requested.connect(func(id: int,position: Vector2,angle: float) -> void: signals_seen.placement = [id,position,angle])
	panel.popup_centered(Vector2i(760,700))
	await process_frame
	check(panel.tabs.get_tab_count() == 6,"one configuration Window exposes six sections")
	check(wb.pause_calls == 0 and not wb.host.paused,"opening and refreshing does not pause the world")
	check(wb.pilot_transfers == 0,"opening and inspecting does not transfer pilot")
	check(panel.placement_x.value == 120 and panel.placement_angle.value == 30,"authored position and optional orientation displayed")
	check(panel.max_force.value == 24000,"force field represents the actual default without range-step rounding")
	panel.instances.get_popup().popup()
	await process_frame
	panel.refresh()
	await process_frame
	check(panel.instances.get_popup().visible,"periodic diagnostics leave the actor inspection menu open")
	panel.instances.get_popup().hide()
	panel.interaction_mode.select(1)
	panel.interaction_mode.item_selected.emit(1)
	check(signals_seen.get("mode") == "grab","pointer mode emits a distinct physical-grab request")
	panel.set_sandbox_state({"mode":"place","settings":{"stiffness":160.0,"snap_enabled":false},
		"capacity":{"logical_limit":64,"body_limit":256,"proxy_limit":300,"actors":64,"bodies":88,"proxies":96,
			"joints":24,"max_logical":4096,"max_bodies":4096,"max_proxies":4096},"preparing":true})
	check(panel.capacity_info.text.contains("64 actors") and panel.capacity_info.text.contains("88 bodies"),"logical and physical use remain distinct")
	check(panel.capacity_info.text.contains("authored joints"),"capacity labels authored constraints separately from evolved live topology")
	panel.set_sandbox_state({"mode":"inspect"})
	check(panel.interaction_mode.get_item_metadata(panel.interaction_mode.selected) == "inspect","legacy canvas mode does not falsely display Grab or Place")
	panel.set_sandbox_state({"mode":"place","preparing":true})
	check(panel.operation_info.text.contains("Preparing"),"pending owner preparation is visible")
	panel.stiffness.value = 350
	panel.set_sandbox_state({"settings":{"stiffness":160.0}})
	check(panel.stiffness.value == 350,"periodic diagnostics do not overwrite staged manipulation settings")
	find_button(panel,"Apply manipulation settings").pressed.emit()
	check(signals_seen.settings.stiffness == 350 and not signals_seen.settings.snap_enabled,"explicit Apply emits staged force and snapping settings")
	panel.tabs.current_tab = 3
	await process_frame
	panel.stiffness.get_line_edit().grab_focus()
	panel.stiffness.get_line_edit().text = "425"
	panel.set_sandbox_state({"settings":{"stiffness":160.0}})
	check(panel.stiffness.get_line_edit().text == "425","focused numeric text survives periodic state refresh before commit")
	find_button(panel,"Apply manipulation settings").pressed.emit()
	check(signals_seen.settings.stiffness == 425,"Apply commits focused numeric text before emitting settings")
	check(panel.tuning.mass_multiplier.editable and not panel.tuning.thrust_multiplier.editable,"physical tuning exposes only model-compatible settings")
	panel.tuning.mass_multiplier.value = 1.25
	panel.refresh()
	check(panel.tuning.mass_multiplier.value == 1.25,"live refresh preserves staged actor tuning")
	find_button(panel,"Apply actor tuning / restart").pressed.emit()
	check(signals_seen.tuning[0] == 1 and signals_seen.tuning[1].mass_multiplier == 1.25,"actor tuning requests target selected identity with complete options")
	panel.stage_capacity_preset(64)
	check(panel.logical_limit.value == 64 and panel.body_limit.value >= 512,"capacity preset stages independent budgets")
	check(not signals_seen.has("capacity"),"capacity presets wait for explicit Apply")
	panel.logical_limit.value = 137
	find_button(panel,"Apply capacity").pressed.emit()
	check(signals_seen.capacity.logical_limit == 137 and signals_seen.capacity.version == 1,"numeric capacity emits versioned nonpreset configuration")
	panel.placement_x.value = 222.25
	panel.placement_y.value = 333.5
	panel.placement_angle.value = -45.25
	panel.refresh()
	check(panel.placement_x.value == 222.25,"live roster refresh preserves uncommitted precision values")
	find_button(panel,"Apply authored placement (paused)").pressed.emit()
	check(signals_seen.placement == [1,Vector2(222.25,333.5),-45.25],"authored placement request includes full precision and orientation")
	panel.demo.select(1)
	panel.demo_count.value = 64
	find_button(panel,"Load playground").pressed.emit()
	check(signals_seen.demo == ["barrels",64],"Barrel Crowd request has real requested population")
	check(wb.pilot_transfers == 0,"settings, placement and playground requests do not silently pilot")
	wb.applied.actors[0].control.source = "passive"
	panel.refresh()
	check(panel.source.get_item_metadata(panel.source.selected) == "passive","external controller handoff refreshes an already-inspected actor")
	panel._read_current_pose()
	check(panel.placement_x.value == 223 and is_equal_approx(panel.placement_angle.value,45.0),"explicit current-pose copy remains staged")
	wb.placement_pose.rotation = 7.0*PI/4.0
	panel._read_current_pose()
	check(is_equal_approx(panel.placement_angle.value,-45.0),"current continuous body rotation is wrapped instead of clamped by the angle field")
	panel.tabs.current_tab = 3
	await process_frame
	await process_frame
	var capture := OS.get_environment("CYBERSAND_ACTOR_CONFIGURATION_CAPTURE")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var error := panel.get_texture().get_image().save_png(capture)
		check(error == OK,"actual configuration framebuffer capture saved")
	panel.hide()
	check(wb.pause_calls == 0,"closing configuration does not pause unrelated actors")
	panel.queue_free()
	wb.queue_free()
	await process_frame
	print("WB_ACTOR_CONFIGURATION ",JSON.stringify({"checks":checks,"failures":failures,"renderer":DisplayServer.get_name()}))
	quit(0 if failures.is_empty() else 1)
