extends SceneTree
const Session = preload("res://scripts/solid_detachment_session.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok:
		failures.append(why)
		printerr("FAIL LA CONTROLS ",why)
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	for params: Dictionary in [{"mass_multiplier":0.0},{"inertia_multiplier":NAN},{"gravity":-1.0},{"friction":INF},{"unknown":1.0}]:
		var bad = Session.new()
		check(not await bad.open(root,1,"empty",true,"LA",params),"invalid parameters refuse")
		check(bad.worker==null,"invalid parameters create no native owner")
	for params: Dictionary in [{},{"gravity":46.06,"mass_multiplier":0.5,"friction":0.2,"inertia_multiplier":2.0}]:
		var session = Session.new()
		check(await session.open(root,1,"packed_sand",true,"LA",params),"LA fresh construction")
		if not session.last_error.is_empty(): printerr("LA construction detail: ",session.last_error)
		if session.worker==null: continue
		check(await session.cut_and_release(),"actual native handoff with matching physical override")
		if session.active:
			session.set_paused(true)
			check(is_equal_approx(session.body.mass,520.0*float(params.get("mass_multiplier",1.0))),"actual mass matches labelled setting")
			check(is_equal_approx(session.body.inertia,109907693.0/1560.0*float(params.get("inertia_multiplier",1.0))),"actual inertia matches labelled independent setting")
			check(is_equal_approx(session.body.gravity_scale,float(params.get("gravity",92.12))/980.0),"actual gravity setting")
			check(is_equal_approx(PhysicsServer2D.body_get_param(session.body.get_rid(),PhysicsServer2D.BODY_PARAM_FRICTION),float(params.get("friction",.78))),"actual friction setting")
			check(int(session.source_receipt.member_count)==520,"native payload unmodified by exploratory transport override")
		session.close()
	# Isolated fixture is apparatus admission only; no efficacy trajectory.
	var isolated = Session.new()
	check(await isolated.open(root,1,"isolated_half",true,"LA"),"isolated geometry construction")
	if not isolated.last_error.is_empty(): printerr("LA isolated detail: ",isolated.last_error)
	if isolated.worker!=null:
		check(await isolated.cut_and_release(),"isolated actual handoff/stump retirement")
		if isolated.active:
			isolated.set_paused(true)
			var observation: Dictionary = await isolated.inspect_coupling(PackedInt32Array([50,67,51,71,32,72,32,118]),Rect2i(0,0,160,128))
			check(observation.get("ok",false),"isolated copied census")
			check(observation.get("probe_materials",PackedInt32Array())==PackedInt32Array([0,0,0,1]),"stump and old floor absent; new floor retained")
	isolated.close()
	print("GCR_LOAD_CONTROLS ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
