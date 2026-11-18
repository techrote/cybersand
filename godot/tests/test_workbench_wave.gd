extends SceneTree

# Real Shared Workbench ownership, native application and subsequent ticks.
# A completed request is not necessarily an accepted request: every successful
# rebuild below requires a new authoritative World generation as well as idle UI.
const Setup = preload("res://scripts/workbench_setup.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const DAM = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const TUNING := {
	"substeps":2,"active_rows":24,"gain":48,"gain_confined":12,"stiffness":512,
	"damp_shift":9,"coast":40,"level_shift":2,"sleep_after":47,"wake_peak":2,
	"rest_head":3,"stick":256,"calm":768,"calm_damp_shift":4,"maximum_mass":30600,
	"empty_pour_shift":3,"flow_share_shift":2,"adhesion_shift":2,
}
const INVALID_KNOBS := {
	"substeps":9,"active_rows":33,"gain":513,"gain_confined":513,"stiffness":4097,
	"damp_shift":17,"coast":65536,"level_shift":17,"sleep_after":3601,"wake_peak":65536,
	"rest_head":65536,"stick":65536,"calm":65536,"calm_damp_shift":17,"maximum_mass":65536,
	"empty_pour_shift":0,"flow_share_shift":0,"adhesion_shift":9,
}
var host: Control
var panel: Control
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var sections := {"activation":false,"parameters":false,"workers_substeps":false,
	"runtime_apply":false,"regeneration":false,"scenario_change":false,
	"pause_resume":false,"invalid_recovery":false,"solver_switch":false,
	"comparison_scenes":false,"native_validation":false,"failure_recovery":false}
var native_ticks := 0
var started_usec := 0

func _initialize() -> void:
	started_usec = Time.get_ticks_usec()
	run.call_deferred()

