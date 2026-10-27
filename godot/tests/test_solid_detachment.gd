extends SceneTree
const Session = preload("res://scripts/solid_detachment_session.gd")
var checks: int = 0
var failures: Array[String] = []
var session: RefCounted
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 ",message)
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	session = Session.new()
	if not await session.open(root,4):
		check(false,session.last_error)
		session.close()
		quit(1)
		return
	var intact: Dictionary = await session.observe_intact()
	check(intact.get("outcome") == "Anchored","intact real native tree remains anchored")
	check(intact.get("source_probe") == 43,"initial trunk/crown is actual RedBrick cells")
	check(not intact.get("fenced",true),"anchored refusal has no outstanding transaction")
	if not await session.cut_and_release():
		check(false,session.last_error)
		session.close()
		quit(1)
		return
	var source: Dictionary = session.source_receipt
	var committed: Dictionary = session.commit_receipt
	check(source.get("member_count") == 520,"exact 520 native members extracted")
	check(source.get("native_source_members") == 520,"all prepared payload still native before commit")
	check(source.get("cut_applied",false),"real applied native cut, not an actor trigger")
	check(source.get("shape_count",0) > 1,"irregular exact compound geometry")
	check(source.get("configured_workers") == 4,"existing owner uses configured four native workers")
	check(committed.get("aggregate_owned") == 520,"committed exact aggregate ownership")
	check(committed.get("source_probe") == 0,"native source really retired")
	check(committed.get("stump_probe") == 43 and committed.get("ground_probe") == 1 and committed.get("nearby_tree_probe") == 43,"stump, ground and unrelated tree retained")
	check(session.final_receipt.get("phase") == 6,"active only after collision revision receipt")
	check(session.bridge.manual_step_count() == 0,"no physics step inside handoff")
	var initial: Transform2D = session.body_transform()
	var max_rotation: float = 0.0
	var max_speed: float = 0.0
	var max_horizontal: float = 0.0
	var max_down: float = 0.0
	var history: Array = []
	for i: int in range(600):
		await physics_frame
		session.physics_step()
		var t: Transform2D = session.body_transform()
		max_rotation = maxf(max_rotation,absf(t.get_rotation()))
		max_speed = maxf(max_speed,absf(session.angular_velocity()))
		max_horizontal = maxf(max_horizontal,absf(t.origin.x-initial.origin.x))
		max_down = maxf(max_down,t.origin.y-initial.origin.y)
		if i % 60 == 59:
			history.append({"tick":i+1,"x":t.origin.x,"y":t.origin.y,"rotation":t.get_rotation(),"omega":session.angular_velocity()})
	var final: Dictionary = await session.inspect_active()
	check(max_down > 2.0,"real gravity-driven fall")
	check(max_rotation > 0.7,"natural toppling/rotation, no transform writes")
	check(max_speed > 0.1,"real nonzero Rapier angular velocity")
	check(max_horizontal > 2.0,"horizontal rolling/displacement after contact")
	check(final.get("native_source_members") == 0 and final.get("aggregate_owned") == 520,"no resurrection/lost payload during motion")
	check(final.get("members") == source.get("members"),"full exact payload preserved, not hash only")
	check(final.get("actual_native_tick",0) > 0,"independently paced existing native worker advanced")
	check(not final.get("worker_failed",true),"ordinary owner did not fail from handoff fences")
	var report: Dictionary = {"schema":"cybersand.sol281.actual-async-rapier.v1","checks":checks,"failures":failures,
		"platform":OS.get_name(),"engine":Engine.get_version_info().string,"members":source.member_count,
		"shapes":source.shape_count,"mass":source.mass,"inertia":source.inertia,"source_native_members":source.native_source_members,
		"aggregate_owned":final.get("aggregate_owned"),"native_ticks":final.get("actual_native_tick"),
		"rapier_ticks":session.bridge.manual_step_count(),"max_down":max_down,"max_rotation":max_rotation,
		"max_angular_velocity":max_speed,"max_horizontal":max_horizontal,"history":history,
		"scope":"dry homogeneous inert native tree; no compound native material coupling, reactive Wood, general desoliding or full application acceptance"}
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0],FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report,"\t"))
			file.close()
	print("SOL281_ACTUAL_RAPIER ",JSON.stringify(report))
	session.close()
	await process_frame
	session = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
