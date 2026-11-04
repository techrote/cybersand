extends SceneTree

# Execute this test-only script in an imported, isolated copy of the actual
# project. Both real controller scripts are instantiated without _ready(); no
# material_name override, generated-resource import or simulation tick is used.
# The external oracle comes from accepted legacy Git, not the candidate table.
# Every ordinary invocation requires exact equality: a poisoned label must fail.
const ORACLE_SCHEMA: String = "cybersand.material-catalogue.legacy-display-oracle"
const ORACLE_SOURCE: String = "7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1"
const PROBE_SCRIPTS: Array[String] = [
	"scripts/main.gd", "scripts/web_demo_controller.gd", "scripts/tower_panel.gd",
	"scripts/transport_profile_panel.gd", "scripts/microscenario_workbench.gd",
	"scripts/microscenario_identity.gd", "scripts/microscenario_comparison.gd",
	"scripts/experiment_tower.gd", "scripts/simulation_snapshot.gd",
	"scripts/cell_world.gd"]

var assertions: int = 0
var failures: Array = []
var checks: Dictionary = {}
var expected_names: Dictionary = {}
var oracle: Dictionary = {}
var options: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _expect(condition: bool, scope: String, description: String,
		actual: Variant = null, expected: Variant = null) -> void:
	assertions += 1
	checks[scope] = int(checks.get(scope, 0)) + 1
	if not condition:
		failures.append({"scope":scope, "assertion":description,
			"actual":actual, "expected":expected})


func _read_json(path: String) -> Variant:
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		_expect(false, "inputs", "valid JSON: " + path,
			parser.get_error_message(), "parse success")
		return null
	return parser.data


func _arguments() -> bool:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var allowed: Array[String] = ["--oracle", "--output", "--source-revision", "--other-probe"]
	if arguments.size() % 2 != 0:
		printerr("display probe: expected --oracle PATH --output PATH [--source-revision SHA] [--other-probe PATH]")
		return false
	for index: int in range(0, arguments.size(), 2):
		var key: String = arguments[index]
		if key not in allowed or options.has(key):
			printerr("display probe: unknown or repeated option " + key)
			return false
		options[key] = arguments[index + 1]
	if not options.has("--oracle") or not options.has("--output"):
		printerr("display probe: --oracle and --output are mandatory")
		return false
	var output: String = str(options["--output"]).simplify_path()
	var project: String = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if not output.is_absolute_path() or not output.ends_with(".json") \
			or output == project or output.begins_with(project + "/"):
		printerr("display probe: output must be an absolute .json path outside the tested project")
		return false
	# The Python custody driver additionally checks filesystem aliases. This
	# engine probe never replaces an existing file or any declared input.
	if FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output):
		printerr("display probe: refusing existing report destination " + output)
		return false
	for key: String in ["--oracle", "--other-probe"]:
		if options.has(key):
			var input_path: String = str(options[key]).simplify_path()
			if not input_path.is_absolute_path() or not FileAccess.file_exists(input_path) or input_path == output:
				printerr("display probe: missing/unsafe input " + key)
				return false
	options["--output"] = output
	return true


func _oracle_input() -> bool:
	var value: Variant = _read_json(str(options["--oracle"]))
	if not value is Dictionary:
		_expect(false, "inputs", "oracle object")
		return false
	oracle = value
	_expect(oracle.get("schema_id") == ORACLE_SCHEMA and int(oracle.get("schema_version", 0)) == 1,
		"inputs", "frozen oracle schema")
	_expect(oracle.get("source_commit") == ORACLE_SOURCE, "inputs", "accepted legacy source")
	var cases: Variant = oracle.get("cases")
	if not cases is Array or cases.size() != 277:
		_expect(false, "inputs", "all 256 byte IDs and 21 signed/large integer cases")
		return false
	for row: Variant in cases:
		if not row is Dictionary or not row.get("id") is String or not row.get("expected") is String:
			_expect(false, "inputs", "string-encoded integer and expected return")
			return false
		var text: String = row.id
		var ident: int = text.to_int()
		_expect(text.is_valid_int() and str(ident) == text, "inputs", "lossless signed64 ID " + text)
		_expect(not expected_names.has(text), "inputs", "unique oracle ID " + text)
		expected_names[text] = row.expected
	for ident: int in range(256):
		_expect(expected_names.has(str(ident)), "inputs", "byte-domain ID " + str(ident))
	_expect(oracle.get("paintable_ids") is Array and oracle.paintable_ids.size() == 130,
		"inputs", "frozen 130-item paintable order")
	_expect(oracle.get("group_first_ids") is Array and oracle.group_first_ids.size() == 8,
		"inputs", "frozen eight group boundaries")
	return failures.is_empty()


