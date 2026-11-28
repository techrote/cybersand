extends "res://tests/test_material_tile_publication.gd"

# Deliberately retain RenderingServer's queue while Main publishes several
# exact images. This tests ownership, not throughput: no production fence or
# GPU readback is added, and the watchdog only releases a broken test gate.
class QueueGate extends RefCounted:
	var entered := Semaphore.new()
	var resume := Semaphore.new()
	var cancel := Semaphore.new()
	var watcher := Thread.new()
	var expired: bool = false
	var was_render_owner: bool = false
	func block_queue() -> void:
		was_render_owner = RenderingServer.is_on_render_thread()
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

var separate: bool = false
var gates_completed: int = 0
var cases_completed: int = 0


func _begin_gate() -> QueueGate:
	if not separate: return null
	var gate := QueueGate.new()
	gate.begin()
	return gate


func _end_gate(gate: QueueGate, label: String) -> void:
	if gate == null: return
	gate.end()
	check(not gate.expired, label+" publication did not synchronize the blocked render queue")
	check(gate.was_render_owner, label+" gate executed on the rendering owner")
	gates_completed += 1


func _queued_patch(host: Control, area: Rect2i, value: int, condition: int) -> void:
	var patch := Image.create(area.size.x,area.size.y,false,host.render_image_format)
	patch.fill(Color(float(value)/255.0,float(condition)/255.0,0,1))
	check(host.upload_texture_patches(PackedInt32Array([area.position.x,area.position.y,
		area.size.x,area.size.y,0,area.size.x*host.render_channels]),patch.get_data(),
		host.last_uploaded_revision+1,host.render_channels),"queued sparse publication accepted")


func _history_receipt(host: Control, expected: PackedByteArray, preceding: PackedByteArray, label: String) -> void:
	_check_gpu(host,expected,preceding,label)
	observations.append({"case":label,"current_sha256":_sha(host.texture.get_image().get_data()),
		"previous_sha256":_sha(host.previous_texture.get_image().get_data()),
		"expected_current_sha256":_sha(expected),"expected_previous_sha256":_sha(preceding),
		"publication":host.material_publication_status()})
	cases_completed += 1


func _queued_full(channels: int) -> void:
	var size := Vector2i(129,71)
	var host: Control = _host(size,channels,"full",1)
	_check_gpu(host,host.image.get_data(),host.image.get_data(),"initial full")
	var a := _pattern(size,channels,41)
	var b := _pattern(size,channels,87)
	var gate: QueueGate = _begin_gate()
	host.upload_texture(a,1)
	host.upload_texture(b,2)
	_end_gate(gate,"full update burst")
	_history_receipt(host,b,a,"full-update-burst-R%d"%channels)
	_release(host)
	gate = _begin_gate()
	host = _host(size,channels,"full",11)
	var initial: PackedByteArray = host.image.get_data()
	host.upload_texture(a,1)
	_end_gate(gate,"full initialization and immediate update")
	_history_receipt(host,a,initial,"full-create-update-R%d"%channels)
	_release(host)


func _queued_blit_and_fallback(channels: int) -> void:
	var host: Control = _host(Vector2i(317,259),channels,"blit",3)
	check(host.texture is Publisher.MaterialPlane,"queue test uses actual drawable backend")
	_check_gpu(host,host.image.get_data(),host.image.get_data(),"initial blit")
	var gate: QueueGate = _begin_gate()
	_queued_patch(host,Rect2i(63,63,3,2),6,255)
	_queued_patch(host,Rect2i(316,258,1,1),17,93)
	var preceding: PackedByteArray = host.image.get_data()
	_queued_patch(host,Rect2i(210,149,2,3),29,1)
	var expected: PackedByteArray = host.image.get_data()
	_end_gate(gate,"blit sparse burst")
	_history_receipt(host,expected,preceding,"blit-sparse-burst-R%d"%channels)
	# Force the real structural fallback without submitting any invalid backend
	# call. Its newly created current image must outlive the next CPU mutation.
	gate = _begin_gate()
	host._material_blit_publisher.tile_side -= 1
	var a := _pattern(host.world_extent,channels,31)
	var b := _pattern(host.world_extent,channels,71)
	host.upload_texture(a,host.last_uploaded_revision+1)
	check(host.texture is ImageTexture,"queued structural fallback selected full pair")
	host.upload_texture(b,host.last_uploaded_revision+1)
	_end_gate(gate,"fallback and immediate full update")
	_history_receipt(host,b,a,"fallback-update-burst-R%d"%channels)
	# Resource construction is allowed to synchronize the rendering owner.
	# Complete that boundary before holding the queue; publications and the
	# following full-image mode switch must still retain independent bytes.
	check(host.set_material_publication_mode("blit"),"live mode switch selected blit")
	gate = _begin_gate()
	_queued_patch(host,Rect2i(0,0,2,1),8,55)
	expected = host.image.get_data()
	check(host.set_material_publication_mode("full"),"queued live mode switch selected full")
	_queued_patch(host,Rect2i(129,70,1,1),4,111)
	preceding = expected
	expected = host.image.get_data()
	_end_gate(gate,"queued mode-switch histories")
	_history_receipt(host,expected,preceding,"mode-switch-burst-R%d"%channels)
	gate = _begin_gate()
	host.world_extent = Vector2i(73,65)
	host.image = Image.create_from_data(73,65,false,host.render_image_format,
		_pattern(host.world_extent,channels,91))
	host.create_render_textures()
	preceding = host.image.get_data()
	_queued_patch(host,Rect2i(72,64,1,1),6,249)
	expected = host.image.get_data()
	_end_gate(gate,"queued World replacement")
	_history_receipt(host,expected,preceding,"world-replacement-burst-R%d"%channels)
	_release(host)


