extends RefCounted
## Bounded, offline design retrieval. Returns reference knowledge, never World permissions.

const CORPUS_PATH := "res://data/batch_lab/architectural_design_cards.v1.json"
const CORPUS_SHA256 := "9153480ea622d5dc6a78543269840af64b3adbef43074af8cf78cfe685d0b057"
const SCHEMA := "cybersand.architectural-design-cards.v1"
const MAX_CARDS := 200
const MAX_MODULES := 1024
const MAX_CONTEXT_CHARS := 12000
const FACET_WEIGHTS := {"intents": 5, "topologies": 8, "architectural_families": 6, "required_parts": 8,
	"required_connections": 7, "material_roles": 2, "character": 4}
const STOP_WORDS := ["a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "in", "into", "is", "it", "of", "on", "or", "the", "to", "with"]

static func load_default_corpus() -> Dictionary:
	var file := FileAccess.open(CORPUS_PATH, FileAccess.READ)
	if file == null: return _failure("Design-card corpus could not be opened.")
	if file.get_length() > 2097152: return _failure("Design-card corpus exceeds 2 MiB.")
	var raw := file.get_as_text()
	if raw.sha256_text() != CORPUS_SHA256: return _failure("Design-card corpus identity mismatch.")
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary: return _failure("Design-card corpus is not an object.")
	var checked := validate_corpus(parsed)
	if not checked.ok: return checked
	return {"ok": true, "corpus": parsed, "corpus_sha256": CORPUS_SHA256, "errors": []}

static func validate_corpus(corpus: Dictionary) -> Dictionary:
	if JSON.stringify(corpus).length() > 2097152: return _failure("Caller-supplied design corpus exceeds 2 MiB.")
	if corpus.get("schema_version") != SCHEMA: return _failure("Unsupported design-card schema.")
	var authority: Variant = corpus.get("authority")
	var cards: Variant = corpus.get("cards")
	if not _text(corpus.get("corpus_id"), 128): return _failure("Corpus identity missing or oversized.")
	if not authority is Dictionary or authority.get("kind") != "reference_knowledge_only" or authority.get("execution_authority", true) != false:
		return _failure("Design knowledge must retain its reference-only authority envelope.")
	if not cards is Array or cards.is_empty() or cards.size() > MAX_CARDS: return _failure("Invalid bounded card collection.")
	var seen := {}
	for card: Variant in cards:
		if not card is Dictionary: return _failure("A design card is not an object.")
		for field: String in ["id", "name", "architectural_family", "ancestry_group", "source", "observed", "interpreted", "facets", "qualification", "construction_strategy", "protected_features"]:
			if not card.has(field): return _failure("Design card omits " + field + ".")
		if not _text(card.id, 128) or seen.has(card.id): return _failure("Missing or duplicate design-card identity.")
		seen[card.id] = true
		for key: String in ["name", "architectural_family", "ancestry_group"]:
			if not _text(card[key], 256): return _failure("Invalid card " + key + ".")
		for field: String in ["source", "observed", "interpreted", "facets", "qualification"]:
			if not card[field] is Dictionary: return _failure("Invalid card " + field + " object.")
		if not _hex(card.source.get("commit"), 40) or not _hex(card.source.get("setup_sha256"), 64):
			return _failure("Card source is not pinned to exact geometry custody.")
		if not _text_array(card.construction_strategy, 16, 2048) or not card.protected_features is Array or card.protected_features.size()>64: return _failure("Invalid strategies or protected-feature states.")
		for key: String in ["macro_composition", "support_relationships", "traversal_and_hierarchy", "negative_space_and_protection", "review_url"]:
			if not _text(card.interpreted.get(key), 8192): return _failure("Missing interpreted " + key + ".")
		for key: String in ["extent", "material_cells", "empty_fraction"]:
			if not card.observed.has(key): return _failure("Missing observed " + key + ".")
		if not card.observed.extent is Array or card.observed.extent.size()!=2 or not card.observed.material_cells is Dictionary or card.observed.material_cells.size()>256: return _failure("Invalid observed geometry summary.")
		for number: Variant in card.observed.extent:
			if not _whole(number, 1, 2048): return _failure("Invalid observed geometry extent.")
		for material: Variant in card.observed.material_cells:
			if not material is String or not material.is_valid_int() or int(material)<0 or int(material)>65535 or not _whole(card.observed.material_cells[material], 0, 4194304): return _failure("Invalid observed material count.")
		for key: String in ["topologies", "parts", "character", "connection_intents", "suggested_material_roles"]:
			if not _text_array(card.facets.get(key),64,128): return _failure("Invalid interpreted facet " + key + ".")
		if not card.facets.get("palette_material_ids") is Array or card.facets.palette_material_ids.size()>256: return _failure("Invalid observed palette.")
		for material: Variant in card.facets.palette_material_ids:
			if not _whole(material,1,65535): return _failure("Invalid observed palette material.")
		if not (card.observed.empty_fraction is float or card.observed.empty_fraction is int) or not is_finite(float(card.observed.empty_fraction)) or float(card.observed.empty_fraction)<0.0 or float(card.observed.empty_fraction)>1.0: return _failure("Invalid observed empty fraction.")
		for feature: Variant in card.protected_features:
			if not feature is Dictionary or not _text(feature.get("state_id"),256): return _failure("Invalid protected-feature identity.")
		if card.qualification.get("direct_module_import") != "NOT_ADMITTED_BY_RETRIEVAL":
			return _failure("A design card cannot authorize native geometry import.")
	return {"ok": true, "errors": []}

static func retrieve(query: Dictionary, module_catalog: Array = [], corpus: Dictionary = {}) -> Dictionary:
	if JSON.stringify(query).length() > 16384: return _failure("Retrieval query exceeds 16 KiB.")
	if module_catalog.size() > MAX_MODULES or JSON.stringify(module_catalog).length() > 2097152: return _failure("Module catalog exceeds the bounded retrieval limit.")
	var frozen_file_sha256: Variant = null
	if corpus.is_empty():
		var loaded := load_default_corpus()
		if not loaded.ok: return loaded
		corpus = loaded.corpus
		frozen_file_sha256 = loaded.corpus_sha256
	var checked := validate_corpus(corpus)
	if not checked.ok: return checked
	var query_check := _validate_query(query)
	if not query_check.ok: return query_check
	var limit := clampi(int(query.get("limit", 3)), 1, 5)
	var context_budget := clampi(int(query.get("context_chars", 10000)), 1500, MAX_CONTEXT_CHARS)
	var terms := _tokens(str(query.get("text", "")))
	var results: Array = []
	var excluded_families := _strings(query.get("excluded_families", []))
	var excluded_groups := _strings(query.get("excluded_ancestry_groups", []))
	var seen_sources := {}
	for card: Dictionary in corpus.cards:
		if str(card.architectural_family) in excluded_families or str(card.ancestry_group) in excluded_groups: continue
		var source_key := str(card.source.commit) + ":" + str(card.source.setup_sha256)
		if seen_sources.has(source_key): continue
		seen_sources[source_key] = true
		if query.has("negative_space_min") and float(card.observed.get("empty_fraction", -1.0)) < float(query.negative_space_min): continue
		var scored := _score(card, query, terms)
		var modules := _compatible_modules(card, query, module_catalog)
		if bool(query.get("require_native_geometry", false)) and modules.qualified.is_empty(): continue
		if scored.score <= 0 and not terms.is_empty(): continue
		results.append({"card": card.duplicate(true), "score": scored.score, "reasons": scored.reasons,
			"compatible_modules": modules.qualified, "metadata_only_modules": modules.metadata_only,
			"module_scope": "Current-session native-verified module metadata; final transformed footprint and receipts remain the stage host's responsibility."})
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.card.id) < str(b.card.id) if is_equal_approx(float(a.score), float(b.score)) else float(a.score) > float(b.score))
	var selected: Array = []
	var selected_groups := {}
	for result: Dictionary in results:
		if selected.size() >= limit: break
		var group := str(result.card.ancestry_group)
		if selected_groups.has(group): continue
		selected_groups[group] = true
		selected.append(result)
	var context := _context(corpus, selected, context_budget)
	if not selected.is_empty() and context.pack.references.is_empty(): return _failure("No selected reference fits the requested context budget; increase context_chars.")
	return {"ok": true, "query": query.duplicate(true), "corpus_id": corpus.corpus_id,
		"corpus_sha256": JSON.stringify(corpus).sha256_text(), "corpus_identity_format": "Godot canonical JSON",
		"frozen_file_sha256": frozen_file_sha256,
		"results": selected, "context_pack": context.pack, "context_text": context.text,
		"limits": {"maximum_cards": limit, "context_chars": context_budget, "returned_context_chars": str(context.text).length(),
			"candidate_count": results.size(), "returned_cards": context.pack.references.size(), "omitted_reference_ids": context.pack.omitted_reference_ids, "native_application": false}, "errors": []}

