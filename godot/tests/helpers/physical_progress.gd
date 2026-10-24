extends RefCounted

# Fixture-only markers: no physics settings, assertions or stepping changes.
const Guard = preload("res://tests/helpers/physical_internal_watchdog.gd")
static var steps: int = 0
static var context: String = ""
static var sequence: int = 0
static var case_name: String = ""
static var guard: Guard

static func begin(name: String) -> bool:
	case_name = name
	steps = 0
	sequence = 0
	context = ""
	guard = Guard.new()
	var result: Error = guard.start(name)
	if result != OK:
		printerr("ERROR: REGRESSION_WATCHDOG start_failed case=", name, " error=", result)
		return false
	return true

static func finish() -> bool:
	if guard == null:
		return true
	var passed: bool = guard.stop()
	if guard.joined():
		guard = null
	return passed

static func mark(phase: String, detail: String = "") -> void:
	if not detail.is_empty():
		context = detail
	sequence += 1
	var marker: Dictionary = {"case": case_name, "phase": phase, "detail": context,
		"steps": steps, "sequence": sequence, "elapsed_ms": Time.get_ticks_msec()}
	if guard != null:
		guard.publish(JSON.stringify(marker))
	print("CYBERSAND_PROGRESS ", JSON.stringify(marker))

static func tick(phase: String) -> void:
	steps += 1
	if steps == 1 or steps % 120 == 0:
		mark(phase)
