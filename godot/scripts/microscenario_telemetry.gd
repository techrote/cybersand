class_name CyberMicroScenarioTelemetry
extends RefCounted

# Fixed-size aggregate state. Histories retain at most the first 3600 samples.
# Native values are copied at successful owner boundaries, never read by the UI.
const LIMIT: int = 3600
const COUNTERS: Array[String] = ["visited_cells", "moved_cells", "scheduled_cores",
	"chunk_allocations", "temperature_field_allocations", "deferred_events_processed"]
var latest: Dictionary = {}
var maximum: Dictionary = {}
var totals: Dictionary = {}
var sampled_ticks: int = 0
var host_samples: Array[float] = []
var host_total_ms: float = 0.0
var host_count: int = 0

func sample(world: Variant, bridge: Variant, completed_tick: bool) -> void:
	latest = bridge.inspect_statistics(world)
	if not latest.get("ok", false): return
	for key: String in latest["values"]:
		maximum[key] = maxi(int(maximum.get(key, 0)), int(latest["values"][key]))
	if not completed_tick: return
	sampled_ticks += 1
	for key: String in COUNTERS:
		totals[key] = int(totals.get(key, 0)) + int(latest["values"][key])

func host_sample(elapsed_ms: float) -> void:
	host_total_ms += elapsed_ms
	host_count += 1
	if host_samples.size() < LIMIT: host_samples.append(elapsed_ms)

func capture() -> Dictionary:
	return {"available":not latest.is_empty(), "latest":latest.duplicate(true),
		"max_observed":maximum.duplicate(true), "totals":totals.duplicate(true),
		"sampled_ticks":sampled_ticks,
		"sampling":"setup and each successful observed tick; peaks are counts, not queue occupancy",
		"host_boundary_timing":distribution(host_samples, host_count, host_total_ms,
			"before_tick + after_tick apparatus; includes observations and statistics; excludes native tick, renderer, Rapier, publication and frame pacing")}

static func distribution(samples: Array[float], count: int, total_ms: float, scope: String) -> Dictionary:
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	var out: Dictionary = {"count":count, "retained_count":ordered.size(),
		"retention":"first-3600-completed-ticks", "truncated":count > LIMIT,
		"total_ms":total_ms, "scope":scope}
	if not ordered.is_empty():
		for percentile: int in [50, 95, 99]:
			out["p%d_ms" % percentile] = ordered[clampi(int(ceil(percentile * ordered.size() / 100.0)) - 1, 0, ordered.size() - 1)]
		out.max_ms = ordered.back()
	return out
