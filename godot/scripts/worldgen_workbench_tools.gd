extends RefCounted

# Workbench 2 owns only copied recipes, plans and diagnostic proposals. No World
# or scene-tree native owner is reachable from these authoring jobs.
const PLANES: Array[String] = ["play", "scripted", "effects", "background"]
const STAGES: Array[String] = ["final", "candidate", "guided_candidate", "grammar", "modifiers", "connectivity"]
const MAX_AUX_JOBS: int = 4
const MAX_COMPARE_AXIS: int = 128
const AUX_CELL_BUDGET: int = 256
const MAX_TRACE_BYTES: int = 262144
const MAX_SEMANTIC_CHANGES: int = 64
const MAX_COMPARE_RECORDS: int = 4096
const MAX_GRAPH_NODES: int = 256
const MAX_STREAMLINES: int = 24
const MAX_STREAMLINE_STEPS: int = 64

var app: Variant
var session: int = 0
var plan: Dictionary = {}
var plane_plan: Dictionary = {}
var selected_plane: String = "play"
var selected_stage: String = "final"
var composite: bool = false
var trace: Dictionary = {}
var trace_token: Dictionary = {}
var last_comparison: Dictionary = {}
var pinned_recipe: Dictionary = {}
var has_pin: bool = false
var pinned_bounds := Rect2i()
var aux_jobs: Array[Dictionary] = []
var aux_active: Dictionary = {}
var aux_results: Array[Dictionary] = []
var aux_serial: int = 0
var aux_kind: String = ""
var aux_thread: Thread
var graph_window: Window
var graph: GraphEdit
var graph_namespace: OptionButton
var graph_new_kind: OptionButton
var graph_new_id: LineEdit
var graph_section: OptionButton
var graph_node_ids: Dictionary = {}
var graph_output_ids: Dictionary = {}
var graph_new_subgraph: OptionButton
var graph_positions: Dictionary = {}
var node_editor: TextEdit
var node_parameter_box: VBoxContainer
var node_label: Label
var node_selected: String = ""
var namespace_ids: Array[String] = []
var graph_status: Label
var hierarchy: Tree
var feature_view: RichTextLabel
var selected_feature_record: Dictionary = {}
var hierarchy_editor: TextEdit
var hierarchy_rule: OptionButton
var layer_editor: TextEdit
var plane_picker: OptionButton
var stage_picker: OptionButton
var trace_view: RichTextLabel
var quality_label: Label
var histogram: VBoxContainer
var seed_input: LineEdit
var seed_cards: VBoxContainer
var aux_status: Label
var overlay_picker: OptionButton
var plane_revision: String = ""

func _init(owner: Variant) -> void:
	app = owner

func _options(parent: Node, values: Array) -> OptionButton:
	var names: Array[String] = []
	for value: Variant in values: names.append(str(value))
	return app._options(parent, names)

func _label(parent: Node, text: String) -> Label:
	return app._note(parent, text)

func _button(parent: Node, text: String, method: Callable) -> Button:
	return app._button(parent, text, method)

func build_graph_tab(box: VBoxContainer) -> void:
	_label(box, "TYPED GRAPH CANVAS")
	_label(box, "Ports carry native output types and units. Connections, operator parameters and namespace edits are validated as one complete candidate. Failed edits leave the accepted graph and undo history intact.")
	_button(box, "Open graph canvas…", open_graph)
	graph_status = _label(box, "Load a typed spatial example, or add a node in Typed spatial graphs.")
	_label(box, "LEGACY SCALAR FIELDS")
	_label(box, "The canvas also edits the scalar fields that feed application/exclusion masks. Select Fields in the canvas; masks keep their native normalized values.")
	_button(box, "Load vector / streamlines example", func() -> void: app.load_spatial_example("typed-vector-utilities"))
	_button(box, "Load reusable namespace example", func() -> void: app.load_spatial_example("typed-reusable-decay"))
	_button(box, "Load GEN-007 Deepworks recipe", load_qualification)

func build_hierarchy_tab(box: VBoxContainer) -> void:
	_label(box, "ACCEPTED SEMANTIC HIERARCHY")
	hierarchy = Tree.new()
	hierarchy.custom_minimum_size = Vector2(0, 250)
	hierarchy.hide_root = true
	hierarchy.columns = 1
	hierarchy.item_selected.connect(_select_feature)
	box.add_child(hierarchy)
	_label(box, "Selected feature metadata is separate from the cell replay at its bounds origin. A selected node is not necessarily that cell's material producer.")
	feature_view = RichTextLabel.new()
	feature_view.custom_minimum_size = Vector2(0, 160)
	feature_view.selection_enabled = true
	feature_view.text = "Select a feature to inspect its accepted record and parent chain."
	box.add_child(feature_view)
	hierarchy_rule = _options(box, [])
	hierarchy_rule.item_selected.connect(func(_index: int) -> void: _show_rule())
	hierarchy_editor = TextEdit.new()
	hierarchy_editor.custom_minimum_size = Vector2(0, 180)
	hierarchy_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(hierarchy_editor)
	_button(box, "Validate and apply selected rule", apply_rule)
	_label(box, "PLANE / ADAPTER RECIPE")
	_label(box, "Edit policies, projection templates, fixture schedules and links together. All supported fields roundtrip; native endpoint and budget validation remains authoritative.")
	layer_editor = TextEdit.new()
	layer_editor.custom_minimum_size = Vector2(0, 200)
	layer_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(layer_editor)
	_button(box, "Validate and apply plane data", apply_plane_json)

func build_inspector_tab(box: VBoxContainer) -> void:
	_label(box, "WHY IS THIS HERE?")
	_label(box, "Ctrl-click a cell, or enable Inspect clicks. Native deterministic replay is bound to the accepted recipe and plane revision. It never reads or changes a simulation World.")
	_button(box, "Enable Inspect clicks", func() -> void: app.inspect_toggle.button_pressed = true)
	trace_view = RichTextLabel.new()
	trace_view.custom_minimum_size = Vector2(0, 570)
	trace_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trace_view.selection_enabled = true
	trace_view.bbcode_enabled = false
	trace_view.text = "Click a ready cell or select a semantic feature. Missing detail is reported as unavailable; colour is never used to infer a native cause."
	box.add_child(trace_view)

func build_quality_tab(box: VBoxContainer) -> void:
	_label(box, "DENSITY / WORK")
	quality_label = _label(box, "Load a recipe to inspect actual semantic counts and native work declarations.")
	histogram = VBoxContainer.new()
	box.add_child(histogram)
	_label(box, "BEFORE / AFTER")
	_label(box, "Pin a recipe and bounded rectangle. Compare uses the same seed and absolute coordinates for both versions; material differences are exact, and semantic changes compare copied native records.")
	_button(box, "Pin current recipe and view", pin_before)
	_button(box, "Compare pinned / accepted", start_comparison)
	_label(box, "DETERMINISTIC SEED VARIATIONS")
	seed_input = app._text_input(box, "At most four portable integer seeds", "19301,19317,19337,19361")
	_button(box, "Generate seed cards", start_seed_browser)
	_button(box, "Cancel auxiliary jobs", cancel_auxiliary)
	aux_status = _label(box, "Comparison and seed buffers are bounded to four jobs, 128 × 128 cells per plane, and one active native owner.")
	seed_cards = VBoxContainer.new()
	box.add_child(seed_cards)

