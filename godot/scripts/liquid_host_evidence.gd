extends RefCounted

# Versioned, qualified host observations. This foundation deliberately grants no
# complete host/mapped-module proof; owner integration and controlled publication
# must supply those bindings separately. Native outer receipt-v1 is unchanged.
const VERSION: int = 1
const MAX_MANIFEST_BYTES: int = 2 * 1024 * 1024
const MAX_SCRIPT_INPUTS: int = 1024
const MAX_CANONICAL_BYTES: int = 4 * 1024 * 1024
const MAX_CLAIM_VALUES: int = 131072
const MAX_CLAIM_TEXT_BYTES: int = 2 * 1024 * 1024
const EXTENSION: String = "res://addons/cybersand_native/cybersand_native.gdextension"
var _values: Dictionary = {}
var _bytes := PackedByteArray()
var _digest: String = ""

static func _manifest_path() -> String:
	if OS.has_feature("web"): return "res://addons/cybersand_native/runtime-provenance.web.json"
	return "res://addons/cybersand_native/runtime-provenance%s.json" % (".linux" if OS.get_name() == "Linux" else "")

static func runtime_observation(bridge: Variant) -> Dictionary:
	var result: Dictionary = {"schema_version":VERSION,"platform":OS.get_name(),
		"godot":Engine.get_version_info().get("string","unknown"),"editor_hint":Engine.is_editor_hint(),
		"mapped_module_binding":"unverified","source_execution_binding":"unverified"}
	result["path_file"] = (bridge.loaded_native_runtime_values().duplicate(true)
		if bridge != null and bridge.has_method(&"loaded_native_runtime_values")
		else {"status":"unavailable","detail":"Runtime has no path/file observation adapter"})
	var config := ConfigFile.new()
	result["extension_config"] = {"path":EXTENSION,"status":"unavailable"}
	if config.load(EXTENSION) == OK:
		result.extension_config = {"path":EXTENSION,"sha256":FileAccess.get_sha256(EXTENSION),
			"status":"observed","reloadable":bool(config.get_value("configuration","reloadable",false)),
			"entry_symbol":str(config.get_value("configuration","entry_symbol",""))}
	var path: String = _manifest_path()
	var manifest_values: Dictionary = {"path":path,"status":"unavailable","artifact_matches_current_path_file":false}
	result["publication_manifest"] = manifest_values
	if not FileAccess.file_exists(path): return result
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > MAX_MANIFEST_BYTES:
		manifest_values.status = "unreadable_or_capacity_refused"
		return result
	var text: String = file.get_as_text()
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		manifest_values.status = "invalid"
		return result
	var manifest: Dictionary = parser.data
	manifest_values.status = "observed"
	manifest_values["sha256"] = FileAccess.get_sha256(path)
	manifest_values["declared_artifact_sha256"] = str(manifest.get("sha256",""))
	manifest_values["declared_source_commit"] = str(manifest.get("source_commit",""))
	manifest_values["declared_source_tree"] = str(manifest.get("source_tree",""))
	manifest_values.artifact_matches_current_path_file = (result.path_file.get("status","") == "path_file_observed"
		and str(manifest.get("sha256","")).length() == 64
		and manifest.sha256 == result.path_file.get("current_file_sha256"))
	# Read only the manifest's bounded in-project resource-script subset. These
	# are current file observations, not proof of mapped/compiled script bytes.
	var build_inputs: Variant = manifest.get("build_inputs",{})
	var scripts: Array[Dictionary] = []
	manifest_values["resource_script_observations"] = scripts
	manifest_values["resource_script_scope"] = "Manifest-listed current .gd files; executed-script binding remains unverified"
	if not build_inputs is Dictionary:
		manifest_values["script_status"] = "invalid_input_map"
		return result
	var keys: Array = build_inputs.keys();keys.sort()
	for value: Variant in keys:
		if not value is String: continue
		var source: String = value
		if not source.begins_with("godot/") or not source.ends_with(".gd"): continue
		if source.length() > 256 or source.simplify_path() != source or source.contains(":"):
			manifest_values["script_status"] = "invalid_resource_path"
			return result
		if scripts.size() == MAX_SCRIPT_INPUTS:
			manifest_values["script_status"] = "capacity_refused"
			return result
		var resource: String = "res://"+source.trim_prefix("godot/")
		var observed: Dictionary = {"path":source,"declared_sha256":str(build_inputs[value]),"status":"unavailable"}
		if FileAccess.file_exists(resource):
			var script_file := FileAccess.open(resource,FileAccess.READ)
			if script_file != null and script_file.get_length() <= MAX_MANIFEST_BYTES:
				observed.status = "observed"
				observed["raw_file_sha256"] = FileAccess.get_sha256(resource)
				observed["git_text_sha256"] = script_file.get_as_text().replace("\r\n","\n").sha256_text()
				observed["matches_declared_git_text"] = observed.git_text_sha256 == observed.declared_sha256
			else: observed.status = "unreadable_or_capacity_refused"
		scripts.append(observed)
	manifest_values["script_status"] = "observed"
	return result

