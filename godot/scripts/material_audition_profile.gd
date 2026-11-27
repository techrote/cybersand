extends RefCounted

# A portable scene-local configuration, never a World snapshot or a catalogue
# installer. The native owner remains the authority for every application.
const SCHEMA := "cybersand.material-audition.profile"
const VERSION := 1
const MAX_BYTES := 65536
const MAX_MATERIALS := 132
const MAX_REACTIONS := 56
const JsonParser = preload("res://scripts/material_lab_experiment.gd")

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func _keys(value: Dictionary, required: Array, optional: Array = []) -> bool:
	for key: Variant in value:
		if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME] or (key not in required and key not in optional): return false
	for key: String in required:
		if not value.has(key): return false
	return true

static func _ascii_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64: return false
	for index: int in range(value.length()):
		var point: int = value.unicode_at(index)
		if not ((point >= 48 and point <= 57) or (point >= 65 and point <= 90) or (point >= 97 and point <= 122) or point in [45,46,95]): return false
	return true

static func capability_key(row: Dictionary) -> String:
	if row.get("kind") == "reaction": return "reaction:%d:%s" % [int(row.get("slot",-1)),str(row.get("property",""))]
	return "material:%d:%s" % [int(row.get("material_id",-1)),str(row.get("property",""))]

static func _capability(state: Dictionary, kind: String, identity: int, property: String) -> Dictionary:
	for row: Variant in state.get("capabilities",[]):
		if not row is Dictionary: continue
		if row.get("kind") == kind and row.get("property") == property and int(row.get("slot" if kind == "reaction" else "material_id",-1)) == identity:
			return row
	return {}

static func _admission(state: Dictionary, kind: String, identity: int, property: String, value: Variant) -> String:
	var cap := _capability(state,kind,identity,property)
	if cap.is_empty(): return "%s %d / %s has no current-scene consumer." % [kind.capitalize(),identity,property]
	if cap.get("change_class") != "live":
		return "%s %d / %s is %s: %s" % [kind.capitalize(),identity,property,str(cap.get("change_class","unsupported")),str(cap.get("applicability","No live consumer is admitted."))]
	if not _integer(value,int(cap.get("minimum",0)),int(cap.get("maximum",0))):
		return "%s requires a whole number from %d to %d." % [property,int(cap.get("minimum",0)),int(cap.get("maximum",0))]
	return ""

static func defaults(profile_id: String = "accepted-defaults") -> Dictionary:
	return {"schema_version":VERSION,"profile_id":profile_id,"materials":[],"reactions":[]}

static func validate_profile(value: Variant, state: Dictionary) -> Dictionary:
	if not value is Dictionary or not _keys(value,["schema_version","profile_id","materials","reactions"]):
		return _fail("Unsupported material profile fields; a profile requires version, identity, materials and reactions only.")
	if not _integer(value.schema_version,VERSION,VERSION) or not _ascii_id(value.profile_id):
		return _fail("Use material profile version 1 and a 1–64 character ASCII profile identity (letters, digits, dash, underscore or dot).")
	if not value.materials is Array or value.materials.size() > MAX_MATERIALS or not value.reactions is Array or value.reactions.size() > MAX_REACTIONS:
		return _fail("A material profile is limited to 132 material entries and 56 reaction entries.")
	var out := defaults(str(value.profile_id))
	var seen := {}
	for entry: Variant in value.materials:
		if not entry is Dictionary or not _keys(entry,["material_id"],["density","viscosity"]) or not _integer(entry.material_id,0,131) or entry.size() == 1:
			return _fail("Each material entry needs an existing material_id and an admitted density or viscosity value.")
		var id := int(entry.material_id)
		if seen.has(id): return _fail("Duplicate material ID %d in profile." % id)
		seen[id] = true
		var normalized := {"material_id":id}
		for property: String in ["density","viscosity"]:
			if not entry.has(property): continue
			var error := _admission(state,"material",id,property,entry[property])
			if not error.is_empty(): return _fail(error)
			normalized[property] = int(entry[property])
		out.materials.append(normalized)
	seen.clear()
	for entry: Variant in value.reactions:
		if not entry is Dictionary or not _keys(entry,["slot","probability_threshold"]) or not _integer(entry.slot,0,55):
			return _fail("Each reaction entry needs an existing slot and probability_threshold; identities, roles and products stay fixed.")
		var slot := int(entry.slot)
		if seen.has(slot): return _fail("Duplicate reaction slot %d in profile." % slot)
		seen[slot] = true
		var error := _admission(state,"reaction",slot,"probability_threshold",entry.probability_threshold)
		if not error.is_empty(): return _fail(error)
		out.reactions.append({"slot":slot,"probability_threshold":int(entry.probability_threshold)})
	out.materials.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.material_id) < int(b.material_id))
	out.reactions.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.slot) < int(b.slot))
	return {"ok":true,"profile":out}

