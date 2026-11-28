extends SceneTree

# Ordinary launch control. No opt-in argument, attached material owner or direct
# erase API is used; real mouse events traverse the mounted canvas signal.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var host: Control
var bench: Control
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("M4_DISABLED_INPUT: "+label)
	return value

func _until(predicate: Callable, label: String) -> bool:
	var deadline: int = Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await process_frame
	return _check(predicate.call(),label)

func _installed() -> bool:
	return host.shared_workbench!=null and not host.shared_workbench.applied.is_empty() \
		and not host.shared_workbench.busy() and host.pending_microscenario_apply.is_empty() \
		and host.image!=null

func _local(position: Vector2i) -> Vector2:
	var area: Rect2 = host.view_content_rect()
	return area.position+(Vector2(position)-host.camera_origin.floor()+Vector2(0.5,0.5)) \
		*area.size/Vector2(host.current_view_size)

func _cell(position: Vector2i) -> int:
	if host.image==null or not Rect2i(Vector2i.ZERO,host.image.get_size()).has_point(position): return -1
	return roundi(host.image.get_pixelv(position).r*255.0)

func _run() -> void:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	if not await _until(_installed,"ordinary Workbench installed without Structures flag"):
		await _finish(); return
	bench = host.shared_workbench
	_check(not bench.object_shard_m4_port.enabled and not host.object_shard_m4_runtime.enabled,
		"ordinary launch has no enabled structural editing authority")
	var setup: Dictionary = Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))
	setup.edits = [[0,464,512,48,1],[236,236,40,40,1]]
	if not _check(bench.apply(setup),"ordinary authored Wall control admitted") \
		or not await _until(_installed,"ordinary Wall control installed"):
		await _finish(); return
	bench.set_camera(2)
	await process_frame
	await process_frame
	_check(_cell(Vector2i(256,256))==1,"ordinary target starts as actual Wall material")
	bench._tool.select(0)
	bench._brush.value = 4
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = _local(Vector2i(256,256))
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
		host.world_view.gui_input.emit(event)
		await process_frame
	await _until(func(): return _cell(Vector2i(256,256))==0,"ordinary right-button eraser applies through production input")
	_check(_cell(Vector2i(270,256))==1,"ordinary erase preserves material outside its radius")
	_check(not bench.object_shard_m4_port.enabled and not host.object_shard_m4_runtime.enabled,
		"ordinary pointer use does not silently enable Structures")
	_check(host.object_shard_m4_runtime.bridge.bodies.is_empty(),"ordinary erase creates no hidden material bodies")
	await _finish()

func _finish() -> void:
	if host!=null:
		host.queue_free()
		await process_frame
		await process_frame
	print(JSON.stringify({"schema":"objectshard-m4-disabled-input-v1","checks":checks,"failures":failures,
		"scope":"actual ordinary native Workbench with Structures disabled and injected production canvas input"}))
	quit(0 if failures.is_empty() else 1)
