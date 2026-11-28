extends Control

# Exact native material+applied pose overlay over the existing Workbench view.
# It never samples a live Rapier transform or reads worker-owned World storage.
const Palette = preload("res://scripts/palette_shader_selector.gd")
const Appearance = preload("res://scripts/material_appearance_lut.gd")
const PALETTE_SOURCE = preload("res://shaders/material_palette.gdshader")
const BODY_DEFINE: String = "#define CYBER_OBJECT_SHARD\n"
static var _body_shader: Shader
static var _fallback_lut: ImageTexture
static var _fallback_program: ImageTexture
static var _material_preparation: Dictionary = {"state":"unrequested","rendered":false,"runs":0,
	"scope":"opt-in process-local shared shader preparation; no native owner, body or simulation clock"}
var host: Control
var frame: Dictionary = {}
var textures: Dictionary = {}
var publication_sequence: int = -1
var _publication_identity: Array = []
var _view_identity: Array = []
var _appearance_identity: Array = []
var _content: Control
var _canvas: Node2D
var view_updates: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	# Follow the ordinary host's final shader uniforms, including while its
	# structural runtime is Held and deliberately no longer pumps receipts.
	process_priority = 1000
	_ensure_canvas()

func _ensure_canvas() -> void:
	if _content != null: return
	_content = Control.new()
	_content.name = "MaterialContentClip"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.clip_contents = true
	add_child(_content)
	_canvas = Node2D.new()
	_content.add_child(_canvas)

static func body_shader() -> Shader:
	# One program for all bodies. Keep the same material finish functions as
	# terrain, with no temporal old-pose blend or ordinary actor decorations.
	var code: String = BODY_DEFINE + Palette.BOUNDED_CROSSFADE_DEFINE + PALETTE_SOURCE.code
	if _body_shader == null or _body_shader.code != code:
		_body_shader = Shader.new()
		_body_shader.code = code
	return _body_shader

static func material_preparation_ready() -> bool:
	return _material_preparation.state in ["ready","headless"]

static func material_preparation_observation() -> Dictionary:
	return _material_preparation.duplicate(true)

static func request_material_preparation(tree: SceneTree) -> void:
	if _material_preparation.state != "unrequested": return
	if DisplayServer.get_name() == "headless":
		_material_preparation.state = "headless"
		_material_preparation.scope = "headless admission only; no shader draw or compilation qualification"
		return
	if tree == null:
		_material_preparation.state = "failed"
		_material_preparation.reason = "Rendered material preparation requires an active SceneTree"
		return
	_material_preparation.state = "preparing"
	_material_preparation.runs = 1
	_material_preparation.started_usec = Time.get_ticks_usec()
	_prepare_materials.call_deferred(tree)

static func _prepare_materials(tree: SceneTree) -> void:
	# Publish a normal UI frame containing the preparation status before asking
	# the renderer to compile the additional material programme. The temporary
	# viewport belongs to SceneTree, so an authored scene replacement cannot
	# cancel the process-shared preparation or leave a stale owner reference.
	await tree.process_frame
	await RenderingServer.frame_post_draw
	_material_preparation.status_frame_completed = true
	_material_preparation.before_draw_usec = Time.get_ticks_usec()-int(_material_preparation.started_usec)
	var view := SubViewport.new()
	view.name = "ObjectShardMaterialPreparation"
	# Godot render targets normalize each dimension to at least two pixels.
	# Keep the two material witnesses on the first row of a supported target.
	view.size = Vector2i(2,2)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	tree.root.add_child(view)
	# Wood positively proves shader execution; Empty proves transparency. An
	# untouched transparent render target cannot satisfy the occupied pixel.
	# This viewport is never presented on the main canvas.
	var texture: ImageTexture = ImageTexture.create_from_image(Image.create_from_data(2,1,false,Image.FORMAT_RG8,PackedByteArray([7,0,0,0])))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = body_shader()
	material.set_shader_parameter("world_size_px",Vector2(2,1))
	material.set_shader_parameter("view_size_px",Vector2(2,1))
	material.set_shader_parameter("current_world_texture",texture)
	material.set_shader_parameter("previous_world_texture",texture)
	material.set_shader_parameter("condition_projection_enabled",1.0)
	material.set_shader_parameter("growth_decor",0.0)
	if _fallback_lut == null: _fallback_lut = Appearance.create_texture()
	if _fallback_program == null: _fallback_program = Appearance.create_program_texture()
	_apply_appearance(material,[_fallback_lut,_fallback_program,1.0,-1.0])
	sprite.material = material
	view.add_child(sprite)
	var draw_started: int = Time.get_ticks_usec()
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	_material_preparation.first_draw_usec = Time.get_ticks_usec()-draw_started
	_material_preparation.shader_instance_id = material.shader.get_instance_id()
	_material_preparation.target_size = view.size
	_material_preparation.image_size = image.get_size() if image != null else Vector2i.ZERO
	_material_preparation.rendered = image != null and image.get_size()==Vector2i(2,2) \
		and image.get_pixel(0,0).a>.99 and image.get_pixel(0,0).g>1.0/255.0 and image.get_pixel(1,0).a<=1.0/255.0
	if image != null and image.get_size()==Vector2i(2,2):
		var occupied: Color = image.get_pixel(0,0)
		_material_preparation.occupied_rgba = [occupied.r,occupied.g,occupied.b,occupied.a]
		_material_preparation.empty_alpha = image.get_pixel(1,0).a
	view.queue_free()
	await tree.process_frame
	_material_preparation.temporary_viewport_retired = not is_instance_valid(view)
	_material_preparation.elapsed_usec = Time.get_ticks_usec()-int(_material_preparation.started_usec)
	_material_preparation.state = "ready" if _material_preparation.rendered and _material_preparation.temporary_viewport_retired else "failed"

