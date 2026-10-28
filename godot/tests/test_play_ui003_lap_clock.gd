extends SceneTree

# PLAY-UI-003 / #268: tick-accounting, ordered checkpoints, pause and epoch
# fences without a synthetic physics implementation or native World owner.
const Lap = preload("res://scripts/playable_course_lap.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const MODEL_LIFECYCLE_CYCLES: int = 50

var assertions: int = 0
var failures: int = 0
var completed_model_cycles: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_UI003: " + message)


func state(lap: RefCounted) -> Array:
	# Refusal leaves public state intact. Subsequent legitimate rebinds also
	# prove that rejected mixed candidates did not poison private lifetime fences.
	return [lap.rig_id, lap.actor_epoch, lap.world_generation,
		lap.last_source_tick, lap.last_physics_tick, lap.started,
		lap.elapsed_ticks, lap.target_index, lap.best_ticks.duplicate(true)]


func lifetime_fences() -> void:
	var lap = Lap.new()
	for cycle: int in range(MODEL_LIFECYCLE_CYCLES):
		var before_failures: int = failures
		var rig: StringName = Course.MECHANICAL_PRESETS[cycle % Course.MECHANICAL_PRESETS.size()]
		var other_rig: StringName = Course.MECHANICAL_PRESETS[(cycle + 1) % Course.MECHANICAL_PRESETS.size()]
		var epoch: int = 200 + cycle * 2
		var generation: int = 1000 + cycle * 2
		var gates: PackedVector2Array = Course.checkpoints(rig)
		var context: String = "cycle %d / %s: " % [cycle, rig]
		expect(lap.bind(rig, epoch, generation, 10) and not lap.started,
			context + "new accepted lifetime starts neutrally")
		expect(lap.admit_movement(10) and lap.observe(13, 1, gates[0], false)
			and lap.elapsed_ticks == 3 and lap.target_index == 1,
			context + "real model credits a native delta and ordered gate")
		var live: Array = state(lap)
		expect(not lap.bind(rig, epoch - 1, generation + 1, 100) and state(lap) == live,
			context + "old actor with newer World refuses atomically")
		expect(not lap.bind(rig, epoch + 1, generation - 1, 100) and state(lap) == live,
			context + "newer actor with old World refuses atomically")
		expect(not lap.bind(other_rig, epoch, generation + 1, 100) and state(lap) == live,
			context + "same actor epoch cannot change rig or poison World fence")
		expect(not lap.bind(rig, epoch, generation, 12) and state(lap) == live,
			context + "stale same-lifetime bind leaves progress unchanged")
		expect(not lap.admit_movement(12) and state(lap) == live,
			context + "stale movement cannot rewind the clock")
		expect(not lap.observe(12, 2, gates[1], false) and state(lap) == live,
			context + "stale native observation cannot credit a gate")
		expect(not lap.observe(13, 0, gates[1], false) and state(lap) == live,
			context + "stale physical observation cannot credit a gate")
		expect(not lap.observe(14, 2, Vector2.INF, false) and state(lap) == live,
			context + "nonfinite pose refuses without advancing either fence")
		expect(lap.observe(13, 1, gates[1], false) and state(lap) == live,
			context + "duplicate physical tick cannot credit the next gate")
		lap.clear_session()
		var cleared: Array = state(lap)
		expect(lap.rig_id == &"" and not lap.started and lap.elapsed_ticks == 0,
			context + "presentation invalidation clears only the live lap")
		expect(not lap.bind(rig, epoch - 1, generation, 100) and state(lap) == cleared,
			context + "clear cannot resurrect a retired actor")
		expect(not lap.bind(rig, epoch, generation - 1, 100) and state(lap) == cleared,
			context + "clear cannot resurrect a retired World")
		expect(not lap.bind(rig, epoch, generation, 12) and state(lap) == cleared,
			context + "clear retains the native publication high-water mark")
		expect(lap.bind(rig, epoch, generation, 13) and lap.admit_movement(13),
			context + "current lifetime may rearm without reusing old lap credit")
		live = state(lap)
		expect(not lap.observe(13, 0, gates[0], false) and state(lap) == live,
			context + "clear also retains the physical observation high-water mark")
		expect(lap.observe(13, 1, gates[0], false) and lap.target_index == 0,
			context + "duplicate pre-clear pose cannot start checkpoint progress")
		expect(lap.observe(15, 2, gates[0], false) and lap.elapsed_ticks == 2 and lap.target_index == 1,
			context + "fresh physical observation resumes ordered progress")
		expect(lap.observe(16, 3, gates[1], true) and lap.elapsed_ticks == 2 and lap.target_index == 1,
			context + "pause excludes time and gate credit")
		expect(lap.observe(16, 4, gates[1], false) and lap.elapsed_ticks == 2 and lap.target_index == 2,
			context + "physical cadence can advance gates without a new native tick")
		expect(lap.observe(20, 5, gates[2], false) and lap.observe(21, 6, gates[3], false)
			and lap.is_complete() and lap.elapsed_ticks == 7 and lap.best_ticks[rig] == 7,
			context + "completion retains exact native-time best for this rig")
		var bests: Dictionary = lap.best_ticks.duplicate(true)
		expect(lap.bind(rig, epoch, generation + 1, 0) and not lap.started and lap.best_ticks == bests,
			context + "World-only reconstruction permits native tick zero, retaining bests")
		live = state(lap)
		expect(not lap.bind(rig, epoch, generation, 9999) and state(lap) == live,
			context + "old World cannot return even with a much larger tick")
		expect(lap.admit_movement(0), context + "new World permits newly admitted movement")
		live = state(lap)
		expect(not lap.observe(0, 5, gates[0], false) and state(lap) == live,
			context + "World replacement alone cannot rewind the unchanged physical actor")
		expect(lap.bind(rig, epoch + 1, generation + 1, 0) and lap.admit_movement(0)
			and lap.observe(1, 0, gates[0], false) and lap.target_index == 1,
			context + "actor replacement independently permits physical tick zero")
		lap.clear_session()
		if failures == before_failures:
			completed_model_cycles += 1
	expect(completed_model_cycles == MODEL_LIFECYCLE_CYCLES,
		"all fifty model lifecycle cycles completed without a failed assertion")
	expect(lap.best_ticks.size() == Course.MECHANICAL_PRESETS.size(),
		"fifty cycles exercised separate bests for all five mechanical rigs")


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
	expect(lap.observe(107, 11, Course.checkpoints(&"acrobat")[1], false)
		and lap.elapsed_ticks == 5 and lap.target_index == 1,
		"duplicate source/physics publication cannot advance gate or clock")
	expect(lap.observe(107, 12, Course.checkpoints(&"acrobat")[1], false)
		and lap.elapsed_ticks == 5 and lap.target_index == 2,
		"new Rapier tick may reach next gate without a new native tick")
	expect(lap.observe(110, 13, Course.checkpoints(&"acrobat")[2], true)
		and lap.elapsed_ticks == 5 and lap.target_index == 2,
		"pause excludes native ticks and gates")
	expect(lap.observe(114, 14, Course.checkpoints(&"acrobat")[2], false)
		and lap.elapsed_ticks == 9 and lap.target_index == 3,
		"resume excludes paused interval and advances third gate")
	expect(not lap.observe(112, 15, Course.checkpoints(&"acrobat")[3], false)
		and lap.elapsed_ticks == 9 and lap.target_index == 3,
		"stale out-of-order source publication refused without rewind")
	expect(lap.observe(115, 16, Course.checkpoints(&"acrobat")[3], false)
		and lap.is_complete() and lap.elapsed_ticks == 10 and lap.best_ticks[&"acrobat"] == 10,
		"fourth gate completes lap and stores exact simulation-tick best")
	expect(lap.observe(116, 17, Course.checkpoints(&"acrobat")[3], false)
		and lap.elapsed_ticks == 10, "completed lap does not accumulate extra ticks")
	expect(not lap.observe(116, 15, Course.checkpoints(&"acrobat")[3], false),
		"stale physical observation cannot overwrite last accepted pose")
	expect(lap.bind(&"acrobat", 8, 12, 200)
		and not lap.started and lap.target_index == 0 and lap.elapsed_ticks == 0,
		"actor epoch replacement clears old live lap")
	expect(lap.best_ticks[&"acrobat"] == 10, "best time survives reset for same rig")
	expect(lap.bind(&"acrobat", 8, 13, 2) and lap.elapsed_ticks == 0,
		"native World reconstruction resets lap independent of actor epoch")
	expect(lap.bind(&"trialsbike", 9, 13, 5) and lap.rig_id == &"trialsbike",
		"switching SetP rigs selects separately authored checkpoints")
	expect(not lap.admit_movement(4), "old source tick cannot start new session")
	lap.clear_session()
	expect(lap.rig_id == &"" and lap.best_ticks[&"acrobat"] == 10,
		"exit discards live identity without inventing a cleared best")
	lifetime_fences()
	print("PLAY_UI003_RESULT ", JSON.stringify({
		"assertions":assertions, "failures":failures,
		"source":"completed-native-tick+main-thread-Rapier-pose",
		"model_lifecycle_cycles":completed_model_cycles,
		"real_host_lifecycle_cycles":0,
		"physical_gamepad_qualified":false, "rendered_fps_measured":false
	}))
	quit(0 if failures == 0 else 1)
