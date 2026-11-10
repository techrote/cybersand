extends RefCounted

# Kinetic usables: one catalogue shared by workbench flyer ports and (later)
# F5 actor equipment. Every entry is a small parameter set over two mechanisms:
#   shooter - fires a burst of real flying cells of one material along the aim
#             (Water as BW-001 parcels, everything else as BS-001 cells). It is
#             an explicit material source: each launched cell is booked by the
#             native owners as injected.
#   wand    - applies a kinetic mask preset a short reach along the aim, so the
#             cells already there fly (exact transfers, nothing created).
# Runs only on the simulation worker, between ticks. Deterministic for a given
# World state and seed.

const Kinetic = preload("res://scripts/workbench_kinetic_mask.gd")
const WATER := 3

const ENTRIES := {
	"sand_blaster":    {"label":"Sand blaster",    "kind":"shooter","material":2, "count":4,"spread":10.0,"speed":4.5},
	"gravel_shotgun":  {"label":"Gravel shotgun",  "kind":"shooter","material":13,"count":7,"spread":24.0,"speed":5.0},
	"stone_slug":      {"label":"Stone slug",      "kind":"shooter","material":13,"count":1,"spread":0.0, "speed":6.0},
	"water_cannon":    {"label":"Water cannon",    "kind":"shooter","material":3, "count":5,"spread":6.0, "speed":5.0},
	"oil_sprayer":     {"label":"Oil sprayer",     "kind":"shooter","material":16,"count":5,"spread":16.0,"speed":3.6},
	"lava_spitter":    {"label":"Lava spitter",    "kind":"shooter","material":8, "count":3,"spread":8.0, "speed":4.0},
	"acid_mister":     {"label":"Acid mister",     "kind":"shooter","material":12,"count":6,"spread":30.0,"speed":3.0},
	"blast_glove":     {"label":"Blast glove",     "kind":"wand","preset":"blast",    "radius":8, "strength":1.0,"reach":7},
	"shovel_gauntlet": {"label":"Shovel gauntlet", "kind":"wand","preset":"shovel",   "radius":10,"strength":1.0,"reach":2},
	"vortex_lance":    {"label":"Vortex lance",    "kind":"wand","preset":"vortex",   "radius":8, "strength":1.0,"reach":11},
	"shockwave_stomp": {"label":"Shockwave stomp", "kind":"wand","preset":"shockwave","radius":12,"strength":1.0,"reach":0},
	"gust_fan":        {"label":"Gust fan",        "kind":"wand","preset":"gust",     "radius":10,"strength":1.2,"reach":9},
	"geyser_rod":      {"label":"Geyser rod",      "kind":"wand","preset":"geyser",   "radius":12,"strength":1.0,"reach":6},
}
const ORDER := ["sand_blaster","gravel_shotgun","stone_slug","water_cannon","oil_sprayer","lava_spitter","acid_mister",
	"blast_glove","shovel_gauntlet","vortex_lance","shockwave_stomp","gust_fan","geyser_rod"]


static func valid(id: Variant) -> bool:
	return id is String and ENTRIES.has(id)


# Fires one use of `id` from the muzzle cell along `axis` (unit vector), scaled
# by `power` (0..1, 1 = full). Returns exact counts by outcome.
static func fire(world: Object, extent: Vector2i, muzzle: Vector2, axis: Vector2, id: String, power: float, seed: int) -> Dictionary:
	var out := {"launched":0,"water":0,"solids":0,"refused":{}}
	if not valid(id) or not axis.is_finite() or axis.length_squared() < 0.5:
		out.refused["invalid"] = 1
		return out
	var entry: Dictionary = ENTRIES[id]
	var scale := clampf(power,0.1,1.0)
	if entry.kind == "wand":
		var centre := Vector2i((muzzle + axis * float(entry.reach)).floor())
		if not Rect2i(Vector2i.ONE,extent - Vector2i(2,2)).has_point(centre):
			out.refused["outside"] = 1
			return out
		var planned := Kinetic.plan(world,extent,centre,str(entry.preset),int(entry.radius),float(entry.strength) * scale,
			rad_to_deg(axis.angle()),seed)
		var result := Kinetic.apply(world,planned)
		out.water = int(result.water)
		out.solids = int(result.solids)
		out.launched = out.water + out.solids
		out.refused = result.refused
		return out
	var count := int(entry.count)
	var material := int(entry.material)
	for i: int in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var jitter := (Kinetic._hash01(i,seed,material) - 0.5) * 3.0
		var direction := axis.rotated(deg_to_rad(float(entry.spread) * t + jitter))
		var speed := float(entry.speed) * scale * (0.92 + 0.16 * Kinetic._hash01(seed,i,7))
		var outcome := "unsupported"
		if material == WATER and world.has_method(&"inject_water_parcel"):
			outcome = world.inject_water_parcel(muzzle,direction * speed,255)
		elif material != WATER and world.has_method(&"inject_solid_parcel"):
			outcome = world.inject_solid_parcel(muzzle,direction * speed,material)
		if outcome == "launched":
			out.launched += 1
			out[("water" if material == WATER else "solids")] += 1
		else:
			out.refused[outcome] = int(out.refused.get(outcome,0)) + 1
	return out