static func _score(card: Dictionary, query: Dictionary, terms: Array) -> Dictionary:
	var score := 0.0
	var reasons: Array = []
	var facets: Dictionary = card.facets
	var fields := {"intents": _strings(facets.get("parts", [])) + _strings(facets.get("connection_intents", [])),
		"topologies": facets.get("topologies", []), "architectural_families": [card.architectural_family],
		"required_parts": facets.get("parts", []), "required_connections": facets.get("connection_intents", []),
		"material_roles": facets.get("suggested_material_roles", []), "character": facets.get("character", [])}
	for key: String in FACET_WEIGHTS:
		var requested := _strings(query.get(key, []))
		var available := _strings(fields[key])
		var matched: Array = []
		for term: String in requested:
			if term in available: matched.append(term)
		if not matched.is_empty():
			var value := float(FACET_WEIGHTS[key]) * float(matched.size()) / float(requested.size())
			score += value
			reasons.append({"criterion": key, "matched": matched, "requested": requested.size(), "score": value, "authority": "curated_interpretation"})
	var searchable := _tokens(str(card.name) + " " + JSON.stringify(card.interpreted) + " " + JSON.stringify(card.facets))
	var lexical: Array = []
	for term: String in terms:
		if term in searchable: lexical.append(term)
	if not lexical.is_empty():
		var value := 3.0 * float(lexical.size()) / float(maxi(1, terms.size()))
		score += value
		reasons.append({"criterion": "text", "matched": lexical, "score": value, "authority": "term_overlap_not_model_inference"})
	if query.has("scale") and str(query.scale) == str(facets.get("scale")):
		score += 1.0
		reasons.append({"criterion": "scale", "matched": [query.scale], "score": 1.0, "authority": "curated_interpretation"})
	var palette := _strings(query.get("palette", []))
	var material_ids := _strings(facets.get("palette_material_ids", []))
	var palette_hits: Array = []
	for entry: String in palette:
		if entry in material_ids: palette_hits.append(entry)
	if not palette_hits.is_empty():
		var value := 3.0 * float(palette_hits.size()) / float(palette.size())
		score += value
		reasons.append({"criterion": "palette_material_ids", "matched": palette_hits, "score": value, "authority": "observed_material_ids"})
	return {"score": score, "reasons": reasons}

