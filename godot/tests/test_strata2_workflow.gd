extends "res://tools/qualify_workbench_strata.gd"

## Actual ordinary Workbench UI mediator -> copied target observation -> native
## paint authority -> ACK -> independent readback. No synthetic World adapter.
const Codec = preload("res://scripts/depth/strata_import_codec.gd")
const Module = preload("res://scripts/depth/strata_native_module.gd")

var _fixture_path := "user://strata2-alpha-input.png"


func _play_chunk_trials() -> bool:
	# Exercise real ordinary acknowledgements and history for a stage larger
	# than one native request. The reviewed private Setup must predict the
	# actual saved authoring result, including each chunk boundary.
	var before := await play_bytes()
	var owner := play_identity()
	strata.preview_module("rear-truss-bay", {"plane":"play", "origin":[16,360],
		"count":3, "step":[128,0], "transform":"identity"})
	if not await until(_ready, "multi-chunk ordinary Play preview"): return false
	var preview: Dictionary = strata.authoring_state()
	if not check(preview.get("can_approve",false), "multi-chunk Play preview admitted: " + str(preview.get("error",""))): return false
	check(preview.stages[0].chunks > 1, "ordinary Play construction spans multiple bounded requests")
	check(await play_bytes() == before, "complete multi-chunk Play review wrote no native cells")
	var reviewed_setup: Dictionary = strata._authoring._preflight_play_setup.duplicate(true)
	if not await _approve(): return false
	var complete: Dictionary = strata.authoring_state()
	var after := await play_bytes()
	check(after == _prefix(before, complete.receipts, "play"), "complete native Play layout equals independently reconstructed acknowledged cells")
	check(wb.applied == reviewed_setup, "exact reviewed chunked Setup equals actual ordinary authored history result")
	for _chunk: int in complete.stages[0].completed_chunks:
		check(strata.undo_layer(), "ordinary Play chunk remains independently undoable")
		if not await until(idle, "ordinary chunk Undo ACK"): return false
	check(await play_bytes() == before, "all ordinary chunk Undo acknowledgements restore exact pre-plan native geometry")
	stable_identity(owner, play_identity(), "multi-chunk ordinary construction and Undo")
	record.play_chunked_construction = {"stages":complete.stages,
		"before_sha256":digest(before), "after_sha256":digest(after), "restored_sha256":digest(await play_bytes())}
	return true


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
	var ready: bool = check(state.get("can_approve",false), "actual target preview awaits explicit owner approval: " + str(state.get("error","")))
	if ready: check(strata.status_text().begins_with("Review exact material-ID projection"), "visible Workbench footer reports ready review instead of stale preparation")
	return ready


func _approve() -> bool:
	var state: Dictionary = strata.authoring_state()
	check(strata.approve_plan(str(state.get("token",""))).get("ok",false), "reviewed native plan admitted")
	if not await until(_ready, "bounded native ACK and readback settle"): return false
	state = strata.authoring_state()
	check(state.get("status") in ["completed","committed_stale_pixels"], "native prefix completed with explicit publication status: " + str(state.get("error","")))
	if state.get("status") == "completed": check(strata.status_text().begins_with("Native construction complete:"), "visible footer reports acknowledged completion")
	for stage: Dictionary in state.get("stages",[]):
		check(stage.get("actual_sha256","") == stage.get("projected_sha256","") and str(stage.get("actual_sha256","")).length() == 64,
			"actual target native material hash matches reviewed projection")
	return true


func _prefix(before: PackedByteArray, receipts: Array, plane: String) -> PackedByteArray:
	var result := before.duplicate()
	for receipt: Dictionary in receipts:
		if receipt.get("plane") != plane: continue
		var cells: PackedInt32Array = receipt.get("cells",PackedInt32Array())
		for offset: int in range(0,cells.size(),3): result.encode_u16((cells[offset+1]*512+cells[offset])*2,cells[offset+2])
	return result


