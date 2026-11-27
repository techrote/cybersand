extends RefCounted

# Finite file protocol for the separately authored native Genteks. These helpers
# transform copied snapshots and evidence; they never access the live World.
const Palette = preload("res://scripts/material_appearance_lut.gd")
const MAX_WIDTH := 256
const MAX_HEIGHT := 128
const MAX_INPUT_BYTES := 2*1024*1024
const MAX_OUTPUT_BYTES := 32*1024*1024
const PROFILES := ["industrial","viaduct_like","irregular_megastructure"]
const LAYOUTS := ["left_right","top_bottom","centered_frame_rectangle"]
# Authoring presets mirror the native expression_profile structural controls.
# Decoration and destruction stay independent and are never reset by a style.
const EXPRESSION_DEFAULTS := [
	{"variation":0.65,"irregularity":0.15,"branching":0.75,"environment_affinity":1.0,"cohesion":0.15},
	{"variation":0.65,"irregularity":0.05,"branching":0.55,"environment_affinity":0.25,"cohesion":0.35},
	{"variation":0.65,"irregularity":0.95,"branching":1.0,"environment_affinity":0.7,"cohesion":0.2}]
const PARAMETERS := ["variation","irregularity","clutter","destruction","branching","environment_affinity","cohesion"]
# This experimental bridge qualifies one compiled native definition interface.
# The suffix is Makefile.reciprocal's hash of its complete C++/header inputs.
# A changed definition requires a separately qualified bridge; source labels or
# a successful child exit do not authorize a different Gentek or larger budget.
const NATIVE_DEFINITION := "06628be15c9e9734c9c7b5bd98705a12bfc2e7f23d9d06f7d3982888bbb0eaaf"
# Saved evidence admits only the exact definition/schema pairs emitted by
# these reviewed serializers. It never authorizes current transport or Apply.
const SAVED_SWARM004_DEFINITION := "57ff699bf5c9833a2a5e2198ff2ef0b07cfd051069013776e6427f1e9d6694ec"
const HISTORICAL_DEFINITION_SCHEMAS := {
	SAVED_SWARM004_DEFINITION:[5],
	"12a4816dab749a9c872a4d531836db8ec6a170aab31576d70086efa80eeb3b6b":[5],
	"fe62e15412459c22c6f81e479fa1ff2917d7359d747581c9891b83fbf2f75618":[5],
	"217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7":[5],
	"afbae85af2c44f1e539a154fbee622a3ee7533a6caab9ad1f9c5190a8e5803e4":[5,6],
	"72779688b897e4707d89ac1f6e692046abbc806bd27b4c129bd77fcd995093a0":[5,6]}
const NATIVE_IDENTITIES := {
	"frame":{"gentek":"FRAMEWEAVER","version":0,"fixture":"workbench_territory",
		"definition":"frameweaver.frontier-growth-v0."+NATIVE_DEFINITION},
	"mosaic":{"gentek":"MOSAIC","version":0,"fixture":"workbench_territory",
		"definition":"mosaic.prepared-regions-v0."+NATIVE_DEFINITION}}
const NATIVE_LIMITS := {"instances":64,"frontier":256,"candidates":8192,"connectors_per_instance":8,
	"affordances":256,"cohesion_patches":8,"cohesion_cells_per_patch":512,"work":2000000,"solver_work":4000000,"bytes":16777216}
const NATIVE_SWITCHES := ["vocabulary","hierarchy","frame_adaptation","mosaic_adaptation","native_mosaic_bearing"]
const LEDGER_COLUMNS := ["owner","instance","rule","first_round","last_round","revision_mask"]
const MAX_INSPECTION_RECORDS := 4096
const SOCKET_COLORS := {"required":0xff6868ff,"foreign_required":0xff6868ff,"optional":0xffd166ff,"local_terminable":0x69e6eeff}

static func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK: return ""
	hash.update(bytes)
	return hash.finish().hex_encode()

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

static func material(value: Variant) -> bool:
	return integer(value,0,Palette.MATERIAL_COUNT-1) and int(value) != 10

static func scalar_same(value: Variant, expected: Variant) -> bool:
	if expected is bool: return value is bool and value==expected
	if expected is String: return value is String and value==expected
	if expected is int or expected is float:
		return (value is int or value is float) and is_finite(float(value)) and float(value)==float(expected)
	return false

static func fail(reason: String) -> Dictionary:
	return {"ok":false,"error":reason}

static func parameters_for(recipe: Dictionary, gentek: String) -> Dictionary:
	var overrides: Variant=recipe.get("gentek_parameters",{})
	if not overrides is Dictionary: return {}
	var values: Variant=overrides.get(gentek,recipe.get("parameters",{}))
	return values if values is Dictionary else {}

static func normalized_parameters(values: Dictionary) -> bool:
	for key: String in PARAMETERS:
		var value: Variant=values.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value)<0 or float(value)>1: return false
	return true

static func parameter_line(values: Dictionary) -> String:
	var knobs:=PackedStringArray()
	for key: String in PARAMETERS: knobs.append("%.8f" % float(values[key]))
	return " ".join(knobs)

static func point_list(value: Variant, size: Vector2i) -> bool:
	if not value is Array or value.size()>size.x*size.y: return false
	for point: Variant in value:
		if not point is Array or point.size()!=2 or not integer(point[0],0,size.x-1) or not integer(point[1],0,size.y-1): return false
	return true

static func bounded_vector(value: Variant, bound: int) -> bool:
	return value is Array and value.size()==2 and integer(value[0],-bound,bound) and integer(value[1],-bound,bound)

