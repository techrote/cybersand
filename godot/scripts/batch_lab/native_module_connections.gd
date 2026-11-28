extends RefCounted
## Exact-grid connection inspection and finite pose proposals. No World access,
## native writes, physics, load-bearing inference or SWARM negotiation.
const Module = preload("res://scripts/batch_lab/native_module.gd")
const MAX_CONNECTORS := 512
const MAX_BINDINGS := 512
const MAX_CONTACT_CELLS := 65536
const MAX_SNAP_POSES := 2048
const MAX_SNAP_SCAN_CELLS := 1048576
const MAX_RETAINED_CONTACTS := 2048
const MAX_RESERVATION_CELLS := 262144

static func _fail(reason: String, code := "invalid_contract", status := "refused") -> Dictionary:
	return {"ok":false,"status":status,"reason":reason,"code":code,"zero_writes":true}

static func _point(value: Array) -> Vector2i:
	return Vector2i(int(value[0]),int(value[1]))

static func _ref(connector: Dictionary) -> Dictionary:
	return {"instance":connector.module_instance,"connector":connector.id}

static func _key(reference: Dictionary) -> String:
	return Module.json_bytes([reference.instance,reference.connector]).get_string_from_utf8()

static func _cell_key(point: Vector2i) -> String:
	return str(point.x)+","+str(point.y)

static func _span(connector: Dictionary) -> Array[Vector2i]:
	var start := _point(connector.point)
	var end := _point(connector.get("end",connector.point))
	# Endpoint order belongs to the stored document. Only this derived contact
	# span is ordered; mirrors and reversed endpoints never rewrite its identity.
	if end.x<start.x or (end.x==start.x and end.y<start.y):
		var swap := start; start = end; end = swap
	var step := Vector2i(signi(end.x-start.x),signi(end.y-start.y))
	var result: Array[Vector2i] = []
	for index: int in absi(end.x-start.x)+absi(end.y-start.y)+1: result.append(start+step*index)
	return result

static func _material(point: Vector2i, context: Dictionary) -> int:
	var region := Module.rect(context.region)
	if not region.has_point(point): return -1
	var local := point-region.position
	return context.projected_cells.decode_u16((local.y*region.size.x+local.x)*2)

static func _valid_reference(value: Variant) -> bool:
	return value is Dictionary and Module._keys(value,["instance","connector"]) \
		and (Module.identifier(value.instance) or (Module.integer(value.instance) and int(value.instance)>=0)) \
		and Module.identifier(value.connector)

static func _validate_context(context: Dictionary) -> Dictionary:
	var region := Module.rect(context.get("region"))
	if region.size.x<1 or region.size.y<1 or region.size.x>Module.MAX_SIDE or region.size.y>Module.MAX_SIDE \
		or not context.get("projected_cells") is PackedByteArray or context.projected_cells.size()!=region.get_area()*2:
		return _fail("Connection inspection needs one complete bounded projected material plane and its world-coordinate region.")
	return {"ok":true}