static func _compatible_modules(card: Dictionary, query: Dictionary, module_catalog: Array) -> Dictionary:
	var qualified: Array = []
	var metadata_only: Array = []
	var needed := _strings(query.get("required_parts", card.facets.get("parts", [])))
	var region: Array = query.get("available_region", [])
	for module: Variant in module_catalog:
		if not module is Dictionary or not module.has("id"): continue
		var part := str(module.get("vocabulary", module.get("part_type", "")))
		if not part in needed: continue
		var extent: Variant = module.get("extent", [])
		if not extent is Array or extent.size() != 2: continue
		if int(extent[0]) <= 0 or int(extent[1]) <= 0: continue
		if region.size() == 4 and (int(extent[0]) > int(region[2]) or int(extent[1]) > int(region[3])): continue
		if region.size() == 2 and (int(extent[0]) > int(region[0]) or int(extent[1]) > int(region[1])): continue
		var requested_roles := _strings(query.get("material_roles", []))
		var roles := _strings(module.get("material_roles", []))
		if not _contains_all(roles, requested_roles): continue
		var connection_types := _strings(module.get("connection_types", []))
		var needed_connections := _strings(query.get("module_connection_types", []))
		if not _contains_all(connection_types, needed_connections): continue
		var candidate := {"id": module.id, "name": module.get("name", module.id), "part_type": part,
			"extent": extent.duplicate(), "content_sha256": module.get("content_sha256", ""),
			"connection_types": connection_types, "native_readback_verified": bool(module.get("native_readback_verified", false)),
			"relationship": "Declared structural role is applicable; not derived source geometry or a proven placement."}
		if candidate.native_readback_verified and str(candidate.content_sha256).length() == 64:
			qualified.append(candidate)
		else:
			metadata_only.append(candidate)
	qualified.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.id)<str(b.id))
	metadata_only.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.id)<str(b.id))
	return {"qualified": qualified.slice(0, 12), "metadata_only": metadata_only.slice(0, 12)}

