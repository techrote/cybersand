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

static func _water_census(bridge: Variant, world: Variant) -> Dictionary:
	var count: int = 0
	var full: bool = true
	var motion: bool = false
	for y: int in range(80):
		for x: int in range(96):
			if world.material_at(x,y) != 3: continue
			count += 1
			var cell: Dictionary = bridge.inspect_cell(world,Vector2i(x,y))
			full = full and cell.get("ok",false) and int(cell.get("state_a",0)) == 255
			var state: Dictionary = world.inspect_inertial_cell(Vector2i(x,y))
			motion = motion or (state.inertial_family and (state.vx != 0 or state.vy != 0 or state.ax != 0 or state.ay != 0))
	return {"count":count,"full":full,"motion":motion,
		"quantity":int(world.water_experiment_observation(Vector2i.ZERO,Vector2i(96,96)).water_integer)}

static func _water_families(controller: Variant, report: Dictionary, definition: Dictionary,
		defaults: PackedInt32Array) -> bool:
	var world: Variant = controller.native_world
	var bridge: Variant = controller.demo_bridge
	var water: Dictionary = definition.duplicate(true)
	water.rectangles = [0,0,96,96,0,0,80,96,1,1,0,0,1,80,1,95,0,1,80,1,28,24,8,6,3]
	water.partial_water_fills = [52,24,1,1,127,0,53,24,1,1,128,0]
	water.interest.region = [0,0,96,96]
	var payloads: Array[String] = []
	for arm: Array in [["freemass_v1","reference"],["cellular_yield_v1","reference"],
			["pressure_flow_v1","reference"],["pressure_flow_v1","cached"],
			["pressure_flow_v1","cached_dormant"],["inertial_cellular_v1","reference"]]:
		var family: String = arm[0]
		var variant: String = arm[1]
		var label: String = family+"/"+variant
		var policy: PackedInt32Array = defaults if family == "freemass_v1" else _choose(bridge,defaults,3,family,variant)
		if not _check(report,not policy.is_empty(),"actual runtime admits common Water arm "+label): return false
		var validation: Dictionary = bridge.validate_liquid_policy(policy)
		if not _check(report,validation.accepted,"native validates common Water request "+label): return false
		var whole: bool = family == "cellular_yield_v1" or family == "inertial_cellular_v1"
		if whole:
			if not _check(report,controller.microscenario_apply_controlled_liquid(water,defaults,false,"Inspect",3),
					"fractional Current control precedes Water refusal "+label): return false
			var retained: Dictionary = {"hash":world.get_physical_state_hash(),
				"receipt":world.get_applied_liquid_construction_receipt().canonical_bytes.duplicate(),
				"generation":world.get_liquid_policy_session_generation(),"owner":controller.player.get_instance_id(),
				"observation":controller.micro_host.liquid_host_observation_record()}
			_check(report,not controller.microscenario_apply_controlled_liquid(water,policy,false,"Inspect",3),
				"fractional Water refuses without normalization "+label)
			_check(report,world.get_physical_state_hash()==retained.hash
				and world.get_applied_liquid_construction_receipt().canonical_bytes==retained.receipt
				and world.get_liquid_policy_session_generation()==retained.generation
				and controller.player.get_instance_id()==retained.owner
				and controller.micro_host.liquid_host_observation_record()==retained.observation,
				"whole-cell refusal retains World/receipt/generation/owner/observation "+label)
		if not _check(report,controller.microscenario_apply_controlled_liquid(water,policy,true,"Inspect",3),
				"normal owner installs normalized common Water arm "+label): return false
		var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
		var actual: Dictionary = world.get_liquid_solver_policy()
		var assignment: Dictionary = {}
		for entry: Dictionary in actual.assignments:
			if int(entry.material)==3: assignment = entry
		_check(report,assignment.get("applied_family","")==family and assignment.get("applied_variant","")==variant
			and actual.policy_hash==validation.receipt.policy_hash and actual.maximum_rule_radius==3
			and receipt.physical_state_hash_version==(3 if family=="inertial_cellular_v1" else 2),
			"native family/variant/policy/hash-version/radius match common Water arm "+label)
		var normal: Dictionary = receipt.normalization
		_check(report,normal.rule=="water-normalize-v1" and normal.water_before==49*255 and normal.water_after==49*255
			and normal.positive_delta==127 and normal.negative_delta==127 and normal.net_delta==0
			and normal.cells_up==1 and normal.cells_down==1,
			"common Water uses exact gross and net setup ledger "+label)
		payloads.append(normal.payload_after_hash)
		var advanced: bool = true
		var quantity_exact: bool = true
		var observed_motion: bool = false
		for tick: int in range(30):
			if not controller.micro_host.advance(): advanced = false;break
			quantity_exact = quantity_exact and int(world.water_experiment_observation(Vector2i.ZERO,Vector2i(96,96)).water_integer)==49*255
			if tick==3 and family=="inertial_cellular_v1": observed_motion = _water_census(bridge,world).motion
		var census: Dictionary = _water_census(bridge,world)
		_check(report,advanced and quantity_exact and census.quantity==49*255 and world.get_tick_index()==30 and census.count>0
			and (not whole or (census.full and census.count==49))
			and (family!="inertial_cellular_v1" or observed_motion),
			"common Water advances30 ticks with exact quantity and actual whole-cell/IN semantics "+label)
		report.water_runs.append({"family":assignment.get("applied_family",""),"variant":assignment.get("applied_variant",""),
			"policy_sha256":actual.policy_hash,"native_receipt_sha256":receipt.receipt_hash,
			"normalized_payload_sha256":normal.payload_after_hash,"positive_delta":normal.positive_delta,
			"negative_delta":normal.negative_delta,"water_integer":census.quantity,"ticks":world.get_tick_index(),
			"quantity_exact_each_tick":quantity_exact,"observed_retained_motion":observed_motion,"census":census,
			"hash_version":receipt.physical_state_hash_version,"physical_hash":world.get_physical_state_hash(),"radius":actual.maximum_rule_radius})
	return _check(report,payloads.size()==6 and payloads.all(func(value: String) -> bool: return value==payloads[0]),
		"all four Water families and three pressure variants use one exact normalized setup payload")

static func run(controller: Variant) -> Dictionary:
	var report: Dictionary = {"schema_version":1,"ok":false,"terminal":false,
		"scope":"actual synchronous application owner; native receipt-v1 remains qualified",
		"web":OS.has_feature("web"),"threads":OS.has_feature("threads"),
		"checks":[],"failures":[],"mixed_runs":[],"water_runs":[]}
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
	if not _water_families(controller,report,definition,defaults): return _finish(report)
	_check(report,controller.microscenario_apply_definition(definition,"Inspect"),"ordinary Current constructor remains available")
	_check(report,world.get_applied_liquid_construction_receipt().is_empty()
		and controller.micro_host.liquid_host_observation().is_empty()
		and world.get_physical_state_hash_version() == 2 and world.get_liquid_solver_policy().maximum_rule_radius == 2,
		"ordinary Current constructor retires prepared identity and restores protected radius2")
	return _finish(report)
