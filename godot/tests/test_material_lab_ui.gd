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
var capture_directory: String = ""
var capture_source_hashes: Dictionary = {}
var capture_manifest: Dictionary = {}
var directory_custody_only: bool = false
var workbench_mount_only: bool = false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="): capture_directory = argument.trim_prefix("--capture-output=")
		if argument == "--directory-custody-only": directory_custody_only = true
		if argument == "--workbench-mount-only": workbench_mount_only = true
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

func directory_custody(requested: String, observed: String) -> bool:
	# MSIX may expose the same AppData directory through logical and physical
	# paths. A fresh marker plus observed removal proves shared live storage;
	# equal basenames or copied bundle bytes alone do not establish custody.
	if not requested.is_absolute_path() or not observed.is_absolute_path(): return false
	if not DirAccess.dir_exists_absolute(requested) or not DirAccess.dir_exists_absolute(observed): return false
	var nonce: String = Crypto.new().generate_random_bytes(32).hex_encode()
	if nonce.length() != 64: return false
	var marker: String = ".materials-lab-custody-" + nonce
	var logical: String = requested.path_join(marker)
	var canonical: String = observed.path_join(marker)
	if FileAccess.file_exists(logical) or DirAccess.dir_exists_absolute(logical): return false
	var file := FileAccess.open(logical,FileAccess.WRITE)
	if file == null: return false
	file.store_string(nonce)
	var write_error: Error = file.get_error()
	file.close()
	var same: bool = write_error == OK and FileAccess.get_file_as_string(canonical) == nonce if FileAccess.file_exists(canonical) else false
	if same:
		same = DirAccess.remove_absolute(canonical) == OK and not FileAccess.file_exists(logical)
	# Only remove the marker created by this invocation, never a replaced file.
	if FileAccess.file_exists(logical) and FileAccess.get_file_as_string(logical) == nonce:
		DirAccess.remove_absolute(logical)
	return same

func directory_custody_controls() -> void:
	var base: String = output_directory.path_join("directory-custody-" + Crypto.new().generate_random_bytes(16).hex_encode())
	var requested: String = base.path_join("logical/export")
	var unrelated: String = base.path_join("unrelated/export")
	expect(not DirAccess.dir_exists_absolute(base),"Directory custody controls use a fresh owned fixture")
	if DirAccess.dir_exists_absolute(base): return
	expect(DirAccess.make_dir_recursive_absolute(requested) == OK and DirAccess.make_dir_recursive_absolute(unrelated) == OK,
		"Directory custody fixtures can be created")
	expect(directory_custody(requested,requested),"Directory custody accepts identical live storage")
	expect(directory_custody(requested,base.path_join("logical/../logical/export")),"Directory custody accepts an actual filesystem path alias")
	expect(not directory_custody(requested,unrelated),"Matching directory basenames cannot establish export custody")
	var payload: String = requested.path_join("identical-bundle-content.json")
	var file := FileAccess.open(payload,FileAccess.WRITE)
	if file != null:
		file.store_string('{"same":"bundle bytes"}\n')
		file.close()
	expect(file != null and DirAccess.copy_absolute(payload,unrelated.path_join(payload.get_file())) == OK,
		"Unrelated directory receives a byte-identical payload")
	expect(not directory_custody(requested,unrelated),"Copied contents in a same-basename directory cannot establish live storage custody")
	for directory: String in [requested,unrelated]:
		var contents: PackedStringArray = DirAccess.get_files_at(directory)
		expect(not str(contents).contains(".materials-lab-custody-"),"Owned custody markers are removed after positive and negative controls")
		DirAccess.remove_absolute(directory.path_join("identical-bundle-content.json"))
		DirAccess.remove_absolute(directory)
	for directory: String in [base.path_join("logical"),base.path_join("unrelated"),base]: DirAccess.remove_absolute(directory)

