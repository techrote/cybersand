extends SceneTree

# GEN-003 adapter and authoring acceptance. Native analytical/structural suites
# separately own the operator mathematics and conservative work accounting.
const Workbench = preload("res://scripts/worldgen_workbench.gd")
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

func base_recipe() -> Dictionary:
	return {"schema":2, "seed":190, "chunk_size":8, "candidate":"strata",
		"parameters":{"surface_y":-128,"relief":0,"cave_threshold":1,"detail":0},
		"themes":{"weights":{"basalt":1}}}

func typed_recipe() -> Dictionary:
	var recipe: Dictionary = base_recipe()
	recipe.spatial = {"nodes":[
		{"id":"x","kind":"coordinate_x","sampling_scale":4},
		{"id":"y","kind":"coordinate_y"},
		{"id":"position","kind":"compose_vector","inputs":["x","y"]},
		{"id":"gradient","kind":"gradient","inputs":["x"]},
		{"id":"mask","kind":"to_mask","inputs":["x"],"parameters":{"low":-8,"high":0}},
		{"id":"signed","kind":"constant","value":{"type":"scalar","x":-12.5}},
		{"id":"circle","kind":"circle_distance","parameters":{"radius":2}},
		{"id":"route_distance","kind":"geometry_distance","reference":"route"},
		{"id":"vector","kind":"constant","value":{"type":"vector2","x":-3,"y":4}},
		{"id":"large_vector","kind":"constant","value":{"type":"vector2","x":-1e60,"y":1e60}},
		{"id":"truth","kind":"constant","value":{"type":"boolean","x":1}},
		{"id":"category","kind":"constant","value":{"type":"category","category":{"x":"9007199254740993","y":"-9007199254740995","domain":"ffffffffffffffff"}}},
		{"id":"category_match","kind":"category_is","inputs":["category"],"value":{"type":"category","category":{"x":"9007199254740993","y":"-9007199254740995","domain":"0000000000000000"}}},
		{"id":"category_other_namespace","kind":"category_is","inputs":["category"],"value":{"type":"category","category":{"x":"9007199254740993","y":"-9007199254740995","domain":"0000000000000001"}}},
	],"geometries":[{"id":"route","points":[[0,10],[8,10]]}]}
	recipe.modifiers = [{"id":"paint","application":"spatial:mask","material":62}]
	return recipe

func check_catalogue() -> void:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var catalogue: Dictionary = generator.get_catalogue()
	expect(catalogue.get("spatial_types", []).size() == 7, "Native typed value inventory is incomplete")
	expect(catalogue.get("field_kinds", []).size() == 22, "Typed support changed the legacy scalar catalogue")
	expect(catalogue.get("spatial_kinds", []).size() >= 50, "Typed operator catalogue is incomplete")
	var names: Dictionary = {}
	for spec: Dictionary in catalogue.get("spatial_kinds", []):
		expect(not names.has(str(spec.id)), "Duplicate spatial operator metadata")
		names[str(spec.id)] = true
		for parameter: Dictionary in spec.parameters:
			var value: float = float(parameter.default_value)
			expect(is_finite(value) and value >= float(parameter.minimum) and value <= float(parameter.maximum) and (not bool(parameter.integer) or value == floorf(value)), "Invalid native parameter default: " + str(spec.id) + "." + str(parameter.name))
	for name: String in ["transform","transform_vector","polar","log_polar","repeat","mirror","warp","gradient","divergence","curl","ridge","valley","curvature","peano","voronoi_region","delaunay_degree","poisson_distance","geometry_distance","assigned_region"]:
		expect(names.has(name), "Missing supported spatial operator metadata: " + name)

