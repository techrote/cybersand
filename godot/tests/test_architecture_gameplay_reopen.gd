extends "res://tests/test_architecture_gameplay.gd"
## This script is a separate process from the route producer. It loads ordinary
## authored starts, never restores the recorded trajectory or command leases.

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_GAMEPLAY_EVIDENCE_DIR")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://architecture/gameplay")
	manifest_path=evidence.path_join("architecture-gameplay.json")
	var file:=FileAccess.open(manifest_path,FileAccess.READ)
	if not check(file!=null and file.get_length()<=64*1024*1024,"bounded previous-process actor witness available"): await finish(); return
	var prior: Variant=JSON.parse_string(file.get_as_text()); file.close()
	if not check(prior is Dictionary and prior.get("attempts") is Array and prior.attempts.size()>=1 and prior.attempts.size()<=6,"finite previous-process authored starts available"): await finish(); return
	if not await start_host(): await finish(); return
	for previous: Dictionary in prior.attempts: await reopen(previous)
	output={"format":"cybersand-architecture-actor-reopen-v1","source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"route_source_revision":prior.get("source_revision",""),"route_report_sha256":FileAccess.get_sha256(manifest_path),
		"native_tick_source":Witness.NATIVE_TICK_SOURCE,
		"native_active_core_capacity":int(ProjectSettings.get_setting("cybersand/native_active_core_capacity",1024)),
		"development_memory_configuration":development_core_capacity>0,"godot":Engine.get_version_info().string,
		"display":DisplayServer.get_name(),"attempts":attempts,
		"scope":"Fresh-process ordinary authored-start replay, exact native route material readback, neutral actor leases and new measured actor commands. No resumed live trajectory or general playability claim."}
	await finish()

func reopen(previous: Dictionary) -> void:
	var identity: String=previous.get("id","witness")
	var path: String=evidence.path_join(str(previous.get("start_path","")))
	if not check(FileAccess.get_sha256(path)==previous.get("saved_start_sha256","missing"),identity+": portable authored start has its exact retained identity"): return
	var start:=_read_start({"start_path":path})
	if not check(not start.is_empty() and start.actors.size()==1,identity+": fresh process validates the saved authored actor start"): return
	var name_text: String=previous.get("saved_start_name","")
	if not check(Setup.write_named(name_text,start).is_empty(),identity+": portable start admitted to ordinary named Setup storage"): return
	wb._name.text=name_text
	if not check(wb.load_setup(),identity+": ordinary Load start opens the saved architecture") or not await until(installed,identity+": fresh native authored start installed"): return
	var actor_id:=int(wb.applied.selected)
	var view: Dictionary=wb.actor_observation(actor_id)
	var spawn:=Setup.point(previous.spawn)
	check(host.paused and bool(view.get("suspended",false)),identity+": fresh authored start opens paused")
	check(view.get("position",Vector2.INF).distance_to(spawn)<=0.25,identity+": actor reopens at the authored spawn rather than the prior landed pose")
	check(int(view.get("lease_remaining",-1))==0 and int(view.get("last_sequence",0))==-1,identity+": prior commands and leases are not restored")
	check(wb.applied.actors[0].control.source=="policy" and wb.applied.actors[0].control.policy=="external",identity+": authored external controller choice survives ordinary reopen")
	var region:=Module.rect(previous.get("inspection_region",[]))
	var captured: Dictionary=await wb.capture_batch_source(region)
	check(captured.get("ok",false) and captured.config.source_provenance.crop_sha256==previous.get("source_crop_sha256",""),identity+": every native route material identity matches the pre-Play authored crop")
	check(wb.art_batches==null or not wb.art_batches.provider.active,identity+": reopen starts no provider request or architectural execution")
	if not check(wb.toggle_pause(),identity+": fresh Play begins selected actual actor trial"): return
	if not await until(func() -> bool: return not wb.actor_observation(actor_id).get("suspended",true),identity+": fresh actor owner begins Play"): return
	var old_command: Dictionary=previous.get("first_command",{}).duplicate(true)
	check(not old_command.is_empty() and not wb.submit_actor_policy(actor_id,old_command),identity+": prior-process issued command cannot control the reopened owner")
	var native_begin:=native_tick()
	var render_cached_begin:=render_cached_native_tick()
	var first: Dictionary=wb.actor_observation(actor_id,true)
	var actor_begin:=int(first.tick)
	var target:=spawn+Vector2(24,-8)
	var samples: Array=[]
	var last_tick:=-1
	var deadline:=Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	var accepted_all:=true
	while Time.get_ticks_msec()<deadline:
		var observed: Dictionary=wb.actor_observation(actor_id,true)
		var tick:=int(observed.get("tick",-1))
		if tick<=last_tick: await process_frame; continue
		last_tick=tick
		if tick-actor_begin>=90: break
		var command:=ActorSession.make_command(observed,int(observed.get("last_sequence",-1))+1,Witness.action(observed,target),12)
		var accepted: bool=wb.submit_actor_policy(actor_id,command)
		accepted_all=accepted_all and accepted
		samples.append(Witness.sample(observed,native_tick(),command,accepted,render_cached_native_tick()))
		await process_frame
	var final: Dictionary=wb.actor_observation(actor_id)
	check(accepted_all and samples.size()>=30,identity+": newly issued observation-bound commands are accepted after reopen")
	check(int(final.tick)>actor_begin and native_tick()>native_begin and final.position.distance_to(spawn)>1.0,identity+": fresh native and Rapier owners produce measured actor movement")
	var native_end:=native_tick()
	var render_cached_end:=render_cached_native_tick()
	await pause_owners(actor_id,identity)
	attempts.append({"id":identity,"start_sha256":FileAccess.get_sha256(path),"source_crop_sha256":captured.get("config",{}).get("source_provenance",{}).get("crop_sha256",""),
		"spawn":previous.spawn,"final_position":Witness._json(final.position),"actor_ticks":int(final.tick)-actor_begin,
		"native_tick_source":Witness.NATIVE_TICK_SOURCE,"native_ticks":native_end-native_begin,
		"native_tick_bounds":{"begin":native_begin,"end":native_end},
		"render_cached_native_tick_bounds":{"begin":render_cached_begin,"end":render_cached_end},
		"render_cached_native_ticks":render_cached_end-render_cached_begin,
		"acknowledged_pause_ticks":{"native_published":native_tick(),"native_render_cached":render_cached_native_tick(),"actor":int(wb.actor_observation(actor_id).get("tick",-1))},"fresh_commands_accepted":accepted_all,"samples":samples})

func finish() -> void:
	output["checks"]=checks; output["failures"]=failures; output["passed"]=failures.is_empty()
	if not evidence.is_empty():
		var file:=FileAccess.open(evidence.path_join("architecture-gameplay-reopen.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(output,"",true,true)); file.close()
	print("ARCHITECTURE_GAMEPLAY_REOPEN: %d checks, %d failures" % [checks,failures.size()])
	if is_instance_valid(host): host.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
