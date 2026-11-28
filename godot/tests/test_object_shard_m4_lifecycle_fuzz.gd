extends SceneTree

# Bounded, reproducible stateful operation fuzzing on one actual ordinary Main.
# Every operation uses the mounted Workbench/native worker and existing Rapier
# space. No generated pose, replacement World pointer, or invented receipt is
# supplied by this fixture.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const SEEDS := [5059585,5059586,5059587]
const BASE_WOOD: int = 192
const BASE_BRICK: int = 96
var f: RefCounted
var expected_wood: int = BASE_WOOD
var expected_brick: int = BASE_BRICK
var old_target: Dictionary = {}
var old_observation: Dictionary = {}
var trace: Array[Dictionary] = []
var seed_records: Array[Dictionary] = []
var worker_identity: int = 0
var native_identity: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _stable() -> bool:
	return f.installed() and f.host.paused and f.runtime().physics_ready() and f.coherent() \
		and f.runtime().publication.get("publication_sequence")==f.frame().get("publication_sequence") \
		and f.bench.object_shard_m4_port.pending_count()==0 \
		and not f.host.simulation_worker.paint_state().get("legacy_busy",true) \
		and f.host.simulation_worker.object_shard_owner_frame(int(f.frame().get("publication_sequence",-1))).is_empty()

func _set_tool(index: int) -> void:
	f.bench._tool.select(index)
	f.bench._tool.item_selected.emit(index)

func _setup_seed(seed: int) -> bool:
	await f.pause()
	_set_tool(0)
	var authored: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
	authored.edits = [[0,464,512,48,1],[0,0,3,512,1],[509,0,3,512,1],
		[136,408,24,4,43],[136,412,24,8,7],[146,420,2,44,1]]
	authored.actors = [Setup.instance(Setup.BARREL,1,Vector2(408,432))]
	authored.next_id = 2
	authored.selected = 1
	if not f.expect(f.bench.apply(authored),"seed %d authored native construction admitted"%seed): return false
	if not await f.until(f.installed,"seed authored World installed"): return false
	f.bench.set_camera(2)
	f.play()
	if not await f.until(func(): return f.runtime().owns_terrain(),"seed owner and actual Main physics bound"): return false
	await f.pause()
	f.bench._brush.value = 3
	if not f.expect(f.bench.paint(Vector2i(147,424),0),"seed ordinary Erase cuts the genuine support"): return false
	f.play()
	if not await f.until(func(): return f.body_count()>0,"seed construction becomes a native-owned Rapier body"): return false
	await f.pause()
	if not await f.until(_stable,"seed copied World and moving publication settle together"): return false
	expected_wood = BASE_WOOD
	expected_brick = BASE_BRICK
	old_target.clear()
	old_observation.clear()
	return _inventory("seed baseline")

func _inventory(label: String) -> bool:
	var valid: bool = f.expect(f.whole_canvas_coherent(),label+" has the complete coherent native cell image")
	valid = f.expect(f.material_count(7)==expected_wood,label+" conserves independently counted World+owned Wood") and valid
	valid = f.expect(f.material_count(43)==expected_brick,label+" conserves independently counted World+owned Brick") and valid
	valid = f.expect(f.runtime().held_reason.is_empty() and not f.host.simulation_worker.has_failed(),
		label+" leaves no held or failed native owner") and valid
	valid = f.expect(f.host.simulation_worker.get_instance_id()==worker_identity \
		and int(f.runtime().capabilities.get("native_instance_id",0))==native_identity,
		label+" retains the same ordinary worker and native facade identity") and valid
	valid = f.expect(f.runtime().native_pose_echo_checks==f.runtime().native_pose_acknowledgements,
		label+" has an exact native pose echo for every acknowledged actual body segment") and valid
	return valid

func _world_cell(point: Vector2i) -> int:
	if not f.whole_canvas_coherent(): return -1
	var bytes: PackedByteArray = f.host.image.get_data()
	var channels: int = bytes.size()/(512*512)
	return int(bytes[(point.y*512+point.x)*channels]) if channels in [1,2,4] else -1

