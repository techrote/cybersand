extends VBoxContainer

# LCB-FEEL #360 A/B comparison controls for the ordinary desktop application.
# Presentation and copied-value recording only. Every reconstruction goes
# through the owning CyberLiquidComparisonPanel request and Main's existing
# prepared-session transaction; worker changes use Main's fresh-owner reload.
# Values shown here are read from immutable published snapshots/context.
const Catalogue = preload("res://scripts/liquid_feel_catalogue.gd")
const CAPTURE_DIRECTORY: String = "user://lcb-feel"
const MAX_SAMPLES: int = 4096
const MAX_TABLE_ROWS: int = 64
const FAMILIES: Array[Array] = [["FreeMass", "freemass_v1"], ["CellularYield", "cellular_yield_v1"],
	["PressureFlow", "pressure_flow_v1"], ["Inertial", "inertial_cellular_v1"]]
const WORKER_OPTIONS: Array[int] = [0, 1, 4] # 0 is the existing Auto policy.

var panel: Control
var host: Control
var family_buttons: Array[Button] = []
var variant_picker: OptionButton
var worker_picker: OptionButton
var worker_button: Button
var run_button: Button
var step_button: Button
var reset_button: Button
var capture_button: Button
var export_button: Button
var readout: Label
var table_label: Label
var status: Label
var _samples: Array = []
var _participation: Array = []
var _last_serial: int = -1
var _last_participation_sequence: int = -1
var _generation: int = -1
var _capture_requested_serial: int = -1
var _table: Array = []
var _message: String = ""
var capture_directory: String = CAPTURE_DIRECTORY

func _button(row: Node, text: String, action: Callable, tip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button

func setup(owner_panel: Control, controller: Control) -> void:
	panel = owner_panel
	host = controller
	name = "LiquidFeelControls"
	var heading := Label.new()
	heading.text = "A/B comparison (#360) • physical family ≠ implementation variant ≠ material"
	heading.add_theme_font_size_override("font_size", 15)
	add_child(heading)
	var families := HFlowContainer.new()
	add_child(families)
	var family_label := Label.new()
	family_label.text = "Water physical family:"
	families.add_child(family_label)
	for pair: Array in FAMILIES:
		var family: String = pair[1]
		family_buttons.append(_button(families, str(pair[0]), func() -> void: select_water_family(family),
			"Selects only the Water assignment; other materials keep their pending selections. Applies on rebuild."))
	variant_picker = OptionButton.new()
	variant_picker.focus_mode = Control.FOCUS_NONE
	for variant: String in ["reference", "cached", "cached_dormant"]: variant_picker.add_item("PF variant: " + variant)
	variant_picker.tooltip_text = "PressureFlow optimisation variant. Cached variants share the reference pressure law; they are secondary performance arms, not extra families."
	variant_picker.item_selected.connect(func(_index: int) -> void: select_water_family("pressure_flow_v1"))
	families.add_child(variant_picker)
	var workers := HFlowContainer.new()
	add_child(workers)
	worker_picker = OptionButton.new()
	worker_picker.focus_mode = Control.FOCUS_NONE
	for value: int in WORKER_OPTIONS: worker_picker.add_item("Native workers: Auto" if value == 0 else "Native workers: %d" % value, value)
	worker_picker.tooltip_text = "Configured pool capacity is fixed when the native owner is constructed. Changing it rebuilds a fresh desktop owner and reapplies the accepted comparison selection."
	workers.add_child(worker_picker)
	worker_button = _button(workers, "Apply workers (fresh owner)", apply_workers,
		"Reloads the application scene with a new native owner at this capacity, then rebuilds the selected scenario and policy.")
	run_button = _button(workers, "Run / pause", toggle_run)
	step_button = _button(workers, "Single step", func() -> void: host.tower_command({"step":true}))
	reset_button = _button(workers, "Fresh reset", func() -> void: host.microscenario_reset(),
		"Rebuilds the accepted setup with its accepted policy, normalization and geometry.")
	capture_button = _button(workers, "Capture run", request_capture,
		"Records the applied identity, native capture and sampled host/worker observations to user://lcb-feel and the A/B table.")
	export_button = _button(workers, "Export A/B table", export_table)
	readout = Label.new()
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout.add_theme_font_size_override("font_size", 12)
	add_child(readout)
	table_label = Label.new()
	table_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	table_label.add_theme_font_size_override("font_size", 12)
	add_child(table_label)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	# The running owner's construction-time request, not the mutable setting.
	var requested: int = int(host.latest_snapshot.native_worker_request) if host.latest_snapshot != null \
		else int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0))
	var index: int = WORKER_OPTIONS.find(requested)
	if index >= 0: worker_picker.select(index)
	_table = _load_table()
	_render_table()