static func value_for(profile: Dictionary, row: Dictionary) -> int:
	var reaction: bool = row.get("kind") == "reaction"
	var identity: String = "slot" if reaction else "material_id"
	for entry: Dictionary in profile.get("reactions" if reaction else "materials",[]):
		if int(entry.get(identity,-1)) == int(row.get(identity,-2)) and entry.has(str(row.property)):
			return int(entry[str(row.property)])
	return int(row.get("declared",0))

static func set_value(profile: Dictionary, row: Dictionary, value: int) -> Dictionary:
	var out := profile.duplicate(true)
	var reaction: bool = row.get("kind") == "reaction"
	var collection: String = "reactions" if reaction else "materials"
	var identity: String = "slot" if reaction else "material_id"
	var entries: Array = out.get(collection,[])
	var found: int = -1
	for index: int in range(entries.size()):
		if int(entries[index].get(identity,-1)) == int(row.get(identity,-2)): found = index
	if found < 0:
		var entry: Dictionary = {}
		entry[identity] = int(row[identity])
		entries.append(entry)
		found = entries.size()-1
	var property := str(row.property)
	if value == int(row.get("declared",0)):
		entries[found].erase(property)
		if entries[found].size() == 1: entries.remove_at(found)
	else:
		entries[found][property] = value
	out[collection] = entries
	return out

static func _digest(value: Dictionary) -> String:
	return (JSON.stringify(value,"",true) + "\n").sha256_text()

static func make_envelope(profile: Dictionary, state: Dictionary, name: String, description: String = "") -> Dictionary:
	var checked := validate_profile(profile,state)
	if not checked.get("ok",false): return checked
	name = name.strip_edges()
	if name.is_empty() or name.length() > 96 or description.length() > 2048:
		return _fail("Name the profile with 1–96 characters; its description can contain up to 2048 characters.")
	if not state.get("source_identity") is String or str(state.source_identity).is_empty() or not state.get("native_compatibility") is String or str(state.native_compatibility).is_empty():
		return _fail("The current native owner has not supplied source and compatibility identities; this profile cannot be saved as qualified.")
	var payload := {"schema_id":SCHEMA,"schema_version":VERSION,"name":name,"description":description,
		"source_identity":str(state.source_identity),"native_compatibility":str(state.native_compatibility),"profile":checked.profile}
	return {"ok":true,"envelope":{"payload":payload,"sha256":_digest(payload)}}

static func parse_envelope(text: String, state: Dictionary) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return _fail("Material profile exceeds the 64 KiB import budget.")
	var parsed := JsonParser._parse_unique_json(text)
	if not parsed.get("ok",false): return parsed
	var value: Variant = parsed.value
	if not value is Dictionary or not _keys(value,["payload","sha256"]) or not value.payload is Dictionary or not value.sha256 is String:
		return _fail("Not a digested material profile envelope.")
	var payload: Dictionary = value.payload
	if not _keys(payload,["schema_id","schema_version","name","description","source_identity","native_compatibility","profile"]) or payload.schema_id != SCHEMA or not _integer(payload.schema_version,VERSION,VERSION):
		return _fail("Unsupported saved material profile version or fields.")
	if not payload.name is String or not payload.description is String or not payload.source_identity is String or not payload.native_compatibility is String:
		return _fail("Saved material profile metadata must be text.")
	if payload.source_identity != state.get("source_identity") or payload.native_compatibility != state.get("native_compatibility"):
		return _fail("This profile belongs to different native source or compatibility. Reconcile it explicitly in the isolated authoring tools; the current scene is unchanged.")
	var rebuilt := make_envelope(payload.profile,state,payload.name,payload.description)
	if not rebuilt.get("ok",false): return rebuilt
	if str(value.sha256) != rebuilt.envelope.sha256:
		return _fail("Material profile digest does not match its validated contents.")
	return {"ok":true,"profile":rebuilt.envelope.payload.profile,"name":payload.name,"description":payload.description,"envelope":rebuilt.envelope}

static func save(path: String, profile: Dictionary, state: Dictionary, name: String, description: String = "") -> Dictionary:
	var built := make_envelope(profile,state,name,description)
	if not built.get("ok",false): return built
	# Write a temporary sibling and rename only after complete persistence. Failed
	# writes never destroy the previous named profile.
	var temporary: String = path + ".tmp-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return _fail("Cannot open the profile destination: " + error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(built.envelope,"\t",true) + "\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("Could not finish writing the material profile: " + error_string(error))
	error = DirAccess.rename_absolute(temporary,path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("Could not replace the named material profile: " + error_string(error))
	return {"ok":true,"path":path,"envelope":built.envelope}

static func load_file(path: String, state: Dictionary) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return _fail("Cannot open material profile: " + error_string(FileAccess.get_open_error()))
	if file.get_length() > MAX_BYTES:
		file.close()
		return _fail("Material profile exceeds the 64 KiB import budget.")
	var text := file.get_as_text()
	file.close()
	return parse_envelope(text,state)
