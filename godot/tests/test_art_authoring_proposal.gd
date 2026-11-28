extends SceneTree
## Synthetic copied-value compiler/preview tests. This suite deliberately does
## not claim native mutation or model creativity; the native campaign is separate.
const Context = preload("res://scripts/art_world_context.gd")
const Proposal = preload("res://scripts/art_authoring_proposal.gd")
const Preview = preload("res://scripts/art_authoring_preview.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("ART_PROPOSAL_CHECK ",label," ",ok)
	if not ok: failures += 1; push_error(label)

func policy() -> Dictionary:
	return {"extent":Vector2i(64,64),"region":Rect2i(0,0,64,64),
		"protected":[],"allowed":[0,28,58],"allow_destructive":false,
		"objective":"Build a useful industrial room.","style":"industrial",
		"complexity":"balanced","variation":0.2,"pinned_constraints":["Keep the owner in control."]}

func capture() -> Dictionary:
	var cells := PackedInt32Array()
	cells.resize(64*64)
	cells.fill(0)
	return {"status":"completed","kind":"capture","backend":"CyberNativeCellWorld",
		"region":Rect2i(0,0,64,64),"materials":cells,"generation":3,"revision":17,"tick":0,
		"authoring_generation":2,"observed_generation":3}

func packet(operations: Array) -> Dictionary:
	return {"schema":Proposal.SCHEMA,"title":"Industrial room","summary":"An explicit bounded native proposal.",
		"stages":[{"id":"frame","title":"Structural frame","depends_on":[],"operations":operations}]}

func rectangle(material: int = 58) -> Dictionary:
	return {"shape":"rectangle","x0":4,"y0":4,"x1":11,"y1":7,"material":material}

func preview(compiled: Dictionary, context: Dictionary) -> Dictionary:
	var instance := Preview.new()
	if not instance.configure(compiled,context): return instance.result
	var deadline := Time.get_ticks_msec()+20000
	while instance.active and Time.get_ticks_msec()<deadline:
		instance.poll()
		if instance.active: await process_frame
	check(not instance.active,"preview reaches a finite terminal state")
	return instance.result

func refuses(raw: Variant, context: Dictionary, rules: Dictionary, label: String) -> void:
	var compiled := Proposal.compile(raw,context,rules)
	check(not compiled.ok,label)

func check_context_scan_equivalence() -> void:
	# A deliberately simple scalar reference uses the public occupancy definition.
	# The optimized context path may precompute counts, but must preserve every
	# material and bucket even for sparse, dense, thin and uneven dimensions.
	var cases: Array = [
		[Vector2i(1,1),0], [Vector2i(1,65),-1], [Vector2i(65,1),58],
		[Vector2i(3,2),-1], [Vector2i(15,17),-1], [Vector2i(17,15),0],
		[Vector2i(31,47),58], [Vector2i(63,65),-1], [Vector2i(512,512),-1]]
	for item: Array in cases:
		var size: Vector2i = item[0]
		var region := Rect2i(Vector2i(7,11),size)
		var rules := policy()
		rules.extent = size+Vector2i(32,32)
		rules.region = region
		var receipt := capture()
		receipt.region = region
		receipt.materials = PackedInt32Array()
		receipt.materials.resize(size.x*size.y)
		var expected_histogram := {}
		var expected_grid: Array = []
		for y: int in 16:
			var row: Array = []
			for x: int in 16: row.append([0,0,0])
			expected_grid.append(row)
		for i: int in receipt.materials.size():
			var id := int(item[1]) if int(item[1]) >= 0 else (i*29+(i/size.x)*7)%256
			receipt.materials[i] = id
			expected_histogram[id] = int(expected_histogram.get(id,0))+1
			var x := i%size.x
			var y := i/size.x
			var observed_bin: Array = expected_grid[mini(15,y*16/size.y)][mini(15,x*16/size.x)]
			observed_bin[0] += 1
			if id != 0: observed_bin[1] += 1
			if id == 0 or id == 58: observed_bin[2] += 1
		var result := Context.build(receipt,rules)
		var label := "%dx%d fill=%d" % [size.x,size.y,int(item[1])]
		check(result.get("ok",false),"bounded exact-context scan admits "+label)
		if not result.get("ok",false): continue
		var actual_histogram := {}
		for row: Dictionary in result.model.material_distribution:
			actual_histogram[int(row.id)] = int(row.cells)
		check(actual_histogram==expected_histogram,"packed scan preserves all observed material counts "+label)
		check(result.model.coarse_occupancy.grid==expected_grid,
			"packed scan preserves exact observed/nonempty/source0-58 buckets "+label)

func run() -> void:
	var rules := policy()
	var observed := capture()
	var original_sha := Context.hash_materials(observed.materials)
	var decisions: Array = []
	for index: int in 20: decisions.append("Acknowledged decision "+str(index))
	var context := Context.build(observed,rules,decisions)
	check(context.ok,"complete copied native capture accepted")
	check(context.inspector.captured_cells==4096,"exact captured-cell count")
	check(context.model.material_distribution[0].cells==4096,"histogram describes actual copied values")
	check(context.model.native_samples.size()==32,"sample count is bounded")
	var sample_quadrants := {}
	var sample_columns := {}
	var sample_rows := {}
	var sample_truth := true
	for cell: Array in context.model.native_samples:
		sample_quadrants[Vector2i(int(cell[0])/32,int(cell[1])/32)] = true
		sample_columns[int(cell[0])] = true
		sample_rows[int(cell[1])] = true
		sample_truth = sample_truth and int(cell[2])==int(observed.materials[int(cell[1])*64+int(cell[0])])
	check(sample_quadrants.size()==4 and sample_columns.size()>1 and sample_rows.size()>1,
		"power-of-two region samples cover all quadrants instead of aliasing to one edge")
	check(sample_truth and context.model.native_sampling.method=="stratified-bin-centers-v1",
		"spatial samples retain actual observed values and deterministic provenance")
	var thin_rules := rules.duplicate(true)
	thin_rules.extent = Vector2i(128,128)
	thin_rules.region = Rect2i(17,21,1,64)
	var thin_capture := observed.duplicate(true)
	thin_capture.region = thin_rules.region
	thin_capture.materials.resize(64)
	for index: int in 64: thin_capture.materials[index] = 58 if index%3==0 else 0
	var thin_context := Context.build(thin_capture,thin_rules)
	var thin_points := {}
	var thin_truth := true
	for cell: Array in thin_context.model.native_samples:
		var point := Vector2i(int(cell[0]),int(cell[1]))
		thin_points[point] = true
		thin_truth = thin_truth and thin_rules.region.has_point(point) \
			and int(cell[2])==int(thin_capture.materials[point.y-thin_rules.region.position.y])
	check(thin_context.ok and thin_points.size()==32 and thin_truth,
		"translated one-cell-wide region has bounded distinct truthful spatial samples")
	var small_rules := rules.duplicate(true)
	small_rules.region = Rect2i(10,11,3,2)
	var small_capture := observed.duplicate(true)
	small_capture.region = small_rules.region
	small_capture.materials = PackedInt32Array([0,58,28,0,28,58])
	var small_context := Context.build(small_capture,small_rules)
	var small_points := {}
	var small_truth := true
	for cell: Array in small_context.model.native_samples:
		var point := Vector2i(int(cell[0]),int(cell[1]))
		small_points[point] = true
		var at := (point.y-11)*3+point.x-10
		small_truth = small_truth and small_rules.region.has_point(point) and at>=0 and at<6 \
			and int(cell[2])==int(small_capture.materials[at])
	check(small_context.ok and small_points.size()==6 and small_truth,
		"small selected regions expose every actual cell exactly once within the sample budget")
	var no_samples_rules := rules.duplicate(true)
	no_samples_rules.include_native_summary = false
	var no_samples_context := Context.build(observed,no_samples_rules)
	check(not no_samples_context.model.has("native_samples") and not no_samples_context.model.has("native_sampling"),
		"owner-disabled native samples omit coordinates and sampling metadata from model context")
	check(context.model.coarse_occupancy.grid.size()==16,"coarse occupancy has bounded rows")
	check(context.model.recent_acknowledged_decisions.size()==8,"session decision summary is bounded")
	check(context.model.recent_acknowledged_decisions[0]=="Acknowledged decision 12","recent admitted decisions retained")
	check(not context.model.has("_capture") and not context.model.has("materials"),"model payload omits private full native plane")
	check(context.inspector.bytes<=24576 and context.inspector.omitted.size()>=7,"context inspector exposes byte budget and omissions")
	var private_rules := rules.duplicate(true)
	private_rules.credentials = "not-for-model"
	private_rules.audit = "historical-private"
	private_rules.unrelated_desktop = "never-admitted"
	var private_context := Context.build(observed,private_rules)
	check(not JSON.stringify(private_context.model).contains("not-for-model")
		and not JSON.stringify(private_context.model).contains("historical-private")
		and not JSON.stringify(private_context.model).contains("never-admitted"),"host unknown/private fields never become model context")
	for field: String in ["generation","revision","tick","authoring_generation"]:
		var bad := observed.duplicate(true)
		bad.erase(field)
		check(not Context.build(bad,rules).ok,"capture missing "+field+" refuses")
	var partial := observed.duplicate(true)
	partial.status = "partial"
	check(not Context.build(partial,rules).ok,"partial native observation refuses")
	partial = observed.duplicate(true)
	partial.backend = "rendered-framebuffer"
	check(not Context.build(partial,rules).ok,"rendered appearance cannot impersonate native material data")
	partial = observed.duplicate(true)
	partial.observed_generation = 4
	check(not Context.build(partial,rules).ok,"replaced capture refuses")
	partial = observed.duplicate(true)
	partial.materials.resize(12)
	check(not Context.build(partial,rules).ok,"truncated material plane refuses")
	partial = observed.duplicate(true)
	partial.materials[0] = 256
	check(not Context.build(partial,rules).ok,"invalid native material refuses")
	var too_big := rules.duplicate(true)
	too_big.objective = "x".repeat(4097)
	check(not Context.build(observed,too_big).ok,"unbounded brief refuses")
	too_big = rules.duplicate(true)
	too_big.variation = NAN
	check(not Context.build(observed,too_big).ok,"nonfinite variation refuses")
	too_big = rules.duplicate(true)
	too_big.allowed = [58,58]
	check(not Context.build(observed,too_big).ok,"duplicate palette IDs refuse")

	var raw := packet([rectangle()])
	var compiled := Proposal.compile(raw,context,rules)
	check(compiled.ok,"typed bounded stage compiles")
	check(compiled.budget.candidate_cells==32 and compiled.budget.operations==1,"host computes geometry budget")
	check(compiled.source==context.source and compiled.context_digest==context.digest,"compiled plan binds current observation")
	check(compiled.policy_digest==context.policy_digest,"compiled plan binds owner constraints")
	var result: Dictionary = await preview(compiled,context)
	check(result.ok and result.status=="ready" and result.predicted_changed==32,"zero-write preview computes exact changed cells")
	check(result.zero_native_writes and Context.hash_materials(observed.materials)==original_sha,"preview cannot change its copied source")
	check(result.stages[0].introduced[58]==32,"preview labels introduced material counts as predictions")
	check(not result.has("native_receipt"),"preview never invents native receipts")

	var malformed := raw.duplicate(true)
	malformed.schema = "unknown"
	refuses(malformed,context,rules,"unknown schema refuses")
	malformed = raw.duplicate(true)
	malformed.receipt = {"status":"completed","changed":999999}
	refuses(malformed,context,rules,"model-invented successful receipts refuse")
	malformed = raw.duplicate(true)
	malformed.policy = {"protected":[]}
	refuses(malformed,context,rules,"model cannot weaken host constraints")
	malformed = raw.duplicate(true)
	malformed.stages[0].operations[0].run = "execute arbitrary code"
	refuses(malformed,context,rules,"unknown executable operation fields refuse")
	malformed = raw.duplicate(true)
	malformed.stages[0].operations[0].material = 29
	refuses(malformed,context,rules,"unapproved palette refuses")
	malformed = packet([rectangle(0)])
	refuses(malformed,context,rules,"erase without owner permission refuses")
	malformed = raw.duplicate(true)
	malformed.stages[0].operations[0].x0 = 0.5
	refuses(malformed,context,rules,"fractional geometry refuses")
	malformed = raw.duplicate(true)
	malformed.stages[0].operations[0].x1 = 64
	refuses(malformed,context,rules,"out-of-canvas geometry refuses")
	malformed = raw.duplicate(true)
	malformed.region = [0,0,8,8]
	refuses(malformed,context,rules,"geometry outside narrowed proposal region refuses")
	malformed = raw.duplicate(true)
	malformed.stages[0].depends_on = ["future"]
	refuses(malformed,context,rules,"forward or unknown dependency refuses")
	malformed = raw.duplicate(true)
	malformed.stages.append(malformed.stages[0].duplicate(true))
	refuses(malformed,context,rules,"duplicate stage identity refuses")
	malformed = raw.duplicate(true)
	malformed.stages[0].id = "../untrusted"
	refuses(malformed,context,rules,"path-like stage IDs refuse")
	malformed = raw.duplicate(true)
	malformed.stages[0].operations[0].shape = "native_part"
	refuses(malformed,context,rules,"unowned Architecture placement refuses explicitly")
	malformed = packet([{"shape":"repeat","count":2,"step":[1,0],
		"item":{"shape":"repeat","count":2,"step":[0,1],"item":rectangle()}}])
	refuses(malformed,context,rules,"nested procedural loops refuse")
	malformed = packet([{"shape":"repeat","count":17,"step":[1,0],"item":rectangle()}])
	refuses(malformed,context,rules,"unbounded repetition refuses")
	var many_segments: Array = []
	for index: int in 66: many_segments.append([index%64,8+index/64])
	refuses(packet([{"shape":"polyline","points":many_segments,"material":58}]),context,rules,"polyline expansion is bounded before native raster preparation")
	var many_ops: Array = []
	for index: int in 65: many_ops.append(rectangle())
	refuses(packet(many_ops),context,rules,"expanded operation budget is enforced")
	var changed_rules := rules.duplicate(true)
	changed_rules.protected = [Rect2i(4,4,2,2)]
	refuses(raw,context,changed_rules,"constraint changes require refreshed native context")
	check(not Proposal.parse_text("[]").ok,"array cannot impersonate typed proposal")
	check(not Proposal.parse_text('{"schema":').ok,"incomplete provider JSON refuses")
	check(not Proposal.parse_text("x".repeat(131073)).ok,"oversized provider proposal refuses")
	check(Proposal.parse_text(JSON.stringify(raw)).ok,"complete exact JSON accepted")

	var revised := raw.duplicate(true)
	revised.title = "Taller industrial room"
	revised.stages[0].operations[0].y1 = 10
	var developed := Proposal.compile(revised,context,rules,compiled)
	check(developed.ok and developed.diff.changed==["frame"],"revision records changed stage")
	check(developed.diff.parent_digest==compiled.proposal_digest,"revision retains parent identity")
	check(developed.policy_digest==compiled.policy_digest,"revision preserves host constraints")

	var guards_rules := rules.duplicate(true)
	guards_rules.protected = [Rect2i(6,5,2,2)]
	var guard_context := Context.build(observed,guards_rules)
	var protected_plan := Proposal.compile(raw,guard_context,guards_rules)
	var protected_result: Dictionary = await preview(protected_plan,guard_context)
	check(not protected_result.ok and protected_result.conflict_count==4,"exact protected cells refuse preview")
	check(protected_result.conflicts[0].reason=="Owner-protected region","protected conflict is understandable")
	var diagonal := packet([{"shape":"line","x0":1,"y0":1,"x1":12,"y1":12,"material":58}])
	guards_rules.protected = [Rect2i(8,2,2,2)]
	guard_context = Context.build(observed,guards_rules)
	var diagonal_result: Dictionary = await preview(Proposal.compile(diagonal,guard_context,guards_rules),guard_context)
	check(diagonal_result.ok,"conservative bounding overlap alone does not invent a protected-cell conflict")

	var occupied := observed.duplicate(true)
	occupied.materials[4*64+4] = 58
	var occupied_context := Context.build(occupied,rules)
	var replacement := Proposal.compile(packet([rectangle(28)]),occupied_context,rules)
	var replacement_result: Dictionary = await preview(replacement,occupied_context)
	check(not replacement_result.ok and replacement_result.conflict_count==1,"occupied material replacement requires destructive approval")
	var allowed_rules := rules.duplicate(true)
	allowed_rules.allow_destructive = true
	occupied_context = Context.build(occupied,allowed_rules)
	var allowed_result: Dictionary = await preview(Proposal.compile(packet([rectangle(28)]),occupied_context,allowed_rules),occupied_context)
	check(allowed_result.ok and allowed_result.predicted_changed==32,"explicit destructive approval permits supported source replacement")
	occupied.materials[4*64+4] = 28
	occupied_context = Context.build(occupied,allowed_rules)
	var source_result: Dictionary = await preview(Proposal.compile(raw,occupied_context,allowed_rules),occupied_context)
	check(not source_result.ok and source_result.conflict_count==1,"native source0/58 policy cannot be expanded by destructive approval")

	var outline := packet([{"shape":"outline","x0":4,"y0":4,"x1":15,"y1":15,"width":2,"material":58}])
	var outline_result: Dictionary = await preview(Proposal.compile(outline,context,rules),context)
	check(outline_result.ok and outline_result.requested==80 and outline_result.predicted_changed==80,"outline has exact nonoverlapping perimeter")
	var repeated := packet([{"shape":"repeat","count":3,"step":[10,0],"item":rectangle()}])
	var repeated_result: Dictionary = await preview(Proposal.compile(repeated,context,rules),context)
	check(repeated_result.ok and repeated_result.requested==96,"finite repeated elements compile to exact native geometry")
	var cancelled := Preview.new()
	check(cancelled.configure(compiled,context),"preview starts independently")
	cancelled.cancel()
	check(not cancelled.active and cancelled.result.status=="cancelled" and cancelled.result.requested==0,"Stop cancels before any preview raster work")
	var ambiguous := raw.duplicate(true)
	ambiguous.unresolved = ["Which passage must remain open?"]
	var ambiguous_result: Dictionary = await preview(Proposal.compile(ambiguous,context,rules),context)
	print("ART_AMBIGUITY_DIAGNOSTIC ",JSON.stringify(ambiguous_result))
	check(not ambiguous_result.ok and ambiguous_result.error.contains("questions"),"unresolved creative ambiguity cannot receive execution approval")

	check_context_scan_equivalence()
	print("ART_PROPOSAL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"evidence_kind":"synthetic copied-value contracts; no model or native writes"}))
	quit(1 if failures else 0)
