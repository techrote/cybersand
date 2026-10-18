extends SceneTree

const SceneRecipe = preload("res://scripts/neon_reliquary.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const TICKS: int = 120

var assertions: int = 0
var failures: int = 0


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
		push_error("Neon Reliquary regression requires the native demo classes")
		quit(1)
		return
	var checked: Dictionary = _contract_checks()
	if not checked.get("ok", false):
		quit(1)
		return
	_native_checks(checked.definition)
	await _desktop_lifecycle(checked.definition)
	await _web_lifecycle(checked.definition)
	print("NEON_RELIQUARY: %d assertions; %d failures; native material progression=%d ticks/1 worker, desktop and synchronous Web-controller lifecycle" % [assertions, failures, TICKS])
	print("NEON_RELIQUARY_IDENTITY: %d setup records; definition_sha256=%s" % [checked.definition.rectangles.size() / 5, checked.hash])
	quit(1 if failures else 0)


func _contract_checks() -> Dictionary:
	var recipe: PackedInt32Array = SceneRecipe.rectangles()
	expect(not recipe.is_empty() and recipe == SceneRecipe.rectangles(),
		"showcase construction is empty or nondeterministic")
	expect(CyberDemoWorlds.valid_id(SceneRecipe.ID)
		and CyberDemoWorlds.rectangles(SceneRecipe.ID) == recipe
		and CyberDemoWorlds.spawn(SceneRecipe.ID) == SceneRecipe.spawn(),
		"ordinary demo catalogue does not resolve the shared showcase recipe")
	expect(SceneRecipe.SCENARIO_ID in CyberMicroScenarioCatalogue.ids(),
		"showcase is missing from the shared MicroScenario catalogue")
	var definition: Dictionary = CyberMicroScenarioCatalogue.definition(SceneRecipe.SCENARIO_ID)
	var checked: Dictionary = Contract.validate(definition)
	expect(checked.get("ok", false), str(checked.get("error", "invalid showcase definition")))
	if not checked.get("ok", false): return checked
	expect(int(definition.schema_version) == 2
		and PackedInt32Array(definition.rectangles) == recipe,
		"showcase is not a schema-2 definition of the shared native recipe")
	var parsed: Dictionary = Contract.parse(str(checked.canonical_json))
	expect(parsed.get("ok", false) and parsed.get("hash", "") == checked.hash,
		"showcase definition loses identity through canonical JSON")
	var area: int = 0
	for offset: int in range(0, recipe.size(), 5):
		area += recipe[offset + 2] * recipe[offset + 3]
	expect(recipe.size() / 5 <= Contract.MAX_RECORDS
		and area <= 8 * Contract.SIDE * Contract.SIDE,
		"showcase exceeds the retained setup record/write-area budgets")
	var views: Array[Dictionary] = SceneRecipe.viewpoints()
	expect(views.size() >= 3, "showcase is missing its overview and detail framings")
	for view: Dictionary in views:
		var frame := Rect2(Vector2(view.origin), Vector2(view.size))
		expect(not str(view.name).is_empty() and frame.size.x > 0 and frame.size.y > 0
			and Rect2(0, 0, Contract.SIDE, Contract.SIDE).encloses(frame),
			"showcase framing is unnamed or outside the native world")
	return checked


func _native_checks(definition: Dictionary) -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var host: CyberMicroScenarioHost = Host.new()
	if not bridge.build_world(world, SceneRecipe.rectangles()):
		expect(false, "native showcase construction failed: " + str(bridge.get_last_error()))
		return
	var original: PackedByteArray = bridge.export_level(world)
	expect(original.size() == CyberDemoSaveCodec.WORLD_BYTES, "native showcase snapshot is incomplete")
	expect(not bridge.build_world(world, PackedInt32Array([1024, 0, 1, 1, 2]))
		and bridge.export_level(world) == original,
		"invalid native replacement changed the existing showcase")
	if not host.install(world, definition, "Inspect", false):
		expect(false, "shared host refused the showcase: " + host.last_error)
		return
	expect(int(world.get_tick_index()) == 0 and int(world.get_worker_threads()) == 1,
		"showcase did not install at tick zero with the requested worker identity")
	expect(bridge.export_level(world) == original,
		"shared host and ordinary demo construct different initial material states")
	_safe_spawn(world)
	_landmarks(world)

	# A rejected definition must preserve both the World and installed host cursor.
	var before: Dictionary = host.summary()
	var invalid: Dictionary = definition.duplicate(true)
	invalid.rectangles[0] = -1
	expect(not host.install(world, invalid), "invalid showcase definition was admitted")
	expect(bridge.export_level(world) == original
		and host.summary().definition_hash == before.definition_hash
		and host.summary().completed_tick == before.completed_tick
		and host.summary().events_applied == before.events_applied,
		"rejected showcase definition changed cells or active host state")

	# This is native material progression only. The real character/scene owners
	# are exercised below; this loop does not stand in for interactive parity.
	var progressed: bool = true
	for tick: int in range(TICKS):
		if not host.advance():
			progressed = false
			break
	expect(progressed and not world.has_failed() and int(world.get_tick_index()) == TICKS,
		"bounded showcase material progression failed: " + host.last_error)
	var stats: Dictionary = bridge.inspect_statistics(world)
	expect(stats.get("ok", false), "showcase has no successful native statistics")
	if stats.get("ok", false):
		expect(int(stats["values"].resident_chunks) <= int(stats.limits.maximum_chunks)
			and int(stats["values"].active_chunks) <= int(stats.limits.active_chunks)
			and int(stats["values"].scheduled_cores) <= int(stats.limits.active_cores),
			"showcase escaped the configured native storage/scheduler capacity")
	expect(host.install(world, definition, "Inspect", false), "fresh showcase reset failed")
	expect(int(world.get_tick_index()) == 0 and bridge.export_level(world) == original,
		"fresh showcase reset did not restore the exact initial material bytes")
	_safe_spawn(world)


func _safe_spawn(world: Variant) -> void:
	var spawn: Vector2 = SceneRecipe.spawn()
	expect(not world.character_box_collides(spawn, CyberSampledCharacter.BODY_SIZE, 0),
		"showcase player starts intersecting authored terrain")
	var nearby_support: bool = false
	for offset: int in range(1, 17):
		if world.character_box_collides(spawn + Vector2(0, offset), CyberSampledCharacter.BODY_SIZE, 1):
			nearby_support = true
			break
	expect(nearby_support, "showcase player starts over an unsupported drop")


func _landmarks(world: Variant) -> void:
	# Semantic composition anchors, not an inventory of every decorative stripe.
	expect(int(world.material_at(512, 216)) == 80, "central light shaft is missing")
	expect(int(world.material_at(594, 216)) == 77, "cyan halo is missing")
	expect(int(world.material_at(360, 490)) == 3, "lower cistern has no authored Water")
	expect(int(world.material_at(360, 506)) == 58, "lower cistern containment is missing")


func _desktop_lifecycle(definition: Dictionary) -> void:
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	var presentation: CyberShowcasePresentation = desktop.showcase_presentation
	expect(not presentation.active() and not presentation.frame_view(0),
		"showcase framing is active before scene installation")
	expect(presentation.launch(), "desktop showcase launcher refused the scene")
	var installed: bool = await wait_for(func() -> bool:
		return (desktop.pending_microscenario_apply.is_empty() and presentation.active()
			and desktop.latest_snapshot != null and desktop.latest_snapshot.paused))
	expect(installed, "desktop showcase installation did not acknowledge")
	if installed:
		var original_tick: int = desktop.latest_snapshot.tick_index
		var original_revision: int = desktop.latest_snapshot.simulation_world_revision
		var original_cells: PackedByteArray = desktop.texture.get_image().get_data()
		expect(desktop.paused and original_tick == 0, "desktop showcase did not begin paused at tick zero")
		_check_framing(desktop, presentation)
		await create_timer(0.1).timeout
		expect(desktop.latest_snapshot.tick_index == original_tick
			and desktop.latest_snapshot.simulation_world_revision == original_revision
			and desktop.texture.get_image().get_data() == original_cells,
			"desktop presentation controls altered the paused native publication")
		var invalid: Dictionary = definition.duplicate(true)
		invalid.rectangles[0] = -1
		expect(not desktop.microscenario_apply_definition(invalid)
			and presentation.active() and desktop.microscenario_definition.id == SceneRecipe.SCENARIO_ID,
			"desktop rejected definition displaced the active showcase")
		expect(desktop.tower_command({"step": true}), "desktop showcase refused single-step")
		expect(await wait_for(func() -> bool: return desktop.latest_snapshot.tick_index == 1),
			"desktop showcase single-step did not complete")
		expect(desktop.paused and not desktop.latest_snapshot.simulation_failed,
			"desktop showcase single-step lost pause or quarantined the World")
		desktop.microscenario_reset()
		expect(await wait_for(func() -> bool:
			return (desktop.pending_microscenario_apply.is_empty() and presentation.active()
				and desktop.latest_snapshot.tick_index == 0)), "desktop showcase reset did not acknowledge")
		expect(desktop.texture.get_image().get_data() == original_cells,
			"desktop fresh reset did not publish the original material bytes")
		expect(desktop.current_view_size == SceneRecipe.viewpoints()[0].size
			and desktop.camera_origin == SceneRecipe.viewpoints()[0].origin,
			"desktop fresh reset did not restore the authored overview")
		desktop.tower_reset()
		expect(not presentation.launch(), "showcase launcher overwrote a pending Tower reset")
		expect(await wait_for(func() -> bool: return not presentation.active()),
			"desktop could not leave the showcase for Experiment Tower")
		presentation.refresh()
		expect(not presentation.overlay.visible and not presentation.view_picker.visible,
			"desktop showcase atmosphere or framing controls leaked into Experiment Tower")
	desktop.simulation_worker.stop_worker()
	desktop.rapier_bridge.shutdown()
	desktop.queue_free()
	await process_frame


func _web_lifecycle(definition: Dictionary) -> void:
	var web: Control = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	await process_frame
	web.focused = true
	web.ui.close_menu()
	web.select_demo(SceneRecipe.ID)
	var presentation: CyberShowcasePresentation = web.showcase_presentation
	expect(web.ready_to_play and presentation.active() and web.demo_id == SceneRecipe.ID,
		"Web demo selection did not install the shared showcase")
	if presentation.active():
		var original: PackedByteArray = web.demo_bridge.export_level(web.native_world)
		expect(web.paused and int(web.native_world.get_tick_index()) == 0,
			"Web showcase did not begin paused at tick zero")
		_check_framing(web, presentation)
		await create_timer(0.1).timeout
		expect(int(web.native_world.get_tick_index()) == 0
			and web.demo_bridge.export_level(web.native_world) == original,
			"Web presentation controls changed paused native material state")
		var invalid: Dictionary = definition.duplicate(true)
		invalid.rectangles[0] = -1
		expect(not web.microscenario_apply_definition(invalid)
			and presentation.active() and web.demo_bridge.export_level(web.native_world) == original,
			"Web rejected definition changed the active showcase")
		expect(web.tower_command({"step": true}), "Web showcase refused single-step")
		expect(await wait_for(func() -> bool: return int(web.native_world.get_tick_index()) == 1),
			"Web showcase single-step did not complete")
		expect(web.paused and not web.native_world.has_failed(),
			"Web showcase single-step lost pause or quarantined the World")
		web.microscenario_reset()
		expect(presentation.active() and web.paused
			and int(web.native_world.get_tick_index()) == 0
			and web.demo_bridge.export_level(web.native_world) == original,
			"Web fresh reset did not retain the exact authored showcase")
		expect(web.current_view_size == SceneRecipe.viewpoints()[0].size
			and web.camera_origin == SceneRecipe.viewpoints()[0].origin,
			"Web fresh reset did not restore the authored overview")
		web.select_demo("neon_works")
		presentation.refresh()
		expect(not presentation.active() and not presentation.overlay.visible
			and not presentation.view_picker.visible,
			"Web showcase atmosphere or framing controls leaked into an ordinary demo")
		expect(web.current_view_size == [Vector2i(320, 180), Vector2i(480, 270), Vector2i(640, 360)][web.quality],
			"Web ordinary demo retained the showcase camera size instead of its quality preset")
	web.rapier_bridge.shutdown()
	web.queue_free()
	await process_frame


func _check_framing(controller: Control, presentation: CyberShowcasePresentation) -> void:
	var views: Array[Dictionary] = SceneRecipe.viewpoints()
	for index: int in range(views.size()):
		expect(presentation.frame_view(index)
			and controller.current_view_size == views[index].size
			and controller.camera_origin == views[index].origin
			and not controller.camera_follow_enabled,
			"showcase viewpoint did not frame its authored region")
	var retained_origin: Vector2 = controller.camera_origin
	expect(not presentation.frame_view(-1) and not presentation.frame_view(views.size())
		and controller.camera_origin == retained_origin,
		"invalid showcase viewpoint changed the camera")
	presentation.refresh()
	expect(presentation.overlay.visible and presentation.view_picker.visible,
		"active showcase did not expose its atmosphere and framing controls")
	var popup: PopupMenu = presentation.view_picker.get_popup()
	popup.popup()
	expect(presentation.input_blocked(), "viewpoint popup did not block gameplay pointer input")
	popup.hide()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse.position = Vector2(-100, -100)
	mouse.global_position = mouse.position
	mouse.pressed = true
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	expect(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"pointer fixture did not establish a held left button")
	presentation.frame_view(1)
	expect(presentation.input_blocked(), "viewpoint selection admitted a still-held mouse button")
	mouse = mouse.duplicate()
	mouse.pressed = false
	mouse.button_mask = 0
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	expect(not presentation.input_blocked(), "viewpoint pointer input did not rearm after release")
	controller.microscenario_panel._open_definition()
	expect(controller.microscenario_panel.modal_open() and not presentation.launch(),
		"showcase shortcut bypassed an open definition editor")
	controller.microscenario_panel.definition_dialog.hide()
	controller.microscenario_toggle_hud()
	presentation.refresh()
	expect(not presentation.controls.visible and presentation.overlay.visible,
		"clean view hid the scene atmosphere or retained showcase controls")
	if controller.player_environment_button != null:
		expect(not controller.player_environment_button.visible,
			"clean view retained the player/environment launcher")
	controller.microscenario_toggle_hud()
	presentation.atmosphere_button.button_pressed = false
	presentation.refresh()
	expect(not presentation.overlay.visible, "distant-city toggle did not hide the atmosphere")
	presentation.atmosphere_button.button_pressed = true
	presentation.refresh()
	expect(presentation.controls.visible and presentation.overlay.visible,
		"showcase controls or atmosphere did not restore")
