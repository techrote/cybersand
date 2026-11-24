extends SceneTree

# Independent ordinary Workbench acceptance. Authored native material is cut
# through the live brush, then the genuine owner/native/Rapier chain is observed.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var f: RefCounted
var observations: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower"):
		await _finish()
		return
	await f.pause()
	if not await f.until(f.whole_canvas_coherent, "native material and shard publication share uploaded revision"):
		await _finish()
		return
	var initial_wood: int = f.material_count(7)
	var initial_brick: int = f.material_count(43)
	f.expect(initial_wood > 100 and initial_brick > 100, "actual authored mixed structure has Wood and Brick")
	var original_worker: int = f.host.simulation_worker.get_instance_id()
	var original_native: int = int(f.diagnostics().native_instance_id)
	var original_generation: int = int(f.diagnostics().world_generation)
	# Leave a small severed Wall cap under the facade. It must not tether a
	# substantial disconnected structure to a foundation that no longer exists.
	await f.cut_supports("tower", 2)
	f.play()
	if not await f.until(func(): return f.body_count() >= 1, "coherent facade with residual offcut detaches"):
		await _finish()
		return
	var first_bodies: Array = f.diagnostics().physics.bodies.duplicate(true)
	if not await f.advance(75, "ordinary worker and physical structures continue for 75 ticks"):
		await _finish()
		return
	await f.pause()
	await f.until(f.coherent, "paused upload matches native material and pose")
	var after: Dictionary = f.diagnostics()
	var moved: bool = false
	for before: Dictionary in first_bodies:
		for body: Dictionary in after.physics.bodies:
			if int(body.id) == int(before.id) and Vector2(float(body.x)-float(before.x),float(body.y)-float(before.y)).length() > 1.0:
				moved = true
	f.expect(moved, "actual Rapier transform progressed after support cut")
	f.expect(int(after.physical_steps) > 75 and int(after.native_pose_acknowledgements) > 75,
		"each physical segment has native pose acknowledgements")
	f.expect(f.host.simulation_worker.get_instance_id() == original_worker and int(after.native_instance_id) == original_native,
		"ordinary native World and worker survive detachment without a second owner")
	f.expect(int(after.world_generation) == original_generation, "detachment preserves ordinary World generation")
	f.validate_physics()
	f.expect(f.material_count(7) == initial_wood, "independent uploaded World plus owning-shard Wood inventory conserved")
	f.expect(f.material_count(43) == initial_brick, "independent uploaded World plus owning-shard Brick inventory conserved")
	var paused_tick: int = f.tick()
	var paused_steps: int = int(f.diagnostics().physical_steps)
	for i: int in range(12): await process_frame
	f.expect(f.tick() == paused_tick and int(f.diagnostics().physical_steps) == paused_steps,
		"Pause stops semantic and physical progression after admitted receipts drain")
	var before_step_controls: int = int(f.diagnostics().controls_completed)
	f.expect(f.bench.step_once(),"ordinary paused single-step request accepted")
	await f.until(func(): return f.tick() == paused_tick+1 and bool(f.diagnostics().physics_ready) and f.coherent(),
		"paused single-step completes one native interval and coherent physical acknowledgement")
	for i: int in range(12): await process_frame
	f.expect(f.host.paused and f.tick() == paused_tick+1,"single-step leaves ordinary simulation paused after exactly one tick")
	f.expect(int(f.diagnostics().controls_completed) == before_step_controls+1,"single-step advances shared physical controls exactly once")
	var target: Dictionary = f.moving_target(7)
	if not f.expect(not target.is_empty(), "source-bound displayed moving Wood cell available"):
		await _finish()
		return
	var old_count: int = f.material_count(7)
	var angular_before: Dictionary = {}
	var energy_before: Dictionary = {}
	for body: Dictionary in f.diagnostics().physics.bodies:
		angular_before[body.id] = float(body.angular_velocity)
		energy_before[body.id] = 0.5*float(body.inertia)*pow(float(body.angular_velocity),2.0)
	var request: Dictionary = f.bench.object_shard_m4_action(target.position, "erase", f.runtime().visible_observation(), target)
	f.expect(request.get("ok",false), "moving-cell erase enters actual ordinary worker command queue / " + str(request))
	if request.get("ok",false):
		await f.until(func(): return f.bench.object_shard_m4_port.pending_count() == 0, "moving erase terminal receipt")
		await f.until(func(): return bool(f.diagnostics().get("physics_ready",false)) and f.coherent(), "post-edit geometry and visible publication installed")
		var result: Dictionary = f.bench.object_shard_m4_port.results.back()
		f.expect(result.get("outcome") == "Applied", "native material mutation applied")
		f.expect(result.get("native_receipt",{}).get("source_target",{}) == target,
			"native copied the exact pre-edit cell state and incarnation witness")
		f.expect(int(result.get("native_receipt",{}).get("transaction_id",0)) > 0,
			"moving mutation has a native transaction identity")
		f.expect(f.material_count(7) == old_count-1, "single moving-cell erase debits exactly one Wood cell")
		for body: Dictionary in f.diagnostics().physics.bodies:
			if angular_before.has(body.id):
				f.expect(absf(float(body.angular_velocity)-float(angular_before[body.id])) < 0.01,
					"paused small geometry edit does not inject angular velocity")
				var rotation_energy: float = 0.5*float(body.inertia)*pow(float(body.angular_velocity),2.0)
				f.expect(rotation_energy <= float(energy_before[body.id])*1.05+0.001,
					"displayed paused geometry edit does not inject rotational kinetic energy")
		observations.erase_receipt = result
	# Stale observed material must be refused without silently erasing another
	# moving cell. The real port verifies the original copied publication.
	var stale: Dictionary = f.bench.object_shard_m4_action(target.position, "erase", f.runtime().visible_observation(), target)
	f.expect(not stale.get("ok",false), "stale pre-edit moving witness refused before new mutation")
	var ignition: Dictionary = f.moving_target(7)
	if f.expect(not ignition.is_empty(), "remaining moving Wood can be selected for ignition"):
		var ignite: Dictionary = f.bench.object_shard_m4_action(ignition.position, "ignite", f.runtime().visible_observation(), ignition)
		f.expect(ignite.get("ok",false), "moving Wood ignition queued through ordinary worker / " + str(ignite))
		if ignite.get("ok",false):
			await f.until(func(): return f.bench.object_shard_m4_port.pending_count() == 0, "ignition receipt")
			await f.until(func(): return bool(f.diagnostics().get("physics_ready",false)) and f.coherent(), "ignition publication installed")
			observations.ignite_receipt = f.bench.object_shard_m4_port.results.back().duplicate(true)
			f.expect(observations.ignite_receipt.get("outcome") == "Applied", "native moving Wood ignition applied")
	var pre_fire: int = f.material_count(7)
	f.play()
	await f.advance(120, "ignited moving material continues native chemistry")
	await f.pause()
	await f.until(f.coherent, "post-combustion publication coherent")
	f.expect(f.material_count(7) < pre_fire, "moving Wood actually undergoes continued combustion")
	f.bench._tool.select(0)
	f.bench._brush.value = 2
	f.expect(f.bench.paint(Vector2i(340,100),2), "ordinary Sand painting remains available beside live structures")
	f.play()
	await f.advance(8, "ordinary painting and structures advance together")
	await f.pause()
	f.bench._name.text = "objectshard-m4-qualification-authored-start"
	await f.until(func(): return not f.host.simulation_worker.paint_state().get("legacy_busy",true), "ordinary brush settles before save")
	f.expect(f.bench.save_setup(), "scoped authored-start save remains available")
	var saved: Dictionary = Setup.read_named(f.bench._name.text)
	f.expect(saved.has("setup") and not saved.get("setup",{}).has("object_shards") and not saved.get("setup",{}).has("moving_inventory"),
		"authored save does not duplicate live moving inventory into World cells")
	var retired_generation: int = int(f.diagnostics().world_generation)
	f.expect(f.bench.load_setup(), "saved authored start can reopen through ordinary owner replacement")
	await f.until(f.installed, "saved starting setup reopens")
	f.play()
	await f.until(func(): return int(f.diagnostics().get("world_generation",0)) > retired_generation and f.tick()>0,
		"reopen creates a fresh fenced native World generation")
	f.expect(str(f.diagnostics().get("held_reason","")) == "", "replacement leaves no stale material or pose receipt hold")
	observations.final = f.diagnostics()
	observations.inventory_before = {"wood":initial_wood,"brick":initial_brick}
	await _finish()

func _finish() -> void:
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-workbench-completion-v1", "checks":f.checks,
		"failures":f.failures, "observations":observations,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"actual ordinary Workbench worker/native World/shared Rapier; owner NVIDIA display acceptance remains separate"}))
	quit(0 if f.failures.is_empty() else 1)
