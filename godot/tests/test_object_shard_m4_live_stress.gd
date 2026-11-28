extends SceneTree

const InputFixture = preload("res://tests/support/object_shard_m4_live_input_fixture.gd")
var input: RefCounted
var f: RefCounted
var observations: Dictionary = {}
var cohorts: Dictionary = {}
var observe_population: bool = false
var previous_usec: int = 0
var previous_tick: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _population() -> Dictionary:
	var owned: int = 0
	var awake: int = 0
	for shard: Dictionary in f.frame().get("shards",[]):
		if not shard.get("has_body",false): continue
		owned += 1
		if not shard.get("sleeping",true): awake += 1
	return {"owned":owned,"awake":awake}

func _observe() -> void:
	if not observe_population or f==null or f.host==null: return
	var now: int = Time.get_ticks_usec()
	var counts: Dictionary = _population()
	var key: String = "%d/%d" % [counts.owned,counts.awake]
	if not cohorts.has(key): cohorts[key] = {"owned":counts.owned,"awake":counts.awake,"callbacks":0,"wall_usec":0,"native_ticks":0}
	cohorts[key].callbacks += 1
	cohorts[key].wall_usec += maxi(0,now-previous_usec)
	cohorts[key].native_ticks += maxi(0,f.tick()-previous_tick)
	previous_usec = now
	previous_tick = f.tick()

func _target(owner: int = 0) -> Dictionary:
	if not f.coherent(): return {}
	for shard: Dictionary in f.runtime().publication.get("shards",[]):
		if not shard.get("owns_inventory",false) or (owner!=0 and int(shard.id)!=owner): continue
		var transform := Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
		for index: int in range(shard.materials.size()):
			if int(shard.roles[index])!=1 or int(shard.materials[index])!=7: continue
			var local := Vector2(index%int(shard.width)+0.5,floorf(float(index)/int(shard.width))+0.5)
			var target: Dictionary = f.runtime().visible_target(Vector2i((transform*local).floor()))
			if int(target.get("owner",-1))==int(shard.id) and int(target.get("cell",-1))==index: return target
	return {}

func _last_native() -> Dictionary:
	var results: Array = f.bench.object_shard_m4_port.results
	return results.back().get("native_receipt",{}).duplicate(true) if not results.is_empty() else {}

func _capture() -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	f.expect(root.get_texture().get_image().save_png(output.path_join("eight-owner-live-edit.png"))==OK,
		"actual rendered eight-owner editing construction retained")

