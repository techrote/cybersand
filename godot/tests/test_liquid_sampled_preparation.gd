extends SceneTree

const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const Staging = preload("res://scripts/prepared_sampled_session.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const PlayerProfiles = preload("res://scripts/player_environment_profiles.gd")
const DAM: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var assertions: int = 0
var failures: int = 0
var desktop: Control
var web: Control

const EquipmentRefusal = preload("res://tests/fixtures/lcb/sampled_preparation_equipment_refusal.gd")

const ApplyCall = preload("res://tests/fixtures/lcb/sampled_preparation_apply_call.gd")

const Barrier = preload("res://tests/fixtures/lcb/sampled_preparation_barrier.gd")

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_SAMPLED_PREPARATION: " + message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func choose(bridge: Variant, request: PackedInt32Array, family: String) -> PackedInt32Array:
	for value: Dictionary in bridge.liquid_policy_assignment_choices(request,3):
		if value.family == family and value.variant == "reference" and value.accepted: return value.request
	return PackedInt32Array()

func prepare(bridge: Variant, world: Variant, definition: Dictionary, request: PackedInt32Array) -> int:
	var checked: Dictionary = Contract.validate(definition)
	return bridge.prepare_liquid_world(world,PackedInt32Array(definition.rectangles),checked.transport.packed,
		PackedInt32Array(definition.water_semantics),PackedInt32Array(definition.partial_water_fills),request,
		{"definition_hash":checked.hash,"seed":definition.seed,"region":PackedInt32Array(definition.interest.region)})

func apply(worker: CyberSimulationWorker, command: Dictionary) -> bool:
	# A serialized external owner invokes the exact production extraction/apply
	# boundary, so failure identity checks need no sleeps or concurrent reads.
	worker.queue_lab(command)
	worker._mutex.lock()
	var owned: Dictionary = worker._lab_request
	worker._lab_request = {}
	worker._mutex.unlock()
	return worker._apply_lab(owned)

func command(definition: Dictionary, policy: PackedInt32Array, serial: int, actors: Array = []) -> Dictionary:
	return {"scenario_reset":definition,"scenario_request_serial":serial,"scenario_mode":"Play",
		"sampled_character_enabled":bool(definition.player_enabled),"runtime_enclosure_recovery_enabled":false,
		"exploratory_actor_definitions":actors,"liquid_policy":policy,
		"controlled_liquid_setup":{"intent":"exploratory","normalization":""}}

func run() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge") if ClassDB.class_exists(&"CyberDemoBridge") else null
	if bridge == null or not bridge.has_method(&"prepared_liquid_character_box_collides"):
		expect(false,"fresh candidate query adapter required")
		finish()
		return
	var source: Dictionary = Contract.parse(FileAccess.get_file_as_string(DAM))
	var defaults: PackedInt32Array = bridge.default_liquid_policy()
	var pressure: PackedInt32Array = choose(bridge,defaults,"pressure_flow_v1")
	var definition: Dictionary = source.definition.duplicate(true)
	definition.rectangles = [0,0,256,256,0,32,32,10,16,1]
	definition.partial_water_fills = []
	definition.events = []; definition.observations = []; definition.conditions = []
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(bridge.build_water_feel_world(world,PackedInt32Array([0,0,256,256,0]),source.transport.packed,
		PackedInt32Array(definition.water_semantics),PackedInt32Array()),"live empty fixture builds")
	var token: int = prepare(bridge,world,definition,defaults)
	var view := Staging.CandidateView.new(bridge,world,token)
	expect(token > 0 and view.box_collides(Vector2(32,32),Vector2(8,14)) 
		and not world.box_collides(Vector2(32,32),Vector2(8,14)),"candidate view queries candidate terrain, never retained live terrain")
	var reference: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(bridge.build_water_feel_world(reference,PackedInt32Array(definition.rectangles),source.transport.packed,
		PackedInt32Array(definition.water_semantics),PackedInt32Array()),"independent ordinary collision control builds")
	for mode: int in range(4):
		for origin: Vector2 in [Vector2(32,32),Vector2(30,30),Vector2(100,100),Vector2(-1,0)]:
			expect(view.character_box_collides(origin,Vector2(8,14),mode)
				== reference.character_box_collides(origin,Vector2(8,14),mode),"candidate collision mode agrees with ordinary Current control")
	var initial_hash: String = world.get_physical_state_hash()
	var staged: Dictionary = Staging.prepare(bridge,world,token,Vector2(32,32),true,false,{},
		[{"model":&"runner","producer":&"human","position":Vector2(32,32)}],17)
	expect(staged.ok and staged.actors.identity_epoch() == 18,"fresh actor session retires prior identity floor")
	expect(staged.character.position != Vector2(32,32) and not staged.character.recovery_blocked,
		"bounded invalid-spawn repair sees candidate wall before commit")
	expect(world.get_physical_state_hash() == initial_hash and not world.box_collides(Vector2(32,32),Vector2(8,14)),
		"private actor/usable preparation changes no retained World")
	bridge.discard_liquid_world(world,token)
	expect(view.box_collides(Vector2(100,100),Vector2(1,1)),"retired candidate view fails closed")
	expect(not view.has_method(&"paint_disc") and not view.has_method(&"simulation_tick"),"candidate view carries no edit/tick authority")

	var worker := Worker.new()
	worker._running = true
	worker._paused = true
	var first: Dictionary = command(source.definition,defaults,1)
	first.sampled_character_enabled = false
	first.controlled_liquid_setup = {"normalization":""}
	expect(apply(worker,first),"retained typed initial session installs")
	var map: Dictionary = Catalogue.definition(CyberShowcaseTiles.scenario_ids()[0])
	expect(int(map.schema_version) == 2 and Catalogue.exploratory_actor_map(map),"actual normal exploratory map is schema2 and allowlisted")
	var actors: Array = [{"model":&"runner","producer":&"human","position":Vector2(map.player_start[0],map.player_start[1])}]
	expect(worker._actor_session.configure(actors,worker._world),"retained actor session configures")
	expect(worker._usable_session.configure(worker._actor_session.snapshot()),"retained equipment configures")
	worker._character = worker._actor_session.player()
	var old_epoch: int = worker._actor_session.identity_epoch()
	expect(worker.submit_actor_usable_action(0,old_epoch,1,0,0,Vector2.RIGHT,0.7,false,false,12,&"human"),"retained equipment request admitted")
	worker._usable_session.step(1.0/60.0,worker._world,worker._actor_session.snapshot())
	worker._world.paint_disc(51,100,0,3,0)
	worker._world.prepare_rigid_body_coupling(PackedFloat32Array([1,51.5,100.5,0,0.5,0.5,0,0,0,1,1]),false)
	var retained_actors: CyberActorPrototypeSession = worker._actor_session
	var retained_usables: CyberUsableSession = worker._usable_session
	var actor_bytes: PackedByteArray = var_to_bytes(retained_actors.snapshot())
	var usable_bytes: PackedByteArray = var_to_bytes(retained_usables.snapshot())
	var canonical: PackedByteArray = worker._world.get_applied_liquid_construction_receipt().canonical_bytes
	initial_hash = worker._world.get_physical_state_hash()
	var generation: int = worker._world.get_liquid_policy_session_generation()
	worker._prepared_usable_factory = func() -> CyberUsableSession: return EquipmentRefusal.new()
	expect(not apply(worker,command(map,pressure,2,actors)),"declared equipment configuration refusal precedes native swap")
	expect(worker._world.get_physical_state_hash() == initial_hash and worker._world.rigid_body_id_at(51,100) == 1
		and worker._world.get_liquid_policy_session_generation() == generation,"equipment refusal preserves complete World, mask and generation")
	expect(worker._actor_session == retained_actors and worker._usable_session == retained_usables
		and var_to_bytes(retained_actors.snapshot()) == actor_bytes and var_to_bytes(retained_usables.snapshot()) == usable_bytes,
		"equipment refusal preserves actor identity, epoch, equipment and complete session state")
	expect(worker._world.get_applied_liquid_construction_receipt().canonical_bytes == canonical
		and worker._world.get_liquid_construction_attempt().is_empty(),"host-only refusal retains applied bytes and invents no native attempt")
	worker._prepared_usable_factory = Callable()
	var barrier := Barrier.new()
	worker._controlled_liquid_prepare_barrier = barrier.enter
	worker.queue_lab(command(map,pressure,3,actors))
	var pending := ApplyCall.new()
	pending.worker = worker
	worker._mutex.lock()
	pending.command = worker._lab_request
	worker._lab_request = {}
	worker._mutex.unlock()
	var applying := Thread.new()
	expect(applying.start(pending.run) == OK,"independent exclusive preparation owner starts")
	var arrived: bool = await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived,"private actor and equipment candidates reach deterministic supersession fence")
	worker.queue_lab(command(map,defaults,4,actors))
	barrier.resume.post()
	applying.wait_to_finish()
	expect(not pending.applied and worker._world.get_physical_state_hash() == initial_hash
		and worker._world.rigid_body_id_at(51,100) == 1,"newer request retires prepared actor/equipment candidate while retaining complete masked World")
	expect(worker._actor_session == retained_actors and worker._usable_session == retained_usables
		and var_to_bytes(retained_actors.snapshot()) == actor_bytes and var_to_bytes(retained_usables.snapshot()) == usable_bytes,
		"supersession retains actual prior actor and equipment sessions")
	worker._controlled_liquid_prepare_barrier = Callable()
	expect(apply(worker,command(map,pressure,5,actors)),"actual exploratory sampled candidate commits")
	var receipt: Dictionary = worker._world.get_applied_liquid_construction_receipt()
	expect(receipt.run_intent == "exploratory" and receipt.pacing == "host_paced"
		and receipt.physical_state_hash == worker._world.get_physical_state_hash(),"initial exploratory receipt captures actual final native state and intent")
	expect(worker._actor_session != retained_actors and worker._usable_session != retained_usables
		and worker._actor_session.identity_epoch() > old_epoch,"accepted swap installs privately prepared owners with fresh identity")
	expect(not worker.submit_actor_action(0,old_epoch,2,0,Vector2.RIGHT,false,false,12,&"human"),"previous epoch action cannot address replacement owner")
	worker.set_frame_state(0,false,true,Vector2i.ZERO,Vector2i(900,900),Vector2i(10,10),0,0,true,false,true)
	expect(worker._view_origin == Vector2i(map.camera_origin[0],map.camera_origin[1]),"old main presentation frame cannot overwrite prepared initial owner view")
	worker.acknowledge_prepared_liquid_configuration(4)
	expect(not worker._prepared_frame_hold.is_empty(),"wrong acknowledgement does not release new initial frame")
	worker.acknowledge_prepared_liquid_configuration(5)
	expect(worker._prepared_frame_hold.is_empty(),"matching installed acknowledgement releases initial frame")
	worker._running = false

	owner_profile_boundary(map,pressure)
	await owner_settings_fence(map,pressure)
	await application_routes(map,pressure)
	finish()

