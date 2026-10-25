extends SceneTree

const PhysicalCandidate = preload("res://scripts/prepared_physical_session.gd")
const DEMOS: Array[String] = ["material_lab","waterworks","foundry","neon_works"]
var assertions: int = 0
var failures: int = 0
var owner: Control
var panel: CyberLiquidComparisonPanel
var bridge: Variant
var cohorts: Array[Dictionary] = []
var matched: Dictionary = {}

class ActorRefusal extends CyberActorPrototypeSession:
	func configure(_definitions: Array, _world, _epoch_floor: int = -1) -> bool: return false

func _initialize() -> void: run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value: failures += 1;push_error("LIQUID_ORDINARY_DEMO_HOST: "+message)
	return value

func apply(preset: int = 2, radius: int = 2) -> bool:
	panel.select_preset(preset);panel.session_picker.select(1)
	panel.geometry_picker.select(1 if radius==3 else 0);panel.refresh(owner.tower_context)
	if not expect(not panel.apply_button.disabled,"actual ordinary Apply control is enabled"): return false
	panel.apply_button.pressed.emit()
	return owner.microscenario_error.is_empty()

func snapshot() -> Dictionary:
	var state: Dictionary = owner.micro_host.summary();state.erase("error")
	return {"hash":owner.native_world.get_physical_state_hash(),"receipt":owner.native_world.get_applied_liquid_construction_receipt(),
		"player":owner.player,"record":owner.micro_host.liquid_host_observation_record(),"host":state,
		"demo":owner.demo_id,"quality":owner.quality,"view":owner.current_view_size,"camera":owner.camera_origin}

func intact(before: Dictionary) -> bool:
	return snapshot()==before

func run() -> void:
	owner = load("res://web_main.tscn").instantiate();root.add_child(owner);await process_frame
	owner.set_process(false);owner.set_physics_process(false)
	bridge = owner.demo_bridge;panel = owner.microscenario_panel.liquid_panel
	if not expect(owner.ready_to_play,"actual normal synchronous owner is ready"): finish();return
	for demo: String in DEMOS:
		for quality: int in [0,2]: _curated(demo,quality)
	_refusals();_import_identity();_current_control();_failed_prepared_hint()
	finish()

func _curated(id: String, quality: int) -> void:
	owner.select_demo(id,false);owner.set_quality(quality)
	var control: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(bridge.build_world(control,CyberDemoWorlds.rectangles(id)),"independent original Current recipe constructs "+id)
	var original: PackedByteArray = bridge.export_level(control)
	expect(bridge.export_level(owner.native_world)==original,"ordinary Current cells match original constructor "+id)
	var view: Vector2i = owner.current_view_size
	var margin: Vector2i = owner.simulation_margin
	var hz: int = owner.render_snapshot_hz
	if not expect(apply(),"actual Apply installs ordinary prepared recipe "+id): return
	var receipt: Dictionary = owner.native_world.get_applied_liquid_construction_receipt()
	var policy: Dictionary = owner.native_world.get_liquid_solver_policy()
	var expected: PackedInt32Array = PackedInt32Array([0,0,view.x+margin.x,view.y+margin.y])
	expect(owner.demo_id==id and not owner.tower_active and not owner.tower_context.get("micro_active",false)
		and owner.paused and owner.player.position==Vector2(24,222) and owner.player.velocity==Vector2.ZERO,
		"prepared ordinary owner retains demo identity/player and pauses without Tower routing "+id)
	expect(owner.quality==quality and owner.current_view_size==view and owner.simulation_margin==margin
		and owner.render_snapshot_hz==hz and owner.camera_origin==Vector2.ZERO and receipt.region==expected,
		"actual quality0/2 geometry and native receipt agree before execution "+id)
	expect(receipt.run_intent=="exploratory" and receipt.pacing=="host_paced" and receipt.initial_body_count==0
		and receipt.qualifications==15 and not receipt.eligible_for_full_matched_evidence
		and receipt.physical_state_hash==owner.native_world.get_physical_state_hash(),"actual tick-zero native facts retain qualifications "+id)
	expect(policy.maximum_rule_radius==2 and policy.assignments[0].applied_family=="pressure_flow_v1"
		and bridge.export_level(owner.native_world)==original,"selected policy retains exact ordered Current recipe tuples "+id)
	expect(not owner.micro_host.summary().instrumentation and owner._microscenario_tool_allowed(3),
		"ordinary tools stay active without apparatus telemetry "+id)
	owner.ui.close_menu();owner.paused = false;owner.focused = true;owner.input_armed = false
	for _tick: int in range(12): owner._physics_process(1.0/60.0)
	owner.paused = true;owner.ui.show_page("home")
	expect(not owner.native_world.has_failed() and owner.native_world.get_tick_index()==12 and owner.total_moves>0,
		"ordinary owner executes positive native ticks "+id)
	owner.native_world.paint_disc(700,700,0,1,0)
	owner.ui.buttons["restart"].pressed.emit()
	var reset: Dictionary = owner.native_world.get_applied_liquid_construction_receipt()
	expect(owner.microscenario_error.is_empty() and reset.session_generation>receipt.session_generation
		and reset.policy_hash==receipt.policy_hash and reset.prepared_payload_hash==receipt.prepared_payload_hash
		and bridge.export_level(owner.native_world)==original,"actual Restart retains accepted recipe/policy after edits "+id)
	cohorts.append({"demo":id,"quality":quality,"region":Array(expected),"policy_hash":policy.policy_hash,
		"initial_player":[24,222],"executed_ticks":12,"reset_generation":reset.session_generation})

