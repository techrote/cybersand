extends SceneTree

func _initialize() -> void:
	var descriptor := "res://tests/performance/rapier_thread_probe/rapier_thread_probe.gdextension"
	var status := GDExtensionManager.load_extension(descriptor)
	if not ClassDB.class_exists(&"CyberRapierThreadProbe"):
		push_error("thread probe class missing; extension load status " + str(status))
		quit(1)
		return
	var before: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample")
	OS.delay_msec(80)
	var after_sleep: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample")
	var stop := Time.get_ticks_usec() + 80000
	var work: int = 1
	while Time.get_ticks_usec() < stop:
		work = (work * 3 + 7) % 65521
	var after_work: PackedInt64Array = ClassDB.class_call_static(&"CyberRapierThreadProbe", &"sample")
	var pass_check := before.size() == 10 and after_sleep.size() == 10 and after_work.size() == 10
	pass_check = pass_check and before[0] == 1 and before[1] == after_work[1]
	pass_check = pass_check and before[8] == 0 and before[9] == 0 and after_work[8] == 0 and after_work[9] == 0
	pass_check = pass_check and after_work[5] + after_work[6] > after_sleep[5] + after_sleep[6]
	var result := {"schema": "rapier-thread-probe-smoke-v1", "passed": pass_check,
		"before": Array(before), "after_sleep": Array(after_sleep),
		"after_work": Array(after_work), "work": work}
	print("RAPIER_THREAD_PROBE_SMOKE ", JSON.stringify(result))
	quit(0 if pass_check else 1)
