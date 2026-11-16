class_name CyberBlitMaterialPublisher
extends RefCounted

# Godot 4.7 desktop Compatibility publication. CPU data enters a bounded
# R8/RG8 staging pool, then ordered GPU copies update two linear RGBA8 material
# histories. Ordinary 2D palette/effect sampling remains unchanged. No CPU
# upload targets a material history, and no draw samples its own output.
# Main owns the publisher; each public Texture2D owns its drawable and keeps
# only a weak publisher link for legacy ImageTexture.update-style callers.
const MAX_TILES: int = 256
const MIN_TILE_SIDE: int = 64
const MAX_TILE_SIDE: int = 1024
const CAPACITIES: Array[int] = [1, 4, 16, 64, 256]
const COPY_SHADER = preload("res://shaders/material_publication_blit.gdshader")

class MaterialPlane extends Texture2D:
	var drawable: DrawableTexture2D
	var _publisher: WeakRef
	var owned_object_id: int = 0
	var owned_rid: RID
	var extent := Vector2i.ZERO
	var logical_format: Image.Format = Image.FORMAT_RG8
	var pending := PackedByteArray()
	var bytes: Array[PackedByteArray] = []
	func _get_width() -> int: return extent.x
	func _get_height() -> int: return extent.y
	func _has_alpha() -> bool: return false
	func _get_rid() -> RID: return drawable.get_rid() if drawable != null else RID()
	func _get_image() -> Image:
		if drawable == null: return null
		var result: Image = drawable.get_image()
		if result == null or result.is_empty() or result.get_format() != Image.FORMAT_RGBA8: return null
		result.convert(logical_format)
		return result

	# Compatibility for direct effect fixtures/tools. Production uses publish()
	# and its revision/certificate transaction in Main, never this shortcut.
	func update(source: Image) -> bool:
		var owner: RefCounted = _publisher.get_ref() if _publisher != null else null
		return owner != null and owner.replace_plane(source, self)

var current: MaterialPlane
var previous: MaterialPlane
var extent := Vector2i.ZERO
var logical_format: Image.Format = Image.FORMAT_RG8
var channels: int = 2
var tile_side: int = MIN_TILE_SIDE
var columns: int = 0
var rows: int = 0
var staging: Dictionary = {}
var _staging_identities: Dictionary = {}
var _full_stage_identity: Array[int] = []
var full_stage: ImageTexture
var retirement_sink: DrawableTexture2D
var retirement_owned_id: int = 0
var retirement_owned_rid: RID
var copy_material: ShaderMaterial
var last_update: Dictionary = {}


static func supported_driver() -> bool:
	return OS.get_name() in ["Linux", "Windows"] and DisplayServer.get_name() != "headless" \
		and RenderingServer.get_current_rendering_driver_name() in ["opengl3", "opengl3_angle"]


static func create_pair(current_image: Image, previous_image: Image) -> CyberBlitMaterialPublisher:
	if not supported_driver(): return null
	var result: CyberBlitMaterialPublisher = load("res://scripts/blit_material_publisher.gd").new()
	return result if result._setup(current_image, previous_image) else null


func _valid_source(source: Image) -> bool:
	return source != null and not source.is_empty() and not source.has_mipmaps() \
		and source.get_size() == extent and source.get_format() == logical_format