func require(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("WORKBENCH_WAVE: " + detail)
	return ok

# UI contract: no expanding Water controls in the Workbench toolbar. The
# existing live control objects, native receipts and option editors remain
# reachable from one non-modal, tabbed window.
func water_lab_ui() -> void:
	var lab: RefCounted = panel.water_lab
	require(lab != null and lab.window != null and lab.tabs != null,
		"Water Lab is a single owned Workbench window")
	if lab == null or lab.window == null: return
	require(lab.tabs.get_tab_count() == 5,"all five Water control groups are visible as tabs")
	require(not lab.window.visible,"Water Lab starts closed to preserve canvas space")
	require(lab.pages["solvers"].is_ancestor_of(panel.water_spray._scene_picker),
		"solver and comparison scene picker are in Water Lab")
	require(lab.pages["solvers"].is_ancestor_of(panel.water_spray._studio_solver)
		and panel.water_spray._studio_solver.item_count == 7,
		"one integrated Water-law picker replaces the button cluster")
	require(lab.pages["wave"].is_ancestor_of(panel.water_spray._wave_fields["workbench_wave_gain"]),
		"Wave tuning is integrated, not a second popup")
	require(lab.pages["transport"].is_ancestor_of(panel.water_spray._ballistic),
		"ballistic, face, PF and spray controls share the transport tab")
	require(lab.pages["equipment"].is_ancestor_of(panel.equipment._buttons.valve),
		"valve, drain and nozzle controls are in Water Lab")
	require(lab.pages["advanced"].is_ancestor_of(panel._liquids),
		"complete per-material policy editor is in Water Lab")
	require(lab.pages["status"].is_ancestor_of(panel.water_spray._wave_status),
		"native applied/staged readback persists across all tabs")
	require(not (panel.water_spray._wave_window.is_inside_tree() or panel.water_spray._spray_window.is_inside_tree()),
		"Wave and spray do not create auxiliary windows")
	lab.select_tab(1)
	require(lab.tabs.current_tab == 1,"Wave tab is navigable")
	lab.select_tab(0)

func lab_button(label: String) -> Button:
	for node: Node in panel.water_lab.window.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and node.text == label: return node
	return null

func click_lab_button(label: String) -> bool:
	var button := lab_button(label)
	if not require(button != null,"visible Water Lab action: "+label): return false
	var scroll := button.get_parent()
	while scroll != null and not scroll is ScrollContainer: scroll = scroll.get_parent()
	if scroll != null:
		scroll.ensure_control_visible(button)
		await process_frame
	var point := button.get_global_rect().get_center()+Vector2(panel.water_lab.window.position)
	var pressed := [false]
	button.pressed.connect(func() -> void: pressed[0] = true,CONNECT_ONE_SHOT)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	return require(pressed[0],"real pointer event reaches Water Lab "+label)

func type_spin_text(field: SpinBox, text: String) -> bool:
	var scroll := field.get_parent()
	while scroll != null and not scroll is ScrollContainer: scroll = scroll.get_parent()
	if scroll != null: scroll.ensure_control_visible(field)
	await process_frame
	var editor := field.get_line_edit()
	editor.grab_focus()
	await process_frame
	editor.select_all()
	var old := field.value
	# Character events reach the focused editor without Enter, Tab or .apply().
	# The action under test must commit this still-pending numeric text.
	for index: int in text.length():
		for down: bool in [true,false]:
			var key := InputEventKey.new()
			key.keycode = text.unicode_at(index)
			key.unicode = text.unicode_at(index)
			key.pressed = down
			editor.get_viewport().push_input(key,true)
			await process_frame
	return require(editor.text == text and field.value == old and editor.has_focus(),
		"numeric text remains pending in the child Window: "+text)

func policy_assignment(bridge: Variant, policy: PackedInt32Array, material: int,
		family: String, variant: String = "reference") -> PackedInt32Array:
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(policy,material):
		if choice.get("accepted",false) and choice.get("family","") == family and choice.get("variant","") == variant:
			return PackedInt32Array(choice.request)
	require(false,"native policy admits %d %s/%s" % [material,family,variant])
	return PackedInt32Array()

func policy_family(receipt: Dictionary, material: int) -> String:
	for row: Dictionary in receipt.get("assignments",[]):
		if int(row.material) == material: return str(row.get("applied_family",""))
	return ""

func native_policy_restore(bridge: Variant) -> void:
	if not require(bridge.has_method(&"liquid_policy_restore_assignment"),"native assignment restoration API is present"): return
	var defaults: PackedInt32Array = bridge.default_liquid_policy()
	var remembered := policy_assignment(bridge,defaults,Setup.WATER,"pressure_flow_v1","cached")
	var result: Dictionary = bridge.liquid_policy_with_pressure_gas(remembered,false)
	if not require(result.get("accepted",false),"remember gas-off PressureFlow settings"): return
	remembered = PackedInt32Array(result.request)
	var current := policy_assignment(bridge,defaults,24,"inertial_cellular_v1")
	result = bridge.liquid_policy_with_inertial_damping(current,9)
	if not require(result.get("accepted",false),"change current shared Inertial damping"): return
	current = PackedInt32Array(result.request)
	var unchanged := current.duplicate()
	result = bridge.liquid_policy_restore_assignment(current,remembered,Setup.WATER)
	if not require(result.get("accepted",false),"restore only Water's remembered PressureFlow assignment"): return
	var receipt: Dictionary = result.receipt
	require(policy_family(receipt,Setup.WATER) == "pressure_flow_v1" and policy_family(receipt,24) == "inertial_cellular_v1",
		"native restore keeps current Brine while restoring Water")
	require(receipt.family_parameters.pressure_flow_v1.gas_enabled == false \
		and receipt.family_parameters.inertial_cellular_v1.damping_numerator == 9,
		"native restore retains dormant PF gas and current shared Inertial values together")
	require(current == unchanged,"native policy restore does not mutate its current request")
	remembered = policy_assignment(bridge,defaults,Setup.WATER,"inertial_cellular_v1")
	result = bridge.liquid_policy_with_inertial_damping(remembered,3)
	if not require(result.get("accepted",false),"remember Water's former Inertial damping"): return
	remembered = PackedInt32Array(result.request)
	for expected: int in [9,1]:
		if expected == 1: current = policy_assignment(bridge,defaults,24,"inertial_cellular_v1")
		result = bridge.liquid_policy_restore_assignment(current,remembered,Setup.WATER)
		if not require(result.get("accepted",false),"restore Water into a currently shared Inertial family"): return
		require(result.receipt.family_parameters.inertial_cellular_v1.damping_numerator == expected,
			"current shared family owns explicit values and implicit defaults, not cached Water's value")
	result = bridge.liquid_policy_restore_assignment(defaults,remembered,Setup.WATER)
	require(result.get("accepted",false) and result.get("receipt",{}).get("family_parameters",{}).get("inertial_cellular_v1",{}).get("damping_numerator",-1) == 3,
		"remembered Inertial parameters return when no current material uses the family")
	for bad: Array in [[PackedInt32Array(),remembered,Setup.WATER],[current,PackedInt32Array(),Setup.WATER],[current,remembered,58]]:
		result = bridge.callv("liquid_policy_restore_assignment",bad)
		require(not result.get("accepted",true),"invalid policy/remembered material refuses without a request")

func idle() -> bool:
	return panel != null and not panel.applied.is_empty() and not panel.busy() \
		and host.pending_microscenario_apply.is_empty()

func generation() -> int:
	return int(host.latest_snapshot.render_world_generation) if host.latest_snapshot != null else -1

func wave() -> Dictionary:
	return host.tower_context.get("wave_flow",{})

func until(predicate: Callable, label: String, allow_failure := false) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return require(true,label)
		if not allow_failure and is_instance_valid(host) and host.simulation_worker.has_failed(): break
		await process_frame
	return require(false,label+" / "+(str(host.microscenario_error) if is_instance_valid(host) else "no host"))

func installed_after(before: int, label: String) -> bool:
	if not await until(idle,label+" request settled"): return false
	return require(generation() > before and str(host.microscenario_error).is_empty(),
		label+" positively installed / "+str(host.microscenario_error)+" / "+str(panel.message))

func observe(stage: String) -> void:
	observations.append({"stage":stage,"generation":generation(),"native":wave().duplicate(true),
		"worker_failed":host.simulation_worker.has_failed(),"paused":host.paused,
		"water_family":native_water_family(),
		"inertial_signed":host.tower_context.get("water_spray",{}).get("inertial_signed",false),
		"construction_receipt_hash":host.tower_context.get("liquid_construction_receipt",{}).get("receipt_hash","")})

func native_water_family() -> String:
	for row: Dictionary in host.tower_context.get("liquid_solver_policy",{}).get("assignments",[]):
		if int(row.material) == Setup.WATER: return str(row.get("applied_family",""))
	return ""

func matches(values: Dictionary, label: String) -> bool:
	var before := failures.size()
	var actual := wave()
	require(actual.get("enabled",false),label+" actual native Wave enabled")
	panel.water_spray.refresh(host.tower_context)
	for key: String in values:
		var readback: int = int(actual.get(key,-1)) if key == "substeps" \
			else int(actual.get("parameters",{}).get(key,-1))
		require(readback == int(values[key]),label+" native "+key+"=%d requested=%d" % [readback,int(values[key])])
		var shown: Label = panel.water_spray._wave_applied_fields.get("workbench_wave_"+key)
		require(shown != null and shown.text == "native %d" % readback,label+" visible authoritative readback "+key)
	return failures.size() == before

func step_wave(count: int, label: String) -> bool:
	var start := failures.size()
	var before: Dictionary = wave().duplicate(true)
	var old_generation := generation()
	var quantity := str(before.get("water_quantity","missing"))
	for i: int in count:
		var tick: int = host.latest_snapshot.tick_index
		if not require(panel.step_once(),label+" single tick admitted"): return false
		if not await until(func() -> bool: return idle() and int(host.latest_snapshot.tick_index) >= tick+1,
			label+" actual native tick acknowledged"): return false
		require(int(host.latest_snapshot.tick_index) == tick+1,label+" one requested step is one native tick")
		require(generation() == old_generation,label+" stepping retains World")
		require(str(wave().get("water_quantity","missing")) == quantity,label+" native Water quantity conserved")
	var after := wave()
	var ticks := int(after.get("ticks",0))-int(before.get("ticks",0))
	var rounds := int(after.get("rounds",0))-int(before.get("rounds",0))
	native_ticks += maxi(0,ticks)
	require(ticks == count,label+" actual Wave tick count")
	require(rounds == count*int(after.get("substeps",0)),label+" actual substep rounds")
	require(int(after.get("last_tasks",0)) > 0 and int(after.get("maximum_participants",0)) > 0,
		label+" native workers performed Wave tasks")
	require(not host.simulation_worker.has_failed(),label+" healthy owner")
	observe(label)
	return failures.size() == start

func native_validation() -> void:
	var start := failures.size()
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	native_policy_restore(bridge)
	var checked: Dictionary = Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var options := {"workbench_extent":Vector2i(256,256),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),"geometry":PackedFloat64Array(),"bodies":[]},
		"region":PackedInt32Array([0,0,256,256]),"intent":"exploratory","definition_hash":checked.hash,
		"initial_bodies":PackedFloat32Array(),"workbench_wave_flow":true,"workbench_worker_threads":4}
	for key: String in TUNING: options["workbench_wave_"+key] = TUNING[key]
	var cells := PackedInt32Array([0,220,256,4,58,0,0,4,220,58,252,0,4,220,58,
		4,100,96,120,3,100,180,152,40,3])
	var args := [world,cells,checked.transport.packed,PackedInt32Array(checked.definition.water_semantics),
		PackedInt32Array(),bridge.default_liquid_policy(),options]
	var token: int = bridge.callv("prepare_liquid_world",args)
	if not require(token > 0 and bridge.commit_liquid_world(world,token),
		"native ordinary Baseline transport admits Wave / "+str(bridge.get_last_error())): return
	var actual: Dictionary = world.get_wave_flow_status()
	require(actual.enabled and actual.substeps == 2 and actual.workers_requested == 4,"native applied constructor readback")
	for key: String in TUNING:
		if key != "substeps": require(int(actual.parameters.get(key,-1)) == int(TUNING[key]),"native constructor "+key)
	require(world.simulation_tick(),"native configured World ticks")
	var before: String = world.get_physical_state_hash()
	var revision: int = world.get_revision()
	var old_generation: int = world.get_liquid_policy_session_generation()
	var invalid: Array[Dictionary] = []
	for key: String in INVALID_KNOBS: invalid.append({"workbench_wave_"+key:INVALID_KNOBS[key]})
	invalid.append_array([{"workbench_wave_substeps":0},{"workbench_wave_gain":1.5},
		{"workbench_wave_gain":"48"},{"workbench_wave_flow":"yes"},{"workbench_wave_stiffness":1},
		{"workbench_worker_threads":0},{"workbench_worker_threads":33},{"workbench_worker_threads":1.5},
		{"workbench_ballistic":"yes"}])
	for bad: Dictionary in invalid:
		var candidate := options.duplicate(true)
		candidate.merge(bad,true)
		args[6] = candidate
		token = bridge.callv("prepare_liquid_world",args)
		require(token == 0 and not str(bridge.get_last_error()).is_empty(),"native invalid configuration explicitly refused "+str(bad))
		if token > 0: bridge.discard_liquid_world(world,token)
		require(world.get_physical_state_hash() == before and world.get_revision() == revision \
			and world.get_liquid_policy_session_generation() == old_generation,"native refusal is atomic "+str(bad))
	# Canonicalizing the exact Baseline must never admit a genuinely edited profile.
	var custom: PackedInt32Array = checked.transport.packed.duplicate()
	custom[1] = 1 # valid sampled-lateral choice, genuinely different from Baseline
	args[2] = custom
	args[6] = options
	token = bridge.callv("prepare_liquid_world",args)
	require(token == 0,"custom cellular transport remains refused")
	if token > 0: bridge.discard_liquid_world(world,token)
	require(world.get_physical_state_hash() == before and world.get_revision() == revision,"custom transport refusal preserves World")
	args[2] = checked.transport.packed
	token = bridge.callv("prepare_liquid_world",args)
	require(token > 0 and bridge.commit_liquid_world(world,token) and world.simulation_tick(),"native recovery accepts valid configuration and ticks")
	var single: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	args[0] = single
	var one_worker := options.duplicate(true)
	one_worker.workbench_worker_threads = 1
	args[6] = one_worker
	token = bridge.callv("prepare_liquid_world",args)
	if require(token > 0 and bridge.commit_liquid_world(single,token) and single.simulation_tick(),"one-worker comparison admitted"):
		var quantity: String = world.get_wave_flow_status().water_quantity
		for tick: int in 12:
			require(world.simulation_tick() and single.simulation_tick(),"both tuned native worker configurations tick")
			require(world.get_physical_state_hash() == single.get_physical_state_hash(),"all-parameter tuned Wave is deterministic at workers 1/4")
			require(str(world.get_wave_flow_status().water_quantity) == quantity and str(single.get_wave_flow_status().water_quantity) == quantity,
				"tuned native worker comparison conserves exact quantity")
	# Inspect the owned native fixture directly: material rendering alone cannot
	# prove preservation of each uint16 mass after Wave has created overfill.
	var retained_cells: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(256,256))
	var peak := 0
	for y: int in range(100,220):
		for x: int in range(4,252): peak = maxi(peak,int(world.inspect_wave_flow_cell(Vector2i(x,y)).stored_mass))
	require(peak > 255,"retained native fixture positively contains uint16 overfill before retuning")
	var retained := options.duplicate(true)
	retained.workbench_retain_cells = true
	retained.workbench_wave_gain = 64
	retained.workbench_wave_substeps = 3
	retained.workbench_worker_threads = 2
	args[0] = world
	args[1] = PackedInt32Array()
	args[6] = retained
	token = bridge.callv("prepare_liquid_world",args)
	if require(token > 0 and bridge.commit_liquid_world(world,token),"retained native Wave retuning accepts actual fullmass / "+str(bridge.get_last_error())):
		var after: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(256,256))
		require(after.content_hash == retained_cells.content_hash and after.water_integer == retained_cells.water_integer,
			"retained native retune preserves exact per-cell uint16 content and total quantity")
		actual = world.get_wave_flow_status()
		require(actual.enabled and actual.substeps == 3 and actual.parameters.gain == 64 and actual.workers_requested == 2,
			"retained native retune installs requested parameters and workers")
		before = world.get_physical_state_hash()
		revision = world.get_revision()
		old_generation = world.get_liquid_policy_session_generation()
		for normalization: String in ["","water-normalize-v1"]:
			var incompatible := retained.duplicate(true)
			for key: String in TUNING: incompatible.erase("workbench_wave_"+key)
			incompatible.workbench_wave_flow = false
			if not normalization.is_empty(): incompatible.normalization = normalization
			args[6] = incompatible
			token = bridge.callv("prepare_liquid_world",args)
			require(token == 0 and str(bridge.get_last_error()).to_lower().contains("wave water overfill"),
				"non-Wave target cannot erase stored overfill, including explicit normalization / "+str(bridge.get_last_error()))
			if token > 0: bridge.discard_liquid_world(world,token)
			require(world.get_physical_state_hash() == before and world.get_revision() == revision \
				and world.get_liquid_policy_session_generation() == old_generation,
				"refused live target conversion preserves complete physical identity and native generation")
		require(world.simulation_tick(),"retained native World remains usable after refused conversion")
	sections.native_validation = failures.size() == start

