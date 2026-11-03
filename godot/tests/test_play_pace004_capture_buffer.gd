extends SceneTree

# Pure retention controls: these are not a native owner or pacing result.
const Buffer = preload("res://tests/play_pace004_capture_buffer.gd")
var failures: int = 0
var assertions: int = 0


func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PACE004_CAPTURE_BUFFER: " + message)


func packet(serial: int, published: int, completed: int) -> Dictionary:
	return {"serial":serial, "published_usec":published,
		"completed_usec":completed, "native_completed":completed > 0}


func _initialize() -> void:
	var capture = Buffer.new()
	# Deliberately exceed the former total publication capacity during startup.
	for serial: int in range(1, 24001):
		capture.retain(packet(serial, serial * 10, serial * 10 - 1), 0, 0)
	check(capture.publications.is_empty() and not capture.overflow,
		"startup exhausted measured-publication capacity")
	check(capture.boundary.serial == 24000 and capture.startup_publications == 24000,
		"startup did not retain exactly its latest actual boundary")
	check(capture.retain(packet(24001, 240020, 240019), 240010, 0),
		"first measured completion was omitted")
	check(capture.retain(packet(24002, 240040, 240039), 240010, 0),
		"second measured completion was omitted")
	# A completion before end can publish after it and still needs its receipt.
	check(capture.retain(packet(24003, 240061, 240059), 240010, 240060),
		"last actual measured completion lost its late publication")
	check(not capture.retain(packet(24004, 240080, 240079), 240010, 240060),
		"after-window completion entered the measurement")
	check(capture.publications.map(func(row: Dictionary) -> int: return row.serial) \
		== [24000, 24001, 24002, 24003], "boundary/window serial inventory is incomplete")
	var receipt: Dictionary = capture.report()
	check(receipt.retained_boundary_publications == 1 and receipt.retained_window_publications == 3
		and receipt.after_window_publications_observed == 1, "window retention receipt differs")
	var bounded = Buffer.new()
	for serial: int in range(1, Buffer.MAX_ROWS + 2):
		bounded.retain(packet(serial, serial * 10, serial * 10 - 1), 1, 0)
	check(bounded.overflow and bounded.publications.size() == Buffer.MAX_ROWS,
		"true measured overflow silently dropped evidence")
	print("PACE004_CAPTURE_BUFFER_RESULT ", JSON.stringify({"assertions":assertions,
		"failures":failures, "scope":"pure retention controls; not native/graphical pacing"}))
	quit(0 if failures == 0 else 1)
