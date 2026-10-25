extends SceneTree

const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const DAM_PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var assertions: int = 0
var failures: int = 0
var desktop: Control
var web: Control

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_COMPARISON_UI: " + message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func acknowledged(controller: Control) -> bool:
	return controller.pending_microscenario_apply.is_empty() and controller.tower_context.get("micro_active",false)

func choose(panel: CyberLiquidComparisonPanel, index: int) -> void:
	panel.preset_picker.select(index)
	panel.preset_picker.item_selected.emit(index)

func water_family(context: Dictionary) -> String:
	for assignment: Dictionary in context.get("liquid_solver_policy",{}).get("assignments",[]):
		if int(assignment.material) == 3: return str(assignment.applied_family)
	return "unavailable"

func run() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge") if ClassDB.class_exists(&"CyberDemoBridge") else null
	if bridge == null or not bridge.has_method(&"liquid_policy_assignment_choices"):
		expect(false,"fresh native comparison editor required")
		finish()
		return
	root.size = Vector2i(1600,1000)
	var original: Dictionary = Contract.parse(FileAccess.get_file_as_string(DAM_PATH))
	var request: PackedInt32Array = bridge.default_liquid_policy()
	var unchanged: PackedInt32Array = request.duplicate()
	var choices: Array = bridge.liquid_policy_assignment_choices(request,3)
	expect(choices.size() >= 4 and request == unchanged, "native choices keep caller request immutable")
	for choice: Dictionary in choices:
		var readback: Dictionary = bridge.validate_liquid_policy(choice.request)
		expect(readback.accepted == choice.accepted, "native option availability agrees with actual admission")
		if choice.accepted:
			for assignment: Dictionary in readback.receipt.assignments:
				if int(assignment.material) == 3:
					expect(assignment.applied_family == choice.family and assignment.applied_variant == choice.variant,
						"native request option edits actual Water assignment")
				else:
					expect(assignment.applied_family == "cellular_yield_v1", "Water edit preserves every foreign material assignment")

	# Press the real launcher entry. Its normal main.tscn route opens the same
	# MicroScenario Liquids dialog and queues a controlled protected Dam Break.
	var launcher: Control = load("res://feature_launcher.tscn").instantiate()
	root.add_child(launcher)
	current_scene = launcher
	await process_frame
	var entry: Button
	for button: Button in launcher.find_children("*","Button",true,false):
		if button.text.begins_with("Liquid comparison"): entry = button
	expect(entry != null,"normal launcher exposes liquid comparison")
	if entry == null:
		finish()
		return
	entry.pressed.emit()
	expect(await wait_for(func() -> bool:
		return current_scene != null and current_scene.has_method(&"microscenario_apply_controlled_liquid")), "launcher reaches normal application")
	desktop = current_scene
	expect(await wait_for(func() -> bool: return acknowledged(desktop)), "launcher Dam Break is acknowledged")
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.refresh(desktop.tower_context)
	expect(desktop.microscenario_panel.liquid_dialog.visible and desktop.paused, "normal comparison opens paused in existing host")
	expect(Contract.validate(desktop.microscenario_definition).hash == original.hash \
		and water_family(desktop.tower_context) == "freemass_v1", "entry retains protected definition and Current Water")
	var applied: Dictionary = desktop.tower_context.liquid_solver_policy
	var generation: int = applied.session_generation
	var policy_hash: String = applied.policy_hash
	choose(panel,2)
	panel.refresh(desktop.tower_context)
	expect(desktop.tower_context.liquid_solver_policy.policy_hash == policy_hash \
		and desktop.tower_context.liquid_solver_policy.session_generation == generation \
		and panel.status.text.contains("Pending"), "preset changes only pending request, never live policy")
	panel.apply_button.pressed.emit()
	expect(await wait_for(func() -> bool: return acknowledged(desktop) \
		and desktop.tower_context.liquid_solver_policy.session_generation > generation), "pressure Apply & rebuild acknowledges")
	panel.refresh(desktop.tower_context)
	expect(water_family(desktop.tower_context) == "pressure_flow_v1" \
		and desktop.tower_context.liquid_construction_receipt.kind == "applied_run" \
		and panel.receipt_label.text.contains("pressure_flow_v1/reference"), "actual applied pressure receipt drives visible readback")
	for index: int in panel.PRESETS.size():
		expect(panel.preset_picker.is_item_disabled(index) == not panel._preset(index).ok, "preset availability uses native validation")

	# Use the ordinary definition editor/controller path for a fractional setup;
	# the panel's whole-cell request must refuse, retaining the prior session.
	var partial: Dictionary = original.definition.duplicate(true)
	partial.partial_water_fills = [50,100,1,1,127,0,51,100,1,1,128,0]
	expect(desktop.microscenario_apply_definition(partial,"Benchmark"), "ordinary fractional definition queues")
	expect(await wait_for(func() -> bool: return acknowledged(desktop)), "fractional definition acknowledges")
	panel.refresh(desktop.tower_context)
	generation = desktop.tower_context.liquid_solver_policy.session_generation
	policy_hash = desktop.tower_context.liquid_solver_policy.policy_hash
	choose(panel,1)
	panel.normalize_water.button_pressed = false
	panel.apply_button.pressed.emit()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()), "no-opt-in refusal is acknowledged")
	panel.refresh(desktop.tower_context)
	expect(desktop.tower_context.liquid_solver_policy.session_generation == generation \
		and desktop.tower_context.liquid_solver_policy.policy_hash == policy_hash \
		and desktop.tower_context.liquid_construction_receipt.is_empty() \
		and panel.status.text.contains("normalization_required"), "UI refusal retains native policy/generation and original constructor identity")
	expect(desktop.tower_context.liquid_construction_attempt.kind == "construction_attempt", "native refusal has distinct attempt readback")
	panel.normalize_water.button_pressed = true
	panel.apply_button.pressed.emit()
	expect(await wait_for(func() -> bool: return acknowledged(desktop) \
		and desktop.tower_context.liquid_solver_policy.session_generation > generation), "explicit normalization rebuild acknowledges")
	panel.refresh(desktop.tower_context)
	var receipt: Dictionary = desktop.tower_context.liquid_construction_receipt
	expect(water_family(desktop.tower_context) == "cellular_yield_v1" \
		and receipt.normalization.positive_delta == 127 and receipt.normalization.negative_delta == 127 \
		and panel.receipt_label.text.contains("added 127 / removed 127 / net 0"), "UI displays actual native gross/net normalization, including zero net change")
	expect(desktop.microscenario_mode == "Benchmark", "active rebuild preserves the existing scenario mode")
	generation = receipt.session_generation
	var payload: String = receipt.prepared_payload_hash
	desktop.microscenario_panel.reset_button.pressed.emit()
	expect(await wait_for(func() -> bool: return acknowledged(desktop) \
		and desktop.tower_context.liquid_solver_policy.session_generation > generation), "existing Fresh reset acknowledges")
	panel.refresh(desktop.tower_context)
	expect(desktop.tower_context.liquid_construction_receipt.prepared_payload_hash == payload \
		and panel.normalize_water.button_pressed and water_family(desktop.tower_context) == "cellular_yield_v1", "Reset retains applied policy, normalized setup and checkbox readback")
	expect(desktop.microscenario_apply_definition(Catalogue.tower(),"Inspect"), "ordinary actor-enabled Tower remains available")
	expect(await wait_for(func() -> bool: return acknowledged(desktop)), "ordinary Tower acknowledges")
	panel.refresh(desktop.tower_context)
	generation = desktop.tower_context.liquid_solver_policy.session_generation
	expect(panel.apply_button.disabled and not panel.apply_active(), "unsupported actor constructor is explicitly unavailable to experimental apply")
	panel.refresh(desktop.tower_context)
	expect(desktop.tower_context.liquid_solver_policy.session_generation == generation \
		and desktop.tower_context.liquid_construction_attempt.is_empty() \
		and panel.status.text.contains("not yet wired"), "unsupported route keeps its existing native session without inventing a native attempt")
	panel.control_button.pressed.emit()
	expect(await wait_for(func() -> bool: return acknowledged(desktop) \
		and desktop.tower_context.liquid_construction_receipt.is_empty()), "Original Current control acknowledges")
	panel.refresh(desktop.tower_context)
	expect(water_family(desktop.tower_context) == "freemass_v1" \
		and Contract.validate(desktop.microscenario_definition).hash == original.hash \
		and not panel.normalize_water.button_pressed, "original control restores exact protected definition and unchanged default constructor")
	desktop.simulation_worker.stop_worker()
	var reference: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var reference_host: CyberMicroScenarioHost = Host.new()
	expect(reference_host.install(reference,original.definition,"Inspect"), "independent original constructor succeeds")
	expect(reference.get_physical_state_hash() == desktop.simulation_worker._world.get_physical_state_hash(),
		"Original Current control preserves exact complete native state against the unchanged constructor")
	desktop.rapier_bridge.shutdown()
	current_scene = null
	desktop.queue_free()
	desktop = null
	remove_meta("cybersand_feature")
	await process_frame

	# The synchronous application's actual pane uses the same native request
	# choices and copied readback; this native test is not a browser claim.
	web = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	await process_frame
	web.focused = true
	web.ui.close_menu()
	web.microscenario_panel.open_liquids()
	panel = web.microscenario_panel.liquid_panel
	choose(panel,2)
	panel.dam_button.pressed.emit()
	panel.refresh(web.tower_context)
	expect(water_family(web.tower_context) == "pressure_flow_v1" \
		and web.tower_context.liquid_construction_receipt.kind == "applied_run", "synchronous pane applies native pressure and reads actual policy")
	expect(web.microscenario_apply_definition(partial,"Inspect"), "synchronous fractional setup installs")
	panel.refresh(web.tower_context)
	choose(panel,1)
	panel.normalize_water.button_pressed = false
	generation = web.tower_context.liquid_solver_policy.session_generation
	expect(not panel.apply_active(), "synchronous no-opt-in apply refuses")
	panel.refresh(web.tower_context)
	expect(web.tower_context.liquid_solver_policy.session_generation == generation \
		and panel.status.text.contains("normalization_required"), "synchronous pane preserves applied state on native refusal")
	panel.normalize_water.button_pressed = true
	expect(panel.apply_active(), "synchronous explicit normalization applies")
	panel.refresh(web.tower_context)
	expect(web.tower_context.liquid_construction_receipt.normalization.positive_delta == 127 \
		and water_family(web.tower_context) == "cellular_yield_v1", "synchronous pane shares exact native normalization")
	choose(panel,2)
	panel.setup_picker.select(1)
	panel.dam_button.pressed.emit()
	panel.refresh(web.tower_context)
	expect(web.microscenario_definition.id == "lcb.mixed.water-oil-brine.v1" \
		and water_family(web.tower_context) == "pressure_flow_v1", "existing mixed-liquid fixture loads through the normal comparison pane")
	var materials: Array = web.tower_context.microscenario.material_ids
	expect(3 in materials and 16 in materials and 24 in materials, "one native mixed setup contains Water, Oil and Brine")
	web.microscenario_panel.liquid_dialog.hide()
	web.microscenario_panel.step_button.pressed.emit()
	expect(await wait_for(func() -> bool: return int(web.tower_context.get("tick",0)) == 1) \
		and not web.micro_host.summary().failed, "existing single-step control advances the accepted mixed World")
	web.rapier_bridge.shutdown()
	web.queue_free()
	web = null
	await process_frame
	finish()

func finish() -> void:
	if desktop != null:
		desktop.simulation_worker.stop_worker()
		desktop.rapier_bridge.shutdown()
	if web != null: web.rapier_bridge.shutdown()
	print("LIQUID_COMPARISON_UI: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