func canonical_parity() -> void:
	var controls: String = ""
	for codepoint: int in range(1,32): controls += String.chr(codepoint)
	# Independently generated with Python compiler.canonical_json: sorted
	# non-BMP keys, UTF-8, escapes, empty containers and primitive values.
	var vector: Dictionary = {"a":"é/砂🧪","control":controls,"z":[true,false,null,0,-1,65535],"𝄞":{"":[],"é":{},"𝄢":"z"}}
	expect(panel._candidate_sha256(vector) == "d96ce94b8540b77a040a94ab447ac0b75a689a59e9702b2a2e93d6c0b68e30e1",
		"Godot candidate hashing matches independent Python canonical JSON bytes")
	expect(panel._candidate_sha256({"not_integer":0.5}).is_empty(),"Candidate hashing refuses fractional values instead of rounding")
	var effect: Dictionary = {"kind":"set_state"}
	effect.state_b = 7
	expect(panel._candidate_sha256(panel._integer_candidate(effect)) == panel._candidate_sha256({"kind":"set_state","state_b":7}),
		"New structured effect fields normalize Godot interned keys to their JSON text identity")

func response_context(executed: Dictionary) -> void:
	# Re-admit the same genuinely executed result to challenge the response
	# boundary. This does not launch or claim a new native run.
	panel._job_op = "compile_world_test"
	panel._job_revision = panel._revision
	panel._job_world_revision = panel.world_panel.revision
	panel._job_candidate = panel._integer_candidate(executed.candidate)
	panel._job_candidate_digest = panel._candidate_sha256(panel._job_candidate)

func response_binding_adversaries(executed: Dictionary) -> void:
	var original: Dictionary = panel.candidate.duplicate(true)
	expect(panel._job_candidate == original and panel._job_candidate_digest == executed.digest,
		"Actual process captured the submitted canonical definition and independent digest before reply")
	for mode: String in ["missing_candidate","foreign_candidate","stale_digests","foreign_receipt_digest","native_density","native_viscosity","native_rgba"]:
		response_context(executed)
		panel._backend_completed(executed.duplicate(true))
		expect(panel.candidate_state == "Compiled/tested — isolated native World","Executed receipt remains a positive control before " + mode)
		var bad: Dictionary = executed.duplicate(true)
		match mode:
			"missing_candidate": bad.erase("candidate")
			"foreign_candidate": bad.candidate.descriptor.density += 1
			"stale_digests":
				bad.digest = "0".repeat(64)
				bad.receipt.candidate_digest = bad.digest
			"foreign_receipt_digest": bad.receipt.candidate_digest = "0".repeat(64)
			"native_density": bad.receipt.candidate.descriptor_readback.density += 1
			"native_viscosity": bad.receipt.candidate.descriptor_readback.viscosity_index += 1
			"native_rgba": bad.receipt.candidate.descriptor_readback.rgba[0] = (int(bad.receipt.candidate.descriptor_readback.rgba[0]) + 1) % 256
		response_context(executed)
		panel._backend_completed(bad)
		expect(panel.candidate_state.begins_with("Draft") and panel.candidate_digest.is_empty() and panel.world_panel.receipt.is_empty(),
			"Refuse false compiled qualification: " + mode)
		expect(panel.candidate == original and not panel.last_backend_result.get("ok",true),"Refusal preserves the current authored definition: " + mode)
	for op: String in ["create","validate","import","export","import_world_case","export_world_case"]:
		response_context(executed)
		panel._job_op = op
		panel._backend_completed(executed.duplicate(true))
		expect(panel.candidate == original and panel.candidate_state.begins_with("Draft") and panel.world_panel.receipt.is_empty(),
			"A noncompile operation cannot promote an injected compiled response: " + op)
	response_context(executed)
	panel.candidate.descriptor.density += 1
	var changed: Dictionary = panel.candidate.duplicate(true)
	# Bypass the revision counter deliberately: submitted data still binds
	# response admission even after mutation through a shared Dictionary.
	panel._backend_completed(executed.duplicate(true))
	expect(panel.candidate == changed and panel.candidate_state.begins_with("Draft") and panel.world_panel.receipt.is_empty(),
		"Unsignalled draft mutation cannot be overwritten or qualified by an older definition")
	panel.candidate = original
	panel._mark_draft()
	panel._refresh_candidate()

