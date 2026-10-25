extends RefCounted

# Main-thread-only two-turn continuation. Native retains exclusive candidate
# World ownership; this object retains one exact copied request and body graph.
const Reference = preload("res://scripts/prepared_reference_body_session.gd")
const Sampled = preload("res://scripts/prepared_sampled_session.gd")
const MAX_PREPARE_MSEC: int = 20000
var candidate: RefCounted
var world: Variant
var bridge: Variant
var token: int = 0
var serial: int = 0
var definition: Dictionary = {}
var policy := PackedInt32Array()
var setup: Dictionary = {}
var values: Dictionary = {}
var last_error: String = ""
var phase: String = "new"
var _settings: Dictionary = {}
var _staged: Dictionary = {}
var _actor_factory: Callable
var _commit_barrier: Callable
var _started_msec: int = 0
var water_result: Dictionary = {}
var water_checked: Dictionary = {}
var water_recipe: Dictionary = {}
var _mode: String = "Play"
var _instrumentation: bool = false

func prepare(owner: Variant, value: Dictionary, request: PackedInt32Array, normalize: bool, radius: int,
		factory: Callable = Callable(), actor_factory: Callable = Callable(), barrier: Callable = Callable(),
		water: Dictionary = {}) -> bool:
	world = owner.native_world;serial = owner._level_import_serial
	_started_msec = Time.get_ticks_msec()
	definition = value.duplicate(true);policy = request.duplicate()
	water_result = water.duplicate(true)
	if not water_result.is_empty():
		water_checked = CyberWaterExperimentProfiles.resolve({},{},water_result.get("policy",{}))
		if not water_checked.get("ok",false) or water_checked.hash!=water_result.get("hash",""):
			last_error = "Prepared Water Feel policy identity is invalid";return false
		water_recipe = CyberWaterFeelScenarios.recipe(str(water_checked.policy.scenario_id),int(water_checked.policy.seed))
		if not water_recipe.get("body_enabled",false) or definition!=CyberMicroScenarioCatalogue.prepared_water(water_checked):
			last_error = "Prepared Water Feel requires its exact supported-body recipe";return false
	_mode = owner.microscenario_mode if not water_result.is_empty() else "Play"
	_instrumentation = not water_result.is_empty()
	_actor_factory = actor_factory;_commit_barrier = barrier;_settings = _owner_settings(owner)
	candidate = factory.call() if factory.is_valid() else Reference.new()
	var templates: Array[RigidBody2D] = [owner.test_rigid_body_1,owner.test_rigid_body_2,owner.test_rigid_body_3]
	if not candidate.prepare_reference(owner,templates,Vector2(8,14),
		PackedVector2Array([Vector2(124,90),Vector2(244,90),Vector2(384,90)]),PackedFloat32Array([0,0,0])):
		last_error = candidate.last_error;close();return false
	setup = {"intent":"exploratory","normalization":"water-normalize-v1" if normalize else "",
		"maximum_rule_radius":radius,"owner_execution":owner._water_prepared_execution(definition)
			if not water_result.is_empty() else owner._ordinary_demo_execution(definition),
		"physical_owner":{"epoch":0,"instance_id":candidate.get_instance_id(),"initial_bodies":candidate.initial_body_states()}}
	return true

func begin(owner: Variant) -> bool:
	var applied: bool = owner.micro_host.install(world,definition,_mode,_instrumentation,policy,setup,_commit.bind(owner,false))
	if applied: return phase=="committed"
	if phase=="waiting": return true
	if last_error.is_empty(): last_error = owner.micro_host.last_error
	return false

func advance(owner: Variant) -> String:
	if Time.get_ticks_msec()-_started_msec>MAX_PREPARE_MSEC:
		last_error = "Prepared reference bodies exceeded their bounded wait; prior owners retained";return "refused"
	if phase!="waiting" or not _bound(owner):
		last_error = "Prepared reference bodies retired by a newer owner/configuration";return "refused"
	if not candidate.verify_physics_frame() or not candidate.prepare_terrain_budget(
		owner.HARD_SURFACE_CHUNKS_PER_FRAME,owner.HARD_SURFACE_FRAME_BUDGET_USEC):
		last_error = candidate.last_error;return "refused"
	if not candidate.ready(): return "waiting"
	if not owner.micro_host.install(world,definition,_mode,_instrumentation,policy,setup,_commit.bind(owner,true),token):
		if last_error.is_empty(): last_error = owner.micro_host.last_error
		return "refused"
	return "committed"

func _commit(actual_bridge: Variant, actual_token: int, owner: Variant, completing: bool) -> Variant:
	if not _bound(owner): return false
	if not completing:
		bridge = actual_bridge;token = actual_token
		values = bridge.prepared_liquid_world_values(world,token)
		if values.is_empty(): last_error = bridge.get_last_error();return false
		_staged = Sampled.prepare(bridge,world,token,Vector2(definition.player_start[0],definition.player_start[1]),
			true,owner.player.runtime_enclosure_recovery_enabled,owner.player.active_profile(),[],0,_actor_factory)
		if not _staged.ok: last_error = _staged.error;return false
		if not candidate.install_terrain(values.terrain): last_error = candidate.last_error;return false
		phase = "waiting"
		return {"deferred":true}
	if actual_token!=token or not candidate.ready(): return false
	if _commit_barrier.is_valid(): _commit_barrier.call()
	if not _bound(owner) or not candidate.ready(): return false
	if not actual_bridge.commit_liquid_world(world,token): last_error = actual_bridge.get_last_error();return false
	# No external callback, declared fallible setup or physics rebind follows.
	owner._adopt_web_reference_candidate(candidate,_staged.character)
	phase = "committed"
	return true

func _bound(owner: Variant) -> bool:
	return is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion() \
		and owner.native_world==world and serial==owner._level_import_serial \
		and (owner._water_owner_is_current() if not water_result.is_empty() else owner._physics_pit_is_current()) \
		and _settings==_owner_settings(owner)

func _owner_settings(owner: Variant) -> Dictionary:
	return {"quality":owner.quality,"view":owner.current_view_size,"margin":owner.simulation_margin,
		"render_hz":owner.render_snapshot_hz,"camera":owner.camera_origin,"player":owner.player,
		"profile":owner.player.active_profile(),"recovery":owner.player.runtime_enclosure_recovery_enabled,
		"window":owner.native_world.get_simulation_window_enabled(),"cadence":owner.native_world.get_cadence_lod_enabled(),
		"adhesion":owner.liquid_surface_adhesion_enabled,"mode":owner.microscenario_mode,
		"water_source":owner.water_policy_resolved.duplicate(true) if not water_result.is_empty() else {},
		"generation":owner.native_world.get_liquid_policy_session_generation(),
		"components":owner.native_world.get_liquid_run_receipt({}).get("components",{}).duplicate(true)}

func close() -> void:
	if phase=="closed": return
	if phase!="committed":
		if token>0 and bridge!=null: bridge.discard_liquid_world(world,token)
		if candidate!=null: candidate.close()
	phase = "closed"
