extends SceneTree

# Real mounted Control tree, asynchronous Python authoring service, compiled C++
# candidate probe and existing native MicroScenario World. No UI/backend mocks.
const SCENE: String = "res://materials_lab.tscn"
const DEADLINE_MS: int = 110000
var assertions: int = 0
var failures: int = 0
var screen: Control
var panel: Variant
var output_directory: String = ""

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("MATERIAL_LAB_UI: " + message)

func wait_for(predicate: Callable, message: String, deadline_ms: int = DEADLINE_MS) -> bool:
	var deadline: int = Time.get_ticks_msec() + deadline_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	expect(false,"Deadline exceeded: " + message)
	return false

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var found: Button = find_button(child,caption)
		if found != null: return found
	return null

func press(caption: String) -> bool:
	var button: Button = find_button(panel,caption)
	if button == null or button.disabled:
		expect(false,"Mounted enabled button missing: " + caption)
		return false
	button.pressed.emit()
	return true

func search_select(id: int) -> bool:
	panel._filter.select(0)
	panel._filter.item_selected.emit(0)
	panel._search.text = str(id)
	panel._search.text_changed.emit(str(id))
	if panel._list.item_count != 1:
		expect(false,"Stable-ID browser lookup must return exactly one item: %d" % id)
		return false
	panel._list.select(0)
	panel._list.item_selected.emit(0)
	expect(panel.selected_id == id,"ItemList selection reached the mounted inspector")
	return panel.selected_id == id

func authoring(caption: String) -> bool:
	if not press(caption): return false
	if not await wait_for(func() -> bool: return not panel.service.busy,caption): return false
	var result: Dictionary = panel.last_backend_result
	expect(result.get("ok",false),"Real authoring operation failed: %s / %s" % [caption,str(result)])
	return bool(result.get("ok",false))

func selected_file(caption: String, path: String) -> bool:
	if not press(caption): return false
	expect(panel._file.visible,"Real file dialog opened: " + caption)
	panel._file.file_selected.emit(path)
	panel._file.hide()
	return await wait_for(func() -> bool: return not panel.service.busy,caption)

func selected_directory(caption: String, path: String) -> bool:
	if not press(caption): return false
	expect(panel._file.visible and panel._file.file_mode == FileDialog.FILE_MODE_OPEN_DIR,
		"Actual compiled-bundle directory picker is mounted")
	panel._file.dir_selected.emit(path)
	panel._file.hide()
	if not await wait_for(func() -> bool: return not panel.service.busy,caption): return false
	expect(panel.last_backend_result.get("ok",false),"Compiled bundle export uses the executed backend: " + str(panel.last_backend_result.get("errors",[])))
	return bool(panel.last_backend_result.get("ok",false))

