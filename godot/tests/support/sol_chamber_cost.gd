extends "res://tests/support/sol_chamber_experiment.gd"

const COST_PROFILE = "res://tests/fixtures/sol_chamber/cost-001.json"
var observer: String = ""
var response_times: Array[int] = []
var statistics_times: Array[int] = []

func coupling_result(world: Variant) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	var packet: Dictionary = super.coupling_result(world)
	response_times.append(Time.get_ticks_usec()-start)
	return packet

func copied_statistics(preparer: Variant, world: Variant) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	var value: Dictionary = super.copied_statistics(preparer,world)
	statistics_times.append(Time.get_ticks_usec()-start)
	return value

func census(world: Variant, body: RigidBody2D, boundary: String) -> Dictionary:
	if observer=="full" or boundary in ["initial","final"]:
		return super.census(world,body,boundary)
	var start: int = Time.get_ticks_usec()
	return {"boundary":boundary,"state":body_state(body),"world_instance":world.get_instance_id(),
		"revision":world.get_revision(),"failed":world.has_failed(),
		"geometry_observation":"UNAVAILABLE in minimal performance observer",
		"observer_us":Time.get_ticks_usec()-start}

func run_chamber_steps(spec: Dictionary, mode: String, body: RigidBody2D, bridge: Variant,
		world: Variant, preparer: Variant, report: Dictionary, output: String, name: String) -> void:
	super.run_chamber_steps(spec,mode,body,bridge,world,preparer,report,output,name)
	report.observer=observer
	report.cost_apparatus="SOL-CHAMBER-COST-001-APPARATUS-002"
	report.godot_process_id=OS.get_process_id()
	report.cost_profile_sha256=FileAccess.get_sha256(COST_PROFILE)
	report.base_profile_sha256=FileAccess.get_sha256(CHAMBER_PROFILE)
	for index: int in report.steps.size():
		report.steps[index].response_generation_us=response_times[index] if index<response_times.size() else null
		report.steps[index].statistics_us=statistics_times[index] if index<statistics_times.size() else null
	check(response_times.size()==report.steps.size(),"complete response timing coverage")
	check(statistics_times.size()==report.steps.size(),"complete statistics timing coverage")

func run() -> void:
	var cost: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COST_PROFILE))
	registration=JSON.parse_string(FileAccess.get_file_as_string(CHAMBER_PROFILE))
	check(FileAccess.get_sha256(CHAMBER_PROFILE)==str(cost.base_profile_sha256),"frozen base profile")
	registration.id=cost.id
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var output: String = OS.get_environment("SOL_CHAMBER_OUTPUT")
	var selection: String = OS.get_environment("SOL_CHAMBER_CASE")
	var arm: String = OS.get_environment("SOL_CHAMBER_ARM")
	var workers: int = int(OS.get_environment("SOL_CHAMBER_WORKERS"))
	var repeat: int = int(OS.get_environment("SOL_CHAMBER_REPEAT"))
	observer=OS.get_environment("SOL_CHAMBER_OBSERVER")
	check(not output.is_empty() and selection in cost.cases and arm in cost.arms and float(workers) in cost.workers
		and repeat>=0 and repeat<int(cost.repeats) and observer in cost.observers,"registered cost coordinates")
	if not failures.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	for spec: Dictionary in registration.cases:
		if spec.id==selection:chamber_episode(spec,arm,workers,repeat,output)
	print("SOL_CHAMBER_COST checks=",checks," failures=",failures.size())
	quit(int(not failures.is_empty()))
