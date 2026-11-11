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
#   launcher  - a finite directed solid source (BS-001). With ballistic solids
#            in the World it fires native ballistic solids of one material from its
#            stock; otherwise it places one resting cell at the muzzle.
#   collector - a bounded sink rectangle for powders/solids; collected cells go
#            to the solids stock by material (exact cell counts).
#   conveyor  - when enabled, collected cells of the launcher's material feed
#            its stock: grid + in-flight solids + stock stays constant.
#   A sand "hopper" is simply a valve in the floor of a powder bin.
#   pump   - when enabled, drained Water feeds the nozzle's internal pipe
#            instead of leaving the World: a closed circulation loop in which
#            native Water + pipe stock stays constant.
#
# Persistent: the authored geometry/parameters. Transient (never saved): open
# state, pipe stock, ledgers. Replacing or restoring the World resets them.

const UsableRuntime = preload("res://scripts/usable_runtime.gd")
const Kinetic = preload("res://scripts/workbench_kinetic_mask.gd")
const KineticUsables = preload("res://scripts/kinetic_usables.gd")
const MAX_KINETICS := 8
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
const KEYS := ["version","valves","drain","nozzle","supply","pump","pipe_capacity",
	"launcher","collector","solid_supply","conveyor","kinetics","loadout"]
