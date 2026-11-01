extends SceneTree

func _space_event(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame

func _test_pause_input(review: Control) -> bool:
	# Dispatch through SceneTree/GUI, including focused buttons' ui_accept.
	# Calling toggle_pause directly cannot catch a competing GUI activation.
	var row: HBoxContainer = review.chooser.get_parent()
	var controls: Array[Control] = [row.get_child(3), row.get_child(2), review.chooser, review.arm, review.presentation]
	for control: Control in controls:
		control.grab_focus()
		await process_frame
		review.paused = true
		var owner: Object = review.fixture.world
		var selected_case: int = review.chooser.selected
		var selected_arm: int = review.arm.selected
		await _space_event(true)
		if review.paused:
			push_error("Space press failed to resume with focus on " + control.get_class())
			return false
		for _repeat: int in range(3):
			await _space_event(true, true)
			if review.paused:
				push_error("Held Space toggled pause repeatedly")
				return false
		await _space_event(false)
		if review.paused or review.resetting or review.fixture.world != owner or review.chooser.selected != selected_case or review.arm.selected != selected_arm:
			push_error("Space release activated a focused control or toggled pause")
			return false
		await _space_event(true)
		if not review.paused:
			push_error("Second Space press failed to pause")
			return false
		await _space_event(false)
		if not review.paused:
			push_error("Space release resumed the paused scene")
			return false
	# Mouse/button activation still uses the same single toggle.
	row.get_child(3).pressed.emit()
	if review.paused: return false
	row.get_child(3).pressed.emit()
	return review.paused

func _init() -> void:
	call_deferred("_run")

func _test_presentation(review: Control) -> bool:
	review.paused = true
	var owner: Object = review.fixture.world
	var pose: Array = review.fixture.pose(0)
	var tick: int = review.fixture.tick
	var cells: PackedByteArray = review.fixture.observation(true).cells
	for mode: int in [1,2,0]:
		review.presentation.select(mode)
		review.refresh_view()
		if review.fixture.world != owner or review.fixture.tick != tick or review.fixture.pose(0) != pose or review.fixture.observation(true).cells != cells:
			push_error("Review presentation changed authoritative simulation")
			return false
	var image := Image.create(40,40,false,Image.FORMAT_RGBA8)
	review.raster_body(image,Vector2(20,20),Vector2(8,14),0.0,true)
	var fill_count: int = 0
	var border_count: int = 0
	for y: int in range(40):
		for x: int in range(40):
			var color: Color = image.get_pixel(x,y)
			if color.a == 0.0: continue
			if color.r > 0.5: fill_count += 1
			else: border_count += 1
	if fill_count != 72 or border_count != 40:
		push_error("Pixel review rectangle lost its one-cell inner border/size")
		return false
	var shifted := Image.create(40,40,false,Image.FORMAT_RGBA8)
	review.raster_body(shifted,Vector2(20.2,20.2),Vector2(8,14),0.0,true)
	if image.get_data() != shifted.get_data():
		push_error("Subcell translation bypassed the presentation cell grid")
		return false
	# Rotated/clipped projection must remain a finite palette, with no AA fringe.
	var rotated := Image.create(40,40,false,Image.FORMAT_RGBA8)
	review.raster_body(rotated,Vector2(0,20),Vector2(8,14),PI/4.0,false)
	for y: int in range(40):
		for x: int in range(40):
			var color: Color = rotated.get_pixel(x,y)
			if color.a != 0.0 and not color.is_equal_approx(image.get_pixel(20,20)):
				push_error("Pixel review introduced an antialias palette fringe")
				return false
	return true

func _run() -> void:
	var scene: PackedScene = load("res://y1_envelope_review.tscn")
	var review: Control = scene.instantiate()
	root.add_child(review)
	await process_frame
	await process_frame
	if review.fixture == null or not review.last_error.is_empty():
		push_error("Y1 owner review did not construct a source-bound fixture")
		quit(1)
		return
	review.paused = true
	if not _test_presentation(review):
		quit(1)
		return
	if not await _test_pause_input(review):
		quit(1)
		return
	var first: Object = review.fixture.world
	review.arm.select(1)
	await review.reset_case()
	if review.fixture.world == first or review.fixture.candidate != "Y1":
		push_error("Review selector did not replace the diagnostic world")
		quit(1)
		return
	review.fixture.step()
	var metrics: Array = review.fixture.world.diagnostic_body_metrics()
	if metrics.is_empty() or metrics[0][20].candidate != "Y1":
		push_error("Review UI and native selector disagree")
		quit(1)
		return
	# The E tool must retire hard colliders as well as native material.
	var hard_index: int = -1
	for i: int in range(review.cases.size()):
		if review.cases[i].id == "hard": hard_index = i
	if hard_index < 0 or review.arm.item_count != (4 if review.admission_enabled else 3):
		push_error("Review omitted registered controls or GCR selection")
		quit(1)
		return
	review.arm.select(2)
	await review.reset_case()
	if review.fixture.candidate != "GCR" or not review.fixture.world.gcr_diagnostics().enabled:
		push_error("GCR review selector did not construct the experimental native owner")
		quit(1)
		return
	if review.admission_enabled:
		review.arm.select(3)
		await review.reset_case()
		if review.fixture.candidate != "GCR-A1" or review.fixture.runtime_identity().admission_variant != "A1":
			push_error("A1 review selector did not construct admission-only native owner")
			quit(1)
			return
	for arm_index: int in range(review.arm.item_count):
		review.chooser.select(hard_index)
		review.arm.select(arm_index)
		await review.reset_case()
		review.paused = true
		var before_y: float = review.fixture.pose(0)[1]
		review.excavate_now()
		for _step: int in range(60): review.fixture.step()
		if float(review.fixture.pose(0)[1])-before_y < 4.0:
			push_error("Review hard excavation retained a stale Rapier collider")
			quit(1)
			return
	review.fixture.close()
	review.fixture = null
	review.queue_free()
	await process_frame
	print("Y1 review fresh owners, Space focus, presentation authority/pixel grid and hard excavation passed; no automated human verdict")
	quit(0)
