extends "res://tests/test_material_presentation_render.gd"

const Body=preload("res://scripts/workbench_canvas_body.gd")
const Overlay=preload("res://scripts/physical_actor_overlay.gd")

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Carried material test requires actual rendered pixels");quit(1);return
	palette_shader=CyberPaletteShader.for_current_renderer(load("res://shaders/material_palette.gdshader"))
	palette_lut=CyberMaterialAppearanceLut.create_texture();program_lut=CyberMaterialAppearanceLut.create_program_texture()
	Context.emit(get_script().resource_path,palette_shader)
	var body: Dictionary={"name":"carried brick","rectangles":[[1,1,28,4],[1,5,4,20],[25,5,4,20],[1,25,28,4]],"appearance":{"material":43,"origin":[55,40]}}
	var visual: Dictionary=Body.visual(body)
	var cropped: Image=visual.texture.get_image()
	var world:=Image.create(128,128,false,Image.FORMAT_RG8);world.fill(Color(0,0,0,1))
	for r: Array in body.rectangles: world.fill_rect(Rect2i(r[0]+55,r[1]+40,r[2],r[3]),Color(43.0/255,0,0,1))
	var source: Image=await _render(world,world,0,1,Vector2i(visual.source),Vector2i(visual.size),{"growth_decor":0.0})
	var viewport:=SubViewport.new();viewport.size=Vector2i(visual.size);viewport.transparent_bg=true;viewport.use_hdr_2d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var overlay:=Overlay.new();viewport.add_child(overlay)
	var material:=ShaderMaterial.new();material.shader=palette_shader
	material.set_shader_parameter("material_lut",palette_lut);material.set_shader_parameter("material_program_lut",program_lut)
	material.set_shader_parameter("presentation_time_override",0.0)
	overlay.palette_material=material
	var part: Dictionary={"actor_id":0,"shape":"material","transform":Transform2D.IDENTITY,"size":visual.size,"visual":visual}
	overlay.present([part],Vector2.ZERO,Vector2i(visual.size),Rect2(Vector2.ZERO,visual.size))
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var result: Image=viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8)
	var maximum: float=0;var occupied: int=0;var empty: int=0
	for y: int in cropped.get_height():
		for x: int in cropped.get_width():
			var colour: Color=result.get_pixel(x,y)
			if cropped.get_pixel(x,y).r>0:
				occupied+=1;var reference: Color=source.get_pixel(x,y)
				maximum=maxf(maximum,maxf(absf(colour.r-reference.r),maxf(absf(colour.g-reference.g),absf(colour.b-reference.b))))
				_expect(colour.a==1,"occupied material is opaque")
			else:
				empty+=1;_expect(colour.a==0,"hole/concavity/padding is transparent")
	_expect(maximum<=TOLERANCE,"source-anchored brick shader agrees with original world pixels")
	_expect(overlay._carried.size()==1,"one image node, independent of four collider rectangles")
	var texture_id: int=overlay._carried[0].texture.get_instance_id()
	part.transform=Transform2D(PI/2,Vector2(visual.size.x,0))
	overlay.present([part],Vector2.ZERO,Vector2i(visual.size),Rect2(Vector2.ZERO,visual.size))
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var rotated: Image=viewport.get_texture().get_image();rotated.convert(Image.FORMAT_RGBA8)
	_expect(overlay._carried[0].texture.get_instance_id()==texture_id,"rotation reuses cached texture")
	var rotated_error: float=0
	for y: int in result.get_height():
		for x: int in result.get_width():
			var a: Color=result.get_pixel(x,y);var b: Color=rotated.get_pixel(result.get_height()-1-y,x)
			rotated_error=maxf(rotated_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),maxf(absf(a.b-b.b),absf(a.a-b.a)))))
	_expect(rotated_error<=TOLERANCE,"material and holes rotate together without world-space swimming")
	Context.capture(source,"source-brick");Context.capture(result,"carried-brick");Context.capture(rotated,"rotated-brick")
	print("CARRIED_MATERIAL_RENDER ",JSON.stringify({"occupied":occupied,"empty":empty,"maximum_error":maximum,"rotation_error":rotated_error,"failures":failures}))
	viewport.queue_free();await process_frame;quit(int(failures!=0))
