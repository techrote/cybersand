extends "res://tests/play_life001_shared_host_case.gd"

# PLAY-LIFE-010 supplements, and does not replace, LIFE001's 50 real lifetimes
# per OS. Main/native/Rapier callbacks are automatic. Synthetic focus/aim and
# explicitly adversarial delivery/preconsume scheduling are the only seams.
const Probe = preload("res://tests/play_life010_live_delivery_worker.gd")
const Usables = preload("res://scripts/physical_usable_runtime.gd")
const UsableCatalog = preload("res://scripts/usable_catalog.gd")
var desktop: Control
var worker: Probe
var fixture_started_usec: int = 0
var artifact_directory: String = ""
var result: Dictionary = {}


class CounterBypass:
	extends "res://scripts/snapshot_publication_counter.gd"
	func observe(serial: int) -> bool:
		# Negative control: disable only the duplicate/older refusal. The real
		# consumer, native publisher and Rapier owner are otherwise unchanged.
		if serial <= last_serial:
			return true
		return super.observe(serial)


class ObservedMain:
	extends "res://scripts/main.gd"
	const WorkerProbe = preload("res://tests/play_life010_live_delivery_worker.gd")
	var bypass_serial_guard: bool = false
	var main_callbacks: int = 0
	var physics_callbacks: int = 0
	var completed_steps: int = 0
	var observations: Array[Dictionary] = []
	var first_main_callback_usec: int = 0
	var receipt_steps: Array[Dictionary] = []
	var receipt_overflow: bool = false

	func _ready() -> void:
		# Replace only the unstarted allocation, before the inherited startup.
		# Exactly one worker is live; there is no new loop or second World.
		simulation_worker = WorkerProbe.new()
		if bypass_serial_guard:
			worker_publication_counter = CounterBypass.new()
		super._ready()

	func _actor_window_has_focus() -> bool:
		return true

	func actor_pointer_aim() -> Vector2:
		# Deterministic synthetic pointer direction, not device qualification.
		return Vector2.RIGHT

	func state() -> Dictionary:
		if latest_snapshot == null or physical_actor_session == null:
			return {}
		var view: Dictionary = physical_actor_session.snapshot().actors[0]
		var item: Dictionary = view.equipment
		return {"worker":simulation_worker.get_instance_id(),
			"session":physical_actor_session.get_instance_id(), "bridge":rapier_bridge.get_instance_id(),
			"run_id":view.run_id, "epoch":_physical_epoch, "control_generation":view.control_generation,
			"last_sequence":view.last_sequence, "pending_edges":view.pending_input_edges,
			"world_generation":latest_snapshot.render_world_generation,
			"consumed_serial":consumed_snapshot_serial, "latest_serial":latest_snapshot.serial,
			"rejected":worker_publication_counter.rejected, "native_tick":latest_snapshot.tick_index,
			"physics_tick":view.tick, "bridge_step":rapier_bridge.manual_step_count(),
			"body_result_serial":rapier_bridge._last_result_snapshot_serial,
			"body_sample_serials":Array(rapier_bridge._applied_sample_serials),
			"terrain_revision":last_hard_surface_revision,
			"terrain_pending":rapier_bridge.pending_hard_surface_chunks(),
			"terrain_shapes":rapier_bridge.hard_surface_shape_count(),
			"terrain_ready":_physical_terrain_ready,
			"uploaded_generation":last_uploaded_world_generation,
			"uploaded_render_serial":last_uploaded_render_snapshot_serial,
			"lap_epoch":_playable_course_progress.actor_epoch,
			"lap_generation":_playable_course_progress.world_generation,
			"lap_source_tick":_playable_course_progress.last_source_tick,
			"lap_physics_tick":_playable_course_progress.last_physics_tick,
			"lap_target":_playable_course_progress.target_index,
			"lap_elapsed":_playable_course_progress.elapsed_ticks,
			"accepted_uses":item.get("accepted_uses", 0),
			"receipt":item.get("last_receipt", {}).duplicate(true),
			"recoil":item.get("last_recoil", Vector2.ZERO), "paused":paused,
			"fault":view.get("fault", ""), "main_callbacks":main_callbacks,
			"physics_callbacks":physics_callbacks, "completed_steps":completed_steps}

	func consume_worker_snapshot() -> void:
		var probe: WorkerProbe = simulation_worker as WorkerProbe
		var count: int = probe.deliveries.size()
		var before: Dictionary = state() if probe.delivery_slot >= 0 else {}
		super.consume_worker_snapshot()
		if probe.deliveries.size() > count:
			observations.append({"delivery":probe.deliveries[-1].duplicate(true),
				"before":before, "after":state()})

	func _process(delta: float) -> void:
		main_callbacks += 1
		super._process(delta)
		if first_main_callback_usec == 0:
			first_main_callback_usec = Time.get_ticks_usec()

	func refresh_actor_usables() -> void:
		var before: Dictionary = state()
		super.refresh_actor_usables()
		var after: Dictionary = state()
		if before.is_empty() or after.is_empty() or after.accepted_uses <= before.accepted_uses:
			return
		if receipt_steps.size() >= 4:
			receipt_overflow = true
			return
		receipt_steps.append({"request_id":after.receipt.get("request_id", ""),
			"admitted_usec":Time.get_ticks_usec(), "admitted":after, "completed":{}})

	func _physics_process(delta: float) -> void:
		physics_callbacks += 1
		var tick: int = physical_actor_session.tick if physical_actor_session != null else -1
		var step: int = rapier_bridge.manual_step_count()
		super._physics_process(delta)
		if physical_actor_session != null and tick >= 0 \
			and physical_actor_session.tick == tick + 1 and rapier_bridge.manual_step_count() == step + 1:
			completed_steps += 1
			for receipt: Dictionary in receipt_steps:
				if not receipt.completed.is_empty():
					continue
				var after: Dictionary = state()
				var same_identity: bool = true
				for key: String in ["worker", "session", "bridge", "run_id", "epoch", "control_generation"]:
					same_identity = same_identity and after[key] == receipt.admitted[key]
				if same_identity and after.physics_tick > receipt.admitted.physics_tick \
					and after.bridge_step > receipt.admitted.bridge_step:
					receipt.completed = after
					receipt["completed_usec"] = Time.get_ticks_usec()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		result.errors.append(message)
		push_error("PLAY_LIFE010: " + message)