func liquid_selection_status() -> bool:
	var start := failures.size()
	var spray: RefCounted = panel.water_spray
	var liquids: Control = panel._liquids
	var before := generation()
	var native_policy: Dictionary = host.tower_context.get("liquid_solver_policy",{}).duplicate(true)
	var native: Dictionary = wave().duplicate(true)
	require(native_policy.get("maximum_rule_radius",0) == 2,"initial FreeMass has native radius two")
	liquids.geometry_picker.select(1)
	liquids.geometry_picker.item_selected.emit(1)
	spray.refresh(host.tower_context)
	require(spray._wave_status.text.contains("STAGED") and not spray._wave_status.text.contains("APPLIED") \
		and spray._wave_status.tooltip_text.contains("Rule radius: requested 3; effective 3"),
		"geometry selection is staged against authoritative native radius")
	require(generation() == before and wave() == native and host.tower_context.liquid_solver_policy == native_policy,
		"staged rule geometry preserves the complete native readback and owner")
	if not require(spray._apply_wave(),"radius-three construction requested") or not await installed_after(before,"radius-three Apply"):
		return false
	spray.refresh(host.tower_context)
	require(host.tower_context.liquid_solver_policy.get("maximum_rule_radius",0) == 3 \
		and spray._wave_status.text.contains("APPLIED"),"native radius three is positively installed before APPLIED")
	var tick: int = host.latest_snapshot.tick_index
	require(panel.step_once(),"radius-three World accepts a real native tick")
	await until(func() -> bool: return idle() and int(host.latest_snapshot.tick_index) == tick+1,"radius-three native tick completed")
	before = generation()
	native = wave().duplicate(true)
	native_policy = host.tower_context.liquid_solver_policy.duplicate(true)
	liquids.normalize_water.button_pressed = true
	spray.refresh(host.tower_context)
	require(spray._wave_status.text.contains("STAGED") and not spray._wave_status.text.contains("APPLIED") \
		and spray._wave_status.tooltip_text.contains("Round Water on next Apply"),
		"one-shot Water rounding is pending even when persistent settings match")
	require(generation() == before and wave() == native and host.tower_context.liquid_solver_policy == native_policy,
		"pending one-shot rounding does not impersonate native mutation")
	if not require(spray._apply_wave(),"one-shot normalization requested") or not await installed_after(before,"one-shot normalization Apply"):
		return false
	var normalized: Dictionary = host.tower_context.get("liquid_construction_receipt",{}).get("normalization",{})
	spray.refresh(host.tower_context)
	require(normalized.get("rule","") == "water-normalize-v1" and str(normalized.get("receipt_hash","")).length() == 64,
		"actual native construction receipt records the one-shot normalization")
	require(not liquids.normalize_water.button_pressed and spray._wave_status.text.contains("APPLIED"),
		"one-shot action clears only after acknowledged native installation")
	before = generation()
	liquids.geometry_picker.select(0)
	liquids.geometry_picker.item_selected.emit(0)
	if not require(spray._apply_wave(),"restore radius-two construction requested") or not await installed_after(before,"radius-two restore"):
		return false
	require(host.tower_context.liquid_solver_policy.get("maximum_rule_radius",0) == 2 \
		and host.tower_context.get("liquid_construction_receipt",{}).get("normalization",{}).is_empty(),
		"restored geometry reads back from native without repeating consumed rounding")
	observe("construction_status_geometry_normalization")
	return failures.size() == start

