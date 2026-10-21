extends SceneTree

# Adapter/UI acceptance complements the independent native layout and raster
# oracles. A script error is also rejected by the repository test runner.
const WorkbenchScene = preload("res://worldgen_workbench.tscn")
var assertions: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("run")

func example() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://../examples/worldgen/hierarchy-multi-district.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func check_transport(recipe: Dictionary) -> void:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = generator.configure(recipe)
	expect(configured.ok, "Executable hierarchy example rejected: " + str(configured.get("error", "")))
	if not configured.ok: return
	var plan: Dictionary = generator.get_semantic_plan()
	expect(plan.ok and plan.schema == 1 and plan.algorithm == 1 and plan.bounds == [-128, -128, 256, 256], "Plan version/absolute bounds lost")
	var report: Dictionary = generator.validate_routes()
	expect(report.ok and report.passed and report.profile == "floating-square-v1" and report.clearance == 3 and report.cells == 65536, "Example final raster clearance did not pass: " + str(report))
	expect(report.routes.size() > 20, "Primary routes, loops and nested socket connectors are missing")
	expect(report.supports_passed and report.support_profile == "static-solid-contact-v1" and report.supports.size() > 0, "Example lost final static support contact: " + str(report.supports))
	var identities: Dictionary = {}
	var kinds: Dictionary = {}
	var point := Vector2i.ZERO
	for feature: Dictionary in plan.features:
		expect(not identities.has(feature.id), "Semantic ownership duplicated: " + str(feature.id))
		identities[feature.id] = feature.duplicate(true)
		kinds[feature.kind] = true
		expect(feature.seed is String and feature.seed.length() == 16 and feature.revision is String, "Semantic seed/revision lost exact encoding")
		expect(feature.ancestry.back() == feature.id, "Ancestry lost the selected feature")
		if feature.kind == "complex": point = Vector2i(int(feature.bounds[0]), int(feature.bounds[1]))
	for kind: String in ["region", "district", "complex", "room", "apparatus", "detail"]:
		expect(kinds.has(kind), "Missing nested semantic kind: " + kind)
	var shared: int = 0
	for socket: Dictionary in plan.sockets:
		if socket.shared: shared += 1
		if socket.required and not socket.shared: expect(not str(socket.matched).is_empty(), "Required local socket lacks explicit matching identity")
	expect(shared >= 12, "Shared boundary sockets were not exported")
	for receipt: Dictionary in plan.receipts:
		expect(receipt.passed or receipt.fallback or receipt.constraint == "candidate", "A failed hard constraint lacks an authored fallback receipt")
	var trace: Dictionary = generator.inspect_cell(point)
	expect(trace.ok and trace.ancestry.size() >= 3 and trace.constraints.size() > 0, "Cell inspection lost semantic ancestry/constraint provenance")
	expect(trace.contributions.size() >= 2 and trace.typed_fields.size() > 0, "Cell inspection lost material/field contributions")
	var size: int = recipe.chunk_size
	var coord := Vector2i(floori(float(point.x) / size), floori(float(point.y) / size))
	var packet: Dictionary = generator.generate_chunk(coord)
	expect(packet.ok, "Hierarchy chunk generation failed: " + str(packet.get("error", "")))
	if packet.ok:
		var index: int = (point.y - coord.y * size) * size + point.x - coord.x * size
		expect(packet.cells[index] == trace.material, "Provenance and raster sample disagree")
	plan.features[0].id = "tampered-copy"
	plan.sockets[0].matched = "tampered-copy"
	expect(generator.get_semantic_plan().features[0].id != "tampered-copy" and generator.get_semantic_plan().sockets[0].matched != "tampered-copy", "Plan query exposed mutable native storage")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(recipe, "", true, true))
	var second: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var restored: Dictionary = second.configure(roundtrip)
	expect(restored.ok and restored.fingerprint == configured.fingerprint, "Grammar JSON roundtrip changed identity")
	if restored.ok:
		expect(second.get_semantic_plan().features == generator.get_semantic_plan().features, "Grammar JSON roundtrip changed semantic records")
		expect(second.generate_chunk(coord).cells == packet.cells, "Grammar JSON roundtrip changed material cells")
	var reordered: Dictionary = recipe.duplicate(true)
	reordered.grammar.rules.reverse()
	for rule: Dictionary in reordered.grammar.rules:
		if rule.has("candidates"): rule.candidates.reverse()
		if rule.has("children"): rule.children.reverse()
	expect(second.configure(reordered).ok, "Declaration reorder was rejected")
	expect(second.get_semantic_plan().features == generator.get_semantic_plan().features, "Declaration order changed stable semantic records")
	var incomplete: Dictionary = generator.begin_chunk(coord)
	expect(incomplete.ok, "Hierarchy incremental job did not start")
	var partial: Dictionary = generator.advance(7)
	expect(partial.ok and partial.state == "running" and not partial.has("cells"), "Pending hierarchy exposed a partial material packet")
	var bads: Array[Dictionary] = []
	var bad: Dictionary = recipe.duplicate(true)
	bad.schema = 2
	bads.append(bad)
	bad = recipe.duplicate(true)
	bad.grammar.rules[0].constraints = {"unknown_constraint": true}
	bads.append(bad)
	bad = recipe.duplicate(true)
	bad.grammar.secondary_loop = 1
	bads.append(bad)
	bad = recipe.duplicate(true)
	bad.grammar.limits = {"max_raster_operations": 1}
	bads.append(bad)
	bad = recipe.duplicate(true)
	bad.grammar.rules[0].candidates[0].bounds[0] = 0.5
	bads.append(bad)
	for malformed: Dictionary in bads:
		expect(not generator.configure(malformed).ok, "Invalid hierarchy declaration was accepted")
		expect(generator.get_configuration() == recipe, "Rejected hierarchy replaced the accepted recipe")
	var resumed: Dictionary = generator.advance(65536)
	expect(resumed.ok and resumed.state == "ready" and resumed.cells == packet.cells and resumed.fingerprint == packet.fingerprint, "Rejected configure disturbed pending accepted work")
	var blocked: Dictionary = recipe.duplicate(true)
	blocked.overrides.append({"id":"intentional-bulkhead", "bounds":[-68, -68, 9, 9], "material":62, "priority":1000})
	var blocked_configuration: Dictionary = second.configure(blocked)
	expect(blocked_configuration.ok, "Authoritative final bulkhead should retain a reportable plan")
	if blocked_configuration.ok:
		var blocked_report: Dictionary = second.validate_routes()
		expect(not blocked_report.passed, "Blocked final route falsely claimed traversal")
		var blocker_found: bool = false
		for route: Dictionary in blocked_report.routes:
			blocker_found = blocker_found or str(route.detail).contains("intentional-bulkhead")
		expect(blocker_found, "Route conflict report lost the final override identity")
		var blocked_trace: Dictionary = second.inspect_cell(Vector2i(-64, -64))
		expect(blocked_trace.material == 62 and blocked_trace.contributions.back().stage == "hard_override" and blocked_trace.contributions.back().id == "intentional-bulkhead", "Route restoration overruled the final hard material")

