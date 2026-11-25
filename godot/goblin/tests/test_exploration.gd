extends SceneTree

# Deliberately synthetic unit inputs. These tests qualify the exploration
# mechanism and import boundary, not CyberSand native gameplay or a found bug.
const Policy = preload("res://goblin/goblin_policy.gd")
const State = preload("res://goblin/goblin_state.gd")
const Coverage = preload("res://goblin/goblin_coverage.gd")
const Corpus = preload("res://goblin/goblin_corpus.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GOBLIN_EXPLORATION_UNIT " + label)

func _run() -> void:
	_state_tests()
	_coverage_tests()
	_corpus_tests()
	_policy_tests()
	print("GOBLIN_EXPLORATION_UNIT " + JSON.stringify({"evidence_kind":"synthetic_unit_fixtures",
		"checks":checks, "failures":failures, "native_gameplay_evidence":false,
		"personality_count":Policy.PERSONALITIES.size()}))
	quit(0 if failures.is_empty() else 1)

func _state_tests() -> void:
	_check(State.abstract({}).paused == "unknown", "missing pause remains unknown")
	_check(not State.observed({}), "missing native owner is not admitted observation")
	var first := _observation()
	var second := first.duplicate(true)
	second.native.generation = 9000
	second.native.revision = 7000
	second.native.tick = 41
	second.actor_tick = 99
	second.snapshot_tick = 99
	_check(State.signature(first) == State.signature(second), "ever-increasing counters do not inflate state novelty")
	_check(State.identity(first) != State.identity(second), "exact source identities retained separately")
	second.tool = "Line"
	_check(State.signature(first) != State.signature(second), "observed tool change alters state projection")
	_check(State.position_zone([-1, 60], [512, 512]) == "outside", "actual out-of-world position has separate zone")
	_check(State.position_zone([3, 60], [512, 512]) == "edge", "observed actor near boundary has edge zone")
	_check(State.position_zone([3, 60], []) == "unknown", "actor zone never assumes a missing World extent")
	var capture := _capture([58, 58, 2, 3])
	_check(State.valid_capture(capture, first.native), "source-matched bounded native sample is admissible")
	_check(State.sample_summary(capture, first.native).scope == "captured_region_only", "material sample never claims whole-world composition")
	var stale := capture.duplicate(true)
	stale.native_receipt.operation_id = 1234
	_check(not State.valid_capture(stale, first.native), "stale operation cannot credit material coverage")
	stale = capture.duplicate(true)
	stale.source_after.revision += 1
	_check(not State.valid_capture(stale, first.native), "interleaved capture source cannot credit composition")
	stale = capture.duplicate(true)
	stale.materials.append(2)
	_check(not State.valid_capture(stale, first.native), "capture region and array length must agree")
	var with_probe := first.duplicate(true)
	with_probe.material_probe = {"current":true, "evidence_kind":"actual_native_material_capture", "generation":1, "revision":2, "tick":40,
		"region":[40, 40, 2, 2], "counts":{"58":2, "2":1, "3":1}}
	_check(State.abstract(with_probe).material_sample.available, "fresh observed material probe contributes bounded composition")
	_check(State.signature(with_probe) != State.signature(first), "actual observed composition can guide state novelty")
	with_probe.material_probe.current = false
	_check(not State.abstract(with_probe).material_sample.available, "stale material probe cannot contribute current composition")
	with_probe.material_probe.current = true
	with_probe.material_probe.counts["58"] = 3000
	_check(not State.abstract(with_probe).material_sample.available, "probe count must match captured region")
	var configured := first.duplicate(true)
	configured.configuration = {"response":"LA"}
	configured.camera.mode = 1
	_check(State.abstract(configured).response_mode == "LA" and State.abstract(configured).camera_mode == 1, "configuration projection follows actual adapter observation fields")

