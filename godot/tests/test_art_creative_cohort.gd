extends SceneTree
## Predeclared fixture cohort: copied-value controls, not native mutation or LLM
## creativity. Held-out labels are reserved for the future owner-model cohort.
const Context = preload("res://scripts/art_world_context.gd")
const Proposal = preload("res://scripts/art_authoring_proposal.gd")
const Preview = preload("res://scripts/art_authoring_preview.gd")
const Examples = preload("res://scripts/art_creative_examples.gd")
var checks := 0
var failures := 0
var outcomes: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_CREATIVE_COHORT_CHECK ",label," ",ok)
	if not ok: failures += 1; push_error(label)

func base_capture(example: Dictionary, region: Rect2i) -> Dictionary:
	var cells := PackedInt32Array()
	cells.resize(region.size.x*region.size.y)
	cells.fill(0)
	for op: Dictionary in example.setup_operations:
		for y: int in range(op.y0,op.y1+1):
			for x: int in range(op.x0,op.x1+1):
				cells[(y-region.position.y)*region.size.x+x-region.position.x] = op.material
	return {"status":"completed","kind":"capture","backend":"CyberNativeCellWorld",
		"region":region,"materials":cells,"generation":2,"revision":10,"tick":0,
		"authoring_generation":1,"observed_generation":2}

func predict(compiled: Dictionary, context: Dictionary) -> Dictionary:
	var preview := Preview.new()
	if not preview.configure(compiled,context): return preview.result
	var deadline := Time.get_ticks_msec()+30000
	while preview.active and Time.get_ticks_msec()<deadline:
		preview.poll()
		if preview.active: await process_frame
	check(not preview.active,"fixture preview terminates")
	return preview.result

func replacement_packet(op: Dictionary) -> Dictionary:
	return {"schema":Proposal.SCHEMA,"title":"Fixture adversary","stages":[{"id":"change","title":"Change",
		"depends_on":[],"operations":[op]}]}

func fixture_op(material: int = 58) -> Dictionary:
	return {"shape":"rectangle","x0":4,"y0":4,"x1":11,"y1":7,"material":material}

