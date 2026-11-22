class_name CyberBlitMaterialPublisher
extends RefCounted

# Godot 4.7 desktop Compatibility publication. CPU data enters a bounded
# R8/RG8 array staging pool, then ordered GPU copies update two linear RGBA8 material
# histories. Ordinary 2D palette/effect sampling remains unchanged. No CPU
# upload targets a material history, and no draw samples its own output.
# Main owns the publisher; each public Texture2D owns its drawable and keeps
# only a weak publisher link for legacy ImageTexture.update-style callers.
const MAX_TILES: int = 256
const HISTORY_COPY_MIN_TILES: int = 128
const HISTORY_STAGING_CAPACITIES: Array[int] = [1, 4]
const MIN_TILE_SIDE: int = 64
const MAX_TILE_SIDE: int = 1024
const CAPACITIES: Array[int] = [1, 4, 16, 64, 128, 256]
const CAPACITY_TILE_EXTENTS: Dictionary = {
	1:Vector2i(1,1), 4:Vector2i(2,2), 16:Vector2i(4,4),
	64:Vector2i(8,8), 128:Vector2i(16,8), 256:Vector2i(16,16),
}
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
	var exact_whole_bytes := PackedByteArray()
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

class StagingResource extends RefCounted:
	var texture: Texture2DArray
	var owned_object_id: int = 0
	var owned_rid: RID
	var material: ShaderMaterial
	var owned_material_id: int = 0
	var owned_material_rid: RID

class StagingPool extends RefCounted:
	var resources: Array[StagingResource] = []
	var owned_resource_ids := PackedInt64Array()
	var extent := Vector2i.ZERO
	var next_slot: int = 0

