extends SceneTree
## Pure authoring UI fixtures. These checks do not certify native construction.
const Document = preload("res://scripts/batch_lab/architecture_document_editor.gd")
const Canvas = preload("res://scripts/batch_lab/architecture_module_canvas.gd")
const Semantics = preload("res://scripts/batch_lab/architecture_semantics_editor.gd")
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const ArchitecturePanel = preload("res://scripts/batch_lab/architecture_stage_panel.gd")
var checks := 0
var failures := 0

class HostlessWorkbench extends Node:
	var host: Node
	var paint_editor: Node
	var art_batches: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures+=1; push_error("ARCHITECTURE_CONTROLS: "+message)

func run() -> void:
	check(ArchitecturePanel is GDScript,"integrated architecture panel and all UI dependencies parse")
	var document := Document.new()
	root.add_child(document)
	await process_frame
	var original := JSON.stringify({"intent":"side elevation","operations":"a".repeat(17000),"tail":"retained"})
	check(document.set_document(original),"bounded complete typed draft admitted")
	check(document.editor.text.length()==Document.PAGE_CHARACTERS and document.text==original,"large draft is retained completely while only one page is shaped")
	document.show_page(2)
	check(document.editor.text==original.substr(8192,4096),"page navigation uses exact deterministic character slices")
	document.editor.text="b"+document.editor.text.substr(1)
	document._page_edited()
	var changed := original.left(8192)+"b"+original.substr(8193)
	check(document.text==changed,"editing a middle page preserves both unseen prefix and suffix")
	document.editor.text="c"+document.editor.text.substr(1)
	document._page_edited()
	var last_page := document.editor.text
	document.editor.text="x".repeat(Document.PAGE_CHARACTERS*2+1)
	document._page_edited()
	check(document.editor.text==last_page and document.text==original.left(8192)+"c"+original.substr(8193),"oversize page paste preserves the latest accepted edit")
	document.show_page(99999)
	check(document.page_number.value==document.page_number.max_value and document.text.ends_with('"tail":"retained"}'),"navigation clamps without dropping terminal document data")
	var prior := document.text
	check(not document.set_document("x".repeat(Document.MAX_BYTES+1)) and document.text==prior,"oversize full replacement cannot destroy the prior draft")
	check(document.parsed().ok,"full JSON validation spans all paged text")
	document.text="{broken"
	check(not document.parsed().ok,"malformed complete JSON refuses before stage mutation")
	var canvas := Canvas.new()
	root.add_child(canvas)
	canvas.size=Vector2(400,240)
	canvas.set_result(null,Vector2i(16,48),PackedByteArray(),"Pure material fixture")
	canvas.fit()
	check(Rect2(Vector2.ZERO,canvas.size).encloses(canvas.image_rect()),"tall native extent fully fits the same material canvas transform")
	check(canvas.local_cell_at(canvas.image_rect().position+Vector2(4.5,7.5)*canvas.pixels_per_cell())==Vector2i(4,7),"overlay picking uses the same local-cell transform as material drawing")
	canvas.set_semantics({"anchor":[4,7],"attachments":[{"id":"top","kind":"line","point":[0,0],"end":[15,0],"facing":[0,-1],"source":"authored"}],"clearances":[[3,3,5,5]]})
	check(canvas._semantics.anchor==[4,7] and canvas.extent==Vector2i(16,48),"semantic overlays never replace native extent or plane")
	canvas.native_scale()
	check(is_equal_approx(canvas.pixels_per_cell(),1.0),"overlay canvas preserves exact 1:1 navigation")
	canvas.fit()
	canvas.size=Vector2(160,320)
	check(Rect2(Vector2.ZERO,canvas.size).encloses(canvas.image_rect()),"fitted material and overlay coordinate frame follows resize")
	var bytes := PackedByteArray()
	bytes.resize(8*8*2)
	for x: int in 8: bytes.encode_u16((7*8+x)*2,58)
	var harvested := Module.harvest(bytes,Vector2i(8,8),Rect2i(0,0,8,8),{"id":"ui-fixture","name":"Pure UI fixture","roles":[{"name":"frame","material_ids":[58],"compatible_materials":[58,28],"source":"authored"}]})
	check(harvested.ok,"pure metadata fixture validates without claiming native provenance")
	var semantics := Semantics.new()
	root.add_child(semantics)
	await process_frame
	semantics.open_module(harvested.module,false)
	semantics.anchor[0].value=3
	semantics.transforms.mirror_x.button_pressed=true
	var patch := semantics.patch()
	check(patch.anchor==[3,7] and "mirror_x" in patch.allowed_transforms,"friendly anchor and transform controls produce explicit metadata draft")
	check(not patch.has("geometry") and not patch.has("provenance") and not patch.has("recipe"),"metadata controls cannot submit edits to observed geometry or provenance")
	semantics.connector_fields.id.text="roof-face"
	semantics.connector_fields.compatibility.text="frame, steel"
	semantics.connector_fields.x.value=2
	semantics.connector_fields.y.value=7
	semantics.store_connector(false)
	check(semantics.patch().attachments.size()==1 and semantics.patch().attachments[0].source=="authored","connector fields create authored declarations, never inferred native facts")
	semantics.region_fields[0].value=1
	semantics.region_fields[1].value=1
	semantics.region_fields[2].value=4
	semantics.region_fields[3].value=3
	semantics.store_region(false)
	check(semantics.patch().clearances==[[1,1,4,3]],"rectangle controls preserve exact local integer clearance declaration")
	semantics.version.button_pressed=true
	check(semantics.patch().format==Semantics.V2 and semantics.patch().attachments[0].capacity==1 and semantics.patch().attachments[0].contact.tolerance==0,"explicit v2 upgrade exposes finite exact contact semantics")
	check(not semantics.commit_draft().ok,"metadata cannot commit an unvalidated draft")
	check(not semantics.validate_draft().ok,"missing metadata library adapter refuses safely")
	check(harvested.module.geometry.cells_base64==Marshalls.raw_to_base64(bytes),"all UI draft changes preserve original immutable fixture bytes")
	var library := Library.new()
	library.add(harvested.module)
	semantics.library=library
	var validated: Dictionary=semantics.validate_draft()
	if not validated.ok: print("METADATA_FORM_REFUSAL ",validated.get("reason",""))
	check(validated.ok and validated.zero_writes and validated.module.geometry==harvested.module.geometry,"real library validates authored form draft without changing exact material geometry")
	check(semantics.commit_draft().ok and library.get_module("ui-fixture").format==Semantics.V2,"explicit validated metadata save upgrades only the named library manifest")
	semantics.open_module(library.get_module("ui-fixture"),false)
	semantics.anchor[0].value=4
	check(semantics.validate_draft().ok,"a second metadata draft can be reviewed against its exact content hash")
	library.annotate("ui-fixture","Concurrently renamed fixture",[])
	check(not semantics.commit_draft().ok and library.get_module("ui-fixture").name=="Concurrently renamed fixture","stale metadata form cannot overwrite a concurrent library revision")
	var line_module: Dictionary = Module.harvest(bytes,Vector2i(8,8),Rect2i(0,0,8,8),{"id":"line-ui-fixture","name":"Line UI fixture","attachments":[{"id":"roof","kind":"line","point":[0,7],"end":[7,7],"facing":[0,-1],"compatibility":["frame"],"required":false,"source":"authored"}]}).module
	library.add(line_module)
	semantics.open_module(line_module,false)
	semantics.version.button_pressed=true
	var line_validation: Dictionary=semantics.validate_draft()
	if not line_validation.ok: print("LINE_FORM_REFUSAL ",line_validation.get("reason",""))
	check(semantics.patch().attachments[0].contact.minimum_cells==8 and line_validation.ok,"explicit full-line upgrade uses exact inclusive contact span, including both endpoints")
	var workbench := HostlessWorkbench.new()
	root.add_child(workbench)
	var panel := ArchitecturePanel.new()
	panel.wb=workbench
	root.add_child(panel)
	await process_frame
	panel.library.add(harvested.module)
	panel.search.text="ui-fixture"
	panel._refresh_modules()
	for frame: int in 3: await process_frame
	check(panel.module_ids==["ui-fixture"] and panel.modules.get_item_icon(0)!=null,"shipped browser resolves metadata query and incrementally generates a bounded material thumbnail")
	check(panel.module_view.extent==Vector2i(8,8) and panel.module_view._semantics.anchor==[0,7],"shipped module inspector binds exact plane and separate authored guides")
	check(panel.palette_choices.has("frame") and panel.palette_choices.frame.item_count==3,"role palette exposes original plus declared compatible material choices")
	panel.palette_choices.frame.select(2)
	panel._palette_changed()
	check(int(JSON.parse_string(panel.palette.text).get("frame",-1))==28,"named palette control produces a typed role substitution")
	check(not panel.stage_editor.visible and panel.result_tabs.get_tab_count()==3,"ordinary stage review separates source/projection/native result and hides typed JSON")
	panel.stage_intent.text="Owner-revised bounded stage intent"
	panel.revise_stage()
	check(panel.session.stage().intent=="Owner-revised bounded stage intent" and panel.session.preview.is_empty(),"friendly stage revision is a proposal and retires approval")
	panel.stage_advanced.button_pressed=true
	check(panel.stage_editor.visible and panel.stage_editor.editor.text.length()<=Document.PAGE_CHARACTERS and panel.stage_editor.parsed().ok,"optional advanced editor retains complete selected stage with bounded visible text")
	panel.propose_placement()
	check(panel.session.stage().modules.size()==1 and int(panel.session.stage().modules[0].placement.palette.get("frame",-1))==28,"module placement control creates a finite typed proposal without a World")
	check(panel.session.records.all(func(record: Dictionary) -> bool: return record.kind!="native-stage") and panel.preview_label.text.contains("NO CURRENT"),"hostless UI fixture cannot manufacture native completion or current preview")
	panel._close()
	check(not panel.visible and not panel.session.busy(),"close/stop remains reachable from ordinary module controls")
	panel.queue_free()
	workbench.queue_free()
	semantics.queue_free()
	canvas.queue_free()
	document.queue_free()
	await process_frame
	await process_frame
	print("ARCHITECTURE_CONTROLS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
