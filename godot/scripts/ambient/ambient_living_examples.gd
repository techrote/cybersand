extends RefCounted

# Six ordinary Setup-v2 authored native Worlds. Loading delegates all material,
# lifecycle, saved-data and physical actor ownership to the normal Workbench.
const Setup = preload("res://scripts/workbench_setup.gd")
const ENTRIES := [
	{"id":"ambient2-settlement", "name":"Living settlement · Foundry Row", "description":"Eight inhabitants share a service street, individual homes and common activity areas. Two affinity groups and contrasting personalities create temporary company."},
	{"id":"ambient2-refinery", "name":"Oil refinery · Pipe Orchard", "description":"Six inhabitants investigate real Oil and avoid Water. A sealed Oil cabinet is within a scavenger's material scope but physically inaccessible; inspect failed approaches and changing interests."},
	{"id":"ambient2-cavern", "name":"Cavern · Echo Galleries", "description":"Native rock chambers, dead ends and alternate aerial passages challenge local exploration and recovery. The system has bounded local steering, not a guaranteed global route planner."},
	{"id":"ambient2-courtyard", "name":"Social courtyard · Common Ground", "description":"Eight ground inhabitants have personal homes, two affinity groups and a common interest region. Observe congregation, spacing, withdrawal and renewed curiosity."},
	{"id":"ambient2-floodyard", "name":"Floodable yard · Rain Exchange", "description":"Real Water leaves an overhead tank and changes the lower yard while six inhabitants follow evolving material observations. Paint or erase a gate to change the physical environment."},
	{"id":"ambient2-aerial-habitat", "name":"Aerial habitat · Lantern Hangar", "description":"Six independent 4LY inhabitants explore open bays, docking homes and suspended material gardens. Cautious flyers, boundary followers and solitary explorers share the same actuator contracts."},
]


static func entries() -> Array:
	return ENTRIES.duplicate(true)


static func make(id: String, policy: PackedInt32Array) -> Dictionary:
	var known := false
	for entry: Dictionary in ENTRIES:
		if str(entry.id) == id: known = true; break
	if not known: return {}
	var path := "res://examples/workbench/" + id + ".json"
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary: return {}
	# A scene adopts the owner's actual liquid policy by the ordinary setup path.
	# Its native materials, profile configuration and actor definitions are copied.
	value.liquid_policy = Array(policy)
	if not Setup.validate(value).is_empty(): return {}
	return value.duplicate(true)