func capture_effects_world(executed: Dictionary) -> bool:
	if capture_directory.is_empty(): return true
	expect(DisplayServer.get_name() != "headless","Graphical capture requires an actual display")
	if DisplayServer.get_name() == "headless": return false
	expect(DirAccess.make_dir_recursive_absolute(capture_directory) == OK,"Graphical output directory can be created")
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = screen.get_viewport().get_texture().get_image()
	var path: String = capture_directory.path_join("08-kept-salt-world.png")
	expect(not image.is_empty() and image.save_png(path) == OK,"Actual retained-Salt desktop viewport is captured")
	var file := FileAccess.open(capture_directory.path_join("effects-ui-world-receipt.json"),FileAccess.WRITE)
	expect(file != null,"Graphical capture stores the displayed native receipt")
	if file == null: return false
	file.store_string(JSON.stringify(executed.receipt,"\t") + "\n")
	file.close()
	var native_path: String = "res://addons/cybersand_native/bin/" + ("libcybersand_native.linux.x86_64.so" if OS.get_name() == "Linux" else "cybersand_native.windows.x86_64.dll")
	expect(FileAccess.file_exists(native_path),"Graphical capture identifies the loaded desktop native library")
	capture_manifest = {"engine":Engine.get_version_info(),"platform":OS.get_name(),"display":DisplayServer.get_name(),
		"renderer":RenderingServer.get_video_adapter_name(),"rendering_method":RenderingServer.get_current_rendering_method(),
		"viewport":[image.get_width(),image.get_height()],"image_sha256":FileAccess.get_sha256(path),
		"native_library_path":native_path,"native_library_sha256":FileAccess.get_sha256(native_path),
		"source_sha256":capture_source_hashes,"native_source_identity":executed.receipt.source_identity,
		"candidate_digest":executed.digest,"runtime_active":false,
		"scope":"Actual mounted UI performs effects-v2 native World test; stored cells establish results. No shader parity claim."}
	return true