func bounded(predicate: Callable, label: String) -> bool:
	var started: int = Time.get_ticks_usec()
	var deadline: int = mini(started + WAIT_TIMEOUT_MS * 1000, fixture_started_usec + Watchdogs.microseconds("complex_fixture_seconds"))
	var passed: bool = false
	while Time.get_ticks_usec() < deadline:
		if predicate.call():
			passed = Time.get_ticks_usec() <= deadline
			break
		await process_frame
	result.waits.append({"name":label, "started_usec":started, "deadline_usec":deadline,
		"ended_usec":Time.get_ticks_usec(), "passed":passed})
	expect(passed, label)
	return passed


func release_controls() -> void:
	super.release_controls()
	for code: Key in [KEY_M, KEY_N, KEY_U, KEY_P, KEY_ESCAPE]:
		parse_key(code, false)


func item() -> Dictionary:
	return desktop.physical_actor_session.snapshot().actors[0].equipment


func ready_for_input() -> bool:
	return actor_ready(desktop, target_rig()) and not desktop._actor_input_rearm \
		and not desktop._actor_usable_pointer_rearm and not desktop.paused


func advanced(reference: Dictionary, ticks: int = 3) -> bool:
	var value: Dictionary = desktop.state()
	var progressed: bool = not value.is_empty() and value.native_tick > reference.native_tick \
		and value.physics_tick >= reference.physics_tick + ticks \
		and value.completed_steps >= reference.completed_steps + ticks
	if progressed:
		result.progress.append({"before":reference, "after":value, "minimum_steps":ticks})
	return progressed


func packet_captured(count: int) -> bool:
	return worker.packets.size() >= count


func delivery_observed(count: int) -> bool:
	return desktop.observations.size() >= count


func gate_extracted() -> bool:
	return bool(worker.gate_state().get("extracted", false))


func gate_returned() -> bool:
	return bool(worker.gate_state().get("returned", false))


func physical_step_while_held(reference: Dictionary) -> bool:
	var value: Dictionary = desktop.state()
	return value.physics_tick > reference.physics_tick \
		and value.completed_steps > reference.completed_steps \
		and value.main_callbacks > reference.main_callbacks