func construction_status() -> bool:
	if not await liquid_selection_status(): return false
	var start := failures.size()
	var spray: RefCounted = panel.water_spray
	var saved: Dictionary = host.workbench_water_options.duplicate(true)
	var saved_signed: bool = spray._inertial_signed_preference
	var native: Dictionary = wave().get("construction_options",{}).duplicate(true)
	var before := generation()
	spray.refresh(host.tower_context)
	require(spray._wave_status.text.contains("APPLIED"),"initial active construction settings match native")
	# All four actual controls share Apply. A pending edit must never be called
	# APPLIED just because the Wave values, policy and worker count still match.
	for item: Array in [["workbench_ballistic","Ballistic Water",spray._ballistic],
		["workbench_inertial_signed","IN signed",spray._signed],
		["workbench_face_release","Face release",spray._face],
		["workbench_fine_cores","Fine cores",spray._fine]]:
		var key: String = item[0]
		var toggle: CheckButton = item[2]
		require(native.get(key) is bool,"authoritative native construction flag exists: "+key)
		var initial: bool = bool(native.get(key,false))
		toggle.button_pressed = not initial
		spray.refresh(host.tower_context)
		require(spray._wave_status.text.contains("STAGED") and not spray._wave_status.text.contains("APPLIED"),
			"unapplied "+key+" is visibly staged")
		require(spray._wave_status.tooltip_text.contains(str(item[1])),"staged difference identifies "+key)
		require(generation() == before and wave().get("construction_options",{}) == native,
			"staging "+key+" preserves native construction and owner")
		toggle.set_pressed_no_signal(initial)
		host.workbench_water_options = saved.duplicate(true)
		spray._inertial_signed_preference = saved_signed
	for invalid_workers: Variant in [float(wave().workers_requested)+0.5,str(wave().workers_requested)]:
		host.workbench_water_options["workbench_worker_threads"] = invalid_workers
		spray.refresh(host.tower_context)
		require(spray._wave_status.text.contains("STAGED") and spray._wave_status.tooltip_text.contains("Pool workers"),
			"invalid worker type cannot impersonate an applied integer request")
		require(generation() == before and wave().get("construction_options",{}) == native,
			"invalid staged worker type leaves the actual World unchanged")
		host.workbench_water_options = saved.duplicate(true)
	# Apply a real ballistic/face World, then distinguish each numeric change
	# from its old native value. Idle face preferences do not configure Wave.
	spray._ballistic.button_pressed = true
	spray._face.button_pressed = true
	if not require(spray._apply_wave(),"ballistic face settings requested") or not await installed_after(before,"ballistic face Apply"):
		return false
	native = wave().get("construction_options",{}).duplicate(true)
	require(native.get("workbench_ballistic",false) and native.get("workbench_face_release",false),
		"ballistic and face flags read back from the replacement World")
	before = generation()
	for spec: Array in spray.FACE_SPINS:
		var key: String = spec[0]
		var initial: int = int(host.workbench_water_options[key])
		require(native.get(key) == initial,"applied native face tuning: "+key)
		spray._fields[key].value = initial+int(spec[4])
		spray.refresh(host.tower_context)
		require(spray._wave_status.text.contains("STAGED") and spray._wave_status.tooltip_text.contains(str(spec[1])),
			"unapplied face tuning is visibly staged: "+key)
		require(generation() == before and wave().get("construction_options",{}) == native,
			"staged face tuning preserves the World: "+key)
		spray._fields[key].value = initial
	var tuned := {"workbench_face_budget":501,"workbench_face_speed":224,
		"workbench_face_period":2,"workbench_face_min_height":7}
	for key: String in tuned: spray._fields[key].value = tuned[key]
	spray._fine.button_pressed = true
	if not require(spray._apply_wave(),"face tuning and fine cores requested") or not await installed_after(before,"face/fine Apply"):
		return false
	native = wave().get("construction_options",{}).duplicate(true)
	for key: String in tuned: require(native.get(key) == tuned[key],"native changed face tuning: "+key)
	require(native.get("workbench_fine_cores",false) and wave().get("scheduling_core_size",0) == 32,
		"fine cores read back as actual native 32-cell geometry")
	var tick: int = host.latest_snapshot.tick_index
	require(panel.step_once(),"configured non-Wave World accepts a real tick")
	await until(func() -> bool: return idle() and int(host.latest_snapshot.tick_index) == tick+1,"configured non-Wave tick completed")
	require(wave().get("construction_options",{}) == native and not host.simulation_worker.has_failed(),
		"native construction readback remains authoritative after real simulation")
	observe("construction_status_ballistic_face")
	# Return to ordinary geometry without promoting inactive face values.
	host.workbench_water_options = saved.duplicate(true)
	for toggle: CheckButton in [spray._ballistic,spray._face,spray._fine,spray._signed]: toggle.set_pressed_no_signal(false)
	spray._inertial_signed_preference = saved_signed
	before = generation()
	if not require(spray._apply_wave(),"restore ordinary construction requested") or not await installed_after(before,"ordinary construction restore"):
		return false
	require(wave().get("scheduling_core_size",0) == 64,"ordinary construction restores native 64-cell cores")
	# Capacity is active only under PressureFlow. A same-law live capacity change
	# still refuses, and a fresh authored construction can explicitly apply it.
	require(spray._stage_solver("pressure_flow_v1","cached"),"stage capacity readback PressureFlow")
	before = generation()
	if not require(spray._apply_wave(),"PressureFlow capacity baseline requested") or not await installed_after(before,"PressureFlow capacity baseline"):
		return false
	native = wave().get("construction_options",{}).duplicate(true)
	require(native.get("pressure_gas_compartment_capacity",0) == 1024,"native default PF capacity")
	spray._pf_c2048.button_pressed = true
	spray.refresh(host.tower_context)
	require(spray._wave_status.text.contains("STAGED") and spray._wave_status.tooltip_text.contains("PF compartment capacity"),
		"unapplied PF capacity is visibly staged")
	before = generation()
	spray._apply_wave()
	await until(idle,"same-law capacity refusal settled")
	spray.refresh(host.tower_context)
	require(generation() == before and wave().get("construction_options",{}) == native \
		and spray._wave_status.text.contains("REFUSED"),"capacity refusal preserves owner and truthful status")
	var fresh: Dictionary = Setup.fresh(panel._liquids.requested_policy,Vector2i(512,512))
	if not require(panel.apply(fresh),"fresh PF capacity construction requested") or not await installed_after(before,"fresh PF capacity construction"):
		return false
	require(wave().get("construction_options",{}).get("pressure_gas_compartment_capacity",0) == 2048,
		"fresh constructor actually applies PF capacity")
	observe("construction_status_pressure_capacity")
	spray._stage_plain_freemass()
	before = generation()
	if not require(spray._apply_wave(),"restore FreeMass after capacity comparison") or not await installed_after(before,"capacity comparison restore"):
		return false
	spray.refresh(host.tower_context)
	require(wave().get("construction_options",{}).get("pressure_gas_compartment_capacity",0) == 1024 \
		and host.workbench_water_options.get("pressure_gas_compartment_capacity",0) == 2048 \
		and spray._wave_status.text.contains("APPLIED"),"inactive PF capacity preference does not falsely mark FreeMass staged")
	host.workbench_water_options = saved
	spray._pf_c2048.set_pressed_no_signal(false)
	spray._inertial_signed_preference = saved_signed
	for spec: Array in spray.FACE_SPINS: spray._fields[spec[0]].set_value_no_signal(int(saved.get(spec[0],spec[5])))
	return failures.size() == start