func extended_authoring() -> bool:
	# New effects are exercised through the mounted controls and actual World
	# backend. Malformed-response cases below corrupt that executed evidence;
	# they do not substitute a simulated successful native run.
	search_select(23)
	if not await authoring("Duplicate selected"): return false
	var unicode_label: String = " " + String.chr(160) + String.chr(12288) + "β 砂🧪 \"trial\" \\ /" + String.chr(160) + " "
	panel._candidate_name.text = unicode_label
	panel._candidate_name.text_changed.emit(unicode_label)
	if not await authoring("Validate"): return false
	expect(panel.candidate.name == "β 砂🧪 \"trial\" \\ /" and panel.candidate_digest == panel._job_candidate_digest,
		"Real Python validation matches Unicode normalization and locally computed canonical digest")
	panel._candidate_name.text = "Retained Salt"
	panel._candidate_name.text_changed.emit("Retained Salt")
	panel._tabs.current_tab = 2
	panel._reaction_picker.select(panel._reaction_picker.get_item_index(2))
	panel._reaction_picker.item_selected.emit(panel._reaction_picker.selected)
	var rule: Dictionary = panel._selected_reaction()
	expect(int(rule.first) == 3 and int(rule.second) == 23,"Owned Water/Salt slot preserves endpoint roles")
	var water: Dictionary = panel._effect_fields.first
	var salt: Dictionary = panel._effect_fields.second
	expect(water.kind.is_item_disabled(1) and water.kind.is_item_disabled(2),"Unsupported Water retention/state controls are disabled")
	expect(not salt.kind.is_item_disabled(1) and salt.kind.is_item_disabled(2),"Salt admits retention but has no invented state-B contract")
	salt.kind.select(1)
	salt.kind.item_selected.emit(1)
	rule = panel._selected_reaction()
	expect(rule.effects.version == 2 and rule.effects.second.kind == "keep_existing" and int(rule.second_product) == 23,
		"Keep-existing control emits explicit v2 and retains participant identity")
	expect(panel._reaction_fields.second_product.disabled and not salt.state_b.editable,
		"Retained identity and unsupported state are not decorative editable controls")
	if not await authoring("Validate candidate"): return false
	expect(panel._selected_reaction().effects.second.kind == "keep_existing" and panel.candidate_state == "Validated candidate",
		"Real validator admits the structured non-Water retention candidate")
	var view: Variant = panel.world_panel
	expect(view.set_scenario({"first":23,"second":3,"seed":2,"ticks":120,"workers":4}),"Prospective World recipe is set before selected-reaction routing")
	if not press("Test reaction in World"): return false
	expect(view.scenario().first == 3 and view.scenario().second == 23 and panel._tabs.current_tab == 4,
		"Selected-reaction button routes its actual positional pair into the mounted World test")
	if not await wait_for(func() -> bool: return not panel.service.busy,"actual retained-endpoint World comparison",300000): return false
	var executed: Dictionary = panel.last_backend_result.duplicate(true)
	expect(executed.get("ok",false),"Effects-v2 candidate ran in actual native World: " + str(executed.get("errors",[])))
	if not executed.get("ok",false): return false
	expect(panel.candidate_state == "Compiled/tested — isolated native World" and not view.receipt.is_empty(),
		"Only accepted actual World evidence promotes the parent candidate state")
	expect(int(executed.receipt.candidate.final.material_cells[23]) > int(executed.receipt.reference.final.material_cells[23]),
		"Native World retains more Salt than the legacy replacing reference")
	expect(executed.receipt.candidate.checks.quantity_balanced and executed.receipt.candidate.checks.worker_1_4_equal,
		"Actual retained-endpoint quantity and worker qualification pass")
	var evidence := FileAccess.open(output_directory.path_join("ui-retained-salt-world-receipt.json"),FileAccess.WRITE)
	expect(evidence != null,"Executed effect receipt is retained for review")
	if evidence != null:
		evidence.store_string(JSON.stringify(executed.receipt,"\t") + "\n")
		evidence.close()
	if not await capture_effects_world(executed): return false
	response_binding_adversaries(executed)
	var refused: Dictionary = executed.duplicate(true)
	refused.receipt.checks.source_unchanged = false
	response_context(executed)
	panel._backend_completed(refused)
	expect(panel.candidate_state.begins_with("Draft") and panel.candidate_digest.is_empty() and not panel.last_backend_result.get("ok",true),
		"Parent cannot remain Compiled/tested after its World view rejects native evidence")
	expect(view.receipt.is_empty() and not view._run_button.disabled and not panel._candidate_feedback.text.contains("Compiled/tested"),
		"Rejected parent evidence clears previews/status and releases compile controls")
	var recipe: Dictionary = {"first":3,"second":23,"seed":73,"ticks":37,"workers":4}
	expect(view.set_scenario(recipe),"Distinct source-bound recipe can be selected")
	view._seed.get_line_edit().text = "74"
	view._seed.get_line_edit().text_changed.emit("74")
	view._ticks.get_line_edit().text = "38"
	view._ticks.get_line_edit().text_changed.emit("38")
	recipe.seed = 74
	recipe.ticks = 38
	var case_path: String = output_directory.path_join("retained-salt-world-case.json")
	if not await selected_file("Save World recipe…",case_path): return false
	expect(panel.last_backend_result.get("ok",false) and FileAccess.file_exists(case_path),"Mounted save exports a source-bound World recipe through the real service")
	if not panel.last_backend_result.get("ok",false): return false
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(case_path))
	expect(saved.schema_id == "cybersand.material-lab.world-case" and str(saved.digest).length() == 64 and not saved.source_identity.lf_sha256.is_empty(),
		"Recipe stores versioned digests and exact executable source inputs")
	expect(panel._integer_candidate(saved.scenario) == recipe,"Saving a World recipe commits displayed seed and tick text without requiring Enter")
	var expected_candidate: Dictionary = panel.candidate.duplicate(true)
	var expected_digest: String = panel.candidate_digest
	expect(panel.candidate_state == "Validated candidate" and view.receipt.is_empty(),"Saving a recipe is validation, not a new native execution")
	search_select(2)
	if not await authoring("Duplicate selected"): return false
	expect(view.set_scenario({"first":2,"second":1,"seed":99,"ticks":600,"workers":1}),"Unrelated candidate and controls are prepared before import")
	if not await selected_file("Import World recipe…",case_path): return false
	expect(panel.last_backend_result.get("ok",false) and panel.candidate == expected_candidate and panel.candidate_digest == expected_digest,
		"Real recipe import restores the exact material and deterministic candidate digest")
	expect(view.scenario() == recipe and panel._tabs.current_tab == 4,"Recipe import restores every control and opens its test tab")
	expect(panel.candidate_state == "Validated candidate" and view.receipt.is_empty() and view._reference_preview.texture == null,
		"Imported source-bound recipe carries no old Compiled/tested result")
	var before_candidate: Dictionary = panel.candidate.duplicate(true)
	var before_recipe: Dictionary = view.scenario()
	saved.digest = "0".repeat(64)
	var broken_path: String = output_directory.path_join("corrupt-world-case.json")
	var broken := FileAccess.open(broken_path,FileAccess.WRITE)
	broken.store_string(JSON.stringify(panel._integer_candidate(saved),"\t") + "\n")
	broken.close()
	if not await selected_file("Import World recipe…",broken_path): return false
	expect(not panel.last_backend_result.get("ok",true) and panel.candidate == before_candidate and view.scenario() == before_recipe,
		"Digest-corrupt recipe import preserves the current candidate and controls")
	expect(panel._status.text.contains("/case/digest"),"Recipe digest refusal identifies the actionable field")
	search_select(28)
	if not await authoring("Duplicate selected"): return false
	panel._tabs.current_tab = 2
	panel._reaction_picker.select(0)
	panel._reaction_picker.item_selected.emit(0)
	var metal: Dictionary = panel._effect_fields.second
	expect(not metal.kind.is_item_disabled(2),"Metal exposes its real charge-countdown state-B effect")
	metal.kind.select(2)
	metal.kind.item_selected.emit(2)
	metal.state_b.value = 7
	rule = panel._selected_reaction()
	expect(rule.effects.second.kind == "set_state" and int(rule.effects.second.state_b) == 7 and int(rule.second_product) == 28,
		"Metal structured state control retains identity and sets its declared register")
	expect(metal.state_b.editable and metal.detail.text.contains("charge countdown"),"State editor names its actual native consumer")
	if not await authoring("Validate candidate"): return false
	if not press("Compile candidate reaction"): return false
	if not await wait_for(func() -> bool: return not panel.service.busy,"descriptor-only backend refusal for extended effect"): return false
	expect(not panel.last_backend_result.get("ok",true) and panel._status.text.contains("World"),
		"Extended effects cannot silently fall back to the legacy descriptor/resolver probe")
	return true