func _coverage_tests() -> void:
	var coverage: RefCounted = Coverage.new()
	var row := _row("pause")
	row.admission = {}
	coverage.observe(row)
	_check(coverage.summary().unique.action == 0, "completed label without actual admission earns no action coverage")
	row = _row("pause")
	coverage.observe(row)
	_check(coverage.summary().unique.action == 1 and coverage.summary().completed_admitted_actions == 1, "observed admission earns completed vocabulary coverage")
	row = _row("brush")
	row.status = "partial"
	coverage.observe(row)
	_check(coverage.summary().unique.action == 1 and coverage.summary().partial_admitted_actions == 1, "partial action earns no completed vocabulary claim")
	row = _row("erase")
	row.status = "refused"
	row.admission = {"accepted":false}
	row.classification = "not_applicable"
	row.error = "body-covered cells protected"
	coverage.observe(row)
	_check(coverage.summary().unique.boundary_refusal == 1 and coverage.summary().unique.action == 1, "expected refusal has its own coverage")
	_check(coverage.score({"id":"erase", "args":{}}, _observation()) < coverage.score({"id":"line", "args":{}}, _observation()), "repeated refusal reduces search priority without inflating completed coverage")
	row = _row("brush")
	row.capture_before = _capture([0, 0, 2, 3])
	row.capture_after = _capture([58, 58, 2, 3])
	row.native_receipt = {"status":"completed", "kind":"paint", "changed":2}
	coverage.observe(row)
	_check(coverage.summary().unique.tool_material == 1, "completed captured edit earns actual tool/material combination")
	_check(coverage.summary().unique.material_interaction >= 2, "captured adjacency and transformations are observed separately")
	_check(coverage.summary().unique.action_transition == 0, "refusal or partial interrupts adjacent completed-action pairs")
	coverage.observe(_row("pause"))
	_check(coverage.summary().unique.action_transition == 1, "adjacent completed actions earn transition coverage")
	var prior: RefCounted = Coverage.new()
	_check(prior.load_memory(coverage.memory()), "bounded prior search hints load")
	_check(prior.summary().completed_admitted_actions == 0 and prior.summary().unique.action == 0, "imported hints never become current evidence")
	_check(coverage.memory().state_action.size() > 0 and coverage.memory().variants.size() > 0, "persistent hints retain actual state/action and parameter visits")
	var excessive := {"schema":Coverage.SCHEMA, "action":{}, "variants":{}}
	for index: int in range(Coverage.MAX_PRIOR_KEYS + 1): excessive.variants[str(index)] = 1
	_check(not prior.load_memory(excessive), "persistent hint maps enforce their independent capacity")
	_check(prior.score({"id":"pause", "args":{}}, _observation()) < prior.score({"id":"line", "args":{}}, _observation()), "prior observed action counts influence search only")
	var malicious := {"schema":Coverage.SCHEMA, "action":{"pause":-1}}
	_check(not prior.load_memory(malicious), "negative imported action count refuses")
	var blind: RefCounted = Coverage.new()
	var blind_row := _row("pause")
	blind_row.after.erase("mounted")
	blind.observe(blind_row)
	_check(blind.summary().unique.state_transition == 0, "absent mounted/native observation earns no transition")

