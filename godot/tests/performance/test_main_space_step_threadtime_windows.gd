extends "res://tests/performance/test_main_rapier_bridge_split_windows.gd"

# INV-004 Task 2 diagnostic wrapper.
# The parent is the exact #449 graphical Windows ABBA workload. This child adds
# only post-callback clock/thread correlation for the profiler-enabled arms.
# It does not change gameplay, physics, rendering, Rapier, worker cadence, or
# the measured _physics_process interval.

var _thread_rendezvous_written: bool = false

func retain_physics(row: Dictionary) -> void:
	var sync_ticks_usec: int = Time.get_ticks_usec()
	var sync_unix_usec: int = roundi(Time.get_unix_time_from_system() * 1000000.0)
	var caller_thread_id: int = int(OS.get_thread_caller_id())
	var main_thread_id: int = int(OS.get_main_thread_id())
	row["profile_sync_ticks_usec"] = sync_ticks_usec
	row["profile_sync_unix_usec"] = sync_unix_usec
	row["profile_caller_thread_id"] = caller_thread_id
	row["profile_main_thread_id"] = main_thread_id

	if not _thread_rendezvous_written:
		var out: String = OS.get_environment("CYBERSAND_PHASE_OUTPUT")
		if not out.is_empty():
			DirAccess.make_dir_recursive_absolute(out)
			var file: FileAccess = FileAccess.open(out.path_join("thread-rendezvous.json"), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify({
					"schema": "inv154-thread-rendezvous-v1",
					"pid": OS.get_process_id(),
					"caller_thread_id": caller_thread_id,
					"main_thread_id": main_thread_id,
					"sync_ticks_usec": sync_ticks_usec,
					"sync_unix_usec": sync_unix_usec
				}, "\t"))
				file.close()
				_thread_rendezvous_written = true

	super(row)
