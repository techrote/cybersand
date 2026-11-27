extends SceneTree

# Real ordinary Workbench group application beside human and external actors.
# Uses the public control owners and actual native/Rapier progress; no fake
# World, copied body, injected pose or physical keyboard/playfeel claim.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var wb: Control
var editor: Window
var session: Node
var checks := 0
var failures: Array[String] = []
var cancellations: Array[int] = []
var complete_group_visible := true
var expected_profile: Dictionary = {}
var phases: Array = []


func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	set_meta("cybersand_feature","shared_workbench")
	var adapter: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var start := Setup.fresh(adapter.call(&"default_liquid_policy"),Vector2i(512,512))
	start.edits = [[0,400,512,12,58],[108,380,12,20,16]]
	for row: Array in [["runner",101,80],["monowheel",202,200],["runner",303,320],["crawler",404,440]]:
		var actor := Setup.instance(str(row[0]),int(row[1]),Vector2(float(row[2]),340))
		var control := Catalog.control_for(actor)
		control.source = "human" if int(row[1])==303 else "policy"
		control.policy = "external"
		control.usable_index = -1
		actor.control = control
		start.actors.append(actor)
	start.selected = 303
	start.next_id = 405
	set_meta("cybersand_playable_recovery",{"workbench":start})
	run.call_deferred()


func check(value: bool,label: String) -> bool:
	checks += 1
	print("AMBIENT_LIVING_GROUP_CHECK ",label," ",value)
	if not value: failures.append(label); push_error(label)
	return value