func build_view_controls(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	app._label(row, "Plane", 13)
	plane_picker = _options(row, ["Play", "Rear", "Atmosphere", "Far", "Four-plane composite"])
	plane_picker.item_selected.connect(func(index: int) -> void: select_plane(index))
	app._label(row, "Stage", 13)
	stage_picker = _options(row, STAGES)
	stage_picker.item_selected.connect(func(index: int) -> void: select_stage(stage_picker.get_item_text(index)))
	overlay_picker = _options(row, ["No extra overlay", "Feature bounds / sockets / routes", "Vector arrows", "Bounded streamlines", "Semantic feature density", "Measured chunk time", "Charged logical work"])
	overlay_picker.item_selected.connect(func(index: int) -> void:
		app.preview.extra_overlay = index
		app.preview.queue_redraw())

func load_qualification() -> bool:
	var path: String = ProjectSettings.globalize_path("res://../examples/worldgen/gen007-deepworks.json")
	var recipe: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not recipe is Dictionary:
		app._set_error("GEN-007 qualification recipe is unavailable or invalid JSON.")
		return false
	if not app.apply_recipe(recipe): return false
	var size: int = int(app.active_recipe.get("chunk_size", 128))
	app.view_size = Vector2(size * 4, size * 3)
	app.set_camera_origin(Vector2.ZERO)
	return true

func capture_token() -> Dictionary:
	return {"session":session, "view":app._view_token, "revision":app.active_revision, "fingerprint":app.active_fingerprint, "plane":selected_plane, "stage":selected_stage, "plane_revision":plane_revision}

func accepts_token(token: Dictionary, include_view: bool = true) -> bool:
	return int(token.get("session", -1)) == session and int(token.get("revision", -1)) == app.active_revision and str(token.get("fingerprint", "")) == app.active_fingerprint and str(token.get("plane_revision", "")) == plane_revision and (not include_view or (int(token.get("view", -1)) == app._view_token and str(token.get("plane", "")) == selected_plane and str(token.get("stage", "")) == selected_stage))

func retire_results() -> void:
	session += 1
	retire_trace("The recipe changed. Click a cell to replay the new accepted identity.")
	last_comparison.clear()
	cancel_auxiliary()

func retire_trace(reason: String) -> void:
	trace.clear()
	trace_token.clear()
	if trace_view != null: trace_view.text = reason
	if app.pointer_label != null:
		app.pointer_label.text = "Click a ready cell to inspect the current view."
		app.pointer_label.tooltip_text = ""
	app._inspected_material = -1

func on_recipe_accepted() -> void:
	retire_results()
	plan = app.generator.get_semantic_plan() if app.active_recipe.has("grammar") else {}
	plane_plan = app.generator.get_plane_plan() if app.active_recipe.has("semantic_planes") else {}
	plane_revision = str(plane_plan.get("revision", ""))
	if plane_plan.is_empty():
		selected_plane = "play"
		composite = false
		plane_picker.select(0)
	for index: int in range(1, 5): plane_picker.set_item_disabled(index, plane_plan.is_empty())
	_refresh_stage_choices()
	app.preview.semantic_plan = plan.duplicate(true)
	app.preview.route_report = app.semantic_route_report.duplicate(true)
	_refresh_hierarchy()
	_refresh_metrics()
	if graph_window != null: _refresh_graph()
	if graph_status != null:
		graph_status.text = "%d compiled typed nodes · %d scalar fields · %d named subgraphs" % [app.spatial_nodes.size(), app.active_recipe.get("fields", []).size(), app.active_recipe.get("spatial", {}).get("subgraphs", []).size()]
	layer_editor.text = JSON.stringify(app.active_recipe.get("semantic_planes", {}), "  ", true, true)

func _refresh_stage_choices() -> void:
	if stage_picker == null: return
	stage_picker.clear()
	var available: Array = STAGES.duplicate()
	if not plane_plan.is_empty():
		available = ["final", "policy", "base", "projections"]
		for policy: Dictionary in plane_plan.get("policies", []):
			if str(policy.plane) == selected_plane and bool(policy.get("base_generator", false)):
				available.append_array(STAGES.slice(1))
	if composite: available = ["final"]
	if not selected_stage in available: selected_stage = "final"
	for stage: String in available: stage_picker.add_item(stage)
	app._select_text(stage_picker, selected_stage)

func select_plane(index: int) -> bool:
	if index < 0 or index > 4 or (index > 0 and plane_plan.is_empty()):
		app._set_error("This recipe has no accepted semantic four-plane bundle.")
		return false
	selected_plane = PLANES[mini(index, 3)] if index < 4 else "play"
	composite = index == 4
	plane_picker.select(index)
	_refresh_stage_choices()
	app.reset_view_jobs()
	return true

func select_stage(stage: String) -> bool:
	var allowed: bool = false
	for index: int in range(stage_picker.item_count): allowed = allowed or stage_picker.get_item_text(index) == stage
	if not allowed:
		app._set_error("That intermediate stage is unavailable for this native plane.")
		return false
	selected_stage = stage
	app._select_text(stage_picker, stage)
	app.reset_view_jobs()
	return true

func uses_plane_preview() -> bool:
	return not plane_plan.is_empty() and app.diagnostic_channel.is_empty()

func chunk_bounds(coordinate: Vector2i) -> Rect2i:
	var size: int = int(app.active_recipe.get("chunk_size", 128))
	return Rect2i(coordinate * size, Vector2i.ONE * size)

func begin_preview(coordinate: Vector2i) -> Dictionary:
	if not uses_plane_preview():
		var channel: String = app.diagnostic_channel
		if channel.is_empty() and selected_stage != "final": channel = "stage:" + selected_stage
		return app.generator.begin_chunk(coordinate, channel)
	var bounds: Rect2i = chunk_bounds(coordinate)
	var area: Rect2i = plane_plan.bounds
	if not area.encloses(bounds): return {"ok":false, "error":"Chunk extends beyond the finite semantic plane bounds; no out-of-plan content is invented."}
	if selected_stage == "final": return app.generator.begin_plane_region(bounds)
	if not app.generator.has_method(&"begin_stage_region"):
		return {"ok":false, "error":"The loaded native runtime has no genuine plane-stage API."}
	return app.generator.begin_stage_region(bounds, selected_plane, selected_stage)

func advance_preview(budget: int) -> Dictionary:
	if not uses_plane_preview(): return app.generator.advance(budget)
	if selected_stage == "final": return app.generator.advance_plane_region(budget)
	return app.generator.advance_stage_region(budget)

func normalize_plane_packet(packet: Dictionary, coordinate: Vector2i) -> Dictionary:
	if not uses_plane_preview(): return packet
	if not packet.get("ok", false) or str(packet.get("state", "")) != "ready": return packet
	# The native adapter serial and plane fingerprint are checked before the
	# presentation envelope is constructed. Never relabel an old payload as new.
	var stage_packet: bool = selected_stage != "final"
	var matches: bool = int(packet.get("adapter_serial", -1)) == app.active_revision
	if stage_packet:
		matches = matches and str(packet.get("plane_fingerprint", "")) == plane_revision and str(packet.get("plane", "")) == selected_plane and int(packet.get("revision", -1)) == app.active_revision and str(packet.get("fingerprint", "")) == app.active_fingerprint and str(packet.get("stage", "")) == selected_stage
	else:
		matches = matches and str(packet.get("revision", "")) == plane_revision
	if not matches:
		return {"ok":false, "state":"failed", "error":"Stale native plane proposal rejected."}
	if packet.get("bounds") != chunk_bounds(coordinate):
		return {"ok":false, "state":"failed", "error":"Plane proposal bounds do not match the requested chunk."}
	var cells: PackedByteArray
	if packet.has("materials"):
		cells = packet.materials.get(selected_plane, PackedByteArray())
	elif packet.has("cells"):
		cells = packet.get("final_cells", packet.cells)
	else: return {"ok":false, "state":"failed", "error":"Native plane proposal is missing material bytes."}
	var result: Dictionary = packet.duplicate(true)
	result["plane_revision"] = plane_revision
	result["native_plane_fingerprint"] = str(packet.get("plane_fingerprint", "")) if stage_packet else str(packet.get("revision", ""))
	if not stage_packet: result["native_bundle_fingerprint"] = str(packet.get("fingerprint", ""))
	result["revision"] = app.active_revision
	result["fingerprint"] = app.active_fingerprint
	result["chunk_x"] = coordinate.x
	result["chunk_y"] = coordinate.y
	result["chunk_size"] = int(app.active_recipe.get("chunk_size", 128))
	result["cells"] = cells
	result["diagnostic"] = ""
	result["hash"] = str(packet.get("hashes", {}).get(selected_plane, "unavailable"))
	if stage_packet:
		result["stage_cells"] = packet.cells.duplicate()
		result["stage_hash"] = str(packet.get("hash", "unavailable"))
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(cells)
		result["final_bytes_sha256"] = digest.finish().hex_encode()
	result["display_plane"] = selected_plane
	result["display_stage"] = selected_stage
	result["display_composite"] = composite
	return result

func material_pixels(cells: PackedByteArray, transparent_empty: bool = false) -> PackedByteArray:
	var rgba := PackedByteArray()
	rgba.resize(cells.size() * 4)
	for index: int in range(cells.size()):
		var material: int = int(cells[index])
		if material >= app.Palette.MATERIAL_COUNT or material == 10: return PackedByteArray()
		var packed: int = int(app.Palette.BASE_RGBA8[material])
		rgba[index * 4] = (packed >> 24) & 255
		rgba[index * 4 + 1] = (packed >> 16) & 255
		rgba[index * 4 + 2] = (packed >> 8) & 255
		rgba[index * 4 + 3] = 0 if transparent_empty and material == 0 else 255
	return rgba

func display_texture(packet: Dictionary) -> ImageTexture:
	var size: int = int(packet.chunk_size)
	var materials: Dictionary = packet.get("materials", {})
	var pixels: PackedByteArray = material_pixels(packet.get("stage_cells", packet.cells))
	if pixels.is_empty(): return null
	if composite and packet.get("display_composite", false) and materials.size() == 4:
		# A generation-only composite uses actual native plane cells at the same
		# coordinate; it intentionally applies no camera/parallax transform.
		var colours: Dictionary = {}
		for plane: String in PLANES:
			if not materials.get(plane) is PackedByteArray or materials[plane].size() != size * size: return null
			colours[plane] = material_pixels(materials[plane])
			if colours[plane].is_empty(): return null
		for index: int in range(size * size):
			var colour := Color(0.025, 0.035, 0.055)
			for plane: String in ["background", "effects", "scripted", "play"]:
				if materials[plane][index] == 0: continue
				var rgba: PackedByteArray = colours[plane]
				var front := Color(float(rgba[index * 4]) / 255.0, float(rgba[index * 4 + 1]) / 255.0, float(rgba[index * 4 + 2]) / 255.0)
				var opacity: float = {"background":0.35, "effects":0.28, "scripted":0.65, "play":1.0}[plane]
				colour = colour.lerp(front, opacity)
			pixels[index * 4] = colour.r8
			pixels[index * 4 + 1] = colour.g8
			pixels[index * 4 + 2] = colour.b8
	return ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, pixels))

