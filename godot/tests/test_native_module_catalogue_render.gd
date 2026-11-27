extends SceneTree
## Actual material-shader gallery from native catalogue observations. No World
## owner or generation occurs here; connectors are labelled authored overlays.
const Module=preload("res://scripts/batch_lab/native_module.gd")
const RenderRig=preload("res://tools/world_art_render_rig.gd")
var checks:=0
var failures: Array[String]=[]
var evidence:=""
var output:=""
var source:=""
var native_source:=""
var observed: Array=[]
var rendered: Array=[]
var gallery_cards: Array=[]
var validation_only:=false
var archival:=false

class ConnectorOverlay extends Control:
	var document: Dictionary={}
	var native_size:=Vector2i.ONE
	func _draw() -> void:
		if document.is_empty(): return
		var scale:=minf(size.x/native_size.x,size.y/native_size.y)
		var origin:=(size-Vector2(native_size)*scale)*0.5
		for connector: Dictionary in document.attachments:
			var a:=origin+(Vector2(connector.point[0],connector.point[1])+Vector2(0.5,0.5))*scale
			var raw: Array=connector.get("end",connector.point)
			var b:=origin+(Vector2(raw[0],raw[1])+Vector2(0.5,0.5))*scale
			var tint:=Color(0.25,0.9,1.0,0.95)
			if a!=b: draw_line(a,b,tint,1.5,true)
			else: draw_circle(a,3.0,tint)
			var middle:=(a+b)*0.5
			var normal:=Vector2(connector.facing[0],connector.facing[1])
			draw_line(middle,middle+normal*8.0,tint,1.5,true)

func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); push_error(label)
	print("NATIVE_CATALOGUE_RENDER_CHECK ",label," ",value)
	return value

func _initialize() -> void:
	run.call_deferred()

func _label(parent: Node,text: String,position: Vector2,size: Vector2,font_size: int,color:=Color.WHITE) -> Label:
	var label:=Label.new(); label.text=text; label.position=position; label.size=size
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.clip_text=true; parent.add_child(label); return label

