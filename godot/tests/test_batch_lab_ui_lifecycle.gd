extends SceneTree
## Independent UI review regressions. Session fixtures below execute real native
## construction. DeferredSource is only a controlled callback/lifetime fixture;
## it supplies no model result and is not native source-capture evidence.
const BatchPanel = preload("res://scripts/batch_lab/batch_lab_panel.gd")
const NativeView = preload("res://scripts/batch_lab/batch_lab_view.gd")
const Controller = preload("res://scripts/batch_lab/batch_lab_controller.gd")

class DeferredSource extends Node:
	var release := false
	func capture_batch_source(_region: Rect2i) -> Dictionary:
		while not release: await get_tree().process_frame
		var bytes := PackedByteArray()
		bytes.resize(128*128*2)
		bytes.encode_u16(0,58)
		return {"ok":true,"config":{"source_cells":bytes,"source_extent":[128,128],
			"source_region":[0,0,128,128],"source_rectangles":[],
			"source_provenance":{"lifetime_fixture":"prior-grid"}}}

var panel: Window
var checks := 0
var failures: Array[String] = []
var evidence := ""
var started := 0
var native_sessions: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("BATCH_UI_LIFECYCLE "+label)
	return ok

func settled(controller: Node) -> bool:
	var deadline := Time.get_ticks_msec()+60000
	while controller.is_running() and Time.get_ticks_msec()<deadline: await process_frame
	return check(not controller.is_running(),"real native fixture completion")

func open_session(path: String) -> void:
	panel._current_file_action = "open"
	panel._file_selected(path)
	panel.refresh()

func deferred_capture(action: String) -> void:
	panel.set_blind(false)
	check(panel.apply_example("architecture",2,19301).get("ok",false),action+" initial grid")
	var source := DeferredSource.new()
	root.add_child(source)
	panel.wb = source
	panel.capture_source()
	await process_frame
	panel.refresh()
	check(panel._source_pending and not panel._stop_button.disabled,action+" source wait keeps Stop enabled")
	match action:
		"new-example": panel.apply_example("pipework",2,19302)
		"open": open_session("user://batch-review-small.json")
		"reset":
			panel._request_reset()
			panel._confirm.confirmed.emit()
			panel._confirm.hide()
		"selection":
			panel.select_tile(1)
			panel.select_tile(0)
		"form-edit": panel.prompt.text += " Changed while capture waits."
		"apply-config":
			panel.model.text = "changed-local-model"
			check(panel._commit_selected(),"explicit configuration revision accepted")
		"paste-config":
			panel._copy_config = Controller.defaults()
			panel.paste_configuration()
		"stop": panel._stop_button.pressed.emit()
		"close": panel._close_panel()
	source.release = true
	for i: int in 3: await process_frame
	check(not panel.controller.tiles[0].config.has("source_cells"),action+" retires late source callback")
	check(not panel._source_pending,action+" clears source pending state")
	panel.wb = null
	source.queue_free()
	await process_frame

