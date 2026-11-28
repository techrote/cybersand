extends SceneTree
## Run with isolated user data: actual archive writes, deliberately foreign
## chains and aliases. No model transport or native drawing is simulated.
const Provider=preload("res://scripts/art_provider.gd")
const Archive=preload("res://scripts/art_traffic_archive.gd")
var checks:=0
var failures:Array[String]=[]
var nodes:Array[Node]=[]
var symlinks_tested:=false
var evidence:=""
func _initialize() -> void: run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	print("NAMESPACE_CONTRACT_CHECK ",checks," ",label," ",value)
	if not value:failures.append(label)
func provider(directory:String="user://art-traffic")->Node:
	var value:=Provider.new();value.traffic_directory=directory;root.add_child(value);nodes.append(value);return value
func write(path:String,value:String)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(value);file.close()
func line(kind:String,data:Dictionary)->String:return JSON.stringify({"kind":kind,"data":data})+"\n"
func resolve(path:String)->bool:
	var archive:=Archive.new();return archive.resolve(path)
func run()->void:
	evidence=OS.get_environment("BATCH_LAB_EVIDENCE_DIR")
	if not evidence.is_empty():DirAccess.make_dir_recursive_absolute(evidence)
	for directory:String in Archive.TRAFFIC_DIRECTORIES:DirAccess.make_dir_recursive_absolute(directory)
	for path:String in ["user://art-traffic/../batch-lab-traffic/a.jsonl","user://batch-lab-traffic/../art-traffic/a.jsonl", "user://batch-lab-traffic/sub/a.jsonl","user://batch-lab-traffic//a.jsonl","user://batch-lab-traffic/./a.jsonl","user://batch-lab-traffic/a.jsonl/..","user://batch-lab-traffic\\a.jsonl","user://other/a.jsonl","res://art-traffic/a.jsonl","/tmp/art-traffic/a.jsonl","user://batch-lab-traffic/a.json","user://batch-lab-traffic/.."]:
		check(not Archive.valid_path(path),"non-direct/unknown path refused: "+path)
	check(Archive.valid_path("user://art-traffic/a.jsonl") and Archive.valid_path("user://batch-lab-traffic/a.jsonl"),"archive recognises two exact direct-child roots")
	check(Provider.valid_traffic_path("user://art-traffic/a.jsonl") and not Provider.valid_traffic_path("user://batch-lab-traffic/a.jsonl"),"ordinary static profile/history validator excludes Batch")
	var ordinary:=provider()
	var batch:=provider("user://batch-lab-traffic")
	check(ordinary.log_event("probe",{"value":"same-size namespace probe"}) and batch.log_event("probe",{"value":"same-size namespace probe"}),"both actual writers create bounded own-root archives")
	var ordinary_path:String=ordinary.log_path;var batch_path:String=batch.log_path
	var ordinary_hash:=FileAccess.get_sha256(ordinary_path);var batch_hash:=FileAccess.get_sha256(batch_path)
	var ordinary_reader:=provider();var batch_reader:=provider("user://batch-lab-traffic")
	check(ordinary_reader.begin_resume(batch_path)!=OK and ordinary_reader.parent_log_path!=batch_path,"ordinary resume rejects Batch source without binding")
	check(batch_reader.begin_resume(ordinary_path)!=OK and batch_reader.parent_log_path!=ordinary_path,"Batch resume rejects ordinary source without binding")
	check(ordinary_reader.traffic_chain(batch_path).is_empty() and batch_reader.traffic_chain(ordinary_path).is_empty(),"instance chain walk rejects foreign namespace")
	ordinary_reader.parent_log_path=batch_path
	check(not ordinary_reader.log_event("probe",{}),"forced ordinary parent cannot append a Batch-derived child")
	batch_reader.parent_log_path=ordinary_path
	check(not batch_reader.log_event("probe",{}),"forced Batch parent cannot append an ordinary-derived child")
	check(ordinary_reader.begin_export("user://foreign-ordinary.jsonl")!=OK and batch_reader.begin_export("user://foreign-batch.jsonl")!=OK,"instance export rejects foreign source binding")
	var invalid:=provider("user://arbitrary-traffic")
	check(not invalid.traffic_namespace_valid() and invalid.new_log_path().is_empty() and not invalid.log_event("probe",{}),"unknown traffic root cannot create or append")
	for directory:String in Archive.TRAFFIC_DIRECTORIES:
		var own_path:=ordinary_path if directory=="user://art-traffic" else batch_path
		var foreign_path:=batch_path if directory=="user://art-traffic" else ordinary_path
		var mixed:=directory.path_join("mixed-legacy.jsonl")
		write(mixed,line("session_parent",{"path":foreign_path}))
		check(not resolve(mixed),"legacy chain cannot cross namespace from "+directory)
		var parent:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(foreign_path).get_slice("\n",0))
		var file:=FileAccess.open(foreign_path,FileAccess.READ);var length:=file.get_length();file.close()
		write(mixed,JSON.stringify({"kind":"session_parent","schema":2,"segment_id":Crypto.new().generate_random_bytes(16).hex_encode(),"data":{"path":foreign_path,"parent_id":parent.segment_id,"parent_bytes":length,"parent_sha256":FileAccess.get_sha256(foreign_path)}})+"\n")
		check(not resolve(mixed),"sealed modern chain cannot cross namespace from "+directory)
		var child:=provider(directory)
		child.resume_traffic(own_path)
		check(child.resume_ok and child.log_event("probe",{"continued":true}),"same-root continuation remains supported: "+directory)
		check(child.traffic_chain(child.log_path).size()==2,"same-root chain resolves two source-bound segments: "+directory)
		var destination:="user://"+directory.get_file()+"-export.jsonl"
		check(child.export_traffic(destination)==OK and FileAccess.get_file_as_string(destination)==FileAccess.get_file_as_string(own_path)+FileAccess.get_file_as_string(child.log_path),"same-root atomic export preserves exact linked bytes: "+directory)
		DirAccess.remove_absolute(mixed)
	check(FileAccess.get_sha256(ordinary_path)==ordinary_hash and FileAccess.get_sha256(batch_path)==batch_hash,"namespace failures and valid descendants preserve original archives")
	# Test leaf aliases in both directions; these fixtures are in isolated data.
	var batch_alias:="user://batch-lab-traffic/ordinary-leaf-alias.jsonl"
	var ordinary_alias:="user://art-traffic/batch-leaf-alias.jsonl"
	var directory:=DirAccess.open("user://batch-lab-traffic")
	var linked:=directory.create_link(ProjectSettings.globalize_path(ordinary_path),ProjectSettings.globalize_path(batch_alias))
	if linked==OK:
		symlinks_tested=true
		check(not batch._valid_writer_path(batch_alias) and not resolve(batch_alias),"Batch leaf alias cannot bind ordinary source")
		directory=DirAccess.open("user://art-traffic")
		check(directory.create_link(ProjectSettings.globalize_path(batch_path),ProjectSettings.globalize_path(ordinary_alias))==OK,"symmetric leaf alias fixture created")
		check(not ordinary._valid_writer_path(ordinary_alias) and not resolve(ordinary_alias),"ordinary leaf alias cannot bind Batch source")
		DirAccess.remove_absolute(batch_alias);DirAccess.remove_absolute(ordinary_alias)
		var same_root_alias:="user://batch-lab-traffic/other-batch-leaf-alias.jsonl"
		directory=DirAccess.open("user://batch-lab-traffic")
		check(directory.create_link(ProjectSettings.globalize_path(batch_path),ProjectSettings.globalize_path(same_root_alias))==OK,"same-root Batch alias fixture created")
		check(not batch._valid_writer_path(same_root_alias) and not resolve(same_root_alias),"one Batch trace cannot alias another tile trace")
		DirAccess.remove_absolute(same_root_alias)
		# A valid ordinary fixture uses a different segment ID but exactly the
		# current Batch writer's byte length. Length-only append guards used to
		# admit this cross-root alias and modify the ordinary archive.
		var raw:=FileAccess.get_file_as_string(batch_path)
		var victim:="user://art-traffic/namespace-alias-victim.jsonl"
		write(victim,raw.replace(str(batch._segment_id),"c".repeat(32)))
		var victim_hash:=FileAccess.get_sha256(victim)
		DirAccess.remove_absolute(batch_path)
		check(directory.create_link(ProjectSettings.globalize_path(victim),ProjectSettings.globalize_path(batch_path))==OK,"same-size foreign append fixture created")
		check(not batch.log_event("probe",{"value":"append after alias"}),"existing Batch writer refuses append through same-size ordinary alias")
		check(FileAccess.get_sha256(victim)==victim_hash,"refused aliased append preserves ordinary archive bytes")
		DirAccess.remove_absolute(batch_path);write(batch_path,raw)
	else:print("NAMESPACE_SYMLINK_UNAVAILABLE ",linked)
	# Changing a writer's root after it starts must not adopt its old file.
	batch.traffic_directory="user://art-traffic"
	check(not batch.log_event("probe",{}) and batch.begin_export("user://changed-root-export.jsonl")!=OK,"active writer cannot switch namespace and adopt its previous trace")
	check(FileAccess.get_sha256(ordinary_path)==ordinary_hash and FileAccess.get_sha256(batch_path)==batch_hash,"rejected root switching preserves both archives")
	for node:Node in nodes:node.queue_free()
	await process_frame
	var summary:={"checks":checks,"failures":failures,"symlinks_tested":symlinks_tested,"actual_model_calls":0,"scope":"real local archive writes, resume and export; no model transport"}
	print("BATCH_NAMESPACE_CONTRACT ",JSON.stringify(summary))
	if not evidence.is_empty():write(evidence.path_join("namespace-summary.json"),JSON.stringify(summary,"\t"))
	quit(0 if failures.is_empty() else 1)
