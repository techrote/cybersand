extends SceneTree

# LCB-FEEL #360 playable comparison route through the ordinary desktop launcher,
# Main, the asynchronous simulation owner and its native World. Covers family
# selection, matched/preferred geometry, actual applied readback, opt-in owner
# participation sampling, capture/export, ordinary-session isolation and a
# fresh-owner worker-capacity change. No timing, feel or GPU claim is made.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Catalogue = preload("res://scripts/liquid_feel_catalogue.gd")
const DRAIN: String = "lcb.feel.drain-bottom.sealed.v1"
const TANK_WATER: int = 124 * 110 * 255
const FAMILIES: Array[String] = ["freemass_v1", "cellular_yield_v1", "pressure_flow_v1", "inertial_cellular_v1"]
var assertions: int = 0
var failures: int = 0
var desktop: Control
var original_workers: int = 0
var completed: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_FEEL_ROUTE: " + message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func acknowledged(controller: Control) -> bool:
	return controller != null and is_instance_valid(controller) and controller.is_inside_tree() \
		and controller.pending_microscenario_apply.is_empty() and controller.tower_context.get("micro_active", false)

func water(context: Dictionary) -> Dictionary:
	for assignment: Dictionary in context.get("liquid_solver_policy", {}).get("assignments", []):
		if int(assignment.material) == 3: return assignment
	return {}

func panel_of(controller: Control) -> CyberLiquidComparisonPanel:
	return controller.microscenario_panel.liquid_panel

