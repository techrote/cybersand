extends SceneTree

const Prepared = preload("res://scripts/prepared_reference_body_session.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
var assertions: int = 0
var failures: int = 0
var desktop: Control

class HeldOwner extends "res://scripts/prepared_reference_body_session.gd":
	var permit_ready: bool = false
	func ready() -> bool:
		return permit_ready and super.ready()

class TerrainRefusal extends "res://scripts/prepared_reference_body_session.gd":
	func install_terrain(_chunks: PackedInt32Array) -> bool:
		last_error = "fixture declared reference terrain refusal"
		return false

class FinalCommitBarrier extends RefCounted:
	var arrived := Semaphore.new()
	var resume := Semaphore.new()
	func enter() -> void:
		arrived.post()
		resume.wait()

class PlayObserver extends CyberSimulationWorker:
	var trace_armed: bool = false
	var initial_ready: bool = false
	var initial_state := PackedByteArray()
	var initial_measurement: Dictionary = {}
	var consumed: Array[Dictionary] = []
	var last_attempt: int = 0
	var trace_bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	func arm() -> void:
		_mutex.lock();trace_armed = true;_mutex.unlock()
	func ready() -> bool:
		_mutex.lock();var value: bool = initial_ready;_mutex.unlock();return value
	func _publish_snapshot(step_ms: float, is_paused: bool, interval: int, force_full: bool = false,
			states: PackedFloat32Array = PackedFloat32Array(), epoch: int = 0) -> void:
		super._publish_snapshot(step_ms,is_paused,interval,force_full,states,epoch)
		_mutex.lock();var enabled: bool = trace_armed;_mutex.unlock()
		if not enabled: return
		if not initial_ready:
			initial_state = trace_bridge.export_physical_state(_world)
			initial_measurement = {"water":_water_observe(),"pressure":_world.get_pressure_flow_ledger(),
				"gas":_world.inspect_gas_compartments(),"tick":_world.get_tick_index(),
				"physical_hash":_world.get_physical_state_hash()}
			_mutex.lock();initial_ready = true;_mutex.unlock()
		var attempt: int = int(_world.get_attempted_tick_index())
		if attempt>last_attempt and consumed.size()<128:
			consumed.append({"attempt":attempt,"completed":_world.get_tick_index(),"bodies":Array(states),
				"failed":_world.has_failed(),"error":_world.get_last_tick_error()})
			last_attempt = attempt

func _initialize() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_WATER_REFERENCE_BODY: "+message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if predicate.call(): return true
	return false

func resolved(id: String) -> Dictionary:
	return CyberWaterExperimentProfiles.resolve({},{},{"scenario_id":id,"seed":31})

func choose(bridge: Variant, family: String, variant: String = "reference") -> PackedInt32Array:
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(),3):
		if choice.accepted and choice.family == family and choice.variant == variant: return choice.request
	return PackedInt32Array()

func record() -> Dictionary:
	return desktop.tower_context.get("liquid_construction_receipt",{}).duplicate(true)

func initial_pose(states: PackedFloat32Array) -> bool:
	if states.size()!=3*Coupling.INPUT_STRIDE: return false
	for index: int in range(3):
		var o: int = index*Coupling.INPUT_STRIDE
		if states[o] != index+1 or states[o+1] != 160+index*52 or states[o+2] != 176 \
			or states[o+3] != 0 or states[o+4] != 8 or states[o+5] != 14 \
			or states[o+6] != 0 or states[o+7] != 0 or states[o+8] != 0 or states[o+9] != 1:
			return false
	return true

func install_ordinary_body(worker: CyberSimulationWorker = null) -> bool:
	desktop = load("res://main.tscn").instantiate()
	if worker != null: desktop.simulation_worker = worker
	root.add_child(desktop);await process_frame
	desktop.water_lab_apply_result(resolved("supported-body-water"))
	return await wait_for(func() -> bool:
		return (desktop.pending_water_apply.is_empty() and desktop.tower_context.get("water_active",false)
			and desktop.rigid_bodies.size()==3))

