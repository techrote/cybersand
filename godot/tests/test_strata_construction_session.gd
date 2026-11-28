extends SceneTree

## Adversarial owner-contract fixtures. The owner below is deliberately a copied
## value fixture, not a native World. Mounted ordinary/native tests are separate.
const Module = preload("res://scripts/depth/strata_native_module.gd")
const Plan = preload("res://scripts/depth/strata_construction_plan.gd")
const Session = preload("res://scripts/depth/strata_construction_session.gd")
const Provenance = preload("res://scripts/depth/strata_authoring_provenance.gd")
const Executor = preload("res://scripts/workbench_paint_editor_executor.gd")
const Codec = preload("res://scripts/depth/strata_import_codec.gd")

class FixtureHost extends RefCounted:
	var planes: Dictionary = {}
	var revisions: Dictionary = {}
	var authored_serials: Dictionary = {}
	var history: Dictionary = {}
	var generation := 1
	var visible := true
	var published := true
	var delayed := false
	var hold_ack := false
	var prefix_limit := -1
	var wrong_owner := false
	var bad_receipt := false
	var bad_applied := false
	var bad_capture := false
	var readback_failure := false
	var disturb_no_write := false
	var permission := "a".repeat(64)
	var records := {"version": 1, "records": []}
	var capacity_records := 64
	var capacity_bytes := 262144
	var rectangles := 0
	var max_rectangles := 32768
	var prior_undo := 0
	var calls: Array = []
	var serial := 0
	var pending: Dictionary = {}
	var writes := 0

	func _init() -> void:
		for id: String in ["play", "scripted", "effects", "background"]:
			var cells := PackedInt32Array(); cells.resize(512 * 512)
			planes[id] = cells; revisions[id] = 1; authored_serials[id] = 1; history[id] = []

	func authoring_plane_state(id: String) -> Dictionary:
		return {"ok": true, "error": "", "scene_id": "scene:1", "owner_id": id + ":owner", "generation": generation,
			"revision": revisions[id], "authored_serial": authored_serials[id], "extent": [512, 512], "paint_allowed": visible, "erase_allowed": visible,
			"permission_sha256": permission, "authored_rectangles": rectangles, "authored_layout_writes": 0,
			"max_rectangles": max_rectangles, "max_layout_writes": 16777216,
			"history_limit": 32, "undo_count": prior_undo + history[id].size(),
			"remaining_authoring_records": capacity_records - records.records.size(), "remaining_authoring_bytes": capacity_bytes}

	func authoring_capture(id: String, region: Rect2i, expected: Dictionary) -> Dictionary:
		calls.append({"kind": "capture", "plane": id, "count": region.get_area()})
		if delayed:
			serial += 1; pending[serial] = {"kind": "capture", "id": id, "region": region, "expected": expected.duplicate(true)}
			return {"ok": true, "pending": true, "operation_id": serial}
		return _capture(id, region)

	func _capture(id: String, region: Rect2i) -> Dictionary:
		if readback_failure and writes > 0: return {"ok": false, "error": "injected postcommit readback refusal"}
		var materials := PackedInt32Array()
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x): materials.append(planes[id][y * 512 + x])
		var result := {"ok": true, "status": "completed", "region": region, "materials": materials,
			"owner_id": id + ":owner", "authored_revision": revisions[id], "authored_serial": authored_serials[id], "generation": generation}
		if bad_capture: result.erase("owner_id")
		return result

	func authoring_apply(id: String, cells: PackedInt32Array, expected: Dictionary) -> Dictionary:
		calls.append({"kind": "apply", "plane": id, "count": cells.size() / 3})
		if delayed:
			serial += 1; pending[serial] = {"kind": "apply", "id": id, "cells": cells.duplicate(), "expected": expected.duplicate(true)}
			return {"ok": true, "pending": true, "operation_id": serial}
		return _apply(id, cells, expected)

	func _apply(id: String, cells: PackedInt32Array, expected: Dictionary) -> Dictionary:
		for i: int in cells.size() / 3:
			if planes[id][cells[i * 3 + 1] * 512 + cells[i * 3]] != expected.before[i]: return {"ok": false, "applied": 0, "status": "refused", "error": "before mismatch"}
		var limit: int = mini(cells.size() / 3, prefix_limit) if prefix_limit >= 0 else cells.size() / 3
		var before := PackedInt32Array(); var after := PackedInt32Array()
		var changed := 0
		for i: int in limit:
			var key: int = cells[i * 3 + 1] * 512 + cells[i * 3]
			before.append(int(planes[id][key])); after.append(int(cells[i * 3 + 2]))
			if planes[id][key] != cells[i * 3 + 2]: changed += 1
			planes[id][key] = cells[i * 3 + 2]
		if limit > 0:
			writes += limit
			if limit == cells.size() / 3: revisions[id] += 1; authored_serials[id] += 1
			history[id].append({"cells": cells.slice(0, limit * 3), "before": before.duplicate()})
		if disturb_no_write: planes[id][65 * 512 + 65] = 77
		var result := {"ok": limit == cells.size() / 3, "status": "completed" if limit == cells.size() / 3 else "partial",
			"applied": limit, "changed": changed, "cells": cells.slice(0, limit * 3), "before": before, "after": after,
			"owner_id": "retired-owner" if wrong_owner else id + ":owner", "generation": generation, "authored_revision": revisions[id], "authored_serial": authored_serials[id],
			"error": "" if limit == cells.size() / 3 else "injected acknowledged partial prefix"}
		if bad_receipt: result.erase("after")
		if bad_applied: result.applied = "1"
		return result

	func authoring_poll(token: int) -> Dictionary:
		if hold_ack or not pending.has(token): return {}
		var operation: Dictionary = pending[token]; pending.erase(token)
		return _capture(operation.id, operation.region) if operation.kind == "capture" else _apply(operation.id, operation.cells, operation.expected)

	func authoring_preflight(_id: String, _cells: PackedInt32Array, _expected: Dictionary) -> Dictionary:
		return {"ok": true, "error": ""}

	func authoring_flush(_id: String) -> Dictionary:
		return {"ok": true, "published": published, "error": "" if published else "injected stale pixel admission"}

	func authoring_record(record: Dictionary) -> Dictionary:
		var result := Provenance.append(records, record)
		if result.ok: records = result.authoring
		return result

