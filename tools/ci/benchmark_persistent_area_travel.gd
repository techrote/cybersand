# External harness runs unchanged against donor and successor Godot projects.
extends SceneTree

const Scene = preload("res://persistent_areas.tscn")
var host: Control
var controller: Node
var output := ""
var rows: Array = []
var workers := 1
var sample_count := 30
var failures: Array[String] = []
var last_frame_us := 0
var frame_gap_ms := 0.0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-output="): output = argument.trim_prefix("--baseline-output=")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-workers="): workers = clampi(int(argument.trim_prefix("--baseline-workers=")),1,4)
		if argument.begins_with("--baseline-samples="): sample_count = clampi(int(argument.trim_prefix("--baseline-samples=")),1,100)
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	run.call_deferred()

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if last_frame_us > 0: frame_gap_ms = maxf(frame_gap_ms, float(now-last_frame_us)/1000.0)
	last_frame_us = now
	return false

func wait_ready(timeout: int = 180000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout
	while Time.get_ticks_msec()<deadline:
		if not controller.busy:
			return controller.active_ready and host.pending_microscenario_apply.is_empty() and not host.shared_workbench.busy()
		await process_frame
	return false

func run() -> void:
	root.size = Vector2i(1280,720)
	var started := Time.get_ticks_usec()
	host = Scene.instantiate()
	root.add_child(host)
	current_scene = host
	controller = host.persistent_areas
	if not await wait_ready():
		failures.append("startup: "+str(controller.message))
	else:
		rows.append({"kind":"open","elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0,"max_frame_gap_ms":frame_gap_ms})
		# Same cyclic edges and equal A/B/C target mix as the HOT/WARM gates.
		var sequence := ["b","c","a"]
		for i in range(sample_count):
			var source: String = controller.active_area
			var target: String = sequence[i%sequence.size()]
			var before: Dictionary = controller.clock.duplicate(true)
			if not host.paused or int(before.game_ticks)!=0:
				failures.append("zero-debt controlled clock changed before sample "+str(i))
				break
			frame_gap_ms = 0.0
			started = Time.get_ticks_usec()
			last_frame_us = started
			if not controller.request_travel(target) or not await wait_ready():
				failures.append("travel "+str(i)+": "+str(controller.message))
				break
			var completed_us := Time.get_ticks_usec()
			# Include the terminal main-thread interval before the receipt freezes.
			# Bound both ends to this operation; following staging is not travel.
			frame_gap_ms = maxf(frame_gap_ms, float(completed_us-last_frame_us)/1000.0)
			var row := {"kind":"travel","index":i,"source":source,"target":target,"elapsed_ms":float(completed_us-started)/1000.0,
				"max_frame_gap_ms":frame_gap_ms,"game_tick":controller.clock.game_ticks,"native_tick":host.latest_snapshot.tick_index,
				"start_usec":started,"end_usec":completed_us,"frame_scope":"Main-frame intervals clipped to operation start/end, including terminal tail",
				"world_generation":host.latest_snapshot.render_world_generation,"last_result":controller.last_result.duplicate(true)}
			rows.append(row)
			print("RAMCACHE_BASELINE_SAMPLE ",JSON.stringify(row))
			if controller.clock!=before or controller.active_area!=target or not controller.last_result.get("ok",false):
				failures.append("clock, identity or result mismatch "+str(i))
				break
	var report := {"schema":"gen006-ramcache-baseline-v1","pid":OS.get_process_id(),"graphics":DisplayServer.get_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"renderer":RenderingServer.get_video_adapter_name(),
		"workers":workers,"fixture_extent":[512,512],"rows":rows,"failures":failures,"passed":failures.is_empty() and rows.size()==sample_count+1,
		"controller_evidence":controller.evidence(),"methodology":"Paused zero-debt native A/B/C; external harness; cold cache-disabled route"}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("Baseline report write failed"); quit(2); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	if host.simulation_worker != null: host.simulation_worker.stop_worker()
	quit(0 if report.passed else 1)
