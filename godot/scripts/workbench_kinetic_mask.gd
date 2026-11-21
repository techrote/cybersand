extends RefCounted

# Kinetic mask core (BS-001 / BW-001 tools). A kinetic application stamps a
# bounded mask onto the World; every selected Water or admitted solid cell inside
# it is launched in place by the native ballistic owners with a velocity from a
# field. Tools are presets: shape x pattern x field x strength. Runs only on the
# simulation worker, between ticks; it never edits velocity of grid cells or
# creates material, it only hands whole cells to the native flight owners.
#
#   shape   disc | ring | cone | column | box
#   pattern all | checker | random(fraction) | edge
#   field   radial | inward | vortex | direction | jitter
# Strength is cells per tick before falloff; jitter adds bounded noise; lift adds
# an upward component. Randomness is a hash of the cell and application serial,
# so an application is deterministic for a given World state.

const WATER := 3
# Solids the tools try to launch (powders and Stone); the native owner decides
# admission again and refuses anything else.
const SOLIDS := [2,13,14,19,23,26,27,29]
# Non-Water liquids fly through the same owner as whole cells (BS-001).
const LIQUIDS := [8,12,16,20,21,24,32,33,36]
const CELLS := SOLIDS + LIQUIDS
const MAX_RADIUS := 24
const MAX_LAUNCHES := 640
const MAX_READS := 6000

const PRESETS := {
	"blast":      {"label":"Blast",      "shape":"disc",   "pattern":"all",     "field":"radial",    "speed":4.0, "falloff":0.6, "jitter":0.15, "lift":0.6, "period":24},
	"implode":    {"label":"Implode",    "shape":"disc",   "pattern":"all",     "field":"inward",    "speed":2.6, "falloff":0.0, "jitter":0.10, "lift":0.0, "period":30},
	"vortex":     {"label":"Vortex",     "shape":"disc",   "pattern":"all",     "field":"vortex",    "speed":3.0, "falloff":0.3, "jitter":0.10, "lift":0.8, "period":18},
	"geyser":     {"label":"Geyser",     "shape":"column", "pattern":"all",     "field":"direction", "speed":5.2, "falloff":0.0, "jitter":0.20, "lift":0.0, "period":10, "angle":-90.0},
	"shovel":     {"label":"Shovel",     "shape":"cone",   "pattern":"all",     "field":"direction", "speed":3.4, "falloff":0.2, "jitter":0.15, "lift":0.9, "period":20, "spread":35.0},
	"shockwave":  {"label":"Shockwave",  "shape":"ring",   "pattern":"all",     "field":"radial",    "speed":5.0, "falloff":0.0, "jitter":0.05, "lift":0.4, "period":30},
	"gust":       {"label":"Gust",       "shape":"box",    "pattern":"random",  "field":"direction", "speed":2.6, "falloff":0.0, "jitter":0.30, "lift":0.3, "period":6, "fraction":0.45},
	"shaker":     {"label":"Shaker",     "shape":"disc",   "pattern":"random",  "field":"jitter",    "speed":1.6, "falloff":0.0, "jitter":1.00, "lift":0.7, "period":4, "fraction":0.30},
	"pepper":     {"label":"Pepper",     "shape":"disc",   "pattern":"random",  "field":"radial",    "speed":3.2, "falloff":0.0, "jitter":0.40, "lift":0.5, "period":8, "fraction":0.12},
	"lattice":    {"label":"Lattice lift","shape":"disc",  "pattern":"checker", "field":"direction", "speed":3.0, "falloff":0.3, "jitter":0.05, "lift":0.0, "period":20, "angle":-90.0},
	"skin":       {"label":"Skin peel",  "shape":"disc",   "pattern":"edge",    "field":"radial",    "speed":2.4, "falloff":0.0, "jitter":0.20, "lift":0.5, "period":14},
}
const ORDER := ["blast","implode","vortex","geyser","shovel","shockwave","gust","shaker","pepper","lattice","skin"]


static func valid_request(preset: Variant, radius: Variant, strength: Variant, angle: Variant) -> String:
	if not preset is String or not PRESETS.has(preset): return "unknown kinetic preset"
	if not _int(radius,2,MAX_RADIUS): return "kinetic radius must be 2-%d" % MAX_RADIUS
	if not _num(strength,0.1,3.0): return "kinetic strength must be 0.1-3"
	if not _num(angle,-180.0,180.0): return "kinetic angle must be -180..180"
	return ""


static func _int(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) \
		and float(value) >= low and float(value) <= high


