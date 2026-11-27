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
	await f.validate_quantity_ledger()
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
	if not await f.advance(120, "ordinary worker and physical structures continue through fall and footing collision"):
		await _finish()
		return
	await f.pause()
	await f.until(f.coherent, "paused upload matches native material and pose")
	var after: Dictionary = f.diagnostics()
	var moved: bool = false
	var rotated: bool = false
	for before: Dictionary in first_bodies:
		for body: Dictionary in after.physics.bodies:
			if int(body.id) == int(before.id) and Vector2(float(body.x)-float(before.x),float(body.y)-float(before.y)).length() > 1.0:
				moved = true
			if int(body.id) == int(before.id) and absf(wrapf(float(body.backend_rotation)-float(before.backend_rotation),-PI,PI)) > 0.02:
				rotated = true
	f.expect(moved, "actual Rapier transform progressed after support cut")
	f.expect(rotated,"coherent facade actually topples under Rapier contact with the asymmetric footing")
	f.expect(int(after.physical_steps) > 120 and int(after.native_pose_acknowledgements) > 120,
		"each physical segment has native pose acknowledgements")
	f.expect(f.host.simulation_worker.get_instance_id() == original_worker and int(after.native_instance_id) == original_native,
		"ordinary native World and worker survive detachment without a second owner")
	f.expect(int(after.world_generation) == original_generation, "detachment preserves ordinary World generation")
	f.validate_physics()
	await f.validate_quantity_ledger()
	f.expect(f.material_count(7) == initial_wood, "independent uploaded World plus owning-shard Wood inventory conserved")
	f.expect(f.material_count(43) == initial_brick, "independent uploaded World plus owning-shard Brick inventory conserved")
	var paused_tick: int = f.tick()
	var paused_steps: int = int(f.diagnostics().physical_steps)
	for i: int in range(12): await process_frame
	f.expect(f.tick() == paused_tick and int(f.diagnostics().physical_steps) == paused_steps,
		"Pause stops semantic and physical progression after admitted receipts drain")
	var before_step_intervals: int = int(f.diagnostics().physical_intervals)
	var before_step_actor_tick: int = int(f.host.physical_actor_session.tick)
	f.expect(f.bench.step_once(),"ordinary paused single-step request accepted")
	await f.until(func(): return f.tick() == paused_tick+1 and bool(f.diagnostics().physics_ready) and f.coherent(),
		"paused single-step completes one native interval and coherent physical acknowledgement")
	for i: int in range(12): await process_frame
	f.expect(f.host.paused and f.tick() == paused_tick+1,"single-step leaves ordinary simulation paused after exactly one tick")
	f.expect(int(f.diagnostics().physical_intervals) == before_step_intervals+1 and int(f.host.physical_actor_session.tick) == before_step_actor_tick+1,
		"single-step advances one shared physical interval and actual actor tick")
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
		# The terminal receipt can precede Main's next display callback. Two
		# coherent old frames still describe the pre-cut inventory.
		if not await f.until(func(): return f.runtime().physics_ready() and f.coherent() \
			and f.bench.object_shard_m4_port.latest_edit_presented(f.runtime().publication,f.runtime().capabilities),
			"post-edit geometry and visible publication installed for the authenticated Cut transaction"):
			await _finish()
			return
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
	var ignition_witnesses: Array[Dictionary] = await f.ignite_exposed_wood()
	f.expect(ignition_witnesses.size() == 4,"four source-bound exposed moving Wood cells were genuinely ignited")
	var pre_fire: int = f.material_count(7)
	var products_before: int = int(f.frame().get("metrics",{}).get("products_created",0))
	f.play()
	await f.advance(120, "ignited moving material continues native chemistry")
	await f.pause()
	await f.until(f.coherent, "post-combustion publication coherent")
	for witness: Dictionary in ignition_witnesses:
		var source: Dictionary = witness.source
		var reacted: Dictionary = f.owned_cell_state(int(source.owner),int(source.cell))
		# The admitted Wood law starts at 240 and decrements every two ticks.
		# Exposed material supplies real empty native product destinations.
		f.expect(f.material_count(7)<pre_fire or (reacted.get("material") == 7 and int(reacted.get("state_b",0))>0 \
			and int(reacted.get("state_b",0))<int(witness.before.get("state_b",0))),
			"exact source-bound exposed moving Wood continues its native combustion state")
		witness.after = reacted
	f.expect(int(f.frame().get("metrics",{}).get("products_created",0))>products_before,
		"continued moving Wood reaction creates authentic native Fire/Smoke products")
	observations.combustion = {"witnesses":ignition_witnesses,
		"products_before":products_before,"products_after":f.frame().get("metrics",{}).get("products_created",0)}
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
	observations.authored_reopen = {"process_id":OS.get_process_id(),
		"file_sha256":FileAccess.get_sha256(Setup._path(f.bench._name.text)),
		"installed_sha256":JSON.stringify(f.bench.applied).sha256_text()}
	observations.final = f.diagnostics()
	observations.inventory_before = {"wood":initial_wood,"brick":initial_brick}
	await _finish()

func _finish() -> void:
	f.validate_display()
	observations.display_coherence = f.display_witness()
	observations.inventory_witnesses = f.inventory_witnesses
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-workbench-completion-v1", "checks":f.checks,
		"failures":f.failures, "observations":observations,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"actual ordinary Workbench worker/native World/shared Rapier; owner NVIDIA display acceptance remains separate"}))
	quit(0 if f.failures.is_empty() else 1)
