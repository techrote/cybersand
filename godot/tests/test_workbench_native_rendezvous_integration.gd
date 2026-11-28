extends "res://tests/test_workbench_physics_publication.gd"

# Reuse the actual Workbench/native/Rapier publication fixture and all of its
# owner, terrain, pause, single-step and shutdown assertions. Only test pacing
# is30 process frames /60 real physics callbacks, so catch-up is exercised.
# This is guard integration, not a performance result or a new physics clock.
class RecordedRendezvous extends "res://scripts/workbench_native_rendezvous.gd":
	const CAPACITY: int = 4096
	var waits: Array[Dictionary] = []
	var dropped: int = 0

	func wait_for_sample(poll_mailbox: Callable, expected: Dictionary) -> Dictionary:
		var result: Dictionary = super.wait_for_sample(poll_mailbox, expected)
		var record: Dictionary = result.duplicate()
		record.erase("snapshot")
		record["expected"] = expected.duplicate()
		if waits.size() < CAPACITY: waits.append(record)
		else: dropped += 1
		return result

var rendezvous_recorders: Array[RecordedRendezvous] = []


func _initialize() -> void:
	OS.set_environment("CYBERSAND_DIAG_NATIVE_RENDEZVOUS", "1")
	Engine.max_fps = 30
	Engine.physics_ticks_per_second = 60
	_run.call_deferred()


func install() -> bool:
	var installed: bool = await super.install()
	if installed:
		var recorder := RecordedRendezvous.new()
		host._workbench_native_rendezvous = recorder
		rendezvous_recorders.append(recorder)
		check(host.native_rendezvous_status().enabled \
			and host.native_rendezvous_status().max_frame_wait_usec == 16667 \
			and host.engine_lab_wait_native_sample,
			"actual Main enables bounded rendezvous with ordinary strict native wait")
	return installed


func stalled_completion(combined: bool) -> void:
	var before: int = observations.size()
	await super.stalled_completion(combined)
	if observations.size() == before or rendezvous_recorders.is_empty(): return
	var mode: String = "combined" if combined else "early"
	var held: Dictionary = worker.status()
	var completion: CyberSimulationSnapshot = held.completion
	var full: CyberSimulationSnapshot = held.full
	if full == null or (not combined and completion == null): return # Base fixture records the failure.
	# Combined mode has no early completion for this turn. The retained
	# completion can belong to an earlier turn and carries no early clock.
	# Time waits at the injected packing hold, and observe the candidate
	# admission from its actual handoff in early mode.
	var held_started_usec: int = held.held_started_usec
	var hold_released_usec: int = held.released_usec
	check(held_started_usec > 0 and held_started_usec < hold_released_usec \
		and hold_released_usec <= full.worker_handoff_usec,
		mode + " measures a real held interval before the full handoff")
	var recorder: RecordedRendezvous = rendezvous_recorders.back()
	var waits: Array = recorder.waits.filter(func(row: Dictionary) -> bool:
		return int(row.start_usec) >= held_started_usec \
			and int(row.completed_usec) <= hold_released_usec)
	check(not waits.is_empty(), mode + " actual catch-up callbacks enter rendezvous during publication hold")
	check(waits.any(func(row: Dictionary) -> bool: return row.status == "timeout" \
		and int(row.sleeps) > 0 and int(row.polls) > 0),
		mode + " actual Main exhausts a bounded wait while native authority is unavailable")
	var admission_start_usec: int = held_started_usec if combined else completion.physics_handoff_usec
	var admissions: Array = host.admissions.filter(func(row: Dictionary) -> bool:
		return int(row.time_usec) >= admission_start_usec \
			and int(row.time_usec) <= hold_released_usec)
	check(admissions.size() == (0 if combined else 1),
		mode + " no additional physical completion is fabricated by expired waits")
	if not combined and admissions.size() == 1:
		check(admissions[0].completed_sample == completion.lab_context.workbench_completed_sample \
			and admissions[0].pending_chunks == 0 \
			and admissions[0].required_revision == admissions[0].installed_revision,
			"early admission retains exact sample and complete required native terrain")
	observations.append({"mode":mode + "-rendezvous", "real_catchup_waits":waits.size(),
		"waits":waits, "physical_admissions_during_hold":admissions.size(),
		"completion_sample":full.lab_context.workbench_completed_sample,
		"held_started_usec":held_started_usec,"hold_released_usec":hold_released_usec,
		"physics_handoff_usec":completion.physics_handoff_usec if not combined else 0,
		"full_handoff_usec":full.worker_handoff_usec,
		"scope":"Actual engine callbacks; unchanged1/60 manual Rapier step; held native owner cannot produce the next sample."})


func paused_terrain_and_reset() -> void:
	var before: int = rendezvous_recorders.size()
	await super.paused_terrain_and_reset()
	for index: int in range(before, rendezvous_recorders.size()):
		check(rendezvous_recorders[index].waits.is_empty(),
			"paused terrain install/reset/single-step never starts a rendezvous wait")


func owner_retirement_during_render() -> void:
	await super.owner_retirement_during_render()
	check(worker.try_read_physics_mailbox().status == "retired",
		"public owner retirement also fences the nonblocking rendezvous reader")
	var total: int = 0
	for recorder: RecordedRendezvous in rendezvous_recorders:
		check(recorder.dropped == 0, "bounded integration observer retains every wait")
		var frames: Dictionary = {}
		for row: Dictionary in recorder.waits:
			total += 1
			check(int(row.callback_index) >= 2, "rendezvous uses a genuinely scheduled catch-up callback")
			var frame: int = int(row.process_frame)
			if not frames.has(frame):
				frames[frame] = {"deadline":int(row.deadline_usec), "requested_sleep_usec":0}
			check(frames[frame].deadline == int(row.deadline_usec),
				"all callbacks share one absolute deadline in their process frame")
			frames[frame].requested_sleep_usec += int(row.requested_sleep_usec)
		for frame: int in frames:
			check(frames[frame].requested_sleep_usec <= 16667,
				"one process frame never requests more than one fixed-step sleep budget")
	check(total > 0, "actual Main rendezvous integration is not a vacuous pass")
	observations.append({"mode":"rendezvous-budget-summary", "waits":total,
		"max_process_wait_requested_usec":16667, "process_target_hz":30,
		"physics_callback_target_hz":60, "fixed_physics_delta":host.rapier_bridge.fixed_delta(),
		"clock_notice":"Requested sleep budget is bounded; observed wall elapsed can include OS descheduling."})