func _refusals() -> void:
	var before: Dictionary = snapshot()
	expect(not owner.liquid_comparison_apply_active(bridge.default_liquid_policy(),false,false,"Play",2) and intact(before),
		"Controlled request cannot erase ordinary sampled ownership")
	owner._prepared_demo_actor_factory = func() -> Variant: return ActorRefusal.new()
	expect(not apply(1) and intact(before),"declared sampled-owner refusal preserves old World/player/native receipt/host cursor/record")
	owner._prepared_demo_actor_factory = Callable()
	owner._prepared_demo_commit_barrier = func() -> void: owner.liquid_comparison_clear_import()
	expect(not apply(1) and intact(before),"newer owner choice at final guard preserves complete accepted ordinary session")
	owner._prepared_demo_commit_barrier = Callable()
	owner.select_demo("physics_pit",false)
	owner.export_save();owner.import_save(owner.export_text)
	before = snapshot()
	var bodies: Array = owner.rigid_bodies.duplicate()
	var poses: PackedFloat32Array = PhysicalCandidate._pose_values(owner.rapier_bridge.pack_body_states())
	panel.refresh(owner.tower_context)
	expect(bodies.size()==3 and owner.rapier_bridge.is_initialized() and panel.apply_button.disabled,
		"imported Physics Pit body owner remains outside authored prepared allowlist")
	expect(not owner.liquid_comparison_apply_active(bridge.default_liquid_policy(),false,true,"Play",2)
		and intact(before) and owner.rigid_bodies==bodies
		and PhysicalCandidate._pose_values(owner.rapier_bridge.pack_body_states())==poses,
		"unsupported physical owner retains actual graph/poses and World on direct request")

func _import_identity() -> void:
	owner.select_demo("neon_works",false)
	if not expect(apply(),"ordinary prepared Baseline setup exists for cross-import"): return
	owner.native_world.paint_disc(700,700,0,1,0)
	var metadata: Dictionary = {"demo":"neon_works","player":[400,300,0,0],"material":2,"quality":0,
		"coherent":false,"adhesion":true,"glow":false,"bodies":[]}
	var save: Dictionary = CyberDemoSaveCodec.encode(bridge.export_level(owner.native_world),metadata)
	panel.import_button.pressed.emit()
	owner.ui.show_page("save");owner.ui.save_text.text = save.text;owner.ui.buttons["import"].pressed.emit()
	expect(owner.last_save_error.is_empty() and owner.liquid_comparison_import_state().applied
		and owner._accepted_demo.is_empty() and owner.liquid_comparison_active_definition().is_empty(),
		"actual prepared import admits known component-bound ordinary Baseline and retires curated identity")
	owner.ui.buttons["restart"].pressed.emit()
	expect(owner.native_world.material_at(700,700)==1 and owner.player.position==Vector2(400,300),
		"import Restart retains imported payload/metadata instead of misclassifying its demo ID as authored recipe")
	owner.liquid_comparison_clear_import();owner.ui.buttons["import"].pressed.emit()
	expect(owner.last_save_error.is_empty() and owner.liquid_comparison_active_definition().is_empty()
		and owner.native_world.get_applied_liquid_construction_receipt().is_empty(),
		"unarmed Current imported level is never silently promoted into the curated-demo recipe")
	owner.select_demo("neon_works",false)
	if expect(apply(),"ordinary prepared owner exists before unarmed legacy replacement"):
		owner.ui.show_page("save");owner.ui.save_text.text = save.text;owner.ui.buttons["import"].pressed.emit()
		expect(owner.last_save_error.is_empty() and not owner.micro_host.active()
			and owner.microscenario_liquid_setup.is_empty() and owner._accepted_demo.is_empty(),
			"accepted legacy replacement retires ordinary host cursors and setup identity")