func workbench_mount() -> void:
	# Main owns its real worker and publishes copied tower_context snapshots.
	# The Lab test never reaches into simulation_worker or its native World.
	var former_feature: Variant = get_meta("cybersand_feature") if has_meta("cybersand_feature") else null
	set_meta("cybersand_feature","shared_workbench")
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	var workbench: Variant = main.shared_workbench
	var installed: Callable = func() -> bool:
		return workbench != null and not workbench.applied.is_empty() and not workbench.busy() \
			and main.pending_microscenario_apply.is_empty() and not main.tower_context.get("liquid_solver_policy",{}).is_empty()
	if await wait_for(installed,"real shared Workbench installation",60000):
		var open_button: Button = find_button(workbench,"Materials Lab…")
		expect(open_button != null,"Existing shared Workbench has a mounted Materials Lab button")
		if open_button != null:
			open_button.pressed.emit()
			await process_frame
			var mounted: Variant = workbench._materials_lab_panel
			expect(is_instance_valid(mounted) and workbench._materials_lab_window.visible,"Materials Lab opens inside actual Workbench Window")
			if is_instance_valid(mounted):
				var initial_owner: Dictionary = main.tower_context.liquid_solver_policy.duplicate(true)
				expect(mounted.applied_policy == initial_owner,"Workbench mount copies the actual owner-published policy")
				expect(mounted.policy_context.contains("Workbench owner snapshot"),"Inspector labels snapshot ownership and refresh semantics")
				var original_family: String = str(initial_owner.assignments[0].applied_family)
				mounted.applied_policy.assignments[0].applied_family = "local-copy-probe"
				expect(str(main.tower_context.liquid_solver_policy.assignments[0].applied_family) == original_family,
					"Inspector nested values cannot mutate the owning Workbench snapshot")
				open_button.pressed.emit()
				expect(mounted.applied_policy == initial_owner,"Reopening replaces mutated local inspection copy with fresh owner data")
				workbench._materials_lab_window.close_requested.emit()
				expect(not workbench._materials_lab_window.visible,"Closing Lab returns to existing Workbench session")
				var details_button: Button = find_button(workbench,"Details")
				if not workbench._details.visible and details_button != null: details_button.pressed.emit()
				var liquids: Variant = workbench._liquids
				liquids.preset_picker.select(1)
				liquids.preset_picker.item_selected.emit(1)
				var apply_button: Button = find_button(workbench,"Apply liquid selection")
				expect(apply_button != null,"Existing native-backed Workbench solver Apply control is mounted")
				if apply_button != null:
					apply_button.pressed.emit()
					var changed: Callable = func() -> bool:
						if not installed.call(): return false
						for assignment: Dictionary in main.tower_context.liquid_solver_policy.assignments:
							if int(assignment.material) == 3: return assignment.applied_family == "cellular_yield_v1"
						return false
					if await wait_for(changed,"native owner acknowledgment of Workbench Water CY",60000):
						expect(mounted.applied_policy.policy_hash == initial_owner.policy_hash,"Closed inspector honestly retains its old snapshot until reopened")
						open_button.pressed.emit()
						expect(mounted.applied_policy.policy_hash == main.tower_context.liquid_solver_policy.policy_hash \
							and mounted.applied_policy.policy_hash != initial_owner.policy_hash,"Reopened inspector receives actual new owner policy hash")
						expect(mounted._summary.text.contains("cellular_yield_v1"),"Water effective-kernel UI shows owner-selected CY after reopening")
				mounted.experiment.close()
	main.queue_free()
	await process_frame
	await process_frame
	if former_feature == null: remove_meta("cybersand_feature")
	else: set_meta("cybersand_feature",former_feature)

