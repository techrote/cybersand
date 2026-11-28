extends SceneTree

# Exercise the actual Structures checkbox, ordinary worker and saved report.
# Instrumentation must never be authority for native/physical progression.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var observations: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower"):
		await _finish(); return
	var probe: CyberObjectShardM4LatencyProbe = f.host.object_shard_m4_probe
	var cli_recording: bool = "--objectshard-diagnostics" in OS.get_cmdline_user_args()
	f.expect(probe.enabled == cli_recording,"Structures flag alone leaves recording off; its own CLI flag enables recording")
	f.expect(RenderingServer.frame_post_draw.is_connected(f.host._object_shard_m4_post_draw) == cli_recording,
		"post-draw instrumentation connection follows the independent recording flag")
	f.bench.open_object_shard_controls()
	var toggle: CheckButton = f.bench._object_shard_recording
	f.expect(toggle != null and toggle.button_pressed == cli_recording,"ordinary Structures checkbox reflects the actual recording state")
	# Toggle through the real control's normal signal, without touching the probe.
	toggle.button_pressed = false
	f.bench._object_shard_window.hide()
	var original_worker: int = f.host.simulation_worker.get_instance_id()
	var original_native: int = int(f.diagnostics().native_instance_id)
	var original_generation: int = int(f.frame().world_generation)
	var disabled_count: int = probe.events.size()
	f.play()
	await f.advance(8,"ordinary native and physical intervals progress with recording disabled")
	await f.pause()
	f.expect(not probe.enabled and probe.events.size() == disabled_count,"disabled recording collects no events during ordinary play")
	f.bench.open_object_shard_controls()
	toggle.button_pressed = true
	f.bench._object_shard_window.hide()
	f.expect(probe.enabled and RenderingServer.frame_post_draw.is_connected(f.host._object_shard_m4_post_draw),
		"real checkbox starts recording and connects renderer observation")
	var recorded_epoch: int = probe.epoch
	f.play()
	await f.advance(12,"recording observes genuine native progression")
	await f.pause()
	var recorded: Dictionary = probe.summary()
	f.expect(int(recorded.events_retained)>0 and recorded.stages.has("scene_callback") \
		and not recorded.cadence.native_progress_delivery.is_empty(),"enabled recording contains real stage events and semantic delivery intervals")
	if DisplayServer.get_name() != "headless":
		f.expect(not recorded.cadence.post_draw_intervals.is_empty(),"graphical recording contains actual post-draw intervals")
	f.bench.open_object_shard_controls()
	toggle.button_pressed = false
	f.bench._object_shard_window.hide()
	var stopped: Dictionary = probe.summary()
	f.expect(not stopped.enabled and stopped.epoch == recorded_epoch \
		and stopped.stages == recorded.stages and stopped.cadence == recorded.cadence,
		"stopping preserves the finished recording for explicit Save diagnostics")
	f.expect(not RenderingServer.frame_post_draw.is_connected(f.host._object_shard_m4_post_draw),
		"stopping removes the renderer instrumentation callback")
	f.play()
	await f.advance(8,"ordinary progression continues after recording stops")
	await f.pause()
	f.expect(probe.summary() == stopped,"stopped recording remains unchanged while the real simulation advances")
	var exported: Dictionary = f.bench.save_object_shard_diagnostics()
	if f.expect(exported.get("ok",false),"ordinary Save diagnostics exports the stopped recording"):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(exported.path)))
		# JSON decodes integral numbers as floats; compare the actual serialized
		# value rather than confusing GDScript Variant types with changed bytes.
		f.expect(saved is Dictionary and saved.get("probe",{}) == JSON.parse_string(JSON.stringify(stopped)),
			"saved timings exactly match the stopped bounded recording")
		observations.saved_report = exported
	f.bench.open_object_shard_controls()
	toggle.button_pressed = true
	f.expect(probe.epoch == recorded_epoch+1 and probe.events.is_empty() \
		and probe.summary().stages.is_empty() and probe.summary().cadence.native_progress_delivery.is_empty(),
		"starting another recording has a new epoch and cannot reuse old timing samples")
	toggle.button_pressed = false
	f.bench._object_shard_window.hide()
	f.expect(f.host.simulation_worker.get_instance_id()==original_worker \
		and int(f.diagnostics().native_instance_id)==original_native \
		and int(f.frame().world_generation)==original_generation,"recording changes preserve the same native World and worker")
	observations.recorded = recorded
	observations.stopped = stopped
	observations.cli_recording = cli_recording
	observations.final_native_tick = f.tick()
	observations.final_physical_intervals = f.diagnostics().physical_intervals
	await _finish()

func _finish() -> void:
	f.validate_display()
	observations.display_coherence = f.display_witness()
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-optional-diagnostics-v1", "checks":f.checks,
		"failures":f.failures,"observations":observations,
		"scope":"actual ordinary Workbench recording controls and saved reports; physical monitor acceptance remains owner-pending"}))
	quit(0 if f.failures.is_empty() else 1)
