extends SceneTree

# Actual native desktop recipe and one-use preparation, independently anchored
# to the pre-refactor DLL's complete CYSD tuple fingerprints. No app adoption,
# browser, retained-momentum contact or complete-host qualification is implied.
const Profiles = preload("res://scripts/transport_profiles.gd")
const FIXTURE: String = "res://tests/fixtures/lcb/default-desktop-demo-legacy.json"
const WATER_IN_FIXTURE: String = "res://tests/fixtures/lcb/default-desktop-demo-water-in-capability.json"
const LEGACY_FIXTURE_SHA256: String = "c557604e68790f289633b6b8a0d496ed5d5a084f451f2ca1143528da595dcb4d"
const LEGACY_NAMESPACE: Dictionary = {"policy_hash":"6e005e61219c01421e3fb404b1df4773120885d02f94eab1558efa6cc5c2ec10",
	"capability_matrix_digest":"55141a323670eac6c50971463cd5b0ba2d4e13b036739d9f69b25aac3c4d54c1","physical_state_hash_version":2}
const WATER_IN_NAMESPACE: Dictionary = {"policy_hash":"4b7922ad7badb443556d82ea0c624c259da7b75e85f92f87cdab216f95cab53a",
	"capability_matrix_digest":"33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237","physical_state_hash_version":2}
var assertions: int = 0
var failures: int = 0
var sections: Dictionary = {}
var bridge: Variant
var defaults: PackedInt32Array
var cohorts: Array = []

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("LIQUID_DEFAULT_DEMO_PREPARATION: "+message)
	return ok
func sha(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256);h.update(bytes)
	return h.finish().hex_encode()
func options(radius: int = 2) -> Dictionary:
	return {"region":PackedInt32Array([0,0,320,180]),"intent":"exploratory","pacing":"host_paced",
		"simulation_window_enabled":true,"cadence_lod_enabled":false,"liquid_surface_adhesion_enabled":true,
		"maximum_rule_radius":radius}
func configured(row: Dictionary) -> Variant:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}),"one-worker legacy configuration")
	if int(row.profile)>=0:
		var resolved: Dictionary = Profiles.resolve(Profiles.preset(int(row.profile)))
		expect(bridge.build_water_feel_world(world,PackedInt32Array([0,0,1,1,2]),resolved.packed,
			PackedInt32Array([1,int(row.mass_bits),int(row.coherence_ticks),0]),PackedInt32Array()),"configure inherited Water and transport")
	expect(world.reset_demo_world(),"legacy default reset")
	world.set_simulation_window(Vector2i.ZERO,Vector2i(320,180),0,0)
	world.set_cadence_lod_enabled(false)
	return world
func choose(request: PackedInt32Array, family: String, variant: String = "reference", material: int = 3) -> PackedInt32Array:
	for item: Dictionary in bridge.liquid_policy_assignment_choices(request,material):
		if item.accepted and item.family==family and item.variant==variant: return item.request
	expect(false,"expected admitted native assignment "+family+"/"+variant)
	return PackedInt32Array()
func snapshot(world: Variant) -> Dictionary:
	return {"hash":world.get_physical_state_hash(),"receipt":world.get_applied_liquid_construction_receipt(),
		"generation":world.get_liquid_policy_session_generation(),"policy":world.get_liquid_solver_policy()}
func intact(world: Variant, before: Dictionary) -> bool: return snapshot(world)==before
func prepare(world: Variant, request: PackedInt32Array, opts: Dictionary = {}) -> int:
	return bridge.prepare_liquid_default_demo(world,request,options() if opts.is_empty() else opts)
func namespace_matches(identity: Dictionary, known: Dictionary) -> bool:
	return identity.size()==known.size() and identity.get("policy_hash","")==known.policy_hash \
		and identity.get("capability_matrix_digest","")==known.capability_matrix_digest \
		and identity.get("physical_state_hash_version",-1)==known.physical_state_hash_version
func control_fixture(legacy: Dictionary, identity: Dictionary) -> Dictionary:
	if namespace_matches(identity,LEGACY_NAMESPACE): return legacy
	if not namespace_matches(identity,WATER_IN_NAMESPACE): return {}
	var candidate: Variant = JSON.parse_string(FileAccess.get_file_as_string(WATER_IN_FIXTURE))
	if not candidate is Dictionary or not namespace_matches(candidate.get("namespace",{}),WATER_IN_NAMESPACE) \
		or candidate.get("legacy_fixture_sha256","")!=LEGACY_FIXTURE_SHA256: return {}
	return candidate
