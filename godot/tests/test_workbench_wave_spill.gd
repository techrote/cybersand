extends SceneTree

# WAVE-WATERWALL-001: native admission of the Workbench Waterwall spill options
# and the Water Lab controls that stage them, through the ordinary Shared
# Workbench owner. A completed request counts only with a new native World
# generation and matching authoritative readback.
const Contract = preload("res://tests/support/../../scripts/microscenario_contract.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const DAM = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var host: Control
var panel: Control
var checks := 0
var failures: Array[String] = []
var sections := {"native_admission":false,"native_conservation":false,"lab_controls":false,"workbench_apply":false}

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("WORKBENCH_WAVE_SPILL: " + detail)
	return ok

func idle() -> bool:
	return panel != null and not panel.applied.is_empty() and not panel.busy() \
		and host.pending_microscenario_apply.is_empty()

func generation() -> int:
	return int(host.latest_snapshot.render_world_generation) if host.latest_snapshot != null else -1

func wave() -> Dictionary:
	return host.tower_context.get("wave_flow",{})

func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return require(true,label)
		if is_instance_valid(host) and host.simulation_worker.has_failed(): break
		await process_frame
	return require(false,label+" / "+(str(host.microscenario_error) if is_instance_valid(host) else "no host"))

func native_admission() -> void:
	var start := failures.size()
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var checked: Dictionary = Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var base := {"workbench_extent":Vector2i(256,256),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),"geometry":PackedFloat64Array(),"bodies":[]},
		"region":PackedInt32Array([0,0,256,256]),"intent":"exploratory","definition_hash":checked.hash,
		"initial_bodies":PackedFloat32Array(),"workbench_wave_flow":true,"workbench_worker_threads":4}
	# A raised open-sided reservoir standing on a ledge: an exposed face.
	var cells := PackedInt32Array([0,220,256,4,58,0,0,4,220,58,252,0,4,220,58,
		4,120,120,4,58,4,40,90,80,3])
	var args := [world,cells,checked.transport.packed,PackedInt32Array(checked.definition.water_semantics),
		PackedInt32Array(),bridge.default_liquid_policy(),base]
	var hybrid := base.duplicate(true)
	hybrid.merge({"workbench_wave_spill":true,"workbench_wave_spill_parcels":true,"workbench_wave_spill_fall":4,
		"workbench_wave_spill_draw":96,"workbench_wave_spill_launch_speed":320,"workbench_wave_spill_launch_budget":128},true)
	args[6] = hybrid
	var token: int = bridge.callv("prepare_liquid_world",args)
	if not require(token > 0 and bridge.commit_liquid_world(world,token),"native admits Wave with Waterwall spill / "+str(bridge.get_last_error())):
		return
	var status: Dictionary = world.get_wave_flow_status()
	var spill: Dictionary = status.get("spill",{})
	require(status.enabled and spill.get("enabled") == true and spill.get("parcels") == true,"native spill and parcel readback")
	for key: String in ["fall","draw","launch_speed","launch_budget"]:
		require(int(spill.get(key,-1)) == int(hybrid["workbench_wave_spill_"+key]),"native spill readback "+key)
	require(status.construction_options.get("workbench_ballistic") == false,
		"the parcel pool owned by spill is not reported as the generic Ballistic Water request")
	var before: String = world.get_physical_state_hash()
	var revision: int = world.get_revision()
	var old_generation: int = world.get_liquid_policy_session_generation()
	var plain := base.duplicate(true)
	plain.erase("workbench_wave_flow")
	for bad: Dictionary in [
			{"workbench_wave_spill":"yes"},{"workbench_wave_spill_parcels":1},
			{"workbench_wave_spill_fall":0},{"workbench_wave_spill_fall":9},{"workbench_wave_spill_draw":128},
			{"workbench_wave_spill_launch_speed":513},{"workbench_wave_spill_launch_budget":4097},
			{"workbench_wave_spill_fall":2.5},{"workbench_ballistic":true},{"workbench_face_release":true,"workbench_ballistic":true}]:
		var candidate := hybrid.duplicate(true)
		candidate.merge(bad,true)
		args[6] = candidate
		token = bridge.callv("prepare_liquid_world",args)
		require(token == 0 and not str(bridge.get_last_error()).is_empty(),"invalid spill request refused "+str(bad))
		if token > 0: bridge.discard_liquid_world(world,token)
		require(world.get_physical_state_hash() == before and world.get_revision() == revision \
			and world.get_liquid_policy_session_generation() == old_generation,"spill refusal is atomic "+str(bad))
	for bad: Dictionary in [{"workbench_wave_spill_parcels":true},{"workbench_wave_spill_fall":3}]:
		var candidate := base.duplicate(true)
		candidate.merge(bad,true)
		args[6] = candidate
		token = bridge.callv("prepare_liquid_world",args)
		require(token == 0,"spill tuning or parcels without Waterwall spill refused "+str(bad))
		if token > 0: bridge.discard_liquid_world(world,token)
	var without_wave := plain.duplicate(true)
	without_wave.workbench_wave_spill = true
	args[6] = without_wave
	token = bridge.callv("prepare_liquid_world",args)
	require(token == 0,"Waterwall spill without Wave Flow refused")
	if token > 0: bridge.discard_liquid_world(world,token)
	sections.native_admission = failures.size() == start

	# Conservation and worker parity on the committed hybrid World.
	start = failures.size()
	var single: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var one := hybrid.duplicate(true)
	one.workbench_worker_threads = 1
	args[0] = single
	args[6] = one
	token = bridge.callv("prepare_liquid_world",args)
	if require(token > 0 and bridge.commit_liquid_world(single,token),"one-worker hybrid admitted"):
		var quantity: String = world.get_wave_flow_status().water_quantity
		for tick: int in 160:
			require(world.simulation_tick() and single.simulation_tick(),"hybrid Worlds tick")
		var a: Dictionary = world.get_wave_flow_status()
		var b: Dictionary = single.get_wave_flow_status()
		require(str(a.water_quantity) == quantity and str(b.water_quantity) == quantity,
			"grid plus in-flight Water quantity is exactly conserved")
		require(int(a.spill.launched_parcels) > 0 and int(a.spill.deposited_units) > 0,"exposed face launched and landed parcels")
		require(world.get_physical_state_hash() == single.get_physical_state_hash(),"hybrid spill is identical at workers 1/4")
	sections.native_conservation = failures.size() == start

