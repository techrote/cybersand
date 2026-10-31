extends SceneTree

const Trace = preload("res://tests/render_publication_trace.gd")
var failures: int = 0

func _init() -> void:
	var trace = Trace.new()
	trace.record("refresh", {"serial": 1})
	trace.record("refresh", {"serial": 2})
	var copy: Dictionary = trace.result()
	copy.events[0].serial = 99
	_expect(trace.result().events[0].serial == 1, "consumer mutated retained evidence")
	_expect(trace.result().counts.refresh == 2, "monotonic owner counter lost refresh")
	for index: int in range(Trace.CAPACITY): trace.record("bounded", {"index": index})
	var full: Dictionary = trace.result()
	_expect(full.events.size() == Trace.CAPACITY and full.dropped == 2, "bounded recorder did not retain first events and count losses")
	_expect(full.counts.bounded == Trace.CAPACITY, "counter stopped at trace capacity")
	_expect(full.events[0].serial == 1 and full.events[1].serial == 2, "bounded trace overwrote causal history")
	print("RENDER_PUBLICATION_TRACE: 5 assertions, %d failures" % failures)
	quit(failures)

func _expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
