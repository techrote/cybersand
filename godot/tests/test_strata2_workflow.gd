extends "res://tools/qualify_workbench_strata.gd"

## Actual ordinary Workbench UI mediator -> copied target observation -> native
## paint authority -> ACK -> independent readback. No synthetic World adapter.
const Codec = preload("res://scripts/depth/strata_import_codec.gd")
const Module = preload("res://scripts/depth/strata_native_module.gd")

var _fixture_path := "user://strata2-alpha-input.png"


func _options(plane: String, origin: Array = [80,80]) -> Dictionary:
	return {"plane":plane, "crop":[0,0,8,8], "origin":origin, "scale":1, "transform":"identity",
		"alpha_mode":"overlay", "alpha_threshold":128,
		"palette":[{"rgb":[255,0,0], "material":58, "role":"structure"},
			{"rgb":[0,255,255], "material":131, "role":"accent"}],
		"color_distance":0, "unmapped":"refuse"}


func _ready() -> bool:
	return not bool(strata.authoring_state().get("busy",false))


func _preview(path: String, options: Dictionary) -> bool:
	strata.preview_import(path, options)
	if not await until(_ready, "bounded native preview settles"): return false
	var state: Dictionary = strata.authoring_state()
	return check(state.get("can_approve",false), "actual target preview awaits explicit owner approval: " + str(state.get("error","")))


func _approve() -> bool:
	var state: Dictionary = strata.authoring_state()
	check(strata.approve_plan(str(state.get("token",""))).get("ok",false), "reviewed native plan admitted")
	if not await until(_ready, "bounded native ACK and readback settle"): return false
	state = strata.authoring_state()
	check(state.get("status") in ["completed","committed_stale_pixels"], "native prefix completed with explicit publication status: " + str(state.get("error","")))
	for stage: Dictionary in state.get("stages",[]):
		check(stage.get("actual_sha256","") == stage.get("projected_sha256","") and str(stage.get("actual_sha256","")).length() == 64,
			"actual target native material hash matches reviewed projection")
	return true