func inspect_point(position: Vector2i) -> Dictionary:
	var token: Dictionary = capture_token()
	if not app.generator.has_method(&"inspect_generation"):
		app._set_error("This runtime has no identity-bound generation inspector; rebuild for GEN-007.")
		return {}
	var result: Dictionary = app.generator.inspect_generation(position, selected_plane if not plane_plan.is_empty() else "", app.active_revision, app.active_fingerprint)
	if not accept_trace(result, token): return {"ok":false, "error":"Inspection was rejected; see the provenance pane for its reason."}
	return trace.duplicate(true)

func accept_trace(result: Dictionary, token: Dictionary) -> bool:
	if not accepts_token(token) or not bool(result.get("ok", false)):
		if trace_view != null: trace_view.text = "Inspection unavailable: " + str(result.get("error", "request identity retired"))
		return false
	if int(result.get("revision", -1)) != app.active_revision or str(result.get("fingerprint", "")) != app.active_fingerprint:
		if trace_view != null: trace_view.text = "Inspection rejected: native recipe identity does not match the accepted preview."
		return false
	if str(result.get("plane", "")) != selected_plane or (not plane_plan.is_empty() and str(result.get("plane_fingerprint", "")) != plane_revision):
		if trace_view != null: trace_view.text = "Inspection rejected: native semantic plane identity does not match the selected plane."
		return false
	result = result.duplicate(true)
	var position: Vector2i = result.get("position", Vector2i(-2147483648, -2147483648))
	var size: int = int(app.active_recipe.get("chunk_size", 128))
	var coordinate := Vector2i(floori(float(position.x) / size), floori(float(position.y) / size))
	var cached: Dictionary = app.cache.get(coordinate, {})
	if not cached.is_empty() and int(cached.get("revision", -1)) == app.active_revision and str(cached.get("fingerprint", "")) == app.active_fingerprint:
		var cells: PackedByteArray = cached.get("materials", {}).get(selected_plane, cached.cells)
		var index: int = (position.y - coordinate.y * size) * size + position.x - coordinate.x * size
		if index >= 0 and index < cells.size() and (plane_plan.is_empty() or cached.has("display_plane")):
			if int(result.get("material", -1)) != int(cells[index]):
				if trace_view != null: trace_view.text = "REJECTED: native replay disagrees with the accepted proposal at this cell."
				return false
			result["preview_comparison"] = {"status":"matches accepted native proposal", "material":int(cells[index]), "receipt_hash":str(cached.get("receipt_hash", "unavailable")), "content_hash":str(cached.get("hash", "unavailable"))}
			if cached.has("stage_hash"):
				result.preview_comparison["stage_hash"] = str(cached.stage_hash)
				result.preview_comparison["stage_hash_scope"] = "native selected intermediate bytes; not the final cells compared above"
				result.preview_comparison["final_bytes_sha256"] = str(cached.get("final_bytes_sha256", "unavailable"))
				result.preview_comparison["final_bytes_sha256_scope"] = "independent workbench digest of copied final material bytes"
		else: result["preview_comparison"] = {"status":"unavailable", "reason":"Selected semantic plane is not the displayed diagnostic material source."}
	else: result["preview_comparison"] = {"status":"unavailable", "reason":"This cell has no completed accepted preview proposal yet."}
	var text: String = JSON.stringify(result, "  ", true, true)
	if text.to_utf8_buffer().size() > MAX_TRACE_BYTES:
		if trace_view != null: trace_view.text = "Inspection unavailable: copied trace exceeds the 256 KiB workbench budget. Native result was not retained."
		return false
	trace = result.duplicate(true)
	trace_token = token.duplicate(true)
	if trace_view != null:
		trace_view.text = "DETERMINISTIC NATIVE REPLAY\nCell %d, %d · %s · material %d\nAccepted session %d · revision %d\n%s\n%s\nStages: %s\n\nCOPIED NATIVE DETAIL\n%s" % [position.x, position.y, selected_plane, int(result.get("material", -1)), session, app.active_revision, str(result.preview_comparison.status), "TRUNCATED: consult unavailable/detail markers." if result.get("truncated", false) else "Complete within the reported native trace scope.", JSON.stringify(result.get("stages", "unavailable")), text]
	return true

func _refresh_hierarchy() -> void:
	hierarchy.clear()
	selected_feature_record.clear()
	app.preview.selected_feature = ""
	if feature_view != null: feature_view.text = "Select a feature to inspect its accepted record and parent chain."
	var root: TreeItem = hierarchy.create_item()
	var items: Dictionary = {}
	var features: Array = plan.get("features", [])
	# Export order is usually parent-first, but a second pass avoids relying on it.
	for feature: Dictionary in features:
		var item: TreeItem = hierarchy.create_item(root)
		item.set_text(0, "%s / %s" % [str(feature.kind), str(feature.id).get_file()])
		item.set_metadata(0, feature.duplicate(true))
		item.set_tooltip_text(0, "%s\nRule %s\nBounds %s" % [feature.id, feature.get("rule_id", ""), str(feature.bounds)])
		items[str(feature.id)] = item
	for feature: Dictionary in features:
		var parent: String = str(feature.get("parent", ""))
		if items.has(parent):
			var item: TreeItem = items[str(feature.id)]
			root.remove_child(item)
			items[parent].add_child(item)
	hierarchy_rule.clear()
	for rule: Dictionary in app.active_recipe.get("grammar", {}).get("rules", []): hierarchy_rule.add_item(str(rule.id))
	_show_rule()

