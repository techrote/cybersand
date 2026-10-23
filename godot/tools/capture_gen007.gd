extends SceneTree

# Retained pixels are produced by the actual canonical material renderer.
# Route/socket overlays are clearly identified diagnostics, never a substitute
# for unobscured composition and isolated-plane review.
const Scene = preload("res://gen007_qualification.tscn")
const Data = preload("res://scripts/worldgen_qualification_data.gd")
var output_path: String = "user://gen007-captures"
var quick: bool = false
var captures: Array[Dictionary] = []
var records: Array[Dictionary] = []
var failed: bool = false

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gen007-output="): output_path = argument.trim_prefix("--gen007-output=")
		if argument == "--quick": quick = true
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GEN007 captures require a display-backed material renderer")
		quit(2)
		return
	var library: String = "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so" if OS.get_name() == "Linux" else "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
	var native_sha: String = FileAccess.get_sha256(library)
	var recipe_sha: String = FileAccess.get_sha256(Data.RECIPE)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path)) != OK:
		quit(1)
		return
	root.size = Vector2i(1440,1000)
	root.content_scale_size = root.size
	var app: Control = Scene.instantiate()
	root.add_child(app)
	app.set_process(false)
	if app.faulted:
		push_error(app.last_error)
		quit(1)
		return
	await _settle()
	_save(root.get_texture().get_image(),"gen007-guide.png","UI and complete scene")
	app.set_hud_visible(false)
	root.size = Vector2i(2048,2048)
	root.content_scale_size = root.size
	app.show_overview()
	await _settle()
	var atlas: Image = root.get_texture().get_image()
	_save(atlas,"gen007-atlas.png","Reference seed actual four-plane composite, 2x presentation scale")
	_save(atlas.get_region(Rect2i(960,0,128,2048)),"gen007-central-vertical-seam.png","Exact atlas crop across x512 theme/region transition")
	_save(atlas.get_region(Rect2i(0,960,2048,128)),"gen007-central-horizontal-seam.png","Exact atlas crop across y512 theme/region transition")
	_save(atlas.get_region(Rect2i(120,128,16,512)),"gen007-chunk-seam-x64.png","Exact atlas crop across native chunk x64")
	_save(atlas.get_region(Rect2i(128,248,512,16)),"gen007-chunk-seam-y128.png","Exact atlas crop across native chunk y128")
	root.size = Vector2i(1024,1024)
	root.content_scale_size = root.size
	for region: int in range(4):
		app.show_region(region)
		await _settle()
		_save(root.get_texture().get_image(),"gen007-region-%d.png"%(region+1),"Actual 512-cell thematic district close-up")
	_record(app)
	if not quick:
		app.show_overview()
		app.compositor.set_options({"mode":"stack","parallax_strength":0.0})
		for plane: int in range(4):
			for other: int in range(4): app.set_layer_visible(other,plane == other)
			await _settle()
			_save(root.get_texture().get_image(),"gen007-"+Data.PLANES[plane]+".png","Actual isolated "+Data.PLANES[plane]+" material plane")
		for plane: int in range(4): app.set_layer_visible(plane,true)
		app.compositor.set_options({"mode":"hybrid","parallax_strength":0.6})
		app.set_diagnostics(true,true)
		await _settle()
		_save(root.get_texture().get_image(),"gen007-routes-sockets.png","Accepted semantic route and socket overlay")
		app.set_diagnostics(false,false)
		for subregion: int in range(8):
			app.show_subregion(subregion)
			await _settle()
			_save(root.get_texture().get_image(),"gen007-gallery-%d.png"%(subregion+1),"Actual named gallery close-up")
		for index: int in range(1,4):
			if not app.load_seed(index):
				push_error(app.last_error)
				quit(1)
				return
			app.show_overview()
			await _settle()
			_save(root.get_texture().get_image(),"gen007-seed-%d.png"%Data.SEEDS[index],"Declared seed variation at identical world coordinates")
			_record(app)
		if not app.load_seed(0):
			quit(1)
			return
		for tick: int in range(220):
			var result: Dictionary = app.runtime.step_once()
			if not result.get("ok",false):
				push_error("Native capture programme failed at tick "+str(tick))
				quit(1)
				return
		if not app.publish_layers(true):
			quit(1)
			return
		app.show_overview()
		await _settle()
		_save(root.get_texture().get_image(),"gen007-after-220-ticks.png","Actual result after220 manual ticks of each dynamic plane; native products")
	var expected: int = 10 if quick else 27
	if FileAccess.get_sha256(library) != native_sha or FileAccess.get_sha256(Data.RECIPE) != recipe_sha:
		failed = true
		push_error("GEN007 capture source or loaded-library file changed during capture; identity is not stable")
	if captures.size() != expected or records.size() != (1 if quick else 4) or failed:
		push_error("Incomplete GEN007 capture helpers: %d/%d"%[captures.size(),expected])
		quit(1)
		return
	var manifest: Dictionary = {"schema":1,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"native_library_sha256":native_sha,"recipe_sha256":recipe_sha,
		"recipe_bytes":FileAccess.get_file_as_bytes(Data.RECIPE).size(),"qualification":Data.manifest(),
		"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"renderer":RenderingServer.get_video_adapter_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"records":records,"captures":captures,
		"complete":true,"quick":quick,"native_products_painted":false}
	var file := FileAccess.open(output_path.path_join("capture-manifest.json"),FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(manifest,"\t",true,true)+"\n")
	print("GEN007_CAPTURE: %d actual rendered captures; %d seed receipts; complete=true"%[captures.size(),records.size()])
	app.queue_free()
	await process_frame
	quit(0)

func _record(app: Control) -> void:
	var material_counts: Dictionary = {}
	for plane: String in Data.PLANES:
		var nonempty: int = 0
		for value: int in app.bundle.materials[plane]:
			if value != 0: nonempty += 1
		material_counts[plane] = {"nonempty_cells":nonempty,"intentional_empty_cells":1048576-nonempty}
	records.append({"seed":Data.SEEDS[app.seed_index],"revision":app.bundle.revision,"hashes":app.bundle.hashes,
		"generation_and_admission_ms":app.generation_ms,"operations":app.bundle.operations,
		"native_storage_bytes":app.bundle.storage_bytes,"native_limits":app.bundle.budgets,"native_spatial_index":app.bundle.spatial_index,
		"features":app.bundle.features.size(),"projections":app.bundle.projections.size(),"fixtures":app.bundle.fixtures.size(),
		"material_coverage":material_counts,"complete":true})

func _save(image: Image, filename: String, meaning: String) -> void:
	if image == null or image.is_empty() or image.save_png(output_path.path_join(filename)) != OK:
		failed = true
		push_error("Could not retain rendered image "+filename)
		return
	captures.append({"file":filename,"meaning":meaning,"width":image.get_width(),"height":image.get_height(),
		"sha256":FileAccess.get_sha256(output_path.path_join(filename))})

func _settle() -> void:
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
