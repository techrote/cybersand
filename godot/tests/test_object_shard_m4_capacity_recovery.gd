extends SceneTree

# Saturate the real M4 rigid-body budget, mutate one live carrier into two
# islands while no rigid slot is available, then free exactly one slot through
# the existing settled-reabsorption protocol. The deferred child must be
# admitted later without duplicating or losing surviving material.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var f: RefCounted
var evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _special_shard() -> Dictionary:
	for shard: Dictionary in f.frame().get("shards",[]):
		if int(shard.get("origin_x",-1))==20 and int(shard.get("origin_y",-1))==120:
			return shard
	return {}

func _shard(id: int) -> Dictionary:
	for shard: Dictionary in f.frame().get("shards",[]):
		if int(shard.get("id",0))==id: return shard
	return {}

func _fragment_child(parent: int) -> Dictionary:
	for shard: Dictionary in f.frame().get("shards",[]):
		if bool(shard.get("fragment",false)) and int(shard.get("source_parent_id",0))==parent:
			return shard
	return {}

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

func _target_for_shard(shard: Dictionary) -> Dictionary:
	if shard.is_empty(): return {}
	var roles: PackedByteArray = shard.get("roles",PackedByteArray())
	var width: int = int(shard.width)
	for index: int in range(roles.size()):
		if int(roles[index])!=1: continue
		var local := Vector2i(index%width,int(index/width))
		var pose := Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
		var pixel := Vector2i((pose*(Vector2(local)+Vector2(0.5,0.5))).floor())
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				var target: Dictionary = f.runtime().visible_target(pixel+Vector2i(x,y))
				if target.get("owner")==int(shard.id) and target.get("cell")==index: return target
	return {}

func _settled_other(parent: int) -> Dictionary:
	for shard: Dictionary in f.frame().get("shards",[]):
		if int(shard.get("id",0))==parent or not shard.get("has_body",false): continue
		var angle: float = wrapf(float(shard.rotation),-PI,PI)
		if int(shard.get("pose_serial",0))>0 and bool(shard.get("sleeping",false)) \
				and Vector2(float(shard.vx),float(shard.vy)).length()<=0.25 \
				and absf(float(shard.angular_velocity))<=0.01 \
				and absf(angle-roundf(angle/(PI/2.0))*(PI/2.0))<=0.001:
			return shard
	return {}

