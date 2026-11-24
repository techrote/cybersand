extends SceneTree
## Actual Godot shader captures from independently retained native readbacks,
## plus interactive module construction through the shipped Architecture UI.
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const RenderRig=preload("res://tools/world_art_render_rig.gd")
const Setup=preload("res://scripts/workbench_setup.gd")
var checks:=0
var failures:=0
var main: Control
var wb: Control
var panel: Window
var evidence: String
var rendered: Array=[]
var ui_only:=false

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(value: bool,label: String) -> bool:
	checks+=1
	print("ARCHITECTURE_UI_CHECK " if ui_only else "ARCHITECTURE_RENDER_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
	return value

func until(test: Callable,label: String,timeout_ms:=90000) -> bool:
	var deadline:=Time.get_ticks_msec()+timeout_ms
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	return check(test.call(),label)

func installed() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty()

func full_native_extent_visible(view: Control) -> bool:
	if view.texture==null or view.size.x<=0 or view.size.y<=0: return false
	var scale: float=view.pixels_per_cell()
	var origin: Vector2=view.size*0.5-view.center*scale
	var end: Vector2=origin+Vector2(view.extent)*scale
	return scale>0 and origin.x>=-0.01 and origin.y>=-0.01 and end.x<=view.size.x+0.01 and end.y<=view.size.y+0.01

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_EVIDENCE_DIR")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://architecture-native-evidence")
	ui_only=OS.get_environment("ARCHITECTURE_UI_ONLY")=="1"
	if not ui_only:
		if not check(DisplayServer.get_name()!="headless","genuine graphical display available"): finish(); return
		var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("representatives.json")))
		if not check(document is Dictionary and document.get("examples",[]) is Array and document.examples.size()==6,"six source-bound native example records exist"): finish(); return
		var modular: Variant=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("module-compositions.json")))
		if not check(modular is Dictionary and modular.get("examples",[]) is Array and modular.examples.size()==3,"three source-bound native module composition records exist"): finish(); return
		var all_examples: Array = document.examples.duplicate()
		all_examples.append_array(modular.examples)
		var rig: SubViewport=RenderRig.new()
		root.add_child(rig)
		var first:=true
		for row: Dictionary in all_examples:
			var cells:=FileAccess.get_file_as_bytes(evidence.path_join(row.plane))
			var size:=Vector2i(int(row.extent[0]),int(row.extent[1]))
			if not check(cells.size()==size.x*size.y*2 and Compiler.digest(cells)==row.sha256,"native material custody before graphical capture "+row.id): continue
			check(row.native_records.size()==3 and row.native_records.all(func(record: Dictionary) -> bool: return record.status=="completed" and not record.native_receipts.is_empty()),"all three construction stages have actual native completion "+row.id)
			var pixels:=PackedByteArray()
			pixels.resize(cells.size())
			for offset: int in range(0,cells.size(),2): pixels[offset]=int(cells.decode_u16(offset)); pixels[offset+1]=0
			var input:=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RG8,pixels)
			var output_size:=size*2
			if first: rig.setup(input,output_size); first=false
			else: rig.replace_input(input); rig.set_resolution(output_size)
			rig.set_view(Vector2.ZERO,Vector2(size))
			rig.set_presentation(1.37,false,true)
			rig.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			await process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			rig.render_target_update_mode=SubViewport.UPDATE_DISABLED
			var image:=rig.get_texture().get_image()
			if not check(image!=null and not image.is_empty() and image.get_size()==output_size,"actual Godot shader framebuffer "+row.id): continue
			var filename: String=row.id+"-godot.png"
			check(image.save_png(evidence.path_join(filename))==OK,"saved actual rendered evidence "+row.id)
			var identity: Dictionary=rig.renderer_identity()
			identity["native_material_sha256"]=row.sha256
			identity["image_sha256"]=FileAccess.get_sha256(evidence.path_join(filename))
			identity["image"]=filename
			identity["family"]=row.family
			identity["kind"]="godot-rendered-native-material-plane"
			rendered.append(identity)
		rig.queue_free()
		await process_frame
	root.size=Vector2i(1280,900)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main=current_scene
	wb=main.shared_workbench
	if not await until(installed,"interactive ordinary Workbench ready"): finish(); return
	for field: SpinBox in wb._extent: field.value=512
	check(wb.new_canvas(),"interactive native blank admitted")
	await until(func(): return installed() and Setup.extent_of(wb.applied)==Vector2i(512,512),"interactive native blank installed")
	wb.open_architecture_lab()
	panel=wb.architecture_lab
	await process_frame
	check(panel.visible and panel.title.contains("Architecture"),"shipped Architecture window is visible")
	var initial: Dictionary=await wb.capture_batch_source(Rect2i(0,0,512,512))
	await panel.build_starter_parts()
	check(panel.library.count()>=8,"eight actual native starter parts are available through shipped UI")
	check(panel.example.item_count==9,"shipped picker exposes all six typed and three modular examples")
	for index: int in range(6,9):
		panel.example.select(index)
		panel.load_example()
		check(panel.session.plan.get("id","").begins_with("modular-") and panel.session.plan.stages.all(func(stage: Dictionary) -> bool: return not stage.modules.is_empty() and stage.operations.is_empty()),"modular picker creates pinned native parts plan "+panel.example.get_item_text(index))
	var after: Dictionary=await wb.capture_batch_source(Rect2i(0,0,512,512))
	check(initial.config.source_cells==after.config.source_cells,"private starter construction preserves every live Workbench cell")
	panel.search.text="buttressed"
	panel._refresh_modules()
	check(panel.module_ids.size()==1 and panel.module_view.extent==Vector2i(16,48) and full_native_extent_visible(panel.module_view),"new tall native module is entirely framed inside its inspector")
	panel.module_view.native_scale()
	check(absf(panel.module_view.pixels_per_cell()-1.0)<0.000001,"module inspector exposes exact one-cell-per-pixel inspection")
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true; wheel.position=panel.module_view.size*0.5
	panel.module_view._gui_input(wheel)
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_RIGHT; press.pressed=true
	panel.module_view._gui_input(press)
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(7,-5)
	panel.module_view._gui_input(motion)
	press.pressed=false
	panel.module_view._gui_input(press)
	var framing: Vector2=panel.module_view.center
	var zoom: float=panel.module_view.zoom
	panel._refresh_session()
	check(panel.module_view.center==framing and panel.module_view.zoom==zoom and framing!=Vector2(8,24),"owner wheel and pan framing survives ordinary session refresh")
	panel.module_view.fit()
	check(full_native_extent_visible(panel.module_view),"explicit Fit restores complete native module bounds after owner navigation")
	panel.search.text="return pipe"
	panel._refresh_modules()
	check(panel.module_ids.size()==1 and panel.module_ids[0]=="return-pipe","module search resolves a real harvested pipe assembly")
	check(full_native_extent_visible(panel.module_view),"new wide native module selection resets its complete framing")
	panel.area_fields[0].value=16; panel.area_fields[1].value=16
	panel.area_fields[2].value=256; panel.area_fields[3].value=160
	panel.origin_fields[0].value=24; panel.origin_fields[1].value=24
	panel.columns.value=3; panel.rows.value=2; panel.gap.value=8
	panel.transform.select(1)
	panel.palette.text='{"service":28}'
	panel.propose_placement()
	check(panel.session.stage().modules.size()==6,"UI composes six mirrored reusable native modules")
	await panel.preview_stage()
	check(not panel.session.preview.is_empty() and panel.preview_label.text.contains("ZERO-WRITE"),"interactive zero-write composition preview is explicit")
	check(panel.preview_view.extent==Vector2i(256,160) and full_native_extent_visible(panel.preview_view),"fresh wide stage preview shows the entire projected native extent")
	var original_size: Vector2i=panel.size
	panel.size=Vector2i(maxi(panel.min_size.x,original_size.x-120),maxi(panel.min_size.y,original_size.y-80))
	panel.tabs.current_tab=0
	await process_frame
	await process_frame
	var resized_module_visible:=full_native_extent_visible(panel.module_view)
	panel.tabs.current_tab=1
	await process_frame
	await process_frame
	check(full_native_extent_visible(panel.preview_view) and resized_module_visible,"fitted native module and stage bounds remain visible after window resize")
	panel.size=original_size
	await process_frame
	if not ui_only:
		await RenderingServer.frame_post_draw
		var preview_image: Image=panel.get_texture().get_image()
		check(preview_image!=null and not preview_image.is_empty() and preview_image.save_png(evidence.path_join("architecture-zero-write-preview-ui.png"))==OK,"actual fitted zero-write preview UI captured before native approval")
	await panel.approve_stage()
	await until(func(): return not panel.session.busy(),"interactive module composition retires")
	check(panel.session.stage_state()=="completed","interactive six-module composition matches authoritative native readback")
	var module_path:=evidence.path_join("identity-replay-source-module.json")
	check(panel.library.export_module("return-pipe",module_path).ok and panel.library.remove("return-pipe").ok and panel.library.import_module(module_path).ok,"actual native pipe module roundtrips through export and fresh import")
	check(not panel.library.summaries().filter(func(row: Dictionary) -> bool: return row.id=="return-pipe")[0].native_readback_verified,"imported module begins with historical provenance only")
	panel._refresh_modules()
	panel.area_fields[0].value=296; panel.area_fields[1].value=16
	panel.area_fields[2].value=160; panel.area_fields[3].value=160
	panel.origin_fields[0].value=300; panel.origin_fields[1].value=24
	panel.columns.value=1; panel.rows.value=1
	panel.transform.select(0)
	panel.palette.text="{}"
	panel.propose_placement()
	await panel.preview_stage()
	await panel.approve_stage()
	await until(func(): return not panel.session.busy(),"imported identity replay retires")
	check(panel.session.stage_state()=="completed" and panel.library.summaries().filter(func(row: Dictionary) -> bool: return row.id=="return-pipe")[0].native_readback_verified,"exact native identity replay establishes a fresh observation for the imported module")
	panel._refresh_modules()
	var inspected: Variant=JSON.parse_string(panel.inspect.text)
	check(inspected is Dictionary and inspected.get("native_readback_verified",false),"module inspector displays current-session native authority accurately")
	panel.tabs.current_tab=0
	await process_frame
	if not ui_only: await RenderingServer.frame_post_draw
	var ui: Image=panel.get_texture().get_image() if not ui_only else null
	if not ui_only: check(ui!=null and not ui.is_empty() and ui.save_png(evidence.path_join("architecture-module-library-ui.png"))==OK,"actual module library UI captured")
	panel.tabs.current_tab=1
	await process_frame
	if not ui_only: await RenderingServer.frame_post_draw
	ui=panel.get_texture().get_image() if not ui_only else null
	if not ui_only: check(ui!=null and not ui.is_empty() and ui.save_png(evidence.path_join("architecture-native-placement-ui.png"))==OK,"actual completed native return-pipe placement UI captured")
	check(panel.library.save(evidence.path_join("interactive-starter-library.json")).ok,"interactive native starter modules exported")
	check(panel.session.save_session(evidence.path_join("interactive-module-session.json")).ok,"interactive real module receipts exported")
	if not ui_only: check(rendered.size()==9,"all nine native representative Godot renders produced")
	finish()

func finish() -> void:
	if not evidence.is_empty():
		var file:=FileAccess.open(evidence.path_join("architecture-ui-manifest.json" if ui_only else "architecture-render-manifest.json"),FileAccess.WRITE)
		if file!=null:
			file.store_string(Compiler.canonical({"passed":failures==0,"checks":checks,"failures":failures,"renders":rendered,
				"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"display":DisplayServer.get_name(),"godot":Engine.get_version_info().string}))
			file.close()
	print(("ARCHITECTURE_STAGE_UI: %d checks, %d failures" if ui_only else "ARCHITECTURE_STAGE_RENDER: %d checks, %d failures") % [checks,failures])
	if is_instance_valid(main): main.queue_free(); await process_frame; await process_frame
	quit(1 if failures else 0)
