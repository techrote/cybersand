extends SceneTree

# Stock embedded default font, actual nearest-filtered Canvas rendering and GPU
# atlas readback. Safe mode compares mipmaps off/on. Separate mode only submits
# enabled fonts and compares to Safe's retained pixels, avoiding the known
# mutable non-mipmap producer inside the separate-render oracle itself.
const INITIAL_TEXT: String = "Workbench PAINT Save Undo 123456"
const LATER_TEXT: String = "ZYXWVU qjz 7890 []{} @#$% &+=/<>"
const VIEW_SIZE := Vector2i(900,300)
const FONT_SIZE: int = 16

class QueueGate extends RefCounted:
	var entered := Semaphore.new()
	var resume := Semaphore.new()
	var cancel := Semaphore.new()
	var watcher := Thread.new()
	var expired: bool = false
	var owner: bool = false
	func block_queue() -> void:
		owner = RenderingServer.is_on_render_thread()
		entered.post()
		resume.wait()
	func watch() -> void:
		var deadline: int = Time.get_ticks_msec()+10000
		while Time.get_ticks_msec() < deadline:
			if cancel.try_wait(): return
			OS.delay_msec(5)
		expired = true
		entered.post()
		resume.post()
	func begin() -> void:
		watcher.start(watch)
		RenderingServer.call_on_render_thread(block_queue)
		entered.wait()
	func end() -> void:
		resume.post()
		cancel.post()
		watcher.wait_to_finish()

var assertions: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []
var screenshots: Dictionary = {}
var pairs_completed: int = 0
var ownership_completed: bool = false
var output: String = ""
var separate: bool = false
var default_font: FontFile
var font_data_hash: String = ""
var text_server: TextServer
var original_default_mipmaps: bool = false


func _init() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("DEFAULT_FONT_MIPMAP: "+label)


func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


func _base(source: Image) -> Image:
	if source == null: return null
	var result: Image = source.duplicate()
	result.clear_mipmaps()
	result.convert(Image.FORMAT_RGBA8)
	return result


func _font(mipmaps: bool) -> FontFile:
	var result: FontFile = default_font.duplicate(true) as FontFile
	check(result != null and result != default_font,"independent default-font resource created")
	if result == null: return null
	result.clear_cache()
	result.generate_mipmaps = mipmaps
	check(result.data == default_font.data and _sha(result.data) == font_data_hash,
		"font bytes are the actual embedded default font")
	# Duplicate the actual default's rasterization settings; only the requested
	# mipmap flag differs. Cache resources and resource bookkeeping are excluded.
	for property: Dictionary in default_font.get_property_list():
		var name: String = property.name
		if (int(property.usage)&PROPERTY_USAGE_STORAGE) == 0 or name.begins_with("cache/") \
				or name.begins_with("resource_") or name in ["generate_mipmaps","data","script"]: continue
		check(result.get(name) == default_font.get(name),"default-font setting preserved: "+name)
	check(result.generate_mipmaps == mipmaps,"actual FontFile mipmap flag matches treatment")
	var ids: Array[RID] = result.get_rids()
	check(not ids.is_empty() and text_server.font_get_generate_mipmaps(ids[0]) == mipmaps,
		"actual TextServer font flag matches treatment")
	return result


func _view(font: FontFile) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.gui_disable_input = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var container := Control.new()
	container.size = Vector2(VIEW_SIZE)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	var theme := Theme.new()
	theme.default_font = font
	container.theme = theme
	viewport.add_child(container)
	var background := ColorRect.new()
	background.color = Color(0.08,0.11,0.16,1)
	background.size = Vector2(VIEW_SIZE)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(background)
	var labels: Array[Label] = []
	var y: float = 12
	for size: int in [13,16,24,32]:
		var label := Label.new()
		label.position = Vector2(12,y)
		label.size = Vector2(870,48)
		label.text = INITIAL_TEXT
		label.add_theme_font_size_override("font_size",size)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(label)
		check(label.get_theme_font("font") == font,"actual Label inherits the intended independent font")
		labels.append(label)
		y += 50
	var button := Button.new()
	button.position = Vector2(12,220)
	button.size = Vector2(500,48)
	button.text = INITIAL_TEXT
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(button)
	check(button.get_theme_font("font") == font,"actual Button inherits the intended independent font")
	return {"viewport":viewport,"container":container,"labels":labels,"button":button,"font":font}