func run() -> void:
	scene_id = "integrated-authoring-workflow"
	phase = "native-workflow"
	output = OS.get_environment("STRATA_EVIDENCE")
	record = {"schema":"strata2-workflow-v1", "completed":false,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_server":DisplayServer.get_name(), "process_id":OS.get_process_id(),
		"scope":"Actual Main/Workbench authoring, native imports/history/provenance and readback; framebuffer qualification is separate."}
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	if not await until(idle, "ordinary fixture initial admission", 180000): finish(); return
	strata = wb.ensure_strata()
	check(strata.layer_owner.stats().native_world_count == 0, "ordinary default has no decorative native owners")
	strata.open_panel()
	check(strata.layer_owner.stats().native_world_count == 0, "opening coherent authoring tabs remains lazy")
	strata._window.hide()
	var setup := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy), Vector2i(512,512))
	setup.edits = [[8,456,496,8,58]]
	setup.actors = [Setup.instance(Setup.Fleet.stable_id(0),1,Vector2(256,200))]
	setup.next_id = 2
	var document := Document.default_document(Vector2i(512,512))
	document.presentation.enabled = true
	Document.plane(document,"scripted").rectangles = [[80,80,16,16,13]]
	check(strata.load_document({"setup":setup,"document":document}), "native four-plane fixture requested")
	if not await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null, "native fixture adopted"): finish(); return
	var stable_play := play_identity()
	var initial_play := await play_bytes()
	var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color(1,0,0,1))
	image.fill_rect(Rect2i(2,2,4,4), Color.TRANSPARENT)
	image.set_pixel(1,1,Color(1,0,0,0.25))
	image.set_pixel(6,1,Color(0,1,1,1))
	check(image.save_png(_fixture_path) == OK, "deterministic alpha-bearing input saved")
	record.input_sha256 = FileAccess.get_sha256(_fixture_path)
	var options := _options("scripted")
	if not await _preview(_fixture_path,options): finish(); return
	var preview: Dictionary = strata.authoring_state()
	var old_token := str(preview.token)
	var old_serial := int(preview.preview_serial)
	check(strata.layer_owner.material_at("scripted",Vector2i(80,80)) == 13, "preview is genuinely zero native writes")
	check(int(preview.get("no_write",0)) == 17 and int(preview.get("mapped",0)) == 47, "alpha0 and below-threshold pixels are explicitly no-write")
	strata.preview_import("user://strata2-does-not-exist.png",options)
	check(not strata.authoring_state().get("can_approve",true) and int(strata.authoring_state().preview_serial) > old_serial,
		"failed new source revokes previous review token")
	check(not strata.approve_plan(old_token).get("ok",true), "retired preview cannot authorize a different attempted source")
	if not await _preview(_fixture_path,options) or not await _approve(): finish(); return
	check(strata.layer_owner.material_at("scripted",Vector2i(80,80)) == 58, "mapped opaque pixel became actual native material")
	check(strata.layer_owner.material_at("scripted",Vector2i(83,83)) == 13, "central transparent opening preserved destination material")
	check(strata.layer_owner.material_at("scripted",Vector2i(81,81)) == 13, "partial alpha threshold preserves destination")
	check(strata.layer_owner.material_at("scripted",Vector2i(86,81)) == 131, "explicit palette accent became exact native ID")
	for plane: String in ["effects","background"]:
		check(strata.layer_owner.material_at(plane,Vector2i(80,80)) == 0, "import does not write overlapping " + plane)
	check(strata.undo_layer(), "native import chunk participates in existing decorative Undo")
	check(strata.layer_owner.material_at("scripted",Vector2i(80,80)) == 13, "Undo restored actual native destination")
	check(strata.redo_layer(), "native import chunk participates in existing decorative Redo")
	check(strata.layer_owner.material_at("scripted",Vector2i(80,80)) == 58, "Redo restored actual imported material")
	options.alpha_mode = "replace"
	if not await _preview(_fixture_path,options) or not await _approve(): finish(); return
	check(strata.layer_owner.material_at("scripted",Vector2i(83,83)) == 0, "approved replacement explicitly erased alpha hole")
	check(strata.undo_layer() and strata.layer_owner.material_at("scripted",Vector2i(83,83)) == 13,
		"replacement erasure can be undone on its native plane")
	strata.set_layer_settings("scripted",{"locked":true})
	strata.preview_import(_fixture_path,options)
	await until(_ready, "locked preview refuses")
	check(not strata.authoring_state().get("can_approve",true), "locked target cannot reach approval")
	strata.set_layer_settings("scripted",{"locked":false,"opacity":0.0})
	strata.preview_import(_fixture_path,options)
	await until(_ready, "zero-opacity preview refuses")
	check(not strata.authoring_state().get("can_approve",true), "zero-opacity target cannot reach approval")
	strata.set_layer_settings("scripted",{"opacity":1.0})
	options = _options("background",[120,80])
	options.transform = "rotate_90"
	options.scale = 2
	if not await _preview(_fixture_path,options) or not await _approve(): finish(); return
	check(strata.layer_owner.material_at("background",Vector2i(132,92)) == 131,
		"rotated and integer-replicated palette pixel has exact native coordinate")
	stable_identity(stable_play,play_identity(),"decorative imports and native history")
	var before_play_import := await play_bytes()
	check(before_play_import == initial_play, "all decorative imports preserved full actual Play material bytes")

	# Read-only harvest keeps no-write mask semantics; export is an admitted
	# native module with the same exact geometry and historical source identity.
	strata.harvest_module("scripted",[80,80,8,8],"Alpha gantry part")
	if not await until(_ready, "actual native harvest completes"): finish(); return
	var harvest: Dictionary = strata.authoring_state()
	check(harvest.get("status") == "completed" and harvest.has("module_id"), "native harvest produces reusable copied module")
	var export_path := "user://strata2-harvested-part.json"
	var exported: Dictionary = strata.export_module(str(harvest.get("module_id","")),export_path)
	check(exported.get("ok",false), "native module exported through atomic replacement")
	var inspected: Dictionary = strata.authoring_inspect_source(export_path)
	check(inspected.get("ok",false) and inspected.get("kind") == "native_module", "export freshly decodes as strict native module")
	check(inspected.get("module",{}).get("geometry",{}).get("sha256","") == harvest.get("geometry_sha256", "missing"),
		"harvest/export retains exact native geometry identity")
	options = _options("effects",[120,120])
	if not await _preview(export_path,options) or not await _approve(): finish(); return
	check(strata.layer_owner.material_at("effects",Vector2i(120,120)) == 58, "exported module places actual native material on independently selected plane")

	# Ordinary Play imports use its existing async paint/history owner, with no
	# second result consumer and no direct World reference.
	options = _options("play",[120,80])
	if not await _preview(_fixture_path,options) or not await _approve(): finish(); return
	var edited_play := await play_bytes()
	check(edited_play.decode_u16((80*512+120)*2) == 58, "Play import actual native cell independently captured")
	check(edited_play.decode_u16((83*512+123)*2) == 0, "Play alpha opening remains native Empty")
	stable_identity(stable_play,play_identity(),"ordinary Play import")
	check(wb.paint_editor.history_available("undo") and strata.undo_layer(), "Play import preserves ordinary undo history")
	await until(idle, "ordinary Play Undo settles")
	var restored_play := await play_bytes()
	check(restored_play == initial_play, "ordinary Play Undo restored complete original native materials")
	check(wb.paint_editor.redo(), "ordinary Play Redo retained")
	await until(idle, "ordinary Play Redo settles")
	var redone_play := await play_bytes()
	check(redone_play == edited_play, "ordinary Play Redo restored exact imported state")
	check(strata.layer_owner.stats().native_world_count == 3, "all integrated authoring retains only three decorative Worlds")
	var saved := "strata2-native-import-history"
	check(strata.save_named(saved), "all planes and historical import provenance save")
	var reopened := Document.read_named(saved)
	check(reopened.get("document",{}) == strata.document(), "saved authored geometry and provenance decode exactly")
	record.play_identity_before = stable_play
	record.play_identity_after = play_identity()
	record.play_hash_original = digest(initial_play)
	record.play_hash_imported = digest(edited_play)
	record.play_hash_restored = digest(restored_play)
	record.provenance = strata.document().authoring
	record.native_owner_stats = strata.layer_owner.stats()
	print("STRATA2_WORKFLOW ",JSON.stringify({"checks":checks,"failures":failures,"completed":true,
		"play_hash_original":record.play_hash_original,"play_hash_restored":record.play_hash_restored}))
	finish()
