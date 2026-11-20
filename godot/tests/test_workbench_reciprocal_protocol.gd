extends SceneTree

# Transport/admission fixtures only. They do not represent generated architecture
# and never install a World or certify reciprocal construction.
const Protocol=preload("res://scripts/workbench_reciprocal_protocol.gd")
var checks:=0
var failures:Array[String]=[]
var path:="user://swarm004-protocol-test.json"
var prepared:Dictionary
var valid:Dictionary

func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func write(value:Dictionary)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value));file.close()

func decode(value:Dictionary)->Dictionary:
	write(value)
	return Protocol.decode(path,prepared,"transport-fixture-no-assembly")

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
		"eligible":frame,"protected":Array(prepared.protected),"transition":Array(prepared.shared)}
	input.profile["name"]="industrial"
	var other:Dictionary=input.duplicate(true);other.eligible=mosaic
	valid={"schema":5,"type":"reciprocal_assembly","source":"transport-fixture-no-assembly","can_apply":false,
		"status":"blocked","reason":"transport test, no architecture","stop_reason":"fixture","input":{"frame":input,"mosaic":other,
		"shared_zone":Array(prepared.shared),"options":{"rounds":2,"shared_extent":2,"orientation_preference":1,
		"optional_negotiation":false,"shared_ownership":true,"final_validation":true}},"cells":[],"ledger":[],"ledger_columns":Protocol.LEDGER_COLUMNS,
		"rules":[],"rounds":[],"joints":[],"obligations":[],"owner_names":["empty","FRAMEWEAVER","MOSAIC","immutable_environment"]}
	check(decode(valid).ok,"well-formed blocked evidence remains inspectable")
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
	var map_file:=FileAccess.open(map_path,FileAccess.WRITE);map_file.store_string("transport fixture only");map_file.close()
	write(valid)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(map_path+".swarm004-evidence.json"))
	var receipt:Dictionary={"schema":1,"map_sha256":FileAccess.get_sha256(map_path),"evidence_sha256":FileAccess.get_sha256(path),
		"proposal_sha256":FileAccess.get_sha256(path),"native_source":"transport-fixture-no-assembly","cli_sha256":"0".repeat(64)}
	var receipt_file:=FileAccess.open(map_path+".swarm004.json",FileAccess.WRITE);receipt_file.store_string(JSON.stringify(receipt));receipt_file.close()
	check(Protocol.load_saved(map_path).ok,"bounded saved evidence reloads for historical inspection")
	map_file=FileAccess.open(map_path,FileAccess.WRITE);map_file.store_string("changed");map_file.close()
	check(not Protocol.load_saved(map_path).ok,"changed saved map cannot borrow an older construction receipt")
	for name:String in [path,map_path,map_path+".swarm004.json",map_path+".swarm004-evidence.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(name))
	print("SWARM004_PROTOCOL ",JSON.stringify({"checks":checks,"failures":failures,"completed":true,"scope":"transport/admission only"}))
	quit(0 if failures.is_empty() else 1)