func owner_profile_boundary(definition: Dictionary, policy: PackedInt32Array) -> void:
	var worker := Worker.new()
	worker._running = true
	worker._paused = true
	var profile: Dictionary = PlayerProfiles.preset(PlayerProfiles.PRESET_CURRENT)
	profile.effective_mass = 2.0
	var initial_hash: String = worker._world.get_physical_state_hash()
	expect(worker.queue_player_environment_profile(profile),"valid independent player profile queues")
	expect(not apply(worker,command(definition,policy,31)) and worker._world.get_physical_state_hash() == initial_hash,
		"unconsumed player configuration prevents prepared swap and retains old World")
	# Match the actual owner-loop extraction boundary. No postcommit profile
	# application runs in this direct call, so an old-profile staging bug fails.
	worker._mutex.lock()
	var extracted: Dictionary = worker._pending_player_environment_profile
	worker._pending_player_environment_profile = {}
	worker._mutex.unlock()
	var next: Dictionary = command(definition,policy,32)
	next["_prepared_player_environment_profile"] = extracted
	expect(apply(worker,next),"same-turn extracted profile joins prepared candidate")
	expect(worker._character.active_profile().effective_mass == 2.0,
		"candidate character has its final independent profile at native commit, before any owner tail")
	worker._running = false

