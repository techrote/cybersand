extends "res://tests/test_strata2_workflow.gd"

## Independent real-art import exercise through ordinary Main/Workbench.
## Python-authored expected module digests bind the copied proposal; complete
## native before/after captures then establish actual writes and no-write holes.
const REFERENCE_ROOT := "res://data/strata2/reference-imports/"
var _reference_receipts: Array = []


func _project(before: PackedByteArray, module: Dictionary, origin: Vector2i, limit: int = -1) -> PackedByteArray:
	var cells := Marshalls.base64_to_raw(module.geometry.cells_base64)
	var mask := Marshalls.base64_to_raw(module.geometry.write_mask_base64)
	var width := int(module.extent[0])
	var projected := before.duplicate()
	var written := 0
	for index: int in mask.size():
		if mask[index] == 0: continue
		if limit >= 0 and written >= limit: break
		var x := origin.x + index % width
		var y := origin.y + index / width
		projected.encode_u16((y * 512 + x) * 2, cells.decode_u16(index * 2))
		written += 1
	return projected


func _prepare_canvas() -> bool:
	var setup := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy), Vector2i(512,512))
	setup.edits = [[8,456,496,8,58]]
	setup.actors = [Setup.instance(Setup.Fleet.stable_id(0),1,Vector2(256,200))]
	setup.selected = 1
	setup.next_id = 2
	var document := Document.default_document(Vector2i(512,512))
	document.presentation.enabled = true
	# Distinct, nonempty overlapping sentinels make accidental clearing or
	# writing the wrong visible plane observable in complete native captures.
	Document.plane(document,"scripted").rectangles = [[16,32,480,384,13]]
	Document.plane(document,"effects").rectangles = [[16,32,480,384,58]]
	Document.plane(document,"background").rectangles = [[16,32,480,384,62]]
	if not check(strata.load_document({"setup":setup,"document":document}), "explicit reference-test canvas requested"): return false
	return await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null,
		"reference-test native canvas adopted")


