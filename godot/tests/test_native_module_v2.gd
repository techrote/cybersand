extends SceneTree
## Independent scalar and adversarial fixture tests. These copied synthetic
## planes are not native execution evidence; the catalogue harness is separate.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Connections = preload("res://scripts/batch_lab/native_module_connections.gd")
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> bool:
	checks += 1
	print("NATIVE_MODULE_V2_CHECK ",label," ",value)
	if not value: failures.append(label); push_error(label)
	return value

func connector(identity: String, point: Array, end: Array, facing: Array, policy := "full", minimum := 0, capacity := 1, required := true) -> Dictionary:
	var length := absi(int(end[0])-int(point[0]))+absi(int(end[1])-int(point[1]))+1
	return {"id":identity,"kind":"line","point":point,"end":end,"facing":facing,"compatibility":["bearing"],
		"required":required,"source":"authored","role":"support","approach":"face","polarity":"neutral","capacity":capacity,
		"contact":{"policy":policy,"minimum_cells":length if minimum==0 else minimum,"tolerance":0}}

func fixture(identity: String, width: int, height: int, attachments: Array, metadata: Dictionary = {}) -> Dictionary:
	var cells := PackedByteArray(); cells.resize(width*height*2)
	for index: int in width*height: cells.encode_u16(index*2,58)
	var details := metadata.duplicate(true)
	details.merge({"format":Module.FORMAT_V2,"id":identity,"name":identity,"attachments":attachments,
		"allowed_transforms":Module.TRANSFORMS,"provenance":{"kind":"synthetic-module-v2-fixture","native_status":"not-executed"}},true)
	var harvested := Module.harvest(cells,Vector2i(width,height),Rect2i(0,0,width,height),details)
	check(harvested.ok,"fixture validates "+identity+" "+str(harvested.get("reason","")))
	return harvested.get("module",{})

func context(region := Rect2i(0,0,64,64)) -> Dictionary:
	var bytes := PackedByteArray(); bytes.resize(region.get_area()*2)
	return {"region":Module._array_rect(region),"projected_cells":bytes,"allowed_materials":[7,28,58],"protected":[],"max_cells":262144}

func placed(module: Dictionary, origin: Array, instance: Variant, ctx: Dictionary, transform := "identity") -> Dictionary:
	var compiled := Module.compile(module,{"origin":origin,"transform":transform},ctx)
	check(compiled.ok,"compile fixture "+module.id+" "+str(instance)+" "+transform)
	if not compiled.ok: return compiled
	var region := Module.rect(ctx.region)
	for offset: int in range(0,compiled.cells.size(),3):
		var x: int = compiled.cells[offset]-region.position.x
		var y: int = compiled.cells[offset+1]-region.position.y
		ctx.projected_cells.encode_u16((y*region.size.x+x)*2,compiled.cells[offset+2])
	for value: Dictionary in compiled.connections: value["module_instance"] = instance
	return compiled

func binding(a: Variant, a_id: String, b: Variant, b_id: String) -> Dictionary:
	return {"a":{"instance":a,"connector":a_id},"b":{"instance":b,"connector":b_id}}

func reseal(module: Dictionary) -> Dictionary:
	module.content_sha256 = Module.content_digest(module)
	return module