func _change_text(view: Dictionary) -> void:
	for label: Label in view.labels: label.text = LATER_TEXT
	view.button.text = LATER_TEXT


func _draw_pair(a: Dictionary, b: Dictionary) -> Array[Image]:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	return [a.viewport.get_texture().get_image(),b.viewport.get_texture().get_image()]


func _save(image: Image, label: String) -> void:
	var path: String = output.path_join(label+".png")
	check(image != null and image.save_png(path) == OK,"actual Canvas screenshot saved: "+label)
	if image != null:
		screenshots[label] = {"file":label+".png","sha256":FileAccess.get_sha256(path),
			"pixel_sha256":_sha(_base(image).get_data())}


func _atlas(font: FontFile) -> Dictionary:
	var rid: RID = font.get_rids()[0]
	var glyph: int = text_server.font_get_glyph_index(rid,FONT_SIZE,"A".unicode_at(0),0)
	var size := Vector2i(FONT_SIZE,0)
	var texture: RID = text_server.font_get_glyph_texture_rid(rid,size,glyph)
	var index: int = text_server.font_get_glyph_texture_idx(rid,size,glyph)
	var cpu: Image = text_server.font_get_texture_image(rid,size,index)
	var gpu: Image = RenderingServer.texture_2d_get(texture)
	check(texture.is_valid() and cpu != null and gpu != null,"actual glyph atlas has CPU source and GPU readback")
	check(not cpu.has_mipmaps(),"dynamic mutable glyph atlas remains without mipmaps")
	check(gpu.has_mipmaps() == font.generate_mipmaps,"GPU texture metadata has the expected mipmap chain")
	check(_base(cpu).get_data() == _base(gpu).get_data(),"actual GPU mip0 matches its corresponding CPU glyph atlas")
	var alpha_varies: bool = false
	var bytes: PackedByteArray = _base(cpu).get_data()
	for offset: int in range(3,bytes.size(),4):
		if bytes[offset] != bytes[3]:
			alpha_varies = true
			break
	check(alpha_varies,"glyph atlas contains nontrivial visible glyph coverage")
	return {"font":rid,"texture":texture,"index":index,"source":cpu,
		"cpu_base":_base(cpu),"gpu_base":_base(gpu),"gpu_mipmaps":gpu.has_mipmaps()}


func _atlas_receipt(state: Dictionary) -> Dictionary:
	return {"font_rid":state.font.get_id(),"texture_rid":state.texture.get_id(),
		"source_object_id":state.source.get_instance_id(),"cpu_mipmaps":state.source.has_mipmaps(),
		"gpu_mipmaps":state.gpu_mipmaps,"extent":[state.cpu_base.get_width(),state.cpu_base.get_height()],
		"cpu_base_sha256":_sha(state.cpu_base.get_data()),"gpu_base_sha256":_sha(state.gpu_base.get_data())}


func _compare_pair(a: Dictionary, b: Dictionary, images: Array[Image], phase: String) -> void:
	check(images.size() == 2 and images[0] != null and images[1] != null,"both Canvas images exist")
	check(_base(images[0]).get_data() == _base(images[1]).get_data(),"exact nearest Canvas pixels: "+phase)
	var left: Dictionary = _atlas(a.font)
	var right: Dictionary = _atlas(b.font)
	check(left.font != right.font and left.texture != right.texture
		and left.source != right.source,"comparison uses distinct font, CPU atlas and GPU texture resources")
	check(left.cpu_base.get_data() == right.cpu_base.get_data(),"exact base glyph rasterization: "+phase)
	check(left.gpu_base.get_data() == right.gpu_base.get_data(),"exact GPU mip0 atlas bytes: "+phase)
	check(a.font.get_string_size(phase,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE)
		== b.font.get_string_size(phase,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE),
		"glyph metrics remain identical: "+phase)
	observations.append({"phase":phase,"left":_atlas_receipt(left),"right":_atlas_receipt(right),
		"left_mipmaps":a.font.generate_mipmaps,"right_mipmaps":b.font.generate_mipmaps,
		"left_pixels_sha256":_sha(_base(images[0]).get_data()),"right_pixels_sha256":_sha(_base(images[1]).get_data())})
	_save(images[0],"left-"+phase)
	_save(images[1],"right-"+phase)
	pairs_completed += 1


