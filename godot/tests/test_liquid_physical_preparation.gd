extends SceneTree

# Actual frozen Rapier poses -> native initial masks -> tick-zero receipt. The
# worker/main continuation is tested separately; no browser evidence is claimed.
const Candidate = preload("res://scripts/prepared_physical_session.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const DAM: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_PHYSICAL_PREPARATION: " + message)

func prepare(bridge: Variant, world: Variant, checked: Dictionary, policy: PackedInt32Array, states: Variant) -> int:
	return bridge.prepare_liquid_world(world,PackedInt32Array(checked.definition.rectangles),checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),policy,
		{"definition_hash":checked.hash,"seed":checked.definition.seed,"intent":"exploratory",
		"region":PackedInt32Array(checked.definition.interest.region),"initial_bodies":states})

func run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	await process_frame
	var candidate = Candidate.new()
	expect(candidate.prepare(host,[{"model":&"runner","producer":&"human","position":Vector2(64,64)}],9),
		"real provisional rig and equipment prepare")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not bridge.has_method(&"prepared_liquid_world_values") or candidate.session == null:
		expect(false,"fresh prepared-body adapter required")
		candidate.close();host.free();finish();return
	var source: Dictionary = Contract.parse(FileAccess.get_file_as_string(DAM))
	var definition: Dictionary = source.definition.duplicate(true)
	definition.rectangles = [0,0,256,256,0,16,16,160,160,3,0,200,256,8,1]
	definition.partial_water_fills = [];definition.events = [];definition.observations = [];definition.conditions = []
	var checked: Dictionary = Contract.validate(definition)
	expect(checked.ok,"water and hard-terrain fixture validates")
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	var states: PackedFloat32Array = candidate.initial_body_states()
	var token: int = prepare(bridge,world,checked,policy,PackedFloat32Array())
	expect(token > 0 and bridge.commit_liquid_world(world,token),"retained typed World installs before preparation")
	var retained_hash: String = world.get_physical_state_hash()
	var retained_receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	var retained_generation: int = world.get_liquid_policy_session_generation()
	var bad_inputs: Array = [[],PackedFloat32Array([1,2]),states.duplicate(),states.duplicate(),states.duplicate(),states.duplicate(),states.duplicate()]
	bad_inputs[2].append_array(states.slice(0,11)) # Duplicate native ID.
	bad_inputs[3][1] = NAN
	bad_inputs[4][9] = 0
	bad_inputs[5][10] = 16777216
	bad_inputs[6].resize(65*11)
	for invalid: Variant in bad_inputs:
		expect(prepare(bridge,world,checked,policy,invalid) == 0,"malformed body input refuses before replacement")
		expect(world.get_physical_state_hash() == retained_hash
			and world.get_liquid_policy_session_generation() == retained_generation
			and world.get_applied_liquid_construction_receipt().canonical_bytes == retained_receipt.canonical_bytes
			and world.get_liquid_construction_attempt().is_empty(),
			"host body-input refusal preserves World/receipt and fabricates no native attempt")
	token = prepare(bridge,world,checked,policy,states)
	expect(token > 0 and world.get_physical_state_hash() == retained_hash,"actual frozen poses prepare without touching retained World")
	var pending: Dictionary = bridge.prepared_liquid_world_values(world,token)
	expect(pending.initial_bodies == states and str(pending.initial_body_state_sha256).length() == 64,
		"copied pending facts identify exact original pose, velocity, mass and serial words")
	var identity: String = pending.initial_body_state_sha256
	var pending_hash: String = str(pending.candidate_physical_state_hash).lpad(16,"0")
	var terrain: PackedInt32Array = pending.terrain.duplicate()
	pending.initial_bodies[1] += 300
	pending.terrain[0] = 0
	var copy: Dictionary = bridge.prepared_liquid_world_values(world,token)
	expect(copy.initial_bodies == states and copy.terrain == terrain
		and copy.candidate_physical_state_hash == pending.candidate_physical_state_hash,
		"consumer writes cannot mutate pending body values or terrain")
	expect(candidate.install_terrain(copy.terrain),"actual native candidate terrain stages in permanent private physics space")
	for _frame: int in range(40):
		await physics_frame
		expect(candidate.verify_physics_frame() and candidate.prepare_terrain_budget(8,0),"frozen pose stays exact across real terrain-preparation frames")
		if candidate.ready(): break
	expect(candidate.ready() and world.get_physical_state_hash() == retained_hash
		and candidate.initial_body_states() == states,"both retained World and exact candidate poses survive asynchronous preparation")
	expect(bridge.commit_liquid_world(world,token),"matching one-use token commits after all physical work is ready")
	candidate.adopt()
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256);digest.update(receipt.canonical_bytes)
	expect(digest.finish().hex_encode() == receipt.receipt_hash
		and world.get_physical_state_hash() == pending_hash
		and str(receipt.physical_state_hash).lpad(16,"0") == pending_hash
		and receipt.completed_tick == 0 and receipt.initial_body_state_sha256 == identity
		and receipt.initial_body_count == states.size()/11,
		"applied native bytes bind actual initial masks; copied pose digest remains explicitly host metadata")
	expect(receipt.qualifications == 15 and not receipt.eligible_for_full_matched_evidence,
		"physical preparation does not invent full host/runtime provenance")
	var reference: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(bridge.build_water_feel_world(reference,PackedInt32Array(definition.rectangles),checked.transport.packed,
		PackedInt32Array(definition.water_semantics),PackedInt32Array()),"ordinary independent mask-law control builds")
	reference.prepare_rigid_body_coupling(states,false)
	var masks_equal: bool = true
	var occupied: int = 0
	var different: int = 0
	for y: int in range(24,112):
		for x: int in range(24,112):
			var actual: int = world.rigid_body_id_at(x,y)
			masks_equal = masks_equal and actual == reference.rigid_body_id_at(x,y)
			if actual != reference.rigid_body_id_at(x,y): different += 1
			if actual != 0: occupied += 1
	expect(masks_equal and occupied > 0,"prepared raster exactly preserves existing live-body mask law over real articulated poses (%d occupied, %d differences)" % [occupied,different])
	expect(world.water_experiment_observation(Vector2i(16,16),Vector2i(160,160)).water_integer == 160*160*255
		and reference.water_experiment_observation(Vector2i(16,16),Vector2i(160,160)).water_integer == 160*160*255,
		"initial masked Water remains exact stored authority, without overlap resolution or erasure")
	expect(world.get_hard_surface_chunk_rectangles() == terrain,"pending and applied native hard-terrain projections agree exactly")
	expect(bridge.prepared_liquid_world_values(world,token).is_empty()
		and not bridge.commit_liquid_world(world,token),"consumed token cannot read or commit a retired candidate")
	candidate.close();host.free();await process_frame
	finish()

func finish() -> void:
	print("LIQUID_PHYSICAL_PREPARATION: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