func _select_feature() -> void:
	var item: TreeItem = hierarchy.get_selected()
	if item == null: return
	var feature: Dictionary = item.get_metadata(0)
	var by_id: Dictionary = {}
	for accepted: Dictionary in plan.get("features", []): by_id[str(accepted.id)] = accepted
	var ancestry: Array[String] = []
	var parent: String = str(feature.get("parent", ""))
	while by_id.has(parent) and ancestry.size() < 64 and not parent in ancestry:
		ancestry.push_front(parent)
		parent = str(by_id[parent].get("parent", ""))
	selected_feature_record = {"feature":feature.duplicate(true), "ancestry":ancestry, "ancestry_truncated":not parent.is_empty(), "revision":app.active_revision, "fingerprint":app.active_fingerprint, "association":"Selected semantic tree node. Bounds-origin cell replay below is separate; this record is not a claim about that cell's material producer."}
	feature_view.text = "ACCEPTED SELECTED FEATURE\n" + JSON.stringify(selected_feature_record, "  ", true, true)
	var bounds: Array = feature.get("bounds", [])
	if bounds.size() == 4:
		app.set_camera_origin(Vector2(float(bounds[0]), float(bounds[1])))
		inspect_point(Vector2i(int(bounds[0]), int(bounds[1])))
	app.preview.selected_feature = str(feature.id)
	app.preview.extra_overlay = 1
	overlay_picker.select(1)
	app._select_text(hierarchy_rule, str(feature.get("rule_id", "")))
	_show_rule()

func _show_rule() -> void:
	if hierarchy_rule.item_count == 0:
		hierarchy_editor.text = "{}"
		return
	var id: String = hierarchy_rule.get_item_text(hierarchy_rule.selected)
	for rule: Dictionary in app.active_recipe.get("grammar", {}).get("rules", []):
		if str(rule.id) == id:
			hierarchy_editor.text = JSON.stringify(rule, "  ", true, true)
			return

func _parse_object(editor: TextEdit, context: String) -> Dictionary:
	if editor.text.to_utf8_buffer().size() > app.MAX_PROFILE_BYTES:
		app._set_error(context + " exceeds the profile byte budget.")
		return {"ok":false}
	var parser := JSON.new()
	if parser.parse(editor.text) != OK or not parser.data is Dictionary:
		app._set_error(context + " must be a JSON object: " + parser.get_error_message())
		return {"ok":false}
	return {"ok":true, "data":parser.data}

func apply_rule() -> bool:
	var parsed: Dictionary = _parse_object(hierarchy_editor, "Grammar rule")
	if not parsed.ok or hierarchy_rule.item_count == 0: return false
	var candidate: Dictionary = app.active_recipe.duplicate(true)
	var id: String = hierarchy_rule.get_item_text(hierarchy_rule.selected)
	for index: int in range(candidate.grammar.rules.size()):
		if str(candidate.grammar.rules[index].id) == id:
			candidate.grammar.rules[index] = parsed.data
			return app.apply_recipe(candidate)
	return false

func apply_plane_json() -> bool:
	var parsed: Dictionary = _parse_object(layer_editor, "Semantic plane data")
	if not parsed.ok: return false
	var candidate: Dictionary = app.active_recipe.duplicate(true)
	candidate["semantic_planes"] = parsed.data
	return app.apply_recipe(candidate)

func _refresh_metrics() -> void:
	if quality_label == null: return
	var kinds: Dictionary = {}
	for feature: Dictionary in plan.get("features", []): kinds[str(feature.kind)] = int(kinds.get(str(feature.kind), 0)) + 1
	for child: Node in histogram.get_children(): child.queue_free()
	for kind: String in kinds:
		var row := HBoxContainer.new()
		histogram.add_child(row)
		app._label(row, "%s: %d" % [kind, int(kinds[kind])], 13).custom_minimum_size.x = 145
		var bar := ProgressBar.new()
		bar.max_value = maxi(plan.get("features", []).size(), 1)
		bar.value = int(kinds[kind])
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
	quality_label.text = "Accepted native features: %d\nGrammar preparation: %s logical units; charged prepared bytes: %s\nPlane preparation: %s logical units; charged prepared bytes: %s\nDeclared plane charge: %s operations/cell\nHeatmaps show per-chunk measured generation time or charged work. Neither is per-cell timing or target-hardware performance." % [plan.get("features", []).size(), str(plan.get("preparation_work", "unavailable")), str(plan.get("storage_bytes", "unavailable")), str(plane_plan.get("preparation_work", "unavailable")), str(plane_plan.get("storage_bytes", "unavailable")), str(plane_plan.get("operations_per_cell", "unavailable"))]

func open_graph() -> void:
	if graph_window == null:
		graph_window = Window.new()
		graph_window.title = "Generation Workbench / typed graph"
		graph_window.size = Vector2i(1180, 760)
		graph_window.min_size = Vector2i(800, 540)
		graph_window.close_requested.connect(graph_window.hide)
		app.add_child(graph_window)
		var layout := VBoxContainer.new()
		layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		graph_window.add_child(layout)
		var toolbar := HBoxContainer.new()
		layout.add_child(toolbar)
		graph_section = _options(toolbar, ["Typed spatial", "Scalar fields"])
		graph_section.item_selected.connect(func(_index: int) -> void: _refresh_graph())
		graph_namespace = _options(toolbar, ["Root"])
		graph_namespace.item_selected.connect(func(_index: int) -> void: _refresh_graph(false))
		_button(toolbar, "Validate node", apply_graph_node)
		_button(toolbar, "Delete node", delete_graph_node)
		_button(toolbar, "Undo", app.undo_authoring)
		_button(toolbar, "Redo", app.redo_authoring)
		var creation := HBoxContainer.new()
		layout.add_child(creation)
		app._label(creation, "New operator", 13)
		graph_new_kind = _options(creation, [])
		graph_new_id = LineEdit.new()
		graph_new_id.text = "new-node"
		graph_new_id.placeholder_text = "Unique local ID"
		graph_new_id.custom_minimum_size.x = 160
		creation.add_child(graph_new_id)
		_button(creation, "New node draft", new_graph_node)
		var instances := HBoxContainer.new()
		layout.add_child(instances)
		app._label(instances, "Reusable namespace", 13)
		graph_new_subgraph = _options(instances, [])
		_button(instances, "New instance draft", new_graph_instance)
		var split := HSplitContainer.new()
		split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		layout.add_child(split)
		graph = GraphEdit.new()
		graph.custom_minimum_size = Vector2(760, 500)
		graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		graph.right_disconnects = true
		for from_type: int in range(8):
			for to_type: int in range(8): graph.add_valid_connection_type(from_type, to_type)
		graph.connection_request.connect(connect_graph_ports)
		graph.disconnection_request.connect(disconnect_graph_ports)
		graph.node_selected.connect(_graph_selected)
		split.add_child(graph)
		var editor := VBoxContainer.new()
		editor.custom_minimum_size.x = 330
		split.add_child(editor)
		node_label = _label(editor, "Select a node. Ports show accepted native type and units; all supported node parameters remain editable.")
		node_parameter_box = VBoxContainer.new()
		editor.add_child(node_parameter_box)
		node_editor = TextEdit.new()
		node_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
		node_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		editor.add_child(node_editor)
		_label(editor, "Root may reference expanded namespace outputs. Select a named subgraph to edit its local operators. Instances/bindings/outputs remain editable in Spatial JSON and are preserved by form edits.")
	_refresh_graph()
	graph_window.popup_centered()

func _graph_definition(recipe: Dictionary) -> Dictionary:
	if graph_section != null and graph_section.selected == 1: return {"nodes":recipe.get("fields", [])}
	var spatial: Dictionary = recipe.get("spatial", {})
	var selected: int = graph_namespace.selected if graph_namespace != null else 0
	if selected > 0 and selected <= spatial.get("subgraphs", []).size(): return spatial.subgraphs[selected - 1]
	return spatial