var current: MaterialPlane
var previous: MaterialPlane
var extent := Vector2i.ZERO
var logical_format: Image.Format = Image.FORMAT_RG8
var channels: int = 2
var tile_side: int = MIN_TILE_SIDE
var columns: int = 0
var rows: int = 0
# Each slot owns an independent one-layer array and a fixed sampler material.
# The bounded ring supplies reuse distance, not a fence or nonblocking promise.
# Three is provisional for the diagnostic experiment, not an acceptance claim.
var staging_slots: int = 3
var copy_mode: String = "runs"
# PUBPRES-PLAYABILITY-001 residency control. The ordinary eager policy remains
# the default. Reachable omits only atlases which _submit always replaces with
# the exact full-image pool; every resource it can select still exists at setup.
var staging_pool_policy: String = "eager"
var staging: Dictionary = {}
var _staging_pool_ids: Dictionary = {}
# The copy into the recycled history texture can outlive ordinary small
# submissions. Give those patches independent upload resources and cursors.
var _history_staging: Dictionary = {}
var _history_staging_pool_ids: Dictionary = {}
var full_staging: StagingPool
var _full_staging_pool_id: int = 0
var retirement_sink: DrawableTexture2D
var retirement_owned_id: int = 0
var retirement_owned_rid: RID
# Required ordinary source0 stays disjoint from every sampled array and output.
# Each resource owns one fixed custom array sampler at texture unit 1.
var dummy_source: ImageTexture
var dummy_owned_id: int = 0
var dummy_owned_rid: RID
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
	var requested_slots: String = OS.get_environment("CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS")
	staging_slots = int(requested_slots) if requested_slots in ["1","2","3"] else 3
	copy_mode = "tiles" if OS.get_environment("CYBERSAND_DIAG_MATERIAL_COPY_MODE") == "tiles" else "runs"
	staging_pool_policy = "reachable" if OS.get_environment("CYBERSAND_DIAG_MATERIAL_POOL_POLICY") == "reachable" else "eager"
	channels = 1 if logical_format == Image.FORMAT_R8 else 2
	while true:
		columns = ceili(float(extent.x) / tile_side)
		rows = ceili(float(extent.y) / tile_side)
		if columns * rows <= MAX_TILES: break
		tile_side *= 2
		if tile_side > MAX_TILE_SIDE: return false
	dummy_source = ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_R8))
	if dummy_source == null or not dummy_source.get_rid().is_valid(): return false
	dummy_owned_id = dummy_source.get_instance_id()
	dummy_owned_rid = dummy_source.get_rid()
	retirement_sink = DrawableTexture2D.new()
	retirement_sink.setup(1,1,DrawableTexture2D.DRAWABLE_FORMAT_RGBA8,Color(0,0,0,1),false)
	retirement_owned_id = retirement_sink.get_instance_id()
	retirement_owned_rid = retirement_sink.get_rid()
	for capacity: int in _required_staging_capacities():
		# The 128-tile rectangle bounds the measured 65..128-tile case without
		# rounding it to a full 256-tile World. Allocate and prime it here so
		# its bounded storage/setup cost is visible before interactive uploads.
		var pool: StagingPool = _new_staging_pool(_capacity_extent(capacity))
		if pool == null: return false
		staging[capacity] = pool
		_staging_pool_ids[capacity] = pool.get_instance_id()
		if pool.extent == extent: full_staging = pool
	if full_staging == null:
		full_staging = _new_staging_pool(extent)
		if full_staging == null: return false
	_full_staging_pool_id = full_staging.get_instance_id()
	for capacity: int in _required_history_staging_capacities():
		var pool: StagingPool = _new_staging_pool(_capacity_extent(capacity))
		if pool == null: return false
		_history_staging[capacity] = pool
		_history_staging_pool_ids[capacity] = pool.get_instance_id()
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
				"retirement_blit_calls", "estimated_retirement_write_bytes", "copy_run_count",
				"uncoalesced_gpu_blit_calls", "coalesced_gpu_blit_calls_saved", "uncoalesced_blit_pixels"]:
			initialized[key] = int(initialized.get(key,0)) + int(last_update.get(key,0))
	# The preceding slot may differ anywhere after a live mode switch. Its
	# first reuse must compare all tiles against the next complete CPU image.
	if not identical: previous.pending.fill(1)
	# Prime resource0 in each class, then choose the least recently used next
	# resource. Distinct histories may already have used0 and1: preserve the
	# still-unused2 in a three-resource ring. This gives reuse distance only;
	# all initialization uploads and preparation remain in the setup receipt.
	initialized["copy_destinations"] = 2
	var priming_started: int = Time.get_ticks_usec()
	var pools: Array = _owned_staging_pools()
	var sink_rids: Array[RID] = [retirement_sink.get_rid()]
	# Prepare the built-in direct texture sampler with the already owned sink.
	retirement_sink.blit_rect(Rect2i(0,0,1,1),dummy_source)
	for pool: StagingPool in pools:
		var source_rids: Array[RID] = [dummy_source.get_rid()]
		RenderingServer.texture_drawable_blit_rect(sink_rids,Rect2i(0,0,1,1),
			pool.resources[0].material.get_rid(),Color(0,0,1,1),source_rids,0)
		pool.next_slot = maxi(1,pool.next_slot)%staging_slots
	initialized["priming_usec"] = Time.get_ticks_usec()-priming_started
	initialized["priming_blit_calls"] = pools.size()+1
	initialized["initialization_staging_zero_bytes"] = gpu_storage_bytes()-extent.x*extent.y*8-5
	initialized["initialization_dummy_source_bytes"] = 1
	initialized["submitted_bytes"] += initialized.initialization_staging_zero_bytes+initialized.initialization_dummy_source_bytes
	initialized["initialization"] = true
	initialized["initialization_usec"] = Time.get_ticks_usec()-setup_started
	# Setup also includes resource allocation and zero initialization, so its
	# duration is not reconstructed by summing the upload component scopes.
	last_update = initialized
	_finish_metrics()
	return true


func _new_staging_pool(size: Vector2i) -> StagingPool:
	var pool := StagingPool.new()
	pool.extent = size
	var zero := Image.create(size.x,size.y,false,logical_format)
	# The immutable zero image may be retained by the render queue. Each
	# array is a separate allocation with exactly one layer, not another
	# layer of a shared storage object.
	var layers: Array[Image] = [zero]
	for slot: int in range(staging_slots):
		var resource := StagingResource.new()
		resource.texture = Texture2DArray.new()
		if resource.texture.create_from_images(layers) != OK or not resource.texture.get_rid().is_valid(): return null
		resource.owned_object_id = resource.texture.get_instance_id()
		resource.owned_rid = resource.texture.get_rid()
		resource.material = ShaderMaterial.new()
		resource.material.shader = COPY_SHADER
		resource.material.set_shader_parameter("staging_array",resource.texture)
		resource.owned_material_id = resource.material.get_instance_id()
		resource.owned_material_rid = resource.material.get_rid()
		pool.resources.append(resource)
		pool.owned_resource_ids.append(resource.get_instance_id())
	return pool