static func recovery_record(record: Dictionary, size: Vector2i) -> bool:
	# Admission bounds protect the inspector. Native replay and the unchanged
	# material-path validator remain authoritative for reservation/joint truth.
	if not integer(record.get("recovery_work"),0,2000000) or not record.get("recovery_frontier_exhausted") is bool: return false
	for key: String in ["recovery_attempts","mosaic_recovery_receipts","recovery_frontier"]:
		if not record.get(key) is Array: return false
	if record.recovery_attempts.size()>520 or record.mosaic_recovery_receipts.size()>8 or record.recovery_frontier.size()>8: return false
	var attempted_work:=0
	for attempt: Variant in record.recovery_attempts:
		if not attempt is Dictionary: return false
		for key: String in ["slot","connector","source_instance","host_instance"]:
			if not integer(attempt.get(key),0,4294967295): return false
		if not integer(attempt.get("round"),1,4) or not scalar_same(attempt.round,record.number) \
			or not integer(attempt.get("ordinal"),0,261) or not integer(attempt.get("length"),0,6) \
			or not integer(attempt.get("variant"),0,3) or not integer(attempt.get("work"),0,2000000) \
			or not point_list([attempt.get("root")],size) or not bounded_vector(attempt.get("contact"),384) \
			or not bounded_vector(attempt.get("axis"),1): return false
		for key: String in ["phase","outcome","reason"]:
			if not attempt.get(key) is String or attempt[key].length()>1024: return false
		attempted_work+=int(attempt.work)
	if attempted_work>int(record.recovery_work): return false
	for cursor: Variant in record.recovery_frontier:
		if not cursor is Dictionary or not integer(cursor.get("slot"),0,4294967295) or not integer(cursor.get("next"),0,262) \
			or not cursor.get("exhausted") is bool or not cursor.get("observation") is String or cursor.observation.length()!=16: return false
	for receipt: Variant in record.mosaic_recovery_receipts:
		if not receipt is Dictionary: return false
		for key: String in ["slot","connector","source_instance","host_instance","receiving_instance","port_id"]:
			if not integer(receipt.get(key),0,4294967295): return false
		if not integer(receipt.get("round"),1,int(record.number)) or not integer(receipt.get("candidate"),0,261) \
			or not integer(receipt.get("length"),0,6) or not integer(receipt.get("variant"),0,3) \
			or not integer(receipt.get("work"),0,2000000) or not receipt.get("edits") is Array or receipt.edits.size()>14 \
			or not point_list([receipt.get("root"),receipt.get("contact"),receipt.get("backing"),receipt.get("host")],size) \
			or not bounded_vector(receipt.get("axis"),1) or not bounded_vector(receipt.get("cross"),1): return false
		for key: String in ["source_family","receiving_family"]:
			if not receipt.get(key) is String or receipt[key].length()>96: return false
		for key: String in ["source_digest","prior_digest"]:
			if not receipt.get(key) is String or receipt[key].length()!=16: return false
		for edit: Variant in receipt.edits:
			if not edit is Dictionary or not point_list([edit.get("point")],size) or not material(edit.get("before")) or not material(edit.get("after")): return false
			for key: String in ["before_role","after_role","before_owner","after_owner"]:
				if not integer(edit.get(key),0,4294967295): return false
	return true

static func native_preview(value: Variant, size: Vector2i, allow_empty: bool) -> bool:
	var count:=size.x*size.y
	if not value is Dictionary or not value.get("cells") is Array or not value.get("provenance") is Array \
		or value.cells.size()!=value.provenance.size() or (value.cells.size()!=count and not (allow_empty and value.cells.is_empty())): return false
	for id: Variant in value.cells:
		if not material(id): return false
	for id: Variant in value.provenance:
		if not integer(id,0,4294967295): return false
	var boundary: Variant=value.get("boundary",{})
	if not boundary is Dictionary or not socket_array(value.get("connectors",[]),size,false) \
		or not socket_array(boundary.get("hard",[]),size,false): return false
	return true

static func frame_preview(value: Variant, size: Vector2i, allow_empty: bool) -> bool:
	if not value is Dictionary or not native_preview(value.get("result"),size,allow_empty) \
		or not value.get("slots") is Array or value.slots.size()>256: return false
	for slot: Variant in value.slots:
		if not slot is Dictionary or not point_list(slot.get("clearance"),size): return false
	var constructions: Variant=value.get("constructions",[])
	if not constructions is Array or constructions.size()>256: return false
	var socket_count:=0
	for construction: Variant in constructions:
		if not construction is Dictionary or not construction.get("assembly") is Dictionary: return false
		var sockets: Variant=construction.assembly.get("sockets",[])
		if not socket_array(sockets,size,true): return false
		socket_count+=sockets.size()
		if socket_count>MAX_INSPECTION_RECORDS: return false
	return true

static func socket_array(values: Variant, size: Vector2i, assembly: bool) -> bool:
	if not values is Array or values.size()>MAX_INSPECTION_RECORDS: return false
	for value: Variant in values:
		if not value is Dictionary or not integer(value.get("id"),0,4294967295) \
			or not integer(value.get("instance"),0,4294967295) or not point_list([value.get("a"),value.get("b")],size) \
			or not value.get("facing") is Array or value.facing.size()!=2 \
			or not integer(value.facing[0],-1,1) or not integer(value.facing[1],-1,1) \
			or not value.get("family") is String or value.family.length()>96: return false
		if assembly:
			if value.get("obligation") not in ["foreign_required","optional","local_terminable"]: return false
		elif not value.get("required") is bool: return false
		if value.has("fulfilled") and not value.fulfilled is bool: return false
		if value.has("counterpart") and not integer(value.counterpart,0,4294967295): return false
		if value.has("state") and (not value.state is String or value.state.length()>8192): return false
	return true

static func ownership_masks(size: Vector2i, layout: String, border: int, reach: int) -> Dictionary:
	# The UI owns only territory/distribution. Native Gentek definitions own all
	# architecture. Flooding the actual exclusive interface matches the native
	# distance convention: either facing boundary cell has distance zero.
	if size.x<1 or size.y<1 or size.x>MAX_WIDTH or size.y>MAX_HEIGHT or layout not in LAYOUTS \
		or border<0 or border>16 or border*2>=mini(size.x,size.y) or reach<0 or reach>13:
		return fail("Invalid bounded ownership layout or clear border.")
	var count:=size.x*size.y
	var frame:=PackedByteArray();frame.resize(count)
	var mosaic:=PackedByteArray();mosaic.resize(count)
	var shared:=PackedByteArray();shared.resize(count)
	var distance:=PackedInt32Array();distance.resize(count);distance.fill(999)
	var frontier:=PackedInt32Array()
	var inner:=Rect2i(size/4,size-size/4*2)
	for at: int in count:
		var point:=Vector2i(at%size.x,at/size.x)
		if point.x<border or point.y<border or point.x>=size.x-border or point.y>=size.y-border: continue
		var owns: bool=point.x<size.x/2 if layout=="left_right" else point.y<size.y/2 if layout=="top_bottom" else inner.has_point(point)
		frame[at]=int(owns);mosaic[at]=int(not owns)
	if reach>0:
		for at: int in count:
			if not frame[at] and not mosaic[at]: continue
			var x: int=at%size.x;var y: int=at/size.x
			for next: int in [at-1 if x>0 else -1,at+1 if x+1<size.x else -1,at-size.x if y>0 else -1,at+size.x if y+1<size.y else -1]:
				if next>=0 and ((frame[at] and mosaic[next]) or (mosaic[at] and frame[next])):
					distance[at]=0;frontier.append(at);break
		var cursor:=0
		while cursor<frontier.size():
			var at:=frontier[cursor];cursor+=1
			shared[at]=1
			if distance[at]>=reach: continue
			var x: int=at%size.x;var y: int=at/size.x
			for next: int in [at-1 if x>0 else -1,at+1 if x+1<size.x else -1,at-size.x if y>0 else -1,at+size.x if y+1<size.y else -1]:
				if next>=0 and (frame[next] or mosaic[next]) and distance[next]>distance[at]+1:
					distance[next]=distance[at]+1;frontier.append(next)
	return {"ok":true,"frame":frame,"mosaic":mosaic,"shared":shared}