# Materials the solids devices may fire or collect (powders and Stone). The
# native owner decides admission again and refuses anything else.
const SOLIDS := [2,13,14,19,23,26,27,29,8,12,16,20,21,24,32,33,36]
const MAX_COLLECTOR_CELLS := 96
const MAX_COLLECTOR_RATE := 32
const MAX_LAUNCHER_RATE := 8
const MAX_SOLID_STOCK := 20000

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
# Solids devices.
var _solids := false              # World constructed with ballistic solids (BS-001)
var _launcher := Vector2i(-1,-1)
var _launcher_angle := 0.0
var _launcher_speed := 0.0
var _launcher_rate := 0
var _launcher_material := 0
var _launcher_on := false
var _launched := 0
var _launched_cells := 0          # resting-cell fallback emissions
var _launcher_refused := {}
var _collector := Rect2i()
var _collector_rate := 0
var _collector_open := false
var _collected := {}
var _conveyor := false
var _solid_stock := 0
var _solid_supplied := 0
var _population := -1           # native grid population of the launcher material
var _populations := {}           # native grid populations of every kinetic solid
# Kinetic emitters (kinetic mask presets) and the pointer tool.
var _kinetics: Array[Dictionary] = []
var _kinetic_serial := 0
var _kinetic_totals := {"applications":0,"water":0,"solids":0,"refused":{},"truncated":0}
var _kinetic_last := {}
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
	return {"version":VERSION,"valves":[],"drain":[],"nozzle":[],"supply":0,"pump":false,"pipe_capacity":MAX_PIPE_CELLS,
		"launcher":[],"collector":[],"solid_supply":0,"conveyor":false,"kinetics":[],"loadout":["","",""]}


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
	if not value.launcher is Array or not value.collector is Array: return "Invalid solids device geometry."
	if not value.launcher.is_empty():
		if value.launcher.size() != 6: return "Launcher needs [x, y, angle, speed, per tick, material]."
		if not _int(value.launcher[0],2,extent.x-3) or not _int(value.launcher[1],2,extent.y-3):
			return "Place the launcher at least two cells inside the canvas."
		if not _num(value.launcher[2],-180.0,180.0) or not _num(value.launcher[3],0.5,6.0):
			return "Launcher angle must be -180..180 degrees and speed 0.5-6 cells per tick."
		if not _int(value.launcher[4],1,MAX_LAUNCHER_RATE): return "Launcher rate must be 1-%d per tick." % MAX_LAUNCHER_RATE
		if not _int(value.launcher[5],0,255) or not int(value.launcher[5]) in SOLIDS: return "Launcher material is not a supported solid."
	if not value.collector.is_empty():
		var error := _rect_error(value.collector,"collector",5)
		if not error.is_empty(): return "Collector needs [x, y, width, height, cells per tick]."
		var sink := _rect(value.collector)
		if not canvas.encloses(sink) or sink.get_area() > MAX_COLLECTOR_CELLS:
			return "The collector must lie inside the canvas and hold at most %d cells." % MAX_COLLECTOR_CELLS
		if not _int(value.collector[4],1,MAX_COLLECTOR_RATE): return "Collector rate must be 1-%d cells per tick." % MAX_COLLECTOR_RATE
	if not _int(value.solid_supply,0,MAX_SOLID_STOCK) or not value.conveyor is bool:
		return "Solid supply must be 0-%d cells and conveyor a true/false switch." % MAX_SOLID_STOCK
	if value.launcher.is_empty() and (value.conveyor or int(value.solid_supply) != 0):
		return "Conveyor and solid supply need a launcher."
	if not value.loadout is Array or value.loadout.size() != 3:
		return "Loadout needs three port entries (Q, E, S)."
	for usable: Variant in value.loadout:
		if not usable is String or (not usable.is_empty() and not KineticUsables.valid(usable)):
			return "Unknown port usable: " + str(usable)
	if not value.kinetics is Array or value.kinetics.size() > MAX_KINETICS:
		return "At most %d kinetic emitters." % MAX_KINETICS
	for emitter: Variant in value.kinetics:
		if not emitter is Array or emitter.size() != 6: return "Kinetic emitter needs [x, y, preset, radius, strength, angle]."
		if not _int(emitter[0],2,extent.x-3) or not _int(emitter[1],2,extent.y-3): return "Place kinetic emitters inside the canvas."
		var error := Kinetic.valid_request(emitter[2],emitter[3],emitter[4],emitter[5])
		if not error.is_empty(): return error
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
	if not value.launcher.is_empty():
		result.launcher = [int(value.launcher[0]),int(value.launcher[1]),float(value.launcher[2]),float(value.launcher[3]),
			int(value.launcher[4]),int(value.launcher[5])]
	result.collector = Array(PackedInt32Array(value.collector))
	result.solid_supply = int(value.solid_supply)
	result.conveyor = bool(value.conveyor)
	result.loadout = [str(value.loadout[0]),str(value.loadout[1]),str(value.loadout[2])]
	for emitter: Array in value.kinetics:
		result.kinetics.append([int(emitter[0]),int(emitter[1]),str(emitter[2]),int(emitter[3]),float(emitter[4]),float(emitter[5])])
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
	_solids = false
	_launcher = Vector2i(-1,-1)
	_launcher_angle = 0.0
	_launcher_speed = 0.0
	_launcher_rate = 0
	_launcher_material = 0
	_launcher_on = false
	_launched = 0
	_launched_cells = 0
	_launcher_refused = {}
	_collector = Rect2i()
	_collector_rate = 0
	_collector_open = false
	_collected = {}
	_conveyor = false
	_solid_stock = 0
	_solid_supplied = 0
	_population = -1
	_populations = {}
	_kinetics = []
	_kinetic_totals = {"applications":0,"water":0,"solids":0,"refused":{},"truncated":0}
	_kinetic_last = {}
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
	if kind == "kinetic_at":
		# The pointer tool: one application at any canvas cell, with or without
		# authored equipment. Refusals are counted; nothing else changes.
		var error := Kinetic.valid_request(request.get("preset"),request.get("radius"),request.get("strength"),request.get("angle"))
		var at: Variant = request.get("at")
		if error.is_empty() and (not at is Vector2i or not Rect2i(Vector2i.ZERO,extent).has_point(at)): error = "outside the canvas"
		if error.is_empty() and (world == null or world.has_failed()): error = "World unavailable"
		if not error.is_empty():
			_refuse("kinetic_at: " + error)
			return
		if _extent == Vector2i.ZERO: _extent = extent
		_kinetic_apply(world,at,str(request.preset),int(request.radius),float(request.strength),float(request.angle),-1)
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
		"launcher":
			if _launcher.x >= 0: _launcher_on = bool(request.get("on",false))
			else: _refuse("launcher: not installed")
		"collector":
			if _collector.has_area(): _collector_open = bool(request.get("open",false))
			else: _refuse("collector: not installed")
		"tune_launcher":
			if _launcher.x < 0:
				_refuse("tune_launcher: no launcher")
			elif not _num(request.get("angle"),-180.0,180.0) or not _num(request.get("speed"),0.5,6.0) \
					or not _int(request.get("rate"),1,MAX_LAUNCHER_RATE):
				_refuse("tune_launcher: outside admission")
			else:
				_launcher_angle = float(request.angle)
				_launcher_speed = float(request.speed)
				_launcher_rate = int(request.rate)
				_config.launcher = [_launcher.x,_launcher.y,_launcher_angle,_launcher_speed,_launcher_rate,_launcher_material]
		"kinetic_pulse", "kinetic_hold":
			var index: Variant = request.get("index",-1)
			if _kinetics.is_empty():
				_refuse("%s: no kinetic emitters" % kind)
			elif not _int(index,-1,_kinetics.size()-1):
				_refuse("%s: no emitter %s" % [kind,str(index)])
			else:
				for i: int in _kinetics.size():
					if int(index) != -1 and i != int(index): continue
					if kind == "kinetic_hold":
						_kinetics[i].hold = bool(request.get("on",false))
						_kinetics[i].timer = 0
					else:
						var e: Dictionary = _kinetics[i]
						_kinetic_apply(world,e.at,e.preset,e.radius,e.strength,e.angle,i)
		"stop":
			for emitter: Dictionary in _kinetics: emitter.hold = false
			for valve: Dictionary in _valves: _set_valve(valve,false)
			_drain_open = false
			_nozzle_on = false
			_launcher_on = false
			_collector_open = false
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
	_solids = world.has_method(&"get_ballistic_solids") and world.has_method(&"inject_solid_parcel") \
		and bool(world.get_ballistic_solids().get("enabled",false))
	if not config.launcher.is_empty():
		_launcher = Vector2i(int(config.launcher[0]),int(config.launcher[1]))
		_launcher_angle = float(config.launcher[2])
		_launcher_speed = float(config.launcher[3])
		_launcher_rate = int(config.launcher[4])
		_launcher_material = int(config.launcher[5])
	if not config.collector.is_empty():
		_collector = _rect(config.collector)
		_collector_rate = int(config.collector[4])
	_conveyor = bool(config.conveyor)
	for emitter: Array in config.kinetics:
		_kinetics.append({"at":Vector2i(int(emitter[0]),int(emitter[1])),"preset":str(emitter[2]),"radius":int(emitter[3]),
			"strength":float(emitter[4]),"angle":float(emitter[5]),"hold":false,"timer":0,"pulses":0,"water":0,"solids":0})
	_solid_stock = int(config.solid_supply)
	_solid_supplied = _solid_stock
	_sample_population(world)
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
	if _collector_open: _step_collector(world)
	if _launcher_on: _step_launcher(world)
	for i: int in _kinetics.size():
		var e: Dictionary = _kinetics[i]
		if not e.hold: continue
		if int(e.timer) <= 0:
			_kinetic_apply(world,e.at,e.preset,e.radius,e.strength,e.angle,i)
			e.timer = int(Kinetic.PRESETS[e.preset].period)
		e.timer = int(e.timer) - 1
	_sample_population(world)
	_last = {"tick":_ticks,"drained":_drained_water-drained_before,"injected":_injected_water-injected_before,"reads":_reads}
	if _drain_open or _nozzle_on or _collector_open or _launcher_on or waiting > 0 or _any_hold(): _active_ticks += 1


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


