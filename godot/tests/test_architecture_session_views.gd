extends SceneTree
## Bounded copied-view contracts only. Actual native authority is exercised by
## the separate Workbench/native suites; these values are explicitly fixtures.
const Session=preload("res://scripts/batch_lab/architecture_stage_session.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Catalogue=preload("res://scripts/batch_lab/native_module_catalogue.gd")
class Worker extends RefCounted:
	var generation:=11
	var tick:=0
	func paint_state() -> Dictionary: return {"generation":generation,"tick":tick}
class Host extends RefCounted:
	var simulation_worker:=Worker.new()
	var paused:=true
class Bench extends Node:
	var host:=Host.new()
	var paint_editor: Control=null
	var art_batches: Window=null
var checks:=0
var failures:=0

func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
	print("ARCHITECTURE_VIEW_CHECK ",label," ",value)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var bench:=Bench.new()
	root.add_child(bench)
	var session:=Session.new()
	session.wb=bench
	root.add_child(session)
	var stage:=Compiler.stage_defaults("view-source",Rect2i(7,9,8,6))
	stage.operations=[{"shape":"rectangle","x0":9,"y0":11,"x1":10,"y1":12,"material":58}]
	var plan: Dictionary={"format":Compiler.FORMAT,"id":"view-contract","intent":"Bounded host summaries","stages":[stage]}
	check(session.load_plan(plan).ok,"finite plan loaded")
	check(not session.inspection_view().ok,"unobserved selection has no invented source")
	var cells:=PackedByteArray()
	cells.resize(8*6*2)
	cells.encode_u16(0,58)
	var context: Dictionary={"ok":true,"region":[7,9,8,6],"source_cells":cells,"source_sha256":Compiler.digest(cells),"generation":11,"provenance":{"kind":"fixture-only"}}
	session._remember_inspection(context)
	var view: Dictionary=session.inspection_view()
	check(view.ok and not view.stale and view.cells==cells,"copied inspection retains exact fixture geometry")
	view.cells.encode_u16(0,0)
	view.provenance.kind="tampered"
	check(session.inspection_view().cells.decode_u16(0)==58 and session.inspection_view().provenance.kind=="fixture-only","returned inspection cannot mutate host cache")
	bench.host.simulation_worker.generation+=1
	check(session.inspection_view().stale,"World replacement marks captured snapshot stale")
	bench.host.simulation_worker.generation-=1
	session._retain({"kind":"native-stage","stage_id":stage.id,"stage":stage,"stage_sha256":Compiler.digest(Compiler.canonical(stage).to_utf8_buffer()),
		"status":"completed","generation":11,"final_readback_available":true,"result_materials_base64":Marshalls.raw_to_base64(cells),
		"result_sha256":Compiler.digest(cells),"checked_cells":1,"changed_cells":1,"native_receipts_sha256":"fixture-only","native_receipts":[{"payload":"x".repeat(262144)}]})
	var compact: Dictionary=session.summary()
	var compact_text:=Compiler.canonical(compact)
	check(compact_text.length()<8192 and not compact_text.contains("result_materials_base64") and not compact_text.contains("native_receipts"),"UI summary excludes full receipts, planes and operations")
	check(compact.stages[0].native_result.same_stage,"stage identity uses precomputed digests")
	check(session.native_result_view().ok and session.native_result_view().cells==cells,"selected retained readback validates its exact digest")
	session.records.back().result_sha256="invalid"
	check(not session.native_result_view().ok,"tampered retained material hash is refused")
	session.records.back().result_sha256=Compiler.digest(cells)
	session.preview={"stage_id":stage.id,"budget":{},"preview_sha256":"fixture"}
	session._preview_fence=session._observation_fence()
	session.states[stage.id]="previewed"
	bench.host.paused=false
	session._process(0.11)
	check(session.preview.is_empty() and session.stage_state()=="proposed","resuming simulation clears current approval preview")
	bench.host.paused=true
	check(session.select(0).ok and not session.inspection_view().ok,"new selection clears prior inspected source")
	check(session.records.size()==1,"view invalidation preserves original terminal evidence")
	# Explicit projected fixtures exercise scope logic; they do not grant any
	# native catalogue qualification and are never used by production imports.
	var templates:=Catalogue.template_library()
	session.library=templates.library
	var part: Dictionary=session.library.get_module("framed-vent-grille")
	var resolved:={"id":part.id,"sha256":part.content_sha256,"instance_id":"fixture-grille","placement":{"origin":[20,30],"transform":"rotate_90"}}
	var compiled:=Module.compile(part,resolved.placement,{"region":[0,0,128,128],"allowed_materials":[0,7,28,58],"protected":[],"max_cells":16384})
	check(compiled.ok,"asymmetric rotated part fixture compiles for scope challenge")
	var fixture_cells:=PackedByteArray(); fixture_cells.resize(128*128*2)
	for offset: int in range(0,compiled.cells.size(),3): fixture_cells.encode_u16((compiled.cells[offset+1]*128+compiled.cells[offset])*2,compiled.cells[offset+2])
	var observed:={"region":[0,0,128,128],"cells":fixture_cells,"source_sha256":Compiler.digest(fixture_cells),"generation":11}
	session._placed_parts=[session._part_scope(resolved,11)]
	var detail:=session._detail_context_from_inspection(observed,"fixture-grille")
	check(detail.ok and detail.instances[0].current_geometry_verified and detail.context.variable_regions==[[23,33,18,42]],"variable regions follow exact rotated native instance coordinates")
	check(detail.ok and detail.context.attachment_cells.size()==48 and [43,30] in detail.context.attachment_cells and [43,77] in detail.context.attachment_cells,"the entire transformed attachment line is guarded")
	check(not detail.context.fixed_regions.is_empty() and detail.context.source_sha256==observed.source_sha256,"fixed geometry and source identity accompany detail proposal context")
	detail.context.variable_regions.clear()
	check(not session._detail_context_from_inspection(observed,"fixture-grille").context.variable_regions.is_empty(),"returned detail context cannot mutate retained instance semantics")
	var changed_source:=observed.duplicate(true)
	changed_source.cells.encode_u16((34*128+24)*2,58)
	changed_source.source_sha256=Compiler.digest(changed_source.cells)
	check(not session._detail_context_from_inspection(changed_source,"fixture-grille").ok,"foreign material added in original empty module cells refuses variable wear")
	var replacement:=observed.duplicate(true); replacement.generation=12
	check(not session._detail_context_from_inspection(replacement,"fixture-grille").ok,"a replacement World cannot inherit old native instance detail authority")
	check(session._detail_context_from_inspection(observed,"").context.variable_regions.is_empty(),"an unselected region grants no inferred variable geometry")
	session._placed_parts.clear()
	check(not session._detail_context_from_inspection(observed,"fixture-grille").ok,"historical or imported module bytes without live placement grant no detail scope")
	session.queue_free()
	bench.queue_free()
	await process_frame
	print("ARCHITECTURE_SESSION_VIEW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Copied-value UI fixture contracts; no inference or native construction claim."}))
	quit(0 if failures==0 else 1)