func _capacity_extent(capacity: int) -> Vector2i:
	return CAPACITY_TILE_EXTENTS.get(capacity,Vector2i.ZERO)*tile_side


func _required_staging_capacities() -> Array[int]:
	var result: Array[int] = []
	for capacity: int in CAPACITIES:
		var size: Vector2i = _capacity_extent(capacity)
		# _submit selects full_staging whenever atlas area reaches World area.
		# Equal shape must retain its existing alias and shared cursor. A larger
		# or differently shaped atlas at that area is otherwise unreachable.
		if staging_pool_policy != "reachable" or size == extent \
				or size.x*size.y < extent.x*extent.y:
			result.append(capacity)
		if capacity >= columns*rows: break
	return result


func _required_history_staging_capacities() -> Array[int]:
	var result: Array[int] = []
	if columns*rows < HISTORY_COPY_MIN_TILES: return result
	for capacity: int in HISTORY_STAGING_CAPACITIES:
		var size: Vector2i = _capacity_extent(capacity)
		# Whole-image history copies also use full_staging. A dedicated history
		# pool has no full-image alias and is required only for smaller atlases.
		if staging_pool_policy != "reachable" or size.x*size.y < extent.x*extent.y:
			result.append(capacity)
	return result


func _valid_staging_pool(pool: StagingPool, size: Vector2i) -> bool:
	if pool == null or pool.extent != size or pool.next_slot < 0 or pool.next_slot >= staging_slots \
			or pool.resources.size() != staging_slots or pool.owned_resource_ids.size() != staging_slots: return false
	# Preflight every inactive resource as well as the selected resource.
	# These Resource properties and cached sampler associations are local;
	# no GPU readback or synchronous renderer query occurs here.
	for slot: int in range(staging_slots):
		var resource: StagingResource = pool.resources[slot]
		if resource == null or resource.get_instance_id() != pool.owned_resource_ids[slot]: return false
		var stage: Texture2DArray = resource.texture
		if stage == null or stage.get_instance_id() != resource.owned_object_id \
				or stage.get_rid() != resource.owned_rid or not stage.get_rid().is_valid() \
				or Vector2i(stage.get_width(),stage.get_height()) != size \
				or stage.get_format() != logical_format or stage.get_layers() != 1 or stage.has_mipmaps(): return false
		if resource.material == null or not resource.material.get_rid().is_valid() \
				or resource.material.get_instance_id() != resource.owned_material_id \
				or resource.material.get_rid() != resource.owned_material_rid \
				or resource.material.shader != COPY_SHADER or COPY_SHADER.get_mode() != Shader.MODE_TEXTURE_BLIT \
				or resource.material.get_shader_parameter("staging_array") != stage: return false
		if stage.get_rid() == dummy_source.get_rid() or stage.get_rid() == retirement_sink.get_rid(): return false
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
	if staging_slots not in [1,2,3] or copy_mode not in ["tiles","runs"] \
			or staging_pool_policy not in ["eager","reachable"]: return false
	if extent.x <= 0 or extent.y <= 0 or extent.x >= 16384 or extent.y >= 16384 \
			or logical_format not in [Image.FORMAT_R8,Image.FORMAT_RG8] \
			or channels != (1 if logical_format == Image.FORMAT_R8 else 2): return false
	if tile_side < MIN_TILE_SIDE or tile_side > MAX_TILE_SIDE or (tile_side & (tile_side-1)) != 0 \
			or columns <= 0 or rows <= 0 or columns*rows > MAX_TILES \
			or columns != ceili(float(extent.x)/tile_side) or rows != ceili(float(extent.y)/tile_side): return false
	if dummy_source == null or dummy_source.get_instance_id() != dummy_owned_id \
			or dummy_source.get_rid() != dummy_owned_rid or not dummy_source.get_rid().is_valid() \
			or Vector2i(dummy_source.get_size()) != Vector2i.ONE or dummy_source.get_format() != Image.FORMAT_R8: return false
	if retirement_sink == null or not retirement_sink.get_rid().is_valid() \
			or retirement_sink.get_instance_id() != retirement_owned_id or retirement_sink.get_rid() != retirement_owned_rid \
			or Vector2i(retirement_sink.get_size()) != Vector2i.ONE or retirement_sink.get_use_mipmaps() \
			or retirement_sink.get_rid() == dummy_source.get_rid(): return false
	for plane: MaterialPlane in [current,previous]:
		if plane == null or plane.drawable == null or not plane.drawable.get_rid().is_valid() \
				or plane.drawable.get_instance_id() != plane.owned_object_id or plane.drawable.get_rid() != plane.owned_rid \
				or plane.extent != extent or plane.logical_format != logical_format \
				or Vector2i(plane.drawable.get_size()) != extent or plane.drawable.get_use_mipmaps() \
				or plane.bytes.size() != columns*rows or plane.pending.size() != columns*rows \
				or plane.drawable.get_rid() == retirement_sink.get_rid() \
				or plane.drawable.get_rid() == dummy_source.get_rid(): return false
	var capacities: Array[int] = _required_staging_capacities()
	if staging.size() != capacities.size() or _staging_pool_ids.size() != capacities.size(): return false
	var history_capacities: Array[int] = _required_history_staging_capacities()
	if _history_staging.size() != history_capacities.size() \
			or _history_staging_pool_ids.size() != history_capacities.size(): return false
	for capacity: int in history_capacities:
		var pool: StagingPool = _history_staging.get(capacity) as StagingPool
		if pool == null or pool.get_instance_id() != int(_history_staging_pool_ids.get(capacity,0)) \
				or not _valid_staging_pool(pool,_capacity_extent(capacity)): return false
	for capacity: int in capacities:
		var pool: StagingPool = staging.get(capacity) as StagingPool
		if pool == null or pool.get_instance_id() != int(_staging_pool_ids.get(capacity,0)): return false
		if not _valid_staging_pool(pool,_capacity_extent(capacity)): return false
	if full_staging == null or full_staging.get_instance_id() != _full_staging_pool_id \
			or not _valid_staging_pool(full_staging,extent): return false
	# Distinct capacity pools and slots must not alias a texture or sampler
	# material. Only an equal-size full atlas shares its existing pool/cursor.
	var pools: Array = _owned_staging_pools()
	var texture_ids: Dictionary = {current.get_rid():true, previous.get_rid():true,
		retirement_sink.get_rid():true, dummy_source.get_rid():true}
	var material_ids: Dictionary = {}
	for pool: StagingPool in pools:
		for resource: StagingResource in pool.resources:
			var texture_rid: RID = resource.texture.get_rid()
			var material_rid: RID = resource.material.get_rid()
			if texture_ids.has(texture_rid) or material_ids.has(material_rid): return false
			texture_ids[texture_rid] = true
			material_ids[material_rid] = true
	return current.get_rid() != previous.get_rid()


