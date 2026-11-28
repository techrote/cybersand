extends SceneTree
## Controlled pure-value comparison over original recorded native material
## planes. No live World, new PAINT receipt, provider or model is created.
const Context = preload("res://scripts/art_world_context.gd")
const Baseline = preload("res://tests/fixtures/art_world_context_scan_baseline_0e93.gd")
const Examples = preload("res://scripts/art_creative_examples.gd")
const BASELINE_SOURCE := "0e93cc9093aee4ddf7429c7b008a48ec87c06fd5"
const ORIGINAL_NATIVE_SOURCE := "2743f89a0df6f6afcf7484e859c10790d521e74b"
const CASES := [[0,"industrial_repair","before"],[6,"stopped_workshop","before"],
	[7,"staged_megaframe","before"],[8,"xeno_vault","before"],[7,"staged_megaframe","after"]]
const REPETITIONS := 8
var checks := 0
var failures: Array = []
var outcomes: Array = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
	return ok

func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func script_hash(path: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(FileAccess.get_file_as_bytes(path))
	return hashing.finish().hex_encode()

func replay_input(directory: String, entry: Array) -> Dictionary:
	var prefix := "%02d-%s" % [entry[0],entry[1]]
	var plane: String = str(entry[2])
	var record := read_json(directory+"/"+prefix+"-result.json")
	var saved := read_json(directory+"/"+prefix+"-editable-setup.json")
	if not check(not record.is_empty() and not saved.is_empty(),"original native metadata and Setup "+prefix): return {}
	var rect: Array = record.get("region",[])
	var extent: Array = saved.get("extent",[])
	if not check(rect.size()==4 and extent.size()==2,"original native region and dimensions "+prefix): return {}
	var region := Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3]))
	var picture := Image.load_from_file(directory+"/"+prefix+"-"+plane+"-native.png")
	if not check(picture!=null and picture.get_size()==region.size,"original native diagnostic dimensions "+prefix+" "+plane): return {}
	picture.convert(Image.FORMAT_RGBA8)
	var rgba := picture.get_data()
	var cells := PackedInt32Array()
	cells.resize(region.size.x*region.size.y)
	for index: int in cells.size(): cells[index]=int(rgba[index*4])
	var original_hash := str(record.get(plane+"_materials_sha256",""))
	if not check(Context.hash_materials(cells)==original_hash,
		"PNG-derived bytes reproduce the original actual int32 material-plane hash "+prefix+" "+plane): return {}
	var example := Examples.make(str(entry[1]),region,[0,28,58])
	if not check(example.get("ok",false),"source-matched deterministic host policy "+prefix): return {}
	var rules: Dictionary = example.brief.duplicate(true)
	rules.extent=Vector2i(int(extent[0]),int(extent[1]))
	rules.region=region
	rules.protected=example.protected.duplicate()
	rules.allowed=[0,28,58]
	rules.include_knowledge=true
	rules.tool="Art finite staged construction"
	var native_source: Dictionary = record["source_"+plane]
	var captured: Dictionary = {"status":"completed","kind":"capture","backend":"CyberNativeCellWorld",
		"region":region,"materials":cells}
	for key: String in ["generation","revision","tick","authoring_generation"]: captured[key]=int(native_source[key])
	captured.observed_generation=captured.generation
	return {"id":str(entry[1])+":"+plane,"capture":captured,"policy":rules,"region":rect,
		"original_plane_sha256":original_hash,"native_plane":plane}

func measure(candidate: bool, input: Dictionary) -> Dictionary:
	var began := Time.get_ticks_usec()
	var value: Dictionary
	if candidate: value=Context.build(input.capture,input.policy)
	else: value=Baseline.build(input.capture,input.policy)
	var callsite := Time.get_ticks_usec()-began
	var phases: Dictionary = value.get("inspector",{}).get("timings_usec",{}).duplicate(true)
	phases.callsite=callsite
	return {"value":value,"timings_usec":phases}

func equal_contexts(first: Dictionary, second: Dictionary, label: String) -> bool:
	if not check(first.get("ok",false) and second.get("ok",false),"both context algorithms complete "+label): return false
	var public_first: Dictionary=first.inspector.duplicate(true)
	var public_second: Dictionary=second.inspector.duplicate(true)
	for key: String in ["timings_usec","elapsed_usec"]:
		public_first.erase(key)
		public_second.erase(key)
	return check(first.digest==second.digest and first.policy_digest==second.policy_digest \
		and JSON.stringify(first.model)==JSON.stringify(second.model) \
		and first._capture==second._capture and first._policy==second._policy \
		and public_first==public_second,"exact model, context digest, source, private capture and inspector "+label)