static func _context(corpus: Dictionary, results: Array, budget: int) -> Dictionary:
	var pack := {"schema_version": "cybersand.architectural-context.v1", "corpus_id": corpus.corpus_id,
		"corpus_sha256": JSON.stringify(corpus).sha256_text(), "authority": "REFERENCE_KNOWLEDGE_ONLY_NO_WRITE_PERMISSION", "evidence_commit": corpus.authority.get("evidence_commit"),
		"claim_limits": ["Source review, native admission and owner acceptance are separate.",
			"Only the host may calculate footprints, material costs, protection and native execution.",
			"Suggested roles and construction strategies are interpretations; unknown geometry is not inferred."], "references": [], "omitted_reference_ids": []}
	for result: Dictionary in results:
		var card: Dictionary = result.card
		var ref := {"id": card.id, "name": card.name, "source": card.source.duplicate(true),
			"observed": {"extent": card.observed.extent, "empty_fraction": card.observed.empty_fraction,
				"material_cells": card.observed.material_cells},
			"interpreted": {"macro": card.interpreted.macro_composition, "supports": card.interpreted.support_relationships,
				"traversal": card.interpreted.traversal_and_hierarchy, "preserve": card.interpreted.negative_space_and_protection,
				"review_url": card.interpreted.review_url}, "strategies": card.construction_strategy,
			"qualification": card.qualification, "compatible_modules": result.compatible_modules,
			"protected_feature_state_ids": card.protected_features.map(func(f: Dictionary) -> String: return str(f.state_id))}
		pack.references.append(ref)
		if JSON.stringify(pack).length() > budget:
			pack.references.pop_back()
			break
	for index: int in range(pack.references.size(), results.size()): pack.omitted_reference_ids.append(results[index].card.id)
	while JSON.stringify(pack).length()>budget and not pack.references.is_empty():
		var removed: Dictionary = pack.references.pop_back()
		pack.omitted_reference_ids.push_front(removed.id)
	return {"pack": pack, "text": JSON.stringify(pack)}

static func _validate_query(query: Dictionary) -> Dictionary:
	for key: String in ["limit", "context_chars"]:
		if query.has(key) and (not (query[key] is int or query[key] is float) or not is_finite(float(query[key])) or float(query[key]) != floor(float(query[key]))): return _failure("Query limit must be a finite integer: " + key)
	if query.has("require_native_geometry") and not query.require_native_geometry is bool: return _failure("Native geometry requirement must be boolean.")
	for key: String in ["intents", "topologies", "architectural_families", "required_parts", "required_connections", "module_connection_types", "material_roles", "palette", "character", "excluded_families", "excluded_ancestry_groups"]:
		if query.has(key) and (not query[key] is Array or query[key].size() > 64): return _failure("Invalid bounded query array: " + key)
	if query.has("negative_space_min"):
		if not (query.negative_space_min is float or query.negative_space_min is int) or not is_finite(float(query.negative_space_min)) or float(query.negative_space_min) < 0.0 or float(query.negative_space_min) > 1.0:
			return _failure("Negative-space threshold must be a finite fraction from zero to one.")
	if query.has("available_region"):
		var region: Variant = query.available_region
		if not region is Array or not region.size() in [2,4]: return _failure("Available region must be an extent or rectangle.")
		for number: Variant in region:
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floor(float(number)): return _failure("Available-region values must be finite integers.")
		if int(region[-1])<=0 or int(region[-2])<=0: return _failure("Available-region extent must be positive.")
	return {"ok": true}

static func _strings(value: Variant) -> Array:
	var output: Array = []
	if value is Array:
		for item: Variant in value:
			var normalized := str(item).strip_edges().to_lower()
			if not normalized.is_empty() and not normalized in output: output.append(normalized)
	return output

static func _tokens(value: String) -> Array:
	var normalized := ""
	for i: int in range(value.length()):
		var c := value.unicode_at(i)
		normalized += value[i].to_lower() if (c>=65 and c<=90) or (c>=97 and c<=122) or (c>=48 and c<=57) else " "
	var output: Array = []
	for word: String in normalized.split(" ",false):
		if word.length()<2 or word in STOP_WORDS or word in output: continue
		output.append(word)
		if output.size()>=96: break
	return output

static func _contains_all(values: Array, required: Array) -> bool:
	for value: Variant in required:
		if not value in values: return false
	return true

static func _text(value: Variant, maximum: int) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length()<=maximum

static func _text_array(value: Variant, maximum: int, length: int) -> bool:
	if not value is Array or value.size()>maximum: return false
	for item: Variant in value:
		if not _text(item,length): return false
	return true

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=minimum and float(value)<=maximum

static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length()!=length: return false
	for i: int in range(value.length()):
		if not value[i] in "0123456789abcdef": return false
	return true

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "errors": [message], "results": [], "context_pack": {}, "context_text": ""}
