class_name CyberPlayerPlaygroundRuntime
extends Node2D

# The mechanical lane reuses the ACT-004/005 synchronous owner. The material
# lane exclusively owns a separate native World; no cells become rigid bodies.
const Course = preload("res://scripts/player_playground_course.gd")
const WorldSetup = preload("res://scripts/player_playground_world.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const UsableCatalog = preload("res://scripts/usable_catalog.gd")
const MaterialUsables = preload("res://scripts/usable_runtime.gd")
const MAX_LEASE: int = 6
const MAX_BUTTON_EDGES: int = 32
const BUTTON_KEYS: Array[String] = ["primary", "secondary", "auxiliary", "tool", "usable_alternate"]
const SWARM_ORIGIN := Vector2(178, 304)

var selection: StringName = &""
var map_id: StringName = &"mixed"
var water_solver: int = 0
var authoring_revision: int = 0
var usable_index: int = -1
var _material_usables := MaterialUsables.new()
var _usable_previous: bool = false
var _alternate_previous: bool = false
var epoch: int = 0
var tick: int = 0
var paused: bool = false
var failed: bool = false
var last_error: String = ""
var _arena: CyberPhysicalActorArena
var _world: Object
var _centre: Vector2 = SWARM_ORIGIN
var _run_id: String = ""
var _generation: int = 0
var _sequence: int = -1
var _deadline: int = -1
var _command: Dictionary = {}
var _receipt: Dictionary = {}
var _issued: PackedInt64Array = PackedInt64Array()
var _button_edges: Array[Dictionary] = []
var _accepted_buttons: Dictionary = {}
var _applied_buttons: Dictionary = {}


func configure(id: StringName, next_map: StringName = &"mixed", next_water: int = 0) -> bool:
	if id not in Course.PRESETS or (next_map not in Course.MAP_IDS and next_map != &"legacy") or next_water < 0 \
		or next_water >= WorldSetup.WATER_NAMES.size() or not is_inside_tree():
		last_error = "Unknown player preset or missing scene owner."
		return false
	var candidate_arena: CyberPhysicalActorArena
	var candidate_world: Object
	if Course.is_swarm(id):
		if not ClassDB.class_exists(&"CyberNativeCellWorld"):
			last_error = "Native material runtime is unavailable."
			return false
		candidate_world = ClassDB.instantiate(&"CyberNativeCellWorld")
		if not candidate_world.has_method("apply_player_material_field"):
			last_error = "This native runtime predates player material fields; use the matching rebuilt runtime."
			return false
		if not candidate_world.diagnostic_reset({"workers": 1, "telemetry": false}):
			last_error = "Material world reset refused."
			return false
		candidate_world.set_simulation_window_enabled(false)
		candidate_world.set_cadence_lod_enabled(false)
		# Only construction creates parcels. Steering moves those real native
		# parcels and never paints replacements or restores lost quantity.
		var material: int = 2 if id == &"dryswarm" else 3
		var built: Dictionary = WorldSetup.build(candidate_world, next_map, next_water, material)
		if not built.accepted:
			last_error = built.error
			return false
	else:
		candidate_arena = Arena.new()
		add_child(candidate_arena)
		var prepared: Dictionary = Equipment.definition(Catalog.entry(id))
		var spawn := Vector2(Course.spawn(next_map).x, Course.floor_y(next_map) - float(prepared.get("spawn_floor_clearance", 20.0)))
		if id in [&"arcadelander", &"jetbarrel"]:
			spawn.y = Course.spawn(next_map).y
		var config: Dictionary = {"version": Arena.VERSION, "seed": 0, "max_ticks": Arena.MAX_TICKS,
			"local_patch_radius": 0, "course": Course.ID, "playground_map": next_map, "playground_water": next_water,
			"actors": [{"model": str(id), "producer": "human", "position": spawn}]}
		if not candidate_arena.configure(config):
			last_error = candidate_arena.last_error
			candidate_arena.free()
			return false
	close()
	selection = id
	map_id = next_map
	water_solver = next_water
	authoring_revision = 0
	_arena = candidate_arena
	_world = candidate_world
	epoch += 1
	tick = 0
	paused = false
	failed = false
	last_error = ""
	_centre = Course.spawn(next_map)
	_run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_generation = 0
	_sequence = -1
	_deadline = -1
	_issued.resize(MAX_LEASE + 1)
	_issued.fill(-1)
	_receipt = {"accepted": true, "reason": "seeded", "observed_cells": 256,
		"controlled_cells": 256, "moved_cells": 0,
		"centroid": _centre - Vector2(0.5, 0.5), "radius": 60, "truncated": false}
	_material_usables.configure(1)
	return true


func select_usable(index: int) -> bool:
	if index < -1 or index >= UsableCatalog.count(): return false
	cancel()
	usable_index = index
	return true


func usable_snapshot() -> Dictionary:
	return _arena._usables.snapshot() if _arena != null else _material_usables.snapshot()


func active() -> bool:
	return _arena != null or _world != null


func liquid_readback() -> Dictionary:
	if not active(): return {}
	var world: Object = _world if _world != null else _arena._world
	return {"policy": world.get_liquid_solver_policy(), "receipt": world.get_applied_liquid_construction_receipt()}


func paint(cell: Vector2i, radius: int, material: int, replace: bool = false) -> Dictionary:
	# This synchronous owner is called only between ticks on the scene thread.
	# A small explicit palette, protected boundary and current body mask bound edits.
	if not active() or failed or radius < 1 or radius > 12 or material not in [0, 1, 2, 3, 4, 6, 8, 12, 16, 24] \
		or not Course.editable(map_id).has_point(cell):
		return {"accepted": false, "reason": "Invalid brush, unavailable owner or point outside the editable course.", "changed": 0}
	var world: Object = _world if _world != null else _arena._world
	if _arena != null:
		world.prepare_rigid_body_coupling(_arena.session.bridge.pack_body_states(), false)
	var changed: int = 0
	for y: int in range(cell.y - radius, cell.y + radius + 1):
		for x: int in range(cell.x - radius, cell.x + radius + 1):
			if Vector2i(x, y).distance_squared_to(cell) > radius * radius \
				or not Course.editable(map_id).has_point(Vector2i(x, y)) or world.rigid_body_id_at(x, y) != 0:
				continue
			var before: int = world.material_at(x, y)
			if before == material or (material != 0 and not replace and before != 0): continue
			world.paint_disc(x, y, 0, material)
			if world.material_at(x, y) == material: changed += 1
	if changed > 0:
		authoring_revision += 1
		if _arena != null: _arena._sync_terrain()
	return {"accepted": true, "reason": "painted", "changed": changed}


func observation() -> Dictionary:
	return _view(true)


func _view(issue: bool) -> Dictionary:
	if _arena != null:
		return _arena.observation(0) if issue else _arena.session.snapshot().actors[0]
	if _world == null:
		return {}
	if issue:
		_issued[tick % (MAX_LEASE + 1)] = tick
	return {"version": 1, "representation": "native-material-field", "model": str(selection),
		"run_id": _run_id, "epoch": epoch, "tick": tick, "actor_id": 0,
		"observation_id": _token(tick), "control_generation": _generation,
		"last_sequence": _sequence, "position": _centre, "velocity": Vector2.ZERO,
		"suspended": paused or failed, "lease_remaining": maxi(0, _deadline - tick),
		"material": 2 if selection == &"dryswarm" else 3,
		"field": _receipt.duplicate(true), "pending_input_edges": _button_edges.size(),
		"usable": _material_usables.snapshot().actors[0] if _material_usables.actor_count() else {},
		"scope": "matching local material; no persistent parcel identity"}


static func make_command(view: Dictionary, sequence: int, action: Dictionary, lease: int = MAX_LEASE) -> Dictionary:
	if str(view.get("representation", "")) != "native-material-field":
		return Session.make_command(view, sequence, action, lease)
	return {"version": 1, "kind": "player_material_field_action", "run_id": view.get("run_id", ""),
		"epoch": view.get("epoch", -1), "actor_id": 0, "sequence": sequence,
		"observed_tick": view.get("tick", -1), "observation_id": view.get("observation_id", ""),
		"lease_ticks": lease, "action": action.duplicate(true)}


func submit(command: Variant) -> bool:
	if not active() or paused or failed:
		return _reject("Player owner is inactive or paused.")
	if _arena != null:
		var accepted: bool = _arena.submit(command, &"human")
		if not accepted:
			last_error = _arena.last_error
		return accepted
	if not command is Dictionary or command.size() != 10:
		return _reject("Malformed material command.")
	for key: String in ["version", "kind", "run_id", "epoch", "actor_id", "sequence", "observed_tick", "observation_id", "lease_ticks", "action"]:
		if not command.has(key):
			return _reject("Missing material command field.")
	if not Session._integer(command.version, 1, 1) or command.kind != "player_material_field_action" or command.run_id != _run_id \
		or not Session._integer(command.epoch, epoch, epoch) or not Session._integer(command.actor_id, 0, 0) \
		or not Session._integer(command.sequence, 0, 9007199254740991) or int(command.sequence) <= _sequence \
		or not Session._integer(command.observed_tick, maxi(0, tick - MAX_LEASE), tick) \
		or not Session._integer(command.lease_ticks, 1, MAX_LEASE):
		return _reject("Stale material command identity, sequence, or lease.")
	var observed: int = int(command.observed_tick)
	if _issued[observed % (MAX_LEASE + 1)] != observed or command.observation_id != _token(observed) \
		or observed + int(command.lease_ticks) <= tick:
		return _reject("Material observation was not issued or its authority expired.")
	if not command.action is Dictionary:
		return _reject("Material action is not an object.")
	for key: Variant in command.action:
		if str(key) not in ["move", "aim", "effort", "trim", "primary", "secondary", "auxiliary", "tool", "usable_alternate", "release_usable", "attach_usable"]:
			return _reject("Unsupported material action field.")
	if not command.action.get("usable_alternate", false) is bool:
		return _reject("Malformed alternate usable input.")
	var input: Dictionary = command.action.duplicate(true)
	input.erase("usable_alternate")
	var normalized: Dictionary = Session.normalized_action(input)
	if normalized.is_empty():
		return _reject("Invalid material action.")
	normalized.usable_alternate = command.action.get("usable_alternate", false)
	var edges: Array[Dictionary] = []
	for button: String in BUTTON_KEYS:
		if bool(normalized[button]) != bool(_accepted_buttons.get(button, false)):
			edges.append({"button": button, "pressed": bool(normalized[button])})
	if _button_edges.size() + edges.size() > MAX_BUTTON_EDGES:
		return _reject("Material button edge capacity reached.")
	_button_edges.append_array(edges)
	for button: String in BUTTON_KEYS:
		_accepted_buttons[button] = normalized[button]
	_command = normalized
	_sequence = int(command.sequence)
	_deadline = observed + int(command.lease_ticks)
	last_error = ""
	return true


func submit_action(action: Dictionary) -> bool:
	var view: Dictionary = observation()
	var request: Dictionary = action.duplicate(true)
	if _arena != null:
		request.equipment = {"usable_index": usable_index, "trigger": bool(request.get("tool", false)),
			"alternate": bool(request.get("usable_alternate", false)), "drop": bool(request.get("release_usable", false)),
			"attach": bool(request.get("attach_usable", false)), "aim": request.get("aim", Vector2.RIGHT), "power": 1.0}
		request.erase("usable_alternate")
	var accepted: bool=not view.is_empty() and submit(make_command(view,int(view.last_sequence)+1,request))
	if accepted and (bool(action.get("tool",false)) or bool(action.get("usable_alternate",false)) \
		or bool(action.get("release_usable",false)) or bool(action.get("attach_usable",false))): authoring_revision+=1
	return accepted


func _token(observed: int) -> String:
	return "%s:%d:%d:%d" % [_run_id, epoch, _generation, observed]


func _reject(reason: String) -> bool:
	last_error = reason
	return false


func cancel() -> void:
	if _arena != null:
		_arena.cancel(0, &"human")
	_command.clear()
	_button_edges.clear()
	_accepted_buttons.clear()
	_applied_buttons.clear()
	_usable_previous = false
	_alternate_previous = false
	_deadline = -1
	_generation += 1
	_issued.fill(-1)


func set_paused(value: bool) -> void:
	cancel()
	paused = value
	if _arena != null:
		_arena.set_paused(value)


func step() -> Dictionary:
	if not active() or paused or failed:
		return snapshot()
	if _arena != null:
		var state: Dictionary = _arena.step()
		tick = int(state.tick)
		failed = bool(state.failed)
		if bool(state.finished):
			paused = true
			last_error = str(state.reason)
		return snapshot()
	if not _command.is_empty() and _deadline < tick + 1:
		cancel()
	if not _command.is_empty():
		# Keep a quick tap alive for one simulation tick. As in the shared
		# physical Session, ordered edges change each button at most once/tick.
		var changed: Dictionary = {}
		while not _button_edges.is_empty():
			var edge: Dictionary = _button_edges[0]
			if changed.has(edge.button):
				break
			_button_edges.pop_front()
			_applied_buttons[edge.button] = edge.pressed
			changed[edge.button] = true
		var mode: int = 0
		if bool(_applied_buttons.get("auxiliary", false)): mode = 3
		elif bool(_applied_buttons.get("secondary", false)): mode = 2
		elif bool(_applied_buttons.get("primary", false)): mode = 1
		_receipt = _wide_material_field(mode)
		if not bool(_receipt.get("accepted", false)):
			failed = true
			last_error = "Material field refused: " + str(_receipt.get("reason", "unknown"))
			cancel()
			return snapshot()
		if int(_receipt.get("observed_cells", 0)) > 0:
			var centroid: Vector2 = _receipt.get("centroid", _centre)
			if centroid.is_finite():
				# The field follows the material it actually observed. Input never
				# teleports a selection cursor to a distant reservoir.
				_centre = _centre.move_toward(centroid, 4.0)
	var tool: bool = not _command.is_empty() and bool(_applied_buttons.get("tool", false))
	var alternate: bool = not _command.is_empty() and bool(_applied_buttons.get("usable_alternate", false))
	# Material players have no held rigid body. Their usable origin is the
	# visible field edge, so a nozzle/projectile does not start inside the cloud.
	var usable_aim: Vector2=Vector2(_command.get("aim",Vector2.RIGHT)).normalized()
	if usable_aim.length_squared()<0.001: usable_aim=Vector2.RIGHT
	var bounds: Rect2i=Course.editable(map_id)
	var muzzle: Vector2=(_centre+usable_aim*68.0).clamp(Vector2(bounds.position)+Vector2(3,3),Vector2(bounds.end)-Vector2(4,4))
	_material_usables.step(1.0/60.0, _world, PackedVector2Array([muzzle]), [Rect2()],
		[{"usable_index":usable_index, "aim":_command.get("aim",Vector2.RIGHT), "power":1.0,
		"trigger":tool, "trigger_pressed":tool and not _usable_previous,
		"alternate_pressed":alternate and not _alternate_previous}])
	_usable_previous = tool
	_alternate_previous = alternate
	if _material_usables.write_count_last > 0: authoring_revision += 1
	if not bool(_world.simulation_tick()):
		failed = true
		last_error = "Native material tick failed."
		cancel()
	tick += 1
	return snapshot()


func _wide_material_field(mode: int) -> Dictionary:
	# Five existing native radius-32 fields cover radius 60. Each call retains
	# its 4225-read / 512-parcel bound; aggregate counts are samples/move
	# operations, not a unique particle inventory. No native ABI changes.
	var offsets: Array[Vector2i] = [Vector2i.ZERO,Vector2i(-28,0),Vector2i(28,0),Vector2i(0,-28),Vector2i(0,28)]
	var result: Dictionary = {}
	var observed: int = 0
	var moved: int = 0
	var fields: Array[Dictionary]=[]
	var truncated: bool=false
	var direction: Vector2 = _command.move
	var idle: bool = direction.length_squared() < 0.001
	for offset: Vector2i in offsets:
		var flow: Vector2 = direction
		if idle:
			var angle: float = float(tick) * (0.065 if selection == &"dryswarm" else 0.043)
			flow = Vector2(cos(angle),sin(angle*1.3))*0.38
		if offset != Vector2i.ZERO:
			flow += -Vector2(offset).normalized()*0.30
			if idle: flow += Vector2(-offset.y,offset.x).normalized()*0.24
		var field_centre: Vector2i=(Vector2i(_centre.round())+offset).clamp(Vector2i.ZERO,Vector2i(1023,1023))
		var receipt: Dictionary = _world.apply_player_material_field(field_centre,
			flow.limit_length(1.0),2 if selection == &"dryswarm" else 3,mode,tick)
		if not receipt.get("accepted",false): return receipt
		fields.append(receipt.duplicate(true))
		truncated=truncated or bool(receipt.get("truncated",false))
		if result.is_empty() or (int(result.get("observed_cells",0))==0 and int(receipt.observed_cells)>0): result=receipt.duplicate(true)
		observed += int(receipt.observed_cells)
		moved += int(receipt.moved_cells)
	result.observed_cells=observed
	result.controlled_cells=observed
	result.moved_cells=moved
	result.radius=60
	result.native_calls=5
	result.idle_pattern=idle
	result.native_fields=fields
	result.truncated=truncated
	return result


func snapshot() -> Dictionary:
	return {"selection": selection, "epoch": epoch, "tick": tick, "paused": paused,
		"failed": failed, "last_error": last_error, "actor": _view(false),
		"material_mode": Course.is_swarm(selection), "field_active": not _command.is_empty() and _deadline > tick}


func render_parts() -> Array:
	return _arena.render_parts() if _arena != null else []


func take_render_packet(force: bool = false) -> Dictionary:
	if not active():
		return {}
	var packet: Dictionary = _arena.presentation_snapshot(force) if _arena != null else _world.take_render_snapshot(force)
	packet["layer_id"] = "player-playground"
	packet["reset_generation"] = epoch
	packet["layer_tick"] = tick
	return packet


func presentation_cells() -> PackedByteArray:
	var view: Rect2i = Course.map_view(map_id)
	if _arena != null:
		return _arena.presentation_cells(view)
	if _world == null:
		return PackedByteArray()
	var source: PackedByteArray = _world.get_cells()
	var result := PackedByteArray()
	result.resize(view.size.x * view.size.y)
	for y: int in range(view.size.y):
		var first: int = (view.position.y + y) * 1024 + view.position.x
		for x: int in range(view.size.x):
			result[y * view.size.x + x] = source[first + x]
	return result


func close() -> void:
	cancel()
	if is_instance_valid(_arena):
		_arena.close()
		_arena.free()
	_arena = null
	_world = null
	_run_id = ""
	_receipt.clear()
	selection = &""


func _exit_tree() -> void:
	close()