func run() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_collaborative_briefs.json"))
	check(data is Dictionary and data.get("briefs",[]).size()==24,"24 distinct owner-style briefs are present")
	if not data is Dictionary: quit(1); return
	var ids := {}
	var prompts := {}
	var retained_refusals := 0
	for brief: Dictionary in data.briefs:
		check(not ids.has(brief.id) and not prompts.has(brief.prompt),"brief identity and text are distinct "+brief.id)
		ids[brief.id] = true
		prompts[brief.prompt] = true
		var region := Rect2i(0,0,256,192)
		var example := Examples.make(brief.scenario,region,[0,28,58])
		check(example.ok,"scenario generator available "+brief.id)
		if not example.ok: continue
		var rules: Dictionary = example.brief.duplicate(true)
		rules.objective = brief.prompt
		rules.extent = region.size
		rules.region = region
		rules.protected = example.protected.duplicate()
		rules.allowed = [0,28,58]
		var capture := base_capture(example,region)
		var raw: Dictionary = example.proposal.duplicate(true)
		var previous: Dictionary = {}
		var expected := "ready"
		var intermediate: Dictionary = {}
		match str(brief.fixture_case):
			"unresolved":
				raw.unresolved = ["Name or select the important structure before changing it."]
				expected = "refused"
			"single_stage":
				raw.stages = [raw.stages[0]]
			"remove_stage":
				var original_context := Context.build(capture,rules)
				previous = Proposal.compile(raw,original_context,rules)
				raw.stages.pop_back()
				raw.title = "Reduced detail"
			"revision_title_and_geometry":
				var original_context := Context.build(capture,rules)
				previous = Proposal.compile(raw,original_context,rules)
				raw.title = "Taller reviewed revision"
				raw.stages[0].operations[0].y1 = int(raw.stages[0].operations[0].y1)+2
			"protected_conflict":
				raw = replacement_packet({"shape":"rectangle","x0":0,"y0":0,"x1":255,"y1":191,"material":58})
				expected = "refused"
			"outside_palette":
				raw = replacement_packet(fixture_op(29))
				expected = "refused"
			"erase_without_permission":
				raw = replacement_packet(fixture_op(0))
				expected = "refused"
			"unsupported_part":
				raw = replacement_packet({"shape":"place_module","name":"motorized-elevator","material":58})
				expected = "refused"
			"protected_source":
				capture.materials[4*256+4] = 28
				raw = replacement_packet(fixture_op())
				expected = "refused"
			"repair_conflict":
				var original_context := Context.build(capture,rules)
				var bad := replacement_packet({"shape":"rectangle","x0":0,"y0":0,"x1":255,"y1":191,"material":58})
				previous = Proposal.compile(bad,original_context,rules)
				intermediate = await predict(previous,original_context)
				check(not intermediate.ok,"first protected-conflict revision remains refused")
				raw = replacement_packet(fixture_op())
				raw.title = "Scoped safe side-gallery repair"
			"stale_source":
				expected = "stale_refused"
		var context := Context.build(capture,rules)
		check(context.ok,"bounded fixture context "+brief.id)
		var compiled := Proposal.compile(raw,context,rules,previous)
		var result := {"ok":false,"status":"refused","error":compiled.get("error","")}
		if compiled.ok:
			if brief.fixture_case == "stale_source":
				var current_context := context.duplicate(true)
				current_context.source.revision += 1
				var stale := Preview.new()
				var accepted := stale.configure(compiled,current_context)
				check(not accepted,"changed source cannot reuse old preview "+brief.id)
				result = stale.result
				result.status = "stale_refused"
			else:
				result = await predict(compiled,context)
		check(str(result.status)==expected,"retained creative outcome "+brief.id+" / "+str(result.get("error","")))
		if result.status!="ready": retained_refusals += 1
		if not previous.is_empty() and compiled.ok:
			check(compiled.diff.parent_digest==previous.proposal_digest,"revised proposal retains exact lineage "+brief.id)
			check(compiled.policy_digest==previous.policy_digest,"revised proposal keeps owner constraints "+brief.id)
		if brief.fixture_case == "stop_prefix":
			check(compiled.budget.candidate_cells>4096,"Stop brief has more than one native chunk of candidate work")
		var ablation := {}
		if compiled.ok and result.status=="ready":
			var without_rules := rules.duplicate(true)
			without_rules.include_knowledge = false
			var without_context := Context.build(capture,without_rules)
			var without_compiled := Proposal.compile(raw,without_context,without_rules)
			var without_result: Dictionary = await predict(without_compiled,without_context)
			var same: bool = bool(without_result.ok) and without_result.predicted_materials_sha256==result.predicted_materials_sha256
			check(same,"fixed-packet knowledge ablation does not invent a geometry effect "+brief.id)
			ablation = {"same_geometry":same,"with_knowledge_bytes":context.inspector.bytes,
				"without_knowledge_bytes":without_context.inspector.bytes,"causal_creativity_claim":false}

			var single_operations: Array = []
			for stage: Dictionary in compiled.stages: single_operations.append_array(stage.operations)
			var single_raw := replacement_packet(single_operations[0])
			single_raw.stages[0].operations = single_operations
			var single_compiled := Proposal.compile(single_raw,context,rules)
			var single_result: Dictionary = await predict(single_compiled,context)
			check(single_result.get("ok",false) and single_result.predicted_materials_sha256==result.predicted_materials_sha256,
				"matched single-stage and staged proposal geometry agrees "+brief.id)
			var no_summary_rules := rules.duplicate(true)
			no_summary_rules.include_native_summary = false
			var no_summary_context := Context.build(capture,no_summary_rules)
			check(not no_summary_context.model.has("native_samples") and not no_summary_context.model.has("coarse_occupancy"),
				"owner-disabled native summaries are absent from model payload "+brief.id)
			var no_summary_result: Dictionary = await predict(Proposal.compile(raw,no_summary_context,no_summary_rules),no_summary_context)
			check(no_summary_result.get("ok",false) and no_summary_result.predicted_materials_sha256==result.predicted_materials_sha256,
				"native-summary ablation preserves identical fixed-packet geometry "+brief.id)
			ablation.single_stage_same_geometry = single_result.get("ok",false) and single_result.predicted_materials_sha256==result.predicted_materials_sha256
			ablation.native_summary_disabled_same_geometry = no_summary_result.get("ok",false) and no_summary_result.predicted_materials_sha256==result.predicted_materials_sha256
			ablation.native_summary_disabled_bytes = no_summary_context.inspector.bytes
		outcomes.append({"id":brief.id,"split":brief.split,"kind":brief.kind,"fixture_case":brief.fixture_case,
			"expected":expected,"actual":result.status,"error":result.get("error",""),
			"scenario":brief.scenario,"intermediate_refusal":intermediate,"knowledge_ablation":ablation,
			"provenance":"Known deterministic fixture mapping; copied native-value-shaped arrays, no World mutation.",
			"model_calls":0,"native_calls":0})
	check(outcomes.size()==24,"all 24 outcomes retained without dropping refusals")
	check(retained_refusals==7,"seven specified adversarial/ambiguous/stale outcomes retained")
	var output := OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output+"/creative-fixture-cohort.json",FileAccess.WRITE)
		check(file!=null,"fixture cohort evidence available")
		if file!=null: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"outcomes":outcomes,
			"limits":data.evidence_limits},"\t")+"\n")
	print("ART_CREATIVE_COHORT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"briefs":outcomes.size(),"retained_refusals":retained_refusals,"native_calls":0,"model_calls":0,
		"evidence_kind":"deterministic copied-value fixture cohort; no real-model creativity claim"}))
	quit(1 if failures else 0)