# Regression and evidence harnesses use their own directory, never the owner's table.
func use_capture_directory(directory: String) -> void:
	capture_directory = directory
	_table = _load_table()
	_render_table()

func _table_path() -> String:
	return capture_directory.path_join("ab-table.json")

func select_water_family(family: String) -> bool:
	var variant: String = "reference"
	if family == "pressure_flow_v1": variant = ["reference", "cached", "cached_dormant"][maxi(0, variant_picker.selected)]
	return panel.select_water_family(family, variant)

func toggle_run() -> void:
	host.paused = not host.paused

func apply_workers() -> bool:
	var workers: int = worker_picker.get_selected_id()
	var envelope: Dictionary = panel.relaunch_envelope()
	if envelope.is_empty():
		_message = "Choose and apply a comparison scenario before changing worker capacity."
		return false
	if str(envelope.get("intent", "")) != "controlled":
		_message = "Worker changes support Controlled comparisons only; Exploratory owners must be restaged after the change."
		return false
	if not host.liquid_feel_relaunch(workers, envelope):
		_message = "Worker change refused; running owner retained. " + str(host.microscenario_error)
		return false
	_message = "Rebuilding a fresh native owner…"
	return true

func request_capture() -> void:
	_capture_requested_serial = int(host.tower_context.get("micro_capture_serial", 0))
	host.microscenario_capture()
	_message = "Capture requested from the exclusive owner…"

# Called with every published context while the comparison controls exist.
func observe(context: Dictionary) -> void:
	panel.track_comparison(context)
	var applied: Dictionary = context.get("liquid_solver_policy", {})
	var generation: int = int(applied.get("session_generation", -1))
	if generation != _generation:
		_generation = generation
		_samples.clear()
		_participation.clear()
		_last_serial = -1
		_last_participation_sequence = -1
	var snapshot: Variant = host.latest_snapshot
	# Optional owner sampling only while this panel is shown or its own accepted
	# comparison session is live; ordinary sessions keep the default-off sampler.
	var active: bool = is_visible_in_tree() or (generation >= 0 and generation == panel.comparison_generation)
	host.liquid_feel_sampling_requested = active
	if not active: return
	if snapshot != null and int(snapshot.serial) != _last_serial and not host.paused:
		_last_serial = int(snapshot.serial)
		if _samples.size() < MAX_SAMPLES:
			_samples.append({"tick":int(snapshot.tick_index), "native_tick_ms":float(snapshot.simulation_time_ms),
				"worker_step_ms":float(snapshot.worker_step_time_ms), "frame_ms":float(host.frame_time_ms),
				"snapshot_age_ms":maxf(0.0, float(Time.get_ticks_usec() - int(snapshot.published_usec)) / 1000.0),
				"moves":int(snapshot.moves_last_tick)})
	var sample: Dictionary = snapshot.native_worker_participation if snapshot != null else {}
	if not sample.is_empty() and int(sample.get("sequence", -1)) != _last_participation_sequence \
		and int(sample.get("world_generation", -1)) == int(snapshot.render_world_generation):
		_last_participation_sequence = int(sample.sequence)
		if _participation.size() < MAX_SAMPLES: _participation.append(sample.duplicate(true))
	var capture_serial: int = int(context.get("micro_capture_serial", 0))
	if _capture_requested_serial >= 0 and capture_serial > _capture_requested_serial \
		and not context.get("micro_capture", {}).is_empty():
		_capture_requested_serial = -1
		_accept_capture(context, context.micro_capture)
	_render(context, snapshot)

static func _percentile(values: Array, fraction: float) -> float:
	if values.is_empty(): return -1.0
	var ordered: Array = values.duplicate()
	ordered.sort()
	return float(ordered[clampi(int(ceil(fraction * ordered.size())) - 1, 0, ordered.size() - 1)])

func _water_assignment(policy: Dictionary) -> Dictionary:
	for assignment: Dictionary in policy.get("assignments", []):
		if int(assignment.material) == 3: return assignment
	return {}

func _participation_summary() -> Dictionary:
	var maximum: int = -1
	var multiple: int = 0
	for sample: Dictionary in _participation:
		maximum = maxi(maximum, int(sample.workers_observed))
		if int(sample.workers_observed) > 1: multiple += 1
	return {"samples":_participation.size(), "max_observed":maximum, "samples_with_multiple":multiple,
		"last":_participation.back() if not _participation.is_empty() else {}}

