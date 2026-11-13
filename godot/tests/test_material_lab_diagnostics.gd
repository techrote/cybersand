extends SceneTree

# Real native owner, real copied cell values and real mounted controls. The
# synthetic body-mask regression tests this read-only adapter boundary; it
# does not claim an actor-enabled MicroScenario or Rapier desktop parity.
const Lab = preload("res://scripts/material_lab_experiment.gd")
var assertions: int = 0
var failures: int = 0
var capture_directory: String = ""
var capture_manifest: Dictionary = {}

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("MATERIAL_LAB_DIAGNOSTICS: " + message)

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="): capture_directory = argument.trim_prefix("--capture-output=")
	run.call_deferred()

func fixture() -> Dictionary:
	var definition: Dictionary = Lab.definition_for_pair(23,3,2,20)
	# Enclosed pair plus a real pair crossing the selected 64-cell core boundary.
	definition.rectangles = [218,128,6,5,1,220,130,1,1,23,317,128,6,5,1,319,130,1,1,23,
		238,128,6,5,1,240,130,1,1,22,241,130,1,1,9,
		258,128,6,5,1,260,130,1,1,35,261,130,1,1,8]
	definition.partial_water_fills = [221,130,1,1,173,0,320,130,1,1,255,0]
	definition.events = []
	return definition

func signature(experiment: RefCounted) -> Dictionary:
	return {"physical":experiment.world.get_physical_state_hash(),
		"revision":experiment.world.get_revision(),"tick":experiment.world.get_tick_index(),
		"cells":experiment.world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024))}