func _current_control() -> void:
	owner.select_demo("waterworks",false)
	if expect(apply(6,3),"ordinary route admits explicit PF Water/Brine IN geometry3"):
		var inertial: Dictionary = owner.native_world.get_liquid_solver_policy()
		var initial: Dictionary = owner.native_world.get_applied_liquid_construction_receipt()
		var extension: Dictionary = {}
		for value: Dictionary in initial.solver_state_extensions:
			if value.family==4: extension = value
		expect(inertial.maximum_rule_radius==3 and inertial.physical_state_hash_version==3
			and extension.get("extension_digest","")==inertial.family_parameters.inertial_cellular_v1.extension_identity,
			"ordinary native IN instance geometry/version/extension readback agrees")
		owner.ui.buttons["restart"].pressed.emit()
		var reset: Dictionary = owner.native_world.get_applied_liquid_construction_receipt()
		expect(reset.session_generation>initial.session_generation and reset.maximum_rule_radius==3
			and reset.policy_hash==initial.policy_hash,"ordinary IN Restart retains actual geometry and selected policy")
		matched.inertial = {"geometry":inertial.maximum_rule_radius,"physical_hash_version":inertial.physical_state_hash_version,
			"extension":inertial.family_parameters.inertial_cellular_v1.extension_identity,"native_extension":extension}
	if expect(apply(0,3),"ordinary Current comparator explicitly admits matched geometry3"):
		var control: Dictionary = owner.native_world.get_liquid_solver_policy()
		expect(control.maximum_rule_radius==3 and control.physical_state_hash_version==2
			and control.assignments[0].applied_family=="freemass_v1","Current comparator retains its family at explicit geometry3")
		matched.current_comparator = {"geometry":control.maximum_rule_radius,"physical_hash_version":control.physical_state_hash_version}
	owner.select_demo("waterworks",false)
	var receipt: Dictionary = owner.native_world.get_liquid_solver_policy()
	expect(owner._accepted_demo.is_empty() and owner.micro_host.liquid_host_observation_record().is_empty()
		and owner.native_world.get_applied_liquid_construction_receipt().is_empty()
		and receipt.maximum_rule_radius==2 and receipt.assignments[0].applied_family=="freemass_v1",
		"ordinary Current constructor remains default and retires prepared identity")

func _failed_prepared_hint() -> void:
	# Actual native scheduling-capacity refusal, using the existing fault probe's
	# explicit constructor setting. No fabricated tick result or timing race.
	var prior: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity",null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",1)
	owner.native_world = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",prior)
	owner.select_demo("waterworks",false)
	if not expect(apply(),"prepared ordinary receipt exists before actual bounded-capacity failure"): return
	owner.ui.close_menu();owner.paused = false;owner.focused = true;owner.input_armed = false
	owner._physics_process(1.0/60.0)
	expect(owner.native_world.has_failed() and owner.paused and owner.ui.open
		and owner.ui.notice.text.contains("Current demo") and owner.ui.notice.text.contains("Prepared Restart requires a healthy World"),
		"actual quarantined prepared owner reports explicit Current/unarmed-import recovery instead of promising Restart")
	var before: Dictionary = snapshot()
	expect(not owner.restart_world() and owner.native_world.has_failed() and intact(before),
		"same-policy Restart preserves quarantined World/receipt/owner while healthy-retained support remains a shared gap")
	owner.select_demo("waterworks",false)
	expect(not owner.native_world.has_failed() and owner.native_world.get_tick_index()==0
		and owner.native_world.get_applied_liquid_construction_receipt().is_empty(),
		"explicit ordinary Current construction recovers without silent family fallback")

func finish() -> void:
	print("LIQUID_ORDINARY_DEMO_HOST_RESULT ",JSON.stringify({"ok":failures==0,"cohorts":cohorts,"matched_geometry":matched,
		"scope":"four ordinary synchronous body-free demos; no full-host/Wasm/body-contact qualification"}))
	print("LIQUID_ORDINARY_DEMO_HOST: %d assertions; %d failures" % [assertions,failures])
	if owner != null: owner.queue_free()
	quit(1 if failures else 0)
