extends SceneTree

const Shared = preload("res://scripts/shared_workbench.gd")
const Setup = Shared.Setup
const Actors = Setup.Actors
const Preferences = Shared.Preferences
var checks := 0
var failures: Array[String] = []

class Worker extends RefCounted:
	func has_failed() -> bool: return false

class Host extends Control:
	var simulation_worker := Worker.new()
	var physical_actor_session = null
	var pending_microscenario_apply := {}
	var observed := {"usable_index":-1,"pending":false,"state":"none","charge":50.0}
	var selection := {}
	var publish_count := 0
	var cancelled := 0
	func cancel_playable_course_input() -> void: cancelled += 1
	func workbench_select_usable(id: int, index: int, power: float) -> bool:
		selection = {"id":id,"index":index,"power":power}
		return true
	func workbench_equipment_observation(_id: int) -> Dictionary: return observed.duplicate(true)
	func workbench_material_player_state(id: int) -> Dictionary:
		return {"instance_id":id,"position":Vector2(1300,1400),"rotation":0.0,"model":"dryswarm"}
	func _publish_workbench_keyboard() -> void: publish_count += 1

func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] in ["--write-actors","--read-actors"]: child.call_deferred(args[0],args[1])
	else: run.call_deferred()

func models() -> Dictionary:
	var result := {}
	for id: String in Actors.pilot_ids(): result[id] = Actors.capabilities(id)
	return result