static func _claims(value: Variant, depth: int, budget: Array[int]) -> Dictionary:
	budget[0] -= 1
	if depth > 24 or budget[0] < 0: return {"ok":false}
	if value is String:
		if value.length() > budget[1]: return {"ok":false}
		budget[1] -= value.to_utf8_buffer().size()
		return {"ok":budget[1] >= 0,"value":value}
	if value == null or value is bool: return {"ok":true,"value":value}
	# Preserve full signed identities across JSON's numeric round trip.
	if value is int: return {"ok":true,"value":{"integer_decimal":str(value)}}
	if value is float:
		return {"ok":is_finite(value),"value":value}
	if value is Array or value is Dictionary:
		if value.size() > 32768: return {"ok":false}
		var converted: Variant = [] if value is Array else {}
		for key: Variant in range(value.size()) if value is Array else value.keys():
			if value is Dictionary:
				if not key is String or key.length() > 256: return {"ok":false}
				budget[1] -= key.to_utf8_buffer().size()
				if budget[1] < 0: return {"ok":false}
			var item: Dictionary = _claims(value[key],depth+1,budget)
			if not item.ok: return {"ok":false}
			if value is Array: converted.append(item.value)
			else: converted[key] = item.value
		return {"ok":true,"value":converted}
	return {"ok":false}

static func collect(bridge: Variant, native_receipt: Dictionary, host_claims: Dictionary = {}) -> Dictionary:
	# The exclusive owner supplies copied native readback. Digest equality is a
	# consistency check, not an independent GDScript decoder of the native codec.
	var native_bytes: Variant = native_receipt.get("canonical_bytes")
	if native_receipt.get("kind","") != "applied_run" or native_receipt.get("schema_version",0) != 1 \
		or not native_bytes is PackedByteArray or native_bytes.is_empty():
		return {"ok":false,"error":"A typed native applied-run receipt is required"}
	if not native_receipt.get("qualifications") is int \
		or not native_receipt.get("eligible_for_full_matched_evidence") is bool:
		return {"ok":false,"error":"Native receipt qualification metadata is required"}
	# This version understands only the frozen qualified native outer-v1.
	if native_receipt.qualifications != 15 or native_receipt.eligible_for_full_matched_evidence:
		return {"ok":false,"error":"Native outer-v1 qualification metadata disagrees with its frozen contract"}
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(native_bytes)
	if hash.finish().hex_encode() != native_receipt.get("receipt_hash",""):
		return {"ok":false,"error":"Native copied bytes and declared digest disagree"}
	var claims: Dictionary = _claims(host_claims,0,[MAX_CLAIM_VALUES,MAX_CLAIM_TEXT_BYTES])
	if not claims.ok: return {"ok":false,"error":"Host claims exceed the pure value/depth/capacity contract"}
	var values: Dictionary = {"schema_version":VERSION,"kind":"qualified_liquid_host_observation",
		"native_applied_run":{"schema_version":1,"canonical_bytes_hex":native_bytes.hex_encode(),
			"receipt_hash":native_receipt.receipt_hash,"qualifications":int(native_receipt.qualifications),
			"native_eligible_for_full_matched_evidence":bool(native_receipt.eligible_for_full_matched_evidence),
			"session_generation_decimal":str(native_receipt.get("session_generation","unavailable"))},
		"runtime":runtime_observation(bridge),"host_claims":{"status":"unverified","values":claims.value},
		"qualifications":["native_outer_receipt_qualifications_retained","mapped_module_binding_unverified",
			"executed_script_binding_unverified","complete_setup_actor_execution_binding_unverified"],
		"host_eligible_for_full_matched_evidence":false}
	var bytes: PackedByteArray = JSON.stringify(values,"",true,true).to_utf8_buffer()
	if bytes.size() > MAX_CANONICAL_BYTES: return {"ok":false,"error":"Host observation byte capacity exceeded"}
	var evidence = load("res://scripts/liquid_host_evidence.gd").new()
	evidence._values = values;evidence._bytes = bytes;evidence._digest = bytes.get_string_from_utf8().sha256_text()
	_freeze(values)
	return {"ok":true,"evidence":evidence}

static func _freeze(value: Variant) -> void:
	if value is Dictionary or value is Array:
		for nested: Variant in value.values() if value is Dictionary else value: _freeze(nested)
		value.make_read_only()

func snapshot() -> Dictionary:
	return _values.duplicate(true)

func canonical_bytes() -> PackedByteArray:
	return _bytes.duplicate()

func digest() -> String:
	return _digest
