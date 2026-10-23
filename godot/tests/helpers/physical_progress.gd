extends RefCounted

# Fixture-only markers: no physics settings, assertions or stepping changes.
static var steps: int = 0

static func mark(phase: String, detail: String = "") -> void:
	print("CYBERSAND_PROGRESS ", JSON.stringify({"phase": phase, "detail": detail,
		"steps": steps, "elapsed_ms": Time.get_ticks_msec()}))

static func tick(phase: String) -> void:
	steps += 1
	if steps == 1 or steps % 120 == 0:
		mark(phase)
