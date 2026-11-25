extends SceneTree

# Natural combustion and authored terminal skeleton removal are deliberately
# separate witnesses. Fire can re-ignite exposed Wood, so no finite whole-body
# burnout promise is invented for an ordinary open wooden building.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const MAX_BURN_TICKS: int = 600
var f: RefCounted
var evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _shard(owner: int) -> Dictionary:
	return _shard_in(f.frame(),owner)

func _shard_in(sample: Dictionary, owner: int) -> Dictionary:
	for row: Dictionary in sample.get("shards",[]):
		if int(row.id)==owner: return row
	return {}

func _cell_in(row: Dictionary, cell: int) -> Dictionary:
	if not row.get("owns_inventory",false) or cell<0 or cell>=row.get("materials",PackedByteArray()).size(): return {}
	return {"material":int(row.materials[cell]),"state_a":int(row.states_a[cell]),
		"state_b":int(row.states_b[cell]),"incarnation":int(row.incarnations[cell])}

func _count(name: String, material: int = 7) -> int:
	var counts: PackedInt64Array = f.frame().get("accounting",{}).get(name,PackedInt64Array())
	return int(counts[material]) if counts.size()>material else -1

func _target_at_source(position: Vector2i) -> Dictionary:
	for row: Dictionary in f.runtime().publication.get("shards",[]):
		if not row.get("owns_inventory",false): continue
		var local: Vector2i = position-Vector2i(int(row.origin_x),int(row.origin_y))
		if not Rect2i(Vector2i.ZERO,Vector2i(int(row.width),int(row.height))).has_point(local): continue
		var cell: int = local.y*int(row.width)+local.x
		var pose := Transform2D(float(row.rotation),Vector2(float(row.position_x),float(row.position_y)))
		var pixel := Vector2i((pose*(Vector2(local)+Vector2(0.5,0.5))).floor())
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				var target: Dictionary = f.runtime().visible_target(pixel+Vector2i(x,y))
				if target.get("owner")==int(row.id) and target.get("cell")==cell: return target
	return {}

func _install(kind: String) -> bool:
	if not await f.pause(): return false
	var generation: int = int(f.frame().world_generation)
	var authored: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
	# Retain the ordinary reference actor in the same Main Rapier space.
	authored.actors = f.bench.applied.actors.duplicate(true)
	authored.next_id = f.bench.applied.next_id
	authored.selected = f.bench.applied.selected
	authored.edits = [[0,464,512,48,1],[0,0,3,512,1],[509,0,3,512,1]]
	var stem: Rect2i
	if kind=="enclosed_wood":
		# Eight Brick neighbours prevent Fire emission/re-ignition around the
		# central Wood without changing the admitted native material law.
		authored.edits.append_array([[180,400,3,3,43],[181,401,1,1,7],[181,403,1,61,1]])
		stem = Rect2i(181,403,1,61)
	else:
		authored.edits.append_array([[300,436,2,2,7],[300,438,1,26,1]])
		stem = Rect2i(300,438,1,26)
	if not f.expect(f.bench.apply(authored),"ordinary authored "+kind+" setup admitted"): return false
	if not await f.until(f.installed,"new authored native owner installed"): return false
	f.bench.set_camera(2)
	f.play()
	if not await f.until(func(): return f.runtime().capabilities.get("world_generation",0)>generation \
		and f.diagnostics().get("attached",false),"fresh ordinary World attaches without parallel simulation authority"): return false
	if not await f.pause(): return false
	f.expect(f.body_count()==0,"complete native foundation anchors the intact authored body")
	f.bench._brush.value = 2
	if not f.expect(int(f.bench.applied.brush)==2,"ordinary authored brush uses its admitted radius-two contract"): return false
	var centers: Array[int] = []
	for y: int in range(stem.position.y+2,stem.end.y-2,4): centers.append(y)
	if centers.is_empty() or centers.back()!=stem.end.y-3: centers.append(stem.end.y-3)
	for y: int in centers:
		# Discs touch the first/last stem rows and overlap by one row. They
		# remove the whole narrow support without touching body or floor.
		if not f.expect(f.bench.paint(Vector2i(stem.position.x,y),0),"ordinary brush removes complete support interval at "+str(y)): return false
		await process_frame
	if not await f.pause(): return false
	f.play()
	if not await f.until(func(): return f.body_count()==1,"one genuine coherent material body detaches"): return false
	if not await f.advance(12,"detached body advances through actual shared Rapier intervals"): return false
	return await f.pause()