func _plan(seed: int) -> Array[String]:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var tail: Array[String] = []
	var actions: Array[String] = ["run_pause","step","tool","paint","erase","stale","restore"]
	for i: int in range(22): tail.append(actions[i%actions.size()])
	for i: int in range(tail.size()-1,0,-1):
		var other: int = random.randi_range(0,i)
		var item: String = tail[i]
		tail[i] = tail[other]
		tail[other] = item
	var plan: Array[String] = ["erase","stale"]
	plan.append_array(tail)
	return plan

func _erase(row: Dictionary) -> bool:
	_set_tool(f.bench.CUT_MOVING_TOOL)
	var target: Dictionary = f.moving_target(7)
	if not f.expect(not target.is_empty(),"fuzz erase has an exact displayed owned Wood cell"): return false
	old_target = target.duplicate(true)
	old_observation = f.runtime().visible_observation()
	var request: Dictionary = f.bench.object_shard_m4_action(target.position,"erase",old_observation,target)
	row.request = request
	if not f.expect(request.get("ok",false),"fuzz moving erase admitted by the ordinary native worker"): return false
	if not await f.until(_stable,"fuzz erase receives native mutation and actual geometry receipts"): return false
	var terminal: Dictionary = f.bench.object_shard_m4_port.results.back().duplicate(true)
	row.receipt = terminal
	if not f.expect(terminal.get("outcome")=="Applied" and terminal.get("native_receipt",{}).get("source_target",{})==target,
		"fuzz erase debits the exact native source witness"): return false
	expected_wood -= 1
	return true

func _stale(row: Dictionary) -> bool:
	if not f.expect(not old_target.is_empty(),"fuzz stale replay retains a genuine earlier source witness"): return false
	var before: int = f.material_count(7)
	var result: Dictionary = f.bench.object_shard_m4_action(old_target.position,"erase",old_observation,old_target)
	row.request = result
	if result.get("ok",false):
		if not await f.until(_stable,"fuzz stale replay receives its actual native refusal"): return false
		row.receipt = f.bench.object_shard_m4_port.results.back().duplicate(true)
		if not f.expect(row.receipt.get("outcome")!="Applied","fuzz native owner refuses a stale moving witness"): return false
	else:
		row.receipt = result
		if not f.expect(not result.get("may_have_executed",false),"fuzz stale observation is explicitly refused before admission"): return false
	return f.expect(f.material_count(7)==before,"stale replay cannot debit or duplicate material")