func _integer_array(value: Array) -> Array[int]:
	var result: Array[int] = []
	for item: Variant in value:
		result.append(int(item))
	return result


func _picker_rows(picker: OptionButton) -> Array:
	var result: Array = []
	for index: int in range(picker.item_count):
		result.append({"index":index, "id":picker.get_item_id(index), "text":picker.get_item_text(index)})
	return result


func _picker_check(picker: OptionButton, ids: Array[int], separator: String, scope: String) -> Array:
	var rows: Array = _picker_rows(picker)
	_expect(rows.size() == ids.size(), scope, "picker item count", rows.size(), ids.size())
	for index: int in range(mini(rows.size(), ids.size())):
		var ident: int = ids[index]
		var expected: String = str(ident) + separator + str(expected_names[str(ident)])
		_expect(rows[index].id == ident, scope, "item ID/order at " + str(index), rows[index].id, ident)
		_expect(rows[index].text == expected, scope, "item text at " + str(index), rows[index].text, expected)
	return rows


func _selection(host: Variant, scope: String) -> Dictionary:
	var paintable: Array[int] = _integer_array(oracle.paintable_ids)
	var groups: Array[int] = _integer_array(oracle.group_first_ids)
	_expect(host.PAINTABLE_MATERIAL_IDS == paintable, scope, "paintable IDs and order",
		host.PAINTABLE_MATERIAL_IDS, paintable)
	_expect(host.MATERIAL_GROUP_FIRST_IDS == groups, scope, "presentation group boundaries",
		host.MATERIAL_GROUP_FIRST_IDS, groups)
	var transitions: Array = []
	for index: int in range(paintable.size()):
		var ident: int = paintable[index]
		host.selected_material_id = ident
		var secondary: int = host.effective_secondary_material_id()
		_expect(secondary == paintable[(index + 1) % paintable.size()], scope,
			"secondary after " + str(ident), secondary, paintable[(index + 1) % paintable.size()])
		for direction: int in [-1, 1]:
			host.selected_material_id = ident
			host.selected_paint_slot = 3
			host.cycle_material(direction)
			var expected: int = paintable[posmod(index + direction, paintable.size())]
			_expect(host.selected_material_id == expected and host.selected_paint_slot == 0,
				scope, "cycle " + str(ident) + " / " + str(direction), host.selected_material_id, expected)
			transitions.append({"id":str(ident), "direction":direction,
				"selected":host.selected_material_id, "secondary":secondary,
				"paint_slot":host.selected_paint_slot})
	var unknown: Array = []
	for text: String in ["0", "10", "-1", "132", "255", "-9223372036854775808", "9223372036854775807"]:
		var ident: int = text.to_int()
		host.selected_material_id = ident
		var secondary: int = host.effective_secondary_material_id()
		_expect(secondary == paintable[0], scope, "unknown secondary " + text, secondary, paintable[0])
		for direction: int in [-1, 0, 1]:
			host.selected_material_id = ident
			host.cycle_material(direction)
			_expect(host.selected_material_id == paintable[posmod(direction, paintable.size())],
				scope, "unknown cycle " + text + " / " + str(direction))
			unknown.append({"id":text, "direction":direction,
				"selected":host.selected_material_id, "secondary":secondary})
	var group_transitions: Array = []
	for row: Dictionary in oracle.cases:
		var ident: int = str(row.id).to_int()
		var group: int = 0
		for index: int in range(groups.size()):
			if ident >= groups[index]: group = index
		for direction: int in [-1, 1]:
			host.selected_material_id = ident
			host.selected_paint_slot = 3
			host.cycle_material_group(direction)
			var expected: int = groups[posmod(group + direction, groups.size())]
			_expect(host.selected_material_id == expected and host.selected_paint_slot == 0,
				scope, "group cycle " + str(row.id) + " / " + str(direction), host.selected_material_id, expected)
			group_transitions.append({"id":row.id, "direction":direction,
				"selected":host.selected_material_id, "paint_slot":host.selected_paint_slot})
	return {"paintable_ids":host.PAINTABLE_MATERIAL_IDS.duplicate(),
		"group_first_ids":host.MATERIAL_GROUP_FIRST_IDS.duplicate(), "cycles":transitions,
		"unknown_cycles":unknown, "group_cycles":group_transitions}