func equipment_ready() -> bool:
	return ready_for_input() and not desktop._actor_usable_transition_pending \
		and int(item().get("usable_index", -1)) == UsableCatalog.index_for(&"impact_slug") \
		and bool(item().get("ready", false)) and bool(item().get("clearance", false))


func uses_reached(count: int) -> bool:
	return int(item().get("accepted_uses", 0)) >= count


func pause_acknowledged() -> bool:
	return desktop.paused and desktop.latest_snapshot.paused \
		and bool(desktop.physical_actor_session.snapshot().actors[0].suspended)


func receipt_completed(request_id: String) -> bool:
	for receipt: Dictionary in desktop.receipt_steps:
		if receipt.request_id == request_id and not receipt.completed.is_empty():
			return true
	return false


func first_main_acknowledged(origin: int) -> bool:
	# The origin precedes load/instantiation/add_child, whose synchronous work
	# can block before any await. Never restart this clock after a late return.
	# This first-callback guard is separate from PACE's Build-to-actor timer.
	var deadline: int = origin + Watchdogs.microseconds("main_ack_seconds")
	while Time.get_ticks_usec() < deadline and desktop.first_main_callback_usec == 0:
		await process_frame
	var acknowledged: int = desktop.first_main_callback_usec
	var passed: bool = acknowledged > origin and acknowledged <= deadline
	result.first_main_acks.append({"origin_usec":origin, "deadline_usec":deadline,
		"acknowledged_usec":acknowledged, "observed_usec":Time.get_ticks_usec(),
		"origin":"before-main-scene-load", "event":"first-inherited-Main-process-return", "passed":passed})
	expect(passed, "first actual Main callback acknowledges within the configured Main acknowledgement watchdog")
	return passed


func capture(label: String) -> int:
	var slot: int = worker.packets.size()
	expect(worker.request_capture(label), label + ": bounded genuine packet capture armed")
	if not await bounded(Callable(self, "packet_captured").bind(slot + 1), label + ": real publication retained"):
		return -1
	expect(worker.packets[slot].owner_running and worker.packets[slot].size > 0,
		label + ": bytes came from the same running owner")
	return slot


static func serial_guard_error(observation: Dictionary) -> String:
	var before: Dictionary = observation.before
	var after: Dictionary = observation.after
	if int(after.consumed_serial) < int(before.consumed_serial) \
		or int(after.latest_serial) < int(before.latest_serial):
		return "consumer_serial_regressed"
	if observation.delivery.serial > before.consumed_serial:
		return "control_did_not_deliver_stale_packet"
	if after.rejected != before.rejected + 1:
		return "consumer_did_not_refuse_stale_packet"
	for key: String in before:
		if key != "rejected" and after.get(key) != before[key]:
			return "stale_consumer_mutation:" + key
	if observation.delivery.captured_sha256 != observation.delivery.delivery_sha256:
		return "retained_packet_mutated"
	if not observation.delivery.owner_running or observation.delivery.owner != before.worker:
		return "publisher_not_same_live_owner"
	return ""


func deliver(slot: int, label: String, expected_error: String = "") -> bool:
	var count: int = desktop.observations.size()
	expect(worker.deliver(slot, label), label + ": one bounded consumer delivery armed")
	if not await bounded(Callable(self, "delivery_observed").bind(count + 1), label + ": automatic Main consumed seam"):
		return false
	var observed: Dictionary = desktop.observations[-1]
	expect(observed.delivery.owner_running and observed.delivery.owner == observed.before.worker
		and observed.delivery.captured_sha256 == observed.delivery.delivery_sha256,
		label + ": authentic unchanged packet delivered while the same owner is alive")
	var error: String = serial_guard_error(observed)
	observed["oracle_error"] = error
	expect(error == expected_error, label + ": expected oracle outcome " + expected_error + ", got " + error)
	return error == expected_error