func medians(samples: Array, arm: String) -> Dictionary:
	var result: Dictionary={}
	for key: String in samples[0][arm]:
		var values: Array=[]
		for pair: Dictionary in samples: values.append(int(pair[arm][key]))
		values.sort()
		result[key]=int((int(values[REPETITIONS/2-1])+int(values[REPETITIONS/2]))/2)
	return result

func run() -> void:
	var directory:=OS.get_environment("ART_CONTEXT_BENCH_NATIVE_DIR")
	if not check(not directory.is_empty(),"explicit original native evidence directory supplied"):
		finish(); return
	var fixture_hash:=script_hash("res://tests/fixtures/art_world_context_scan_baseline_0e93.gd")
	if not check(fixture_hash=="59fd1b9b517ffd742e81f1e4ec5aca6f81c9911b3e3e04bc04072692efb34415","baseline is the exact archived Context source from0e93"):
		finish(); return
	for case_index: int in CASES.size():
		var input:=replay_input(directory,CASES[case_index])
		if input.is_empty(): continue
		var warm_baseline:=measure(false,input)
		var warm_candidate:=measure(true,input)
		if not equal_contexts(warm_baseline.value,warm_candidate.value,input.id+" warmup"): continue
		var stable_digest: String=warm_baseline.value.digest
		var nonempty:=0
		for row: Dictionary in warm_baseline.value.model.material_distribution:
			if int(row.id)!=0: nonempty+=int(row.cells)
		var pairs: Array=[]
		for iteration: int in REPETITIONS:
			var order: Array=["baseline","candidate"] if (iteration+case_index)%2==0 else ["candidate","baseline"]
			var pair_results: Dictionary={}
			for arm: String in order:
				await process_frame
				pair_results[arm]=measure(arm=="candidate",input)
			var identical:=equal_contexts(pair_results.baseline.value,pair_results.candidate.value,input.id+" pair"+str(iteration))
			if not identical: break
			if not check(pair_results.baseline.value.digest==stable_digest,"repeated result remains immutable "+input.id): break
			pairs.append({"iteration":iteration,"order":order,
				"baseline":pair_results.baseline.timings_usec,"candidate":pair_results.candidate.timings_usec})
		if not check(pairs.size()==REPETITIONS,"all alternating samples retained "+input.id): continue
		check(Context.hash_materials(input.capture.materials)==input.original_plane_sha256,
			"both algorithms preserve the original captured plane "+input.id)
		outcomes.append({"id":input.id,"native_plane":input.native_plane,"captured_cells":input.capture.materials.size(),
			"observed_nonempty_cells":nonempty,"original_native_plane_sha256":input.original_plane_sha256,
			"context_bytes":warm_baseline.value.inspector.bytes,"model_context_digest":stable_digest,
			"warmup_timings_usec":{"baseline":warm_baseline.timings_usec,"candidate":warm_candidate.timings_usec},
			"repetitions_per_arm":REPETITIONS,
			"median_usec":{"baseline":medians(pairs,"baseline"),"candidate":medians(pairs,"candidate")},
			"paired_samples_usec":pairs})
	check(outcomes.size()==CASES.size(),"all original before planes and the completed native megaframe retained")
	finish()

func finish() -> void:
	var report: Dictionary={"schema":"art-context-scan-comparison-v1","checks":checks,"failures":failures,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"godot":Engine.get_version_info(),
		"baseline_source":BASELINE_SOURCE,
		"baseline_script_sha256":script_hash("res://tests/fixtures/art_world_context_scan_baseline_0e93.gd"),
		"candidate_script_sha256":script_hash("res://scripts/art_world_context.gd"),
		"knowledge_script_sha256":script_hash("res://scripts/art_knowledge_context.gd"),
		"original_native_source":ORIGINAL_NATIVE_SOURCE,"model_calls":0,"native_calls":0,"outcomes":outcomes,
		"scope":"One-process alternating-order pure-value comparison over authenticated original native before planes and actual completed megaframe after plane.",
		"order":"Eight paired repetitions per input; baseline/candidate first position alternates and is counterbalanced within every input.",
		"limits":["PNG decode, native-plane hash validation and equality assertions are outside the measured Context.build intervals.",
			"No live native capture, graphical frame latency, provider dispatch or genuine-model experiment is performed.",
			"Shared-host scheduling remains visible in every retained sample; medians are not a frame-latency guarantee.",
			"Dense/uneven/thin synthetic correctness cases are reported by the separate authoring-proposal test."]}
	var output:=OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file:=FileAccess.open(output+"/context-scan-comparison.json",FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"\t")+"\n")
	print("ART_CONTEXT_SCAN_COMPARISON ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