func workbench_popup_controls(workbench: Variant, main: Control) -> void:
	var popup: Window = workbench._materials_lab_window
	var mounted: Variant = workbench._materials_lab_panel
	var native: bool = not OS.has_feature("web") and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)
	expect(popup.force_native == native and popup.is_embedded() != native,"Lab uses a native desktop window only when the display supports subwindows")
	expect(popup.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED and popup.handle_input_locally,
		"Lab owns its pixel scaling and local input without changing the game")
	expect(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and root.content_scale_size == Vector2i(1920,1080),
		"Opening Lab preserves the stretched game canvas")
	var bounds: Rect2i = DisplayServer.screen_get_usable_rect(root.current_screen) if native else Rect2i(Vector2i.ZERO,Vector2i(root.get_visible_rect().size))
	expect(bounds.encloses(Rect2i(popup.position,popup.size)),"Lab initially fits the available desktop or embedded viewport")
	for dimensions: Vector2i in [Vector2i(1000,650),Vector2i(1280,720)]:
		popup.size = dimensions
		for frame: int in range(3): await process_frame
		var scale: Vector2 = mounted.get_screen_transform().get_scale()
		if native: expect(scale.is_equal_approx(Vector2.ONE),"Native Lab controls remain physical pixels at %s" % dimensions)
		expect(Rect2(Vector2.ZERO,Vector2(popup.size)).encloses(mounted.get_global_rect()),"Lab content fits its %s client area" % dimensions)
		mounted._tabs.current_tab = 3
		for frame: int in range(2): await process_frame
		var scroll: ScrollContainer = mounted._tabs.get_current_tab_control()
		var contact: Button = find_button(mounted,"Inspect contact")
		scroll.ensure_control_visible(contact)
		for frame: int in range(2): await process_frame
		expect(scroll.get_global_rect().has_point(contact.get_global_rect().get_center()),"Native contact action remains reachable at %s" % dimensions)
		scroll.scroll_vertical = 0
		print("MATERIAL_LAB_POPUP_GEOMETRY ",JSON.stringify({"display":DisplayServer.get_name(),"native":native,"embedded":popup.is_embedded(),"size":[popup.size.x,popup.size.y],"control_screen_scale":[scale.x,scale.y]}))
	mounted._tabs.current_tab = 0
	for frame: int in range(2): await process_frame
	var paused: bool = main.paused
	var steps: int = workbench.step_serial
	var tick: int = int(main.latest_snapshot.tick_index)
	var edits: Array = workbench.applied.edits.duplicate(true)
	var camera: int = workbench._camera.selected
	mounted._search.grab_focus()
	var typing := InputEventKey.new()
	typing.pressed = true
	typing.keycode = KEY_F
	typing.unicode = "f".unicode_at(0)
	popup.push_input(typing)
	expect(mounted._search.text == "f","Lab text receives keyboard input in its own viewport")
	mounted._search.release_focus()
	for key: Key in [KEY_P,KEY_PERIOD,KEY_F]:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = key
		popup.push_input(event)
		event = event.duplicate()
		event.pressed = false
		popup.push_input(event)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(popup.size) / 2.0
	popup.push_input(click)
	click = click.duplicate()
	click.pressed = false
	popup.push_input(click)
	for frame: int in range(3): await process_frame
	expect(main.paused == paused and workbench.step_serial == steps and int(main.latest_snapshot.tick_index) == tick,
		"Lab keys do not pause, resume or tick the underlying native Workbench")
	expect(workbench.applied.edits == edits and workbench._camera.selected == camera,
		"Lab clicks and shortcuts do not paint or change the underlying Workbench camera")
	mounted._search.text = ""
	mounted._search.text_changed.emit("")