func start_host(negative: bool) -> bool:
	release_controls()
	var host_started_usec: int = Time.get_ticks_usec()
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(ObservedMain)
	desktop.bypass_serial_guard = negative
	root.add_child(desktop)
	await process_frame
	worker = desktop.simulation_worker as Probe
	expect(worker != null and desktop.worker_start_error == OK and worker._thread.is_started(),
		"Main starts exactly the inherited live native owner")
	if worker == null or desktop.worker_start_error != OK:
		return false
	if not await first_main_acknowledged(host_started_usec):
		return false
	var panel = desktop.playable_session_panel
	panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(target_rig()))
	panel.control_choice.select(1) # Keyboard only; no physical gamepad claim.
	expect(panel.build_selected(), "normal integrated Play panel admits authored course/rig")
	if not await bounded(Callable(self, "actor_ready").bind(desktop, target_rig()), "construction and terrain ready"):
		return false
	expect(desktop.paused, "normal construction starts paused")
	panel.resume_play()
	if not await bounded(Callable(self, "ready_for_input"), "normal resume and neutral rearm"):
		return false
	var before: Dictionary = desktop.state()
	if not await bounded(Callable(self, "advanced").bind(before), "live native and automatic Rapier progress"):
		return false
	expect(str(desktop.latest_snapshot.backend_name).contains("native"), "real native backend selected")
	return true


func close_host(label: String) -> void:
	var closing: int = Time.get_ticks_usec()
	var final_state: Dictionary = desktop.state() if is_instance_valid(desktop) else {}
	var final_session: Variant = desktop.physical_actor_session if is_instance_valid(desktop) else null
	var observations: Array = desktop.observations.duplicate(true) if is_instance_valid(desktop) else []
	var receipt_steps: Array = desktop.receipt_steps.duplicate(true) if is_instance_valid(desktop) else []
	expect(not desktop.receipt_overflow, label + ": physical receipt trace remains bounded")
	var held_worker: Probe = worker
	await close_cycle(desktop, held_worker, final_session, label + ": ")
	var elapsed: int = Time.get_ticks_usec() - closing
	expect(elapsed <= Watchdogs.microseconds("operation_seconds"), label + ": complete teardown stays within the operation watchdog")
	var packet_records: Array = held_worker.save_packets(artifact_directory, str(target_rig()) + "-" + label)
	for packet: Dictionary in packet_records:
		expect(packet.artifact_written and packet.sha256 == packet.retired_sha256
			and packet.json_sha256 == packet.retired_json_sha256,
			label + ": full authentic packet bytes unchanged through worker join")
	expect(not held_worker.capture_overflow and held_worker.packets.size() <= Probe.MAX_PACKETS,
		label + ": retention remains bounded")
	result.lifetimes.append({"name":label, "final":final_state, "packets":packet_records,
		"deliveries":observations, "gates":held_worker.gate_history(), "receipt_steps":receipt_steps,
		"teardown_usec":elapsed, "worker_joined":not held_worker._thread.is_started(),
		"session_retired":not is_instance_valid(final_session), "host_freed":not is_instance_valid(desktop),
		"normal_handoffs":held_worker.normal_handoffs})
	desktop = null
	worker = null


func negative_control() -> bool:
	if not await start_host(true):
		return false
	var slot: int = await capture("negative-authentic-A")
	if slot < 0:
		return false
	var before: Dictionary = desktop.state()
	if not await bounded(Callable(self, "advanced").bind(before), "negative newer genuine publication and physics"):
		return false
	return await deliver(slot, "counter-bypass", "consumer_serial_regressed")


func packet_controls() -> bool:
	var a: int = await capture("live-A")
	if a < 0:
		return false
	var before: Dictionary = desktop.state()
	if not await bounded(Callable(self, "advanced").bind(before), "publisher and physics advance before B"):
		return false
	var b: int = await capture("live-B")
	if b < 0:
		return false
	expect(worker.packets[b].serial > worker.packets[a].serial, "B is an authentic later publication")
	if not await deliver(b, "duplicate-current"):
		return false
	expect(desktop.observations[-1].delivery.serial == desktop.observations[-1].before.consumed_serial,
		"duplicate control delivered the exact currently consumed serial")
	if not await deliver(a, "delayed-A"):
		return false
	before = desktop.state()
	if not await bounded(Callable(self, "advanced").bind(before), "publisher and Rapier remain live after delayed delivery"):
		return false
	if not await deliver(b, "out-of-order-B"):
		return false
	expect(desktop.observations[-1].delivery.serial < desktop.observations[-1].before.consumed_serial,
		"out-of-order B is older than an already applied genuine later publication")
	# Ordinary nonneutral input starts real source-bound lap accounting.
	before = desktop.state()
	parse_key(KEY_D, true)
	var progressed: bool = await bounded(Callable(self, "advanced").bind(before), "nonneutral input completes real Rapier steps")
	parse_key(KEY_D, false)
	expect(desktop._playable_course_progress.started and desktop._playable_course_progress.elapsed_ticks > 0,
		"course clock advances from real native/physical observations")
	return progressed


