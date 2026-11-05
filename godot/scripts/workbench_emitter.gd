extends RefCounted

# Immutable nozzle intents originate at the leased physical actor. Only the
# cellular owner may trace occupancy and insert a cell after installing its mask.
const CADENCE_TICKS: int = 6
const MAX_NOZZLES: int = 3
const MAX_TRACE_CELLS: int = 64
const MAX_READS: int = 1024
const MAX_CELLS_PER_NOZZLE: int = 8

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
	var customization: Dictionary = profile.get("fleet_customization", {})
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
		# Overrides change an existing authored outlet, never grant a new one.
		if material != 0:
			material = int(customization.get(port + "_material", material))
		if material != 0 and binding.ports[port]:
			nozzles.append({"nozzle":location[1], "material":material, "target":pose * Vector2(location[2]),
				"amount":amount_for_tick(float(customization.get(port + "_amount", 1.0)), int(identity.tick))})
	var live_force: bool = binding.fire and float(profile.fleet_force) > 0 and float(action.get("effort",1.0)) > 0 and Vector2(controller.applied_force).length_squared() > 0
	if live_force:
		var thrust: float = controller.thrust
		if profile.fleet_control_mode == "hoverboard":
			thrust = 1.0 if action.get("primary",false) else -Vector2(action.move).y
		if absf(thrust) > 0.01:
			nozzles.append({"nozzle":"main-fire", "material":6, "target":pose * Vector2(0,(half.y+2.0)*signf(thrust)),
				"amount":amount_for_tick(float(customization.get("fire_amount", 1.0)), int(identity.tick))})
		var side: float = controller.side_thrust
		if profile.fleet_side_thrusters and absf(side) > 0.01:
			nozzles.append({"nozzle":"side-fire", "material":6, "target":pose * Vector2(-(half.x+2.0)*signf(side),0),
				"amount":amount_for_tick(float(customization.get("fire_amount", 1.0)), int(identity.tick))})
	var bounded: Array = []
	for nozzle: Dictionary in nozzles:
		if int(nozzle.amount) > 0 and bounded.size() < MAX_NOZZLES: bounded.append(nozzle)
	for nozzle: Dictionary in bounded:
		nozzle.merge(identity)
		nozzle.source = pose * Vector2(profile.fleet_emitter_origin)
	return bounded


static func amount_for_tick(rate: float, tick: int) -> int:
	if not is_finite(rate) or rate < 0.0 or rate > MAX_CELLS_PER_NOZZLE or tick < 0: return 0
	# Fractional rates have a deterministic pulse schedule. No unused source
	# credit accumulates while a control is released or a session is paused.
	var cadence: int = tick / CADENCE_TICKS
	return clampi(floori((cadence + 1) * rate) - floori(cadence * rate), 0, MAX_CELLS_PER_NOZZLE)


static func valid_material(material: Variant) -> bool:
	return _integer(material, 1, CyberCellWorld.LAST_MATERIAL) and int(material) != 10


static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value == floorf(float(value)) and value >= low and value <= high


static func candidate_cells(source: Vector2, target: Vector2, amount: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if amount < 0 or amount > MAX_CELLS_PER_NOZZLE: return result
	var origin := Vector2i(floori(target.x), floori(target.y))
	var ray := target - source
	var forward := Vector2i(signi(ray.x), 0) if absf(ray.x) >= absf(ray.y) else Vector2i(0, signi(ray.y))
	if forward == Vector2i.ZERO: forward = Vector2i.DOWN
	var side := Vector2i(-forward.y, forward.x)
	# One finite fan, not a free-volume search. The first endpoint is exactly
	# the legacy single-cell endpoint. Every extra endpoint is traced afresh.
	var offsets: Array[Vector2i] = [Vector2i.ZERO, forward, side, -side,
		forward + side, forward - side, forward * 2, forward * 2 + side]
	for index: int in range(amount): result.append(origin + offsets[index])
	return result


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
		var amount: Variant = intent.get("amount", 1)
		var requested: int = int(amount) if _integer(amount, 0, MAX_CELLS_PER_NOZZLE) else 0
		if not _inside(intent.source, extent) or not _inside(intent.target, extent): reason = "bounds"
		elif id <= 0 or proxy.first_proxy < 1 or proxy.count < 1 or proxy.first_proxy + proxy.count - 1 > 64 \
			or int(intent.get("first_proxy", 0)) != proxy.first_proxy or int(intent.get("count", 0)) != proxy.count: reason = "identity"
		elif not valid_material(intent.get("material")): reason = "material"
		elif not _integer(amount, 0, MAX_CELLS_PER_NOZZLE): reason = "amount"
		elif requested == 0: reason = "disabled"
		var changed: int = 0
		var attempted: int = 0
		var reasons: Dictionary = {}
		if reason.is_empty():
			cell = Vector2i(floori(intent.target.x), floori(intent.target.y))
			var endpoints: Array[Vector2i] = candidate_cells(intent.source, intent.target, requested)
			# Farthest first keeps this finite source fan from blocking its own
			# later rays. Existing material and all masks still block every ray.
			# A one-cell source keeps the original endpoint and ray unchanged.
			endpoints.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(intent.source) \
					> (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(intent.source))
			for endpoint: Vector2i in endpoints:
				attempted += 1
				var endpoint_reason := ""
				var point := Vector2(endpoint) + Vector2(0.5, 0.5)
				# Preserve the exact legacy ray for its first endpoint.
				if endpoint == cell: point = intent.target
				if not _inside(point, extent): endpoint_reason = "bounds"
				elif not _path_clear(proxy, intent.source, point): endpoint_reason = "read_budget" if proxy.exhausted else "blocked"
				elif proxy.material(endpoint) != 0 or proxy.mask(endpoint) != 0: endpoint_reason = "read_budget" if proxy.exhausted else "occupied"
				# Reserve the authoritative post-write read inside the same budget.
				elif proxy.exhausted or proxy.reads >= MAX_READS: endpoint_reason = "read_budget"
				else:
					world.emit_disc(endpoint.x, endpoint.y, 0, int(intent.material))
					var inserted := int(proxy.material(endpoint) == int(intent.material))
					changed += inserted
					if inserted == 0: endpoint_reason = "write_refused"
				if not endpoint_reason.is_empty():
					reasons[endpoint_reason] = int(reasons.get(endpoint_reason, 0)) + 1
					if reason.is_empty(): reason = endpoint_reason
		if changed == requested and requested > 0: reason = ""
		elif changed > 0: reason = "partial"
		elif not reason.is_empty() and reasons.is_empty(): reasons[reason] = requested
		receipts.append({"instance_id":id,"epoch":intent.get("epoch", -1),"sequence":intent.get("sequence", -1),"tick":intent.get("tick", -1),
			"nozzle":intent.get("nozzle", ""),"material":intent.get("material", -1),"point":cell,"changed_cells":changed,"reason":reason,
			"requested_cells":requested,"attempted_cells":attempted,"refused_cells":requested - changed,
			"endpoint_reasons":reasons,"occupancy_reads":proxy.reads})
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
