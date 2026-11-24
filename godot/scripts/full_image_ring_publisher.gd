class_name CyberFullImageRingPublisher
extends RefCounted

## Opt-in, bounded full-image publication experiment. Exactly three persistent
## ImageTextures retain current, previous and a spare. Each publication updates
## the spare before rotating the pair. Unlike the two-slot path, that destination
## was absent from the immediately preceding current/previous binding.
##
## Reuse distance is NOT a GPU completion fence or a nonblocking guarantee. More
## than one render frame may be queued. RenderingServer command ordering and an
## immutable copy for every queued update remain required. No native, revision,
## sample, callback, ACK or presentation-blend authority belongs to this object.
const SLOT_COUNT: int = 3

var current: ImageTexture
var previous: ImageTexture
var extent := Vector2i.ZERO
var logical_format: Image.Format = Image.FORMAT_RG8
var channels: int = 0
var last_update: Dictionary = {}
var _textures: Array[ImageTexture] = []
var _owned_ids := PackedInt64Array()
var _owned_rids: Array[RID] = []
var _current_slot: int = 0
var _previous_slot: int = 1
var _spare_slot: int = 2


static func create_pair(source: Image, preceding: Image) -> CyberFullImageRingPublisher:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return null
	var result: CyberFullImageRingPublisher = load("res://scripts/full_image_ring_publisher.gd").new()
	return result if result._setup(source, preceding) else null


func _valid_source(source: Image) -> bool:
	return source != null and not source.is_empty() and not source.has_mipmaps() \
		and source.get_size() == extent and source.get_format() == logical_format


func _setup(source: Image, preceding: Image) -> bool:
	if not _textures.is_empty() or source == null or source.is_empty() or source.has_mipmaps() \
		or source.get_format() not in [Image.FORMAT_R8, Image.FORMAT_RG8]: return false
	extent = source.get_size()
	logical_format = source.get_format()
	channels = 1 if logical_format == Image.FORMAT_R8 else 2
	if not _valid_source(preceding): return false
	var started: int = Time.get_ticks_usec()
	# Initial uploads can be queued too. Never retain the caller's mutable Image.
	for input: Image in [source, preceding, preceding]:
		var texture: ImageTexture = ImageTexture.create_from_image(input.duplicate())
		if texture == null or not texture.get_rid().is_valid(): return false
		_textures.append(texture)
		_owned_ids.append(texture.get_instance_id())
		_owned_rids.append(texture.get_rid())
	current = _textures[_current_slot]
	previous = _textures[_previous_slot]
	last_update = _status(-1)
	last_update.merge({"initialization":true, "initialization_usec":Time.get_ticks_usec()-started,
		"submitted_bytes":allocated_logical_gpu_bytes()})
	return true


func _owns_resources() -> bool:
	if _textures.size() != SLOT_COUNT or _owned_ids.size() != SLOT_COUNT or _owned_rids.size() != SLOT_COUNT:
		return false
	for slot: int in range(SLOT_COUNT):
		var value: ImageTexture = _textures[slot]
		if value == null or value.get_instance_id() != _owned_ids[slot] or value.get_rid() != _owned_rids[slot] \
			or value.get_size() != Vector2(extent) or value.get_format() != logical_format:
			return false
	return current == _textures[_current_slot] and previous == _textures[_previous_slot] \
		and _current_slot != _previous_slot and _spare_slot != _current_slot and _spare_slot != _previous_slot


func publish(source: Image) -> bool:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or not _valid_source(source) or not _owns_resources():
		return false
	var upload_slot: int = _spare_slot
	var started: int = Time.get_ticks_usec()
	_textures[upload_slot].update(source.duplicate())
	var backend_usec: int = Time.get_ticks_usec()-started
	_spare_slot = _previous_slot
	_previous_slot = _current_slot
	_current_slot = upload_slot
	current = _textures[_current_slot]
	previous = _textures[_previous_slot]
	last_update = _status(upload_slot)
	last_update.merge({"submitted_bytes":extent.x*extent.y*channels,
		"candidate_tiles":1, "updated_tiles":1, "tile_count":1,
		"tile_assembly_usec":0, "backend_submit_usec":backend_usec})
	return true


func allocated_logical_gpu_bytes() -> int:
	# Declared uncompressed R8/RG8 storage; driver allocation/residency is unknown.
	return SLOT_COUNT*extent.x*extent.y*channels


func resource_identity() -> PackedInt64Array:
	return _owned_ids.duplicate()


func _status(upload_slot: int) -> Dictionary:
	var rids := PackedInt64Array()
	for rid: RID in _owned_rids: rids.append(rid.get_id())
	return {"mode":"full", "full_image_slot_count":SLOT_COUNT,
		"current_slot":_current_slot, "previous_slot":_previous_slot,
		"spare_slot":_spare_slot, "upload_slot":upload_slot,
		"texture_ids":resource_identity(), "texture_rids":rids,
		"allocated_logical_gpu_bytes":allocated_logical_gpu_bytes(),
		"reuse_scope":"one intervening publication; not GPU completion"}
