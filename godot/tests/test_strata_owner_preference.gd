extends "res://tools/qualify_workbench_strata.gd"

## Source-matched actual Workbench test. Install and reopen phases use separate
## OS processes and the same isolated user data. Headless is diagnostic only.
const Optics = preload("res://scripts/depth/strata_optics_configuration.gd")
const Presets = preload("res://scripts/depth/strata_optics_presets.gd")


class EvidenceFailure extends Control:
	var labels: Array[String] = []
	func busy() -> bool: return false
	func save_evidence(label: String) -> String:
		labels.append(label)
		return "Authored scene saved; reciprocal evidence publication refused by the test fixture."


func run() -> void:
	scene_id = "owner-diorama-depth-1-3"
	phase = OS.get_environment("STRATA_PHASE")
	if phase.is_empty(): phase = "install"
	output = OS.get_environment("STRATA_EVIDENCE")
	save_name = "ramcache-strata-owner-diorama"
	record = {"schema":"ramcache-strata-owner-preference-v1","scene":scene_id,"phase":phase,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"process_id":OS.get_process_id(),
		"graphical":DisplayServer.get_name() != "headless","completed":false}
	if not check(phase in ["install","reopen"], "known owner preference qualification phase"):
		finish(); return
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	if not await until(idle,"ordinary 512 Workbench bootstrap",180000): finish(); return
	check(not is_instance_valid(wb.strata), "ordinary startup creates no layered or optical owner")
	strata = wb.ensure_strata()
	var initial: Dictionary = strata.optics_state()
	check(initial.configuration.profile == "classic" and not initial.configuration.enabled,
		"new ordinary composition remains Classic with processing disabled")
	if phase == "reopen":
		wb._name.text = save_name
		if not check(wb.load_setup(), "named authored scene loads in a genuinely fresh process"):
			finish(); return
	else:
		var setup := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
		setup.edits = [[8,452,496,8,58]]
		var document := Document.default_document(Vector2i(512,512))
		document.presentation.enabled = true
		Document.plane(document,"scripted").rectangles = [[32,32,96,96,58]]
		Document.plane(document,"effects").rectangles = [[64,64,24,24,131]]
		Document.plane(document,"background").rectangles = [[16,16,160,160,13]]
		if not check(strata.load_document({"setup":setup,"document":document}), "ordinary authored layered fixture admitted"):
			finish(); return
	if not await until(func() -> bool: return idle() and strata.has_document(),"complete layered fixture native ACK",180000):
		finish(); return
	var identity := play_identity()
	var native_before := await play_bytes()
	if phase == "install":
		var classic: Dictionary = strata.optics_state().statistics
		check(not classic.active and classic.material_count == 0 and classic.uniform_writes == 0,
			"fresh Classic allocates no enhanced optical materials and writes no uniforms")
		check(strata.select_optics_profile("diorama") and strata.set_plane_optics("scripted",{"depth":1.3}),
			"owner preference is reproducible through the actual controller APIs")
		var authored: Dictionary = strata.document().optics.duplicate(true)
		check(strata.save_optics_preset("Owner Diorama rear 1.3"), "named reusable preference saves through atomic native storage")
		var catalogue := Presets.read_catalogue()
		check(not catalogue.has("error") and catalogue.catalogue.presets.size() == 1
			and catalogue.catalogue.presets[0].configuration.planes.scripted.depth == 1.3,
			"independent catalogue read retains exact rear optical depth")
		check(strata.select_optics_profile("diorama") and strata.set_plane_optics("scripted",{"depth":1.3}),
			"built-in Diorama identity remains explicitly selectable after named copy")
		check(strata.document().optics == authored, "saved preset does not retune the built-in optical profile")
		await _paint_with_owner_optics()
		check(strata.document().optics == authored, "native edits and history preserve the owner's exact authored optics")
		check(strata.set_optics_inspection({"bypass":true,"clarity":true,"wipe":0.37,"focus_override":"background"}),
			"temporary optical inspection is active before saving")
		check(strata.set_optics_quality("low"), "application quality is stored separately")
		wb._name.text = save_name
		check(wb.save_setup(), "ordinary Save start writes the authored layered composition")
		var saved := Document.read_named(save_name)
		check(saved.get("layered",false) and saved.document.optics == authored,
			"disk scene retains exact authored optics while excluding inspection and quality")
		# Main's sidecar failure contract distinguishes a saved scene from failed
		# ancillary evidence. Layered saves must retain the same visible outcome.
		var evidence := EvidenceFailure.new()
		wb.add_child(evidence)
		wb.reciprocal_panel = evidence
		check(wb.save_setup() and evidence.labels == [save_name]
			and "reciprocal evidence publication refused" in wb.message,
			"layered Save invokes the reciprocal evidence owner and visibly reports its failure")
		wb.reciprocal_panel = null
		evidence.queue_free()
		check(Document.read_named(save_name).document.optics == authored,
			"sidecar refusal does not conceal or destroy the successfully saved authored scene")
		if not await _activate_audition(): finish(); return
		check(wb.save_setup() and "profile is separate" in wb.message and "Saved all four authored planes" in wb.message,
			"layered Save retains the ordinary active Material Audition separate-profile warning")
		check(wb.restore_start(), "Restore start retains the layered composition with existing pose API preserved")
		if not await until(idle,"ordinary restore native ACK",180000): finish(); return
		check(strata.has_document() and strata.document().optics == authored,
			"restoring Play does not erase authored rear optics")
		if not await until(func() -> bool: return wb.material_audition.material_audition_state().get("ok",false),
			"restored ordinary World publishes its material configuration"): finish(); return
		check(not wb.material_audition.material_audition_state().get("changes_behavior",true),
			"restored authored scene honestly starts with ordinary material defaults as disclosed")
	else:
		var state: Dictionary = strata.optics_state()
		check(state.configuration.profile == "diorama" and state.configuration.planes.scripted.depth == 1.3,
			"fresh process restores Diorama with exact rear depth 1.3")
		check(state.inspection == Optics.inspection_defaults(), "fresh scene excludes prior bypass, wipe, clarity and inspection focus")
		check(state.quality == "low", "application quality survives independently of authored optical values")
		var catalogue := Presets.read_catalogue()
		check(not catalogue.has("error") and catalogue.catalogue.presets.size() == 1
			and catalogue.catalogue.presets[0].configuration.planes.scripted.depth == 1.3,
			"named owner preference reopens independently of the scene")
		stable_identity(identity,play_identity(),"optical persistence inspection")
	check(await play_bytes() == native_before, "optical preference and restoration preserve physical material bytes")
	check(strata.layer_owner.material_at("scripted",Vector2i(40,40)) == 58,
		"native rear architecture remains authored material, independent of optical depth")
	record.preference = strata.document().optics
	record.inspection = strata.optics_state().inspection
	record.quality = strata.optics_state().quality
	record.save_sha256 = FileAccess.get_sha256(Setup._path(save_name))
	if DisplayServer.get_name() != "headless" and not output.is_empty(): await capture("owner-diorama-"+phase)
	finish()


