extends SceneTree

const Setup=preload("res://scripts/workbench_setup.gd")
var host: Control
var panel
var failures: int=0
var checks: int=0

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok: bool, reason: String) -> bool:
	checks+=1
	if not ok: failures+=1;push_error("CUT_LIFECYCLE "+reason)
	return ok

func until(predicate: Callable) -> bool:
	var end: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<end:
		if predicate.call(): return true
		await process_frame
	return false

func installed() -> bool:
	return panel!=null and not panel.applied.is_empty() and not panel.busy() and host.pending_microscenario_apply.is_empty()

func one(append: bool, committed: bool) -> void:
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;panel=host.shared_workbench
	if not check(await until(installed),"normal workbench starts"): return
	var setup: Dictionary=Setup.fresh(PackedInt32Array(panel.applied.liquid_policy),Vector2i(512,512))
	setup.version=4;setup.edits=[[0,72,512,4,58],[50,40,4,32,43],[44,27,29,13,43],[54,40,11,4,43],[60,32,1,1,0]]
	if append:
		setup.actors=[Setup.instance(Setup.BARREL,1,Vector2(400,32))];setup.next_id=2
	check(panel.apply(setup),"authored native structure")
	if not check(await until(installed),"source installed"): return
	panel.applied.brush=2
	for x: int in range(50,54): check(panel.paint(Vector2i(x,67),0),"accepted ordinary erase dab")
	var cut=panel.cut
	check(cut.finish_stroke(panel),"ordinary stroke completion")
	var seen: bool=await until(func():return cut._committed if committed else not cut._sample.is_empty())
	if not check(seen,"held phase observed before scene departure"): return
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	host=null;panel=null
	await create_timer(.1).timeout
	check(cut._retired and not cut.busy and cut.panel==null,"synchronous owner retirement")
	check(cut._candidate==null and cut._staged.is_empty(),"no staged graph survives teardown")

func run() -> void:
	for append: bool in [false,true]:
		for committed: bool in [false,true]: await one(append,committed)
	print("CUT_LIFECYCLE ",checks," checks / ",failures," failures")
	quit(int(failures>0))
