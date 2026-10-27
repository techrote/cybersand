extends SceneTree

# PLAY-UI-003 / #268: tick-accounting, ordered checkpoints, pause and epoch
# fences without a synthetic physics implementation or native World owner.
const Lap = preload("res://scripts/playable_course_lap.gd")
const Course = preload("res://scripts/player_playground_course.gd")

var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_UI003: " + message)


func run() -> void:
	var lap = Lap.new()
	expect(not lap.bind(&"dryswarm", 1, 1, 0),
		"deferred material swarm is not a mechanical gameplay lap")
	expect(not lap.admit_movement(0), "unbound/unsupported input cannot begin a lap")
	expect(lap.bind(&"acrobat", 7, 12, 100), "bound to a typed physical and World generation")
	expect(not lap.started and lap.elapsed_ticks == 0 and lap.target_index == 0,
		"new session begins neutral and with no credited native ticks")
	expect(lap.observe(102, 10, Vector2(208, 339), false) and lap.target_index == 0,
		"physical proximity alone does not start an uncommanded session")
	expect(lap.admit_movement(102), "accepted human movement starts the lap")
	expect(lap.observe(107, 11, Course.checkpoints(&"acrobat")[0], false)
		and lap.elapsed_ticks == 5 and lap.target_index == 1,
		"one completed snapshot delta credits exactly five ticks and first gate")
	expect(lap.observe(107, 12, Course.checkpoints(&"acrobat")[1], false)
		and lap.elapsed_ticks == 5 and lap.target_index == 1,
		"duplicate native publication cannot advance gate or clock")
	expect(lap.observe(110, 13, Course.checkpoints(&"acrobat")[1], true)
		and lap.elapsed_ticks == 5 and lap.target_index == 1,
		"pause excludes native ticks and gates")
	expect(lap.observe(114, 14, Course.checkpoints(&"acrobat")[1], false)
		and lap.elapsed_ticks == 9 and lap.target_index == 2,
		"resume excludes paused interval and advances second gate")
	expect(not lap.observe(112, 15, Course.checkpoints(&"acrobat")[2], false)
		and lap.elapsed_ticks == 9 and lap.target_index == 2,
		"stale out-of-order source publication refused without rewind")
	expect(lap.observe(115, 16, Course.checkpoints(&"acrobat")[2], false)
		and lap.target_index == 3,
		"third gate in source-authored order")
	expect(lap.observe(116, 17, Course.checkpoints(&"acrobat")[3], false)
		and lap.is_complete() and lap.elapsed_ticks == 11 and lap.best_ticks[&"acrobat"] == 11,
		"fourth gate completes lap and stores exact simulation-tick best")
	expect(lap.observe(130, 18, Course.checkpoints(&"acrobat")[3], false)
		and lap.elapsed_ticks == 11, "completed lap does not accumulate extra ticks")
	expect(lap.bind(&"acrobat", 8, 12, 200)
		and not lap.started and lap.target_index == 0 and lap.elapsed_ticks == 0,
		"actor epoch replacement clears old live lap")
	expect(lap.best_ticks[&"acrobat"] == 11, "best time survives reset for same rig")
	expect(lap.bind(&"acrobat", 8, 13, 2) and lap.elapsed_ticks == 0,
		"native World reconstruction resets lap independent of actor epoch")
	expect(lap.bind(&"trialsbike", 9, 13, 5) and lap.rig_id == &"trialsbike",
		"switching SetP rigs selects separately authored checkpoints")
	expect(not lap.admit_movement(4), "old source tick cannot start new session")
	lap.clear_session()
	expect(lap.rig_id == &"" and lap.best_ticks[&"acrobat"] == 11,
		"exit discards live identity without inventing a cleared best")
	print("PLAY_UI003_RESULT ", JSON.stringify({
		"assertions":assertions, "failures":failures,
		"source":"completed-native-tick+main-thread-Rapier-pose",
		"physical_gamepad_qualified":false, "rendered_fps_measured":false
	}))
	quit(0 if failures == 0 else 1)
