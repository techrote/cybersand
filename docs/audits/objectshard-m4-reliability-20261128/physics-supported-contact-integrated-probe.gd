extends SceneTree

# Representative support-contact sequence; the owner's pointer trace is not
# available. All cuts use ordinary Workbench Erase and all poses come from the
# actual Main-owned Rapier body, with native ownership still active.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var evidence: Dictionary = {}
var facade_id: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _facade() -> Dictionary:
	for body: Dictionary in f.diagnostics().get("physics",{}).get("bodies",[]):
		if int(body.id)==facade_id: return body
	return {}

func _remaining_posts() -> Array:
	var rows: Array = []
	var bytes: PackedByteArray = f.host.image.get_data()
	var channels: int = bytes.size()/(512*512)
	for x: int in [138,139,140,141,194,195,196,197]:
		var ys: Array = []
		for y: int in range(364,464):
			if int(bytes[(y*512+x)*channels])==1: ys.append(y)
		rows.append({"x":x,"world_wall_ys":ys})
	return rows

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("tower"):
		await _finish(); return
	await f.pause()
	var wood: int = f.material_count(7)
	var brick: int = f.material_count(43)
	f.bench._brush.value = 3
	for x: int in [140,196]:
		if not f.expect(f.bench.paint(Vector2i(x,370),0),"ordinary Erase severs one complete support band"):
			await _finish(); return
		await process_frame
	f.play()
	if not await f.until(func(): return f.body_count()>0,"facade obtains an actual native-owned rigid body"):
		await _finish(); return
	var largest_mass: float = 0.0
	for body: Dictionary in f.diagnostics().physics.bodies:
		if float(body.mass)>largest_mass:
			facade_id = int(body.id)
			largest_mass = float(body.mass)
	var initial: Dictionary = _facade()
	var initial_tick: int = f.tick()
	var rid: RID = f.runtime().bridge.bodies[facade_id].rid
	if not await f.until(func(): return f.tick()>=initial_tick+120 and bool(_facade().get("sleeping",false)),
		"detached facade naturally rests on the remaining physical stumps",15000):
		evidence.failed_rest = f.diagnostics()
		await _finish(); return
	await f.pause()
	var resting: Dictionary = _facade()
	var resting_pose: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	var query := PhysicsTestMotionParameters2D.new()
	query.from = resting_pose
	query.motion = Vector2(0,.1)
	query.margin = .001
	query.recovery_as_collision = true
	var collision := PhysicsTestMotionResult2D.new()
	var hit: bool = PhysicsServer2D.body_test_motion(rid,query,collision)
	var native_terrain: bool = false
	if hit:
		for chunk: Dictionary in f.runtime().bridge.terrain.values():
			if chunk.rid==collision.get_collider_rid(): native_terrain = true
	var point: Vector2 = collision.get_collision_point() if hit else Vector2.ZERO
	f.expect(f.runtime().bridge.bodies[facade_id].rid==rid and bool(resting.sleeping),
		"one native-owned physical facade retains its RID and solver-generated rest")
	f.expect(float(resting.y)>float(initial.y)+1.0 and float(resting.y)<float(initial.y)+15.0,
		"detached facade makes a real short fall before becoming stationary")
	f.expect(hit and native_terrain and collision.get_collision_normal().y<-.9 and point.y>370.0 and point.y<390.0,
		"actual nonmutating collision query identifies remaining native stump contact above the floor")
	evidence.contact = {"hit":hit,"native_terrain":native_terrain,"point":[point.x,point.y],
		"normal":[collision.get_collision_normal().x,collision.get_collision_normal().y] if hit else []}
	f.play()
	if not await f.advance(60,"native simulation continues while the detached facade rests"):
		await _finish(); return
	await f.pause()
	var after_rest: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	f.expect(after_rest.origin.distance_to(resting_pose.origin)<.1 and bool(_facade().sleeping),
		"stationary facade is genuine supported rest during ongoing native progression")
	evidence.initial = initial
	evidence.resting = resting
	evidence.support_before = _remaining_posts()
	evidence.native_ticks_while_resting = 60
	if not await f.cut_supports("tower",2):
		await _finish(); return
	f.play()
	if not await f.advance(120,"removing the grounded stumps permits renewed actual structural motion"):
		await _finish(); return
	await f.pause()
	await _diagnose_contact_erasure()
	await _finish()

func _pause_predicates() -> Dictionary:
	var current: Dictionary = f.runtime().frame
	var displayed: Dictionary = f.runtime().publication
	var worker: CyberSimulationWorker = f.host.simulation_worker
	var latest: Dictionary = worker.object_shard_owner_frame()
	var snapshot: CyberSimulationSnapshot = f.host.latest_snapshot
	return {"physics_ready":f.runtime().physics_ready(),"coherent":f.coherent(),
		"bench_busy":f.bench.busy(),"pending_count":f.bench.object_shard_m4_port.pending_count(),
		"legacy_busy":worker.paint_state().get("legacy_busy",true),
		"runtime_publication_sequence":displayed.get("publication_sequence"),
		"runtime_frame_sequence":current.get("publication_sequence"),
		"newer_owner_frame":not worker.object_shard_owner_frame(int(current.get("publication_sequence",-1))).is_empty(),
		"frame_tuple":[current.get("world_generation"),current.get("world_revision"),current.get("publication_sequence"),current.get("tick")],
		"display_tuple":[displayed.get("world_generation"),displayed.get("world_revision"),displayed.get("render_serial"),displayed.get("publication_sequence")],
		"upload_tuple":[f.host.last_uploaded_world_generation,f.host.last_uploaded_revision,f.host.last_uploaded_render_snapshot_serial],
		"snapshot_tuple":[snapshot.render_world_generation,snapshot.world_revision,snapshot.render_snapshot_serial,snapshot.simulation_world_revision],
		"native_tuple":[latest.get("world_generation"),latest.get("world_revision"),latest.get("publication_sequence"),latest.get("tick")],
		"phase":f.runtime().phase,"held_reason":f.runtime().held_reason,
		"workbench_error":f.host._workbench_frame_error,
		"displayed_inventory_request":f.runtime().request_inventory_inspection() if displayed.get("publication_sequence")!=current.get("publication_sequence") else {}}