func _queued_direct_sparse(channels: int) -> void:
	# Exercise the sparse component's actual queued resources independently of
	# Main's chosen backend; this case does not change that selection.
	var size := Vector2i(317,259)
	var format: Image.Format = Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8
	var initial := Image.create_from_data(size.x,size.y,false,format,_pattern(size,channels,5))
	var owner: Publisher = Publisher.create_pair(initial,initial)
	check(owner != null,"queued direct sparse component initializes")
	if owner == null: return
	check(owner.current.get_image().get_data() == initial.get_data(),"direct sparse initial GPU history is exact")
	var a: Image = initial.duplicate()
	a.set_pixel(63,63,Color8(6,255,0))
	var b: Image = a.duplicate()
	b.set_pixel(316,258,Color8(17,93,0))
	var expected_a: PackedByteArray = a.get_data()
	var expected_b: PackedByteArray = b.get_data()
	var gate: QueueGate = _begin_gate()
	check(owner.publish(a,[Rect2i(63,63,1,1)]),"first queued direct sparse update accepted")
	check(owner.publish(b,[Rect2i(316,258,1,1)]),"second queued direct sparse update accepted")
	check(owner.last_update.staging_slot >= 0 and owner.last_update.submitted_bytes > 0,
		"direct sparse queue case submitted actual staging work")
	a.fill(Color.BLACK)
	b.fill(Color.BLACK)
	a = null
	b = null
	var current: Publisher.MaterialPlane = owner.current
	var previous: Publisher.MaterialPlane = owner.previous
	owner = null
	_end_gate(gate,"direct sparse source mutation and publisher retirement")
	check(current.get_image().get_data() == expected_b and previous.get_image().get_data() == expected_a,
		"both complete sparse histories survive queued source mutation and staging owner retirement")
	check(not current.update(initial) and not previous.update(initial),"retired direct sparse owner refuses future updates")
	observations.append({"case":"direct-sparse-retirement-R%d"%channels,"scope":"component, not Main effective backend",
		"current_sha256":_sha(current.get_image().get_data()),"previous_sha256":_sha(previous.get_image().get_data())})
	cases_completed += 1


func _queued_owner_retirement(channels: int) -> void:
	var size := Vector2i(129,71)
	var format: Image.Format = Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8
	var source := Image.create_from_data(size.x,size.y,false,format,_pattern(size,channels,9))
	var owner: Publisher = Publisher.create_pair(source,source)
	check(owner != null,"queued manual owner exists")
	if owner == null: return
	var retained: Publisher.MaterialPlane = owner.current
	check(retained.get_image().get_data() == source.get_data(),"manual initial GPU exact")
	var expected := _pattern(size,channels,29)
	source.set_data(size.x,size.y,false,format,expected)
	var gate: QueueGate = _begin_gate()
	check(retained.update(source),"queued manual update accepted")
	source.fill(Color(0,0,0,1))
	owner = null
	_end_gate(gate,"manual source mutation and owner retirement")
	check(retained.get_image().get_data() == expected,"retained wrapper owns exact queued GPU result after owner retirement")
	check(not retained.update(source),"retired weak owner refuses future update")
	observations.append({"case":"retired-manual-R%d"%channels,
		"current_sha256":_sha(retained.get_image().get_data()),"expected_current_sha256":_sha(expected)})
	cases_completed += 1


func _run() -> void:
	OS.set_environment("CYBERSAND_DIAG_RENDER_CADENCE","repaired")
	separate = not RenderingServer.is_on_render_thread()
	check(DisplayServer.get_name() != "headless","queue test requires a real graphical backend")
	var expected_thread: String = OS.get_environment("CYBERSAND_MATERIAL_QUEUE_THREAD")
	check(expected_thread in ["safe","separate"] and separate == (expected_thread == "separate"),
		"actual rendering ownership matches the requested test mode")
	if DisplayServer.get_name() != "headless":
		for channels: int in [1,2]:
			_queued_full(channels)
			_queued_blit_and_fallback(channels)
			_queued_owner_retirement(channels)
			_queued_direct_sparse(channels)
	check(cases_completed == 16,"all bounded queue cases completed")
	check(gates_completed == (16 if separate else 0),"all requested render gates completed")
	var report := {"godot":Engine.get_version_info(),"display":DisplayServer.get_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"platform":OS.get_name(),"main_policy":"",
		"separate":separate,
		"assertions":assertions,"failures":failures,"gates_completed":gates_completed,
		"cases_completed":cases_completed,"observations":observations,
		"scope":"Deterministic queued resource ownership and actual GPU histories; no throughput or physical GPU claim."}
	var output: String = OS.get_environment("CYBERSAND_MATERIAL_QUEUE_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
		check(file != null,"queue receipt opened")
		if file != null:
			report.assertions = assertions
			report.failures = failures
			file.store_string(JSON.stringify(report,"\t"))
	print("MATERIAL_THREADED_PUBLICATION: %d assertions, %d failures"%[assertions,failures])
	quit(failures)
