extends "res://tests/test_architecture_flagships_render.gd"
## Render only independently retained actual native readback planes.
func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_HIERARCHY_DIR")
	if evidence.is_empty():evidence=ProjectSettings.globalize_path("user://architecture/hierarchy")
	if not check(DisplayServer.get_name()!="headless","actual graphical display required"):finish();return
	var document: Variant=parsed(evidence.path_join("hierarchy-native.json"))
	if not check(document is Dictionary and document.get("failures",1)==0 and document.get("source_revision")==OS.get_environment("CYBERSAND_SOURCE_REVISION"),"exact-source actual hierarchy witness"):finish();return
	native_source=document.source_revision
	var prior: Dictionary=document.result
	var rig: SubViewport=RenderRig.new();root.add_child(rig)
	var first:=true
	for view: Dictionary in [{"id":"recovered-workshop","plane":prior.plane,"sha256":prior.plane_sha256,"region":[0,0,512,512]},
		{"id":"delegated-detail","plane":prior.plane,"sha256":prior.plane_sha256,"region":[0,320,512,192]},
		{"id":"stopped-prefix","plane":prior.stopped_plane,"sha256":prior.stopped_plane_sha256,"region":[0,0,512,512]}]:
		var bytes:=FileAccess.get_file_as_bytes(evidence.path_join(view.plane))
		if not check(bytes.size()==512*512*2 and Compiler.digest(bytes)==view.sha256,"exact actual native bytes "+view.id):continue
		var pixels:=PackedByteArray();pixels.resize(bytes.size());var supported:=true
		for offset: int in range(0,bytes.size(),2):
			var material:=bytes.decode_u16(offset)
			if material>255:supported=false
			pixels[offset]=material;pixels[offset+1]=0
		if not check(supported,"lossless material texture identities "+view.id):continue
		var input:=Image.create_from_data(512,512,false,Image.FORMAT_RG8,pixels)
		var region:=Compiler.rect(view.region)
		if first:rig.setup(input,region.size);first=false
		else:rig.replace_input(input);rig.set_resolution(region.size)
		rig.set_view(Vector2(region.position),Vector2(region.size));rig.set_presentation(1.37,false,true)
		rig.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await process_frame;await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
		rig.render_target_update_mode=SubViewport.UPDATE_DISABLED
		var frame:=rig.get_texture().get_image()
		if not check(frame!=null and not frame.is_empty() and frame.get_size()==region.size,"actual Godot frame "+view.id):continue
		var name_text: String=view.id+"-godot.png"
		if not check(frame.save_png(evidence.path_join(name_text))==OK,"retain unretouched framebuffer "+view.id):continue
		var row: Dictionary=rig.renderer_identity()
		row.merge({"id":view.id,"region":view.region,"image":name_text,"image_sha256":FileAccess.get_sha256(evidence.path_join(name_text)),
			"native_material_sha256":view.sha256,"native_source_revision":native_source,"kind":"godot-rendered-native-material-plane"})
		renders.append(row)
	check(renders.size()==3,"final World delegated detail and actual stopped prefix rendered")
	rig.queue_free();await process_frame;finish()

func finish() -> void:
	var file:=FileAccess.open(evidence.path_join("hierarchy-render.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(Compiler.canonical({"format":"cybersand-native-hierarchy-renders-v1","checks":checks,"failures":failures,"passed":failures==0,
			"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"native_source_revision":native_source,"renders":renders,
			"godot":Engine.get_version_info().string,"display":DisplayServer.get_name()}));file.close()
	print("ARCHITECTURE_HIERARCHY_RENDER: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