static func prepare(request: Dictionary, capture: Dictionary) -> Dictionary:
	var size: Vector2i = request.size
	var origin: Vector2i = request.origin
	var extent: Vector2i = capture.extent
	if size.x < 1 or size.y < 1 or size.x > MAX_WIDTH or size.y > MAX_HEIGHT \
		or not Rect2i(Vector2i.ZERO,extent).encloses(Rect2i(origin,size)):
		return fail("Activation territory must fit the native canvas within 256×128 cells.")
	if not capture.get("cells") is PackedByteArray or capture.cells.size() != extent.x*extent.y*2:
		return fail("Native source capture has incomplete material cells.")
	if request.profile not in PROFILES or not integer(request.seed,0,2147483647) \
		or not integer(request.rounds,0,4) or not integer(request.shared_extent,0,13) \
		or not integer(request.orientation,-1,1): return fail("Invalid bounded native recipe.")
	if not request.get("parameters") is Dictionary or not normalized_parameters(request.parameters):
		return fail("Invalid normalized shared native controls.")
	var frame_parameters:=parameters_for(request,"frame");var mosaic_parameters:=parameters_for(request,"mosaic")
	if not normalized_parameters(frame_parameters) or not normalized_parameters(mosaic_parameters):
		return fail("Independent Gentek controls must all be finite and normalized to 0..1.")
	if request.activation.is_empty() or request.activation.size() > 16:
		return fail("Paint an activation stroke with 1–16 sampled locations.")
	var layout: Variant=request.get("layout","left_right")
	var border: Variant=request.get("border",0)
	if not layout is String or not integer(border,0,16): return fail("Invalid ownership layout or clear border.")
	var masks:=ownership_masks(size,layout,int(border),int(request.shared_extent))
	if not masks.ok: return masks
	var sharing: Variant=request.get("shared_ownership",true)
	if not sharing is bool: return fail("Negotiated territory sharing must be an explicit boolean.")
	var compact: Variant=request.get("compact_native_termination",false)
	var supported: Variant=request.get("supported_native_receptors",false)
	if not compact is bool or not supported is bool:
		return fail("SWARM-005 source feasibility and native receptors must be explicit booleans.")
	var recovery: Variant=request.get("negotiated_recovery",false)
	if not recovery is bool: return fail("Bounded reciprocal recovery must be an explicit boolean.")
	var experimental: bool=compact or supported or recovery
	var independent: bool=parameter_line(frame_parameters)!=parameter_line(mosaic_parameters) or not sharing or experimental
	var magic: String="SWARM006 4" if recovery else ("SWARM005 3" if experimental else ("SWARM004 2" if independent else "SWARM004 1"))
	var lines := PackedStringArray([magic,"%d %d %d %d %d %d %d %d" % [size.x,size.y,
		request.seed,origin.x,origin.y,request.rounds,request.shared_extent,request.orientation],request.profile])
	lines.append(parameter_line(frame_parameters)+(" 1" if request.optional else " 0"))
	if independent: lines.append(parameter_line(mosaic_parameters)+(" 1" if sharing else " 0"))
	if recovery: lines.append("%d %d 1" % [int(compact),int(supported)])
	elif experimental: lines.append("%d %d" % [int(compact),int(supported)])
	lines.append(str(request.activation.size()))
	for point: Vector2i in request.activation:
		if not Rect2i(Vector2i.ZERO,size).has_point(point): return fail("Activation point is outside its territory.")
		lines.append("%d %d" % [point.x,point.y])
	var context := PackedInt32Array()
	var protected := PackedByteArray()
	var shared: PackedByteArray=masks.shared.duplicate()
	if not sharing: shared.fill(0)
	var guards := PackedInt32Array()
	context.resize(size.x*size.y);protected.resize(context.size())
	for y: int in size.y:
		for x: int in size.x:
			var at := y*size.x+x
			var world := origin+Vector2i(x,y)
			var id: int = capture.cells.decode_u16((world.y*extent.x+world.x)*2)
			if not material(id): return fail("Source contains an unsupported native material ID.")
			context[at] = id
			protected[at] = 1 if request.protected.has(world) else 0
			if protected[at]: guards.append_array(PackedInt32Array([world.x,world.y]))
			lines.append("%d %d %d %d %d" % [masks.frame[at],masks.mosaic[at],protected[at],masks.shared[at],id])
	var text := "\n".join(lines)+"\n"
	if text.to_utf8_buffer().size() > MAX_INPUT_BYTES: return fail("Native request exceeds the 2 MiB transport budget.")
	return {"ok":true,"text":text,"context":context,"protected":protected,"shared":shared,"guards":guards,
		"frame_eligible":masks.frame,"mosaic_eligible":masks.mosaic,"interface":masks.shared,
		"request_sha256":digest(text.to_utf8_buffer()),"recipe":request.duplicate(true)}

