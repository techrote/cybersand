extends RefCounted

## Optional integration contract for successor programmes. Capability reports are
## data only; this module cannot dispatch methods, load scripts or import branches.
## No optional family is enabled until a separately qualified adapter is compiled.
const SCHEMA := "cybersand-goblin-optional-capabilities-v1"
const VERSION := 1
const FEATURES := ["ambient", "objectshard", "strata", "materials_lab", "gentek", "art"]
const MAX_ACTIONS := 32


static func validate_offer(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 5 or not value.has_all(["schema", "version", "feature", "source", "actions"]):
		return {"ok": false, "reason": "capability offer needs the exact versioned fields"}
	if value.schema != SCHEMA or value.version != VERSION or value.feature not in FEATURES:
		return {"ok": false, "reason": "unsupported optional capability contract"}
	if not value.source is String or value.source.length() != 40 or not value.source.is_valid_hex_number(false):
		return {"ok": false, "reason": "optional adapter needs a pinned source identity"}
	if not value.actions is Array or value.actions.size() > MAX_ACTIONS:
		return {"ok": false, "reason": "optional action budget exceeded"}
	var seen := {}
	for action: Variant in value.actions:
		if not action is String or action.length() > 64 or action.is_empty() or not action.is_valid_identifier() or seen.has(action):
			return {"ok": false, "reason": "optional action identities must be unique bounded identifiers"}
		seen[action] = true
	return {"ok": true}


static func negotiate(_host: Variant = null, _bench: Variant = null) -> Dictionary:
	var families := {}
	for feature: String in FEATURES:
		families[feature] = {"enabled": false, "registered": false, "actions": [],
			"reason": "No separately qualified gameplay adapter is registered in this source."}
	return {"schema": SCHEMA, "version": VERSION, "families": families,
		"coverage": "Capability negotiation is never counted as admitted gameplay."}
