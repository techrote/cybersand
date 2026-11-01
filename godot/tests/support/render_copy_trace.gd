extends RefCounted

# Derived from #335 corrected graphical apparatus. Explicit test objects only. Never installed by ordinary application code.
# Stop recording at capacity (do not overwrite causal history); lost events fail a run.
const CAPACITY := 32768
var events: Array[Dictionary] = []
var counts: Dictionary = {}
var dropped: int = 0
var mutex := Mutex.new()

func record(kind: String, fields: Dictionary = {}) -> void:
	var event := fields.duplicate(true)
	event["event"] = kind
	event["usec"] = Time.get_ticks_usec()
	mutex.lock()
	counts[kind] = int(counts.get(kind, 0)) + 1
	if events.size() < CAPACITY:
		event["event_sequence"] = events.size() + 1
		events.append(event)
	else:
		dropped += 1
	mutex.unlock()

func result() -> Dictionary:
	mutex.lock()
	var copied := {"events": events.duplicate(true), "counts": counts.duplicate(), "dropped": dropped}
	mutex.unlock()
	return copied

func total(kind: String) -> int:
	mutex.lock()
	var value: int = int(counts.get(kind, 0))
	mutex.unlock()
	return value
