extends SceneTree

const Clock = preload("res://scripts/persistent_area_clock.gd")
var checks := 0
var failures := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("GEN006 clock: " + label)


func ahead(clock: Dictionary, id: String, future: int, slice_ticks: int) -> Dictionary:
	var current := clock.duplicate(true)
	var remaining := future
	var work := 0
	while Clock.debt(current, id) > 0 or remaining > 0:
		var prepared := Clock.plan(current, id, "ahead", remaining, slice_ticks)
		if not prepared.get("ok", false):
			check(false, "bounded ahead plan: " + str(prepared))
			return {}
		var completed := Clock.complete(current, prepared.plan, prepared.plan.work_ticks)
		if not completed.get("ok", false):
			check(false, "bounded ahead completion: " + str(completed))
			return {}
		work += completed.completed_ticks
		remaining = completed.remaining_future_ticks
		current = completed.clock
	return {"clock":current, "work":work}


func _initialize() -> void:
	var clock := Clock.fresh()
	check(Clock.validate(clock).is_empty(), "fresh three-area clock is valid")
	var first := Clock.active(clock, "a", 120)
	check(first.ok and first.clock.game_ticks == 120 and Clock.debt(first.clock, "b") == 120,
		"completed active A ticks create inactive B debt")
	check(clock.game_ticks == 0 and clock.areas.a.native_ticks == 0, "clock transitions never mutate their input")
	clock = Clock.active(first.clock, "b", 45).clock
	check(clock.game_ticks == 165 and clock.areas.b.accounted_ticks == 45 and Clock.debt(clock, "b") == 120,
		"active play on a lagging area preserves explicit prior debt")
	check(Clock.debt(clock, "a") == 45 and Clock.debt(clock, "c") == 165, "three independent frontiers are retained")
	var plan := Clock.plan(clock, "a", "catch_up", 0, 30)
	var partial := Clock.complete(clock, plan.plan, 18)
	check(partial.ok and partial.clock.game_ticks == 165 and partial.clock.areas.a.accounted_ticks == 138 \
		and partial.debt_ticks == 27 and partial.paid_debt_ticks == 18, "cancel commits only actual partial catch-up and retains debt")
	check(not Clock.complete(partial.clock, plan.plan, 18).ok, "stale completion cannot advance the same interval twice")
	var no_work := Clock.complete(clock, plan.plan, 0)
	check(no_work.ok and no_work.clock == clock, "cancellation before a native tick changes no game time")
	var early := Clock.plan(clock, "b", "ahead", 90, 60)
	var early_done := Clock.complete(clock, early.plan, 60)
	check(early_done.ok and early_done.remaining_future_ticks == 90 and early_done.game_advanced_ticks == 0 \
		and early_done.clock.game_ticks == 165, "ahead request pays old debt before requested future time")
	var restarted: Dictionary = JSON.parse_string(JSON.stringify(early_done.clock))
	check(Clock.validate(restarted).is_empty(), "partially completed debt survives JSON numeric representation")
	var from_restart := ahead(Clock.canonical(restarted), "b", 90, 7)
	var one_slice := ahead(clock, "b", 90, 600)
	var thirteen := ahead(clock, "b", 90, 13)
	check(from_restart.clock == one_slice.clock and thirteen.clock == one_slice.clock,
		"different native work slices and interrupted resume account exactly the same completed interval")
	check(one_slice.work == 210 and one_slice.clock.game_ticks == 255 and one_slice.clock.areas.b.native_ticks == 255,
		"120 ticks of old debt plus 90 future ticks perform 210 real ticks but add only 90 game ticks")
	clock = one_slice.clock
	var repeated := clock.duplicate(true)
	var repeated_work := 0
	for request: int in 10:
		var result := ahead(repeated, "c", 12, 17)
		repeated = result.clock
		repeated_work += result.work
	check(repeated.game_ticks == 375 and repeated.areas.c.accounted_ticks == 375 and repeated_work == 375,
		"repeated Ahead requests cannot repeat an already paid inactive interval")
	check(Clock.active(repeated, "c", 375).clock == repeated, "repeated active observation is idempotent")
	check(not Clock.active(repeated, "c", 374).ok, "native clock rollback refuses")
	var rebased := Clock.rebase(repeated, "a")
	check(rebased.ok and rebased.clock.areas.a.native_ticks == 0 and rebased.clock.areas.a.origin_game_tick == 375 \
		and Clock.active(rebased.clock, "a", 5).clock.game_ticks == 380, "explicit authored reset establishes a new clock origin")
	var huge := Clock.fresh()
	huge.game_ticks = 9000000000000
	var bounded := Clock.plan(huge, "c", "catch_up", 0, 600)
	var bounded_done := Clock.complete(huge, bounded.plan, 600)
	check(bounded.ok and bounded.plan.work_ticks == 600 and bounded_done.debt_ticks == 8999999999400 \
		and bounded_done.clock.game_ticks == 9000000000000, "large accumulated debt is bounded and never silently skipped")
	for bad_ticks: Variant in [-1, 1.5, INF, NAN, true, "60"]:
		var invalid := Clock.fresh()
		invalid.game_ticks = bad_ticks
		check(not Clock.validate(invalid).is_empty(), "malformed game time refuses: " + str(bad_ticks))
	var invalid := Clock.fresh()
	invalid.areas.a.accounted_ticks = 1
	check(not Clock.validate(invalid).is_empty(), "native/accounted mismatch refuses")
	invalid = Clock.fresh()
	invalid.areas.erase("c")
	check(not Clock.validate(invalid).is_empty(), "missing area refuses")
	check(not Clock.plan(clock, "a", "catch_up", 1, 30).ok, "catch-up cannot smuggle future advancement")
	check(not Clock.plan(clock, "a", "ahead", 36001, 30).ok and not Clock.plan(clock, "a", "ahead", 1, 601).ok,
		"request and per-slice capacities are separate bounded refusals")
	var changed_plan: Dictionary = plan.plan.duplicate(true)
	changed_plan.work_ticks += 1
	check(not Clock.complete(first.clock, changed_plan, 1).ok, "tampered work plan refuses")
	print("GEN006_CLOCK checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
