extends SceneTree

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
	review.fixture.close()
	review.fixture = null
	review.queue_free()
	await process_frame
	print("Y1 review fresh-owner selection passed; no human gameplay verdict")
	quit(0)
