extends SceneTree

## Exercise the production Main transaction, including a same-size World
## replacement and structural ring refusal. GPU reads remain first reads;
## recovering a later plane never repairs a failed earlier comparison.
const Main = preload("res://scripts/main.gd")
const Context = preload("res://tests/palette_qualification_context.gd")
const EXTENT := Vector2i(33,19)
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var output: String = ""

class AckProbe extends "res://scripts/simulation_worker.gd":
	var serials: Array[int] = []
	func acknowledge_render_snapshot(serial: int) -> void:
		serials.append(serial)


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt="): output = argument.trim_prefix("--receipt=")
	_run.call_deferred()


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("FULL_IMAGE_RING_MAIN: "+detail)


func _packet(serial: int, generation: int, revision: int) -> CyberSimulationSnapshot:
	var result := CyberSimulationSnapshot.new()
	result.render_world_generation = generation
	result.world_revision = revision
	result.render_snapshot_serial = serial
	result.render_tick_index = revision
	result.render_generated_usec = Time.get_ticks_usec()
	result.render_channels = 2
	result.render_full_refresh = true
	result.render_patch_rectangles = PackedInt32Array([0,0,EXTENT.x,EXTENT.y,0,EXTENT.x*2])
	var pixels := Image.create(EXTENT.x,EXTENT.y,false,Image.FORMAT_RG8)
	pixels.fill(Color8(3+serial,137-serial,0))
	result.render_patch_cells = pixels.get_data()
	return result


func _hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _histories(host: Control, current: PackedByteArray, previous: PackedByteArray, label: String) -> void:
	var gpu_current: Image = host.texture.get_image()
	var gpu_previous: Image = host.previous_texture.get_image()
	var current_ok: bool = gpu_current != null and gpu_current.get_size() == EXTENT \
		and gpu_current.get_format() == Image.FORMAT_RG8 and gpu_current.get_data() == current
	var previous_ok: bool = gpu_previous != null and gpu_previous.get_size() == EXTENT \
		and gpu_previous.get_format() == Image.FORMAT_RG8 and gpu_previous.get_data() == previous
	check(current_ok,label+" exact first GPU current")
	check(previous_ok,label+" exact first GPU previous")
	observations.append({"label":label,"current_verified":current_ok,"previous_verified":previous_ok,
		"current_sha256":_hash(gpu_current.get_data()) if gpu_current != null else "",
		"previous_sha256":_hash(gpu_previous.get_data()) if gpu_previous != null else "",
		"expected_current_sha256":_hash(current),"expected_previous_sha256":_hash(previous)})


func _run() -> void:
	check(DisplayServer.get_name() != "headless","graphical backend required")
	check(OS.get_environment("CYBERSAND_MATERIAL_PUBLICATION") == "full" \
		and OS.get_environment("CYBERSAND_DIAG_FULL_IMAGE_SLOTS") == "3","explicit three-slot Full selection required")
	if not failures.is_empty():
		quit(1)
		return
	var host = Main.new()
	var ack := AckProbe.new()
	host.simulation_worker = ack
	host.shared_workbench = Control.new()
	host.world_extent = EXTENT
	host.render_channels = 2
	host.render_image_format = Image.FORMAT_RG8
	host.image = Image.create(EXTENT.x,EXTENT.y,false,Image.FORMAT_RG8)
	host.cadence_lod_enabled = true
	host.create_render_textures()
	check(host._material_full_ring != null,"Main creates requested ring")
	var expected_previous: PackedByteArray = host.image.get_data()
	var packets: Array[CyberSimulationSnapshot] = []
	for serial: int in range(1,7): packets.append(_packet(serial,42 if serial < 3 else 43,serial if serial < 3 else serial-2))
	for index: int in range(4):
		host.consume_render_snapshot(packets[index])
		_histories(host,packets[index].render_patch_cells,expected_previous,"admission%d" % (index+1))
		check(ack.serials.size() == index+1 and ack.serials[-1] == index+1,"one exact ACK per admission")
		check(host.material_publication_status().full_image_slots == 3,"ordinary transaction retains ring")
		var frame: Dictionary = host._material_presentation_state(host.snapshot_blend_start_usec)
		if index == 2:
			check(frame.current.generation == 43 and frame.previous.is_empty() \
				and not frame.previous_blend_active and frame.snapshot_blend == 1.0,"new World gives old history no visual authority")
		elif index == 3:
			check(frame.previous.generation == 43 and frame.previous_blend_active,"same-World successor restores qualified blend")
		expected_previous = packets[index].render_patch_cells
	# Tamper only with the publisher's exposed reference. Main still owns its
	# prior exact pair. The production owner check must refuse before ring update.
	host._material_full_ring.current = ImageTexture.create_from_image(host.image.duplicate())
	host.consume_render_snapshot(packets[4])
	_histories(host,packets[4].render_patch_cells,expected_previous,"refusal-recovery")
	check(host._material_full_ring == null and host.material_publication_status().full_image_slots == 2
		and host.material_publication_status().fallback_reason == "full image ring ownership or source refused",
		"Main truthfully falls back to exact two-slot storage")
	check(ack.serials == [1,2,3,4,5],"refusal recovery ACKs accepted material once")
	host.consume_render_snapshot(packets[5])
	_histories(host,packets[5].render_patch_cells,packets[4].render_patch_cells,"post-recovery")
	check(ack.serials == [1,2,3,4,5,6] and host._material_full_ring == null,"fallback remains two-slot through next accepted ACK")
	check(host.set_material_publication_mode("full") and host._material_full_ring != null,"explicit mode recreation rebuilds bounded ring")
	_histories(host,packets[5].render_patch_cells,packets[4].render_patch_cells,"mode-recreation")
	check(ack.serials == [1,2,3,4,5,6],"mode recreation invents no publication ACK")
	var result := {"schema":"pubpres-full-image-ring-main-recovery-v1","checks":checks,
		"complete":failures.is_empty(),"failures":failures,"observations":observations,"acks":ack.serials,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"pid":OS.get_process_id(),
		"context":Context.identity(get_script().resource_path),
		"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
		"publisher_sha256":FileAccess.get_sha256("res://scripts/full_image_ring_publisher.gd"),
		"driver":RenderingServer.get_current_rendering_driver_name(),"render_thread_inline":RenderingServer.is_on_render_thread()}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null:
			check(false,"cannot write receipt")
		else:
			file.store_string(JSON.stringify(result)+"\n")
			file.close()
	print("FULL_IMAGE_RING_MAIN_RESULT ",JSON.stringify(result))
	host.shared_workbench.free()
	host.shared_workbench = null
	host.free()
	quit(int(not failures.is_empty()))