func check_owner(workers: int) -> void:
	var experiment := Lab.new()
	expect(not experiment.inspect_contact(Vector2i.ZERO,Vector2i.ONE).ok,"Closed contact owner refuses inspection")
	expect(experiment.start(fixture(),workers),"Actual controlled native fixture starts: " + experiment.last_error)
	if not experiment.active(): return
	var before: Dictionary = signature(experiment)
	var report: Dictionary = experiment.inspect_contact(Vector2i(220,130),Vector2i(221,130),0)
	expect(report.get("ok",false),"Owner accepts two stored-cell probes: " + str(report.get("error","")))
	if not report.get("ok",false):
		experiment.close()
		return
	expect(report.schema_id == "cybersand.material-lab.contact" and report.schema_version == 1,
		"Contact report has an explicit versioned value schema")
	expect(report.source.material == 23 and report.target.material == 3 and report.target.state_a == 173,
		"Report reads actual stored materials and partial Water state")
	expect(report.source.stored_temperature_raw == 200 and report.target.stored_temperature_raw == 200,
		"Stored temperature is actual native raw thermal storage")
	expect(report.source.visible_material == 23 and report.target.visible_material == 3
		and report.source.transient_body_id == 0 and report.target.transient_body_id == 0,
		"Unmasked visible contact matches storage through native readback")
	expect(report.source.scheduler.core_coordinate == [3,2] and report.source.scheduler.selected_core_included,
		"Actual native source core coordinates and selected inclusion are copied")
	expect(report.source.scheduler.last_applied_core_included == null,
		"Tick zero does not invent preceding completed-tick execution")
	expect(report.resolver.outcome == "selected_reaction" and report.resolver.probability_denominator == 256
		and report.resolver.probability_numerator == int(report.resolver.probability_threshold)+1,
		"Compiled resolver keeps exact threshold-plus-one probability")
	expect(report.world_eligibility == "unresolved" and report.blockers.is_empty() and not report.reaction_executed,
		"Selected native resolver result is never promoted to an executed or guaranteed World reaction")
	expect(report.source.unobserved.has("per-cell sleeping status")
		and report.source.unobserved.has("activity-block active flag and future wake deadline"),
		"Unpublished sleep and wake values remain explicitly unobserved")
	for repeat: int in range(8):
		expect(experiment.inspect_contact(Vector2i(220,130),Vector2i(221,130),0) == report,
			"Repeated cold inspection is deterministic at the same completed tick")
	expect(signature(experiment) == before,"Contact inspection preserves physical state, quantities, tick and render revision")
	var probability: Dictionary = experiment.inspect_contact(Vector2i(240,130),Vector2i(241,130),33)
	expect(probability.resolver.outcome == "failed_probability_roll" and probability.world_eligibility == "unresolved",
		"A supplied failed Steam/Ice roll is distinguished from actual World eligibility")
	expect(experiment.inspect_contact(Vector2i(240,130),Vector2i(241,130),32).resolver.selected,
		"Actual stored Steam/Ice pair retains the native inclusive probability threshold")
	var far: Dictionary = experiment.inspect_contact(Vector2i(220,130),Vector2i(320,130),0)
	expect(far.resolver.selected and far.blockers.has("moore_neighbour") and far.world_eligibility == "blocked_by_observed_fact",
		"Matching materials at non-neighbour coordinates cannot be presented as a World contact")
	var same: Dictionary = experiment.inspect_contact(Vector2i(220,130),Vector2i(220,130),0)
	expect(same.blockers.has("moore_neighbour"),"A cell is not its own Moore neighbour")
	var outside: Dictionary = experiment.inspect_contact(Vector2i(800,800),Vector2i(801,800),0)
	expect(not outside.source.scheduler.selected_core_included and outside.blockers.has("source_core_window"),
		"Observed native selected-core exclusion is an explicit source-oriented blocker")
	var halo: Dictionary = experiment.inspect_contact(Vector2i(319,130),Vector2i(320,130),0)
	expect(halo.source.scheduler.selected_core_included and not halo.target.scheduler.selected_core_included,
		"Boundary fixture has an included source core and excluded target core")
	expect(halo.blockers.is_empty() and halo.world_eligibility == "unresolved",
		"Target core exclusion does not invent a prohibition on the native neighbour write halo")
	var no_rule: Dictionary = experiment.inspect_contact(Vector2i(220,130),Vector2i(219,130),0)
	expect(no_rule.resolver.outcome == "no_matching_rule" and no_rule.blockers.has("matching_visible_pair"),
		"Actual Salt/Wall readback distinguishes no rule from failed probability")
	var inert_source: Dictionary = experiment.inspect_contact(Vector2i(260,130),Vector2i(261,130),0)
	expect(inert_source.resolver.selected and inert_source.source.has_pair_reactions and inert_source.source.kernel == 0
		and inert_source.blockers.has("source_kernel_available"),
		"Actual Glass/Lava resolver match cannot bypass the inert source's native kernel-dispatch exclusion")
	var inert_target: Dictionary = experiment.inspect_contact(Vector2i(261,130),Vector2i(260,130),0)
	expect(inert_target.resolver.selected and inert_target.target.kernel == 0 and inert_target.blockers.is_empty(),
		"Reversing the real pair admits Lava's source gate without imposing a target-kernel requirement")
	for point: Vector2i in [Vector2i(-1,0),Vector2i(1024,130),Vector2i(220,1024)]:
		expect(not experiment.inspect_contact(point,Vector2i(221,130),0).ok,"Out-of-world source point is rejected")
		expect(not experiment.inspect_contact(Vector2i(220,130),point,0).ok,"Out-of-world target point is rejected")
	for roll: int in [-1,256]:
		expect(not experiment.inspect_contact(Vector2i(220,130),Vector2i(221,130),roll).ok,"Non-byte supplied roll is rejected")
	report.source.material = 77
	report.source.scheduler.core_coordinate[0] = 999
	expect(experiment.inspect_contact(Vector2i(220,130),Vector2i(221,130),0).source.material == 23,
		"Caller mutation of copied report cannot change native material authority")
	expect(signature(experiment) == before,"All refused and caller-edited inspections preserve the native owner")
	# Adapter-only mask fixture; remove it before any host advance.
	experiment.world.prepare_rigid_body_coupling(PackedFloat32Array([1,221.5,130.5,0,0.5,0.5,0,0,0,1,1]),false)
	before = signature(experiment)
	var masked: Dictionary = experiment.inspect_contact(Vector2i(220,130),Vector2i(221,130),0)
	expect(masked.target.material == 3 and masked.target.visible_material == 1 and masked.target.transient_body_id == 1,
		"Native visible body proxy does not replace the retained stored material")
	expect(masked.target.state_a == 173 and masked.target.stored_temperature_raw == 200
		and not masked.target.temperature_available and masked.target.temperature_raw == null,
		"New stored-temperature copy preserves the established masked visible-temperature contract")
	expect(masked.blockers.has("target_mask") and masked.resolver.target == 1 and not masked.resolver.matched,
		"Masked neighbour is diagnosed using actual visible Wall identity, not hidden Water")
	expect(signature(experiment) == before,"Mask-aware inspection does not remove masks or mutate hidden storage")
	experiment.world.prepare_rigid_body_coupling(PackedFloat32Array([1,220.5,130.5,0,0.5,0.5,0,0,0,1,1]),false)
	masked = experiment.inspect_contact(Vector2i(220,130),Vector2i(221,130),0)
	expect(masked.blockers.has("source_mask") and masked.source.material == 23,
		"Native source mask prevents presenting the retained cell as a runnable source")
	experiment.world.prepare_rigid_body_coupling(PackedFloat32Array(),false)
	expect(experiment.step(1),"Actual owner can still advance after observation-only probes")
	var stepped: Dictionary = experiment.inspect_contact(Vector2i(220,130),Vector2i(221,130),0)
	expect(stepped.completed_tick == 1 and stepped.source.scheduler.last_applied_core_included == true,
		"After a native tick, applied-core facts bind to that completed boundary")
	experiment.close()
	expect(not experiment.inspect_contact(Vector2i(220,130),Vector2i(221,130),0).ok,"Closing releases the diagnostic owner")