func workbench_mount() -> void:
	# Main owns its real worker and publishes copied tower_context snapshots.
	# The Lab test never reaches into simulation_worker or its native World.
	var former_feature: Variant = get_meta("cybersand_feature") if has_meta("cybersand_feature") else null
	var former_size: Vector2i = root.size
	var former_scale_size: Vector2i = root.content_scale_size
	var former_scale_mode: int = root.content_scale_mode
	var former_embedding: bool = root.gui_embed_subwindows
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.gui_embed_subwindows = true
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
				await workbench_popup_controls(workbench,main)
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
				var focus: Control = root.gui_get_focus_owner()
				if focus != null: focus.release_focus()
				var former_tick: int = int(main.latest_snapshot.tick_index)
				var step := InputEventKey.new()
				step.pressed = true
				step.keycode = KEY_PERIOD
				root.push_input(step)
				if await wait_for(func() -> bool: return installed.call() and int(main.latest_snapshot.tick_index) > former_tick,"Workbench input after closing Lab",60000):
					expect(int(main.latest_snapshot.tick_index) == former_tick + 1,"Closing Lab restores the existing exact native Step shortcut")
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
	root.size = former_size
	root.content_scale_size = former_scale_size
	root.content_scale_mode = former_scale_mode
	root.gui_embed_subwindows = former_embedding
	if former_feature == null: remove_meta("cybersand_feature")
	else: set_meta("cybersand_feature",former_feature)

