extends "res://tools/qualify_workbench_strata.gd"

## Narrow test subclasses use ordinary ACK/candidate/executor interfaces.
## No production fault flag, second Play owner or simulated readback is used.
const LayerOwner = preload("res://scripts/depth/workbench_layer_owner.gd")

class RejectingHost extends "res://scripts/main.gd":
	var reject_prepared_once := false
	var refused_identity: Dictionary = {}
	func _advance_prepared_physical_candidate() -> void:
		if not reject_prepared_once:
			super._advance_prepared_physical_candidate()
			return
		var publication: Dictionary = simulation_worker.prepared_physical_liquid_values()
		if publication.is_empty() or _pending_physical_candidate == null: return
		if int(publication.get("serial",0)) != int(pending_microscenario_apply.get("serial",-1)): return
		if simulation_worker.complete_prepared_physical_liquid(publication,false,"Strata mounted fixture rejected the prepared Play ACK"):
			refused_identity = publication.duplicate(true)
			reject_prepared_once = false
			_prepared_physical_ready_sent = true


class PrefixExecutor extends "res://scripts/workbench_paint_editor_executor.gd":
	func _protection_error(world: Variant, point: Vector2i) -> String:
		if command.kind == "edit" and status == "executing" and applied >= 1:
			return "Strata mounted fixture stopped after one real native cell"
		return super._protection_error(world,point)


class FaultOwner extends "res://scripts/depth/workbench_layer_owner.gd":
	var partial_once := false
	var publication_once := false
	func _make_executor() -> RefCounted:
		if partial_once:
			partial_once = false
			return PrefixExecutor.new()
		return super._make_executor()
	func _take_snapshot(world: Object) -> Dictionary:
		if publication_once:
			publication_once = false
			return {"failed":true,"error":"Strata mounted fixture refused the committed plane publication"}
		return super._take_snapshot(world)


func _fixture_scene() -> Dictionary:
	var setup := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
	setup.edits = [[8,456,496,8,58]]
	setup.actors = [Setup.instance(Setup.Fleet.stable_id(0),1,Vector2(256,200))]
	setup.next_id = 2
	var doc := Document.default_document(Vector2i(512,512))
	doc.presentation.enabled = true
	doc.presentation.active = "scripted"
	Document.plane(doc,"scripted").rectangles = [[20,20,12,12,13]]
	return {"setup":setup,"document":doc}


