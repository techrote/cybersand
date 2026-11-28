extends SceneTree

# Synthetic immutable publications isolate the renderer from native motion.
# Paired actual framebuffers compare the shared ordinary material finish against
# a detached body at the same captured coordinates, then after rotation/edit.
const Overlay = preload("res://scripts/object_shard_workbench_overlay.gd")
const Palette = preload("res://scripts/palette_shader_selector.gd")
const Appearance = preload("res://scripts/material_appearance_lut.gd")
const SIZE := Vector2i(32,32)
const ORIGIN := Vector2i(24,31)
const WORLD := Vector2i(80,80)
const SCALE: int = 4
const TOLERANCE: float = 2.0/255.0
class ViewHost extends Control:
	var world_view: Control
	var world_shader: ShaderMaterial
	var camera_origin: Vector2 = Vector2(ORIGIN)
	var current_view_size: Vector2i = SIZE
	func view_content_rect() -> Rect2:
		return Rect2(Vector2.ZERO,Vector2(SIZE*SCALE))
var checks: int = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var first_use: Dictionary = {}
var output: String = "user://objectshard-presentation"
var source: PackedByteArray
var palette: ImageTexture
var program: ImageTexture

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool,label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("M4_PRESENTATION: "+label)
	return value

func _setup_material(texture: ImageTexture) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Palette.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	material.set_shader_parameter("world_size_px",Vector2(WORLD))
	material.set_shader_parameter("view_size_px",Vector2(SIZE))
	material.set_shader_parameter("camera_origin_px",Vector2(ORIGIN))
	material.set_shader_parameter("view_rect_uv",Vector4(0,0,1,1))
	material.set_shader_parameter("current_world_texture",texture)
	material.set_shader_parameter("previous_world_texture",texture)
	material.set_shader_parameter("material_lut",palette)
	material.set_shader_parameter("material_program_lut",program)
	material.set_shader_parameter("condition_projection_enabled",1.0)
	material.set_shader_parameter("growth_decor",0.0)
	material.set_shader_parameter("presentation_time_override",0.375)
	material.set_shader_parameter("player_origin_px",Vector2(-1000,-1000))
	return material

func _viewport() -> SubViewport:
	var view := SubViewport.new()
	view.size = SIZE*SCALE
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view

func _world_texture() -> ImageTexture:
	var bytes := PackedByteArray()
	bytes.resize(WORLD.x*WORLD.y*2)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):
			var local: int = (y*SIZE.x+x)*2
			var target: int = ((ORIGIN.y+y)*WORLD.x+ORIGIN.x+x)*2
			bytes[target] = source[local]
			bytes[target+1] = source[local+1]
	return ImageTexture.create_from_image(Image.create_from_data(WORLD.x,WORLD.y,false,Image.FORMAT_RG8,bytes))

func _publication(sequence: int,rotation: float = 0.0) -> Dictionary:
	return {"world_generation":7,"world_incarnation":9,"session":11,"publication_sequence":sequence,
		"shards":[{"session":11,"id":1,"generation":1,"body_generation":1,"material_revision":sequence,
			"width":SIZE.x,"height":SIZE.y,"owns_inventory":true,"render_cells":source,
			"origin_x":ORIGIN.x,"origin_y":ORIGIN.y,"position_x":ORIGIN.x+(SIZE.y if rotation != 0.0 else 0),
			"position_y":ORIGIN.y,"rotation":rotation}]}

func _fragment_publication(sequence: int,rotation: float = 0.0) -> Dictionary:
	# Native Registry keeps the parent's storage origin and gives the child a
	# cropped origin = parent origin + local crop offset. Coordinator rotates
	# that same offset into the child's physical pose. The captured finish must
	# therefore survive both recropping and rotation without resetting its phase.
	var value: Dictionary = _publication(sequence,rotation)
	var parent: Dictionary = value.shards[0]
	var retained: PackedByteArray = source.duplicate()
	var child_pixels := PackedByteArray()
	child_pixels.resize((SIZE.x/2)*SIZE.y*2)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x/2,SIZE.x):
			var before: int = (y*SIZE.x+x)*2
			var after: int = (y*(SIZE.x/2)+x-SIZE.x/2)*2
			child_pixels[after] = source[before]
			child_pixels[after+1] = source[before+1]
			retained[before] = 0
			retained[before+1] = 0
	parent.render_cells = retained
	var child: Dictionary = parent.duplicate(true)
	child.id = 2
	child.width = SIZE.x/2
	child.origin_x = ORIGIN.x+SIZE.x/2
	child.render_cells = child_pixels
	var offset := Vector2(SIZE.x/2,0).rotated(rotation)
	child.position_x += offset.x
	child.position_y += offset.y
	value.shards.append(child)
	return value

