extends SceneTree

const History = preload("res://scripts/workbench_presentation_history.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("PRESENTATION_HISTORY: "+label)

func _run() -> void:
	var history = History.new()
	var first: Dictionary = history.observe(0,41,3,1,Transform2D(0.2,Vector2(12,14)),
		Vector2(3,4),0.5,100,91,105)
	check(first.is_read_only(),"published observation is immutable value data")
	check(first.step == 1 and first.completed_usec == 100 and first.sampled_usec == 105,
		"physical step, completion and observation clocks remain distinct")
	var repeat: Dictionary = history.observe(0,41,3,1,first.pose,first.velocity,0.5,200,92,205)
	check(repeat.completed_usec == 100 and repeat.sampled_usec == 105 and repeat.sample_serial == 92,
		"repeated render/sample observation cannot rejuvenate a completed step")
	check(first.sample_serial == 91,"later serial attachment leaves previous immutable value unchanged")
	for step: int in range(2,400):
		history.observe(0,41,3,step,Transform2D(float(step)*0.001,Vector2(step,14)),
			Vector2(120,0),0.12,step*1000,step+90,step*1000+5)
	check(history.retained_observations() == History.CAPACITY,"one actor remains bounded after ring wrap")
	check(history.observation(0,1).is_empty(),"retired step cannot alias a wrapped ring entry")
	check(history.observation(0,399).velocity == Vector2(120,0),"velocity stays associated with exact pose and step")
	var candidates: Array[Dictionary] = history.recovery_candidates(0,390,399)
	check(candidates.size() == History.RECOVERY_ATTEMPTS,"geometry recovery cannot exceed three candidates")
	check(candidates[0].step == 391 and candidates[1].step == 392 and candidates[2].step == 393,
		"recovery considers a chronological prefix, never the older selected step")
	check(history.recovery_candidates(0,398,399).is_empty(),"newest failed candidate is not retried as history")
	check(history.newest_after_through(0,390,394).step == 394,
		"bounded playback selects the newest actual observation below its step ceiling")
	check(history.newest_after_through(0,390,390).is_empty(),
		"empty playback window never substitutes an old observation")
	check(history.observe(0,41,3,200,Transform2D.IDENTITY,Vector2.ZERO,0,200001).is_empty(),
		"regressed physical step cannot overwrite later observations")
	history.observe(0,42,4,0,Transform2D.IDENTITY,Vector2.ZERO,0,0,-1,400000)
	check(history.retained_observations() == 1 and history.observation(0,399).is_empty(),
		"actor identity replacement retires the old timeline")
	check(history.observation(0,0).completed_usec == 0,
		"initial state keeps unknown completion time explicitly unknown")
	check(history.observe(History.MAX_ACTORS,99,4,0,Transform2D.IDENTITY,Vector2.ZERO,0,1).is_empty(),
		"invalid actor slot cannot grow the actor history map")
	history.clear()
	check(history.retained_observations() == 0,"session/World replacement clears all observations")
	print("WORKBENCH_PRESENTATION_HISTORY ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