func _natural_combustion() -> bool:
	if not await _install("enclosed_wood"): return false
	var target: Dictionary = _target_at_source(Vector2i(181,401))
	if not f.expect(not target.is_empty(),"central Wood has an exact displayed moving-cell source"): return false
	var owner: int = int(target.owner)
	var cell: int = int(target.cell)
	var initial: Dictionary = _shard(owner).duplicate(true)
	f.expect(int(initial.structural)==9 and f.material_count(7)==1 and f.material_count(43)==8,
		"actual detached inventory is exactly one Wood surrounded by eight Brick cells")
	var brick_neighbours: int = 0
	for dy: int in range(-1,2):
		for dx: int in range(-1,2):
			if dx==0 and dy==0: continue
			var neighbour: int = cell+dy*int(initial.width)+dx
			if neighbour>=0 and neighbour<initial.materials.size() and int(initial.materials[neighbour])==43 \
				and int(initial.roles[neighbour])==1: brick_neighbours += 1
	if not f.expect(brick_neighbours==8,"all eight exact native neighbours are occupied inert Brick before ignition"): return false
	f.expect(float(initial.position_y)>float(initial.origin_y) and absf(float(initial.vy))>0.1,
		"Wood source belongs to an actually falling native-acknowledged Rapier body")
	await f.validate_quantity_ledger()
	var requested: Dictionary = f.bench.object_shard_m4_action(target.position,"ignite",f.runtime().visible_observation(),target)
	if not f.expect(requested.get("ok",false),"ordinary moving Ignite queues the exact central source"): return false
	if not await f.until(func(): return f.bench.object_shard_m4_port.pending_count()==0,"native ignition receipt completes"): return false
	if not await f.pause(): return false
	var ignition: Dictionary = f.bench.object_shard_m4_port.results.back().duplicate(true)
	var state: Dictionary = f.owned_cell_state(owner,cell)
	if not f.expect(ignition.get("outcome")=="Applied" and state.get("material")==7 and state.get("state_b")==240,
		"native source starts the unchanged 240-opportunity Wood lifetime"): return false
	f.expect(_cell_in(_shard(owner),cell)==state and int(f.runtime().publication.get("tick",-1))==f.tick(),
		"paused ignition joins the native cell and displayed cell at one exact source tick")
	var before_tick: int = f.tick()
	var before_intervals: int = int(f.runtime().physical_intervals)
	var before_steps: int = int(f.runtime().physical_steps)
	var before_ack: int = int(f.runtime().native_pose_acknowledgements)
	var before_destroyed: int = _count("destroyed")
	var before_authored: int = _count("authored_destroyed")
	var before_products: int = int(f.frame().get("metrics",{}).get("products_created",0))
	var incarnation: int = int(state.incarnation)
	var trace: Array[Dictionary] = []
	var previous_tick: int = -1
	var previous_burn: int = 240
	var monotone: bool = true
	var same_incarnation: bool = true
	var exhaustion_tick: int = -1
	var deadline: int = Time.get_ticks_msec()+Fixture.Watchdogs.milliseconds("operation_seconds")
	f.play()
	while f.tick()-before_tick<=MAX_BURN_TICKS and Time.get_ticks_msec()<deadline \
		and str(f.runtime().held_reason).is_empty():
		await process_frame
		# Semantic chemistry time and cell state must come from the same
		# immutable native frame. A geometry change deliberately retains the
		# earlier coherent display until Rapier installation is acknowledged;
		# labelling that old displayed cell with a newer native tick is false.
		var native_sample: Dictionary = f.frame()
		var native_tick: int = int(native_sample.get("tick",-1))
		if native_tick==previous_tick: continue
		previous_tick = native_tick
		var row: Dictionary = _shard_in(native_sample,owner)
		state = _cell_in(row,cell)
		var displayed_sample: Dictionary = f.runtime().publication
		var displayed_cell: Dictionary = _cell_in(_shard_in(displayed_sample,owner),cell)
		if state.get("material")==7:
			monotone = monotone and int(state.state_b)>0 and int(state.state_b)<=previous_burn
			same_incarnation = same_incarnation and int(state.incarnation)==incarnation
			previous_burn = int(state.state_b)
		elif state.get("material")==0 and exhaustion_tick<0:
			exhaustion_tick = native_tick
		trace.append({"tick":native_tick,"native_cell":state,"native_publication_sequence":native_sample.get("publication_sequence"),
			"displayed_tick":displayed_sample.get("tick"),"displayed_cell":displayed_cell,
			"displayed_publication_sequence":displayed_sample.get("publication_sequence"),"geometry_revision":row.get("geometry_revision"),
			"applied_physics_revision":row.get("applied_physics_revision"),"structural":row.get("structural"),
			"has_body":row.get("has_body")})
		if (native_tick-before_tick)%60==0:
			print("M4_LONG_BURN_PROGRESS ",JSON.stringify(trace.back()))
		if exhaustion_tick>=0: break
	if not f.expect(exhaustion_tick>before_tick and exhaustion_tick-before_tick<=480,
		"exact moving Wood naturally exhausts all 240 period-two opportunities within 480 native ticks"):
		evidence.natural_trace = trace
		return false
	if not await f.pause(): return false
	var final: Dictionary = _shard(owner).duplicate(true)
	var delivered_cell: Dictionary = f.owned_cell_state(owner,cell)
	f.expect(delivered_cell.get("material")==0 and delivered_cell==_cell_in(final,cell) \
		and int(f.runtime().publication.get("publication_sequence",-1))==int(f.frame().get("publication_sequence",-2)),
		"naturally exhausted cell is independently delivered after exact physical and display acknowledgement")
	f.expect(monotone and same_incarnation,"burn countdown belongs continuously to the original native cell incarnation")
	f.expect(int(final.structural)==8 and final.has_body and int(final.geometry_revision)>int(initial.geometry_revision) \
		and final.applied_physics_revision==final.geometry_revision,
		"natural structural deletion installs and acknowledges its exact reduced native geometry")
	f.expect(float(final.mass)<float(initial.mass) and float(final.mass)>0.0,
		"surviving Brick body has the reduced positive native mass")
	f.expect(_count("destroyed")==before_destroyed+1 and _count("authored_destroyed")==before_authored,
		"native chemistry consumes exactly one Wood without an authored erase debit")
	f.expect(f.material_count(7)==0 and f.material_count(43)==8,
		"independent visible World-plus-owner inventory loses only the naturally consumed Wood")
	f.expect(int(f.frame().get("metrics",{}).get("products_created",0))==before_products,
		"occupied native neighbours prevent re-ignition without modifying the combustion law")
	var ticks: int = f.tick()-before_tick
	var intervals: int = int(f.runtime().physical_intervals)-before_intervals
	var steps: int = int(f.runtime().physical_steps)-before_steps
	f.expect(absi(intervals-ticks)<=1 and steps==4*intervals and int(f.runtime().native_pose_acknowledgements)>before_ack,
		"long native chemistry run consumes separately witnessed real physical intervals and segment acknowledgements")
	f.validate_physics()
	await f.validate_quantity_ledger()
	evidence.natural_combustion = {"source":target,"ignition":ignition,"initial":initial,"final":final,"brick_neighbours":brick_neighbours,
		"native_ticks":ticks,"physical_intervals":intervals,"physical_segments":steps,
		"simulated_physical_seconds":intervals/60.0,"before_tick":before_tick,"exhaustion_tick":exhaustion_tick,
		"delivered_cell":delivered_cell,"displayed_after_pause_tick":f.runtime().publication.get("tick"),
		"displayed_after_pause_publication_sequence":f.runtime().publication.get("publication_sequence"),
		"maximum_native_ticks":MAX_BURN_TICKS,"trace":trace,
		"scope":"natural lifetime exhaustion of the original moving Wood cell inside an inert closed Brick neighbourhood; no claim of bounded whole-building burnout"}
	return f.failures.is_empty()

