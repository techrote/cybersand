extends SceneTree

# Native field/authoring acceptance. No World residency, simulation material
# rules, target GPU performance, or live-world manipulation is implied.
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
	return {"schema":1, "seed":431, "chunk_size":16, "candidate":"strata",
		"parameters":{"surface_y":-128,"relief":0,"cave_threshold":1,"detail":0},
		"themes":{"weights":{"basalt":1}}}

func extension_recipe() -> Dictionary:
	var recipe: Dictionary = base_recipe()
	recipe.fields = [
		{"id":"zero","kind":"constant","parameters":{"value":0}},
		{"id":"one","kind":"constant","parameters":{"value":1}},
		{"id":"noise","kind":"value_noise","parameters":{"scale":8,"salt":17}},
		{"id":"mask","kind":"circle","parameters":{"x":8,"y":8,"radius":7,"feather":3}},
		{"id":"inverse","kind":"invert","inputs":["mask"]},
		{"id":"occupied","kind":"context","context":"occupied"},
		{"id":"curve","kind":"hilbert","parameters":{"order":4}},
	]
	recipe.aggregates = [{"id":"stone-mix","components":[{"material":38,"weight":3},{"material":39,"weight":1}],"grain_size":3,"variation":"noise"}]
	recipe.modifiers = [{"id":"paint","bounds":[0,0,16,16],"context":"solid","application":"mask","exclusion":"zero","aggregate":"stone-mix"}]
	recipe.modules = [{"id":"shell","module":"arcology","version":1,"bounds":[-64,-64,128,128],"application":"zero"}]
	recipe.overrides = [{"id":"final","bounds":[4,4,2,2],"material":62}]
	return recipe

func normalized(values: Variant, count: int) -> bool:
	if not values is PackedFloat32Array or values.size() != count: return false
	for value: float in values:
		if not is_finite(value) or value < 0 or value > 1: return false
	return true

func uniform(values: Variant, value: float) -> bool:
	if values.is_empty(): return false
	for actual: float in values:
		if not is_equal_approx(actual, value): return false
	return true

