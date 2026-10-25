extends SceneTree

const Candidate = preload("res://scripts/prepared_physical_session.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const PlayerProfiles = preload("res://scripts/player_environment_profiles.gd")
const DAM: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var assertions: int = 0
var failures: int = 0
var desktop: Control

class TerrainRefusal extends "res://scripts/prepared_physical_session.gd":
	func install_terrain(_chunks: PackedInt32Array) -> bool:
		last_error = "fixture declared terrain refusal"
		return false

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_PHYSICAL_TRANSACTION: " + message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func apply(worker: CyberSimulationWorker, command: Dictionary) -> bool:
	worker.queue_lab(command)
	worker._mutex.lock()
	var owned: Dictionary = worker._lab_request
	worker._lab_request = {}
	worker._mutex.unlock()
	return worker._apply_lab(owned)

func command(definition: Dictionary, policy: PackedInt32Array, serial: int, candidate: RefCounted) -> Dictionary:
	return {"scenario_reset":definition,"scenario_request_serial":serial,"scenario_mode":"Play",
		"sampled_character_enabled":false,"liquid_policy":policy,
		"controlled_liquid_setup":{"intent":"exploratory","normalization":"",
		"physical_owner":{"epoch":17,"instance_id":candidate.get_instance_id(),"initial_bodies":candidate.initial_body_states()}}}

func run() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	var worker := Worker.new()
	worker._running = true;worker._paused = true
	var initial: Dictionary = Contract.parse(FileAccess.get_file_as_string(DAM))
	expect(apply(worker,{"scenario_reset":initial.definition,"scenario_request_serial":1,"scenario_mode":"Inspect",
		"sampled_character_enabled":false,"liquid_policy":policy,"controlled_liquid_setup":{"normalization":""}}),
		"typed retained World and host install")
	worker._world.prepare_rigid_body_coupling(PackedFloat32Array([1,50.5,100.5,0,1,1,0,0,0,1,1]),false)
	var retained_hash: String = worker._world.get_physical_state_hash()
	var retained_receipt: PackedByteArray = worker._world.get_applied_liquid_construction_receipt().canonical_bytes
	var retained_host_hash: String = worker._scenario_host.summary().definition_hash
	var definition: Dictionary = Catalogue.definition(CyberShowcaseTiles.scenario_ids()[0])
	definition.body_enabled = true;definition.player_enabled = false
	var host := Node2D.new();root.add_child(host);await process_frame
	var candidate = Candidate.new()
	expect(candidate.prepare(host,[{"model":&"runner","producer":&"human","position":Vector2(64,64)}],17),
		"actual provisional physical owner prepares before native request")
	for serial: int in [2,3,4,5]:
		expect(not apply(worker,command(definition,policy,serial,candidate))
			and not worker.prepared_physical_liquid_values().is_empty(),"exclusive owner defers without reporting installation")
		var publication: Dictionary = worker.prepared_physical_liquid_values()
		if publication.is_empty():
			print("Preparation status: ",worker._lab_status)
			candidate.close();host.free();worker._running = false;finish();return
		expect(worker._world.get_physical_state_hash() == retained_hash
			and worker._world.get_applied_liquid_construction_receipt().canonical_bytes == retained_receipt
			and worker._scenario_host.summary().definition_hash == retained_host_hash,
			"pending physical continuation retains complete masked World, canonical receipt and old host cursor")
		var wrong: Dictionary = publication.duplicate(true);wrong.token += 1
		expect(not worker.complete_prepared_physical_liquid(wrong,true),"stale ready token cannot consume current preparation")
		if serial == 2:
			expect(worker.complete_prepared_physical_liquid(publication,false,"declared terrain refusal"),"main can refuse its declared preparation")
		elif serial == 3:
			worker.queue_lab({"floor":0})
		elif serial == 4:
			worker.set_frame_state(0,false,true,Vector2i.ZERO,Vector2i.ZERO,Vector2i(320,180),32,36,true,false,true)
		else:
			expect(worker.complete_prepared_physical_liquid(publication,true),"completed main preparation supplies readiness")
			worker.queue_reset(Vector2(24,24),false,false)
		expect(worker._advance_prepared_physical_liquid().is_empty() and worker.prepared_physical_liquid_values().is_empty(),
			"refusal, newer request, changed execution and reset all retire without a callback or wait")
		expect(worker._world.get_physical_state_hash() == retained_hash
			and worker._world.get_applied_liquid_construction_receipt().canonical_bytes == retained_receipt,
			"every retired continuation retains original native state and applied bytes")
		worker._reset_requested = false
	expect(not apply(worker,command(definition,policy,6,candidate)),"final physical candidate waits for main readiness")
	var publication: Dictionary = worker.prepared_physical_liquid_values()
	var prepared_terrain: PackedInt32Array = publication.terrain.duplicate()
	expect(candidate.install_terrain(publication.terrain),"copied pending terrain stages in exact retained provisional space")
	for _frame: int in range(40):
		await physics_frame
		expect(candidate.verify_physics_frame() and candidate.prepare_terrain_budget(16,0),"actual poses remain frozen throughout terrain continuation")
		if candidate.ready(): break
	expect(candidate.ready() and worker.complete_prepared_physical_liquid(publication,true),"all fallible physical work completes before final owner turn")
	var continuation: Dictionary = worker._advance_prepared_physical_liquid()
	var changed: Dictionary = continuation.duplicate(true)
	changed.scenario_reset.seed += 1
	expect(not worker._apply_lab(changed) and worker._world.get_physical_state_hash() == retained_hash
		and worker.prepared_physical_liquid_values().is_empty(),"continuation cannot reuse a token with different definition/options")
	expect(not apply(worker,command(definition,policy,7,candidate)),"unchanged frozen graph can prepare a new token after refused binding")
	publication = worker.prepared_physical_liquid_values()
	expect(publication.terrain == prepared_terrain and candidate.pose_unchanged(),
		"candidate graph remains frozen for a subsequent matching preparation")
	expect(worker.complete_prepared_physical_liquid(publication,true),"matching original definition and all final owner inputs become ready")
	continuation = worker._advance_prepared_physical_liquid()
	worker.queue_lab({"floor":0})
	expect(not worker._apply_lab(continuation) and worker._world.get_physical_state_hash() == retained_hash,
		"new command after readiness but before native commit still wins final owner fence")
	expect(not apply(worker,command(definition,policy,8,candidate)),"final replacement obtains a fresh one-use preparation")
	publication = worker.prepared_physical_liquid_values()
	expect(candidate.ready() and worker.complete_prepared_physical_liquid(publication,true),"unchanged actual frozen graph is ready for final matching token")
	continuation = worker._advance_prepared_physical_liquid()
	expect(not continuation.is_empty() and worker._apply_lab(continuation),"ready continuation commits native World and worker owners once")
	var receipt: Dictionary = worker._world.get_applied_liquid_construction_receipt()
	expect(worker.prepared_physical_liquid_values().is_empty()
		and receipt.initial_body_state_sha256 == publication.initial_body_state_sha256
		and receipt.physical_state_hash == worker._world.get_physical_state_hash()
		and receipt.physical_state_hash == publication.candidate_physical_state_hash,
		"accepted state and immutable native bytes match prepared masks, not an intermediate empty mask")
	expect(worker.set_rigid_body_states(PackedFloat32Array(),0).reason == "prepared_owner_adoption_pending"
		and worker._rigid_body_states == candidate.initial_body_states(),"stale main body frame cannot erase accepted initial masks")
	worker.acknowledge_prepared_liquid_configuration(7)
	expect(not worker._prepared_physical_frame_hold.is_empty(),"wrong main acknowledgement cannot release initial-body hold")
	candidate.adopt()
	worker.acknowledge_prepared_liquid_configuration(8)
	expect(worker._prepared_physical_frame_hold.is_empty(),"matching main adoption releases initial-body publication")
	worker._running = false
	candidate.close();host.free();await process_frame
	await stop_pending_owner(definition,policy)
	await admitted_work_survives(definition,policy)
	await application_route(definition,policy)
	finish()

func application_route(definition: Dictionary, policy: PackedInt32Array) -> void:
	root.size = Vector2i(1600,1000)
	desktop = load("res://main.tscn").instantiate();root.add_child(desktop);await process_frame
	var ordinary: Dictionary = definition.duplicate(true)
	ordinary.body_enabled = false;ordinary.player_enabled = true
	expect(desktop.microscenario_apply_definition(ordinary,"Play"),"ordinary exploratory constructor remains available")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary map acknowledges")
	expect(desktop.apply_actor_prototype_configuration(&"rapier/runner",&"human",false),"existing articulated constructor remains available")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"ordinary articulated owner acknowledges")
	var retained: CyberPhysicalActorSession = desktop.physical_actor_session
	var old_epoch: int = retained.epoch
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.session_picker.select(1);panel.requested_policy = policy.duplicate();panel._dirty = true
	panel.refresh(desktop.tower_context)
	expect(not panel.apply_button.disabled and panel.apply_active(),
		"actual liquid comparison panel prepares explicit policy with real articulated actor/equipment")
	expect(desktop.physical_actor_session == retained and desktop._pending_physical_candidate != null
		and desktop._pending_physical_candidate.pose_unchanged(),"prior owner remains installed while separate actual graph is frozen")
	var staged: RefCounted = desktop._pending_physical_candidate
	var exact_space: RID = staged.viewport.world_2d.space
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"two live owners complete preparation and commit without blocking main")
	expect(desktop.microscenario_error.is_empty() and desktop._accepted_physical_candidate == staged
		and desktop.physical_actor_session == staged.session and desktop.physical_actor_session != retained
		and staged.viewport.world_2d.space == exact_space and desktop._physical_epoch > old_epoch
		and desktop._physical_terrain_ready,"accepted application adopts exact prepared graph/space with fresh epoch and complete terrain")
	var canonical: PackedByteArray = desktop.tower_context.liquid_construction_receipt.canonical_bytes.duplicate()
	var retained_observation: Dictionary = desktop.tower_context.liquid_host_observation.duplicate(true)
	expect(not retained_observation.is_empty()
		and retained_observation.native_receipt_hash == desktop.tower_context.liquid_construction_receipt.receipt_hash,
		"actual accepted physical graph carries its prepared native/host observation identity")
	var accepted_hash: String = desktop.tower_context.liquid_construction_receipt.physical_state_hash
	var exact_pose: PackedFloat32Array = Candidate._pose_values(staged.session.bridge.pack_body_states())
	var exact_equipment: PackedByteArray = var_to_bytes(staged.session.observation(0).equipment)
	desktop._prepared_physical_factory = func() -> RefCounted: return TerrainRefusal.new()
	expect(desktop.microscenario_apply_exploratory_liquid(desktop.microscenario_definition,policy,false,"Play"),
		"replacement reaches real main terrain refusal before native commit")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"declared main refusal receives terminal owner acknowledgement")
	expect(desktop.physical_actor_session == staged.session and desktop._accepted_physical_candidate == staged
		and staged.viewport.world_2d.space == exact_space and desktop._pending_physical_candidate == null
		and Candidate._pose_values(staged.session.bridge.pack_body_states()) == exact_pose
		and var_to_bytes(staged.session.observation(0).equipment) == exact_equipment,
		"refused replacement retains prior actual graph, permanent space, complete pose and equipment")
	expect(desktop.tower_context.liquid_construction_receipt.canonical_bytes == canonical,
		"host-only main refusal keeps accepted native bytes")
	expect(desktop.tower_context.liquid_host_observation == retained_observation,
		"main terrain refusal retains the old actual graph's complete observation identity")
	desktop.simulation_worker.stop_worker()
	var receipt: Dictionary = desktop.simulation_worker._world.get_applied_liquid_construction_receipt()
	expect(receipt.initial_body_count == desktop.rigid_bodies.size() and receipt.run_intent == "exploratory"
		and receipt.physical_state_hash == desktop.simulation_worker._world.get_physical_state_hash()
		and desktop.simulation_worker._prepared_physical_frame_hold.is_empty(),
		"paused actual application retains initial-body receipt identity after acknowledged adoption")
	expect(desktop.simulation_worker._world.get_physical_state_hash() == accepted_hash,
		"complete retained native hash remains exact through actual main terrain refusal")
	desktop.queue_free();desktop = null;await process_frame

