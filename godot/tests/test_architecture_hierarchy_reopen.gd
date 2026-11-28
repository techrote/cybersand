extends "res://tests/test_architecture_gameplay.gd"
## Separate-process ordinary Save/Load and historical state retirement.
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Session=preload("res://scripts/batch_lab/architecture_stage_session.gd")
const Workflow=preload("res://scripts/batch_lab/architecture_workflow.gd")
const Library=preload("res://scripts/batch_lab/native_module_library.gd")
var reopened: Dictionary={}
var session: Node
var workflow: Node

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_HIERARCHY_DIR")
	if evidence.is_empty():evidence=ProjectSettings.globalize_path("user://architecture/hierarchy")
	var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("hierarchy-native.json")))
	if not check(document is Dictionary and document.get("failures",1)==0 and document.get("source_revision")==OS.get_environment("CYBERSAND_SOURCE_REVISION"),"exact-source completed native hierarchy available"):await finish();return
	var previous: Dictionary=document.result
	if not check(FileAccess.get_sha256(evidence.path_join(previous.start))==previous.start_sha256,"saved authored start content identity"):await finish();return
	var start:=_read_start({"start_path":evidence.path_join(previous.start)})
	if not check(not start.is_empty(),"portable authored start validates"):await finish();return
	if not await start_host():await finish();return
	var name_text:="m67-delegated-workshop-reopened"
	if not check(Setup.write_named(name_text,start).is_empty(),"named authored start imported through ordinary Setup storage"):await finish();return
	wb._name.text=name_text
	if not check(wb.load_setup(),"ordinary Load start admits saved construction") or not await until(installed,"fresh World installs saved hierarchy geometry"):await finish();return
	var observed: Dictionary=await wb.capture_batch_source(Rect2i(0,0,512,512))
	check(observed.get("ok",false) and observed.config.source_provenance.crop_sha256==previous.plane_sha256,"fresh process native readback exactly reproduces the final material plane")
	check(host.paused and (wb.art_batches==null or not wb.art_batches.provider.active),"reopen remains paused and starts no provider or old native job")
	session=Session.new();session.wb=wb;session.library=Library.new();root.add_child(session)
	workflow=Workflow.new();root.add_child(workflow);workflow.bind_session(session)
	check(session.library.load_library(evidence.path_join("workshop-modules.json")).ok,"separate reusable geometry library opens")
	check(session.open_session(evidence.path_join("workshop-session.json")).ok,"separate native execution history opens for inspection")
	var history: Variant=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("workshop-workflow.json")))
	check(workflow.open_history(history).ok,"bounded recovery and prior owner decisions reopen")
	check(not workflow.busy() and not workflow.summary().has_review_ticket and not workflow.summary().prepared_local_job \
		and session.completed_ids().is_empty() and workflow.campaign.summary().historical_only,"reopened decisions grant no current completion approval worker capability or execution")
	var again: Dictionary=await wb.capture_batch_source(Rect2i(0,0,512,512))
	check(again.get("ok",false) and again.config.source_cells==observed.config.source_cells,"opening library and histories cannot mutate saved World")
	reopened={"plane_sha256":previous.plane_sha256,"start_sha256":previous.start_sha256,"prior_campaigns":workflow.summary().prior_campaigns,
		"records":session.records.size(),"native_source_revision":document.source_revision,"fresh_process":true}
	await finish()

func finish() -> void:
	var file:=FileAccess.open(evidence.path_join("hierarchy-reopen.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(Compiler.canonical({"format":"cybersand-native-hierarchy-reopen-v1","checks":checks,"failures":failures.size(),"failed_checks":failures,
			"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"core_capacity":int(ProjectSettings.get_setting("cybersand/native_active_core_capacity",1024)),
			"godot":Engine.get_version_info().string,"platform":OS.get_name(),"result":reopened}));file.close()
	print("ARCHITECTURE_HIERARCHY_REOPEN: %d checks, %d failures"%[checks,failures.size()])
	if is_instance_valid(workflow):workflow.queue_free()
	if is_instance_valid(session):session.queue_free()
	if is_instance_valid(host):host.queue_free()
	await process_frame;await process_frame
	quit(1 if not failures.is_empty() else 0)
