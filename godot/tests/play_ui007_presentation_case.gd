extends "res://tests/play_life001_shared_host_case.gd"

# UI007: actual shared Main/native/Rapier owner plus copied presentation.
# The serial arithmetic and completed-marker controls are explicitly models;
# they do not claim natural gate traversal or graphical/physical-device proof.
const Counter = preload("res://scripts/snapshot_publication_counter.gd")
var desktop: Control
var fixture_started_usec: int = 0
var row: Dictionary = {}


class PresentationMain:
	extends "res://scripts/main.gd"
	var suppress_consumption: bool = false
	var main_callbacks: int = 0
	var presentation_frame: Dictionary = {}

	func _actor_window_has_focus() -> bool:
		return true

	func _process(delta: float) -> void:
		main_callbacks += 1
		super._process(delta)
		# Capture only after the ordinary Main callback has presented every
		# layer. A process_frame waiter can otherwise observe deferred Container
		# layout after this callback, before Main publishes that new layout.
		presentation_frame = {
			"callback":main_callbacks, "process_frame":Engine.get_process_frames(),
			"requested_origin":camera_origin, "presented_origin":presentation_camera_origin(),
			"view_size":Vector2(current_view_size), "content":view_content_rect(),
			"screen":world_view.get_viewport().get_final_transform() * world_view.get_global_transform_with_canvas(),
			"target_origin":playable_course_overlay._origin, "target_view":playable_course_overlay._view_size,
			"target_content":Rect2(playable_course_overlay.position,playable_course_overlay.size),
			"actor_origin":physical_actor_overlay._origin, "actor_view":physical_actor_overlay._view_size,
			"actor_content":Rect2(physical_actor_overlay.position,physical_actor_overlay.size),
			"terrain_origin":world_shader.get_shader_parameter("camera_origin_px"),
			"native_serial":latest_snapshot.serial if latest_snapshot != null else 0,
			"world_generation":latest_snapshot.render_world_generation if latest_snapshot != null else -1,
			"actor_epoch":_physical_epoch}

	func consume_worker_snapshot() -> void:
		if not suppress_consumption:
			super.consume_worker_snapshot()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAY_UI007: " + message)


func bounded(predicate: Callable, message: String) -> bool:
	var start: int = Time.get_ticks_usec()
	var deadline: int = mini(start + WAIT_TIMEOUT_MS * 1000, fixture_started_usec + Watchdogs.microseconds("complex_fixture_seconds"))
	var ok: bool = false
	while Time.get_ticks_usec() < deadline:
		if predicate.call():
			ok = Time.get_ticks_usec() <= deadline
			break
		await process_frame
	row.waits.append({"name":message, "started_usec":start, "deadline_usec":deadline,
		"ended_usec":Time.get_ticks_usec(), "passed":ok})
	expect(ok, message)
	return ok


func targets_ready() -> bool:
	return desktop.playable_course_overlay.visible and not desktop.playable_course_overlay.course_identity.is_empty()


func current_presentation_layout(after_callback: int) -> bool:
	var frame: Dictionary = desktop.presentation_frame
	return not frame.is_empty() and int(frame.callback) > after_callback \
		and frame.screen == desktop.world_view.get_viewport().get_final_transform() * desktop.world_view.get_global_transform_with_canvas() \
		and frame.content == desktop.view_content_rect() and frame.view_size == Vector2(desktop.current_view_size)


func presentation_layers_agree(frame: Dictionary) -> bool:
	return frame.target_origin == frame.presented_origin and frame.actor_origin == frame.presented_origin \
		and frame.terrain_origin == frame.presented_origin \
		and frame.target_view == frame.view_size and frame.actor_view == frame.view_size \
		and frame.target_content == frame.content and frame.actor_content == frame.content


func vector_receipt(value: Vector2) -> Array[float]:
	return [value.x,value.y]


func screen_receipt(value: Transform2D) -> Dictionary:
	return {"x":vector_receipt(value.x),"y":vector_receipt(value.y),"origin":vector_receipt(value.origin)}


