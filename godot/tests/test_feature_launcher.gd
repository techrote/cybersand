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
	for destination: String in ["blacksite", "showcase", "actors", "sandbox", "thunderbowl", "worldgen", "semantic_depth", "depth", "deepworks", "player_playground", "experimental/blacksite/ripper"]:
		var menu: Control = Launcher.instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		menu.launch(destination)
		await process_frame
		await process_frame
		var scene: Node = current_scene
		expect(scene != null and scene != menu, "Launcher must replace the menu: " + destination)
		if destination in ["blacksite", "showcase", "experimental/blacksite/ripper"]:
			var deadline: int = Time.get_ticks_msec() + 60000
			while scene.pending_microscenario_apply.is_empty() and scene.microscenario_definition.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
			while not scene.pending_microscenario_apply.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
			expect(not scene.microscenario_definition.is_empty(), "Scene must acknowledge selected world: " + destination)
		if destination == "actors": expect(scene.actor_prototype_panel.visible, "Actor selector must open")
		if destination == "worldgen": expect(scene.scene_file_path == "res://worldgen_workbench.tscn", "Worldgen must stay a separate scene")
		if destination == "semantic_depth": expect(scene.scene_file_path == "res://semantic_depth.tscn" and not scene.faulted and not scene.bundle.is_empty(), "Semantic depth must install its complete four-plane bundle")
		if destination == "thunderbowl": expect(scene.scene_file_path.ends_with("thunderbowl.tscn"), "Arena must stay a separate scene")
		if destination == "depth": expect(scene.scene_file_path == "res://depth_lab.tscn" and not scene.faulted, "Depth must open its isolated four-world host")
		if destination == "deepworks": expect(scene.scene_file_path == "res://deepworks.tscn" and not scene.faulted, "Deepworks must open its complete four-world exhibition")
		if destination == "player_playground": expect(scene.scene_file_path == "res://player_playground.tscn" and scene.runtime.active() and not scene.runtime.failed, "Player playground must own its live native and physical session")
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
