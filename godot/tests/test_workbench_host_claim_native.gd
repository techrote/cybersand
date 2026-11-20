extends SceneTree

# Real MicroScenario host + installed native constructor. The ordinary Main /
# Rapier / saved-map campaign is separate; these fixtures isolate claim capacity,
# complete geometry identity and the existing prepared-World transaction.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const EXTENT := Vector2i(2048,1024)
const COUNTS := [6553,6554,9167,13839,32768]
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var refusals: Array[Dictionary] = []
var bridge: Variant
var world: Variant
var host: RefCounted
var policy := PackedInt32Array()
var refused_token := 0
var native_capacity := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WORKBENCH_HOST_CLAIMS_NATIVE: " + label)
	return ok

func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func definition(count: int, workbench: bool = true) -> Dictionary:
	var value := Contract.base(Contract.WORKBENCH_ID if workbench else "host-claims/native-control")
	value.schema_version = 2
	var width: int = EXTENT.x if workbench else Contract.SIDE
	if workbench: value["extent"] = [width,EXTENT.y]
	value["presentation"] = {"title":"Native host claim capacity","instructions":"Bounded native fixture",
		"duration_ticks":1,"baseline":"workbench","profile":"host-claims","regions":[]}
	value.interest = {"policy":"fixed","region":[0,0,width,EXTENT.y]}
	value.execution.cadence_lod_enabled = false
	for i: int in count:
		value.rectangles.append_array([(i % (width/2))*2,int(i/(width/2))*2,1,1,58])
	# One real falling Sand cell makes post-admission progression observable.
	if count > 0: value.rectangles[-1] = 2
	return value

func sample() -> Dictionary:
	return {"session":1,"epoch":1,"states":PackedFloat64Array(),"geometry":PackedFloat64Array(),"bodies":[]}

func host_setup() -> Dictionary:
	return {"intent":"exploratory","normalization":"","workbench_response":"LA-SELECTIVE",
		"workbench_sample":sample(),"workbench_worker_threads":1,
		"owner_execution":{"region":[0,0,EXTENT.x,EXTENT.y],"simulation_window_enabled":true,
			"cadence_lod_enabled":false,"liquid_surface_adhesion_enabled":true}}

func commit(native_bridge: Variant, token: int) -> bool:
	return native_bridge.commit_liquid_world(world,token)

func refuse_commit(_native_bridge: Variant, token: int) -> bool:
	refused_token = token
	return false

func native_options(checked: Dictionary, workbench: bool = true) -> Dictionary:
	var value := {"definition_hash":checked.hash,"seed":checked.definition.seed,
		"region":PackedInt32Array(checked.definition.interest.region),
		"intent":"exploratory" if workbench else "controlled","pacing":"host_paced" if workbench else "fixed_steps",
		"cadence_lod_enabled":false,"liquid_surface_adhesion_enabled":true,
		"initial_bodies":PackedFloat32Array()}
	if workbench:
		value.merge({"workbench_extent":EXTENT,"workbench_response":"LA-SELECTIVE",
			"workbench_sample":sample(),"workbench_worker_threads":1})
	return value

func native_prepare(words: PackedInt32Array, checked: Dictionary, options: Dictionary) -> int:
	return bridge.prepare_liquid_world(world,words,checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),policy,options)

func material_plane(value: Dictionary) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(EXTENT.x*EXTENT.y*2)
	# Independent ordered material oracle; compare every installed cell, not a
	# palette image, sampled pixels, or a claimed rectangle count.
	for offset: int in range(0,value.rectangles.size(),5):
		for y: int in range(value.rectangles[offset+1],value.rectangles[offset+1]+value.rectangles[offset+3]):
			for x: int in range(value.rectangles[offset],value.rectangles[offset]+value.rectangles[offset+2]):
				result.encode_u16((y*EXTENT.x+x)*2,value.rectangles[offset+4])
	return result

func integer_bytes(value: int, width: int) -> PackedByteArray:
	var result := PackedByteArray()
	for i: int in width: result.append((value >> (i*8)) & 255)
	return result

