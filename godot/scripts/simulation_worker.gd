class_name CyberSimulationWorker
extends RefCounted

# This worker owns every mutable simulation object. The main thread sends only
# small commands and receives immutable snapshots, so rendering never reads a
# PackedByteArray while the cellular solver is modifying it.
const MicroCatalogue = preload("res://scripts/microscenario_catalogue.gd")
const MicroHost = preload("res://scripts/microscenario_host.gd")
const PlayerEnvironmentProfiles = preload("res://scripts/player_environment_profiles.gd")
const ActorSession = preload("res://scripts/actor_prototype_session.gd")
const UsableSession = preload("res://scripts/usable_session.gd")
const PreparedSampled = preload("res://scripts/prepared_sampled_session.gd")
const LiquidHostEvidence = preload("res://scripts/liquid_host_evidence.gd")
const PhysicalEffects = preload("res://scripts/physical_actor_effects.gd")
const PhysicalUsables = preload("res://scripts/physical_usable_runtime.gd")
const SIMULATION_HZ: float = 60.0
const FIXED_TIMESTEP: float = 1.0 / SIMULATION_HZ
const TICK_INTERVAL_USEC: int = 16667
const MAX_BACKLOG_TICKS: int = 3
const EMISSION_MATERIAL_MASK: int = 255
const EMISSION_FLAGS_SHIFT: int = 8
const DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC: int = 16667
const HARD_SURFACE_SNAPSHOT_INTERVAL_USEC: int = 250000
const RENDER_PATCH_METADATA_STRIDE: int = 6
const MAX_PENDING_RENDER_PATCHES: int = 256
const MAX_BRUSH_FOOTPRINT_CELLS: int = 4096
const MAX_PENDING_BRUSH_COMMANDS: int = 8

var _thread: Thread = Thread.new()
var _mutex: Mutex = Mutex.new()
# The Linux test build uses the compiled native phased backend. Unsupported
# platforms retain the script world as a functional compatibility fallback.
var _world = _create_world()
var _character: CyberSampledCharacter = CyberSampledCharacter.new()
var _actor_session: CyberActorPrototypeSession = ActorSession.new()
var _usable_session: CyberUsableSession = UsableSession.new()
# Worker-exclusive representation state. Only one player owner is active at a
# time; PCHAR representation changes are applied through fresh reset.
var _sampled_character_enabled: bool = true
var _player_environment_profile: Dictionary = PlayerEnvironmentProfiles.preset(
	PlayerEnvironmentProfiles.PRESET_CURRENT
)
var _pending_player_environment_profile: Dictionary = {}

var _running: bool = false
var _paused: bool = false
var _simulation_failed: bool = false # Exclusive worker state; main reads status under mutex.
var _horizontal_input: float = 0.0
var _jetpack_active: bool = false
var _interest_center: Vector2i = Vector2i.ZERO
var _view_origin: Vector2i = Vector2i.ZERO
var _view_size: Vector2i = Vector2i(320, 180)
var _horizontal_buffer: int = 32
var _vertical_buffer: int = 36
var _simulation_window_enabled: bool = true
var _cadence_lod_enabled: bool = true
var _liquid_surface_adhesion_enabled: bool = true
var _render_snapshot_interval_usec: int = DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
var _rigid_body_states: PackedFloat32Array = PackedFloat32Array()
var _rigid_body_epoch: int = 0
var _physical_effect_epoch: int = 0
var _physical_effect_generations := PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0])
var _pending_physical_effects: Array = []
var _physical_effects = PhysicalEffects.new() # Worker-exclusive consumer.
var _physical_effect_receipts: Array = []
# Mutex-owned admission telemetry is fixed-size; native application receipts
# remain worker-exclusive and describe actual cell changes separately.
var _physical_effect_accepted_batches: int = 0
var _physical_effect_accepted_requests: int = 0
var _physical_effect_refused_batches: int = 0
var _physical_effect_refused_requests: int = 0
var _physical_effect_overflow_batches: int = 0
var _physical_effect_last_admission: Dictionary = {}
var _physical_usables := PhysicalUsables.new() # Worker-exclusive material/projectile/device owner.
var _physical_usable_frame: Dictionary = {} # Mutex-owned copied publication.
var _pending_physical_usables: Array = []
var _physical_usable_inflight: Dictionary = {} # One unconsumed request per actor, including extracted work.
var _physical_usable_admission: Dictionary = {}
var _physical_usable_cancelled_generations := PackedInt64Array([-1, -1, -1, -1, -1, -1, -1, -1])

var _pending_emissions: Array[Vector4i] = []
var _pending_cell_emissions: Array[Dictionary] = []
var _reset_requested: bool = false
var _reset_spawn: Vector2 = Vector2(150.0, 145.0)
var _reset_sampled_character_enabled: bool = true
var _reset_runtime_enclosure_recovery_enabled: bool = true
var _reset_actor_definitions: Array = []
var _reset_actor_prototype_request: bool = false
var _actor_prototype_status: String = ""
var _actor_prototype_request_serial: int = 0
var _reset_actor_prototype_serial: int = 0
var _actor_prototype_result_serial: int = 0
var _actor_prototype_reset_applied: bool = false
var _lab_request: Dictionary = {} # One bounded pending control command; newest wins.
var _lab_request_revision: int = 0
var _construction_settings_revision: int = 0
var _prepared_frame_hold: Dictionary = {}
var _prepared_frame_serial: int = 0
# The continuation itself belongs exclusively to the simulation owner. Only
# copied value publications/readiness cross the mutex to the main-thread owner.
var _pending_physical_liquid: Dictionary = {}
var _prepared_physical_publication: Dictionary = {}
var _prepared_physical_ready: Dictionary = {}
var _prepared_physical_frame_hold: Dictionary = {}
var _prepared_liquid_owner_error: String = ""
var _default_liquid_identity: Dictionary = {}
var _default_liquid_published_record: Dictionary = {} # Mutex-owned immutable slot.
# Private dependency seams exercise declared precommit actor/equipment failures.
var _prepared_actor_factory: Callable = Callable()
var _prepared_usable_factory: Callable = Callable()
# Optional deterministic test barrier, called by the exclusive owner after
# native preparation and before the queue-mutex commit fence. No scene objects.
var _controlled_liquid_prepare_barrier: Callable = Callable()
var _lab_active: bool = false
var _lab_floor: int = 0
var _lab_status: String = ""
var _lab_schedule: Array = [] # At most two floor-local release deadlines.
var _lab_inputs: Array = [] # Bounded observation input history.
var _lab_profile: Dictionary = CyberTransportProfiles.preset(0)
var _lab_profile_hash: String = ""
var _scenario_host: CyberMicroScenarioHost = MicroHost.new()
var _micro_active: bool = false
var _scenario_request_serial: int = 0
var _scenario_request_applied: bool = false
var _water_exit_request_serial: int = 0
var _water_exit_request_applied: bool = false
var _micro_capture: Dictionary = {}
var _micro_capture_serial: int = 0
var _water_lab_active: bool = false
var _water_policy: Dictionary = {}
var _liquid_policy_receipt: Dictionary = {}
var _liquid_policy_receipt_generation: int = -1
var _water_policy_hash: String = ""
var _water_policy_provenance: Dictionary = {}
var _water_recipe: Dictionary = {}
var _water_recipe_hash: String = ""
var _water_blind_label: String = ""
var _water_action_index: int = 0
var _water_action_history: Array = []
var _water_observations: Array = []
var _water_initial_integer: int = 0
var _water_initial_requested_numerator_255: int = 0
var _water_initial_quantization_error_numerator_255: int = 0
var _water_current_integer: int = 0
var _water_explicit_source: int = 0
var _water_explicit_sink: int = 0

func queue_lab(command: Dictionary) -> void:
	_mutex.lock()
	_lab_request_revision += 1
	_lab_request = command.duplicate(true)
	_lab_request["_owner_request_revision"] = _lab_request_revision
	_pending_physical_effects.clear()
	_cancel_physical_usables_locked()
	if command.has("step") or command.has("reset") or command.has("water_reset") or command.has("scenario_reset") or command.has("default_liquid_reset") or command.has("floor"): _paused = true
	_mutex.unlock()

static func prepared_owner_execution(definition: Dictionary, settings: Dictionary) -> Dictionary:
	var origin := Vector2i(int(definition.camera_origin[0]), int(definition.camera_origin[1]))
	var size := Vector2i(480,270)
	var horizontal: int = int(settings.horizontal_buffer)
	var vertical: int = int(settings.vertical_buffer)
	var first := Vector2i(clampi(origin.x-horizontal,0,1023), clampi(origin.y-vertical,0,1023))
	var last := Vector2i(clampi(origin.x+size.x+horizontal,first.x+1,1024),
		clampi(origin.y+size.y+vertical,first.y+1,1024))
	var region: Array = [first.x,first.y,last.x-first.x,last.y-first.y] \
		if settings.simulation_window_enabled else [0,0,1024,1024]
	return {"region":region, "simulation_window_enabled":settings.simulation_window_enabled,
		"cadence_lod_enabled":settings.cadence_lod_enabled,
		"liquid_surface_adhesion_enabled":settings.liquid_surface_adhesion_enabled,
		"view_origin":origin, "view_size":size, "horizontal_buffer":horizontal,"vertical_buffer":vertical}

func acknowledge_prepared_liquid_configuration(serial: int) -> void:
	# Main has installed the accepted camera/configuration before releasing the
	# initial owner frame hold. Old presentation frames cannot rewrite tick zero.
	_mutex.lock()
	if serial == _prepared_frame_serial:
		_prepared_frame_hold = {}
		_prepared_frame_serial = 0
	if serial == int(_prepared_physical_frame_hold.get("serial",-1)):
		_prepared_physical_frame_hold = {}
	_mutex.unlock()

func prepared_physical_liquid_values() -> Dictionary:
	_mutex.lock()
	var copied: Dictionary = _prepared_physical_publication.duplicate(true)
	_mutex.unlock()
	return copied

func complete_prepared_physical_liquid(identity: Dictionary, ready: bool, reason: String = "") -> bool:
	_mutex.lock()
	var current: bool = not _prepared_physical_publication.is_empty() and _prepared_physical_ready.is_empty()
	for key: String in ["token","serial","epoch","instance_id","initial_body_state_sha256"]:
		current = current and identity.get(key) == _prepared_physical_publication.get(key)
	if current: _prepared_physical_ready = {"ready":ready,"reason":reason}
	_mutex.unlock()
	return current

func _retire_prepared_physical_liquid(reason: String = "") -> void:
	if _pending_physical_liquid.is_empty(): return
	_pending_physical_liquid.bridge.discard_liquid_world(_world,int(_pending_physical_liquid.token))
	_pending_physical_liquid = {}
	_mutex.lock()
	_prepared_physical_publication = {};_prepared_physical_ready = {}
	_mutex.unlock()
	if not reason.is_empty(): _lab_status = "Prepared physical replacement refused; " + reason

func _advance_prepared_physical_liquid() -> Dictionary:
	if _pending_physical_liquid.is_empty(): return {}
	_mutex.lock()
	var current: bool = _running and not _reset_requested \
		and int(_pending_physical_liquid.request_revision) == _lab_request_revision \
		and int(_pending_physical_liquid.settings_revision) == _construction_settings_revision
	var readiness: Dictionary = _prepared_physical_ready.duplicate(true)
	_mutex.unlock()
	if not current:
		_retire_prepared_physical_liquid("request, settings or owner lifetime changed")
		return {}
	if readiness.is_empty(): return {}
	if not readiness.ready:
		_retire_prepared_physical_liquid(str(readiness.reason))
		return {}
	var command: Dictionary = _pending_physical_liquid.command.duplicate(true)
	command["_prepared_physical_commit"] = true
	return command

func _prepared_liquid_continuation_token(command: Dictionary) -> int:
	if not command.get("_prepared_physical_commit",false): return 0
	var original: Dictionary = command.duplicate(true)
	original.erase("_prepared_physical_commit")
	if _pending_physical_liquid.is_empty() or original != _pending_physical_liquid.get("command",{}):
		_lab_status = "Prepared physical continuation binding changed; retained session preserved"
		_retire_prepared_physical_liquid()
		return -1
	return int(_pending_physical_liquid.token)