var checks := 0
var failures: Array[String] = []
var admitted := PackedInt32Array()


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error("STRATA_SESSION " + label)


func module(size: Vector2i, dense: bool = false) -> Dictionary:
	var cells := PackedByteArray(); cells.resize(size.x * size.y * 2)
	var mask := PackedByteArray(); mask.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			if dense or (x + y) % 2 == 0:
				cells.encode_u16((y * size.x + x) * 2, 58); mask[y * size.x + x] = 1
	return Module.create("test-part", "Session fixture part", size, cells, mask, {"source_kind": "test"}, admitted).module


func begin(host: FixtureHost, part: Dictionary, origin: Vector2i = Vector2i(64, 64)) -> Dictionary:
	var plan := Plan.from_module(part, "scripted", {"origin": [origin.x, origin.y]}, host.authoring_plane_state("scripted"))
	var session := Session.new()
	var state: Dictionary = session.begin(host, plan.plan, admitted)
	return {"session": session, "state": state, "plan": plan.plan}


func drive(session: RefCounted, maximum: int = 4096) -> Dictionary:
	var state: Dictionary = session.state()
	for _i: int in maximum:
		if not state.busy: return state
		state = session.step()
	check(false, "fixture finite session terminates within its step budget")
	return state


func _ack_notice_trials(part: Dictionary) -> void:
	# Backdate only this copied value owner's pending timestamp; no wall-clock
	# sleep, native delay injection, watchdog change or late-ACK acceptance bypass.
	var host := FixtureHost.new()
	host.delayed = true; host.hold_ack = true
	var created := begin(host, part)
	var session: RefCounted = created.session
	var state: Dictionary = session.state()
	for _i: int in 16:
		state = session.step()
		if state.pending_owner_ack: break
	var preview_pending: bool = state.pending_owner_ack and session._pending.kind == "preview"
	check(preview_pending, "held preview has an actual pending copied owner operation")
	if not preview_pending: return
	session._pending.started_usec = Time.get_ticks_usec() - Session.ACK_NOTICE_USEC - 1
	state = session.step()
	check(state.status == "preparing" and state.error == Session.ACK_NOTICE_MESSAGE and host.writes == 0,
		"overdue preview remains zero-write and explicitly waiting")
	host.hold_ack = false
	state = drive(session)
	check(state.status == "ready" and state.can_approve and state.error.is_empty() and host.writes == 0,
		"validated late observation clears only its provisional waiting notice")
	session.approve(state.token)
	host.hold_ack = true
	for _i: int in 16:
		state = session.step()
		if state.pending_owner_ack: break
	var apply_pending: bool = state.pending_owner_ack and session._pending.kind == "apply"
	check(apply_pending, "held apply has an actual pending owner operation")
	if not apply_pending: return
	session._pending.started_usec = Time.get_ticks_usec() - Session.ACK_NOTICE_USEC - 1
	state = session.step()
	check(state.status == "awaiting_ack" and state.error == Session.ACK_NOTICE_MESSAGE and host.writes == 0,
		"overdue mutation is pending without an invented native outcome")
	host.hold_ack = false
	state = session.step()
	check(state.status == "applying" and not state.pending_owner_ack and state.error.is_empty() and state.applied_cells == 3,
		"valid late ACK resumes applying and records its exact material prefix")
	state = drive(session)
	check(state.status == "completed" and state.error.is_empty() and state.applied_cells == 3
		and state.stages[0].actual_sha256 == state.stages[0].projected_sha256,
		"late ACK still requires exact final readback before clean completion")
	host = FixtureHost.new(); host.delayed = true; host.hold_ack = true
	created = begin(host, part); session = created.session; state = session.state()
	for _i: int in 16:
		state = session.step()
		if state.pending_owner_ack: break
	var invalid_pending: bool = state.pending_owner_ack
	check(invalid_pending, "invalid late observation fixture is pending")
	if not invalid_pending: return
	session._pending.started_usec = Time.get_ticks_usec() - Session.ACK_NOTICE_USEC - 1
	session.step()
	host.bad_capture = true; host.hold_ack = false
	state = drive(session)
	check(state.status == "refused" and state.error.contains("owner") and state.error != Session.ACK_NOTICE_MESSAGE and host.writes == 0,
		"late owner-identity failure replaces waiting notice with the genuine refusal")


