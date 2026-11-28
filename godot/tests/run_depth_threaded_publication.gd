extends SceneTree

const Surface = preload("res://scripts/depth/depth_layer_surface.gd")

# Queue-only test helpers own no SceneTree objects. The intermediate readback
# is ordered between two actual Surface publications, so final-state equality
# cannot conceal mutation of the earlier queued Image.
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

class AtlasCapture extends RefCounted:
	var texture: Texture2D
	var rid: RID
	var image: Image
	var owner: bool = false
	var ready := Semaphore.new()
	func capture() -> void:
		owner = RenderingServer.is_on_render_thread()
		image = RenderingServer.texture_2d_get(rid)
		ready.post()
	func complete() -> bool:
		var deadline: int = Time.get_ticks_msec()+10000
		while Time.get_ticks_msec() < deadline:
			if ready.try_wait(): return true
			OS.delay_msec(1)
		return false

var checks: int = 0
var failures: int = 0
var separate: bool = false
var cases_completed: int = 0
var captures_completed: int = 0
var gates_completed: int = 0
var observations: Array[Dictionary] = []
var output: String

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("DEPTH_THREADED: "+message)

func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func _image(size: Vector2i, material: int, condition: int) -> Image:
	var result := Image.create(size.x,size.y,false,Image.FORMAT_RG8)
	result.fill(Color(float(material)/255.0,float(condition)/255.0,0,1))
	return result

func _packet(id: String, generation: int, serial: int, area: Rect2i, image: Image) -> Dictionary:
	return {"failed":false,"layer_id":id,"reset_generation":generation,"layer_tick":serial,
		"serial":serial,"channels":2,"full_refresh":area == Rect2i(Vector2i.ZERO,Surface.NATIVE_SIZE),
		"rectangles":PackedInt32Array([area.position.x,area.position.y,area.size.x,area.size.y,0,area.size.x*2]),
		"cells":image.get_data()}

func _surface(id: String, frozen: bool) -> CyberDepthLayerSurface:
	var result: CyberDepthLayerSurface = Surface.new()
	# Configure outside the gate: construction includes a legitimate LUT GPU
	# readback. The test holds only publication, not unrelated synchronization.
	check(result.configure(id,frozen,Vector2i(64,64)),"actual depth surface configured")
	result._material.set_shader_parameter("presentation_time_override",1.25)
	root.add_child(result)
	check(result.cell_texture.get_image().get_data() == result.cell_image.get_data(),"initial RG8 atlas is exact")
	return result

func _capture(surface: CyberDepthLayerSurface) -> AtlasCapture:
	var result := AtlasCapture.new()
	result.texture = surface.cell_texture
	result.rid = result.texture.get_rid()
	RenderingServer.call_on_render_thread(result.capture)
	return result

func _burst(surface: CyberDepthLayerSurface, first: Dictionary, second: Dictionary,
		expected_first: Image, expected_final: Image, label: String) -> void:
	var source_id: int = surface.cell_image.get_instance_id()
	var texture_id: RID = surface.cell_texture.get_rid()
	var gate: QueueGate
	if separate:
		gate = QueueGate.new()
		gate.begin()
	check(surface.apply_packet(first),label+" first actual packet accepted")
	var capture: AtlasCapture = _capture(surface)
	check(surface.apply_packet(second),label+" second actual packet accepted")
	if gate != null:
		gate.end()
		check(gate.owner and not gate.expired,label+" queue gate completed without watchdog or scene access")
		gates_completed += 1
	check(capture.complete(),label+" intermediate GPU readback completed")
	check(capture.owner and capture.image != null,label+" intermediate readback ran on rendering owner")
	if capture.image == null: return
	check(capture.image.get_format() == Image.FORMAT_RG8 and capture.image.get_size() == Surface.NATIVE_SIZE,
		label+" intermediate GPU format and extent remain exact")
	check(capture.image.get_data() == expected_first.get_data(),label+" earlier queued atlas retained its exact bytes")
	check(surface.cell_image.get_data() == expected_final.get_data(),label+" CPU atlas contains the later publication")
	var final: Image = surface.cell_texture.get_image()
	check(final.get_data() == expected_final.get_data(),label+" final GPU atlas contains the later publication")
	check(surface.cell_image.get_instance_id() == source_id and surface.cell_texture.get_rid() == texture_id,
		label+" actual producer retains its mutable CPU atlas and GPU resource")
	observations.append({"phase":label,"separate":separate,"gate_expired":gate.expired if gate != null else false,
		"intermediate_sha256":_sha(capture.image.get_data()),"expected_intermediate_sha256":_sha(expected_first.get_data()),
		"final_sha256":_sha(final.get_data()),"expected_final_sha256":_sha(expected_final.get_data()),
		"source_object_id":source_id,"texture_rid":texture_id.get_id(),"diagnostics":surface.diagnostics()})
	captures_completed += 1