func _process(_delta: float) -> void:
	_sync_view()
	_sync_appearance()

func _sync_view() -> void:
	if host == null or not is_instance_valid(host) or _content == null: return
	var rect: Rect2 = host.view_content_rect()
	var origin: Vector2 = host.camera_origin.floor()
	var extent: Vector2 = Vector2(host.current_view_size)
	# These are the actual camera uniforms displayed by the ordinary terrain.
	# A control can request a view late in a frame; showing that request before
	# terrain has adopted it would produce a one-draw structural displacement.
	if host.get("world_shader") is ShaderMaterial and host.get("world_view") is Control:
		var material: ShaderMaterial = host.world_shader
		var shader_origin: Variant = material.get_shader_parameter("camera_origin_px")
		var shader_extent: Variant = material.get_shader_parameter("view_size_px")
		var shader_rect: Variant = material.get_shader_parameter("view_rect_uv")
		if shader_origin is Vector2 and shader_extent is Vector2 and shader_rect is Vector4:
			origin = shader_origin
			extent = shader_extent
			var view_size: Vector2 = host.world_view.size
			rect = Rect2(Vector2(shader_rect.x,shader_rect.y)*view_size,
				Vector2(shader_rect.z,shader_rect.w)*view_size)
	if extent.x <= 0.0 or extent.y <= 0.0 or not rect.has_area():
		_content.hide()
		return
	_content.show()
	var identity: Array = [origin,extent,rect]
	if identity == _view_identity: return
	_view_identity = identity
	_content.position = rect.position
	_content.size = rect.size
	var scale: Vector2 = rect.size/extent
	_canvas.transform = Transform2D(0.0,scale,0.0,-origin*scale)
	view_updates += 1

func _appearance_values() -> Array:
	if host != null and host.get("world_shader") is ShaderMaterial:
		var material: ShaderMaterial = host.world_shader
		return [material.get_shader_parameter("material_lut"),
			material.get_shader_parameter("material_program_lut"),
			material.get_shader_parameter("structured_detail"),
			material.get_shader_parameter("presentation_time_override")]
	if _fallback_lut == null: _fallback_lut = Appearance.create_texture()
	if _fallback_program == null: _fallback_program = Appearance.create_program_texture()
	return [_fallback_lut,_fallback_program,1.0,-1.0]

func _sync_appearance() -> void:
	if textures.is_empty(): return
	var values: Array = _appearance_values()
	if values == _appearance_identity: return
	_appearance_identity = values
	for entry: Dictionary in textures.values():
		_apply_appearance(entry.sprite.material,values)

static func _apply_appearance(material: Material, values: Array) -> void:
	if not material is ShaderMaterial: return
	material.set_shader_parameter("material_lut",values[0])
	material.set_shader_parameter("material_program_lut",values[1])
	material.set_shader_parameter("structured_detail",values[2] if values[2] != null else 1.0)
	material.set_shader_parameter("presentation_time_override",values[3] if values[3] != null else -1.0)

