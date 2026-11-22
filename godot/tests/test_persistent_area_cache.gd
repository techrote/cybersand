extends SceneTree
## Ledger/eviction adversarial tests use real validated CYPS and authoring
## capsules with synthetic opaque receipts. Actual World residency belongs to
## the independent native-owner and graphical Workbench qualification suites.

const Cache = preload("res://scripts/persistent_area_cache.gd")
const Store = preload("res://scripts/persistent_area_store.gd")
const Clock = preload("res://scripts/persistent_area_clock.gd")
const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const MaterialBaseline = preload("res://scripts/workbench_material_baseline.gd")
var checks := 0
var failures := 0
var fixture: Dictionary
var capture: Dictionary
var authoring: Dictionary
var manifest: Dictionary


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		push_error("RAMCACHE ledger: " + label)
	return value


func receipt(id: String, handle: int, tick: int = 0, mutation: int = 0, generation: int = 1) -> Dictionary:
	return {"schema":1,"handle":handle,"identity":{"session_id":manifest.session_id,"area_id":id,
		"incarnation":manifest.areas[id].incarnation,"runtime_sha256":"a".repeat(64),
		"authored_source_sha256":capture.authored_source_sha256},"resident_generation":generation,
		"mutation_generation":mutation,"completed_tick":tick,"physics_profile_sha256":capture.physics_profile_sha256,
		"native_bytes":8*1024*1024,"active":false}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	fixture = Fixture.create()
	if not check(not fixture.has("error"),"real supported native fixture constructs"): finish(); return
	capture = fixture.bridge.capture_workbench_continuation(fixture.world)
	var setup := Setup.fresh(fixture.bridge.default_liquid_policy(),Vector2i(512,512))
	setup.edits = [[65,60,0,0]]
	authoring = {"setup":setup,"definition":fixture.checked.definition.duplicate(true),"generated_packet":{},"material_baseline":{},
		"camera":{"origin":Vector2i(12,24),"view_size":Vector2i(256,256),"zoom":1.5,"mode":"overview"}}
	manifest = {"version":1,"profile_id":"ledger-test","session_id":"b".repeat(32),
		"compatibility":"test:"+"a".repeat(64),"revision":1,"operation_nonce":"c".repeat(32),"active_area":"a",
		"clock":Clock.fresh(),"areas":{}}
	for id: String in Clock.AREA_IDS:
		manifest.areas[id] = {"area_id":id,"incarnation":id.repeat(32),"generation":1,"mutation_generation":0,"completed_tick":0,
			"native_sha256":capture.sha256,"authoring_sha256":Store.digest(var_to_bytes(authoring)),
			"authored_source_sha256":capture.authored_source_sha256,"physics_profile_sha256":capture.physics_profile_sha256,
			"policy_sha256":capture.policy_sha256}
	var cache := Cache.new()
	check(cache.open(manifest,40*1024*1024).ok,"cache binds admitted session and runtime")
	check(cache.status().cold_count == 3 and cache.status().hot_count == 0,"durable bytes do not become hot by classification")
	for id: String in Clock.AREA_IDS:
		var op := str(Clock.AREA_IDS.find(id)+1).repeat(32)
		check(cache.reserve(op,id,9*1024*1024).ok,"preparation resource reserved before admission")
		check(cache.admit_hot(id,receipt(id,Clock.AREA_IDS.find(id)+1),authoring,0,op).ok,"native opaque receipt admitted with matching authoring")
	check(cache.status().hot_count == 3 and cache.status().warm_count == 0,"three true-handle ledger entries remain distinct from warm bytes")
	check(cache.set_active("a").ok,"one active owner is pinned")
	var changed: Dictionary = cache.entry("b")
	changed.authoring.setup.edits.clear()
	check(cache.entry("b").authoring.setup.edits.size() == 1,"returned host envelope cannot mutate retained authoring")
	var refresh := receipt("a",1,0,0,2)
	check(cache.refresh_hot("a",refresh,0).ok and not cache.entry("a").dirty,"same native handle refresh avoids source reconstruction")
	for field: String in ["session_id","area_id","incarnation","runtime_sha256","authored_source_sha256"]:
		var forged := refresh.duplicate(true)
		forged.identity[field] = "wrong"
		check(not cache.refresh_hot("a",forged,0).ok,"hot identity mismatch refuses: " + field)
	var forged := refresh.duplicate(true)
	forged.handle = 90
	check(not cache.refresh_hot("a",forged,0).ok,"different native handle cannot replace retained authority")
	forged = refresh.duplicate(true)
	forged.resident_generation = 1
	check(not cache.refresh_hot("a",forged,0).ok,"stale resident generation refuses")
	var op := "4".repeat(32)
	check(cache.pin("b",op).ok,"in-flight entry pinned")
	cache.configure(true,9*1024*1024)
	var candidates: Array = cache.eviction_candidates()
	check(candidates.size() == 1 and candidates[0].area_id == "c","active and in-flight entries excluded from LRU")
	check(not cache.complete_eviction("a",2,1,false).ok and not cache.complete_eviction("b",1,2,false).ok,
		"cannot discard active or pinned World")
	cache.unpin("b",op)
	check(cache.mark_dirty("b",0,1).ok and cache.entry("b").dirty,"material edit without completed tick is explicitly dirty")
	check(not cache.complete_eviction("b",1,2,false).ok,"dirty only copy cannot be evicted")
	check(cache.complete_eviction("c",1,3,false).ok and cache.entry("c").residency == "COLD","durable inactive native release acknowledges COLD")
	check(not cache.reserve("5".repeat(32),"c",8*1024*1024).ok,"budget lower than pinned authority refuses extra allocations")
	cache.configure(true,40*1024*1024)
	check(cache.retain_warm("b",capture,authoring,1,manifest.areas.b.incarnation).ok,"dirty current complete capture may remain warm")
	check(cache.complete_eviction("b",1,2,true).ok and cache.entry("b").residency == "WARM" and cache.entry("b").dirty,
		"hot-to-warm demotion preserves the only dirty native continuation")
	check(not cache.complete_eviction("b",1,0,false).ok,"dirty warm state cannot be discarded")
	var acknowledged: Dictionary = manifest.duplicate(true)
	acknowledged.revision = 2
	acknowledged.areas.b.mutation_generation = 1
	acknowledged.areas.b.generation = 2
	check(cache.durable_ack(acknowledged).ok and not cache.entry("b").dirty,"ACK advances durability without changing residency")
	check(cache.complete_eviction("b",1,0,false).ok and cache.entry("b").residency == "COLD","warm bytes release only after durable ACK")
	check(not cache.durable_ack(manifest).ok,"older durable ACK refuses")
	check(cache.durable_ack(acknowledged).ok,"duplicate identical durable ACK is idempotent")
	var wrong := acknowledged.duplicate(true)
	wrong.areas.a.incarnation = "f".repeat(32)
	check(not cache.durable_ack(wrong).ok,"ACK cannot attach to another resident incarnation")
	check(cache.mark_dirty("a",5,2).ok,"new native ticks remain resident dirty")
	check(cache.durable_ack(acknowledged).ok and cache.entry("a").completed_tick == 5 and cache.entry("a").dirty,
		"older in-flight save ACK never rewinds newer resident ticks/edits")
	check(cache.configure(false,40*1024*1024).ok and not cache.reserve("6".repeat(32),"b",1).ok,
		"cache off prevents speculative admission while preserving active dirty authority")
	check(not cache.configure(true,Cache.MAX_BUDGET_BYTES+1).ok,"unbounded configuration refuses")
	cache.configure(true,40*1024*1024)
	for index: int in 100:
		var id := "b" if index%2 == 0 else "c"
		var token := index+100
		check(cache.admit_hot(id,receipt(id,token,0,1 if id == "b" else 0,index+2),authoring,1 if id == "b" else 0).ok,
			"churn admission retains fenced identity")
		check(cache.complete_eviction(id,index+2,token,false).ok,"churn releases exactly acknowledged durable handle")
		check(cache.status().hot_count == 1 and cache.status().pending_reservations == 0,"churn cannot accumulate stale native handles/reservations")
	check(cache.admit_hot("b",receipt("b",999,0,1,1),authoring,1).ok,
		"fresh restored handle may start generation one after an older handle reached a higher generation")
	check(cache.complete_eviction("b",1,999,false).ok,"fresh handle releases by its own generation")
	check(not cache.admit_hot("b",receipt("b",198,0,1,100),authoring,1).ok,
		"retired handle replay cannot use its old higher generation to regain authority")
	var publication_id := "7".repeat(32)
	cache.configure(true,1)
	check(cache.reserve_publication(publication_id,Cache.MAX_PUBLICATION_HEADROOM_BYTES).ok,
		"essential Save can reserve separately bounded working space when retained dirty authority exceeds a lowered budget")
	check(cache.status().essential_publication_reserved_bytes==Cache.MAX_PUBLICATION_HEADROOM_BYTES \
		and cache.status().total_accounted_and_reserved_bytes>cache.status().used_bytes,
		"temporary serialization reserve is visible separately from retained cache usage")
	check(not cache.reserve("8".repeat(32),"c",1).ok,"speculation yields while essential serialization owns headroom")
	check(not cache.reserve_publication("9".repeat(32),1).ok,"a second publication cannot allocate another full buffer batch")
	check(not cache.resize_publication(publication_id,Cache.MAX_PUBLICATION_HEADROOM_BYTES+1).ok,
		"captured batch cannot grow its preallocated working bound")
	check(cache.resize_publication(publication_id,1024).ok,"actual small immutable batch shrinks reserved headroom")
	check(not cache.release_publication("9".repeat(32)).ok,"stale ACK cannot release current publication headroom")
	check(cache.release_publication(publication_id).ok and cache.status().essential_publication_reserved_bytes==0,
		"matching publication completion retires its temporary reservation")
	var bounded := Cache.new()
	check(bounded.open(manifest,1).ok and bounded.configure(false,1).ok,"one-byte disabled cache establishes the budget attack boundary")
	check(not bounded.admit_hot("b",receipt("b",2000),authoring,0,"",true).ok,
		"an inactive HOT receipt cannot bypass a disabled cache through the active-owner flag")
	check(not bounded.retain_warm("c",capture,authoring,0,manifest.areas.c.incarnation,"",true).ok,
		"WARM continuation cannot bypass the retained budget through the active-owner flag")
	var wrong_active := receipt("b",2001)
	wrong_active.active = true
	check(not bounded.admit_hot("b",wrong_active,authoring,0,"",true).ok,
		"an active-marked receipt for another area cannot claim the admitted active owner exception")
	var admitted_active := receipt("a",2002)
	admitted_active.active = true
	check(bounded.admit_hot("a",admitted_active,authoring,0,"",true).ok,
		"the admitted active native World remains available after retention is disabled or reduced")
	check(bounded.set_active("a").ok and bounded.status().hot_count==1,
		"the active-only exception retains exactly one native authority")
	var staged := Cache.new()
	check(staged.open(manifest,20*1024*1024).ok,"prepared-target reservation fixture opens")
	var staging_id := "d".repeat(32)
	check(staged.reserve(staging_id,"b",19*1024*1024,2).ok,"candidate reserves warm and native staging memory before construction")
	var total_reserved := int(staged.status().used_bytes)+int(staged.status().reserved_bytes)
	check(staged.retain_warm("b",capture,authoring,0,manifest.areas.b.incarnation,staging_id,false,true).ok,
		"strict prepared checkpoint uses its matching native preparation reservation")
	check(staged.status().pending_reservations==1 and int(staged.status().used_bytes)+int(staged.status().reserved_bytes)==total_reserved,
		"WARM admission transfers reserved bytes without releasing remaining native staging headroom")
	check(not staged.complete_eviction("b",0,0,false).ok,"preparation reservation pins a retained WARM checkpoint")
	check(staged.admit_hot("b",receipt("b",2003),authoring,0,staging_id).ok and staged.status().pending_reservations==0,
		"final native admission consumes only the matching remaining preparation reservation")
	check(not staged.retain_warm("c",capture,authoring,0,manifest.areas.c.incarnation,"",false,true).ok,
		"preserving an absent candidate reservation refuses")
	exercise_authoring_refresh()
	exercise_admitted_authoring()
	finish()