func _capture(view: SubViewport,name: String) -> Image:
	var started: int = Time.get_ticks_usec()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	var path: String = output.path_join(name+".png")
	_check(image.save_png(path)==OK,"save actual framebuffer "+name)
	captures.append({"name":name,"sha256":FileAccess.get_sha256(path),"width":image.get_width(),"height":image.get_height(),
		"elapsed_usec":Time.get_ticks_usec()-started})
	return image

func _compare(reference: Image,actual: Image,label: String,rotated: bool = false) -> void:
	var mismatches: int = 0
	var occupied: int = 0
	var colours: Dictionary = {}
	var maximum: float = 0.0
	for y: int in range(SIZE.y*SCALE):
		for x: int in range(SIZE.x*SCALE):
			var sx: int = y if rotated else x
			var sy: int = SIZE.y*SCALE-1-x if rotated else y
			var material_id: int = int(source[((sy/SCALE)*SIZE.x+(sx/SCALE))*2])
			var a: Color = actual.get_pixel(x,y)
			if material_id == 0:
				if a.a > TOLERANCE: mismatches += 1
				continue
			var b: Color = reference.get_pixel(sx,sy)
			var residual: float = maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))
			maximum = maxf(maximum,residual)
			if residual > TOLERANCE: mismatches += 1
			occupied += 1
			colours[a.to_rgba32()] = true
	_check(occupied>10000 and colours.size()>64,label+" contains textured material pixels, not a flat fallback")
	_check(mismatches==0,label+" matches ordinary material finish and transparent holes; mismatches="+str(mismatches)+" max="+str(maximum))

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Actual material framebuffer qualification requires a graphical renderer")
		quit(1); return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	palette = Appearance.create_texture()
	program = Appearance.create_program_texture()
	source.resize(SIZE.x*SIZE.y*2)
	var ids: Array[int] = [43,7,31,62]
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):
			var at: int = (y*SIZE.x+x)*2
			source[at] = ids[(y/16)*2+(x/16)]
			source[at+1] = 130 if source[at]==7 and y>7 else 0
			if x in range(14,18) and y in range(14,18): source[at] = 0
	var started: int = Time.get_ticks_usec()
	var reference_view: SubViewport = _viewport()
	var reference_texture: ImageTexture = _world_texture()
	var reference := TextureRect.new()
	reference.size = Vector2(SIZE*SCALE)
	reference.texture = reference_texture
	reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reference.material = _setup_material(reference_texture)
	reference_view.add_child(reference)
	first_use.ordinary_setup_usec = Time.get_ticks_usec()-started
	# Draw the ordinary shader alone before creating the detached variant. The
	# separate timings include frame wait, readback and PNG I/O as well as any
	# first-use compilation; they are not per-frame cost or monitor FPS.
	var original: Image = await _capture(reference_view,"ordinary-materials")
	first_use.ordinary_first_capture_usec = captures.back().elapsed_usec
	started = Time.get_ticks_usec()
	var body_view: SubViewport = _viewport()
	var host := ViewHost.new()
	host.world_view = Control.new()
	host.world_view.size = Vector2(SIZE*SCALE)
	host.world_shader = reference.material
	body_view.add_child(host)
	host.add_child(host.world_view)
	var overlay: Control = Overlay.new()
	overlay.host = host
	overlay.size = Vector2(SIZE*SCALE)
	host.world_view.add_child(overlay)
	overlay.present(_publication(1))
	first_use.detached_setup_usec = Time.get_ticks_usec()-started
	var detached: Image = await _capture(body_view,"detached-materials")
	first_use.detached_first_capture_usec = captures.back().elapsed_usec
	_compare(original,detached,"unrotated detachment")
	_check(overlay.textures[1].projected and overlay.textures[1].texture.get_image().get_data()==source,
		"the uploaded RG8 bytes retain exact native-style material and condition channels")
	var retained_texture: ImageTexture = overlay.textures[1].texture
	var retained_material: ShaderMaterial = overlay.textures[1].sprite.material
	overlay.present(_publication(2,PI/2.0))
	var rotated: Image = await _capture(body_view,"rotated-materials")
	_compare(original,rotated,"quarter-turn capture-coordinate finish",true)
	_check(overlay.textures[1].texture==retained_texture,"same-size updates retain texture allocation")
	_check(overlay.textures[1].sprite.material==retained_material,"material revisions reuse the owner's shader material")
	var edit: int = (8*SIZE.x+8)*2
	source[edit] = 62
	overlay.present(_publication(3))
	var next_world: ImageTexture = _world_texture()
	reference.texture = next_world
	reference.material = _setup_material(next_world)
	host.world_shader = reference.material
	var edited_reference: Image = await _capture(reference_view,"ordinary-edited")
	var edited_body: Image = await _capture(body_view,"detached-edited")
	_compare(edited_reference,edited_body,"moving material edit")
	# A two-cell cut opens separate islands. The right child is recropped with
	# its empty ring, while the parent's stable storage extent is unchanged.
	for y: int in range(SIZE.y):
		for x: int in [15,16]:
			source[(y*SIZE.x+x)*2] = 0
			source[(y*SIZE.x+x)*2+1] = 0
	var cut_world: ImageTexture = _world_texture()
	reference.texture = cut_world
	reference.material = _setup_material(cut_world)
	host.world_shader = reference.material
	overlay.present(_fragment_publication(4))
	var cut_reference: Image = await _capture(reference_view,"ordinary-fragment-cut")
	var cut_body: Image = await _capture(body_view,"detached-fragment-cut")
	_compare(cut_reference,cut_body,"child storage-origin recrop")
	_check(overlay.textures.size()==2 and overlay.textures[1].sprite.material==retained_material,
		"fragment admission adds one independent owner while retaining the parent's material allocation")
	overlay.present(_fragment_publication(5,PI/2.0))
	var cut_rotated: Image = await _capture(body_view,"rotated-fragment-cut")
	_compare(cut_reference,cut_rotated,"rotated child storage-origin recrop",true)
	var publication_before: int = overlay.publication_sequence
	var update_before: int = overlay.view_updates
	host.world_shader.set_shader_parameter("camera_origin_px",Vector2(ORIGIN)+Vector2(2,3))
	host.world_shader.set_shader_parameter("view_size_px",Vector2(40,32))
	host.world_shader.set_shader_parameter("view_rect_uv",Vector4(0.1,0.2,0.8,0.6))
	await _capture(body_view,"retained-camera-letterbox")
	_check(overlay.publication_sequence==publication_before and overlay.view_updates>update_before,
		"camera pan/zoom/letterbox invalidate presentation without a new material publication")
	_check(overlay._content.clip_contents and overlay._content.position.is_equal_approx(Vector2(12.8,25.6))
		and overlay._content.size.is_equal_approx(Vector2(102.4,76.8)),"material body clips to actual terrain content rectangle")
	var clipped: Image = body_view.get_texture().get_image()
	_check(clipped.get_pixel(5,5).a<TOLERANCE and clipped.get_pixel(120,120).a<TOLERANCE,
		"off-view structural pixels cannot leak into letterbox margins")
	overlay.clear()
	await _capture(body_view,"retired-clear")
	_check(overlay.textures.is_empty() and overlay._canvas.get_child_count()==0,"retirement releases every body visual")
	reference_view.queue_free(); body_view.queue_free()
	await process_frame
	print(JSON.stringify({"schema":"objectshard-m4-material-presentation-v1","checks":checks,"failures":failures,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"display_driver":DisplayServer.get_name(),
		"rendering_driver":RenderingServer.get_current_rendering_driver_name(),"captures":captures,"first_use":first_use,
		"timing_scope":"sequential ordinary-only then detached first use; setup and capture elapsed include frame wait/readback/PNG I/O; no steady-state or physical display claim",
		"scope":"synthetic immutable RG8 publications; actual ordinary/shared-shader framebuffer parity, rotation, edit, child-origin recrop, view and retirement; not native or physical-motion qualification"}))
	quit(0 if failures.is_empty() else 1)