func present(value: Dictionary) -> void:
	_ensure_canvas()
	frame = value
	var identity: Array = [int(value.get("world_generation",value.get("m4_world_generation",-1))),
		int(value.get("session",-1)),int(value.get("world_incarnation",-1)),
		int(value.get("publication_sequence",-1))]
	if identity == _publication_identity: return
	_publication_identity = identity
	publication_sequence = int(value.get("publication_sequence",-1))
	var retained: Dictionary = {}
	for shard: Dictionary in frame.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		var id: int = int(shard.id)
		retained[id] = true
		var previous: Dictionary = textures.get(id,{})
		var projected: bool = shard.has("render_cells")
		# A coalesced publication need not expose an absent/retired body between
		# two owners of the same slot. Revisions are local to the incarnation.
		var texture_identity: Array = [identity[0],identity[2],int(shard.get("session",value.get("session",-1))),id,
			int(shard.generation),int(shard.body_generation),int(shard.material_revision),
			int(shard.width),int(shard.height),projected]
		if previous.get("identity",[]) != texture_identity:
			var pixels: PackedByteArray = shard.get("render_cells" if projected else "rgba",PackedByteArray())
			if int(shard.width)<=0 or int(shard.height)<=0 or pixels.size()!=int(shard.width)*int(shard.height)*(2 if projected else 4):
				_erase_texture(id) # Never draw a previous owner's image for invalid new storage.
				continue
			var image: Image = Image.create_from_data(int(shard.width),int(shard.height),false,
				Image.FORMAT_RG8 if projected else Image.FORMAT_RGBA8,pixels)
			var texture: ImageTexture = previous.get("texture",null)
			if texture == null or texture.get_width() != int(shard.width) or texture.get_height() != int(shard.height) \
				or previous.get("projected",false) != projected:
				texture = ImageTexture.create_from_image(image)
			else:
				texture.update(image)
			var sprite: Sprite2D = previous.get("sprite",null)
			if sprite == null:
				sprite = Sprite2D.new()
				sprite.centered = false
				_canvas.add_child(sprite)
			sprite.texture = texture
			if projected:
				var material: ShaderMaterial = sprite.material as ShaderMaterial
				if material == null:
					material = ShaderMaterial.new()
					material.shader = body_shader()
				var extent := Vector2(int(shard.width),int(shard.height))
				var capture_origin := Vector2(float(shard.get("origin_x",0)),float(shard.get("origin_y",0)))
				material.set_shader_parameter("world_size_px",extent)
				material.set_shader_parameter("view_size_px",extent)
				material.set_shader_parameter("camera_origin_px",capture_origin)
				material.set_shader_parameter("material_texture_origin_px",capture_origin)
				material.set_shader_parameter("current_world_texture",texture)
				material.set_shader_parameter("previous_world_texture",texture)
				material.set_shader_parameter("condition_projection_enabled",1.0)
				material.set_shader_parameter("growth_decor",0.0)
				_apply_appearance(material,_appearance_values())
				sprite.material = material
			else:
				# Retained Lab/synthetic RGBA publications remain inspectable. New
				# ordinary native snapshots always supply the projected RG8 field.
				sprite.material = null
			textures[id] = {"texture":texture,"sprite":sprite,"identity":texture_identity,
				"material_revision":int(shard.material_revision),"projected":projected}
		if textures.has(id):
			textures[id].sprite.transform = Transform2D(float(shard.get("rotation",0.0)),
				Vector2(float(shard.get("position_x",0.0)),float(shard.get("position_y",0.0))))
	for id: Variant in textures.keys():
		if not retained.has(id): _erase_texture(id)
	# IDs can grow across many fragments; renderer z-indices cannot. Stable
	# bounded ranks preserve the same highest-owner foreground picking order.
	var ordered: Array = textures.keys()
	ordered.sort()
	for index: int in ordered.size(): textures[ordered[index]].sprite.z_index = index
	_sync_view()

func _erase_texture(id: Variant) -> void:
	if textures.has(id):
		var sprite: Sprite2D = textures[id].get("sprite",null)
		if sprite != null: sprite.free()
	textures.erase(id)

func clear() -> void:
	frame.clear()
	for id: Variant in textures.keys(): _erase_texture(id)
	publication_sequence = -1
	_publication_identity.clear()
	_view_identity.clear()
	_appearance_identity.clear()
	view_updates = 0

func presentation_observation() -> Dictionary:
	return {"view":_view_identity.duplicate(),"view_updates":view_updates,
		"publication_sequence":publication_sequence,"body_count":textures.size(),
		"content_clipped":_content != null and _content.clip_contents,
		"scope":"retained acknowledged material publication under the ordinary terrain camera; no physics advancement"}