func exercise_authoring_refresh() -> void:
	var cache := Cache.new()
	check(cache.open(manifest,40*1024*1024).ok,"authoring refresh admission fixture opens")
	var active := receipt("a",3001)
	active.active = true
	var inactive := receipt("b",3002)
	check(cache.admit_hot("a",active,authoring,0).ok and cache.set_active("a").ok \
		and cache.admit_hot("b",inactive,authoring,0).ok,"two admitted identities establish active and inactive authority")
	var used := int(cache.status().used_bytes)
	cache.configure(true,used)
	var original := cache.entry("b")
	var edited := authoring.duplicate(true)
	edited.camera["note"] = "bounded authored change"
	var refreshed := inactive.duplicate(true)
	refreshed.resident_generation = 2
	check(not cache.refresh_hot("b",refreshed,1,edited).ok,
		"inactive changed authoring cannot exceed the retained cache budget")
	check(cache.entry("b")==original and int(cache.status().used_bytes)==used,
		"refused inactive refresh preserves receipt, authoring, mutation and byte authority")
	refreshed.active = true
	check(not cache.refresh_hot("b",refreshed,1,edited).ok,
		"inactive area cannot acquire a growth exception by claiming an active receipt")
	refreshed.active = false
	check(not cache.mark_dirty("b",0,1,edited).ok and cache.entry("b")==original,
		"authoring-only dirty API applies the same inactive admission fence atomically")
	var larger_native := refreshed.duplicate(true)
	larger_native.native_bytes = int(larger_native.native_bytes)+64
	check(not cache.refresh_hot("b",larger_native,0).ok and cache.entry("b")==original,
		"inactive refresh cannot increase native reservation beyond its admitted budget")
	cache.configure(true,40*1024*1024)
	check(cache.refresh_hot("b",refreshed,1,edited).ok and cache.entry("b").dirty,
		"bounded inactive authoring is admitted when retained capacity exists")
	cache.configure(false,1)
	active.resident_generation = 2
	check(cache.refresh_hot("a",active,1,edited).ok and cache.status().over_budget,
		"matching active native authority can retain edits after its budget is lowered")
	edited.camera.note = "longer retained active authoring ".repeat(16)
	check(cache.mark_dirty("a",0,2,edited).ok,
		"active authoring-only dirty observation retains its explicit budget exception")
	refreshed.resident_generation = 3
	check(cache.refresh_hot("b",refreshed,1).ok,
		"existing inactive receipt may refresh without allocating while cache admission is disabled")
	var shared := PackedByteArray()
	shared.resize(5*1024*1024)
	var aliases: Array = []
	aliases.resize(4096)
	aliases.fill(shared)
	var oversized := edited.duplicate(true)
	oversized.camera["aliases"] = aliases
	check(Store._pure(oversized,[Store.MAX_VALUE_ITEMS]),
		"logical twenty-GiB repeated packed payload fits the old pure-item boundary without encoding")
	var encodes := int(cache.status().counters.hot_refresh_encodes)
	original = cache.entry("a")
	active.resident_generation = 3
	check(not cache.refresh_hot("a",active,3,oversized).ok,
		"aggregate metadata refuses before aliased payload expansion even for active authority")
	check(int(cache.status().counters.hot_refresh_encodes)==encodes and cache.entry("a")==original,
		"oversized alias refusal performs no full authoring encoding and preserves resident state")
	var wrong_definition := edited.duplicate(true)
	wrong_definition.definition["unexpected_source_change"] = true
	check(not cache.refresh_hot("a",active,3,wrong_definition).ok \
		and int(cache.status().counters.hot_refresh_encodes)==encodes,
		"unchanged original-construction equality fence still refuses before encoding")
	var wrong_shape := edited.duplicate(true)
	wrong_shape.camera = "unsupported camera shape"
	check(not cache.refresh_hot("a",active,3,wrong_shape).ok,
		"pure values cannot replace required admitted host envelope dictionaries")
	active.active = "true"
	check(not cache.refresh_hot("a",active,3,edited).ok,
		"active growth exception requires a boolean native active receipt")