func check_nonambient_storage(bridge: Variant) -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}) and bridge.build_world(world,PackedInt32Array([24,24,1,1,3])),
		"Standalone exclusive owner prepares a native stored-temperature fixture")
	# Existing decoded CYSD1 payload, as used by the accepted level importer.
	# This adapter regression never introduces a live temperature authoring UI.
	var bytes: PackedByteArray = bridge.export_level(world)
	bytes.encode_s16((24 * 1024 + 24) * 5 + 3,371)
	expect(bridge.import_level(world,bytes),"Existing native import stores a nonambient temperature")
	world.prepare_rigid_body_coupling(PackedFloat32Array([1,24.5,24.5,0,0.5,0.5,0,0,0,1,1]),false)
	var before: String = world.get_physical_state_hash()
	var cell: Dictionary = bridge.inspect_material_lab_cell(world,Vector2i(24,24))
	expect(cell.material == 3 and cell.visible_material == 1 and cell.stored_temperature_raw == 371,
		"Cold native readback exposes exact nonambient stored temperature beneath the mask")
	expect(not cell.temperature_available and cell.temperature_raw == null,
		"Legacy masked visible-temperature fields retain their original meaning")
	expect(world.get_physical_state_hash() == before and world.rigid_body_id_at(24,24) == 1,
		"Stored-temperature inspection preserves physical state and actual body mask")

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var button: Button = find_button(child,caption)
		if button != null: return button
	return null

func preview_click(panel: Variant, point: Vector2i, button: MouseButton) -> void:
	var size: Vector2 = panel._preview.texture.get_size()
	var scale: float = minf(panel._preview.size.x / size.x,panel._preview.size.y / size.y)
	var margin: Vector2 = (panel._preview.size - size * scale) / 2.0
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = margin + (Vector2(point - panel.experiment.preview_region().position) + Vector2(0.5,0.5)) * scale
	panel._preview.gui_input.emit(event)