# Collector: bottom row first, at most `rate` cells per tick, skipping masked
# cells. Every removed cell is counted by material; with the conveyor on, cells
# of the launcher's material enter its stock (the stock never deletes: a full
# stock stops the collector).
func _step_collector(world: Object) -> void:
	var removed := 0
	for y: int in range(_collector.end.y-1,_collector.position.y-1,-1):
		for x: int in range(_collector.position.x,_collector.end.x):
			if removed >= _collector_rate or _reads >= MAX_READS: return
			var cell := Vector2i(x,y)
			var material := _material(world,cell)
			if not material in SOLIDS or _mask(world,cell) != 0: continue
			var feeds := _conveyor and material == _launcher_material
			if feeds and _solid_stock >= MAX_SOLID_STOCK: return
			world.emit_disc(x,y,0,0)
			if _material(world,cell) != 0: continue
			removed += 1
			_collected[material] = int(_collected.get(material,0)) + 1
			if feeds: _solid_stock += 1


# Worker publication samples the population at the same boundary as the
# ballistic-solid roster, so grid + ballistic + stock is read consistently.
func refresh_population(world: Object) -> void:
	if world != null and not world.has_failed() and (configured or _kinetic_totals.applications > 0): _sample_population(world)


func _any_hold() -> bool:
	for e: Dictionary in _kinetics:
		if e.hold: return true
	return false


