extends SceneTree

const SECTIONS: Array[String] = ["actual_user_route","refusal_atomicity","thermal_normalization","restart_identity","legacy_preservation"]
const PhysicalCandidate = preload("res://scripts/prepared_physical_session.gd")
var assertions: int = 0
var failures: int = 0
var sections: Dictionary = {}
var owner: Control
var panel: CyberLiquidComparisonPanel
var bridge: Variant
var payload := PackedByteArray()
var encoded: Dictionary = {}
var metadata: Dictionary = {"demo":"neon_works","player":[400.0,300.0,2.0,-3.0],
	"material":16,"quality":0,"coherent":false,"adhesion":false,"glow":false,"bodies":[]}
var applied: Dictionary = {}
var applied_record: Dictionary = {}
var observations: Dictionary = {}

func _initialize() -> void:
	for name: String in SECTIONS: sections[name] = false
	_run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1;push_error("LIQUID_LEVEL_IMPORT_HOST: "+message)
	return value

func section(name: String, body: Callable) -> void:
	var before: int = failures;body.call();sections[name] = failures==before

func _put(x: int, y: int, material: int, a: int = 0, temperature: int = 200) -> void:
	var offset: int = (y*1024+x)*5
	payload[offset] = material;payload[offset+1] = a;payload[offset+2] = 0
	payload.encode_u16(offset+3,temperature & 65535)

func user_import(text: String) -> void:
	owner.ui.show_page("save")
	owner.ui.save_text.text = text
	owner.ui.buttons["import"].pressed.emit()

func arm(preset: int, normalized: bool = false, radius: int = 2) -> bool:
	panel.select_preset(preset);panel.session_picker.select(1)
	panel.geometry_picker.select(1 if radius==3 else 0)
	panel.normalize_water.button_pressed = normalized
	panel.refresh(owner.tower_context)
	if not expect(panel.import_button != null and not panel.import_button.disabled,"actual import selection control is available"): return false
	panel.import_button.pressed.emit()
	return expect(owner.liquid_comparison_import_state().armed,"actual control arms a copied next-import selection")

func intact(before: Dictionary) -> bool:
	return owner.native_world.get_physical_state_hash()==before.hash \
		and owner.native_world.get_applied_liquid_construction_receipt()==before.receipt \
		and owner.native_world.get_liquid_run_receipt({})==before.run_receipt \
		and owner.player==before.player and owner.liquid_level_host_observation_record()==before.record

func snapshot() -> Dictionary:
	return {"hash":owner.native_world.get_physical_state_hash(),"receipt":owner.native_world.get_applied_liquid_construction_receipt(),
		"run_receipt":owner.native_world.get_liquid_run_receipt({}),"player":owner.player,"record":owner.liquid_level_host_observation_record()}

func payload_sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode()

func _run() -> void:
	owner = load("res://web_main.tscn").instantiate();root.add_child(owner);await process_frame
	owner.set_process(false);owner.set_physics_process(false)
	bridge = owner.demo_bridge;panel = owner.microscenario_panel.liquid_panel
	if not expect(owner.ready_to_play and bridge.has_method(&"prepare_liquid_level"),"actual synchronous application and fresh native importer are ready"):
		_finish();return
	payload = PackedByteArray([0,0,0,200,0])
	for _power: int in range(20): payload.append_array(payload.duplicate())
	_put(300,240,3,127,310);_put(301,240,3,128,315)
	_put(302,240,0,0,700);_put(303,240,3,0,-12)
	for x: int in range(340,346):
		_put(x,260,16);_put(x,240,24)
	encoded = CyberDemoSaveCodec.encode(payload,metadata)
	if not expect(encoded.ok,"actual portable CYSD codec produces the user input"):
		_finish();return
	section("actual_user_route",_actual_user_route)
	section("thermal_normalization",_thermal_normalization)
	section("refusal_atomicity",_refusal_atomicity)
	section("restart_identity",_restart_identity)
	section("legacy_preservation",_legacy_preservation)
	_finish()

