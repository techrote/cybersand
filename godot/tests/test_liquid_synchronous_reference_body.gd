extends SceneTree

const Prepared = preload("res://scripts/prepared_reference_body_session.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const PLAY_TICKS: int = 240 # Four authored seconds: initial y90 bodies reach tank contents.
var assertions: int = 0
var failures: int = 0
var owner: Control
var panel: CyberLiquidComparisonPanel
var cohorts: Array[Dictionary] = []

class Held extends "res://scripts/prepared_reference_body_session.gd":
	var permit: bool = false
	func ready() -> bool: return permit and super.ready()

class TerrainRefusal extends "res://scripts/prepared_reference_body_session.gd":
	func install_terrain(_chunks: PackedInt32Array) -> bool:
		last_error = "declared synchronous terrain refusal";return false

class ActorRefusal extends CyberActorPrototypeSession:
	func configure(_definitions: Array, _world, _epoch_floor: int = -1) -> bool: return false

func _initialize() -> void: run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value: failures += 1;push_error("LIQUID_SYNCHRONOUS_REFERENCE_BODY: "+message)
	return value

func snapshot() -> Dictionary:
	var summary: Dictionary = owner.micro_host.summary();summary.erase("error")
	return {"world":owner.native_world.get_physical_state_hash(),"receipt":owner.native_world.get_applied_liquid_construction_receipt(),
		"record":owner.micro_host.liquid_host_observation_record(),"host":summary,"player":owner.player,
		"bodies":owner.rigid_bodies.duplicate(),"poses":Prepared._pose_values(owner.rapier_bridge.pack_body_states())}

func start(preset: int = 2) -> bool:
	owner.microscenario_panel.open_liquids()
	panel.select_preset(preset);panel.session_picker.select(1);panel.geometry_picker.select(0)
	panel.refresh(owner.tower_context)
	if not expect(not panel.apply_button.disabled,"actual authored Physics Pit Apply control admits Exploratory"): return false
	panel.apply_button.pressed.emit()
	return owner._pending_web_reference!=null

func complete() -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while owner._pending_web_reference!=null and Time.get_ticks_msec()<deadline:
		await physics_frame
		owner._advance_web_reference()
	var applied: bool = owner._pending_web_reference==null and owner.microscenario_error.is_empty()
	if applied: owner._process(0)
	return applied

func original_pose(states: PackedFloat32Array) -> bool:
	if states.size()!=3*Coupling.INPUT_STRIDE: return false
	for index: int in range(3):
		var offset: int = index*Coupling.INPUT_STRIDE
		if states[offset]!=index+1 or states[offset+1]!=[124,244,384][index] or states[offset+2]!=90 \
			or states[offset+3]!=0 or states[offset+4]!=8 or states[offset+5]!=14 \
			or states[offset+6]!=0 or states[offset+7]!=0 or states[offset+8]!=0: return false
	return true

func run() -> void:
	owner = load("res://web_main.tscn").instantiate();root.add_child(owner);await process_frame
	owner.set_process(false);owner.set_physics_process(false)
	panel = owner.microscenario_panel.liquid_panel
	owner.select_demo("physics_pit",false)
	if not expect(owner.ready_to_play and owner.rapier_available and original_pose(owner.rapier_bridge.pack_body_states()),
		"actual original synchronous Physics Pit has its unchanged three authored bodies"): finish();return
	var baseline: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(owner.demo_bridge.build_world(baseline,CyberDemoWorlds.rectangles("physics_pit"))
		and owner.demo_bridge.export_level(baseline)==owner.demo_bridge.export_level(owner.native_world),"original exact authored native recipe is retained")
	var prior: Dictionary = snapshot()
	var held := Held.new()
	owner._prepared_web_reference_factory = func() -> RefCounted: return held
	if not expect(start(),"actual normal Apply queues private physical continuation"): finish();return
	var values: Dictionary = owner._pending_web_reference.values.duplicate(true)
	expect(original_pose(held.initial_body_states()) and values.initial_bodies==held.initial_body_states()
		and snapshot()==prior,"initial pending native mask input uses actual frozen authored poses and retains old owner")
	owner.ui.close_menu();owner.focused = true;owner.paused = false;owner.input_armed = false
	for frame: int in range(32):
		await physics_frame
		owner._advance_web_reference();owner._physics_process(1.0/60.0)
		expect(owner._pending_web_reference!=null and held.pose_unchanged() and snapshot()==prior,
			"pending real frame%d holds candidate and old native/player/body graph" % frame)
	held.permit = true
	expect(await complete(),"bounded terrain/frozen-frame readiness commits the actual prepared owner")
	owner._prepared_web_reference_factory = Callable()
	var receipt: Dictionary = owner.native_world.get_applied_liquid_construction_receipt()
	expect(owner._accepted_reference_candidate==held and owner.rapier_bridge==held.physics_bridge() and owner.rigid_bodies==held.bodies()
		and owner.demo_id=="physics_pit" and not owner.tower_active and owner.paused and owner.player.position==Vector2(24,222),
		"success adopts exact permanent body graph and staged sampled player without Tower routing")
	expect(receipt.initial_body_count==3 and receipt.initial_body_state_sha256==values.initial_body_state_sha256
		and receipt.physical_state_hash==owner.native_world.get_physical_state_hash() and receipt.qualifications==15
		and not receipt.eligible_for_full_matched_evidence and owner.native_world.rigid_body_id_at(124,90)==1
		and owner.native_world.rigid_body_id_at(244,90)==2 and owner.native_world.rigid_body_id_at(384,90)==3,
		"tick-zero receipt and actual native masks describe the adopted body poses with frozen qualifications")
	expect(owner.demo_bridge.export_level(owner.native_world)==owner.demo_bridge.export_level(baseline),
		"prepared tick-zero native tuples exactly retain the independently constructed original Physics Pit recipe")
	expect(owner.demo_bridge.prepared_liquid_world_values(owner.native_world,values.token).is_empty(),
		"accepted continuation consumes the native token instead of leaving a reusable candidate")
	for preset: int in [2,3,4]:
		if preset!=2:
			if not expect(start(preset) and await complete(),"actual next PF variant stages original body owner"): continue
		_play(preset)
	prior = snapshot()
	owner._prepared_web_reference_factory = func() -> RefCounted: return TerrainRefusal.new()
	expect(not start() and snapshot()==prior and owner._pending_web_reference==null,
		"declared candidate terrain refusal retains World/player/body graph/receipt/cursors/record")
	owner._prepared_web_reference_factory = Callable()
	owner._prepared_web_reference_actor_factory = func() -> Variant: return ActorRefusal.new()
	expect(not start() and snapshot()==prior,"declared private sampled refusal retains complete accepted owner")
	owner._prepared_web_reference_actor_factory = Callable()
	owner._prepared_web_reference_commit_barrier = func() -> void: owner.liquid_comparison_clear_import()
	expect(start() and not await complete() and snapshot()==prior,"newer selection at final native guard refuses and retains complete owner")
	owner._prepared_web_reference_commit_barrier = Callable()
	panel.select_preset(6)
	expect(not owner.liquid_comparison_apply_active(panel.requested_policy,false,true,"Play",2) and snapshot()==prior
		and owner.native_world.get_liquid_construction_attempt().get("kind","")=="construction_attempt"
		and owner.tower_context.liquid_construction_attempt==owner.native_world.get_liquid_construction_attempt(),
		"native IN geometry refusal retains old owner and refreshes its distinct actual attempt readback")
	if expect(start(),"bounded readiness expiry candidate queues"):
		owner._pending_web_reference._started_msec = Time.get_ticks_msec()-20001
		owner._advance_web_reference()
		expect(owner._pending_web_reference==null and snapshot()==prior,"explicit bounded readiness expiry retains accepted graph/World/receipts")
	var retained_quality: int = owner.quality
	if expect(start(),"settings-fenced candidate queues"):
		owner.set_quality(0 if retained_quality!=0 else 2)
		var after_setting: Dictionary = snapshot()
		expect(not await complete() and snapshot()==after_setting,
			"changed final execution settings refuse pending replacement while retaining the actual updated old owner")
		owner.set_quality(retained_quality)
	var old: RefCounted = owner._accepted_reference_candidate
	owner.native_world.paint_disc(700,700,0,1,0)
	owner.ui.buttons["restart"].pressed.emit()
	expect(await complete() and owner.native_world.get_tick_index()==0 and owner.native_world.material_at(700,700)==0
		and owner._accepted_reference_candidate!=old and old.viewport==null and original_pose(owner.rapier_bridge.pack_body_states()),
		"actual Restart retains accepted solver/recipe and replaces old body graph only on success")
	owner.export_save();owner.import_save(owner.export_text)
	panel.refresh(owner.tower_context)
	prior = snapshot()
	expect(owner.last_save_error.is_empty() and panel.apply_button.disabled and owner.liquid_comparison_active_definition().is_empty()
		and not owner.liquid_comparison_apply_active(owner.demo_bridge.default_liquid_policy(),false,true,"Play",2) and snapshot()==prior,
		"imported same-label physical owner cannot acquire authored recipe identity or silently convert bodies")
	owner.select_demo("physics_pit",false)
	if expect(start(),"pending candidate exists before explicit Current replacement"):
		var pending: RefCounted = owner._pending_web_reference.candidate
		owner.select_demo("neon_works",false)
		expect(owner._pending_web_reference==null and pending.viewport==null and owner.rigid_bodies.is_empty()
			and owner.native_world.get_applied_liquid_construction_receipt().is_empty()
			and owner.native_world.get_liquid_solver_policy().maximum_rule_radius==2,
			"Current replacement discards pending graph/token and retires prepared physical identity")
	finish()

func _play(preset: int) -> void:
	var actual: Dictionary = owner.native_world.get_liquid_solver_policy()
	var water_assignment: Dictionary = {}
	for assignment: Dictionary in actual.assignments:
		if int(assignment.material)==3: water_assignment = assignment
	var variant: String = "cached_dormant" if preset==4 else ("cached" if preset==3 else "reference")
	expect(water_assignment.get("applied_family","")=="pressure_flow_v1"
		and water_assignment.get("applied_variant","")==variant
		and actual.policy_hash==owner.demo_bridge.validate_liquid_policy(panel.requested_policy).receipt.policy_hash,
		"actual native pressure family/variant/hash matches the selected physical cohort")
	var initial: PackedFloat32Array = owner.rapier_bridge.pack_body_states()
	var water: int = owner.native_world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)).water_integer
	owner.microscenario_panel.liquid_dialog.hide()
	owner.ui.close_menu();owner.paused = false;owner.focused = true;owner.input_armed = false
	var contacts: int = 0
	var applications: int = 0
	var accepted_impulse := Vector2.ZERO
	var absolute_impulse: float = 0
	var accepted_ages: Array[int] = []
	owner.rapier_bridge.diagnostic_applications.resize(3*6)
	for _tick: int in range(PLAY_TICKS):
		owner._physics_process(1.0/60.0)
		applications += owner.rapier_bridge.last_results_applied()
		var applied: PackedFloat64Array = owner.rapier_bridge.diagnostic_applications
		for index: int in range(3):
			if applied[index*6+5]==1 and applied[index*6+4]==0:
				var impulse := Vector2(applied[index*6+1],applied[index*6+2])
				accepted_impulse += impulse;absolute_impulse += absf(impulse.x)+absf(impulse.y)
				accepted_ages.append(int(applied[index*6]))
		var results: PackedFloat32Array = owner.native_world.rigid_body_results()
		for offset: int in range(0,results.size(),Coupling.RESULT_STRIDE): contacts += int(results[offset+Coupling.RESULT_CONTACT_COUNT])
	owner.paused = true;owner.ui.show_page("home")
	var current: PackedFloat32Array = owner.rapier_bridge.pack_body_states()
	var gas: Dictionary = owner.native_world.inspect_gas_compartments().get("ledger",{})
	expect(not owner.native_world.has_failed() and owner.native_world.get_tick_index()==PLAY_TICKS and owner.rapier_bridge.manual_step_count()==PLAY_TICKS
		and applications>0 and absolute_impulse>0 and not accepted_ages.is_empty() and accepted_ages.max()<=8
		and owner.rapier_bridge.last_stale_results_rejected()==0
		and (current[1]!=initial[1] or current[2]!=initial[2]),"ordinary synchronous body/native feedback executes four authored seconds with positive translation and consumed signed feedback")
	expect(owner.native_world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)).water_integer==water and gas.get("closes",false),
		"closed authored recipe preserves exact initial Water and closing pressure gas ledger")
	cohorts.append({"preset":preset,"family":water_assignment.get("applied_family",""),
		"variant":water_assignment.get("applied_variant",""),"policy_hash":actual.policy_hash,
		"completed_ticks":owner.native_world.get_tick_index(),"manual_steps":owner.rapier_bridge.manual_step_count(),
		"contacts":contacts,"water":water,"gas_closes":gas.get("closes",false),"applications":applications,
		"accepted_impulse":[accepted_impulse.x,accepted_impulse.y],"absolute_impulse":absolute_impulse,
		"max_accepted_age":accepted_ages.max() if not accepted_ages.is_empty() else -1,
		"initial_body0":[initial[1],initial[2]],"final_body0":[current[1],current[2]]})

func finish() -> void:
	print("LIQUID_SYNCHRONOUS_REFERENCE_BODY_RESULT ",JSON.stringify({"ok":failures==0,"cohorts":cohorts,
		"scope":"actual synchronous Physics Pit staging and ordinary feedback; local native Windows only"}))
	print("LIQUID_SYNCHRONOUS_REFERENCE_BODY: %d assertions; %d failures" % [assertions,failures])
	if owner!=null: owner.queue_free()
	quit(1 if failures else 0)
