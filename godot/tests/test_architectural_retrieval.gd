extends SceneTree
## Source-bound reference ranking and family-excluded transfer. No model calls.
const Retrieval = preload("res://scripts/batch_lab/architectural_retrieval.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var loaded: Dictionary = Retrieval.load_default_corpus()
	_check(loaded.ok, "frozen corpus parses and verifies")
	if not loaded.ok:
		printerr(loaded.errors)
		quit(1)
		return
	var corpus: Dictionary = loaded.corpus
	_check(corpus.cards.size() == 25, "all 25 Gold recommendations have design cards")
	_check(corpus.authority.counts.final_map_count == 70 and corpus.authority.counts.primary_policy_scan_population == 67, "source populations stay distinct")
	_check(corpus.authority.counts.owner_accepted == 0 and not corpus.authority.execution_authority, "recommendation is not acceptance or write permission")
	_check(corpus.comparative_family_links.size() == 12 and corpus.negative_interventions.size() == 5, "families and negative interventions preserved")
	for card: Dictionary in corpus.cards:
		_check(card.observed.has("material_cells") and card.interpreted.authority.begins_with("Curated"), "observed geometry and interpretation are distinct")
		_check(card.qualification.owner_acceptance == "PENDING" and card.native_module_ids.is_empty(), "design recommendation does not claim module custody")
		if int(card.source.pr) == 155:
			_check(card.qualification.native_policy == "REFUSED" and card.qualification.native_headless == "REFUSED_INVALID_SOURCE", "original 155 refusal survives qualification overlay")
		else:
			_check(card.qualification.native_headless == "QUALIFIED_HEADLESS", "per-source hosted native result recovered")
	var query := {"text": "overhead hangar structure with a clear lower route", "required_parts": ["beam_truss"], "topologies": ["suspended"], "required_connections": ["roof_anchor"]}
	var a: Dictionary = Retrieval.retrieve(query)
	var b: Dictionary = Retrieval.retrieve(query)
	_check(a.ok and JSON.stringify(a) == JSON.stringify(b), "retrieval repeats exactly")
	_check(a.results.size() == 3 and a.context_pack.references.size() > 0, "small context pack emitted")
	_check(a.context_text.length() <= 10000 and not a.limits.native_application, "context bounded and read only")
	var excluded := query.duplicate(true)
	excluded.excluded_families = ["suspended_industry"]
	for result: Dictionary in Retrieval.retrieve(excluded).results:
		_check(result.card.architectural_family != "suspended_industry", "family cannot leak through text")
	var native_query := query.duplicate(true)
	native_query.require_native_geometry = true
	var fake_module := {"id": "test-beam", "name": "Test beam", "vocabulary": "beam_truss", "extent": [32,8], "content_sha256": "1".repeat(64), "native_readback_verified": false, "material_roles": ["structure"], "connection_types": ["beam"]}
	_check(Retrieval.retrieve(native_query,[fake_module]).results.is_empty(), "serialized module metadata cannot assert native qualification")
	fake_module.native_readback_verified = true
	_check(not Retrieval.retrieve(native_query,[fake_module]).results.is_empty(), "verified host catalog supports geometry retrieval")
	native_query.available_region = [8,8]
	_check(Retrieval.retrieve(native_query,[fake_module]).results.is_empty(), "module must fit actual requested extent")
	_check(not Retrieval.retrieve({"negative_space_min":-1}).ok, "invalid negative-space fraction refuses")
	_check(not Retrieval.retrieve({"required_parts":"beam"}).ok, "malformed facets refuse")
	_check(not Retrieval.retrieve({"available_region":[0,0,0,8]}).ok, "zero region refuses")
	var tampered := corpus.duplicate(true)
	tampered.cards[0].qualification.direct_module_import = "APPROVED"
	_check(not Retrieval.retrieve({},[],tampered).ok, "retrieval-authority escalation refuses")
	var duplicate := corpus.duplicate(true)
	duplicate.cards.append(corpus.cards[0].duplicate(true))
	_check(not Retrieval.retrieve({},[],duplicate).ok, "duplicate source IDs refuse")
	_check(not Retrieval.retrieve({"limit":{}}).ok, "non-numeric limits refuse without a script error")
	_check(not Retrieval.retrieve({"require_native_geometry":"yes"}).ok, "ambiguous native-geometry request refuses")
	_check(Retrieval.retrieve({"text":"zzzzextraterrestrialquartz"}).results.is_empty(), "unmatched intent does not invent relevant context")
	_check(not Retrieval.retrieve({"text":"industrial","context_chars":1500}).ok, "undersized context budget reports explicit no-fit")
	var bounded := Retrieval.retrieve({"text":"industrial","context_chars":3000,"limit":5})
	_check(bounded.ok and bounded.context_pack.references.size()==1 and bounded.limits.omitted_reference_ids.size()==4, "budget omission is explicit")
	for mutation: Dictionary in [
		{"scope":"card", "key":"name", "value":[]},
		{"scope":"card", "key":"architectural_family", "value":null},
		{"scope":"card", "key":"ancestry_group", "value":7},
		{"scope":"card", "key":"construction_strategy", "value":[{}]},
		{"scope":"card", "key":"protected_features", "value":[{}]},
		{"scope":"observed", "key":"extent", "value":[0,10]},
		{"scope":"observed", "key":"material_cells", "value":[]},
		{"scope":"interpreted", "key":"support_relationships", "value":{}},
		{"scope":"facets", "key":"parts", "value":"beam_truss"}]:
		var malformed := corpus.duplicate(true)
		if mutation.scope=="card": malformed.cards[0][mutation.key]=mutation.value
		else: malformed.cards[0][mutation.scope][mutation.key]=mutation.value
		_check(not Retrieval.retrieve({},[],malformed).ok, "malformed caller corpus safely refuses: "+str(mutation.key))
	var no_identity := corpus.duplicate(true)
	no_identity.erase("corpus_id")
	_check(not Retrieval.retrieve({},[],no_identity).ok, "missing corpus identity refuses")
	var evaluation := _evaluate(corpus)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.substr(9),FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(evaluation,"\t")+"\n")
	print("Architectural retrieval: %d checks, %d failures; %d family-excluded cases. No model-quality or owner-preference claim." % [checks,failures,evaluation.held_out.size()])
	quit(1 if failures else 0)

