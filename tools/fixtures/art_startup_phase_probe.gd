extends SceneTree
## External read-only phase apparatus; production source and scheduling unchanged.
## Fresh process/profile timings are wall times, not OS-cache cold CPU benchmarks.
var host: Control
var wb: Control
var panel: Window
var began_usec := 0
var phases: Dictionary = {}
var captures: Array = []
var failures: Array = []
var checks := 0
var frames := 0
var max_gap_usec := 0
var previous_usec := 0
var output := ""
var context_script: GDScript

func _initialize() -> void:
	began_usec=Time.get_ticks_usec()
	previous_usec=began_usec
	output=OS.get_environment("ART_STARTUP_PHASE_OUTPUT")
	set_meta("cybersand_feature","shared_workbench")
	run.call_deferred()

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	max_gap_usec=maxi(max_gap_usec,now-previous_usec)
	previous_usec=now
	frames+=1
	return false

func check(value: bool, label: String) -> bool:
	checks+=1
	if not value: failures.append(label)
	print("ART_STARTUP_PHASE_CHECK ",label," ",value)
	return value

func until(predicate: Callable, label: String, timeout_ms := 90000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not bool(predicate.call()) and Time.get_ticks_msec()<deadline: await process_frame
	return check(bool(predicate.call()),label)

func installed() -> bool:
	return is_instance_valid(wb) and not wb.applied.is_empty() and not wb.busy() and host.pending_microscenario_apply.is_empty()

func run() -> void:
	var started := Time.get_ticks_usec()
	var scene: PackedScene = load("res://main.tscn")
	phases.resource_load_main_usec=Time.get_ticks_usec()-started
	if not check(scene!=null,"main scene loads"): finish();return
	started=Time.get_ticks_usec()
	host=scene.instantiate()
	phases.scene_instantiate_usec=Time.get_ticks_usec()-started
	if not check(is_instance_valid(host),"main scene instantiates"): finish();return
	started=Time.get_ticks_usec()
	root.add_child(host)
	phases.add_child_and_synchronous_ready_usec=Time.get_ticks_usec()-started
	wb=host.shared_workbench
	started=Time.get_ticks_usec()
	if not await until(installed,"ordinary native Workbench installs"): finish();return
	phases.remaining_native_install_wait_usec=Time.get_ticks_usec()-started
	phases.workbench_ready_elapsed_usec=Time.get_ticks_usec()-began_usec
	check(wb.art_batches==null,"Workbench startup has no Art provider")
	started=Time.get_ticks_usec()
	wb.open_art_batches()
	panel=wb.art_batches
	phases.ordinary_art_open_usec=Time.get_ticks_usec()-started
	check(is_instance_valid(panel) and not panel.provider.active and panel.provider.serial==0,"ordinary Art opening admits no provider request")
	started=Time.get_ticks_usec()
	await process_frame
	phases.first_frame_after_art_open_usec=Time.get_ticks_usec()-started
	started=Time.get_ticks_usec()
	context_script=load("res://scripts/art_world_context.gd")
	phases.load_context_resource_usec=Time.get_ticks_usec()-started
	for side: int in [64,256,512]:
		await observe(Rect2i(0,0,side,side))
	check(not panel.provider.active and panel.provider.serial==0,"all measurements leave provider undispatched")
	started=Time.get_ticks_usec()
	host.queue_free()
	await process_frame
	await process_frame
	phases.orderly_teardown_usec=Time.get_ticks_usec()-started
	finish()

func observe(region: Rect2i) -> void:
	var state := {"receipt":{},"completed_usec":0}
	var before: Dictionary = wb.paint_editor.art_context_state().source
	var requested := Time.get_ticks_usec()
	var answer: Dictionary = wb.paint_editor.art_context_capture(region,func(value:Dictionary)->void:
		state.completed_usec=Time.get_ticks_usec()
		state.receipt=value)
	var admission := Time.get_ticks_usec()-requested
	if not check(answer.get("ok",false),"native capture admitted "+str(region.size)): return
	if not await until(func()->bool:return not state.receipt.is_empty(),"native capture completes "+str(region.size)): return
	var receipt: Dictionary = state.receipt
	check(receipt.get("status")=="completed" and receipt.get("kind")=="capture" and receipt.get("backend")=="CyberNativeCellWorld","actual native capture owner "+str(region.size))
	var after: Dictionary = wb.paint_editor.art_context_state().source
	check(before==after,"read-only capture preserves source identity "+str(region.size))
	var policy := {"extent":wb.paint_editor.extent(),"region":region,"allowed":[0,58],"protected":[],
		"objective":"Inspect a bounded industrial room and preserve its open passage.","style":"industrial",
		"include_native_summary":true,"include_knowledge":true}
	var builds: Array = []
	for repeat: int in 3:
		var started := Time.get_ticks_usec()
		var value: Dictionary = context_script.build(receipt,policy,[])
		var duration := Time.get_ticks_usec()-started
		check(value.get("ok",false),"bounded context builds "+str(region.size)+" repeat "+str(repeat))
		builds.append({"wall_usec":duration,"internal_elapsed_usec":value.get("inspector",{}).get("elapsed_usec",-1),
			"wire_bytes":value.get("inspector",{}).get("bytes",-1),"context_sha256":value.get("digest","")})
	captures.append({"region":[region.position.x,region.position.y,region.size.x,region.size.y],
		"cells":region.size.x*region.size.y,"admission_usec":admission,
		"admission_to_callback_usec":int(state.completed_usec)-requested,
		"callback_to_observation_usec":Time.get_ticks_usec()-int(state.completed_usec),
		"source_before":before,"source_after":after,"builds":builds})

func finish() -> void:
	var value := {"format":"cybersand-art-startup-phases-v1","source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"application_source":"2743f89a0df6f6afcf7484e859c10790d521e74b","checks":checks,"failures":failures,
		"platform":OS.get_name(),"display":DisplayServer.get_name(),"godot":Engine.get_version_info().string,
		"processor_name":OS.get_processor_name(),"logical_processors":OS.get_processor_count(),
		"video_adapter":RenderingServer.get_video_adapter_name(),"renderer_method":RenderingServer.get_current_rendering_method(),
		"model_calls":0,"provider_requests":0,"phases":phases,"captures":captures,
		"elapsed_usec":Time.get_ticks_usec()-began_usec,"frames":frames,"maximum_observed_frame_gap_usec":max_gap_usec,
		"scope":"External read-only phase observation; no production scheduling change or physical Windows acceptance."}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(value,"\t")+"\n");file.close()
	print("ART_STARTUP_PHASE_RESULT ",JSON.stringify(value))
	quit(0 if failures.is_empty() else 1)
