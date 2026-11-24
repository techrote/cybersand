extends "res://tests/test_architecture_gameplay.gd"
## Actual native Workbench interactions through the shipped UI. Headless runs
## qualify behavior only; real-display runs retain actual Window framebuffers.
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
var panel: Window
var captures: Array=[]
var catalogue_path:=""

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_COLLABORATIVE_UI_DIR")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://architecture/collaborative-ui")
	DirAccess.make_dir_recursive_absolute(evidence)
	catalogue_path=OS.get_environment("ARCHITECTURE_MODULE_CATALOGUE_DIR").path_join("curated-library-v2.json")
	if not check(FileAccess.file_exists(catalogue_path),"actual harvested catalogue export is available"): await finish(); return
	if not await start_host(): await finish(); return
	var blank:=Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
	if not check(wb.apply(blank),"ordinary blank native World admitted") or not await until(installed,"ordinary blank native World installed"): await finish(); return
	wb.open_architecture_lab(); panel=wb.architecture_lab
	await process_frame
	check(panel.visible and is_instance_valid(panel.workflow) and panel.workflow.session==panel.session,"shipped panel uses exactly one host workflow and one native session")
	check(wb.art_batches==null,"opening collaborative Architecture sends no Art request or shared lifecycle mutation")
	if not check(panel.library.load_library(catalogue_path).ok,"actual harvested forty-part library imports with exact content pins"): await finish(); return
	panel.search.clear(); panel._refresh_modules()
	for frame: int in 45: await process_frame
	check(panel.module_ids.size()==40 and panel.library.summaries().all(func(item: Dictionary) -> bool: return not item.native_readback_verified),"imported actual native geometry retains forty distinct parts and historical-only qualification")
	check(panel._thumbnail_cache.size()>=40 and panel._thumbnail_queue.is_empty(),"all forty browser thumbnails finish through bounded per-frame work")
	check(panel.example.item_count==9 and panel.flagship.item_count==4,"ordinary controls expose nine original examples and four large flagship hierarchies")
	await screenshot("collaborative-module-browser","Actual imported catalogue browser. Import does not claim current-session native replay.")
	select_module("tapered-pier")
	check(panel.module_view.extent==Vector2i(24,64) and fully_visible(panel.module_view),"tall native part and authored connector guides are fully framed")
	panel.module_view.native_scale()
	check(is_equal_approx(panel.module_view.pixels_per_cell(),1.0),"module inspector provides exact cell-scale inspection")
	var wheel:=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true; wheel.position=panel.module_view.size*0.5
	panel.module_view._gui_input(wheel)
	var down:=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_RIGHT; down.pressed=true
	panel.module_view._gui_input(down)
	var drag:=InputEventMouseMotion.new(); drag.relative=Vector2(9,-6); panel.module_view._gui_input(drag)
	down.pressed=false; panel.module_view._gui_input(down)
	var centre: Vector2=panel.module_view.center; var zoom: float=panel.module_view.zoom
	panel._refresh_session()
	check(panel.module_view.center==centre and panel.module_view.zoom==zoom,"ordinary state refresh preserves owner pan and zoom")
	panel.module_view.fit(); check(fully_visible(panel.module_view),"Fit restores complete native material bounds")
	panel.edit_semantics(); await process_frame
	check(panel.module_semantics.visible and panel.module_semantics.patch().attachments.size()==2,"friendly semantics editor exposes both authored full-span connectors")
	check(not panel.module_semantics.patch().has("geometry") and not panel.module_semantics.patch().has("provenance"),"friendly metadata draft cannot replace observed geometry or provenance")
	await screenshot("collaborative-module-semantics","Authored connector, role and region controls over immutable source geometry.",panel.module_semantics)
	panel.module_semantics.hide()
	for index: int in 4: panel.area_fields[index].value=[128,128,256,256][index]
	panel.columns.value=1; panel.rows.value=1
	panel.origin_fields[0].value=200; panel.origin_fields[1].value=250
	select_module("stepped-foundation")
	var region:=Rect2i(128,128,256,256)
	var blank_capture: Dictionary=await wb.capture_batch_source(region)
	panel.propose_placement()
	await panel.preview_stage()
	if not check(not panel.session.preview.is_empty(),"actual foundation placement receives a current native zero-write preview"): await finish(); return
	var foundation_preview: Dictionary=panel.session.preview.duplicate(true)
	var after_preview: Dictionary=await wb.capture_batch_source(region)
	check(after_preview.config.source_cells==blank_capture.config.source_cells and panel.session.records.is_empty(),"preview and all preceding browser operations leave every inspected native cell unchanged")
	await panel.approve_stage()
	if not await until(func() -> bool: return not panel.session.busy(),"foundation native receipts retire"): await finish(); return
	if not check(panel.session.stage_state()=="completed","foundation is completed only after exact native receipts and readback"): await finish(); return
	var foundation_actual: Dictionary=await wb.capture_batch_source(region)
	check(foundation_actual.config.source_cells==foundation_preview.projected_cells,"whole native region equals the exact approved foundation projection")
	check(panel.library.summaries().filter(func(item: Dictionary) -> bool: return item.id=="stepped-foundation")[0].native_readback_verified,"identity replay establishes new current-session observation for the exact imported foundation")
	select_module("tapered-pier")
	panel.origin_fields[0].value=212; panel.origin_fields[1].value=186
	for index: int in panel.source_connector.item_count:
		if panel.source_connector.get_item_metadata(index)=="foot": panel.source_connector.select(index)
	await panel.inspect_snap_targets()
	var target_index:=-1
	for index: int in panel._snap_inventory.get("targets",[]).size():
		if panel._snap_inventory.targets[index].id=="bearing": target_index=index
	if not check(target_index>=0,"actual native foundation exposes its rechecked authored bearing contact"): await finish(); return
	panel.target_connector.select(target_index)
	panel.find_snap_poses()
	var candidate_index:=-1
	for index: int in panel._snap_candidates.size():
		var candidate: Dictionary=panel._snap_candidates[index]
		if candidate.placement.origin==[212,186] and candidate.placement.transform=="identity": candidate_index=index
	if not check(candidate_index>=0,"shipped bounded snap controls find the exact opposing full-span native bearing pose"): await finish(); return
	panel.snap_list.select(candidate_index)
	check(panel._snap_candidates[candidate_index].contact.cell_count==24 and panel.snap_list.get_item_text(candidate_index).contains("24 contact cells"),"candidate exposes its complete twenty-four-cell contact span")
	var snap_unchanged: Dictionary=await wb.capture_batch_source(region)
	check(snap_unchanged.config.source_cells==foundation_actual.config.source_cells,"inspecting contacts and searching poses performs zero native writes")
	panel.tabs.current_tab=0
	await screenshot("collaborative-native-snap","Bounded pose candidates against currently inspected native foundation contacts; still proposals.")
	panel.propose_snap()
	check(panel.session.stage().module_bindings.size()==1 and panel.session.preview.is_empty(),"selected snap proposes one pinned instance and explicit binding without applying it")
	await panel.preview_stage()
	if not check(not panel.session.preview.is_empty() and panel.preview_label.text.contains("ZERO-WRITE"),"snapped stage has a current source-bound zero-write approval preview"): await finish(); return
	var pier_preview: Dictionary=panel.session.preview.duplicate(true)
	await process_frame
	check(fully_visible(panel.preview_view) and fully_visible(panel.source_view),"actual source and projected native extent both fit their separate inspection panes")
	var original_size: Vector2i=panel.size
	panel.size=Vector2i(1000,700); await process_frame; await process_frame
	check(fully_visible(panel.preview_view),"fresh fitted zero-write projection stays completely visible after resize")
	panel.size=original_size; await process_frame
	await screenshot("collaborative-zero-write-snap","Exact native contact proposal awaiting explicit approval; actual source and projection are separate.")
	await panel.approve_stage()
	if not await until(func() -> bool: return not panel.session.busy(),"snapped native placement retires"): await finish(); return
	check(panel.session.stage_state()=="completed","snapped placement completes through the ordinary native stage pathway")
	var pier_actual: Dictionary=await wb.capture_batch_source(region)
	check(pier_actual.config.source_cells==pier_preview.projected_cells,"native snapped material plane equals every approved projected cell")
	panel._refresh_session(); panel._refresh_result_views(true)
	check(panel.result_tabs.current_tab==2 and panel.native_label.text.contains("RETAINED"),"completed UI selects retained authoritative native result rather than an old approval preview")
	await screenshot("collaborative-native-result","Completed native foundation and connected pier with exact retained readback; this is a terminal result.")
	var record: Dictionary=panel.session.records.back()
	check(record.kind=="native-stage" and record.status=="completed" and not record.native_receipts.is_empty(),"native completion is backed by exact execution receipts")
	var detail: Control=panel.detail_panel
	panel.tabs.current_tab=4
	for index: int in 4:
		detail.inspection_fields[index].value=[128,128,256,256][index]
		detail.area_fields[index].value=[192,240,64,32][index]
	await detail.inspect_source()
	check(detail.instance.item_count>=3 and detail.source_label.text.contains("retained native instance"),"detail controls obtain native-completed part scopes from the single host session")
	await detail.prepare()
	if not check(not detail._job.is_empty() and detail._job.zero_writes,"friendly mounted-rib controls produce a source-grounded zero-write proposal"): await finish(); return
	var detail_before: Dictionary=await wb.capture_batch_source(region)
	check(detail_before.config.source_cells==pier_actual.config.source_cells,"detail preparation leaves every native cell unchanged")
	await screenshot("collaborative-detail-controls","Bounded geometry controls and source-grounded procedural proposal; native approval remains separate.")
	detail.review()
	check(panel.tabs.current_tab==1 and panel.session.stage().has("input_snapshot_sha256"),"detail review preserves exact source pin in the ordinary stage pathway")
	await panel.preview_stage()
	if not check(not panel.session.preview.is_empty(),"detail stage receives a fresh host-native permission and contact preview"): await finish(); return
	var detail_preview: Dictionary=panel.session.preview.duplicate(true)
	await panel.approve_stage()
	if not await until(func() -> bool: return not panel.session.busy(),"source-grounded detail native receipts retire"): await finish(); return
	check(panel.session.stage_state()=="completed","procedural detail becomes completed only through actual native receipts")
	pier_actual=await wb.capture_batch_source(region)
	check(pier_actual.config.source_cells==detail_preview.projected_cells,"every native detail cell agrees with the approved host projection")
	var pane: Control=panel.workflow_panel
	panel.tabs.current_tab=3
	pane.intent.text="An industrial assembly hall with an open central route and unequal service bays."
	for index: int in 4: pane.region_fields[index].value=[16,16,176,144][index]
	pane.family.select(1)
	await pane.propose()
	if not check(pane.options.item_count==3,"actual World inspection produces three named offline construction options"): await finish(); return
	var proposal_unchanged: Dictionary=await wb.capture_batch_source(region)
	check(proposal_unchanged.config.source_cells==pier_actual.config.source_cells,"intent discussion and alternative generation preserve all existing native construction")
	pane.options.select(1); pane.adopt(); pane.refresh()
	var plan_id: String=panel.session.plan.id
	check(not plan_id.is_empty() and panel.session.preview.is_empty() and pane.tasks.get_root().get_child_count()>0,"explicitly adopted alternative appears as a finite unapproved task tree")
	await screenshot("collaborative-intent-tasks","Deterministic proposal options and finite task hierarchy; no model call or implicit stage approval.")
	panel.tabs.current_tab=1; panel._refresh_session()
	panel.stage_intent.text="Owner revision: preserve the central route and keep the frame sparse."
	panel.revise_stage()
	check(panel.session.stage().intent==panel.stage_intent.text and panel.session.preview.is_empty(),"ordinary intent revision retires prior approval before execution")
	await panel.preview_stage()
	check(not panel.session.preview.is_empty(),"revised bounded task compiles against the actual World")
	panel.stop_all()
	check(not panel.session.busy() and panel.session.preview.is_empty() and panel.session.stage_state()=="cancelled","reachable Stop cancels reviewed work without inventing completion")
	var cancelled: Dictionary=await wb.capture_batch_source(region)
	check(cancelled.config.source_cells==pier_actual.config.source_cells,"cancelled proposal does not change previously completed native construction")
	check(is_instance_valid(wb.art_batches) and not wb.art_batches.provider.active and wb.art_batches.conversation.is_empty(),"native architecture controls preserve the Art provider and conversation namespace")
	var file:=FileAccess.open(evidence.path_join("connected-native-region.u16le"),FileAccess.WRITE)
	if file!=null: file.store_buffer(pier_actual.config.source_cells); file.close()
	check(panel.session.save_session(evidence.path_join("collaborative-session.json")).ok,"decision and native receipt history remains savable after cancellation")
	output={"format":"cybersand-collaborative-architecture-ui-v1","source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"catalogue_sha256":FileAccess.get_sha256(catalogue_path),"native_active_core_capacity":int(ProjectSettings.get_setting("cybersand/native_active_core_capacity",1024)),
		"development_memory_configuration":development_core_capacity>0,"godot":Engine.get_version_info().string,"display":DisplayServer.get_name(),
		"captures":captures,"native_region":[128,128,256,256],"native_sha256":Module.digest(pier_actual.config.source_cells),
		"native_records":panel.session.records.filter(func(value: Dictionary) -> bool: return value.kind=="native-stage"),
		"scope":"Actual shipped controls, exact native contact placement and terminal receipts. Graphical evidence exists only when a real display produced the retained Window framebuffers; no model or physical acceptance inferred."}
	await finish()

