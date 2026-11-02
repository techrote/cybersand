extends "res://tests/play_life001_shared_host_case.gd"

# Focused helpers retained from #308 for native-failure recovery and navigation.
# No LIFE006 churn campaign is imported. Main's existing exclusive worker and
# main-thread Rapier stay authoritative; only copied/retired state is inspected.
var TOTAL_BUDGET_MS: int = Watchdogs.milliseconds("complex_fixture_seconds")
var OPERATION_BUDGET_MS: int = Watchdogs.milliseconds("operation_seconds")
var MAIN_ACK_BUDGET_MS: int = Watchdogs.milliseconds("main_ack_seconds")
var deadline_ms: int = 0
var graphs_retired: int = 0


func wait_for(predicate: Callable, timeout_ms: int = -1) -> bool:
	if timeout_ms < 0:
		timeout_ms = OPERATION_BUDGET_MS
	var end_ms: int = mini(deadline_ms, Time.get_ticks_msec() + timeout_ms)
	while Time.get_ticks_msec() < end_ms:
		if predicate.call():
			return Time.get_ticks_msec() <= end_ms
		await process_frame
	return false


func is_launcher() -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://feature_launcher.tscn"


func entered_host() -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://main.tscn" \
		and current_scene.playable_session_panel != null and current_scene.playable_session_panel.visible


func live_clocks(desktop: Control, rig: StringName, native_tick: int, physical_tick: int) -> bool:
	# Headless windows need not report OS focus. Do not bypass Main's real focus
	# predicate or mislabel neutral completed physics as human-control acceptance.
	return actor_ready(desktop, rig) and not desktop.simulation_worker.has_failed() \
		and desktop.latest_snapshot.tick_index > native_tick \
		and desktop.physical_actor_session.tick >= physical_tick + 3


func retained_payload(snapshot: CyberSimulationSnapshot) -> Dictionary:
	return {"serial":snapshot.serial, "tick":snapshot.tick_index,
		"generation":snapshot.render_world_generation, "epoch":snapshot.rigid_body_epoch,
		"cells":snapshot.cells.duplicate(), "render_serial":snapshot.render_snapshot_serial,
		"rectangles":snapshot.render_patch_rectangles.duplicate(),
		"patch_cells":snapshot.render_patch_cells.duplicate(),
		"terrain":snapshot.hard_surface_chunk_rectangles.duplicate(),
		"context":snapshot.lab_context.duplicate(true),
		"effects":snapshot.physical_actor_effects.duplicate(true)}


func graph(desktop: Control) -> Dictionary:
	if desktop.physical_actor_session == null: return {}
	return {"session":desktop.physical_actor_session,
		"bodies":desktop.physical_actor_session.bodies().duplicate(),
		"bridge":desktop.rapier_bridge, "candidate":desktop._accepted_physical_candidate,
		"viewport":desktop._accepted_physical_candidate.viewport \
			if desktop._accepted_physical_candidate != null else null}


func verify_retired(previous: Dictionary, context: String) -> void:
	if previous.is_empty(): return
	var bodies_gone: bool = true
	for body: Variant in previous.bodies:
		bodies_gone = bodies_gone and not is_instance_valid(body)
	var closed: bool = not is_instance_valid(previous.session) and bodies_gone \
		and not previous.bridge.is_initialized() \
		and previous.bridge.hard_surface_shape_count() == 0 \
		and previous.bridge.pending_hard_surface_chunks() == 0 \
		and previous.bridge._body_rids.is_empty() \
		and not is_instance_valid(previous.viewport)
	if previous.candidate != null:
		closed = closed and previous.candidate.session == null and previous.candidate.viewport == null
	expect(closed, context + "old session/bodies/private viewport and bridge collider state retire")
	if closed: graphs_retired += 1


func configure(desktop: Control, rig: StringName, parity: int) -> Dictionary:
	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.actor_choice.select(Course.MECHANICAL_PRESETS.find(rig))
	panel.control_choice.select(parity)
	panel.rule_choice.select(parity)
	panel.camera_choice.select(parity)
	panel.policy_editor.select_preset(2 if parity == 0 else 0)
	return {"selection":panel.selection(), "policy":panel.policy_editor.requested_policy.duplicate()}