func same_json(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func check_catalogue() -> void:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var catalogue: Dictionary = generator.get_catalogue()
	expect(catalogue.get("field_kinds", []).size() == 22, "Native field catalogue is missing supported kinds")
	expect(catalogue.get("field_contexts", []) == ["occupied","solid","fluid","depth","slope","route"], "Field context catalogue differs from native context contract")
	expect(catalogue.get("modifier_contexts", []).has("material") and catalogue.get("maximum_fields", 0) == 64 and catalogue.get("maximum_aggregates", 0) == 32 and catalogue.get("maximum_modifiers", 0) == 64, "Native extension capacity/context metadata is incomplete")
	var names: Dictionary = {}
	for spec: Dictionary in catalogue.get("field_kinds", []):
		var id: String = str(spec.id)
		expect(not names.has(id), "Duplicate native field kind: " + id)
		names[id] = true
		var defaults: Dictionary = {}
		var valid: bool = true
		for parameter: Dictionary in spec.parameters:
			var value: float = float(parameter.default_value)
			valid = valid and is_finite(value) and value >= float(parameter.minimum) and value <= float(parameter.maximum)
			valid = valid and (not bool(parameter.integer) or value == floorf(value))
			defaults[str(parameter.name)] = value
		expect(valid, "Metadata has an invalid native default for " + id)
		var node: Dictionary = {"id":"tested","kind":id,"inputs":[]}
		for index: int in range(int(spec.input_count)): node.inputs.append(["a","b","c"][index])
		if spec.requires_context: node.context = "occupied"
		if spec.supports_warp: node.warp_x = "a"
		var recipe: Dictionary = base_recipe()
		recipe.fields = [{"id":"a","kind":"constant","parameters":{"value":0.25}}, {"id":"b","kind":"constant","parameters":{"value":0.75}}, {"id":"c","kind":"constant","parameters":{"value":0.5}}, node]
		var accepted: Dictionary = generator.configure(recipe)
		expect(accepted.ok, "Default field descriptor did not configure: " + id + " / " + str(accepted.get("error", "")))
		if not accepted.ok: continue
		var implicit: Dictionary = generator.generate_chunk(Vector2i(-1,0), "field:tested")
		expect(implicit.ok and normalized(implicit.get("diagnostics"), 256), "Field kind did not produce normalized copied values: " + id)
		node.parameters = defaults
		recipe.fields[-1] = node
		accepted = generator.configure(recipe)
		expect(accepted.ok, "Native metadata defaults were not accepted explicitly: " + id)
		if not accepted.ok: continue
		var explicit: Dictionary = generator.generate_chunk(Vector2i(-1,0), "field:tested")
		expect(explicit.ok and explicit.get("diagnostics") == implicit.get("diagnostics") and explicit.get("cells") == implicit.get("cells"), "Metadata defaults changed native field output: " + id)
	if not catalogue.get("field_kinds", []).is_empty():
		catalogue.field_kinds[0].parameters[0].maximum = -1
		expect(generator.get_catalogue().field_kinds[0].parameters[0].maximum == 1, "Catalogue query leaked mutable metadata")

func check_adapter() -> void:
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var recipe: Dictionary = extension_recipe()
	var accepted: Dictionary = generator.configure(recipe)
	expect(accepted.ok, "Complete field/aggregate/modifier profile failed: " + str(accepted.get("error", "")))
	if not accepted.ok: return
	var plain: Dictionary = generator.generate_chunk(Vector2i.ZERO)
	var inspected: Dictionary = generator.generate_chunk(Vector2i.ZERO, "field:mask")
	expect(plain.ok and plain.diagnostic == "" and plain.diagnostics is PackedFloat32Array and plain.diagnostics.is_empty(), "Unrequested diagnostic output was allocated or mislabelled")
	expect(inspected.ok and inspected.diagnostic == "field:mask" and normalized(inspected.get("diagnostics"),256), "Ready field inspection lacks normalized full-chunk values")
	if not inspected.ok: return
	expect(plain.cells == inspected.cells and plain.hash == inspected.hash and plain.receipt_hash != inspected.receipt_hash, "Inspection changed materials or failed to bind the diagnostic in its receipt")
	expect(inspected.diagnostics[0] == 0 and inspected.diagnostics[8*16+8] == 1, "Circle mask diagnostic does not reflect its actual world-space shape")
	expect(inspected.cells[4*16+4] == 62, "Final hard material override lost authority after aggregate masking")
	var modifier: Dictionary = generator.generate_chunk(Vector2i.ZERO, "modifier:paint")
	var module: Dictionary = generator.generate_chunk(Vector2i.ZERO, "module:shell")
	var context: Dictionary = generator.generate_chunk(Vector2i.ZERO, "field:occupied")
	expect(modifier.ok and modifier.diagnostics == inspected.diagnostics, "Modifier effective mask differs from application, fixed-solid context and shape")
	expect(module.ok and normalized(module.get("diagnostics"),256) and uniform(module.diagnostics,0), "Zero application field did not suppress the module output mask")
	expect(context.ok and uniform(context.diagnostics,1), "Context fields observed painted/module terrain instead of the occupied base terrain")
	var borrowed: Dictionary = generator.get_configuration()
	borrowed.fields[0].parameters.value = 0.5
	borrowed.aggregates[0].components[0].weight = 99
	borrowed.modifiers[0].bounds[0] = 100
	expect(generator.get_configuration() == recipe, "Accepted extension recipe leaked mutable nested field/aggregate/modifier storage")
	expect(generator.begin_chunk(Vector2i.ZERO, "field:mask").ok, "Diagnostic job did not begin")
	var pending: Dictionary = generator.advance(7)
	expect(pending.ok and pending.state == "running" and pending.completed_cells == 7 and not pending.has("cells") and not pending.has("diagnostics"), "Pending inspection exposed partial native output")
	expect(not generator.begin_chunk(Vector2i.ZERO, "field:missing").ok, "Unknown diagnostic channel was admitted")
	expect(generator.advance(0).completed_cells == 7, "Rejected inspection request discarded the earlier pending job")
	# Godot 4.7 replaces JSON U+0000 (and String.chr(0)) with U+FFFD before
	# passing a String to the adapter. Use that representable value explicitly
	# instead of emitting the engine's expected Unicode warning. It must remain
	# invalid, never become the existing "one" ID through prefix truncation.
	# The adapter's defensive literal-NUL guard is not reachable by this fixture.
	var nul_id: String = "one" + String.chr(0xfffd) + "tail"
	var nul_profiles: Array[Dictionary] = [
		{"fields":[{"id":nul_id,"kind":"constant"}]},
		{"fields":[{"id":"one","kind":"constant"},{"id":"b","kind":"invert","inputs":[nul_id]}]},
		{nul_id:1},
	]
	for invalid: Dictionary in nul_profiles:
		var rejected: Dictionary = generator.configure(invalid)
		expect(nul_id.unicode_at(3) == 0xfffd and not rejected.ok and not str(rejected.get("error", "")).is_empty(), "Godot's replacement for a NUL in a field ID, dependency or unknown key was not rejected")
	var nul_diagnostic: Dictionary = generator.begin_chunk(Vector2i.ZERO,"field:" + nul_id)
	expect(not nul_diagnostic.ok and not str(nul_diagnostic.get("error", "")).is_empty() and generator.advance(0).completed_cells == 7, "Godot's replacement for a NUL diagnostic was coerced or disturbed the existing job")

	var invalid_profiles: Array[Dictionary] = [
		{"fields":"not-an-array"},
		{"fields":[{"id":"a","kind":"missing"}]},
		{"fields":[{"id":"a","kind":"constant","op":"constant"}]},
		{"fields":[{"id":"a","kind":"constant","parameters":{"unknown":1}}]},
		{"fields":[{"id":"a","kind":"constant","parameters":{"value":NAN}}]},
		{"fields":[{"id":"a","kind":"hilbert","parameters":{"order":1.5}}]},
		{"fields":[{"id":"a","kind":"constant","context":"solid"}]},
		{"fields":[{"id":"a","kind":"constant","warp_x":"a"}]},
		{"fields":[{"id":"a","kind":"context","context":"final_material"}]},
		{"fields":[{"id":"a","kind":"material","parameters":{"material":10}}]},
		{"fields":[{"id":"a","kind":"invert","inputs":["missing"]}]},
		{"fields":[{"id":"a","kind":"invert","inputs":["b"]},{"id":"b","kind":"invert","inputs":["a"]}]},
		{"aggregates":[{"id":"a","components":[]}]},
		{"aggregates":[{"id":"a","components":[{"material":10}]}]},
		{"aggregates":[{"id":"a","components":[{"material":255}]}]},
		{"aggregates":[{"id":"a","components":[{"material":38,"weight":0}]}]},
		{"aggregates":[{"id":"a","components":[{"material":38,"weight":-1}]}]},
		{"aggregates":[{"id":"a","components":[{"material":38},{"material":38}]}]},
		{"aggregates":[{"id":"a","components":[{"material":38}],"grain_size":1.5}]},
		{"aggregates":[{"id":"a","components":[{"material":38}],"variation":"missing"}]},
		{"aggregates":[{"id":"a","components":[{"material":38,"probability":1}]}]},
		{"modifiers":[{"id":"a","material":0,"application":"missing"}]},
		{"modifiers":[{"id":"a","material":0,"context":"unsupported"}]},
		{"modifiers":[{"id":"a","material":0,"context":"material"}]},
		{"modifiers":[{"id":"a","material":0,"context":"solid","context_material":38}]},
		{"modifiers":[{"id":"a","material":0,"aggregate":"missing"}]},
		{"modifiers":[{"id":"a","material":0,"bounds":[0,0,8,8],"points":[[1,1]]}]},
		{"modifiers":[{"id":"a","material":0,"strength":1.1}]},
		{"modifiers":[{"id":"a","material":0,"radius":0}]},
		{"modifiers":[{"id":"a","material":0,"exclusion":0.5}]},
		{"modifiers":[{"id":"a","mappings":[{"parameter":"district_size","field":"one","low":64,"high":128}]}],"fields":[{"id":"one","kind":"constant"}]},
		{"modifiers":[{"id":"a","mappings":[{"parameter":"relief","field":"one","low":0}]}]},
		{"modifiers":[{"id":"a","mappings":[{"parameter":"relief","field":"missing","low":0,"high":10}]}]},
		{"modules":[{"id":"a","module":"arcology","bounds":[0,0,128,128],"application":"missing"}]},
		{"modules":[{"id":"a","module":"arcology","bounds":[0,0,128,128],"strength":-0.1}]},
		{"limits":{"max_fields":65}}, {"limits":{"max_aggregates":33}}, {"limits":{"max_modifiers":65}},
	]
	for invalid: Dictionary in invalid_profiles:
		var rejected: Dictionary = generator.configure(invalid)
		expect(not rejected.ok and not str(rejected.get("error", "")).is_empty(), "Invalid extension recipe accepted: " + str(invalid))
	expect(generator.get_configuration() == recipe, "Rejected extension recipe replaced the accepted native plan")
	var completed: Dictionary = generator.advance(249)
	expect(completed.ok and completed.state == "ready" and completed.revision == accepted.revision and completed.diagnostics == inspected.diagnostics and completed.cells == inspected.cells, "Rejected recipes destroyed or altered the earlier diagnostic job")
	completed.diagnostics[0] = NAN
	completed.cells[0] = 255
	var copied: Dictionary = generator.advance(0)
	expect(copied.cells == inspected.cells and copied.diagnostics == inspected.diagnostics, "Ready diagnostic/material arrays borrow mutable native storage")
	expect(generator.begin_chunk(Vector2i.ZERO,"field:one").ok and generator.advance(3).completed_cells == 3, "Replacement cancellation fixture failed")
	var replaced: Dictionary = generator.configure(recipe)
	expect(replaced.ok and replaced.revision == accepted.revision + 1 and generator.advance(0).state == "idle", "Successful replacement did not cancel the pending diagnostic job and advance revision")
	var from_json: Dictionary = JSON.parse_string(JSON.stringify(recipe))
	expect(generator.configure(from_json).ok, "Exact integral JSON fields were rejected")
	var restored: Dictionary = generator.generate_chunk(Vector2i.ZERO,"field:mask")
	expect(restored.ok and restored.cells == inspected.cells and restored.diagnostics == inspected.diagnostics, "JSON profile round-trip changed material or diagnostic output")

	# Context is fixed before modifiers. Carving does not make later empty-only
	# paint eligible, even though the displayed result becomes empty.
	var fixed: Dictionary = base_recipe()
	fixed.modifiers = [{"id":"first","priority":0,"context":"solid","material":0}, {"id":"second","priority":1,"context":"empty","material":62}]
	expect(generator.configure(fixed).ok, "Fixed context fixture failed")
	var result: Dictionary = generator.generate_chunk(Vector2i.ZERO,"modifier:second")
	expect(result.ok and uniform(result.cells,0) and uniform(result.diagnostics,0), "Later contextual modifier reacted to earlier sculpt output")
	var aggregate: Dictionary = base_recipe()
	aggregate.fields = [{"id":"selector","kind":"constant","parameters":{"value":1}}]
	aggregate.aggregates = [{"id":"mix","components":[{"material":38,"weight":3},{"material":39,"weight":1}],"grain_size":7,"variation":"selector"}]
	aggregate.modifiers = [{"id":"paint","aggregate":"mix"}]
	expect(generator.configure(aggregate).ok, "Aggregate selector fixture failed")
	result = generator.generate_chunk(Vector2i.ZERO)
	expect(result.ok and uniform(result.cells,39), "Aggregate normalized selector did not reach its last weighted component")
	aggregate.fields[0].parameters.value = 0
	expect(generator.configure(aggregate).ok, "Aggregate zero-selector fixture failed")
	result = generator.generate_chunk(Vector2i.ZERO)
	expect(result.ok and uniform(result.cells,38), "Aggregate selector did not reach its first weighted component")

func drain(app: CyberWorldGenerationWorkbench) -> void:
	var calls: int = 0
	while (app._has_active_chunk or not app.pending_chunks.is_empty()) and calls < 512:
		app.service_generation()
		calls += 1
	expect(calls < 512 and not app._has_active_chunk and app.pending_chunks.is_empty(), "Field inspection queue did not drain within its bound")
	expect(app.cache.size() <= Workbench.MAX_CACHE_CHUNKS and app.pending_chunks.size() <= Workbench.MAX_QUEUED_CHUNKS, "Field inspection exceeded preview queue/cache capacity")

func check_loaded_defaults(app: CyberWorldGenerationWorkbench) -> void:
	var recipe: Dictionary = base_recipe()
	recipe.aggregates = [{"id":"implicit-grain","components":[{"material":38},{"material":39}]}]
	recipe.modifiers = [{"id":"implicit-priority","aggregate":"implicit-grain"}, {"id":"later-paint","priority":5,"bounds":[0,0,8,16],"material":62}]
	var original_generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var original_identity: Dictionary = original_generator.configure(recipe)
	expect(original_identity.ok and app.apply_recipe(recipe), "Omitted native-default fixture was not accepted")
	var original: Dictionary = original_generator.generate_chunk(Vector2i.ZERO)
	Workbench._select_reference(app.aggregate_choice,"implicit-grain")
	app._load_aggregate()
	var first_row: HBoxContainer = app.aggregate_rows.get_child(0)
	expect(app.aggregate_grain.value == 4 and (first_row.get_child(1) as SpinBox).value == 1, "Accepted aggregate displayed draft defaults instead of native grain 4 and weight 1")
	expect(app.apply_aggregate() and app._entry("aggregates","implicit-grain").grain_size == 4, "Unchanged aggregate apply changed its implicit native grain size")
	Workbench._select_reference(app.modifier_choice,"implicit-priority")
	app._load_modifier()
	expect(app.modifier_priority.value == 0, "Accepted modifier displayed draft priority instead of native priority 0")
	expect(app.apply_modifier() and app._entry("modifiers","implicit-priority").priority == 0, "Unchanged modifier apply changed its implicit native ordering")
	# Separate generators each begin at revision 1, so their canonical plan
	# fingerprints can compare omitted defaults with the UI's explicit defaults.
	var equivalent_generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	var equivalent_identity: Dictionary = equivalent_generator.configure(app.active_recipe)
	expect(equivalent_identity.ok and equivalent_identity.fingerprint == original_identity.fingerprint, "Reopening and applying omitted defaults changed canonical recipe semantics")
	var reapplied: Dictionary = app.generator.generate_chunk(Vector2i.ZERO)
	expect(original.ok and reapplied.ok and original.cells == reapplied.cells and original.hash == reapplied.hash, "Reopening and applying omitted defaults changed aggregate grains or modifier ordering")
	app.aggregate_choice.select(0)
	app._load_aggregate()
	app.modifier_choice.select(0)
	app._load_modifier()
	expect(app.aggregate_grain.value == 12 and app.modifier_priority.value == 10, "Intentional new-draft presets were lost when fixing accepted-entry defaults")

func check_workbench() -> void:
	root.size = Vector2i(1600,1000)
	var app: CyberWorldGenerationWorkbench = WorkbenchScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	await process_frame
	expect(app.generator != null and app.field_specs.size() == 22 and app.page_picker.item_count == 11 and app.page_picker.get_item_text(3) == "Fields & masks", "Native-backed field authoring pages did not initialize")
	if app.generator == null:
		app.queue_free()
		return
	expect(app.apply_recipe(extension_recipe()), "Workbench did not accept the full extension recipe")
	app.field_choice.select(0)
	app.field_id.text = "ui-noise"
	Workbench._select_text(app.field_kind,"fbm")
	app._refresh_field_parameters({})
	expect(app.field_parameter_inputs.scale.value == 128 and app.field_parameter_inputs.octaves.max_value == 6 and not app.field_warp_x.disabled, "Guided noise controls diverge from native defaults/ranges")
	app.field_parameter_inputs.scale.value = 27
	app.field_parameter_inputs.salt.value = 23
	expect(app.apply_field() and app._entry("fields","ui-noise").parameters.scale == 27, "Guided field controls did not create an accepted native field")
	app.field_choice.select(0)
	app.field_id.text = "material-filter"
	Workbench._select_text(app.field_kind,"material")
	app._refresh_field_parameters({})
	var material_control: OptionButton = app.field_parameter_inputs.material
	expect(material_control.get_item_index(10) == -1 and material_control.get_item_index(255) == -1, "Material field picker offers reserved/invalid material IDs")
	material_control.select(material_control.get_item_index(38))
	expect(app.apply_field() and app._entry("fields","material-filter").parameters.material == 38, "Native material context field could not be authored")
	var revision: int = app.active_revision
	expect(not app.delete_entry("fields","mask") and app.active_revision == revision, "Deleting an in-use field silently left dangling masks")
	app.aggregate_choice.select(0)
	app.aggregate_id.text = "ui-grain"
	app.aggregate_grain.value = 11
	app.aggregate_components = [{"material":38,"weight":2.0},{"material":39,"weight":1.0}]
	app._render_aggregate_rows()
	Workbench._select_reference(app.aggregate_variation,"one")
	expect(app.apply_aggregate() and app._entry("aggregates","ui-grain").grain_size == 11 and app._entry("aggregates","ui-grain").variation == "one", "Guided aggregate recipe lost its grain or variation driver")
	var row: HBoxContainer = app.aggregate_rows.get_child(0)
	(row.get_child(1) as SpinBox).value = 4
	expect(app.aggregate_components[0].weight == 4 and app.aggregate_components[1].weight == 1, "Aggregate component control edited the wrong row")
	expect(app.apply_aggregate(), "Aggregate weight edit could not be applied")
	app.modifier_choice.select(0)
	app.modifier_id.text = "ui-paint"
	app.modifier_json.text = "{}"
	app.modifier_bounds.text = "[0,0,16,16]"
	app.modifier_action.select(2)
	Workbench._select_reference(app.modifier_application,"one")
	Workbench._select_reference(app.modifier_exclusion,"zero")
	Workbench._select_reference(app.modifier_aggregate,"ui-grain")
	Workbench._select_text(app.modifier_context,"any")
	expect(app.apply_modifier(), "Guided masked aggregate modifier failed: " + app.last_error)
	var result: Dictionary = app.generator.generate_chunk(Vector2i.ZERO)
	expect(result.ok and result.cells[0] == 39 and result.cells[4*16+4] == 62, "Guided aggregate paint or final hard override failed")
	var original: Dictionary = app._entry("modifiers","ui-paint")
	expect(app.transform_modifier("ui-paint",Vector2(5,-3),2), "Selected bounds modifier could not be transformed")
	expect(app._entry("modifiers","ui-paint").bounds == [-3,-11,32,32], "Bounds transform did not scale about the center and then translate")
	app.undo_authoring()
	expect(same_json(app._entry("modifiers","ui-paint"),original), "Undo did not restore the accepted modifier before transformation")
	app.modifier_choice.select(0)
	app.modifier_id.text = "mapped"
	app.modifier_json.text = "{}"
	app.modifier_bounds.text = ""
	app.modifier_action.select(4)
	Workbench._select_text(app.modifier_parameter,"cave_threshold")
	app._modifier_parameter_range()
	app.modifier_low.value = 0.25
	app.modifier_high.value = 0.75
	Workbench._select_reference(app.modifier_mapping_field,"noise")
	expect(app.apply_modifier() and app._entry("modifiers","mapped").mappings[0].field == "noise", "Guided field-to-parameter mapping failed")
	expect(not app.transform_modifier("mapped",Vector2.ONE,2), "World-wide modifier acquired invented transform bounds")
	Workbench._select_reference(app.module_choice,"shell")
	app._load_module_instance()
	Workbench._select_reference(app.module_application,"one")
	Workbench._select_reference(app.module_exclusion,"zero")
	app.module_strength.value = 0.5
	expect(app.apply_module_instance() and app._entry("modules","shell").strength == 0.5 and app._entry("modules","shell").bounds == [-64,-64,128,128], "Existing module mask edit lost its placement or strength")
	var advanced: Dictionary = app.active_recipe.duplicate(true)
	app.parameter_inputs.relief.value = 9
	app.apply_controls()
	for section: String in ["fields","aggregates","modifiers","modules"]:
		expect(same_json(app.active_recipe[section],advanced[section]), "Fine generator controls rewrote advanced " + section)
	Workbench._select_reference(app.brush_application,"one")
	Workbench._select_reference(app.brush_exclusion,"zero")
	Workbench._select_text(app.brush_context,"solid")
	Workbench._select_reference(app.brush_aggregate,"ui-grain")
	app.radius_input.value = 12
	app.strength_input.value = 1
	app.tool_picker.select(6)
	app.add_gesture(PackedVector2Array([Vector2(-2,7),Vector2(18,7)]))
	var sculpt: Dictionary = app.active_recipe.modifiers[-1]
	expect(sculpt.material == 0 and sculpt.context == "solid" and sculpt.application == "one" and sculpt.exclusion == "zero", "Contextual carve did not author a masked native point modifier")
	expect(app.transform_modifier(str(sculpt.id),Vector2(4,2),0.5), "Point modifier could not be transformed")
	var moved: Dictionary = app._entry("modifiers",str(sculpt.id))
	expect(same_json(moved.points,[[7,9],[17,9]]) and moved.radius == 6, "Point transform did not use the centroid and scale its radius")
	for mode: int in [7,8,9,10]:
		var count: int = app.active_recipe.modifiers.size()
		app.tool_picker.select(mode)
		app.add_gesture(PackedVector2Array([Vector2(8,8)]))
		expect(app.active_recipe.modifiers.size() == count+1, "Contextual brush mode did not add its native action: " + str(mode))
	drain(app)
	app._inspect_point(Vector2(4,4))
	app._pick_context_material()
	expect(app.brush_context.get_item_text(app.brush_context.selected) == "material" and app.brush_context_material.get_selected_id() == 62, "Inspected final material could not be selected as the context predicate ID")
	var old_packet: Dictionary = app.last_packet.duplicate(true)
	revision = app.active_revision
	var undo_count: int = app._undo.size()
	var token: int = app._view_token
	expect(app.select_diagnostic("field:mask"), "Accepted field could not be selected for inspection")
	expect(app.active_revision == revision and app._undo.size() == undo_count and app._view_token != token and app.cache.is_empty(), "Inspection selection changed the recipe or retained stale material-only previews")
	expect(not app.accept_chunk(old_packet), "Packet from the previous diagnostic channel entered the inspection cache")
	drain(app)
	var packet: Dictionary = app.generator.generate_chunk(Vector2i.ZERO,"field:mask")
	expect(app.accept_chunk(packet,Vector2i.ZERO,app._view_token), "Complete native diagnostic packet could not be displayed")
	expect(app.cache[Vector2i.ZERO].has("diagnostic_texture"), "Diagnostic values were not converted to a preview texture")
	expect(not app.accept_chunk(packet,Vector2i.ZERO,token), "Old inspection completion token was accepted for the same recipe")
	var malformed: Dictionary = packet.duplicate(true)
	malformed.diagnostics = PackedFloat32Array([0])
	expect(not app.accept_chunk(malformed), "Diagnostic extent mismatch entered preview storage")
	malformed = packet.duplicate(true)
	malformed.diagnostics[0] = NAN
	expect(not app.accept_chunk(malformed), "Non-finite mask value entered the preview")
	malformed = packet.duplicate(true)
	malformed.diagnostics[0] = 1.1
	expect(not app.accept_chunk(malformed), "Out-of-range mask value entered the preview")
	malformed = packet.duplicate(true)
	malformed.diagnostic = "field:one"
	expect(not app.accept_chunk(malformed), "Different diagnostic channel entered the current inspection")
	packet.diagnostics[0] = 0.5
	expect(app.cache[Vector2i.ZERO].diagnostics[0] == 0, "Preview retained caller-mutable diagnostic bytes")
	app._inspect_point(Vector2(8,8))
	expect(app.pointer_label.text.contains("field:mask = 1.00000"), "Pointer inspection does not report the native Ready value")
	expect(not app.select_diagnostic("field:missing") and app.diagnostic_channel == "field:mask", "Unknown diagnostic selection changed the accepted inspection")
	var save_path: String = "user://worldgen-fields-test-profile.json"
	var saved_recipe: Dictionary = app.active_recipe.duplicate(true)
	var saved_packet: Dictionary = app.generator.generate_chunk(Vector2i.ZERO,"field:mask")
	expect(app.save_profile(save_path) and app.load_profile(save_path), "Complete field recipe could not save/load")
	app.apply_json()
	expect(same_json(app.active_recipe,saved_recipe), "Profile persistence lost field, aggregate, modifier or module-mask data")
	var restored: Dictionary = app.generator.generate_chunk(Vector2i.ZERO,"field:mask")
	expect(restored.ok and restored.cells == saved_packet.cells and restored.diagnostics == saved_packet.diagnostics, "Persisted profile changed native material or inspection values")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var fields_count: int = app.active_recipe.fields.size()
	var aggregates_count: int = app.active_recipe.aggregates.size()
	app.clear_authoring()
	expect(app.active_recipe.fields.size() == fields_count and app.active_recipe.aggregates.size() == aggregates_count and app.active_recipe.modifiers.is_empty() and app.active_recipe.modules.is_empty(), "Clear marks destroyed reusable field/aggregate recipes or retained contextual actions")
	expect(app.select_diagnostic(""), "Material preview could not be restored")
	malformed = app.generator.generate_chunk(Vector2i.ZERO)
	malformed.diagnostics = PackedFloat32Array([0.5])
	expect(not app.accept_chunk(malformed), "Unrequested diagnostic payload entered the materials-only preview")
	# Authoring scalar arithmetic must not narrow accepted world coordinates to
	# Vector2's single-precision storage, including identity transforms.
	var far_bounds: Dictionary = {"id":"far-bounds","bounds":[16777217,16777219,33,17],"material":0}
	expect(app.upsert_entry("modifiers",far_bounds), "Large-coordinate bounds fixture was not admitted")
	expect(app.transform_modifier("far-bounds",Vector2.ZERO,1) and app._entry("modifiers","far-bounds").bounds == far_bounds.bounds, "Identity transform rounded large integer bounds through single-precision coordinates")
	expect(app.transform_modifier("far-bounds",Vector2(1,-1),1) and app._entry("modifiers","far-bounds").bounds == [16777218,16777218,33,17], "Large-coordinate translation lost an exact cell")
	var far_points: Dictionary = {"id":"far-points","points":[[0.1,0.2],[16777217.125,16777219.25]],"radius":4,"material":0}
	expect(app.upsert_entry("modifiers",far_points), "Large-coordinate point fixture was not admitted")
	expect(app.transform_modifier("far-points",Vector2.ZERO,1) and app._entry("modifiers","far-points").points == far_points.points, "Identity transform narrowed point coordinates or lost precision through centroid cancellation")
	check_loaded_defaults(app)
	app.queue_free()
	await process_frame

func run() -> void:
	if not ClassDB.class_exists(&"CyberWorldGenerator"):
		push_error("Source-matched CyberWorldGenerator is required; a missing runtime is not field-authoring acceptance")
		quit(1)
		return
	var generator: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
	if not generator.get_catalogue().has("field_kinds"):
		push_error("Loaded native runtime predates GEN-002 field authoring")
		quit(1)
		return
	check_catalogue()
	check_adapter()
	await check_workbench()
	print("WORLDGEN_FIELDS: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