func check_transport() -> void:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var recipe: Dictionary = typed_recipe()
	var configured: Dictionary = generator.configure(recipe)
	expect(configured.ok, "Typed recipe rejected: " + str(configured.get("error", "")))
	if not configured.ok: return
	var plain: Dictionary = generator.generate_chunk(Vector2i(-1,0))
	var x: Dictionary = generator.generate_chunk(Vector2i(-1,0), "spatial:x")
	expect(x.ok and x.diagnostics.is_empty() and x.diagnostic_values is PackedFloat64Array and x.diagnostic_values.size() == 64, "Typed scalar was clamped or transported through legacy floats")
	if not x.ok: return
	expect(x.diagnostic_info.type == "scalar" and x.diagnostic_info.unit_power == 1 and x.diagnostic_info.sampling_scale == 4, "Coordinate units/type/scale were lost at the adapter")
	for row: int in range(8):
		for column: int in range(8):
			expect(x.diagnostic_values[row * 8 + column] == column - 8, "World-anchored negative coordinate interpolation changed an analytic field")
	expect(x.cells == plain.cells and x.hash == plain.hash and x.receipt_hash != plain.receipt_hash, "Typed inspection changed material output or was omitted from the receipt")
	var signed: Dictionary = generator.generate_chunk(Vector2i.ZERO, "spatial:signed")
	expect(signed.ok and signed.diagnostic_values[0] == -12.5, "Signed scalar lost its negative value")
	var circle: Dictionary = generator.generate_chunk(Vector2i.ZERO, "spatial:circle")
	expect(circle.ok and circle.diagnostic_info.type == "signed_distance" and circle.diagnostic_info.unit_power == 1 and circle.diagnostic_values[0] == -2 and circle.diagnostic_info.distance_min_factor == 1 and circle.diagnostic_info.distance_max_factor == 1, "Signed distance lost its sign, units or distance guarantees")
	var route: Dictionary = generator.generate_chunk(Vector2i.ZERO, "spatial:route_distance")
	expect(route.ok and route.diagnostic_info.type == "distance" and route.diagnostic_values[0] == 10 and route.diagnostic_info.unit_power == 1, "Immutable geometry distance lost its type, value or units")
	var vector: Dictionary = generator.generate_chunk(Vector2i.ZERO, "spatial:vector")
	expect(vector.ok and vector.diagnostic_info.type == "vector2" and vector.diagnostic_values.size() == 128 and vector.diagnostic_values[0] == -3 and vector.diagnostic_values[1] == 4, "Vector components were flattened or clamped")
	var gradient: Dictionary = generator.generate_chunk(Vector2i(-1,0), "spatial:gradient")
	expect(gradient.ok and gradient.diagnostic_values[0] == 1 and gradient.diagnostic_values[1] == 0 and gradient.diagnostic_info.unit_power == 0, "Derivative value/sign/units did not survive the adapter")
	var category: Dictionary = generator.generate_chunk(Vector2i.ZERO, "spatial:category")
	expect(category.ok and category.diagnostic_values.is_empty() and category.diagnostic_categories is PackedStringArray and category.diagnostic_categories.size() == 192, "Exact categorical diagnostics have the wrong shape")
	if not category.ok: return
	expect(category.diagnostic_categories[0] == "9007199254740993" and category.diagnostic_categories[1] == "-9007199254740995" and category.diagnostic_categories[2] == "ffffffffffffffff", "Categorical identity was rounded through floating point or signed uint64 conversion")
	var truth: Dictionary = generator.generate_chunk(Vector2i.ZERO, "spatial:truth")
	expect(truth.ok and truth.diagnostic_info.type == "boolean" and truth.diagnostic_values[0] == 1, "Boolean type/value was not preserved")
	var category_match: Dictionary = generator.generate_chunk(Vector2i.ZERO, "spatial:category_match")
	var category_other: Dictionary = generator.generate_chunk(Vector2i.ZERO, "spatial:category_other_namespace")
	expect(category_match.ok and category_match.diagnostic_values[0] == 1 and category_other.ok and category_other.diagnostic_values[0] == 0, "Explicit category selection lost exact coordinates or namespace comparison")
	var copied: Dictionary = generator.get_configuration()
	copied.spatial.nodes[0].sampling_scale = 64
	expect(generator.get_configuration() == recipe, "Typed configuration exposes mutable accepted storage")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(recipe, "", true, true))
	var second: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var restored: Dictionary = second.configure(roundtrip)
	expect(restored.ok and restored.fingerprint == configured.fingerprint, "JSON roundtrip changed canonical typed recipe identity")
	var roundtrip_category: Dictionary = second.generate_chunk(Vector2i.ZERO, "spatial:category")
	expect(roundtrip_category.ok and roundtrip_category.diagnostic_categories == category.diagnostic_categories, "JSON roundtrip rounded exact category identity")
	category.diagnostic_categories[0] = "0"
	expect(generator.generate_chunk(Vector2i.ZERO, "spatial:category").diagnostic_categories[0] == "9007199254740993", "Diagnostic strings borrow mutable native storage")

