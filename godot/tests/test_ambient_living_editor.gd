extends SceneTree

# Real main.tscn, native prepared owner, Rapier session and mounted Window.
# Authoring starts paused, then a short live audition checks Apply/Revert while
# both owners advance. Sustained gameplay has its own focused fixture.
# No World, body or owner acknowledgement is replaced here.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
var host: Control
var ui: Control
var editor: Window
var checks := 0
var failures: Array[String] = []
var save_name := "ambient-editor-002-test"
var started := 0
var layout: Dictionary = {}
var live_audition: Dictionary = {}


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
		push_error("AMBIENT_LIVING_EDITOR: " + label)
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
	data.actors = [Setup.instance("runner", 1, Vector2(170, 350)), Setup.instance("4ly_trainer", 2, Vector2(350, 210)), Setup.instance("runner", 3, Vector2(430, 350))]
	data.actors[0].control.usable_index = -1
	data.next_id = 4
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
	# Living settings remain staged; library copies and grouped assignment use
	# the same current owner identities, with complete preflight before mutation.
	ui.open_ambient_profile(1)
	var living := Profile.preset("restless_explorer")
	living.regions = []
	check(editor.replace_draft(living), "living preset stages in ordinary editor")
	var before_search := Catalog.control_for(ui.actor(ui.applied, 1))
	editor._filter_catalogue("wander")
	check(editor._module_type.item_count > 0 and editor._module_type.item_count < Profile.module_types().size(), "catalogue search narrows real module metadata")
	editor._filter_catalogue("")
	check(editor._module_type.item_count == Profile.module_types().size(), "clearing search restores complete catalogue")
	check(editor.add_region("home") and editor.add_region("interest") and editor.add_region("avoid"), "home, interest and avoidance rectangles authored through ordinary controls")
	check(not editor.add_region("home"), "second home has explicit refusal")
	check(Catalog.control_for(ui.actor(ui.applied, 1)) == before_search, "search and region editing never change admitted controller")
	await _living_tab_layout()
	check(editor.store_library_profile(), "scene library store receives actual owner acknowledgement")
	check(ui.ambient_library().profiles.size() == 1, "complete authored living profile stored")
	check(Catalog.control_for(ui.actor(ui.applied, 1)) == before_search, "library store never applies silently")
	check(editor.apply_draft(), "per-actor v2 configuration acknowledged")
	editor.refresh_group()
	_select_group([1, 3])
	check(editor.apply_group_draft(), "two compatible physical actors receive explicit grouped profile copies")
	var first := Catalog.control_for(ui.actor(ui.applied, 1))
	var third := Catalog.control_for(ui.actor(ui.applied, 3))
	check(first.ambient == third.ambient, "group shares authored values after acknowledgement")
	var changed := third.duplicate(true)
	changed.ambient.name = "Individual third inhabitant"
	check(ui.set_actor_control(3, changed), "individual override uses ordinary control admission")
	check(Catalog.control_for(ui.actor(ui.applied, 1)).ambient == first.ambient and ui.ambient_library().profiles[0].name != changed.ambient.name, "individual override does not mutate sibling or shared library")
	_select_group([1, 3])
	var first_before_stale := Catalog.control_for(ui.actor(ui.applied, 1))
	check(not editor.apply_group_draft(), "one externally changed member refuses stale whole group")
	check(Catalog.control_for(ui.actor(ui.applied, 1)) == first_before_stale and Catalog.control_for(ui.actor(ui.applied, 3)) == changed, "stale group refusal has no partial controller changes")
	editor.refresh_group()
	check(editor.replace_draft(Profile.preset("oil_moth")), "ground-only predecessor profile stages")
	_select_group([1, 2])
	var group_before := [Catalog.control_for(ui.actor(ui.applied, 1)), Catalog.control_for(ui.actor(ui.applied, 2))]
	check(not editor.apply_group_draft(), "incompatible flyer refuses whole ground-profile group")
	check([Catalog.control_for(ui.actor(ui.applied, 1)), Catalog.control_for(ui.actor(ui.applied, 2))] == group_before, "incompatible group refusal preserves every admitted controller")
	editor.revert_draft()
	check(editor.load_library_profile(0), "shared profile stages without code")
	var library_before: Dictionary = ui.ambient_library()
	var invalid_library: Dictionary = library_before.duplicate(true)
	invalid_library.profiles[0].memory.capacity = -1
	check(not ui.set_ambient_library(invalid_library, library_before, editor._bound_run, editor._bound_epoch), "invalid library rejected through actual host seam")
	check(ui.ambient_library() == library_before, "invalid library retains exact admitted library")
	await _live_audition()
	# The normal Save route persists authored data, with no module runtime state.
	var label := OS.get_environment("CYBERSAND_AMBIENT_LIVING_EDITOR_SAVE")
	if not label.is_empty(): save_name = label
	check(not FileAccess.file_exists(Setup._path(save_name)), "editor save fixture will not replace user data")
	if not FileAccess.file_exists(Setup._path(save_name)):
		ui._name.text = save_name
		check(ui.save_setup(), "normal Workbench Save stores profiles and assignment")
		var reopened := Setup.read_named(save_name)
		check(reopened.has("setup"), "normal codec reopens saved edited scene")
		if reopened.has("setup"):
			check(reopened.setup.actors == ui.applied.actors, "reopened exact actor profiles, module order and seeds")
			check(reopened.setup.ambient_authoring == ui.ambient_library(), "reopened exact scene library, places and relationships")
		DirAccess.remove_absolute(Setup._path(save_name))
	await finish()


