extends SceneTree

# Real Main input dispatch and native/Rapier sessions. The headless harness
# replaces only the display server's focused-window predicate.
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	var test_focus := true
	func _actor_window_has_focus() -> bool: return test_focus

var host: Control
var ui: Control
var failures: Array[String] = []
var checks := 0
var ledger: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error("WORKBENCH_INPUT "+reason)
	return ok

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release() -> void:
	for code: Key in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_Q,KEY_E,KEY_SHIFT,KEY_CTRL,KEY_SPACE]: key(code,false)

func wait_for(predicate: Callable, timeout_ms: int = 30000) -> bool:
	var until := Time.get_ticks_msec()+timeout_ms
	while Time.get_ticks_msec()<until:
		for row: Dictionary in host.tower_context.get("workbench_emitters",[]):
			if row.has("nozzle"):
				ledger["%d/%s/%s"%[row.instance_id,row.nozzle,"inserted" if row.changed_cells else row.reason]]=row.duplicate()
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		await process_frame
	return false

func ticks(count: int) -> bool:
	var target: int = host.physical_actor_session.tick+count
	return await wait_for(func()->bool: return host.physical_actor_session.tick>=target)

func test_controls() -> void:
	var data := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	data.actors = [Setup.instance("kestrel",1,Vector2(250,230)),Setup.instance("midge",2,Vector2(325,230)),Setup.instance(Setup.BARREL,3,Vector2(375,230))]
	data.next_id = 4
	data.selected=1
	# A wall touches the left Midge nozzle, clear of its four-cell wide hull.
	for y: int in range(220,270,3): data.edits.append([319,y,3,58])
	for x: int in range(180,420,12): data.edits.append([x,275,18,58])
	data.fire=true
	var epoch: int = host._physical_epoch
	if not check(ui.apply(data) and await wait_for(func()->bool: return host._physical_epoch>epoch and host.pending_microscenario_apply.is_empty()),"admitted physical graph"): return
	if not check(ui.toggle_pause() and await ticks(4) and not host._actor_input_rearm,"neutral rearm in play"): return
	key(KEY_W,true);key(KEY_S,true);key(KEY_Q,true);key(KEY_SHIFT,true)
	if not check(await ticks(18),"Kestrel controls progress"): return
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var first := session.workbench_actor_state(1)
	check(first.controller.boost_multiplier==2.0 and first.controller.side_thrust<0,"Shift boost and Q side thruster")
	check(ledger.has("1/s-rear/inserted") and ledger["1/s-rear/inserted"].material==26,"Kestrel S inserts Gunpowder")
	check(ledger.has("1/main-fire/inserted"),"real thruster Fire")
	key(KEY_CTRL,true); await ticks(2)
	check(session.workbench_actor_state(1).controller.movement_mode=="brake","Ctrl brake")
	# A numeric editor must revoke future drive, brushing, source and nozzles.
	ui._details.show()
	ui._fields.budget.get_line_edit().grab_focus()
	await ticks(6)
	check(host._actor_input_rearm and session._commands[0].is_empty() and ui._drag_button==0,"numeric focus revokes pilot and brush")
	ui._fields.budget.get_line_edit().release_focus()
	check(await ticks(6) and session._commands[0].is_empty(),"held controls cannot rearm after editing")
	release()
	await ticks(2)
	key(KEY_E,true)
	await ticks(6)
	check(session.workbench_actor_state(1).controller.side_thrust>0,"fresh E side thrust")
	host.test_focus=false
	await ticks(3)
	check(session._commands[0].is_empty() and host._actor_input_rearm,"focus loss retires emission and flight")
	host.test_focus=true
	await ticks(3)
	check(session._commands[0].is_empty(),"restored focus with held E stays neutral")
	check(ui.select_instance(2),"switch to Midge")
	await ticks(4)
	check(session._commands[0].is_empty() and session._commands[1].is_empty(),"held input cannot transfer actors")
	# Return the unpiloted Midge to its saved attitude opposite the wall.
	# Its actual free-fall landing can otherwise rotate the port away from it.
	release()
	if not check(ui.toggle_pause() and ui.reset_selected(),"reset Midge opposite fixed wall"): return
	if not check(await wait_for(func()->bool: return host._physical_epoch>epoch+1 and host.pending_microscenario_apply.is_empty()),"reset acknowledged"): return
	session=host.physical_actor_session
	if not check(ui.toggle_pause() and await ticks(3),"neutral rearm after reset"): return
	key(KEY_Q,true);key(KEY_E,true)
	await ticks(16)
	check(ledger.has("2/e-right/inserted") and ledger["2/e-right/inserted"].material==8,"Midge right Lava dispenser")
	check(ledger.has("2/q-left/blocked") or ledger.has("2/q-left/occupied"),"Midge left nozzle cannot excavate obstruction")
	check(ui.toggle_pause() and session._commands[1].is_empty(),"pause immediately retires held ports")
	check(ui.toggle_pause() and await ticks(3) and session._commands[1].is_empty(),"held ports cannot resume after pause")
	release(); await ticks(2)
	check(ui.select_instance(3) and ui.pilot_slot<0,"passive prop has no pilot")

func run() -> void:
	var pad := CyberPlayerPlaygroundInput.from_state({},Vector2(0.3,-0.7),Vector3i(1,1,0),-1.0)
	check(pad.primary and pad.secondary and pad.trim<0 and pad.move.y<0,"sampled gamepad A/B/shoulder and stick")
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	ui=host.shared_workbench
	if check(await wait_for(func()->bool: return not ui.applied.is_empty(),60000),"workbench installed"): await test_controls()
	release()
	host.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH_INPUT ",JSON.stringify({"checks":checks,"failures":failures,"receipts":ledger}))
	quit(int(not failures.is_empty()))
