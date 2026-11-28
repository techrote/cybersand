extends RefCounted
## Versioned, read-only boundary for an explicitly acquired GOLDMAPS owner export.
## No downloads, artwork copying, native import, owner decisions or corpus writes.
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Campaign=preload("res://scripts/batch_lab/architecture_campaign.gd")
const Design=preload("res://scripts/batch_lab/architectural_retrieval.gd")
const EXPORT_SCHEMA:="goldmaps.architectural-knowledge.v1"
const VIEW_SCHEMA:="cybersand-goldmaps-read-only-view-v1"
const EVIDENCE:="40f196f792e4d9e19bbd57fdafd6a90420fadf32"
const ARCHIVE:="b9535405853a5cd16e4bba968ec7167222861c42"
const MAX_BYTES:=8*1024*1024
const MAX_MAPS:=70
const MAX_SOURCE_TAG_CHARS:=512
const COUNTS:={"maps":70,"current_protected_features":27,"immutable_feature_states":76,"comparative_families":12,"negative_interventions":5,"owner_accepted":0}

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"zero_writes":true,"native_module_import":false}

static func _hex(value: Variant, count: int) -> bool:
	return Design._hex(value,count)

static func _source_tags(value: Variant) -> bool:
	# The identified source export retains descriptive source-authored tags,
	# including a 272-character observation. They are not campaign identifiers.
	if not value is Array or value.size()>128: return false
	for item: Variant in value:
		if not Campaign._text(item,MAX_SOURCE_TAG_CHARS): return false
	return true

static func load_identified(path: String, identity: Dictionary) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return _fail("The explicitly selected local knowledge export could not be read.")
	if file.get_length()>MAX_BYTES: file.close(); return _fail("Read-only export exceeds eight MiB.")
	var bytes:=file.get_buffer(file.get_length()); file.close()
	return inspect_bytes(bytes,identity)

static func inspect_bytes(bytes: PackedByteArray, identity: Dictionary) -> Dictionary:
	if bytes.size()>MAX_BYTES or identity.get("repository")!="techrote/sandmapsreference" or not _hex(identity.get("commit"),40) \
		or identity.get("path")!="corpus-export/knowledge.v1.json" or not _hex(identity.get("sha256"),64):
		return _fail("Consumer requires an exact host-acquired repository commit, export path and SHA-256 identity.")
	if Compiler.digest(bytes)!=identity.sha256: return _fail("Knowledge export bytes differ from the acquired immutable identity.")
	var parser:=JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary: return _fail("Knowledge export is not a bounded valid JSON object.")
	var value: Dictionary=parser.data
	if value.get("schema_version")!=EXPORT_SCHEMA or value.get("version")!=1: return _fail("Unknown knowledge export version; no automatic schema or authority promotion is allowed.")
	var authority: Variant=value.get("authority")
	if not authority is Dictionary or authority.get("kind")!="reference_knowledge_only" or authority.get("execution_authority")!=false or authority.get("owner_accepted")!=false \
		or authority.get("repository")!="techrote/sandmapsreference" or authority.get("archival_commit")!=ARCHIVE or authority.get("scientific_evidence_commit")!=EVIDENCE:
		return _fail("Export does not preserve the separate frozen knowledge and owner/execution authority boundaries.")
	if not value.get("counts") is Dictionary: return _fail("Export lacks its frozen population counts.")
	for key: String in COUNTS:
		if value.counts.get(key)!=COUNTS[key]: return _fail("Frozen knowledge population changed: "+key)
	for key: String in ["maps","protected_features","immutable_feature_states","comparative_families","negative_interventions","module_candidates"]:
		if not value.get(key) is Array: return _fail("Export collection is malformed: "+key)
	if value.maps.size()!=70 or value.protected_features.size()!=27 or value.immutable_feature_states.size()!=76 or value.comparative_families.size()!=12 or value.negative_interventions.size()!=5 or value.module_candidates.size()!=27:
		return _fail("Export arrays do not match the immutable research populations.")
	var compatibility: Variant=value.get("consumer_compatibility")
	if not compatibility is Dictionary or compatibility.get("cards_sha256")!=Design.CORPUS_SHA256: return _fail("Existing 25-card consumer identity is missing or changed.")
	var coordinates: Variant=value.get("coordinate_convention")
	if not coordinates is Dictionary or coordinates.get("evidence_windows_are_edit_masks")!=false or coordinates.get("x")!="right" or coordinates.get("y")!="down":
		return _fail("Source coordinates or evidence-window authority is unsupported.")
	var holdout: Variant=value.get("holdout_policy")
	if not holdout is Dictionary or holdout.get("preserve_visual_family_groups")!=true or not holdout.get("consumer_sealed_families") is Array \
		or holdout.consumer_sealed_families!=["bioindustrial","civic","vessel_dock"]:
		return _fail("The export must preserve the existing sealed-family boundaries.")
	var rows: Array=[]; var ids: Array=[]; var source_prs: Array=[]
	for map: Variant in value.maps:
		if not map is Dictionary or not Campaign._text(map.get("id"),256) or map.id in ids or not Campaign._text(map.get("title"),1024) \
			or not map.get("source") is Dictionary or not map.get("material_plane") is Dictionary or map.get("owner_accepted")!=false:
			return _fail("Malformed source map or implied owner adoption in reference export.")
		if not _hex(map.source.get("commit"),40) or not _hex(map.source.get("sha256"),64) or not Campaign._integer(map.source.get("pr"),1,10000000) \
			or int(map.source.pr) in source_prs or not _hex(map.material_plane.get("plane_sha256"),64): return _fail("Source map identity is not exact and distinct.")
		var extent: Variant=map.material_plane.get("extent")
		if not extent is Array or extent.size()!=2 or not Campaign._integer(extent[0],1,2048) or not Campaign._integer(extent[1],1,2048): return _fail("Source map extent is unsupported.")
		if not Campaign._strings(map.get("visual_family_groups"),32) or not _source_tags(map.get("tags",[])): return _fail("Source map family ancestry or tags are malformed.")
		if not Campaign._text(map.get("architectural_family"),256) or not map.get("native",{}) is Dictionary: return _fail("Source map interpretation or historical qualification record is malformed.")
		if int(map.source.pr) in [155,183] and (map.native.get("eligibility")!="refused" or map.native.get("status")!="REFUSED_INVALID_SOURCE"):
			return _fail("Original #155/#183 source refusals must remain explicit; policy-only descendants are separate identities.")
		ids.append(map.id); source_prs.append(int(map.source.pr))
		rows.append({"id":map.id,"title":map.title,"source":map.source.duplicate(true),"source_static_plane":map.material_plane.duplicate(true),
			"architectural_family":map.architectural_family,"visual_family_groups":map.visual_family_groups.duplicate(),"tags":map.get("tags",[]).duplicate(),
			"topology":map.get("topology",[]),"historical_native_record":map.get("native",{}).duplicate(true),"owner_accepted":false,"native_module_import":false,
			"qualification_scope":"Historical source/engine evidence only. A separately identified current-delivery overlay and fresh World harvest are distinct actions."})
	if 155 not in source_prs or 183 not in source_prs: return _fail("Frozen recovered-source inventory must retain both original native-refused map identities.")
	for candidate: Variant in value.module_candidates:
		if not candidate is Dictionary or candidate.get("geometry_included")!=false or candidate.get("native_module_import_eligible")!=false or candidate.get("owner_accepted")!=false \
			or not candidate.get("attachments") is Array or not candidate.attachments.is_empty(): return _fail("Semantic feature hints cannot silently become native geometry, sockets or owner-approved modules.")
	return {"ok":true,"format":VIEW_SCHEMA,"identity":identity.duplicate(true),"authority":authority.duplicate(true),"counts":COUNTS.duplicate(),
		"primary_policy_schema_population":67,"existing_cards_sha256":Design.CORPUS_SHA256,"maps":rows,
		"semantic_module_hints":value.module_candidates.duplicate(true),"protected_features":value.protected_features.duplicate(true),
		"sealed_families":holdout.consumer_sealed_families.duplicate(),"source_coordinate_convention":coordinates.duplicate(true),
		"original_refusals_preserved":[155,183],"zero_writes":true,"native_module_import":false,"current_delivery_overlay_applied":false,
		"scope":"Expanded knowledge is a separate read-only browsing population; it is never automatically added to the frozen 25-card retrieval or experimental cohorts."}

