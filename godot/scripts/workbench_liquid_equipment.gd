extends RefCounted

# IN-TOOLS #361 liquid equipment for the shared development workbench.
#
# Owned exclusively by the cellular simulation worker, like the powder source:
# the main thread only queues copied commands. Every edit goes through the
# native World's ordinary booked external-edit path (emit_disc / native
# ballistic injection), so the native quantity ledger stays authoritative and
# closes on its own. This owner adds no solver, law or velocity edit.
#
# Devices (all optional, authored in the starting setup's `equipment` block):
#   valves - up to eight rectangles of Hard wall gate cells. Open erases a
#            gate's cells; close refills them. Liquid caught in a gate is
#            pushed to the nearest free cell outside it (exact for whole-cell
#            Water and other whole-cell materials). A partially filled Water
#            cell cannot move without changing its quantity, so it is removed
#            and booked explicitly as `trimmed_water`.
#   drain  - a bounded sink rectangle that removes declared liquids at a
#            bounded rate, booking the exact native quantity of every cell.
#   nozzle - a finite directed Water source. With ballistic Water enabled in
#            the World it fires native ballistic parcels (real momentum, the
#            #406 owner). Otherwise it injects whole Water cells at the muzzle
#            with zero motion. A submerged muzzle tops up a partial Water cell,
#            or places the cell on the free surface above it (`_surface_cell`):
#            exact volume, rising level, but no local pressure jet. Slow inlets
#            spread over the surface; fast ones stack a fountain column.
#   pump   - when enabled, drained Water feeds the nozzle's internal pipe
#            instead of leaving the World: a closed circulation loop in which
#            native Water + pipe stock stays constant.
#
# Persistent: the authored geometry/parameters. Transient (never saved): open
# state, pipe stock, ledgers. Replacing or restoring the World resets them.

const UsableRuntime = preload("res://scripts/usable_runtime.gd")
const VERSION := 1
const GATE := 58                 # Hard wall
const WATER := 3
const MAX_VALVES := 8
const MAX_GATE_CELLS := 64
const MAX_DRAIN_CELLS := 96
const MAX_DRAIN_RATE := 32
const MAX_NOZZLE_RATE := 8
const MAX_SUPPLY_CELLS := 20000
const MAX_PIPE_CELLS := 20000
const MAX_READS := 4096
const DISPLACE_RADIUS := 4
const MAX_COLUMN_RISE := 64
const SURFACE_SPREAD := 6
const SURFACE_DROP := 32
const KEYS := ["version","valves","drain","nozzle","supply","pump","pipe_capacity"]

var serial := 0
var configured := false
var _config: Dictionary = {}
var _extent := Vector2i.ZERO
var _unit := 0                    # native Water quantity of one full cell
var _whole_cell := false
var _ballistic := false           # World constructed with ballistic Water (#406)
var _reads := 0
# Valves: one Dictionary of runtime state per authored gate.
var _valves: Array[Dictionary] = []
var _gates := Rect2i()            # union of every gate, for displacement exclusion
# Drain.
var _drain := Rect2i()
var _drain_rate := 0
var _drain_open := false
var _drained_water := 0
var _drained_cells := {}
var _drain_masked := 0
var _drain_pipe_full := 0
# Nozzle.
var _nozzle := Vector2i(-1,-1)
var _angle := 0.0
var _speed := 0.0
var _nozzle_rate := 0
var _nozzle_on := false
var _injected_water := 0
var _emitted := 0
var _cell_emissions := 0          # emissions that were Water cells, not parcels
var _topped_up := 0
var _column_injections := 0
var _nozzle_refused := {}
# Pipe / supply.
var _pump := false
var _stock := 0
var _supplied := 0
var _pipe_capacity := 0
var _ticks := 0
var _active_ticks := 0
var _last_refusal := ""
var _refused := 0
var _last := {}
# Read-only native census of up to four labelled canvas rectangles (each at
# most 256 x 256), copied into the next receipt. Used by the status/test path
# and available to a future agent client; it never mutates the World.
const MAX_OBSERVATIONS := 4
const MAX_OBSERVATION_SIDE := 256
var _observations := {}
var _observation_serial := 0


