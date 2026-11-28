extends SceneTree

const Capture = preload("res://scripts/object_shard_capture.gd")
const View = preload("res://scripts/object_shard_lab_view.gd")
var checks: int = 0
var failures: int = 0
const SOURCE: String = "1111111111111111111111111111111111111111"
const PATH: String = "user://objectshard-capture-contract.trace.jsonl"


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var capture = Capture.new()
	var began: Dictionary = capture.begin({"source_revision": SOURCE, "scenario": 1, "seed": 12}, PATH)
	_expect(began.complete_prefix, "Prospective trace opens before any input")
	capture.action(0, "edit", {"position": Vector2i(2, 7), "material": 7, "state_a": 4, "state_b": 19, "temperature": 645}, {"ok": true, "outcome": "Accepted"})
	capture.write("step_requested", 0, {"force": true})
	capture.write("step_completed", 1, {"physics": {"pose": Transform2D(0.5, Vector2(3, 9))}})
	capture.checkpoint(1, {"failed": false})
	var accepted: Dictionary = Capture.read_trace(PATH, SOURCE)
	_expect(accepted.get("ok", false), "A flushed incident checkpoint is a complete replay prefix")
	_expect(accepted.rows[1].detail.parameters.position is Array and int(accepted.rows[1].detail.parameters.position[0]) == 2
		and int(accepted.rows[1].detail.parameters.position[1]) == 7, "Coordinates retain machine-readable numeric components")
	_expect(int(accepted.rows[1].detail.parameters.state_b) == 19 and int(accepted.rows[1].detail.parameters.temperature) == 645,
		"State and temperature are captured, not merely material ID")
	_expect(accepted.rows[3].detail.physics.pose.rotation is float, "Pose export preserves numeric rotation")
	_expect(not Capture.read_trace(PATH, "2".repeat(40)).get("ok", false), "Another source cannot silently replay this trace")
	capture.close()
	_expect(Capture.read_trace(PATH, SOURCE).get("ok", false), "Normal close seals the recorded prefix")

	var text: String = FileAccess.get_file_as_string(PATH)
	var stream: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	stream.store_string(text + '{"sequence":0,"kind":"checkpoint","tick":1,"detail":{}}\n')
	stream.close()
	_expect(not Capture.read_trace(PATH, SOURCE).get("ok", false), "Duplicate/out-of-order sequence is refused")
	stream = FileAccess.open(PATH, FileAccess.WRITE)
	stream.store_string(text.left(text.length() - 10))
	stream.close()
	_expect(not Capture.read_trace(PATH, SOURCE).get("ok", false), "Partial final JSON is not a complete replay")

	capture.begin({"source_revision": SOURCE}, PATH)
	capture.action(0, "unrecognized-command", {}, {"ok": true})
	capture.checkpoint(0, {})
	_expect(not Capture.read_trace(PATH, SOURCE).get("ok", false), "Unknown action cannot be executed by replay")
	capture.close()

	capture.begin({"source_revision": SOURCE}, PATH)
	capture.records = Capture.MAX_RECORDS
	capture.write("event", 1, {"kind": "overflow"})
	_expect(not capture.complete and capture.stream == null, "Record saturation closes trace without blocking control")
	_expect(capture.reason.contains("limit"), "Saturation is visible as incomplete, never silently complete")
	capture.begin({"source_revision": SOURCE})
	for index: int in range(Capture.MAX_ACTIONS + 3):
		capture.action(index, "pause", {"paused": true}, {"ok": true})
	_expect(capture.actions.size() == Capture.MAX_ACTIONS and capture.dropped_actions == 3, "In-memory action window stays bounded with an exact loss count")
	capture.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	for destination: Vector2i in [Vector2i(0, 20), Vector2i(20, 0), Vector2i(18, 19), Vector2i(-18, -19), Vector2i(1, 1)]:
		var cells: Array[Vector2i] = View.stroke_cells(Vector2i.ZERO, destination)
		var previous := Vector2i.ZERO
		var connected: bool = true
		for cell: Vector2i in cells:
			connected = connected and absi(cell.x - previous.x) + absi(cell.y - previous.y) == 1
			previous = cell
		_expect(connected and previous == destination, "Mouse cut uses a continuous four-connected supercover: " + str(destination))
	_expect(View.stroke_cells(Vector2i.ZERO, Vector2i(30000, 30000)).size() == 256, "One mouse event cannot create unbounded work")
	_expect(View.stroke_cells(Vector2i(4, 7), Vector2i(4, 7)).is_empty(), "Repeated mouse motion over the same cell creates no duplicate stroke work")
	print(JSON.stringify({"schema": "objectshard-capture-contract-test-v1", "checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
