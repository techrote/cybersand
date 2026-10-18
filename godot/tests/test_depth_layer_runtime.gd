extends SceneTree

const Runtime = preload("res://scripts/depth/depth_layer_runtime.gd")
const Fixture = preload("res://scripts/depth/depth_lab_fixture.gd")
const Cell = preload("res://scripts/cell_world.gd")

var failures: int = 0
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world unavailable")
	if failures != 0:
		quit(failures)
		return
	var runtime: CyberDepthLayerRuntime = Runtime.new()
	_expect(runtime.reset(Fixture.build()), "fixture reset failed: " + runtime.last_error)
	_expect(runtime.generation() == 1, "reset generation did not advance")
	_expect(runtime.layer_tick("background") == 0, "background started ticking")
	var target: Vector2i = Fixture.features()["reactor_target"]
	var play_before: int = runtime.material_at("play", target)
	var rear_before: int = runtime.material_at("scripted", target)
	_expect(rear_before != Cell.EMPTY, "reactor target is not authored")
	var receipt: Dictionary = runtime.route_event("play", "scripted", "blast", target, 18, Cell.FIRE, runtime.generation())
	_expect(bool(receipt.get("accepted", false)), "play -> rear blast was rejected")
	runtime.advance(0.0, true)
	_expect(runtime.material_at("play", target) == play_before, "rear event mutated play world")
	_expect(runtime.material_at("scripted", target) != rear_before, "rear blast did not change rear world")
	var reverse: Dictionary = runtime.route_event("scripted", "play", "blast", target, 8, Cell.FIRE, runtime.generation())
	_expect(not bool(reverse.get("accepted", true)), "forbidden rear -> play route was accepted")
	_expect(str(reverse.get("error", "")) == "route_not_allowed", "reverse route rejection reason changed")
	var frozen: Dictionary = runtime.paint_disc("background", Vector2i(100, 100), 3, Cell.FIRE)
	_expect(not bool(frozen.get("accepted", true)), "background mutation was accepted")
	var old_generation: int = runtime.generation()
	_expect(runtime.reset(Fixture.build()), "second reset failed")
	var stale: Dictionary = runtime.route_event("play", "scripted", "blast", target, 8, Cell.FIRE, old_generation)
	_expect(str(stale.get("error", "")) == "stale_generation", "stale event was not rejected")
	_expect(runtime.configure_rates({"play": 60.0, "scripted": 20.0, "effects": 30.0, "background": 0.0}), "valid rates rejected")
	_expect(not runtime.configure_rates({"background": 1.0}), "animated background rate was accepted")
	_expect(runtime.set_weather("rain"), "rain mode rejected")
	for _i: int in range(60):
		var step: Dictionary = runtime.advance(1.0 / 60.0, false)
		_expect(bool(step.get("ok", false)), "runtime advance failed")
	var info: Dictionary = runtime.stats()
	var layers: Dictionary = info["layers"]
	_expect(int(layers["play"]["tick"]) == 60, "play plane did not run at 60 Hz")
	_expect(int(layers["scripted"]["tick"]) == 20, "rear plane did not run at 20 Hz")
	_expect(int(layers["effects"]["tick"]) == 30, "effects plane did not run at 30 Hz")
	_expect(int(layers["background"]["tick"]) == 0, "background plane ticked")
	_expect(int(info["weather_emissions"]) > 0, "weather emitted no native material")
	var first_bg: Dictionary = runtime.snapshot_layer("background", true)
	var second_bg: Dictionary = runtime.snapshot_layer("background", false)
	_expect(not PackedByteArray(first_bg.get("cells", PackedByteArray())).is_empty(), "background bake is empty")
	_expect(PackedByteArray(second_bg.get("cells", PackedByteArray())).is_empty(), "cached background republished bytes")
	if failures == 0:
		print("Depth-layer runtime regression passed; ", checks, " checks")
	quit(failures)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error(message)