func expected_setup_hash(checked: Dictionary, payload_hash: String) -> String:
	# Frozen prepared-setup-v1 encoding, independently built from the complete
	# validated definition digest and native payload digest. This confirms the
	# native descriptor binds the same source; it grants no complete-host proof.
	var domain := "cybersand-prepared-setup-v1".to_utf8_buffer()
	var bytes := integer_bytes(domain.size(),4)
	bytes.append_array(domain)
	bytes.append_array(integer_bytes(1,2)) # prepared setup schema
	bytes.append(2) # MicroScenario
	bytes.append_array(integer_bytes(2,2)) # definition schema
	bytes.append(1) # definition digest present
	bytes.append_array(str(checked.hash).hex_decode())
	bytes.append_array(integer_bytes(checked.definition.seed,8))
	bytes.append_array(integer_bytes(0,8)) # x
	bytes.append_array(integer_bytes(0,8)) # y
	bytes.append_array(integer_bytes(EXTENT.x,4))
	bytes.append_array(integer_bytes(EXTENT.y,4))
	bytes.append(2) # RegisteredDefinitionAndPayload
	bytes.append_array(integer_bytes(63,4)) # unchanged known setup gaps
	bytes.append_array(payload_hash.hex_decode())
	return digest(bytes)

func retained_state() -> Dictionary:
	return {"physical_hash":world.get_physical_state_hash(),"generation":world.get_liquid_policy_session_generation(),
		"revision":world.get_revision(),"tick":world.get_tick_index(),
		"native_receipt_hash":world.get_applied_liquid_construction_receipt().get("receipt_hash",""),
		"host_definition_hash":host.summary().get("definition_hash",""),
		"host_observation":host.liquid_host_observation()}

func accepted_case(count: int) -> void:
	var first_failure := failures.size()
	var first_check := checks
	var value := definition(count)
	var original: Dictionary = value.duplicate(true)
	var checked := Contract.validate(value)
	var row := {"rectangle_count":count,"accepted":false}
	cases.append(row)
	if not check(checked.ok,"%d complete source validates" % count): return
	row["complete_definition_sha256"] = checked.hash
	var old_generation: int = world.get_liquid_policy_session_generation()
	if not check(host.install(world,value,"Play",false,policy,host_setup(),commit),
			"%d real host installation / %s" % [count,host.last_error]): return
	row.accepted = true
	check(world.get_liquid_policy_session_generation() == old_generation+1 and world.get_tick_index() == 0,
		"%d successful commit installs one fresh tick-zero generation" % count)
	check(host.definition() == checked.definition and value == original,
		"%d native host retains complete geometry without mutating caller input" % count)
	var capture: Dictionary = bridge.capture_material_baseline(world)
	var expected := material_plane(checked.definition)
	check(capture.get("ok",false) and capture.extent == EXTENT and capture.cells == expected
		and capture.sha256 == digest(expected),"%d complete native stored-material plane matches all authored cells" % count)
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	check(receipt.workbench_extent == EXTENT and receipt.qualifications == 15
		and not receipt.eligible_for_full_matched_evidence
		and digest(receipt.canonical_bytes) == receipt.receipt_hash,
		"%d native receipt retains its actual extent, integrity and qualified scope" % count)
	check(receipt.prepared_setup_hash == expected_setup_hash(checked,receipt.prepared_payload_hash),
		"%d native prepared identity binds the complete validated source digest" % count)
	var record: Dictionary = host.liquid_host_observation_record()
	if not check(not record.is_empty(),"%d real host observation exists after commit" % count): return
	var claims: Dictionary = record.values.host_claims.values
	check(record.identity.definition_hash == checked.hash and claims.definition_hash == checked.hash
		and record.values.native_applied_run.canonical_bytes_hex == receipt.canonical_bytes.hex_encode()
		and record.values.host_claims.status == "unverified" and not record.values.host_eligible_for_full_matched_evidence,
		"%d reduced claim and actual native acknowledgement retain distinct authorities" % count)
	var projected := count*5 > Host.HOST_CLAIM_MAX_CONTAINER_WORDS
	if projected:
		var projection: Dictionary = claims.get("definition_projection",{})
		check(not claims.definition.has("rectangles")
			and projection.get("rectangle_count",{}).get("integer_decimal","") == str(count)
			and projection.get("integer_word_count",{}).get("integer_decimal","") == str(count*5)
			and projection.get("validated_complete_definition_sha256","") == checked.hash
			and projection.get("status","") == "unverified_host_claim_projection",
			"%d applied observation discloses omission, exact count and complete identity" % count)
	else:
		check(not claims.has("definition_projection") and claims.definition.rectangles.size() == count*5,
			"%d below-boundary observation retains the complete original rectangle claim" % count)
	for i: int in 4: check(host.advance(),"%d admitted native host tick %d" % [count,i+1])
	var evolved: Dictionary = bridge.capture_material_baseline(world)
	check(world.get_tick_index() == 4 and not world.has_failed() and evolved.sha256 != capture.sha256,
		"%d actual native ticks advance a real falling material after admission" % count)
	row.merge({"generation":world.get_liquid_policy_session_generation(),"extent":[EXTENT.x,EXTENT.y],
		"native_prepared_setup_sha256":receipt.prepared_setup_hash,"native_payload_sha256":receipt.prepared_payload_hash,
		"native_receipt_sha256":receipt.receipt_hash,"material_plane_sha256":capture.sha256,
		"evolved_material_plane_sha256":evolved.sha256,"host_projected":projected,
		"native_ticks":world.get_tick_index(),"checks":checks-first_check,"failures":failures.size()-first_failure,
		"passed":failures.size()==first_failure})
	print("WORKBENCH_HOST_CLAIMS_NATIVE_CASE: " + JSON.stringify(row))