func _store_graph_definition(recipe: Dictionary, definition: Dictionary) -> void:
	if graph_section.selected == 1:
		recipe.fields = definition.get("nodes", [])
		return
	recipe.schema = maxi(2, int(recipe.get("schema", 1)))
	if not recipe.has("spatial"): recipe.spatial = {"nodes":[]}
	if graph_namespace.selected > 0: recipe.spatial.subgraphs[graph_namespace.selected - 1] = definition
	else: recipe.spatial = definition

func _graph_namespace_prefixes() -> Array[String]:
	var prefixes: Array[String] = []
	if graph_section.selected != 0: return prefixes
	if graph_namespace.selected == 0: return [""]
	var selected: String = graph_namespace.get_item_text(graph_namespace.selected)
	var spatial: Dictionary = app.active_recipe.get("spatial", {})
	var definitions: Dictionary = {}
	for definition: Dictionary in spatial.get("subgraphs", []): definitions[str(definition.id)] = definition
	var pending: Array[Dictionary] = [{"definition":spatial, "prefix":""}]
	var visited: int = 0
	# Match this exact reusable definition, never a coincidental local ID in a
	# different namespace. Uninstantiated/bounded-out definitions stay unresolved.
	while not pending.is_empty() and visited < MAX_GRAPH_NODES:
		var entry: Dictionary = pending.pop_front()
		visited += 1
		for instance: Dictionary in entry.definition.get("instances", []):
			var name: String = str(instance.get("subgraph", ""))
			var prefix: String = str(entry.prefix) + str(instance.id) + "."
			if name == selected: prefixes.append(prefix)
			if definitions.has(name) and pending.size() < MAX_GRAPH_NODES:
				pending.append({"definition":definitions[name], "prefix":prefix})
	return prefixes

