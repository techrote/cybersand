extends SceneTree

const Scene = preload("res://semantic_depth.tscn")
const PLANES: Array[String] = ["play", "scripted", "effects", "background"]
const NAMES: Array[String] = ["refinery", "flooded-cavern"]
const TICKS: int = 240
var output_path: String = "user://semantic-depth-captures"
var captures: Array[Dictionary] = []
var records: Array[Dictionary] = []
var failed: bool = false

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--semantic-output="):
			output_path = argument.trim_prefix("--semantic-output=")
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Semantic-depth captures require a graphical material renderer")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path)) != OK:
		push_error("Cannot create capture directory")
		quit(2)
		return
	var app: Control = Scene.instantiate()
	root.add_child(app)
	app.set_process(false)
	if app.faulted:
		push_error(app.last_error)
		quit(1)
		return
	for example: int in range(2):
		if not app.load_example(example):
			push_error(app.last_error)
			quit(1)
			return
		root.size = Vector2i(1440, 1000)
		root.content_scale_size = root.size
		app.set_hud_visible(true)
		app.show_overview()
		await _settle()
		_save(root.get_texture().get_image(), NAMES[example] + "-guide.png")
		app.set_hud_visible(false)
		root.size = Vector2i(1024, 1024)
		root.content_scale_size = root.size
		app.show_overview()
		await _settle()
		_save(root.get_texture().get_image(), NAMES[example] + "-composite.png")
		var material_coverage: Dictionary = {}
		app.compositor.set_options({"mode": "stack", "parallax_strength": 0.0})
		for plane: int in range(4):
			for other: int in range(4): app.set_layer_visible(other, plane == other)
			await _settle()
			_save(root.get_texture().get_image(), "%s-%s.png" % [NAMES[example], PLANES[plane]])
			var image: Image = app.compositor._surfaces[plane].get_texture().get_image()
			var nonempty: int = 0
			for y: int in range(image.get_height()):
				for x: int in range(image.get_width()):
					if image.get_pixel(x, y).a > 0.02: nonempty += 1
			material_coverage[PLANES[plane]] = nonempty
			if nonempty <= 8:
				push_error("A required material plane rendered empty")
				failed = true
		for plane: int in range(4): app.set_layer_visible(plane, true)
		app.compositor.set_options({"mode": "hybrid", "parallax_strength": 0.75})
		for region: int in range(4):
			app.select_region(region)
			await _settle()
			_save(root.get_texture().get_image(), "%s-region-%d.png" % [NAMES[example], region + 1])
		for tick: int in range(TICKS):
			var step: Dictionary = app.runtime.step_once()
			if not bool(step.get("ok", false)):
				push_error("Native step failed at " + str(tick))
				quit(1)
				return
		if not app.publish_layers(true):
			quit(1)
			return
		app.show_overview()
		await _settle()
		_save(root.get_texture().get_image(), NAMES[example] + "-after-240-ticks.png")
		var recipe_path: String = ProjectSettings.globalize_path("res://../examples/worldgen/%s.json" % app.EXAMPLES[example])
		records.append({"example": app.EXAMPLES[example], "recipe_sha256": FileAccess.get_sha256(recipe_path),
			"bundle_id": app.bundle.id, "bundle_revision": app.bundle.revision,
			"bounds": app.bundle.bounds, "features": app.bundle.features.size(),
			"projections": app.bundle.projections.size(), "links": app.bundle.links.size(),
			"fixtures": app.bundle.fixtures.size(), "actors": app.bundle.get("actors", []).size(), "ticks": TICKS,
			"material_surface_nonempty_pixels": material_coverage,
			"runtime": app.runtime.stats(), "lifecycle": app.runtime.lifecycle_stats(),
			"compositor": app.compositor.get_diagnostics(), "oracle_completed": true})
	if records.size() != 2 or captures.size() != 22 or failed:
		push_error("Incomplete semantic-depth capture manifest")
		quit(1)
		return
	var manifest: Dictionary = {"schema": 1, "source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"native_library_sha256": FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so") if OS.get_name() == "Linux" else FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
		"engine": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_video_adapter_name(), "method": RenderingServer.get_current_rendering_method(),
		"initial_state": "paused at native tick zero; copied native RG8 material surfaces; frozen material animation",
		"source_products": "Native fixtures supply reagents; reaction products are made by the existing native kernels.",
		"records": records, "captures": captures, "capture_failures": false}
	var file := FileAccess.open(output_path.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t", true, true) + "\n")
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		quit(1)
		return
	print("SEMANTIC_DEPTH_CAPTURE: 22 actual rendered captures and two complete example receipts saved to ", output_path)
	app.queue_free()
	await process_frame
	quit(0)

func _save(image: Image, filename: String) -> void:
	if image == null or image.is_empty() or image.save_png(output_path.path_join(filename)) != OK:
		failed = true
		push_error("Could not save actual material render " + filename)
		return
	captures.append({"file": filename, "width": image.get_width(), "height": image.get_height(),
		"sha256": FileAccess.get_sha256(output_path.path_join(filename))})

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