func presentation_receipt(after_callback: int) -> Dictionary:
	var frame: Dictionary = desktop.presentation_frame
	return {"after_callback_exclusive":after_callback,"published_callback":frame.callback,
		"observed_callback":desktop.main_callbacks,"published_process_frame":frame.process_frame,
		"requested_origin":vector_receipt(frame.requested_origin),"presented_origin":vector_receipt(frame.presented_origin),
		"target_origin":vector_receipt(frame.target_origin),"actor_origin":vector_receipt(frame.actor_origin),
		"terrain_origin":vector_receipt(frame.terrain_origin),"view_size":vector_receipt(frame.view_size),
		"content_position":vector_receipt(frame.content.position),"content_size":vector_receipt(frame.content.size),
		"physical_transform":screen_receipt(frame.screen),
		"native_serial":frame.native_serial,"world_generation":frame.world_generation,"actor_epoch":frame.actor_epoch,
		"current_layout_acknowledged":current_presentation_layout(after_callback),
		"exact_published_layers_agree":presentation_layers_agree(frame)}


func sample_ready(after_sequence: int = 0) -> bool:
	var sample: Dictionary = desktop.latest_snapshot.native_worker_participation
	return not sample.is_empty() and int(sample.sequence) > after_sequence \
		and int(sample.world_generation) == desktop.latest_snapshot.render_world_generation


func sample_disabled() -> bool:
	return desktop.latest_snapshot.native_worker_participation.is_empty()


func publications_resumed(after_serial: int) -> bool:
	return desktop.consumed_snapshot_serial > after_serial


func new_session(epoch: int, rig: StringName, rules: String) -> bool:
	return actor_ready(desktop, rig) and desktop._physical_epoch > epoch \
		and desktop.playable_session_options.rules == rules


func paused_acknowledged(serial: int) -> bool:
	return desktop.latest_snapshot.serial > serial and desktop.latest_snapshot.paused and desktop.paused


func launcher_ready() -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://feature_launcher.tscn"


func counter_state() -> Dictionary:
	var counter = desktop.worker_publication_counter
	return {"last_serial":counter.last_serial, "consumed":counter.consumed,
		"coalesced":counter.coalesced, "rejected":counter.rejected}


func pure_presentation_controls(rig: StringName) -> void:
	var counter = Counter.new()
	expect(counter.observe(1) and counter.observe(4) and counter.consumed == 2 and counter.coalesced == 2,
		"serial model counts two genuinely skipped publication ordinals")
	expect(not counter.observe(4) and not counter.observe(3) and not counter.observe(0)
		and counter.last_serial == 4 and counter.consumed == 2 and counter.coalesced == 2 and counter.rejected == 3,
		"duplicate/delayed/nonpositive serial models refuse without inflating progress")
	expect(counter.observe(6) and counter.consumed == 3 and counter.coalesced == 3,
		"serial model preserves its high-water mark after rejected delivery")
	var overlay: Control = desktop.playable_course_overlay.get_script().new()
	root.add_child(overlay)
	var identity: Dictionary = {"rig":str(rig), "actor_epoch":1, "world_generation":1,
		"source_tick":5, "physics_tick":8, "target_index":1}
	overlay.present_course(identity, Vector2(128,128), Vector2i(512,256), Rect2(4,8,1024,512))
	expect(overlay.visible and overlay.target_index == 1 and overlay.targets == Course.checkpoints(rig)
		and overlay.course_identity == identity,
		"presentation-only completed-marker model retains exact authored coordinates and progress")
	expect(overlay._point(Course.checkpoints(rig)[0]) == (Course.checkpoints(rig)[0]-Vector2(128,128))*2.0,
		"presentation model maps world targets through the same content scale as actor shapes")
	identity.target_index = 4
	overlay.present_course(identity, Vector2(128,128), Vector2i(512,256), Rect2(4,8,1024,512))
	expect(overlay.visible and overlay.target_index == 4, "completed-course model retains all four completed markers")
	identity.target_index = 5
	overlay.present_course(identity, Vector2(128,128), Vector2i(512,256), Rect2(4,8,1024,512))
	expect(not overlay.visible and overlay.targets.is_empty() and overlay.course_identity.is_empty(),
		"out-of-range progress refuses rather than drawing a fabricated fifth checkpoint")
	identity.target_index = 0
	identity.world_generation = -1
	overlay.present_course(identity, Vector2.ZERO, Vector2i(512,256), Rect2(0,0,1024,512))
	expect(not overlay.visible and overlay.targets.is_empty(), "invalid source identity clears retained model markers")
	overlay.free()