func _render(context: Dictionary, snapshot: Variant) -> void:
	var applied: Dictionary = context.get("liquid_solver_policy", {})
	var water: Dictionary = _water_assignment(applied)
	var requested: Dictionary = panel.requested_water_assignment()
	var micro: Dictionary = context.get("microscenario", {})
	var receipt: Dictionary = context.get("liquid_construction_receipt", {})
	var lines: PackedStringArray = []
	lines.append("Scenario %s • definition %s • tick %d • %s" % [str(micro.get("id", "none")),
		str(micro.get("definition_hash", "")).left(12), int(context.get("tick", 0)), "PAUSED" if host.paused else "RUNNING"])
	lines.append("Water selected %s/%s → applied %s/%s • policy %s gen %d" % [str(requested.get("family", "?")),
		str(requested.get("variant", "?")), str(water.get("applied_family", "unavailable")), str(water.get("applied_variant", "")),
		str(applied.get("policy_hash", "")).left(10), int(applied.get("session_generation", -1))])
	var normalized: Dictionary = receipt.get("normalization", {})
	lines.append("Geometry selected r%d → applied r%d • setup %s" % [panel.selected_radius(),
		int(applied.get("maximum_rule_radius", 0)), "normalized +%s/−%s (net %s)" % [normalized.positive_delta,
		normalized.negative_delta, normalized.net_delta] if not normalized.is_empty() else "original constructor (no typed receipt)"])
	var request_value: int = int(snapshot.native_worker_request) if snapshot != null else 0
	var capacity: int = int(snapshot.scheduler_thread_capacity_hint) if snapshot != null else 0
	var participation: Dictionary = _participation_summary()
	var last: Dictionary = participation.last
	lines.append("Workers requested %s • configured capacity %d • observed task claimants max %s over %d samples (last %s at tick %s, jobs %s) — claimants are not utilization" % [
		"Auto" if request_value <= 0 else str(request_value), capacity,
		str(participation.max_observed) if participation.samples > 0 else "unobserved", participation.samples,
		str(last.get("workers_observed", "-")), str(last.get("completed_tick", "-")), str(last.get("phase_jobs", []))])
	var native: Array = []
	var step: Array = []
	var frame: Array = []
	for item: Dictionary in _samples:
		native.append(item.native_tick_ms); step.append(item.worker_step_ms); frame.append(item.frame_ms)
	lines.append("Native World::tick last %.2f ms (p50 %.2f / p95 %.2f, %d publications) • owner step p50 %.2f ms • host frame p50 %.2f / max %.2f ms • publication %.1f Hz" % [
		float(snapshot.simulation_time_ms) if snapshot != null else -1.0, _percentile(native, 0.5), _percentile(native, 0.95),
		_samples.size(), _percentile(step, 0.5), _percentile(frame, 0.5), float(host.maximum_frame_time_ms),
		float(host.measured_render_publication_hz)])
	var physical: PackedStringArray = []
	for observation: Dictionary in micro.get("observations", []).slice(-4):
		physical.append("%s=%s" % [observation.id, str(observation.value)])
	lines.append("Physical (declared observations): " + (", ".join(physical) if not physical.is_empty() else "none yet"))
	lines.append("Machine metrics are not feel ratings; headless or windowed timings are not GPU FPS.")
	readout.text = "\n".join(lines)
	var pending: bool = not host.pending_microscenario_apply.is_empty() or not host.pending_water_apply.is_empty()
	for button: Button in family_buttons: button.disabled = pending
	worker_button.disabled = pending or worker_picker.get_selected_id() == request_value
	step_button.disabled = pending or micro.is_empty()
	capture_button.disabled = pending or micro.is_empty()
	status.text = _message

