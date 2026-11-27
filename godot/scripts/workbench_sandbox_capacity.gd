extends RefCounted

# Versioned authored allocation/admission budgets, independent of frame rate.
# Missing Setup-v2 metadata retains the accepted eight-actor / 64-body defaults.
# The 4096 native ceiling bounds per-World response scratch and uint16 masks;
# logical actors, actual prepared bodies and occupancy proxies are charged apart.
const VERSION := 1
const DEFAULT_ACTORS := 8
const DEFAULT_BODIES := 64
const MAX_ACTORS := 4096
const MAX_BODIES := 4096
const MAX_PARTS := 8
const KEYS := ["version", "logical_limit", "body_limit", "proxy_limit"]


static func defaults() -> Dictionary:
	return {"version":VERSION, "logical_limit":DEFAULT_ACTORS,
		"body_limit":DEFAULT_BODIES, "proxy_limit":DEFAULT_BODIES}


static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high


static func error(value: Variant) -> String:
	if not value is Dictionary or value.size() != KEYS.size() or not value.has_all(KEYS):
		return "Sandbox capacity needs version, logical_limit, body_limit and proxy_limit."
	if not _integer(value.version, VERSION, VERSION): return "Unsupported sandbox capacity version."
	if not _integer(value.logical_limit, 1, MAX_ACTORS):
		return "Logical actor capacity must be an integer from 1 to %d." % MAX_ACTORS
	for key: String in ["body_limit", "proxy_limit"]:
		if not _integer(value[key], 1, MAX_BODIES):
			return "%s must be an integer from 1 to %d." % [key, MAX_BODIES]
	return ""


static func summary(actors: Array, value: Dictionary = {}) -> Dictionary:
	var limits := defaults() if value.is_empty() else value.duplicate(true)
	# Runtime lookup avoids a static preload cycle: the catalogue also uses the
	# numeric capacity contract when validating an authored composition.
	var catalogue = load("res://scripts/workbench_actor_catalog.gd")
	var result: Dictionary = catalogue.resource_usage(actors)
	result.merge(limits, true)
	result.merge({"max_logical":MAX_ACTORS, "max_bodies":MAX_BODIES,
		"max_proxies":MAX_BODIES}, true)
	return result
