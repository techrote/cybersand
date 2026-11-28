extends SceneTree
## Actual Godot shader framebuffers of source-bound native material readbacks.
## This test never constructs a substitute image or edits an evidence capture.
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Session=preload("res://scripts/batch_lab/architecture_stage_session.gd")
const RenderRig=preload("res://tools/world_art_render_rig.gd")
var checks:=0
var failures:=0
var evidence:=""
var renders: Array=[]
var native_source:=""

func _initialize() -> void:
	run.call_deferred()

func check(value: bool,label: String) -> bool:
	checks+=1; print("FLAGSHIP_RENDER_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
	return value

func parsed(path: String) -> Variant:
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: return null
	return parser.data

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_FLAGSHIP_DIR")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://architecture-flagships")
	if not check(DisplayServer.get_name()!="headless","actual graphical display available"): finish(); return
	var document: Variant=parsed(evidence.path_join("flagships-native.json"))
	if not check(document is Dictionary and document.get("format")=="cybersand-native-flagship-campaign-v1" and document.get("examples",[]).size()==4 and document.get("failures",1)==0,"four complete native flagship records"): finish(); return
	native_source=str(document.source_revision)
	var expected_source:=OS.get_environment("CYBERSAND_NATIVE_SOURCE_REVISION")
	if expected_source.is_empty(): expected_source=OS.get_environment("CYBERSAND_SOURCE_REVISION")
	if not check(native_source.length()==40 and native_source==expected_source,"exact declared native producer source"): finish(); return
	var rig: SubViewport=RenderRig.new(); root.add_child(rig)
	var first:=true
	for row: Dictionary in document.examples:
		var cells:=FileAccess.get_file_as_bytes(evidence.path_join(row.plane))
		var size:=Vector2i(int(row.extent[0]),int(row.extent[1]))
		if not check(size.x>=1024 and cells.size()==size.x*size.y*2 and Compiler.digest(cells)==row.sha256,"complete actual native material custody "+row.id): continue
		var retained: Variant=parsed(evidence.path_join(str(row.id)+"-session.json"))
		var receipts_valid: bool=retained is Dictionary and retained.get("records",[]).size()>=int(row.stages)
		var completed:=0; var chunks:=0; var changed:=0
		if receipts_valid:
			for record: Dictionary in retained.records:
				if record.get("kind")!="native-stage": continue
				var accounting:=Session.receipt_accounting(record.native_receipts,record.budget)
				if record.status!="completed" or not accounting.complete or record.result_sha256!=record.expected_sha256 or record.source_revision!=native_source: receipts_valid=false
				completed+=1; chunks+=record.native_receipts.size(); changed+=int(record.changed_cells)
		if not check(receipts_valid and completed==int(row.stages) and chunks==int(row.native_receipt_chunks) and changed==int(row.changed_cells),"independent native receipt totals before capture "+row.id): continue
		var pixels:=PackedByteArray(); pixels.resize(cells.size())
		var supported:=true
		for offset: int in range(0,cells.size(),2):
			var material:=cells.decode_u16(offset)
			if material>255: supported=false
			pixels[offset]=material; pixels[offset+1]=0
		if not check(supported,"exact RG8 material identities without truncation "+row.id): continue
		var input:=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RG8,pixels)
		var views: Array=[{"name":"whole","region":Rect2i(Vector2i.ZERO,size)}]
		views.append({"name":"district-upper","region":Rect2i(Vector2i(size.x/2-256,0),Vector2i(512,512))})
		views.append({"name":"district-lower","region":Rect2i(Vector2i(size.x/2-256,size.y-512),Vector2i(512,512))})
		for view: Dictionary in views:
			var region: Rect2i=view.region
			if first: rig.setup(input,region.size); first=false
			else: rig.replace_input(input); rig.set_resolution(region.size)
			rig.set_view(Vector2(region.position),Vector2(region.size))
			rig.set_presentation(1.37,false,true)
			rig.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			await process_frame; await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
			rig.render_target_update_mode=SubViewport.UPDATE_DISABLED
			var frame:=rig.get_texture().get_image()
			if not check(frame!=null and not frame.is_empty() and frame.get_size()==region.size,"native-resolution Godot framebuffer "+row.id+" "+view.name): continue
			var filename: String=str(row.id)+"-"+str(view.name)+"-godot.png"
			if not check(frame.save_png(evidence.path_join(filename))==OK,"saved unretouched native shader view "+filename): continue
			var identity: Dictionary=rig.renderer_identity()
			identity.merge({"id":row.id,"view":view.name,"region":Compiler.rect_array(region),"pixels":[frame.get_width(),frame.get_height()],
				"native_material_sha256":row.sha256,"native_source_revision":native_source,"image":filename,
				"image_sha256":FileAccess.get_sha256(evidence.path_join(filename)),"kind":"godot-rendered-native-material-plane",
				"scope":"Orthographic native material projection; static rendering does not establish physical stability, traversal or owner preference."})
			renders.append(identity)
	check(renders.size()==12,"all four whole Worlds and eight native-resolution district captures")
	rig.queue_free(); await process_frame
	finish()

func finish() -> void:
	if not evidence.is_empty():
		var file:=FileAccess.open(evidence.path_join("flagships-render.json"),FileAccess.WRITE)
		if file!=null:
			file.store_string(Compiler.canonical({"format":"cybersand-native-flagship-renders-v1","passed":failures==0,"checks":checks,"failures":failures,
				"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"native_source_revision":native_source,
				"display":DisplayServer.get_name(),"godot":Engine.get_version_info().string,"renders":renders})); file.close()
	print("ARCHITECTURE_FLAGSHIPS_RENDER: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