func _tower(host: Variant, scope: String) -> Dictionary:
	var panel: CyberTowerPanel = CyberTowerPanel.new()
	host.add_child(panel)
	panel.setup(host)
	var floors: Array = []
	_expect(panel.floor_picker.item_count == 5, scope, "five Tower floor choices")
	for floor_index: int in range(5):
		panel.refresh(true, floor_index, {})
		var tubes: Array = CyberExperimentTower.tubes(floor_index)
		var rows: Array = _picker_rows(panel.tube_picker)
		_expect(panel.floor_picker.get_selected_id() == floor_index, scope, "selected floor " + str(floor_index))
		_expect(rows.size() == tubes.size() and panel.labels.size() == tubes.size(), scope,
			"tube and visible-label count on floor " + str(floor_index))
		var labels: Array = []
		for index: int in range(mini(rows.size(), tubes.size())):
			var ident: int = int(tubes[index][1])
			var name_text: String = str(expected_names[str(ident)])
			var expected: String = "%d / %s / %s" % [index + 1, name_text, str(tubes[index][3])]
			_expect(rows[index].id == index and rows[index].text == expected, scope,
				"tube item " + str(floor_index) + "/" + str(index), rows[index].text, expected)
			_expect(panel.labels[index].text == name_text, scope,
				"visible tube label " + str(floor_index) + "/" + str(index), panel.labels[index].text, name_text)
			panel.tube_picker.select(index)
			panel.refresh(true, floor_index, {})
			_expect(panel.tube_picker.selected == index, scope, "tube selection survives refresh")
			labels.append({"material_id":ident, "text":panel.labels[index].text,
				"selected_item_id":panel.tube_picker.get_selected_id()})
		floors.append({"floor":floor_index, "selected_floor_id":panel.floor_picker.get_selected_id(),
			"tubes":rows, "labels":labels})
	return {"floor_picker":_picker_rows(panel.floor_picker), "floors":floors}


func _transport(host: Variant, scope: String) -> Dictionary:
	var panel: CyberTransportProfilePanel = CyberTransportProfilePanel.new()
	host.add_child(panel)
	panel.setup(host)
	var ids: Array[int] = []
	for ident: int in range(81):
		if ident != 10: ids.append(ident)
	var source_rows: Array = _picker_check(panel.source, ids, " ", scope + "/source")
	var target_rows: Array = _picker_check(panel.target, ids, " ", scope + "/target")
	var defaults: Dictionary = {"source":panel.source.get_selected_id(), "target":panel.target.get_selected_id()}
	_expect(defaults == {"source":3, "target":2}, scope, "default selected Water/Sand", defaults)
	var selections: Array = []
	for index: int in range(ids.size()):
		var source_id: int = ids[index]
		var target_id: int = ids[ids.size() - 1 - index]
		panel.source.select(index)
		panel.target.select(ids.size() - 1 - index)
		panel.source.item_selected.emit(index)
		panel.target.item_selected.emit(ids.size() - 1 - index)
		var heading: String = panel.effective_text.text.get_slice("\n", 0)
		var expected: String = "Effective validated draft: %s to %s" % [
			expected_names[str(source_id)], expected_names[str(target_id)]]
		_expect(heading == expected, scope, "effective names " + str(source_id) + "/" + str(target_id), heading, expected)
		_expect(panel.source.get_selected_id() == source_id and panel.target.get_selected_id() == target_id,
			scope, "source/target selections survive effective refresh")
		selections.append({"source":panel.source.get_selected_id(), "target":panel.target.get_selected_id(),
			"effective_heading":heading})
	return {"source_items":source_rows, "target_items":target_rows,
		"default_selection":defaults, "selections":selections}