func _run() -> void:
	root.size = Vector2i(1600,1000)
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var pressure: PackedInt32Array = choose(bridge,"pressure_flow_v1")
	var whole: PackedInt32Array = choose(bridge,"cellular_yield_v1")
	if not await install_ordinary_body():
		expect(false,"ordinary reference body setup acknowledges");_finish();return
	expect(initial_pose(desktop.rapier_bridge.pack_body_states()),"ordinary Current reference recipe remains three unchanged bodies")
	var retained_nodes: Array = desktop.rigid_bodies.duplicate()
	var retained_pose: PackedFloat32Array = Prepared._pose_values(desktop.rapier_bridge.pack_body_states())
	var held := HeldOwner.new()
	desktop._prepared_reference_factory = func() -> RefCounted: return held
	expect(desktop.liquid_comparison_apply_active(pressure,false,true,"Inspect",2),"normal active Water Feel queues staged reference body selection")
	expect(await wait_for(func() -> bool: return not desktop.simulation_worker.prepared_physical_liquid_values().is_empty()),
		"worker publishes copied candidate geometry and body identity without blocking main")
	if desktop.simulation_worker.prepared_physical_liquid_values().is_empty(): _finish();return
	var publication: Dictionary = desktop.simulation_worker.prepared_physical_liquid_values()
	expect(initial_pose(held.initial_body_states()) and publication.initial_bodies == held.initial_body_states(),
		"candidate actual frozen poses equal native preparation input")
	for frame: int in range(32):
		await physics_frame
		expect(held.pose_unchanged() and desktop.rigid_bodies == retained_nodes
			and Prepared._pose_values(desktop.rapier_bridge.pack_body_states()) == retained_pose,
			"real physics frame %d retains both provisional and old actual body graph" % frame)
	held.permit_ready = true
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"main/worker final fences acknowledge staged reference owner")
	desktop._prepared_reference_factory = Callable()
	expect(desktop._accepted_reference_candidate == held and desktop.rigid_bodies == held.bodies()
		and desktop.physical_actor_session == null and desktop.latest_snapshot.rigid_body_epoch == 0,
		"success adopts exact permanent graph with ordinary reference epoch and no actor authority")
	expect(desktop.tower_context.sampled_character_enabled and desktop._liquid_water_active
		and record().initial_body_count == 3 and record().initial_body_state_sha256 == publication.initial_body_state_sha256,
		"sampled player stays enabled and native receipt reports the actual body input")
	var prior: Dictionary = record()
	var prior_observation: Dictionary = desktop.tower_context.liquid_host_observation.duplicate(true)
	desktop._prepared_reference_factory = func() -> RefCounted: return TerrainRefusal.new()
	expect(desktop.liquid_comparison_apply_active(pressure,false,true,"Inspect",2),"declared terrain refusal queues a separate candidate")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate == held and desktop.rigid_bodies == held.bodies()
		and record().canonical_bytes == prior.canonical_bytes
		and desktop.tower_context.liquid_host_observation == prior_observation,
		"terrain refusal retains applied graph, native receipt and immutable observation")
	desktop._prepared_reference_factory = Callable()
	var barrier := FinalCommitBarrier.new()
	desktop.simulation_worker._controlled_liquid_prepare_barrier = barrier.enter
	expect(desktop.liquid_comparison_apply_active(pressure,false,true,"Inspect",2),"final-fence reference body candidate queues")
	var arrived: bool = await wait_for(func() -> bool: return barrier.arrived.try_wait())
	expect(arrived,"actual worker reaches deterministic final commit barrier after body readiness")
	if arrived:
		desktop.simulation_worker.queue_lab({"scenario_capture":true})
	barrier.resume.post()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate == held and record().canonical_bytes == prior.canonical_bytes
		and desktop.tower_context.liquid_host_observation == prior_observation,
		"newer admitted capture at final guard refuses replacement and retains actual owner/receipt/record")
	desktop.simulation_worker._controlled_liquid_prepare_barrier = Callable()
	expect(desktop.liquid_comparison_apply_active(whole,false,true,"Inspect",2),"fractional whole-cell body request reaches native admission")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop._accepted_reference_candidate == held and record().canonical_bytes == prior.canonical_bytes,
		"native normalization refusal retains actual body owner and receipt")
	desktop.water_lab_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and record().session_generation > prior.session_generation and desktop.microscenario_liquid_policy == pressure
		and desktop._accepted_reference_candidate != held and held.viewport == null,
		"ordinary reset retains solver and replaces the old reference graph only after success")
	expect(desktop.liquid_comparison_apply_active(whole,true,true,"Inspect",2),"explicit normalized whole-cell body request queues")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and record().normalization.water_after == 332*50*255 and record().initial_body_count == 3,
		"whole-cell body preparation reports exact normalization and actual initial masks")
	desktop.simulation_worker.stop_worker()
	var world: Variant = desktop.simulation_worker._world
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	expect(receipt.canonical_bytes == record().canonical_bytes and receipt.physical_state_hash == world.get_physical_state_hash()
		and world.rigid_body_id_at(160,176)==1 and world.rigid_body_id_at(212,176)==2 and world.rigid_body_id_at(264,176)==3,
		"exclusive stopped-owner readback matches receipt and actual three initial native masks")
	expect(int(world.water_experiment_observation(Vector2i.ZERO,Vector2i(480,270)).water_integer) == 332*50*255
		and desktop.simulation_worker._sampled_character_enabled,"stored Water quantity and sampled character survive body preparation")
	desktop.queue_free();desktop = null;await process_frame
	if not await install_ordinary_body(): expect(false,"second ordinary body setup");_finish();return
	expect(desktop.liquid_comparison_apply_active(pressure,false,true,"Inspect",2),"second body preparation queues")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()) and desktop._accepted_reference_candidate != null,
		"second actual reference owner installs")
	var accepted: RefCounted = desktop._accepted_reference_candidate
	desktop.water_lab_apply_result(resolved("shallow-pool"))
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.rigid_bodies.is_empty() and desktop._accepted_reference_candidate == null and accepted.viewport == null
		and record().initial_body_count == 0 and desktop.microscenario_liquid_policy == pressure,
		"accepted body-free recipe transition retires old private body space and retains family")
	desktop.tower_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_water_exit.is_empty())
		and not desktop._liquid_water_active and desktop.tower_context.liquid_host_observation.is_empty(),
		"ordinary exit retires prepared reference selection and observation")
	desktop.queue_free();desktop = null;await process_frame
	for variant: String in ["reference","cached","cached_dormant","freemass"]:
		var policy: PackedInt32Array = bridge.default_liquid_policy() if variant=="freemass" else choose(bridge,"pressure_flow_v1",variant)
		await ordinary_play_prefix(policy,variant)
		desktop.queue_free();desktop = null;await process_frame
	_finish()

