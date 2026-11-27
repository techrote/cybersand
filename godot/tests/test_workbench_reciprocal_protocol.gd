extends SceneTree

# Transport/admission fixtures only. They do not represent generated architecture
# and never install a World or certify reciprocal construction.
const Protocol=preload("res://scripts/workbench_reciprocal_protocol.gd")
var checks:=0
var failures:Array[String]=[]
var path:="user://swarm004-protocol-test.json"
var prepared:Dictionary
var valid:Dictionary

const HISTORICAL_DEFINITIONS := [
	"57ff699bf5c9833a2a5e2198ff2ef0b07cfd051069013776e6427f1e9d6694ec",
	"12a4816dab749a9c872a4d531836db8ec6a170aab31576d70086efa80eeb3b6b",
	"fe62e15412459c22c6f81e479fa1ff2917d7359d747581c9891b83fbf2f75618",
	"217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7",
	"afbae85af2c44f1e539a154fbee622a3ee7533a6caab9ad1f9c5190a8e5803e4",
	"72779688b897e4707d89ac1f6e692046abbc806bd27b4c129bd77fcd995093a0"]

func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func write(value:Dictionary)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value));file.close()

func decode(value:Dictionary)->Dictionary:
	write(value)
	return Protocol.decode(path,prepared,"transport-fixture-no-assembly")

func saved_fixture(map_path:String,value:Dictionary,receipt_changes:Dictionary={})->Dictionary:
	var map_file:=FileAccess.open(map_path,FileAccess.WRITE)
	map_file.store_string("transport fixture only");map_file.close()
	var evidence_file:=FileAccess.open(map_path+".swarm004-evidence.json",FileAccess.WRITE)
	evidence_file.store_string(JSON.stringify(value));evidence_file.close()
	var evidence_sha:=FileAccess.get_sha256(map_path+".swarm004-evidence.json")
	var receipt:Dictionary={"schema":1,"map_sha256":FileAccess.get_sha256(map_path),"evidence_sha256":evidence_sha,
		"proposal_sha256":evidence_sha,"native_source":"transport-fixture-no-assembly","cli_sha256":"0".repeat(64)}
	receipt.merge(receipt_changes,true)
	var receipt_file:=FileAccess.open(map_path+".swarm004.json",FileAccess.WRITE)
	receipt_file.store_string(JSON.stringify(receipt));receipt_file.close()
	return Protocol.load_saved(map_path)

func historical_fixture(definition:String)->Dictionary:
	var value:Dictionary=valid.duplicate(true)
	value.input.frame.definition="frameweaver.frontier-growth-v0."+definition
	value.input.mosaic.definition="mosaic.prepared-regions-v0."+definition
	return value

func saved_hashes(map_path:String)->Array[String]:
	var hashes:Array[String]=[]
	for suffix:String in ["",".swarm004.json",".swarm004-evidence.json"]:
		hashes.append(FileAccess.get_sha256(map_path+suffix))
	return hashes