func run() -> void:
	admitted = Executor.native_materials()
	check(not admitted.is_empty(), "actual retained runtime provides native material admission catalogue")
	var part := module(Vector2i(3, 2))
	_ack_notice_trials(part)
	var host := FixtureHost.new()
	host.planes.scripted[64 * 512 + 65] = 77 # Transparent source pixel.
	host.planes.effects[64 * 512 + 64] = 66
	var play_before := Module.digest(host.planes.play.to_byte_array())
	var scripted_before := Module.digest(host.planes.scripted.to_byte_array())
	var created := begin(host, part)
	var session: RefCounted = created.session
	var state := drive(session)
	check(state.status == "ready" and state.can_approve and not state.token.is_empty(), "finite native-source preview becomes approvable")
	check(host.writes == 0 and Module.digest(host.planes.scripted.to_byte_array()) == scripted_before, "preview performs zero target mutations")
	check(state.preview_regions.size() == 1 and state.preview_regions[0].plane == "scripted", "per-plane projected image and coordinate region are exposed")
	check(state.changed_cells == 3, "preview counts actual changes, excludes transparent cells")
	var first_token: String = state.token
	session.approve(state.token); state = drive(session)
	check(state.status == "completed" and state.applied_cells == 3 and state.changed_cells == 3, "complete owner ACK and independent readback produce completion")
	check(host.planes.scripted[64 * 512 + 65] == 77 and host.planes.scripted[64 * 512 + 64] == 58, "source transparency preserves target material through real proposal execution")
	check(host.planes.effects[64 * 512 + 64] == 66 and Module.digest(host.planes.play.to_byte_array()) == play_before, "selected plane writes never alter Play or another plane fixture")
	check(host.records.records.size() == 1 and host.records.records[0].actual_sha256 == host.records.records[0].projected_sha256 and host.records.records[0].published, "retained terminal record carries complete native region identity")
	check(host.history.scripted.size() == 1, "existing owner history receives one operation per chunk")
	var recreated := begin(host, part); state = drive(recreated.session)
	check(state.token != first_token and state.changed_cells == 0, "new preview token differs even when source geometry is unchanged")
	recreated.session.begin(host, {}, admitted)
	check(not recreated.session.state().can_approve and recreated.session.state().token.is_empty(), "failed replacement preview retires previous approval token")
	for mutation: String in ["revision", "authored_serial", "permission", "generation", "hidden"]:
		host = FixtureHost.new(); created = begin(host, part); session = created.session; state = drive(session)
		match mutation:
			"revision": host.revisions.scripted += 1
			"authored_serial": host.authored_serials.scripted += 1 # No cell/native revision change.
			"permission": host.permission = "b".repeat(64)
			"generation": host.generation += 1
			"hidden": host.visible = false
		state = session.approve(state.token)
		check(state.status == "refused" and host.writes == 0 and not state.can_approve, "approval revalidates " + mutation)
	host = FixtureHost.new(); host.capacity_records = 0
	check(begin(host, part).state.status == "refused" and host.writes == 0, "record capacity refuses before any write")
	host = FixtureHost.new(); host.capacity_bytes = 100
	check(begin(host, part).state.status == "refused" and host.writes == 0, "record bytes refuse before any write")
	host = FixtureHost.new(); created = begin(host, part)
	var near_limit: Dictionary = created.plan.duplicate(true)
	var basic := Plan.compile(near_limit, admitted)
	near_limit.metadata.padding = "x".repeat(8170 - Module.json_bytes(basic.stages[0].metadata).size() - 13)
	check(Plan.compile(near_limit, admitted).ok, "boundary provenance fixture fits the plain typed plan")
	var boundary_session := Session.new()
	check(boundary_session.begin(host, near_limit, admitted).status == "refused" and host.writes == 0, "worst-case terminal metadata refuses before the first native write")
	host = FixtureHost.new(); host.prior_undo = 32
	created = begin(host, part); state = drive(created.session)
	check(state.can_approve and state.history_summary[0].displaced_entries == 1 and not state.history_warnings.is_empty(), "preview explicitly warns about inherited32-entry history displacement")
	host = FixtureHost.new(); host.bad_capture = true
	created = begin(host, part)
	check(drive(created.session).status == "refused" and host.writes == 0, "copied native observation requires explicit owner identity")
	host = FixtureHost.new(); host.max_rectangles = 1; host.rectangles = 1
	created = begin(host, part); check(drive(created.session).status == "refused" and host.writes == 0, "predictable rectangle history cap refuses at preview")
	var large := module(Vector2i(70, 70), true)
	for delayed: bool in [false, true]:
		host = FixtureHost.new(); host.delayed = delayed
		created = begin(host, large); session = created.session; state = drive(session)
		check(state.can_approve and host.writes == 0, "large proposal remains zero-write before approval")
		session.approve(state.token)
		for _i: int in 100:
			state = session.step()
			if (delayed and state.pending_owner_ack) or (not delayed and state.applied_cells == 4096): break
		session.stop(); state = drive(session)
		check(state.status == "partial" and state.applied_cells == 4096 and host.writes == 4096, "Stop retains exact acknowledged4096-cell prefix, delayed=" + str(delayed))
		check(state.stages[0].completed_chunks == 1 and state.stages[0].actual_sha256 != state.stages[0].projected_sha256, "partial native result cannot claim complete projected geometry")
		check(host.records.records[0].status == "partial" and host.history.scripted.size() == 1, "partial prefix has truthful provenance and one undo entry")
		for call: Dictionary in host.calls: check(call.count <= 4096, "every capture/apply operation bounded4096")
	host = FixtureHost.new(); host.prefix_limit = 7
	created = begin(host, large); session = created.session; state = drive(session); session.approve(state.token); state = drive(session)
	check(state.status == "partial" and state.applied_cells == 7 and host.records.records[0].applied_cells == 7 and state.stages[0].completed_chunks == 0, "partial owner mutation is accounted independently of completed chunks")
	host = FixtureHost.new(); host.published = false
	created = begin(host, part); session = created.session; state = drive(session); session.approve(state.token); state = drive(session)
	check(state.status == "committed_stale_pixels" and state.applied_cells == 3 and host.records.records[0].status == "committed_stale_pixels", "display publication failure never relabels committed native materials uncommitted")
	host = FixtureHost.new(); host.readback_failure = true
	created = begin(host, part); session = created.session; state = drive(session); session.approve(state.token); state = drive(session)
	check(state.status == "partial" and state.applied_cells == 3 and state.stages[0].actual_sha256.is_empty(), "failed final capture preserves ACK prefix without inventing whole-region readback")
	host = FixtureHost.new(); host.disturb_no_write = true
	created = begin(host, part); session = created.session; state = drive(session); session.approve(state.token); state = drive(session)
	check(state.status == "partial" and state.applied_cells == 3, "independent final capture catches an unrelated no-write cell mutation")
	for fault: String in ["wrong_owner", "bad_receipt", "bad_applied"]:
		host = FixtureHost.new(); host.set(fault, true)
		created = begin(host, part); session = created.session; state = drive(session); session.approve(state.token); state = drive(session)
		check(state.status == "failed" and state.native_outcome_unverified and not state.zero_writes and not state.receipts.is_empty() and host.records.records.is_empty(), "unverified native ACK blocks completion without false no-write claim: " + fault)
	host = FixtureHost.new(); created = begin(host, part); session = created.session; state = drive(session)
	var second: Dictionary = created.plan.stages[0].duplicate(true)
	second.id = "second"; second.depends_on = ["place"]
	var module_copy: Dictionary = part.duplicate(true)
	var material_bytes: PackedByteArray = Marshalls.base64_to_raw(module_copy.geometry.cells_base64)
	for i: int in material_bytes.size() / 2:
		if material_bytes.decode_u16(i * 2) != 0: material_bytes.encode_u16(i * 2, 66)
	module_copy.id = "second-part"; module_copy.geometry.cells_base64 = Marshalls.raw_to_base64(material_bytes); module_copy.geometry.sha256 = Module.digest(material_bytes); module_copy.content_sha256 = Module.content_digest(module_copy)
	second.placements[0].module_id = module_copy.id; second.placements[0].module_sha256 = module_copy.content_sha256; second.allowed_materials = [0, 58, 66]
	created.plan.modules.append(module_copy); created.plan.stages.append(second)
	session = Session.new(); session.begin(host, created.plan, admitted); state = drive(session)
	check(state.can_approve and state.stages[1].before_sha256 == state.stages[0].projected_sha256, "same-plane later stage previews earlier reviewed projection")
	session.approve(state.token); state = drive(session)
	check(state.status == "completed" and host.records.records.size() == 2 and host.planes.scripted[64 * 512 + 64] == 66, "ordered dependent stages require actual ACK completion")
	var invalid: Dictionary = created.plan.duplicate(true); invalid.stages[0].depends_on = ["second"]
	check(not Plan.compile(invalid, admitted).ok, "future/cyclic dependency refuses")
	invalid = created.plan.duplicate(true); invalid.stages[0].placements.append(invalid.stages[0].placements[0].duplicate(true))
	check(not Plan.compile(invalid, admitted).ok, "same-stage overlapping placement refuses")
	for field: String in ["id", "plane", "region", "expected_revision", "depends_on", "allowed_materials", "protected_regions", "placements"]:
		invalid = created.plan.duplicate(true); invalid.stages[0][field] = Rect2i(0, 0, 2, 2)
		check(not Plan.compile(invalid, admitted).ok, "typed plan rejects non-JSON field " + field)
	var json_plan: Variant = JSON.parse_string(JSON.stringify(created.plan))
	check(Plan.compile(json_plan, admitted).ok, "real JSON plan numeric arrays canonicalize to exact material IDs")
	var preset := {"format": Plan.COMPOSITION_FORMAT, "id": "roundtrip-preset", "name": "JSON preset", "modules": [part.id], "metadata": {},
		"stages": [{"id": "one", "plane": "scripted", "region": [0, 0, 3, 2], "depends_on": [], "allowed_materials": [0, 58], "protected_regions": [],
			"placements": [{"module_id": part.id, "origin": [0, 0], "transform": "identity", "palette": {}, "empty_mode": "preserve"}]}]}
	var preset_roundtrip: Variant = JSON.parse_string(JSON.stringify(preset))
	check(Plan.from_composition(preset_roundtrip, Vector2i(64, 64), [JSON.parse_string(JSON.stringify(part))], {"scripted": host.authoring_plane_state("scripted")}, admitted).ok, "real JSON composition/module bridge preserves palette permissions")
	var two_parts: Dictionary = preset.duplicate(true)
	two_parts.modules = [part.id, module_copy.id]
	var second_preset_stage: Dictionary = two_parts.stages[0].duplicate(true)
	second_preset_stage.id = "two"; second_preset_stage.depends_on = ["one"]
	second_preset_stage.allowed_materials = [0, 66]
	second_preset_stage.placements[0].module_id = module_copy.id
	two_parts.stages.append(second_preset_stage)
	var two_parts_roundtrip: Variant = JSON.parse_string(JSON.stringify(two_parts))
	check(Plan.from_composition(two_parts_roundtrip, Vector2i(64, 64), [part, module_copy], {"scripted": host.authoring_plane_state("scripted")}, admitted).ok, "JSON composition declares the exact two-part dependency set")
	two_parts_roundtrip.modules = [part.id, part.id]
	check(not Plan.from_composition(two_parts_roundtrip, Vector2i(64, 64), [part, module_copy], {"scripted": host.authoring_plane_state("scripted")}, admitted).ok, "duplicate declared dependency cannot conceal a second supplied and used part")
	preset_roundtrip.stages[0].allowed_materials = [0.0, 58.5]
	check(not Plan.from_composition(preset_roundtrip, Vector2i(64, 64), [part], {"scripted": host.authoring_plane_state("scripted")}, admitted).ok, "fractional JSON material IDs still refuse")
	var inspected := Codec.inspect_source("res://data/strata2/imports/alpha-cutout.png", admitted)
	check(inspected.ok and inspected.extent == [64, 48] and inspected.source_sha256 == "452832a18d4b09185ecdc1220d1d0c93e8f447211463fec8c6e6705d07c3627b", "shipped synthetic PNG source identity and exact extent")
	var native_fixture := Codec.inspect_source("res://data/strata2/imports/alpha-cutout-native.json", admitted)
	check(native_fixture.ok and native_fixture.mask[24 * 64 + 32] == 0 and native_fixture.cells.decode_u16((4 * 64 + 4) * 2) == 58, "shipped native fixture validates exact IDs and interior no-write mask")
	print("STRATA_SESSION ", JSON.stringify({"checks": checks, "failures": failures, "completed": true, "scope": "adversarial owner-contract fixtures, actual native mutation and framebuffer qualified separately"}))
	quit(0 if failures.is_empty() else 1)