func ordinary_play_prefix(policy: PackedInt32Array, variant: String) -> void:
	# A fresh cohort preserves the preceding tick-zero receipt assertions. Drive
	# the adopted graph through Main's ordinary physics/worker feedback path.
	var observer := PlayObserver.new()
	if not await install_ordinary_body(observer): expect(false,"play cohort ordinary setup");return
	expect(not policy.is_empty() and desktop.liquid_comparison_apply_active(policy,false,true,"Inspect",2),
		"play cohort prepared body request queues: "+variant)
	if not await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()):
		expect(false,"play cohort prepared body acknowledges");return
	var physics: CyberRapierPhysicsBridge = desktop.rapier_bridge
	var initial: PackedFloat32Array = physics.pack_body_states()
	observer.arm()
	if not await wait_for(observer.ready): expect(false,"exclusive native initial observation acknowledges");return
	# This copied owner value is measured by native _water_observe() immediately
	# after commit, before play. Fractional pressure input is 224/cell, unlike the
	# independently normalized whole-cell cohort above (255/cell).
	var initial_water: int = int(desktop.tower_context.water_accounting.initial_integer)
	expect(initial_water==332*50*224 and observer.initial_measurement.water.water_integer==initial_water
		and observer.initial_measurement.tick==0 and not observer.initial_state.is_empty(),
		"fresh fractional pressure cohort publishes actual initial native Water before play")
	physics.enable_diagnostics()
	var applied: int = 0
	var received: int = 0
	var rejected: int = 0
	var invalid_age_application: int = 0
	var contacts: int = 0
	var accepted_impulse := Vector2.ZERO
	var ages: Dictionary = {}
	var last_serial: int = -1
	var deadline: int = Time.get_ticks_msec()+20000
	desktop.paused = false
	while Time.get_ticks_msec()<deadline:
		await physics_frame
		var current: CyberSimulationSnapshot = desktop.latest_snapshot
		var diagnostics: PackedFloat64Array = physics.diagnostic_applications
		applied += physics.last_results_applied()
		rejected += physics.last_stale_results_rejected()
		for body: int in range(3):
			var offset: int = body*6
			received += int(diagnostics[offset+5])
			if diagnostics[offset+5]>0:
				var age: int = int(diagnostics[offset])
				ages[age] = int(ages.get(age,0))+1
				if age>physics.MAX_CELLULAR_RESULT_AGE_TICKS:
					if diagnostics[offset+4]!=1 or diagnostics[offset+1]!=0 or diagnostics[offset+2]!=0:
						invalid_age_application += 1
				elif diagnostics[offset+4]!=0:
					invalid_age_application += 1
			accepted_impulse += Vector2(diagnostics[offset+1],diagnostics[offset+2])
		if current.serial != last_serial:
			last_serial = current.serial
			contacts += current.rigid_body_contacts_last_tick
		if current.simulation_failed or (current.tick_index>=96 and applied>0 and contacts>0): break
	desktop.paused = true
	desktop.update_worker_frame_state()
	desktop.simulation_worker.stop_worker()
	var world: Variant = desktop.simulation_worker._world
	var final: PackedFloat32Array = physics.pack_body_states()
	var translated: bool = false
	for body: int in range(3):
		var offset: int = body*Coupling.INPUT_STRIDE
		translated = translated or final[offset+1]!=initial[offset+1] or final[offset+2]!=initial[offset+2]
	expect(not desktop.latest_snapshot.simulation_failed and not world.has_failed() and world.get_tick_index()>=96
		and physics.manual_step_count()>0 and translated,"ordinary unpaused owner advances native ticks and actual adopted bodies")
	expect(received>0 and applied>0 and contacts>0 and accepted_impulse!=Vector2.ZERO and invalid_age_application==0,
		"ordinary native contacts produce signed accepted feedback within age bounds; stale responses apply no impulse")
	var quantity: int = int(world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)).water_integer)
	var ledger: Dictionary = world.get_pressure_flow_ledger()
	# contact_loss books stopped momentum at closed faces, not lost Water. Keep
	# the actual momentum ledger in output rather than equating it to mass loss.
	var pressure_closes: bool = not bool(ledger.available) if variant=="freemass" else (bool(ledger.available)
		and int(ledger.overfill_external)==0 and bool(world.inspect_gas_compartments().ledger.closes))
	expect(quantity==initial_water+desktop.simulation_worker._water_explicit_source-desktop.simulation_worker._water_explicit_sink
		and desktop.simulation_worker._water_initial_integer==initial_water and pressure_closes,
		"ordinary coupled prefix preserves exact whole-World Water source/sink balance and closes gas accounting")
	print("LIQUID_WATER_REFERENCE_PLAY: ",JSON.stringify({"variant":variant,"completed_ticks":world.get_tick_index(),
		"rapier_steps":physics.manual_step_count(),"contacts":contacts,"applications":applied,"received":received,
		"stale_rejected":rejected,"accepted_impulse":[accepted_impulse.x,accepted_impulse.y],"water":quantity,
		"initial_water":initial_water,"ledger":ledger,"gas":world.inspect_gas_compartments().get("ledger",{}),"ages":ages,
		"failed":world.has_failed(),"error":world.get_last_tick_error(),"attempted_tick":world.get_attempted_tick_index(),
		"snapshot_tick":desktop.latest_snapshot.tick_index,"snapshot_failed":desktop.latest_snapshot.simulation_failed}))
	# Optional external failure reduction retains exact initial native bytes and
	# consumed body values; ordinary test execution creates no output files.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var folder: String = args[0].path_join(variant)
		DirAccess.make_dir_recursive_absolute(folder)
		var state_file := FileAccess.open(folder.path_join("play-initial.cyps"),FileAccess.WRITE)
		var trace_file := FileAccess.open(folder.path_join("play-consumed.json"),FileAccess.WRITE)
		if state_file != null and trace_file != null:
			state_file.store_buffer(observer.initial_state)
			trace_file.store_string(JSON.stringify({"initial":observer.initial_measurement,"consumed":observer.consumed},"\t"))
		else: expect(false,"requested external native trace destination opens")

func _finish() -> void:
	if desktop != null: desktop.queue_free()
	print("LIQUID_WATER_REFERENCE_BODY: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
