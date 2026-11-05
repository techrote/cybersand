extends SceneTree

const Prefs = preload("res://scripts/flyer_preferences.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
var host: Control
var ui
var checks: int = 0
var failures: Array[String] = []
var profile_path: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error("FLYER_OPTIONS_UI: "+reason)
	return ok

func wait_for(test: Callable, reason: String) -> bool:
	var deadline: int = Time.get_ticks_msec()+90000
	while not test.call() and Time.get_ticks_msec()<deadline:
		if host.simulation_worker.has_failed(): break
		await process_frame
	return check(test.call(),reason+" / "+host.microscenario_error)

func ready() -> bool:
	return not ui.applied.is_empty() and host.pending_microscenario_apply.is_empty() and not ui.busy()

func key(code: Key, down: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return event

func released() -> void:
	for code: Key in [KEY_G,KEY_Q,KEY_E,KEY_W,KEY_4,KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_F2,KEY_DELETE]: key(code,false)

func run() -> void:
	root.size = Vector2i(1920,1080)
	root.gui_embed_subwindows = true
	profile_path = OS.get_environment("CYBERSAND_FLYER_UI_PROFILE")
	if profile_path.is_empty(): profile_path = "user://workbench/options-ui-%d.json" % OS.get_process_id()
	ProjectSettings.set_setting("cybersand/flyer_profile_path",profile_path)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	current_scene = host
	ui = host.shared_workbench
	if await wait_for(ready,"blank acknowledged"):
		if OS.get_environment("CYBERSAND_FLYER_UI_REOPEN") == "1": await reopened()
		else: await edit_profile()
	released()
	host.queue_free()
	await process_frame
	await process_frame
	print("FLYER_OPTIONS_UI ",JSON.stringify({"checks":checks,"failures":failures,"profile_path":profile_path}))
	quit(int(not failures.is_empty()))

func reopened() -> void:
	check(ui.preferences.has_saved("kestrel"),"fresh host launch loaded Kestrel profile")
	if not check(ui.pilot_model("kestrel"),"place saved Kestrel"): return
	if not await wait_for(ready,"saved Kestrel acknowledged"): return
	var actor: Dictionary = ui.actor(ui.applied,ui.selected_id())
	var state: Dictionary = ui.body_state(ui.selected_id())
	check(actor.options.mass_multiplier == 1.5 and actor.customization.acceleration == 1.25,"new placement uses persisted model tuning")
	check(state.customization.swap_side_thrusters and state.customization.s_material == 2,"actual new rig has saved side/emission options")
	check(ui._active_profile.bindings.primary == [KEY_G] and ui.fire_enabled,"fresh host uses persisted key and Fire toggle")

func edit_profile() -> void:
	if not check(ui.pilot_model("kestrel"),"pilot Kestrel"): return
	if not await wait_for(ready,"Kestrel acknowledged"): return
	var id: int = ui.selected_id()
	check(ui.toggle_pause() and not host.paused,"play before options")
	if not check(ui.open_flyer_options(),"open controls window"): return
	var editor = ui._options_panel
	check(host.paused and ui.controls_blocked(),"modal pauses and blocks actor control")
	check(editor.staged_profile().options == ui.actor(ui.applied,id).options,"opening the editor preserves exact applied multipliers")
	# Capture itself must not feed the craft, including reserved navigation.
	editor.begin_capture("primary",0)
	editor._input(key(KEY_F2,true))
	check(current_scene == host and editor.visible and editor._capture_action == "primary","F2 is refused during capture without navigating")
	key(KEY_F2,false)
	editor._input(key(KEY_G,true))
	check(editor._draft.bindings.primary == [KEY_G],"actual key event stages new primary binding")
	host._publish_workbench_keyboard()
	check(host.physical_actor_session._commands[ui.pilot_slot].is_empty(),"captured held key does not actuate while editing")
	editor._numbers["options/mass_multiplier"].value = 1.5
	editor._numbers["tuning/acceleration"].value = 1.25
	editor._numbers["tuning/s_amount"].value = 2.0
	editor._numbers["tuning/fire_amount"].value = 0.5
	editor._flags["tuning/swap_side_thrusters"].button_pressed = true
	editor._flags.fire_enabled.button_pressed = true
	editor._materials.s_material.select(editor._materials.s_material.get_item_index(2))
	# Saving is deferred until the real owner acknowledgement.
	var before: String = FileAccess.get_sha256(profile_path) if FileAccess.file_exists(profile_path) else ""
	editor._submit()
	check(not editor.visible and not host.pending_microscenario_apply.is_empty(),"Save submits real prepared replacement")
	check((FileAccess.get_sha256(profile_path) if FileAccess.file_exists(profile_path) else "") == before,"no profile written before owner acknowledgement")
	ui._fire_changed(false)
	check((FileAccess.get_sha256(profile_path) if FileAccess.file_exists(profile_path) else "") == before,"busy Fire toggle cannot persist stale settings")
	if not await wait_for(ready,"profile installed"): return
	check(not host.paused and ui.preferences.has_saved("kestrel"),"accepted profile persisted and prior play restored")
	var state: Dictionary = ui.body_state(id)
	check(state.customization.acceleration == 1.25 and state.customization.swap_side_thrusters,"actual rig received customization")
	check(state.customization.s_material == 2 and state.customization.s_amount == 2.0,"actual dispenser received chosen material and rate")
	check(ui.fire_enabled and ui._active_profile.bindings.primary == [KEY_G],"accepted controls became active")
	host._publish_workbench_keyboard()
	check(host._actor_input_rearm and host.physical_actor_session._commands[ui.pilot_slot].is_empty(),"captured key must be released after Apply")
	key(KEY_G,false)
	host._publish_workbench_keyboard()
	check(not host._actor_input_rearm,"neutral input rearms new bindings")
	key(KEY_G,true)
	host._publish_workbench_keyboard()
	check(host.physical_actor_session._commands[ui.pilot_slot].get("primary",false),"new binding actuates through leased session: "+host.physical_actor_session.last_error+" / "+str(host.physical_actor_session._commands[ui.pilot_slot])+" rearm="+str(host._actor_input_rearm))
	key(KEY_G,false)
	var epoch: int = host._physical_epoch
	ui._input(key(KEY_4,true)); key(KEY_4,false)
	await process_frame
	check(host._physical_epoch == epoch and ui.actor(ui.applied,ui.selected_id()).model == "kestrel","number key no longer selects flyers")
	ui._input(key(KEY_BRACKETRIGHT,true)); key(KEY_BRACKETRIGHT,false)
	if not await wait_for(ready,"bracket model cycle acknowledged"): return
	check(ui.actor(ui.applied,ui.selected_id()).model == "afterglow","bracket cycles models")
	check(ui.pilot_model("kestrel"),"return to saved Kestrel")
	if not await wait_for(ready,"saved model restored"): return
	check(ui.actor(ui.applied,ui.selected_id()).options.mass_multiplier == 1.5 and ui._active_profile.bindings.primary == [KEY_G],"model switch restores its saved body settings and binding")
	# A legacy start remains valid and receives neutral extensions, while its
	# explicit instance tuning outranks the user's saved defaults.
	var legacy: Dictionary = ui.applied.duplicate(true)
	legacy.version = 2
	for a: Dictionary in legacy.actors:
		a.erase("customization")
		a.erase("usable_index")
		a.erase("usable_power")
	legacy.actors[0].options.mass_multiplier = 2.5
	check(Setup.validate(legacy).is_empty(),"legacy v2 start accepted")
	check(ui.apply(legacy),"load legacy authored settings")
	if not await wait_for(ready,"legacy start installed"): return
	check(ui.applied.version == Setup.VERSION and ui.applied.actors[0].options.mass_multiplier == 2.5 and ui.applied.actors[0].customization.acceleration == 1.0 and ui.applied.actors[0].usable_index == -1,"legacy migration preserves instance values with neutral extensions")
	check(ui.open_flyer_options(),"open cancelled edit")
	editor.hide()
	check(not ui.controls_blocked() and host.paused,"cancel restores original paused state")
	var hash_before: String = FileAccess.get_sha256(profile_path)
	var rejected: Dictionary = ui._profile("kestrel")
	rejected.options.budget = 80.0
	ui._requested_response = "RFT"
	check(not ui.apply_flyer_profile(rejected) and FileAccess.get_sha256(profile_path) == hash_before,"refused response/budget cannot overwrite saved profile")
	ui._requested_response = ui.applied.response
	if DisplayServer.get_name() != "headless" and not OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR").is_empty():
		check(ui.open_flyer_options(),"show controls for actual framebuffer")
		for tab: int in 3:
			editor._tabs.current_tab = tab
			await process_frame
			await RenderingServer.frame_post_draw
			var path: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR").path_join("flyer-options-%d.png" % tab)
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			check(root.get_texture().get_image().save_png(path) == OK,"save actual controls window framebuffer tab %d" % tab)
		editor.hide()