func _actual_user_route() -> void:
	var before: Dictionary = snapshot()
	panel.session_picker.select(0)
	expect(not panel.arm_import() and not owner.liquid_comparison_import_state().armed,
		"Controlled selection cannot silently erase the imported sampled owner")
	if not arm(1): return
	expect(intact(before),"arming a policy leaves the actual running World/player/receipt unchanged")
	user_import(encoded.text)
	expect(not owner.last_save_error.is_empty() and intact(before) and owner.liquid_comparison_import_state().armed,
		"actual Import button refuses fractional whole-cell Water without normalization and retains all prior state")
	if not arm(1,true): return
	user_import(encoded.text)
	if not expect(owner.last_save_error.is_empty() and owner.liquid_comparison_import_state().applied,
		"actual Import button applies the explicit normalized level"): return
	applied = owner.native_world.get_applied_liquid_construction_receipt()
	applied_record = owner.liquid_level_host_observation_record()
	expect(applied.setup_kind=="native_cell_fixture" and applied.source_payload_sha256==payload_sha256(payload),
		"native receipt identifies the actual imported payload")
	expect(applied.run_intent=="exploratory" and applied.pacing=="host_paced" and applied.initial_body_count==0
		and applied.qualifications==15 and not applied.eligible_for_full_matched_evidence,
		"imported sampled owner keeps frozen native qualifications and honest execution intent")
	expect(owner.player.position==Vector2(400,300) and owner.player.velocity==Vector2(2,-3)
		and owner.quality==0 and owner.current_view_size==Vector2i(320,180) and owner.camera_origin==Vector2(244,217)
		and owner.selected_material_id==16 and not owner.coherent_liquid_emission and not owner.glow_enabled,
		"actual saved player, velocity, quality, camera and presentation are adopted from staged metadata")
	expect(applied.region==PackedInt32Array([228,199,352,216]) and not applied.liquid_surface_adhesion_enabled
		and owner.native_world.get_liquid_run_receipt({}).components.simulation_region=="228:199:352:216"
		and applied.physical_state_hash==owner.native_world.get_physical_state_hash(),
		"final quality buffers/region/adhesion are actual before native receipt capture")
	expect(not applied_record.is_empty() and applied_record.identity.native_receipt_hash==applied.receipt_hash
		and not applied_record.values.host_eligible_for_full_matched_evidence
		and applied_record.values.native_applied_run.canonical_bytes_hex==applied.canonical_bytes.hex_encode(),
		"copied owner observation binds the actual native bytes and retains false full-host eligibility")
	observations.normalized = {"native_receipt_hash":applied.receipt_hash,"source_payload_sha256":applied.source_payload_sha256,
		"prepared_payload_hash":applied.prepared_payload_hash,"physical_hash":applied.physical_state_hash,
		"host_observation_digest":applied_record.identity.digest,"normalization":applied.normalization}

func _thermal_normalization() -> void:
	if not expect(not applied.is_empty(),"normalized application exists for exact tuple checks"): return
	var normal: Dictionary = applied.normalization
	expect(normal.rule=="water-normalize-v1" and normal.water_before==255 and normal.water_after==255
		and normal.positive_delta==127 and normal.negative_delta==127 and normal.net_delta==0,
		"zero-net normalization still reports both exact gross ledger changes")
	for item: Array in [[300,240,0,0,310],[301,240,3,255,315],[302,240,0,0,700],[303,240,0,0,-12]]:
		var cell: Dictionary = bridge.inspect_cell(owner.native_world,Vector2i(item[0],item[1]))
		expect(cell.material==item[2] and cell.state_a==item[3] and cell.temperature_raw==item[4],
			"actual imported material/mass/signed thermal authority survives preparation: "+str(item))

