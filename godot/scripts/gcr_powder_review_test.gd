extends RefCounted

# Developer-room source authoring only. The arena still owns every native/Rapier step.
const ORIGIN := Vector2i(514,224)
const POSITION := Vector2(512,256)
const MATERIAL := 2
const TOTAL_TICKS := 1800
const STREAM_TICKS := 600
var mode: String = ""
var ticks: int = 0
var modified: bool = false
var error: String = ""
var attempted: int = 0
var inserted: int = 0
var blocked: int = 0
var ledger: Array[Dictionary] = []
var initial: Dictionary = {}
var controls: Dictionary = {}
var native_gravity: float = -1.0
var selector: String = ""
var _body: RigidBody2D

func active() -> bool: return not mode.is_empty()

func clear() -> void:
	mode=""; ticks=0; modified=false; error=""
	attempted=0; inserted=0; blocked=0; ledger.clear(); initial.clear(); controls.clear()
	native_gravity=-1.0; selector=""
	_body=null

func setup(arena, selected_mode: String, options: Dictionary) -> bool:
	clear()
	if selected_mode not in ["burst","stream"]: return false
	mode=selected_mode; controls=options.duplicate(true)
	_body=arena.session.bodies()[0]
	var world: Object = arena._world
	if not world.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0): return _fail("room clear refused")
	for rect: Rect2i in [Rect2i(16,475,992,21),Rect2i(16,16,6,480),Rect2i(1002,16,6,480),Rect2i(16,16,992,6)]:
		if not world.diagnostic_fill_rect(rect.position,rect.size,58): return _fail("room boundary refused")
	arena._sync_terrain()
	if mode=="burst" and not _emit(world,Vector2i(4,24),-1): return false
	arena.session.bridge.refresh_all_states()
	arena.session._rigs[0].refresh_observation()
	var body: RigidBody2D = arena.session.bodies()[0]
	var transform: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	var diagnostics: Dictionary = world.gcr_diagnostics()
	selector=str(diagnostics.get("granular_events",""))
	var rest: Dictionary = world.gcr_rest_receipt()
	if rest.get("bodies",[]).is_empty(): return _fail("native gravity receipt unavailable")
	native_gravity=float(rest.bodies[0].gravity)
	initial={"position":transform.origin,"rotation":transform.get_rotation(),
		"velocity":PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
		"omega":PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY),
		"mass":body.mass,"inertia":PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA),
		"gravity":body.gravity_scale*980.0,"native_gravity":native_gravity,"native_hash":world.get_physical_state_hash()}
	if transform.origin!=POSITION or transform.get_rotation()!=0.0 or initial.velocity!=Vector2.ZERO or initial.omega!=0.0 or native_gravity!=0.0 or initial.gravity!=0.0:
		return _fail("initial body or gravity mismatch")
	return true

func _fail(reason: String) -> bool:
	error=reason
	return false

func _emit(world: Object, size: Vector2i, tick: int) -> bool:
	var before: Dictionary = world.diagnostic_snapshot(ORIGIN,size,false,false)
	if not before.get("cells") is PackedByteArray or before.cells.size()!=size.x*size.y: return _fail("source read refused")
	var placed: int = 0
	var occupied: int = 0
	# Between owner steps the native mask describes the preceding sample. Also
	# guard the actual current Kestrel hull, conservatively expanded by a cell.
	var body_transform: Transform2D = PhysicsServer2D.body_get_state(_body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	var inverse: Transform2D = body_transform.affine_inverse()
	for y: int in range(size.y):
		for x: int in range(size.x):
			var index: int = y*size.x+x
			if int(before.cells[index])!=0:
				occupied+=1
				continue
			var cell := ORIGIN+Vector2i(x,y)
			var local: Vector2 = inverse*(Vector2(cell)+Vector2(0.5,0.5))
			if absf(local.x)<=5.5 and absf(local.y)<=4.0:
				occupied+=1
				continue
			if not world.diagnostic_fill_rect(cell,Vector2i.ONE,MATERIAL): return _fail("source write refused")
			var after: Dictionary = world.diagnostic_snapshot(cell,Vector2i.ONE,false,false)
			if not after.get("cells") is PackedByteArray or after.cells.size()!=1: return _fail("source readback refused")
			if int(after.cells[0])==MATERIAL: placed+=1
			elif int(after.cells[0])==0: occupied+=1 # Transient body masks refuse authoring.
			else: return _fail("source changed during serialized authoring")
	var count: int = size.x*size.y
	attempted+=count; inserted+=placed; blocked+=occupied
	ledger.append({"tick":tick,"attempted":count,"inserted":placed,"blocked":occupied})
	return true

func before_step(world: Object) -> bool:
	if not active() or modified or not error.is_empty() or ticks>=TOTAL_TICKS: return false
	return _emit(world,Vector2i(4,1),ticks) if mode=="stream" and ticks<STREAM_TICKS else true

func after_step() -> void: ticks+=1

func status(paused: bool) -> String:
	return "modified-reset-required" if modified else "failed" if not error.is_empty() else "complete" if ticks>=TOTAL_TICKS else "paused" if paused else "running"

func receipt(paused: bool) -> Dictionary:
	return {"schema":1,"profile":"powder-review-v1","mode":mode,"ticks":ticks,"total_ticks":TOTAL_TICKS,
		"modified":modified,"error":error,"status":status(paused),
		"initial":initial.duplicate(true),"controls":controls.duplicate(true),"selector":selector,"native_gravity":native_gravity,
		"material":MATERIAL,"source_origin":ORIGIN,"burst_size":Vector2i(4,24),"stream_size":Vector2i(4,1),"stream_ticks":STREAM_TICKS,
		"attempted":attempted,"inserted":inserted,"blocked":blocked,"ledger":ledger.duplicate(true),
		"scope":"Repeatable developer loading setup; source edits are explicit. Native hash excludes transient coupled history; no scientific acceptance or complete replay claim."}
