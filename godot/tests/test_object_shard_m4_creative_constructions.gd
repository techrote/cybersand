extends SceneTree

const InputFixture = preload("res://tests/support/object_shard_m4_live_input_fixture.gd")
var input: RefCounted
var f: RefCounted
var observations: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _cell(point: Vector2i) -> int:
	return roundi(f.host.image.get_pixelv(point).r*255.0) if f.coherent() and f.host.image!=null else -1

func _load(id: String) -> bool:
	if f.host==null: return await f.open(id)
	if not await f.pause(): return false
	if not f.expect(f.bench.load_object_shard_scene(id),"new authored "+id+" demonstration selected"): return false
	if not await f.until(f.installed,"new authored demonstration installed through ordinary Workbench"): return false
	f.bench.set_camera(2)
	f.play()
	if not await f.until(func(): return f.runtime().owns_terrain(),"new demonstration attaches to the ordinary native owner"): return false
	return await f.pause()

func _cut_stem(x: int, top: int) -> bool:
	input.select_tool(10,4)
	var admitted: int = input.admitted_count()
	input.press(Vector2(x,top+5))
	if not await f.until(func(): return input.admitted_count()>admitted,"demonstration support brush admitted through production mouse input"):
		input.release(true); return false
	input.move(Vector2(x,459))
	if not await f.until(func(): return _cell(Vector2i(x,459))==0,"continuous production brush removes the complete lower support"):
		input.release(true); return false
	input.release()
	return await input.drain()

func _capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	f.expect(root.get_texture().get_image().save_png(output.path_join("construction-"+id+".png"))==OK,
		id+": actual rendered native construction retained")

func _run() -> void:
	input = InputFixture.new(self)
	f = input.f
	for id: String in ["perforated","weathered","editing_yard"]:
		if not await _load(id): await _finish(); return
		var wood_before: int = f.material_count(7)
		var brick_before: int = f.material_count(43)
		var top: int = 344 if id=="editing_yard" else 364
		for x: int in [144,212]:
			if not await _cut_stem(x,top): await _finish(); return
		f.play()
		if not await f.until(func(): return f.body_count()>=1,"new "+id+" construction becomes a real physical body") \
			or not await f.advance(45,"new demonstration continues real native and physical progression") \
			or not await f.pause(): await _finish(); return
		f.expect(f.material_count(7)==wood_before and f.material_count(43)==brick_before,
			id+": support removal preserves all Wood and Brick through actual ownership transfer")
		f.validate_physics()
		var target: Dictionary = f.moving_target()
		if not f.expect(not target.is_empty(),id+": detached demonstration remains visibly editable"):
			await _finish(); return
		input.select_tool(10,2)
		if not await input.tap(Vector2(target.position)): await _finish(); return
		var result: Dictionary = f.bench.object_shard_m4_port.results.back()
		var native: Dictionary = result.get("native_receipt",{})
		f.expect(result.get("outcome")=="Applied" and int(native.get("removed_cells",0))>1 \
			and int(native.get("geometry_rebuilds",0))==1,
			id+": fresh native batch changes several owned cells with one coherent reconstruction")
		var row: Dictionary = {"owned_edit":native.duplicate(true),"body_count":f.body_count(),
			"wood_before":wood_before,"brick_before":brick_before}
		if id=="editing_yard":
			var ordinary := Vector2i(258,440)
			var groups: Dictionary = f.runtime().visible_edit_groups([ordinary])
			f.expect(_cell(ordinary)==7 and groups.has(0) and f.body_count()>0,
				"editing yard simultaneously retains rooted ordinary terrain and detached material")
			if not await input.tap(Vector2(ordinary)): await _finish(); return
			result = f.bench.object_shard_m4_port.results.back()
			native = result.get("native_receipt",{})
			f.expect(_cell(ordinary)==0 and result.get("outcome")=="Applied" and native.get("domain")=="terrain",
				"the same selected eraser edits the rooted wing after editing the detached panel")
			row.ordinary_edit = native.duplicate(true)
		f.validate_physics()
		row.inventory = await f.validate_quantity_ledger()
		row.editing = f.bench.object_shard_edit_diagnostics()
		observations[id] = row
		await _capture(id)
	await _finish()

func _finish() -> void:
	if input!=null and input.button!=0: input.release(true)
	if f!=null:
		if f.host!=null:
			observations.final = f.diagnostics()
			observations.pointer_events = input.events
			f.validate_display()
		await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-creative-constructions-v1","checks":f.checks,"failures":f.failures,
		"observations":observations,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"new authored demonstrations reconstructed in the actual native Workbench/shared Rapier and edited through production mouse events; no restored live body checkpoint"}))
	quit(0 if f.failures.is_empty() else 1)
