extends "res://tests/support/sol_active_normal_authored.gd"

func configure_fresh_world(world: Variant, mode: String, report: Dictionary) -> bool:
	var trace_mode: String = OS.get_environment("SOL_NODE_TRACE_MODE")
	if trace_mode not in ["off","batch64-001"]: return false
	# Both selectors precede NormalPolicy.configure's first getter.
	if not world.diagnostic_set_workbench_solver_trace(trace_mode): return false
	return super.configure_fresh_world(world,mode,report)

func coupling_result(world: Variant) -> Dictionary:
	var packet: Dictionary = super.coupling_result(world)
	var enabled: bool = OS.get_environment("SOL_NODE_TRACE_MODE")=="batch64-001"
	check(packet.get("solver_trace_mode")==OS.get_environment("SOL_NODE_TRACE_MODE") and packet.get("solver_trace_locked",false),"actual native trace selector")
	for row: Dictionary in packet.get("rows",[]):
		if not enabled:
			check(not row.has("solver_trace"),"off has no capture payload")
			continue
		var capture: Dictionary = row.get("solver_trace",{})
		check(capture.get("schema")=="gcr-node-trace-001" and capture.get("normal_policy")==row.normal_policy,"native trace schema/policy")
		check(capture.get("owner_id")==row.id and capture.get("instance_id")==row.instance_id and capture.get("generation")==row.generation and capture.get("sample")==row.sample,"native trace owner/sample")
		check(capture.get("complete",false) and capture.get("export_complete",false) and capture.get("total_nodes")==row.nodes,"complete native capture")
	# Observer failures mark the experiment failed; they never change a physical packet.
	return packet
