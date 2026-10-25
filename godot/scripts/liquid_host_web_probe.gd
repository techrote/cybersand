extends RefCounted

# Explicit startup apparatus: it calls the same synchronous owner methods as
# the normal controls. Native headless execution only qualifies this apparatus;
# actual compat/threaded browser runs remain separately recorded evidence.
const Contract = preload("res://scripts/microscenario_contract.gd")
const FIXTURE: String = "res://tests/fixtures/lcb/lcb.mixed.water-oil-brine.v1.json"

static func _check(report: Dictionary, value: bool, label: String) -> bool:
	report.checks.append({"name":label,"passed":value})
	if not value: report.failures.append(label)
	return value

static func _finish(report: Dictionary) -> Dictionary:
	report.ok = report.failures.is_empty()
	report.terminal = true
	return report

static func _choose(bridge: Variant, request: PackedInt32Array, material: int,
		family: String, variant: String = "reference") -> PackedInt32Array:
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(request,material):
		if choice.accepted and choice.family == family and choice.variant == variant:
			return choice.request
	return PackedInt32Array()

static func _definition() -> Dictionary:
	var parsed: Dictionary = Contract.parse(FileAccess.get_file_as_string(FIXTURE))
	if not parsed.ok: return {}
	var value: Dictionary = parsed.definition.duplicate(true)
	value.rectangles = [0,0,160,160,0,0,150,160,1,1,0,0,1,150,1,159,0,1,150,1]
	# Per-cell normalization rounds127 down and128 up at mass_bits8.
	value.partial_water_fills = [50,100,1,1,127,0,51,100,1,1,128,0]
	value.events = [];value.observations = [];value.conditions = []
	value.player_enabled = false;value.body_enabled = false
	value.interest = {"policy":"fixed","region":[0,0,160,160]}
	value.execution = {"policy":"fixed","cadence_lod_enabled":false,"liquid_surface_adhesion_enabled":true}
	return value

static func _census(world: Variant) -> Dictionary:
	var counts: Dictionary = {"water":0,"oil":0,"brine":0}
	var motion: bool = false
	for y: int in range(80):
		for x: int in range(96):
			var material: int = world.material_at(x,y)
			if material == 3: counts.water += 1
			elif material == 16: counts.oil += 1
			elif material == 24:
				counts.brine += 1
				var state: Dictionary = world.inspect_inertial_cell(Vector2i(x,y))
				motion = motion or state.vx != 0 or state.vy != 0 or state.ax != 0 or state.ay != 0
	return {"counts":counts,"motion":motion}

