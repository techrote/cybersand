extends SceneTree

const Tiles = preload("res://scripts/showcase_tiles.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const IDS: Array[String] = ["neon_reliquary", "middle_cyberberbia", "sewertech_alley", "industrial_underswamp"]
const SCENARIOS: Array[String] = ["showcase/neon-reliquary", "showcase/middle-cyberberbia", "showcase/sewertech-alley", "showcase/industrial-underswamp"]
const TITLES: Array[String] = ["Neon Reliquary", "Middle Cyberberbia", "Sewertech Alley", "Industrial Underswamp"]
const TICKS: int = 120

var assertions: int = 0
var failures: int = 0
var evidence: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)


func wait_for(predicate: Callable, timeout_ms: int = 20000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	root.size = Vector2i(1600, 900)
	if not CyberWebCapabilities.native_available():
		expect(false, "Four-district regression requires the native demo classes")
		_finish()
		return
	var checked: Array[Dictionary] = _contract_checks()
	if checked.size() == IDS.size():
		for index: int in range(1, IDS.size()):
			_native_new_tile(index, checked[index].definition)
		await _desktop_transitions(checked)
		await _web_transitions(checked)
	_finish()


func _finish() -> void:
	print("SHOWCASE_TILES_IDENTITY: " + JSON.stringify(evidence))
	print("SHOWCASE_TILES: %d assertions; %d failures; new-district native material progression=%d ticks/1 worker; desktop asynchronous and synchronous Web-controller transitions" % [assertions, failures, TICKS])
	quit(1 if failures else 0)


func _contract_checks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	expect(Tiles.RECIPES.size() == 4 and Tiles.scenario_ids() == SCENARIOS,
		"District order must be Neon Reliquary, Middle Cyberberbia, Sewertech Alley, Industrial Underswamp")
	var identities: Dictionary = {}
	var hashes: Dictionary = {}
	for index: int in range(IDS.size()):
		var source: GDScript = Tiles.recipe(IDS[index])
		expect(source != null, "Missing district recipe: " + IDS[index])
		if source == null: continue
		expect(source.ID == IDS[index] and source.SCENARIO_ID == SCENARIOS[index]
			and source.TITLE == TITLES[index] and int(source.VERSION) == 1
			and Tiles.index_of(IDS[index]) == index and Tiles.index_of(SCENARIOS[index]) == index
			and Tiles.stack_position(IDS[index]) == Vector2i(0, index),
			"District identity or vertical position does not match the requested order: " + IDS[index])
		identities[source.ID] = true
		identities[source.SCENARIO_ID] = true
		var recipe: PackedInt32Array = source.rectangles()
		expect(not recipe.is_empty() and recipe == source.rectangles()
			and CyberDemoWorlds.valid_id(IDS[index])
			and CyberDemoWorlds.rectangles(IDS[index]) == recipe
			and CyberDemoWorlds.spawn(IDS[index]) == source.spawn()
			and SCENARIOS[index] in CyberMicroScenarioCatalogue.ids(),
			"District construction is nondeterministic or missing from a shared catalogue: " + IDS[index])
		var definition: Dictionary = CyberMicroScenarioCatalogue.definition(SCENARIOS[index])
		var checked: Dictionary = Contract.validate(definition)
		expect(checked.get("ok", false), IDS[index] + ": " + str(checked.get("error", "invalid schema")))
		if not checked.get("ok", false): continue
		result.append(checked)
		hashes[checked.hash] = true
		var parsed: Dictionary = Contract.parse(str(checked.canonical_json))
		var invalid: Dictionary = definition.duplicate(true)
		invalid["unowned_scene_state"] = true
		expect(int(definition.schema_version) == 2 and definition.id == SCENARIOS[index]
			and definition.presentation.title == TITLES[index]
			and PackedInt32Array(definition.rectangles) == recipe
			and parsed.get("ok", false) and parsed.get("hash", "") == checked.hash
			and parsed.get("canonical_json", "") == checked.canonical_json
			and not Contract.validate(invalid).get("ok", false),
			"District schema is not strict or canonical identity is unstable: " + IDS[index])
		var metrics: Dictionary = _recipe_metrics(recipe)
		expect(metrics.valid and int(metrics.records) <= Contract.MAX_RECORDS
			and int(metrics.area) <= 8 * Contract.SIDE * Contract.SIDE
			and str(checked.canonical_json).to_utf8_buffer().size() <= Contract.MAX_JSON_BYTES,
			"District exceeded native bounds, setup records, write area or JSON capacity: " + IDS[index])
		expect(definition.transport_profile == Contract.base("test/baseline").transport_profile
			and definition.water_semantics == [1, 8, 12, 0]
			and definition.interest == {"policy": "fixed", "region": [32, 16, 960, 540]}
			and definition.execution.policy == "owner" and definition.player_enabled
			and not definition.body_enabled and definition.tools == ["paint", "erase", "player"]
			and definition.events.is_empty() and definition.observations.is_empty()
			and definition.conditions.is_empty(),
			"District changed the ordinary native policies or admitted extra scene mechanics: " + IDS[index])
		var views: Array[Dictionary] = source.viewpoints()
		var valid_views: bool = views.size() == 5
		var names: Dictionary = {}
		var origins: Dictionary = {}
		for view_index: int in range(views.size()):
			var view: Dictionary = views[view_index]
			var frame := Rect2(Vector2(view.origin), Vector2(view.size))
			valid_views = valid_views and not str(view.name).is_empty()
			valid_views = valid_views and Rect2(0, 0, 1024, 1024).encloses(frame)
			valid_views = valid_views and view.size == (Vector2i(960, 540) if view_index == 0 else Vector2i(480, 270))
			if view_index == 0: valid_views = valid_views and view.origin == Vector2(32, 16)
			names[view.name] = true
			origins[view.origin] = true
		expect(valid_views and names.size() == 5 and origins.size() == 5,
			"District must have one bounded overview and four distinct named detail views: " + IDS[index])
		evidence.append({"id": IDS[index], "records": metrics.records, "area": metrics.area,
			"materials": metrics.materials, "canonical_sha256": checked.hash})
	expect(identities.size() == 8 and hashes.size() == 4,
		"District identities or canonical definitions are not unique")
	expect(not Tiles.contains("showcase/missing") and Tiles.recipe("missing") == null
		and Tiles.definition("missing").is_empty() and Tiles.viewpoints("missing").is_empty()
		and Tiles.stack_position("missing") == Vector2i(-1, -1),
		"Unknown district resolves to a valid tile")
	return result


func _recipe_metrics(recipe: PackedInt32Array) -> Dictionary:
	var valid: bool = not recipe.is_empty() and recipe.size() % 5 == 0
	var area: int = 0
	var materials: Dictionary = {}
	for offset: int in range(0, recipe.size() - 4, 5):
		var x: int = recipe[offset]
		var y: int = recipe[offset + 1]
		var width: int = recipe[offset + 2]
		var height: int = recipe[offset + 3]
		var material: int = recipe[offset + 4]
		valid = valid and x >= 0 and y >= 0 and width > 0 and height > 0
		valid = valid and x + width <= 1024 and y + height <= 1024
		valid = valid and material >= 0 and material < Contract.MATERIAL_COUNT
		area += width * height
		materials[material] = true
	return {"valid": valid, "records": recipe.size() / 5, "area": area, "materials": materials.size()}


func _native_new_tile(index: int, definition: Dictionary) -> void:
	var source: GDScript = Tiles.recipe(IDS[index])
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var host: CyberMicroScenarioHost = Host.new()
	var built: bool = bridge.build_world(world, source.rectangles())
	expect(built, "Native district construction failed: " + IDS[index])
	if not built: return
	var original: PackedByteArray = bridge.export_level(world)
	var installed: bool = host.install(world, definition, "Inspect", false)
	expect(installed and original.size() == CyberDemoSaveCodec.WORLD_BYTES
		and bridge.export_level(world) == original and int(world.get_tick_index()) == 0
		and int(world.get_worker_threads()) == 1,
		"Native host changed authored cells or initial worker/tick identity: " + IDS[index])
	if not installed: return
	var landmarks: Array[Dictionary] = source.landmarks()
	expect(landmarks.size() >= 3 and landmarks.size() <= 5,
		"New district lacks a bounded set of semantic landmarks: " + IDS[index])
	for landmark: Dictionary in landmarks:
		var point: Vector2i = landmark.point
		expect(Rect2i(0, 0, 1024, 1024).has_point(point)
			and int(world.material_at(point.x, point.y)) == int(landmark.material),
			"Native district landmark disagrees at %s: %s" % [point, IDS[index]])
	var spawn: Vector2 = source.spawn()
	var supported: bool = false
	for offset: int in range(1, 17):
		if world.character_box_collides(spawn + Vector2(0, offset), CyberSampledCharacter.BODY_SIZE, 1):
			supported = true
			break
	expect(not world.character_box_collides(spawn, CyberSampledCharacter.BODY_SIZE, 0) and supported,
		"New district player spawn is obstructed or lacks nearby native support: " + IDS[index])

	# Native material progression only; the two actual interactive owners are
	# exercised separately below, without reading the desktop worker's World.
	var progressed: bool = true
	for tick: int in range(TICKS):
		if not host.advance():
			progressed = false
			break
	expect(progressed and not world.has_failed() and int(world.get_tick_index()) == TICKS,
		"New district failed 120 native ticks: %s / %s" % [IDS[index], host.last_error])
	var progressed_cells: PackedByteArray = bridge.export_level(world)
	var before: Dictionary = _host_cursor(host.summary())
	var invalid: Dictionary = definition.duplicate(true)
	invalid.rectangles[0] = -1
	expect(not bridge.build_world(world, PackedInt32Array([1024, 0, 1, 1, 2]))
		and not host.install(world, invalid)
		and bridge.export_level(world) == progressed_cells and _host_cursor(host.summary()) == before,
		"Rejected replacement changed progressed native cells or the host cursor: " + IDS[index])
	expect(host.install(world, definition, "Inspect", false)
		and int(world.get_tick_index()) == 0 and bridge.export_level(world) == original,
		"New district reset did not restore exact authored native bytes: " + IDS[index])


func _host_cursor(summary: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["id", "definition_hash", "completed_tick", "events_applied", "observations", "outcome", "failed"]:
		result[key] = summary.get(key)
	return result


func _desktop_transitions(checked: Array[Dictionary]) -> void:
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	var presentation: CyberShowcasePresentation = desktop.showcase_presentation
	desktop.toggle_actor_prototypes()
	expect(desktop.actor_prototype_panel.visible and not presentation.launch(IDS[0])
		and desktop.pending_microscenario_apply.is_empty(),
		"District launch replaced the world while the actor selector owned input")
	desktop.update_brush_preview()
	expect(not desktop.brush_preview.visible, "Actor selector left the world brush preview visible")
	desktop.microscenario_toggle_hud()
	expect(not desktop.actor_prototype_button.visible and not desktop.actor_prototype_panel.visible,
		"Clean view left the actor launcher or selector visible")
	desktop.microscenario_toggle_hud()
	expect(desktop.actor_prototype_button.visible, "Leaving clean view did not restore the actor launcher")
	expect(desktop.apply_actor_prototype_configuration(&"runner", &"human", false)
		and desktop._actor_reset_receipt != 0 and not presentation.launch(IDS[0])
		and desktop.pending_microscenario_apply.is_empty(),
		"District launch replaced a pending actor installation")
	expect(await wait_for(func() -> bool:
		return (desktop._actor_reset_receipt == 0 and desktop.latest_snapshot != null
			and not desktop.latest_snapshot.actor_prototypes.is_empty())),
		"The ordinary sandbox did not acknowledge its actor installation")
	for index: int in range(IDS.size()):
		var previous: Dictionary = _presentation_state(desktop, presentation)
		var accepted: bool = false
		if index == 0:
			accepted = presentation.launch(IDS[index])
		elif index == 1:
			# Exercise the real OptionButton signal, including its provisional selection.
			presentation.tile_picker.select(index)
			presentation.tile_picker.item_selected.emit(index)
			accepted = not desktop.pending_microscenario_apply.is_empty()
		else:
			accepted = presentation.move_tile(1)
		expect(accepted and desktop.pending_microscenario_apply.get("hash", "") == checked[index].hash,
			"Desktop did not queue the requested district: " + IDS[index])
		expect(_presentation_state(desktop, presentation) == previous,
			"Desktop advertised title, district or viewpoint before owner acceptance: " + IDS[index])
		var pending: Dictionary = desktop.pending_microscenario_apply.duplicate(true)
		expect(not presentation.launch(IDS[(index + 1) % IDS.size()])
			and not presentation.launch("showcase/missing")
			and desktop.pending_microscenario_apply == pending
			and _presentation_state(desktop, presentation) == previous,
			"Another district request replaced a pending desktop install")
		var installed: bool = await _wait_desktop_district(desktop, presentation, index)
		expect(installed, "Desktop district install did not acknowledge: " + IDS[index])
		if not installed: break
		_check_accepted_view(desktop, presentation, index)
		if index == 0:
			expect(desktop.latest_snapshot.actor_prototypes.is_empty()
				and desktop.actor_model_selection == &"",
				"Accepted showcase district retained ordinary sandbox actor ownership")
			desktop.microscenario_toggle_hud()
			await process_frame
			expect(not desktop.actor_prototype_button.visible and not presentation.controls.visible,
				"The actor launcher or scene controls remained in a clean showcase view")
			desktop.microscenario_toggle_hud()
		expect(desktop.paused and desktop.latest_snapshot.paused
			and desktop.latest_snapshot.tick_index == 0 and not desktop.latest_snapshot.simulation_failed,
			"Desktop district did not begin paused at tick zero: " + IDS[index])
		await _neutral_controls(desktop, presentation, false)
		if index == 0: _endpoint(desktop, presentation, -1, false)
		if index == IDS.size() - 1: _endpoint(desktop, presentation, 1, false)
	if presentation.current_scenario_id() == SCENARIOS.back():
		await _district_pointer_guard(desktop, presentation, false)
		expect(presentation.move_tile(-1), "Desktop Above navigation refused the preceding district")
		expect(await _wait_desktop_district(desktop, presentation, 2),
			"Desktop Above navigation did not return to Sewertech Alley")
		_check_accepted_view(desktop, presentation, 2)
		desktop.tower_reset()
		expect(not presentation.launch(IDS[1]), "District launch overwrote an ordinary Tower reset")
		expect(await wait_for(func() -> bool: return not presentation.active()),
			"Desktop could not return to ordinary Experiment Tower")
		presentation.refresh()
		expect(not presentation.tile_picker.visible and not presentation.up_button.visible
			and not presentation.down_button.visible and not presentation.view_picker.visible
			and not presentation.overlay.visible,
			"District navigation or atmosphere leaked into desktop Experiment Tower")
	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame


func _wait_desktop_district(desktop: Control, presentation: CyberShowcasePresentation, index: int) -> bool:
	return await wait_for(func() -> bool:
		return (desktop.pending_microscenario_apply.is_empty()
			and presentation.current_scenario_id() == SCENARIOS[index]
			and desktop.latest_snapshot != null and desktop.latest_snapshot.paused
			and desktop.latest_snapshot.tick_index == 0))


func _web_transitions(checked: Array[Dictionary]) -> void:
	var web: Control = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	await process_frame
	web.focused = true
	web.ui.close_menu()
	var presentation: CyberShowcasePresentation = web.showcase_presentation
	expect(web.ready_to_play and web.set_quality(2), "Web controller did not initialize its ordinary quality preset")
	for index: int in range(IDS.size()):
		if index == 0:
			web.select_demo(IDS[index])
		elif index == 1:
			presentation.tile_picker.select(index)
			presentation.tile_picker.item_selected.emit(index)
		else:
			expect(presentation.move_tile(1), "Web Below navigation refused: " + IDS[index])
		expect(presentation.current_scenario_id() == SCENARIOS[index] and web.demo_id == IDS[index]
			and web.pending_microscenario_apply.is_empty()
			and web.micro_host.summary().definition_hash == checked[index].hash,
			"Synchronous Web selection did not publish the accepted district: " + IDS[index])
		_check_accepted_view(web, presentation, index)
		expect(web.paused and int(web.native_world.get_tick_index()) == 0 and not web.native_world.has_failed(),
			"Web district did not begin paused at tick zero: " + IDS[index])
		await _neutral_controls(web, presentation, true)
		if index == 0: _endpoint(web, presentation, -1, true)
		if index == IDS.size() - 1: _endpoint(web, presentation, 1, true)
	if presentation.current_scenario_id() == SCENARIOS.back():
		await _district_pointer_guard(web, presentation, true)
		expect(presentation.move_tile(-1) and presentation.current_scenario_id() == SCENARIOS[2],
			"Web Above navigation did not synchronously return to Sewertech Alley")
		_check_accepted_view(web, presentation, 2)
		web.select_demo("neon_works")
		presentation.refresh()
		expect(web.demo_id == "neon_works" and not presentation.active()
			and not presentation.tile_picker.visible and not presentation.up_button.visible
			and not presentation.down_button.visible and not presentation.view_picker.visible
			and not presentation.overlay.visible,
			"District navigation or atmosphere leaked into an ordinary Web demo")
		expect(web.quality == 2 and web.current_view_size == Vector2i(640, 360)
			and web.simulation_margin == Vector2i(64, 72) and web.render_snapshot_hz == 60
			and web.camera_origin == Vector2.ZERO and not web.paused,
			"Ordinary Web demo did not restore its quality, camera and running state")
	web.rapier_bridge.shutdown()
	web.queue_free()
	await process_frame


func _presentation_state(controller: Control, presentation: CyberShowcasePresentation) -> Dictionary:
	var names: Array[String] = []
	for index: int in range(presentation.view_picker.item_count):
		names.append(presentation.view_picker.get_item_text(index))
	return {"id": presentation.current_scenario_id(), "title": controller.get_node("Layout/Title").text,
		"district": presentation.tile_picker.selected, "view": presentation.selected_view,
		"views": names, "origin": controller.camera_origin, "size": controller.current_view_size}


func _check_accepted_view(controller: Control, presentation: CyberShowcasePresentation, index: int) -> void:
	presentation.refresh()
	var state: Dictionary = _presentation_state(controller, presentation)
	var names: Array[String] = []
	for view: Dictionary in Tiles.viewpoints(IDS[index]): names.append(str(view.name))
	expect(state.id == SCENARIOS[index] and state.title == "CYBERSAND / " + TITLES[index].to_upper()
		and state.district == index and state.view == 0 and state.views == names
		and state.origin == Vector2(32, 16) and state.size == Vector2i(960, 540)
		and not controller.camera_follow_enabled,
		"Accepted district did not update its title, selector and overview together: " + IDS[index])
	expect(presentation.tile_picker.visible and presentation.up_button.visible
		and presentation.down_button.visible and presentation.view_picker.visible
		and presentation.up_button.disabled == (index == 0)
		and presentation.down_button.disabled == (index == IDS.size() - 1),
		"Accepted district exposed the wrong navigation endpoints: " + IDS[index])


func _cells(controller: Control, web: bool) -> PackedByteArray:
	if web: return controller.demo_bridge.export_level(controller.native_world)
	# The main-thread CPU Image is assembled from accepted immutable native
	# patches. Dummy-renderer ImageTexture readback can retain its initial bytes.
	return controller.image.get_data()


func _tick(controller: Control, web: bool) -> int:
	return int(controller.native_world.get_tick_index()) if web else int(controller.latest_snapshot.tick_index)


func _neutral_controls(controller: Control, presentation: CyberShowcasePresentation, web: bool) -> void:
	var original: PackedByteArray = _cells(controller, web)
	var tick: int = _tick(controller, web)
	var views: Array[Dictionary] = Tiles.viewpoints(presentation.current_scenario_id())
	var framed: bool = true
	for index: int in range(1, views.size()):
		framed = presentation.frame_view(index) and framed
		framed = framed and controller.camera_origin == views[index].origin
		framed = framed and controller.current_view_size == views[index].size
	var retained: Dictionary = _presentation_state(controller, presentation)
	expect(framed and not presentation.frame_view(-1) and not presentation.frame_view(5)
		and _presentation_state(controller, presentation) == retained,
		"District detail framing is invalid or an invalid view displaced the camera")
	presentation.atmosphere_button.button_pressed = false
	presentation.refresh()
	expect(not presentation.overlay.visible, "District atmosphere toggle did not hide the backdrop")
	presentation.atmosphere_button.button_pressed = true
	presentation.refresh()
	expect(presentation.overlay.visible, "District atmosphere toggle did not restore the backdrop")
	expect(not presentation.launch("showcase/missing") and not presentation.move_tile(0)
		and not presentation.move_tile(2) and _presentation_state(controller, presentation) == retained,
		"Invalid district or direction changed accepted presentation state")
	await create_timer(0.1).timeout
	expect(controller.paused and _tick(controller, web) == tick and _cells(controller, web) == original,
		"District detail views, atmosphere or rejected navigation changed paused native cells")


func _endpoint(controller: Control, presentation: CyberShowcasePresentation, direction: int, web: bool) -> void:
	var state: Dictionary = _presentation_state(controller, presentation)
	var original: PackedByteArray = _cells(controller, web)
	expect(not presentation.move_tile(direction) and _presentation_state(controller, presentation) == state
		and _cells(controller, web) == original and controller.pending_microscenario_apply.is_empty(),
		"District Above/Below navigation wrapped beyond an endpoint")


func _mouse_at(controller: Control, point: Vector2i, pressed: bool) -> void:
	var content: Rect2 = controller.view_content_rect()
	var local: Vector2 = content.position + (Vector2(point) + Vector2(0.5, 0.5)
		- controller.camera_origin) / Vector2(controller.current_view_size) * content.size
	# Input events use window pixels; the project stretches a 1920x1080 logical
	# viewport into this test's 1600x900 window.
	var position: Vector2 = controller.get_viewport().get_screen_transform() \
		* controller.world_view.get_global_transform_with_canvas() * local
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	button.position = position
	button.global_position = position
	button.pressed = pressed
	Input.parse_input_event(button)
	Input.flush_buffered_events()


func _paint(controller: Control, web: bool) -> void:
	if web: controller._paint_pointer()
	else: controller.handle_painting()


func _district_pointer_guard(controller: Control, presentation: CyberShowcasePresentation, web: bool) -> void:
	presentation.frame_view(0)
	controller.set_brush_size(1)
	await process_frame
	var original: PackedByteArray = _cells(controller, web)
	var point := Vector2i(88, 511) # Known occupied dry landing in Industrial Underswamp.
	var popup: PopupMenu = presentation.tile_picker.get_popup()
	popup.popup()
	expect(popup.visible and presentation.input_blocked(), "District popup did not block gameplay pointer input")
	_mouse_at(controller, point, true)
	expect(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and presentation.input_blocked(),
		"District popup admitted a held erase gesture")
	_paint(controller, web)
	await create_timer(0.05).timeout
	expect(_cells(controller, web) == original, "Painting through an open district popup changed native cells")
	popup.hide()
	expect(presentation.input_blocked(), "Closing the district popup rearmed a still-held erase gesture")
	_paint(controller, web)
	await create_timer(0.05).timeout
	expect(_cells(controller, web) == original, "Closing the district popup painted before pointer release")
	_mouse_at(controller, point, false)
	expect(not presentation.input_blocked(), "District popup pointer guard did not rearm after release")
	# A positive erase control proves the blocked attempts used a real world
	# pointer and admitted tool, rather than silently pointing outside the view.
	_mouse_at(controller, point, true)
	_paint(controller, web)
	_mouse_at(controller, point, false)
	expect(await wait_for(func() -> bool: return _cells(controller, web) != original),
		"Released district popup did not admit a fresh native erase gesture")
	expect(_tick(controller, web) == 0 and controller.paused,
		"District pointer editing advanced the paused simulation")
	controller.microscenario_reset()
	var reset: bool = await wait_for(func() -> bool:
		return (controller.pending_microscenario_apply.is_empty()
			and presentation.current_scenario_id() == SCENARIOS.back()
			and _tick(controller, web) == 0 and _cells(controller, web) == original))
	expect(reset, "District reset did not remove the positive-control edit exactly")
