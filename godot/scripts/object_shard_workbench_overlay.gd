extends Control

# Exact native material+applied pose overlay over the existing Workbench view.
# It never samples a live Rapier transform or reads worker-owned World storage.
var host: Control
var frame: Dictionary = {}
var textures: Dictionary = {}
var publication_sequence: int = -1
var _publication_identity: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true

func present(value: Dictionary) -> void:
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
		# A coalesced publication need not expose an absent/retired body between
		# two owners of the same slot. Revisions are local to the incarnation.
		var texture_identity: Array = [identity[0],identity[2],int(shard.get("session",value.get("session",-1))),id,
			int(shard.generation),int(shard.body_generation),int(shard.material_revision),
			int(shard.width),int(shard.height)]
		if previous.get("identity",[]) == texture_identity: continue
		var pixels: PackedByteArray = shard.get("rgba",PackedByteArray())
		if int(shard.width)<=0 or int(shard.height)<=0 or pixels.size()!=int(shard.width)*int(shard.height)*4:
			textures.erase(id) # Never draw a previous owner's image for invalid new storage.
			continue
		var image: Image = Image.create_from_data(int(shard.width),int(shard.height),false,Image.FORMAT_RGBA8,pixels)
		var texture: ImageTexture = previous.get("texture",null)
		if texture == null or texture.get_width() != int(shard.width) or texture.get_height() != int(shard.height):
			texture = ImageTexture.create_from_image(image)
		else:
			texture.update(image)
		textures[id] = {"texture":texture,"identity":texture_identity,"material_revision":int(shard.material_revision)}
	for id: Variant in textures.keys():
		if not retained.has(id): textures.erase(id)
	queue_redraw()

func clear() -> void:
	frame.clear()
	textures.clear()
	publication_sequence = -1
	_publication_identity.clear()
	queue_redraw()

func _draw() -> void:
	if host == null or frame.is_empty(): return
	var rect: Rect2 = host.view_content_rect()
	var scale: Vector2 = rect.size / Vector2(host.current_view_size)
	for shard: Dictionary in frame.get("shards",[]):
		var id: int = int(shard.id)
		if not shard.get("owns_inventory",false) or not textures.has(id): continue
		var origin := Vector2(float(shard.position_x),float(shard.position_y))
		var transform := Transform2D(float(shard.rotation),origin)
		var camera := Transform2D(0.0,scale,0.0,rect.position-Vector2(host.camera_origin.floor())*scale)
		draw_set_transform_matrix(camera*transform)
		draw_texture(textures[id].texture,Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