func check_workbench() -> void:
	root.size = Vector2i(1600, 1000)
	var app: CyberWorldGenerationWorkbench = WorkbenchScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	await process_frame
	expect(app.load_hierarchy_example(), "Workbench rejected hierarchy profile: " + app.last_error)
	if app.active_recipe.get("schema", 1) == 3:
		expect(app.semantic_feature_count > 20 and app.semantic_route_report.passed, "Workbench did not retain semantic metadata")
		expect(app.apply_spatial_json() and app.active_recipe.schema == 3 and app.active_recipe.has("grammar"), "Typed editor downgraded/removed accepted hierarchy")
		app._inspect_point(Vector2(-64, -64))
		expect(app.tools2.trace_view.text.contains("contributions") and app.tools2.trace_view.text.contains("ancestry") and app.tools2.trace.get("revision", -1) == app.active_revision, "Workbench inspection pane omitted copied provenance or its accepted identity")
		var path: String = "user://gen004-profile-roundtrip.json"
		expect(app.save_profile(path) and app.load_profile(path) and app.active_recipe.schema == 3, "Hierarchy profile save/load failed")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app.queue_free()
	await process_frame

func run() -> void:
	expect(ClassDB.class_exists(&"CyberWorldGenerator"), "Required native generator is unavailable")
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		quit(1)
		return
	var recipe: Dictionary = example()
	expect(not recipe.is_empty(), "Executable hierarchy JSON is missing")
	if not recipe.is_empty(): check_transport(recipe)
	await check_workbench()
	print("GEN-004 grammar adapter: %d assertions; %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
