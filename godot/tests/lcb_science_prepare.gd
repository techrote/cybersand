extends SceneTree

# Apparatus-only precursor: the real schema-2 validator and transactional native
# constructor own setup. Export completed0 before events0. This immutable receipt
# belongs to workers1 and cannot be relabelled a restored CLI/whole-host receipt.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Evidence = preload("res://scripts/liquid_host_evidence.gd")

func _initialize() -> void:
	prepare.call_deferred()

func refuse(message: String) -> void:
	push_error("LCB_SCIENCE_PREPARE: " + message)
	quit(1)

# Every integer in observation dictionaries is a decimal string. The definition
# itself is retained separately as its original bytes and normalized JSON text.
func copied_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT: return str(value)
		TYPE_PACKED_BYTE_ARRAY: return {"encoding":"hex", "value":value.hex_encode()}
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key: Variant in value: result[str(key)] = copied_json(value[key])
			return result
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var result: Array = []
			for item: Variant in value: result.append(copied_json(item))
			return result
	return value

func checkpoint(world: Variant, bridge: Variant) -> Dictionary:
	return {"completed_tick":str(world.get_tick_index()),
		"physical_hash":world.get_physical_state_hash(),
		"physical_hash_version":str(world.get_physical_state_hash_version()),
		"quiescent_hash":world.get_liquid_comparison_hash(2),
		"pressure_equivalence_hash":world.get_liquid_comparison_hash(1),
		"water":copied_json(world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024))),
		"statistics":copied_json(bridge.inspect_statistics(world))}