func _commit_controlled_liquid_candidate(bridge: Variant, token: int, request_revision: int,
		settings_revision: int, command: Dictionary, definition: Dictionary, profile: Dictionary,
		owner_execution: Dictionary) -> Variant:
	var physical: Dictionary = command.get("controlled_liquid_setup",{}).get("physical_owner",{})
	var completing: bool = bool(command.get("_prepared_physical_commit",false))
	var staged: Dictionary = _pending_physical_liquid.get("staged",{}) if completing else PreparedSampled.prepare(bridge, _world, token,
		Vector2(definition.player_start[0],definition.player_start[1]),
		bool(command.get("sampled_character_enabled",false)),
		bool(command.get("runtime_enclosure_recovery_enabled",true)), profile,
		command.get("exploratory_actor_definitions",[]), _actor_session.identity_epoch(),
		_prepared_actor_factory, _prepared_usable_factory)
	if not staged.get("ok",false):
		_prepared_liquid_owner_error = str(staged.get("error","Prepared owner was retired"))
		return false
	if not physical.is_empty() and not completing:
		var values: Dictionary = bridge.prepared_liquid_world_values(_world,token)
		if values.is_empty():
			_prepared_liquid_owner_error = bridge.get_last_error()
			return false
		values.serial = int(command.get("scenario_request_serial",0))
		values.epoch = int(physical.epoch)
		values.instance_id = int(physical.instance_id)
		_mutex.lock()
		var current: bool = _running and not _reset_requested and request_revision == _lab_request_revision \
			and settings_revision == _construction_settings_revision
		if current:
			_pending_physical_liquid = {"bridge":bridge,"token":token,"command":command.duplicate(true),
				"request_revision":request_revision,"settings_revision":settings_revision,"staged":staged}
			_prepared_physical_publication = values
			_prepared_physical_ready = {}
		_mutex.unlock()
		return {"deferred":true} if current else false
	if _controlled_liquid_prepare_barrier.is_valid(): _controlled_liquid_prepare_barrier.call()
	# Retain the previous sessions through the no-fail swap; refusal never calls
	# clear/configure on them or changes their epochs, equipment or actor state.
	var retained_actors: CyberActorPrototypeSession = _actor_session
	var retained_usables: CyberUsableSession = _usable_session
	_mutex.lock()
	var current: bool = _running and not _reset_requested and request_revision == _lab_request_revision \
		and settings_revision == _construction_settings_revision
	if completing:
		current = current and not _pending_physical_liquid.is_empty() \
			and token == int(_pending_physical_liquid.get("token",0)) and bool(_prepared_physical_ready.get("ready",false))
	var committed: bool = bridge.commit_liquid_world(_world, token) if current else false
	if committed:
		_actor_session = staged.actors
		_usable_session = staged.usables
		_character = staged.character
		_sampled_character_enabled = staged.enabled
		if completing:
			_rigid_body_states = physical.initial_bodies.duplicate()
			_rigid_body_epoch = int(physical.epoch)
			_prepared_physical_frame_hold = {"serial":int(command.get("scenario_request_serial",0)),
				"epoch":int(physical.epoch)}
			_player_environment_profile = profile.duplicate(true)
			_set_physical_actor_epoch_locked(int(physical.epoch))
		if definition.interest.policy == "owner" or definition.execution.policy == "owner":
			_prepared_frame_hold = owner_execution
			_prepared_frame_serial = int(command.get("scenario_request_serial",0))
			_view_origin = owner_execution.view_origin
			_view_size = owner_execution.view_size
			_horizontal_buffer = owner_execution.horizontal_buffer
			_vertical_buffer = owner_execution.vertical_buffer
			_simulation_window_enabled = owner_execution.simulation_window_enabled
			_cadence_lod_enabled = owner_execution.cadence_lod_enabled
			_liquid_surface_adhesion_enabled = owner_execution.liquid_surface_adhesion_enabled
	_mutex.unlock()
	# These references intentionally remain alive until after the mutex fence.
	retained_actors = null
	retained_usables = null
	return committed

func _lab_release(index: int) -> void:
	if _water_lab_active or _micro_active: return
	var plugs: Array[Rect2i] = CyberExperimentTower.plugs(_lab_floor)
	if index < 0 or index >= plugs.size(): return
	var plug: Rect2i = plugs[index]
	for y: int in range(plug.position.y,plug.end.y):
		for x: int in range(plug.position.x,plug.end.x): _world.paint_disc(x,y,0,0,0)

# Applied LCB-001 liquid solver policy receipt, forwarded unchanged. It is
# re-read only after native commits a World replacement (a new generation).
func _liquid_policy_receipt_snapshot() -> Dictionary:
	if _world == null or not _world.has_method(&"get_liquid_policy_session_generation"):
		return {}
	var generation: int = int(_world.get_liquid_policy_session_generation())
	if generation != _liquid_policy_receipt_generation:
		_liquid_policy_receipt = _world.get_liquid_solver_policy()
		_liquid_policy_receipt_generation = generation
	return _liquid_policy_receipt.duplicate(true)

func _water_observe(action: Dictionary = {}) -> Dictionary:
	if not _world.has_method(&"water_experiment_observation"):
		return {}
	var origin: Vector2i=Vector2i.ZERO
	var size: Vector2i=Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT)
	if not action.is_empty():
		origin=Vector2i(int(action.x),int(action.y))
		size=Vector2i(int(action.width),int(action.height))
	return _world.water_experiment_observation(origin,size)

func _sync_micro_water_state() -> void:
	var state: Dictionary = _scenario_host.legacy_water_state()
	_water_action_index = int(state.action_index)
	_water_action_history = state.actions
	_water_observations = state.observations
	_water_explicit_source = int(state.explicit_source)
	_water_explicit_sink = int(state.explicit_sink)
	_water_current_integer = int(state.current)

func _apply_due_water_actions() -> bool:
	var ok: bool = _scenario_host.before_tick()
	if _water_lab_active: _sync_micro_water_state()
	if not ok: _lab_status = _scenario_host.last_error
	return ok

func _prepared_liquid_install_options(command: Dictionary, definition: Dictionary,
		setup: Dictionary) -> Dictionary:
	_prepared_liquid_owner_error = ""
	var validated: Dictionary = CyberMicroScenarioContract.validate(definition)
	if not validated.ok:
		_lab_status = "Prepared setup rejected; " + str(validated.error)
		return {"ok":false}
	_mutex.lock()
	var settings_revision: int = _construction_settings_revision
	var profile: Dictionary = command.get("_prepared_player_environment_profile",_player_environment_profile).duplicate(true)
	var pending_profile: bool = not _pending_player_environment_profile.is_empty()
	var owner: Dictionary = prepared_owner_execution(validated.definition, {
		"simulation_window_enabled":_simulation_window_enabled,"cadence_lod_enabled":_cadence_lod_enabled,
		"liquid_surface_adhesion_enabled":_liquid_surface_adhesion_enabled,
		"horizontal_buffer":_horizontal_buffer,"vertical_buffer":_vertical_buffer})
	_mutex.unlock()
	if pending_profile:
		_lab_status = "Prepared liquid request retired by a pending player environment profile"
		return {"ok":false}
	var final_setup: Dictionary = setup.duplicate(true)
	final_setup.owner_execution = owner
	var guard: Callable = _commit_controlled_liquid_candidate.bind(
		int(command.get("_owner_request_revision",-1)),settings_revision,command,validated.definition,profile,owner)
	return {"ok":true,"definition":validated.definition,"transport":validated.transport,"setup":final_setup,"guard":guard}

func _default_liquid_origin() -> Dictionary:
	return _world.get_default_demo_identity() if _world.has_method(&"get_default_demo_identity") else {}

func liquid_default_host_observation_record() -> Dictionary:
	# Main reads only the immutable accepted slot and published generation. It
	# never calls the live World, or copies the full record on every render frame.
	_mutex.lock()
	var generation: int = int(_published_snapshot.lab_context.get("native_default_demo",{}).get("session_generation",-1)) \
		if _published_snapshot != null else -1
	var result: Dictionary = _default_liquid_published_record.duplicate(true) \
		if generation == int(_default_liquid_published_record.get("identity",{}).get("session_generation",-2)) else {}
	_mutex.unlock()
	return result

func _apply_prepared_default_liquid(command: Dictionary) -> bool:
	_scenario_request_serial = int(command.get("scenario_request_serial",0))
	_scenario_request_applied = false
	var origin: Dictionary = _default_liquid_origin()
	var setup: Dictionary = command.get("controlled_liquid_setup",{})
	var physical: Dictionary = setup.get("physical_owner",{})
	if origin.get("native_recipe_id","") != "cybersand-desktop-default-demo-v1" \
		or not origin.get("healthy",false) or origin.get("session_generation",-1) != command.get("expected_default_generation",-2) \
		or _lab_active or _micro_active or _water_lab_active or _actor_session.active() \
		or not _sampled_character_enabled or not command.get("sampled_character_enabled",false) \
		or setup.get("intent","") != "exploratory" or not command.get("exploratory_actor_definitions",[]).is_empty() \
		or physical.get("kind","") != "reference_body" or physical.get("epoch",-1) != 0 \
		or not physical.get("instance_id") is int or physical.instance_id == 0 \
		or not physical.get("initial_bodies") is PackedFloat32Array \
		or physical.initial_bodies.size() != 3*CyberRigidBodyCoupling.INPUT_STRIDE:
		_lab_status = "Prepared native default demo refused; original constructor, healthy sampled owner and staged reference bodies required"
		if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
		return false
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if bridge == null or not bridge.has_method(&"prepare_liquid_default_demo"):
		_lab_status = "Native default demo preparation requires the rebuilt native adapter"
		return false
	_mutex.lock()
	var settings_revision: int = _construction_settings_revision
	var profile: Dictionary = command.get("_prepared_player_environment_profile",_player_environment_profile).duplicate(true)
	var pending_profile: bool = not _pending_player_environment_profile.is_empty()
	var owner: Dictionary = command.get("default_owner_execution",{}).duplicate(true)
	var settings_match: bool = (owner.get("view_size") == _view_size
		and owner.get("horizontal_buffer") == _horizontal_buffer and owner.get("vertical_buffer") == _vertical_buffer
		and owner.get("simulation_window_enabled") == _simulation_window_enabled
		and owner.get("cadence_lod_enabled") == _cadence_lod_enabled
		and owner.get("liquid_surface_adhesion_enabled") == _liquid_surface_adhesion_enabled)
	_mutex.unlock()
	if pending_profile or not settings_match or not owner.get("view_origin") is Vector2i:
		_lab_status = "Prepared native default demo retired by owner settings or player profile"
		if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
		return false
	var first := Vector2i(clampi(owner.view_origin.x-owner.horizontal_buffer,0,1023),clampi(owner.view_origin.y-owner.vertical_buffer,0,1023))
	var last := Vector2i(clampi(owner.view_origin.x+owner.view_size.x+owner.horizontal_buffer,first.x+1,1024),
		clampi(owner.view_origin.y+owner.view_size.y+owner.vertical_buffer,first.y+1,1024))
	owner.region = [first.x,first.y,last.x-first.x,last.y-first.y] if owner.simulation_window_enabled else [0,0,1024,1024]
	var options: Dictionary = {"region":PackedInt32Array(owner.region),"intent":"exploratory","pacing":"host_paced",
		"simulation_window_enabled":owner.simulation_window_enabled,"cadence_lod_enabled":owner.cadence_lod_enabled,
		"liquid_surface_adhesion_enabled":owner.liquid_surface_adhesion_enabled,
		"normalization":setup.get("normalization",""),"maximum_rule_radius":setup.get("maximum_rule_radius",2),
		"initial_bodies":physical.initial_bodies}
	var token: int = _prepared_liquid_continuation_token(command)
	if token < 0: return false
	if token == 0: token = bridge.prepare_liquid_default_demo(_world,command.get("liquid_policy",PackedInt32Array()),options)
	if token == 0:
		_lab_status = "Prepared native default demo refused; " + str(bridge.get_last_error())
		return false
	var captured: Dictionary = bridge.prepared_liquid_run_capture(_world,token)
	if captured.get("lifecycle","") != "prepared" or captured.get("token",0) != token:
		bridge.discard_liquid_world(_world,token)
		_lab_status = "Prepared native default demo capture retired"
		if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
		return false
	var receipt: Dictionary = captured.native_run_encoding
	# Profile finalization adds its hash through GDScript member syntax, whose
	# key is a StringName. Copy keys explicitly into the frozen pure-value claim
	# vocabulary while retaining every actual profile value and its hash.
	var claim_profile: Dictionary = {}
	for key: Variant in profile: claim_profile[str(key)] = profile[key]
	var owner_inputs: Dictionary = {"scope":"native_default_recipe_and_owner_inputs_v1",
		"input_owner":"exclusive_desktop_simulation_owner","native_recipe_id":origin.native_recipe_id,
		"player_start":[150,145],"player_environment_profile":claim_profile,
		"sampled_runtime_recovery_enabled":command.get("runtime_enclosure_recovery_enabled",true),
		"native_initial_execution":{"intent":receipt.run_intent,"pacing":receipt.pacing,"region":Array(receipt.region),
			"simulation_window_enabled":receipt.simulation_window_enabled,"cadence_lod_enabled":receipt.cadence_lod_enabled,
			"liquid_surface_adhesion_enabled":receipt.liquid_surface_adhesion_enabled,
			"worker_threads":receipt.worker_threads,"maximum_rule_radius":receipt.maximum_rule_radius},
		"native_initial_body_input":{"values":Array(physical.initial_bodies),"sha256":receipt.initial_body_state_sha256,
			"body_count":receipt.initial_body_count}}
	var observed: Dictionary = LiquidHostEvidence.collect(bridge,receipt,owner_inputs)
	if not observed.get("ok",false):
		bridge.discard_liquid_world(_world,token)
		_lab_status = "Prepared native default observation refused; " + str(observed.get("error","unknown"))
		if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
		return false
	var staged_identity: Dictionary = {"schema_version":1,"kind":"qualified_liquid_host_observation_identity",
		"digest":observed.evidence.digest(),"native_receipt_hash":receipt.receipt_hash,
		"session_generation":receipt.session_generation,"native_recipe_id":origin.native_recipe_id,
		"run_intent":receipt.run_intent,"host_eligible_for_full_matched_evidence":false,
		"publication_matches_current_path_file":observed.evidence.snapshot().runtime.publication_manifest.artifact_matches_current_path_file,
		"mapped_module_binding":"unverified","complete_host_binding":"unverified"}
	staged_identity.make_read_only()
	var record: Dictionary = {"identity":staged_identity,"values":observed.evidence.snapshot(),
		"canonical_bytes_hex":observed.evidence.canonical_bytes().hex_encode()}
	_freeze_capture(record)
	# Owner adapter data supplies no MicroScenario or caller-authored geometry.
	var sampled_owner: Dictionary = {"player_start":[150,145],"interest":{"policy":"owner"},"execution":{"policy":"owner"}}
	var result: Variant = _commit_controlled_liquid_candidate(bridge,token,int(command.get("_owner_request_revision",-1)),
		settings_revision,command,sampled_owner,profile,owner)
	if result is Dictionary and result.get("deferred",false): return false
	if not result is bool or not result:
		bridge.discard_liquid_world(_world,token)
		_lab_status = "Prepared native default replacement retired; " + _prepared_liquid_owner_error
		if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
		return false
	if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
	_default_liquid_identity = staged_identity
	_mutex.lock();_default_liquid_published_record = record;_mutex.unlock()
	_world_generation += 1
	_scenario_host.clear();_lab_active = false;_micro_active = false;_water_lab_active = false
	_micro_capture = {};_lab_schedule.clear();_lab_inputs.clear()
	_simulation_failed = false;_scenario_request_applied = true
	_lab_status = "Native default demo installed with selected liquids and original reference bodies"
	return true

