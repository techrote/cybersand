extends SceneTree

## First-read GPU history, immutable queued Images and finite-owner checks for
## the three-slot Full experiment. No native/Rapier result is inferred here.
const Publisher = preload("res://scripts/full_image_ring_publisher.gd")
const Context = preload("res://tests/palette_qualification_context.gd")

var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var output: String = ""


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


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt="): output = argument.trim_prefix("--receipt=")
	_run.call_deferred()


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("FULL_IMAGE_RING: "+detail)


func _source(size: Vector2i, channels: int, value: int) -> Image:
	var result := Image.create(size.x,size.y,false,Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8)
	result.fill(Color8(value,197-value,0))
	result.set_pixel(0,0,Color8(value+1,17,0))
	result.set_pixel(size.x-1,size.y-1,Color8(127,value+2,0))
	return result


func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _histories(owner: Publisher, current: Image, previous: Image, label: String) -> Dictionary:
	# The first two actual reads are the oracle. No retry, draw or settling await.
	var gpu_current: Image = owner.current.get_image()
	var gpu_previous: Image = owner.previous.get_image()
	var current_ok: bool = gpu_current != null and gpu_current.get_size() == current.get_size() \
		and gpu_current.get_format() == current.get_format() and gpu_current.get_data() == current.get_data()
	var previous_ok: bool = gpu_previous != null and gpu_previous.get_size() == previous.get_size() \
		and gpu_previous.get_format() == previous.get_format() and gpu_previous.get_data() == previous.get_data()
	check(current_ok,label+" exact first current GPU read")
	check(previous_ok,label+" exact first previous GPU read")
	return {"current_verified":current_ok,"previous_verified":previous_ok,
		"current_sha256":_hash(gpu_current.get_data()) if gpu_current != null else "",
		"previous_sha256":_hash(gpu_previous.get_data()) if gpu_previous != null else "",
		"expected_current_sha256":_hash(current.get_data()),"expected_previous_sha256":_hash(previous.get_data())}


func _refusals(owner: Publisher, source: Image, label: String) -> void:
	var pair: Array[RID] = [owner.current.get_rid(),owner.previous.get_rid()]
	var status: Dictionary = owner.last_update.duplicate(true)
	var wrong_size := Image.create(source.get_width()+1,source.get_height(),false,source.get_format())
	var wrong_format := Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGB8)
	check(not owner.publish(null) and not owner.publish(wrong_size) and not owner.publish(wrong_format),
		label+" rejects null, shape and format before rotation")
	var mipmap: Image = source.duplicate()
	mipmap.generate_mipmaps()
	check(not owner.publish(mipmap),label+" rejects mipmapped source")
	check(pair == [owner.current.get_rid(),owner.previous.get_rid()] and owner.last_update == status,
		label+" refused source changes no pair or receipt")
	var retained: ImageTexture = owner.current
	owner.current = ImageTexture.create_from_image(source)
	check(not owner.publish(source),label+" refuses substituted public texture owner")
	owner.current = retained
	check(Publisher.create_pair(source,wrong_format) == null,label+" refuses mismatched initialization")


func _case(size: Vector2i, channels: int) -> void:
	var label: String = "%dx%d/R%d" % [size.x,size.y,channels*8]
	var source: Image = _source(size,channels,5)
	var preceding: Image = _source(size,channels,9)
	var owner: Publisher = Publisher.create_pair(source,preceding)
	check(owner != null,label+" owner initializes")
	if owner == null: return
	var identities: PackedInt64Array = owner.resource_identity()
	var resident: int = 3*size.x*size.y*channels
	check(identities.size() == 3 and identities[0] != identities[1] and identities[0] != identities[2]
		and identities[1] != identities[2] and owner.allocated_logical_gpu_bytes() == resident,
		label+" exactly three independent resources and declared logical bytes")
	_histories(owner,source,preceding,label+" initialization")
	_refusals(owner,source,label)
	for index: int in range(10):
		preceding = source
		source = _source(size,channels,20+index)
		var prior_current: RID = owner.current.get_rid()
		var prior_previous: RID = owner.previous.get_rid()
		check(owner.publish(source),label+" publication%d admitted" % index)
		check(owner.previous.get_rid() == prior_current and owner.current.get_rid() != prior_current
			and owner.current.get_rid() != prior_previous,label+" publication%d updates only spare" % index)
		check(owner.resource_identity() == identities and owner.allocated_logical_gpu_bytes() == resident,
			label+" publication%d bounded owner set" % index)
		_histories(owner,source,preceding,label+" publication%d" % index)
	# Prepare enough immutable caller inputs to wrap every slot repeatedly.
	var sources: Array[Image] = []
	for index: int in range(17): sources.append(_source(size,channels,40+index))
	var expected_current: Image = sources[-1].duplicate()
	var expected_previous: Image = sources[-2].duplicate()
	var separate: bool = not RenderingServer.is_on_render_thread()
	var gate: QueueGate
	if separate:
		gate = QueueGate.new()
		gate.begin()
	for item: Image in sources:
		check(owner.publish(item),label+" queued publication admitted")
		item.fill(Color.BLACK)
	sources.clear()
	if gate != null:
		gate.end()
		check(gate.was_render_owner and not gate.expired,label+" actual bounded render queue gate")
	var gpu: Dictionary = _histories(owner,expected_current,expected_previous,label+" poisoned queued burst")
	check(owner.resource_identity() == identities and owner.allocated_logical_gpu_bytes() == resident,
		label+" queued burst preserves three owned resources")
	observations.append({"extent":[size.x,size.y],"channels":channels,"logical_gpu_bytes":resident,
		"resource_count":identities.size(),"queued_publications":17,"separate":separate,
		"render_gate_completed":gate != null and not gate.expired,"histories":gpu})


func _run() -> void:
	check(DisplayServer.get_name() != "headless","a real graphical backend is required")
	if failures.is_empty():
		for channels: int in [1,2]:
			for size: Vector2i in [Vector2i(33,19),Vector2i(512,512),Vector2i(2048,1024)]:
				_case(size,channels)
				await process_frame
	var result := {"schema":"pubpres-full-image-ring-correctness-v1","complete":failures.is_empty(),
		"checks":checks,"failures":failures,"observations":observations,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"pid":OS.get_process_id(),
		"engine":Engine.get_version_info(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"context":Context.identity(get_script().resource_path),
		"publisher_sha256":FileAccess.get_sha256("res://scripts/full_image_ring_publisher.gd")}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null:
			check(false,"could not write receipt")
		else:
			file.store_string(JSON.stringify(result)+"\n")
			file.close()
	print("FULL_IMAGE_RING_RESULT ",JSON.stringify(result))
	quit(int(not failures.is_empty()))
