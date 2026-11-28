extends SceneTree

const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var f: RefCounted
var runner_id: int
var intervals: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func clocks() -> Dictionary:
	var view: Dictionary = f.bench.actor_observation(runner_id)
	return {"seconds":float(view["simulation_time_seconds"]), "actor":f.host.physical_actor_session.tick,
		"rapier":f.host.rapier_bridge.manual_step_count(), "segments":f.runtime().physical_steps}

func exercise_interval(interrupt: bool) -> bool:
	# Drive the real Main callback until its worker grants one structural interval.
	# Then pump only completion, so the measurement contains exactly that interval.
	if not f.play(): return false
	var before := clocks()
	var deadline := Time.get_ticks_msec()+15000
	while f.runtime()._motion_lease == 0 and Time.get_ticks_msec() < deadline:
		f.host._process(0.0)
		f.host._physics_process(f.host.rapier_bridge.fixed_delta())
		if f.runtime()._motion_lease == 0: await process_frame
	if not f.expect(f.runtime()._motion_lease > 0 and f.runtime()._interval_active,
		"native owner grants a real segmented interval"): return false
	if interrupt and not f.expect(f.bench.toggle_pause() and f.host.paused,
		"ordinary Pause interrupts the admitted interval before its last segment"): return false
	while f.runtime()._motion_lease > 0 and f.runtime().held_reason.is_empty() and Time.get_ticks_msec() < deadline:
		f.runtime()._poll_once()
		if f.runtime()._motion_lease > 0: await process_frame
	if not f.expect(f.runtime()._motion_lease == 0 and f.runtime().held_reason.is_empty(),
		"the completed structural interval releases its native motion lease"): return false
	var after := clocks()
	var segments: int = after.rapier-before.rapier
	intervals.append({"interrupted":interrupt,"before":before,"after":after})
	f.expect(segments >= 4 and after.segments-before.segments == segments,
		"multiple observed Rapier steps belong to the same material interval")
	f.expect(after.actor-before.actor == (0 if interrupt else 1),
		"one active interval advances the actor once and an intervening Pause suspends it")
	var expected_seconds: float = 0.0 if interrupt else f.host.rapier_bridge.fixed_delta()
	f.expect(absf(float(after.seconds)-float(before.seconds)-expected_seconds) < 0.000001,
		"actor elapsed time counts completed active intervals and excludes suspended segments")
	return true

func structural_ground_actor() -> bool:
	if not await f.open("tower"): return false
	runner_id = int(f.bench.applied.next_id)
	if not f.expect(f.bench.place("runner",Vector2(375,420)), "ordinary Workbench admits a ground actor"): return false
	if not await f.until(f.installed,"ground actor construction is acknowledged"): return false
	if not f.play(): return false
	if not await f.until(func(): return f.diagnostics().get("attached",false),"structures attach to the ground actor World"): return false
	if not await f.pause() or not await f.cut_supports("tower"): return false
	if not f.play(): return false
	if not await f.until(func(): return f.body_count() > 0,"an authored support cut releases a real structural body"): return false
	if not await f.pause(): return false
	var view: Dictionary = f.bench.actor_observation(runner_id)
	return f.expect(view.has("simulation_time_seconds") and view.get("controller_enabled",false),
		"the mounted ground actor reports its normal controller clock")

func flight_admission() -> bool:
	var old_session: String = f.host.physical_actor_session.run_id
	var old_generation: int = f.frame().world_generation
	var old_body_count: int = f.body_count()
	var mixed: Dictionary = f.bench.applied.duplicate(true)
	var flight_id: int = mixed.next_id
	mixed.actors.append(Setup.instance("4ly_trainer",flight_id,Vector2(280,230)))
	mixed.next_id += 1
	if not f.expect(not f.bench.apply(mixed,true) and not f.bench.busy() and "4LY" in f.bench.message,
		"a retained edit cannot add a 4LY plant to the populated structural World"): return false
	if not f.expect(f.body_count() == old_body_count and f.frame().world_generation == old_generation
		and f.host.physical_actor_session.run_id == old_session and f.bench.actor_observation(flight_id).is_empty(),
		"flight refusal retains the installed material bodies, actor session and native generation"): return false
	var flight: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
	flight.actors = [Setup.instance("4ly_trainer",1,Vector2(280,230))]
	flight.next_id = 2
	flight.selected = 1
	if not f.expect(f.bench.apply(flight),"full authored replacement admits an ordinary flight-only World"): return false
	if not await f.until(f.installed,"the new flight-only actor owner is installed"): return false
	var session: Variant = f.host.physical_actor_session
	if not f.expect(session.is_flight_actor(0) and f.host.latest_snapshot.render_world_generation != old_generation
		and f.body_count() == 0 and not f.runtime().enabled,
		"replacement retires structural bodies and their clock before flight admission"): return false
	if not f.expect(not f.bench.enable_object_shard() and not f.runtime().enabled and "4LY" in f.bench.message,
		"ordinary Structures refuses activation on an installed 4LY plant"): return false
	var tick_before: int = session.tick
	if not f.play(): return false
	return await f.until(func(): return session.tick >= tick_before+3 and session._flight_step_fault.is_empty(),
		"the flight-only World continues under its ordinary fixed-step actor owner")

func run() -> void:
	f = Fixture.new(self)
	if await structural_ground_actor():
		f.host.set_process(false)
		f.host.set_physics_process(false)
		var completed := true
		for interrupted: bool in [false,true,false]:
			if not await exercise_interval(interrupted):
				completed = false
				break
		f.host.set_process(true)
		f.host.set_physics_process(true)
		if completed and await f.pause(): await flight_admission()
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-actor-clock-v1","source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":f.checks,"failures":f.failures,"intervals":intervals}))
	quit(0 if f.failures.is_empty() else 1)