func exercise_admitted_authoring() -> void:
	var cache := Cache.new()
	check(cache.open(manifest,64*1024*1024).ok,"already-admitted source reuse fixture opens")
	var active := receipt("a",4001)
	active.active = true
	var encoded_before := int(cache.status().counters.authoring_admission_encodes)
	check(cache.admit_hot("a",active,authoring,0).ok and cache.set_active("a").ok,
		"normalized original source admits the real native fixture authoring")
	check(int(cache.status().counters.authoring_admission_encodes)==encoded_before+1,
		"HOT admission uses one bounded authoring encoding for size and digest")
	encoded_before = int(cache.status().counters.authoring_admission_encodes)
	check(cache.retain_warm("b",capture,authoring,0,manifest.areas.b.incarnation).ok,
		"complete validated native checkpoint reuses its normalized original source")
	check(int(cache.status().counters.authoring_admission_encodes)==encoded_before+1,
		"WARM admission uses one bounded authoring encoding for size and digest")
	var unchanged_a := cache.entry("a")
	var unchanged_b := cache.entry("b")
	var shared := PackedByteArray()
	shared.resize(5*1024*1024)
	for label: String in ["geometry","rectangle_count","transport","unknown_definition_field","unknown_nested_field",
			"unsupported_schema","packed_tools","packed_position","packed_rectangles","integral_float","nil_source",
			"unknown_envelope_field","wrong_envelope_shape","aliased_metadata"]:
		var forged := authoring.duplicate(true)
		match label:
			"geometry": forged.definition.rectangles[15] += 1
			"rectangle_count": forged.definition.rectangles.pop_back()
			"transport": forged.definition.transport_profile.families.powder.pickup = 63
			"unknown_definition_field": forged.definition["unverified_extra"] = false
			"unknown_nested_field": forged.definition.transport_profile.families.liquid["unverified_extra"] = 1
			"unsupported_schema": forged.definition.schema_version = 3
			"packed_tools": forged.definition.tools = PackedStringArray(forged.definition.tools)
			"packed_position": forged.definition.player_start = PackedInt32Array(forged.definition.player_start)
			"packed_rectangles": forged.definition.rectangles = PackedInt32Array(forged.definition.rectangles)
			"integral_float": forged.definition.recipe_version = float(forged.definition.recipe_version)
			"nil_source": forged.definition.source_recipe = null
			"unknown_envelope_field": forged["unverified_extra"] = false
			"wrong_envelope_shape": forged.camera = []
			"aliased_metadata": forged.camera["aliases"] = [shared,shared]
		if label.begins_with("packed_"):
			check(JSON.stringify(forged.definition,"",true).sha256_text()==capture.authored_source_sha256 \
				and not Store.Contract.validate(forged.definition).get("ok",false),
				"canonical JSON alone aliases a source type refused by the full validator: "+label)
		encoded_before = int(cache.status().counters.authoring_admission_encodes)
		check(not cache.admit_hot("b",receipt("b",4002),forged,0).ok,
			"HOT admission refuses changed or unsupported complete source: "+label)
		check(not cache.retain_warm("b",capture,forged,0,manifest.areas.b.incarnation).ok,
			"WARM admission refuses changed or unsupported complete source: "+label)
		check(not cache.mark_dirty("a",0,1,forged).ok,
			"authoring mutation refuses changed or unsupported complete source: "+label)
		check(cache.entry("a")==unchanged_a and cache.entry("b")==unchanged_b,
			"refused source preserves native handle, warm checkpoint and host authority: "+label)
		check(int(cache.status().counters.authoring_admission_encodes)==encoded_before,
			"invalid or oversized envelope refuses before full authoring encoding: "+label)
	var wrong_source := receipt("b",4002)
	wrong_source.identity.authored_source_sha256 = "f".repeat(64)
	check(not cache.admit_hot("b",wrong_source,authoring,0).ok,
		"unknown native source identity cannot reuse an admitted cache entry")
	var wrong_capture := capture.duplicate(true)
	wrong_capture.authored_source_sha256 = "f".repeat(64)
	check(not cache.retain_warm("b",wrong_capture,authoring,0,manifest.areas.b.incarnation).ok,
		"unknown captured source identity cannot reuse the admitted native geometry")
	wrong_capture = capture.duplicate(true)
	wrong_capture.native_chunks = 129
	check(not cache.retain_warm("b",wrong_capture,authoring,0,manifest.areas.b.incarnation).ok,
		"native capture capacity count remains fully validated before envelope reuse")
	check(not cache.admit_hot("unknown",receipt("b",4002),authoring,0).ok,
		"unopened area identity cannot enter the normalized-source reuse path")
	var parsed: Variant = JSON.parse_string(JSON.stringify(authoring.definition,"",true))
	var normalized: Dictionary = Store.Contract.validate(parsed)
	check(normalized.get("ok",false) and normalized.get("hash","")==capture.authored_source_sha256,
		"full source validator establishes normalized identity after JSON number parsing")
	if normalized.get("ok",false):
		var reconstructed := authoring.duplicate(true)
		reconstructed.definition = normalized.definition
		check(cache.admit_hot("c",receipt("c",4003),reconstructed,0).ok,
			"normalized JSON reconstruction is admitted without changing its complete source identity")
	var changed := authoring.duplicate(true)
	changed.camera.origin = Vector2i(31,47)
	changed.setup.edits.append([71,80,0,0])
	encoded_before = int(cache.status().counters.authoring_admission_encodes)
	check(cache.mark_dirty("a",0,1,changed).ok and cache.entry("a").authoring.setup.edits.back()==[71,80,0,0],
		"supported camera values and explicit Empty authoring edits retain their original construction")
	check(int(cache.status().counters.authoring_admission_encodes)==encoded_before+1,
		"authoring mutation uses one bounded encoding for accounting and identity")
	var plane: Dictionary = fixture.bridge.capture_material_baseline(fixture.world)
	var flattened: Dictionary = MaterialBaseline.stage(plane,Vector2i(512,512))
	check(not flattened.has("error"),"real native material baseline is validated for Flatten compatibility")
	if not flattened.has("error"):
		var flattened_authoring := changed.duplicate(true)
		flattened_authoring.material_baseline = flattened.baseline
		flattened_authoring.setup.edits = []
		check(cache.mark_dirty("a",0,2,flattened_authoring).ok \
			and cache.retain_warm("a",capture,flattened_authoring,2,manifest.areas.a.incarnation).ok,
			"native flattened starting plane and full dynamic continuation coexist in the cache")
		check(cache.entry("a").authoring.material_baseline.sha256==plane.sha256 \
			and cache.entry("a").authored_source_sha256==capture.authored_source_sha256 \
			and cache.entry("a").capture.sha256==capture.sha256,
			"Flatten changes the authored baseline without replacing original geometry or dynamic state")
	check(fixture.bridge.capture_workbench_continuation(fixture.world).sha256==capture.sha256,
		"cache source checks and material capture never mutate the real native World")


func finish() -> void:
	print("GEN006_RAMCACHE_CACHE checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
