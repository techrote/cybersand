class_name CyberWaterExperimentContract
extends RefCounted

# Shared Issue 19 schema identity. Scenario recipes and policy resolution both
# consume these frozen values; neither owns a second registry.
const VERSION: int = 1
const REST_POLICY: String = "current-normalized-v1"
const INTERFACE_MODES: Array[String] = ["coverage", "oriented"]
const POLICY_KEYS: Array[String] = [
	"version",
	"mass_bits",
	"coherence_ticks",
	"rest_policy",
	"render_fill_levels",
	"interface_mode",
	"scenario_id",
	"seed",
]
const SCENARIO_IDS: Array[String] = [
	"shallow-pool",
	"deep-pool",
	"calm-settling",
	"connected-pools",
	"tiny-quantities",
	"residual-pockets",
	"drips",
	"trickle",
	"fast-dump",
	"slow-release",
	"fall",
	"thin-stream",
	"shower-drizzle",
	"ledge-sheet",
	"narrow-channel",
	"broad-channel",
	"steps",
	"u-vessel",
	"constriction",
	"irregular-bed",
	"direction-vertical",
	"direction-horizontal",
	"direction-diagonal",
	"excavation-refill",
	"support-removal",
	"cavity-fill-drain",
	"real-void-barrier",
	"film-boundaries",
	"storage-seam",
	"activity-seam",
	"core-seam",
	"long-tail-settling",
	"water-sand-baseline",
	"mercury-reference",
	"supported-body-water",
]


static func valid_scenario(id: String) -> bool:
	return id in SCENARIO_IDS


static func default_policy() -> Dictionary:
	return {
		"version": VERSION,
		"mass_bits": 8,
		"coherence_ticks": 12,
		"rest_policy": REST_POLICY,
		"render_fill_levels": 4,
		"interface_mode": "coverage",
		"scenario_id": SCENARIO_IDS[0],
		"seed": 0,
	}