static func empty_config() -> Dictionary:
	return {"version":VERSION,"valves":[],"drain":[],"nozzle":[],"supply":0,"pump":false,"pipe_capacity":MAX_PIPE_CELLS}


static func _int(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) \
		and float(value) >= low and float(value) <= high


static func _num(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func _rect(values: Array) -> Rect2i:
	return Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3]))


static func _rect_error(values: Variant, label: String, size: int) -> String:
	if not values is Array or values.size() != size: return "Invalid %s geometry." % label
	for i: int in 4:
		if not _int(values[i],0 if i < 2 else 1,2048): return "Invalid %s geometry." % label
	return ""


# Strict validation shared by Setup files and the worker. Unknown keys,
# out-of-canvas geometry and unbounded rates are refused, never clipped.
static func validate(value: Variant, extent: Vector2i) -> String:
	if not value is Dictionary or value.size() != KEYS.size() or not value.has_all(KEYS):
		return "Equipment block must hold exactly: " + ", ".join(KEYS) + "."
	if not _int(value.version,VERSION,VERSION): return "Unsupported equipment version."
	var canvas := Rect2i(Vector2i.ZERO,extent)
	for key: String in ["valves","drain","nozzle"]:
		if not value[key] is Array: return "Invalid %s geometry." % key
	if value.valves.size() > MAX_VALVES: return "At most %d valves." % MAX_VALVES
	var placed: Array[Rect2i] = []
	for gate_values: Variant in value.valves:
		var error := _rect_error(gate_values,"valve",4)
		if not error.is_empty(): return error
		var gate := _rect(gate_values)
		if not canvas.encloses(gate.grow(1)) or gate.get_area() > MAX_GATE_CELLS:
			return "Each valve must lie inside the canvas and hold at most %d cells." % MAX_GATE_CELLS
		for other: Rect2i in placed:
			if other.intersects(gate): return "Valves must not overlap."
		placed.append(gate)
	if not value.drain.is_empty():
		var error := _rect_error(value.drain,"drain",5)
		if not error.is_empty(): return "Drain needs [x, y, width, height, cells per tick]."
		var sink := _rect(value.drain)
		if not canvas.encloses(sink) or sink.get_area() > MAX_DRAIN_CELLS:
			return "The drain must lie inside the canvas and hold at most %d cells." % MAX_DRAIN_CELLS
		if not _int(value.drain[4],1,MAX_DRAIN_RATE): return "Drain rate must be 1-%d cells per tick." % MAX_DRAIN_RATE
	if not value.nozzle.is_empty():
		if value.nozzle.size() != 5: return "Nozzle needs [x, y, angle, speed, cells per tick]."
		if not _int(value.nozzle[0],2,extent.x-3) or not _int(value.nozzle[1],2,extent.y-3):
			return "Place the nozzle at least two cells inside the canvas."
		if not _num(value.nozzle[2],-180.0,180.0) or not _num(value.nozzle[3],0.5,6.0):
			return "Nozzle angle must be -180..180 degrees and speed 0.5-6 cells per tick."
		if not _int(value.nozzle[4],1,MAX_NOZZLE_RATE): return "Nozzle rate must be 1-%d per tick." % MAX_NOZZLE_RATE
	if not _int(value.supply,0,MAX_SUPPLY_CELLS) or not value.pump is bool:
		return "Nozzle supply must be 0-%d cells and pump a true/false switch." % MAX_SUPPLY_CELLS
	if not _int(value.pipe_capacity,1,MAX_PIPE_CELLS) or int(value.supply) > int(value.pipe_capacity):
		return "Pipe capacity must be 1-%d cells and hold the supply." % MAX_PIPE_CELLS
	if value.nozzle.is_empty() and (value.pump or int(value.supply) != 0):
		return "Pump and supply need a nozzle."
	return ""


