extends SceneTree

const Clock = preload("res://scripts/persistent_area_clock.gd")
var checks := 0
var failures := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("RAMCACHE background clock: " + label)


func _initialize() -> void:
	var clock: Dictionary = Clock.active(Clock.fresh(),"a",120).clock
	var planned := Clock.plan_background(clock,"b",32,"1".repeat(32))
	check(planned.ok and planned.plan.work_ticks == 32,"background plan admits a bounded existing debt interval")
	var advancing: Dictionary = Clock.active(clock,"a",180).clock
	var completed := Clock.complete_background(advancing,planned.plan,19)
	check(completed.ok and completed.clock.game_ticks == 180 and completed.clock.areas.a.native_ticks == 180 \
		and completed.clock.areas.b.native_ticks == 19 and completed.debt_ticks == 161,"active G advancement preserves useful private progress")
	check(not Clock.complete_background(completed.clock,planned.plan,19).ok,"duplicate interval cannot double-credit time")
	check(Clock.complete_background(advancing,planned.plan,0).clock == advancing,"cancellation before work leaves all clocks unchanged")
	var changed_target: Dictionary = Clock.active(advancing,"b",1).clock
	check(not Clock.complete_background(changed_target,planned.plan,19).ok,"target activation/mutation of native frontier supersedes background plan")
	check(not Clock.complete_background(Clock.rebase(advancing,"b").clock,planned.plan,19).ok,"new target origin refuses stale work")
	check(not Clock.complete_background(Clock.fresh(),planned.plan,1).ok,"rollback of global frontier refuses")
	check(not Clock.complete_background(advancing,planned.plan,33).ok,"completed ticks cannot exceed reservation")
	var tampered: Dictionary = planned.plan.duplicate(true)
	tampered.work_ticks = 33
	check(not Clock.complete_background(advancing,tampered,1).ok,"tampered bounded work refuses")
	for key: String in ["version","protocol","area_id","operation_id","source_game_tick","source_area_clock","max_work_ticks","work_ticks"]:
		tampered = planned.plan.duplicate(true)
		tampered.erase(key)
		check(not Clock.complete_background(advancing,tampered,1).ok,"missing plan field refuses: " + key)
	for value: Variant in [-1,1.5,INF,NAN,true,"32"]:
		tampered = planned.plan.duplicate(true)
		tampered.max_work_ticks = value
		check(not Clock.complete_background(advancing,tampered,1).ok,"malformed work amount refuses: " + str(value))
	# Sustained changing-G schedule. Target intervals remain anchored to their
	# actual completed native frontiers, irrespective of active snapshot timing.
	clock = Clock.fresh()
	var observed_b := 0
	var observed_c := 0
	for index: int in 500:
		clock = Clock.active(clock,"a",int(clock.areas.a.native_ticks)+5).clock
		var id := "b" if index % 2 == 0 else "c"
		var plan := Clock.plan_background(clock,id,17,"2".repeat(32))
		clock = Clock.active(clock,"a",int(clock.areas.a.native_ticks)+3).clock
		var actual := mini(int(plan.plan.work_ticks),1+index%13)
		var result := Clock.complete_background(clock,plan.plan,actual)
		check(result.ok and result.clock.game_ticks == (index+1)*8,"changing G does not discard verified work")
		clock = result.clock
		if id == "b": observed_b += actual
		else: observed_c += actual
		check(int(clock.areas.b.native_ticks) == observed_b and int(clock.areas.c.native_ticks) == observed_c,
			"independent area completion totals remain exact")
		check(not Clock.complete_background(clock,plan.plan,actual).ok or actual == 0,"completed interval cannot replay")
	check(Clock.validate(clock).is_empty() and clock.game_ticks == 4000,"sustained background schedule retains a valid global clock")
	print("GEN006_RAMCACHE_BACKGROUND_CLOCK checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