func prepare() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		refuse("expected one apparatus job path");return
	var job_path: String = arguments[0]
	if not job_path.is_absolute_path() or not FileAccess.file_exists(job_path):
		refuse("job path must be an existing absolute file");return
	var job_file := FileAccess.open(job_path,FileAccess.READ)
	if job_file == null or job_file.get_length() > 1024*1024:
		refuse("job exceeds input budget or cannot be opened");return
	var parsed: Variant = JSON.parse_string(job_file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema","") != "lcb-science-prepare-job-v1":
		refuse("invalid job schema");return
	var job: Dictionary = parsed
	var definition_path: String = str(job.get("definition_path",""))
	var output: String = str(job.get("output_dir",""))
	var radius: int = int(job.get("maximum_rule_radius",0))
	var qualification_ticks: int = int(job.get("qualification_ticks",0))
	var normalization: String = str(job.get("normalization",""))
	if not definition_path.is_absolute_path() or not output.is_absolute_path() \
		or not DirAccess.dir_exists_absolute(output) or radius not in [2,3] \
		or qualification_ticks < 0 or qualification_ticks > 30 \
		or normalization not in ["","water-normalize-v1"]:
		refuse("invalid bounded preparation options");return
	for leaf: String in ["initial.cyps","precursor.json"]:
		if FileAccess.file_exists(output.path_join(leaf)):
			refuse("output already exists");return
	var definition_file := FileAccess.open(definition_path,FileAccess.READ)
	if definition_file == null or definition_file.get_length() > Contract.MAX_JSON_BYTES:
		refuse("definition unavailable or exceeds contract byte budget");return
	var text: String = definition_file.get_as_text()
	var checked: Dictionary = Contract.parse(text)
	if not checked.get("ok",false):
		refuse("definition rejected: " + str(checked.get("error","")));return
	var definition: Dictionary = checked.definition
	if int(definition.schema_version) != 2 or definition.player_enabled or definition.body_enabled \
		or definition.interest.policy != "fixed" or definition.execution.policy != "fixed":
		refuse("apparatus requires a fixed actor-free schema-2 definition");return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if world == null or bridge == null or not world.diagnostic_reset({"workers":1}):
		refuse("native preparation owner unavailable");return
	var request: PackedInt32Array = bridge.default_liquid_policy()
	for assignment: Dictionary in job.get("assignments",[]):
		var found: PackedInt32Array = PackedInt32Array()
		for choice: Dictionary in bridge.liquid_policy_assignment_choices(request,int(assignment.material)):
			if choice.family == assignment.family and choice.variant == assignment.variant and choice.accepted:
				found = choice.request;break
		if found.is_empty():
			refuse("requested family/variant is not admitted by this native runtime");return
		request = found
	var host: CyberMicroScenarioHost = Host.new()
	if not host.install(world,definition,"Benchmark",true,request,
		{"intent":"controlled","normalization":normalization,"maximum_rule_radius":radius}):
		print("LCB_SCIENCE_PREPARATION_REFUSAL: " + JSON.stringify(copied_json(
			{"error":host.last_error,"attempt":world.get_liquid_construction_attempt()})))
		refuse("controlled constructor refused");return
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	if world.has_failed() or world.get_tick_index() != 0 or receipt.get("completed_tick",-1) != 0 \
		or receipt.get("worker_threads",0) != 1 or receipt.get("initial_body_count",-1) != 0 \
		or receipt.get("maximum_rule_radius",0) != radius or not world.get_simulation_window_enabled():
		refuse("prepared owner/readback differs from declared actor-free precursor");return
	var bytes: PackedByteArray = bridge.export_physical_state(world)
	if bytes.is_empty() or bytes.size() > 128*1024*1024:
		refuse("CYPS export unavailable or over budget");return
	var snapshot_path: String = output.path_join("initial.cyps")
	var snapshot := FileAccess.open(snapshot_path,FileAccess.WRITE)
	if snapshot == null:
		refuse("cannot create snapshot");return
	snapshot.store_buffer(bytes);snapshot.close()
	var baselines: Array = [checkpoint(world,bridge)]
	# CYPS retains block activity, but reconstructs the legacy aggregate chunk
	# quiet cache. Keep the prepared observation, and independently observe the
	# same saved boundary through the actual Godot restore API as the CLI does.
	var restored: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not restored.diagnostic_reset({"workers":1}) or not bridge.import_physical_state(restored,bytes):
		refuse("independent saved-boundary owner restore failed");return
	var restored_bytes: PackedByteArray = bridge.export_physical_state(restored)
	if restored_bytes != bytes:
		refuse("actual Godot restore changed canonical saved state");return
	var restored_hash := HashingContext.new()
	if restored_hash.start(HashingContext.HASH_SHA256) != OK or restored_hash.update(restored_bytes) != OK:
		refuse("cannot hash restored saved-boundary bytes");return
	var restored_sha256: String = restored_hash.finish().hex_encode()
	var restored_initial: Dictionary = checkpoint(restored,bridge)
	for key: String in ["physical_hash","physical_hash_version","quiescent_hash","pressure_equivalence_hash"]:
		if restored_initial[key] != baselines[0][key]:
			refuse("prepared/restored physical authority differs: " + key);return
	if restored_initial.water.content_hash != baselines[0].water.content_hash:
		refuse("prepared/restored visible authority differs");return
	for step: int in range(qualification_ticks):
		if not host.advance() or world.has_failed() or world.get_tick_index() != step+1:
			refuse("qualification host stopped before requested completed tick");return
		baselines.append(checkpoint(world,bridge))
	var observation: Dictionary = {"schema":"lcb-science-precursor-v2",
		"status":"prepared","job_file_sha256":FileAccess.get_sha256(job_path),
		"definition_file_sha256":FileAccess.get_sha256(definition_path),
		"definition_hash":checked.hash,"definition_text":text,
		"normalized_definition_json":JSON.stringify(checked.definition),
		"transport_hash":checked.transport.hash,"requested_policy_words":copied_json(request),
		"applied_policy":copied_json(world.get_liquid_solver_policy()),
		"prepared_receipt":copied_json(receipt),
		"prepared_receipt_canonical_bytes_hex":receipt.canonical_bytes.hex_encode(),
		"snapshot_sha256":FileAccess.get_sha256(snapshot_path),
		"snapshot_bytes":str(bytes.size()),"cyps_version":str(bytes.decode_u32(4)),
		"restored_initial_checkpoint":restored_initial,
		"restored_initial_snapshot_sha256":restored_sha256,
		"initial_legacy_hash_scope":"prepared and restored observations both retained; aggregate chunk quiet is reconstructed from serialized block activity; no legacy-hash equivalence asserted",
		"runtime":copied_json(Evidence.runtime_observation(bridge)),
		"pressure_requested_config":copied_json(world.inspect_pressure_optimization().requested_config),
		"qualification_baselines":baselines,"precursor_workers":"1",
		"qualification_ticks":str(qualification_ticks),"integer_encoding":"canonical-decimal-strings",
		"scope":"Immutable workers1 completed0 native prepared precursor and bounded optional host qualification. Receipt is not restored-CLI or complete-host identity; mapped module and executed scripts remain unverified. Web deferred."}
	var sidecar := FileAccess.open(output.path_join("precursor.json"),FileAccess.WRITE)
	if sidecar == null:
		refuse("cannot create precursor sidecar");return
	sidecar.store_string(JSON.stringify(observation,"\t")+"\n");sidecar.close()
	print("LCB_SCIENCE_PREPARED: " + JSON.stringify({"status":"prepared","definition_hash":checked.hash,
		"snapshot_sha256":FileAccess.get_sha256(snapshot_path),"qualification_ticks":qualification_ticks}))
	quit(0)