func until(predicate: Callable,label: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	var progress_at := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		if Time.get_ticks_msec()>=progress_at:
			print("AMBIENT_LIVING_GROUP_WAIT ",label); progress_at=Time.get_ticks_msec()+10000
		await process_frame
	return check(false,label+" did not complete within the established operation watchdog")


func installed() -> bool:
	return wb != null and not wb.applied.is_empty() and not wb.busy() and host.pending_microscenario_apply.is_empty()


func control(id: int) -> Dictionary:
	return Catalog.control_for(wb.actor(wb.applied,id))


func view(id: int) -> Dictionary:
	return session.workbench_control(id)


func body_ids() -> Array:
	return session.bodies().map(func(body: RigidBody2D): return body.get_rid())


func native_tick() -> int:
	var publication: CyberSimulationSnapshot = host.simulation_worker.take_latest_snapshot(0)
	return int(publication.tick_index) if publication != null else -1


func progress(count: int,label: String) -> bool:
	var native_before := native_tick()
	var physical_before: int = session.tick
	if not await until(func() -> bool: return native_tick()>=native_before+count and session.tick>=physical_before+count,label): return false
	phases.append({"phase":label,"native_ticks":native_tick()-native_before,"physical_ticks":session.tick-physical_before})
	return true


func choose_group() -> void:
	editor._group_list.deselect_all()
	for index: int in editor._group_list.item_count:
		if int(editor._group_list.get_item_metadata(index)) in [101,202]: editor._group_list.select(index,false)


func cancelled(slot: int,_epoch: int) -> void:
	cancellations.append(slot)
	for id: int in [101,202]: complete_group_visible = complete_group_visible and view(id).ambient==expected_profile


func human_action() -> bool:
	return session.submit_workbench_action(303,{"move":Vector2.RIGHT,"effort":0.25},
		{"q":false,"e":false,"s":false,"boost":false},false)


func exercise() -> void:
	check(Catalog.Capacity.defaults().logical_limit == 8 and Catalog.MAX_AMBIENT_CONTROLLERS == 8,
		"ordinary host retains the eight-actor default and AMBIENT budget")
	check(wb.applied.actors.size()==4 and session.bodies().size()>=4,"four authored actors own real retained Rapier bodies")
	check(wb._ambient_profile_editor==null and not session._ambient_sensor_active,"ordinary startup has no ambient editor or material sensor")
	wb.open_ambient_profile(101)
	editor = wb._ambient_profile_editor
	if not check(editor != null and editor.visible,"explicit ordinary action opens living profile editor"): return
	var draft := Profile.preset("restless_explorer")
	draft.regions = []
	draft.seed = 251101
	if not check(editor.replace_draft(draft),"living personality stages without changing any producer"): return
	expected_profile = Profile.canonicalize(editor.staged_profile())
	editor.refresh_group()
	choose_group()
	if not check(wb.pilot_instance(303) and wb.pilot_id()==303,"unselected human actor is piloted through the ordinary Workbench"): return
	if not check(wb.toggle_pause() and not host.paused,"ordinary Play starts the native and physical owners"): return
	if not await progress(12,"ordinary producers before living-group admission"): return
	var owners := {"worker":host.simulation_worker.get_instance_id(),"session":session.get_instance_id(),
		"run_id":session.run_id,"epoch":session.epoch,"world":host.simulation_worker.paint_state().generation}
	var bodies := body_ids()
	var human_configuration := control(303)
	var external_configuration := control(404)
	if not check(human_action(),"real human command is admitted before group handoff"): return
	var human_before := view(303)
	var external_before := view(404)
	var external_observation: Dictionary = session.workbench_policy_observation(404)
	var external_command := Session.make_command(external_observation,int(external_observation.last_sequence)+1,{"move":Vector2.LEFT,"effort":0.2},12)
	var stale_commands: Array = []
	var generations: Array = []
	for id: int in [101,202]:
		var observation: Dictionary = session.workbench_policy_observation(id)
		stale_commands.append(Session.make_command(observation,int(observation.last_sequence)+1,{"move":Vector2.RIGHT,"effort":0.2},12))
		generations.append(int(view(id).generation))
	session.input_cancelled.connect(cancelled)
	var applied: bool = editor.apply_group_draft()
	session.input_cancelled.disconnect(cancelled)
	if not check(applied,"mounted Group Apply acknowledges both living actors during Play"): return
	check(not host.paused and wb.pilot_id()==303,"group application preserves ordinary Play and unselected human pilot")
	check(cancellations.size()==2 and not cancellations.has(session.slot_for_instance(303))
		and not cancellations.has(session.slot_for_instance(404)) and complete_group_visible,
		"only selected authorities retire and every cancellation observer sees the complete native group")
	for index: int in 2:
		var id: int = 101 if index==0 else 202
		check(control(id).ambient==expected_profile and view(id).ambient==expected_profile,"authored and physical group members share exact acknowledged profile values")
		check(int(view(id).generation)==int(generations[index])+1,"each selected actor retires its prior command generation exactly once")
		check(not session.submit(stale_commands[index],&"policy"),"old selected-actor external authority cannot command the new ambient controller")
	check(control(303)==human_configuration and int(view(303).generation)==int(human_before.generation)
		and int(view(303).accepted)==int(human_before.accepted),"unselected human configuration, authority and accepted command survive the transaction")
	check(control(404)==external_configuration and int(view(404).generation)==int(external_before.generation),
		"unselected external actor retains its exact configuration and authority")
	check(wb.submit_actor_policy(404,external_command),"external observation issued before group Apply remains authoritative afterward")
	check(human_action(),"fresh human action remains admissible beside the new living group")
	check(body_ids()==bodies and host.simulation_worker.get_instance_id()==owners.worker
		and session.get_instance_id()==owners.session and session.run_id==owners.run_id
		and session.epoch==owners.epoch and host.simulation_worker.paint_state().generation==owners.world,
		"group application retains native World, worker, physical session and every actual body identity")
	if not await progress(30,"living group beside human and external actors"): return
	for id: int in [101,202]:
		check(int(view(id).diagnostics.get("ambient",{}).get("decisions",0))>0 and int(view(id).accepted)>0,
			"actual living actor makes and submits decisions while the ordinary owners advance")
	check(control(303)==human_configuration and control(404)==external_configuration and wb.pilot_id()==303,
		"continued group activity does not replace either unselected controller")
	# A prepared first member must not be changed when the second has acquired a
	# newer authored control. Keep this guard on the actual mounted editor path.
	editor.refresh_group()
	choose_group()
	var first := control(101)
	var first_generation: int = view(101).generation
	var newer := control(202)
	newer.ambient.name = "Independent second resident"
	check(wb.set_actor_control(202,newer),"ordinary individual edit changes the second group member")
	check(not editor.apply_group_draft(),"stale second member refuses the complete mounted group")
	check(control(101)==first and int(view(101).generation)==first_generation and control(202)==newer,
		"refused stale group leaves the first authority and newer second profile intact")
	check(control(303)==human_configuration and control(404)==external_configuration,
		"refused group leaves unselected human and external actors intact")
	check(human_action(),"human commands remain accepted after successful and refused group transactions")
	editor.hide()
	if not await progress(12,"living group after editor closes"): return
	check(body_ids()==bodies and session.run_id==owners.run_id and host.simulation_worker.get_instance_id()==owners.worker,
		"editor close and subsequent living activity preserve all physical and native owners")


func run() -> void:
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	wb = host.shared_workbench
	if await until(installed,"ordinary four-actor native installation"):
		session = host.physical_actor_session
		await exercise()
	host.queue_free()
	await process_frame
	await process_frame
	print("AMBIENT_LIVING_GROUP_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures,"phases":phases,
		"scope":"Real ordinary native/Rapier group and unselected human/external authority; no physical keyboard or owner playfeel acceptance"}))
	quit(0 if failures.is_empty() else 1)