func lab_controls() -> void:
	var start := failures.size()
	var spray: RefCounted = panel.water_spray
	var lab: RefCounted = panel.water_lab
	require(lab != null and lab.pages["wave"].is_ancestor_of(spray._spill_toggles["workbench_wave_spill"]),
		"Waterwall spill switch lives in the Water Lab Wave tab, not the toolbar")
	require(lab.pages["wave"].is_ancestor_of(spray._spill_status),"spill native status is on the Wave tab")
	require(spray._spill_fields.size() == 4,"four meaningful spill parameters")
	spray._set_spill("workbench_wave_spill_parcels",true)
	require(host.workbench_water_options.get("workbench_wave_spill") == true,"ballistic release stages Waterwall spill")
	spray._set_spill("workbench_wave_spill",false)
	require(host.workbench_water_options.get("workbench_wave_spill_parcels") == false,"turning spill off also drops ballistic release")
	sections.lab_controls = failures.size() == start

func workbench_apply() -> void:
	var start := failures.size()
	var spray: RefCounted = panel.water_spray
	spray._set_wave(true)
	spray._set_spill("workbench_wave_spill_parcels",true)
	var before := generation()
	if not require(spray._apply_wave(),"Apply with Waterwall spill requested"): return
	if not await until(func() -> bool: return idle() and generation() > before,"Waterwall spill installed"): return
	require(str(host.microscenario_error).is_empty(),"no refusal / "+str(host.microscenario_error))
	var spill: Dictionary = wave().get("spill",{})
	require(wave().get("enabled") == true and spill.get("enabled") == true and spill.get("parcels") == true,
		"Workbench Apply installs Wave with Waterwall spill and ballistic release")
	spray.refresh(host.tower_context)
	require(spray._wave_status.text.contains("APPLIED"),"requested spill matches native readback / "+spray._wave_status.text)
	require(spray._spill_status.text.contains("Waterwall spill ON"),"spill status reports native activation")
	# The straightforward comparison: spill off is original Wave Flow.
	spray._set_spill("workbench_wave_spill",false)
	spray.refresh(host.tower_context)
	require(spray._wave_status.text.contains("STAGED"),"staged spill-off is not mistaken for native state")
	before = generation()
	spray._apply_wave()
	if not await until(func() -> bool: return idle() and generation() > before,"original Wave reinstalled"): return
	spill = wave().get("spill",{})
	require(wave().get("enabled") == true and spill.get("enabled") == false and spill.get("parcels") == false,
		"spill off restores original Wave Flow")
	spray.refresh(host.tower_context)
	require(spray._spill_status.text.contains("OFF"),"spill status shows original Wave")
	# Leaving Wave never carries the spill request into another law.
	spray._set_spill("workbench_wave_spill",true)
	spray._set_wave(false)
	before = generation()
	spray._apply_wave()
	if not await until(func() -> bool: return idle() and generation() > before,"non-Wave law installed"): return
	require(str(host.microscenario_error).is_empty() and wave().get("enabled") == false \
		and not bool(wave().get("spill",{}).get("enabled",true)),"a staged spill request is not sent to a non-Wave law")
	sections.workbench_apply = failures.size() == start

func run() -> void:
	native_admission()
	root.size = Vector2i(1600,900)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	host = current_scene
	panel = host.shared_workbench
	if await until(idle,"ordinary Workbench installed"):
		lab_controls()
		await workbench_apply()
	for section: String in sections: require(bool(sections[section]),"required section completed: "+section)
	print("WORKBENCH_WAVE_SPILL ",JSON.stringify({"checks":checks,"failures":failures,"sections":sections}))
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	quit(int(not failures.is_empty()))