func activation() -> bool:
	var start := failures.size()
	require(not wave().get("enabled",true),"ordinary Workbench starts with Wave off")
	if not await construction_status(): return false
	var recipe: Dictionary = Setup.fresh(panel._liquids.bridge.default_liquid_policy(),Vector2i(512,512))
	recipe.edits = [[0,220,256,4,Setup.WALL],[0,0,4,220,Setup.WALL],[252,0,4,220,Setup.WALL],
		[4,100,96,120,Setup.WATER],[100,180,152,40,Setup.WATER]]
	var before := generation()
	if not require(panel.apply(recipe),"ordinary authored Water start requested / "+str(panel.message)) or \
		not await installed_after(before,"authored Water start"): return false
	# Exercise the actual visible dropdown instead of the hidden legacy toggle.
	panel.water_spray._studio_solver.select(1)
	panel.water_spray._studio_solver.item_selected.emit(1)
	require(host.workbench_water_options.get("workbench_wave_flow",false),
		"visible Water-law picker stages Wave Flow")
	require(not wave().get("enabled",true),
		"Wave remains native OFF until Apply is acknowledged")
	for key: String in TUNING:
		var field: SpinBox = panel.water_spray._wave_fields.get("workbench_wave_"+key)
		if not require(field != null,"tuning field exists "+key): return false
		if key != "gain": field.value = int(TUNING[key])
	main_worker_request(4)
	panel.water_lab.open()
	panel.water_lab.select_tab(1)
	for frame: int in 3: await process_frame
	if not await type_spin_text(panel.water_spray._wave_fields.workbench_wave_gain,str(TUNING.gain)): return false
	require(int(host.workbench_water_options.workbench_wave_gain) != int(TUNING.gain),
		"typing alone has not staged the new gain before the Apply click")
	before = generation()
	if not await click_lab_button("Apply solver / tuning"): return false
	if not await installed_after(before,"Wave Apply"): return false
	require(int(wave().get("parameters",{}).get("gain",-1)) == int(TUNING.gain),
		"Water Lab Apply commits focused numeric text before native construction")
	# Equipment moved into the same child Window and uses its own action helper.
	# A real click must commit pending supply before constructing the device.
	panel.water_lab.select_tab(3)
	panel._position[0].value = 300
	panel._position[1].value = 40
	for frame: int in 2: await process_frame
	if not await type_spin_text(panel.equipment._supply,"250"): return false
	if not await click_lab_button("Nozzle at X/Y"): return false
	require(int(panel.applied.get("equipment",{}).get("supply",-1)) == 250,
		"Equipment action consumes focused supply text in Water Lab")
	if not await until(func() -> bool:
		return int(host.tower_context.get("workbench_equipment",{}).get("serial",-1)) == panel.equipment.serial,
		"native owner acknowledges equipment built from typed supply"): return false
	require(int(host.tower_context.workbench_equipment.get("pipe",{}).get("supplied",-1)) == 250*255,
		"native equipment supply matches the committed typed value")
	require(panel.equipment.remove_all(),"remove numeric-input test nozzle")
	await until(func() -> bool:
		return int(host.tower_context.get("workbench_equipment",{}).get("serial",-1)) == panel.equipment.serial,
		"numeric-input fixture equipment removed")
	panel.water_lab.window.hide()
	sections.activation = require(wave().get("enabled",false),"Workbench activates native Wave") and failures.size() == start
	start = failures.size()
	matches(TUNING,"first Apply")
	var accepted_rounds: int = int(TUNING.substeps)
	var active: Dictionary = wave().duplicate(true)
	for malformed: Variant in [{"unexpected":2},[2],"2",2.5]:
		host.workbench_water_options.workbench_wave_substeps = malformed
		panel.water_spray.refresh(host.tower_context)
		require(panel.water_spray._wave_status.text.contains("STAGED") \
			and panel.water_spray._wave_status.text.contains("invalid rounds") \
			and not panel.water_spray._wave_status.text.contains("APPLIED"),
			"malformed rounds cannot abort refresh and retain a stale APPLIED label: "+str(malformed))
		require(wave() == active,"staging malformed rounds leaves authoritative native state unchanged")
	host.workbench_water_options.workbench_wave_substeps = accepted_rounds
	panel.water_spray.refresh(host.tower_context)
	sections.parameters = failures.size() == start
	start = failures.size()
	require(int(wave().get("workers_requested",0)) == 4,"Workbench requested workers applied natively")
	await step_wave(6,"initial Wave")
	require(int(wave().get("workers_observed",0)) >= 1 and int(wave().get("workers_observed",0)) <= 4,
		"native worker participation is bounded by requested team")
	sections.workers_substeps = failures.size() == start
	return sections.activation and sections.parameters and sections.workers_substeps

func main_worker_request(count: int) -> void:
	var field: Variant = panel.water_spray.get("_worker_threads")
	if field != null: field.value = count
	else: host.workbench_water_options["workbench_worker_threads"] = count

