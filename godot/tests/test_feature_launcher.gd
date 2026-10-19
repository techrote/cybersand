extends SceneTree

const Launcher = preload("res://feature_launcher.tscn")
var failures: int = 0
var assertions: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for destination: String in ["grey_area_51", "blacksite", "showcase", "actors", "sandbox", "thunderbowl", "worldgen", "depth", "experimental/blacksite/ripper"]:
		var menu: Control = Launcher.instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		menu.launch(destination)
		await process_frame
		await process_frame
		var scene: Node = current_scene
		expect(scene != null and scene != menu, "Launcher must replace the menu: " + destination)
		if destination in ["grey_area_51", "blacksite", "showcase", "experimental/blacksite/ripper"]:
			var deadline: int = Time.get_ticks_msec() + 60000
			while scene.pending_microscenario_apply.is_empty() and scene.microscenario_definition.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
			while not scene.pending_microscenario_apply.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
			expect(not scene.microscenario_definition.is_empty(), "Scene must acknowledge selected world: " + destination)
		if destination == "actors": expect(scene.actor_prototype_panel.visible, "Actor selector must open")
		if destination == "worldgen": expect(scene.scene_file_path == "res://worldgen_workbench.tscn", "Worldgen must stay a separate scene")
		if destination == "thunderbowl": expect(scene.scene_file_path.ends_with("thunderbowl.tscn"), "Arena must stay a separate scene")
		if destination == "depth": expect(scene.scene_file_path == "res://depth_lab.tscn" and not scene.faulted, "Depth must open its isolated four-world host")
		var event := InputEventKey.new()
		event.keycode = KEY_F2
		event.pressed = true
		root.get_node("FeatureNavigation")._input(event)
		await process_frame
		await process_frame
		expect(current_scene != null and current_scene.scene_file_path == "res://feature_launcher.tscn", "F2 must return to launcher: " + destination)
		expect(not has_meta("cybersand_feature"), "Navigation must clear session selection")
		current_scene.queue_free()
		current_scene = null
		await process_frame
	print("Feature launcher: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