func _add_glyphs(font: FontFile, text: String) -> void:
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		check(font.has_char(code),"embedded font contains requested later glyph")
		font.render_range(0,Vector2i(FONT_SIZE,0),code,code)


func _queued_atlas(reference: FontFile, work: FontFile) -> void:
	_add_glyphs(reference,LATER_TEXT)
	var expected: Dictionary = _atlas(reference)
	var before: Dictionary = _atlas(work)
	var gate := QueueGate.new()
	gate.begin()
	_add_glyphs(work,LATER_TEXT)
	var rid: RID = work.get_rids()[0]
	var glyph: int = text_server.font_get_glyph_index(rid,FONT_SIZE,"A".unicode_at(0),0)
	var texture: RID = text_server.font_get_glyph_texture_rid(rid,Vector2i(FONT_SIZE,0),glyph)
	var source: Image = text_server.font_get_texture_image(rid,Vector2i(FONT_SIZE,0),before.index)
	var submitted: Image = _base(source)
	_add_glyphs(work,"~")
	var mutated: Image = _base(source)
	gate.end()
	check(not gate.expired and gate.owner,"bounded font upload gate held only the rendering owner")
	check(texture == before.texture,"later glyphs reuse the existing GPU atlas")
	check(submitted.get_data() == expected.cpu_base.get_data(),"queued upload starts with exact reference glyph bytes")
	check(mutated.get_data() != submitted.get_data(),"later glyph addition actually mutates the same CPU atlas")
	var actual: Image = _base(RenderingServer.texture_2d_get(texture))
	check(actual.get_data() == expected.gpu_base.get_data(),"queued mipmapped upload retained its immutable base glyph bytes")
	# Publish the later mutation, then compare it with an independent font that
	# received the same glyph sequence. No non-mipmap upload is used in this mode.
	_add_glyphs(reference,"~")
	var final_reference: Dictionary = _atlas(reference)
	var final_work: Dictionary = _atlas(work)
	check(final_reference.cpu_base.get_data() == final_work.cpu_base.get_data()
		and final_reference.gpu_base.get_data() == final_work.gpu_base.get_data(),
		"later dirty glyph publication preserves exact final atlas bytes")
	observations.append({"phase":"queued-ownership","render_gate_expired":gate.expired,
		"submitted_cpu_base_sha256":_sha(submitted.get_data()),"later_cpu_base_sha256":_sha(mutated.get_data()),
		"expected_gpu_base_sha256":_sha(expected.gpu_base.get_data()),"actual_gpu_base_sha256":_sha(actual.get_data()),
		"final_reference":_atlas_receipt(final_reference),"final_work":_atlas_receipt(final_work)})
	ownership_completed = true


func _reference_pixels(images: Array[Image], phase: String) -> void:
	var directory: String = OS.get_environment("CYBERSAND_FONT_MIPMAP_REFERENCE")
	var path: String = directory.path_join("result.json")
	check(not directory.is_empty() and FileAccess.file_exists(path),"separate mode has the retained Safe appearance reference")
	if directory.is_empty() or not FileAccess.file_exists(path): return
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(receipt is Dictionary,"Safe reference contains a valid receipt object")
	if not receipt is Dictionary: return
	var qualified: bool = receipt.get("schema","") == "default-font-mipmap-publication-v1" \
		and receipt.get("failures",-1) == 0 and receipt.get("separate",true) == false \
		and receipt.get("pairs_completed",-1) == 2 \
		and receipt.get("test_sha256","") == FileAccess.get_sha256(get_script().resource_path) \
		and receipt.get("font_data_sha256","") == font_data_hash
	check(qualified,"reference is the completed exact-test Safe run of the same embedded font")
	var records: Variant = receipt.get("screenshots",{})
	var both_phases: bool = records is Dictionary and records.has("right-initial") and records.has("right-later")
	check(both_phases,"Safe reference retains both required appearance phases")
	if not qualified or not both_phases: return
	var record: Dictionary = records.get("right-"+phase,{})
	var image_path: String = directory.path_join(str(record.get("file","")))
	check(FileAccess.get_sha256(image_path) == record.get("sha256", "missing"),"retained Safe PNG bytes match its receipt")
	var expected := Image.load_from_file(image_path)
	check(expected != null and _sha(_base(expected).get_data()) == record.get("pixel_sha256", "missing"),
		"retained Safe pixels match their recorded hash")
	check(expected != null and _base(expected).get_data() == _base(images[0]).get_data()
		and _base(expected).get_data() == _base(images[1]).get_data(),"separate Canvas pixels equal Safe mipmap-off/on pixels: "+phase)