func _accept_capture(context: Dictionary, report: Dictionary) -> void:
	var applied: Dictionary = context.get("liquid_solver_policy", {})
	var water: Dictionary = _water_assignment(applied)
	var snapshot: Variant = host.latest_snapshot
	var native: Array = []
	var frame: Array = []
	for item: Dictionary in _samples:
		native.append(item.native_tick_ms); frame.append(item.frame_ms)
	var record: Dictionary = {"schema":"lcb-feel-app-capture-v1", "catalogue":Catalogue.VERSION,
		"utc":Time.get_datetime_string_from_system(true), "scenario":str(report.get("id", "")),
		"definition_hash":str(report.get("definition_hash", "")), "selected_water":panel.requested_water_assignment(),
		"applied_policy":applied.duplicate(true), "construction_receipt":context.get("liquid_construction_receipt", {}).duplicate(true),
		"liquid_host_observation":context.get("liquid_host_observation", {}).duplicate(true),
		"workers":{"requested":int(snapshot.native_worker_request) if snapshot != null else -1,
			"configured_capacity":int(snapshot.scheduler_thread_capacity_hint) if snapshot != null else -1,
			"participation":_participation_summary(), "participation_samples":_participation.duplicate(true),
			"scope":"sampled at most 4 Hz from the exclusive owner; configured capacity is not participation, and claimants are not utilization"},
		"native_capture":{"completed_tick":report.get("completed_tick", 0), "native":report.get("native", {}),
			"timing":report.get("timing", {}), "water_ledger":report.get("water_ledger", {}),
			"observations":report.get("observations", []), "work_statistics":report.get("work_statistics", {}),
			"budget_outcome":report.get("budget_outcome", ""), "outcome":report.get("outcome", "")},
		"host_samples":{"publications":_samples.size(), "native_tick_ms_p50":_percentile(native, 0.5),
			"native_tick_ms_p95":_percentile(native, 0.95), "frame_ms_p50":_percentile(frame, 0.5),
			"frame_ms_p95":_percentile(frame, 0.95), "samples":_samples.duplicate(true),
			"scope":"one sample per consumed publication; native tick is the latest World::tick of that publication"},
		"subjective":"UNTESTED"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	var name: String = "%s-%s-%s-c%d.json" % [Time.get_datetime_string_from_system(true).replace(":", ""),
		str(report.get("id", "scenario")), str(water.get("applied_family", "unknown")), int(record.workers.configured_capacity)]
	var path: String = capture_directory.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_message = "Could not write the comparison capture."
		return
	file.store_string(JSON.stringify(record, "  ") + "\n")
	file.close()
	var timing: Dictionary = report.get("timing", {})
	var ledger: Dictionary = report.get("water_ledger", {})
	var typed: Dictionary = context.get("liquid_construction_receipt", {})
	var inertial: Dictionary = applied.get("family_parameters", {}).get("inertial_cellular_v1", {})
	_table.append({"scenario":record.scenario, "definition_hash":str(report.get("definition_hash", "")).left(16),
		"normalization_net":str(typed.get("normalization", {}).get("net_delta", "none")),
		"in_damping":str(inertial.get("damping_numerator", "-")),
		"window_first_tick":int(_samples.front().tick) if not _samples.is_empty() else -1,
		"window_last_tick":int(_samples.back().tick) if not _samples.is_empty() else -1,
		"family":str(water.get("applied_family", "")),
		"variant":str(water.get("applied_variant", "")), "radius":int(applied.get("maximum_rule_radius", 0)),
		"capacity":int(record.workers.configured_capacity), "claimants_max":int(record.workers.participation.max_observed),
		"ticks":int(report.get("completed_tick", 0)), "native_p50_ms":float(timing.get("p50_ms", -1.0)),
		"native_p95_ms":float(timing.get("p95_ms", -1.0)), "water_initial":int(ledger.get("initial_integer", -1)),
		"water_current":int(report.get("native", {}).get("water_integer", -1)), "source":int(ledger.get("explicit_source", 0)),
		"sink":int(ledger.get("explicit_sink", 0)), "capture":path})
	while _table.size() > MAX_TABLE_ROWS: _table.pop_front()
	_save_table()
	_render_table()
	_message = "Captured " + ProjectSettings.globalize_path(path)

func _load_table() -> Array:
	if not FileAccess.file_exists(_table_path()): return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_table_path()))
	return parsed if parsed is Array else []

func _save_table() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	var file := FileAccess.open(_table_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_table, "  ") + "\n")
		file.close()

func _render_table() -> void:
	var lines: PackedStringArray = ["Captured runs (sequential A/B; newest last):",
		"scenario | Water family/variant | r | cap/claimants | ticks | native p50/p95 ms | Water initial→now (src/sink)"]
	for row: Dictionary in _table.slice(-8):
		lines.append("%s | %s/%s | %d | %d/%d | %d | %.2f/%.2f | %d→%d (%d/%d)" % [str(row.scenario), str(row.family).trim_suffix("_v1"),
			str(row.variant), int(row.radius), int(row.capacity), int(row.claimants_max), int(row.ticks),
			float(row.native_p50_ms), float(row.native_p95_ms), int(row.water_initial), int(row.water_current),
			int(row.source), int(row.sink)])
	table_label.text = "\n".join(lines) if not _table.is_empty() else "No captured runs yet."

func export_table() -> String:
	var path: String = capture_directory.path_join("ab-table.csv")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_message = "Could not export the A/B table."
		return ""
	var columns: PackedStringArray = ["scenario", "definition_hash", "family", "variant", "radius", "normalization_net",
		"in_damping", "capacity", "claimants_max", "ticks", "window_first_tick", "window_last_tick",
		"native_p50_ms", "native_p95_ms", "water_initial", "water_current", "source", "sink", "capture"]
	file.store_line(",".join(columns))
	for row: Dictionary in _table:
		var values: PackedStringArray = []
		for column: String in columns: values.append(str(row.get(column, "")))
		file.store_line(",".join(values))
	file.close()
	_message = "Exported " + ProjectSettings.globalize_path(path)
	return path