func runtime_and_lifecycle() -> void:
	var start := failures.size()
	var tuned := TUNING.duplicate()
	tuned.gain = 64
	tuned.substeps = 3
	panel.water_spray._wave_fields.workbench_wave_gain.value = 64
	panel.water_spray._wave_fields.workbench_wave_substeps.value = 3
	main_worker_request(1)
	require(int(wave().parameters.gain) == 48 and int(wave().substeps) == 2,"staged edits do not impersonate native application")
	var before := generation()
	var quantity: String = wave().water_quantity
	panel.water_spray._apply_wave()
	if not await installed_after(before,"runtime Wave retune"): return
	require(str(wave().water_quantity) == quantity,"retuning after real Wave overfill retains the exact full native quantity")
	matches(tuned,"runtime retune")
	require(int(wave().workers_requested) == 1,"runtime worker change is authoritative")
	await step_wave(4,"retuned Wave")
	var defaults := {}
	if require(panel.water_spray.has_method(&"_reset_wave_defaults"),"explicit Reset tuning action exists"):
		panel.water_spray._reset_wave_defaults()
		for spec: Array in panel.water_spray.WAVE_SPINS:
			defaults[str(spec[0]).trim_prefix("workbench_wave_")] = int(spec[5])
			require(host.workbench_water_options.get(str(spec[0])) == int(spec[5]),"Reset stages default "+str(spec[0]))
		matches(tuned,"staged Reset preserves running law")
		before = generation()
		panel.water_spray._apply_wave()
		if not await installed_after(before,"Apply reset tuning"): return
		matches(defaults,"applied Reset")
		for key: String in tuned: panel.water_spray._wave_fields["workbench_wave_"+key].value = int(tuned[key])
		before = generation()
		panel.water_spray._apply_wave()
		if not await installed_after(before,"restore experimental tuning"): return
		matches(tuned,"experimental tuning restored")
	sections.runtime_apply = failures.size() == start
	start = failures.size()
	var tick := int(wave().ticks)
	var rounds := int(wave().rounds)
	for i: int in 5: await process_frame
	require(host.paused and int(wave().ticks) == tick and int(wave().rounds) == rounds,"pause freezes native Wave counters")
	require(panel.toggle_pause(),"resume requested")
	await until(func() -> bool: return int(wave().get("ticks",0)) >= tick+5,"resume executes Wave ticks")
	require(panel.toggle_pause(),"pause requested")
	await until(idle,"pause owner settled")
	native_ticks += maxi(0,int(wave().ticks)-tick)
	require(int(wave().rounds)-rounds == (int(wave().ticks)-tick)*3,"resume uses configured substeps")
	matches(tuned,"pause/resume")
	observe("pause_resume")
	sections.pause_resume = failures.size() == start
	start = failures.size()
	# Staging an invalid alternative must not leak into an unrelated rebuild.
	# Restore and New canvas use the accepted constructor settings until Apply.
	var staged: Dictionary = host.workbench_water_options.duplicate(true)
	host.workbench_water_options.workbench_wave_gain = 1000000
	host.workbench_water_options.workbench_wave_flow = false
	before = generation()
	if not require(panel.restore_start(),"Restore start requested") or not await installed_after(before,"Restore start"): return
	matches(tuned,"restored World")
	require(int(wave().workers_requested) == 1,"Restore start retains requested worker team")
	require(host.workbench_water_options.get("workbench_wave_gain") == 1000000 \
		and not host.workbench_water_options.get("workbench_wave_flow",true),"Restore preserves pending edits separately from accepted settings")
	await step_wave(2,"restored Wave")
	sections.regeneration = failures.size() == start
	start = failures.size()
	before = generation()
	for axis: int in 2: panel._extent[axis].value = 640
	if not require(panel.new_canvas(),"new canvas requested") or not await installed_after(before,"new canvas"): return
	matches(tuned,"new canvas")
	require(wave().extent == Vector2i(640,640),"new canvas is actual native extent")
	# Inactive Wave tuning does not configure another law. Re-select Wave before
	# requesting the malformed pending gain to test its own active validation.
	host.workbench_water_options.workbench_wave_flow = true
	before = generation()
	var queued: bool = panel.apply_liquids()
	if queued: await until(idle,"explicit invalid staged Apply settled")
	require(not queued or not str(host.microscenario_error).is_empty(),"explicit Apply refuses staged invalid settings")
	require(generation() == before and wave().enabled and int(wave().parameters.gain) == 64,
		"staged refusal retains the newly generated accepted World")
	host.workbench_water_options = staged
	sections.scenario_change = failures.size() == start

func invalid_recovery() -> void:
	var start := failures.size()
	# Paused copies: refusals must preserve the active generation and material
	# projection, the installed recipe and native applied settings/counters.
	var saved: Dictionary = host.workbench_water_options.duplicate(true)
	var active: Dictionary = wave().duplicate(true)
	var image: PackedByteArray = host.image.get_data()
	var applied: Dictionary = panel.applied.duplicate(true)
	var before := generation()
	for bad: Dictionary in [{"workbench_wave_substeps":0},{"workbench_wave_substeps":{}},
		{"workbench_wave_substeps":[3]},{"workbench_wave_active_rows":33},
		{"workbench_wave_stiffness":1},{"workbench_wave_gain":1.5},{"workbench_wave_gain":"64"},
		{"workbench_wave_flow":"yes"},{"workbench_worker_threads":33}]:
		host.workbench_water_options = saved.duplicate(true)
		host.workbench_water_options.merge(bad,true)
		var queued: bool = panel.apply_liquids()
		if queued: await until(idle,"invalid Apply settled "+str(bad))
		require(not queued or not str(host.microscenario_error).is_empty(),"invalid settings visibly refused "+str(bad))
		require(generation() == before and panel.applied == applied and host.image.get_data() == image,
			"invalid settings preserve owner and cells "+str(bad))
		require(wave() == active,"invalid settings preserve authoritative Wave readback "+str(bad))
		require(not host.simulation_worker.has_failed(),"invalid settings leave owner usable")
	host.workbench_water_options = saved
	panel.water_spray._apply_wave()
	if await installed_after(before,"recovery Apply"):
		require(wave().enabled and int(wave().substeps) == 3,"valid request recovers after refusal")
	sections.invalid_recovery = failures.size() == start