func _save_json(path: String,value: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: check(false,"save rendered identity "+path); return
	file.store_buffer(Module.json_bytes(value)); file.close()

func run() -> void:
	evidence=OS.get_environment("NATIVE_CATALOGUE_EVIDENCE_DIR")
	output=OS.get_environment("NATIVE_CATALOGUE_RENDER_DIR")
	if output.is_empty(): output=evidence.path_join("rendered")
	source=OS.get_environment("CYBERSAND_SOURCE_REVISION")
	validation_only=OS.get_environment("NATIVE_CATALOGUE_RENDER_VALIDATE_ONLY")=="1"
	archival=OS.get_environment("NATIVE_CATALOGUE_RENDER_ALLOW_ARCHIVAL")=="1"
	if not check(not evidence.is_empty() and source.length()==40 and Module._hex(source+"0".repeat(24)),"exact render source and existing native evidence directory"): finish(); return
	DirAccess.make_dir_recursive_absolute(output)
	var report: Variant=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("native-catalogue-report.json")))
	if not check(report is Dictionary and report.get("passed",false) and report.get("modules",[]).size()==40 and report.get("observations",[]).size()==100,"complete forty-part native catalogue evidence"): finish(); return
	native_source=str(report.source_revision)
	if not check(native_source==source or archival,"native/render exact source match or explicit archival-development label"): finish(); return
	var source_rows: Dictionary={}
	for row: Dictionary in report.observations:
		if row.phase=="source": source_rows[row.id]=row
	var seen: Dictionary={}
	for summary: Dictionary in report.modules:
		var path:=evidence.path_join("modules").path_join(str(summary.id)+".json")
		var module: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not check(module is Dictionary,"module JSON exists "+str(summary.id)): continue
		var validated:=Module.validate(module)
		if not check(validated.ok and module.content_sha256==summary.content_sha256 and not seen.has(module.id),"validated exact distinct native module "+str(summary.id)): continue
		seen[module.id]=true
		if not check(source_rows.has(module.id),"source construction record exists "+str(module.id)): continue
		var row: Dictionary=source_rows[module.id]
		var record_name: String="observations/"+str(module.id)+"-source-identity.json"
		if not check(row.record_path==record_name and row.status=="completed" and row.source_revision==native_source and FileAccess.get_sha256(evidence.path_join(record_name))==row.record_sha256,"original native source record custody "+str(module.id)): continue
		var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join(record_name)))
		var raw:=Marshalls.base64_to_raw(str(record.get("material_cells_base64","")))
		var crop: Dictionary=module.provenance.harvest
		var source_size:=Vector2i(int(crop.source_extent[0]),int(crop.source_extent[1]))
		var region:=Module.rect(crop.source_region)
		var receipt_ok: bool=record.get("state")=="completed" and record.get("receipts",[]).size()>0
		for receipt: Dictionary in record.get("receipts",[]):
			if receipt.get("backend")!="CyberNativeCellWorld" or receipt.get("status")!="completed" or int(receipt.get("refused",-1))!=0: receipt_ok=false
		if not check(receipt_ok and raw.size()==source_size.x*source_size.y*2 and Module.digest(raw)==row.material_sha256 and Module.digest(raw)==crop.source_plane_sha256,"completed native receipt and complete observed source plane "+str(module.id)): continue
		var bytes:=PackedByteArray(); bytes.resize(region.get_area()*2)
		for y: int in region.size.y:
			for x: int in region.size.x: bytes.encode_u16((y*region.size.x+x)*2,raw.decode_u16(((y+region.position.y)*source_size.x+x+region.position.x)*2))
		var separate:=FileAccess.get_file_as_bytes(evidence.path_join("planes").path_join(str(module.id)+".u16le"))
		if not check(bytes==validated.cells and bytes==separate and Module.digest(bytes)==crop.crop_sha256,"every source crop cell matches exported observed geometry "+str(module.id)): continue
		observed.append({"module":module,"cells":bytes,"extent":region.size,"record_sha256":row.record_sha256,
			"native_binary_sha256":row.native_binary_sha256,"source_observation_sha256":row.material_sha256})
	check(observed.size()==40,"all forty native module crops retained")
	if validation_only: finish(); return
	if not check(DisplayServer.get_name()!="headless","genuine graphical display for native material shader"): finish(); return
	var rig: SubViewport=RenderRig.new(); root.add_child(rig); var first:=true
	for item: Dictionary in observed:
		var size: Vector2i=item.extent; var pixels:=PackedByteArray(); pixels.resize(item.cells.size())
		var supported:=true
		for offset: int in range(0,item.cells.size(),2):
			var identity: int=item.cells.decode_u16(offset)
			if identity>255: supported=false; break
			pixels[offset]=identity; pixels[offset+1]=0
		if not check(supported,"observed materials fit existing shader input "+str(item.module.id)): continue
		var input:=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RG8,pixels)
		if first: rig.setup(input,size*3); first=false
		else: rig.replace_input(input); rig.set_resolution(size*3)
		rig.set_view(Vector2.ZERO,Vector2(size)); rig.set_presentation(1.37,false,true)
		rig.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await process_frame; await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
		rig.render_target_update_mode=SubViewport.UPDATE_DISABLED
		var picture:=rig.get_texture().get_image()
		if not check(picture!=null and not picture.is_empty() and picture.get_size()==size*3,"actual native shader framebuffer "+str(item.module.id)): continue
		var filename: String=str(item.module.id)+"-godot.png"
		check(picture.save_png(output.path_join(filename))==OK,"save actual part shader image "+str(item.module.id))
		var identity: Dictionary=rig.renderer_identity()
		identity.merge({"id":item.module.id,"module_sha256":item.module.content_sha256,"native_geometry_sha256":Module.digest(item.cells),
			"native_record_sha256":item.record_sha256,"native_binary_sha256":item.native_binary_sha256,
			"native_source_revision":native_source,"render_source_revision":source,"extent":[size.x,size.y],
			"image":filename,"image_sha256":FileAccess.get_sha256(output.path_join(filename)),"kind":"godot-rendered-native-material-plane"})
		rendered.append(identity); gallery_cards.append({"module":item.module,"image":picture,"extent":size})
	rig.queue_free(); await process_frame
	if check(gallery_cards.size()==40,"forty actual shader cards available"): await gallery()
	finish()

