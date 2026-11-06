extends RefCounted

# Immutable nozzle intents originate at the leased physical actor. Only the
# cellular owner may trace occupancy and insert a cell after installing its mask.
const CADENCE_TICKS: int = 6
const MAX_NOZZLES: int = 3
const MAX_TRACE_CELLS: int = 64
const MAX_READS: int = 1024

class Guard extends RefCounted:
	var world: Object
	var extent: Vector2i
	var first_proxy: int
	var count: int
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


static func valid_ports(ports: Dictionary) -> bool:
	if ports.size() != 4: return false
	for key: String in ["q", "e", "s", "boost"]:
		if not ports.get(key) is bool: return false
	return true


static func intents(rig, pose: Transform2D, binding: Dictionary, identity: Dictionary) -> Array:
	var profile: Dictionary = rig._profile
	var action: Dictionary = rig._action
	if action.is_empty() or rig._player_controller == null: return []
	var controller: Dictionary = rig._player_controller.observation()
	var half: Vector2 = rig._sizes[0] * 0.5
	var nozzles: Array[Dictionary] = []
	for location: Array in [
			["q", "q-left", Vector2(-half.x-2.0,0)],
			["e", "e-right", Vector2(half.x+2.0,0)],
			["s", "s-rear", Vector2(half.x*0.65,half.y+3.0)]]:
		var port: String = location[0]
		var material: int = profile.get("fleet_dispenser_" + port, 0)
		if material != 0 and binding.ports[port]:
			nozzles.append({"nozzle":location[1], "material":material, "target":pose * Vector2(location[2])})
	var live_force: bool = binding.fire and float(profile.fleet_force) > 0 and float(action.get("effort",1.0)) > 0 and Vector2(controller.applied_force).length_squared() > 0
	if live_force:
		var thrust: float = controller.thrust
		if profile.fleet_control_mode == "hoverboard":
			thrust = 1.0 if action.get("primary",false) else -Vector2(action.move).y
		if absf(thrust) > 0.01:
			nozzles.append({"nozzle":"main-fire", "material":6, "target":pose * Vector2(0,(half.y+2.0)*signf(thrust))})
		var side: float = controller.side_thrust
		if profile.fleet_side_thrusters and absf(side) > 0.01:
			nozzles.append({"nozzle":"side-fire", "material":6, "target":pose * Vector2(-(half.x+2.0)*signf(side),0)})
	var bounded: Array = nozzles.slice(0, MAX_NOZZLES)
	for nozzle: Dictionary in bounded:
		nozzle.merge(identity)
		nozzle.source = pose * Vector2(profile.fleet_emitter_origin)
	return bounded


static func apply(world: Object, emitters: Array, extent: Vector2i) -> Array:
	var receipts: Array = []
	if emitters.size() > 8 * MAX_NOZZLES or world == null or world.has_failed(): return receipts
	var guards: Dictionary = {}
	for intent: Variant in emitters:
		if not intent is Dictionary or not intent.get("source") is Vector2 or not intent.get("target") is Vector2: continue
		var id: int = int(intent.get("instance_id",-1))
		if not guards.has(id):
			var guard := Guard.new()
			guard.world = world
			guard.extent = extent
			guard.first_proxy = int(intent.get("first_proxy",0))
			guard.count = int(intent.get("count",0))
			guards[id] = guard
		var proxy: Guard = guards[id]
		var reason: String = ""
		var cell := Vector2i.ZERO
		if not _inside(intent.source, extent) or not _inside(intent.target, extent): reason = "bounds"
		elif proxy.first_proxy < 1 or proxy.count < 1 or proxy.first_proxy + proxy.count - 1 > 64: reason = "identity"
		elif intent.get("material") not in [3,6,8,12,26]: reason = "material"
		else:
			cell = Vector2i(floori(intent.target.x), floori(intent.target.y))
			if not _path_clear(proxy,intent.source,intent.target): reason = "blocked"
			elif proxy.material(cell) != 0 or proxy.mask(cell) != 0 or proxy.exhausted: reason = "occupied"
		var changed: int = 0
		var ballistic: bool = int(intent.material) == 3 and world.has_method(&"get_water_spray") 			and bool(world.get_water_spray().get("ballistic_enabled",false))
		if reason.is_empty() and ballistic:
			# WCX/BW-001: a Water nozzle fires an owned parcel along the nozzle axis.
			var axis: Vector2 = (intent.target - intent.source).normalized()
			var speed: float = float(world.get_water_spray().settings.get("nozzle_speed",2.5))
			var outcome: String = world.inject_water_parcel(Vector2(cell)+Vector2(0.5,0.5), axis*speed, 255)
			changed = int(outcome == "launched")
			if changed == 0: reason = "parcel_" + outcome
		elif reason.is_empty():
			world.emit_disc(cell.x, cell.y, 0, int(intent.material))
			changed = int(int(world.material_at(cell.x,cell.y)) == int(intent.material))
			if changed == 0: reason = "write_refused"
		receipts.append({"instance_id":id,"epoch":intent.epoch,"sequence":intent.sequence,"tick":intent.tick,
			"nozzle":intent.nozzle,"material":intent.material,"point":cell,"changed_cells":changed,"reason":reason})
	return receipts


static func _inside(point: Vector2, extent: Vector2i) -> bool:
	return point.is_finite() and point.x>=0 and point.y>=0 and point.x<extent.x and point.y<extent.y

static func _cell_clear(proxy: Guard, cell: Vector2i, own_prefix: bool) -> bool:
	if cell.x<0 or cell.y<0 or cell.x>=proxy.extent.x or cell.y>=proxy.extent.y: return false
	var mask: int = proxy.mask(cell)
	if mask!=0: return own_prefix and _own_mask(proxy,mask)
	return proxy.material(cell)==0

static func _own_mask(guard: Guard, mask: int) -> bool: return mask>=guard.first_proxy and mask<guard.first_proxy+guard.count

static func _path_clear(proxy: Guard, source: Vector2, target: Vector2) -> bool:
	var cell := Vector2i(floori(source.x),floori(source.y))
	var end := Vector2i(floori(target.x),floori(target.y))
	var own_prefix: bool = _own_mask(proxy,proxy.mask(cell))
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
			if not _own_mask(proxy,proxy.mask(side_x)) or not _own_mask(proxy,proxy.mask(side_y)): own_prefix=false
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
		if not _own_mask(proxy,proxy.mask(cell)): own_prefix=false
	return false
