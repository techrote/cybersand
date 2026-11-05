extends RefCounted

# Worker-owned value controllers over existing native parcels. This object owns
# no World, scene node, rigid body or replacement material simulation.
const MAX_PLAYERS: int = 8
const MAX_LEASE: int = 6
const MAX_BUTTON_EDGES: int = 32
const BUTTONS: Array[String] = ["primary","secondary","auxiliary"]
const MODELS := {"dryswarm":2,"liquidswarm":3}
var _players: Dictionary = {}
var _extent := Vector2i.ZERO
var _run_id: String = ""
var _epoch: int = 0
var _tick: int = 0

static func _integer(v: Variant, low: int, high: int) -> bool:
	return v is int and v >= low and v <= high

static func _new_player(id: int, model: String, position: Vector2) -> Dictionary:
	var issued := PackedInt64Array()
	issued.resize(MAX_LEASE+1); issued.fill(-1)
	return {"id":id,"model":model,"position":position,"spawn":position,"seeded":false,
		"generation":0,"sequence":-1,"deadline":-1,"command":{},"issued":issued,
		"edges":[],"accepted":{},"applied":{},"field":{},"error":""}

func configure(definitions: Array, extent: Vector2i, run_id: String, epoch: int, previous: Dictionary = {}) -> String:
	if definitions.size() > MAX_PLAYERS or extent.x < 1 or extent.y < 1 or extent.x > 2048 or extent.y > 2048 \
		or run_id.is_empty() or run_id.length() > 128 or epoch < 1:
		return "material_player_configuration"
	var next: Dictionary = {}
	for value: Variant in definitions:
		if not value is Dictionary or not _integer(value.get("instance_id"),1,2147483646) \
			or str(value.get("model","")) not in MODELS or not value.get("position") is Vector2:
			return "material_player_definition"
		var id: int = value.instance_id
		var model: String = value.model
		var position: Vector2 = value.position
		if next.has(id) or not position.is_finite() or not Rect2(Vector2.ZERO,Vector2(extent)).encloses(Rect2(position-Vector2(8,8),Vector2(16,16))):
			return "material_player_position"
		if value.has("material_id") and value.material_id != MODELS[model]: return "material_player_material"
		var player := _new_player(id,model,position)
		var old: Dictionary = previous.get("players",{}).get(id,{})
		if old.get("model") == model:
			var centre: Variant = old.get("position")
			if not centre is Vector2 or not centre.is_finite() or not Rect2(Vector2.ZERO,Vector2(extent)).has_point(centre):
				return "material_player_retained_position"
			player.position = centre
			player.seeded = bool(old.get("seeded",false))
			player.field = old.get("field",{}).duplicate(true)
		next[id] = player
	_players = next
	_extent = extent
	_run_id = run_id
	_epoch = epoch
	_tick = 0
	return ""

func seed_pending(world: Object) -> Dictionary:
	var rows: Array = []
	for id: int in _players:
		var player: Dictionary = _players[id]
		if player.seeded: continue
		var inserted: int = 0
		var refused: int = 0
		var origin := Vector2i(Vector2(player.spawn).round())-Vector2i(8,8)
		for y: int in 16:
			for x: int in 16:
				var point := origin+Vector2i(x,y)
				if int(world.material_at(point.x,point.y)) != 0 or int(world.rigid_body_id_at(point.x,point.y)) != 0:
					refused += 1
					continue
				world.emit_disc(point.x,point.y,0,int(MODELS[player.model]))
				var changed: int = int(int(world.material_at(point.x,point.y)) == int(MODELS[player.model]))
				inserted += changed
				if changed == 0: refused += 1
		player.seeded = true
		rows.append({"instance_id":id,"material":MODELS[player.model],"requested":256,"inserted":inserted,"refused":refused})
	return {"players":rows,"kind":"explicit-development-spawn","material_replenishment":false}

func export_state() -> Dictionary:
	var values: Dictionary = {}
	for id: int in _players:
		var p: Dictionary = _players[id]
		values[id] = {"model":p.model,"position":p.position,"spawn":p.spawn,"seeded":p.seeded,"field":p.field.duplicate(true)}
	return {"players":values}

func _token(player: Dictionary, observed: int) -> String:
	return "%s:%d:%d:%d:%d" % [_run_id,_epoch,int(player.id),int(player.generation),observed]

func publish(tick: int, paused: bool = false, failed: bool = false) -> Dictionary:
	_tick = tick
	var actors: Array = []
	for id: int in _players:
		var p: Dictionary = _players[id]
		p.issued[tick % (MAX_LEASE+1)] = tick
		actors.append({"version":1,"representation":"native-material-field","model":p.model,
			"instance_id":id,"actor_id":id,"run_id":_run_id,"epoch":_epoch,"tick":tick,
			"observation_id":_token(p,tick),"control_generation":p.generation,"last_sequence":p.sequence,
			"position":p.position,"velocity":Vector2.ZERO,"rotation":0.0,"angular_velocity":0.0,
			"suspended":paused or failed,"lease_remaining":maxi(0,int(p.deadline)-tick),
			"material":MODELS[p.model],"field":p.field.duplicate(true),"error":p.error,
			"pending_input_edges":p.edges.size(),"scope":"matching local material; no persistent parcel identity"})
	return {"version":1,"run_id":_run_id,"epoch":_epoch,"tick":tick,"actors":actors}

static func make_command(view: Dictionary, sequence: int, action: Dictionary, lease: int = MAX_LEASE) -> Dictionary:
	return {"version":1,"kind":"player_material_field_action","run_id":view.get("run_id",""),
		"epoch":view.get("epoch",-1),"actor_id":view.get("instance_id",-1),"sequence":sequence,
		"observed_tick":view.get("tick",-1),"observation_id":view.get("observation_id",""),
		"lease_ticks":lease,"action":action.duplicate(true)}