static func _num(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func _hash01(x: int, y: int, seed: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func _in_shape(spec: Dictionary, offset: Vector2, radius: float, axis: Vector2) -> bool:
	var distance := offset.length()
	match str(spec.shape):
		"disc": return distance <= radius
		"ring": return distance <= radius and distance >= radius * 0.62
		"cone":
			if distance > radius or distance < 0.5: return distance < 0.5
			return rad_to_deg(absf(axis.angle_to(offset))) <= float(spec.get("spread",35.0))
		"column": return absf(offset.x) <= maxf(1.0,radius * 0.25) and offset.y <= 0.5 and offset.y >= -radius
		"box": return absf(offset.x) <= radius and absf(offset.y) <= radius * 0.5
	return false


static func _selected(spec: Dictionary, cell: Vector2i, offset: Vector2, radius: float, seed: int, is_edge: bool) -> bool:
	match str(spec.pattern):
		"all": return true
		"checker": return (cell.x + cell.y) % 2 == 0
		"random": return _hash01(cell.x,cell.y,seed) < float(spec.get("fraction",0.5))
		"edge": return is_edge
	return false


static func _velocity(spec: Dictionary, offset: Vector2, radius: float, strength: float, axis: Vector2,
		cell: Vector2i, seed: int) -> Vector2:
	var distance := offset.length()
	var outward := offset / distance if distance > 0.01 else axis
	var falloff := 1.0 - float(spec.falloff) * clampf(distance / maxf(radius,1.0),0.0,1.0)
	var speed := float(spec.speed) * strength * falloff
	var direction := Vector2.ZERO
	match str(spec.field):
		"radial": direction = outward
		"inward": direction = -outward
		"vortex": direction = Vector2(-outward.y,outward.x) * 0.85 + outward * 0.25
		"direction": direction = axis
		"jitter": direction = Vector2.ZERO
	var jitter := float(spec.jitter)
	var noise := Vector2(_hash01(cell.x,cell.y,seed + 17) * 2.0 - 1.0,_hash01(cell.y,cell.x,seed + 31) * 2.0 - 1.0)
	var velocity := direction.normalized() * speed + noise * jitter * maxf(speed,1.0) + Vector2(0.0,-float(spec.lift))
	return velocity.limit_length(6.0)


# Plans one application without mutating: the cells to launch, each with its
# velocity, ordered so cells further along their own motion leave first (their
# neighbours then have room). Bounded by MAX_READS world reads.
static func plan(world: Object, extent: Vector2i, center: Vector2i, preset: String, radius: int,
		strength: float, angle: float, seed: int) -> Dictionary:
	var spec: Dictionary = PRESETS[preset]
	var axis := Vector2.RIGHT.rotated(deg_to_rad(float(spec.get("angle",angle))))
	var reads := 0
	var cells: Array = []
	var canvas := Rect2i(Vector2i.ONE,extent - Vector2i(2,2))
	for dy: int in range(-radius,radius + 1):
		for dx: int in range(-radius,radius + 1):
			var offset := Vector2(dx,dy)
			if not _in_shape(spec,offset,float(radius),axis): continue
			var cell := center + Vector2i(dx,dy)
			if not canvas.has_point(cell): continue
			if reads >= MAX_READS: break
			reads += 2
			var material := int(world.material_at(cell.x,cell.y))
			if material != WATER and not material in CELLS: continue
			if int(world.rigid_body_id_at(cell.x,cell.y)) != 0: continue
			var is_edge := false
			if str(spec.pattern) == "edge":
				for step: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
					reads += 1
					if int(world.material_at(cell.x + step.x,cell.y + step.y)) == 0: is_edge = true
			if not _selected(spec,cell,offset,float(radius),seed,is_edge): continue
			var velocity := _velocity(spec,offset,float(radius),strength,axis,cell,seed)
			if velocity.length_squared() < 0.0025: continue
			var lead := offset.dot(velocity.normalized())
			cells.append([lead,cell,velocity,material])
	cells.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return {"cells":cells.slice(0,MAX_LAUNCHES),"truncated":cells.size() > MAX_LAUNCHES,"reads":reads}


# Executes a plan through the native owners. Returns exact counts by outcome.
static func apply(world: Object, plan_result: Dictionary) -> Dictionary:
	var out := {"water":0,"solids":0,"refused":{}}
	var water_ok := world.has_method(&"launch_water_parcel")
	var solids_ok := world.has_method(&"launch_solid_parcel")
	for entry: Array in plan_result.cells:
		var cell: Vector2i = entry[1]
		var velocity: Vector2 = entry[2]
		var material: int = entry[3]
		var position := Vector2(cell) + Vector2(0.5,0.5)
		var outcome := "unsupported"
		if material == WATER and water_ok: outcome = world.launch_water_parcel(cell,position,velocity)
		elif material != WATER and solids_ok: outcome = world.launch_solid_parcel(cell,position,velocity)
		if outcome == "launched":
			out[("water" if material == WATER else "solids")] += 1
		else:
			out.refused[outcome] = int(out.refused.get(outcome,0)) + 1
	out.truncated = plan_result.truncated
	return out
