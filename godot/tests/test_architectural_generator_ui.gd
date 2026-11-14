extends SceneTree

# Focused form/file transaction regression; native install/reopen is exercised
# separately by test_architectural_generator.gd against a source-built runtime.
const Dialog = preload("res://scripts/workbench_generator_dialog.gd")
const Project = preload("res://scripts/architectural_generator_project.gd")
const Store = preload("res://scripts/workbench_generated_map.gd")
var checks := 0
var failures := 0
var emissions := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ARCH_UI " + label)

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i.ZERO
	var owner := Control.new()
	root.add_child(owner)
	var dialog := Dialog.new()
	owner.add_child(dialog)
	dialog.mount(owner)
	dialog.open_new()
	var original_profile: int = dialog._profile.selected
	dialog._architecture_button.pressed.emit()
	var panel: ConfirmationDialog = dialog._architecture
	for frame: int in 4: await process_frame
	check(panel.visible, "Architecture form is reachable from the ordinary generator dialog")
	check(dialog._profile.selected == original_profile and dialog._ready_packet.is_empty(), "opening the form leaves source selection and installed proposal untouched")
	check(panel._style_controls.size() == 5, "five independently editable style columns")
	check(panel._style_controls[0].chooser.item_count >= 13, "three new native algorithms join the expanded preset catalogue")
	var columns_visible := true
	for index: int in range(1,5):
		var previous: Rect2 = panel._style_controls[index - 1].card.get_global_rect()
		var current: Rect2 = panel._style_controls[index].card.get_global_rect()
		if current.position.x <= previous.position.x or current.position.y != previous.position.y: columns_visible = false
	check(columns_visible, "all five style cards share a single horizontal row; no tabs")
	check(panel._style_controls[4].card.get_global_rect().end.x <= panel.get_global_rect().end.x, "fifth style column is visible at 1280px width")
	check(Store.recipe_hash(panel.project()) == Store.recipe_hash(Project.default_project()), "default form exactly represents the declarative project")
	var bounds := Rect2i(Vector2i.ZERO,root.size)
	check(bounds.encloses(Rect2i(panel.position,panel.size)), "first-open Architectural form fits the viewport")
	for button: Button in [panel.get_ok_button(), panel.get_cancel_button()]:
		check(button.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(panel.size)).encloses(button.get_global_rect()), "Architecture action remains visible: " + button.text)
	panel._tunnels.button_pressed = false
	panel._windows.button_pressed = false
	panel._doors.button_pressed = true
	panel._seed.value = 271828
	panel._x.value = -512
	panel._y.value = -512
	panel._corridor.value = 10
	panel._style_controls[0].geometry.room_size.value = 64
	var edited: Dictionary = panel.project()
	check(not edited.automatic_tunnels and not edited.automatic_windows and edited.automatic_doors, "aperture toggles are independent")
	check(edited.seed == 271828 and edited.origin == [-512,-512] and edited.corridor_width == 10, "seed/global origin/corridor are exposed without JSON editing")
	check(edited.styles[0].preset.geometry.room_size == 64 and edited.styles[1].preset.geometry == Project.default_project().styles[1].preset.geometry, "dimension edit has per-style scope")
	var project_path := "user://architecture-ui-project.json"
	var preset_path := "user://architecture-ui-preset.json"
	var invalid_path := "user://architecture-ui-invalid.json"
	check(panel.save_project(project_path), "save embeds validated project and selected presets")
	var saved_text := FileAccess.get_file_as_string(project_path)
	panel._seed.value = 123
	panel._tunnels.button_pressed = true
	check(panel.load_project(project_path), "project reload succeeds")
	check(Store.recipe_hash(panel.project()) == Store.recipe_hash(edited), "project file restores all edited settings")
	var custom: Dictionary = edited.styles[0].preset.duplicate(true)
	custom.id = "owner-service-study"
	custom.name = "Owner Service Study"
	custom.materials.wall = 62
	custom.apertures = {"automatic_doors":false,"automatic_windows":false}
	write_json(preset_path, custom)
	check(panel.import_style(preset_path,0), "user-authored declarative style is imported")
	check(panel.project().styles[0].preset.id == custom.id and panel.project().styles[0].preset.materials.wall == 62, "custom stable identity and material choice survive import")
	check(panel._style_controls[0].description.tooltip_text.contains("Doors: preset Off") and panel._style_controls[0].description.tooltip_text.contains("Windows: preset Off"), "custom aperture overrides are explicit in the owner-facing preset description")
	check(panel.save_project(project_path), "save stores complete custom preset")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preset_path))
	check(panel.load_project(project_path), "custom project reloads after original external preset is deleted")
	var accepted: Dictionary = panel.project()
	write_json(invalid_path,{"format":"bad","version":999})
	check(not panel.load_project(invalid_path), "unsupported project is refused")
	check(Store.recipe_hash(panel.project()) == Store.recipe_hash(accepted), "failed project load preserves prior editable configuration")
	check(not panel.import_style(invalid_path,1), "unsupported custom preset is refused")
	check(Store.recipe_hash(panel.project()) == Store.recipe_hash(accepted), "failed preset import preserves all selected styles")
	saved_text = FileAccess.get_file_as_string(project_path)
	panel._style_controls[0].share.value = 99
	check(not panel.save_project(project_path), "infeasible share total is refused before writing")
	check(FileAccess.get_file_as_string(project_path) == saved_text, "failed save preserves previous complete file")
	panel.project_compiled.connect(func(_result: Dictionary) -> void: emissions += 1)
	panel._apply()
	check(panel.visible and emissions == 0, "invalid Apply remains editable and emits no native preview request")
	check(panel._status.text.begins_with("Refused"), "validation failure is visible")
	var single: Dictionary = Project.default_project()
	single.seed = 9007199254740991
	single.automatic_windows = false
	single.styles = [single.styles[1].duplicate(true)]
	single.styles[0].share = 100.0
	single.styles[0].preset.geometry.room_size = 256
	single.styles[0].preset.geometry.floor_height = 16
	single.styles[0].preset.geometry.wall_thickness = 5
	single.styles[0].preset.geometry.door_width = 2
	single.styles[0].preset.geometry.shaft_width = 0
	single.zone_scale = 512
	check(panel.set_project(single), "single-style custom project with maximum exact seed is admitted")
	if Store.recipe_hash(panel.project()) != Store.recipe_hash(single):
		print("ARCH_UI_ROUNDTRIP expected=", JSON.stringify(single), " actual=", JSON.stringify(panel.project()))
	check(Store.recipe_hash(panel.project()) == Store.recipe_hash(single), "single-style import preserves seed, dimensions, shaft-off and coarse scale without clamping")
	check(panel.save_project(project_path) and panel.load_project(project_path) and int(panel.project().seed) == 9007199254740991, "maximum exact integer seed survives file save and fresh JSON parsing")
	var before_fraction := FileAccess.get_file_as_string(project_path)
	panel._seed.value = 123.75
	panel._choose_style(1, 0)
	check(panel.project().seed == 123.75 and not panel.save_project(project_path), "fractional seed reaches validation and is refused without truncation")
	check(FileAccess.get_file_as_string(project_path) == before_fraction, "fractional seed refusal preserves previously saved exact seed")
	check(panel.set_project(single), "valid exact seed is restored after fractional refusal")
	dialog._seed.value = 4.25
	dialog._start()
	check(dialog._phase == "idle" and dialog._status.text.contains("exact nonnegative integer"), "shared preview input refuses a fractional seed before any native proposal")
	check(panel._style_controls[0].geometry.door_width.editable, "Arcology door width remains editable")
	check(not panel._style_controls[1].enabled.button_pressed and not panel._style_controls[2].enabled.button_pressed and not panel._style_controls[3].enabled.button_pressed and not panel._style_controls[4].enabled.button_pressed, "missing slots are shown as unselected placeholders")
	var pair: Dictionary = Project.default_project()
	pair.styles.resize(2)
	pair.styles[1].share = 55.0
	pair.styles[0].preset.geometry.room_size = 128
	pair.styles[0].preset.geometry.wall_thickness = 4
	check(panel.set_project(pair), "two-style project and maximum Vault dimensions are admitted")
	check(Store.recipe_hash(panel.project()) == Store.recipe_hash(pair), "two-style round trip preserves exact configured project")
	check(panel._style_controls[0].geometry.room_size.max_value == 128 and panel._style_controls[0].geometry.wall_thickness.max_value == 4, "Vault controls expose correct native maximum dimensions")
	var unsupported: Dictionary = pair.duplicate(true)
	unsupported.extent = [256,256]
	unsupported.zone_scale = 32
	check(not panel.set_project(unsupported) and panel._status.text.contains("512 or 1024"), "headless-only extent is refused explicitly instead of silently changing selected map size")
	check(Store.recipe_hash(panel.project()) == Store.recipe_hash(pair), "unsupported UI extent preserves previous editable configuration")
	var precise: Dictionary = Project.default_project()
	precise.styles[0].share = 45.12345
	precise.styles[1].share = 29.87655
	check(panel.set_project(precise) and Store.recipe_hash(panel.project()) == Store.recipe_hash(precise), "custom fractional shares retain their exact configured values instead of slider-step rounding")
	var grammar_path := "res://authoring/worldgen/hierarchy-multi-district.json"
	if not FileAccess.file_exists(grammar_path): grammar_path = "res://../examples/worldgen/hierarchy-multi-district.json"
	var grammar: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(grammar_path))
	grammar.schema = 4
	grammar.architecture = {"version":1,"automatic_tunnels":false,"automatic_doors":false,"door_width":0}
	dialog._architecture_active = false
	dialog._seed.set_value_no_signal(int(grammar.seed))
	dialog._saved_recipe = grammar.duplicate(true)
	dialog._extent.select(0)
	dialog._start()
	check(dialog._phase == "chunks" and dialog._configuration.get("route_validation",{}).get("passed",false), "explicit GEN-004 routes remain admissible with automatic tunnels and doors disabled")
	var supported_recipe: Dictionary = grammar.duplicate(true)
	var support_bounds: Array = []
	if dialog._generator != null:
		var plan: Dictionary = dialog._generator.get_semantic_plan()
		for support: Dictionary in dialog._configuration.get("route_validation",{}).get("supports",[]):
			if support.constraint != "floor": continue
			for feature: Dictionary in plan.get("features",[]):
				if feature.id == support.feature_id:
					support_bounds = [int(feature.bounds[0]),int(feature.bounds[1])+int(feature.bounds[3]),int(feature.bounds[2]),1]
					break
			if not support_bounds.is_empty(): break
	dialog._stop()
	grammar.overrides.append({"id":"intentional-bulkhead","bounds":[-68,-68,9,9],"material":62,"priority":1000})
	dialog._saved_recipe = grammar.duplicate(true)
	dialog._start()
	check(dialog._configuration.get("ok",false) and not dialog._configuration.get("route_validation",{}).get("passed",true), "native report identifies a final override blocking semantic clearance")
	check(dialog._phase == "idle" and dialog.get_ok_button().disabled and dialog._ready_packet.is_empty(), "blocked schema4 required route cannot become an installable preview")
	check(dialog._status.text.contains("intentional-bulkhead") and dialog._status.text.contains("Required semantic route") and dialog._status.text.contains("Remove"), "route conflict identifies the native blocker and an actionable remedy")
	grammar.schema = 3
	grammar.erase("architecture")
	dialog._saved_recipe = grammar
	dialog._start()
	check(dialog._phase == "chunks", "legacy schema3 retains its established reportable blocked-route admission")
	dialog._stop()
	check(not support_bounds.is_empty(), "native hierarchy exposes a real required floor contact for support qualification")
	if not support_bounds.is_empty():
		supported_recipe.overrides.append({"id":"remove-declared-support","bounds":support_bounds,"material":0,"priority":1001})
		dialog._saved_recipe = supported_recipe
		dialog._start()
		var support_report: Dictionary = dialog._configuration.get("route_validation",{})
		check(support_report.get("passed",false) and not support_report.get("supports_passed",true), "real final support removal remains distinct from passage clearance")
		check(dialog._phase == "idle" and dialog.get_ok_button().disabled and dialog._status.text.contains("Required semantic support"), "schema4 missing required support is refused with its native diagnosis")
	var five: Dictionary = Project.default_project()
	var catalogue: Array = Project.builtin_presets()
	for slot: int in range(3, 5):
		five.styles.append({"enabled": true, "share": 0.0, "preset": catalogue[slot].duplicate(true)})
	for slot: int in 5: five.styles[slot].share = [25.0,25.0,25.0,12.5,12.5][slot]
	check(panel.set_project(five), "five active styles can be loaded in one project")
	panel._choose_style(7, 4)
	check(panel.project().styles[4].preset.id == "thermal-foundry" and panel._style_controls[4].enabled.button_pressed, "fifth column changes its own style independently")
	panel._equalize_shares()
	var equalized: Dictionary = panel.project()
	check(equalized.styles.size() == 5 and absf(equalized.styles[4].share - 20.0) < 0.001, "equal shares button balances five active styles")
	check(Project.compile(equalized).get("ok", false), "five-column edited project compiles")
	for path: String in [project_path,preset_path,invalid_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	owner.queue_free()
	await process_frame
	print("ARCHITECTURAL_UI checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