func publish(source: Image, rectangles: Array[Rect2i]) -> bool:
	if not _valid_source(source) or not _valid_state(): return false
	# Validate every rectangle before touching pending coverage or resources.
	for area: Rect2i in rectangles:
		if area.size.x <= 0 or area.size.y <= 0 or area.position.x < 0 or area.position.y < 0 \
				or area.end.x > extent.x or area.end.y > extent.y: return false
	# A full resync can carry bytes already known to be in the current target.
	# Its receipt advances and rotates normally, but it adds no newly dirty
	# tiles to either plane. Keep the recycled target's existing coverage.
	var identical_full: bool = not current.exact_whole_bytes.is_empty() \
		and (rectangles.is_empty() or (rectangles.size() == 1 \
			and rectangles[0] == Rect2i(Vector2i.ZERO, extent))) \
		and source.get_data() == current.exact_whole_bytes
	var incoming := PackedByteArray()
	var reuse_current: bool = false
	# Recycle a plane made entirely stale by the preceding dense frame. Copy
	# the exact current GPU history, then submit only the new sparse coverage.
	# Direct compatibility writes leave current.pending dirty and disable this.
	if not identical_full and not rectangles.is_empty() and rectangles.size() <= 4 \
			and columns * rows >= HISTORY_COPY_MIN_TILES and not previous.pending.has(0) and not current.pending.has(1):
		incoming.resize(columns*rows)
		_mark_pending(incoming,rectangles)
		reuse_current = incoming.count(1) <= 4
	if reuse_current:
		if not _submit(source,[previous],incoming,current): return false
		current.pending = incoming
	else:
		if not identical_full:
			_mark_pending(current.pending,rectangles)
			_mark_pending(previous.pending,rectangles)
		if not _submit(source,[previous]): return false
	var retired: MaterialPlane = previous
	previous = current
	current = retired
	return true


