extends RefCounted

const Contract = preload("res://scripts/microscenario_contract.gd")

static func definition() -> Dictionary:
	var value: Dictionary = Contract.base(Contract.WORKBENCH_ID)
	value.schema_version = 2
	value["extent"] = [512,512]
	value["presentation"] = {"title":"Persistent native fixture","instructions":"Native continuation qualification",
		"duration_ticks":600,"baseline":"workbench","profile":"persistent-areas","regions":[]}
	value.interest = {"policy":"fixed","region":[0,0,512,512]}
	value.execution.cadence_lod_enabled = false
	value.execution.policy = "fixed"
	value.tools = ["paint","erase"]
	value.rectangles = [0,500,512,8,1, 0,0,4,508,1, 508,0,4,508,1,
		40,385,44,45,7, 44,377,36,8,6, 150,450,48,5,1, 154,436,40,14,16,
		280,80,24,25,2, 408,80,24,25,2, 280,220,28,15,3, 408,220,28,15,3,
		51,400,1,1,0, 65,60,1,1,1]
	return value

static func create(workers: int = 1) -> Dictionary:
	var checked: Dictionary = Contract.validate(definition())
	if not checked.get("ok",false): return {"error":checked.get("error","fixture invalid")}
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var options: Dictionary = {"workbench_extent":Vector2i(512,512),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),
			"geometry":PackedFloat64Array(),"bodies":[]},"region":PackedInt32Array([0,0,512,512]),
		"intent":"controlled","pacing":"fixed_steps","definition_hash":checked.hash,
		"initial_bodies":PackedFloat32Array(),"simulation_window_enabled":true,
		"cadence_lod_enabled":false,"liquid_surface_adhesion_enabled":true,"workbench_worker_threads":workers}
	var result: Dictionary = {"world":world,"bridge":bridge,"checked":checked,"options":options}
	var token: int = prepare(result,options)
	if token <= 0 or not bridge.commit_liquid_world(world,token):
		return {"error":bridge.get_last_error()}
	return result

static func prepare(fixture: Dictionary, options: Dictionary) -> int:
	return int(fixture.bridge.prepare_liquid_world(fixture.world,
		PackedInt32Array(fixture.checked.definition.rectangles),fixture.checked.transport.packed,
		PackedInt32Array(fixture.checked.definition.water_semantics),
		PackedInt32Array(fixture.checked.definition.partial_water_fills),
		fixture.bridge.default_liquid_policy(),options))

static func restore_options(fixture: Dictionary, capsule: Dictionary, operation: String) -> Dictionary:
	var options: Dictionary = fixture.options.duplicate(true)
	options["workbench_continuation"] = capsule.duplicate(true)
	options["workbench_continuation_identity"] = {"session_id":"qualification-session",
		"area_id":"industrial","generation":1,"operation_id":operation}
	return options
