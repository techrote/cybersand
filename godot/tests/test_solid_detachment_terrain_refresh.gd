extends SceneTree

const Session = preload("res://scripts/solid_detachment_session.gd")
var checks: int = 0
var failures: Array[String] = []
var workers: int = 4

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 TERRAIN ", message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="):
			workers = int(argument.trim_prefix("--workers="))
	var session = Session.new()
	if not await session.open(root, workers) or not await session.cut_and_release():
		check(false, session.last_error)
		session.close()
		quit(1)
		return
	for _tick: int in range(480):
		await physics_frame
		session.physics_step()
	var before: Dictionary = session.coupling_metrics()
	var start: Transform2D = session.body_transform()
	check(session.excavate_support(), "ordinary native erase admitted below resting aggregate")
	for _tick: int in range(180):
		await physics_frame
		session.physics_step()
	var after: Dictionary = session.coupling_metrics()
	var observation: Dictionary = await session.inspect_coupling(PackedInt32Array([20, 73, 9, 50]))
	check(int(after.get("terrain_revision", -1)) > int(before.get("terrain_revision", -1)),
		"new native hard-surface revision consumed")
	check(int(after.get("terrain_refreshes", 0)) > int(before.get("terrain_refreshes", 0)),
		"main-thread static collision refresh ran after excavation")
	check(session.bridge.pending_hard_surface_chunks() == 0, "bounded terrain refresh drained")
	check(session.body_transform().origin.y > start.origin.y + 0.5,
		"Rapier falls when real static support is removed")
	var controls: PackedInt32Array = observation.get("probe_materials", PackedInt32Array())
	check(controls == PackedInt32Array([1, 43]), "unrelated floor and control tree remain native")
	check(observation.get("members") == session.source_receipt.get("members")
		and observation.get("aggregate_owned") == 520, "excavation preserves aggregate exact payload")
	check(not observation.get("worker_failed", true), "native owner remains healthy")
	print("SOL281_TERRAIN_REFRESH ", JSON.stringify({"checks":checks, "failures":failures,
		"workers":workers, "platform":OS.get_name(), "before":before, "after":after,
		"fall_after_excavation":session.body_transform().origin.y - start.origin.y}))
	session.close()
	await process_frame
	quit(0 if failures.is_empty() else 1)