func _native_fixture(id: String, challenge_stop: bool) -> void:
	if not await _prepare_canvas(): return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE_ROOT + id + ".fixture.json"))
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE_ROOT + id + ".provenance.json"))
	var trial: Dictionary = provenance.native_qualification
	var options: Dictionary = fixture.options.duplicate(true)
	options.crop = trial.selected_crop.duplicate()
	options.origin = trial.origin.duplicate()
	var origin := Vector2i(int(options.origin[0]),int(options.origin[1]))
	var identity := play_identity()
	var play_before := await play_bytes()
	var before := decorative_bytes("scripted")
	var effects_before := decorative_bytes("effects")
	var background_before := decorative_bytes("background")
	var started := Time.get_ticks_usec()
	if not await _preview(fixture.path,options): return
	var preview: Dictionary = strata.authoring_state()
	check(preview.has("module"), id + " copied material proposal retained for independent digest check")
	if not preview.has("module"): return
	var module: Dictionary = preview.module
	check(module.geometry.sha256 == trial.proposed_uint16le_sha256, id + " real PNG mapping matches independent Python material digest")
	check(module.geometry.mask_sha256 == trial.proposed_write_mask_sha256, id + " real PNG mapping matches independent Python no-write mask")
	check(preview.mapped == trial.mapped and preview.no_write == trial.no_write \
		and preview.unmapped == trial.unmapped_skipped and preview.mask_skipped == trial.mask_no_write,
		id + " exact crop mapping and discarded pixel accounting")
	check(preview.explicit_empty == 0 and preview.alpha_skipped == 0, id + " opaque source does not invent alpha or Empty")
	check(decorative_bytes("scripted") == before, id + " complete target remains unchanged before approval")
	var preview_usec := Time.get_ticks_usec() - started
	var expected := _project(before, module, origin)
	var stop_record := {}
	if challenge_stop:
		check(strata.approve_plan(str(preview.token)).get("ok",false), "real reference prefix approved for Stop trial")
		if not await until(func() -> bool: return int(strata.authoring_state().get("applied_cells",0)) > 0 or _ready(), "one acknowledged real reference chunk"): return
		var stop_started := Time.get_ticks_usec()
		var applied_at_stop := int(strata.authoring_state().get("applied_cells",0))
		strata.stop_authoring()
		if not await until(_ready, "real reference Stop finishes truthful prefix readback"): return
		var stopped: Dictionary = strata.authoring_state()
		var applied := int(stopped.get("applied_cells",0))
		check(stopped.status in ["partial","stopped"] and applied > 0 and applied < int(trial.mapped), "Stop reports a genuine partial native prefix")
		check(applied == applied_at_stop, "Stop prevents another decorative native chunk after the observed ACK")
		var partial := decorative_bytes("scripted")
		check(partial == _project(before,module,origin,applied), "whole native target equals independently ordered acknowledged prefix")
		var chunks := int(stopped.stages[0].completed_chunks)
		check(chunks >= 1 and chunks < int(stopped.stages[0].chunks), "partial history has only acknowledged bounded chunks")
		stop_record = {"status":stopped.status, "applied_cells":applied, "completed_chunks":chunks,
			"stop_to_verified_readback_usec":Time.get_ticks_usec()-stop_started, "native_sha256":digest(partial),
			"stage_receipts":stopped.stages, "scope":"Stop retains native prefix; no rollback inferred."}
		for _chunk: int in chunks: check(strata.undo_layer(), "partial chunk uses existing native Undo")
		check(decorative_bytes("scripted") == before, "per-chunk Undo restores complete native target after partial import")
		if not await _preview(fixture.path,options): return
		preview = strata.authoring_state()
	started = Time.get_ticks_usec()
	if not await _approve(): return
	var completed: Dictionary = strata.authoring_state()
	var after := decorative_bytes("scripted")
	check(after == expected, id + " complete native target equals independent masked material projection")
	check(decorative_bytes("effects") == effects_before, id + " complete overlapping effects plane is unchanged")
	check(decorative_bytes("background") == background_before, id + " complete overlapping background plane is unchanged")
	var play_after := await play_bytes()
	check(play_after == play_before, id + " complete actual Play material bytes are unchanged")
	stable_identity(identity,play_identity(),id + " native decorative reference import")
	var chunks := int(completed.stages[0].completed_chunks)
	check(chunks == ceili(float(trial.mapped)/4096.0), id + " existing per-plane history records bounded chunks")
	var name := "strata2-ref-" + id
	check(strata.save_named(name), id + " actual imported layout and mapping provenance save: " + strata.status_text())
	var decoded := Document.read_named(name)
	check(decoded.get("document",{}) == strata.document(), id + " strict saved authored scene decodes exactly")
	var records: Array = strata.document().authoring.records
	check(not records.is_empty() and records.back().source_sha256 == provenance.crop_file_sha256,
		id + " retained native provenance identifies the actual source bytes")
	_reference_receipts.append({"id":id, "source_original_sha256":provenance.original_sha256,
		"source_crop_sha256":provenance.crop_file_sha256, "mask_sha256":provenance.mask_sha256,
		"explicit_trial":trial, "preview_usec":preview_usec, "apply_and_verify_usec":Time.get_ticks_usec()-started,
		"before_native_sha256":digest(before), "projected_native_sha256":digest(expected), "actual_native_sha256":digest(after),
		"play_sha256_before":digest(play_before), "play_sha256_after":digest(play_after),
		"effects_sha256":digest(effects_before), "background_sha256":digest(background_before),
		"identity_before":identity, "identity_after":play_identity(), "completed_chunks":chunks,
		"stop_trial":stop_record, "native_stage_receipts":completed.stages,
		"retained_authoring":strata.document().authoring})


func run() -> void:
	scene_id = "real-reference-native-imports"
	phase = "reference-native"
	output = OS.get_environment("STRATA_EVIDENCE")
	record = {"schema":"strata2-reference-native-v1", "completed":false,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"), "display_server":DisplayServer.get_name(),
		"scope":"Actual ordinary Main/Workbench, real reference crops, explicit masks, native ACK/history and complete independent material readback; framebuffer appearance is a separate gate."}
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	if not await until(idle,"ordinary reference-test startup",180000): finish(); return
	strata = wb.ensure_strata()
	await _native_fixture("asteroid-service-gallery",false)
	await _native_fixture("rocket-hangar-frame",true)
	record.reference_imports = _reference_receipts
	check(_reference_receipts.size() == 2, "both exact-source references completed native readback")
	print("STRATA2_REFERENCE_NATIVE ",JSON.stringify({"checks":checks,"failures":failures,
		"completed_references":_reference_receipts.size(),"display_server":DisplayServer.get_name()}))
	finish()
