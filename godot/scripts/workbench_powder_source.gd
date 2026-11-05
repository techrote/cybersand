extends RefCounted

# Owned exclusively by the cellular worker. Source edits enter Empty cells
# only, and carry no arrival provenance. A repeated B coalesces to one burst.
const MATERIALS := [2,14,29,13,19,23,25,26,27]
const BURST_SIZE := Vector2i(4,24)
const STREAM_SIZE := Vector2i(4,1)
const MAX_STREAM_TICKS := 600
var _point := Vector2i.ZERO
var _material := 0
var _burst := false
var _stream := false
var _ticks := 0
var _inserted := 0
var _blocked := 0

static func valid(point: Vector2i, material: int, extent: Vector2i) -> bool:
	return material in MATERIALS and Rect2i(Vector2i.ZERO,extent).encloses(Rect2i(point,BURST_SIZE))

func reset() -> void:
	_point = Vector2i.ZERO
	_material = 0
	_burst = false
	_stream = false
	_ticks = 0
	_inserted = 0
	_blocked = 0

func command(request: Dictionary) -> void:
	match request.command:
		"configure":
			_point = request.origin
			_material = request.material
			_burst = false
			_stream = false
			_ticks = 0
		"burst": _burst = _material != 0
		"stream":
			if not _stream: _ticks = 0
			_stream = _material != 0
		"stop":
			_burst = false
			_stream = false

func before_tick(world: Object, sample: Dictionary) -> void:
	if not _burst and not _stream: return
	var hulls: Array[Dictionary] = []
	# Workbench proxy tuples extend the legacy rectangle with actual
	# inertia, COM, friction, timestep and session (17 values per proxy).
	var states: PackedFloat64Array = sample.states
	for offset: int in range(0,states.size(),CyberRigidBodyCoupling.GCR_INPUT_STRIDE):
		var pose := Transform2D(states[offset+3],Vector2(states[offset+1],states[offset+2]))
		hulls.append({"inverse":pose.affine_inverse(),"half":Vector2(states[offset+4],states[offset+5])*0.5})
	if _burst:
		_emit(world,hulls,BURST_SIZE)
		_burst = false
	if _stream:
		_emit(world,hulls,STREAM_SIZE)
		_ticks += 1
		if _ticks >= MAX_STREAM_TICKS: _stream = false

func _emit(world: Object, hulls: Array[Dictionary], size: Vector2i) -> void:
	for dy: int in size.y:
		for dx: int in size.x:
			var point := _point + Vector2i(dx,dy)
			if world.material_at(point.x,point.y) != 0 or world.rigid_body_id_at(point.x,point.y) != 0 or _touches(point,hulls):
				_blocked += 1
				continue
			world.emit_disc(point.x,point.y,0,_material)
			if world.material_at(point.x,point.y) == _material: _inserted += 1
			else: _blocked += 1

func _touches(point: Vector2i, hulls: Array[Dictionary]) -> bool:
	for hull: Dictionary in hulls:
		var local: Vector2 = Transform2D(hull.inverse) * (Vector2(point) + Vector2(0.5,0.5))
		var half: Vector2 = hull.half
		if absf(local.x) <= half.x + 0.70710679 and absf(local.y) <= half.y + 0.70710679: return true
	return false

func receipt() -> Dictionary:
	return {"armed":_material != 0,"origin":_point,"material":_material,"burst_queued":_burst,
		"stream_enabled":_stream,"stream_ticks":_ticks,"max_stream_ticks":MAX_STREAM_TICKS,
		"attempted":_inserted+_blocked,"inserted":_inserted,"blocked":_blocked}