static func browse(view: Dictionary, query: Dictionary) -> Dictionary:
	if view.get("format")!=VIEW_SCHEMA or view.get("ok")!=true or not view.get("maps") is Array: return _fail("A validated identified read-only view is required.")
	if not Campaign._text(query.get("text",""),4096,true) or not Campaign._integer(query.get("limit",3),1,5) \
		or not Campaign._strings(query.get("excluded_families",[]),32) or not Campaign._strings(query.get("excluded_visual_family_groups",[]),128): return _fail("Read-only browsing query is invalid or unbounded.")
	var terms:=Design._tokens(str(query.get("text",""))); var results: Array=[]
	for row: Dictionary in view.maps:
		if row.architectural_family in query.get("excluded_families",[]): continue
		if row.visual_family_groups.any(func(group: String) -> bool:return group in query.get("excluded_visual_family_groups",[])): continue
		var searchable:=Design._tokens(str(row.title)+" "+str(row.architectural_family)+" "+" ".join(row.tags)); var score:=0
		for term: String in terms:
			if term in searchable: score+=1
		if score==0 and not terms.is_empty(): continue
		results.append({"score":score,"id":row.id,"title":row.title,"source":row.source.duplicate(true),"architectural_family":row.architectural_family,
			"visual_family_groups":row.visual_family_groups.duplicate(),"source_static_plane":row.source_static_plane.duplicate(true),"native_module_import":false,"owner_accepted":false})
	results.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return str(a.id)<str(b.id) if a.score==b.score else a.score>b.score)
	return {"ok":true,"results":results.slice(0,int(query.get("limit",3))),"candidate_count":results.size(),"identity":view.identity.duplicate(true),
		"zero_writes":true,"native_module_import":false,"scope":"Separate expanded-reference browsing. Exclusions match exact exported family strings and ancestry groups; no automatic cross-taxonomy holdout equivalence or frozen-retrieval admission is asserted."}

static func widen_source_static_plane(bytes: PackedByteArray, extent: Vector2i, expected_sha256: String) -> Dictionary:
	if extent.x<1 or extent.y<1 or extent.x>2048 or extent.y>2048 or bytes.size()!=extent.x*extent.y or Compiler.digest(bytes)!=expected_sha256:
		return _fail("Source-static uint8 plane must retain exact extent, byte count and identity before widening.")
	var native_width:=PackedByteArray(); native_width.resize(bytes.size()*2)
	for index: int in bytes.size(): native_width.encode_u16(index*2,int(bytes[index]))
	return {"ok":true,"source_encoding":"row-major-uint8","source_sha256":expected_sha256,"derived_encoding":"row-major-u16le","derived_sha256":Compiler.digest(native_width),
		"cells":native_width,"extent":[extent.x,extent.y],"zero_writes":true,"native_module_import":false,"native_readback_verified":false,
		"scope":"Lossless integer-width conversion of source-static bytes only. Native World admission, execution and current-process harvest remain unperformed."}
