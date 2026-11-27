extends SceneTree
## Real ordinary Workbench native construction. No model dispatch. Exact preview
## predictions are compared with original native receipts and fresh native capture.
const Context = preload("res://scripts/art_world_context.gd")
const Proposal = preload("res://scripts/art_authoring_proposal.gd")
const Preview = preload("res://scripts/art_authoring_preview.gd")
const Examples = preload("res://scripts/art_creative_examples.gd")
var main: Control
var wb
var panel
var executor
var checks := 0
var failures := 0
var output := ""
var outcomes: Array = []
var originals: Array = []

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",2)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_COLLAB_NATIVE_CHECK ",label," ",ok)
	if not ok: failures += 1; push_error(label)

func until(predicate: Callable, label: String, milliseconds: int = 90000) -> bool:
	var deadline := Time.get_ticks_msec()+milliseconds
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	var ok: bool = predicate.call()
	check(ok,label)
	return ok

func installed() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() \
		and main.pending_microscenario_apply.is_empty()

func write_json(name: String, value: Variant) -> void:
	if output.is_empty(): return
	var file := FileAccess.open(output+"/"+name,FileAccess.WRITE)
	check(file != null,"evidence open "+name)
	if file != null: file.store_string(JSON.stringify(value,"\t")+"\n")

func native_png(name: String, receipt: Dictionary) -> void:
	if output.is_empty() or receipt.get("status","") != "completed": return
	var region: Rect2i = receipt.region
	var bytes := PackedByteArray()
	bytes.resize(receipt.materials.size())
	for index: int in bytes.size(): bytes[index] = int(receipt.materials[index])
	var picture := Image.create_from_data(region.size.x,region.size.y,false,Image.FORMAT_R8,bytes)
	check(picture.save_png(output+"/"+name)==OK,"native material diagnostic PNG "+name)

func capture_region(region: Rect2i) -> Dictionary:
	var box: Array = [{}]
	var callback := func(receipt: Dictionary) -> void: box[0] = receipt.duplicate(true)
	var admission: Dictionary = wb.paint_editor.art_context_capture(region,callback)
	if not admission.get("ok",false):
		check(false,"native observation admission / "+str(admission.get("error","")))
		return {}
	if not await until(func(): return not box[0].is_empty(),"native observation completion"): return {}
	check(box[0].get("status","")=="completed" and box[0].get("backend","")=="CyberNativeCellWorld",
		"native stored-material capture authority")
	return box[0]

func fixture_policy(example: Dictionary, region: Rect2i) -> Dictionary:
	var result: Dictionary = example.brief.duplicate(true)
	result.extent = wb.Setup.extent_of(wb.applied)
	result.region = region
	result.protected = example.protected.duplicate()
	result.allowed = [0,28,58]
	result.include_knowledge = true
	result.tool = "Art finite staged construction"
	return result

func build_preview(compiled: Dictionary, context: Dictionary) -> Dictionary:
	var preview := Preview.new()
	check(preview.configure(compiled,context),"zero-write preview configured")
	if not preview.active: return preview.result
	await until(func():
		preview.poll()
		return not preview.active,"finite exact geometry preview")
	return preview.result

func render_scene(region: Rect2i, name: String) -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	panel.hide()
	wb._set_view(Vector2(region.position),region.size)
	for frame: int in 5: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name)==OK,"actual ordinary Workbench framebuffer "+name)

func case_region(index: int) -> Rect2i:
	if index < 6: return Rect2i(32+(index%3)*288,32+(index/3)*224,256,192)
	if index == 6: return Rect2i(32,512,384,256)
	if index == 7: return Rect2i(960,32,512,512)
	return Rect2i(480,512,384,256)


