extends "res://tests/test_workbench_freed.gd"

const Wakeup=preload("res://scripts/workbench_cut_wakeup.gd")

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func fresh_host() -> bool:
	change_scene_to_file("res://feature_launcher.tscn");await scene_changed
	current_scene.launch("shared_workbench");await scene_changed
	host=current_scene;ui=host.shared_workbench
	if not check(await until(installed),"normal live worker"): return false
	var recipe: Dictionary=Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	check(ui.apply(recipe),"fresh native-only World")
	return check(await until(installed),"fresh native owner installed")

func run() -> void:
	for after_publication: bool in [false,true]:
		if not await fresh_host(): finish();return
		var worker=host.simulation_worker
		var tick: int=host.latest_snapshot.tick_index
		var wakeup=Wakeup.new()
		var serial: int=worker.queue_workbench_cut({"action":"begin","dabs":PackedInt32Array([350,350,2]),"sample":{}},wakeup)
		check(serial>0,"actual worker queued notification")
		if after_publication:
			# Test-only stall: hold main delivery until the real worker publishes.
			# This is deliberately excluded from performance measurements.
			var found: bool=false;var deadline: int=Time.get_ticks_msec()+2000
			while Time.get_ticks_msec()<deadline:
				worker._mutex.lock();found=not worker._workbench_cut_reply.is_empty();worker._mutex.unlock()
				if found: break
				OS.delay_usec(1000)
			check(found and not wakeup.done,"real reply published before deferred delivery")
		worker.stop_worker()
		await process_frame
		check(wakeup.done,"shutdown or published completion always wakes")
		var reply: Dictionary=worker.take_workbench_cut_reply(serial)
		check(reply.get("transport_failure",false) and str(reply.outcome).contains("stopped"),"stopped worker cannot apply an already published reply")
		check(worker.queue_workbench_cut({"action":"next"},Wakeup.new())==0,"stopped queue refuses")
		check(host.paused and host.latest_snapshot.tick_index==tick,"stop never resumes clocks")
	if not await fresh_host(): finish();return
	# Replacements race only on detached notification/mailbox bookkeeping here;
	# no test thread calls native World or live Godot/Rapier APIs.
	var worker=host.simulation_worker
	var pending=Wakeup.new()
	check(worker.queue_workbench_cut({"action":"begin","dabs":PackedInt32Array([350,350,2]),"sample":{}},pending)>0,"replacement request queued")
	worker.stop_worker()
	var replacement:=Thread.new()
	check(replacement.start(worker._replace_cut_world_mailbox)==OK,"replacement bookkeeping thread")
	replacement.wait_to_finish()
	await process_frame
	check(pending.done and worker._workbench_cut_request.is_empty() and worker._workbench_cut_reply.is_empty(),"replacement clears mailbox and retires notification")
	check(worker.queue_workbench_cut({"action":"begin"},Wakeup.new())==0,"replacement cannot reopen stopped owner")
	finish()