func _initialize() -> void:
	_test_versions_and_metadata()
	_test_full_contact_and_transforms()
	_test_capacity_and_ambiguity()
	_test_retained_capacity()
	_test_snap_and_bounds()
	print("NATIVE_MODULE_V2_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"scope":"Pure bounded synthetic fixtures and scalar oracles; no native application, physics or owner acceptance."}))
	quit(0 if failures.is_empty() else 1)

func _test_versions_and_metadata() -> void:
	var legacy_cells := PackedByteArray([58,0,28,0,0,0,7,0])
	var legacy := Module.harvest(legacy_cells,Vector2i(2,2),Rect2i(0,0,2,2),{"id":"legacy","name":"Legacy exact bytes"})
	check(legacy.ok and legacy.module.format==Module.FORMAT and not legacy.module.has("fixed_regions"),"v1 harvest shape remains unchanged")
	var original := Module.json_bytes(legacy.module)
	var reopened := Module.validate(JSON.parse_string(original.get_string_from_utf8()))
	check(reopened.ok and Module.json_bytes(reopened.module)==original and reopened.cells==legacy_cells,"v1 canonical roundtrip preserves bytes and content identity")
	var library := Library.new()
	check(library.add(legacy.module).ok,"legacy library adoption")
	var patch := {"format":Module.FORMAT_V2,"fixed_regions":[[0,0,1,1]],"name":"Authored semantic revision"}
	var draft := library.draft_metadata("legacy",legacy.module.content_sha256,patch)
	check(draft.ok and library.get_module("legacy").content_sha256==legacy.module.content_sha256,"v2 upgrade stays a zero-write metadata draft")
	check(draft.ok and draft.module.geometry==legacy.module.geometry and draft.module.provenance==legacy.module.provenance,"metadata draft preserves exact geometry and provenance")
	check(library.commit_metadata("legacy",legacy.module.content_sha256,draft.module).ok,"explicit upgrade commits checked metadata")
	check(not library.commit_metadata("legacy",legacy.module.content_sha256,draft.module).ok,"stale expected metadata hash refuses")
	var current := library.get_module("legacy")
	check(not library.draft_metadata("legacy",current.content_sha256,{"geometry":{}}).ok,"draft cannot edit geometry")
	check(not library.draft_metadata("legacy",current.content_sha256,{"provenance":{"native_status":"accepted"}}).ok,"draft cannot invent native provenance")
	check(not library.draft_metadata("legacy",current.content_sha256,{"format":Module.FORMAT}).ok,"v2 contracts cannot silently downgrade")
	check(not library.draft_metadata("legacy",current.content_sha256,{"variation_regions":[[0,0,1,1]]}).ok,"variable and fixed geometry cannot overlap")
	var forged := current.duplicate(true); forged.provenance["owner_accepted"] = true; reseal(forged)
	check(not library.commit_metadata("legacy",current.content_sha256,forged).ok,"commit rechecks immutable provenance instead of trusting draft origin")
	var summaries := library.summaries(); summaries[0].name = "Caller mutation"
	check(library.summaries()[0].name==current.name and not library.summaries()[0].native_readback_verified,"cached summaries are detached and imported geometry remains unqualified")
	var roles := [{"name":"structure","material_ids":[58],"compatible_materials":[58,28],"source":"authored"}]
	var role_draft := library.draft_metadata("legacy",current.content_sha256,{"roles":roles})
	check(role_draft.ok,"explicit authored compatible palette remains editable")
	var roles_bad := roles.duplicate(true); roles_bad[0].source = "observed"
	check(not library.draft_metadata("legacy",current.content_sha256,{"roles":roles_bad}).ok,"material semantic roles cannot masquerade as observed facts")
	var huge := fixture("bounded",2,4,[connector("east",[1,0],[1,3],[1,0])])
	for field: String in ["capacity","role","approach","polarity"]:
		var malformed := huge.duplicate(true)
		match field:
			"capacity": malformed.attachments[0][field] = 17
			"role": malformed.attachments[0][field] = ""
			"approach": malformed.attachments[0][field] = "diagonal"
			"polarity": malformed.attachments[0][field] = "any"
		check(not Module.validate(reseal(malformed)).ok,"invalid v2 "+field+" refuses")
	var bad := huge.duplicate(true); bad.attachments[0].contact.tolerance = 1
	check(not Module.validate(reseal(bad)).ok,"nonzero tolerance refuses")
	bad = huge.duplicate(true); bad.attachments[0].contact.minimum_cells = 3
	check(not Module.validate(reseal(bad)).ok,"full policy cannot use a partial minimum")
	bad = huge.duplicate(true); bad.attachments[0].facing = [0,1]
	check(not Module.validate(reseal(bad)).ok,"line tangent cannot masquerade as outward face")
	bad = huge.duplicate(true); bad.attachments[0].point = [0,0]; bad.attachments[0].end = [0,3]
	check(not Module.validate(reseal(bad)).ok,"connector buried behind own material refuses")
	bad = huge.duplicate(true); bad.attachments[0].source = "inferred"
	check(not Module.validate(reseal(bad)).ok,"inferred connector cannot become required")
	var broken_cells := Marshalls.base64_to_raw(huge.geometry.cells_base64); broken_cells.encode_u16((2*2+1)*2,0)
	bad = huge.duplicate(true); bad.geometry.cells_base64 = Marshalls.raw_to_base64(broken_cells); bad.geometry.sha256 = Module.digest(broken_cells)
	check(not Module.validate(reseal(bad)).ok,"empty cell inside exact declared face refuses")
	bad = huge.duplicate(true); var alias: Dictionary = bad.attachments[0].duplicate(true); alias.id = "second-name"; bad.attachments.append(alias)
	check(not Module.validate(reseal(bad)).ok,"different IDs cannot alias one physical outward face")
	var corner := huge.duplicate(true); corner.attachments.append(connector("top",[0,0],[1,0],[0,-1]))
	check(Module.validate(reseal(corner)).ok,"perpendicular corner faces remain distinct physical contacts")

func _test_full_contact_and_transforms() -> void:
	var a := fixture("full-a",2,4,[connector("east",[1,0],[1,3],[1,0])])
	var b := fixture("full-b",2,4,[connector("west",[0,0],[0,3],[-1,0])])
	var ctx := context(); var pa := placed(a,[10,10],"left",ctx); var pb := placed(b,[12,10],"right",ctx)
	var baseline: PackedByteArray = ctx.projected_cells.duplicate()
	var joined := Connections.resolve(pa.connections+pb.connections,[],ctx)
	check(joined.ok and joined.contacts.size()==1 and joined.contacts[0].cell_count==4,"required full lines uniquely pair four occupied adjacent faces")
	check(ctx.projected_cells==baseline,"connection resolution does not change supplied bytes")
	var reversed := a.duplicate(true); reversed.attachments[0].point = [1,3]; reversed.attachments[0].end = [1,0]; reseal(reversed)
	var copy := Module.json_bytes(reversed)
	var reversed_ctx := context(); var reverse_part := placed(reversed,[10,10],"left",reversed_ctx); var right_part := placed(b,[12,10],"right",reversed_ctx)
	check(Connections.resolve(reverse_part.connections+right_part.connections,[],reversed_ctx).ok,"reversed source endpoints normalize only for matching")
	check(Module.json_bytes(reversed)==copy and reversed.content_sha256!=a.content_sha256,"reversed endpoint order retains its own manifest identity")
	var transforms := {
		"identity":[[1,0],[1,3],[1,0]],"mirror_x":[[0,0],[0,3],[-1,0]],"mirror_y":[[1,3],[1,0],[1,0]],
		"rotate_90":[[3,1],[0,1],[0,1]],"rotate_180":[[0,3],[0,0],[-1,0]],"rotate_270":[[0,0],[3,0],[0,-1]]}
	for transform: String in transforms:
		var compiled := Module.compile(a,{"origin":[0,0],"transform":transform},context())
		var expected: Array = transforms[transform]
		check(compiled.ok and compiled.connections[0].point==expected[0] and compiled.connections[0].end==expected[1] and compiled.connections[0].facing==expected[2],"independent line transform scalar oracle "+transform)
	var gap_ctx := context(); var gap_a := placed(a,[10,10],0,gap_ctx); var gap_b := placed(b,[13,10],1,gap_ctx)
	check(not Connections.resolve(gap_a.connections+gap_b.connections,[],gap_ctx).ok,"one-cell gap refuses full line mating")
	var shifted_ctx := context(); var shifted_a := placed(a,[10,10],0,shifted_ctx); var shifted_b := placed(b,[12,11],1,shifted_ctx)
	check(not Connections.resolve(shifted_a.connections+shifted_b.connections,[],shifted_ctx).ok,"three-of-four overlap does not satisfy a full line")
	var odd := fixture("odd-five",2,5,[connector("west",[0,0],[0,4],[-1,0])])
	var odd_ctx := context(); var odd_a := placed(a,[10,10],0,odd_ctx); var odd_b := placed(odd,[12,10],1,odd_ctx)
	check(not Connections.resolve(odd_a.connections+odd_b.connections,[],odd_ctx).ok,"odd and even full spans cannot silently truncate")
	var negative_ctx := context(Rect2i(-16,-16,64,64)); var neg_a := placed(a,[-10,-10],0,negative_ctx); var neg_b := placed(b,[-8,-10],1,negative_ctx)
	check(Connections.resolve(neg_a.connections+neg_b.connections,[],negative_ctx).ok,"negative offsets use the supplied region origin exactly")
	var damaged := ctx.duplicate(true); damaged.projected_cells = ctx.projected_cells.duplicate(); damaged.projected_cells.encode_u16((11*64+11)*2,0)
	check(not Connections.resolve(pa.connections+pb.connections,[],damaged).ok,"later projection cannot erase a grounded contact")
	var forged: Array = pa.connections.duplicate(true); forged[0].own_contact_cells.pop_back()
	check(not Connections.resolve(forged+pb.connections,[],ctx).ok,"incomplete own-geometry contact evidence refuses")
	check(not Connections.resolve(pa.connections+pb.connections,[binding("left","east","left","east")],ctx).ok,"self binding refuses")
	check(not Connections.resolve(pa.connections+pb.connections,[binding("unknown","east","right","west")],ctx).ok,"unknown placed instance refuses")
	check(not Connections.resolve(pa.connections+pa.connections,[],ctx).ok,"duplicate instance connector descriptor refuses")
	var wrong_role: Array = pb.connections.duplicate(true); wrong_role[0].role = "pipe"
	check(not Connections.resolve(pa.connections+wrong_role,[],ctx).ok,"same tag does not override incompatible functional role")
	var legacy_line: Array = pa.connections.duplicate(true); legacy_line[0].module_format = Module.FORMAT
	check(not Connections.resolve(legacy_line+pb.connections,[],ctx).ok,"v1 required line remains an explicit refusal")

func _test_capacity_and_ambiguity() -> void:
	var rail := fixture("rail",2,12,[connector("rail",[1,0],[1,11],[1,0],"overlap",3,2)])
	var pad := fixture("pad",2,3,[connector("pad",[0,0],[0,2],[-1,0],"overlap",3,1,false)])
	var ctx := context(); var rail_part := placed(rail,[10,10],"rail",ctx); var one := placed(pad,[12,10],"one",ctx); var two := placed(pad,[12,16],"two",ctx)
	var graph: Array = rail_part.connections+one.connections+two.connections
	var ambiguous := Connections.resolve(graph,[],ctx)
	check(not ambiguous.ok and ambiguous.code=="ambiguous_partner","two eligible partial partners need explicit owner binding")
	var bindings := [binding("rail","rail","one","pad"),binding("rail","rail","two","pad")]
	var joined := Connections.resolve(graph,bindings,ctx)
	check(joined.ok and joined.contacts.size()==2 and joined.contacts[0].cell_count==3,"two distinct nonoverlapping partners fit a two-slot rail")
	var rail_row: Dictionary = {}
	if joined.ok:
		for item: Dictionary in joined.occupancy:
			if item.connector.instance=="rail": rail_row = item
	check(rail_row.get("used_partners")==2 and rail_row.get("reserved_contact_cells")==6,"logical capacity and booked contact cells reported independently")
	var limited: Array = graph.duplicate(true); limited[0].capacity = 1
	var exhausted := Connections.resolve(limited,bindings,ctx)
	check(not exhausted.ok and exhausted.code=="capacity_exhausted","one-slot receptor cannot accept a second partner")
	var overlap_ctx := context(); var overlap_rail := placed(rail,[10,10],"rail",overlap_ctx); var overlap_a := placed(pad,[12,10],"one",overlap_ctx); var overlap_b := placed(pad,[12,12],"two",overlap_ctx)
	var overlap := Connections.resolve(overlap_rail.connections+overlap_a.connections+overlap_b.connections,bindings,overlap_ctx)
	check(not overlap.ok and overlap.code in ["contact_occupied","aliased_face"],"capacity does not authorize overlapping exclusive contact intervals")
	check(not Connections.resolve(graph,[bindings[0],bindings[0]],ctx).ok,"duplicate pair does not consume an invented second capacity slot")
	var aliases: Array = graph.duplicate(true); var alias: Dictionary = aliases[0].duplicate(true); alias.id = "rail-alias"; aliases.append(alias)
	var alias_result := Connections.resolve(aliases,[bindings[0],binding("rail","rail-alias","two","pad")],ctx)
	check(not alias_result.ok and alias_result.code=="aliased_face","transformed aliases cannot bypass capacity through different connector IDs")
	aliases = graph.duplicate(true); alias = aliases[0].duplicate(true); alias.module_instance = "duplicate-rail-instance"; aliases.append(alias)
	alias_result = Connections.resolve(aliases,[bindings[0],binding("duplicate-rail-instance","rail","two","pad")],ctx)
	check(not alias_result.ok and alias_result.code=="aliased_face","duplicated placed instances cannot reuse one world-coordinate outward face")
	var prior := ctx.duplicate(true); prior.existing_bindings = [bindings[0]]
	check(Connections.resolve(graph,[bindings[1]],prior).ok,"existing reservations are rederived from currently inspected contacts")
	var stale_prior := ctx.duplicate(true); stale_prior.existing_bindings = [binding("gone","rail","one","pad")]
	check(not Connections.resolve(graph,[],stale_prior).ok,"stale reservation cannot refer to uninspected geometry")
	var cross_version: Array = graph.duplicate(true); cross_version[1].module_format = Module.FORMAT
	check(not Connections.resolve(cross_version,[bindings[0]],ctx).ok,"mixed contract versions need an explicit adapter")

func _test_snap_and_bounds() -> void:
	var rail := fixture("snap-rail",2,12,[connector("rail",[1,0],[1,11],[1,0],"overlap",3,2)])
	var pad := fixture("snap-pad",2,3,[connector("pad",[0,0],[0,2],[-1,0],"overlap",3)])
	var ctx := context(); var target: Dictionary = placed(rail,[10,10],"rail",ctx).connections[0]
	ctx["preferred_origin"] = [12,16]; ctx["limit"] = 1; ctx["transforms"] = ["identity"]
	var before: PackedByteArray = ctx.projected_cells.duplicate()
	var snaps := Connections.snap_candidates(pad,"pad",target,ctx)
	check(snaps.ok and snaps.status=="found" and snaps.candidates[0].placement=={"origin":[12,16],"transform":"identity"},"snap selects the exact nearest integer fitting pose")
	check(ctx.projected_cells==before,"snap compilation is zero-write")
	check(snaps.candidates[0].contact.cell_count==3 and snaps.candidates[0].budget.unique_cells==6,"snap returns actual contact and compiled native cell budget")
	var repeated := Connections.snap_candidates(pad,"pad",target,ctx)
	check(Module.json_bytes(snaps)==Module.json_bytes(repeated),"snap ordering and evidence are deterministic")
	var guarded := ctx.duplicate(true); guarded.protected = [[12,10,2,12]]
	var no_fit := Connections.snap_candidates(pad,"pad",target,guarded)
	check(not no_fit.ok and no_fit.status=="refused" and not no_fit.truncated,"complete bounded no-fit search is a refusal")
	guarded.search_budget = 1
	var spent := Connections.snap_candidates(pad,"pad",target,guarded)
	check(not spent.ok and spent.status=="exhausted" and spent.considered==1 and spent.truncated,"search exhaustion is distinct from a proven bounded no-fit")
	var clearance := ctx.duplicate(true); clearance.clearances = [[12,10,2,12]]
	check(not Connections.snap_candidates(pad,"pad",target,clearance).ok,"required empty host clearance cannot be filled by snap")
	var collision := ctx.duplicate(true); collision.projected_cells = before.duplicate()
	for y: int in range(10,22):
		for x: int in [12,13]: collision.projected_cells.encode_u16((y*64+x)*2,58)
	check(not Connections.snap_candidates(pad,"pad",target,collision).ok,"snap does not hide geometry overlap behind allowed Hard wall replacement")
	var malformed := ctx.duplicate(true); malformed.search_budget = 2049
	check(not Connections.snap_candidates(pad,"pad",target,malformed).ok,"unbounded snap work refuses")
	malformed = ctx.duplicate(true); malformed.transforms = ["identity","identity"]
	check(not Connections.snap_candidates(pad,"pad",target,malformed).ok,"duplicate transform enumeration refuses")
	malformed = ctx.duplicate(true); malformed.source_instance = "rail"
	check(not Connections.snap_candidates(pad,"pad",target,malformed).ok,"snap cannot reuse target instance identity")
	var bad_target := target.duplicate(true); bad_target.point = [1,1]
	check(not Connections.snap_candidates(pad,"pad",bad_target,ctx).ok,"tampered target span refuses")
	var prior_ctx := ctx.duplicate(true); prior_ctx.projected_cells = before.duplicate()
	var old := placed(pad,[12,10],"old",prior_ctx)
	prior_ctx.existing_connectors = [target]+old.connections
	prior_ctx.bindings = [binding("rail","rail","old","pad")]
	prior_ctx.preferred_origin = [12,10]
	var available := Connections.snap_candidates(pad,"pad",target,prior_ctx)
	check(available.ok and available.candidates[0].placement.origin==[12,13],"snapping respects existing occupied interval and moves to next finite free span")
	var full_target := target.duplicate(true); full_target.capacity = 1
	var booked_ctx := prior_ctx.duplicate(true); booked_ctx.existing_connectors = [full_target]; booked_ctx.bindings = []
	var initial := Connections.resolve([target]+old.connections,[binding("rail","rail","old","pad")],prior_ctx)
	booked_ctx.reserved_contacts = initial.contacts
	var retired_slot := Connections.snap_candidates(pad,"pad",full_target,booked_ctx)
	check(not retired_slot.ok and retired_slot.reasons.any(func(reason: String) -> bool: return reason.contains("capacity")),"snap filters retained capacity even when old partner descriptor is omitted")

func _test_retained_capacity() -> void:
	var rail := fixture("retained-rail",2,12,[connector("rail",[1,0],[1,11],[1,0],"overlap",3,2,false)])
	var pad := fixture("retained-pad",2,3,[connector("pad",[0,0],[0,2],[-1,0],"overlap",3,1,false)])
	var ctx := context(); var r := placed(rail,[10,10],"rail",ctx); var a := placed(pad,[12,10],"old",ctx)
	var b := placed(pad,[12,14],"new-one",ctx); var c := placed(pad,[12,18],"new-two",ctx)
	var retained := Connections.resolve(r.connections+a.connections,[binding("rail","rail","old","pad")],ctx)
	var current := Connections.resolve(r.connections+b.connections+c.connections,
		[binding("rail","rail","new-one","pad"),binding("rail","rail","new-two","pad")],ctx)
	check(retained.ok and current.ok,"each separately bounded old/new contact cohort is valid")
	var combined := Connections.check_reserved_contacts(current.contacts,r.connections+b.connections+c.connections,retained.contacts)
	check(not combined.ok and combined.code=="capacity_exhausted","retained one plus new two cannot exceed capacity two")
	var one_new: Array = [current.contacts[0]]
	check(Connections.check_reserved_contacts(one_new,r.connections+b.connections,retained.contacts).ok,"one retained and one new distinct partner fit capacity two")
	check(Connections.check_reserved_contacts(retained.contacts,r.connections+a.connections,retained.contacts).ok,"exact retained contact reinspection is idempotent")
	var reversed: Dictionary = retained.contacts[0].duplicate(true)
	var old_a: Dictionary = reversed.a; var old_cells: Array = reversed.a_cells
	reversed.a = reversed.b; reversed.b = old_a; reversed.a_cells = reversed.b_cells; reversed.b_cells = old_cells
	check(Connections.check_reserved_contacts([reversed],r.connections+a.connections,retained.contacts).ok,"reverse endpoint order does not consume a duplicate reservation")
	var alias: Dictionary = retained.contacts[0].duplicate(true); alias.a.instance = "renamed-rail"; alias.b.instance = "renamed-pad"
	var renamed: Array = r.connections.duplicate(true)+a.connections.duplicate(true)
	renamed[0].module_instance = "renamed-rail"; renamed[1].module_instance = "renamed-pad"
	var reused := Connections.check_reserved_contacts([alias],renamed,retained.contacts)
	check(not reused.ok and reused.code=="contact_occupied","renamed placed instances cannot reuse retained physical world faces")
	var changed: Dictionary = retained.contacts[0].duplicate(true)
	changed.a_cells = [[11,11],[11,12],[11,13]]; changed.b_cells = [[12,11],[12,12],[12,13]]
	var shifted := Connections.check_reserved_contacts([changed],r.connections+a.connections,retained.contacts)
	check(not shifted.ok and shifted.code=="binding_changed","same partner pair cannot silently slide its retained contact interval")
	var malformed: Dictionary = retained.contacts[0].duplicate(true); malformed.b_cells[1] = [13,11]
	check(not Connections.check_reserved_contacts([],r.connections+a.connections,[malformed]).ok,"malformed retained nonadjacent faces refuse")
	malformed = retained.contacts[0].duplicate(true); malformed.a_cells[1] = malformed.a_cells[0].duplicate()
	check(not Connections.check_reserved_contacts([],r.connections+a.connections,[malformed]).ok,"retained duplicate contact cells refuse")
	var outside: Array = retained.contacts.duplicate(true)
	check(Connections.check_reserved_contacts([],[],outside).ok,"historical reservation can remain conservative outside current descriptor inventory")