func capture_graphical(rig: StringName, camera: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var directory: String = OS.get_environment("CYBERSAND_PLAY_UI007_CAPTURE_DIR")
	if directory.is_empty():
		directory = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if directory.is_empty():
		directory = OS.get_user_data_dir().path_join("play-ui007")
	var created: Error = DirAccess.make_dir_recursive_absolute(directory)
	expect(created == OK, "graphical capture directory is writable")
	if created != OK:
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = directory.path_join(str(rig) + "-" + camera + ".png")
	expect(image != null and not image.is_empty(), "actual graphical viewport returns pixels")
	if image == null or image.is_empty():
		return
	var saved: Error = image.save_png(path)
	expect(saved == OK, "actual graphical screenshot is retained")
	var hashed := HashingContext.new()
	hashed.start(HashingContext.HASH_SHA256)
	hashed.update(FileAccess.get_file_as_bytes(path))
	row.graphical_captures.append({"path":path, "sha256":hashed.finish().hex_encode(),
		"width":image.get_width(), "height":image.get_height(),
		"camera":camera, "identity":desktop.playable_course_overlay.course_identity.duplicate(true),
		"actor_parts":desktop.physical_actor_overlay._parts.size(),
		"pixel_interpretation":"raw actual-host image; independently inspect target, actor and terrain output"})


func test_sequence(rig: StringName) -> bool:
	var installed_overlay: Node = desktop.get_node_or_null("Layout/World/PlayableCourseOverlay")
	expect(installed_overlay != null, "shared Main installs the authored course checkpoint overlay")
	if installed_overlay == null:
		return false
	expect(not installed_overlay.visible, "ordinary sandbox has no stray course targets")
	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"normal authored course request is admitted")
	if not await bounded(Callable(self, "course_installed").bind(desktop), "native course installation"):
		return false
	expect(desktop.apply_actor_prototype_configuration(StringName("rapier/" + str(rig)), &"human", false),
		"normal rig configuration is admitted")
	if not await bounded(Callable(self, "actor_ready").bind(desktop, rig), "native/physical actor and terrain ready"):
		return false
	if not await bounded(Callable(self, "targets_ready"), "current lap targets are visibly presented"):
		return false
	var follow_callback: int = desktop.main_callbacks
	row.first_target_observation = {"main_callback":follow_callback,
		"published_physical_transform":screen_receipt(desktop.presentation_frame.screen),
		"observed_physical_transform":screen_receipt(desktop.world_view.get_viewport().get_final_transform() * desktop.world_view.get_global_transform_with_canvas()),
		"root_size":vector_receipt(root.size)}
	if not await bounded(Callable(self, "current_presentation_layout").bind(follow_callback),
		"a new actual Main callback presents the observed follow layout"):
		return false
	var overlay: Control = desktop.playable_course_overlay
	var identity: Dictionary = overlay.course_identity.duplicate(true)
	row.initial_identity = identity
	expect(overlay.targets == Course.checkpoints(rig) and overlay.target_index == 0
		and identity.rig == str(rig) and identity.actor_epoch == desktop._physical_epoch
		and identity.world_generation == desktop.latest_snapshot.render_world_generation
		and identity.source_tick == desktop._playable_course_progress.last_source_tick
		and identity.physics_tick == desktop._playable_course_progress.last_physics_tick,
		"actual presented targets bind authored positions and copied current native/Rapier lap identity")
	expect(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.clip_contents
		and overlay.get_index() < desktop.physical_actor_overlay.get_index(),
		"target overlay cannot intercept controls or cover the actual actor layer")
	expect(not desktop.physical_actor_overlay._parts.is_empty(), "actual Rapier actor parts remain presented")
	pure_presentation_controls(rig)
	expect(overlay._origin == desktop.presentation_camera_origin() and overlay._view_size == Vector2(desktop.current_view_size)
		and overlay.position == desktop.view_content_rect().position and overlay.size == desktop.view_content_rect().size
		and presentation_layers_agree(desktop.presentation_frame),
		"follow camera target and actor content transforms agree")
	row.follow_presentation = presentation_receipt(follow_callback)
	await capture_graphical(rig, "follow")
	var overview_callback: int = desktop.main_callbacks
	var overview_epoch: int = desktop._physical_epoch
	var overview_generation: int = desktop.latest_snapshot.render_world_generation
	var overview_session: Variant = desktop.physical_actor_session
	parse_key(KEY_F, true)
	parse_key(KEY_F, false)
	await process_frame
	await process_frame
	if not await bounded(Callable(self, "current_presentation_layout").bind(overview_callback),
		"a new actual Main callback presents the observed overview layout"):
		return false
	expect(not desktop.camera_follow_enabled and desktop.camera_origin == Vector2(Course.VIEW.position)
		and overlay._origin == desktop.presentation_camera_origin() and overlay._view_size == Vector2(Course.VIEW.size)
		and desktop._physical_epoch == overview_epoch and desktop.latest_snapshot.render_world_generation == overview_generation
		and desktop.physical_actor_session == overview_session and presentation_layers_agree(desktop.presentation_frame),
		"real F input maps targets onto the authored overview without rebuilding")
	row.overview_presentation = presentation_receipt(overview_callback)
	await capture_graphical(rig, "overview")
	parse_key(KEY_F, true)
	parse_key(KEY_F, false)
	await process_frame

	var native_start: int = desktop.latest_snapshot.tick_index
	var physics_start: int = desktop.physical_actor_session.tick
	parse_key(KEY_P, true)
	parse_key(KEY_P, false)
	if not await bounded(Callable(self, "clocks_advanced").bind(desktop,rig,physics_start,native_start),
		"actual native and physical clocks advance with production targets present"):
		return false
	expect(desktop.latest_snapshot.native_worker_participation.is_empty(),
		"ordinary production frames leave optional participation observation off")
	var unobserved: Dictionary = desktop.latest_snapshot.native_worker_participation
	expect(unobserved.is_read_only(),
		"unobserved native participation is an immutable publication value")
	desktop.debug_stats_expanded = true
	desktop.update_status()
	if not await bounded(Callable(self, "sample_ready").bind(0), "exclusive owner supplies a real completed-tick participation sample"):
		return false
	var retained: Dictionary = desktop.latest_snapshot.native_worker_participation
	var first: Dictionary = retained.duplicate(true)
	if not await bounded(Callable(self, "sample_ready").bind(int(first.sequence)), "a later bounded participation sample arrives"):
		return false
	var second: Dictionary = desktop.latest_snapshot.native_worker_participation
	expect(second.sampled_usec - first.sampled_usec >= 250000 and second.completed_tick > first.completed_tick,
		"participation sampling is limited to at most four distinct completed-tick samples per second")
	expect(first == retained and retained.is_read_only() and retained.phase_jobs.is_read_only(),
		"new sampling cannot mutate an earlier immutable native-count record")
	expect(second.workers_observed >= 0 and second.workers_observed <= second.worker_capacity
		and second.worker_capacity == desktop.latest_snapshot.scheduler_thread_capacity_hint
		and second.completed_tick <= desktop.latest_snapshot.tick_index
		and str(second.scope).contains("not utilization"),
		"observed task participation stays distinct from configured capacity and utilization")
	expect(desktop.latest_snapshot.native_worker_request == int(ProjectSettings.get_setting("cybersand/native_worker_threads",0)),
		"snapshot reports the construction-time requested worker setting")
	desktop.update_status()
	expect(desktop.status_label.text.contains("requested Auto / capacity")
		and desktop.status_label.text.contains("task participants at native tick")
		and desktop.status_label.text.contains("owner publications")
		and desktop.status_label.text.contains("render payloads"),
		"details show requested/capacity/sample-age and separate publication/render dispositions")
	row.participation_samples = [first,second.duplicate(true)]
	desktop.debug_stats_expanded = false
	desktop.update_status()
	if not await bounded(Callable(self, "sample_disabled"), "disabling details retires optional sampling"):
		return false
	var disabled: Dictionary = desktop.latest_snapshot.native_worker_participation
	expect(disabled.is_read_only() and unobserved.is_read_only() and unobserved.is_empty()
		and retained == first and retained.is_read_only(),
		"disabled participation remains immutable without changing retained empty or populated samples")
	row.empty_samples_immutable = unobserved.is_read_only() and disabled.is_read_only()

	# Hold only Main consumption for a bounded interval; native callbacks and
	# publications continue normally. No fake packet or parallel owner is used.
	var counter_before: Dictionary = counter_state()
	var callbacks_before: int = desktop.main_callbacks
	desktop.suppress_consumption = true
	for _frame: int in range(16):
		await process_frame
	expect(counter_state() == counter_before and desktop.main_callbacks > callbacks_before,
		"held-consumer negative preserves counters while Main remains alive")
	desktop.suppress_consumption = false
	if not await bounded(Callable(self, "publications_resumed").bind(int(counter_before.last_serial)),
		"normal consumer resumes from the actual owner's latest publication"):
		return false
	var counter_after: Dictionary = counter_state()
	expect(counter_after.coalesced > counter_before.coalesced
		and counter_after.coalesced-counter_before.coalesced == counter_after.last_serial-counter_before.last_serial
			-(counter_after.consumed-counter_before.consumed)
		and counter_after.last_serial == desktop.consumed_snapshot_serial,
		"actual skipped owner serials are accounted exactly without calling them missing native ticks")
	row.publication_control = {"before":counter_before,"after":counter_after}
	var old_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot

	var panel = desktop.playable_session_panel
	panel.show_selection()
	panel.rule_choice.select(1)
	var old_epoch: int = desktop._physical_epoch
	expect(panel.build_selected(), "free-play uses normal composed reconstruction")
	desktop._present_playable_course_targets()
	expect(not overlay.visible and overlay.targets.is_empty(), "pending reconstruction clears old course markers")
	if not await bounded(Callable(self, "new_session").bind(old_epoch,rig,"freeplay"), "actual free-play replacement"):
		return false
	panel.resume_play()
	await process_frame
	expect(not overlay.visible and overlay.course_identity.is_empty() and not desktop.course_timing_label.visible,
		"accepted free play has neither misleading targets nor lap HUD")
	panel.show_selection()
	panel.rule_choice.select(0)
	old_epoch = desktop._physical_epoch
	expect(panel.build_selected(), "lap re-entry uses normal composed reconstruction")
	if not await bounded(Callable(self, "new_session").bind(old_epoch,rig,"lap"), "actual lap replacement"):
		return false
	panel.resume_play()
	if not await bounded(Callable(self, "targets_ready"), "fresh lap targets return"):
		return false
	var current_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	desktop.latest_snapshot = old_snapshot
	desktop._present_playable_course_targets()
	expect(not overlay.visible and overlay.targets.is_empty(),
		"retained actual old-epoch snapshot cannot draw targets on a replacement actor")
	desktop.latest_snapshot = current_snapshot
	desktop._present_playable_course_targets()
	expect(overlay.visible and overlay.course_identity.actor_epoch == desktop._physical_epoch
		and overlay.course_identity.world_generation > identity.world_generation,
		"restored current immutable publication presents only the replacement identity")
	desktop.microscenario_hud_hidden = true
	desktop._present_playable_course_targets()
	expect(not overlay.visible and overlay.targets.is_empty(), "clean-view mode removes target annotations")
	desktop.microscenario_hud_hidden = false
	desktop._present_playable_course_targets()
	expect(overlay.visible, "restoring HUD restores current targets")
	row.final_identity = overlay.course_identity.duplicate(true)
	expect(not desktop.simulation_worker.has_failed(), "actual native worker remains healthy")
	return true


