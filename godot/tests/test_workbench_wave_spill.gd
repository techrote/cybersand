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
var sections := {"native_admission":false,"native_conservation":false,"native_generic_ballistic":false,
	"native_body_push_reaction":false,"lab_controls":false,"workbench_apply":false,"workbench_generic_ballistic":false}

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
		"workbench_wave_spill_draw":96,"workbench_wave_spill_launch_speed":320,"workbench_wave_spill_launch_budget":128,
		"workbench_wave_spill_blobs":1,"workbench_wave_spill_stream_share":32,"workbench_wave_spill_stream_draw":48},true)
	args[6] = hybrid
	var token: int = bridge.callv("prepare_liquid_world",args)
	if not require(token > 0 and bridge.commit_liquid_world(world,token),"native admits Wave with Waterwall spill / "+str(bridge.get_last_error())):
		return
	var status: Dictionary = world.get_wave_flow_status()
	var spill: Dictionary = status.get("spill",{})
	require(status.enabled and spill.get("enabled") == true and spill.get("parcels") == true,"native spill and parcel readback")
	for key: String in ["fall","draw","launch_speed","launch_budget","blobs","stream_share","stream_draw"]:
		require(int(spill.get(key,-1)) == int(hybrid["workbench_wave_spill_"+key]),"native spill readback "+key)
	require(status.construction_options.get("workbench_ballistic") == true,
		"Ballistic release throws through the Ballistic Water parcel pool and reports it")
	var before: String = world.get_physical_state_hash()
	var revision: int = world.get_revision()
	var old_generation: int = world.get_liquid_policy_session_generation()
	var plain := base.duplicate(true)
	plain.erase("workbench_wave_flow")
	for bad: Dictionary in [
			{"workbench_wave_spill":"yes"},{"workbench_wave_spill_parcels":1},
			{"workbench_wave_spill_fall":0},{"workbench_wave_spill_fall":9},{"workbench_wave_spill_draw":128},
			{"workbench_wave_spill_launch_speed":513},{"workbench_wave_spill_launch_budget":4097},
			{"workbench_wave_spill_fall":2.5},{"workbench_wave_spill_blobs":2},{"workbench_wave_spill_stream_share":256},
			{"workbench_wave_spill_stream_draw":256},{"workbench_wave_spill_stream_draw":-1},
			{"workbench_ballistic":"yes"},{"workbench_face_release":true,"workbench_ballistic":true}]:
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
	native_generic_ballistic(bridge,args,base)

# Generic Ballistic Water under Wave: splashes, sprays and jets keep working,
# with or without Waterwall spill. Face release runs only without spill.
func native_generic_ballistic(bridge: Variant, args: Array, base: Dictionary) -> void:
	var start := failures.size()
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	args[0] = world
	var generic := base.duplicate(true)
	generic.workbench_ballistic = true
	args[6] = generic
	var token: int = bridge.callv("prepare_liquid_world",args)
	if not require(token > 0 and bridge.commit_liquid_world(world,token),"native admits Ballistic Water under Wave / "+str(bridge.get_last_error())):
		return
	var status: Dictionary = world.get_wave_flow_status()
	require(status.enabled and status.construction_options.get("workbench_ballistic") == true \
		and status.spill.get("enabled") == false and status.spill.get("parcels") == false,
		"Wave reads back Ballistic Water on, spill and its release off")
	require(world.get_water_spray().get("ballistic_enabled") == true,"spray coupling sees the Ballistic Water pool under Wave")
	var initial := int(str(status.water_quantity))
	world.set_water_spray({"jet_enabled":true,"jet_origin":Vector2i(200,150),"jet_angle":-130.0,"jet_speed":3.0,"jet_rate":3,"jet_quantity":96})
	for tick: int in 200:
		world.water_spray_before_tick()
		require(world.simulation_tick(),"Wave World with a ballistic jet ticks")
	world.set_water_spray({"jet_enabled":false})
	for tick: int in 300: world.simulation_tick()
	var spray: Dictionary = world.get_water_spray()
	var ledger: Dictionary = spray.get("ledger",{})
	status = world.get_wave_flow_status()
	require(not world.has_failed() and status.get("healthy") == true,"ballistic jet leaves the Wave World healthy")
	require(int(spray.get("totals",{}).get("jet",0)) > 0 and int(ledger.get("deposited_parcels",0)) > 0,
		"jet parcels flew and landed in the Wave World")
	require(int(str(status.water_quantity)) == initial+int(ledger.get("injected_quantity",-1)),
		"Wave grid plus in-flight Water equals the start plus exactly what the jet injected")
	# Spill on, release off: parcels fly, faces drain through the grid.
	var grid_only := base.duplicate(true)
	grid_only.merge({"workbench_ballistic":true,"workbench_wave_spill":true,"workbench_wave_spill_launch_budget":128},true)
	args[6] = grid_only
	token = bridge.callv("prepare_liquid_world",args)
	if require(token > 0 and bridge.commit_liquid_world(world,token),"native admits Ballistic Water beside grid-only spill / "+str(bridge.get_last_error())):
		var spill: Dictionary = world.get_wave_flow_status().spill
		require(spill.enabled == true and spill.parcels == false and int(spill.launch_budget) == 0 \
			and world.get_wave_flow_status().construction_options.workbench_ballistic == true,
			"without Ballistic release spill throws nothing (budget 0) while Ballistic Water stays on")
	# Face release under Wave without spill.
	var faces := base.duplicate(true)
	faces.merge({"workbench_ballistic":true,"workbench_face_release":true},true)
	args[6] = faces
	token = bridge.callv("prepare_liquid_world",args)
	if require(token > 0 and bridge.commit_liquid_world(world,token),"native admits Face release under Wave without spill / "+str(bridge.get_last_error())):
		require(world.get_wave_flow_status().construction_options.workbench_face_release == true,"Face release reads back under Wave")
		for tick: int in 60: require(world.simulation_tick(),"Wave World with Face release ticks")
	sections.native_generic_ballistic = failures.size() == start