func _run() -> void:
	input = InputFixture.new(self)
	f = input.f
	if not await f.open("stress"): await _finish(); return
	# One production slice cuts all eight ordinary stems in one terrain owner
	# transaction. The native component discovery subsequently owns each body.
	input.select_tool(11,1)
	var admitted: int = input.admitted_count()
	input.press(Vector2(60,420))
	input.move(Vector2(455,420))
	input.release()
	if not await f.until(func(): return input.admitted_count()>admitted,"one actual slice admits the eight-support terrain cut") \
		or not await input.drain(): await _finish(); return
	var supports: Dictionary = _last_native()
	f.expect(supports.get("domain")=="terrain" and int(supports.get("removed_cells",0))==48,
		"thin shared-owner slice removes exactly three rows from eight two-cell support stems")
	observations.support_slice = supports
	f.play()
	if not await f.until(func(): return f.body_count()==8,"eight real material bodies detach through ordinary discovery"):
		await _finish(); return
	observe_population = true
	previous_usec = Time.get_ticks_usec()
	previous_tick = f.tick()
	process_frame.connect(_observe)
	if not await f.advance(180,"eight-owner construction progresses for 180 native ticks before editing"):
		await _finish(); return
	f.expect(f.body_count()==8,"prolonged progression retains the intended eight owned bodies")
	observations.before_edits = {"tick":f.tick(),"population":_population()}
	await _capture()
	var owners: Array[int] = []
	for shard: Dictionary in f.frame().get("shards",[]):
		if shard.get("has_body",false): owners.append(int(shard.id))
	var small: Array[Dictionary] = []
	var editing_start: int = f.tick()
	# Each original owner receives a real fresh input event after prolonged
	# progression. Geometry and state may have changed before the next owner.
	for owner: int in owners:
		var target: Dictionary = _target(owner)
		if not f.expect(not target.is_empty(),"settled or moving owner remains visibly targetable after prior mutations"):
			await _finish(); return
		input.select_tool(10,1)
		var started: int = Time.get_ticks_usec()
		if not await input.tap(Vector2(target.position)): await _finish(); return
		var receipt: Dictionary = _last_native()
		small.append({"owner":owner,"elapsed_usec":Time.get_ticks_usec()-started,"receipt":receipt})
		if not f.expect(receipt.get("ok",false) and int(receipt.get("removed_cells",0))>0 \
			and int(receipt.get("geometry_rebuilds",-1))==1,
			"live small brush applies once to its authoritative owner with one reconstruction"):
			await _finish(); return
		if not await f.advance(4,"native progression remains available between repeated owner edits"):
			await _finish(); return
	observations.small_edits = small
	f.expect(f.tick()>editing_start and f.body_count()>=7,
		"seven or more owners retain semantic progression through repeated real brush edits")
	# The maximum UI radius and a fast long sweep exercise bounded capsule
	# decomposition and per-owner service. Release stops every unadmitted tail.
	var target: Dictionary = _target()
	if not f.expect(not target.is_empty(),"maximum-radius sweep starts on current owned material"):
		await _finish(); return
	input.select_tool(10,24)
	admitted = input.admitted_count()
	var first_result: int = f.bench.object_shard_m4_port.results.size()
	input.press(Vector2(target.position))
	if not await f.until(func(): return input.admitted_count()>admitted,"maximum radius receives bounded live service"):
		input.release(true); await _finish(); return
	input.move(Vector2(476,int(target.position.y)))
	if not await f.until(func(): return input.admitted_count()>=admitted+2,"rapid wide sweep receives another fresh owner service opportunity"):
		input.release(true); await _finish(); return
	input.release(true)
	var released_serial: int = input.admission_serial()
	if not await input.drain(): await _finish(); return
	for callback: int in range(12): await process_frame
	f.expect(input.admission_serial()==released_serial,"maximum-radius release cancels the unadmitted sweep tail")
	var wide: Array[Dictionary] = []
	var wide_changed: int = 0
	for index: int in range(first_result,f.bench.object_shard_m4_port.results.size()):
		var terminal: Dictionary = f.bench.object_shard_m4_port.results[index]
		var receipt: Dictionary = terminal.get("native_receipt",{})
		wide.append({"outcome":terminal.get("outcome","missing"),"receipt":receipt.duplicate(true)})
		f.expect(terminal.get("outcome")=="Applied" and receipt.get("ok",false),
			"maximum-radius service is positively applied, not merely admitted")
		f.expect(int(receipt.get("requested_cells",0))<=4096 and int(receipt.get("geometry_rebuilds",0))<=1,
			"every maximum-radius native transaction respects cell and reconstruction bounds")
		wide_changed += int(receipt.get("changed_cells",0))
	f.expect(wide_changed>1,"maximum-radius sweep changes multiple authoritative material cells")
	observations.maximum_radius = wide
	# Rapid mode changes terminate future work even when an earlier transaction
	# was already admitted and legitimately completes after the switch.
	target = _target()
	if not f.expect(not target.is_empty(),"rapid-tool cancellation retains a visible survivor"):
		await _finish(); return
	input.select_tool(10,2)
	input.press(Vector2(target.position))
	for mode: int in [12,13,11,7,0]: input.select_tool(mode,2)
	var switched_serial: int = input.admission_serial()
	for callback: int in range(12): await process_frame
	f.expect(input.admission_serial()==switched_serial and f.bench._object_shard_pointer_tool==-1,
		"rapid tool switches never replay the previous held brush")
	input.release(true)
	if not await f.pause(): await _finish(); return
	f.validate_physics()
	await f.validate_quantity_ledger()
	# Pause and resume cancel a held gesture; a new press is required afterward.
	target = _target()
	if not f.expect(not target.is_empty(),"pause/restart test starts on surviving structural material"):
		await _finish(); return
	input.select_tool(10,1)
	input.press(Vector2(target.position))
	f.play()
	var resumed_serial: int = input.admission_serial()
	if not await f.advance(12,"Pause-to-Play progresses after cancelling prior pointer intent"):
		input.release(true); await _finish(); return
	f.expect(input.admission_serial()==resumed_serial,"pause/resume admits no stale held-pointer replay")
	input.release(true)
	observations.after_edits = {"tick":f.tick(),"population":_population(),"editing":f.bench.object_shard_edit_diagnostics()}
	f.expect(f.runtime().held_reason.is_empty() and not f.host.simulation_worker.has_failed(),
		"sustained editing retains a healthy native/physical owner")
	observe_population = false # New owner cohorts belong to a different session.
	target = _target()
	if not target.is_empty():
		input.press(Vector2(target.position))
		f.expect(f.bench.restore_start(),"fresh scene replacement retires pending stress input")
		if await f.until(f.installed,"replacement authored scene installs after stress"):
			var replaced_serial: int = input.admission_serial()
			for callback: int in range(12): await process_frame
			f.expect(input.admission_serial()==replaced_serial and f.bench._object_shard_pointer_tool==-1,
				"no old stress pointer survives owner replacement")
		input.release(true)
	await _finish()

func _finish() -> void:
	observe_population = false
	if process_frame.is_connected(_observe): process_frame.disconnect(_observe)
	if input!=null and input.button!=0: input.release(true)
	if f!=null:
		if f.host!=null:
			observations.final = f.diagnostics()
			observations.editing = f.bench.object_shard_edit_diagnostics()
			observations.pointer_events = input.events
			observations.cohorts = cohorts
			f.validate_display()
		await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-live-stress-v1","checks":f.checks,"failures":f.failures,
		"observations":observations,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"actual production pointer path, native progression and shared Rapier; owned and awake cohorts are separate; test callback timings are not owner hardware benchmarks"}))
	quit(0 if f.failures.is_empty() else 1)