func equipment_gate(label: String, cancelled: bool) -> bool:
	if not await bounded(Callable(self, "equipment_ready"), label + ": authored cooldown, mount and neutral rearm ready"):
		return false
	var before: Dictionary = desktop.state()
	expect(worker.arm_gate(label), label + ": preconsume scheduling gate armed")
	parse_key(KEY_M, true)
	parse_key(KEY_M, false)
	var queued_edges: Array = desktop.physical_actor_session._button_edges[0].duplicate(true)
	var sequence_after: int = int(desktop.physical_actor_session.snapshot().actors[0].last_sequence)
	expect(queued_edges.size() == 2 and queued_edges[0] == {"button":"equipment_trigger", "pressed":true}
		and queued_edges[1] == {"button":"equipment_trigger", "pressed":false}
		and sequence_after >= int(before.last_sequence) + 2,
		label + ": ordinary quick M press/release creates two ordered admitted equipment edges")
	if not await bounded(Callable(self, "gate_extracted"), label + ": actual keyboard request extracted by live owner"):
		worker.release_gate()
		return false
	var extracted: Dictionary = worker.gate_state()
	expect(extracted.requests.size() == 1 and extracted.allowed,
		label + ": exactly one genuine admitted request reached inherited owner boundary")
	var request: Dictionary = extracted.requests[0]
	var held_before: Dictionary = desktop.state()
	if not await bounded(Callable(self, "physical_step_while_held").bind(held_before),
		label + ": automatic Main and Rapier continue while actual request is held"):
		worker.release_gate()
		return false
	var held_after: Dictionary = desktop.state()
	var still_held: Dictionary = worker.gate_state()
	expect(not still_held.released and not still_held.returned and not still_held.timed_out,
		label + ": physical progress occurred before native preconsume gate release")
	var frame: Dictionary = desktop.physical_actor_session.equipment_frame()
	var current: Dictionary = Usables.actor_row(frame, 0)
	var captured: Dictionary = Usables.actor_row(extracted.frame, 0)
	var lease_valid: bool = Usables.request_error(request, frame).is_empty() \
		and int(frame.tick) < int(current.lease_deadline) and int(frame.tick) < int(captured.lease_deadline)
	expect(lease_valid, label + ": request is still within its actual live lease before action")
	var control: Dictionary = {"name":label, "before":before, "request":request.duplicate(true),
		"lease_frame_tick":frame.tick, "lease_deadline":current.lease_deadline,
		"extracted_lease_deadline":captured.lease_deadline,
		"lease_valid":lease_valid, "cancelled":cancelled,
		"queued_edges":queued_edges, "input_sequence_after":sequence_after,
		"held_before":held_before, "held_after":held_after, "held_before_release":not still_held.released,
		"held_observed_usec":Time.get_ticks_usec()}
	if cancelled:
		parse_key(KEY_P, true)
		parse_key(KEY_P, false)
		control["after_cancel"] = desktop.state()
		expect(desktop.paused and control.after_cancel.control_generation > before.control_generation,
			label + ": ordinary pause revokes generation before the worker gate is released")
		expect(not bool(item().pending) and not desktop.physical_actor_session._button_edges[0].size(),
			label + ": pending request and ordered input edges are retired immediately")
	worker.release_gate()
	if not await bounded(Callable(self, "gate_returned"), label + ": inherited native equipment consumer returned"):
		return false
	var returned: Dictionary = worker.gate_state()
	var native_receipts: Array = returned.runtime_after.get("receipts", [])
	var native_accepted: int = 0
	for receipt: Dictionary in native_receipts:
		if receipt.get("request_id") == request.request_id and receipt.get("accepted", false) and receipt.get("consumed", false):
			native_accepted += 1
	control["native_matching_accepts"] = native_accepted
	control["gate_returned"] = returned.returned
	expect(not returned.timed_out and not returned.release_from_stop,
		label + ": normal explicit release, never timeout or shutdown fallback")
	if cancelled:
		if not await bounded(Callable(self, "pause_acknowledged"), label + ": native pause acknowledged"):
			return false
		expect(native_accepted == 0 and int(item().accepted_uses) == before.accepted_uses \
			and item().last_recoil == before.recoil,
			label + ": cancellation prevents native commit and physical use/recoil")
		parse_key(KEY_P, true)
		parse_key(KEY_P, false)
		if not await bounded(Callable(self, "ready_for_input"), label + ": resume with fresh neutral generation"):
			return false
		frame = desktop.physical_actor_session.equipment_frame()
		var refused: Dictionary = worker.set_physical_usable_state(frame, [request], desktop.pack_rigid_body_states())
		control["old_generation_admission"] = refused
		expect(refused.status == "refused" and refused.reason == "generation",
			label + ": actual old request cannot cross the replacement control generation")
	else:
		if not await bounded(Callable(self, "uses_reached").bind(int(before.accepted_uses) + 1), label + ": native receipt completes physical use"):
			return false
		if not await bounded(Callable(self, "receipt_completed").bind(str(request.request_id)),
			label + ": accepted receipt precedes a completed automatic Rapier step"):
			return false
		for receipt: Dictionary in desktop.receipt_steps:
			if receipt.request_id == request.request_id:
				control["receipt_step"] = receipt.duplicate(true)
		expect(native_accepted == 1 and int(item().accepted_uses) == int(before.accepted_uses) + 1,
			label + ": matching uncancelled request commits once on native and physical owners")
		expect(item().last_receipt.get("request_id") == request.request_id \
			and Vector2(item().last_recoil).length_squared() > 0.0,
			label + ": actual receipt identity and nonzero physical recoil agree")
	control["after"] = desktop.state()
	var same_owner: bool = true
	for key: String in ["worker", "session", "bridge", "run_id", "epoch", "world_generation"]:
		same_owner = same_owner and control.after[key] == before[key]
	expect(same_owner, label + ": equipment scheduling/cancellation preserves both live owners")
	result.equipment.append(control)
	return lease_valid


