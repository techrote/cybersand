extends SceneTree

const Publisher = preload("res://scripts/blit_material_publisher.gd")
const Main = preload("res://scripts/main.gd")
const Palette = preload("res://scripts/palette_shader_selector.gd")
const Consumer = preload("res://tests/support/render_copy_consumer.gd")
const Trace = preload("res://tests/support/render_copy_trace.gd")
var assertions: int = 0
var failures: int = 0
var observations: Array[Dictionary] = []

class RejectCommitPublisher extends Publisher:
	var observer: WeakRef
	var rejection: Dictionary = {}
	func commit_publication(prepared: Publisher.PreparedPublication) -> bool:
		var host: Control = observer.get_ref()
		rejection = {"current_certificate":host._presentation_current_bytes,
			"previous_certificate":host._presentation_previous_bytes,
			"current_content_id":host._presentation_current_content_id,
			"previous_content_id":host._presentation_previous_content_id,
			"revision":host.last_uploaded_revision,"current":current.get_image().get_data(),
			"previous":previous.get_image().get_data(),"prepared":prepared._destination.get_image().get_data()}
		return false

func _init() -> void: _run.call_deferred()

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("MATERIAL_HISTORY_TRANSACTION: "+label)

func _pattern(size: Vector2i, channels: int, seed_value: int) -> Image:
	var data := PackedByteArray()
	data.resize(size.x*size.y*channels)
	for index: int in range(data.size()): data[index] = (index*23+seed_value)%256
	return Image.create_from_data(size.x,size.y,false,Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8,data)