func run() -> void:
	if not capture_directory.is_empty():
		root.size = Vector2i(1680,1050)
		root.content_scale_size = Vector2i(1680,1050)
		DisplayServer.window_set_size(Vector2i(1680,1050))
		capture_source_hashes = _capture_sources()
	output_directory = ProjectSettings.globalize_path("user://materials_lab/ui-acceptance-%d" % Time.get_ticks_usec())
	expect(DirAccess.make_dir_recursive_absolute(output_directory) == OK,"Acceptance export directory created")
	if workbench_mount_only:
		await workbench_mount()
		print("MATERIAL_LAB_WORKBENCH_MOUNT: %d assertions; %d failures" % [assertions,failures])
		quit(1 if failures else 0)
		return
	directory_custody_controls()
	if directory_custody_only:
		print("MATERIAL_LAB_DIRECTORY_CUSTODY: %d assertions; %d failures" % [assertions,failures])
		quit(1 if failures else 0)
		return
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
	canonical_parity()
	expect(panel._tabs.get_tab_count() == 5,"Inspect, Candidate, Reactions, Native test and Candidate test are mounted")
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
	panel._fields.density.get_line_edit().grab_focus()
	# SpinBox normalizes its display on the deferred focus-enter callback;
	# actual typing happens after that focus event, on the next input frame.
	await process_frame
	panel._fields.density.get_line_edit().text = "1439"
	panel._fields.density.get_line_edit().text_changed.emit("1439")
	expect(panel.candidate_state == "Draft" and panel.candidate_digest.is_empty(),
		"Unsubmitted numeric text immediately retires the visible candidate qualification")
	if not await wait_for(func() -> bool: return not panel.service.busy,"stale validation request"):
		finish()
		return
	expect(panel.candidate_state == "Draft" and panel.candidate.descriptor.density == 1439,
		"Old asynchronous result cannot validate a newer candidate revision")
	expect(panel._status.text.contains("older revision"),"Stale result is explained to the user")
	# Simulate typing without Enter or a focus-exit commit, then immediately
	# activate Compile. The request must capture the displayed number first.
	panel._fields.density.get_line_edit().grab_focus()
	panel._fields.density.get_line_edit().text = "1440"
	panel._fields.density.get_line_edit().text_changed.emit("1440")
	if not await authoring("Compile + native test"):
		finish()
		return
	var compiled: Dictionary = panel.last_backend_result
	expect(panel.candidate_state.begins_with("Compiled/tested"),"Compiled status requires executed C++ receipt")
	expect(not compiled.runtime_active and compiled.receipt.observed.candidate_material.id == 132,
		"Actual compiled synthetic descriptor remains separate from runtime activation")
	expect(compiled.receipt.observed.candidate_material.density == 1440 and panel.candidate.descriptor.density == 1440 and not compiled.receipt.observed.candidate_material.hard_surface,
		"Immediate Compile commits the displayed density before capturing request data or revision")
	expect(PackedInt32Array(compiled.receipt.observed.candidate_material.rgba) == PackedInt32Array([210,90,180,255]),"Appearance bytes reached compiled C++ candidate")
	expect(panel.candidate_digest != validated_digest,"Edited source has a new deterministic digest")
	var exported_digest: String = panel.candidate_digest
	if not await selected_directory("Export compiled bundle…",output_directory):
		finish()
		return
	var bundle: String = str(panel.last_backend_result.get("output_dir","")).replace("\\","/")
	var requested_bundle: String = output_directory.path_join(bundle.get_file())
	expect(not bundle.is_empty() and directory_custody(requested_bundle,bundle),"Compiled bundle has the requested external directory custody, including actual filesystem aliases")
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
	expect(panel.last_backend_result.get("ok",false) and panel.candidate.descriptor.density == 1440
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
	panel._reaction_picker.select(1)
	panel._reaction_picker.item_selected.emit(1)
	var retained_rule: Dictionary = panel._selected_reaction().duplicate(true)
	press("Compile candidate reaction")
	panel._reaction_picker.select(0)
	panel._reaction_picker.item_selected.emit(0)
	if not await wait_for(func() -> bool: return not panel.service.busy,"selected reaction compilation"):
		finish()
		return
	expect(panel.last_backend_result.get("ok",false),"Selected sparse rule is compiled by the actual backend")
	if not panel.last_backend_result.get("ok",false):
		finish()
		return
	expect(panel._selected_reaction().slot == retained_rule.slot,
		"Successful compilation restores its requested sparse rule even if the user browsed another slot while it ran")
	var retained_diagnostic: Dictionary = panel.last_backend_result.receipt.observed.diagnostic
	expect(int(retained_diagnostic.source) == int(panel._selected_reaction().first)
		and int(retained_diagnostic.target) == int(panel._selected_reaction().second),
		"Compiled diagnostic and visible selected reaction fields refer to the same positional pair")
	panel._reaction_picker.select(0)
	panel._reaction_picker.item_selected.emit(0)
	expect(panel._reaction_report.text.begins_with("Candidate rule (not active)")
		and not panel._reaction_report.text.contains("COMPILED CANDIDATE"),"Selecting another rule retires the previous rule's displayed result")
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
	press("Compile candidate reaction")
	panel._roll.value = 0
	if not await wait_for(func() -> bool: return not panel.service.busy,"reaction compilation after supplied-roll edit"):
		finish()
		return
	expect(panel.last_backend_result.get("ok",false) and panel.candidate_state.begins_with("Compiled/tested"),
		"Changing the supplied diagnostic roll does not discard a source-matched material compilation")
	expect(panel._reaction_report.text.begins_with("Diagnostic inputs changed") and not panel._reaction_report.text.contains("COMPILED CANDIDATE"),
		"An in-flight diagnostic cannot restore a receipt for an older supplied roll")
	panel._roll.value = 1
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
	panel._roll.get_line_edit().text = "2"
	panel._roll.get_line_edit().text_changed.emit("2")
	expect(panel._reaction_report.text.begins_with("Diagnostic inputs changed") and not panel._reaction_report.text.contains('"selected":'),
		"Changing the supplied roll retires the preceding production resolver result")
	press("Inspect native result")
	panel._partner.select(panel._partner.get_item_index(2))
	panel._partner.item_selected.emit(panel._partner.selected)
	expect(panel._reaction_report.text.begins_with("Diagnostic inputs changed"),
		"Changing the native partner retires its preceding resolver result")
	panel._select_partner(3)
	press("Inspect native result")
	panel.select_material(2)
	expect(panel._reaction_report.text.begins_with("Diagnostic inputs changed"),
		"Changing the selected source retires its preceding resolver result")
	panel.select_material(23)
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
	expect(panel.experiment.reference_running() and panel.experiment.reference_progress().completed_tick == 0,
		"Mounted comparison starts a fresh native owner without synchronously replaying all ticks")
	await process_frame
	expect(panel.experiment.reference_running() and panel.experiment.reference_progress().completed_tick < 120,
		"Reference comparison yields to the real Godot frame loop")
	press("Pause")
	expect(not panel.experiment.reference_running() and panel.experiment.readback().native.content_hash == readback.native.content_hash,
		"Pause cancels the in-flight replay and preserves source native content")
	press("Repeat / compare reference")
	if not await wait_for(func() -> bool: return not panel.experiment.reference_running(),"incremental native reference",45000):
		finish()
		return
	var comparison: Dictionary = JSON.parse_string(panel._experiment_report.text)
	expect(comparison.ok and comparison.equal,"Fresh native comparison runs through mounted control")
	var case_path: String = output_directory.path_join("salt-water-test.json")
	await selected_file("Save test case…",case_path)
	expect(FileAccess.file_exists(case_path),"Native test case is saved with execution/source contract")
	panel._seed.value = 29
	panel._steps.value = 600
	panel._workers.select(panel._workers.get_item_index(1))
	panel._family.select(2)
	search_select(2)
	panel._experiment_partner.select(panel._experiment_partner.get_item_index(1))
	panel._experiment_partner.item_selected.emit(panel._experiment_partner.selected)
	expect(panel._partner.get_selected_id() == 1 and panel._steps.value == 600,
		"Native test exposes a synchronized partner selector and the complete admitted 600-tick range")
	await selected_file("Import test case…",case_path)
	expect(panel.experiment.readback().completed_tick == 0 and panel.experiment.readback().workers == 4,
		"Saved native case restores a fresh source-matched run and worker count")
	expect(panel._seed.value == 2 and panel._steps.value == 120 and panel._workers.get_selected_id() == 4
		and panel._family.selected == 0,"Import replaces stale seed, duration, workers and Water policy controls with the prepared configuration")
	expect(panel.selected_id == 23 and panel._partner.get_selected_id() == 3 and panel._experiment_partner.get_selected_id() == 3,
		"Import of an exact generated fixture restores its recognized material pair")
	expect(panel._experiment_summary.text.contains("salt-water") and panel._experiment_summary.text.contains("seed 2"),
		"Prepared-run summary identifies the stored fixture and seed independently of prospective controls")
	panel._steps.value = 600
	press("Prepare selected + partner")
	var long_case_path: String = output_directory.path_join("salt-water-600-test.json")
	await selected_file("Save test case…",long_case_path)
	panel._steps.value = 1
	await selected_file("Import test case…",long_case_path)
	expect(panel._steps.value == 600 and panel.experiment.readback().duration_ticks == 600,
		"Imported maximum-duration fixture is represented exactly without SpinBox clamping")
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
	if not await extended_authoring():
		finish()
		return
	await workbench_mount()
	finish()

func _capture_sources() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in ["materials_lab.tscn","addons/cybersand_native/cybersand_native.gdextension","scripts/material_lab_screen.gd","scripts/material_lab_panel.gd","scripts/material_lab_world_panel.gd",
		"scripts/material_lab_service.gd","scripts/material_lab_catalogue.gd","scripts/material_lab_experiment.gd","scripts/shared_workbench.gd","tests/test_material_lab_ui.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func finish() -> void:
	if not capture_manifest.is_empty():
		expect(capture_source_hashes == _capture_sources(),"Graphical UI source stayed unchanged through the run")
		expect(capture_manifest.native_library_sha256 == FileAccess.get_sha256(capture_manifest.native_library_path),
			"Graphical native library stayed unchanged through the run")
		capture_manifest["assertions"] = assertions
		capture_manifest["failures"] = failures
		var file := FileAccess.open(capture_directory.path_join("effects-ui-capture-manifest.json"),FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(capture_manifest,"\t") + "\n")
			file.close()
		else: expect(false,"Graphical capture manifest can be saved")
	if is_instance_valid(panel): panel.experiment.close()
	print("MATERIAL_LAB_UI: %d assertions; %d failures; artifacts=%s" % [assertions,failures,output_directory])
	quit(1 if failures else 0)