func positive_controls() -> bool:
	if not await start_host(false) or not await packet_controls():
		return false
	expect(desktop.apply_actor_equipment_configuration(UsableCatalog.index_for(&"impact_slug"), 0.25),
		"normal equip-only route selects existing authored projectile without replacing actor")
	if not await equipment_gate("uncancelled-positive", false):
		return false
	var receipt_slot: int = await capture("committed-receipt")
	if receipt_slot < 0 or not await deliver(receipt_slot, "duplicate-receipt-packet"):
		return false
	var uses: int = int(item().accepted_uses)
	var receipt_feedback: Dictionary = worker.packets[receipt_slot].packet.physical_usables
	var feedback_before: Dictionary = item()
	var accepted: int = desktop.physical_actor_session.accept_equipment_feedback(receipt_feedback)
	expect(accepted == 0 and item() == feedback_before,
		"deep receipt consumer also refuses authentic duplicate receipt without repeat recoil")
	if not await equipment_gate("lease-valid-cancellation", true):
		return false
	if not await equipment_gate("fresh-generation-recovery", false):
		return false
	expect(int(item().accepted_uses) == uses + 1,
		"only fresh post-cancellation press adds one physical equipment use")
	var first: Dictionary = result.equipment[0].request
	var cancelled_request: Dictionary = result.equipment[1].request
	var recovered: Dictionary = result.equipment[2].request
	expect(first.sequence < cancelled_request.sequence and cancelled_request.sequence < recovered.sequence \
		and first.request_id != cancelled_request.request_id and cancelled_request.request_id != recovered.request_id,
		"ordered press identifiers preserve accepted, cancelled and recovered outcomes")
	var old_slot: int = await capture("pre-reconstruction")
	if old_slot < 0:
		return false
	var old_state: Dictionary = desktop.state()
	var old_session = desktop.physical_actor_session
	desktop.playable_session_panel.restart_applied()
	if not await bounded(Callable(self, "reset_installed").bind(desktop, target_rig(),
		int(old_state.epoch), int(old_state.world_generation)), "normal reset reconstructs actual actor and native World"):
		return false
	expect(not is_instance_valid(old_session), "reset retires the original Rapier owner")
	desktop.playable_session_panel.resume_play()
	if not await bounded(Callable(self, "ready_for_input"), "replacement owner neutral rearm"):
		return false
	var reset_state: Dictionary = desktop.state()
	if not await bounded(Callable(self, "advanced").bind(reset_state), "replacement native and Rapier progress"):
		return false
	expect(desktop.state().run_id != old_state.run_id, "reconstruction supplies a new physical run identity")
	if not await deliver(old_slot, "old-epoch-world-body-terrain"):
		return false
	feedback_before = item()
	expect(desktop.physical_actor_session.accept_equipment_feedback(receipt_feedback) == 0 and item() == feedback_before,
		"old run and epoch receipt cannot mutate replacement equipment")
	var old_admission: Dictionary = worker.set_physical_usable_state(
		desktop.physical_actor_session.equipment_frame(), [recovered], desktop.pack_rigid_body_states())
	expect(old_admission.status == "refused" and old_admission.reason == "epoch",
		"actual old request is refused at inherited worker admission after reconstruction")
	result["reconstruction"] = {"before":old_state, "after":desktop.state(), "old_request_admission":old_admission}
	expect(not worker.has_failed(), "exclusive native owner remains outside failure quarantine")
	return true


