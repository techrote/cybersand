extends SceneTree

# The actual registered stream exposed a fictitious one-ULP catch delta after
# compound double-precision summation. Exercise the strict bridge unchanged.
const Runtime=preload("res://scripts/player_playground_runtime.gd")
const Fleet=preload("res://scripts/gcr_review_fleet.gd")
const Source=preload("res://scripts/gcr_painting_powder_source.gd")
var checks: int=0
var failures: Array[String]=[]
var completed: int=0
func _init() -> void: call_deferred("_run")
func check(ok: bool, reason: String) -> bool:
	checks+=1
	if not ok: failures.append(reason);push_error(reason)
	return ok
func neutral() -> Dictionary:
	return {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":1.0,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false}
func quantity(world: Object) -> Dictionary:
	var left: Dictionary=world.diagnostic_snapshot(Vector2i.ZERO,Vector2i(512,512),false,false)
	var right: Dictionary=world.diagnostic_snapshot(Vector2i(512,0),Vector2i(512,512),false,false)
	if left.is_empty() or right.is_empty(): return {}
	for index: int in range(left.counts.size()): left.counts[index]=int(left.counts[index])+int(right.counts[index])
	return {"counts":left.counts,"water_mass":int(left.water_mass)+int(right.water_mass)}
func _run() -> void:
	var protocol_path: String=ProjectSettings.globalize_path("res://../docs/audits/gcr-authored-2026-11-04/protocol.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--protocol="): protocol_path=arg.trim_prefix("--protocol=")
	var protocol: Variant=JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	if not check(protocol is Dictionary and protocol.get("registration")=="GCR-AUTHORED-001","registered authored protocol available"):
		quit(1);return
	var spec: Dictionary={}
	for candidate: Dictionary in protocol.cases:
		if candidate.id=="stream": spec=candidate
	if not check(not spec.is_empty() and int(spec.ticks)==900,"retain exact stream setup and duration"):
		quit(1);return
	var runtime=Runtime.new();root.add_child(runtime)
	var options: Dictionary={"response":"LA","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}
	if not check(runtime.configure_review_fleet(Fleet.NAMES.find("Scooper"),options,Vector2(spec.spawn[0],spec.spawn[1])),"construct actual one-body Scooper LA control"):
		runtime.close();runtime.free();quit(1);return
	var arena=runtime._arena
	var world: Object=arena._world
	var source=Source.new()
	check(world.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0),"clear registered fixture")
	for rect: Array in [[16,396,992,6],[16,16,6,386],[1002,16,6,386],[16,16,992,6]]:
		check(world.diagnostic_fill_rect(Vector2i(rect[0],rect[1]),Vector2i(rect[2],rect[3]),58),"registered closed hard boundary")
	for rect: Array in spec.get("material_rects",[]):
		check(world.diagnostic_fill_rect(Vector2i(rect[0],rect[1]),Vector2i(rect[2],rect[3]),int(spec.material)),"registered initial material")
	check(source.configure(Vector2i(spec.source[0],spec.source[1]),int(spec.material)) and source.set_stream(true),"registered four-cell stream")
	var before: Dictionary=quantity(world)
	check(not before.is_empty(),"initial native quantity census")
	for tick: int in range(900):
		if not check(source.before_step(arena),"stream uses actual owner before step"): break
		if not check(runtime.submit_review_action(neutral(),{"q":false,"e":false,"s":false,"boost":false}),"normal neutral pilot command"): break
		var state: Dictionary=runtime.step()
		if not check(not state.failed,"registered stream reaches tick %d: %s" % [tick,runtime.last_error]): break
		var receipt: Dictionary=world.gcr_rest_receipt()
		var result: PackedFloat64Array=world.gcr_compound_results()
		if not check(receipt.get("bodies",[]).size()==1 and result.size()==14,"one physical receipt and wrench"): break
		var row: Dictionary=receipt.bodies[0]
		check(not row.catch_applied and row.catch_refusal=="NotRequested","control mode never requests catch")
		check(row.catch_delta_impulse==Vector2.ZERO and float(row.catch_delta_torque)==0.0,"no-catch deltas are exactly zero, including mixed-precision boundaries")
		check(row.uncaught_impulse==Vector2(result[1],result[2]) and float(row.uncaught_torque)==float(result[9]),"uncaught receipt is the actual unmodified physical wrench")
		var application: Dictionary=arena.session.bridge.gcr_application_diagnostics()
		check(application.get("accepted",false) and application.get("refusal","").is_empty(),"strict bridge accepts exact native receipt")
		if tick==0:
			var serial: int=int(result[8])
			var bridge=arena.session.bridge
			var history: int=(serial%bridge.GCR_SAMPLE_HISTORY)*CyberRigidBodyCoupling.MAX_BODIES*bridge.GCR_SAMPLE_FIELDS
			check(bridge._gcr_rest_row_valid(row,0,serial,history),"actual zero-catch row satisfies unchanged validator")
			var forged: Dictionary=row.duplicate(true)
			forged.catch_delta_impulse=Vector2(0.000000007450580596923828125,0.0)
			check(not bridge._gcr_rest_row_valid(forged,0,serial,history),"a forged one-ULP no-catch delta remains refused")
		completed+=1
		if not failures.is_empty(): break
	check(completed==900,"all900 registered stream boundaries complete")
	var after: Dictionary=quantity(world)
	if check(not before.is_empty() and not after.is_empty(),"final native quantity census"):
		var expected: Array=before.counts.duplicate()
		expected[int(spec.material)]+=source.inserted
		check(after.counts==expected and after.water_mass==before.water_mass,"native material is conserved plus exact accepted source additions")
	var inserted: int=source.inserted
	runtime.close();runtime.free()
	print("GCR_SCOOPER_RECEIPT ",JSON.stringify({"checks":checks,"failures":failures,"completed_ticks":completed,"source_inserted":inserted,"scope":"Registered stream-LA strict receipt regression; unchanged contact/motor laws and bridge guards"}))
	quit(0 if failures.is_empty() else 1)