func owner_settings_fence(definition: Dictionary, policy: PackedInt32Array) -> void:
	var worker := Worker.new()
	worker.set_frame_state(0,false,true,Vector2i.ZERO,Vector2i.ZERO,Vector2i(320,180),32,36,true,true,true)
	expect(worker.start_worker(Vector2(24,24)) == OK,"owner fence worker starts")
	var before: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var barrier := Barrier.new()
	worker._controlled_liquid_prepare_barrier = barrier.enter
	worker.queue_lab(command(definition,policy,41))
	var arrived: bool = await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived,"staged exploratory candidate reaches deterministic commit barrier")
	if not arrived:
		barrier.resume.post(); worker.stop_worker(); return
	worker.set_frame_state(0,false,true,Vector2i.ZERO,Vector2i.ZERO,Vector2i(320,180),32,36,true,false,true)
	barrier.resume.post()
	expect(await wait_for(func() -> bool:
		var state: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return state != null and state.lab_context.get("scenario_request_serial",0) == 41),"execution selection refusal is acknowledged")
	worker.stop_worker()
	expect(not worker._scenario_request_applied and worker._world.get_liquid_policy_session_generation()
		== int(before.lab_context.liquid_solver_policy.session_generation),"changed owner execution selection retires staged candidate before commit")