func run() -> void:
	original_workers = int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0))
	root.size = Vector2i(1600, 1000)
	var launcher: Control = load("res://feature_launcher.tscn").instantiate()
	root.add_child(launcher)
	current_scene = launcher
	await process_frame
	var entry: Button
	for button: Button in launcher.find_children("*", "Button", true, false):
		if button.text.begins_with("Liquid comparison"): entry = button
	expect(entry != null, "normal launcher exposes liquid comparison")
	if entry == null:
		finish(); return
	entry.pressed.emit()
	expect(await wait_for(func() -> bool: return current_scene != null and current_scene.has_method(&"liquid_feel_relaunch")),
		"launcher reaches the desktop host with comparison controls")
	desktop = current_scene
	expect(await wait_for(func() -> bool: return acknowledged(desktop)), "protected Dam Break entry acknowledges")
	var panel: CyberLiquidComparisonPanel = panel_of(desktop)
	var controls: Control = panel.feel_controls
	expect(controls != null, "desktop comparison panel carries the A/B controls")
	if controls == null:
		finish(); return
	expect(panel.setup_picker.item_count == panel.SETUP_BUILTIN_COUNT + Catalogue.SCENARIOS.size()
		and panel.setup_picker.get_item_text(0) == "Protected Dam Break", "catalogue appends after unchanged protected setups")
	var slot7: int = panel.SETUP_BUILTIN_COUNT + Catalogue.SCENARIOS.size() - 3
	expect(str(Catalogue.entry(slot7 - panel.SETUP_BUILTIN_COUNT).slot) == "7" and panel.setup_picker.is_item_disabled(slot7),
		"actor-free controlled route explicitly refuses the Rapier slot")
	desktop.microscenario_panel.liquid_dialog.hide()
	await process_frame
	expect(not desktop.liquid_feel_sampling_requested and panel.comparison_generation == -1,
		"ordinary protected entry keeps optional participation sampling off")

	# Isolated, emptied capture directory: never touch the owner's A/B table.
	var directory: String = "user://lcb-feel-regression"
	var absolute: String = ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute):
		for file: String in DirAccess.get_files_at(absolute): DirAccess.remove_absolute(absolute.path_join(file))
	controls.use_capture_directory(directory)
	expect(controls._table.is_empty(), "regression captures start from an empty isolated table")
	panel.setup_picker.select(panel.SETUP_BUILTIN_COUNT + Catalogue.index_of(DRAIN))
	panel.geometry_picker.select(1)
	panel.normalize_water.button_pressed = true
	var rows_before: int = controls._table.size()
	for family: String in FAMILIES:
		var generation: int = int(desktop.tower_context.liquid_solver_policy.session_generation)
		expect(controls.select_water_family(family), family + " Water selection is offered natively")
		expect(panel.requested_water_assignment().family == family and water(desktop.tower_context).applied_family != family \
			or family == "freemass_v1", "selection stays pending until rebuild")
		expect(panel.load_selected(), family + " comparison request is admitted")
		expect(await wait_for(func() -> bool: return acknowledged(desktop) \
			and int(desktop.tower_context.liquid_solver_policy.session_generation) > generation), family + " rebuild acknowledges")
		panel.refresh(desktop.tower_context)
		var applied: Dictionary = desktop.tower_context.liquid_solver_policy
		var receipt: Dictionary = desktop.tower_context.liquid_construction_receipt
		expect(water(desktop.tower_context).applied_family == family and int(applied.maximum_rule_radius) == 3
			and desktop.microscenario_definition.id == DRAIN, family + " applied identity, matched radius and scenario read back")
		expect(int(receipt.normalization.net_delta) == 0 and int(receipt.normalization.positive_delta) == 0,
			family + " whole-cell capsule normalizes with zero delta")
		expect(panel.comparison_generation == int(applied.session_generation) and desktop.liquid_feel_sampling_requested,
			family + " accepted comparison enables opt-in owner sampling")
		var start_tick: int = int(desktop.tower_context.get("tick", 0))
		desktop.paused = false
		expect(await wait_for(func() -> bool: return int(desktop.tower_context.get("tick", 0)) >= start_tick + 150 \
			and not desktop.latest_snapshot.native_worker_participation.is_empty()), family + " real native ticks and a participation sample arrive")
		desktop.paused = true
		var sample: Dictionary = desktop.latest_snapshot.native_worker_participation
		expect(int(sample.workers_observed) >= 1 and int(sample.workers_observed) <= int(sample.worker_capacity)
			and int(sample.worker_capacity) == int(desktop.latest_snapshot.scheduler_thread_capacity_hint),
			family + " observed claimants stay distinct from and bounded by configured capacity")
		var rows: int = controls._table.size()
		controls.request_capture()
		expect(await wait_for(func() -> bool: return controls._table.size() > rows), family + " capture reaches the A/B table")
		var row: Dictionary = controls._table.back()
		var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(row.capture)))
		expect(row.family == family and row.scenario == DRAIN and int(row.radius) == 3, family + " A/B row carries applied identity")
		expect(record is Dictionary and int(record.native_capture.water_ledger.initial_integer) == TANK_WATER
			and int(record.native_capture.native.water_integer) == TANK_WATER and int(row.source) == 0 and int(row.sink) == 0,
			family + " captured complete Water is conserved through the opened drain")
		expect(record is Dictionary and record.subjective == "UNTESTED" and int(record.native_capture.timing.count) > 0
			and str(record.workers.scope).contains("not utilization"), family + " capture keeps machine metrics separate from feel")
		completed[family] = true
	expect(controls._table.size() == rows_before + FAMILIES.size(), "every family adds one sequential A/B row")
	expect(str(controls._table.back().capture).begins_with(directory), "captures stay in the isolated directory")
	var exported: String = controls.export_table()
	expect(not exported.is_empty() and FileAccess.get_file_as_string(exported).begins_with("scenario,definition_hash,family,variant"),
		"A/B table exports as CSV with definition and preparation identity")
	expect(str(controls._table.back().normalization_net) == "0" and int(controls._table.back().window_last_tick) > 0,
		"A/B rows record normalization and the sampled tick window")

	# Fresh reset rebuilds the same comparison under a new native generation;
	# tracking, opt-in sampling and the relaunch envelope must survive it.
	var before_reset: int = panel.comparison_generation
	controls.reset_button.pressed.emit()
	expect(await wait_for(func() -> bool: return acknowledged(desktop) \
		and int(desktop.tower_context.liquid_solver_policy.session_generation) > before_reset), "Fresh reset acknowledges")
	desktop.microscenario_panel.liquid_dialog.hide()
	desktop.microscenario_panel.refresh(desktop.tower_context)
	expect(panel.comparison_generation == int(desktop.tower_context.liquid_solver_policy.session_generation)
		and desktop.liquid_feel_sampling_requested and not panel.relaunch_envelope().is_empty(),
		"Fresh reset keeps comparison tracking, sampling and the relaunch envelope")
	desktop.microscenario_panel.open_liquids()

	panel.geometry_picker.select(2)
	controls.select_water_family("freemass_v1")
	expect(panel.selected_radius() == 2, "preferred geometry keeps FreeMass at native radius two")
	controls.select_water_family("inertial_cellular_v1")
	expect(panel.selected_radius() == 3, "preferred geometry gives InertialCellular its required radius three")
	var refusal_generation: int = int(desktop.tower_context.liquid_solver_policy.session_generation)
	panel.geometry_picker.select(0)
	expect(not panel.load_selected() or await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),
		"radius-two IN request settles")
	panel.refresh(desktop.tower_context)
	expect(int(desktop.tower_context.liquid_solver_policy.session_generation) == refusal_generation
		and water(desktop.tower_context).applied_family == "inertial_cellular_v1", "radius-two IN refusal retains the applied session")

	# A fresh owner at configured capacity one retains the accepted comparison.
	var envelope: Dictionary = panel.relaunch_envelope()
	expect(not envelope.is_empty() and envelope.definition.id == DRAIN and envelope.intent == "controlled",
		"accepted comparison yields a copied Controlled relaunch envelope")
	var exploratory: Dictionary = envelope.duplicate(true)
	exploratory.intent = "exploratory"
	expect(not desktop.liquid_feel_relaunch(4, exploratory)
		and int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0)) == original_workers,
		"Exploratory worker change refuses without touching the worker setting")
	var previous_id: int = desktop.get_instance_id()
	expect(desktop.liquid_feel_relaunch(1, envelope), "worker change is admitted")
	expect(await wait_for(func() -> bool: return current_scene != null and current_scene.get_instance_id() != previous_id \
		and current_scene.has_method(&"liquid_feel_relaunch") and acknowledged(current_scene)), "fresh owner rebuilds the comparison")
	desktop = current_scene
	expect(int(desktop.latest_snapshot.native_worker_request) == 1 and int(desktop.latest_snapshot.scheduler_thread_capacity_hint) == 1,
		"fresh owner reports the requested capacity one")
	expect(int(ProjectSettings.get_setting("cybersand/native_worker_threads", 0)) == original_workers,
		"the prior in-memory worker setting is restored once the fresh owner exists")
	expect(desktop.microscenario_definition.id == DRAIN and water(desktop.tower_context).applied_family == "inertial_cellular_v1"
		and int(desktop.tower_context.liquid_solver_policy.maximum_rule_radius) == 3, "fresh owner reapplies the accepted family and geometry")
	panel = panel_of(desktop)
	panel.refresh(desktop.tower_context)
	expect(panel.comparison_generation == int(desktop.tower_context.liquid_solver_policy.session_generation),
		"relaunched session is tracked as the accepted comparison")

	# Original Current control is not a comparison session: sampling retires.
	panel.control_button.pressed.emit()
	expect(await wait_for(func() -> bool: return acknowledged(desktop) and desktop.tower_context.liquid_construction_receipt.is_empty()),
		"Original Current control acknowledges")
	panel.refresh(desktop.tower_context)
	desktop.microscenario_panel.liquid_dialog.hide()
	desktop.microscenario_panel.refresh(desktop.tower_context)
	expect(panel.comparison_generation == -1 and not desktop.liquid_feel_sampling_requested,
		"leaving the comparison session returns optional sampling to default-off")
	finish()

func finish() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", original_workers)
	if desktop != null and is_instance_valid(desktop):
		desktop.simulation_worker.stop_worker()
		desktop.rapier_bridge.shutdown()
	print("LIQUID_FEEL_ROUTE: %d assertions; %d failures; completed=%s" % [assertions, failures, JSON.stringify(completed)])
	quit(1 if failures else 0)