func reaction_body_sample(y: float, serial: int, speed: float) -> PackedFloat64Array:
	return PackedFloat64Array([1,50,y,0,8,8,0,speed,0,1,serial,20,50,y,0.4,1.0/60.0,1])

# A single partial Water cell keeps the real body impulse below its cap. Read
# the native packet before a tick, isolating overlap displacement and launch
# reaction from later Wave contacts or parcel impacts. Reaction-off pairs let
# us compare the reaction alone without assuming the displacement formula.
func native_reaction_case(bridge: Variant, checked: Dictionary, wave_enabled: bool,
		push: int, reaction: float) -> Dictionary:
	var label := "spray reaction Wave=%s push=%d reaction=%.1f" % [str(wave_enabled),push,reaction]
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var owner := {"id":1,"instance_id":42,"generation":1,"first_proxy":1,"count":1,
		"budget":20,"gravity":92,"external_drive":false}
	var geometry := PackedFloat64Array([0,0,8,8])
	var sample := {"session":1,"epoch":1,"states":reaction_body_sample(45.0,1,0.0),
		"geometry":geometry,"bodies":[owner]}
	var options := {"workbench_extent":Vector2i(256,256),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":sample,"region":PackedInt32Array([0,0,256,256]),
		"intent":"exploratory","definition_hash":checked.hash,
		"initial_bodies":PackedFloat32Array([1,50,45,0,8,8,0,0,0,1,1]),
		"workbench_wave_flow":wave_enabled,"workbench_ballistic":true,"workbench_worker_threads":1}
	if wave_enabled:
		options.workbench_wave_body_push = push
		options.workbench_wave_body_push_by_mass = 1
	var token: int = bridge.prepare_liquid_world(world,PackedInt32Array([50,62,1,1,3]),
		checked.transport.packed,PackedInt32Array(checked.definition.water_semantics),
		PackedInt32Array([50,62,1,1,64,0]),bridge.default_liquid_policy(),options)
	if not require(token > 0 and bridge.commit_liquid_world(world,token),label+" construction / "+str(bridge.get_last_error())):
		return {}
	var status: Dictionary = world.get_wave_flow_status()
	require(status.get("enabled") == wave_enabled and status.construction_options.get("workbench_ballistic") == true,
		label+" acknowledged solver and Ballistic Water")
	if wave_enabled:
		require(status.parameters.get("body_push") == push and status.parameters.get("body_push_by_mass") == 1,
			label+" acknowledged Body push and Push by amount")
	require(int(str(status.get("water_quantity",-1))) == 64,label+" starts with one partial 64-unit cell")
	var configured: Dictionary = world.set_water_spray({"enabled":true,"threshold":0.0,
		"reaction_gain":reaction,"jitter":0.0,"droplet_gain":0.0})
	if not require(configured.get("accepted") == true and configured.get("applied",{}).get("enabled") == true \
			and is_equal_approx(float(configured.get("applied",{}).get("reaction_gain",-1)),reaction),
			label+" native spray configuration accepted"):
		return {}
	if not require(world.prepare_workbench_coupling(reaction_body_sample(59.0,2,240.0),geometry,[owner],1,1,true),
			label+" moving body sample accepted"):
		return {}
	var result: Dictionary = world.workbench_coupling_results()
	var rows: Array = result.get("rows",[])
	if not require(result.get("valid") == true and rows.size() == 1,label+" valid native body impulse packet"):
		return {}
	var row: Dictionary = rows[0]
	require(row.get("id") == 1 and row.get("instance_id") == 42 and row.get("sample") == 2,
		label+" packet matches the offered physical body/sample")
	var impulse: Vector2 = row.get("impulse",Vector2(INF,INF))
	require(impulse.is_finite() and impulse.length() < 1.0,label+" impulse is below the native cap")
	var spray: Dictionary = world.get_water_spray()
	var ledger: Dictionary = spray.get("ledger",{})
	var water: Dictionary = spray.get("water",{})
	require(int(ledger.get("launched_parcels",-1)) == 1 and int(ledger.get("launched_quantity",-1)) == 64 \
		and int(ledger.get("injected_quantity",-1)) == 0 and int(spray.get("in_flight_quantity",-1)) == 64,
		label+" launches exactly the original partial cell")
	require(int(water.get("total",-1)) == 64 and int(water.get("expected",-1)) == 64 \
		and int(water.get("visible",-1)) == 0 and int(water.get("ballistic",-1)) == 64,
		label+" exact grid plus parcel conservation")
	require(not world.has_failed() and world.get_tick_index() == 0,label+" healthy overlap-only observation")
	return {"impulse":impulse,"hash":world.get_physical_state_hash(),"parcels":world.inspect_ballistic_parcels(4)}

