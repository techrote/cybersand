extends SceneTree

# Actual unchanged playground controllers and arena/session ordering. This is
# engineering comparison data, never a substitute for human gameplay acceptance.
const Runtime = preload("res://scripts/player_playground_runtime.gd")
var failures: int = 0
var reports: Array = []

func _init() -> void: call_deferred("_run")

func check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error("GCR playground: " + reason)

func _capture(rig: StringName, candidate: String, material: int) -> Dictionary:
	var runtime = Runtime.new()
	root.add_child(runtime)
	check(runtime.configure_granular_experiment(rig,candidate,"GCR-001-2026-11-01"),"construct " + str(rig) + " " + candidate + ": " + runtime.last_error)
	if not runtime.active(): runtime.queue_free(); return {}
	await process_frame
	var world: Object = runtime._arena._world
	# Remove course material samples identically; material0 is a real hard/air
	# control, not an assumption that a controller never reaches the stock pools.
	check(world.diagnostic_fill_rect(Vector2i(454,346),Vector2i(34,6),0),"remove stock grains")
	check(world.diagnostic_fill_rect(Vector2i(552,344),Vector2i(60,8),0),"remove stock Water")
	for index: int in range(runtime._arena.session.bodies().size()):
		var pose: Transform2D = runtime._arena.session.bridge.body_transform(index)
		runtime._arena.session.bridge.reset_body(index,pose.origin+Vector2(0,-40),pose.get_rotation())
	if material != 0:
		check(world.diagnostic_fill_rect(Vector2i(148,326),Vector2i(72,26),material),"ordinary granular setup")
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(128,128),Vector2i(512,256),false,false)
	var rows: Array = []
	for step: int in range(360):
		var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":1.0,"trim":0.0,"reel":0.0,"primary":false,"secondary":false,"auxiliary":false,"tool":false}
		if rig == &"jetbarrel":
			action.primary = step >= 90 and step < 150
			action.trim = .2 if step >= 125 and step < 155 else 0.0
			action.secondary = step >= 180 and step < 210
		else:
			action.move = Vector2.RIGHT if step < 150 else Vector2.ZERO
			action.secondary = step >= 150 and step < 180
		check(runtime.submit_action(action),"actual controller command accepted")
		var view: Dictionary = runtime.step()
		check(not runtime.failed,"actual playground host healthy: " + runtime.last_error)
		var poses: Array = []
		for body: RigidBody2D in runtime._arena.session.bodies():
			var pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
			var velocity: Vector2 = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			poses.append([pose.origin.x,pose.origin.y,pose.get_rotation(),velocity.x,velocity.y,float(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY))])
		rows.append(poses)
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(128,128),Vector2i(512,256),false,false)
	if candidate == "GCR":
		check(runtime._arena.gcr_stats.responses > 0 and runtime._arena.gcr_stats.applications > 0,"actual GCR responses admitted/applied")
		if material != 0: check(runtime._arena.gcr_stats.granular_frames > 0,"actual granular response exercised")
	check(before.counts == after.counts and before.water_mass == after.water_mass,"closed host material conservation")
	var report: Dictionary = {"rig":str(rig),"candidate":candidate,"material":material,"ticks":360,"poses":rows,"gcr_stats":runtime._arena.gcr_stats.duplicate(),"conserved":before.counts==after.counts and before.water_mass==after.water_mass,"host":"actual CyberPlayerPlaygroundRuntime/CyberPhysicalActorArena/CyberPhysicalActorSession","owner_acceptance":false}
	runtime.close()
	runtime.queue_free()
	await process_frame
	return report

func _run() -> void:
	for rig: StringName in [&"jetbarrel",&"acrobat"]:
		for material: int in [0,2,14,29]:
			var baseline: Dictionary = await _capture(rig,"Y1",material)
			var candidate: Dictionary = await _capture(rig,"GCR",material)
			if material == 0 and not baseline.is_empty() and not candidate.is_empty():
				var maximum_difference: float = 0.0
				for tick: int in range(360):
					for body: int in range(baseline.poses[tick].size()):
						for field: int in range(6): maximum_difference=maxf(maximum_difference,absf(float(baseline.poses[tick][body][field])-float(candidate.poses[tick][body][field])))
				check(maximum_difference < .001,"hard/air physical channels unchanged: " + str(maximum_difference))
				candidate["hard_air_max_difference"]=maximum_difference
			reports.append(baseline); reports.append(candidate)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var file := FileAccess.open(argument.trim_prefix("--output="),FileAccess.WRITE)
			file.store_string(JSON.stringify({"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"failures":failures,"reports":reports},"\t"))
	print("GCR_PLAYGROUND reports=",reports.size()," failures=",failures,"; no human verdict")
	quit(0 if failures==0 else 1)
