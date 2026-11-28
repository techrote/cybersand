extends SceneTree
const Retriever=preload("res://scripts/batch_lab/architecture_compositional_retrieval.gd")
const Catalogue=preload("res://scripts/batch_lab/native_module_catalogue.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
	checks+=1; print("COMPOSITION_RETRIEVAL_CHECK ",label," ",value)
	if not value: failures+=1; push_error(label)
func query() -> Dictionary:
	return {"format":Retriever.FORMAT,"id":"development-arch-bay","text":"curved arch enclosing useful negative space","region":[0,0,192,96],"max_native_cells":16384,
		"require_native_geometry":false,"slots":[{"id":"span","region":[8,8,96,64],"part_types":["beam_truss"],"preferred_tags":["arch","curved"],"target_extent":[96,52]}],
		"reference_query":{"topologies":["open_span"],"required_parts":["beam_truss"],"excluded_families":["bioindustrial","civic","vessel_dock"]}}
func project(result: Dictionary, library: RefCounted) -> Dictionary:
	var stage:=Compiler.stage_defaults("composition",Rect2i(0,0,192,96)); stage.materials=[0,7,28,58]
	for part: Dictionary in result.placements: stage.modules.append({"module_id":part.module_id,"module_sha256":part.module_sha256,"placement":part.placement})
	var cells:=PackedByteArray(); cells.resize(192*96*2)
	return Compiler.compile(stage,{"region":[0,0,192,96],"world_region":[0,0,192,96],"source_cells":cells,"source_sha256":Compiler.digest(cells),"generation":1,"paused":true,"allowed_materials":[0,7,28,58]},library)
func _initialize() -> void:
	var built:=Catalogue.template_library(); check(built.ok,"forty code-owned recipe templates load without native qualification")
	var summaries: Array=built.library.summaries()
	check(summaries.size()==40 and summaries.all(func(value: Dictionary) -> bool:return not value.native_readback_verified),"template corpus never self-certifies native observation")
	var arch:=Retriever.retrieve(query(),summaries)
	check(arch.ok and arch.placements[0].module_id=="parabolic-arch-rib","curved macro-void intent selects actual arch geometry")
	check(arch.context_text.length()<=12000 and arch.context_pack.references.size()<=3,"small relevant context is bounded")
	check(arch.context_pack.references.all(func(value: Dictionary) -> bool:return value.architectural_family not in ["bioindustrial","civic","vessel_dock"]),"excluded reference families never leak into context")
	var altered:=query(); altered.text="repeated deep lattice structural span"; altered.slots[0].preferred_tags=["truss","repetition"]; altered.slots[0].target_extent=[96,32]
	var lattice:=Retriever.retrieve(altered,summaries)
	check(lattice.ok and lattice.placements[0].module_id=="alternating-lattice-truss","different motif and scale selects a distinct native recipe identity")
	var arch_plane:=project(arch,built.library); var lattice_plane:=project(lattice,built.library)
	check(arch_plane.ok and lattice_plane.ok,"selected part proposals compile through existing native stage compiler: "+str(arch_plane.get("reason",""))+" / "+str(lattice_plane.get("reason","")))
	check(arch_plane.get("projected_sha256","")!=lattice_plane.get("projected_sha256",""),"retrieval choice changes downstream material geometry rather than metadata only")
	check(not arch.placements[0].native_readback_verified,"pure development output remains unqualified geometry")
	altered=query(); altered.require_native_geometry=true
	check(Retriever.retrieve(altered,summaries).status=="no-fit","unqualified imported/code recipe does not satisfy native requirement")
	altered=query(); altered.slots[0].required_tags=["arch"]; altered.slots[0].region=[8,8,95,64]
	check(Retriever.retrieve(altered,summaries).status=="no-fit","almost fitting scale is a hard negative")
	altered=query(); altered.slots[0].required_tags=["nonexistent-visual-family"]
	check(Retriever.retrieve(altered,summaries).status=="no-fit","unknown motif fails explicitly")
	altered=query(); altered.slots[0].connection_types=["pipe-4"]
	check(Retriever.retrieve(altered,summaries).status=="no-fit","incompatible service connector is a hard negative for a beam slot")
	altered=query(); altered.max_native_cells=1
	check(Retriever.retrieve(altered,summaries).status=="no-fit","bounded conservative geometric cost refuses insufficient resources")
	altered=query(); altered.search_budget=1; altered.slots.append({"id":"other","region":[112,8,64,64],"part_types":["column_support"]})
	check(Retriever.retrieve(altered,summaries).status=="exhausted","finite search distinguishes exhaustion from proof of no fit")
	altered=query(); altered.context_chars=1500
	check(Retriever.retrieve(altered,summaries).status=="context-no-fit","minimum useful context never silently becomes empty")
	var cells:=PackedByteArray(); cells.resize(192*96*2)
	for y: int in 96:
		for x: int in 192: cells.encode_u16((y*192+x)*2,58)
	check(Retriever.retrieve(query(),summaries,{}, {"region":[0,0,192,96],"cells":cells,"source_sha256":Compiler.digest(cells)}).status=="no-fit","observed occupied negative-space boxes reject all candidate placements")
	altered=query(); altered.protected=[[0,0,192,96]]
	check(Retriever.retrieve(altered,summaries).status=="no-fit","empty but protected composition boxes are not placement opportunities")
	var malformed: Array=summaries.duplicate(true); malformed[0].connectors=[{"id":"broken","contact":7}]
	check(not Retriever.retrieve(query(),malformed).ok,"malformed caller connector metadata refuses without crashing")
	altered=query(); altered.id="paired-cellular-decks"; altered.text="paired cellular decks"; altered.max_native_cells=10000
	altered.slots=[{"id":"west","region":[0,0,96,32],"part_types":["beam_truss"],"required_tags":["cellular"],"target_extent":[96,24],"connector_contract":"face-adjacent-grid-v2"},
		{"id":"east","region":[96,0,96,32],"part_types":["beam_truss"],"required_tags":["cellular"],"target_extent":[96,24],"connector_contract":"face-adjacent-grid-v2"}]
	altered.relations=[{"kind":"face-contact","a":"west","b":"east","role":"floor","compatibility":"deck-4"}]
	var connected:=Retriever.retrieve(altered,summaries)
	check(connected.ok and connected.contacts.size()==1 and connected.contacts[0].declared_adjacent_cells==4,"joint selection checks declared adjacent connector spans")
	altered.slots[1].region=[96,1,96,32]
	check(Retriever.retrieve(altered,summaries).status=="no-fit","one-cell offset cannot claim full-span connector compatibility")
	altered.slots[1].region=[96,0,96,32]; altered.relations.append(altered.relations[0].duplicate())
	check(Retriever.retrieve(altered,summaries).status=="no-fit","exclusive declared connector cannot satisfy duplicated reservations")
	print("ARCHITECTURE_COMPOSITIONAL_RETRIEVAL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