static func decode(path: String, prepared: Dictionary, expected_source: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return fail("Native generator produced no completed output.")
	if file.get_length() > MAX_OUTPUT_BYTES: return fail("Native evidence exceeds the 32 MiB preview budget.")
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return fail("Native output is not a complete evidence document.")
	return decode_document(parser.data,bytes,prepared,expected_source)

static func receipt_same(value: Variant, expected: Variant) -> bool:
	# JSON numbers are floats in Godot. Compare exact integral values while
	# retaining strict boolean/string and bounded expected-container types.
	if expected is Dictionary:
		if not value is Dictionary or value.size()!=expected.size(): return false
		for key: Variant in expected:
			if not value.has(key) or not receipt_same(value[key],expected[key]): return false
		return true
	if expected is Array:
		if not value is Array or value.size()!=expected.size(): return false
		for at: int in expected.size():
			if not receipt_same(value[at],expected[at]): return false
		return true
	if expected==null: return value==null
	return scalar_same(value,expected)

static func empty_admission_refusal(result: Dictionary) -> bool:
	# Only the frozen preflight empty state can omit generation work counters or
	# source vectors. It carries no geometry, accepted history or Apply authority.
	if result.get("can_apply")!=false or result.get("status") not in ["exhausted","invalid"] \
		or result.get("digest")!="0000000000000000" or not result.has("damage_derivative") or result.damage_derivative!=null: return false
	if result.get("stop_reason")!=("budget_exhaustion" if result.status=="exhausted" else "invalid_native_proposal"): return false
	for key: String in ["rounds","cells","ledger","rules","obligations","joints","rejections"]:
		if not result.get(key) is Array or not result[key].is_empty(): return false
	var empty: Dictionary={"gentek":"FRAMEWEAVER","implementation":"","definition":"","source":"","seed":0,
		"status":"complete","termination":"complete","request_digest":"0000000000000000",
		"material_digest":"0000000000000000","digest":"0000000000000000","width":0,"height":0,
		"work":0,"candidates":0,"solver_work":0,"backtracks":-1,"protected_violations":0,"illegal_overlaps":0,
		"unresolved_joints":0,"metrics":{},"rejected":{},"notes":[],"cells":[],"roles":[],"provenance":[],
		"instances":[],"connectors":[],"attachments":[],"boundary":{"hard":[],"soft":[],"protected":[],"transition":[]}}
	return receipt_same(result.get("original_frame"),{"core":empty,"result":empty,"slots":[],"reservation_rejections":[],"source_feasibility":[]})

static func saved_definition(result: Dictionary) -> String:
	var inputs: Variant=result.get("input")
	if not inputs is Dictionary or not inputs.get("frame") is Dictionary or not inputs.get("mosaic") is Dictionary: return ""
	var definitions: Array=HISTORICAL_DEFINITION_SCHEMAS.keys()
	if NATIVE_DEFINITION not in definitions: definitions.append(NATIVE_DEFINITION)
	for definition: String in definitions:
		if not scalar_same(inputs.frame.get("definition"),"frameweaver.frontier-growth-v0."+definition) \
			or not scalar_same(inputs.mosaic.get("definition"),"mosaic.prepared-regions-v0."+definition): continue
		var schemas: Array=[5,6] if definition==NATIVE_DEFINITION else HISTORICAL_DEFINITION_SCHEMAS[definition]
		for schema: int in schemas:
			if scalar_same(result.get("schema"),schema): return definition
	return ""

static func decode_document(result: Dictionary, bytes: PackedByteArray, prepared: Dictionary, expected_source: String, historical: bool = false) -> Dictionary:
	var qualified_definition:=saved_definition(result) if historical else NATIVE_DEFINITION
	if qualified_definition.is_empty(): return fail("Saved Gentek definitions or schema are unknown or do not share one reviewed native source.")
	var recovery: bool=prepared.recipe.get("negotiated_recovery",false)==true
	if not scalar_same(result.get("schema"),6 if recovery else 5) or not scalar_same(result.get("type"),"reciprocal_assembly") \
		or not scalar_same(result.get("source"),expected_source) or not result.get("can_apply") is bool:
		return fail("Native output schema or source identity does not match this executable request.")
	if recovery and (not scalar_same(result.get("programme"),"GENTEK-SWARM-006") \
		or not scalar_same(result.get("identity"),"gentek_swarm_006_negotiated_recovery_v1")):
		return fail("Native recovery evidence changed the qualified SWARM-006 protocol.")
	var header_only:=false
	var admission_refusal: bool=recovery and empty_admission_refusal(result)
	if recovery:
		var metrics: Variant=result.get("metrics")
		if not metrics is Dictionary or metrics.size()>512: return fail("Native recovery evidence has malformed work diagnostics.")
		for key: Variant in metrics:
			if not key is String or key.length()>128 or not integer(metrics[key],0,9007199254740991):
				return fail("Native recovery evidence has malformed work counters.")
		if not integer(metrics.get("input_header_only",0),0,1): return fail("Native input-header receipt is malformed.")
		header_only=int(metrics.get("input_header_only",0))==1
		if header_only and (not admission_refusal or not receipt_same(metrics,{"frame_work":0,"input_header_only":1,"total_charged_work":0})):
			return fail("Native header refusal supplied geometry, work, history or Apply authority.")
		for key: String in ["frame_work","mosaic_work","solver_work","shared_work"]:
			if not integer(metrics.get(key,0 if admission_refusal else null),0,4000000 if key=="solver_work" else 2000000):
				return fail("Native recovery evidence exceeds a qualified aggregate work allowance.")
	for key: String in ["status","reason","stop_reason"]:
		if not result.get(key) is String or result[key].length()>8192: return fail("Native status or reason is malformed.")
	var recipe: Dictionary = prepared.recipe
	var size: Vector2i = recipe.size
	var count := size.x*size.y
	var layout: Variant=recipe.get("layout","left_right");var border: Variant=recipe.get("border",0)
	if not layout is String or not integer(border,0,16) or not integer(recipe.get("shared_extent"),0,13):
		return fail("Native evidence has an invalid ownership layout.")
	var masks:=ownership_masks(size,layout,int(border),int(recipe.shared_extent))
	if not masks.ok: return masks
	if not integer(recipe.seed,0,2147483647) or not integer(recipe.rounds,0,4) or not integer(recipe.shared_extent,0,13) \
		or not integer(recipe.orientation,-1,1) or not recipe.optional is bool or not recipe.profile is String or recipe.profile not in PROFILES \
		or recipe.activation.is_empty() or recipe.activation.size()>16:
		return fail("Native evidence has an invalid bounded authoring recipe.")
	if not recipe.get("shared_ownership",true) is bool: return fail("Native evidence has invalid negotiated territory sharing.")
	for key: String in ["compact_native_termination","supported_native_receptors","negotiated_recovery"]:
		if not recipe.get(key,false) is bool: return fail("Experimental evidence has a nonboolean native closure control.")
	for gentek: String in ["frame","mosaic"]:
		if not normalized_parameters(parameters_for(recipe,gentek)): return fail("Native evidence has invalid independent Gentek controls.")
	var inputs: Variant = result.get("input")
	if not inputs is Dictionary: return fail("Native evidence is missing its immutable requests.")
	var options: Variant = inputs.get("options")
	if not options is Dictionary or not scalar_same(options.get("rounds"),recipe.rounds) \
		or not scalar_same(options.get("shared_extent"),recipe.shared_extent) or not scalar_same(options.get("orientation_preference"),recipe.orientation) \
		or not scalar_same(options.get("optional_negotiation"),recipe.optional) or not scalar_same(options.get("final_validation"),true) \
		or not scalar_same(options.get("shared_ownership"),recipe.get("shared_ownership",true)) \
		or not scalar_same(options.get("negotiated_recovery",false),recipe.get("negotiated_recovery",false)) \
		or not inputs.get("shared_zone") is Array or inputs.shared_zone.size()!=(0 if header_only else count):
		return fail("Native evidence changed the negotiated controls or final-validation requirement.")
	for key: String in ["compact_native_termination","supported_native_receptors"]:
		# Only the original SWARM004 saved format predates these controls.
		# Later serializers always emit them, including when both are OFF.
		var legacy: bool=historical and qualified_definition==SAVED_SWARM004_DEFINITION
		var value: Variant=options.get(key,false if legacy else null)
		if (legacy and not scalar_same(value,false)) or not scalar_same(value,recipe.get(key,false)):
			return fail("Native evidence changed the negotiated native closure controls.")
	if recovery and not scalar_same(options.get("recovery_offers"),true):
		return fail("Recovery preview requires the declared native offer policy.")
	for key: String in NATIVE_SWITCHES:
		if not scalar_same(options.get(key),true):
			return fail("Native evidence changed a qualified architectural rule switch.")
	for gentek: String in ["frame","mosaic"]:
		var input: Variant = inputs.get(gentek)
		if not input is Dictionary or not scalar_same(input.get("width"),size.x) or not scalar_same(input.get("height"),size.y) \
			or not scalar_same(input.get("seed"),recipe.seed) or not scalar_same(input.get("source"),expected_source) \
			or not input.get("origin") is Array or input.origin.size()!=2 \
			or not integer(input.origin[0],-1000000,1000000) or not integer(input.origin[1],-1000000,1000000) \
			or int(input.origin[0])!=recipe.origin.x or int(input.origin[1])!=recipe.origin.y:
			return fail("Native "+gentek+" evidence does not describe the requested source, seed, extent or origin.")
		for key: String in NATIVE_IDENTITIES[gentek]:
			var identity: Variant=NATIVE_IDENTITIES[gentek][key]
			if key=="definition": identity=str(identity).trim_suffix(NATIVE_DEFINITION)+qualified_definition
			if not scalar_same(input.get(key),identity):
				return fail("Native evidence changed the qualified Gentek identity, definition or authoring fixture.")
		if not input.get("limits") is Dictionary or input.limits.size()!=NATIVE_LIMITS.size():
			return fail("Native evidence omitted its qualified resource limits.")
		for key: String in NATIVE_LIMITS:
			var expected: int=192 if gentek=="mosaic" and key=="instances" else int(NATIVE_LIMITS[key])
			if not scalar_same(input.limits.get(key),expected):
				return fail("Native evidence changed a qualified resource limit.")
		if not input.get("neighbor_cells") is Array or not input.neighbor_cells.is_empty() \
			or not input.get("neighbors") is Dictionary or input.neighbors.size()!=4:
			return fail("Native evidence changed the initial independent proposal inputs.")
		for key: String in ["hard","soft","protected","transition"]:
			if not input.neighbors.get(key) is Array or not input.neighbors[key].is_empty():
				return fail("Native evidence introduced an unauthored initial neighbor obligation.")
		if not input.get("context") is Array or input.context.size()!=(0 if header_only else count):
			return fail("Native "+gentek+" evidence has an incomplete immutable source context.")
		if not input.get("profile") is Dictionary or not scalar_same(input.profile.get("name"),recipe.profile) \
			or not input.get("activation") is Array or input.activation.size()!=(0 if header_only else recipe.activation.size()):
			return fail("Native evidence changed the authored expression or activation distribution.")
		for key: String in PARAMETERS:
			var value: Variant=input.profile.get(key)
			if not (value is int or value is float) or not is_finite(value) \
				or absf(float(value)-float(parameters_for(recipe,gentek)[key]))>0.00000001:
				return fail("Native evidence changed the requested control "+key+".")
		for index: int in (0 if header_only else recipe.activation.size()):
			var point: Variant=input.activation[index]
			if not point is Array or point.size()!=2 or not scalar_same(point[0],recipe.activation[index].x) or not scalar_same(point[1],recipe.activation[index].y):
				return fail("Native evidence changed the sampled activation stroke.")
		for mask: String in ["eligible","protected","transition"]:
			if not input.get(mask) is Array or input[mask].size()!=(0 if header_only else count): return fail("Native evidence has an incomplete "+mask+" mask.")
		for at: int in (0 if header_only else count):
			if not material(input.context[at]) or int(input.context[at])!=int(prepared.context[at]):
				return fail("Native "+gentek+" evidence changed the captured source material context.")
			var eligible: int=masks.frame[at] if gentek=="frame" else masks.mosaic[at]
			var shared: int=masks.shared[at] if recipe.get("shared_ownership",true) else 0
			if not scalar_same(input.eligible[at],eligible) or not scalar_same(input.protected[at],int(prepared.protected[at])) \
				or not scalar_same(input.transition[at],int(masks.shared[at])) or not scalar_same(inputs.shared_zone[at],shared) \
				or int(prepared.shared[at])!=shared:
				return fail("Native evidence changed exclusive ownership, protected space or the bounded shared zone.")
	if admission_refusal:
		if not receipt_same(result.get("ledger_columns"),LEDGER_COLUMNS) \
			or not receipt_same(result.get("owner_names"),["empty","FRAMEWEAVER","MOSAIC","immutable_environment"]):
			return fail("Native admission refusal changed ownership or ledger semantics.")
		# Return a nonauthorizing diagnostic, never a proposal with substituted masks.
		return {"ok":false,"diagnostic_refusal":true,"native_status":result.status,"response_sha256":digest(bytes),
			"error":"Native %s · %s · %s. Apply remains disabled." % [result.status,result.stop_reason,result.reason]}
	if not result.get("cells") is Array or not result.get("ledger") is Array: return fail("Native composition has no material and ownership arrays.")
	var empty_failure: bool = not result.can_apply and result.cells.is_empty() and result.ledger.is_empty()
	if (result.cells.size() != count and not empty_failure) or (result.ledger.size() != count and not empty_failure) \
		or not result.get("ledger_columns") is Array or result.ledger_columns != LEDGER_COLUMNS or not result.get("rules") is Array \
		or not result.get("rounds") is Array or result.rounds.size()>5 \
		or not result.get("joints") is Array or not result.get("obligations") is Array \
		or not result.get("owner_names") is Array or result.owner_names.size()!=4:
		return fail("Native composition has incomplete cells, ownership, rounds or obligations.")
	for rule: Variant in result.rules:
		if not rule is String or rule.length()>8192: return fail("Native rule provenance is malformed.")
	for owner: Variant in result.owner_names:
		if not owner is String or owner.length()>128: return fail("Native owner names are malformed.")
	if result.joints.size()>256 or result.obligations.size()>256: return fail("Native connector inspection exceeds its finite capacity.")
	for joint: Variant in result.joints:
		if not joint is Dictionary or not point_list(joint.get("path"),size): return fail("Native joint path evidence is malformed.")
	for obligation: Variant in result.obligations:
		if not obligation is Dictionary or not obligation.get("state") is String or not obligation.get("reason") is String \
			or not integer(obligation.get("connector"),0,4294967295) or not point_list([obligation.get("original")],size) \
			or not obligation.get("foreign_joined") is bool or not obligation.get("local_terminated") is bool \
			or obligation.state not in ["FOREIGN_JOINED","STILL_REQUIRED"]:
			return fail("Native obligation evidence is malformed.")
	var cells := PackedInt32Array()
	var before := PackedInt32Array()
	for at: int in result.cells.size():
		var id: Variant = result.cells[at]
		var record: Variant = result.ledger[at]
		if not material(id) or not record is Array or record.size()!=6:
			return fail("Native composition contains an invalid cell or ownership record.")
		for value: Variant in record:
			if not integer(value,0,4294967295): return fail("Native provenance contains invalid integer values.")
		var owner := int(record[0])
		if owner>3 or (int(id)==0 and owner!=0) or (int(id)!=0 and owner==0):
			return fail("Every native material cell needs one unambiguous owner.")
		if owner==3:
			if int(id)!=int(prepared.context[at]): return fail("Immutable environment was changed by a proposal.")
		elif owner in [1,2]:
			var ordinary: bool=masks.frame[at]!=0 if owner==1 else masks.mosaic[at]!=0
			if int(prepared.context[at])!=0 or prepared.protected[at] or int(record[1])==0 \
				or int(record[2])>=result.rules.size() or int(record[3])>int(record[4]) or int(record[4])>4 or int(record[5])>31 \
				or (not ordinary and not prepared.shared[at]):
				return fail("Native construction violates source ownership, protected space or revision provenance.")
			cells.append_array(PackedInt32Array([recipe.origin.x+at%size.x,recipe.origin.y+at/size.x,int(id)]))
			before.append(0)
		elif int(prepared.context[at])!=0:
			return fail("Native composition dropped immutable environment material.")
	for ordinal: int in result.rounds.size():
		var round_value: Variant=result.rounds[ordinal]
		if not round_value is Dictionary or not scalar_same(round_value.get("number"),ordinal) \
			or not round_value.get("frame_accepted") is bool or not round_value.get("mosaic_accepted") is bool \
			or not round_value.get("reason") is String or not frame_preview(round_value.get("frame"),size,not result.can_apply) \
			or not round_value.get("mosaic") is Dictionary or not native_preview(round_value.mosaic.get("result"),size,not result.can_apply):
			return fail("Invalid native round record.")
		for counter: String in ["frame_changed","mosaic_changed","frame_work","mosaic_work"]:
			if not integer(round_value.get(counter),0,9007199254740991): return fail("Invalid native round counter.")
		for proposal: Variant in [round_value.get("proposed_frame"),round_value.get("proposed_mosaic")]:
			if not native_preview(proposal,size,not result.can_apply): return fail("Native round has incomplete provisional cells, sockets or part provenance.")
		if recovery and not recovery_record(round_value,size): return fail("Native recovery search, work or reservation evidence exceeds its bounded protocol.")
	var damage: Variant=result.get("damage_derivative")
	if damage!=null:
		if not damage is Dictionary or not frame_preview(damage.get("frame"),size,not result.can_apply) \
			or not damage.get("mosaic") is Dictionary or not native_preview(damage.mosaic.get("result"),size,not result.can_apply) \
			or not damage.get("reason") is String: return fail("Separate destruction evidence is malformed.")
		for counter: String in ["frame_changed","mosaic_changed","frame_footprint_changed","mosaic_footprint_changed","work"]:
			if not integer(damage.get(counter),0,9007199254740991): return fail("Separate destruction work or geometry count is malformed.")
	if not result.cells.is_empty():
		if result.rounds.is_empty(): return fail("Final material architecture requires an accepted round history.")
		var accepted: Dictionary=damage if damage is Dictionary else result.rounds.back()
		var frame: Dictionary=accepted.frame.result;var mosaic: Dictionary=accepted.mosaic.result
		if frame.cells.size()!=count or mosaic.cells.size()!=count: return fail("Final material architecture has incomplete accepted Gentek snapshots.")
		for at: int in count:
			var frame_id:=int(frame.cells[at]);var mosaic_id:=int(mosaic.cells[at])
			var expected_id:=int(prepared.context[at]);var owner:=3 if expected_id!=0 else 0
			var part:=0
			if frame_id!=0 or mosaic_id!=0:
				if expected_id!=0 or (frame_id!=0 and mosaic_id!=0): return fail("Accepted Gentek snapshots contain conflicting material claims.")
				owner=1 if frame_id!=0 else 2;expected_id=frame_id if owner==1 else mosaic_id
				part=int(frame.provenance[at]) if owner==1 else int(mosaic.provenance[at])
			if int(result.cells[at])!=expected_id or int(result.ledger[at][0])!=owner or (owner in [1,2] and int(result.ledger[at][1])!=part):
				return fail("Final cells or structural ownership differ from the accepted native snapshots.")
	if result.can_apply:
		if cells.is_empty() or not scalar_same(result.get("status"),"complete"): return fail("Native Apply requires a complete nonempty construction.")
		for obligation: Variant in result.obligations:
			if obligation.state!="FOREIGN_JOINED" or not obligation.foreign_joined:
				return fail("Native Apply is inconsistent with an unresolved mandatory obligation.")
	var pixels := raster(result,prepared,-1,"Materials")
	return {"ok":true,"result":result,"proposal_sha256":digest(bytes),"cells":cells,"before":before,
		"pixels":pixels,"file_bytes":bytes.size(),"historical_only":historical}

static func load_saved(map_path: String) -> Dictionary:
	var map_file:=FileAccess.open(map_path,FileAccess.READ)
	if map_file==null or map_file.get_length()>MAX_OUTPUT_BYTES: return fail("The named saved map is missing or exceeds the evidence inspection budget.")
	map_file.close()
	var receipt_file:=FileAccess.open(map_path+".swarm004.json",FileAccess.READ)
	if receipt_file==null or receipt_file.get_length()>1024*1024: return fail("This saved map has no bounded construction receipt.")
	var receipt: Variant=JSON.parse_string(receipt_file.get_as_text());receipt_file.close()
	if not receipt is Dictionary or not scalar_same(receipt.get("schema"),1) \
		or not scalar_same(receipt.get("map_sha256"),FileAccess.get_sha256(map_path)) \
		or not receipt.get("native_source") is String or receipt.native_source.is_empty() \
		or not receipt.get("cli_sha256") is String or receipt.cli_sha256.length()!=64:
		return fail("Saved construction evidence does not match this map file.")
	var path:=map_path+".swarm004-evidence.json"
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_OUTPUT_BYTES: return fail("Saved construction evidence is missing or exceeds the preview budget.")
	var bytes:=file.get_buffer(file.get_length());file.close()
	var evidence_sha:=digest(bytes)
	if not scalar_same(receipt.get("evidence_sha256"),evidence_sha) or not scalar_same(receipt.get("proposal_sha256"),evidence_sha):
		return fail("Saved construction evidence changed after acknowledgement.")
	var document: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	if not document is Dictionary or not document.get("input") is Dictionary: return fail("Saved construction evidence is malformed.")
	var input: Variant=document.input.get("frame");var options: Variant=document.input.get("options")
	if not input is Dictionary or not options is Dictionary or not integer(input.get("width"),1,MAX_WIDTH) \
		or not integer(input.get("height"),1,MAX_HEIGHT) or not input.get("origin") is Array or input.origin.size()!=2 \
		or not integer(input.origin[0],-1000000,1000000) or not integer(input.origin[1],-1000000,1000000) \
		or not input.get("profile") is Dictionary or not input.get("activation") is Array:
		return fail("Saved construction has invalid recipe bounds.")
	var size:=Vector2i(int(input.width),int(input.height));var origin:=Vector2i(int(input.origin[0]),int(input.origin[1]))
	var count:=size.x*size.y
	for key: String in ["context","protected","transition"]:
		if not input.get(key) is Array or input[key].size()!=count: return fail("Saved construction has incomplete source masks.")
	var activation: Array[Vector2i]=[]
	for point: Variant in input.activation:
		if not point is Array or point.size()!=2 or not integer(point[0],0,size.x-1) or not integer(point[1],0,size.y-1):
			return fail("Saved construction has an invalid activation location.")
		activation.append(Vector2i(int(point[0]),int(point[1])))
	var guards:=PackedInt32Array()
	for at: int in count:
		if not integer(input.protected[at],0,1) or not integer(input.transition[at],0,1) or not material(input.context[at]):
			return fail("Saved construction has invalid native source masks.")
		if int(input.protected[at]): guards.append_array(PackedInt32Array([origin.x+at%size.x,origin.y+at/size.x]))
	var recipe: Dictionary={"size":size,"origin":origin,"seed":input.get("seed"),"profile":input.profile.get("name"),
		"parameters":input.profile.duplicate(),"activation":activation,"protected":{},"rounds":options.get("rounds"),
		"shared_extent":options.get("shared_extent"),"orientation":options.get("orientation_preference"),"optional":options.get("optional_negotiation"),
		"shared_ownership":options.get("shared_ownership",true),
		"compact_native_termination":options.get("compact_native_termination",false),
		"supported_native_receptors":options.get("supported_native_receptors",false),
		"negotiated_recovery":options.get("negotiated_recovery",false)}
	var mosaic: Variant=document.input.get("mosaic")
	if not mosaic is Dictionary or not mosaic.get("profile") is Dictionary: return fail("Saved construction has no independent MOSAIC controls.")
	recipe["gentek_parameters"]={"frame":input.profile.duplicate(),"mosaic":mosaic.profile.duplicate()}
	var territory: Variant=receipt.get("authoring_territory",{"layout":"left_right","border":0})
	if not territory is Dictionary or not territory.get("layout") is String or not integer(territory.get("border"),0,16):
		return fail("Saved construction has invalid authoring territory settings.")
	recipe["layout"]=territory.layout;recipe["border"]=int(territory.border)
	if not document.input.get("shared_zone") is Array or document.input.shared_zone.size()!=count:
		return fail("Saved construction has an incomplete negotiated ownership mask.")
	var prepared: Dictionary={"recipe":recipe,"context":PackedInt32Array(input.context),"protected":PackedByteArray(input.protected),
		"interface":PackedByteArray(input.transition),"shared":PackedByteArray(document.input.shared_zone),
		"guards":guards,"request_sha256":receipt.get("request_sha256","")}
	var result:=decode_document(document,bytes,prepared,str(receipt.get("native_source","")),true)
	if not result.ok: return result
	result["prepared"]=prepared;result["receipt"]=receipt
	return result

static func round_cells(result: Dictionary, round_index: int) -> Array:
	if round_index<0 or round_index>=result.rounds.size():
		return result.cells if not result.cells.is_empty() else result.input.frame.context
	var round_value: Dictionary = result.rounds[round_index]
	var frame: Array = round_value.proposed_frame.cells
	var mosaic: Array = round_value.proposed_mosaic.cells
	var merged: Array = result.input.frame.context.duplicate()
	for at: int in merged.size():
		if frame.size()==merged.size() and int(frame[at])!=0: merged[at]=frame[at]
		if mosaic.size()==merged.size() and int(mosaic[at])!=0: merged[at]=mosaic[at]
	return merged

static func proposal_record(result: Dictionary, round_index: int, at: int) -> Array:
	var round_value: Dictionary=result.rounds[round_index]
	var frame: Dictionary=round_value.proposed_frame
	var mosaic: Dictionary=round_value.proposed_mosaic
	var has_frame: bool=at<frame.cells.size() and int(frame.cells[at])!=0
	var has_mosaic: bool=at<mosaic.cells.size() and int(mosaic.cells[at])!=0
	if has_frame and has_mosaic: return [4,0,0,0,0,0]
	if has_frame: return [1,int(frame.provenance[at]),0,0,0,0]
	if has_mosaic: return [2,int(mosaic.provenance[at]),0,0,0,0]
	return [3 if int(result.input.frame.context[at])!=0 else 0,0,0,0,0,0]

static func socket_records(result: Dictionary, round_index: int) -> Array[Dictionary]:
	# Provisional views consume only the actual provisional native sockets. Final
	# assembly certificates never get projected onto an earlier rejected proposal.
	var records: Array[Dictionary]=[]
	if result.rounds.is_empty(): return records
	var final: Dictionary=result.damage_derivative if result.get("damage_derivative") is Dictionary else result.rounds.back()
	var snapshots: Dictionary={"FRAMEWEAVER":final.frame.result,"MOSAIC":final.mosaic.result}
	if round_index>=0:
		var shown: Dictionary=result.rounds[round_index]
		snapshots={"FRAMEWEAVER":shown.proposed_frame,"MOSAIC":shown.proposed_mosaic}
	for owner: String in ["FRAMEWEAVER","MOSAIC"]:
		var snapshot: Dictionary=snapshots[owner]
		for kind: String in ["socket","receptor"]:
			var source: Array=snapshot.get("connectors",[]) if kind=="socket" else snapshot.get("boundary",{}).get("hard",[])
			for value: Dictionary in source:
				var record:=value.duplicate();record["owner"]=owner;record["kind"]=kind
				record["obligation"]="required" if value.required else "optional"
				record["scope"]="provisional offer" if round_index>=0 else "accepted native offer"
				records.append(record)
	if round_index<0:
		for construction: Dictionary in final.frame.get("constructions",[]):
			for value: Dictionary in construction.assembly.get("sockets",[]):
				var record:=value.duplicate();record["owner"]="FRAMEWEAVER";record["kind"]="assembly socket"
				record["scope"]="authored assembly contract";records.append(record)
	return records

static func socket_points(record: Dictionary) -> Array[Vector2i]:
	var point:=Vector2i(int(record.a[0]),int(record.a[1]));var last:=Vector2i(int(record.b[0]),int(record.b[1]))
	var points: Array[Vector2i]=[]
	var dx:=absi(last.x-point.x);var dy:=-absi(last.y-point.y)
	var sx:=1 if point.x<last.x else -1;var sy:=1 if point.y<last.y else -1
	var error:=dx+dy
	# Validated endpoints fit the finite crop. The line has at most256 pixels.
	for _step: int in MAX_WIDTH+MAX_HEIGHT:
		points.append(point)
		if point==last: break
		var twice:=2*error
		if twice>=dy: error+=dy;point.x+=sx
		if twice<=dx: error+=dx;point.y+=sy
	return points

static func inspect_sockets(result: Dictionary, round_index: int, point: Vector2i) -> PackedStringArray:
	var lines:=PackedStringArray()
	for record: Dictionary in socket_records(result,round_index):
		var near:=false
		for socket_point: Vector2i in socket_points(record):
			if (socket_point-point).length_squared()<=4: near=true;break
		if not near: continue
		lines.append("%s %s %d · %s · %s · facing %s · %s%s" % [record.owner,record.kind,int(record.id),
			record.obligation,record.family,record.facing,record.scope,
			(" · "+str(record.state)+" / counterpart "+str(record.get("counterpart",0))) if record.has("state") else ""])
		if lines.size()==12: lines.append("Inspection limited to twelve nearby native offers.");break
	return lines

static func raster(result: Dictionary, prepared: Dictionary, round_index: int, layer: String) -> PackedByteArray:
	var values := round_cells(result,round_index)
	var bytes := PackedByteArray()
	bytes.resize(values.size()*4)
	var previous: Array = round_cells(result,round_index-1) if round_index>0 else Array(prepared.context)
	for at: int in values.size():
		var id := int(values[at])
		var rgba: int = Palette.BASE_RGBA8[id]
		var record: Array = result.ledger[at] if result.ledger.size()==values.size() else [0,0,0,0,0,0]
		if round_index>=0: record=proposal_record(result,round_index,at)
		if layer=="Owners" and id!=0:
			rgba = [0x080b12ff,0x62adffff,0xb88850ff,0x666c76ff,0xfc35c6ff][int(record[0])]
		elif layer=="Parts" and id!=0:
			rgba = Color.from_hsv(fposmod(float(record[1])*0.6180339+float(record[0])*0.2,1.0),0.65,0.95).to_rgba32()
		elif layer=="Revisions" and id!=0 and round_index<0:
			rgba = Color.from_hsv(float(record[4])/5.0,0.75,0.95).to_rgba32()
		elif layer=="Changed cells":
			rgba = 0xffcd57ff if int(values[at])!=int(previous[at]) else 0x19222fff
		elif layer=="Clearance" and prepared.protected[at]: rgba = 0x69e6eeff
		elif layer=="Shared zone" and prepared.shared[at]: rgba = 0x47864dff if id==0 else 0xa4e39aff
		elif layer=="Interface band" and prepared.get("interface",prepared.shared)[at]: rgba = 0x75552aff if id==0 else 0xd7ad70ff
		bytes[at*4]=(rgba>>24)&255;bytes[at*4+1]=(rgba>>16)&255;bytes[at*4+2]=(rgba>>8)&255;bytes[at*4+3]=255
	if layer=="Joints" and round_index<0:
		for joint: Dictionary in result.joints:
			for point: Array in joint.get("path",[]): _mark(bytes,prepared.recipe.size,point,Color(0.45,1,0.55))
	if layer=="Clearance" and round_index<0 and not result.rounds.is_empty():
		var frame: Dictionary=result.damage_derivative.frame if result.get("damage_derivative") is Dictionary else result.rounds.back().frame
		for slot: Dictionary in frame.get("slots",[]):
			for point: Array in slot.get("clearance",[]): _mark(bytes,prepared.recipe.size,point,Color(0.4,0.9,1))
	if layer=="Unresolved" and round_index<0:
		for obligation: Dictionary in result.obligations:
			if obligation.get("state")=="STILL_REQUIRED":
				_mark(bytes,prepared.recipe.size,obligation.get("original",[]),Color(1,0.2,0.3))
	if layer=="Sockets / receptors":
		for record: Dictionary in socket_records(result,round_index):
			var color:=Color.hex(SOCKET_COLORS[record.obligation])
			for point: Vector2i in socket_points(record): _mark(bytes,prepared.recipe.size,[point.x,point.y],color)
			var facing:=Vector2i(int(record.facing[0]),int(record.facing[1]))
			var direction:=Vector2i(int(record.a[0]),int(record.a[1]))+facing
			if facing!=Vector2i.ZERO: _mark(bytes,prepared.recipe.size,[direction.x,direction.y],Color.WHITE)
	return bytes

static func _mark(bytes: PackedByteArray, size: Vector2i, point: Array, color: Color) -> void:
	if point.size()!=2 or not integer(point[0],0,size.x-1) or not integer(point[1],0,size.y-1): return
	var at := (int(point[1])*size.x+int(point[0]))*4
	bytes[at]=int(color.r*255);bytes[at+1]=int(color.g*255);bytes[at+2]=int(color.b*255)