func _setup(source: Image, preceding: Image) -> bool:
	var setup_started: int = Time.get_ticks_usec()
	# A fresh owner is required for every World replacement and mode switch.
	if current != null or previous != null or not staging.is_empty(): return false
	if source == null or source.is_empty() or source.has_mipmaps() \
			or source.get_format() not in [Image.FORMAT_R8, Image.FORMAT_RG8]: return false
	if source.get_width() >= 16384 or source.get_height() >= 16384: return false
	if preceding == null or preceding.get_size() != source.get_size() \
			or preceding.get_format() != source.get_format() or preceding.has_mipmaps(): return false
	extent = source.get_size()
	logical_format = source.get_format()
	channels = 1 if logical_format == Image.FORMAT_R8 else 2
	while true:
		columns = ceili(float(extent.x) / tile_side)
		rows = ceili(float(extent.y) / tile_side)
		if columns * rows <= MAX_TILES: break
		tile_side *= 2
		if tile_side > MAX_TILE_SIDE: return false
	copy_material = ShaderMaterial.new()
	copy_material.shader = COPY_SHADER
	retirement_sink = DrawableTexture2D.new()
	retirement_sink.setup(1,1,DrawableTexture2D.DRAWABLE_FORMAT_RGBA8,Color(0,0,0,1),false)
	retirement_owned_id = retirement_sink.get_instance_id()
	retirement_owned_rid = retirement_sink.get_rid()
	for capacity: int in CAPACITIES:
		var side: int = int(sqrt(float(capacity))) * tile_side
		var image := Image.create(side, side, false, logical_format)
		staging[capacity] = ImageTexture.create_from_image(image)
		if not staging[capacity].get_rid().is_valid(): return false
		_staging_identities[capacity] = [staging[capacity].get_instance_id(), staging[capacity].get_rid().get_id()]
		if capacity >= columns * rows: break
	for stage: ImageTexture in staging.values():
		if Vector2i(stage.get_size()) == extent: full_stage = stage
	if full_stage == null:
		full_stage = ImageTexture.create_from_image(Image.create(extent.x,extent.y,false,logical_format))
	_full_stage_identity = [full_stage.get_instance_id(), full_stage.get_rid().get_id()]
	current = _new_plane()
	previous = _new_plane()
	if current == null or previous == null: return false
	var initialized: Dictionary = {}
	var identical: bool = source.get_data() == preceding.get_data()
	if identical:
		if not _submit(source, [current, previous]): return false
		initialized = last_update.duplicate()
	else:
		if not _submit(source, [current]): return false
		initialized = last_update.duplicate()
		if not _submit(preceding, [previous]): return false
		for key: String in ["submitted_bytes", "atlas_assembly_usec", "staging_upload_usec",
				"gpu_blit_submit_usec", "gpu_blit_calls", "blit_pixels", "estimated_target_write_bytes",
				"retirement_blit_calls", "estimated_retirement_write_bytes"]:
			initialized[key] = int(initialized.get(key,0)) + int(last_update.get(key,0))
	# The preceding slot may differ anywhere after a live mode switch. Its
	# first reuse must compare all tiles against the next complete CPU image.
	if not identical: previous.pending.fill(1)
	# Prime each fixed source binding during setup. This is production work,
	# not a benchmark warmup; its measured cost belongs to initialization.
	var priming_started: int = Time.get_ticks_usec()
	var stages: Array = staging.values()
	if not stages.has(full_stage): stages.append(full_stage)
	var sink_rids: Array[RID] = [retirement_sink.get_rid()]
	for stage: ImageTexture in stages:
		var source_rids: Array[RID] = [stage.get_rid()]
		RenderingServer.texture_drawable_blit_rect(sink_rids,Rect2i(0,0,1,1),
			copy_material.get_rid(),Color(0,0,1,1),source_rids,0)
	initialized["priming_usec"] = Time.get_ticks_usec()-priming_started
	initialized["priming_blit_calls"] = stages.size()
	initialized["initialization_staging_zero_bytes"] = gpu_storage_bytes()-extent.x*extent.y*8-4
	initialized["submitted_bytes"] += initialized.initialization_staging_zero_bytes
	initialized["initialization"] = true
	initialized["initialization_usec"] = Time.get_ticks_usec()-setup_started
	# Setup also includes resource allocation and zero initialization, so its
	# duration is not reconstructed by summing the upload component scopes.
	last_update = initialized
	_finish_metrics()
	return true