func _compiled_graph_info(local_id: String, prefixes: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for prefix: String in prefixes:
		var candidate: Dictionary = app.spatial_nodes.get(prefix + local_id, {})
		if candidate.is_empty(): continue
		if not result.is_empty() and (candidate.get("type") != result.get("type") or candidate.get("unit_power") != result.get("unit_power")):
			return {} # Binding-dependent type must be checked for each instance.
		result = candidate
	return result

func _refresh_graph(refresh_namespaces: bool = true) -> void:
	if graph == null: return
	for node: Node in graph.get_children():
		if node is GraphNode:
			graph_positions[str(node.get_meta("position_key", node.name))] = node.position_offset
			graph.remove_child(node)
			node.queue_free()
	while graph_positions.size() > MAX_GRAPH_NODES * 4: graph_positions.erase(graph_positions.keys()[0])
	graph.clear_connections()
	graph_node_ids.clear()
	graph_output_ids.clear()
	if refresh_namespaces:
		var prior: String = graph_namespace.get_item_text(graph_namespace.selected) if graph_namespace.item_count > 0 else "Root"
		graph_namespace.clear()
		graph_namespace.add_item("Root")
		if graph_section.selected == 0:
			for subgraph: Dictionary in app.active_recipe.get("spatial", {}).get("subgraphs", []): graph_namespace.add_item(str(subgraph.id))
		app._select_text(graph_namespace, prior)
	graph_new_subgraph.clear()
	for subgraph: Dictionary in app.active_recipe.get("spatial", {}).get("subgraphs", []): graph_new_subgraph.add_item(str(subgraph.id))
	graph_new_subgraph.disabled = graph_section.selected != 0
	var kinds: Dictionary = app.spatial_specs if graph_section.selected == 0 else app.field_specs
	var prior_kind: String = graph_new_kind.get_item_text(graph_new_kind.selected) if graph_new_kind.item_count > 0 else "constant"
	graph_new_kind.clear()
	for kind: String in kinds: graph_new_kind.add_item(kind)
	app._select_text(graph_new_kind, prior_kind)
	var definition: Dictionary = _graph_definition(app.active_recipe)
	var nodes: Array = definition.get("nodes", [])
	var prefixes: Array[String] = _graph_namespace_prefixes()
	var reverse: Dictionary = {}
	for index: int in range(mini(nodes.size(), MAX_GRAPH_NODES)):
		var item: Dictionary = nodes[index]
		var node := GraphNode.new()
		node.name = "operator_%d" % index
		node.set_meta("id", str(item.id))
		var position_key: String = "%d:%s:%s" % [graph_section.selected, graph_namespace.get_item_text(graph_namespace.selected), str(item.id)]
		node.set_meta("position_key", position_key)
		node.title = str(item.id)
		node.tooltip_text = "%s / %s" % [str(item.id), str(item.kind)]
		node.position_offset = graph_positions.get(position_key, Vector2(30 + (index % 2) * 310, 70 + (index / 2) * 175))
		node.custom_minimum_size = Vector2(270, 100)
		graph.add_child(node)
		graph_node_ids[str(node.name)] = str(item.id)
		reverse[str(item.id)] = {"node":str(node.name), "port":0}
		graph_output_ids[str(node.name)] = [str(item.id)]
		var info: Dictionary = _compiled_graph_info(str(item.id), prefixes)
		var kind: String = str(info.get("type", "normalized" if graph_section.selected == 1 else "inferred on validation"))
		var port_type: int = _port_type(kind)
		var colour: Color = _port_colour(port_type)
		var input_count: int = item.get("inputs", []).size()
		var spec: Dictionary = app.spatial_specs.get(str(item.kind), {}) if graph_section.selected == 0 else app.field_specs.get(str(item.kind), {})
		input_count = maxi(input_count, int(spec.get("input_count", input_count)))
		for slot: int in range(maxi(1, input_count)):
			var label := Label.new()
			var input_text: String = str(item.get("inputs", [])[slot]) if slot < item.get("inputs", []).size() else ("input %d" % (slot + 1) if slot < input_count else "output")
			label.text = "%s → %s" % [input_text, "%s · cells^%s" % [kind, str(info.get("unit_power", "?"))] if slot == 0 else ""]
			label.tooltip_text = "%s: linked input type is checked by native validation; output %s cells^%s" % [input_text, kind, str(info.get("unit_power", "?"))]
			label.clip_text = true
			label.add_theme_font_size_override("font_size", 12)
			node.add_child(label)
			node.set_slot(slot, slot < input_count, 0, Color(0.6, 0.75, 0.82), slot == 0, port_type, colour)
		var note := Label.new()
		note.clip_text = true
		note.text = "%s · sample %s · %s" % [str(item.kind), str(item.get("sampling_scale", 1)), "declared %s ops" % str(info.operations) if info.has("operations") else "native validation"]
		note.add_theme_font_size_override("font_size", 11)
		node.add_child(note)
	# Reusable instances expose their actual named outputs as typed graph ports.
	# The declaration/bindings remain intact and editable in the node inspector.
	var instances: Array = definition.get("instances", [])
	for instance_index: int in range(mini(instances.size(), 16)):
		var instance: Dictionary = instances[instance_index]
		var prototype: Dictionary = {}
		for subgraph: Dictionary in app.active_recipe.get("spatial", {}).get("subgraphs", []):
			if str(subgraph.id) == str(instance.get("subgraph", "")): prototype = subgraph
		var node := GraphNode.new()
		node.name = "instance_%d" % instance_index
		node.title = str(instance.id) + " / " + str(instance.get("subgraph", ""))
		node.set_meta("id", "instance:" + str(instance.id))
		node.set_meta("instance", true)
		var position_key: String = "%d:%s:instance:%s" % [graph_section.selected, graph_namespace.get_item_text(graph_namespace.selected), str(instance.id)]
		node.set_meta("position_key", position_key)
		var layout_index: int = nodes.size() + instance_index
		node.position_offset = graph_positions.get(position_key, Vector2(30 + (layout_index % 2) * 310, 70 + (layout_index / 2) * 175))
		node.custom_minimum_size = Vector2(270, 110)
		graph.add_child(node)
		graph_node_ids[str(node.name)] = "instance:" + str(instance.id)
		var outputs: Array = prototype.get("outputs", {}).keys()
		var output_ids: Array[String] = []
		for output_index: int in range(outputs.size()):
			var output_id: String = str(instance.id) + "." + str(outputs[output_index])
			var info: Dictionary = _compiled_graph_info(output_id, prefixes)
			var label := Label.new()
			label.text = "%s → %s cells^%s" % [str(outputs[output_index]), str(info.get("type", "native inferred")), str(info.get("unit_power", "?"))]
			label.clip_text = true
			label.tooltip_text = output_id
			label.add_theme_font_size_override("font_size", 12)
			node.add_child(label)
			var type: int = _port_type(str(info.get("type", "scalar")))
			node.set_slot(output_index, false, 0, Color.WHITE, true, type, _port_colour(type))
			reverse[output_id] = {"node":str(node.name), "port":output_index}
			output_ids.append(output_id)
		graph_output_ids[str(node.name)] = output_ids
		var note := Label.new()
		note.text = "%d literal bindings · %d inherited bindings" % [instance.get("bindings", {}).size(), instance.get("parameter_bindings", {}).size()]
		note.clip_text = true
		note.add_theme_font_size_override("font_size", 11)
		node.add_child(note)
	for item: Dictionary in nodes:
		if not reverse.has(str(item.id)): continue
		var inputs: Array = item.get("inputs", [])
		for index: int in range(inputs.size()):
			if reverse.has(str(inputs[index])): graph.connect_node(reverse[str(inputs[index])].node, int(reverse[str(inputs[index])].port), reverse[str(item.id)].node, index)
	if nodes.size() > MAX_GRAPH_NODES: node_label.text = "Canvas truncated at 256 nodes; complete supported graph remains in Spatial JSON."

func new_graph_node() -> void:
	if graph_new_kind.item_count == 0: return
	var kind: String = graph_new_kind.get_item_text(graph_new_kind.selected)
	var spec: Dictionary = (app.spatial_specs if graph_section.selected == 0 else app.field_specs).get(kind, {})
	var item: Dictionary = {"id":graph_new_id.text.strip_edges(), "kind":kind}
	var parameters: Dictionary = {}
	for parameter: Dictionary in spec.get("parameters", []): parameters[str(parameter.name)] = parameter.default_value
	if not parameters.is_empty(): item.parameters = parameters
	var inputs: Array[String] = []
	for index: int in range(int(spec.get("input_count", 0))): inputs.append("select-existing-input-%d" % index)
	if not inputs.is_empty(): item.inputs = inputs
	if graph_section.selected == 0:
		item.sampling_scale = 1
		if kind == "constant": item.value = {"type":"scalar", "x":0.0}
		if kind in ["parameter", "geometry_distance", "assigned_region"]: item.reference = "select-declared-reference"
		if kind == "category_is": item.value = {"type":"category", "category":{"x":"0", "y":"0", "domain":"0000000000000000"}}
	node_selected = ""
	node_editor.text = JSON.stringify(item, "  ", true, true)
	_render_node_parameters(item)
	node_label.text = "NEW NODE DRAFT. Choose valid input IDs and parameters, then Validate node. This draft is not in the accepted graph."

func new_graph_instance() -> void:
	if graph_section.selected != 0 or graph_new_subgraph.item_count == 0:
		app._set_error("Declare a reusable subgraph in Spatial JSON before instantiating it.")
		return
	node_selected = "instance:"
	node_editor.text = JSON.stringify({"id":graph_new_id.text.strip_edges(), "subgraph":graph_new_subgraph.get_item_text(graph_new_subgraph.selected), "bindings":{}}, "  ", true, true)
	for child: Node in node_parameter_box.get_children(): child.queue_free()
	node_label.text = "NEW INSTANCE DRAFT. Supply required typed bindings or use declared defaults, then Validate node."

func _port_type(kind: String) -> int:
	return maxi(["scalar", "normalized", "boolean", "vector2", "category", "distance", "signed_distance"].find(kind), 0)

func _port_colour(type: int) -> Color:
	return [Color(0.6, 0.8, 1), Color(0.35, 0.95, 0.65), Color(1, 0.85, 0.35), Color(0.85, 0.55, 1), Color(1, 0.5, 0.6), Color(0.4, 0.9, 0.9), Color(1, 0.65, 0.3)][clampi(type, 0, 6)]

func _graph_selected(node: Node) -> void:
	if not node is GraphNode: return
	node_selected = str(node.get_meta("id", ""))
	var is_instance: bool = node_selected.begins_with("instance:")
	var id: String = node_selected.trim_prefix("instance:") if is_instance else node_selected
	for item: Dictionary in _graph_definition(app.active_recipe).get("instances" if is_instance else "nodes", []):
		if str(item.id) == id:
			node_editor.text = JSON.stringify(item, "  ", true, true)
			_render_node_parameters(item)
			node_label.text = "Edit %s in %s. Supported parameters, references, type/unit declarations and bindings are preserved." % [node_selected, graph_namespace.get_item_text(graph_namespace.selected)]

func _render_node_parameters(item: Dictionary) -> void:
	for child: Node in node_parameter_box.get_children(): child.queue_free()
	var spec: Dictionary = (app.spatial_specs if graph_section.selected == 0 else app.field_specs).get(str(item.get("kind", "")), {})
	for parameter: Dictionary in spec.get("parameters", []):
		var key: String = str(parameter.name)
		var value: float = float(item.get("parameters", {}).get(key, parameter.default_value))
		# Godot Range quantizes relative to min_value. Native +/-1e150 bounds
		# would erase ordinary edits through cancellation, so use a finite UI
		# stepping window with explicit overflow entry; native validates bounds.
		var low: float = maxf(-1000000.0, float(parameter.minimum))
		var high: float = minf(1000000.0, float(parameter.maximum))
		if low > high:
			low = -1000000.0
			high = 1000000.0
		var input: SpinBox = app._labelled_spin(node_parameter_box, key, low, high, 1.0 if bool(parameter.get("integer", false)) else 0.01, clampf(value, low, high))
		input.allow_greater = true
		input.allow_lesser = true
		input.value = value
		input.tooltip_text = "Native accepted range [%s, %s]; validation occurs before commit. JSON preserves full double precision." % [str(parameter.minimum), str(parameter.maximum)]
		input.value_changed.connect(func(next: float) -> void:
			var draft: Variant = JSON.parse_string(node_editor.text)
			if not draft is Dictionary:
				app._set_error("Fix node JSON before changing a parameter control.")
				return
			var parameters: Dictionary = draft.get("parameters", {}).duplicate(true)
			parameters[key] = next
			draft.parameters = parameters
			node_editor.text = JSON.stringify(draft, "  ", true, true))

func apply_graph_node() -> bool:
	var parsed: Dictionary = _parse_object(node_editor, "Graph node")
	if not parsed.ok: return false
	var recipe: Dictionary = app.active_recipe.duplicate(true)
	var definition: Dictionary = _graph_definition(recipe).duplicate(true)
	var section: String = "instances" if node_selected.begins_with("instance:") else "nodes"
	var id: String = node_selected.trim_prefix("instance:") if section == "instances" else node_selected
	var nodes: Array = definition.get(section, [])
	var found: bool = false
	for index: int in range(nodes.size()):
		if str(nodes[index].id) == id:
			nodes[index] = parsed.data
			found = true
	if not found: nodes.append(parsed.data)
	definition[section] = nodes
	_store_graph_definition(recipe, definition)
	return app.apply_recipe(recipe)

func delete_graph_node() -> bool:
	if node_selected.is_empty(): return false
	var recipe: Dictionary = app.active_recipe.duplicate(true)
	var definition: Dictionary = _graph_definition(recipe).duplicate(true)
	var section: String = "instances" if node_selected.begins_with("instance:") else "nodes"
	var id: String = node_selected.trim_prefix("instance:") if section == "instances" else node_selected
	var nodes: Array = definition.get(section, [])
	for index: int in range(nodes.size() - 1, -1, -1):
		if str(nodes[index].id) == id: nodes.remove_at(index)
	definition[section] = nodes
	_store_graph_definition(recipe, definition)
	return app.apply_recipe(recipe)

func connect_graph_ports(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	app._interactive_edit = true
	_edit_graph_edge(str(from_node), str(to_node), to_port, false, from_port)
	app._interactive_edit = false

func disconnect_graph_ports(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	app._interactive_edit = true
	_edit_graph_edge(str(from_node), str(to_node), to_port, true, from_port)
	app._interactive_edit = false

func _edit_graph_edge(from_node: String, to_node: String, port: int, remove: bool, source_port: int = 0) -> bool:
	if not graph_node_ids.has(from_node) or not graph_node_ids.has(to_node): return false
	var recipe: Dictionary = app.active_recipe.duplicate(true)
	var definition: Dictionary = _graph_definition(recipe).duplicate(true)
	for node: Dictionary in definition.get("nodes", []):
		if str(node.id) != str(graph_node_ids[to_node]): continue
		var inputs: Array = node.get("inputs", []).duplicate()
		if port < 0 or port >= 8:
			app._set_error("Graph input port exceeds the bounded editor port set.")
			return false
		while inputs.size() <= port: inputs.append("")
		if remove: inputs[port] = ""
		else:
			var outputs: Array = graph_output_ids.get(from_node, [])
			if source_port < 0 or source_port >= outputs.size(): return false
			inputs[port] = str(outputs[source_port])
		node.inputs = inputs
		_store_graph_definition(recipe, definition)
		return app.apply_recipe(recipe)
	return false

func bounded_view() -> Rect2i:
	var size := Vector2i(mini(MAX_COMPARE_AXIS, maxi(1, floori(app.view_size.x))), mini(MAX_COMPARE_AXIS, maxi(1, floori(app.view_size.y))))
	var bounds := Rect2i(Vector2i(floori(app.camera_origin.x), floori(app.camera_origin.y)), size)
	if not plane_plan.is_empty(): bounds = bounds.intersection(plane_plan.bounds)
	return bounds

func pin_before() -> bool:
	if app.active_revision < 0: return false
	has_pin = true
	pinned_recipe = app.active_recipe.duplicate(true)
	pinned_bounds = bounded_view()
	aux_status.text = "Pinned accepted recipe at %s, seed %s. Later comparisons keep these coordinates and use the current seed for both recipes." % [str(pinned_bounds), str(pinned_recipe.get("seed", 1))]
	return true

func cancel_auxiliary() -> void:
	aux_serial += 1
	aux_jobs.clear()
	if aux_thread == null: aux_active.clear()
	aux_results.clear()
	last_comparison.clear()
	if seed_cards != null:
		for card: Node in seed_cards.get_children(): card.queue_free()
	if aux_status != null: aux_status.text = "Auxiliary jobs retired. No partial result was published."

func start_comparison() -> bool:
	if not has_pin or pinned_bounds.size.x <= 0 or pinned_bounds.size.y <= 0:
		app._set_error("Pin an accepted recipe and nonempty viewport before comparing.")
		return false
	cancel_auxiliary()
	aux_kind = "comparison"
	var seed: int = int(app.active_recipe.get("seed", 1))
	var before: Dictionary = pinned_recipe.duplicate(true)
	before.seed = seed
	var after: Dictionary = app.active_recipe.duplicate(true)
	after.seed = seed
	for item: Dictionary in [{"label":"Before", "recipe":before}, {"label":"After", "recipe":after}]:
		item["token"] = capture_token()
		item["serial"] = aux_serial
		item["bounds"] = pinned_bounds
		aux_jobs.append(item)
	aux_status.text = "Comparing actual native proposals at seed %d and %s…" % [seed, str(pinned_bounds)]
	return true

func start_seed_browser() -> bool:
	var seeds: Array[int] = []
	for piece: String in seed_input.text.split(",", false):
		var value: String = piece.strip_edges()
		if not value.is_valid_int() or value.to_int() < 0 or value.to_int() > 9007199254740991:
			app._set_error("Seed cards require portable nonnegative integer seeds through 2^53−1.")
			return false
		if not value.to_int() in seeds: seeds.append(value.to_int())
	if seeds.is_empty() or seeds.size() > MAX_AUX_JOBS:
		app._set_error("Declare between one and four distinct seed variations.")
		return false
	var bounds: Rect2i = bounded_view()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		app._set_error("Seed comparison requires a nonempty region inside the semantic plan.")
		return false
	cancel_auxiliary()
	aux_kind = "seeds"
	for seed: int in seeds:
		var recipe: Dictionary = app.active_recipe.duplicate(true)
		recipe.seed = seed
		aux_jobs.append({"label":"Seed %d" % seed, "recipe":recipe, "bounds":bounds, "token":capture_token(), "serial":aux_serial})
	aux_status.text = "Queued %d deterministic variations; bounded to one active native owner." % seeds.size()
	return true

func service_auxiliary() -> void:
	if aux_thread != null:
		if aux_thread.is_alive(): return
		var checked: Dictionary = aux_thread.wait_to_finish()
		aux_thread = null
		if not _aux_current(aux_active):
			aux_active.clear()
		elif not checked.get("ok", false):
			_aux_fail(str(checked.get("error", "Auxiliary recipe rejected.")))
			return
		else:
			aux_active.prepare_usec = int(checked.get("prepare_usec", 0))
			if not _initialize_aux(): return
	if aux_active.is_empty():
		if aux_jobs.is_empty(): return
		aux_active = aux_jobs.pop_front()
		if not _aux_current(aux_active):
			cancel_auxiliary()
			return
		var owner: Variant = ClassDB.instantiate(&"CyberWorldGenerator")
		aux_active.owner = owner
		var size: int = maxi(int(aux_active.recipe.get("chunk_size", 128)), 1)
		var coordinate := Vector2i(floori(float(aux_active.bounds.position.x) / size), floori(float(aux_active.bounds.position.y) / size))
		aux_thread = Thread.new()
		var error: Error = aux_thread.start(app._prepare_candidate.bind(owner, aux_active.recipe, coordinate))
		if error != OK:
			aux_thread = null
			_aux_fail("Auxiliary private validator could not start: " + error_string(error))
		return
	if not _aux_current(aux_active):
		cancel_auxiliary()
		return
	var owner: Variant = aux_active.owner
	if not aux_active.plane_mode and not aux_active.chunk_active:
		if aux_active.chunks.is_empty():
			_finish_aux()
			return
		aux_active.coordinate = aux_active.chunks.pop_front()
		var began: Dictionary = owner.begin_chunk(aux_active.coordinate)
		if not began.get("ok", false):
			_aux_fail(str(began.get("error", "Auxiliary chunk request rejected.")))
			return
		aux_active.chunk_active = true
	var start: int = Time.get_ticks_usec()
	var packet: Dictionary = owner.advance_plane_region(AUX_CELL_BUDGET) if aux_active.plane_mode else owner.advance(AUX_CELL_BUDGET)
	aux_active.compute_usec += Time.get_ticks_usec() - start
	if not packet.get("ok", false):
		_aux_fail(str(packet.get("error", "Auxiliary generation failed.")))
		return
	if str(packet.get("state", "")) != "ready": return
	aux_active.operations += int(packet.get("operations", 0))
	if aux_active.plane_mode:
		aux_active.materials = packet.materials.duplicate(true)
		_finish_aux()
	else:
		_copy_aux_chunk(packet)
		aux_active.chunk_active = false

func _initialize_aux() -> bool:
	var owner: Variant = aux_active.owner
	aux_active.started_usec = Time.get_ticks_usec()
	aux_active.compute_usec = 0
	aux_active.operations = 0
	var semantic: Dictionary = owner.get_semantic_plan() if aux_active.recipe.has("grammar") else {}
	var planes: Dictionary = owner.get_plane_plan() if aux_active.recipe.has("semantic_planes") else {}
	var records: Array[Dictionary] = []
	var record_count: int = 0
	for family: String in ["features", "sockets", "routes", "projections", "fixtures", "links", "actors"]:
		var source: Dictionary = semantic if family in ["features", "sockets", "routes"] else planes
		for record: Dictionary in source.get(family, []):
			record_count += 1
			if records.size() < MAX_COMPARE_RECORDS: records.append({"family":family, "record":record.duplicate(true)})
	aux_active.records = records
	aux_active.records_total = record_count
	aux_active.records_truncated = record_count > records.size()
	aux_active.plane_mode = aux_active.recipe.has("semantic_planes")
	aux_active.materials = {}
	if aux_active.plane_mode:
		var began: Dictionary = owner.begin_plane_region(aux_active.bounds)
		if not began.get("ok", false):
			_aux_fail(str(began.get("error", "Auxiliary plane region rejected.")))
			return false
	else:
		var pixels := PackedByteArray()
		pixels.resize(aux_active.bounds.size.x * aux_active.bounds.size.y)
		aux_active.materials.play = pixels
		aux_active.chunks = _bounds_chunks(aux_active.bounds, int(aux_active.recipe.get("chunk_size", 128)))
		aux_active.chunk_active = false
	return true

func shutdown() -> void:
	cancel_auxiliary()
	if aux_thread != null:
		aux_thread.wait_to_finish()
		aux_thread = null
	aux_active.clear()
	app = null

func _aux_current(job: Dictionary) -> bool:
	return int(job.get("serial", -1)) == aux_serial and accepts_token(job.get("token", {}), false)

func _bounds_chunks(bounds: Rect2i, size: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var first := Vector2i(floori(float(bounds.position.x) / size), floori(float(bounds.position.y) / size))
	var last := Vector2i(floori(float(bounds.end.x - 1) / size), floori(float(bounds.end.y - 1) / size))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1): result.append(Vector2i(x, y))
	return result

func _copy_aux_chunk(packet: Dictionary) -> void:
	var bounds: Rect2i = aux_active.bounds
	var size: int = int(packet.chunk_size)
	var origin := Vector2i(int(packet.chunk_x) * size, int(packet.chunk_y) * size)
	var overlap: Rect2i = bounds.intersection(Rect2i(origin, Vector2i.ONE * size))
	var pixels: PackedByteArray = aux_active.materials.play
	for y: int in range(overlap.position.y, overlap.end.y):
		for x: int in range(overlap.position.x, overlap.end.x):
			pixels[(y - bounds.position.y) * bounds.size.x + x - bounds.position.x] = packet.cells[(y - origin.y) * size + x - origin.x]
	aux_active.materials.play = pixels

func _finish_aux() -> void:
	if not _aux_current(aux_active):
		cancel_auxiliary()
		return
	var result: Dictionary = aux_active.duplicate(true)
	result.seed = int(result.recipe.get("seed", 1))
	result.erase("owner")
	result.erase("chunks")
	result.erase("recipe")
	result.elapsed_usec = Time.get_ticks_usec() - int(aux_active.started_usec)
	aux_results.append(result)
	aux_active.clear()
	if aux_results.size() > MAX_AUX_JOBS:
		_aux_fail("Auxiliary result capacity exceeded.")
		return
	if aux_kind == "comparison" and aux_jobs.is_empty():
		finish_comparison(aux_results, capture_token())
	elif aux_kind == "seeds":
		_show_card(result)
		aux_status.text = "%d seed cards complete; %d queued. Measured local native work, no simulation." % [aux_results.size(), aux_jobs.size()]

func _aux_fail(message: String) -> void:
	cancel_auxiliary()
	aux_status.text = "No result published: " + message
	app._set_error(message)

func finish_comparison(results: Array, token: Dictionary) -> bool:
	if not accepts_token(token, false) or results.size() != 2: return false
	for result: Dictionary in results:
		if not _aux_current(result): return false
	var before: Dictionary = results[0]
	var after: Dictionary = results[1]
	if before.bounds != after.bounds: return false
	var changes: Dictionary = {}
	var masks: Dictionary = {}
	for plane: String in PLANES:
		if not before.materials.has(plane) and not after.materials.has(plane): continue
		var a: PackedByteArray = before.materials.get(plane, PackedByteArray())
		var b: PackedByteArray = after.materials.get(plane, PackedByteArray())
		if a.size() != b.size():
			changes[plane] = {"unavailable":"plane introduced/removed; no aligned baseline"}
			continue
		var count: int = 0
		var rgba := PackedByteArray()
		rgba.resize(a.size() * 4)
		for index: int in range(a.size()):
			var different: bool = a[index] != b[index]
			if different: count += 1
			rgba[index * 4] = 255 if different else 20
			rgba[index * 4 + 1] = 80 if different else 30
			rgba[index * 4 + 2] = 170 if different else 40
			rgba[index * 4 + 3] = 255
		changes[plane] = {"changed_cells":count, "total_cells":a.size()}
		masks[plane] = ImageTexture.create_from_image(Image.create_from_data(before.bounds.size.x, before.bounds.size.y, false, Image.FORMAT_RGBA8, rgba))
	var old_features: Dictionary = _semantic_signatures(before.records)
	var new_features: Dictionary = _semantic_signatures(after.records)
	var changed_features: Array[String] = []
	var added: int = 0
	var removed: int = 0
	var changed: int = 0
	for id: String in old_features:
		if not new_features.has(id):
			removed += 1
			if changed_features.size() < MAX_SEMANTIC_CHANGES: changed_features.append("removed " + id)
		elif old_features[id] != new_features[id]:
			changed += 1
			if changed_features.size() < MAX_SEMANTIC_CHANGES: changed_features.append("changed " + id)
	for id: String in new_features:
		if not old_features.has(id):
			added += 1
			if changed_features.size() < MAX_SEMANTIC_CHANGES: changed_features.append("added " + id)
	last_comparison = {"token":token.duplicate(true), "bounds":before.bounds, "materials":changes, "semantic_added":added, "semantic_removed":removed, "semantic_changed":changed, "semantic_details":changed_features, "semantic_truncated":added + removed + changed > changed_features.size() or before.get("records_truncated", false) or after.get("records_truncated", false), "before_records_total":before.get("records_total", 0), "after_records_total":after.get("records_total", 0), "masks":masks}
	_show_card(before)
	_show_card(after)
	_label(seed_cards, "EXACT MATERIAL DIFFERENCES")
	var difference_grid := GridContainer.new()
	difference_grid.columns = 2
	difference_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_cards.add_child(difference_grid)
	for plane: String in masks:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		difference_grid.add_child(box)
		_label(box, "%s: %d / %d changed" % [plane, int(changes[plane].changed_cells), int(changes[plane].total_cells)])
		var rect := TextureRect.new()
		rect.texture = masks[plane]
		rect.custom_minimum_size = Vector2(128, 128)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(rect)
	_label(seed_cards, "SEMANTIC RECORDS: +%d / −%d / %d changed%s" % [added, removed, changed, " (details truncated)" if last_comparison.semantic_truncated else ""])
	for detail: String in changed_features: _label(seed_cards, detail)
	aux_status.text = "Exact comparison complete: same seed %d at %s.\nSemantic records: +%d / −%d / %d changed%s.\nPink marks changed materials; dark cells are identical." % [int(after.get("seed", 1)), str(before.bounds), added, removed, changed, " (details truncated)" if last_comparison.semantic_truncated else ""]
	return true

func _semantic_signatures(records: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in records:
		var copy: Dictionary = entry.record.duplicate(true)
		copy.erase("revision")
		result[str(entry.family) + ":" + str(copy.id)] = JSON.stringify(copy, "", true, true)
	return result

func _show_card(result: Dictionary) -> void:
	_label(seed_cards, "%s · %.2f ms prepare / %.2f ms native calls · %s logical operations" % [result.label, float(result.get("prepare_usec", 0)) / 1000.0, float(result.compute_usec) / 1000.0, str(result.operations)])
	var row := HBoxContainer.new()
	seed_cards.add_child(row)
	for plane: String in PLANES:
		if not result.materials.has(plane): continue
		var pixels: PackedByteArray = material_pixels(result.materials[plane])
		var box := VBoxContainer.new()
		row.add_child(box)
		app._label(box, plane, 10)
		var image: Image = Image.create_from_data(result.bounds.size.x, result.bounds.size.y, false, Image.FORMAT_RGBA8, pixels)
		var texture := TextureRect.new()
		texture.texture = ImageTexture.create_from_image(image)
		texture.custom_minimum_size = Vector2(80, 90)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(texture)
