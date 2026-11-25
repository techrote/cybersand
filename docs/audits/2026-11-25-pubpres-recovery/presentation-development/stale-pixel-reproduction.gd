extends "res://tests/test_workbench_presentation_submission.gd"

func _run() -> void:
	if await _mounted():
		_freeze_normal_processing()
		await process_frame
		var before_frame: Dictionary = host.workbench_presentation_frame
		var old_image: Image = root.get_texture().get_image()
		var old_camera: Vector2 = host.camera_origin
		host.camera_origin += Vector2(32,0)
		_prepare()
		var staged: Dictionary = host._workbench_submission.candidate.frame
		OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","")
		await RenderingServer.frame_post_draw
		var new_image: Image = root.get_texture().get_image()
		var record: Dictionary = {"schema":"pubpres-stale-candidate-pixels-reproduction-v1",
			"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
			"diagnostic_sha256":FileAccess.get_sha256(get_script().resource_path),
			"prototype_main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),
			"prototype_transaction_sha256":FileAccess.get_sha256("res://scripts/workbench_presentation_submission.gd"),
			"old_framebuffer_sha256":old_image.get_data().hex_encode().sha256_text(),
			"new_framebuffer_sha256":new_image.get_data().hex_encode().sha256_text(),
			"pixels_changed":old_image.get_data()!=new_image.get_data(),
			"journal_unchanged":before_frame==host.workbench_presentation_frame,
			"old_mapping":str(before_frame.camera_mapping),"staged_mapping":str(staged.camera_mapping),
			"actual_picking_mapping":str(host.presentation_camera_screen_transform()),
			"status":host.workbench_presentation_submission_status(),
			"scope":"actual graphical proof of rejected staged canvas still drawn; not performance"}
		old_image.save_png(output.get_base_dir().path_join("stale-before.png"))
		new_image.save_png(output.get_base_dir().path_join("stale-after.png"))
		var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(record,"  ")+"\n")
		file.close()
		print("STALE_PIXELS_REPRODUCTION ",JSON.stringify(record))
		host.camera_origin = old_camera
		host.queue_free()
	quit()