func _new_plane() -> MaterialPlane:
	var plane := MaterialPlane.new()
	plane._publisher = weakref(self)
	plane.extent = extent
	plane.logical_format = logical_format
	plane.pending.resize(columns * rows)
	plane.pending.fill(1)
	plane.bytes.resize(columns * rows)
	plane.drawable = DrawableTexture2D.new()
	plane.drawable.setup(extent.x, extent.y, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0, 0, 0, 1), false)
	if not plane.drawable.get_rid().is_valid(): return null
	plane.owned_object_id = plane.drawable.get_instance_id()
	plane.owned_rid = plane.drawable.get_rid()
	return plane


func _tile(source: Image, index: int) -> Image:
	var origin := Vector2i((index % columns) * tile_side, (index / columns) * tile_side)
	var size := Vector2i(mini(tile_side, extent.x-origin.x), mini(tile_side, extent.y-origin.y))
	var image: Image = source.get_region(Rect2i(origin, size))
	if size != Vector2i(tile_side, tile_side):
		var padded := Image.create(tile_side, tile_side, false, logical_format)
		padded.blit_rect(image, Rect2i(Vector2i.ZERO,size), Vector2i.ZERO)
		image = padded
	return image


func _valid_state() -> bool:
	if extent.x <= 0 or extent.y <= 0 or extent.x >= 16384 or extent.y >= 16384 \
			or logical_format not in [Image.FORMAT_R8,Image.FORMAT_RG8] \
			or channels != (1 if logical_format == Image.FORMAT_R8 else 2): return false
	if tile_side < MIN_TILE_SIDE or tile_side > MAX_TILE_SIDE or (tile_side & (tile_side-1)) != 0 \
			or columns <= 0 or rows <= 0 or columns*rows > MAX_TILES \
			or columns != ceili(float(extent.x)/tile_side) or rows != ceili(float(extent.y)/tile_side): return false
	if copy_material == null or copy_material.shader == null or copy_material.shader.get_mode() != Shader.MODE_TEXTURE_BLIT \
			or retirement_sink == null or not retirement_sink.get_rid().is_valid() \
			or retirement_sink.get_instance_id() != retirement_owned_id or retirement_sink.get_rid() != retirement_owned_rid \
			or Vector2i(retirement_sink.get_size()) != Vector2i.ONE or retirement_sink.get_use_mipmaps(): return false
	for plane: MaterialPlane in [current,previous]:
		if plane == null or plane.drawable == null or not plane.drawable.get_rid().is_valid() \
				or plane.drawable.get_instance_id() != plane.owned_object_id or plane.drawable.get_rid() != plane.owned_rid \
				or plane.extent != extent or plane.logical_format != logical_format \
				or Vector2i(plane.drawable.get_size()) != extent or plane.drawable.get_use_mipmaps() \
				or plane.bytes.size() != columns*rows or plane.pending.size() != columns*rows \
				or plane.drawable.get_rid() == retirement_sink.get_rid(): return false
	for capacity: int in staging:
		var stage: ImageTexture = staging[capacity] as ImageTexture
		var identity: Array = _staging_identities.get(capacity, [])
		var side: int = int(sqrt(float(capacity)))*tile_side
		if capacity not in CAPACITIES or stage == null or identity.size() != 2 \
				or stage.get_instance_id() != identity[0] or stage.get_rid().get_id() != identity[1] \
				or Vector2i(stage.get_size()) != Vector2i(side,side) or stage.get_format() != logical_format: return false
	if full_stage == null or _full_stage_identity.size() != 2 \
			or full_stage.get_instance_id() != _full_stage_identity[0] or full_stage.get_rid().get_id() != _full_stage_identity[1] \
			or Vector2i(full_stage.get_size()) != extent or full_stage.get_format() != logical_format: return false
	return current.get_rid() != previous.get_rid()