func check_transactional_rejection() -> void:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var recipe: Dictionary = typed_recipe()
	expect(generator.configure(recipe).ok and generator.begin_chunk(Vector2i.ZERO,"spatial:signed").ok, "Transactional fixture could not begin")
	var pending: Dictionary = generator.advance(7)
	expect(pending.ok and pending.state == "running" and not pending.has("cells") and not pending.has("diagnostic_values") and not pending.has("diagnostic_categories"), "Pending typed job exposed partial output")
	var malformed: Array[Dictionary] = [
		{"schema":1,"spatial":{"nodes":[{"id":"a","kind":"coordinate_x"}]}},
		{"schema":2,"spatial":{"nodes":"bad"}},
		{"schema":2,"spatial":{"nodes":[{"id":"a","kind":"unknown"}]}},
		{"schema":2,"spatial":{"nodes":[{"id":"a","kind":"constant","value":{"type":"category","category":{"x":"9223372036854775808","y":0,"domain":"0000000000000001"}}}]}},
		{"schema":2,"spatial":{"nodes":[{"id":"a","kind":"constant","value":{"type":"category","category":{"x":0,"y":0,"domain":"FFFFFFFFFFFFFFFF"}}}]}},
		{"schema":2,"spatial":{"nodes":[{"id":"a","kind":"constant","value":{"type":"scalar","x":NAN}}]}},
		{"schema":2,"spatial":{"nodes":[{"id":"a","kind":"constant","value":{"type":"boolean","x":0.5}}]}},
		{"schema":2,"spatial":{"nodes":[{"id":"a","kind":"coordinate_x","sampling_scale":3}]}},
		{"schema":2,"spatial":{"nodes":[{"id":"a","kind":"gradient","inputs":["missing"]}]}},
		{"schema":2,"spatial":{"instances":[{"id":"a","subgraph":"missing"}]}},
		{"schema":2,"spatial":{"geometries":[{"id":"a","points":[]}]}},
		{"schema":2,"spatial":{"assignments":[{"id":"a","specification":{"categories":[1],"adjacency":[[1]],"width":1,"height":1}}]}},
		{"schema":2,"spatial_limits":{"max_nodes":65}},
		{"schema":2,"spatial_limits":{"max_preparation_bytes":0}},
	]
	var unnormalized: Dictionary = typed_recipe()
	unnormalized.modifiers[0].application = "spatial:signed"
	malformed.append(unnormalized)
	for invalid: Dictionary in malformed:
		var rejected: Dictionary = generator.configure(invalid)
		expect(not rejected.ok and not str(rejected.get("error", "")).is_empty(), "Invalid typed recipe did not fail with a diagnostic: " + str(invalid))
		expect(generator.advance(0).completed_cells == 7 and generator.get_configuration() == recipe, "Rejected typed configuration disturbed accepted work")
	expect(not generator.begin_chunk(Vector2i.ZERO,"spatial:missing").ok and generator.advance(0).completed_cells == 7, "Rejected typed channel cancelled the prior job")
	var complete: Dictionary = generator.advance(57)
	expect(complete.ok and complete.state == "ready" and complete.diagnostic_values.size() == 64, "Typed job did not complete transactionally after rejected configurations")
	complete.diagnostic_values[0] = 999
	expect(generator.advance(0).diagnostic_values[0] == -12.5, "Typed result values borrow mutable native storage")