func application_routes(definition: Dictionary, policy: PackedInt32Array) -> void:
	root.size = Vector2i(1600,1000)
	desktop = load("res://main.tscn").instantiate();root.add_child(desktop)
	await process_frame
	expect(desktop.microscenario_apply_definition(definition,"Play"),"ordinary authored map remains available")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary map owner acknowledges")
	expect(desktop.apply_actor_prototype_configuration(&"runner",&"human",false),"ordinary sampled rig selection remains available")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary sampled rig owner acknowledges")
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.session_picker.select(1);panel.session_picker.item_selected.emit(1)
	panel.requested_policy = policy.duplicate();panel._dirty = true
	panel.refresh(desktop.tower_context)
	expect(not panel.apply_button.disabled and panel.apply_active(),"actual normal panel admits explicit exploratory sampled rebuild")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"exploratory panel owner acknowledges")
	expect(desktop.tower_context.liquid_construction_receipt.run_intent == "exploratory"
		and desktop.latest_snapshot.actor_prototypes.models[0] == &"runner","panel uses native exploratory receipt and preserves sampled actor")
	var policy_hash: String = desktop.tower_context.liquid_solver_policy.policy_hash
	expect(desktop.apply_actor_prototype_configuration(&"gyrocrate",&"human",false),"F5 actor rebuild retains explicit exploratory solver request")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"F5 staged rebuild acknowledges")
	expect(desktop.tower_context.liquid_solver_policy.policy_hash == policy_hash
		and desktop.latest_snapshot.actor_prototypes.models[0] == &"gyrocrate","F5 applies new sampled owner with accepted policy retained")
	var generation: int = desktop.tower_context.liquid_solver_policy.session_generation
	expect(not desktop.apply_actor_prototype_configuration(&"physical/barrel",&"human",false)
		and desktop.pending_microscenario_apply.is_empty(),"unstaged physical actor rebuild refuses before queue")
	expect(desktop.tower_context.liquid_solver_policy.session_generation == generation
		and desktop.latest_snapshot.actor_prototypes.models[0] == &"gyrocrate","physical refusal retains old native and actor session")
	desktop.microscenario_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"exploratory reset acknowledges")
	expect(desktop.tower_context.liquid_solver_policy.policy_hash == policy_hash
		and desktop.tower_context.liquid_construction_receipt.run_intent == "exploratory","reset retains selected solver and exploratory intent")
	desktop.simulation_worker.stop_worker()
	expect(desktop.simulation_worker._prepared_frame_hold.is_empty(),"normal application releases accepted initial frame hold")
	expect(desktop.simulation_worker._world.get_physical_state_hash()
		== desktop.simulation_worker._world.get_applied_liquid_construction_receipt().physical_state_hash,
		"paused application tick-zero state matches captured final owner receipt")
	desktop.queue_free();desktop = null;await process_frame
	web = load("res://web_main.tscn").instantiate();root.add_child(web);await process_frame
	expect(web.microscenario_apply_exploratory_liquid(definition,policy,false,"Play"),"synchronous owner stages sampled exploratory setup")
	expect(web.tower_context.liquid_construction_receipt.run_intent == "exploratory"
		and web.native_world.get_physical_state_hash() == web.tower_context.liquid_construction_receipt.physical_state_hash,
		"synchronous native readback equals actual initial exploratory World")
	var retained: CyberSampledCharacter = web.player
	var body: Dictionary = definition.duplicate(true);body.body_enabled = true
	expect(not web.microscenario_apply_exploratory_liquid(body,policy,false,"Play") and web.player == retained,
		"unstaged synchronous physical bodies refuse without replacing sampled owner")
	web.queue_free();web = null;await process_frame

func finish() -> void:
	if desktop != null: desktop.queue_free()
	if web != null: web.queue_free()
	print("LIQUID_SAMPLED_PREPARATION: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
