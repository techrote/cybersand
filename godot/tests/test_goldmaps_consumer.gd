extends SceneTree
const Consumer=preload("res://scripts/batch_lab/goldmaps_consumer.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Design=preload("res://scripts/batch_lab/architectural_retrieval.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
	checks+=1; print("GOLDMAPS_CONSUMER_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
func fixture() -> Dictionary:
	# Synthetic schema fixture, explicitly not recovered source or new evidence.
	var value: Dictionary={"schema_version":Consumer.EXPORT_SCHEMA,"version":1,"authority":{"kind":"reference_knowledge_only","execution_authority":false,"owner_accepted":false,"repository":"techrote/sandmapsreference","archival_commit":Consumer.ARCHIVE,"scientific_evidence_commit":Consumer.EVIDENCE},
		"counts":Consumer.COUNTS.duplicate(),"maps":[],"protected_features":[],"immutable_feature_states":[],"comparative_families":[],"negative_interventions":[],"module_candidates":[],
		"consumer_compatibility":{"cards_sha256":Design.CORPUS_SHA256},"coordinate_convention":{"x":"right","y":"down","evidence_windows_are_edit_masks":false},
		"holdout_policy":{"preserve_visual_family_groups":true,"consumer_sealed_families":["bioindustrial","civic","vessel_dock"]}}
	for index: int in 70:
		value.maps.append({"id":"fixture-"+str(index),"title":"Synthetic structural fixture "+str(index),"source":{"commit":"1".repeat(40),"sha256":str(index).sha256_text(),"pr":183 if index==69 else index+100},
			"material_plane":{"plane_sha256":("plane-"+str(index)).sha256_text(),"extent":[64,64]},"owner_accepted":false,"architectural_family":"civic" if index%2==0 else "linear_industry","visual_family_groups":["fixture-group-"+str(index/2)],"tags":["fixture","structural"],"native":{"status":"REFUSED_INVALID_SOURCE" if index==55 or index==69 else "SYNTHETIC_NOT_EVIDENCE","eligibility":"refused" if index==55 or index==69 else "fixture"}})
	for _index: int in 27:
		value.protected_features.append({"fixture":true})
		value.module_candidates.append({"geometry_included":false,"native_module_import_eligible":false,"owner_accepted":false,"attachments":[]})
	for _index: int in 76:value.immutable_feature_states.append({"fixture":true})
	for _index: int in 12:value.comparative_families.append({"fixture":true})
	for _index: int in 5:value.negative_interventions.append({"fixture":true})
	return value
func inspect(value: Dictionary) -> Dictionary:
	var bytes:=Compiler.canonical(value).to_utf8_buffer()
	return Consumer.inspect_bytes(bytes,{"repository":"techrote/sandmapsreference","commit":"2".repeat(40),"path":"corpus-export/knowledge.v1.json","sha256":Compiler.digest(bytes),"fixture":true})
func _initialize() -> void:
	var view:=inspect(fixture())
	check(view.ok and view.counts.maps==70 and view.primary_policy_schema_population==67,"separate source and policy/schema populations retained "+str(view.get("reason","")))
	if not view.ok: quit(1); return
	check(not view.native_module_import and not view.current_delivery_overlay_applied and view.original_refusals_preserved==[155,183],"reference consumer grants neither native import nor fresh delivery admission")
	check(not Design.validate_corpus(view).ok,"expanded reference view cannot masquerade as frozen design-card corpus")
	var browsed:=Consumer.browse(view,{"text":"structural","excluded_families":["civic"],"excluded_visual_family_groups":["fixture-group-0"],"limit":3})
	check(browsed.ok and browsed.results.size()==3 and browsed.results.all(func(row: Dictionary)->bool:return row.architectural_family!="civic" and "fixture-group-0" not in row.visual_family_groups),"explicit family and donor-group exclusions preserved in bounded browsing")
	var changed:=fixture(); changed.version=2
	check(not inspect(changed).ok,"unrecognized export version is refused")
	changed=fixture(); changed.authority.execution_authority=true
	check(not inspect(changed).ok,"export cannot promote reference knowledge into execution authority")
	changed=fixture(); changed.authority.owner_accepted=true
	check(not inspect(changed).ok,"Gold recommendation cannot invent owner acceptance")
	changed=fixture(); changed.counts.maps=67
	check(not inspect(changed).ok,"70/67 population conflation refused")
	changed=fixture(); changed.consumer_compatibility.cards_sha256="0".repeat(64)
	check(not inspect(changed).ok,"changed consumer cards require deliberate new versioned intake")
	changed=fixture(); changed.module_candidates[0].native_module_import_eligible=true
	check(not inspect(changed).ok,"inferred feature hints cannot become qualified module programs")
	changed=fixture(); changed.module_candidates[0].attachments=[{"invented":"socket"}]
	check(not inspect(changed).ok,"unknown source sockets remain unknown")
	changed=fixture(); changed.coordinate_convention.evidence_windows_are_edit_masks=true
	check(not inspect(changed).ok,"evidence crop is not an edit mask")
	changed=fixture(); changed.maps[0].owner_accepted=true
	check(not inspect(changed).ok,"per-map acceptance cannot be inferred")
	changed=fixture(); changed.maps[55].native.status="passed"
	check(not inspect(changed).ok,"original refused source cannot be promoted through metadata")
	var bytes:=PackedByteArray([0,1,58,255]); var widened:=Consumer.widen_source_static_plane(bytes,Vector2i(2,2),Compiler.digest(bytes))
	check(widened.ok and widened.cells==PackedByteArray([0,0,1,0,58,0,255,0]),"uint8 source bytes widen losslessly to explicit LE16")
	check(widened.source_sha256!=widened.derived_sha256 and not widened.native_readback_verified,"source and derived plane hashes retain separate authority")
	check(not Consumer.widen_source_static_plane(bytes,Vector2i(2,2),"0".repeat(64)).ok,"unbound source plane refused before conversion")
	print("GOLDMAPS_READ_ONLY_CONSUMER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