func gallery() -> void:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(1600,1840); viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var backdrop:=ColorRect.new(); backdrop.color=Color(0.025,0.035,0.055); backdrop.size=Vector2(viewport.size); viewport.add_child(backdrop)
	_label(viewport,"NATIVE ARCHITECTURAL PARTS · 40 DISTINCT SOURCES",Vector2(20,12),Vector2(1560,28),22)
	_label(viewport,"Actual Godot material shader • Cyan: authored contact spans and outward faces • No simulation or physical support claim",Vector2(20,42),Vector2(1560,24),15,Color(0.65,0.77,0.85))
	for index: int in gallery_cards.size():
		var item: Dictionary=gallery_cards[index]; var left: int=(index%5)*320; var top: int=80+(index/5)*220
		var card:=Control.new(); card.position=Vector2(left+8,top); card.size=Vector2(304,212); viewport.add_child(card)
		var background:=ColorRect.new(); background.size=card.size; background.color=Color(0.05,0.065,0.09); card.add_child(background)
		_label(card,str(item.module.name),Vector2(10,6),Vector2(284,22),14)
		_label(card,str(item.module.id),Vector2(10,28),Vector2(284,18),11,Color(0.6,0.7,0.78))
		var texture:=TextureRect.new(); texture.position=Vector2(12,52); texture.size=Vector2(280,132)
		texture.texture=ImageTexture.create_from_image(item.image); texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; card.add_child(texture)
		var overlay:=ConnectorOverlay.new(); overlay.document=item.module; overlay.native_size=item.extent
		overlay.position=texture.position; overlay.size=texture.size; card.add_child(overlay)
		var capacity:=0
		for connector: Dictionary in item.module.attachments: capacity+=int(connector.get("capacity",0))
		_label(card,"%d×%d cells · %d ports · %s" % [item.extent.x,item.extent.y,item.module.attachments.size(),"v2 capacity "+str(capacity) if item.module.format==Module.FORMAT_V2 else "legacy semantics"],Vector2(10,190),Vector2(284,18),12,Color(0.65,0.8,0.86))
	await process_frame; await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var picture:=viewport.get_texture().get_image()
	if check(picture!=null and picture.get_size()==viewport.size,"actual Godot authored-contact overview framebuffer"):
		check(picture.save_png(output.path_join("native-parts-contact-gallery.png"))==OK,"save contact gallery")
	viewport.queue_free(); await process_frame

func finish() -> void:
	var result:={"format":"cybersand-native-catalogue-render-v1","passed":failures.is_empty(),"checks":checks,"failures":failures,
		"native_source_revision":native_source,"render_source_revision":source,"same_source":native_source==source,
		"archival_development_requested":archival,"validation_only":validation_only,"native_modules_checked":observed.size(),"rendered":rendered,
		"scope":"Custody-only validation; no graphical qualification." if validation_only else "Actual Godot material shader observations. Cyan gallery overlay is authored connector metadata, not native painted cells or physical support."}
	if not output.is_empty():
		var path:=output.path_join("native-parts-contact-gallery.png")
		if FileAccess.file_exists(path): result["gallery_sha256"]=FileAccess.get_sha256(path)
		_save_json(output.path_join("catalogue-render-validation.json" if validation_only else "catalogue-render-report.json"),result)
	print("NATIVE_CATALOGUE_RENDER_PREFLIGHT_RESULT " if validation_only else "NATIVE_CATALOGUE_RENDER_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"observed":observed.size(),"rendered":rendered.size()}))
	quit(0 if failures.is_empty() else 1)