static func canonical(value: Dictionary) -> Dictionary:
	var result := empty_config()
	for gate: Array in value.valves: result.valves.append(Array(PackedInt32Array(gate)))
	result.drain = Array(PackedInt32Array(value.drain))
	if not value.nozzle.is_empty():
		result.nozzle = [int(value.nozzle[0]),int(value.nozzle[1]),float(value.nozzle[2]),float(value.nozzle[3]),int(value.nozzle[4])]
	result.supply = int(value.supply)
	result.pump = bool(value.pump)
	result.pipe_capacity = int(value.pipe_capacity)
	return result


func reset() -> void:
	serial = 0
	configured = false
	_config = {}
	_extent = Vector2i.ZERO
	_observations = {}
	_reset_runtime()


func _reset_runtime() -> void:
	_valves = []
	_gates = Rect2i()
	_drain = Rect2i()
	_drain_rate = 0
	_drain_open = false
	_drained_water = 0
	_drained_cells = {}
	_drain_masked = 0
	_drain_pipe_full = 0
	_nozzle = Vector2i(-1,-1)
	_angle = 0.0
	_speed = 0.0
	_nozzle_rate = 0
	_nozzle_on = false
	_injected_water = 0
	_emitted = 0
	_cell_emissions = 0
	_topped_up = 0
	_column_injections = 0
	_nozzle_refused = {}
	_pump = false
	_stock = 0
	_supplied = 0
	_pipe_capacity = 0
	_ticks = 0
	_active_ticks = 0
	_last_refusal = ""
	_refused = 0
	_last = {}


func _refuse(reason: String) -> void:
	_last_refusal = reason
	_refused += 1


# A valve command is applied between ticks but the gate only changes in the
# next device step; until then the receipt reports opening/closing.
func _set_valve(valve: Dictionary, open: bool) -> void:
	if bool(valve.open) == open and not valve.pending: return
	valve.open = open
	valve.pending = true


# Commands arrive in queue order between ticks. A command for an older
# configuration (for example queued before the World was replaced) refuses.
func command(world: Object, request: Dictionary, extent: Vector2i) -> void:
	var kind: String = str(request.get("command",""))
	if kind == "configure":
		var config: Variant = request.get("config")
		var error := validate(config,extent)
		if error.is_empty() and int(request.get("serial",0)) <= serial: error = "stale_serial"
		if error.is_empty() and (world == null or not world.has_method(&"inspect_pressure_cell")):
			error = "native World required"
		if not error.is_empty():
			_refuse("configure: " + error)
			return
		_configure(world,canonical(config),extent,int(request.serial))
		return
	if kind == "observe":
		_observe(world,request,extent)
		return
	if not configured or int(request.get("serial",-1)) != serial:
		_refuse("%s: stale_configuration" % kind)
		return
	match kind:
		"valve":
			var index: Variant = request.get("index",0)
			if _valves.is_empty():
				_refuse("valve: not installed")
			elif not _int(index,-1,_valves.size()-1):
				_refuse("valve: no valve %s" % str(index))
			elif int(index) == -1:
				for valve: Dictionary in _valves: _set_valve(valve,bool(request.get("open",false)))
			else:
				_set_valve(_valves[int(index)],bool(request.get("open",false)))
		"drain":
			if _drain.has_area(): _drain_open = bool(request.get("open",false))
			else: _refuse("drain: not installed")
		"nozzle":
			if _nozzle.x >= 0: _nozzle_on = bool(request.get("on",false))
			else: _refuse("nozzle: not installed")
		"tune":
			if _nozzle.x < 0:
				_refuse("tune: no nozzle")
			elif not _num(request.get("angle"),-180.0,180.0) or not _num(request.get("speed"),0.5,6.0) \
					or not _int(request.get("rate"),1,MAX_NOZZLE_RATE):
				_refuse("tune: outside admission")
			else:
				_angle = float(request.angle)
				_speed = float(request.speed)
				_nozzle_rate = int(request.rate)
				_config.nozzle = [_nozzle.x,_nozzle.y,_angle,_speed,_nozzle_rate]
		"stop":
			for valve: Dictionary in _valves: _set_valve(valve,false)
			_drain_open = false
			_nozzle_on = false
		_:
			_refuse("unknown command " + kind)