func finish() -> void:
	var report := {"checks":checks, "failures":failures, "platform":OS.get_name(), "display":DisplayServer.get_name(),
		"godot":Engine.get_version_info().string, "elapsed_seconds":float(Time.get_ticks_msec()-started)/1000.0,
		"layout":layout, "live_audition":live_audition,
		"scope":"actual mounted editor + ordinary native/Rapier owner; staged and live Apply/Revert, not sustained behavioural or physical display acceptance"}
	var path := OS.get_environment("CYBERSAND_AMBIENT_LIVING_EDITOR_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	print("AMBIENT_LIVING_EDITOR ", JSON.stringify(report))
	if host != null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)


func _live_audition() -> void:
	ui.open_ambient_profile(1)
	var admitted := Catalog.control_for(ui.actor(ui.applied, 1))
	var draft: Dictionary = editor.staged_profile()
	draft.seed = int(draft.seed) + 31
	draft.personality.curiosity = 0.17
	draft.memory.enabled = false
	check(editor.replace_draft(draft), "live audition stages a complete edited profile")
	var paused_generation: int = host.physical_actor_session.workbench_control(1).generation
	var old_run: String = host.physical_actor_session.run_id
	var old_epoch: int = host.physical_actor_session.epoch
	var old_world: int = host.latest_snapshot.render_world_generation
	var initial_tick: int = host.physical_actor_session.tick
	var initial_native: int = host.latest_snapshot.tick_index
	if not check(ui.toggle_pause() and not host.paused, "ordinary Play begins live configuration audition"): return
	# Resume deliberately revokes paused command leases. Establish the live
	# baseline after that lifecycle fence, before any physics advances; a draft
	# must not alter the admitted configuration on either side of the fence.
	var playing_generation: int = host.physical_actor_session.workbench_control(1).generation
	live_audition = {"paused_generation":paused_generation, "playing_generation":playing_generation,
		"resume_configuration_unchanged":Catalog.control_for(ui.actor(ui.applied, 1)) == admitted}
	check(playing_generation > paused_generation and bool(live_audition.resume_configuration_unchanged),
		"ordinary resume fences paused leases without applying the staged configuration")
	var moving := await until(func() -> bool:
		return int(host.physical_actor_session.tick) >= initial_tick + 12 and int(host.latest_snapshot.tick_index) >= initial_native + 11,
		"actual native and physical owners progress with an unapplied draft")
	if moving:
		live_audition["unapplied_generation"] = host.physical_actor_session.workbench_control(1).generation
		live_audition["unapplied_configuration_unchanged"] = Catalog.control_for(ui.actor(ui.applied, 1)) == admitted
		check(bool(live_audition.unapplied_configuration_unchanged) and int(live_audition.unapplied_generation) == playing_generation,
			"unapplied live draft cannot change admitted control or authority")
		check(editor.apply_draft() and not host.paused, "Apply receives acknowledgement without stopping Play")
		var current := Catalog.control_for(ui.actor(ui.applied, 1))
		check(current.ambient == editor.staged_profile() and current.ambient.seed == draft.seed and not current.ambient.memory.enabled,
			"live acknowledgement admits the exact edited personality, seed and memory configuration")
		var new_generation: int = host.physical_actor_session.workbench_control(1).generation
		live_audition["applied_generation"] = new_generation
		check(new_generation > playing_generation and host.physical_actor_session.run_id == old_run and host.physical_actor_session.epoch == old_epoch
			and host.latest_snapshot.render_world_generation == old_world, "live Apply retires controller authority while retaining both owner identities")
		var applied_tick: int = host.physical_actor_session.tick
		var applied_native: int = host.latest_snapshot.tick_index
		if await until(func() -> bool:
			return int(host.physical_actor_session.tick) >= applied_tick + 18 and int(host.latest_snapshot.tick_index) >= applied_native + 17,
			"native and physical owners continue after live Apply"):
			var diagnostics: Dictionary = host.physical_actor_session.workbench_control(1).diagnostics.get("ambient", {})
			check(int(diagnostics.get("decisions", 0)) > 0 and diagnostics.get("memory", {}).get("enabled", true) == false,
				"new live controller makes actual decisions with disabled memory")
		var discarded: Dictionary = editor.staged_profile()
		discarded.name = "Discarded live draft"
		check(editor.replace_draft(discarded), "another live draft can be staged")
		editor.revert_draft()
		check(editor.staged_profile() == current.ambient and host.physical_actor_session.workbench_control(1).generation == new_generation,
			"live Revert discards only the draft and preserves admitted controller authority")
	if not host.paused: check(ui.toggle_pause() and host.paused, "ordinary Pause ends bounded live audition")