func native_body_push_reaction() -> void:
	var start := failures.size()
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var checked: Dictionary = Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var pairs: Array[Dictionary] = []
	for spec: Array in [[true,0],[true,128],[true,256],[false,256]]:
		var quiet := native_reaction_case(bridge,checked,bool(spec[0]),int(spec[1]),0.0)
		var reacting := native_reaction_case(bridge,checked,bool(spec[0]),int(spec[1]),0.2)
		if quiet.is_empty() or reacting.is_empty(): return
		require(quiet.hash == reacting.hash and quiet.parcels == reacting.parcels,
			"Reaction changes only the body impulse, never Water or its launched parcel")
		pairs.append({"quiet":quiet,"reacting":reacting,"delta":reacting.impulse-quiet.impulse})
	require(pairs[0].quiet.impulse == Vector2.ZERO and pairs[0].reacting.impulse == Vector2.ZERO,
		"Body push 0 suppresses impact spray reaction as well as ordinary Water force")
	var full: Vector2 = pairs[2].delta
	require(full.length() > 0.01,"Body push 256 keeps a measured nonzero spray reaction")
	require(Vector2(pairs[1].delta).distance_to(full*0.5) < 0.000001,
		"Body push 128 halves the reaction on the same launched Water")
	require(Vector2(pairs[3].delta).distance_to(full) < 0.000001,
		"Body push 256 retains the non-Wave reaction, without scaling partial quantity twice")
	for index: int in [0,1]:
		require(pairs[index].reacting.hash == pairs[2].reacting.hash \
			and pairs[index].reacting.parcels == pairs[2].reacting.parcels,
			"Body push changes neither Wave physical state nor actual parcel trajectory")
	sections.native_body_push_reaction = failures.size() == start

