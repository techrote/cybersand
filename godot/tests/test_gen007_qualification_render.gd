extends SceneTree

# Required graphical acceptance: real material shader surfaces, isolated planes,
# composite changes, route/socket overlays and camera invariance. Headless is a
# failed gate, never a skipped success.
const Scene = preload("res://gen007_qualification.tscn")
const Data = preload("res://scripts/worldgen_qualification_data.gd")
var assertions: int = 0
var failures: int = 0
var completed: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("GEN007_RENDER: "+message)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GEN007 requires an actual display-backed material renderer")
		quit(2)
		return
	root.size = Vector2i(1024,1024)
	root.content_scale_size = root.size
	var app: Control = Scene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_expect(not app.faulted,"Qualification scene admits source-matched bundle: "+app.last_error)
	if app.faulted:
		quit(1)
		return
	app.set_hud_visible(false)
	app.show_overview()
	await _settle()
	var identity: String = app.bundle.revision
	var lifecycle: Dictionary = app.runtime.lifecycle_stats()
	var native: Dictionary = {}
	var surface_hashes: Dictionary = {}
	for plane: String in Data.PLANES:
		var packet: Dictionary = app.runtime.snapshot_layer(plane,true)
		_expect(not packet.get("failed",false),"Complete native observation for "+plane)
		native[plane] = Data.digest(packet.cells)
		var surface: Image = app.compositor._surfaces[Data.PLANES.find(plane)].get_texture().get_image()
		_expect(surface != null and surface.get_size() == Vector2i(1024,1024),"Actual complete material surface on "+plane)
		if surface == null: continue
		surface_hashes[plane] = Data.digest(surface.get_data())
		for hall: Dictionary in Data.tagged(app.bundle,"named-subregion"):
			var rect: Rect2i = hall.bounds
			var nonempty: int = 0
			for y: int in range(rect.position.y,rect.end.y):
				for x: int in range(rect.position.x,rect.end.x):
					if surface.get_pixel(x,y).a > 0.01: nonempty += 1
			_expect(nonempty > 8,"Actual "+plane+" pixels in named gallery "+str(hall.id))
	_expect(surface_hashes.size() == 4,"All four pixel oracle helpers returned")
	completed.append("four-native-material-surfaces")
	var composite: String = Data.digest(root.get_texture().get_image().get_data())
	var isolated: Dictionary = {}
	app.compositor.set_options({"mode":"stack","parallax_strength":0.0})
	for plane: int in range(4):
		for other: int in range(4): app.set_layer_visible(other,plane == other)
		await _settle()
		var rendered: Image = root.get_texture().get_image()
		var hash: String = Data.digest(rendered.get_data())
		_expect(hash != composite,"Isolated plane changes actual compositor pixels")
		isolated[hash] = true
	_expect(isolated.size() == 4,"All isolated plane images differ")
	for plane: int in range(4): app.set_layer_visible(plane,true)
	app.compositor.set_options({"mode":"hybrid","parallax_strength":0.6})
	completed.append("isolated-composites")
	app.set_diagnostics(true,true)
	await _settle()
	_expect(Data.digest(root.get_texture().get_image().get_data()) != composite,"Route and socket overlay renders")
	app.set_diagnostics(false,false)
	app.show_region(3)
	await _settle()
	_expect(Data.digest(root.get_texture().get_image().get_data()) != composite,"Region view produces actual changed pixels")
	app.show_subregion(0)
	app.compositor.set_options({"parallax_strength":1.3})
	await _settle()
	for plane: String in Data.PLANES:
		_expect(Data.digest(app.runtime.snapshot_layer(plane,true).cells) == native[plane],"Pan/zoom/parallax preserves native "+plane+" authority")
	_expect(app.bundle.revision == identity and app.runtime.lifecycle_stats() == lifecycle,"View/diagnostics preserve accepted identity and fixture lifecycle")
	completed.append("view-invariance")
	_expect(completed.size() == 3,"All graphical oracle sections completed")
	print("GEN007_RENDER: %d assertions; %d failures; completed=%s"%[assertions,failures,completed])
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