func select_module(identity: String) -> void:
	panel.search.text=identity; panel.part_filter.select(0); panel._refresh_modules()
	check(panel.module_ids.size()==1 and panel.module_ids[0]==identity,"browser resolves exact native part "+identity)

func fully_visible(view: Control) -> bool:
	if view.texture==null or view.size.x<=0 or view.size.y<=0: return false
	var scale: float=view.pixels_per_cell()
	var beginning: Vector2=view.size*0.5-view.center*scale
	var ending: Vector2=beginning+Vector2(view.extent)*scale
	return scale>0 and beginning.x>=-0.01 and beginning.y>=-0.01 and ending.x<=view.size.x+0.01 and ending.y<=view.size.y+0.01

func screenshot(identity: String,caption: String,window: Window=null) -> void:
	if DisplayServer.get_name()=="headless": return
	var target: Window=panel if window==null else window
	await process_frame; await RenderingServer.frame_post_draw
	var image:=target.get_texture().get_image()
	var path:=evidence.path_join(identity+".png")
	if check(image!=null and not image.is_empty() and image.save_png(path)==OK,"actual graphical Window capture "+identity):
		captures.append({"id":identity,"path":identity+".png","sha256":FileAccess.get_sha256(path),"extent":[image.get_width(),image.get_height()],"caption":caption,"kind":"actual-godot-window-framebuffer"})

func finish() -> void:
	output["checks"]=checks; output["failures"]=failures; output["passed"]=failures.is_empty()
	if not evidence.is_empty():
		var file:=FileAccess.open(evidence.path_join("collaborative-ui.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(output,"",true,true)); file.close()
	print("ARCHITECTURE_COLLABORATIVE_UI: %d checks, %d failures" % [checks,failures.size()])
	if is_instance_valid(host): host.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
