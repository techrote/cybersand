extends RefCounted

# A declared, fixed world-space authoring source in the developer painting room.
# It never steps a solver, moves a body, overwrites occupied material or grants
# granular arrival provenance. The existing owner performs the next normal tick.
const MATERIALS: Array[int] = [2,14,29,13,19,23,25,26,27]
const BOUNDS := Rect2i(23,23,979,452)
const BURST_SIZE := Vector2i(4,24)
const STREAM_SIZE := Vector2i(4,1)
const MAX_STREAM_TICKS: int = 600
const MAX_LEDGER: int = 256
const MAX_BODIES: int = 64
const MAX_COUNTER: int = 4_503_599_627_370_496
const CELL_PADDING: float = 0.707106781187

var armed: bool = false
var origin := Vector2i.ZERO
var material: int = 2
var burst_queued: bool = false
var stream_enabled: bool = false
var stream_ticks: int = 0
var attempted: int = 0
var inserted: int = 0
var blocked: int = 0
var source_steps: int = 0
var error: String = ""
var ledger_dropped: int = 0
var _ledger: Array[Dictionary] = []
var _ledger_cursor: int = 0
var _last_session: int = 0
var _last_owner_tick: int = -1
var _bound_session: int = 0

func configure(point: Vector2i, value: int) -> bool:
	if value not in MATERIALS: return _reject("Select a granular powder for the source.")
	if not BOUNDS.encloses(Rect2i(point,BURST_SIZE)): return _reject("Place the complete source inside the painting room.")
	origin=point;material=value;armed=true;burst_queued=false;stream_enabled=false;stream_ticks=0;error="";_bound_session=0
	_record({"kind":"configure","origin":origin,"material":material})
	return true

func queue_burst() -> bool:
	if not armed or not error.is_empty(): return false
	burst_queued=true # Repeated button edges cannot queue unbounded bursts.
	return true

func set_stream(enabled: bool) -> bool:
	if not enabled:
		stream_enabled=false
		return true
	if not armed or not error.is_empty(): return false
	if not stream_enabled: stream_ticks=0
	stream_enabled=true
	return true

func stop() -> void:
	armed=false;burst_queued=false;stream_enabled=false

func clear() -> void:
	stop();origin=Vector2i.ZERO;material=2;stream_ticks=0
	attempted=0;inserted=0;blocked=0;source_steps=0;error=""
	_ledger.clear();_ledger_cursor=0;ledger_dropped=0;_last_session=0;_last_owner_tick=-1;_bound_session=0

func _reject(reason: String) -> bool:
	error=reason;stop()
	return false

func _record(row: Dictionary) -> void:
	if _ledger.size()<MAX_LEDGER:
		_ledger.append(row)
	else:
		_ledger[_ledger_cursor]=row
		_ledger_cursor=(_ledger_cursor+1)%MAX_LEDGER
		ledger_dropped+=1

func _hulls(arena) -> Array:
	var hulls: Array=[]
	if arena.session==null: return hulls
	for rig in arena.session._rigs:
		var bodies: Array=rig.bodies()
		var sizes: PackedVector2Array=rig.body_sizes()
		if bodies.size()!=sizes.size() or hulls.size()+bodies.size()>MAX_BODIES: return []
		for i: int in range(bodies.size()):
			var body: RigidBody2D=bodies[i]
			if not is_instance_valid(body) or not body.get_rid().is_valid() or not sizes[i].is_finite() or sizes[i].x<=0 or sizes[i].y<=0: return []
			var pose: Transform2D=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
			if not pose.is_finite() or absf(pose.determinant())<0.000001: return []
			var inverse: Transform2D=pose.affine_inverse()
			if not inverse.is_finite(): return []
			hulls.append({"inverse":inverse,"half":sizes[i]*0.5})
	return hulls