func _apply_lab(command: Dictionary) -> bool:
	if command.is_empty(): return false
	if command.has("default_liquid_reset"): return _apply_prepared_default_liquid(command)
	if command.has("reset"):
		_water_exit_request_serial = int(command.get("water_exit_request_serial",0))
		_water_exit_request_applied = false
		if not ClassDB.class_exists(&"CyberDemoBridge") or not _world.has_method(&"has_failed"):
			_lab_status = "Experiment Tower requires the native backend"
			return false
		var resolved: Dictionary = command.profile if command.has("profile") else CyberTransportProfiles.resolve(_lab_profile)
		if not resolved.get("ok",false):
			_lab_status = "Profile rejected; running world preserved"
			return false
		var tower_definition: Dictionary = MicroCatalogue.tower(resolved.profile)
		var tower_setup: Dictionary = command.get("controlled_liquid_setup",{})
		var tower_guard: Callable = Callable()
		if not tower_setup.is_empty():
			_scenario_request_serial = int(command.get("scenario_request_serial",0))
			_scenario_request_applied = false
			if tower_setup.get("intent","") != "exploratory" or not command.get("sampled_character_enabled",false) \
				or not tower_setup.get("physical_owner",{}).is_empty():
				_lab_status = "Prepared Tower requires its sampled exploratory owner"
				return false
			tower_definition = MicroCatalogue.prepared_tower(resolved.profile,int(command.get("floor",_lab_floor)))
			var prepared: Dictionary = _prepared_liquid_install_options(command,tower_definition,tower_setup)
			if not prepared.ok: return false
			tower_definition = prepared.definition;tower_setup = prepared.setup;tower_guard = prepared.guard
			resolved = prepared.transport
		if not _scenario_host.install(
			_world,
			tower_definition,
			str(command.get("scenario_mode", "Inspect")),true,command.get("liquid_policy",null),tower_setup,tower_guard
		):
			_lab_status = _scenario_host.last_error
			return false
		_world_generation += 1
		if tower_setup.is_empty():
			_activate_sampled_character(Vector2(tower_definition.player_start[0],tower_definition.player_start[1]),true)
		else:
			_scenario_request_applied = true
		_lab_profile = resolved.profile.duplicate(true)
		_lab_profile_hash = str(resolved.hash)
		_lab_active = true
		_lab_schedule.clear();_lab_inputs.clear()
		_simulation_failed = false
		_lab_status = "%s / profile v1 %s / recipe v%d / seed 0" % [str(_lab_profile.name),_lab_profile_hash.left(12),CyberExperimentTower.VERSION]
		if not tower_setup.is_empty() and _scenario_host.summary().get("failed",false):
			_lab_status = "Experiment Tower installed; apparatus failed: " + _scenario_host.last_error
		_water_lab_active=false
		_micro_active=false
		_micro_capture={}
		_water_exit_request_applied = true
	if command.has("water_reset"):
		var water_setup: Dictionary = command.get("controlled_liquid_setup",{})
		if not water_setup.is_empty():
			_scenario_request_serial = int(command.get("scenario_request_serial",0))
			_scenario_request_applied = false
		if not ClassDB.class_exists(&"CyberDemoBridge") or not _world.has_method(&"get_water_experiment_policy"):
			_lab_status="Water Feel Lab requires the current native backend"
			return false
		var resolved: Dictionary=CyberWaterExperimentProfiles.resolve(
			{},{},command.get("water_policy",{}))
		if not resolved.get("ok",false) or (
			command.has("water_policy_hash") and str(command.water_policy_hash)!=str(resolved.hash)
		):
			_lab_status="Water policy rejected; running world preserved"
			return false
		var recipe: Dictionary=CyberWaterFeelScenarios.recipe(
			str(resolved.policy.scenario_id),int(resolved.policy.seed))
		if recipe.is_empty():
			_lab_status="Water scenario rejected; running world preserved"
			return false
		var profile_result: Dictionary=CyberTransportProfiles.resolve(
			CyberTransportProfiles.preset(0))
		var water_definition: Dictionary = MicroCatalogue.water(resolved)
		var water_guard: Callable = Callable()
		var continuation_token: int = _prepared_liquid_continuation_token(command)
		if continuation_token < 0: return false
		if not water_setup.is_empty():
			var physical: Dictionary = water_setup.get("physical_owner",{})
			var reference_body: bool = not physical.is_empty()
			if water_setup.get("intent","") != "exploratory" \
				or not str(command.get("blind_label","")).is_empty() or not _water_blind_label.is_empty() \
				or not command.get("sampled_character_enabled",false) or bool(recipe.body_enabled) != reference_body:
				_lab_status = "Prepared Water Feel rejected; requires an unblinded sampled Exploratory owner and staged reference bodies"
				return false
			if reference_body and (physical.get("kind","") != "reference_body" \
				or not physical.get("epoch") is int or physical.epoch != 0 \
				or not physical.get("instance_id") is int or physical.instance_id == 0 \
				or not physical.get("initial_bodies") is PackedFloat32Array \
				or physical.initial_bodies.size() != 3*CyberRigidBodyCoupling.INPUT_STRIDE):
				_lab_status = "Prepared Water Feel reference body values rejected; retained owner preserved"
				return false
			var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
			var admitted: Dictionary = bridge.validate_liquid_policy(command.get("liquid_policy",bridge.default_liquid_policy()))
			var source_refusal: String = MicroCatalogue.prepared_water_source_refusal(admitted.get("receipt",{}),recipe)
			if not source_refusal.is_empty():
				_lab_status = source_refusal
				return false
			water_definition = MicroCatalogue.prepared_water(resolved)
			var prepared: Dictionary = _prepared_liquid_install_options(command,water_definition,water_setup)
			if not prepared.ok: return false
			water_definition = prepared.definition;water_setup = prepared.setup;water_guard = prepared.guard
		var retained_host_error: String = _scenario_host.last_error
		var retained_host_refusal: Dictionary = _scenario_host.last_liquid_policy_refusal
		if not _scenario_host.install(_world,water_definition,str(command.get("scenario_mode","Inspect")),true,
			command.get("liquid_policy",null),water_setup,water_guard,continuation_token):
			if not _pending_physical_liquid.is_empty() and not command.get("_prepared_physical_commit",false):
				_scenario_host.last_error = retained_host_error
				_scenario_host.last_liquid_policy_refusal = retained_host_refusal
				return false
			_lab_status="Water Apply + Reset rejected; "+_scenario_host.last_error
			if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
			return false
		if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
		_world_generation += 1
		_lab_profile=profile_result.profile.duplicate(true)
		_lab_profile_hash=str(profile_result.hash)
		_lab_active=true
		_water_lab_active=true
		_micro_active=false
		_micro_capture={}
		_water_policy=resolved.policy.duplicate(true)
		_water_policy_hash=str(resolved.hash)
		_water_policy_provenance=command.get("water_policy_provenance",{}).duplicate(true)
		_water_recipe=recipe.duplicate(true)
		_water_recipe_hash=CyberWaterFeelScenarios.recipe_hash(recipe)
		_water_blind_label=str(command.get("blind_label",""))
		_water_action_index=0
		_water_action_history.clear()
		_water_observations.clear()
		_water_explicit_source=0
		_water_explicit_sink=0
		_water_initial_integer=int(_water_observe().get("water_integer",0))
		_water_current_integer=_water_initial_integer
		_water_initial_requested_numerator_255=0
		for offset: int in range(0,recipe.partial_water_fills.size(),6):
			_water_initial_requested_numerator_255+=(
				int(recipe.partial_water_fills[offset+2])
				*int(recipe.partial_water_fills[offset+3])
				*int(recipe.partial_water_fills[offset+4])
				*int(resolved.derived.maximum))
		_water_initial_quantization_error_numerator_255=(
			_water_initial_integer*255-_water_initial_requested_numerator_255)
		_lab_schedule.clear();_lab_inputs.clear()
		_simulation_failed=false
		if water_setup.is_empty(): _activate_sampled_character(Vector2(recipe.player_start), true)
		else: _scenario_request_applied = true
		if _water_blind_label!="":
			_lab_status="Water Feel candidate %s / scenario %s / seed %d" % [
				_water_blind_label,str(_water_policy.scenario_id),int(_water_policy.seed)]
		else:
			_lab_status="Water Feel unblinded / policy %s / recipe %s / seed %d" % [
				_water_policy_hash.left(12),_water_recipe_hash.left(12),
				int(_water_policy.seed)]
		if not water_setup.is_empty() and _scenario_host.summary().get("failed",false):
			_lab_status = "Water Feel installed; apparatus failed: " + _scenario_host.last_error
	if command.has("scenario_reset"):
		_scenario_request_serial = int(command.get("scenario_request_serial", 0))
		_scenario_request_applied = false
		var actor_definitions: Array = command.get("exploratory_actor_definitions", [])
		var controlled_setup: Dictionary = command.get("controlled_liquid_setup", {})
		var exploratory_liquid: bool = controlled_setup.get("intent", "controlled") == "exploratory"
		var physical: Dictionary = controlled_setup.get("physical_owner",{})
		var continuation_token: int = _prepared_liquid_continuation_token(command)
		if continuation_token < 0: return false
		if not physical.is_empty() and (not exploratory_liquid
			or not MicroCatalogue.exploratory_actor_map(command.scenario_reset)
			or str(command.get("scenario_mode","Inspect")) == "Benchmark"
			or not bool(command.scenario_reset.body_enabled) or bool(command.scenario_reset.player_enabled)
			or bool(command.get("sampled_character_enabled",true)) or not actor_definitions.is_empty()
			or not physical.get("epoch") is int or int(physical.epoch) < 1
			or not physical.get("instance_id") is int or int(physical.instance_id) == 0
			or not physical.get("initial_bodies") is PackedFloat32Array or physical.initial_bodies.is_empty()):
			_lab_status = "Prepared physical ownership requires a bounded exploratory body request"
			return false
		if not controlled_setup.is_empty() and not exploratory_liquid and (not actor_definitions.is_empty() \
			or bool(command.get("sampled_character_enabled", true))):
			_lab_status = "Controlled liquid preparation requires an actor-free request"
			return false
		if not actor_definitions.is_empty() and (
			not MicroCatalogue.exploratory_actor_map(command.scenario_reset)
			or str(command.get("scenario_mode", "Inspect")) == "Benchmark"
			or not bool(command.scenario_reset.player_enabled)
			or not bool(command.get("sampled_character_enabled", true))
			or not ActorSession.valid_definitions(actor_definitions)):
			_lab_status = "Refused actor configuration for controlled scenario"
			return false
		var guard: Callable = Callable()
		_prepared_liquid_owner_error = ""
		if not controlled_setup.is_empty():
			var prepared: Dictionary = _prepared_liquid_install_options(command,command.scenario_reset,controlled_setup)
			if not prepared.ok: return false
			controlled_setup = prepared.setup;guard = prepared.guard
		var retained_host_error: String = _scenario_host.last_error
		var retained_host_refusal: Dictionary = _scenario_host.last_liquid_policy_refusal
		if not _scenario_host.install(_world, command.scenario_reset, str(command.get("scenario_mode", "Inspect")),
			true, command.get("liquid_policy", null), controlled_setup, guard, continuation_token):
			if not _pending_physical_liquid.is_empty() and not command.get("_prepared_physical_commit",false):
				_scenario_host.last_error = retained_host_error
				_scenario_host.last_liquid_policy_refusal = retained_host_refusal
				return false
			_lab_status = "MicroScenario rejected; " + (_prepared_liquid_owner_error \
				if not _prepared_liquid_owner_error.is_empty() else _scenario_host.last_error)
			if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
			return false
		if command.get("_prepared_physical_commit",false): _retire_prepared_physical_liquid()
		_world_generation += 1
		var definition: Dictionary = _scenario_host.definition()
		var transport: Dictionary = CyberTransportProfiles.resolve(definition.transport_profile)
		_lab_profile = transport.profile.duplicate(true)
		_lab_profile_hash = str(transport.hash)
		_lab_active = true
		_micro_active = true
		_water_lab_active = false
		_water_recipe.clear()
		_lab_schedule.clear()
		_lab_inputs.clear()
		_micro_capture = {}
		_simulation_failed = false
		if controlled_setup.is_empty():
			_configure_sampled_character(
				Vector2(definition.player_start[0], definition.player_start[1]),
				bool(command.get("sampled_character_enabled", true)),
				bool(command.get("runtime_enclosure_recovery_enabled", true))
			)
			if not actor_definitions.is_empty():
				if not _actor_session.configure(actor_definitions, _world):
					_lab_status = "Refused exploratory actor configuration"
					return false
				if not _usable_session.configure(_actor_session.snapshot()):
					_actor_session.clear()
					_lab_status = "Refused exploratory equipment session"
					return false
				_character = _actor_session.player()
				_sampled_character_enabled = true
		_scenario_request_applied = true
		_lab_status = ("MicroScenario installed; apparatus failed: " + _scenario_host.last_error \
			if _scenario_host.summary().get("failed", false) else "MicroScenario " + str(definition.id))
	if not _lab_active: return false
	if command.has("scenario_capture") and _scenario_host.active():
		_micro_capture = _scenario_host.capture(command.get("identity", {}))
		_freeze_capture(_micro_capture)
		_micro_capture_serial += 1
	if (_water_lab_active or _micro_active) and (command.has("release") or command.has("schedule") or command.has("floor")):
		_lab_status="Water Feel uses only registered scenario actions; Tower releases are disabled"
		return false
	if command.has("floor"):
		_lab_schedule.clear() # Navigation abandons scheduled inputs; no catch-up.
		_lab_floor = clampi(int(command.floor),0,4)
		# Prepared Tower already staged this exact floor landing before capture.
		if not command.has("reset") or command.get("controlled_liquid_setup",{}).is_empty():
			_activate_sampled_character(CyberExperimentTower.landing(_lab_floor), true)
	if command.has("release"):
		_lab_release(int(command.release))
		if command.get("adjacent",false): _lab_release(int(command.release)+1)
	if command.has("schedule"):
		var tick: int = int(_world.get_tick_index())
		_lab_schedule = [[tick+30,int(command.schedule),_lab_floor],[tick+90,int(command.schedule)+1,_lab_floor]]
	if _lab_inputs.size() < 256:
		var recorded: Dictionary = command.duplicate(true)
		recorded.erase("profile")
		recorded.erase("scenario_reset")
		recorded.erase("identity")
		recorded.erase("water_policy")
		recorded.erase("water_policy_hash")
		recorded.erase("water_policy_provenance")
		_lab_inputs.append({"tick":int(_world.get_tick_index()),"command":recorded,"profile_hash":_lab_profile_hash})
	return command.has("reset") or command.has("water_reset") or command.has("scenario_reset")