func refused_native(label: String, words: PackedInt32Array, checked: Dictionary, options: Dictionary) -> void:
	var before := retained_state()
	var token := native_prepare(words,checked,options)
	var reason: String = bridge.get_last_error()
	var refused := token == 0
	check(refused and not reason.is_empty(),label+" is refused by the actual native constructor")
	var preserved := retained_state() == before
	check(preserved,label+" preserves the installed World, host cursor and receipt")
	if token > 0: bridge.discard_liquid_world(world,token)
	var progressed: bool = host.advance() and world.get_tick_index() == int(before.tick)+1 and not world.has_failed()
	check(progressed,label+" leaves the old native World able to advance")
	refusals.append({"case":label,"refused":refused,"reason":reason,"old_world_preserved":preserved,
		"old_world_advanced":progressed,"tick_after":world.get_tick_index()})

func negative_cases() -> void:
	var checked := Contract.validate(definition(6554))
	var options := native_options(checked)
	refused_native("one beyond installed native rectangle capacity",PackedInt32Array(definition(native_capacity+1).rectangles),checked,options)
	var truncated := PackedInt32Array(checked.definition.rectangles)
	truncated.resize(truncated.size()-1)
	refused_native("mismatched five-word rectangle count",truncated,checked,options)
	var malformed := PackedInt32Array(checked.definition.rectangles)
	malformed[malformed.size()-5] = EXTENT.x
	refused_native("malformed omitted-tail geometry",malformed,checked,options)
	malformed = PackedInt32Array(checked.definition.rectangles)
	malformed[-1] = Contract.MATERIAL_COUNT
	refused_native("invalid omitted-tail material",malformed,checked,options)
	var wrong_hash := options.duplicate(true)
	wrong_hash.definition_hash = "0".repeat(62)
	refused_native("invalid complete-source digest length",PackedInt32Array(checked.definition.rectangles),checked,wrong_hash)
	var too_large := options.duplicate(true)
	too_large.workbench_extent = Vector2i(2112,1024)
	refused_native("unchanged native World extent ceiling",PackedInt32Array(checked.definition.rectangles),checked,too_large)
	var invalid_response := options.duplicate(true)
	invalid_response.workbench_response = "unsupported-response"
	refused_native("unchanged native response allowlist",PackedInt32Array(checked.definition.rectangles),checked,invalid_response)
	var ordinary := Contract.validate(definition(Contract.MAX_RECORDS,false))
	var ordinary_options := native_options(ordinary,false)
	var before := retained_state()
	var token := native_prepare(PackedInt32Array(ordinary.definition.rectangles),ordinary,ordinary_options)
	check(token > 0,"ordinary non-Workbench native constructor still admits 4096 records")
	if token > 0: bridge.discard_liquid_world(world,token)
	check(retained_state() == before,"discarding the ordinary control leaves the valid Workbench intact")
	refused_native("non-Workbench above its unchanged native rectangle ceiling",
		PackedInt32Array(definition(Contract.MAX_RECORDS+1,false).rectangles),ordinary,ordinary_options)
	# Actual Host.install must refuse invalid source before preparing anything.
	before = retained_state()
	check(not host.install(world,definition(native_capacity+1),"Play",false,policy,host_setup(),commit)
		and retained_state() == before,"host source-capacity refusal preserves the running native World and cursor")
	check(host.advance() and world.get_tick_index() == int(before.tick)+1,
		"old World advances after host source-capacity refusal")
	# A valid, fully prepared replacement reaches the real owner commit guard,
	# which vetoes adoption. No fake bridge or World substitutes for this path.
	before = retained_state()
	var owner_refused: bool = not host.install(world,checked.definition,"Play",false,policy,host_setup(),refuse_commit)
	var preserved: bool = retained_state() == before
	check(owner_refused and refused_token > 0 and preserved,
		"refused owner commit discards a fully prepared large candidate and preserves the old World")
	check(not bridge.commit_liquid_world(world,refused_token) and retained_state() == before,
		"a discarded owner-refused token cannot subsequently replace the old World")
	check(host.advance() and world.get_tick_index() == int(before.tick)+1 and not world.has_failed(),
		"old World advances after a refused replacement and stale-token retry")
	refusals.append({"case":"owner commit veto","refused":owner_refused and refused_token>0,
		"old_world_preserved":preserved,
		"old_world_advanced":world.get_tick_index()==int(before.tick)+1,"tick_after":world.get_tick_index()})

