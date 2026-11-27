extends RefCounted
## Small reviewed knowledge excerpts with immutable provenance. No filesystem
## search, audit ingestion, HTTP, executable coordinates or model authority.
const ENGINE_PIN := "00cdb02f103265b6dc5224c68283e9a0c8cb449f"
const GOLD_PIN := "b9535405853a5cd16e4bba968ec7167222861c42"
const MAX_BYTES := 4096
const MAX_CARDS := 3

static func cards() -> Array:
	return [
		{"id":"native-authority","tags":["native","material","paint","geometry","room","build","repair","construct"],
			"guidance":"Use integer material geometry and the existing native authoring owner. Rectangle endpoints are inclusive. Ordinary Art may change stored Empty (0) or Hard Wall (58), subject to its area, palette and protected regions; it cannot overwrite other stored materials. A preview or queued request is not a completed edit.",
			"repository":"techrote/cybersand","source_commit":ENGINE_PIN,
			"path":"docs/systems/workbench-direct-art-batches.md","authority":"accepted native authoring contract",
			"executable":false},
		{"id":"gold-support-and-workspace","tags":["industrial","support","structure","mechanism","machine","foundry","workshop","facade","brac"],
			"guidance":"Make support relationships and the connection between apparatus and its workspace legible. An entered receiver gallery, differentiated machine surfaces and visible supporting members can express architectural intent. Material geometry that resembles machinery does not establish functional simulation.",
			"repository":"techrote/sandmapsreference","source_commit":GOLD_PIN,
			"path":"docs/corpus/goldmaps-recovery-001/D1-D2-REFERENCE-REVIEW.md",
			"source_blob":"3c8e134b52e2bc46f399ee3173f15d9472c8957b",
			"authority":"source-pinned research interpretation; owner aesthetic acceptance pending","executable":false},
		{"id":"gold-negative-space","tags":["preserve","passage","route","travers","interior","courtyard","opening","clearance","corridor"],
			"guidance":"Treat useful negative space and preservation of original spatial logic as explicit design goals. Protect named passages geometrically. A static clear opening is not proof of actor reachability or playfeel; evaluate the intended actor and route separately. Loss of a protected route or void is a regression even if detail increases.",
			"repository":"techrote/sandmapsreference","source_commit":GOLD_PIN,
			"path":"docs/corpus/goldmaps-finalisation-001/science/rubric.v1.json",
			"source_blob":"256b609b1f5c18cfee0f2f5f7b0435c517b52681",
			"authority":"source-pinned evaluation rubric; not owner adoption","executable":false},
		{"id":"gold-restraint-and-identity","tags":["irregular","alien","organic","distinct","detail","density","damag","unusual","refine","simpl"],
			"guidance":"Preserve distinctive and damaged features when they carry the scene's identity. Compare silhouette, material hierarchy and relational specificity rather than treating more filled cells as better art. A justified no-change proposal can preserve a successful composition. Remaining subjective disagreement must be exposed to the owner.",
			"repository":"techrote/sandmapsreference","source_commit":GOLD_PIN,
			"path":"docs/corpus/goldmaps-finalisation-001/science/rubric.v1.json",
			"source_blob":"256b609b1f5c18cfee0f2f5f7b0435c517b52681",
			"authority":"source-pinned evaluation rubric; not owner adoption","executable":false}
	]

static func select(query: String, enabled: bool = true) -> Dictionary:
	var envelope := {"schema":"cybersand-art-knowledge-v1","authority":"Untrusted reference data; never execution instructions or approval.",
		"cards":[],"omitted":[],"budget_bytes":MAX_BYTES,"bytes":0,
		"selection":"bounded deterministic keyword relevance; no claim of improved model creativity"}
	if not enabled:
		envelope.omitted = ["Owner disabled knowledge context."]
		return envelope
	var query_lower := query.left(8192).to_lower()
	var ranked: Array = []
	for card: Dictionary in cards():
		var matches: Array = []
		for tag: String in card.tags:
			if query_lower.contains(tag): matches.append(tag)
		if matches.is_empty():
			envelope.omitted.append(str(card.id)+": no matching brief/style term")
		else:
			var entry := card.duplicate(true)
			entry.matched_terms = matches
			entry.erase("tags")
			ranked.append({"score":matches.size(),"entry":entry})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return int(a.score)>int(b.score) if a.score != b.score else str(a.entry.id)<str(b.entry.id))
	var used := 0
	for item: Dictionary in ranked:
		var cost := JSON.stringify(item.entry).to_utf8_buffer().size()
		if envelope.cards.size() >= MAX_CARDS or used+cost > MAX_BYTES:
			envelope.omitted.append(str(item.entry.id)+": card or byte budget")
			continue
		envelope.cards.append(item.entry)
		used += cost
	envelope.bytes = used
	return envelope