func _corpus_tests() -> void:
	var corpus: RefCounted = Corpus.new()
	_check(not corpus.begin_episode({"fixture_id":"construction"}), "corpus requires exact source and fixture identity")
	_check(corpus.begin_episode(_context()), "exact episode context is accepted")
	var coverage: RefCounted = Coverage.new()
	var row := _row("pause")
	var novelty: Dictionary = coverage.observe(row)
	var retained: Dictionary = corpus.observe(row, novelty)
	_check(retained.get("retained", false), "independently observed novelty retains a prefix")
	_check(corpus.reuse_actions(_context()).size() == 1, "successful exact-context prefix can be explicitly reused")
	var mismatched := _context()
	mismatched.provenance_sha256 = "b".repeat(64)
	_check(corpus.reuse_actions(mismatched).is_empty(), "different runtime/source context never reuses prefix")
	var exported: Dictionary = corpus.export_data()
	var reloaded: RefCounted = Corpus.new()
	var imported: Dictionary = reloaded.import_data(JSON.parse_string(JSON.stringify(exported)), _finite_action)
	_check(imported.get("ok", false), "numeric JSON roundtrip preserves bounded corpus identity")
	_check(reloaded.summary().imported_unverified == 1, "imported observations explicitly lose verification authority")
	var old_count := int(reloaded.summary().records)
	var corrupted: Dictionary = exported.duplicate(true)
	corrupted.records[0].actions[0] = {"id":"shell", "args":{"command":"external command"}}
	corrupted.records[0].id = Corpus._entry_id(corrupted.records[0])
	_check(not reloaded.import_data(corrupted, _finite_action).get("ok", false), "import refuses non-adapter action even with matching record hash")
	_check(reloaded.summary().records == old_count, "failed import is transactional")
	corrupted = exported.duplicate(true)
	corrupted.records[0].prefix_complete = false
	_check(not reloaded.import_data(corrupted, _finite_action).get("ok", false), "partial setup is never imported as reusable")
	var unresolved: RefCounted = Corpus.new()
	unresolved.begin_episode(_context())
	row.assertions = [{"id":"injected_unit_failure", "status":"fail"}]
	unresolved.observe(row, novelty)
	_check(unresolved.summary().classifications.has("unresolved_observation"), "failed assertion is a candidate, never a confirmed production defect")
	_check(unresolved.reuse_actions(_context()).is_empty(), "failed prefix is excluded from successful discovery reuse")
	var long_run: RefCounted = Corpus.new()
	long_run.begin_episode(_context())
	for index: int in range(1024):
		var observed := _row("pause")
		observed.after.native.tick = 32 + index
		observed.semantic_sha256 = str(index).sha256_text()
		var newness := {"score":1, "before_state":str(index).sha256_text(), "after_state":str(index + 1).sha256_text()}
		long_run.observe(observed, newness)
	var long_data: Dictionary = long_run.export_data()
	_check(long_data.records.size() <= Corpus.MAX_RECORDS, "1024 decisions retain a bounded number of observations")
	_check(JSON.stringify(long_data).to_utf8_buffer().size() <= Corpus.MAX_BYTES, "bounded corpus remains inside export byte budget")
	_check(long_data.records.any(func(item: Dictionary) -> bool: return item.step > 128 and not item.prefix_complete and item.actions.is_empty() and not item.reusable), "long-horizon observation never claims a physical or truncated setup checkpoint")
	_check(reloaded.import_data(long_data, _finite_action).get("ok", false), "long-horizon bounded observation corpus remains portable")
	corpus.clear()
	_check(corpus.summary().records == 0 and corpus.reuse_actions(_context()).is_empty(), "explicit clear retires memory and prefixes")

func _policy_tests() -> void:
	var menu := _menu()
	var signatures: Dictionary = {}
	var action_signatures: Dictionary = {}
	for name: String in Policy.PERSONALITIES:
		var first: RefCounted = Policy.new()
		var second: RefCounted = Policy.new()
		_check(first.configure(name, 1701) and second.configure(name, 1701), name + " configures")
		var emitted: Array[Dictionary] = []
		var same := true
		var offered := true
		for index: int in range(128):
			var observation := _observation()
			observation.native.tick = 32 + index
			var a: Dictionary = first.next_action(observation, menu)
			var b: Dictionary = second.next_action(observation, menu)
			same = same and a == b
			offered = offered and menu.any(func(item: Dictionary) -> bool: return item.id == a.id)
			emitted.append(a)
			var row := _row(str(a.id))
			row.action = a
			first.observe_result(row)
			second.observe_result(row.duplicate(true))
		_check(same, name + " is deterministic for matching supplied observation history")
		_check(offered, name + " never invents a nominally absent action family")
		_check(first.summary().recent_observations.size() <= Policy.HISTORY_LIMIT, name + " keeps bounded recent history")
		_check(first.summary().coverage.completed_admitted_actions == 128, name + " accounts for actual admitted unit records")
		signatures[JSON.stringify(emitted).sha256_text()] = true
		var action_only: Array = []
		for action: Dictionary in emitted: action_only.append({"id":action.id, "args":action.args})
		action_signatures[JSON.stringify(action_only).sha256_text()] = true
	_check(Policy.PERSONALITIES.size() >= 12 and signatures.size() == Policy.PERSONALITIES.size(), "personality outputs are independently distinct under matched synthetic inputs")
	_check(action_signatures.size() == Policy.PERSONALITIES.size(), "all personalities differ in actual proposed actions, independent of their labels")
	var chooser: RefCounted = Policy.new()
	chooser.configure("COVERAGE_HUNTER", 13)
	chooser.next_action(_observation(), menu)
	_check(chooser.summary().coverage.unique.action == 0, "policy proposal cannot manufacture native coverage")
	var corpus: RefCounted = Corpus.new()
	corpus.begin_episode(_context())
	var unit_coverage: RefCounted = Coverage.new()
	var row := _row("pause")
	corpus.observe(row, unit_coverage.observe(row))
	_check(chooser.bind_memory(corpus, _context(), true) == false, "memory binding refuses after first proposal")
	chooser.configure("OBSESSIVE_REPRODUCER", 13)
	_check(chooser.bind_memory(corpus, _context(), true), "explicit memory reuse can be bound before episode")
	_check(chooser.next_action(_observation(), menu).id == "pause", "matching retained authored prefix is proposed first")
	_check(chooser.summary().coverage.unique.action == 0, "reused prefix is not credited until actual observation")