func _initialize()->void:
	var extent:=Vector2i(16,12)
	var bytes:=PackedByteArray();bytes.resize(extent.x*extent.y*2)
	bytes.encode_u16((3*extent.x+2)*2,13)
	var request:Dictionary={"size":Vector2i(8,4),"origin":Vector2i(2,3),"seed":59,"rounds":2,"shared_extent":2,
		"orientation":1,"profile":"industrial","optional":false,"activation":[Vector2i(2,1),Vector2i(6,2)],
		"parameters":{"variation":0.1,"irregularity":0.2,"clutter":0.3,"destruction":0.4,"branching":0.5,"environment_affinity":0.6,"cohesion":0.7},
		"protected":{Vector2i(3,3):true}}
	prepared=Protocol.prepare(request,{"extent":extent,"cells":bytes})
	check(prepared.ok,"finite request prepares from copied native materials")
	check(prepared.context[0]==13 and prepared.protected[1]==1,"exact Stone13 and protected void are retained independently")
	var lines:PackedStringArray=prepared.text.split("\n",false)
	check(lines[0]=="SWARM004 1" and lines[1]=="8 4 59 2 3 2 2 1","protocol seed geometry and bounds are exact")
	check(lines[3]=="0.10000000 0.20000000 0.30000000 0.40000000 0.50000000 0.60000000 0.70000000 0",
		"all seven controls and optional negotiation have independent exact fields")
	var v3:Dictionary=request.duplicate(true)
	v3["compact_native_termination"]=true
	v3["supported_native_receptors"]=true
	var trial:=Protocol.prepare(v3,{"extent":extent,"cells":bytes})
	check(trial.ok and trial.text.begins_with("SWARM005 3\n") and "\n1 1\n" in trial.text,
		"SWARM-005 V3 adds exact opt-in native switches without changing V1/V2")
	var v4:Dictionary=v3.duplicate(true)
	v4["negotiated_recovery"]=true
	var recovery_trial:=Protocol.prepare(v4,{"extent":extent,"cells":bytes})
	check(recovery_trial.ok and recovery_trial.text.begins_with("SWARM006 4\n") and "\n1 1 1\n" in recovery_trial.text,
		"SWARM-006 V4 carries the explicit recovery policy independently of V3")
	v4["negotiated_recovery"]=false
	check(Protocol.prepare(v4,{"extent":extent,"cells":bytes}).text==trial.text,
		"recovery OFF preserves byte-for-byte V3 transport")
	var recovery_only:Dictionary=request.duplicate(true);recovery_only["negotiated_recovery"]=true
	var recovery_only_trial:=Protocol.prepare(recovery_only,{"extent":extent,"cells":bytes})
	check(recovery_only_trial.ok and "\n0 0 1\n" in recovery_only_trial.text,
		"V4 preserves independent SWARM-005 switches when recovery alone is selected")
	for invalid:Variant in [1,"true",null]:
		recovery_only["negotiated_recovery"]=invalid
		check(not Protocol.prepare(recovery_only,{"extent":extent,"cells":bytes}).ok,
			"nonboolean recovery request is rejected")
	var malformed_v3:Dictionary=v3.duplicate(true)
	malformed_v3["compact_native_termination"]=1
	check(not Protocol.prepare(malformed_v3,{"extent":extent,"cells":bytes}).ok,
		"malformed SWARM-005 source-time switch fails closed")
	malformed_v3=v3.duplicate(true)
	malformed_v3["supported_native_receptors"]="true"
	check(not Protocol.prepare(malformed_v3,{"extent":extent,"cells":bytes}).ok,
		"malformed SWARM-005 receptor switch fails closed")
	var frame:Array=[];var mosaic:Array=[]
	for at:int in 32:
		frame.append(int(at%8<4));mosaic.append(int(at%8>=4))
		check(int(prepared.shared[at])==int(at%8>=1 and at%8<=6),"shared mask counts distance from both facing interface cells")
	var no_shared:=Protocol.ownership_masks(Vector2i(8,4),"left_right",0,0)
	check(not 1 in no_shared.shared,"zero shared reach disables shared ownership")
	var horizontal:=Protocol.ownership_masks(Vector2i(8,8),"top_bottom",1,1)
	check(horizontal.frame[3*8+3]==1 and horizontal.mosaic[4*8+3]==1 and horizontal.frame[0]==0 and horizontal.mosaic[0]==0,
		"horizontal ownership and clear border are independently represented")
	check(horizontal.shared[2*8+3]==1 and horizontal.shared[5*8+3]==1 and horizontal.shared[1*8+3]==0,
		"shared reach follows the horizontal interface")
	var centred:=Protocol.ownership_masks(Vector2i(16,12),"centered_frame_rectangle",1,1)
	check(centred.frame[6*16+8]==1 and centred.mosaic[2*16+8]==1 and centred.frame[0]==0 and centred.mosaic[0]==0,
		"centred FRAME territory leaves native MOSAIC ownership around all sides")
	check(centred.shared[2*16+3]==1 and centred.shared[1*16+3]==0 and centred.shared[6*16+8]==0,
		"centred shared territory uses finite cardinal paths around corners")
	check(not Protocol.ownership_masks(Vector2i(8,8),"unbounded",0,1).ok,"unknown ownership layouts are refused")
	check(not Protocol.ownership_masks(Vector2i(8,8),"left_right",4,1).ok,"clear border cannot erase the activation territory")
	var input:Dictionary={"width":8,"height":4,"seed":59,"origin":[2,3],"source":"transport-fixture-no-assembly",
		"profile":request.parameters.duplicate(),"activation":[[2,1],[6,2]],"context":Array(prepared.context),
		"eligible":frame,"protected":Array(prepared.protected),"transition":Array(prepared.shared),
		"limits":Protocol.NATIVE_LIMITS.duplicate(),"neighbor_cells":[],"neighbors":{"hard":[],"soft":[],"protected":[],"transition":[]}}
	input.merge(Protocol.NATIVE_IDENTITIES.frame)
	input.profile["name"]="industrial"
	var other:Dictionary=input.duplicate(true);other.eligible=mosaic
	other.merge(Protocol.NATIVE_IDENTITIES.mosaic,true);other.limits.instances=192
	valid={"schema":5,"type":"reciprocal_assembly","source":"transport-fixture-no-assembly","can_apply":false,
		"status":"blocked","reason":"transport test, no architecture","stop_reason":"fixture","input":{"frame":input,"mosaic":other,
		"shared_zone":Array(prepared.shared),"options":{"rounds":2,"shared_extent":2,"orientation_preference":1,
		"optional_negotiation":false,"shared_ownership":true,"final_validation":true,
		"compact_native_termination":false,"supported_native_receptors":false}},"cells":[],"ledger":[],"ledger_columns":Protocol.LEDGER_COLUMNS,
		"rules":[],"rounds":[],"joints":[],"obligations":[],"owner_names":["empty","FRAMEWEAVER","MOSAIC","immutable_environment"]}
	for field:String in Protocol.NATIVE_SWITCHES:valid.input.options[field]=true
	var current_live:=decode(valid)
	check(current_live.ok and not current_live.historical_only,"well-formed current blocked evidence retains live decode semantics")
	var original_prepared:Dictionary=prepared
	prepared=recovery_only_trial
	var v4_evidence:Dictionary=valid.duplicate(true)
	v4_evidence.schema=6;v4_evidence["programme"]="GENTEK-SWARM-006";v4_evidence["identity"]="gentek_swarm_006_negotiated_recovery_v1"
	v4_evidence["metrics"]={"frame_work":0,"mosaic_work":0,"solver_work":0,"shared_work":0}
	v4_evidence.input.options["negotiated_recovery"]=true;v4_evidence.input.options["recovery_offers"]=true
	check(decode(v4_evidence).ok,"bounded blocked V4 native evidence admits exact requested recovery identity")
	# Original #705/#707/#710 evidence keeps its exact native identity. It may
	# be inspected, but cannot authorize a new candidate after the repair.
	var previous_recovery:Dictionary=v4_evidence.duplicate(true)
	previous_recovery.input.frame.definition="frameweaver.frontier-growth-v0.afbae85af2c44f1e539a154fbee622a3ee7533a6caab9ad1f9c5190a8e5803e4"
	previous_recovery.input.mosaic.definition="mosaic.prepared-regions-v0.afbae85af2c44f1e539a154fbee622a3ee7533a6caab9ad1f9c5190a8e5803e4"
	var previous_inspection:=Protocol.decode_document(previous_recovery,JSON.stringify(previous_recovery).to_utf8_buffer(),prepared,"transport-fixture-no-assembly",true)
	check(previous_inspection.ok and previous_inspection.get("historical_only",false),"original V4/schema6 receipts retain historical inspection compatibility")
	check(not decode(previous_recovery).ok,"original V4 definition cannot authorize the successor native candidate")
	for field:String in ["schema","programme","identity"]:
		var changed:Dictionary=v4_evidence.duplicate(true);changed[field]="forged"
		check(not decode(changed).ok,"V4 rejects a changed "+field)
	for field:String in ["negotiated_recovery","recovery_offers"]:
		var changed:Dictionary=v4_evidence.duplicate(true);changed.input.options[field]=false
		check(not decode(changed).ok,"V4 rejects a changed "+field)
	for field:String in ["frame_work","mosaic_work","solver_work","shared_work"]:
		var changed:Dictionary=v4_evidence.duplicate(true);changed.metrics[field]=4000001
		check(not decode(changed).ok,"V4 refuses a larger unreported "+field+" budget")
	# Exact empty native preflight receipt shape, captured from the frozen V4
	# maximum-size refusal. It is diagnostic evidence, never material authority.
	var refusal:Dictionary=v4_evidence.duplicate(true)
	refusal.status="exhausted";refusal.stop_reason="budget_exhaustion";refusal.reason="capacity: source admission"
	refusal["digest"]="0000000000000000";refusal["damage_derivative"]=null;refusal["rejections"]=[]
	refusal["original_frame"]=JSON.parse_string("{\"core\":{\"gentek\":\"FRAMEWEAVER\",\"implementation\":\"\",\"definition\":\"\",\"source\":\"\",\"seed\":0,\"status\":\"complete\",\"termination\":\"complete\",\"request_digest\":\"0000000000000000\",\"material_digest\":\"0000000000000000\",\"digest\":\"0000000000000000\",\"width\":0,\"height\":0,\"work\":0,\"candidates\":0,\"solver_work\":0,\"backtracks\":-1,\"protected_violations\":0,\"illegal_overlaps\":0,\"unresolved_joints\":0,\"metrics\":{},\"rejected\":{},\"notes\":[],\"cells\":[],\"roles\":[],\"provenance\":[],\"instances\":[],\"connectors\":[],\"attachments\":[],\"boundary\":{\"hard\":[],\"soft\":[],\"protected\":[],\"transition\":[]}},\"result\":{\"gentek\":\"FRAMEWEAVER\",\"implementation\":\"\",\"definition\":\"\",\"source\":\"\",\"seed\":0,\"status\":\"complete\",\"termination\":\"complete\",\"request_digest\":\"0000000000000000\",\"material_digest\":\"0000000000000000\",\"digest\":\"0000000000000000\",\"width\":0,\"height\":0,\"work\":0,\"candidates\":0,\"solver_work\":0,\"backtracks\":-1,\"protected_violations\":0,\"illegal_overlaps\":0,\"unresolved_joints\":0,\"metrics\":{},\"rejected\":{},\"notes\":[],\"cells\":[],\"roles\":[],\"provenance\":[],\"instances\":[],\"connectors\":[],\"attachments\":[],\"boundary\":{\"hard\":[],\"soft\":[],\"protected\":[],\"transition\":[]}},\"slots\":[],\"reservation_rejections\":[],\"source_feasibility\":[]}")
	refusal.metrics={"frame_work":0,"input_header_only":1,"total_charged_work":0}
	refusal.input.shared_zone=[]
	for gentek:String in ["frame","mosaic"]:
		for key:String in ["activation","eligible","protected","transition","context","neighbor_cells"]:refusal.input[gentek][key]=[]
	var header_refused:=decode(refusal)
	check(not header_refused.ok and header_refused.get("diagnostic_refusal",false) and header_refused.native_status=="exhausted" \
		and not header_refused.has("cells") and not header_refused.has("result") and "capacity: source admission" in header_refused.error,
		"exact V4 header refusal retains its budget reason without any Apply proposal")
	for field:String in ["can_apply","status","digest","source","cells","rounds","joints","obligations","owner_names","ledger_columns"]:
		var changed:Dictionary=refusal.duplicate(true)
		changed[field]=true if field=="can_apply" else ([1] if field in ["cells","rounds","joints","obligations"] else "forged")
		var denied:=decode(changed)
		check(not denied.ok and not denied.get("diagnostic_refusal",false),"header refusal cannot carry false authority: "+field)
	for field:String in ["input_header_only","frame_work","total_charged_work"]:
		var changed:Dictionary=refusal.duplicate(true);changed.metrics[field]=2
		var denied:=decode(changed)
		check(not denied.ok and not denied.get("diagnostic_refusal",false),"header refusal cannot forge work: "+field)
	for gentek:String in ["frame","mosaic"]:
		for field:String in ["source","definition","width","profile","limits","context","activation"]:
			var changed:Dictionary=refusal.duplicate(true);changed.input[gentek][field]=[1]
			var denied:=decode(changed)
			check(not denied.ok and not denied.get("diagnostic_refusal",false),"header refusal binds "+gentek+" "+field)
	var refusal_changed:Dictionary=refusal.duplicate(true);refusal_changed.original_frame.result.cells=[58]
	check(not decode(refusal_changed).get("diagnostic_refusal",false),"header refusal cannot invent a native result")
	refusal_changed=refusal.duplicate(true);refusal_changed.input.options.negotiated_recovery=false
	check(not decode(refusal_changed).get("diagnostic_refusal",false),"header refusal cannot replace requested recovery controls")
	refusal_changed=refusal.duplicate(true);refusal_changed.input=v4_evidence.input.duplicate(true)
	refusal_changed.metrics={"input_header_only":0,"frame_work":0,"shared_work":64,"total_charged_work":64,"conservative_memory_bound_bytes":18087936}
	check(decode(refusal_changed).get("diagnostic_refusal",false),"full-input memory refusal may omit untouched generation work counters")
	refusal_changed.input.frame.context=[]
	check(not decode(refusal_changed).get("diagnostic_refusal",false),"full-input refusal still requires every captured source mask")
	prepared=original_prepared
	check(not decode(v4_evidence).ok,"V4 evidence cannot replace a V1/V2 request with recovery OFF")
	var record:Dictionary={"number":1,"recovery_work":100,"recovery_frontier_exhausted":true,
		"recovery_frontier":[],"recovery_attempts":[],"mosaic_recovery_receipts":[]}
	check(Protocol.recovery_record(record,Vector2i(8,4)),"bounded empty recovery diagnostics remain distinct from joint proof")
	for field:String in ["recovery_work","recovery_frontier_exhausted","recovery_frontier","recovery_attempts","mosaic_recovery_receipts"]:
		var changed:Dictionary=record.duplicate(true);changed[field]="forged"
		check(not Protocol.recovery_record(changed,Vector2i(8,4)),"malformed recovery inspector field is rejected: "+field)
	var oversized:Dictionary=record.duplicate(true);oversized.recovery_work=2000001
	check(not Protocol.recovery_record(oversized,Vector2i(8,4)),"recovery diagnostics cannot exceed aggregate MOSAIC work")
	for field:String in ["recovery_frontier","mosaic_recovery_receipts"]:
		oversized=record.duplicate(true);oversized[field].resize(9)
		check(not Protocol.recovery_record(oversized,Vector2i(8,4)),"recovery diagnostics preserve eight-reservation capacity")
	var attempt:Dictionary={"slot":1,"connector":1,"source_instance":1,"host_instance":0,"round":1,"ordinal":0,
		"root":[2,1],"contact":[-1,1],"axis":[0,0],"length":0,"variant":0,"work":100,
		"phase":"receiver_bid","outcome":"rejected","reason":"unreachable_receiver_territory"}
	record.recovery_attempts=[attempt]
	check(Protocol.recovery_record(record,Vector2i(8,4)),"attempted out-of-crop receiver remains an honest rejected bid")
	oversized=record.duplicate(true);oversized.recovery_attempts[0].work=101
	check(not Protocol.recovery_record(oversized,Vector2i(8,4)),"attempt work cannot exceed its charged recovery work")
	for option: String in ["compact_native_termination","supported_native_receptors","negotiated_recovery"]:
		var forged:Dictionary=valid.duplicate(true)
		forged.input.options[option]=true
		check(not decode(forged).ok,"unrequested SWARM-005 native option "+option+" is rejected")
	for owner:String in ["frame","mosaic"]:
		for field:String in Protocol.NATIVE_IDENTITIES[owner]:
			var changed:Dictionary=valid.duplicate(true);changed.input[owner][field]=123
			check(not decode(changed).ok,"changed native "+owner+" "+field+" is refused")
		for field:String in Protocol.NATIVE_LIMITS:
			var changed:Dictionary=valid.duplicate(true);changed.input[owner].limits[field]+=1
			check(not decode(changed).ok,"increased native "+owner+" "+field+" ceiling is refused")
		var changed:Dictionary=valid.duplicate(true);changed.input[owner].neighbor_cells=[58]
		check(not decode(changed).ok,"unauthored initial "+owner+" neighbor materials are refused")
		for field:String in ["hard","soft","protected","transition"]:
			changed=valid.duplicate(true);changed.input[owner].neighbors[field]=[0]
			check(not decode(changed).ok,"unauthored initial "+owner+" neighbor "+field+" is refused")
	for field:String in Protocol.NATIVE_SWITCHES:
		var changed:Dictionary=valid.duplicate(true);changed.input.options[field]=false
		check(not decode(changed).ok,"changed native architectural switch "+field+" is refused")
	for field:String in ["seed","width","source"]:
		var bad:Dictionary=valid.duplicate(true);bad.input.frame[field]=123
		check(not decode(bad).ok,"mismatched request "+field+" is refused")
	for mask:String in ["eligible","protected","transition","context"]:
		var bad:Dictionary=valid.duplicate(true);bad.input.mosaic[mask][0]=42
		check(not decode(bad).ok,"changed source "+mask+" is refused")
	for parameter:String in Protocol.PARAMETERS:
		var bad:Dictionary=valid.duplicate(true);bad.input.frame.profile[parameter]=0.99
		check(not decode(bad).ok,"changed native parameter "+parameter+" is refused")
	for option:String in ["rounds","shared_extent","orientation_preference","optional_negotiation","shared_ownership","final_validation"]:
		var bad:Dictionary=valid.duplicate(true);bad.input.options[option]=99
		check(not decode(bad).ok,"changed negotiated option "+option+" is refused")
	var mismatched:Dictionary=valid.duplicate(true);mismatched.input.frame.activation[0]=[3,1]
	check(not decode(mismatched).ok,"changed activation distribution is refused")
	var illegal:Dictionary=request.duplicate(true);illegal.shared_extent=14
	check(not Protocol.prepare(illegal,{"extent":extent,"cells":bytes}).ok,"shared extent cannot exceed native bound")
	illegal=request.duplicate(true);illegal.size=Vector2i(257,4)
	check(not Protocol.prepare(illegal,{"extent":extent,"cells":bytes}).ok,"native crop dimensions remain bounded")
	illegal=request.duplicate(true);illegal.parameters.variation=NAN
	check(not Protocol.prepare(illegal,{"extent":extent,"cells":bytes}).ok,"nonfinite controls are refused")
	var forbidden:=bytes.duplicate();forbidden.encode_u16((3*extent.x+2)*2,10)
	check(not Protocol.prepare(request,{"extent":extent,"cells":forbidden}).ok,"reserved material10 is never relabeled")
	var false_apply:Dictionary=valid.duplicate(true);false_apply.can_apply=true;false_apply.status="complete"
	false_apply.cells=Array(prepared.context);false_apply.rules=["fixture-must-refuse"]
	for at:int in 32:false_apply.ledger.append([3,0,0,0,0,0] if at==0 else [0,0,0,0,0,0])
	false_apply.cells[2]=58;false_apply.ledger[2]=[1,1,0,0,0,1]
	var frame_result:Dictionary={"cells":[],"provenance":[]};var mosaic_result:Dictionary={"cells":[],"provenance":[]}
	for at:int in 32:
		frame_result.cells.append(58 if at==2 else 0);frame_result.provenance.append(1 if at==2 else 0)
		mosaic_result.cells.append(0);mosaic_result.provenance.append(0)
	false_apply.rounds=[{"number":0,"reason":"transport fixture","frame_accepted":true,"mosaic_accepted":true,
		"frame_changed":1,"mosaic_changed":0,"frame_work":1,"mosaic_work":1,"frame":{"result":frame_result,"slots":[]},
		"mosaic":{"result":mosaic_result},"proposed_frame":frame_result,"proposed_mosaic":mosaic_result}]
	false_apply.obligations=[{"state":"STILL_REQUIRED","connector":1,"reason":"a local cap cannot discharge a foreign-required socket",
		"original":[2,0],"foreign_joined":false,"local_terminated":true}]
	var refused:=decode(false_apply)
	check(not refused.ok and "unresolved mandatory" in refused.error,"well-formed mandatory obligation defeats claimed Apply permission even with a local cap")
	var malformed:Dictionary=false_apply.duplicate(true);malformed.obligations[0].original=17
	check(not decode(malformed).ok,"malformed obligation coordinates are refused before rendering")
	malformed=false_apply.duplicate(true);malformed.obligations[0].state="ASSUMED_JOINED"
	check(not decode(malformed).ok,"unknown obligation state cannot authorize Apply")
	malformed=false_apply.duplicate(true);malformed.rounds=[]
	check(not decode(malformed).ok,"final material cells require accepted native history")
	malformed=false_apply.duplicate(true);malformed.rounds[0].mosaic=17
	check(not decode(malformed).ok,"malformed accepted MOSAIC snapshot is refused")
	malformed=false_apply.duplicate(true);malformed.rounds[0].frame.result.cells[2]=0
	check(not decode(malformed).ok,"unbacked final material cannot enter the authored patch")
	malformed=false_apply.duplicate(true);malformed.cells[2]=0;malformed.ledger[2]=[0,0,0,0,0,0]
	malformed.cells[7]=58;malformed.ledger[7]=[1,1,0,0,0,1]
	check(not decode(malformed).ok,"foreign ordinary territory cannot be claimed through a false ledger")
	var inspection:Dictionary=false_apply.duplicate(true);inspection.can_apply=false;inspection.status="blocked"
	var required_socket:Dictionary={"id":7,"instance":1,"a":[2,0],"b":[2,1],"facing":[1,0],"family":"frame","required":true,
		"fulfilled":false,"counterpart":0,"state":"still_required"}
	var optional_socket:Dictionary=required_socket.duplicate(true);optional_socket.required=false;optional_socket.id=8;optional_socket.a=[6,2];optional_socket.b=[6,2]
	inspection.rounds[0].frame.result["connectors"]=[required_socket]
	inspection.rounds[0].proposed_frame=frame_result.duplicate(true);inspection.rounds[0].proposed_frame["connectors"]=[optional_socket]
	var local_socket:Dictionary={"id":9,"instance":1,"a":[4,2],"b":[4,2],"facing":[0,-1],"family":"frame","obligation":"local_terminable"}
	inspection.rounds[0].frame["constructions"]=[{"assembly":{"sockets":[local_socket]}}]
	var receptor:Dictionary={"id":10,"instance":2,"a":[5,3],"b":[5,3],"facing":[-1,0],"family":"frame","required":false}
	inspection.rounds[0].mosaic.result["boundary"]={"hard":[receptor]}
	check(decode(inspection).ok,"bounded native connector and assembly contracts are inspectable without granting Apply")
	var final_sockets:Array=Protocol.socket_records(inspection,-1)
	var proposal_sockets:Array=Protocol.socket_records(inspection,0)
	check(final_sockets.size()==3 and proposal_sockets.size()==1 and proposal_sockets[0].id==8,
		"provisional socket inspection never borrows accepted assembly certificates or receivers")
	var socket_pixels:PackedByteArray=Protocol.raster(inspection,prepared,-1,"Sockets / receptors")
	check(socket_pixels[2*4]==255 and socket_pixels[2*4+1]==104 \
		and socket_pixels[(2*8+4)*4]==105 and socket_pixels[(3*8+5)*4+1]==209,
		"required optional and local-terminable native contracts retain distinct diagnostic colors")
	check("still_required" in "\n".join(Protocol.inspect_sockets(inspection,-1,Vector2i(2,0))),
		"cell inspector reports actual native connector status and counterpart")
	for broken_field:String in ["facing","required","a","family"]:
		var broken:Dictionary=inspection.duplicate(true);broken.rounds[0].frame.result.connectors[0][broken_field]=17
		check(not decode(broken).ok,"malformed native socket "+broken_field+" is refused before rendering")
	var broken:Dictionary=inspection.duplicate(true);broken.rounds[0].frame.constructions[0].assembly.sockets[0].obligation="assumed_support"
	check(not decode(broken).ok,"unknown assembly obligation cannot enter diagnostic inspection")
	var independent_request:Dictionary=request.duplicate(true)
	independent_request["gentek_parameters"]={"frame":request.parameters.duplicate(),"mosaic":request.parameters.duplicate()}
	check(Protocol.prepare(independent_request,{"extent":extent,"cells":bytes}).text==prepared.text,
		"equal owner overrides preserve exact v1 transport bytes")
	independent_request.gentek_parameters.frame.branching=0.9
	independent_request.gentek_parameters.mosaic.cohesion=0.15
	independent_request["shared_ownership"]=false
	var independent_prepared:=Protocol.prepare(independent_request,{"extent":extent,"cells":bytes})
	check(independent_prepared.ok and independent_prepared.text.begins_with("SWARM004 2\n") \
		and independent_prepared.interface==prepared.shared and not 1 in independent_prepared.shared and independent_prepared.context==prepared.context,
		"independent controls and fixed ownership use v2 without changing source or interface geometry")
	var independent_evidence:Dictionary=valid.duplicate(true)
	independent_evidence.input.frame.profile.branching=0.9;independent_evidence.input.mosaic.profile.cohesion=0.15
	independent_evidence.input.options.shared_ownership=false
	independent_evidence.input.shared_zone.fill(0)
	var shared_prepared:=prepared;prepared=independent_prepared
	check(decode(independent_evidence).ok,"decoder checks the two actual native profiles independently")
	independent_evidence.input.mosaic.profile.branching=0.9
	check(not decode(independent_evidence).ok,"one Gentek cannot borrow the other's requested independent control")
	prepared=shared_prepared
	independent_request.gentek_parameters.frame.destruction=NAN
	check(not Protocol.prepare(independent_request,{"extent":extent,"cells":bytes}).ok,"independent destruction remains finite and independently validated")
	var map_path:="user://swarm004-protocol-map.json"
	var current_saved:=saved_fixture(map_path,valid)
	check(current_saved.ok and current_saved.historical_only,"current saved evidence has inspection authority only")
	var before_hashes:=saved_hashes(map_path)
	check(Protocol.load_saved(map_path).ok and saved_hashes(map_path)==before_hashes,"current inspection never rewrites any saved file")
	for definition:String in HISTORICAL_DEFINITIONS:
		var historical:=historical_fixture(definition)
		if definition==HISTORICAL_DEFINITIONS[0]:
			historical.input.options.erase("compact_native_termination")
			historical.input.options.erase("supported_native_receptors")
		var loaded:=saved_fixture(map_path,historical)
		check(loaded.ok and loaded.historical_only,"reviewed saved definition "+definition.left(8)+" is read-only inspectable")
		check(loaded.ok and loaded.result==JSON.parse_string(FileAccess.get_file_as_string(map_path+".swarm004-evidence.json")),
			"historical native evidence is preserved without option or authority rewriting")
		before_hashes=saved_hashes(map_path)
		check(Protocol.load_saved(map_path).ok and saved_hashes(map_path)==before_hashes,"historical inspection preserves all three original file hashes")
		check(not decode(historical).ok,"historical definition "+definition.left(8)+" cannot enter live decode")
	for option:String in ["compact_native_termination","supported_native_receptors"]:
		var legacy:=historical_fixture(HISTORICAL_DEFINITIONS[0])
		legacy.input.options[option]=true
		check(not saved_fixture(map_path,legacy).ok,"SWARM-004 historical evidence cannot acquire later "+option)
		legacy.input.options[option]=0
		check(not saved_fixture(map_path,legacy).ok,"legacy missing-field compatibility does not coerce malformed "+option)
		for definition:String in HISTORICAL_DEFINITIONS.slice(1)+[Protocol.NATIVE_DEFINITION]:
			var missing:=historical_fixture(definition);missing.input.options.erase(option)
			check(not saved_fixture(map_path,missing).ok,"later saved definitions require explicit "+option)
		var missing_current:Dictionary=valid.duplicate(true);missing_current.input.options.erase(option)
		check(not decode(missing_current).ok,"current live evidence still requires explicit "+option)
	check(not saved_fixture(map_path,historical_fixture("a".repeat(64))).ok,"unknown native definition is refused despite matching receipt hashes")
	var mixed:=historical_fixture(HISTORICAL_DEFINITIONS[1])
	mixed.input.mosaic.definition="mosaic.prepared-regions-v0."+HISTORICAL_DEFINITIONS[2]
	check(not saved_fixture(map_path,mixed).ok,"two reviewed but mixed definitions cannot share a saved receipt")
	for revision:int in [4,6]:
		var future:=historical_fixture(HISTORICAL_DEFINITIONS[2]);future.schema=revision
		check(not saved_fixture(map_path,future).ok,"saved compatibility admits schema5 only, refusing schema"+str(revision))
	var future_type:=historical_fixture(HISTORICAL_DEFINITIONS[2]);future_type.type="reciprocal_assembly_v4"
	check(not saved_fixture(map_path,future_type).ok,"future protocol family cannot borrow a reviewed native identity")
	for field:String in ["map_sha256","evidence_sha256","proposal_sha256","native_source","cli_sha256"]:
		var tampered:Dictionary={};tampered[field]="changed"
		check(not saved_fixture(map_path,historical_fixture(HISTORICAL_DEFINITIONS[2]),tampered).ok,
			"historical receipt still rejects changed "+field)
	for owner:String in ["frame","mosaic"]:
		var limit:=historical_fixture(HISTORICAL_DEFINITIONS[2]);limit.input[owner].limits.work+=1
		check(not saved_fixture(map_path,limit).ok,"historical "+owner+" limits remain exact even with rebound file hashes")
	for mask:String in ["eligible","protected","transition","context"]:
		var changed_mask:=historical_fixture(HISTORICAL_DEFINITIONS[2]);changed_mask.input.mosaic[mask][0]=42
		check(not saved_fixture(map_path,changed_mask).ok,"historical "+mask+" remains validated even with rebound file hashes")
	saved_fixture(map_path,valid)
	var evidence_file:=FileAccess.open(map_path+".swarm004-evidence.json",FileAccess.READ_WRITE)
	evidence_file.seek_end();evidence_file.store_string(" ");evidence_file.close()
	check(not Protocol.load_saved(map_path).ok,"changed evidence bytes cannot borrow an earlier saved receipt")
	saved_fixture(map_path,valid)
	var map_file:=FileAccess.open(map_path,FileAccess.WRITE);map_file.store_string("changed");map_file.close()
	check(not Protocol.load_saved(map_path).ok,"changed saved map cannot borrow an older construction receipt")
	# Only original006 and later sources emitted reciprocal_assembly schema6.
	# Older serializers used schema6 for a different diagnostic record type.
	for definition:String in HISTORICAL_DEFINITIONS+[Protocol.NATIVE_DEFINITION]:
		var recovery_saved:Dictionary=v4_evidence.duplicate(true)
		recovery_saved.input.frame.definition="frameweaver.frontier-growth-v0."+definition
		recovery_saved.input.mosaic.definition="mosaic.prepared-regions-v0."+definition
		var inspected:Dictionary=saved_fixture(map_path,recovery_saved)
		var supports_recovery:bool=definition in [HISTORICAL_DEFINITIONS[4],HISTORICAL_DEFINITIONS[5],Protocol.NATIVE_DEFINITION]
		check(inspected.ok==supports_recovery,"saved schema6 admission matches the original serializer for "+definition.left(8))
		if supports_recovery:
			check(inspected.historical_only and inspected.result==JSON.parse_string(FileAccess.get_file_as_string(map_path+".swarm004-evidence.json")),
				"saved V4 retains exact native evidence under read-only authority")
			before_hashes=saved_hashes(map_path)
			check(Protocol.load_saved(map_path).ok and saved_hashes(map_path)==before_hashes,"V4 inspection preserves the original saved triplet bytes")
			for field:String in ["negotiated_recovery","recovery_offers"]:
				var changed:Dictionary=recovery_saved.duplicate(true);changed.input.options.erase(field)
				check(not saved_fixture(map_path,changed).ok,"saved schema6 requires explicit "+field)
			for field:String in ["schema","programme","identity"]:
				var changed:Dictionary=recovery_saved.duplicate(true);changed[field]="forged"
				check(not saved_fixture(map_path,changed).ok,"saved schema6 refuses changed "+field)
			var mixed_recovery:Dictionary=recovery_saved.duplicate(true)
			mixed_recovery.input.mosaic.definition="mosaic.prepared-regions-v0."+HISTORICAL_DEFINITIONS[1]
			check(not saved_fixture(map_path,mixed_recovery).ok,"saved schema6 refuses a mixed reviewed definition pair")
	for name:String in [path,map_path,map_path+".swarm004.json",map_path+".swarm004-evidence.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(name))
	print("SWARM004_PROTOCOL ",JSON.stringify({"checks":checks,"failures":failures,"completed":true,"scope":"transport/admission only"}))
	quit(0 if failures.is_empty() else 1)