static func _freeze_capture(value: Variant) -> void:
	# One retained record may appear in several snapshots. Freeze nested values
	# once instead of copying a potentially large definition every frame.
	if value is Dictionary:
		for nested: Variant in value.values(): _freeze_capture(nested)
		value.make_read_only()
	elif value is Array:
		for nested: Variant in value: _freeze_capture(nested)
		value.make_read_only()

var _published_snapshot: CyberSimulationSnapshot
var _snapshot_serial: int = 0
var _snapshot_cells: PackedByteArray = PackedByteArray()
var _snapshot_world_revision: int = -1
# World incarnation is independent of native revisions, actor epochs and
# transport/full-refresh serials. Only the exclusive owner advances it after
# an accepted reset/replacement; publication retains it with the render bytes.
var _world_generation: int = 1
var _pending_render_world_generation: int = 0
var _last_render_snapshot_usec: int = -DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
var _pending_render_snapshot_serial: int = 0
var _pending_render_channels: int = 1
var _pending_render_full_refresh: bool = false
var _pending_render_patch_rectangles: PackedInt32Array = PackedInt32Array()
var _pending_render_patch_cells: PackedByteArray = PackedByteArray()
var _pending_render_tick_index: int = 0
var _pending_render_generated_usec: int = 0
var _pending_render_character_position: Vector2 = Vector2.ZERO
var _pending_render_character_velocity: Vector2 = Vector2.ZERO
var _pending_render_character_grounded: bool = false
var _pending_render_rigid_body_states: PackedFloat32Array = PackedFloat32Array()
var _pending_render_simulation_time_ms: float = 0.0
var _pending_render_worker_step_time_ms: float = 0.0
var _pending_render_worker_overruns: int = 0
var _pending_render_context: Dictionary = {}
var _pending_render_payload_generation: int = 0
var _published_render_payload_generation: int = -1
var _published_render_patch_rectangles: PackedInt32Array = PackedInt32Array()
var _published_render_patch_cells: PackedByteArray = PackedByteArray()
var _acknowledged_render_snapshot_serial: int = 0
var _render_full_refresh_requested: bool = false
var _fallback_render_snapshot_serial: int = 0
var _snapshot_hard_surface_revision: int = -1
var _snapshot_hard_surface_epoch: int = -1
var _snapshot_hard_surface_rectangles: PackedInt32Array = PackedInt32Array()
var _snapshot_hard_surface_rectangles_valid: bool = false
var _snapshot_hard_surface_chunk_rectangles: PackedInt32Array = PackedInt32Array()
var _snapshot_hard_surface_chunk_rectangles_valid: bool = false
var _last_hard_surface_snapshot_usec: int = -HARD_SURFACE_SNAPSHOT_INTERVAL_USEC
var _worker_overruns: int = 0
var _scheduler_thread_capacity_hint: int = 1
var _backend_name: String = "gdscript-serial-fallback"


func _create_world():
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		var native_world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		if native_world != null:
			return native_world
	return CyberCellWorld.new()


func _configure_sampled_character(
	spawn_position: Vector2,
	enabled: bool,
	runtime_recovery_enabled: bool
) -> void:
	_mutex.lock()
	_prepared_frame_hold = {}
	_prepared_frame_serial = 0
	_prepared_physical_frame_hold = {}
	_mutex.unlock()
	_actor_session.clear()
	_usable_session.clear()
	if _character is CyberActorPrototype:
		_character = CyberSampledCharacter.new()
		_character.configure_profile(_player_environment_profile)
	_sampled_character_enabled = enabled
	_character.configure_runtime_enclosure_recovery(runtime_recovery_enabled)
	_character.reset(spawn_position)
	if enabled:
		_character.recover_invalid_spawn(_world)


func _activate_sampled_character(
	spawn_position: Vector2,
	runtime_recovery_enabled: bool
) -> void:
	_configure_sampled_character(
		spawn_position,
		true,
		runtime_recovery_enabled
	)


func start_worker(spawn_position: Vector2) -> Error:
	if _thread.is_started():
		return OK
	if _world.has_method(&"get_worker_threads"):
		_scheduler_thread_capacity_hint = int(_world.get_worker_threads())
		_backend_name = str(_world.get_backend_name())
	else:
		_scheduler_thread_capacity_hint = 1
		_backend_name = "gdscript-serial-fallback"
	_character.configure_profile(_player_environment_profile)
	_activate_sampled_character(spawn_position, true)
	_publish_snapshot(0.0, false, _render_snapshot_interval_usec, true)
	_mutex.lock()
	_running = true
	_mutex.unlock()
	var start_error: Error = _thread.start(Callable(self, "_worker_loop"))
	if start_error != OK:
		_mutex.lock()
		_running = false
		_mutex.unlock()
	return start_error


func stop_worker() -> void:
	if not _thread.is_started():
		_retire_prepared_physical_liquid()
		return
	_mutex.lock()
	_running = false
	_lab_request_revision += 1
	_mutex.unlock()
	_thread.wait_to_finish()
	_actor_session.set_suspended(true)


func submit_actor_action(
	actor_id: int, epoch: int, sequence: int, observed_tick: int,
	movement: Vector2, primary: bool, secondary: bool,
	lease_ticks: int = ActorSession.DEFAULT_LEASE_TICKS,
	producer: StringName = &"policy"
) -> bool:
	# Thread-safe value admission only. World and motors stay worker-exclusive.
	_mutex.lock()
	var session: CyberActorPrototypeSession = _actor_session
	_mutex.unlock()
	return session.submit_action(actor_id, epoch, sequence, observed_tick,
		movement, primary, secondary, lease_ticks, producer)


func cancel_actor_input(actor_id: int, epoch: int, producer: StringName) -> bool:
	_mutex.lock()
	var session: CyberActorPrototypeSession = _actor_session
	_mutex.unlock()
	return session.cancel_input(actor_id, epoch, producer)


func submit_actor_usable_action(
	actor_id: int, epoch: int, sequence: int, observed_tick: int,
	usable_index: int, aim: Vector2, power: float, trigger: bool, alternate: bool,
	lease_ticks: int = UsableSession.DEFAULT_LEASE_TICKS, producer: StringName = &"policy"
) -> bool:
	# Equipment is an independent copied-input domain. Policies never receive a
	# World reference or permission to submit cell-edit footprints directly.
	_mutex.lock()
	var session: CyberUsableSession = _usable_session
	_mutex.unlock()
	return session.submit_action(actor_id, epoch, sequence, observed_tick,
		usable_index, aim, power, trigger, alternate, lease_ticks, producer)


func cancel_actor_usable_input(actor_id: int, epoch: int, producer: StringName) -> bool:
	_mutex.lock()
	var session: CyberUsableSession = _usable_session
	_mutex.unlock()
	return session.cancel_input(actor_id, epoch, producer)


func submit_actor_rig_action(
	actor_id: int, epoch: int, sequence: int, observed_tick: int,
	movement: Vector2, aim: Vector2, effort: float, trim: float, reel: float,
	primary: bool, secondary: bool, auxiliary: bool,
	lease_ticks: int = ActorSession.DEFAULT_LEASE_TICKS,
	producer: StringName = &"policy"
) -> bool:
	# ACT-002: the extended envelope admits values, never caller-supplied World
	# commands, effect footprints or mutable motor references.
	_mutex.lock()
	var session: CyberActorPrototypeSession = _actor_session
	_mutex.unlock()
	return session.submit_rig_action(actor_id, epoch, sequence, observed_tick,
		movement, aim, effort, trim, reel, primary, secondary, auxiliary, lease_ticks, producer)


func submit_actor_actuator_action(
	actor_id: int, epoch: int, sequence: int, observed_tick: int,
	actuators: Vector4, lease_ticks: int = ActorSession.DEFAULT_LEASE_TICKS,
	producer: StringName = &"policy"
) -> bool:
	# The configuration-fixed direct lane admits copied actuator values only.
	_mutex.lock()
	var session: CyberActorPrototypeSession = _actor_session
	_mutex.unlock()
	return session.submit_actuator_action(actor_id, epoch, sequence,
		observed_tick, actuators, lease_ticks, producer)


func queue_actor_prototype_reset(definitions: Array, spawn_position: Vector2, sampled_enabled: bool = true) -> int:
	# A positive receipt acknowledges admission; the owner publishes disposition.
	if not ActorSession.valid_definitions(definitions) or not spawn_position.is_finite() or (not sampled_enabled and not definitions.is_empty()):
		return 0
	_mutex.lock()
	# The experimental sandbox cannot rewrite a registered apparatus identity.
	if (
		not _lab_request.is_empty()
		or (_published_snapshot != null and _published_snapshot.lab_context.get("active", false))
	):
		_mutex.unlock()
		return 0
	_lab_request_revision += 1
	_reset_requested = true
	_reset_spawn = spawn_position
	_reset_sampled_character_enabled = sampled_enabled
	_reset_runtime_enclosure_recovery_enabled = sampled_enabled and definitions.is_empty()
	_reset_actor_definitions = definitions.duplicate(true)
	_reset_actor_prototype_request = true
	_actor_prototype_request_serial += 1
	_reset_actor_prototype_serial = _actor_prototype_request_serial
	var receipt: int = _actor_prototype_request_serial
	_pending_emissions.clear()
	_pending_cell_emissions.clear()
	_pending_physical_effects.clear()
	_cancel_physical_usables_locked()
	_physical_usable_frame.clear()
	_mutex.unlock()
	return receipt


