extends SceneTree

# Real main.tscn, native prepared owner, Rapier session and mounted Window.
# All cases start paused; gameplay motion and timed behaviour have their own
# focused fixture. No World, body or owner acknowledgement is replaced here.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
var host: Control
var ui: Control
var editor: Window
var checks := 0
var failures: Array[String] = []
var save_name := "ambient-editor-001-test"
var started := 0
var layout: Dictionary = {}


func _initialize() -> void:
	started = Time.get_ticks_msec()
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	# Use the accepted authored recovery route so this bounded UI fixture does
	# not first allocate the unrelated default 2048-cell canvas.
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	set_meta("cybersand_playable_recovery", {"workbench":Setup.fresh(bridge.call(&"default_liquid_policy"), Vector2i(512, 512))})
	run.call_deferred()


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_EDITOR: " + label)
	return value


func until(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		await process_frame
	return check(false, label + " / " + str(ui.message if ui != null else "opening") + " / " + str(host.microscenario_error if host != null else "no host"))


func installed() -> bool:
	return ui != null and not ui.applied.is_empty() and not ui.busy() and host.pending_microscenario_apply.is_empty()


func _fixture() -> Dictionary:
	var data := Setup.fresh(PackedInt32Array(ui.applied.liquid_policy), Vector2i(512, 512))
	data.edits = [[0,376,512,12,58], [205,368,25,8,16]]
	data.actors = [Setup.instance("runner", 1, Vector2(170, 350)), Setup.instance("4ly_trainer", 2, Vector2(350, 210))]
	data.actors[0].control.usable_index = -1
	data.next_id = 3
	data.selected = 1
	return data


func _parameter(node: Node, key: String) -> SpinBox:
	if node is SpinBox and str(node.get_meta("ambient_parameter", "")) == key: return node
	for child: Node in node.get_children():
		var found := _parameter(child, key)
		if found != null: return found
	return null


func run() -> void:
	root.size = Vector2i(1280, 900)
	set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench != null, "ordinary Workbench opens"):
		await finish(); return
	ui = host.shared_workbench
	if not await until(installed, "ordinary native owner ready"):
		await finish(); return
	if not check(ui.apply(_fixture()), "prepare ordinary bounded native actor fixture"):
		await finish(); return
	if not await until(installed, "authored fixture acknowledged by native and physical owners"):
		await finish(); return
	check(host.paused, "editor qualification starts physically paused")
	check(ui._ambient_profile_editor == null, "ambient authoring remains lazy outside explicit action")
	var baseline := Catalog.control_for(ui.actor(ui.applied, 1))
	var initial_generation: int = host.physical_actor_session.workbench_control(1).generation
	ui.open_ambient_profile(1)
	editor = ui._ambient_profile_editor
	check(editor != null and editor.visible, "ordinary UI opens mounted profile window")
	# A headless display has no screen geometry for popup_centered(). Exercise
	# the actual advertised default and minimum sizes explicitly.
	editor.size = Vector2i(1020, 760)
	await process_frame
	await process_frame
	var editor_bounds := Rect2(Vector2.ZERO, Vector2(editor.size))
	layout = {"window_size":editor.size, "content_minimum":editor.get_child(0).get_combined_minimum_size(),
		"apply_rect":editor._apply_button.get_global_rect(), "inspector_rect":editor._inspector.get_global_rect(),
		"module_list_rect":editor._module_list.get_global_rect()}
	check(editor_bounds.encloses(editor._apply_button.get_global_rect()), "Apply remains inside the actual window layout")
	check(editor_bounds.encloses(editor._inspector.get_global_rect()), "live inspector remains inside the actual window layout")
	check(editor._module_list.size.y >= 150.0, "module list has useful visible height")
	check(_parameter(editor._parameter_body, "effort") != null and _parameter(editor._parameter_body, "effort").editable,
		"ground effort channel remains an editable actual control")
	editor.size = Vector2i(740, 480)
	await process_frame
	await process_frame
	editor._content_scroll.scroll_vertical = 1000000
	await process_frame
	var small_bounds := Rect2(Vector2.ZERO, Vector2(editor.size))
	layout.minimum_window_size = editor.size
	layout.minimum_apply_rect = editor._apply_button.get_global_rect()
	layout.minimum_inspector_rect = editor._inspector.get_global_rect()
	check(small_bounds.encloses(editor._apply_button.get_global_rect()) and small_bounds.encloses(editor._inspector.get_global_rect()),
		"minimum-size editor scroll keeps Apply and live inspector reachable")
	editor.size = Vector2i(1020, 760)
	editor._content_scroll.scroll_vertical = 0
	await process_frame
	check(editor.staged_profile().id == "oil_moth", "ground actor receives compatible staged default")
	check(Catalog.control_for(ui.actor(ui.applied, 1)) == baseline, "opening editor leaves admitted authored controller unchanged")
	check(host.physical_actor_session.workbench_control(1).generation == initial_generation, "opening editor does not reset nonhuman controller generation")
	var staged: Dictionary = editor.staged_profile()
	staged.name = "Patient workshop resident"
	staged.seed = 8081
	check(editor.replace_draft(staged), "stage named independent profile")
	check(editor.add_module("rest"), "add an actual reusable rest module")
	var final_module_id := str(editor.staged_profile().modules.back().id)
	editor.move_module(-1)
	check(str(editor.staged_profile().modules[-2].id) == final_module_id, "reorder module without mutating admitted config")
	check(Catalog.control_for(ui.actor(ui.applied, 1)) == baseline, "all staged module and seed edits leave live authoring intact")
	var draft_before: Dictionary = editor.staged_profile()
	var invalid: Dictionary = draft_before.duplicate(true)
	invalid.modules[0].params.pace = NAN
	check(not editor.replace_draft(invalid) and editor.staged_profile() == draft_before, "invalid staged replacement retains complete last valid draft")
	check(editor.apply_draft(), "Apply receives actual live session acknowledgement")
	var admitted := Catalog.control_for(ui.actor(ui.applied, 1))
	check(admitted.source == "policy" and admitted.policy == "ambient" and admitted.ambient.name == staged.name, "actual authored actor uses admitted ambient profile")
	check(admitted.ambient.seed == 8081 and not admitted.ambient.shared_seed, "independent authored seed assigned to this actor")
	check(host.physical_actor_session.workbench_control(1).generation > initial_generation, "acknowledged Apply retires old command authority")
	var admitted_generation: int = host.physical_actor_session.workbench_control(1).generation
	var admitted_runtime: Dictionary = host.physical_actor_session.workbench_control(1).diagnostics
	for index: int in 8: editor.refresh_inspection()
	check(host.physical_actor_session.workbench_control(1).generation == admitted_generation \
		and host.physical_actor_session.workbench_control(1).diagnostics == admitted_runtime, "repeated visible inspection is nonmutating")
	check(ui.select_instance(2) and editor._instance_id == 1, "inspecting a different actor does not retarget staged editor")
	check(editor.staged_profile() == admitted.ambient, "selection changes leave staged profile intact")
	# An independent authored change must not be overwritten by an older draft.
	var external := admitted.duplicate(true)
	external.ambient.name = "Newer external edit"
	check(ui.set_actor_control(1, external), "independent valid control update accepted")
	check(not editor.apply_draft(), "stale profile editor refuses lost-update overwrite")
	check(Catalog.control_for(ui.actor(ui.applied, 1)).ambient.name == "Newer external edit", "stale refusal retains newer admitted profile")
	editor.revert_draft()
	check(editor.staged_profile().name == "Newer external edit", "Revert loads current admitted profile")
	# Pilot handoff changes authority without losing the authored procedural block.
	check(ui.pilot_instance(1), "human pilot takeover uses existing owner")
	check(Catalog.control_for(ui.actor(ui.applied, 1)).ambient == external.ambient, "pilot handoff retains exact authored profile")
	check(ui.hand_back_pilot(), "hand back returns through existing producer owner")
	check(Catalog.control_for(ui.actor(ui.applied, 1)).policy == "ambient", "hand back restores procedural policy adapter")
	# Flying actors get a flight profile; an enabled ground reflex is refused.
	ui.open_ambient_profile(2)
	check(editor.staged_profile().id == "drifting_flyer", "4LY default does not inherit invalid ground ledge rule")
	var flight_effort := _parameter(editor._parameter_body, "effort")
	check(flight_effort != null and not flight_effort.editable and flight_effort.tooltip_text.contains("Pace only"),
		"4LY effort field is disabled with an explicit pace-only explanation")
	check(editor.add_module("avoid_ledge"), "incompatible module can be staged for visible diagnosis")
	check(editor._profile_status.text.contains("ground"), "editor identifies missing ground capability before Apply")
	var flyer_before := Catalog.control_for(ui.actor(ui.applied, 2))
	check(not editor.apply_draft() and Catalog.control_for(ui.actor(ui.applied, 2)) == flyer_before, "unsupported profile Apply preserves valid flyer control")
	editor.remove_module()
	check(editor.apply_draft(), "compatible 4LY profile is actually admitted")
	# Same IDs, same models, same profile bytes: a replacement still gets a new
	# session identity. An old editing window cannot unknowingly target it.
	ui.open_ambient_profile(1)
	var old_run: String = editor._bound_run
	var replacement: Dictionary = ui.applied.duplicate(true)
	check(ui.apply(replacement), "prepare replacement with identical authored actor identities")
	if await until(installed, "replacement native and physical owners acknowledged"):
		check(str(host.physical_actor_session.run_id) != old_run, "replacement has a distinct physical run identity")
		check(not editor.apply_draft(), "stale editor refuses same-ID same-profile world replacement")
		editor.revert_draft()
		check(editor.apply_draft(), "explicit Revert rebinds and allows a new acknowledged Apply")
	# The normal Save route persists authored data, with no module runtime state.
	var label := OS.get_environment("CYBERSAND_AMBIENT_EDITOR_SAVE")
	if not label.is_empty(): save_name = label
	check(not FileAccess.file_exists(Setup._path(save_name)), "editor save fixture will not replace user data")
	if not FileAccess.file_exists(Setup._path(save_name)):
		ui._name.text = save_name
		check(ui.save_setup(), "normal Workbench Save stores profiles and assignment")
		var reopened := Setup.read_named(save_name)
		check(reopened.has("setup"), "normal codec reopens saved edited scene")
		if reopened.has("setup"):
			check(reopened.setup.actors == ui.applied.actors, "reopened exact actor profiles, module order and seeds")
		DirAccess.remove_absolute(Setup._path(save_name))
	await finish()


func finish() -> void:
	var report := {"checks":checks, "failures":failures, "platform":OS.get_name(), "display":DisplayServer.get_name(),
		"godot":Engine.get_version_info().string, "elapsed_seconds":float(Time.get_ticks_msec()-started)/1000.0,
		"layout":layout,
		"scope":"actual mounted editor + ordinary native/Rapier owner; paused authoring, not motion or physical display acceptance"}
	var path := OS.get_environment("CYBERSAND_AMBIENT_EDITOR_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	print("AMBIENT_EDITOR ", JSON.stringify(report))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