func _sha(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func _pair(publisher: Publisher, current: Image, previous: Image, label: String) -> void:
	check(publisher.current.get_image().get_data() == current.get_data(),label+" current GPU exact")
	check(publisher.previous.get_image().get_data() == previous.get_data(),label+" previous GPU exact")

func _token_contract(channels: int) -> void:
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS","3")
	var size := Vector2i(317,259)
	var a: Image = _pattern(size,channels,11)
	var b: Image = _pattern(size,channels,99)
	var publisher: Publisher = Publisher.create_pair(a,b)
	check(publisher != null and publisher.history_targets == 3 and publisher.spare != null,
		"three-target factory preserves two visible histories and one initialized spare")
	if publisher == null: return
	_pair(publisher,a,b,"initial distinct histories")
	check(publisher.spare.get_image().get_data() == a.get_data(),"spare starts with exact current bytes")
	var resources: Array[int] = publisher.resource_identity()
	var roles: Array[RID] = [publisher.current.get_rid(),publisher.previous.get_rid(),publisher.spare.get_rid()]
	var next: Image = a.duplicate()
	next.set_pixel(1,1,Color(251.0/255.0,7.0/255.0,0,1))
	var areas: Array[Rect2i] = [Rect2i(1,1,1,1)]
	var prepared: Publisher.PreparedPublication = publisher.prepare_publication(next,areas)
	check(prepared != null, "first sparse preparation succeeds")
	if prepared == null: return
	check(publisher.current.get_rid() == roles[0] and publisher.previous.get_rid() == roles[1]
		and publisher.spare.get_rid() == roles[2],"preparation does not expose new logical roles")
	_pair(publisher,a,b,"prepared visible histories")
	check(publisher.spare.get_image().get_data() == next.get_data() and publisher.last_update.updated_tiles == 1,
		"initialized spare accepts only the first changed tile")
	check(publisher.prepare_publication(next,areas) == null and not publisher.current.update(next),
		"one outstanding token bounds preparation and excludes direct mutation")
	var foreign: Publisher = Publisher.create_pair(a,b)
	check(not foreign.commit_publication(prepared),"foreign owner refuses a prepared token")
	var forged := Publisher.PreparedPublication.new()
	check(not publisher.commit_publication(forged),"unissued token cannot commit roles")
	var original_sequence: int = prepared._sequence
	prepared._sequence += 1
	check(not publisher.commit_publication(prepared),"modified token generation is refused")
	prepared._sequence = original_sequence
	check(publisher.commit_publication(prepared),"valid token commits exactly once")
	check(not publisher.commit_publication(prepared),"replayed committed token is refused")
	check(publisher.current.get_rid() == roles[2] and publisher.previous.get_rid() == roles[0]
		and publisher.spare.get_rid() == roles[1],"commit rotates current, previous and spare coherently")
	_pair(publisher,next,a,"first committed histories")
	var source: Image = next
	var target_counts: Dictionary = {}
	var edits: Array[Rect2i] = [Rect2i(130,70,1,1),Rect2i(316,258,1,1),Rect2i(1,1,1,1),
		Rect2i(63,63,2,2),Rect2i(130,70,1,1),Rect2i(256,192,2,2),Rect2i(316,258,1,1)]
	for turn: int in range(edits.size()):
		var old: Image = source
		source = source.duplicate()
		var erased: bool = turn in [2,4,6]
		source.fill_rect(edits[turn],Color(0 if erased else float(220+turn)/255.0,
			0 if erased else float(100+turn)/255.0,0,1))
		var rectangles: Array[Rect2i] = [edits[turn]]
		var transaction: Publisher.PreparedPublication = publisher.prepare_publication(source,rectangles)
		check(transaction != null and not publisher.commit_publication(prepared),
			"stale token cannot replace a newer prepared publication")
		check(publisher.commit_publication(transaction),"disjoint/erasing publication commits")
		_pair(publisher,source,old,"three-transition coverage "+str(turn))
		var rid: int = publisher.current.get_rid().get_id()
		target_counts[rid] = int(target_counts.get(rid,0))+1
		check(publisher.resource_identity() == resources,"history ring stays bounded across all target reuses")
		observations.append({"label":"three-transition coverage","channels":channels,"turn":turn,
			"current_sha256":_sha(publisher.current.get_image().get_data()),
			"previous_sha256":_sha(publisher.previous.get_image().get_data()),
			"publication":publisher.last_update.duplicate()})
	check(target_counts.size() == 3,"every physical history target was reused")
	# Multiple ordered publications execute without a frame or GPU readback
	# between them. Only the last two complete sources may become visible.
	var preceding: Image
	for turn: int in range(8):
		preceding = source
		source = source.duplicate()
		source.set_pixel(200+turn,200,Color(float(180+turn)/255.0,0.5,0,1))
		var rectangles: Array[Rect2i] = [Rect2i(200+turn,200,1,1)]
		check(publisher.publish(source,rectangles),"several publications before a draw remain ordered")
	_pair(publisher,source,preceding,"undrawn burst histories")
	for turn: int in range(3): check(publisher.publish(source,[]),"identical history reconciliation accepted")
	var cursor: int = publisher.full_staging.next_slot
	var old_current: RID = publisher.current.get_rid()
	var old_spare: RID = publisher.spare.get_rid()
	check(publisher.publish(source,[]),"byte-identical transition commits")
	check(publisher.last_update.submitted_bytes == 0 and publisher.full_staging.next_slot == cursor
		and publisher.current.get_rid() == old_spare and publisher.previous.get_rid() == old_current,
		"no-op rotates only logical history roles without consuming a staging resource")
	_pair(publisher,source,source,"byte-identical visible histories")
	var spare_extent: Vector2i = publisher.spare.extent
	publisher.spare.extent += Vector2i.ONE
	check(publisher.prepare_publication(source,[]) == null,"invalid spare metadata refused before preparation")
	publisher.spare.extent = spare_extent
	var spare_drawable: DrawableTexture2D = publisher.spare.drawable
	publisher.spare.drawable = publisher.current.drawable
	check(publisher.prepare_publication(source,[]) == null,"foreign/aliased spare resource refused")
	publisher.spare.drawable = spare_drawable
	_pair(publisher,source,source,"rejected spare leaves visible histories unchanged")
	var checked_token: Publisher.PreparedPublication = publisher.prepare_publication(source,[])
	var owned_id: int = publisher.spare.owned_object_id
	var visible_rid: RID = publisher.current.get_rid()
	publisher.spare.owned_object_id = 0
	check(not publisher.commit_publication(checked_token) and publisher.current.get_rid() == visible_rid,
		"post-prepare resource rejection cannot advance visible roles")
	publisher.spare.owned_object_id = owned_id
	check(publisher.commit_publication(checked_token),"restored exact prepared resource can commit its original token")
	# Retain a token after owner retirement: its plane references must not
	# create a publisher cycle, while actual GPU storage remains readable.
	var retired_token: Publisher.PreparedPublication = publisher.prepare_publication(source,[])
	var owner: WeakRef = weakref(publisher)
	var retained: Texture2D = publisher.current
	publisher = null
	check(owner.get_ref() == null,"outstanding token and retained wrapper do not keep publisher alive")
	check(retired_token != null and retained.get_image().get_data() == source.get_data()
		and not retained.update(source),"retired owner leaves readable GPU resources and refuses updates")

func _retained_spare_contract(channels: int) -> void:
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS","3")
	var size := Vector2i(317,259)
	var initial: Image = _pattern(size,channels,11)
	var publisher: Publisher = Publisher.create_pair(initial,initial)
	check(publisher != null,"retained-spare fixture initializes")
	if publisher == null: return
	var retained: Texture2D = publisher.current
	var source: Image = initial
	var preceding: Image = initial
	for turn: int in range(2):
		preceding = source
		source = source.duplicate()
		source.set_pixel(2+turn,2,Color(float(230+turn)/255.0,0.25,0,1))
		var areas: Array[Rect2i] = [Rect2i(2+turn,2,1,1)]
		check(publisher.publish(source,areas),"retained wrapper advances from current through previous to spare")
	check(retained == publisher.spare,"retained public wrapper is now the live spare")
	var current_rid: RID = publisher.current.get_rid()
	var previous_rid: RID = publisher.previous.get_rid()
	var manual: Image = retained.get_image()
	manual.set_pixel(316,258,Color(253.0/255.0,0.5,0,1))
	check(retained.update(manual),"retained spare accepts a compatibility update while its owner is live")
	check(publisher.current.get_rid() == current_rid and publisher.previous.get_rid() == previous_rid,
		"updating a spare never changes visible role identities")
	_pair(publisher,source,preceding,"manual spare preserves both visible images")
	check(retained.get_image().get_data() == manual.get_data(),"manual spare exposes its actual updated GPU bytes")
	for turn: int in range(4):
		preceding = source
		source = source.duplicate()
		source.set_pixel(10+turn,2,Color(float(240+turn)/255.0,0.75,0,1))
		var areas: Array[Rect2i] = [Rect2i(10+turn,2,1,1)]
		check(publisher.publish(source,areas),"sparse publication after manual spare write succeeds")
		_pair(publisher,source,preceding,"manual spare is repaired across complete recycling")
	observations.append({"label":"retained spare direct update","channels":channels,
		"current_sha256":_sha(publisher.current.get_image().get_data()),
		"previous_sha256":_sha(publisher.previous.get_image().get_data())})

func _host(script: Script = Main) -> Control:
	var host: Control = script.new()
	if script == Consumer: host.trace = Trace.new()
	host.world_extent = Vector2i(129,71)
	host.render_channels = 2
	host.render_image_format = Image.FORMAT_RG8
	host.image = _pattern(host.world_extent,2,11)
	host.world_view = TextureRect.new()
	host.world_shader = ShaderMaterial.new()
	host.world_shader.shader = Palette.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	host.world_view.material = host.world_shader
	host.shared_workbench = Control.new()
	host._material_publication_mode = "blit"
	host.create_render_textures()
	host._bind_material_texture_consumers()
	return host

func _post_prepare_fallback(targets: int) -> void:
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS",str(targets))
	var host: Control = _host()
	var a: PackedByteArray = host.image.get_data()
	var b: Image = _pattern(host.world_extent,2,99)
	check(host.upload_texture_patches(host._full_material_rectangle(),b.get_data(),1,2),
		"Main creates distinct A/B histories before rejection")
	var current_id: int = host._presentation_current_content_id
	var previous_id: int = host._presentation_previous_content_id
	var reject := RejectCommitPublisher.new()
	check(reject._setup(b,Image.create_from_data(host.world_extent.x,host.world_extent.y,false,Image.FORMAT_RG8,a)),
		"post-prepare rejection owner initializes distinct histories")
	reject.observer = weakref(host)
	host._material_blit_publisher = reject
	host.texture = reject.current
	host.previous_texture = reject.previous
	host._bind_material_texture_consumers()
	var c: Image = _pattern(host.world_extent,2,177)
	check(host.upload_texture_patches(host._full_material_rectangle(),c.get_data(),2,2),
		"Main publishes verified full fallback after commit rejection")
	check(not reject.rejection.is_empty() and reject.rejection.current_certificate == b.get_data()
		and reject.rejection.previous_certificate == a and reject.rejection.current_content_id == current_id
		and reject.rejection.previous_content_id == previous_id and reject.rejection.revision == 1,
		"pre-commit rejection observes unchanged Main certificates and ACK")
	check(reject.rejection.prepared == c.get_data(),"rejection occurs after the new target actually received C")
	if targets == 3:
		check(reject.rejection.current == b.get_data() and reject.rejection.previous == a,
			"preparing spare never mutates either visible history")
	check(host.texture is ImageTexture and host.previous_texture is ImageTexture
		and host._material_blit_publisher == null,"rejection retires the whole prepared owner")
	check(host.texture.get_image().get_data() == c.get_data()
		and host.previous_texture.get_image().get_data() == b.get_data(),
		"fallback uses new CPU C and OLD CURRENT B, never old previous A or spare")
	check(host._presentation_current_bytes == c.get_data() and host._presentation_previous_bytes == b.get_data()
		and host._presentation_previous_content_id == current_id and host.last_uploaded_revision == 2,
		"only the successful fallback advances exact certificates and revision")
	check(host.world_view.texture == host.texture
		and host.world_shader.get_shader_parameter("current_world_texture") == host.texture
		and host.world_shader.get_shader_parameter("previous_world_texture") == host.previous_texture,
		"all ordinary visible bindings use the recovered pair before return")
	observations.append({"label":"post-prepare fallback","history_targets":targets,
		"current_sha256":_sha(host.texture.get_image().get_data()),
		"previous_sha256":_sha(host.previous_texture.get_image().get_data()),
		"publication":host.material_publication_status()})
	host.world_view.free()
	host.shared_workbench.free()
	host.free()

func _virtual_hooks() -> void:
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS","3")
	var host: Control = _host(Consumer)
	var next: Image = _pattern(host.world_extent,2,177)
	check(host.upload_texture_patches(host._full_material_rectangle(),next.get_data(),1,2),
		"existing render-copy consumer virtual hooks accept transactional publication")
	var result: Dictionary = host.trace.result()
	var events: Array[String] = []
	for row: Dictionary in result.events:
		if row.event in ["texture_begin","texture_update_begin","texture_update_end","texture_success"]:
			events.append(row.event)
	check(events == ["texture_begin","texture_update_begin","texture_update_end","texture_success"]
		and result.dropped == 0,"existing virtual texture hooks retain their complete order and counts")
	check(host.texture.get_image().get_data() == next.get_data() and host.last_uploaded_revision == 1,
		"virtual consumer returns only after exact GPU publication and ACK")
	observations.append({"label":"render-copy virtual hooks","events":events,"dropped":result.dropped})
	host.world_view.free()
	host.shared_workbench.free()
	host.free()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("MATERIAL_HISTORY_TRANSACTION: graphical GPU test required")
		quit(2)
		return
	for channels: int in [1,2]:
		_token_contract(channels)
		_retained_spare_contract(channels)
	for targets: int in [2,3]: _post_prepare_fallback(targets)
	_virtual_hooks()
	var output: String = OS.get_environment("CYBERSAND_MATERIAL_HISTORY_OUTPUT")
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file != null,"transaction receipt opened")
	if file != null:
		file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"observations":observations,
			"scope":"External transaction/GPU correctness only; no performance or target-hardware acceptance."},"\t"))
	print("MATERIAL_HISTORY_TRANSACTION: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
