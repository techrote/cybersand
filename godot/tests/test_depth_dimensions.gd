extends SceneTree

const Runtime = preload("res://scripts/depth/depth_layer_runtime.gd")
const DepthCompositor = preload("res://scripts/depth/depth_compositor.gd")
const Cell = preload("res://scripts/cell_world.gd")

var checks: int = 0
var failures: int = 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world unavailable")
	if failures:
		quit(1)
		return
	var runtime: CyberDepthLayerRuntime = Runtime.new()
	for extent: Vector2i in [Vector2i(1024,1024), Vector2i(1024,192), Vector2i(96,256), Vector2i(8,8)]:
		var definitions: Dictionary = _definitions(extent)
		_expect(runtime.reset(definitions, extent), "reset rejected " + str(extent) + ": " + runtime.last_error)
		_expect(runtime.world_size == extent, "accepted dimensions were not installed")
		var marker: Vector2i = extent - Vector2i(6,6)
		for id: String in Runtime.IDS:
			_expect(runtime.material_at(id, marker) == _material(id), "far-edge marker missing: " + id + " " + str(extent))
			_expect(runtime.material_at(id, Vector2i(extent.x, 0)) == -1, "right exterior was admitted")
			_expect(runtime.material_at(id, Vector2i(0, extent.y)) == -1, "bottom exterior was admitted")
			_expect(runtime.material_at(id, Vector2i(-1, 0)) == -1, "negative exterior was admitted")
		var baked: Dictionary = runtime.snapshot_layer("background", true)
		_expect(not PackedByteArray(baked.cells).is_empty(), "far plane did not publish its first bake")
		var queued_cell := Vector2i(extent.x / 2, extent.y / 2)
		_expect(bool(runtime.paint_disc("play", queued_cell, 0, Cell.HEAT_SHIELD_TILE).get("accepted", false)), "valid queued edit rejected")
		var generation: int = runtime.generation()
		var tick: int = runtime.layer_tick("play")
		for invalid: Vector2i in [Vector2i.ZERO, Vector2i(-1,64), Vector2i(7,8), Vector2i(1025,1024), Vector2i(64,1025)]:
			_expect(not runtime.reset(definitions, invalid), "invalid dimensions accepted: " + str(invalid))
			_expect(runtime.world_size == extent and runtime.generation() == generation, "invalid dimensions replaced the live generation")
			_expect(runtime.layer_tick("play") == tick and int(runtime.stats().pending_commands) == 1, "invalid reset changed clocks/queued edits")
			_expect(runtime.material_at("play", marker) == Cell.PINE_PLANKS, "invalid reset changed live material")
			_expect(bool(runtime.stats().background_cached), "invalid reset discarded the far bake")
		var reserved: Dictionary = definitions.duplicate(true)
		reserved["play"] = PackedInt32Array([2,2,1,1,10])
		_expect(not runtime.reset(reserved, extent), "reserved material ID10 accepted in authoring")
		var outside: Dictionary = definitions.duplicate(true)
		outside["scripted"] = PackedInt32Array([extent.x - 1,2,2,1,Cell.MARBLE])
		_expect(not runtime.reset(outside, extent), "rectangle crossed the authored edge")
		_expect(runtime.world_size == extent and runtime.generation() == generation and int(runtime.stats().pending_commands) == 1,
			"invalid material/rectangle reset was not atomic")
		_expect(str(runtime.paint_disc("play", queued_cell, 0, 10).get("error", "")) == "invalid_material", "reserved ID10 edit accepted")
		_expect(str(runtime.paint_disc("play", Vector2i(extent.x - 1, 2), 0, Cell.WATER).get("error", "")) == "disc_crosses_plane_guard",
			"guard edit accepted")
		_expect(str(runtime.paint_disc("background", queued_cell, 0, Cell.FIRE).get("error", "")) == "background_frozen", "far plane edit accepted")
		_expect(bool(runtime.advance(0.0, true).ok), "queued edit flush failed")
		_expect(runtime.material_at("play", queued_cell) == Cell.HEAT_SHIELD_TILE, "invalid resets lost the accepted queued edit")
		for weather: String in ["rain", "snow", "fog", "energy"]:
			_expect(runtime.set_weather(weather), "weather mode rejected")
			_expect(bool(runtime.step_once().ok), "weather failed at " + str(extent) + ": " + weather)
		_expect(runtime.layer_tick("background") == 0, "far backdrop ticked")
		_expect(PackedByteArray(runtime.snapshot_layer("background", false).cells).is_empty(), "cached far backdrop republished bytes")
		# Include the east edge where the old 639-wide sink erased the guard.
		for point: Vector2i in [Vector2i.ZERO, Vector2i(extent.x - 1,0), Vector2i(0,extent.y - 1), extent - Vector2i.ONE,
				Vector2i(extent.x / 2,0), Vector2i(extent.x / 2,extent.y - 1), Vector2i(0,extent.y / 2), Vector2i(extent.x - 1,extent.y / 2),
				Vector2i(extent.x - 1,1), Vector2i(extent.x - 1,extent.y - 2)]:
			for id: String in ["play", "scripted", "effects"]:
				_expect(runtime.material_at(id, point) == Cell.WALL, "weather/sinks erased " + id + " guard at " + str(point))
		await _check_compositor(extent)
	print("Depth dimensions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_compositor(extent: Vector2i) -> void:
	var compositor: CyberDepthCompositor = DepthCompositor.new()
	compositor.size = Vector2(960,540)
	_expect(compositor.configure(extent), "compositor rejected admitted dimensions")
	root.add_child(compositor)
	_expect(compositor.world_size == Vector2(extent), "compositor dimensions drifted from native ROI")
	for surface: CyberDepthLayerSurface in compositor._surfaces:
		_expect(surface.size == extent and surface._material_rect.size == Vector2(extent), "surface failed to render complete ROI")
		_expect(Vector2(surface._material.get_shader_parameter("view_size_px")) == Vector2(extent), "palette sampling dimensions differ from surface")
	_expect(compositor.set_view(Vector2(2000,2000), Vector2(extent)), "whole-map view rejected")
	_expect(compositor.camera_origin == Vector2.ZERO, "whole-map camera escaped zero origin")
	_expect(Vector2(compositor._material.get_shader_parameter("view_size")) == Vector2(extent), "view uniform was not synchronized")
	var close_size: Vector2 = Vector2(extent) * 0.5
	_expect(compositor.set_view(Vector2(2000,2000), close_size), "far-corner close-up rejected")
	_expect(compositor.camera_origin == Vector2(extent) - close_size, "far-corner view used the old 640x360 clamp")
	var display: Rect2 = compositor.content_rect()
	for uv: Vector2 in [Vector2(0.1,0.1), Vector2(0.9,0.1), Vector2(0.1,0.9), Vector2(0.9,0.9)]:
		var point: Vector2 = display.position + display.size * uv
		for layer: int in range(4):
			var cell: Vector2 = compositor.screen_to_layer(point, layer)
			_expect(compositor.get_layer_screen_position(cell, layer).distance_to(point) < 0.01, "far-corner layer/input transforms are not inverses")
	var old_origin: Vector2 = compositor.camera_origin
	for invalid_size: Vector2 in [Vector2.ZERO, Vector2(-1,8), Vector2(INF,8), Vector2(extent) + Vector2.ONE]:
		_expect(not compositor.set_view(Vector2.ZERO, invalid_size), "invalid view extent accepted")
		_expect(compositor.camera_origin == old_origin and compositor.view_size == close_size, "invalid view modified camera/extent")
	_expect(not compositor.set_view(Vector2(NAN,0), close_size), "nonfinite camera accepted")
	_expect(not compositor.configure(Vector2i(1025,1024)), "oversized surface setup accepted")
	_expect(compositor.world_size == Vector2(extent) and compositor._surfaces.size() == 4, "failed configure replaced surfaces")
	compositor.queue_free()
	await process_frame

func _definitions(extent: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	for id: String in Runtime.IDS:
		result[id] = PackedInt32Array([extent.x - 6,extent.y - 6,2,2,_material(id)])
	return result

func _material(id: String) -> int:
	return {"play":Cell.PINE_PLANKS, "scripted":Cell.MARBLE, "effects":Cell.STEAM, "background":Cell.PHOSPHOR_PANEL}[id]

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