func check_window_layout(panel: Variant) -> void:
	var former_size: Vector2i = root.size
	var former_scale_size: Vector2i = root.content_scale_size
	var former_tab: int = panel._tabs.current_tab
	var actions: Array = [["Make editable copy"],["New powder (definition test only)","Save material preset…"],
		["Check built-in rule","Run edited reaction"],["Prepare experiment","Inspect contact","Swap the two cells"],
		["Build + run comparison","Save World recipe…"]]
	for dimensions: Vector2i in [Vector2i(1000,650),Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		for tab: int in range(panel._tabs.get_tab_count()):
			panel._tabs.current_tab = tab
			for frame: int in range(3): await process_frame
			var visible: Rect2 = root.get_visible_rect()
			expect(visible.size.is_equal_approx(Vector2(dimensions)),"Standalone Lab uses actual window pixels at %s" % dimensions)
			expect(panel.get_global_rect().end.y <= visible.end.y and panel.get_global_rect().end.x <= visible.end.x,
				"Tab %d remains inside the %s window instead of growing controls offscreen" % [tab,dimensions])
			var scroll: ScrollContainer = panel._tabs.get_current_tab_control()
			for caption: String in actions[tab]:
				var button: Button = find_button(panel,caption)
				expect(button != null,"Layout action exists: " + caption)
				if button == null: continue
				scroll.ensure_control_visible(button)
				for frame: int in range(2): await process_frame
				expect(scroll.get_global_rect().has_point(button.get_global_rect().get_center()),
					"Action can be brought into the visible tab at %s: %s" % [dimensions,caption])
			scroll.scroll_vertical = 0
	root.size = former_size
	root.content_scale_size = former_scale_size
	panel._tabs.current_tab = former_tab
	for frame: int in range(3): await process_frame

func check_mounted_controls() -> void:
	root.size = Vector2i(1680,1050)
	root.content_scale_size = Vector2i(1680,1050)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(Vector2i(1680,1050))
	var previous_scale_mode: int = root.content_scale_mode
	var scene: Control = load("res://materials_lab.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var panel: Variant = scene.find_child("MaterialsLabPanel",true,false)
	expect(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED,"Standalone Lab keeps authoring text at its declared pixel size")
	await check_window_layout(panel)
	expect(panel.experiment.start(fixture(),1),"Mounted Lab owns the real controlled native fixture")
	if not panel.experiment.active():
		scene.queue_free()
		return
	panel._tabs.current_tab = 3
	panel.select_material(23)
	panel._select_partner(3)
	panel._steps.value = 20
	panel._refresh_experiment()
	await process_frame
	panel._cell_x.value = 220
	panel._cell_y.value = 130
	panel._target_x.value = 221
	panel._target_y.value = 130
	var before: Dictionary = signature(panel.experiment)
	panel._running = true
	find_button(panel,"Inspect contact").pressed.emit()
	expect(not panel._running and panel.last_contact_report.get("ok",false),"Mounted contact action pauses before reading the exclusive owner")
	expect(panel._experiment_report.text.contains("NATIVE CONTACT / completed tick 0")
		and panel._experiment_report.text.contains("UNOBSERVED") and panel._experiment_report.text.contains("supplied byte roll"),
		"Mounted report separates stored facts, supplied resolver result and unknown scheduling gates")
	expect(signature(panel.experiment) == before,"Mounted inspection performs no simulation step or material write")
	await capture_contact(panel)
	find_button(panel,"Swap the two cells").pressed.emit()
	expect(panel.last_contact_report.source.material == 3 and panel.last_contact_report.target.material == 23,
		"Swap the two cells inspects the opposite actual positional pair")
	panel._target_x.get_line_edit().text = "222"
	panel._target_x.get_line_edit().text_changed.emit("222")
	expect(panel.last_contact_report.is_empty(),"Unsubmitted coordinate text immediately retires contact evidence")
	find_button(panel,"Swap the two cells").pressed.emit()
	expect(int(panel._cell_x.value) == 222 and int(panel._target_x.value) == 221,
		"Swap the two cells commits displayed coordinates before exchanging them")
	panel._contact_roll.value = 255
	expect(panel.last_contact_report.is_empty() and panel._experiment_report.text.contains("inputs changed"),
		"Editing diagnostic inputs retires the previous visible receipt")
	preview_click(panel,Vector2i(220,130),MOUSE_BUTTON_LEFT)
	preview_click(panel,Vector2i(221,130),MOUSE_BUTTON_RIGHT)
	expect(int(panel._cell_x.value) == 220 and int(panel._cell_y.value) == 130
		and int(panel._target_x.value) == 221 and int(panel._target_y.value) == 130,
		"Left/right preview selection maps through the aspect-preserved native image region")
	expect(panel.last_contact_report.source.material == 23 and panel.last_contact_report.target.material == 3,
		"Preview-selected values come from native storage, not sampled image colour")
	expect(signature(panel.experiment) == before,"Preview selection preserves all native state and masks")
	find_button(panel,"Read cell values").pressed.emit()
	var cell: Dictionary = JSON.parse_string(panel._experiment_report.text)
	expect(cell.ok and cell.material == 23 and cell.has("stored_temperature_raw") and cell.has("scheduler"),
		"Existing single-cell control is connected to the richer native readback")
	find_button(panel,"Inspect contact").pressed.emit()
	find_button(panel,"Step").pressed.emit()
	expect(panel.last_contact_report.is_empty(),"Advancing the native owner retires the previous contact snapshot")
	scene.queue_free()
	await process_frame
	expect(root.content_scale_mode == previous_scale_mode,"Leaving standalone Lab restores the game's previous canvas scaling")

func capture_sources() -> Dictionary:
	var values: Dictionary = {}
	for path: String in ["materials_lab.tscn","scripts/material_lab_panel.gd","scripts/material_lab_screen.gd","scripts/material_lab_property_tree.gd","scripts/material_lab_experiment.gd",
		"tests/test_material_lab_diagnostics.gd","native_extension/material_lab_inspection.inc","native_extension/cyber_demo_bridge.hpp"]:
		values[path] = FileAccess.get_sha256("res://" + path)
	return values

func capture_contact(panel: Variant) -> void:
	if capture_directory.is_empty(): return
	expect(capture_directory.is_absolute_path() and DisplayServer.get_name() != "headless",
		"Contact capture requires an explicit absolute directory and a real display")
	if not capture_directory.is_absolute_path() or DisplayServer.get_name() == "headless": return
	expect(DirAccess.make_dir_recursive_absolute(capture_directory) == OK,"Contact capture output directory exists")
	var sources: Dictionary = capture_sources()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = capture_directory.path_join("09-native-contact-inspector.png")
	expect(not image.is_empty() and image.save_png(path) == OK,"Actual mounted contact-inspector viewport is captured")
	var owner: Dictionary = panel.experiment.capture()
	expect(owner.get("ok",false),"Captured contact has a source-bound native owner receipt")
	var evidence: Dictionary = {"contact":panel.last_contact_report.duplicate(true),"owner":owner}
	var file := FileAccess.open(capture_directory.path_join("contact-readback.json"),FileAccess.WRITE)
	expect(file != null,"Actual contact and owner readback artifact opens")
	if file == null: return
	file.store_string(JSON.stringify(evidence,"\t") + "\n")
	file.close()
	var library: String = "res://addons/cybersand_native/bin/" + ("libcybersand_native.linux.x86_64.so" if OS.get_name() == "Linux" else "cybersand_native.windows.x86_64.dll")
	capture_manifest = {"schema_id":"cybersand.material-lab.contact-capture","schema_version":1,
		"platform":OS.get_name(),"display":DisplayServer.get_name(),"engine":Engine.get_version_info(),
		"renderer":RenderingServer.get_video_adapter_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"viewport":[image.get_width(),image.get_height()],"image_sha256":FileAccess.get_sha256(path),
		"readback_sha256":FileAccess.get_sha256(capture_directory.path_join("contact-readback.json")),
		"source_sha256":sources,"native_library_path":library,"native_library_sha256":FileAccess.get_sha256(library),
		"scope":"Actual mounted contact controls and native owner readback on the stated platform; no human acceptance or executed-reaction claim from supplied resolver roll."}

func run() -> void:
	if not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false,"Current native extension is required; no mocked diagnostics acceptance")
		quit(1)
		return
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if not bridge.has_method(&"inspect_material_lab_cell"):
		expect(false,"Rebuild the new native Materials Lab inspection seam before acceptance")
		quit(1)
		return
	expect(not bridge.inspect_material_lab_cell(null,Vector2i.ZERO).ok,"Null native inspection owner is refused")
	var wall_rule: bool = false
	for material: int in range(132):
		if material != 10 and bridge.inspect_interaction(material,1,0).get("matched",false): wall_rule = true
	expect(not wall_rule,"Current compiled sparse rules admit no valid source paired with the visible Wall mask sentinel")
	check_nonambient_storage(bridge)
	for workers: int in [1,4]: check_owner(workers)
	await check_mounted_controls()
	if not capture_manifest.is_empty():
		expect(capture_manifest.source_sha256 == capture_sources(),"Captured contact UI/native source files stayed unchanged")
		expect(capture_manifest.native_library_sha256 == FileAccess.get_sha256(capture_manifest.native_library_path),
			"Captured native library stayed unchanged through qualification")
		capture_manifest["assertions"] = assertions
		capture_manifest["failures"] = failures
		var file := FileAccess.open(capture_directory.path_join("contact-capture-manifest.json"),FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(capture_manifest,"\t") + "\n")
			file.close()
		else: expect(false,"Contact capture manifest can be written")
	print("MATERIAL_LAB_DIAGNOSTICS: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