func lab_controls() -> void:
	var start := failures.size()
	var spray: RefCounted = panel.water_spray
	var lab: RefCounted = panel.water_lab
	require(lab != null and lab.pages["wave"].is_ancestor_of(spray._spill_toggles["workbench_wave_spill"]),
		"Waterwall spill switch lives in the Water Lab Wave tab, not the toolbar")
	require(lab.pages["wave"].is_ancestor_of(spray._spill_status),"spill native status is on the Wave tab")
	require(spray._spill_fields.size() == 7,"seven spill parameters: fall, feed, throw, budget, blobs, stream share, stream draw")
	spray._set_spill("workbench_wave_spill_parcels",true)
	require(host.workbench_water_options.get("workbench_wave_spill") == true,"ballistic release stages Waterwall spill")
	require(host.workbench_water_options.get("workbench_ballistic") == true and spray._ballistic.button_pressed,
		"ballistic release stages the Ballistic Water parcels it throws through")
	spray._set_spill("workbench_wave_spill",false)
	require(host.workbench_water_options.get("workbench_wave_spill_parcels") == false,"turning spill off also drops ballistic release")
	# Under Wave the Ballistic Water switch stays live and keeps its choice.
	spray._set_wave(true)
	require(host.workbench_water_options.get("workbench_ballistic") == true and spray._ballistic.button_pressed \
		and not spray._ballistic.disabled,"choosing Wave keeps Ballistic Water on and editable")
	spray._set_spill("workbench_wave_spill_parcels",true)
	spray._ballistic.button_pressed = false
	require(host.workbench_water_options.get("workbench_ballistic") == false \
		and host.workbench_water_options.get("workbench_wave_spill_parcels") == false,
		"turning Ballistic Water off also drops Ballistic release")
	spray._face.button_pressed = true
	require(host.workbench_water_options.get("workbench_face_release") == false and spray._face.disabled,
		"Face release is unavailable beside Waterwall spill")
	spray._set_spill("workbench_wave_spill",false)
	require(not spray._face.disabled,"Face release is available under Wave without spill")
	spray._set_wave(false)
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
	await workbench_generic_ballistic()
	# Leaving Wave never carries the spill request into another law.
	spray._set_spill("workbench_wave_spill",true)
	spray._set_wave(false)
	before = generation()
	spray._apply_wave()
	if not await until(func() -> bool: return idle() and generation() > before,"non-Wave law installed"): return
	require(str(host.microscenario_error).is_empty() and wave().get("enabled") == false \
		and not bool(wave().get("spill",{}).get("enabled",true)),"a staged spill request is not sent to a non-Wave law")
	sections.workbench_apply = failures.size() == start

# The real Workbench: Wave Flow (spill off) with Ballistic Water and a live jet.
func workbench_generic_ballistic() -> void:
	var start := failures.size()
	var spray: RefCounted = panel.water_spray
	spray._ballistic.button_pressed = true
	var before := generation()
	if not require(spray._apply_wave(),"Apply Wave with Ballistic Water requested"): return
	if not await until(func() -> bool: return idle() and generation() > before,"Wave with Ballistic Water installed"): return
	require(str(host.microscenario_error).is_empty(),"no refusal / "+str(host.microscenario_error))
	require(wave().get("enabled") == true and wave().get("construction_options",{}).get("workbench_ballistic") == true,
		"Workbench Apply installs Wave Flow with Ballistic Water")
	spray.refresh(host.tower_context)
	require(spray._wave_status.text.contains("APPLIED"),"Ballistic Water under Wave matches native readback / "+spray._wave_status.text)
	require(spray.request({"jet_enabled":true,"jet_origin":Vector2i(60,40)}),"jet requested")
	# The Workbench is paused: step real native ticks until the jet has fired.
	var fired := func() -> int: return int(host.tower_context.get("water_spray",{}).get("totals",{}).get("jet",0))
	for step: int in 40:
		if fired.call() > 0: break
		var tick := int(host.latest_snapshot.tick_index)
		panel.step_once()
		await until(func() -> bool: return idle() and int(host.latest_snapshot.tick_index) > tick,"Wave World with a jet ticks")
	require(fired.call() > 0,"jet fires ballistic parcels into the Wave World / "+str(host.tower_context.get("water_spray",{}).get("totals",{})))
	spray.request({"jet_enabled":false})
	require(not host.simulation_worker.has_failed(),"Wave World with a jet stays healthy")
	spray._ballistic.button_pressed = false
	sections.workbench_generic_ballistic = failures.size() == start

func run() -> void:
	native_admission()
	native_body_push_reaction()
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