func run() -> void:
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	if not expect(bridge!=null and bridge.has_method(&"prepare_liquid_default_demo"),"native default recipe API is required"):
		finish();return
	defaults = bridge.default_liquid_policy()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not expect(parsed is Dictionary and parsed.get("cohorts",[]).size()==4,"four immutable old-DLL controls"):
		finish();return
	expect(sha(FileAccess.get_file_as_bytes(FIXTURE))==LEGACY_FIXTURE_SHA256,"original pre-Water fixture remains byte-for-byte immutable")
	var applied: Dictionary = bridge.validate_liquid_policy(defaults).receipt
	var identity: Dictionary = {"policy_hash":applied.policy_hash,"capability_matrix_digest":applied.capability_matrix_digest,
		"physical_state_hash_version":int(applied.physical_state_hash_version)}
	var selected_controls: Dictionary = control_fixture(parsed,identity)
	if not expect(not selected_controls.is_empty() and selected_controls.get("cohorts",[]).size()==4,
		"actual policy/capability/hash-version selects one separately frozen default namespace"):
		finish();return
	var unknown: Dictionary = identity.duplicate();unknown.capability_matrix_digest = "0".repeat(64)
	expect(control_fixture(parsed,unknown).is_empty(),"an unregistered identity cannot accept arbitrary new physical hashes")
	cohorts = selected_controls.cohorts
	var before: int = failures
	for row: Dictionary in cohorts:
		var legacy: Variant = configured(row)
		expect(sha(bridge.export_level(legacy))==row.payload_sha256,"legacy refactor keeps every original tuple at precision "+str(row.mass_bits))
		expect(legacy.get_physical_state_hash()==row.physical_hash,"legacy physical identity remains unchanged")
		expect(legacy.get_default_demo_identity().native_recipe_id=="cybersand-desktop-default-demo-v1","legacy native origin is copied rather than inferred from scene labels")
		var world: Variant = configured(row)
		var laws: Dictionary = world.get_liquid_run_receipt({}).components
		var retained: Dictionary = snapshot(world)
		var token: int = prepare(world,defaults)
		if not expect(token>0,"native default prepares: "+str(bridge.get_last_error())): continue
		expect(intact(world,retained),"prepare does not replace the old World or applied receipt")
		expect(bridge.commit_liquid_world(world,token),"one-use default candidate commits")
		expect(world.get_default_demo_identity().prepared and world.get_default_demo_identity().session_generation==world.get_liquid_policy_session_generation(),"prepared native origin binds actual committed generation")
		var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
		expect(receipt.get("native_recipe_id","")=="cybersand-desktop-default-demo-v1" and receipt.get("setup_kind","")=="native_cell_fixture","native recipe identity is explicit")
		expect(sha(receipt.canonical_bytes)==receipt.receipt_hash and not receipt.eligible_for_full_matched_evidence,"exact native receipt retains qualification")
		expect(sha(bridge.export_level(world))==row.payload_sha256,"prepared Current reproduces the entire old native payload")
		var actual: Dictionary = world.get_liquid_run_receipt({}).components
		expect(actual.water_policy==laws.water_policy and actual.transport_profile==laws.transport_profile,"independent inherited Water and transport settings survive preparation")
		for tick: int in range(4):
			expect(legacy.simulation_tick() and world.simulation_tick(),"both ordinary paths execute tick "+str(tick))
			expect(legacy.get_physical_state_hash()==row.ticks[tick],"legacy four-tick physical control stays exact")
			expect(bridge.export_level(world)==bridge.export_level(legacy),"all material/state/temperature tuples continue identically")
	sections.recipe_and_law_parity = failures==before
	before = failures
	var selected: Variant = configured(cohorts[0])
	for request: PackedInt32Array in [choose(defaults,"cellular_yield_v1")]:
		var token: int = prepare(selected,request)
		if expect(token>0,"full native Water recipe admits selected family"):
			expect(bridge.commit_liquid_world(selected,token),"selected native default commits")
			expect(selected.get_liquid_solver_policy().envelope==request,"readback is the actual selected policy")
			expect(sha(bridge.export_level(selected))==cohorts[0].payload_sha256,"selected whole-cell recipe does not alter initial Water")
	# The original sparse Water checker contains more than the fixed gas-table
	# capacity of initially sealed, Water-adjacent Empty components. Refuse at
	# construction; the retained World must not become a tick-one quarantine.
	for variant: String in ["reference","cached","cached_dormant"]:
		var retained: Dictionary = snapshot(selected)
		expect(prepare(selected,choose(defaults,"pressure_flow_v1",variant))==0 and intact(selected,retained),
			"actual initial pressure capacity refuses transactionally for "+variant)
		expect(bridge.get_last_liquid_policy_refusal().get("code","")=="capacity_refused"
			and bridge.get_last_error().contains("capacity"),"pressure capacity refusal is native typed admission")
		expect(selected.get_liquid_construction_attempt().get("kind","")=="construction_attempt"
			and not selected.has_failed(),"actual refusal attempt retains a healthy accepted World")
	var inertial: PackedInt32Array = choose(defaults,"inertial_cellular_v1","reference",CyberCellWorld.BRINE)
	if not inertial.is_empty():
		var retained: Dictionary = snapshot(selected)
		expect(prepare(selected,inertial)==0 and intact(selected,retained),"IN geometry refuses radius two transactionally")
		var token: int = prepare(selected,inertial,options(3))
		if expect(token>0,"explicit matched geometry admits Brine IN"):
			expect(bridge.commit_liquid_world(selected,token),"explicit geometry candidate commits")
			expect(selected.get_applied_liquid_construction_receipt().maximum_rule_radius==3,"native execution radius remains explicit")
	sections.selected_policy = failures==before
	before = failures
	var masked: Variant = configured(cohorts[0])
	var body := PackedFloat32Array([1,124,92,0,8,14,0,0,0,1,1])
	var opts: Dictionary = options();opts.initial_bodies=body
	var retained: Dictionary = snapshot(masked)
	var token: int = prepare(masked,defaults,opts)
	if expect(token>0,"default physical input prepares"):
		expect(intact(masked,retained),"pending masks do not alter live authority")
		expect(bridge.prepared_liquid_character_box_collides(masked,token,Vector2(120,88),Vector2(8,8),0),"candidate owns its initial body raster")
		var values: Dictionary = bridge.prepared_liquid_world_values(masked,token)
		expect(values.initial_bodies==body and not values.initial_body_state_sha256.is_empty(),"actual copied body input has an identity")
		expect(bridge.commit_liquid_world(masked,token),"prepared native mask commits")
		expect(masked.get_applied_liquid_construction_receipt().initial_body_count==1,"applied receipt retains body count")
	sections.prepared_masks = failures==before
	before = failures
	for bad: Dictionary in [{"definition_hash":"0".repeat(64)},{"seed":1},{"initial_bodies":PackedFloat32Array([1,2,3])},{"region":PackedInt32Array([-1,0,32,32])}]:
		var invalid: Dictionary = options();invalid.merge(bad,true)
		retained=snapshot(masked)
		expect(prepare(masked,defaults,invalid)==0 and intact(masked,retained),"invalid default input refuses without authority changes")
	token=prepare(masked,defaults)
	if expect(token>0,"stale fence control prepares"):
		masked.paint_disc(400,300,0,1,0)
		retained=snapshot(masked)
		expect(not bridge.commit_liquid_world(masked,token) and intact(masked,retained),"intervening edit rejects stale token and retains edited authority")
		expect(not bridge.commit_liquid_world(masked,token),"refused token remains one use")
	sections.refusal_and_token_fences = failures==before
	before=failures
	var diagnostic: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(diagnostic.diagnostic_reset({"workers":1,"support_cells":1,"exchange_off":true,"contact":1.0}),"nondefault diagnostic owner installs")
	expect(diagnostic.diagnostic_fill_rect(Vector2i(400,300),Vector2i.ONE,1,0),"diagnostic-only writer is initially available")
	token=prepare(diagnostic,defaults)
	if expect(token>0,"native default replaces an explicit diagnostic constructor"):
		expect(bridge.commit_liquid_world(diagnostic,token),"diagnostic replacement commits")
		var actual: Dictionary = diagnostic.get_liquid_run_receipt({}).components
		expect(actual.interaction_policy=="8:9:30" and actual.diagnostic_physics=="0:-1","default reset restores production interaction and diagnostic laws")
		retained=snapshot(diagnostic)
		expect(not diagnostic.diagnostic_fill_rect(Vector2i(400,300),Vector2i.ONE,1,0) and intact(diagnostic,retained),"default preparation retires the diagnostic-only editing lifecycle")
	sections.default_lifecycle=failures==before
	before=failures
	var origin: Variant = configured(cohorts[0])
	expect(bridge.build_world(origin,PackedInt32Array([0,0,1,1,2])) and origin.get_default_demo_identity().is_empty(),"rectangle construction retires native default origin")
	expect(origin.reset_demo_world() and not origin.get_default_demo_identity().is_empty(),"explicit legacy reset restores native default origin")
	var payload: PackedByteArray = bridge.export_level(origin)
	expect(bridge.import_level(origin,payload) and origin.get_default_demo_identity().is_empty(),"imported identical tuples do not acquire authored-recipe origin")
	expect(origin.reset_demo_world(),"default origin control restores")
	var resolved: Dictionary = Profiles.resolve(Profiles.preset(0))
	token=bridge.prepare_liquid_world(origin,PackedInt32Array([0,0,1,1,2]),resolved.packed,PackedInt32Array([1,8,12,0]),PackedInt32Array(),defaults,
		{"definition_hash":"0".repeat(64),"region":PackedInt32Array([0,0,320,180])})
	if expect(token>0,"foreign prepared origin control prepares"):
		expect(bridge.commit_liquid_world(origin,token) and origin.get_default_demo_identity().is_empty(),"other prepared constructors retire default origin")
	sections.origin_lifetime=failures==before
	finish()
func finish() -> void:
	print("LIQUID_DEFAULT_DEMO_PREPARATION: %d assertions; %d failures; completed=%s" % [assertions,failures,JSON.stringify(sections)])
	quit(1 if failures else 0)