static func _validate_connector(connector: Variant) -> Dictionary:
	if not connector is Dictionary or not connector.has_all(["module_instance","id","point","facing","kind","required","source","compatibility"]):
		return _fail("Connection descriptor is missing its instance or declared fields.")
	if not _valid_reference(_ref(connector)) or not Module._pair(connector.point) or not Module._pair(connector.facing) \
		or absi(int(connector.facing[0]))+absi(int(connector.facing[1]))!=1 \
		or connector.kind not in ["vertex","line","socket","receptor"] or not connector.required is bool \
		or not Module._strings(connector.compatibility,16,64) or connector.compatibility.is_empty() \
		or connector.source not in ["authored","inferred"] or (connector.required and connector.source!="authored"):
		return _fail("Malformed transformed connector identity, orientation or semantics.")
	if connector.kind=="line":
		if not Module._pair(connector.get("end")) or connector.end==connector.point \
			or (connector.end[0]!=connector.point[0] and connector.end[1]!=connector.point[1]) \
			or absi(int(connector.end[0])-int(connector.point[0]))+absi(int(connector.end[1])-int(connector.point[1]))>=Module.MAX_SIDE:
			return _fail("Transformed contact line exceeds its bounded inclusive axis-aligned span.")
	elif connector.has("end"): return _fail("A point connector cannot carry a line endpoint.")
	var format: Variant = connector.get("module_format",Module.FORMAT)
	if format not in [Module.FORMAT,Module.FORMAT_V2]: return _fail("Unknown connector contract version.")
	if format==Module.FORMAT: return {"ok":true}
	if not connector.has_all(["role","approach","polarity","capacity","contact","own_contact_cells"]) \
		or not Module.identifier(connector.role) or connector.approach!="face" \
		or connector.polarity not in ["neutral","socket","receptor"] \
		or not Module.integer(connector.capacity) or int(connector.capacity)<1 or int(connector.capacity)>16:
		return _fail("V2 transformed connector lacks its bounded face/capacity contract.")
	if (connector.kind in ["socket","receptor"] and connector.polarity!=connector.kind) \
		or (connector.kind=="vertex" and connector.polarity!="neutral"):
		return _fail("V2 point connector kind and polarity disagree.")
	if not connector.contact is Dictionary or not Module._keys(connector.contact,["policy","minimum_cells","tolerance"]) \
		or connector.contact.policy not in ["full","overlap"] or not Module.integer(connector.contact.minimum_cells) \
		or not Module.integer(connector.contact.tolerance) or int(connector.contact.tolerance)!=0:
		return _fail("V2 transformed contact needs zero-tolerance full or overlap semantics.")
	var points := _span(connector)
	if (points[-1].x-points[0].x)*int(connector.facing[0])+(points[-1].y-points[0].y)*int(connector.facing[1])!=0 \
		or int(connector.contact.minimum_cells)<1 or int(connector.contact.minimum_cells)>points.size() \
		or (connector.contact.policy=="full" and int(connector.contact.minimum_cells)!=points.size()) \
		or (connector.kind!="line" and (connector.contact.policy!="full" or int(connector.capacity)!=1)):
		return _fail("Invalid perpendicular span, contact minimum or exclusive point capacity.")
	if not connector.own_contact_cells is Array or connector.own_contact_cells.size()!=points.size():
		return _fail("V2 contact must retain the compiler's complete own-geometry contact cells.")
	var own := {}
	for raw: Variant in connector.own_contact_cells:
		if not Module._pair(raw): return _fail("Malformed own-geometry contact cell.")
		var key := _cell_key(_point(raw))
		if own.has(key): return _fail("Duplicated own-geometry contact cell.")
		own[key] = true
	for point: Vector2i in points:
		if not own.has(_cell_key(point)): return _fail("Own-geometry contact span is incomplete.")
	return {"ok":true}

