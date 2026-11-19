extends SceneTree

# WAVE-WATERWALL-001 evidence driver (not a CI test): real Shared Workbench,
# Wave Flow, the repeated-impact comparison scene with four real Rapier bodies.
# Runs the scene at a given Body push / Push by amount and prints how far the
# bodies sank and the Water impulse they received.
#   godot --headless --path godot --script res://tests/workbench_body_push_probe.gd -- PUSH BY_MASS TICKS
const Scenes = preload("res://scripts/workbench_water_comparison_scenes.gd")
var host: Control
var bench: Control

func _initialize() -> void:
	run.call_deferred()

func installed() -> bool:
	return bench != null and not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func until(predicate: Callable, seconds := 300.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var push := int(args[0]); var by_mass := int(args[1]); var ticks := int(args[2])
	root.size = Vector2i(1600,900)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	host = current_scene
	bench = host.shared_workbench
	await until(installed)
	var spray = bench.water_spray
	host.workbench_water_options["workbench_wave_body_push"] = push
	host.workbench_water_options["workbench_wave_body_push_by_mass"] = by_mass
	spray._set_wave(true)
	var index := -1
	for i: int in Scenes.SCENES.size():
		if str(Scenes.SCENES[i].id).contains("impact"): index = i
	var before := int(host.tower_context.get("wave_flow",{}).get("session_generation",-1))
	if not bench.load_water_comparison(str(Scenes.SCENES[index].id)):
		print("PROBE refused ", bench.message); quit(1); return
	await until(func() -> bool: return installed() and int(host.tower_context.get("wave_flow",{}).get("session_generation",-1)) > before)
	var wave: Dictionary = host.tower_context.get("wave_flow",{})
	var bodies: Array = host.physical_actor_session.bodies()
	var start_y: Array = []
	for body: Node2D in bodies: start_y.append(body.global_position.y)
	var tick0 := int(wave.get("completed_tick",0))
	for t: int in ticks:
		var tick: int = int(host.tower_context.get("wave_flow",{}).get("completed_tick",0))
		bench.step_once()
		await until(func() -> bool: return installed() and int(host.tower_context.get("wave_flow",{}).get("completed_tick",0)) >= tick+1, 30.0)
	var sink: Array = []
	for i: int in bodies.size(): sink.append(snappedf(bodies[i].global_position.y - start_y[i], 0.1))
	wave = host.tower_context.get("wave_flow",{})
	print("PROBE ", JSON.stringify({"scene":Scenes.SCENES[index].id,"push":push,"by_mass":by_mass,
		"native_push":wave.get("parameters",{}).get("body_push"),"native_by_mass":wave.get("parameters",{}).get("body_push_by_mass"),
		"ticks":int(wave.get("completed_tick",0))-tick0,"sink":sink,"quantity":wave.get("water_quantity")}))
	host.queue_free()
	await process_frame
	await process_frame
	quit(0)
