extends SceneTree

const InputFixture = preload("res://tests/support/object_shard_m4_live_input_fixture.gd")
var input: RefCounted
var f: RefCounted
var observations: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _last_native() -> Dictionary:
	var results: Array = f.bench.object_shard_m4_port.results
	return results.back().get("native_receipt",{}).duplicate(true) if not results.is_empty() else {}

func _burning() -> Dictionary:
	var cells: Dictionary = {}
	for shard: Dictionary in f.runtime().publication.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		for cell: int in range(shard.materials.size()):
			if int(shard.materials[cell])==7 and int(shard.states_b[cell])>0:
				cells[Vector2i(int(shard.id),cell)] = int(shard.states_b[cell])
	return cells

func _sleeping() -> bool:
	for body: Dictionary in f.diagnostics().get("physics",{}).get("bodies",[]):
		if body.get("sleeping",false): return true
	return false

func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	f.expect(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,
		label+": actual rendered tool result retained")

func _detach_panel(kind: String = "panel") -> bool:
	if not await input.install_panel(kind): return false
	input.select_tool(10,5 if kind!="panel" else 8)
	if not await input.tap(Vector2(146,457) if kind=="tiny" else Vector2(164,457) if kind=="sleeping" else Vector2(172,452)):
		return false
	f.play()
	if not await f.until(func(): return f.body_count()==1,"authored "+kind+" becomes one real detached material owner"): return false
	return await f.pause()

func _weather_once() -> Dictionary:
	if not await _detach_panel(): return {}
	input.select_tool(12,8)
	f.bench._erosion_density.value = 35
	f.bench._erosion_seed.value = 91999
	var before: Dictionary = input.owned_material()
	var target: Dictionary = input.source_target(Vector2i(172,416))
	if not f.expect(not target.is_empty(),"weathering starts from actual captured panel material"): return {}
	if not await input.tap(Vector2(target.position)): return {}
	var after: Dictionary = input.owned_material()
	var removed: Array[String] = []
	for key: String in before:
		if not after.has(key): removed.append(key)
	removed.sort()
	var receipt: Dictionary = _last_native()
	f.expect(removed.size()>0 and removed.size()<197,"weathering creates sparse real holes within the radius-eight disc")
	f.expect(int(receipt.get("removed_cells",-1))==removed.size(),"weathering receipt closes against independent captured-material census")
	f.expect(int(receipt.get("seed",-1))==91999 and int(receipt.get("probability_ppm",-1))==350000,
		"native stochastic selection retains the exact seed and density")
	f.validate_physics()
	await _capture("weathered-panel")
	return {"removed":removed,"receipt":receipt,"surviving_material":after.size()}

