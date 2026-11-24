extends SceneTree

# Genuine ordinary Workbench handoffs: a witnessed cut makes two physical
# islands, and a separate settled body returns its exact inventory to World.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var f: RefCounted
var evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _install(shape: String) -> bool:
	await f.pause()
	var authored: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
	authored.edits = [[0,464,512,48,1],[0,0,3,512,1],[509,0,3,512,1]]
	if shape=="fragment":
		authored.edits.append_array([[140,420,12,12,7],[158,420,12,12,7],[152,425,6,2,7],
			[145,432,2,32,1],[163,432,2,32,1]])
	else:
		authored.edits.append_array([[140,440,20,8,7],[149,448,2,16,1]])
	if not f.expect(f.bench.apply(authored),"fresh native "+shape+" construction admitted"): return false
	if not await f.until(f.installed,"fresh "+shape+" World installed"): return false
	f.play()
	if not await f.until(func(): return f.runtime().physics_ready(),"ordinary material owner rebound"): return false
	await f.pause()
	f.bench._brush.value = 3
	var points: Array = [Vector2i(146,437),Vector2i(164,437)] if shape=="fragment" else [Vector2i(150,453)]
	for point: Vector2i in points:
		if not f.expect(f.bench.paint(point,0),"ordinary support cut "+str(point)): return false
		await process_frame
	f.play()
	return await f.until(func(): return f.body_count()==1 and f.runtime().physics_ready(),"one actual coherent material body detached")

func _target_for_source(position: Vector2i) -> Dictionary:
	for shard: Dictionary in f.runtime().publication.get("shards",[]):
		if not shard.get("owns_inventory",false): continue
		var local: Vector2i = position-Vector2i(int(shard.origin_x),int(shard.origin_y))
		if local.x<0 or local.y<0 or local.x>=int(shard.width) or local.y>=int(shard.height): continue
		var index: int = local.y*int(shard.width)+local.x
		if int(shard.roles[index])!=1: continue
		var pose := Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
		var pixel := Vector2i((pose*(Vector2(local)+Vector2(0.5,0.5))).floor())
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				var target: Dictionary = f.runtime().visible_target(pixel+Vector2i(x,y))
				if target.get("owner")==int(shard.id) and target.get("cell")==index: return target
	return {}

func _settled() -> bool:
	for shard: Dictionary in f.frame().get("shards",[]):
		if not shard.get("has_body",false): continue
		var angle: float = wrapf(float(shard.rotation),-PI,PI)
		return Vector2(float(shard.vx),float(shard.vy)).length()<=0.25 \
			and absf(float(shard.angular_velocity))<=0.01 \
			and absf(angle-roundf(angle/(PI/2.0))*(PI/2.0))<=0.001
	return false

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower") or not await _install("fragment"):
		await _finish(); return
	await f.pause()
	await f.until(f.coherent,"pre-cut native World and material body display coherent")
	var inventory: int = f.material_count(7)
	var parent: int = int(f.frame().shards[0].id)
	for position: Vector2i in [Vector2i(154,425),Vector2i(154,426)]:
		var target: Dictionary = _target_for_source(position)
		if not f.expect(not target.is_empty(),"exact native neck cell visible at "+str(position)):
			await _finish(); return
		var queued: Dictionary = f.bench.object_shard_m4_action(target.position,"erase",f.runtime().visible_observation(),target)
		if not f.expect(queued.get("ok",false),"moving neck cut admitted"):
			await _finish(); return
		await f.until(func(): return f.bench.object_shard_m4_port.pending_count()==0,"actual cut terminal receipt")
		if not f.expect(f.bench.object_shard_m4_port.results.back().get("outcome")=="Applied","native neck cut applied"):
			await _finish(); return
		await f.until(func(): return f.runtime().physics_ready() and f.coherent(),"changed parent geometry actually installed")
	f.play()
	if not await f.until(func(): return f.body_count()==2 and f.runtime().physics_ready(),"two actual physical islands activate after native transfer"):
		await _finish(); return
	await f.pause()
	await f.until(f.coherent,"fragmented inventory shares one visual World revision")
	f.expect(f.material_count(7)==inventory-2,"fragment custody conserves every surviving Wood cell")
	var source_proved: bool = false
	for shard: Dictionary in f.frame().shards:
		if shard.get("fragment",false) and int(shard.get("source_parent_id",0))==parent: source_proved = true
	f.expect(source_proved,"native child names its actual parent ownership transfer")
	f.validate_physics()
	evidence.fragment = f.diagnostics()
	if not await _install("return"):
		await _finish(); return
	if not await f.until(_settled,"actual Rapier body settles nearly on the material grid"):
		await _finish(); return
	await f.pause()
	await f.until(f.coherent,"settled body is exactly the displayed source")
	var before: int = f.material_count(7)
	var target: Dictionary = f.moving_target(7)
	if not f.expect(not target.is_empty(),"settled owned Wood has exact displayed witness"):
		await _finish(); return
	var requested: Dictionary = f.runtime().request_reabsorption(target.position)
	if not f.expect(requested.get("ok",false) and requested.get("applied")==false,"return starts as staged request, never a fictitious applied edit"):
		await _finish(); return
	if not await f.until(func(): return f.runtime().last_reabsorption_receipt.get("applied",false),"actual freeze, World credit, RID removal and terrain ACK complete"):
		await _finish(); return
	await f.until(func(): return f.runtime().physics_ready() and f.coherent(),"returned World and absent moving overlay commit together")
	var receipt: Dictionary = f.runtime().last_reabsorption_receipt
	f.expect(receipt.get("source_target",{})==target,"terminal native receipt retains exact pre-return target")
	f.expect(receipt.get("world_committed",false) and int(receipt.get("retired_inventory_cells",-1))==0,
		"native return retires only empty inventory after World owns the cells")
	f.expect(f.body_count()==0 and not f.runtime().has_live_inventory(),"returned body owns no hidden RID or material copy")
	f.expect(f.material_count(7)==before,"independent ordinary World image conserves returned Wood")
	evidence.reabsorption = receipt
	evidence.final = f.diagnostics()
	await _finish()

func _finish() -> void:
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-fragment-reabsorption-v1","checks":f.checks,"failures":f.failures,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"evidence":evidence,
		"scope":"actual ordinary Workbench material inventory, shared Rapier fragmentation and same-World settled return"}))
	quit(0 if f.failures.is_empty() else 1)