func _observe(world: Object, request: Dictionary, extent: Vector2i) -> void:
	var regions: Variant = request.get("regions")
	if world == null or world.has_failed() or not world.has_method(&"water_experiment_observation") \
			or not regions is Dictionary or regions.is_empty() or regions.size() > MAX_OBSERVATIONS:
		_refuse("observe: invalid request")
		return
	var result := {}
	for label: Variant in regions:
		var rect: Variant = regions[label]
		if not label is String or not rect is Array or rect.size() != 4:
			_refuse("observe: invalid region")
			return
		for i: int in 4:
			if not _int(rect[i],0 if i < 2 else 1,MAX_OBSERVATION_SIDE if i >= 2 else 2048):
				_refuse("observe: invalid region")
				return
		var area := _rect(rect)
		if not Rect2i(Vector2i.ZERO,extent).encloses(area):
			_refuse("observe: region outside canvas")
			return
		var observed: Dictionary = world.water_experiment_observation(area.position,area.size)
		result[label] = {"rect":rect.duplicate(),"water_cells":int(observed.get("water_cells",0)),
			"water":int(observed.get("water_integer",0)),"overfill":int(observed.get("water_overfill",0)),
			"tick":int(observed.get("tick",-1))}
	_observation_serial = int(request.get("observation",_observation_serial + 1))
	_observations = result


func _configure(world: Object, config: Dictionary, extent: Vector2i, next_serial: int) -> void:
	_reset_runtime()
	serial = next_serial
	configured = true
	_config = config
	_extent = extent
	var policy: Dictionary = world.get_water_experiment_policy() if world.has_method(&"get_water_experiment_policy") else {}
	_unit = int(policy.get("maximum",0))
	_whole_cell = false
	# Ballistic Water is a construction option, fixed for this World.
	_ballistic = world.has_method(&"inject_water_parcel") and world.has_method(&"get_water_spray") \
		and bool(world.get_water_spray().get("ballistic_enabled",false))
	if world.has_method(&"get_liquid_solver_policy"):
		for assignment: Dictionary in world.get_liquid_solver_policy().get("assignments",[]):
			if int(assignment.get("material",-1)) == WATER:
				_whole_cell = str(assignment.get("applied_family","")) in ["cellular_yield_v1","inertial_cellular_v1"]
	for gate_values: Array in config.valves:
		var gate := _rect(gate_values)
		_gates = gate if not _gates.has_area() else _gates.merge(gate)
		_valves.append({"rect":gate,"open":false,"pending":false,"waiting":0,"opened":0,"closed":0,"displaced":0,"trimmed":0})
	if not config.drain.is_empty():
		_drain = _rect(config.drain)
		_drain_rate = int(config.drain[4])
	if not config.nozzle.is_empty():
		_nozzle = Vector2i(int(config.nozzle[0]),int(config.nozzle[1]))
		_angle = float(config.nozzle[2])
		_speed = float(config.nozzle[3])
		_nozzle_rate = int(config.nozzle[4])
	_pump = bool(config.pump)
	_pipe_capacity = int(config.pipe_capacity) * _unit
	_stock = int(config.supply) * _unit
	_supplied = _stock


func _mask(world: Object, cell: Vector2i) -> int:
	_reads += 1
	return int(world.rigid_body_id_at(cell.x,cell.y))


func _material(world: Object, cell: Vector2i) -> int:
	_reads += 1
	return int(world.material_at(cell.x,cell.y))


# Exact native Water quantity of one stored cell: visible state plus any
# PressureFlow overfill (zero under every other family).
func _water_quantity(world: Object, cell: Vector2i) -> int:
	_reads += 1
	var state: Dictionary = world.inspect_pressure_cell(cell)
	if int(state.get("material",-1)) != WATER: return 0
	return int(state.get("state_a",0)) + int(state.get("overfill",0))


