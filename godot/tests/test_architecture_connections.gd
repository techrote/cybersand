extends SceneTree
## Copied material fixtures exercise host compilation and runtime inventory.
## Native application and receipt witnesses are qualified separately.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const Library = preload("res://scripts/batch_lab/native_module_library.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Session = preload("res://scripts/batch_lab/architecture_stage_session.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks+=1
	print("ARCHITECTURE_CONNECTION_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)

func part(identity: String, east: bool, required: bool) -> Dictionary:
	var cells:=PackedByteArray(); cells.resize(4*8*2)
	for index: int in 32: cells.encode_u16(index*2,58)
	var x:=3 if east else 0
	var connector:={"id":"face","kind":"line","point":[x,0],"end":[x,7],"facing":[1 if east else -1,0],
		"compatibility":["bearing"],"required":required,"source":"authored","role":"support","approach":"face",
		"polarity":"neutral","capacity":1,"contact":{"policy":"full","minimum_cells":8,"tolerance":0}}
	var harvested:=Module.harvest(cells,Vector2i(4,8),Rect2i(0,0,4,8),{"format":Module.FORMAT_V2,"id":identity,
		"name":identity,"attachments":[connector],"allowed_transforms":Module.TRANSFORMS,
		"provenance":{"kind":"copied-fixture","native_status":"not-executed"}})
	check(harvested.ok,"fixture "+identity)
	return harvested.module

func context() -> Dictionary:
	var cells:=PackedByteArray(); cells.resize(32*32*2)
	return {"region":[100,100,32,32],"world_region":[0,0,256,256],"source_cells":cells,
		"source_sha256":Compiler.digest(cells),"generation":5,"paused":true,"allowed_materials":[0,28,58]}

func stage(identity: String,module: Dictionary,origin: Array,instance: String) -> Dictionary:
	var value:=Compiler.stage_defaults(identity,Rect2i(100,100,32,32))
	value.materials=[0,28,58]
	value.modules=[{"module_id":module.id,"module_sha256":module.content_sha256,"instance_id":instance,"placement":{"origin":origin}}]
	return value

func _initialize() -> void:
	var library:=Library.new()
	var pier:=part("fixture-pier",true,false)
	var beam:=part("fixture-beam",false,true)
	check(library.add(pier).ok and library.add(beam).ok,"fixture library")
	var source:=context()
	var first:=Compiler.compile(stage("pier",pier,[108,108],"pier-one"),source,library)
	check(first.ok,"standalone optional bearing compiles / "+str(first.get("reason","")))
	if not first.ok: quit(1); return
	check(first.placed_module_connections[0].module_instance=="pier-one","explicit placed identity retained")
	check(first.resolved_modules[0].instance_id=="pier-one","module recipe retains placed identity")
	var session:=Session.new(); session.library=library
	session._execution={"stage_id":"pier","preview_sha256":first.preview_sha256,"placed_module_connections":first.placed_module_connections,"module_contact_result":first.module_contact_result}
	var captured:={"region":source.region,"source_cells":first.projected_cells,"generation":5}
	session._retain_placed_connections(captured)
	var inventory: Dictionary=session._connection_context(captured)
	check(inventory.existing_module_connections.size()==1,"only runtime observed fixture contact enters inventory")
	check(inventory.existing_module_connections[0].original_required==false,"original authored semantics retained")
	check(inventory.existing_module_connections[0].contact_materials.size()==8,"each exact contact material retained")
	var next:=source.duplicate(true)
	next.source_cells=first.projected_cells.duplicate(); next.source_sha256=Compiler.digest(next.source_cells)
	next.merge(inventory)
	var proposal:=stage("beam",beam,[112,108],"beam-one")
	proposal.module_bindings=[{"a":{"instance":"beam-one","connector":"face"},"b":{"instance":"pier-one","connector":"face"}}]
	var second:=Compiler.compile(proposal,next,library)
	check(second.ok,"required full line binds a fresh module to rechecked prior geometry")
	if second.ok:
		check(second.module_contact_result.contacts.size()==1 and second.module_contact_result.contacts[0].cell_count==8,"actual full inclusive contact count")
		check(second.budget.checked_cells==32,"existing native part contributes no fabricated new work")
		check(second.placed_module_connections.size()==1 and second.module_connections.size()==2,"new declarations separated from existing contacts")
		check(source.source_cells!=second.projected_cells and source.source_cells==context().source_cells,"all compilation remains zero-write")
		var retained: Array=second.module_contact_result.contacts.duplicate(true)
		var reused:=next.duplicate(true); reused.reserved_module_contacts=retained
		var duplicate:=proposal.duplicate(true); duplicate.modules[0].instance_id="beam-two"; duplicate.module_bindings[0].a.instance="beam-two"
		check(not Compiler.compile(duplicate,reused,library).ok,"existing contact interval cannot be reused under a new partner identity")
		var same:=Compiler.compile(proposal,reused,library)
		check(same.ok,"same exact recorded binding is idempotent for recovery")
	var gap:=proposal.duplicate(true); gap.modules[0].placement.origin=[113,108]
	check(not Compiler.compile(gap,next,library).ok,"one-cell empty gap refuses exact line contact")
	var shortened:=proposal.duplicate(true); shortened.modules[0].placement.origin=[112,109]
	check(not Compiler.compile(shortened,next,library).ok,"partial overlap cannot satisfy full line")
	var missing:=proposal.duplicate(true); missing.module_bindings[0].b.instance="not-live"
	check(not Compiler.compile(missing,next,library).ok,"unobserved target identity cannot be invented")
	var protected_source:=next.duplicate(true); protected_source.protected=[[112,108,1,1]]
	check(not Compiler.compile(proposal,protected_source,library).ok,"connection cannot expand native edit permissions")
	var changed:=captured.duplicate(true); changed.source_cells=changed.source_cells.duplicate(); changed.source_cells.encode_u16((8*32+11)*2,28)
	check(session._connection_context(changed).existing_module_connections.is_empty(),"changed contact material invalidates prior declared target")
	changed=captured.duplicate(true); changed.generation=6
	check(session._connection_context(changed).existing_module_connections.is_empty(),"World replacement invalidates contact inventory")
	var edited:=pier.duplicate(true); edited.name="Edited metadata"; edited.content_sha256=Module.content_digest(edited)
	check(library.add(edited,true).ok,"explicit fixture metadata replacement")
	check(session._connection_context(captured).existing_module_connections.is_empty(),"stale module metadata cannot remain a current target")
	check(session.connection_targets().get("ok",true)==false,"public target chooser requires a fresh host inspection")
	session.free()
	print("ARCHITECTURE_CONNECTIONS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