func set_frame_state(
		horizontal_input: float,
		jetpack_active: bool,
		paused: bool,
		interest_center: Vector2i,
		view_origin: Vector2i,
		view_size: Vector2i,
		horizontal_buffer: int,
		vertical_buffer: int,
		simulation_window_enabled: bool,
		cadence_lod_enabled: bool,
		liquid_surface_adhesion_enabled: bool
) -> void:
	_mutex.lock()
	_horizontal_input = horizontal_input
	_jetpack_active = jetpack_active
	if paused and not _paused:
		_pending_physical_effects.clear()
		_cancel_physical_usables_locked()
		for actor: int in range(PhysicalEffects.MAX_ACTORS):
			_physical_effect_generations[actor] += 1
	_paused = paused
	if _prepared_frame_hold.is_empty():
		if _view_size != view_size or _simulation_window_enabled != simulation_window_enabled or _cadence_lod_enabled != cadence_lod_enabled \
			or _liquid_surface_adhesion_enabled != liquid_surface_adhesion_enabled \
			or _horizontal_buffer != horizontal_buffer or _vertical_buffer != vertical_buffer:
			_construction_settings_revision += 1
		_interest_center = interest_center
		_view_origin = view_origin
		_view_size = view_size
		_horizontal_buffer = horizontal_buffer
		_vertical_buffer = vertical_buffer
		_simulation_window_enabled = simulation_window_enabled
		_cadence_lod_enabled = cadence_lod_enabled
		_liquid_surface_adhesion_enabled = liquid_surface_adhesion_enabled
	_mutex.unlock()


func set_rigid_body_states(states: PackedFloat32Array, body_epoch: int = 0, effects: Array = []) -> Dictionary:
	# Packed value data is copied at the bridge; scene-tree nodes and Physics RIDs
	# remain exclusively on the main/physics thread. Body publication is independent
	# of effect admission. A nonempty effects batch is queued wholly or refused;
	# previously queued work is never replaced to make room for a newer batch.
	_mutex.lock()
	if not _prepared_physical_frame_hold.is_empty():
		var held: Dictionary = {"epoch":body_epoch,"status":"refused","reason":"prepared_owner_adoption_pending",
			"requested":effects.size(),"queued":0,"refused":effects.size()}
		_mutex.unlock()
		return held
	_rigid_body_states = states.duplicate()
	_rigid_body_epoch = body_epoch
	var requested: int = effects.size()
	var result: Dictionary = {"epoch": body_epoch, "status": "no_effects", "reason": "",
		"requested": requested, "queued": 0, "refused": 0}
	if requested == 0:
		# Routine body-only frames must not erase the latest admission outcome.
		_mutex.unlock()
		return result
	var reason: String = ""
	if body_epoch <= 0 or body_epoch != _physical_effect_epoch:
		reason = "epoch"
	elif _published_snapshot != null and _published_snapshot.simulation_failed:
		reason = "simulation_failed"
	elif _paused:
		reason = "paused"
	elif _reset_requested:
		reason = "reset_pending"
	elif not _lab_request.is_empty():
		reason = "lab_pending"
	elif requested > PhysicalEffects.MAX_REQUESTS:
		reason = "batch_capacity"
	elif requested > PhysicalEffects.MAX_REQUESTS - _pending_physical_effects.size():
		reason = "pending_capacity"
	else:
		# Full effect schema/geometry validation belongs to the native-owner
		# consumer. This bounded pass verifies only generation-index safety.
		for effect: Variant in effects:
			if not effect is Dictionary or not effect.get("actor_slot") is int \
				or int(effect.actor_slot) < 0 or int(effect.actor_slot) >= PhysicalEffects.MAX_ACTORS:
				reason = "actor_slot"
				break
	if reason.is_empty():
		for effect: Dictionary in effects:
			_pending_physical_effects.append({"request": effect.duplicate(true),
				"generation": _physical_effect_generations[int(effect.actor_slot)]})
		result.status = "queued"
		result.queued = requested
		_physical_effect_accepted_batches += 1
		_physical_effect_accepted_requests += requested
	else:
		result.status = "refused"
		result.reason = reason
		result.refused = requested
		_physical_effect_refused_batches += 1
		_physical_effect_refused_requests += requested
		if reason in ["batch_capacity", "pending_capacity"]:
			_physical_effect_overflow_batches += 1
	_physical_effect_last_admission = result
	var copied_result: Dictionary = result.duplicate(true)
	_mutex.unlock()
	return copied_result


func physical_actor_effect_admission() -> Dictionary:
	# Counts/last batch cover calls since the latest set_physical_actor_epoch,
	# including stale-epoch refusals. Cancellation drains work but retains history.
	_mutex.lock()
	var result: Dictionary = {"epoch": _physical_effect_epoch,
		"capacity": PhysicalEffects.MAX_REQUESTS, "pending_requests": _pending_physical_effects.size(),
		"accepted_batches": _physical_effect_accepted_batches,
		"accepted_requests": _physical_effect_accepted_requests,
		"refused_batches": _physical_effect_refused_batches,
		"refused_requests": _physical_effect_refused_requests,
		"overflow_batches": _physical_effect_overflow_batches,
		"last_batch": _physical_effect_last_admission.duplicate(true)}
	_mutex.unlock()
	return result