func before_tick(world: Object) -> void:
	if not configured or world == null or world.has_failed(): return
	_reads = 0
	_ticks += 1
	var drained_before := _drained_water
	var injected_before := _injected_water
	var waiting := 0
	for valve: Dictionary in _valves:
		_step_valve(world,valve)
		waiting += int(valve.waiting)
	if _drain_open: _step_drain(world)
	if _nozzle_on: _step_nozzle(world)
	_last = {"tick":_ticks,"drained":_drained_water-drained_before,"injected":_injected_water-injected_before,"reads":_reads}
	if _drain_open or _nozzle_on or waiting > 0: _active_ticks += 1


func _step_valve(world: Object, valve: Dictionary) -> void:
	valve.waiting = 0
	valve.pending = false
	var gate: Rect2i = valve.rect
	for y: int in range(gate.position.y,gate.end.y):
		for x: int in range(gate.position.x,gate.end.x):
			if _reads >= MAX_READS:
				valve.waiting += 1
				continue
			var cell := Vector2i(x,y)
			var material := _material(world,cell)
			if valve.open:
				if material == GATE:
					world.emit_disc(x,y,0,0)
					if _material(world,cell) == 0: valve.opened += 1
				continue
			if material == GATE: continue
			if _mask(world,cell) != 0:
				valve.waiting += 1
				continue
			if material != 0 and not _clear_gate_cell(world,cell,material,valve):
				valve.waiting += 1
				continue
			world.emit_disc(x,y,0,GATE)
			if _material(world,cell) == GATE: valve.closed += 1
			else: valve.waiting += 1


# Pushes the material occupying a closing gate cell to the nearest free
# unmasked cell outside every gate. Whole cells move exactly (same material,
# full native quantity). A partial Water cell is removed and its exact native
# quantity booked as trimmed instead of inventing the missing quantity.
func _clear_gate_cell(world: Object, cell: Vector2i, material: int, valve: Dictionary) -> bool:
	var excess := 0
	if material == WATER:
		var quantity := _water_quantity(world,cell)
		if quantity < _unit or _unit <= 0:
			world.emit_disc(cell.x,cell.y,0,0)
			if _material(world,cell) != 0: return false
			valve.trimmed += quantity
			return true
		# A pressurized PressureFlow cell moves as one full cell; only its
		# overfill above a full cell is trimmed and booked.
		excess = quantity - _unit
	elif not UsableRuntime.LIQUIDS.has(material) and not material in UsableRuntime.POWDERS:
		return false
	var target := _free_cell_near(world,cell)
	# A flooded gate has no free neighbour: push the cell up to the free
	# surface of the liquid it sits in, so the level rises by its volume.
	if target.x < 0 and UsableRuntime.LIQUIDS.has(material): target = _surface_cell(world,cell,material)
	if target.x < 0: return false
	world.emit_disc(cell.x,cell.y,0,0)
	if _material(world,cell) != 0: return false
	world.emit_disc(target.x,target.y,0,material)
	if _material(world,target) != material:
		# Never reached in practice: the target was checked Empty and unmasked
		# under the same exclusive owner. Restore the cell rather than lose it.
		world.emit_disc(cell.x,cell.y,0,material)
		valve.trimmed += excess
		return false
	valve.displaced += 1
	valve.trimmed += excess
	return true


func _in_gate(cell: Vector2i) -> bool:
	if not _gates.has_point(cell): return false
	for valve: Dictionary in _valves:
		if Rect2i(valve.rect).has_point(cell): return true
	return false


func _free_cell_near(world: Object, cell: Vector2i) -> Vector2i:
	for radius: int in range(1,DISPLACE_RADIUS+1):
		for offset: Vector2i in [Vector2i(0,-radius),Vector2i(-radius,0),Vector2i(radius,0),Vector2i(0,radius)]:
			var target := cell + offset
			if _in_gate(target) or not Rect2i(Vector2i.ZERO,_extent).has_point(target): continue
			if _reads >= MAX_READS: return Vector2i(-1,-1)
			if _material(world,target) == 0 and _mask(world,target) == 0: return target
	return Vector2i(-1,-1)