func _refusal_atomicity() -> void:
	var before: Dictionary = snapshot()
	owner._prepared_level_character_factory = func() -> Variant: return null
	if arm(2): user_import(encoded.text)
	expect(not owner.last_save_error.is_empty() and intact(before),"declared sampled-owner refusal retains World/player/canonical receipt/full owner record")
	owner._prepared_level_character_factory = Callable()
	owner._prepared_level_commit_barrier = func() -> void: owner.liquid_comparison_clear_import()
	if arm(2): user_import(encoded.text)
	expect(not owner.last_save_error.is_empty() and intact(before),"newer owner choice at final fence refuses a prepared token before World/record adoption")
	owner._prepared_level_commit_barrier = Callable()
	var invalid_meta: Dictionary = metadata.duplicate(true);invalid_meta.demo = "physics_pit";invalid_meta.bodies = [[160,176,0,0,0,0,false]]
	var body_save: Dictionary = CyberDemoSaveCodec.encode(payload,invalid_meta)
	if arm(2): user_import(body_save.text)
	expect(not owner.last_save_error.is_empty() and intact(before),"saved physical body route explicitly refuses before touching the applied sampled level")

func _restart_identity() -> void:
	if not expect(not applied.is_empty(),"accepted source exists for reset"): return
	owner.liquid_comparison_clear_import()
	owner.native_world.paint_disc(300,240,0,1,0)
	owner.ui.buttons["restart"].pressed.emit()
	var next: Dictionary = owner.native_world.get_applied_liquid_construction_receipt()
	expect(owner.last_save_error.is_empty() and next.session_generation>applied.session_generation
		and next.source_payload_sha256==applied.source_payload_sha256 and next.prepared_payload_hash==applied.prepared_payload_hash
		and next.physical_state_hash==applied.physical_state_hash,
		"actual Restart button rebuilds original accepted payload/policy/normalization after edits with a new generation")
	expect(owner.player.position==Vector2(400,300) and owner.player.velocity==Vector2(2,-3)
		and owner.liquid_level_host_observation_record().identity.digest!=applied_record.identity.digest,
		"restart adopts a fresh sampled owner and copied observation for the new native generation")
	var retired_owner: RefCounted = owner._accepted_level
	var baseline: Dictionary = CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0))
	expect(owner.native_world.diagnostic_reset({"transport":baseline.packed}),"separate native construction changes the owned generation")
	var changed: Dictionary = snapshot()
	if arm(2): user_import(encoded.text)
	expect(not owner.last_save_error.is_empty() and intact(changed) and owner._accepted_level==retired_owner,
		"an old private owner cannot exempt configured Baseline after native generation/receipt retirement")
	owner.select_demo("neon_works",false)
	if not arm(6,false,3): return
	panel.damping_numerator.value = 7
	panel.import_button.pressed.emit()
	user_import(encoded.text)
	if not expect(owner.last_save_error.is_empty(),"actual user controls import pressure Water plus IN Brine with explicit radius3"): return
	var policy: Dictionary = owner.native_world.get_liquid_solver_policy()
	expect(policy.maximum_rule_radius==3 and policy.physical_state_hash_version==3
		and policy.family_parameters.inertial_cellular_v1.damping_numerator==7,
		"actual imported mixed family parameters and instance identity read back natively")
	owner.ui.close_menu();owner.paused = false
	for _tick: int in range(30): owner._physics_process(1.0/60.0)
	owner.paused = true;owner.ui.show_page("save")
	var motion: bool = false
	for y: int in range(230,310):
		for x: int in range(330,356):
			if owner.native_world.material_at(x,y)==24:
				var cell: Dictionary = owner.native_world.inspect_inertial_cell(Vector2i(x,y))
				motion = motion or cell.vx!=0 or cell.vy!=0 or cell.ax!=0 or cell.ay!=0
	expect(not owner.native_world.has_failed() and owner.native_world.get_tick_index()==30 and motion,
		"ordinary synchronous application tick path executes the imported mixed World with positive retained IN motion")
	observations.mixed = {"completed_ticks":owner.native_world.get_tick_index(),"physical_hash":owner.native_world.get_physical_state_hash(),
		"projection":owner.native_world.get_liquid_comparison_hash(1),"retained_inertial_motion":motion}