func publish(source: Image, rectangles: Array[Rect2i]) -> bool:
	if not _valid_source(source) or not _valid_state(): return false
	# Validate every rectangle before touching pending coverage or resources.
	for area: Rect2i in rectangles:
		if area.size.x <= 0 or area.size.y <= 0 or area.position.x < 0 or area.position.y < 0 \
				or area.end.x > extent.x or area.end.y > extent.y: return false
	for plane: MaterialPlane in [current, previous]:
		if rectangles.is_empty():
			plane.pending.fill(1)
		else:
			for area: Rect2i in rectangles:
				var first: Vector2i = area.position / tile_side
				var last: Vector2i = (area.end - Vector2i.ONE) / tile_side
				for y: int in range(first.y,last.y+1):
					for x: int in range(first.x,last.x+1): plane.pending[y*columns+x] = 1
	if not _submit(source, [previous]): return false
	var retired: MaterialPlane = previous
	previous = current
	current = retired
	return true


func replace_plane(source: Image, destination: MaterialPlane) -> bool:
	if not _valid_source(source) or not _valid_state() or destination not in [current,previous]: return false
	# Direct Texture2D.update() does not advance Main's source/history identity.
	# Keep both slots conservatively dirty for the next normal publication.
	current.pending.fill(1)
	previous.pending.fill(1)
	return _submit(source, [destination])


func _finish_metrics() -> void:
	last_update["tile_assembly_usec"] = last_update.get("atlas_assembly_usec",0)
	last_update["backend_submit_usec"] = int(last_update.get("staging_upload_usec",0)) + int(last_update.get("gpu_blit_submit_usec",0))
	last_update["logical_source_format"] = "R8" if channels == 1 else "RG8"
	last_update["gpu_storage_format"] = "RGBA8_LINEAR"
	last_update["tile_side"] = tile_side
	last_update["tile_count"] = columns*rows