func _mark_pending(pending: PackedByteArray, rectangles: Array[Rect2i]) -> void:
	if rectangles.is_empty():
		pending.fill(1)
		return
	for area: Rect2i in rectangles:
		var first: Vector2i = area.position / tile_side
		var last: Vector2i = (area.end - Vector2i.ONE) / tile_side
		for y: int in range(first.y,last.y+1):
			for x: int in range(first.x,last.x+1): pending[y*columns+x] = 1


func replace_plane(source: Image, destination: MaterialPlane) -> bool:
	if not _valid_source(source) or not _valid_state() or destination not in [current,previous]: return false
	# Direct Texture2D.update() does not advance Main's source/history identity.
	# Keep both slots conservatively dirty for the next normal publication.
	current.pending.fill(1)
	previous.pending.fill(1)
	if not _submit(source, [destination]): return false
	# The direct caller's image is independent of Main's CPU source. _submit
	# clears the written target, so invalidate both again AFTER success. A
	# later sparse authoritative publication must compare every tile before
	# either target can retain manual bytes outside its new patch rectangles.
	current.pending.fill(1)
	previous.pending.fill(1)
	return true


func _finish_metrics() -> void:
	last_update["tile_assembly_usec"] = last_update.get("atlas_assembly_usec",0)
	last_update["backend_submit_usec"] = int(last_update.get("staging_upload_usec",0)) + int(last_update.get("gpu_blit_submit_usec",0))
	last_update["logical_source_format"] = "R8" if channels == 1 else "RG8"
	last_update["gpu_storage_format"] = "RGBA8_LINEAR"
	last_update["tile_side"] = tile_side
	last_update["tile_count"] = columns*rows
	last_update["staging_slots"] = staging_slots
	last_update["staging_pool_policy"] = staging_pool_policy
	last_update["staging_backend"] = "texture2d_array"
	last_update["staging_layer"] = 0 if int(last_update.get("staging_slot",-1)) >= 0 else -1
	last_update["staging_resource_layers"] = 1
	last_update["copy_mode"] = copy_mode
	var cpu_bytes: int = 0
	for plane: MaterialPlane in [current, previous]:
		cpu_bytes += plane.pending.size() + plane.exact_whole_bytes.size()
		for tile: PackedByteArray in plane.bytes:
			cpu_bytes += tile.size()
	last_update["retained_cpu_picture_bytes"] = cpu_bytes


