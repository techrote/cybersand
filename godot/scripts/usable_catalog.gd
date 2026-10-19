class_name CyberUsableCatalog
extends RefCounted

const CATEGORY_TOOL: StringName = &"tool"
const CATEGORY_PROJECTILE: StringName = &"projectile"
const CATEGORY_OBJECT: StringName = &"object"

const USABLE_IDS: Array[StringName] = [
	&"sand_scatter", &"water_lance", &"cement_extruder", &"brick_stamper",
	&"seed_duster", &"foam_sprayer", &"line_cutter", &"rotary_borer",
	&"powder_vacuum", &"liquid_drain", &"glass_scorer", &"acid_wash",
	&"impact_slug", &"borer_round", &"ricochet_pellet", &"sticky_delay_charge",
	&"timer_airburst", &"water_capsule", &"oil_igniter", &"seed_pod",
	&"cement_blob", &"water_contact_charge", &"stone_grinder", &"glass_reclaimer",
	&"brine_splitter", &"glass_kiln", &"steam_condenser", &"cement_finisher",
	&"sludge_scrubber", &"metal_reclaimer", &"seed_incubator", &"firewarden",
]

const TOOL_IDS: Array[StringName] = [
	&"sand_scatter", &"water_lance", &"cement_extruder", &"brick_stamper",
	&"seed_duster", &"foam_sprayer", &"line_cutter", &"rotary_borer",
	&"powder_vacuum", &"liquid_drain", &"glass_scorer", &"acid_wash",
]
const PROJECTILE_IDS: Array[StringName] = [
	&"impact_slug", &"borer_round", &"ricochet_pellet", &"sticky_delay_charge",
	&"timer_airburst", &"water_capsule", &"oil_igniter", &"seed_pod",
	&"cement_blob", &"water_contact_charge",
]
const OBJECT_IDS: Array[StringName] = [
	&"stone_grinder", &"glass_reclaimer", &"brine_splitter", &"glass_kiln",
	&"steam_condenser", &"cement_finisher", &"sludge_scrubber", &"metal_reclaimer",
	&"seed_incubator", &"firewarden",
]