func _legacy_preservation() -> void:
	owner.liquid_comparison_clear_import()
	user_import(encoded.text)
	var policy: Dictionary = owner.native_world.get_liquid_solver_policy()
	expect(owner.last_save_error.is_empty() and policy.maximum_rule_radius==2 and policy.physical_state_hash_version==2
		and owner.native_world.get_applied_liquid_construction_receipt().is_empty()
		and owner.liquid_level_host_observation_record().is_empty() and owner.microscenario_liquid_setup.is_empty(),
		"unarmed ordinary import restores Current defaults/radius2 and retires prepared receipt/host identity")
	var water: Dictionary = bridge.inspect_cell(owner.native_world,Vector2i(300,240))
	expect(water.material==3 and water.state_a==127 and water.temperature_raw==310,
		"legacy import preserves fractional Water and thermal cells without implicit normalization")
	owner.select_demo("physics_pit",false)
	var before: Dictionary = snapshot();var bodies: Array = owner.rigid_bodies.duplicate()
	expect(bodies.size()==3 and owner.rapier_bridge.is_initialized(),"old ordinary Physics Pit has three actual Rapier bodies before refusal")
	# Sampling advances its frame serial. Compare the actual pose/velocity/mass
	# state, as the existing prepared-physical refusal tests do.
	var poses: PackedFloat32Array = PhysicalCandidate._pose_values(owner.rapier_bridge.pack_body_states())
	if arm(1,true): user_import(encoded.text)
	expect(not owner.last_save_error.is_empty() and intact(before) and owner.rigid_bodies==bodies
		and PhysicalCandidate._pose_values(owner.rapier_bridge.pack_body_states())==poses,
		"unsupported current physical owner retains actual old World/body graph/poses on prepared import refusal")
	_nondefault_setting_refusals()

func _nondefault_setting_refusals() -> void:
	var tuned: Dictionary = CyberTransportProfiles.resolve(CyberTransportProfiles.preset(1))
	var cases: Array[Dictionary] = [{"support_cells":1},{"mercury_period":1},{"exchange_off":true},{"viscosity":5},{"transport":tuned.packed}]
	for index: int in cases.size():
		owner.liquid_comparison_clear_import();owner.select_demo("neon_works",false)
		expect(owner.native_world.diagnostic_reset(cases[index]),"native nondefault configuration installs for cohort "+str(index))
		# The original user import retains inherited laws/profiles. It also retires
		# the earlier private prepared generation, even for a configured profile.
		user_import(encoded.text)
		var before: Dictionary = snapshot()
		expect(owner.last_save_error.is_empty() and before.receipt.is_empty() and before.record.is_empty(),
			"ordinary Current import preserves the independently configured owner for cohort "+str(index))
		if arm(2): user_import(encoded.text)
		expect(not owner.last_save_error.is_empty() and intact(before) and owner.liquid_comparison_import_state().armed,
			"explicit import refuses unsupported inherited settings before mutation, cohort "+str(index))
		observations["nondefault_"+str(index)] = {"interaction":before.run_receipt.components.interaction_policy,
			"diagnostic":before.run_receipt.components.diagnostic_physics,"transport":before.run_receipt.components.transport_profile,
			"error":owner.last_save_error,"world_and_receipts_retained":intact(before)}

func _finish() -> void:
	print("LIQUID_LEVEL_IMPORT_HOST_RESULT ",JSON.stringify({"ok":failures==0,"sections":sections,"observations":observations,
		"scope":"actual normal synchronous import controls; native/host full matched eligibility remains false"}))
	print("LIQUID_LEVEL_IMPORT_HOST: %d assertions; %d failures" % [assertions,failures])
	if owner != null: owner.queue_free()
	quit(1 if failures else 0)
