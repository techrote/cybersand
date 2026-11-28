extends "res://tests/test_workbench_actor_composition.gd"

# Focused actual-Workbench regression for retained-pose safety after equipment
# changes the joint graph. Uses real Rapier bodies and native prepared owners.

func run() -> void:
	root.size = Vector2i(1440,900)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench != null,"ordinary Workbench opens"):
		finish()
		return
	ui = host.shared_workbench
	if not await until(installed,"initial native owner installs"):
		finish()
		return
	var setup := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	Setup._box(setup.edits,Vector2i(0,330),Vector2i(512,342),Setup.WALL)
	setup.actors = [Setup.instance("runner",1,Vector2(140,200)),
		Setup.instance(Setup.BARREL,2,Vector2(340,200))]
	setup.selected = 1
	setup.next_id = 3
	var requested: bool = ui.apply(setup)
	if not check(requested,"equipped actor and barrel prepare: "+ui.message) or not await until(installed,"topology cast installs"):
		finish()
		return
	var owner = host.physical_actor_session
	var rig = owner._rigs[owner.slot_for_instance(1)]
	var body_count: int = owner.bodies().size()
	var joints: int = rig.physical_joint_count()
	check(rig.release_usable(),"equipment release clears a real physical joint")
	check(rig.physical_joint_count()==joints-1,"released equipment has one fewer live constraint")
	check(not str(owner.capture_workbench_assembly(1).pose_error).is_empty(),"changed topology is identified before prepared authoring")
	ui.select_instance(2)
	var authored: Dictionary = ui.applied.duplicate(true)
	var first_pose: Array = owner.capture_workbench_assembly(1).parts
	var other_pose: Array = owner.capture_workbench_assembly(2).parts
	var capacity := {"version":1,"logical_limit":64,"body_limit":128,"proxy_limit":128}
	check(not ui.actor_interaction.place_exact(2,Vector2(380,210),30.0),"unrelated barrel placement refuses unsafe retained equipment graph")
	check(not ui.set_sandbox_capacity(capacity),"capacity transaction refuses unsafe retained equipment graph")
	var tuning: Dictionary = ui.actor(ui.applied,2).options.duplicate(true)
	tuning.budget = 30.0
	check(not ui.set_actor_tuning(2,tuning),"physical tuning transaction refuses unsafe retained equipment graph")
	check(not ui.apply_actor_equipment(1,3),"equipment Apply explicitly refuses changed live topology")
	check(ui.applied==authored and host.physical_actor_session==owner and not ui.busy(),
		"all refusals preserve authored data and the exact native/Rapier owner")
	check(owner.capture_workbench_assembly(1).parts==first_pose and owner.capture_workbench_assembly(2).parts==other_pose \
		and owner.bodies().size()==body_count and rig.physical_joint_count()==joints-1,
		"refusal preserves both actors, velocities, released part and remaining joint graph")
	check(ui.select_instance(1) and ui.reset_selected(),"explicit Reset may reconstruct its intentionally retired graph")
	if not await until(installed,"Reset adopts a new native and physical owner"):
		finish()
		return
	check(host.physical_actor_session!=owner and host.physical_actor_session.bodies().size()==body_count,
		"Reset replaces the owner with exactly the original physical population")
	check(str(host.physical_actor_session.capture_workbench_assembly(1).pose_error).is_empty() \
		and host.physical_actor_session._rigs[0].physical_joint_count()==joints,
		"Reset restores the authored connected equipment graph")
	check(host.physical_actor_session.capture_workbench_assembly(2).parts==other_pose,
		"Reset preserves the unrelated passive actor's complete pose")
	check(ui.apply_actor_equipment(1,3),"ordinary equipment Apply remains accepted after explicit Reset")
	if not await until(installed,"equipment Apply adopts"):
		finish()
		return
	check(int(ui.actor_observation(1).equipment.usable_index)==3,"accepted starting equipment reaches the real actor runtime")
	check(ui.set_sandbox_capacity(capacity),"intact assembly accepts explicit expanded capacity")
	if not await until(installed,"capacity change adopts"):
		finish()
		return
	check(ui.applied.sandbox_capacity==capacity and host.physical_actor_session.bodies().size()==body_count,
		"expanded budget changes no current actor or part population")
	check(not host.simulation_worker.has_failed() and host.sample_refusals.is_empty(),
		"native owner and copied body/equipment publications remain healthy")
	finish()


func finish() -> void:
	print("WB_ACTOR_TOPOLOGY ",JSON.stringify({"checks":checks,"failures":failures,
		"elapsed_msec":Time.get_ticks_msec()-started_msec}))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