func _case(frozen: bool) -> void:
	var id: String = "background" if frozen else "play"
	var work: CyberDepthLayerSurface = _surface(id,frozen)
	var reference: CyberDepthLayerSurface = _surface(id,frozen)
	var whole := Rect2i(Vector2i.ZERO,Surface.NATIVE_SIZE)
	var a: Image = _image(Surface.NATIVE_SIZE,1,17)
	var patch: Image = _image(Vector2i(6,8),3,225)
	var area := Rect2i(17,19,6,8)
	var b: Image = a.duplicate()
	b.blit_rect(patch,Rect2i(Vector2i.ZERO,patch.get_size()),area.position)
	_burst(work,_packet(id,1,1,whole,a),_packet(id,1,2,area,patch),a,b,id+" full-partial")
	var stale: Dictionary = _packet(id,0,99,area,patch)
	check(not work.apply_packet(stale),"older generation is still rejected")
	check(work.cell_image.get_data() == b.get_data() and work.cell_texture.get_image().get_data() == b.get_data(),
		"rejected packet preserves CPU and GPU bytes")
	var c: Image = _image(Surface.NATIVE_SIZE,81,255)
	var later: Image = _image(Vector2i(17,21),2,0)
	var later_area := Rect2i(31,33,17,21)
	var d: Image = c.duplicate()
	d.blit_rect(later,Rect2i(Vector2i.ZERO,later.get_size()),later_area.position)
	_burst(work,_packet(id,2,0,whole,c),_packet(id,2,1,later_area,later),c,d,id+" reset-partial")
	check(work.reset_generation == 2 and work.last_serial == 1 and work.layer_tick == 1,
		"generation and serial acknowledgements retain actual accepted identity")
	check(work.upload_count == 4 and work.accepted_packets == 4 and work.rejected_packets == 1
		and work.uploaded_bytes == 4*Surface.MAX_PAYLOAD_BYTES,"existing upload and packet accounting remains exact")
	check(work.bake_requests == (4 if frozen else 0),"static and dynamic surface bake semantics remain intact")
	check(reference.apply_packet(_packet(id,2,1,whole,d)),"single-publication appearance reference accepted")
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var actual: Image = work.get_texture().get_image()
	var expected: Image = reference.get_texture().get_image()
	check(actual.get_size() == Vector2i(64,64) and actual.get_used_rect().has_area(),"actual depth Canvas pixels are visible")
	check(actual.get_data() == expected.get_data(),"queued and single-publication depth appearance is byte-exact")
	var path: String = output.get_base_dir().path_join(id+".png")
	check(actual.save_png(path) == OK,"depth screenshot saved")
	observations.append({"phase":id+" appearance","actual_pixel_sha256":_sha(actual.get_data()),
		"reference_pixel_sha256":_sha(expected.get_data()),"png_file":path.get_file(),"png_sha256":FileAccess.get_sha256(path)})
	work.queue_free()
	reference.queue_free()
	await process_frame
	cases_completed += 1

func _run() -> void:
	output = OS.get_environment("CYBERSAND_DEPTH_QUEUE_OUTPUT")
	separate = not RenderingServer.is_on_render_thread()
	var requested: String = OS.get_environment("CYBERSAND_DEPTH_QUEUE_THREAD")
	check(not output.is_empty(),"explicit evidence output supplied")
	check(requested in ["safe","separate"] and separate == (requested == "separate"),"actual render ownership matches requested mode")
	check(DisplayServer.get_name() != "headless","actual graphical backend is required")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	await _case(false)
	await _case(true)
	check(cases_completed == 2 and captures_completed == 4 and gates_completed == (4 if separate else 0),
		"all actual dynamic/static queue cases completed")
	var report := {"schema":"depth-threaded-publication-v1","source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"test_sha256":FileAccess.get_sha256(get_script().resource_path),
		"surface_sha256":FileAccess.get_sha256("res://scripts/depth/depth_layer_surface.gd"),
		"godot":Engine.get_version_info(),"display":DisplayServer.get_name(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"separate":separate,"assertions":checks,"failures":failures,"cases_completed":cases_completed,
		"captures_completed":captures_completed,"gates_completed":gates_completed,"observations":observations,
		"scope":"Actual depth producer RG8 queued ownership and exact same-frame Canvas appearance only; no throughput, general thread-safety or hardware acceptance claim."}
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file != null,"depth receipt opened")
	if file != null:
		report.assertions = checks
		report.failures = failures
		file.store_string(JSON.stringify(report,"\t"))
	print("DEPTH_THREADED_PUBLICATION: %d assertions, %d failures"%[checks,failures])
	quit(failures)