func _point_query(rid: RID, position: Vector2) -> Dictionary:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collision_mask = 1
	var result: Dictionary = {"point":[position.x,position.y],"expected_rid":rid.get_id(),"hit":false,"hits":[]}
	for hit: Dictionary in PhysicsServer2D.space_get_direct_state(f.runtime().bridge.space).intersect_point(query,32):
		var hit_rid: RID = hit.get("rid",RID())
		result.hits.append({"rid":hit_rid.get_id(),"shape":hit.get("shape",-1)})
		if hit_rid==rid: result.hit = true
	return result

func _point_hits(rid: RID, position: Vector2) -> bool:
	return bool(_point_query(rid,position).hit)

func _terminal_cut() -> bool:
	if not await _install("terminal_wood"): return false
	if not f.expect(f.material_count(7)==4 and f.material_count(43)==0,
		"terminal control begins with exactly four actual owned Wood cells"): return false
	await f.validate_quantity_ledger()
	var authored_before: int = _count("authored_destroyed")
	var chemistry_before: int = _count("destroyed")
	var cuts: Array[Dictionary] = []
	var final_rid: RID
	var final_point: Vector2
	for index: int in range(4):
		if index==3:
			# A paused shape install has native/actual shape readback, but a
			# direct spatial query also needs Rapier's completed query pipeline.
			# Exercise the one-cell body for one ordinary paused Step first.
			var step_tick: int = f.tick()
			var step_ack: int = int(f.runtime().native_pose_acknowledgements)
			if not f.expect(f.bench.step_once(),"ordinary Step admits the new final one-cell physical geometry"): return false
			if not await f.until(func(): return f.tick()==step_tick+1,"one-cell geometry receives one real native/physical interval"): return false
			if not await f.pause(): return false
			f.expect(int(f.runtime().native_pose_acknowledgements)==step_ack+4,
				"actual one-cell body completes four precisely acknowledged Rapier segments")
		var target: Dictionary = f.moving_target(7)
		if not f.expect(not target.is_empty(),"remaining Wood has an exact displayed Cut source "+str(index)): return false
		if index==3:
			var row: Dictionary = _shard(int(target.owner))
			final_rid = f.runtime().bridge.bodies[int(target.owner)].rid
			var local := Vector2(float(int(target.cell)%int(row.width))+0.5,float(int(target.cell)/int(row.width))+0.5)
			final_point = Transform2D(float(row.rotation),Vector2(float(row.position_x),float(row.position_y)))*local
			var actual: Transform2D = PhysicsServer2D.body_get_state(final_rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
			var point_result: Dictionary = _point_query(final_rid,final_point)
			evidence.terminal_final_cell = {"native":row.duplicate(true),"query":point_result,
				"backend_position":[actual.origin.x,actual.origin.y],"backend_rotation":actual.get_rotation(),
				"backend_shape_count":PhysicsServer2D.body_get_shape_count(final_rid),
				"backend_layer":PhysicsServer2D.body_get_collision_layer(final_rid)}
			f.expect(int(row.structural)==1 and bool(point_result.hit),
				"independent actual Rapier query sees the final one-cell physical skeleton")
		var request: Dictionary = f.bench.object_shard_m4_action(target.position,"erase",f.runtime().visible_observation(),target)
		if not request.get("ok",false):
			evidence.terminal_cut_refusal = {"index":index,"request":request,"target":target,
				"observation":f.runtime().visible_observation(),"step_pending":f.bench.step_pending,"message":f.bench.message}
		if not f.expect(request.get("ok",false),"ordinary exact-source Cut is admitted "+str(index)+" / "+str(request)): return false
		if not await f.until(func(): return f.bench.object_shard_m4_port.pending_count()==0,"exact terminal Cut receipt completes"): return false
		if not await f.pause(): return false
		var receipt: Dictionary = f.bench.object_shard_m4_port.results.back().duplicate(true)
		if not f.expect(receipt.get("outcome")=="Applied","native source-bound Cut is applied "+str(index)): return false
		cuts.append({"source":target,"receipt":receipt})
	f.expect(f.body_count()==0 and not _point_hits(final_rid,final_point),
		"final structural deletion removes its actual Rapier body without constructing zero mass")
	f.play()
	if not await f.advance(4,"ordinary native and physical play continues after terminal body retirement"): return false
	if not await f.pause(): return false
	var live_owners: int = 0
	for row: Dictionary in f.frame().get("shards",[]):
		if row.get("owns_inventory",false) or row.get("has_body",false): live_owners += 1
	f.expect(live_owners==0 and f.body_count()==0 and f.material_count(7)==0,
		"empty native draining inventory and its physical owner both retire completely")
	f.expect(_count("authored_destroyed")==authored_before+4 and _count("destroyed")==chemistry_before,
		"four explicit authored deletions remain distinct from the natural chemistry control")
	await f.validate_quantity_ledger()
	evidence.terminal_retirement = {"cuts":cuts,"remaining_live_owners":live_owners,
		"final_body_rid":final_rid.get_id(),"independent_backend_absent":not _point_hits(final_rid,final_point),
		"scope":"authored exact-source last-cell Cut and terminal native/Rapier retirement; not natural whole-body combustion"}
	return f.failures.is_empty()

func _run() -> void:
	f = Fixture.new(self)
	if not f.expect(DisplayServer.get_name()=="headless","bounded long-burn integration runs only in the headless lane"):
		await _finish(); return
	if await f.open("tower") and await _natural_combustion():
		await _terminal_cut()
	await _finish()

func _finish() -> void:
	if f.host != null:
		f.validate_display()
		evidence.display_coherence = f.display_witness()
		evidence.final_diagnostics = f.diagnostics()
	evidence.inventory_witnesses = f.inventory_witnesses
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-long-burn-v1","source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":f.checks,"failures":f.failures,"evidence":evidence}))
	quit(0 if f.failures.is_empty() else 1)