func run() -> void:
	scene_id = "mounted-failure-fixtures"
	phase = "native-faults"
	output = OS.get_environment("STRATA_EVIDENCE")
	record = {"schema":"strata2-mounted-failures-v1","completed":false,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_server":DisplayServer.get_name(),"process_id":OS.get_process_id(),
		"scope":"Actual ordinary Main/Workbench, native decorative writes and prepared Play refusal; graphical capture is supplemental."}
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(RejectingHost)
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	if not await until(idle,"ordinary 512 fixture admission",180000): finish(); return
	strata = wb.ensure_strata()
	strata.layer_owner.retire()
	var fault_owner := FaultOwner.new()
	strata.layer_owner = fault_owner
	if not check(strata.load_document(_fixture_scene()),"real fixture candidate requested"):
		finish(); return
	if not await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null,"real fixture adopted"):
		finish(); return
	var stable_play := play_identity()
	var play_before := await play_bytes()
	check(fault_owner.stats().native_world_count == 3,"fixture has exactly three decorative Worlds")
	check(not fault_owner.stats().owns_play_world,"fixture never owns Play")

	# A true executor prefix mutates one cell; the second is blocked by an
	# injected protection refusal. The owner must quarantine the affected plane.
	var authored_before: Dictionary = strata.document()
	var actual_before := PackedInt32Array([fault_owner.material_at("scripted",Vector2i(70,70)),fault_owner.material_at("scripted",Vector2i(71,70))])
	fault_owner.partial_once = true
	var prefix_return: bool = strata.edit_cells("scripted",PackedInt32Array([70,70,131,71,70,131]))
	var prefix_receipt: Dictionary = strata.last_edit_receipt.duplicate(true)
	var actual_after := PackedInt32Array([fault_owner.material_at("scripted",Vector2i(70,70)),fault_owner.material_at("scripted",Vector2i(71,70))])
	check(not prefix_return and prefix_receipt.get("status") == "partial" and prefix_receipt.get("applied") == 1,"actual partial receipt is not full completion")
	check(actual_before == PackedInt32Array([0,0]) and actual_after == PackedInt32Array([131,0]),"partial prefix independently read from actual native cells")
	check(fault_owner.stats().layers.scripted.failed and not fault_owner.can_edit("scripted"),"partial native owner quarantined")
	check(strata.document() == authored_before and fault_owner.stats().layers.scripted.undo == 0,"partial native mutation does not invent authored commit or history")
	check(fault_owner.material_at("effects",Vector2i(70,70)) == 0 and fault_owner.material_at("background",Vector2i(70,70)) == 0,"partial fault stays in selected plane")
	stable_identity(stable_play,play_identity(),"partial decorative native fault")
	record.partial = {"receipt":prefix_receipt,"native_before":Array(actual_before),"native_after":Array(actual_after),
		"authored_retained":strata.document() == authored_before,"quarantined":fault_owner.stats().layers.scripted.failed}

	# Rebuild only decoration from its retained baseline. Borrowed Play and its
	# actor graph stay mounted throughout this owner replacement.
	var retired_owner_id: String = fault_owner.stats().layers.scripted.owner_id
	check(strata._prepare(authored_before) and strata._adopt(),"decorative recovery adopts a complete fresh candidate")
	check(fault_owner.material_at("scripted",Vector2i(70,70)) == 0,"recovery restores authored baseline, excluding failed prefix")
	check(fault_owner.stats().layers.scripted.owner_id != retired_owner_id,"retired decorative owner identity replaced")
	stable_identity(stable_play,play_identity(),"decorative recovery")

	# A committed native edit with a failed copied publication remains committed.
	var surface: SubViewport = strata.presenter._surfaces.effects
	var pixels_before := digest(surface.cell_image.get_data())
	var revision_before: int = Document.plane(strata.document(),"effects").revision
	fault_owner.publication_once = true
	var committed_return: bool = strata.edit_cells("effects",PackedInt32Array([90,90,131]))
	var committed_receipt: Dictionary = strata.last_edit_receipt.duplicate(true)
	check(committed_return and committed_receipt.get("ok",false) and not committed_receipt.get("published",true),"native ACK remains success when later publication fails")
	check(fault_owner.material_at("effects",Vector2i(90,90)) == 131,"committed mutation independently survives publication fault")
	check(Document.plane(strata.document(),"effects").revision == revision_before+1 and fault_owner.stats().layers.effects.undo == 1,"committed authored revision and Undo retained")
	check(digest(surface.cell_image.get_data()) == pixels_before,"failed publication retains previous copied material pixels")
	check(strata._publication_errors.has("effects") and not strata.edit_cells("effects",PackedInt32Array([91,90,131])),"stale view blocks another edit")
	var saved_document: Dictionary = strata.document()
	var name := "strata2-committed-stale-view"
	check(strata.save_named(name),"committed authored layout saves despite stale view")
	var loaded := Document.read_named(name)
	check(loaded.get("layered",false) and loaded.document == saved_document,"saved layout contains exact committed revision")
	stable_identity(stable_play,play_identity(),"committed decorative publication fault")
	record.committed_stale_view = {"receipt":committed_receipt,"returned_committed":committed_return,
		"native_after":fault_owner.material_at("effects",Vector2i(90,90)),"revision_before":revision_before,
		"revision_after":Document.plane(strata.document(),"effects").revision,"copied_pixels_sha256":pixels_before,
		"copied_pixels_retained":digest(surface.cell_image.get_data()) == pixels_before,"saved_sha256":FileAccess.get_sha256(Setup._path(name))}
	check(strata._prepare(saved_document) and strata._adopt(),"reopen committed decoration through complete candidate")
	check(fault_owner.material_at("effects",Vector2i(90,90)) == 131 and not strata._publication_errors.has("effects"),"native committed cell and current pixels recovered")

	# Reject the actual prepared Play handshake before native adoption. The
	# ordinary host/worker rejection path must cancel all candidate decoration.
	var previous_document: Dictionary = strata.document()
	var previous_owner_stats: Dictionary = fault_owner.stats()
	var play_before_rejection := play_identity()
	host.reject_prepared_once = true
	check(strata.load_document({"setup":wb.applied.duplicate(true),"document":previous_document}),"complete replacement reaches real prepared Play path")
	check(fault_owner.stats().pending_native_world_count == 3,"three candidate decorative owners are private before Play ACK")
	if not await until(func() -> bool: return idle() and strata._pending.is_empty() and not host.refused_identity.is_empty(),"failed Play ACK cancels candidate"):
		finish(); return
	check(not host.reject_prepared_once,"test rejected the actual prepared native identity")
	check(strata.document() == previous_document,"failed Play ACK retains previous complete document")
	for id: String in ["scripted","effects","background"]:
		check(fault_owner.stats().layers[id].native_instance_id == previous_owner_stats.layers[id].native_instance_id,"failed Play ACK retains real previous owner "+id)
	check(fault_owner.stats().pending_native_world_count == 0,"failed Play ACK retires every candidate owner")
	stable_identity(play_before_rejection,play_identity(),"failed real Play ACK")
	var play_after := await play_bytes()
	check(play_before == play_after,"all fault paths preserve actual Play material bytes")
	record.failed_play_ack = {"serial":host.refused_identity.get("serial",0),"epoch":host.refused_identity.get("epoch",0),
		"instance_id":str(host.refused_identity.get("instance_id",0)),"before":play_before_rejection,"after":play_identity(),
		"pending_native_worlds":fault_owner.stats().pending_native_world_count,"previous_document_retained":strata.document() == previous_document,
		"host_reason":host.microscenario_error}
	record.play_hash_before = digest(play_before)
	record.play_hash_after = digest(play_after)
	if DisplayServer.get_name() != "headless" and not output.is_empty(): await capture("recovered-mounted-faults")
	print("STRATA2_MOUNTED_FAILURES ",JSON.stringify({"checks":checks,"failures":failures,"native_play_hash":record.play_hash_after}))
	finish()