func _step_drain(world: Object) -> void:
	var removed := 0
	# Bottom row first: the drain pulls from the outlet floor upward.
	for y: int in range(_drain.end.y-1,_drain.position.y-1,-1):
		for x: int in range(_drain.position.x,_drain.end.x):
			if removed >= _drain_rate or _reads >= MAX_READS: return
			var cell := Vector2i(x,y)
			var material := _material(world,cell)
			if not UsableRuntime.LIQUIDS.has(material): continue
			if _mask(world,cell) != 0:
				_drain_masked += 1
				continue
			var quantity := _water_quantity(world,cell) if material == WATER else 0
			if material == WATER and _pump and _stock + quantity > _pipe_capacity:
				# A full pipe stops the drain; it never deletes the excess.
				_drain_pipe_full += 1
				return
			world.emit_disc(x,y,0,0)
			if _material(world,cell) != 0: continue
			removed += 1
			_drained_cells[material] = int(_drained_cells.get(material,0)) + 1
			if material == WATER:
				_drained_water += quantity
				if _pump: _stock += quantity


func _step_nozzle(world: Object) -> void:
	var axis := Vector2.RIGHT.rotated(deg_to_rad(_angle))
	# Native injection uses the full cell quantity in whole-cell regimes and at
	# most 255 units otherwise (water_spray_coupling.inc).
	var quantity := _unit if _whole_cell else mini(_unit,255)
	for index: int in range(_nozzle_rate):
		if _stock < (quantity if _ballistic else _unit) or _unit <= 0:
			_count_refusal("empty")
			return
		var muzzle := Vector2i((Vector2(_nozzle) + Vector2(0.5,0.5) + axis * 1.5).floor())
		var submerged := Rect2i(Vector2i.ZERO,_extent).has_point(muzzle) and _material(world,muzzle) == WATER
		if _ballistic and not submerged:
			var outcome: String = world.inject_water_parcel(Vector2(_nozzle) + Vector2(0.5,0.5) + axis * 1.5,axis * _speed,quantity)
			if outcome != "launched":
				_count_refusal(outcome)
				return
			_stock -= quantity
			_injected_water += quantity
			_emitted += 1
			continue
		if not _inject_cell(world,axis):
			_count_refusal("muzzle_blocked")
			return


func _count_refusal(reason: String) -> void:
	_nozzle_refused[reason] = int(_nozzle_refused.get(reason,0)) + 1


# Cell mode, also used whenever the muzzle is under Water: place Water at the
# first usable muzzle cell along the axis. An Empty cell gets one whole cell at
# rest. A partial Water cell is topped up to full. A full Water cell passes the
# new cell to the free surface above it (`_surface_cell`), so the level rises
# by exactly that volume.
func _inject_cell(world: Object, axis: Vector2) -> bool:
	var inside := Rect2i(Vector2i.ONE,_extent-Vector2i(2,2))
	for distance: float in [1.0,2.0]:
		var cell := Vector2i((Vector2(_nozzle) + Vector2(0.5,0.5) + axis * distance).floor())
		if not inside.has_point(cell) or _mask(world,cell) != 0: continue
		var material := _material(world,cell)
		if material == 0:
			return _place_full(world,cell,false)
		if material != WATER: continue
		var before := _water_quantity(world,cell)
		if before < _unit:
			world.emit_disc(cell.x,cell.y,0,WATER)
			var added := _water_quantity(world,cell) - before
			if added <= 0: continue
			_stock -= added
			_injected_water += added
			_topped_up += 1
			_emitted += 1
			_cell_emissions += 1
			return true
		var top := _surface_cell(world,cell,WATER,underwater_spread(_speed))
		if top.x >= 0: return _place_full(world,top,true)
	return false


# Underwater inlet feel is velocity based: a slow inlet (speed <= 1 cell/tick)
# spreads each added cell over up to six columns of the surface; faster inlets
# spread less and from 3 cells/tick stack a rising fountain column on the
# muzzle's own column (bounded by the 64-row climb).
static func underwater_spread(speed: float) -> int:
	return clampi(roundi(SURFACE_SPREAD * (3.0 - speed) / 2.0),0,SURFACE_SPREAD)


