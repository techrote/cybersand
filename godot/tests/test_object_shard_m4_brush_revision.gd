extends SceneTree

# Actual ordinary paused brush publication regression. A native-owned Tower
# rests on retained native support; protected contact cells and already-empty
# neighbours must not invent a renderless World revision. Real edits still do.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Profiles = preload("res://scripts/transport_profiles.gd")
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
		"detached facade naturally rests on the remaining physical stumps"):
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
	if not await f.advance(120,"native progression continues after ordinary lower-stump erasure"):
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
		"physical_intervals":f.runtime().physical_intervals,"actor_tick":f.host.physical_actor_session.tick,
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
		"last_result":raw.last_result,"refusals":raw.metrics.get("refusals",-1),
		"control_material":int(bytes[100*512+450])}

func _brush_idle() -> bool:
	var deadline: int = Time.get_ticks_msec()+5000
	while bool(f.host.simulation_worker.paint_state().get("legacy_busy",true)) and Time.get_ticks_msec()<deadline:
		await process_frame
	return f.expect(not f.host.simulation_worker.paint_state().get("legacy_busy",true),"actual ordinary brush queue completed")

func _publication_ready() -> bool:
	var p: Dictionary = _pause_predicates()
	return p.physics_ready and p.coherent and not p.bench_busy and int(p.pending_count)==0 and not p.legacy_busy \
		and p.runtime_publication_sequence==p.runtime_frame_sequence and not p.newer_owner_frame

func _await_publication(label: String) -> bool:
	var deadline: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not _publication_ready(): await process_frame
	return f.expect(_publication_ready(),label+": exact paused native and displayed publication remain usable / "+str(_pause_predicates()))

func _diagnose_contact_erasure() -> void:
	evidence.integrated_before = _pause_predicates()
	evidence.native_before = await _native_cells("before exact contact edit")
	var target := Vector2i(-1,-1)
	for cell: Dictionary in evidence.native_before.get("cells",[]):
		if int(cell.material)==1 and int(cell.y)==373:
			target = Vector2i(int(cell.x),int(cell.y)); break
	if not f.expect(target.x>=0,"real remaining World Wall contact cell is identified"): return
	f.expect(f.host.queue_brush_mutation(target.x,target.y,0,0),"single-cell ordinary Erase command admitted")
	if not await _brush_idle(): return
	evidence.exact_cell_after = await _native_cells("after exact contact edit")
	f.expect(evidence.exact_cell_after.last_result.outcome=="DestinationUnavailable" \
		and evidence.exact_cell_after.world_material_sha256==evidence.native_before.world_material_sha256 \
		and evidence.exact_cell_after.source.world_revision==evidence.native_before.source.world_revision,
		"native protected-overlap refusal preserves both actual World material and publication revision")
	f.bench._brush.value = 1
	f.expect(f.bench.paint(target,0),"ordinary fine Erase stamp overlaps protected contact and empty neighbours")
	if not await _brush_idle(): return
	var coherent_after_fine: bool = await _await_publication("partly protected unchanged brush")
	evidence.fine_stamp_after = await _native_cells("after ordinary fine Erase")
	evidence.final_predicates = _pause_predicates()
	f.expect(evidence.fine_stamp_after.world_material_sha256==evidence.native_before.world_material_sha256 \
		and evidence.fine_stamp_after.source.world_revision==evidence.native_before.source.world_revision,
		"accepted unchanged neighbours do not fabricate a native brush revision")
	f.expect(evidence.fine_stamp_after.source.tick==evidence.native_before.source.tick \
		and evidence.final_predicates.physical_intervals==evidence.integrated_before.physical_intervals \
		and evidence.final_predicates.actor_tick==evidence.integrated_before.actor_tick,
		"protected and unchanged brush controls advance zero native, physical or actor time")
	if not coherent_after_fine: return
	var before_empty: Dictionary = await _native_cells("before ordinary empty-area erase")
	f.expect(f.bench.paint(Vector2i(450,100),0),"ordinary Erase is admitted in an already-empty distant area")
	if not await _brush_idle() or not await _await_publication("unchanged Empty brush"): return
	var after_empty: Dictionary = await _native_cells("after ordinary empty-area erase")
	f.expect(after_empty.world_material_sha256==before_empty.world_material_sha256 \
		and after_empty.source.world_revision==before_empty.source.world_revision,
		"fully unchanged Empty brush preserves the exact native material publication")
	f.expect(f.bench.paint(Vector2i(450,100),7),"ordinary Wood brush makes a real distant World mutation")
	if not await _brush_idle() or not await _await_publication("real Wood brush"): return
	var painted: Dictionary = await _native_cells("after real Wood brush")
	f.expect(painted.control_material==7 and painted.source.world_revision>after_empty.source.world_revision \
		and painted.world_material_sha256!=after_empty.world_material_sha256,
		"actual material creation still advances and displays its native revision")
	f.expect(f.bench.paint(Vector2i(450,100),0),"ordinary Erase removes those actual World Wood cells")
	if not await _brush_idle() or not await _await_publication("real World erasure"): return
	var erased: Dictionary = await _native_cells("after actual World erasure")
	f.expect(erased.control_material==0 and erased.source.world_revision>painted.source.world_revision \
		and erased.world_material_sha256==after_empty.world_material_sha256,
		"actual erasure publishes a new revision and restores exact original World inventory")
	evidence.real_mutation_control = {"empty":after_empty,"painted":painted,"erased":erased}
	await f.validate_quantity_ledger()
	f.validate_physics()
	_native_condition_revision_control()

