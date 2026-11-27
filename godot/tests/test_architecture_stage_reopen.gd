extends SceneTree
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var main: Control
var wb: Control
var panel: Window
var checks:=0
var failures:=0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks+=1
	print("ARCHITECTURE_REOPEN_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
	return value

func until(test: Callable,label: String) -> bool:
	var deadline:=Time.get_ticks_msec()+90000
	while not test.call() and Time.get_ticks_msec()<deadline: await process_frame
	return check(test.call(),label)

func installed() -> bool:
	return not wb.applied.is_empty() and not wb.busy() and main.pending_microscenario_apply.is_empty()

func run() -> void:
	var evidence:=OS.get_environment("ARCHITECTURE_EVIDENCE_DIR")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://architecture-native-evidence")
	var identity: Variant=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("reopen-identity.json")))
	if not check(identity is Dictionary and identity.get("last",{}) is Dictionary and not identity.last.is_empty(),"previous native process exported a reopen identity"): finish(); return
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main=current_scene
	wb=main.shared_workbench
	if not await until(installed,"fresh native Workbench ready"): finish(); return
	wb._name.text=identity.workbench_name
	if not check(wb.load_setup(),"ordinary authored start load admitted"): finish(); return
	if not await until(installed,"saved authored native geometry installed"): finish(); return
	wb.open_architecture_lab()
	panel=wb.architecture_lab
	panel.hide()
	var library: RefCounted=panel.library
	check(library.load_library(evidence.path_join(identity.library)).ok,"saved exact native module geometry reopened")
	check(library.count()>=6,"six native representative modules retained")
	check(library.summaries().all(func(item: Dictionary) -> bool: return not item.native_readback_verified),"imported evidence does not impersonate fresh native observation")
	var session: Node=panel.session
	check(session.open_session(evidence.path_join(identity.session)).ok,"staged session reopened with identity validation")
	check(session.records.is_empty() and not session.imported_history.is_empty(),"old native records remain explicit imported historical evidence")
	check(not session.busy() and session.preview.is_empty() and session.completed_ids().is_empty(),"fresh process resumes no construction or assumed completed dependency")
	check(session.states.values().all(func(value: String) -> bool: return value=="proposed"),"every reopened stage requires another native inspection and approval")
	var size:=Vector2i(int(identity.last.extent[0]),int(identity.last.extent[1]))
	var region:=Rect2i(16,16,size.x,size.y)
	var capture: Dictionary=await wb.capture_batch_source(region)
	if check(capture.get("ok",false),"fresh native material capture available"):
		check(Compiler.digest(capture.config.source_cells)==identity.last.sha256,"every reopened native representative material cell matches the original process")
		var original:=FileAccess.get_file_as_bytes(evidence.path_join(identity.last.plane))
		check(capture.config.source_cells==original,"independent complete material plane equality after ordinary Save/Open")
	var whole: Dictionary=await wb.capture_batch_source(Rect2i(0,0,512,512))
	var outside:=true
	if whole.get("ok",false):
		for y: int in 512:
			for x: int in 512:
				if not region.has_point(Vector2i(x,y)) and whole.config.source_cells.decode_u16((y*512+x)*2)!=0: outside=false
	else: outside=false
	check(outside,"fresh reopened construction has no out-of-region writes")
	var before: PackedByteArray=capture.config.source_cells.duplicate() if capture.get("ok",false) else PackedByteArray()
	for i: int in 12: await process_frame
	var stable: Dictionary=await wb.capture_batch_source(region)
	check(stable.get("ok",false) and stable.config.source_cells==before,"session reopening does not execute the retained plan")
	finish()

func finish() -> void:
	print("ARCHITECTURE_STAGE_REOPEN: %d checks, %d failures" % [checks,failures])
	if is_instance_valid(main): main.queue_free(); await process_frame; await process_frame
	quit(1 if failures else 0)
