extends SceneTree

const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const Profiles = preload("res://scripts/transport_profiles.gd")
const Tower = preload("res://scripts/experiment_tower.gd")
var assertions: int = 0
var failures: int = 0
var desktop: Control
var web: Control

class ObservationFailureHost extends CyberMicroScenarioHost:
	func _observe_due() -> void:
		_fault("fixture Tower observation unavailable")

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1;push_error("LIQUID_TOWER_HOST: "+message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func apply(worker: CyberSimulationWorker, command: Dictionary) -> bool:
	worker.queue_lab(command)
	worker._mutex.lock();var owned: Dictionary = worker._lab_request;worker._lab_request = {};worker._mutex.unlock()
	return worker._apply_lab(owned)

func request(policy: PackedInt32Array, serial: int, radius: int = 3) -> Dictionary:
	return {"reset":true,"floor":2,"profile":Profiles.resolve(Profiles.preset(2)),"scenario_mode":"Inspect",
		"scenario_request_serial":serial,"sampled_character_enabled":true,"liquid_policy":policy,
		"controlled_liquid_setup":{"intent":"exploratory","maximum_rule_radius":radius,"normalization":""}}

func run() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var policy: PackedInt32Array
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(),24):
		if choice.family == "inertial_cellular_v1" and choice.accepted: policy = choice.request
	expect(not policy.is_empty(),"integrated runtime admits actual IN Brine")
	var worker := Worker.new();worker._running = true;worker._paused = true
	expect(apply(worker,{"reset":true,"floor":1}),"ordinary Current Tower constructor remains available")
	var original: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var host := CyberMicroScenarioHost.new()
	expect(host.install(original,Catalogue.tower(),"Inspect"),"independent original Tower installs")
	expect(worker._world.get_physical_state_hash() == original.get_physical_state_hash()
		and worker._world.get_applied_liquid_construction_receipt().is_empty(),"ordinary Current Tower keeps exact constructor state and no typed identity")
	var applied: bool = apply(worker,request(policy,11))
	expect(applied,"ordinary Tower dispatch admits explicit prepared family policy: "+worker._lab_status)
	if not applied:
		worker._running = false;finish();return
	var receipt: Dictionary = worker._world.get_applied_liquid_construction_receipt()
	expect(not worker._micro_active and not worker._water_lab_active and worker._lab_active and worker._lab_floor == 2,
		"prepared application remains the ordinary Tower, with all normal control routing")
	expect(worker._character.position == Vector2(20,Tower.landing(2).y) and not worker._prepared_frame_hold.is_empty()
		and worker._scenario_host.definition().camera_origin == [0,int(Tower.floor_y(2))],
		"final selected floor/player/camera are staged before capture; post-install floor tail does not reset them")
	expect(receipt.physical_state_hash == worker._world.get_physical_state_hash() and receipt.physical_state_hash_version == 3
		and receipt.maximum_rule_radius == 3 and receipt.run_intent == "exploratory" and receipt.qualifications == 15,
		"ordinary Tower exposes actual native construction facts with retained qualifications")
	expect(worker._lab_profile_hash == Profiles.resolve(Profiles.preset(2)).hash,"independent transport profile survives solver rebuild")
	worker.acknowledge_prepared_liquid_configuration(11)
	expect(worker._prepared_frame_hold.is_empty(),"matching actual Tower acknowledgement releases initial owner frame")
	var retained_hash: String = worker._world.get_physical_state_hash()
	var retained_bytes: PackedByteArray = receipt.canonical_bytes.duplicate()
	var retained_definition: String = worker._scenario_host.summary().definition_hash
	var retained_position: Vector2 = worker._character.position
	expect(not apply(worker,request(policy,12,2)),"IN Tower refuses unprepared radius-two geometry")
	expect(worker._world.get_physical_state_hash() == retained_hash
		and worker._world.get_applied_liquid_construction_receipt().canonical_bytes == retained_bytes
		and worker._scenario_host.summary().definition_hash == retained_definition and worker._character.position == retained_position,
		"native refusal retains complete old Tower, cursor, character and canonical receipt")
	for disposition: String in ["new_request","reset","stop"]:
		worker._controlled_liquid_prepare_barrier = func() -> void:
			if disposition == "new_request": worker.queue_lab({"floor":4})
			elif disposition == "reset": worker.queue_reset(Vector2(24,24))
			else: worker._running = false
		expect(not apply(worker,request(policy,13)),"deterministic final Tower fence observes "+disposition)
		expect(worker._world.get_physical_state_hash() == retained_hash
			and worker._world.get_applied_liquid_construction_receipt().canonical_bytes == retained_bytes
			and worker._character.position == retained_position,"fenced Tower preparation retains actual old owner and native bytes")
		worker._running = true;worker._reset_requested = false
	worker._controlled_liquid_prepare_barrier = Callable()
	var plug: Rect2i = Tower.plugs(2)[0]
	var occupied: int = worker._world.material_at(plug.position.x,plug.position.y)
	apply(worker,{"release":0})
	expect(occupied != 0 and worker._world.material_at(plug.position.x,plug.position.y) == 0,
		"prepared Tower retains actual ordinary release tool instead of MicroScenario refusal")
	worker._running = false
	var faulty := Worker.new();faulty._running = true;faulty._paused = true;faulty._scenario_host = ObservationFailureHost.new()
	expect(apply(faulty,request(policy,21)) and faulty._scenario_request_applied
		and faulty._scenario_host.summary().failed and faulty._lab_status.contains("installed; apparatus failed")
		and not faulty._world.get_applied_liquid_construction_receipt().is_empty(),
		"post-commit Tower observer failure is an installed session fault with actual receipt, never a retained-World refusal")
	faulty._running = false
	await application(policy)
	await synchronous(policy)
	finish()