static func _compatible(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.module_instance==b.module_instance: return _fail("A module cannot mate with itself.","same_instance")
	if a.get("module_format",Module.FORMAT)!=b.get("module_format",Module.FORMAT):
		return _fail("V1 and V2 connectors require an explicit authored adapter part.","version_mismatch")
	if _point(a.facing)!=-_point(b.facing): return _fail("Connector faces do not oppose each other.","facing_mismatch")
	var shared := false
	for tag: String in a.compatibility:
		if tag in b.compatibility: shared = true; break
	if not shared: return _fail("Connector compatibility tags do not intersect.","tag_mismatch")
	if a.get("module_format",Module.FORMAT)==Module.FORMAT:
		if a.kind=="line" or b.kind=="line": return _fail("V1 required attachment lines remain unsupported.","legacy_line")
		if a.kind in ["socket","receptor"] and b.kind!=("receptor" if a.kind=="socket" else "socket"):
			return _fail("Legacy socket and receptor polarity differs.","polarity_mismatch")
		return {"ok":true}
	if (a.kind=="line")!=(b.kind=="line"): return _fail("Point-to-line contact needs an explicit adapter part.","span_kind_mismatch")
	if a.polarity=="neutral" and b.polarity!="neutral" or a.polarity!="neutral" and b.polarity!=("receptor" if a.polarity=="socket" else "socket"):
		return _fail("V2 connector polarities are incompatible.","polarity_mismatch")
	if a.role!=b.role: return _fail("V2 connector functional roles differ.","role_mismatch")
	return {"ok":true}

static func _contact(a: Dictionary, b: Dictionary, context: Dictionary) -> Dictionary:
	var compatible := _compatible(a,b)
	if not compatible.ok: return compatible
	if a.get("module_format",Module.FORMAT)==Module.FORMAT:
		var ap := _point(a.point); var bp := _point(b.point)
		if bp!=ap and bp!=ap+_point(a.facing): return _fail("Legacy endpoints are neither coincident nor face adjacent.","no_contact")
		if _material(ap,context)<=0 or _material(bp,context)<=0: return _fail("Legacy endpoint is not occupied in the projection.","ungrounded")
		return {"ok":true,"a":_ref(a),"b":_ref(b),"a_span":[ap.x,ap.y,ap.x,ap.y],"b_span":[bp.x,bp.y,bp.x,bp.y],
			"a_cells":[[ap.x,ap.y]],"b_cells":[[bp.x,bp.y]],"cell_count":1,"contract":"legacy-point-v1"}
	# Reject separated spans before expanding their bounded cell lists. This
	# keeps large optional connector inventories cheap to inspect.
	var a_first := _point(a.point)+_point(a.facing)
	var a_last := _point(a.get("end",a.point))+_point(a.facing)
	var b_first := _point(b.point); var b_last := _point(b.get("end",b.point))
	var a_box := Rect2i(Vector2i(mini(a_first.x,a_last.x),mini(a_first.y,a_last.y)),Vector2i(absi(a_last.x-a_first.x)+1,absi(a_last.y-a_first.y)+1))
	var b_box := Rect2i(Vector2i(mini(b_first.x,b_last.x),mini(b_first.y,b_last.y)),Vector2i(absi(b_last.x-b_first.x)+1,absi(b_last.y-b_first.y)+1))
	if not a_box.intersects(b_box): return _fail("Declared faces do not have adjacent contact cells.","no_contact")
	var a_points := _span(a); var b_points := _span(b)
	var b_set := {}
	for point: Vector2i in b_points: b_set[_cell_key(point)] = true
	var a_cells: Array = []; var b_cells: Array = []
	for point: Vector2i in a_points:
		var other := point+_point(a.facing)
		if b_set.has(_cell_key(other)):
			if _material(point,context)<=0 or _material(other,context)<=0: return _fail("Contact face is not occupied in the final projection.","ungrounded")
			a_cells.append([point.x,point.y]); b_cells.append([other.x,other.y])
	if a_cells.size()<maxi(int(a.contact.minimum_cells),int(b.contact.minimum_cells)):
		return _fail("Occupied adjacent contact is shorter than the declared minimum.","insufficient_overlap")
	if (a.contact.policy=="full" or b.contact.policy=="full") and (a_cells.size()!=a_points.size() or b_cells.size()!=b_points.size()):
		return _fail("Full-span contact must cover both complete inclusive spans.","full_span_mismatch")
	var first_a: Array = a_cells[0]; var last_a: Array = a_cells[-1]
	var first_b: Array = b_cells[0]; var last_b: Array = b_cells[-1]
	return {"ok":true,"a":_ref(a),"b":_ref(b),"a_span":[first_a[0],first_a[1],last_a[0],last_a[1]],
		"b_span":[first_b[0],first_b[1],last_b[0],last_b[1]],"a_cells":a_cells,"b_cells":b_cells,
		"cell_count":a_cells.size(),"contract":"face-adjacent-grid-v2"}

static func _reservation(contact_value: Dictionary, index: Dictionary, occupancy: Dictionary, apply := false) -> Dictionary:
	for side: String in ["a","b"]:
		var reference: Dictionary = contact_value[side]
		var key := _key(reference)
		var other_key := _key(contact_value["b" if side=="a" else "a"])
		var connector: Dictionary = index[key]
		var booked: Dictionary = occupancy.get(key,{"partners":[],"cells":{}})
		if other_key in booked.partners: return _fail("The same instance/connector pair is already bound.","duplicate_binding")
		if connector.get("module_format",Module.FORMAT)==Module.FORMAT_V2:
			if booked.partners.size()>=int(connector.capacity): return _fail("Connector partner capacity is exhausted.","capacity_exhausted","exhausted")
			for raw: Array in contact_value[side+"_cells"]:
				if booked.cells.has(_cell_key(_point(raw))): return _fail("An exclusive contact interval is already reserved.","contact_occupied","exhausted")
	if apply:
		for side: String in ["a","b"]:
			var key := _key(contact_value[side])
			if not occupancy.has(key): occupancy[key] = {"partners":[],"cells":{}}
			var other_key := _key(contact_value["b" if side=="a" else "a"])
			occupancy[key].partners.append(other_key)
			for raw: Array in contact_value[side+"_cells"]: occupancy[key].cells[_cell_key(_point(raw))] = other_key
	return {"ok":true}

static func resolve(connectors: Array, bindings: Array = [], context: Dictionary = {}) -> Dictionary:
	if connectors.size()>MAX_CONNECTORS or bindings.size()>MAX_BINDINGS: return _fail("Connection graph exceeds its bounded descriptors or bindings.")
	var inspected := _validate_context(context)
	if not inspected.ok: return inspected
	var existing: Variant = context.get("existing_bindings",[])
	if not existing is Array or existing.size()+bindings.size()>MAX_BINDINGS: return _fail("Existing reservations exceed the bounded connection graph.")
	var index := {}; var checked_cells := 0; var occupied_faces := {}
	for connector: Variant in connectors:
		var checked := _validate_connector(connector)
		if not checked.ok: return checked
		var key := _key(_ref(connector))
		if index.has(key): return _fail("A placed instance declares the same connector twice.")
		index[key] = connector
		var points := _span(connector)
		checked_cells += points.size()
		if checked_cells>MAX_CONTACT_CELLS: return _fail("Connection inspection exceeds 65,536 contact cells.")
		if connector.get("module_format",Module.FORMAT)==Module.FORMAT_V2:
			for point: Vector2i in points:
				var face_key := Module.json_bytes([point.x,point.y,connector.facing]).get_string_from_utf8()
				if occupied_faces.has(face_key): return _fail("Different connectors or placed instances cannot reserve the same occupied outward face.","aliased_face")
				occupied_faces[face_key] = true
				if _material(point,context)<=0: return _fail("A V2 declared face lost its own occupied material in the projection.","ungrounded")
	var occupancy := {}; var contacts: Array = []; var satisfied := {}
	for binding: Variant in existing+bindings:
		if not binding is Dictionary or not Module._keys(binding,["a","b"]) or not _valid_reference(binding.a) or not _valid_reference(binding.b):
			return _fail("Explicit binding must identify two concrete instance/connector references.")
		var a_key := _key(binding.a); var b_key := _key(binding.b)
		if not index.has(a_key) or not index.has(b_key): return _fail("A binding references a connector outside the inspected graph.")
		var joined := _contact(index[a_key],index[b_key],context)
		if not joined.ok: return joined
		var reserved := _reservation(joined,index,occupancy,true)
		if not reserved.ok: return reserved
		joined["binding_source"] = "explicit"
		contacts.append(joined); satisfied[a_key] = true; satisfied[b_key] = true
	var keys: Array = index.keys(); keys.sort()
	for key: String in keys:
		var connector: Dictionary = index[key]
		if not connector.required or satisfied.has(key): continue
		if connector.get("module_format",Module.FORMAT)==Module.FORMAT and connector.kind=="line":
			return _fail("V1 required attachment lines remain unsupported; author an explicit V2 contract.","legacy_line")
		var eligible: Array = []; var blocked := false
		for other_key: String in keys:
			if other_key==key: continue
			var joined := _contact(connector,index[other_key],context)
			if not joined.ok: continue
			var reserved := _reservation(joined,index,occupancy)
			if not reserved.ok: blocked = true; continue
			eligible.append(joined)
		if eligible.is_empty(): return _fail("Required connector has no available compatible occupied partner: "+str(connector.id),"capacity_exhausted" if blocked else "unmatched_required","exhausted" if blocked else "refused")
		# V1 intentionally retains its legacy first matching point behavior.
		if connector.get("module_format",Module.FORMAT)==Module.FORMAT_V2 and eligible.size()>1:
			return _fail("Required V2 connector has multiple eligible partners; select an explicit binding.","ambiguous_partner")
		var chosen: Dictionary = eligible[0]
		var reservation := _reservation(chosen,index,occupancy,true)
		if not reservation.ok: return reservation
		chosen["binding_source"] = "unique-required-partner"
		contacts.append(chosen); satisfied[_key(chosen.a)] = true; satisfied[_key(chosen.b)] = true
	var occupancy_rows: Array = []; var unmatched: Array = []
	for key: String in keys:
		var connector: Dictionary = index[key]
		var booked: Dictionary = occupancy.get(key,{"partners":[],"cells":{}})
		occupancy_rows.append({"connector":_ref(connector),"partners":booked.partners.duplicate(),"used_partners":booked.partners.size(),
			"capacity":int(connector.get("capacity",0)),"reserved_contact_cells":booked.cells.size(),"contract":connector.get("module_format",Module.FORMAT)})
		if not satisfied.has(key): unmatched.append(_ref(connector))
	return {"ok":true,"status":"resolved","zero_writes":true,"contacts":contacts,"occupancy":occupancy_rows,
		"unmatched":unmatched,"diagnostics":[],"checked_contact_cells":checked_cells,
		"scope":"Static occupied grid contact and logical partner reservations only; no physical support or fresh native execution claim."}

static func inspect_connections(module: Dictionary, placement: Dictionary, constraints: Dictionary) -> Dictionary:
	var compiled := Module.compile(module,placement,constraints)
	if not compiled.ok: return compiled
	return {"ok":true,"zero_writes":true,"connections":compiled.connections,"footprint":compiled.footprint,
		"clearances":compiled.clearances,"protected_regions":compiled.protected_regions,"diagnostics":[]}

static func _validate_contact_record(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("contract")!="face-adjacent-grid-v2" or not _valid_reference(value.get("a")) or not _valid_reference(value.get("b")) \
		or value.a.instance==value.b.instance or not value.get("a_cells") is Array or not value.get("b_cells") is Array \
		or value.a_cells.is_empty() or value.a_cells.size()>Module.MAX_SIDE or value.a_cells.size()!=value.b_cells.size() \
		or not Module.integer(value.get("cell_count")) or int(value.cell_count)!=value.a_cells.size():
		return _fail("Retained contact lacks exact bounded instance references and paired material faces.","invalid_retained_contact")
	var normal := Vector2i.ZERO; var seen := {}; var prior := Vector2i.ZERO; var tangent := Vector2i.ZERO
	for i: int in value.a_cells.size():
		if not Module._pair(value.a_cells[i]) or not Module._pair(value.b_cells[i]): return _fail("Malformed retained contact coordinate.","invalid_retained_contact")
		var a := _point(value.a_cells[i]); var b := _point(value.b_cells[i]); var facing := b-a
		if absi(facing.x)+absi(facing.y)!=1 or (i>0 and facing!=normal): return _fail("Retained contact must preserve exactly one outward adjacent normal.","invalid_retained_contact")
		normal = facing
		if seen.has(_cell_key(a)): return _fail("Repeated retained contact cell.","invalid_retained_contact")
		seen[_cell_key(a)] = true
		if i>0:
			var step := a-prior
			if absi(step.x)+absi(step.y)!=1 or step.x*normal.x+step.y*normal.y!=0 or (i>1 and step!=tangent):
				return _fail("Retained line contact must be a contiguous straight inclusive interval.","invalid_retained_contact")
			tangent=step
		prior=a
	return {"ok":true,"normal":normal}

static func check_reserved_contacts(current: Array, connectors: Array, retained: Variant) -> Dictionary:
	# Retained records are supplied only by the live host. They reserve physical
	# occupied faces even when the other endpoint lies outside this inspection.
	# This does not requalify their old materials; fresh host admission owns that.
	if not retained is Array or retained.size()>MAX_RETAINED_CONTACTS or current.size()>MAX_BINDINGS or connectors.size()>MAX_CONNECTORS:
		return _fail("Live connection reservations exceed their explicit bounded envelope.","reservation_budget")
	var index := {}
	for connector: Variant in connectors:
		var checked := _validate_connector(connector)
		if not checked.ok: return checked
		var key := _key(_ref(connector))
		if index.has(key): return _fail("Duplicate connector identity in reservation context.","invalid_retained_contact")
		index[key]=connector
	var partners := {}; var faces := {}; var pairs := {}; var scanned := 0; var unique_contacts := 0
	for record_value: Variant in retained+current:
		if record_value is Dictionary and record_value.get("contract")=="legacy-point-v1": continue
		var checked := _validate_contact_record(record_value)
		if not checked.ok: return checked
		var value: Dictionary=record_value
		scanned += value.a_cells.size()*2
		if scanned>MAX_RESERVATION_CELLS: return _fail("Live reservation inspection exceeds 262,144 paired face cells.","reservation_budget")
		var a_key := _key(value.a); var b_key := _key(value.b)
		var ordered := [a_key,b_key]; ordered.sort()
		var pair_key := Module.json_bytes(ordered).get_string_from_utf8()
		var ordered_cells: Array = [value.a_cells,value.b_cells] if ordered[0]==a_key else [value.b_cells,value.a_cells]
		# Endpoint order may be reversed while denoting the same physical interval.
		if ordered_cells[0].size()>1 and (_point(ordered_cells[0][-1]).x<_point(ordered_cells[0][0]).x \
			or (_point(ordered_cells[0][-1]).x==_point(ordered_cells[0][0]).x and _point(ordered_cells[0][-1]).y<_point(ordered_cells[0][0]).y)):
			ordered_cells=ordered_cells.duplicate(true); ordered_cells[0].reverse(); ordered_cells[1].reverse()
		var cells_key := Module.digest(Module.json_bytes(ordered_cells))
		if pairs.has(pair_key):
			if pairs[pair_key]!=cells_key: return _fail("A retained connector pair cannot silently move or expand its booked interval.","binding_changed")
			continue
		pairs[pair_key]=cells_key; unique_contacts += 1
		for side: String in ["a","b"]:
			var reference: Dictionary=value[side]; var key := _key(reference)
			var other_key := _key(value["b" if side=="a" else "a"])
			if not partners.has(key): partners[key]={}
			partners[key][other_key]=true
			var normal: Vector2i=checked.normal if side=="a" else -checked.normal
			for raw: Array in value[side+"_cells"]:
				var face_key := Module.json_bytes([raw[0],raw[1],[normal.x,normal.y]]).get_string_from_utf8()
				if faces.has(face_key): return _fail("An occupied outward face is already reserved, including under another placed-instance identity.","contact_occupied")
				faces[face_key]=pair_key
	for key: String in partners:
		if index.has(key) and index[key].get("module_format",Module.FORMAT)==Module.FORMAT_V2 \
			and partners[key].size()>int(index[key].capacity):
			return _fail("The union of retained and newly proposed partners exceeds connector capacity.","capacity_exhausted","exhausted")
	return {"ok":true,"zero_writes":true,"unique_contacts":unique_contacts,"checked_contact_cells":scanned,
		"retained_contacts":retained.size(),"proposed_contacts":current.size(),"scope":"Conservative live-host logical and physical face reservations; no historical import or native readback authority."}

static func _snap_failure(reason: String, status := "refused") -> Dictionary:
	return {"ok":false,"status":status,"zero_writes":true,"candidates":[],"considered":0,"truncated":false,"reasons":[reason]}

static func snap_candidates(module: Dictionary, source_connector_id: String, target: Dictionary, controls: Dictionary) -> Dictionary:
	var checked := Module.validate(module)
	if not checked.ok: return _snap_failure(checked.reason)
	if module.format!=Module.FORMAT_V2: return _snap_failure("Snap requires an explicit V2 contract; V1 remains inspectable and manually placeable.")
	var target_check := _validate_connector(target)
	if not target_check.ok: return _snap_failure(target_check.reason)
	if target.get("module_format",Module.FORMAT)!=Module.FORMAT_V2: return _snap_failure("A V2 snap target must use the same versioned face contract.")
	var context_check := _validate_context(controls)
	if not context_check.ok: return _snap_failure(context_check.reason)
	var source: Dictionary = {}
	for connector: Dictionary in module.attachments:
		if connector.id==source_connector_id: source = connector; break
	if source.is_empty(): return _snap_failure("Unknown source connector.")
	var transforms: Variant = controls.get("transforms",module.allowed_transforms)
	if not transforms is Array or transforms.is_empty() or transforms.size()>Module.TRANSFORMS.size(): return _snap_failure("Choose a bounded list of permitted grid transforms.")
	var seen_transforms := {}
	for transform: Variant in transforms:
		if transform not in module.allowed_transforms or seen_transforms.has(transform): return _snap_failure("Snap transform is not permitted or is duplicated.")
		seen_transforms[transform] = true
	var instance: Variant = controls.get("source_instance","candidate")
	if not _valid_reference({"instance":instance,"connector":source_connector_id}) or instance==target.module_instance: return _snap_failure("Snap source needs a distinct stable placed-instance identity.")
	var region := Module.rect(controls.region)
	var preferred: Variant = controls.get("preferred_origin",[region.position.x,region.position.y])
	var limit: Variant = controls.get("limit",24); var search_budget: Variant = controls.get("search_budget",256)
	if not Module._pair(preferred) or not Module.integer(limit) or int(limit)<1 or int(limit)>64 \
		or not Module.integer(search_budget) or int(search_budget)<1 or int(search_budget)>MAX_SNAP_POSES:
		return _snap_failure("Invalid snap origin, result limit or finite search budget.")
	var existing: Variant = controls.get("existing_connectors",[target])
	var bindings: Variant = controls.get("bindings",[])
	var retained: Variant = controls.get("reserved_contacts",[])
	if not existing is Array or existing.size()>=MAX_CONNECTORS or not bindings is Array or bindings.size()>=MAX_BINDINGS:
		return _snap_failure("Snap context exceeds its connector/binding envelope.")
	if not retained is Array or retained.size()>MAX_RETAINED_CONTACTS: return _snap_failure("Snap retained contact history exceeds its explicit bound.")
	var target_present := false
	for connector: Variant in existing:
		var valid := _validate_connector(connector)
		if not valid.ok: return _snap_failure(valid.reason)
		if connector.module_instance==instance: return _snap_failure("Candidate instance already exists in the snap context.")
		if _ref(connector)==_ref(target):
			if connector!=target: return _snap_failure("Snap target differs from the inspected connector inventory.")
			target_present = true
	if not target_present: return _snap_failure("Snap target must belong to the inspected connector inventory.")
	for key: String in ["protected","clearances"]:
		if not controls.get(key,[]) is Array or controls.get(key,[]).size()>256: return _snap_failure("Invalid bounded snap protection/clearance list.")
		for raw: Variant in controls.get(key,[]):
			if Module.rect(raw).size.x<1 or Module.rect(raw).size.y<1: return _snap_failure("Invalid snap protection/clearance rectangle.")
	var poses: Array = []; var target_span := _span(target)
	for transform: String in transforms:
		var local := source.duplicate(true)
		var p := Module.transform_point(_point(local.point),checked.extent,transform)
		local.point = [p.x,p.y]
		var f := Module.transform_direction(_point(local.facing),transform)
		local.facing = [f.x,f.y]
		if local.has("end"):
			var e := Module.transform_point(_point(local.end),checked.extent,transform); local.end = [e.x,e.y]
		local["module_instance"] = instance; local["module_format"] = module.format
		if not _compatible(local,target).ok: continue
		var source_span := _span(local)
		var origins: Array[Vector2i] = []
		if source.kind!="line" or source.contact.policy=="full" or target.contact.policy=="full":
			if source_span.size()!=target_span.size(): continue
			origins.append(target_span[0]-f-source_span[0])
		else:
			var minimum := maxi(int(source.contact.minimum_cells),int(target.contact.minimum_cells))
			if minimum>mini(source_span.size(),target_span.size()): continue
			var horizontal := source_span[0].y==source_span[-1].y
			var lo := (target_span[0].x if horizontal else target_span[0].y)+minimum-1-(source_span[-1].x if horizontal else source_span[-1].y)
			var hi := (target_span[-1].x if horizontal else target_span[-1].y)-minimum+1-(source_span[0].x if horizontal else source_span[0].y)
			for tangent: int in range(lo,hi+1):
				origins.append(Vector2i(tangent,target_span[0].y-f.y-source_span[0].y) if horizontal else Vector2i(target_span[0].x-f.x-source_span[0].x,tangent))
		for origin: Vector2i in origins:
			if not region.encloses(Rect2i(origin,Module.transformed_size(checked.extent,transform))): continue
			poses.append({"origin":[origin.x,origin.y],"transform":transform,"distance":absi(origin.x-int(preferred[0]))+absi(origin.y-int(preferred[1])),"order":transforms.find(transform)})
	poses.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.distance!=b.distance: return a.distance<b.distance
		if a.order!=b.order: return a.order<b.order
		if a.origin[1]!=b.origin[1]: return a.origin[1]<b.origin[1]
		return a.origin[0]<b.origin[0])
	var candidates: Array = []; var reasons: Array = []; var considered := 0; var scan_cells := 0; var truncated := false
	for pose: Dictionary in poses:
		if considered>=int(search_budget) or scan_cells+checked.extent.x*checked.extent.y>MAX_SNAP_SCAN_CELLS:
			truncated = true; break
		considered += 1; scan_cells += checked.extent.x*checked.extent.y
		var placement := {"origin":pose.origin,"transform":pose.transform}
		if controls.has("palette"): placement["palette"] = controls.palette
		if controls.has("variation"): placement["variation"] = controls.variation
		var compiled := Module.compile(module,placement,controls)
		if not compiled.ok:
			if compiled.reason not in reasons and reasons.size()<8: reasons.append(compiled.reason)
			continue
		var projection: PackedByteArray = controls.projected_cells.duplicate()
		var valid := true
		for offset: int in range(0,compiled.cells.size(),3):
			var point := Vector2i(compiled.cells[offset],compiled.cells[offset+1])
			if Module._in_regions(point,controls.get("clearances",[])): valid = false; break
			var at := ((point.y-region.position.y)*region.size.x+point.x-region.position.x)*2
			var old := projection.decode_u16(at); var material: int = compiled.cells[offset+2]
			# A snapped candidate fits available negative space. Manual plans may
			# separately request the host's normal admitted overwrite/no-op policy.
			if old!=0: valid = false; break
			projection.encode_u16(at,material)
		if not valid:
			if "Candidate conflicts with stored material or protected clearance." not in reasons: reasons.append("Candidate conflicts with stored material or protected clearance.")
			continue
		var inspection := {"region":controls.region,"projected_cells":projection,"existing_bindings":bindings}
		for raw: Array in compiled.clearances+controls.get("clearances",[]):
			var box := Module.rect(raw)
			if not region.encloses(box): valid = false; break
			for y: int in range(box.position.y,box.end.y):
				for x: int in range(box.position.x,box.end.x):
					if _material(Vector2i(x,y),inspection)!=0: valid = false; break
				if not valid: break
			if not valid: break
		if not valid: continue
		var connectors: Array = existing.duplicate(true)
		for connector: Dictionary in compiled.connections:
			var item := connector.duplicate(true); item["module_instance"] = instance; connectors.append(item)
		var binding := {"a":{"instance":instance,"connector":source_connector_id},"b":_ref(target)}
		var resolved := resolve(connectors,[binding],inspection)
		if not resolved.ok:
			if resolved.reason not in reasons and reasons.size()<8: reasons.append(resolved.reason)
			continue
		var reservations := check_reserved_contacts(resolved.contacts,connectors,retained)
		if not reservations.ok:
			if reservations.reason not in reasons and reasons.size()<8: reasons.append(reservations.reason)
			continue
		var joined: Dictionary = {}
		for value: Dictionary in resolved.contacts:
			if value.a==binding.a and value.b==binding.b: joined = value; break
		candidates.append({"placement":placement,"source_connector":binding.a,"target":binding.b,"contact":joined,
			"budget":compiled.budget,"footprint":compiled.footprint,"module_sha256":module.content_sha256})
		if candidates.size()>=int(limit): truncated = considered<poses.size(); break
	if candidates.is_empty() and reasons.is_empty(): reasons.append("No compatible fitting pose exists in the supplied finite grid context.")
	return {"ok":not candidates.is_empty(),"status":"found" if not candidates.is_empty() else ("exhausted" if truncated else "refused"),
		"zero_writes":true,"candidates":candidates,"considered":considered,"truncated":truncated,"reasons":reasons,
		"scan_cells":scan_cells,"scope":"Finite zero-write pose proposals against supplied bytes. Fresh native stage admission remains mandatory."}
