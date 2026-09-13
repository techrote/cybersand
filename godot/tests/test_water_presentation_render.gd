extends SceneTree

const WORLD_SIDE: int=4
const TARGET:=Vector2i(1,1)
var failures: int=0

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures+=1
	push_error(message)

func _world_texture(with_water: bool, oriented: bool) -> ImageTexture:
	var image:=Image.create_empty(WORLD_SIDE,WORLD_SIDE,false,Image.FORMAT_RG8)
	image.fill(Color(0,0,0,1))
	if with_water:
		image.set_pixel(TARGET.x,TARGET.y,Color(3.0/255.0,64.0/255.0,0,1))
		if oriented:
			image.set_pixel(TARGET.x+1,TARGET.y,Color(3.0/255.0,1.0,0,1))
	return ImageTexture.create_from_image(image)

func _render(with_water: bool, mode: int, scale: int, oriented: bool) -> Image:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(WORLD_SIDE*scale,WORLD_SIDE*scale)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var texture:=_world_texture(with_water,oriented)
	var rect:=TextureRect.new()
	rect.size=Vector2(viewport.size)
	rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode=TextureRect.STRETCH_SCALE
	rect.texture=texture
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/material_palette.gdshader")
	material.set_shader_parameter("world_size_px",Vector2(WORLD_SIDE,WORLD_SIDE))
	material.set_shader_parameter("view_size_px",Vector2(WORLD_SIDE,WORLD_SIDE))
	material.set_shader_parameter("view_rect_uv",Vector4(0,0,1,1))
	material.set_shader_parameter("camera_origin_px",Vector2.ZERO)
	material.set_shader_parameter("player_origin_px",Vector2(-100,-100))
	material.set_shader_parameter("condition_projection_enabled",1.0)
	material.set_shader_parameter("water_presentation_mode",float(mode))
	material.set_shader_parameter("snapshot_blend",1.0)
	material.set_shader_parameter("current_world_texture",texture)
	material.set_shader_parameter("previous_world_texture",texture)
	material.set_shader_parameter("material_lut",CyberMaterialAppearanceLut.create_texture())
	material.set_shader_parameter("material_program_lut",CyberMaterialAppearanceLut.create_program_texture())
	material.set_shader_parameter("material_lut_size",Vector2(
		CyberMaterialAppearanceLut.ATLAS_WIDTH,CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	rect.material=material
	viewport.add_child(rect)
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Image=viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return result

func _changed_in_target(baseline: Image, rendered: Image, scale: int) -> Array[Vector2i]:
	var changed: Array[Vector2i]=[]
	for y: int in range(TARGET.y*scale,(TARGET.y+1)*scale):
		for x: int in range(TARGET.x*scale,(TARGET.x+1)*scale):
			var before: Color=baseline.get_pixel(x,y)
			var after: Color=rendered.get_pixel(x,y)
			if (absf(before.r-after.r)+absf(before.g-after.g)
				+absf(before.b-after.b)+absf(before.a-after.a))>0.02:
				changed.append(Vector2i(x-TARGET.x*scale,y-TARGET.y*scale))
	return changed

func _run() -> void:
	# A headless DisplayServer does not submit frames, so frame_post_draw never
	# fires. The actual-pixel oracle is exercised by the retained GPU walkthrough;
	# headless CI keeps the shader/model coverage in test_water_presentation_model.
	if DisplayServer.get_name()=="headless":
		print("WATER_PRESENTATION_RENDER: skipped (headless DisplayServer has no frame submission)")
		quit(0)
		return

	var baseline_2: Image=await _render(false,1,2,false)
	var coverage_2: Image=await _render(true,1,2,false)
	var coverage_pixels_2: Array[Vector2i]=_changed_in_target(baseline_2,coverage_2,2)
	_expect(coverage_pixels_2.size()==2,"half-full Water did not render two 2x samples")
	_expect(Vector2i(0,1) in coverage_pixels_2 and Vector2i(1,1) in coverage_pixels_2,
		"coverage mask was not world-anchored to the registered lower pair")

	var baseline_4: Image=await _render(false,1,4,false)
	var coverage_4: Image=await _render(true,1,4,false)
	var coverage_pixels_4: Array[Vector2i]=_changed_in_target(baseline_4,coverage_4,4)
	_expect(coverage_pixels_4.size()==8,"4x scale changed the registered half coverage")

	var oriented_2: Image=await _render(true,2,2,true)
	var oriented_pixels: Array[Vector2i]=_changed_in_target(baseline_2,oriented_2,2)
	_expect(oriented_pixels.size()==2,"oriented half-full Water lost coverage")
	_expect(Vector2i(1,0) in oriented_pixels and Vector2i(1,1) in oriented_pixels,
		"oriented mask did not face the fuller right neighbour")

	if failures==0:
		print("WATER_PRESENTATION_RENDER: actual pixels coverage=2/4 at 2x, 8/16 at 4x; oriented right edge passed")
	quit(failures)