# The free-surface cell for liquid added at `start`: climb through the same
# liquid (<= 64 rows) to the first Empty cell, then look up to six columns to
# each side on that row and drop down open air (<= 32 rows) to the lowest
# resting spot, so repeated additions spread over the surface instead of
# stacking a one-cell spire. Gates, masked cells and walls are never chosen.
func _surface_cell(world: Object, start: Vector2i, material: int, spread_limit: int = SURFACE_SPREAD) -> Vector2i:
	var inside := Rect2i(Vector2i.ONE,_extent-Vector2i(2,2))
	var top := start
	var found := false
	for _row: int in range(MAX_COLUMN_RISE):
		top += Vector2i.UP
		if not inside.has_point(top) or _reads >= MAX_READS or _mask(world,top) != 0: return Vector2i(-1,-1)
		var above := _material(world,top)
		if above == 0:
			found = true
			break
		if above != material: return Vector2i(-1,-1)
	if not found: return Vector2i(-1,-1)
	var best := Vector2i(-1,-1)
	for spread: int in range(spread_limit + 1):
		for side: int in ([0] if spread == 0 else [-spread,spread]):
			var probe := top + Vector2i(side,0)
			if not inside.has_point(probe) or _in_gate(probe) or _reads >= MAX_READS: continue
			if _material(world,probe) != 0 or _mask(world,probe) != 0: continue
			for _drop: int in range(SURFACE_DROP):
				var below := probe + Vector2i.DOWN
				if not inside.has_point(below) or _in_gate(below) or _reads >= MAX_READS: break
				if _material(world,below) != 0 or _mask(world,below) != 0: break
				probe = below
			if probe.y > best.y: best = probe
	return best


func _place_full(world: Object, cell: Vector2i, column: bool) -> bool:
	world.emit_disc(cell.x,cell.y,0,WATER)
	if _material(world,cell) != WATER: return false
	_stock -= _unit
	_injected_water += _unit
	_emitted += 1
	_cell_emissions += 1
	if column: _column_injections += 1
	return true


func receipt() -> Dictionary:
	var counts := {}
	for material: int in _drained_cells: counts[str(material)] = _drained_cells[material]
	var valves := []
	for valve: Dictionary in _valves:
		var gate: Rect2i = valve.rect
		valves.append({"rect":[gate.position.x,gate.position.y,gate.size.x,gate.size.y],"open":valve.open,
			"waiting":valve.waiting,"opened_cells":valve.opened,"closed_cells":valve.closed,
			"displaced_cells":valve.displaced,"trimmed_water":valve.trimmed,
			"state":(("opening" if valve.pending else "open") if valve.open
				else ("closing" if int(valve.waiting) > 0 or valve.pending else "closed"))})
	return {"version":VERSION,"configured":configured,"serial":serial,"config":_config.duplicate(true),
		"water_unit":_unit,"whole_cell_water":_whole_cell,"nozzle_mode":"ballistic parcels" if _ballistic else "cells at rest",
		"ticks":_ticks,"active_ticks":_active_ticks,"valves":valves,
		"drain":{"installed":_drain.has_area(),"open":_drain_open,"rate":_drain_rate,"drained_water":_drained_water,
			"drained_cells":counts,"masked_skips":_drain_masked,"pipe_full":_drain_pipe_full},
		"nozzle":{"installed":_nozzle.x >= 0,"on":_nozzle_on,"angle":_angle,"speed":_speed,"rate":_nozzle_rate,
			"emitted":_emitted,"cell_emissions":_cell_emissions,"injected_water":_injected_water,"topped_up":_topped_up,
			"column_injections":_column_injections,"refused":_nozzle_refused.duplicate()},
		"pipe":{"pump":_pump,"stock":_stock,"supplied":_supplied,"capacity":_pipe_capacity},
		"last":_last.duplicate(),"last_refusal":_last_refusal,"refused":_refused,
		"observation_serial":_observation_serial,"observations":_observations.duplicate(true)}