func stop_pending_owner(definition: Dictionary, policy: PackedInt32Array) -> void:
	var host := Node2D.new();root.add_child(host);await process_frame
	var candidate = Candidate.new()
	expect(candidate.prepare(host,[{"model":&"runner","producer":&"human","position":Vector2(64,64)}],17),"stop fixture physical graph prepares")
	var worker := Worker.new();worker._running = true;worker._paused = true
	var retained_hash: String = worker._world.get_physical_state_hash()
	expect(not apply(worker,command(definition,policy,91,candidate)),"stop fixture reaches pending native continuation")
	var publication: Dictionary = worker.prepared_physical_liquid_values()
	expect(worker.start_worker(Vector2(24,24)) == OK,"actual worker starts while main readiness is withheld")
	worker.stop_worker()
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	expect(worker.prepared_physical_liquid_values().is_empty()
		and bridge.prepared_liquid_world_values(worker._world,int(publication.token)).is_empty()
		and worker._world.get_physical_state_hash() == retained_hash,
		"stop joins promptly without main callback and retires native token while retaining complete old World")
	candidate.close();host.free();await process_frame

func admitted_work_survives(definition: Dictionary, policy: PackedInt32Array) -> void:
	var host := Node2D.new();root.add_child(host);await process_frame
	for disposition: String in ["main_refusal","profile_supersession"]:
		var candidate = Candidate.new()
		expect(candidate.prepare(host,[{"model":&"runner","producer":&"human","position":Vector2(64,64)}],17),"queued-work fixture prepares real graph")
		var worker := Worker.new();worker._running = true;worker._paused = true
		expect(worker.queue_emit_disc(500,300,0,2),"paint is admitted before physical request defers")
		expect(worker.queue_emit_cells(PackedInt32Array([501,300]),2),"bounded cell paint is admitted before physical request defers")
		worker.queue_lab(command(definition,policy,101,candidate))
		expect(worker.start_worker(Vector2(24,24)) == OK,"real owner starts with both admitted work and queued physical construction")
		expect(await wait_for(func() -> bool: return not worker.prepared_physical_liquid_values().is_empty()),"real owner publishes pending preparation")
		var publication: Dictionary = worker.prepared_physical_liquid_values()
		worker._mutex.lock()
		var disc_count: int = worker._pending_emissions.size()
		var cell_count: int = worker._pending_cell_emissions.size()
		worker._mutex.unlock()
		expect(disc_count == 1 and cell_count == 1,"pending owner leaves already-admitted values in bounded mailboxes")
		expect(not worker.queue_emit_disc(502,300,0,2)
			and not worker.queue_emit_cells(PackedInt32Array([503,300]),2),"new paint explicitly refuses during preparation instead of being admitted then dropped")
		if disposition == "main_refusal":
			expect(worker.complete_prepared_physical_liquid(publication,false,"fixture refusal"),"main refuses after owner has actually waited")
		else:
			var profile: Dictionary = PlayerProfiles.preset(PlayerProfiles.PRESET_CURRENT)
			profile.effective_mass = 2.0
			expect(worker.queue_player_environment_profile(profile),"independent final player setting is admitted while physical preparation waits")
		expect(await wait_for(func() -> bool:
			var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
			return worker.prepared_physical_liquid_values().is_empty() and snapshot != null \
				and snapshot.lab_context.get("scenario_request_serial",0) == 101 \
				and snapshot.simulation_world_revision > 0 \
				and (disposition != "profile_supersession" or snapshot.lab_context.player_environment_profile.get("effective_mass",0) == 2.0)),
			"refusal/supersession has a terminal owner acknowledgement and retains admitted profile")
		# One further owner publication proves the retained mailbox is consumed,
		# without relying on a sleep or a guessed inter-thread interval.
		var observed: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		expect(await wait_for(func() -> bool: return worker.take_latest_snapshot(observed.serial) != null),"retained owner advances through its next mailbox-consumption turn")
		worker.stop_worker()
		expect(worker._world.material_at(500,300) == 2 and worker._world.material_at(501,300) == 2,
			"previously admitted disc and cell work execute against retained World after refused preparation")
		if disposition == "profile_supersession":
			expect(worker._character.active_profile().effective_mass == 2.0,"admitted profile reaches actual retained character, not just readback")
		candidate.close()
	host.free();await process_frame

func finish() -> void:
	if desktop != null: desktop.queue_free()
	print("LIQUID_PHYSICAL_TRANSACTION: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
