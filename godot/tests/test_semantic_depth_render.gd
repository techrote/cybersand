extends SceneTree

# Real material surfaces and the composite must render, while every camera and
# parallax operation leaves generated authority and semantic identity unchanged.
const Scene = preload("res://semantic_depth.tscn")
const PLANES: Array[String] = ["play", "scripted", "effects", "background"]
var assertions: int = 0
var failures: int = 0
var completed_examples: int = 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Semantic depth pixel acceptance requires a graphical renderer")
		quit(2)
		return
	root.size = Vector2i(768, 768)
	root.content_scale_size = Vector2i(768, 768)
	var app: Control = Scene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_expect(not app.faulted, "Default semantic depth example must initialize: " + app.last_error)
	if app.faulted:
		quit(1)
		return
	for example: int in range(2):
		_expect(app.load_example(example), "Example admission " + str(example) + ": " + app.last_error)
		if app.faulted or app.runtime == null: continue
		app.set_hud_visible(false)
		app.show_overview()
		await _settle()
		var original: Dictionary = app.bundle.duplicate(true)
		var authority: Dictionary = app.runtime.lifecycle_stats()
		var actor_authority: Dictionary = app.runtime.actor_snapshot()
		var material_hashes: Dictionary = {}
		var pixels: Dictionary = {}
		for plane: String in PLANES:
			var packet: Dictionary = app.runtime.snapshot_layer(plane, true)
			_expect(not packet.get("failed", false) and packet.get("cells", PackedByteArray()).size() == 2097152, "Copied authority for " + plane)
			material_hashes[plane] = _digest(packet.get("cells", PackedByteArray()))
			var surface: CyberDepthLayerSurface = app.compositor._surfaces[PLANES.find(plane)]
			var image: Image = surface.get_texture().get_image()
			_expect(image != null and image.get_size() == app.runtime.world_size, "Complete material surface " + plane)
			if image == null: continue
			var nonempty: int = 0
			for y: int in range(image.get_height()):
				for x: int in range(image.get_width()):
					if image.get_pixel(x, y).a > 0.02: nonempty += 1
			_expect(nonempty > 8, "Material plane actually renders nonempty coverage: " + plane)
			pixels[plane] = _digest(image.get_data())
		_expect(pixels.size() == 4, "All four material pixel oracles completed")
		for a: int in range(4):
			for b: int in range(a + 1, 4):
				_expect(pixels.get(PLANES[a]) != pixels.get(PLANES[b]), "Planes retain independent rendered contents")
		var full_view: String = _digest(root.get_texture().get_image().get_data())
		app.select_region(2)
		app.compositor.set_view(Vector2(24, 94), Vector2(96, 96))
		app.compositor.layer_parallax = Vector4(1.0, 0.86, 0.65, 0.35)
		app.compositor.set_view(app.compositor.camera_origin, app.compositor.view_size)
		app.compositor.set_options({"parallax_strength": 1.4})
		app._present_actors()
		await _settle()
		_expect(_digest(root.get_texture().get_image().get_data()) != full_view, "Pan/zoom/parallax visibly change presentation")
		var regenerated: Dictionary = app.generator.generate_plane_bundle()
		_expect(regenerated.get("ok", false), "Regeneration after view change succeeds")
		for field: String in ["revision", "fingerprint", "layers", "features", "projections", "fixtures", "links", "actors"]:
			_expect(regenerated.get(field) == original.get(field), "View transforms preserve generation field " + field)
		_expect(app.runtime.lifecycle_stats() == authority, "View change preserves owner and fixture lifecycle")
		_expect(app.runtime.actor_snapshot() == actor_authority, "View changes preserve the existing play-only actor owner")
		_expect(original.get("actors", []).size() == 4, "Each region has one declared play-only inspector")
		for plane: String in PLANES:
			var after: Dictionary = app.runtime.snapshot_layer(plane, true)
			_expect(_digest(after.get("cells", PackedByteArray())) == material_hashes[plane], "View change preserves actual native cells on " + plane)
		var families: Dictionary = {}
		for link: Dictionary in original.links: families[link.family] = true
		for family: String in ["explosion", "vent", "window", "pipe", "waterfall", "machinery"]:
			_expect(families.has(family), "Example has explicit " + family + " correspondence")
		for effect: String in ["blast", "burst"]:
			var receipt: Dictionary = app.fire_event(effect)
			_expect(receipt.get("accepted", false), "Demo submits a bounded " + effect + " observation")
			var selected_owner: bool = false
			for link: Dictionary in original.links:
				if link.id == receipt.get("link_id", ""):
					selected_owner = link.owner_x == -1 and link.owner_y == 0
			_expect(selected_owner, "Event stays inside the selected named region")
		_expect(app.step_once(), "Demo advances native material owners")
		_expect(app.runtime.layer_tick("background") == 0, "Distant world stays frozen")
		_expect(app.reset_example(), "Demo resets the full semantic bundle")
		_expect(app.runtime.layer_tick("play") == 0 and app.runtime.layer_tick("scripted") == 0, "Reset starts a coherent fresh owner incarnation")
		completed_examples += 1
	_expect(completed_examples == 2, "Both complete example oracles ran without helper aborts")
	print("Semantic depth pixels: %d assertions, %d failures; completed examples %d/2" % [assertions, failures, completed_examples])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw

func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("SEMANTIC_DEPTH_RENDER: " + message)