func _living_tab_layout() -> void:
	var tabs: TabContainer = editor._living_body.get_parent().get_parent()
	var measured: Array = []
	for target_size: Vector2i in [Vector2i(1020, 760), Vector2i(740, 480)]:
		editor.size = target_size
		for index: int in tabs.get_tab_count():
			tabs.current_tab = index
			editor._content_scroll.scroll_vertical = 0
			await process_frame
			await process_frame
			var bounds := Rect2(Vector2.ZERO, Vector2(editor.size))
			check(tabs.get_global_rect().end.x <= bounds.end.x,
				"living tab has no unreachable horizontal overflow: %s at %s" % [tabs.get_tab_title(index), target_size])
			if target_size.y == 480:
				editor._content_scroll.scroll_vertical = 1000000
				await process_frame
			check(bounds.encloses(editor._apply_button.get_global_rect()) and bounds.encloses(editor._inspector.get_global_rect()),
				"Apply and inspector remain reachable on living tab: %s at %s" % [tabs.get_tab_title(index), target_size])
			measured.append({"tab":tabs.get_tab_title(index), "size":editor.size,
				"tab_rect":tabs.get_global_rect(), "apply_rect":editor._apply_button.get_global_rect(), "inspector_rect":editor._inspector.get_global_rect()})
	layout["living_tabs"] = measured
	tabs.current_tab = 0
	editor.size = Vector2i(1020, 760)
	editor._content_scroll.scroll_vertical = 0
	await process_frame


func _select_group(ids: Array) -> void:
	editor._group_list.deselect_all()
	for index: int in editor._group_list.item_count:
		if int(editor._group_list.get_item_metadata(index)) in ids:
			editor._group_list.select(index, false)
