extends RefCounted

# Room-only native-cell sources. This does not extend ordinary rig actions or
# their Sand-only generic effect consumer. Every nozzle is a one-cell source,
# never an overwrite, excavation operation, search or additional recoil owner.
const CADENCE_TICKS: int = 6
const MAX_NOZZLES: int = 3
const WORLD_LIMIT: int = 1024
const MAX_TRACE_CELLS: int = 64
const MAX_READS: int = 1024
const PORT_KEYS: Array[String] = ["q", "e", "s"]
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
var fire_enabled: bool = false
var _identity: Dictionary = {}
var _ports: Dictionary = {}
var _last_tick: int = -1
var _receipts: Array = []
var _totals: Dictionary = {}
var _own_mask_count: int = 1

class Guard extends RefCounted:
	var world: Object
	var reads: int = 0
	var exhausted: bool = false
	func mask(cell: Vector2i) -> int:
		if reads >= MAX_READS:
			exhausted = true
			return -1
		reads += 1
		return int(world.rigid_body_id_at(cell.x, cell.y))
	func material(cell: Vector2i) -> int:
		if reads >= MAX_READS:
			exhausted = true
			return -1
		reads += 1
		return int(world.material_at(cell.x, cell.y))

func _init() -> void:
	reset()

func reset() -> void:
	fire_enabled = false
	_own_mask_count=1
	revoke()
	_last_tick = -1
	_receipts.clear()
	_totals = {"frames":0,"due_frames":0,"requested_nozzles":0,"emitted_cells":0,
		"refused_nozzles":0,"stale_frames":0,"reads":0}

static func valid_ports(ports: Dictionary) -> bool:
	if ports.size() != PORT_KEYS.size(): return false
	for key: Variant in ports:
		if (not key is String and not key is StringName) or str(key) not in PORT_KEYS or not ports[key] is bool:
			return false
	return true

func capture(view: Dictionary, ports: Dictionary) -> void:
	_identity = {"epoch":view.epoch,"control_generation":view.control_generation,
		"last_sequence":view.last_sequence}
	_ports = ports.duplicate(true)

func revoke() -> void:
	_identity.clear()
	_ports.clear()

func snapshot() -> Dictionary:
	return {"fire_enabled":fire_enabled,"cadence_ticks":CADENCE_TICKS,
		"maximum_nozzles":MAX_NOZZLES,"receipts":_receipts.duplicate(true),"totals":_totals.duplicate(true)}

func step(world: Object, index: int, pose: Transform2D, size: Vector2,
		action: Dictionary, controller: Dictionary, force_cap: float, view: Dictionary, authored_profile: Dictionary = {}) -> void:
	_receipts.clear()
	_totals.frames += 1
	var tick: int = int(view.get("tick",-1))
	if tick < 0 or tick <= _last_tick: return
	_last_tick = tick
	# Cadence is sampled, not queued: blocked ports and missed deadlines never
	# accrue a later burst. A copied port level is valid only for this command.
	if tick % CADENCE_TICKS != 0: return
	_totals.due_frames += 1
	if action.is_empty() or _identity.is_empty() or bool(view.get("suspended",true)) or int(view.get("lease_remaining",0)) <= 0:
		return
	for key: String in ["epoch","control_generation","last_sequence"]:
		if view.get(key) != _identity.get(key):
			_totals.stale_frames += 1
			return
	if not Fleet.valid_index(index) or not pose.is_finite() or not size.is_finite() or size.x <= 0 or size.y <= 0 or size.x > 128 or size.y > 128:
		return
	var capabilities: Dictionary=Fleet.capabilities(index)
	var q_material: int=int(authored_profile.get("fleet_dispenser_q",capabilities.dispenser_q))
	var e_material: int=int(authored_profile.get("fleet_dispenser_e",capabilities.dispenser_e))
	var s_material: int=int(authored_profile.get("fleet_dispenser_s",capabilities.dispenser_s))
	var board: bool=str(authored_profile.get("fleet_control_mode","hoverboard" if Fleet.is_hoverboard(index) else "body_thrust"))=="hoverboard"
	var side_jets: bool=bool(authored_profile.get("fleet_side_thrusters",capabilities.side_thrusters))
	_own_mask_count=clampi(int(authored_profile.get("fleet_proxy_count",1)),1,8)
	var nozzles: Array = []
	var half: Vector2 = size*.5
	if q_material!=0 and _ports.q: nozzles.append({"nozzle":"q-left","offset":Vector2(-half.x-2.,0),"material":q_material})
	if e_material!=0 and _ports.e: nozzles.append({"nozzle":"e-right","offset":Vector2(half.x+2.,0),"material":e_material})
	if s_material!=0 and _ports.s: nozzles.append({"nozzle":"s-rear","offset":Vector2(half.x*.65,half.y+3.),"material":s_material})
	var live_force: bool = fire_enabled and force_cap > 0 and float(action.get("effort",1.)) > 0 and Vector2(controller.get("applied_force",Vector2.ZERO)).length_squared() > 0
	if live_force:
		var thrust: float = float(controller.get("thrust",0.))
		if board:
			# Suppress Fire for idle lift compensation. A commanded descent uses
			# the top nozzle; primary lift takes precedence over descent.
			thrust = 1. if bool(action.get("primary",false)) else -Vector2(action.get("move",Vector2.ZERO)).y
		if absf(thrust) > .01:
			nozzles.append({"nozzle":"main-fire","offset":Vector2(0,(half.y+2.)*signf(thrust)),"material":6})
		var side: float = float(controller.get("side_thrust",0.))
		if side_jets and absf(side)>.01:
			nozzles.append({"nozzle":"side-fire","offset":Vector2(-(half.x+2.)*signf(side),0),"material":6})
	var proxy := Guard.new()
	proxy.world = world
	for nozzle: Dictionary in nozzles.slice(0,MAX_NOZZLES):
		_totals.requested_nozzles += 1
		var target: Vector2 = pose * Vector2(nozzle.offset)
		# Validate finite world bounds before narrowing any coordinate to a cell.
		var cell := Vector2i.ZERO
		if _inside(target): cell=Vector2i(floori(target.x),floori(target.y))
		var reason: String = ""
		if world==null or not world.has_method(&"material_at") or not world.has_method(&"rigid_body_id_at") or not world.has_method(&"emit_disc"):
			reason="adapter"
		elif world.has_method(&"has_failed") and bool(world.has_failed()):
			reason="world_failed"
		elif not _inside(target) or not _inside(pose.origin):
			reason="bounds"
		elif not _path_clear(proxy,pose*Vector2(authored_profile.get("fleet_emitter_origin",Vector2.ZERO)),target):
			reason="blocked"
		# emit_disc overwrites: require Empty and no body mask again at the
		# actual write boundary, including after earlier nozzles this frame.
		elif proxy.material(cell)!=0 or proxy.mask(cell)!=0 or proxy.exhausted:
			reason="occupied"
		var changed: int = 0
		if reason.is_empty():
			world.emit_disc(cell.x,cell.y,0,int(nozzle.material))
			changed = int(proxy.material(cell)==int(nozzle.material))
			if changed==0: reason="write_refused"
		_totals.emitted_cells += changed
		_totals.refused_nozzles += int(changed==0)
		_receipts.append({"nozzle":nozzle.nozzle,"material":nozzle.material,"point":cell,
			"tick":tick,"epoch":view.epoch,"control_generation":view.control_generation,
			"sequence":view.last_sequence,"changed_cells":changed,"reason":reason})
	_totals.reads += proxy.reads