func _run() -> void:
	output = OS.get_environment("CYBERSAND_FONT_MIPMAP_OUTPUT")
	check(not output.is_empty(),"explicit screenshot/receipt output directory supplied")
	if output.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	separate = not RenderingServer.is_on_render_thread()
	var requested: String = OS.get_environment("CYBERSAND_FONT_MIPMAP_THREAD")
	check(requested in ["safe","separate"] and separate == (requested == "separate"),"actual render ownership matches requested mode")
	check(DisplayServer.get_name() != "headless","font gate requires actual graphical rendering")
	check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0,
		"project uses the ordinary nearest Canvas filter")
	default_font = ThemeDB.fallback_font as FontFile
	check(default_font != null and ThemeDB.get_default_theme().default_font == default_font,
		"actual embedded fallback and default-theme font are the same FontFile")
	if default_font == null or DisplayServer.get_name() == "headless":
		quit(1)
		return
	text_server = TextServerManager.get_primary_interface()
	original_default_mipmaps = default_font.generate_mipmaps
	font_data_hash = _sha(default_font.data)
	# Before creating any test UI, protect incidental default-font draws in the
	# separate mode as well. The project file and production defaults are untouched.
	if separate: default_font.generate_mipmaps = true
	var left: FontFile = _font(separate)
	var right: FontFile = _font(true)
	var a: Dictionary = _view(left)
	var b: Dictionary = _view(right)
	var images: Array[Image] = await _draw_pair(a,b)
	_compare_pair(a,b,images,"initial")
	if separate:
		_reference_pixels(images,"initial")
		_queued_atlas(left,right)
	_change_text(a)
	_change_text(b)
	images = await _draw_pair(a,b)
	_compare_pair(a,b,images,"later")
	if separate: _reference_pixels(images,"later")
	check(pairs_completed == 2 and (not separate or ownership_completed),"all required font phases completed")
	var report := {"schema":"default-font-mipmap-publication-v1","godot":Engine.get_version_info(),
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),
		"driver":RenderingServer.get_current_rendering_driver_name(),"display":DisplayServer.get_name(),
		"separate":separate,"assertions":assertions,"failures":failures,"font_data_sha256":font_data_hash,
		"original_default_mipmaps":original_default_mipmaps,"actual_default_mipmaps":default_font.generate_mipmaps,
		"project_default_filter":ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"),
		"pairs_completed":pairs_completed,"ownership_completed":ownership_completed,
		"observations":observations,"screenshots":screenshots,
		"readback_scope":"GPU mip0 bytes only. GLES/ANGLE readback can regenerate mip levels on CPU; no claim to read actual lower GPU mip levels.",
		"scope":"Actual nearest Canvas/default-font appearance and bounded queued atlas ownership. Does not identify the original crashing RID, qualify all render-thread users, or establish performance/hardware acceptance."}
	var file := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	check(file != null,"font receipt opened")
	if file != null:
		report.assertions = assertions
		report.failures = failures
		file.store_string(JSON.stringify(report,"\t"))
	print("DEFAULT_FONT_MIPMAP_PUBLICATION: %d assertions, %d failures"%[assertions,failures])
	a.viewport.queue_free()
	b.viewport.queue_free()
	await process_frame
	quit(failures)