static func run(controller: Variant) -> Dictionary:
	var report: Dictionary = {"schema_version":1,"ok":false,"terminal":false,
		"scope":"actual synchronous application owner; native receipt-v1 remains qualified",
		"web":OS.has_feature("web"),"threads":OS.has_feature("threads"),
		"checks":[],"failures":[],"mixed_runs":[]}
	if not _check(report,controller.ready_to_play,"normal owner reached actual setup"): return _finish(report)
	var world: Variant = controller.native_world
	var bridge: Variant = controller.demo_bridge
	report.worker_count = world.get_worker_threads()
	if OS.has_feature("web") and not OS.has_feature("threads"):
		_check(report,report.worker_count == 1,"compat runtime uses one native worker")
	var definition: Dictionary = _definition()
	if not _check(report,not definition.is_empty(),"registered fixture parses"): return _finish(report)
	var defaults: PackedInt32Array = bridge.default_liquid_policy()
	var whole: PackedInt32Array = _choose(bridge,defaults,3,"cellular_yield_v1")
	if not _check(report,not whole.is_empty(),"actual runtime admits Water CY"): return _finish(report)
	if not _check(report,controller.microscenario_apply_controlled_liquid(definition,defaults,false,"Inspect",2),
			"normal owner installs fractional Current control"): return _finish(report)
	var retained: Dictionary = world.get_applied_liquid_construction_receipt()
	var retained_hash: String = world.get_physical_state_hash()
	var retained_owner: int = controller.player.get_instance_id()
	var retained_observation: Dictionary = controller.micro_host.liquid_host_observation_record()
	_check(report,not controller.microscenario_apply_controlled_liquid(definition,whole,false,"Inspect",2),
		"normal owner explicitly refuses missing normalization")
	_check(report,world.get_physical_state_hash() == retained_hash
		and world.get_applied_liquid_construction_receipt().canonical_bytes == retained.canonical_bytes
		and controller.player.get_instance_id() == retained_owner
		and controller.micro_host.liquid_host_observation_record() == retained_observation,
		"refusal retains actual World, copied receipt, sampled owner and owner observation")
	if not _check(report,controller.microscenario_apply_controlled_liquid(definition,whole,true,"Inspect",2),
			"normal owner installs explicit water-normalize-v1"): return _finish(report)
	var normalized: Dictionary = world.get_applied_liquid_construction_receipt()
	_check(report,normalized.normalization.water_after == 255
		and normalized.physical_state_hash == world.get_physical_state_hash()
		and normalized.qualifications == 15 and not normalized.eligible_for_full_matched_evidence,
		"actual native normalization and frozen qualification read back")
	controller.microscenario_reset()
	var restarted: Dictionary = world.get_applied_liquid_construction_receipt()
	_check(report,restarted.session_generation > normalized.session_generation
		and restarted.prepared_payload_hash == normalized.prepared_payload_hash
		and restarted.normalization.water_after == normalized.normalization.water_after
		and not controller.micro_host.liquid_host_observation().is_empty(),
		"ordinary reset retains explicit selection, normalized payload and new copied identity")
	report.normalization = {"rule":"water-normalize-v1","water_after":normalized.normalization.water_after,
		"payload_sha256":normalized.prepared_payload_hash,"receipt_sha256":restarted.receipt_hash}

	var mixed: Dictionary = definition.duplicate(true)
	mixed.rectangles = [0,0,96,96,0,0,80,96,1,1,0,0,1,80,1,95,0,1,80,1,
		28,60,8,6,3,36,60,8,6,16,32,40,8,6,24]
	mixed.partial_water_fills = [];mixed.interest.region = [0,0,96,96]
	var inertial: PackedInt32Array = _choose(bridge,defaults,24,"inertial_cellular_v1")
	if not _check(report,not inertial.is_empty(),"actual runtime admits Brine IN"): return _finish(report)
	var edited: Dictionary = bridge.liquid_policy_with_inertial_damping(inertial,7)
	if not _check(report,edited.accepted,"native damping7 edit admits"): return _finish(report)
	var projections: Array[String] = []
	for variant: String in ["freemass","reference","cached","cached_dormant"]:
		var policy: PackedInt32Array = edited.request
		if variant != "freemass": policy = _choose(bridge,policy,3,"pressure_flow_v1",variant)
		if not _check(report,not policy.is_empty(),"native selected mixed arm "+variant): return _finish(report)
		if not _check(report,controller.microscenario_apply_controlled_liquid(mixed,policy,false,"Inspect",3),
				"normal owner installs mixed arm "+variant): return _finish(report)
		var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
		var actual: Dictionary = world.get_liquid_solver_policy()
		var inertial_extension: Dictionary = {}
		for extension: Dictionary in receipt.solver_state_extensions:
			if extension.family == 4: inertial_extension = extension
		_check(report,receipt.physical_state_hash_version == 3 and receipt.maximum_rule_radius == 3
			and actual.family_parameters.inertial_cellular_v1.damping_numerator == 7
			and inertial_extension.get("extension_digest","") == actual.family_parameters.inertial_cellular_v1.extension_identity,
			"actual IN instance geometry/damping/extension agree "+variant)
		var advanced: bool = true
		var observed_motion: bool = false
		for tick: int in range(30):
			if not controller.micro_host.advance(): advanced = false;break
			if tick == 3: observed_motion = _census(world).motion
		var end: Dictionary = _census(world)
		var quantity: int = int(world.water_experiment_observation(Vector2i.ZERO,Vector2i(96,96)).water_integer)
		_check(report,advanced and observed_motion and end.counts.water > 0 and end.counts.oil == 48
			and end.counts.brine == 48 and quantity == 48*255,"mixed families advance with exact quantity "+variant)
		var run: Dictionary = {"variant":variant,"census":end,"water_integer":quantity,
			"physical_hash":world.get_physical_state_hash(),"policy_sha256":actual.policy_hash,
			"native_receipt_sha256":receipt.receipt_hash,"observed_retained_motion":observed_motion}
		if variant != "freemass":
			var optimization: Dictionary = world.inspect_pressure_optimization()
			_check(report,optimization.available and optimization.cached == (variant != "reference")
				and optimization.dormant == (variant == "cached_dormant"),"actual PF execution readback "+variant)
			var projection: String = world.get_liquid_comparison_hash(1)
			projections.append(projection);run.projection = projection
			run.optimization_execution_version = optimization.execution_version
		report.mixed_runs.append(run)
	_check(report,projections.size() == 3 and projections[0] == projections[1] and projections[1] == projections[2],
		"three PF variants have exact mixed-family authority projection")
	_check(report,controller.microscenario_apply_definition(definition,"Inspect"),"ordinary Current constructor remains available")
	_check(report,world.get_applied_liquid_construction_receipt().is_empty()
		and controller.micro_host.liquid_host_observation().is_empty()
		and world.get_physical_state_hash_version() == 2 and world.get_liquid_solver_policy().maximum_rule_radius == 2,
		"ordinary Current constructor retires prepared identity and restores protected radius2")
	return _finish(report)