func _run() -> void:
	input = InputFixture.new(self)
	f = input.f
	if not await f.open("perforated") or not await _detach_panel(): await _finish(); return
	var target: Dictionary = input.source_target(Vector2i(172,416))
	if not f.expect(not target.is_empty(),"drill center has an actual structural target"):
		await _finish(); return
	var wood_before: int = f.material_count(7)
	input.select_tool(13,4)
	if not await input.tap(Vector2(target.position)): await _finish(); return
	var drilled: Dictionary = _last_native()
	f.expect(int(drilled.get("removed_cells",0))>1 and int(drilled.get("removed_cells",0))<=49,
		"one deliberate drill placement removes a circular multi-cell opening")
	f.expect(f.material_count(7)==wood_before-int(drilled.get("removed_cells",0)),
		"drilled material is removed from authoritative inventory exactly once")
	f.expect(int(f.owned_cell_state(int(target.owner),int(target.cell)).get("material",-1))==0,
		"drill center is actual Empty owned material")
	f.expect(int(drilled.get("geometry_rebuilds",-1))==1,"one drill rebuilds owner geometry once")
	f.validate_physics()
	observations.drill = drilled
	await _capture("drilled-panel")
	# Let the panel settle through prolonged ordinary simulation, then commit a
	# previewed slice during a real physical interval. Release is one-shot intent.
	f.play()
	if not await f.until(_sleeping,"drilled panel falls and settles before the live slice"):
		await _finish(); return
	var start: Dictionary = input.source_target(Vector2i(140,416))
	var end: Dictionary = input.source_target(Vector2i(203,416))
	if not f.expect(not start.is_empty() and not end.is_empty(),"substantial slice endpoints lie on current displayed panel material"):
		await _finish(); return
	input.select_tool(11,1)
	var admitted_before: int = input.admitted_count()
	input.press(Vector2(start.position))
	input.move(Vector2(end.position))
	for callback: int in range(4): await process_frame
	f.expect(input.admitted_count()==admitted_before,"slice drag previews without mutating before release")
	observations.slice_release_transaction = await input.release_during_physical_transaction()
	if observations.slice_release_transaction.is_empty():
		input.release(true); await _finish(); return
	var release_usec: int = int(observations.slice_release_transaction.release_usec)
	if not await f.until(func(): return input.admitted_count()>admitted_before,
		"committed live slice receives a safe fresh-witness admission after release"):
		await _finish(); return
	observations.slice_admission_usec = Time.get_ticks_usec()-release_usec
	if not await f.pause(): await _finish(); return
	var sliced: Dictionary = _last_native()
	f.expect(int(sliced.get("removed_cells",0))>=100,"slice removes a substantial continuous structural member")
	f.expect(int(sliced.get("islands_after",0))>int(sliced.get("islands_before",0)),
		"native connectivity observes the wall split into separate islands")
	f.play()
	if not await f.until(func(): return f.body_count()>=2,"slice islands become separate actual physical bodies"):
		await _finish(); return
	await f.advance(30,"new physical islands continue native progression after slice")
	if not await f.pause(): await _finish(); return
	f.validate_physics()
	await f.validate_quantity_ledger()
	observations.slice = sliced
	await _capture("sliced-panel")
	observations.weather_first = await _weather_once()
	observations.weather_replay = await _weather_once()
	f.expect(not observations.weather_first.is_empty() and observations.weather_first.get("removed") == observations.weather_replay.get("removed"),
		"fresh authored replay with the same seed reproduces the exact removed material coordinates")
	# Area ignition is authoritative and never resets already-burning countdowns.
	if not await _detach_panel(): await _finish(); return
	target = input.source_target(Vector2i(148,400))
	if not f.expect(not target.is_empty(),"area ignition has a current owned Wood target"):
		await _finish(); return
	input.select_tool(8,4)
	if not await input.tap(Vector2(target.position)): await _finish(); return
	f.expect(_burning().size()>1,"area ignition starts multiple native Wood countdowns")
	observations.ignition = _last_native()
	f.play()
	if not await f.advance(60,"native combustion advances before repeated area ignition") or not await f.pause():
		await _finish(); return
	var burning_before: Dictionary = _burning()
	target = input.source_target(Vector2i(148,400))
	if not f.expect(not target.is_empty() and not burning_before.is_empty(),"ignited material persists with advancing state"):
		await _finish(); return
	if not await input.tap(Vector2(target.position)): await _finish(); return
	var burning_after: Dictionary = _burning()
	var resets: int = 0
	for key: Vector2i in burning_before:
		if burning_after.has(key) and int(burning_after[key])>int(burning_before[key]): resets += 1
	f.expect(resets==0,"repeated area ignition never restarts an existing native combustion countdown")
	observations.reignition = _last_native()
	await _capture("area-ignition")
	# Complete removal exercises geometry retirement and the zero-inventory body.
	if not await _detach_panel("tiny"): await _finish(); return
	target = input.source_target(Vector2i(146,446))
	if not f.expect(not target.is_empty(),"small complete-removal body has a current target"):
		await _finish(); return
	wood_before = f.material_count(7)
	var owned_before: Dictionary = input.owned_material()
	var owned_by_material: Dictionary = {}
	for material: int in owned_before.values():
		owned_by_material[material] = int(owned_by_material.get(material,0))+1
	input.select_tool(13,12)
	if not await input.tap(Vector2(target.position)): await _finish(); return
	if not await f.until(func(): return f.body_count()==0,"last owned material removal retires its actual physical body"):
		await _finish(); return
	f.expect(f.material_count(7)==0 and input.owned_material().is_empty() \
		and int(_last_native().get("removed_cells",0))==owned_before.size(),
		"complete body erasure closes material accounting with no orphan ownership")
	f.expect(int(owned_by_material.get(7,0))==wood_before,
		"Wood subtotal and the separately retained support-cap materials reconcile before complete removal")
	observations.complete_removal_before = {"wood":wood_before,"owned_cells":owned_before.size(),"by_material":owned_by_material}
	observations.complete_removal = _last_native()
	await _finish()

func _finish() -> void:
	if input!=null and input.button!=0: input.release(true)
	if f!=null:
		if f.host!=null:
			observations.final = f.diagnostics()
			observations.pointer_events = input.events
			observations.editing = f.bench.object_shard_edit_diagnostics()
			f.validate_display()
		await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-live-tools-v1","checks":f.checks,"failures":f.failures,
		"observations":observations,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"actual ordinary native/shared Rapier and production pointer tools; deterministic replay is authored-start reconstruction, not a live checkpoint"}))
	quit(0 if f.failures.is_empty() else 1)