func _paint_with_owner_optics() -> void:
	# Reuse the original real Workbench gesture path and native readback. The
	# original one-scene optics smoke omits its challenge-only edit witness.
	var identity := play_identity()
	var point := Vector2i(120,100)
	var extent: Vector2i = Setup.extent_of(wb.applied)
	var witnesses: Array[Dictionary] = []
	for plane: String in ["scripted","play"]:
		var before := await play_bytes() if plane == "play" else decorative_bytes(plane)
		var offset := (point.y*extent.x+point.x)*2
		var original := int(before.decode_u16(offset))
		var material := 131 if original != 131 else 58
		await gesture(plane,"Brush",point,point,material,0)
		var marked := await play_bytes() if plane == "play" else decorative_bytes(plane)
		check(int(marked.decode_u16(offset)) == material, "Diorama input dispatch paints actual native " + plane)
		await gesture(plane,"Eraser",point,point,0,0)
		var erased := await play_bytes() if plane == "play" else decorative_bytes(plane)
		check(int(erased.decode_u16(offset)) == 0, "Diorama input dispatch erases actual native " + plane)
		check(strata.undo_layer(), "Undo actual optical-view erase on " + plane)
		await until(idle,"native optical-view erase Undo settles")
		check(strata.undo_layer(), "Undo actual optical-view brush on " + plane)
		await until(idle,"native optical-view brush Undo settles")
		var restored := await play_bytes() if plane == "play" else decorative_bytes(plane)
		check(restored == before, "complete native plane is restored after Diorama paint/erase/history on " + plane)
		witnesses.append({"plane":plane,"point":[point.x,point.y],"native_before":original,
			"native_brush":int(marked.decode_u16(offset)),"native_erase":int(erased.decode_u16(offset)),
			"native_restored":int(restored.decode_u16(offset)),"before_sha256":digest(before),"restored_sha256":digest(restored)})
	stable_identity(identity,play_identity(),"painting with owner-preferred optics")
	check(strata.select_layer("play"), "restore physical Play editing after optical input exercise")
	record.native_edit_witnesses = witnesses


func _activate_audition() -> bool:
	wb.material_audition = preload("res://scripts/material_audition_controller.gd").new()
	wb.material_audition.bind(wb)
	if not await until(func() -> bool: return wb.material_audition.material_audition_state().get("ok",false),
		"actual Material Audition facade receives native configuration"): return false
	var state: Dictionary = wb.material_audition.material_audition_state()
	var request := {"world_id":state.world_id,"session_id":state.session_id,"expected_revision":int(state.revision),
		"profile":{"schema_version":1,"profile_id":"strata-save-warning","materials":[{"material_id":2,"density":500}],"reactions":[]}}
	var admitted: Dictionary = wb.material_audition.request_material_audition(request)
	if not check(admitted.get("accepted",false), "actual native material audition request is admitted"): return false
	if not await until(func() -> bool: return not wb.material_audition.poll_material_audition(admitted.request_id).get("pending",false),
		"actual native material audition ACK settles"): return false
	var receipt: Dictionary = wb.material_audition.poll_material_audition(admitted.request_id)
	record.material_audition = receipt
	return check(receipt.get("accepted",false) and wb.material_audition.material_audition_state().get("changes_behavior",false),
		"separate-profile warning is exercised with a genuinely active native material configuration")