func solver_switch() -> void:
	var start := failures.size()
	var saved: Dictionary = host.workbench_water_options.duplicate(true)
	# Produce real Wave uint16 overfill. Legacy Water domains cannot always carry
	# that volume in the same cells. Refuse the live switch, preserve it exactly,
	# then prove ordinary authored-scene replacement offers a useful comparison.
	var recipe: Dictionary = Setup.fresh(panel._liquids.bridge.default_liquid_policy(),Vector2i(512,512))
	recipe.edits = [[0,220,256,4,Setup.WALL],[0,0,4,220,Setup.WALL],[252,0,4,220,Setup.WALL],
		[4,100,96,120,Setup.WATER],[100,180,152,40,Setup.WATER]]
	var before := generation()
	if not require(panel.apply(recipe),"moving Wave switch fixture requested") or \
		not await installed_after(before,"moving Wave switch fixture"): return
	if not await step_wave(6,"pre-switch overfill"): return
	var retained: Dictionary = wave().duplicate(true)
	var cells: PackedByteArray = host.image.get_data()
	before = generation()
	panel.water_spray._stage_plain_freemass()
	panel.water_spray._apply_wave()
	if not await until(idle,"live Wave-to-FreeMass refusal settled"): return
	var refusal := str(host.microscenario_error).to_lower()
	require(refusal.contains("wave") and refusal.contains("overfill"),"unrepresentable live Wave switch explains its overfill refusal")
	require(generation() == before and wave() == retained and host.image.get_data() == cells,
		"refused Wave switch preserves native configuration, counters, cells and exact quantity")
	observe("switch_refused_fullmass")
	# Fresh authored Water is full-cell and representable by every comparison
	# family. Loading a scene explicitly applies the staged target selection.
	before = generation()
	if not require(panel.load_water_comparison("interference"),"same ordinary scene with staged FreeMass requested") or \
		not await installed_after(before,"fresh FreeMass comparison"): return
	require(not wave().enabled,"fresh scene actually switches off Wave")
	for family: String in ["pressure_flow_v1","freemass_v1","inertial_cellular_v1","cellular_yield_v1"]:
		var variant := "cached" if family == "pressure_flow_v1" else "reference"
		if family == "freemass_v1": panel.water_spray._stage_plain_freemass()
		elif not require(panel.water_spray._stage_solver(family,variant),"stage comparison "+family): continue
		before = generation()
		panel.water_spray._apply_wave()
		if not await installed_after(before,"comparison "+family): continue
		require(not wave().get("enabled",true),family+" has no Wave overlay")
		var water: Dictionary = {}
		for row: Dictionary in host.tower_context.get("liquid_solver_policy",{}).get("assignments",[]):
			if int(row.material) == Setup.WATER: water = row
		require(water.get("applied_family","") == family and water.get("applied_variant","") == variant,
			"native law readback "+family)
		if family == "inertial_cellular_v1":
			# The ordinary Apply path raises the selected radius to the policy's
			# minimum. A picker-only change below that minimum is an explicit no-op.
			before = generation()
			panel._liquids.geometry_picker.select(0)
			panel._liquids.geometry_picker.item_selected.emit(0)
			panel.water_spray.refresh(host.tower_context)
			require(panel.water_spray._wave_status.text.contains("APPLIED") \
				and panel.water_spray._wave_status.tooltip_text.contains("Rule radius: requested 2; effective 3") \
				and host.tower_context.liquid_solver_policy.get("maximum_rule_radius",0) == 3 \
				and generation() == before,"status compares effective policy-minimum geometry and exposes the raw request")
			panel._liquids.geometry_picker.select(1)
			panel._liquids.geometry_picker.item_selected.emit(1)
		for key: String in TUNING:
			require(host.workbench_water_options.get("workbench_wave_"+key) == saved.get("workbench_wave_"+key),
				family+" does not overwrite staged Wave "+key)
	await solver_preference_cycle()
	await mixed_policy_selection_cycle()
	panel.water_spray._wave.button_pressed = true
	before = generation()
	panel.water_spray._apply_wave()
	if await installed_after(before,"return to Wave"):
		require(wave().enabled and int(wave().parameters.gain) == 64 and int(wave().substeps) == 3,
			"return to Wave restores its independent tuning")
	sections.solver_switch = failures.size() == start

func preference_apply(family: String, signed_vertical: bool, label: String) -> bool:
	var before := generation()
	if not require(panel.water_spray._apply_wave(),label+" Apply admitted") or not await installed_after(before,label): return false
	var is_wave := family == "wave_flow_v1"
	var carrier := "freemass_v1" if is_wave else family
	var spray: Dictionary = host.tower_context.get("water_spray",{})
	require(wave().enabled == is_wave and native_water_family() == carrier,label+" actual native law")
	require(spray.has("inertial_signed") and spray.inertial_signed == signed_vertical,
		label+" actual native signed-vertical flag")
	var receipt: Dictionary = host.tower_context.get("liquid_construction_receipt",{})
	require(receipt.get("kind","") == "applied_run" and str(receipt.get("receipt_hash","")).length() == 64 \
		and receipt.get("wave_flow",{}).get("enabled",not is_wave) == is_wave,label+" committed native constructor receipt")
	observe(label)
	return true

func solver_preference_cycle() -> void:
	# A signed Inertial preference must survive a comparison visit without being
	# passed to incompatible FreeMass/Pressure/Wave constructors. All readbacks
	# below come from actual replacement Worlds, not cached checkbox state.
	if not require(panel.water_spray._stage_solver("inertial_cellular_v1","reference"),"stage signed Inertial comparison"): return
	panel.water_spray._signed.button_pressed = true
	if not await preference_apply("inertial_cellular_v1",true,"inertial_signed_on"): return
	panel.water_spray._wave.button_pressed = true
	if not await preference_apply("wave_flow_v1",false,"signed_preference_wave"): return
	for family: String in ["pressure_flow_v1","freemass_v1","inertial_cellular_v1"]:
		var variant := "cached" if family == "pressure_flow_v1" else "reference"
		if not require(panel.water_spray._stage_solver(family,variant),"stage signed-preference target "+family): return
		if not await preference_apply(family,family == "inertial_cellular_v1","signed_preference_"+family): return
	panel.water_spray._signed.button_pressed = false
	if not await preference_apply("inertial_cellular_v1",false,"inertial_signed_explicit_off"): return
	panel.water_spray._wave.button_pressed = true
	if not await preference_apply("wave_flow_v1",false,"unsigned_preference_wave"): return
	if not require(panel.water_spray._stage_solver("pressure_flow_v1","cached"),"stage Pressure after explicit signed off"): return
	if not await preference_apply("pressure_flow_v1",false,"unsigned_preference_pressure"): return
	if not require(panel.water_spray._stage_solver("inertial_cellular_v1","reference"),"return to explicitly unsigned Inertial"): return
	await preference_apply("inertial_cellular_v1",false,"inertial_explicit_off_retained")

func select_brine(family: String) -> bool:
	var liquids: Control = panel._liquids
	liquids.material_picker.select(liquids.material_picker.get_item_index(24))
	liquids._refresh_choices()
	for index: int in liquids._choices.size():
		var choice: Dictionary = liquids._choices[index]
		if choice.get("accepted",false) and choice.get("family","") == family:
			liquids.family_picker.select(index)
			liquids.family_picker.item_selected.emit(index)
			return true
	return require(false,"Advanced policy exposes Brine "+family)