func application(policy: PackedInt32Array) -> void:
	root.size = Vector2i(1600,1000)
	desktop = load("res://main.tscn").instantiate();root.add_child(desktop);await process_frame
	desktop.tower_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_water_exit.is_empty() and desktop.tower_context.get("active",false)),"actual ordinary Tower acknowledges")
	desktop.tower_floor_select(3)
	expect(await wait_for(func() -> bool: return desktop.tower_context.get("floor",-1) == 3),"ordinary selected floor acknowledges")
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.session_picker.select(1);panel.requested_policy = policy.duplicate();panel._dirty = true;panel._refresh_choices()
	panel.geometry_picker.select(1);panel.damping_numerator.value = 7;panel.refresh(desktop.tower_context)
	expect(not panel.apply_button.disabled and panel.apply_active(),"actual panel prepares ordinary Tower in explicit Exploratory mode")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"prepared ordinary Tower receives matching acknowledgement")
	expect(desktop.microscenario_error.is_empty() and desktop._liquid_tower_active and not desktop.tower_context.micro_active
		and desktop.tower_context.liquid_solver_policy.family_parameters.inertial_cellular_v1.damping_numerator == 7
		and desktop.tower_floor == 3,"ordinary Tower adopts actual policy while retaining floor/control identity")
	var canonical: PackedByteArray = desktop.tower_context.liquid_construction_receipt.canonical_bytes.duplicate()
	expect(desktop._apply_prepared_liquid_tower(desktop.microscenario_liquid_policy,false,2,Profiles.resolve(desktop.tower_profile)),"invalid geometry request reaches native refusal")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary Tower refusal acknowledges")
	expect(not desktop.microscenario_error.is_empty() and desktop._liquid_tower_active and desktop.tower_floor == 3
		and desktop.tower_context.liquid_construction_receipt.canonical_bytes == canonical,"actual refused rebuild retains UI and original applied native bytes")
	desktop.tower_apply_profile(Profiles.resolve(Profiles.preset(1)))
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary profile rebuild acknowledges")
	expect(desktop.tower_context.profile_hash == Profiles.resolve(Profiles.preset(1)).hash
		and desktop.tower_context.liquid_solver_policy.maximum_rule_radius == 3
		and desktop.tower_context.liquid_solver_policy.family_parameters.inertial_cellular_v1.damping_numerator == 7,
		"independent profile rebuild retains accepted solver, geometry and actual damping")
	desktop.tower_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary Tower reset acknowledges")
	expect(desktop.tower_context.liquid_solver_policy.maximum_rule_radius == 3 and desktop._liquid_tower_active,
		"ordinary reset retains explicit policy and geometry")
	expect(panel.load_current_control(),"explicit original Current comparison remains available after prepared Tower")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"original Current comparison acknowledges")
	desktop.tower_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_water_exit.is_empty()),"ordinary default Tower constructor acknowledges after leaving prepared route")
	expect(not desktop._liquid_tower_active and desktop.microscenario_liquid_setup.is_empty()
		and desktop.tower_context.liquid_construction_receipt.is_empty()
		and desktop.tower_context.liquid_solver_policy.maximum_rule_radius == 2,
		"ordinary default Tower retires prior typed setup/intent and restores protected radius two")
	desktop.simulation_worker.stop_worker();desktop.queue_free();desktop = null;await process_frame

func synchronous(policy: PackedInt32Array) -> void:
	web = load("res://web_main.tscn").instantiate();root.add_child(web)
	expect(await wait_for(func() -> bool: return web.ready_to_play),"native synchronous application initializes")
	web.select_demo("experiment_tower",false);web.tower_floor_select(2)
	expect(web.liquid_comparison_apply_active(policy,false,true,"Inspect",3),"synchronous ordinary Tower uses explicit prepared owner")
	expect(web._liquid_tower_active and not web.tower_context.get("micro_active",true)
		and web.native_world.get_liquid_solver_policy().physical_state_hash_version == 3
		and web.player.position == Vector2(20,Tower.landing(2).y),"synchronous Tower retains selected floor and actual native identity")
	var canonical: PackedByteArray = web.native_world.get_applied_liquid_construction_receipt().canonical_bytes.duplicate()
	expect(not web._apply_prepared_liquid_tower(policy,false,2,Profiles.resolve(web.tower_profile))
		and web.native_world.get_applied_liquid_construction_receipt().canonical_bytes == canonical,"synchronous refusal retains original Tower bytes")
	web.tower_apply_profile(Profiles.resolve(Profiles.preset(1)));web.tower_reset()
	expect(web.native_world.get_liquid_solver_policy().maximum_rule_radius == 3
		and web.tower_context.profile_hash == Profiles.resolve(Profiles.preset(1)).hash,"synchronous profile/reset retain accepted policy geometry")
	web.queue_free();web = null;await process_frame

func finish() -> void:
	if desktop != null: desktop.queue_free()
	if web != null: web.queue_free()
	print("LIQUID_TOWER_HOST: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
