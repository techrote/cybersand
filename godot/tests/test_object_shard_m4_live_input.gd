extends SceneTree

const InputFixture = preload("res://tests/support/object_shard_m4_live_input_fixture.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
var input: RefCounted
var f: RefCounted
var observations: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _cell(point: Vector2i) -> int:
	if not f.coherent() or f.host.image==null: return -1
	return roundi(f.host.image.get_pixelv(point).r*255.0)

func _owned_applied_since(first: int) -> Dictionary:
	var results: Array = f.bench.object_shard_m4_port.results
	for index: int in range(first,results.size()):
		var result: Dictionary = results[index]
		var native: Dictionary = result.get("native_receipt",{})
		if result.get("outcome")=="Applied" and not native.get("source_targets",[]).is_empty() \
			and int(native.get("removed_cells",0))>1: return result
	return {}

func _sleeping() -> bool:
	for body: Dictionary in f.diagnostics().get("physics",{}).get("bodies",[]):
		if body.get("sleeping",false): return true
	return false

func _run() -> void:
	input = InputFixture.new(self)
	f = input.f
	if not await f.open("tower"): await _finish(); return
	# Dispatch Escape through the full viewport route: direct Workbench method
	# calls cannot detect accidental fallthrough into Main's pause shortcut.
	input.select_tool(11,1)
	input.press(Vector2(140,330))
	var cancel_serial: int = input.admission_serial()
	var was_paused: bool = f.host.paused
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	escape = escape.duplicate()
	escape.pressed = false
	Input.parse_input_event(escape)
	await process_frame
	f.expect(f.bench._object_shard_pointer_tool==-1,"viewport Escape cancels the active structural preview")
	f.expect(f.host.paused==was_paused,"structural Escape cancellation cannot fall through to the ordinary pause shortcut")
	f.expect(input.admission_serial()==cancel_serial,"Escape does not commit a cancelled slice")
	input.release()
	if not await f.pause(): await _finish(); return
	input.press(Vector2(140,330))
	var original_window: Vector2i = root.size
	root.size = original_window+Vector2i(80,40)
	await process_frame
	await process_frame
	f.expect(f.bench._object_shard_pointer_tool==-1 and input.admission_serial()==cancel_serial,
		"physical Window resize cancels structural intent even when the logical stretched canvas keeps its size")
	input.release()
	root.size = original_window
	await process_frame
	input.select_tool(0,8)
	# This is ordinary Paint's right-button Erase, not the old owned-cell mode.
	var before: int = input.admitted_count()
	input.press(Vector2(140,374),MOUSE_BUTTON_RIGHT)
	if not await f.until(func(): return input.admitted_count()>before,"ordinary eraser admits the first structural support cut"):
		input.release(); await _finish(); return
	input.move(Vector2(140,452))
	if not await f.until(func(): return _cell(Vector2i(140,448))==0,"fast pointer sweep removes the lower support without gaps"):
		print("M4_FAST_SWEEP_DIAGNOSTICS ",JSON.stringify({
			"editing":f.bench.object_shard_edit_diagnostics(),
			"pointer_tool":f.bench._object_shard_pointer_tool,
			"pointer_source_tool":f.bench._object_shard_pointer_source_tool,
			"selected_tool":f.bench._tool.selected,
			"drag_button":f.bench._drag_button,
			"pointer_previous":f.bench._object_shard_pointer_previous,
			"pointer_local":f.bench._object_shard_pointer_local,
			"segment":f.bench._object_shard_segment,
			"wait_reason":f.bench._object_shard_wait_reason,
			"wait_since":f.bench._object_shard_wait_since,
			"pending":f.bench.object_shard_m4_port.pending_count(),
			"port_status":f.bench.object_shard_m4_port.last_status,
			"latest_delivery":f.bench.object_shard_m4_port._latest_edit_delivery,
			"publication":f.runtime().publication,
			"frame":f.runtime().frame,
		}))
		input.release(); await _finish(); return
	input.release()
	if not await input.drain(): await _finish(); return
	var intact: int = 0
	for y: int in range(380,449):
		if _cell(Vector2i(140,y))!=0: intact += 1
	f.expect(intact==0,"swept ordinary eraser cleared the complete sampled support path")
	f.play()
	before = input.admitted_count()
	input.press(Vector2(196,374),MOUSE_BUTTON_RIGHT)
	if not await f.until(func(): return input.admitted_count()>before,"ordinary eraser receives service during continuous simulation"):
		input.release(); await _finish(); return
	input.move(Vector2(196,452))
	if not await f.until(func(): return f.body_count()>0,"ordinary erased support releases an actual physical structure"):
		input.release(); await _finish(); return
	var first_owned_receipt: int = f.bench.object_shard_m4_port.results.size()
	var tick_before: int = f.tick()
	var deadline: int = Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while _owned_applied_since(first_owned_receipt).is_empty() and Time.get_ticks_msec()<deadline:
		if not f.runtime().held_reason.is_empty(): break
		var target: Dictionary = f.moving_target()
		if not target.is_empty(): input.move(Vector2(target.position))
		await process_frame
	var live_receipt: Dictionary = _owned_applied_since(first_owned_receipt)
	f.expect(not live_receipt.is_empty(),"the same held ordinary eraser removes several owned cells during collapse")
	f.expect(f.bench._tool.selected==0,"terrain-to-body transition never switches the selected interaction tool")
	f.expect(f.tick()>tick_before,"native semantic progression continues while live editing receives service")
	observations.collapse_edit = live_receipt
	if not live_receipt.is_empty():
		var native: Dictionary = live_receipt.native_receipt
		f.expect(int(native.changed_owners)==1 and int(native.geometry_rebuilds)<=1,
			"one admitted owner batch removes multiple cells with at most one geometry rebuild")
		f.expect(int(native.requested_cells)<=4096 and native.atomicity=="one_owner",
			"actual native receipt declares bounded per-owner atomicity")
	var release_serial: int = input.admission_serial()
	input.release(true)
	for callback: int in range(16): await process_frame
	f.expect(input.admission_serial()==release_serial,"off-canvas release prevents every later stroke admission")
	if not await f.pause(): await _finish(); return
	f.validate_physics()
	await f.validate_quantity_ledger()
	# Let a small real body settle naturally, then edit it without conversion.
	if not await input.install_panel("sleeping"): await _finish(); return
	input.select_tool(10,5)
	if not await input.tap(Vector2(164,457)): await _finish(); return
	f.play()
	if not await f.until(func(): return f.body_count()==1,"a single plank detaches through the unified eraser") \
		or not await f.until(_sleeping,"actual Rapier plank falls and sleeps naturally"):
		await _finish(); return
	if not await f.pause(): await _finish(); return
	var sleeping_count: int = f.material_count(7)
	var sleeping_target: Dictionary = input.source_target(Vector2i(152,442))
	if not f.expect(not sleeping_target.is_empty(),"sleeping body exposes a current authoritative visible target"):
		await _finish(); return
	input.select_tool(10,3)
	if not await input.tap(Vector2(sleeping_target.position)): await _finish(); return
	f.expect(f.material_count(7)<sleeping_count-1,"sleeping material remains eligible for a multi-cell structural brush")
	f.expect(not _sleeping(),"acknowledged geometry change wakes the surviving actual body")
	f.validate_physics()
	# Camera-correct targeting, including a changed aspect ratio.
	f.bench._camera.select(0)
	f.bench._set_view(Vector2(112,400),Vector2i(192,96))
	root.size = Vector2i(1120,760)
	await process_frame
	await process_frame
	var target: Dictionary = f.moving_target()
	if not f.expect(not target.is_empty(),"fresh zoomed target remains visible"):
		await _finish(); return
	var mapped: Vector2i = Vector2i(f.host.camera_origin.floor())+f.host.view_pixel_from_local_point(input.local(Vector2(target.position)))
	f.expect(mapped==target.position,"preview/input transformation round-trips after pan, zoom and resize")
	var before_zoom: int = f.material_count(7)
	input.select_tool(7,9)
	if not await input.tap(Vector2(target.position)): await _finish(); return
	f.expect(f.material_count(7)==before_zoom-1,"precision cut remains one exact cell despite the stored brush radius")
	# A held fresh point is invalidated by scene replacement, never replayed.
	target = f.moving_target()
	if not target.is_empty():
		input.select_tool(10,4)
		input.press(Vector2(target.position))
		f.expect(f.bench.restore_start(),"scene replacement can retire a held editing gesture")
		if await f.until(f.installed,"fresh authored owner replaces pending input"):
			var replacement_serial: int = input.admission_serial()
			for callback: int in range(12): await process_frame
			f.expect(input.admission_serial()==replacement_serial,"retired held intent does not submit into the replacement scene")
			f.expect(f.runtime().held_reason.is_empty(),"replacement does not inherit a stale editing hold")
		input.release(true)
	observations.edit_diagnostics = f.bench.object_shard_edit_diagnostics()
	f.expect(int(observations.edit_diagnostics.get("max_events",0))<=256,
		"always-on editing history has an explicit bounded retention limit")
	await _finish()

func _finish() -> void:
	if input!=null and input.button!=0: input.release(true)
	if f!=null:
		if f.host!=null:
			observations.final = f.diagnostics()
			observations.display = f.display_witness()
			observations.pointer_events = input.events
			f.validate_display()
		await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-live-input-v1","checks":f.checks,
		"failures":f.failures,"observations":observations,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"actual ordinary native Workbench/shared Rapier and injected production mouse routes; renderer callbacks are not physical monitor proof"}))
	quit(0 if f.failures.is_empty() else 1)