func _install_saturated_start() -> bool:
	if not await f.pause(): return false
	var authored: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
	authored.edits = [[0,464,512,48,1],[0,0,3,512,1],[509,0,3,512,1],
		[20,120,8,8,7],[29,120,8,8,7],[28,123,1,1,7]]
	for i: int in range(15):
		var x: int = 54+i*28
		var y: int = 112+(i%3)*28
		authored.edits.append([x,y,8,8,7])
	if not f.expect(f.bench.apply(authored),"capacity fixture admitted through ordinary Workbench apply"): return false
	if not await f.until(f.installed,"capacity fixture World installed"): return false
	f.bench.set_camera(2)
	if not f.play(): return false
	if not await f.until(func(): return f.runtime().owns_terrain(),"ordinary owner adopts capacity fixture terrain"): return false
	if not await f.until(func(): return f.body_count()==16,"all sixteen supported M4 material-body slots are occupied"): return false
	if not await f.pause(): return false
	return f.expect(int(f.runtime().capabilities.get("max_bodies",0))==16 and f.body_count()==16,
		"advertised and actual rigid-body capacity agree at sixteen")

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower") or not await _install_saturated_start():
		await _finish()
		return
	# Do not identify the carrier by authored storage origin: promotion/geometry
	# publication may normalize retained storage. The exact displayed bridge-cell
	# witness is the production ownership identity and remains valid after that
	# normalization.
	var target: Dictionary = _target_for_source(Vector2i(28,123))
	if not f.expect(not target.is_empty(),"single bridge cell has an exact displayed native witness"):
		await _finish()
		return
	var parent_id: int = int(target.owner)
	var parent: Dictionary = _shard(parent_id)
	if not f.expect(parent_id>0 and not parent.is_empty(),"bridge witness resolves its connected saturated parent"):
		await _finish()
		return
	var before_wood: int = f.material_count(7)
	var before_refusals: int = int(f.frame().get("metrics",{}).get("fragment_refusals",0))
	var before_results: int = f.bench.object_shard_m4_port.results.size()
	var queued: Dictionary = f.bench.object_shard_m4_action(target.position,"erase",f.runtime().visible_observation(),target)
	var wait_condition_observed: bool = f.bench.object_shard_m4_port.pending_count()>0 or not f.runtime().physics_ready()
	if not f.expect(queued.get("ok",false) and f.bench.object_shard_m4_port.pending_count()==1,
		"paused saturated edit queues one authenticated owner transaction"):
		await _finish()
		return
	if not await f.until(func(): return f.bench.object_shard_m4_port.results.size()>before_results \
			and f.bench.object_shard_m4_port.pending_count()==0 and f.runtime().physics_ready() and f.coherent(),
		"paused WaitingForPhysicalReceipt condition drains to an installed coherent receipt"):
		await _finish()
		return
	var terminal: Dictionary = f.bench.object_shard_m4_port.results[before_results]
	f.expect(terminal.get("outcome")=="Applied","capacity-saturated bridge removal has an Applied native receipt")
	f.expect(wait_condition_observed,"the saturated paused edit actually entered the physical-receipt wait boundary")
	f.expect(f.body_count()==16,"no seventeenth rigid body is fabricated while capacity is full")
	f.expect(f.material_count(7)==before_wood-1,"only the intentionally erased bridge cell leaves Wood inventory")
	if not f.play() or not await f.advance(1,"one real interval after saturated edit") or not await f.pause():
		await _finish()
		return
	if not await f.until(func():
		var current: Dictionary = _shard(parent_id)
		return not current.is_empty() and bool(current.get("fragment_deferred",false)) and bool(current.get("split_pending",false)),
		"split is explicitly deferred in its physical parent when all body slots are occupied"):
		await _finish()
		return
	var deferred: Dictionary = _shard(parent_id)
	f.expect(int(deferred.get("islands",0))>=2 and f.body_count()==16,
		"deferred parent retains the disconnected islands without exceeding body capacity")
	f.expect(int(f.frame().get("metrics",{}).get("fragment_refusals",0))>before_refusals,
		"native metrics record the BodySlots fragmentation refusal")
	evidence.saturated = {"body_count":f.body_count(),"parent":deferred.duplicate(true),
		"edit_receipt":terminal.duplicate(true),"wait_condition_observed":wait_condition_observed,
		"fragment_refusals":f.frame().get("metrics",{}).get("fragment_refusals",0)}
	await f.validate_quantity_ledger()
	if not f.failures.is_empty():
		await _finish()
		return

	if not f.play() or not await f.advance(120,"saturated carriers receive real physical settling time"):
		await _finish()
		return
	if not await f.until(func(): return not _settled_other(parent_id).is_empty(),
		"an unrelated saturated carrier settles slowly and quarter-turn aligned"):
		await _finish()
		return
	if not await f.pause():
		await _finish()
		return
	var settled: Dictionary = _settled_other(parent_id)
	var settle_target: Dictionary = _target_for_shard(settled)
	if not f.expect(not settle_target.is_empty(),"settled slot donor has an exact displayed structural witness"):
		await _finish()
		return
	var reabsorb: Dictionary = f.runtime().request_reabsorption(settle_target.position)
	if not f.expect(reabsorb.get("ok",false),"existing settled-reabsorption protocol accepts one slot donor"):
		await _finish()
		return
	if not await f.until(func(): return f.runtime().last_reabsorption_receipt.get("applied",false),
		"freeze, World credit, physical retirement and terrain acknowledgement release the donor slot"):
		await _finish()
		return
	var returned: Dictionary = f.runtime().last_reabsorption_receipt.duplicate(true)
	f.expect(returned.get("world_committed",false) and int(returned.get("retired_inventory_cells",-1))==0,
		"slot donor retires only after World owns every returned material cell")
	evidence.reabsorption = {"donor_id":settled.get("id"),"receipt":returned,
		"body_count_at_observation":f.body_count()}

	if not f.play():
		await _finish()
		return
	if not await f.until(func(): return f.body_count()==16 and not _fragment_child(parent_id).is_empty() \
			and not bool(_shard(parent_id).get("fragment_deferred",true)),
		"deferred split consumes the newly available slot and becomes a real child body"):
		await _finish()
		return
	if not await f.pause():
		await _finish()
		return
	var child: Dictionary = _fragment_child(parent_id)
	f.expect(int(child.get("source_parent_id",0))==parent_id and child.get("has_body",false),
		"recovered child preserves the exact native parent ownership transfer")
	f.expect(f.material_count(7)==before_wood-1,
		"reabsorption and delayed fragmentation preserve every surviving Wood cell")
	evidence.recovered = {"body_count":f.body_count(),"parent":_shard(parent_id).duplicate(true),
		"child":child.duplicate(true),"material_count":f.material_count(7)}
	await f.validate_quantity_ledger()
	if not f.failures.is_empty():
		await _finish()
		return

	var old_generation: int = int(f.diagnostics().get("world_generation",0))
	var old_session: int = int(f.frame().get("session",0))
	if not f.expect(f.bench.restore_start(),"whole authored start replacement is admitted from saturated live ownership"):
		await _finish()
		return
	if not await f.until(f.installed,"replacement authored World is committed"):
		await _finish()
		return
	f.expect(f.body_count()==0 and f.bench.object_shard_m4_port.pending_count()==0,
		"scene replacement retires every previous physical body and pending edit receipt before new play")
	if not f.play():
		await _finish()
		return
	if not await f.until(func(): return int(f.diagnostics().get("world_generation",0))>old_generation \
			and int(f.frame().get("session",0))!=old_session,
		"replacement owns a fresh World generation and shard session"):
		await _finish()
		return
	await f.pause()
	evidence.replacement = {"old_generation":old_generation,"new_generation":f.diagnostics().get("world_generation",0),
		"old_session":old_session,"new_session":f.frame().get("session",0),
		"pending":f.bench.object_shard_m4_port.pending_count()}
	await _finish()

func _finish() -> void:
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	evidence.inventory_witnesses = f.inventory_witnesses
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-capacity-recovery-v1",
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":f.checks,"failures":f.failures,"evidence":evidence,
		"scope":"actual ordinary Workbench 16-body saturation, paused edit receipt, deferred split, settled reabsorption slot release and owner replacement"}))
	quit(0 if f.failures.is_empty() else 1)
