extends SceneTree

# Actual Workbench 2 controls, accepted native proposals and failure controls.
# Completion receipts prevent a helper abort/no-op from satisfying this suite.
const WorkbenchScene = preload("res://worldgen_workbench.tscn")
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func basic_recipe() -> Dictionary:
	return {"schema":2, "seed":19301, "chunk_size":16, "candidate":"strata",
		"parameters":{"surface_y":-128, "relief":0, "detail":0, "cave_threshold":1},
		"themes":{"weights":{"industrial":1}},
		"spatial":{"nodes":[{"id":"x", "kind":"coordinate_x"}, {"id":"y", "kind":"coordinate_y"},
			{"id":"direction", "kind":"compose_vector", "inputs":["x","y"]},
			{"id":"mask", "kind":"to_mask", "inputs":["x"], "parameters":{"low":0,"high":16}}],
			"geometries":[{"id":"preserved-geometry","points":[[0,0],[16,16]]}]},
		"modifiers":[{"id":"paint","application":"spatial:mask","material":77}],
		"overrides":[{"id":"last","bounds":[4,4,4,4],"material":62}]}

func recipe_file(name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../examples/worldgen/" + name + ".json")))
	return parsed if parsed is Dictionary else {}

func drain(app: Variant) -> void:
	var iterations: int = 0
	while (app._has_active_chunk or not app.pending_chunks.is_empty()) and iterations < 4096:
		app.service_generation()
		iterations += 1
	expect(iterations < 4096 and not app._has_active_chunk and app.pending_chunks.is_empty(), "Native preview did not finish its bounded request set: " + app.last_error)
	expect(app.cache.size() <= app.MAX_CACHE_CHUNKS, "Preview cache exceeded its bound")

func drain_aux(app: Variant) -> void:
	var iterations: int = 0
	while (not app.tools2.aux_active.is_empty() or not app.tools2.aux_jobs.is_empty()) and iterations < 4096:
		app.tools2.service_auxiliary()
		iterations += 1
		await process_frame
	expect(iterations < 4096, "Bounded comparison/seed jobs failed to complete")

func drain_edits(app: Variant) -> void:
	var frames: int = 0
	while (app._edit_thread != null or not app._pending_edit.is_empty()) and frames < 4096:
		app.service_editor_transaction()
		frames += 1
		await process_frame
	expect(frames < 4096, "Private candidate validator did not complete")

func check_graph_transactions(app: Variant) -> void:
	var start: int = assertions
	expect(app.apply_recipe(basic_recipe()), "Typed editor fixture failed: " + app.last_error)
	app.tools2.open_graph()
	var graph: GraphEdit = app.tools2.graph
	expect(graph != null and app.tools2.graph_node_ids.size() == 4, "Graph canvas omitted accepted operators")
	expect(graph.get_connection_list().size() == 3, "Graph ports did not reflect actual dependencies")
	var original: Dictionary = app.active_recipe.duplicate(true)
	var revision: int = app.active_revision
	var old_history: int = app._undo.size()
	# Removing a required input must preserve the accepted graph/materials.
	expect(not app.tools2._edit_graph_edge("operator_0", "operator_3", 0, true), "Missing graph dependency was accepted")
	expect(app.active_recipe == original and app.active_revision == revision and app._undo.size() == old_history, "Invalid graph wiring changed accepted recipe or history")
	expect(app.tools2._edit_graph_edge("operator_1", "operator_3", 0, false), "Valid same-unit graph wiring rejected: " + app.last_error)
	expect(app.active_recipe.spatial.nodes[3].inputs == ["y"], "Graph connection did not update declarative input")
	expect(app.active_recipe.spatial.geometries == original.spatial.geometries, "Graph form dropped supported geometry not represented by node controls")
	app.tools2._graph_selected(graph.get_node("operator_3"))
	expect(app.tools2.node_parameter_box.get_child_count() == 2, "Graph parameter controls omitted native mask bounds")
	for row: Node in app.tools2.node_parameter_box.get_children():
		if row.get_child(0).text == "high": row.get_child(1).value = 20
	var parameter_applied: bool = app.tools2.apply_graph_node()
	expect(parameter_applied and app.active_recipe.spatial.nodes[3].parameters.high == 20, "Visual graph parameter edit was not compiled transactionally: " + app.last_error + " / " + app.tools2.node_editor.text)
	app._select_text(app.tools2.graph_new_kind, "constant")
	app.tools2.graph_new_id.text = "added-value"
	app.tools2.new_graph_node()
	app.tools2.node_editor.text = JSON.stringify({"id":"added-value", "kind":"constant", "value":{"type":"scalar","x":3.141592653589793}}, "", true, true)
	expect(app.tools2.apply_graph_node(), "Visual new-node action did not add a valid node")
	expect(app.spatial_nodes.has("added-value"), "New graph node is not a compiled native output")
	var with_node: Dictionary = app.active_recipe.duplicate(true)
	var cells_with_node: PackedByteArray = app.generator.generate_chunk(Vector2i.ZERO).cells
	app.parameter_inputs.relief.value = 7
	app.apply_controls()
	app.tool_picker.select(3)
	app.material_picker.select(app.material_picker.get_item_index(104))
	app.add_gesture(PackedVector2Array([Vector2(1,1), Vector2(3,3)]))
	var final_recipe: Dictionary = app.active_recipe.duplicate(true)
	var final_cells: PackedByteArray = app.generator.generate_chunk(Vector2i.ZERO).cells
	var old_token: Dictionary = app.tools2.capture_token()
	app.undo_authoring()
	app.undo_authoring()
	expect(app.active_recipe == with_node and app.generator.generate_chunk(Vector2i.ZERO).cells == cells_with_node, "Mixed parameter/brush undo did not reproduce accepted content")
	app.redo_authoring()
	app.redo_authoring()
	expect(app.active_recipe == final_recipe and app.generator.generate_chunk(Vector2i.ZERO).cells == final_cells, "Mixed parameter/brush redo changed canonical recipe or materials")
	expect(not app.tools2.accepts_token(old_token), "Undo/redo readmitted an older same-content session token")
	var retained: Dictionary = app.active_recipe.duplicate(true)
	var limited: Dictionary = retained.duplicate(true)
	limited.limits = {"max_operations_per_chunk":1}
	var undo_count: int = app._undo.size()
	var redo_count: int = app._redo.size()
	var token: Dictionary = app.tools2.capture_token()
	expect(not app.apply_recipe(limited), "Exhausted work candidate was admitted")
	expect(app.active_recipe == retained and app._undo.size() == undo_count and app._redo.size() == redo_count and app.tools2.accepts_token(token), "Budget failure damaged the accepted transaction")
	expect(app.load_spatial_example("typed-reusable-decay"), "Reusable graph fixture failed")
	expect(app.tools2.graph_namespace.item_count == 3 and app.tools2.graph_node_ids.size() == 2, "Namespace canvas omitted reusable definitions or root instance cards")
	app.tools2._graph_selected(app.tools2.graph.get_node("instance_0"))
	var instance: Dictionary = JSON.parse_string(app.tools2.node_editor.text)
	instance.bindings.panel_scale.x = 96
	app.tools2.node_editor.text = JSON.stringify(instance, "", true, true)
	var before_subgraphs: Array = app.active_recipe.spatial.subgraphs.duplicate(true)
	expect(app.tools2.apply_graph_node() and app.active_recipe.spatial.instances[0].bindings.panel_scale.x == 96 and app.active_recipe.spatial.subgraphs == before_subgraphs, "Instance edit changed templates or lost typed bindings")
	app.tools2.graph_namespace.select(1)
	app.tools2._refresh_graph(false)
	expect(app.tools2.graph_node_ids.size() == 4, "Named subgraph canvas did not display its local operators")
	app.tools2._graph_selected(app.tools2.graph.get_node("operator_0"))
	var local: Dictionary = JSON.parse_string(app.tools2.node_editor.text)
	local.parameters.salt = 9
	app.tools2.node_editor.text = JSON.stringify(local, "", true, true)
	var bindings: Array = app.active_recipe.spatial.instances.duplicate(true)
	expect(app.tools2.apply_graph_node() and app.active_recipe.spatial.subgraphs[0].nodes[0].parameters.salt == 9 and app.active_recipe.spatial.instances == bindings, "Namespace operator edit lost unrelated instance bindings")
	app.tools2.graph_window.hide()
	completed.graph_transactions = assertions - start

func check_trace_and_stages(app: Variant) -> void:
	var start: int = assertions
	expect(app.apply_recipe(basic_recipe()), "Trace fixture failed")
	app.view_size = Vector2(32, 32)
	app.set_camera_origin(Vector2.ZERO)
	drain(app)
	var token: Dictionary = app.tools2.capture_token()
	var trace: Dictionary = app.tools2.inspect_point(Vector2i(5, 5))
	expect(trace.get("ok", false) and trace.get("material", -1) == 62 and trace.get("mode", "") == "deterministic_replay", "Trace did not report actual final native hard override")
	expect(app.tools2.trace.get("preview_comparison", {}).get("status", "") == "matches accepted native proposal", "Inspector did not independently compare its replay to accepted copied preview cells")
	var tampered: Dictionary = trace.duplicate(true)
	tampered.material = 1
	expect(not app.tools2.accept_trace(tampered, token), "Replay disagreement was displayed as an accepted cause")
	var final_bytes: PackedByteArray = app.generator.generate_chunk(Vector2i.ZERO).cells
	for stage: String in ["candidate", "guided_candidate", "grammar", "modifiers", "connectivity", "final"]:
		expect(app.tools2.select_stage(stage), "Valid native stage rejected: " + stage)
		drain(app)
		var packet: Dictionary = app.cache.get(Vector2i.ZERO, {})
		expect(not packet.is_empty() and packet.cells == final_bytes, "Stage selection changed accepted final material cells: " + stage)
		if stage != "final":
			expect(packet.get("stage_cells") is PackedByteArray and packet.stage_cells.size() == final_bytes.size(), "Real stage bytes missing: " + stage)
			if stage in ["candidate", "guided_candidate", "grammar"]:
				expect(packet.stage_cells[5 * 16 + 5] != 62, "Early stage incorrectly rendered the final hard override")
	var view_token: int = app._view_token
	expect(not app.tools2.select_stage("imaginary") and app._view_token == view_token, "Unavailable stage changed the accepted view")
	expect(app.select_diagnostic("spatial:direction"), "Typed vector diagnostic unavailable")
	drain(app)
	var vector: Dictionary = app.preview._vector_at(Vector2(8, 4))
	expect(vector.get("ok", false) and vector.value.is_equal_approx(Vector2(1, 0.5)), "Vector overlay did not sample the copied native vector components")
	var stale: Dictionary = app.last_packet.duplicate(true)
	var changed: Dictionary = app.active_recipe.duplicate(true)
	changed.seed = int(changed.seed) + 1
	expect(app.apply_recipe(changed), "Seed switch failed")
	expect(not app.accept_chunk(stale) and not app.tools2.accept_trace(trace, token), "Seed switch admitted stale preview or replay")
	expect(app.tools2.trace.is_empty(), "Retired trace remained attached to a new preview")
	app.select_diagnostic("")
	completed.trace_stages = assertions - start

func check_planes_hierarchy(app: Variant) -> void:
	var start: int = assertions
	var recipe: Dictionary = recipe_file("semantic-refinery")
	expect(app.apply_recipe(recipe), "Native semantic-plane fixture rejected: " + app.last_error)
	app.view_size = Vector2(128, 128)
	app.set_camera_origin(Vector2(-128, -128))
	var features: Array = app.tools2.plan.get("features", [])
	expect(features.size() > 0 and app.tools2.hierarchy.get_root().get_child_count() > 0, "Hierarchy browser has no accepted semantic tree")
	var coordinate := Vector2i(-2, -2)
	var patch := Rect2i(-128, -128, 64, 64)
	var oracle: Dictionary = app.generator.generate_plane_region(patch)
	for index: int in range(5):
		expect(app.tools2.select_plane(index), "Plane selection rejected %d" % index)
		drain(app)
		var packet: Dictionary = app.cache.get(coordinate, {})
		var plane: String = app.tools2.selected_plane
		expect(not packet.is_empty() and packet.cells == oracle.materials[plane], "Workbench plane bytes differ from native four-plane proposal: " + plane)
		if index == 4: expect(packet.get("display_composite", false) and packet.materials.size() == 4, "Composite did not retain all four native planes")
	expect(app.tools2.select_plane(1), "Rear selection failed")
	var allowed: Array[String] = []
	for index: int in range(app.tools2.stage_picker.item_count): allowed.append(app.tools2.stage_picker.get_item_text(index))
	expect(not "grammar" in allowed, "Rear policy falsely advertised a nonexistent base-generator grammar stage")
	for stage: String in ["policy", "base", "projections"]:
		expect(app.tools2.select_stage(stage), "Actual plane stage unavailable: " + stage)
		drain(app)
		var packet: Dictionary = app.cache.get(coordinate, {})
		expect(not packet.is_empty() and packet.get("stage_cells") is PackedByteArray and packet.cells == oracle.materials.scripted, "Actual plane stage bytes or accepted final bytes lost: " + stage)
	var wrong_plane: Dictionary = app.cache[coordinate].duplicate(true)
	wrong_plane.plane = "background"
	expect(not app.tools2.normalize_plane_packet(wrong_plane, coordinate).get("ok", false), "Stage packet from a different plane was relabelled as the selected plane")
	var current_token: Dictionary = app.tools2.capture_token()
	var plane_trace: Dictionary = app.generator.inspect_generation(Vector2i(-120,-120), "scripted", app.active_revision, app.active_fingerprint)
	expect(app.tools2.accept_trace(plane_trace, current_token), "Matching native plane trace failed admission")
	expect(app.tools2.trace.preview_comparison.content_hash == "unavailable" and app.tools2.trace.preview_comparison.final_bytes_sha256.length() == 64 and app.cache[coordinate].native_plane_fingerprint == app.tools2.plane_revision, "Stage inspection mislabelled recipe identity or intermediate checksum as final content identity")
	var wrong_trace: Dictionary = plane_trace.duplicate(true)
	wrong_trace.plane = "background"
	expect(not app.tools2.accept_trace(wrong_trace, current_token), "Trace from the wrong plane was admitted despite unchanged selected-plane material")
	wrong_trace = plane_trace.duplicate(true)
	wrong_trace.plane_fingerprint = "retired-plane-plan"
	expect(not app.tools2.accept_trace(wrong_trace, current_token), "Trace with a stale plane fingerprint was admitted")
	var retired_plane_token: Dictionary = current_token.duplicate(true)
	retired_plane_token.plane_revision = "retired-plane-plan"
	expect(not app.tools2.accepts_token(retired_plane_token, false), "Auxiliary identity ignored the accepted plane fingerprint")
	expect(app.tools2.select_stage("base") and app.tools2.trace.is_empty() and app.tools2.trace_token.is_empty() and app.tools2.trace_view.text.contains("changed"), "View source change kept a previous stage explanation visibly attached")
	var selected_item: TreeItem = app.tools2.hierarchy.get_root().get_first_child()
	selected_item.select(0)
	app.tools2._select_feature()
	expect(app.tools2.selected_feature_record.get("feature", {}).get("id", "") == selected_item.get_metadata(0).id and app.tools2.selected_feature_record.get("revision", -1) == app.active_revision and app.tools2.feature_view.text.contains("not a claim"), "Selected hierarchy record was conflated with the separate bounds-origin cell replay")
	var before_recipe: Dictionary = app.active_recipe.duplicate(true)
	var before_features: Array = app.generator.get_semantic_plan().features.duplicate(true)
	var before_materials: Dictionary = app.generator.generate_plane_region(patch).materials.duplicate(true)
	var rules: Array = before_recipe.grammar.rules
	app._select_text(app.tools2.hierarchy_rule, str(rules[0].id))
	app.tools2._show_rule()
	var edited: Dictionary = rules[0].duplicate(true)
	edited.tags = edited.get("tags", []).duplicate()
	edited.tags.append("workbench-regression")
	app.tools2.hierarchy_editor.text = JSON.stringify(edited, "", true, true)
	expect(app.tools2.apply_rule(), "Native hierarchy rule edit failed")
	var with_rule: Dictionary = app.active_recipe.duplicate(true)
	var planes: Dictionary = with_rule.semantic_planes.duplicate(true)
	planes.id = str(planes.id) + "-editor"
	app.tools2.layer_editor.text = JSON.stringify(planes, "", true, true)
	expect(app.tools2.apply_plane_json(), "Native plane parameter edit failed")
	var edited_features: Array = app.generator.get_semantic_plan().features.duplicate(true)
	var edited_materials: Dictionary = app.generator.generate_plane_region(patch).materials.duplicate(true)
	app.undo_authoring()
	expect(app.active_recipe == with_rule, "Plane edit undo did not restore the canonical data")
	app.undo_authoring()
	expect(app.active_recipe == before_recipe, "Hierarchy edit undo did not restore all supported recipe fields")
	expect(app.generator.get_semantic_plan().features == before_features and app.generator.generate_plane_region(patch).materials == before_materials, "Mixed hierarchy/plane undo did not restore actual native semantic records and all four material planes")
	app.redo_authoring()
	app.redo_authoring()
	expect(str(app.active_recipe.semantic_planes.id).ends_with("-editor"), "Hierarchy/plane redo did not restore the transaction sequence")
	expect(app.generator.get_semantic_plan().features == edited_features and app.generator.generate_plane_region(patch).materials == edited_materials, "Mixed hierarchy/plane redo did not reproduce actual native semantic and material content")
	completed.planes_hierarchy = assertions - start

func check_comparison_seeds(app: Variant) -> void:
	var start: int = assertions
	expect(app.apply_recipe(basic_recipe()), "Comparison fixture failed")
	app.tools2.select_plane(0)
	app.tools2.select_stage("final")
	app.view_size = Vector2(32, 32)
	app.set_camera_origin(Vector2.ZERO)
	expect(app.tools2.pin_before(), "Accepted comparison baseline not pinned")
	var after: Dictionary = app.active_recipe.duplicate(true)
	after.overrides.append({"id":"comparison-change", "priority":9,"bounds":[20,20,4,4],"material":124})
	expect(app.apply_recipe(after), "Comparison candidate failed")
	expect(app.tools2.start_comparison(), "Aligned before/after comparison did not begin")
	await drain_aux(app)
	var result: Dictionary = app.tools2.last_comparison.duplicate(true)
	expect(result.get("materials", {}).get("play", {}).get("changed_cells", -1) == 16, "Same-seed material diff is not the exact authored 16-cell change")
	expect(result.get("bounds") == Rect2i(0,0,32,32), "Comparison silently moved its coordinate rectangle")
	app.tools2.seed_input.text = "19301,19317,19337,19361"
	expect(app.tools2.start_seed_browser(), "Declared seed suite did not queue")
	expect(app.tools2.aux_jobs.size() == 4, "Seed browser did not retain the four declared seeds")
	await drain_aux(app)
	expect(app.tools2.aux_results.size() == 4, "Seed browser lost completed results")
	var first: PackedByteArray = app.tools2.aux_results[0].materials.play.duplicate()
	app.tools2.seed_input.text = "19301"
	expect(app.tools2.start_seed_browser(), "Deterministic seed replay did not begin")
	await drain_aux(app)
	expect(app.tools2.aux_results.size() == 1 and app.tools2.aux_results[0].materials.play == first, "Repeated seed changed its native proposal")
	app.tools2.seed_input.text = "1,2,3,4,5"
	expect(not app.tools2.start_seed_browser() and app.tools2.aux_results.size() == 1, "Oversized seed job request destroyed accepted results")
	expect(not app.tools2.finish_comparison([], result.get("token", {})), "Empty/aborted comparison was accepted")
	app.tools2.seed_input.text = "1,2,3,4"
	app.tools2.start_seed_browser()
	app.tools2.service_auxiliary()
	expect(app.apply_recipe(basic_recipe()), "Recipe switch while comparing failed")
	expect((app.tools2.aux_active.is_empty() or not app.tools2._aux_current(app.tools2.aux_active)) and app.tools2.aux_jobs.is_empty() and app.tools2.aux_results.is_empty() and app.tools2.last_comparison.is_empty(), "Recipe replacement retained stale comparison or seed buffers")
	expect(not app.tools2.finish_comparison([], result.get("token", {})), "Retired comparison token was accepted")
	completed.comparison_seeds = assertions - start

func check_responsive_transactions(app: Variant) -> void:
	var start: int = assertions
	expect(app.apply_recipe(basic_recipe()), "Async transaction fixture failed")
	drain(app)
	var old_recipe: Dictionary = app.active_recipe.duplicate(true)
	var old_cache: Dictionary = app.cache.duplicate(true)
	var a: Dictionary = old_recipe.duplicate(true)
	a.seed = 200
	var b: Dictionary = old_recipe.duplicate(true)
	b.seed = 300
	expect(app.request_recipe(a), "First candidate was not queued")
	expect(app.request_recipe(b), "Latest candidate was not queued")
	expect(app._edit_thread != null and app._pending_edit.size() > 0, "Rapid edits are not bounded to one worker and one replacement")
	expect(app.active_recipe == old_recipe and app.cache == old_cache, "Unfinished candidate replaced accepted recipe/preview")
	await drain_edits(app)
	expect(int(app.active_recipe.seed) == 300, "Retired first edit won the rapid-edit race")
	var invalid: Dictionary = app.active_recipe.duplicate(true)
	invalid.limits = {"max_operations_per_chunk":1}
	var token: Dictionary = app.tools2.capture_token()
	var undo: Array = app._undo.duplicate(true)
	app.request_recipe(invalid)
	await drain_edits(app)
	expect(int(app.active_recipe.seed) == 300 and app._undo == undo and app.tools2.accepts_token(token), "Async failed candidate mutated active identity or history")
	drain(app)
	var cancellation_cache: Dictionary = app.cache.duplicate(true)
	app.request_recipe(a)
	app.cancel_pending_edit()
	expect(app.status_label.text.contains("cancelled") and not app.status_label.text.to_lower().contains("validating"), "Cancel left the pending validation footer visible")
	app._refresh_status()
	expect(not app.status_label.text.to_lower().contains("validating") and app.cache == cancellation_cache, "Retiring private validator reappeared as a current edit or disturbed preview cache")
	await drain_edits(app)
	expect(int(app.active_recipe.seed) == 300, "Cancelled worker result was later admitted")
	expect(not app.status_label.text.to_lower().contains("validating") and app.cache == cancellation_cache and app.tools2.accepts_token(token), "Quiesced cancelled edit left pending status or changed accepted identity/cache")
	app._interactive_edit = true
	app.undo_authoring()
	app._interactive_edit = false
	await drain_edits(app)
	expect(app.active_recipe == old_recipe, "Async undo did not restore canonical content")
	app._interactive_edit = true
	app.redo_authoring()
	app._interactive_edit = false
	await drain_edits(app)
	expect(int(app.active_recipe.seed) == 300 and not app.tools2.accepts_token(token), "Async redo reused a retired session token")
	completed.responsive_transactions = assertions - start

func run() -> void:
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		push_error("Source-matched native generator is mandatory")
		quit(1)
		return
	var guard: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	for method: StringName in [&"inspect_generation", &"begin_stage_region", &"advance_stage_region", &"adopt_configuration"]:
		if not guard.has_method(method):
			push_error("GEN-007 native API missing: " + str(method))
			quit(1)
			return
	root.size = Vector2i(1600,1000)
	var app: Variant = WorkbenchScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	await process_frame
	check_graph_transactions(app)
	check_trace_and_stages(app)
	check_planes_hierarchy(app)
	await check_comparison_seeds(app)
	await check_responsive_transactions(app)
	for helper: String in ["graph_transactions", "trace_stages", "planes_hierarchy", "comparison_seeds", "responsive_transactions"]:
		expect(int(completed.get(helper, 0)) >= 10, "Required helper aborted or became a no-op: " + helper)
	app.queue_free()
	await process_frame
	print("GEN007_WORKBENCH: %d assertions; %d failures; completed=%s" % [assertions, failures, JSON.stringify(completed)])
	quit(1 if failures else 0)
