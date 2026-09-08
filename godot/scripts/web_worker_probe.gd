class_name CyberWebWorkerProbe
extends RefCounted

# Explicit acceptance probe only. Worlds are released between worker counts,
# exercising pthread teardown/reuse as well as exact exported level parity.
static func sample(workers: int, tree: SceneTree) -> Dictionary:
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var hashes: Array = []
	var moves: int = 0
	var elapsed: float = 0.0
	var parallel_phases: int = 0
	for id: String in ["material_lab", "waterworks", "foundry", "neon_works"]:
		print("WEB_WORKER_PROBE_BEGIN ", workers, " ", id)
		if not bridge.build_world(world, CyberDemoWorlds.rectangles(id)):
			return {"ok": false, "error": "construction " + id}
		world.set_simulation_window(Vector2i.ZERO, Vector2i(480, 270), 32, 32)
		for tick: int in range(30):
			await tree.process_frame
			if not world.simulation_tick():
				return {"ok": false, "error": "tick " + id}
			moves += int(world.get_moves_last_tick())
			elapsed += float(world.get_simulation_time_ms())
			parallel_phases += int(world.get_scheduler_parallel_phases_last_tick())
			var hasher: HashingContext = HashingContext.new()
			hasher.start(HashingContext.HASH_SHA256)
			hasher.update(bridge.export_level(world))
			hashes.append(hasher.finish().hex_encode())
	print("WEB_WORKER_PROBE_END ", workers)
	return {"ok": true, "workers": int(world.get_worker_threads()), "hashes": hashes, "moves": moves, "parallel_phases": parallel_phases, "mean_tick_ms": elapsed / 120.0}

static func run(tree: SceneTree) -> Dictionary:
	var previous: int = int(ProjectSettings.get_setting("cybersand/native_worker_threads", 1))
	var serial: Dictionary = await sample(1, tree)
	await tree.process_frame
	var parallel: Dictionary = await sample(4, tree)
	await tree.process_frame
	ProjectSettings.set_setting("cybersand/native_worker_threads", previous)
	var passed: bool = bool(serial.ok) and bool(parallel.ok) and int(parallel.get("workers", 0)) > 1 and serial.get("hashes") == parallel.get("hashes") and int(serial.get("moves", 0)) > 0 and serial.get("moves") == parallel.get("moves")
	passed = passed and int(parallel.get("parallel_phases", 0)) > 0
	return {"passed": passed, "serial": serial, "parallel": parallel}