func _evaluate(corpus: Dictionary) -> Dictionary:
	var path := "res://data/batch_lab/architectural_retrieval_evaluation.v1.json"
	var raw := FileAccess.get_file_as_string(path)
	var cases: Dictionary = JSON.parse_string(raw)
	var output := {"schema_version":"cybersand.architectural-retrieval-results.v1", "registration_sha256":raw.sha256_text(),
		"corpus_sha256":Retrieval.CORPUS_SHA256,"seed":cases.seed,"development":[],"held_out":[],"limitations":cases.independence_limit}
	for cohort: String in ["development","held_out"]:
		for fixture: Dictionary in cases[cohort]:
			var query: Dictionary = fixture.query.duplicate(true)
			query.excluded_families = cases.candidate_exclusion.duplicate()
			var result: Dictionary = Retrieval.retrieve(query,[],corpus)
			_check(result.ok, "registered query executes: "+str(fixture.id))
			var ids: Array = []
			var families: Array = []
			var reciprocal_rank := 0.0
			for row: Dictionary in result.results:
				ids.append(row.card.id)
				families.append(row.card.architectural_family)
				_check(not row.card.architectural_family in cases.candidate_exclusion, "excluded visual family absent from candidates")
				if row.card.id in fixture.relevant and reciprocal_rank==0.0: reciprocal_rank=1.0/float(ids.size())
			output[cohort].append({"id":fixture.id,"query":query,"ranked_ids":ids,"ranked_families":families,"relevant_ids":fixture.relevant,
				"reciprocal_rank_at_3":reciprocal_rank,"hit_at_3":reciprocal_rank>0.0,"context_chars":result.context_text.length()})
	return output