func run() -> void:
	fixture_started_usec = Time.get_ticks_usec()
	result = {"schema":"play-life010-v1", "rig":str(target_rig()),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"fixture_sha256":FileAccess.get_sha256("res://tests/play_life010_live_delivery_case.gd"),
		"worker_sha256":FileAccess.get_sha256("res://tests/play_life010_live_delivery_worker.gd"),
		"engine":Engine.get_version_info().string, "platform":OS.get_name(),
		"display_server":DisplayServer.get_name(), "graphical_qualification":false,
		"seams":["synthetic-focus-and-pointer-aim", "authentic-consumer-delivery", "actual-extracted-request-preconsume-gate"],
		"operation_limit_usec":Watchdogs.microseconds("operation_seconds"), "fixture_limit_usec":Watchdogs.microseconds("complex_fixture_seconds"),
		"first_main_ack_limit_usec":Watchdogs.microseconds("main_ack_seconds"), "first_main_acks":[],
		"waits":[], "errors":[], "lifetimes":[], "equipment":[], "progress":[]}
	artifact_directory = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	expect(target_rig() in Course.MECHANICAL_PRESETS, "wrapper selects an accepted mechanical rig")
	expect(result.source_revision.length() == 40, "source identity is supplied by qualification runner")
	expect(not artifact_directory.is_empty(), "retained raw packet directory is supplied by qualification runner")
	if artifact_directory.is_empty():
		print("PLAY_LIFE010_RESULT ", JSON.stringify(result))
		quit(1)
		return
	expect(DirAccess.make_dir_recursive_absolute(artifact_directory) == OK, "raw packet directory is writable")
	var negative_ok: bool = await negative_control()
	if desktop != null:
		await close_host("negative")
	expect(negative_ok, "real-host serial-bypass control fails exactly for serial regression")
	var positive_ok: bool = await positive_controls()
	if desktop != null:
		await close_host("guarded")
	expect(positive_ok, "complete live delivery/equipment/reconstruction sequence finishes")
	expect(result.lifetimes.size() == 2 and joined_workers == 2 and retired_sessions == 2,
		"two sequential real lifetimes are completely joined and retired")
	var retained_count: int = 0
	for lifetime: Dictionary in result.lifetimes:
		retained_count += lifetime.packets.size()
	expect(retained_count <= 8, "fixture retains at most eight authentic immutable packets total")
	result["elapsed_usec"] = Time.get_ticks_usec() - fixture_started_usec
	expect(result.elapsed_usec <= Watchdogs.microseconds("complex_fixture_seconds"), "complete fixture including both teardowns stays within the fixture watchdog")
	result["assertions"] = assertions
	result["failures"] = failures
	result["negative_control_passed"] = negative_ok
	result["positive_controls_passed"] = positive_ok
	var output := FileAccess.open(artifact_directory.path_join(str(target_rig()) + "-life010.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(result, "\t") + "\n")
		output.close()
	else:
		failures += 1
	print("PLAY_LIFE010_RESULT ", JSON.stringify(result))
	print("PLAY_LIFE010_SUMMARY assertions=", assertions, " failures=", failures)
	quit(1 if failures else 0)