func record_return_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		row.return_input.gui_events.append({"kind":"motion","position":vector_receipt(event.position),
			"button_mask":event.button_mask})
	elif event is InputEventMouseButton:
		row.return_input.gui_events.append({"kind":"button","position":vector_receipt(event.position),
			"button_mask":event.button_mask,"button_index":event.button_index,"pressed":event.pressed})


func record_return_pressed() -> void:
	row.return_input.pressed_signals += 1


func click_return_button() -> void:
	var button: Button = desktop.playable_session_panel.return_button
	var popup: PopupPanel = desktop.playable_session_panel
	# An embedded Popup cannot update its own hover tracking through push_input.
	# Route the complete pointer sequence through its root/embedder, using the
	# actual popup transform, so normal hit testing reaches the real button.
	var position: Vector2 = Vector2(popup.position) + popup.get_final_transform() * button.get_global_rect().get_center()
	row.return_input = {"root_position":vector_receipt(position),"popup_position":vector_receipt(popup.position),
		"popup_transform":screen_receipt(popup.get_final_transform()),
		"button_position":vector_receipt(button.get_global_rect().position),"button_size":vector_receipt(button.size),
		"hover_before":button.is_hovered(),"gui_events":[],"pressed_signals":0}
	button.gui_input.connect(record_return_gui_input)
	button.pressed.connect(record_return_pressed)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	row.return_input.hover_after_motion = button.is_hovered()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
	var buttons: Array = row.return_input.gui_events.filter(func(event: Dictionary) -> bool: return event.kind == "button")
	expect(row.return_input.hover_after_motion and row.return_input.pressed_signals == 1 and buttons.size() == 2
		and buttons[0].pressed and buttons[0].button_mask == MOUSE_BUTTON_MASK_LEFT
		and not buttons[1].pressed and buttons[1].button_mask == 0,
		"root pointer hit testing delivers press/release and the actual Return button signal")