func _observation() -> Dictionary:
	return {"mounted":true, "fixture_id":"construction", "scene_identity":"fixture", "world_size":[512, 512],
		"paused":true, "material":58, "tool":"Brush", "brush_radius":2, "selection":[0, 0, 0, 0],
		"clipboard_size":[0, 0], "undo_available":true, "redo_available":true,
		"actors":[], "actor_ids":[], "controllable_actor_ids":[], "next_actor_id":1,
		"selected_actor":0, "pilot_actor":0, "saved_authored_digest":"",
		"camera":{"origin":[0, 0], "size":[480, 270]}, "details_open":false,
		"native":{"generation":1, "revision":2, "tick":40, "paused":true, "busy":false, "failed":false}}

func _row(id: String) -> Dictionary:
	return {"action":{"id":id, "args":{}}, "before":_observation(), "after":_observation(),
		"status":"completed", "admission":{"accepted":true}, "classification":"game_observation",
		"assertions":[{"id":"synthetic_unit_invariant", "status":"pass"}],
		"observation_sha256":"c".repeat(64), "semantic_sha256":"d".repeat(64)}

func _capture(materials: Array) -> Dictionary:
	var source := {"generation":1, "revision":2, "tick":40, "paused":true, "failed":false}
	return {"source_matches":true, "source_before":source.duplicate(), "source_after":source.duplicate(),
		"admission":{"status":"queued", "operation_id":7}, "region":[40, 40, 2, 2], "materials":materials,
		"native_receipt":{"backend":"CyberNativeCellWorld", "kind":"capture", "status":"completed",
			"operation_id":7, "generation":1, "observed_generation":1, "revision":2, "tick":40}}

func _context() -> Dictionary:
	return {"fixture_id":"construction", "fixture_version":1, "fixture_sha256":"a".repeat(64),
		"provenance_sha256":"e".repeat(64), "seed":13, "personality":"CONTROL"}

func _finite_action(action: Dictionary) -> Dictionary:
	# Deliberately small synthetic adapter authority for import-negative controls.
	return {"ok":action.get("id") in ["pause", "brush"] and action.get("args") is Dictionary}

func _menu() -> Array:
	return [{"id":"pause", "args":{}}, {"id":"play", "args":{"ticks":4}}, {"id":"wait_ticks", "args":{"ticks":4}},
		{"id":"single_step", "args":{}}, {"id":"select_material", "args":{"material":2}},
		{"id":"select_material", "args":{"material":3}}, {"id":"select_material", "args":{"material":58}},
		{"id":"brush", "args":{"x":80, "y":80, "radius":2}}, {"id":"erase", "args":{"x":80, "y":80, "radius":2}},
		{"id":"rectangle", "args":{"x0":48, "y0":48, "x1":63, "y1":63}},
		{"id":"outline", "args":{"x0":48, "y0":48, "x1":63, "y1":63}},
		{"id":"line", "args":{"x0":48, "y0":48, "x1":63, "y1":55}},
		{"id":"select_region", "args":{"x0":48, "y0":48, "x1":63, "y1":63}},
		{"id":"fill", "args":{"x":380, "y":44}}, {"id":"copy", "args":{}}, {"id":"paste", "args":{"x":200, "y":80}},
		{"id":"undo", "args":{}}, {"id":"redo", "args":{}},
		{"id":"camera", "args":{"x":0, "y":0, "width":480, "height":270}},
		{"id":"actor_place", "args":{"model":"kestrel", "x":224, "y":128}},
		{"id":"panel", "args":{"panel":"details", "open":true}},
		{"id":"save_layout", "args":{}}, {"id":"reopen_layout", "args":{}}, {"id":"reset_fixture", "args":{}}]
