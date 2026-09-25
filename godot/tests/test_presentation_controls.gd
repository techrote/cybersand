extends SceneTree

# Focused scene-level checks for desktop presentation/tool controls. These checks
# exercise the UI-side geometry and pointer contract without changing simulation
# semantics or registered scenario definitions.

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://main.tscn") as PackedScene
	var main: Control = packed_scene.instantiate() as Control
	get_root().add_child(main)
	await process_frame

	var status: Label = main.get_node("Layout/Status") as Label
	var help: Label = main.get_node("Layout/Help") as Label
	_expect(status.visible, "compact status did not start visible")
	_expect(not help.visible, "shortcut help should be hidden in compact mode")
	_expect(main.render_snapshot_hz == 60, "desktop publication default is not 60 Hz")
	_expect(
		CyberSimulationWorker.DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC == 16667,
		"worker publication default is not the 60 Hz interval"
	)
	main.update_status()
	if main.latest_snapshot != null and not main.latest_snapshot.simulation_failed:
		_expect(
			status.text.count("\n") == 1,
			"ordinary status is not approximately two concise lines"
		)

	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F3
	toggle.pressed = true
	main._unhandled_key_input(toggle)
	_expect(main.debug_stats_expanded, "F3 did not expand diagnostics")
	_expect(help.visible, "expanded diagnostics did not expose settings shortcuts")
	main.update_status()
	if main.latest_snapshot != null and not main.latest_snapshot.simulation_failed:
		_expect(status.text.count("\n") >= 3, "expanded diagnostics did not deepen the readout")
	main._unhandled_key_input(toggle)
	_expect(not main.debug_stats_expanded, "second F3 did not restore compact diagnostics")
	_expect(not help.visible, "compact diagnostics left shortcut prose visible")

	toggle.shift_pressed = true
	main._unhandled_key_input(toggle)
	_expect(not status.visible, "Shift+F3 did not hide the stats readout")
	main._unhandled_key_input(toggle)
	_expect(status.visible, "Shift+F3 did not restore the stats readout")
	toggle.shift_pressed = false

	_expect(
		main.brush_shape == "circle"
			and main.brush_size_px == 9
			and main.brush_footprint_cells(100, 100).size() / 2 == 49,
		"default circle no longer matches the retained radius-4 lattice"
	)

	var primary: int = main.selected_material_id
	var primary_index: int = main.PAINTABLE_MATERIAL_IDS.find(primary)
	var expected_secondary: int = main.PAINTABLE_MATERIAL_IDS[
		(primary_index + 1) % main.PAINTABLE_MATERIAL_IDS.size()
	]
	_expect(
		main.effective_secondary_material_id() == expected_secondary,
		"secondary material is not the next valid paintable material"
	)
	_expect(
		main.brush_material_for_buttons(false, true, false) == expected_secondary,
		"MMB did not resolve to the effective secondary material"
	)
	_expect(
		main.brush_material_for_buttons(true, true, true) == CyberCellWorld.EMPTY,
		"RMB erase did not retain precedence"
	)

	_expect(main.set_brush_shape("square"), "square brush was rejected")
	_expect(main.set_brush_size(4), "valid square size was rejected")
	_expect(main.brush_dimensions() == Vector2i(4, 4), "square dimensions are wrong")
	_expect(
		main.brush_footprint_cells(100, 100).size() / 2 == 16,
		"square footprint is not exact edge×edge coverage"
	)

	_expect(main.set_brush_shape("rectangle"), "rectangle brush was rejected")
	_expect(main.set_brush_size(3), "valid rectangle short edge was rejected")
	_expect(main.set_brush_rectangle_ratio(2), "valid rectangle ratio was rejected")
	main.set_brush_rectangle_vertical(false)
	_expect(main.brush_dimensions() == Vector2i(6, 3), "horizontal rectangle dimensions are wrong")
	_expect(
		main.brush_footprint_cells(100, 100).size() / 2 == 18,
		"horizontal rectangle footprint is not exact"
	)
	main.set_brush_rectangle_vertical(true)
	_expect(main.brush_dimensions() == Vector2i(3, 6), "vertical rectangle dimensions are wrong")
	_expect(
		main.brush_footprint_cells(100, 100).size() / 2 == 18,
		"vertical rectangle footprint is not exact"
	)
	var retained_size: int = main.brush_size_px
	var retained_ratio: int = main.brush_rectangle_ratio
	_expect(not main.set_brush_size(0), "zero brush dimension was accepted")
	_expect(not main.set_brush_size(33), "oversize brush dimension was accepted")
	_expect(not main.set_brush_rectangle_ratio(5), "oversize rectangle ratio was accepted")
	_expect(
		main.brush_size_px == retained_size and main.brush_rectangle_ratio == retained_ratio,
		"invalid brush settings mutated the retained settings"
	)

	_expect(main.set_brush_shape("circle"), "circle brush was rejected")
	_expect(main.set_brush_size(4), "valid circle diameter was rejected")
	var circle: PackedInt32Array = main.brush_footprint_cells(100, 100)
	_expect(
		circle.size() > 0 and circle.size() / 2 <= 16,
		"circle footprint escaped its declared 4×4 diameter bounds"
	)

	main.current_view_size = Vector2i(320, 180)
	var content: Rect2 = main.view_content_rect()
	var target_pixel := Vector2i(37, 22)
	var local_point: Vector2 = content.position + Vector2(
		(float(target_pixel.x) + 0.5) / float(main.current_view_size.x) * content.size.x,
		(float(target_pixel.y) + 0.5) / float(main.current_view_size.y) * content.size.y
	)
	_expect(
		main.view_pixel_from_local_point(local_point) == target_pixel,
		"shared pointer mapping did not resolve the expected world-view pixel"
	)
	_expect(main.brush_preview != null, "brush footprint preview was not created")
	_expect(
		main.brush_outline_points(target_pixel).size() == main.BRUSH_PREVIEW_SEGMENTS + 1,
		"circle preview does not describe the configured footprint"
	)

	_expect(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920 and
			int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080 and
			int(ProjectSettings.get_setting("display/window/size/window_width_override")) == 1920 and
			int(ProjectSettings.get_setting("display/window/size/window_height_override")) == 1080,
		"project output settings are not 1920x1080"
	)
	_expect(
		not help.text.contains("A/D move") and not help.text.contains("Space jetpack"),
		"permanent basic movement prose remains in the main HUD"
	)

	main.simulation_worker.stop_worker()
	main.rapier_bridge.shutdown()
	main.queue_free()
	await process_frame
	if _failures == 0:
		print("Presentation controls regression passed; compact HUD, 60 Hz and brush UX")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