func indexed_spatial_nodes(catalogue: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for node: Dictionary in catalogue.spatial_nodes: result[str(node.id)] = node
	return result

func check_subgraphs_and_examples() -> void:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var path: String = ProjectSettings.globalize_path("res://../examples/worldgen/typed-reusable-decay.json")
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var configured: Dictionary = generator.configure(recipe)
	expect(configured.ok, "Reusable decay example failed to configure: " + str(configured.get("error","")))
	if not configured.ok: return
	var before: Dictionary = indexed_spatial_nodes(generator.get_catalogue())
	expect(before.has("north.mask") and before.has("south.mask") and before.has("north.brush.texture"), "Expanded nested subgraph outputs or namespaces are missing")
	var north: Dictionary = generator.generate_chunk(Vector2i.ZERO,"spatial:north.mask")
	var south: Dictionary = generator.generate_chunk(Vector2i.ZERO,"spatial:south.mask")
	expect(north.ok and south.ok and north.diagnostic_info.type == "normalized" and south.diagnostic_info.type == "normalized", "Reusable masks are not executable normalized outputs")
	var second: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var restored: Dictionary = second.configure(JSON.parse_string(JSON.stringify(recipe, "", true, true)))
	expect(restored.ok and restored.fingerprint == configured.fingerprint, "Subgraph JSON roundtrip changed canonical identity")
	expect(second.generate_chunk(Vector2i.ZERO,"spatial:north.mask").diagnostic_values == north.diagnostic_values, "Subgraph JSON roundtrip changed typed output")
	var changed: Dictionary = recipe.duplicate(true)
	changed.spatial.instances[0].bindings.panel_scale.x = 64
	expect(second.configure(changed).ok, "Valid subgraph parameter edit failed")
	var after: Dictionary = indexed_spatial_nodes(second.get_catalogue())
	expect(before["north.mask"].fingerprint != after["north.mask"].fingerprint and before["south.mask"].fingerprint == after["south.mask"].fingerprint, "Parameter change failed to isolate affected node/cache identities")
	var invalid: Dictionary = recipe.duplicate(true)
	invalid.spatial.nodes = [{"id":"north","kind":"coordinate_x"}]
	expect(not generator.configure(invalid).ok, "Top-level node collided with a subgraph namespace")
	invalid = recipe.duplicate(true)
	invalid.spatial.subgraphs.append(invalid.spatial.subgraphs[0].duplicate(true))
	expect(not generator.configure(invalid).ok, "Duplicate subgraph declaration was accepted")
	invalid = recipe.duplicate(true)
	invalid.spatial.subgraphs[0].parameters[1].erase("default")
	expect(not generator.configure(invalid).ok, "Missing required subgraph binding was accepted")
	invalid = recipe.duplicate(true)
	invalid.spatial.subgraphs[0].instances = [{"id":"loop","subgraph":"panel_decay"}]
	expect(not generator.configure(invalid).ok, "Recursive unused/instantiated subgraph expansion was accepted")

	path = ProjectSettings.globalize_path("res://../examples/worldgen/typed-categorical-districts.json")
	var districts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	configured = generator.configure(districts)
	expect(configured.ok, "Categorical district example failed: " + str(configured.get("error","")))
	if not configured.ok: return
	var assigned: Dictionary = generator.generate_chunk(Vector2i.ZERO,"spatial:district")
	var selected: Dictionary = generator.generate_chunk(Vector2i.ZERO,"spatial:first_district_mask")
	expect(assigned.ok and assigned.diagnostic_categories[0] == "9007199254740993", "Bounded assignment did not preserve its exact authored category/domain anchor")
	expect(selected.ok and selected.diagnostic_values[0] == 1, "Declared category mask did not select the pinned finite assignment cell")
	districts.spatial.assignments[0].specification.width = 17
	expect(not generator.configure(districts).ok, "Unbounded finite region assignment entered the native compiler")

func check_workbench() -> void:
	root.size = Vector2i(1600,1000)
	var app: CyberWorldGenerationWorkbench = WorkbenchScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	await process_frame
	expect(app.spatial_specs.size() >= 50 and app.page_picker.item_count == 11 and app.page_picker.get_item_text(6) == "Typed spatial graphs", "Typed native authoring catalogue or retained legacy page did not initialize")
	expect(app.apply_recipe(typed_recipe()), "Workbench rejected typed recipe: " + app.last_error)
	if app.active_recipe.get("schema",1) != 2:
		app.queue_free()
		return
	var authored_identity: String = app.generator.get_catalogue().spatial_fingerprint
	app.apply_json()
	expect(app.last_error.is_empty() and app.generator.get_catalogue().spatial_fingerprint == authored_identity, "Profile editor text rounded accepted double precision values")
	expect(app.apply_spatial_json() and app.generator.get_catalogue().spatial_fingerprint == authored_identity, "Spatial editor text rounded accepted double precision values")
	var saved_profile: String = "user://gen003-typed-roundtrip.json"
	expect(app.save_profile(saved_profile) and app.load_profile(saved_profile), "Typed profile file could not roundtrip")
	app.apply_json()
	expect(app.last_error.is_empty() and app.generator.get_catalogue().spatial_fingerprint == authored_identity, "Saved typed profile rounded accepted double precision values")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_profile))
	for id: String in ["mask","signed","circle","route_distance","vector","large_vector","truth","category"]:
		expect(app.select_diagnostic("spatial:" + id), "Typed output missing from inspection menu: " + id)
		var packet: Dictionary = app.generator.generate_chunk(Vector2i.ZERO,"spatial:" + id)
		expect(app.accept_chunk(packet,Vector2i.ZERO,app._view_token), "Typed packet did not enter preview: " + id + " / " + app.last_error)
		expect(app.cache[Vector2i.ZERO].has("diagnostic_texture"), "Typed preview lacks a mapped texture")
		app._inspect_point(Vector2.ZERO)
		expect(app.pointer_label.text.contains("spatial:" + id), "Typed point inspection lost the output ID")
		var color: Color = Workbench.spatial_diagnostic_color(packet,0)
		expect(is_finite(color.r) and is_finite(color.g) and is_finite(color.b), "Display mapping narrowed or overflowed valid typed values")
		var malformed: Dictionary = packet.duplicate(true)
		malformed.diagnostic_info.unit_power = 7
		expect(not app.accept_chunk(malformed), "Forged typed units metadata entered the preview")
		malformed = packet.duplicate(true)
		if id == "category": malformed.diagnostic_categories[0] = "9007199254740993.0"
		else: malformed.diagnostic_values[0] = NAN
		expect(not app.accept_chunk(malformed), "Malformed typed values entered the preview")
		malformed = packet.duplicate(true)
		malformed.diagnostics = PackedFloat32Array([0])
		expect(not app.accept_chunk(malformed), "Typed payload admitted a second legacy scalar representation")
		expect(app.accept_chunk(packet), "Valid typed packet did not recover after malformed controls")
		if id == "category":
			packet.diagnostic_categories[0] = "0"
			expect(app.cache[Vector2i.ZERO].diagnostic_categories[0] == "9007199254740993", "Preview retained mutable categorical storage")
		else:
			packet.diagnostic_values[0] = 99
			expect(app.cache[Vector2i.ZERO].diagnostic_values[0] != 99, "Preview retained mutable typed numeric storage")
	var revision: int = app.active_revision
	app.spatial_editor.text = "{\"nodes\":[{\"id\":\"bad\",\"kind\":\"unknown\"}]}"
	expect(not app.apply_spatial_json() and app.active_revision == revision, "Rejected authoring JSON replaced the accepted graph")
	app.spatial_editor.text = JSON.stringify(typed_recipe().spatial, "", true, true)
	expect(app.apply_spatial_json(), "Complete typed JSON could not be authored")
	var saved: Dictionary = app.active_recipe.duplicate(true)
	app.parameter_inputs.relief.value = 7
	app.apply_controls()
	expect(app.active_recipe.spatial == saved.spatial, "Legacy terrain controls discarded typed graph data")
	for name: String in Workbench.SPATIAL_EXAMPLES:
		expect(app.load_spatial_example(name), "Executable typed example did not configure: " + name + " / " + app.last_error)
		if app.last_error.is_empty():
			var packet: Dictionary = app.generator.generate_chunk(Vector2i.ZERO)
			expect(packet.ok and packet.state == "ready", "Executable typed example did not generate actual material cells: " + name + " / " + str(packet.get("error","")))
	app.queue_free()
	await process_frame

func run() -> void:
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		push_error("Source-matched CyberWorldGenerator is required for GEN-003 adapter acceptance")
		quit(1)
		return
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	if not generator.get_catalogue().has("spatial_kinds"):
		push_error("Loaded native runtime predates typed spatial generation")
		quit(1)
		return
	check_catalogue()
	check_transport()
	check_transactional_rejection()
	check_subgraphs_and_examples()
	await check_workbench()
	print("GEN-003 typed adapter and workbench: ", assertions, " assertions; ", failures, " failures")
	quit(0 if failures == 0 else 1)