func run() -> void:
	if not check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge"),
			"real native adapter is available"):
		finish();return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	host = Host.new()
	if not check(bridge.has_method(&"workbench_start_rectangle_capacity") and bridge.has_method(&"capture_material_baseline"),
			"installed runtime exposes construction capacity and authoritative material readback"):
		finish();return
	native_capacity = bridge.workbench_start_rectangle_capacity()
	if not check(native_capacity == 32768,"installed native constructor reports the actual 32768-record budget"):
		finish();return
	policy = bridge.default_liquid_policy()
	for count: int in COUNTS: accepted_case(count)
	if host.active(): negative_cases()
	finish()

func finish() -> void:
	var report := {"schema":1,"completed":true,"passed":failures.is_empty(),"checks":checks,
		"failures":failures.size(),"failure_messages":failures,"platform":OS.get_name(),
		"engine":Engine.get_version_info().get("string","unknown"),"native_rectangle_capacity":native_capacity,
		"native_runtime":bridge.loaded_native_runtime_values() if bridge != null and bridge.has_method(&"loaded_native_runtime_values") else {},
		"host_script_sha256":FileAccess.get_sha256("res://scripts/microscenario_host.gd"),
		"contract_script_sha256":FileAccess.get_sha256("res://scripts/microscenario_contract.gd"),
		"test_script_sha256":FileAccess.get_sha256("res://tests/test_workbench_host_claim_native.gd"),
		"cases":cases,"refusals":refusals,
		"scope":"native constructor and real MicroScenario host; ordinary Main/Rapier/save-reopen campaign is separate"}
	var path := OS.get_environment("WB_HOST_NATIVE_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if check(file != null,"native capacity report can be written"):
			report.checks = checks
			file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WORKBENCH_HOST_CLAIMS_NATIVE: %d assertions, %d failures" % [checks,failures.size()])
	quit(1 if not failures.is_empty() else 0)