func run() -> void:
	fixture_started_usec = Time.get_ticks_usec()
	var rig: StringName = target_rig()
	row = {"rig":str(rig),"waits":[],"graphical_captures":[]}
	release_controls()
	expect(ClassDB.class_exists("CyberNativeCellWorld") and ClassDB.class_exists("RapierPhysicsServer2D"),
		"actual native and Rapier backends are present")
	expect(rig in Course.MECHANICAL_PRESETS, "wrapper selects one mechanical rig")
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(PresentationMain)
	root.add_child(desktop)
	current_scene = desktop
	var main_allowance_usec: int = Watchdogs.microseconds("main_ack_seconds")
	var main_deadline_usec: int = fixture_started_usec + main_allowance_usec
	while desktop.main_callbacks == 0 and Time.get_ticks_usec() < main_deadline_usec:
		await process_frame
	row.main_ack_usec = Time.get_ticks_usec() - fixture_started_usec
	var main_acknowledged: bool = desktop.main_callbacks > 0 and row.main_ack_usec <= main_allowance_usec
	expect(main_acknowledged, "actual Main callback acknowledges within the configured Main acknowledgement watchdog")
	var worker: CyberSimulationWorker = desktop.simulation_worker
	var worker_started: bool = worker != null and desktop.worker_start_error == OK and worker._thread.is_started()
	expect(worker_started, "the existing native worker starts")
	var success: bool = false
	if main_acknowledged and worker_started and failures == 0:
		success = await test_sequence(rig)
	var session: Variant = desktop.physical_actor_session
	var teardown_started: int = Time.get_ticks_usec()
	if success and DisplayServer.get_name() != "headless":
		# A parent-focus transition from the earlier popup lifecycle may still
		# queue hide. Acknowledge native root focus and drain that lifecycle
		# before the final real pointer test opens the popup again.
		row.return_native_focus = {"before":root.has_focus(),"requested_process_frame":Engine.get_process_frames()}
		root.grab_focus()
		var focused: bool = await bounded(Callable(root,"has_focus"), "native root window acknowledges focus before Return input")
		row.return_native_focus.acknowledged = focused
		if focused:
			await RenderingServer.frame_post_draw
			focused = root.has_focus()
			row.return_native_focus.after_rendered_frame = focused
			row.return_native_focus.rendered_process_frame = Engine.get_process_frames()
			expect(focused, "native root focus remains current after the deferred popup lifecycle")
		success = focused
	if success:
		desktop.playable_session_panel.show_selection()
		var button: Button = desktop.playable_session_panel.return_button
		expect(button.text == "Return to launcher" and button.visible and not button.disabled
			and button.pressed.is_connected(desktop.playable_session_panel.return_to_launcher),
			"Return to launcher is an enabled real button bound to ordinary scene navigation")
		if DisplayServer.get_name() == "headless":
			# Headless reports a 1x1 usable popup area and no native window
			# focus. Exercise the real button's connected callback, explicitly
			# without claiming viewport hit testing or display visibility.
			row.return_activation = "actual_button_pressed_signal; headless_window_hit_testing_unqualified"
			button.pressed.emit()
		else:
			await process_frame
			await process_frame
			expect(button.is_visible_in_tree()
				and Rect2(Vector2.ZERO, Vector2(desktop.playable_session_panel.size)).encloses(button.get_global_rect()),
				"graphical Return button is visible and fully inside the popup")
			row.return_activation = "actual_root_viewport_mouse_motion_press_release"
			click_return_button()
		var navigated: bool = await bounded(Callable(self,"launcher_ready"), "actual Return button callback reaches the launcher")
		row.return_button_navigation = navigated
		expect(navigated and not is_instance_valid(desktop),
			"ordinary scene replacement actually destroys the shared Main owner")
	await close_cycle(desktop if is_instance_valid(desktop) else null, worker, session, "UI007: ")
	var teardown_usec: int = Time.get_ticks_usec()-teardown_started
	expect(teardown_usec <= WAIT_TIMEOUT_MS*1000, "complete navigation/teardown respects configured operation watchdog")
	expect(Time.get_ticks_usec()-fixture_started_usec <= Watchdogs.microseconds("complex_fixture_seconds"), "complete fixture respects its configured fixture watchdog")
	row.completed = success and failures == 0
	print("PLAY_UI007_RESULT ",JSON.stringify({"schema":"play-ui007-v1",
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"rig":str(rig),
		"display_server":DisplayServer.get_name(),"physics_engine":ProjectSettings.get_setting("physics/2d/physics_engine"),
		"assertions":assertions,"failures":failures,"row":row,
		"elapsed_usec":Time.get_ticks_usec()-fixture_started_usec,"teardown_usec":teardown_usec,
		"worker_joined":joined_workers==1,"session_retired":retired_sessions==1,
		"real_host":true,"automatic_callbacks":true,"manual_physics_calls":0,
		"window_focus_seam":true,"consumer_hold_is_negative_control":true,
		"presentation_model_controls":true,"natural_gate_traversal_qualified":false,
		"graphical_capture_executed":not row.graphical_captures.is_empty(),
		"rendered_fps_measured":false,"physical_devices_qualified":false,"human_feel_qualified":false,"retries":0}))
	quit(0 if row.completed else 1)
