extends SceneTree

const Evidence = preload("res://scripts/liquid_host_evidence.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var assertions: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1;push_error("LIQUID_HOST_EVIDENCE: "+message)

func run() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	expect(bridge.has_method(&"loaded_native_runtime_values"),"fresh runtime provides its own Godot API path observation")
	if not bridge.has_method(&"loaded_native_runtime_values"): finish();return
	var observed: Dictionary = bridge.loaded_native_runtime_values()
	expect(observed.schema_version == 1 and observed.observation_source == "godot_library_path_current_file_v1",
		"native observation has a distinct versioned scope")
	var path: String = observed.api_reported_library_path
	expect(observed.status == "path_file_observed" and path.is_absolute_path() and FileAccess.file_exists(path),
		"actual native API reports an accessible absolute path")
	var actual_file := FileAccess.open(path,FileAccess.READ)
	expect(observed.current_file_sha256 == FileAccess.get_sha256(path) and observed.current_file_size == actual_file.get_length(),
		"native observation matches the current bytes at the reported path")
	expect(observed.mapped_module_binding == "unverified","path and file observation does not imply mapped-module binding")
	var runtime: Dictionary = Evidence.runtime_observation(bridge)
	expect(runtime.editor_hint == Engine.is_editor_hint() and runtime.platform == OS.get_name(),"host collects actual execution mode")
	expect(runtime.path_file == observed and runtime.extension_config.status == "observed" and not runtime.extension_config.reloadable,
		"host retains native values and actual extension configuration")
	expect(runtime.publication_manifest.status == "observed" and not runtime.publication_manifest.artifact_matches_current_path_file,
		"new local runtime remains qualified against the actual older publication manifest")
	expect(runtime.publication_manifest.script_status == "observed" and not runtime.publication_manifest.resource_script_observations.is_empty(),
		"manifest-listed script files are bounded current-file observations")
	expect(runtime.source_execution_binding == "unverified" and runtime.mapped_module_binding == "unverified",
		"current files do not assert executed script or mapped library identity")
	var source: Dictionary = Runner.read_text(PATH)
	var checked: Dictionary = Contract.parse(source.text)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var host := Host.new()
	expect(checked.ok and host.install(world,checked.definition,"Benchmark",true,bridge.default_liquid_policy(),
		{"normalization":"water-normalize-v1"}),"real controlled native construction supplies a typed receipt")
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	var native_bytes: PackedByteArray = receipt.canonical_bytes.duplicate()
	expect(receipt.qualifications == 15 and not receipt.eligible_for_full_matched_evidence,"native outer-v1 remains frozen and qualified")
	var claims: Dictionary = {"runtime_hash":"pretend-matched","eligible_for_full_matched_evidence":true,
		"generation":-9223372036854775807,"complete_setup":true,"nested":[1,"actual claim",false]}
	var result: Dictionary = Evidence.collect(bridge,receipt,claims)
	expect(result.ok,"qualified evidence collects real native bytes and actual runtime observations")
	if not result.ok: finish();return
	var evidence: RefCounted = result.evidence
	var snapshot: Dictionary = evidence.snapshot()
	expect(snapshot.kind == "qualified_liquid_host_observation" and snapshot.schema_version == 1,
		"host record is separately versioned from the native receipt")
	expect(not snapshot.host_eligible_for_full_matched_evidence and snapshot.host_claims.status == "unverified",
		"caller completeness or eligibility claims cannot grant matched evidence")
	expect(snapshot.runtime == runtime and snapshot.runtime.path_file.current_file_sha256 != claims.runtime_hash,
		"caller runtime identity cannot replace actual adapter observations")
	expect(snapshot.host_claims.values.generation.integer_decimal == "-9223372036854775807",
		"signed 64-bit claim identities survive canonical JSON without floating-point loss")
	expect(snapshot.native_applied_run.canonical_bytes_hex == native_bytes.hex_encode()
		and snapshot.native_applied_run.receipt_hash == receipt.receipt_hash
		and snapshot.native_applied_run.qualifications == 15
		and not snapshot.native_applied_run.native_eligible_for_full_matched_evidence,
		"host value copies actual native receipt bytes, digest and qualifications without re-encoding native state")
	var bytes: PackedByteArray = evidence.canonical_bytes()
	expect(bytes.get_string_from_utf8().sha256_text() == evidence.digest(),"canonical host bytes have a stable SHA-256")
	var parser := JSON.new()
	expect(parser.parse(bytes.get_string_from_utf8()) == OK
		and parser.data.host_claims.values.generation.integer_decimal == "-9223372036854775807",
		"canonical record round trips exact signed identity")
	var repeated: Dictionary = Evidence.collect(bridge,receipt,claims)
	expect(repeated.ok and repeated.evidence.canonical_bytes() == bytes and repeated.evidence.digest() == evidence.digest(),
		"same observed inputs produce byte-identical host records")
	# Returned dictionaries and packed bytes are copies, even when deep-duplicate
	# retains a read-only flag: changing an independently rebuilt copy is safe.
	var changed: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	changed.runtime.path_file.current_file_sha256 = "changed"
	bytes[0] = 0
	claims.nested[1] = "changed caller"
	expect(evidence.snapshot().runtime.path_file.current_file_sha256 == observed.current_file_sha256
		and evidence.snapshot().host_claims.values.nested[1] == "actual claim"
		and evidence.canonical_bytes()[0] != 0,"collected values and canonical bytes remain immutable across caller changes")
	expect(world.get_applied_liquid_construction_receipt().canonical_bytes == native_bytes,
		"host observation leaves authoritative native receipt unchanged")
	expect(not Evidence.collect(bridge,{}).ok,"missing typed receipt refuses cleanly")
	var corrupt: Dictionary = receipt.duplicate(true);corrupt.receipt_hash = "0".repeat(64)
	expect(not Evidence.collect(bridge,corrupt).ok,"copied native bytes with a mismatched digest refuse cleanly")
	corrupt = receipt.duplicate(true);corrupt.erase("qualifications")
	expect(not Evidence.collect(bridge,corrupt).ok,"missing native qualifications refuse cleanly")
	corrupt = receipt.duplicate(true);corrupt.eligible_for_full_matched_evidence = true
	expect(not Evidence.collect(bridge,corrupt).ok,"changed native-v1 eligibility metadata cannot upgrade the frozen contract")
	corrupt = receipt.duplicate(true);corrupt.qualifications = 0
	expect(not Evidence.collect(bridge,corrupt).ok,"changed native-v1 qualification metadata cannot upgrade the frozen contract")
	expect(not Evidence.collect(bridge,receipt,{"object":RefCounted.new()}).ok,"object-bearing claims refuse cleanly")
	expect(not Evidence.collect(bridge,receipt,{"float":INF}).ok,"non-finite claims refuse cleanly")
	expect(not Evidence.collect(bridge,receipt,{1:"non-string key"}).ok,"non-string claim keys refuse cleanly")
	var nested: Dictionary = {"value":1}
	for i: int in range(25): nested = {"nested":nested}
	expect(not Evidence.collect(bridge,receipt,nested).ok,"excess depth refuses before canonicalization")
	expect(not Evidence.collect(bridge,receipt,{"text":"x".repeat(Evidence.MAX_CLAIM_TEXT_BYTES+1)}).ok,
		"explicit text capacity refuses cleanly")
	var many: Array = [];many.resize(32769)
	expect(not Evidence.collect(bridge,receipt,{"values":many}).ok,"explicit container capacity refuses cleanly")
	await controlled_probe(runtime,evidence)
	finish()

func controlled_probe(runtime: Dictionary, evidence: RefCounted) -> void:
	# An external test launcher supplies a process barrier, observes this exact
	# process's OS modules, then releases it. This never upgrades the host value.
	var folder: String = OS.get_environment("CYBERSAND_LCB_HOST_PROBE_DIR")
	if folder.is_empty(): return
	var file := FileAccess.open(folder.path_join("ready.json"),FileAccess.WRITE)
	if file == null: expect(false,"external controlled-launch probe directory is writable");return
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"runtime":runtime,
		"host_digest":evidence.digest(),"host_eligible":evidence.snapshot().host_eligible_for_full_matched_evidence},"",true,true))
	file.close()
	var marker := FileAccess.open(folder.path_join("ready.complete"),FileAccess.WRITE)
	if marker == null: expect(false,"external probe completion marker is writable");return
	marker.store_string("ready");marker.close()
	var deadline: int = Time.get_ticks_msec()+15000
	while not FileAccess.file_exists(folder.path_join("release")) and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(FileAccess.file_exists(folder.path_join("release")),"external module observation completed at the explicit process barrier")

func finish() -> void:
	print("LIQUID_HOST_EVIDENCE: %d assertions, %d failures" % [assertions,failures])
	if Engine.is_editor_hint():
		var deadline: int = Time.get_ticks_msec()+15000
		while EditorInterface.get_resource_filesystem().is_scanning() and Time.get_ticks_msec() < deadline:
			await process_frame
	quit(1 if failures else 0)