func _native_cells(label: String) -> Dictionary:
	# Use the existing exclusive-worker read-only inspection with its exact
	# current native frame, deliberately independent of the displayed frame.
	# No native object crosses threads, and every existing admission fence runs.
	var worker: CyberSimulationWorker = f.host.simulation_worker
	var ticket: Dictionary = {}
	var deadline: int = Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		var current: Dictionary = worker.object_shard_owner_frame()
		var source: Dictionary = {}
		for key: String in ["world_generation","session","world_incarnation","publication_sequence","tick","world_revision","next_transaction"]:
			source[key] = current.get(key)
		for key: String in ["native_instance_id","transport_generation","owner_epoch","shard_session"]:
			source[key] = f.runtime().capabilities.get(key)
		ticket = worker.object_shard_request_inventory_inspection(source)
		if ticket.get("ok",false): break
		await process_frame
	if not f.expect(ticket.get("ok",false),label+": existing source-bound native inspection admitted"): return {"ticket":ticket}
	var receipt: Dictionary = {}
	while Time.get_ticks_msec()<deadline:
		receipt = worker.object_shard_take_inventory_inspection(int(ticket.token))
		if not receipt.is_empty(): break
		await process_frame
	if not f.expect(receipt.get("ok",false),label+": current native raw World copied without advancing time"): return {"receipt":receipt}
	var raw: Dictionary = receipt.raw_snapshot
	var bytes: PackedByteArray = raw.world_materials
	var cells: Array = []
	for x: int in [138,139,140,141,194,195,196,197]:
		for y: int in [372,373,374]: cells.append({"x":x,"y":y,"material":int(bytes[y*512+x])})
	return {"source":receipt.source,"native_before":receipt.native_before,"native_after":receipt.native_after,
		"cells":cells,"world_material_sha256":bytes.hex_encode().sha256_text(),
		"last_result":raw.last_result,"refusals":raw.metrics.get("refusals",-1)}

func _brush_idle() -> bool:
	var deadline: int = Time.get_ticks_msec()+5000
	while bool(f.host.simulation_worker.paint_state().get("legacy_busy",true)) and Time.get_ticks_msec()<deadline:
		await process_frame
	return f.expect(not f.host.simulation_worker.paint_state().get("legacy_busy",true),"actual ordinary brush queue completed")

func _diagnose_contact_erasure() -> void:
	evidence.integrated_before = _pause_predicates()
	evidence.native_before = await _native_cells("before exact contact edit")
	var target := Vector2i(-1,-1)
	for cell: Dictionary in evidence.native_before.get("cells",[]):
		if int(cell.material)==1 and int(cell.y)==373:
			target = Vector2i(int(cell.x),int(cell.y)); break
	if not f.expect(target.x>=0,"real remaining World Wall contact cell is identified"): return
	# One actual legacy footprint cell yields an unambiguous last native result.
	f.expect(f.host.queue_brush_mutation(target.x,target.y,0,0),"single-cell ordinary Erase command admitted")
	if not await _brush_idle(): return
	evidence.exact_cell_after = await _native_cells("after exact contact edit")
	evidence.exact_cell_predicates = _pause_predicates()
	f.bench._brush.value = 1
	f.expect(f.bench.paint(target,0),"ordinary fine Erase stamp admitted at the same native stump contact")
	if not await _brush_idle(): return
	var deadline: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		var p: Dictionary = _pause_predicates()
		if p.physics_ready and p.coherent and not p.bench_busy and int(p.pending_count)==0 and not p.legacy_busy \
			and p.runtime_publication_sequence==p.runtime_frame_sequence and not p.newer_owner_frame: break
		await process_frame
	evidence.fine_stamp_after = await _native_cells("after ordinary fine Erase")
	evidence.final_predicates = _pause_predicates()
	evidence.final_paint_state = f.host.simulation_worker.paint_state()
	evidence.remaining_posts = _remaining_posts()
	print("CONTACT_ERASE_DIAGNOSTIC ",JSON.stringify(evidence))
	var publication_ready: bool = evidence.final_predicates.runtime_publication_sequence==evidence.final_predicates.runtime_frame_sequence
	f.expect(publication_ready,
		"ordinary no-op/refused contact brush leaves the paused publication usable")
	if not publication_ready:
		# Explicit diagnostic-only counterfactual, after preserving the failed
		# assertion: does an ordinary full render request repair the tuple
		# without any material write, native tick or physical interval?
		f.host.simulation_worker.request_render_full_refresh()
		var refresh_deadline: int = Time.get_ticks_msec()+3000
		while Time.get_ticks_msec()<refresh_deadline:
			var p: Dictionary = _pause_predicates()
			if p.runtime_publication_sequence==p.runtime_frame_sequence: break
			await process_frame
		evidence.explicit_render_refresh_counterfactual = _pause_predicates()

func _finish() -> void:
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-supported-contact-probe-v1","checks":f.checks,
		"failures":f.failures,"evidence":evidence,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"complete integrated application; actual supported Tower contact and source-bound native inspection; no native ownership protection bypass"}))
	quit(0 if f.failures.is_empty() else 1)