func run() -> void:
	output_directory = ProjectSettings.globalize_path("user://materials_lab/ui-acceptance-%d" % Time.get_ticks_usec())
	expect(DirAccess.make_dir_recursive_absolute(output_directory) == OK,"Acceptance export directory created")
	screen = load(SCENE).instantiate()
	root.add_child(screen)
	current_scene = screen
	await process_frame
	panel = screen.find_child("MaterialsLabPanel",true,false)
	if panel == null:
		expect(false,"Materials Lab scene must mount the real panel")
		finish()
		return
	panel._python.text = "python" if OS.get_name() == "Windows" else "python3"
	expect(panel._tabs.get_tab_count() == 4,"Inspect, Candidate, Reactions and Native test are mounted")
	if not panel.catalogue.native_available:
		expect(false,"Matching rebuilt native inspector is required: " + str(panel.catalogue.error))
		finish()
		return
	expect(panel.catalogue.materials.size() == 132,"All 132 stable native slots are visible")
	for id: int in [3,2,21,36,10]:
		if not search_select(id): continue
		expect(panel._property_tree.get_root() != null and panel._property_tree.get_root().get_child_count() >= 10,
			"Selected material has actual property rows: %d" % id)
		expect(panel._summary.text.begins_with("%03d" % id),"Inspector identifies selected stable ID")
		if id == 21:
			expect(panel._inspector_notes.text.contains("1100"),"Slush fallback difference is exposed rather than substituted")
		if id == 10:
			press("Duplicate selected as candidate")
			expect(panel._status.text.contains("reserved") and panel.candidate.is_empty(),"Reserved ID cannot become a candidate")
	panel._search.text = "molten"
	panel._search.text_changed.emit("molten")
	expect(panel._list.item_count > 0,"Text search includes material names and reaction partners")
	panel._filter.select(panel.catalogue.FILTERS.find("Powders"))
	panel._filter.item_selected.emit(panel._filter.selected)
	for index: int in range(panel._list.item_count):
		var id: int = int(panel._list.get_item_metadata(index))
		expect(panel.catalogue.materials[id].state_name == "Powder","Physical-type filter is native state")
	panel._tabs.current_tab = 1
	if not await authoring("New powder 132"):
		finish()
		return
	expect(panel.candidate_state == "Draft" and panel.candidate.target_id == 132,"Create uses isolated candidate identity and Draft status")
	expect(panel._hard.disabled and not panel._hard.button_pressed,"Synthetic powder has explicit non-hard capability")
	panel._fields.density.value = 1437
	panel._colour.color = Color8(210,90,180,255)
	panel._colour.color_changed.emit(panel._colour.color)
	panel._granular.button_pressed = true
	expect(panel.candidate.descriptor.density == 1437 and panel.candidate_state == "Draft","Structured density control edits candidate and invalidates status")
	expect(panel.candidate.descriptor.rgba == [210,90,180,255],"Structured appearance control reaches canonical candidate")
	if not await authoring("Validate"):
		finish()
		return
	expect(panel.candidate_state == "Validated candidate" and panel.candidate_digest.length() == 64,"Validated status comes from strict backend and digest")
	var validated_digest: String = panel.candidate_digest
	panel._fields.density.value = 1438
	expect(panel.candidate_state == "Draft" and panel.candidate_digest.is_empty(),"Editing immediately retires validation digest")
	expect(panel._candidate_feedback.text.begins_with("Draft") and panel._reaction_report.text.begins_with("Draft candidate"),
		"Editing retires visible validation and reaction reports as well as status")
	# Exercise the actual in-flight result race: old validation may finish, but
	# it must never qualify newer SpinBox edits.
	press("Validate")
	panel._fields.density.value = 1439
	if not await wait_for(func() -> bool: return not panel.service.busy,"stale validation request"):
		finish()
		return
	expect(panel.candidate_state == "Draft" and panel.candidate.descriptor.density == 1439,
		"Old asynchronous result cannot validate a newer candidate revision")
	expect(panel._status.text.contains("older revision"),"Stale result is explained to the user")
	if not await authoring("Compile + native test"):
		finish()
		return
	var compiled: Dictionary = panel.last_backend_result
	expect(panel.candidate_state.begins_with("Compiled/tested"),"Compiled status requires executed C++ receipt")
	expect(not compiled.runtime_active and compiled.receipt.observed.candidate_material.id == 132,
		"Actual compiled synthetic descriptor remains separate from runtime activation")
	expect(compiled.receipt.observed.candidate_material.density == 1439 and not compiled.receipt.observed.candidate_material.hard_surface,
		"Compiled native readback acknowledges authored density and explicit capabilities")
	expect(PackedInt32Array(compiled.receipt.observed.candidate_material.rgba) == PackedInt32Array([210,90,180,255]),"Appearance bytes reached compiled C++ candidate")
	expect(panel.candidate_digest != validated_digest,"Edited source has a new deterministic digest")
	var exported_digest: String = panel.candidate_digest
	if not await selected_directory("Export compiled bundle…",output_directory):
		finish()
		return
	var bundle: String = str(panel.last_backend_result.get("output_dir","")).replace("\\","/")
	expect(not bundle.is_empty() and bundle.begins_with(output_directory.replace("\\","/") + "/"),"Compiled bundle has an explicit external destination")
	for name: String in ["preset.json","candidate-catalogue.json","native-receipt.json","generated/manifest.json"]:
		expect(FileAccess.file_exists(bundle.path_join(name)),"Compiled source bundle contains " + name)
	# Check published bytes against their manifest without loading generated
	# definitions into Godot or depending on names of compiler artifacts.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("generated/manifest.json")))
	expect(manifest.artifacts.size() == 3 and manifest.authority == "shadow-only","Exported manifest preserves explicit source-only authority")
	for artifact: Dictionary in manifest.artifacts:
		var artifact_path: String = bundle.path_join("generated").path_join(str(artifact.name))
		expect(FileAccess.file_exists(artifact_path) and FileAccess.get_sha256(artifact_path) == str(artifact.sha256),
			"Exported compiler artifact matches manifest digest: " + str(artifact.name))
	var published_receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("native-receipt.json")))
	expect(published_receipt.candidate_digest == exported_digest and published_receipt.observed.production_registry_unchanged,
		"Published native receipt binds the exported candidate while preserving production identities")
	var export_path: String = output_directory.path_join("powder-132.json")
	if not await selected_file("Save / export preset…",export_path):
		finish()
		return
	expect(FileAccess.file_exists(export_path) and panel.last_backend_result.get("ok",false),"Actual backend exports a versioned preset")
	panel._fields.density.value = 1500
	expect(panel._candidate_feedback.text.begins_with("Draft") and not panel._candidate_feedback.text.contains("Compiled/tested"),
		"Editing a tested candidate removes the previous compiled-success report")
	if not await selected_file("Import preset…",export_path):
		finish()
		return
	expect(panel.last_backend_result.get("ok",false) and panel.candidate.descriptor.density == 1439
		and panel.candidate_digest == exported_digest,"Import restores exact source and deterministic digest")
	var retained_candidate: Dictionary = panel.candidate.duplicate(true)
	var bad_path: String = output_directory.path_join("malformed-preset.json")
	var file := FileAccess.open(bad_path,FileAccess.WRITE)
	file.store_string('{"schema_version":1,"schema_version":2}')
	file.close()
	await selected_file("Import preset…",bad_path)
	expect(not panel.last_backend_result.get("ok",true) and panel.candidate == retained_candidate,
		"Malformed preset import is actionable and preserves prior candidate data")
	expect(not panel._status.text.is_empty(),"Validation failure is visible in mounted UI")
	search_select(3)
	if not await authoring("Duplicate selected"):
		finish()
		return
	expect(not panel._fields.viscosity_index.editable,"Water descriptor viscosity is not falsely exposed as effective control")
	search_select(23)
	if not await authoring("Duplicate selected"):
		finish()
		return
	panel._tabs.current_tab = 2
	expect(panel._reaction_picker.item_count > 0,"Reactive template provides structured sparse rule fields")
	panel._reaction_picker.select(0)
	panel._reaction_picker.item_selected.emit(0)
	panel._reaction_fields.probability.value = 0
	panel._roll.value = 1
	expect(panel._reaction_report.text.contains("1 / 256"),"Threshold zero is shown as 1/256 rather than disabled")
	if not await authoring("Compile candidate reaction"):
		finish()
		return
	var reaction: Dictionary = panel.last_backend_result.receipt.observed.diagnostic
	expect(panel._reaction_report.text.contains("COMPILED CANDIDATE / ISOLATED NATIVE RESOLVER") \
		and panel._reaction_report.text.contains("failed_probability_roll"),"Candidate reaction result is visible on its own mounted tab")
	expect(reaction.status == "failed_probability_roll" and reaction.successful_rolls_of_256 == 1,
		"Compiled edited Salt rule succeeds on exactly one of all 256 rolls and fails supplied roll1")
	expect(reaction.production_selected,"Production Salt rule remains unchanged and selects the same roll")
	panel._tabs.current_tab = 1
	if not await selected_directory("Export compiled bundle…",output_directory):
		finish()
		return
	var bundled_reaction: Dictionary = panel.last_backend_result.receipt.observed.diagnostic
	expect(bundled_reaction.status == "failed_probability_roll" and int(bundled_reaction.roll) == 1 \
		and int(bundled_reaction.probability_threshold) == 0,"Bundle export executes the selected threshold-zero rule with the supplied roll1")
	var selected_rule: Dictionary = panel.candidate.reactions[panel._reaction_picker.selected]
	expect(int(bundled_reaction.source) == int(selected_rule.first) and int(bundled_reaction.target) == int(selected_rule.second),
		"Bundle export retains the selected reaction endpoint identities")
	var reaction_bundle: String = str(panel.last_backend_result.output_dir).replace("\\","/")
	var reaction_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(reaction_bundle.path_join("native-receipt.json")))
	expect(reaction_file.observed.diagnostic == reaction and reaction_file.observed.diagnostic == bundled_reaction,
		"Exported receipt and Compile candidate reaction execute exactly the same user-selected diagnostic")
	panel._tabs.current_tab = 2
	panel._reaction_fields.probability.value = 1
	expect(panel.candidate_state == "Draft" and panel._reaction_report.text.begins_with("Candidate rule (not active)") \
		and not panel._reaction_report.text.contains("COMPILED CANDIDATE"),"Editing a compiled rule retires its visible native result")
	panel._partner.select(panel._partner.get_item_index(3))
	press("Inspect native result")
	var native_reaction: Dictionary = JSON.parse_string(panel._reaction_report.text)
	expect(native_reaction.selected and native_reaction.probability_numerator == 256,
		"Native production inspector remains distinct from edited candidate rule")
	panel._tabs.current_tab = 3
	panel._seed.value = 2
	panel._steps.value = 120
	panel._workers.select(panel._workers.get_item_index(4))
	press("Prepare selected + partner")
	expect(panel.experiment.active(),"Real native MicroScenario is prepared through mounted controls")
	press("Run bounded window")
	if not await wait_for(func() -> bool: return not panel._running,"native bounded window",45000):
		finish()
		return
	var readback: Dictionary = panel.experiment.readback()
	expect(readback.ok and readback.completed_tick == 120 and readback.workers == 4,"Native run completed exact requested steps and worker profile")
	expect(int(readback.material_counts.get("24",0)) == 768,"Actual native owner reports Salt→Brine products")
	expect(panel._experiment_summary.text.contains("120 / 120") and panel._experiment_summary.text.contains("brine 768"),
		"Native completed-step and product counts are visible without reading raw JSON")
	expect(panel._preview.texture != null,"Real native material preview reaches mounted TextureRect")
	press("Repeat / compare reference")
	var comparison: Dictionary = JSON.parse_string(panel._experiment_report.text)
	expect(comparison.ok and comparison.equal,"Fresh native comparison runs through mounted control")
	var case_path: String = output_directory.path_join("salt-water-test.json")
	await selected_file("Save test case…",case_path)
	expect(FileAccess.file_exists(case_path),"Native test case is saved with execution/source contract")
	await selected_file("Import test case…",case_path)
	expect(panel.experiment.readback().completed_tick == 0 and panel.experiment.readback().workers == 4,
		"Saved native case restores a fresh source-matched run and worker count")
	panel._family.select(2)
	press("Prepare selected + partner")
	var actual_policy: Dictionary = panel.experiment.readback().applied_policy
	press("Inspect test-owner policy")
	search_select(3)
	expect(panel.applied_policy.policy_hash == actual_policy.policy_hash and panel.policy_context == "Isolated native test owner",
		"Inspect test-owner policy copies actual native applied policy into the property inspector")
	expect(panel._summary.text.contains("cellular_yield_v1"),"Inspector shows native-applied test policy rather than compiled Water default")
	var receipt_path: String = output_directory.path_join("ui-native-receipt.json")
	file = FileAccess.open(receipt_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(compiled,"\t") + "\n")
	file.close()
	await workbench_mount()
	finish()

func finish() -> void:
	if is_instance_valid(panel): panel.experiment.close()
	print("MATERIAL_LAB_UI: %d assertions; %d failures; artifacts=%s" % [assertions,failures,output_directory])
	quit(1 if failures else 0)
