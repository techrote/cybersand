extends SceneTree

# Fixed work, independent of the desktop render clock. Compare checksum,
# completed work and timing across fresh one-worker and Auto processes.
const Contract = preload("res://scripts/microscenario_contract.gd")
const DAM := "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const WARMUP := 10
const TICKS := 180

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var requested := int(OS.get_environment("WORKBENCH_POOL_REQUEST"))
	ProjectSettings.set_setting("cybersand/native_worker_threads",requested)
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var checked := Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var family := OS.get_environment("WORKBENCH_POOL_WATER")
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	var ticks := TICKS if family.is_empty() else 12
	var warmup := WARMUP if family.is_empty() else 2
	if not family.is_empty():
		var admitted := false
		for choice: Dictionary in bridge.liquid_policy_assignment_choices(policy,3):
			if choice.accepted and choice.family == family and choice.variant == "reference":
				policy = choice.request
				admitted = true
				break
		if not admitted:
			push_error("Requested Water solver is unavailable")
			quit(1)
			return
	var rectangles := PackedInt32Array()
	# Parallel granular columns in flight. The contacts/density/materials are
	# unchanged between variants. No input event depends on elapsed time.
	for column: int in 12:
		var material := (2 if column%2 == 0 else 14) if family.is_empty() else 3
		rectangles.append_array(PackedInt32Array([640+column*24,512,14,144,material]))
	var options := {"workbench_extent":Vector2i(2048,2048),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),"geometry":PackedFloat64Array(),"bodies":[]},
		"region":PackedInt32Array([0,0,2048,2048]),"intent":"exploratory","cadence_lod_enabled":false,
		"definition_hash":checked.hash,"initial_bodies":PackedFloat32Array()}
	var token: int = bridge.prepare_liquid_world(world,rectangles,checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),policy,options)
	if token <= 0 or not bridge.commit_liquid_world(world,token):
		print("POOL_ERROR ",bridge.get_last_error())
		quit(1)
		return
	var visited := 0
	var jobs := 0
	var moves := 0
	var start := 0
	var prep := {}
	for tick: int in warmup+ticks:
		if tick == warmup:
			if family == "pressure_flow_v1": prep = world.inspect_pressure_optimization().counters
			print("POOL_BEGIN")
			start = Time.get_ticks_usec()
		if not world.simulation_tick():
			print("POOL_ERROR ",tick," ",world.get_last_tick_error())
			quit(1)
			return
		if tick >= warmup:
			visited += world.scanned_last_tick
			jobs += world.scheduler_jobs_last_tick
			moves += world.moves_last_tick
	var duration := Time.get_ticks_usec()-start
	if not prep.is_empty():
		var after: Dictionary = world.inspect_pressure_optimization().counters
		print("POOL_PF ",JSON.stringify({"gas_ms":(float(after.gas_nanoseconds)-float(prep.gas_nanoseconds))/1e6,
			"heads_ms":(float(after.head_nanoseconds)-float(prep.head_nanoseconds))/1e6}))
	print("POOL_END ",JSON.stringify({"workers":world.get_worker_threads(),"ticks":ticks,"water":family,"usec":duration,"jobs":jobs,
		"visited":visited,"moves":moves}))
	print("POOL_HASH ",world.get_physical_state_hash())
	quit()