func matched_direct_control(index: int, entry: Dictionary, example: Dictionary, compiled: Dictionary, expected_sha: String, region: Rect2i) -> Dictionary:
	var shift := Vector2i(0,1024)
	var target := Rect2i(region.position+shift,region.size)
	var baseline: Array = []
	for operation: Dictionary in example.setup_operations: baseline.append(Proposal._translate(operation,shift))
	var start_result: Dictionary = executor.submit(baseline,target,[],[0,58])
	check(start_result.status=="queued","matched direct baseline admission "+entry.id)
	await until(func(): return not executor.active,"matched direct baseline native completion")
	var operations: Array = []
	for stage: Dictionary in compiled.stages:
		for operation: Dictionary in stage.operations: operations.append(Proposal._translate(operation,shift))
	var guards: Array = []
	for guard: Rect2i in example.protected: guards.append(Rect2i(guard.position+shift,guard.size))
	var receipts: Array = []
	var on_receipt := func(receipt: Dictionary) -> void: receipts.append(receipt.duplicate(true))
	executor.native_receipt.connect(on_receipt)
	var started := Time.get_ticks_usec()
	var admitted: Dictionary = executor.submit(operations,target,guards,[0,28,58])
	check(admitted.status=="queued","existing direct matched-geometry submission "+entry.id)
	await until(func(): return not executor.active,"existing direct matched-geometry terminal")
	var elapsed := Time.get_ticks_usec()-started
	executor.native_receipt.disconnect(on_receipt)
	check(executor.result.status=="completed","existing direct authoritative completion")
	var after: Dictionary = await capture_region(target)
	var matches: bool = after.get("status","")=="completed" and Context.hash_materials(after.materials)==expected_sha
	check(matches,"matched direct and staged native material planes are identical "+entry.id)
	var changed := 0
	var checked := 0
	for receipt: Dictionary in receipts:
		check(receipt.get("backend","")=="CyberNativeCellWorld","matched direct uses the real native backend")
		changed += int(receipt.get("changed",0))
		checked += int(receipt.get("checked",0))
	write_json("%02d-%s-direct-original-native-receipts.json" % [index,entry.id],receipts)
	return {"arm":"existing_direct_matched_geometry","region":Context.rect_values(target),
		"native_changed":changed,"native_checked":checked,"native_chunks":receipts.size(),
		"elapsed_usec":elapsed,"native_execution_usec":elapsed,
		"timing_scope":"Single ordinary executor submit through executor terminal; excludes baseline setup, native readback and artifacts.",
		"complete_material_plane_matches":matches,
		"material_sha256":Context.hash_materials(after.get("materials",PackedInt32Array())),
		"interpretation":"Same deterministic geometry and same protected areas; this measures execution compatibility/cost, not model creativity."}

func frozen_context_ablation(example: Dictionary, before: Dictionary, rules: Dictionary, expected_sha: String) -> Dictionary:
	var without_rules := rules.duplicate(true)
	without_rules.include_knowledge = false
	var without_context := Context.build(before,without_rules)
	var without_compiled := Proposal.compile(example.proposal,without_context,without_rules)
	var without_result: Dictionary = await build_preview(without_compiled,without_context)
	var same: bool = bool(without_result.get("ok",false)) and without_result.predicted_materials_sha256==expected_sha
	check(same,"identical proposal knowledge ablation yields identical predicted geometry")
	check(without_context.model.knowledge.cards.is_empty(),"knowledge-disabled context sends no knowledge cards")
	return {"arm":"knowledge_disabled_fixed_proposal","same_predicted_material_plane":same,
		"context_bytes":without_context.inspector.bytes,"model_calls":0,
		"interpretation":"Frozen identical packets; no causal retrieval or creative improvement can be inferred."}