func child(mode: String, path: String) -> void:
	if not path.begins_with("user://test-workbench-actors-") or path.contains(".."): quit(1); return
	var prefs := Preferences.new()
	prefs.file_path = path; prefs.configure_models(models())
	if mode == "--write-actors":
		for id: String in Actors.pilot_ids():
			var value := prefs.profile(id)
			value.bindings.primary = [KEY_G]
			if Actors.kind(id) == "mechanical": value.options.mass_multiplier = 1.4
			check(prefs.commit_profile(id,value).is_empty(),"save "+id)
	else:
		var reason: String = prefs.load_profiles()
		check(reason.is_empty(),"reopen all actor profiles: "+reason)
		for id: String in Actors.pilot_ids():
			check(prefs.has_saved(id) and prefs.profile(id).bindings.primary == [KEY_G],"reopen "+id)
			if Actors.kind(id) == "mechanical": check(prefs.profile(id).options.mass_multiplier == 1.4,"body settings survive "+id)
	print("WORKBENCH_ACTOR_PROFILE_CHILD "+JSON.stringify({"mode":mode,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1920,1080)
	var host := Host.new()
	root.add_child(host)
	var ui := Shared.new()
	root.add_child(ui); ui.set_process(false); ui.host = host
	# This is a focused UI model control. Attach every constructed control so
	# teardown owns it even though the complete Main layout is not constructed.
	for property: Dictionary in ui.get_property_list():
		var value: Variant = ui.get(property.name)
		if value is Control and value != host and value.get_parent() == null: ui.add_child(value)
	for text: String in Shared.TOOL_NAMES: ui._tool.add_item(text)
	for i: int in range(33): ui._usable.add_item(str(i))
	ui.applied = Setup.fresh(PackedInt32Array([1]))
	ui.applied.actors = [Setup.instance("acrobat",1,Vector2(200,200))]
	ui.applied.next_id = 2; ui.applied.selected = 1
	ui._usable_power.min_value = 0.0; ui._usable_power.max_value = 1.0; ui._usable_power.step = 0.05
	ui._usable_power.value = 0.6; ui._usable.select(8)
	check(ui.request_usable(),"retarget uses host command admission")
	check(host.selection.id == 1 and host.selection.index == 7 and is_equal_approx(host.selection.power,0.6),"selected instance, usable and power submitted")
	check(ui.applied.actors[0].usable_index == -1,"submission cannot alter saved initial usable")
	ui._poll_usable()
	check(not ui._pending_usable.is_empty(),"old observation cannot acknowledge new choice")
	host.observed.usable_index = 7; host.observed.pending = true
	ui._poll_usable()
	check(ui.applied.actors[0].usable_index == -1,"inflight observation cannot acknowledge new choice")
	host.observed.pending = false; ui._poll_usable()
	check(ui._pending_usable.is_empty() and ui.applied.actors[0].usable_index == 7 and is_equal_approx(ui.applied.actors[0].usable_power,0.6),"acknowledged selection enters starting recipe")
	ui.applied.actors.append(Setup.instance("midge",2,Vector2(400,200)))
	ui.applied.next_id = 3
	ui._instances.add_item("Observer",0); ui._instances.add_item("Acrobat",1); ui._instances.add_item("Midge",2)
	for axis: int in 2:
		var field := SpinBox.new(); field.max_value = 2047; ui.add_child(field); ui._position.append(field)
	ui._fill_roster(); ui._configure_preferences()
	ui._usable.select(2); ui._usable_power.set_value_no_signal(0.35)
	check(ui.request_usable(),"second pending choice admitted")
	check(ui.select_instance(2,true) and ui.select_instance(1,true),"selection and retained install restore pending actor choice")
	check(ui.usable_selection().usable_index == 1 and is_equal_approx(ui.usable_selection().power,0.35),"pending index and power survive peer selection")
	host.observed.usable_index = 1; host.observed.power = 1.0
	ui._poll_usable()
	check(ui.applied.actors[0].usable_index == 1 and is_equal_approx(ui.applied.actors[0].usable_power,0.35),"ack cannot overwrite pending power with stale presentation fallback")
	var editor := Shared.OptionsPanel.new(); root.add_child(editor)
	var caps := Actors.capabilities("acrobat")
	editor.open_profile("Acrobat",Preferences.default_profile(caps),caps)
	editor.begin_capture("primary",0); editor.capture_key(KEY_M)
	check(editor._draft.bindings.primary == [KEY_SPACE],"equipment key refused at capture before profile submission")
	caps = Actors.capabilities("midge")
	editor.open_profile("Midge",Preferences.default_profile(caps),caps)
	editor.begin_capture("primary",0); editor.capture_key(KEY_M)
	check(editor._draft.bindings.primary == [KEY_M],"flyer retains equipment-free key flexibility")
	editor.hide(); editor.queue_free()
	ui._tool.select(5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	ui._world_input(click)
	check(ui.usable_tool_active() and ui.sample_usable_buttons().trigger and host.publish_count == 1,"use mode publishes short press without painting")
	click.pressed = false; ui._world_input(click)
	check(not ui.sample_usable_buttons().trigger and host.publish_count == 2,"short release is published")
	ui.applied.actors[0] = Setup.instance("dryswarm",1,Vector2(200,200))
	check(ui.body_state(1).position == Vector2(1300,1400),"native player state uses host field observation")
	click.button_index = MOUSE_BUTTON_RIGHT; click.pressed = true; ui._world_input(click)
	check(not ui.usable_tool_active() and host.publish_count == 2,"use mode on field does not fall through to erase")
	ui.cancel_stroke()
	check(not ui._usable_trigger and not ui._usable_alternate,"cancellation clears pointer intent")
	ui.queue_free(); host.queue_free(); await process_frame
	var path := "user://test-workbench-actors-%d.json" % OS.get_process_id()
	for mode: String in ["--write-actors","--read-actors"]:
		var output := []
		var exit_code := OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/test_workbench_actor_options.gd","--",mode,path]),output,true)
		var captured := "\n".join(output)
		check(exit_code == 0 and captured.contains("WORKBENCH_ACTOR_PROFILE_CHILD") and not captured.contains("ERROR:") and not captured.contains("WARNING:"),"fresh process "+mode)
		for line: String in captured.split("\n"):
			if line.begins_with("WORKBENCH_ACTOR_PROFILE_CHILD"): print(line)
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("WORKBENCH_ACTOR_OPTIONS "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