func _inside(point: Vector2) -> bool:
	return point.is_finite() and point.x>=0 and point.y>=0 and point.x<WORLD_LIMIT and point.y<WORLD_LIMIT

func _cell_clear(proxy: Guard, cell: Vector2i, own_prefix: bool) -> bool:
	if cell.x<0 or cell.y<0 or cell.x>=WORLD_LIMIT or cell.y>=WORLD_LIMIT: return false
	var mask: int = proxy.mask(cell)
	if mask!=0: return own_prefix and _own_mask(mask)
	return proxy.material(cell)==0

func _own_mask(mask: int) -> bool: return mask>=1 and mask<=_own_mask_count

func _path_clear(proxy: Guard, source: Vector2, target: Vector2) -> bool:
	var cell := Vector2i(floori(source.x),floori(source.y))
	var end := Vector2i(floori(target.x),floori(target.y))
	var own_prefix: bool = _own_mask(proxy.mask(cell))
	if not _cell_clear(proxy,cell,own_prefix): return false
	var ray: Vector2 = target-source
	var direction := Vector2i(signi(end.x-cell.x),signi(end.y-cell.y))
	var delta_x: float = 1./absf(ray.x) if direction.x!=0 else INF
	var delta_y: float = 1./absf(ray.y) if direction.y!=0 else INF
	var next_x: float = ((cell.x+1-source.x) if direction.x>0 else (source.x-cell.x))*delta_x if direction.x!=0 else INF
	var next_y: float = ((cell.y+1-source.y) if direction.y>0 else (source.y-cell.y))*delta_y if direction.y!=0 else INF
	for _index: int in range(MAX_TRACE_CELLS):
		if cell==end: return not proxy.exhausted
		if absf(next_x-next_y)<.000001:
			var side_x: Vector2i = cell+Vector2i(direction.x,0)
			var side_y: Vector2i = cell+Vector2i(0,direction.y)
			if not _cell_clear(proxy,side_x,own_prefix) or not _cell_clear(proxy,side_y,own_prefix): return false
			if not _own_mask(proxy.mask(side_x)) or not _own_mask(proxy.mask(side_y)): own_prefix=false
			cell += direction
			next_x += delta_x
			next_y += delta_y
		elif next_x<next_y:
			cell.x += direction.x
			next_x += delta_x
		else:
			cell.y += direction.y
			next_y += delta_y
		if not _cell_clear(proxy,cell,own_prefix): return false
		if not _own_mask(proxy.mask(cell)): own_prefix=false
	return false