func _kinetic_apply(world: Object, at: Vector2i, preset: String, radius: int, strength: float, angle: float, index: int) -> void:
	_kinetic_serial += 1
	var planned := Kinetic.plan(world,_extent,at,preset,radius,strength,angle,_kinetic_serial)
	var result := Kinetic.apply(world,planned)
	_kinetic_totals.applications += 1
	_kinetic_totals.water += int(result.water)
	_kinetic_totals.solids += int(result.solids)
	if result.truncated: _kinetic_totals.truncated += 1
	for reason: String in result.refused:
		_kinetic_totals.refused[reason] = int(_kinetic_totals.refused.get(reason,0)) + int(result.refused[reason])
	_kinetic_last = {"serial":_kinetic_serial,"emitter":index,"preset":preset,"at":at,"water":result.water,"solids":result.solids,
		"refused":result.refused.duplicate(),"reads":planned.reads}
	if index >= 0:
		var e: Dictionary = _kinetics[index]
		e.pulses = int(e.pulses) + 1
		e.water = int(e.water) + int(result.water)
		e.solids = int(e.solids) + int(result.solids)


func _sample_population(world: Object) -> void:
	if not world.has_method(&"get_material_population"): return
	if _launcher.x >= 0: _population = int(world.get_material_population(_launcher_material))
	for material: int in Kinetic.CELLS: _populations[str(material)] = int(world.get_material_population(material))


func _step_launcher(world: Object) -> void:
	var axis := Vector2.RIGHT.rotated(deg_to_rad(_launcher_angle))
	for _index: int in range(_launcher_rate):
		if _solid_stock <= 0:
			_launcher_refused["empty"] = int(_launcher_refused.get("empty",0)) + 1
			return
		var muzzle := Vector2(_launcher) + Vector2(0.5,0.5) + axis * 1.5
		if _solids:
			var outcome: String = world.inject_solid_parcel(muzzle,axis * _launcher_speed,_launcher_material)
			if outcome != "launched":
				_launcher_refused[outcome] = int(_launcher_refused.get(outcome,0)) + 1
				return
			_solid_stock -= 1
			_launched += 1
			continue
		var cell := Vector2i(muzzle.floor())
		if not Rect2i(Vector2i.ONE,_extent-Vector2i(2,2)).has_point(cell) or _material(world,cell) != 0 or _mask(world,cell) != 0:
			_launcher_refused["muzzle_blocked"] = int(_launcher_refused.get("muzzle_blocked",0)) + 1
			return
		world.emit_disc(cell.x,cell.y,0,_launcher_material)
		if _material(world,cell) != _launcher_material:
			_launcher_refused["write_refused"] = int(_launcher_refused.get("write_refused",0)) + 1
			return
		_solid_stock -= 1
		_launched += 1
		_launched_cells += 1
		return


func _kinetic_receipts() -> Array:
	var out := []
	for e: Dictionary in _kinetics:
		out.append({"at":[e.at.x,e.at.y],"preset":e.preset,"radius":e.radius,"strength":e.strength,"angle":e.angle,
			"hold":e.hold,"pulses":e.pulses,"water":e.water,"solids":e.solids})
	return out


func _string_keys(values: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in values: out[str(key)] = values[key]
	return out


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
		"solids_mode":"ballistic solids" if _solids else "cells at rest",
		"launcher":{"installed":_launcher.x >= 0,"on":_launcher_on,"angle":_launcher_angle,"speed":_launcher_speed,
			"rate":_launcher_rate,"material":_launcher_material,"launched":_launched,"cell_launches":_launched_cells,
			"refused":_launcher_refused.duplicate()},
		"collector":{"installed":_collector.has_area(),"open":_collector_open,"rate":_collector_rate,
			"collected":_string_keys(_collected)},
		"solid_stock":{"conveyor":_conveyor,"stock":_solid_stock,"supplied":_solid_supplied,"population":_population},
		"populations":_populations.duplicate(),
		"kinetics":_kinetic_receipts(),"kinetic_totals":_kinetic_totals.duplicate(true),"kinetic_last":_kinetic_last.duplicate(true),
		"last":_last.duplicate(),"last_refusal":_last_refusal,"refused":_refused,
		"observation_serial":_observation_serial,"observations":_observations.duplicate(true)}
