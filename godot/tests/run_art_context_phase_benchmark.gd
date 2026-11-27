extends SceneTree
## Pure-value timing over authenticated saved native observations. No native
## World is created and no provider is called. This is not a fresh PAINT receipt.
const Context = preload("res://scripts/art_world_context.gd")
const Examples = preload("res://scripts/art_creative_examples.gd")
const CASES := [[0,"industrial_repair"],[6,"stopped_workshop"],[7,"staged_megaframe"],[8,"xeno_vault"]]
const REPETITIONS := 7
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

func median(values: Array) -> int:
	var ordered := values.duplicate()
	ordered.sort()
	return int(ordered[ordered.size()/2])

func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func replay_input(directory: String, entry: Array) -> Dictionary:
	var prefix := "%02d-%s" % [entry[0],entry[1]]
	var record := read_json(directory+"/"+prefix+"-result.json")
	var saved := read_json(directory+"/"+prefix+"-editable-setup.json")
	if not check(not record.is_empty() and not saved.is_empty(),"original native metadata and Setup are available "+prefix): return {}
	var rect: Array = record.get("region",[])
	var extent: Array = saved.get("extent",[])
	if not check(rect.size()==4 and extent.size()==2,"original native region/extent are complete "+prefix): return {}
	var region := Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3]))
	var picture := Image.load_from_file(directory+"/"+prefix+"-before-native.png")
	if not check(picture!=null and picture.get_size()==region.size,"original native diagnostic dimensions "+prefix): return {}
	picture.convert(Image.FORMAT_RGBA8)
	var rgba := picture.get_data()
	var cells := PackedInt32Array()
	cells.resize(region.size.x*region.size.y)
	for index: int in cells.size(): cells[index]=int(rgba[index*4])
	if not check(Context.hash_materials(cells)==str(record.get("before_materials_sha256","")),
		"PNG-derived material bytes match original actual native int32-plane hash "+prefix): return {}
	var example := Examples.make(str(entry[1]),region,[0,28,58])
	if not check(example.get("ok",false),"source-matched deterministic policy available "+prefix): return {}
	var rules: Dictionary=example.brief.duplicate(true)
	rules.extent=Vector2i(int(extent[0]),int(extent[1]))
	rules.region=region
	rules.protected=example.protected.duplicate()
	rules.allowed=[0,28,58]
	rules.include_knowledge=true
	rules.tool="Art finite staged construction"
	var native_source: Dictionary=record.source_before
	var captured: Dictionary={"status":"completed","kind":"capture","backend":"CyberNativeCellWorld",
		"region":region,"materials":cells}
	for key: String in ["generation","revision","tick","authoring_generation"]: captured[key]=int(native_source[key])
	captured.observed_generation=captured.generation
	return {"id":str(entry[1]),"capture":captured,"policy":rules,"region":rect,
		"original_plane_sha256":record.before_materials_sha256}

func run() -> void:
	var directory:=OS.get_environment("ART_CONTEXT_BENCH_NATIVE_DIR")
	if not check(not directory.is_empty(),"explicit original native evidence directory supplied"):
		finish(); return
	for entry: Array in CASES:
		var input:=replay_input(directory,entry)
		if input.is_empty(): continue
		var warm:=Context.build(input.capture,input.policy)
		if not check(warm.get("ok",false),"warm-up captured-value context "+input.id): continue
		var samples: Array=[]
		var stable_digest: String=warm.digest
		for iteration: int in REPETITIONS:
			await process_frame
			var began:=Time.get_ticks_usec()
			var result:=Context.build(input.capture,input.policy)
			var call_usec:=Time.get_ticks_usec()-began
			if not check(result.get("ok",false) and result.digest==stable_digest,
				"repeated context values/digest stay deterministic "+input.id): break
			var phases: Dictionary=result.inspector.get("timings_usec",{}).duplicate(true)
			if not check(not phases.is_empty(),"phase instrumentation present "+input.id): break
			phases.callsite=call_usec
			phases.reported_total=int(result.inspector.elapsed_usec)
			samples.append(phases)
		if not check(samples.size()==REPETITIONS,"all controlled timing repetitions retained "+input.id): continue
		var medians: Dictionary={}
		for key: String in samples[0]:
			var values: Array=[]
			for sample: Dictionary in samples: values.append(int(sample[key]))
			medians[key]=median(values)
		outcomes.append({"id":input.id,"captured_cells":input.capture.materials.size(),
			"original_native_plane_sha256":input.original_plane_sha256,"context_bytes":warm.inspector.bytes,
			"model_context_digest":stable_digest,"warmup_timings_usec":warm.inspector.timings_usec,
			"repetitions":REPETITIONS,"median_usec":medians,"samples_usec":samples})
	check(outcomes.size()==CASES.size(),"all four original native observation sizes retained")
	finish()

func finish() -> void:
	var report: Dictionary={"schema":"art-context-phase-benchmark-v1","checks":checks,"failures":failures,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"godot":Engine.get_version_info(),
		"scope":"Pure-value timing over original native PNG/int32-hash observations from source2743; no live World, new native receipt or model call.",
		"original_native_source":"2743f89a0df6f6afcf7484e859c10790d521e74b",
		"model_calls":0,"native_calls":0,"outcomes":outcomes,
		"limits":["Input conversion/validation is outside measured Context.build intervals.",
			"These phases do not measure PAINT capture, interactive publication or ordinary Workbench frame latency.",
			"No behavioral optimization or async preparation is enabled by this benchmark."]}
	var output:=OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file:=FileAccess.open(output+"/context-phase-benchmark.json",FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"\t")+"\n")
	print("ART_CONTEXT_PHASE_BENCHMARK ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