func submit(command: Dictionary, tick: int, allowed: bool = true) -> Dictionary:
	var fields := ["version","kind","run_id","epoch","actor_id","sequence","observed_tick","observation_id","lease_ticks","action"]
	if not allowed: return {"accepted":false,"reason":"paused_or_unavailable"}
	if command.size() != fields.size() or not command.has_all(fields): return {"accepted":false,"reason":"fields"}
	if not _integer(command.version,1,1) or command.kind != "player_material_field_action" or command.run_id != _run_id \
		or not _integer(command.epoch,_epoch,_epoch) or not _integer(command.actor_id,1,2147483646) or not _players.has(command.actor_id):
		return {"accepted":false,"reason":"identity"}
	var p: Dictionary = _players[int(command.actor_id)]
	if not _integer(command.sequence,0,9007199254740991) or command.sequence <= p.sequence \
		or not _integer(command.observed_tick,maxi(0,tick-MAX_LEASE),tick) or not _integer(command.lease_ticks,1,MAX_LEASE):
		return {"accepted":false,"reason":"sequence_or_lease"}
	var observed: int = command.observed_tick
	if p.issued[observed % (MAX_LEASE+1)] != observed or command.observation_id != _token(p,observed) or observed+int(command.lease_ticks) <= tick:
		return {"accepted":false,"reason":"unissued_or_expired"}
	if not command.action is Dictionary: return {"accepted":false,"reason":"action"}
	var action: Dictionary = command.action
	for key: Variant in action:
		if str(key) not in ["move","aim","effort","trim","primary","secondary","auxiliary"]: return {"accepted":false,"reason":"action_key"}
	var move: Variant = action.get("move",Vector2.ZERO)
	if not move is Vector2 or not move.is_finite() or move.length_squared() > 1.000001: return {"accepted":false,"reason":"direction"}
	var aim: Variant = action.get("aim",Vector2.ZERO)
	if not aim is Vector2 or not aim.is_finite(): return {"accepted":false,"reason":"aim"}
	for scalar: String in ["effort","trim"]:
		if not action.has(scalar): continue
		var value: Variant = action[scalar]
		if not (value is int or value is float) or not is_finite(value) or value < (-1.0 if scalar == "trim" else 0.0) or value > 1.0:
			return {"accepted":false,"reason":"action_scalar"}
	var normalized := {"move":move}
	var edges: Array = []
	for button: String in BUTTONS:
		if action.has(button) and not action[button] is bool: return {"accepted":false,"reason":"button"}
		normalized[button] = bool(action.get(button,false))
		if normalized[button] != bool(p.accepted.get(button,false)): edges.append({"button":button,"pressed":normalized[button]})
	if p.edges.size()+edges.size() > MAX_BUTTON_EDGES: return {"accepted":false,"reason":"edge_capacity"}
	p.edges.append_array(edges)
	p.accepted = normalized.duplicate(true)
	p.command = normalized
	p.sequence = command.sequence
	p.deadline = observed+int(command.lease_ticks)
	p.error = ""
	return {"accepted":true,"reason":"","instance_id":int(command.actor_id),"sequence":int(command.sequence)}

func cancel(instance_id: int = -1) -> void:
	for id: int in _players:
		if instance_id >= 0 and id != instance_id: continue
		var p: Dictionary = _players[id]
		p.command = {}; p.edges = []; p.accepted = {}; p.applied = {}; p.deadline = -1
		p.generation += 1
		p.issued.fill(-1)

func reset_player(instance_id: int, position: Vector2) -> bool:
	if not _players.has(instance_id) or not position.is_finite() \
		or not Rect2(Vector2.ZERO,Vector2(_extent)).encloses(Rect2(position-Vector2(8,8),Vector2(16,16))): return false
	cancel(instance_id)
	_players[instance_id].position = position
	return true

func advance(world: Object, tick: int, paused: bool = false) -> Dictionary:
	_tick = tick
	var results: Array = []
	if paused:
		cancel()
		return {"accepted":true,"players":results}
	for id: int in _players:
		var p: Dictionary = _players[id]
		if not p.command.is_empty() and p.deadline < tick+1: cancel(id)
		if p.command.is_empty(): continue
		var changed: Dictionary = {}
		while not p.edges.is_empty():
			var edge: Dictionary = p.edges[0]
			if changed.has(edge.button): break
			p.edges.pop_front(); p.applied[edge.button] = edge.pressed; changed[edge.button] = true
		var mode: int = 3 if p.applied.get("auxiliary",false) else (2 if p.applied.get("secondary",false) else (1 if p.applied.get("primary",false) else 0))
		var receipt: Dictionary = world.apply_player_material_field(Vector2i(Vector2(p.position).round()),Vector2(p.command.move),int(MODELS[p.model]),mode,posmod(tick,2147483648))
		p.field = receipt.duplicate(true)
		if not receipt.get("accepted",false):
			p.error = "Material field refused: "+str(receipt.get("reason","unknown"))
			cancel(id)
			return {"accepted":false,"reason":p.error,"instance_id":id,"players":results}
		if int(receipt.get("observed_cells",0)) > 0:
			var centroid: Vector2 = receipt.get("centroid",p.position)
			if centroid.is_finite(): p.position = Vector2(p.position).move_toward(centroid,4.0)
		results.append({"instance_id":id,"field":receipt.duplicate(true)})
	return {"accepted":true,"players":results}