func mixed_policy_selection_cycle() -> void:
	# A Water-law comparison must retain other accepted liquid assignments.
	# Start with a cached Water-only PF option, then edit shared IN while Wave
	# is active. Every outcome below is read from a positively replaced World.
	var spray: RefCounted = panel.water_spray
	if not require(spray._stage_solver("pressure_flow_v1","cached"),"stage remembered gas-off PressureFlow"): return
	spray._pf_gas.button_pressed = false
	if not await preference_apply("pressure_flow_v1",false,"mixed_policy_start_pf"): return
	require(not host.tower_context.liquid_solver_policy.family_parameters.pressure_flow_v1.gas_enabled,
		"initial remembered PressureFlow has gas disabled")
	panel.water_lab.open()
	for target: Array in [["pressure_flow_v1","cached",9],["freemass_v1","reference",11],["inertial_cellular_v1","reference",7]]:
		spray._wave.button_pressed = true
		if not await preference_apply("wave_flow_v1",false,"mixed_policy_enter_wave_"+target[0]): return
		panel.water_lab.select_tab(4)
		if not select_brine("inertial_cellular_v1"): return
		for frame: int in 2: await process_frame
		if not await type_spin_text(panel._liquids.damping_numerator,str(target[2])): return
		var before := generation()
		if not await click_lab_button("Apply liquid selection"): return
		if not await installed_after(before,"apply edited Brine while Wave is active"): return
		var actual: Dictionary = host.tower_context.liquid_solver_policy
		require(wave().enabled and policy_family(actual,24) == "inertial_cellular_v1" \
			and actual.family_parameters.inertial_cellular_v1.damping_numerator == int(target[2]),
			"Advanced Apply consumes typed damping and installs Brine IN under Wave")
		if not require(spray._stage_solver(str(target[0]),str(target[1])),"select Water alone: "+target[0]): return
		if not await preference_apply(str(target[0]),false,"mixed_policy_leave_wave_"+target[0]): return
		actual = host.tower_context.liquid_solver_policy
		require(policy_family(actual,24) == "inertial_cellular_v1" \
			and actual.family_parameters.inertial_cellular_v1.damping_numerator == int(target[2]),
			"Water selection retains accepted Brine and latest shared damping: "+target[0])
		if target[0] == "pressure_flow_v1":
			require(not actual.family_parameters.pressure_flow_v1.gas_enabled,
				"return to PressureFlow restores its dormant gas-off setting")
	# Exercise the legacy Wave-off toggle as well as explicit law selection.
	spray._wave.button_pressed = true
	if not await preference_apply("wave_flow_v1",false,"mixed_policy_toggle_enter"): return
	panel.water_lab.select_tab(4)
	if not await type_spin_text(panel._liquids.damping_numerator,"10"): return
	var before := generation()
	if not await click_lab_button("Apply liquid selection"): return
	if not await installed_after(before,"accept latest shared parameters before Wave off"): return
	spray._wave.button_pressed = false
	if not await preference_apply("inertial_cellular_v1",false,"mixed_policy_toggle_restore"): return
	var actual: Dictionary = host.tower_context.liquid_solver_policy
	require(policy_family(actual,24) == "inertial_cellular_v1" \
		and actual.family_parameters.inertial_cellular_v1.damping_numerator == 10,
		"Wave toggle restores Water while retaining latest accepted shared-family parameters")
	if not select_brine("cellular_yield_v1"): return
	before = generation()
	if not require(spray._apply_wave(),"restore default Brine after mixed-policy test"): return
	await installed_after(before,"mixed-policy fixture cleanup")
	panel.water_lab.window.hide()

func comparison_scenes() -> void:
	var start := failures.size()
	if not require(panel.has_method(&"load_water_comparison"),"comparison scenes belong to ordinary Workbench"): return
	for scene_id: String in ["interference","impacts","sparse","cascade"]:
		var before := generation()
		if not require(panel.load_water_comparison(scene_id),"load interactive "+scene_id): continue
		if not await installed_after(before,"interactive "+scene_id): continue
		require(wave().get("enabled",false),scene_id+" retains active Wave selection")
		require(int(wave().get("water_quantity","0")) > 0,scene_id+" has native Water")
		if scene_id == "cascade": require(wave().extent == Vector2i(2048,1024),"large scene native extent")
		await step_wave(2,"scene_"+scene_id)
	sections.comparison_scenes = failures.size() == start

func failed_owner_recovery() -> void:
	var start := failures.size()
	# The constructor consumes a deliberately tiny existing diagnostic capacity;
	# restore the setting before either host enters the tree. The failure itself
	# is a real native tick, and recovery creates an ordinary unmodified Main.
	host.queue_free()
	await process_frame
	await process_frame
	const CAPACITY := "cybersand/native_active_core_capacity"
	var previous: Variant = ProjectSettings.get_setting(CAPACITY,null)
	ProjectSettings.set_setting(CAPACITY,1)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	ProjectSettings.set_setting(CAPACITY,previous)
	root.add_child(host)
	current_scene = host
	panel = host.shared_workbench
	if not await until(idle,"capacity-one Workbench installed"): return
	panel.water_spray._wave.button_pressed = true
	for key: String in TUNING: panel.water_spray._wave_fields["workbench_wave_"+key].value = TUNING[key]
	main_worker_request(4)
	var recipe: Dictionary = Setup.fresh(panel._liquids.bridge.default_liquid_policy(),Vector2i(512,512))
	recipe.edits = [[20,20,8,8,Setup.SAND],[160,20,8,8,Setup.SAND],[0,240,256,4,Setup.WALL],
		[0,0,4,240,Setup.WALL],[252,0,4,240,Setup.WALL],[4,180,248,60,Setup.WATER]]
	var before := generation()
	if not require(panel.apply(recipe),"capacity fixture with Wave admitted") or \
		not await installed_after(before,"capacity fixture"): return
	matches(TUNING,"accepted configuration before native failure")
	var old_id := host.get_instance_id()
	var old_worker: RefCounted = host.simulation_worker
	if not require(panel.step_once(),"real native failing tick requested"): return
	if not await until(func() -> bool: return old_worker.has_failed() and host.latest_snapshot.simulation_failed,
		"actual native capacity fault is published",true): return
	require(str(host.latest_snapshot.last_tick_error).contains("active scheduling-core capacity exhausted"),
		"native fault is the deliberate capacity failure")
	panel.water_spray.refresh(host.tower_context)
	require(panel.water_spray._wave_status.text.contains("NATIVE WORLD FAILED") \
		and panel.water_spray._wave_status.text.contains("last completed native readback"),
		"failed owner status identifies the frozen last-completed readback instead of reporting APPLIED")
	# An unsubmitted malformed choice must not become the recovered law.
	host.workbench_water_options.workbench_wave_gain = 1000000
	host.workbench_water_options.workbench_wave_flow = false
	if not require(panel.restore_start(),"failed owner Restore start queues scene replacement"): return
	if not await until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id,
		"whole Main replaced after native failure",true): return
	host = current_scene
	panel = host.shared_workbench
	if not await until(idle,"fresh recovered Workbench installed"): return
	require(not old_worker._thread.is_started(),"failed native worker was joined")
	require(host.simulation_worker != old_worker and not host.simulation_worker.has_failed() and host.paused,
		"recovery owns a distinct healthy paused worker")
	matches(TUNING,"recovered accepted Wave configuration")
	require(int(wave().get("workers_requested",0)) == 4,"recovery retains accepted worker team")
	require(int(host.workbench_water_options.get("workbench_wave_gain",0)) == 48 \
		and host.workbench_water_options.get("workbench_wave_flow",false),"recovery discards unsubmitted invalid settings")
	await step_wave(3,"recovered Wave")
	sections.failure_recovery = failures.size() == start

func run() -> void:
	native_validation()
	root.content_scale_size = Vector2i.ZERO
	root.gui_embed_subwindows = true
	root.size = Vector2i(1600,900)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	if "--workbench" not in OS.get_cmdline_user_args(): current_scene.launch("shared_workbench")
	await scene_changed
	host = current_scene
	panel = host.shared_workbench
	if await until(idle,"ordinary Workbench installed"):
		water_lab_ui()
		if await activation():
			await runtime_and_lifecycle()
			await invalid_recovery()
			await solver_switch()
			await comparison_scenes()
			await failed_owner_recovery()
	for section: String in sections: require(bool(sections[section]),"required section completed: "+section)
	var result := {"schema":"workbench-wave-631-v1","assertions":checks,"failures":failures.size(),
		"failure_details":failures,"sections":sections,"real_workbench":true,"native_ticks":native_ticks,
		"observations":observations,"platform":OS.get_name(),"godot":Engine.get_version_info().string,
		"elapsed_ms":(Time.get_ticks_usec()-started_usec)/1000.0}
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	print("WORKBENCH_WAVE_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
