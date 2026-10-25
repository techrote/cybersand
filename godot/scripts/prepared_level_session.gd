extends RefCounted

# A decoded level is a finite reconstruction, not a saved simulation session.
# This owner retains copied import inputs and a private sampled player; only
# native owns the pending World. No live state changes before commit().
const Evidence = preload("res://scripts/liquid_host_evidence.gd")
var _bridge: Variant
var _world: Variant
var _token: int = 0
var _payload := PackedByteArray()
var _metadata: Dictionary = {}
var _selection: Dictionary = {}
var _evidence: RefCounted
var _identity: Dictionary = {}
var _receipt: Dictionary = {}
var _accepted_transport_component: String = ""
var staged_player: CyberSampledCharacter
var last_error: String = ""

func prepare(bridge: Variant, world: Variant, payload: PackedByteArray, metadata: Dictionary,
		selection: Dictionary, profile: PackedInt32Array, water: PackedInt32Array,
		options: Dictionary, player_profile: Dictionary, runtime_recovery: bool,
		character_factory: Callable = Callable()) -> bool:
	if _token != 0 or not _identity.is_empty(): return false
	_bridge = bridge;_world = world
	_token = int(bridge.prepare_liquid_level(world,payload,profile,water,selection.policy,options))
	if _token == 0:
		last_error = bridge.get_last_error();return false
	var candidate: Variant = character_factory.call() if character_factory.is_valid() else CyberSampledCharacter.new()
	if not candidate is CyberSampledCharacter:
		return _refuse("Imported sampled player preparation refused")
	staged_player = candidate
	staged_player.configure_profile(player_profile)
	staged_player.configure_runtime_enclosure_recovery(runtime_recovery)
	staged_player.reset(Vector2(metadata.player[0],metadata.player[1]))
	staged_player.velocity = Vector2(metadata.player[2],metadata.player[3])
	var captured: Dictionary = bridge.prepared_liquid_run_capture(world,_token)
	if captured.get("lifecycle","") != "prepared" or int(captured.get("token",0)) != _token:
		return _refuse("Prepared imported level token was retired")
	_receipt = captured.native_run_encoding.duplicate(true)
	var owner_inputs: Dictionary = {"scope":"decoded_level_and_sampled_owner_inputs_v1",
		"input_owner":"synchronous_application_owner","decoded_metadata":metadata.duplicate(true),
		"native_source_payload_sha256":str(_receipt.get("source_payload_sha256","")),
		"prepared_player":{"position":[staged_player.position.x,staged_player.position.y],
			"velocity":[staged_player.velocity.x,staged_player.velocity.y],"profile":player_profile.duplicate(true),
			"runtime_enclosure_recovery":runtime_recovery},
		"native_initial_execution":{"intent":_receipt.run_intent,"pacing":_receipt.pacing,
			"region":Array(_receipt.region),"simulation_window_enabled":_receipt.simulation_window_enabled,
			"cadence_lod_enabled":_receipt.cadence_lod_enabled,"liquid_surface_adhesion_enabled":_receipt.liquid_surface_adhesion_enabled,
			"worker_threads":_receipt.worker_threads,"maximum_rule_radius":_receipt.maximum_rule_radius}}
	var observed: Dictionary = Evidence.collect(bridge,_receipt,owner_inputs)
	if not observed.get("ok",false): return _refuse(str(observed.get("error","Imported host observation refused")))
	_evidence = observed.evidence
	var evidence_values: Dictionary = _evidence.snapshot()
	_identity = {"schema_version":1,"kind":"qualified_liquid_level_host_observation_identity",
		"digest":_evidence.digest(),"native_receipt_hash":_receipt.receipt_hash,
		"session_generation":_receipt.session_generation,"source_payload_sha256":_receipt.source_payload_sha256,
		"run_intent":_receipt.run_intent,"host_eligible_for_full_matched_evidence":false,
		"publication_matches_current_path_file":evidence_values.runtime.publication_manifest.artifact_matches_current_path_file,
		"mapped_module_binding":"unverified","complete_host_binding":"unverified"}
	_identity.make_read_only()
	_payload = payload.duplicate();_metadata = metadata.duplicate(true);_selection = selection.duplicate(true)
	return true

func _refuse(reason: String) -> bool:
	last_error = reason
	if _token != 0: _bridge.discard_liquid_world(_world,_token)
	_token = 0;staged_player = null;_evidence = null;_identity = {};_receipt = {}
	return false

func commit() -> bool:
	if _token == 0: return false
	if not _bridge.commit_liquid_world(_world,_token): return _refuse(str(_bridge.get_last_error()))
	_token = 0
	# Native configuration is construction-only. Keep its actual copied readback
	# for later rebuild admission; this observation cannot refuse an applied run.
	_accepted_transport_component = str(_world.get_liquid_run_receipt({}).get("components",{}).get("transport_profile",""))
	return true

func retains_prepared_transport(world: Variant, current: String) -> bool:
	return not identity(world).is_empty() and not _accepted_transport_component.is_empty() \
		and current == _accepted_transport_component \
		and world.get_applied_liquid_construction_receipt().get("receipt_hash","") == _receipt.get("receipt_hash","")

func identity(world: Variant) -> Dictionary:
	if _token != 0 or _identity.is_empty() or world != _world \
		or int(world.get_liquid_policy_session_generation()) != int(_identity.session_generation): return {}
	return _identity.duplicate(true)

func record(world: Variant) -> Dictionary:
	var current: Dictionary = identity(world)
	if current.is_empty(): return {}
	return {"identity":current,"values":_evidence.snapshot(),"canonical_bytes_hex":_evidence.canonical_bytes().hex_encode()}

func reconstruction() -> Dictionary:
	return {"payload":_payload.duplicate(),"metadata":_metadata.duplicate(true),"selection":_selection.duplicate(true)}

func close_pending() -> void:
	if _token != 0: _bridge.discard_liquid_world(_world,_token)
	_token = 0
