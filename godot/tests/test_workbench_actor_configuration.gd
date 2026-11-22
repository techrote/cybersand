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
		# Mirror the actual Shared Workbench refusal contract so the panel's
		# rejected-Apply acknowledgements are exercised, not bypassed by a mock.
		message = "Refused · " + reason.trim_prefix("MicroScenario rejected; ")
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
	check(panel._settings_dirty and panel.apply_info.text.contains("awaiting"),"signal emission alone does not acknowledge settings")
	panel.tabs.current_tab = 3
	await process_frame
	panel.stiffness.get_line_edit().grab_focus()
	panel.stiffness.get_line_edit().text = "425"
	panel.set_sandbox_state({"settings":{"stiffness":160.0}})
	check(panel.stiffness.get_line_edit().text == "425","focused numeric text survives periodic state refresh before commit")
	find_button(panel,"Apply manipulation settings").pressed.emit()
	check(signals_seen.settings.stiffness == 425,"Apply commits focused numeric text before emitting settings")
	panel.set_sandbox_state({"settings":panel._staged_values("settings")})
	check(not panel._settings_dirty and panel.apply_info.text.contains("Accepted"),"observed synchronous settings are accepted and clear only committed staging")
	check(panel.tuning.mass_multiplier.editable and not panel.tuning.thrust_multiplier.editable,"physical tuning exposes only model-compatible settings")
	panel.tuning.mass_multiplier.value = 1.25
	panel.refresh()
	check(panel.tuning.mass_multiplier.value == 1.25,"live refresh preserves staged actor tuning")
	find_button(panel,"Apply actor tuning / restart").pressed.emit()
	check(signals_seen.tuning[0] == 1 and signals_seen.tuning[1].mass_multiplier == 1.25,"actor tuning requests target selected identity with complete options")
	check(panel._tuning_dirty,"emitted tuning signal does not clear staging")
	wb.message = "Preparing physical tuning for #1 · controller restart."
	panel.set_sandbox_state({"preparing":true})
	check(panel.apply_info.text.contains("Pending"),"tuning owner preparation is pending, not installed")
	wb.applied.actors[0]["options"] = signals_seen.tuning[1].duplicate(true)
	panel.set_sandbox_state({"preparing":false})
	panel.refresh()
	check(not panel._tuning_dirty and panel.apply_info.text.contains("Accepted"),"tuning requires accepted actor options after preparation")
	panel.stage_capacity_preset(64)
	check(panel.logical_limit.value == 64 and panel.body_limit.value >= 512,"capacity preset stages independent budgets")
	check(not signals_seen.has("capacity"),"capacity presets wait for explicit Apply")
	panel.logical_limit.value = 137
	find_button(panel,"Apply capacity").pressed.emit()
	check(signals_seen.capacity.logical_limit == 137 and signals_seen.capacity.version == 1,"numeric capacity emits versioned nonpreset configuration")
	check(panel._capacity_dirty,"capacity remains staged after emitted signal")
	var admitted_capacity: Dictionary = signals_seen.capacity.duplicate(true)
	wb.message = "Preparing capacity · 137 actors."
	panel.set_sandbox_state({"preparing":true,"capacity":{"version":1,"logical_limit":64,"body_limit":256,"proxy_limit":300}})
	check(panel._capacity_dirty and panel.apply_info.text.contains("Pending"),"asynchronous capacity not reported installed during preparation")
	panel.set_sandbox_state({"preparing":false,"capacity":admitted_capacity})
	check(not panel._capacity_dirty and panel.apply_info.text.contains("Accepted"),"capacity cleared only when the accepted limits match the proposal")
	panel.logical_limit.value = 150
	find_button(panel,"Apply capacity").pressed.emit()
	var previous_capacity: Dictionary = signals_seen.capacity.duplicate(true)
	panel.set_sandbox_state({"preparing":true,"capacity":admitted_capacity})
	wb.message = "Refused · Unrelated tuning while capacity prepares."
	panel.set_sandbox_state({"preparing":true,"capacity":admitted_capacity})
	check(panel._apply_requests.capacity.phase == "pending",
		"another Apply refusal cannot cancel an already-admitted capacity preparation")
	wb.message = "Preparing capacity · 150 actors."
	panel.logical_limit.value = 166
	panel.set_sandbox_state({"preparing":false,"capacity":previous_capacity})
	check(panel.logical_limit.value == 166 and panel._capacity_dirty and panel.apply_info.text.contains("newer"),"late first-request acceptance cannot replace newer typed capacity")
	find_button(panel,"Apply capacity").pressed.emit()
	panel.set_sandbox_state({"preparing":true})
	panel.set_sandbox_state({"preparing":false,"capacity":signals_seen.capacity.duplicate(true)})
	check(panel.logical_limit.value == 166 and not panel._capacity_dirty,"reapplying newer capacity accepts without lost updates")
	panel.placement_x.value = 222.25
	panel.placement_y.value = 333.5
	panel.placement_angle.value = -45.25
	panel.refresh()
	check(panel.placement_x.value == 222.25,"live roster refresh preserves uncommitted precision values")
	find_button(panel,"Apply authored placement (paused)").pressed.emit()
	check(signals_seen.placement == [1,Vector2(222.25,333.5),-45.25],"authored placement request includes full precision and orientation")
	check(panel._placement_dirty,"placement Apply remains staged before owner acknowledgement")
	wb.message = "Preparing #1 placement once."
	panel.set_sandbox_state({"preparing":true})
	check(panel.apply_info.text.contains("Pending"),"placement preparation is not completed installation")
	wb.applied.actors[0].spawn = [222.25,333.5]
	wb.applied.actors[0].spawn_rotation_degrees = -45.25
	panel.set_sandbox_state({"preparing":false})
	panel.refresh()
	check(not panel._placement_dirty and panel.apply_info.text.contains("Accepted"),"exact authored placement accepted with full position and angle precision")
	check(panel._same_values({"x":500.25,"y":420.5,"angle":180.0},
		{"x":500.25,"y":420.5,"angle":-180.0}),
		"+180 and -180 are the same committed assembly heading")
	check(not panel._same_values({"x":16000.25,"y":420.5,"angle":45.0},
		{"x":16000.0,"y":420.5,"angle":45.0}),
		"large-canvas placement still enforces exact quarter-cell precision")
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
	# Controlled refusal cases: the real Workbench lifecycle is exercised by
	# test_workbench_actor_configuration_native.gd, not inferred from these mocks.
	panel.set_sandbox_state({"preparing":false,"capacity":{"version":1,"logical_limit":64,
		"body_limit":128,"proxy_limit":128,"actors":64}})
	wb.message = "Ready."
	panel.capacity_requested.connect(func(value: Dictionary) -> void:
		if int(value.logical_limit) < 64: wb.refuse("64 installed barrels exceed requested capacity."))
	panel.logical_limit.value = 32
	find_button(panel,"Apply capacity").pressed.emit()
	panel.set_sandbox_state({"preparing":false,"capacity":{"version":1,"logical_limit":64,
		"body_limit":128,"proxy_limit":128,"actors":64}})
	panel.refresh()
	check(panel.logical_limit.value == 32 and panel._capacity_dirty,"rejected 64-to-32 capacity stays visibly staged after refresh")
	check(panel.apply_info.text.contains("Refused") and panel.apply_info.text.contains("retained"),"rejected capacity is visibly acknowledged as a refusal")
	panel.tuning_requested.connect(func(_id: int,options: Dictionary) -> void:
		if is_equal_approx(float(options.mass_multiplier),1.75): wb.refuse("Changed equipment topology requires Reset."))
	panel.tuning.mass_multiplier.value = 1.75
	find_button(panel,"Apply actor tuning / restart").pressed.emit()
	panel.refresh()
	check(panel.tuning.mass_multiplier.value == 1.75 and panel._tuning_dirty and panel.apply_info.text.contains("Refused"),
		"denied physical tuning retains staged value and explicit topology refusal")
	wb.applied.actors.append({"id":2,"model":"runner","spawn":[420.0,430.0],
		"spawn_rotation_degrees":5.0,"options":{"mass_multiplier":2.0},
		"control":Catalog.default_control("runner")})
	panel.tuning.mass_multiplier.value = 1.8
	find_button(panel,"Apply actor tuning / restart").pressed.emit()
	panel.placement_x.value = 340.25
	wb.select_instance(2)
	panel.refresh()
	check(panel._apply_requests.tuning.phase == "invalidated","pending first-actor Apply invalidates explicitly on inspection change")
	check(panel.placement_x.value == 420.0 and panel.tuning.mass_multiplier.value == 2.0,
		"staged fields from actor #1 never silently apply to inspected actor #2")
	check(wb.pilot_transfers == 0 and wb.pause_calls == 0 and not wb.host.paused,
		"refusals, pending acknowledgements and inspector switches never transfer pilot or pause Play")
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