func _native_condition_revision_control() -> void:
	# Independent same-thread native facade control: repainting the same
	# material can reset a real condition state without changing its ID.
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var adapter: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var sample: Dictionary = {"session":701,"epoch":701,"states":PackedFloat64Array(),
		"geometry":PackedFloat64Array(),"bodies":[]}
	var profile: Dictionary = Profiles.resolve(Profiles.preset(0))
	var options: Dictionary = {"workbench_extent":Vector2i(256,256),"workbench_response":"LA-SELECTIVE",
		"workbench_sample":sample,"region":PackedInt32Array([0,0,256,256]),"intent":"exploratory",
		"definition_hash":"m4-brush-condition-revision-v1".sha256_text(),
		"initial_bodies":PackedFloat32Array(),"workbench_worker_threads":1}
	var token: int = adapter.prepare_liquid_world(world,PackedInt32Array([0,240,256,8,1]),
		profile.packed,PackedInt32Array([1,8,12,0]),PackedInt32Array(),adapter.default_liquid_policy(),options)
	if not f.expect(token>0 and adapter.commit_liquid_world(world,token),
		"independent actual same-World native facade prepares the condition-only control"): return
	if not f.expect(world.simulation_tick() and world.object_shard_attach(Rect2i(0,0,256,256)).get("ok",false),
		"independent actual same-World coordinator attaches for the condition-only control"): return
	var point := Vector2i(30,30)
	f.expect(world.object_shard_edit_cell(point,7,173,91,371).get("ok",false),"native owned policy authors real Wood condition state")
	var before: Dictionary = world.object_shard_inspect_cell(point)
	var before_revision: int = int(world.revision)
	var before_tick: int = int(world.get_tick_index())
	world.emit_disc(point.x,point.y,0,7)
	var after: Dictionary = world.object_shard_inspect_cell(point)
	var changed_revision: int = int(world.revision)
	f.expect(before.material==7 and before.state_b==91 and after.material==7 and after.state_b==0 \
		and after.temperature==371 and changed_revision>before_revision,
		"same-material condition reset remains a real native mutation and advances the facade revision")
	world.emit_disc(point.x,point.y,0,7)
	f.expect(int(world.revision)==changed_revision and world.object_shard_inspect_cell(point)==after,
		"repeating the now-identical material and condition is an actual no-op")
	f.expect(int(world.get_tick_index())==before_tick,"condition-only brush controls advance no semantic time")
	evidence.condition_control = {"before":before,"after":after,"before_revision":before_revision,
		"changed_revision":changed_revision,"unchanged_revision":int(world.revision),"native_tick":before_tick}

func _finish() -> void:
	f.validate_display()
	evidence.display_coherence = f.display_witness()
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-brush-revision-v1","checks":f.checks,
		"failures":f.failures,"evidence":evidence,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"actual ordinary supported Tower, protected/no-op brush revisions, exact paused publication and real material/state mutation controls; no render-refresh workaround"}))
	quit(0 if f.failures.is_empty() else 1)
