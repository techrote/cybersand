extends "res://tests/test_workbench_cut_hitch.gd"

class TimedCut extends "res://scripts/workbench_cut.gd":
	var boundary: Dictionary={}
	func _finish() -> void:
		var host=panel.host
		boundary={"usec":Time.get_ticks_usec(),"native_tick":host.latest_snapshot.tick_index,
			"steps":host.rapier_bridge.manual_step_count(),"sample":host._workbench_wait_sample,
			"epoch":host._physical_epoch,"session":host.rapier_bridge._session,
			"timings":timings.duplicate(true),"receipts":receipts.duplicate(true)}
		super._finish()

var active_cut: RefCounted
var first_tick: Dictionary={}
var first_step: Dictionary={}

func observe_resume() -> void:
	if active_cut==null or active_cut.boundary.is_empty() or host==null: return
	var boundary: Dictionary=active_cut.boundary
	if first_tick.is_empty() and host.latest_snapshot.tick_index>int(boundary.native_tick):
		first_tick={"usec":Time.get_ticks_usec(),"tick":host.latest_snapshot.tick_index}
	if first_step.is_empty() and host.rapier_bridge.manual_step_count()>int(boundary.steps):
		first_step={"usec":Time.get_ticks_usec(),"steps":host.rapier_bridge.manual_step_count(),
			"application":host.rapier_bridge.last_application.duplicate(true)}

func live_one(kind: String, repeat: int) -> bool:
	if not await fresh_case(kind): return false
	var timed=TimedCut.new();ui.cut.retire();ui.cut=timed
	check(ui.toggle_pause(),"live run starts")
	var tick: int=host.latest_snapshot.tick_index
	if not check(await until(func():return host.latest_snapshot.tick_index>=tick+3),"three ordinary live ticks before cut"): return false
	active_cut=timed;first_tick={};first_step={}
	ui.applied.brush=2
	var started: int=Time.get_ticks_usec()
	for x: int in range(50,54): check(ui.paint(Vector2i(x,67),0),"live stem erase")
	check(ui.cut.finish_stroke(ui),"live stroke completion")
	if not check(await until(func():return not first_step.is_empty() and not first_tick.is_empty()),"live native and actual Rapier resume"): return false
	check(not host.paused,"live state restored")
	check(first_step.steps==int(timed.boundary.steps)+1,"first physical step observed without missing coverage")
	check(first_step.application.get("accepted",false),"actual response accepted")
	var body_rows: Array=first_step.application.get("bodies",[])
	check(not body_rows.is_empty(),"actual current-roster body applications present")
	for row: Dictionary in body_rows:
		check(not row.has("refusal") and int(row.get("sample",-1))==int(timed.boundary.sample),"first response uses exact cut-end sample")
	check(host._physical_epoch==int(timed.boundary.epoch),"resumed roster epoch unchanged")
	check(ui.toggle_pause(),"pause after first observed resumed step")
	active_cut=null
	evidence.cuts.append({"kind":kind,"repeat":repeat,"started_usec":started,"boundary":timed.boundary,
		"first_native":first_tick,"first_rapier":first_step,"held_usec":int(timed.boundary.usec)-started,
		"visible_resume_usec":int(first_step.usec)-started,"resume_after_hold_usec":int(first_step.usec)-int(timed.boundary.usec)})
	return true

func run() -> void:
	Engine.max_fps=60
	process_frame.connect(observe_resume)
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"normal live-latency workbench"): finish();return
	for kind: String in ["first-tree-core","appended-building-core"]:
		for repeat: int in range(5):
			print("CUT_LIVE_LATENCY ",kind," ",repeat)
			if not await live_one(kind,repeat): finish();return
	evidence["maximum_observed_workers"]=observed_workers
	finish()