func _submit(source: Image, destinations: Array[MaterialPlane],
		coverage: PackedByteArray = PackedByteArray(), base: MaterialPlane = null) -> bool:
	var started: int = Time.get_ticks_usec()
	last_update = {"mode":"blit", "candidate_tiles":0, "updated_tiles":0,
		"submitted_bytes":0, "atlas_capacity":0, "staging_width":0, "staging_height":0, "atlas_assembly_usec":0,
		"staging_upload_usec":0, "gpu_blit_submit_usec":0, "gpu_blit_calls":0,
		"blit_pixels":0, "estimated_target_write_bytes":0, "allocated_gpu_bytes":gpu_storage_bytes(),
		"retirement_blit_calls":0, "estimated_retirement_write_bytes":0,
		"staging_slot":-1, "staging_resource_rid":0,
		"copy_destinations":0, "copy_run_count":0, "uncoalesced_gpu_blit_calls":0,
		"coalesced_gpu_blit_calls_saved":0, "uncoalesced_blit_pixels":0}
	if not _valid_source(source) or not _valid_state() or destinations.is_empty(): return false
	for plane: MaterialPlane in destinations:
		if plane not in [current,previous]: return false
	last_update.copy_destinations = destinations.size()
	var pending: PackedByteArray = coverage if base != null else destinations[0].pending
	if base != null and (base != current or destinations != [previous] or pending.size() != columns*rows):
		return false
	var pending_count: int = pending.count(1)
	last_update["history_copy"] = base != null
	# The entire large plane is dirty. It is cheaper to transfer the immutable
	# frame directly than to allocate and compare each staging tile first.
	var direct_whole: bool = pending_count >= 128 and pending_count == columns*rows
	last_update["direct_whole"] = direct_whole
	var changed := PackedInt32Array()
	var images: Array[Image] = []
	var bytes: Array[PackedByteArray] = []
	for index: int in range(0 if direct_whole else columns*rows):
		if pending[index] == 0: continue
		last_update.candidate_tiles += 1
		var image: Image = _tile(source,index)
		if image == null or image.get_size() != Vector2i(tile_side,tile_side) \
				or image.get_format() != logical_format or image.has_mipmaps(): return false
		var tile_bytes: PackedByteArray = image.get_data()
		if tile_bytes.size() != tile_side*tile_side*channels: return false
		if base == null and tile_bytes == destinations[0].bytes[index]: continue
		changed.append(index)
		images.append(image)
		bytes.append(tile_bytes)
	if direct_whole:
		last_update.candidate_tiles = pending_count
	var already_equal: bool = direct_whole and destinations.size() == 1 \
		and source.get_data() == destinations[0].exact_whole_bytes
	if already_equal or (not direct_whole and changed.is_empty()):
		for plane: MaterialPlane in destinations: plane.pending.fill(0)
		last_update.atlas_assembly_usec = Time.get_ticks_usec()-started
		_finish_metrics()
		return true
	var capacity: int = MAX_TILES
	for candidate: int in CAPACITIES:
		if candidate >= (pending_count if direct_whole else changed.size()):
			capacity = candidate
			break
	var atlas_size: Vector2i = _capacity_extent(capacity)
	var atlas_columns: int = atlas_size.x/tile_side
	var whole: bool = direct_whole or atlas_size.x*atlas_size.y >= extent.x*extent.y
	var pool: StagingPool = full_staging if whole else (
		_history_staging.get(capacity) if base != null else staging.get(capacity)) as StagingPool
	if pool == null: return false
	var slot: int = pool.next_slot
	var resource: StagingResource = pool.resources[slot]
	var stage: Texture2DArray = resource.texture
	var stage_size: Vector2i = extent if whole else atlas_size
	if not _valid_staging_pool(pool,stage_size): return false
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
		atlas = Image.create(atlas_size.x,atlas_size.y,false,logical_format)
		for item: int in range(changed.size()):
			atlas.blit_rect(images[item],Rect2i(0,0,tile_side,tile_side),
				Vector2i((item%atlas_columns)*tile_side,(item/atlas_columns)*tile_side))
	# Each run is (first packed-atlas item, number of adjacent tiles). Merge
	# only exact horizontal adjacency in BOTH coordinate spaces. Equal tiles
	# omitted from changed, World-row wraps and atlas-row wraps break a run.
	var copy_runs: Array[Vector2i] = []
	if whole:
		copy_runs.append(Vector2i(0,pending_count if direct_whole else changed.size()))
		last_update.uncoalesced_gpu_blit_calls = destinations.size()
		last_update.uncoalesced_blit_pixels = extent.x*extent.y*destinations.size()
	else:
		for item: int in range(changed.size()):
			var index: int = changed[item]
			var position := Vector2i((index%columns)*tile_side,(index/columns)*tile_side)
			last_update.uncoalesced_blit_pixels += mini(tile_side,extent.x-position.x) \
				*mini(tile_side,extent.y-position.y)*destinations.size()
			var adjacent: bool = copy_mode == "runs" and item > 0 \
				and index == changed[item-1]+1 and index/columns == changed[item-1]/columns \
				and item/atlas_columns == (item-1)/atlas_columns
			if adjacent:
				var run: Vector2i = copy_runs[-1]
				copy_runs[-1] = Vector2i(run.x,run.y+1)
			else:
				copy_runs.append(Vector2i(item,1))
		last_update.uncoalesced_gpu_blit_calls = changed.size()*destinations.size()
	last_update.copy_run_count = copy_runs.size()
	last_update.atlas_assembly_usec = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	stage.update_layer(atlas,0)
	last_update.staging_upload_usec = Time.get_ticks_usec()-started
	var source_rids: Array[RID] = [dummy_source.get_rid()]
	started = Time.get_ticks_usec()
	if base != null:
		previous.drawable.blit_rect(Rect2i(Vector2i.ZERO,extent),base.drawable)
		last_update["history_copy_usec"] = Time.get_ticks_usec()-started
		last_update["estimated_history_read_bytes"] = extent.x*extent.y*4
	if whole:
		for plane: MaterialPlane in destinations:
			var output_rids: Array[RID] = [plane.drawable.get_rid()]
			RenderingServer.texture_drawable_blit_rect(output_rids,Rect2i(Vector2i.ZERO,extent),
				resource.material.get_rid(),Color(0,0,extent.x,extent.y),source_rids,0)
		last_update.gpu_blit_calls = destinations.size()
		last_update.blit_pixels = extent.x*extent.y*destinations.size()
	else:
		for run: Vector2i in copy_runs:
			var item: int = run.x
			var index: int = changed[item]
			var position := Vector2i((index%columns)*tile_side,(index/columns)*tile_side)
			var size := Vector2i(mini(tile_side*run.y,extent.x-position.x),mini(tile_side,extent.y-position.y))
			var source_origin := Vector2i((item%atlas_columns)*tile_side,(item/atlas_columns)*tile_side)
			for plane: MaterialPlane in destinations:
				var output_rids: Array[RID] = [plane.drawable.get_rid()]
				RenderingServer.texture_drawable_blit_rect(output_rids,Rect2i(position,size),
					resource.material.get_rid(),Color(source_origin.x,source_origin.y,size.x,size.y),source_rids,0)
				last_update.gpu_blit_calls += 1
			last_update.blit_pixels += size.x*size.y*destinations.size()
	last_update.coalesced_gpu_blit_calls_saved = last_update.uncoalesced_gpu_blit_calls-last_update.gpu_blit_calls
	if base != null:
		last_update.gpu_blit_calls += 1
		last_update.uncoalesced_gpu_blit_calls += 1
		last_update.blit_pixels += extent.x*extent.y
		last_update.uncoalesced_blit_pixels += extent.x*extent.y
	# Godot's persistent FBO retains attachments while unbound. Always detach
	# large targets by replacing its sole attachment with one owned 1x1 sink.
	# Single-target calls throughout ensure no hidden second MRT attachment.
	var sink_rids: Array[RID] = [retirement_sink.get_rid()]
	RenderingServer.texture_drawable_blit_rect(sink_rids,Rect2i(0,0,1,1),
		resource.material.get_rid(),Color(0,0,1,1),source_rids,0)
	last_update.retirement_blit_calls = 1
	last_update.estimated_retirement_write_bytes = 4
	last_update.gpu_blit_submit_usec = Time.get_ticks_usec()-started
	for plane: MaterialPlane in destinations:
		if direct_whole:
			plane.exact_whole_bytes = atlas.get_data()
			plane.bytes.fill(PackedByteArray())
		else:
			plane.exact_whole_bytes = PackedByteArray()
			if base != null:
				plane.bytes = base.bytes.duplicate()
			for item: int in range(changed.size()): plane.bytes[changed[item]] = bytes[item]
		plane.pending.fill(0)
	last_update.updated_tiles = pending_count if direct_whole else changed.size()
	last_update.submitted_bytes = stage_size.x*stage_size.y*channels
	last_update.estimated_target_write_bytes = 4*last_update.blit_pixels
	last_update.whole_gpu_copy = whole
	last_update.atlas_capacity = capacity
	last_update.staging_width = stage_size.x
	last_update.staging_height = stage_size.y
	last_update.staging_slot = slot
	last_update.staging_resource_rid = stage.get_rid().get_id()
	last_update["history_staging"] = base != null and not whole
	# Rotate only after upload, all copies and retirement have been submitted.
	# Byte-identical and rejected publications never consume a staging slot.
	pool.next_slot = (slot+1)%staging_slots
	_finish_metrics()
	return true


func resource_identity() -> Array[int]:
	var ids: Array[int] = [current.get_rid().get_id(),previous.get_rid().get_id()]
	ids.append(retirement_sink.get_rid().get_id())
	ids.append(dummy_source.get_rid().get_id())
	var pools: Array = _owned_staging_pools()
	for pool: StagingPool in pools:
		for resource: StagingResource in pool.resources:
			ids.append(resource.texture.get_rid().get_id())
	ids.sort()
	return ids


func _owned_staging_pools() -> Array:
	var pools: Array = staging.values()
	if full_staging != null and not pools.has(full_staging): pools.append(full_staging)
	pools.append_array(_history_staging.values())
	return pools


func gpu_storage_bytes() -> int:
	var bytes: int = extent.x*extent.y*4*2+5
	var pools: Array = _owned_staging_pools()
	for pool: StagingPool in pools:
		if pool != null: bytes += pool.extent.x*pool.extent.y*channels*staging_slots
	return bytes
