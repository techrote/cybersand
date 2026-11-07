extends SceneTree

## WB-AGENT #526 negative control. Real Godot native/owner session with NO
## agent authorization, tool request, panel or Responses transport.
## Two processes use one user:// named start; the second verifies real reopen.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const PAINT_A := Vector2i(1170,375)
const PAINT_B := Vector2i(1500,1400)
const NAME := "wb-agent-526-agent-disabled-ci"

var host: Control
var panel: Control
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	set_meta("cybersand_feature","shared_workbench")
	_run.call_deferred()


func _check(ok: bool, claim: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_AGENT_DISABLED: " + claim)
	return ok


func _wait_for(predicate: Callable, claim: String) -> bool:
	var limit: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < limit:
		if predicate.call():
			return true
		await process_frame
	return _check(predicate.call(),claim)


func _ready() -> bool:
	return panel != null and not panel.applied.is_empty() \
		and not panel.busy() and host != null and host.paused \
		and host.pending_microscenario_apply.is_empty()


func _fresh_ready() -> bool:
	return _ready() and host.world_extent == Vector2i(2048,2048) \
		and panel.applied.get("extent",[]) == [2048,2048]


func _pixels() -> bool:
	return host.image != null \
		and host.image.get_width() == 2048 and host.image.get_height() == 2048 \
		and host.image.get_pixelv(PAINT_A).r8 == 58 \
		and host.image.get_pixelv(PAINT_B).r8 == 58


func _finish() -> void:
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	print("WB_AGENT_DISABLED: %d assertions, %d failures, second_process=%s" % [
		checks, failures, OS.get_environment("WB_AGENT_DISABLED_REOPEN") == "1"])
	quit(1 if failures else 0)


func _run() -> void:
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	panel = host.shared_workbench
	if not await _wait_for(Callable(self,"_ready"),
			"real native shared workbench failed to initialize"):
		_finish()
		return
	panel._name.text = NAME
	if OS.get_environment("WB_AGENT_DISABLED_REOPEN") == "1":
		if _check(panel.load_setup(),"manual named-start reopen refused") \
				and await _wait_for(Callable(self,"_pixels"),
					"separate-process native/render readback lost both manual Hard Wall edits"):
			var source: Dictionary = Setup.read_named(NAME)
			_check(not source.has("error") and source.get("setup",{}).get("edits",[]).size() >= 2,
				"named-start persisted manual brush operations incorrectly")
			_check(host.paused and not host.simulation_worker.has_failed(),
				"saved manual session did not reopen paused and healthy")
		# The first process's file is deleted only after the second-process
		# correctness checks, even when they fail, on this isolated CI runner.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Setup._path(NAME)))
	else:
		var candidate: Dictionary = Setup.fresh(
			PackedInt32Array(panel.applied.liquid_policy),Vector2i(2048,2048))
		if not _check(panel.apply(candidate),"real native blank 2048 workbench refused") \
				or not await _wait_for(Callable(self,"_fresh_ready"),
					"2048 native owner did not accept manual setup"):
			_finish()
			return
		panel._name.text = NAME
		_check(panel.paint(PAINT_A,58),"ordinary manual Hard Wall brush A refused")
		_check(panel.paint(PAINT_B,58),"ordinary manual distant Hard Wall brush B refused")
		if await _wait_for(Callable(self,"_pixels"),
				"real native/render did not display manual brush results"):
			_check(panel.save_setup(),"manual named authored-start save failed")
			var saved: Dictionary = Setup.read_named(NAME)
			_check(not saved.has("error") \
				and saved.get("setup",{}).get("edits",[]).size() >= 2,
				"manual authored-start file did not retain both stamps")
		_check(host.paused and not host.simulation_worker.has_failed(),
			"agent-disabled manual editor became unavailable")
	_finish()