func run() -> void:
	started = Time.get_ticks_msec()
	evidence = OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	panel = BatchPanel.new()
	root.add_child(panel)
	await process_frame
	var empty := Controller.new()
	root.add_child(empty)
	await process_frame
	check(empty.save_session("user://batch-review-small.json").get("ok",false),"save independent smaller idle grid")
	empty.queue_free()
	await process_frame
	check(panel.apply_example("architecture",4,19301).get("ok",false),"sixteen-tile initial UI")
	panel.set_compare([15])
	panel.refresh()
	open_session("user://batch-review-small.json")
	check(panel.controller.tiles.size()==4 and panel.compare_indices.is_empty(),"Open smaller grid retires out-of-range comparison selections")
	check(panel.materials.text=="0,58" and panel._commit_selected(),"reopened JSON material IDs remain editable integer controls")
	for name: String in ["a","b"]:
		var author := Controller.new()
		root.add_child(author)
		await process_frame
		check(author.configure_grid(1,1).get("ok",false),"configure native session "+name)
		check(author.start().get("ok",false),"start real native session "+name)
		if not await settled(author): author.queue_free(); await finish(); return
		check(author.tiles[0].state=="completed" and not author.tiles[0].receipts.is_empty(),"completed native receipt for session "+name)
		check(author.save_session("user://batch-review-"+name+".json").get("ok",false),"save real native session "+name)
		native_sessions.append({"attempt_id":author.tiles[0].attempt_id,"material_sha256":author.tiles[0].material_sha256})
		author.queue_free()
		await process_frame
	open_session("user://batch-review-a.json")
	check(str(panel.result_history.get_item_metadata(0))==str(native_sessions[0].attempt_id),"first session history points at first native attempt")
	open_session("user://batch-review-b.json")
	check(str(panel.result_history.get_item_metadata(0))==str(native_sessions[1].attempt_id),"equal-count replacement rebuilds history identity")
	panel._select_history(0)
	check(panel.preview_text.text=="Accepted.","replacement history is selectable")
	check(panel._commit_selected(),"same-count reopened session can commit its next-attempt form")
	var identity_before: String = panel.controller.tiles[0].attempt_id
	var history_before: String = panel.result_history.get_item_metadata(0)
	var corrupt := FileAccess.open("user://batch-review-invalid.json",FileAccess.WRITE)
	corrupt.store_string("{\"format\":\"invalid-review-file\"}")
	corrupt.close()
	open_session("user://batch-review-invalid.json")
	check(panel.controller.tiles[0].attempt_id==identity_before and panel.result_history.get_item_metadata(0)==history_before,
		"failed Open retains current native result and usable history")
	# Controlled metadata sentinel, not a genuine inference comparison.
	panel.controller.tiles[0].usage = {"requested_model":"review-private-model","returned_model":"review-private-model"}
	panel.set_blind(true)
	panel.refresh()
	check(not panel.details.text.contains("review-private-model") and not panel.details.text.contains("usage"),"blind inspector conceals provider/model metadata")
	check(not panel.family.visible and not panel.example_control.visible and not panel.example_seed.visible,
		"blind mode conceals top-row family/control/seed settings")
	check(panel._stop_button.visible and panel._stop_button.get_parent().visible,"blind mode leaves Stop in the interface")
	check(not panel.result_history.visible and not panel.tabs.is_tab_hidden(0) and panel.tabs.is_tab_hidden(1),"blind mode hides identified history and editable configuration")
	var pixel_view := NativeView.new()
	root.add_child(pixel_view)
	pixel_view.size = Vector2(512,512)
	pixel_view.set_result(null,Vector2i(64,64),PackedByteArray(),"pixel-scale contract")
	pixel_view.native_scale()
	check(absf(pixel_view.pixels_per_cell()-1.0)<0.000001,"1:1 remains exact for a64-cell tile in a512-pixel inspector")
	pixel_view.queue_free()
	panel.set_blind(false)
	panel.refresh()
	check(panel.details.text.contains("review-private-model") and panel.example_seed.visible,"unblind restores retained provenance and controls")
	panel.apply_example("architecture",2,19301)
	panel.variant.select(3)
	panel._choose_variant(3)
	check(panel._commit_selected(),"versioned P3 selection commits")
	var prompt_config: Dictionary = panel.controller.tiles[0].config
	check(prompt_config.variant=="P3" and prompt_config.prompt_sha256==str(prompt_config.prompt).sha256_text()
		and prompt_config.prompt_template_sha256==FileAccess.get_sha256("res://batch_lab/prompts/v1/P3.txt")
		and prompt_config.reference_delivery=="grounded-card-only","variant selection retains correct assembled/template/reference identities")
	panel.prompt.text += " A custom reviewed instruction."
	check(panel._commit_selected(),"custom prompt commits")
	prompt_config = panel.controller.tiles[0].config
	check(str(prompt_config.prompt_version).begins_with("custom:") and prompt_config.prompt_sha256==str(prompt_config.prompt).sha256_text(),
		"custom prompt records its actual assembled hash and custom version")
	for action: String in ["new-example","open","reset","selection","form-edit","apply-config","paste-config","stop","close"]:
		await deferred_capture(action)
	# A non-retired callback still works, and its explicit source replaces the
	# example's initial-material fixture. The mounted suite verifies the actual
	# Workbench source adapter and native-plane equality separately.
	panel.apply_example("architecture",2,19301)
	var source := DeferredSource.new()
	root.add_child(source)
	panel.wb = source
	panel.capture_source()
	await process_frame
	source.release = true
	for i: int in 3: await process_frame
	var config: Dictionary = panel.controller.tiles[0].config
	check(config.has("source_cells") and config.source_rectangles.is_empty(),"current explicit source replaces example source rectangles")
	var material: Dictionary = panel.controller._source(config)
	check(material.get("ok",false) and material.cells==config.source_cells,"current source remains exact before the construction program")
	panel.wb = null
	source.queue_free()
	await finish()

func finish() -> void:
	if panel != null: panel.queue_free()
	await process_frame
	await process_frame
	var summary := {"schema":"batch-ui-lifecycle-review-v1","checks":checks,"failures":failures,
		"elapsed_ms":Time.get_ticks_msec()-started,"native_sessions":native_sessions,
		"deferred_capture_scope":"controlled callback lifetime fixture only; no native capture or inference claim",
		"godot":Engine.get_version_info().string,"os":OS.get_name(),"display":DisplayServer.get_name(),
		"panel_sha256":FileAccess.get_sha256("res://scripts/batch_lab/batch_lab_panel.gd"),
		"view_sha256":FileAccess.get_sha256("res://scripts/batch_lab/batch_lab_view.gd"),
		"source_adapter_sha256":FileAccess.get_sha256("res://scripts/batch_lab/batch_lab_source.gd")}
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("ui-lifecycle.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(summary,"\t")); file.close()
	print("BATCH_UI_LIFECYCLE ",JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
