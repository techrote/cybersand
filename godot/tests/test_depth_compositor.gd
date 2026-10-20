extends SceneTree

const DepthCompositor = preload("res://scripts/depth/depth_compositor.gd")
const Surface = preload("res://scripts/depth/depth_layer_surface.gd")

var failures: int = 0
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Control.new()
	host.size = Vector2(960, 540)
	root.add_child(host)
	var compositor: CyberDepthCompositor = DepthCompositor.new()
	compositor.size = host.size
	host.add_child(compositor)
	compositor.configure()
	for index: int in range(4):
		var plane: CyberDepthLayerSurface = compositor._surfaces[index]
		_expect(plane._material_rect.size == Vector2(640,360), "Native backing must not expand the rendered ROI")
		if index > 0:
			_expect(plane.world_2d != compositor._surfaces[index - 1].world_2d, "Material planes must have independent canvases")
	compositor.set_camera(Vector2(80, 45))
	compositor.set_options({
		"mode": "hybrid",
		"parallax_strength": 1.0,
		"relief_depth": 12.0,
		"relief_slices": 8,
		"relief_quantization": 2.0,
	})
	var rear_world := Vector2(366, 218)
	var screen: Vector2 = compositor.get_layer_screen_position(rear_world, 1)
	var reconstructed: Vector2 = compositor.screen_to_layer(screen, 1)
	_expect(reconstructed.distance_to(rear_world) < 0.01, "rear transform inverse lost pointer authority")
	var play_screen: Vector2 = compositor.get_layer_screen_position(rear_world, 0)
	_expect(screen.distance_to(play_screen) > 0.01, "rear layer has no distinct parallax transform")
	var surface: CyberDepthLayerSurface = Surface.new()
	surface.configure("play")
	host.add_child(surface)
	var bad: Dictionary = {
		"failed": false, "serial": 1, "channels": 2, "full_refresh": false,
		"rectangles": PackedInt32Array([0, 0, 85, 128, 0, 170]),
		"cells": PackedByteArray(), "layer_id": "play",
		"reset_generation": 1, "layer_tick": 0,
	}
	_expect(not surface.apply_packet(bad), "empty patch payload was accepted")
	_expect(str(surface.diagnostics()["last_rejection"]) == "patch payload is empty", "malformed packet reason changed")
	var duplicate := PackedInt32Array()
	for _i: int in range(17):
		duplicate.append_array(PackedInt32Array([0, 0, 256, 256, 0, 512]))
	var bytes := PackedByteArray()
	bytes.resize(256 * 256 * 2)
	var too_much: Dictionary = bad.duplicate(true)
	too_much["rectangles"] = duplicate
	too_much["cells"] = bytes
	too_much["serial"] = 2
	_expect(not surface.apply_packet(too_much), "duplicated staged area escaped allocation bound")
	var current: Dictionary = bad.duplicate(true)
	current["rectangles"] = PackedInt32Array([100,100,1,1,0,2])
	current["cells"] = PackedByteArray([131,0])
	current["reset_generation"] = 7
	current["serial"] = 50
	current["layer_tick"] = 12
	_expect(surface.apply_packet(current), "initial generation packet rejected")
	current["reset_generation"] = 8
	current["serial"] = 1
	current["layer_tick"] = 0
	current["cells"] = PackedByteArray([81,0])
	_expect(surface.apply_packet(current), "newer generation packet rejected")
	var accepted_pixels: PackedByteArray = surface.cell_image.get_data()
	var stale: Dictionary = current.duplicate(true)
	stale["reset_generation"] = 7
	stale["serial"] = 999
	stale["layer_tick"] = 99
	stale["cells"] = PackedByteArray([0,0])
	_expect(not surface.apply_packet(stale), "older generation with a newer serial was accepted")
	_expect(surface.last_rejection == "packet reset generation moved backwards", "stale generation rejection reason changed")
	_expect(surface.cell_image.get_data() == accepted_pixels, "stale generation altered copied pixels")
	_expect(surface.last_serial == 1 and surface.reset_generation == 8 and surface.layer_tick == 0,
		"stale generation altered accepted serial/generation/tick")
	compositor.set_options({"mode": "diorama", "cutaway": true, "focus_position": rear_world})
	_expect(int(compositor.get_diagnostics()["full_rg8_uploads"]) == 0, "compositor created uploads without publications")
	if failures == 0:
		print("Depth compositor regression passed; ", checks, " checks")
	host.queue_free()
	await process_frame
	quit(failures)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error(message)