const DEFINITIONS: Array[Dictionary] = [
	{"id":&"sand_scatter","name":"Sand Scatter","category":CATEGORY_TOOL,"description":"Broad deterministic Sand fan.","operation":&"fan_deposit","material":2,"cooldown":0.08,"cost":0.8,"range":44.0,"spread":0.35,"rays":5,"steps":8,"color":Color(0.76,0.62,0.35)},
	{"id":&"water_lance","name":"Water Lance","category":CATEGORY_TOOL,"description":"Narrow aimed Water deposition.","operation":&"line_deposit","material":3,"cooldown":0.06,"cost":0.7,"range":54.0,"steps":12,"color":Color(0.22,0.55,1.0)},
	{"id":&"cement_extruder","name":"Cement Extruder","category":CATEGORY_TOOL,"description":"Compact Cement bead, up to five cells per pulse.","operation":&"bead","material":30,"cooldown":0.12,"cost":1.2,"range":31.0,"color":Color(0.55,0.57,0.55)},
	{"id":&"brick_stamper","name":"Brick Stamper","category":CATEGORY_TOOL,"description":"Five-position Industrial Brick stamp.","operation":&"stamp","material":57,"cooldown":0.20,"cost":2.2,"range":30.0,"color":Color(0.58,0.24,0.20)},
	{"id":&"seed_duster","name":"Seed Duster","category":CATEGORY_TOOL,"description":"Sparse Seed fan.","operation":&"fan_deposit","material":19,"cooldown":0.16,"cost":1.0,"range":40.0,"spread":0.52,"rays":5,"steps":5,"stride":2,"color":Color(0.44,0.74,0.28)},
	{"id":&"foam_sprayer","name":"Foam Sprayer","category":CATEGORY_TOOL,"description":"Broad transient Foam plume.","operation":&"fan_deposit","material":37,"cooldown":0.08,"cost":0.85,"range":36.0,"spread":0.58,"rays":7,"steps":4,"color":Color(0.84,0.90,0.93)},
	{"id":&"line_cutter","name":"Line Cutter","category":CATEGORY_TOOL,"description":"Thin direct excavation line.","operation":&"line_cut","cooldown":0.08,"cost":0.7,"range":45.0,"steps":13,"color":Color(1.0,0.34,0.24)},
	{"id":&"rotary_borer","name":"Rotary Borer","category":CATEGORY_TOOL,"description":"Near-contact circular excavation.","operation":&"bore","cooldown":0.10,"cost":1.0,"range":22.0,"radius":3,"color":Color(1.0,0.64,0.18)},
	{"id":&"powder_vacuum","name":"Powder Vacuum","category":CATEGORY_TOOL,"description":"Selective loose-powder sink.","operation":&"powder_sink","cooldown":0.08,"cost":0.75,"range":36.0,"radius":4,"color":Color(0.66,0.56,0.72)},
	{"id":&"liquid_drain","name":"Liquid Drain","category":CATEGORY_TOOL,"description":"Selective local liquid sink.","operation":&"liquid_sink","cooldown":0.10,"cost":0.85,"range":29.0,"radius":4,"color":Color(0.24,0.75,0.88)},
	{"id":&"glass_scorer","name":"Glass Scorer","category":CATEGORY_TOOL,"description":"Thin cut limited to supported glass IDs.","operation":&"glass_cut","cooldown":0.09,"cost":0.65,"range":48.0,"steps":14,"color":Color(0.56,0.92,1.0)},
	{"id":&"acid_wash","name":"Acid Wash","category":CATEGORY_TOOL,"description":"Applies Acid through a narrow occluded fan.","operation":&"fan_deposit","material":12,"cooldown":0.10,"cost":1.05,"range":33.0,"spread":0.32,"rays":3,"steps":8,"color":Color(0.42,1.0,0.18)},

	{"id":&"impact_slug","name":"Impact Slug","category":CATEGORY_PROJECTILE,"description":"Fast direct chip round.","operation":&"impact_chip","cooldown":0.14,"cost":2.5,"speed":190.0,"gravity":0.0,"ttl":1.6,"radius":1,"color":Color(0.95,0.95,0.90)},
	{"id":&"borer_round","name":"Borer Round","category":CATEGORY_PROJECTILE,"description":"Heavy round with three editable penetrations.","operation":&"penetrate","cooldown":0.24,"cost":4.0,"speed":150.0,"gravity":18.0,"ttl":1.8,"radius":1,"penetrations":3,"color":Color(1.0,0.62,0.20)},
	{"id":&"ricochet_pellet","name":"Ricochet Pellet","category":CATEGORY_PROJECTILE,"description":"Damped two-bounce pellet.","operation":&"ricochet","cooldown":0.16,"cost":2.0,"speed":170.0,"gravity":55.0,"ttl":2.4,"radius":1,"bounces":2,"color":Color(0.72,0.88,1.0)},
	{"id":&"sticky_delay_charge","name":"Sticky Delay Charge","category":CATEGORY_PROJECTILE,"description":"Sticks on contact and excavates after 0.55 s.","operation":&"sticky_delayed","cooldown":0.35,"cost":6.0,"speed":110.0,"gravity":72.0,"ttl":5.0,"fuse":0.55,"radius":3,"color":Color(1.0,0.30,0.18)},
	{"id":&"timer_airburst","name":"Timer Airburst","category":CATEGORY_PROJECTILE,"description":"0.45 s timer splitting into five child chip shots.","operation":&"airburst","cooldown":0.38,"cost":6.5,"speed":120.0,"gravity":40.0,"ttl":2.8,"fuse":0.45,"children":5,"radius":2,"color":Color(1.0,0.78,0.20)},
	{"id":&"water_capsule","name":"Water Capsule","category":CATEGORY_PROJECTILE,"description":"Releases Water at contact.","operation":&"material_payload","cooldown":0.25,"cost":4.0,"speed":120.0,"gravity":58.0,"ttl":2.4,"material":3,"radius":3,"color":Color(0.20,0.55,1.0)},
	{"id":&"oil_igniter","name":"Oil Igniter","category":CATEGORY_PROJECTILE,"description":"Spills Oil, then attempts Fire after 0.35 s.","operation":&"staged_igniter","cooldown":0.32,"cost":5.0,"speed":115.0,"gravity":62.0,"ttl":3.0,"material":16,"fuse":0.35,"radius":3,"color":Color(0.35,0.24,0.18)},
	{"id":&"seed_pod","name":"Seed Pod","category":CATEGORY_PROJECTILE,"description":"Disperses Seed at contact.","operation":&"material_payload","cooldown":0.30,"cost":3.2,"speed":105.0,"gravity":65.0,"ttl":2.6,"material":19,"radius":3,"color":Color(0.42,0.75,0.28)},
	{"id":&"cement_blob","name":"Cement Blob","category":CATEGORY_PROJECTILE,"description":"Heavy compact Cement payload.","operation":&"material_payload","cooldown":0.34,"cost":5.2,"speed":90.0,"gravity":78.0,"ttl":2.2,"material":30,"radius":2,"color":Color(0.54,0.56,0.55)},
	{"id":&"water_contact_charge","name":"Water Contact Charge","category":CATEGORY_PROJECTILE,"description":"Arms at contact; Water or Brine triggers a Fire pulse.","operation":&"water_sensor","cooldown":0.40,"cost":6.2,"speed":105.0,"gravity":66.0,"ttl":5.0,"material":6,"radius":2,"sensor_radius":4,"color":Color(0.92,0.28,0.22)},

	{"id":&"stone_grinder","name":"Stone Grinder","category":CATEGORY_OBJECT,"description":"Stone -> Sand.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[13,1]],"outputs":[[2,1]],"color":Color(0.58,0.58,0.54)},
	{"id":&"glass_reclaimer","name":"Glass Reclaimer","category":CATEGORY_OBJECT,"description":"Glass -> Sand.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[35,1]],"outputs":[[2,1]],"color":Color(0.50,0.82,0.90)},
	{"id":&"brine_splitter","name":"Brine Splitter","category":CATEGORY_OBJECT,"description":"Two Brine slots -> Water + Salt.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[24,2]],"outputs":[[3,1],[23,1]],"color":Color(0.34,0.70,0.86)},
	{"id":&"glass_kiln","name":"Glass Kiln","category":CATEGORY_OBJECT,"description":"Sand -> Molten Glass with nearby Fire or Lava.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[2,1]],"outputs":[[36,1]],"catalyst_any":[6,8],"color":Color(1.0,0.45,0.12)},
	{"id":&"steam_condenser","name":"Steam Condenser","category":CATEGORY_OBJECT,"description":"Steam -> Water with nearby Ice.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[22,1]],"outputs":[[3,1]],"catalyst_any":[9],"color":Color(0.66,0.86,1.0)},
	{"id":&"cement_finisher","name":"Cement Finisher","category":CATEGORY_OBJECT,"description":"Cement -> Concrete with nearby Water.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[30,1]],"outputs":[[31,1]],"catalyst_any":[3],"color":Color(0.63,0.64,0.63)},
	{"id":&"sludge_scrubber","name":"Sludge Scrubber","category":CATEGORY_OBJECT,"description":"Toxic Sludge + Water -> Water + Dust.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[32,1],[3,1]],"outputs":[[3,1],[14,1]],"color":Color(0.47,0.76,0.37)},
	{"id":&"metal_reclaimer","name":"Metal Reclaimer","category":CATEGORY_OBJECT,"description":"Rust + Coal -> Metal + Smoke.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[29,1],[27,1]],"outputs":[[28,1],[4,1]],"color":Color(0.72,0.48,0.32)},
	{"id":&"seed_incubator","name":"Seed Incubator","category":CATEGORY_OBJECT,"description":"Seed + Water -> Plant.","operation":&"processor","cooldown":0.35,"cost":18.0,"stock":16,"lifetime":45.0,"inputs":[[19,1],[3,1]],"outputs":[[11,1]],"color":Color(0.35,0.82,0.30)},
	{"id":&"firewarden","name":"Firewarden","category":CATEGORY_OBJECT,"description":"Detects nearby Fire and emits Water; twelve pulses.","operation":&"firewarden","cooldown":0.30,"cost":18.0,"stock":12,"lifetime":45.0,"outputs":[[3,1]],"sensor_material":6,"color":Color(0.20,0.62,0.98)},
]

static func count() -> int:
	return DEFINITIONS.size()

static func has_usable(id: StringName) -> bool:
	return USABLE_IDS.has(id)

static func index_for(id: StringName) -> int:
	return USABLE_IDS.find(id)

static func entry(value) -> Dictionary:
	var index: int = value if value is int else index_for(StringName(str(value)))
	if index < 0 or index >= DEFINITIONS.size():
		return {}
	return DEFINITIONS[index].duplicate(true)

static func name_for(value) -> String:
	var definition: Dictionary = entry(value)
	return str(definition.get("name", "None"))

static func category_for(value) -> StringName:
	var definition: Dictionary = entry(value)
	return StringName(str(definition.get("category", "")))

static func controls_text(value) -> String:
	var definition: Dictionary = entry(value)
	if definition.is_empty():
		return "No equipment."
	match StringName(str(definition.category)):
		CATEGORY_TOOL:
			return "Left hold: repeat tool. Right press: one 35% precision pulse."
		CATEGORY_PROJECTILE:
			if StringName(str(definition.id)) in [&"sticky_delay_charge", &"timer_airburst", &"oil_igniter"]:
				return "Left press: launch. Right press: activate oldest eligible owned payload early."
			return "Left press: launch."
		CATEGORY_OBJECT:
			return "Left press: deploy fixed 5x5 processor. Right press: retrieve oldest matching owned device."
	return ""