func set_physical_usable_state(frame: Dictionary, requests: Array = [], states: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	# This publication and its batch have one admission point. Identity changes
	# retire older queued work; capacity never replaces another actor's request.
	_mutex.lock()
	var reason: String = PhysicalUsables.frame_error(frame)
	if reason.is_empty() and (states.size() > CyberRigidBodyCoupling.MAX_BODIES * CyberRigidBodyCoupling.INPUT_STRIDE \
		or states.size() % CyberRigidBodyCoupling.INPUT_STRIDE != 0):
		reason = "body_state_capacity"
	if reason.is_empty():
		for value: float in states:
			if not is_finite(value):
				reason = "body_state_nonfinite"
				break
	var result: Dictionary = {"epoch": frame.get("epoch", -1), "run_id": frame.get("run_id", ""),
		"status": "no_requests", "reason": "", "requested": requests.size(), "queued": 0,
		"refused": 0, "capacity": PhysicalUsables.MAX_REQUESTS}
	if reason.is_empty() and int(frame.epoch) != _physical_effect_epoch:
		reason = "epoch"
	if reason.is_empty() and not _physical_usable_frame.is_empty():
		reason = PhysicalUsables.frame_transition_error(_physical_usable_frame, frame)
	if reason.is_empty():
		for row: Dictionary in frame.actors:
			if bool(row.active) and int(row.generation) <= _physical_usable_cancelled_generations[int(row.actor_id)]:
				reason = "cancelled_generation"
				break
	if reason.is_empty():
		_physical_usable_frame = frame.duplicate(true)
		if not states.is_empty():
			_rigid_body_states = states.duplicate()
			_rigid_body_epoch = int(frame.epoch)
		# A changed generation/selection or cancelled lease invalidates packets
		# even if the worker already extracted them from the pending array.
		for actor: Variant in _physical_usable_inflight.keys():
			if not PhysicalUsables.request_error(_physical_usable_inflight[actor], frame).is_empty():
				_physical_usable_inflight.erase(actor)
		_pending_physical_usables = _pending_physical_usables.filter(func(request: Dictionary) -> bool:
			return PhysicalUsables.request_error(request, frame).is_empty())
		if not requests.is_empty():
			if _paused or bool(frame.suspended):
				reason = "paused"
			elif _reset_requested:
				reason = "reset_pending"
			elif not _lab_request.is_empty():
				reason = "lab_pending"
			elif _published_snapshot != null and _published_snapshot.simulation_failed:
				reason = "simulation_failed"
			elif requests.size() > PhysicalUsables.MAX_REQUESTS:
				reason = "batch_capacity"
			else:
				var owners: Dictionary = {}
				for request: Variant in requests:
					if not request is Dictionary:
						reason = "request_type"
						break
					reason = PhysicalUsables.request_error(request, frame)
					if not reason.is_empty():
						break
					if owners.has(request.actor_id) or _physical_usable_inflight.has(request.actor_id):
						reason = "actor_inflight"
						break
					owners[request.actor_id] = true
	if not reason.is_empty():
		result.status = "refused"
		result.reason = reason
		result.refused = requests.size()
	elif not requests.is_empty():
		for request: Dictionary in requests:
			var copied: Dictionary = request.duplicate(true)
			_pending_physical_usables.append(copied)
			_physical_usable_inflight[int(request.actor_id)] = copied
		result.status = "queued"
		result.queued = requests.size()
	result["pending"] = _physical_usable_inflight.size()
	if not requests.is_empty() or not reason.is_empty():
		_physical_usable_admission = result.duplicate(true)
	_mutex.unlock()
	return result


func cancel_physical_usable_requests(epoch: int, actor_id: int = -1) -> bool:
	if actor_id < -1 or actor_id >= PhysicalUsables.MAX_ACTORS:
		return false
	_mutex.lock()
	if epoch <= 0 or epoch != _physical_effect_epoch:
		_mutex.unlock()
		return false
	_cancel_physical_usables_locked(actor_id)
	_mutex.unlock()
	return true


func _cancel_physical_usables_locked(actor_id: int = -1) -> void:
	for owner: Variant in _physical_usable_inflight.keys():
		if actor_id == -1 or int(owner) == actor_id:
			_physical_usable_inflight.erase(owner)
	_pending_physical_usables = _pending_physical_usables.filter(func(request: Dictionary) -> bool:
		return actor_id != -1 and int(request.actor_id) != actor_id)
	for row: Dictionary in _physical_usable_frame.get("actors", []):
		if actor_id == -1 or int(row.actor_id) == actor_id:
			_physical_usable_cancelled_generations[int(row.actor_id)] = maxi(
				_physical_usable_cancelled_generations[int(row.actor_id)], int(row.generation))
			row.active = false
			row.lease_deadline = -1


func _consume_physical_usables(requests: Array, body_epoch: int, allowed: bool, captured_frame: Dictionary = {}) -> void:
	# Cancellation and the finite cell-edit transaction are linearized under the
	# same mutex. Once cancellation returns, earlier pending work cannot commit.
	# The material adapter still runs only on this exclusive worker thread.
	_mutex.lock()
	var frame: Dictionary = captured_frame.duplicate(true) if not captured_frame.is_empty() else _physical_usable_frame.duplicate(true)
	if _physical_usable_frame.is_empty():
		_physical_usables.reset(_physical_effect_epoch)
		_mutex.unlock()
		return
	if not frame.is_empty() and body_epoch == _physical_effect_epoch and int(frame.epoch) == body_epoch:
		var admitted: Array = []
		for request: Dictionary in requests:
			var owner: int = int(request.actor_id)
			var current: Dictionary = _physical_usable_inflight.get(owner, {})
			if current.get("request_id") == request.request_id \
				and PhysicalUsables.request_error(request, _physical_usable_frame).is_empty():
				admitted.append(request)
				_physical_usable_inflight.erase(owner)
		# Geometry remains matched to the native mask captured at the start of
		# this tick. A newer pickup publication may nevertheless retire a device
		# before this finite transaction starts; it must then produce no recipe.
		frame.devices = frame.devices.filter(func(device: Dictionary) -> bool:
			for current: Dictionary in _physical_usable_frame.get("devices", []):
				if current.instance_id == device.instance_id and current.equipment_epoch == device.equipment_epoch \
					and current.body_id == device.body_id and current.state in ["fixed", "settled", "deployed"]:
					return true
			return false)
		if allowed and not _paused and not _reset_requested and _lab_request.is_empty():
			_physical_usables.step(FIXED_TIMESTEP, _world, frame, admitted)
		else:
			frame.suspended = true
			_physical_usables.step(FIXED_TIMESTEP, _world, frame, admitted)
	_mutex.unlock()


func set_physical_actor_epoch(epoch: int) -> void:
	# Switching owners retires pending effects; no node/RID enters this boundary.
	_mutex.lock()
	if not _prepared_physical_frame_hold.is_empty() and epoch != int(_prepared_physical_frame_hold.epoch):
		_mutex.unlock()
		return
	_set_physical_actor_epoch_locked(epoch)
	_mutex.unlock()

func _set_physical_actor_epoch_locked(epoch: int) -> void:
	_physical_effect_epoch = maxi(0, epoch)
	_pending_physical_effects.clear()
	_pending_physical_usables.clear()
	_physical_usable_inflight.clear()
	_physical_usable_frame.clear()
	_physical_usable_admission.clear()
	_physical_usable_cancelled_generations.fill(-1)
	_physical_effect_accepted_batches = 0
	_physical_effect_accepted_requests = 0
	_physical_effect_refused_batches = 0
	_physical_effect_refused_requests = 0
	_physical_effect_overflow_batches = 0
	_physical_effect_last_admission.clear()
	for actor: int in range(PhysicalEffects.MAX_ACTORS):
		_physical_effect_generations[actor] += 1


func cancel_physical_actor_effects(epoch: int, actor_id: int = -1) -> bool:
	if actor_id < -1 or actor_id >= PhysicalEffects.MAX_ACTORS:
		return false
	_mutex.lock()
	if epoch <= 0 or epoch != _physical_effect_epoch:
		_mutex.unlock()
		return false
	for actor: int in range(PhysicalEffects.MAX_ACTORS):
		if actor_id == -1 or actor_id == actor:
			_physical_effect_generations[actor] += 1
	_pending_physical_effects = _pending_physical_effects.filter(func(packet: Dictionary) -> bool:
		return actor_id != -1 and int(packet.request.actor_slot) != actor_id)
	_cancel_physical_usables_locked(actor_id)
	_mutex.unlock()
	return true


func _admit_physical_effects(packets: Array, epoch: int) -> Array:
	var admitted: Array = []
	_mutex.lock()
	if not _paused and not _reset_requested and _lab_request.is_empty() \
		and epoch > 0 and epoch == _physical_effect_epoch:
		for packet: Dictionary in packets:
			var actor: int = packet.request.actor_slot
			if packet.generation == _physical_effect_generations[actor]:
				admitted.append(packet.request)
	_mutex.unlock()
	return admitted


func set_render_snapshot_hz(render_hz: int) -> void:
	_mutex.lock()
	_render_snapshot_interval_usec = maxi(1, roundi(1000000.0 / maxf(float(render_hz), 1.0)))
	_mutex.unlock()


func queue_emit_disc(
	world_x: int,
	world_y: int,
	radius: int,
	material_id: int,
	emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
) -> bool:
	# Material and emission flags share the fourth integer so the command stays a
	# compact value type. UI/tool slots never enter this simulation-facing command.
	var packed_flags: int = emission_flags << EMISSION_FLAGS_SHIFT
	var packed_material: int = (material_id & EMISSION_MATERIAL_MASK) | packed_flags
	var emission_command: Vector4i = Vector4i(world_x, world_y, radius, packed_material)
	_mutex.lock()
	if not _prepared_physical_publication.is_empty() \
		or not _lab_request.get("controlled_liquid_setup",{}).get("physical_owner",{}).is_empty():
		_mutex.unlock()
		return false
	if _published_snapshot != null and _published_snapshot.simulation_failed:
		_mutex.unlock()
		return false
	if (_published_snapshot != null
		and _published_snapshot.lab_context.get("water_active",false)):
		_mutex.unlock()
		return false
	if _pending_emissions.is_empty() or _pending_emissions.back() != emission_command:
		_pending_emissions.append(emission_command)
	_mutex.unlock()
	return true


func queue_emit_cells(
	points: PackedInt32Array,
	material_id: int,
	emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
) -> bool:
	if points.is_empty() or (points.size() & 1) != 0:
		return false
	if points.size() / 2 > MAX_BRUSH_FOOTPRINT_CELLS:
		return false
	var packed_flags: int = emission_flags << EMISSION_FLAGS_SHIFT
	var packed_material: int = (material_id & EMISSION_MATERIAL_MASK) | packed_flags
	var command: Dictionary = {
		"points": points.duplicate(),
		"packed_material": packed_material,
	}
	_mutex.lock()
	if not _prepared_physical_publication.is_empty() \
		or not _lab_request.get("controlled_liquid_setup",{}).get("physical_owner",{}).is_empty():
		_mutex.unlock()
		return false
	if _published_snapshot != null and _published_snapshot.simulation_failed:
		_mutex.unlock()
		return false
	if (_published_snapshot != null
		and _published_snapshot.lab_context.get("water_active",false)):
		_mutex.unlock()
		return false
	if not _pending_cell_emissions.is_empty():
		var last_command: Dictionary = _pending_cell_emissions.back()
		if (
			int(last_command.get("packed_material", -1)) == packed_material
			and last_command.get("points", PackedInt32Array()) == points
		):
			_mutex.unlock()
			return true
	if _pending_cell_emissions.size() >= MAX_PENDING_BRUSH_COMMANDS:
		_mutex.unlock()
		return false
	_pending_cell_emissions.append(command)
	_mutex.unlock()
	return true


func queue_paint(
	world_x: int,
	world_y: int,
	radius: int,
	material_id: int,
	emission_flags: int = CyberCellWorld.EMISSION_FLAG_NONE
) -> void:
	# Retain the prototype paint interface while equipment, enemies, and world
	# spawners can target the generic emission command directly.
	queue_emit_disc(world_x, world_y, radius, material_id, emission_flags)


func queue_reset(
	spawn_position: Vector2,
	sampled_character_enabled: bool = true,
	runtime_enclosure_recovery_enabled: bool = true
) -> void:
	_mutex.lock()
	_lab_request_revision += 1
	_reset_requested = true
	_reset_spawn = spawn_position
	_reset_sampled_character_enabled = sampled_character_enabled
	_reset_runtime_enclosure_recovery_enabled = runtime_enclosure_recovery_enabled
	_reset_actor_definitions = []
	_reset_actor_prototype_request = false
	# Preserve any overwritten actor receipt for owner-side cancellation. Ordinary
	# resets still replace the single pending reset, without orphaning its caller.
	_pending_emissions.clear()
	_pending_cell_emissions.clear()
	_pending_physical_effects.clear()
	_cancel_physical_usables_locked()
	_physical_usable_frame.clear()
	_mutex.unlock()


func queue_player_environment_profile(profile: Dictionary) -> bool:
	var resolved: Dictionary = PlayerEnvironmentProfiles.resolve(profile)
	if not resolved.get("ok", false):
		return false
	_mutex.lock()
	_construction_settings_revision += 1
	_pending_player_environment_profile = resolved.profile.duplicate(true)
	# PENV tuning remains fresh-reset only. The presentation owner follows this
	# with the current TEST-UX/PCHAR-aware reset path so tool state and player
	# representation/recovery selection remain separate.
	_paused = true
	_mutex.unlock()
	return true


func take_latest_snapshot(after_serial: int) -> CyberSimulationSnapshot:
	_mutex.lock()
	var result: CyberSimulationSnapshot = _published_snapshot
	if result != null and result.serial <= after_serial:
		result = null
	_mutex.unlock()
	return result


func acknowledge_render_snapshot(render_snapshot_serial: int) -> void:
	if render_snapshot_serial <= 0:
		return
	_mutex.lock()
	_acknowledged_render_snapshot_serial = maxi(
		_acknowledged_render_snapshot_serial,
		render_snapshot_serial
	)
	_mutex.unlock()


func request_render_full_refresh() -> void:
	_mutex.lock()
	_render_full_refresh_requested = true
	_mutex.unlock()


func _worker_loop() -> void:
	var next_tick_usec: int = Time.get_ticks_usec()
	while true:
		var local_running: bool = false
		var local_paused: bool = false
		var local_horizontal_input: float = 0.0
		var local_jetpack_active: bool = false
		var local_interest_center: Vector2i = Vector2i.ZERO
		var local_view_origin: Vector2i = Vector2i.ZERO
		var local_view_size: Vector2i = Vector2i.ZERO
		var local_horizontal_buffer: int = 0
		var local_vertical_buffer: int = 0
		var local_window_enabled: bool = true
		var local_cadence_enabled: bool = true
		var local_liquid_adhesion_enabled: bool = true
		var local_render_snapshot_interval_usec: int = DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
		var local_rigid_body_states: PackedFloat32Array = PackedFloat32Array()
		var local_rigid_body_epoch: int = 0
		var local_physical_effects: Array = []
		var local_physical_usables: Array = []
		var local_physical_usable_frame: Dictionary = {}
		var local_emissions: Array[Vector4i] = []
		var local_cell_emissions: Array[Dictionary] = []
		var local_reset_requested: bool = false
		var local_reset_spawn: Vector2 = Vector2.ZERO
		var local_reset_sampled_character_enabled: bool = true
		var local_reset_runtime_recovery_enabled: bool = true
		var local_actor_definitions: Array = []
		var local_actor_prototype_request: bool = false
		var local_actor_prototype_serial: int = 0
		var local_player_environment_profile: Dictionary = {}
		var local_lab: Dictionary = {}

		_mutex.lock()
		local_running = _running
		local_paused = _paused
		local_horizontal_input = _horizontal_input
		local_jetpack_active = _jetpack_active
		local_interest_center = _interest_center
		local_view_origin = _view_origin
		local_view_size = _view_size
		local_horizontal_buffer = _horizontal_buffer
		local_vertical_buffer = _vertical_buffer
		local_window_enabled = _simulation_window_enabled
		local_cadence_enabled = _cadence_lod_enabled
		local_liquid_adhesion_enabled = _liquid_surface_adhesion_enabled
		local_render_snapshot_interval_usec = _render_snapshot_interval_usec
		var physical_wait: bool = not _prepared_physical_publication.is_empty() \
			or not _lab_request.get("controlled_liquid_setup",{}).get("physical_owner",{}).is_empty()
		local_rigid_body_states = _rigid_body_states
		local_rigid_body_epoch = _rigid_body_epoch
		if not physical_wait:
			local_physical_effects = _pending_physical_effects
			_pending_physical_effects = []
		local_physical_usable_frame = _physical_usable_frame.duplicate(true)
		if not physical_wait:
			local_physical_usables = _pending_physical_usables
			_pending_physical_usables = []
			local_emissions = _pending_emissions
			_pending_emissions = []
			local_cell_emissions = _pending_cell_emissions
			_pending_cell_emissions = []
		local_reset_requested = _reset_requested
		local_reset_spawn = _reset_spawn
		local_reset_sampled_character_enabled = _reset_sampled_character_enabled
		local_reset_runtime_recovery_enabled = _reset_runtime_enclosure_recovery_enabled
		local_actor_definitions = _reset_actor_definitions
		_reset_actor_definitions = []
		local_actor_prototype_request = _reset_actor_prototype_request
		_reset_actor_prototype_request = false
		local_actor_prototype_serial = _reset_actor_prototype_serial
		_reset_actor_prototype_serial = 0
		_reset_requested = false
		if not physical_wait:
			local_player_environment_profile = _pending_player_environment_profile
			_pending_player_environment_profile = {}
		local_lab = _lab_request
		_lab_request = {}
		_mutex.unlock()

		if not local_running:
			_retire_prepared_physical_liquid()
			return

		var step_start_usec: int = Time.get_ticks_usec()
		if (
			not local_actor_prototype_request
			and local_actor_prototype_serial > _actor_prototype_result_serial
		):
			_actor_prototype_result_serial = local_actor_prototype_serial
			_actor_prototype_reset_applied = false
			_actor_prototype_status = "Refused actor reset: superseded by ordinary reset"
		if not local_lab.get("controlled_liquid_setup",{}).is_empty() and not local_player_environment_profile.is_empty():
			# A profile extracted in this same owner turn is part of the final
			# staged character configuration, before native replacement commits.
			local_lab["_prepared_player_environment_profile"] = local_player_environment_profile
		if local_reset_requested and not local_lab.get("controlled_liquid_setup",{}).get("physical_owner",{}).is_empty():
			# An already admitted reset/prototype request keeps its ordinary
			# disposition. Do not begin a continuation that could swallow it.
			_scenario_request_serial = int(local_lab.get("scenario_request_serial",0))
			_scenario_request_applied = false
			_lab_status = "Prepared physical replacement refused by an admitted reset"
			local_lab = {}
		var continuation: Dictionary = _advance_prepared_physical_liquid()
		if not continuation.is_empty(): local_lab = continuation
		if not _pending_physical_liquid.is_empty() and continuation.is_empty():
			# Main owns the live Rapier graph. Never block waiting for it, call
			# its APIs, or advance/edit the retained native World while it stages.
			OS.delay_usec(1000)
			next_tick_usec = Time.get_ticks_usec()
			continue
		if _apply_lab(local_lab):
			# Candidate Worlds may reuse a hard-surface revision number. Their
			# initial terrain must replace the previous World's retained packet.
			_snapshot_hard_surface_revision = -1
			local_physical_effects.clear()
			_physical_effect_receipts.clear()
			local_physical_usables.clear()
			_physical_usables.reset()
			_mutex.lock()
			_physical_usable_frame.clear()
			_mutex.unlock()
			if local_actor_prototype_request:
				_actor_prototype_result_serial = local_actor_prototype_serial
				_actor_prototype_reset_applied = false
				_actor_prototype_status = "Refused actor reset: scenario transition took priority"
			local_reset_requested = false
			if not local_lab.get("controlled_liquid_setup",{}).is_empty():
				_mutex.lock()
				local_view_origin = _view_origin; local_view_size = _view_size
				local_horizontal_buffer = _horizontal_buffer; local_vertical_buffer = _vertical_buffer
				local_window_enabled = _simulation_window_enabled; local_cadence_enabled = _cadence_lod_enabled
				local_liquid_adhesion_enabled = _liquid_surface_adhesion_enabled
				if not _prepared_physical_frame_hold.is_empty():
					local_rigid_body_states = _rigid_body_states
					local_rigid_body_epoch = _rigid_body_epoch
				_mutex.unlock()
			local_paused = true
			_last_render_snapshot_usec = -DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
		if not _pending_physical_liquid.is_empty():
			OS.delay_usec(1000)
			next_tick_usec = Time.get_ticks_usec()
			continue
		if not local_player_environment_profile.is_empty():
			_player_environment_profile = local_player_environment_profile.duplicate(true)
			if not _actor_session.active():
				_character.configure_profile(_player_environment_profile)
			_last_render_snapshot_usec = -DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC
		if _water_lab_active:
			local_emissions.clear()
			local_cell_emissions.clear()
		if _micro_active:
			for i: int in range(local_emissions.size() - 1, -1, -1):
				var tool: String = "erase" if (local_emissions[i].w & EMISSION_MATERIAL_MASK) == 0 else "paint"
				if not _scenario_host.allows_tool(tool): local_emissions.remove_at(i)
			for i: int in range(local_cell_emissions.size() - 1, -1, -1):
				var packed_material: int = int(local_cell_emissions[i].get("packed_material", 0))
				var tool: String = "erase" if (packed_material & EMISSION_MATERIAL_MASK) == 0 else "paint"
				if not _scenario_host.allows_tool(tool): local_cell_emissions.remove_at(i)
		if _lab_active:
			if not ((_water_lab_active and bool(_water_recipe.get("body_enabled",false))) or (_micro_active and _scenario_host.body_enabled())):
				local_rigid_body_states = PackedFloat32Array()
			if local_lab.get("step",false): local_paused = false
			if not local_paused:
				if _scenario_host.active() and not _apply_due_water_actions():
					local_paused=true
					_mutex.lock()
					_paused=true
					_mutex.unlock()
				for release: Array in _lab_schedule.duplicate():
					if int(release[2]) == _lab_floor and int(_world.get_tick_index())+1 >= int(release[0]):
						_lab_release(int(release[1]))
						_lab_schedule.erase(release)
		if _micro_active and _scenario_host.fixed_execution():
			local_cadence_enabled = _scenario_host.cadence_enabled()
			local_liquid_adhesion_enabled = _scenario_host.adhesion_enabled()
		_world.simulation_window_enabled = local_window_enabled
		_world.cadence_lod_enabled = local_cadence_enabled
		_world.set_liquid_surface_adhesion_enabled(local_liquid_adhesion_enabled)
		_world.set_interest_center(local_interest_center)
		_world.set_simulation_window(
			local_view_origin,
			local_view_size,
			local_horizontal_buffer,
			local_vertical_buffer
		)

		if _micro_active: _scenario_host.apply_interest()

		if (
			local_reset_requested and local_actor_prototype_request
			and (_lab_active or _micro_active or _water_lab_active)
		):
			# Main-thread publication can lag a lab command already extracted by
			# this owner. Revalidate here before replacing a registered World.
			local_reset_requested = false
			_actor_prototype_result_serial = local_actor_prototype_serial
			_actor_prototype_reset_applied = false
			_actor_prototype_status = "Refused actor reset: a registered scenario is active"
		if local_reset_requested:
			local_physical_effects.clear()
			_physical_effect_receipts.clear()
			local_physical_usables.clear()
			_physical_usables.reset()
			var recovered: bool = true
			if _world.has_method(&"has_failed"):
				recovered = bool(_world.reset_demo_world())
			else:
				_world.reset_demo_world()
			if recovered:
				_world_generation += 1
				_scenario_host.clear()
				_lab_active = false
				_micro_active = false
				_water_lab_active = false
				_micro_capture = {}
				_simulation_failed = false
				_configure_sampled_character(local_reset_spawn,
					local_reset_sampled_character_enabled, local_reset_runtime_recovery_enabled)
				var actors_configured: bool = local_actor_definitions.is_empty()
				if not local_actor_definitions.is_empty():
					actors_configured = _actor_session.configure(local_actor_definitions, _world)
					if actors_configured:
						actors_configured = _usable_session.configure(_actor_session.snapshot())
					if actors_configured:
						_character = _actor_session.player()
						_sampled_character_enabled = true
				if local_actor_prototype_request:
					_actor_prototype_status = "Actor reset applied" if actors_configured else "Refused actor configuration after World reset"
					_actor_prototype_result_serial = local_actor_prototype_serial
					_actor_prototype_reset_applied = actors_configured
				# Publish the replacement before any attempted continuation.
				local_paused = true
			elif local_actor_prototype_request:
				_actor_prototype_result_serial = local_actor_prototype_serial
				_actor_prototype_reset_applied = false
				_actor_prototype_status = "Refused actor reset: World replacement failed"
		_actor_session.set_suspended(local_paused or _simulation_failed)
		if _actor_session.active():
			_usable_session.sync_actor_context(_actor_session.snapshot())
		else:
			_usable_session.clear()
		if not _simulation_failed:
			_world.prepare_rigid_body_coupling(local_rigid_body_states, not local_paused)
			# Admission is rechecked at the exclusive owner's consume boundary.
			var physical_effects_allowed: bool = (not local_paused
				and not _sampled_character_enabled and not _water_lab_active
				and (not _lab_active or (_micro_active
					and CyberMicroScenarioCatalogue.exploratory_actor_map(_scenario_host.definition())
					and not _scenario_host.fixed_execution())))
			if physical_effects_allowed and not local_physical_effects.is_empty():
				local_physical_effects = _admit_physical_effects(local_physical_effects, local_rigid_body_epoch)
				_physical_effect_receipts = _physical_effects.apply(
					_world, local_physical_effects, local_rigid_body_epoch)
			_consume_physical_usables(local_physical_usables, local_rigid_body_epoch, physical_effects_allowed, local_physical_usable_frame)
			for emission_command: Vector4i in local_emissions:
				_world.emit_disc(
					emission_command.x,
					emission_command.y,
					emission_command.z,
					emission_command.w & EMISSION_MATERIAL_MASK,
					emission_command.w >> EMISSION_FLAGS_SHIFT
				)
			for emission_batch: Dictionary in local_cell_emissions:
				var points: PackedInt32Array = emission_batch.get("points", PackedInt32Array())
				var packed_material: int = int(emission_batch.get("packed_material", 0))
				for point_index: int in range(0, points.size(), 2):
					_world.emit_disc(
						points[point_index],
						points[point_index + 1],
						0,
						packed_material & EMISSION_MATERIAL_MASK,
						packed_material >> EMISSION_FLAGS_SHIFT
					)

			if not local_paused:
				if (
					_sampled_character_enabled
					and (not _micro_active or _scenario_host.player_enabled())
				):
					if _actor_session.active():
						_actor_session.step(FIXED_TIMESTEP, _world)
						_usable_session.step(FIXED_TIMESTEP, _world, _actor_session.snapshot())
					else:
						_character.simulate(
							FIXED_TIMESTEP,
							local_horizontal_input,
							local_jetpack_active,
							_world
						)
				if _world.has_method(&"has_failed"):
					_simulation_failed = not bool(_world.simulation_tick())
				else:
					_world.simulation_tick()
				if _lab_active and _scenario_host.active() and not _scenario_host.after_tick():
					_lab_status = _scenario_host.last_error
					local_paused = true
					_mutex.lock()
					_paused = true
					_mutex.unlock()

		var worker_step_time_ms: float = float(Time.get_ticks_usec() - step_start_usec) / 1000.0
		_publish_snapshot(
			worker_step_time_ms,
			local_paused,
			local_render_snapshot_interval_usec,
			local_reset_requested,
			local_rigid_body_states,
			local_rigid_body_epoch
		)

		next_tick_usec += TICK_INTERVAL_USEC
		var now_usec: int = Time.get_ticks_usec()
		var wait_usec: int = next_tick_usec - now_usec
		if wait_usec > 0:
			OS.delay_usec(wait_usec)
		elif -wait_usec > TICK_INTERVAL_USEC * MAX_BACKLOG_TICKS:
			_worker_overruns += 1
			next_tick_usec = now_usec


func _publish_snapshot(
	worker_step_time_ms: float,
	paused: bool,
	render_snapshot_interval_usec: int,
	force_render_full_refresh: bool = false,
	rigid_body_states: PackedFloat32Array = PackedFloat32Array(),
	rigid_body_epoch: int = 0
) -> void:
	if _simulation_failed:
		_publish_failure_snapshot()
		return
	var copy_start_usec: int = Time.get_ticks_usec()
	var now_usec: int = Time.get_ticks_usec()
	var render_serial_before: int = _pending_render_snapshot_serial
	var render_generation_advanced: bool = false
	var acknowledged_render_serial: int = 0
	var render_full_refresh_requested: bool = false
	_mutex.lock()
	acknowledged_render_serial = _acknowledged_render_snapshot_serial
	render_full_refresh_requested = _render_full_refresh_requested
	_render_full_refresh_requested = false
	_mutex.unlock()
	force_render_full_refresh = (
		force_render_full_refresh or render_full_refresh_requested
		or _world_generation != _pending_render_world_generation
	)
	if (
		_pending_render_snapshot_serial > 0
		and acknowledged_render_serial >= _pending_render_snapshot_serial
	):
		_clear_pending_render_patches()
	if (
		force_render_full_refresh
		or (
			_world.revision != _snapshot_world_revision
			and now_usec - _last_render_snapshot_usec >= render_snapshot_interval_usec
		)
	):
		if _world.has_method(&"take_render_snapshot"):
			var render_packet: Dictionary = _world.take_render_snapshot(
				force_render_full_refresh
			)
			_append_native_render_packet(render_packet)
			if (
				_pending_render_patch_cells.size()
				> CyberCellWorld.WORLD_WIDTH * CyberCellWorld.WORLD_HEIGHT * 2
				or _pending_render_patch_rectangles.size()
				> MAX_PENDING_RENDER_PATCHES * RENDER_PATCH_METADATA_STRIDE
			):
				_append_native_render_packet(_world.take_render_snapshot(true))
			if _pending_render_full_refresh:
				_snapshot_cells = _pending_render_patch_cells.duplicate()
		else:
			_snapshot_cells = PackedByteArray(_world.get_cells())
			_fallback_render_snapshot_serial += 1
			_pending_render_snapshot_serial = _fallback_render_snapshot_serial
			_pending_render_channels = 1
			_pending_render_full_refresh = true
			_pending_render_patch_rectangles = PackedInt32Array([
				0,
				0,
				CyberCellWorld.WORLD_WIDTH,
				CyberCellWorld.WORLD_HEIGHT,
				0,
				CyberCellWorld.WORLD_WIDTH,
			])
			_pending_render_patch_cells = _snapshot_cells
			_pending_render_payload_generation += 1
		_snapshot_world_revision = _world.revision
		_last_render_snapshot_usec = now_usec
		if _pending_render_snapshot_serial > render_serial_before:
			_pending_render_world_generation = _world_generation
			_pending_render_tick_index = int(_world.tick_index)
			_pending_render_generated_usec = now_usec
			_pending_render_character_position = _character.position
			_pending_render_character_velocity = _character.velocity
			_pending_render_character_grounded = _character.grounded
			_pending_render_rigid_body_states = rigid_body_states.duplicate()
			_pending_render_simulation_time_ms = _world.simulation_time_ms
			_pending_render_worker_step_time_ms = worker_step_time_ms
			_pending_render_worker_overruns = _worker_overruns
			render_generation_advanced = true
	var current_hard_surface_revision: int = int(_world.hard_surface_revision)
	if (
		force_render_full_refresh
		or rigid_body_epoch != _snapshot_hard_surface_epoch
		or _snapshot_hard_surface_revision < 0
		or (current_hard_surface_revision != _snapshot_hard_surface_revision
			and now_usec - _last_hard_surface_snapshot_usec >= HARD_SURFACE_SNAPSHOT_INTERVAL_USEC)
	):
		# A new physical owner/reset cannot acknowledge a retained terrain
		# packet from its predecessor, even inside the ordinary edit throttle.
		if _world.has_method(&"get_hard_surface_chunk_rectangles"):
			_snapshot_hard_surface_chunk_rectangles = PackedInt32Array(
				_world.get_hard_surface_chunk_rectangles()
			)
			_snapshot_hard_surface_chunk_rectangles_valid = true
		elif _world.has_method(&"get_hard_surface_rectangles"):
			_snapshot_hard_surface_rectangles = PackedInt32Array(
				_world.get_hard_surface_rectangles()
			)
			_snapshot_hard_surface_rectangles_valid = true
		_snapshot_hard_surface_revision = current_hard_surface_revision
		_snapshot_hard_surface_epoch = rigid_body_epoch
		_last_hard_surface_snapshot_usec = now_usec
	var copy_time_ms: float = float(Time.get_ticks_usec() - copy_start_usec) / 1000.0

	var snapshot: CyberSimulationSnapshot = CyberSimulationSnapshot.new()
	snapshot.actor_prototypes = _actor_session.snapshot()
	snapshot.actor_usables = _usable_session.snapshot()
	snapshot.rigid_body_epoch = rigid_body_epoch
	snapshot.physical_actor_effects = _physical_effect_receipts.duplicate(true)
	snapshot.physical_actor_effect_admission = physical_actor_effect_admission()
	snapshot.physical_usables = _physical_usables.snapshot()
	_mutex.lock()
	snapshot.physical_usables["admission"] = _physical_usable_admission.duplicate(true)
	_mutex.unlock()
	snapshot.actor_prototype_status = _actor_prototype_status
	snapshot.actor_prototype_reset_serial = _actor_prototype_result_serial
	snapshot.actor_prototype_reset_applied = _actor_prototype_reset_applied
	_snapshot_serial += 1
	snapshot.serial = _snapshot_serial
	snapshot.published_usec = Time.get_ticks_usec()
	snapshot.world_revision = _snapshot_world_revision
	snapshot.simulation_world_revision = int(_world.revision)
	snapshot.hard_surface_revision = _snapshot_hard_surface_revision
	snapshot.cells = _snapshot_cells
	snapshot.render_snapshot_serial = _pending_render_snapshot_serial
	snapshot.render_world_generation = _pending_render_world_generation
	snapshot.render_channels = _pending_render_channels
	snapshot.render_full_refresh = _pending_render_full_refresh
	snapshot.render_tick_index = _pending_render_tick_index
	snapshot.render_generated_usec = _pending_render_generated_usec
	snapshot.render_character_position = _pending_render_character_position
	snapshot.render_character_velocity = _pending_render_character_velocity
	snapshot.render_character_grounded = _pending_render_character_grounded
	snapshot.render_rigid_body_states = _pending_render_rigid_body_states
	snapshot.render_simulation_time_ms = _pending_render_simulation_time_ms
	snapshot.render_worker_step_time_ms = _pending_render_worker_step_time_ms
	snapshot.render_worker_overruns = _pending_render_worker_overruns
	_refresh_published_render_payload()
	snapshot.render_patch_rectangles = _published_render_patch_rectangles
	snapshot.render_patch_cells = _published_render_patch_cells
	snapshot.hard_surface_rectangles = _snapshot_hard_surface_rectangles
	snapshot.hard_surface_rectangles_valid = _snapshot_hard_surface_rectangles_valid
	snapshot.hard_surface_chunk_rectangles = _snapshot_hard_surface_chunk_rectangles
	snapshot.hard_surface_chunk_rectangles_valid = (
		_snapshot_hard_surface_chunk_rectangles_valid
	)
	snapshot.character_position = _character.position
	snapshot.character_velocity = _character.velocity
	snapshot.character_grounded = _character.grounded
	snapshot.player_representation = (
		("sampled-baseline" if _character.runtime_enclosure_recovery_enabled else "sampled-burial-safe")
		if _sampled_character_enabled
		else "barrel-rapier"
	)
	snapshot.player_body_id = 0 if _sampled_character_enabled else 1
	if not snapshot.actor_prototypes.is_empty():
		snapshot.player_representation = "actor-prototype/" + str(snapshot.actor_prototypes.models[0])
	snapshot.current_rigid_body_states = rigid_body_states.duplicate()
	snapshot.character_runtime_recovery_enabled = (
		_character.runtime_enclosure_recovery_enabled
	)
	snapshot.character_runtime_enclosed = _character.runtime_enclosed
	snapshot.character_runtime_recovery_attempts = _character.runtime_recovery_attempts
	snapshot.character_runtime_recovery_successes = _character.runtime_recovery_successes
	snapshot.character_runtime_recovery_upward_cells = _character.runtime_recovery_upward_cells
	snapshot.character_invalid_spawn_recovery_attempts = (
		_character.invalid_spawn_recovery_attempts
	)
	snapshot.character_invalid_spawn_recovery_successes = (
		_character.invalid_spawn_recovery_successes
	)
	snapshot.character_last_recovery_kind = _character.last_recovery_kind
	snapshot.character_last_recovery_offset = _character.last_recovery_offset
	snapshot.tick_index = _world.tick_index
	snapshot.moves_last_tick = _world.moves_last_tick
	snapshot.scanned_last_tick = _world.scanned_last_tick
	snapshot.dormant_cells_skipped_last_tick = _world.dormant_cells_skipped_last_tick
	snapshot.active_blocks_last_tick = _world.active_blocks_last_tick
	snapshot.eligible_blocks_last_tick = _world.eligible_blocks_last_tick
	snapshot.adaptive_block_stride_last_tick = _world.adaptive_block_stride_last_tick
	snapshot.deferred_blocks_last_tick = _world.deferred_blocks_last_tick
	snapshot.frozen_blocks_last_tick = _world.frozen_blocks_last_tick
	snapshot.scheduler_jobs_last_tick = _world.scheduler_jobs_last_tick
	snapshot.scheduler_parallel_phases_last_tick = _world.scheduler_parallel_phases_last_tick
	snapshot.scheduler_thread_capacity_hint = _scheduler_thread_capacity_hint
	snapshot.backend_name = _backend_name
	snapshot.sparse_flight_moves_last_tick = _world.sparse_flight_moves_last_tick
	snapshot.rigid_body_results = _world.rigid_body_results()
	snapshot.rigid_body_contacts_last_tick = _world.rigid_body_contacts_last_tick
	snapshot.rigid_body_displaced_last_tick = _world.rigid_body_displaced_last_tick
	snapshot.rigid_body_unresolved_last_tick = _world.rigid_body_unresolved_last_tick
	snapshot.simulation_time_ms = _world.simulation_time_ms
	snapshot.worker_step_time_ms = worker_step_time_ms
	snapshot.snapshot_copy_time_ms = copy_time_ms
	snapshot.worker_overruns = _worker_overruns
	if _world.has_method(&"get_tick_failure_count"):
		snapshot.tick_failure_count = int(_world.get_tick_failure_count())
		snapshot.last_tick_error = str(_world.get_last_tick_error())
	snapshot.paused = paused
	snapshot.lab_context = {
		"tick":snapshot.tick_index,
		"paused":paused,
		"visited_cells":snapshot.scanned_last_tick,
		"active_blocks":snapshot.active_blocks_last_tick,
		"moves":snapshot.moves_last_tick,
		"active":_lab_active,
		"floor":_lab_floor,
		"status":_lab_status,
		"inputs":_lab_inputs.duplicate(true),
		"input_limit":256,
		"profile":_lab_profile.duplicate(true),
		"profile_hash":_lab_profile_hash,
		"player_environment_profile":_player_environment_profile.duplicate(true),
		"actor_prototypes":snapshot.actor_prototypes,
		"actor_usables":snapshot.actor_usables,
		"sampled_character_enabled":_sampled_character_enabled,
		"sampled_runtime_recovery_enabled":(
			_character.runtime_enclosure_recovery_enabled
		),
		"scenario_request_serial":_scenario_request_serial,
		"scenario_request_applied":_scenario_request_applied,
		"water_exit_request_serial":_water_exit_request_serial,
		"water_exit_request_applied":_water_exit_request_applied,
		"micro_active":_micro_active,
		"liquid_solver_policy":_liquid_policy_receipt_snapshot(),
		"native_default_demo":_default_liquid_origin(),
		"liquid_host_observation":_default_liquid_identity.duplicate(true) \
			if int(_default_liquid_origin().get("session_generation",-1)) == int(_default_liquid_identity.get("session_generation",-2)) \
			else _scenario_host.liquid_host_observation(),
		"liquid_construction_receipt":_world.get_applied_liquid_construction_receipt() \
			if _world.has_method(&"get_applied_liquid_construction_receipt") else {},
		"liquid_construction_attempt":_world.get_liquid_construction_attempt() \
			if _world.has_method(&"get_liquid_construction_attempt") else {},
		"microscenario":_scenario_host.summary() if _lab_active else {},
		"micro_capture_serial":_micro_capture_serial,
		"micro_capture":_micro_capture, # Immutable one-slot result; replaced, never mutated.
		"water_active":_water_lab_active,
		"water_policy":_water_policy.duplicate(true),
		"water_policy_hash":_water_policy_hash,
		"water_policy_provenance":_water_policy_provenance.duplicate(true),
		"water_recipe_hash":_water_recipe_hash,
		"water_blind_label":_water_blind_label,
		"water_actions":_water_action_history.duplicate(true),
		"water_observations":_water_observations.duplicate(true),
		"water_accounting":{
			"initial_integer":_water_initial_integer,
			"initial_requested_numerator_255":_water_initial_requested_numerator_255,
			"initial_quantization_error_numerator_255":_water_initial_quantization_error_numerator_255,
			"explicit_source":_water_explicit_source,
			"explicit_sink":_water_explicit_sink,
			"outflow":0,
			"current":_water_current_integer if _water_lab_active else 0,
		},
	}
	if render_generation_advanced:
		var render_micro: Dictionary = snapshot.lab_context.get("microscenario", {})
		var render_presentation: Dictionary = render_micro.get("presentation", {})
		var render_profile: Dictionary = snapshot.lab_context.get("profile", {})
		_pending_render_context = {
			"actor_prototypes": snapshot.actor_prototypes.duplicate(true),
			"actor_usables": snapshot.actor_usables.duplicate(true),
			"micro_active": bool(snapshot.lab_context.get("micro_active", false)),
			"profile": {"name": str(render_profile.get("name", ""))},
			"profile_hash": str(snapshot.lab_context.get("profile_hash", "")),
			"water_policy_hash": str(snapshot.lab_context.get("water_policy_hash", "")),
			"player_environment_profile": snapshot.lab_context.get(
				"player_environment_profile",
				{}
			).duplicate(true),
			"microscenario": {
				"id": str(render_micro.get("id", "")),
				"definition_hash": str(render_micro.get("definition_hash", "")),
				"source_recipe": str(render_micro.get("source_recipe", "")),
				"source_recipe_hash": str(render_micro.get("source_recipe_hash", "")),
				"seed": int(render_micro.get("seed", 0)),
				"mode": str(render_micro.get("mode", "")),
				"presentation": {
					"profile": str(render_presentation.get("profile", "")),
				},
			},
		}
		_freeze_capture(_pending_render_context)
	snapshot.render_context = _pending_render_context

	_mutex.lock()
	_published_snapshot = snapshot
	_mutex.unlock()


func has_failed() -> bool:
	_mutex.lock()
	var failed: bool = _published_snapshot != null and _published_snapshot.simulation_failed
	_mutex.unlock()
	return failed


func _publish_failure_snapshot() -> void:
	_actor_session.set_suspended(true)
	# Copy the last valid publication, never partial cells/character/body results.
	# The previous snapshot and its packed payloads remain immutable.
	var previous: CyberSimulationSnapshot = _published_snapshot
	if (
		previous != null and previous.simulation_failed
		and previous.actor_prototype_reset_serial == _actor_prototype_result_serial
	):
		return
	var snapshot: CyberSimulationSnapshot = CyberSimulationSnapshot.new()
	if previous != null:
		for property: Dictionary in previous.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				snapshot.set(property.name, previous.get(property.name))
	_snapshot_serial += 1
	snapshot.serial = _snapshot_serial
	snapshot.published_usec = Time.get_ticks_usec()
	snapshot.simulation_failed = true
	snapshot.actor_prototype_status = _actor_prototype_status
	snapshot.actor_prototype_reset_serial = _actor_prototype_result_serial
	snapshot.actor_prototype_reset_applied = _actor_prototype_reset_applied
	snapshot.paused = true
	snapshot.rigid_body_results = PackedFloat32Array()
	snapshot.failed_tick_index = int(_world.get_attempted_tick_index())
	snapshot.tick_failure_count = int(_world.get_tick_failure_count())
	snapshot.last_tick_error = str(_world.get_last_tick_error())
	_mutex.lock()
	_pending_emissions.clear()
	_published_snapshot = snapshot
	_mutex.unlock()


func _clear_pending_render_patches() -> void:
	_pending_render_full_refresh = false
	_pending_render_patch_rectangles = PackedInt32Array()
	_pending_render_patch_cells = PackedByteArray()
	_pending_render_payload_generation += 1


func _refresh_published_render_payload() -> void:
	if _published_render_payload_generation == _pending_render_payload_generation:
		return
	# Packed arrays are reference types. These copies are the ownership boundary
	# between the worker's mutable accumulation buffers and immutable snapshots
	# consumed by the main thread.
	_published_render_patch_rectangles = _pending_render_patch_rectangles.duplicate()
	_published_render_patch_cells = _pending_render_patch_cells.duplicate()
	_published_render_payload_generation = _pending_render_payload_generation


func _append_native_render_packet(packet: Dictionary) -> void:
	var packet_cells: PackedByteArray = packet.get("cells", PackedByteArray())
	var packet_rectangles: PackedInt32Array = packet.get(
		"rectangles",
		PackedInt32Array()
	)
	if packet_cells.is_empty() or packet_rectangles.is_empty():
		return

	var packet_serial: int = int(packet.get("serial", 0))
	var packet_channels: int = int(packet.get("channels", 2))
	var packet_full_refresh: bool = bool(packet.get("full_refresh", false))
	if packet_full_refresh:
		_pending_render_patch_rectangles = packet_rectangles
		_pending_render_patch_cells = packet_cells
		_pending_render_full_refresh = true
	else:
		var data_offset_base: int = _pending_render_patch_cells.size()
		_pending_render_patch_cells.append_array(packet_cells)
		for metadata_offset: int in range(
			0,
			packet_rectangles.size(),
			RENDER_PATCH_METADATA_STRIDE
		):
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset])
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset + 1])
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset + 2])
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset + 3])
			_pending_render_patch_rectangles.append(
				packet_rectangles[metadata_offset + 4] + data_offset_base
			)
			_pending_render_patch_rectangles.append(packet_rectangles[metadata_offset + 5])

	# Native exchange serials restart on validated World replacement. Desktop
	# acknowledgements belong to the worker lifetime and must remain monotonic.
	_pending_render_snapshot_serial = maxi(_pending_render_snapshot_serial+1,packet_serial)
	_pending_render_channels = packet_channels
	_pending_render_payload_generation += 1