func exercise(index: int, entry: Dictionary) -> void:
	var region := case_region(index)
	var example := Examples.make(entry.id,region,[0,28,58])
	check(example.ok,"fixture "+entry.id+" fits admitted native scope")
	if not example.ok: return
	var baseline: Dictionary = executor.submit(example.setup_operations,region,[],[0,58])
	check(baseline.status=="queued","ordinary direct baseline admitted")
	if not await until(func(): return not executor.active,"ordinary direct baseline native completion"): return
	check(executor.result.status=="completed","baseline native result completed")
	var before: Dictionary = await capture_region(region)
	if before.get("status","")!="completed": return
	var before_sha := Context.hash_materials(before.materials)
	native_png("%02d-%s-before-native.png" % [index,entry.id],before)
	await render_scene(region,"%02d-%s-before-workbench.png" % [index,entry.id])
	var rules := fixture_policy(example,region)
	var context := Context.build(before,rules)
	check(context.ok,"bounded current native context "+entry.id)
	if not context.ok: return
	var compiled := Proposal.compile(example.proposal,context,rules)
	check(compiled.ok,"typed proposal compiles "+entry.id+" / "+str(compiled.get("error","")))
	if not compiled.ok: return
	var predicted: Dictionary = await build_preview(compiled,context)
	check(predicted.get("ok",false),"exact no-write preview "+entry.id+" / "+str(predicted.get("error","")))
	if not predicted.get("ok",false): return
	var untouched: Dictionary = await capture_region(region)
	check(Context.hash_materials(untouched.materials)==before_sha,"complete preview left the actual native material plane unchanged")
	var latest := untouched
	var native_chunks: Array = []
	var changed := 0
	var checked := 0
	var native_execution_usec := 0
	var stage_timings: Array = []
	var started := Time.get_ticks_usec()
	for stage_index: int in compiled.stages.size():
		var stage: Dictionary = compiled.stages[stage_index]
		var stage_receipts: Array = []
		var on_receipt := func(receipt: Dictionary) -> void:
			stage_receipts.append(receipt.duplicate(true))
		executor.native_receipt.connect(on_receipt)
		var stage_started := Time.get_ticks_usec()
		var admitted: Dictionary = executor.submit_guarded(stage.operations,stage.scope,stage.guards,stage.allowed,
			Context.source_of(latest),bool(compiled.allow_destructive),int(stage.budget.candidate_cells))
		check(admitted.status=="queued","fresh explicit fixture-stage approval "+entry.id+"/"+stage.id)
		if admitted.status=="queued":
			await until(func(): return not executor.active,"native stage terminal "+entry.id+"/"+stage.id)
		var stage_execution_usec := Time.get_ticks_usec()-stage_started
		native_execution_usec += stage_execution_usec
		stage_timings.append({"stage":stage.id,"native_execution_usec":stage_execution_usec,
			"admission":str(admitted.get("status","")),"terminal":str(executor.result.get("status",""))})
		executor.native_receipt.disconnect(on_receipt)
		check(executor.result.status=="completed","native stage completion is authoritative")
		var stage_changed := 0
		var stage_checked := 0
		for receipt: Dictionary in stage_receipts:
			check(receipt.get("backend","")=="CyberNativeCellWorld","original receipt identifies real native backend")
			check(receipt.get("status","")=="completed","original chunk receipt completed")
			stage_changed += int(receipt.get("changed",0))
			stage_checked += int(receipt.get("checked",0))
			native_chunks.append(receipt)
		changed += stage_changed
		checked += stage_checked
		check(stage_checked==int(predicted.stages[stage_index].requested),"native requested cells match exact preview")
		check(stage_changed==int(predicted.stages[stage_index].predicted_changed),"native changed cells match exact preview")
		latest = await capture_region(region)
		if latest.get("status","")!="completed": return
		check(Context.hash_materials(latest.materials)==predicted.stages[stage_index].after_materials_sha256,
			"complete native plane equals stage preview "+stage.id)
	var empty_routes := true
	for route: Rect2i in example.expected_routes:
		for y: int in range(route.position.y,route.end.y):
			for x: int in range(route.position.x,route.end.x):
				if int(latest.materials[(y-region.position.y)*region.size.x+x-region.position.x]) != 0:
					empty_routes = false
	check(empty_routes,"declared static clearance rectangles remain Empty (not an actor-reachability claim)")
	var protected_unchanged := true
	for guard: Rect2i in example.protected:
		for y: int in range(guard.position.y,guard.end.y):
			for x: int in range(guard.position.x,guard.end.x):
				var at := (y-region.position.y)*region.size.x+x-region.position.x
				if latest.materials[at] != before.materials[at]: protected_unchanged=false
	check(protected_unchanged,"every protected native cell remains byte-identical")
	var after_sha := Context.hash_materials(latest.materials)
	check(after_sha==predicted.predicted_materials_sha256,"final entire native material plane matches predicted geometry")
	native_png("%02d-%s-after-native.png" % [index,entry.id],latest)
	await render_scene(region,"%02d-%s-after-workbench.png" % [index,entry.id])
	var staged_elapsed := Time.get_ticks_usec()-started
	var direct_comparison: Dictionary = await matched_direct_control(index,entry,example,compiled,after_sha,region)
	var context_comparison: Dictionary = await frozen_context_ablation(example,before,rules,after_sha)
	wb._name.text = "art-collaborative-"+str(entry.id)
	check(wb.save_setup(),"ordinary native authored-start Save "+entry.id+" / "+str(wb.message))
	if not output.is_empty():
		var saved := FileAccess.get_file_as_string(wb.Setup._path(wb._name.text))
		var target := FileAccess.open(output+"/%02d-%s-editable-setup.json" % [index,entry.id],FileAccess.WRITE)
		check(target != null and not saved.is_empty(),"editable ordinary Setup artifact available")
		if target != null: target.store_string(saved)
	var outcome := {"id":entry.id,"title":entry.title,"evidence_kind":example.evidence_kind,
		"region":Context.rect_values(region),"before_materials_sha256":before_sha,"after_materials_sha256":after_sha,
		"stages":compiled.stages.size(),"native_chunks":native_chunks.size(),"native_checked":checked,
		"native_changed":changed,"preview_changed":predicted.predicted_changed,
		"constraint_preservation":protected_unchanged,"static_clearance":empty_routes,
		"route_claim":example.route_claim,"elapsed_usec":staged_elapsed,
		"native_execution_usec":native_execution_usec,"stage_timings":stage_timings,
		"timing_scope":"elapsed_usec includes all stage execution, verification captures, constraint checks and after-image artifacts. native_execution_usec sums only each guarded submit through executor terminal.",
		"timing_caveat":"Compare only equally scoped native_execution_usec as observed fixture costs. Fixed arm order and different stage boundaries are not a randomized performance experiment; broad elapsed_usec is not comparable with the direct-arm elapsed_usec.",
		"comparisons":[direct_comparison,context_comparison],
		"source_before":Context.source_of(before),"source_after":Context.source_of(latest),
		"context_inspector":context.inspector,"proposal":compiled.proposal,"preview":predicted}
	outcomes.append(outcome)
	originals.append({"region":region,"sha":after_sha})
	write_json("%02d-%s-result.json" % [index,entry.id],outcome)
	write_json("%02d-%s-original-native-receipts.json" % [index,entry.id],native_chunks)