func _action(kind: String, random: RandomNumberGenerator, row: Dictionary) -> bool:
	match kind:
		"run_pause":
			var before: int = f.runtime().native_pose_echo_checks
			if not f.play(): return false
			if not await f.advance(random.randi_range(2,5),"fuzz Resume advances real native chemistry and physical intervals"): return false
			await f.pause()
			return f.expect(f.runtime().native_pose_echo_checks>before,"fuzz Resume delivered genuine new native pose echoes")
		"step":
			var tick: int = f.tick()
			var intervals: int = f.runtime().physical_intervals
			var actor_tick: int = f.host.physical_actor_session.tick
			if not f.expect(f.bench.step_once(),"fuzz paused Step admitted"): return false
			if not await f.until(func(): return _stable() and not f.bench.step_pending,"fuzz Step finishes its one owner interval"): return false
			return f.expect(f.tick()==tick+1 and f.runtime().physical_intervals==intervals+1 \
				and f.host.physical_actor_session.tick==actor_tick+1,"fuzz Step advances native, Rapier and actor exactly once")
		"tool":
			var index: int = [0, f.bench.CUT_MOVING_TOOL, f.bench.IGNITE_MOVING_TOOL, f.bench.SETTLE_MOVING_TOOL][random.randi_range(0,3)]
			_set_tool(index)
			row.selected_tool = index
			return f.expect(f.bench._object_shard_pointer_tool==-1 and f.bench._brush.editable==(index==0),
				"fuzz tool switch leaves no held pointer intent and advertises the correct radius")
		"paint":
			_set_tool(0)
			f.bench._brush.value = 2
			var point := Vector2i(random.randi_range(300,380),463)
			row.position = [point.x,point.y]
			if not f.expect(f.bench.paint(point,Setup.WALL),"fuzz ordinary inert paint remains available beside owned material"): return false
			# The owner can finish its write before Main receives that image.
			# Empty transport queues alone are not proof of a displayed edit.
			return await f.until(func(): return _stable() and _world_cell(point)==Setup.WALL,
				"ordinary inert paint has an independent completed native image witness")
		"erase": return await _erase(row)
		"stale": return await _stale(row)
		"restore":
			var generation: int = int(f.runtime().capabilities.world_generation)
			if not f.expect(f.bench.restore_start(),"fuzz whole-World Restore admitted with live owned inventory"): return false
			if not await f.until(f.installed,"fuzz authored World replacement installs"): return false
			f.bench.set_camera(2)
			f.play()
			if not await f.until(func(): return int(f.runtime().capabilities.get("world_generation",0))>generation \
				and f.body_count()>0,"fuzz fresh owner re-detaches the authored construction"): return false
			await f.pause()
			expected_wood = BASE_WOOD
			expected_brick = BASE_BRICK
			row.reset_baseline = {"wood":BASE_WOOD,"brick":BASE_BRICK,"previous_generation":generation}
			return true
	return false

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower"):
		await _finish(); return
	worker_identity = f.host.simulation_worker.get_instance_id()
	native_identity = int(f.runtime().capabilities.native_instance_id)
	for seed: int in SEEDS:
		if not await _setup_seed(seed):
			await _finish(); return
		var random := RandomNumberGenerator.new()
		random.seed = seed
		var plan: Array[String] = _plan(seed)
		seed_records.append({"seed":seed,"actions":plan})
		for index: int in range(plan.size()):
			if not await f.until(_stable,"fuzz action starts from a completed owner boundary"):
				await _finish(); return
			var row: Dictionary = {"seed":seed,"index":index,"action":plan[index],"before_tick":f.tick(),
				"before_generation":f.runtime().capabilities.world_generation}
			var accepted: bool = await _action(plan[index],random,row)
			var settled: bool = await f.until(_stable,"fuzz action settles its native and physical receipts")
			row["accepted"] = accepted
			row["settled"] = settled
			row["owner"] = {"worker_instance_id":worker_identity,"native_instance_id":native_identity,
				"world_generation":f.runtime().capabilities.get("world_generation",0),
				"shard_session":f.runtime().capabilities.get("shard_session",0),
				"world_incarnation":f.runtime().capabilities.get("world_incarnation",0),"tick":f.tick()}
			row["expected_inventory"] = {"wood":expected_wood,"brick":expected_brick}
			row["observed_inventory"] = {"wood":f.material_count(7),"brick":f.material_count(43)}
			row["native_pose_echo_checks"] = f.runtime().native_pose_echo_checks
			trace.append(row)
			print("M4_LIFECYCLE_ACTION ",JSON.stringify(row))
			if not accepted or not settled or not _inventory("seed %d action %d"%[seed,index]):
				await _finish(); return
		f.validate_physics()
		await f.validate_quantity_ledger()
	f.expect(trace.size()==SEEDS.size()*24,"all three fixed seeds completed twenty-four actual stateful operations")
	await _finish()

func _finish() -> void:
	f.validate_display()
	var report: Dictionary = {"schema":"objectshard-m4-lifecycle-fuzz-v1",
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"checks":f.checks,"failures":f.failures,
		"seeds":seed_records,"completed_actions":trace.size(),"actions":trace,"display":f.display_witness(),
		"inventory_witnesses":f.inventory_witnesses,"runtime":f.diagnostics(),"scope":"bounded seeded stateful fuzz: actual ordinary Workbench/native World/shared Rapier, independent Wood/Brick ledger with explicit erase debits and authored reset baselines"}
	await f.close()
	print(JSON.stringify(report))
	quit(0 if f.failures.is_empty() else 1)
