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
	var controls: Array[Control] = [row.get_child(3), row.get_child(2), review.chooser, review.arm]
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
	for arm_index: int in [0,1]:
		for i: int in range(review.cases.size()):
			if review.cases[i].id == "hard": review.chooser.select(i)
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
	print("Y1 review fresh-owner selection, focused Space press/hold/release and hard excavation passed; no human gameplay verdict")
	quit(0)
