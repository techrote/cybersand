extends "res://tests/test_camera_stack_clocks.gd"

# External qualification fixture: inherits committed mounting/recipe helpers.
# No application or repository source changes.
func _run() -> void:
	var report: Dictionary = {}
	if await mount() and await install():
		configure(1,60,60,false)
		if await play():
			check(host.engine_lab_set_scripted_input(true),"live actor pilot lease starts")
			var native_before: int = host.latest_snapshot.tick_index
			var rapier_before: int = host.physical_actor_session.tick
			var position_before: Vector2 = host.physical_actor_session.workbench_actor_state(1).position
			check(await wait_for(func() -> bool:
				return host.latest_snapshot.tick_index >= native_before+2 and host.physical_actor_session.tick > rapier_before),
				"real native and Rapier continue while Pixel cadence is one Hz")
			var position_after: Vector2 = host.physical_actor_session.workbench_actor_state(1).position
			check(not host.paused and host.engine_lab_scripted_input,"shutdown begins during active simulation and pilot input")
			check(position_after.distance_to(position_before)>0.0,"actual Rapier actor moved at the one Hz Pixel setting")
			report = {"pixel_requested_hz":1,"rapier_requested_hz":60,"render_requested_hz":60,
				"sample_wake":false,"wait_native_sample":false,"native_ticks_before":native_before,
				"native_ticks_after":host.latest_snapshot.tick_index,"rapier_steps_before":rapier_before,
				"rapier_steps_after":host.physical_actor_session.tick,
				"actor_displacement_cells":position_after.distance_to(position_before),
				"paused_at_stop":host.paused,"pilot_active_at_stop":host.engine_lab_scripted_input}
			var worker: RefCounted = host.simulation_worker
			var stop_started: int = Time.get_ticks_usec()
			# Synchronous actual Main deletion calls its original _exit_tree,
			# including physical owners, stop_worker/join, and Rapier shutdown.
			host.free()
			var stop_elapsed_ms: float = float(Time.get_ticks_usec()-stop_started)/1000.0
			report["main_exit_tree_elapsed_ms"] = stop_elapsed_ms
			report["native_owner_thread_joined"] = not worker._thread.is_started()
			report["worker_running_after_stop"] = worker._running
			check(not is_instance_valid(host),"original Main destroyed synchronously")
			check(not worker._thread.is_started() and not worker._running,"actual native owner joined")
			check(stop_elapsed_ms<5000.0,"shutdown bounded by five second qualification watchdog")
			host = null
			worker = null
			if await mount():
				report["fresh_native_owner_started"] = host.simulation_worker._thread.is_started()
				check(host.simulation_worker._thread.is_started(),"fresh actual native owner starts after stop")
				host.free()
				host = null
	if is_instance_valid(host):
		host.free()
		host = null
	print("CAMERA_STACK_SHUTDOWN_1HZ_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"source_commit":OS.get_environment("CYBERSAND_EVAL_SOURCE_SHA"),
		"runtime":{"os":OS.get_name(),"display_server":DisplayServer.get_name(),"godot":Engine.get_version_info().string},
		"measurement_scope":"synchronous actual Main free/_exit_tree, including native worker join; observed bound, not hard real time",
		"unmeasured":["GPU present time","worker wait duration","worker backlog depth"],"result":report}))
	quit(int(not failures.is_empty()))