func _touches_hull(cell: Vector2i, hulls: Array) -> bool:
	for hull: Dictionary in hulls:
		var local: Vector2=Transform2D(hull.inverse)*(Vector2(cell)+Vector2(0.5,0.5))
		var half: Vector2=hull.half
		# Encloses the complete unit cell after rotation; conservative at corners.
		if absf(local.x)<=half.x+CELL_PADDING and absf(local.y)<=half.y+CELL_PADDING: return true
	return false

func _emit(world: Object, hulls: Array, size: Vector2i, owner_tick: int, kind: String) -> bool:
	if attempted>MAX_COUNTER-size.x*size.y: return _reject("Source quantity counter capacity exhausted.")
	var n: int=0
	var placed: int=0
	var occupied: int=0
	var failure: String=""
	for y: int in range(size.y):
		for x: int in range(size.x):
			if not failure.is_empty(): break
			var cell: Vector2i=origin+Vector2i(x,y)
			var before: int=int(world.material_at(cell.x,cell.y))
			if before<0 or before>255:
				failure="Source material query refused."
				break
			n+=1
			if before!=0 or int(world.rigid_body_id_at(cell.x,cell.y))!=0 or _touches_hull(cell,hulls):
				occupied+=1
				continue
			world.emit_disc(cell.x,cell.y,0,material)
			var after: int=int(world.material_at(cell.x,cell.y))
			if after==material: placed+=1
			elif after==0: occupied+=1
			else:
				occupied+=1
				failure="Source write/readback mismatch."
	attempted+=n;inserted+=placed;blocked+=occupied
	_record({"kind":kind,"tick":owner_tick,"origin":origin,"material":material,"requested":size.x*size.y,
		"attempted":n,"inserted":placed,"blocked":occupied,"unprocessed":size.x*size.y-n,"error":failure})
	return _reject(failure) if not failure.is_empty() else true

func before_step(arena) -> bool:
	if not armed or (not burst_queued and not stream_enabled): return true
	if arena==null or arena.session==null or arena._world==null: return _reject("Source owner unavailable.")
	if arena._paused: return true
	if arena._failed or arena._finished: return _reject("Source owner has stopped.")
	var session_id: int=arena.session.get_instance_id()
	if _bound_session!=0 and _bound_session!=session_id: return _reject("Source owner changed. Place and arm the source again.")
	var owner_tick: int=int(arena.session.tick)
	if session_id==_last_session and owner_tick==_last_owner_tick: return true
	var world: Object=arena._world
	if not world.has_method(&"material_at") or not world.has_method(&"rigid_body_id_at") or not world.has_method(&"emit_disc"): return _reject("Source adapter unavailable.")
	if world.has_method(&"has_failed") and bool(world.has_failed()): return _reject("Source world has failed.")
	var hulls: Array=_hulls(arena)
	if hulls.is_empty(): return _reject("Current source body geometry unavailable.")
	_bound_session=session_id;_last_session=session_id;_last_owner_tick=owner_tick;source_steps+=1
	if burst_queued:
		burst_queued=false
		if not _emit(world,hulls,BURST_SIZE,owner_tick,"burst"): return false
	if stream_enabled:
		if not _emit(world,hulls,STREAM_SIZE,owner_tick,"stream"): return false
		stream_ticks+=1
		if stream_ticks>=MAX_STREAM_TICKS: stream_enabled=false
	return true

func receipt() -> Dictionary:
	var rows: Array=[]
	for i: int in range(_ledger.size()):
		rows.append(_ledger[(_ledger_cursor+i)%_ledger.size()].duplicate(true))
	return {"schema":1,"profile":"painting-powder-source/v1","armed":armed,"origin":origin,"material":material,
		"burst_queued":burst_queued,"stream_enabled":stream_enabled,"stream_ticks":stream_ticks,"max_stream_ticks":MAX_STREAM_TICKS,
		"attempted":attempted,"inserted":inserted,"blocked":blocked,"source_steps":source_steps,"error":error,
		"ledger":rows,"ledger_capacity":MAX_LEDGER,"ledger_dropped":ledger_dropped,
		"scope":"Declared developer world source; actual external edits, no physics or arrival-provenance authority."}