func _submit(source: Image, destinations: Array[MaterialPlane]) -> bool:
	var started: int = Time.get_ticks_usec()
	last_update = {"mode":"blit", "candidate_tiles":0, "updated_tiles":0,
		"submitted_bytes":0, "atlas_capacity":0, "atlas_assembly_usec":0,
		"staging_upload_usec":0, "gpu_blit_submit_usec":0, "gpu_blit_calls":0,
		"blit_pixels":0, "estimated_target_write_bytes":0, "allocated_gpu_bytes":gpu_storage_bytes(),
		"retirement_blit_calls":0, "estimated_retirement_write_bytes":0}
	if not _valid_source(source) or not _valid_state() or destinations.is_empty(): return false
	for plane: MaterialPlane in destinations:
		if plane not in [current,previous]: return false
	var changed := PackedInt32Array()
	var images: Array[Image] = []
	var bytes: Array[PackedByteArray] = []
	for index: int in range(columns*rows):
		if destinations[0].pending[index] == 0: continue
		last_update.candidate_tiles += 1
		var image: Image = _tile(source,index)
		if image == null or image.get_size() != Vector2i(tile_side,tile_side) \
				or image.get_format() != logical_format or image.has_mipmaps(): return false
		var tile_bytes: PackedByteArray = image.get_data()
		if tile_bytes.size() != tile_side*tile_side*channels: return false
		if tile_bytes == destinations[0].bytes[index]: continue
		changed.append(index)
		images.append(image)
		bytes.append(tile_bytes)
	if changed.is_empty():
		for plane: MaterialPlane in destinations: plane.pending.fill(0)
		last_update.atlas_assembly_usec = Time.get_ticks_usec()-started
		_finish_metrics()
		return true
	var capacity: int = 1
	while capacity < changed.size(): capacity *= 4
	var atlas_columns: int = int(sqrt(float(capacity)))
	var atlas_side: int = atlas_columns * tile_side
	var whole: bool = atlas_side*atlas_side >= extent.x*extent.y
	var stage: ImageTexture = full_stage if whole else staging.get(capacity) as ImageTexture
	var stage_size: Vector2i = extent if whole else Vector2i(atlas_side,atlas_side)
	if stage == null or Vector2i(stage.get_size()) != stage_size \
			or stage.get_format() != logical_format or not stage.get_rid().is_valid(): return false
	for plane: MaterialPlane in destinations:
		if plane.drawable.get_rid() == stage.get_rid(): return false
	if retirement_sink.get_rid() == stage.get_rid(): return false
	# This Image is immutable after update(): a separate RenderingServer thread
	# may retain it until the queued upload executes. Never recycle its storage.
	var atlas: Image
	if whole:
		# Dense publication uses one full GPU copy, not hundreds of tile draws.
		atlas = source.duplicate()
	else:
		atlas = Image.create(atlas_side,atlas_side,false,logical_format)
		for item: int in range(changed.size()):
			atlas.blit_rect(images[item],Rect2i(0,0,tile_side,tile_side),
				Vector2i((item%atlas_columns)*tile_side,(item/atlas_columns)*tile_side))
	last_update.atlas_assembly_usec = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	stage.update(atlas)
	last_update.staging_upload_usec = Time.get_ticks_usec()-started
	var source_rids: Array[RID] = [stage.get_rid()]
	started = Time.get_ticks_usec()
	if whole:
		for plane: MaterialPlane in destinations:
			var output_rids: Array[RID] = [plane.drawable.get_rid()]
			RenderingServer.texture_drawable_blit_rect(output_rids,Rect2i(Vector2i.ZERO,extent),
				copy_material.get_rid(),Color(0,0,extent.x,extent.y),source_rids,0)
		last_update.gpu_blit_calls = destinations.size()
		last_update.blit_pixels = extent.x*extent.y*destinations.size()
	else:
		for item: int in range(changed.size()):
			var index: int = changed[item]
			var position := Vector2i((index%columns)*tile_side,(index/columns)*tile_side)
			var size := Vector2i(mini(tile_side,extent.x-position.x),mini(tile_side,extent.y-position.y))
			var source_origin := Vector2i((item%atlas_columns)*tile_side,(item/atlas_columns)*tile_side)
			for plane: MaterialPlane in destinations:
				var output_rids: Array[RID] = [plane.drawable.get_rid()]
				RenderingServer.texture_drawable_blit_rect(output_rids,Rect2i(position,size),
					copy_material.get_rid(),Color(source_origin.x,source_origin.y,size.x,size.y),source_rids,0)
			last_update.blit_pixels += size.x*size.y*destinations.size()
		last_update.gpu_blit_calls = changed.size()*destinations.size()
	# Godot's persistent FBO retains attachments while unbound. Always detach
	# large targets by replacing its sole attachment with one owned 1x1 sink.
	# Single-target calls throughout ensure no hidden second MRT attachment.
	var sink_rids: Array[RID] = [retirement_sink.get_rid()]
	RenderingServer.texture_drawable_blit_rect(sink_rids,Rect2i(0,0,1,1),
		copy_material.get_rid(),Color(0,0,1,1),source_rids,0)
	last_update.retirement_blit_calls = 1
	last_update.estimated_retirement_write_bytes = 4
	last_update.gpu_blit_submit_usec = Time.get_ticks_usec()-started
	for plane: MaterialPlane in destinations:
		for item: int in range(changed.size()): plane.bytes[changed[item]] = bytes[item]
		plane.pending.fill(0)
	last_update.updated_tiles = changed.size()
	last_update.submitted_bytes = stage_size.x*stage_size.y*channels
	last_update.estimated_target_write_bytes = 4*last_update.blit_pixels
	last_update.whole_gpu_copy = whole
	last_update.atlas_capacity = capacity
	_finish_metrics()
	return true


func resource_identity() -> Array[int]:
	var ids: Array[int] = [current.get_rid().get_id(),previous.get_rid().get_id()]
	ids.append(retirement_sink.get_rid().get_id())
	for capacity: int in staging: ids.append(staging[capacity].get_rid().get_id())
	if not staging.values().has(full_stage): ids.append(full_stage.get_rid().get_id())
	ids.sort()
	return ids


func gpu_storage_bytes() -> int:
	var bytes: int = extent.x*extent.y*4*2+4
	for capacity: int in staging: bytes += capacity*tile_side*tile_side*channels
	if full_stage != null and not staging.values().has(full_stage): bytes += extent.x*extent.y*channels
	return bytes