func _workbench(host: Variant, scope: String) -> Dictionary:
	var panel: CyberMicroScenarioWorkbench = CyberMicroScenarioWorkbench.new()
	host.add_child(panel)
	panel.setup(host)
	var ids: Array[int] = []
	var identities: Array[int] = [0]
	for ident: int in range(1, 132):
		if ident != 10:
			ids.append(ident)
			identities.append(ident)
	var rows: Array = _picker_check(panel.material_picker, ids, " / ", scope)
	# This is a synthetic copied owner context for the real UI methods only.
	# It does not claim that a World ran or a native observation was produced.
	var context: Dictionary = {"micro_active":true, "microscenario":{
		"schema_version":2, "definition_hash":"display-probe-synthetic-context",
		"material_ids":identities, "tools":["paint", "erase"],
		"presentation":{"instructions":"Display-name route proof", "regions":[]}}}
	var selections: Array = []
	for index: int in range(ids.size()):
		panel.material_picker.select(index)
		panel.material_picker.item_selected.emit(index)
		_expect(host.selected_material_id == ids[index], scope, "selection signal assigns stable material ID")
		panel.refresh(context)
		_expect(panel.material_picker.get_selected_id() == ids[index], scope, "selection survives workbench refresh")
		selections.append(panel.material_picker.get_selected_id())
	var details: Dictionary = panel.details()
	var exported: Array = details.get("material_identities", [])
	_expect(exported.size() == identities.size(), scope, "all 131 valid exported identities including empty")
	for index: int in range(mini(exported.size(), identities.size())):
		var ident: int = identities[index]
		_expect(exported[index].id == ident and exported[index].ui_name == expected_names[str(ident)],
			scope, "exported ui_name for " + str(ident), exported[index],
			{"id":ident, "ui_name":expected_names[str(ident)]})
	return {"items":rows, "selections":selections, "exported_material_identities":exported,
		"runtime_identity":panel.runtime_identity.duplicate(true),
		"context_scope":"synthetic copied owner context; actual workbench setup/refresh/details methods"}


func _hud(host: Variant, web: bool, scope: String) -> Array:
	var rows: Array = []
	host.debug_stats_visible = true
	host.debug_stats_expanded = false
	if web:
		# Construct the actual native class solely for the Web HUD's pure status
		# getters. No setup, tick, brush, worker or Rapier operation is requested.
		host.native_world = ClassDB.instantiate(&"CyberNativeCellWorld")
		_expect(host.native_world != null, scope, "actual native status object available")
		if host.native_world == null: return rows
	else:
		host.latest_snapshot = CyberSimulationSnapshot.new()
		host.latest_snapshot.published_usec = Time.get_ticks_usec()
	for ident: int in [0, 2, 10, 80, 83, 113, 117, 131, 132, -1]:
		host.selected_material_id = ident
		host.update_status()
		var text: String = host.status_label.text
		var expected: String = str(expected_names[str(ident)])
		var fragment: String
		if web:
			fragment = text.get_slice(" / ", 0)
			_expect(fragment == expected, scope, "Web HUD selected name " + str(ident), fragment, expected)
		else:
			var secondary: int = host.effective_secondary_material_id()
			var expected_fragment: String = "P %d:%s · M %d:%s" % [
				ident, expected, secondary, expected_names[str(secondary)]]
			var start: int = text.find("P " + str(ident) + ":")
			fragment = text.substr(start, expected_fragment.length()) if start >= 0 else ""
			_expect(fragment == expected_fragment, scope, "desktop HUD primary/secondary " + str(ident), fragment, expected_fragment)
		rows.append({"id":str(ident), "material_fragment":fragment})
	if web: host.native_world = null
	return rows


func _controller(path: String, label: String) -> Dictionary:
	var script: GDScript = load(path) as GDScript
	_expect(script != null and script.can_instantiate(), label, "actual controller script compiles")
	if script == null or not script.can_instantiate(): return {}
	var host: Variant = script.new()
	_expect(host is Control, label, "actual controller instance")
	if not host is Control: return {}
	var layout: Control = Control.new()
	layout.name = "Layout"
	host.add_child(layout)
	var title: Label = Label.new()
	title.name = "Title"
	layout.add_child(title)
	host.world_view = TextureRect.new()
	host.world_view.name = "World"
	host.world_view.size = Vector2(1024, 1024)
	layout.add_child(host.world_view)
	host.status_label = Label.new()
	layout.add_child(host.status_label)
	var names: Array = []
	for row: Dictionary in oracle.cases:
		var ident: int = str(row.id).to_int()
		var actual: String = host.material_name(ident)
		_expect(actual == row.expected, label + "/names", "material_name(" + str(row.id) + ")", actual, row.expected)
		names.append({"id":row.id, "actual":actual})
	var result: Dictionary = {"script":path, "script_sha256":FileAccess.get_sha256(path),
		"names":names, "selection":_selection(host, label + "/selection"),
		"tower":_tower(host, label + "/tower"),
		"transport":_transport(host, label + "/transport"),
		"workbench":_workbench(host, label + "/workbench"),
		"hud":_hud(host, label == "inherited_web_controller", label + "/hud")}
	host.simulation_worker.stop_worker()
	host.rapier_bridge.shutdown()
	host.free()
	return result


