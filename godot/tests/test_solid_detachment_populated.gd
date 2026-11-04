extends SceneTree

# Actual native/Rapier hosts; deterministic recipes and cut schedule. Worker/main
# scheduling is deliberately real, so contact totals and poses are measured rather
# than required to be bit-identical across operating systems or worker counts.
const Session = preload("res://scripts/solid_detachment_session.gd")
var checks: int = 0
var failures: Array[String] = []
var workers: int = 4
var surroundings: String = "packed_sand"
var conservative_displacement: bool = true

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL SOL281 POPULATED ", message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="):
			workers = int(argument.trim_prefix("--workers="))
		elif argument == "--baseline":
			conservative_displacement = false
		elif argument.begins_with("--surroundings="):
			surroundings = argument.trim_prefix("--surroundings=")
		elif not argument.begins_with("--"):
			output = argument
	check(workers in [1, 4], "worker fixture is one or four")
	check(surroundings in ["packed_sand", "embedded_sand", "mixed"], "named dense fixture")
	var session = Session.new()
	if not await session.open(root, workers, surroundings, conservative_displacement):
		check(false, session.last_error)
		session.close()
		quit(1)
		return
	var anchored: Dictionary = await session.observe_intact()
	check(anchored.get("outcome") == "Anchored", "populated tree remains native while anchored")
	var before: Dictionary = await session.inspect_coupling(PackedInt32Array(), Rect2i(0, 0, 160, 128))
	check(before.get("ok", false), "copied pre-cut material census")
	var before_material: Dictionary = before.get("diagnostic_snapshot", {})
	var before_counts: Array = before_material.get("counts", [])
	var sand_before: int = int(before_counts[2]) if before_counts.size() > 2 else -1
	var water_before: int = int(before_material.get("water_mass", -1))
	check(sand_before > (500 if surroundings == "mixed" else 1000), "dense bank contains its required Sand population")
	check(water_before > 0 if surroundings == "mixed" else water_before == 0,
		"Water fixture class is explicit")
	if not await session.cut_and_release():
		check(false, session.last_error)
		session.close()
		quit(1)
		return
	var initial: Transform2D = session.body_transform()
	var greatest_translation: float = 0.0
	var greatest_rotation: float = 0.0
	for _tick: int in range(360):
		await physics_frame
		session.physics_step()
		var pose: Transform2D = session.body_transform()
		greatest_translation = maxf(greatest_translation, pose.origin.distance_to(initial.origin))
		greatest_rotation = maxf(greatest_rotation, absf(pose.get_rotation()))
		if not pose.origin.is_finite() or not is_finite(pose.get_rotation()):
			check(false, "finite actual Rapier pose")
			break
	var after: Dictionary = await session.inspect_coupling(PackedInt32Array(), Rect2i(0, 0, 160, 128))
	var after_material: Dictionary = after.get("diagnostic_snapshot", {})
	var after_counts: Array = after_material.get("counts", [])
	var sand_after: int = int(after_counts[2]) if after_counts.size() > 2 else -2
	var water_after: int = int(after_material.get("water_mass", -2))
	var coupling: Dictionary = session.coupling_metrics()
	check(after.get("ok", false) and not after.get("worker_failed", true), "actual owner remains healthy")
	check(after.get("members") == session.source_receipt.get("members"), "exact aggregate material/state/temperature payload retained")
	check(int(after.get("aggregate_owned", -1)) == 520 and int(after.get("native_source_members", -1)) == 0,
		"aggregate remains sole owner of all 520 cells")
	check(sand_after == sand_before, "Sand quantity conserved through dense contact")
	check(water_after == water_before, "Water mass conserved through dense contact")
	check(int(coupling.get("contacts", 0)) > 0, "dense cellular contact reaches actual aggregate")
	check(int(coupling.get("state_publications", 0)) > 100, "independent Rapier/native exchange continues")
	check(greatest_translation > 0.01 or greatest_rotation > 0.001,
		"support cut admits real Rapier response in populated environment")
	var report := {"schema":"cybersand.sol281.populated.v1", "checks":checks, "failures":failures,
		"platform":OS.get_name(), "workers":workers, "surroundings":surroundings,
		"conservative_displacement":conservative_displacement,
		"sand_before":sand_before, "sand_after":sand_after,
		"water_mass_before":water_before, "water_mass_after":water_after,
		"max_translation":greatest_translation, "max_rotation":greatest_rotation,
		"coupling":coupling, "displacement":after.get("conservative_displacement", {}),
		"scope":"exact material conservation and real dense-contact host; contact quality and GPU frame pacing remain separate gates"}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
	print("SOL281_POPULATED ", JSON.stringify(report))
	session.close()
	await process_frame
	quit(0 if failures.is_empty() else 1)
