extends SceneTree

# Enter via the launcher, operate both OptionButtons and the Reset button
# through their viewports, and check the actual shared owner after each ack.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
var main: Control
var ui: Control
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, reason: String) -> bool:
	assertions += 1
	if not ok:
		failures.append(reason)
		push_error("WORKBENCH_PILOT_UI " + reason)
	return ok

func until(predicate: Callable, reason: String) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("diagnostic_capture_seconds")
	print("Waiting for ",reason)
	while Time.get_ticks_msec()<deadline and not predicate.call():
		await process_frame
	return check(predicate.call(),reason+" ("+ui.message+" / "+main.microscenario_error+")")

func mouse_click(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		button.get_viewport().push_input(event,true)
		await process_frame

func button_named(label: String) -> Button:
	for candidate: Node in ui.find_children("*","Button",true,false):
		if candidate.text == label: return candidate
	return null

func pick(picker: OptionButton, index: int) -> void:
	await mouse_click(picker)
	var popup := picker.get_popup()
	if not check(popup.visible,"toolbar opened "+picker.tooltip_text): return
	# Headless windows have no OS menu picker. Use PopupMenu's normal
	# accelerator entry to activate this item and dispatch its real selection.
	popup.set_item_accelerator(index,KEY_F19)
	var key := InputEventKey.new()
	key.keycode = KEY_F19
	key.pressed = true
	check(popup.activate_item_by_event(key),"native popup activated "+popup.get_item_text(index))
	popup.set_item_accelerator(index,KEY_NONE)
	popup.hide()
	await process_frame

func reset_key() -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_R
		event.pressed=down
		root.push_input(event,true)
		await process_frame

func changed(epoch: int) -> bool:
	return main._physical_epoch>epoch and main.pending_microscenario_apply.is_empty() and not ui.busy()

func check_tuning(id: int, expected: Dictionary, context: String) -> void:
	var a: Dictionary = ui.actor(ui.applied,id)
	for key: String in expected:
		check(is_equal_approx(float(a.options[key]),float(expected[key])),context+" saved "+key)
		check(is_equal_approx(ui._fields[key].value,float(expected[key])),context+" displayed "+key)
	var state: Dictionary = ui.body_state(id)
	var definition: Dictionary = Fleet.definition(Fleet.index_for_id(str(state.model)))
	var part: Dictionary = definition.parts[0]
	var authored_inertia: float = float(part.inertia) if part.has("inertia") else float(part.mass)*Vector2(part.size).length_squared()/12.0
	check(is_equal_approx(state.mass,float(part.mass)*expected.mass_multiplier),context+" actual mass")
	check(is_equal_approx(state.inertia,authored_inertia*expected.mass_multiplier*expected.inertia_multiplier),context+" actual inertia")
	check(is_equal_approx(state.budget,float(expected.budget)),context+" actual response budget")
	check(is_equal_approx(state.force_limit,float(definition.profile.fleet_force)*expected.thrust_multiplier),context+" actual thrust limit")
	check(is_equal_approx(state.torque_limit,float(definition.profile.fleet_torque)*expected.torque_multiplier),context+" actual torque limit")
	var slot: int = main.physical_actor_session.slot_for_instance(id)
	check(is_equal_approx(main.physical_actor_session._rigs[slot]._profile.fleet_boost_multiplier,float(expected.boost_multiplier)),context+" configured boost")

func test_roster() -> void:
	var epoch: int = main._physical_epoch
	check(ui.applied.actors.is_empty() and ui.pilot_slot == -1,"empty canvas")
	await pick(ui._roster,Fleet.index_for_id("scooper")+1)
	if not await until(func()->bool: return changed(epoch),"roster places first flyer"): return
	var scoop_id: int = ui.selected_id()
	check(main.paused and ui.body_state(scoop_id).model=="scooper" and ui.pilot_slot==0 and "Placed" in ui.message,"acknowledged Scooper")
	var saved := Vector2(200,200)
	var wall := Vector2i(1120,1100)
	check(ui.paint(wall,58),"paint remote terrain")
	if not await until(func()->bool: return main.image.get_pixelv(wall).r8==58,"real painted pixel"): return
	# Switching the missing model must retain the selected flyer's applied
	# comparison settings, while independently placed bodies start at defaults.
	var tuned := {"budget":40.0,"mass_multiplier":1.5,"inertia_multiplier":1.75,
		"thrust_multiplier":1.6,"torque_multiplier":1.3,"boost_multiplier":2.75}
	for key: String in tuned: ui._fields[key].value=tuned[key]
	epoch=main._physical_epoch
	await mouse_click(button_named("Apply settings"))
	if not await until(func()->bool: return changed(epoch),"nondefault flyer tuning accepted"): return
	check_tuning(scoop_id,tuned,"tuned Scooper")
	var accepted_epoch: int = main._physical_epoch
	ui._requested_response="RFT"
	check(not ui.apply_settings() and main._physical_epoch==accepted_epoch and ui.applied.response=="LA-SELECTIVE",
		"RFT fixed-budget admission still refuses a tuned 40 budget without replacing the owner")
	ui._requested_response="LA-SELECTIVE"

	# The placement model has no side effects on a pilot. Place a second,
	# independently selectable flyer far outside the initial view.
	await pick(ui._model,Fleet.index_for_id("needle"))
	check(ui.selected_id()==scoop_id and ui.body_state(scoop_id).model=="scooper","placement picker is independent")
	ui._position[0].value=1450
	ui._position[1].value=1400
	epoch=main._physical_epoch
	await mouse_click(button_named("Place at X/Y"))
	if not await until(func()->bool: return changed(epoch),"second flyer placement"): return
	var needle_id: int = ui.selected_id()
	check(ui.body_state(needle_id).model=="needle" and Rect2(main.camera_origin,main.current_view_size).has_point(Vector2(1450,1400)),"distant placement revealed")
	check_tuning(needle_id,ui.Setup.DEFAULT_OPTIONS,"independent new Needle")
	epoch=main._physical_epoch
	await pick(ui._roster,Fleet.index_for_id("scooper")+1)
	check(main._physical_epoch==epoch and ui.selected_id()==scoop_id and ui.pilot_slot==0,"existing flyer handover uses same physical session")
	check_tuning(scoop_id,tuned,"reselected existing Scooper")
	check(Rect2(main.camera_origin,main.current_view_size).has_point(saved),"selected pilot visible after handover")
	await mouse_click(button_named("Reset selected [R]"))
	if not await until(func()->bool: return changed(epoch),"stationary reset accepted"): return
	check(main.paused and ui.body_state(scoop_id).position.is_equal_approx(saved) and "Reset Scooper" in ui.message,"stationary reset confirmed")

	await mouse_click(button_named("Play / Pause [P]"))
	if not await until(func()->bool: return not main.paused and main.physical_actor_session.tick>=4,"playing owner advanced"): return
	# The reference Scooper stabilizes in place. Capture a deliberately
	# different reset spawn and prove the live body stays where it was.
	saved = Vector2(260,180)
	ui._position[0].value=saved.x
	ui._position[1].value=saved.y
	await mouse_click(button_named("Save reset spawn"))
	if not check(ui.body_state(scoop_id).position.distance_to(saved)>20 and ui.actor(ui.applied,scoop_id).spawn==[saved.x,saved.y],"saved spawn edit during play does not teleport"): return
	epoch=main._physical_epoch
	await reset_key()
	if not await until(func()->bool: return changed(epoch),"R resets during play"): return
	check(not main.paused and ui.selected_id()==scoop_id and ui.body_state(scoop_id).position.distance_to(saved)<1 and "Reset Scooper" in ui.message,"reset returned to saved spawn and resumed play")
	epoch=main._physical_epoch
	await pick(ui._roster,Fleet.index_for_id("kestrel")+1)
	if not await until(func()->bool: return changed(epoch),"switch absent model while flying"): return
	var kestrel_id: int = ui.selected_id()
	check(not main.paused and kestrel_id!=scoop_id and ui.body_state(kestrel_id).model=="kestrel" and ui.body_state(scoop_id).is_empty(),"replaced actual old pilot")
	check(ui.body_state(needle_id).model=="needle" and ui.applied.actors.size()==2 and main.image.get_pixelv(wall).r8==58,"other flyer and terrain retained")
	check(main.tower_context.workbench_gcr.response=="LA-SELECTIVE","response retained on reset and replacement")
	check_tuning(kestrel_id,tuned,"missing-model Kestrel replacement")
	var replacement_epoch: int = main._physical_epoch
	await pick(ui._roster,Fleet.index_for_id("needle")+1)
	check(ui.selected_id()==needle_id and main._physical_epoch==replacement_epoch,"existing Needle selection does not reconstruct or inherit another pilot's tuning")
	check_tuning(needle_id,ui.Setup.DEFAULT_OPTIONS,"reselected existing Needle")
	await pick(ui._roster,Fleet.index_for_id("kestrel")+1)
	check(ui.selected_id()==kestrel_id and main._physical_epoch==replacement_epoch,"existing tuned Kestrel selection retains its instance")
	check_tuning(kestrel_id,tuned,"reselected tuned Kestrel")
	var capture := OS.get_environment("CYBERSAND_WORKBENCH_PILOT_CAPTURE")
	if not capture.is_empty() and DisplayServer.get_name()!="headless":
		await until(func()->bool: return "Switched to Kestrel" in ui._status.text,"visible acknowledged pilot label")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture)==OK,"graphical roster and acknowledgement")
	epoch=main._physical_epoch
	ui._position[0].value=480
	ui._position[1].value=160
	await mouse_click(button_named("Move to X/Y"))
	if not await until(func()->bool: return changed(epoch),"move accepted during play"): return
	check(not main.paused and ui.body_state(kestrel_id).position.distance_to(Vector2(480,160))<2,"moved body and resumed")
	var base_mass: float = float(Fleet.authoring_record(Fleet.index_for_id("kestrel")).physics.mass)
	ui._fields.mass_multiplier.value=2.0
	epoch=main._physical_epoch
	await mouse_click(button_named("Apply settings"))
	if not await until(func()->bool: return changed(epoch),"edited handling accepted during play"): return
	check(not main.paused and is_equal_approx(ui.body_state(kestrel_id).mass,base_mass*2.0),"live settings reached Rapier")
	epoch=main._physical_epoch
	await mouse_click(button_named("Defaults"))
	if not await until(func()->bool: return changed(epoch),"Defaults accepted during play"): return
	check(not main.paused and is_equal_approx(ui.body_state(kestrel_id).mass,base_mass),"Defaults reached Rapier")
	check_tuning(kestrel_id,ui.Setup.DEFAULT_OPTIONS,"explicit Defaults")
	# This test owns a unique user:// name and removes only that file.
	var label := "pilot-ui-%d-%d" % [OS.get_process_id(),Time.get_ticks_msec()]
	ui._name.text=label
	check(ui.save_setup() and not main.paused,"save authored start while playing")
	epoch=main._physical_epoch
	await mouse_click(button_named("Remove"))
	if not await until(func()->bool: return changed(epoch),"remove accepted during play"): return
	check(not main.paused and ui.body_state(kestrel_id).is_empty() and ui.body_state(needle_id).model=="needle","removed only selected instance")
	epoch=main._physical_epoch
	check(ui.load_setup(),"load named start from play")
	if not await until(func()->bool: return changed(epoch),"named start loaded"): return
	check(main.paused and ui.body_state(kestrel_id).model=="kestrel" and main.image.get_pixelv(wall).r8==58,"loaded authored contents paused")
	var path: String = ui.Setup._path(label)
	check(DirAccess.remove_absolute(path)==OK,"removed unique test setup")
	await mouse_click(button_named("Play / Pause [P]"))
	check(ui.new_canvas(),"new canvas accepted during play")
	if not await until(func()->bool: return ui.applied.actors.is_empty() and main.pending_microscenario_apply.is_empty(),"new blank acknowledged"): return
	check(main.paused and ui.pilot_slot==-1,"new canvas paused and neutral")

func run() -> void:
	root.size=Vector2i(1920,1080)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main=current_scene
	ui=main.shared_workbench
	if await until(func()->bool: return not ui.applied.is_empty() and not ui.busy(),"blank workbench installed"):
		await test_roster()
	main.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH_PILOT_UI ",JSON.stringify({"assertions":assertions,"failures":failures}))
	quit(int(not failures.is_empty()))
