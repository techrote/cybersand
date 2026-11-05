extends SceneTree

# Actual Main/native/Rapier admission and UI control, distinct from the smaller
# model-only options test. Focus override is disclosed, not physical input proof.
const Setup = preload("res://scripts/workbench_setup.gd")
const Actors = Setup.Actors
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
var host: Control
var ui
var checks := 0
var failures: Array[String] = []

func check(value: bool, reason: String) -> bool:
	checks += 1
	if not value: failures.append(reason)
	return value

func _initialize() -> void: run.call_deferred()

func ready() -> bool:
	return not ui.applied.is_empty() and host.pending_microscenario_apply.is_empty() and not ui.busy()

func wait_for(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec()+120000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		if host.simulation_worker.has_failed(): break
		await process_frame
	return check(predicate.call(),label+" / "+host.microscenario_error)

func acknowledged(label: String) -> bool:
	var serial: int = int(ui._pending_request_serial)
	if not await wait_for(ready,label): return false
	return check(serial > 0 and int(host.tower_context.get("scenario_request_serial",-1)) == serial \
		and bool(host.tower_context.get("scenario_request_applied",false)),label+" matching native acknowledgement / "+host.microscenario_error)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host); current_scene = host; ui = host.shared_workbench
	if await wait_for(ready,"blank installed"):
		await mixed_roster()
	key(KEY_SHIFT,false); key(KEY_CTRL,false)
	host.queue_free(); await process_frame; await process_frame
	print("WORKBENCH_PLAYER_ROSTER "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func mixed_roster() -> void:
	var ids: Array[String] = ["scooper","stuntbuggy","trialsbike","acrobat","arcadelander","jetbarrel","dryswarm","liquidswarm"]
	var positions := [Vector2(200,300),Vector2(400,300),Vector2(600,300),Vector2(800,300),Vector2(1000,300),Vector2(1200,300),Vector2(1450,300),Vector2(1650,300)]
	var start := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy))
	for index: int in ids.size(): start.actors.append(Setup.instance(ids[index],index+1,positions[index]))
	start.next_id = 9; start.selected = 1
	if not check(ui.apply(start),"submit mixed roster"): return
	if not await acknowledged("mixed roster acknowledged"): return
	check(host.physical_actor_session._definitions.size() == 6,"two material players do not consume fake physical actors")
	var expected_bodies := 0
	for index: int in 6: expected_bodies += Actors.definition(ids[index]).parts.size()
	check(host.physical_actor_session.bridge._members.size() == expected_bodies,"every independent articulated body has its own response owner")
	check(host.physical_actor_session.bridge._members[0].count == 5,"Scooper remains one body with five compound proxies")
	for id: int in range(2,7):
		check(ui.select_instance(id),"select player "+str(id))
		var slot: int = host.physical_actor_session.slot_for_instance(id)
		check(slot == id-1 and ui.pilot_slot == slot,"selected stable instance maps to physical slot")
		check(ui.body_state(id).model == ids[id-1],"selected observation has player model")
		key(KEY_SHIFT,true)
		check(ui.sample_controls().action.secondary,"authored Shift secondary retained")
		key(KEY_SHIFT,false); key(KEY_CTRL,true)
		check(not ui.sample_controls().action.secondary,"Ctrl does not replace secondary")
		key(KEY_CTRL,false)
		check(ui.open_flyer_options(),"player options open")
		check(ui._options_panel._numbers.has("options/mass_multiplier") and not ui._options_panel._numbers.has("options/boost_multiplier"),"player exposes real body controls without inert boost")
		check(not ui._options_panel._flags.has("fire_enabled"),"player does not invent flyer Fire outlet")
		ui._options_panel.hide()
	for id: int in [7,8]:
		check(ui.select_instance(id),"select native player")
		check(ui.pilot_slot == -1,"native player has no mechanical slot")
		var state: Dictionary = ui.body_state(id)
		check(not state.is_empty() and state.model == ids[id-1],"copied native field observation available")
		check(ui.open_flyer_options(),"native player options open")
		check(ui._options_panel._numbers.is_empty(),"native field options do not pretend to change mass")
		ui._options_panel.hide()
		check(ui.reset_selected(),"native field reset admitted without body recreation")
	check(ui.select_instance(4),"return to Acrobat")
	var prior_epoch: int = host._physical_epoch
	var profile: Dictionary = ui._profile("acrobat")
	profile.options.mass_multiplier = 1.25
	check(ui.apply_flyer_profile(profile),"submit player tuning through owner transaction")
	if not await acknowledged("player tuning acknowledged"): return
	check(host._physical_epoch > prior_epoch and is_equal_approx(ui.body_state(4).mass,1.5),"actual replacement applies player mass setting")
	check(ui.applied.actors.size() == 8 and host.physical_actor_session._definitions.size() == 6,"peer roster preserved across tuning")