func _construction_trials() -> bool:
	var play_before := await play_bytes()
	var identity := play_identity()
	strata.preview_composition("factory-service-bay",{"origin":[240,180]})
	if not await until(_ready,"multi-plane copied native preview"): return false
	var preview: Dictionary = strata.authoring_state()
	if not check(preview.get("can_approve",false),"layered composition preview admitted: "+str(preview.get("error",""))): return false
	check(preview.stages.size()==4 and preview.preview_regions.size()==4,"all native construction stages have independently inspectable projections")
	check(preview.get("composite_image") is Image and preview.composite_image.get_width()<=256,"bounded composited native-ID proposal uses copied material context")
	check(preview.has("visual_settings_proposal") and not preview.can_apply_visual_settings,"visual preset remains separate before native completion")
	if not await _approve(): return false
	var completed: Dictionary = strata.authoring_state()
	check(completed.can_apply_visual_settings,"completed native construction enables separately reviewed visual settings")
	var old_haze: float = strata.document().presentation.fog_strength
	check(strata.set_presentation({"fog_strength":old_haze+0.01}),"change appearance after native completion")
	var stale_visual: Dictionary = strata.apply_composition_settings(completed.visual_settings_token)
	check(not stale_visual.get("ok",true) and str(stale_visual.get("error","")).contains("Visual settings changed"),"changed visual settings invalidate original appearance approval")
	check(strata.set_presentation({"fog_strength":old_haze}),"restore exact reviewed appearance before independent native revision challenge")
	strata.select_layer("background")
	check(strata.edit_cells("background",PackedInt32Array([20,24,58])),"independent native edit after completed construction")
	check(strata.undo_layer(),"undo independent native edit while retaining advanced authored revision")
	stale_visual = strata.apply_composition_settings(completed.visual_settings_token)
	check(not stale_visual.get("ok",true) and str(stale_visual.get("error","")).contains("Native geometry changed"),"even exact material Undo cannot resurrect a stale native-revision visual token")
	strata.preview_composition("factory-service-bay",{"origin":[240,180]})
	await until(_ready,"fresh review after native revision changed")
	if not await _approve(): return false
	completed = strata.authoring_state()
	var native_before := {}
	var histories := {}
	for id: String in ["scripted","effects","background"]:
		native_before[id] = digest(decorative_bytes(id))
		histories[id] = strata.layer_owner.stats().layers[id].undo
	check(not strata.apply_composition_settings("stale-review-token").get("ok",true),"incorrect visual approval token refused")
	check(strata.set_layer_option("background","locked",true),"lock completed composition target")
	check(not strata.apply_composition_settings(completed.visual_settings_token).get("ok",true),"locked target cannot receive preset settings")
	check(strata.set_layer_option("background","locked",false),"unlock completed composition target")
	var settings: Dictionary = strata.apply_composition_settings(completed.visual_settings_token)
	check(settings.get("ok",false) and settings.get("material_writes",-1)==0,"reviewed visual settings commit without native writes")
	for id: String in ["scripted","effects","background"]:
		check(native_before[id]==digest(decorative_bytes(id)),"visual preset preserves complete native geometry on "+id)
		check(histories[id]==strata.layer_owner.stats().layers[id].undo,"visual preset preserves native Undo on "+id)
	check(strata.document().atmosphere==completed.visual_settings_proposal.atmosphere,"preset effect regions and authored settings are exact")
	record.layered_construction = {"stages":completed.stages,"settings":completed.visual_settings_proposal,"native_hashes":native_before}
	# Turning presentation off must not strand a preparation coroutine.
	var options := {"plane":"scripted","origin":[16,360],"count":3,"step":[128,0],"transform":"identity"}
	var before := decorative_bytes("scripted")
	strata.preview_module("rear-truss-bay",options)
	check(strata.set_enabled(false),"disable layered display during native preview preparation")
	await until(_ready,"disabled preparation drains without writes")
	check(not strata.authoring_busy(),"excluded preparation terminates while display stays disabled")
	check(not strata.layer_owner.capture_region("scripted",Rect2i(16,360,1,1)).get("ok",true),"hidden plane capture follows explicit visibility policy")
	check(strata.set_enabled(true),"enable existing composition after cancelled preparation")
	check(before==decorative_bytes("scripted"),"re-enabled native readback proves cancelled preparation retained exact layout")
	# Stop after one synchronous decorative chunk. Full-plane independent
	# readback reconstructs only the acknowledged prefix, never the whole plan.
	strata.preview_module("rear-truss-bay",options)
	await until(_ready,"repeated native part preview")
	preview = strata.authoring_state()
	if not check(preview.get("can_approve",false),"repeat proposal ready: "+str(preview.get("error",""))): return false
	check(strata.approve_plan(preview.token).get("ok",false),"repeat proposal approved")
	await until(func()->bool:return int(strata.authoring_state().get("applied_cells",0))>0,"first native chunk ACK")
	var at_stop: Dictionary = strata.authoring_state()
	strata.stop_authoring()
	await until(_ready,"Stop completes acknowledged prefix readback")
	var stopped: Dictionary = strata.authoring_state()
	check(stopped.status=="partial" and stopped.applied_cells==at_stop.applied_cells and stopped.applied_cells==4096,"Stop admits no later chunk after first4096-cell ACK")
	check(decorative_bytes("scripted")==_prefix(before,stopped.receipts,"scripted"),"Stop complete native plane equals independent acknowledged prefix")
	strata.select_layer("scripted")
	check(strata.undo_layer() and decorative_bytes("scripted")==before,"existing per-plane Undo reverses stopped committed chunk")
	record.stopped_construction = {"applied":stopped.applied_cells,"stages":stopped.stages}
	# A visibility change may prevent final readback; committed writes must
	# still remain explicit and the service must drain with display disabled.
	options.plane = "background"
	before = decorative_bytes("background")
	strata.preview_module("rear-truss-bay",options)
	await until(_ready,"background repeat preview")
	preview = strata.authoring_state()
	if not check(preview.get("can_approve",false),"background repeated part ready"): return false
	strata.approve_plan(preview.token)
	await until(func()->bool:return int(strata.authoring_state().get("applied_cells",0))>0,"background first native ACK")
	at_stop = strata.authoring_state()
	check(strata.set_enabled(false),"disable display after a real native prefix")
	await until(_ready,"disabled native prefix is drained and reported")
	stopped = strata.authoring_state()
	check(not strata.authoring_busy() and not stopped.zero_writes and stopped.applied_cells==at_stop.applied_cells,"disabled display cannot strand or misreport committed native prefix")
	check(strata.set_enabled(true),"resume presentation after bounded partial result")
	check(decorative_bytes("background")==_prefix(before,stopped.receipts,"background"),"re-enabled independent readback matches exact disabled-operation prefix")
	strata.select_layer("background")
	check(strata.undo_layer() and decorative_bytes("background")==before,"partial native prefix remains ordinary decorative Undo")
	check(await play_bytes()==play_before,"multi-plane construction and all stop/toggle trials leave complete Play materials untouched")
	stable_identity(identity,play_identity(),"layered construction and disabled authoring")
	record.disabled_construction = {"status":stopped.status,"applied":stopped.applied_cells,"stages":stopped.stages}
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
	if not await _construction_trials(): finish(); return

	# Ordinary Play imports use its existing async paint/history owner, with no
	# second result consumer and no direct World reference.
	options = _options("play",[120,80])
	wb.applied.brush = 2
	if not await _preview(_fixture_path,options): finish(); return
	var cancel_before := await play_bytes()
	strata.stop_authoring()
	check(not strata.authoring_busy() and strata.authoring_state().get("status") == "cancelled", "ready native proposal cancels immediately before any write")
	check(strata.status_text().begins_with("Native preview cancelled"), "visible footer reports immediate cancellation without stale Stop progress")
	check(await play_bytes() == cancel_before, "cancelled approved-next Play preview preserves every native cell")
	if not await _preview(_fixture_path,options): finish(); return
	var before_noop: Dictionary = strata.authoring_plane_state("play")
	var noop_token: String = strata.authoring_state().token
	check(wb.paint_editor.commit_cells(PackedInt32Array([300,459,58]),"No-op material history fence"), "ordinary no-op native edit admitted between preview and approval")
	await until(idle, "ordinary no-op native ACK")
	var after_noop: Dictionary = strata.authoring_plane_state("play")
	check(after_noop.authored_serial > before_noop.authored_serial, "copied authored Setup serial advances after same-material ordinary edit")
	check(await play_bytes() == initial_play, "same-material edit preserved complete actual native Play layout")
	check(not strata.approve_plan(noop_token).get("ok",true), "old import approval refused after no-op authored history change")
	if not await _preview(_fixture_path,options): finish(); return
	before_noop = strata.authoring_plane_state("play")
	noop_token = strata.authoring_state().token
	check(wb.paint(Vector2i(304,459),58), "legacy ordinary no-op brush admitted through existing owner")
	await until(func()->bool:return idle() and not bool(host.simulation_worker.paint_state().get("legacy_busy",false)), "legacy no-op native delivery")
	after_noop = strata.authoring_plane_state("play")
	check(after_noop.authored_serial > before_noop.authored_serial, "copied authored Setup observes legacy recorder without depending on editor counter")
	check(await play_bytes() == initial_play, "legacy no-op brush preserves complete native Play layout")
	check(not strata.approve_plan(noop_token).get("ok",true), "old approval refused after legacy no-op authored change")
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
	if not await _play_chunk_trials(): finish(); return
	check(strata.layer_owner.stats().native_world_count == 3, "all integrated authoring retains only three decorative Worlds")
	var saved := "strata2-native-import-history"
	check(strata.save_named(saved), "all planes and historical import provenance save")
	var reopened := Document.read_named(saved)
	if reopened.get("document",{}) != strata.document():
		record.persistence_difference = _first_difference(strata.document(),reopened.get("document",{}),"scene")
		print("STRATA2_PERSISTENCE_DIFFERENCE ",JSON.stringify(record.persistence_difference))
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


func _first_difference(a: Variant,b: Variant,path: String) -> Dictionary:
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			if not b.has(key): return {"path":path+"."+str(key),"error":"missing"}
			if a[key]!=b[key]: return _first_difference(a[key],b[key],path+"."+str(key))
	elif a is Array and b is Array:
		if a.size()!=b.size(): return {"path":path,"before_size":a.size(),"after_size":b.size()}
		for index: int in a.size():
			if a[index]!=b[index]: return _first_difference(a[index],b[index],path+"["+str(index)+"]")
	return {"path":path,"before":a,"after":b,"before_type":typeof(a),"after_type":typeof(b),"before_full":JSON.stringify(a,"",true,true),"after_full":JSON.stringify(b,"",true,true)}
