extends SceneTree

# Exercise real launcher Button signals and F2 teardown, not just path constants.
const Launcher = preload("res://feature_launcher.tscn")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("Granular review navigation: " + message)

func run() -> void:
	var labels: Dictionary = {
		"Granular barrel comparison":"res://gcr_load_review.tscn",
		"Structural cut / support tests":"res://solid_detachment_lab.tscn",
		"Flyer playground + painting":"res://gcr_fleet_playground.tscn",
	}
	for label: String in labels:
		var menu: Control = Launcher.instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		var matches: Array[Button] = []
		for node: Button in menu.find_children("*", "Button", true, false):
			if node.text == label:
				matches.append(node)
		check(matches.size() == 1, "one visible menu route for " + label)
		if matches.size() != 1:
			menu.queue_free()
			current_scene = null
			await process_frame
			continue
		var old_menu: WeakRef = weakref(menu)
		matches[0].pressed.emit()
		await process_frame
		await process_frame
		var scene: Node = current_scene
		check(scene != null and scene.scene_file_path == labels[label], "actual target scene for " + label)
		check(old_menu.get_ref() == null, "menu retired before target review")
		if scene == null:
			continue
		if label == "Granular barrel comparison":
			check(scene.fixture != null and scene.fixture.error.is_empty(), "barrel fixture ready")
		elif label == "Structural cut / support tests":
			var deadline: int = Time.get_ticks_msec() + 30000
			while scene.busy and Time.get_ticks_msec() < deadline:
				await process_frame
			check(not scene.busy and scene.session != null and scene.session.worker != null, "structural worker/session ready")
		else:
			check(scene.runtime != null and scene.runtime.active() and not scene.runtime.failed, "flyer native/Rapier owner ready")
		var old_review: WeakRef = weakref(scene)
		var event := InputEventKey.new()
		event.keycode = KEY_F2
		event.pressed = true
		root.get_node("FeatureNavigation")._input(event)
		await process_frame
		await process_frame
		check(current_scene != null and current_scene.scene_file_path == "res://feature_launcher.tscn", "F2 returns from " + label)
		check(old_review.get_ref() == null, "old review owner scene freed by F2")
		check(not has_meta("cybersand_feature"), "F2 clears selection metadata")
		current_scene.queue_free()
		current_scene = null
		await process_frame
	var original_web_setting: Variant = ProjectSettings.get_setting("cybersand/web_demo",false)
	ProjectSettings.set_setting("cybersand/web_demo",true)
	var web_menu: Control = Launcher.instantiate()
	root.add_child(web_menu)
	current_scene=web_menu
	await process_frame
	var review_buttons: int = 0
	for button: Button in web_menu.find_children("*","Button",true,false):
		if button.text in labels: review_buttons+=1
	check(review_buttons==0,"desktop review routes remain hidden in Web demo policy")
	web_menu.launch("granular_flyers")
	await process_frame
	check(current_scene==web_menu,"unsupported Web review request retains launcher")
	ProjectSettings.set_setting("cybersand/web_demo",original_web_setting)
	current_scene.queue_free()
	current_scene=null
	await process_frame
	print("GCR_REVIEW_NAVIGATION ", JSON.stringify({"checks":checks,"failures":failures,"routes":labels.size()}))
	quit(0 if failures == 0 else 1)