func run() -> void:
	output = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if output.is_empty(): output = OS.get_environment("WB_ART_EVIDENCE_DIR")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,1000)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	wb = main.shared_workbench
	if not await until(installed,"ordinary native Workbench ready"): quit(1); return
	check(wb.art_batches==null,"ordinary startup sends no model request and does not initialize Art")
	panel = wb._ensure_art_batches()
	executor = panel.executor
	check(main.paused,"native creative campaign uses acknowledged paused authoring")
	check(wb.paint_editor.has_method("art_context_capture"),"one PAINT owner supplies copied native context")
	check(executor.has_method("submit_guarded"),"guarded stages reuse existing Art executor")
	if not wb.paint_editor.has_method("art_context_capture") or not executor.has_method("submit_guarded"):
		quit(1)
		return
	var entries := Examples.catalogue()
	for index: int in entries.size():
		await exercise(index,entries[index])
	check(outcomes.size()==9,"nine substantial ordinary native authoring examples retained")
	wb._name.text = "art-collaborative-atlas"
	check(wb.save_setup(),"complete ordinary native atlas saved")
	check(wb.load_setup(),"saved native atlas reopens through ordinary Workbench")
	await until(installed,"ordinary native saved-start reload completes")
	for original: Dictionary in originals:
		var restored: Dictionary = await capture_region(original.region)
		check(restored.get("status","")=="completed" and Context.hash_materials(restored.materials)==original.sha,
			"reopened native example reproduces its complete material plane")
	var summary := {"checks":checks,"failures":failures,"scenarios":outcomes.size(),
		"model_requests":0,"fixture_label":"Deterministic host-authored proposals, real ordinary Workbench native operations.",
		"source_policy":[0,58],"claims":"Compiler/context/lifecycle/native geometry evidence; no LLM creativity or retrieval causality claim.",
		"outcomes":outcomes}
	write_json("creative-native-summary.json",summary)
	print("ART_COLLABORATIVE_NATIVE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"scenarios":outcomes.size(),"model_requests":0,"evidence_kind":summary.fixture_label}))
	main.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