func _comparison(a: Dictionary, b: Dictionary) -> Dictionary:
	var comparison: CyberMicroScenarioComparison = CyberMicroScenarioComparison.new()
	var definitions: Array = [CyberMicroScenarioContract.base("display-probe/a"),
		CyberMicroScenarioContract.base("display-probe/b")]
	for index: int in range(2):
		var slot: String = "A" if index == 0 else "B"
		var checked: Dictionary = CyberMicroScenarioContract.validate(definitions[index])
		_expect(checked.get("ok", false) and comparison.store(slot, definitions[index]),
			"comparison", "valid synthetic definition " + slot)
		if not checked.get("ok", false): return {}
		comparison.retain({"definition_hash":checked.hash, "failed":false,
			"native":{"scope":"synthetic comparator input; no World execution"},
			"runtime_identity":a.duplicate(true) if index == 0 else b.duplicate(true),
			"completed_tick":0, "seed":0, "worker_count":1,
			"outcome":"synthetic comparison control", "observations":[]})
	return comparison.summary()


func _run() -> void:
	if not _arguments():
		quit(2)
		return
	var report: Dictionary = {"schema_id":"cybersand.material-catalogue.raw-display-probe",
		"schema_version":1, "godot":Engine.get_version_info().get("string", "unknown"),
		"platform":OS.get_name(), "display_server":DisplayServer.get_name(),
		"browser_or_wasm_execution":OS.has_feature("web"),
		"scope":"Actual detached Main and inherited Web scripts, real UI methods and synthetic UI context; no World tick or rendered-pixel claim",
		"oracle_sha256":FileAccess.get_sha256(str(options["--oracle"])),
		"probe_sha256":FileAccess.get_sha256(get_script().resource_path)}
	if _oracle_input():
		report["controllers"] = {"main":_controller("res://scripts/main.gd", "main"),
			"inherited_web_controller":_controller("res://scripts/web_demo_controller.gd", "inherited_web_controller")}
		var identity: Dictionary = CyberMicroScenarioIdentity.current(str(options.get("--source-revision", "unavailable")))
		report["runtime_identity"] = identity
		var loaded_scripts: Dictionary = {}
		for relative: String in PROBE_SCRIPTS:
			loaded_scripts[relative] = FileAccess.get_sha256("res://" + relative)
		report["loaded_scripts"] = loaded_scripts
		var same: Dictionary = _comparison(identity, identity)
		_expect(same.get("matched_runtime_tick_seed", false), "comparison", "same-identity positive control")
		var drifted: Dictionary = identity.duplicate(true)
		drifted.script_sha256["scripts/main.gd"] = "f".repeat(64) if identity.script_sha256["scripts/main.gd"] != "f".repeat(64) else "0".repeat(64)
		drifted.script_set_sha256 = JSON.stringify(drifted.script_sha256).sha256_text()
		var drift: Dictionary = _comparison(identity, drifted)
		_expect(not drift.get("matched_runtime_tick_seed", true), "comparison", "drifted source fingerprint ineligible")
		report["comparison_controls"] = {"same_identity":same, "drifted_identity":drift,
			"scope":"actual comparator with synthetic capture-shaped records; no native observation or World execution"}
		if options.has("--other-probe"):
			var other: Variant = _read_json(str(options["--other-probe"]))
			if other is Dictionary and other.get("runtime_identity") is Dictionary:
				var previous: Dictionary = other.runtime_identity
				var mixed: Dictionary = _comparison(identity, previous)
				_expect(previous.get("script_set_sha256") != identity.get("script_set_sha256"),
					"comparison", "old/new executable source sets differ")
				_expect(not mixed.get("matched_runtime_tick_seed", true), "comparison", "old/new capture identities ineligible")
				report.comparison_controls["other_probe_sha256"] = FileAccess.get_sha256(str(options["--other-probe"]))
				report.comparison_controls["mixed_source"] = mixed
			else:
				_expect(false, "inputs", "other probe contains runtime identity")
	report["assertions"] = assertions
	report["checks"] = checks
	report["failures"] = failures
	report["status"] = "PASS" if failures.is_empty() else "FAIL"
	var output: String = str(options["--output"])
	var error: Error = DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if error != OK:
		printerr("display probe: cannot create output directory: ", error)
		quit(2)
		return
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("display probe: cannot open report output")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  ", true, true) + "\n")
	file.close()
	print("MATERIAL_DISPLAY_PROBE: %d assertions; %d failures; %s; inherited Web is host-platform controller execution" % [
		assertions, failures.size(), OS.get_name()])
	quit(0 if failures.is_empty() else 1)
